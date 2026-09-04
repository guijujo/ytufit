-- pgTAP tests for YtuFit v2.0.3-A Training exercise library.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SELECT plan(192);


-- Extra Training-only fixture used to test trainer-member authorization without changing global identity tests.
SET LOCAL ROLE postgres;
RESET "request.jwt.claims";
INSERT INTO auth.users (
  id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES
  ('66666666-6666-6666-6666-666666666666', 'authenticated', 'authenticated', 'member-a2@ytufit.local', crypt('Password123!', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"first_name":"Member","last_name":"Alpha Two"}', now(), now())
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.profiles (id, first_name, last_name, status) VALUES
  ('66666666-6666-6666-6666-666666666666', 'Member', 'Alpha Two', 'ACTIVE')
ON CONFLICT (id) DO UPDATE SET first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name, status = EXCLUDED.status;
INSERT INTO public.gym_members (id, gym_id, user_id, status) VALUES
  ('ffffffff-ffff-ffff-ffff-ffffffff0001', '00000000-0000-0000-0000-000000000001', '66666666-6666-6666-6666-666666666666', 'ACTIVE')
ON CONFLICT (gym_id, user_id) DO NOTHING;
INSERT INTO public.gym_member_roles (gym_member_id, role_id)
SELECT 'ffffffff-ffff-ffff-ffff-ffffffff0001'::uuid, r.id FROM public.roles r WHERE r.name = 'MEMBER'
ON CONFLICT (gym_member_id, role_id) DO NOTHING;
INSERT INTO auth.users (
  id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES
  ('77777777-7777-7777-7777-777777777777', 'authenticated', 'authenticated', 'trainer-b@ytufit.local', crypt('Password123!', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"first_name":"Trainer","last_name":"Beta"}', now(), now())
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.profiles (id, first_name, last_name, status) VALUES
  ('77777777-7777-7777-7777-777777777777', 'Trainer', 'Beta', 'ACTIVE')
ON CONFLICT (id) DO UPDATE SET first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name, status = EXCLUDED.status;
INSERT INTO public.gym_members (id, gym_id, user_id, status) VALUES
  ('ffffffff-ffff-ffff-ffff-ffffffff0002', '00000000-0000-0000-0000-000000000002', '77777777-7777-7777-7777-777777777777', 'ACTIVE')
ON CONFLICT (gym_id, user_id) DO NOTHING;
INSERT INTO public.gym_member_roles (gym_member_id, role_id)
SELECT 'ffffffff-ffff-ffff-ffff-ffffffff0002'::uuid, r.id FROM public.roles r WHERE r.name = 'TRAINER'
ON CONFLICT (gym_member_id, role_id) DO NOTHING;
INSERT INTO public.trainer_member_assignments (id, gym_id, trainer_gym_member_id, member_gym_member_id, created_by, status)
VALUES ('60000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000002', 'ffffffff-ffff-ffff-ffff-ffffffff0002', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', '44444444-4444-4444-4444-444444444444', 'ACTIVE')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.routine_exercises (
  id, gym_id, routine_id, exercise_id, position, tracking_type, sets_target,
  reps_min, reps_max, rest_seconds, notes
) VALUES (
  '62000000-0000-0000-0000-000000000005',
  '00000000-0000-0000-0000-000000000001',
  '61000000-0000-0000-0000-000000000002',
  '54000000-0000-0000-0000-000000000002',
  1,
  'WEIGHT_REPS',
  3,
  8,
  10,
  90,
  'History prescription'
)
ON CONFLICT (id) DO NOTHING;
-- GLOBAL visibility is available to authenticated tenant roles while active.
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated","email":"admin-a@ytufit.local"}';
SELECT results_eq($$ SELECT count(*)::integer FROM public.exercises WHERE scope = 'GLOBAL' AND status = 'ACTIVE' $$, $$ VALUES (6) $$, 'Gym Admin A sees active GLOBAL exercises');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated","email":"trainer-a@ytufit.local"}';
SELECT results_eq($$ SELECT count(*)::integer FROM public.exercises WHERE scope = 'GLOBAL' AND status = 'ACTIVE' $$, $$ VALUES (6) $$, 'Trainer A sees active GLOBAL exercises');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated","email":"member-a@ytufit.local"}';
SELECT results_eq($$ SELECT count(*)::integer FROM public.exercises WHERE scope = 'GLOBAL' AND status = 'ACTIVE' $$, $$ VALUES (6) $$, 'Member A sees active GLOBAL exercises');

SELECT throws_ok($$ SELECT public.update_global_exercise('54000000-0000-0000-0000-000000000001', 'Nope', 'nope', NULL, NULL, 'WEIGHT_REPS', 'STRENGTH', 'PUSH', 'ACTIVE') $$, '42501', NULL, 'Member cannot modify GLOBAL exercises');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated","email":"admin-a@ytufit.local"}';
SELECT throws_ok($$ SELECT public.update_global_exercise('54000000-0000-0000-0000-000000000001', 'Nope', 'nope', NULL, NULL, 'WEIGHT_REPS', 'STRENGTH', 'PUSH', 'ACTIVE') $$, '42501', NULL, 'Gym Admin cannot modify GLOBAL exercises');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated","email":"trainer-a@ytufit.local"}';
SELECT throws_ok($$ SELECT public.update_global_exercise('54000000-0000-0000-0000-000000000001', 'Nope', 'nope', NULL, NULL, 'WEIGHT_REPS', 'STRENGTH', 'PUSH', 'ACTIVE') $$, '42501', NULL, 'Trainer cannot modify GLOBAL exercises');

-- GYM visibility is tenant-local.
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated","email":"member-a@ytufit.local"}';
SELECT results_eq($$ SELECT slug FROM public.exercises WHERE scope = 'GYM' ORDER BY slug $$, $$ VALUES ('press-inclinado-alpha'::text) $$, 'Member A sees Gym A exercise');
SELECT is_empty($$ SELECT * FROM public.exercises WHERE id = '55000000-0000-0000-0000-000000000002' $$, 'Member A cannot see Gym B exercise');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated","email":"admin-a@ytufit.local"}';
SELECT is_empty($$ SELECT * FROM public.exercises WHERE id = '55000000-0000-0000-0000-000000000002' $$, 'Gym Admin A cannot see Gym B exercise');
SELECT throws_ok($$ SELECT public.archive_gym_exercise('55000000-0000-0000-0000-000000000002') $$, '42501', NULL, 'Gym Admin A cannot modify Gym B exercise');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated","email":"member-a@ytufit.local"}';
SELECT throws_ok($$ SELECT public.create_gym_exercise('00000000-0000-0000-0000-000000000001', 'Member exercise', 'member-exercise', NULL, NULL, 'REPS', 'STRENGTH', 'PULL') $$, '42501', NULL, 'Member cannot create GYM exercise');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated","email":"admin-a@ytufit.local"}';
SELECT ok(public.create_gym_exercise('00000000-0000-0000-0000-000000000001', 'Admin row', 'admin-row', NULL, NULL, 'REPS', 'STRENGTH', 'PULL') IS NOT NULL, 'Authorized admin can create GYM exercise');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated","email":"trainer-a@ytufit.local"}';
SELECT ok(public.create_gym_exercise('00000000-0000-0000-0000-000000000001', 'Trainer row', 'trainer-row', NULL, NULL, 'TIME', 'STRENGTH', 'ISOMETRIC') IS NOT NULL, 'Authorized trainer can create GYM exercise');

-- Constraints and relation integrity.
SET LOCAL ROLE postgres;
RESET "request.jwt.claims";
SELECT throws_ok($$ INSERT INTO public.exercises (scope, gym_id, name, slug, tracking_type, category, movement_pattern) VALUES ('GLOBAL', '00000000-0000-0000-0000-000000000001', 'Bad global', 'bad-global', 'REPS', 'STRENGTH', 'PULL') $$, '23514', NULL, 'GLOBAL exercise with gym_id fails');
SELECT throws_ok($$ INSERT INTO public.exercises (scope, gym_id, name, slug, tracking_type, category, movement_pattern) VALUES ('GYM', NULL, 'Bad gym', 'bad-gym', 'REPS', 'STRENGTH', 'PULL') $$, '23514', NULL, 'GYM exercise without gym_id fails');
SELECT throws_ok($$ INSERT INTO public.exercises (scope, gym_id, name, slug, tracking_type, category, movement_pattern) VALUES ('GLOBAL', NULL, 'Duplicate', 'press-de-banca', 'REPS', 'STRENGTH', 'PUSH') $$, '23505', NULL, 'GLOBAL slug is unique');
SELECT throws_ok($$ INSERT INTO public.exercises (scope, gym_id, name, slug, tracking_type, category, movement_pattern) VALUES ('GYM', '00000000-0000-0000-0000-000000000001', 'Duplicate', 'press-inclinado-alpha', 'REPS', 'STRENGTH', 'PUSH') $$, '23505', NULL, 'GYM slug is unique inside the tenant');
SELECT throws_ok($$ INSERT INTO public.exercises (scope, gym_id, name, slug, tracking_type, category, movement_pattern) VALUES ('GLOBAL', NULL, 'Bad slug', 'Bad Slug', 'REPS', 'STRENGTH', 'PUSH') $$, '23514', NULL, 'Exercise slug format is constrained');
SELECT throws_ok($$ INSERT INTO public.exercise_muscles (exercise_id, muscle_id, involvement) VALUES ('54000000-0000-0000-0000-000000000001', 'ffffffff-ffff-ffff-ffff-ffffffffffff', 'PRIMARY') $$, '23503', NULL, 'Invalid exercise muscle relation fails');
SELECT throws_ok($$ INSERT INTO public.exercise_equipment (exercise_id, equipment_id) VALUES ('54000000-0000-0000-0000-000000000001', 'ffffffff-ffff-ffff-ffff-ffffffffffff') $$, '23503', NULL, 'Invalid exercise equipment relation fails');

-- Security posture: anon denied, direct DML denied, EXECUTE revoked from PUBLIC.
SET LOCAL ROLE anon;
RESET "request.jwt.claims";
SELECT is_empty($$ SELECT * FROM public.exercises $$, 'Anon cannot read exercises');
SELECT is_empty($$ SELECT * FROM public.muscles $$, 'Anon cannot read muscles');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated","email":"admin-a@ytufit.local"}';
SELECT throws_ok($$ INSERT INTO public.exercises (scope, gym_id, name, slug, tracking_type, category, movement_pattern) VALUES ('GYM', '00000000-0000-0000-0000-000000000001', 'Direct insert', 'direct-insert', 'REPS', 'STRENGTH', 'PULL') $$, '42501', NULL, 'Direct INSERT is blocked');
SELECT throws_ok($$ UPDATE public.exercises SET name = 'Direct update' WHERE id = '55000000-0000-0000-0000-000000000001' $$, '42501', NULL, 'Direct UPDATE is blocked');
SELECT throws_ok($$ DELETE FROM public.exercises WHERE id = '55000000-0000-0000-0000-000000000001' $$, '42501', NULL, 'Direct DELETE is blocked');
SELECT throws_ok($$ SELECT public.create_gym_exercise('00000000-0000-0000-0000-000000000002', 'Forged', 'forged', NULL, NULL, 'REPS', 'STRENGTH', 'PULL') $$, '42501', NULL, 'RPC does not allow forging a tenant');

SET LOCAL ROLE postgres;
RESET "request.jwt.claims";
SELECT is(has_function_privilege('public', 'public.create_gym_exercise(uuid,text,text,text,text[],public.exercise_tracking_type,public.exercise_category,public.exercise_movement_pattern,text,text)', 'EXECUTE'), false, 'create_gym_exercise EXECUTE is revoked from PUBLIC');
SELECT is(has_function_privilege('public', 'public.update_global_exercise(uuid,text,text,text,text[],public.exercise_tracking_type,public.exercise_category,public.exercise_movement_pattern,public.exercise_status,text,text)', 'EXECUTE'), false, 'update_global_exercise EXECUTE is revoked from PUBLIC');

SELECT is(relrowsecurity, true, 'exercises has RLS enabled') FROM pg_class WHERE oid = 'public.exercises'::regclass;
SELECT is(relforcerowsecurity, true, 'exercises has FORCE RLS') FROM pg_class WHERE oid = 'public.exercises'::regclass;
SELECT is(relrowsecurity, true, 'exercise_muscles has RLS enabled') FROM pg_class WHERE oid = 'public.exercise_muscles'::regclass;
SELECT is(relforcerowsecurity, true, 'exercise_muscles has FORCE RLS') FROM pg_class WHERE oid = 'public.exercise_muscles'::regclass;

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated","email":"member-a@ytufit.local"}';
SELECT is_empty($$ SELECT em.* FROM public.exercise_muscles em WHERE em.exercise_id = '55000000-0000-0000-0000-000000000002' $$, 'Member A cannot read Gym B private exercise muscle relations');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"99999999-9999-9999-9999-999999999999","role":"authenticated","email":"platform-admin@ytufit.local"}';
SELECT public.update_global_exercise('54000000-0000-0000-0000-000000000006', 'Cinta', 'cinta', 'Trabajo cardiovascular en cinta.', ARRAY['Registrar distancia y tiempo.'], 'DISTANCE_TIME', 'CARDIO', 'CARDIO', 'INACTIVE') IS NOT NULL;

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated","email":"member-a@ytufit.local"}';
SELECT is_empty($$ SELECT * FROM public.exercises WHERE id = '54000000-0000-0000-0000-000000000006' $$, 'Members do not read inactive GLOBAL exercises');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated","email":"admin-a@ytufit.local"}';
SELECT ok(public.archive_gym_exercise((SELECT id FROM public.exercises WHERE slug = 'admin-row')) IS NOT NULL, 'Gym Admin can archive own tenant exercise through RPC');
SELECT results_eq($$ SELECT status FROM public.exercises WHERE slug = 'admin-row' $$, $$ VALUES ('INACTIVE'::public.exercise_status) $$, 'Archiving keeps the GYM exercise as inactive history');


-- Relationship commands for muscles and equipment.
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated","email":"admin-a@ytufit.local"}';
SELECT ok(public.set_exercise_muscles('55000000-0000-0000-0000-000000000001', '[{"muscle_id":"52000000-0000-0000-0000-000000000001","involvement":"PRIMARY"},{"muscle_id":"52000000-0000-0000-0000-000000000002","involvement":"SECONDARY"}]'::jsonb) IS NOT NULL, 'Gym Admin configures muscles for own GYM exercise');
SELECT results_eq($$ SELECT muscle_id, involvement FROM public.exercise_muscles WHERE exercise_id = '55000000-0000-0000-0000-000000000001' ORDER BY involvement, muscle_id $$, $$ VALUES ('52000000-0000-0000-0000-000000000001'::uuid, 'PRIMARY'::public.muscle_involvement), ('52000000-0000-0000-0000-000000000002'::uuid, 'SECONDARY'::public.muscle_involvement) $$, 'Gym Admin muscle command replaces exercise muscles');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated","email":"trainer-a@ytufit.local"}';
SELECT ok(public.set_exercise_muscles((SELECT id FROM public.exercises WHERE slug = 'trainer-row'), '[{"muscle_id":"52000000-0000-0000-0000-000000000010","involvement":"PRIMARY"}]'::jsonb) IS NOT NULL, 'Trainer configures muscles for own tenant GYM exercise');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated","email":"member-a@ytufit.local"}';
SELECT throws_ok($$ SELECT public.set_exercise_muscles('55000000-0000-0000-0000-000000000001', '[{"muscle_id":"52000000-0000-0000-0000-000000000001","involvement":"PRIMARY"}]'::jsonb) $$, '42501', NULL, 'Member cannot configure exercise muscles');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated","email":"admin-a@ytufit.local"}';
SELECT throws_ok($$ SELECT public.set_exercise_muscles('55000000-0000-0000-0000-000000000002', '[{"muscle_id":"52000000-0000-0000-0000-000000000005","involvement":"PRIMARY"}]'::jsonb) $$, '42501', NULL, 'Gym A cannot configure muscles for Gym B exercise');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"99999999-9999-9999-9999-999999999999","role":"authenticated","email":"platform-admin@ytufit.local"}';
SELECT ok(public.set_exercise_muscles('54000000-0000-0000-0000-000000000001', '[{"muscle_id":"52000000-0000-0000-0000-000000000001","involvement":"PRIMARY"},{"muscle_id":"52000000-0000-0000-0000-000000000003","involvement":"SECONDARY"}]'::jsonb) IS NOT NULL, 'Platform Admin configures muscles for GLOBAL exercise');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated","email":"admin-a@ytufit.local"}';
SELECT throws_ok($$ SELECT public.set_exercise_muscles('54000000-0000-0000-0000-000000000001', '[{"muscle_id":"52000000-0000-0000-0000-000000000001","involvement":"PRIMARY"}]'::jsonb) $$, '42501', NULL, 'Gym Admin cannot configure muscles for GLOBAL exercise');
SELECT throws_ok($$ SELECT public.set_exercise_muscles('55000000-0000-0000-0000-000000000001', '[{"muscle_id":"52000000-0000-0000-0000-000000000001","involvement":"PRIMARY"},{"muscle_id":"52000000-0000-0000-0000-000000000001","involvement":"SECONDARY"}]'::jsonb) $$, '23505', NULL, 'Same muscle cannot be PRIMARY and SECONDARY for one exercise');
SELECT throws_ok($$ SELECT public.set_exercise_muscles('55000000-0000-0000-0000-000000000001', '[{"muscle_id":"ffffffff-ffff-ffff-ffff-ffffffffffff","involvement":"PRIMARY"}]'::jsonb) $$, '23503', NULL, 'Invalid muscle_id fails in muscle command');

SELECT ok(public.set_exercise_equipment('55000000-0000-0000-0000-000000000001', ARRAY['53000000-0000-0000-0000-000000000001'::uuid, '53000000-0000-0000-0000-000000000004'::uuid]) IS NOT NULL, 'Gym Admin configures equipment for own GYM exercise');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated","email":"member-a@ytufit.local"}';
SELECT throws_ok($$ SELECT public.set_exercise_equipment('55000000-0000-0000-0000-000000000001', ARRAY['53000000-0000-0000-0000-000000000003'::uuid]) $$, '42501', NULL, 'Member cannot configure exercise equipment');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated","email":"admin-a@ytufit.local"}';
SELECT throws_ok($$ SELECT public.set_exercise_equipment('55000000-0000-0000-0000-000000000002', ARRAY['53000000-0000-0000-0000-000000000002'::uuid]) $$, '42501', NULL, 'Gym A cannot configure equipment for Gym B exercise');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"99999999-9999-9999-9999-999999999999","role":"authenticated","email":"platform-admin@ytufit.local"}';
SELECT ok(public.set_exercise_equipment('54000000-0000-0000-0000-000000000001', ARRAY['53000000-0000-0000-0000-000000000001'::uuid, '53000000-0000-0000-0000-000000000004'::uuid]) IS NOT NULL, 'Platform Admin configures equipment for GLOBAL exercise');

SET LOCAL ROLE postgres;
RESET "request.jwt.claims";
SELECT is(has_function_privilege('public', 'public.set_exercise_muscles(uuid,jsonb)', 'EXECUTE'), false, 'set_exercise_muscles EXECUTE is revoked from PUBLIC');
SELECT is(has_function_privilege('public', 'public.set_exercise_equipment(uuid,uuid[])', 'EXECUTE'), false, 'set_exercise_equipment EXECUTE is revoked from PUBLIC');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated","email":"admin-a@ytufit.local"}';
SELECT throws_ok($$ INSERT INTO public.exercise_muscles (exercise_id, muscle_id, involvement) VALUES ('55000000-0000-0000-0000-000000000001', '52000000-0000-0000-0000-000000000003', 'SECONDARY') $$, '42501', NULL, 'Direct DML on exercise_muscles remains blocked');
SELECT throws_ok($$ INSERT INTO public.exercise_equipment (exercise_id, equipment_id) VALUES ('55000000-0000-0000-0000-000000000001', '53000000-0000-0000-0000-000000000003') $$, '42501', NULL, 'Direct DML on exercise_equipment remains blocked');

-- Routines, prescriptions, routine assignments and trainer-member authorization.
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated","email":"admin-a@ytufit.local"}';
SELECT ok(public.create_routine('00000000-0000-0000-0000-000000000001', 'Admin Routine Command', 'Created by admin') IS NOT NULL, 'Admin A creates routine A');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated","email":"trainer-a@ytufit.local"}';
SELECT ok(public.create_routine('00000000-0000-0000-0000-000000000001', 'Trainer Routine Command', 'Created by trainer') IS NOT NULL, 'Trainer A creates routine A');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated","email":"member-a@ytufit.local"}';
SELECT throws_ok($$ SELECT public.create_routine('00000000-0000-0000-0000-000000000001', 'Member Routine Command', NULL) $$, '42501', NULL, 'Member does not create routine');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated","email":"admin-a@ytufit.local"}';
SELECT throws_ok($$ SELECT public.update_routine('61000000-0000-0000-0000-000000000003', 'Nope', NULL, 'ACTIVE') $$, '42501', NULL, 'Admin A does not modify routine B');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated","email":"member-a@ytufit.local"}';
SELECT is_empty($$ SELECT * FROM public.routines WHERE id = '61000000-0000-0000-0000-000000000002' $$, 'Member does not read unassigned routine');
SELECT results_eq($$ SELECT name FROM public.routines WHERE id = '61000000-0000-0000-0000-000000000001' $$, $$ VALUES ('Fuerza Base A'::text) $$, 'Member reads assigned routine');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated","email":"admin-a@ytufit.local"}';
SELECT ok(public.add_routine_exercise((SELECT id FROM public.routines WHERE name = 'Admin Routine Command'), '54000000-0000-0000-0000-000000000001', 1, 4, 6, 8, NULL, NULL, NULL, 120, 'global press') IS NOT NULL, 'GLOBAL exercise can be added to routine A');
SELECT ok(public.add_routine_exercise((SELECT id FROM public.routines WHERE name = 'Admin Routine Command'), '55000000-0000-0000-0000-000000000001', 2, 3, 8, 10, NULL, NULL, NULL, 90, 'gym press') IS NOT NULL, 'GYM exercise A can be added to routine A');
SELECT throws_ok($$ SELECT public.add_routine_exercise((SELECT id FROM public.routines WHERE name = 'Admin Routine Command'), '55000000-0000-0000-0000-000000000002', 3, 3, 8, 10, NULL, NULL, NULL, 90, 'cross') $$, '23503', NULL, 'GYM exercise B cannot be added to routine A');
SELECT throws_ok($$ SELECT public.add_routine_exercise((SELECT id FROM public.routines WHERE name = 'Admin Routine Command'), '54000000-0000-0000-0000-000000000002', 2, 3, 5, 5, NULL, NULL, NULL, 90, 'duplicate') $$, '23505', NULL, 'Duplicate routine exercise position is rejected');
SELECT throws_ok($$ SELECT public.add_routine_exercise((SELECT id FROM public.routines WHERE name = 'Admin Routine Command'), '54000000-0000-0000-0000-000000000002', 3, 3, 10, 5, NULL, NULL, NULL, 90, 'bad reps') $$, '23514', NULL, 'Invalid prescription constraints are rejected');
SELECT ok(public.reorder_routine_exercises((SELECT id FROM public.routines WHERE name = 'Admin Routine Command'), (SELECT jsonb_agg(jsonb_build_object('id', id, 'position', CASE position WHEN 1 THEN 2 ELSE 1 END) ORDER BY id) FROM public.routine_exercises WHERE routine_id = (SELECT id FROM public.routines WHERE name = 'Admin Routine Command'))) IS NOT NULL, 'Reordering routine exercises works');
SELECT results_eq($$ SELECT exercise_id FROM public.routine_exercises WHERE routine_id = (SELECT id FROM public.routines WHERE name = 'Admin Routine Command') ORDER BY position $$, $$ VALUES ('55000000-0000-0000-0000-000000000001'::uuid), ('54000000-0000-0000-0000-000000000001'::uuid) $$, 'Reorder persists explicit positions');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated","email":"member-a@ytufit.local"}';
SELECT throws_ok($$ SELECT public.update_routine_exercise('62000000-0000-0000-0000-000000000001', '54000000-0000-0000-0000-000000000001', 1, 1, 1, 1, NULL, NULL, NULL, 60, 'member') $$, '42501', NULL, 'Member does not modify prescription');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated","email":"admin-a@ytufit.local"}';
SELECT ok(public.assign_routine('61000000-0000-0000-0000-000000000001', 'cccccccc-cccc-cccc-cccc-cccccccccccc', '2026-09-02 00:00:00+00', 'admin assignment') IS NOT NULL, 'Admin assigns routine to Member A');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated","email":"trainer-a@ytufit.local"}';
SELECT ok(public.assign_routine('61000000-0000-0000-0000-000000000001', 'cccccccc-cccc-cccc-cccc-cccccccccccc', '2026-09-03 00:00:00+00', 'trainer assignment') IS NOT NULL, 'Authorized trainer assigns routine to Member A');
SELECT throws_ok($$ SELECT public.assign_routine('61000000-0000-0000-0000-000000000001', 'ffffffff-ffff-ffff-ffff-ffffffff0001', '2026-09-03 00:00:00+00', 'not authorized') $$, '42501', NULL, 'Unauthorized trainer does not assign another member');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated","email":"member-a@ytufit.local"}';
SELECT throws_ok($$ SELECT public.assign_routine('61000000-0000-0000-0000-000000000001', 'cccccccc-cccc-cccc-cccc-cccccccccccc', now(), 'self') $$, '42501', NULL, 'Member does not self-assign routine');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated","email":"admin-a@ytufit.local"}';
SELECT throws_ok($$ SELECT public.assign_routine('61000000-0000-0000-0000-000000000001', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', now(), 'cross member') $$, '23503', NULL, 'Routine A is not assigned to Member B from Gym B');
SELECT throws_ok($$ SELECT public.assign_routine('61000000-0000-0000-0000-000000000003', 'cccccccc-cccc-cccc-cccc-cccccccccccc', now(), 'cross routine') $$, '23503', NULL, 'Routine B is not assigned to Member A by Gym A admin');
SELECT ok(public.complete_routine_assignment('63000000-0000-0000-0000-000000000001', '2026-09-10 00:00:00+00') IS NOT NULL, 'Assignment can be completed through command');
SELECT results_eq($$ SELECT status FROM public.routine_assignments WHERE id = '63000000-0000-0000-0000-000000000001' $$, $$ VALUES ('COMPLETED'::public.routine_assignment_status) $$, 'Completed assignment history remains');
SELECT ok(public.cancel_routine_assignment((SELECT id FROM public.routine_assignments WHERE notes = 'admin assignment'), '2026-09-11 00:00:00+00', 'cancelled by admin') IS NOT NULL, 'Assignment can be cancelled through command');
SELECT results_eq($$ SELECT status FROM public.routine_assignments WHERE notes = 'cancelled by admin' $$, $$ VALUES ('CANCELLED'::public.routine_assignment_status) $$, 'Cancelled assignment history remains');
SELECT ok(public.assign_routine('61000000-0000-0000-0000-000000000001', 'cccccccc-cccc-cccc-cccc-cccccccccccc', '2026-09-04 00:00:00+00', 'second active assignment') IS NOT NULL, 'Second active assignment can be created');
SELECT results_eq($$ SELECT count(*)::integer FROM public.routine_assignments WHERE gym_member_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc' AND status = 'ACTIVE' $$, $$ VALUES (2) $$, 'Multiple ACTIVE assignments are allowed');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"66666666-6666-6666-6666-666666666666","role":"authenticated","email":"member-a2@ytufit.local"}';
SELECT is_empty($$ SELECT * FROM public.routine_assignments $$, 'Member only sees own assignments');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated","email":"member-a@ytufit.local"}';
SELECT results_eq($$ SELECT count(*)::integer FROM public.routine_exercises WHERE routine_id = '61000000-0000-0000-0000-000000000001' $$, $$ VALUES (3) $$, 'Member sees routine exercises for assigned routine');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated","email":"admin-a@ytufit.local"}';
SELECT ok(public.assign_routine('61000000-0000-0000-0000-000000000002', 'cccccccc-cccc-cccc-cccc-cccccccccccc', '2026-09-05 00:00:00+00', 'history completed assignment') IS NOT NULL, 'Admin creates ACTIVE assignment used for member history');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated","email":"member-a@ytufit.local"}';
SELECT results_eq($$ SELECT name FROM public.routines WHERE id = '61000000-0000-0000-0000-000000000002' $$, $$ VALUES ('Tecnica Interna A'::text) $$, 'Member reads routine while assignment is ACTIVE');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated","email":"admin-a@ytufit.local"}';
SELECT ok(public.complete_routine_assignment((SELECT id FROM public.routine_assignments WHERE notes = 'history completed assignment'), '2026-09-12 00:00:00+00') IS NOT NULL, 'Admin completes history assignment');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated","email":"member-a@ytufit.local"}';
SELECT results_eq($$ SELECT name FROM public.routines WHERE id = '61000000-0000-0000-0000-000000000002' $$, $$ VALUES ('Tecnica Interna A'::text) $$, 'Member keeps reading routine after COMPLETED assignment');
SELECT results_eq($$ SELECT count(*)::integer FROM public.routine_exercises WHERE routine_id = '61000000-0000-0000-0000-000000000002' $$, $$ VALUES (1) $$, 'Member keeps reading routine prescription after COMPLETED assignment');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated","email":"admin-a@ytufit.local"}';
SELECT ok(public.assign_routine('61000000-0000-0000-0000-000000000001', 'ffffffff-ffff-ffff-ffff-ffffffff0001', '2026-09-06 00:00:00+00', 'history cancelled assignment') IS NOT NULL, 'Admin creates second assignment for cancellation history');
SELECT ok(public.cancel_routine_assignment((SELECT id FROM public.routine_assignments WHERE notes = 'history cancelled assignment'), '2026-09-13 00:00:00+00', 'history cancellation') IS NOT NULL, 'Admin cancels second history assignment');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"66666666-6666-6666-6666-666666666666","role":"authenticated","email":"member-a2@ytufit.local"}';
SELECT results_eq($$ SELECT name FROM public.routines WHERE id = '61000000-0000-0000-0000-000000000001' $$, $$ VALUES ('Fuerza Base A'::text) $$, 'Member keeps reading routine after CANCELLED assignment');
SELECT results_eq($$ SELECT count(*)::integer FROM public.routine_exercises WHERE routine_id = '61000000-0000-0000-0000-000000000001' $$, $$ VALUES (3) $$, 'Member keeps reading routine prescription after CANCELLED assignment');
SELECT is_empty($$ SELECT * FROM public.routines WHERE name = 'Trainer Routine Command' $$, 'Member does not read a routine that was never assigned');
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated","email":"trainer-a@ytufit.local"}';
SELECT is_empty($$ SELECT * FROM public.routine_assignments WHERE gym_id = '00000000-0000-0000-0000-000000000002' $$, 'Trainer A does not read Gym B assignments');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated","email":"admin-a@ytufit.local"}';
SELECT is_empty($$ SELECT * FROM public.routines WHERE gym_id = '00000000-0000-0000-0000-000000000002' $$, 'Admin A tenant isolation for routines');

SET LOCAL ROLE anon;
RESET "request.jwt.claims";
SELECT is_empty($$ SELECT * FROM public.routines $$, 'Anon cannot read routines');
SELECT is_empty($$ SELECT * FROM public.routine_assignments $$, 'Anon cannot read routine assignments');

SET LOCAL ROLE postgres;
RESET "request.jwt.claims";
SELECT is(relrowsecurity, true, 'routines has RLS enabled') FROM pg_class WHERE oid = 'public.routines'::regclass;
SELECT is(relforcerowsecurity, true, 'routines has FORCE RLS') FROM pg_class WHERE oid = 'public.routines'::regclass;
SELECT is(relrowsecurity, true, 'routine_exercises has RLS enabled') FROM pg_class WHERE oid = 'public.routine_exercises'::regclass;
SELECT is(relforcerowsecurity, true, 'routine_exercises has FORCE RLS') FROM pg_class WHERE oid = 'public.routine_exercises'::regclass;
SELECT is(relrowsecurity, true, 'routine_assignments has RLS enabled') FROM pg_class WHERE oid = 'public.routine_assignments'::regclass;
SELECT is(relforcerowsecurity, true, 'routine_assignments has FORCE RLS') FROM pg_class WHERE oid = 'public.routine_assignments'::regclass;
SELECT is(relrowsecurity, true, 'trainer_member_assignments has RLS enabled') FROM pg_class WHERE oid = 'public.trainer_member_assignments'::regclass;
SELECT is(relforcerowsecurity, true, 'trainer_member_assignments has FORCE RLS') FROM pg_class WHERE oid = 'public.trainer_member_assignments'::regclass;

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated","email":"admin-a@ytufit.local"}';
SELECT throws_ok($$ INSERT INTO public.routines (gym_id, name) VALUES ('00000000-0000-0000-0000-000000000001', 'Direct Routine') $$, '42501', NULL, 'Direct DML on routines is blocked');
SELECT throws_ok($$ INSERT INTO public.routine_exercises (gym_id, routine_id, exercise_id, position, tracking_type) VALUES ('00000000-0000-0000-0000-000000000001', '61000000-0000-0000-0000-000000000001', '54000000-0000-0000-0000-000000000001', 99, 'WEIGHT_REPS') $$, '42501', NULL, 'Direct DML on routine_exercises is blocked');
SELECT throws_ok($$ INSERT INTO public.routine_assignments (gym_id, routine_id, gym_member_id, assigned_by) VALUES ('00000000-0000-0000-0000-000000000001', '61000000-0000-0000-0000-000000000001', 'cccccccc-cccc-cccc-cccc-cccccccccccc', '11111111-1111-1111-1111-111111111111') $$, '42501', NULL, 'Direct DML on routine_assignments is blocked');

SET LOCAL ROLE postgres;
RESET "request.jwt.claims";
SELECT is(has_function_privilege('public', 'public.create_routine(uuid,text,text)', 'EXECUTE'), false, 'create_routine EXECUTE is revoked from PUBLIC');
SELECT is(has_function_privilege('public', 'public.assign_routine(uuid,uuid,timestamp with time zone,text)', 'EXECUTE'), false, 'assign_routine EXECUTE is revoked from PUBLIC');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated","email":"trainer-a@ytufit.local"}';
SELECT throws_ok($$ SELECT public.create_routine('00000000-0000-0000-0000-000000000002', 'Forged tenant routine', NULL) $$, '42501', NULL, 'Forged gym_id routine create is rejected');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated","email":"admin-a@ytufit.local"}';
SELECT ok(public.create_trainer_member_assignment('00000000-0000-0000-0000-000000000001', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'ffffffff-ffff-ffff-ffff-ffffffff0001') IS NOT NULL, 'Gym Admin creates trainer-member assignment');
SELECT throws_ok($$ SELECT public.create_trainer_member_assignment('00000000-0000-0000-0000-000000000001', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee') $$, '23503', NULL, 'Trainer-member assignment enforces same tenant');
SELECT throws_ok($$ SELECT public.create_trainer_member_assignment('00000000-0000-0000-0000-000000000001', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'ffffffff-ffff-ffff-ffff-ffffffff0001') $$, '23514', NULL, 'Trainer-member assignment enforces trainer role');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated","email":"trainer-a@ytufit.local"}';
SELECT ok(public.assign_routine('61000000-0000-0000-0000-000000000001', 'ffffffff-ffff-ffff-ffff-ffffffff0001', now(), 'trainer newly authorized') IS NOT NULL, 'Trainer can assign after trainer-member authorization exists');

SET LOCAL ROLE postgres;
RESET "request.jwt.claims";
INSERT INTO public.exercises (
  id, scope, gym_id, name, slug, description, instructions, tracking_type,
  category, movement_pattern, created_by
) VALUES
  ('55000000-0000-0000-0000-000000000003', 'GYM', '00000000-0000-0000-0000-000000000001', 'Empuje con trineo Alpha', 'empuje-trineo-alpha', 'Carga sostenida por tiempo.', NULL, 'WEIGHT_TIME', 'STRENGTH', 'PUSH', '11111111-1111-1111-1111-111111111111'),
  ('55000000-0000-0000-0000-000000000004', 'GYM', '00000000-0000-0000-0000-000000000001', 'Carry pesado Alpha', 'carry-pesado-alpha', 'Traslado de carga por distancia.', NULL, 'WEIGHT_DISTANCE', 'STRENGTH', 'CARRY', '11111111-1111-1111-1111-111111111111'),
  ('55000000-0000-0000-0000-000000000005', 'GYM', '00000000-0000-0000-0000-000000000001', 'Remo ergometro Alpha', 'remo-ergometro-alpha', 'Distancia con duracion medida.', NULL, 'DISTANCE_TIME', 'CARDIO', 'CARDIO', '11111111-1111-1111-1111-111111111111')
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
INSERT INTO public.routines (id, gym_id, name, description, status, created_by)
VALUES ('61000000-0000-0000-0000-000000000010', '00000000-0000-0000-0000-000000000001', 'Workout Matrix A', 'Rutina con todos los tracking types para tests de workout.', 'ACTIVE', '11111111-1111-1111-1111-111111111111')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description, status = EXCLUDED.status;
INSERT INTO public.routine_exercises (
  id, gym_id, routine_id, exercise_id, position, tracking_type, sets_target,
  reps_min, reps_max, weight_target, duration_seconds_target, distance_meters_target,
  rest_seconds, notes
) VALUES
  ('62000000-0000-0000-0000-000000000010', '00000000-0000-0000-0000-000000000001', '61000000-0000-0000-0000-000000000010', '55000000-0000-0000-0000-000000000001', 1, 'WEIGHT_REPS', 2, 8, 10, 60, NULL, NULL, 90, 'Matrix weight reps'),
  ('62000000-0000-0000-0000-000000000011', '00000000-0000-0000-0000-000000000001', '61000000-0000-0000-0000-000000000010', '54000000-0000-0000-0000-000000000004', 2, 'REPS', 1, 5, 5, NULL, NULL, NULL, 75, 'Matrix reps'),
  ('62000000-0000-0000-0000-000000000012', '00000000-0000-0000-0000-000000000001', '61000000-0000-0000-0000-000000000010', '54000000-0000-0000-0000-000000000005', 3, 'TIME', 1, NULL, NULL, NULL, 45, NULL, 60, 'Matrix time'),
  ('62000000-0000-0000-0000-000000000013', '00000000-0000-0000-0000-000000000001', '61000000-0000-0000-0000-000000000010', '55000000-0000-0000-0000-000000000005', 4, 'DISTANCE_TIME', 1, NULL, NULL, NULL, 600, 1000, 120, 'Matrix distance time'),
  ('62000000-0000-0000-0000-000000000014', '00000000-0000-0000-0000-000000000001', '61000000-0000-0000-0000-000000000010', '55000000-0000-0000-0000-000000000003', 5, 'WEIGHT_TIME', 1, NULL, NULL, 20, 30, NULL, 45, 'Matrix weight time'),
  ('62000000-0000-0000-0000-000000000015', '00000000-0000-0000-0000-000000000001', '61000000-0000-0000-0000-000000000010', '55000000-0000-0000-0000-000000000004', 6, 'WEIGHT_DISTANCE', 1, NULL, NULL, 30, NULL, 40, 45, 'Matrix weight distance')
ON CONFLICT (id) DO UPDATE SET
  exercise_id = EXCLUDED.exercise_id,
  position = EXCLUDED.position,
  tracking_type = EXCLUDED.tracking_type,
  sets_target = EXCLUDED.sets_target,
  reps_min = EXCLUDED.reps_min,
  reps_max = EXCLUDED.reps_max,
  weight_target = EXCLUDED.weight_target,
  duration_seconds_target = EXCLUDED.duration_seconds_target,
  distance_meters_target = EXCLUDED.distance_meters_target,
  rest_seconds = EXCLUDED.rest_seconds,
  notes = EXCLUDED.notes;
INSERT INTO public.routine_assignments (
  id, gym_id, routine_id, gym_member_id, assigned_by, starts_at, status, notes
) VALUES
  ('63000000-0000-0000-0000-000000000010', '00000000-0000-0000-0000-000000000001', '61000000-0000-0000-0000-000000000010', 'cccccccc-cccc-cccc-cccc-cccccccccccc', '11111111-1111-1111-1111-111111111111', '2026-09-01 00:00:00+00', 'ACTIVE', 'workout matrix member a'),
  ('63000000-0000-0000-0000-000000000011', '00000000-0000-0000-0000-000000000001', '61000000-0000-0000-0000-000000000010', 'ffffffff-ffff-ffff-ffff-ffffffff0001', '11111111-1111-1111-1111-111111111111', '2026-09-01 00:00:00+00', 'ACTIVE', 'workout cancellation member a2')
ON CONFLICT (id) DO UPDATE SET status = EXCLUDED.status, ends_at = NULL, notes = EXCLUDED.notes;

-- Workout sessions, historical snapshots and workout sets.
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated","email":"member-a@ytufit.local"}';
SELECT ok(public.start_workout('63000000-0000-0000-0000-000000000010') IS NOT NULL, 'Member starts workout from own ACTIVE assignment');

SET LOCAL ROLE postgres;
RESET "request.jwt.claims";
DO $$
BEGIN
  PERFORM set_config(
    'ytufit_test.main_we_1',
    (
      SELECT id::text
      FROM public.workout_exercises
      WHERE workout_session_id = (
        SELECT id FROM public.workout_sessions
        WHERE routine_assignment_id = '63000000-0000-0000-0000-000000000010'
      )
      AND position = 1
    ),
    true
  );
END $$;

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated","email":"member-a@ytufit.local"}';
SELECT throws_ok($$ SELECT public.start_workout('63000000-0000-0000-0000-000000000002') $$, '42501', NULL, 'Member cannot start another member assignment');
SELECT throws_ok($$ SELECT public.start_workout('63000000-0000-0000-0000-000000000001') $$, '55000', NULL, 'Member cannot start COMPLETED routine assignment');
SELECT throws_ok($$ SELECT public.start_workout((SELECT id FROM public.routine_assignments WHERE notes = 'cancelled by admin')) $$, '55000', NULL, 'Member cannot start CANCELLED routine assignment');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"55555555-5555-5555-5555-555555555555","role":"authenticated","email":"member-b@ytufit.local"}';
SELECT throws_ok($$ SELECT public.start_workout('63000000-0000-0000-0000-000000000010') $$, '42501', NULL, 'Member B cannot start Gym A assignment');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated","email":"member-a@ytufit.local"}';
SELECT throws_ok($$ SELECT public.start_workout('63000000-0000-0000-0000-000000000010') $$, '23505', NULL, 'Member cannot create a second IN_PROGRESS workout');

SET LOCAL ROLE anon;
RESET "request.jwt.claims";
SELECT throws_ok($$ SELECT public.start_workout('63000000-0000-0000-0000-000000000010') $$, '42501', NULL, 'Anon cannot start workout');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated","email":"admin-a@ytufit.local"}';
SELECT throws_ok($$ SELECT public.start_workout('63000000-0000-0000-0000-000000000010') $$, '42501', NULL, 'RPC cannot forge workout owner through assignment id');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated","email":"member-a@ytufit.local"}';
SELECT results_eq($$ SELECT position, exercise_name FROM public.workout_exercises WHERE workout_session_id = (SELECT id FROM public.workout_sessions WHERE routine_assignment_id = '63000000-0000-0000-0000-000000000010') ORDER BY position $$, $$ VALUES (1, 'Press inclinado Gym Alpha'::text), (2, 'Dominadas'::text), (3, 'Plancha'::text), (4, 'Remo ergometro Alpha'::text), (5, 'Empuje con trineo Alpha'::text), (6, 'Carry pesado Alpha'::text) $$, 'Workout exercises are snapshotted in routine order');
SELECT results_eq($$ SELECT exercise_name FROM public.workout_exercises WHERE workout_session_id = (SELECT id FROM public.workout_sessions WHERE routine_assignment_id = '63000000-0000-0000-0000-000000000010') AND position = 1 $$, $$ VALUES ('Press inclinado Gym Alpha'::text) $$, 'Workout exercise stores exercise name snapshot');
SELECT results_eq($$ SELECT tracking_type FROM public.workout_exercises WHERE workout_session_id = (SELECT id FROM public.workout_sessions WHERE routine_assignment_id = '63000000-0000-0000-0000-000000000010') AND position = 1 $$, $$ VALUES ('WEIGHT_REPS'::public.exercise_tracking_type) $$, 'Workout exercise stores tracking type snapshot');
SELECT results_eq($$ SELECT sets_target, reps_min, reps_max, weight_target, rest_seconds FROM public.workout_exercises WHERE workout_session_id = (SELECT id FROM public.workout_sessions WHERE routine_assignment_id = '63000000-0000-0000-0000-000000000010') AND position = 1 $$, $$ VALUES (2, 8, 10, 60.00::numeric, 90) $$, 'Workout exercise stores prescription snapshot');
SELECT results_eq($$ SELECT count(*)::integer FROM public.workout_sets ws JOIN public.workout_exercises we ON we.id = ws.workout_exercise_id WHERE we.workout_session_id = (SELECT id FROM public.workout_sessions WHERE routine_assignment_id = '63000000-0000-0000-0000-000000000010') AND ws.status = 'PLANNED' $$, $$ VALUES (7) $$, 'start_workout creates planned sets from sets_target');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated","email":"admin-a@ytufit.local"}';
SELECT ok(public.update_routine_exercise('62000000-0000-0000-0000-000000000010', '55000000-0000-0000-0000-000000000001', 1, 2, 1, 2, 66, NULL, NULL, 30, 'mutated original') IS NOT NULL, 'Gym Admin can mutate original routine prescription after workout start');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated","email":"member-a@ytufit.local"}';
SELECT results_eq($$ SELECT reps_min, reps_max, weight_target, rest_seconds, notes FROM public.workout_exercises WHERE workout_session_id = (SELECT id FROM public.workout_sessions WHERE routine_assignment_id = '63000000-0000-0000-0000-000000000010') AND position = 1 $$, $$ VALUES (8, 10, 60.00::numeric, 90, 'Matrix weight reps'::text) $$, 'Routine prescription edits do not leak into workout snapshot');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated","email":"admin-a@ytufit.local"}';
SELECT ok(public.update_gym_exercise('55000000-0000-0000-0000-000000000001', 'Press inclinado editado', 'press-inclinado-editado', NULL, NULL, 'WEIGHT_REPS', 'STRENGTH', 'PUSH', 'ACTIVE') IS NOT NULL, 'Gym Admin can mutate source exercise after workout start');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated","email":"member-a@ytufit.local"}';
SELECT results_eq($$ SELECT exercise_name FROM public.workout_exercises WHERE workout_session_id = (SELECT id FROM public.workout_sessions WHERE routine_assignment_id = '63000000-0000-0000-0000-000000000010') AND position = 1 $$, $$ VALUES ('Press inclinado Gym Alpha'::text) $$, 'Exercise edits do not change workout exercise name snapshot');
SELECT ok(public.record_workout_set((SELECT id FROM public.workout_exercises WHERE workout_session_id = (SELECT id FROM public.workout_sessions WHERE routine_assignment_id = '63000000-0000-0000-0000-000000000010') AND position = 1), 1, 'COMPLETED', 9, 62.5, NULL, NULL, 'solid') IS NOT NULL, 'Member records WEIGHT_REPS set');
SELECT results_eq($$ SELECT reps, weight, status FROM public.workout_sets WHERE workout_exercise_id = (SELECT id FROM public.workout_exercises WHERE workout_session_id = (SELECT id FROM public.workout_sessions WHERE routine_assignment_id = '63000000-0000-0000-0000-000000000010') AND position = 1) AND set_number = 1 $$, $$ VALUES (9, 62.50::numeric, 'COMPLETED'::public.workout_set_status) $$, 'Recorded WEIGHT_REPS metrics persist');
SELECT ok(public.record_workout_set((SELECT id FROM public.workout_exercises WHERE workout_session_id = (SELECT id FROM public.workout_sessions WHERE routine_assignment_id = '63000000-0000-0000-0000-000000000010') AND position = 2), 1, 'COMPLETED', 5, NULL, NULL, NULL, NULL) IS NOT NULL, 'Member records REPS set');
SELECT ok(public.record_workout_set((SELECT id FROM public.workout_exercises WHERE workout_session_id = (SELECT id FROM public.workout_sessions WHERE routine_assignment_id = '63000000-0000-0000-0000-000000000010') AND position = 3), 1, 'COMPLETED', NULL, NULL, 50, NULL, NULL) IS NOT NULL, 'Member records TIME set');
SELECT ok(public.record_workout_set((SELECT id FROM public.workout_exercises WHERE workout_session_id = (SELECT id FROM public.workout_sessions WHERE routine_assignment_id = '63000000-0000-0000-0000-000000000010') AND position = 4), 1, 'COMPLETED', NULL, NULL, 620, 1100, NULL) IS NOT NULL, 'Member records DISTANCE_TIME set');
SELECT ok(public.record_workout_set((SELECT id FROM public.workout_exercises WHERE workout_session_id = (SELECT id FROM public.workout_sessions WHERE routine_assignment_id = '63000000-0000-0000-0000-000000000010') AND position = 5), 1, 'COMPLETED', NULL, 22, 35, NULL, NULL) IS NOT NULL, 'Member records WEIGHT_TIME set');
SELECT ok(public.record_workout_set((SELECT id FROM public.workout_exercises WHERE workout_session_id = (SELECT id FROM public.workout_sessions WHERE routine_assignment_id = '63000000-0000-0000-0000-000000000010') AND position = 6), 1, 'COMPLETED', NULL, 32, NULL, 45, NULL) IS NOT NULL, 'Member records WEIGHT_DISTANCE set');
SELECT throws_ok($$ SELECT public.record_workout_set((SELECT id FROM public.workout_exercises WHERE workout_session_id = (SELECT id FROM public.workout_sessions WHERE routine_assignment_id = '63000000-0000-0000-0000-000000000010') AND position = 2), 2, 'COMPLETED', -1, NULL, NULL, NULL, NULL) $$, '23514', NULL, 'Negative workout set metrics are rejected');
SELECT throws_ok($$ SELECT public.record_workout_set((SELECT id FROM public.workout_exercises WHERE workout_session_id = (SELECT id FROM public.workout_sessions WHERE routine_assignment_id = '63000000-0000-0000-0000-000000000010') AND position = 2), 2, 'COMPLETED', 6, 10, NULL, NULL, NULL) $$, '22023', NULL, 'Incompatible tracking payload is rejected');
SELECT ok(public.record_workout_set((SELECT id FROM public.workout_exercises WHERE workout_session_id = (SELECT id FROM public.workout_sessions WHERE routine_assignment_id = '63000000-0000-0000-0000-000000000010') AND position = 1), 2, 'SKIPPED', NULL, NULL, NULL, NULL, 'fatigue') IS NOT NULL, 'SKIPPED set is valid without metrics');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"66666666-6666-6666-6666-666666666666","role":"authenticated","email":"member-a2@ytufit.local"}';
SELECT throws_ok($$ SELECT public.record_workout_set(current_setting('ytufit_test.main_we_1')::uuid, 1, 'COMPLETED', 8, 60, NULL, NULL, NULL) $$, '42501', NULL, 'Other Member cannot record workout set');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated","email":"trainer-a@ytufit.local"}';
SELECT throws_ok($$ SELECT public.record_workout_set(current_setting('ytufit_test.main_we_1')::uuid, 1, 'COMPLETED', 8, 60, NULL, NULL, NULL) $$, '42501', NULL, 'Trainer cannot record member performance');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated","email":"admin-a@ytufit.local"}';
SELECT throws_ok($$ SELECT public.record_workout_set(current_setting('ytufit_test.main_we_1')::uuid, 1, 'COMPLETED', 8, 60, NULL, NULL, NULL) $$, '42501', NULL, 'Gym Admin cannot record member performance');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated","email":"member-a@ytufit.local"}';
SELECT ok(public.complete_workout((SELECT id FROM public.workout_sessions WHERE routine_assignment_id = '63000000-0000-0000-0000-000000000010')) IS NOT NULL, 'Workout owner completes IN_PROGRESS workout');
SELECT isnt((SELECT completed_at FROM public.workout_sessions WHERE routine_assignment_id = '63000000-0000-0000-0000-000000000010'), NULL::timestamptz, 'Completed workout sets completed_at server-side');
SELECT throws_ok($$ SELECT public.complete_workout((SELECT id FROM public.workout_sessions WHERE routine_assignment_id = '63000000-0000-0000-0000-000000000010')) $$, '55000', NULL, 'Workout cannot be completed twice');
SELECT throws_ok($$ SELECT public.record_workout_set((SELECT id FROM public.workout_exercises WHERE workout_session_id = (SELECT id FROM public.workout_sessions WHERE routine_assignment_id = '63000000-0000-0000-0000-000000000010') AND position = 1), 1, 'COMPLETED', 10, 65, NULL, NULL, NULL) $$, '55000', NULL, 'Completed workout performance is immutable');
SELECT throws_ok($$ SELECT public.cancel_workout((SELECT id FROM public.workout_sessions WHERE routine_assignment_id = '63000000-0000-0000-0000-000000000010'), 'late cancel') $$, '55000', NULL, 'Completed workout cannot be cancelled');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"66666666-6666-6666-6666-666666666666","role":"authenticated","email":"member-a2@ytufit.local"}';
SELECT ok(public.start_workout('63000000-0000-0000-0000-000000000011') IS NOT NULL, 'Member starts second workout for cancellation flow');
SELECT ok(public.cancel_workout((SELECT id FROM public.workout_sessions WHERE routine_assignment_id = '63000000-0000-0000-0000-000000000011'), 'not feeling well') IS NOT NULL, 'Workout owner cancels IN_PROGRESS workout');
SELECT results_eq($$ SELECT cancellation_reason FROM public.workout_sessions WHERE routine_assignment_id = '63000000-0000-0000-0000-000000000011' $$, $$ VALUES ('not feeling well'::text) $$, 'Workout cancellation reason is preserved');
SELECT isnt((SELECT cancelled_at FROM public.workout_sessions WHERE routine_assignment_id = '63000000-0000-0000-0000-000000000011'), NULL::timestamptz, 'Cancelled workout sets cancelled_at server-side');
SELECT throws_ok($$ SELECT public.complete_workout((SELECT id FROM public.workout_sessions WHERE routine_assignment_id = '63000000-0000-0000-0000-000000000011')) $$, '55000', NULL, 'Cancelled workout cannot be completed');
SELECT throws_ok($$ SELECT public.record_workout_set((SELECT id FROM public.workout_exercises WHERE workout_session_id = (SELECT id FROM public.workout_sessions WHERE routine_assignment_id = '63000000-0000-0000-0000-000000000011') AND position = 1), 1, 'COMPLETED', 8, 60, NULL, NULL, NULL) $$, '55000', NULL, 'Cancelled workout cannot record further sets');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated","email":"member-a@ytufit.local"}';
SELECT results_eq($$ SELECT status FROM public.workout_sessions WHERE routine_assignment_id = '63000000-0000-0000-0000-000000000010' $$, $$ VALUES ('COMPLETED'::public.workout_status) $$, 'Member reads own workout history');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"66666666-6666-6666-6666-666666666666","role":"authenticated","email":"member-a2@ytufit.local"}';
SELECT is_empty($$ SELECT * FROM public.workout_sessions WHERE routine_assignment_id = '63000000-0000-0000-0000-000000000010' $$, 'Member cannot read another member workout');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated","email":"trainer-a@ytufit.local"}';
SELECT results_eq($$ SELECT status FROM public.workout_sessions WHERE routine_assignment_id = '63000000-0000-0000-0000-000000000010' $$, $$ VALUES ('COMPLETED'::public.workout_status) $$, 'Authorized trainer reads member workout history');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"77777777-7777-7777-7777-777777777777","role":"authenticated","email":"trainer-b@ytufit.local"}';
SELECT is_empty($$ SELECT * FROM public.workout_sessions WHERE routine_assignment_id = '63000000-0000-0000-0000-000000000010' $$, 'Unauthorized trainer cannot read workout history');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated","email":"admin-a@ytufit.local"}';
SELECT results_eq($$ SELECT count(*)::integer FROM public.workout_sessions WHERE gym_id = '00000000-0000-0000-0000-000000000001' $$, $$ VALUES (2) $$, 'Gym Admin reads same-tenant workouts');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"44444444-4444-4444-4444-444444444444","role":"authenticated","email":"admin-b@ytufit.local"}';
SELECT is_empty($$ SELECT * FROM public.workout_sessions WHERE gym_id = '00000000-0000-0000-0000-000000000001' $$, 'Gym Admin cannot read cross-tenant workouts');

SET LOCAL ROLE anon;
RESET "request.jwt.claims";
SELECT is_empty($$ SELECT * FROM public.workout_sessions $$, 'Anon cannot read workout sessions');
SELECT is_empty($$ SELECT * FROM public.workout_exercises $$, 'Anon cannot read workout exercises');
SELECT is_empty($$ SELECT * FROM public.workout_sets $$, 'Anon cannot read workout sets');

SET LOCAL ROLE postgres;
RESET "request.jwt.claims";
SELECT is(relrowsecurity, true, 'workout_sessions has RLS enabled') FROM pg_class WHERE oid = 'public.workout_sessions'::regclass;
SELECT is(relforcerowsecurity, true, 'workout_sessions has FORCE RLS') FROM pg_class WHERE oid = 'public.workout_sessions'::regclass;
SELECT is(relrowsecurity, true, 'workout_exercises has RLS enabled') FROM pg_class WHERE oid = 'public.workout_exercises'::regclass;
SELECT is(relforcerowsecurity, true, 'workout_exercises has FORCE RLS') FROM pg_class WHERE oid = 'public.workout_exercises'::regclass;
SELECT is(relrowsecurity, true, 'workout_sets has RLS enabled') FROM pg_class WHERE oid = 'public.workout_sets'::regclass;
SELECT is(relforcerowsecurity, true, 'workout_sets has FORCE RLS') FROM pg_class WHERE oid = 'public.workout_sets'::regclass;
SELECT is(has_function_privilege('public', 'public.start_workout(uuid)', 'EXECUTE'), false, 'start_workout EXECUTE is revoked from PUBLIC');
SELECT is(has_function_privilege('public', 'public.record_workout_set(uuid,integer,public.workout_set_status,integer,numeric,integer,numeric,text)', 'EXECUTE'), false, 'record_workout_set EXECUTE is revoked from PUBLIC');
SELECT is(has_function_privilege('public', 'public.complete_workout(uuid)', 'EXECUTE'), false, 'complete_workout EXECUTE is revoked from PUBLIC');
SELECT is(has_function_privilege('public', 'public.cancel_workout(uuid,text)', 'EXECUTE'), false, 'cancel_workout EXECUTE is revoked from PUBLIC');
SELECT is(has_function_privilege('public', 'public."startWorkout"(uuid)', 'EXECUTE'), false, 'startWorkout EXECUTE is revoked from PUBLIC');
SELECT is(has_function_privilege('public', 'public."recordWorkoutSet"(uuid,integer,public.workout_set_status,integer,numeric,integer,numeric,text)', 'EXECUTE'), false, 'recordWorkoutSet EXECUTE is revoked from PUBLIC');
SELECT is(has_function_privilege('public', 'public."completeWorkout"(uuid)', 'EXECUTE'), false, 'completeWorkout EXECUTE is revoked from PUBLIC');
SELECT is(has_function_privilege('public', 'public."cancelWorkout"(uuid,text)', 'EXECUTE'), false, 'cancelWorkout EXECUTE is revoked from PUBLIC');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated","email":"admin-a@ytufit.local"}';
SELECT throws_ok($$ INSERT INTO public.workout_sessions (gym_id, gym_member_id, routine_assignment_id, routine_id) VALUES ('00000000-0000-0000-0000-000000000001', 'cccccccc-cccc-cccc-cccc-cccccccccccc', '63000000-0000-0000-0000-000000000010', '61000000-0000-0000-0000-000000000010') $$, '42501', NULL, 'Direct DML on workout_sessions is blocked');
SELECT throws_ok($$ UPDATE public.workout_exercises SET exercise_name = 'forged' WHERE id = (SELECT id FROM public.workout_exercises LIMIT 1) $$, '42501', NULL, 'Direct DML on workout_exercises is blocked');
SELECT throws_ok($$ INSERT INTO public.workout_sets (gym_id, workout_exercise_id, set_number) VALUES ('00000000-0000-0000-0000-000000000001', (SELECT id FROM public.workout_exercises LIMIT 1), 99) $$, '42501', NULL, 'Direct DML on workout_sets is blocked');
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated","email":"member-a@ytufit.local"}';
SELECT results_eq($$ SELECT trainer_gym_member_id FROM public.trainer_member_assignments WHERE member_gym_member_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc' $$, $$ VALUES ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'::uuid) $$, 'Member can read their trainer-member assignment');
SELECT throws_ok($$ SELECT public.deactivate_trainer_member_assignment('60000000-0000-0000-0000-000000000001') $$, '42501', NULL, 'Member cannot deactivate trainer-member assignment');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated","email":"trainer-a@ytufit.local"}';
SELECT throws_ok($$ SELECT public.deactivate_trainer_member_assignment('60000000-0000-0000-0000-000000000001') $$, '42501', NULL, 'Trainer cannot deactivate trainer-member assignment');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated","email":"admin-a@ytufit.local"}';
SELECT throws_ok($$ SELECT public.deactivate_trainer_member_assignment('60000000-0000-0000-0000-000000000002') $$, '42501', NULL, 'Gym A admin cannot deactivate Gym B trainer-member assignment');
SELECT ok(public.deactivate_trainer_member_assignment('60000000-0000-0000-0000-000000000001') IS NOT NULL, 'Gym Admin deactivates Trainer A to Member A assignment');
SELECT results_eq($$ SELECT status FROM public.trainer_member_assignments WHERE id = '60000000-0000-0000-0000-000000000001' $$, $$ VALUES ('INACTIVE'::public.trainer_member_assignment_status) $$, 'Trainer-member assignment status becomes INACTIVE');
SELECT isnt((SELECT ended_at FROM public.trainer_member_assignments WHERE id = '60000000-0000-0000-0000-000000000001'), NULL::timestamptz, 'Trainer-member assignment ended_at is set');
SELECT results_eq($$ SELECT count(*)::integer FROM public.trainer_member_assignments WHERE id = '60000000-0000-0000-0000-000000000001' $$, $$ VALUES (1) $$, 'Trainer-member assignment row remains after deactivation');
SELECT throws_ok($$ SELECT public.deactivate_trainer_member_assignment('60000000-0000-0000-0000-000000000001') $$, '55000', NULL, 'Second trainer-member deactivation is explicitly rejected');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated","email":"trainer-a@ytufit.local"}';
SELECT throws_ok($$ SELECT public.assign_routine('61000000-0000-0000-0000-000000000001', 'cccccccc-cccc-cccc-cccc-cccccccccccc', now(), 'after trainer-member deactivation') $$, '42501', NULL, 'Trainer loses routine assignment authorization after deactivation');

SET LOCAL ROLE postgres;
RESET "request.jwt.claims";
SELECT is(has_function_privilege('public', 'public.deactivate_trainer_member_assignment(uuid)', 'EXECUTE'), false, 'deactivate_trainer_member_assignment EXECUTE is revoked from PUBLIC');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated","email":"admin-a@ytufit.local"}';
SELECT throws_ok($$ UPDATE public.trainer_member_assignments SET status = 'INACTIVE' WHERE id = '60000000-0000-0000-0000-000000000002' $$, '42501', NULL, 'Direct UPDATE on trainer_member_assignments remains blocked');
SELECT * FROM finish();
ROLLBACK;





