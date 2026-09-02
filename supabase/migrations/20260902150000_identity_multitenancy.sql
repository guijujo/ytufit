-- YtuFit v2.0.1: Identity + Multi-tenancy + Auth + RLS Core Migration
-- Migration: 20260902150000_identity_multitenancy.sql

-- 1. EXTENSIONS & PRIVATE SCHEMA
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE SCHEMA IF NOT EXISTS private;
REVOKE ALL ON SCHEMA private FROM PUBLIC;
REVOKE ALL ON SCHEMA private FROM anon;
REVOKE ALL ON SCHEMA private FROM authenticated;
GRANT USAGE ON SCHEMA private TO anon, authenticated, service_role;

-- Generic updated_at timestamp trigger
CREATE OR REPLACE FUNCTION private.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
  NEW.updated_at = clock_timestamp();
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION private.set_updated_at() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION private.set_updated_at() TO postgres, service_role;

-- 2. CORE TABLES

-- 2.1 Profiles (extension of auth.users)
CREATE TABLE public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  first_name TEXT NULL,
  last_name TEXT NULL,
  phone TEXT NULL,
  birth_date DATE NULL,
  avatar_path TEXT NULL,
  status TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'SUSPENDED', 'INACTIVE')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);

CREATE TRIGGER trg_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION private.set_updated_at();

-- 2.2 Gyms (tenant boundaries)
CREATE TABLE public.gyms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  slug TEXT NOT NULL UNIQUE,
  status TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'SUSPENDED', 'INACTIVE')),
  timezone TEXT NOT NULL DEFAULT 'UTC',
  created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);

CREATE TRIGGER trg_gyms_updated_at
  BEFORE UPDATE ON public.gyms
  FOR EACH ROW
  EXECUTE FUNCTION private.set_updated_at();

-- 2.3 Gym Members (user-to-gym contextual membership)
CREATE TABLE public.gym_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  gym_id UUID NOT NULL REFERENCES public.gyms(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'SUSPENDED', 'INACTIVE')),
  joined_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
  CONSTRAINT gym_members_gym_user_key UNIQUE (gym_id, user_id),
  CONSTRAINT gym_members_id_gym_key UNIQUE (id, gym_id)
);

CREATE INDEX idx_gym_members_gym_id ON public.gym_members(gym_id);
CREATE INDEX idx_gym_members_user_id ON public.gym_members(user_id);

CREATE TRIGGER trg_gym_members_updated_at
  BEFORE UPDATE ON public.gym_members
  FOR EACH ROW
  EXECUTE FUNCTION private.set_updated_at();

-- 2.4 Roles (gym role catalog)
CREATE TABLE public.roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE CHECK (name IN ('GYM_ADMIN', 'TRAINER', 'MEMBER')),
  description TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);

INSERT INTO public.roles (name, description) VALUES
  ('GYM_ADMIN', 'Administrador contextual del gimnasio'),
  ('TRAINER', 'Entrenador del gimnasio'),
  ('MEMBER', 'Miembro / alumno del gimnasio')
ON CONFLICT (name) DO NOTHING;

-- 2.5 Gym Member Roles
CREATE TABLE public.gym_member_roles (
  gym_member_id UUID NOT NULL REFERENCES public.gym_members(id) ON DELETE CASCADE,
  role_id UUID NOT NULL REFERENCES public.roles(id) ON DELETE RESTRICT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
  PRIMARY KEY (gym_member_id, role_id)
);

CREATE INDEX idx_gym_member_roles_role_id ON public.gym_member_roles(role_id);

-- 2.6 Platform Admins (global, independent of tenant model)
CREATE TABLE public.platform_admins (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);

-- 2.7 Gym Join Requests
CREATE TABLE public.gym_join_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  gym_id UUID NOT NULL REFERENCES public.gyms(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED', 'CANCELLED')),
  note TEXT NULL,
  reviewed_by UUID NULL REFERENCES auth.users(id) ON DELETE SET NULL,
  reviewed_at TIMESTAMPTZ NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);

CREATE UNIQUE INDEX idx_gym_join_requests_unique_pending
  ON public.gym_join_requests (gym_id, user_id)
  WHERE status = 'PENDING';

CREATE INDEX idx_gym_join_requests_gym_id ON public.gym_join_requests(gym_id);
CREATE INDEX idx_gym_join_requests_user_id ON public.gym_join_requests(user_id);

CREATE TRIGGER trg_gym_join_requests_updated_at
  BEFORE UPDATE ON public.gym_join_requests
  FOR EACH ROW
  EXECUTE FUNCTION private.set_updated_at();

-- 2.8 Gym Invitations
CREATE TABLE public.gym_invitations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  gym_id UUID NOT NULL REFERENCES public.gyms(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  role_id UUID NOT NULL REFERENCES public.roles(id) ON DELETE RESTRICT,
  invited_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  token_hash TEXT NOT NULL UNIQUE,
  status TEXT NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'ACCEPTED', 'DECLINED', 'REVOKED', 'EXPIRED')),
  expires_at TIMESTAMPTZ NOT NULL,
  accepted_at TIMESTAMPTZ NULL,
  accepted_by UUID NULL REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);

CREATE UNIQUE INDEX idx_gym_invitations_unique_pending
  ON public.gym_invitations (gym_id, lower(email))
  WHERE status = 'PENDING';

CREATE INDEX idx_gym_invitations_gym_id ON public.gym_invitations(gym_id);
CREATE INDEX idx_gym_invitations_email ON public.gym_invitations(lower(email));

CREATE TRIGGER trg_gym_invitations_updated_at
  BEFORE UPDATE ON public.gym_invitations
  FOR EACH ROW
  EXECUTE FUNCTION private.set_updated_at();

-- 3. AUTOMATIC PROFILE TRIGGER ON auth.users
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_first_name TEXT;
  v_last_name TEXT;
  v_phone TEXT;
  v_avatar_path TEXT;
BEGIN
  IF NEW.raw_user_meta_data IS NOT NULL THEN
    v_first_name := NULLIF(TRIM(COALESCE(NEW.raw_user_meta_data ->> 'first_name', '')), '');
    v_last_name := NULLIF(TRIM(COALESCE(NEW.raw_user_meta_data ->> 'last_name', '')), '');
    v_phone := NULLIF(TRIM(COALESCE(NEW.raw_user_meta_data ->> 'phone', '')), '');
    v_avatar_path := NULLIF(TRIM(COALESCE(NEW.raw_user_meta_data ->> 'avatar_path', NEW.raw_user_meta_data ->> 'avatar_url', '')), '');
  END IF;

  INSERT INTO public.profiles (
    id,
    first_name,
    last_name,
    phone,
    avatar_path,
    status
  )
  VALUES (
    NEW.id,
    v_first_name,
    v_last_name,
    v_phone,
    v_avatar_path,
    'ACTIVE'
  )
  ON CONFLICT (id) DO NOTHING;

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.handle_new_user() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO postgres, supabase_auth_admin, service_role;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- Guard trigger on profiles update to prevent tampering with sensitive columns
CREATE OR REPLACE FUNCTION private.check_profile_update()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
  IF (SELECT auth.uid()) IS NOT NULL AND NOT private.is_platform_admin() THEN
    IF NEW.id <> OLD.id THEN
      RAISE EXCEPTION 'Cannot modify profile id';
    END IF;
    IF NEW.status <> OLD.status THEN
      RAISE EXCEPTION 'Cannot modify profile status directly';
    END IF;
    IF NEW.created_at <> OLD.created_at THEN
      RAISE EXCEPTION 'Cannot modify profile created_at';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION private.check_profile_update() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION private.check_profile_update() TO postgres, service_role;

CREATE TRIGGER trg_profiles_check_update
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION private.check_profile_update();

-- 4. PRIVATE SECURITY HELPERS (Derived strictly from auth.uid())
CREATE OR REPLACE FUNCTION private.is_gym_member(p_gym_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.gym_members gm
    WHERE gm.gym_id = p_gym_id
      AND gm.user_id = (SELECT auth.uid())
      AND gm.status = 'ACTIVE'
  );
$$;

CREATE OR REPLACE FUNCTION private.has_gym_role(p_gym_id UUID, p_role_name TEXT)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.gym_members gm
    JOIN public.gym_member_roles gmr ON gmr.gym_member_id = gm.id
    JOIN public.roles r ON r.id = gmr.role_id
    WHERE gm.gym_id = p_gym_id
      AND gm.user_id = (SELECT auth.uid())
      AND gm.status = 'ACTIVE'
      AND r.name = p_role_name
  );
$$;

CREATE OR REPLACE FUNCTION private.is_platform_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.platform_admins pa
    WHERE pa.user_id = (SELECT auth.uid())
  );
$$;

REVOKE ALL ON FUNCTION private.is_gym_member(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION private.has_gym_role(UUID, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION private.is_platform_admin() FROM PUBLIC;

GRANT EXECUTE ON FUNCTION private.is_gym_member(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.has_gym_role(UUID, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.is_platform_admin() TO authenticated, service_role;

-- 5. ROW LEVEL SECURITY (RLS) - DEFAULT DENY

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles FORCE ROW LEVEL SECURITY;

ALTER TABLE public.gyms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gyms FORCE ROW LEVEL SECURITY;

ALTER TABLE public.gym_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gym_members FORCE ROW LEVEL SECURITY;

ALTER TABLE public.roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.roles FORCE ROW LEVEL SECURITY;

ALTER TABLE public.gym_member_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gym_member_roles FORCE ROW LEVEL SECURITY;

ALTER TABLE public.platform_admins ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.platform_admins FORCE ROW LEVEL SECURITY;

ALTER TABLE public.gym_join_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gym_join_requests FORCE ROW LEVEL SECURITY;

ALTER TABLE public.gym_invitations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gym_invitations FORCE ROW LEVEL SECURITY;

-- 5.1 Profiles Policies
-- User can read own profile; Gym Admin can read profiles of members in their gym; Platform Admin can read all
CREATE POLICY profiles_select_permitted ON public.profiles
  FOR SELECT TO authenticated
  USING (
    id = (SELECT auth.uid())
    OR private.is_platform_admin()
    OR EXISTS (
      SELECT 1
      FROM public.gym_members gm_target
      JOIN public.gym_members gm_admin ON gm_admin.gym_id = gm_target.gym_id
      WHERE gm_target.user_id = profiles.id
        AND gm_admin.user_id = (SELECT auth.uid())
        AND private.has_gym_role(gm_admin.gym_id, 'GYM_ADMIN')
    )
  );

CREATE POLICY profiles_update_own ON public.profiles
  FOR UPDATE TO authenticated
  USING (id = (SELECT auth.uid()))
  WITH CHECK (id = (SELECT auth.uid()));

-- 5.2 Gyms Policies
-- Members can read gyms they belong to; Platform Admin can read all
CREATE POLICY gyms_select_member ON public.gyms
  FOR SELECT TO authenticated
  USING (
    private.is_gym_member(id)
    OR private.is_platform_admin()
  );

-- Only platform admins can mutate gyms directly
CREATE POLICY gyms_platform_admin_mutations ON public.gyms
  FOR ALL TO authenticated
  USING (private.is_platform_admin())
  WITH CHECK (private.is_platform_admin());

-- 5.3 Gym Members Policies
-- User can read own membership
CREATE POLICY gym_members_select_own ON public.gym_members
  FOR SELECT TO authenticated
  USING (user_id = (SELECT auth.uid()));

-- Gym Admin can read members of the same gym
CREATE POLICY gym_members_select_gym_admin ON public.gym_members
  FOR SELECT TO authenticated
  USING (private.has_gym_role(gym_id, 'GYM_ADMIN'));

-- Platform admin can read all gym members
CREATE POLICY gym_members_select_platform_admin ON public.gym_members
  FOR SELECT TO authenticated
  USING (private.is_platform_admin());

-- Only platform admin can mutate gym_members directly from client
CREATE POLICY gym_members_platform_admin_mutations ON public.gym_members
  FOR ALL TO authenticated
  USING (private.is_platform_admin())
  WITH CHECK (private.is_platform_admin());

-- 5.4 Roles Catalog Policies
-- Authenticated users can view available roles catalog
CREATE POLICY roles_select_authenticated ON public.roles
  FOR SELECT TO authenticated
  USING (true);

-- Platform admin can manage roles catalog
CREATE POLICY roles_platform_admin_mutations ON public.roles
  FOR ALL TO authenticated
  USING (private.is_platform_admin())
  WITH CHECK (private.is_platform_admin());

-- 5.5 Gym Member Roles Policies
-- User can read roles for their own memberships
CREATE POLICY gym_member_roles_select_own ON public.gym_member_roles
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.gym_members gm
      WHERE gm.id = gym_member_id
        AND gm.user_id = (SELECT auth.uid())
    )
  );

-- Gym Admin can read member roles within their gym
CREATE POLICY gym_member_roles_select_gym_admin ON public.gym_member_roles
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.gym_members gm
      WHERE gm.id = gym_member_id
        AND private.has_gym_role(gm.gym_id, 'GYM_ADMIN')
    )
  );

-- Platform admin can read all
CREATE POLICY gym_member_roles_select_platform_admin ON public.gym_member_roles
  FOR SELECT TO authenticated
  USING (private.is_platform_admin());

-- Platform admin can mutate gym member roles directly
CREATE POLICY gym_member_roles_platform_admin_mutations ON public.gym_member_roles
  FOR ALL TO authenticated
  USING (private.is_platform_admin())
  WITH CHECK (private.is_platform_admin());

-- 5.6 Platform Admins Policies
-- User can read only their own platform admin status
CREATE POLICY platform_admins_select_self ON public.platform_admins
  FOR SELECT TO authenticated
  USING (user_id = (SELECT auth.uid()));

-- No direct client insert, update, or delete on platform_admins (default deny)

-- 5.7 Gym Join Requests Policies
-- User can read their own join requests
CREATE POLICY gym_join_requests_select_own ON public.gym_join_requests
  FOR SELECT TO authenticated
  USING (user_id = (SELECT auth.uid()));

-- Gym Admin can read join requests for their gym
CREATE POLICY gym_join_requests_select_admin ON public.gym_join_requests
  FOR SELECT TO authenticated
  USING (private.has_gym_role(gym_id, 'GYM_ADMIN'));

-- Platform admin can read all join requests
CREATE POLICY gym_join_requests_select_platform_admin ON public.gym_join_requests
  FOR SELECT TO authenticated
  USING (private.is_platform_admin());

-- User can submit their own join request with status PENDING
CREATE POLICY gym_join_requests_insert_own ON public.gym_join_requests
  FOR INSERT TO authenticated
  WITH CHECK (
    user_id = (SELECT auth.uid())
    AND status = 'PENDING'
  );

-- User can cancel their own pending join request
CREATE POLICY gym_join_requests_cancel_own ON public.gym_join_requests
  FOR UPDATE TO authenticated
  USING (
    user_id = (SELECT auth.uid())
    AND status = 'PENDING'
  )
  WITH CHECK (
    user_id = (SELECT auth.uid())
    AND status = 'CANCELLED'
  );

-- Gym Admin can update join requests for their gym (approve/reject)
CREATE POLICY gym_join_requests_update_admin ON public.gym_join_requests
  FOR UPDATE TO authenticated
  USING (private.has_gym_role(gym_id, 'GYM_ADMIN'))
  WITH CHECK (private.has_gym_role(gym_id, 'GYM_ADMIN'));

-- Platform admin can update join requests
CREATE POLICY gym_join_requests_update_platform_admin ON public.gym_join_requests
  FOR UPDATE TO authenticated
  USING (private.is_platform_admin())
  WITH CHECK (private.is_platform_admin());

-- 5.8 Gym Invitations Policies
-- Gym Admin can read invitations for their gym
CREATE POLICY gym_invitations_select_admin ON public.gym_invitations
  FOR SELECT TO authenticated
  USING (private.has_gym_role(gym_id, 'GYM_ADMIN'));

-- Invited user can read invitation matching their authenticated email
CREATE POLICY gym_invitations_select_invited ON public.gym_invitations
  FOR SELECT TO authenticated
  USING (lower(email) = lower(COALESCE((SELECT auth.jwt() ->> 'email'), '')));

-- Platform admin can read all invitations
CREATE POLICY gym_invitations_select_platform_admin ON public.gym_invitations
  FOR SELECT TO authenticated
  USING (private.is_platform_admin());

-- Gym Admin can create invitations for their gym
CREATE POLICY gym_invitations_insert_admin ON public.gym_invitations
  FOR INSERT TO authenticated
  WITH CHECK (
    private.has_gym_role(gym_id, 'GYM_ADMIN')
    AND invited_by = (SELECT auth.uid())
    AND status = 'PENDING'
  );

-- Gym Admin can update invitations for their gym (e.g. revoke)
CREATE POLICY gym_invitations_update_admin ON public.gym_invitations
  FOR UPDATE TO authenticated
  USING (private.has_gym_role(gym_id, 'GYM_ADMIN'))
  WITH CHECK (private.has_gym_role(gym_id, 'GYM_ADMIN'));

-- Platform admin can update invitations
CREATE POLICY gym_invitations_update_platform_admin ON public.gym_invitations
  FOR UPDATE TO authenticated
  USING (private.is_platform_admin())
  WITH CHECK (private.is_platform_admin());
