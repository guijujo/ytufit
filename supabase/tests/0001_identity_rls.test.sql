-- pgTAP Security and RLS Tests for YtuFit v2.0.1
-- File: supabase/tests/0001_identity_rls.test.sql

BEGIN;

-- 1. Install pgTAP if not present and declare plan
CREATE EXTENSION IF NOT EXISTS pgtap;

SELECT plan(26);

-- Test 1: Member A can read their own profile
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "33333333-3333-3333-3333-333333333333", "role": "authenticated", "email": "member-a@ytufit.local"}';

SELECT results_eq(
  $$ SELECT id, first_name, last_name FROM public.profiles WHERE id = '33333333-3333-3333-3333-333333333333' $$,
  $$ VALUES ('33333333-3333-3333-3333-333333333333'::uuid, 'Member'::text, 'Alpha'::text) $$,
  'Member A can read their own profile'
);

-- Test 2: Member A cannot read private profile of Member B (negative test)
SELECT is_empty(
  $$ SELECT * FROM public.profiles WHERE id = '55555555-5555-5555-5555-555555555555' $$,
  'Member A cannot read private profile of Member B'
);

-- Test 3: Member A can access permitted context of Gym A
SELECT results_eq(
  $$ SELECT id, name, slug FROM public.gyms WHERE id = '00000000-0000-0000-0000-000000000001' $$,
  $$ VALUES ('00000000-0000-0000-0000-000000000001'::uuid, 'Gym Alpha'::text, 'gym-alpha'::text) $$,
  'Member A can access permitted context of Gym A'
);

-- Test 4: Member A cannot access Gym B (cross-tenant negative test)
SELECT is_empty(
  $$ SELECT * FROM public.gyms WHERE id = '00000000-0000-0000-0000-000000000002' $$,
  'Member A cannot access Gym B'
);

-- Test 5: Admin A can access all members of Gym A
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated", "email": "admin-a@ytufit.local"}';

SELECT results_eq(
  $$ SELECT user_id FROM public.gym_members WHERE gym_id = '00000000-0000-0000-0000-000000000001' ORDER BY user_id $$,
  $$ VALUES
      ('11111111-1111-1111-1111-111111111111'::uuid),
      ('22222222-2222-2222-2222-222222222222'::uuid),
      ('33333333-3333-3333-3333-333333333333'::uuid)
  $$,
  'Admin A can access members of Gym A'
);

-- Test 6: Admin A cannot access members of Gym B (cross-tenant negative test)
SELECT is_empty(
  $$ SELECT * FROM public.gym_members WHERE gym_id = '00000000-0000-0000-0000-000000000002' $$,
  'Admin A cannot access members of Gym B'
);

-- Test 7: Trainer A does not obtain permissions of Admin A (negative test)
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "22222222-2222-2222-2222-222222222222", "role": "authenticated", "email": "trainer-a@ytufit.local"}';

SELECT results_eq(
  $$ SELECT user_id FROM public.gym_members WHERE gym_id = '00000000-0000-0000-0000-000000000001' $$,
  $$ VALUES ('22222222-2222-2222-2222-222222222222'::uuid) $$,
  'Trainer A only sees own membership and does not obtain admin privileges'
);

-- Test 8: Member A cannot self-assign GYM_ADMIN (escalation negative test)
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "33333333-3333-3333-3333-333333333333", "role": "authenticated", "email": "member-a@ytufit.local"}';

SELECT throws_ok(
  $$
    INSERT INTO public.gym_member_roles (gym_member_id, role_id)
    SELECT 'cccccccc-cccc-cccc-cccc-cccccccccccc', r.id
    FROM public.roles r WHERE r.name = 'GYM_ADMIN';
  $$,
  '42501',
  NULL,
  'Member A cannot self-assign GYM_ADMIN'
);

-- Test 9: Anonymous user cannot read tenant data (negative tests)
SET LOCAL ROLE anon;
RESET "request.jwt.claims";

SELECT is_empty(
  $$ SELECT * FROM public.gyms $$,
  'Anonymous user cannot read gyms'
);

SELECT is_empty(
  $$ SELECT * FROM public.gym_members $$,
  'Anonymous user cannot read gym_members'
);

SELECT is_empty(
  $$ SELECT * FROM public.profiles $$,
  'Anonymous user cannot read profiles'
);

-- Test 10: Regular user cannot insert into platform_admins (escalation negative test)
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "33333333-3333-3333-3333-333333333333", "role": "authenticated", "email": "member-a@ytufit.local"}';

SELECT throws_ok(
  $$
    INSERT INTO public.platform_admins (user_id)
    VALUES ('33333333-3333-3333-3333-333333333333');
  $$,
  '42501',
  NULL,
  'Regular user cannot insert themselves into platform_admins'
);

-- Test 11: Duplicate PENDING join request rejected by partial unique index
SET LOCAL ROLE postgres;
RESET "request.jwt.claims";

INSERT INTO public.gym_join_requests (gym_id, user_id, status)
VALUES ('00000000-0000-0000-0000-000000000001', '33333333-3333-3333-3333-333333333333', 'PENDING');

SELECT throws_ok(
  $$
    INSERT INTO public.gym_join_requests (gym_id, user_id, status)
    VALUES ('00000000-0000-0000-0000-000000000001', '33333333-3333-3333-3333-333333333333', 'PENDING');
  $$,
  '23505',
  NULL,
  'Cannot create multiple simultaneous PENDING join requests for same gym and user'
);

-- Fixtures for transition and cross-tenant tests
INSERT INTO public.gym_join_requests (id, gym_id, user_id, status)
VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaa01', '00000000-0000-0000-0000-000000000002', '55555555-5555-5555-5555-555555555555', 'PENDING')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.gym_invitations (
  id, gym_id, email, role_id, invited_by, token_hash, status, expires_at
)
SELECT
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaa02',
  '00000000-0000-0000-0000-000000000001',
  'member-a@ytufit.local',
  r.id,
  '11111111-1111-1111-1111-111111111111',
  'deterministic-token-hash',
  'PENDING',
  now() + interval '1 day'
FROM public.roles r
WHERE r.name = 'MEMBER'
ON CONFLICT (id) DO NOTHING;

-- Test 12: Admin A cannot modify a request from Gym B
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';
UPDATE public.gym_join_requests
SET status = 'APPROVED'
WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaa01';
SET LOCAL ROLE postgres;
SELECT results_eq(
  $$ SELECT status FROM public.gym_join_requests WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaa01' $$,
  $$ VALUES ('PENDING'::text) $$,
  'Admin A cannot modify a join request from Gym B'
);

-- Test 13: Admin A cannot change join request ownership fields
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';
UPDATE public.gym_join_requests
SET user_id = '55555555-5555-5555-5555-555555555555'
WHERE gym_id = '00000000-0000-0000-0000-000000000001'
  AND user_id = '33333333-3333-3333-3333-333333333333'
  AND status = 'PENDING';
SET LOCAL ROLE postgres;
SELECT results_eq(
  $$ SELECT user_id FROM public.gym_join_requests WHERE gym_id = '00000000-0000-0000-0000-000000000001' AND user_id = '33333333-3333-3333-3333-333333333333' AND status = 'PENDING' $$,
  $$ VALUES ('33333333-3333-3333-3333-333333333333'::uuid) $$,
  'Admin A cannot change join request user_id'
);

-- Test 14: Admin A cannot change a join request gym_id
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';
UPDATE public.gym_join_requests
SET gym_id = '00000000-0000-0000-0000-000000000002'
WHERE gym_id = '00000000-0000-0000-0000-000000000001'
  AND user_id = '33333333-3333-3333-3333-333333333333'
  AND status = 'PENDING';
SET LOCAL ROLE postgres;
SELECT is(
  (SELECT gym_id::text FROM public.gym_join_requests WHERE user_id = '33333333-3333-3333-3333-333333333333' AND status = 'PENDING'),
  '00000000-0000-0000-0000-000000000001',
  'Admin A cannot change join request gym_id'
);

-- Test 15: Member cannot approve their own request
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "33333333-3333-3333-3333-333333333333", "role": "authenticated"}';
SELECT throws_ok(
  $$ UPDATE public.gym_join_requests
     SET status = 'APPROVED'
     WHERE gym_id = '00000000-0000-0000-0000-000000000001'
       AND user_id = '33333333-3333-3333-3333-333333333333'
       AND status = 'PENDING' $$,
  NULL, NULL, 'Member cannot approve their own join request'
);
SET LOCAL ROLE postgres;
SELECT is(
  (SELECT status FROM public.gym_join_requests WHERE user_id = '33333333-3333-3333-3333-333333333333' AND status = 'PENDING'),
  'PENDING',
  'Member cannot approve their own join request'
);

-- Test 16: Trainer cannot approve requests
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "22222222-2222-2222-2222-222222222222", "role": "authenticated"}';
UPDATE public.gym_join_requests
SET status = 'APPROVED'
WHERE gym_id = '00000000-0000-0000-0000-000000000001'
  AND user_id = '33333333-3333-3333-3333-333333333333'
  AND status = 'PENDING';
SET LOCAL ROLE postgres;
SELECT is(
  (SELECT status FROM public.gym_join_requests WHERE user_id = '33333333-3333-3333-3333-333333333333' AND status = 'PENDING'),
  'PENDING',
  'Trainer cannot approve join requests'
);

-- Test 17: Member cannot modify role assignments
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "33333333-3333-3333-3333-333333333333", "role": "authenticated"}';
SELECT throws_ok(
  $$ INSERT INTO public.gym_member_roles (gym_member_id, role_id)
     SELECT 'cccccccc-cccc-cccc-cccc-cccccccccccc', id FROM public.roles WHERE name = 'GYM_ADMIN' $$,
  '42501', NULL, 'Member cannot modify role assignments'
);

-- Test 18: Admin A cannot assign roles to Gym B
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';
SELECT throws_ok(
  $$ INSERT INTO public.gym_member_roles (gym_member_id, role_id)
     SELECT 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', id FROM public.roles WHERE name = 'GYM_ADMIN' $$,
  '42501', NULL, 'Admin A cannot assign roles to Gym B'
);

-- Test 19: An invitation from Gym A cannot create a Gym B membership
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "33333333-3333-3333-3333-333333333333", "role": "authenticated", "email": "member-a@ytufit.local"}';
SELECT throws_ok(
  $$ INSERT INTO public.gym_members (gym_id, user_id, status)
     VALUES ('00000000-0000-0000-0000-000000000002', '33333333-3333-3333-3333-333333333333', 'ACTIVE') $$,
  '42501', NULL, 'Invitation from Gym A cannot create a Gym B membership'
);

-- Test 20: Invited user cannot alter invitation role_id
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "33333333-3333-3333-3333-333333333333", "role": "authenticated", "email": "member-a@ytufit.local"}';
UPDATE public.gym_invitations
SET role_id = (SELECT id FROM public.roles WHERE name = 'GYM_ADMIN')
WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaa02';
SET LOCAL ROLE postgres;
SELECT is(
  (SELECT r.name FROM public.gym_invitations i JOIN public.roles r ON r.id = i.role_id WHERE i.id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaa02'),
  'MEMBER',
  'Invited user cannot alter invitation role_id'
);

-- Test 21: Invited user cannot alter invitation token_hash
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "33333333-3333-3333-3333-333333333333", "role": "authenticated", "email": "member-a@ytufit.local"}';
UPDATE public.gym_invitations
SET token_hash = 'tampered'
WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaa02';
SET LOCAL ROLE postgres;
SELECT is(
  (SELECT token_hash FROM public.gym_invitations WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaa02'),
  'deterministic-token-hash',
  'Invited user cannot alter invitation token_hash'
);

-- Test 22: Client cannot transition PENDING to an arbitrary state
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "33333333-3333-3333-3333-333333333333", "role": "authenticated"}';
SELECT throws_ok(
  $$ UPDATE public.gym_join_requests
     SET status = 'REJECTED'
     WHERE gym_id = '00000000-0000-0000-0000-000000000001'
       AND user_id = '33333333-3333-3333-3333-333333333333'
       AND status = 'PENDING' $$,
  NULL, NULL, 'Client cannot transition PENDING to an arbitrary state'
);
SET LOCAL ROLE postgres;
SELECT is(
  (SELECT status FROM public.gym_join_requests WHERE user_id = '33333333-3333-3333-3333-333333333333' AND status = 'PENDING'),
  'PENDING',
  'Client cannot transition PENDING to an arbitrary state'
);

SELECT * FROM finish();
ROLLBACK;
