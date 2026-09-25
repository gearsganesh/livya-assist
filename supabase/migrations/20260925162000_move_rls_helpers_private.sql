-- Move RLS SECURITY DEFINER helpers out of the exposed public schema.
CREATE SCHEMA IF NOT EXISTS private;
ALTER FUNCTION public.ops_is_staff() SET SCHEMA private;
ALTER FUNCTION public.ops_is_super_admin() SET SCHEMA private;
ALTER FUNCTION public.ops_is_admin() SET SCHEMA private;
ALTER FUNCTION public.ops_scope() SET SCHEMA private;
ALTER FUNCTION public.ops_can_access_center(uuid) SET SCHEMA private;
ALTER FUNCTION public.ops_can_write(text) SET SCHEMA private;

CREATE OR REPLACE FUNCTION private.ops_is_staff() RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$ SELECT EXISTS (SELECT 1 FROM public.ops_staff WHERE id=(SELECT auth.uid()) AND active); $$;
CREATE OR REPLACE FUNCTION private.ops_is_super_admin() RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$ SELECT EXISTS (SELECT 1 FROM public.ops_staff WHERE id=(SELECT auth.uid()) AND active AND role='Super admin'); $$;
CREATE OR REPLACE FUNCTION private.ops_is_admin() RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$ SELECT EXISTS (SELECT 1 FROM public.ops_staff WHERE id=(SELECT auth.uid()) AND active AND role IN ('Super admin','Center admin')); $$;
CREATE OR REPLACE FUNCTION private.ops_scope() RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$ SELECT scope FROM public.ops_staff WHERE id=(SELECT auth.uid()) AND active LIMIT 1; $$;
CREATE OR REPLACE FUNCTION private.ops_can_access_center(p_center_id uuid) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$ SELECT private.ops_is_super_admin() OR private.ops_scope()='All centers' OR EXISTS (SELECT 1 FROM public.ops_centers c WHERE c.id=p_center_id AND c.name=private.ops_scope()); $$;
CREATE OR REPLACE FUNCTION private.ops_can_write(p_module text) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$ SELECT EXISTS (SELECT 1 FROM public.ops_staff s WHERE s.id=(SELECT auth.uid()) AND s.active AND (s.role='Super admin' OR (p_module IN ('cases','patients','appointments','tasks','concierge','documents','quotations','travel','messages') AND s.role IN ('Coordinator','Center admin')) OR (p_module='billing' AND s.role='Finance') OR (p_module IN ('hospitals','referrers','centers') AND s.role='Center admin'))); $$;

REVOKE ALL ON SCHEMA private FROM PUBLIC;
GRANT USAGE ON SCHEMA private TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.ops_is_staff() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.ops_is_super_admin() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.ops_is_admin() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.ops_scope() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.ops_can_access_center(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.ops_can_write(text) TO authenticated, service_role;
