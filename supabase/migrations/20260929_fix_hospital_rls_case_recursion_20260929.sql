-- Prevent hospital-user RLS recursion when policies traverse ops_cases.
-- The helper functions are SECURITY DEFINER so policy checks can inspect
-- the case linkage without recursively re-entering ops_cases RLS.

create or replace function private.ops_case_in_hospital(p_case_id uuid)
returns boolean
language sql
stable
security definer
set search_path=''
as $function$
  select exists(
    select 1
    from public.ops_cases c
    where c.id = p_case_id
      and c.hospital_id = private.ops_hospital_id()
  );
$function$;

create or replace function private.ops_patient_has_hospital_case(p_patient_id uuid)
returns boolean
language sql
stable
security definer
set search_path=''
as $function$
  select exists(
    select 1
    from public.ops_cases c
    where c.patient_id = p_patient_id
      and c.hospital_id = private.ops_hospital_id()
  );
$function$;

revoke all on function private.ops_case_in_hospital(uuid) from public;
revoke all on function private.ops_patient_has_hospital_case(uuid) from public;
grant execute on function private.ops_case_in_hospital(uuid) to authenticated, service_role;
grant execute on function private.ops_patient_has_hospital_case(uuid) to authenticated, service_role;

drop policy if exists "hospital read appointments" on public.ops_appointments;
create policy "hospital read appointments"
on public.ops_appointments for select to authenticated
using (ops_role() = 'HOSPITAL_USER' and private.ops_case_in_hospital(case_id));

drop policy if exists "hospital write appointments" on public.ops_appointments;
create policy "hospital write appointments"
on public.ops_appointments for all to authenticated
using (ops_role() = 'HOSPITAL_USER' and private.ops_case_in_hospital(case_id))
with check (ops_role() = 'HOSPITAL_USER' and private.ops_case_in_hospital(case_id));

drop policy if exists "hospital read patients" on public.ops_patients;
create policy "hospital read patients"
on public.ops_patients for select to authenticated
using (ops_role() = 'HOSPITAL_USER' and private.ops_patient_has_hospital_case(id));

drop policy if exists "hospital read messages" on public.ops_case_messages;
create policy "hospital read messages"
on public.ops_case_messages for select to authenticated
using (ops_role() = 'HOSPITAL_USER' and private.ops_case_in_hospital(case_id));

drop policy if exists "hospital write messages" on public.ops_case_messages;
create policy "hospital write messages"
on public.ops_case_messages for insert to authenticated
with check (ops_role() = 'HOSPITAL_USER' and private.ops_case_in_hospital(case_id));

drop policy if exists "hospital read documents" on public.ops_documents;
create policy "hospital read documents"
on public.ops_documents for select to authenticated
using (ops_role() = 'HOSPITAL_USER' and visible_to_hospital and private.ops_case_in_hospital(case_id));

drop policy if exists "hospital write documents" on public.ops_documents;
create policy "hospital write documents"
on public.ops_documents for insert to authenticated
with check (ops_role() = 'HOSPITAL_USER' and private.ops_case_in_hospital(case_id));

drop policy if exists "hospital read itineraries" on public.ops_itineraries;
create policy "hospital read itineraries"
on public.ops_itineraries for select to authenticated
using (ops_role() = 'HOSPITAL_USER' and private.ops_case_in_hospital(case_id));

drop policy if exists "hospital write itineraries" on public.ops_itineraries;
create policy "hospital write itineraries"
on public.ops_itineraries for all to authenticated
using (ops_role() = 'HOSPITAL_USER' and private.ops_case_in_hospital(case_id))
with check (ops_role() = 'HOSPITAL_USER' and private.ops_case_in_hospital(case_id));

drop policy if exists "hospital read quotations" on public.ops_quotations;
create policy "hospital read quotations"
on public.ops_quotations for select to authenticated
using (ops_role() = 'HOSPITAL_USER' and private.ops_case_in_hospital(case_id));

drop policy if exists "hospital update quotations" on public.ops_quotations;
create policy "hospital update quotations"
on public.ops_quotations for update to authenticated
using (ops_role() = 'HOSPITAL_USER' and private.ops_case_in_hospital(case_id))
with check (ops_role() = 'HOSPITAL_USER' and private.ops_case_in_hospital(case_id));
