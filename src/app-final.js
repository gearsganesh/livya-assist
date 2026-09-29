import { createClient } from '@supabase/supabase-js';

const supabase=createClient(
  import.meta.env.VITE_SUPABASE_URL||'https://maewvwdjxdlcbwsrshlp.supabase.co',
  import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY||'sb_publishable__edgISlScMx7zmDT1wGVpA_1N788YwM',
  {auth:{persistSession:true,autoRefreshToken:true,detectSessionInUrl:true}}
);

const SESSION_MAX=3*60*60*1000, SESSION_KEY='livya_session_started_at:';
const STAGES=['ENQUIRY','ASSESSMENT','QUOTATION','ACCEPTED','TRAVEL_PLANNED','IN_TREATMENT','DISCHARGED','FOLLOW_UP','CLOSED','CANCELLED'];
const NAV=['Dashboard','Cases','Patients','Appointments','Concierge','Tasks','Billing','Hospitals','Referral network','Team & Centers'];
const ROLES=['SUPER_ADMIN','CENTER_MANAGER','COORDINATOR','CONCIERGE_AGENT','HOSPITAL_USER','PATIENT'];
const ROLE_LABELS={SUPER_ADMIN:'Super Admin',CENTER_MANAGER:'Center Manager',COORDINATOR:'Coordinator',CONCIERGE_AGENT:'Concierge Agent',HOSPITAL_USER:'Hospital User',PATIENT:'Patient'};
const TYPES=['CONSULTATION','TELEMEDICINE','PROCEDURE','ADMISSION','FOLLOW_UP','HEALTH_CHECK'];
const APPT_STATUS=['SCHEDULED','CONFIRMED','COMPLETED','MISSED','CANCELLED'];
const CONCIERGE_TYPES=['FLIGHT','HOTEL','AIRPORT_TRANSFER','LOCAL_TRANSPORT','TRANSLATOR','VISA_ASSIST','SIM_CARD','PHARMACY','HEALTH_CHECK','WELLNESS','ATTENDANT_SUPPORT','OTHER'];
const CONCIERGE_STATUS=['REQUESTED','QUOTED','CONFIRMED','IN_DELIVERY','DELIVERED','CANCELLED'];
const DOC_CATS=['MEDICAL_REPORT','IMAGING','PRESCRIPTION','HOSPITAL_QUOTATION','PATIENT_EDUCATION','PRE_OP_INSTRUCTIONS','POST_OP_CARE','PASSPORT','VISA','FLIGHT_TICKET','HOTEL_BOOKING','INSURANCE','DISCHARGE_SUMMARY','INVOICE','OTHER'];
const INVOICE_TYPES=['HOSPITAL_COMMISSION','CONCIERGE','ANCILLARY'];
const INVOICE_STATUS=['DUE','PARTIAL','PAID','VOID'];
const TASK_STATUS=['OPEN','IN_PROGRESS','DONE','CANCELLED'];
const VISA=['NOT_REQUIRED','PENDING','APPLIED','APPROVED','REJECTED'];

const S={user:null,staff:null,patient:null,page:'Dashboard',q:'',center:'All centers',loading:false,caseView:'board'};
const D={centers:[],staff:[],patients:[],cases:[],appointments:[],concierge:[],tasks:[],billing:[],hospitals:[],referrers:[],vendors:[],dashboard:null,report:[]};
let sessionTimer=null;

const $=id=>document.getElementById(id);
const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const money=n=>'AED '+Number(n||0).toLocaleString('en-IN',{minimumFractionDigits:0,maximumFractionDigits:2});
const role=()=>String(S.staff?.role||'').toUpperCase();
const roleLabel=r=>ROLE_LABELS[String(r||'').toUpperCase()]||r||'';
const isStaff=()=>['SUPER_ADMIN','CENTER_MANAGER','COORDINATOR','CONCIERGE_AGENT'].includes(role());
const superAdmin=()=>role()==='SUPER_ADMIN'||S.staff?.role==='Super admin';
const manager=()=>superAdmin()||role()==='CENTER_MANAGER';
const coordinator=()=>manager()||role()==='COORDINATOR';
const conciergeAgent=()=>superAdmin()||role()==='CONCIERGE_AGENT';
const billingAccess=()=>manager()||role()==='COORDINATOR';
const canEditModule=n=>{
  n=String(n||'').toLowerCase();
  if(n==='team & centers')return manager();
  if(n==='cases')return coordinator();
  if(n==='patients')return coordinator();
  if(n==='appointments')return coordinator();
  if(n==='concierge')return conciergeAgent()||coordinator();
  if(n==='tasks')return isStaff();
  if(n==='billing')return billingAccess();
  if(n==='hospitals')return manager();
  if(n==='referral network')return isStaff();
  return isStaff();
};
const toast=s=>{const t=$('toast');if(!t)return;t.textContent=s;t.classList.add('show');setTimeout(()=>t.classList.remove('show'),2300)};
const run=async f=>{try{await f()}catch(e){console.error(e);toast(e.message||'Operation failed')}};
const closeModal=()=>document.querySelector('.modal')?.remove();
const patient=id=>D.patients.find(x=>x.id===id)?.full_name||'Unknown patient';
const center=id=>D.centers.find(x=>x.id===id)?.name||'';
const hospital=id=>D.hospitals.find(x=>x.id===id)?.name||'';
const referrer=id=>D.referrers.find(x=>x.id===id)?.name||'';
const caseLabel=id=>{const c=D.cases.find(x=>x.id===id);return c?c.case_code+' · '+patient(c.patient_id):''};
const scoped=a=>{
  if(S.center==='All centers')return a;
  return a.filter(x=>{
    if(x.center_id)return x.center_id===S.center;
    if(x.patient_id){const p=D.patients.find(p=>p.id===x.patient_id);if(p?.center_id)return p.center_id===S.center}
    if(x.case_id){const c=D.cases.find(c=>c.id===x.case_id);if(c?.center_id)return c.center_id===S.center}
    return true;
  });
};
const fmt=s=>s?new Date(s).toLocaleString('en-GB',{day:'2-digit',month:'short',year:'numeric',hour:'2-digit',minute:'2-digit'}):'';
const label=s=>String(s||'').replaceAll('_',' ').replace(/\b\w/g,m=>m.toUpperCase());

function Sel(labelText,id,arr,val='',mapper=x=>({value:x,label:x})){
  return '<label>'+esc(labelText)+'<select id="'+id+'">'+arr.map(x=>{const m=mapper(x);return '<option value="'+esc(m.value??'')+'" '+(String(m.value??'')===String(val??'')?'selected':'')+'>'+esc(m.label??'')+'</option>'}).join('')+'</select></label>';
}
function F(labelText,id,type='text',v=''){
  return '<label>'+esc(labelText)+'<input id="'+id+'" type="'+type+'" value="'+esc(v??'')+'"></label>';
}
function TA(labelText,id,v=''){
  return '<label>'+esc(labelText)+'<textarea id="'+id+'">'+esc(v??'')+'</textarea></label>';
}
function modal(title,form,save){
  $('app').insertAdjacentHTML('beforeend','<div class="modal"><div class="dialog"><button class="close" onclick="closeModal()">×</button><h2>'+esc(title)+'</h2>'+form+'<div class="modal-actions"><button onclick="closeModal()">Cancel</button><button class="primary" onclick="run(()=>'+save+')">Save</button></div></div></div>');
}
async function refresh(){
  if(S.patient||role()==='HOSPITAL_USER'){render();return}
  await load();
}
async function load(){
  S.loading=true;render();
  const qs=[
    ['centers',supabase.from('ops_centers').select('*').order('name')],
    ['staff',supabase.from('ops_staff').select('id,full_name,email,role,scope,center_id,hospital_id,patient_id,active').order('full_name')],
    ['patients',supabase.from('ops_patients').select('*').order('created_at',{ascending:false})],
    ['cases',supabase.from('ops_cases').select('*').order('created_at',{ascending:false})],
    ['appointments',supabase.from('ops_appointments').select('*').order('appointment_date')],
    ['concierge',supabase.from('ops_concierge').select('*').order('created_at',{ascending:false})],
    ['tasks',supabase.from('ops_tasks').select('*').order('due_date')],
    ['billing',supabase.from('ops_billing').select('*').order('created_at',{ascending:false})],
    ['hospitals',supabase.from('ops_hospitals').select('*').order('name')],
    ['referrers',supabase.from('ops_referrers').select('*').order('name')],
    ['vendors',supabase.from('ops_vendors').select('*').order('name')]
  ];
  const r=await Promise.all(qs.map(x=>x[1]));
  r.forEach((x,i)=>{if(x.error)throw x.error;D[qs[i][0]]=x.data||[]});
  const d=await supabase.rpc('ops_dashboard_summary');
  if(!d.error)D.dashboard=d.data||{};
  const rr=await supabase.rpc('ops_referral_report',{p_from:new Date(new Date().getFullYear(),0,1).toISOString().slice(0,10),p_to:new Date().toISOString().slice(0,10)});
  D.report=rr.error?[]:(rr.data||[]);
  S.loading=false;render();
}

function actionLabel(add){
  const k=String(add||'').split('(')[0];
  return ({newCase:'New Case',newPatient:'New Patient',newAppointment:'New Appointment',newConcierge:'New Concierge',newTask:'New Task',newBilling:'New Billing',newHospital:'New Hospital',newReferrer:'New Referrer',newUser:'New User'})[k]||k;
}
function head(title,add,extra=''){
  return '<div class="head"><div><h1>'+esc(title)+'</h1><p>Patient coordination & concierge operations</p></div><div>'+extra+(add&&canEditModule(title)?'<button class="primary" onclick="'+add+'">+ '+esc(actionLabel(add))+'</button>':'')+'</div></div>';
}
function filterBar(){
  return '<div class="toolbar"><input placeholder="Search..." value="'+esc(S.q)+'" oninput="S.q=this.value;render()"><select onchange="S.center=this.value;render()"><option value="All centers">All centers</option>'+D.centers.filter(c=>superAdmin()||S.staff?.scope==='All centers'||c.id===S.staff?.center_id).map(c=>'<option value="'+c.id+'" '+(S.center===c.id?'selected':'')+'>'+esc(c.name)+'</option>').join('')+'</select></div>';
}
function table(title,add,cols,rows,extra=''){
  return head(title,add,extra)+filterBar()+'<section class="table"><table><thead><tr>'+cols.map(c=>'<th>'+c+'</th>').join('')+'</tr></thead><tbody>'+(rows.join('')||'<tr><td colspan="'+cols.length+'" class="empty">No records yet.</td></tr>')+'</tbody></table></section>';
}

function dashboard(){
  const c=scoped(D.cases),k=D.dashboard||{};
  const active=c.filter(x=>!['DISCHARGED','FOLLOW_UP','CLOSED','CANCELLED'].includes(x.status)).length;
  const treatment=c.filter(x=>x.status==='IN_TREATMENT').length;
  const due=Number(k.commission_due||0);
  const rev=Number(k.concierge_revenue||0)+Number(k.ancillary_revenue||0);
  const ap=D.appointments.filter(a=>!['CANCELLED','MISSED'].includes(String(a.status).toUpperCase())).slice(0,8);
  return head('Dashboard','newCase()','<select onchange="S.center=this.value;render()"><option value="All centers">All centers</option>'+D.centers.map(c=>'<option value="'+c.id+'" '+(S.center===c.id?'selected':'')+'>'+esc(c.name)+'</option>').join('')+'</select>')+
  '<section class="cards"><button onclick="go(\'Cases\')"><small>ACTIVE CASES</small><b>'+active+'</b><span>'+c.filter(x=>x.status==='ENQUIRY').length+' enquiries</span></button>'+
  '<button onclick="go(\'Cases\')"><small>IN TREATMENT</small><b>'+treatment+'</b><span>'+c.length+' total cases</span></button>'+
  '<button onclick="go(\'Billing\')"><small>COMMISSION DUE</small><b>'+money(due)+'</b><span>Open invoices</span></button>'+
  '<button onclick="go(\'Concierge\')"><small>CONCIERGE & ANCILLARY</small><b>'+money(rev)+'</b><span>Revenue</span></button></section>'+
  '<div class="two"><section class="panel"><h2>Pipeline</h2>'+STAGES.slice(0,8).map(s=>'<button class="pipe" onclick="go(\'Cases\');S.q=\''+s+'\';render()"><span>'+label(s)+'</span><i><em style="width:'+(c.length?Math.max(2,c.filter(x=>x.status===s).length/c.length*100):2)+'%"></em></i><b>'+c.filter(x=>x.status===s).length+'</b></button>').join('')+'</section>'+
  '<section class="panel"><h2>Upcoming appointments</h2>'+ap.map(a=>'<button class="row" onclick="editAppointment(\''+a.id+'\')"><b>'+esc(patient(a.patient_id))+'</b><span>'+esc(a.title||'')+' · '+esc(a.doctor||'')+'</span><small>'+esc(a.appointment_date||'')+' '+esc(a.appointment_time||'')+'</small></button>').join('')||'<div class="empty">No appointments yet.</div>'+'</section></div>'+
  '<div class="two"><section class="panel"><h2>Upcoming arrivals</h2>'+scoped(D.cases).filter(c=>c.status==='TRAVEL_PLANNED').slice(0,8).map(c=>'<div class="row"><b>'+esc(c.case_code)+'</b><span>'+esc(patient(c.patient_id))+' · '+esc(c.specialty||'')+'</span><small>Travel planned</small></div>').join('')||'<div class="empty">No arrivals planned.</div>'+'</section>'+
  '<section class="panel"><h2>Referral performance</h2>'+D.report.slice(0,6).map(r=>'<div class="row"><b>'+esc(r.referrer||'Unknown')+'</b><span>'+esc(r.period||'')+' · '+esc(r.converted||0)+' converted</span><small>'+money(r.converted_value||0)+' business</small></div>').join('')||'<div class="empty">No referral activity yet.</div>'+'</section></div>';
}

function patients(){
  const rows=scoped(D.patients).filter(p=>JSON.stringify(p).toLowerCase().includes(S.q.toLowerCase())).map(p=>'<tr><td><b>'+esc(p.full_name)+'</b><small>'+esc(p.date_of_birth||'')+'</small></td><td>'+esc(p.phone||'')+'<small>'+esc(p.email||'')+'</small></td><td>'+esc(center(p.center_id))+'</td><td>'+esc(p.nationality||'')+'</td><td>'+D.cases.filter(c=>c.patient_id===p.id).length+'</td><td>'+(isStaff()?'<button onclick="editPatient(\''+p.id+'\')">Edit</button> <button onclick="newCase(\'\',\''+p.id+'\')">+ Case</button> ':'')+(superAdmin()?(p.app_user_id?(p.portal_enabled?'<button onclick="patientAccount(\''+p.id+'\')">Disable login</button>':'<button onclick="patientAccount(\''+p.id+'\')">Enable login</button>'):'<button onclick="patientAccount(\''+p.id+'\')">Create login</button>'):'')+(superAdmin()?'<button class="danger" onclick="deleteRecord(\'ops_patients\',\''+p.id+'\')">Delete</button>':'')+'</td></tr>');
  return table('Patients','newPatient()',['NAME','CONTACT','CENTER','NATIONALITY','CASES','ACTIONS'],rows);
}
function newPatient(id=''){
  const x=D.patients.find(p=>p.id===id)||{};
  modal(id?'Edit patient':'New patient','<div class="formgrid">'+F('Full name','pn', 'text',x.full_name)+F('Phone','pp','text',x.phone)+F('Email','pe','email',x.email)+F('Nationality','pna','text',x.nationality)+F('Country of residence','pc','text',x.country_of_residence)+F('City','pci','text',x.city)+F('Date of birth','pd','date',x.date_of_birth)+Sel('Gender','pg',['','Male','Female','Other'],x.gender)+Sel('Preferred language','pl',['en','ar'],x.preferred_language||'en')+Sel('Center','pcen',D.centers,x.center_id,x=>({value:x.id,label:x.name}))+TA('Notes','pnotes',x.notes)+'</div>','savePatient(\''+id+'\')');
}
async function savePatient(id){
  const d={full_name:$('pn').value.trim(),phone:$('pp').value.trim(),email:$('pe').value.trim()||null,nationality:$('pna').value.trim(),country_of_residence:$('pc').value.trim(),city:$('pci').value.trim(),date_of_birth:$('pd').value||null,gender:$('pg').value,preferred_language:$('pl').value,center_id:$('pcen').value||null,notes:$('pnotes').value.trim()||null};
  if(!d.full_name)return toast('Patient name is required');
  if(id){const r=await supabase.from('ops_patients').update(d).eq('id',id);if(r.error)throw r.error}else{d.created_by=S.user.id;const r=await supabase.from('ops_patients').insert(d);if(r.error)throw r.error}
  closeModal();await refresh();toast('Patient saved');
}

function newCase(id='',pid=''){
  const x=D.cases.find(c=>c.id===id)||{};
  if(!D.patients.length&&!pid)return toast('Create a patient first');
  modal(id?'Edit case':'New case','<div class="formgrid">'+Sel('Patient','cp',D.patients,pid||x.patient_id,x=>({value:x.id,label:x.full_name+' · '+(x.phone||'')}))+Sel('Center','cc',D.centers,x.center_id||D.centers[0]?.id,x=>({value:x.id,label:x.name}))+F('Specialty','sp','text',x.specialty)+F('Procedure','pr','text',x.procedure)+Sel('Hospital','ho',D.hospitals,x.hospital_id,x=>({value:x.id,label:x.name}))+Sel('Referrer','rf',D.referrers,x.referrer_id,x=>({value:x.id,label:x.name}))+Sel('Coordinator','co',D.staff.filter(s=>s.active),x.coordinator_id,x=>({value:x.id,label:x.full_name}))+Sel('Priority','pri',['Normal','High','Critical'],x.priority||'Normal')+Sel('Source','src',['WALK_IN','DOCTOR_REFERRAL','COORDINATOR_REFERRAL','WEBSITE','SOCIAL','CORPORATE','REPEAT'],x.source||'WALK_IN')+F('Estimated value','val','number',x.estimated_value)+Sel('Status','st',STAGES,x.status||'ENQUIRY')+'</div>'+TA('Internal notes','notes',x.notes),'saveCase(\''+id+'\')');
}
async function saveCase(id){
  const patientId=$('cp').value,centerId=$('cc').value;
  if(!patientId)return toast('Select a patient');
  if(!id){
    const r=await supabase.rpc('ops_create_case',{p_patient_id:patientId,p_center_id:centerId,p_specialty:$('sp').value,p_procedure:$('pr').value,p_hospital_id:$('ho').value||null,p_referrer_id:$('rf').value||null,p_coordinator_id:$('co').value||null,p_priority:$('pri').value,p_source:$('src').value,p_notes:$('notes').value,p_estimated_value:+$('val').value||0});
    if(r.error)throw r.error;
  }else{
    const old=D.cases.find(c=>c.id===id),d={patient_id:patientId,center_id:centerId,specialty:$('sp').value,procedure:$('pr').value,hospital_id:$('ho').value||null,referrer_id:$('rf').value||null,coordinator_id:$('co').value||null,priority:$('pri').value,source:$('src').value,estimated_value:+$('val').value||0,notes:$('notes').value};
    const r=await supabase.from('ops_cases').update(d).eq('id',id);if(r.error)throw r.error;
    if(old?.status!==$('st').value){const t=await supabase.rpc('ops_transition_case',{p_case_id:id,p_target:$('st').value,p_message:'Case stage updated from editor'});if(t.error)throw t.error}
  }
  closeModal();await refresh();toast('Case saved');
}
function cases(){
  const c=scoped(D.cases).filter(x=>JSON.stringify(x).toLowerCase().includes(S.q.toLowerCase()));
  return head('Cases','newCase()')+'<div class="toolbar"><input placeholder="Search cases..." value="'+esc(S.q)+'" oninput="S.q=this.value;render()"><button onclick="S.caseView=\'board\';render()">Board</button><button onclick="S.caseView=\'list\';render()">List</button></div>'+(S.caseView==='list'?caseList(c):caseBoard(c));
}
function caseBoard(c){
  return '<div class="board">'+STAGES.slice(0,8).map(s=>'<section><h3>'+label(s)+'<b>'+c.filter(x=>x.status===s).length+'</b></h3>'+c.filter(x=>x.status===s).map(x=>'<article><small>'+esc(x.case_code)+'</small><b>'+esc(patient(x.patient_id))+'</b><span>'+esc(x.specialty||'')+' · '+esc(x.procedure||'')+'</span><span>'+esc(hospital(x.hospital_id)||x.hospital||'Not assigned')+'</span><label>'+esc(label(x.priority))+'</label><div><button onclick="openCase(\''+x.id+'\')">Open workspace</button>'+(isStaff()?'<select onchange="moveCase(\''+x.id+'\',this.value)">'+STAGES.map(z=>'<option value="'+z+'" '+(z===x.status?'selected':'')+'>'+label(z)+'</option>').join('')+'</select>':'')+'</div></article>').join('')+'</section>').join('')+'</div>';
}
function caseList(c){
  return '<section class="table"><table><thead><tr><th>CASE</th><th>PATIENT</th><th>HOSPITAL</th><th>STATUS</th><th>VALUE</th><th>ACTIONS</th></tr></thead><tbody>'+c.map(x=>'<tr><td>'+esc(x.case_code)+'</td><td>'+esc(patient(x.patient_id))+'</td><td>'+esc(hospital(x.hospital_id)||x.hospital||'')+'</td><td>'+label(x.status)+'</td><td>'+money(x.estimated_value)+'</td><td><button onclick="openCase(\''+x.id+'\')">Open</button>'+(isStaff()?'<button onclick="editCase(\''+x.id+'\')">Edit</button>':'')+'</td></tr>').join('')+'</tbody></table></section>';
}
async function moveCase(id,status){
  const r=await supabase.rpc('ops_transition_case',{p_case_id:id,p_target:status,p_message:'Stage updated to '+label(status)});if(r.error)throw r.error;await refresh();toast('Case stage updated');
}

function appointments(){
  const rows=scoped(D.appointments).filter(a=>JSON.stringify(a).toLowerCase().includes(S.q.toLowerCase())).map(a=>'<tr><td>'+esc(patient(a.patient_id))+'</td><td>'+esc(a.appointment_type||'CONSULTATION')+'</td><td>'+esc(a.title)+'</td><td>'+esc(a.doctor||'')+'</td><td>'+esc(a.appointment_date||'')+' '+esc(a.appointment_time||'')+'</td><td>'+label(a.status)+'</td><td>'+(isStaff()?'<button onclick="editAppointment(\''+a.id+'\')">Edit</button>':'')+(superAdmin()?'<button class="danger" onclick="deleteRecord(\'ops_appointments\',\''+a.id+'\')">Delete</button>':'')+'</td></tr>');
  return table('Appointments','newAppointment()',['PATIENT','TYPE','TITLE','DOCTOR','DATE / TIME','STATUS','ACTIONS'],rows);
}
function newAppointment(id=''){
  const x=D.appointments.find(a=>a.id===id)||{};
  modal(id?'Edit appointment':'New appointment','<div class="formgrid">'+Sel('Patient','ap',D.patients,x.patient_id,x=>({value:x.id,label:x.full_name}))+Sel('Case','ac',D.cases.filter(c=>!x.patient_id||c.patient_id===x.patient_id),x.case_id,x=>({value:x.id,label:caseLabel(x.id)}))+Sel('Type','aty',TYPES,x.appointment_type||'CONSULTATION')+F('Title','at','text',x.title)+F('Doctor','ad','text',x.doctor)+F('Date','dt','date',x.appointment_date)+F('Time','tm','time',x.appointment_time)+F('Location','al','text',x.location)+Sel('Status','as',APPT_STATUS,x.status||'SCHEDULED')+TA('Notes','an',x.notes)+'</div>','saveAppointment(\''+id+'\')');
}
async function saveAppointment(id){
  const d={patient_id:$('ap').value,case_id:$('ac').value||null,appointment_type:$('aty').value,title:$('at').value.trim(),doctor:$('ad').value.trim()||null,appointment_date:$('dt').value,appointment_time:$('tm').value||null,location:$('al').value.trim()||null,status:$('as').value,notes:$('an').value.trim()||null};
  if(!d.patient_id||!d.title||!d.appointment_date)return toast('Patient, title and date are required');
  const r=id?await supabase.from('ops_appointments').update(d).eq('id',id):await supabase.from('ops_appointments').insert({...d,created_by:S.user.id});
  if(r.error)throw r.error;closeModal();await refresh();toast('Appointment saved');
}

function tasks(){
  const rows=scoped(D.tasks).filter(x=>JSON.stringify(x).toLowerCase().includes(S.q.toLowerCase())).map(x=>'<tr><td>'+esc(x.title)+'</td><td>'+esc(patient(x.patient_id))+'</td><td>'+esc(caseLabel(x.case_id))+'</td><td>'+label(x.priority)+'</td><td>'+esc(x.due_date||'')+'</td><td>'+label(x.status)+'</td><td><button onclick="editTask(\''+x.id+'\')">Edit</button>'+(superAdmin()?'<button class="danger" onclick="deleteRecord(\'ops_tasks\',\''+x.id+'\')">Delete</button>':'')+'</td></tr>');
  return table('Tasks','newTask()',['TITLE','PATIENT','CASE','PRIORITY','DUE','STATUS','ACTIONS'],rows);
}
function newTask(id=''){
  const x=D.tasks.find(t=>t.id===id)||{};
  modal(id?'Edit task':'New task','<div class="formgrid">'+F('Title','tt','text',x.title)+TA('Details','tdetails',x.details||x.notes)+Sel('Patient','tp',D.patients,x.patient_id,x=>({value:x.id,label:x.full_name}))+Sel('Case','tc',D.cases.filter(c=>!x.patient_id||c.patient_id===x.patient_id),x.case_id,x=>({value:x.id,label:caseLabel(x.id)}))+Sel('Assigned to','ta',D.staff.filter(s=>s.active),x.assigned_to,x=>({value:x.id,label:x.full_name}))+Sel('Priority','tpri',['Normal','High','Critical'],x.priority||'Normal')+F('Due date','tdate','date',x.due_date)+Sel('Status','ts',TASK_STATUS,x.status||'OPEN')+'</div>','saveTask(\''+id+'\')');
}
async function saveTask(id){
  const d={title:$('tt').value.trim(),notes:$('tdetails').value.trim()||null,patient_id:$('tp').value||null,case_id:$('tc').value||null,assigned_to:$('ta').value||null,priority:$('tpri').value,due_date:$('tdate').value||null,status:$('ts').value};
  if(!d.title)return toast('Task title is required');
  const r=id?await supabase.from('ops_tasks').update(d).eq('id',id):await supabase.from('ops_tasks').insert({...d,created_by:S.user.id});
  if(r.error)throw r.error;closeModal();await refresh();toast('Task saved');
}

function concierge(){
  const rows=scoped(D.concierge).filter(x=>JSON.stringify(x).toLowerCase().includes(S.q.toLowerCase())).map(x=>'<tr><td>'+esc(patient(x.patient_id))+'</td><td>'+esc(caseLabel(x.case_id))+'</td><td>'+label(x.service_type)+'</td><td>'+label(x.status)+'</td><td>'+money(x.price||x.revenue)+'</td><td>'+esc(hospital(x.vendor_id)||D.vendors.find(v=>v.id===x.vendor_id)?.name||'')+'</td><td>'+(isStaff()?'<button onclick="editConcierge(\''+x.id+'\')">Edit</button>':'')+'</td></tr>');
  return table('Concierge','newConcierge()',['PATIENT','CASE','SERVICE','STATUS','PRICE','VENDOR','ACTIONS'],rows)+
    '<section class="panel lower"><h2>Vendors</h2><button class="primary" onclick="newVendor()">+ Add Vendor</button><div class="centergrid">'+D.vendors.map(v=>'<div><b>'+esc(v.name)+'</b><span>'+esc(v.category||'')+' · '+esc(v.city||'')+'</span><span>'+esc(v.contact_phone||v.contact_email||'')+'</span><button onclick="editVendor(\''+v.id+'\')">Edit</button></div>').join('')+'</div></section>';
}
function newConcierge(id=''){
  const x=D.concierge.find(c=>c.id===id)||{};
  modal(id?'Edit concierge request':'New concierge request','<div class="formgrid">'+Sel('Patient','qp',D.patients,x.patient_id,x=>({value:x.id,label:x.full_name}))+Sel('Case','qc',D.cases.filter(c=>!x.patient_id||c.patient_id===x.patient_id),x.case_id,x=>({value:x.id,label:caseLabel(x.id)}))+Sel('Type','qtype',CONCIERGE_TYPES,x.service_type||'OTHER')+F('Title','qtitle','text',x.title||x.service_type)+TA('Details','qdetails',x.details)+F('When','qwhen','date',x.requested_for||x.service_date)+Sel('Status','qstatus',CONCIERGE_STATUS,x.status||'REQUESTED')+F('Price to patient','qprice','number',x.price)+F('Vendor cost','qcost','number',0)+Sel('Vendor','qvendor',D.vendors,x.vendor_id,x=>({value:x.id,label:x.name}))+'</div>','saveConcierge(\''+id+'\')');
}
async function saveConcierge(id){
  const d={patient_id:$('qp').value||null,case_id:$('qc').value||null,service_type:$('qtype').value,category:$('qtitle').value.trim()||null,details:$('qdetails').value.trim()||null,service_date:$('qwhen').value||null,status:$('qstatus').value,price:+$('qprice').value||0,revenue:+$('qprice').value||0,vendor_id:$('qvendor').value||null};
  if(!d.case_id)return toast('Case is required');
  if(!id){const r=await supabase.from('ops_concierge').insert({...d,created_by:S.user.id});if(r.error)throw r.error}
  else{const r=await supabase.from('ops_concierge').update(d).eq('id',id);if(r.error)throw r.error;if(['DELIVERED','CANCELLED'].includes(d.status)){const s=await supabase.rpc('ops_set_concierge_status',{p_id:id,p_status:d.status,p_price:d.price});if(s.error)throw s.error}}
  closeModal();await refresh();toast('Concierge request saved');
}
function newVendor(id=''){
  if(!(manager()||conciergeAgent()))return toast('Manager or Concierge Agent access required');
  const x=D.vendors.find(v=>v.id===id)||{};
  modal(id?'Edit vendor':'New vendor','<div class="formgrid">'+F('Name','vn','text',x.name)+F('Category','vc','text',x.category)+F('City','vci','text',x.city)+F('Country','vco','text',x.country)+F('Phone','vp','text',x.contact_phone)+F('Email','ve','email',x.contact_email)+F('Rating','vr','number',x.rating||0)+'</div>','saveVendor(\''+id+'\')');
}
async function saveVendor(id){
  const d={name:$('vn').value.trim(),category:$('vc').value.trim(),city:$('vci').value.trim(),country:$('vco').value.trim(),contact_phone:$('vp').value.trim(),contact_email:$('ve').value.trim(),rating:+$('vr').value||0};
  if(!d.name)return toast('Vendor name is required');
  const r=id?await supabase.from('ops_vendors').update(d).eq('id',id):await supabase.from('ops_vendors').insert({...d,created_by:S.user.id});
  if(r.error)throw r.error;closeModal();await refresh();toast('Vendor saved');
}

function billing(){
  const rows=scoped(D.billing).filter(x=>JSON.stringify(x).toLowerCase().includes(S.q.toLowerCase())).map(x=>'<tr><td>'+esc(x.invoice_number||x.invoice_no||'')+'</td><td>'+label(x.type)+'</td><td>'+esc(patient(x.patient_id)||hospital(x.hospital_id))+'</td><td>'+esc(caseLabel(x.case_id))+'</td><td>'+money(x.amount)+'</td><td>'+money(Number(x.paid_amount||0))+'</td><td>'+label(x.status)+'</td><td>'+(billingAccess()?'<button onclick="editBilling(\''+x.id+'\')">Edit</button> '+(Number(x.amount||0)>Number(x.paid_amount||0)&&x.status!=='VOID'?'<button onclick="recordPayment(\''+x.id+'\')">Payment</button>':''):'')+'</td></tr>');
  const rowsHtml=rows.join('');
  return table('Billing','newBilling()',['INVOICE','TYPE','BILLED TO','CASE','AMOUNT','PAID','STATUS','ACTIONS'],rows)+
    '<section class="panel lower"><h2>Commission settlements</h2><div class="table"><table><thead><tr><th>HOSPITAL</th><th>QUARTER</th><th>VOLUME</th><th>RATE</th><th>GROSS</th><th>COMMISSION</th><th>COLLECTED</th></tr></thead><tbody>'+commissionSlabs().join('')+'</tbody></table></div></section>';
}
function commissionSlabs(){
  const now=new Date(),qStart=new Date(now.getFullYear(),Math.floor(now.getMonth()/3)*3,1),converted=['ACCEPTED','TRAVEL_PLANNED','IN_TREATMENT','DISCHARGED','FOLLOW_UP','CLOSED'];
  return D.hospitals.map(h=>{
    const cs=D.cases.filter(c=>c.hospital_id===h.id&&converted.includes(c.status)&&new Date(c.updated_at||c.created_at)>=qStart);
    const volume=new Set(cs.map(c=>c.patient_id)).size;
    const rate=h.exclusivity_region?(volume>=11?35:volume>=6?30:25):25;
    const gross=cs.reduce((sum,c)=>sum+Number(c.estimated_value||0),0);
    const inv=D.billing.filter(b=>b.hospital_id===h.id&&b.type==='HOSPITAL_COMMISSION'&&b.status!=='VOID');
    const commission=inv.reduce((sum,b)=>sum+Number(b.amount||0),0),collected=inv.reduce((sum,b)=>sum+Number(b.paid_amount||0),0);
    return '<tr><td>'+esc(h.name)+'</td><td>Q'+(Math.floor(now.getMonth()/3)+1)+' '+now.getFullYear()+'</td><td>'+volume+'</td><td>'+rate+'%</td><td>'+money(gross)+'</td><td>'+money(commission)+'</td><td>'+money(collected)+'</td></tr>';
  });
}
function newBilling(id=''){
  const x=D.billing.find(b=>b.id===id)||{};
  modal(id?'Edit invoice':'New invoice','<div class="formgrid">'+(id?F('Invoice number','bin','text',x.invoice_number):'<p class="hint">Invoice number is generated automatically.</p>')+Sel('Type','bit',INVOICE_TYPES,x.type||'CONCIERGE')+Sel('Patient','bip',D.patients,x.patient_id,x=>({value:x.id,label:x.full_name}))+Sel('Case','bic',D.cases,x.case_id,x=>({value:x.id,label:caseLabel(x.id)}))+F('Gross amount','big','number',x.gross_amount||x.amount)+F('Rate %','bir','number',x.rate_pct)+F('Due date','bid','date',x.due_date||new Date().toISOString().slice(0,10))+Sel('Status','bis',INVOICE_STATUS,x.status||'DUE')+TA('Notes','binotes',x.notes)+'</div>','saveBilling(\''+id+'\')');
}
async function saveBilling(id){
  const type=$('bit').value,caseId=$('bic').value,amount=+$('big').value||0;
  if(!caseId||amount<=0)return toast('Case and amount are required');
  if(!id){
    const r=type==='HOSPITAL_COMMISSION'
      ?await supabase.rpc('ops_create_hospital_commission_invoice',{p_case_id:caseId,p_gross_amount:amount,p_due_date:$('bid').value||null,p_notes:$('binotes').value||null})
      :await supabase.rpc('ops_create_invoice',{p_case_id:caseId,p_type:type,p_amount:amount,p_patient_id:$('bip').value||null,p_hospital_id:null,p_rate_pct:+$('bir').value||null,p_due_date:$('bid').value||null,p_notes:$('binotes').value||null});
    if(r.error)throw r.error;
  }else{
    const r=await supabase.from('ops_billing').update({gross_amount:amount,amount,due_date:$('bid').value||null,rate_pct:+$('bir').value||null,status:$('bis').value,notes:$('binotes').value||null}).eq('id',id);if(r.error)throw r.error;
  }
  closeModal();await refresh();toast('Invoice saved');
}
function recordPayment(id){
  const x=D.billing.find(b=>b.id===id)||{};
  modal('Record payment','<div class="formgrid"><p>Invoice <b>'+esc(x.invoice_number||'')+'</b><br>Outstanding <b>'+money(Number(x.amount||0)-Number(x.paid_amount||0))+'</b></p>'+F('Amount','pamt','number')+Sel('Method','pmethod',['BANK_TRANSFER','CARD','CASH','ONLINE'],x.payment_method||'BANK_TRANSFER')+F('Reference','pref')+F('Date','pdate','date',new Date().toISOString().slice(0,10))+'</div>','savePayment(\''+id+'\')');
}
async function savePayment(id){
  const amount=+$('pamt').value||0;if(amount<=0)return toast('Enter a valid amount');
  const r=await supabase.rpc('ops_record_payment',{p_invoice_id:id,p_amount:amount,p_payment_method:$('pmethod').value,p_reference:$('pref').value||null,p_notes:null,p_payment_date:$('pdate').value});if(r.error)throw r.error;
  closeModal();await refresh();toast('Payment recorded');
}

function hospitals(){
  const rows=scoped(D.hospitals).filter(x=>JSON.stringify(x).toLowerCase().includes(S.q.toLowerCase())).map(h=>'<tr><td><b>'+esc(h.name)+'</b></td><td>'+esc(h.city||'')+'</td><td>'+esc(h.specialty||'')+'</td><td>'+esc(h.mou_status||'NONE')+'</td><td>'+esc(h.exclusivity_region||'Flat 25%')+'</td><td>'+esc(h.contact||h.phone||h.email||'')+'</td><td>'+(manager()?'<button onclick="editHospital(\''+h.id+'\')">Edit</button>':'')+'</td></tr>');
  return table('Hospitals','newHospital()',['NAME','CITY','SPECIALTY','MOU','COMMISSION','CONTACT','ACTIONS'],rows);
}
function newHospital(id=''){
  const x=D.hospitals.find(h=>h.id===id)||{};
  modal(id?'Edit hospital':'New hospital','<div class="formgrid">'+F('Name','hn','text',x.name)+F('City','hcity','text',x.city)+F('Specialty','hs','text',x.specialty)+F('Contact','hc','text',x.contact)+F('Phone','hp','text',x.phone)+F('Email','he','email',x.email)+F('Exclusivity region','hex','text',x.exclusivity_region)+'</div>','saveHospital(\''+id+'\')');
}
async function saveHospital(id){
  const d={name:$('hn').value.trim(),city:$('hcity').value.trim(),specialty:$('hs').value.trim(),contact:$('hc').value.trim(),phone:$('hp').value.trim(),email:$('he').value.trim(),exclusivity_region:$('hex').value.trim()||null};
  if(!d.name)return toast('Hospital name is required');
  const r=id?await supabase.from('ops_hospitals').update(d).eq('id',id):await supabase.from('ops_hospitals').insert(d);if(r.error)throw r.error;
  closeModal();await refresh();toast('Hospital saved');
}

function referrers(){
  const rows=scoped(D.referrers).filter(x=>JSON.stringify(x).toLowerCase().includes(S.q.toLowerCase())).map(r=>'<tr><td><b>'+esc(r.name)+'</b></td><td>'+esc(r.type||'')+'</td><td>'+esc(r.organization||'')+'</td><td>'+esc(r.city||'')+'</td><td>'+esc(r.email||r.contact||'')+'</td><td>'+D.cases.filter(c=>c.referrer_id===r.id).length+'</td><td>'+ (manager()||role()==='COORDINATOR'?'<button onclick="editReferrer(\''+r.id+'\')">Edit</button>':'')+'</td></tr>');
  return table('Referral network','newReferrer()',['NAME','TYPE','ORGANIZATION','CITY','CONTACT','CASES','ACTIONS'],rows)+
    '<section class="panel lower"><h2>Referral report</h2><div class="table"><table><thead><tr><th>REFERRER</th><th>PERIOD</th><th>PATIENTS</th><th>CONVERTED</th><th>CONVERSION</th><th>VALUE</th><th>COMMISSION</th><th>CONCIERGE</th></tr></thead><tbody>'+D.report.map(r=>'<tr><td>'+esc(r.referrer||'')+'</td><td>'+esc(r.period||'')+'</td><td>'+esc(r.patients||0)+'</td><td>'+esc(r.converted||0)+'</td><td>'+esc(r.conversion_pct||0)+'%</td><td>'+money(r.converted_value||0)+'</td><td>'+money(r.commission||0)+'</td><td>'+money(r.concierge||0)+'</td></tr>').join('')+'</tbody></table></div></section>';
}
function newReferrer(id=''){
  const x=D.referrers.find(r=>r.id===id)||{};
  modal(id?'Edit referrer':'New referrer','<div class="formgrid">'+F('Name','rn','text',x.name)+Sel('Type','rt', ['DOCTOR','HEALTH_COACH','CLINIC','HOSPITAL','MEDICAL_TOURISM_COORDINATOR','CORPORATE','INSURER','PATIENT_REFERRAL','OTHER'],x.type||'DOCTOR')+F('Organization','ro','text',x.organization)+F('Contact','rc','text',x.contact)+F('Email','re','email',x.email)+F('City','rci','text',x.city)+F('Country','rco','text',x.country)+'</div>','saveReferrer(\''+id+'\')');
}
async function saveReferrer(id){
  const d={name:$('rn').value.trim(),type:$('rt').value,organization:$('ro').value.trim(),contact:$('rc').value.trim(),email:$('re').value.trim(),city:$('rci').value.trim(),country:$('rco').value.trim()};
  if(!d.name)return toast('Referrer name is required');
  const r=id?await supabase.from('ops_referrers').update(d).eq('id',id):await supabase.from('ops_referrers').insert(d);if(r.error)throw r.error;
  closeModal();await refresh();toast('Referrer saved');
}

function team(){
  const rows=scoped(D.staff).map(x=>'<tr><td>'+esc(x.full_name)+'</td><td>'+esc(x.email||'')+'</td><td>'+esc(roleLabel(x.role))+'</td><td>'+esc(center(x.center_id)||x.scope||'All centers')+'</td><td>'+esc(hospital(x.hospital_id)||'')+'</td><td>'+ (x.active?'Active':'Inactive')+'</td><td>'+(manager()?'<button onclick="editUser(\''+x.id+'\')">Edit</button> <button class="danger" onclick="deleteUser(\''+x.id+'\')">Delete</button>':'')+'</td></tr>');
  return table('Team & Centers',manager()?'newUser()':null,['NAME','EMAIL','ROLE','CENTER','HOSPITAL','STATUS','ACTIONS'],rows)+
  '<section class="panel lower"><h2>Centers</h2>'+(superAdmin()?'<button class="primary" onclick="newCenter()">+ Add Center</button>':'')+'<div class="centergrid">'+D.centers.map(c=>'<div><b>'+esc(c.name)+'</b><span>'+esc(c.city||'')+' · '+esc(c.country||'')+'</span><span>'+esc(c.code||'')+' · '+esc(c.currency||'AED')+'</span>'+(superAdmin()?'<button onclick="newCenter(\''+c.id+'\')">Edit</button>':'')+'</div>').join('')+'</div></section>';
}
function newUser(id=''){
  if(!manager())return toast('Manager access required');
  const x=D.staff.find(s=>s.id===id)||{};
  const availableRoles=superAdmin()?ROLES:ROLES.filter(r=>r!=='SUPER_ADMIN');
  const centerField=superAdmin()?Sel('Center','uc',D.centers,x.center_id,x=>({value:x.id,label:x.name})):'<label>Center<input id="uc_fixed" value="'+esc(center(x.center_id)||S.staff.scope||'')+'" disabled></label>';
  modal(id?'Edit user':'New user','<div class="formgrid">'+F('Full name','un','text',x.full_name)+F('Email','ue','email',x.email)+(!id?F('Password','up','password',''):'')+Sel('Role','ur',availableRoles,x.role||'COORDINATOR',x=>({value:x,label:roleLabel(x)}))+centerField+Sel('Hospital','uh',D.hospitals,x.hospital_id,x=>({value:x.id,label:x.name}))+Sel('Status','ua',['true','false'],String(x.active!==false))+'</div>','saveUser(\''+id+'\')');
}
async function saveUser(id){
  if(!superAdmin())return toast('Super Admin access required');
  if(id){
    const r=await supabase.from('ops_staff').update({full_name:$('un').value.trim(),role:$('ur').value,center_id:$('uc').value||null,hospital_id:$('uh').value||null,active:$('ua').value==='true'}).eq('id',id);if(r.error)throw r.error;
  }else{
    const password=$('up').value;if(password.length<8)return toast('Use an 8+ character password');
    const r=await supabase.functions.invoke('admin-create-user',{body:{full_name:$('un').value,email:$('ue').value.trim().toLowerCase(),password,role:$('ur').value,scope:$('uc').value||'All centers',hospital_id:$('uh').value||null}});
    if(r.error)throw new Error(r.data?.error||r.error.message);if(r.data?.error)throw new Error(r.data.error);
  }
  closeModal();await refresh();toast('User saved');
}
function newCenter(id=''){
  if(!superAdmin())return toast('Super Admin access required');
  const x=D.centers.find(c=>c.id===id)||{};
  modal(id?'Edit center':'Add center','<div class="formgrid">'+F('Name','cn','text',x.name)+F('Code','ccode','text',x.code)+F('City','ccity','text',x.city)+F('Country','ccountry','text',x.country)+F('Currency','ccur','text',x.currency||'AED')+F('Phone','cphone','text',x.phone)+TA('Address','caddr',x.address)+'</div>','saveCenter(\''+id+'\')');
}
async function saveCenter(id){
  const d={name:$('cn').value.trim(),code:$('ccode').value.trim().toUpperCase(),city:$('ccity').value.trim(),country:$('ccountry').value.trim(),currency:$('ccur').value.trim()||'AED',phone:$('cphone').value.trim(),address:$('caddr').value.trim(),active:true};
  if(!d.name||!d.code)return toast('Center name and code are required');
  const r=id?await supabase.from('ops_centers').update(d).eq('id',id):await supabase.from('ops_centers').insert(d);if(r.error)throw r.error;
  closeModal();await refresh();toast('Center saved');
}
function editHospital(id){newHospital(id)}
function editReferrer(id){newReferrer(id)}
function editUser(id){newUser(id)}
function editPatient(id){newPatient(id)}
function editCase(id){newCase(id)}
function editAppointment(id){newAppointment(id)}
function editTask(id){newTask(id)}
function editConcierge(id){newConcierge(id)}
function editVendor(id){newVendor(id)}
function editBilling(id){newBilling(id)}
async function deleteRecord(table,id){
  if(!superAdmin())return toast('Super Admin access required');
  if(!confirm('Delete this record?'))return;
  const r=await supabase.from(table).delete().eq('id',id);if(r.error)throw r.error;await refresh();toast('Deleted');
}
async function deleteUser(id){
  if(!superAdmin())return toast('Super Admin access required');
  if(!confirm('Delete this user and disable the account?'))return;
  const r=await supabase.functions.invoke('admin-delete-user',{body:{user_id:id}});if(r.error)throw new Error(r.data?.error||r.error.message);await refresh();toast('User deleted');
}

function patientPortal(){
  const p=S.patient;
  return supabase.from('ops_cases').select('id,case_code,patient_id,center_id,hospital_id,specialty,procedure,priority,status,estimated_value,currency,created_at,updated_at').eq('patient_id',p.id).then(async cr=>{
    if(cr.error)throw cr.error;
    const cases=cr.data||[],ids=cases.map(c=>c.id); D.cases=cases; D.patients=[p];
    const [ap,ti,co,bi,doq,msg]=await Promise.all([
      supabase.from('ops_appointments').select('*').in('case_id',ids.length?ids:['00000000-0000-0000-0000-000000000000']).order('appointment_date'),
      supabase.from('ops_itineraries').select('*').in('case_id',ids.length?ids:['00000000-0000-0000-0000-000000000000']),
      supabase.from('ops_concierge').select('*').eq('patient_id',p.id).order('created_at',{ascending:false}),
      supabase.from('ops_billing').select('*').eq('patient_id',p.id).in('type',['CONCIERGE','ANCILLARY']).order('created_at',{ascending:false}),
      supabase.from('ops_documents').select('*').in('case_id',ids.length?ids:['00000000-0000-0000-0000-000000000000']).eq('visible_to_patient',true).order('created_at',{ascending:false}),
      supabase.from('ops_case_messages').select('*').in('case_id',ids.length?ids:['00000000-0000-0000-0000-000000000000']).eq('visible_to_patient',true).order('created_at')
    ]);
    [ap,ti,co,bi,doq,msg].forEach(x=>{if(x.error)throw x.error});
    return '<div class="portal"><header class="portal-head"><div class="brand livya-brand"><div class="livya-wordmark">LIVYA</div><section><small>Patient Portal</small></section></div><button onclick="logout()">Sign out</button></header><main>'+
      '<section class="welcome"><div><small>PATIENT PORTAL</small><h1>Welcome, '+esc(p.full_name)+'</h1><p>'+esc(p.email||S.user?.email||'')+' · '+esc(p.phone||'')+'</p></div><button class="primary" onclick="patientProfile()">Edit profile</button></section>'+
      '<section class="cards"><div><small>ACTIVE CASES</small><b>'+cases.filter(c=>!['CLOSED','CANCELLED'].includes(c.status)).length+'</b><span>Your care journeys</span></div><div><small>APPOINTMENTS</small><b>'+(ap.data||[]).length+'</b><span>Upcoming and completed</span></div><div><small>OUTSTANDING</small><b>'+money((bi.data||[]).reduce((s,x)=>s+Number(x.amount||0)-Number(x.paid_amount||0),0))+'</b><span>Patient invoices</span></div><div><small>CONCIERGE</small><b>'+(co.data||[]).filter(x=>!['DELIVERED','CANCELLED'].includes(String(x.status).toUpperCase())).length+'</b><span>Open requests</span></div></section>'+
      '<div class="two"><section class="panel"><h2>My cases</h2>'+(cases.map(c=>'<div class="row"><b>'+esc(c.case_code)+'</b><span>'+esc(c.specialty||'')+' · '+esc(c.procedure||'')+'</span><small>'+label(c.status)+'</small><button onclick="openCase(\''+c.id+'\')">View journey</button></div>').join('')||'<div class="empty">No cases.</div>')+'</section>'+
      '<section class="panel"><h2>Appointments</h2>'+((ap.data||[]).map(a=>'<div class="row"><b>'+esc(a.title)+'</b><span>'+esc(a.doctor||'')+'</span><small>'+esc(a.appointment_date||'')+' '+esc(a.appointment_time||'')+' · '+label(a.status)+'</small></div>').join('')||'<div class="empty">No appointments.</div>')+'</section></div>'+
      '<div class="two"><section class="panel"><h2>Travel</h2>'+((ti.data||[]).map(t=>'<div class="row"><b>'+esc(t.departure_city||'—')+' → '+esc(t.arrival_city||'—')+'</b><span>'+esc(t.outbound_flight||'')+' · '+esc(t.hotel_name||'')+'</span><small>'+esc(t.departure_date||'—')+' · Visa '+esc(t.visa_status||'PENDING')+'</small></div>').join('')||'<div class="empty">No travel plan.</div>')+'</section>'+
      '<section class="panel"><h2>Billing</h2>'+((bi.data||[]).map(b=>'<div class="row"><b>'+esc(b.invoice_number||'')+'</b><span>'+label(b.type)+' · '+money(b.amount)+'</span><small>'+label(b.status)+' · Paid '+money(b.paid_amount)+'</small></div>').join('')||'<div class="empty">No patient invoices.</div>')+'</section></div>'+
      '<section class="panel"><div class="section-head"><div><h2>Concierge</h2><p>Services around your treatment.</p></div><button class="primary" onclick="patientNewConcierge()">+ Request service</button></div>'+((co.data||[]).map(q=>'<div class="row"><b>'+esc(q.title||q.service_type)+'</b><span>'+label(q.service_type)+' · '+esc(q.details||'')+'</span><small>'+label(q.status)+'</small></div>').join('')||'<div class="empty">No concierge requests.</div>')+'</section>'+
      '<section class="panel"><h2>Documents</h2>'+((doq.data||[]).map(d=>'<div class="row"><b>'+esc(d.file_name)+'</b><span>'+label(d.category)+'</span><small>'+fmt(d.created_at)+'</small><button onclick="openDocument(\''+esc(d.storage_path)+'\')">Open</button></div>').join('')||'<div class="empty">No documents.</div>')+'</section>'+
      '</main></div>';
  });
}
function patientProfile(){
  modal('My profile','<div class="formgrid">'+F('Full name','pfname','text',S.patient.full_name)+F('Phone','pfphone','text',S.patient.phone)+F('City','pfcity','text',S.patient.city)+Sel('Preferred language','pflang',['en','ar'],S.patient.preferred_language||'en')+TA('Notes','pfnotes',S.patient.notes)+'</div>','savePatientProfile()');
}
async function savePatientProfile(){
  const d={full_name:$('pfname').value.trim(),phone:$('pfphone').value.trim(),city:$('pfcity').value.trim(),preferred_language:$('pflang').value,notes:$('pfnotes').value.trim()||null};
  if(!d.full_name)return toast('Name is required');
  const r=await supabase.from('ops_patients').update(d).eq('id',S.patient.id);if(r.error)throw r.error;
  Object.assign(S.patient,d);closeModal();render();toast('Profile updated');
}
function patientNewConcierge(){
  modal('Request concierge service','<div class="formgrid">'+Sel('Case','pcase',D.cases.filter(c=>c.patient_id===S.patient.id),D.cases.find(c=>c.patient_id===S.patient.id)?.id,x=>({value:x.id,label:caseLabel(x.id)}))+Sel('Service','ptype',CONCIERGE_TYPES,'OTHER')+F('Title','ptitle','text')+TA('Details','pdetail')+F('Requested date','pwhen','date')+'</div>','savePatientConcierge()');
}
async function savePatientConcierge(){
  const d={patient_id:S.patient.id,case_id:$('pcase').value,service_type:$('ptype').value,category:$('ptitle').value.trim()||null,details:$('pdetail').value.trim()||null,service_date:$('pwhen').value||null,status:'REQUESTED',price:0,revenue:0};
  if(!d.case_id)return toast('Select a case');
  const r=await supabase.from('ops_concierge').insert(d);if(r.error)throw r.error;closeModal();render();toast('Request submitted');
}

async function hospitalPortal(){
  const hid=S.staff?.hospital_id;
  if(!hid)return '<div class="auth"><div class="authcard"><h2>Hospital account setup required</h2><p>This account is not linked to a hospital.</p><button onclick="logout()">Sign out</button></div></div>';
  const cr=await supabase.from('ops_cases').select('id,case_code,patient_id,center_id,hospital_id,specialty,procedure,priority,status,estimated_value,currency,created_at,updated_at').eq('hospital_id',hid).order('created_at',{ascending:false});
  if(cr.error)throw cr.error;
  const cases=cr.data||[],ids=cases.map(c=>c.id);
  const [qr,ar,dr,br]=await Promise.all([
    supabase.from('ops_quotations').select('*').eq('hospital_id',hid).order('created_at',{ascending:false}),
    ids.length?supabase.from('ops_appointments').select('*').in('case_id',ids).order('appointment_date'):Promise.resolve({data:[],error:null}),
    ids.length?supabase.from('ops_documents').select('*').in('case_id',ids).eq('visible_to_hospital',true).order('created_at',{ascending:false}):Promise.resolve({data:[],error:null}),
    supabase.from('ops_billing').select('*').eq('hospital_id',hid).eq('type','HOSPITAL_COMMISSION').order('created_at',{ascending:false})
  ]);
  for(const x of [qr,ar,dr,br])if(x.error)throw x.error;
  const quotes=qr.data||[],appointments=ar.data||[],docs=dr.data||[],billing=br.data||[];
  const caseRows=cases.map(c=>{
    const actions=[];
    if(['TRAVEL_PLANNED','IN_TREATMENT'].includes(c.status))actions.push('<button onclick="hospitalMoveCase(\''+c.id+'\',\'IN_TREATMENT\')">Start treatment</button>');
    if(c.status==='IN_TREATMENT')actions.push('<button onclick="hospitalMoveCase(\''+c.id+'\',\'DISCHARGED\')">Discharge</button>');
    actions.push('<button onclick="hospitalQuote(\''+c.id+'\')">Quotation</button>');
    actions.push('<button onclick="openCase(\''+c.id+'\')">Open</button>');
    return '<div class="row"><b>'+esc(c.case_code)+'</b><span>'+esc(patient(c.patient_id))+' · '+esc(c.specialty||'')+'</span><small>'+label(c.status)+'</small>'+actions.join('')+'</div>';
  }).join('');
  const apptRows=appointments.map(a=>'<div class="row"><b>'+esc(patient(a.patient_id))+'</b><span>'+esc(a.title||'')+' · '+esc(a.doctor||'')+'</span><small>'+esc(a.appointment_date||'')+' '+esc(a.appointment_time||'')+' · '+label(a.status)+'</small></div>').join('');
  const docRows=docs.map(d=>'<div class="row"><b>'+esc(d.file_name)+'</b><span>'+label(d.category)+'</span><button onclick="openDocument(\''+esc(d.storage_path)+'\')">Open</button></div>').join('');
  const billRows=billing.map(b=>'<div class="row"><b>'+esc(b.invoice_number||'')+'</b><span>'+money(b.amount)+'</span><small>'+label(b.status)+' · Paid '+money(b.paid_amount)+'</small></div>').join('');
  return '<div class="portal"><header class="portal-head"><div class="brand livya-brand"><div class="livya-wordmark">LIVYA</div><section><small>Hospital Portal</small></section></div><button onclick="logout()">Sign out</button></header><main>'+
    '<section class="welcome"><div><small>PARTNER HOSPITAL</small><h1>Hospital operations</h1><p>'+esc(S.staff.full_name)+' · '+esc(S.staff.email||'')+'</p></div></section>'+
    '<section class="cards"><div><small>REFERRALS</small><b>'+cases.length+'</b><span>Assigned cases</span></div><div><small>QUOTATIONS</small><b>'+quotes.length+'</b><span>Submitted offers</span></div><div><small>APPOINTMENTS</small><b>'+appointments.length+'</b><span>Care schedule</span></div><div><small>COMMISSION</small><b>'+money(billing.reduce((sum,x)=>sum+Number(x.amount||0)-Number(x.paid_amount||0),0))+'</b><span>Outstanding</span></div></section>'+
    '<section class="panel"><h2>Cases</h2>'+(caseRows||'<div class="empty">No referrals.</div>')+'</section>'+
    '<div class="two"><section class="panel"><h2>Appointments</h2>'+(apptRows||'<div class="empty">No appointments.</div>')+'</section><section class="panel"><h2>Documents</h2>'+(docRows||'<div class="empty">No documents.</div>')+'</section></div>'+
    '<section class="panel"><h2>Commission invoices</h2>'+(billRows||'<div class="empty">No commission invoices.</div>')+'</section>'+
    '</main></div>';
}
async function hospitalMoveCase(id,status){
  const r=await supabase.rpc('ops_transition_case',{p_case_id:id,p_target:status,p_message:'Hospital updated case stage'});if(r.error)throw r.error;render();toast('Case updated');
}
function hospitalQuote(caseId){
  modal('Submit hospital quotation','<div class="formgrid">'+F('Reference','hqref')+F('Amount','hqamt','number')+F('Valid until','hqvalid','date')+TA('Notes','hqnotes')+'</div>','saveHospitalQuote(\''+caseId+'\')');
}
async function saveHospitalQuote(caseId){
  const r=await supabase.from('ops_quotations').insert({case_id:caseId,hospital_id:S.staff.hospital_id,reference:$('hqref').value.trim(),amount:+$('hqamt').value||0,currency:'AED',valid_until:$('hqvalid').value||null,status:'SENT',notes:$('hqnotes').value.trim(),created_by:S.user.id});
  if(r.error)throw r.error;
  const c=D.cases.find(x=>x.id===caseId);
  if(c?.status==='ASSESSMENT'){const t=await supabase.rpc('ops_transition_case',{p_case_id:caseId,p_target:'QUOTATION',p_message:'Hospital quotation submitted'});if(t.error)throw t.error}
  closeModal();render();toast('Quotation submitted');
}

async function openDocument(path){
  const r=await supabase.storage.from('case-documents').createSignedUrl(path,600);if(r.error)throw r.error;window.open(r.data.signedUrl,'_blank','noopener');
}
async function uploadDocument(caseId){
  const input=document.createElement('input');input.type='file';input.accept='.pdf,.jpg,.jpeg,.png,.doc,.docx,.xls,.xlsx,.webp';input.onchange=async()=>{
    const file=input.files?.[0];if(!file)return;if(file.size>25*1024*1024)return toast('Maximum file size is 25 MB');
    const category=prompt('Document category: '+DOC_CATS.join(', '),'OTHER')||'OTHER';
    const path=caseId+'/'+crypto.randomUUID()+'-'+file.name.replace(/[^a-zA-Z0-9._-]/g,'_');
    const up=await supabase.storage.from('case-documents').upload(path,file,{upsert:false,contentType:file.type||'application/octet-stream'});if(up.error)throw up.error;
    const ins=await supabase.from('ops_documents').insert({case_id:caseId,category,file_name:file.name,mime_type:file.type||null,storage_path:path,uploaded_by:S.user.id,visible_to_patient:true,visible_to_hospital:!S.patient});
    if(ins.error){await supabase.storage.from('case-documents').remove([path]);throw ins.error}
    toast('Document uploaded');openCase(caseId);
  };input.click();
}

async function openCase(caseId){
  const root=document.createElement('div');root.className='modal case-modal';root.innerHTML='<div class="dialog case-dialog"><button class="close" id="cwclose">×</button><div id="cw"><div class="empty">Loading case...</div></div></div>';$('app').appendChild(root);
  $('cwclose').onclick=()=>root.remove();
  const caseColumns=(role()==='HOSPITAL_USER'||S.patient)?'id,case_code,patient_id,center_id,hospital_id,specialty,procedure,priority,status,estimated_value,currency,created_at,updated_at':'*';
  const cr=await supabase.from('ops_cases').select(caseColumns).eq('id',caseId).maybeSingle();if(cr.error)throw cr.error;if(!cr.data)throw new Error('Case not found');
  const c=cr.data,ids=[caseId];
  const [pr,ce,doq,qu,it,ap,co,bi,ta,me]=await Promise.all([
    supabase.from('ops_patients').select('*').eq('id',c.patient_id).maybeSingle(),
    supabase.from('ops_case_events').select('*').eq('case_id',caseId).order('created_at',{ascending:false}),
    supabase.from('ops_documents').select('*').eq('case_id',caseId).order('created_at',{ascending:false}),
    supabase.from('ops_quotations').select('*').eq('case_id',caseId).order('created_at',{ascending:false}),
    supabase.from('ops_itineraries').select('*').eq('case_id',caseId).maybeSingle(),
    supabase.from('ops_appointments').select('*').eq('case_id',caseId).order('appointment_date'),
    supabase.from('ops_concierge').select('*').eq('case_id',caseId).order('created_at',{ascending:false}),
    supabase.from('ops_billing').select('*').eq('case_id',caseId).order('created_at',{ascending:false}),
    supabase.from('ops_tasks').select('*').eq('case_id',caseId).order('due_date'),
    supabase.from('ops_case_messages').select('*').eq('case_id',caseId).order('created_at')
  ]);
  [pr,ce,doq,qu,it,ap,co,bi,ta,me].forEach(x=>{if(x.error)throw x.error});
  let tab='overview';
  const data={p:pr.data||{},events:ce.data||[],docs:doq.data||[],quotes:qu.data||[],items:[],itinerary:it.data||{},appointments:ap.data||[],concierge:co.data||[],billing:bi.data||[],tasks:ta.data||[],messages:me.data||[]};
  if(data.quotes.length){const iq=await supabase.from('ops_quotation_items').select('*').in('quotation_id',data.quotes.map(q=>q.id));if(iq.error)throw iq.error;data.items=iq.data||[]}
  async function reload(){
    const [e,d,q,i,a,o,b,t,m]=await Promise.all([
      supabase.from('ops_case_events').select('*').eq('case_id',caseId).order('created_at',{ascending:false}),
      supabase.from('ops_documents').select('*').eq('case_id',caseId).order('created_at',{ascending:false}),
      supabase.from('ops_quotations').select('*').eq('case_id',caseId).order('created_at',{ascending:false}),
      supabase.from('ops_itineraries').select('*').eq('case_id',caseId).maybeSingle(),
      supabase.from('ops_appointments').select('*').eq('case_id',caseId).order('appointment_date'),
      supabase.from('ops_concierge').select('*').eq('case_id',caseId).order('created_at',{ascending:false}),
      supabase.from('ops_billing').select('*').eq('case_id',caseId).order('created_at',{ascending:false}),
      supabase.from('ops_tasks').select('*').eq('case_id',caseId).order('due_date'),
      supabase.from('ops_case_messages').select('*').eq('case_id',caseId).order('created_at')
    ]);
    [e,d,q,i,a,o,b,t,m].forEach(x=>{if(x.error)throw x.error});
    Object.assign(data,{events:e.data||[],docs:d.data||[],quotes:q.data||[],itinerary:i.data||{},appointments:a.data||[],concierge:o.data||[],billing:b.data||[],tasks:t.data||[],messages:m.data||[]});
    if(data.quotes.length){const iq=await supabase.from('ops_quotation_items').select('*').in('quotation_id',data.quotes.map(q=>q.id));if(iq.error)throw iq.error;data.items=iq.data||[]}else data.items=[];
    const fresh=await supabase.from('ops_cases').select(caseColumns).eq('id',caseId).single();if(fresh.error)throw fresh.error;Object.assign(c,fresh.data);
    renderWorkspace();
  }
  function renderWorkspace(){
    const canWriteCase=isStaff();
    const outstanding=data.billing.reduce((s,x)=>s+Number(x.amount||0)-Number(x.paid_amount||0),0);
    let body='';
    if(tab==='overview')body='<div class="cw-grid cw-grid-3"><article class="cw-card"><h3>Patient</h3><b>'+esc(data.p.full_name||'')+'</b><p>'+esc(data.p.phone||'')+'<br>'+esc(data.p.email||'')+'</p></article><article class="cw-card"><h3>Care</h3><p><b>'+esc(c.specialty||'')+'</b><br>'+esc(c.procedure||'')+'</p><p>Status <strong>'+label(c.status)+'</strong><br>Value <strong>'+money(c.estimated_value)+'</strong></p></article><article class="cw-card"><h3>Next appointment</h3>'+(data.appointments[0]?'<p><b>'+esc(data.appointments[0].title)+'</b><br>'+esc(data.appointments[0].appointment_date||'')+' '+esc(data.appointments[0].appointment_time||'')+'</p>':'<p>None scheduled.</p>')+'</article><article class="cw-card cw-span-2"><h3>Journey</h3><div class="cw-journey">'+STAGES.slice(0,8).map(s=>'<span class="'+(s===c.status?'now':'')+'">'+label(s)+'</span>').join('')+'</div></article><article class="cw-card"><h3>Financial</h3><p>'+data.billing.length+' invoice(s)</p><p>Outstanding <b>'+money(outstanding)+'</b></p></article></div>';
    if(tab==='timeline')body='<div class="cw-section-head"><div><h2>Timeline</h2><p>Operational history.</p></div>'+(canWriteCase?'<button class="cw-primary" id="add-event">+ Add event</button>':'')+'</div><div class="cw-timeline">'+(data.events.map(e=>'<article><span class="dot"></span><div><b>'+esc(label(e.event_type))+'</b><p>'+esc(e.message)+'</p><small>'+fmt(e.created_at)+'</small></div></article>').join('')||'<div class="cw-empty">No events yet.</div>')+'</div>';
    if(tab==='documents')body='<div class="cw-section-head"><div><h2>Documents</h2><p>Case records and treatment documents.</p></div>'+(canWriteCase||role()==='HOSPITAL_USER'||S.patient?'<button class="cw-primary" id="add-doc">+ Upload document</button>':'')+'</div><div class="cw-list">'+(data.docs.map(d=>'<article><div><b>'+esc(d.file_name)+'</b><p>'+label(d.category)+' · '+(d.visible_to_patient?'Patient visible':'Staff only')+'</p></div><small>'+fmt(d.created_at)+'</small><button data-doc="'+esc(d.storage_path)+'">Open</button></article>').join('')||'<div class="cw-empty">No documents.</div>')+'</div>';
    if(tab==='quotations')body='<div class="cw-section-head"><div><h2>Quotations</h2><p>Hospital offers and acceptance.</p></div>'+(canWriteCase||role()==='HOSPITAL_USER'?'<button class="cw-primary" id="add-quote">+ New quotation</button>':'')+'</div><div class="cw-list">'+(data.quotes.map(q=>'<article><div><b>'+esc(q.reference||'Quotation')+'</b><p>'+label(q.status)+' · '+money(q.amount)+' · Valid '+esc(q.valid_until||'—')+'</p><div class="cw-quote-items">'+(data.items.filter(i=>i.quotation_id===q.id).map(i=>'<span>'+esc(i.description)+' × '+esc(i.quantity)+' = '+money(i.amount)+'</span>').join('')||'<span>No line items.</span>')+'</div></div><small>'+fmt(q.created_at)+'</small>'+(canWriteCase&&q.status!=='ACCEPTED'&&q.status!=='REJECTED'?'<button data-item="'+q.id+'">+ Item</button><button data-accept="'+q.id+'">Accept</button>':'')+'</article>').join('')||'<div class="cw-empty">No quotations.</div>')+'</div>';
    if(tab==='appointments')body='<div class="cw-section-head"><div><h2>Appointments</h2><p>Consultations, procedures and admissions.</p></div>'+(canWriteCase||role()==='HOSPITAL_USER'?'<button class="cw-primary" id="add-appt">+ Add appointment</button>':'')+'</div><div class="cw-list">'+(data.appointments.map(a=>'<article><div><b>'+esc(a.title)+'</b><p>'+label(a.appointment_type)+' · '+esc(a.doctor||'')+' · '+esc(a.location||'')+'</p></div><small>'+esc(a.appointment_date||'')+' '+esc(a.appointment_time||'')+' · '+label(a.status)+'</small></article>').join('')||'<div class="cw-empty">No appointments.</div>')+'</div>';
    if(tab==='travel')body='<div class="cw-section-head"><div><h2>Travel & itinerary</h2><p>Flights, hotel, visa and attendants.</p></div>'+(canWriteCase?'<button class="cw-primary" id="edit-travel">Edit itinerary</button>':'')+'</div><div class="cw-grid cw-grid-2"><article class="cw-card"><h3>Flights</h3><p>'+esc(data.itinerary.departure_city||'—')+' → '+esc(data.itinerary.arrival_city||'—')+'</p><p>'+esc(data.itinerary.departure_date||'—')+' → '+esc(data.itinerary.return_date||'—')+'</p><p>'+esc(data.itinerary.outbound_flight||'—')+' · '+esc(data.itinerary.return_flight||'—')+'</p></article><article class="cw-card"><h3>Hotel & visa</h3><p>'+esc(data.itinerary.hotel_name||'—')+'</p><p>'+esc(data.itinerary.hotel_check_in||'—')+' → '+esc(data.itinerary.hotel_check_out||'—')+'</p><p>Visa: '+label(data.itinerary.visa_status||'PENDING')+' · Attendants: '+Number(data.itinerary.attendants||0)+'</p></article><article class="cw-card cw-span-2"><h3>Notes</h3><p>'+esc(data.itinerary.notes||'No notes.')+'</p></article></div>';
    if(tab==='concierge')body='<div class="cw-section-head"><div><h2>Concierge</h2><p>Services attached to this case.</p></div>'+(canWriteCase||S.patient?'<button class="cw-primary" id="add-concierge">+ Request service</button>':'')+'</div><div class="cw-list">'+(data.concierge.map(q=>'<article><div><b>'+esc(q.title||q.service_type)+'</b><p>'+label(q.service_type)+' · '+esc(q.details||'')+'</p></div><small>'+label(q.status)+' · '+money(q.price)+'</small></article>').join('')||'<div class="cw-empty">No concierge requests.</div>')+'</div>';
    if(tab==='billing')body='<div class="cw-section-head"><div><h2>Billing</h2><p>Invoices and payments.</p></div></div><div class="cw-list">'+(data.billing.map(b=>'<article><div><b>'+esc(b.invoice_number||'')+'</b><p>'+label(b.type)+' · '+money(b.amount)+' · Paid '+money(b.paid_amount)+'</p></div><small>'+label(b.status)+' · Due '+esc(b.due_date||'—')+'</small>'+(billingAccess()&&Number(b.amount||0)>Number(b.paid_amount||0)&&b.status!=='VOID'?'<button data-pay="'+b.id+'">Payment</button>':'')+'</article>').join('')||'<div class="cw-empty">No invoices.</div>')+'</div>';
    if(tab==='tasks')body='<div class="cw-section-head"><div><h2>Tasks</h2><p>Operational follow-up.</p></div>'+(canWriteCase?'<button class="cw-primary" id="add-task">+ Add task</button>':'')+'</div><div class="cw-list">'+(data.tasks.map(t=>'<article><div><b>'+esc(t.title)+'</b><p>'+label(t.priority)+' · '+esc(t.notes||'')+'</p></div><small>'+esc(t.due_date||'')+' · '+label(t.status)+'</small></article>').join('')||'<div class="cw-empty">No tasks.</div>')+'</div>';
    if(tab==='messages')body='<div class="cw-section-head"><div><h2>Case messages</h2><p>Case communication.</p></div>'+(canWriteCase||role()==='HOSPITAL_USER'||S.patient?'<button class="cw-primary" id="add-message">+ Message</button>':'')+'</div><div class="cw-messages">'+(data.messages.map(m=>'<article><b>Case participant</b><p>'+esc(m.body)+'</p><small>'+fmt(m.created_at)+'</small></article>').join('')||'<div class="cw-empty">No messages.</div>')+'</div>';
    root.querySelector('#cw').innerHTML='<header class="case-workspace-head"><div><div class="case-workspace-kicker">'+esc(c.case_code)+' · '+label(c.status)+'</div><h1>'+esc(data.p.full_name||'Patient')+' · '+esc(c.specialty||'Case')+'</h1><p>'+esc(center(c.center_id))+' · '+esc(hospital(c.hospital_id)||c.hospital||'Hospital not assigned')+' · '+label(c.priority)+'</p></div></header><nav class="case-workspace-tabs">'+[['overview','Overview'],['timeline','Timeline'],['documents','Documents'],['quotations','Quotations'],['appointments','Appointments'],['travel','Travel'],['concierge','Concierge'],['billing','Billing'],['tasks','Tasks'],['messages','Messages']].map(t=>'<button class="'+(tab===t[0]?'active':'')+'" data-tab="'+t[0]+'">'+t[1]+'</button>').join('')+'</nav><main class="case-workspace-body">'+body+'</main>';
    root.querySelectorAll('[data-tab]').forEach(b=>b.onclick=()=>{tab=b.dataset.tab;renderWorkspace()});
    root.querySelectorAll('[data-doc]').forEach(b=>b.onclick=()=>run(()=>openDocument(b.dataset.doc)));
    root.querySelectorAll('[data-accept]').forEach(b=>b.onclick=()=>run(async()=>{const r=await supabase.rpc('ops_accept_quotation',{p_quotation_id:b.dataset.accept});if(r.error)throw r.error;await reload();toast('Quotation accepted')}));
    root.querySelectorAll('[data-item]').forEach(b=>b.onclick=()=>caseQuoteItem(b.dataset.item));
    root.querySelectorAll('[data-pay]').forEach(b=>b.onclick=()=>recordPayment(b.dataset.pay));
    root.querySelector('#add-doc')?.addEventListener('click',()=>uploadDocument(caseId));
    root.querySelector('#add-event')?.addEventListener('click',()=>modal('Timeline event',Sel('Type','evtype',['NOTE','HOSPITAL','ASSIGNED','REFERRAL','DOCUMENT','TRAVEL','CONCIERGE','BILLING'],'NOTE')+TA('Message','evmsg'),'saveEvent(\''+caseId+'\')'));
    root.querySelector('#add-message')?.addEventListener('click',()=>modal('Case message',TA('Message','msgbody'),'saveMessage(\''+caseId+'\')'));
    root.querySelector('#add-appt')?.addEventListener('click',()=>caseAppointment(caseId));
    root.querySelector('#add-quote')?.addEventListener('click',()=>caseQuote(caseId));
    root.querySelector('#edit-travel')?.addEventListener('click',()=>caseTravel(caseId,data.itinerary));
    root.querySelector('#add-concierge')?.addEventListener('click',()=>caseConcierge(caseId));
    root.querySelector('#add-task')?.addEventListener('click',()=>caseTask(caseId));
  }
  window.saveEvent=async cid=>{const r=await supabase.from('ops_case_events').insert({case_id:cid,actor_id:S.user.id,event_type:$('evtype').value,message:$('evmsg').value});if(r.error)throw r.error;closeModal();await reload()};
  window.saveMessage=async cid=>{const r=await supabase.from('ops_case_messages').insert({case_id:cid,sender_id:S.user.id,body:$('msgbody').value,visible_to_patient:true});if(r.error)throw r.error;closeModal();await reload()};
  window.caseAppointment=cid=>modal('Case appointment','<div class="formgrid">'+Sel('Type','caty',TYPES,'CONSULTATION')+F('Title','cat','text')+F('Doctor','cad','text')+F('Date','cadt','date')+F('Time','catm','time')+F('Location','cal','text')+Sel('Status','cast',APPT_STATUS,'SCHEDULED')+'</div>','saveCaseAppointment(\''+cid+'\')');
  window.saveCaseAppointment=async cid=>{const r=await supabase.from('ops_appointments').insert({case_id:cid,patient_id:c.patient_id,appointment_type:$('caty').value,title:$('cat').value,doctor:$('cad').value||null,appointment_date:$('cadt').value,appointment_time:$('catm').value||null,location:$('cal').value||null,status:$('cast').value,created_by:S.user.id});if(r.error)throw r.error;closeModal();await reload()};
  window.caseQuoteItem=qid=>modal('Quotation line item','<div class="formgrid">'+F('Description','qi_desc')+F('Quantity','qi_qty','number',1)+F('Unit price','qi_price','number',0)+'</div>','saveCaseQuoteItem(\''+qid+'\')');
  window.saveCaseQuoteItem=async qid=>{const r=await supabase.from('ops_quotation_items').insert({quotation_id:qid,description:$('qi_desc').value.trim(),quantity:+$('qi_qty').value||1,unit_price:+$('qi_price').value||0});if(r.error)throw r.error;const ir=await supabase.from('ops_quotation_items').select('amount').eq('quotation_id',qid);if(ir.error)throw ir.error;const total=(ir.data||[]).reduce((sum,x)=>sum+Number(x.amount||0),0);const ur=await supabase.from('ops_quotations').update({amount:total}).eq('id',qid);if(ur.error)throw ur.error;closeModal();await reload()};
  const caseQuoteItem=window.caseQuoteItem;
  window.caseQuote=cid=>modal('Hospital quotation','<div class="formgrid">'+Sel('Hospital','qho',D.hospitals,c.hospital_id,x=>({value:x.id,label:x.name}))+F('Reference','qref')+F('Amount','qamt','number')+F('Valid until','qvalid','date')+TA('Notes','qnotes')+'</div>','saveCaseQuote(\''+cid+'\')');
  window.saveCaseQuote=async cid=>{const r=await supabase.from('ops_quotations').insert({case_id:cid,hospital_id:$('qho').value||null,reference:$('qref').value,amount:+$('qamt').value||0,currency:c.currency||'AED',valid_until:$('qvalid').value||null,status:role()==='HOSPITAL_USER'?'SENT':'DRAFT',notes:$('qnotes').value,created_by:S.user.id});if(r.error)throw r.error;if(c.status==='ASSESSMENT'){const t=await supabase.rpc('ops_transition_case',{p_case_id:cid,p_target:'QUOTATION',p_message:'Quotation added'});if(t.error)throw t.error}closeModal();await reload()};
  window.caseTravel=()=>modal('Travel itinerary','<div class="formgrid">'+F('Departure city','tdep','text',data.itinerary.departure_city)+F('Arrival city','tarr','text',data.itinerary.arrival_city)+F('Departure date','tdd','date',data.itinerary.departure_date)+F('Return date','trd','date',data.itinerary.return_date)+F('Outbound flight','tof','text',data.itinerary.outbound_flight)+F('Return flight','trf','text',data.itinerary.return_flight)+F('Hotel','th','text',data.itinerary.hotel_name)+F('Hotel check-in','thi','date',data.itinerary.hotel_check_in)+F('Hotel check-out','tho','date',data.itinerary.hotel_check_out)+Sel('Visa status','tvs',VISA,data.itinerary.visa_status||'PENDING')+F('Attendants','tatt','number',data.itinerary.attendants||0)+TA('Notes','tnotes',data.itinerary.notes)+'</div>','saveCaseTravel(\''+caseId+'\')');
  window.saveCaseTravel=async cid=>{const r=await supabase.rpc('ops_save_itinerary',{p_case_id:cid,p_departure_city:$('tdep').value||null,p_arrival_city:$('tarr').value||null,p_departure_date:$('tdd').value||null,p_return_date:$('trd').value||null,p_outbound_flight:$('tof').value||null,p_return_flight:$('trf').value||null,p_hotel_name:$('th').value||null,p_hotel_check_in:$('thi').value||null,p_hotel_check_out:$('tho').value||null,p_visa_status:$('tvs').value,p_attendants:+$('tatt').value||0,p_notes:$('tnotes').value||null});if(r.error)throw r.error;closeModal();await reload()};
  window.caseConcierge=cid=>modal('Case concierge','<div class="formgrid">'+Sel('Type','ccs',CONCIERGE_TYPES,'OTHER')+F('Title','cct')+TA('Details','ccd')+F('Price','ccp','number')+Sel('Vendor','ccv',D.vendors,'',x=>({value:x.id,label:x.name}))+'</div>','saveCaseConcierge(\''+cid+'\')');
  window.saveCaseConcierge=async cid=>{const r=await supabase.from('ops_concierge').insert({case_id:cid,patient_id:c.patient_id,service_type:$('ccs').value,title:$('cct').value||$('ccs').value,details:$('ccd').value,price:+$('ccp').value||0,revenue:+$('ccp').value||0,vendor_id:$('ccv').value||null,status:'REQUESTED',created_by:S.user.id});if(r.error)throw r.error;closeModal();await reload()};
  window.caseTask=cid=>modal('Case task','<div class="formgrid">'+F('Title','ctt')+TA('Details','ctd')+Sel('Assigned to','cta',D.staff.filter(s=>s.active),'',x=>({value:x.id,label:x.full_name}))+Sel('Priority','ctp',['Normal','High','Critical'],'Normal')+F('Due date','ctdue','date')+'</div>','saveCaseTask(\''+cid+'\')');
  window.saveCaseTask=async cid=>{const r=await supabase.from('ops_tasks').insert({case_id:cid,patient_id:c.patient_id,title:$('ctt').value,notes:$('ctd').value,assigned_to:$('cta').value||null,priority:$('ctp').value,due_date:$('ctdue').value||null,status:'OPEN',created_by:S.user.id});if(r.error)throw r.error;closeModal();await reload()};
  renderWorkspace();
}

function auth(){
  return '<div class="auth"><div class="authcard"><div class="brand livya-brand"><div class="livya-wordmark">LIVYA</div><section><small>Patient Coordination & Concierge</small></section></div><h1>Sign in</h1><form onsubmit="login(event)"><label>Email<input id="email" type="email" autocomplete="username" required></label><label>Password<input id="password" type="password" autocomplete="current-password" required></label><p id="err" class="error"></p><button class="primary" type="submit">Sign in</button></form><button onclick="forgotPassword()">Forgot password?</button></div></div>';
}
function shell(body){
  $('app').innerHTML='<div class="app"><aside><div class="brand livya-brand"><div class="livya-wordmark">LIVYA</div><section><small>Patient Coordination & Concierge</small></section></div><nav>'+NAV.map(n=>'<button class="'+(S.page===n?'active':'')+'" onclick="go(\''+n+'\')">'+esc(n)+'</button>').join('')+'</nav><footer><strong>'+esc(S.staff.full_name)+'</strong><small>'+esc(roleLabel(S.staff.role))+' · '+esc(S.staff.scope||center(S.staff.center_id)||'All centers')+'</small><button onclick="logout()">Sign out</button></footer></aside><main><header><strong>LIVYA OPS</strong><span>'+new Date().toLocaleDateString('en-GB',{day:'2-digit',month:'short',year:'numeric'})+' <i>'+esc((S.staff.full_name||'L')[0])+'</i></span></header>'+body+'</main></div>';
}
function go(p){S.page=p;S.q='';render()}
function render(){
  if(S.patient){patientPortal().then(b=>$('app').innerHTML=b).catch(e=>$('app').innerHTML='<div class="auth"><div class="authcard"><h2>Portal error</h2><p>'+esc(e.message)+'</p></div></div>');return}
  if(role()==='HOSPITAL_USER'){hospitalPortal().then(b=>$('app').innerHTML=b).catch(e=>$('app').innerHTML='<div class="auth"><div class="authcard"><h2>Hospital portal error</h2><p>'+esc(e.message)+'</p></div></div>');return}
  if(!S.staff){$('app').innerHTML=auth();return}
  if(S.loading){$('app').innerHTML='<div class="auth"><div class="authcard"><h2>Loading LIVYA OPS…</h2></div></div>';return}
  const body=S.page==='Dashboard'?dashboard():S.page==='Cases'?cases():S.page==='Patients'?patients():S.page==='Appointments'?appointments():S.page==='Concierge'?concierge():S.page==='Tasks'?tasks():S.page==='Billing'?billing():S.page==='Hospitals'?hospitals():S.page==='Referral network'?referrers():S.page==='Team & Centers'?team():dashboard();
  shell(body);
}
function beginSession(uid){
  const key=SESSION_KEY+uid;
  let started=Number(localStorage.getItem(key));
  if(!started){started=Date.now();localStorage.setItem(key,String(started))}
  const remaining=SESSION_MAX-(Date.now()-started);
  if(remaining<=0){expireSession(uid);return false}
  clearTimeout(sessionTimer);sessionTimer=setTimeout(()=>expireSession(uid),remaining);return true;
}
async function expireSession(uid){
  clearTimeout(sessionTimer);localStorage.removeItem(SESSION_KEY+uid);await supabase.auth.signOut();S.user=S.staff=S.patient=null;render();toast('Your 3-hour session has expired. Please sign in again.');
}
async function login(e){
  e.preventDefault();$('err').textContent='';
  const r=await supabase.auth.signInWithPassword({email:$('email').value.trim().toLowerCase(),password:$('password').value});
  if(r.error){$('err').textContent=r.error.message;return}
  if(!beginSession(r.data.user.id))return;
  await boot();
}
async function logout(){
  clearTimeout(sessionTimer);if(S.user?.id)localStorage.removeItem(SESSION_KEY+S.user.id);
  await supabase.auth.signOut();S.user=S.staff=S.patient=null;render();
}
async function boot(){
  const u=await supabase.auth.getUser();if(!u.data.user)return;
  if(!beginSession(u.data.user.id))return;
  const sr=await supabase.from('ops_staff').select('*').eq('id',u.data.user.id).maybeSingle();if(sr.error)throw sr.error;
  if(sr.data?.active){S.user=u.data.user;S.staff=sr.data;S.patient=null;await load();return}
  const pr=await supabase.from('ops_patients').select('*').eq('app_user_id',u.data.user.id).eq('portal_enabled',true).maybeSingle();if(pr.error)throw pr.error;
  if(pr.data){S.user=u.data.user;S.staff=null;S.patient=pr.data;render();return}
  await supabase.auth.signOut();localStorage.removeItem(SESSION_KEY+u.data.user.id);throw new Error('Account is not active');
}
async function forgotPassword(){
  const email=$('email')?.value?.trim().toLowerCase();if(!email)return toast('Enter your email first');
  const r=await supabase.auth.resetPasswordForEmail(email,{redirectTo:window.location.origin});if(r.error)throw r.error;toast('Password reset email sent');
}
async function patientAccount(id){
  if(!superAdmin())return toast('Super Admin access required');
  const p=D.patients.find(x=>x.id===id);if(!p)return;
  const action=p.app_user_id?(p.portal_enabled?'disable':'enable'):'create';
  const form=action==='create'?F('Login email','pae','email',p.email)+F('Initial password','pap','password'):('<p>'+esc(p.full_name)+'</p><button class="primary" onclick="run(()=>managePatientAccount(\''+id+'\',\''+action+'\')">'+(action==='enable'?'Enable login':'Disable login')+'</button>');
  modal('Patient login',form,action==='create'?'managePatientAccount(\''+id+'\',\'create\')':'closeModal()');
}
async function managePatientAccount(id,action){
  const body={action,patient_id:id};
  if(action==='create'){body.email=$('pae').value.trim().toLowerCase();body.password=$('pap').value;if(body.password.length<8)return toast('Use an 8+ character password')}
  const r=await supabase.functions.invoke('admin-patient-account',{body});if(r.error)throw new Error(r.data?.error||r.error.message);if(r.data?.error)throw new Error(r.data.error);
  closeModal();await refresh();toast('Patient login updated');
}
supabase.auth.onAuthStateChange((event)=>{if(event==='SIGNED_OUT'){clearTimeout(sessionTimer);S.user=S.staff=S.patient=null;render()}});
Object.assign(window,{closeModal,run,go,render,login,logout,forgotPassword,newPatient,savePatient,newCase,saveCase,editPatient,editCase,openCase,moveCase,newAppointment,saveAppointment,editAppointment,newTask,saveTask,editTask,newConcierge,saveConcierge,editConcierge,newVendor,editVendor,saveVendor,newBilling,saveBilling,editBilling,recordPayment,savePayment,newHospital,editHospital,saveHospital,newReferrer,editReferrer,saveReferrer,newUser,editUser,saveUser,deleteUser,newCenter,saveCenter,deleteRecord,patientAccount,managePatientAccount,hospitalMoveCase,hospitalQuote,saveHospitalQuote,openDocument,patientNewConcierge,savePatientConcierge,patientProfile,savePatientProfile});
render();
(async()=>{try{const s=await supabase.auth.getSession();if(s.data.session){await boot();return}}catch(e){console.error(e)}render()})();