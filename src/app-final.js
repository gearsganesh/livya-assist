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
  if(n==='dashboard')return isStaff();
  return isStaff();
};
;