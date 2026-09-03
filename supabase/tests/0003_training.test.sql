-- pgTAP tests for YtuFit v2.0.3-A Training exercise library.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SELECT plan(53);

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
SELECT * FROM finish();
ROLLBACK;


