create extension if not exists pgcrypto;

create table if not exists public.ops_centers (
  id uuid primary key default gen_random_uuid(), name text not null unique, city text,
  active boolean not null default true, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.ops_staff (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null, role text not null check(role in ('Super admin','Coordinator','Finance','Center admin','Viewer')),
  scope text not null default 'All centers', active boolean not null default true,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.ops_patients (
  id uuid primary key default gen_random_uuid(), full_name text not null, phone text, email text,
  nationality text, country_of_residence text, city text, date_of_birth date, gender text,
  preferred_language text default 'English', center_id uuid references ops_centers(id) on delete set null,
  referred_by text, emergency_contact text, app_user_id uuid references auth.users(id) on delete set null,
  notes text, created_by uuid references auth.users(id) on delete set null, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.ops_cases (
  id uuid primary key default gen_random_uuid(), case_code text not null unique, patient_id uuid not null references ops_patients(id) on delete cascade,
  center_id uuid references ops_centers(id) on delete set null, specialty text, procedure text, hospital text,
  coordinator_id uuid references auth.users(id) on delete set null, priority text not null default 'Normal' check(priority in ('Normal','High','Critical')),
  source text, referred_by text, estimated_value numeric(14,2) not null default 0,
  status text not null default 'ENQUIRY' check(status in ('ENQUIRY','ASSESSMENT','QUOTATION','ACCEPTED','TRAVEL PLANNED','IN TREATMENT','DISCHARGED','FOLLOW UP')),
  notes text, created_by uuid references auth.users(id) on delete set null, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.ops_appointments (
  id uuid primary key default gen_random_uuid(), patient_id uuid not null references ops_patients(id) on delete cascade,
  case_id uuid references ops_cases(id) on delete set null, title text not null, doctor text, appointment_date date not null,
  appointment_time time, mode text, location text, status text not null default 'Scheduled' check(status in ('Scheduled','Confirmed','Completed','Cancelled')),
  notes text, created_by uuid references auth.users(id) on delete set null, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.ops_tasks (
  id uuid primary key default gen_random_uuid(), title text not null, patient_id uuid references ops_patients(id) on delete set null,
  case_id uuid references ops_cases(id) on delete set null, assigned_to uuid references auth.users(id) on delete set null,
  priority text not null default 'Normal' check(priority in ('Normal','High','Critical')), due_date date,
  status text not null default 'Open' check(status in ('Open','Completed','Cancelled')), notes text,
  created_by uuid references auth.users(id) on delete set null, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.ops_concierge (
  id uuid primary key default gen_random_uuid(), patient_id uuid not null references ops_patients(id) on delete cascade,
  case_id uuid references ops_cases(id) on delete set null, service_type text not null, details text,
  status text not null default 'Open', revenue numeric(14,2) not null default 0, assigned_to uuid references auth.users(id) on delete set null,
  service_date date, notes text, created_by uuid references auth.users(id) on delete set null, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.ops_billing (
  id uuid primary key default gen_random_uuid(), invoice_number text not null unique, patient_id uuid references ops_patients(id) on delete set null,
  case_id uuid references ops_cases(id) on delete set null, amount numeric(14,2) not null default 0, commission numeric(14,2) not null default 0,
  status text not null default 'Due' check(status in ('Due','Collected','Cancelled')), invoice_date date not null default current_date,
  notes text, created_by uuid references auth.users(id) on delete set null, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.ops_hospitals (id uuid primary key default gen_random_uuid(), name text not null, city text, specialty text, contact text, active boolean default true, created_at timestamptz default now());
create table if not exists public.ops_referrers (id uuid primary key default gen_random_uuid(), name text not null, organization text, contact text, active boolean default true, created_at timestamptz default now());

create or replace function public.ops_is_staff() returns boolean language sql stable security definer set search_path=public
as $$ select exists(select 1 from ops_staff where id=auth.uid() and active); $$;
create or replace function public.ops_is_admin() returns boolean language sql stable security definer set search_path=public
as $$ select exists(select 1 from ops_staff where id=auth.uid() and active and role in ('Super admin','Center admin')); $$;

alter table ops_centers enable row level security; alter table ops_staff enable row level security; alter table ops_patients enable row level security;
alter table ops_cases enable row level security; alter table ops_appointments enable row level security; alter table ops_tasks enable row level security;
alter table ops_concierge enable row level security; alter table ops_billing enable row level security; alter table ops_hospitals enable row level security; alter table ops_referrers enable row level security;

create policy "staff read centers" on ops_centers for select using(ops_is_staff());
create policy "admins write centers" on ops_centers for all using(ops_is_admin()) with check(ops_is_admin());
create policy "staff read staff" on ops_staff for select using(auth.uid()=id or ops_is_admin());
create policy "admins write staff" on ops_staff for all using(ops_is_admin()) with check(ops_is_admin());

do $$ declare t text; begin foreach t in array array['ops_patients','ops_cases','ops_appointments','ops_tasks','ops_concierge','ops_billing','ops_hospitals','ops_referrers'] loop
  execute format('create policy "staff read %s" on %I for select using(ops_is_staff())',t,t);
  execute format('create policy "staff insert %s" on %I for insert with check(ops_is_staff())',t,t);
  execute format('create policy "staff update %s" on %I for update using(ops_is_staff()) with check(ops_is_staff())',t,t);
  execute format('create policy "admins delete %s" on %I for delete using(ops_is_admin())',t,t);
end loop; end $$;

insert into ops_centers(name,city) values
('LIVYA Dubai (Master Center)','Dubai'),('LIVYA Muscat','Muscat'),('LIVYA Abu Dhabi','Abu Dhabi'),('LIVYA Al Ain','Al Ain'),('LIVYA Manama','Manama')
on conflict(name) do nothing;
