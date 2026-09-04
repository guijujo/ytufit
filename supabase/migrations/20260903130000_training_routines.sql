-- YtuFit v2.0.3-B: Training routines, routine prescriptions and assignments.
-- This stage models prescribed training only. Workout sessions/results remain future work.

CREATE TYPE public.routine_status AS ENUM ('ACTIVE', 'INACTIVE', 'ARCHIVED');
CREATE TYPE public.routine_assignment_status AS ENUM ('ACTIVE', 'COMPLETED', 'CANCELLED');
CREATE TYPE public.trainer_member_assignment_status AS ENUM ('ACTIVE', 'INACTIVE');

CREATE TABLE public.trainer_member_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  gym_id UUID NOT NULL REFERENCES public.gyms(id) ON DELETE CASCADE,
  trainer_gym_member_id UUID NOT NULL,
  member_gym_member_id UUID NOT NULL,
  status public.trainer_member_assignment_status NOT NULL DEFAULT 'ACTIVE',
  created_by UUID NULL REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
  ended_at TIMESTAMPTZ NULL,
  CONSTRAINT trainer_member_assignments_trainer_fk FOREIGN KEY (trainer_gym_member_id, gym_id)
    REFERENCES public.gym_members (id, gym_id) ON DELETE RESTRICT,
  CONSTRAINT trainer_member_assignments_member_fk FOREIGN KEY (member_gym_member_id, gym_id)
    REFERENCES public.gym_members (id, gym_id) ON DELETE RESTRICT,
  CONSTRAINT trainer_member_assignments_distinct_check CHECK (trainer_gym_member_id <> member_gym_member_id),
  CONSTRAINT trainer_member_assignments_ended_status_check CHECK (
    (status = 'ACTIVE' AND ended_at IS NULL)
    OR (status = 'INACTIVE' AND ended_at IS NOT NULL)
  )
);

CREATE UNIQUE INDEX idx_trainer_member_assignments_active_pair
  ON public.trainer_member_assignments (gym_id, trainer_gym_member_id, member_gym_member_id)
  WHERE status = 'ACTIVE';
CREATE INDEX idx_trainer_member_assignments_trainer ON public.trainer_member_assignments(gym_id, trainer_gym_member_id);
CREATE INDEX idx_trainer_member_assignments_member ON public.trainer_member_assignments(gym_id, member_gym_member_id);

CREATE TABLE public.routines (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  gym_id UUID NOT NULL REFERENCES public.gyms(id) ON DELETE CASCADE,
  name TEXT NOT NULL CHECK (length(btrim(name)) > 0),
  description TEXT NULL,
  status public.routine_status NOT NULL DEFAULT 'ACTIVE',
  created_by UUID NULL REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
  deleted_at TIMESTAMPTZ NULL,
  CONSTRAINT routines_id_gym_key UNIQUE (id, gym_id),
  CONSTRAINT routines_deleted_status_check CHECK (
    deleted_at IS NULL OR status = 'ARCHIVED'
  )
);

CREATE INDEX idx_routines_gym_id ON public.routines(gym_id);
CREATE INDEX idx_routines_status ON public.routines(status);
CREATE UNIQUE INDEX idx_routines_active_name
  ON public.routines (gym_id, lower(name))
  WHERE status = 'ACTIVE' AND deleted_at IS NULL;

CREATE TABLE public.routine_exercises (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  gym_id UUID NOT NULL,
  routine_id UUID NOT NULL,
  exercise_id UUID NOT NULL REFERENCES public.exercises(id) ON DELETE RESTRICT,
  position INTEGER NOT NULL CHECK (position > 0),
  tracking_type public.exercise_tracking_type NOT NULL,
  sets_target INTEGER NULL CHECK (sets_target IS NULL OR sets_target > 0),
  reps_min INTEGER NULL CHECK (reps_min IS NULL OR reps_min >= 0),
  reps_max INTEGER NULL CHECK (reps_max IS NULL OR reps_max >= 0),
  weight_target NUMERIC(12, 2) NULL CHECK (weight_target IS NULL OR weight_target >= 0),
  duration_seconds_target INTEGER NULL CHECK (duration_seconds_target IS NULL OR duration_seconds_target >= 0),
  distance_meters_target NUMERIC(12, 2) NULL CHECK (distance_meters_target IS NULL OR distance_meters_target >= 0),
  rest_seconds INTEGER NULL CHECK (rest_seconds IS NULL OR rest_seconds >= 0),
  notes TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
  CONSTRAINT routine_exercises_id_gym_key UNIQUE (id, gym_id),
  CONSTRAINT routine_exercises_routine_fk FOREIGN KEY (routine_id, gym_id)
    REFERENCES public.routines (id, gym_id) ON DELETE CASCADE,
  CONSTRAINT routine_exercises_reps_range_check CHECK (
    reps_min IS NULL OR reps_max IS NULL OR reps_min <= reps_max
  ),
  CONSTRAINT routine_exercises_position_key UNIQUE (routine_id, position)
);

CREATE INDEX idx_routine_exercises_gym_routine ON public.routine_exercises(gym_id, routine_id);
CREATE INDEX idx_routine_exercises_exercise_id ON public.routine_exercises(exercise_id);

CREATE TABLE public.routine_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  gym_id UUID NOT NULL,
  routine_id UUID NOT NULL,
  gym_member_id UUID NOT NULL,
  assigned_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  starts_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
  ends_at TIMESTAMPTZ NULL,
  status public.routine_assignment_status NOT NULL DEFAULT 'ACTIVE',
  notes TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
  CONSTRAINT routine_assignments_id_gym_key UNIQUE (id, gym_id),
  CONSTRAINT routine_assignments_routine_fk FOREIGN KEY (routine_id, gym_id)
    REFERENCES public.routines (id, gym_id) ON DELETE RESTRICT,
  CONSTRAINT routine_assignments_member_fk FOREIGN KEY (gym_member_id, gym_id)
    REFERENCES public.gym_members (id, gym_id) ON DELETE RESTRICT,
  CONSTRAINT routine_assignments_dates_check CHECK (ends_at IS NULL OR ends_at >= starts_at),
  CONSTRAINT routine_assignments_status_dates_check CHECK (
    (status = 'ACTIVE' AND ends_at IS NULL)
    OR (status IN ('COMPLETED', 'CANCELLED') AND ends_at IS NOT NULL)
  )
);

CREATE INDEX idx_routine_assignments_gym_member ON public.routine_assignments(gym_id, gym_member_id);
CREATE INDEX idx_routine_assignments_gym_routine ON public.routine_assignments(gym_id, routine_id);
CREATE INDEX idx_routine_assignments_status ON public.routine_assignments(status);

CREATE TRIGGER trg_trainer_member_assignments_updated_at
  BEFORE UPDATE ON public.trainer_member_assignments
  FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();
CREATE TRIGGER trg_routines_updated_at
  BEFORE UPDATE ON public.routines
  FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();
CREATE TRIGGER trg_routine_exercises_updated_at
  BEFORE UPDATE ON public.routine_exercises
  FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();
CREATE TRIGGER trg_routine_assignments_updated_at
  BEFORE UPDATE ON public.routine_assignments
  FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();

CREATE OR REPLACE FUNCTION private.current_gym_member_id(p_gym_id UUID)
RETURNS UUID LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
  SELECT gm.id
  FROM public.gym_members gm
  WHERE gm.gym_id = p_gym_id
    AND gm.user_id = (SELECT auth.uid())
    AND gm.status = 'ACTIVE'
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION private.gym_member_has_role(p_gym_member_id UUID, p_role_name TEXT)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.gym_member_roles gmr
    JOIN public.roles r ON r.id = gmr.role_id
    WHERE gmr.gym_member_id = p_gym_member_id
      AND r.name = p_role_name
  );
$$;

CREATE OR REPLACE FUNCTION private.can_manage_routine(p_gym_id UUID)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
  SELECT private.has_gym_role(p_gym_id, 'GYM_ADMIN')
    OR private.has_gym_role(p_gym_id, 'TRAINER');
$$;

CREATE OR REPLACE FUNCTION private.can_train_gym_member(p_gym_id UUID, p_member_gym_member_id UUID)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
  SELECT private.has_gym_role(p_gym_id, 'GYM_ADMIN')
    OR EXISTS (
      SELECT 1
      FROM public.trainer_member_assignments tma
      WHERE tma.gym_id = p_gym_id
        AND tma.member_gym_member_id = p_member_gym_member_id
        AND tma.trainer_gym_member_id = private.current_gym_member_id(p_gym_id)
        AND tma.status = 'ACTIVE'
    );
$$;

CREATE OR REPLACE FUNCTION private.is_own_gym_member(p_gym_id UUID, p_gym_member_id UUID)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.gym_members gm
    WHERE gm.id = p_gym_member_id
      AND gm.gym_id = p_gym_id
      AND gm.user_id = (SELECT auth.uid())
      AND gm.status = 'ACTIVE'
  );
$$;

CREATE OR REPLACE FUNCTION private.has_assigned_routine(p_gym_id UUID, p_routine_id UUID)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.routine_assignments ra
    JOIN public.gym_members gm ON gm.id = ra.gym_member_id AND gm.gym_id = ra.gym_id
    WHERE ra.gym_id = p_gym_id
      AND ra.routine_id = p_routine_id
      AND gm.user_id = (SELECT auth.uid())
      AND gm.status = 'ACTIVE'
  );
$$;

CREATE OR REPLACE FUNCTION private.validate_trainer_member_assignment()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
  IF NOT private.gym_member_has_role(NEW.trainer_gym_member_id, 'TRAINER') THEN
    RAISE EXCEPTION 'trainer_gym_member_id must reference a TRAINER' USING ERRCODE = '23514';
  END IF;
  IF NOT private.gym_member_has_role(NEW.member_gym_member_id, 'MEMBER') THEN
    RAISE EXCEPTION 'member_gym_member_id must reference a MEMBER' USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION private.validate_routine_exercise()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE v_exercise public.exercises%ROWTYPE;
BEGIN
  SELECT * INTO v_exercise FROM public.exercises WHERE id = NEW.exercise_id FOR SHARE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Exercise not found' USING ERRCODE = '23503';
  END IF;
  IF v_exercise.status <> 'ACTIVE' THEN
    RAISE EXCEPTION 'Only ACTIVE exercises can be prescribed' USING ERRCODE = '23514';
  END IF;
  IF v_exercise.scope = 'GYM' AND v_exercise.gym_id <> NEW.gym_id THEN
    RAISE EXCEPTION 'Gym exercises must belong to the same tenant as the routine' USING ERRCODE = '23503';
  END IF;
  NEW.tracking_type := v_exercise.tracking_type;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION private.current_gym_member_id(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION private.gym_member_has_role(UUID, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION private.can_manage_routine(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION private.can_train_gym_member(UUID, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION private.is_own_gym_member(UUID, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION private.has_assigned_routine(UUID, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION private.validate_trainer_member_assignment() FROM PUBLIC;
REVOKE ALL ON FUNCTION private.validate_routine_exercise() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION private.current_gym_member_id(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.gym_member_has_role(UUID, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.can_manage_routine(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.can_train_gym_member(UUID, UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.is_own_gym_member(UUID, UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.has_assigned_routine(UUID, UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.validate_trainer_member_assignment() TO postgres, service_role;
GRANT EXECUTE ON FUNCTION private.validate_routine_exercise() TO postgres, service_role;

CREATE TRIGGER trg_trainer_member_assignments_validate
  BEFORE INSERT OR UPDATE ON public.trainer_member_assignments
  FOR EACH ROW EXECUTE FUNCTION private.validate_trainer_member_assignment();
CREATE TRIGGER trg_routine_exercises_validate
  BEFORE INSERT OR UPDATE ON public.routine_exercises
  FOR EACH ROW EXECUTE FUNCTION private.validate_routine_exercise();

ALTER TABLE public.trainer_member_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trainer_member_assignments FORCE ROW LEVEL SECURITY;
ALTER TABLE public.routines ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.routines FORCE ROW LEVEL SECURITY;
ALTER TABLE public.routine_exercises ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.routine_exercises FORCE ROW LEVEL SECURITY;
ALTER TABLE public.routine_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.routine_assignments FORCE ROW LEVEL SECURITY;

CREATE POLICY trainer_member_assignments_select_authorized ON public.trainer_member_assignments
  FOR SELECT TO authenticated
  USING (
    private.has_gym_role(gym_id, 'GYM_ADMIN')
    OR trainer_gym_member_id = private.current_gym_member_id(gym_id)
    OR private.is_own_gym_member(gym_id, member_gym_member_id)
  );

CREATE POLICY routines_select_authorized ON public.routines
  FOR SELECT TO authenticated
  USING (
    private.can_manage_routine(gym_id)
    OR private.has_assigned_routine(gym_id, id)
  );

CREATE POLICY routine_exercises_select_authorized ON public.routine_exercises
  FOR SELECT TO authenticated
  USING (
    private.can_manage_routine(gym_id)
    OR private.has_assigned_routine(gym_id, routine_id)
  );

CREATE POLICY routine_assignments_select_authorized ON public.routine_assignments
  FOR SELECT TO authenticated
  USING (
    private.has_gym_role(gym_id, 'GYM_ADMIN')
    OR private.is_own_gym_member(gym_id, gym_member_id)
    OR private.can_train_gym_member(gym_id, gym_member_id)
  );

REVOKE INSERT, UPDATE, DELETE ON public.trainer_member_assignments, public.routines,
  public.routine_exercises, public.routine_assignments FROM anon, authenticated;
GRANT SELECT ON public.trainer_member_assignments, public.routines,
  public.routine_exercises, public.routine_assignments TO authenticated;
GRANT USAGE ON TYPE public.routine_status, public.routine_assignment_status,
  public.trainer_member_assignment_status TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.create_trainer_member_assignment(
  p_gym_id UUID,
  p_trainer_gym_member_id UUID,
  p_member_gym_member_id UUID
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE v_actor UUID := (SELECT auth.uid()); v_id UUID;
BEGIN
  IF v_actor IS NULL OR NOT private.has_gym_role(p_gym_id, 'GYM_ADMIN') THEN
    RAISE EXCEPTION 'Gym administrator authorization required' USING ERRCODE = '42501';
  END IF;
  INSERT INTO public.trainer_member_assignments (
    gym_id, trainer_gym_member_id, member_gym_member_id, created_by
  ) VALUES (p_gym_id, p_trainer_gym_member_id, p_member_gym_member_id, v_actor)
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.deactivate_trainer_member_assignment(
  p_assignment_id UUID
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE v_assignment public.trainer_member_assignments%ROWTYPE; v_id UUID;
BEGIN
  IF (SELECT auth.uid()) IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
  END IF;
  SELECT * INTO v_assignment
  FROM public.trainer_member_assignments
  WHERE id = p_assignment_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Trainer-member assignment not found' USING ERRCODE = 'P0002';
  END IF;
  IF NOT private.has_gym_role(v_assignment.gym_id, 'GYM_ADMIN') THEN
    RAISE EXCEPTION 'Gym administrator authorization required' USING ERRCODE = '42501';
  END IF;
  IF v_assignment.status <> 'ACTIVE' THEN
    RAISE EXCEPTION 'Trainer-member assignment is already inactive' USING ERRCODE = '55000';
  END IF;
  UPDATE public.trainer_member_assignments
  SET status = 'INACTIVE', ended_at = clock_timestamp()
  WHERE id = p_assignment_id
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;
CREATE OR REPLACE FUNCTION public.create_routine(
  p_gym_id UUID,
  p_name TEXT,
  p_description TEXT DEFAULT NULL
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE v_actor UUID := (SELECT auth.uid()); v_id UUID;
BEGIN
  IF v_actor IS NULL OR NOT private.can_manage_routine(p_gym_id) THEN
    RAISE EXCEPTION 'Training routine administration authorization required' USING ERRCODE = '42501';
  END IF;
  INSERT INTO public.routines (gym_id, name, description, created_by)
  VALUES (p_gym_id, p_name, p_description, v_actor)
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.update_routine(
  p_routine_id UUID,
  p_name TEXT,
  p_description TEXT,
  p_status public.routine_status
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE v_routine public.routines%ROWTYPE; v_id UUID;
BEGIN
  SELECT * INTO v_routine FROM public.routines WHERE id = p_routine_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Routine not found' USING ERRCODE = 'P0002'; END IF;
  IF NOT private.can_manage_routine(v_routine.gym_id) THEN
    RAISE EXCEPTION 'Training routine administration authorization required' USING ERRCODE = '42501';
  END IF;
  UPDATE public.routines SET
    name = p_name,
    description = p_description,
    status = p_status,
    deleted_at = CASE WHEN p_status = 'ARCHIVED' THEN COALESCE(deleted_at, clock_timestamp()) ELSE NULL END
  WHERE id = p_routine_id
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.archive_routine(p_routine_id UUID)
RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE v_routine public.routines%ROWTYPE; v_id UUID;
BEGIN
  SELECT * INTO v_routine FROM public.routines WHERE id = p_routine_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Routine not found' USING ERRCODE = 'P0002'; END IF;
  IF NOT private.can_manage_routine(v_routine.gym_id) THEN
    RAISE EXCEPTION 'Training routine administration authorization required' USING ERRCODE = '42501';
  END IF;
  UPDATE public.routines
    SET status = 'ARCHIVED', deleted_at = COALESCE(deleted_at, clock_timestamp())
    WHERE id = p_routine_id RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.add_routine_exercise(
  p_routine_id UUID,
  p_exercise_id UUID,
  p_position INTEGER,
  p_sets_target INTEGER DEFAULT NULL,
  p_reps_min INTEGER DEFAULT NULL,
  p_reps_max INTEGER DEFAULT NULL,
  p_weight_target NUMERIC DEFAULT NULL,
  p_duration_seconds_target INTEGER DEFAULT NULL,
  p_distance_meters_target NUMERIC DEFAULT NULL,
  p_rest_seconds INTEGER DEFAULT NULL,
  p_notes TEXT DEFAULT NULL
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE v_routine public.routines%ROWTYPE; v_id UUID;
BEGIN
  SELECT * INTO v_routine FROM public.routines WHERE id = p_routine_id FOR UPDATE;
  IF NOT FOUND OR v_routine.status <> 'ACTIVE' THEN
    RAISE EXCEPTION 'Active routine not found' USING ERRCODE = 'P0002';
  END IF;
  IF NOT private.can_manage_routine(v_routine.gym_id) THEN
    RAISE EXCEPTION 'Training routine administration authorization required' USING ERRCODE = '42501';
  END IF;
  INSERT INTO public.routine_exercises (
    gym_id, routine_id, exercise_id, position, tracking_type, sets_target,
    reps_min, reps_max, weight_target, duration_seconds_target,
    distance_meters_target, rest_seconds, notes
  ) VALUES (
    v_routine.gym_id, p_routine_id, p_exercise_id, p_position, 'REPS', p_sets_target,
    p_reps_min, p_reps_max, p_weight_target, p_duration_seconds_target,
    p_distance_meters_target, p_rest_seconds, p_notes
  ) RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.update_routine_exercise(
  p_routine_exercise_id UUID,
  p_exercise_id UUID,
  p_position INTEGER,
  p_sets_target INTEGER DEFAULT NULL,
  p_reps_min INTEGER DEFAULT NULL,
  p_reps_max INTEGER DEFAULT NULL,
  p_weight_target NUMERIC DEFAULT NULL,
  p_duration_seconds_target INTEGER DEFAULT NULL,
  p_distance_meters_target NUMERIC DEFAULT NULL,
  p_rest_seconds INTEGER DEFAULT NULL,
  p_notes TEXT DEFAULT NULL
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE v_row public.routine_exercises%ROWTYPE; v_id UUID;
BEGIN
  SELECT * INTO v_row FROM public.routine_exercises WHERE id = p_routine_exercise_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Routine exercise not found' USING ERRCODE = 'P0002'; END IF;
  IF NOT private.can_manage_routine(v_row.gym_id) THEN
    RAISE EXCEPTION 'Training routine administration authorization required' USING ERRCODE = '42501';
  END IF;
  UPDATE public.routine_exercises SET
    exercise_id = p_exercise_id,
    position = p_position,
    sets_target = p_sets_target,
    reps_min = p_reps_min,
    reps_max = p_reps_max,
    weight_target = p_weight_target,
    duration_seconds_target = p_duration_seconds_target,
    distance_meters_target = p_distance_meters_target,
    rest_seconds = p_rest_seconds,
    notes = p_notes
  WHERE id = p_routine_exercise_id
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.remove_routine_exercise(p_routine_exercise_id UUID)
RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE v_row public.routine_exercises%ROWTYPE; v_id UUID;
BEGIN
  SELECT * INTO v_row FROM public.routine_exercises WHERE id = p_routine_exercise_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Routine exercise not found' USING ERRCODE = 'P0002'; END IF;
  IF NOT private.can_manage_routine(v_row.gym_id) THEN
    RAISE EXCEPTION 'Training routine administration authorization required' USING ERRCODE = '42501';
  END IF;
  DELETE FROM public.routine_exercises WHERE id = p_routine_exercise_id RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.reorder_routine_exercises(
  p_routine_id UUID,
  p_order JSONB
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE v_routine public.routines%ROWTYPE; v_existing_count INTEGER; v_order_count INTEGER;
BEGIN
  IF p_order IS NULL OR jsonb_typeof(p_order) <> 'array' THEN
    RAISE EXCEPTION 'order must be a JSON array' USING ERRCODE = '22023';
  END IF;
  SELECT * INTO v_routine FROM public.routines WHERE id = p_routine_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Routine not found' USING ERRCODE = 'P0002'; END IF;
  IF NOT private.can_manage_routine(v_routine.gym_id) THEN
    RAISE EXCEPTION 'Training routine administration authorization required' USING ERRCODE = '42501';
  END IF;

  SELECT count(*) INTO v_existing_count FROM public.routine_exercises WHERE routine_id = p_routine_id;
  SELECT count(*) INTO v_order_count FROM jsonb_array_elements(p_order);
  IF v_existing_count <> v_order_count THEN
    RAISE EXCEPTION 'Reorder payload must include every routine exercise' USING ERRCODE = '22023';
  END IF;
  IF EXISTS (
    SELECT 1 FROM jsonb_array_elements(p_order) item
    WHERE jsonb_typeof(item) <> 'object'
      OR NOT (item ? 'id')
      OR NOT (item ? 'position')
      OR (item->>'position')::integer <= 0
  ) THEN
    RAISE EXCEPTION 'Each order item must include id and positive position' USING ERRCODE = '22023';
  END IF;
  IF EXISTS (
    SELECT 1 FROM jsonb_array_elements(p_order) item GROUP BY item->>'id' HAVING count(*) > 1
  ) OR EXISTS (
    SELECT 1 FROM jsonb_array_elements(p_order) item GROUP BY (item->>'position')::integer HAVING count(*) > 1
  ) THEN
    RAISE EXCEPTION 'Reorder payload contains duplicates' USING ERRCODE = '23505';
  END IF;
  IF EXISTS (
    SELECT 1 FROM jsonb_array_elements(p_order) item
    WHERE NOT EXISTS (
      SELECT 1 FROM public.routine_exercises re
      WHERE re.id = (item->>'id')::uuid AND re.routine_id = p_routine_id
    )
  ) THEN
    RAISE EXCEPTION 'Reorder payload contains an exercise outside the routine' USING ERRCODE = '23503';
  END IF;

  UPDATE public.routine_exercises SET position = position + 100000 WHERE routine_id = p_routine_id;
  UPDATE public.routine_exercises re
  SET position = (item->>'position')::integer
  FROM jsonb_array_elements(p_order) item
  WHERE re.id = (item->>'id')::uuid
    AND re.routine_id = p_routine_id;
  RETURN p_routine_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.assign_routine(
  p_routine_id UUID,
  p_gym_member_id UUID,
  p_starts_at TIMESTAMPTZ DEFAULT NULL,
  p_notes TEXT DEFAULT NULL
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE v_routine public.routines%ROWTYPE; v_member public.gym_members%ROWTYPE; v_actor UUID := (SELECT auth.uid()); v_id UUID;
BEGIN
  IF v_actor IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501'; END IF;
  SELECT * INTO v_routine FROM public.routines WHERE id = p_routine_id AND status = 'ACTIVE' FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Active routine not found' USING ERRCODE = 'P0002'; END IF;
  SELECT * INTO v_member FROM public.gym_members WHERE id = p_gym_member_id AND status = 'ACTIVE' FOR SHARE;
  IF NOT FOUND OR v_member.gym_id <> v_routine.gym_id THEN
    RAISE EXCEPTION 'Target member does not belong to routine tenant' USING ERRCODE = '23503';
  END IF;
  IF NOT private.gym_member_has_role(p_gym_member_id, 'MEMBER') THEN
    RAISE EXCEPTION 'Routine target must be a MEMBER' USING ERRCODE = '23514';
  END IF;
  IF NOT private.can_train_gym_member(v_routine.gym_id, p_gym_member_id) THEN
    RAISE EXCEPTION 'Trainer-member authorization required' USING ERRCODE = '42501';
  END IF;
  INSERT INTO public.routine_assignments (
    gym_id, routine_id, gym_member_id, assigned_by, starts_at, notes
  ) VALUES (
    v_routine.gym_id, p_routine_id, p_gym_member_id, v_actor, COALESCE(p_starts_at, clock_timestamp()), p_notes
  ) RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.complete_routine_assignment(
  p_assignment_id UUID,
  p_ends_at TIMESTAMPTZ DEFAULT NULL
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE v_assignment public.routine_assignments%ROWTYPE; v_id UUID;
BEGIN
  SELECT * INTO v_assignment FROM public.routine_assignments WHERE id = p_assignment_id AND status = 'ACTIVE' FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Active routine assignment not found' USING ERRCODE = 'P0002'; END IF;
  IF NOT private.can_train_gym_member(v_assignment.gym_id, v_assignment.gym_member_id) THEN
    RAISE EXCEPTION 'Trainer-member authorization required' USING ERRCODE = '42501';
  END IF;
  UPDATE public.routine_assignments
    SET status = 'COMPLETED', ends_at = COALESCE(p_ends_at, clock_timestamp())
    WHERE id = p_assignment_id RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.cancel_routine_assignment(
  p_assignment_id UUID,
  p_ends_at TIMESTAMPTZ DEFAULT NULL,
  p_notes TEXT DEFAULT NULL
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE v_assignment public.routine_assignments%ROWTYPE; v_id UUID;
BEGIN
  SELECT * INTO v_assignment FROM public.routine_assignments WHERE id = p_assignment_id AND status = 'ACTIVE' FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Active routine assignment not found' USING ERRCODE = 'P0002'; END IF;
  IF NOT private.can_train_gym_member(v_assignment.gym_id, v_assignment.gym_member_id) THEN
    RAISE EXCEPTION 'Trainer-member authorization required' USING ERRCODE = '42501';
  END IF;
  UPDATE public.routine_assignments
    SET status = 'CANCELLED', ends_at = COALESCE(p_ends_at, clock_timestamp()), notes = COALESCE(p_notes, notes)
    WHERE id = p_assignment_id RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public."createRoutine"(p_gym_id UUID, p_name TEXT, p_description TEXT DEFAULT NULL)
RETURNS UUID LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog, public
AS $$ SELECT public.create_routine($1,$2,$3) $$;
CREATE OR REPLACE FUNCTION public."updateRoutine"(p_routine_id UUID, p_name TEXT, p_description TEXT, p_status public.routine_status)
RETURNS UUID LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog, public
AS $$ SELECT public.update_routine($1,$2,$3,$4) $$;
CREATE OR REPLACE FUNCTION public."archiveRoutine"(p_routine_id UUID)
RETURNS UUID LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog, public
AS $$ SELECT public.archive_routine($1) $$;
CREATE OR REPLACE FUNCTION public."addRoutineExercise"(p_routine_id UUID, p_exercise_id UUID, p_position INTEGER, p_sets_target INTEGER DEFAULT NULL, p_reps_min INTEGER DEFAULT NULL, p_reps_max INTEGER DEFAULT NULL, p_weight_target NUMERIC DEFAULT NULL, p_duration_seconds_target INTEGER DEFAULT NULL, p_distance_meters_target NUMERIC DEFAULT NULL, p_rest_seconds INTEGER DEFAULT NULL, p_notes TEXT DEFAULT NULL)
RETURNS UUID LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog, public
AS $$ SELECT public.add_routine_exercise($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11) $$;
CREATE OR REPLACE FUNCTION public."updateRoutineExercise"(p_routine_exercise_id UUID, p_exercise_id UUID, p_position INTEGER, p_sets_target INTEGER DEFAULT NULL, p_reps_min INTEGER DEFAULT NULL, p_reps_max INTEGER DEFAULT NULL, p_weight_target NUMERIC DEFAULT NULL, p_duration_seconds_target INTEGER DEFAULT NULL, p_distance_meters_target NUMERIC DEFAULT NULL, p_rest_seconds INTEGER DEFAULT NULL, p_notes TEXT DEFAULT NULL)
RETURNS UUID LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog, public
AS $$ SELECT public.update_routine_exercise($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11) $$;
CREATE OR REPLACE FUNCTION public."removeRoutineExercise"(p_routine_exercise_id UUID)
RETURNS UUID LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog, public
AS $$ SELECT public.remove_routine_exercise($1) $$;
CREATE OR REPLACE FUNCTION public."reorderRoutineExercises"(p_routine_id UUID, p_order JSONB)
RETURNS UUID LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog, public
AS $$ SELECT public.reorder_routine_exercises($1,$2) $$;
CREATE OR REPLACE FUNCTION public."assignRoutine"(p_routine_id UUID, p_gym_member_id UUID, p_starts_at TIMESTAMPTZ DEFAULT NULL, p_notes TEXT DEFAULT NULL)
RETURNS UUID LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog, public
AS $$ SELECT public.assign_routine($1,$2,$3,$4) $$;
CREATE OR REPLACE FUNCTION public."completeRoutineAssignment"(p_assignment_id UUID, p_ends_at TIMESTAMPTZ DEFAULT NULL)
RETURNS UUID LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog, public
AS $$ SELECT public.complete_routine_assignment($1,$2) $$;
CREATE OR REPLACE FUNCTION public."cancelRoutineAssignment"(p_assignment_id UUID, p_ends_at TIMESTAMPTZ DEFAULT NULL, p_notes TEXT DEFAULT NULL)
RETURNS UUID LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog, public
AS $$ SELECT public.cancel_routine_assignment($1,$2,$3) $$;
CREATE OR REPLACE FUNCTION public."createTrainerMemberAssignment"(p_gym_id UUID, p_trainer_gym_member_id UUID, p_member_gym_member_id UUID)
RETURNS UUID LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog, public
AS $$ SELECT public.create_trainer_member_assignment($1,$2,$3) $$;
CREATE OR REPLACE FUNCTION public."deactivateTrainerMemberAssignment"(p_assignment_id UUID)
RETURNS UUID LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog, public
AS $$ SELECT public.deactivate_trainer_member_assignment($1) $$;

DO $$
DECLARE f RECORD;
BEGIN
  FOR f IN
    SELECT p.oid::regprocedure AS signature
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname IN (
        'create_trainer_member_assignment', 'createTrainerMemberAssignment',
        'deactivate_trainer_member_assignment', 'deactivateTrainerMemberAssignment',
        'create_routine', 'update_routine', 'archive_routine',
        'add_routine_exercise', 'update_routine_exercise', 'remove_routine_exercise',
        'reorder_routine_exercises', 'assign_routine', 'complete_routine_assignment',
        'cancel_routine_assignment',
        'createRoutine', 'updateRoutine', 'archiveRoutine',
        'addRoutineExercise', 'updateRoutineExercise', 'removeRoutineExercise',
        'reorderRoutineExercises', 'assignRoutine', 'completeRoutineAssignment',
        'cancelRoutineAssignment'
      )
  LOOP
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC', f.signature);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated, service_role', f.signature);
  END LOOP;
END $$;
