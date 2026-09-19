-- LIVYA Assist case workspace, adapted from the supplied LIVYA OPS domain model.
create table if not exists public.ops_case_events(id uuid primary key default gen_random_uuid(),case_id uuid not null references public.ops_cases(id) on delete cascade,actor_id uuid references auth.users(id) on delete set null,event_type text not null default 'NOTE',message text not null,created_at timestamptz not null default now());
create table if not exists public.ops_documents(id uuid primary key default gen_random_uuid(),case_id uuid not null references public.ops_cases(id) on delete cascade,category text not null default 'OTHER',file_name text not null,mime_type text,storage_path text not null default '',uploaded_by uuid references auth.users(id) on delete set null,visible_to_patient boolean not null default true,visible_to_hospital boolean not null default true,created_at timestamptz not null default now());
create table if not exists public.ops_quotations(id uuid primary key default gen_random_uuid(),case_id uuid not null references public.ops_cases(id) on delete cascade,hospital_id uuid references public.ops_hospitals(id) on delete set null,reference text,amount numeric(14,2) not null default 0,currency text not null default 'AED',valid_until date,status text not null default 'DRAFT' check(status in ('DRAFT','SENT','ACCEPTED','REJECTED','EXPIRED')),notes text,document_id uuid references public.ops_documents(id) on delete set null,created_by uuid references auth.users(id) on delete set null,created_at timestamptz not null default now(),updated_at timestamptz not null default now());
create table if not exists public.ops_quotation_items(id uuid primary key default gen_random_uuid(),quotation_id uuid not null references public.ops_quotations(id) on delete cascade,description text not null,quantity numeric(12,2) not null default 1,unit_price numeric(14,2) not null default 0,amount numeric(14,2) generated always as(quantity*unit_price) stored);
create table if not exists public.ops_itineraries(id uuid primary key default gen_random_uuid(),case_id uuid unique not null references public.ops_cases(id) on delete cascade,departure_city text,arrival_city text,departure_date date,return_date date,outbound_flight text,return_flight text,hotel_name text,hotel_check_in date,hotel_check_out date,visa_status text not null default 'PENDING',attendants integer not null default 0 check(attendants>=0),notes text,updated_at timestamptz not null default now());
create table if not exists public.ops_case_messages(id uuid primary key default gen_random_uuid(),case_id uuid not null references public.ops_cases(id) on delete cascade,sender_id uuid references auth.users(id) on delete set null,body text not null,visible_to_patient boolean not null default true,created_at timestamptz not null default now());

create index if not exists ops_case_events_case_idx on public.ops_case_events(case_id,created_at desc);
create index if not exists ops_documents_case_idx on public.ops_documents(case_id,created_at desc);
create index if not exists ops_quotations_case_idx on public.ops_quotations(case_id,created_at desc);
create index if not exists ops_quotation_items_quote_idx on public.ops_quotation_items(quotation_id);
create index if not exists ops_case_messages_case_idx on public.ops_case_messages(case_id,created_at);

alter table public.ops_case_events enable row level security;
alter table public.ops_documents enable row level security;
alter table public.ops_quotations enable row level security;
alter table public.ops_quotation_items enable row level security;
alter table public.ops_itineraries enable row level security;
alter table public.ops_case_messages enable row level security;

drop policy if exists "staff read case events" on public.ops_case_events;
drop policy if exists "staff write case events" on public.ops_case_events;
create policy "staff read case events" on public.ops_case_events for select using(ops_is_staff() and exists(select 1 from public.ops_cases c where c.id=case_id and ops_can_access_center(c.center_id)));
create policy "staff write case events" on public.ops_case_events for insert with check(ops_is_staff() and exists(select 1 from public.ops_cases c where c.id=case_id and ops_can_access_center(c.center_id)));

drop policy if exists "staff read documents" on public.ops_documents;
drop policy if exists "staff write documents" on public.ops_documents;
drop policy if exists "staff update documents" on public.ops_documents;
drop policy if exists "admins delete documents" on public.ops_documents;
create policy "staff read documents" on public.ops_documents for select using(ops_is_staff() and exists(select 1 from public.ops_cases c where c.id=case_id and ops_can_access_center(c.center_id)));
create policy "staff write documents" on public.ops_documents for insert with check(ops_is_staff() and exists(select 1 from public.ops_cases c where c.id=case_id and ops_can_access_center(c.center_id)));
create policy "staff update documents" on public.ops_documents for update using(ops_is_staff() and exists(select 1 from public.ops_cases c where c.id=case_id and ops_can_access_center(c.center_id))) with check(ops_is_staff() and exists(select 1 from public.ops_cases c where c.id=case_id and ops_can_access_center(c.center_id)));
create policy "admins delete documents" on public.ops_documents for delete using(ops_is_admin() and exists(select 1 from public.ops_cases c where c.id=case_id and ops_can_access_center(c.center_id)));

drop policy if exists "staff read quotations" on public.ops_quotations;
drop policy if exists "staff write quotations" on public.ops_quotations;
drop policy if exists "staff update quotations" on public.ops_quotations;
drop policy if exists "admins delete quotations" on public.ops_quotations;
create policy "staff read quotations" on public.ops_quotations for select using(ops_is_staff() and exists(select 1 from public.ops_cases c where c.id=case_id and ops_can_access_center(c.center_id)));
create policy "staff write quotations" on public.ops_quotations for insert with check(ops_is_staff() and exists(select 1 from public.ops_cases c where c.id=case_id and ops_can_access_center(c.center_id)));
create policy "staff update quotations" on public.ops_quotations for update using(ops_is_staff() and exists(select 1 from public.ops_cases c where c.id=case_id and ops_can_access_center(c.center_id))) with check(ops_is_staff() and exists(select 1 from public.ops_cases c where c.id=case_id and ops_can_access_center(c.center_id)));
create policy "admins delete quotations" on public.ops_quotations for delete using(ops_is_admin() and exists(select 1 from public.ops_cases c where c.id=case_id and ops_can_access_center(c.center_id)));

drop policy if exists "staff read quote items" on public.ops_quotation_items;
drop policy if exists "staff write quote items" on public.ops_quotation_items;
create policy "staff read quote items" on public.ops_quotation_items for select using(ops_is_staff() and exists(select 1 from public.ops_quotations q join public.ops_cases c on c.id=q.case_id where q.id=quotation_id and ops_can_access_center(c.center_id)));
create policy "staff write quote items" on public.ops_quotation_items for all using(ops_is_staff() and exists(select 1 from public.ops_quotations q join public.ops_cases c on c.id=q.case_id where q.id=quotation_id and ops_can_access_center(c.center_id))) with check(ops_is_staff() and exists(select 1 from public.ops_quotations q join public.ops_cases c on c.id=q.case_id where q.id=quotation_id and ops_can_access_center(c.center_id)));

drop policy if exists "staff read itineraries" on public.ops_itineraries;
drop policy if exists "staff write itineraries" on public.ops_itineraries;
create policy "staff read itineraries" on public.ops_itineraries for select using(ops_is_staff() and exists(select 1 from public.ops_cases c where c.id=case_id and ops_can_access_center(c.center_id)));
create policy "staff write itineraries" on public.ops_itineraries for all using(ops_is_staff() and exists(select 1 from public.ops_cases c where c.id=case_id and ops_can_access_center(c.center_id))) with check(ops_is_staff() and exists(select 1 from public.ops_cases c where c.id=case_id and ops_can_access_center(c.center_id)));

drop policy if exists "staff read case messages" on public.ops_case_messages;
drop policy if exists "staff write case messages" on public.ops_case_messages;
create policy "staff read case messages" on public.ops_case_messages for select using(ops_is_staff() and exists(select 1 from public.ops_cases c where c.id=case_id and ops_can_access_center(c.center_id)));
create policy "staff write case messages" on public.ops_case_messages for insert with check(ops_is_staff() and exists(select 1 from public.ops_cases c where c.id=case_id and ops_can_access_center(c.center_id)));

drop policy if exists "patients read visible events" on public.ops_case_events;
drop policy if exists "patients read visible documents" on public.ops_documents;
drop policy if exists "patients read visible quotations" on public.ops_quotations;
drop policy if exists "patients read quote items" on public.ops_quotation_items;
drop policy if exists "patients read itineraries" on public.ops_itineraries;
drop policy if exists "patients read visible messages" on public.ops_case_messages;
create policy "patients read visible events" on public.ops_case_events for select using(exists(select 1 from public.ops_cases c join public.ops_patients p on p.id=c.patient_id where c.id=case_id and p.app_user_id=auth.uid() and p.portal_enabled=true));
create policy "patients read visible documents" on public.ops_documents for select using(visible_to_patient and exists(select 1 from public.ops_cases c join public.ops_patients p on p.id=c.patient_id where c.id=case_id and p.app_user_id=auth.uid() and p.portal_enabled=true));
create policy "patients read visible quotations" on public.ops_quotations for select using(exists(select 1 from public.ops_cases c join public.ops_patients p on p.id=c.patient_id where c.id=case_id and p.app_user_id=auth.uid() and p.portal_enabled=true));
create policy "patients read quote items" on public.ops_quotation_items for select using(exists(select 1 from public.ops_quotations q join public.ops_cases c on c.id=q.case_id join public.ops_patients p on p.id=c.patient_id where q.id=quotation_id and p.app_user_id=auth.uid() and p.portal_enabled=true));
create policy "patients read itineraries" on public.ops_itineraries for select using(exists(select 1 from public.ops_cases c join public.ops_patients p on p.id=c.patient_id where c.id=case_id and p.app_user_id=auth.uid() and p.portal_enabled=true));
create policy "patients read visible messages" on public.ops_case_messages for select using(visible_to_patient and exists(select 1 from public.ops_cases c join public.ops_patients p on p.id=c.patient_id where c.id=case_id and p.app_user_id=auth.uid() and p.portal_enabled=true));

grant select,insert,update,delete on public.ops_case_events,public.ops_documents,public.ops_quotations,public.ops_quotation_items,public.ops_itineraries,public.ops_case_messages to authenticated;


-- Production hardening: role-aware writes, Super Admin full CRUD, indexes, timestamps and private document storage.
create or replace function public.ops_can_write(p_module text)
returns boolean language sql stable security definer set search_path=public
as $$
  select exists(
    select 1 from public.ops_staff s
    where s.id=auth.uid() and s.active and (
      s.role='Super admin'
      or (p_module in ('cases','patients','appointments','tasks','concierge','documents','quotations','travel','messages') and s.role in ('Coordinator','Center admin'))
      or (p_module='billing' and s.role='Finance')
      or (p_module in ('hospitals','referrers','centers') and s.role='Center admin')
    )
  );
$$;

-- Super Admin is the only role allowed to permanently remove operational records.
drop policy if exists "admins delete ops_patients" on public.ops_patients;
create policy "super admins delete ops_patients" on public.ops_patients for delete using(ops_is_super_admin());

drop policy if exists "admins delete ops_cases" on public.ops_cases;
create policy "super admins delete ops_cases" on public.ops_cases for delete using(ops_is_super_admin());

drop policy if exists "admins delete ops_appointments" on public.ops_appointments;
create policy "super admins delete ops_appointments" on public.ops_appointments for delete using(ops_is_super_admin());

drop policy if exists "admins delete ops_tasks" on public.ops_tasks;
create policy "super admins delete ops_tasks" on public.ops_tasks for delete using(ops_is_super_admin());

drop policy if exists "admins delete ops_concierge" on public.ops_concierge;
create policy "super admins delete ops_concierge" on public.ops_concierge for delete using(ops_is_super_admin());

drop policy if exists "admins delete ops_billing" on public.ops_billing;
create policy "super admins delete ops_billing" on public.ops_billing for delete using(ops_is_super_admin());

drop policy if exists "admins delete ops_hospitals" on public.ops_hospitals;
create policy "super admins delete ops_hospitals" on public.ops_hospitals for delete using(ops_is_super_admin());

drop policy if exists "admins delete ops_referrers" on public.ops_referrers;
create policy "super admins delete ops_referrers" on public.ops_referrers for delete using(ops_is_super_admin());

-- Centers are already Super Admin-only.
-- Case workspace destructive actions are Super Admin-only.
drop policy if exists "admins delete documents" on public.ops_documents;
create policy "super admins delete documents" on public.ops_documents for delete using(ops_is_super_admin());

drop policy if exists "admins delete quotations" on public.ops_quotations;
create policy "super admins delete quotations" on public.ops_quotations for delete using(ops_is_super_admin());

-- Quote items, itineraries and messages were previously broadly writable. Keep reads scoped, but restrict mutations.
drop policy if exists "staff write quote items" on public.ops_quotation_items;
create policy "staff write quote items" on public.ops_quotation_items for all
using(ops_is_super_admin() or (ops_can_write('quotations') and exists(select 1 from public.ops_quotations q join public.ops_cases c on c.id=q.case_id where q.id=quotation_id and ops_can_access_center(c.center_id))))
with check(ops_is_super_admin() or (ops_can_write('quotations') and exists(select 1 from public.ops_quotations q join public.ops_cases c on c.id=q.case_id where q.id=quotation_id and ops_can_access_center(c.center_id))));

drop policy if exists "staff write itineraries" on public.ops_itineraries;
create policy "staff write itineraries" on public.ops_itineraries for all
using(ops_is_super_admin() or (ops_can_write('travel') and exists(select 1 from public.ops_cases c where c.id=case_id and ops_can_access_center(c.center_id))))
with check(ops_is_super_admin() or (ops_can_write('travel') and exists(select 1 from public.ops_cases c where c.id=case_id and ops_can_access_center(c.center_id))));

drop policy if exists "staff write case events" on public.ops_case_events;
create policy "staff write case events" on public.ops_case_events for insert
with check(ops_is_super_admin() or (ops_can_write('cases') and exists(select 1 from public.ops_cases c where c.id=case_id and ops_can_access_center(c.center_id))));

drop policy if exists "staff write case messages" on public.ops_case_messages;
create policy "staff write case messages" on public.ops_case_messages for insert
with check(ops_is_super_admin() or (ops_can_write('messages') and exists(select 1 from public.ops_cases c where c.id=case_id and ops_can_access_center(c.center_id))));
drop policy if exists "staff update case messages" on public.ops_case_messages;
create policy "staff update case messages" on public.ops_case_messages for update
using(ops_is_super_admin() or (ops_can_write('messages') and exists(select 1 from public.ops_cases c where c.id=case_id and ops_can_access_center(c.center_id))))
with check(ops_is_super_admin() or (ops_can_write('messages') and exists(select 1 from public.ops_cases c where c.id=case_id and ops_can_access_center(c.center_id))));
create policy "super admins delete case messages" on public.ops_case_messages for delete using(ops_is_super_admin());

-- Operational indexes.
create index if not exists ops_patients_center_idx on public.ops_patients(center_id);
create index if not exists ops_cases_center_status_idx on public.ops_cases(center_id,status);
create index if not exists ops_cases_patient_idx on public.ops_cases(patient_id);
create index if not exists ops_cases_coordinator_idx on public.ops_cases(coordinator_id);
create index if not exists ops_appointments_case_date_idx on public.ops_appointments(case_id,appointment_date);
create index if not exists ops_appointments_patient_date_idx on public.ops_appointments(patient_id,appointment_date);
create index if not exists ops_tasks_case_due_idx on public.ops_tasks(case_id,due_date,status);
create index if not exists ops_tasks_assigned_due_idx on public.ops_tasks(assigned_to,due_date,status);
create index if not exists ops_concierge_case_idx on public.ops_concierge(case_id);
create index if not exists ops_billing_case_status_idx on public.ops_billing(case_id,status);
create index if not exists ops_billing_patient_status_idx on public.ops_billing(patient_id,status);
create index if not exists ops_hospitals_name_idx on public.ops_hospitals(name);
create index if not exists ops_referrers_name_idx on public.ops_referrers(name);

-- Consistent updated_at behavior.
create or replace function public.ops_touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at=now();
  return new;
end;
$$;
do $$
declare t text;
begin
  foreach t in array array['ops_centers','ops_staff','ops_patients','ops_cases','ops_appointments','ops_tasks','ops_concierge','ops_billing']
  loop
    execute format('drop trigger if exists %I_updated_at on public.%I',t,t);
    execute format('create trigger %I_updated_at before update on public.%I for each row execute function public.ops_touch_updated_at()',t,t);
  end loop;
end $$;

-- Private bucket for case documents. Files are never public.
insert into storage.buckets(id,name,public)
values('case-documents','case-documents',false)
on conflict(id) do update set public=false;

drop policy if exists "staff read case document files" on storage.objects;
drop policy if exists "staff upload case document files" on storage.objects;
drop policy if exists "super admins delete case document files" on storage.objects;
create policy "staff read case document files" on storage.objects for select
using(bucket_id='case-documents' and ops_is_staff());
create policy "staff upload case document files" on storage.objects for insert
with check(bucket_id='case-documents' and ops_can_write('documents'));
create policy "super admins delete case document files" on storage.objects for delete
using(bucket_id='case-documents' and ops_is_super_admin());


-- Replace broad staff write policies with role-aware write policies.
do $$
declare
  t text;
  module text;
begin
  foreach t in array array['ops_patients','ops_cases','ops_appointments','ops_tasks','ops_concierge','ops_billing']
  loop
    execute format('drop policy if exists "staff insert %s" on public.%I',t,t);
    execute format('drop policy if exists "staff update %s" on public.%I',t,t);
  end loop;
end $$;

drop policy if exists "staff insert ops_patients" on public.ops_patients;
drop policy if exists "staff update ops_patients" on public.ops_patients;
create policy "role insert ops_patients" on public.ops_patients for insert with check(ops_can_write('patients') and ops_can_access_center(center_id));
create policy "role update ops_patients" on public.ops_patients for update using(ops_can_write('patients') and ops_can_access_center(center_id)) with check(ops_can_write('patients') and ops_can_access_center(center_id));

drop policy if exists "staff insert ops_cases" on public.ops_cases;
drop policy if exists "staff update ops_cases" on public.ops_cases;
create policy "role insert ops_cases" on public.ops_cases for insert with check(ops_can_write('cases') and ops_can_access_center(center_id));
create policy "role update ops_cases" on public.ops_cases for update using(ops_can_write('cases') and ops_can_access_center(center_id)) with check(ops_can_write('cases') and ops_can_access_center(center_id));

drop policy if exists "staff insert ops_appointments" on public.ops_appointments;
drop policy if exists "staff update ops_appointments" on public.ops_appointments;
create policy "role insert ops_appointments" on public.ops_appointments for insert with check(ops_can_write('appointments') and exists(select 1 from ops_patients p where p.id=patient_id and ops_can_access_center(p.center_id)));
create policy "role update ops_appointments" on public.ops_appointments for update using(ops_can_write('appointments') and exists(select 1 from ops_patients p where p.id=patient_id and ops_can_access_center(p.center_id))) with check(ops_can_write('appointments') and exists(select 1 from ops_patients p where p.id=patient_id and ops_can_access_center(p.center_id)));

drop policy if exists "staff insert ops_tasks" on public.ops_tasks;
drop policy if exists "staff update ops_tasks" on public.ops_tasks;
create policy "role insert ops_tasks" on public.ops_tasks for insert with check(ops_can_write('tasks') and (patient_id is null or exists(select 1 from ops_patients p where p.id=patient_id and ops_can_access_center(p.center_id))) and (case_id is null or exists(select 1 from ops_cases c where c.id=case_id and ops_can_access_center(c.center_id))));
create policy "role update ops_tasks" on public.ops_tasks for update using(ops_can_write('tasks') and (patient_id is null or exists(select 1 from ops_patients p where p.id=patient_id and ops_can_access_center(p.center_id))) and (case_id is null or exists(select 1 from ops_cases c where c.id=case_id and ops_can_access_center(c.center_id)))) with check(ops_can_write('tasks') and (patient_id is null or exists(select 1 from ops_patients p where p.id=patient_id and ops_can_access_center(p.center_id))) and (case_id is null or exists(select 1 from ops_cases c where c.id=case_id and ops_can_access_center(c.center_id))));

drop policy if exists "staff insert ops_concierge" on public.ops_concierge;
drop policy if exists "staff update ops_concierge" on public.ops_concierge;
create policy "role insert ops_concierge" on public.ops_concierge for insert with check(ops_can_write('concierge') and exists(select 1 from ops_patients p where p.id=patient_id and ops_can_access_center(p.center_id)));
create policy "role update ops_concierge" on public.ops_concierge for update using(ops_can_write('concierge') and exists(select 1 from ops_patients p where p.id=patient_id and ops_can_access_center(p.center_id))) with check(ops_can_write('concierge') and exists(select 1 from ops_patients p where p.id=patient_id and ops_can_access_center(p.center_id)));

drop policy if exists "staff insert ops_billing" on public.ops_billing;
drop policy if exists "staff update ops_billing" on public.ops_billing;
create policy "role insert ops_billing" on public.ops_billing for insert with check(ops_can_write('billing') and (patient_id is null or exists(select 1 from ops_patients p where p.id=patient_id and ops_can_access_center(p.center_id))) and (case_id is null or exists(select 1 from ops_cases c where c.id=case_id and ops_can_access_center(c.center_id))));
create policy "role update ops_billing" on public.ops_billing for update using(ops_can_write('billing') and (patient_id is null or exists(select 1 from ops_patients p where p.id=patient_id and ops_can_access_center(p.center_id))) and (case_id is null or exists(select 1 from ops_cases c where c.id=case_id and ops_can_access_center(c.center_id)))) with check(ops_can_write('billing') and (patient_id is null or exists(select 1 from ops_patients p where p.id=patient_id and ops_can_access_center(p.center_id))) and (case_id is null or exists(select 1 from ops_cases c where c.id=case_id and ops_can_access_center(c.center_id))));

-- Shared reference data: only Super Admin and Center Admin can maintain it.
drop policy if exists "staff insert ops_hospitals" on public.ops_hospitals;
drop policy if exists "staff update ops_hospitals" on public.ops_hospitals;
create policy "role insert ops_hospitals" on public.ops_hospitals for insert with check(ops_can_write('hospitals'));
create policy "role update ops_hospitals" on public.ops_hospitals for update using(ops_can_write('hospitals')) with check(ops_can_write('hospitals'));

drop policy if exists "staff insert ops_referrers" on public.ops_referrers;
drop policy if exists "staff update ops_referrers" on public.ops_referrers;
create policy "role insert ops_referrers" on public.ops_referrers for insert with check(ops_can_write('referrers'));
create policy "role update ops_referrers" on public.ops_referrers for update using(ops_can_write('referrers')) with check(ops_can_write('referrers'));
