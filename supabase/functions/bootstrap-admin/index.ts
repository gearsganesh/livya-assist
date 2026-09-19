import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

function secretKey() {
  const raw = Deno.env.get('SUPABASE_SECRET_KEYS');
  if (raw) {
    try {
      const keys = JSON.parse(raw);
      const first = Object.values(keys)[0];
      if (first) return String(first);
    } catch (_) {}
  }
  return Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '';
}

function callerClient(url:string, token:string) {
  const anon = Deno.env.get('SUPABASE_ANON_KEY') || '';
  return createClient(url, anon, { auth:{persistSession:false,autoRefreshToken:false}, global:{headers:{Authorization:`Bearer ${token}`}} });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok');
  try {
    const url = Deno.env.get('SUPABASE_URL') || '';
    const key = secretKey();
    if (!url || !key) return Response.json({error:'Server configuration is incomplete'},{status:500});
    const admin = createClient(url, key, { auth:{persistSession:false,autoRefreshToken:false} });
    const body = await req.json().catch(()=>({}));
    if (body.action === 'status') {
      const { count, error } = await admin.from('ops_staff').select('id',{count:'exact',head:true});
      if (error) throw error;
      return Response.json({needs_setup:(count||0)===0});
    }
    const auth = req.headers.get('Authorization') || '';
    const token = auth.replace(/^Bearer\s+/i, '');
    if (!token) return Response.json({error:'Unauthorized'},{status:401});
    const caller = callerClient(url, token);
    const { data:{user}, error:userError } = await caller.auth.getUser(token);
    if (userError || !user) return Response.json({error:'Unauthorized'},{status:401});
    const { data:staff, error:staffError } = await caller.from('ops_staff').select('role,active').eq('id',user.id).maybeSingle();
    if (staffError) throw staffError;
    if (!staff?.active || staff.role !== 'Super admin') return Response.json({error:'Forbidden'},{status:403});
    const full_name = String(body.full_name || '').trim();
    const email = String(body.email || '').trim().toLowerCase();
    const password = String(body.password || '');
    if (!full_name || !email || password.length < 8) return Response.json({error:'Name, email and password are required'},{status:400});
    const { data, error:createError } = await admin.auth.admin.createUser({email,password,email_confirm:true,user_metadata:{full_name}});
    if (createError) throw createError;
    const { error:staffError2 } = await admin.from('ops_staff').insert({id:data.user.id,full_name,email,role:'Super admin',scope:'All centers',active:true});
    if (staffError2) { await admin.auth.admin.deleteUser(data.user.id); throw staffError2; }
    return Response.json({id:data.user.id});
  } catch(e) { return Response.json({error:e?.message||'Unable to create initial administrator'},{status:400}); }
});
