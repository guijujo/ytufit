-- v2.0.4-2 audit follow-up. Released Membership migrations remain unchanged.
-- Status knowledge starts at the first authoritative event, never at an
-- inferred starts_at/updated_at/cancelled_at for an existing contract.
BEGIN;
LOCK TABLE public.memberships IN SHARE ROW EXCLUSIVE MODE;

CREATE TABLE public.membership_status_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_sequence BIGINT GENERATED ALWAYS AS IDENTITY UNIQUE,
  gym_id UUID NOT NULL,
  membership_id UUID NOT NULL,
  from_status public.membership_status NULL,
  to_status public.membership_status NOT NULL,
  effective_at TIMESTAMPTZ NOT NULL,
  reason TEXT NULL,
  -- Actor snapshot: deleting an auth user must not rewrite immutable history.
  changed_by UUID NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
  CONSTRAINT membership_status_history_membership_fk
    FOREIGN KEY (membership_id, gym_id)
    REFERENCES public.memberships (id, gym_id) ON DELETE RESTRICT,
  CONSTRAINT membership_status_history_transition_check
    CHECK (from_status IS NULL OR from_status <> to_status)
);

CREATE UNIQUE INDEX membership_status_history_initial_event
  ON public.membership_status_history (membership_id, gym_id)
  WHERE from_status IS NULL;
CREATE INDEX membership_status_history_lookup
  ON public.membership_status_history
  (gym_id, membership_id, effective_at DESC, event_sequence DESC);

ALTER TABLE public.membership_status_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.membership_status_history FORCE ROW LEVEL SECURITY;
REVOKE ALL ON public.membership_status_history FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON SEQUENCE public.membership_status_history_event_sequence_seq
  FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT ON public.membership_status_history TO authenticated, service_role;

-- Reuse Membership's SELECT visibility, including its Platform Admin behavior.
-- No Streak policy or private-engine privilege is broadened by this policy.
CREATE POLICY membership_status_history_select ON public.membership_status_history
  FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.memberships m
    WHERE m.id = membership_status_history.membership_id
      AND m.gym_id = membership_status_history.gym_id
  ));

CREATE FUNCTION private.reject_membership_status_history_mutation()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
  RAISE EXCEPTION 'Membership status history is immutable' USING ERRCODE = '55000';
END;
$$;
REVOKE ALL ON FUNCTION private.reject_membership_status_history_mutation()
  FROM PUBLIC, anon, authenticated, service_role;

CREATE TRIGGER membership_status_history_immutable
  BEFORE UPDATE OR DELETE ON public.membership_status_history
  FOR EACH ROW EXECUTE FUNCTION private.reject_membership_status_history_mutation();
CREATE TRIGGER membership_status_history_no_truncate
  BEFORE TRUNCATE ON public.membership_status_history
  FOR EACH STATEMENT EXECUTE FUNCTION private.reject_membership_status_history_mutation();

-- One migration-time baseline, even for ACTIVE/EXPIRED contracts. This records
-- only what is known now, and does NOT assert an earlier continuous ACTIVE span.
INSERT INTO public.membership_status_history (
  gym_id, membership_id, from_status, to_status, effective_at, reason
)
SELECT m.gym_id, m.id, NULL, m.status, baseline.effective_at, 'Migration baseline'
FROM public.memberships m
CROSS JOIN (SELECT clock_timestamp() AS effective_at OFFSET 0) baseline;

-- Only the owner-executed Membership commands below can call this helper.
-- No client-supplied GUC is an authorization mechanism for ledger writes.
CREATE FUNCTION private.record_membership_status(
  p_membership_id UUID,
  p_from_status public.membership_status,
  p_to_status public.membership_status,
  p_effective_at TIMESTAMPTZ DEFAULT NULL,
  p_reason TEXT DEFAULT NULL
) RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_membership public.memberships%ROWTYPE;
  v_previous public.membership_status_history%ROWTYPE;
  v_effective_at TIMESTAMPTZ;
BEGIN
  SELECT * INTO STRICT v_membership FROM public.memberships
  WHERE id = p_membership_id FOR UPDATE;
  SELECT * INTO v_previous FROM public.membership_status_history
  WHERE membership_id = p_membership_id AND gym_id = v_membership.gym_id
  ORDER BY effective_at DESC, event_sequence DESC LIMIT 1;
  v_effective_at := COALESCE(p_effective_at, clock_timestamp());
  IF v_membership.status <> p_to_status
     OR (v_previous.id IS NULL AND p_from_status IS NOT NULL)
     OR (v_previous.id IS NOT NULL AND
         (p_from_status IS DISTINCT FROM v_previous.to_status
          OR v_effective_at < v_previous.effective_at)) THEN
    RAISE EXCEPTION 'Inconsistent membership status transition' USING ERRCODE = '23514';
  END IF;
  INSERT INTO public.membership_status_history (
    gym_id, membership_id, from_status, to_status, effective_at, reason, changed_by
  ) VALUES (
    v_membership.gym_id, p_membership_id, p_from_status, p_to_status,
    v_effective_at, p_reason, (SELECT auth.uid())
  );
END;
$$;
REVOKE ALL ON FUNCTION private.record_membership_status(
  UUID, public.membership_status, public.membership_status, TIMESTAMPTZ, TEXT
) FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION private.is_streak_period_eligible(
  p_gym_id UUID,
  p_gym_member_id UUID,
  p_period_start_at TIMESTAMPTZ
) RETURNS BOOLEAN LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_membership_id UUID;
  v_status public.membership_status;
  v_eligible BOOLEAN := FALSE;
BEGIN
  -- Contract dates are authoritative: [starts_at, ends_at). Only contracts
  -- covering this instant need status history. No contracts means known false.
  FOR v_membership_id IN
    SELECT m.id FROM public.memberships m
    WHERE m.gym_id = p_gym_id AND m.gym_member_id = p_gym_member_id
      AND m.starts_at <= p_period_start_at AND m.ends_at > p_period_start_at
    ORDER BY m.id
  LOOP
    -- history_coverage_start = MIN(effective_at) for this membership/tenant.
    -- A missing event at/before the instant means insufficient coverage.
    -- Equal-time transitions are already effective; sequence breaks ties.
    SELECT h.to_status INTO v_status FROM public.membership_status_history h
    WHERE h.gym_id = p_gym_id AND h.membership_id = v_membership_id
      AND h.effective_at <= p_period_start_at
    ORDER BY h.effective_at DESC, h.event_sequence DESC LIMIT 1;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Insufficient membership status history'
        USING ERRCODE = '55000',
          DETAIL = format('membership_id=%s, period_start_at=%s', v_membership_id, p_period_start_at);
    END IF;
    -- Inspect every candidate before returning, so unknown coverage cannot be
    -- hidden by row ordering or by another known ACTIVE contract.
    v_eligible := v_eligible OR v_status = 'ACTIVE';
  END LOOP;
  RETURN v_eligible;
END;
$$;
REVOKE ALL ON FUNCTION private.is_streak_period_eligible(UUID, UUID, TIMESTAMPTZ)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.is_streak_period_eligible(UUID, UUID, TIMESTAMPTZ)
  TO postgres, service_role;

-- Original Membership business rules, with atomic transition recording only.
CREATE OR REPLACE FUNCTION public.create_membership(
  p_gym_member_id UUID, p_membership_plan_id UUID, p_starts_at TIMESTAMPTZ DEFAULT NULL
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_actor UUID; v_gym_id UUID; v_start TIMESTAMPTZ; v_id UUID;
  v_existing public.memberships%ROWTYPE;
  v_plan public.membership_plans%ROWTYPE;
BEGIN
  SELECT gym_id INTO v_gym_id FROM public.gym_members WHERE id = p_gym_member_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Gym member not found' USING ERRCODE = 'P0002'; END IF;
  v_actor := private.assert_gym_admin(v_gym_id);
  SELECT * INTO v_plan FROM public.membership_plans
    WHERE id = p_membership_plan_id AND gym_id = v_gym_id
      AND status = 'ACTIVE' AND deleted_at IS NULL FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Membership plan does not belong to this gym or is inactive' USING ERRCODE = '23503'; END IF;
  FOR v_existing IN
    SELECT * FROM public.memberships
    WHERE gym_member_id = p_gym_member_id AND gym_id = v_gym_id AND status = 'ACTIVE'
    FOR UPDATE
  LOOP
    IF v_existing.ends_at <= clock_timestamp() THEN
      PERFORM set_config('ytufit.command', 'membership', true);
      UPDATE public.memberships SET status = 'EXPIRED' WHERE id = v_existing.id;
      PERFORM private.record_membership_status(v_existing.id, 'ACTIVE', 'EXPIRED');
      PERFORM set_config('ytufit.command', '', true);
    ELSE
      RAISE EXCEPTION 'Gym member already has an active membership' USING ERRCODE = '23505';
    END IF;
  END LOOP;
  v_start := COALESCE(p_starts_at, clock_timestamp());
  INSERT INTO public.memberships (
    gym_id, gym_member_id, membership_plan_id, starts_at, ends_at,
    contracted_price, currency, access_limit_snapshot, access_type_snapshot,
    target_snapshot, period_snapshot
  ) VALUES (
    v_gym_id, p_gym_member_id, p_membership_plan_id, v_start,
    v_start + make_interval(days => v_plan.duration_days),
    v_plan.price, v_plan.currency, v_plan.access_limit, v_plan.access_type,
    v_plan.target, v_plan.frequency_period
  ) RETURNING id INTO v_id;
  PERFORM private.record_membership_status(v_id, NULL, 'ACTIVE');
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.renew_membership(
  p_membership_id UUID, p_starts_at TIMESTAMPTZ DEFAULT NULL
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_old public.memberships%ROWTYPE; v_plan public.membership_plans%ROWTYPE;
  v_start TIMESTAMPTZ; v_id UUID;
BEGIN
  SELECT * INTO v_old FROM public.memberships WHERE id = p_membership_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Membership not found' USING ERRCODE = 'P0002'; END IF;
  PERFORM private.assert_gym_admin(v_old.gym_id);
  IF v_old.status = 'ACTIVE' AND v_old.ends_at > clock_timestamp() THEN
    RAISE EXCEPTION 'Active membership cannot be renewed' USING ERRCODE = '55000';
  ELSIF v_old.status = 'ACTIVE' THEN
    PERFORM set_config('ytufit.command', 'membership', true);
    UPDATE public.memberships SET status = 'EXPIRED' WHERE id = v_old.id;
    PERFORM private.record_membership_status(v_old.id, 'ACTIVE', 'EXPIRED');
    PERFORM set_config('ytufit.command', '', true);
  END IF;
  IF v_old.status NOT IN ('EXPIRED', 'ACTIVE') OR
     (v_old.status = 'ACTIVE' AND v_old.ends_at > clock_timestamp()) THEN
    RAISE EXCEPTION 'Only expired memberships can be renewed' USING ERRCODE = '55000';
  END IF;
  SELECT * INTO v_plan FROM public.membership_plans
    WHERE id = v_old.membership_plan_id AND gym_id = v_old.gym_id
      AND status = 'ACTIVE' AND deleted_at IS NULL FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Membership plan is inactive' USING ERRCODE = '23503'; END IF;
  v_start := COALESCE(p_starts_at, clock_timestamp());
  INSERT INTO public.memberships (
    gym_id, gym_member_id, membership_plan_id, starts_at, ends_at,
    contracted_price, currency, access_limit_snapshot, access_type_snapshot,
    target_snapshot, period_snapshot
  ) VALUES (
    v_old.gym_id, v_old.gym_member_id, v_old.membership_plan_id, v_start,
    v_start + make_interval(days => v_plan.duration_days),
    v_plan.price, v_plan.currency, v_plan.access_limit, v_plan.access_type,
    v_plan.target, v_plan.frequency_period
  ) RETURNING id INTO v_id;
  PERFORM private.record_membership_status(v_id, NULL, 'ACTIVE');
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.change_membership_plan(
  p_membership_id UUID, p_new_plan_id UUID, p_starts_at TIMESTAMPTZ DEFAULT NULL,
  p_reason TEXT DEFAULT 'Plan changed'
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_old public.memberships%ROWTYPE; v_plan public.membership_plans%ROWTYPE;
  v_start TIMESTAMPTZ; v_id UUID;
BEGIN
  SELECT * INTO v_old FROM public.memberships WHERE id = p_membership_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Membership not found' USING ERRCODE = 'P0002'; END IF;
  PERFORM private.assert_gym_admin(v_old.gym_id);
  IF v_old.status <> 'ACTIVE' THEN RAISE EXCEPTION 'Only an active membership can change plan' USING ERRCODE = '55000'; END IF;
  SELECT * INTO v_plan FROM public.membership_plans
    WHERE id = p_new_plan_id AND gym_id = v_old.gym_id
      AND status = 'ACTIVE' AND deleted_at IS NULL FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'New membership plan does not belong to this gym or is inactive' USING ERRCODE = '23503'; END IF;
  IF p_new_plan_id = v_old.membership_plan_id THEN RAISE EXCEPTION 'Membership already uses this plan' USING ERRCODE = '22023'; END IF;
  IF length(btrim(COALESCE(p_reason, ''))) = 0 THEN RAISE EXCEPTION 'Reason is required' USING ERRCODE = '22023'; END IF;
  PERFORM set_config('ytufit.command', 'membership', true);
  UPDATE public.memberships SET status = 'CANCELLED', cancelled_at = clock_timestamp(),
    cancellation_reason = p_reason WHERE id = p_membership_id;
  PERFORM private.record_membership_status(p_membership_id, 'ACTIVE', 'CANCELLED',
    (SELECT cancelled_at FROM public.memberships WHERE id = p_membership_id), p_reason);
  PERFORM set_config('ytufit.command', '', true);
  v_start := COALESCE(p_starts_at, clock_timestamp());
  INSERT INTO public.memberships (
    gym_id, gym_member_id, membership_plan_id, starts_at, ends_at,
    contracted_price, currency, access_limit_snapshot, access_type_snapshot,
    target_snapshot, period_snapshot
  ) VALUES (
    v_old.gym_id, v_old.gym_member_id, p_new_plan_id, v_start,
    v_start + make_interval(days => v_plan.duration_days),
    v_plan.price, v_plan.currency, v_plan.access_limit, v_plan.access_type,
    v_plan.target, v_plan.frequency_period
  ) RETURNING id INTO v_id;
  PERFORM private.record_membership_status(v_id, NULL, 'ACTIVE');
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.suspend_membership(p_membership_id UUID)
RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE v_gym_id UUID; v_id UUID;
BEGIN
  SELECT gym_id INTO v_gym_id FROM public.memberships WHERE id = p_membership_id AND status = 'ACTIVE' FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Only an active membership can be suspended' USING ERRCODE = '55000'; END IF;
  PERFORM private.assert_gym_admin(v_gym_id);
  PERFORM set_config('ytufit.command', 'membership', true);
  UPDATE public.memberships SET status = 'SUSPENDED' WHERE id = p_membership_id RETURNING id INTO v_id;
  PERFORM private.record_membership_status(v_id, 'ACTIVE', 'SUSPENDED');
  PERFORM set_config('ytufit.command', '', true);
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.resume_membership(p_membership_id UUID)
RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE v_gym_id UUID; v_id UUID;
BEGIN
  SELECT gym_id INTO v_gym_id FROM public.memberships
    WHERE id = p_membership_id AND status = 'SUSPENDED' FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Only a suspended membership can be resumed' USING ERRCODE = '55000'; END IF;
  PERFORM private.assert_gym_admin(v_gym_id);
  IF EXISTS (
    SELECT 1 FROM public.memberships
    WHERE id = p_membership_id AND ends_at <= clock_timestamp()
  ) THEN
    PERFORM set_config('ytufit.command', 'membership', true);
    UPDATE public.memberships SET status = 'EXPIRED' WHERE id = p_membership_id;
    PERFORM private.record_membership_status(p_membership_id, 'SUSPENDED', 'EXPIRED');
    PERFORM set_config('ytufit.command', '', true);
    RAISE EXCEPTION 'Suspended membership has expired and must be renewed' USING ERRCODE = '55000';
  END IF;
  PERFORM set_config('ytufit.command', 'membership', true);
  UPDATE public.memberships SET status = 'ACTIVE' WHERE id = p_membership_id RETURNING id INTO v_id;
  PERFORM private.record_membership_status(v_id, 'SUSPENDED', 'ACTIVE');
  PERFORM set_config('ytufit.command', '', true);
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.cancel_membership(p_membership_id UUID, p_reason TEXT)
RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE v_gym_id UUID; v_id UUID; v_from_status public.membership_status;
BEGIN
  IF length(btrim(COALESCE(p_reason, ''))) = 0 THEN RAISE EXCEPTION 'Reason is required' USING ERRCODE = '22023'; END IF;
  SELECT gym_id, status INTO v_gym_id, v_from_status FROM public.memberships
    WHERE id = p_membership_id AND status IN ('ACTIVE', 'SUSPENDED') FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Only active or suspended memberships can be cancelled' USING ERRCODE = '55000'; END IF;
  PERFORM private.assert_gym_admin(v_gym_id);
  PERFORM set_config('ytufit.command', 'membership', true);
  UPDATE public.memberships SET status = 'CANCELLED', cancelled_at = clock_timestamp(),
    cancellation_reason = p_reason WHERE id = p_membership_id RETURNING id INTO v_id;
  PERFORM private.record_membership_status(v_id, v_from_status, 'CANCELLED',
    (SELECT cancelled_at FROM public.memberships WHERE id = v_id), p_reason);
  PERFORM set_config('ytufit.command', '', true);
  RETURN v_id;
END;
$$;

-- CREATE OR REPLACE preserves the existing command ACLs and CamelCase aliases.
COMMIT;
