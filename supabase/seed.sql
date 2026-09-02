-- Deterministic seed fixtures for testing and local development
-- YtuFit v2.0.1: Multi-tenant identity fixtures

-- 1. Deterministic test auth users
INSERT INTO auth.users (
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at
) VALUES
  ('11111111-1111-1111-1111-111111111111', 'authenticated', 'authenticated', 'admin-a@ytufit.local', crypt('Password123!', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"first_name":"Admin","last_name":"Alpha"}', now(), now()),
  ('22222222-2222-2222-2222-222222222222', 'authenticated', 'authenticated', 'trainer-a@ytufit.local', crypt('Password123!', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"first_name":"Trainer","last_name":"Alpha"}', now(), now()),
  ('33333333-3333-3333-3333-333333333333', 'authenticated', 'authenticated', 'member-a@ytufit.local', crypt('Password123!', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"first_name":"Member","last_name":"Alpha"}', now(), now()),
  ('44444444-4444-4444-4444-444444444444', 'authenticated', 'authenticated', 'admin-b@ytufit.local', crypt('Password123!', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"first_name":"Admin","last_name":"Beta"}', now(), now()),
  ('55555555-5555-5555-5555-555555555555', 'authenticated', 'authenticated', 'member-b@ytufit.local', crypt('Password123!', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"first_name":"Member","last_name":"Beta"}', now(), now()),
  ('99999999-9999-9999-9999-999999999999', 'authenticated', 'authenticated', 'platform-admin@ytufit.local', crypt('Password123!', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"first_name":"Platform","last_name":"SuperAdmin"}', now(), now())
ON CONFLICT (id) DO NOTHING;

-- 2. Ensure profiles exist with expected metadata
INSERT INTO public.profiles (id, first_name, last_name, status) VALUES
  ('11111111-1111-1111-1111-111111111111', 'Admin', 'Alpha', 'ACTIVE'),
  ('22222222-2222-2222-2222-222222222222', 'Trainer', 'Alpha', 'ACTIVE'),
  ('33333333-3333-3333-3333-333333333333', 'Member', 'Alpha', 'ACTIVE'),
  ('44444444-4444-4444-4444-444444444444', 'Admin', 'Beta', 'ACTIVE'),
  ('55555555-5555-5555-5555-555555555555', 'Member', 'Beta', 'ACTIVE'),
  ('99999999-9999-9999-9999-999999999999', 'Platform', 'SuperAdmin', 'ACTIVE')
ON CONFLICT (id) DO UPDATE SET
  first_name = EXCLUDED.first_name,
  last_name = EXCLUDED.last_name,
  status = EXCLUDED.status;

-- 3. Gyms (Gym A and Gym B)
INSERT INTO public.gyms (id, name, slug, status, timezone) VALUES
  ('00000000-0000-0000-0000-000000000001', 'Gym Alpha', 'gym-alpha', 'ACTIVE', 'America/Montevideo'),
  ('00000000-0000-0000-0000-000000000002', 'Gym Beta', 'gym-beta', 'ACTIVE', 'America/Montevideo')
ON CONFLICT (id) DO NOTHING;

-- 4. Platform Admins
INSERT INTO public.platform_admins (user_id) VALUES
  ('99999999-9999-9999-9999-999999999999')
ON CONFLICT (user_id) DO NOTHING;

-- 5. Gym Members
INSERT INTO public.gym_members (id, gym_id, user_id, status) VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '00000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'ACTIVE'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '00000000-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', 'ACTIVE'),
  ('cccccccc-cccc-cccc-cccc-cccccccccccc', '00000000-0000-0000-0000-000000000001', '33333333-3333-3333-3333-333333333333', 'ACTIVE'),
  ('dddddddd-dddd-dddd-dddd-dddddddddddd', '00000000-0000-0000-0000-000000000002', '44444444-4444-4444-4444-444444444444', 'ACTIVE'),
  ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', '00000000-0000-0000-0000-000000000002', '55555555-5555-5555-5555-555555555555', 'ACTIVE')
ON CONFLICT (gym_id, user_id) DO NOTHING;

-- 6. Gym Member Roles
INSERT INTO public.gym_member_roles (gym_member_id, role_id)
SELECT 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid, r.id FROM public.roles r WHERE r.name = 'GYM_ADMIN'
UNION ALL
SELECT 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'::uuid, r.id FROM public.roles r WHERE r.name = 'TRAINER'
UNION ALL
SELECT 'cccccccc-cccc-cccc-cccc-cccccccccccc'::uuid, r.id FROM public.roles r WHERE r.name = 'MEMBER'
UNION ALL
SELECT 'dddddddd-dddd-dddd-dddd-dddddddddddd'::uuid, r.id FROM public.roles r WHERE r.name = 'GYM_ADMIN'
UNION ALL
SELECT 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee'::uuid, r.id FROM public.roles r WHERE r.name = 'MEMBER'
ON CONFLICT (gym_member_id, role_id) DO NOTHING;
