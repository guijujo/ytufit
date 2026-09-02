-- pgTAP tests for YtuFit v2.0.2 membership and attendance boundaries.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SELECT plan(41);

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated","email":"admin-a@ytufit.local"}';
SELECT results_eq($$ SELECT name FROM public.membership_plans WHERE gym_id = '00000000-0000-0000-0000-000000000001' ORDER BY name $$, $$ VALUES ('Doce por mes'::text), ('Pase Libre'::text), ('Tres por semana'::text) $$, 'Admin A can read Gym A plans');
SELECT is_empty($$ SELECT * FROM public.membership_plans WHERE gym_id = '00000000-0000-0000-0000-000000000002' $$, 'Admin A cannot read Gym B plans');
SELECT results_eq($$ SELECT count(*)::integer FROM public.memberships WHERE gym_id = '00000000-0000-0000-0000-000000000001' $$, $$ VALUES (1) $$, 'Admin A can read Gym A memberships');
SELECT is_empty($$ SELECT * FROM public.memberships WHERE gym_id = '00000000-0000-0000-0000-000000000002' $$, 'Admin A cannot read Gym B memberships');
SELECT results_eq($$ SELECT count(*)::integer FROM public.attendances WHERE gym_id = '00000000-0000-0000-0000-000000000001' $$, $$ VALUES (2) $$, 'Admin A can read Gym A attendance');
SELECT is_empty($$ SELECT * FROM public.attendances WHERE gym_id = '00000000-0000-0000-0000-000000000002' $$, 'Admin A cannot read Gym B attendance');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated","email":"member-a@ytufit.local"}';
SELECT results_eq($$ SELECT membership_plan_id FROM public.memberships WHERE gym_member_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc' $$, $$ VALUES ('10000000-0000-0000-0000-000000000001'::uuid) $$, 'Member A can read own membership');
SELECT is_empty($$ SELECT * FROM public.memberships WHERE gym_member_id = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee' $$, 'Member A cannot read Member B membership');
SELECT results_eq($$ SELECT count(*)::integer FROM public.attendances WHERE gym_member_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc' $$, $$ VALUES (2) $$, 'Member A can read own attendance history');
SELECT is_empty($$ SELECT * FROM public.attendances WHERE gym_member_id = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee' $$, 'Member A cannot read Member B attendance');
SELECT throws_ok($$ UPDATE public.memberships SET contracted_price = 1 WHERE id = '30000000-0000-0000-0000-000000000001' $$, '42501', NULL, 'Member cannot modify membership snapshots');
SELECT throws_ok($$ UPDATE public.attendances SET attendance_date = attendance_date + 1 WHERE id = '40000000-0000-0000-0000-000000000001' $$, '42501', NULL, 'Member cannot modify attendance date');
SELECT throws_ok($$ UPDATE public.attendances SET status = 'CANCELLED' WHERE id = '40000000-0000-0000-0000-000000000001' $$, '42501', NULL, 'Member cannot cancel attendance directly');
SELECT throws_ok($$ UPDATE public.membership_plans SET price = 1 WHERE id = '10000000-0000-0000-0000-000000000001' $$, '42501', NULL, 'Member cannot modify plan price');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated","email":"trainer-a@ytufit.local"}';
SELECT throws_ok($$ SELECT public.create_membership_plan('00000000-0000-0000-0000-000000000001', 'Trainer plan', NULL, 'UNLIMITED', NULL, NULL, NULL, 1, 'ARS', 30) $$, '42501', NULL, 'Trainer cannot manage plans');
SELECT throws_ok($$ SELECT public.register_attendance('cccccccc-cccc-cccc-cccc-cccccccccccc', now(), 'QR', '30000000-0000-0000-0000-000000000001', 'trainer') $$, '42501', NULL, 'Trainer has no attendance administration privilege');
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}';
SELECT throws_ok($$ SELECT public.register_attendance('cccccccc-cccc-cccc-cccc-cccccccccccc', now(), 'MANUAL', NULL, 'member') $$, '42501', NULL, 'Member cannot self-register manual attendance');
SELECT throws_ok($$ SELECT public.register_attendance('cccccccc-cccc-cccc-cccc-cccccccccccc', now(), 'QR', NULL, 'member') $$, '42501', NULL, 'Member cannot forge QR attendance');
SELECT throws_ok($$ SELECT public.register_attendance('cccccccc-cccc-cccc-cccc-cccccccccccc', now(), 'WORKOUT_STARTED', NULL, 'member') $$, '42501', NULL, 'Member cannot forge workout-start attendance');
SELECT throws_ok($$ SELECT public.register_attendance('cccccccc-cccc-cccc-cccc-cccccccccccc', now(), 'WORKOUT_COMPLETED', NULL, 'member') $$, '42501', NULL, 'Member cannot forge workout-completion attendance');
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';
SELECT throws_ok($$ SELECT public.register_attendance('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', now(), 'MANUAL', NULL, 'cross-tenant') $$, '42501', NULL, 'Gym A admin cannot register attendance for Gym B');

SET LOCAL ROLE postgres;
RESET "request.jwt.claims";
SELECT throws_ok($$ INSERT INTO public.memberships (gym_id, gym_member_id, membership_plan_id, starts_at, ends_at, contracted_price, currency, access_type_snapshot) VALUES ('00000000-0000-0000-0000-000000000001', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', '10000000-0000-0000-0000-000000000001', now(), now() + interval '30 days', 1, 'ARS', 'UNLIMITED') $$, '23503', NULL, 'Cross-tenant membership foreign keys fail');
SELECT throws_ok($$ INSERT INTO public.attendances (gym_id, gym_member_id, membership_id, attendance_date, occurred_at, method) VALUES ('00000000-0000-0000-0000-000000000001', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', NULL, current_date, now(), 'MANUAL') $$, '23503', NULL, 'Cross-tenant attendance foreign key fails');
SELECT throws_ok($$ INSERT INTO public.memberships (gym_id, gym_member_id, membership_plan_id, starts_at, ends_at, contracted_price, currency, access_type_snapshot, target_snapshot, period_snapshot) VALUES ('00000000-0000-0000-0000-000000000001', 'cccccccc-cccc-cccc-cccc-cccccccccccc', '10000000-0000-0000-0000-000000000001', now(), now() + interval '30 days', 30000, 'ARS', 'WEEKLY_FREQUENCY', 3, 'WEEK') $$, '23505', NULL, 'At most one active membership is allowed per member');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated","email":"admin-a@ytufit.local"}';
SELECT public.cancel_attendance('40000000-0000-0000-0000-000000000001', 'Correction') IS NOT NULL;
SELECT results_eq($$ SELECT status FROM public.attendances WHERE id = '40000000-0000-0000-0000-000000000001' $$, $$ VALUES ('CANCELLED'::public.attendance_status) $$, 'Cancelling attendance preserves history');
SELECT public.register_attendance('cccccccc-cccc-cccc-cccc-cccccccccccc', '2026-08-04 19:00:00+00', 'MANUAL', '30000000-0000-0000-0000-000000000001', 'replacement') IS NOT NULL;
SELECT throws_ok($$ SELECT public.register_attendance('cccccccc-cccc-cccc-cccc-cccccccccccc', '2026-08-04 20:00:00+00', 'MANUAL', '30000000-0000-0000-0000-000000000001', 'duplicate') $$, '23505', NULL, 'Only one valid attendance per local day');
SELECT results_eq($$ SELECT attendance_date FROM public.attendances WHERE source_reference = 'replacement' $$, $$ VALUES ('2026-08-04'::date) $$, 'Attendance date is derived from gym timezone');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}';
SELECT throws_ok($$ SELECT public.cancel_attendance('40000000-0000-0000-0000-000000000002', 'No') $$, '42501', NULL, 'Member cannot cancel attendance');
SET LOCAL ROLE postgres;
RESET "request.jwt.claims";
UPDATE public.membership_plans SET price = 99999 WHERE id = '10000000-0000-0000-0000-000000000001';
SELECT is((SELECT contracted_price FROM public.memberships WHERE id = '30000000-0000-0000-0000-000000000001'), 30000::numeric, 'Membership price snapshot is historical');
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated","email":"admin-a@ytufit.local"}';
SELECT public.change_membership_plan('30000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000002', now(), 'Plan change') IS NOT NULL;
SELECT results_eq($$ SELECT status FROM public.memberships WHERE id = '30000000-0000-0000-0000-000000000001' $$, $$ VALUES ('CANCELLED'::public.membership_status) $$, 'Changing plan closes the previous contract');
SELECT results_eq($$ SELECT count(*)::integer FROM public.memberships WHERE gym_member_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc' $$, $$ VALUES (2) $$, 'Changing plan preserves membership history');
SELECT results_eq($$ SELECT count(*)::integer FROM public.memberships WHERE gym_member_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc' AND status = 'ACTIVE' $$, $$ VALUES (1) $$, 'Changing plan leaves one active membership');
SELECT results_eq($$ SELECT access_type_snapshot FROM public.memberships WHERE gym_member_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc' AND status = 'ACTIVE' $$, $$ VALUES ('MONTHLY_LIMIT'::public.membership_access_type) $$, 'New membership stores the new plan snapshot');
SET LOCAL ROLE postgres;
RESET "request.jwt.claims";
INSERT INTO public.memberships (
  id, gym_id, gym_member_id, membership_plan_id, status, starts_at, ends_at,
  contracted_price, currency, access_type_snapshot
) VALUES (
  '30000000-0000-0000-0000-000000000003',
  '00000000-0000-0000-0000-000000000001',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  '10000000-0000-0000-0000-000000000003',
  'ACTIVE', now() - interval '30 days', now() - interval '1 day',
  45000, 'ARS', 'UNLIMITED'
);
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';
SELECT public.renew_membership('30000000-0000-0000-0000-000000000003') IS NOT NULL;
SELECT results_eq($$ SELECT status FROM public.memberships WHERE id = '30000000-0000-0000-0000-000000000003' $$, $$ VALUES ('EXPIRED'::public.membership_status) $$, 'Expired active membership is normalized before renewal');
SELECT results_eq($$ SELECT count(*)::integer FROM public.memberships WHERE gym_member_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' AND status = 'ACTIVE' $$, $$ VALUES (1) $$, 'Renewal leaves one active membership');
SELECT throws_ok($$ SELECT public.register_attendance('cccccccc-cccc-cccc-cccc-cccccccccccc', now(), 'MANUAL', NULL, 'member') $$, '42501', NULL, 'Member remains unable to register after renewal');
SET LOCAL ROLE anon;
RESET "request.jwt.claims";
SELECT is_empty($$ SELECT * FROM public.memberships $$, 'Anonymous cannot read memberships');
SELECT is_empty($$ SELECT * FROM public.attendances $$, 'Anonymous cannot read attendance');
SELECT * FROM finish();
ROLLBACK;
