create extension if not exists pgcrypto;

create table if not exists public.ops_centers (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  city text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.ops_staff (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  role text not null check(role in ('Super admin','Coordinator','Finance','Center admin','Viewer')),
  scope text not null default 'All centers',
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.ops_patients (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  phone text,
  email text,
  nationality text,
  country_of_residence text,
  city text,
  date_of_birth date,
  gender text,
  preferred_language text default 'English',
  center_id uuid references ops_centers(id) on delete set null,
  referred_by text,
  emergency_contact text,
  app_user_id uuid references auth.users(id) on delete set null,
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.ops_cases (
  id uuid primary key default gen_random_uuid(),
  case_code text not null unique,
  patient_id uuid not null references ops_patients(id) on delete cascade,
  center_id uuid references ops_centers(id) on delete set null,
  specialty text,
  procedure text,
  hospital text,
  coordinator_id uuid references auth.users(id) on delete set null,
  priority text not null default 'Normal' check(priority in ('Normal','High','Critical')),
  source text,
  referred_by text,
  estimated_value numeric(14,2) not null default 0,
  status text not null default 'ENQUIRY' check(status in ('ENQUIRY','ASSESSMENT','QUOTATION','ACCEPTED','TRAVEL PLANNED','IN TREATMENT','DISCHARGED','FOLLOW UP')),
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.ops_appointments (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references ops_patients(id) on delete cascade,
  case_id uuid references ops_cases(id) on delete set null,
  title text not null,
  doctor text,
  appointment_date date not null,
  appointment_time time,
  mode text,
  location text,
  status text not null default 'Scheduled' check(status in ('Scheduled','Confirmed','Completed','Cancelled')),
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.ops_tasks (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  patient_id uuid references ops_patients(id) on delete set null,
  case_id uuid references ops_cases(id) on delete set null,
  assigned_to uuid references auth.users(id) on delete set null,
  priority text not null default 'Normal' check(priority in ('Normal','High','Critical')),
  due_date date,
  status text not null default 'Open' check(status in ('Open','Completed','Cancelled')),
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.ops_concierge (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references ops_patients(id) on delete cascade,
  case_id uuid references ops_cases(id) on delete set null,
  service_type text not null,
  details text,
  status text not null default 'Open',
  revenue numeric(14,2) not null default 0,
  assigned_to uuid references auth.users(id) on delete set null,
  service_date date,
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.ops_billing (
  id uuid primary key default gen_random_uuid(),
  invoice_number text not null unique,
  patient_id uuid references ops_patients(id) on delete set null,
  case_id uuid references ops_cases(id) on delete set null,
  amount numeric(14,2) not null default 0,
  commission numeric(14,2) not null default 0,
  status text not null default 'Due' check(status in ('Due','Collected','Cancelled')),
  invoice_date date not null default current_date,
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.ops_hospitals (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  city text,
  specialty text,
  contact text,
  active boolean default true,
  created_at timestamptz default now()
);

create table if not exists public.ops_referrers (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  organization text,
  contact text,
  active boolean default true,
  created_at timestamptz default now()
);

create or replace function public.ops_is_staff()
returns boolean language sql stable security definer set search_path=public
as $$
  select exists(select 1 from ops_staff where id=auth.uid() and active);
$$;

create or replace function public.ops_is_super_admin()
returns boolean language sql stable security definer set search_path=public
as $$
  select exists(select 1 from ops_staff where id=auth.uid() and active and role='Super admin');
$$;

create or replace function public.ops_is_admin()
returns boolean language sql stable security definer set search_path=public
as $$
  select exists(select 1 from ops_staff where id=auth.uid() and active and role in ('Super admin','Center admin'));
$$;

create or replace function public.ops_scope()
returns text language sql stable security definer set search_path=public
as $$
  select scope from ops_staff where id=auth.uid() and active limit 1;
$$;

create or replace function public.ops_can_access_center(p_center_id uuid)
returns boolean language sql stable security definer set search_path=public
as $$
  select
    ops_is_super_admin()
    or ops_scope()='All centers'
    or exists(
      select 1 from ops_centers c
      where c.id=p_center_id and c.name=ops_scope()
    );
$$;

alter table ops_centers enable row level security;
alter table ops_staff enable row level security;
alter table ops_patients enable row level security;
alter table ops_cases enable row level security;
alter table ops_appointments enable row level security;
alter table ops_tasks enable row level security;
alter table ops_concierge enable row level security;
alter table ops_billing enable row level security;
alter table ops_hospitals enable row level security;
alter table ops_referrers enable row level security;

-- Centers are visible to active staff. Only admins can change them.
drop policy if exists "staff read centers" on ops_centers;
drop policy if exists "admins write centers" on ops_centers;
create policy "staff read centers" on ops_centers for select using(ops_is_staff());
create policy "admins write centers" on ops_centers for all using(ops_is_admin()) with check(ops_is_admin());

-- Staff can see themselves; Super Admins can manage the full staff directory.
drop policy if exists "staff read staff" on ops_staff;
drop policy if exists "admins write staff" on ops_staff;
create policy "staff read staff" on ops_staff for select using(auth.uid()=id or ops_is_super_admin());
create policy "super admins write staff" on ops_staff for all using(ops_is_super_admin()) with check(ops_is_super_admin());

-- Patient and case access is center-scoped. Global-scope staff can access all centers.
drop policy if exists "staff read ops_patients" on ops_patients;
drop policy if exists "staff insert ops_patients" on ops_patients;
drop policy if exists "staff update ops_patients" on ops_patients;
drop policy if exists "admins delete ops_patients" on ops_patients;
create policy "staff read ops_patients" on ops_patients for select using(ops_is_staff() and ops_can_access_center(center_id));
create policy "staff insert ops_patients" on ops_patients for insert with check(ops_is_staff() and ops_can_access_center(center_id));
create policy "staff update ops_patients" on ops_patients for update using(ops_is_staff() and ops_can_access_center(center_id)) with check(ops_is_staff() and ops_can_access_center(center_id));
create policy "admins delete ops_patients" on ops_patients for delete using(ops_is_admin() and ops_can_access_center(center_id));

drop policy if exists "staff read ops_cases" on ops_cases;
drop policy if exists "staff insert ops_cases" on ops_cases;
drop policy if exists "staff update ops_cases" on ops_cases;
drop policy if exists "admins delete ops_cases" on ops_cases;
create policy "staff read ops_cases" on ops_cases for select using(ops_is_staff() and ops_can_access_center(center_id));
create policy "staff insert ops_cases" on ops_cases for insert with check(ops_is_staff() and ops_can_access_center(center_id));
create policy "staff update ops_cases" on ops_cases for update using(ops_is_staff() and ops_can_access_center(center_id)) with check(ops_is_staff() and ops_can_access_center(center_id));
create policy "admins delete ops_cases" on ops_cases for delete using(ops_is_admin() and ops_can_access_center(center_id));

-- Related operational records inherit access from their patient/case center.
drop policy if exists "staff read ops_appointments" on ops_appointments;
drop policy if exists "staff insert ops_appointments" on ops_appointments;
drop policy if exists "staff update ops_appointments" on ops_appointments;
drop policy if exists "admins delete ops_appointments" on ops_appointments;
create policy "staff read ops_appointments" on ops_appointments for select using(ops_is_staff() and exists(select 1 from ops_patients p where p.id=patient_id and ops_can_access_center(p.center_id)));
create policy "staff insert ops_appointments" on ops_appointments for insert with check(ops_is_staff() and exists(select 1 from ops_patients p where p.id=patient_id and ops_can_access_center(p.center_id)));
create policy "staff update ops_appointments" on ops_appointments for update using(ops_is_staff() and exists(select 1 from ops_patients p where p.id=patient_id and ops_can_access_center(p.center_id))) with check(ops_is_staff() and exists(select 1 from ops_patients p where p.id=patient_id and ops_can_access_center(p.center_id)));
create policy "admins delete ops_appointments" on ops_appointments for delete using(ops_is_admin() and exists(select 1 from ops_patients p where p.id=patient_id and ops_can_access_center(p.center_id)));

drop policy if exists "staff read ops_tasks" on ops_tasks;
drop policy if exists "staff insert ops_tasks" on ops_tasks;
drop policy if exists "staff update ops_tasks" on ops_tasks;
drop policy if exists "admins delete ops_tasks" on ops_tasks;
create policy "staff read ops_tasks" on ops_tasks for select using(ops_is_staff() and (patient_id is null or exists(select 1 from ops_patients p where p.id=patient_id and ops_can_access_center(p.center_id))) and (case_id is null or exists(select 1 from ops_cases c where c.id=case_id and ops_can_access_center(c.center_id))));
create policy "staff insert ops_tasks" on ops_tasks for insert with check(ops_is_staff() and (patient_id is null or exists(select 1 from ops_patients p where p.id=patient_id and ops_can_access_center(p.center_id))) and (case_id is null or exists(select 1 from ops_cases c where c.id=case_id and ops_can_access_center(c.center_id))));
create policy "staff update ops_tasks" on ops_tasks for update using(ops_is_staff() and (patient_id is null or exists(select 1 from ops_patients p where p.id=patient_id and ops_can_access_center(p.center_id))) and (case_id is null or exists(select 1 from ops_cases c where c.id=case_id and ops_can_access_center(c.center_id)))) with check(ops_is_staff() and (patient_id is null or exists(select 1 from ops_patients p where p.id=patient_id and ops_can_access_center(p.center_id))) and (case_id is null or exists(select 1 from ops_cases c where c.id=case_id and ops_can_access_center(c.center_id))));
create policy "admins delete ops_tasks" on ops_tasks for delete using(ops_is_admin() and (patient_id is null or exists(select 1 from ops_patients p where p.id=patient_id and ops_can_access_center(p.center_id))) and (case_id is null or exists(select 1 from ops_cases c where c.id=case_id and ops_can_access_center(c.center_id))));

drop policy if exists "staff read ops_concierge" on ops_concierge;
drop policy if exists "staff insert ops_concierge" on ops_concierge;
drop policy if exists "staff update ops_concierge" on ops_concierge;
drop policy if exists "admins delete ops_concierge" on ops_concierge;
create policy "staff read ops_concierge" on ops_concierge for select using(ops_is_staff() and exists(select 1 from ops_patients p where p.id=patient_id and ops_can_access_center(p.center_id)));
create policy "staff insert ops_concierge" on ops_concierge for insert with check(ops_is_staff() and exists(select 1 from ops_patients p where p.id=patient_id and ops_can_access_center(p.center_id)));
create policy "staff update ops_concierge" on ops_concierge for update using(ops_is_staff() and exists(select 1 from ops_patients p where p.id=patient_id and ops_can_access_center(p.center_id))) with check(ops_is_staff() and exists(select 1 from ops_patients p where p.id=patient_id and ops_can_access_center(p.center_id)));
create policy "admins delete ops_concierge" on ops_concierge for delete using(ops_is_admin() and exists(select 1 from ops_patients p where p.id=patient_id and ops_can_access_center(p.center_id)));

drop policy if exists "staff read ops_billing" on ops_billing;
drop policy if exists "staff insert ops_billing" on ops_billing;
drop policy if exists "staff update ops_billing" on ops_billing;
drop policy if exists "admins delete ops_billing" on ops_billing;
create policy "staff read ops_billing" on ops_billing for select using(ops_is_staff() and (patient_id is null or exists(select 1 from ops_patients p where p.id=patient_id and ops_can_access_center(p.center_id))) and (case_id is null or exists(select 1 from ops_cases c where c.id=case_id and ops_can_access_center(c.center_id))));
create policy "staff insert ops_billing" on ops_billing for insert with check(ops_is_staff() and (patient_id is null or exists(select 1 from ops_patients p where p.id=patient_id and ops_can_access_center(p.center_id))) and (case_id is null or exists(select 1 from ops_cases c where c.id=case_id and ops_can_access_center(c.center_id))));
create policy "staff update ops_billing" on ops_billing for update using(ops_is_staff() and (patient_id is null or exists(select 1 from ops_patients p where p.id=patient_id and ops_can_access_center(p.center_id))) and (case_id is null or exists(select 1 from ops_cases c where c.id=case_id and ops_can_access_center(c.center_id)))) with check(ops_is_staff() and (patient_id is null or exists(select 1 from ops_patients p where p.id=patient_id and ops_can_access_center(p.center_id))) and (case_id is null or exists(select 1 from ops_cases c where c.id=case_id and ops_can_access_center(c.center_id))));
create policy "admins delete ops_billing" on ops_billing for delete using(ops_is_admin() and (patient_id is null or exists(select 1 from ops_patients p where p.id=patient_id and ops_can_access_center(p.center_id))) and (case_id is null or exists(select 1 from ops_cases c where c.id=case_id and ops_can_access_center(c.center_id))));

-- Hospital and referral directories are shared reference data.
drop policy if exists "staff read ops_hospitals" on ops_hospitals;
drop policy if exists "staff insert ops_hospitals" on ops_hospitals;
drop policy if exists "staff update ops_hospitals" on ops_hospitals;
drop policy if exists "admins delete ops_hospitals" on ops_hospitals;
create policy "staff read ops_hospitals" on ops_hospitals for select using(ops_is_staff());
create policy "staff insert ops_hospitals" on ops_hospitals for insert with check(ops_is_staff());
create policy "staff update ops_hospitals" on ops_hospitals for update using(ops_is_staff()) with check(ops_is_staff());
create policy "admins delete ops_hospitals" on ops_hospitals for delete using(ops_is_admin());

drop policy if exists "staff read ops_referrers" on ops_referrers;
drop policy if exists "staff insert ops_referrers" on ops_referrers;
drop policy if exists "staff update ops_referrers" on ops_referrers;
drop policy if exists "admins delete ops_referrers" on ops_referrers;
create policy "staff read ops_referrers" on ops_referrers for select using(ops_is_staff());
create policy "staff insert ops_referrers" on ops_referrers for insert with check(ops_is_staff());
create policy "staff update ops_referrers" on ops_referrers for update using(ops_is_staff()) with check(ops_is_staff());
create policy "admins delete ops_referrers" on ops_referrers for delete using(ops_is_admin());

insert into ops_centers(name,city) values
('LIVYA Dubai (Master Center)','Dubai'),
('LIVYA Muscat','Muscat'),
('LIVYA Abu Dhabi','Abu Dhabi'),
('LIVYA Al Ain','Al Ain'),
('LIVYA Manama','Manama')
on conflict(name) do nothing;


-- Data API privileges for browser clients. RLS remains the authorization boundary.
grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on public.ops_centers, public.ops_staff, public.ops_patients, public.ops_cases, public.ops_appointments, public.ops_tasks, public.ops_concierge, public.ops_billing, public.ops_hospitals, public.ops_referrers to authenticated;
