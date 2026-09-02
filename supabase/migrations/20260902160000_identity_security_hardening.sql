-- v2.0.1 security hardening.
-- The initial identity migration is append-only; this migration removes
-- client-side state transitions that must be performed by server commands.

DROP POLICY IF EXISTS gym_join_requests_update_admin ON public.gym_join_requests;
DROP POLICY IF EXISTS gym_join_requests_update_platform_admin ON public.gym_join_requests;
DROP POLICY IF EXISTS gym_invitations_update_admin ON public.gym_invitations;
DROP POLICY IF EXISTS gym_invitations_update_platform_admin ON public.gym_invitations;

CREATE OR REPLACE FUNCTION private.guard_join_request_update()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
  IF (SELECT auth.uid()) IS NOT NULL AND NOT private.is_platform_admin() THEN
    IF NEW.id <> OLD.id
      OR NEW.gym_id <> OLD.gym_id
      OR NEW.user_id <> OLD.user_id
      OR NEW.created_at <> OLD.created_at
      OR NEW.reviewed_by IS DISTINCT FROM OLD.reviewed_by
      OR NEW.reviewed_at IS DISTINCT FROM OLD.reviewed_at THEN
      RAISE EXCEPTION 'Join request ownership and review fields are immutable';
    END IF;

    IF OLD.status <> 'PENDING' OR NEW.status <> 'CANCELLED' THEN
      RAISE EXCEPTION 'Only PENDING join requests can be cancelled by a client';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION private.guard_join_request_update() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION private.guard_join_request_update() TO postgres, service_role;

DROP TRIGGER IF EXISTS trg_guard_join_request_update ON public.gym_join_requests;
CREATE TRIGGER trg_guard_join_request_update
  BEFORE UPDATE ON public.gym_join_requests
  FOR EACH ROW
  EXECUTE FUNCTION private.guard_join_request_update();

CREATE OR REPLACE FUNCTION private.guard_invitation_update()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
  IF (SELECT auth.uid()) IS NOT NULL AND NOT private.is_platform_admin() THEN
    RAISE EXCEPTION 'Invitation state changes require a server-side command';
  END IF;

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION private.guard_invitation_update() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION private.guard_invitation_update() TO postgres, service_role;

DROP TRIGGER IF EXISTS trg_guard_invitation_update ON public.gym_invitations;
CREATE TRIGGER trg_guard_invitation_update
  BEFORE UPDATE ON public.gym_invitations
  FOR EACH ROW
  EXECUTE FUNCTION private.guard_invitation_update();

