const fs=require('node:fs'),path=require('node:path'),http=require('node:http'),os=require('node:os'),cp=require('node:child_process'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..');
const bridge=fs.readFileSync(path.join(root,'scripts/ui/character_backup_files.gd'),'utf8').match(/const BRIDGE := """\r?\n([\s\S]*?)"""/)[1];
const delay=ms=>new Promise(r=>setTimeout(r,ms));
(async()=>{
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'arena45e-edge-')); let edge,server,ws; let count=0;
 const checks=(v,m)=>{count++;assert.ok(v,m);};
 try {
  server=http.createServer((q,r)=>{r.setHeader('Content-Type','text/html');r.end('<!doctype html><title>Disposable 45E scheduler</title>Disposable test only; no storage APIs.');});
  await new Promise(r=>server.listen(0,'127.0.0.1',r));
  edge=cp.spawn('C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',['--headless=new','--disable-gpu','--no-first-run','--no-default-browser-check','--remote-debugging-port=0','--user-data-dir='+dir,'about:blank'],{stdio:'ignore',windowsHide:true});
  let port;for(let i=0;i<100;i++){try{port=fs.readFileSync(path.join(dir,'DevToolsActivePort'),'utf8').split('\n');break;}catch{}await delay(100);}
  checks(port,'Own disposable Edge debugging port');
  ws=new WebSocket('ws://127.0.0.1:'+port[0]+port[1]);await new Promise((r,j)=>{ws.onopen=r;ws.onerror=j;});
  let seq=0,pending=new Map(); ws.onmessage=e=>{const m=JSON.parse(e.data);if(pending.has(m.id)){const p=pending.get(m.id);pending.delete(m.id);m.error?p.reject(Error(JSON.stringify(m.error))):p.resolve(m.result);}};
  const call=(method,params={},sessionId)=>new Promise((resolve,reject)=>{let id=++seq;pending.set(id,{resolve,reject});ws.send(JSON.stringify({id,method,params,sessionId}));});
  const target=await call('Target.createTarget',{url:'http://127.0.0.1:'+server.address().port});
  const attached=await call('Target.attachToTarget',{targetId:target.targetId,flatten:true});const sid=attached.sessionId;
  const evaluate=async expression=>{const r=await call('Runtime.evaluate',{expression,awaitPromise:true,returnByValue:true},sid);if(r.exceptionDetails)throw Error(JSON.stringify(r.exceptionDetails));return r.result.value;};
  await call('Runtime.enable',{},sid);await delay(200);await evaluate(bridge);
  await evaluate(`window.payload=JSON.stringify({v:'x'.repeat(30000)});window.run=(kind,n)=>new Promise(resolve=>{let i=0,start=performance.now();window.result=null;const step=()=>{JSON.parse(payload);if(++i===n){ArenaBackupFiles.stopPulse();window.result={kind,n,ms:performance.now()-start,hidden:document.hidden};resolve(result);}else if(kind==='raf')requestAnimationFrame(step);};if(kind==='raf')requestAnimationFrame(step);else{ArenaBackupFiles.startPulse(step);ArenaBackupFiles.pulseState(true,true);}})`);
  const foreground=await evaluate("run('raf',221)");checks(foreground.n===221,'Foreground RAF control completes');
  const pulse=await evaluate("run('pulse',221)");checks(pulse.n===221,'Production MessageChannel completes foreground');
  // Background the test tab using a second tab in this disposable browser only.
  const cover=await call('Target.createTarget',{url:'about:blank'});await call('Target.activateTarget',{targetId:cover.targetId});await delay(300);
  const hidden=await evaluate('document.hidden');
  // Headless visibility can differ by Edge version: report instead of pretending.
  await evaluate("window.rafCount=0;requestAnimationFrame(()=>{window.rafCount++});void 0");await delay(800);
  const rafBackground=await evaluate('rafCount');
  checks(hidden && rafBackground===0,'Disposable tab is truly hidden and RAF is suspended');
  const background=await evaluate("run('pulse',221)");checks(background.n===221,'Production scheduler completes while other disposable tab selected');
  const stopped=await evaluate(`new Promise(resolve=>{window.stopCount=0;ArenaBackupFiles.startPulse(()=>{stopCount++;ArenaBackupFiles.stopPulse();});ArenaBackupFiles.pulseState(true,true);setTimeout(()=>resolve(stopCount),150);})`);checks(stopped===1,'Stop cancels queued work exactly once');
  const cancelled=await evaluate(`new Promise(resolve=>{window.cancelCount=0;ArenaBackupFiles.startPulse(()=>cancelCount++);ArenaBackupFiles.pulseState(true,true);ArenaBackupFiles.stopPulse();setTimeout(()=>resolve(cancelCount),150);})`);checks(cancelled===0,'Immediate cancellation prevents queued callback');
  // Retained JS heap after repeated allocation/release, not the Godot WASM heap.
  await call('HeapProfiler.enable',{},sid);await call('HeapProfiler.collectGarbage',{},sid);const heapBefore=await call('Runtime.getHeapUsage',{},sid);
  for(let i=0;i<5;i++)await evaluate(`run('pulse',221)`);
  await call('HeapProfiler.collectGarbage',{},sid);const heapAfter=await call('Runtime.getHeapUsage',{},sid);
  checks(heapAfter.usedSize<heapBefore.usedSize+2*1024*1024,'Repeated scheduler jobs retain less than 2 MiB additional JS heap');
  console.log(JSON.stringify({assertions:count,foreground,pulse,background,hidden,rafBackground,heapBefore,heapAfter,userDataDirectory:dir,storageAccess:'NONE',scope:'Actual isolated Edge production JS scheduler; not Godot WASM/browser gameplay'},null,2));
  await call('Browser.close');ws.close();ws=null;
 }finally{if(ws)ws.close();if(server)await new Promise(r=>server.close(r));if(edge&&edge.exitCode===null)edge.kill();}
})().catch(e=>{console.error(e);process.exitCode=1;});
