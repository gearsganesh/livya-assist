import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
Deno.serve(async(req)=>{
  try{
    const url=Deno.env.get('SUPABASE_URL')!,key=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,auth=req.headers.get('Authorization')||'';
    const c=createClient(url,key,{global:{headers:{Authorization:auth}}});
    const {data:{user:caller}}=await c.auth.getUser(auth.replace(/^Bearer\s+/,''));
    if(!caller)return Response.json({error:'Unauthorized'},{status:401});
    const {data:s}=await c.from('ops_staff').select('role,active').eq('id',caller.id).maybeSingle();
    if(!s?.active||s.role!=='Super admin')return Response.json({error:'Forbidden'},{status:403});
    const {user_id}=await req.json(); if(!user_id||user_id===caller.id)return Response.json({error:'Invalid user'},{status:400});
    const {error}=await c.auth.admin.deleteUser(user_id); if(error)throw error;
    return Response.json({ok:true});
  }catch(e){return Response.json({error:e?.message||'Unable to delete user'},{status:400});}
});
