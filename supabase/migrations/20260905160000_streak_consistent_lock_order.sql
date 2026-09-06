-- Serialize every per-member Streak mutation on member_streaks before taking
-- period, assignment, or freeze-ledger row locks. This removes the lock-order
-- inversions found during the v2.0.4-2 concurrency audit.

CREATE OR REPLACE FUNCTION private.restore_streak_freeze_consume(
  p_consume_transaction_id UUID,
  p_actor UUID DEFAULT NULL
) RETURNS UUID LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_gym_id UUID;
  v_gym_member_id UUID;
  v_streak_period_id UUID;
  v_projection_id UUID;
  v_locked_period_id UUID;
  v_consume public.streak_freeze_transactions%ROWTYPE;
  v_restore_id UUID;
BEGIN
  -- Locator read only: the CONSUME must not be locked before the member mutex.
  SELECT sft.gym_id, sft.gym_member_id, sft.streak_period_id
  INTO v_gym_id, v_gym_member_id, v_streak_period_id
  FROM public.streak_freeze_transactions sft
  WHERE sft.id = p_consume_transaction_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Streak freeze consume transaction not found' USING ERRCODE = 'P0002';
  END IF;

  SELECT ms.id
  INTO v_projection_id
  FROM public.member_streaks ms
  WHERE ms.gym_id = v_gym_id
    AND ms.gym_member_id = v_gym_member_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Member streak projection not found' USING ERRCODE = 'P0002';
  END IF;

  -- Match recalculate_member_streak's projection -> period -> ledger order.
  IF v_streak_period_id IS NOT NULL THEN
    SELECT sp.id
    INTO v_locked_period_id
    FROM public.streak_periods sp
    WHERE sp.id = v_streak_period_id
      AND sp.gym_id = v_gym_id
      AND sp.gym_member_id = v_gym_member_id
    FOR UPDATE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Streak period not found' USING ERRCODE = 'P0002';
    END IF;
  END IF;

  SELECT sft.*
  INTO v_consume
  FROM public.streak_freeze_transactions sft
  WHERE sft.id = p_consume_transaction_id
    AND sft.gym_id = v_gym_id
    AND sft.gym_member_id = v_gym_member_id
    AND sft.streak_period_id IS NOT DISTINCT FROM v_streak_period_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Streak freeze consume transaction not found' USING ERRCODE = 'P0002';
  END IF;
  IF v_consume.transaction_type <> 'CONSUME' THEN
    RAISE EXCEPTION 'Only CONSUME transactions can be restored' USING ERRCODE = '22023';
  END IF;
  IF v_consume.reversed_by_transaction_id IS NOT NULL THEN
    RETURN v_consume.reversed_by_transaction_id;
  END IF;

  INSERT INTO public.streak_freeze_transactions (
    gym_id, gym_member_id, streak_period_id, transaction_type, amount,
    reason, source_transaction_id, created_by, metadata
  ) VALUES (
    v_consume.gym_id, v_consume.gym_member_id, v_consume.streak_period_id,
    'RESTORE', v_consume.amount, 'Streak period correction restored freeze',
    v_consume.id, p_actor, jsonb_build_object('restored_consume_id', v_consume.id)
  ) RETURNING id INTO v_restore_id;

  UPDATE public.streak_freeze_transactions
  SET reversed_by_transaction_id = v_restore_id
  WHERE id = v_consume.id;

  RETURN v_restore_id;
END;
$$;

CREATE OR REPLACE FUNCTION private.finalize_streak_period(
  p_streak_period_id UUID,
  p_as_of TIMESTAMPTZ DEFAULT clock_timestamp()
) RETURNS UUID LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_gym_id UUID;
  v_gym_member_id UUID;
  v_projection_id UUID;
  v_period public.streak_periods%ROWTYPE;
BEGIN
  -- Locator read only: the period must not be locked before the member mutex.
  SELECT sp.gym_id, sp.gym_member_id
  INTO v_gym_id, v_gym_member_id
  FROM public.streak_periods sp
  WHERE sp.id = p_streak_period_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Streak period not found' USING ERRCODE = 'P0002';
  END IF;

  SELECT ms.id
  INTO v_projection_id
  FROM public.member_streaks ms
  WHERE ms.gym_id = v_gym_id
    AND ms.gym_member_id = v_gym_member_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Member streak projection not found' USING ERRCODE = 'P0002';
  END IF;

  -- Re-read and validate authoritative state after acquiring both locks.
  SELECT sp.*
  INTO v_period
  FROM public.streak_periods sp
  WHERE sp.id = p_streak_period_id
    AND sp.gym_id = v_gym_id
    AND sp.gym_member_id = v_gym_member_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Streak period not found' USING ERRCODE = 'P0002';
  END IF;
  IF v_period.status = 'OPEN' AND p_as_of < v_period.period_end_at THEN
    RAISE EXCEPTION 'Cannot finalize an open streak period before its local end boundary' USING ERRCODE = '55000';
  END IF;

  RETURN private.recalculate_member_streak(
    v_period.gym_member_id,
    v_period.period_start,
    p_as_of
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.change_member_streak_rule(
  p_gym_id UUID,
  p_gym_member_id UUID,
  p_new_streak_rule_id UUID
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_actor UUID;
  v_projection_id UUID;
  v_current public.member_streak_rules%ROWTYPE;
  v_boundary TIMESTAMPTZ;
  v_id UUID;
BEGIN
  v_actor := private.assert_gym_admin(p_gym_id);

  -- Use the same per-member mutex as lifecycle activation and replay before
  -- locking ACTIVE/SCHEDULED assignment rows.
  SELECT ms.id
  INTO v_projection_id
  FROM public.member_streaks ms
  WHERE ms.gym_id = p_gym_id
    AND ms.gym_member_id = p_gym_member_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Member streak projection not found' USING ERRCODE = 'P0002';
  END IF;

  SELECT * INTO v_current FROM public.member_streak_rules
  WHERE gym_id = p_gym_id AND gym_member_id = p_gym_member_id AND status = 'ACTIVE'
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Active member streak rule assignment not found' USING ERRCODE = 'P0002';
  END IF;
  IF v_current.streak_rule_id = p_new_streak_rule_id THEN
    RAISE EXCEPTION 'Member already uses this streak rule' USING ERRCODE = '22023';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.member_streak_rules
    WHERE gym_id = p_gym_id AND gym_member_id = p_gym_member_id AND status = 'SCHEDULED'
    FOR UPDATE
  ) THEN
    RAISE EXCEPTION 'Gym member already has a scheduled streak rule assignment' USING ERRCODE = '23505';
  END IF;

  v_boundary := private.next_monday_boundary(clock_timestamp(), v_current.timezone);
  UPDATE public.member_streak_rules
  SET ends_at = v_boundary
  WHERE id = v_current.id;

  v_id := private.create_member_streak_rule_assignment(
    p_gym_id, p_gym_member_id, p_new_streak_rule_id, v_boundary, 'SCHEDULED', v_actor, FALSE
  );
  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION private.restore_streak_freeze_consume(UUID, UUID)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.restore_streak_freeze_consume(UUID, UUID)
  TO postgres, service_role;

REVOKE ALL ON FUNCTION private.finalize_streak_period(UUID, TIMESTAMPTZ)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.finalize_streak_period(UUID, TIMESTAMPTZ)
  TO postgres, service_role;
