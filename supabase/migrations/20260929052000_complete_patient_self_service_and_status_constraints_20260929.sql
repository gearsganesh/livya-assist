drop policy if exists "patient create concierge request" on public.ops_concierge;
create policy "patient create concierge request"
on public.ops_concierge for insert to authenticated
with check (
  (select public.ops_is_patient())
  and patient_id = (select id from public.ops_patients where app_user_id = (select auth.uid()) and portal_enabled = true)
  and exists (select 1 from public.ops_cases c where c.id = ops_concierge.case_id and c.patient_id = ops_concierge.patient_id)
  and coalesce(price,0) = 0
  and coalesce(revenue,0) = 0
  and upper(coalesce(status,'REQUESTED')) = 'REQUESTED'
);

drop policy if exists "patient create case messages" on public.ops_case_messages;
create policy "patient create case messages"
on public.ops_case_messages for insert to authenticated
with check (
  visible_to_patient = true
  and exists (
    select 1 from public.ops_cases c
    join public.ops_patients p on p.id = c.patient_id
    where c.id = ops_case_messages.case_id
      and p.app_user_id = (select auth.uid())
      and p.portal_enabled = true
  )
  and sender_id = (select auth.uid())
);

drop policy if exists "patient upload case documents" on public.ops_documents;
create policy "patient upload case documents"
on public.ops_documents for insert to authenticated
with check (
  visible_to_patient = true
  and uploaded_by = (select auth.uid())
  and exists (
    select 1 from public.ops_cases c
    join public.ops_patients p on p.id = c.patient_id
    where c.id = ops_documents.case_id
      and p.app_user_id = (select auth.uid())
      and p.portal_enabled = true
  )
);

drop policy if exists "patients upload case document files" on storage.objects;
create policy "patients upload case document files"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'case-documents'
  and exists (
    select 1 from public.ops_cases c
    join public.ops_patients p on p.id = c.patient_id
    where c.id::text = split_part(storage.objects.name,'/',1)
      and p.app_user_id = (select auth.uid())
      and p.portal_enabled = true
  )
);

drop policy if exists "patients read own uploaded case document files" on storage.objects;
create policy "patients read own uploaded case document files"
on storage.objects for select to authenticated
using (
  bucket_id = 'case-documents'
  and exists (
    select 1 from public.ops_documents d
    join public.ops_cases c on c.id = d.case_id
    join public.ops_patients p on p.id = c.patient_id
    where d.storage_path = storage.objects.name
      and p.app_user_id = (select auth.uid())
      and p.portal_enabled = true
      and d.visible_to_patient = true
  )
);

alter table public.ops_cases drop constraint if exists ops_cases_priority_check;
alter table public.ops_cases add constraint ops_cases_priority_check
check (priority = any (array['LOW','NORMAL','HIGH','CRITICAL','Normal','High','Critical']::text[]));

alter table public.ops_tasks drop constraint if exists ops_tasks_priority_check;
alter table public.ops_tasks add constraint ops_tasks_priority_check
check (priority = any (array['LOW','NORMAL','HIGH','CRITICAL','Normal','High','Critical']::text[]));

alter table public.ops_billing drop constraint if exists ops_billing_status_check;
alter table public.ops_billing add constraint ops_billing_status_check
check (status = any (array['DUE','PARTIAL','PAID','VOID','CANCELLED','Due','Partial','Paid','Cancelled']::text[]));
