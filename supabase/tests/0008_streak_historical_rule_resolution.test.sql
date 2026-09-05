BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SELECT no_plan();
SET LOCAL ROLE postgres;
RESET "request.jwt.claims";

INSERT INTO public.streak_rules (
  id, gym_id, name, target_days, max_freezes, timezone, created_by
) VALUES
  ('77000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001',
   'Historical A', 3, 1, 'America/New_York', '11111111-1111-1111-1111-111111111111'),
  ('77000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000001',
   'Historical B', 4, 1, 'America/New_York', '11111111-1111-1111-1111-111111111111'),
  ('77000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000001',
   'Partial rule', 2, 0, 'America/Montevideo', '11111111-1111-1111-1111-111111111111'),
  ('77000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000001',
   'Ambiguous rule', 5, 0, 'America/Montevideo', '11111111-1111-1111-1111-111111111111');

SELECT private.create_member_streak_rule_assignment(
  '00000000-0000-0000-0000-000000000001',
  'cccccccc-cccc-cccc-cccc-cccccccccccc',
  '77000000-0000-0000-0000-000000000001',
  '2026-03-02 05:00:00+00',
  'ACTIVE',
  '11111111-1111-1111-1111-111111111111',
  TRUE
);

-- The first A week crosses the US daylight-saving transition.
INSERT INTO public.attendances (
  gym_id, gym_member_id, membership_id, attendance_date, occurred_at,
  method, status, created_by
) VALUES
  ('00000000-0000-0000-0000-000000000001', 'cccccccc-cccc-cccc-cccc-cccccccccccc',
   '30000000-0000-0000-0000-000000000001', '2026-03-02', '2026-03-02 15:00:00+00',
   'MANUAL', 'VALID', '11111111-1111-1111-1111-111111111111'),
  ('00000000-0000-0000-0000-000000000001', 'cccccccc-cccc-cccc-cccc-cccccccccccc',
   '30000000-0000-0000-0000-000000000001', '2026-03-04', '2026-03-04 15:00:00+00',
   'MANUAL', 'VALID', '11111111-1111-1111-1111-111111111111'),
  ('00000000-0000-0000-0000-000000000001', 'cccccccc-cccc-cccc-cccc-cccccccccccc',
   '30000000-0000-0000-0000-000000000001', '2026-03-06', '2026-03-06 15:00:00+00',
   'MANUAL', 'VALID', '11111111-1111-1111-1111-111111111111');

SELECT private.ensure_streak_period(
  'cccccccc-cccc-cccc-cccc-cccccccccccc', '2026-03-02', '2026-03-09 04:00:00+00'
);
SELECT results_eq(
  $$ SELECT period_start_at, period_end_at, target_days_snapshot, timezone_snapshot
     FROM public.streak_periods
     WHERE gym_member_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'
       AND period_start = '2026-03-02' $$,
  $$ VALUES ('2026-03-02 05:00:00+00'::timestamptz, '2026-03-09 04:00:00+00'::timestamptz,
     3::smallint, 'America/New_York'::text) $$,
  'Rule A snapshots exact local Monday boundaries across DST'
);
SELECT private.recalculate_member_streak(
  'cccccccc-cccc-cccc-cccc-cccccccccccc', '2026-03-02', '2026-03-09 04:00:00+00'
);
SELECT results_eq(
  $$ SELECT status, current_streak, best_streak, freezes_available
     FROM public.streak_periods sp
     JOIN public.member_streaks ms USING (gym_id, gym_member_id)
     WHERE sp.gym_member_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'
       AND sp.period_start = '2026-03-02' $$,
  $$ VALUES ('COMPLETED'::public.streak_period_status, 1, 1, 1::smallint) $$,
  'Completed A period and initial freeze balance remain unchanged'
);

UPDATE public.member_streak_rules
SET ends_at = '2026-03-16 04:00:00+00'
WHERE gym_member_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'
  AND status = 'ACTIVE';
SELECT private.create_member_streak_rule_assignment(
  '00000000-0000-0000-0000-000000000001',
  'cccccccc-cccc-cccc-cccc-cccccccccccc',
  '77000000-0000-0000-0000-000000000002',
  '2026-03-16 04:00:00+00',
  'SCHEDULED',
  '11111111-1111-1111-1111-111111111111',
  FALSE
);

-- A historical ensure with a future as-of must not operate rule lifecycle.
SELECT private.ensure_streak_period(
  'cccccccc-cccc-cccc-cccc-cccccccccccc', '2026-03-09', '2026-03-20 12:00:00+00'
);
SELECT results_eq(
  $$ SELECT status, target_days FROM public.member_streak_rules
     WHERE gym_member_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'
     ORDER BY starts_at $$,
  $$ VALUES
     ('ACTIVE'::public.member_streak_rule_status, 3::smallint),
     ('SCHEDULED'::public.member_streak_rule_status, 4::smallint) $$,
  'Historical period creation does not activate a due scheduled rule'
);
SELECT results_eq(
  $$ SELECT member_streak_rule_id, target_days_snapshot, timezone_snapshot,
            period_start_at, period_end_at
     FROM public.streak_periods
     WHERE gym_member_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'
       AND period_start = '2026-03-09' $$,
  $$ SELECT id, 3::smallint, 'America/New_York'::text,
            '2026-03-09 04:00:00+00'::timestamptz,
            '2026-03-16 04:00:00+00'::timestamptz
     FROM public.member_streak_rules
     WHERE gym_member_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'
       AND starts_at = '2026-03-02 05:00:00+00' $$,
  'Future scheduled B is not selected for the preceding A week'
);

SELECT lives_ok(
  $$ SELECT private.activate_due_streak_rule(
       'cccccccc-cccc-cccc-cccc-cccccccccccc', '2026-03-16 04:00:00+00'
     ) $$,
  'Normal lifecycle activation succeeds at the exact weekly boundary'
);
SELECT results_eq(
  $$ SELECT status, target_days FROM public.member_streak_rules
     WHERE gym_member_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'
     ORDER BY starts_at $$,
  $$ VALUES
     ('ENDED'::public.member_streak_rule_status, 3::smallint),
     ('ACTIVE'::public.member_streak_rule_status, 4::smallint) $$,
  'Rule A ends and Rule B activates at the shared boundary'
);

-- After lifecycle advances, historical creation still resolves ENDED A.
SELECT private.ensure_streak_period(
  'cccccccc-cccc-cccc-cccc-cccccccccccc', '2026-03-09', '2026-03-21 12:00:00+00'
);
SELECT results_eq(
  $$ SELECT sp.member_streak_rule_id, sp.target_days_snapshot, sp.timezone_snapshot
     FROM public.streak_periods sp
     WHERE sp.gym_member_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'
       AND sp.period_start = '2026-03-09' $$,
  $$ SELECT msr.id, 3::smallint, 'America/New_York'::text
     FROM public.member_streak_rules msr
     WHERE msr.gym_member_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'
       AND msr.status = 'ENDED' $$,
  'Existing historical period remains bound to ENDED Rule A'
);
SELECT private.ensure_streak_period(
  'cccccccc-cccc-cccc-cccc-cccccccccccc', '2026-03-16', '2026-03-18 12:00:00+00'
);
SELECT results_eq(
  $$ SELECT sp.member_streak_rule_id, sp.target_days_snapshot, sp.timezone_snapshot,
            sp.status
     FROM public.streak_periods sp
     WHERE sp.gym_member_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'
       AND sp.period_start = '2026-03-16' $$,
  $$ SELECT msr.id, 4::smallint, 'America/New_York'::text,
            'OPEN'::public.streak_period_status
     FROM public.member_streak_rules msr
     WHERE msr.gym_member_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'
       AND msr.status = 'ACTIVE' $$,
  'Current period resolves active Rule B and remains OPEN'
);

CREATE TEMP TABLE period_snapshots AS
SELECT period_start, member_streak_rule_id, timezone_snapshot, target_days_snapshot
FROM public.streak_periods
WHERE gym_member_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc';
SELECT private.recalculate_member_streak(
  'cccccccc-cccc-cccc-cccc-cccccccccccc', '2026-03-02', '2026-03-18 12:00:00+00'
);
SELECT results_eq(
  $$ SELECT period_start, member_streak_rule_id, timezone_snapshot, target_days_snapshot
     FROM public.streak_periods
     WHERE gym_member_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'
     ORDER BY period_start $$,
  $$ SELECT * FROM period_snapshots ORDER BY period_start $$,
  'Replay never changes existing rule, timezone, or target snapshots'
);
SELECT results_eq(
  $$ SELECT transaction_type, amount FROM public.streak_freeze_transactions
     WHERE gym_member_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'
     ORDER BY created_at, id $$,
  $$ VALUES
     ('GRANT'::public.streak_freeze_transaction_type, 1::smallint),
     ('CONSUME'::public.streak_freeze_transaction_type, 1::smallint) $$,
  'Historical rule resolution preserves freeze replay behavior'
);
SELECT is(private.is_streak_period_eligible(
  '00000000-0000-0000-0000-000000000001',
  'cccccccc-cccc-cccc-cccc-cccccccccccc',
  '2026-03-09 04:00:00+00'
), true, 'Membership eligibility history remains authoritative during rule replay');

-- Partial initial weeks still snapshot their temporal assignment.
SELECT private.create_member_streak_rule_assignment(
  '00000000-0000-0000-0000-000000000001',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  '77000000-0000-0000-0000-000000000003',
  '2026-04-08 03:00:00+00',
  'ACTIVE',
  '11111111-1111-1111-1111-111111111111',
  TRUE
);
SELECT private.ensure_streak_period(
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '2026-04-06', '2026-04-10 03:00:00+00'
);
SELECT results_eq(
  $$ SELECT target_days_snapshot, timezone_snapshot, status
     FROM public.streak_periods
     WHERE gym_member_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
       AND period_start = '2026-04-06' $$,
  $$ VALUES (2::smallint, 'America/Montevideo'::text,
     'OPEN'::public.streak_period_status) $$,
  'Partial initial week keeps its temporal rule and stays OPEN before boundary'
);
SELECT private.recalculate_member_streak(
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '2026-04-06', '2026-04-13 03:00:00+00'
);
SELECT results_eq(
  $$ SELECT status, eligibility_reason FROM public.streak_periods
     WHERE gym_member_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
       AND period_start = '2026-04-06' $$,
  $$ VALUES ('NOT_ELIGIBLE'::public.streak_period_status,
     'PARTIAL_INITIAL_PERIOD'::public.streak_period_eligibility_reason) $$,
  'Partial initial week retains its existing terminal semantics'
);

-- Current uniqueness constraints do not exclude overlapping ENDED intervals.
INSERT INTO public.member_streaks (gym_id, gym_member_id)
VALUES ('00000000-0000-0000-0000-000000000001', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb');
INSERT INTO public.member_streak_rules (
  gym_id, gym_member_id, streak_rule_id, target_days, max_freezes,
  period_type, week_starts_on, timezone, starts_at, ends_at, status, assigned_by
) VALUES
  ('00000000-0000-0000-0000-000000000001', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
   '77000000-0000-0000-0000-000000000004', 5, 0, 'WEEK', 1,
   'America/Montevideo', '2026-05-01 03:00:00+00', '2026-05-20 03:00:00+00',
   'ENDED', '11111111-1111-1111-1111-111111111111'),
  ('00000000-0000-0000-0000-000000000001', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
   '77000000-0000-0000-0000-000000000004', 5, 0, 'WEEK', 1,
   'America/Montevideo', '2026-05-04 03:00:00+00', '2026-05-18 03:00:00+00',
   'ENDED', '11111111-1111-1111-1111-111111111111');
SELECT throws_ok(
  $$ SELECT (private.resolve_streak_rule_for_period(
       'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '2026-05-11'
     )).id $$,
  '23514', 'Ambiguous streak rule history for period',
  'Overlapping temporal rules fail explicitly instead of using LIMIT 1'
);

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';
SELECT throws_ok(
  $$ SELECT (private.resolve_streak_rule_for_period(
       'cccccccc-cccc-cccc-cccc-cccccccccccc', '2026-03-09'
     )).id $$,
  '42501', NULL, 'Authenticated clients cannot execute the private resolver'
);
SET LOCAL ROLE postgres;
RESET "request.jwt.claims";
SELECT is_empty(
  $$ SELECT p.proname FROM pg_proc p
     JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'private'
       AND p.proname = 'resolve_streak_rule_for_period'
       AND (has_function_privilege('public', p.oid, 'EXECUTE')
         OR NOT ('search_path=pg_catalog, public' = ANY(p.proconfig))) $$,
  'Private temporal resolver revokes PUBLIC execution and fixes search_path'
);

SELECT * FROM finish();
ROLLBACK;
