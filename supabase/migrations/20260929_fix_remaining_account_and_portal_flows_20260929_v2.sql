-- Fix remaining LIVYA account and portal flows
create or replace function public.ops_update_patient_profile(p_full_name text,p_phone text default null,p_city text default null,p_preferred_language text default null,p_notes text default null)
returns public.ops_patients language plpgsql security definer set search_path=''
as $$
declare v public.ops_patients;
begin
 select * into v from public.ops_patients where app_user_id=auth.uid() and portal_enabled=true limit 1 for update;
 if not found then raise exception 'Patient profile access denied'; end if;
 if nullif(btrim(coalesce(p_full_name,'')),'') is null then raise exception 'Full name is required'; end if;
 update public.ops_patients set full_name=btrim(p_full_name),phone=nullif(btrim(coalesce(p_phone,'')),''),city=nullif(btrim(coalesce(p_city,'')),''),preferred_language=coalesce(nullif(btrim(coalesce(p_preferred_language,'')),''),preferred_language),notes=nullif(btrim(coalesce(p_notes,'')),''),updated_at=now() where id=v.id returning * into v;
 return v;
end
$$;
revoke all on function public.ops_update_patient_profile(text,text,text,text,text) from public,anon;
grant execute on function public.ops_update_patient_profile(text,text,text,text,text) to authenticated,service_role;

drop policy if exists "patient update own profile" on public.ops_patients;

drop policy if exists "staff read staff" on public.ops_staff;
create policy "staff read staff" on public.ops_staff for select to authenticated using (
 auth.uid()=id or private.ops_is_super_admin() or (
   upper(public.ops_role())='CENTER_MANAGER'
   and center_id is not null
   and private.ops_can_access_center(center_id)
 )
);

drop policy if exists "hospital read patients" on public.ops_patients;
create policy "hospital read patients" on public.ops_patients for select to authenticated using (
 public.ops_role()='HOSPITAL_USER'
 and exists (
   select 1 from public.ops_cases c
   where c.patient_id=ops_patients.id
     and c.hospital_id=private.ops_hospital_id()
 )
);

drop policy if exists "authenticated read ops_billing" on public.ops_billing;
create policy "authenticated read ops_billing" on public.ops_billing for select to authenticated using (
 (
   exists (
     select 1 from public.ops_patients p
     where p.id=ops_billing.patient_id
       and p.app_user_id=auth.uid()
       and p.portal_enabled=true
   )
   and upper(coalesce(ops_billing.type,'')) in ('CONCIERGE','ANCILLARY')
 )
 or (
   private.ops_is_staff()
   and (
     patient_id is null
     or exists (
       select 1 from public.ops_patients p
       where p.id=ops_billing.patient_id
         and private.ops_can_access_center(p.center_id)
     )
   )
   and (
     case_id is null
     or exists (
       select 1 from public.ops_cases c
       where c.id=ops_billing.case_id
         and private.ops_can_access_center(c.center_id)
     )
   )
 )
);
