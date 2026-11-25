/* Pass D: isolated portable proof + exact recovery, sharing Pass C's IDB CAS.
 * All progression/ancestry checks execute in release Godot WASM, not JS flags. */
(() => {
  'use strict';
  const fail=reason=>({success:false,reason,state:'recovery_required'});
  const hash=async text=>Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(text))),b=>b.toString(16).padStart(2,'0')).join('');
  const token=head=>head?{sequence:head.sequence,digest:head.digest}:null;
  class Store extends DisposableV6Store {
    constructor(name,verify,proof,profile='dev_vaelis_thorn',namespace='dev_normal') {
      super(name,verify,profile,namespace);
      if(typeof proof!=='function')throw Error('native_portable_verifier_required');
      this.proof=proof;
    }
    async capsule(snap) {
      if(!snap.head)return fail('head_missing');
      const file=snap.records.get('portable:'+snap.head.digest);
      if(typeof file!=='string')return fail('exact_recovery_evidence_unavailable');
      const p=await this.proof({kind:'portable_decode',portable:file});
      if(!p.success)return p;
      if(await hash(p.text)!==snap.head.digest||p.record.head.sequence!==snap.head.sequence||p.record.head.epoch!==snap.head.epoch||p.preview.profile!==this.profile||p.preview.namespace!==this.namespace)return fail('capsule_head_mismatch');
      return {...p,portable:file};
    }
    async load() {
      const start=performance.now(),loaded=await super.load();if(!loaded.success)return loaded;
      const snap=await this.snapshot();
      if(JSON.stringify(snap.head)!==JSON.stringify(loaded.head))return fail('head_changed_during_validation');
      const p=await this.capsule(snap);return p.success?{...loaded,history:p.history,load_ms:performance.now()-start}:p;
    }
    async publish(text,expected,fault='') {
      const start=performance.now(),snap=await this.snapshot();let before=null,history=[];
      if(snap.head){before=await this.load();if(!before.success)return before;}
      else if(snap.records.size)return fail('unknown_or_existing_head');
      const checked=await this.checked(text,before?.text||null);if(!checked.success)return checked;
      if(before&&checked.digest===before.head.digest)return {...before,already_applied:true};
      if(JSON.stringify(expected)!==JSON.stringify(token(before?.head)))return fail('stale_expected_head');
      if(!before&&checked.sequence!==1)return fail('initial_baseline_required');
      if(before){const d=await this.proof({kind:'portable_delta',text,parent:before.text});if(!d.success)return d;history=[...before.history,d.transition];}
      const p=await this.proof({kind:'portable_encode',text,history});if(!p.success)return p;
      return this.commitVerified(text,checked,snap,before,fault,start,{['portable:'+checked.digest]:p.text});
    }
    async export(beforeRecheck=null) {
      const start=performance.now(),loaded=await this.load();if(!loaded.success)return loaded;
      const snap=await this.snapshot();if(JSON.stringify(snap.head)!==JSON.stringify(loaded.head))return fail('export_head_changed');
      const p=await this.capsule(snap);if(!p.success)return p;
      if(beforeRecheck)await beforeRecheck();
      if(JSON.stringify((await this.snapshot()).head)!==JSON.stringify(loaded.head))return fail('export_head_changed');
      return {success:true,file:p.portable,preview:p.preview,export_ms:performance.now()-start,bytes:new TextEncoder().encode(p.portable).length};
    }
    async prepare(file,expected) {
      // Pure native preview. Does not even open a destination database.
      return this.proof({kind:'portable_prepare',portable:file,expected,profile:this.profile,namespace:this.namespace});
    }
    async restore(file,expected,confirmation,fault='') {
      const start=performance.now(),p=await this.prepare(file,expected);if(!p.success)return p;
      if(confirmation!==p.confirmation)return fail('explicit_restore_confirmation_required');
      const snap=await this.snapshot();let before=null;
      if(snap.head){before=await this.load();if(!before.success){if(await hash(p.text)!==snap.head.digest||p.record.head.epoch!==snap.head.epoch||p.record.head.sequence!==snap.head.sequence)return fail('exact_acknowledged_record_required');before=null;}}
      else if(snap.records.size)return fail('unknown_or_existing_head');
      const relation=await this.proof({kind:'portable_relationship',portable:file,current:before?.text||null});if(!relation.success)return relation;
      if(before&&await hash(p.text)===before.head.digest)return {...before,already_applied:true};
      if(JSON.stringify(expected)!==JSON.stringify(token(snap.head)))return fail('stale_expected_head');
      const checked=await this.checked(p.text);if(!checked.success)return checked;
      const extra={['portable:'+checked.digest]:file};let previous=null;
      if(p.previous_text){previous=await hash(p.previous_text);extra[previous]=p.previous_text;}
      return this.commitVerified(p.text,checked,snap,before,fault,start,extra,previous);
    }
    async recover() {
      const start=performance.now(),current=await this.load();if(current.success)return {...current,recovery_ms:performance.now()-start};
      if(current.reason!=='latest_record_damaged')return current;
      const p=await this.capsule(await this.snapshot());if(!p.success)return p;
      const result=await this.repairExact(p.text);
      return {...result,recovered_exact_head:result.success,recovery_ms:performance.now()-start};
    }
  }
  globalThis.DisposableV6BackupStore=Store;
})();
