-- Core Streak engine. This slice intentionally exposes no public RPC surface:
-- engine execution remains private/service-side and only reads Attendance.

CREATE OR REPLACE FUNCTION private.streak_period_boundary(
  p_local_date DATE,
  p_timezone TEXT
) RETURNS TIMESTAMPTZ LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
  SELECT (p_local_date::TIMESTAMP AT TIME ZONE p_timezone);
$$;

CREATE OR REPLACE FUNCTION private.is_streak_period_eligible(
  p_gym_id UUID,
  p_gym_member_id UUID,
  p_period_start_at TIMESTAMPTZ
) RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.memberships m
    WHERE m.gym_id = p_gym_id
      AND m.gym_member_id = p_gym_member_id
      AND m.status IN ('ACTIVE', 'EXPIRED')
      AND m.starts_at <= p_period_start_at
      AND m.ends_at > p_period_start_at
  );
$$;

CREATE OR REPLACE FUNCTION private.count_valid_streak_days(
  p_streak_period_id UUID
) RETURNS INTEGER LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_period public.streak_periods%ROWTYPE;
  v_days INTEGER;
BEGIN
  SELECT * INTO v_period
  FROM public.streak_periods
  WHERE id = p_streak_period_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Streak period not found' USING ERRCODE = 'P0002';
  END IF;

  SELECT COUNT(DISTINCT a.attendance_date)::INTEGER INTO v_days
  FROM public.attendances a
  WHERE a.gym_id = v_period.gym_id
    AND a.gym_member_id = v_period.gym_member_id
    AND a.status = 'VALID'
    AND a.attendance_date BETWEEN v_period.period_start AND v_period.period_end;

  RETURN COALESCE(v_days, 0);
END;
$$;

CREATE OR REPLACE FUNCTION private.get_streak_freeze_balance(
  p_gym_member_id UUID
) RETURNS INTEGER LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
  SELECT COALESCE(SUM(
    CASE transaction_type
      WHEN 'GRANT' THEN amount
      WHEN 'RESTORE' THEN amount
      WHEN 'CONSUME' THEN -amount
      WHEN 'EXPIRE' THEN -amount
    END
  ), 0)::INTEGER
  FROM public.streak_freeze_transactions
  WHERE gym_member_id = p_gym_member_id;
$$;

CREATE OR REPLACE FUNCTION private.get_active_streak_freeze_consume(
  p_streak_period_id UUID
) RETURNS UUID LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
  SELECT sft.id
  FROM public.streak_freeze_transactions sft
  WHERE sft.streak_period_id = p_streak_period_id
    AND sft.transaction_type = 'CONSUME'
    AND sft.reversed_by_transaction_id IS NULL
  ORDER BY sft.created_at DESC, sft.id
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION private.restore_streak_freeze_consume(
  p_consume_transaction_id UUID,
  p_actor UUID DEFAULT NULL
) RETURNS UUID LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_consume public.streak_freeze_transactions%ROWTYPE;
  v_restore_id UUID;
BEGIN
  SELECT * INTO v_consume
  FROM public.streak_freeze_transactions
  WHERE id = p_consume_transaction_id
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

CREATE OR REPLACE FUNCTION private.activate_due_streak_rule(
  p_gym_member_id UUID,
  p_as_of TIMESTAMPTZ DEFAULT clock_timestamp()
) RETURNS VOID LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_projection public.member_streaks%ROWTYPE;
  v_active public.member_streak_rules%ROWTYPE;
  v_scheduled public.member_streak_rules%ROWTYPE;
BEGIN
  SELECT * INTO v_projection
  FROM public.member_streaks
  WHERE gym_member_id = p_gym_member_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RETURN;
  END IF;

  SELECT * INTO v_scheduled
  FROM public.member_streak_rules
  WHERE gym_id = v_projection.gym_id
    AND gym_member_id = p_gym_member_id
    AND status = 'SCHEDULED'
    AND starts_at <= p_as_of
  ORDER BY starts_at, id
  LIMIT 1
  FOR UPDATE;
  IF NOT FOUND THEN
    RETURN;
  END IF;

  SELECT * INTO v_active
  FROM public.member_streak_rules
  WHERE gym_id = v_scheduled.gym_id
    AND gym_member_id = p_gym_member_id
    AND status = 'ACTIVE'
  FOR UPDATE;
  IF NOT FOUND OR v_active.ends_at IS DISTINCT FROM v_scheduled.starts_at THEN
    RAISE EXCEPTION 'Scheduled streak rule boundary is inconsistent' USING ERRCODE = '23514';
  END IF;

  UPDATE public.member_streak_rules
  SET status = 'ENDED'
  WHERE id = v_active.id;

  UPDATE public.member_streak_rules
  SET status = 'ACTIVE'
  WHERE id = v_scheduled.id;
END;
$$;

CREATE OR REPLACE FUNCTION private.ensure_streak_period(
  p_gym_member_id UUID,
  p_period_start DATE,
  p_as_of TIMESTAMPTZ DEFAULT clock_timestamp()
) RETURNS UUID LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_projection public.member_streaks%ROWTYPE;
  v_rule public.member_streak_rules%ROWTYPE;
  v_period_id UUID;
  v_period_start_at TIMESTAMPTZ;
  v_period_end_at TIMESTAMPTZ;
  v_period_status public.streak_period_status := 'OPEN';
  v_reason public.streak_period_eligibility_reason := NULL;
  v_finalized_at TIMESTAMPTZ := NULL;
BEGIN
  IF EXTRACT(ISODOW FROM p_period_start)::INTEGER <> 1 THEN
    RAISE EXCEPTION 'Streak period start must be a Monday' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_projection
  FROM public.member_streaks
  WHERE gym_member_id = p_gym_member_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Member streak projection not found' USING ERRCODE = 'P0002';
  END IF;

  PERFORM private.activate_due_streak_rule(p_gym_member_id, p_as_of);

  SELECT * INTO v_rule
  FROM public.member_streak_rules msr
  WHERE msr.gym_id = v_projection.gym_id
    AND msr.gym_member_id = p_gym_member_id
    AND msr.status = 'ACTIVE'
    AND msr.starts_at < private.streak_period_boundary(p_period_start + 7, msr.timezone)
    AND (msr.ends_at IS NULL OR msr.ends_at > private.streak_period_boundary(p_period_start, msr.timezone))
  ORDER BY msr.starts_at DESC, msr.id DESC
  LIMIT 1
  FOR SHARE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Active streak rule not found for period' USING ERRCODE = 'P0002';
  END IF;

  v_period_start_at := private.streak_period_boundary(p_period_start, v_rule.timezone);
  v_period_end_at := private.streak_period_boundary(p_period_start + 7, v_rule.timezone);

  IF p_as_of >= v_period_end_at THEN
    IF v_rule.starts_at > v_period_start_at THEN
      v_period_status := 'NOT_ELIGIBLE';
      v_reason := 'PARTIAL_INITIAL_PERIOD';
      v_finalized_at := p_as_of;
    ELSIF NOT private.is_streak_period_eligible(v_rule.gym_id, p_gym_member_id, v_period_start_at) THEN
      v_period_status := 'NOT_ELIGIBLE';
      v_reason := 'NO_ACTIVE_MEMBERSHIP';
      v_finalized_at := p_as_of;
    END IF;
  END IF;

  INSERT INTO public.streak_periods (
    gym_id, gym_member_id, member_streak_rule_id, period_start, period_end,
    period_start_at, period_end_at, timezone_snapshot, target_days_snapshot,
    status, eligibility_reason, finalized_at
  ) VALUES (
    v_rule.gym_id, p_gym_member_id, v_rule.id, p_period_start, p_period_start + 6,
    v_period_start_at, v_period_end_at, v_rule.timezone, v_rule.target_days,
    v_period_status, v_reason, v_finalized_at
  )
  ON CONFLICT (gym_id, gym_member_id, period_start) DO NOTHING
  RETURNING id INTO v_period_id;

  IF v_period_id IS NULL THEN
    SELECT id INTO v_period_id
    FROM public.streak_periods
    WHERE gym_id = v_rule.gym_id
      AND gym_member_id = p_gym_member_id
      AND period_start = p_period_start;
  END IF;

  RETURN v_period_id;
END;
$$;

CREATE OR REPLACE FUNCTION private.recalculate_member_streak(
  p_gym_member_id UUID,
  p_from_period_start DATE DEFAULT NULL,
  p_as_of TIMESTAMPTZ DEFAULT clock_timestamp()
) RETURNS UUID LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_projection public.member_streaks%ROWTYPE;
  v_period RECORD;
  v_valid_days INTEGER;
  v_new_status public.streak_period_status;
  v_reason public.streak_period_eligibility_reason;
  v_finalized_at TIMESTAMPTZ;
  v_should_freeze BOOLEAN;
  v_active_consume_id UUID;
  v_current_streak INTEGER := 0;
  v_best_streak INTEGER := 0;
  v_virtual_balance INTEGER := 0;
  v_actual_balance INTEGER := 0;
  v_current_period_id UUID := NULL;
  v_last_completed_period_start DATE := NULL;
  v_calculated_through DATE := NULL;
BEGIN
  SELECT * INTO v_projection
  FROM public.member_streaks
  WHERE gym_member_id = p_gym_member_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Member streak projection not found' USING ERRCODE = 'P0002';
  END IF;

  PERFORM private.activate_due_streak_rule(p_gym_member_id, p_as_of);

  SELECT COALESCE(SUM(
    CASE transaction_type
      WHEN 'GRANT' THEN amount
      WHEN 'EXPIRE' THEN -amount
      ELSE 0
    END
  ), 0)::INTEGER INTO v_virtual_balance
  FROM public.streak_freeze_transactions
  WHERE gym_member_id = p_gym_member_id;

  FOR v_period IN
    SELECT sp.*, msr.starts_at AS assignment_starts_at
    FROM public.streak_periods sp
    JOIN public.member_streak_rules msr
      ON msr.id = sp.member_streak_rule_id
     AND msr.gym_id = sp.gym_id
     AND msr.gym_member_id = sp.gym_member_id
    WHERE sp.gym_id = v_projection.gym_id
      AND sp.gym_member_id = p_gym_member_id
    ORDER BY sp.period_start, sp.id
    FOR UPDATE OF sp
  LOOP
    v_valid_days := private.count_valid_streak_days(v_period.id);
    v_active_consume_id := private.get_active_streak_freeze_consume(v_period.id);
    v_new_status := 'OPEN';
    v_reason := NULL;
    v_finalized_at := NULL;
    v_should_freeze := FALSE;

    IF v_period.period_end_at > p_as_of THEN
      v_new_status := 'OPEN';
    ELSIF v_period.assignment_starts_at > v_period.period_start_at THEN
      v_new_status := 'NOT_ELIGIBLE';
      v_reason := 'PARTIAL_INITIAL_PERIOD';
    ELSIF NOT private.is_streak_period_eligible(v_period.gym_id, v_period.gym_member_id, v_period.period_start_at) THEN
      v_new_status := 'NOT_ELIGIBLE';
      v_reason := 'NO_ACTIVE_MEMBERSHIP';
    ELSIF v_valid_days >= v_period.target_days_snapshot THEN
      v_new_status := 'COMPLETED';
    ELSIF v_current_streak > 0 AND v_virtual_balance > 0 THEN
      v_new_status := 'FROZEN';
      v_should_freeze := TRUE;
    ELSE
      v_new_status := 'MISSED';
    END IF;

    IF v_should_freeze THEN
      IF v_active_consume_id IS NULL THEN
        INSERT INTO public.streak_freeze_transactions (
          gym_id, gym_member_id, streak_period_id, transaction_type,
          amount, reason, metadata
        ) VALUES (
          v_period.gym_id, v_period.gym_member_id, v_period.id, 'CONSUME',
          1, 'Streak period frozen after missed target',
          jsonb_build_object('period_start', v_period.period_start)
        );
      END IF;
      v_virtual_balance := v_virtual_balance - 1;
    ELSIF v_active_consume_id IS NOT NULL THEN
      PERFORM private.restore_streak_freeze_consume(v_active_consume_id, NULL);
    END IF;

    IF v_new_status = 'OPEN' THEN
      v_current_period_id := v_period.id;
      v_finalized_at := NULL;
    ELSE
      v_finalized_at := CASE
        WHEN v_period.status = v_new_status AND v_period.finalized_at IS NOT NULL
          THEN v_period.finalized_at
        ELSE p_as_of
      END;
      v_calculated_through := v_period.period_start;
    END IF;

    UPDATE public.streak_periods
    SET valid_days = v_valid_days::SMALLINT,
        status = v_new_status,
        eligibility_reason = v_reason,
        freeze_applied = v_should_freeze,
        finalized_at = v_finalized_at,
        last_recalculated_at = p_as_of
    WHERE id = v_period.id;

    IF v_new_status = 'COMPLETED' THEN
      v_current_streak := v_current_streak + 1;
      v_last_completed_period_start := v_period.period_start;
    ELSIF v_new_status = 'MISSED' THEN
      v_current_streak := 0;
    END IF;

    IF v_current_streak > v_best_streak THEN
      v_best_streak := v_current_streak;
    END IF;
  END LOOP;

  v_actual_balance := private.get_streak_freeze_balance(p_gym_member_id);
  IF v_actual_balance < 0 THEN
    RAISE EXCEPTION 'Streak freeze balance cannot be negative' USING ERRCODE = '23514';
  END IF;

  UPDATE public.member_streaks
  SET current_streak = v_current_streak,
      best_streak = v_best_streak,
      freezes_available = v_actual_balance::SMALLINT,
      current_period_id = v_current_period_id,
      last_completed_period_start = v_last_completed_period_start,
      calculated_through = v_calculated_through,
      version = version + 1
  WHERE id = v_projection.id
  RETURNING id INTO v_projection.id;

  RETURN v_projection.id;
END;
$$;

CREATE OR REPLACE FUNCTION private.finalize_streak_period(
  p_streak_period_id UUID,
  p_as_of TIMESTAMPTZ DEFAULT clock_timestamp()
) RETURNS UUID LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_period public.streak_periods%ROWTYPE;
BEGIN
  SELECT * INTO v_period
  FROM public.streak_periods
  WHERE id = p_streak_period_id
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

REVOKE ALL ON FUNCTION private.streak_period_boundary(DATE, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION private.is_streak_period_eligible(UUID, UUID, TIMESTAMPTZ) FROM PUBLIC;
REVOKE ALL ON FUNCTION private.count_valid_streak_days(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION private.get_streak_freeze_balance(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION private.get_active_streak_freeze_consume(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION private.restore_streak_freeze_consume(UUID, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION private.activate_due_streak_rule(UUID, TIMESTAMPTZ) FROM PUBLIC;
REVOKE ALL ON FUNCTION private.ensure_streak_period(UUID, DATE, TIMESTAMPTZ) FROM PUBLIC;
REVOKE ALL ON FUNCTION private.recalculate_member_streak(UUID, DATE, TIMESTAMPTZ) FROM PUBLIC;
REVOKE ALL ON FUNCTION private.finalize_streak_period(UUID, TIMESTAMPTZ) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION private.streak_period_boundary(DATE, TEXT) TO postgres, service_role;
GRANT EXECUTE ON FUNCTION private.is_streak_period_eligible(UUID, UUID, TIMESTAMPTZ) TO postgres, service_role;
GRANT EXECUTE ON FUNCTION private.count_valid_streak_days(UUID) TO postgres, service_role;
GRANT EXECUTE ON FUNCTION private.get_streak_freeze_balance(UUID) TO postgres, service_role;
GRANT EXECUTE ON FUNCTION private.get_active_streak_freeze_consume(UUID) TO postgres, service_role;
GRANT EXECUTE ON FUNCTION private.restore_streak_freeze_consume(UUID, UUID) TO postgres, service_role;
GRANT EXECUTE ON FUNCTION private.activate_due_streak_rule(UUID, TIMESTAMPTZ) TO postgres, service_role;
GRANT EXECUTE ON FUNCTION private.ensure_streak_period(UUID, DATE, TIMESTAMPTZ) TO postgres, service_role;
GRANT EXECUTE ON FUNCTION private.recalculate_member_streak(UUID, DATE, TIMESTAMPTZ) TO postgres, service_role;
GRANT EXECUTE ON FUNCTION private.finalize_streak_period(UUID, TIMESTAMPTZ) TO postgres, service_role;
