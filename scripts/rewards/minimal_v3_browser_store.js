/* Dormant 46J transport only. No production DB name/default/upgrade path.
 * Source/semantic authority stays in the existing Godot coordinator.
 */
(() => {
  'use strict';
  if (globalThis.ArenaV3Browser) return;
  const PREFIX='itank-arena-disposable-v3-46j-', MAX=24*1024*1024;
  const validName=n=>typeof n==='string'&&n.startsWith(PREFIX)&&/^[a-z0-9-]{1,160}$/.test(n);
  const id=n=>typeof n==='string'&&/^[a-z0-9_-]{1,64}$/.test(n);
  const ok=(extra={})=>({success:true,state:'verified_committed',...extra});
  const error=(reason,name='Error')=>Object.assign(new Error(reason),{name});
  const failed=e=>({success:false,state:'failed',reason:e.message||e.name,error_name:e.name});
  const request=q=>new Promise((resolve,reject)=>{q.onsuccess=()=>resolve(q.result);q.onerror=()=>reject(q.error);});
  const done=t=>new Promise((resolve,reject)=>{t.oncomplete=resolve;t.onabort=()=>reject(t.error||error('transaction_aborted','AbortError'));t.onerror=()=>{};});
  const same=(a,b)=>a===b||!!a&&!!b&&a.profile===b.profile&&a.head===b.head&&a.current===b.current&&a.replica===b.replica;
  const sha=async t=>Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(t))),b=>b.toString(16).padStart(2,'0')).join('');
  class Store {
    constructor(name){if(!validName(name))throw error('disposable_database_required');Object.defineProperty(this,'database',{value:name});this.opening=null;this.leases=new Map();this.closed=false;this.fault='';this.barrier=null;}
    async db(){
      if(this.closed||!isSecureContext||!indexedDB||!crypto?.subtle)throw error('browser_storage_unavailable');
      if(!this.opening)this.opening=new Promise((resolve,reject)=>{
        const q=indexedDB.open(this.database,1);let blocked=false;
        q.onupgradeneeded=()=>q.result.createObjectStore('characters',{keyPath:'profile'});
        q.onerror=()=>reject(q.error);q.onblocked=()=>{blocked=true;reject(error('database_open_blocked'));};
        q.onsuccess=()=>{if(blocked){q.result.close();return;}q.result.onversionchange=()=>{q.result.close();this.closed=true;};resolve(q.result);};
      });return this.opening;
    }
    async acquire(profile,owner){
      if(!id(profile)||!id(owner)||!navigator.locks?.request)throw error('web_lock_identity_unavailable');
      if(this.leases.has(profile)){const l=this.leases.get(profile);return l.owner===owner&&l.release?ok({owner}):failed(error('writer_lock_busy'));}
      const l={owner,busy:0,release:null};this.leases.set(profile,l);
      return new Promise((resolve,reject)=>navigator.locks.request(`${this.database}:writer:${profile}`,{mode:'exclusive',ifAvailable:true},lock=>{
        if(!lock){this.leases.delete(profile);resolve(failed(error('profile_in_use')));return;}
        return new Promise(release=>{l.release=release;resolve(ok({owner}));});
      }).catch(e=>{this.leases.delete(profile);reject(e);}));
    }
    lease(p,o){const l=this.leases.get(p);if(!l||l.owner!==o||!l.release)throw error('writer_ownership_required');return l;}
    release(p,o){const l=this.lease(p,o);if(l.busy)throw error('writer_busy');this.leases.delete(p);l.release();return ok();}
    async snapshot(profile){
      if(!id(profile))throw error('invalid_profile');const db=await this.db(),t=db.transaction('characters','readonly'),completion=done(t);
      const row=await request(t.objectStore('characters').get(profile));await completion;return ok({row:row||null});
    }
    async pair(head,text,profile){
      if(typeof head!=='string'||new TextEncoder().encode(head).length>65536||typeof text!=='string'||new TextEncoder().encode(text).length>MAX)throw error('transport_size_or_type');
      const outer=JSON.parse(head),h=JSON.parse(outer.body);
      if(outer.sha256!==await sha(outer.body)||h.format!=='itank_arena_disposable_v3_browser_head'||h.layout_version!==1||h.reader_version!==3||h.record_version!==3||h.profile!==profile||h.record_sha256!==await sha(text)||h.record_bytes!==new TextEncoder().encode(text).length)throw error('head_transport_binding');
      return h;
    }
    async barrierAt(name){
      if(this.fault!==name)return;
      this.barrier={at:name,release:null};await new Promise(resolve=>{this.barrier.release=resolve;});this.barrier=null;
    }
    async publish(a,repair=false){
      const l=this.lease(a.profile,a.owner);if(l.busy)throw error('writer_busy');l.busy++;
      try{
        await this.pair(a.head,a.text,a.profile); // Async crypto BEFORE transaction.
        await this.barrierAt('before_transaction');
        const db=await this.db(),started=performance.now(),t=db.transaction('characters','readwrite',{durability:'strict'}),completion=done(t);
        const store=t.objectStore('characters');let outcome='published',rejectReason='';
        const q=store.get(a.profile);
        q.onsuccess=()=>{
          const current=q.result||null;
          if(!repair&&current&&current.head===a.head&&current.current===a.text&&current.replica===a.text){outcome='exact_retry';return;}
          if((current?.head||null)!==(a.expected||null)||(repair&&!same(current,a.raw))){rejectReason='stale_expected_head';t.abort();return;}
          if(repair&&(!current||(current.current!==a.text&&current.replica!==a.text)||current.head!==a.head)){rejectReason='repair_requires_exact_selected_copy';t.abort();return;}
          store.put({profile:a.profile,head:a.head,current:a.text,replica:a.text});
          if(this.fault==='abort_after_put'){rejectReason='injected_transaction_abort';t.abort();}
          if(this.fault==='quota'){rejectReason='injected_quota_exceeded';t.abort();}
        };
        try{await completion;}catch(e){if(rejectReason)throw error(rejectReason,this.fault==='quota'?'QuotaExceededError':'AbortError');throw e;}
        const transaction_ms=performance.now()-started;
        await this.barrierAt('after_commit');
        if(this.fault==='lost_response')throw error('committed_response_lost');
        return ok({outcome,transaction_ms});
      }finally{l.busy--;}
    }
    async match(a){const current=await this.snapshot(a.profile);if(!same(current.row,a.raw))throw error('readback_changed');return ok();}
    async run(op,a={}){
      try{if(this.closed)throw error('store_closed');
        if(op==='acquire')return await this.acquire(a.profile,a.owner);
        if(op==='release')return this.release(a.profile,a.owner);
        if(op==='snapshot')return await this.snapshot(a.profile);
        if(op==='publish')return await this.publish(a);
        if(op==='repair')return await this.publish(a,true);
        if(op==='match')return await this.match(a);
        throw error('unknown_operation');
      }catch(e){return failed(e);}
    }
    async close(){if([...this.leases.values()].some(l=>l.busy||!l.release))throw error('store_busy');for(const [p,l]of this.leases)this.release(p,l.owner);if(this.opening)(await this.opening).close();this.closed=true;}
  }
  const entries=new Map();let serial=0;
  globalThis.ArenaV3Browser={
    create(name){try{const key='store_'+(++serial);entries.set(key,{store:new Store(name),job:null,value:null,active:null});return key;}catch{return ''; }},
    request(key,op,json){const e=entries.get(key);if(!e||e.job)return '';let a;try{a=JSON.parse(json);}catch{return '';}
      const job='job_'+(++serial);e.job=job;e.value={success:false,state:'pending'};e.active=e.store.run(op,a).then(value=>{e.value=value;e.active=null;});return job;},
    poll(key,job){const e=entries.get(key);if(!e||e.job!==job)return JSON.stringify(failed(error('stale_browser_job')));const v=e.value;if(v.state!=='pending'){e.job=null;e.value=null;}return JSON.stringify(v);},
    async dispose(key){const e=entries.get(key);if(!e)return;if(e.active)await e.active;await e.store.close();entries.delete(key);},
    // Diagnostic controls are available only on this always-disposable module.
    fault(key,value){const e=entries.get(key);if(!e)return false;e.store.fault=value;return true;},
    resume(key){const b=entries.get(key)?.store.barrier;if(b?.release)b.release();},
    status(key){const e=entries.get(key);return e?{jobs:e.job?1:0,active:!!e.active,leases:e.store.leases.size,barrier:e.store.barrier?.at||null}:null;},
    diagnostics(){return {stores:entries.size,jobs:[...entries.values()].filter(e=>e.job).length};},
    testStore(name){return new Store(name);}
  };
})();
