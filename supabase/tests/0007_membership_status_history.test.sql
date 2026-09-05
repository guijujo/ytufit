BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SELECT no_plan();
SET LOCAL ROLE postgres;
RESET "request.jwt.claims";
CREATE TEMP TABLE command_contracts (name TEXT PRIMARY KEY, id UUID, before_at TIMESTAMPTZ, after_at TIMESTAMPTZ);
GRANT ALL ON command_contracts TO authenticated;

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';
INSERT INTO command_contracts (name, before_at) VALUES ('first', clock_timestamp());
UPDATE command_contracts SET id = public.create_membership(
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '10000000-0000-0000-0000-000000000003',
  clock_timestamp() - interval '7 days'
), after_at = clock_timestamp() WHERE name = 'first';
SELECT results_eq(
  $$ SELECT h.from_status, h.to_status, h.changed_by, h.effective_at >= c.before_at AND h.effective_at <= c.after_at FROM public.membership_status_history h JOIN command_contracts c ON c.id = h.membership_id WHERE c.name = 'first' $$,
  $$ VALUES (NULL::public.membership_status, 'ACTIVE'::public.membership_status, '11111111-1111-1111-1111-111111111111'::uuid, true) $$,
  'Create command records exactly one initial ACTIVE event at creation, with actor'
);
SELECT ok((SELECT min(h.effective_at) > m.starts_at FROM public.membership_status_history h
  JOIN public.memberships m ON m.id = h.membership_id
  WHERE m.id = (SELECT id FROM command_contracts WHERE name = 'first') GROUP BY m.starts_at),
  'Backdated contract start does not backdate authoritative coverage');

SELECT public.suspend_membership((SELECT id FROM command_contracts WHERE name = 'first'));
SELECT throws_ok($$ SELECT public.suspend_membership((SELECT id FROM command_contracts WHERE name = 'first')) $$,
  '55000', 'Only an active membership can be suspended', 'Rejected duplicate suspension changes no business rule');
SELECT public.resume_membership((SELECT id FROM command_contracts WHERE name = 'first'));
SELECT public.cancel_membership((SELECT id FROM command_contracts WHERE name = 'first'), 'Command test cancellation');
SELECT results_eq(
  $$ SELECT from_status, to_status FROM public.membership_status_history WHERE membership_id = (SELECT id FROM command_contracts WHERE name = 'first') ORDER BY event_sequence $$,
  $$ VALUES (NULL::public.membership_status, 'ACTIVE'::public.membership_status), ('ACTIVE'::public.membership_status, 'SUSPENDED'::public.membership_status), ('SUSPENDED'::public.membership_status, 'ACTIVE'::public.membership_status), ('ACTIVE'::public.membership_status, 'CANCELLED'::public.membership_status) $$,
  'Create, suspend, resume and cancel append one coherent event per successful command'
);
SELECT results_eq(
  $$ SELECT h.effective_at = m.cancelled_at, h.reason, h.changed_by FROM public.membership_status_history h JOIN public.memberships m ON m.id = h.membership_id WHERE m.id = (SELECT id FROM command_contracts WHERE name = 'first') AND h.to_status = 'CANCELLED' $$,
  $$ VALUES (true, 'Command test cancellation'::text, '11111111-1111-1111-1111-111111111111'::uuid) $$,
  'Cancellation event uses the exact authoritative cancelled_at, reason and actor'
);

INSERT INTO command_contracts (name, id) VALUES ('suspended', public.create_membership(
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '10000000-0000-0000-0000-000000000003'
));
SELECT public.suspend_membership((SELECT id FROM command_contracts WHERE name = 'suspended'));
SELECT public.cancel_membership((SELECT id FROM command_contracts WHERE name = 'suspended'), 'Cancel suspended');
SELECT results_eq(
  $$ SELECT from_status, to_status FROM public.membership_status_history WHERE membership_id = (SELECT id FROM command_contracts WHERE name = 'suspended') ORDER BY event_sequence DESC LIMIT 1 $$,
  $$ VALUES ('SUSPENDED'::public.membership_status, 'CANCELLED'::public.membership_status) $$,
  'Cancellation preserves the actual SUSPENDED predecessor'
);

INSERT INTO command_contracts (name, id) VALUES ('old', public.create_membership(
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '10000000-0000-0000-0000-000000000003',
  clock_timestamp() - interval '60 days'
));
INSERT INTO command_contracts (name, id) VALUES ('renewed', public.renew_membership(
  (SELECT id FROM command_contracts WHERE name = 'old')
));
SELECT results_eq(
  $$ SELECT from_status, to_status FROM public.membership_status_history WHERE membership_id = (SELECT id FROM command_contracts WHERE name = 'old') ORDER BY event_sequence $$,
  $$ VALUES (NULL::public.membership_status, 'ACTIVE'::public.membership_status), ('ACTIVE'::public.membership_status, 'EXPIRED'::public.membership_status) $$,
  'Renewal records ACTIVE to EXPIRED normalization without erasing the initial state'
);
SELECT results_eq(
  $$ SELECT from_status, to_status FROM public.membership_status_history WHERE membership_id = (SELECT id FROM command_contracts WHERE name = 'renewed') $$,
  $$ VALUES (NULL::public.membership_status, 'ACTIVE'::public.membership_status) $$,
  'Renewal records the new contract initial ACTIVE event'
);
INSERT INTO command_contracts (name, id) VALUES ('changed', public.change_membership_plan(
  (SELECT id FROM command_contracts WHERE name = 'renewed'), '10000000-0000-0000-0000-000000000002', NULL, 'Plan replacement'
));
SELECT results_eq(
  $$ SELECT h.from_status, h.to_status, h.reason, h.effective_at = m.cancelled_at FROM public.membership_status_history h JOIN public.memberships m ON m.id = h.membership_id WHERE m.id = (SELECT id FROM command_contracts WHERE name = 'renewed') AND h.to_status = 'CANCELLED' $$,
  $$ VALUES ('ACTIVE'::public.membership_status, 'CANCELLED'::public.membership_status, 'Plan replacement'::text, true) $$,
  'Plan change records cancellation of the old contract with exact timestamp and reason'
);
SELECT results_eq(
  $$ SELECT from_status, to_status FROM public.membership_status_history WHERE membership_id = (SELECT id FROM command_contracts WHERE name = 'changed') $$,
  $$ VALUES (NULL::public.membership_status, 'ACTIVE'::public.membership_status) $$,
  'Plan change records the replacement initial ACTIVE event'
);
SELECT public.cancel_membership((SELECT id FROM command_contracts WHERE name = 'changed'), 'Next fixture');
INSERT INTO command_contracts (name, id) VALUES ('normalize_old', public.create_membership(
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '10000000-0000-0000-0000-000000000003', clock_timestamp() - interval '60 days'
));
INSERT INTO command_contracts (name, id) VALUES ('normalize_new', public.create_membership(
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '10000000-0000-0000-0000-000000000003'
));
SELECT results_eq(
  $$ SELECT from_status, to_status FROM public.membership_status_history WHERE membership_id = (SELECT id FROM command_contracts WHERE name = 'normalize_old') ORDER BY event_sequence $$,
  $$ VALUES (NULL::public.membership_status, 'ACTIVE'::public.membership_status), ('ACTIVE'::public.membership_status, 'EXPIRED'::public.membership_status) $$,
  'Create normalizes the previous expired ACTIVE contract and records the transition'
);
SELECT public.cancel_membership((SELECT id FROM command_contracts WHERE name = 'normalize_new'), 'Next fixture');
INSERT INTO command_contracts (name, id) VALUES ('expired_suspended', public.create_membership(
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '10000000-0000-0000-0000-000000000003', clock_timestamp() - interval '60 days'
));
SELECT public.suspend_membership((SELECT id FROM command_contracts WHERE name = 'expired_suspended'));
SELECT throws_ok($$ SELECT public.resume_membership((SELECT id FROM command_contracts WHERE name = 'expired_suspended')) $$,
  '55000', 'Suspended membership has expired and must be renewed', 'Expired suspension still cannot be resumed');
SELECT results_eq(
  $$ SELECT from_status, to_status FROM public.membership_status_history WHERE membership_id = (SELECT id FROM command_contracts WHERE name = 'expired_suspended') ORDER BY event_sequence $$,
  $$ VALUES (NULL::public.membership_status, 'ACTIVE'::public.membership_status), ('ACTIVE'::public.membership_status, 'SUSPENDED'::public.membership_status) $$,
  'Failed resume rolls back both attempted normalization and its history event'
);
SELECT results_eq(
  $$ SELECT status FROM public.memberships WHERE id = (SELECT id FROM command_contracts WHERE name = 'expired_suspended') $$,
  $$ VALUES ('SUSPENDED'::public.membership_status) $$,
  'Failed resume preserves existing Membership rollback semantics'
);
SELECT is_empty(
  $$ SELECT h.id FROM public.membership_status_history h JOIN command_contracts c ON c.id = h.membership_id WHERE h.changed_by IS DISTINCT FROM '11111111-1111-1111-1111-111111111111'::uuid $$,
  'All successful command events retain the authenticated actor'
);
SET LOCAL ROLE postgres;
RESET "request.jwt.claims";
SELECT is_empty(
  $$ SELECT id FROM (SELECT h.id, h.effective_at, lag(h.effective_at) OVER (PARTITION BY h.membership_id ORDER BY h.event_sequence) AS previous_at FROM public.membership_status_history h JOIN command_contracts c ON c.id = h.membership_id) history WHERE effective_at < previous_at $$,
  'Command event times are chronological within each contract'
);
SELECT throws_ok(
  $$ SELECT private.is_streak_period_eligible('00000000-0000-0000-0000-000000000001', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', (SELECT starts_at FROM public.memberships WHERE id = (SELECT id FROM command_contracts WHERE name = 'first'))) $$,
  '55000', 'Insufficient membership status history', 'A backdated creation cannot fabricate pre-creation status coverage'
);

-- Real later commands preserve a past Monday backed by explicit seed history.
SELECT is(private.is_streak_period_eligible('00000000-0000-0000-0000-000000000001',
  'cccccccc-cccc-cccc-cccc-cccccccccccc', '2026-08-03 03:00:00+00'), true, 'Seed Monday is initially eligible');
SET LOCAL "request.jwt.claims" = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';
SELECT public.suspend_membership('30000000-0000-0000-0000-000000000001');
SELECT is(private.is_streak_period_eligible('00000000-0000-0000-0000-000000000001',
  'cccccccc-cccc-cccc-cccc-cccccccccccc', '2026-08-03 03:00:00+00'), true, 'Later suspend command cannot invalidate past Monday');
SELECT public.cancel_membership('30000000-0000-0000-0000-000000000001', 'Later cancellation');
SELECT is(private.is_streak_period_eligible('00000000-0000-0000-0000-000000000001',
  'cccccccc-cccc-cccc-cccc-cccccccccccc', '2026-08-03 03:00:00+00'), true, 'Later cancel command cannot invalidate past Monday');
SELECT * FROM finish();
ROLLBACK;
