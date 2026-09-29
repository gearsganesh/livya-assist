drop policy if exists "authenticated read quotations" on public.ops_quotations;
create policy "authenticated read quotations" on public.ops_quotations for select to authenticated
using (
  (exists (
    select 1 from public.ops_cases c join public.ops_patients p on p.id=c.patient_id
    where c.id=ops_quotations.case_id and p.app_user_id=(select auth.uid()) and p.portal_enabled=true
      and upper(coalesce(ops_quotations.status,'')) <> 'DRAFT'
  ))
  or
  (private.ops_is_staff() and exists (
    select 1 from public.ops_cases c where c.id=ops_quotations.case_id and private.ops_can_access_center(c.center_id)
  ))
);
drop policy if exists "hospital read concierge" on public.ops_concierge;