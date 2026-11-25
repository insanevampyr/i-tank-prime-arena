 'use strict';
const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),http=require('node:http'),cp=require('node:child_process'),assert=require('node:assert/strict');
const repo=path.resolve(__dirname,'../..'),dir=fs.mkdtempSync(path.join(os.tmpdir(),'arena45t-edge-'));

const schemaOnly=process.argv.includes('--schema-only');
const resumeProfile=process.argv.find(a=>a.startsWith('--resume-profile='))?.slice(17);
const resumePort=resumeProfile?Number(fs.readdirSync(path.join(resumeProfile,'Default/IndexedDB')).map(n=>n.match(/^http_127.0.0.1_(\d+)\./)?.[1]).find(Boolean)):0;
const reuse=process.argv.find(a=>a.startsWith('--reuse='))?.slice(8);
const project=reuse||path.join(dir,'project'),web=path.join(project,'web');
const fixture=path.join(os.homedir(),'AppData/Local/itank-storage-tests/compact45m_45n_session_20261117e');
const frozenPath=fs.readFileSync(path.join(os.tmpdir(),'arena45s-frozen-bundle.txt'),'utf8').trim();
assert(frozenPath.replaceAll('\\','/').toLowerCase().startsWith(path.join(os.homedir(),'AppData/Local/itank-storage-tests/compact45s_').replaceAll('\\','/').toLowerCase()));
const crypto=require('node:crypto'),sha=t=>crypto.createHash('sha256').update(t).digest('hex');
if(!schemaOnly&&!reuse){
fs.mkdirSync(web,{recursive:true});
for(const folder of ['scripts','data','tests','scenes'])fs.cpSync(path.join(repo,folder),path.join(project,folder),{recursive:true,filter:p=>!p.includes('__pycache__')});
for(const file of cp.execFileSync('git',['ls-files','--','assets'],{cwd:repo,encoding:'utf8'}).trim().split('\n')){if(!file)continue;assert(!/Rare Human Warrior \(Boss\)\.doc|^character saves\/|^tmp\//.test(file));const target=path.join(project,file);fs.mkdirSync(path.dirname(target),{recursive:true});fs.copyFileSync(path.join(repo,file),target);}
fs.writeFileSync(path.join(project,'project.godot'),'config_version=5\n[application]\nconfig/name="Disposable 45T S5"\nrun/main_scene="res://harness.tscn"\n[display]\nwindow/size/viewport_width=320\nwindow/size/viewport_height=180\n[rendering]\nrenderer/rendering_method="gl_compatibility"\nrenderer/rendering_method.mobile="gl_compatibility"\n');
fs.writeFileSync(path.join(project,'harness.tscn'),'[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://tests/browser/compact_v6_browser_wasm_harness.gd" id="1"]\n[node name="Harness" type="Node"]\nscript = ExtResource("1")\n');
const preset=fs.readFileSync(path.join(repo,'export_presets.cfg'),'utf8').replace('name="Web"','name="Disposable Web"').replace(/^include_filter=.*$/m,'include_filter="scripts/**/*.js,tests/browser/*.js,assets/Character Choices/*.json"').replace(/^exclude_filter=.*$/m,'exclude_filter=""').replace(/^export_path=.*$/m,'export_path="web/index.html"');
fs.writeFileSync(path.join(project,'export_presets.cfg'),preset);
for(const [args,label] of [[['--editor','--import'],'import'],[['--export-release','Disposable Web','web/index.html'],'export']]){const r=cp.spawnSync('C:/Users/mxz/Desktop/GoDot/Godot_v4.7.2-stable_win64_console.exe',['--headless','--path',project,...args],{windowsHide:true,encoding:'utf8',timeout:180000,maxBuffer:12*1024*1024});const text=(r.stdout||'')+(r.stderr||'');fs.writeFileSync(path.join(dir,label+'.log'),text);assert(r.status===0&&!/SCRIPT ERROR:|Parse Error:|^ERROR:/m.test(text),label+' '+text.slice(-5000));}
console.log('45T isolated release exported '+dir);
}
const delay=ms=>new Promise(r=>setTimeout(r,ms));
(async()=>{let server,edge,ws,closeBrowser,count=0,lastExpression='';const consoleMessages=[],metrics=[],checks=(ok,message)=>{count++;assert.ok(ok,message);};
try{
server=http.createServer((q,r)=>{
const u=new URL(q.url,'http://localhost');r.setHeader('Cache-Control','no-store');
if(schemaOnly||u.pathname==='/guard.html'){r.setHeader('Content-Type','text/html');r.end('<html>Isolated S5 gate</html>');return;}
let file;if(u.pathname==='/legacy233'){const outer=JSON.parse(fs.readFileSync(frozenPath,'utf8'));assert(sha(outer.body_json)===outer.sha256);r.setHeader('Content-Type','application/json');r.end(outer.body_json);return;}
if(u.pathname.startsWith('/fixtures/'))file=path.join(fixture,path.basename(u.pathname));else file=path.join(web,u.pathname==='/'?'index.html':path.basename(u.pathname));
if(!fs.existsSync(file)){r.statusCode=404;r.end();return;}r.setHeader('Content-Type',file.endsWith('.wasm')?'application/wasm':file.endsWith('.js')?'text/javascript':file.endsWith('.html')?'text/html':'application/octet-stream');fs.createReadStream(file).pipe(r);
});await new Promise(r=>server.listen(resumePort||0,'127.0.0.1',r));
  const userData=resumeProfile||path.join(dir,'edge-profile'),edgeStart=Date.now();edge=cp.spawn('C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',['--headless=new','--disable-extensions','--disable-gpu','--enable-unsafe-swiftshader','--no-first-run','--no-default-browser-check','--remote-debugging-port=0','--user-data-dir='+userData,'about:blank'],{stdio:'ignore',windowsHide:true});
  let port;for(let i=0;i<150;i++){try{if(resumeProfile&&fs.statSync(path.join(userData,'DevToolsActivePort')).mtimeMs<edgeStart)throw Error('old debugging endpoint');port=fs.readFileSync(path.join(userData,'DevToolsActivePort'),'utf8').split('\n');break;}catch{}await delay(100);}checks(port,'Own disposable Edge port');
  ws=new WebSocket('ws://127.0.0.1:'+port[0]+port[1]);await new Promise((resolve,reject)=>{ws.onopen=resolve;ws.onerror=reject;});
  let sequence=0;const pending=new Map();ws.onmessage=e=>{const m=JSON.parse(e.data);if(pending.has(m.id)){const p=pending.get(m.id);pending.delete(m.id);clearTimeout(p.timer);m.error?p.reject(Error(JSON.stringify(m.error))):p.resolve(m.result);}if(m.method==='Runtime.consoleAPICalled')consoleMessages.push(m.params.args.map(v=>v.value||v.description||'').join(' '));if(m.method==='Runtime.exceptionThrown')consoleMessages.push('JS_EXCEPTION '+JSON.stringify(m.params.exceptionDetails));};
  const call=(method,params={},sessionId)=>new Promise((resolve,reject)=>{const id=++sequence;const timer=setTimeout(()=>{pending.delete(id);reject(Error('CDP timeout '+method));},300000);pending.set(id,{resolve,reject,timer});ws.send(JSON.stringify({id,method,params,sessionId}));});
  closeBrowser=()=>Promise.race([call('Browser.close'),delay(2000)]);
  const target=await call('Target.createTarget',{url:'about:blank'}),attached=await call('Target.attachToTarget',{targetId:target.targetId,flatten:true}),sid=attached.sessionId;
  const evaluate=async expression=>{lastExpression=expression;const r=await call('Runtime.evaluate',{expression,awaitPromise:true,returnByValue:true},sid);if(r.exceptionDetails)throw Error(JSON.stringify(r.exceptionDetails));return r.result.value;};
  await call('Runtime.enable',{},sid);await call('Page.enable',{},sid);

await call('Page.addScriptToEvaluateOnNewDocument',{source:`{const M=WebAssembly.Memory;const capture=r=>{const i=r?.instance||r;if(i?.exports)for(const v of Object.values(i.exports))if(v instanceof M)window.s5Memory=v;};for(const k of ['instantiate','instantiateStreaming']){const f=WebAssembly[k];if(f)WebAssembly[k]=async function(...a){const r=await f.apply(WebAssembly,a);capture(r);return r;};}WebAssembly.Memory=class extends M{constructor(...a){super(...a);window.s5Memory=this;}};}`},sid);
const url='http://127.0.0.1:' +server.address().port+'/';await call('Page.navigate',{url},sid);await delay(200);
await evaluate(fs.readFileSync(path.join(repo,'scripts/rewards/character_browser_store.js'),'utf8'));
await evaluate(fs.readFileSync(path.join(repo,'scripts/rewards/compact_v6_browser_store.js'),'utf8'));
const gate=resumeProfile?[]:await evaluate(`(async()=>{
const results=[],p='dev_vaelis_thorn',name='itank-arena-test-36k-45t-gate';
try{ArenaCompactV6Browser.testStore('itank-prime-arena.character-profiles');results.push(false);}catch{results.push(true);}
const old=ArenaCharacterBrowserStorage.testStore({testing:true,database:name}),db=await old.db();
let tx=db.transaction(['heads'],'readwrite');tx.objectStore('heads').put({profile:p,marker:'legacy_unchanged'});await new Promise(r=>tx.oncomplete=r);
const fresh=ArenaCompactV6Browser.testStore(name);results.push((await fresh.run('open')).success&&old.closed);
const snap=await fresh.run('snapshot',{profile:p});results.push(snap.success&&snap.legacy_head.marker==='legacy_unchanged');
const outdated=ArenaCharacterBrowserStorage.testStore({testing:true,database:name});results.push((await outdated.run('inspect',{profile:p})).reason==='unsupported_database_version');
const lease=await fresh.run('acquire',{profile:p,owner:'fresh'}),contender=ArenaCharacterBrowserStorage.testStore({testing:true,database:name});results.push(lease.success&&!(await contender.run('acquire',{profile:p,owner:'old'})).success);
results.push((await fresh.run('transfer',{profile:p,owner:'fresh',next_owner:'next'})).success&&!(await fresh.run('release',{profile:p,owner:'fresh'})).success&&(await fresh.run('release',{profile:p,owner:'next'})).success);
await fresh.close();await outdated.close();await contender.close();
const block='itank-arena-test-36k-45t-blocked';let hold=await new Promise((r,j)=>{const q=indexedDB.open(block,1);q.onsuccess=()=>r(q.result);q.onerror=()=>j(q.error);});hold.onversionchange=()=>{};
const blocked=ArenaCompactV6Browser.testStore(block);results.push((await blocked.run('open')).reason==='database_upgrade_blocked');hold.close();await new Promise(r=>setTimeout(r,100));await blocked.close();
results.push(!(await indexedDB.databases()).some(d=>d.name==='itank-prime-arena.character-profiles'));
return results;})()`);
gate.forEach((v,i)=>checks(v,'Old-client/schema gate '+i));
if(!resumeProfile)await require('./compact_v6_browser_multitab_cases')({evaluate,call,sid,url,checks});
if(resumeProfile&&!process.argv.includes('--phase=large-portable')){const r=await evaluate(`(async()=>{const s=ArenaCompactV6Browser.testStore('itank-arena-test-36k-45t-credit'),p=await s.snapshot('dev_vaelis_thorn'),b=p.blobs.find(b=>b.kind==='record'&&b.digest===p.route.digest),r=JSON.parse(JSON.parse(b.text).payload_json);await s.close();return {items:r.current.items.length,accounting:r.accounting,operations:r.operations.length,last:r.operations.at(-1)};})()`);console.log('DISPOSABLE_DIAG '+JSON.stringify(r));}
if(!schemaOnly&&(!resumeProfile||process.argv.includes('--phase=large-portable')))await require(process.argv.includes('--routine')?'./compact_v6_routine_edge_cases':'./compact_v6_browser_edge_cases')({evaluate,call,sid,target,url,dir,fixture,checks,metrics,edgePid:edge.pid,phase:process.argv.find(a=>a.startsWith("--phase="))?.slice(8)});
checks(!consoleMessages.some(m=>/SCRIPT ERROR:|^ERROR:|JS_EXCEPTION/.test(m)),'No Godot/JS runtime errors');
const output={success:true,assertions:count,gate,metrics,pck:!schemaOnly?sha(fs.readFileSync(path.join(web,'index.pck'))):null,consoleMessages,scope:'isolated Edge schema/lock guard; no owner storage',dir};fs.writeFileSync(path.join(dir,'gate-results.json'),JSON.stringify(output,null,2));console.log(JSON.stringify(output));
await call('Browser.close');ws.close();ws=null;
}finally{fs.writeFileSync(path.join(dir,'partial-results.json'),JSON.stringify({assertions:count,lastExpression,consoleMessages,metrics},null,2));if(ws&&closeBrowser)await closeBrowser().catch(()=>{});if(ws)ws.close();if(server)await new Promise(r=>server.close(r));if(edge&&edge.exitCode===null)edge.kill();}
})().catch(e=>{console.error(e);console.error('Diagnostics '+dir);process.exitCode=1;});
