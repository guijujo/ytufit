BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SELECT no_plan();

-- Extra Streak-only fixture used to test unassigned member visibility and reassignment behavior.
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

-- Schema surface.
SELECT has_table('public', 'streak_rules', 'streak_rules table exists');
SELECT has_table('public', 'member_streak_rules', 'member_streak_rules table exists');
SELECT has_table('public', 'streak_periods', 'streak_periods table exists');
SELECT has_table('public', 'streak_freeze_transactions', 'streak_freeze_transactions table exists');
SELECT has_table('public', 'member_streaks', 'member_streaks table exists');
SELECT isnt(to_regtype('public.streak_period_type'), NULL::regtype, 'streak_period_type enum exists');
SELECT isnt(to_regtype('public.streak_rule_status'), NULL::regtype, 'streak_rule_status enum exists');
SELECT isnt(to_regtype('public.member_streak_rule_status'), NULL::regtype, 'member_streak_rule_status enum exists');
SELECT isnt(to_regtype('public.streak_period_status'), NULL::regtype, 'streak_period_status enum exists');
SELECT isnt(to_regtype('public.streak_freeze_transaction_type'), NULL::regtype, 'streak_freeze_transaction_type enum exists');
SELECT isnt(to_regtype('public.streak_period_eligibility_reason'), NULL::regtype, 'streak_period_eligibility_reason enum exists');
SELECT results_eq($$ SELECT count(*)::integer FROM pg_class c WHERE c.oid IN ('public.streak_rules'::regclass, 'public.member_streak_rules'::regclass, 'public.streak_periods'::regclass, 'public.streak_freeze_transactions'::regclass, 'public.member_streaks'::regclass) AND c.relrowsecurity AND c.relforcerowsecurity $$, $$ VALUES (5) $$, 'All Streak tables use FORCE RLS');

-- Management RPC authorization.
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated","email":"admin-a@ytufit.local"}';
SELECT ok(public.create_streak_rule('00000000-0000-0000-0000-000000000001', 'Core 3', 3, 2, NULL) IS NOT NULL, 'Gym Admin creates a weekly streak rule with gym timezone default');
SELECT results_eq($$ SELECT target_days, max_freezes, week_starts_on, timezone, status FROM public.streak_rules WHERE name = 'Core 3' $$, $$ VALUES (3::smallint, 2::smallint, 1::smallint, 'America/Montevideo'::text, 'ACTIVE'::public.streak_rule_status) $$, 'Rule defaults and limits are stored');
SELECT ok(public.update_streak_rule((SELECT id FROM public.streak_rules WHERE name = 'Core 3'), 'Core 3 updated', 4, 1, 'America/Argentina/Buenos_Aires', 'ACTIVE') IS NOT NULL, 'Gym Admin updates active rule configuration');
SELECT results_eq($$ SELECT name, target_days, max_freezes, timezone FROM public.streak_rules WHERE name = 'Core 3 updated' $$, $$ VALUES ('Core 3 updated'::text, 4::smallint, 1::smallint, 'America/Argentina/Buenos_Aires'::text) $$, 'Rule update persists edited fields');
SELECT throws_ok($$ SELECT public.update_streak_rule((SELECT id FROM public.streak_rules WHERE name = 'Core 3 updated'), 'Bad archive via update', 4, 1, 'America/Montevideo', 'ARCHIVED') $$, '22023', NULL, 'Rules cannot be archived through update_streak_rule');
SELECT ok(public.create_streak_rule('00000000-0000-0000-0000-000000000001', 'Core 5', 5, 0, 'America/Montevideo') IS NOT NULL, 'Gym Admin creates replacement rule');
SELECT ok(public.create_streak_rule('00000000-0000-0000-0000-000000000001', 'Temporary archive', 2, 1, 'America/Montevideo') IS NOT NULL, 'Gym Admin creates archive candidate');
SELECT ok(public.archive_streak_rule((SELECT id FROM public.streak_rules WHERE name = 'Temporary archive')) IS NOT NULL, 'Gym Admin archives a rule');
SELECT results_eq($$ SELECT status, deleted_at IS NOT NULL FROM public.streak_rules WHERE name = 'Temporary archive' $$, $$ VALUES ('ARCHIVED'::public.streak_rule_status, true) $$, 'Archived rule is soft-deleted');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated","email":"trainer-a@ytufit.local"}';
SELECT throws_ok($$ SELECT public.create_streak_rule('00000000-0000-0000-0000-000000000001', 'Trainer rule', 3, 1, 'America/Montevideo') $$, '42501', NULL, 'Trainer cannot create streak rules');
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated","email":"member-a@ytufit.local"}';
SELECT throws_ok($$ SELECT public.create_streak_rule('00000000-0000-0000-0000-000000000001', 'Member rule', 3, 1, 'America/Montevideo') $$, '42501', NULL, 'Member cannot create streak rules');
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"99999999-9999-9999-9999-999999999999","role":"authenticated","email":"platform-admin@ytufit.local"}';
SELECT throws_ok($$ SELECT public.create_streak_rule('00000000-0000-0000-0000-000000000001', 'Platform rule', 3, 1, 'America/Montevideo') $$, '42501', NULL, 'Platform Admin has no implicit tenant rule management');
SET LOCAL ROLE anon;
RESET "request.jwt.claims";
SELECT throws_ok($$ SELECT public.create_streak_rule('00000000-0000-0000-0000-000000000001', 'Anon rule', 3, 1, 'America/Montevideo') $$, '42501', NULL, 'Anon cannot create streak rules');

-- Assignment snapshots and member projection bootstrap.
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated","email":"admin-a@ytufit.local"}';
SELECT ok(public.assign_member_streak_rule('00000000-0000-0000-0000-000000000001', 'cccccccc-cccc-cccc-cccc-cccccccccccc', (SELECT id FROM public.streak_rules WHERE name = 'Core 3 updated')) IS NOT NULL, 'Gym Admin assigns a streak rule to a member');
SELECT results_eq($$ SELECT target_days, max_freezes, period_type, week_starts_on, timezone, status FROM public.member_streak_rules WHERE gym_member_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc' $$, $$ VALUES (4::smallint, 1::smallint, 'WEEK'::public.streak_period_type, 1::smallint, 'America/Argentina/Buenos_Aires'::text, 'ACTIVE'::public.member_streak_rule_status) $$, 'Assignment snapshots rule configuration');
SELECT results_eq($$ SELECT current_streak, best_streak, freezes_available FROM public.member_streaks WHERE gym_member_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc' $$, $$ VALUES (0, 0, 1::smallint) $$, 'Assignment creates member streak projection with freeze balance');
SELECT results_eq($$ SELECT transaction_type, amount, reason FROM public.streak_freeze_transactions WHERE gym_member_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc' $$, $$ VALUES ('GRANT'::public.streak_freeze_transaction_type, 1::smallint, 'Initial streak rule assignment grant'::text) $$, 'Assignment records freeze grant ledger entry');
SELECT throws_ok($$ SELECT public.assign_member_streak_rule('00000000-0000-0000-0000-000000000001', 'cccccccc-cccc-cccc-cccc-cccccccccccc', (SELECT id FROM public.streak_rules WHERE name = 'Core 3 updated')) $$, '23505', NULL, 'Only one active streak rule assignment is allowed per member');
SELECT throws_ok($$ SELECT public.assign_member_streak_rule('00000000-0000-0000-0000-000000000001', 'ffffffff-ffff-ffff-ffff-ffffffff0001', (SELECT id FROM public.streak_rules WHERE name = 'Temporary archive')) $$, '23503', NULL, 'Archived rules cannot be assigned');
SELECT throws_ok($$ SELECT public.assign_member_streak_rule('00000000-0000-0000-0000-000000000001', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', (SELECT id FROM public.streak_rules WHERE name = 'Core 5')) $$, 'P0002', NULL, 'Gym Admin cannot assign a member from another tenant');
SELECT ok(public.change_member_streak_rule('00000000-0000-0000-0000-000000000001', 'cccccccc-cccc-cccc-cccc-cccccccccccc', (SELECT id FROM public.streak_rules WHERE name = 'Core 5')) IS NOT NULL, 'Gym Admin schedules a member rule change on the next weekly boundary');
SELECT results_eq($$ SELECT count(*)::integer FROM public.member_streak_rules WHERE gym_member_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc' AND status = 'ACTIVE' $$, $$ VALUES (1) $$, 'Rule change keeps exactly one active assignment');
SELECT results_eq($$ SELECT target_days, max_freezes FROM public.member_streak_rules WHERE gym_member_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc' AND status = 'ACTIVE' $$, $$ VALUES (5::smallint, 0::smallint) $$, 'New active assignment snapshots replacement rule');
SELECT results_eq($$ SELECT target_days, max_freezes FROM public.member_streak_rules WHERE gym_member_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc' AND status = 'ENDED' $$, $$ VALUES (4::smallint, 1::smallint) $$, 'Ended assignment keeps the original snapshot');
SELECT isnt((SELECT ends_at FROM public.member_streak_rules WHERE gym_member_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc' AND status = 'ENDED'), NULL::timestamptz, 'Ended assignment has an explicit boundary');
SELECT throws_ok($$ SELECT public.change_member_streak_rule('00000000-0000-0000-0000-000000000001', 'cccccccc-cccc-cccc-cccc-cccccccccccc', (SELECT id FROM public.streak_rules WHERE name = 'Core 5')) $$, '22023', NULL, 'Changing to the current active rule is rejected');

-- DB invariants and privileged fixture creation for RLS reads.
SET LOCAL ROLE postgres;
RESET "request.jwt.claims";
INSERT INTO public.streak_rules (id, gym_id, name, target_days, max_freezes, timezone, created_by)
VALUES ('70000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', 'Beta Core', 3, 1, 'America/Montevideo', '44444444-4444-4444-4444-444444444444');
INSERT INTO public.member_streak_rules (id, gym_id, gym_member_id, streak_rule_id, target_days, max_freezes, period_type, week_starts_on, timezone, starts_at, assigned_by)
VALUES ('71000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', '70000000-0000-0000-0000-000000000001', 3, 1, 'WEEK', 1, 'America/Montevideo', '2026-09-07 00:00:00+00', '44444444-4444-4444-4444-444444444444');
INSERT INTO public.member_streak_rules (id, gym_id, gym_member_id, streak_rule_id, target_days, max_freezes, period_type, week_starts_on, timezone, starts_at, assigned_by)
VALUES ('71000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000001', 'ffffffff-ffff-ffff-ffff-ffffffff0001', (SELECT id FROM public.streak_rules WHERE name = 'Core 5'), 5, 0, 'WEEK', 1, 'America/Montevideo', '2026-09-07 00:00:00+00', '11111111-1111-1111-1111-111111111111');
INSERT INTO public.member_streaks (id, gym_id, gym_member_id, freezes_available)
VALUES ('72000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000001', 'ffffffff-ffff-ffff-ffff-ffffffff0001', 0);
INSERT INTO public.member_streaks (id, gym_id, gym_member_id, freezes_available)
VALUES ('72000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 1);
INSERT INTO public.streak_periods (id, gym_id, gym_member_id, member_streak_rule_id, period_start, period_end, timezone_snapshot, target_days_snapshot, status)
VALUES
  ('73000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'cccccccc-cccc-cccc-cccc-cccccccccccc', (SELECT id FROM public.member_streak_rules WHERE gym_member_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc' AND status = 'ACTIVE'), '2026-09-07', '2026-09-13', 'America/Montevideo', 5, 'OPEN'),
  ('73000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000001', 'ffffffff-ffff-ffff-ffff-ffffffff0001', '71000000-0000-0000-0000-000000000002', '2026-09-14', '2026-09-20', 'America/Montevideo', 5, 'OPEN') ON CONFLICT DO NOTHING;
SELECT throws_ok($$ INSERT INTO public.streak_rules (gym_id, name, target_days, max_freezes, timezone, created_by) VALUES ('00000000-0000-0000-0000-000000000001', 'Bad target low', 0, 1, 'America/Montevideo', '11111111-1111-1111-1111-111111111111') $$, '23514', NULL, 'target_days lower bound is enforced');
SELECT throws_ok($$ INSERT INTO public.streak_rules (gym_id, name, target_days, max_freezes, timezone, created_by) VALUES ('00000000-0000-0000-0000-000000000001', 'Bad target high', 8, 1, 'America/Montevideo', '11111111-1111-1111-1111-111111111111') $$, '23514', NULL, 'target_days upper bound is enforced');
SELECT throws_ok($$ INSERT INTO public.streak_rules (gym_id, name, target_days, max_freezes, timezone, created_by) VALUES ('00000000-0000-0000-0000-000000000001', 'Bad freeze low', 3, -1, 'America/Montevideo', '11111111-1111-1111-1111-111111111111') $$, '23514', NULL, 'max_freezes lower bound is enforced');
SELECT throws_ok($$ INSERT INTO public.streak_rules (gym_id, name, target_days, max_freezes, timezone, created_by) VALUES ('00000000-0000-0000-0000-000000000001', 'Bad freeze high', 3, 3, 'America/Montevideo', '11111111-1111-1111-1111-111111111111') $$, '23514', NULL, 'max_freezes upper bound is enforced');
SELECT throws_ok($$ INSERT INTO public.streak_rules (gym_id, name, target_days, max_freezes, week_starts_on, timezone, created_by) VALUES ('00000000-0000-0000-0000-000000000001', 'Bad weekday', 3, 1, 2, 'America/Montevideo', '11111111-1111-1111-1111-111111111111') $$, '23514', NULL, 'Only Monday weekly streaks are allowed');
SELECT throws_ok($$ INSERT INTO public.streak_rules (gym_id, name, target_days, max_freezes, timezone, created_by) VALUES ('00000000-0000-0000-0000-000000000001', 'Bad timezone', 3, 1, 'Mars/Base', '11111111-1111-1111-1111-111111111111') $$, '22023', NULL, 'Invalid timezones are rejected');
SELECT throws_ok($$ INSERT INTO public.member_streak_rules (gym_id, gym_member_id, streak_rule_id, target_days, max_freezes, period_type, week_starts_on, timezone, starts_at, assigned_by) VALUES ('00000000-0000-0000-0000-000000000001', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', (SELECT id FROM public.streak_rules WHERE name = 'Core 5'), 5, 0, 'WEEK', 1, 'America/Montevideo', now(), '11111111-1111-1111-1111-111111111111') $$, '23503', NULL, 'Member streak assignment enforces member tenant');
SELECT throws_ok($$ INSERT INTO public.member_streak_rules (gym_id, gym_member_id, streak_rule_id, target_days, max_freezes, period_type, week_starts_on, timezone, starts_at, assigned_by) VALUES ('00000000-0000-0000-0000-000000000002', 'dddddddd-dddd-dddd-dddd-dddddddddddd', (SELECT id FROM public.streak_rules WHERE name = 'Core 5'), 5, 0, 'WEEK', 1, 'America/Montevideo', now(), '44444444-4444-4444-4444-444444444444') $$, '23503', NULL, 'Member streak assignment enforces rule tenant');
SELECT throws_ok($$ INSERT INTO public.streak_periods (gym_id, gym_member_id, member_streak_rule_id, period_start, period_end, timezone_snapshot, target_days_snapshot, status) VALUES ('00000000-0000-0000-0000-000000000001', 'cccccccc-cccc-cccc-cccc-cccccccccccc', (SELECT id FROM public.member_streak_rules WHERE gym_member_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc' AND status = 'ACTIVE'), '2026-09-07', '2026-09-12', 'America/Montevideo', 5, 'OPEN') $$, '23514', NULL, 'Streak periods are constrained to full weeks');
SELECT throws_ok($$ INSERT INTO public.streak_periods (gym_id, gym_member_id, member_streak_rule_id, period_start, period_end, timezone_snapshot, target_days_snapshot, status, eligibility_reason) VALUES ('00000000-0000-0000-0000-000000000001', 'cccccccc-cccc-cccc-cccc-cccccccccccc', (SELECT id FROM public.member_streak_rules WHERE gym_member_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc' AND status = 'ACTIVE'), '2026-09-21', '2026-09-27', 'America/Montevideo', 5, 'OPEN', 'STREAK_NOT_ENABLED') $$, '23514', NULL, 'OPEN periods cannot carry ineligible reason');
SELECT throws_ok($$ INSERT INTO public.streak_periods (gym_id, gym_member_id, member_streak_rule_id, period_start, period_end, timezone_snapshot, target_days_snapshot, status, finalized_at) VALUES ('00000000-0000-0000-0000-000000000001', 'cccccccc-cccc-cccc-cccc-cccccccccccc', (SELECT id FROM public.member_streak_rules WHERE gym_member_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc' AND status = 'ACTIVE'), '2026-09-28', '2026-10-04', 'America/Montevideo', 5, 'NOT_ELIGIBLE', now()) $$, '23514', NULL, 'NOT_ELIGIBLE periods require an eligibility reason');
SELECT throws_ok($$ INSERT INTO public.streak_freeze_transactions (gym_id, gym_member_id, transaction_type, amount, reason) VALUES ('00000000-0000-0000-0000-000000000001', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'GRANT', 0, 'bad') $$, '23514', NULL, 'Freeze ledger amount must be positive');
SELECT throws_ok($$ INSERT INTO public.streak_freeze_transactions (gym_id, gym_member_id, transaction_type, amount, reason) VALUES ('00000000-0000-0000-0000-000000000001', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'RESTORE', 1, 'bad') $$, '23503', NULL, 'RESTORE transactions require a source transaction');
SELECT throws_ok($$ INSERT INTO public.member_streaks (gym_id, gym_member_id, current_streak, best_streak, freezes_available) VALUES ('00000000-0000-0000-0000-000000000001', 'ffffffff-ffff-ffff-ffff-ffffffff0001', 2, 1, 0) $$, '23514', NULL, 'Projection best streak must cover current streak');
SELECT throws_ok($$ INSERT INTO public.member_streaks (gym_id, gym_member_id, current_streak, best_streak, freezes_available) VALUES ('00000000-0000-0000-0000-000000000001', 'ffffffff-ffff-ffff-ffff-ffffffff0001', 0, 0, -1) $$, '23514', NULL, 'Projection freeze balance cannot be negative');

-- RLS visibility.
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated","email":"member-a@ytufit.local"}';
SELECT results_eq($$ SELECT count(*)::integer FROM public.member_streak_rules WHERE gym_member_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc' $$, $$ VALUES (2) $$, 'Member reads own streak assignment history');
SELECT results_eq($$ SELECT freezes_available FROM public.member_streaks WHERE gym_member_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc' $$, $$ VALUES (1::smallint) $$, 'Member reads own streak projection');
SELECT is_empty($$ SELECT * FROM public.member_streaks WHERE gym_member_id = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee' $$, 'Member cannot read another tenant projection');
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated","email":"trainer-a@ytufit.local"}';
SELECT results_eq($$ SELECT count(*)::integer FROM public.member_streaks WHERE gym_member_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc' $$, $$ VALUES (1) $$, 'Trainer reads assigned member projection');
SELECT results_eq($$ SELECT count(*)::integer FROM public.streak_periods WHERE gym_member_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc' $$, $$ VALUES (1) $$, 'Trainer reads assigned member periods');
SELECT is_empty($$ SELECT * FROM public.streak_periods WHERE gym_member_id = 'ffffffff-ffff-ffff-ffff-ffffffff0001' $$, 'Trainer cannot read unassigned member periods');
SELECT is_empty($$ SELECT * FROM public.streak_freeze_transactions WHERE gym_member_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc' $$, 'Trainer cannot read member freeze ledger');
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated","email":"admin-a@ytufit.local"}';
SELECT is_empty($$ SELECT * FROM public.member_streaks WHERE gym_member_id = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee' $$, 'Gym Admin A cannot read Gym B member streak projection');
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"99999999-9999-9999-9999-999999999999","role":"authenticated","email":"platform-admin@ytufit.local"}';
SELECT is_empty($$ SELECT * FROM public.streak_rules WHERE gym_id = '00000000-0000-0000-0000-000000000001' $$, 'Platform Admin cannot read tenant streak rules implicitly');
SELECT is_empty($$ SELECT * FROM public.member_streaks WHERE gym_id = '00000000-0000-0000-0000-000000000001' $$, 'Platform Admin cannot read tenant member streaks implicitly');
SET LOCAL ROLE anon;
RESET "request.jwt.claims";
SELECT is_empty($$ SELECT * FROM public.streak_rules $$, 'Anon cannot read streak rules');
SELECT is_empty($$ SELECT * FROM public.member_streaks $$, 'Anon cannot read member streak projections');

-- Direct authenticated DML is blocked; all writes go through RPCs or future engine code.
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated","email":"admin-a@ytufit.local"}';
SELECT throws_ok($$ INSERT INTO public.streak_rules (gym_id, name, target_days, max_freezes, timezone, created_by) VALUES ('00000000-0000-0000-0000-000000000001', 'Direct rule', 3, 1, 'America/Montevideo', '11111111-1111-1111-1111-111111111111') $$, '42501', NULL, 'Direct INSERT on streak_rules is blocked');
SELECT throws_ok($$ UPDATE public.member_streaks SET current_streak = 99 WHERE gym_member_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc' $$, '42501', NULL, 'Direct UPDATE on member_streaks is blocked');
SELECT throws_ok($$ INSERT INTO public.streak_periods (gym_id, gym_member_id, member_streak_rule_id, period_start, period_end, timezone_snapshot, target_days_snapshot) VALUES ('00000000-0000-0000-0000-000000000001', 'cccccccc-cccc-cccc-cccc-cccccccccccc', (SELECT id FROM public.member_streak_rules WHERE gym_member_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc' AND status = 'ACTIVE'), '2026-10-05', '2026-10-11', 'America/Montevideo', 5) $$, '42501', NULL, 'Direct INSERT on streak_periods is blocked');
SELECT throws_ok($$ DELETE FROM public.streak_freeze_transactions WHERE gym_member_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc' $$, '42501', NULL, 'Direct DELETE on freeze ledger is blocked');

-- SECURITY DEFINER posture.
SET LOCAL ROLE postgres;
RESET "request.jwt.claims";
SELECT is_empty($$ SELECT p.proname FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = 'public' AND p.proname IN ('create_streak_rule', 'update_streak_rule', 'archive_streak_rule', 'assign_member_streak_rule', 'change_member_streak_rule', 'createStreakRule', 'updateStreakRule', 'archiveStreakRule', 'assignMemberStreakRule', 'changeMemberStreakRule') AND has_function_privilege('public', p.oid, 'EXECUTE') $$, 'PUBLIC EXECUTE is revoked for Streak public RPCs');
SELECT is_empty($$ SELECT p.proname FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = 'private' AND p.proname IN ('is_valid_timezone', 'next_monday_boundary', 'validate_streak_rule_config', 'validate_member_streak_rule_snapshot', 'validate_streak_period_snapshot', 'validate_streak_freeze_transaction', 'create_member_streak_rule_assignment') AND has_function_privilege('public', p.oid, 'EXECUTE') $$, 'PUBLIC EXECUTE is revoked for Streak private helpers');
SELECT is_empty($$ SELECT p.proname FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = 'private' AND p.proname IN ('is_valid_timezone', 'next_monday_boundary', 'validate_streak_rule_config', 'validate_member_streak_rule_snapshot', 'validate_streak_period_snapshot', 'validate_streak_freeze_transaction', 'create_member_streak_rule_assignment') AND has_function_privilege('authenticated', p.oid, 'EXECUTE') $$, 'Authenticated users cannot execute Streak private helpers directly');
SELECT is_empty($$ SELECT p.proname FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = 'public' AND p.proname IN ('create_streak_rule', 'update_streak_rule', 'archive_streak_rule', 'assign_member_streak_rule', 'change_member_streak_rule', 'createStreakRule', 'updateStreakRule', 'archiveStreakRule', 'assignMemberStreakRule', 'changeMemberStreakRule') AND p.prosecdef AND NOT EXISTS (SELECT 1 FROM unnest(COALESCE(p.proconfig, ARRAY[]::text[])) cfg WHERE cfg = 'search_path=pg_catalog, public') $$, 'Streak SECURITY DEFINER RPCs keep explicit search_path');
SELECT is_empty($$ SELECT c.relname FROM pg_class c WHERE c.oid IN ('public.streak_rules'::regclass, 'public.member_streak_rules'::regclass, 'public.streak_periods'::regclass, 'public.streak_freeze_transactions'::regclass, 'public.member_streaks'::regclass) AND (has_table_privilege('authenticated', c.oid, 'INSERT') OR has_table_privilege('authenticated', c.oid, 'UPDATE') OR has_table_privilege('authenticated', c.oid, 'DELETE')) $$, 'Authenticated has no direct Streak table DML privilege');
SELECT is_empty($$ SELECT routine_assignment_id FROM public.workout_sessions $$, 'Streak schema and rule management does not create workout or attendance side effects');
SELECT is_empty($$ SELECT proname FROM pg_proc JOIN pg_namespace ON pg_namespace.oid = pg_proc.pronamespace WHERE nspname = 'public' AND proname LIKE '%attendance%streak%' $$, 'No Attendance to Streak integration RPC exists in this slice');

SELECT * FROM finish();
ROLLBACK;
