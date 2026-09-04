CREATE EXTENSION IF NOT EXISTS pgtap;
BEGIN;
SELECT no_plan();

SET LOCAL ROLE postgres;
RESET "request.jwt.claims";

INSERT INTO public.streak_rules (
  id, gym_id, name, target_days, max_freezes, timezone, created_by
) VALUES
  ('74000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'Engine 3', 3, 1, 'America/Montevideo', '11111111-1111-1111-1111-111111111111'),
  ('74000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000001', 'Engine 2', 2, 0, 'America/Montevideo', '11111111-1111-1111-1111-111111111111'),
  ('74000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000001', 'Engine partial', 2, 1, 'America/Montevideo', '11111111-1111-1111-1111-111111111111');

SELECT ok(private.create_member_streak_rule_assignment(
  '00000000-0000-0000-0000-000000000001',
  'cccccccc-cccc-cccc-cccc-cccccccccccc',
  '74000000-0000-0000-0000-000000000001',
  '2026-08-03 03:00:00+00',
  'ACTIVE',
  '11111111-1111-1111-1111-111111111111',
  TRUE
) IS NOT NULL, 'Engine fixture assigns a one-freeze weekly rule');

INSERT INTO public.attendances (
  id, gym_id, gym_member_id, membership_id, attendance_date, occurred_at, method, status, created_by
) VALUES
  ('75000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'cccccccc-cccc-cccc-cccc-cccccccccccc', '30000000-0000-0000-0000-000000000001', '2026-08-03', '2026-08-03 13:00:00+00', 'MANUAL', 'VALID', '11111111-1111-1111-1111-111111111111'),
  ('75000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000001', 'cccccccc-cccc-cccc-cccc-cccccccccccc', '30000000-0000-0000-0000-000000000001', '2026-08-05', '2026-08-05 13:00:00+00', 'MANUAL', 'VALID', '11111111-1111-1111-1111-111111111111'),
  ('75000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000001', 'cccccccc-cccc-cccc-cccc-cccccccccccc', '30000000-0000-0000-0000-000000000001', '2026-08-10', '2026-08-10 13:00:00+00', 'MANUAL', 'VALID', '11111111-1111-1111-1111-111111111111'),
  ('75000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000001', 'cccccccc-cccc-cccc-cccc-cccccccccccc', '30000000-0000-0000-0000-000000000001', '2026-08-11', '2026-08-11 13:00:00+00', 'MANUAL', 'VALID', '11111111-1111-1111-1111-111111111111'),
  ('75000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000001', 'cccccccc-cccc-cccc-cccc-cccccccccccc', '30000000-0000-0000-0000-000000000001', '2026-08-12', '2026-08-12 13:00:00+00', 'MANUAL', 'VALID', '11111111-1111-1111-1111-111111111111'),
  ('75000000-0000-0000-0000-000000000006', '00000000-0000-0000-0000-000000000001', 'cccccccc-cccc-cccc-cccc-cccccccccccc', '30000000-0000-0000-0000-000000000001', '2026-08-17', '2026-08-17 13:00:00+00', 'MANUAL', 'VALID', '11111111-1111-1111-1111-111111111111'),
  ('75000000-0000-0000-0000-000000000007', '00000000-0000-0000-0000-000000000001', 'cccccccc-cccc-cccc-cccc-cccccccccccc', '30000000-0000-0000-0000-000000000001', '2026-08-18', '2026-08-18 13:00:00+00', 'MANUAL', 'VALID', '11111111-1111-1111-1111-111111111111'),
  ('75000000-0000-0000-0000-000000000008', '00000000-0000-0000-0000-000000000001', 'cccccccc-cccc-cccc-cccc-cccccccccccc', '30000000-0000-0000-0000-000000000001', '2026-08-24', '2026-08-24 13:00:00+00', 'MANUAL', 'VALID', '11111111-1111-1111-1111-111111111111'),
  ('75000000-0000-0000-0000-000000000009', '00000000-0000-0000-0000-000000000001', 'cccccccc-cccc-cccc-cccc-cccccccccccc', '30000000-0000-0000-0000-000000000001', '2026-08-25', '2026-08-25 13:00:00+00', 'MANUAL', 'VALID', '11111111-1111-1111-1111-111111111111'),
  ('75000000-0000-0000-0000-000000000010', '00000000-0000-0000-0000-000000000001', 'cccccccc-cccc-cccc-cccc-cccccccccccc', '30000000-0000-0000-0000-000000000001', '2026-08-26', '2026-08-26 13:00:00+00', 'MANUAL', 'VALID', '11111111-1111-1111-1111-111111111111');

SELECT ok(private.ensure_streak_period('cccccccc-cccc-cccc-cccc-cccccccccccc', '2026-08-03', '2026-09-01 03:00:00+00') IS NOT NULL, 'Engine ensures first closed weekly period');
SELECT ok(private.ensure_streak_period('cccccccc-cccc-cccc-cccc-cccccccccccc', '2026-08-10', '2026-09-01 03:00:00+00') IS NOT NULL, 'Engine ensures second closed weekly period');
SELECT ok(private.ensure_streak_period('cccccccc-cccc-cccc-cccc-cccccccccccc', '2026-08-17', '2026-09-01 03:00:00+00') IS NOT NULL, 'Engine ensures incomplete closed period');
SELECT ok(private.ensure_streak_period('cccccccc-cccc-cccc-cccc-cccccccccccc', '2026-08-24', '2026-09-01 03:00:00+00') IS NOT NULL, 'Engine ensures following completed period');
SELECT ok(private.recalculate_member_streak('cccccccc-cccc-cccc-cccc-cccccccccccc', '2026-08-03', '2026-09-01 03:00:00+00') IS NOT NULL, 'Engine recalculates materialized weekly streak history');

SELECT results_eq(
  $$ SELECT period_start, valid_days, status, freeze_applied FROM public.streak_periods WHERE gym_member_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc' ORDER BY period_start $$,
  $$ VALUES
    ('2026-08-03'::date, 3::smallint, 'COMPLETED'::public.streak_period_status, false),
    ('2026-08-10'::date, 3::smallint, 'COMPLETED'::public.streak_period_status, false),
    ('2026-08-17'::date, 2::smallint, 'FROZEN'::public.streak_period_status, true),
    ('2026-08-24'::date, 3::smallint, 'COMPLETED'::public.streak_period_status, false) $$,
  'Closed periods complete, freeze, and continue in chronological order'
);
SELECT results_eq(
  $$ SELECT current_streak, best_streak, freezes_available, last_completed_period_start, calculated_through FROM public.member_streaks WHERE gym_member_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc' $$,
  $$ VALUES (3, 3, 0::smallint, '2026-08-24'::date, '2026-08-24'::date) $$,
  'Projection reflects frozen continuity and consumed freeze balance'
);
SELECT results_eq(
  $$ SELECT transaction_type, amount, streak_period_id IS NOT NULL, reversed_by_transaction_id IS NULL FROM public.streak_freeze_transactions WHERE gym_member_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc' ORDER BY created_at, id $$,
  $$ VALUES
    ('GRANT'::public.streak_freeze_transaction_type, 1::smallint, false, true),
    ('CONSUME'::public.streak_freeze_transaction_type, 1::smallint, true, true) $$,
  'Freeze ledger consumes one freeze without deleting the initial grant'
);

INSERT INTO public.attendances (
  id, gym_id, gym_member_id, membership_id, attendance_date, occurred_at, method, status, created_by
) VALUES (
  '75000000-0000-0000-0000-000000000011',
  '00000000-0000-0000-0000-000000000001',
  'cccccccc-cccc-cccc-cccc-cccccccccccc',
  '30000000-0000-0000-0000-000000000001',
  '2026-08-19',
  '2026-08-19 13:00:00+00',
  'MANUAL',
  'VALID',
  '11111111-1111-1111-1111-111111111111'
);
SELECT ok(private.recalculate_member_streak('cccccccc-cccc-cccc-cccc-cccccccccccc', '2026-08-17', '2026-09-01 03:00:00+00') IS NOT NULL, 'Historical attendance correction replays the affected streak window');
SELECT results_eq(
  $$ SELECT status, valid_days, freeze_applied FROM public.streak_periods WHERE gym_member_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc' AND period_start = '2026-08-17' $$,
  $$ VALUES ('COMPLETED'::public.streak_period_status, 3::smallint, false) $$,
  'Corrected period is completed and no longer frozen'
);
SELECT results_eq(
  $$ SELECT current_streak, best_streak, freezes_available FROM public.member_streaks WHERE gym_member_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc' $$,
  $$ VALUES (4, 4, 1::smallint) $$,
  'Corrected projection restores the freeze and extends the streak'
);
SELECT results_eq(
  $$ SELECT transaction_type, source_transaction_id IS NOT NULL FROM public.streak_freeze_transactions WHERE gym_member_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc' ORDER BY created_at, id $$,
  $$ VALUES
    ('GRANT'::public.streak_freeze_transaction_type, false),
    ('CONSUME'::public.streak_freeze_transaction_type, false),
    ('RESTORE'::public.streak_freeze_transaction_type, true) $$,
  'Correction appends a RESTORE transaction instead of mutating away the CONSUME row'
);

SELECT ok(private.ensure_streak_period('cccccccc-cccc-cccc-cccc-cccccccccccc', '2026-09-07', '2026-09-08 03:00:00+00') IS NOT NULL, 'Engine creates a current week as OPEN');
SELECT results_eq(
  $$ SELECT status, finalized_at IS NULL FROM public.streak_periods WHERE gym_member_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc' AND period_start = '2026-09-07' $$,
  $$ VALUES ('OPEN'::public.streak_period_status, true) $$,
  'Current not-yet-closed week remains open'
);
SELECT throws_ok(
  $$ SELECT private.finalize_streak_period((SELECT id FROM public.streak_periods WHERE gym_member_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc' AND period_start = '2026-09-07'), '2026-09-08 03:00:00+00') $$,
  '55000',
  NULL,
  'Open current week cannot be finalized before the local end boundary'
);
INSERT INTO public.streak_freeze_transactions (
  gym_id, gym_member_id, streak_period_id, transaction_type, amount, reason
) VALUES (
  '00000000-0000-0000-0000-000000000001',
  'cccccccc-cccc-cccc-cccc-cccccccccccc',
  (SELECT id FROM public.streak_periods WHERE gym_member_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc' AND period_start = '2026-09-07'),
  'CONSUME',
  1,
  'fixture stale consume on open period'
);
SELECT ok(private.recalculate_member_streak('cccccccc-cccc-cccc-cccc-cccccccccccc', '2026-09-07', '2026-09-08 03:00:00+00') IS NOT NULL, 'Recalculate restores a stale consume from an OPEN period');
SELECT results_eq(
  $$ SELECT status, finalized_at IS NULL, eligibility_reason, private.get_active_streak_freeze_consume(id) IS NULL FROM public.streak_periods WHERE gym_member_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc' AND period_start = '2026-09-07' $$,
  $$ VALUES ('OPEN'::public.streak_period_status, true, NULL::public.streak_period_eligibility_reason, true) $$,
  'OPEN period remains open and has no active consume after stale-freeze reconciliation'
);
SELECT results_eq(
  $$ SELECT freezes_available FROM public.member_streaks WHERE gym_member_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc' $$,
  $$ VALUES (1::smallint) $$,
  'Stale OPEN consume restoration preserves available freeze balance'
);

SELECT ok(private.create_member_streak_rule_assignment(
  '00000000-0000-0000-0000-000000000001',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  '74000000-0000-0000-0000-000000000003',
  '2026-09-09 03:00:00+00',
  'ACTIVE',
  '11111111-1111-1111-1111-111111111111',
  TRUE
) IS NOT NULL, 'Engine fixture assigns a midweek rule for partial period eligibility');
SELECT ok(private.ensure_streak_period('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '2026-09-07', '2026-09-10 03:00:00+00') IS NOT NULL, 'Engine materializes a partial initial period');
SELECT results_eq(
  $$ SELECT status, eligibility_reason, finalized_at IS NULL FROM public.streak_periods WHERE gym_member_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' AND period_start = '2026-09-07' $$,
  $$ VALUES ('OPEN'::public.streak_period_status, NULL::public.streak_period_eligibility_reason, true) $$,
  'Partial initial current week remains OPEN before the boundary'
);
SELECT ok(private.recalculate_member_streak('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '2026-09-07', '2026-09-10 03:00:00+00') IS NOT NULL, 'Recalculating a partial current week before boundary is idempotent');
SELECT results_eq(
  $$ SELECT status, eligibility_reason, finalized_at IS NULL FROM public.streak_periods WHERE gym_member_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' AND period_start = '2026-09-07' $$,
  $$ VALUES ('OPEN'::public.streak_period_status, NULL::public.streak_period_eligibility_reason, true) $$,
  'Partial current week stays OPEN with no provisional eligibility reason'
);
SELECT results_eq(
  $$ SELECT freezes_available FROM public.member_streaks WHERE gym_member_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' $$,
  $$ VALUES (1::smallint) $$,
  'OPEN partial-initial period consumes no freeze'
);
SELECT ok(private.recalculate_member_streak('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '2026-09-07', '2026-09-14 03:00:00+00') IS NOT NULL, 'Partial current week may finalize at the exact end boundary');
SELECT results_eq(
  $$ SELECT status, eligibility_reason, finalized_at IS NOT NULL FROM public.streak_periods WHERE gym_member_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' AND period_start = '2026-09-07' $$,
  $$ VALUES ('NOT_ELIGIBLE'::public.streak_period_status, 'PARTIAL_INITIAL_PERIOD'::public.streak_period_eligibility_reason, true) $$,
  'Same partial week becomes NOT_ELIGIBLE at the boundary'
);

SELECT ok(private.create_member_streak_rule_assignment(
  '00000000-0000-0000-0000-000000000001',
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  '74000000-0000-0000-0000-000000000001',
  '2026-08-03 03:00:00+00',
  'ACTIVE',
  '11111111-1111-1111-1111-111111111111',
  TRUE
) IS NOT NULL, 'Engine fixture creates an active assignment for scheduled activation');
UPDATE public.member_streak_rules
SET ends_at = '2026-08-17 03:00:00+00'
WHERE gym_member_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
  AND status = 'ACTIVE';
SELECT ok(private.create_member_streak_rule_assignment(
  '00000000-0000-0000-0000-000000000001',
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  '74000000-0000-0000-0000-000000000002',
  '2026-08-17 03:00:00+00',
  'SCHEDULED',
  '11111111-1111-1111-1111-111111111111',
  FALSE
) IS NOT NULL, 'Engine fixture creates a scheduled successor');
SELECT lives_ok($$ SELECT private.activate_due_streak_rule('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '2026-08-17 03:00:00+00') $$, 'Scheduled rule activation is idempotent and private');
SELECT results_eq(
  $$ SELECT status, target_days FROM public.member_streak_rules WHERE gym_member_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' ORDER BY starts_at $$,
  $$ VALUES
    ('ENDED'::public.member_streak_rule_status, 3::smallint),
    ('ACTIVE'::public.member_streak_rule_status, 2::smallint) $$,
  'Due scheduled assignment becomes ACTIVE and prior assignment becomes ENDED'
);
SELECT ok(private.ensure_streak_period('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '2026-09-07', '2026-09-08 03:00:00+00') IS NOT NULL, 'Engine creates a no-membership current week as OPEN');
SELECT results_eq(
  $$ SELECT status, eligibility_reason, finalized_at IS NULL FROM public.streak_periods WHERE gym_member_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' AND period_start = '2026-09-07' $$,
  $$ VALUES ('OPEN'::public.streak_period_status, NULL::public.streak_period_eligibility_reason, true) $$,
  'No-membership current week remains OPEN before the boundary'
);
SELECT ok(private.recalculate_member_streak('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '2026-09-07', '2026-09-08 03:00:00+00') IS NOT NULL, 'Recalculating a no-membership current week before boundary is idempotent');
SELECT results_eq(
  $$ SELECT status, eligibility_reason, finalized_at IS NULL FROM public.streak_periods WHERE gym_member_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' AND period_start = '2026-09-07' $$,
  $$ VALUES ('OPEN'::public.streak_period_status, NULL::public.streak_period_eligibility_reason, true) $$,
  'No-membership current week stays OPEN with no provisional eligibility reason'
);
SELECT results_eq(
  $$ SELECT freezes_available FROM public.member_streaks WHERE gym_member_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' $$,
  $$ VALUES (1::smallint) $$,
  'OPEN no-membership period consumes no freeze'
);
SELECT ok(private.recalculate_member_streak('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '2026-09-07', '2026-09-14 03:00:00+00') IS NOT NULL, 'No-membership week may finalize at the exact end boundary');
SELECT results_eq(
  $$ SELECT status, eligibility_reason, finalized_at IS NOT NULL FROM public.streak_periods WHERE gym_member_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' AND period_start = '2026-09-07' $$,
  $$ VALUES ('NOT_ELIGIBLE'::public.streak_period_status, 'NO_ACTIVE_MEMBERSHIP'::public.streak_period_eligibility_reason, true) $$,
  'Same no-membership week becomes NOT_ELIGIBLE at the boundary'
);

SELECT throws_ok(
  $$ INSERT INTO public.streak_periods (gym_id, gym_member_id, member_streak_rule_id, period_start, period_end, period_start_at, period_end_at, timezone_snapshot, target_days_snapshot, status) VALUES ('00000000-0000-0000-0000-000000000001', 'cccccccc-cccc-cccc-cccc-cccccccccccc', (SELECT id FROM public.member_streak_rules WHERE gym_member_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc' AND status = 'ACTIVE'), '2026-10-06', '2026-10-12', '2026-10-06 03:00:00+00', '2026-10-13 03:00:00+00', 'America/Montevideo', 3, 'OPEN') $$,
  '22023',
  NULL,
  'Streak period trigger rejects non-Monday period starts'
);
INSERT INTO public.streak_freeze_transactions (
  gym_id, gym_member_id, streak_period_id, transaction_type, amount, reason
) VALUES (
  '00000000-0000-0000-0000-000000000001',
  'cccccccc-cccc-cccc-cccc-cccccccccccc',
  (SELECT id FROM public.streak_periods WHERE gym_member_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc' AND period_start = '2026-08-17'),
  'CONSUME',
  1,
  'fixture effective consume after restore'
);
SELECT throws_ok(
  $$ INSERT INTO public.streak_freeze_transactions (gym_id, gym_member_id, streak_period_id, transaction_type, amount, reason) VALUES ('00000000-0000-0000-0000-000000000001', 'cccccccc-cccc-cccc-cccc-cccccccccccc', (SELECT id FROM public.streak_periods WHERE gym_member_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc' AND period_start = '2026-08-17'), 'CONSUME', 1, 'duplicate effective consume') $$,
  '23505',
  NULL,
  'Only one unreversed CONSUME can be effective for a period'
);

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated","email":"admin-a@ytufit.local"}';
SELECT throws_ok(
  $$ SELECT private.ensure_streak_period('cccccccc-cccc-cccc-cccc-cccccccccccc', '2026-09-14', '2026-09-15 03:00:00+00') $$,
  '42501',
  NULL,
  'Authenticated users cannot execute the private Streak engine'
);

SET LOCAL ROLE postgres;
RESET "request.jwt.claims";
SELECT is_empty(
  $$ SELECT p.proname FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = 'public' AND p.proname ILIKE '%streak%period%' $$,
  'Core engine exposes no public period or recalculation RPCs'
);
SELECT is_empty(
  $$ SELECT tgname FROM pg_trigger WHERE tgrelid = 'public.attendances'::regclass AND NOT tgisinternal AND tgname ILIKE '%streak%' $$,
  'Core engine installs no Attendance-triggered Streak integration'
);
SELECT results_eq(
  $$ SELECT count(*)::integer FROM public.attendances WHERE gym_member_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc' $$,
  $$ VALUES (13) $$,
  'Streak engine reads attendance without creating attendance side effects'
);

SELECT * FROM finish();
ROLLBACK;
