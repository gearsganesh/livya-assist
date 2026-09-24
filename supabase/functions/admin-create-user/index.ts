import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { corsHeaders } from "npm:@supabase/supabase-js@2/cors";

const ROLES = ['Super admin','Coordinator','Finance','Center admin','Viewer'];

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

    const callerClient = createClient(url, Deno.env.get('SUPABASE_ANON_KEY') || '', { auth: { persistSession:false, autoRefreshToken:false }, global:{headers:{Authorization:`Bearer ${token}`}} });
    const admin = createClient(url, key, { auth:{persistSession:false,autoRefreshToken:false} });
    const { data:{ user: caller }, error: callerError } = await callerClient.auth.getUser(token);
    if (callerError || !caller) return respond({error:'Unauthorized'},{status:401});

    const { data: staff, error: staffError } = await admin.from('ops_staff')
      .select('role,scope,active').eq('id', caller.id).maybeSingle();
    if (staffError) throw staffError;
    if (!staff?.active || staff.role !== 'Super admin') return respond({error:'Forbidden'},{status:403});

    const body = await req.json();
    const email = String(body.email || '').trim().toLowerCase();
    const password = String(body.password || '');
    const full_name = String(body.full_name || '').trim();
    const role = String(body.role || 'Coordinator');
    const scope = String(body.scope || 'All centers');

    if (!email || password.length < 8 || !full_name) return respond({error:'Name, email and password are required'},{status:400});
    if (!ROLES.includes(role)) return respond({error:'Invalid role'},{status:400});
    if (scope !== 'All centers') {
      const { data:center, error:centerError } = await admin.from('ops_centers')
        .select('id').eq('name',scope).eq('active',true).maybeSingle();
      if (centerError) throw centerError;
      if (!center) return respond({error:'Invalid or inactive center scope'},{status:400});
    }

    const { data, error:createError } = await admin.auth.admin.createUser({
      email,
      password,
      email_confirm:true,
      user_metadata:{full_name, role}
    });
    if (createError) throw createError;

    const { error:staffError2 } = await admin.from('ops_staff').insert({
      id:data.user.id,
      full_name,
      email,
      role,
      scope,
      active:true
    });
    if (staffError2) {
      await admin.auth.admin.deleteUser(data.user.id);
      throw staffError2;
    }
    return respond({id:data.user.id});
  } catch(e) {
    return respond({error:e?.message||'Unable to create user'},{status:400});
  }
});