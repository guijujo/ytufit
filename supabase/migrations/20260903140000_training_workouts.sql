-- YtuFit v2.0.3-C: Workout sessions, immutable prescription snapshots and workout sets.
-- Workouts are historical facts. They do not write attendance in this stage.

CREATE TYPE public.workout_status AS ENUM ('IN_PROGRESS', 'COMPLETED', 'CANCELLED');
CREATE TYPE public.workout_set_status AS ENUM ('PLANNED', 'COMPLETED', 'SKIPPED');

CREATE TABLE public.workout_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  gym_id UUID NOT NULL REFERENCES public.gyms(id) ON DELETE CASCADE,
  gym_member_id UUID NOT NULL,
  routine_assignment_id UUID NOT NULL,
  routine_id UUID NOT NULL,
  status public.workout_status NOT NULL DEFAULT 'IN_PROGRESS',
  started_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
  completed_at TIMESTAMPTZ NULL,
  cancelled_at TIMESTAMPTZ NULL,
  cancellation_reason TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
  CONSTRAINT workout_sessions_id_gym_key UNIQUE (id, gym_id),
  CONSTRAINT workout_sessions_member_fk FOREIGN KEY (gym_member_id, gym_id)
    REFERENCES public.gym_members (id, gym_id) ON DELETE RESTRICT,
  CONSTRAINT workout_sessions_assignment_fk FOREIGN KEY (routine_assignment_id, gym_id)
    REFERENCES public.routine_assignments (id, gym_id) ON DELETE RESTRICT,
  CONSTRAINT workout_sessions_routine_fk FOREIGN KEY (routine_id, gym_id)
    REFERENCES public.routines (id, gym_id) ON DELETE RESTRICT,
  CONSTRAINT workout_sessions_status_timestamps_check CHECK (
    (status = 'IN_PROGRESS' AND completed_at IS NULL AND cancelled_at IS NULL)
    OR (status = 'COMPLETED' AND completed_at IS NOT NULL AND cancelled_at IS NULL)
    OR (status = 'CANCELLED' AND cancelled_at IS NOT NULL AND completed_at IS NULL)
  ),
  CONSTRAINT workout_sessions_completed_order_check CHECK (completed_at IS NULL OR completed_at >= started_at),
  CONSTRAINT workout_sessions_cancelled_order_check CHECK (cancelled_at IS NULL OR cancelled_at >= started_at)
);

CREATE UNIQUE INDEX idx_workout_sessions_one_in_progress_per_member
  ON public.workout_sessions (gym_id, gym_member_id)
  WHERE status = 'IN_PROGRESS';
CREATE INDEX idx_workout_sessions_member ON public.workout_sessions(gym_id, gym_member_id, started_at DESC);
CREATE INDEX idx_workout_sessions_assignment ON public.workout_sessions(gym_id, routine_assignment_id);

CREATE TABLE public.workout_exercises (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  gym_id UUID NOT NULL,
  workout_session_id UUID NOT NULL,
  source_routine_exercise_id UUID NULL REFERENCES public.routine_exercises(id) ON DELETE SET NULL,
  source_exercise_id UUID NULL REFERENCES public.exercises(id) ON DELETE SET NULL,
  position INTEGER NOT NULL CHECK (position > 0),
  exercise_name TEXT NOT NULL CHECK (length(btrim(exercise_name)) > 0),
  exercise_slug_snapshot TEXT NULL,
  exercise_scope_snapshot public.exercise_scope NULL,
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
  CONSTRAINT workout_exercises_id_gym_key UNIQUE (id, gym_id),
  CONSTRAINT workout_exercises_session_fk FOREIGN KEY (workout_session_id, gym_id)
    REFERENCES public.workout_sessions (id, gym_id) ON DELETE CASCADE,
  CONSTRAINT workout_exercises_reps_range_check CHECK (
    reps_min IS NULL OR reps_max IS NULL OR reps_min <= reps_max
  ),
  CONSTRAINT workout_exercises_position_key UNIQUE (workout_session_id, position)
);

CREATE INDEX idx_workout_exercises_session ON public.workout_exercises(gym_id, workout_session_id, position);
CREATE INDEX idx_workout_exercises_source_routine ON public.workout_exercises(source_routine_exercise_id);

CREATE TABLE public.workout_sets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  gym_id UUID NOT NULL,
  workout_exercise_id UUID NOT NULL,
  set_number INTEGER NOT NULL CHECK (set_number > 0),
  status public.workout_set_status NOT NULL DEFAULT 'PLANNED',
  reps INTEGER NULL CHECK (reps IS NULL OR reps >= 0),
  weight NUMERIC(12, 2) NULL CHECK (weight IS NULL OR weight >= 0),
  duration_seconds INTEGER NULL CHECK (duration_seconds IS NULL OR duration_seconds >= 0),
  distance_meters NUMERIC(12, 2) NULL CHECK (distance_meters IS NULL OR distance_meters >= 0),
  completed_at TIMESTAMPTZ NULL,
  notes TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
  CONSTRAINT workout_sets_exercise_fk FOREIGN KEY (workout_exercise_id, gym_id)
    REFERENCES public.workout_exercises (id, gym_id) ON DELETE CASCADE,
  CONSTRAINT workout_sets_number_key UNIQUE (workout_exercise_id, set_number),
  CONSTRAINT workout_sets_status_completed_check CHECK (
    (status = 'PLANNED' AND completed_at IS NULL)
    OR (status IN ('COMPLETED', 'SKIPPED') AND completed_at IS NOT NULL)
  )
);

CREATE INDEX idx_workout_sets_exercise ON public.workout_sets(gym_id, workout_exercise_id, set_number);

CREATE TRIGGER trg_workout_sessions_updated_at
  BEFORE UPDATE ON public.workout_sessions
  FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();
CREATE TRIGGER trg_workout_exercises_updated_at
  BEFORE UPDATE ON public.workout_exercises
  FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();
CREATE TRIGGER trg_workout_sets_updated_at
  BEFORE UPDATE ON public.workout_sets
  FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();

CREATE OR REPLACE FUNCTION private.can_read_workout_session(p_gym_id UUID, p_workout_session_id UUID)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.workout_sessions ws
    WHERE ws.id = p_workout_session_id
      AND ws.gym_id = p_gym_id
      AND (
        private.has_gym_role(ws.gym_id, 'GYM_ADMIN')
        OR private.is_own_gym_member(ws.gym_id, ws.gym_member_id)
        OR private.can_train_gym_member(ws.gym_id, ws.gym_member_id)
      )
  );
$$;

CREATE OR REPLACE FUNCTION private.assert_workout_set_payload(
  p_tracking_type public.exercise_tracking_type,
  p_status public.workout_set_status,
  p_reps INTEGER,
  p_weight NUMERIC,
  p_duration_seconds INTEGER,
  p_distance_meters NUMERIC
) RETURNS VOID LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
  IF p_status = 'PLANNED' THEN
    RAISE EXCEPTION 'record_workout_set cannot write PLANNED status' USING ERRCODE = '22023';
  END IF;

  IF (p_reps IS NOT NULL AND p_reps < 0)
    OR (p_weight IS NOT NULL AND p_weight < 0)
    OR (p_duration_seconds IS NOT NULL AND p_duration_seconds < 0)
    OR (p_distance_meters IS NOT NULL AND p_distance_meters < 0) THEN
    RAISE EXCEPTION 'Workout set metrics cannot be negative' USING ERRCODE = '23514';
  END IF;

  IF p_status = 'SKIPPED' THEN
    IF p_reps IS NOT NULL OR p_weight IS NOT NULL OR p_duration_seconds IS NOT NULL OR p_distance_meters IS NOT NULL THEN
      RAISE EXCEPTION 'Skipped sets cannot include performance metrics' USING ERRCODE = '22023';
    END IF;
    RETURN;
  END IF;

  IF p_tracking_type = 'WEIGHT_REPS' THEN
    IF p_reps IS NULL OR p_weight IS NULL OR p_duration_seconds IS NOT NULL OR p_distance_meters IS NOT NULL THEN
      RAISE EXCEPTION 'WEIGHT_REPS requires reps and weight only' USING ERRCODE = '22023';
    END IF;
  ELSIF p_tracking_type = 'REPS' THEN
    IF p_reps IS NULL OR p_weight IS NOT NULL OR p_duration_seconds IS NOT NULL OR p_distance_meters IS NOT NULL THEN
      RAISE EXCEPTION 'REPS requires reps only' USING ERRCODE = '22023';
    END IF;
  ELSIF p_tracking_type = 'TIME' THEN
    IF p_duration_seconds IS NULL OR p_reps IS NOT NULL OR p_weight IS NOT NULL OR p_distance_meters IS NOT NULL THEN
      RAISE EXCEPTION 'TIME requires duration only' USING ERRCODE = '22023';
    END IF;
  ELSIF p_tracking_type = 'DISTANCE_TIME' THEN
    IF p_distance_meters IS NULL OR p_duration_seconds IS NULL OR p_reps IS NOT NULL OR p_weight IS NOT NULL THEN
      RAISE EXCEPTION 'DISTANCE_TIME requires distance and duration only' USING ERRCODE = '22023';
    END IF;
  ELSIF p_tracking_type = 'WEIGHT_TIME' THEN
    IF p_weight IS NULL OR p_duration_seconds IS NULL OR p_reps IS NOT NULL OR p_distance_meters IS NOT NULL THEN
      RAISE EXCEPTION 'WEIGHT_TIME requires weight and duration only' USING ERRCODE = '22023';
    END IF;
  ELSIF p_tracking_type = 'WEIGHT_DISTANCE' THEN
    IF p_weight IS NULL OR p_distance_meters IS NULL OR p_reps IS NOT NULL OR p_duration_seconds IS NOT NULL THEN
      RAISE EXCEPTION 'WEIGHT_DISTANCE requires weight and distance only' USING ERRCODE = '22023';
    END IF;
  ELSE
    RAISE EXCEPTION 'Unsupported workout tracking type' USING ERRCODE = '22023';
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION private.can_read_workout_session(UUID, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION private.assert_workout_set_payload(public.exercise_tracking_type, public.workout_set_status, INTEGER, NUMERIC, INTEGER, NUMERIC) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION private.can_read_workout_session(UUID, UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.assert_workout_set_payload(public.exercise_tracking_type, public.workout_set_status, INTEGER, NUMERIC, INTEGER, NUMERIC) TO postgres, service_role;

ALTER TABLE public.workout_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workout_sessions FORCE ROW LEVEL SECURITY;
ALTER TABLE public.workout_exercises ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workout_exercises FORCE ROW LEVEL SECURITY;
ALTER TABLE public.workout_sets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workout_sets FORCE ROW LEVEL SECURITY;

CREATE POLICY workout_sessions_select_authorized ON public.workout_sessions
  FOR SELECT TO authenticated
  USING (
    private.has_gym_role(gym_id, 'GYM_ADMIN')
    OR private.is_own_gym_member(gym_id, gym_member_id)
    OR private.can_train_gym_member(gym_id, gym_member_id)
  );

CREATE POLICY workout_exercises_select_authorized ON public.workout_exercises
  FOR SELECT TO authenticated
  USING (private.can_read_workout_session(gym_id, workout_session_id));

CREATE POLICY workout_sets_select_authorized ON public.workout_sets
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.workout_exercises we
      WHERE we.id = workout_sets.workout_exercise_id
        AND we.gym_id = workout_sets.gym_id
        AND private.can_read_workout_session(we.gym_id, we.workout_session_id)
    )
  );

REVOKE INSERT, UPDATE, DELETE ON public.workout_sessions, public.workout_exercises, public.workout_sets FROM anon, authenticated;
GRANT SELECT ON public.workout_sessions, public.workout_exercises, public.workout_sets TO authenticated;
GRANT USAGE ON TYPE public.workout_status, public.workout_set_status TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.start_workout(p_routine_assignment_id UUID)
RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_actor UUID := (SELECT auth.uid());
  v_assignment public.routine_assignments%ROWTYPE;
  v_member public.gym_members%ROWTYPE;
  v_session_id UUID;
  v_now TIMESTAMPTZ := clock_timestamp();
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_assignment
  FROM public.routine_assignments
  WHERE id = p_routine_assignment_id
  FOR SHARE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Routine assignment not found' USING ERRCODE = 'P0002';
  END IF;

  SELECT * INTO v_member
  FROM public.gym_members
  WHERE id = v_assignment.gym_member_id
    AND gym_id = v_assignment.gym_id
    AND status = 'ACTIVE'
  FOR SHARE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Assigned member not found' USING ERRCODE = 'P0002';
  END IF;
  IF v_member.user_id <> v_actor THEN
    RAISE EXCEPTION 'Only the assigned member can start this workout' USING ERRCODE = '42501';
  END IF;
  IF v_assignment.status <> 'ACTIVE' THEN
    RAISE EXCEPTION 'Only ACTIVE routine assignments can start workouts' USING ERRCODE = '55000';
  END IF;
  IF v_assignment.starts_at > v_now THEN
    RAISE EXCEPTION 'Routine assignment has not started yet' USING ERRCODE = '22023';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.routine_exercises WHERE routine_id = v_assignment.routine_id AND gym_id = v_assignment.gym_id) THEN
    RAISE EXCEPTION 'Routine has no exercises to start' USING ERRCODE = 'P0002';
  END IF;

  INSERT INTO public.workout_sessions (gym_id, gym_member_id, routine_assignment_id, routine_id, started_at)
  VALUES (v_assignment.gym_id, v_assignment.gym_member_id, v_assignment.id, v_assignment.routine_id, v_now)
  RETURNING id INTO v_session_id;

  WITH inserted_exercises AS (
    INSERT INTO public.workout_exercises (
      gym_id, workout_session_id, source_routine_exercise_id, source_exercise_id,
      position, exercise_name, exercise_slug_snapshot, exercise_scope_snapshot, tracking_type,
      sets_target, reps_min, reps_max, weight_target, duration_seconds_target,
      distance_meters_target, rest_seconds, notes
    )
    SELECT
      re.gym_id, v_session_id, re.id, e.id,
      re.position, e.name, e.slug, e.scope, re.tracking_type,
      re.sets_target, re.reps_min, re.reps_max, re.weight_target, re.duration_seconds_target,
      re.distance_meters_target, re.rest_seconds, re.notes
    FROM public.routine_exercises re
    JOIN public.exercises e ON e.id = re.exercise_id
    WHERE re.routine_id = v_assignment.routine_id
      AND re.gym_id = v_assignment.gym_id
    ORDER BY re.position
    RETURNING id, gym_id, sets_target
  )
  INSERT INTO public.workout_sets (gym_id, workout_exercise_id, set_number)
  SELECT ie.gym_id, ie.id, gs.set_number
  FROM inserted_exercises ie
  CROSS JOIN LATERAL generate_series(1, ie.sets_target) AS gs(set_number)
  WHERE ie.sets_target IS NOT NULL;

  RETURN v_session_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.record_workout_set(
  p_workout_exercise_id UUID,
  p_set_number INTEGER,
  p_status public.workout_set_status DEFAULT 'COMPLETED',
  p_reps INTEGER DEFAULT NULL,
  p_weight NUMERIC DEFAULT NULL,
  p_duration_seconds INTEGER DEFAULT NULL,
  p_distance_meters NUMERIC DEFAULT NULL,
  p_notes TEXT DEFAULT NULL
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_actor UUID := (SELECT auth.uid());
  v_exercise public.workout_exercises%ROWTYPE;
  v_session public.workout_sessions%ROWTYPE;
  v_id UUID;
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
  END IF;
  IF p_set_number IS NULL OR p_set_number <= 0 THEN
    RAISE EXCEPTION 'set_number must be positive' USING ERRCODE = '23514';
  END IF;

  SELECT * INTO v_exercise FROM public.workout_exercises WHERE id = p_workout_exercise_id FOR SHARE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Workout exercise not found' USING ERRCODE = 'P0002';
  END IF;
  SELECT * INTO v_session FROM public.workout_sessions WHERE id = v_exercise.workout_session_id AND gym_id = v_exercise.gym_id FOR SHARE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Workout session not found' USING ERRCODE = 'P0002';
  END IF;
  IF NOT private.is_own_gym_member(v_session.gym_id, v_session.gym_member_id) THEN
    RAISE EXCEPTION 'Only the workout owner can record performance' USING ERRCODE = '42501';
  END IF;
  IF v_session.status <> 'IN_PROGRESS' THEN
    RAISE EXCEPTION 'Workout session is not in progress' USING ERRCODE = '55000';
  END IF;

  PERFORM private.assert_workout_set_payload(v_exercise.tracking_type, p_status, p_reps, p_weight, p_duration_seconds, p_distance_meters);

  INSERT INTO public.workout_sets (
    gym_id, workout_exercise_id, set_number, status,
    reps, weight, duration_seconds, distance_meters, completed_at, notes
  ) VALUES (
    v_exercise.gym_id, v_exercise.id, p_set_number, p_status,
    p_reps, p_weight, p_duration_seconds, p_distance_meters, clock_timestamp(), p_notes
  )
  ON CONFLICT (workout_exercise_id, set_number) DO UPDATE SET
    status = EXCLUDED.status,
    reps = EXCLUDED.reps,
    weight = EXCLUDED.weight,
    duration_seconds = EXCLUDED.duration_seconds,
    distance_meters = EXCLUDED.distance_meters,
    completed_at = EXCLUDED.completed_at,
    notes = EXCLUDED.notes
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.complete_workout(p_workout_session_id UUID)
RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_session public.workout_sessions%ROWTYPE;
  v_id UUID;
BEGIN
  IF (SELECT auth.uid()) IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
  END IF;
  SELECT * INTO v_session FROM public.workout_sessions WHERE id = p_workout_session_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Workout session not found' USING ERRCODE = 'P0002';
  END IF;
  IF NOT private.is_own_gym_member(v_session.gym_id, v_session.gym_member_id) THEN
    RAISE EXCEPTION 'Only the workout owner can complete this workout' USING ERRCODE = '42501';
  END IF;
  IF v_session.status <> 'IN_PROGRESS' THEN
    RAISE EXCEPTION 'Only IN_PROGRESS workouts can be completed' USING ERRCODE = '55000';
  END IF;
  UPDATE public.workout_sessions
  SET status = 'COMPLETED', completed_at = clock_timestamp()
  WHERE id = p_workout_session_id
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.cancel_workout(
  p_workout_session_id UUID,
  p_reason TEXT DEFAULT NULL
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_session public.workout_sessions%ROWTYPE;
  v_id UUID;
BEGIN
  IF (SELECT auth.uid()) IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
  END IF;
  SELECT * INTO v_session FROM public.workout_sessions WHERE id = p_workout_session_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Workout session not found' USING ERRCODE = 'P0002';
  END IF;
  IF NOT private.is_own_gym_member(v_session.gym_id, v_session.gym_member_id) THEN
    RAISE EXCEPTION 'Only the workout owner can cancel this workout' USING ERRCODE = '42501';
  END IF;
  IF v_session.status <> 'IN_PROGRESS' THEN
    RAISE EXCEPTION 'Only IN_PROGRESS workouts can be cancelled' USING ERRCODE = '55000';
  END IF;
  UPDATE public.workout_sessions
  SET status = 'CANCELLED', cancelled_at = clock_timestamp(), cancellation_reason = p_reason
  WHERE id = p_workout_session_id
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public."startWorkout"(p_routine_assignment_id UUID)
RETURNS UUID LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog, public
AS $$ SELECT public.start_workout($1) $$;
CREATE OR REPLACE FUNCTION public."recordWorkoutSet"(p_workout_exercise_id UUID, p_set_number INTEGER, p_status public.workout_set_status DEFAULT 'COMPLETED', p_reps INTEGER DEFAULT NULL, p_weight NUMERIC DEFAULT NULL, p_duration_seconds INTEGER DEFAULT NULL, p_distance_meters NUMERIC DEFAULT NULL, p_notes TEXT DEFAULT NULL)
RETURNS UUID LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog, public
AS $$ SELECT public.record_workout_set($1,$2,$3,$4,$5,$6,$7,$8) $$;
CREATE OR REPLACE FUNCTION public."completeWorkout"(p_workout_session_id UUID)
RETURNS UUID LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog, public
AS $$ SELECT public.complete_workout($1) $$;
CREATE OR REPLACE FUNCTION public."cancelWorkout"(p_workout_session_id UUID, p_reason TEXT DEFAULT NULL)
RETURNS UUID LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog, public
AS $$ SELECT public.cancel_workout($1,$2) $$;

DO $$
DECLARE f RECORD;
BEGIN
  FOR f IN
    SELECT p.oid::regprocedure AS signature
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname IN (
        'start_workout', 'startWorkout',
        'record_workout_set', 'recordWorkoutSet',
        'complete_workout', 'completeWorkout',
        'cancel_workout', 'cancelWorkout'
      )
  LOOP
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC', f.signature);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated, service_role', f.signature);
  END LOOP;
END $$;