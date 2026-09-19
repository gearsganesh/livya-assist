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

    const callerClient = createClient(url, Deno.env.get('SUPABASE_ANON_KEY') || '', { auth:{persistSession:false,autoRefreshToken:false}, global:{headers:{Authorization:`Bearer ${token}`}} });
    const admin = createClient(url, key, { auth:{persistSession:false,autoRefreshToken:false} });
    const {data:{user:caller},error:callerError}=await callerClient.auth.getUser(token);
    if(callerError||!caller) return Response.json({error:'Unauthorized'},{status:401});

    const {data:staff,error:staffError}=await callerClient.from('ops_staff')
      .select('role,active').eq('id',caller.id).maybeSingle();
    if(staffError) throw staffError;
    if(!staff?.active||staff.role!=='Super admin') return Response.json({error:'Forbidden'},{status:403});

    const body=await req.json();
    const action=String(body.action||'');
    const patientId=String(body.patient_id||'');
    if(!patientId) return Response.json({error:'Patient is required'},{status:400});

    const {data:patient,error:patientError}=await admin.from('ops_patients')
      .select('id,full_name,email,app_user_id,portal_enabled').eq('id',patientId).maybeSingle();
    if(patientError) throw patientError;
    if(!patient) return Response.json({error:'Patient not found'},{status:404});

    if(action==='create'){
      const email=String(body.email||patient.email||'').trim().toLowerCase();
      const password=String(body.password||'');
      if(!email||password.length<8) return Response.json({error:'Patient email and an 8+ character password are required'},{status:400});
      if(patient.app_user_id) return Response.json({error:'This patient already has a login account'},{status:409});

      const {data,error:createError}=await admin.auth.admin.createUser({
        email,password,email_confirm:true,
        user_metadata:{role:'Patient',patient_id:patient.id,full_name:patient.full_name}
      });
      if(createError) throw createError;

      const {error:updateError}=await admin.from('ops_patients').update({
        email,app_user_id:data.user.id,portal_enabled:true,updated_at:new Date().toISOString()
      }).eq('id',patient.id);
      if(updateError){
        await admin.auth.admin.deleteUser(data.user.id);
        throw updateError;
      }
      return Response.json({id:data.user.id,enabled:true});
    }

    if(!patient.app_user_id) return Response.json({error:'This patient does not have a login account'},{status:409});

    if(action==='enable'){
      const {error}=await admin.auth.admin.updateUserById(patient.app_user_id,{ban_duration:'none'});
      if(error) throw error;
      await admin.from('ops_patients').update({portal_enabled:true,updated_at:new Date().toISOString()}).eq('id',patient.id);
      return Response.json({enabled:true});
    }

    if(action==='disable'){
      const {error}=await admin.auth.admin.updateUserById(patient.app_user_id,{ban_duration:'876000h'});
      if(error) throw error;
      await admin.from('ops_patients').update({portal_enabled:false,updated_at:new Date().toISOString()}).eq('id',patient.id);
      return Response.json({enabled:false});
    }

    if(action==='reset'){
      const password=String(body.password||'');
      if(password.length<8) return Response.json({error:'Use an 8+ character password'},{status:400});
      const {error}=await admin.auth.admin.updateUserById(patient.app_user_id,{password});
      if(error) throw error;
      return Response.json({ok:true});
    }

    return Response.json({error:'Invalid action'},{status:400});
  } catch(e) {
    return Response.json({error:e?.message||'Unable to manage patient account'},{status:400});
  }
});