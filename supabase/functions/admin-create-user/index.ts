import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok');
  try {
    const url=Deno.env.get('SUPABASE_URL')!, key=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const auth=req.headers.get('Authorization')||'';
    const client=createClient(url,key,{global:{headers:{Authorization:auth}}});
    const token=auth.replace(/^Bearer\s+/,'');
    const {data:{user:caller},error}=await client.auth.getUser(token);
    if(error||!caller) return Response.json({error:'Unauthorized'},{status:401});
    const {data:staff}=await client.from('ops_staff').select('role,active').eq('id',caller.id).maybeSingle();
    if(!staff?.active||!['Super admin','Center admin'].includes(staff.role)) return Response.json({error:'Forbidden'},{status:403});
    const b=await req.json(), email=String(b.email||'').trim().toLowerCase(), password=String(b.password||''), full_name=String(b.full_name||'').trim();
    if(!email||password.length<8||!full_name) return Response.json({error:'Name, email and password are required'},{status:400});
    const role=b.role||'Coordinator', scope=b.scope||'All centers';
    if(!['Super admin','Coordinator','Finance','Center admin','Viewer'].includes(role)) return Response.json({error:'Invalid role'},{status:400});
    const {data,error:createError}=await client.auth.admin.createUser({email,password,email_confirm:true,user_metadata:{full_name}});
    if(createError) throw createError;
    const {error:staffError}=await client.from('ops_staff').insert({id:data.user.id,full_name,role,scope,active:true});
    if(staffError){await client.auth.admin.deleteUser(data.user.id);throw staffError;}
    return Response.json({id:data.user.id});
  } catch(e) { return Response.json({error:e?.message||'Unable to create user'},{status:400}); }
});
