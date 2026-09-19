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
