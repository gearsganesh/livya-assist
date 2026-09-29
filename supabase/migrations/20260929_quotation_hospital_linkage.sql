-- Mirrors production migration quotation_hospital_linkage_20260929.
CREATE OR REPLACE FUNCTION public.ops_submit_hospital_quotation(
  p_case_id uuid,p_hospital_id uuid,p_reference text,p_amount numeric,
  p_currency text DEFAULT NULL,p_valid_until date DEFAULT NULL,p_notes text DEFAULT NULL
)
RETURNS public.ops_quotations LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
declare v_case public.ops_cases; v public.ops_quotations; v_currency text; v_hospital uuid;
begin
  select * into v_case from public.ops_cases where id=p_case_id for update;
  if not found then raise exception 'Case not found'; end if;
  if p_amount is null or p_amount<=0 then raise exception 'Quotation amount must be greater than zero'; end if;
  if public.ops_role()='HOSPITAL_USER' then
    v_hospital:=private.ops_hospital_id();
    if v_case.hospital_id is null or v_case.hospital_id<>v_hospital then raise exception 'Hospital access denied'; end if;
  elsif not private.ops_can_access_center(v_case.center_id) or not private.ops_can_write('cases') then
    raise exception 'Quotation access denied';
  else
    v_hospital:=coalesce(p_hospital_id,v_case.hospital_id);
    if v_hospital is null then raise exception 'Hospital is required'; end if;
  end if;
  v_currency:=coalesce(nullif(upper(trim(p_currency)),''),v_case.currency,'AED');
  if length(v_currency)<>3 then raise exception 'Currency must be a 3-letter code'; end if;
  perform private.ops_set_workflow_context('QUOTATION_SUBMIT');
  insert into public.ops_quotations(case_id,hospital_id,reference,amount,currency,valid_until,status,notes,created_by)
  values(p_case_id,v_hospital,p_reference,p_amount,v_currency,p_valid_until,'SENT',p_notes,auth.uid()) returning * into v;
  if v_case.status='ASSESSMENT' then
    update public.ops_cases set status='QUOTATION',hospital_id=coalesce(hospital_id,v_hospital),hospital=(select name from public.ops_hospitals where id=coalesce(hospital_id,v_hospital)),updated_at=now() where id=p_case_id;
    insert into public.ops_case_events(case_id,actor_id,event_type,message) values(p_case_id,auth.uid(),'STAGE_CHANGE','Hospital quotation submitted; case moved to quotation');
  end if;
  return v;
end $$;
