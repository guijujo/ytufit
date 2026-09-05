BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SELECT no_plan();
SET LOCAL ROLE postgres;
RESET "request.jwt.claims";

-- Explicit, coherent synthetic history; never infer past status from a row.
-- Each case uses a disjoint contract interval for the same test member.
CREATE FUNCTION pg_temp.history_fixture(
  p_case INTEGER, p_start TIMESTAMPTZ, p_end TIMESTAMPTZ,
  p_statuses public.membership_status[], p_times TIMESTAMPTZ[]
) RETURNS UUID LANGUAGE plpgsql AS $$
DECLARE v_id UUID; v_i INTEGER; v_last INTEGER := array_length(p_statuses, 1);
BEGIN
  INSERT INTO public.memberships (
    gym_id, gym_member_id, membership_plan_id, status, starts_at, ends_at,
    contracted_price, currency, access_type_snapshot, cancelled_at, cancellation_reason
  ) VALUES (
    '00000000-0000-0000-0000-000000000001', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    '10000000-0000-0000-0000-000000000003', p_statuses[v_last], p_start, p_end,
    45000, 'ARS', 'UNLIMITED',
    CASE WHEN p_statuses[v_last] = 'CANCELLED' THEN p_times[v_last] END,
    CASE WHEN p_statuses[v_last] = 'CANCELLED' THEN 'Fixture cancellation' END
  ) RETURNING id INTO v_id;
  FOR v_i IN 1..v_last LOOP
    INSERT INTO public.membership_status_history (
      gym_id, membership_id, from_status, to_status, effective_at, reason
    ) VALUES (
      '00000000-0000-0000-0000-000000000001', v_id,
      CASE WHEN v_i > 1 THEN p_statuses[v_i - 1] END,
      p_statuses[v_i], p_times[v_i], 'Authoritative test fixture'
    );
  END LOOP;
  RETURN v_id;
END;
$$;

CREATE TEMP TABLE history_cases (
  case_no INTEGER PRIMARY KEY, monday TIMESTAMPTZ, expected BOOLEAN,
  description TEXT, membership_id UUID
);
INSERT INTO history_cases (case_no, monday, expected, description) VALUES
  (1, '2025-01-06 03:00:00+00', true, 'ACTIVE Monday, suspended Wednesday stays eligible'),
  (2, '2025-01-20 03:00:00+00', true, 'ACTIVE Monday, cancelled Thursday stays eligible'),
  (3, '2025-02-03 03:00:00+00', false, 'Suspended Sunday is not eligible Monday'),
  (4, '2025-02-17 03:00:00+00', true, 'Suspended Sunday and resumed before Monday is eligible'),
  (5, '2025-03-03 03:00:00+00', false, 'Suspension exactly Monday is already in effect'),
  (6, '2025-03-17 03:00:00+00', true, 'Suspension one second after Monday preserves eligibility'),
  (7, '2025-03-31 03:00:00+00', true, 'Expiration Wednesday preserves Monday eligibility'),
  (8, '2025-04-14 03:00:00+00', false, 'Contract ended before Monday is not eligible'),
  (9, '2025-04-28 03:00:00+00', false, 'Contract ending exactly Monday is not eligible'),
  (10, '2025-05-12 03:00:00+00', false, 'Contract starting after Monday is not eligible'),
  (11, '2025-05-26 03:00:00+00', true, 'Equal-time resume follows suspension in ledger sequence');

UPDATE history_cases SET membership_id = pg_temp.history_fixture(
  case_no,
  CASE WHEN case_no = 10 THEN monday + interval '1 second' ELSE monday - interval '7 days' END,
  CASE WHEN case_no = 7 THEN monday + interval '2 days'
       WHEN case_no = 8 THEN monday - interval '1 second'
       WHEN case_no = 9 THEN monday ELSE monday + interval '7 days' END,
  CASE WHEN case_no IN (4, 11) THEN ARRAY['ACTIVE', 'SUSPENDED', 'ACTIVE', 'CANCELLED']::public.membership_status[]
       WHEN case_no IN (7, 8, 9) THEN ARRAY['ACTIVE', 'EXPIRED']::public.membership_status[]
       WHEN case_no IN (2, 10) THEN ARRAY['ACTIVE', 'CANCELLED']::public.membership_status[]
       ELSE ARRAY['ACTIVE', 'SUSPENDED']::public.membership_status[] END,
  CASE WHEN case_no = 4 THEN ARRAY[monday - interval '7 days', monday - interval '1 day', monday - interval '1 second', monday + interval '3 days']
       WHEN case_no = 11 THEN ARRAY[monday - interval '7 days', monday, monday, monday + interval '3 days']
       ELSE ARRAY[
         CASE WHEN case_no = 10 THEN monday + interval '1 second' ELSE monday - interval '7 days' END,
         CASE WHEN case_no IN (1, 7) THEN monday + interval '2 days'
              WHEN case_no IN (2, 10) THEN monday + interval '3 days'
              WHEN case_no = 3 THEN monday - interval '1 day'
              WHEN case_no IN (5, 9) THEN monday
              WHEN case_no = 6 THEN monday + interval '1 second'
              WHEN case_no = 8 THEN monday - interval '1 second' END] END
);

SELECT is(private.is_streak_period_eligible(
  '00000000-0000-0000-0000-000000000001', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', monday
), expected, description) FROM history_cases ORDER BY case_no;

INSERT INTO public.streak_rules (id, gym_id, name, target_days, max_freezes, timezone, created_by)
VALUES ('76000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001',
  'History rule', 1, 0, 'America/Montevideo', '11111111-1111-1111-1111-111111111111');
SELECT private.create_member_streak_rule_assignment(
  '00000000-0000-0000-0000-000000000001', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  '76000000-0000-0000-0000-000000000001', '2024-01-01 03:00:00+00', 'ACTIVE',
  '11111111-1111-1111-1111-111111111111', TRUE
);
SELECT private.ensure_streak_period('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  (monday AT TIME ZONE 'America/Montevideo')::date, monday + interval '7 days')
FROM history_cases ORDER BY case_no;
SELECT private.recalculate_member_streak('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', NULL, '2025-06-02 03:00:00+00');
SELECT is(sp.status, CASE WHEN c.expected THEN 'MISSED' ELSE 'NOT_ELIGIBLE' END::public.streak_period_status,
  'Engine terminal status: ' || c.description)
FROM history_cases c JOIN public.streak_periods sp ON sp.period_start_at = c.monday
WHERE sp.gym_member_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' ORDER BY c.case_no;

-- Later authoritative changes must not invalidate already-evaluated weeks.
CREATE TEMP TABLE replay_before AS
SELECT period_start, status, eligibility_reason, valid_days, freeze_applied, finalized_at
FROM public.streak_periods WHERE gym_member_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
SET LOCAL "request.jwt.claims" = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';
SELECT public.cancel_membership((SELECT membership_id FROM history_cases WHERE case_no = 1), 'Later cancellation');
RESET "request.jwt.claims";
SELECT private.recalculate_member_streak('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', NULL, '2026-09-01 03:00:00+00');
SELECT results_eq(
  $$ SELECT period_start, status, eligibility_reason, valid_days, freeze_applied, finalized_at FROM public.streak_periods WHERE gym_member_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' ORDER BY period_start $$,
  $$ SELECT * FROM replay_before ORDER BY period_start $$,
  'Historical replay after a later command preserves all earlier eligibility and finalization'
);

-- A migration-style baseline explicitly has no knowledge before its timestamp.
SELECT pg_temp.history_fixture(12, '2025-06-09 03:00:00+00', '2025-07-01 03:00:00+00',
  ARRAY['SUSPENDED']::public.membership_status[], ARRAY['2025-06-18 03:00:00+00'::timestamptz]);
SELECT throws_ok(
  $$ SELECT private.is_streak_period_eligible('00000000-0000-0000-0000-000000000001', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '2025-06-16 03:00:00+00') $$,
  '55000', 'Insufficient membership status history', 'Baseline never implies knowledge of a prior Monday'
);
SELECT is(private.is_streak_period_eligible('00000000-0000-0000-0000-000000000001',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '2025-06-18 03:00:00+00'), false,
  'Coverage starts inclusively at the first authoritative event');
SELECT lives_ok(
  $$ SELECT private.ensure_streak_period('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '2025-06-16', '2025-06-17 03:00:00+00') $$,
  'Unclosed week remains OPEN without premature eligibility evaluation'
);
SELECT throws_ok(
  $$ SELECT private.recalculate_member_streak('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '2025-06-16', '2025-06-23 03:00:00+00') $$,
  '55000', 'Insufficient membership status history', 'Reconciliation rejects unknown history at the end boundary'
);
SELECT results_eq(
  $$ SELECT status, eligibility_reason, finalized_at FROM public.streak_periods WHERE gym_member_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' AND period_start = '2025-06-16' $$,
  $$ VALUES ('OPEN'::public.streak_period_status, NULL::public.streak_period_eligibility_reason, NULL::timestamptz) $$,
  'Failed reconciliation does not turn unknown into NOT_ELIGIBLE'
);
SELECT throws_ok(
  $$ SELECT private.ensure_streak_period('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '2025-06-09', '2025-06-16 03:00:00+00') $$,
  '55000', 'Insufficient membership status history', 'Ensuring a closed week also rejects insufficient history'
);

-- Known ACTIVE coverage must not mask another candidate's unknown history.
SELECT pg_temp.history_fixture(13, '2025-06-09 03:00:00+00', '2025-07-01 03:00:00+00',
  ARRAY['ACTIVE']::public.membership_status[], ARRAY['2025-06-09 03:00:00+00'::timestamptz]);
SELECT throws_ok(
  $$ SELECT private.is_streak_period_eligible('00000000-0000-0000-0000-000000000001', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '2025-06-16 03:00:00+00') $$,
  '55000', 'Insufficient membership status history', 'Known active contract does not hide an uncovered candidate'
);
INSERT INTO public.memberships (
  gym_id, gym_member_id, membership_plan_id, status, starts_at, ends_at,
  contracted_price, currency, access_type_snapshot
) VALUES (
  '00000000-0000-0000-0000-000000000001', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  '10000000-0000-0000-0000-000000000003', 'EXPIRED', '2025-07-07 03:00:00+00',
  '2025-07-21 03:00:00+00', 45000, 'ARS', 'UNLIMITED'
);
SELECT throws_ok(
  $$ SELECT private.is_streak_period_eligible('00000000-0000-0000-0000-000000000001', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '2025-07-14 03:00:00+00') $$,
  '55000', 'Insufficient membership status history', 'An empty ledger cannot use current EXPIRED status as historical truth'
);

SELECT throws_ok(
  $$ INSERT INTO public.membership_status_history (gym_id, membership_id, to_status, effective_at) VALUES ('00000000-0000-0000-0000-000000000002', (SELECT membership_id FROM history_cases WHERE case_no = 1), 'ACTIVE', now()) $$,
  '23503', NULL, 'Composite FK rejects a cross-tenant history reference'
);
SELECT throws_ok($$ UPDATE public.membership_status_history SET effective_at = effective_at - interval '1 day' $$,
  '55000', 'Membership status history is immutable', 'Even privileged UPDATE cannot rewrite history');
SELECT throws_ok($$ DELETE FROM public.membership_status_history $$,
  '55000', 'Membership status history is immutable', 'Even privileged DELETE cannot erase history');
SELECT throws_ok($$ TRUNCATE public.membership_status_history $$,
  '55000', 'Membership status history is immutable', 'TRUNCATE cannot erase history');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}';
SELECT results_eq($$ SELECT count(*)::integer FROM public.membership_status_history WHERE membership_id = '30000000-0000-0000-0000-000000000001' $$,
  $$ VALUES (1) $$, 'Member reads own Membership history');
SELECT is_empty($$ SELECT * FROM public.membership_status_history WHERE gym_id = '00000000-0000-0000-0000-000000000002' $$,
  'Member cannot read cross-tenant history');
SELECT throws_ok($$ INSERT INTO public.membership_status_history (gym_id, membership_id, to_status, effective_at) VALUES ('00000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', 'ACTIVE', now()) $$,
  '42501', NULL, 'Member cannot forge history');
SELECT throws_ok($$ UPDATE public.membership_status_history SET to_status = 'ACTIVE' $$, '42501', NULL, 'Member cannot update history');
SELECT throws_ok($$ DELETE FROM public.membership_status_history $$, '42501', NULL, 'Member cannot delete history');
SELECT throws_ok($$ SELECT private.record_membership_status('30000000-0000-0000-0000-000000000001', 'ACTIVE', 'SUSPENDED') $$,
  '42501', NULL, 'Member cannot call the internal recorder');
SET LOCAL "request.jwt.claims" = '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';
SELECT is_empty($$ SELECT * FROM public.membership_status_history $$, 'Trainer has no extra Membership history visibility');
SELECT throws_ok($$ INSERT INTO public.membership_status_history (gym_id, membership_id, to_status, effective_at) VALUES ('00000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', 'ACTIVE', now()) $$,
  '42501', NULL, 'Trainer cannot forge history');
SELECT throws_ok($$ UPDATE public.membership_status_history SET to_status = 'ACTIVE' $$, '42501', NULL, 'Trainer cannot update history');
SELECT throws_ok($$ DELETE FROM public.membership_status_history $$, '42501', NULL, 'Trainer cannot delete history');
SET LOCAL "request.jwt.claims" = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';
SELECT is_empty($$ SELECT * FROM public.membership_status_history WHERE gym_id = '00000000-0000-0000-0000-000000000002' $$,
  'Gym Admin cannot read another tenant history');
SELECT throws_ok($$ INSERT INTO public.membership_status_history (gym_id, membership_id, to_status, effective_at) VALUES ('00000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', 'ACTIVE', now()) $$,
  '42501', NULL, 'Gym Admin must use commands rather than direct history INSERT');
SET LOCAL "request.jwt.claims" = '{"sub":"99999999-9999-9999-9999-999999999999","role":"authenticated"}';
SELECT ok((SELECT count(*) > 0 FROM public.membership_status_history WHERE gym_id = '00000000-0000-0000-0000-000000000002'),
  'Platform Admin retains existing Membership read behavior');
SELECT is_empty($$ SELECT * FROM public.streak_periods $$, 'Membership visibility grants no implicit Platform Admin Streak access');
SELECT throws_ok($$ SELECT private.is_streak_period_eligible('00000000-0000-0000-0000-000000000001', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', now()) $$,
  '42501', NULL, 'Platform Admin cannot execute private Streak eligibility');
SET LOCAL ROLE anon;
RESET "request.jwt.claims";
SELECT throws_ok($$ SELECT * FROM public.membership_status_history $$, '42501', NULL, 'Anon has no history read grant');
SET LOCAL ROLE service_role;
SELECT throws_ok($$ INSERT INTO public.membership_status_history (gym_id, membership_id, to_status, effective_at) VALUES ('00000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', 'ACTIVE', now()) $$,
  '42501', NULL, 'Service role also writes history only via Membership commands');
SET LOCAL ROLE postgres;
SELECT is_empty(
  $$ SELECT p.proname FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = 'private' AND p.proname IN ('record_membership_status', 'reject_membership_status_history_mutation', 'is_streak_period_eligible') AND (has_function_privilege('public', p.oid, 'EXECUTE') OR NOT ('search_path=pg_catalog, public' = ANY(p.proconfig))) $$,
  'History helpers revoke PUBLIC execution and fix search_path'
);
SELECT * FROM finish();
ROLLBACK;
