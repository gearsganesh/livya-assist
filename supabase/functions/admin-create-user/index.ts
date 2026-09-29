import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { corsHeaders } from "npm:@supabase/supabase-js@2/cors";

const ROLES = ['SUPER_ADMIN','CENTER_MANAGER','COORDINATOR','CONCIERGE_AGENT','HOSPITAL_USER'];

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
      .select('role,scope,center_id,active').eq('id', caller.id).maybeSingle();
    if (staffError) throw staffError;
    const callerRole = String(staff?.role || '').toUpperCase();
    if (!staff?.active || !['SUPER_ADMIN','CENTER_MANAGER'].includes(callerRole)) return respond({error:'Forbidden'},{status:403});

    const body = await req.json();
    const action = String(body.action || 'create').toLowerCase();
    const email = String(body.email || '').trim().toLowerCase();
    const password = String(body.password || '');
    const full_name = String(body.full_name || '').trim();
    const role = String(body.role || 'COORDINATOR');
    let scope = String(body.scope || 'All centers');
    let forcedCenterId = body.center_id ? String(body.center_id) : null;
    const hospital_id = body.hospital_id ? String(body.hospital_id) : null;

    if (!full_name) return respond({error:'Name is required'},{status:400});
    if (action === 'create' && (!email || password.length < 8)) return respond({error:'Name, email and password are required'},{status:400});
    if (!['create','update'].includes(action)) return respond({error:'Invalid action'},{status:400});
    if (!ROLES.includes(role)) return respond({error:'Invalid role'},{status:400});
    if (callerRole === 'CENTER_MANAGER') {
      if (role === 'SUPER_ADMIN') return respond({error:'Center Managers cannot create Super Admins'},{status:403});
      if (!staff.center_id) return respond({error:'Center Manager is not assigned to a center'},{status:400});
      const { data:center, error:centerError } = await admin.from('ops_centers').select('id,name').eq('id',staff.center_id).eq('active',true).maybeSingle();
      if (centerError) throw centerError;
      if (!center) return respond({error:'Manager center is invalid or inactive'},{status:400});
      forcedCenterId=center.id; scope=center.name;
    }
    let centerId = forcedCenterId;
    if (!centerId && scope !== 'All centers') {
      const { data:center, error:centerError } = await admin.from('ops_centers').select('id').eq('name',scope).eq('active',true).maybeSingle();
      if (centerError) throw centerError;
      if (!center) return respond({error:'Invalid or inactive center scope'},{status:400});
      centerId=center.id;
    }
    if (role === 'HOSPITAL_USER' && !hospital_id) return respond({error:'Hospital user must be linked to a hospital'},{status:400});

    if (action === 'update') {
      const userId = String(body.user_id || '');
      if (!userId || userId === caller.id) return respond({error:'Invalid user'},{status:400});
      const { data:target, error:targetError } = await admin.from('ops_staff')
        .select('id,center_id').eq('id',userId).maybeSingle();
      if (targetError) throw targetError;
      if (!target) return respond({error:'User not found'},{status:404});
      if (callerRole === 'CENTER_MANAGER' && target.center_id !== staff.center_id) return respond({error:'User is outside your center'},{status:403});
      if (callerRole === 'CENTER_MANAGER' && role === 'SUPER_ADMIN') return respond({error:'Center Managers cannot assign Super Admin'},{status:403});
      const targetCenterId = callerRole === 'CENTER_MANAGER' ? staff.center_id : (forcedCenterId || null);
      const targetScope = callerRole === 'CENTER_MANAGER' ? staff.scope : (scope || 'All centers');
      const { error:updateAuthError } = await admin.auth.admin.updateUserById(userId,{user_metadata:{full_name,role}});
      if (updateAuthError) throw updateAuthError;
      const { error:updateStaffError } = await admin.from('ops_staff').update({
        full_name, role, scope:targetScope, center_id:targetCenterId,
        hospital_id:role === 'HOSPITAL_USER' ? hospital_id : null,
        active:body.active !== false
      }).eq('id',userId);
      if (updateStaffError) throw updateStaffError;
      return respond({id:userId,updated:true});
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
      center_id: centerId || null,
      hospital_id: role === 'HOSPITAL_USER' ? hospital_id : null,
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