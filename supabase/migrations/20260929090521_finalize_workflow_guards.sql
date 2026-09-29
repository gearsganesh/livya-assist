-- Finalize trigger permissions and lock commercial fields after quotation acceptance.

create or replace function private.ops_validate_case_write()
returns trigger language plpgsql security definer set search_path=''
as $function$
declare v_patient_center uuid; v_context text:=coalesce(pg_catalog.current_setting('livya.workflow_context',true),'');
begin
  if new.patient_id is null then raise exception 'Case patient is required'; end if;
  select center_id into v_patient_center from public.ops_patients where id=new.patient_id;
  if not found then raise exception 'Case patient not found'; end if;
  if new.center_id is null then raise exception 'Case center is required'; end if;
  if v_patient_center is not null and v_patient_center<>new.center_id then raise exception 'Case patient and center must match'; end if;
  if tg_op='UPDATE' then
    if new.status is distinct from old.status and v_context not in ('CASE_TRANSITION','QUOTATION_ACCEPT') then
      raise exception 'Case status changes must use ops_transition_case';
    end if;
    if old.status in ('ACCEPTED','TRAVEL_PLANNED','IN_TREATMENT','DISCHARGED','FOLLOW_UP','CLOSED','CANCELLED')
       and v_context<>'QUOTATION_ACCEPT'
       and (new.hospital_id is distinct from old.hospital_id or new.estimated_value is distinct from old.estimated_value) then
      raise exception 'Hospital and accepted value are locked after quotation acceptance';
    end if;
  end if;
  if new.hospital_id is not null and not exists(select 1 from public.ops_hospitals h where h.id=new.hospital_id) then
    raise exception 'Case hospital not found';
  end if;
  return new;
end
$function$;

create or replace function private.ops_validate_quotation_write()
returns trigger language plpgsql security definer set search_path=''
as $function$
declare v_context text:=coalesce(pg_catalog.current_setting('livya.workflow_context',true),'');
begin
  if new.case_id is null then raise exception 'Quotation case is required'; end if;
  if not exists(select 1 from public.ops_cases c where c.id=new.case_id) then raise exception 'Quotation case not found'; end if;
  if tg_op='UPDATE' then
    if new.case_id is distinct from old.case_id then raise exception 'Quotation case cannot be changed'; end if;
    if new.created_by is distinct from old.created_by then raise exception 'Quotation creator cannot be changed'; end if;
    if new.status is distinct from old.status and v_context<>'QUOTATION_ACCEPT' then
      raise exception 'Quotation status changes must use the quotation workflow';
    end if;
    if old.status in ('ACCEPTED','REJECTED')
       and (new.amount is distinct from old.amount or new.hospital_id is distinct from old.hospital_id
            or new.currency is distinct from old.currency or new.case_id is distinct from old.case_id) then
      raise exception 'Commercial fields are locked after quotation decision';
    end if;
    if public.ops_role()='HOSPITAL_USER' then
      if new.hospital_id is distinct from old.hospital_id or new.amount is distinct from old.amount
         or new.currency is distinct from old.currency or new.document_id is distinct from old.document_id
         or new.status is distinct from old.status then
        raise exception 'Hospital users cannot modify protected quotation fields';
      end if;
    end if;
  end if;
  if new.hospital_id is not null and not exists(select 1 from public.ops_hospitals h where h.id=new.hospital_id) then
    raise exception 'Quotation hospital not found';
  end if;
  return new;
end
$function$;

revoke all on function private.ops_validate_case_write() from public,anon;
revoke all on function private.ops_validate_quotation_write() from public,anon;
revoke all on function private.ops_validate_appointment_write() from public,anon;
revoke all on function private.ops_validate_document_write() from public,anon;
revoke all on function private.ops_validate_message_write() from public,anon;

grant execute on function private.ops_validate_case_write() to authenticated,service_role;
grant execute on function private.ops_validate_quotation_write() to authenticated,service_role;
grant execute on function private.ops_validate_appointment_write() to authenticated,service_role;
grant execute on function private.ops_validate_document_write() to authenticated,service_role;
grant execute on function private.ops_validate_message_write() to authenticated,service_role;
