-- LIVYA Client + Admin Platform
-- New, standalone Supabase project. Does not reference the existing Livya HIMS project.

create extension if not exists pgcrypto;
create schema if not exists private;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  phone text,
  email text,
  role text not null default 'client' check (role in ('client','doctor','care_agent','admin','super_admin')),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.patients (
  patient_id text primary key,
  user_id uuid unique references auth.users(id) on delete set null,
  name text not null,
  gender text,
  date_of_birth date,
  mobile text,
  email text,
  city text,
  abha_number text,
  abha_status text not null default 'Pending',
  status text not null default 'ACTIVE',
  plan text not null default 'Care Basic',
  risk_level text not null default 'Stable',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.metabolic_clients (
  id uuid primary key default gen_random_uuid(),
  patient_id text unique references public.patients(patient_id) on delete cascade,
  client_user_id uuid unique references auth.users(id) on delete set null,
  record_number text,
  full_name text not null,
  phone text,
  email text,
  sex text,
  age_years integer,
  status text not null default 'ACTIVE',
  plan text not null default 'Care Basic',
  city text default 'Chennai',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.vital_readings (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.metabolic_clients(id) on delete cascade,
  type text not null,
  value text not null,
  unit text,
  context text,
  source text not null default 'manual',
  recorded_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table if not exists public.hydration_logs (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.metabolic_clients(id) on delete cascade,
  amount_ml integer not null check (amount_ml > 0),
  logged_at timestamptz not null default now()
);

create table if not exists public.devices (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.metabolic_clients(id) on delete cascade,
  name text not null,
  provider text,
  device_type text,
  status text not null default 'connected',
  last_synced_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.medicines (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  strength text,
  form text default 'Tablet',
  sku text,
  stock integer not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.patient_medicines (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.metabolic_clients(id) on delete cascade,
  medicine_id uuid references public.medicines(id) on delete set null,
  medicine_name text not null,
  dose text,
  frequency text,
  times text[] default '{}',
  start_date date,
  duration_days integer,
  adherence numeric(5,2) default 0,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.medication_logs (
  id uuid primary key default gen_random_uuid(),
  patient_medicine_id uuid not null references public.patient_medicines(id) on delete cascade,
  scheduled_at timestamptz not null,
  taken_at timestamptz,
  status text not null default 'upcoming' check (status in ('upcoming','taken','missed','skipped')),
  created_at timestamptz not null default now()
);

create table if not exists public.health_records (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.metabolic_clients(id) on delete cascade,
  title text not null,
  record_type text not null default 'Lab report',
  record_date date default current_date,
  storage_path text,
  ai_status text not null default 'Pending',
  review_status text not null default 'Pending',
  client_visible boolean not null default false,
  extracted jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.prescriptions (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.metabolic_clients(id) on delete cascade,
  doctor_id uuid references auth.users(id) on delete set null,
  rx_number text unique,
  status text not null default 'Draft',
  medicines jsonb not null default '[]'::jsonb,
  notes text,
  prescribed_at timestamptz not null default now()
);

create table if not exists public.programmes (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  duration_weeks integer not null,
  description text,
  status text not null default 'Draft',
  created_at timestamptz not null default now()
);

create table if not exists public.client_programmes (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.metabolic_clients(id) on delete cascade,
  programme_id uuid not null references public.programmes(id) on delete cascade,
  start_date date,
  week integer not null default 1,
  next_review date,
  status text not null default 'Active',
  unique(client_id, programme_id)
);

create table if not exists public.diet_plans (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.metabolic_clients(id) on delete cascade,
  title text not null,
  calories integer,
  protein_g numeric,
  water_l numeric,
  notes text,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.recipes (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  category text,
  calories integer,
  protein_g numeric,
  instructions text,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.therapies (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  therapist text,
  mode text,
  capacity integer default 0,
  price numeric(12,2) default 0,
  active boolean not null default true
);

create table if not exists public.appointments (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.metabolic_clients(id) on delete cascade,
  therapist text,
  service text not null,
  starts_at timestamptz not null,
  ends_at timestamptz,
  location text,
  status text not null default 'Confirmed',
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists public.lab_partners (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  tests_count integer default 0,
  collection_area text,
  turnaround_hours integer,
  active boolean not null default true
);

create table if not exists public.lab_bookings (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.metabolic_clients(id) on delete cascade,
  partner_id uuid references public.lab_partners(id) on delete set null,
  tests text[] not null default '{}',
  slot_at timestamptz,
  amount numeric(12,2) default 0,
  status text not null default 'Booked',
  created_at timestamptz not null default now()
);

create table if not exists public.store_products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category text,
  price numeric(12,2) not null default 0,
  stock integer not null default 0,
  active boolean not null default true
);

create table if not exists public.store_orders (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.metabolic_clients(id) on delete cascade,
  order_number text unique not null,
  items jsonb not null default '[]'::jsonb,
  amount numeric(12,2) not null default 0,
  pharmacy text,
  status text not null default 'Processing',
  created_at timestamptz not null default now()
);

create table if not exists public.emergency_contacts (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.metabolic_clients(id) on delete cascade,
  name text not null,
  phone text not null,
  relation text
);

create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.metabolic_clients(id) on delete cascade,
  assigned_to uuid references auth.users(id) on delete set null,
  status text not null default 'open',
  created_at timestamptz not null default now()
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.metabolic_clients(id) on delete cascade,
  title text not null,
  body text,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references auth.users(id) on delete set null,
  action text not null,
  entity_type text,
  entity_id text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create or replace function private.current_role() returns text
language sql stable security definer set search_path = public, pg_temp
as $$
  select coalesce((select role from public.profiles where id = auth.uid() and active = true), 'client')
$$;

create or replace function private.is_staff() returns boolean
language sql stable security definer set search_path = public, pg_temp
as $$
  select private.current_role() in ('doctor','care_agent','admin','super_admin')
$$;

create or replace function private.handle_new_user() returns trigger
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  insert into public.profiles(id, full_name, phone, email)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name',''), new.phone, new.email)
  on conflict (id) do update set email = excluded.email, phone = excluded.phone;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute function private.handle_new_user();

create or replace function private.prevent_non_admin_role_change() returns trigger
language plpgsql security invoker
as $$
begin
  if old.role is distinct from new.role and private.current_role() not in ('admin','super_admin') then
    raise exception 'Only an administrator can change roles';
  end if;
  return new;
end;
$$;

drop trigger if exists protect_profile_role on public.profiles;
create trigger protect_profile_role before update on public.profiles
for each row execute function private.prevent_non_admin_role_change();

-- RLS
DO $$ declare t text; begin
  foreach t in array array['profiles','patients','metabolic_clients','vital_readings','hydration_logs','devices','medicines','patient_medicines','medication_logs','health_records','prescriptions','programmes','client_programmes','diet_plans','recipes','therapies','appointments','lab_partners','lab_bookings','store_products','store_orders','emergency_contacts','conversations','messages','notifications','audit_logs'] loop
    execute format('alter table public.%I enable row level security', t);
  end loop;
end $$;

-- Profile access
drop policy if exists profiles_self_select on public.profiles;
create policy profiles_self_select on public.profiles for select to authenticated using (id = auth.uid() or private.is_staff());
drop policy if exists profiles_self_update on public.profiles;
create policy profiles_self_update on public.profiles for update to authenticated using (id = auth.uid() or private.current_role() in ('admin','super_admin')) with check (id = auth.uid() or private.current_role() in ('admin','super_admin'));

-- Patient/client directory
drop policy if exists patients_client_select on public.patients;
create policy patients_client_select on public.patients for select to authenticated using (user_id = auth.uid() or private.is_staff());
drop policy if exists patients_staff_write on public.patients;
create policy patients_staff_write on public.patients for all to authenticated using (private.is_staff()) with check (private.is_staff());

drop policy if exists clients_own_select on public.metabolic_clients;
create policy clients_own_select on public.metabolic_clients for select to authenticated using (client_user_id = auth.uid() or private.is_staff());
drop policy if exists clients_staff_write on public.metabolic_clients;
create policy clients_staff_write on public.metabolic_clients for all to authenticated using (private.is_staff()) with check (private.is_staff());

drop policy if exists clients_own_update on public.metabolic_clients;
create policy clients_own_update on public.metabolic_clients for update to authenticated using (client_user_id = auth.uid()) with check (client_user_id = auth.uid());

-- Client-owned records
drop policy if exists vitals_select on public.vital_readings;
create policy vitals_select on public.vital_readings for select to authenticated using ((exists(select 1 from public.metabolic_clients c where c.id=client_id and c.client_user_id=auth.uid())) or private.is_staff());
drop policy if exists vitals_insert on public.vital_readings;
create policy vitals_insert on public.vital_readings for insert to authenticated with check ((exists(select 1 from public.metabolic_clients c where c.id=client_id and c.client_user_id=auth.uid())) or private.is_staff());
drop policy if exists vitals_update on public.vital_readings;
create policy vitals_update on public.vital_readings for update to authenticated using ((exists(select 1 from public.metabolic_clients c where c.id=client_id and c.client_user_id=auth.uid())) or private.is_staff()) with check ((exists(select 1 from public.metabolic_clients c where c.id=client_id and c.client_user_id=auth.uid())) or private.is_staff());
drop policy if exists vitals_delete on public.vital_readings;
create policy vitals_delete on public.vital_readings for delete to authenticated using (private.is_staff());

drop policy if exists hydration_all on public.hydration_logs;
create policy hydration_all on public.hydration_logs for all to authenticated using ((exists(select 1 from public.metabolic_clients c where c.id=client_id and c.client_user_id=auth.uid())) or private.is_staff()) with check ((exists(select 1 from public.metabolic_clients c where c.id=client_id and c.client_user_id=auth.uid())) or private.is_staff());
drop policy if exists devices_all on public.devices;
create policy devices_all on public.devices for all to authenticated using ((exists(select 1 from public.metabolic_clients c where c.id=client_id and c.client_user_id=auth.uid())) or private.is_staff()) with check ((exists(select 1 from public.metabolic_clients c where c.id=client_id and c.client_user_id=auth.uid())) or private.is_staff());
drop policy if exists patient_meds_all on public.patient_medicines;
create policy patient_meds_all on public.patient_medicines for all to authenticated using ((exists(select 1 from public.metabolic_clients c where c.id=client_id and c.client_user_id=auth.uid())) or private.is_staff()) with check ((exists(select 1 from public.metabolic_clients c where c.id=client_id and c.client_user_id=auth.uid())) or private.is_staff());
drop policy if exists medication_logs_all on public.medication_logs;
create policy medication_logs_all on public.medication_logs for all to authenticated using ((exists(select 1 from public.patient_medicines pm join public.metabolic_clients c on c.id=pm.client_id where pm.id=patient_medicine_id and (c.client_user_id=auth.uid() or private.is_staff())))) with check ((exists(select 1 from public.patient_medicines pm join public.metabolic_clients c on c.id=pm.client_id where pm.id=patient_medicine_id and (c.client_user_id=auth.uid() or private.is_staff()))));
drop policy if exists health_records_select on public.health_records;
create policy health_records_select on public.health_records for select to authenticated using ((exists(select 1 from public.metabolic_clients c where c.id=client_id and c.client_user_id=auth.uid())) or private.is_staff());
drop policy if exists health_records_insert on public.health_records;
create policy health_records_insert on public.health_records for insert to authenticated with check (private.is_staff() or exists(select 1 from public.metabolic_clients c where c.id=client_id and c.client_user_id=auth.uid()));
drop policy if exists health_records_update on public.health_records;
create policy health_records_update on public.health_records for update to authenticated using (private.is_staff()) with check (private.is_staff());
drop policy if exists health_records_delete on public.health_records;
create policy health_records_delete on public.health_records for delete to authenticated using (private.is_staff());
drop policy if exists prescriptions_select on public.prescriptions;
create policy prescriptions_select on public.prescriptions for select to authenticated using ((exists(select 1 from public.metabolic_clients c where c.id=client_id and c.client_user_id=auth.uid())) or private.is_staff());
drop policy if exists prescriptions_staff_write on public.prescriptions;
create policy prescriptions_staff_write on public.prescriptions for all to authenticated using (private.is_staff()) with check (private.is_staff());
drop policy if exists client_programmes_select on public.client_programmes;
create policy client_programmes_select on public.client_programmes for select to authenticated using ((exists(select 1 from public.metabolic_clients c where c.id=client_id and c.client_user_id=auth.uid())) or private.is_staff());
drop policy if exists client_programmes_staff_write on public.client_programmes;
create policy client_programmes_staff_write on public.client_programmes for all to authenticated using (private.is_staff()) with check (private.is_staff());
drop policy if exists diet_plans_select on public.diet_plans;
create policy diet_plans_select on public.diet_plans for select to authenticated using ((exists(select 1 from public.metabolic_clients c where c.id=client_id and c.client_user_id=auth.uid())) or private.is_staff());
drop policy if exists diet_plans_staff_write on public.diet_plans;
create policy diet_plans_staff_write on public.diet_plans for all to authenticated using (private.is_staff()) with check (private.is_staff());
drop policy if exists appointments_all on public.appointments;
create policy appointments_all on public.appointments for all to authenticated using ((exists(select 1 from public.metabolic_clients c where c.id=client_id and c.client_user_id=auth.uid())) or private.is_staff()) with check ((exists(select 1 from public.metabolic_clients c where c.id=client_id and c.client_user_id=auth.uid())) or private.is_staff());
drop policy if exists lab_bookings_all on public.lab_bookings;
create policy lab_bookings_all on public.lab_bookings for all to authenticated using ((exists(select 1 from public.metabolic_clients c where c.id=client_id and c.client_user_id=auth.uid())) or private.is_staff()) with check ((exists(select 1 from public.metabolic_clients c where c.id=client_id and c.client_user_id=auth.uid())) or private.is_staff());
drop policy if exists store_orders_all on public.store_orders;
create policy store_orders_all on public.store_orders for all to authenticated using ((exists(select 1 from public.metabolic_clients c where c.id=client_id and c.client_user_id=auth.uid())) or private.is_staff()) with check ((exists(select 1 from public.metabolic_clients c where c.id=client_id and c.client_user_id=auth.uid())) or private.is_staff());
drop policy if exists emergency_all on public.emergency_contacts;
create policy emergency_all on public.emergency_contacts for all to authenticated using ((exists(select 1 from public.metabolic_clients c where c.id=client_id and c.client_user_id=auth.uid())) or private.is_staff()) with check ((exists(select 1 from public.metabolic_clients c where c.id=client_id and c.client_user_id=auth.uid())) or private.is_staff());
drop policy if exists conversations_all on public.conversations;
create policy conversations_all on public.conversations for all to authenticated using ((exists(select 1 from public.metabolic_clients c where c.id=client_id and c.client_user_id=auth.uid())) or private.is_staff()) with check ((exists(select 1 from public.metabolic_clients c where c.id=client_id and c.client_user_id=auth.uid())) or private.is_staff());
drop policy if exists messages_all on public.messages;
create policy messages_all on public.messages for all to authenticated using ((sender_id=auth.uid() and exists(select 1 from public.conversations cv join public.metabolic_clients c on c.id=cv.client_id where cv.id=conversation_id and (c.client_user_id=auth.uid() or private.is_staff()))) or private.is_staff()) with check (sender_id=auth.uid() and ((exists(select 1 from public.conversations cv join public.metabolic_clients c on c.id=cv.client_id where cv.id=conversation_id and c.client_user_id=auth.uid())) or private.is_staff()));
drop policy if exists notifications_all on public.notifications;
create policy notifications_all on public.notifications for all to authenticated using ((exists(select 1 from public.metabolic_clients c where c.id=client_id and c.client_user_id=auth.uid())) or private.is_staff()) with check ((exists(select 1 from public.metabolic_clients c where c.id=client_id and c.client_user_id=auth.uid())) or private.is_staff());

-- Staff-managed catalogue tables
drop policy if exists medicines_select on public.medicines;
create policy medicines_select on public.medicines for select to authenticated using (true);
drop policy if exists medicines_staff_write on public.medicines;
create policy medicines_staff_write on public.medicines for all to authenticated using (private.is_staff()) with check (private.is_staff());
drop policy if exists programmes_select on public.programmes;
create policy programmes_select on public.programmes for select to authenticated using (true);
drop policy if exists programmes_staff_write on public.programmes;
create policy programmes_staff_write on public.programmes for all to authenticated using (private.is_staff()) with check (private.is_staff());
drop policy if exists recipes_select on public.recipes;
create policy recipes_select on public.recipes for select to authenticated using (true);
drop policy if exists recipes_staff_write on public.recipes;
create policy recipes_staff_write on public.recipes for all to authenticated using (private.is_staff()) with check (private.is_staff());
drop policy if exists therapies_select on public.therapies;
create policy therapies_select on public.therapies for select to authenticated using (true);
drop policy if exists therapies_staff_write on public.therapies;
create policy therapies_staff_write on public.therapies for all to authenticated using (private.is_staff()) with check (private.is_staff());
drop policy if exists labs_select on public.lab_partners;
create policy labs_select on public.lab_partners for select to authenticated using (true);
drop policy if exists labs_staff_write on public.lab_partners;
create policy labs_staff_write on public.lab_partners for all to authenticated using (private.is_staff()) with check (private.is_staff());
drop policy if exists store_products_select on public.store_products;
create policy store_products_select on public.store_products for select to authenticated using (true);
drop policy if exists store_products_staff_write on public.store_products;
create policy store_products_staff_write on public.store_products for all to authenticated using (private.is_staff()) with check (private.is_staff());

-- Audit logs are staff-readable; inserts are staff-only.
drop policy if exists audit_staff_select on public.audit_logs;
create policy audit_staff_select on public.audit_logs for select to authenticated using (private.is_staff());
drop policy if exists audit_staff_insert on public.audit_logs;
create policy audit_staff_insert on public.audit_logs for insert to authenticated with check (private.is_staff());

-- Useful indexes
create index if not exists idx_clients_user on public.metabolic_clients(client_user_id);
create index if not exists idx_clients_patient on public.metabolic_clients(patient_id);
create index if not exists idx_vitals_client_time on public.vital_readings(client_id, recorded_at desc);
create index if not exists idx_hydration_client_time on public.hydration_logs(client_id, logged_at desc);
create index if not exists idx_records_client_date on public.health_records(client_id, record_date desc);
create index if not exists idx_appointments_client_time on public.appointments(client_id, starts_at);
create index if not exists idx_messages_conversation_time on public.messages(conversation_id, created_at);

-- Browser clients use the Data API with RLS as the authorization boundary.
grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;

-- Private document bucket for clinical uploads. File access is still constrained by authenticated ownership/staff policies.
insert into storage.buckets(id,name,public) values ('livya-records','livya-records',false) on conflict(id) do nothing;
drop policy if exists livya_records_select on storage.objects;
drop policy if exists livya_records_insert on storage.objects;
create policy livya_records_select on storage.objects for select to authenticated using (bucket_id='livya-records' and (private.is_staff() or (name like auth.uid()::text || '/%')));
create policy livya_records_insert on storage.objects for insert to authenticated with check (bucket_id='livya-records' and (private.is_staff() or (name like auth.uid()::text || '/%')));

-- Starter catalogue. Safe to re-run.
insert into public.programmes(name,duration_weeks,description,status) values
('Metabolic Reset',52,'Twelve-month metabolic health programme.','Published'),
('Diabetes Care',26,'Structured diabetes monitoring and coaching.','Published'),
('Heart Health',12,'Blood pressure and cardiovascular risk programme.','Published')
on conflict(name) do nothing;

insert into public.therapies(name,therapist,mode,capacity,price) values
('Yoga therapy','Karthik V.','In-hub / online',8,4800),
('Physiotherapy','Arun P., BPT','In-hub / home',10,2700),
('Ayurveda','Dr. Nithya','In-hub',6,3500)
on conflict do nothing;

insert into public.lab_partners(name,tests_count,collection_area,turnaround_hours) values
('Aarogya Diagnostics',412,'Chennai',24),
('PulseDx Labs',386,'Chennai',12)
on conflict(name) do nothing;
