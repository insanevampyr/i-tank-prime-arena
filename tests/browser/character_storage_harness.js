/* Real IndexedDB/Web Locks, disposable test databases only. Browser faults that
 * cannot safely be forced (disk quota/permission denial) are explicitly injected. */
"use strict";
const token = new URLSearchParams(location.search).get("test");
if (!token || !/^[a-z0-9-]{1,40}$/.test(token)) throw new Error("Supply a disposable ?test=lowercase-token");
const database = `itank-arena-test-36k-${token}`;
document.getElementById("database").textContent = database;
const api = globalThis.ArenaCharacterBrowserStorage;
const output = document.getElementById("output");
const profile = "prod_browser_fixture", dev = "dev_browser_fixture";
let lines = [], passed = 0, failed = 0, tabStore;
const say = text => {lines.push(text); output.textContent = lines.join("\n");};
const check = (condition, name) => {condition ? passed++ : failed++; say(`${condition ? "PASS" : "FAIL"}: ${name}`); if (!condition) throw new Error(name);};
const fixtures = fetch("character_storage_fixture.json").then(r => {if (!r.ok) throw new Error("Generate fixtures with documented Godot command"); return r.json();});
const make = suffix => api.testStore({testing: true, database: `${database}-${suffix}`});
const args = (document, generation, transaction_id = `test_txn_${generation + 1}`, fault) => ({profile, owner:"session_a", expected_generation: generation, transaction_id, document, ...(fault ? {fault} : {})});
const txDone = tx => new Promise((resolve,reject) => {tx.oncomplete=resolve;tx.onabort=()=>reject(tx.error);tx.onerror=()=>{};});

async function core() {
  lines=[];passed=0;failed=0;
  const f = await fixtures;
  for (const unavailable of ["indexeddb","locks"]) {
    const absent=api.testStore({testing:true,database:`${database}-no-${unavailable}`,unavailable});
    const response=await absent.run(unavailable === "locks" ? "acquire" : "inspect",{profile,owner:"session_a"});
    check(response.state === "unavailable",`Injected missing ${unavailable} capability fails closed without fallback`);
    await absent.close();
  }
  const store = make("core");
  const current = await store.run("inspect",{profile});
  check(current.success && current.missing,"Fresh disposable DB is missing, not corrupt (use fresh token for repeat)");
  check((await store.run("acquire",{profile,owner:"session_a"})).success,"Acquire exclusive native Web Lock");
  const first = await store.run("publish",args(f.normal[0],0));
  check(first.success && first.document === f.normal[0] && first.generation === 1,"Canonical Contract V2 bytes, generation and transaction exact after fresh readback");
  check((await store.run("publish",args(f.normal[0],0))).reason === "exact_retry_verified","Exact retry deduplicated");
  check((await store.run("publish",args(f.normal[1],0))).state !== "verified_committed","Mismatched candidate generation rejected");
  check((await store.run("publish",args(f.normal[0],0,"other_txn"))).reason === "stale_generation","In-transaction expected-generation rejection");
  check((await store.run("publish",args(f.normal[1],1,"test_txn_1"))).reason === "transaction_payload_conflict","Transaction ID cannot be reused for different document");
  const abort = await store.run("publish",args(f.normal[1],1,"test_txn_2","abort"));
  check(abort.state === "failed" && (await store.run("inspect",{profile})).document === f.normal[0],"Actual IDB abort after queued writes rolls back head, generation and receipt");
  for (const fault of ["quota","denied"]) {
    const response = await store.run("publish",args(f.normal[1],1,"test_txn_2",fault));
    check(response.state === (fault === "denied" ? "unavailable" : "failed") && (await store.run("inspect",{profile})).generation === 1,`Injected ${fault} failure preserves verified generation (not real quota exhaustion/permission setting)`);
  }
  check((await store.run("publish",args(f.normal[1],1,"test_txn_2","lost_ack"))).state === "recovery_required","Commit with intentionally lost acknowledgement is uncertain, not successful");
  check((await store.run("reconcile",args(f.normal[1],1))).success,"Fresh read reconciles ambiguous acknowledgement without write");
  check((await store.run("publish",args(f.normal[1],1))).reason === "exact_retry_verified","Replayed ambiguous publication cannot duplicate generation");
  check((await store.run("publish",args(f.normal[2],2,"test_txn_3","readback_mismatch"))).state === "recovery_required","Injected readback mismatch is never acknowledged");
  check((await store.run("reconcile",args(f.normal[2],2))).success,"Readback mismatch can be explicitly reconciled");
  check((await store.run("acquire",{profile:dev,owner:"dev_owner"})).success,"Independent DEV namespace lock");
  const devWrite = await store.run("publish",{profile:dev,owner:"dev_owner",expected_generation:0,transaction_id:"dev_txn_1",document:f.dev_normal[0]});
  check(devWrite.success && (await store.run("inspect",{profile})).generation === 3,"NORMAL/DEV namespaces remain independent");
  check((await store.run("publish",{profile:dev,owner:"dev_owner",expected_generation:1,transaction_id:"bad_namespace",document:f.normal[1]})).state === "recovery_required","Cross-namespace document rejected");
  check((await store.run("transfer",{profile,owner:"session_a",next_owner:"candidate_a"})).success,"Lease transferred in place to candidate without lock gap");
  check((await store.run("release",{profile,owner:"session_a"})).state === "unavailable","Old session cannot release candidate lease");
  check((await store.run("release",{profile,owner:"candidate_a"})).success,"Candidate releases writer lock");
  const other = make("core");
  check((await other.run("acquire",{profile,owner:"session_b"})).success,"Released lock available to another store");
  check((await other.run("inspect",{profile})).document === f.normal[2],"Closed/reopened IDB connection preserves exact canonical bytes");
  await other.close(); await store.close();
  // Corruption fixtures affect only explicitly disposable databases.
  for (const fault of ["corrupt_primary","future_version"]) {
    const target = make(fault.replaceAll("_","-"));
    await target.run("acquire",{profile,owner:"session_a"});
    check((await target.run("publish",args(f.normal[0],0))).success,`${fault} baseline committed`);
    const db = await target.db();
    const tx = db.transaction(["heads","generations","transactions"],"readwrite");
    const done = txDone(tx);
    if (fault === "corrupt_primary") tx.objectStore("heads").put({profile,generation:1,transaction_id:"test_txn_1",document:"corrupt"});
    else {
      const envelope = JSON.parse(f.normal[0]); envelope.version=999;
      const record={profile,generation:1,transaction_id:"test_txn_1",document:JSON.stringify(envelope)};
      tx.objectStore("heads").put(record);tx.objectStore("generations").put(record);tx.objectStore("transactions").put({...record,expected_generation:0});
    }
    await done;
    const rejected = await target.run("inspect",{profile});
    check(rejected.state === "recovery_required" && !rejected.missing,`${fault} never becomes missing/new profile`);
    check(!(await target.run("publish",args(f.normal[1],1))).success,`${fault} blocks further writes and retains evidence`);
    await target.close();
  }
  // Exercise the exact JSON job interface used by JavaScriptBridge.
  const handle=api.create(JSON.stringify({testing:true,database:`${database}-bridge`}));
  const job=api.request(handle,"inspect",JSON.stringify({profile}));
  let poll=JSON.parse(api.poll(handle,job));
  check(poll.state === "pending" && !poll.success,"Bridge queue returns pending before async IDB result");
  // Harness-only browser event loop; no combat simulation or blocking loop.
  while(poll.state === "pending") {await new Promise(resolve=>setTimeout(resolve,10));poll=JSON.parse(api.poll(handle,job));}
  check(poll.success && poll.missing,"JSON bridge polling receives completed inspection");
  await api.dispose(handle);
  const closing=api.create(JSON.stringify({testing:true,database:`${database}-closing`}));
  async function bridgeResult(job) {
    let value=JSON.parse(api.poll(closing,job));
    while(value.state === "pending") {await new Promise(resolve=>setTimeout(resolve,10)); value=JSON.parse(api.poll(closing,job));}
    return value;
  }
  check((await bridgeResult(api.request(closing,"acquire",JSON.stringify({profile,owner:"session_a"})))).success,"Termination fixture owns native writer lease");
  api.request(closing,"publish",JSON.stringify(args(f.normal[0],0)));
  const drained=api.dispose(closing);
  check(api.request(closing,"inspect",JSON.stringify({profile})) === "","Closing engine handle rejects new operations");
  check((await drained).success,"Engine shutdown drains an in-flight publication before releasing its lease");
  const reopened=make("closing");
  check((await reopened.run("acquire",{profile,owner:"session_b"})).success && (await reopened.run("inspect",{profile})).document === f.normal[0],"New session obtains released lease and verified generation after drained shutdown");
  await reopened.close();
  say(`CORE RESULT: ${passed} passed, ${failed} failed. Two-tab/close-reopen checks are separate buttons.`);
}

async function hold() {
  const f=await fixtures;tabStore ||= make("tabs");
  check((await tabStore.run("acquire",{profile,owner:"session_a"})).success,"Tab A native writer lease acquired");
  check((await tabStore.run("publish",args(f.normal[0],0))).success,"Tab A generation 1 stored and read back");
  say("Keep this tab open. Open a second harness tab with the SAME test token; click Tab B contention.");
}
async function contend() {
  const f=await fixtures;
  tabStore ||= make("tabs");
  const response=await tabStore.run("acquire",{profile,owner:"session_b"});
  check(response.state === "unavailable" && response.reason === "profile_in_use","Actual second tab cannot acquire writer (no mutation)");
  check((await tabStore.run("publish",{...args(f.normal[1],1),owner:"session_b"})).state === "unavailable" && (await tabStore.run("inspect",{profile})).generation === 1,"Competing tab cannot publish without native lock; current generation unchanged");
  say("Close Tab A, then click After A closes in this tab.");
}
async function reopen() {
  const f=await fixtures;tabStore ||= make("tabs");
  const read=await tabStore.run("inspect",{profile});
  check(read.success && read.document === f.normal[0],"After actual tab close: exact generation 1 readback");
  check((await tabStore.run("acquire",{profile,owner:"session_b"})).success,"Browser released Tab A lock on termination");
  const committed=await tabStore.run("publish",{...args(f.normal[1],1),owner:"session_b"});
  check(committed.success,"Tab B safely publishes next generation after ownership release");
}
async function verify() {
  const f=await fixtures;const readStore=make("tabs");
  const read=await readStore.run("inspect",{profile});
  check(read.success && read.document === f.normal[1] && read.generation === 2,"Fresh reopened tab reads exact generation 2, transaction, history");
  await readStore.close();
}
for (const [name, callback] of Object.entries({core,hold,contend,reopen,release:async()=>{check((await tabStore?.run("release",{profile,owner:"session_b"})).success,"Tab B lease explicitly released");},verify})) {
  document.getElementById(name).onclick=async()=>{
    for(const button of document.querySelectorAll("button")) button.disabled=true;
    try {await callback();} catch(error) {say(`ERROR: ${error.stack || error}`);}
    finally {for(const button of document.querySelectorAll("button")) button.disabled=false;}
  };
}
