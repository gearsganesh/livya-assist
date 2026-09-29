-- Mirrors production migration workflow_financial_hardening_20260929.
CREATE OR REPLACE FUNCTION private.ops_set_workflow_context(p_context text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
begin
  if p_context not in ('CASE_TRANSITION','QUOTATION_ACCEPT','QUOTATION_SUBMIT','CONCIERGE_WORKFLOW','BILLING_CREATE','BILLING_PAYMENT','BILLING_VOID') then raise exception 'Invalid workflow context'; end if;
  perform pg_catalog.set_config('livya.workflow_context',p_context,true);
end $$;

CREATE OR REPLACE FUNCTION private.ops_workflow_context()
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$ select coalesce(current_setting('livya.workflow_context',true),'') $$;

CREATE OR REPLACE FUNCTION public.ops_guard_case_workflow()
RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $$
begin
  if NEW.status is distinct from OLD.status and private.ops_workflow_context() not in ('CASE_TRANSITION','QUOTATION_ACCEPT','QUOTATION_SUBMIT') then raise exception 'Case status can only be changed through the case workflow'; end if;
  return NEW;
end $$;
DROP TRIGGER IF EXISTS trg_ops_cases_workflow_guard ON public.ops_cases;
CREATE TRIGGER trg_ops_cases_workflow_guard BEFORE UPDATE ON public.ops_cases FOR EACH ROW EXECUTE FUNCTION public.ops_guard_case_workflow();

CREATE OR REPLACE FUNCTION public.ops_guard_quotation_workflow()
RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $$
begin
  if NEW.status is distinct from OLD.status and private.ops_workflow_context() not in ('QUOTATION_ACCEPT','QUOTATION_SUBMIT') then raise exception 'Quotation status can only be changed through the quotation workflow'; end if;
  if coalesce(public.ops_role(),'')='HOSPITAL_USER' and (NEW.status is distinct from OLD.status or NEW.hospital_id is distinct from OLD.hospital_id or NEW.amount is distinct from OLD.amount or NEW.currency is distinct from OLD.currency) then raise exception 'Hospital users cannot modify protected quotation fields'; end if;
  return NEW;
end $$;
DROP TRIGGER IF EXISTS trg_ops_quotations_workflow_guard ON public.ops_quotations;
CREATE TRIGGER trg_ops_quotations_workflow_guard BEFORE UPDATE ON public.ops_quotations FOR EACH ROW EXECUTE FUNCTION public.ops_guard_quotation_workflow();

CREATE OR REPLACE FUNCTION public.ops_guard_appointment_linkage()
RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $$
declare v_case public.ops_cases;
begin
  if NEW.case_id is not null then
    select * into v_case from public.ops_cases where id=NEW.case_id;
    if not found then raise exception 'Appointment case not found'; end if;
    if NEW.patient_id<>v_case.patient_id then raise exception 'Appointment patient must match case patient'; end if;
    if coalesce(public.ops_role(),'')='HOSPITAL_USER' and (v_case.hospital_id is null or v_case.hospital_id<>private.ops_hospital_id()) then raise exception 'Appointment hospital access denied'; end if;
  end if;
  return NEW;
end $$;
DROP TRIGGER IF EXISTS trg_ops_appointments_linkage ON public.ops_appointments;
CREATE TRIGGER trg_ops_appointments_linkage BEFORE INSERT OR UPDATE ON public.ops_appointments FOR EACH ROW EXECUTE FUNCTION public.ops_guard_appointment_linkage();

CREATE OR REPLACE FUNCTION public.ops_guard_document_actor()
RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $$ begin if NEW.uploaded_by is null or NEW.uploaded_by<>auth.uid() then raise exception 'Document uploader must be the authenticated user'; end if; return NEW; end $$;
DROP TRIGGER IF EXISTS trg_ops_documents_actor ON public.ops_documents;
CREATE TRIGGER trg_ops_documents_actor BEFORE INSERT OR UPDATE ON public.ops_documents FOR EACH ROW EXECUTE FUNCTION public.ops_guard_document_actor();

CREATE OR REPLACE FUNCTION public.ops_guard_message_actor()
RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $$ begin if NEW.sender_id is null or NEW.sender_id<>auth.uid() then raise exception 'Message sender must be the authenticated user'; end if; return NEW; end $$;
DROP TRIGGER IF EXISTS trg_ops_case_messages_actor ON public.ops_case_messages;
CREATE TRIGGER trg_ops_case_messages_actor BEFORE INSERT OR UPDATE ON public.ops_case_messages FOR EACH ROW EXECUTE FUNCTION public.ops_guard_message_actor();

CREATE OR REPLACE FUNCTION public.ops_guard_billing_workflow()
RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $$
begin
  if TG_OP='UPDATE' and (NEW.amount is distinct from OLD.amount or NEW.gross_amount is distinct from OLD.gross_amount or NEW.commission is distinct from OLD.commission or NEW.rate_pct is distinct from OLD.rate_pct or NEW.paid_amount is distinct from OLD.paid_amount or NEW.currency is distinct from OLD.currency or NEW.type is distinct from OLD.type or NEW.case_id is distinct from OLD.case_id or NEW.patient_id is distinct from OLD.patient_id or NEW.hospital_id is distinct from OLD.hospital_id or NEW.invoice_number is distinct from OLD.invoice_number or NEW.status is distinct from OLD.status) and private.ops_workflow_context() not in ('BILLING_PAYMENT','BILLING_VOID') then
    raise exception 'Financial invoice fields can only be changed through billing workflows';
  end if;
  return NEW;
end $$;
DROP TRIGGER IF EXISTS trg_ops_billing_workflow ON public.ops_billing;
CREATE TRIGGER trg_ops_billing_workflow BEFORE UPDATE ON public.ops_billing FOR EACH ROW EXECUTE FUNCTION public.ops_guard_billing_workflow();

CREATE OR REPLACE FUNCTION public.ops_update_invoice(p_invoice_id uuid,p_due_date date DEFAULT NULL,p_notes text DEFAULT NULL)
RETURNS public.ops_billing LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
declare v public.ops_billing;
begin
  select * into v from public.ops_billing where id=p_invoice_id for update;
  if not found then raise exception 'Invoice not found'; end if;
  if not private.ops_can_access_center((select center_id from public.ops_cases where id=v.case_id)) then raise exception 'Invoice access denied'; end if;
  if public.ops_role() not in('SUPER_ADMIN','CENTER_MANAGER','COORDINATOR') then raise exception 'Invoice update denied'; end if;
  if v.status='PAID' then raise exception 'Paid invoices cannot be edited'; end if;
  update public.ops_billing set due_date=p_due_date,notes=p_notes,updated_at=now() where id=p_invoice_id returning * into v;
  return v;
end $$;

CREATE OR REPLACE FUNCTION public.ops_void_invoice(p_invoice_id uuid,p_reason text DEFAULT NULL)
RETURNS public.ops_billing LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
declare v public.ops_billing;
begin
  select * into v from public.ops_billing where id=p_invoice_id for update;
  if not found then raise exception 'Invoice not found'; end if;
  if not private.ops_can_access_center((select center_id from public.ops_cases where id=v.case_id)) then raise exception 'Invoice access denied'; end if;
  if public.ops_role() not in('SUPER_ADMIN','CENTER_MANAGER','COORDINATOR') then raise exception 'Invoice void denied'; end if;
  if v.paid_amount>0 then raise exception 'Paid or partially paid invoices cannot be voided'; end if;
  perform private.ops_set_workflow_context('BILLING_VOID');
  update public.ops_billing set status='VOID',notes=case when nullif(trim(p_reason),'') is null then notes else concat_ws(E'\n',notes,'VOID: '||trim(p_reason)) end,updated_at=now() where id=p_invoice_id returning * into v;
  return v;
end $$;

CREATE OR REPLACE FUNCTION public.ops_submit_hospital_quotation(p_case_id uuid,p_reference text,p_amount numeric,p_currency text DEFAULT NULL,p_valid_until date DEFAULT NULL,p_notes text DEFAULT NULL)
RETURNS public.ops_quotations LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
declare v_case public.ops_cases; v public.ops_quotations; v_currency text;
begin
  select * into v_case from public.ops_cases where id=p_case_id for update;
  if not found then raise exception 'Case not found'; end if;
  if p_amount is null or p_amount<=0 then raise exception 'Quotation amount must be greater than zero'; end if;
  if public.ops_role()='HOSPITAL_USER' then
    if v_case.hospital_id is null or v_case.hospital_id<>private.ops_hospital_id() then raise exception 'Hospital access denied'; end if;
  elsif not private.ops_can_access_center(v_case.center_id) or not private.ops_can_write('cases') then raise exception 'Quotation access denied'; end if;
  v_currency:=coalesce(nullif(upper(trim(p_currency)),''),v_case.currency,'AED');
  if length(v_currency)<>3 then raise exception 'Currency must be a 3-letter code'; end if;
  perform private.ops_set_workflow_context('QUOTATION_SUBMIT');
  insert into public.ops_quotations(case_id,hospital_id,reference,amount,currency,valid_until,status,notes,created_by)
  values(p_case_id,v_case.hospital_id,p_reference,p_amount,v_currency,p_valid_until,'SENT',p_notes,auth.uid()) returning * into v;
  if v_case.status='ASSESSMENT' then
    update public.ops_cases set status='QUOTATION',updated_at=now() where id=p_case_id;
    insert into public.ops_case_events(case_id,actor_id,event_type,message) values(p_case_id,auth.uid(),'STAGE_CHANGE','Hospital quotation submitted; case moved to quotation');
  end if;
  return v;
end $$;

CREATE OR REPLACE FUNCTION public.ops_create_concierge_request(p_case_id uuid,p_patient_id uuid,p_service_type text,p_category text DEFAULT NULL,p_details text DEFAULT NULL,p_service_date date DEFAULT NULL,p_price numeric DEFAULT 0,p_vendor_id uuid DEFAULT NULL,p_currency text DEFAULT NULL)
RETURNS public.ops_concierge LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
declare v_case public.ops_cases; v public.ops_concierge; v_currency text;
begin
  select * into v_case from public.ops_cases where id=p_case_id;
  if not found or not private.ops_can_access_center(v_case.center_id) then raise exception 'Case access denied'; end if;
  if p_patient_id<>v_case.patient_id then raise exception 'Concierge patient must match case patient'; end if;
  if public.ops_role() not in('SUPER_ADMIN','CENTER_MANAGER','COORDINATOR','CONCIERGE_AGENT') and not private.ops_is_patient() then raise exception 'Concierge creation denied'; end if;
  if private.ops_is_patient() and p_price<>0 then raise exception 'Patients cannot set concierge pricing'; end if;
  v_currency:=coalesce(nullif(upper(trim(p_currency)),''),v_case.currency,'AED');
  perform private.ops_set_workflow_context('CONCIERGE_WORKFLOW');
  insert into public.ops_concierge(patient_id,case_id,service_type,category,details,service_date,status,revenue,created_by,vendor_id,price,currency,requested_at)
  values(p_patient_id,p_case_id,upper(p_service_type),nullif(p_category,''),p_details,p_service_date,'REQUESTED',0,auth.uid(),p_vendor_id,coalesce(p_price,0),v_currency,now()) returning * into v;
  return v;
end $$;

ALTER TABLE public.ops_case_sequences ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "case sequence no direct access" ON public.ops_case_sequences;
CREATE POLICY "case sequence no direct access" ON public.ops_case_sequences FOR ALL TO authenticated USING (false) WITH CHECK (false);
REVOKE ALL ON public.ops_case_sequences FROM anon,authenticated;
GRANT SELECT,INSERT,UPDATE ON public.ops_case_sequences TO service_role;
