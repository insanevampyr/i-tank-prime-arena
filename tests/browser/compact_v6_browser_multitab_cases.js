 'use strict';
module.exports=async({evaluate,call,sid,url,checks})=>{
const fs=require('node:fs'),path=require('node:path');
const other=await call('Target.createTarget',{url:'about:blank'}),attached=await call('Target.attachToTarget',{targetId:other.targetId,flatten:true}),peer=attached.sessionId;
const ev=async e=>{const r=await call('Runtime.evaluate',{expression:e,awaitPromise:true,returnByValue:true},peer);if(r.exceptionDetails)throw Error(JSON.stringify(r.exceptionDetails));return r.result.value;};
await call('Page.enable',{},peer);await call('Page.navigate',{url:url+'guard.html'},peer);await new Promise(r=>setTimeout(r,100));
await ev(fs.readFileSync(path.join(__dirname,'../../scripts/rewards/character_browser_store.js'),'utf8'));
checks(await ev(`(async()=>{window.oldClient=ArenaCharacterBrowserStorage.testStore({testing:true,database:'itank-arena-test-36k-45t-multitab'});const d=await oldClient.db();window.oldTransactionComplete=false;const t=d.transaction(['heads'],'readwrite');for(let i=0;i<500;i++)t.objectStore('heads').put({profile:'inflight_'+i,value:i});t.oncomplete=()=>oldTransactionComplete=true;return (await oldClient.acquire('dev_vaelis_thorn','old_owner')).success;})()`),'Actual schema-1 peer holds original Web Lock while transaction runs');
const upgrade=await evaluate(`(async()=>{window.multitab=ArenaCompactV6Browser.testStore('itank-arena-test-36k-45t-multitab');const opened=await multitab.run('open');const blocked=await multitab.run('acquire',{profile:'dev_vaelis_thorn',owner:'new_owner'});const d=await multitab.db(),t=d.transaction('heads','readonly'),q=t.objectStore('heads').count();const count=await new Promise(r=>q.onsuccess=()=>r(q.result));return {opened,blocked,count};})()`);
checks(upgrade.opened.success&&!upgrade.blocked.success&&upgrade.count===500,'Schema upgrade waits for in-flight writes, preserves all records and does not steal old-tab lock');
checks(await ev(`oldClient.closed&&oldTransactionComplete`),'Actual old connection receives versionchange and finishes its in-flight transaction');
checks(!(await ev(`oldClient.run('publish',{profile:'dev_vaelis_thorn',owner:'old_owner',transaction_id:'forged',expected_generation:0,document:'{}'})`)).success,'Closed schema-1 tab cannot publish after upgrade');
await call('Target.closeTarget',{targetId:other.targetId});
checks(await evaluate(`(async()=>{for(let i=0;i<100;i++){const r=await multitab.run('acquire',{profile:'dev_vaelis_thorn',owner:'new_owner'});if(r.success)return true;await new Promise(r=>setTimeout(r,10));}return false;})()`),'Browser releases Web Lock after actual old-tab termination without PID/time stealing');
checks(await evaluate(`(async()=>{const a=await multitab.run('transfer',{profile:'dev_vaelis_thorn',owner:'new_owner',next_owner:'transferred'}),b=await multitab.run('release',{profile:'dev_vaelis_thorn',owner:'new_owner'}),c=await multitab.run('release',{profile:'dev_vaelis_thorn',owner:'transferred'});return a.success&&!b.success&&c.success;})()`),'Only exact transferred owner may release lease');
await evaluate('multitab.close()');
};
