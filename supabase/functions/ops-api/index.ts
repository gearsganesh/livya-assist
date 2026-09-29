import { createClient } from "jsr:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json"
};

const json=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:cors});

Deno.serve(async (req)=>{
  if(req.method==="OPTIONS") return new Response("ok",{headers:cors});
  if(req.method!=="POST") return json({error:"POST required"},405);

  const auth=req.headers.get("Authorization");
  if(!auth) return json({error:"Authorization required"},401);

  const supabase=createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    {global:{headers:{Authorization:auth}}}
  );

  const {data:{user},error:userError}=await supabase.auth.getUser();
  if(userError||!user) return json({error:"Unauthorized"},401);

  const body=await req.json().catch(()=>({}));
  const action=String(body.action||"");

  if(action==="dashboard"){
    const r=await supabase.rpc("ops_dashboard_summary");
    return r.error?json({error:r.error.message},400):json({data:r.data});
  }

  if(action==="referral_report"){
    const r=await supabase.rpc("ops_referral_report",{p_from:body.from||null,p_to:body.to||null});
    return r.error?json({error:r.error.message},400):json({data:r.data||[]});
  }

  const rpcMap:Record<string,string>={
    transition_case:"ops_transition_case",
    create_case:"ops_create_case",
    accept_quotation:"ops_accept_quotation",
    save_itinerary:"ops_save_itinerary",
    create_invoice:"ops_create_invoice",
    record_payment:"ops_record_payment",
    concierge_status:"ops_set_concierge_status"
  };

  const rpc=rpcMap[action];
  if(!rpc) return json({error:"Unknown action"},400);

  const payload={...body};
  delete payload.action;
  const r=await supabase.rpc(rpc,payload);
  return r.error?json({error:r.error.message},400):json({data:r.data});
});