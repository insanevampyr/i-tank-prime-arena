 'use strict';
module.exports=async context=>{
 const {evaluate,checks,metrics}=context;
 await require('./compact_v6_browser_edge_cases')({...context,phase:'setup-only'});
 for(const kind of ['small','233','inventory']){
  const setup=await evaluate(`(async()=>{const c=await s5Create('45u-${kind}','${kind==='small'?'normal':'dev_normal'}');window.current=c;await s5Load(c);if('${kind}'==='233'){const file=await(await fetch('/fixtures/baseline_233.v6backup')).text();const restored=await s5Restore(c,file);if(!restored.success)return restored;}const started=await s5Call({kind:'browser_start',context:c,multiplier:${kind==='small'?1:'null'}});if(!started.success)return started;if(started.pending)await s5Flush(c);if('${kind}'!=='233'){await s5Command(c,'defeat');await s5Command(c,'loot');}if('${kind}'==='inventory')await s5Command(c,'inventory',{count:1000});return s5Call({kind:'browser_summary',context:c});})()`);
  checks(setup.success,'Matched real gameplay fixture '+kind);metrics.push({kind:'45u_input',fixture:kind,...setup});
  for(let i=0;i<(kind==='small'?3:1);i++){
   const before=await evaluate(`s5Call({kind:'browser_summary',context:current})`);
   const prepared=await evaluate(`s5Call({kind:'browser_command',context:current,command:'development',id:'45u_${kind}_${i}'})`);checks(prepared.pending,'Real authorized pending batch '+kind);
   const probe=await evaluate(`s5Call({kind:'browser_routine_probe',context:current,samples:3})`);checks(probe.success,'Full oracle equivalence '+kind);metrics.push({kind:'45u_check',fixture:kind,sample:i,...probe});
   const save=await evaluate(`(async()=>{const t=performance.now(),ack=await s5Flush(current);return {ack,total_ms:performance.now()-t};})()`);
   checks(save.ack.success,'Original coordinator and persisted readback '+kind);metrics.push({kind:'45u_save',fixture:kind,sample:i,...save});
  }
  const cold=await evaluate(`(async()=>{const t=performance.now(),r=await s5Load(current);return {success:r.success,load_ms:performance.now()-t,summary:r.result};})()`);checks(cold.success,'Independent cold validation '+kind);metrics.push({kind:'45u_cold',fixture:kind,...cold});
 }
 metrics.push({kind:'45u_bridge',...await evaluate('({...s5BridgeStats,...s5Lag,wasm_bytes:s5Memory?.buffer.byteLength||null})')});
};
