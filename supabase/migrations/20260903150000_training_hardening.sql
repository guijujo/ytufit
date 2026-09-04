-- YtuFit v2.0.3-D: Training security and integrity hardening.
-- This migration adds database-level invariants for Training A+B+C without adding user-facing features.

ALTER TABLE public.routine_assignments
  ADD CONSTRAINT routine_assignments_id_gym_member_routine_key
  UNIQUE (id, gym_id, gym_member_id, routine_id);

ALTER TABLE public.workout_sessions
  ADD CONSTRAINT workout_sessions_assignment_identity_fk
  FOREIGN KEY (routine_assignment_id, gym_id, gym_member_id, routine_id)
  REFERENCES public.routine_assignments (id, gym_id, gym_member_id, routine_id)
  ON DELETE RESTRICT;

CREATE OR REPLACE FUNCTION private.guard_workout_session_integrity()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_assignment public.routine_assignments%ROWTYPE;
BEGIN
  SELECT * INTO v_assignment
  FROM public.routine_assignments
  WHERE id = NEW.routine_assignment_id
    AND gym_id = NEW.gym_id
  FOR SHARE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Workout session routine assignment must exist in the same tenant' USING ERRCODE = '23503';
  END IF;

  IF v_assignment.gym_member_id <> NEW.gym_member_id
     OR v_assignment.routine_id <> NEW.routine_id THEN
    RAISE EXCEPTION 'Workout session assignment, member and routine must match' USING ERRCODE = '23503';
  END IF;

  IF TG_OP = 'UPDATE' THEN
    IF NEW.id IS DISTINCT FROM OLD.id
       OR NEW.gym_id IS DISTINCT FROM OLD.gym_id
       OR NEW.gym_member_id IS DISTINCT FROM OLD.gym_member_id
       OR NEW.routine_assignment_id IS DISTINCT FROM OLD.routine_assignment_id
       OR NEW.routine_id IS DISTINCT FROM OLD.routine_id
       OR NEW.started_at IS DISTINCT FROM OLD.started_at
       OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
      RAISE EXCEPTION 'Workout session identity fields are immutable' USING ERRCODE = '23514';
    END IF;

    IF OLD.status <> 'IN_PROGRESS' THEN
      IF NEW.status IS DISTINCT FROM OLD.status
         OR NEW.completed_at IS DISTINCT FROM OLD.completed_at
         OR NEW.cancelled_at IS DISTINCT FROM OLD.cancelled_at
         OR NEW.cancellation_reason IS DISTINCT FROM OLD.cancellation_reason THEN
        RAISE EXCEPTION 'Finalized workout sessions are immutable' USING ERRCODE = '55000';
      END IF;
    ELSIF NEW.status = 'IN_PROGRESS' THEN
      IF NEW.completed_at IS DISTINCT FROM OLD.completed_at
         OR NEW.cancelled_at IS DISTINCT FROM OLD.cancelled_at
         OR NEW.cancellation_reason IS DISTINCT FROM OLD.cancellation_reason THEN
        RAISE EXCEPTION 'IN_PROGRESS workout session terminal fields cannot change without finalizing' USING ERRCODE = '23514';
      END IF;
    ELSIF NEW.status = 'COMPLETED' THEN
      IF NEW.completed_at IS NULL
         OR NEW.cancelled_at IS NOT NULL
         OR NEW.cancellation_reason IS DISTINCT FROM OLD.cancellation_reason THEN
        RAISE EXCEPTION 'Invalid workout completion transition' USING ERRCODE = '23514';
      END IF;
    ELSIF NEW.status = 'CANCELLED' THEN
      IF NEW.cancelled_at IS NULL OR NEW.completed_at IS NOT NULL THEN
        RAISE EXCEPTION 'Invalid workout cancellation transition' USING ERRCODE = '23514';
      END IF;
    ELSE
      RAISE EXCEPTION 'Unsupported workout session transition' USING ERRCODE = '23514';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION private.guard_workout_exercise_integrity()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_session public.workout_sessions%ROWTYPE;
BEGIN
  SELECT * INTO v_session
  FROM public.workout_sessions
  WHERE id = NEW.workout_session_id
    AND gym_id = NEW.gym_id
  FOR SHARE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Workout exercise session must exist in the same tenant' USING ERRCODE = '23503';
  END IF;

  IF TG_OP = 'INSERT' AND v_session.status <> 'IN_PROGRESS' THEN
    RAISE EXCEPTION 'Workout exercise snapshots can only be created for IN_PROGRESS sessions' USING ERRCODE = '55000';
  END IF;

  IF TG_OP = 'INSERT' THEN
    IF (NEW.source_routine_exercise_id IS NULL) <> (NEW.source_exercise_id IS NULL) THEN
      RAISE EXCEPTION 'Workout exercise source ids must be provided together on insert' USING ERRCODE = '23514';
    END IF;
  ELSE
    IF NEW.id IS DISTINCT FROM OLD.id
       OR NEW.gym_id IS DISTINCT FROM OLD.gym_id
       OR NEW.workout_session_id IS DISTINCT FROM OLD.workout_session_id
       OR NEW.position IS DISTINCT FROM OLD.position
       OR NEW.exercise_name IS DISTINCT FROM OLD.exercise_name
       OR NEW.exercise_slug_snapshot IS DISTINCT FROM OLD.exercise_slug_snapshot
       OR NEW.exercise_scope_snapshot IS DISTINCT FROM OLD.exercise_scope_snapshot
       OR NEW.tracking_type IS DISTINCT FROM OLD.tracking_type
       OR NEW.sets_target IS DISTINCT FROM OLD.sets_target
       OR NEW.reps_min IS DISTINCT FROM OLD.reps_min
       OR NEW.reps_max IS DISTINCT FROM OLD.reps_max
       OR NEW.weight_target IS DISTINCT FROM OLD.weight_target
       OR NEW.duration_seconds_target IS DISTINCT FROM OLD.duration_seconds_target
       OR NEW.distance_meters_target IS DISTINCT FROM OLD.distance_meters_target
       OR NEW.rest_seconds IS DISTINCT FROM OLD.rest_seconds
       OR NEW.notes IS DISTINCT FROM OLD.notes
       OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
      RAISE EXCEPTION 'Workout exercise snapshots are immutable' USING ERRCODE = '55000';
    END IF;

    IF NEW.source_routine_exercise_id IS DISTINCT FROM OLD.source_routine_exercise_id
       AND NEW.source_routine_exercise_id IS NOT NULL THEN
      RAISE EXCEPTION 'Workout exercise source routine exercise cannot be repointed' USING ERRCODE = '23514';
    END IF;
    IF NEW.source_exercise_id IS DISTINCT FROM OLD.source_exercise_id
       AND NEW.source_exercise_id IS NOT NULL THEN
      RAISE EXCEPTION 'Workout exercise source exercise cannot be repointed' USING ERRCODE = '23514';
    END IF;
  END IF;

  IF NEW.source_routine_exercise_id IS NOT NULL AND NEW.source_exercise_id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1
      FROM public.routine_exercises re
      WHERE re.id = NEW.source_routine_exercise_id
        AND re.gym_id = NEW.gym_id
        AND re.exercise_id = NEW.source_exercise_id
    ) THEN
      RAISE EXCEPTION 'Workout exercise sources must match the same routine exercise origin' USING ERRCODE = '23503';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION private.guard_workout_set_integrity()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_exercise public.workout_exercises%ROWTYPE;
  v_session public.workout_sessions%ROWTYPE;
BEGIN
  SELECT * INTO v_exercise
  FROM public.workout_exercises
  WHERE id = NEW.workout_exercise_id
    AND gym_id = NEW.gym_id
  FOR SHARE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Workout set exercise must exist in the same tenant' USING ERRCODE = '23503';
  END IF;

  SELECT * INTO v_session
  FROM public.workout_sessions
  WHERE id = v_exercise.workout_session_id
    AND gym_id = v_exercise.gym_id
  FOR SHARE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Workout set session must exist in the same tenant' USING ERRCODE = '23503';
  END IF;

  IF TG_OP = 'UPDATE' THEN
    IF NEW.id IS DISTINCT FROM OLD.id
       OR NEW.gym_id IS DISTINCT FROM OLD.gym_id
       OR NEW.workout_exercise_id IS DISTINCT FROM OLD.workout_exercise_id
       OR NEW.set_number IS DISTINCT FROM OLD.set_number
       OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
      RAISE EXCEPTION 'Workout set identity fields are immutable' USING ERRCODE = '23514';
    END IF;
  END IF;

  IF v_session.status <> 'IN_PROGRESS' THEN
    RAISE EXCEPTION 'Workout sets are immutable after workout finalization' USING ERRCODE = '55000';
  END IF;

  IF NEW.status = 'PLANNED' THEN
    IF NEW.completed_at IS NOT NULL
       OR NEW.reps IS NOT NULL
       OR NEW.weight IS NOT NULL
       OR NEW.duration_seconds IS NOT NULL
       OR NEW.distance_meters IS NOT NULL THEN
      RAISE EXCEPTION 'PLANNED workout sets cannot include completion data' USING ERRCODE = '23514';
    END IF;
  ELSE
    PERFORM private.assert_workout_set_payload(
      v_exercise.tracking_type,
      NEW.status,
      NEW.reps,
      NEW.weight,
      NEW.duration_seconds,
      NEW.distance_meters
    );
    IF NEW.completed_at IS NULL THEN
      RAISE EXCEPTION 'Completed or skipped workout sets require completed_at' USING ERRCODE = '23514';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION private.guard_workout_session_integrity() FROM PUBLIC;
REVOKE ALL ON FUNCTION private.guard_workout_exercise_integrity() FROM PUBLIC;
REVOKE ALL ON FUNCTION private.guard_workout_set_integrity() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION private.guard_workout_session_integrity() TO postgres, service_role;
GRANT EXECUTE ON FUNCTION private.guard_workout_exercise_integrity() TO postgres, service_role;
GRANT EXECUTE ON FUNCTION private.guard_workout_set_integrity() TO postgres, service_role;

CREATE TRIGGER trg_workout_sessions_integrity
  BEFORE INSERT OR UPDATE ON public.workout_sessions
  FOR EACH ROW EXECUTE FUNCTION private.guard_workout_session_integrity();

CREATE TRIGGER trg_workout_exercises_integrity
  BEFORE INSERT OR UPDATE ON public.workout_exercises
  FOR EACH ROW EXECUTE FUNCTION private.guard_workout_exercise_integrity();

CREATE TRIGGER trg_workout_sets_integrity
  BEFORE INSERT OR UPDATE ON public.workout_sets
  FOR EACH ROW EXECUTE FUNCTION private.guard_workout_set_integrity();