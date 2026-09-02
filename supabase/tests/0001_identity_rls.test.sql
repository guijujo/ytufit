-- pgTAP Security and RLS Tests for YtuFit v2.0.1
-- File: supabase/tests/0001_identity_rls.test.sql

BEGIN;

-- 1. Install pgTAP if not present and declare plan
CREATE EXTENSION IF NOT EXISTS pgtap;

SELECT plan(13);

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

SELECT * FROM finish();
ROLLBACK;
