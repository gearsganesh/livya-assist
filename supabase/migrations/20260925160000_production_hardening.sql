-- LIVYA production hardening: security, RLS role scoping, policy performance and FK indexes.

-- Production hardening applied to the live LIVYA project on 2026-09-25.
REVOKE EXECUTE ON FUNCTION public.ops_can_access_center(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.ops_can_write(text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.ops_is_admin() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.ops_is_staff() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.ops_is_super_admin() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.ops_scope() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ops_can_access_center(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.ops_can_write(text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.ops_is_admin() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.ops_is_staff() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.ops_is_super_admin() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.ops_scope() TO authenticated, service_role;

ALTER FUNCTION public.ops_touch_updated_at() SET search_path = public;
REVOKE EXECUTE ON FUNCTION public.ops_touch_updated_at() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ops_touch_updated_at() TO authenticated, service_role;

CREATE INDEX IF NOT EXISTS ops_appointments_created_by_idx ON public.ops_appointments(created_by);
CREATE INDEX IF NOT EXISTS ops_billing_created_by_idx ON public.ops_billing(created_by);
CREATE INDEX IF NOT EXISTS ops_case_events_actor_idx ON public.ops_case_events(actor_id);
CREATE INDEX IF NOT EXISTS ops_case_messages_sender_idx ON public.ops_case_messages(sender_id);
CREATE INDEX IF NOT EXISTS ops_cases_created_by_idx ON public.ops_cases(created_by);
CREATE INDEX IF NOT EXISTS ops_concierge_assigned_to_idx ON public.ops_concierge(assigned_to);
CREATE INDEX IF NOT EXISTS ops_concierge_created_by_idx ON public.ops_concierge(created_by);
CREATE INDEX IF NOT EXISTS ops_concierge_patient_idx ON public.ops_concierge(patient_id);
CREATE INDEX IF NOT EXISTS ops_documents_uploaded_by_idx ON public.ops_documents(uploaded_by);
CREATE INDEX IF NOT EXISTS ops_patients_created_by_idx ON public.ops_patients(created_by);
CREATE INDEX IF NOT EXISTS ops_quotations_created_by_idx ON public.ops_quotations(created_by);
CREATE INDEX IF NOT EXISTS ops_quotations_document_idx ON public.ops_quotations(document_id);
CREATE INDEX IF NOT EXISTS ops_quotations_hospital_idx ON public.ops_quotations(hospital_id);
CREATE INDEX IF NOT EXISTS ops_tasks_created_by_idx ON public.ops_tasks(created_by);
CREATE INDEX IF NOT EXISTS ops_tasks_patient_idx ON public.ops_tasks(patient_id);

DROP POLICY IF EXISTS "patient read own appointments" ON public.ops_appointments;
CREATE POLICY "patient read own appointments" ON public.ops_appointments FOR SELECT TO authenticated
USING (EXISTS (SELECT 1 FROM public.ops_patients p WHERE p.id=patient_id AND p.app_user_id=(SELECT auth.uid()) AND p.portal_enabled=true));

DROP POLICY IF EXISTS "patient read own billing" ON public.ops_billing;
CREATE POLICY "patient read own billing" ON public.ops_billing FOR SELECT TO authenticated
USING (EXISTS (SELECT 1 FROM public.ops_patients p WHERE p.id=patient_id AND p.app_user_id=(SELECT auth.uid()) AND p.portal_enabled=true));

DROP POLICY IF EXISTS "patients read visible events" ON public.ops_case_events;
CREATE POLICY "patients read visible events" ON public.ops_case_events FOR SELECT TO authenticated
USING (EXISTS (SELECT 1 FROM public.ops_cases c JOIN public.ops_patients p ON p.id=c.patient_id WHERE c.id=case_id AND p.app_user_id=(SELECT auth.uid()) AND p.portal_enabled=true));

DROP POLICY IF EXISTS "patients read visible messages" ON public.ops_case_messages;
CREATE POLICY "patients read visible messages" ON public.ops_case_messages FOR SELECT TO authenticated
USING (visible_to_patient AND EXISTS (SELECT 1 FROM public.ops_cases c JOIN public.ops_patients p ON p.id=c.patient_id WHERE c.id=case_id AND p.app_user_id=(SELECT auth.uid()) AND p.portal_enabled=true));

DROP POLICY IF EXISTS "patient read own cases" ON public.ops_cases;
CREATE POLICY "patient read own cases" ON public.ops_cases FOR SELECT TO authenticated
USING (EXISTS (SELECT 1 FROM public.ops_patients p WHERE p.id=patient_id AND p.app_user_id=(SELECT auth.uid()) AND p.portal_enabled=true));

DROP POLICY IF EXISTS "patient read own center" ON public.ops_centers;
CREATE POLICY "patient read own center" ON public.ops_centers FOR SELECT TO authenticated
USING (EXISTS (SELECT 1 FROM public.ops_patients p WHERE p.center_id=id AND p.app_user_id=(SELECT auth.uid()) AND p.portal_enabled=true));

DROP POLICY IF EXISTS "patient read own concierge" ON public.ops_concierge;
CREATE POLICY "patient read own concierge" ON public.ops_concierge FOR SELECT TO authenticated
USING (EXISTS (SELECT 1 FROM public.ops_patients p WHERE p.id=patient_id AND p.app_user_id=(SELECT auth.uid()) AND p.portal_enabled=true));

DROP POLICY IF EXISTS "patients read visible documents" ON public.ops_documents;
CREATE POLICY "patients read visible documents" ON public.ops_documents FOR SELECT TO authenticated
USING (visible_to_patient AND EXISTS (SELECT 1 FROM public.ops_cases c JOIN public.ops_patients p ON p.id=c.patient_id WHERE c.id=case_id AND p.app_user_id=(SELECT auth.uid()) AND p.portal_enabled=true));

DROP POLICY IF EXISTS "patients read itineraries" ON public.ops_itineraries;
CREATE POLICY "patients read itineraries" ON public.ops_itineraries FOR SELECT TO authenticated
USING (EXISTS (SELECT 1 FROM public.ops_cases c JOIN public.ops_patients p ON p.id=c.patient_id WHERE c.id=case_id AND p.app_user_id=(SELECT auth.uid()) AND p.portal_enabled=true));

DROP POLICY IF EXISTS "patient read own profile" ON public.ops_patients;
CREATE POLICY "patient read own profile" ON public.ops_patients FOR SELECT TO authenticated
USING (app_user_id=(SELECT auth.uid()) AND portal_enabled=true);

DROP POLICY IF EXISTS "patients read quote items" ON public.ops_quotation_items;
CREATE POLICY "patients read quote items" ON public.ops_quotation_items FOR SELECT TO authenticated
USING (EXISTS (SELECT 1 FROM public.ops_quotations q JOIN public.ops_cases c ON c.id=q.case_id JOIN public.ops_patients p ON p.id=c.patient_id WHERE q.id=quotation_id AND p.app_user_id=(SELECT auth.uid()) AND p.portal_enabled=true));

DROP POLICY IF EXISTS "patients read visible quotations" ON public.ops_quotations;
CREATE POLICY "patients read visible quotations" ON public.ops_quotations FOR SELECT TO authenticated
USING (EXISTS (SELECT 1 FROM public.ops_cases c JOIN public.ops_patients p ON p.id=c.patient_id WHERE c.id=case_id AND p.app_user_id=(SELECT auth.uid()) AND p.portal_enabled=true));

DROP POLICY IF EXISTS "staff read staff" ON public.ops_staff;
CREATE POLICY "staff read staff" ON public.ops_staff FOR SELECT TO authenticated
USING ((SELECT auth.uid())=id OR ops_is_super_admin());

