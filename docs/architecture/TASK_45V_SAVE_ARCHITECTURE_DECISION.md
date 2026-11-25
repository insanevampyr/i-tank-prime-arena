# Task 45V — Save architecture decision

18 November 2026. **DESIGN ONLY. Recommend B: snapshot + exact lifetime ledger. Owner approval required before implementation.** Task 45U remains paused. This document is the only project change in 45V. No tests, benchmarks, exports, storage operations or migrations were run.

## 1. Current-state diagnosis

The current V6 prototype is overengineered at the routine-save boundary. A smaller character record is coupled to a fully reversible portable history and repeatedly checked through several layers. This retains much of the old processing burden. It does not make source rules, ownership, exact duplicate prevention or independent readback unnecessary.

Keep the existing coordinator and engine. Separate ordinary transaction validation, cold verification and portable recovery/restore proof. Do not build another persistence authority or a general event-sourcing engine.

Evidence labels: **verified source** means inspected current code; **recorded measurement** means an existing disposable log/report inspected without rerunning it; **proposed** means unimplemented, with no measured performance claim.

The playable system still uses V2/V4/V5 persistence. S2/S3/S4/S5 are dormant/test-gated. Q's candidate builder and R's post-conversion fixed credit now exist; O's earlier absence findings are historical, not current missing features. No 45U optimization was installed: the S2 script's SHA-256 matches `%TEMP%/arena45u-candidate-before.gd`.

### Ordinary save call path — verified source

Categories: **A** new mutation authority; **D** duplicate/immutable-binding protection; **P** publication/acknowledgement; **C** cold integrity; **B** backup/import/restore/recovery; **R** repeated proof of unchanged input.

| Boundary | Current work | Actual requirement versus design choice |
|---|---|---|
| `playable_character_persistence.gd` ingest/checkpoint | Collect original events, purchases, awards, growth, items, resources and run/checkpoint; project/encode a legacy-compatible proposal. | A/D. Facts and legal boundaries are essential. A second full legacy-format serialization is an adapter choice. |
| `compact_v6_gameplay_candidate.gd:85 prepare()` | Coordinator authorization/hydration; copy cumulative evidence/current state; derive IDs/accounting; encode/full-validate and validate extension. | A/D/C. Preserve source-authorized effects and complete IDs. Full lifetime replay here does not imply it must recur at every later call. |
| Same file `:146 check()`, `:297 publication_request()` | Check owned handle, source, request, runtime, cursor/order and head; authorize again; decode candidate and validate endpoints/extension again. Repeated at prepare/commit/adopt. | A/D/R. Fresh authority/context checks stay. Repeated replay of exact owned immutable bytes is separable. No result-reuse optimization is installed. |
| `character_persistence_coordinator.gd:22 prepare_compact()`; browser coordinator `:130 _prepare()` | Validate current/capsule; decode candidate; compare projection/parent; construct transition. | A/D/P/C. Fresh parent and authorized delta are mandatory; repeated unchanged-state hydration is not intrinsically so. |
| `compact_v6_portable.gd:39 transition()`, `:96 export_record()` | Validate endpoints; diff records; copy transitions; decode current; reverse/revalidate all ancestry to sequence 1; encode full portable capsule. | B/R during routine saves. Required by the current capsule invariant, not inherently by character persistence. |
| Windows storage `:180 install()` and coordinator commit | Decode capsule, reload parent, stage/flush/reread/decode current and capsule, publish route, fully read/validate again. | P/C/B/R. Keep ownership, CAS, staging and exact readback. Repeated full portable replay is a design choice. |
| Browser `compact_v6_browser_store.js publish()` | Hash current/capsule/route; CAS exact route and relevant prior bytes; atomically write blobs/route; fresh readback. Godot cold-validates again and requests a fresh match. | P. Preserve the transaction and independent exact readback. They do not inherently require a portable file. |
| Windows `:123 load_current()`; browser storage `:80 load_current()` | Use capsule as proof/recovery even with intact current; reconstruct/check predecessor and current. Several callers repeat this. | C/B/P/R. Full cold validation and exact-current recovery stay. Making normal reads act like backup imports is not essential. |
| Shared service ack and S2 `:303 adopt_compact()` | Read current again; compare original request/projection/digests; acknowledge; decode candidate again for observer parent. | P/A/R. Exact acknowledged state and no effect replay are mandatory, not another replay of the same bound history. |

Core `encode():31` fully validates. `decode():39` checks bounds/canonical bytes and fully validates. `validate_extension():163` validates both endpoints. `_chronology():288` replays source-qualified purchase/growth evidence. Portable `verify_history():83` reverses every transition and validates endpoints. Nested calls multiply work.

Compact routine reads generally no longer replay the entire original 233-generation archive. They repeatedly process compact lifetime evidence and native compact ancestry. Both S4/S5 route layouts require a matching `capsule_digest`, and load verifies the complete capsule. Simply omitting capsule generation would break current readers/recovery. Decoupling requires an approved versioned layout, not a bypass.

## 2. Three architectures compared

Let S be current state, L exact lifetime IDs/bindings, E essential progression/ownership proof, H compact commits, k new effects. All can grow. The approximately 20-entry journal is not L.

| Concern | A — Current V6 | B — Snapshot + ledger (recommended) | C — Snapshot + append-only transactions |
|---|---|---|---|
| Routine save | Repeated full semantic and reverse-ancestry work. Demonstrated. | Authorize new batch; exact ID lookup; encode/hash/publish/readback current package once. Proposed. | Append resolved transaction and secure log/head; periodically checkpoint. Proposed. |
| Complexity | Repeated sum of validations across ancestor states plus serialization/copying. | New-effect checks can be proportional to k using an exact admitted map; complete encoding/I/O remains proportional to S+L+E. Not constant time. | Append may be proportional to k; indexing, checkpoint and compaction costs remain. |
| Cold load | Current proof plus full portable ancestry, often repeated. | Full current source/evidence validation once, exact map rebuild, head/compact receipt checks. | Verify checkpoint and replay committed tail exactly once; latency depends on tail. |
| Size/growth | Current, known previous, capsule/current copy, lifetime evidence and reversible history. | Current package + ledger/evidence + small commit receipts + latest repair replica. O(L+E), not fixed size. | Checkpoint + tail + lifetime evidence. Compaction cannot discard duplicate-prevention IDs. |
| Memory | Large strings, reverse states, dictionaries, bridge copies measured. | Avoid many historical states; still needs supported current package and validation workspace. Unmeasured. | Streaming possible, but compaction can hold old/new checkpoints, tail and indexes. |
| Windows | Stage/flush/route/fence implemented; stale leases blocked. | Reuse those primitives with a new layout. | Framed log, partial-tail/flush offsets, compaction cutover and retention add machinery. |
| IndexedDB | Disposable schema-2 route/blobs, Web Locks and CAS demonstrated. | Same transaction primitives can publish package/replica/head. Live upgrade remains gated. | Atomic append fits, but paging/compaction/multi-tab cutover remain new work. |
| Crash recovery | Exact latest from bound capsule demonstrated; no previous fallback. | Head-bound latest replica repairs exact current; uncertain ack reconciles original ID. Proposed. | Need committed-tail boundary, idempotent replay and crash-safe compaction. |
| Duplicates | Complete scoped lifetime IDs, bindings, rules/receipts demonstrated. | Same exact ledger; journal is convenience only. Membership does not require reconstructing old game events. | Same lifetime authority required; replay cannot issue fresh rewards/items/RNG. |
| END/HPB/WIS | Original event-time proof and full chronology exist. | Retain originals once; new growth uses event-time attributes; full cold/import verification. | Store original resolved outcomes/order; compaction cannot replace old attributes with current values. |
| Items/equipment | Origins, instances, quantities, consumed IDs, conditions verified. | Same essential facts and current state; atomic new ownership changes. | Resolved ownership/use outcomes must replay without duplication. |
| Backup/import | Current plus reverse ancestry; exact old-state reconstruction demonstrated. | Self-contained current/evidence + compact lineage receipts; new format and explicit restore trade-off. | Package checkpoint and committed tail at an exact boundary. |
| Future co-op PvE | Useful local coordinator, no network authority proved. | Same resolved-batch/identity boundary can consume future server outcomes. | May suit server logs, but local event sourcing does not create server authority. |
| Maintenance risk | Correctness evidence exists; severe performance failures known. | Moderate bounded boundary changes; most existing work reusable. | Highest: replay, compaction, log repair, version evolution and index/tail consistency. |

C is not recommended now. Raw writes are not the demonstrated dominant bottleneck. Adding replay and crash-safe compaction to avoid tens of milliseconds of I/O would address the wrong problem while adding substantial correctness obligations.

## 3. Expensive safeguards: risk and simpler alternatives

| Safeguard | Risk addressed | Defensible disposition |
|---|---|---|
| Full portable ancestry each save | Exact old-state reconstruction and current reversible restore contract. | Not a Prime character rule. Reserve existing full reconstruction for old-format import/conversion; B requires owner-approved current proof/receipt lineage instead. |
| Full validation at every layer | Changed/untrusted data and separate callers. | One private immutable checked representation per authorized operation, bound to source/rules/identity/namespace, parent, original request, candidate bytes and recovery references. Recheck mutable authority and fresh storage state. Never a caller flag. |
| Repeated old-parent hydration | Changed parents/forks. | Fresh bytes/head CAS against the verified admitted parent. Restart, changed source/rules or lost continuity requires full cold validation again. |
| Semantic replay on exact readback | Persisted candidate might differ or be invalid. | Independently compare exact persisted bytes/head to the coordinator's already validated sealed candidate. Different/imported bytes cannot borrow its result. |
| Current/previous/capsule copies | Exact recovery after current damage. | Latest primary plus one exact latest replica; no previous-state fallback. Hashes alone cannot recover data. |
| Reversible arbitrary full-record deltas | Reconstruct and check every intermediate checkpoint. | Not needed solely for duplicate prevention or mechanics. Removing this product guarantee needs explicit approval/versioning, not an optimization flag. |
| Lifetime IDs/bindings | Old rewards/purchases/items/credits rewrapped as new requests. | Keep full scoped IDs/bindings. No probabilistic membership, truncated hash, balance-only check or 20-entry FIFO substitute. |
| Event-time growth evidence | Later END/WIS incorrectly alters earlier HP/Mana; forged arithmetic. | Retain original dice/HD/flat/HPB, creation and before/after values, WIS and proven purchase order once. Validate new growth incrementally, all permanent proof cold. |
| Award/credit/ownership rules | Unsupported prices/rewards, grants and fabricated items. | Keep original rule functions and coordinator authority. Unique IDs and correct totals alone do not prove legitimacy. |
| Full legacy proposal in compact path | Reuse of old validation/authorization. | Keep initially; later shared typed compact projection/delta authorization can remove intermediate serialization. No JS rule rewrite. |
| Runtime ledger/proof duplication | Schema-12 checkpoint/replay semantics. | Separate serializer audit; do not automatically strip fields or change simulation snapshots. Materialize shared facts once where equivalence is proved. |
| Infinite legacy archive/downgrade obligations | Old saves and recovery options. | One verified conversion, originals untouched; compact-capable recovery build after activation. Universal old-build downgrade is not a default requirement. |
| Ownership/single-flight/CAS/old-writer fences | Competing publishers, stale/incompatible clients. | Keep. B does not solve Windows stale-lease ownership or justify stealing locks. |
| Size/UTF-8/canonical/hash/receipt checks | Malformed, truncated, corrupt or inconsistent input. | Keep finite limits and full changed/imported-data validation. A preview cache cannot authorize altered bytes. |

**Integrity is not authentication.** The available head is freshly read under ownership and compared with a verified admitted state. Its unsigned digest does not independently prove XP earning. Checks can detect corruption, accidental forks, duplicate operations and source-inconsistent values; they cannot authenticate a local user able to replace code/state/hashes. An embedded client secret or persisted `verified` field is not a trusted server.

## 4. Recommended B contract and operation boundaries

### Contents and authority

One current character and approved run/wave checkpoint; immutable source/rules/identity; exact lifetime operation/effect IDs and bindings; necessary awards, purchases, item origins/consumption, credits and original growth evidence; about 20 recent outcomes. Preserve current resources, Mana remainder, Running fatigue/timers, equipment condition and locked run policy. No competing wallet or new reward authority.

One current authority does not mean all evidence contains zero predecessor data. In particular, preserve the existing native fixed-credit predecessor witness unless a separately versioned smaller proof is independently established. Do not delete credit evidence to force a snapshot-count slogan.

Keep small **commit-lineage receipts within the lifetime transaction evidence**: identity/epoch/sequence, original operation/request binding, predecessor reference and exact record digest. They grow with commits; they are not reversible character snapshots, commands to replay, or claimed to fit in 20 entries.

Avoid digest cycles: a record cannot contain its own hash. Bind canonical character bytes first, then an external receipt/head referencing the record and predecessor; an outer package checksum can cover both. Exact field layout is future versioned work, not a contract activated by this review.

### Routine save

1. Full admission/cold verification establishes a private process-local current head and exact ID map. Nothing remains trusted merely because a prior process verified it.
2. Freeze the new resolved effects in original causal order. Existing coordinator verifies eligibility, rules/prices/affordability, run policy, new growth, ownership and the fixed credit's specific authorization. Same operation ID + same binding reconciles; conflicting bindings/reused semantic effects reject.
3. Build the new current snapshot and append proof/IDs without rewriting old facts. Verify changes equal authorized effects and derived consequences. Never reroll or reapply old growth/rewards.
4. Hold/acquire the existing exclusive writer and compare fresh head/exact parent. Changed parent/source/rules or missing trust continuity blocks publication or requires re-admission, not blind cache reuse.
5. Encode/hash the supported package once, publish current/repair replica/head atomically or recoverably staged, independently read back exact bytes/head, then acknowledge. Lost acknowledgement retains/reconciles the original transaction ID.

Full package serialization/readback remains proportional to S+L+E. Do not promise constant-time saves or immediately add persistent secondary indexes, Merkle trees or compaction machinery.

### Cold load and display

Read the committed route/current record; verify version, identity, trusted source/rules, checksums and full current lifetime proof. Reconstruct source-correct attributes/accounting, original END/HPB/WIS growth, ownership and checkpoint once; rebuild exact ID lookup and verify receipt/head bindings. Admit only afterward.

This may replay essential permanent evidence, but not every historical combat checkpoint/ancestor character. Existing full validators remain the independent correctness oracle. An already admitted Character Sheet reads the verified current projection without re-admission/history scanning.

### Recovery and physical redundancy

Recommend a primary plus **one byte-identical latest-state repair replica**, bound to the authoritative head and small publication metadata. The replica is complete data, not constant-size metadata. This is simpler than a previous checkpoint plus a durable replay tail and avoids passing an older character off as recovered progression.

Windows stages/verifies both new replicas before publishing one route and retains old authority during the uncommitted write window. IndexedDB publishes replicas/head in one transaction under the existing Web Lock. Fresh exact readback precedes acknowledgement. A valid replica repairs only the exact acknowledged digest; if neither copy can establish it, fail closed and diagnose/use an exact independently valid external backup.

Missing/conflicting committed-head evidence must fail closed; do not choose the highest filename/sequence. A replica is recovery data, not an external acknowledgement watermark.

Multiple complete **historical** snapshots are not intrinsically necessary. Recovery from current corruption does require data redundancy somewhere: mirror, reconstructible previous state plus durable delta, or external backup. A hash/recent journal cannot manufacture lost acknowledged data. Two copies on one physical device do not guarantee survival of total device/origin loss or every power failure.

### Portable backup and restore — explicit trade-off

A new B file is self-contained: complete current character, lifetime IDs/bindings and necessary progression/ownership/credit proof, source description checked against the trusted catalog, head and compact lineage receipts. It does not package every reverse-state delta. Pin export to an exact acknowledged head; fully verify imports without writes; restore only after explicit consent, destination ownership/CAS and exact readback.

- Empty destination: install a fully verified package without needing the original machine.
- Identical installed head: idempotent no-op.
- Older file against known newer progress: reject.
- Same sequence with different bytes, identity or epoch: reject.
- Newer file: require an exact known-head reference in verified incoming lineage, immutable receipt/evidence prefix equality, full current semantic validation and fresh destination comparison. Higher sequence/XP or familiar IDs alone are insufficient.
- Damaged current with intact head: repair only that exact acknowledged state, not a convenient old file.

Current `compact_v6_portable.gd:144 relationship()` reverses transitions and reconstructs the complete exact older record. Compact receipt linkage is **not equivalent to that stronger proof**. B intentionally drops automatic reconstruction/forensic rule validation of every intermediate resource/checkpoint state. Owner approval and independent fork/receipt-binding tests are required. Until the exact simpler descendant predicate is proven, keep nonidentical restoration over an occupied profile blocked; do not quietly replace the old rule with sequence comparison.

### Future cooperative PvE

Retain the coordinator's resolved-batch boundary and full profile/namespace/beneficiary/run/wave/source identities as applicable. A future authoritative PvE service can issue outcomes and arbitrate histories; local storage is an idempotent consumer. No server, networking, authentication, multi-profile atomicity or PvP is supplied by B or a local append-only log.

## 5. Reuse, conversion and versioning

Retain source catalogs/prices, growth/credit validators, P's exact ID work, S2 causal ordering/sealed request, S3 fixed authorization, converter/independent equivalence, shared admission/ack, S4/S5 ownership/CAS/fences and failure tests, canonical encoding and input limits.

Reduce repeated validation of one bound candidate/parent, full reverse-ancestry work on routine reads/writes, and synonymous state copies across the bridge. Keep the existing portable decoder as a compatibility/conversion oracle. Do not delete its implementation/artifacts or strip schema-12 runtime fields in the first B pass.

Existing legacy `_authorize()` still hydrates cumulative history; S2 serializes a legacy proposal; native credit reconstructs its source-qualified predecessor. These are explicit adaptation boundaries. Do not disable them wholesale or remove rule validation under a performance label.

### Legacy characters

One explicit bounded conversion under ownership: fully validate V2/V4/V5 source history once; preserve exact current state, IDs, original receipts/dice/growth and proven order; independently compare all attributes, equipment, resources, run/checkpoint/RNG, history and balances. No source computer dependency remains in the resulting portable proof. No rerolls, refunds or invented chronology.

Existing dormant V6 can be read with its full core/capsule validator once; derive lineage information only from genuinely validated records/commit evidence. A technical conversion baseline cannot pretend old legacy documents were new compact commits.

Keep original saves/backups untouched, recheck unchanged source head before activation and independently verify portable output. If conversion is ambiguous/unverifiable, stop. A separate owner-approved archived-development/fresh-slot option is reasonable; never overwrite an occupied identity or merge NORMAL and Legacy DEV. A failed manual export is not permission to discard valid automatic history.

### Format boundaries

- A new storage layout/minimum-reader version is required; S4/S5 route version 1 requires a capsule. Never label B as that unchanged layout.
- New portable version required; version 1 requires reverse-ancestry frames. Keep its decoder for legitimate old files.
- Reuse current V6 semantic record only if exact required evidence/encoding/full cold validation are unchanged. Changed fields/semantics require an audited unused inner/envelope version; do not silently repurpose V6 or assume an unused number.
- Production IndexedDB upgrade remains separately approved; only disposable schema 2 was tested. Generic stores may fit a new layout, but reader/upgrade fences still need audit; keep legacy stores untouched.
- After new-format progression, software rollback requires a compatible recovery build. Reopening an old conversion baseline would lose progress. Universal reverse migration/old-build downgrade is not promised.

## 6. Recorded performance and realistic expectations

No benchmark ran in 45V. These are inspected earlier disposable results, not predictions for B/C. Fixture depth, timing boundaries, warmup and machine load differ; unrelated rows are not an optimization comparison.

| Evidence | Result and interpretation |
|---|---|
| P exact-ID optimization | Native 10k extension median 4106 -> 935 ms, but full 1000-operation save only 3678 -> 3626 ms. One lookup did not solve end-to-end architecture. |
| S Windows release inventory stress | Later saves about 49.5–73.3 s. Different workload depth from T. |
| T release-WASM 1005-item workflow | Host save 37.478 s; coordinator 17.687 s; IDB write 50.3 ms/readback 5.7 ms. Host includes S2/adoption/diagnostics. Raw IDB writes are not the demonstrated dominant cost. |
| T final large portable/cold workflow | Load 10.735 s; export 5.883 s (codec 2.275); preview 2.937 s; restore 18.548 s; exact recovery 13.957 s. Several targets failed. |
| T memory/responsiveness | WASM capacity 1,084,030,976 bytes; largest owned renderer peak 1,448,693,760 bytes; maximum event-loop delay 25.792 s. Includes conversion/retained test contexts, not proof of an idle leak. |
| T separate large-portable after JS GC | JS used heap 12,925,560 bytes; WASM capacity 469,368,832 bytes; relevant renderer RSS 626,163,712 bytes. JS garbage and retained WASM capacity are different. |
| Paused U native Windows debug | Small saves 827.819/977.159/1143.386 ms; one converted-history save 8841.760 ms; one inventory save 63693.061 ms. No optimized comparison exists. |
| U corrected credited-only debug | A successful real checkpoint took 12731.262 ms, retaining native credit/advancement evidence. Separate run. |
| U actual release-WASM baseline | 38 outer checks passed. Inventory ordinary check 1748/1751/1905 ms versus frozen full-oracle 1738/1858/1892 ms: expensive duplicate work, not a measured improvement. |

U's first aggregate native run failed because the credited fixture attempted development outside legal downtime. Its 0.009 ms rejected request is **not** a valid save timing. Small/233/inventory samples completed; the corrected credited-only run passed. Earlier setup/parse failures are not passing baselines. S2 source is unchanged and no after-optimization result exists.

U browser `45u_save.total_ms` is **flush-only**, after candidate preparation and repeated ordinary/oracle probes. Its coordinator timer can include waiting for those probes. The 15.425-second loop delay includes batched oracle work; do not present it as an uninstrumented single-save freeze. T's workflow and U's native end-to-end timer provide clearer decision evidence. U's WASM capacity reached 622,592,000 bytes; no owner-tab memory attribution follows.

For B, removing repeated reverse-state work is a plausible improvement, **not a speed guarantee**. Full encoding/hashing, current proof, inventories and the exact ledger still cost time/memory. No 20-entry journal makes arbitrary lifetime data fixed-size. Avoid multi-second synchronous callbacks through bounded yielding where necessary; do not assume a second WASM worker solves authority or memory concerns.

Keep the owner's targets as gates on identical declared workloads: routine save/load ideally 1–3 s; export/preview under 5 s; restore under 10 s; no multi-second ordinary-save UI stalls or gigabyte transient allocations during ordinary play. Measure debug, Windows release and actual Edge release separately. Report sample counts, inclusive/exclusive boundaries and meaningful percentiles. There are no measured B or C performance results.

## 7. Smallest safe implementation sequence — not authorized here

1. **Approve B's contract first:** latest replica, reduced historical reversibility, receipt/occupied-profile restore rule, version fences and compatible-build rollback. This does not resume 45U.
2. **One isolated package/reader prototype:** reuse fully validated character records; add only versioned head/replica/lineage metadata. Prove standalone cold verification, exact repair, malformed/forged proof rejection and no older fallback. No live route.
3. **One trusted incremental transaction boundary:** actual S2/S3 events and existing coordinator rules; reuse owned immutable checked inputs only within the same process/operation. Verify IDs, authorized changes and chronology against the independent full oracle. Bind source/rules/profile/namespace/parent/request/candidate/recovery. No caller or persisted verification flag, second wallet or general credit API.
4. **Separate disposable Windows/browser adapters:** retain ownership/CAS/fences; publish latest replicas/head; fresh exact readback. Test interrupted writes/acknowledgements, stale writers and damaged current/replica/head. Do not steal Windows stale leases to pass.
5. **Portable/restore/conversion gate:** fully verify standalone B proof and exact known-head lineage. Until proven, reject nonidentical occupied-profile restore. Test older/newer/conflicting branches, changed receipts and missing source. Preserve old decoder and independently compare conversions; no owner migration.
6. **Matched performance/acceptance gate:** small, converted 233-generation, historical/native credit, all five purchases, interleaved END/WIS growth, 1000-item/ID workloads, successive genuine checkpoints, replay and corruption. Measure full mutation-to-ack and stages, bridge copies, loop stalls, RSS/heap/WASM, cold/portable/recovery. If targets fail, identify that cost; do not add indexing/paging/compaction speculatively.

Production activation and database upgrade remain separate authorizations. No wholesale engine rewrite, networking or C-style transaction-replay/compaction engine is recommended.

## 8. Security/recovery limits and owner decisions

No local unsigned architecture can prove earning against rewritten local code/data, detect rollback of an entire storage image, arbitrate independently modified offline copies as global authority, recover data after all replicas/backups are lost, guarantee browser retention, or establish physical power-loss durability from these tests. Trusted server outcomes/watermarks and independently held backups address different limits; another checksum does not.

Approvals needed before code:

1. Adopt **B**, explicitly dropping full reversible portable history as a mandatory ordinary-save guarantee.
2. Accept a primary plus one **latest exact replica**, rather than promising recovery from small metadata alone or loading an older state. External backups remain necessary.
3. Approve receipt-based lineage's reduced forensic guarantee for newer-descendant restore. Until the exact predicate/tests pass, fail closed on nonidentical occupied-profile restore. Never sequence-only replacement.
4. Approve new layout/portable versions and compact-capable-only recovery/rollback; audit version reservations before coding.
5. Authorize a bounded independent conversion when eventually wanted; if it fails, choose an explicit separate fresh slot/archive policy without overwriting the original character.
6. Define supported lifetime/item workload and measured hardware/browser targets. No unlimited-ID, fixed-size, constant-time promise.

Recommendation remains B, not an open-ended implementation menu. These decisions expose its trade-offs before engineering starts.

## 9. Git and preservation status

Only `docs/architecture/TASK_45V_SAVE_ARCHITECTURE_DECISION.md` is added by 45V. No implementation, test, benchmark, fixture, configuration or earlier document was edited. Task 45U remains paused; its five added files and three modified browser harness/test files are preserved.

Final verification and exact Git status follow.

### Verified preservation and exact status

- Checkout: primary desktop Arena repository; branch `main`, HEAD `f9bb0db0235b0003895c477a12346191d4714469`. The older export worktree was not edited.
- SHA-256 comparison: all **701 original nonprotected source/data/test/scene/document/config files** unchanged. The five snapshotted paused-U logs/snapshots remain byte-identical. No original file is missing; the only addition is this report.
- `project.godot` remains `8398f110f77d7712eb19c283eb9f745c7123feab9557187778da412639ba5692`, retaining its prior modification.
- Index empty; **29 modified tracked files and 125 collapsed untracked entries**. These are pre-existing changes plus this document, not implementation done by 45V.
- Protected boss document, `character saves/`, repository `tmp/`, owner backups and personal IndexedDB were not opened or modified. Git lists protected path names only. No production/fixture writes, tests, benchmarks, exports, Git mutations or cleanup. No resumption of 45U.
- Read-only source/log review, preservation hashes and report whitespace verification are this task's checks; historical test results are explicitly labeled above.

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
?? scripts/rewards/compact_v6_equivalence.gd
?? scripts/rewards/compact_v6_equivalence.gd.uid
?? scripts/rewards/compact_v6_fixed_credit.gd
?? scripts/rewards/compact_v6_fixed_credit.gd.uid
?? scripts/rewards/compact_v6_gameplay_candidate.gd
?? scripts/rewards/compact_v6_gameplay_candidate.gd.uid
?? scripts/rewards/compact_v6_portable.gd
?? scripts/rewards/compact_v6_portable.gd.uid
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
?? tests/test_compact_v6_performance.gd
?? tests/test_compact_v6_performance.gd.uid
?? tests/test_compact_v6_storage.gd
?? tests/test_compact_v6_storage.gd.uid
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
