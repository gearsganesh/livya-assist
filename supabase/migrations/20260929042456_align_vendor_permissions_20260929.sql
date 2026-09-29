drop policy if exists "staff update vendors" on public.ops_vendors;
drop policy if exists "staff write vendors" on public.ops_vendors;
create policy "staff update vendors" on public.ops_vendors for update to authenticated
using (private.ops_can_write('vendors')) with check (private.ops_can_write('vendors'));
create policy "staff write vendors" on public.ops_vendors for insert to authenticated
with check (private.ops_can_write('vendors'));