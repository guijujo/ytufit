-- Resolve Streak rule snapshots from authoritative assignment intervals.
-- Lifecycle status remains operational state and is not historical truth.

CREATE FUNCTION private.resolve_streak_rule_for_period(
  p_gym_member_id UUID,
  p_period_start DATE
) RETURNS public.member_streak_rules
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_gym_id UUID;
  v_candidate_ids UUID[];
  v_rule public.member_streak_rules%ROWTYPE;
BEGIN
  IF EXTRACT(ISODOW FROM p_period_start)::INTEGER <> 1 THEN
    RAISE EXCEPTION 'Streak period start must be a Monday' USING ERRCODE = '22023';
  END IF;

  SELECT ms.gym_id INTO v_gym_id
  FROM public.member_streaks ms
  WHERE ms.gym_member_id = p_gym_member_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Member streak projection not found' USING ERRCODE = 'P0002';
  END IF;

  SELECT array_agg(msr.id ORDER BY msr.starts_at, msr.id)
  INTO v_candidate_ids
  FROM public.member_streak_rules msr
  WHERE msr.gym_id = v_gym_id
    AND msr.gym_member_id = p_gym_member_id
    AND msr.starts_at < private.streak_period_boundary(p_period_start + 7, msr.timezone)
    AND (
      msr.ends_at IS NULL
      OR msr.ends_at > private.streak_period_boundary(p_period_start, msr.timezone)
    );

  IF COALESCE(cardinality(v_candidate_ids), 0) = 0 THEN
    RAISE EXCEPTION 'Streak rule not found for period' USING ERRCODE = 'P0002';
  ELSIF cardinality(v_candidate_ids) > 1 THEN
    RAISE EXCEPTION 'Ambiguous streak rule history for period'
      USING ERRCODE = '23514',
        DETAIL = format(
          'gym_member_id=%s, period_start=%s, candidate_ids=%s',
          p_gym_member_id,
          p_period_start,
          v_candidate_ids
        );
  END IF;

  SELECT * INTO STRICT v_rule
  FROM public.member_streak_rules
  WHERE id = v_candidate_ids[1]
    AND gym_id = v_gym_id
    AND gym_member_id = p_gym_member_id
  FOR SHARE;

  RETURN v_rule;
END;
$$;

REVOKE ALL ON FUNCTION private.resolve_streak_rule_for_period(UUID, DATE)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.resolve_streak_rule_for_period(UUID, DATE)
  TO postgres, service_role;

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

  -- An existing period owns immutable rule/timezone/target snapshots. Replay
  -- never resolves it again and historical ensure calls have no lifecycle side effect.
  SELECT id INTO v_period_id
  FROM public.streak_periods
  WHERE gym_id = v_projection.gym_id
    AND gym_member_id = p_gym_member_id
    AND period_start = p_period_start
  FOR UPDATE;
  IF FOUND THEN
    RETURN v_period_id;
  END IF;

  v_rule := private.resolve_streak_rule_for_period(
    p_gym_member_id,
    p_period_start
  );
  v_period_start_at := private.streak_period_boundary(p_period_start, v_rule.timezone);
  v_period_end_at := private.streak_period_boundary(p_period_start + 7, v_rule.timezone);

  IF p_as_of >= v_period_end_at THEN
    IF v_rule.starts_at > v_period_start_at THEN
      v_period_status := 'NOT_ELIGIBLE';
      v_reason := 'PARTIAL_INITIAL_PERIOD';
      v_finalized_at := p_as_of;
    ELSIF NOT private.is_streak_period_eligible(
      v_rule.gym_id,
      p_gym_member_id,
      v_period_start_at
    ) THEN
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

REVOKE ALL ON FUNCTION private.ensure_streak_period(UUID, DATE, TIMESTAMPTZ)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.ensure_streak_period(UUID, DATE, TIMESTAMPTZ)
  TO postgres, service_role;
