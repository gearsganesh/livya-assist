-- Mirrors production migration concierge_workflow_hardening_20260929.
CREATE OR REPLACE FUNCTION public.ops_create_concierge_request(
  p_case_id uuid,p_patient_id uuid,p_service_type text,p_category text DEFAULT NULL,
  p_details text DEFAULT NULL,p_service_date date DEFAULT NULL,p_price numeric DEFAULT 0,
  p_vendor_id uuid DEFAULT NULL,p_currency text DEFAULT NULL
)
RETURNS public.ops_concierge LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
declare v_case public.ops_cases; v public.ops_concierge; v_currency text;
begin
  select * into v_case from public.ops_cases where id=p_case_id;
  if not found then raise exception 'Case not found'; end if;
  if p_patient_id<>v_case.patient_id then raise exception 'Concierge patient must match case patient'; end if;
  if private.ops_is_patient() then null;
  elsif not private.ops_can_access_center(v_case.center_id) then raise exception 'Case access denied'; end if;
  if public.ops_role() not in('SUPER_ADMIN','CENTER_MANAGER','COORDINATOR','CONCIERGE_AGENT') and not private.ops_is_patient() then raise exception 'Concierge creation denied'; end if;
  if private.ops_is_patient() and p_price<>0 then raise exception 'Patients cannot set concierge pricing'; end if;
  v_currency:=coalesce(nullif(upper(trim(p_currency)),''),v_case.currency,'AED');
  perform private.ops_set_workflow_context('CONCIERGE_WORKFLOW');
  insert into public.ops_concierge(patient_id,case_id,service_type,category,details,service_date,status,revenue,created_by,vendor_id,price,currency,requested_at)
  values(p_patient_id,p_case_id,upper(p_service_type),nullif(p_category,''),p_details,p_service_date,'REQUESTED',0,auth.uid(),p_vendor_id,coalesce(p_price,0),v_currency,now())
  returning * into v;
  return v;
end $$;

CREATE OR REPLACE FUNCTION public.ops_set_concierge_status(p_id uuid,p_status text,p_price numeric DEFAULT NULL)
RETURNS public.ops_concierge LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v public.ops_concierge; v_from text; v_to text; v_case public.ops_cases;
BEGIN
 SELECT * INTO v FROM public.ops_concierge WHERE id=p_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Concierge request not found'; END IF;
 SELECT * INTO v_case FROM public.ops_cases WHERE id=v.case_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'Case not found'; END IF;
 IF private.ops_is_patient() THEN
   IF v.patient_id <> (SELECT patient_id FROM public.ops_staff WHERE id=auth.uid()) THEN RAISE EXCEPTION 'Concierge access denied'; END IF;
 ELSE
   IF NOT private.ops_can_access_center(v_case.center_id) THEN RAISE EXCEPTION 'Concierge access denied'; END IF;
 END IF;
 IF public.ops_role() NOT IN('SUPER_ADMIN','CENTER_MANAGER','CONCIERGE_AGENT','COORDINATOR') AND NOT private.ops_is_patient() THEN RAISE EXCEPTION 'Concierge access denied'; END IF;
 v_from:=upper(coalesce(v.status,'REQUESTED')); v_to:=upper(replace(p_status,' ','_'));
 IF v_to NOT IN('REQUESTED','QUOTED','CONFIRMED','IN_DELIVERY','DELIVERED','CANCELLED') THEN RAISE EXCEPTION 'Invalid concierge status'; END IF;
 IF private.ops_is_patient() AND v_to NOT IN('REQUESTED','CANCELLED') THEN RAISE EXCEPTION 'Patients cannot advance concierge status'; END IF;
 IF v_to<>v_from AND NOT ((v_from='REQUESTED' AND v_to IN('QUOTED','CANCELLED')) OR (v_from='QUOTED' AND v_to IN('CONFIRMED','CANCELLED')) OR (v_from='CONFIRMED' AND v_to IN('IN_DELIVERY','CANCELLED')) OR (v_from='IN_DELIVERY' AND v_to IN('DELIVERED','CANCELLED')) OR (v_from='DELIVERED' AND v_to='DELIVERED') OR (v_from='CANCELLED' AND v_to='CANCELLED') OR (v_from=v_to)) THEN
   RAISE EXCEPTION 'Invalid concierge transition: % -> %',v_from,v_to;
 END IF;
 PERFORM private.ops_set_workflow_context('CONCIERGE_WORKFLOW');
 UPDATE public.ops_concierge SET status=v_to,price=CASE WHEN private.ops_is_patient() THEN price ELSE coalesce(p_price,price) END,delivered_at=CASE WHEN v_to='DELIVERED' THEN now() ELSE delivered_at END,cancelled_at=CASE WHEN v_to='CANCELLED' THEN now() ELSE cancelled_at END,updated_at=now() WHERE id=p_id RETURNING * INTO v;
 IF v_to='DELIVERED' AND v.price>0 AND NOT EXISTS(SELECT 1 FROM public.ops_billing b WHERE b.case_id=v.case_id AND b.type=CASE WHEN upper(coalesce(v.category,v.service_type)) IN('PHARMACY','HEALTH_CHECK','WELLNESS') THEN 'ANCILLARY' ELSE 'CONCIERGE' END AND b.notes LIKE '%'||v.id::text||'%') THEN
   PERFORM public.ops_create_invoice(v.case_id,CASE WHEN upper(coalesce(v.category,v.service_type)) IN('PHARMACY','HEALTH_CHECK','WELLNESS') THEN 'ANCILLARY' ELSE 'CONCIERGE' END,v.price,v.patient_id,NULL,NULL,NULL,'Auto-generated from concierge request '||v.id::text);
 END IF;
 RETURN v;
END $$;
