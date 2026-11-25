/* Dormant S5. Transport only; the existing Godot coordinator authorizes and
 * cold-validates every mutation. This class cannot open the production DB. */
(() => {
  'use strict';
  if(globalThis.ArenaCompactV6Browser)return;
  const PREFIX='itank-arena-test-36k-45t-';
  const allowed=n=>typeof n==='string'&&n.startsWith(PREFIX)&&/^[a-z0-9-]+$/.test(n);
  const canonical=v=>JSON.stringify(v??null,(_,x)=>x&&typeof x==='object'&&!Array.isArray(x)?Object.fromEntries(Object.keys(x).sort().map(k=>[k,x[k]])):x);
  const same=(a,b)=>canonical(a)===canonical(b);
  const fail=reason=>({success:false,state:'recovery_required',reason});
  const ok=extra=>({success:true,state:'verified_committed',...extra});
  const req=q=>new Promise((resolve,reject)=>{q.onsuccess=()=>resolve(q.result);q.onerror=()=>reject(q.error);});
  const done=tx=>new Promise((resolve,reject)=>{tx.oncomplete=resolve;tx.onabort=()=>reject(tx.error||Error('transaction_aborted'));tx.onerror=()=>{};});
  const hash=async t=>Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(t))),b=>b.toString(16).padStart(2,'0')).join('');
  class Store {
    constructor(name){
      if(!allowed(name))throw Error('disposable_database_required');
      Object.defineProperty(this,'database',{value:name,writable:false});
      this.locks=ArenaCharacterBrowserStorage.testStore({testing:true,database:name});
      this.opening=null;this.closed=false;this.jobs=new Map();this.serial=0;
    }
    guard(){if(!allowed(this.database)||this.closed)throw Error('disposable_store_closed_or_invalid');}
    async db(){
      this.guard();
      if(!this.opening)this.opening=new Promise((resolve,reject)=>{
        const q=indexedDB.open(this.database,2);let blocked=false;
        q.onupgradeneeded=()=>{
          if(blocked){q.transaction.abort();return;}
          const d=q.result;
          if(!d.objectStoreNames.contains('heads'))d.createObjectStore('heads',{keyPath:'profile'});
          if(!d.objectStoreNames.contains('generations'))d.createObjectStore('generations',{keyPath:['profile','generation']});
          if(!d.objectStoreNames.contains('transactions'))d.createObjectStore('transactions',{keyPath:['profile','transaction_id']});
          d.createObjectStore('profile_routes',{keyPath:'profile'});
          d.createObjectStore('compact_blobs',{keyPath:['profile','kind','digest']});
        };
        q.onblocked=()=>{blocked=true;reject(Error('database_upgrade_blocked'));};
        q.onerror=()=>reject(q.error);
        q.onsuccess=()=>{if(blocked){q.result.close();return;}const d=q.result;d.onversionchange=()=>{this.closed=true;d.close();};resolve(d);};
      });
      return this.opening;
    }
    async snapshot(profile){
      const t=performance.now(),d=await this.db(),tx=d.transaction(['profile_routes','compact_blobs','heads','generations','transactions'],'readonly'),end=done(tx);
      const route=await req(tx.objectStore('profile_routes').get(profile));
      const range=IDBKeyRange.bound([profile,0],[profile,Number.MAX_SAFE_INTEGER]);
      const [blobs,legacy_head,rows,receipts,count]=await Promise.all([
        req(tx.objectStore('compact_blobs').getAll(IDBKeyRange.bound([profile,'',''],[profile,'\uffff','\uffff']))),
        req(tx.objectStore('heads').get(profile)),route?Promise.resolve([]):req(tx.objectStore('generations').getAll(range)),
        route?Promise.resolve([]):req(tx.objectStore('transactions').getAll(IDBKeyRange.bound([profile,''],[profile,'\uffff']))),req(tx.objectStore('generations').count(range))
      ]);await end;
      // Legacy rows are transferred only for explicit conversion, never routine loads.
      const compact=route||null;
      return ok({route:compact,blobs,legacy_head:legacy_head||null,legacy_rows:compact?[]:rows,legacy_receipts:compact?[]:receipts,legacy_count:count,transaction_ms:performance.now()-t});
    }
    async publish(a){
      this.guard();const lease=this.locks.lease(a.profile,a.owner);if(lease.busy)return fail('operation_in_flight');lease.busy++;
      try{
        const r=a.route;if(!r||r.profile!==a.profile||r.active_format!==6||r.minimum_reader!==2||typeof a.text!=='string'||typeof a.capsule!=='string'||new TextEncoder().encode(a.text).length>16777216||new TextEncoder().encode(a.capsule).length>35651584)return fail('invalid_compact_transport');
        if(await hash(a.text)!==r.digest||await hash(a.capsule)!==r.capsule_digest||await hash(a.route_json)!==a.route_digest||!same(JSON.parse(a.route_json),r))return fail('transport_digest_mismatch');
        if(a.fault==='pause_before_transaction')await new Promise(()=>{});
        if(a.fault==='before_transaction')return fail('injected_before_transaction');
        this.guard();this.locks.lease(a.profile,a.owner);
        const d=await this.db(),t=performance.now();let tx;
        try{tx=d.transaction(['profile_routes','compact_blobs','heads','generations','transactions'],'readwrite',{durability:'strict'});}catch(e){if(!(e instanceof TypeError))throw e;tx=d.transaction(['profile_routes','compact_blobs','heads','generations','transactions'],'readwrite');}
        const end=done(tx);let rejection='';
        const rs=tx.objectStore('profile_routes'),bs=tx.objectStore('compact_blobs');
        const read=rs.get(a.profile);
        read.onsuccess=()=>{
          if(!same(read.result,a.expected_route)){rejection='stale_compact_storage_head';tx.abort();return;}
          const checks=[req(tx.objectStore('heads').get(a.profile)),req(bs.get([a.profile,'record',r.digest])),req(bs.get([a.profile,'capsule',r.capsule_digest]))];
          if(a.expected_route)checks.push(req(bs.get([a.profile,'record',a.expected_route.digest])),req(bs.get([a.profile,'capsule',a.expected_route.capsule_digest])));
          else checks.push(req(tx.objectStore('generations').getAll(IDBKeyRange.bound([a.profile,0],[a.profile,Number.MAX_SAFE_INTEGER]))),req(tx.objectStore('transactions').getAll(IDBKeyRange.bound([a.profile,''],[a.profile,'\uffff']))),req(bs.getAll(IDBKeyRange.bound([a.profile,'',''],[a.profile,'\uffff','\uffff']))));
          Promise.all(checks).then(v=>{
            if(!same(v[0],a.legacy_head)||v[1]&&v[1].text!==a.text||v[2]&&v[2].text!==a.capsule){rejection='immutable_blob_or_legacy_head_conflict';tx.abort();return;}
            if(a.expected_route){if(!same(v[3],a.expected_record)||!same(v[4],a.expected_capsule)){rejection='stored_bytes_changed_during_validation';tx.abort();return;}}
            else if(!same(v[3],a.legacy_rows)||!same(v[4],a.legacy_receipts)||v[5].length){rejection='activation_source_changed_or_orphaned';tx.abort();return;}
            bs.put({profile:a.profile,kind:'record',digest:r.digest,text:a.text});bs.put({profile:a.profile,kind:'capsule',digest:r.capsule_digest,text:a.capsule});rs.put(r);
            // Only technical unreferenced compact objects are pruned, in this same transaction.
            const cursor=bs.openCursor(IDBKeyRange.bound([a.profile,'',''],[a.profile,'\uffff','\uffff']));cursor.onsuccess=()=>{const c=cursor.result;if(!c)return;const b=c.value;if(!(b.kind==='record'&&[r.digest,r.previous].includes(b.digest))&&!(b.kind==='capsule'&&b.digest===r.capsule_digest))c.delete();c.continue();};
            if(['abort','quota'].includes(a.fault)){rejection=a.fault==='quota'?'injected_quota_exceeded':'injected_transaction_abort';tx.abort();}
          }).catch(()=>{rejection='transaction_input_failure';try{tx.abort();}catch{}});
        };
        try{await end;}catch(e){return fail(rejection||e.name||e.message);}
        const transaction_ms=performance.now()-t;
        if(a.fault==='lost_ack')return fail('acknowledgement_lost');
        const after=await this.snapshot(a.profile);
        if(!same(after.route,r)||!after.blobs.some(b=>b.kind==='record'&&b.digest===r.digest&&b.text===a.text)||!after.blobs.some(b=>b.kind==='capsule'&&b.digest===r.capsule_digest&&b.text===a.capsule))return fail('publication_readback_mismatch');
        return ok({reason:'transport_readback_verified',transaction_ms,readback_ms:after.transaction_ms,strict_durability_requested:tx.durability==='strict',power_loss_proven:false});
      }finally{lease.busy--;}
    }
    async repair(a){
      const lease=this.locks.lease(a.profile,a.owner);if(lease.busy)return fail('operation_in_flight');lease.busy++;
      try{
        if(await hash(a.text)!==a.expected_route?.digest)return fail('exact_acknowledged_bytes_required');
        const d=await this.db(),tx=d.transaction(['profile_routes','compact_blobs'],'readwrite'),end=done(tx),q=tx.objectStore('profile_routes').get(a.profile);
        q.onsuccess=()=>{if(!same(q.result,a.expected_route)){tx.abort();return;}const c=tx.objectStore('compact_blobs').get([a.profile,'capsule',q.result.capsule_digest]);c.onsuccess=()=>{if(!same(c.result,a.expected_capsule)){tx.abort();return;}tx.objectStore('compact_blobs').put({profile:a.profile,kind:'record',digest:q.result.digest,text:a.text});};};
        try{await end;}catch{return fail('repair_head_or_capsule_conflict');}return await this.snapshot(a.profile);
      }finally{lease.busy--;}
    }
    async run(operation,a={}){
      try{
        this.guard();
        if(operation==='open'){await this.db();return ok({schema:2});}
        if(operation==='acquire'||operation==='transfer'||operation==='release')return await this.locks.run(operation,a);
        if(operation==='snapshot')return await this.snapshot(a.profile);
        if(operation==='publish')return await this.publish(a);
        if(operation==='repair')return await this.repair(a);
        if(operation==='match'){const s=await this.snapshot(a.profile);return same(s.route,a.route)&&same(s.blobs,a.blobs)&&same(s.legacy_head,a.legacy_head)&&same(s.legacy_rows,a.legacy_rows)&&same(s.legacy_receipts,a.legacy_receipts)?ok({reason:'fresh_snapshot_matches'}):fail('head_or_bytes_changed_during_validation');}
        return fail('unknown_operation');
      }catch(e){return fail(e.name==='VersionError'?'unsupported_database_version':e.message||e.name);}
    }
    async close(){const r=await this.locks.close();if(!r.success)return r;if(this.opening)try{(await this.opening).close();}catch{}this.closed=true;return ok({});}
  }
  const handles=new Map();let serial=0;
  globalThis.ArenaCompactV6Browser={
    testStore:name=>new Store(name),
    create:name=>{try{const k='s5_'+(++serial);handles.set(k,new Store(name));return k;}catch{return '';}},
    request:(key,op,text)=>{const s=handles.get(key);if(!s||s.jobs.size>=16)return '';let a;try{a=JSON.parse(text);}catch{return '';}const j='job_'+(++serial);s.jobs.set(j,{success:false,state:'pending'});s.run(op,a).then(r=>s.jobs.set(j,r));return j;},
    poll:(key,job)=>{const s=handles.get(key),r=s?.jobs.get(job)||fail('unknown_job');if(r.state!=='pending')s.jobs.delete(job);return JSON.stringify(r);},
    close:async key=>{const s=handles.get(key);if(!s)return fail('unknown_store');const r=await s.close();if(r.success)handles.delete(key);return r;}
  };
})();
