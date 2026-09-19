import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

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
  if (req.method === 'OPTIONS') return new Response('ok');
  try {
    const url = Deno.env.get('SUPABASE_URL') || '';
    const key = secretKey();
    const auth = req.headers.get('Authorization') || '';
    const token = auth.replace(/^Bearer\s+/i, '');
    if (!url || !key) return Response.json({error:'Server configuration is incomplete'},{status:500});
    if (!token) return Response.json({error:'Unauthorized'},{status:401});

    const admin = createClient(url, key, { auth:{persistSession:false,autoRefreshToken:false} });
    const { data:{user:caller}, error:callerError } = await admin.auth.getUser(token);
    if (callerError || !caller) return Response.json({error:'Unauthorized'},{status:401});

    const { data:staff, error:staffError } = await admin.from('ops_staff')
      .select('role,active').eq('id',caller.id).maybeSingle();
    if (staffError) throw staffError;
    if (!staff?.active || staff.role !== 'Super admin') return Response.json({error:'Forbidden'},{status:403});

    const {user_id} = await req.json();
    if (!user_id || user_id === caller.id) return Response.json({error:'Invalid user'},{status:400});

    const {error} = await admin.auth.admin.deleteUser(user_id);
    if (error) throw error;
    return Response.json({ok:true});
  } catch(e) {
    return Response.json({error:e?.message||'Unable to delete user'},{status:400});
  }
});