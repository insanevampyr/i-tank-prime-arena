'use strict';
// A fresh Edge process/profile, random localhost origin and temporary Godot
// project. Never connects to an existing debugging port or production export.
const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),http=require('node:http'),cp=require('node:child_process'),assert=require('node:assert/strict');
const repo=path.resolve(__dirname,'../..'),fixture=path.resolve(process.argv[2]||'');
const expected=path.join(os.homedir(),'AppData/Local/itank-storage-tests/compact45m_').toLowerCase();
assert(fixture.toLowerCase().startsWith(expected),'Disposable fixture root required');
const manifest=JSON.parse(fs.readFileSync(path.join(fixture,'manifest.json'),'utf8'));
const dir=fs.mkdtempSync(path.join(os.tmpdir(),'arena45m-wasm-')),project=path.join(dir,'project'),web=path.join(project,'web');
fs.mkdirSync(web,{recursive:true});
for(const folder of ['scripts','data'])fs.cpSync(path.join(repo,folder),path.join(project,folder),{recursive:true});
for(const file of ['compact_v6_wasm_harness.gd','compact_v6_store.js','compact_v6_backup_store.js']){const dest=path.join(project,'tests/browser',file);fs.mkdirSync(path.dirname(dest),{recursive:true});fs.copyFileSync(path.join(repo,'tests/browser',file),dest);}
fs.mkdirSync(path.join(project,'tests'),{recursive:true});fs.copyFileSync(path.join(repo,'tests/compact_v6_portable_backup.gd'),path.join(project,'tests/compact_v6_portable_backup.gd'));
const asset='assets/Character Choices/Vaelis_Thorn_Elven_Fighter_Force_Mage_Arena_Character_Data.json';
fs.mkdirSync(path.dirname(path.join(project,asset)),{recursive:true});fs.copyFileSync(path.join(repo,asset),path.join(project,asset));
fs.writeFileSync(path.join(project,'project.godot'),'config_version=5\n[application]\nconfig/name="Disposable 45M storage harness"\nrun/main_scene="res://harness.tscn"\n[display]\nwindow/size/viewport_width=320\nwindow/size/viewport_height=180\n[rendering]\nrenderer/rendering_method="gl_compatibility"\nrenderer/rendering_method.mobile="gl_compatibility"\n');
fs.writeFileSync(path.join(project,'harness.tscn'),'[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://tests/browser/compact_v6_wasm_harness.gd" id="1"]\n[node name="DisposableHarness" type="Node"]\nscript = ExtResource("1")\n');
const preset=fs.readFileSync(path.join(repo,'export_presets.cfg'),'utf8')
 .replace('name="Web"','name="Disposable Web"')
 .replace(/^include_filter=.*$/m,'include_filter="tests/browser/*.js,assets/Character Choices/*.json"')
 .replace(/^exclude_filter=.*$/m,'exclude_filter=""')
 .replace(/^export_path=.*$/m,'export_path="web/index.html"');
fs.writeFileSync(path.join(project,'export_presets.cfg'),preset);
const performancePhase=process.argv.includes('--perf-before')?'before':process.argv.includes('--perf-after')?'after':null;
if(performancePhase){fs.cpSync(path.join(repo,'tests'),path.join(project,'tests'),{recursive:true});cp.execFileSync('python',[path.join(repo,'tests/profile_compact_v6.py'),'instrument',project,'--fine'],{encoding:'utf8',windowsHide:true});}
const godot='C:/Users/mxz/Desktop/GoDot/Godot_v4.7.2-stable_win64_console.exe';
function engine(args,label){const r=cp.spawnSync(godot,['--headless','--path',project,...args],{encoding:'utf8',windowsHide:true,timeout:180000,maxBuffer:8*1024*1024});const text=(r.stdout||'')+(r.stderr||'');fs.writeFileSync(path.join(dir,label+'.log'),text);assert.equal(r.status,0,label+' failed: '+text.slice(-5000));assert(!/SCRIPT ERROR:|Parse Error:|ERROR:/m.test(text),label+' diagnostics: '+text.slice(-5000));}
engine(['--editor','--import'],'import');engine(['--export-release','Disposable Web','web/index.html'],'export');
const delay=ms=>new Promise(resolve=>setTimeout(resolve,ms));
(async()=>{
 let server,edge,ws,closeBrowser,count=0,lastExpression='';const consoleMessages=[],metrics=[],checks=(ok,message)=>{count++;assert.ok(ok,message);};
 try{
  server=http.createServer((q,r)=>{const url=new URL(q.url,'http://localhost');let file;if(url.pathname.startsWith('/fixtures/'))file=path.join(fixture,path.basename(url.pathname));else file=path.join(web,url.pathname==='/'?'index.html':path.basename(url.pathname));if(!fs.existsSync(file)){r.statusCode=404;r.end();return;}r.setHeader('Cache-Control','no-store');r.setHeader('Content-Type',file.endsWith('.wasm')?'application/wasm':file.endsWith('.js')?'text/javascript':file.endsWith('.html')?'text/html':'application/octet-stream');fs.createReadStream(file).pipe(r);});
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  const userData=path.join(dir,'edge-profile');edge=cp.spawn('C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',['--headless=new','--disable-extensions','--disable-gpu','--enable-unsafe-swiftshader','--no-first-run','--no-default-browser-check','--remote-debugging-port=0','--user-data-dir='+userData,'about:blank'],{stdio:'ignore',windowsHide:true});
  let port;for(let i=0;i<150;i++){try{port=fs.readFileSync(path.join(userData,'DevToolsActivePort'),'utf8').split('\n');break;}catch{}await delay(100);}checks(port,'Own disposable Edge port');
  ws=new WebSocket('ws://127.0.0.1:'+port[0]+port[1]);await new Promise((resolve,reject)=>{ws.onopen=resolve;ws.onerror=reject;});
  let sequence=0;const pending=new Map();ws.onmessage=e=>{const m=JSON.parse(e.data);if(pending.has(m.id)){const p=pending.get(m.id);pending.delete(m.id);clearTimeout(p.timer);m.error?p.reject(Error(JSON.stringify(m.error))):p.resolve(m.result);}if(m.method==='Runtime.consoleAPICalled')consoleMessages.push(m.params.args.map(v=>v.value||v.description||'').join(' '));if(m.method==='Runtime.exceptionThrown')consoleMessages.push('JS_EXCEPTION '+JSON.stringify(m.params.exceptionDetails));};
  const call=(method,params={},sessionId)=>new Promise((resolve,reject)=>{const id=++sequence;const timer=setTimeout(()=>{pending.delete(id);reject(Error('CDP timeout '+method));},performancePhase?300000:45000);pending.set(id,{resolve,reject,timer});ws.send(JSON.stringify({id,method,params,sessionId}));});
  closeBrowser=()=>call('Browser.close');
  const target=await call('Target.createTarget',{url:'about:blank'}),attached=await call('Target.attachToTarget',{targetId:target.targetId,flatten:true}),sid=attached.sessionId;
  const evaluate=async expression=>{lastExpression=expression;const r=await call('Runtime.evaluate',{expression,awaitPromise:true,returnByValue:true},sid);if(r.exceptionDetails)throw Error(JSON.stringify(r.exceptionDetails));return r.result.value;};
  await call('Runtime.enable',{},sid);await call('Page.enable',{},sid);
  await call('Page.addScriptToEvaluateOnNewDocument',{source:`{const M=WebAssembly.Memory;const capture=result=>{const instance=result?.instance||result;if(instance?.exports)for(const value of Object.values(instance.exports))if(value instanceof M)window.__45mMemory=value;};for(const key of ['instantiate','instantiateStreaming']){const original=WebAssembly[key];if(original)WebAssembly[key]=async function(...args){const result=await original.apply(WebAssembly,args);capture(result);return result;};}WebAssembly.Memory=class extends M{constructor(...args){super(...args);window.__45mMemory=this;}};}`},sid);
  const url='http://127.0.0.1:'+server.address().port+'/';await call('Page.navigate',{url},sid);await call('Target.activateTarget',{targetId:target.targetId});
  for(let i=0;i<600;i++){if(await evaluate('Boolean(window.v6Ready)'))break;await delay(100);}checks(await evaluate('Boolean(window.v6Ready)'),'Actual Godot 4.7.2 release WASM ready');
  const install=async()=>evaluate(`window.verify=(text,parent=null)=>v6Harness.call({text,parent});window.nextText=async(text,id)=>{const r=await v6Harness.call({kind:'next',text,id});if(!r.success)throw Error(JSON.stringify(r));return r.text;};window.token=head=>({sequence:head.sequence,digest:head.digest});window.fixtures={};window.stores=[];void 0;`);
  await install();
  const heapBefore=await call('Runtime.getHeapUsage',{},sid);
  for(const name of ['small','168','221','233','400']){
   const data=await evaluate(`(async()=>{const text=await(await fetch('/fixtures/${name}.json')).text();fixtures['${name}']=text;const store=new DisposableV6Store('itank-arena-disposable-v6-45m-${name}',verify);stores.push(store);const a=await store.publish(text,null);if(!a.success)return {failed:a};const bText=await nextText(text,'web_next_${name}');const b=await store.publish(bText,token(a.head));const loaded=await store.load();return {fixture:'${name}',initial:a.save_ms,save:b.save_ms,readback:b.readback_ms,load:loaded.load_ms,bytes:new TextEncoder().encode(text).length,ok:b.success&&loaded.text===bText,records:(await store.snapshot()).records.size,wasm_bytes:window.__45mMemory?.buffer.byteLength||null};})()`);
   checks(data.ok&&data.records===2,'WASM-validated publish/load '+name+' '+JSON.stringify(data));metrics.push(data);
  }
  const cover=await call('Target.createTarget',{url:'about:blank'});await call('Target.activateTarget',{targetId:cover.targetId});await delay(200);checks(await evaluate('(async()=>document.hidden&&(await verify(fixtures.small)).success)()'),'Real WASM validation proceeds in hidden tab without RAF polling');await call('Target.activateTarget',{targetId:target.targetId});
  const matrix=await evaluate(`(async()=>{const s=stores[0],before=await s.load(),text=await nextText(before.text,'matrix_next'),expected=token(before.head),results=[];
   for(const fault of ['before_transaction','abort_transaction']){const r=await s.publish(text,expected,fault),load=await s.load();results.push(!r.success&&load.text===before.text);}
   const lost=await s.publish(text,expected,'lost_ack'),retry=await s.publish(text,expected);results.push(!lost.success&&retry.success&&retry.already_applied);
   const old=await s.publish(before.text,expected);results.push(!old.success);
   const wrong=await s.publish(await nextText(text,'wrong_expected'),{sequence:99,digest:'0'.repeat(64)});results.push(!wrong.success);
   const base=await s.load(),one=await nextText(base.text,'race_a'),two=await nextText(base.text,'race_b'),other=new DisposableV6Store(s.name,verify);const raced=await Promise.all([s.publish(one,token(base.head)),other.publish(two,token(base.head))]);results.push(raced.filter(x=>x.success).length===1);await other.close();
   const good=await s.load();await s.fault('latest_corrupt');results.push(!(await s.load()).success&&(await s.previous()).is_current===false);results.push(!(await s.repairExact(before.text)).success&&(await s.repairExact(good.text)).success);
   await s.fault('previous_corrupt');results.push((await s.load()).success&&!(await s.previous()).success);
   await s.fault('latest_missing');results.push(!(await s.recover()).success&&(await s.repairExact(good.text)).success);
   return {results,recovery_ms:(await s.recover()).recovery_ms};})()`);
  matrix.results.forEach((ok,i)=>checks(ok,'IndexedDB interruption/conflict/recovery '+i));
  const lifetime=await evaluate(`(async()=>{const b=await(await fetch('/fixtures/1000.json')).text(),s=new DisposableV6Store('itank-arena-disposable-v6-45m-lifetime',verify);stores.push(s);const initial=await s.publish(b,null);console.log('45M lifetime initial');const next=await nextText(b,'lifetime_next');console.log('45M lifetime next');const last=await s.publish(next,token(initial.head));console.log('45M lifetime committed');const old=last.record.operations[0].id;const repeated=await v6Harness.call({kind:'next',text:next,id:old});console.log('45M lifetime old operation rejected');const reward=await v6Harness.call({kind:'replay_award',text:next,id:'new_wrapper_for_old_reward'});console.log('45M forged envelope built');const rejected=await s.publish(reward.text,token(last.head));console.log('45M forged envelope checked',JSON.stringify(rejected));const loaded=await s.load();return {ok:last.success&&last.record.operations.length>=1000&&!repeated.success&&!rejected.success&&loaded.text===next,ids:last.record.applied_ids.length,operations:last.record.operations.length,journal:last.record.recent_journal.length,bytes:new TextEncoder().encode(b).length,save_ms:last.save_ms,load_ms:loaded.load_ms,readback_ms:last.readback_ms,rejection:rejected.reason};})()`);
  checks(lifetime.ok&&lifetime.journal===20,'1000+ lifetime duplicate protection through real WASM '+JSON.stringify(lifetime));
  checks(await evaluate(`(()=>{try{new DisposableV6Store('itank-prime-arena.character-profiles',verify);return false;}catch{return true;}})()`),'Production database name rejected before open');
  checks(await evaluate(`(async()=>!(await indexedDB.databases()).some(d=>d.name==='itank-prime-arena.character-profiles'))()`),'Production character database was never created/opened');
  const extra=await evaluate(`(async()=>{const s=stores[0],results=[];const head=await s.load();const outer=JSON.parse(head.text);outer.version=7;results.push(!(await s.publish(JSON.stringify(outer),token(head.head))).success);const wrong=new DisposableV6Store('itank-arena-disposable-v6-45m-wrong-profile',verify,'prod_vaelis_thorn','normal');results.push(!(await wrong.publish(fixtures.small,null)).success);await wrong.close();const mutated=new DisposableV6Store('itank-arena-disposable-v6-45m-name-guard',verify);mutated.name='itank-prime-arena.character-profiles';try{await mutated.db();results.push(false);}catch{results.push(true);}const futureName='itank-arena-disposable-v6-45m-future';await new Promise((resolve,reject)=>{const q=indexedDB.open(futureName,2);q.onsuccess=()=>{q.result.close();resolve();};q.onerror=()=>reject(q.error);});try{await new DisposableV6Store(futureName,verify).db();results.push(false);}catch(e){results.push(e.name==='VersionError');}await s.fault('head_missing');results.push(!(await s.load()).success&&!(await s.publish(fixtures.small,null)).success);return results;})()`);
  extra.forEach((ok,i)=>checks(ok,'Version/identity/head isolation '+i));
  const performance=performancePhase?await require('./compact_v6_performance_edge_cases')({evaluate,call,sid,fixture,checks,phase:performancePhase}):null;
  const backup=process.argv.includes('--backup')?await require('./compact_v6_backup_edge_cases')({evaluate,call,sid,fixture,dir,checks,edgePid:edge.pid}):null;
  const credit=process.argv.includes('--credit')?await require('./compact_v6_credit_edge_cases')({evaluate,call,sid,checks}):null;
  const heapAfter=await call('Runtime.getHeapUsage',{},sid),memory=await evaluate('({wasm_bytes:window.__45mMemory?.buffer.byteLength||null})');
  await evaluate('Promise.all(stores.map(s=>s.close()))');await call('Page.reload',{ignoreCache:true},sid);
  for(let i=0;i<600;i++){if(await evaluate('Boolean(window.v6Ready)'))break;await delay(100);}await install();
  const reload=await evaluate(`(async()=>{const s=new DisposableV6Store('itank-arena-disposable-v6-45m-lifetime',verify),r=await s.load();await s.close();return {ok:r.success,ids:r.record?.applied_ids.length,operations:r.record?.operations.length,head:r.head};})()`);checks(reload.ok&&reload.operations>=1000,'IndexedDB survives actual browser page/WASM reload');
  if(credit){credit.reload=await evaluate(`(async()=>{const s=new DisposableV6BackupStore('itank-arena-disposable-v6-45m-45r-restored',verify,args=>v6Harness.call(args)),r=await s.load();await s.close();return {ok:r.success,credit:r.record?.accounting.credit_expc,expm:r.record?.accounting.expm_total,head:r.head};})()`);checks(credit.reload.ok&&credit.reload.credit===10000&&credit.reload.expm===credit.expm,'Native credit survives actual page/WASM restart exactly once');}
  const errors=consoleMessages.filter(s=>/SCRIPT ERROR:|ERROR:|JS_EXCEPTION/.test(s));checks(errors.length===0,'No Godot/JS errors '+JSON.stringify(errors));
  const output={assertions:count,performance,backup,credit,metrics,matrix,lifetime,reload,heapBefore,heapAfter,memory,consoleMessages,temporaryProject:project,testPckSha256:require('node:crypto').createHash('sha256').update(fs.readFileSync(path.join(web,'index.pck'))).digest('hex'),scope:'Actual isolated Edge + Godot 4.7.2 Web release WASM + real IndexedDB; not production gameplay acceptance'};
  fs.writeFileSync(path.join(fixture,'edge-results.json'),JSON.stringify(output,null,2));console.log(JSON.stringify(output,null,2));
  await call('Browser.close');ws.close();ws=null;
 }finally{fs.writeFileSync(path.join(dir,'partial-results.json'),JSON.stringify({assertions:count,lastExpression,consoleMessages,metrics},null,2));if(ws&&closeBrowser)await closeBrowser().catch(()=>{});if(ws)ws.close();if(server)await new Promise(resolve=>server.close(resolve));if(edge&&edge.exitCode===null)edge.kill();}
})().catch(error=>{console.error(error);console.error('Disposable diagnostics retained at '+dir);process.exitCode=1;});
