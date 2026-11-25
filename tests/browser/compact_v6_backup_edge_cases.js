'use strict';
// Invoked only by the fresh-profile, temporary-project Pass C runner.
module.exports=async({evaluate,call,sid,fixture,dir,checks,edgePid})=>{
 const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process');
 await evaluate(`window.proof=args=>v6Harness.call(args);window.backupStores=[];window.backupMetrics=[];void 0`);
 const heapBefore=await call('Runtime.getHeapUsage',{},sid);
 for(const name of ['small','168','221','233','400','1000']){
  const r=await evaluate(`(async()=>{const text=await(await fetch('/fixtures/${name}.json')).text(),nativeFile=await(await fetch('/fixtures/${name}.v6backup')).text(),store=new DisposableV6BackupStore('itank-arena-disposable-v6-45m-45n-${name}',verify,proof);backupStores.push(store);let a=await store.publish(text,null);if(!a.success)return {failed:a};for(let i=0;i<2;i++){const t=await nextText(a.text,'portable_${name}_'+i);a=await store.publish(t,token(a.head));if(!a.success)return {failed:a};}const exp=await store.export();if(!exp.success)return {failed:exp};const start=performance.now(),preview=await store.prepare(exp.file,token(a.head)),preview_ms=performance.now()-start;const dest=new DisposableV6BackupStore('itank-arena-disposable-v6-45m-45n-dest-${name}',verify,proof);backupStores.push(dest);const ticket=await dest.prepare(exp.file,null),restoreStart=performance.now();const lost=await dest.restore(exp.file,null,ticket.confirmation,'lost_ack'),restore_publish_ms=performance.now()-restoreStart,retry=await dest.restore(exp.file,null,ticket.confirmation);const restore_ms=performance.now()-restoreStart;await dest.fault('latest_missing');const recovered=await dest.recover();const result={fixture:'${name}',equal:exp.file===nativeFile,ok:preview.success&&!lost.success&&retry.success&&retry.already_applied&&recovered.success&&recovered.text===a.text,bytes:exp.bytes,export_ms:exp.export_ms,preview_ms,restore_publish_ms,restore_lost_ack_plus_retry_ms:restore_ms,routine_save_ms:a.save_ms,routine_load_ms:recovered.load_ms,recovery_ms:recovered.recovery_ms,operations:retry.record?.operations.length,ids:retry.record?.applied_ids.length,wasm_bytes:window.__45mMemory?.buffer.byteLength};backupMetrics.push(result);return result;})()`);
  checks(r.ok&&r.equal,'Portable native/Web exact bytes, restore and exact recovery '+name+' '+JSON.stringify(r));
 }
 for(const scope of ['normal','dev_normal'])for(const version of [2,4]){
  const r=await evaluate(`(async()=>{const f=await(await fetch('/fixtures/${scope}_v${version}.v6backup')).text(),profile='${scope}'==='normal'?'prod_vaelis_thorn':'dev_vaelis_thorn',s=new DisposableV6BackupStore('itank-arena-disposable-v6-45m-45n-${scope.replace('_','-')}-v${version}',verify,proof,profile,'${scope}');backupStores.push(s);const p=await s.prepare(f,null);if(!p.success)return p;const r=await s.restore(f,null,p.confirmation),loaded=await s.load();return {success:r.success&&loaded.success&&loaded.text===p.text,preview:p.preview};})()`);
  checks(r.success,'Release WASM namespace and legacy V'+version+' portable restore '+scope+' '+JSON.stringify(r));
 }
 const matrix=await evaluate(`(async()=>{const s=backupStores[0],exp=await s.export(),old=await(await fetch('/fixtures/baseline_small.v6backup')).text(),head=await s.load(),expected=token(head.head),out=[];
 const prep=await s.prepare(old,expected);out.push((await s.restore(old,expected,prep.confirmation)).reason==='older_backup_rejected');
 const newer=await nextText(head.text,'n-after-export');const result=await s.export(()=>s.publish(newer,expected));out.push(result.reason==='export_head_changed');
 const now=await s.load(),e=token(now.head),next=await nextText(now.text,'n-race-next');const p=await proof({kind:'portable_delta',text:next,parent:now.text}),pack=await proof({kind:'portable_encode',text:next,history:[...now.history,p.transition]});
 out.push(!(await s.restore(pack.text,e,'forged')).success);const ticket=await s.prepare(pack.text,e);
 for(const fault of ['before_transaction','abort_transaction']){const r=await s.restore(pack.text,e,ticket.confirmation,fault);out.push(!r.success&&(await s.load()).text===now.text);}
 const other=new DisposableV6BackupStore(s.name,verify,proof);const raced=await Promise.all([s.restore(pack.text,e,ticket.confirmation),other.restore(pack.text,e,ticket.confirmation)]);out.push(raced.some(r=>r.success)&&(await s.load()).text===next);await other.close();
 out.push(!(await s.restore(exp.file,e,(await s.prepare(exp.file,e)).confirmation)).success);
 const bads=[exp.file.slice(0,-1),exp.file.slice(0,100),exp.file.replace('integrity','tampered'),exp.file.replace('"version":1','"version":99')];for(const f of bads)out.push(!(await s.prepare(f,e)).success);
 // Reframe malicious totals with every transport checksum recomputed.
 const frames=exp.file.trimEnd().split('\\n'),header=JSON.parse(frames[0]),outer=JSON.parse(frames[1]),record=JSON.parse(outer.payload_json);
 record.accounting.expc_available+=10000;const sort=v=>Array.isArray(v)?v.map(sort):(v&&typeof v==='object'?Object.fromEntries(Object.keys(v).sort().map(k=>[k,sort(v[k])])):v);const canonical=v=>JSON.stringify(sort(v));const sha=async t=>Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(t))),b=>b.toString(16).padStart(2,'0')).join('');
 outer.payload_json=canonical(record);outer.sha256=await sha(outer.payload_json);frames[1]=canonical(outer);header.document_digest=await sha(frames[1]);frames[0]=canonical(header);const body=frames.slice(0,-1).join('\\n')+'\\n',forged=body+canonical({kind:'integrity',sha256:await sha(body)})+'\\n';out.push(!(await s.prepare(forged,e)).success);
 const before=await indexedDB.databases(),cancel=new DisposableV6BackupStore('itank-arena-disposable-v6-45m-45n-cancel',verify,proof);await cancel.prepare(exp.file,null);const after=await indexedDB.databases();out.push(!after.some(d=>d.name===cancel.name)&&before.length===after.length);
 const wrong=new DisposableV6BackupStore('itank-arena-disposable-v6-45m-45n-wrong',verify,proof,'prod_vaelis_thorn','normal');out.push(!(await wrong.prepare(exp.file,null)).success);
 const current=await s.load();await s.fault('latest_corrupt');out.push((await s.recover()).text===current.text);await s.fault('previous_corrupt');out.push((await s.load()).text===current.text);
 // Previous alone cannot authorize recovery when current AND capsule are gone.
 const snap=await s.snapshot(),db=await s.db();await new Promise((resolve,reject)=>{const tx=db.transaction('records','readwrite');tx.objectStore('records').delete(snap.head.digest);tx.objectStore('records').delete('portable:'+snap.head.digest);tx.oncomplete=resolve;tx.onabort=reject;});out.push(!(await s.recover()).success);
 const external=await proof({kind:'portable_encode',text:current.text,history:current.history}),extTicket=await s.prepare(external.text,token(current.head));out.push((await s.restore(external.text,token(current.head),extTicket.confirmation)).success);
 return out;})()`);
 matrix.forEach((ok,i)=>checks(ok,'Pass D restore/integrity/cancellation case '+i));
 // Actual DOM File input reads a native-produced portable artifact. Preview
 // never opens its destination DB; no profile/file selection outside fixtures.
 await evaluate(`{const input=document.createElement('input');input.id='portable-input';input.type='file';input.onchange=async()=>{const text=new TextDecoder('utf-8',{fatal:true}).decode(await input.files[0].arrayBuffer());window.filePreview=await proof({kind:'portable_decode',portable:text});};document.body.append(input);}void 0`);
 const document=await call('DOM.getDocument',{},sid),node=await call('DOM.querySelector',{nodeId:document.root.nodeId,selector:'#portable-input'},sid);
 await call('DOM.setFileInputFiles',{nodeId:node.nodeId,files:[path.join(fixture,'small.v6backup')]},sid);
 for(let i=0;i<100;i++){if(await evaluate('Boolean(window.filePreview)'))break;await new Promise(r=>setTimeout(r,100));}
 checks(await evaluate('Boolean(window.filePreview?.success&&filePreview.preview.namespace==="dev_normal")'),'Actual native file input -> release WASM read-only preview');
 await call('Browser.setDownloadBehavior',{behavior:'allow',downloadPath:dir,eventsEnabled:true});
 await evaluate(`(async()=>{const f=await(await fetch('/fixtures/small.v6backup')).text();const a=document.createElement('a');a.href=URL.createObjectURL(new Blob([f],{type:'application/octet-stream'}));a.download='portable-download.v6backup';document.body.append(a);a.click();a.remove();setTimeout(()=>URL.revokeObjectURL(a.href),1000);})()`);
 for(let i=0;i<100&&!fs.existsSync(path.join(dir,'portable-download.v6backup'));i++)await new Promise(r=>setTimeout(r,100));
 checks(fs.existsSync(path.join(dir,'portable-download.v6backup'))&&fs.readFileSync(path.join(dir,'portable-download.v6backup')).equals(fs.readFileSync(path.join(fixture,'small.v6backup'))),'Actual browser Blob download preserves exact portable bytes');
 const repeated=await evaluate(`(async()=>{const s=backupStores.find(s=>s.name.endsWith('-45n-1000')),results=[];for(let i=0;i<3;i++){const a=await s.export(),start=performance.now(),p=await s.prepare(a.file,token((await s.load()).head));results.push({ok:a.success&&p.success,export_ms:a.export_ms,preview_including_load_ms:performance.now()-start});}return results;})()`);repeated.forEach((r,i)=>checks(r.ok,'Repeated large export/preview cycle '+i));
 const heapAfter=await call('Runtime.getHeapUsage',{},sid);await call('HeapProfiler.collectGarbage',{},sid);const heapAfterGC=await call('Runtime.getHeapUsage',{},sid);
 const processInfo=await call('SystemInfo.getProcessInfo'),pids=processInfo.processInfo.filter(p=>p.type==='renderer').map(p=>p.id);
 let renderer=null;if(pids.length){try{renderer=JSON.parse(cp.execFileSync('powershell',['-NoProfile','-Command',`$processes=Get-CimInstance Win32_Process -Filter \"Name='msedge.exe'\"; $owned=@(${edgePid}); do { $added=@($processes | Where-Object { $_.ParentProcessId -in $owned -and $_.ProcessId -notin $owned } | ForEach-Object ProcessId); $owned+=$added } while($added.Count -gt 0); $targets=@(${pids.join(',')}) | Where-Object { $_ -in $owned }; if($targets.Count -gt 0) { Get-Process -Id $targets | Select-Object Id,WorkingSet64,PeakWorkingSet64 | ConvertTo-Json -Compress }`],{encoding:'utf8',windowsHide:true}));}catch{}}
 const metrics=await evaluate('backupMetrics');
 await evaluate('Promise.all(backupStores.map(s=>s.close()))');
 return {metrics,matrix,repeated,heapBefore,heapAfter,heapAfterGC,renderer,scope:'Actual fresh Edge, disposable IDB and release Godot WASM; file input and download automated; no owner acceptance'};
};
