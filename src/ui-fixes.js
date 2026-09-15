/* LIVYA OPS cleanup + compatibility fixes */
(function(){
  const CLEAN_MARK='livya_ops_clean_v1';
  try{
    /* Remove the old demo dataset once. Future records are preserved. */
    if(!localStorage.getItem(CLEAN_MARK)){
      db.users=[];
      db.patients=[];
      db.cases=[];
      db.appointments=[];
      db.concierge=[];
      db.tasks=[];
      db.billing=[];
      db.hospitals=[];
      db.referrers=[];
      db.centers=[];
      save();
      session=null;
      localStorage.removeItem(SESSION);
      localStorage.setItem(CLEAN_MARK,'1');
    }
  }catch(e){ console.warn('LIVYA cleanup skipped',e); }

  /* The Team screen previously rendered an edit button for a missing function. */
  window.editUser=function(id){ return newUser(id); };

  /* Avoid broken select controls when no centers have been created yet. */
  const originalNewPatient=window.newPatient;
  const originalNewCase=window.newCase;
  window.newPatient=function(eid){
    if(!db.centers.length){ toast('Create a center first in Team & Centers'); go('Team & Centers'); return; }
    return originalNewPatient(eid);
  };
  window.newCase=function(eid,pid){
    if(!db.centers.length){ toast('Create a center first in Team & Centers'); go('Team & Centers'); return; }
    if(!db.patients.length && !pid){ toast('Create a patient first'); go('Patients'); return; }
    return originalNewCase(eid,pid);
  };

  if(typeof render==='function') render();
})();
