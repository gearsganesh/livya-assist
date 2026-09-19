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

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok');
  try {
    const url = Deno.env.get('SUPABASE_URL');
    const key = secretKey();
    if (!url || !key) return Response.json({error:'Server configuration is incomplete'},{status:500});
    const admin = createClient(url, key);
    const { count, error: countError } = await admin.from('ops_staff').select('id',{count:'exact',head:true});
    if (countError) throw countError;
    if ((count || 0) > 0) return Response.json({error:'Initial administrator already exists'},{status:409});
    const body = await req.json();
    const full_name = String(body.full_name || '').trim();
    const email = String(body.email || '').trim().toLowerCase();
    const password = String(body.password || '');
    if (!full_name || !email || password.length < 8) return Response.json({error:'Name, email and password are required'},{status:400});
    const { data, error:createError } = await admin.auth.admin.createUser({email,password,email_confirm:true,user_metadata:{full_name}});
    if (createError) throw createError;
    const { error:staffError } = await admin.from('ops_staff').insert({id:data.user.id,full_name,email,role:'Super admin',scope:'All centers',active:true});
    if (staffError) {
      await admin.auth.admin.deleteUser(data.user.id);
      throw staffError;
    }
    return Response.json({id:data.user.id});
  } catch(e) {
    return Response.json({error:e?.message||'Unable to create initial administrator'},{status:400});
  }
});
