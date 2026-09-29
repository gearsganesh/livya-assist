create or replace function private.ops_can_write(p_module text)
returns boolean language sql stable security definer set search_path=''
as $$
  select exists(
    select 1 from public.ops_staff s where s.id=auth.uid() and s.active and (
      upper(s.role)='SUPER_ADMIN'
      or (p_module in('cases','patients','appointments','tasks','documents','quotations','travel','messages') and upper(s.role) in('CENTER_MANAGER','COORDINATOR'))
      or (p_module='concierge' and upper(s.role) in('CENTER_MANAGER','COORDINATOR','CONCIERGE_AGENT'))
      or (p_module='billing' and upper(s.role) in('SUPER_ADMIN','CENTER_MANAGER','COORDINATOR'))
      or (p_module='hospitals' and upper(s.role) in('SUPER_ADMIN','CENTER_MANAGER'))
      or (p_module='referrers' and upper(s.role) in('SUPER_ADMIN','CENTER_MANAGER','COORDINATOR','CONCIERGE_AGENT'))
      or (p_module='vendors' and upper(s.role) in('SUPER_ADMIN','CENTER_MANAGER','CONCIERGE_AGENT'))
    )
  )
$$;
revoke all on function private.ops_can_write(text) from public;
grant execute on function private.ops_can_write(text) to authenticated,service_role;