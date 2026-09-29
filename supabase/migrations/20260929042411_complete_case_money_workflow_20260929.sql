create or replace function public.ops_create_case(
  p_patient_id uuid,p_center_id uuid,p_specialty text default null,p_procedure text default null,p_hospital_id uuid default null,p_referrer_id uuid default null,p_coordinator_id uuid default null,p_priority text default 'Normal',p_source text default null,p_notes text default null,p_estimated_value numeric default 0
) returns public.ops_cases language plpgsql security definer set search_path=''
as $$
declare v_case public.ops_cases; v_code text;
begin
  if not private.ops_can_write('cases') or not private.ops_can_access_center(p_center_id) then raise exception 'Case creation denied'; end if;
  v_code:=public.ops_next_case_code(p_center_id);
  insert into public.ops_cases(case_code,patient_id,center_id,specialty,procedure,hospital,hospital_id,coordinator_id,referrer_id,priority,source,referred_by,estimated_value,status,notes,created_by,currency)
  select v_code,p_patient_id,p_center_id,p_specialty,p_procedure,h.name,p_hospital_id,p_coordinator_id,p_referrer_id,p_priority,p_source,r.name,p_estimated_value,'ENQUIRY',p_notes,auth.uid(),coalesce(c.currency,'AED')
  from public.ops_centers c left join public.ops_hospitals h on h.id=p_hospital_id left join public.ops_referrers r on r.id=p_referrer_id where c.id=p_center_id
  returning * into v_case;
  if v_case.id is null then raise exception 'Center not found'; end if;
  insert into public.ops_itineraries(case_id,visa_status,attendants) values(v_case.id,'PENDING',0) on conflict(case_id) do nothing;
  insert into public.ops_case_events(case_id,actor_id,event_type,message) values(v_case.id,auth.uid(),'CASE_CREATED','Case created');
  return v_case;
end $$;

create or replace function public.ops_accept_quotation(p_quotation_id uuid)
returns public.ops_quotations language plpgsql security definer set search_path=''
as $$
declare v_q public.ops_quotations; v_case public.ops_cases;
begin
  select * into v_q from public.ops_quotations where id=p_quotation_id for update;
  if not found then raise exception 'Quotation not found'; end if;
  select * into v_case from public.ops_cases where id=v_q.case_id for update;
  if not private.ops_can_access_center(v_case.center_id) or not private.ops_can_write('cases') then raise exception 'Quotation acceptance denied'; end if;
  update public.ops_quotations set status='ACCEPTED',updated_at=now() where id=p_quotation_id returning * into v_q;
  update public.ops_quotations set status='REJECTED',updated_at=now() where case_id=v_q.case_id and id<>v_q.id and status in('DRAFT','SENT');
  update public.ops_cases set hospital_id=v_q.hospital_id,hospital=(select name from public.ops_hospitals where id=v_q.hospital_id),estimated_value=v_q.amount,status='ACCEPTED',updated_at=now() where id=v_q.case_id;
  if not exists(select 1 from public.ops_billing b where b.case_id=v_q.case_id and b.type='HOSPITAL_COMMISSION' and b.status<>'VOID') then
    perform public.ops_create_hospital_commission_invoice(v_q.case_id,v_q.amount,current_date,'Auto-created from accepted quotation '||coalesce(v_q.reference,v_q.id::text));
  end if;
  insert into public.ops_case_events(case_id,actor_id,event_type,message) values(v_q.case_id,auth.uid(),'QUOTATION_ACCEPTED',format('Quotation %s accepted',coalesce(v_q.reference,v_q.id::text)));
  return v_q;
end $$;

create or replace function public.ops_create_invoice(p_case_id uuid,p_type text,p_amount numeric,p_patient_id uuid default null,p_hospital_id uuid default null,p_rate_pct numeric default null,p_due_date date default null,p_notes text default null)
returns public.ops_billing language plpgsql security definer set search_path=''
as $$
declare v public.ops_billing; v_commission numeric:=0;
begin
  if not private.ops_can_access_center((select center_id from public.ops_cases where id=p_case_id)) then raise exception 'Invoice access denied'; end if;
  if public.ops_role() not in('SUPER_ADMIN','CENTER_MANAGER','COORDINATOR') then raise exception 'Invoice creation denied'; end if;
  if upper(p_type)='HOSPITAL_COMMISSION' then v_commission:=coalesce(p_amount,0); end if;
  insert into public.ops_billing(invoice_number,type,patient_id,case_id,hospital_id,gross_amount,amount,commission,rate_pct,paid_amount,currency,status,invoice_date,due_date,notes,created_by)
  values(public.ops_next_invoice_number(),upper(p_type),p_patient_id,p_case_id,p_hospital_id,coalesce(p_amount,0),coalesce(p_amount,0),v_commission,p_rate_pct,0,'AED','DUE',current_date,p_due_date,p_notes,auth.uid()) returning * into v;
  return v;
end $$;

create or replace function public.ops_record_payment(p_invoice_id uuid,p_amount numeric,p_payment_method text default null,p_reference text default null,p_notes text default null,p_payment_date date default current_date)
returns public.ops_billing language plpgsql security definer set search_path=''
as $$
declare v public.ops_billing; v_total numeric;
begin
  select * into v from public.ops_billing where id=p_invoice_id for update;
  if not found then raise exception 'Invoice not found'; end if;
  if not private.ops_can_access_center((select center_id from public.ops_cases where id=v.case_id)) then raise exception 'Invoice access denied'; end if;
  if public.ops_role() not in('SUPER_ADMIN','CENTER_MANAGER','COORDINATOR') then raise exception 'Payment access denied'; end if;
  if p_amount<=0 or p_amount>(v.amount-v.paid_amount) then raise exception 'Invalid payment amount'; end if;
  insert into public.ops_payments(invoice_id,amount,payment_date,payment_method,reference,notes,created_by) values(p_invoice_id,p_amount,p_payment_date,p_payment_method,p_reference,p_notes,auth.uid());
  v_total:=v.paid_amount+p_amount;
  update public.ops_billing set paid_amount=v_total,status=case when v_total>=amount then 'PAID' when v_total>0 then 'PARTIAL' else 'DUE' end,paid_at=case when v_total>=amount then now() else paid_at end,updated_at=now() where id=p_invoice_id returning * into v;
  return v;
end $$;

revoke all on function public.ops_create_case(uuid,uuid,text,text,uuid,uuid,uuid,text,text,text,numeric) from public,anon;
grant execute on function public.ops_create_case(uuid,uuid,text,text,uuid,uuid,uuid,text,text,text,numeric) to authenticated,service_role;
revoke all on function public.ops_accept_quotation(uuid) from public,anon;
grant execute on function public.ops_accept_quotation(uuid) to authenticated,service_role;
revoke all on function public.ops_create_invoice(uuid,text,numeric,uuid,uuid,numeric,date,text) from public,anon;
grant execute on function public.ops_create_invoice(uuid,text,numeric,uuid,uuid,numeric,date,text) to authenticated,service_role;
revoke all on function public.ops_record_payment(uuid,numeric,text,text,text,date) from public,anon;
grant execute on function public.ops_record_payment(uuid,numeric,text,text,text,date) to authenticated,service_role;