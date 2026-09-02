-- YtuFit v2.0.2: membership plans, membership history and attendance.
-- All state-changing operations below are server-side commands.  The tables
-- intentionally have no client INSERT/UPDATE/DELETE policies.

CREATE TYPE public.membership_access_type AS ENUM (
  'WEEKLY_FREQUENCY',
  'MONTHLY_LIMIT',
  'ACCESS_COUNT',
  'UNLIMITED'
);

CREATE TYPE public.membership_frequency_period AS ENUM ('WEEK', 'MONTH');
CREATE TYPE public.membership_plan_status AS ENUM ('ACTIVE', 'INACTIVE');
CREATE TYPE public.membership_status AS ENUM ('ACTIVE', 'EXPIRED', 'CANCELLED', 'SUSPENDED');
CREATE TYPE public.attendance_method AS ENUM ('QR', 'WORKOUT_STARTED', 'WORKOUT_COMPLETED', 'MANUAL');
CREATE TYPE public.attendance_status AS ENUM ('VALID', 'CANCELLED');

CREATE TABLE public.membership_plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  gym_id UUID NOT NULL REFERENCES public.gyms(id) ON DELETE CASCADE,
  name TEXT NOT NULL CHECK (length(btrim(name)) > 0),
  description TEXT NULL,
  access_type public.membership_access_type NOT NULL,
  access_limit INTEGER NULL,
  frequency_period public.membership_frequency_period NULL,
  target INTEGER NULL,
  price NUMERIC(12, 2) NOT NULL CHECK (price >= 0),
  currency TEXT NOT NULL DEFAULT 'ARS' CHECK (currency ~ '^[A-Z]{3}$'),
  duration_days INTEGER NOT NULL CHECK (duration_days > 0),
  status public.membership_plan_status NOT NULL DEFAULT 'ACTIVE',
  created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
  deleted_at TIMESTAMPTZ NULL,
  CONSTRAINT membership_plans_id_gym_key UNIQUE (id, gym_id),
  CONSTRAINT membership_plans_access_configuration_check CHECK (
    (access_type = 'UNLIMITED'
      AND access_limit IS NULL AND frequency_period IS NULL AND target IS NULL)
    OR (access_type = 'WEEKLY_FREQUENCY'
      AND access_limit IS NULL AND frequency_period = 'WEEK' AND target > 0)
    OR (access_type = 'MONTHLY_LIMIT'
      AND access_limit IS NULL AND frequency_period = 'MONTH' AND target > 0)
    OR (access_type = 'ACCESS_COUNT'
      AND access_limit > 0 AND frequency_period IS NULL AND target IS NULL)
  ),
  CONSTRAINT membership_plans_deleted_status_check CHECK (
    (deleted_at IS NULL AND status = 'ACTIVE')
    OR (deleted_at IS NOT NULL AND status = 'INACTIVE')
  )
);

CREATE INDEX idx_membership_plans_gym_id ON public.membership_plans(gym_id);
CREATE UNIQUE INDEX idx_membership_plans_active_name
  ON public.membership_plans (gym_id, lower(name))
  WHERE status = 'ACTIVE' AND deleted_at IS NULL;

CREATE TABLE public.memberships (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  gym_id UUID NOT NULL REFERENCES public.gyms(id) ON DELETE CASCADE,
  gym_member_id UUID NOT NULL,
  membership_plan_id UUID NOT NULL,
  status public.membership_status NOT NULL DEFAULT 'ACTIVE',
  starts_at TIMESTAMPTZ NOT NULL,
  ends_at TIMESTAMPTZ NOT NULL,
  contracted_price NUMERIC(12, 2) NOT NULL CHECK (contracted_price >= 0),
  currency TEXT NOT NULL CHECK (currency ~ '^[A-Z]{3}$'),
  access_limit_snapshot INTEGER NULL,
  access_type_snapshot public.membership_access_type NOT NULL,
  target_snapshot INTEGER NULL,
  period_snapshot public.membership_frequency_period NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
  cancelled_at TIMESTAMPTZ NULL,
  cancellation_reason TEXT NULL,
  CONSTRAINT memberships_id_gym_key UNIQUE (id, gym_id),
  CONSTRAINT memberships_gym_member_fk FOREIGN KEY (gym_member_id, gym_id)
    REFERENCES public.gym_members (id, gym_id) ON DELETE RESTRICT,
  CONSTRAINT memberships_plan_fk FOREIGN KEY (membership_plan_id, gym_id)
    REFERENCES public.membership_plans (id, gym_id) ON DELETE RESTRICT,
  CONSTRAINT memberships_dates_check CHECK (ends_at > starts_at),
  CONSTRAINT memberships_snapshot_check CHECK (
    (access_type_snapshot = 'UNLIMITED'
      AND access_limit_snapshot IS NULL AND period_snapshot IS NULL AND target_snapshot IS NULL)
    OR (access_type_snapshot = 'WEEKLY_FREQUENCY'
      AND access_limit_snapshot IS NULL AND period_snapshot = 'WEEK' AND target_snapshot > 0)
    OR (access_type_snapshot = 'MONTHLY_LIMIT'
      AND access_limit_snapshot IS NULL AND period_snapshot = 'MONTH' AND target_snapshot > 0)
    OR (access_type_snapshot = 'ACCESS_COUNT'
      AND access_limit_snapshot > 0 AND period_snapshot IS NULL AND target_snapshot IS NULL)
  ),
  CONSTRAINT memberships_cancellation_check CHECK (
    (status = 'CANCELLED' AND cancelled_at IS NOT NULL AND length(btrim(cancellation_reason)) > 0)
    OR (status <> 'CANCELLED' AND cancelled_at IS NULL AND cancellation_reason IS NULL)
  )
);

CREATE INDEX idx_memberships_gym_member_id ON public.memberships(gym_id, gym_member_id);
CREATE INDEX idx_memberships_plan_id ON public.memberships(gym_id, membership_plan_id);
CREATE UNIQUE INDEX idx_memberships_one_active_per_member
  ON public.memberships (gym_id, gym_member_id)
  WHERE status = 'ACTIVE';

CREATE TABLE public.attendances (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  gym_id UUID NOT NULL REFERENCES public.gyms(id) ON DELETE CASCADE,
  gym_member_id UUID NOT NULL,
  membership_id UUID NULL,
  attendance_date DATE NOT NULL,
  occurred_at TIMESTAMPTZ NOT NULL,
  method public.attendance_method NOT NULL,
  status public.attendance_status NOT NULL DEFAULT 'VALID',
  source_reference TEXT NULL,
  created_by UUID NULL REFERENCES auth.users(id) ON DELETE SET NULL,
  cancellation_reason TEXT NULL,
  cancelled_by UUID NULL REFERENCES auth.users(id) ON DELETE SET NULL,
  cancelled_at TIMESTAMPTZ NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
  CONSTRAINT attendances_gym_member_fk FOREIGN KEY (gym_member_id, gym_id)
    REFERENCES public.gym_members (id, gym_id) ON DELETE RESTRICT,
  CONSTRAINT attendances_membership_fk FOREIGN KEY (membership_id, gym_id)
    REFERENCES public.memberships (id, gym_id) ON DELETE RESTRICT,
  CONSTRAINT attendances_cancellation_check CHECK (
    (status = 'CANCELLED'
      AND cancelled_by IS NOT NULL
      AND cancelled_at IS NOT NULL
      AND length(btrim(cancellation_reason)) > 0)
    OR (status = 'VALID'
      AND cancelled_by IS NULL
      AND cancelled_at IS NULL
      AND cancellation_reason IS NULL)
  )
);

CREATE INDEX idx_attendances_member_date ON public.attendances(gym_id, gym_member_id, attendance_date);
CREATE INDEX idx_attendances_membership_id ON public.attendances(gym_id, membership_id);
CREATE UNIQUE INDEX idx_attendances_one_valid_per_local_day
  ON public.attendances (gym_id, gym_member_id, attendance_date)
  WHERE status = 'VALID';

CREATE TRIGGER trg_membership_plans_updated_at
  BEFORE UPDATE ON public.membership_plans
  FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();
CREATE TRIGGER trg_memberships_updated_at
  BEFORE UPDATE ON public.memberships
  FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();
CREATE TRIGGER trg_attendances_updated_at
  BEFORE UPDATE ON public.attendances
  FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();

-- Direct writes remain prohibited even for a role which happens to receive a
-- table grant later.  Commands set a transaction-local marker while mutating.
CREATE OR REPLACE FUNCTION private.guard_membership_plan_update()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
  IF (SELECT auth.uid()) IS NOT NULL
     AND COALESCE(current_setting('ytufit.command', true), '') <> 'membership_plan' THEN
    RAISE EXCEPTION 'Membership plan changes require a server-side command';
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION private.guard_membership_update()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
  IF (SELECT auth.uid()) IS NOT NULL
     AND COALESCE(current_setting('ytufit.command', true), '') <> 'membership' THEN
    RAISE EXCEPTION 'Membership changes require a server-side command';
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION private.guard_attendance_update()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
  IF (SELECT auth.uid()) IS NOT NULL
     AND COALESCE(current_setting('ytufit.command', true), '') <> 'attendance' THEN
    RAISE EXCEPTION 'Attendance changes require a server-side command';
  END IF;
  IF NEW.gym_id <> OLD.gym_id
     OR NEW.gym_member_id <> OLD.gym_member_id
     OR NEW.membership_id IS DISTINCT FROM OLD.membership_id
     OR NEW.attendance_date <> OLD.attendance_date
     OR NEW.occurred_at <> OLD.occurred_at
     OR NEW.method <> OLD.method
     OR NEW.created_by IS DISTINCT FROM OLD.created_by
     OR NEW.created_at <> OLD.created_at THEN
    RAISE EXCEPTION 'Attendance identity and event fields are immutable';
  END IF;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION private.guard_membership_plan_update() FROM PUBLIC;
REVOKE ALL ON FUNCTION private.guard_membership_update() FROM PUBLIC;
REVOKE ALL ON FUNCTION private.guard_attendance_update() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION private.guard_membership_plan_update() TO postgres, service_role;
GRANT EXECUTE ON FUNCTION private.guard_membership_update() TO postgres, service_role;
GRANT EXECUTE ON FUNCTION private.guard_attendance_update() TO postgres, service_role;

CREATE TRIGGER trg_membership_plans_guard_update
  BEFORE UPDATE ON public.membership_plans
  FOR EACH ROW EXECUTE FUNCTION private.guard_membership_plan_update();
CREATE TRIGGER trg_memberships_guard_update
  BEFORE UPDATE ON public.memberships
  FOR EACH ROW EXECUTE FUNCTION private.guard_membership_update();
CREATE TRIGGER trg_attendances_guard_update
  BEFORE UPDATE ON public.attendances
  FOR EACH ROW EXECUTE FUNCTION private.guard_attendance_update();

ALTER TABLE public.membership_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.membership_plans FORCE ROW LEVEL SECURITY;
ALTER TABLE public.memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.memberships FORCE ROW LEVEL SECURITY;
ALTER TABLE public.attendances ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendances FORCE ROW LEVEL SECURITY;

CREATE POLICY membership_plans_select_admin ON public.membership_plans
  FOR SELECT TO authenticated
  USING (private.has_gym_role(gym_id, 'GYM_ADMIN') OR private.is_platform_admin());
CREATE POLICY membership_plans_select_own_contract ON public.membership_plans
  FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.memberships m
    JOIN public.gym_members gm ON gm.id = m.gym_member_id AND gm.gym_id = m.gym_id
    WHERE m.membership_plan_id = membership_plans.id
      AND m.gym_id = membership_plans.gym_id
      AND gm.user_id = (SELECT auth.uid())
  ));

CREATE POLICY memberships_select_own ON public.memberships
  FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.gym_members gm
    WHERE gm.id = memberships.gym_member_id
      AND gm.gym_id = memberships.gym_id
      AND gm.user_id = (SELECT auth.uid())
  ));
CREATE POLICY memberships_select_admin ON public.memberships
  FOR SELECT TO authenticated
  USING (private.has_gym_role(gym_id, 'GYM_ADMIN') OR private.is_platform_admin());

CREATE POLICY attendances_select_own ON public.attendances
  FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.gym_members gm
    WHERE gm.id = attendances.gym_member_id
      AND gm.gym_id = attendances.gym_id
      AND gm.user_id = (SELECT auth.uid())
  ));
CREATE POLICY attendances_select_admin ON public.attendances
  FOR SELECT TO authenticated
  USING (private.has_gym_role(gym_id, 'GYM_ADMIN') OR private.is_platform_admin());

REVOKE INSERT, UPDATE, DELETE ON public.membership_plans, public.memberships, public.attendances FROM anon, authenticated;
GRANT SELECT ON public.membership_plans, public.memberships, public.attendances TO authenticated;
GRANT USAGE ON TYPE public.membership_access_type, public.membership_frequency_period,
  public.membership_plan_status, public.membership_status, public.attendance_method,
  public.attendance_status TO authenticated, service_role;

CREATE OR REPLACE FUNCTION private.assert_gym_admin(p_gym_id UUID)
RETURNS UUID LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE v_actor UUID := (SELECT auth.uid());
BEGIN
  IF v_actor IS NULL OR NOT private.has_gym_role(p_gym_id, 'GYM_ADMIN') THEN
    RAISE EXCEPTION 'Gym administrator authorization required' USING ERRCODE = '42501';
  END IF;
  RETURN v_actor;
END;
$$;
REVOKE ALL ON FUNCTION private.assert_gym_admin(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION private.assert_gym_admin(UUID) TO postgres, service_role;

CREATE OR REPLACE FUNCTION public.create_membership_plan(
  p_gym_id UUID, p_name TEXT, p_description TEXT,
  p_access_type public.membership_access_type, p_access_limit INTEGER,
  p_frequency_period public.membership_frequency_period, p_target INTEGER,
  p_price NUMERIC, p_currency TEXT, p_duration_days INTEGER
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE v_id UUID;
BEGIN
  PERFORM private.assert_gym_admin(p_gym_id);
  INSERT INTO public.membership_plans (
    gym_id, name, description, access_type, access_limit, frequency_period,
    target, price, currency, duration_days
  ) VALUES (
    p_gym_id, p_name, p_description, p_access_type, p_access_limit,
    p_frequency_period, p_target, p_price, p_currency, p_duration_days
  ) RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.update_membership_plan(
  p_plan_id UUID, p_name TEXT, p_description TEXT,
  p_access_type public.membership_access_type, p_access_limit INTEGER,
  p_frequency_period public.membership_frequency_period, p_target INTEGER,
  p_price NUMERIC, p_currency TEXT, p_duration_days INTEGER
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE v_gym_id UUID; v_id UUID;
BEGIN
  SELECT gym_id INTO v_gym_id FROM public.membership_plans WHERE id = p_plan_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Membership plan not found' USING ERRCODE = 'P0002'; END IF;
  PERFORM private.assert_gym_admin(v_gym_id);
  PERFORM set_config('ytufit.command', 'membership_plan', true);
  UPDATE public.membership_plans SET
    name = p_name, description = p_description, access_type = p_access_type,
    access_limit = p_access_limit, frequency_period = p_frequency_period,
    target = p_target, price = p_price, currency = p_currency,
    duration_days = p_duration_days
  WHERE id = p_plan_id
  RETURNING id INTO v_id;
  PERFORM set_config('ytufit.command', '', true);
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.archive_membership_plan(p_plan_id UUID)
RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE v_gym_id UUID; v_id UUID;
BEGIN
  SELECT gym_id INTO v_gym_id FROM public.membership_plans WHERE id = p_plan_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Membership plan not found' USING ERRCODE = 'P0002'; END IF;
  PERFORM private.assert_gym_admin(v_gym_id);
  PERFORM set_config('ytufit.command', 'membership_plan', true);
  UPDATE public.membership_plans
    SET status = 'INACTIVE', deleted_at = clock_timestamp()
    WHERE id = p_plan_id RETURNING id INTO v_id;
  PERFORM set_config('ytufit.command', '', true);
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.create_membership(
  p_gym_member_id UUID, p_membership_plan_id UUID, p_starts_at TIMESTAMPTZ DEFAULT NULL
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_actor UUID; v_gym_id UUID; v_start TIMESTAMPTZ; v_id UUID;
  v_plan public.membership_plans%ROWTYPE;
BEGIN
  SELECT gym_id INTO v_gym_id FROM public.gym_members WHERE id = p_gym_member_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Gym member not found' USING ERRCODE = 'P0002'; END IF;
  v_actor := private.assert_gym_admin(v_gym_id);
  SELECT * INTO v_plan FROM public.membership_plans
    WHERE id = p_membership_plan_id AND gym_id = v_gym_id
      AND status = 'ACTIVE' AND deleted_at IS NULL FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Membership plan does not belong to this gym or is inactive' USING ERRCODE = '23503'; END IF;
  IF EXISTS (SELECT 1 FROM public.memberships WHERE gym_member_id = p_gym_member_id AND gym_id = v_gym_id AND status = 'ACTIVE') THEN
    RAISE EXCEPTION 'Gym member already has an active membership' USING ERRCODE = '23505';
  END IF;
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
  IF v_old.status = 'ACTIVE' THEN RAISE EXCEPTION 'Active membership cannot be renewed' USING ERRCODE = '55000'; END IF;
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
  SELECT gym_id INTO v_gym_id FROM public.memberships WHERE id = p_membership_id AND status = 'SUSPENDED' FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Only a suspended membership can be resumed' USING ERRCODE = '55000'; END IF;
  PERFORM private.assert_gym_admin(v_gym_id);
  PERFORM set_config('ytufit.command', 'membership', true);
  UPDATE public.memberships SET status = 'ACTIVE' WHERE id = p_membership_id RETURNING id INTO v_id;
  PERFORM set_config('ytufit.command', '', true);
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.cancel_membership(p_membership_id UUID, p_reason TEXT)
RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE v_gym_id UUID; v_id UUID;
BEGIN
  IF length(btrim(COALESCE(p_reason, ''))) = 0 THEN RAISE EXCEPTION 'Reason is required' USING ERRCODE = '22023'; END IF;
  SELECT gym_id INTO v_gym_id FROM public.memberships
    WHERE id = p_membership_id AND status IN ('ACTIVE', 'SUSPENDED') FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Only active or suspended memberships can be cancelled' USING ERRCODE = '55000'; END IF;
  PERFORM private.assert_gym_admin(v_gym_id);
  PERFORM set_config('ytufit.command', 'membership', true);
  UPDATE public.memberships SET status = 'CANCELLED', cancelled_at = clock_timestamp(),
    cancellation_reason = p_reason WHERE id = p_membership_id RETURNING id INTO v_id;
  PERFORM set_config('ytufit.command', '', true);
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.register_attendance(
  p_gym_member_id UUID, p_occurred_at TIMESTAMPTZ,
  p_method public.attendance_method, p_membership_id UUID DEFAULT NULL,
  p_source_reference TEXT DEFAULT NULL
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_actor UUID := (SELECT auth.uid()); v_gym_id UUID; v_timezone TEXT;
  v_membership public.memberships%ROWTYPE; v_date DATE; v_id UUID;
  v_count INTEGER; v_week_start DATE; v_month_start DATE;
BEGIN
  IF v_actor IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501'; END IF;
  SELECT gm.gym_id, g.timezone INTO v_gym_id, v_timezone
    FROM public.gym_members gm JOIN public.gyms g ON g.id = gm.gym_id
    WHERE gm.id = p_gym_member_id AND gm.status = 'ACTIVE'
      AND (gm.user_id = v_actor OR private.has_gym_role(gm.gym_id, 'GYM_ADMIN'))
    FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Active gym member or authorization not found' USING ERRCODE = '42501'; END IF;
  IF p_occurred_at IS NULL THEN RAISE EXCEPTION 'occurred_at is required' USING ERRCODE = '22023'; END IF;
  v_date := (p_occurred_at AT TIME ZONE v_timezone)::date;
  IF p_membership_id IS NULL THEN
    SELECT * INTO v_membership FROM public.memberships
      WHERE gym_member_id = p_gym_member_id AND gym_id = v_gym_id
        AND status = 'ACTIVE' AND starts_at <= clock_timestamp() AND ends_at > clock_timestamp()
      ORDER BY starts_at DESC LIMIT 1 FOR UPDATE;
  ELSE
    SELECT * INTO v_membership FROM public.memberships
      WHERE id = p_membership_id AND gym_member_id = p_gym_member_id
        AND gym_id = v_gym_id FOR UPDATE;
    IF FOUND AND (v_membership.status <> 'ACTIVE'
      OR v_membership.starts_at > clock_timestamp() OR v_membership.ends_at <= clock_timestamp()) THEN
      RAISE EXCEPTION 'Membership is not active and current' USING ERRCODE = '55000';
    END IF;
  END IF;
  IF NOT FOUND THEN RAISE EXCEPTION 'An active and current membership is required' USING ERRCODE = '55000'; END IF;
  IF v_membership.access_type_snapshot = 'ACCESS_COUNT' THEN
    SELECT count(*) INTO v_count FROM public.attendances
      WHERE membership_id = v_membership.id AND status = 'VALID';
    IF v_count >= v_membership.access_limit_snapshot THEN
      RAISE EXCEPTION 'Membership access limit reached' USING ERRCODE = '55000';
    END IF;
  ELSIF v_membership.access_type_snapshot IN ('WEEKLY_FREQUENCY', 'MONTHLY_LIMIT') THEN
    IF v_membership.period_snapshot = 'WEEK' THEN
      v_week_start := date_trunc('week', v_date::timestamp)::date;
      SELECT count(*) INTO v_count FROM public.attendances
        WHERE membership_id = v_membership.id AND status = 'VALID'
          AND attendance_date >= v_week_start AND attendance_date < v_week_start + 7;
    ELSE
      v_month_start := date_trunc('month', v_date::timestamp)::date;
      SELECT count(*) INTO v_count FROM public.attendances
        WHERE membership_id = v_membership.id AND status = 'VALID'
          AND attendance_date >= v_month_start
          AND attendance_date < (v_month_start + interval '1 month')::date;
    END IF;
    IF v_count >= v_membership.target_snapshot THEN
      RAISE EXCEPTION 'Membership frequency limit reached' USING ERRCODE = '55000';
    END IF;
  END IF;
  BEGIN
    INSERT INTO public.attendances (
      gym_id, gym_member_id, membership_id, attendance_date, occurred_at,
      method, source_reference, created_by
    ) VALUES (
      v_gym_id, p_gym_member_id, v_membership.id, v_date, p_occurred_at,
      p_method, p_source_reference, v_actor
    ) RETURNING id INTO v_id;
  EXCEPTION WHEN unique_violation THEN
    RAISE EXCEPTION 'Attendance already exists for this member and local date'
      USING ERRCODE = '23505';
  END;
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.cancel_attendance(p_attendance_id UUID, p_reason TEXT)
RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE v_attendance public.attendances%ROWTYPE; v_actor UUID; v_id UUID;
BEGIN
  IF length(btrim(COALESCE(p_reason, ''))) = 0 THEN RAISE EXCEPTION 'Reason is required' USING ERRCODE = '22023'; END IF;
  SELECT * INTO v_attendance FROM public.attendances
    WHERE id = p_attendance_id AND status = 'VALID' FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Only a valid attendance can be cancelled' USING ERRCODE = '55000'; END IF;
  v_actor := private.assert_gym_admin(v_attendance.gym_id);
  PERFORM set_config('ytufit.command', 'attendance', true);
  UPDATE public.attendances SET status = 'CANCELLED', cancellation_reason = p_reason,
    cancelled_by = v_actor, cancelled_at = clock_timestamp()
    WHERE id = p_attendance_id RETURNING id INTO v_id;
  PERFORM set_config('ytufit.command', '', true);
  RETURN v_id;
END;
$$;

-- Camel-case aliases preserve the command names used by the product contract.
CREATE OR REPLACE FUNCTION public."createMembershipPlan"(p_gym_id UUID, p_name TEXT, p_description TEXT, p_access_type public.membership_access_type, p_access_limit INTEGER, p_frequency_period public.membership_frequency_period, p_target INTEGER, p_price NUMERIC, p_currency TEXT, p_duration_days INTEGER)
RETURNS UUID LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog, public
AS $$ SELECT public.create_membership_plan($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) $$;
CREATE OR REPLACE FUNCTION public."updateMembershipPlan"(p_plan_id UUID, p_name TEXT, p_description TEXT, p_access_type public.membership_access_type, p_access_limit INTEGER, p_frequency_period public.membership_frequency_period, p_target INTEGER, p_price NUMERIC, p_currency TEXT, p_duration_days INTEGER)
RETURNS UUID LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog, public
AS $$ SELECT public.update_membership_plan($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) $$;
CREATE OR REPLACE FUNCTION public."archiveMembershipPlan"(p_plan_id UUID)
RETURNS UUID LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog, public
AS $$ SELECT public.archive_membership_plan($1) $$;
CREATE OR REPLACE FUNCTION public."createMembership"(p_gym_member_id UUID, p_membership_plan_id UUID, p_starts_at TIMESTAMPTZ DEFAULT NULL)
RETURNS UUID LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog, public
AS $$ SELECT public.create_membership($1,$2,$3) $$;
CREATE OR REPLACE FUNCTION public."renewMembership"(p_membership_id UUID, p_starts_at TIMESTAMPTZ DEFAULT NULL)
RETURNS UUID LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog, public
AS $$ SELECT public.renew_membership($1,$2) $$;
CREATE OR REPLACE FUNCTION public."changeMembershipPlan"(p_membership_id UUID, p_new_plan_id UUID, p_starts_at TIMESTAMPTZ DEFAULT NULL, p_reason TEXT DEFAULT 'Plan changed')
RETURNS UUID LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog, public
AS $$ SELECT public.change_membership_plan($1,$2,$3,$4) $$;
CREATE OR REPLACE FUNCTION public."suspendMembership"(p_membership_id UUID)
RETURNS UUID LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog, public
AS $$ SELECT public.suspend_membership($1) $$;
CREATE OR REPLACE FUNCTION public."resumeMembership"(p_membership_id UUID)
RETURNS UUID LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog, public
AS $$ SELECT public.resume_membership($1) $$;
CREATE OR REPLACE FUNCTION public."cancelMembership"(p_membership_id UUID, p_reason TEXT)
RETURNS UUID LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog, public
AS $$ SELECT public.cancel_membership($1,$2) $$;
CREATE OR REPLACE FUNCTION public."registerAttendance"(p_gym_member_id UUID, p_occurred_at TIMESTAMPTZ, p_method public.attendance_method, p_membership_id UUID DEFAULT NULL, p_source_reference TEXT DEFAULT NULL)
RETURNS UUID LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog, public
AS $$ SELECT public.register_attendance($1,$2,$3,$4,$5) $$;
CREATE OR REPLACE FUNCTION public."cancelAttendance"(p_attendance_id UUID, p_reason TEXT)
RETURNS UUID LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog, public
AS $$ SELECT public.cancel_attendance($1,$2) $$;

DO $$
DECLARE f RECORD;
BEGIN
  FOR f IN
    SELECT n.nspname, p.oid::regprocedure AS signature
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname IN (
        'create_membership_plan', 'update_membership_plan', 'archive_membership_plan',
        'create_membership', 'renew_membership', 'change_membership_plan',
        'suspend_membership', 'resume_membership', 'cancel_membership',
        'register_attendance', 'cancel_attendance',
        'createMembershipPlan', 'updateMembershipPlan', 'archiveMembershipPlan',
        'createMembership', 'renewMembership', 'changeMembershipPlan',
        'suspendMembership', 'resumeMembership', 'cancelMembership',
        'registerAttendance', 'cancelAttendance'
      )
  LOOP
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC', f.signature);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated, service_role', f.signature);
  END LOOP;
END $$;
