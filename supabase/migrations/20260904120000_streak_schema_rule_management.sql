-- YtuFit v2.0.4-1: Streak schema and rule management.
-- This slice persists weekly streak rules, assignments, periods, freeze ledger
-- and member projections. It intentionally does not calculate streak periods
-- from attendance and does not install cron/scheduled processing.

CREATE TYPE public.streak_period_type AS ENUM ('WEEK');
CREATE TYPE public.streak_rule_status AS ENUM ('ACTIVE', 'INACTIVE', 'ARCHIVED');
CREATE TYPE public.member_streak_rule_status AS ENUM ('ACTIVE', 'SCHEDULED', 'ENDED');
CREATE TYPE public.streak_period_status AS ENUM ('OPEN', 'COMPLETED', 'FROZEN', 'MISSED', 'NOT_ELIGIBLE');
CREATE TYPE public.streak_freeze_transaction_type AS ENUM ('GRANT', 'CONSUME', 'RESTORE', 'EXPIRE');
CREATE TYPE public.streak_period_eligibility_reason AS ENUM (
  'NO_ACTIVE_MEMBERSHIP',
  'PARTIAL_INITIAL_PERIOD',
  'STREAK_NOT_ENABLED'
);

CREATE TABLE public.streak_rules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  gym_id UUID NOT NULL REFERENCES public.gyms(id) ON DELETE CASCADE,
  name TEXT NOT NULL CHECK (length(btrim(name)) > 0),
  period_type public.streak_period_type NOT NULL DEFAULT 'WEEK',
  target_days SMALLINT NOT NULL CHECK (target_days BETWEEN 1 AND 7),
  max_freezes SMALLINT NOT NULL DEFAULT 2 CHECK (max_freezes BETWEEN 0 AND 2),
  week_starts_on SMALLINT NOT NULL DEFAULT 1 CHECK (week_starts_on = 1),
  timezone TEXT NOT NULL CHECK (length(btrim(timezone)) > 0),
  status public.streak_rule_status NOT NULL DEFAULT 'ACTIVE',
  created_by UUID NULL REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
  deleted_at TIMESTAMPTZ NULL,
  CONSTRAINT streak_rules_id_gym_key UNIQUE (id, gym_id),
  CONSTRAINT streak_rules_week_only_check CHECK (period_type = 'WEEK'),
  CONSTRAINT streak_rules_deleted_status_check CHECK (
    deleted_at IS NULL OR status = 'ARCHIVED'
  )
);

CREATE INDEX idx_streak_rules_gym_id ON public.streak_rules(gym_id);
CREATE INDEX idx_streak_rules_status ON public.streak_rules(status);
CREATE UNIQUE INDEX idx_streak_rules_active_name
  ON public.streak_rules (gym_id, lower(name))
  WHERE status = 'ACTIVE' AND deleted_at IS NULL;

CREATE TABLE public.member_streak_rules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  gym_id UUID NOT NULL,
  gym_member_id UUID NOT NULL,
  streak_rule_id UUID NOT NULL,
  target_days SMALLINT NOT NULL CHECK (target_days BETWEEN 1 AND 7),
  max_freezes SMALLINT NOT NULL CHECK (max_freezes BETWEEN 0 AND 2),
  period_type public.streak_period_type NOT NULL,
  week_starts_on SMALLINT NOT NULL CHECK (week_starts_on = 1),
  timezone TEXT NOT NULL CHECK (length(btrim(timezone)) > 0),
  starts_at TIMESTAMPTZ NOT NULL,
  ends_at TIMESTAMPTZ NULL,
  status public.member_streak_rule_status NOT NULL DEFAULT 'ACTIVE',
  assigned_by UUID NULL REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
  CONSTRAINT member_streak_rules_id_gym_key UNIQUE (id, gym_id),
  CONSTRAINT member_streak_rules_id_gym_member_key UNIQUE (id, gym_id, gym_member_id),
  CONSTRAINT member_streak_rules_member_fk FOREIGN KEY (gym_member_id, gym_id)
    REFERENCES public.gym_members (id, gym_id) ON DELETE RESTRICT,
  CONSTRAINT member_streak_rules_rule_fk FOREIGN KEY (streak_rule_id, gym_id)
    REFERENCES public.streak_rules (id, gym_id) ON DELETE RESTRICT,
  CONSTRAINT member_streak_rules_week_only_check CHECK (period_type = 'WEEK'),
  CONSTRAINT member_streak_rules_status_dates_check CHECK (
    (status = 'ACTIVE' AND (ends_at IS NULL OR ends_at > starts_at))
    OR (status = 'SCHEDULED' AND ends_at IS NULL)
    OR (status = 'ENDED' AND ends_at IS NOT NULL AND ends_at >= starts_at)
  )
);

CREATE UNIQUE INDEX idx_member_streak_rules_one_active
  ON public.member_streak_rules (gym_id, gym_member_id)
  WHERE status = 'ACTIVE';
CREATE UNIQUE INDEX idx_member_streak_rules_one_scheduled
  ON public.member_streak_rules (gym_id, gym_member_id)
  WHERE status = 'SCHEDULED';
CREATE INDEX idx_member_streak_rules_member ON public.member_streak_rules(gym_id, gym_member_id);
CREATE INDEX idx_member_streak_rules_rule ON public.member_streak_rules(gym_id, streak_rule_id);

CREATE TABLE public.streak_periods (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  gym_id UUID NOT NULL,
  gym_member_id UUID NOT NULL,
  member_streak_rule_id UUID NOT NULL,
  period_start DATE NOT NULL,
  period_end DATE NOT NULL,
  period_start_at TIMESTAMPTZ NOT NULL,
  period_end_at TIMESTAMPTZ NOT NULL,
  timezone_snapshot TEXT NOT NULL CHECK (length(btrim(timezone_snapshot)) > 0),
  target_days_snapshot SMALLINT NOT NULL CHECK (target_days_snapshot BETWEEN 1 AND 7),
  valid_days SMALLINT NOT NULL DEFAULT 0 CHECK (valid_days BETWEEN 0 AND 7),
  status public.streak_period_status NOT NULL DEFAULT 'OPEN',
  eligibility_reason public.streak_period_eligibility_reason NULL,
  freeze_applied BOOLEAN NOT NULL DEFAULT FALSE,
  finalized_at TIMESTAMPTZ NULL,
  last_recalculated_at TIMESTAMPTZ NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
  CONSTRAINT streak_periods_id_gym_key UNIQUE (id, gym_id),
  CONSTRAINT streak_periods_id_gym_member_key UNIQUE (id, gym_id, gym_member_id),
  CONSTRAINT streak_periods_member_fk FOREIGN KEY (gym_member_id, gym_id)
    REFERENCES public.gym_members (id, gym_id) ON DELETE RESTRICT,
  CONSTRAINT streak_periods_member_rule_fk FOREIGN KEY (member_streak_rule_id, gym_id, gym_member_id)
    REFERENCES public.member_streak_rules (id, gym_id, gym_member_id) ON DELETE RESTRICT,
  CONSTRAINT streak_periods_week_length_check CHECK (period_end = period_start + 6),
  CONSTRAINT streak_periods_bounds_order_check CHECK (period_end_at > period_start_at),
  CONSTRAINT streak_periods_not_eligible_reason_check CHECK (
    (status = 'NOT_ELIGIBLE' AND eligibility_reason IS NOT NULL)
    OR (status <> 'NOT_ELIGIBLE' AND eligibility_reason IS NULL)
  ),
  CONSTRAINT streak_periods_finalized_status_check CHECK (
    (status = 'OPEN' AND finalized_at IS NULL)
    OR (status <> 'OPEN' AND finalized_at IS NOT NULL)
  )
);

CREATE UNIQUE INDEX idx_streak_periods_member_period
  ON public.streak_periods (gym_id, gym_member_id, period_start);
CREATE INDEX idx_streak_periods_member_rule ON public.streak_periods(gym_id, member_streak_rule_id);
CREATE INDEX idx_streak_periods_status ON public.streak_periods(gym_id, status);

CREATE TABLE public.streak_freeze_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  gym_id UUID NOT NULL,
  gym_member_id UUID NOT NULL,
  streak_period_id UUID NULL,
  transaction_type public.streak_freeze_transaction_type NOT NULL,
  amount SMALLINT NOT NULL CHECK (amount > 0),
  reason TEXT NULL CHECK (reason IS NULL OR length(btrim(reason)) > 0),
  source_transaction_id UUID NULL REFERENCES public.streak_freeze_transactions(id) ON DELETE RESTRICT,
  reversed_by_transaction_id UUID NULL REFERENCES public.streak_freeze_transactions(id) ON DELETE RESTRICT,
  created_by UUID NULL REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  CONSTRAINT streak_freeze_transactions_id_gym_key UNIQUE (id, gym_id),
  CONSTRAINT streak_freeze_transactions_member_fk FOREIGN KEY (gym_member_id, gym_id)
    REFERENCES public.gym_members (id, gym_id) ON DELETE RESTRICT,
  CONSTRAINT streak_freeze_transactions_period_fk FOREIGN KEY (streak_period_id, gym_id, gym_member_id)
    REFERENCES public.streak_periods (id, gym_id, gym_member_id) ON DELETE RESTRICT,
  CONSTRAINT streak_freeze_transactions_restore_source_check CHECK (
    (transaction_type = 'RESTORE' AND source_transaction_id IS NOT NULL)
    OR (transaction_type <> 'RESTORE')
  ),
  CONSTRAINT streak_freeze_transactions_reversal_check CHECK (
    transaction_type = 'CONSUME' OR reversed_by_transaction_id IS NULL
  )
);

CREATE UNIQUE INDEX idx_streak_freeze_one_effective_consume_per_period
  ON public.streak_freeze_transactions (gym_id, gym_member_id, streak_period_id)
  WHERE transaction_type = 'CONSUME'
    AND streak_period_id IS NOT NULL
    AND reversed_by_transaction_id IS NULL;
CREATE UNIQUE INDEX idx_streak_freeze_one_restore_per_source
  ON public.streak_freeze_transactions (source_transaction_id)
  WHERE transaction_type = 'RESTORE';
CREATE INDEX idx_streak_freeze_transactions_member ON public.streak_freeze_transactions(gym_id, gym_member_id, created_at DESC);

CREATE TABLE public.member_streaks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  gym_id UUID NOT NULL,
  gym_member_id UUID NOT NULL,
  current_streak INTEGER NOT NULL DEFAULT 0 CHECK (current_streak >= 0),
  best_streak INTEGER NOT NULL DEFAULT 0 CHECK (best_streak >= 0),
  freezes_available SMALLINT NOT NULL DEFAULT 0 CHECK (freezes_available >= 0),
  current_period_id UUID NULL,
  last_completed_period_start DATE NULL,
  calculated_through DATE NULL,
  version BIGINT NOT NULL DEFAULT 0 CHECK (version >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
  CONSTRAINT member_streaks_gym_member_key UNIQUE (gym_id, gym_member_id),
  CONSTRAINT member_streaks_member_fk FOREIGN KEY (gym_member_id, gym_id)
    REFERENCES public.gym_members (id, gym_id) ON DELETE RESTRICT,
  CONSTRAINT member_streaks_current_period_fk FOREIGN KEY (current_period_id, gym_id, gym_member_id)
    REFERENCES public.streak_periods (id, gym_id, gym_member_id) ON DELETE RESTRICT,
  CONSTRAINT member_streaks_best_at_least_current_check CHECK (best_streak >= current_streak)
);

CREATE INDEX idx_member_streaks_member ON public.member_streaks(gym_id, gym_member_id);

CREATE TRIGGER trg_streak_rules_updated_at
  BEFORE UPDATE ON public.streak_rules
  FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();
CREATE TRIGGER trg_member_streak_rules_updated_at
  BEFORE UPDATE ON public.member_streak_rules
  FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();
CREATE TRIGGER trg_streak_periods_updated_at
  BEFORE UPDATE ON public.streak_periods
  FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();
CREATE TRIGGER trg_member_streaks_updated_at
  BEFORE UPDATE ON public.member_streaks
  FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();

CREATE OR REPLACE FUNCTION private.is_valid_timezone(p_timezone TEXT)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM pg_catalog.pg_timezone_names tzn
    WHERE tzn.name = btrim(p_timezone)
  );
$$;

CREATE OR REPLACE FUNCTION private.next_monday_boundary(p_from TIMESTAMPTZ, p_timezone TEXT)
RETURNS TIMESTAMPTZ LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
  SELECT ((date_trunc('week', p_from AT TIME ZONE p_timezone)::date + 7)::timestamp AT TIME ZONE p_timezone);
$$;

CREATE OR REPLACE FUNCTION private.validate_streak_rule_config()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
  NEW.timezone := btrim(NEW.timezone);
  IF NOT private.is_valid_timezone(NEW.timezone) THEN
    RAISE EXCEPTION 'Invalid streak rule timezone' USING ERRCODE = '22023';
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION private.validate_member_streak_rule_snapshot()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
  NEW.timezone := btrim(NEW.timezone);
  IF NOT private.is_valid_timezone(NEW.timezone) THEN
    RAISE EXCEPTION 'Invalid member streak rule timezone snapshot' USING ERRCODE = '22023';
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION private.validate_streak_period_snapshot()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
  NEW.timezone_snapshot := btrim(NEW.timezone_snapshot);
  IF NOT private.is_valid_timezone(NEW.timezone_snapshot) THEN
    RAISE EXCEPTION 'Invalid streak period timezone snapshot' USING ERRCODE = '22023';
  END IF;
  IF EXTRACT(ISODOW FROM NEW.period_start)::INTEGER <> 1 THEN
    RAISE EXCEPTION 'Streak periods must start on Monday' USING ERRCODE = '22023';
  END IF;
  NEW.period_start_at := COALESCE(
    NEW.period_start_at,
    NEW.period_start::TIMESTAMP AT TIME ZONE NEW.timezone_snapshot
  );
  NEW.period_end_at := COALESCE(
    NEW.period_end_at,
    (NEW.period_end + 1)::TIMESTAMP AT TIME ZONE NEW.timezone_snapshot
  );
  IF (NEW.period_start_at AT TIME ZONE NEW.timezone_snapshot)::DATE <> NEW.period_start
     OR (NEW.period_end_at AT TIME ZONE NEW.timezone_snapshot)::DATE <> NEW.period_end + 1 THEN
    RAISE EXCEPTION 'Streak period UTC bounds must match local period dates' USING ERRCODE = '22023';
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION private.validate_streak_freeze_transaction()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_source public.streak_freeze_transactions%ROWTYPE;
  v_reversal public.streak_freeze_transactions%ROWTYPE;
BEGIN
  IF TG_OP = 'UPDATE' THEN
    IF OLD.gym_id IS DISTINCT FROM NEW.gym_id
       OR OLD.gym_member_id IS DISTINCT FROM NEW.gym_member_id
       OR OLD.streak_period_id IS DISTINCT FROM NEW.streak_period_id
       OR OLD.transaction_type IS DISTINCT FROM NEW.transaction_type
       OR OLD.amount IS DISTINCT FROM NEW.amount
       OR OLD.reason IS DISTINCT FROM NEW.reason
       OR OLD.source_transaction_id IS DISTINCT FROM NEW.source_transaction_id
       OR OLD.created_by IS DISTINCT FROM NEW.created_by
       OR OLD.created_at IS DISTINCT FROM NEW.created_at
       OR OLD.metadata IS DISTINCT FROM NEW.metadata THEN
      RAISE EXCEPTION 'Streak freeze transaction ledger rows are immutable' USING ERRCODE = '55000';
    END IF;
    IF OLD.reversed_by_transaction_id IS NOT NULL
       AND OLD.reversed_by_transaction_id IS DISTINCT FROM NEW.reversed_by_transaction_id THEN
      RAISE EXCEPTION 'Streak freeze reversals are immutable' USING ERRCODE = '55000';
    END IF;
  END IF;

  IF NEW.transaction_type = 'RESTORE' THEN
    SELECT * INTO v_source FROM public.streak_freeze_transactions
    WHERE id = NEW.source_transaction_id FOR SHARE;
    IF NOT FOUND OR v_source.transaction_type <> 'CONSUME'
       OR v_source.gym_id <> NEW.gym_id
       OR v_source.gym_member_id <> NEW.gym_member_id THEN
      RAISE EXCEPTION 'RESTORE must reference a same-tenant CONSUME transaction' USING ERRCODE = '23503';
    END IF;
    IF v_source.reversed_by_transaction_id IS NOT NULL
       AND v_source.reversed_by_transaction_id IS DISTINCT FROM NEW.id THEN
      RAISE EXCEPTION 'CONSUME transaction has already been restored' USING ERRCODE = '23505';
    END IF;
  END IF;

  IF NEW.reversed_by_transaction_id IS NOT NULL THEN
    SELECT * INTO v_reversal FROM public.streak_freeze_transactions
    WHERE id = NEW.reversed_by_transaction_id FOR SHARE;
    IF NEW.transaction_type <> 'CONSUME'
       OR NOT FOUND
       OR v_reversal.transaction_type <> 'RESTORE'
       OR v_reversal.source_transaction_id <> NEW.id
       OR v_reversal.gym_id <> NEW.gym_id
       OR v_reversal.gym_member_id <> NEW.gym_member_id THEN
      RAISE EXCEPTION 'Reversal must point to a same-tenant RESTORE transaction' USING ERRCODE = '23503';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION private.create_member_streak_rule_assignment(
  p_gym_id UUID,
  p_gym_member_id UUID,
  p_streak_rule_id UUID,
  p_starts_at TIMESTAMPTZ,
  p_status public.member_streak_rule_status,
  p_actor UUID,
  p_grant_initial_freezes BOOLEAN
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_member public.gym_members%ROWTYPE;
  v_rule public.streak_rules%ROWTYPE;
  v_assignment_id UUID;
  v_projection_rows INTEGER := 0;
BEGIN
  IF p_status NOT IN ('ACTIVE', 'SCHEDULED') THEN
    RAISE EXCEPTION 'Unsupported streak rule assignment status' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_member FROM public.gym_members
  WHERE id = p_gym_member_id AND gym_id = p_gym_id AND status = 'ACTIVE'
  FOR SHARE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Active gym member not found for streak assignment' USING ERRCODE = 'P0002';
  END IF;

  SELECT * INTO v_rule FROM public.streak_rules
  WHERE id = p_streak_rule_id
    AND gym_id = p_gym_id
    AND status = 'ACTIVE'
    AND deleted_at IS NULL
  FOR SHARE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Active streak rule not found in tenant' USING ERRCODE = '23503';
  END IF;

  INSERT INTO public.member_streak_rules (
    gym_id, gym_member_id, streak_rule_id, target_days, max_freezes,
    period_type, week_starts_on, timezone, starts_at, status, assigned_by
  ) VALUES (
    p_gym_id, p_gym_member_id, p_streak_rule_id, v_rule.target_days, v_rule.max_freezes,
    v_rule.period_type, v_rule.week_starts_on, v_rule.timezone, p_starts_at, p_status, p_actor
  ) RETURNING id INTO v_assignment_id;

  INSERT INTO public.member_streaks (
    gym_id, gym_member_id, current_streak, best_streak, freezes_available, version
  ) VALUES (
    p_gym_id, p_gym_member_id, 0, 0,
    CASE WHEN p_grant_initial_freezes THEN v_rule.max_freezes ELSE 0 END,
    0
  ) ON CONFLICT (gym_id, gym_member_id) DO NOTHING;
  GET DIAGNOSTICS v_projection_rows = ROW_COUNT;

  IF p_grant_initial_freezes AND v_projection_rows = 1 AND v_rule.max_freezes > 0 THEN
    INSERT INTO public.streak_freeze_transactions (
      gym_id, gym_member_id, transaction_type, amount, reason, created_by, metadata
    ) VALUES (
      p_gym_id, p_gym_member_id, 'GRANT', v_rule.max_freezes,
      'Initial streak rule assignment grant', p_actor,
      jsonb_build_object('member_streak_rule_id', v_assignment_id)
    );
  END IF;

  RETURN v_assignment_id;
END;
$$;

CREATE TRIGGER trg_streak_rules_validate
  BEFORE INSERT OR UPDATE ON public.streak_rules
  FOR EACH ROW EXECUTE FUNCTION private.validate_streak_rule_config();
CREATE TRIGGER trg_member_streak_rules_validate
  BEFORE INSERT OR UPDATE ON public.member_streak_rules
  FOR EACH ROW EXECUTE FUNCTION private.validate_member_streak_rule_snapshot();
CREATE TRIGGER trg_streak_periods_validate
  BEFORE INSERT OR UPDATE ON public.streak_periods
  FOR EACH ROW EXECUTE FUNCTION private.validate_streak_period_snapshot();
CREATE TRIGGER trg_streak_freeze_transactions_validate
  BEFORE INSERT OR UPDATE ON public.streak_freeze_transactions
  FOR EACH ROW EXECUTE FUNCTION private.validate_streak_freeze_transaction();

REVOKE ALL ON FUNCTION private.is_valid_timezone(TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION private.next_monday_boundary(TIMESTAMPTZ, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION private.validate_streak_rule_config() FROM PUBLIC;
REVOKE ALL ON FUNCTION private.validate_member_streak_rule_snapshot() FROM PUBLIC;
REVOKE ALL ON FUNCTION private.validate_streak_period_snapshot() FROM PUBLIC;
REVOKE ALL ON FUNCTION private.validate_streak_freeze_transaction() FROM PUBLIC;
REVOKE ALL ON FUNCTION private.create_member_streak_rule_assignment(UUID, UUID, UUID, TIMESTAMPTZ, public.member_streak_rule_status, UUID, BOOLEAN) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION private.is_valid_timezone(TEXT) TO postgres, service_role;
GRANT EXECUTE ON FUNCTION private.next_monday_boundary(TIMESTAMPTZ, TEXT) TO postgres, service_role;
GRANT EXECUTE ON FUNCTION private.validate_streak_rule_config() TO postgres, service_role;
GRANT EXECUTE ON FUNCTION private.validate_member_streak_rule_snapshot() TO postgres, service_role;
GRANT EXECUTE ON FUNCTION private.validate_streak_period_snapshot() TO postgres, service_role;
GRANT EXECUTE ON FUNCTION private.validate_streak_freeze_transaction() TO postgres, service_role;
GRANT EXECUTE ON FUNCTION private.create_member_streak_rule_assignment(UUID, UUID, UUID, TIMESTAMPTZ, public.member_streak_rule_status, UUID, BOOLEAN) TO postgres, service_role;

ALTER TABLE public.streak_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.streak_rules FORCE ROW LEVEL SECURITY;
ALTER TABLE public.member_streak_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.member_streak_rules FORCE ROW LEVEL SECURITY;
ALTER TABLE public.streak_periods ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.streak_periods FORCE ROW LEVEL SECURITY;
ALTER TABLE public.streak_freeze_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.streak_freeze_transactions FORCE ROW LEVEL SECURITY;
ALTER TABLE public.member_streaks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.member_streaks FORCE ROW LEVEL SECURITY;

CREATE POLICY streak_rules_select_tenant_member ON public.streak_rules
  FOR SELECT TO authenticated
  USING (private.is_gym_member(gym_id));

CREATE POLICY member_streak_rules_select_authorized ON public.member_streak_rules
  FOR SELECT TO authenticated
  USING (
    private.has_gym_role(gym_id, 'GYM_ADMIN')
    OR private.is_own_gym_member(gym_id, gym_member_id)
    OR private.can_train_gym_member(gym_id, gym_member_id)
  );

CREATE POLICY streak_periods_select_authorized ON public.streak_periods
  FOR SELECT TO authenticated
  USING (
    private.has_gym_role(gym_id, 'GYM_ADMIN')
    OR private.is_own_gym_member(gym_id, gym_member_id)
    OR private.can_train_gym_member(gym_id, gym_member_id)
  );

CREATE POLICY streak_freeze_transactions_select_authorized ON public.streak_freeze_transactions
  FOR SELECT TO authenticated
  USING (
    private.has_gym_role(gym_id, 'GYM_ADMIN')
    OR private.is_own_gym_member(gym_id, gym_member_id)
  );

CREATE POLICY member_streaks_select_authorized ON public.member_streaks
  FOR SELECT TO authenticated
  USING (
    private.has_gym_role(gym_id, 'GYM_ADMIN')
    OR private.is_own_gym_member(gym_id, gym_member_id)
    OR private.can_train_gym_member(gym_id, gym_member_id)
  );

REVOKE INSERT, UPDATE, DELETE ON public.streak_rules, public.member_streak_rules,
  public.streak_periods, public.streak_freeze_transactions, public.member_streaks
  FROM anon, authenticated;
GRANT SELECT ON public.streak_rules, public.member_streak_rules,
  public.streak_periods, public.streak_freeze_transactions, public.member_streaks
  TO authenticated;
GRANT USAGE ON TYPE public.streak_period_type, public.streak_rule_status,
  public.member_streak_rule_status, public.streak_period_status,
  public.streak_freeze_transaction_type, public.streak_period_eligibility_reason
  TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.create_streak_rule(
  p_gym_id UUID,
  p_name TEXT,
  p_target_days INTEGER,
  p_max_freezes INTEGER DEFAULT 2,
  p_timezone TEXT DEFAULT NULL
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE v_actor UUID; v_id UUID; v_timezone TEXT;
BEGIN
  v_actor := private.assert_gym_admin(p_gym_id);
  v_timezone := COALESCE(NULLIF(btrim(p_timezone), ''), (SELECT timezone FROM public.gyms WHERE id = p_gym_id));
  INSERT INTO public.streak_rules (
    gym_id, name, target_days, max_freezes, week_starts_on, timezone, created_by
  ) VALUES (
    p_gym_id, p_name, p_target_days::SMALLINT, p_max_freezes::SMALLINT, 1, v_timezone, v_actor
  ) RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.update_streak_rule(
  p_streak_rule_id UUID,
  p_name TEXT,
  p_target_days INTEGER,
  p_max_freezes INTEGER,
  p_timezone TEXT,
  p_status public.streak_rule_status DEFAULT 'ACTIVE'
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE v_rule public.streak_rules%ROWTYPE; v_id UUID;
BEGIN
  SELECT * INTO v_rule FROM public.streak_rules WHERE id = p_streak_rule_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Streak rule not found' USING ERRCODE = 'P0002'; END IF;
  PERFORM private.assert_gym_admin(v_rule.gym_id);
  IF v_rule.status = 'ARCHIVED' OR v_rule.deleted_at IS NOT NULL THEN
    RAISE EXCEPTION 'Archived streak rules cannot be updated' USING ERRCODE = '55000';
  END IF;
  IF p_status = 'ARCHIVED' THEN
    RAISE EXCEPTION 'Use archive_streak_rule to archive rules' USING ERRCODE = '22023';
  END IF;
  UPDATE public.streak_rules SET
    name = p_name,
    target_days = p_target_days::SMALLINT,
    max_freezes = p_max_freezes::SMALLINT,
    timezone = p_timezone,
    status = p_status,
    deleted_at = NULL
  WHERE id = p_streak_rule_id
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.archive_streak_rule(p_streak_rule_id UUID)
RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE v_rule public.streak_rules%ROWTYPE; v_id UUID;
BEGIN
  SELECT * INTO v_rule FROM public.streak_rules WHERE id = p_streak_rule_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Streak rule not found' USING ERRCODE = 'P0002'; END IF;
  PERFORM private.assert_gym_admin(v_rule.gym_id);
  UPDATE public.streak_rules
  SET status = 'ARCHIVED', deleted_at = COALESCE(deleted_at, clock_timestamp())
  WHERE id = p_streak_rule_id
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.assign_member_streak_rule(
  p_gym_id UUID,
  p_gym_member_id UUID,
  p_streak_rule_id UUID
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE v_actor UUID; v_id UUID;
BEGIN
  v_actor := private.assert_gym_admin(p_gym_id);
  IF EXISTS (
    SELECT 1 FROM public.member_streak_rules
    WHERE gym_id = p_gym_id AND gym_member_id = p_gym_member_id AND status IN ('ACTIVE', 'SCHEDULED')
    FOR UPDATE
  ) THEN
    RAISE EXCEPTION 'Gym member already has an active streak rule assignment' USING ERRCODE = '23505';
  END IF;
  v_id := private.create_member_streak_rule_assignment(
    p_gym_id, p_gym_member_id, p_streak_rule_id, clock_timestamp(), 'ACTIVE', v_actor, TRUE
  );
  RETURN v_id;
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
  v_current public.member_streak_rules%ROWTYPE;
  v_boundary TIMESTAMPTZ;
  v_id UUID;
BEGIN
  v_actor := private.assert_gym_admin(p_gym_id);
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

CREATE OR REPLACE FUNCTION public."createStreakRule"(p_gym_id UUID, p_name TEXT, p_target_days INTEGER, p_max_freezes INTEGER DEFAULT 2, p_timezone TEXT DEFAULT NULL)
RETURNS UUID LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog, public
AS $$ SELECT public.create_streak_rule($1,$2,$3,$4,$5) $$;
CREATE OR REPLACE FUNCTION public."updateStreakRule"(p_streak_rule_id UUID, p_name TEXT, p_target_days INTEGER, p_max_freezes INTEGER, p_timezone TEXT, p_status public.streak_rule_status DEFAULT 'ACTIVE')
RETURNS UUID LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog, public
AS $$ SELECT public.update_streak_rule($1,$2,$3,$4,$5,$6) $$;
CREATE OR REPLACE FUNCTION public."archiveStreakRule"(p_streak_rule_id UUID)
RETURNS UUID LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog, public
AS $$ SELECT public.archive_streak_rule($1) $$;
CREATE OR REPLACE FUNCTION public."assignMemberStreakRule"(p_gym_id UUID, p_gym_member_id UUID, p_streak_rule_id UUID)
RETURNS UUID LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog, public
AS $$ SELECT public.assign_member_streak_rule($1,$2,$3) $$;
CREATE OR REPLACE FUNCTION public."changeMemberStreakRule"(p_gym_id UUID, p_gym_member_id UUID, p_new_streak_rule_id UUID)
RETURNS UUID LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog, public
AS $$ SELECT public.change_member_streak_rule($1,$2,$3) $$;

DO $$
DECLARE f RECORD;
BEGIN
  FOR f IN
    SELECT p.oid::regprocedure AS signature
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname IN (
        'create_streak_rule', 'update_streak_rule', 'archive_streak_rule',
        'assign_member_streak_rule', 'change_member_streak_rule',
        'createStreakRule', 'updateStreakRule', 'archiveStreakRule',
        'assignMemberStreakRule', 'changeMemberStreakRule'
      )
  LOOP
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC', f.signature);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated, service_role', f.signature);
  END LOOP;
END $$;
