import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const ROLES=['Super admin','Coordinator','Finance','Center admin','Viewer'];

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok');
  try {
    const url=Deno.env.get('SUPABASE_URL')!;
    const secretJson=Deno.env.get('SUPABASE_SECRET_KEYS')||'{}';
    let key='';
    try{const keys=JSON.parse(secretJson);key=String(Object.values(keys)[0]||'')}catch(_){}
    key=key||Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')||'';
    if(!url||!key) throw new Error('Server configuration is incomplete');
    const auth=req.headers.get('Authorization')||'';
    const client=createClient(url,key,{global:{headers:{Authorization:auth}}});
    const token=auth.replace(/^Bearer\s+/,'');
    const {data:{user:caller},error}=await client.auth.getUser(token);
    if(error||!caller) return Response.json({error:'Unauthorized'},{status:401});

    const {data:staff}=await client.from('ops_staff').select('role,scope,active').eq('id',caller.id).maybeSingle();
    if(!staff?.active||!['Super admin','Center admin'].includes(staff.role)) return Response.json({error:'Forbidden'},{status:403});

    const b=await req.json();
    const email=String(b.email||'').trim().toLowerCase();
    const password=String(b.password||'');
    const full_name=String(b.full_name||'').trim();
    const role=String(b.role||'Coordinator');
    const requestedScope=String(b.scope||'All centers');

    if(!email||password.length<8||!full_name) return Response.json({error:'Name, email and password are required'},{status:400});
    if(!ROLES.includes(role)) return Response.json({error:'Invalid role'},{status:400});

    const scope=staff.role==='Super admin' ? requestedScope : staff.scope;
    if(staff.role==='Center admin' && (role==='Super admin'||requestedScope==='All centers')) {
      return Response.json({error:'Center Admins can only create users within their own center'},{status:403});
    }
    if(!scope) return Response.json({error:'A valid center scope is required'},{status:400});
    if(scope!=='All centers') {
      const {data:center}=await client.from('ops_centers').select('id').eq('name',scope).eq('active',true).maybeSingle();
      if(!center) return Response.json({error:'Invalid or inactive center scope'},{status:400});
    }

    const {data,error:createError}=await client.auth.admin.createUser({email,password,email_confirm:true,user_metadata:{full_name}});
    if(createError) throw createError;
    const {error:staffError}=await client.from('ops_staff').insert({id:data.user.id,full_name,role,scope,active:true});
    if(staffError){await client.auth.admin.deleteUser(data.user.id);throw staffError;}
    return Response.json({id:data.user.id});
  } catch(e) {
    return Response.json({error:e?.message||'Unable to create user'},{status:400});
  }
});
