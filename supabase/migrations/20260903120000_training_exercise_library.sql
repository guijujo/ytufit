-- YtuFit v2.0.3-A: Training exercise library.
-- This stage intentionally models only the exercise catalog: no routines,
-- workouts, sets, progress or attendance integration.

CREATE TYPE public.exercise_scope AS ENUM ('GLOBAL', 'GYM');
CREATE TYPE public.exercise_status AS ENUM ('ACTIVE', 'INACTIVE');
CREATE TYPE public.exercise_tracking_type AS ENUM (
  'WEIGHT_REPS',
  'REPS',
  'TIME',
  'DISTANCE_TIME',
  'WEIGHT_TIME',
  'WEIGHT_DISTANCE'
);
CREATE TYPE public.muscle_involvement AS ENUM ('PRIMARY', 'SECONDARY');
CREATE TYPE public.exercise_category AS ENUM ('STRENGTH', 'CARDIO', 'MOBILITY', 'STRETCHING');
CREATE TYPE public.exercise_movement_pattern AS ENUM (
  'PUSH',
  'PULL',
  'SQUAT',
  'HINGE',
  'LUNGE',
  'CARRY',
  'ROTATION',
  'ISOMETRIC',
  'CARDIO'
);

CREATE TABLE public.muscle_groups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL CHECK (length(btrim(name)) > 0),
  code TEXT NOT NULL UNIQUE CHECK (code ~ '^[a-z0-9_]+$'),
  display_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);

CREATE TABLE public.muscles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  muscle_group_id UUID NOT NULL REFERENCES public.muscle_groups(id) ON DELETE RESTRICT,
  name TEXT NOT NULL CHECK (length(btrim(name)) > 0),
  code TEXT NOT NULL UNIQUE CHECK (code ~ '^[a-z0-9_]+$'),
  map_key TEXT NULL CHECK (map_key IS NULL OR map_key ~ '^[a-z0-9_]+$'),
  created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);

CREATE INDEX idx_muscles_muscle_group_id ON public.muscles(muscle_group_id);

CREATE TABLE public.equipment (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL CHECK (length(btrim(name)) > 0),
  code TEXT NOT NULL UNIQUE CHECK (code ~ '^[a-z0-9_]+$'),
  created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);

CREATE TABLE public.exercises (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  scope public.exercise_scope NOT NULL,
  gym_id UUID NULL REFERENCES public.gyms(id) ON DELETE CASCADE,
  name TEXT NOT NULL CHECK (length(btrim(name)) > 0),
  slug TEXT NOT NULL CHECK (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  description TEXT NULL,
  instructions TEXT[] NULL,
  tracking_type public.exercise_tracking_type NOT NULL,
  status public.exercise_status NOT NULL DEFAULT 'ACTIVE',
  category public.exercise_category NOT NULL,
  movement_pattern public.exercise_movement_pattern NOT NULL,
  image_url TEXT NULL,
  animation_url TEXT NULL,
  created_by UUID NULL REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
  deleted_at TIMESTAMPTZ NULL,
  CONSTRAINT exercises_scope_gym_check CHECK (
    (scope = 'GLOBAL' AND gym_id IS NULL)
    OR (scope = 'GYM' AND gym_id IS NOT NULL)
  ),
  CONSTRAINT exercises_deleted_status_check CHECK (
    (deleted_at IS NULL)
    OR (deleted_at IS NOT NULL AND status = 'INACTIVE')
  )
);

CREATE INDEX idx_exercises_gym_id ON public.exercises(gym_id);
CREATE INDEX idx_exercises_status ON public.exercises(status);
CREATE UNIQUE INDEX idx_exercises_global_slug
  ON public.exercises (slug)
  WHERE scope = 'GLOBAL' AND gym_id IS NULL;
CREATE UNIQUE INDEX idx_exercises_gym_slug
  ON public.exercises (gym_id, slug)
  WHERE scope = 'GYM';

CREATE TABLE public.exercise_muscles (
  exercise_id UUID NOT NULL REFERENCES public.exercises(id) ON DELETE CASCADE,
  muscle_id UUID NOT NULL REFERENCES public.muscles(id) ON DELETE RESTRICT,
  involvement public.muscle_involvement NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
  PRIMARY KEY (exercise_id, muscle_id)
);

CREATE INDEX idx_exercise_muscles_muscle_id ON public.exercise_muscles(muscle_id);

CREATE TABLE public.exercise_equipment (
  exercise_id UUID NOT NULL REFERENCES public.exercises(id) ON DELETE CASCADE,
  equipment_id UUID NOT NULL REFERENCES public.equipment(id) ON DELETE RESTRICT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
  PRIMARY KEY (exercise_id, equipment_id)
);

CREATE INDEX idx_exercise_equipment_equipment_id ON public.exercise_equipment(equipment_id);

CREATE TRIGGER trg_muscle_groups_updated_at
  BEFORE UPDATE ON public.muscle_groups
  FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();
CREATE TRIGGER trg_muscles_updated_at
  BEFORE UPDATE ON public.muscles
  FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();
CREATE TRIGGER trg_equipment_updated_at
  BEFORE UPDATE ON public.equipment
  FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();
CREATE TRIGGER trg_exercises_updated_at
  BEFORE UPDATE ON public.exercises
  FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();

CREATE OR REPLACE FUNCTION private.can_read_exercise(
  p_scope public.exercise_scope,
  p_gym_id UUID,
  p_status public.exercise_status
) RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
  SELECT
    (
      p_scope = 'GLOBAL'
      AND (
        private.is_platform_admin()
        OR (p_status = 'ACTIVE' AND (SELECT auth.uid()) IS NOT NULL)
      )
    )
    OR (p_scope = 'GYM' AND p_gym_id IS NOT NULL AND private.is_gym_member(p_gym_id));
$$;

CREATE OR REPLACE FUNCTION private.can_manage_gym_training(p_gym_id UUID)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
  SELECT private.has_gym_role(p_gym_id, 'GYM_ADMIN')
    OR private.has_gym_role(p_gym_id, 'TRAINER');
$$;

CREATE OR REPLACE FUNCTION private.guard_exercise_update()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
  IF (SELECT auth.uid()) IS NOT NULL
     AND COALESCE(current_setting('ytufit.command', true), '') <> 'exercise' THEN
    RAISE EXCEPTION 'Exercise changes require a server-side command' USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION private.can_read_exercise(public.exercise_scope, UUID, public.exercise_status) FROM PUBLIC;
REVOKE ALL ON FUNCTION private.can_manage_gym_training(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION private.guard_exercise_update() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION private.can_read_exercise(public.exercise_scope, UUID, public.exercise_status) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.can_manage_gym_training(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.guard_exercise_update() TO postgres, service_role;

CREATE TRIGGER trg_exercises_guard_update
  BEFORE UPDATE ON public.exercises
  FOR EACH ROW EXECUTE FUNCTION private.guard_exercise_update();

ALTER TABLE public.muscle_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.muscle_groups FORCE ROW LEVEL SECURITY;
ALTER TABLE public.muscles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.muscles FORCE ROW LEVEL SECURITY;
ALTER TABLE public.equipment ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.equipment FORCE ROW LEVEL SECURITY;
ALTER TABLE public.exercises ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exercises FORCE ROW LEVEL SECURITY;
ALTER TABLE public.exercise_muscles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exercise_muscles FORCE ROW LEVEL SECURITY;
ALTER TABLE public.exercise_equipment ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exercise_equipment FORCE ROW LEVEL SECURITY;

CREATE POLICY muscle_groups_select_authenticated ON public.muscle_groups
  FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) IS NOT NULL);
CREATE POLICY muscles_select_authenticated ON public.muscles
  FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) IS NOT NULL);
CREATE POLICY equipment_select_authenticated ON public.equipment
  FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) IS NOT NULL);

CREATE POLICY exercises_select_visible ON public.exercises
  FOR SELECT TO authenticated
  USING (private.can_read_exercise(scope, gym_id, status));
CREATE POLICY exercise_muscles_select_visible ON public.exercise_muscles
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.exercises e
      WHERE e.id = exercise_muscles.exercise_id
        AND private.can_read_exercise(e.scope, e.gym_id, e.status)
    )
  );
CREATE POLICY exercise_equipment_select_visible ON public.exercise_equipment
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.exercises e
      WHERE e.id = exercise_equipment.exercise_id
        AND private.can_read_exercise(e.scope, e.gym_id, e.status)
    )
  );

REVOKE INSERT, UPDATE, DELETE ON public.muscle_groups, public.muscles, public.equipment,
  public.exercises, public.exercise_muscles, public.exercise_equipment FROM anon, authenticated;
GRANT SELECT ON public.muscle_groups, public.muscles, public.equipment,
  public.exercises, public.exercise_muscles, public.exercise_equipment TO authenticated;
GRANT USAGE ON TYPE public.exercise_scope, public.exercise_status,
  public.exercise_tracking_type, public.muscle_involvement, public.exercise_category,
  public.exercise_movement_pattern TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.create_gym_exercise(
  p_gym_id UUID,
  p_name TEXT,
  p_slug TEXT,
  p_description TEXT,
  p_instructions TEXT[],
  p_tracking_type public.exercise_tracking_type,
  p_category public.exercise_category,
  p_movement_pattern public.exercise_movement_pattern,
  p_image_url TEXT DEFAULT NULL,
  p_animation_url TEXT DEFAULT NULL
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE v_actor UUID := (SELECT auth.uid()); v_id UUID;
BEGIN
  IF v_actor IS NULL OR NOT private.can_manage_gym_training(p_gym_id) THEN
    RAISE EXCEPTION 'Training administration authorization required' USING ERRCODE = '42501';
  END IF;
  INSERT INTO public.exercises (
    scope, gym_id, name, slug, description, instructions, tracking_type,
    category, movement_pattern, image_url, animation_url, created_by
  ) VALUES (
    'GYM', p_gym_id, p_name, p_slug, p_description, p_instructions, p_tracking_type,
    p_category, p_movement_pattern, p_image_url, p_animation_url, v_actor
  ) RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.update_gym_exercise(
  p_exercise_id UUID,
  p_name TEXT,
  p_slug TEXT,
  p_description TEXT,
  p_instructions TEXT[],
  p_tracking_type public.exercise_tracking_type,
  p_category public.exercise_category,
  p_movement_pattern public.exercise_movement_pattern,
  p_status public.exercise_status,
  p_image_url TEXT DEFAULT NULL,
  p_animation_url TEXT DEFAULT NULL
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE v_exercise public.exercises%ROWTYPE; v_id UUID;
BEGIN
  SELECT * INTO v_exercise FROM public.exercises WHERE id = p_exercise_id FOR UPDATE;
  IF NOT FOUND OR v_exercise.scope <> 'GYM' THEN
    RAISE EXCEPTION 'Gym exercise not found' USING ERRCODE = 'P0002';
  END IF;
  IF NOT private.can_manage_gym_training(v_exercise.gym_id) THEN
    RAISE EXCEPTION 'Training administration authorization required' USING ERRCODE = '42501';
  END IF;
  PERFORM set_config('ytufit.command', 'exercise', true);
  UPDATE public.exercises SET
    name = p_name,
    slug = p_slug,
    description = p_description,
    instructions = p_instructions,
    tracking_type = p_tracking_type,
    category = p_category,
    movement_pattern = p_movement_pattern,
    status = p_status,
    image_url = p_image_url,
    animation_url = p_animation_url,
    deleted_at = CASE WHEN p_status = 'INACTIVE' THEN COALESCE(deleted_at, clock_timestamp()) ELSE NULL END
  WHERE id = p_exercise_id
  RETURNING id INTO v_id;
  PERFORM set_config('ytufit.command', '', true);
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.archive_gym_exercise(p_exercise_id UUID)
RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE v_exercise public.exercises%ROWTYPE; v_id UUID;
BEGIN
  SELECT * INTO v_exercise FROM public.exercises WHERE id = p_exercise_id FOR UPDATE;
  IF NOT FOUND OR v_exercise.scope <> 'GYM' THEN
    RAISE EXCEPTION 'Gym exercise not found' USING ERRCODE = 'P0002';
  END IF;
  IF NOT private.can_manage_gym_training(v_exercise.gym_id) THEN
    RAISE EXCEPTION 'Training administration authorization required' USING ERRCODE = '42501';
  END IF;
  PERFORM set_config('ytufit.command', 'exercise', true);
  UPDATE public.exercises
    SET status = 'INACTIVE', deleted_at = COALESCE(deleted_at, clock_timestamp())
    WHERE id = p_exercise_id
    RETURNING id INTO v_id;
  PERFORM set_config('ytufit.command', '', true);
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.create_global_exercise(
  p_name TEXT,
  p_slug TEXT,
  p_description TEXT,
  p_instructions TEXT[],
  p_tracking_type public.exercise_tracking_type,
  p_category public.exercise_category,
  p_movement_pattern public.exercise_movement_pattern,
  p_image_url TEXT DEFAULT NULL,
  p_animation_url TEXT DEFAULT NULL
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE v_actor UUID := (SELECT auth.uid()); v_id UUID;
BEGIN
  IF v_actor IS NULL OR NOT private.is_platform_admin() THEN
    RAISE EXCEPTION 'Platform administration authorization required' USING ERRCODE = '42501';
  END IF;
  INSERT INTO public.exercises (
    scope, gym_id, name, slug, description, instructions, tracking_type,
    category, movement_pattern, image_url, animation_url, created_by
  ) VALUES (
    'GLOBAL', NULL, p_name, p_slug, p_description, p_instructions, p_tracking_type,
    p_category, p_movement_pattern, p_image_url, p_animation_url, v_actor
  ) RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.update_global_exercise(
  p_exercise_id UUID,
  p_name TEXT,
  p_slug TEXT,
  p_description TEXT,
  p_instructions TEXT[],
  p_tracking_type public.exercise_tracking_type,
  p_category public.exercise_category,
  p_movement_pattern public.exercise_movement_pattern,
  p_status public.exercise_status,
  p_image_url TEXT DEFAULT NULL,
  p_animation_url TEXT DEFAULT NULL
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE v_exercise public.exercises%ROWTYPE; v_id UUID;
BEGIN
  IF NOT private.is_platform_admin() THEN
    RAISE EXCEPTION 'Platform administration authorization required' USING ERRCODE = '42501';
  END IF;
  SELECT * INTO v_exercise FROM public.exercises WHERE id = p_exercise_id FOR UPDATE;
  IF NOT FOUND OR v_exercise.scope <> 'GLOBAL' THEN
    RAISE EXCEPTION 'Global exercise not found' USING ERRCODE = 'P0002';
  END IF;
  PERFORM set_config('ytufit.command', 'exercise', true);
  UPDATE public.exercises SET
    name = p_name,
    slug = p_slug,
    description = p_description,
    instructions = p_instructions,
    tracking_type = p_tracking_type,
    category = p_category,
    movement_pattern = p_movement_pattern,
    status = p_status,
    image_url = p_image_url,
    animation_url = p_animation_url,
    deleted_at = CASE WHEN p_status = 'INACTIVE' THEN COALESCE(deleted_at, clock_timestamp()) ELSE NULL END
  WHERE id = p_exercise_id
  RETURNING id INTO v_id;
  PERFORM set_config('ytufit.command', '', true);
  RETURN v_id;
END;
$$;


CREATE OR REPLACE FUNCTION public.set_exercise_muscles(
  p_exercise_id UUID,
  p_muscles JSONB
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_exercise public.exercises%ROWTYPE;
  v_actor UUID := (SELECT auth.uid());
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
  END IF;
  IF p_muscles IS NULL OR jsonb_typeof(p_muscles) <> 'array' THEN
    RAISE EXCEPTION 'muscles must be a JSON array' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_exercise FROM public.exercises WHERE id = p_exercise_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Exercise not found' USING ERRCODE = 'P0002';
  END IF;

  IF v_exercise.scope = 'GLOBAL' THEN
    IF NOT private.is_platform_admin() THEN
      RAISE EXCEPTION 'Platform administration authorization required' USING ERRCODE = '42501';
    END IF;
  ELSIF v_exercise.scope = 'GYM' THEN
    IF NOT private.can_manage_gym_training(v_exercise.gym_id) THEN
      RAISE EXCEPTION 'Training administration authorization required' USING ERRCODE = '42501';
    END IF;
  ELSE
    RAISE EXCEPTION 'Unsupported exercise scope' USING ERRCODE = '22023';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM jsonb_array_elements(p_muscles) item
    WHERE jsonb_typeof(item) <> 'object'
      OR NOT (item ? 'muscle_id')
      OR NOT (item ? 'involvement')
      OR item->>'involvement' NOT IN ('PRIMARY', 'SECONDARY')
  ) THEN
    RAISE EXCEPTION 'Each muscle must include muscle_id and PRIMARY or SECONDARY involvement' USING ERRCODE = '22023';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM jsonb_array_elements(p_muscles) item
    GROUP BY item->>'muscle_id'
    HAVING count(*) > 1
  ) THEN
    RAISE EXCEPTION 'A muscle can only appear once per exercise' USING ERRCODE = '23505';
  END IF;

  IF jsonb_array_length(p_muscles) > 0
     AND v_exercise.category <> 'CARDIO'
     AND NOT EXISTS (
       SELECT 1 FROM jsonb_array_elements(p_muscles) item
       WHERE item->>'involvement' = 'PRIMARY'
     ) THEN
    RAISE EXCEPTION 'At least one PRIMARY muscle is required for non-cardio exercises' USING ERRCODE = '23514';
  END IF;

  DELETE FROM public.exercise_muscles WHERE exercise_id = p_exercise_id;
  INSERT INTO public.exercise_muscles (exercise_id, muscle_id, involvement)
  SELECT
    p_exercise_id,
    (item->>'muscle_id')::uuid,
    (item->>'involvement')::public.muscle_involvement
  FROM jsonb_array_elements(p_muscles) item;

  RETURN p_exercise_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.set_exercise_equipment(
  p_exercise_id UUID,
  p_equipment_ids UUID[]
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_exercise public.exercises%ROWTYPE;
  v_actor UUID := (SELECT auth.uid());
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
  END IF;
  IF p_equipment_ids IS NULL THEN
    RAISE EXCEPTION 'equipment_ids is required' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_exercise FROM public.exercises WHERE id = p_exercise_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Exercise not found' USING ERRCODE = 'P0002';
  END IF;

  IF v_exercise.scope = 'GLOBAL' THEN
    IF NOT private.is_platform_admin() THEN
      RAISE EXCEPTION 'Platform administration authorization required' USING ERRCODE = '42501';
    END IF;
  ELSIF v_exercise.scope = 'GYM' THEN
    IF NOT private.can_manage_gym_training(v_exercise.gym_id) THEN
      RAISE EXCEPTION 'Training administration authorization required' USING ERRCODE = '42501';
    END IF;
  ELSE
    RAISE EXCEPTION 'Unsupported exercise scope' USING ERRCODE = '22023';
  END IF;

  IF EXISTS (
    SELECT 1 FROM unnest(p_equipment_ids) AS equipment_id
    GROUP BY equipment_id HAVING count(*) > 1
  ) THEN
    RAISE EXCEPTION 'Equipment can only appear once per exercise' USING ERRCODE = '23505';
  END IF;

  DELETE FROM public.exercise_equipment WHERE exercise_id = p_exercise_id;
  INSERT INTO public.exercise_equipment (exercise_id, equipment_id)
  SELECT p_exercise_id, equipment_id
  FROM unnest(p_equipment_ids) AS equipment_id;

  RETURN p_exercise_id;
END;
$$;

CREATE OR REPLACE FUNCTION public."setExerciseMuscles"(p_exercise_id UUID, p_muscles JSONB)
RETURNS UUID LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog, public
AS $$ SELECT public.set_exercise_muscles($1,$2) $$;
CREATE OR REPLACE FUNCTION public."setExerciseEquipment"(p_exercise_id UUID, p_equipment_ids UUID[])
RETURNS UUID LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog, public
AS $$ SELECT public.set_exercise_equipment($1,$2) $$;

CREATE OR REPLACE FUNCTION public."createGymExercise"(p_gym_id UUID, p_name TEXT, p_slug TEXT, p_description TEXT, p_instructions TEXT[], p_tracking_type public.exercise_tracking_type, p_category public.exercise_category, p_movement_pattern public.exercise_movement_pattern, p_image_url TEXT DEFAULT NULL, p_animation_url TEXT DEFAULT NULL)
RETURNS UUID LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog, public
AS $$ SELECT public.create_gym_exercise($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) $$;
CREATE OR REPLACE FUNCTION public."updateGymExercise"(p_exercise_id UUID, p_name TEXT, p_slug TEXT, p_description TEXT, p_instructions TEXT[], p_tracking_type public.exercise_tracking_type, p_category public.exercise_category, p_movement_pattern public.exercise_movement_pattern, p_status public.exercise_status, p_image_url TEXT DEFAULT NULL, p_animation_url TEXT DEFAULT NULL)
RETURNS UUID LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog, public
AS $$ SELECT public.update_gym_exercise($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11) $$;
CREATE OR REPLACE FUNCTION public."archiveGymExercise"(p_exercise_id UUID)
RETURNS UUID LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog, public
AS $$ SELECT public.archive_gym_exercise($1) $$;
CREATE OR REPLACE FUNCTION public."createGlobalExercise"(p_name TEXT, p_slug TEXT, p_description TEXT, p_instructions TEXT[], p_tracking_type public.exercise_tracking_type, p_category public.exercise_category, p_movement_pattern public.exercise_movement_pattern, p_image_url TEXT DEFAULT NULL, p_animation_url TEXT DEFAULT NULL)
RETURNS UUID LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog, public
AS $$ SELECT public.create_global_exercise($1,$2,$3,$4,$5,$6,$7,$8,$9) $$;
CREATE OR REPLACE FUNCTION public."updateGlobalExercise"(p_exercise_id UUID, p_name TEXT, p_slug TEXT, p_description TEXT, p_instructions TEXT[], p_tracking_type public.exercise_tracking_type, p_category public.exercise_category, p_movement_pattern public.exercise_movement_pattern, p_status public.exercise_status, p_image_url TEXT DEFAULT NULL, p_animation_url TEXT DEFAULT NULL)
RETURNS UUID LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog, public
AS $$ SELECT public.update_global_exercise($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11) $$;

DO $$
DECLARE f RECORD;
BEGIN
  FOR f IN
    SELECT p.oid::regprocedure AS signature
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname IN (
        'create_gym_exercise', 'update_gym_exercise', 'archive_gym_exercise',
        'create_global_exercise', 'update_global_exercise',
        'set_exercise_muscles', 'set_exercise_equipment',
        'createGymExercise', 'updateGymExercise', 'archiveGymExercise',
        'createGlobalExercise', 'updateGlobalExercise',
        'setExerciseMuscles', 'setExerciseEquipment'
      )
  LOOP
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC', f.signature);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated, service_role', f.signature);
  END LOOP;
END $$;



