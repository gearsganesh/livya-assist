do $$
declare r record;
begin
  for r in
    select p.oid, format('%I.%I(%s)',n.nspname,p.proname,pg_get_function_identity_arguments(p.oid)) as sig
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname like 'ops_%'
  loop
    execute 'revoke all on function '||r.sig||' from public, anon';
    execute 'grant execute on function '||r.sig||' to authenticated, service_role';
  end loop;
end $$;