# Task 45O - Compact V6 production integration audit and activation plan

2026-11-17. **Audit complete; activation blocked pending the implementation and approval gates below.** This document is the only project change in 45O. No Pass E implementation, owner-character access/conversion, database upgrade, runtime test or export occurred.

Inspected baseline: `main`, HEAD `f9bb0db0235b0003895c477a12346191d4714469`, plus preserved uncommitted 45B-45N work. HEAD alone does not describe this working tree.

## 1. Evidence and scope

- **V - verified now:** actual source, Git metadata, disposable result files and retained temporary release-harness artifact inspected during this audit.
- **R - recorded earlier:** Codex-reported tests/timings from 45K-45N. The 45N JSON/PCK were checked now, but their tests were not rerun.
- **P - proposed:** future design, not implemented or authorized here.
- **U - unresolved:** needs measurement, proof or an owner decision.

Reviewed all five requested 45J-45N documents and actual production/prototype code. Source controls this map, rather than stale comments: CharacterBrowserStorage is used by playable browser persistence; the fixed credit has a separate confirmation UI despite older module comments.

Version distinctions (V): production character envelopes V2/V4/V5; foundation V1 also exists, and dormant Profile V3 is separate. Compact outer envelope V6 currently contains `itank_arena_compact_character_pass_a` / `compact_version:1`. Portable files use `itank_arena_compact_portable` / version 1. Production IndexedDB is schema 1; simulation snapshots remain schema 12 (`combat_simulation.gd:3652`). These numbers are not interchangeable.

45J's paging, sequence-zero baseline, five new browser stores, reverse converter and DB upgrade were proposals. 45K-45N instead implement flat evidence, sequence-one conversion baselines, disposable storage and framed backups. 45L supersedes 45K's early late-credit extraction limitation; 45N adds exact recovery absent in 45M. None supplies production activation.

## 2. Production call-path inventory (V)

Paths below are repository-relative. Line numbers identify inspected entry points.

| Operation | Actual components and invariant | V6 disposition (P) |
|---|---|---|
| Identity/source | `playable_character_admission.gd:73 profile_identity()` selects `prod_vaelis_thorn` / `normal` or `dev_vaelis_thorn` / `dev_normal`. `prepare_starter():79` checks exact allowlisted historical source and separately verified runtime Balance provenance. Controller `_profile_namespace`, `_open_legacy_profile():1279`, `_admit_existing_profile():1294` capture target explicitly. | Reuse. DEV visibility and XP multiplier never choose storage identity. Existing-only Legacy DEV access must not create a starter. |
| Desktop admission | Controller `_prepare_encounter_fixture():1132` -> `_prepare_encounter_candidate():1162` -> session `prepare_playable_persistence():815` -> service `open():50` -> `CharacterSaveStorage.inspect_profile():83` -> `open_verified_history():66`. Complete chain, source, END witnesses, receipts and ownership precede hydration. | Add format/route dispatch and a compact verified-head branch. Never fake a one-row legacy history for consumers requiring generations 1..G. |
| Web admission | Controller `_begin_browser_load():1437` captures target/policy -> `PlayableBrowserPersistence.open_browser():23` -> acquire/inspect -> `CharacterBrowserStorage.inspection():53` -> shared `open_verified_history()`. Missing-character creation confirmation differs from existing-only access. | Retain request identity, lease transfer, failed/canceled/pending states and stale-callback isolation; return versioned compact results. |
| State application | Session `finalize_playable_persistence():873` -> service `bind_runtime():240`, `apply_player():191`, `restore_ledger():223`. Restores resources, items/condition/hands, growth, credits, Mana remainder, RNG, clock, movement, timers and loot without awarding history again. | Reuse via a verified compact view. Preserve historical validation source versus runtime skill source. |
| Automatic saves | Session `_checkpoint_character():909` -> service `checkpoint():446` -> `ingest():345`, `Profiles.project():17`, `_capture():553` -> coordinator prepare/publish -> `_ack():540`. Safe phases: entry/downtime/complete. Unchanged boundaries avoid another generation. | Preserve boundaries, mutation guards and no-op detection. No new every-frame save or arbitrary mid-combat resume. |
| XP/purchases/items | ArenaRewardLedger applies locked reward policy and deduplication. Session advancement/equipment/consumable methods use existing rules. Service `ingest():345` captures resolved proofs; `checkpoint():462` validates awards/purchases/growth and durable IDs. Acquisition, consumption and shield condition have independent evidence. | Reuse prices, growth, receipts and ownership. Capture ordered new facts at ingestion, rather than infer causality from final totals. |
| Desktop coordinator | `CharacterPersistenceCoordinator.prepare():14`, `commit():27`, `_authorize():76`, `_find_transaction():92`: trusted verifier, exact proposal, source hydration, expected generation/checkpoints, continuity/items, write, exact readback/reconcile. | Extend this authority with compact prepared requests/head tokens. V6.validate is not a replacement for mutation authorization. |
| Browser coordinator | `CharacterBrowserPersistence.begin_commit():21` reuses desktop `_authorize`; `poll():33` inspects/reconciles, checks continuity/items and publishes. PlayableBrowserPersistence acknowledges through shared `_ack`. | Preserve single-flight, retained exact requests, lease ownership and acknowledgement checks. No second wallet/coordinator. |
| Windows storage | `CharacterSaveStorage.DEFAULT_ROOT = user://character_documents`; `write_profile():56` / `_write_locked():128` use writer guards, stage/flush/readback `write.pending`, rename a new generation and verify it. `inspect_profile()` checks all generations/bundles, gaps, conflicts and pending state. | Add compact routing under the same profile authority; activated profiles stop appending complete legacy generations. |
| Edge storage | `character_browser_store.js:6,38`: DB `itank-prime-arena.character-profiles`, schema 1, stores `heads`, `generations`, `transactions`. Full document is repeated in these records. `acquire():56` uses a profile Web Lock; `publish():115` uses transactional head comparison and fresh readback. | Reuse DB name/locks/CAS, add compact routes/stores only through a separately approved upgrade. |
| Existing Web history work | JS `inspect():89` gets all generations and transaction receipts and verifies each; Godot `CharacterBrowserStorage.inspection():53` decodes again; admission rechecks history/source. Publication/reconciliation inspect again. | Compact operations must bypass full legacy archive inspection, rather than only change the encoded envelope. |
| SAVE CHARACTER | Actions `_on_action():181` -> Reader `begin_export():26` -> storage inspect -> Task history validation -> BackupContract `_encode_checked():35`. Reader binds exported head/transaction to acknowledged `_prior`. | Preserve eligibility/head binding; dispatch to compact portable preparation, not legacy archive construction. |
| SAVE FILE | Actions `_on_action():153` checks current admission/generation; Web downloads prepared text. Desktop `_file_selected():264` -> Files `save_new_file():63` stages/verifies/renames without overwriting or targeting profile storage. | Transfer the bound artifact; use epoch/head/hash rather than generation alone. No hidden semantic replay just to download identical bytes. |
| SELECT SAVE FILE / preview | Web Files `choose()` / desktop `read_file():50` enforce UTF-8/bounds -> Actions `preview_text():279` -> Reader `begin_preview():43` -> Task full incoming decode/proof -> read-only destination comparison. Legacy DEV preview works with absent local profile. | Bounded content-based format dispatch, full imported proof, explicit target and no writes. Current single-JSON legacy decoder cannot parse V6 line framing. |
| Confirmed restore | `CharacterBackupRestoration.begin():23`, `confirm():58`, `poll():69`, `_verified():100` bind exact input, hold/reuse writer, reread destination, publish eligible prefix and verify exact bytes, then hand off admission. | Reuse confirmation/uncertainty/lease protocol; replace raw history-array comparison with compact ancestry. Preserve legacy branch for legacy profiles. |
| Physical restoration | Desktop `restore_history():209` publishes a restoration bundle. Web JS `restore():160` appends missing history in one IDB transaction. Both require exact existing prefix. | Never store portable V6 as a legacy generation or replace newer compact authority with an older bundle. |
| NEXT WAVE | Session `_enter_between_wave_downtime():2316` secures completion; `_advance_from_between_wave_downtime():2349` secures old progress and next entry. Web `BrowserWaveCandidate.prepare():6` and controller adoption isolate candidate RNG/events until publication. | Preserve both boundaries, including immediate NEXT WAVE after a purchase. |
| RESUME / RETRY / NEW / RETURN | Controller `_resume_loaded_run():1347` rechecks desktop head. `_on_encounter_button_pressed():864` reloads verified entry after defeat or starts a new run after completion. `_confirm_abandon_loaded_run():1396` consumes an explicit head-bound decision. `_on_return_to_wave_one_pressed():1101` uses session authorization. Service preserves committed history and binds new run/policy/first entry together. | Preserve actual current semantics. Technical previous state never authorizes refunding committed rewards, credits or purchases. Reconcile uncertain publication before another mutation. |
| Fixed EXPC grant | `character_expc_grant.gd begin/confirm/_publish/_published():26,85,104,117` and UI Actions provide explicit confirmation. `CharacterExpcCredit.prepare():37` binds fixed grant ID/amount/profile to exact legacy predecessor generation/hash. | Preserve original credits; resolve the post-conversion grant blocker below. Never automatic or unrestricted credit. |
| Sheet / TEST / foundation | Character Sheet reads live actor/progression; TEST fixtures remain nonpersistent/zero rewards. CharacterPersistenceSession is an older host-bound foundation seam, not another active writer to install beside playable persistence. | Display must not revalidate/write an archive. Keep DEV/TEST/profile policies independent from format routing. |

Important distinction: desktop `read_profile():26` can return a diagnostic previous legacy generation after corruption, but playable admission uses strict `inspect_profile()` and rejects the broken chain. Do not import that fallback into V6 or report it as a newly reproduced playable defect. Dormant DEAD/Profile-V3 contracts remain unrelated and inactive.

## 3. Dormant V6 integration map (V/P)

| Component | Actual scope and required adaptation |
|---|---|
| `compact_character_v6_prototype.gd:30,38,55,156` | Canonical codec and full semantic/continuity proof. Reuse rule validators; it supplies no live mutation authority. Finalize production inner format/version before activation. |
| `_chronology():252`, `_historical_credit_basis():193` | Explicit chronology, original growth and predecessor proof. Preserve creation HPM, original dice, HPB plateaus, event-time WIS and unchanged immediate END HPM/HPC. |
| `legacy_to_compact_v6_prototype.gd Conversion` | In-memory V2/V4/V5 conversion; creation prefix/playable checkpoint required, 4,096-generation/256 MiB raw input and per-document bounds. Add bounded production source reading under writer ownership, not manual backup's 32 MiB budget. |
| `compact_v6_equivalence.gd:7 compare()` | Independent entire legacy projection, hydrated actor, END witnesses and lifetime identities. Mandatory conversion/readback gate; confirmation of totals cannot substitute for it. |
| Native disposable adapters | `tests/compact_v6_disposable_store.gd` / `compact_v6_backup_store.gd`: cache-only roots, staged publication, exact repair/capsule. Extract reviewed algorithms into production; do not remove test isolation guards or expose fault injection live. |
| Browser disposable adapters | `tests/browser/compact_v6_store.js` / `compact_v6_backup_store.js`: separate test DB, schema 1, CAS/readback. They lack production Web Lock ownership/handoff and do not prove a production schema upgrade or old-writer fence. |
| Portable codec | `tests/compact_v6_portable_backup.gd:96,112,144`: current record + reversible transitions + footer, full proof/ancestry. Promote one shared implementation; bounded parser is not yet fully streaming. |
| Recovery | Capsule can recover exact acknowledged bytes with intact head; previous alone cannot. Missing head or all exact evidence fails closed. Preserve this guarantee and diagnostics. |

Lifetime operations, semantic IDs, receipts and consumed-item origins remain exact and growing. The recent 20-entry journal is not duplicate-prevention authority. No truncated hashes, approximate membership or balance-only replacement.

## 4. Explicit activation blockers

### B1 - Live V6 candidate builder (V/P)

`assemble():23` is a supplied-facts fixture builder. Storage tests append no-op transport/preference updates. The legacy converter rejects mixed purchase/award/growth ambiguity (`legacy_to_compact_v6_prototype.gd:188-210`). No production builder captures new ordered gameplay facts into a compact candidate. Existing proof maps are not a global chronology.

**Recommended solution:** a shared compact adapter at `ingest()` / `checkpoint()` / existing coordinator seams. Capture new original facts from the ordered resolved-event cursor, retaining causal event, parent, request, award, purchase, growth, item and run IDs. Prepare one immutable typed batch bound to its exact parent head/request. Do not sort IDs or infer chronology from totals. Retry retains the same batch and never replays historical effects into the actor.

Keep the coordinator's trusted verifier, authoritative event/ownership checks, receipt validation and exact readback. V6.validate proves consistency, not that a player earned an award. A checksum, `success:true`, generic JSON delta or well-formed request_digest must not authorize a mutation.

Exit tests: real new awards/growth, all five supported attribute purchases, interleaved END/WIS growth, development, item acquisition/consumption/equipment/condition, source-qualified resources, new run/policy, real multi-effect checkpoints, duplicates/stale requests and unchanged simulation RNG/history/two-client convergence. Missing order/authority rejects without publication.

### B2 - New post-conversion EXPC credits (V/P)

`validate_extension():170` requires existing credit and predecessor evidence to remain equal: adding a grant after conversion is rejected. `_historical_credit_basis():193-220` reconstructs legacy-document prefixes, not an arbitrary native compact predecessor. The grant UI/coordinator still expects full legacy history and generation-bound Credit.prepare(). Existing historical credits are supported; new V6 credit publication is not.

**Recommended solution:** a dedicated typed fixed-grant transition with a portable, source-backed predecessor witness. Preserve the same unique grant ID, +10,000 EXPC/+0 EXPM, exact eligible DEV profile/baseline, explicit confirmation and exactly-once receipt. Bind to known compact parent `(profile,namespace,epoch,sequence,digest)`. Reconstruct predecessor/order/accounting from retained evidence and transitions; never fabricate legacy document hashes. Explicitly version any changed evidence shape; merely relaxing credit equality is unsafe.

Test first native credit after purchases/growth, conversion before/after a historical grant, unchanged EXPM, wrong/forged/stale requests, duplicate grant wrapped in a new operation, lost acknowledgement/reload/NEW RUN/backup restore. Until proved, show an explicit unsupported operation, not an actionable confirmation that cannot commit. Owner may separately confirm the legacy grant before conversion; this audit assumes neither its live status nor permission to grant it. That ordering workaround does not solve the general integration gap.

## 5. Evidence-backed performance investigation

### Measurements (R, artifacts checked V)

45N's largest fixture is a converted 1,000-operation baseline with two compact updates: 1,002 operations, 1,447 lifetime bindings, 560,083 portable bytes. It is neither 1,000 native compact transitions nor the owner's character. Individual recorded samples:

| Metric | Native Godot editor/debug | Actual Edge release WASM |
|---|---:|---:|
| Routine update / load | 4.147 / 1.409 s | 4.491 / 1.119 s |
| Export / preview | 3.410 / 1.078 s | 2.026 / 0.833 s |
| Restore + uncertain-ack retry/readback | 8.978 s | 4.758 s |
| Exact recovery | 2.819 s | 2.187 s |

The same Edge run's simpler Pass C 1,000-operation update was 1.118 s, load 0.274 s and readback 0.231 s. It lacks Pass D capsule/ancestry work and has one instead of two compact updates. This is a useful control, not a controlled causal A/B or proof that a particular function costs the difference.

**Timing boundary (V):** native save_ms starts inside `_publish_locked()` after writer acquisition; input Fixtures.next()/V6.encode() runs before it. Browser nextText() construction/encoding also precedes publish()'s timer. These are not full user-click-to-secured-state production timings. The browser first lost-ack restore returns before readback; its retry/readback total is the completed restore measurement.

Checked the prior disposable results under `C:/Users/mxz/AppData/Local/itank-storage-tests/compact45m_45n_session_20261117e/`. The five inspected core/portable/browser sources match retained release-harness sources byte-for-byte. Its test-only PCK hashes to `ef31ce5b7e6ab5db4b715ada2e7ab7af98bc9a3ccf8b2ef713e1ce4b625de4bd`. The earlier 136 native / 814 core / 62 storage / 61 Edge checks were not rerun in 45O.

### Structural bottlenecks versus unmeasured attribution

| Finding | Evidence / confidence | Safe optimization (P) |
|---|---|---|
| Repeated full replay | Native N `_publish_locked():39` decodes incoming, loads current record AND capsule, validates extension, exports/verifies next capsule, stages/decodes record, then fully reads/validates current/capsule again. Portable history steps call validate_extension(), which fully validates both endpoints. **V repetition; exclusive milliseconds U.** | Check immutable predecessor/candidate once per operation; reuse only after exact byte/hash/source/head binding. Retain full cold/import proof and mandatory persisted readback. |
| Work amplification | A normal second compact update with one prior transition has at least **7 V6.decode / 19 V6.validate** entries natively; Web has at least **9 decode / 25 validate** entries through the current harness. Counts exclude recursive credit-prefix and underlying contract/hydration work. **V static counts, not profiler timings.** | Instrument first, then prove a shared checked representation removes duplicate work without changing accept/reject results. |
| Nested membership searches | `V6.validate_extension():173-176` falls back to candidate.applied_ids.has(row) for each old row. IDs are grouped by scope; appending an operation shifts following groups, usually defeating prefix comparison. Coordinator `_validate_continuity():164-165` likewise scans settlements repeatedly. **V structure; worst-case quadratic membership work.** | Operation-scoped maps keyed by exact canonical `(scope,id)` with complete binding comparison. Preserve duplicate rejection and required order; no approximate or unauthoritative index. |
| Reconstructed evidence/actors | `_projection():181` deep-copies current/lifetime arrays; `_ids():231` rehashes every row; `_chronology():252` instantiates/replays an actor; validate():151 hydrates again. Historical credit recursively validates a predecessor. **V.** | Reuse immutable projection, exact ID map, accounting and historical witness within the operation. Never replace event-time HPB/WIS or credit proof with current totals. |
| Repeated parse/canonical/hash | digest():18 serializes before hashing; encode/decode canonicalize again. Portable decode parses every frame and V6.decode reparses its current envelope. Web base load hashes before checked() hashes the same text; capsule checks hash it again. **V; fraction of latency U.** | Carry privately owned canonical bytes/digests with explicit inner/outer/capsule domains; shared parse/scan boundary. Changed bytes always invalidate reuse. |
| Browser reads/bridge | A successful N update performs six snapshot() reads of all 2-3 compact blobs plus transactional current-byte read. Seven verifier/proof callbacks cross the JSON bridge with full text/dictionaries/history. Harness `_portable_request():73` encodes previous text even for ordinary capsule checks. **V counts; timed attribution U.** | One coherent head/current read, transactional CAS, targeted fresh readback. Keep semantic objects in Godot; exchange compact metadata. Return full export/previous bytes only when needed. |
| Copies / blocking | Delta application duplicates full records and changes. Results can simultaneously contain current text/Dictionary, previous record/encoded text, history and portable file. Native writes reread strings. Proof callbacks are synchronous. **V allocation paths; exact peak ownership U.** | Bounded operation ownership, release terminal/canceled buffers and divide expensive proof into bounded scheduler steps. MessageChannel alone cannot make one long synchronous step responsive. |
| Storage/ack overhead | Flush, rename, SHA, IDB structured cloning/strict transaction, CAS and readback occur. No exclusive per-stage I/O/bridge/hash/allocation profile was captured. **V operations; dominant cost U.** | Measure each stage; do not remove flush, ownership, CAS, candidate validation or exact acknowledgement for speed. |

For these static counts, L is prior compact-transition count: native direct validate entries are `13+6L`; Web entries are `18+6L+(1 if L>0 else 0)`, excluding recursive credit/underlying validators. These counts follow the inspected normal success path, not restore/retry branches. They expose ancestry amplification, not precise wall-time attribution.

R memory readings: native allocator peak 266.15 MiB/process peak working set 364.16 MiB including preloaded suites; Edge WASM capacity 115 MiB; JS used heap 66.83 -> 7.83 MiB after diagnostic GC; largest owned renderer peak 561.97 MiB/end 294.60 MiB. They establish neither a leak nor its absence, and do not certify the owner's 2 GB playable tab. No owner browser was inspected in 45O.

### Optimization order and integrity obligations (P)

1. Instrument the complete operation, including caller preparation/encoding, validation/replay, hash/canonicalization, bridge bytes/calls, I/O/transaction, readback, event-loop stalls and memory. Reuse identical disposable fixtures and record artifact hashes.
2. Replace repeated exact membership scans with equivalent scoped maps. This is the smallest algorithmic optimization; test conflicting bindings, duplicate scopes/IDs, IDs older than journal20 and unchanged canonical bytes/order.
3. Introduce **operation-scoped immutable checked representations**, bound to source/rules, identity, parent head, exact canonical candidate bytes/digests and evidence. No mutable Dictionary alias, global boolean cache or imported verified flag. Changed source/head/text/record metadata invalidates reuse; cold load and imported evidence always receive full independent validation.
4. Eliminate duplicate candidate/ancestry replay within one save. Read back actual persisted bytes/head and compare them to the fully checked candidate, rather than replay identical semantics again. Check every referenced object/digest; cold restart validates persisted evidence anew. Keep full validation as a test oracle.
5. Reduce bridge payloads/getAll snapshots, unused previous-text encoding and temporary copies; retain existing background work, single-flight and cancellation guards. Do not use production GC or skipped readback as a fix.
6. Measure before considering pages/index trees/compression. Flat lifetime proof remains O(N), and long ancestry may still need a separately approved proof/retention design. Never prune IDs/deltas, raise limits or rebuild full-generation archives to hide a miss.

Targets remain goals: routine save/load ideally 1-3 s, export/preview <5 s, restore <10 s. Require repeatable p50/p95/max, foreground/background responsiveness and declared hardware/workloads in Windows release and playable Edge release. Existing samples miss some routine-save targets. No speedup or production memory acceptance is claimed by this audit.

## 6. Shared adapter and production boundaries (P)

Propose one shared `scripts/rewards/compact_character_adapter.gd` (name provisional) for format-specific projection, proof, ordered live preparation, exact membership and portable operations. Both playable facades use it through the existing coordinator. Extract reusable pure prototype logic once; production must not import tests/ or duplicate game rules in JS.

A versioned prepared operation binds identity/namespace/source/rules, expected `(format,epoch,sequence,digest)`, operation ID/request binding, authorized original facts/order, candidate bytes and recovery references. Keep it immutable/single-flight. Exact retry inspects first and uses the same operation ID. Reconciliation does not reapply effects to an actor.

Legacy current.generation remains validated provenance where needed by the compatibility projection; it is not compact sequence. A 233-generation conversion starts compact sequence 1. Do not invent generation documents or hash reformatted projections as original legacy bytes. Add format-aware acknowledgement/head tokens rather than weakening old generation checks.

Initially preserve the complete checkpoint/schema-12 runtime ledger, even its duplicated lifetime facts. Materialize the legacy-compatible view once from verified compact evidence. Stripping runtime ledger fields or changing replay hashes is a separate authority change. Preserve HP/Mana, WIS remainder, END Running/fatigue/cooldowns, single equipment application, action timing, RNG and legitimate temporary-effect timing.

### Desktop publication and old-writer exclusion

Adapt CharacterSaveStorage with versioned route methods under the existing root/profile writer. Stage immutable current/previous/capsule data, verify it, then replace one route/head manifest. Bind capsule integrity explicitly in that head as well as exact state digest. Distinguish technical previous from gameplay checkpoint; damaged compact routing never falls back to legacy generations.

A route file alone cannot fence an old client that ignores it. Under exclusive ownership, stage verified activation intent/data, stage/verify and atomically rename an exactly specified unsupported-version technical fence that tested old readers/writers reject, then publish the compact route. Do not edit original generations or disguise a fence as a gameplay reward. An unsupported storage wrapper could use old `_read_generation():277` fail-closed behavior; filename/placement and read/inspect/restore interactions must be proved in disposable tests first. **This protocol is proposed, not demonstrated by 45M/45N.**

Crash after fence/before route must leave a recoverable activation intent or a clear block. Complete/reconcile the same activation; never silently remove the fence and resume old authority. Existing production stale locks fail closed. Any dead-owner recovery must prove ownership/process lifetime and avoid stealing a live writer; do not promote PID-only or timeout assumptions.

### Browser publication and upgrade

Recommend the same production DB name with a separately approved additive **schema 2** upgrade. Keep original heads/generations/transactions untouched. Two added stores can suffice initially, rather than 45J's proposed five:

- `profile_routes`: explicit profile/namespace, active format/epoch/head, previous/capsule references, activation/source binding, minimum reader and recovery intent.
- `compact_blobs`: profile/epoch/kind/content-digest qualified immutable objects. Retain referenced current/previous/capsule; lifetime operations/IDs stay in validated compact proof, not a second wallet/index authority.

Publish data plus route/head in one IDB transaction under the existing profile Web Lock, CAS complete expected route/head and exact bytes, then verify through fresh readback. Asynchronous proof/crypto stays outside the live transaction. Preserve busy/release/transfer and quota/abort/unsupported-version handling.

Upgrade creates empty stores, not converted characters. It affects both namespaces for that origin. Old clients explicitly open schema 1 and should receive VersionError after upgrade; old connections must close on versionchange. Test blocked upgrades, old held Web Locks, in-flight writes, multiple tabs and stale callbacks. Do not steal leases or clear/rename the DB to finish an upgrade. Production upgrade requires separate approval.

### Portable backup, restore and exact recovery

Add format dispatch to existing BackupReader/Task/Restoration and Files/Actions, retaining the legacy branch. Choose a clear V6 extension/MIME and support both filters; actual content selects validation. Preserve UTF-8/depth/token/size guards with separate explicit bounds. SAVE FILE transfers the already-bound artifact after a current-head check, not another full replay. Preview/restore validate complete incoming proof and target; changed text, metadata or bytes invalidates any handoff.

Keep Pass D capsule redundancy initially: two compact records plus a current capsule. Largest tested footprint: 1,646,377 bytes, including a 560,083-byte capsule and 14,465-byte two-transition ancestry. Optimize repeated proof before changing recovery guarantees.

Recovery reconstructs only the exact acknowledged head. Missing authority metadata, or current plus all exact recovery evidence, remains unrecoverable/diagnostic; previous alone is not a refund. Flush/readback/strict IDB requests do not prove every power-loss case or exclude total storage-image rollback.

Restore: exact installed bytes -> no-op; newer same-lineage descendant -> proven ancestry; older / same-sequence conflict / unrelated epoch / unknown staged storage -> reject. Independent reconversion of a later legacy archive can create another epoch; do not relabel it. A legacy backup never overwrites active compact authority. Cross-format import requires explicit verified conversion/activation, not a larger-XP or generation shortcut.

## 7. Existing character strategy and rollback (P/U)

| Option | Benefit | Safety and cost |
|---|---|---|
| Explicit verified conversion | Best practical preservation of Legacy DEV Vaelis. 45L supports mapped V2/V4/V5 sources, original progression, late credit and exact independent comparison. | Actual owner history has not been read/proved convertible. Missing prefix, ambiguity, unknown source, limits or concurrent change stops conversion. One-time cost is not routine latency. |
| Preserve legacy archive + fresh V6 | Simple fallback when proof fails; avoids indefinite compatibility engineering. | Keep old data untouched/read-only. Fresh means no copied XP/items/credit. Requires a distinct explicit profile ID/slot while old identity is occupied; current fixed profile_identity() offers no such registry. No namespace/epoch trick may silently reset the old character. |
| Explicit selected fresh start | Useful for new empty slots and deliberate development resets. | Missing/corrupt/unavailable history is never proof of empty storage. Existing-only legacy access still must not create starters. Selection/identity/route policy requires approval/tests. |

**Recommendation:** one bounded, cancellable, independently verified conversion attempt after separate authorization. If proof fails, preserve all original data and offer a separately named/selected fresh V6 slot instead of inventing evidence or adding endless compatibility exceptions. Never merge NORMAL/DEV. Truly empty new profiles can create V6 directly at the first authorized Wave 1 boundary, atomically binding run ID, policy and checkpoint without a throwaway V2 write.

Do not require a legacy manual export to succeed when the valid archive exceeds its 32 MiB transport cap. Preserve complete original storage; after successful conversion, create and independently verify a portable V6 baseline before activation. If a separate raw legacy archive is required, explicitly design a bounded read-only archive path; incomplete/over-limit export is not a verified backup. Failed conversion plus fresh start never deletes or overwrites the old data.

After activation, software rollback uses a known-good **compact-capable recovery build**, reading the latest acknowledged state. Reopening the legacy conversion baseline after new compact progress loses purchases/rewards/credits. Do not promise a reverse converter or an unmodified old writer; schema 2 cannot be downgraded in place by schema-1 software. This recovery-only rollback policy needs owner approval. Legacy data need not remain playable forever; retention/deletion is a separate decision.

Before publication, discard only unpublished candidates; prior authority remains intact unless a fence was published. After any possible route publication, freeze mutations and reconcile the exact activation/head. Uncertainty never permits automatic reset, old-checkpoint fallback or a new operation ID.

## 8. Small, independently testable passes (P)

These future scopes are not authorized by this plan. Each has dependencies, tests and a stop/rollback gate.

| Stage | Scope / files | Dependencies and exit evidence | Stop / rollback condition |
|---|---|---|---|
| S1 - isolated performance foundation | Instrument K/M/N; scoped exact-ID maps and checked representation in compact core. No production routing. | Existing K-N oracle; identical bytes/acceptance, forged/evicted/rebound IDs, full caller preparation timed; 1k/10k IDs, 100/500+ native transitions and high-award/inventory fixtures; native/release Edge stalls/memory/timings. | Weaker validation, mutation or unexplained target miss -> keep existing behavior; no activation. Smallest next pass. |
| S2 - shared adapter/live facts, dormant | Proposed compact adapter; PlayableCharacterPersistence.ingest/checkpoint, Profiles and coordinator seams; promote pure portable codec once. | S1; real event-ordered batches for every mutation family; fresh V6 creation; interleaved END/WIS, exact source/runtime actor and checkpoint/resource equivalence; run/identity and replay proof. | Missing chronology/authority/ownership or changed combat/RNG -> reject candidate; legacy remains live. Resolves B1 before any live writes. |
| S3 - fixed-credit proof, dormant | Compact typed credit/witness and existing Credit/Grant/coordinator adapters. | S2; original grant unchanged, new native credit after growth/purchases, EXPM unchanged, duplicate/new wrapper, stale/forged confirmation, lost ack/reload/portable restore. | Cannot prove predecessor/exactly-once grant -> block that operation and activation for affected profiles until explicitly resolved. B2 remains a blocker. |
| S4 - production-shaped Windows adapter in disposable roots | CharacterSaveStorage routing/leases, coordinator compact head/ack and fixture wrappers. | S2/S3; tested old-writer fence; interruption across staging/fence/route/ack; active/stale owner, disk/space faults, exact current/damaged metadata recovery and no overwrite. | Old writer can publish, head lost or previous used as current -> block. Before fence preserve old authority; after fence reconcile or fail closed. |
| S5 - production-shaped Web upgrade in separate DB | BrowserStorage/Store/BrowserPersistence; additive stores and existing Web Lock protocol. Not the production DB. | S4-equivalent semantics; actual release Edge, disposable schema-1 -> schema-2 with original bytes intact; old/stale tabs, blocked/versionchange, ownership transfer, quota/abort/lost ack/reload/cancel. | Partial route, lock theft, old writer or lost acknowledged progress -> no live upgrade. No clearing/renaming DB workaround. |
| S6 - portable workflow, feature off | BackupReader/Task/Restoration, Files/Actions and shared codec. | S4/S5; actual file input/download; no-write preview, cross-format policies, changed file after preview, older/descendant/empty/exact/conflicting restores, cancellation/uncertainty, responsive background work. | Corrupt/older data publishes, overlapping mutation or incomplete file accepted -> feature stays off. Possible publication reconciles; no undo/refund. |
| S7 - dormant game compatibility/release gate | Playable/browser facade, BrowserWaveCandidate, controller profile/run choices and Character Sheet; retain schema-12 ledger. | Prior stages; new/convert/reload/RESUME/NEW/RETURN/RETRY/NEXT; resources, Mana remainder, Running, armor/Balance and purchases/credits; TEST suppression, identical RNG/history/two-client results. Focused checks then justified full checkpoint and actual Windows/Web release acceptance. | Any progression/resource/replay/namespace mismatch or unexplained performance failure -> feature remains off. No combat-rule change to hide it. |
| S8 - dry conversion/fresh selection | Converter + independent verifier, bounded reader, staged activation report. Separate owner action. | S4-S7, compatible recovery build, locked source unchanged, exact projection/evidence equality and full portable baseline readback; sufficient space and explicit identity. Actual owner access needs separate authorization. | Unsupported/changing/ambiguous source, no valid baseline backup or insufficient space -> preserve source and stop; never automatic fresh reset. |
| S9 - controlled activation/owner acceptance | Approved per-profile route/fence and DB upgrade. No blanket auto-migration. | Owner approves versions/rollback/identity; confirms immutable source/target; atomic/recoverable route publication and exact readback. Start with one profile, correct BUILD/PCK/source, load/purchase/reload/backup/run acceptance, then expand. | Before publication preserve prior authority; after possible publication reconcile/compact recovery. Never use an incompatible old writer/baseline as fallback. |

Existing tests to preserve/extend: compact K/L/M/N suites and actual Edge harness; persistence coordinator/playable desktop/browser suites; loaded-run selection, run reward save contract, EXPC credit/grant delivery; backup/restoration/responsiveness and 45E integrity; historical admission; permanent STR/DEX/SPD/WIS/END; END HPB and WIS Mana replay; 45D Mana/DEX/Experience. This is a future matrix, not a claim these ran in 45O.

## 9. Remaining decisions and hard stops

- Approve production inner/container versions, extension and schema-2/minimum-reader policy. Prototypes do not silently become production contracts.
- Approve compact-capable-only rollback; universal legacy reverse conversion is unproved and not recommended for initial delivery.
- Choose a fresh-profile identity/selection policy when the original slot is occupied. No implicit namespace switch, overwrite or merge.
- Resolve B1 and B2. The owner's actual credited status and convertibility remain unknown here.
- Define supported hardware/workloads and lifetime/ancestry growth policy. Current finite guards (4,096 transitions, 16 MiB core/ancestry, 34 MiB portable) do not authorize pruning legitimate evidence.
- Gate on actual Windows release, playable Edge stalls/memory, long native lineages, quota/disk-full, old-writer/upgrade and crash recovery. Fault injection is not power-loss proof.
- Missing acknowledged head or exact recovery evidence never authorizes older progression. Local unsigned hashes cannot exclude replacement of the entire storage image; explain the limit rather than add a fake trust flag.
- Future authoritative PvE co-op can feed owner/session/beneficiary-qualified outcome batches through the same coordinator, with semantic deduplication and per-profile acknowledgement. No networking, PvP, signature system or distributed multi-profile atomicity is introduced. Local Web Locks are not network authority.

## 10. Git/workspace audit and preservation

Repository inspected: `C:/Users/mxz/Desktop/Projects/ITank Prime/Video Game/ITank Arena/i-tank-prime-arena`.

- Branch `main`; HEAD `f9bb0db0235b0003895c477a12346191d4714469`. Index empty; no staged changes.
- Start: 28 modified tracked files, 61 untracked entries. End: 28 modified tracked files, 62 untracked entries, including the three protected entries and this new plan. Exact status follows.
- All **86 existing nonprotected pending files** retain their start-of-audit SHA-256; no prior file is missing. Only this document was added. No source/test/config modification.
- `project.godot` stays SHA-256 `8398f110f77d7712eb19c283eb9f745c7123feab9557187778da412639ba5692`. Its existing diff only reorders the editor_plugins and physics sections; values are unchanged. It remains outside any proposed checkpoint unless separately approved.
- No owner profile, IndexedDB, save, backup, protected boss DOC, `character saves/` or repository `tmp/` contents were accessed. Protected entries remain unchanged/excluded. Only previously generated disposable results and a retained test-harness PCK were read.
- Checks in 45O: source/call-graph inspection, prior-result/artifact verification, preservation hashes, exact Git inventory and whitespace checks. No runtime suites, full regression, browser operation, import, production DB upgrade or Web export ran. No staging/commit/push/stash/reset/rebase/clean occurred.

Integration hazards: the inspected implementation spans uncommitted 45B-45N production changes, prototype source/tests/UIDs and runner registrations. HEAD does not include them; old HEAD builds cannot certify this plan's behavior. Some new files are under tests/ and may be excluded from production exports; promote shared pure logic once rather than importing tests live. A future separately authorized checkpoint needs an exact reviewed manifest including dependent untracked UID/source files, excluding the pre-existing project.godot change and protected/generated/personal data. Do not mix a schema upgrade or routing activation into that checkpoint by assumption. The current playable Web artifact was not inspected or refreshed in this audit.

### Exact final working-tree status

```text
 M project.godot
 M scripts/combat/arena_combat_session.gd
 M scripts/combat/character_development.gd
 M scripts/combat/combat_actor_definition.gd
 M scripts/combat/combat_simulation.gd
 M scripts/movement/prime_movement_model.gd
 M scripts/player/placeholder_player.gd
 M scripts/rewards/arena_reward_ledger.gd
 M scripts/rewards/character_backup_contract.gd
 M scripts/rewards/character_backup_reader.gd
 M scripts/rewards/character_backup_restoration.gd
 M scripts/rewards/character_backup_task.gd
 M scripts/rewards/character_level_progression.gd
 M scripts/rewards/character_profile_projection.gd
 M scripts/rewards/character_wave_checkpoint.gd
 M scripts/rewards/playable_character_admission.gd
 M scripts/rewards/playable_character_persistence.gd
 M scripts/rewards/prime_v3_advancement_catalog.gd
 M scripts/ui/arena_combat_controller.gd
 M scripts/ui/character_backup_actions.gd
 M scripts/ui/character_backup_files.gd
 M scripts/ui/character_sheet_help.gd
 M scripts/ui/character_sheet_projection.gd
 M scripts/ui/character_sheet_window.gd
 M tests/test_character_sheet.gd
 M tests/test_historical_vaelis_admission.gd
 M tests/test_runner.gd
 M tests/test_task_37a_foundation.gd
?? "assets/Rare Human Warrior (Boss).doc"
?? "character saves/"
?? docs/architecture/TASK_45D_CHARACTER_CORRECTIONS.md
?? docs/architecture/TASK_45J_COMPACT_CHARACTER_SAVE_DESIGN.md
?? docs/architecture/TASK_45K_COMPACT_V6_PROTOTYPE.md
?? docs/architecture/TASK_45L_LEGACY_TO_V6_CONVERSION.md
?? docs/architecture/TASK_45M_COMPACT_V6_STORAGE.md
?? docs/architecture/TASK_45N_COMPACT_V6_BACKUP_RESTORE.md
?? docs/architecture/TASK_45O_V6_PRODUCTION_INTEGRATION_PLAN.md
?? docs/audits/TASK_45E_SAVE_LOAD_PERFORMANCE.md
?? docs/audits/TASK_45G_WEB_MEMORY_DIAGNOSIS.md
?? scripts/combat/arena_mana_recovery.gd
?? scripts/combat/arena_mana_recovery.gd.uid
?? scripts/rewards/compact_character_v6_prototype.gd
?? scripts/rewards/compact_character_v6_prototype.gd.uid
?? scripts/rewards/compact_v6_equivalence.gd
?? scripts/rewards/compact_v6_equivalence.gd.uid
?? scripts/rewards/endurance_growth_history.gd
?? scripts/rewards/endurance_growth_history.gd.uid
?? scripts/rewards/legacy_to_compact_v6_prototype.gd
?? scripts/rewards/legacy_to_compact_v6_prototype.gd.uid
?? tests/benchmark_task_45e.gd
?? tests/benchmark_task_45e.gd.uid
?? tests/browser/compact_v6_backup_edge_cases.js
?? tests/browser/compact_v6_backup_store.js
?? tests/browser/compact_v6_store.js
?? tests/browser/compact_v6_wasm_harness.gd
?? tests/browser/compact_v6_wasm_harness.gd.uid
?? tests/browser/test_compact_v6_storage_edge.js
?? tests/browser/test_task_45e_edge.js
?? tests/compact_v6_backup_store.gd
?? tests/compact_v6_backup_store.gd.uid
?? tests/compact_v6_disposable_store.gd
?? tests/compact_v6_disposable_store.gd.uid
?? tests/compact_v6_portable_backup.gd
?? tests/compact_v6_portable_backup.gd.uid
?? tests/compact_v6_storage_fixtures.gd
?? tests/compact_v6_storage_fixtures.gd.uid
?? tests/compact_v6_storage_process.gd
?? tests/compact_v6_storage_process.gd.uid
?? tests/test_compact_character_v6.gd
?? tests/test_compact_character_v6.gd.uid
?? tests/test_compact_v6_backup.gd
?? tests/test_compact_v6_backup.gd.uid
?? tests/test_compact_v6_storage.gd
?? tests/test_compact_v6_storage.gd.uid
?? tests/test_end_hpm_replay.gd
?? tests/test_end_hpm_replay.gd.uid
?? tests/test_legacy_to_compact_v6.gd
?? tests/test_legacy_to_compact_v6.gd.uid
?? tests/test_permanent_end_advancement.gd
?? tests/test_permanent_end_advancement.gd.uid
?? tests/test_task_45d_dex_correction.gd
?? tests/test_task_45d_dex_correction.gd.uid
?? tests/test_task_45d_experience.gd
?? tests/test_task_45d_experience.gd.uid
?? tests/test_task_45d_mana_recovery.gd
?? tests/test_task_45d_mana_recovery.gd.uid
?? tests/test_task_45e_backup_integrity.gd
?? tests/test_task_45e_backup_integrity.gd.uid
?? tests/test_task_45g_release_scanner.py
?? tmp/
```

**Stop after 45O.** Recommended next authorized scope is S1 only, then dormant adapter/proof work. No Pass E or live integration begins under this audit.
