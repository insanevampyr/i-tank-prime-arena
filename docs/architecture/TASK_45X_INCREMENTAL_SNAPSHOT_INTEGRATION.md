# Task 45X — Architecture B incremental snapshot integration

18 November 2026. **Complete: one isolated dormant implementation pass.** No playable activation, production Windows/browser publication, migration, restore authorization or export. Task 45U remains paused.

## 1. Exact task manifest

Added:

- `scripts/rewards/compact_v6_incremental_snapshot.gd`.
- `scripts/rewards/compact_v6_incremental_snapshot.gd.uid`.
- `tests/test_compact_v6_incremental_snapshot.gd`.
- `tests/test_compact_v6_incremental_snapshot.gd.uid`.
- `tests/compact_v6_incremental_process.gd`.
- `tests/compact_v6_incremental_process.gd.uid`.
- This report, `docs/architecture/TASK_45X_INCREMENTAL_SNAPSHOT_INTEGRATION.md`.

Modified:

- `scripts/rewards/compact_v6_gameplay_candidate.gd`: timing instrumentation in ordinary S2 preparation only. Authorization, event order, fields, encoding, extension checks and candidate bytes are unchanged.
- `scripts/rewards/compact_v6_snapshot_package.gd`: additional returned timing metrics only. No format, receipt, limit, validation or encoded-byte changes.
- `tests/test_runner.gd`: one X preload and suite registration. Previous registrations preserved.

Ten intended files including three UID sidecars. No production coordinator, codec, S3 rule/credit implementation, storage route, playable service, UI, combat or progression edits.

## 2. Authority and private context

Read V/W/Q/R/P and inspected the actual S2/S3 implementations, V6 validator and lifetime registry, existing coordinator and W package. X is an explicitly constructed in-memory observer. It accepts the real trusted playable service and a trusted host callback for fresh acknowledged package/head and ownership-witness reads. No imported verification flag supplies authority.

Admission fully cold-verifies W bytes/head against the trusted source, rules and exact target; S2 additionally requires complete projection equality with the service's independently admitted prior character. An empty baseline is permitted only for actual generation-zero creation and its original authorized first Wave 1 checkpoint. Source-invalid/imported data cannot borrow another context's result.

The private context contains:

- Exact service/source object identity, source digest, rules, profile, namespace and run. Object IDs are exact decimal **strings**, avoiding lossy JSON conversion of Godot's 64-bit reference IDs.
- Complete cold-verified parent record, canonical package/head bytes and ownership witness.
- Full exact lifetime binding lookup keyed by canonical `[scope, ID]` tuples, retaining complete immutable binding rows.
- Private S2 observer, original event cursor/order, actual prepared request and one owned pending sealed handle.

Every operation rereads the acknowledged parent/ownership witness and checks the actual service/source/run context. Changed source, profile, rules, ownership, parent or bytes invalidates the context. S2 rechecks the original authorized request, events and simulation state. A request changed after sealing invalidates the context permanently; restoring old input fields does not resurrect it.

S2's session snapshot omits the external player Running model. X therefore pins the actual movement provider at the existing ingest/capture boundary and separately seals/rechecks the existing S3 full runtime-plus-movement digest. It rejects changed movement/fatigue/timers or a missing provider without modifying that model or live S2 behavior. The original prepared checkpoint digest is also sealed.

The fresh callback is a **trusted-host freshness/ownership boundary**, not authentication or a new lock implementation. Tests model it with an in-memory witness and use the existing coordinator for all actual disposable legacy writes. This pass does not demonstrate production filesystem leases, Web Locks, CAS, power-loss durability or old-writer fences for Architecture B. Those still belong to future routing under the existing coordinator.

## 3. Original gameplay integration

Only isolated tests subscribe at the established ingest and `publish_prepared()` seams. No playable caller imports or constructs X.

1. Existing gameplay resolves effects and prepares its original checkpoint through unchanged persistence code.
2. X delegates ordered fact capture and candidate preparation to S2. The original coordinator's `_authorize()` remains mandatory; final balances never authorize a transaction.
3. S2 retains original defeat/award causality, purchase requests and exact chronological growth records. It constructs the next V6 record from the original authorized projection without rerolling or changing source rules.
4. X checks complete lifetime bindings and original evidence/operation prefixes, then calls the unchanged W package builder using the exact verified parent package/head.
5. X seals owned immutable package/head strings plus source/context, original S2 request/operation, checkpoint and byte-digest bindings. Returned copies and forged handles cannot replace the private pending operation.
6. Repeated preparation checks and returns that exact handle. A changed/stale context is rejected, rather than generating another request.
7. The test's **original legacy coordinator** publishes and verifies its original proposal. Only then does the host remember the matching package as its acknowledged witness. X requires exact package/head readback and S2's original verified acknowledgement before adopting the candidate and appending its new ID bindings to the admitted map.

X itself never writes or acknowledges storage. Lost observer acknowledgement reconciles the exact pending operation after the original coordinator has acknowledged it; it does not replay effects. No complete reversible portable capsule/transition is constructed, exported, decoded or traversed on this preparation path. Full semantic proof scans remain as described below.

## 4. Exact lifetime protection and evidence

The transient index uses full scoped IDs and full canonical binding rows. It is not encoded, truncated, probabilistic, inferred from balances or limited to the recent journal. Candidates must preserve every prior identity/binding; duplicates, missing IDs and altered bindings reject. The actual new coordinator operation ID cannot already exist. Only genuinely absent bindings are merged after verified acknowledgement.

Existing operations and award/purchase/growth/settlement/chronology prefixes must remain canonical-byte-identical. S2 and the full V6 validator preserve source-authorized historical credit predecessor materialization where its existing contract explicitly permits it. No new representation rule is invented by X.

The current record continues to hold all five attribute purchases, original END/HPB/WIS order and dice, XP/EXPM/EXPC expenditure and credit evidence, items/origins/consumption/equipment, currency, shield condition, run policy, resources and schema-12 recovery/RNG/movement/timers. Whole-projection equality is required, not a selected-fields balance comparison.

## 5. Native fixed credit and package construction

`prepare_credit()` delegates to the existing S3 typed fixed-credit adapter and original coordinator permit. The confirmation callback must approve the exact original quote. No new grant amount, target, ID, wallet or production UI is exposed. NORMAL and unsupported targets remain ineligible.

S3's existing storage-free observer mode is used deliberately. X separately pins the exact W head before and after consent. It does not fabricate an S4 version-1 storage head or reinterpret W's head version. Native credited records retain inner V6 version 2 and their complete original predecessor witness; historical credits preserve their original supported representation.

Package domain/version stays `itank_arena_snapshot_ledger:1`; head `itank_arena_snapshot_head:2`; receipts `itank_arena_snapshot_receipts:1`. Character envelope 6/inner 1 or 2 and all W limits remain unchanged. Each genuine successor appends one commit receipt bound to the actual parent, new logical/exact-byte digest and original S2 operation/request. Actual first creation produces the existing anchor. No reverse-state history is introduced.

The latest repair replica is byte-identical to the current package. An intact current can be admitted when its replica is missing/damaged; a newly prepared package supplies a matching replica. A damaged current must first undergo explicit W exact recovery and readback; X does not silently repair storage or fall back to an older state. Conflicting/missing heads fail closed. Occupied-profile restore authority remains false.

## 6. Independent correctness and test boundaries

Final Godot 4.7.2 native-debug results:

| Focused invocation | Printed checks | Result |
|---|---:|---|
| X remaining-cases partition, including original 233 archive | 146 assertions | PASS |
| X complete gameplay partition | 3 outer assertions, plus 580 reused original Q assertions | PASS |
| Original S2 Q regression | 912 assertions | PASS |
| W package/recovery regression | 86 assertions | PASS |
| Original full K V6 validator regression | 814 assertions | PASS |

The two X partitions cover the default full suite together. Counts are reported per invocation, not claimed as unique test scenarios; reused helper assertions execute inside the outer checks. No final failed or expected-failure assertions, script errors, leak reports or native warnings were found. Parse checks of the new adapter, test and fresh-process script pass. `git diff --check` and explicit ten-file whitespace/final-newline checks pass. Git still emits its pre-existing CRLF-conversion warnings for the already-modified playable service/runner; no conversion was performed.

Executed coverage:

- Actual fresh Wave 1, NORMAL x1, DEV x1/x10, original defeats/awards/growth and loot; complete independently unobserved legacy payload and simulation/RNG/event equality.
- Same commands/seeds produce identical canonical V6 candidate and W package/head bytes. Every ordinary acknowledged candidate is independently cold-verified and reencoded with the original full validator.
- All STR/DEX/SPD/WIS/END purchases, original END7 plateau/END8 HPB2, odd-WIS growth and later WIS purchase, original rolls/maxima, unchanged purchase-time HPC/resources, actual item acquisition/consumption/equipment and source-legal shield wear. The unchanged Q helper also checks the exact generation-backed growth/credit proof against original legacy history.
- Twenty-three genuine development checkpoints, lost acknowledgement, rejected old purchase/defeat IDs, cold RESUME with nonzero Running/recovery/RNG/Mana remainder, explicitly confirmed NEW RUN with unique ID and locked x1 policy, then a complete five-wave circuit and original blocked boss-reward policy.
- Historical V2/V5 credit conversion, native typed fixed EXPC credit with exact original confirmation/permit, no NORMAL credit authorization, +10,000 EXPC/zero EXPM, exact retry, full cold/replica verification, and 21 later genuine operations: the grant leaves the recent journal and still cannot repeat.
- A fresh 1,000-origin inventory fixture uses original world-item acquisition/receipt APIs. It retains 1,005 items and at least 2,025 exact IDs, prepares another genuine checkpoint, and matches an independent unobserved legacy control including generation and complete ownership state. No owner-earned loot is claimed for source-origin fixture acquisitions.
- Exact frozen original 233-generation archive: full source validation, independent conversion equivalence, original-coordinator fixture installation into a new disposable root, cold admission and two actual subsequent checkpoints. The pre-X W anchored package hash remains exactly `c8e6f1494e61ecdd04f859daf43e296076f1c3121b4496a835b6bc489851b670`, proving timing instrumentation did not change its format/bytes. No fake 233-generation fixture or whitespace padding.
- Duplicate/missing/changed scoped IDs and bindings, reused awards/purchases/acquisition settlements, changed source/request/owner/head/current bytes, forged/reordered event facts, changed external Running state, foreign sealed handles, cancellation and terminal invalidation after inputs are restored.
- Two actual valid legacy writers compete at one generation: the original coordinator admits only the winner; X cannot adopt the stale loser's package. Exact stored legacy bytes match the winner.
- Missing/damaged replica with intact current, next candidate's exact replacement replica, damaged current requiring explicit recovery, conflicting head authority and old-head rejection. No older fallback or occupied restore permission.
- A separate OS process reads only the W head/package/replica context and original legacy fixture in the unique disposable root, performs full cold admission and publishes a subsequent actual gameplay checkpoint through the original coordinator. This is a cold-restart native test, not browser acceptance.

Commands, primary repository root:

```powershell
$godot = 'C:/Users/mxz/Desktop/GoDot/Godot_v4.7.2-stable_win64_console.exe'
& $godot --headless --path . --check-only --script scripts/rewards/compact_v6_incremental_snapshot.gd
& $godot --headless --path . --check-only --script tests/test_compact_v6_incremental_snapshot.gd
& $godot --headless --path . --check-only --script tests/compact_v6_incremental_process.gd
$env:ARENA45X_CASE = 'remaining'
$env:ARENA45X_SHORT = ''
$env:ARENA45X_LEGACY_BUNDLE = (Get-Content -Raw "$env:TEMP/arena45s-frozen-bundle.txt").Trim()
& $godot --headless --path . --script tests/test_runner.gd -- '--suite=45X incremental snapshot'
$env:ARENA45X_CASE = 'complex'
& $godot --headless --path . --script tests/test_runner.gd -- '--suite=45X incremental snapshot'
& $godot --headless --path . --script tests/test_runner.gd -- '--suite=45Q gameplay candidate'
& $godot --headless --path . --script tests/test_runner.gd -- '--suite=45W snapshot package'
& $godot --headless --path . --script tests/test_runner.gd -- '--suite=45K compact V6 prototype'
git diff --check
```

The default X invocation runs both partitions. The original archive extension is explicit opt-in using the guarded frozen cache path; absence is printed as not executed. This task supplied it and executed it successfully. `ARENA45X_SHORT=1` is an explicit developer probe, not the complete acceptance matrix. No full registered regression or Web export ran.

Final logs: `%TEMP%/arena45x-remaining-final.log`, `arena45x-complex-guarded.log`, `arena45x-related-q.log`, `arena45x-related-w.log`, `arena45x-related-k.log`. The earlier failing iterations remain in `arena45x-full.log`/`arena45x-final.log`; they are not mislabeled PASS. The successful remaining-cases root is `C:/Users/mxz/AppData/Local/itank-storage-tests/compact45x_19036_4834622`; full gameplay root `compact45x_1168_4815141` in the same disposable directory. Process-restart artifacts stay under each root's `restart/`.

Tests use actual unobserved legacy gameplay as a control, full V6 cold validation/encoding, whole original payload equality, canonical package/head comparisons and complete simulation/RNG/event comparisons. The reused original Q gameplay assertions remain intact. The host preserves the legacy service's raw acknowledged representation and original generation behavior; cold comparisons independently decode the actual durable document.

Initial development failures exposed capture ordering in the test host and unsafe numeric serialization of object-identity pins. A native-ack test-helper assumption then caused a comparison failure. Normalizing the legacy host's in-memory prior view introduced an extra no-op generation, which the full control correctly rejected; that host change was removed. The complete original legacy-control helper is now used via its test-only start seam. No assertion was weakened, no progression fixture was relabeled valid and no production legacy behavior was changed.

## 7. Performance and memory

Timings below are **native debug** observations, not Windows release, Edge, routine storage latency or owner acceptance. X preparation does not include publication, persisted readback, browser bridge or IndexedDB. Samples are heterogeneous actual checkpoints, not repeated identical latency trials; no p95 guarantee is inferred.

| Workload | n | Capture median ms | Preparation median / max ms | ID/prefix median ms | Package median ms | Cold median ms | Replica repair median ms | Max package bytes |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| normal1 | 4 | 0.366 | 103.143 / 106.329 | 0.291 | 33.499 | 15.758 | 15.927 | 34,816 |
| dev_normal1 | 4 | 0.353 | 103.165 / 106.816 | 0.289 | 34.143 | 15.511 | 15.919 | 34,779 |
| dev_normal10 | 4 | 0.363 | 95.094 / 99.897 | 0.325 | 32.762 | 14.940 | 15.159 | 31,647 |
| native_fixed_credit_operation | 1 | 0.000 | 371.394 / 371.394 | 0.572 | 98.880 | 42.095 | 42.578 | 60,576 |
| native_credit | 21 | 0.201 | 282.238 / 319.509 | 0.766 | 123.588 | 46.244 | 47.167 | 107,712 |
| original233 | 2 | 0.305 | 883.374 / 886.968 | 5.040 | 371.425 | 142.578 | 141.707 | 241,556 |
| all-five + lifecycle | 61 | 0.236 | 520.512 / 839.727 | 2.149 | 218.487 | 90.336 | 91.119 | 351,189 |
| inventory: large operations only | 2 | 5.713 | 5102.167 / 6081.216 | 22.794 | 1907.856 | 1025.657 | 1102.064 | 2,107,596 |

One latest replica has exactly the package byte size. The large-inventory row excludes its three small setup checkpoints and shows its two genuinely large operations. Max lifetime IDs: 2,025; max items: 1,005. The exact current + replica payload at maximum is 4,215,192 bytes, plus the small external head; no portable ancestry file is needed.

For the original 233 workload, median stages were: existing coordinator authorization **34.625 ms**, causal selection/decoded-request checks **13.819 ms**, assembly **25.814 ms**, full validated encode **39.971 ms**, full endpoint extension **88.890 ms**, X ID/prefix check **5.040 ms**, W package **371.425 ms**, final S2 authority/full-proof recheck **261.299 ms**. Within W: candidate full decode **96.384 ms**, parent cold/extension **233.219 ms**, receipt **0.125 ms**, framing/head encoding **4.387 ms**. Total preparation median **883.374 ms**; the measured 879.781–886.968 ms includes unlisted outer seal/copy/hash work.

For the two large-inventory operations: preparation **4,123.117 / 6,081.216 ms**. Median S2 authorization **242.880 ms**, causal checks **133.371 ms**, assembly **216.311 ms**, full encode **236.428 ms**, endpoint extension **362.998 ms**; X ID/prefix **22.794 ms**; package **1,907.856 ms**; final full-proof recheck **1,671.493 ms**. W receipt median **0.216 ms**, framing/head encoding **36.695 ms**. The one-second preparation goal is not met for this workload; full repeated semantic/canonical proof dominates membership lookup.

Native fixed-credit preparation **371.394 ms** includes original S3 preparation **158.072 ms** and exact confirmation/quote checks; separate S3 authorization/assembly timings are unavailable because that existing function is monolithic. No fabricated sub-stage attribution. Cold credit verification **42.095 ms**, exact replica repair **42.578 ms**. Subsequent credited checkpoints have a **282.238 ms** preparation median.

The complete 61-checkpoint all-five/lifecycle workload measured **520.512 ms** preparation median, **839.727 ms** maximum; cold **90.336 ms** and repair **91.119 ms** medians. It retains original historical credits and later purchases/growth across run transitions.

Memory: successful remaining-cases process allocator **309,931,858 bytes** at completion, **1,662,578,022 bytes** peak. Largest observed OS peak working set while that process was running: **1,791,365,120 bytes**, a sampled lower bound on its eventual high-water mark. The all-five/lifecycle process allocator was **265,405,910 bytes** at completion, **419,079,530 bytes** peak. These include every preloaded registered suite, retained test-service snapshots/control sessions and original legacy-history validation; they do not isolate a single admitted X context. No allocation-stack attribution or leak conclusion is claimed.

Post-S2 package/seal live allocation median: original 233 **5,293,898 bytes**; large-inventory operations **43,108,464 bytes** (38,486,764–47,730,164). These observations show substantial transient/copying cost still exists. No Edge renderer RSS, JS heap, WASM capacity or browser responsiveness measurements were collected, and no owner-tab memory claim follows.

Raw successful stage data is in the `45X_METRICS` lines of the final logs; `%TEMP%/arena45x-remaining-metrics.json` contains their extracted remaining-case metrics. One-time conversion and original legacy coordinator I/O are outside the preparation timer. No before/after U speedup or complete-save latency is claimed.

Stage timings separate actual event/movement capture, S2 coordinator authorization, causal selection, construction, full validated encode, extension proof, exact ID/prefix checks, W package build, receipt/framing and final authority recheck. Cold package verification and exact-replica recovery are measured separately. Capture totals include actual ingest callbacks, not the gameplay command's combat execution time.

The existing codec forces full proof scans. S2 encode fully validates; S2 extension validates both endpoints; W build decodes the candidate and cold-verifies/extension-validates the parent; S2 final checks repeat full semantic validation. These scans are retained. Exact-map membership and semantic evidence append are incremental, but complete candidate/prefix work and serialization still scale with total retained proof. No broad validation cache, new persistent index or codec bypass was added.

Package stage timing categories do not account for every outer JSON/hash operation. S2 construction totals include their sub-stages. Do not add overlapping totals. Native allocation deltas in X's metrics begin after S2 preparation and cover package/seal work; they are not complete preparation allocation traffic or per-operation peaks. Aggregate allocator/process peaks include retained test sessions, snapshots, controls and legacy-archive validation.

No directly comparable end-to-end U speedup is claimed: U includes coordinator/publication/capsule/readback work and different command/record bindings. Its files/results remain preserved; no U benchmark or optimization was resumed.

## 8. Integration blockers and stop conditions

- Full scans remain costly, especially with large inventory/evidence. The one-second preparation target is a goal, not a validation exemption. Any operation-scoped validation reuse needs a separately approved proof boundary.
- The trusted acknowledged-head/ownership reader must later be connected to existing coordinator-controlled storage, with atomic/recoverable current+replica+head publication, fresh CAS and exact independent readback. X supplies none of those writer mechanisms.
- Adoption currently uses S2's existing verified service-acknowledgement seam. The legacy commit in this test is an independent oracle, not an approved production dual-write strategy. A future W route must prove its coordinator acknowledgement and service bookkeeping against exact W readback; existing S4/S5 route-specific acknowledgement cannot be silently reinterpreted. Canonical service views must also preserve original no-op/generation behavior.
- Cold verification stays mandatory after restart/import or changed source/authority. A persisted flag cannot restore trust.
- W's multi-step receipt-only semantic lineage limitation remains. No occupied-profile replacement authorization, history pruning or implicit reanchoring.
- Missing/conflicting acknowledged-head authority, lost latest current plus replica, unsupported source/evidence or changed context must stay fail-closed.
- No production activation/migration, Windows stale-lock recovery, database upgrade, browser/Windows routing, backup-control integration, multiplayer or public deployment was begun.

## 9. Git and protected data

Entry branch `main`, HEAD `f9bb0db0235b0003895c477a12346191d4714469`; empty index; 29 modified tracked paths / 132 collapsed untracked entries. A preservation snapshot covers 710 existing nonprotected project files and seven existing U diagnostics.

`project.godot` must retain SHA-256 `8398f110f77d7712eb19c283eb9f745c7123feab9557187778da412639ba5692`. Owner Vaelis, backups, IndexedDB, protected boss documents, `character saves/` and repository `tmp/` are not read or modified. Fixtures and logs are under the existing OS-cache test roots and TEMP, not owner storage. No Git mutations or exports.

Final branch/HEAD are unchanged; index empty; **29 modified tracked paths / 139 collapsed untracked entries**. Of 710 original nonprotected files, only the intended S2 timing additions, W returned metrics and test-runner registration differ. No original file is missing. All seven pre-existing U diagnostics match their entry SHA-256 values; U benchmark sources and earlier B–W work are preserved. All three new UID values occur exactly once in the source/test tree.

Removing the two X runner additions reconstructs the exact entry runner SHA-256 `a55a552d24ebc29c831d32b4a81e7d93b07eaede83c046478fcac7603c802508`. Existing registrations remain intact. `project.godot` retains its original hash above. No playable source imports the X adapter; all callers are isolated tests.

Exact final filename-only Git status (protected contents were not inspected):

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

**STOP after X.** No Windows/browser routing, owner migration, production activation, occupied restore, U resumption or subsequent implementation has begun. Automated native evidence above is separate from owner acceptance; no owner/browser acceptance is claimed.
