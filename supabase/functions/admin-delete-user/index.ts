import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { corsHeaders } from "npm:@supabase/supabase-js@2/cors";

function respond(body: unknown, init: ResponseInit = {}) {
  return new Response(JSON.stringify(body), {
    ...init,
    headers: { ...corsHeaders, ...(init.headers || {}), 'Content-Type': 'application/json' }
  });
}

function secretKey() {
  const json = Deno.env.get('SUPABASE_SECRET_KEYS') || '{}';
  try {
    const keys = JSON.parse(json);
    const values = Object.values(keys).map(String).filter(Boolean);
    if (values[0]) return values[0];
  } catch (_) {}
  return Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '';
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  try {
    const url = Deno.env.get('SUPABASE_URL') || '';
    const key = secretKey();
    const auth = req.headers.get('Authorization') || '';
    const token = auth.replace(/^Bearer\s+/i, '');
    if (!url || !key) return respond({error:'Server configuration is incomplete'},{status:500});
    if (!token) return respond({error:'Unauthorized'},{status:401});

    const callerClient = createClient(url, Deno.env.get('SUPABASE_ANON_KEY') || '', { auth:{persistSession:false,autoRefreshToken:false}, global:{headers:{Authorization:`Bearer ${token}`}} });
    const admin = createClient(url, key, { auth:{persistSession:false,autoRefreshToken:false} });
    const { data:{user:caller}, error:callerError } = await callerClient.auth.getUser(token);
    if (callerError || !caller) return respond({error:'Unauthorized'},{status:401});

    const { data:staff, error:staffError } = await callerClient.from('ops_staff')
      .select('role,active').eq('id',caller.id).maybeSingle();
    if (staffError) throw staffError;
    if (!staff?.active || staff.role !== 'Super admin') return respond({error:'Forbidden'},{status:403});

    const {user_id} = await req.json();
    if (!user_id || user_id === caller.id) return respond({error:'Invalid user'},{status:400});

    const {error} = await admin.auth.admin.deleteUser(user_id);
    if (error) throw error;
    await admin.from('ops_staff').update({active:false}).eq('id',user_id);
    return respond({ok:true});
  } catch(e) {
    return respond({error:e?.message||'Unable to delete user'},{status:400});
  }
});