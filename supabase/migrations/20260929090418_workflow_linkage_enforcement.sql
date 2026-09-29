-- Consolidate LIVYA workflow enforcement and linkage checks.
-- This migration makes the database authoritative for lifecycle changes and
-- closes the remaining cross-record write paths found in the frontend audit.

create or replace function private.ops_set_workflow_context(p_context text)
returns void language plpgsql security definer set search_path=''
as $function$
begin
  if p_context not in ('CASE_TRANSITION','QUOTATION_ACCEPT') then
    raise exception 'Invalid workflow context';
  end if;
  perform pg_catalog.set_config('livya.workflow_context', p_context, true);
end
$function$;

revoke all on function private.ops_set_workflow_context(text) from public, anon, authenticated;
grant execute on function private.ops_set_workflow_context(text) to service_role;

create or replace function private.ops_validate_case_write()
returns trigger language plpgsql security definer set search_path=''
as $function$
declare v_patient_center uuid;
begin
  if new.patient_id is null then raise exception 'Case patient is required'; end if;
  select center_id into v_patient_center from public.ops_patients where id=new.patient_id;
  if not found then raise exception 'Case patient not found'; end if;
  if new.center_id is null then raise exception 'Case center is required'; end if;
  if v_patient_center is not null and v_patient_center<>new.center_id then
    raise exception 'Case patient and center must match';
  end if;
  if tg_op='UPDATE' and new.status is distinct from old.status
     and coalesce(pg_catalog.current_setting('livya.workflow_context',true),'') not in ('CASE_TRANSITION','QUOTATION_ACCEPT') then
    raise exception 'Case status changes must use ops_transition_case';
  end if;
  if new.hospital_id is not null and not exists(select 1 from public.ops_hospitals h where h.id=new.hospital_id) then
    raise exception 'Case hospital not found';
  end if;
  return new;
end
$function$;

drop trigger if exists trg_ops_validate_case_write on public.ops_cases;
create trigger trg_ops_validate_case_write
before insert or update on public.ops_cases
for each row execute function private.ops_validate_case_write();

create or replace function private.ops_validate_quotation_write()
returns trigger language plpgsql security definer set search_path=''
as $function$
begin
  if new.case_id is null then raise exception 'Quotation case is required'; end if;
  if not exists(select 1 from public.ops_cases c where c.id=new.case_id) then raise exception 'Quotation case not found'; end if;
  if tg_op='UPDATE' then
    if new.case_id is distinct from old.case_id then raise exception 'Quotation case cannot be changed'; end if;
    if new.created_by is distinct from old.created_by then raise exception 'Quotation creator cannot be changed'; end if;
    if new.status is distinct from old.status
       and coalesce(pg_catalog.current_setting('livya.workflow_context',true),'')<>'QUOTATION_ACCEPT' then
      raise exception 'Quotation status changes must use the quotation workflow';
    end if;
    if public.ops_role()='HOSPITAL_USER' then
      if new.hospital_id is distinct from old.hospital_id
         or new.amount is distinct from old.amount
         or new.currency is distinct from old.currency
         or new.document_id is distinct from old.document_id
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

drop trigger if exists trg_ops_validate_quotation_write on public.ops_quotations;
create trigger trg_ops_validate_quotation_write
before insert or update on public.ops_quotations
for each row execute function private.ops_validate_quotation_write();

create or replace function private.ops_validate_appointment_write()
returns trigger language plpgsql security definer set search_path=''
as $function$
declare v_case_patient uuid; v_case_hospital uuid;
begin
  if new.case_id is not null then
    select patient_id,hospital_id into v_case_patient,v_case_hospital from public.ops_cases where id=new.case_id;
    if not found then raise exception 'Appointment case not found'; end if;
    if v_case_patient<>new.patient_id then raise exception 'Appointment patient must match case patient'; end if;
    if public.ops_role()='HOSPITAL_USER' and v_case_hospital<>private.ops_hospital_id() then
      raise exception 'Hospital appointment must belong to the hospital case';
    end if;
  end if;
  return new;
end
$function$;

drop trigger if exists trg_ops_validate_appointment_write on public.ops_appointments;
create trigger trg_ops_validate_appointment_write
before insert or update on public.ops_appointments
for each row execute function private.ops_validate_appointment_write();

create or replace function private.ops_validate_document_write()
returns trigger language plpgsql security definer set search_path=''
as $function$
begin
  if tg_op='INSERT' and auth.uid() is not null and new.uploaded_by is distinct from auth.uid() then
    raise exception 'Document uploader must be the signed-in user';
  end if;
  if new.case_id is null or not exists(select 1 from public.ops_cases c where c.id=new.case_id) then
    raise exception 'Document case not found';
  end if;
  return new;
end
$function$;

drop trigger if exists trg_ops_validate_document_write on public.ops_documents;
create trigger trg_ops_validate_document_write
before insert or update on public.ops_documents
for each row execute function private.ops_validate_document_write();

create or replace function private.ops_validate_message_write()
returns trigger language plpgsql security definer set search_path=''
as $function$
begin
  if tg_op='INSERT' and auth.uid() is not null and new.sender_id is distinct from auth.uid() then
    raise exception 'Message sender must be the signed-in user';
  end if;
  if new.case_id is null or not exists(select 1 from public.ops_cases c where c.id=new.case_id) then
    raise exception 'Message case not found';
  end if;
  return new;
end
$function$;

drop trigger if exists trg_ops_validate_message_write on public.ops_case_messages;
create trigger trg_ops_validate_message_write
before insert on public.ops_case_messages
for each row execute function private.ops_validate_message_write();

create or replace function public.ops_transition_case(p_case_id uuid,p_target text,p_message text default null)
returns public.ops_cases language plpgsql security definer set search_path=''
as $function$
declare v_case public.ops_cases; v_target text:=upper(replace(p_target,' ','_')); v_from text;
begin
  select * into v_case from public.ops_cases where id=p_case_id for update;
  if not found then raise exception 'Case not found'; end if;
  if public.ops_role()='HOSPITAL_USER' then
    if v_case.hospital_id is null or v_case.hospital_id<>private.ops_hospital_id() then raise exception 'Case access denied'; end if;
  else
    if not private.ops_can_access_center(v_case.center_id) then raise exception 'Case access denied'; end if;
  end if;
  if not private.ops_can_write('cases') and public.ops_role()<>'HOSPITAL_USER' then raise exception 'Case write access denied'; end if;
  v_from:=upper(replace(v_case.status,' ','_'));
  if public.ops_role()='HOSPITAL_USER' and v_target not in('IN_TREATMENT','DISCHARGED') then
    raise exception 'Hospital users can only move cases to treatment or discharge';
  end if;
  if not public.ops_case_stage_allowed(v_from,v_target) and public.ops_role()<>'SUPER_ADMIN' then
    raise exception 'Invalid case transition: % -> %',v_from,v_target;
  end if;
  perform private.ops_set_workflow_context('CASE_TRANSITION');
  update public.ops_cases set status=v_target,
    closed_at=case when v_target='CLOSED' then now() else closed_at end,
    cancelled_at=case when v_target='CANCELLED' then now() else cancelled_at end,
    updated_at=now() where id=p_case_id returning * into v_case;
  insert into public.ops_case_events(case_id,actor_id,event_type,message)
  values(p_case_id,auth.uid(),'STAGE_CHANGE',coalesce(p_message,format('Case moved from %s to %s',v_from,v_target)));
  return v_case;
end
$function$;

create or replace function public.ops_accept_quotation(p_quotation_id uuid)
returns public.ops_quotations language plpgsql security definer set search_path=''
as $function$
declare v_q public.ops_quotations; v_case public.ops_cases;
begin
  select * into v_q from public.ops_quotations where id=p_quotation_id for update;
  if not found then raise exception 'Quotation not found'; end if;
  select * into v_case from public.ops_cases where id=v_q.case_id for update;
  if not private.ops_can_access_center(v_case.center_id) or not private.ops_can_write('cases') then
    raise exception 'Quotation acceptance denied';
  end if;
  perform private.ops_set_workflow_context('QUOTATION_ACCEPT');
  update public.ops_quotations set status='ACCEPTED',updated_at=now() where id=p_quotation_id returning * into v_q;
  update public.ops_quotations set status='REJECTED',updated_at=now()
  where case_id=v_q.case_id and id<>v_q.id and status in('DRAFT','SENT');
  update public.ops_cases set hospital_id=v_q.hospital_id,
    hospital=(select name from public.ops_hospitals where id=v_q.hospital_id),
    estimated_value=v_q.amount,status='ACCEPTED',updated_at=now() where id=v_q.case_id;
  if not exists(select 1 from public.ops_billing b where b.case_id=v_q.case_id and b.type='HOSPITAL_COMMISSION' and b.status<>'VOID') then
    perform public.ops_create_hospital_commission_invoice(v_q.case_id,v_q.amount,current_date,'Auto-created from accepted quotation '||coalesce(v_q.reference,v_q.id::text));
  end if;
  insert into public.ops_case_events(case_id,actor_id,event_type,message)
  values(v_q.case_id,auth.uid(),'QUOTATION_ACCEPTED',format('Quotation %s accepted',coalesce(v_q.reference,v_q.id::text)));
  return v_q;
end
$function$;

create or replace function private.ops_case_patient_matches(p_case_id uuid,p_patient_id uuid)
returns boolean language sql stable security definer set search_path=''
as $function$
  select exists(select 1 from public.ops_cases c where c.id=p_case_id and c.patient_id=p_patient_id);
$function$;

revoke all on function private.ops_case_patient_matches(uuid,uuid) from public;
grant execute on function private.ops_case_patient_matches(uuid,uuid) to authenticated,service_role;

drop policy if exists "hospital write appointments" on public.ops_appointments;
create policy "hospital write appointments" on public.ops_appointments for all to authenticated
using(ops_role()='HOSPITAL_USER' and private.ops_case_in_hospital(case_id) and private.ops_case_patient_matches(case_id,patient_id))
with check(ops_role()='HOSPITAL_USER' and private.ops_case_in_hospital(case_id) and private.ops_case_patient_matches(case_id,patient_id));

drop policy if exists "hospital write documents" on public.ops_documents;
create policy "hospital write documents" on public.ops_documents for insert to authenticated
with check(ops_role()='HOSPITAL_USER' and private.ops_case_in_hospital(case_id) and uploaded_by=(select auth.uid()));

drop policy if exists "hospital write messages" on public.ops_case_messages;
create policy "hospital write messages" on public.ops_case_messages for insert to authenticated
with check(ops_role()='HOSPITAL_USER' and private.ops_case_in_hospital(case_id) and sender_id=(select auth.uid()));

alter table public.ops_case_sequences enable row level security;
drop policy if exists "authenticated read case sequences" on public.ops_case_sequences;
drop policy if exists "authenticated write case sequences" on public.ops_case_sequences;
drop policy if exists "service role case sequences" on public.ops_case_sequences;
revoke all on table public.ops_case_sequences from anon,authenticated;
grant all on table public.ops_case_sequences to service_role;

create or replace function public.ops_create_invoice(p_case_id uuid,p_type text,p_amount numeric,p_patient_id uuid default null,p_hospital_id uuid default null,p_rate_pct numeric default null,p_due_date date default null,p_notes text default null)
returns public.ops_billing language plpgsql security definer set search_path=''
as $function$
declare v public.ops_billing; v_case public.ops_cases; v_commission numeric:=0;
begin
  select * into v_case from public.ops_cases where id=p_case_id;
  if not found then raise exception 'Case not found'; end if;
  if not private.ops_can_access_center(v_case.center_id) then raise exception 'Invoice access denied'; end if;
  if public.ops_role() not in('SUPER_ADMIN','CENTER_MANAGER','COORDINATOR') then raise exception 'Invoice creation denied'; end if;
  if p_patient_id is not null and p_patient_id<>v_case.patient_id then raise exception 'Invoice patient must match case patient'; end if;
  if upper(p_type)='HOSPITAL_COMMISSION' then
    if p_hospital_id is null or p_hospital_id<>v_case.hospital_id then raise exception 'Hospital commission must use the case hospital'; end if;
    v_commission:=coalesce(p_amount,0);
  elsif p_hospital_id is not null and v_case.hospital_id is not null and p_hospital_id<>v_case.hospital_id then
    raise exception 'Invoice hospital does not match case hospital';
  end if;
  insert into public.ops_billing(invoice_number,type,patient_id,case_id,hospital_id,gross_amount,amount,commission,rate_pct,paid_amount,currency,status,invoice_date,due_date,notes,created_by)
  values(public.ops_next_invoice_number(),upper(p_type),coalesce(p_patient_id,v_case.patient_id),p_case_id,p_hospital_id,coalesce(p_amount,0),coalesce(p_amount,0),v_commission,p_rate_pct,0,coalesce(v_case.currency,'AED'),'DUE',current_date,p_due_date,p_notes,auth.uid())
  returning * into v;
  return v;
end
$function$;

create index if not exists ops_cases_patient_center_idx on public.ops_cases(patient_id,center_id);
create index if not exists ops_appointments_case_patient_idx on public.ops_appointments(case_id,patient_id);
create index if not exists ops_quotations_case_hospital_idx on public.ops_quotations(case_id,hospital_id);

revoke all on function private.ops_validate_case_write() from public,anon,authenticated;
revoke all on function private.ops_validate_quotation_write() from public,anon,authenticated;
revoke all on function private.ops_validate_appointment_write() from public,anon,authenticated;
revoke all on function private.ops_validate_document_write() from public,anon,authenticated;
revoke all on function private.ops_validate_message_write() from public,anon,authenticated;
grant execute on function private.ops_validate_case_write() to service_role;
grant execute on function private.ops_validate_quotation_write() to service_role;
grant execute on function private.ops_validate_appointment_write() to service_role;
grant execute on function private.ops_validate_document_write() to service_role;
grant execute on function private.ops_validate_message_write() to service_role;
