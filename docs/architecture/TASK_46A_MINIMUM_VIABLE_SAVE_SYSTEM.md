# Task 46A — Minimum-viable character save system

18 November 2026. **Design recommendation only. No implementation or activation authorized by this report.** Task 45U remains paused. The owner maintains the Roadmap and Combat Specification independently; neither was opened or edited. This is the only file created or changed in 46A.

## 1. Decision

**Recommend a smaller, explicitly versioned successor to Architecture B: a coordinator-owned admitted character, essential lifetime facts/IDs, and a current snapshot plus exact latest-state repair copy. Do not productionize W/X/Y unchanged.**

Keep the gameplay engine and the existing persistence coordinator. Change its future ownership/serialization boundary instead of attaching another verifier or cache. Ordinary saves should validate newly resolved effects and publish one checkpoint; admission/import should validate the complete essential character evidence once. A save must not be a forensic reconstruction of every prior save.

This deliberately changes the proposed local trust model. Internal code running in the same process is trusted to call the existing rule/transaction paths. Imported data is bounded and semantically checked, but locally reproducible hashes are not evidence that a player really fought an enemy or received owner consent. Prevent accidental duplication and corruption now; defer sophisticated local anti-cheat.

The successor is a proposal requiring approval. Current V2/V4/V5 behavior, dormant V6 formats and their stricter validators stay unchanged until separately authorized implementation.

## 2. Current source and complexity diagnosis

Evidence labels: **verified source** means current code inspected in this audit; **recorded result** means existing V–Z/S–T reports or prior completed measurements, not a new test; **proposed** means not implemented or timed.

### Production call paths — verified source

| Path | Actual components and current work |
| --- | --- |
| Desktop admission | `PlayableCharacterPersistence.open()` → `CharacterSaveStorage.inspect_profile()` → `open_verified_history()` → original source/lineage/profile hydration. Reads complete legacy generations to establish history. |
| Browser admission | `PlayableBrowserPersistence.open_browser()` captures profile/run-policy choice, acquires/inspects through `CharacterBrowserStorage`, then `poll_browser()` invokes the same `open_verified_history()`. Pending/failure/cancellation and leases matter. |
| Gameplay capture | `playable_character_persistence.gd:ingest()`, `_sync_items()`, `checkpoint()`, `_capture()` collect real ledger facts, current resources, run policy, wave checkpoint, RNG, movement/fatigue and timers. `CharacterWaveCheckpoint.validate()` checks supported boundaries. |
| Desktop publication | `publish_prepared()` constructs the existing `CharacterPersistenceCoordinator`; `commit()` calls `_authorize()`, inspects history, checks continuity, writes, rereads and reconciles exact transaction identity. `CharacterSaveStorage._write_locked()` retains complete generation documents. |
| Browser publication | `PlayableBrowserPersistence.publish_prepared()` → `CharacterBrowserPersistence.begin_commit()/poll()` → same coordinator `_authorize()` → `character_browser_store.js` ownership/CAS/IndexedDB publication/readback → original `_ack()`. JS is transport, not the rule engine. |
| Export/download | `CharacterBackupActions`, `CharacterBackupReader`, `character_backup_task.gd` and `CharacterBackupContract` validate and encode the complete generation archive; `CharacterBackupFiles` writes/downloads the file. Download initiation is not confirmation that the user's file is safely retained. |
| Preview/restore | Reader validates the imported file without writes. `CharacterBackupRestoration.begin()/confirm()/poll()` reacquires/rechecks destination, compares complete history, requires confirmation, publishes and verifies. Its current permitted comparisons include empty, exact and exact history-prefix extension. |

`CharacterPersistenceCoordinator._authorize()` re-encodes the proposal, fingerprints it, invokes the trusted verifier, hydrates the character and validates receipts. That is meaningful for an externally supplied mutable proposal. Repeating it through several adapters is not inherently required once one owner exclusively controls an admitted character and a pending save.

Legacy `CharacterSaveStorage.read_profile()` can return an older valid generation with an explicit recovery flag after rejecting a newer file; it is not the proposed exact-latest recovery contract. The new system must not inherit that behavior as an unqualified automatic fallback.

### Dormant paths — verified source

- **V6 codec:** `compact_character_v6_prototype.gd:encode()/decode()/validate()/validate_extension()` validates source identity, lifetime IDs, current projection, accounting, ownership and original chronology. `_chronology()` replays essential purchases/growth. Historical/native credit proof can reconstruct predecessor data recursively. A valid V6 file is not itself a permit to award XP.
- **S2/S3:** `compact_v6_gameplay_candidate.gd` observes actual events, authorizes the original legacy proposal, assembles V6, compares projections and seals the operation. `compact_v6_fixed_credit.gd` preserves the fixed grant contract, consent binding and predecessor witness. These paths are still coupled to legacy projection/authorization.
- **W:** `compact_v6_snapshot_package.gd` holds a current record, cumulative hashed commit receipts and a separate head with per-field/evidence digests. `cold_verify()` and `recover()` bind exact current/replica bytes. `relationship()` explicitly does not authorize occupied-profile restoration; a longer receipt chain cannot establish omitted intermediate semantics.
- **X:** `compact_v6_incremental_snapshot.gd` adds another admitted context, exact-ID map, event/request binding, full parent/runtime/source fingerprints, W packaging and acknowledgement checks. Its freshness callback is a trusted test-host witness, not a production storage lock/CAS implementation. The player Running model is external to the session snapshot and is separately bound.
- **Y:** `compact_v6_checked_operation.gd` adds immutable-byte proof ownership and invalidation across S2/W/X. It safely avoids repeated semantic replay inside the current mutable-adapter design, but introduces additional weak references, identities, context states and repeated byte reconstruction.
- **Z:** the attempted seal representation is **rejected and absent**. S2 remains its original pre-Z bytes. Only profiling/report/characterization work was retained.
- **S4/S5:** Windows and browser compact adapters are disposable-only and still require the earlier reversible portable capsule. They do not implement W's snapshot/replica layout. Removing their disposable-prefix guards would not constitute safe production integration.

The complexity comes from composing individually defensive layers around mutually mutable structures, including a legacy document, V6 record, S2 seal, X context/seal, Y proof, W package/head and old portable capsule. Many layers re-prove the same state because no single boundary owns it. This is a design issue, not evidence that every individual check was mistaken.

## 3. KEEP / SIMPLIFY / DEFER

Decisions below apply to the **proposed new format/path**, not permission to remove checks from existing formats.

| Safeguard/component | Decision | Risk if removed; simplest disposition |
| --- | --- | --- |
| One authoritative character, exact identity and namespace | **KEEP** | Prevent profile crossover and conflicting balances. One admitted persistence aggregate under the existing coordinator; no second wallet. |
| Existing reward, purchase, advancement, level and item rules | **KEEP** | Otherwise rules/prices/loot can change. Reuse original rule functions for new effects and cold essential-evidence checks. |
| Trusted gameplay-event causality | **KEEP** | A changed balance is not an authorized award. Accept effects from the existing resolved gameplay/management paths, not arbitrary UI deltas. |
| Exact lifetime semantic transaction IDs and immutable bindings | **KEEP** | Prevent old awards, purchases, grants, item origins/uses and growth being submitted under new request wrappers. Full scoped IDs, never truncated/probabilistic membership. |
| Exact lookup map | **KEEP** | Rebuild once from complete explicit lifetime records on admission; update with accepted effects. No persistent secondary index or digest per ID is necessary. |
| Approximately 20-operation recent journal | **KEEP** | Useful status and retry diagnostics. It is not the lifetime duplicate registry. |
| Existing run policy, Wave 1 binding and namespace validation | **KEEP** | Avoid multiplier reassignment and NORMAL/DEV crossover. TEST remains nonrewarding/nonpersistent. |
| Original END/HPB/WIS/HD/Mana facts and chronological links | **KEEP** | Needed to prevent final END/WIS changing prior growth. Retain original dice, starting values, event-time values and purchase order. This is essential progression evidence, not optional forensics. |
| Current equipment, quantities, condition, currency and consumed IDs | **KEEP** | Prevent duplication, loss and equipment/resource mismatch. Preserve origin/use bindings plus current ownership. |
| Current run/checkpoint/RNG/movement/recovery state | **KEEP** | Deterministic resume and legal RETRY require these. Keep existing schema-12 boundary validation, including Running state and Mana remainder. |
| Full cold/import validation | **KEEP**, once per admission/import | Detect malformed, inconsistent or unsupported data before use. Includes all required accounting, advancement/growth and item evidence, not merely a checksum. |
| Lifetime history rehydration on every routine save | **SIMPLIFY** | New effects must be checked; already admitted immutable facts need not be replayed. Append to the coordinator's owned evidence and reject conflicts at that boundary. |
| Repeated parent/source/runtime canonical fingerprints | **SIMPLIFY** | They currently detect mutable aliases and stale proposals. Replace only after real exclusive ownership and a legal checkpoint gate are established; use exact expected head and an internal revision, not a caller-provided trust bit. |
| S2 legacy proposal → projection → V6 assembly round trip | **SIMPLIFY** | Retain its real source-authorized effects and their order. Produce the compact checkpoint directly from the admitted aggregate; no second full legacy serialization in normal operation. |
| Separate S2/X/Y proof and seal frameworks | **SIMPLIFY** | Preserve single-flight, immutable pending bytes, exact retry and terminal cancellation in the existing coordinator. Do not stack three context lifecycles in the new path. |
| Full-record copying and sealed JSON parsing | **SIMPLIFY** | Own one pending record and serialized byte string; pass it read-only. UI gets bounded projections, not mutable state or complete history copies. Do not hand-build an extra serializer to chase a tiny gain. |
| Checksums, strict parser, finite limits and versions | **KEEP** | Detect corruption, duplicate JSON keys, unsafe numbers, unsupported schema and excessive inputs. One record checksum and small descriptor integrity are sufficient; these do not authenticate earnings. |
| Many per-field cryptographic digests | **DEFER** | Adds localization/forensic detail, not stronger local earning authority. Keep exact body/head binding; drop redundant field hashes from the new format. |
| Cryptographic commit-receipt chains | **DEFER** | Useful forensic lineage but not proof of honest local play; W still cannot authorize arbitrary descendant restore. Use epoch, sequence, exact expected head and stable commit ID for publication. Block unsupported occupied restores. |
| Complete reversible ancestry/previous character generations | **DEFER** | Needed for arbitrary historic rollback, not current save correctness. Keep old readers for conversion; new routine saves carry no ancestry capsule. Do not delete originals. |
| Recursive complete pre-credit state proof | **SIMPLIFY** | Keep fixed target, amount, grant ID, eligibility, explicit confirmation and EXPC-only accounting. In a new format retain the original resolved credit fact/order, not a full predecessor character. Legacy conversion verifies the old proof first. |
| Exclusive writer, one pending operation and CAS | **KEEP** | Prevent tabs/processes overwriting each other and double clicks issuing two mutations. Compare exact expected destination head before publication. |
| Stage/flush/transaction/atomic commit and exact readback | **KEEP** | Avoid partial publication and acknowledging bytes never stored. Full semantic replay on byte-identical readback is unnecessary; independently compare stored bytes/head to the validated candidate. |
| Exact latest-state replica and acknowledged-head marker | **KEEP** | Recover actual acknowledged progress, not an older character. A checksum or journal cannot reconstruct missing data. |
| Busy/progress, cancellation and operation isolation | **KEEP** | Prevent apparent hangs, stale callbacks and overlapping requests. Reuse existing UI/state behavior and browser pump; release temporary buffers on every terminal path. |
| Old-writer/minimum-reader exclusion | **KEEP** | Older builds must not overwrite the new slot or make new progression silently disappear. Explicit versioned activation and a compatible recovery build are required. |
| Arbitrary occupied-profile backup replacement | **DEFER** | Same names, higher XP or sequence do not prove a safe descendant. Initially allow empty-destination restore and exact-installed no-op only. |
| Local tamper resistance, signatures/accounts, future PvP defenses | **DEFER** | Client-controlled files/hashes cannot prove legitimate XP. Do not implement fake authentication using local digests. Future host/server decides reward authority. |

## 4. Minimal record and ownership model — proposed

### Durable contents

One self-contained current record contains:

1. **Header:** explicit format/version/minimum-reader identity, profile ID, namespace, character lineage/epoch, monotonically increasing commit sequence, stable last commit/request ID, source/rules revision and body checksum.
2. **Current character:** immutable starting attributes/creation HPM/Mana, permanent advancement, current derived/equipment-adjusted projection, level and authoritative balances, equipment/inventory/condition/consumables/currency, current resources and modifiers supported by the existing checkpoint.
3. **Essential evidence:** original award amounts and run/multiplier/defeat bindings; purchases/costs/DEX allocations; original ordered level growth with HD sides, rolls, bonuses, event-time END/HPB/WIS and before/after HPM/Mana; fixed-credit facts; item origin/use/ownership evidence. Existing flat fact arrays can be retained initially; do not redesign them into a generic event engine merely to save a few bytes.
4. **Complete exact lifetime ID/binding registry:** covers effects that can duplicate progression or items, including retained original operation identities. Recent journal eviction cannot remove these. The admitted exact lookup is rebuilt from explicit records, not inferred from balances or missing IDs. References may avoid duplicated fact bodies; no approximate hashes.
5. **Current run and applicable verified wave-entry/recovery checkpoint:** locked XP policy, legal resume phase, RNG/draw state, clock, resources, Running/fatigue/cooldowns/timers, movement ledger, Mana fractional remainder and existing request sequence. This necessary checkpoint is not an archive of arbitrary old characters.
6. **Small recent journal:** about 20 operation summaries/references, without duplicating whole record bodies.

Retain essential facts once; no combat transcript, hundreds of generations, reversible state deltas or cumulative receipt chain in routine files. Lifetime evidence still grows; this is bounded by finite supported limits, not a constant-size or infinite-history promise.

Do not mislabel a changed contract as V6. Proposed distinct domain **`itank_arena_character_snapshot`, version 1** was not found in inspected source. It is a design choice, not a reservation or activated version. A separately explicit storage-layout version and minimum-reader fence are needed. Existing character envelopes 2/4/5, V6 inner versions 1/2, W package 1/head 2, and capsule-based S4/S5 route 1 retain their original meaning. Production IndexedDB currently opens version 1; disposable S5 opens version 2. Production upgrade numbers/layout require approval and an upgrade audit, not copying the disposable number blindly.

Use one straightforward bounded JSON codec and one whole-body checksum; a small envelope/header is acceptable. Avoid per-field hashes and repeated parse/encode cycles, but do not invent a clever hand-assembled serializer. A portable backup can carry the exact self-contained current record under the new format, with optional nonauthoritative display metadata; it needs no second historical archive format. Old backup readers remain separate.

### Accounting and growth

Cold verification reconciles source-backed starting EXPM/EXPC, all original XP award facts, all legitimate EXPC debits, and the fixed EXPC-only credits. In the present model:

- EXPM total = source-backed starting EXPM + earned XP awards.
- Available EXPC = source-backed starting spendable EXPC + XP awards + authorized EXPC-only credits − recorded EXPC purchase costs.
- Spent EXPC = those recorded costs; credits never increase EXPM, level or earned-XP progress.

Do not assume starting spendable EXPC equals starting EXPM or invent zero for unavailable source data. Unsupported effect kinds fail explicitly.

Replay **essential growth chronology once on cold load/import**, using existing source/rule helpers. Earlier HPM gains retain their original HPB/HD/rolls. END purchases change approved NAL/PS/HPB and Running duration but do not immediately change HPM/HPC. Earlier Mana gains retain event-time WIS; WIS purchases contribute their approved +1 Mana Max without refilling current Mana. Future growth uses the attributes at its own event. STR/DEX/SPD/SS and equipment/authored exceptions remain source-validated. No historical reroll or recomputation using final attributes.

This necessary compact progression check is distinct from replaying all combat events or rehydrating every historical generation. The latter is deferred.

### One existing coordinator owns the admitted state

The existing service remains the gameplay façade; the existing coordinator owns its persistence aggregate/commit lifecycle for the admitted profile. Do not create a second wallet or competing authoritative character in W/X/Y. Combat actors and the reward ledger still resolve gameplay under current rules.

Admission constructs the private aggregate after full validation. Ordinary callers cannot supply arbitrary replacement balances/records or retain mutable aliases into it. UI reads small projections. Original rule/management paths deliver a typed batch of resolved effects with stable IDs and original order. Validate the new effects against that state and the existing catalogs, then append their facts/IDs once. No full parent/source/actor rehydration is needed after every check of the same owned evidence.

An internal revision counter is safe only when **all** relevant mutations pass through the owner/gate. It is not a serialized verified flag and cannot be accepted from a caller. Shared authored resources must be immutable in this boundary; temporary combat effects belong to runtime actors. Source/rules changes require re-admission or an explicit compatible update. If the actual mutation audit cannot establish ownership, keep the current checks and stop integration; do not replace hashes with an unproven counter.

### Ordinary save algorithm

1. At an existing legal save boundary, use the existing pause/command gate, capture current runtime plus external movement state once, and validate the **new** resolved batch and checkpoint. Preserve existing action/reward timing; no new per-frame saves or arbitrary mid-combat resume feature.
2. Check exact new IDs/bindings. A repeated exact request reconciles the one pending operation; conflicting binding or stale revision/head fails. Rewrapped old rewards/purchases/credits cannot become new effects.
3. Build one next snapshot and serialize it once for this operation. Retain one immutable pending byte string, expected acknowledged head, request ID and resulting state. No legacy proposal serialization, full old-history replay, W receipt append, S2/X/Y seal cascade or per-item cryptographic fingerprint loop.
4. Recheck genuinely mutable writer ownership, expected durable head and the local admitted revision/checkpoint gate. Publish the record, identical replica and head atomically or recoverably. Hold the existing single-flight barrier through asynchronous work.
5. Independently read back exact stored bytes/head. Acknowledge and adopt only the matching operation. An uncertain outcome blocks a new conflicting operation and reads/reconciles the same request; it never rerolls or reapplies effects.
6. Release pending copies, callbacks and import/export buffers on completion/cancel. Cancellation before commit changes nothing; after a possible commit it is an uncertain acknowledgement requiring reconciliation, not a promise to undo publication.

Proposed routine cost is validation of new effects plus O(current record + lifetime evidence) encoding/I/O. It is not O(1), and no measured speedup is claimed.

## 5. Storage, recovery and portable files

### Windows

Reuse validated path isolation, exclusive writer, staged write/flush/error checks, rename/readback and fault-injection techniques from existing storage. Adapt them through the existing coordinator to the new layout; do not reuse S4 `install()` unchanged because it requires a capsule.

Prefer head-selected immutable record/replica files during a commit: stage and verify both new copies first, then publish the small head. Keep the old head's pair until the new head is committed and exactly read back. Before head publication, a crash leaves the previous acknowledged pair intact; after publication, the new pair is recoverable even if acknowledgement was lost. After a verified commit, bounded maintenance can retire obsolete files under the same writer lock, leaving one current and one exact repair copy. Transient pending/old pairs are crash-safety staging, not an expanding character archive.

Do not overwrite both old copies before committing the head. Do not claim Godot rename/flush proves OS power-loss durability or atomic replacement on every Windows filesystem. Reuse the demonstrated operations but test the exact new commit sequence, including head replacement and stale-lock behavior, before activation. Unknown locks fail closed; automatic stale-lock deletion is not part of the minimum pass.

### Edge

Reuse the existing request/poll bridge, Web Locks/lease handling, single-flight state, IndexedDB transaction/CAS, failure presentation and exact readback. In the new versioned layout, write current bytes, identical replica and head in one transaction. JS checks transport shape, size, expected head and ownership; source/rule validation stays in Godot. A lost acknowledgement is resolved by the stored commit ID/body, not another award/purchase.

Production upgrade must preserve legacy stores/profiles and close old connections safely. Existing version-1 clients must be fenced from overwriting the new slot. Do not infer that the disposable S5 database proves a production upgrade. Quota, eviction, origin loss, locked tabs and unsupported versions need explicit failure paths. Transaction/readback tests do not prove every power-loss scenario.

### Exact recovery

- Intact head + valid current: load that state once. A damaged/missing replica can be repaired under ownership from the exact current bytes.
- Damaged current + matching latest replica: verify that exact head-bound state and repair it. No older checkpoint substitution.
- Missing/conflicting head authority, or both latest copies damaged: diagnostic/recovery-required state. Do not select a file simply because its sequence/XP is higher or another file happens to parse.
- An intact prior state is not proof of missing later acknowledged changes. Two copies on one device/origin do not protect against total storage loss; portable backups remain necessary.

### Export, preview and restore

Export the exact acknowledged current record after checking the selected head did not change. No legacy archive scan; do not export a pending candidate as committed. Reuse file selection/download, safe limits, busy/progress and cancellation UI. Release duplicate temporary strings/Blobs after use. Do not add worker/cache infrastructure before measurement warrants it.

Preview/import is read-only and validates bounds, UTF-8, version, identity, checksum and **all required essential semantics** once. An exact preview may be reused only while file bytes, selected profile and relevant destination conditions remain unchanged. Restore separately confirms, acquires ownership, rereads destination and publishes through the same coordinator/readback protocol.

For the first release, restore only into a truly empty target or treat exact installed bytes as an idempotent no-op. Block occupied-profile replacement and older/conflicting states; a higher sequence is not sufficient proof of descent. If a known newer destination marker survives, it blocks an older backup even if the data file is missing. On a genuinely empty new device, an offline backup cannot prove that no newer copy existed elsewhere; disclose that limitation. Arbitrary rollback, branch merge and cross-device anti-rollback are deferred, not secretly solved by a receipt chain.

## 6. What can be reused directly

| Existing component | Disposition for the new path |
| --- | --- |
| Reward/advancement/level catalogs, actor source rules, original effect IDs | Reuse rule behavior unchanged. No new prices, reward rules or permanent-stat mechanics. |
| Wave checkpoint validators and capture fields | Retain semantics, RNG/timing and external movement capture. Adapt only the record boundary. |
| Coordinator single-flight, expected-head, ownership, retry/reconcile and acknowledgement responsibilities | Keep. Make it the owner of admitted persistence state rather than reconstructing it through multiple adapters. |
| Desktop/browser transport primitives and failure-injection tests | Reuse patterns/primitives after layout-specific tests. Disposable guards and capsule contracts stay intact in old adapters; new production routing needs explicit approval. |
| K/L conversion and independent equivalence machinery | Keep as offline/disposable conversion/reference tools; never run full legacy conversion during each normal save. |
| V6 codec/original full validator and S2/S3 | Retain legacy/prototype readers and correctness references. Extract/reuse rule checks; do not invoke the entire old proof chain for each new-format save. |
| W exact-current/replica recovery behavior | Reuse invariants and test cases directly. Simplify format/metadata; current W bytes/cold verifier are not the new-format implementation. |
| W commit chain/per-field hashes and occupied-restore diagnostics | Do not integrate into minimum routine saves. Preserve old reader/diagnostics as needed. |
| X exact-ID protection, legal event capture, external movement awareness, lost-ack tests | Reuse behavior/tests. Replace its parallel context/whole-state seal lifecycle with coordinator ownership. |
| Y checked-operation framework | Keep dormant as earlier work/oracle evidence. Do not add it to the new playable path; real ownership removes the reason for a second proof-capability layer. |
| Z profiler and characterization assertions | Keep evidence and reusable tests. The rejected serializer must not reappear as an approved optimization. |
| Existing backup busy/progress/file UI | Reuse, with new exact-current export/preview adapter. Preserve legacy backup readers separately. |

## 7. Performance: observed versus projected

No benchmarks or tests ran in 46A. These are recorded earlier measurements, not predictions for the proposed system:

| Evidence / boundary | Recorded result and interpretation |
| --- | --- |
| Y small NORMAL/DEV preparation, native debug | About 39–128 ms; good preparation latency already exists for small fixtures, but excludes actual publication/adoption. Do not optimize only for stress cases. |
| Y original233, native preparation | About 491–513 ms after one-time conversion. The record can be practical without retaining 233 complete generations in routine storage. |
| Z current-Y 1,005-item stress, native preparation | 3732/3992 ms. One full V6 validation about 223–225 ms; two coordinator authorizations about 513–516 ms. Aggregate JSON stringify about 1566/1924 ms; intervals overlap. |
| Z rejected experiment | About 3691/3941 ms, only ~1% observed full-preparation gain. Isolated copy savings and lower live bytes did not establish a worthwhile CPU improvement. Source restored; no delivered speedup. |
| Y/Z native matrix memory | Peaks around 1.8 GB include full legacy conversion/fixtures/oracles. They are not routine-save-only peaks and do not diagnose an idle Edge leak. |
| Earlier T actual release-WASM, older capsule path | Reported large host save 37.478 s, underlying IndexedDB transaction 50.3 ms/readback 5.7 ms. Different architecture/workload: evidence to avoid blaming disk/IDB first, not a direct benchmark of W/X/Y or this proposal. |

Normal characters, realistic inventories and consecutive checkpoints are the primary shipping workload. Preserve converted characters where practical; keep 1,005 items as a separately labelled stress gate. Avoid timing fixture creation/full legacy conversion as routine load/save. No owner-browser or release-WASM performance has been established for this proposed layout.

Targets remain save/load ideally 1–3 seconds, export/preview under 5 seconds and restore under 10 seconds with responsive controls. Eliminating repeated adapters/history replay is a plausible improvement, **not a measured guarantee**. Future approved testing must separately measure preparation, storage, acknowledgement, cold admission, UI responsiveness and memory release; label native debug, Windows release and actual Edge release separately.

## 8. Legacy characters and security trade-offs

**Recommend new-format characters first, plus one optional bounded verified conversion path.** Reuse K/L to validate the complete V2/V4/V5 history once, extract its exact current state/essential evidence and independently compare it. Historical V6 readers can similarly validate their own original contracts once before mapping. New-format routine operations must not carry those archives or full pre-credit snapshots forward.

Preserve the original files/backups unchanged and recheck the original head under ownership before cutover. Keep existing NORMAL and historical DEV identities/namespaces separate; no merging, relabelling or new DEV starter via legacy-profile access. Preserve legacy namespace-derived award policy and V4 per-run policies for completed/unfinished runs; both current persistent namespaces support authorized run-specific ×1/×10 policies. DEV visibility neither selects a namespace nor unlocks an admitted policy. Existing DEV Refresh authorization remains separate. TEST retains zero rewards and testing fixtures.

If chronology, credit lineage or checkpoint equivalence cannot be established, return a precise unsupported conversion result. Do not invent original HPB/WIS order or repair balances. Leave the original intact; offer an explicitly selected fresh character/slot only after owner-approved UI/policy, never a silent overwrite or migration. Vaelis preservation is desirable, not grounds for indefinite legacy execution or months of migration machinery.

Security limits are deliberate: checksums detect accidental damage; semantic checks detect inconsistent records, duplicate/conflicting transactions and unsupported effects. A local player controlling code/files can create a self-consistent fictitious history or recompute hashes. This system will not prove authentic play, stop deliberate offline rollback on a blank device or synchronize competing cloud branches. Do not weaken actual arithmetic/source rules to acknowledge that limit. Online authority later must not treat a client backup as authenticated entitlement.

## 9. Future cooperative PvE boundary

Keep one narrow interface at the existing resolved-effect/commit boundary: **session/run identity, expected admitted revision, ordered effect batch, full scoped event/request IDs, and checkpoint** → validate with existing game rules → accept one commit or reject with a reason. The producer is trusted local gameplay today; a future host/server can supply authoritative resolved effects through the same boundary. It decides legal actions, RNG/results and rewards; clients cannot submit arbitrary balance changes or confer authority using a verified flag.

Persist provenance identifiers so exact retransmission is idempotent. The persistence layer remains responsible for durable publication, not combat simulation or networking. Host authentication, profile admission/fairness policy, two-player commit coordination and disconnect recovery remain future decisions. Do not require a multiplayer distributed transaction, PvP anti-cheat, matchmaking, account backend or speculative scale machinery to ship the single-player save path.

## 10. Short bounded implementation path — proposals, not authorization

| Pass | Small deliverable / affected seam | Minimum proof before advancing / stop condition |
| --- | --- | --- |
| 1. Minimal record and cold reader | Explicit new domain/version; self-contained current record, existing essential flat evidence/IDs, checkpoint and checksum. Reuse rule helpers from current projection/V6; no storage routing. Define flat fixed-credit fact mapping rather than recursive predecessor snapshots. | Disposable fresh/converted/credited characters, all five attributes, ordered END/WIS growth, exact complete projection, accounting/ID/item tampering, unknown versions and original source exceptions. Stop if any required field/chronology cannot be preserved without guessing. |
| 2. Coordinator-owned routine batch | One admitted aggregate, existing trusted rule/effect inputs, private exact-ID lookup, legal checkpoint gate, one pending serialized snapshot. Remove legacy proposal and W/X/Y proof cascade only from this new path. | Consecutive normal/DEV checkpoints, original gameplay controls, exact retries/conflicts/stale revision, fixed grant once, all existing resource/RNG/Running/Mana remainder fields, cancellation and external movement changes. Stop if writes can bypass ownership/revision tracking. Measure normal workloads before expanding. |
| 3. Disposable Windows publication | New layout under existing coordinator, staged current/replica/head, expected head, exclusive writer, exact readback/reconcile. | Crash before/during/after every publication step; acknowledged head never silently regresses; exact replica repair; stale writer/lock and unsupported-reader fences; no deletion of unrelated/legacy data. Stop if replacement durability/ownership is unproved. No automatic stale-lock removal. |
| 4. Disposable Edge publication | Same record/commit protocol through existing bridge, one IDB transaction, writer/CAS and fresh readback. | Actual release-WASM tests: competing tabs, stale callbacks, quota/abort, lost ack, reload/backgrounding, repeated saves and memory/responsiveness. Verify production-upgrade plan separately; no production DB touched in this pass. |
| 5. Portable file and optional conversion | Exact acknowledged export, bounded full read-only preview, separately confirmed empty/exact restore, one-time K/L-based conversion with original left intact. | Windows↔Edge bytes/projection equivalence; corruption/duplicate keys/truncation/size limits; changed preview/head, cancellation, failed writes, old/conflicting occupied backup blocked; complete equipment/progression/resources/checkpoint equivalence. Stop rather than invent ancestry. |
| 6. Controlled playable cutover | Connect existing character admission/checkpoint/backup UI to approved route; explicit compatible build/minimum reader; retain legacy readers and distinct profiles. | Focused integration then one justified full checkpoint, Windows release and actual isolated Edge acceptance, owner confirmation for any real conversion. Owner tests load, purchase/reload, RESUME/NEW RUN/RETRY/NEXT WAVE, XP policy, backup/repair and interrupted operations. No silent fresh start or legacy fallback after new progress. |

Do not add more prototype frameworks between these passes. Reuse the tested behavior and existing coordinator, not all prototype object layers. After any new-format write, software rollback means a compatible recovery build reading that exact state; reverting to old software/old legacy data is not an acceptable rollback mechanism.

## 11. Owner decisions before implementation

1. Approve replacing the W/X/Y routine proof model with the ownership-based local trust model and a **new** record/layout contract. Earlier formats/readers are not silently reinterpreted.
2. Approve retaining essential original growth/purchase/award/item/credit facts and exact lifetime IDs while dropping reversible ancestry, cryptographic receipt chains, per-field forensic hashes and full pre-credit snapshots from new records.
3. Approve the initial restore restriction: empty target or exact installed no-op; occupied replacements remain blocked until a separately justified policy. Offline blank-device restore cannot prove global latest state.
4. Approve optional best-effort verified legacy conversion, originals untouched, with an explicitly selected fresh character option if conversion is unsupported. No automatic identity/namespace migration.
5. Approve the controlled production storage/version upgrade and compatible-reader policy only after disposable Windows/Edge evidence. No production upgrade, schema change or real profile operation is authorized by this design report.

The implementation should not wait for co-op networking or local anti-cheat. It must wait for trustworthy ownership boundaries, exact accounting/chronology, recoverable publication and explicit owner activation approval.

## 12. Git and preservation

Entry branch `main`, HEAD `f9bb0db0235b0003895c477a12346191d4714469`, index empty. 29 modified tracked paths and 147 collapsed untracked entries already existed. A read-only hash inventory captured **727 pre-existing nonprotected files** plus seven paused-U diagnostics before this report was created.

No source/tests/configuration, existing architecture/planning report, Roadmap, Combat Specification, owner data, backup, browser storage or generated build was changed. No benchmark, regression, import, startup or export ran. No Git mutation was performed. Only the report named by the owner is created. Final exact status and preservation comparison follow below.
Final read-only comparison: **all 727 pre-existing nonprotected files and all seven paused-U diagnostics retain their entry hashes; no original file is missing.** The only addition is this report. `project.godot` remains SHA-256 `8398f110f77d7712eb19c283eb9f745c7123feab9557187778da412639ba5692`. The index remains empty. Final status: **29 modified tracked paths, 148 collapsed untracked entries**, including this report and all pre-existing protected-name entries unchanged. No owner/protected file contents were inspected to make that confirmation.

Exact `git status --short`:

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
 M scripts/rewards/character_persistence_coordinator.gd
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
?? docs/architecture/TASK_45P_V6_PERFORMANCE.md
?? docs/architecture/TASK_45Q_V6_LIVE_CANDIDATE_BUILDER.md
?? docs/architecture/TASK_45R_V6_CREDIT_EXTENSION.md
?? docs/architecture/TASK_45S_V6_WINDOWS_STORAGE.md
?? docs/architecture/TASK_45T_V6_BROWSER_STORAGE.md
?? docs/architecture/TASK_45V_SAVE_ARCHITECTURE_DECISION.md
?? docs/architecture/TASK_45W_SIMPLIFIED_V6_PACKAGE.md
?? docs/architecture/TASK_45X_INCREMENTAL_SNAPSHOT_INTEGRATION.md
?? docs/architecture/TASK_45Y_INCREMENTAL_VALIDATION_OPTIMIZATION.md
?? docs/architecture/TASK_45Z_ROUTINE_SAVE_COST_REDUCTION.md
?? docs/architecture/TASK_46A_MINIMUM_VIABLE_SAVE_SYSTEM.md
?? docs/audits/TASK_45E_SAVE_LOAD_PERFORMANCE.md
?? docs/audits/TASK_45G_WEB_MEMORY_DIAGNOSIS.md
?? scripts/combat/arena_mana_recovery.gd
?? scripts/combat/arena_mana_recovery.gd.uid
?? scripts/rewards/compact_character_v6_prototype.gd
?? scripts/rewards/compact_character_v6_prototype.gd.uid
?? scripts/rewards/compact_v6_browser_coordinator.gd
?? scripts/rewards/compact_v6_browser_coordinator.gd.uid
?? scripts/rewards/compact_v6_browser_storage.gd
?? scripts/rewards/compact_v6_browser_storage.gd.uid
?? scripts/rewards/compact_v6_browser_store.js
?? scripts/rewards/compact_v6_checked_operation.gd
?? scripts/rewards/compact_v6_checked_operation.gd.uid
?? scripts/rewards/compact_v6_equivalence.gd
?? scripts/rewards/compact_v6_equivalence.gd.uid
?? scripts/rewards/compact_v6_fixed_credit.gd
?? scripts/rewards/compact_v6_fixed_credit.gd.uid
?? scripts/rewards/compact_v6_gameplay_candidate.gd
?? scripts/rewards/compact_v6_gameplay_candidate.gd.uid
?? scripts/rewards/compact_v6_incremental_snapshot.gd
?? scripts/rewards/compact_v6_incremental_snapshot.gd.uid
?? scripts/rewards/compact_v6_portable.gd
?? scripts/rewards/compact_v6_portable.gd.uid
?? scripts/rewards/compact_v6_snapshot_package.gd
?? scripts/rewards/compact_v6_snapshot_package.gd.uid
?? scripts/rewards/compact_v6_windows_storage.gd
?? scripts/rewards/compact_v6_windows_storage.gd.uid
?? scripts/rewards/endurance_growth_history.gd
?? scripts/rewards/endurance_growth_history.gd.uid
?? scripts/rewards/legacy_to_compact_v6_prototype.gd
?? scripts/rewards/legacy_to_compact_v6_prototype.gd.uid
?? tests/__pycache__/
?? tests/benchmark_task_45e.gd
?? tests/benchmark_task_45e.gd.uid
?? tests/browser/compact_v6_backup_edge_cases.js
?? tests/browser/compact_v6_backup_store.js
?? tests/browser/compact_v6_browser_edge_cases.js
?? tests/browser/compact_v6_browser_multitab_cases.js
?? tests/browser/compact_v6_browser_wasm_harness.gd
?? tests/browser/compact_v6_browser_wasm_harness.gd.uid
?? tests/browser/compact_v6_credit_edge_cases.js
?? tests/browser/compact_v6_performance_edge_cases.js
?? tests/browser/compact_v6_routine_edge_cases.js
?? tests/browser/compact_v6_store.js
?? tests/browser/compact_v6_wasm_harness.gd
?? tests/browser/compact_v6_wasm_harness.gd.uid
?? tests/browser/test_compact_v6_browser_edge.js
?? tests/browser/test_compact_v6_storage_edge.js
?? tests/browser/test_task_45e_edge.js
?? tests/compact_v6_backup_store.gd
?? tests/compact_v6_backup_store.gd.uid
?? tests/compact_v6_browser_host.gd
?? tests/compact_v6_browser_host.gd.uid
?? tests/compact_v6_disposable_store.gd
?? tests/compact_v6_disposable_store.gd.uid
?? tests/compact_v6_incremental_process.gd
?? tests/compact_v6_incremental_process.gd.uid
?? tests/compact_v6_perf_trace.gd
?? tests/compact_v6_perf_trace.gd.uid
?? tests/compact_v6_performance.gd
?? tests/compact_v6_performance.gd.uid
?? tests/compact_v6_performance_process.gd
?? tests/compact_v6_performance_process.gd.uid
?? tests/compact_v6_portable_backup.gd
?? tests/compact_v6_portable_backup.gd.uid
?? tests/compact_v6_routine_benchmark.gd
?? tests/compact_v6_routine_benchmark_process.gd
?? tests/compact_v6_routine_probe.gd
?? tests/compact_v6_snapshot_process.gd
?? tests/compact_v6_snapshot_process.gd.uid
?? tests/compact_v6_storage_fixtures.gd
?? tests/compact_v6_storage_fixtures.gd.uid
?? tests/compact_v6_storage_process.gd
?? tests/compact_v6_storage_process.gd.uid
?? tests/compact_v6_windows_benchmark.gd
?? tests/compact_v6_windows_benchmark.gd.uid
?? tests/compact_v6_windows_benchmark_process.gd
?? tests/compact_v6_windows_benchmark_process.gd.uid
?? tests/compact_v6_windows_crash_process.gd
?? tests/compact_v6_windows_crash_process.gd.uid
?? tests/compact_v6_windows_host.gd
?? tests/compact_v6_windows_host.gd.uid
?? tests/oracles/
?? tests/profile_compact_v6.py
?? tests/profile_compact_v6_costs.py
?? tests/profile_compact_v6_reuse.py
?? tests/test_compact_character_v6.gd
?? tests/test_compact_character_v6.gd.uid
?? tests/test_compact_v6_backup.gd
?? tests/test_compact_v6_backup.gd.uid
?? tests/test_compact_v6_browser_storage.gd
?? tests/test_compact_v6_browser_storage.gd.uid
?? tests/test_compact_v6_credit.gd
?? tests/test_compact_v6_credit.gd.uid
?? tests/test_compact_v6_gameplay_candidate.gd
?? tests/test_compact_v6_gameplay_candidate.gd.uid
?? tests/test_compact_v6_incremental_snapshot.gd
?? tests/test_compact_v6_incremental_snapshot.gd.uid
?? tests/test_compact_v6_performance.gd
?? tests/test_compact_v6_performance.gd.uid
?? tests/test_compact_v6_snapshot_package.gd
?? tests/test_compact_v6_snapshot_package.gd.uid
?? tests/test_compact_v6_storage.gd
?? tests/test_compact_v6_storage.gd.uid
?? tests/test_compact_v6_validation_reuse.gd
?? tests/test_compact_v6_validation_reuse.gd.uid
?? tests/test_compact_v6_windows_crash.gd
?? tests/test_compact_v6_windows_crash.gd.uid
?? tests/test_compact_v6_windows_guards.gd
?? tests/test_compact_v6_windows_guards.gd.uid
?? tests/test_compact_v6_windows_storage.gd
?? tests/test_compact_v6_windows_storage.gd.uid
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
