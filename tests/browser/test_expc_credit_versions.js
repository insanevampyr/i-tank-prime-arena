"use strict";
// Exercise the production IndexedDB adapter's pure document gate, without a DB.
const fs = require("node:fs"), path = require("node:path"), vm = require("node:vm");
const {webcrypto} = require("node:crypto");
const assert = require("node:assert/strict");
const source = fs.readFileSync(path.join(__dirname,"../../scripts/rewards/character_browser_store.js"),"utf8");
const method = source.slice(source.indexOf("async document("), source.indexOf("async db()"));
const validator = vm.runInNewContext("({"+method+"})", {crypto:webcrypto,TextEncoder,problem:message=>Error(message)});
(async()=>{
 let count=0;
 for (const version of [2,4,5]) for (const policy of [false,true]) for (const credit of [false,true]) {
  const p={character_id:"dev_vaelis_thorn",profile_namespace:"dev_normal",generation:2};
  if(policy)p.run_reward_policy={}; if(credit)p.expc_credits={};
  const payload_json=JSON.stringify(p);
  const sha256=Buffer.from(await webcrypto.subtle.digest("SHA-256",new TextEncoder().encode(payload_json))).toString("hex");
  const document=JSON.stringify({format:"itank_arena_character",version,payload_json,sha256});
  const valid=version===5?credit:!credit&&(version===4)===policy;
  let accepted=true;try{await validator.document(document,"dev_vaelis_thorn");}catch{accepted=false;}
  assert.equal(accepted,valid,`version=${version}, policy=${policy}, credits=${credit}`);count++;
 }
 console.log(`PASS: Web V2/V4/V5 envelope gate: ${count} combinations; no IndexedDB accessed.`);
})().catch(e=>{console.error(e);process.exitCode=1;});
