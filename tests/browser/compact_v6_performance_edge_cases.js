'use strict';
module.exports=async({evaluate,call,sid,fixture,checks,phase})=>{
 const fs=require('node:fs'),path=require('node:path');
 const result={phase,cases:{}};
 await evaluate(`window.perfBridge={calls:0,sent:0,received:0,max_sync_ms:0,total_ms:0};{const original=v6Harness.call.bind(v6Harness);v6Harness.call=async value=>{const bytes=new TextEncoder().encode(JSON.stringify(value)).length,t=performance.now();const pending=original(value),sync=performance.now()-t;const response=await pending;perfBridge.calls++;perfBridge.sent+=bytes;perfBridge.received+=new TextEncoder().encode(JSON.stringify(response)).length;perfBridge.max_sync_ms=Math.max(perfBridge.max_sync_ms,sync);perfBridge.total_ms+=performance.now()-t;return response;};}window.perfResults={};void 0`);
 for(const name of ['ops1000','ops10000','awards','inventory','chain100','chain501']){
  console.log('45P_EDGE_START',phase,name);
  const r=await evaluate(`(async()=>{const text=await(await fetch('/fixtures/${name}.json')).text(),args={kind:'${name.startsWith('chain')?'perf_history':'perf_sample'}',text,samples:${name.startsWith('chain')?3:5}};if('${name}'.startsWith('chain'))args.history=await(await fetch('/fixtures/${name}.history')).json();const r=await v6Harness.call(args);perfResults['${name}']=r;return r;})()`);
  checks(r.success,'Instrumented release WASM case '+name+' '+JSON.stringify(r.reason||''));
  result.cases[name]=r;console.log('45P_EDGE_DONE',phase,name,JSON.stringify(r.samples));
  fs.writeFileSync(path.join(fixture,'edge-performance-'+phase+'.json'),JSON.stringify(result,null,2));
 }
 console.log('45P_EDGE_START',phase,'workflow');
 result.workflow=await evaluate(`(async()=>{const times={},traces=[],add=(k,t)=>{(times[k]??=[]).push(performance.now()-t);};const base=await(await fetch('/fixtures/ops1000.json')).text(),proof=args=>v6Harness.call(args);for(let i=0;i<3;i++){const s=new DisposableV6BackupStore('itank-arena-disposable-v6-45m-perf-${phase}-'+i,verify,proof);const a=await s.publish(base,null);if(!a.success)return a;await proof({kind:'perf_reset'});let t=performance.now();const c=await proof({kind:'perf_next',text:a.text,id:'workflow_next'});add('construct_encode_bridge',t);if(!c.success)return c;t=performance.now();const saved=await s.publish(c.text,token(a.head));add('save',t);if(!saved.success)return saved;t=performance.now();const loaded=await s.load();add('load',t);if(!loaded.success)return loaded;t=performance.now();const exp=await s.export();add('export',t);if(!exp.success)return exp;const dest=new DisposableV6BackupStore('itank-arena-disposable-v6-45m-perf-restore-${phase}-'+i,verify,proof);t=performance.now();const p=await dest.prepare(exp.file,null);add('preview',t);if(!p.success)return p;t=performance.now();const r=await dest.restore(exp.file,null,p.confirmation);add('restore',t);if(!r.success)return r;await dest.fault('latest_missing');t=performance.now();const rec=await dest.recover();add('recovery',t);if(!rec.success||rec.text!==c.text)return {success:false,reason:'changed_workflow'};traces.push((await proof({kind:'perf_snapshot'})).trace);await s.close();await dest.close();}const stats=values=>{const x=[...values].sort((a,b)=>a-b);return {n:x.length,p50_ms:x[Math.ceil(x.length*.5)-1],p95_ms:x[Math.ceil(x.length*.95)-1],max_ms:x.at(-1),samples_ms:values};};return {success:true,samples:Object.fromEntries(Object.entries(times).map(([k,v])=>[k,stats(v)])),traces};})()`);
 checks(result.workflow.success,'Release instrumented portable save/export/preview/restore/recovery workflow');
 console.log('45P_EDGE_DONE',phase,'workflow',JSON.stringify(result.workflow.samples));
 result.bridge=await evaluate('perfBridge');
 result.heap=await call('Runtime.getHeapUsage',{},sid);
 result.wasm=await evaluate('window.__45mMemory?.buffer.byteLength||null');
 await call('HeapProfiler.collectGarbage',{},sid);result.heapAfterGC=await call('Runtime.getHeapUsage',{},sid);
 if(phase==='after'){
  result.equivalence={};
  for(const name of ['ops1000','ops10000','awards','inventory','chain100','chain501']){
   const r=await evaluate(`(async()=>{const text=await(await fetch('/fixtures/${name}.json')).text();return v6Harness.call({kind:'perf_equivalence',text});})()`);
   checks(r.success,'Full frozen oracle equivalence in release WASM '+name+' '+JSON.stringify(r.failures||r.reason));result.equivalence[name]=r;
  }
 }
 fs.writeFileSync(path.join(fixture,'edge-performance-'+phase+'.json'),JSON.stringify(result,null,2));
 return result;
};
