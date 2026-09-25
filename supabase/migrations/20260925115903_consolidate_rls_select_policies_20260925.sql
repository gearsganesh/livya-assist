-- Consolidate overlapping patient/staff SELECT policies for production RLS performance.
-- This preserves the existing access rules while reducing duplicate permissive policies.

drop policy if exists "patient read own appointments" on public.ops_appointments;
drop policy if exists "staff read ops_appointments" on public.ops_appointments;
create policy "authenticated read ops_appointments"
on public.ops_appointments for select to authenticated
using (
  exists (
    select 1 from public.ops_patients p
    where p.id=ops_appointments.patient_id
      and p.app_user_id=(select auth.uid())
      and p.portal_enabled=true
  )
  or (
    private.ops_is_staff()
    and exists (
      select 1 from public.ops_patients p
      where p.id=ops_appointments.patient_id
        and private.ops_can_access_center(p.center_id)
    )
  )
);

drop policy if exists "patient read own billing" on public.ops_billing;
drop policy if exists "staff read ops_billing" on public.ops_billing;
create policy "authenticated read ops_billing"
on public.ops_billing for select to authenticated
using (
  exists (
    select 1 from public.ops_patients p
    where p.id=ops_billing.patient_id
      and p.app_user_id=(select auth.uid())
      and p.portal_enabled=true
  )
  or (
    private.ops_is_staff()
    and (ops_billing.patient_id is null or exists (
      select 1 from public.ops_patients p
      where p.id=ops_billing.patient_id
        and private.ops_can_access_center(p.center_id)
    ))
    and (ops_billing.case_id is null or exists (
      select 1 from public.ops_cases c
      where c.id=ops_billing.case_id
        and private.ops_can_access_center(c.center_id)
    ))
  )
);

drop policy if exists "patients read visible events" on public.ops_case_events;
drop policy if exists "staff read case events" on public.ops_case_events;
create policy "authenticated read case events"
on public.ops_case_events for select to authenticated
using (
  exists (
    select 1 from public.ops_cases c
    join public.ops_patients p on p.id=c.patient_id
    where c.id=ops_case_events.case_id
      and p.app_user_id=(select auth.uid())
      and p.portal_enabled=true
  )
  or (
    private.ops_is_staff()
    and exists (
      select 1 from public.ops_cases c
      where c.id=ops_case_events.case_id
        and private.ops_can_access_center(c.center_id)
    )
  )
);

drop policy if exists "patients read visible messages" on public.ops_case_messages;
drop policy if exists "staff read case messages" on public.ops_case_messages;
create policy "authenticated read case messages"
on public.ops_case_messages for select to authenticated
using (
  (
    visible_to_patient
    and exists (
      select 1 from public.ops_cases c
      join public.ops_patients p on p.id=c.patient_id
      where c.id=ops_case_messages.case_id
        and p.app_user_id=(select auth.uid())
        and p.portal_enabled=true
    )
  )
  or (
    private.ops_is_staff()
    and exists (
      select 1 from public.ops_cases c
      where c.id=ops_case_messages.case_id
        and private.ops_can_access_center(c.center_id)
    )
  )
);

drop policy if exists "patient read own cases" on public.ops_cases;
drop policy if exists "staff read ops_cases" on public.ops_cases;
create policy "authenticated read ops_cases"
on public.ops_cases for select to authenticated
using (
  exists (
    select 1 from public.ops_patients p
    where p.id=ops_cases.patient_id
      and p.app_user_id=(select auth.uid())
      and p.portal_enabled=true
  )
  or (private.ops_is_staff() and private.ops_can_access_center(ops_cases.center_id))
);

drop policy if exists "patient read own concierge" on public.ops_concierge;
drop policy if exists "staff read ops_concierge" on public.ops_concierge;
create policy "authenticated read ops_concierge"
on public.ops_concierge for select to authenticated
using (
  exists (
    select 1 from public.ops_patients p
    where p.id=ops_concierge.patient_id
      and p.app_user_id=(select auth.uid())
      and p.portal_enabled=true
  )
  or (
    private.ops_is_staff()
    and exists (
      select 1 from public.ops_patients p
      where p.id=ops_concierge.patient_id
        and private.ops_can_access_center(p.center_id)
    )
  )
);

drop policy if exists "patients read visible documents" on public.ops_documents;
drop policy if exists "staff read documents" on public.ops_documents;
create policy "authenticated read documents"
on public.ops_documents for select to authenticated
using (
  (
    visible_to_patient
    and exists (
      select 1 from public.ops_cases c
      join public.ops_patients p on p.id=c.patient_id
      where c.id=ops_documents.case_id
        and p.app_user_id=(select auth.uid())
        and p.portal_enabled=true
    )
  )
  or (
    private.ops_is_staff()
    and exists (
      select 1 from public.ops_cases c
      where c.id=ops_documents.case_id
        and private.ops_can_access_center(c.center_id)
    )
  )
);

drop policy if exists "patients read itineraries" on public.ops_itineraries;
drop policy if exists "staff read itineraries" on public.ops_itineraries;
create policy "authenticated read itineraries"
on public.ops_itineraries for select to authenticated
using (
  exists (
    select 1
    from public.ops_cases c
    join public.ops_patients p on p.id=c.patient_id
    where c.id=ops_itineraries.case_id
      and p.app_user_id=(select auth.uid())
      and p.portal_enabled=true
  )
  or (
    private.ops_is_staff()
    and exists (
      select 1 from public.ops_cases c
      where c.id=ops_itineraries.case_id
        and private.ops_can_access_center(c.center_id)
    )
  )
);

drop policy if exists "patient read own profile" on public.ops_patients;
drop policy if exists "staff read ops_patients" on public.ops_patients;
create policy "authenticated read ops_patients"
on public.ops_patients for select to authenticated
using (
  (app_user_id=(select auth.uid()) and portal_enabled=true)
  or (private.ops_is_staff() and private.ops_can_access_center(center_id))
);

drop policy if exists "patients read quote items" on public.ops_quotation_items;
drop policy if exists "staff read quote items" on public.ops_quotation_items;
create policy "authenticated read quote items"
on public.ops_quotation_items for select to authenticated
using (
  exists (
    select 1
    from public.ops_quotations q
    join public.ops_cases c on c.id=q.case_id
    join public.ops_patients p on p.id=c.patient_id
    where q.id=ops_quotation_items.quotation_id
      and p.app_user_id=(select auth.uid())
      and p.portal_enabled=true
  )
  or (
    private.ops_is_staff()
    and exists (
      select 1
      from public.ops_quotations q
      join public.ops_cases c on c.id=q.case_id
      where q.id=ops_quotation_items.quotation_id
        and private.ops_can_access_center(c.center_id)
    )
  )
);

drop policy if exists "patients read visible quotations" on public.ops_quotations;
drop policy if exists "staff read quotations" on public.ops_quotations;
create policy "authenticated read quotations"
on public.ops_quotations for select to authenticated
using (
  exists (
    select 1
    from public.ops_cases c
    join public.ops_patients p on p.id=c.patient_id
    where c.id=ops_quotations.case_id
      and p.app_user_id=(select auth.uid())
      and p.portal_enabled=true
  )
  or (
    private.ops_is_staff()
    and exists (
      select 1 from public.ops_cases c
      where c.id=ops_quotations.case_id
        and private.ops_can_access_center(c.center_id)
    )
  )
);

drop policy if exists "staff write itineraries" on public.ops_itineraries;
create policy "staff insert itineraries" on public.ops_itineraries for insert to authenticated
with check (
  private.ops_is_super_admin()
  or (private.ops_can_write('travel') and exists (
    select 1 from public.ops_cases c
    where c.id=ops_itineraries.case_id
      and private.ops_can_access_center(c.center_id)
  ))
);
create policy "staff update itineraries" on public.ops_itineraries for update to authenticated
using (
  private.ops_is_super_admin()
  or (private.ops_can_write('travel') and exists (
    select 1 from public.ops_cases c
    where c.id=ops_itineraries.case_id
      and private.ops_can_access_center(c.center_id)
  ))
)
with check (
  private.ops_is_super_admin()
  or (private.ops_can_write('travel') and exists (
    select 1 from public.ops_cases c
    where c.id=ops_itineraries.case_id
      and private.ops_can_access_center(c.center_id)
  ))
);
create policy "staff delete itineraries" on public.ops_itineraries for delete to authenticated
using (
  private.ops_is_super_admin()
  or (private.ops_can_write('travel') and exists (
    select 1 from public.ops_cases c
    where c.id=ops_itineraries.case_id
      and private.ops_can_access_center(c.center_id)
  ))
);

drop policy if exists "staff write quote items" on public.ops_quotation_items;
create policy "staff insert quote items" on public.ops_quotation_items for insert to authenticated
with check (
  private.ops_is_super_admin()
  or (private.ops_can_write('quotations') and exists (
    select 1 from public.ops_quotations q
    join public.ops_cases c on c.id=q.case_id
    where q.id=ops_quotation_items.quotation_id
      and private.ops_can_access_center(c.center_id)
  ))
);
create policy "staff update quote items" on public.ops_quotation_items for update to authenticated
using (
  private.ops_is_super_admin()
  or (private.ops_can_write('quotations') and exists (
    select 1 from public.ops_quotations q
    join public.ops_cases c on c.id=q.case_id
    where q.id=ops_quotation_items.quotation_id
      and private.ops_can_access_center(c.center_id)
  ))
)
with check (
  private.ops_is_super_admin()
  or (private.ops_can_write('quotations') and exists (
    select 1 from public.ops_quotations q
    join public.ops_cases c on c.id=q.case_id
    where q.id=ops_quotation_items.quotation_id
      and private.ops_can_access_center(c.center_id)
  ))
);
create policy "staff delete quote items" on public.ops_quotation_items for delete to authenticated
using (
  private.ops_is_super_admin()
  or (private.ops_can_write('quotations') and exists (
    select 1 from public.ops_quotations q
    join public.ops_cases c on c.id=q.case_id
    where q.id=ops_quotation_items.quotation_id
      and private.ops_can_access_center(c.center_id)
  ))
);

drop policy if exists "super admins write centers" on public.ops_centers;
create policy "super admins insert centers" on public.ops_centers for insert to authenticated with check (private.ops_is_super_admin());
create policy "super admins update centers" on public.ops_centers for update to authenticated using (private.ops_is_super_admin()) with check (private.ops_is_super_admin());
create policy "super admins delete centers" on public.ops_centers for delete to authenticated using (private.ops_is_super_admin());

drop policy if exists "super admins write staff" on public.ops_staff;
create policy "super admins insert staff" on public.ops_staff for insert to authenticated with check (private.ops_is_super_admin());
create policy "super admins update staff" on public.ops_staff for update to authenticated using (private.ops_is_super_admin()) with check (private.ops_is_super_admin());
create policy "super admins delete staff" on public.ops_staff for delete to authenticated using (private.ops_is_super_admin());
