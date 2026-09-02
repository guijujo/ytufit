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

-- 7. Membership plans (tenant-local commercial configuration)
INSERT INTO public.membership_plans (
  id, gym_id, name, description, access_type, access_limit,
  frequency_period, target, price, currency, duration_days
) VALUES
  ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001',
   'Tres por semana', 'Frecuencia semanal', 'WEEKLY_FREQUENCY', NULL, 'WEEK', 3, 30000, 'ARS', 30),
  ('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000001',
   'Doce por mes', 'LÃƒÂ­mite mensual', 'MONTHLY_LIMIT', NULL, 'MONTH', 12, 36000, 'ARS', 30),
  ('10000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000001',
   'Pase Libre', 'Acceso sin lÃƒÂ­mite comercial', 'UNLIMITED', NULL, NULL, NULL, 45000, 'ARS', 30),
  ('20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002',
   'Plan Beta', 'Plan independiente de Gym Beta', 'ACCESS_COUNT', 10, NULL, NULL, 10000, 'ARS', 10)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  access_type = EXCLUDED.access_type,
  access_limit = EXCLUDED.access_limit,
  frequency_period = EXCLUDED.frequency_period,
  target = EXCLUDED.target,
  price = EXCLUDED.price,
  currency = EXCLUDED.currency,
  duration_days = EXCLUDED.duration_days,
  status = 'ACTIVE',
  deleted_at = NULL;

-- 8. Contract snapshots for deterministic member history
INSERT INTO public.memberships (
  id, gym_id, gym_member_id, membership_plan_id, status, starts_at, ends_at,
  contracted_price, currency, access_limit_snapshot, access_type_snapshot,
  target_snapshot, period_snapshot
) VALUES
  ('30000000-0000-0000-0000-000000000001',
   '00000000-0000-0000-0000-000000000001',
   'cccccccc-cccc-cccc-cccc-cccccccccccc',
   '10000000-0000-0000-0000-000000000001',
   'ACTIVE', '2020-01-01 00:00:00+00', '2099-01-01 00:00:00+00',
   30000, 'ARS', NULL, 'WEEKLY_FREQUENCY', 3, 'WEEK'),
  ('30000000-0000-0000-0000-000000000002',
   '00000000-0000-0000-0000-000000000002',
   'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
   '20000000-0000-0000-0000-000000000001',
   'ACTIVE', '2020-01-01 00:00:00+00', '2099-01-01 00:00:00+00',
   10000, 'ARS', 10, 'ACCESS_COUNT', NULL, NULL)
ON CONFLICT (id) DO NOTHING;

-- 9. Attendance history: valid rows and one retained cancellation.
INSERT INTO public.attendances (
  id, gym_id, gym_member_id, membership_id, attendance_date, occurred_at,
  method, status, source_reference, created_by,
  cancellation_reason, cancelled_by, cancelled_at
) VALUES
  ('40000000-0000-0000-0000-000000000001',
   '00000000-0000-0000-0000-000000000001',
   'cccccccc-cccc-cccc-cccc-cccccccccccc',
   '30000000-0000-0000-0000-000000000001',
   '2026-08-04', '2026-08-04 18:00:00+00', 'QR', 'VALID',
   'seed-a-1', '33333333-3333-3333-3333-333333333333', NULL, NULL, NULL),
  ('40000000-0000-0000-0000-000000000002',
   '00000000-0000-0000-0000-000000000001',
   'cccccccc-cccc-cccc-cccc-cccccccccccc',
   '30000000-0000-0000-0000-000000000001',
   '2026-08-05', '2026-08-05 18:00:00+00', 'MANUAL', 'CANCELLED',
   'seed-a-cancelled', '33333333-3333-3333-3333-333333333333',
   'Correction fixture', '11111111-1111-1111-1111-111111111111',
   '2026-08-06 12:00:00+00'),
  ('40000000-0000-0000-0000-000000000003',
   '00000000-0000-0000-0000-000000000002',
   'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
   '30000000-0000-0000-0000-000000000002',
   '2026-08-04', '2026-08-04 18:00:00+00', 'QR', 'VALID',
   'seed-b-1', '55555555-5555-5555-5555-555555555555', NULL, NULL, NULL)
ON CONFLICT (id) DO NOTHING;
