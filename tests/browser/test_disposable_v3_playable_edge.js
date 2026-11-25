'use strict';
// Own TEMP project/profile/origin only. Never attaches to an existing browser.
const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),http=require('node:http'),cp=require('node:child_process'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const repo=path.resolve(__dirname,'../..'),dir=fs.readFileSync(path.join(os.tmpdir(),'arena46k-current-root.txt'),'utf8').trim();
assert(path.resolve(dir).startsWith(path.join(os.tmpdir(),'arena46k-')));
const project=path.join(dir,'project'),web=path.join(project,'web'),fixtures=path.join(dir,'fixtures');
const sha=t=>crypto.createHash('sha256').update(t).digest('hex'),delay=ms=>new Promise(r=>setTimeout(r,ms));
if(!process.argv.includes('--reuse')){
 fs.mkdirSync(web,{recursive:true});
 for(const folder of ['scripts','data','tests','scenes'])fs.cpSync(path.join(repo,folder),path.join(project,folder),{recursive:true,filter:p=>!p.includes('__pycache__')});
 for(const file of cp.execFileSync('git',['ls-files','--','assets'],{cwd:repo,encoding:'utf8'}).trim().split('\n')){if(!file)continue;assert(!/Rare Human Warrior \(Boss\)\.doc|^character saves\/|^tmp\//.test(file));const target=path.join(project,file);fs.mkdirSync(path.dirname(target),{recursive:true});fs.copyFileSync(path.join(repo,file),target);}
 fs.writeFileSync(path.join(project,'project.godot'),'config_version=5\n[application]\nconfig/name="Disposable 46J"\nrun/main_scene="res://harness.tscn"\n[display]\nwindow/size/viewport_width=1152\nwindow/size/viewport_height=1152\n[rendering]\nrenderer/rendering_method="gl_compatibility"\nrenderer/rendering_method.mobile="gl_compatibility"\n');
 fs.writeFileSync(path.join(project,'harness.tscn'),'[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://tests/disposable_v3_playable_release.gd" id="1"]\n[node name="Harness" type="Node"]\nscript = ExtResource("1")\n');
 const preset=fs.readFileSync(path.join(repo,'export_presets.cfg'),'utf8').replace('name="Web"','name="Disposable Web"').replace(/^custom_features=.*$/m,'custom_features="arena_disposable_v3"').replace(/^include_filter=.*$/m,'include_filter="scripts/**/*.js,assets/Character Choices/*.json"').replace(/^exclude_filter=.*$/m,'exclude_filter=""').replace(/^export_path=.*$/m,'export_path="web/index.html"');
 fs.writeFileSync(path.join(project,'export_presets.cfg'),preset);
 for(const [args,label]of [[['--editor','--import'],'import'],[['--export-release','Disposable Web','web/index.html'],'export']]){
  const r=cp.spawnSync('C:/Users/mxz/Desktop/GoDot/Godot_v4.7.2-stable_win64_console.exe',['--headless','--path',project,...args],{windowsHide:true,encoding:'utf8',timeout:180000,maxBuffer:12*1024*1024});const text=(r.stdout||'')+(r.stderr||'');fs.writeFileSync(path.join(dir,label+'.log'),text);assert(r.status===0&&!/SCRIPT ERROR:|Parse Error:|^ERROR:/m.test(text),label+' '+text.slice(-6000));
 }console.log('46J isolated release exported '+dir);
}
(async()=>{
 let server,edge,ws,call;const messages=[],metrics=[];let assertions=0,lastExpression='';
 const check=(ok,label)=>{assertions++;fs.appendFileSync(path.join(dir,'checks.log'),JSON.stringify({assertion:assertions,pass:!!ok,label})+'\n');assert.ok(ok,label);};
 try{
  server=http.createServer((q,r)=>{r.setHeader('Cache-Control','no-store');const u=new URL(q.url,'http://localhost');const file=u.pathname.startsWith('/fixtures/')?path.join(fixtures,path.basename(u.pathname)):path.join(web,u.pathname==='/'?'index.html':path.basename(u.pathname));if(!fs.existsSync(file)){r.statusCode=404;r.end();return;}r.setHeader('Content-Type',file.endsWith('.wasm')?'application/wasm':file.endsWith('.js')?'text/javascript':file.endsWith('.html')?'text/html':'application/octet-stream');fs.createReadStream(file).pipe(r);});
  await new Promise(r=>server.listen(0,'127.0.0.1',r));const url='http://127.0.0.1:'+server.address().port+'/?arena_disposable_v3=release'+Date.now();
  const userData=path.join(dir,'edge-profile-'+Date.now());edge=cp.spawn('C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',['--headless=new','--disable-extensions','--disable-gpu','--enable-unsafe-swiftshader','--no-first-run','--no-default-browser-check','--remote-debugging-port=0','--user-data-dir='+userData,'about:blank'],{stdio:'ignore',windowsHide:true});
  let port;for(let i=0;i<150;i++){try{port=fs.readFileSync(path.join(userData,'DevToolsActivePort'),'utf8').split('\n');break;}catch{await delay(100);}}check(port,'Own isolated Edge debugging endpoint');
  ws=new WebSocket('ws://127.0.0.1:'+port[0]+port[1]);await new Promise((r,j)=>{ws.onopen=r;ws.onerror=j;});let serial=0;const jobs=new Map();
  ws.onmessage=e=>{const m=JSON.parse(e.data);if(jobs.has(m.id)){const j=jobs.get(m.id);jobs.delete(m.id);clearTimeout(j.timer);m.error?j.reject(Error(JSON.stringify(m.error))):j.resolve(m.result);}if(m.method==='Runtime.consoleAPICalled')messages.push(m.params.args.map(v=>v.value||v.description||'').join(' '));if(m.method==='Runtime.exceptionThrown')messages.push('JS_EXCEPTION '+JSON.stringify(m.params.exceptionDetails));};
  call=(method,params={},sessionId)=>new Promise((resolve,reject)=>{const id=++serial,timer=setTimeout(()=>{jobs.delete(id);reject(Error('CDP timeout '+method));},120000);jobs.set(id,{resolve,reject,timer});ws.send(JSON.stringify({id,method,params,sessionId}));});
  const version=await call('Browser.getVersion');metrics.push({kind:'browser',...version});
  const createTab=async()=>{const t=await call('Target.createTarget',{url:'about:blank'}),a=await call('Target.attachToTarget',{targetId:t.targetId,flatten:true}),sid=a.sessionId;await call('Runtime.enable',{},sid);await call('Page.enable',{},sid);await call('Page.addScriptToEvaluateOnNewDocument',{source:`{const M=WebAssembly.Memory;const capture=r=>{const i=r?.instance||r;if(i?.exports)for(const v of Object.values(i.exports))if(v instanceof M)window.arena46kMemory=v;};for(const k of ['instantiate','instantiateStreaming']){const f=WebAssembly[k];if(f)WebAssembly[k]=async function(...a){const r=await f.apply(WebAssembly,a);capture(r);return r;};}WebAssembly.Memory=class extends M{constructor(...a){super(...a);window.arena46kMemory=this;}};}`},sid);return {target:t.targetId,sid};};
  const tab=await createTab();
  const evaluate=async(expr,sid=tab.sid)=>{lastExpression=expr;const r=await call('Runtime.evaluate',{expression:expr,awaitPromise:true,returnByValue:true},sid);if(r.exceptionDetails)throw Error(JSON.stringify(r.exceptionDetails));return r.result.value;};
  await call('Emulation.setDeviceMetricsOverride',{width:Number(process.env.ARENA_UI_WIDTH||1280),height:Number(process.env.ARENA_UI_HEIGHT||900),deviceScaleFactor:1,mobile:false},tab.sid);
  await call('Page.navigate',{url},tab.sid);
  let result;
  for(let i=0;i<2400;i++){
   result=await evaluate('window.arena46kResult||null');
   if(result)break;
   if(messages.some(x=>/SCRIPT ERROR:|Parse Error:|JS_EXCEPTION/.test(x)))throw Error(messages.slice(-20).join('\n'));
   await delay(100);
  }
  fs.writeFileSync(path.join(dir,'edge-playable-result.json'),JSON.stringify({result,metrics,messages,pck_sha256:sha(fs.readFileSync(path.join(web,'index.pck')))},null,2));
  const shot=await call('Page.captureScreenshot',{format:'png'},tab.sid);fs.writeFileSync(path.join(dir,'edge-last.png'),Buffer.from(shot.data,'base64'));
  metrics.push({viewport:await evaluate('({innerWidth,innerHeight,canvas:document.querySelector("canvas").getBoundingClientRect().toJSON()})')});
  check(result&&result.success,'Actual playable-control assertions '+JSON.stringify(result));
  check(!messages.some(x=>/SCRIPT ERROR:|^ERROR:|JS_EXCEPTION/.test(x)),'No runtime errors');
  console.log('46K Edge accepted '+JSON.stringify(result));
  const image=await call('Page.captureScreenshot',{format:'png'},tab.sid);fs.writeFileSync(path.join(dir,'edge-playable.png'),Buffer.from(image.data,'base64'));
  await call('Browser.close');ws.close();ws=null;
 }finally{fs.writeFileSync(path.join(dir,'edge-partial.json'),JSON.stringify({assertions,lastExpression,messages,metrics},null,2));if(ws&&call)await Promise.race([call('Browser.close').catch(()=>{}),delay(2000)]);if(ws)ws.close();if(server)await new Promise(r=>server.close(r));if(edge&&edge.exitCode===null)edge.kill();}
})().catch(e=>{console.error(e);console.error('46K diagnostics '+dir);process.exitCode=1;});
