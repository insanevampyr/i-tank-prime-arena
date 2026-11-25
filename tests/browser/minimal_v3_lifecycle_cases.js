'use strict';
module.exports=async({rpc,pump,create,summary,inspect,evaluate,call,tab,createTab,ready,url,cold,metrics,check,delay})=>{
 let a=cold;
 const barrier=async(c,at,sid=tab.sid)=>{for(let i=0;i<3000;i++){await rpc({op:'poll',context:c.context},sid);const s=await evaluate(`ArenaV3Browser.status(${JSON.stringify(c.handle)})`,sid);if(s?.barrier===at)return;await delay(10);}throw Error('Controlled browser barrier not reached '+at);};
 const other=await createTab();await call('Page.navigate',{url},other.sid);await ready(other);
 const b=await create('history','historical',true,other.sid);
 const currentProfile=(await summary(a)).body.current.recovery.player.nac_automation_settings.profile;
 const unchangedHead=(await inspect('history')).head;
 const noop=await rpc({op:'command',context:a.context,kind:'nac',details:{profile:currentProfile}});
 check(noop.success&&!noop.pending&&!noop.phase&&noop.original.checkpoint.state==='simulated_checkpoint_unchanged'&&(await inspect('history')).head===unchangedHead,'Unchanged character checkpoint creates no publication or extra saved generation');
 await rpc({op:'fault',context:a.context,value:'before_transaction'});
 const queued=await rpc({op:'command',context:a.context,kind:'nac',details:{profile:currentProfile==='Balanced'?'Aggressive':'Balanced'}});
 check(queued.success&&queued.phase,'Competing-writer test has a genuine source checkpoint '+JSON.stringify(queued));
 await barrier(a,'before_transaction');
 // Creating the competing tab may background this page. Edge clamps hidden
 // page timers, so require bounded progress rather than a foreground 100ms rate.
 const visibility=await evaluate('document.visibilityState'),ticks=await evaluate('jLag.samples'),heartbeatStarted=Date.now();
 let heartbeat=false;
 for(let i=0;i<30;i++){await delay(100);if(await evaluate('jLag.samples')>ticks){heartbeat=true;break;}}
 check(heartbeat,'Browser heartbeat continues within 3 seconds while publication awaits its barrier');
 metrics.push({kind:'barrier_heartbeat',visibility,elapsed_ms:Date.now()-heartbeatStarted});
 const old=(await inspect('history')).head;
 await rpc({op:'command',context:b.context,kind:'nac',details:{profile:'Guardian'}},other.sid);
 const locked=await pump(b,other.sid);check(!locked.success&&locked.reason==='profile_in_use','Actual competing tab rejected by native Web Lock');
 const pending=await summary(a);await rpc({op:'command',context:a.context,kind:'running'});const advanced=await summary(a);
 check(JSON.stringify(pending.movement)!==JSON.stringify(advanced.movement),'Actual external Running advances after capture while storage waits');
 await rpc({op:'resume_barrier',context:a.context});const saved=await pump(a);check(saved.success&&saved.durable,'Independent readback acknowledges original captured operation');
 check(JSON.stringify((await summary(a)).movement)===JSON.stringify(advanced.movement),'Earlier committed checkpoint never reinstalls older live Running');
 await rpc({op:'begin',context:b.context},other.sid);const stale=await pump(b,other.sid);
 check(!stale.success&&stale.reason==='stale_expected_head'&&(await inspect('history')).head!==old,'Competing stale expected head cannot overwrite acknowledged progression');
 await call('Target.closeTarget',{targetId:other.target});
 for(const at of ['before_transaction','after_commit']){
  await rpc({op:'fault',context:a.context,value:at});
  const before=(await inspect('history')).head;
  await rpc({op:'command',context:a.context,kind:'nac',details:{profile:at==='before_transaction'?'Aggressive':'Defensive'}});
  await barrier(a,at);
  const candidate=(await summary(a)).pending;
  const row=await inspect('history');
  check(at==='before_transaction'?row.head===before:row.head!==before&&row.current===candidate&&row.replica===candidate,'Actual selected IDB state at controlled '+at);
  metrics.push({kind:'controlled_page_termination',at,pending_bytes:new TextEncoder().encode(candidate).length,lag:await evaluate('({...jLag})')});
  // Real document teardown. No simulated callback or IndexedDB shim.
  await call('Page.reload',{ignoreCache:true},tab.sid);await ready(tab);
  a=await create('history','historical',true);
  const recovered=(await inspect('history'));
  check(at==='before_transaction'?recovered.head===before:recovered.current===candidate&&recovered.replica===candidate,'Fresh release-WASM cold admission after real document teardown '+at);
 }
 const final=await summary(a);check(final.body.current.run_reward_policy.runs.at(-1).xp_multiplier===1,'Reload and interruption preserve locked admitted policy');
 const credit=await rpc({op:'command',context:a.context,kind:'credit'});check(credit.success&&!credit.phase,'No duplicate fixed credit after interrupted publication/reload');
 check((await rpc({op:'close',context:a.context})).success,'Reconciled lifecycle source and browser buffers released');
};
