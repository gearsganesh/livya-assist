-- Correct and consolidate center SELECT access.
drop policy if exists "patient read own center" on public.ops_centers;
drop policy if exists "staff read centers" on public.ops_centers;
create policy "authenticated read centers"
on public.ops_centers for select to authenticated
using (
  private.ops_is_staff()
  or exists (
    select 1 from public.ops_patients p
    where p.center_id=ops_centers.id
      and p.app_user_id=(select auth.uid())
      and p.portal_enabled=true
  )
);