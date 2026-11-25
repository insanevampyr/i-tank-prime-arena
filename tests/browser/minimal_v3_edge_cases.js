'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),cp=require('node:child_process'),crypto=require('node:crypto');
module.exports=async({evaluate,call,tab,createTab,ready,url,fixtures,dir,metrics,check,edgePid})=>{
 const delay=ms=>new Promise(r=>setTimeout(r,ms)),prefix='itank-arena-disposable-v3-46j-';
 const fixture=name=>fs.readFileSync(path.join(fixtures,name+'.json'),'utf8');
 const rpc=(a,sid=tab.sid)=>evaluate(`arena46j.call(${JSON.stringify(a)})`,sid);
 const pump=async(c,sid=tab.sid,op='poll')=>{for(let i=0;i<12000;i++){const r=await rpc({op,context:c.context},sid);if(r.state!=='pending')return r;await delay(10);}throw Error('Bounded browser pump exhausted');};
 const reader=async(c,repair=false,sid=tab.sid)=>{const started=performance.now(),r=await rpc({op:'reader_begin',context:c.context,repair},sid),result=r.state==='pending'?await pump(c,sid,'reader_poll'):r;metrics.push({kind:'cold_read',fixture:c.fixture,repair,success:result.success,reason:result.reason,wall_ms:performance.now()-started,cold_validate_us:result.cold_validate_us});return result;};
 const create=async(name,kind='normal',cold=false,sid=tab.sid)=>{
  const c=await rpc({op:'create',text:fixture(kind),database:prefix+name},sid);c.fixture=name;check(c.success,'WASM admitted source fixture '+name+' '+JSON.stringify(c));
  const r=await reader(c,true,sid);check(r.success,'Actual cold IDB reader '+name+' '+JSON.stringify({reason:r.reason}));
  const attached=await rpc({op:cold?'reload_admit':'attach',context:c.context},sid);check(attached.success,'Actual coordinator bound to readback '+name+' '+JSON.stringify(attached));
  if(!cold){const begin=await rpc({op:'begin',context:c.context},sid),ack=begin.state==='pending'?await pump(c,sid):begin;check(ack.success&&ack.durable,'First committed head and pair '+name+' '+JSON.stringify(ack));metrics.push({fixture:name+'_first',...ack.metrics});}
  const auto=await rpc({op:'automatic',context:c.context,enabled:true},sid);check(auto.success,'Automatic async source capture opt-in');return c;
 };
 const command=async(c,kind,extra={},sid=tab.sid)=>{
  const started=performance.now(),r=await rpc({op:'command',context:c.context,kind,...extra},sid);
  if(r.phase){const ack=await pump(c,sid);check(ack.success&&ack.durable,'Source '+kind+' actual committed readback '+JSON.stringify(ack));metrics.push({fixture:c.fixture+':'+kind,source_command:kind,wall_ms:performance.now()-started,...ack.metrics});return ack;}
  check(r.success,'Source '+kind+' '+JSON.stringify(r));return r;
 };
 const summary=(c,sid=tab.sid)=>rpc({op:'summary',context:c.context},sid);
 const inspect=async name=>evaluate(`(async()=>{const s=ArenaV3Browser.testStore(${JSON.stringify(prefix+name)});const r=await s.snapshot(${JSON.stringify(name.startsWith('normal')?'prod_vaelis_thorn':'dev_vaelis_thorn')});await s.close();return r.row;})()`);
 const inject=async(name,profile,script)=>evaluate(`(async()=>{const s=ArenaV3Browser.testStore(${JSON.stringify(prefix+name)}),db=await s.db(),t=db.transaction('characters','readwrite'),o=t.objectStore('characters'),q=o.get(${JSON.stringify(profile)});q.onsuccess=()=>{const r=q.result;${script};o.put(r);};await new Promise((r,j)=>{t.oncomplete=r;t.onabort=()=>j(t.error);});await s.close();return true;})()`);
 const memory=async label=>{
  const heap=await call('Runtime.getHeapUsage',{},tab.sid),wasm=await evaluate('window.arena46jMemory?.buffer.byteLength||null');
  let renderer=null;try{const rows=await call('SystemInfo.getProcessInfo'),ids=rows.processInfo.filter(x=>x.type==='renderer').map(x=>x.id);if(ids.length)renderer=JSON.parse(cp.execFileSync('powershell',['-NoProfile','-Command',`Get-Process -Id ${ids.join(',')} -ErrorAction SilentlyContinue|Select-Object Id,WorkingSet64,PeakWorkingSet64|ConvertTo-Json -Compress`],{encoding:'utf8',windowsHide:true,timeout:10000}));}catch{}
  metrics.push({kind:'memory',label,heap,wasm,renderer});
 };
 await memory('fresh_release');
 check(await evaluate(`(()=>{try{ArenaV3Browser.testStore('itank-prime-arena.character-profiles');return false;}catch{return true;}})()`),'Production database name rejected without opening it');
 for(const kind of ['normal','dev_normal']){
  const name=kind==='normal'?'normal-main':'dev-main',c=await create(name,kind);
  await command(c,'defeat');await command(c,'loot');
  const actual=await summary(c),expected=JSON.parse(fixture(kind+'_oracle'));
  if(JSON.stringify(actual.body)!==JSON.stringify(expected.body))fs.writeFileSync(path.join(dir,'oracle-difference.json'),JSON.stringify({actual:actual.body,expected:expected.body,actual_sim:actual.simulation,expected_sim:expected.simulation},null,2));
  check(JSON.stringify(actual.body)===JSON.stringify(expected.body),'Complete native original-source current/evidence equivalence '+kind);
  assert.deepStrictEqual(actual.simulation,expected.simulation);check(true,'Complete original simulation/events/RNG native-WASM equivalence '+kind);
  await command(c,'acquire');await command(c,'item',{kind_item:'unequip',definition:'prime_v3_short_wand',id:'46j_off'});
  await command(c,'item',{kind_item:'equip',definition:'prime_v3_short_wand',id:'46j_on'});
  await command(c,'item',{kind_item:'handling',definition:'prime_v3_short_wand',handling:'stow',id:'46j_stow'});
  await command(c,'item',{kind_item:'use',definition:'health_potion',id:'46j_use',fixture_damage:true});
  let a=await summary(c);check(a.body.current.items.some(i=>i.definition_id==='health_potion'&&i.quantity===0),'Terminal zero quantity with original consumption');
  const replay=await rpc({op:'command',context:c.context,kind:'item',kind_item:'use',definition:'health_potion',id:'46j_use'});
  check(!replay.success&&replay.reason==='reused_irreversible_consumption','Irreversible identity cannot consume twice');
  if(kind==='normal'){
   for(let i=0;i<21;i++)await command(c,'nac',{details:{profile:i%2?'Balanced':'Defensive'}});
   check((await summary(c)).body.recent_journal.length===20,'Consumption remains protected after its temporary summary is evicted');
  }
  await command(c,'next');a=await summary(c);check(a.body.current.recovery.wave_id==='wave_2'&&a.encounter_state==='running','Original NEXT WAVE resumes only verified entry '+JSON.stringify({recovery:a.body.current.recovery,encounter:a.encounter_state}));
  check((await rpc({op:'close',context:c.context})).success,'Release source runtime and browser jobs '+name);
  const reopened=await create(name,kind,true),restored=await summary(reopened);
  assert.deepStrictEqual(restored.body,a.body);check(true,'Full current character and entry checkpoint survive cold '+kind+' admission');
  const repeat=await rpc({op:'command',context:reopened.context,kind:'item',kind_item:'use',definition:'health_potion',id:'46j_use'});
  check(!repeat.success&&repeat.reason==='reused_irreversible_consumption','Exact consumed identity survives cold '+kind+' admission');
  assert.deepStrictEqual((await summary(reopened)).simulation,restored.simulation);check(true,'Cold duplicate cannot mutate resources/events/RNG');
  check((await rpc({op:'close',context:reopened.context})).success,'Cold '+kind+' context disposed');
 }
 await memory('small_profiles_closed');
 const c=await create('history','historical');
 const before=await summary(c);
 await rpc({op:'fault',context:c.context,value:'abort_after_put'});
 const credit=await rpc({op:'command',context:c.context,kind:'credit'});check(credit.phase,'Original credit queued, no optimistic acknowledgement');
 let failed=await pump(c);check(!failed.success&&failed.reason==='injected_transaction_abort','Actual IDB transaction aborted after staged puts');
 let pending=await summary(c),row=await inspect('history');
 check(JSON.parse(JSON.parse(row.current).body_json).current.xp.earned===before.body.current.xp.earned,'Abort preserves old committed EXPM');
 const second=await rpc({op:'command',context:c.context,kind:'credit'});check(!second.success,'Pending fixed credit cannot be issued twice');
 check((await summary(c)).live_xp.expc===pending.live_xp.expc,'Failed/repeated confirmation adds no second credit');
 await rpc({op:'fault',context:c.context,value:''});await rpc({op:'begin',context:c.context});let ack=await pump(c);check(ack.success&&ack.durable,'Exact same pending credit retries through real readback');
 let credited=await summary(c);check(credited.body.current.xp.unspent===before.body.current.xp.unspent+10000&&credited.body.current.xp.earned===before.body.current.xp.earned,'Native fixed grant +10000 EXPC / zero EXPM');
 for(const [attribute,current,cost,allocation]of [['end',6,3000],['wis',10,3000],['dex',9,3000,'dt']])await command(c,'purchase',{attribute,id:'j_'+attribute,details:{expected_current_value:current,expected_cost:cost,...(allocation?{allocation}:{})}});
 for(let i=0;i<2;i++){await command(c,'next');await command(c,'defeat');await command(c,'loot');if(!i)await command(c,'purchase',{attribute:'end',id:'j_end7',details:{expected_current_value:7,expected_cost:3000}});}
 for(const [attribute,current,cost]of [['str',9,3000],['spd',11,5000]])await command(c,'purchase',{attribute,id:'j_'+attribute,details:{expected_current_value:current,expected_cost:cost}});
 let a=await summary(c);check(['str','dex','spd','wis','end'].every(x=>a.body.evidence.purchases.some(p=>p.target_id===x)),'All five genuine source purchases captured');
 check(a.body.evidence.growth.some(r=>r.hpb===2&&r.wisdom===11),'Original chronological END/HPB/WIS growth');
 const old=a.body;await command(c,'new_run',{multiplier:1});a=await summary(c);check(a.body.epoch===old.epoch&&a.body.current.profile_namespace==='dev_normal'&&a.body.current.run_history.length===old.current.run_history.length+1&&a.body.current.run_reward_policy.runs.at(-1).xp_multiplier===1,'Genuine NEW RUN retains character and locks new x1 policy');
 assert.deepStrictEqual(a.body.evidence,old.evidence);check(true,'NEW RUN leaves all committed permanent evidence intact');
 await command(c,'defeat');await command(c,'loot'); // Original authorized downtime, not an unauthorized entry write.
 // Actual abort/quota path and safe cancellation before any publish dispatch.
 await rpc({op:'automatic',context:c.context,enabled:false});
 const preparedQuota=await rpc({op:'command',context:c.context,kind:'nac',details:{profile:'Aggressive'}});check(preparedQuota.success&&preparedQuota.pending,'Quota test has a genuine pending legal source checkpoint '+JSON.stringify(preparedQuota));
 const oldHead=(await inspect('history')).head;
 await rpc({op:'fault',context:c.context,value:'quota'});await rpc({op:'begin',context:c.context});failed=await pump(c);
 check(!failed.success&&failed.reason==='injected_quota_exceeded','Quota failure simulation aborts actual transaction and reports QuotaExceededError '+JSON.stringify(failed));
 check(failed.details.error_name==='QuotaExceededError','Injected quota retains exact transport error classification');
 check((await inspect('history')).head===oldHead,'Quota failure cannot acknowledge/replace previous head');
 await rpc({op:'fault',context:c.context,value:''});await rpc({op:'begin',context:c.context});ack=await pump(c);check(ack.success,'Exact quota retry retains original operation');
 const preparedCancel=await rpc({op:'command',context:c.context,kind:'nac',details:{profile:'Defensive'}});check(preparedCancel.success&&preparedCancel.pending,'Cancellation test has a genuine pending checkpoint');
 await rpc({op:'begin',context:c.context});check((await rpc({op:'cancel',context:c.context})).success,'Cancel before publication request accepted');
 const canceled=await pump(c);check(canceled.state==='canceled'&&(await summary(c)).pending,'Cancellation retains pending identity, no fake retirement');
 await rpc({op:'begin',context:c.context});check((await pump(c)).success,'Canceled-before-send exact pending can be safely retried');
 const lossPrepared=await rpc({op:'command',context:c.context,kind:'nac',details:{profile:'Balanced'}});
 check(lossPrepared.success&&lossPrepared.pending,'Lost response test has original immutable pending bytes');
 const lossBefore=await summary(c),lossHead=(await inspect('history')).head;
 await rpc({op:'fault',context:c.context,value:'lost_response'});await rpc({op:'begin',context:c.context});failed=await pump(c);
 check(!failed.success&&failed.reason==='committed_response_lost','Real transaction completes but its response is deliberately lost');
 row=await inspect('history');check(row.head!==lossHead&&row.current===lossBefore.pending&&row.replica===lossBefore.pending,'Lost response retains exact committed head and both bytes');
 check((await summary(c)).pending===lossBefore.pending,'Uncertain acknowledgement retains original immutable candidate');
 await rpc({op:'fault',context:c.context,value:''});await rpc({op:'begin',context:c.context});ack=await pump(c);
 check(ack.success&&ack.durable&&(await inspect('history')).head===row.head,'Exact retry reconciles installed commit without a new generation');
 assert.deepStrictEqual((await summary(c)).simulation,lossBefore.simulation);check(true,'Lost-response retry replays no gameplay, rewards or RNG');
 // Corrupt only disposable DB rows. Restore original test data after each case.
 const profile='dev_vaelis_thorn';
 for(const field of ['current','replica']){
  await inject('history',profile,`r.${field}='damaged';`);const repaired=await reader(c,true);check(repaired.success&&!repaired.repair_current&&!repaired.repair_replica,'Real IDB repair '+field);
  row=await inspect('history');check(row.current===row.replica,'Repaired replica exact byte equality');
 }
 row=await inspect('history');const frozen=row;
 for(const corrupt of [`r.current='bad';r.replica='bad'`,`r.head=null`,`{const o=JSON.parse(r.head),h=JSON.parse(o.body);h.reader_version=99;o.body=JSON.stringify(h);r.head=JSON.stringify(o);}`]){
  await inject('history',profile,corrupt);const r=await reader(c,true);check(!r.success,'Corrupt/missing authority fails closed');
  await inject('history',profile,`Object.assign(r,${JSON.stringify(frozen)});`);
 }
 for(const patch of [{sequence:JSON.parse(JSON.parse(frozen.head).body).sequence+1},{reader_version:99}]){
  const envelope=JSON.parse(frozen.head),head=JSON.parse(envelope.body);Object.assign(head,patch);envelope.body=JSON.stringify(head);envelope.sha256=crypto.createHash('sha256').update(envelope.body).digest('hex');
  await inject('history',profile,`r.head=${JSON.stringify(JSON.stringify(envelope))};`);
  check(!(await reader(c,true)).success,'Checksum-valid conflicting/unsupported head rejected by source-bound reader');
  await inject('history',profile,`Object.assign(r,${JSON.stringify(frozen)});`);
 }
 await memory('before_repeated_operations');
 await rpc({op:'automatic',context:c.context,enabled:true});
 for(let i=0;i<24;i++)await command(c,'nac',{details:{profile:i%2?'Balanced':'Aggressive'}});
 const repeated=await summary(c);
 check(repeated.body.recent_journal.length===20,'Recent journal remains bounded across 24 further genuine checkpoints');
 check(repeated.body.evidence.credit.records.length===1,'Repeated operations preserve exactly one fixed-credit proof');
 assert.deepStrictEqual(repeated.body.evidence.credit,credited.body.evidence.credit);check(true,'Fixed-credit immutable binding survives every subsequent checkpoint');
 await memory('after_repeated_operations');await call('HeapProfiler.collectGarbage',{},tab.sid);await memory('after_repeated_operations_gc');
 const repeatedStored=await inspect('history');
 check(repeatedStored.current===repeatedStored.replica,'Latest replica remains byte-identical after repeated saves');
 const layout=await evaluate(`(async()=>{const s=ArenaV3Browser.testStore(${JSON.stringify(prefix+'history')}),db=await s.db(),t=db.transaction('characters','readonly'),q=t.objectStore('characters').count();const count=await new Promise((r,j)=>{q.onsuccess=()=>r(q.result);q.onerror=()=>j(q.error);});const names=Array.from(db.objectStoreNames);await s.close();return {count,names};})()`);
 check(layout.count===1&&JSON.stringify(layout.names)==='["characters"]'&&JSON.stringify(Object.keys(repeatedStored).sort())==='["current","head","profile","replica"]','No accumulated full generations, archive store or receipt chain');
 metrics.push({kind:'retention',layout,record_bytes:new TextEncoder().encode(repeatedStored.current).length,journal:repeated.body.recent_journal.length});
 check((await rpc({op:'close',context:c.context})).success,'History context released');
 await call('Page.reload',{ignoreCache:true},tab.sid);await ready(tab);
 const cold=await create('history','historical',true);a=await summary(cold);
 assert.deepStrictEqual(a.body,repeated.body);check(true,'Actual Edge reload preserves exact complete character/evidence/checkpoint bytes');
 check(a.body.current.run_reward_policy.runs.at(-1).xp_multiplier===1,'Actual Edge reload preserves recovered run policy');
 const creditAgain=await rpc({op:'command',context:cold.context,kind:'credit'});check(creditAgain.success&&!creditAgain.phase,'Credited cold profile is once-only no-op');
 const useAgain=await rpc({op:'command',context:cold.context,kind:'item',kind_item:'use',definition:'health_potion',id:'46j_use'});check(!useAgain.success,'No fabricated item ownership on different historical profile');
 // Fault barriers and real tab teardown are implemented below in a bounded test block.
 await require('./minimal_v3_lifecycle_cases')({rpc,pump,reader,create,summary,command,inspect,inject,evaluate,call,tab,createTab,ready,url,cold,metrics,check,delay});
 await memory('before_stress');
 const stress=await create('stress','stress1005');
 await command(stress,'nac',{details:{profile:'Aggressive'}});a=await summary(stress);check(a.body.current.items.length===1005,'Separate 1005-item source fixture remains complete');
 await memory('stress_completed');
 check((await rpc({op:'close',context:stress.context})).success,'Stress context disposed');
 await delay(100);await call('HeapProfiler.collectGarbage',{},tab.sid);await memory('after_contexts_closed_gc');
 const diagnostics=await evaluate('ArenaV3Browser.diagnostics()');check(diagnostics.stores===0&&diagnostics.jobs===0,'No retained browser store/job payloads after disposal');metrics.push({kind:'released',diagnostics});
 const lag=await evaluate('({...jLag})');metrics.push({kind:'responsiveness',...lag});await evaluate('clearInterval(jTimer)');
 check(!(await evaluate(`indexedDB.databases().then(a=>a.some(d=>d.name==='itank-prime-arena.character-profiles'))`)),'Isolated origin never opened production database');
};
