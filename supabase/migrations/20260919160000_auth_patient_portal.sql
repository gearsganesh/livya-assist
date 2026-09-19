-- LIVYA auth and patient portal hardening
alter table public.ops_staff add column if not exists email text;
alter table public.ops_patients add column if not exists portal_enabled boolean not null default false;

create unique index if not exists ops_patients_app_user_id_uidx
  on public.ops_patients(app_user_id)
  where app_user_id is not null;

update public.ops_staff s
set email = u.email
from auth.users u
where u.id = s.id
  and (s.email is null or s.email = '');

alter table public.ops_staff enable row level security;
alter table public.ops_patients enable row level security;
alter table public.ops_cases enable row level security;
alter table public.ops_appointments enable row level security;
alter table public.ops_concierge enable row level security;
alter table public.ops_billing enable row level security;

drop policy if exists "patient read own profile" on public.ops_patients;
create policy "patient read own profile"
on public.ops_patients for select
using (app_user_id = auth.uid() and portal_enabled = true);

drop policy if exists "patient read own cases" on public.ops_cases;
create policy "patient read own cases"
on public.ops_cases for select
using (exists (
  select 1 from public.ops_patients p
  where p.id = patient_id and p.app_user_id = auth.uid() and p.portal_enabled = true
));

drop policy if exists "patient read own appointments" on public.ops_appointments;
create policy "patient read own appointments"
on public.ops_appointments for select
using (exists (
  select 1 from public.ops_patients p
  where p.id = patient_id and p.app_user_id = auth.uid() and p.portal_enabled = true
));

drop policy if exists "patient read own concierge" on public.ops_concierge;
create policy "patient read own concierge"
on public.ops_concierge for select
using (exists (
  select 1 from public.ops_patients p
  where p.id = patient_id and p.app_user_id = auth.uid() and p.portal_enabled = true
));

drop policy if exists "patient read own billing" on public.ops_billing;
create policy "patient read own billing"
on public.ops_billing for select
using (exists (
  select 1 from public.ops_patients p
  where p.id = patient_id and p.app_user_id = auth.uid() and p.portal_enabled = true
));


drop policy if exists "patient read own center" on public.ops_centers;
create policy "patient read own center" on public.ops_centers for select using (exists (select 1 from public.ops_patients p where p.center_id = ops_centers.id and p.app_user_id = auth.uid() and p.portal_enabled = true));
