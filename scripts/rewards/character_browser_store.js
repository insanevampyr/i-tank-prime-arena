/* Storage transport only. Character authority/continuity is checked by the
 * GDScript coordinator. Documents are opaque canonical Contract V2 strings. */
(() => {
  "use strict";
  if (globalThis.ArenaCharacterBrowserStorage) return;
  const DB = "itank-prime-arena.character-profiles";
  const TEST_PREFIX = "itank-arena-test-36k-";
  const id = value => typeof value === "string" && /^[a-z0-9_-]{1,64}$/.test(value);
  const result = (state, reason, extra = {}) => ({success: state === "verified_committed", state, reason, ...extra});
  const problem = (reason, state = "recovery_required") => Object.assign(new Error(reason), {storageState: state});
  const failure = error => result(error.storageState || (error.name === "VersionError" ? "recovery_required" : error.name === "SecurityError" || error.name === "NotAllowedError" ? "unavailable" : "failed"), error.name === "VersionError" ? "unsupported_database_version" : error.message || error.name, {error_name: error.name || "Error"});
  const request = req => new Promise((resolve, reject) => { req.onsuccess = () => resolve(req.result); req.onerror = () => reject(req.error); });
  const completion = tx => new Promise((resolve, reject) => {tx.oncomplete = resolve; tx.onabort = () => reject(tx.error || problem("transaction_aborted", "failed")); tx.onerror = () => {};});

  class Store {
    constructor(options = {}) {
      if (options.database && !(options.testing === true && options.database.startsWith(TEST_PREFIX) && /^[a-z0-9-]+$/.test(options.database))) throw problem("invalid_test_database", "unavailable");
      this.database = options.database || DB;
      this.testing = options.testing === true && this.database.startsWith(TEST_PREFIX);
      this.unavailable = this.testing ? options.unavailable : null;
      this.leases = new Map();
      this.opening = null;
      this.closed = false;
    }
    async document(text, profile) {
      if (typeof text !== "string") throw problem("invalid_document");
      let outer, payload;
      try { outer = JSON.parse(text); payload = JSON.parse(outer.payload_json); } catch (_) { throw problem("corrupt_document"); }
      if (Object.keys(outer).sort().join(",") !== "format,payload_json,sha256,version" || outer.format !== "itank_arena_character" || outer.version !== 2) throw problem("unsupported_format_or_version");
      const digest = Array.from(new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(outer.payload_json))), n => n.toString(16).padStart(2, "0")).join("");
      if (digest !== outer.sha256) throw problem("checksum_mismatch");
      if (payload.character_id !== profile || !Number.isSafeInteger(payload.generation) || payload.generation < 1) throw problem("document_identity_mismatch");
      const ns = payload.profile_namespace;
      if (!["normal", "dev_normal"].includes(ns) || !profile.startsWith(ns === "normal" ? "prod_" : "dev_")) throw problem("namespace_mismatch");
      return payload;
    }
    async db() {
      if (this.closed) throw problem("store_closed", "unavailable");
      if (this.unavailable === "indexeddb" || !globalThis.indexedDB || !globalThis.isSecureContext || !globalThis.crypto?.subtle) throw problem("indexeddb_unavailable", "unavailable");
      if (!this.opening) this.opening = new Promise((resolve, reject) => {
        const req = indexedDB.open(this.database, 1);
        req.onupgradeneeded = () => {
          const db = req.result;
          db.createObjectStore("heads", {keyPath: "profile"});
          db.createObjectStore("generations", {keyPath: ["profile", "generation"]});
          db.createObjectStore("transactions", {keyPath: ["profile", "transaction_id"]});
        };
        let blocked = false;
        req.onsuccess = () => {if (blocked) {req.result.close(); return;} req.result.onversionchange = () => {req.result.close(); this.closed = true;}; resolve(req.result); };
        req.onerror = () => reject(req.error);
        req.onblocked = () => {blocked = true; reject(problem("database_upgrade_blocked", "unavailable"));};
      });
      return this.opening;
    }
    async acquire(profile, owner) {
      if (!id(profile) || !id(owner)) throw problem("invalid_identity", "failed");
      if (this.unavailable === "locks" || !navigator.locks?.request) throw problem("web_locks_unavailable", "unavailable");
      const prior = this.leases.get(profile);
      if (prior) return prior.owner === owner && prior.release ? result("verified_committed", "writer_lock_held", {owner}) : result("unavailable", "profile_in_use_or_acquiring");
      // Reserve before the asynchronous request so two calls cannot race locally.
      const lease = {owner, busy: 0, release: null};
      this.leases.set(profile, lease);
      return new Promise((resolve, reject) => {
        navigator.locks.request(`${this.database}:writer:${profile}`, {mode: "exclusive", ifAvailable: true}, lock => {
          if (!lock) {this.leases.delete(profile); resolve(result("unavailable", "profile_in_use")); return;}
          return new Promise(release => {lease.release = release; resolve(result("verified_committed", "writer_lock_acquired", {owner}));});
        }).catch(error => {this.leases.delete(profile); reject(error);});
      });
    }
    lease(profile, owner) {
      const lease = this.leases.get(profile);
      if (!lease || lease.owner !== owner || !lease.release) throw problem("writer_lock_required", "unavailable");
      return lease;
    }
    transfer(profile, owner, next_owner) {
      const lease = this.lease(profile, owner);
      if (!id(next_owner) || lease.busy) throw problem("writer_lock_busy_or_invalid_owner", "failed");
      lease.owner = next_owner;
      return result("verified_committed", "writer_lock_transferred", {owner: next_owner});
    }
    release(profile, owner) {
      const lease = this.lease(profile, owner);
      if (lease.busy) throw problem("writer_lock_busy", "failed");
      this.leases.delete(profile);
      lease.release();
      return result("verified_committed", "writer_lock_released");
    }
    async inspect(profile) {
      if (!id(profile)) throw problem("invalid_profile_identity", "failed");
      const db = await this.db();
      const tx = db.transaction(["heads", "generations", "transactions"], "readonly");
      const done = completion(tx);
      const range = IDBKeyRange.bound([profile, 0], [profile, Number.MAX_SAFE_INTEGER]);
      const [head, records, receipts] = await Promise.all([
        request(tx.objectStore("heads").get(profile)), request(tx.objectStore("generations").getAll(range)),
        request(tx.objectStore("transactions").getAll(IDBKeyRange.bound([profile, ""], [profile, "\uffff"]))), done
      ]);
      if (!head && !records.length && !receipts.length) return result("verified_committed", "profile_missing", {missing: true, generations: []});
      if (!head || records.length !== head.generation || receipts.length !== records.length) throw problem("incomplete_generation_history");
      const generations = [];
      for (let i = 0; i < records.length; i++) {
        const record = records[i];
        if (record.generation !== i + 1 || !id(record.transaction_id)) throw problem("generation_gap_or_invalid_transaction");
        const payload = await this.document(record.document, profile);
        if (payload.generation !== record.generation) throw problem("document_generation_mismatch");
        const receipt = receipts.find(r => r.transaction_id === record.transaction_id);
        if (!receipt || receipt.generation !== record.generation || receipt.document !== record.document || receipt.expected_generation !== i) throw problem("transaction_history_mismatch");
        generations.push({document: record.document, transaction_id: record.transaction_id, generation: record.generation});
      }
      const last = records.at(-1);
      if (last.generation !== head.generation || last.transaction_id !== head.transaction_id || last.document !== head.document) throw problem("current_pointer_mismatch");
      return result("verified_committed", "history_verified", {missing: false, generation: head.generation, transaction_id: head.transaction_id, document: head.document, generations});
    }
    async publish(args) {
      const {profile, owner, transaction_id, expected_generation, document, fault} = args;
      const lease = this.lease(profile, owner);
      if (!id(transaction_id) || !Number.isSafeInteger(expected_generation) || expected_generation < 0) throw problem("invalid_transaction", "failed");
      if (fault && !this.testing) throw problem("test_fault_forbidden", "failed");
      lease.busy++;
      try {
        const payload = await this.document(document, profile);
        if (payload.generation !== expected_generation + 1) throw problem("candidate_generation_mismatch", "failed");
        // Inspection is defense in depth. The compare below is IN the write transaction.
        const before = await this.inspect(profile);
        const prior = before.generations.find(r => r.transaction_id === transaction_id);
        if (prior) {
          if (prior.document !== document || prior.generation !== payload.generation) throw problem("transaction_payload_conflict", "failed");
          return result("verified_committed", "exact_retry_verified", {generation: prior.generation, transaction_id, document, latest_generation: before.generation, reconciled: true});
        }
        if (fault === "denied") throw new DOMException("permission_denied", "NotAllowedError");
        if (fault === "quota") throw new DOMException("quota_exhausted", "QuotaExceededError");
        // Disposable browser tests can hold an uncommitted operation while its
        // actual tab is reloaded/closed. Never enabled for a production database.
        if (fault === "pause_before_transaction") await new Promise(() => {});
        const db = await this.db();
        let tx;
        try {tx = db.transaction(["heads", "generations", "transactions"], "readwrite", {durability: "strict"});}
        catch (error) {if (!(error instanceof TypeError)) throw error; tx = db.transaction(["heads", "generations", "transactions"], "readwrite");}
        const done = completion(tx);
        let rejection = null;
        const read = tx.objectStore("heads").get(profile);
        read.onsuccess = () => {
          const actual = read.result ? read.result.generation : 0;
          if (actual !== expected_generation) {rejection = problem("stale_generation", "failed"); tx.abort(); return;}
          const record = {profile, generation: payload.generation, transaction_id, document};
          tx.objectStore("generations").add(record);
          tx.objectStore("transactions").add({...record, expected_generation});
          tx.objectStore("heads").put(record);
          if (fault === "abort") tx.abort();
        };
        try {await done;} catch (error) {throw rejection || error;}
        if (fault === "lost_ack") return result("recovery_required", "acknowledgement_lost");
        // A NEW transaction after oncomplete; no queued-operation acknowledgement.
        const after = await this.inspect(profile);
        if (fault === "readback_mismatch" || after.document !== document || after.transaction_id !== transaction_id || after.generation !== payload.generation) throw problem("readback_mismatch");
        return result("verified_committed", "publication_readback_verified", {generation: payload.generation, latest_generation: after.generation, transaction_id, document, strict_durability_requested: tx.durability === "strict", long_term_retention_guaranteed: false});
      } finally {lease.busy--;}
    }
    async reconcile(args) {
      const after = await this.inspect(args.profile);
      const prior = after.generations.find(r => r.transaction_id === args.transaction_id);
      if (!prior) return result("failed", "transaction_not_found");
      if (prior.document !== args.document || prior.generation !== args.expected_generation + 1) throw problem("transaction_payload_conflict");
      return result("verified_committed", "reconciled_readback_verified", {generation: prior.generation, latest_generation: after.generation, transaction_id: prior.transaction_id, document: prior.document, reconciled: true});
    }
    async run(operation, args = {}) {
      try {
        if (this.closed) throw problem("store_closed", "unavailable");
        if (operation === "acquire") return await this.acquire(args.profile, args.owner);
        if (operation === "release") return this.release(args.profile, args.owner);
        if (operation === "transfer") return this.transfer(args.profile, args.owner, args.next_owner);
        if (operation === "inspect") return await this.inspect(args.profile);
        if (operation === "publish") return await this.publish(args);
        if (operation === "reconcile") return await this.reconcile(args);
        return result("failed", "unknown_operation");
      } catch (error) {return failure(error);}
    }
    async close() {
      if ([...this.leases.values()].some(l => l.busy || !l.release)) return result("failed", "writer_lock_busy");
      for (const [profile, lease] of this.leases) this.release(profile, lease.owner);
      if (this.opening) {try {(await this.opening).close();} catch (_) { /* Reported by original request. */ }}
      this.closed = true;
      return result("verified_committed", "store_closed");
    }
  }
  // JSON-only bridge: no retained Godot callbacks, no busy waits, bounded jobs.
  const stores = new Map();
  let serial = 0;
  globalThis.ArenaCharacterBrowserStorage = {
    create(config) {try {const key = `store_${++serial}`; stores.set(key, {store: new Store(JSON.parse(config)), jobs: new Map(), active: new Set(), closing: false}); return key;} catch (_) {return "";}},
    request(key, operation, json) {
      const entry = stores.get(key);
      if (!entry || entry.closing || entry.jobs.size >= 32) return "";
      let args;
      try {args = JSON.parse(json);} catch (_) {return "";}
      const job = `job_${++serial}`;
      entry.jobs.set(job, result("pending", "operation_pending"));
      const pending = entry.store.run(operation, args);
      entry.active.add(pending);
      pending.then(value => {entry.jobs.set(job, value); entry.active.delete(pending);});
      return job;
    },
    poll(key, job) {
      const entry = stores.get(key);
      const value = entry?.jobs.get(job) || result("unavailable", "unknown_operation");
      if (value.state !== "pending") entry?.jobs.delete(job);
      return JSON.stringify(value);
    },
    dispose(key) {
      const entry = stores.get(key);
      if (!entry) return Promise.resolve(result("unavailable", "unknown_store"));
      if (entry.disposal) return entry.disposal;
      entry.closing = true;
      // Engine/session termination may occur before a publication finishes.
      // Drain already-authorized operations before releasing the native lease;
      // this is cleanup, never a gameplay save acknowledgement.
      entry.disposal = (async () => {
        await Promise.allSettled([...entry.active]);
        const status = await entry.store.close();
        if (status.success) stores.delete(key);
        else {entry.closing = false; entry.disposal = null;}
        return status;
      })();
      return entry.disposal;
    },
    // Harness uses the identical implementation, never production profiles/database.
    testStore(config) {if (!config.testing || !config.database?.startsWith(TEST_PREFIX)) throw problem("test_database_required"); return new Store(config);}
  };
})();
