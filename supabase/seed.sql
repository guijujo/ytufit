-- Deterministic seed fixtures for testing and local development
-- YtuFit v2.0.1: Multi-tenant identity fixtures

-- 1. Deterministic test auth users
INSERT INTO auth.users (
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at
) VALUES
  ('11111111-1111-1111-1111-111111111111', 'authenticated', 'authenticated', 'admin-a@ytufit.local', crypt('Password123!', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"first_name":"Admin","last_name":"Alpha"}', now(), now()),
  ('22222222-2222-2222-2222-222222222222', 'authenticated', 'authenticated', 'trainer-a@ytufit.local', crypt('Password123!', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"first_name":"Trainer","last_name":"Alpha"}', now(), now()),
  ('33333333-3333-3333-3333-333333333333', 'authenticated', 'authenticated', 'member-a@ytufit.local', crypt('Password123!', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"first_name":"Member","last_name":"Alpha"}', now(), now()),
  ('44444444-4444-4444-4444-444444444444', 'authenticated', 'authenticated', 'admin-b@ytufit.local', crypt('Password123!', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"first_name":"Admin","last_name":"Beta"}', now(), now()),
  ('55555555-5555-5555-5555-555555555555', 'authenticated', 'authenticated', 'member-b@ytufit.local', crypt('Password123!', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"first_name":"Member","last_name":"Beta"}', now(), now()),
  ('99999999-9999-9999-9999-999999999999', 'authenticated', 'authenticated', 'platform-admin@ytufit.local', crypt('Password123!', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"first_name":"Platform","last_name":"SuperAdmin"}', now(), now())
ON CONFLICT (id) DO NOTHING;

-- 2. Ensure profiles exist with expected metadata
INSERT INTO public.profiles (id, first_name, last_name, status) VALUES
  ('11111111-1111-1111-1111-111111111111', 'Admin', 'Alpha', 'ACTIVE'),
  ('22222222-2222-2222-2222-222222222222', 'Trainer', 'Alpha', 'ACTIVE'),
  ('33333333-3333-3333-3333-333333333333', 'Member', 'Alpha', 'ACTIVE'),
  ('44444444-4444-4444-4444-444444444444', 'Admin', 'Beta', 'ACTIVE'),
  ('55555555-5555-5555-5555-555555555555', 'Member', 'Beta', 'ACTIVE'),
  ('99999999-9999-9999-9999-999999999999', 'Platform', 'SuperAdmin', 'ACTIVE')
ON CONFLICT (id) DO UPDATE SET
  first_name = EXCLUDED.first_name,
  last_name = EXCLUDED.last_name,
  status = EXCLUDED.status;

-- 3. Gyms (Gym A and Gym B)
INSERT INTO public.gyms (id, name, slug, status, timezone) VALUES
  ('00000000-0000-0000-0000-000000000001', 'Gym Alpha', 'gym-alpha', 'ACTIVE', 'America/Montevideo'),
  ('00000000-0000-0000-0000-000000000002', 'Gym Beta', 'gym-beta', 'ACTIVE', 'America/Montevideo')
ON CONFLICT (id) DO NOTHING;

-- 4. Platform Admins
INSERT INTO public.platform_admins (user_id) VALUES
  ('99999999-9999-9999-9999-999999999999')
ON CONFLICT (user_id) DO NOTHING;

-- 5. Gym Members
INSERT INTO public.gym_members (id, gym_id, user_id, status) VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '00000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'ACTIVE'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '00000000-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', 'ACTIVE'),
  ('cccccccc-cccc-cccc-cccc-cccccccccccc', '00000000-0000-0000-0000-000000000001', '33333333-3333-3333-3333-333333333333', 'ACTIVE'),
  ('dddddddd-dddd-dddd-dddd-dddddddddddd', '00000000-0000-0000-0000-000000000002', '44444444-4444-4444-4444-444444444444', 'ACTIVE'),
  ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', '00000000-0000-0000-0000-000000000002', '55555555-5555-5555-5555-555555555555', 'ACTIVE')
ON CONFLICT (gym_id, user_id) DO NOTHING;

-- 6. Gym Member Roles
INSERT INTO public.gym_member_roles (gym_member_id, role_id)
SELECT 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid, r.id FROM public.roles r WHERE r.name = 'GYM_ADMIN'
UNION ALL
SELECT 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'::uuid, r.id FROM public.roles r WHERE r.name = 'TRAINER'
UNION ALL
SELECT 'cccccccc-cccc-cccc-cccc-cccccccccccc'::uuid, r.id FROM public.roles r WHERE r.name = 'MEMBER'
UNION ALL
SELECT 'dddddddd-dddd-dddd-dddd-dddddddddddd'::uuid, r.id FROM public.roles r WHERE r.name = 'GYM_ADMIN'
UNION ALL
SELECT 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee'::uuid, r.id FROM public.roles r WHERE r.name = 'MEMBER'
ON CONFLICT (gym_member_id, role_id) DO NOTHING;

-- 7. Membership plans (tenant-local commercial configuration)
INSERT INTO public.membership_plans (
  id, gym_id, name, description, access_type, access_limit,
  frequency_period, target, price, currency, duration_days
) VALUES
  ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001',
   'Tres por semana', 'Frecuencia semanal', 'WEEKLY_FREQUENCY', NULL, 'WEEK', 3, 30000, 'ARS', 30),
  ('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000001',
   'Doce por mes', 'LÃƒÂ­mite mensual', 'MONTHLY_LIMIT', NULL, 'MONTH', 12, 36000, 'ARS', 30),
  ('10000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000001',
   'Pase Libre', 'Acceso sin lÃƒÂ­mite comercial', 'UNLIMITED', NULL, NULL, NULL, 45000, 'ARS', 30),
  ('20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002',
   'Plan Beta', 'Plan independiente de Gym Beta', 'ACCESS_COUNT', 10, NULL, NULL, 10000, 'ARS', 10)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  access_type = EXCLUDED.access_type,
  access_limit = EXCLUDED.access_limit,
  frequency_period = EXCLUDED.frequency_period,
  target = EXCLUDED.target,
  price = EXCLUDED.price,
  currency = EXCLUDED.currency,
  duration_days = EXCLUDED.duration_days,
  status = 'ACTIVE',
  deleted_at = NULL;

-- 8. Contract snapshots for deterministic member history
INSERT INTO public.memberships (
  id, gym_id, gym_member_id, membership_plan_id, status, starts_at, ends_at,
  contracted_price, currency, access_limit_snapshot, access_type_snapshot,
  target_snapshot, period_snapshot
) VALUES
  ('30000000-0000-0000-0000-000000000001',
   '00000000-0000-0000-0000-000000000001',
   'cccccccc-cccc-cccc-cccc-cccccccccccc',
   '10000000-0000-0000-0000-000000000001',
   'ACTIVE', '2020-01-01 00:00:00+00', '2099-01-01 00:00:00+00',
   30000, 'ARS', NULL, 'WEEKLY_FREQUENCY', 3, 'WEEK'),
  ('30000000-0000-0000-0000-000000000002',
   '00000000-0000-0000-0000-000000000002',
   'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
   '20000000-0000-0000-0000-000000000001',
   'ACTIVE', '2020-01-01 00:00:00+00', '2099-01-01 00:00:00+00',
   10000, 'ARS', 10, 'ACCESS_COUNT', NULL, NULL)
ON CONFLICT (id) DO NOTHING;

-- 9. Attendance history: valid rows and one retained cancellation.
INSERT INTO public.attendances (
  id, gym_id, gym_member_id, membership_id, attendance_date, occurred_at,
  method, status, source_reference, created_by,
  cancellation_reason, cancelled_by, cancelled_at
) VALUES
  ('40000000-0000-0000-0000-000000000001',
   '00000000-0000-0000-0000-000000000001',
   'cccccccc-cccc-cccc-cccc-cccccccccccc',
   '30000000-0000-0000-0000-000000000001',
   '2026-08-04', '2026-08-04 18:00:00+00', 'QR', 'VALID',
   'seed-a-1', '33333333-3333-3333-3333-333333333333', NULL, NULL, NULL),
  ('40000000-0000-0000-0000-000000000002',
   '00000000-0000-0000-0000-000000000001',
   'cccccccc-cccc-cccc-cccc-cccccccccccc',
   '30000000-0000-0000-0000-000000000001',
   '2026-08-05', '2026-08-05 18:00:00+00', 'MANUAL', 'CANCELLED',
   'seed-a-cancelled', '33333333-3333-3333-3333-333333333333',
   'Correction fixture', '11111111-1111-1111-1111-111111111111',
   '2026-08-06 12:00:00+00'),
  ('40000000-0000-0000-0000-000000000003',
   '00000000-0000-0000-0000-000000000002',
   'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
   '30000000-0000-0000-0000-000000000002',
   '2026-08-04', '2026-08-04 18:00:00+00', 'QR', 'VALID',
   'seed-b-1', '55555555-5555-5555-5555-555555555555', NULL, NULL, NULL)
ON CONFLICT (id) DO NOTHING;

-- 10. Training exercise library catalogs
INSERT INTO public.muscle_groups (id, name, code, display_order) VALUES
  ('51000000-0000-0000-0000-000000000001', 'Chest', 'chest', 10),
  ('51000000-0000-0000-0000-000000000002', 'Shoulders', 'shoulders', 20),
  ('51000000-0000-0000-0000-000000000003', 'Arms', 'arms', 30),
  ('51000000-0000-0000-0000-000000000004', 'Back', 'back', 40),
  ('51000000-0000-0000-0000-000000000005', 'Legs', 'legs', 50),
  ('51000000-0000-0000-0000-000000000006', 'Core', 'core', 60),
  ('51000000-0000-0000-0000-000000000007', 'Cardio', 'cardio', 70)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  code = EXCLUDED.code,
  display_order = EXCLUDED.display_order;

INSERT INTO public.muscles (id, muscle_group_id, name, code, map_key) VALUES
  ('52000000-0000-0000-0000-000000000001', '51000000-0000-0000-0000-000000000001', 'Pectoralis major', 'pectoralis_major', 'pectoralis_major'),
  ('52000000-0000-0000-0000-000000000002', '51000000-0000-0000-0000-000000000002', 'Anterior deltoid', 'anterior_deltoid', 'anterior_deltoid'),
  ('52000000-0000-0000-0000-000000000003', '51000000-0000-0000-0000-000000000003', 'Triceps', 'triceps', 'triceps'),
  ('52000000-0000-0000-0000-000000000004', '51000000-0000-0000-0000-000000000003', 'Biceps', 'biceps', 'biceps'),
  ('52000000-0000-0000-0000-000000000005', '51000000-0000-0000-0000-000000000004', 'Latissimus dorsi', 'latissimus_dorsi', 'latissimus_dorsi'),
  ('52000000-0000-0000-0000-000000000006', '51000000-0000-0000-0000-000000000005', 'Quadriceps', 'quadriceps', 'quadriceps'),
  ('52000000-0000-0000-0000-000000000007', '51000000-0000-0000-0000-000000000005', 'Hamstrings', 'hamstrings', 'hamstrings'),
  ('52000000-0000-0000-0000-000000000008', '51000000-0000-0000-0000-000000000005', 'Gluteus maximus', 'gluteus_maximus', 'gluteus_maximus'),
  ('52000000-0000-0000-0000-000000000009', '51000000-0000-0000-0000-000000000005', 'Calves', 'calves', 'calves'),
  ('52000000-0000-0000-0000-000000000010', '51000000-0000-0000-0000-000000000006', 'Rectus abdominis', 'rectus_abdominis', 'rectus_abdominis'),
  ('52000000-0000-0000-0000-000000000011', '51000000-0000-0000-0000-000000000007', 'Cardiorespiratory system', 'cardiorespiratory_system', 'cardiorespiratory_system')
ON CONFLICT (id) DO UPDATE SET
  muscle_group_id = EXCLUDED.muscle_group_id,
  name = EXCLUDED.name,
  code = EXCLUDED.code,
  map_key = EXCLUDED.map_key;

INSERT INTO public.equipment (id, name, code) VALUES
  ('53000000-0000-0000-0000-000000000001', 'Barbell', 'barbell'),
  ('53000000-0000-0000-0000-000000000002', 'Dumbbell', 'dumbbell'),
  ('53000000-0000-0000-0000-000000000003', 'Bodyweight', 'bodyweight'),
  ('53000000-0000-0000-0000-000000000004', 'Bench', 'bench'),
  ('53000000-0000-0000-0000-000000000005', 'Pull-up bar', 'pull_up_bar'),
  ('53000000-0000-0000-0000-000000000006', 'Cardio machine', 'cardio_machine')
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  code = EXCLUDED.code;

-- 11. Minimal deterministic exercise library
INSERT INTO public.exercises (
  id, scope, gym_id, name, slug, description, instructions, tracking_type,
  category, movement_pattern, created_by
) VALUES
  ('54000000-0000-0000-0000-000000000001', 'GLOBAL', NULL, 'Press de banca', 'press-de-banca',
   'Empuje horizontal con barra en banco plano.', ARRAY['Ubicar la espalda en el banco.', 'Bajar la barra con control.', 'Empujar hasta extender los brazos.'], 'WEIGHT_REPS', 'STRENGTH', 'PUSH', '99999999-9999-9999-9999-999999999999'),
  ('54000000-0000-0000-0000-000000000002', 'GLOBAL', NULL, 'Sentadilla', 'sentadilla',
   'Patron dominante de rodilla con carga externa.', ARRAY['Apoyar la barra de forma estable.', 'Descender manteniendo control.', 'Subir empujando el piso.'], 'WEIGHT_REPS', 'STRENGTH', 'SQUAT', '99999999-9999-9999-9999-999999999999'),
  ('54000000-0000-0000-0000-000000000003', 'GLOBAL', NULL, 'Peso muerto', 'peso-muerto',
   'Bisagra de cadera con barra desde el piso.', ARRAY['Preparar la barra cerca del cuerpo.', 'Extender cadera y rodillas.', 'Bajar con control.'], 'WEIGHT_REPS', 'STRENGTH', 'HINGE', '99999999-9999-9999-9999-999999999999'),
  ('54000000-0000-0000-0000-000000000004', 'GLOBAL', NULL, 'Dominadas', 'dominadas',
   'Traccion vertical con peso corporal.', ARRAY['Colgarse de la barra.', 'Elevar el cuerpo hasta superar la barra.', 'Descender con control.'], 'REPS', 'STRENGTH', 'PULL', '99999999-9999-9999-9999-999999999999'),
  ('54000000-0000-0000-0000-000000000005', 'GLOBAL', NULL, 'Plancha', 'plancha',
   'Isometrico de core en posicion prona.', ARRAY['Alinear hombros, cadera y tobillos.', 'Mantener tension abdominal.', 'Sostener el tiempo indicado.'], 'TIME', 'STRENGTH', 'ISOMETRIC', '99999999-9999-9999-9999-999999999999'),
  ('54000000-0000-0000-0000-000000000006', 'GLOBAL', NULL, 'Cinta', 'cinta',
   'Trabajo cardiovascular en cinta.', ARRAY['Configurar velocidad e inclinacion.', 'Mantener tecnica estable.', 'Registrar distancia y tiempo.'], 'DISTANCE_TIME', 'CARDIO', 'CARDIO', '99999999-9999-9999-9999-999999999999'),
  ('55000000-0000-0000-0000-000000000001', 'GYM', '00000000-0000-0000-0000-000000000001', 'Press inclinado Gym Alpha', 'press-inclinado-alpha',
   'Ejercicio privado de Gym Alpha para pruebas de tenant.', NULL, 'WEIGHT_REPS', 'STRENGTH', 'PUSH', '11111111-1111-1111-1111-111111111111'),
  ('55000000-0000-0000-0000-000000000002', 'GYM', '00000000-0000-0000-0000-000000000002', 'Remo Gym Beta', 'remo-beta',
   'Ejercicio privado de Gym Beta para pruebas de tenant.', NULL, 'WEIGHT_REPS', 'STRENGTH', 'PULL', '44444444-4444-4444-4444-444444444444')
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  slug = EXCLUDED.slug,
  description = EXCLUDED.description,
  instructions = EXCLUDED.instructions,
  tracking_type = EXCLUDED.tracking_type,
  category = EXCLUDED.category,
  movement_pattern = EXCLUDED.movement_pattern,
  status = 'ACTIVE',
  deleted_at = NULL;

INSERT INTO public.exercise_muscles (exercise_id, muscle_id, involvement) VALUES
  ('54000000-0000-0000-0000-000000000001', '52000000-0000-0000-0000-000000000001', 'PRIMARY'),
  ('54000000-0000-0000-0000-000000000001', '52000000-0000-0000-0000-000000000003', 'SECONDARY'),
  ('54000000-0000-0000-0000-000000000001', '52000000-0000-0000-0000-000000000002', 'SECONDARY'),
  ('54000000-0000-0000-0000-000000000002', '52000000-0000-0000-0000-000000000006', 'PRIMARY'),
  ('54000000-0000-0000-0000-000000000002', '52000000-0000-0000-0000-000000000008', 'SECONDARY'),
  ('54000000-0000-0000-0000-000000000003', '52000000-0000-0000-0000-000000000007', 'PRIMARY'),
  ('54000000-0000-0000-0000-000000000003', '52000000-0000-0000-0000-000000000008', 'SECONDARY'),
  ('54000000-0000-0000-0000-000000000004', '52000000-0000-0000-0000-000000000005', 'PRIMARY'),
  ('54000000-0000-0000-0000-000000000004', '52000000-0000-0000-0000-000000000004', 'SECONDARY'),
  ('54000000-0000-0000-0000-000000000005', '52000000-0000-0000-0000-000000000010', 'PRIMARY'),
  ('54000000-0000-0000-0000-000000000006', '52000000-0000-0000-0000-000000000011', 'PRIMARY'),
  ('55000000-0000-0000-0000-000000000001', '52000000-0000-0000-0000-000000000001', 'PRIMARY'),
  ('55000000-0000-0000-0000-000000000002', '52000000-0000-0000-0000-000000000005', 'PRIMARY')
ON CONFLICT DO NOTHING;

INSERT INTO public.exercise_equipment (exercise_id, equipment_id) VALUES
  ('54000000-0000-0000-0000-000000000001', '53000000-0000-0000-0000-000000000001'),
  ('54000000-0000-0000-0000-000000000001', '53000000-0000-0000-0000-000000000004'),
  ('54000000-0000-0000-0000-000000000002', '53000000-0000-0000-0000-000000000001'),
  ('54000000-0000-0000-0000-000000000003', '53000000-0000-0000-0000-000000000001'),
  ('54000000-0000-0000-0000-000000000004', '53000000-0000-0000-0000-000000000003'),
  ('54000000-0000-0000-0000-000000000004', '53000000-0000-0000-0000-000000000005'),
  ('54000000-0000-0000-0000-000000000005', '53000000-0000-0000-0000-000000000003'),
  ('54000000-0000-0000-0000-000000000006', '53000000-0000-0000-0000-000000000006'),
  ('55000000-0000-0000-0000-000000000001', '53000000-0000-0000-0000-000000000001'),
  ('55000000-0000-0000-0000-000000000002', '53000000-0000-0000-0000-000000000002')
ON CONFLICT DO NOTHING;
