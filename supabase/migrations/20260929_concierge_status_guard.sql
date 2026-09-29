-- Mirrors production migration concierge_status_guard_20260929.
CREATE OR REPLACE FUNCTION public.ops_guard_concierge_workflow()
RETURNS trigger LANGUAGE plpgsql SET search_path=''
AS $$
begin
  if NEW.status is distinct from OLD.status and private.ops_workflow_context() <> 'CONCIERGE_WORKFLOW' then
    raise exception 'Concierge status can only be changed through the concierge workflow';
  end if;
  return NEW;
end
$$;
DROP TRIGGER IF EXISTS trg_ops_concierge_workflow_guard ON public.ops_concierge;
CREATE TRIGGER trg_ops_concierge_workflow_guard BEFORE UPDATE ON public.ops_concierge FOR EACH ROW EXECUTE FUNCTION public.ops_guard_concierge_workflow();
