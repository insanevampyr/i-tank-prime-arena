/* Pass C disposable transport only. Mandatory external Godot semantic verifier.
 * Never opens the production DB. All referenced evidence is inside each V6 blob. */
(() => {
  'use strict';
  const prefix = 'itank-arena-disposable-v6-45m-';
  const fail = reason => ({success:false, state:'recovery_required', reason});
  const hash = async text => Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(text))),b=>b.toString(16).padStart(2,'0')).join('');
  const request = q => new Promise((resolve,reject)=>{q.onsuccess=()=>resolve(q.result);q.onerror=()=>reject(q.error);});
  const done = tx => new Promise((resolve,reject)=>{tx.oncomplete=resolve;tx.onabort=()=>reject(Error('transaction_aborted'));tx.onerror=()=>{};});
  class Store {
    constructor(name, verify, profile='dev_vaelis_thorn', namespace='dev_normal') {
      if (!name.startsWith(prefix) || !/^[a-z0-9-]+$/.test(name) || typeof verify!=='function') throw Error('disposable_database_required');
      this.name=name; this.verify=verify; this.profile=profile; this.namespace=namespace;this.opening=null;
    }
    async db() {
      if(!this.name.startsWith(prefix)||!/^[a-z0-9-]+$/.test(this.name))throw Error('disposable_database_required');
      if(!this.opening)this.opening=new Promise((resolve,reject)=>{const q=indexedDB.open(this.name,1);q.onupgradeneeded=()=>{q.result.createObjectStore('head');q.result.createObjectStore('records');};q.onsuccess=()=>{q.result.onversionchange=()=>q.result.close();resolve(q.result);};q.onerror=()=>reject(q.error);q.onblocked=()=>reject(Error('test_database_blocked'));});
      return this.opening;
    }
    async snapshot() {
      const db=await this.db(),tx=db.transaction(['head','records'],'readonly'), completion=done(tx);
      const a=request(tx.objectStore('head').get('current')),b=request(tx.objectStore('records').getAll()),c=request(tx.objectStore('records').getAllKeys());
      const [head,values,keys]=await Promise.all([a,b,c]);await completion;
      return {head,records:new Map(keys.map((k,i)=>[k,values[i]]))};
    }
    async checked(text, parent=null) {
      if(typeof text!=='string')return fail('record_missing');
      const result=await this.verify(text,parent);
      if(!result.success)return result;
      if(result.profile!==this.profile||result.namespace!==this.namespace)return fail('profile_identity_mismatch');
      return {...result,digest:await hash(text)};
    }
    async load() {
      const start=performance.now(),snap=await this.snapshot();
      if(!snap.head)return fail('head_missing');
      const text=snap.records.get(snap.head.digest);
      if(typeof text!=='string'||await hash(text)!==snap.head.digest)return {...fail('latest_record_damaged'),head:snap.head};
      const checked=await this.checked(text);
      if(!checked.success||checked.digest!==snap.head.digest)return {...fail('latest_record_damaged'),head:snap.head};
      if(checked.sequence!==snap.head.sequence||checked.epoch!==snap.head.epoch||snap.head.profile!==this.profile||snap.head.namespace!==this.namespace||snap.head.version!==1)return fail('committed_identity_mismatch');
      return {success:true,text,head:snap.head,record:checked.record,load_ms:performance.now()-start};
    }
    async previous() {
      const snap=await this.snapshot(),text=snap.records.get(snap.head?.previous);
      if(typeof text!=='string'||await hash(text)!==snap.head.previous)return fail('previous_record_damaged');
      const checked=await this.checked(text);
      return checked.success&&checked.digest===snap.head.previous?{success:true,diagnostic_only:true,is_current:false,text}:fail('previous_record_damaged');
    }
    async publish(text,expected,fault='') {
      if(!['','before_transaction','abort_transaction','lost_ack'].includes(fault))return fail('unknown_fault');
      const start=performance.now(),snap=await this.snapshot();
      let before=null;
      if(snap.head){before=await this.load();if(!before.success)return before;}
      else if(snap.records.size)return fail('unknown_or_existing_head');
      // Semantic replay occurs outside the IDB transaction; its exact head and
      // bytes are then compared again inside the atomic publication transaction.
      const checked=await this.checked(text,before?.text||null);
      if(!checked.success)return checked;
      if(before&&checked.digest===before.head.digest)return {...before,already_applied:true};
      const candidate=checked.record;
      if(!before&&(expected!==null||checked.sequence!==1))return fail('initial_baseline_required');
      if(before&&JSON.stringify(expected)!==JSON.stringify({sequence:before.head.sequence,digest:before.head.digest}))return fail('stale_expected_head');
      return this.commitVerified(text,checked,snap,before,fault,start);
    }
    // Shared transport CAS. Callers must validate complete proof before this.
    async commitVerified(text,checked,snap,before,fault,start,extra={},previousDigest=undefined) {
      if(!['','before_transaction','abort_transaction','lost_ack'].includes(fault))return fail('unknown_fault');
      if(fault==='before_transaction')return fail('injected_before_transaction');
      const db=await this.db(),tx=db.transaction(['head','records'],'readwrite',{durability:'strict'}),completion=done(tx);
      let reason=null;
      const q=tx.objectStore('head').get('current');
      const head={version:1,profile:this.profile,namespace:this.namespace,epoch:checked.epoch,sequence:checked.sequence,digest:checked.digest,previous:previousDigest===undefined?(before?.head.digest||null):previousDigest};
      q.onsuccess=()=>{
        if(JSON.stringify(q.result||null)!==JSON.stringify(snap.head||null)){reason='head_changed_during_validation';tx.abort();return;}
        const current=before?tx.objectStore('records').get(before.head.digest):null;
        const write=()=>{
          if(current&&current.result!==before.text){reason='record_changed_during_validation';tx.abort();return;}
          tx.objectStore('records').put(text,checked.digest);
          for(const [key,value] of Object.entries(extra))tx.objectStore('records').put(value,key);
          tx.objectStore('head').put(head,'current');
          for(const key of snap.records.keys())if(key!==checked.digest&&key!==head.previous&&!Object.hasOwn(extra,key))tx.objectStore('records').delete(key);
          if(fault==='abort_transaction'){reason='injected_transaction_abort';tx.abort();}
        };
        if(current)current.onsuccess=write;else write();
      };
      try{await completion;}catch(e){return fail(reason||e.message);}
      if(fault==='lost_ack')return fail('acknowledgement_lost');
      const readStart=performance.now(),loaded=await this.load();
      if(!loaded.success||loaded.text!==text||JSON.stringify(loaded.head)!==JSON.stringify(head))return fail('readback_not_verified');
      return {...loaded,save_ms:performance.now()-start,readback_ms:performance.now()-readStart,record_count:(await this.snapshot()).records.size};
    }
    async recover(){const start=performance.now(),loaded=await this.load();return {...loaded,recovery_ms:performance.now()-start};}
    async repairExact(text){
      const snap=await this.snapshot(),checked=await this.checked(text);
      if(!checked.success||!snap.head||checked.digest!==snap.head.digest)return fail('exact_acknowledged_record_required');
      const db=await this.db(),tx=db.transaction(['head','records'],'readwrite'),completion=done(tx),q=tx.objectStore('head').get('current');
      q.onsuccess=()=>{if(JSON.stringify(q.result)!==JSON.stringify(snap.head)){tx.abort();return;}tx.objectStore('records').put(text,checked.digest);};
      try{await completion;}catch{return fail('repair_head_conflict');}return this.load();
    }
    async fault(which){
      const snap=await this.snapshot(),db=await this.db(),tx=db.transaction(['head','records'],'readwrite'),completion=done(tx);
      if(which==='latest_corrupt')tx.objectStore('records').put('corrupt',snap.head.digest);
      else if(which==='latest_missing')tx.objectStore('records').delete(snap.head.digest);
      else if(which==='previous_corrupt')tx.objectStore('records').put('corrupt',snap.head.previous);
      else if(which==='head_missing')tx.objectStore('head').delete('current');
      else{tx.abort();throw Error('unknown_fault');}await completion;
    }
    async close(){if(this.opening)(await this.opening).close();this.opening=null;}
  }
  globalThis.DisposableV6Store=Store;
})();
