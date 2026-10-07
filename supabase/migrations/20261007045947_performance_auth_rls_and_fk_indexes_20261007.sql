create index if not exists ops_billing_hospital_idx
  on public.ops_billing (hospital_id);

create index if not exists ops_payments_created_by_idx
  on public.ops_payments (created_by);

create index if not exists ops_vendors_created_by_idx
  on public.ops_vendors (created_by);

drop policy if exists "staff read staff" on public.ops_staff;

create policy "staff read staff"
on public.ops_staff
for select
to authenticated
using (
  ((select auth.uid()) = id)
  or private.ops_is_super_admin()
  or (
    upper(ops_role()) = 'CENTER_MANAGER'
    and center_id is not null
    and private.ops_can_access_center(center_id)
  )
);

drop policy if exists "authenticated read ops_billing" on public.ops_billing;

create policy "authenticated read ops_billing"
on public.ops_billing
for select
to authenticated
using (
  (
    exists (
      select 1
      from public.ops_patients p
      where p.id = ops_billing.patient_id
        and p.app_user_id = (select auth.uid())
        and p.portal_enabled = true
    )
    and upper(coalesce(type, '')) in ('CONCIERGE','ANCILLARY')
  )
  or (
    private.ops_is_staff()
    and (
      patient_id is null
      or exists (
        select 1
        from public.ops_patients p
        where p.id = ops_billing.patient_id
          and private.ops_can_access_center(p.center_id)
      )
    )
    and (
      case_id is null
      or exists (
        select 1
        from public.ops_cases c
        where c.id = ops_billing.case_id
          and private.ops_can_access_center(c.center_id)
      )
    )
  )
);