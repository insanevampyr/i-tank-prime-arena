# Task #46J — Compact v3 Edge/IndexedDB Publication and Recovery

## Status and scope

**Needs follow-up / BLOCKED. #46J acceptance is incomplete. NO-GO for the next controlled playable-integration planning pass.**

The isolated browser implementation exists and actual Edge release-WASM publication/readback ran. The strict native-original-source equivalence assertion fails. A pre-existing release-only Dodge mutation explains the differing simulation revisions and checkpoint binding. Combat changes are expressly excluded from #46J, so no combat correction, oracle normalization or acceptance bypass was made. Remaining browser cases are implemented test scaffolding, not verified features.

No playable activation, production export, production database access, owner-profile conversion or Git mutation occurred. Task #45U remains paused.

## Exact task-relative file manifest

The starting worktree was already extensively modified. “Modified” below means changed from the #46J entry hashes, not the much older HEAD.

| Change | File | Purpose |
|---|---|---|
| Modified | `scripts/rewards/minimal_character_transactions.gd` | Opt-in browser attachment, immutable pending publication/poll/cancel/readback, original source callbacks and wave continuation; same existing owner. |
| Modified | `scripts/rewards/character_persistence_coordinator.gd` | Six explicit dormant delegates; production dispatcher unchanged. |
| Added | `scripts/rewards/minimal_v3_browser_storage.gd` | Disposable Web-only transport and independent full v3 cold reader/repair state machine. |
| Added | `scripts/rewards/minimal_v3_browser_storage.gd.uid` | UID. |
| Added | `scripts/rewards/minimal_v3_browser_store.js` | Isolated IndexedDB/Web Locks/CAS transport, bounded request/poll payload ownership and disposable fault barriers. |
| Added | `tests/minimal_v3_browser_fixtures.gd` | Original-source native fixture/oracle exporter; historical and separately labelled 1,005-item fixtures. |
| Added | `tests/minimal_v3_browser_fixtures.gd.uid` | UID. |
| Added | `tests/browser/minimal_v3_wasm_harness.gd` | Standalone release-WASM RPC harness; no playable controls. |
| Added | `tests/browser/minimal_v3_wasm_harness.gd.uid` | UID. |
| Added | `tests/browser/test_minimal_v3_edge.js` | Own temporary project, release export, origin, Edge profile, CDP runner and metrics. |
| Added | `tests/browser/minimal_v3_edge_cases.js` | Strict native/source oracle and subsequent browser matrix; later cases NOT executed. |
| Added | `tests/browser/minimal_v3_lifecycle_cases.js` | Competing-tab, controlled reload and uncertainty cases; NOT executed. |
| Added | `docs/architecture/TASK_46J_V3_EDGE_PUBLICATION.md` | This partial-completion report. |

## IndexedDB layout and protocol

Code-inspected design; only the successful cases explicitly listed below have browser acceptance evidence.

- Database names must start with `itank-arena-disposable-v3-46j-`; no production default exists. Database version 1, one `characters` store with `profile` key. One row contains exactly `profile`, `head`, `current`, `replica`. There is no accumulated generation archive.
- The transport head uses its own `itank_arena_disposable_v3_browser_head` domain/layout 1, snapshot reader/record 3. It binds profile, namespace, trusted source digest, epoch, sequence, original commit ID, exact record byte count and SHA-256. Canonical head JSON and whole-body hash are independently checked in Godot. Snapshot v3 and all older codec semantics are unchanged.
- A Web Lock named from disposable database plus profile gives exclusive cooperating writer ownership. An in-transaction exact expected-head comparison provides CAS even if another caller changes the row outside that convention. No local revision is claimed as cross-process ownership.
- Hashing/other asynchronous preparation occurs before the IndexedDB transaction. One actual readwrite transaction, requested with `durability: strict`, installs the entire head/current/replica row. First publication compares against an empty selected head. Exact already-installed bytes are an idempotent retry, not a second gameplay action.
- Completion alone cannot acknowledge. The coordinator independently reads the committed row, fully decodes and cold-validates the snapshot against source rules, requires exact intended bytes/head/both copies, then performs another exact row comparison while retaining writer ownership. Only afterward does the original owner adopt the pending checkpoint. No runtime snapshot is reinstalled.
- The existing capture/request machinery supplies immutable pending bytes and genuine event/irreversible-ID evidence. An attempted publication keeps the original pending identity uncertain until reconciliation. Capture does not freeze gameplay for the asynchronous file operation. Mutations during an original wave transition remain subject to its original verified-entry boundary.
- Only one queued/unpolled bridge job is permitted per handle. Terminal polling drops its response payload. Disposal drains its own active request and releases its own Web Locks. Actual repeated-operation retention acceptance was not reached.
- Cancellation is restricted to the pre-publication phases and retains pending evidence; after dispatch, reconciliation is mandatory. Browser attachment excludes the Windows route. Simulated acknowledgement/automatic adoption cannot acknowledge an attached real transport. Original Windows guard behavior and error reason were preserved.

Neither `strict` durability nor successful readback is a universal hardware/power-loss guarantee.

## Recovery design and unexecuted matrix

The full cold reader selects only bytes matching the exact selected head digest and size, then verifies the semantic source-authorized v3 record. If one copy is damaged, repair compares the exact raw row/head in a readwrite transaction and writes the same selected bytes to both copies. If the head is absent/conflicting or both latest copies are damaged, it fails closed. It does not select by greater XP or sequence and has no previous-generation fallback.

| Case | Actual browser result |
|---|---|
| Empty disposable database + Web Locks cold reader | PASS |
| Initial head/current/replica publication + exact independent readback | PASS, NORMAL |
| Subsequent original wave-defeat and loot checkpoints | Publication/readback PASS; source equivalence FAIL afterward |
| Eligible DEV awards, all five attributes and chronological growth through this browser route | NOT EXECUTED; native source fixtures/tests pass separately |
| Corrupt current / corrupt replica repair | NOT EXECUTED |
| Both corrupt / missing or conflicting head | NOT EXECUTED |
| Forced post-put transaction abort | NOT EXECUTED |
| Quota | NOT EXECUTED; harness uses an explicitly injected QuotaExceededError with actual transaction abort, not real quota exhaustion |
| Lost response and exact retry | NOT EXECUTED |
| Real Page.reload before dispatch / after commit | NOT EXECUTED; these are planned actual reloads, not process-crash proof |
| Two actual tabs, stale expected head and Web Lock contention | NOT EXECUTED |
| Cancellation and gameplay continuing before earlier readback | NOT EXECUTED |
| NEXT WAVE, NEW RUN, cold resume, once-only credit after browser restart | NOT EXECUTED |
| Browser 1,005-item and repeated-disposal/memory matrix | NOT EXECUTED |

No actual Edge process-crash or hardware-power-loss result is claimed.

## Strict original-gameplay equivalence blocker

Native fixture generation uses real original gameplay twice: a verified-reload original control and the existing coordinator-owned v3 runtime. It requires full state/evidence equality before exporting its oracle; 10 assertions per namespace passed (20 total). An initial fresh-creation versus verified-reload fixture mismatch was corrected at the admission boundary; no field was ignored or normalized to force equivalence.

The final Edge run admitted the same source/seed/fixture and executed original defeat/loot commands. After three actual IDB commits, strict comparison failed:

- Snapshot body differs only at `/recent_journal/1/request_digest`.
- Full simulation differs only at `/actors/2/state/revision` (Edge 27, native 28) and `/actors/3/state/revision` (Edge 25, native 26).
- All other compared final simulation fields, RNG/event data and essential character evidence match in this case. This does not establish general parity.

Exact pre-existing source, `scripts/combat/combat_simulation.gd:5746`, `_apply_successful_dodge()`:

```gdscript
assert(defender_state.spend_movement(movement_cost), "Validated Dodge movement must remain spendable in the same transaction.")
```

In the release export, assertion expression evaluation is removed. `CombatActorState.spend_movement()` subtracts MR and increments `revision`. The omitted successful-Dodge calls explain the two one-step revision discrepancies; the original checkpoint request digest therefore also differs. End-of-wave movement reset can hide the resource difference in the final snapshot, but the revisions retain it. Source hash comparison proves this combat function was not changed during #46J.

Recommended separately authorized correction: execute the validated movement spend exactly once outside `assert`, retain an assertion on its result, and test actual MR spending, revision, event/RNG and checkpoint equivalence in native debug and release WASM. Do not change the storage codec or disregard the differing digest. That combat correction has NOT been implemented here.

Two #46J-only defects found during execution were corrected: the existing dormant checkpoint-failure path initially closed its owner on its own legitimately queued asynchronous pending result; it now recognizes only its exact owned pending request. Browser-next-wave continuation and pending NEW RUN support were added in the dormant helper but remain unaccepted because execution stops at the source-equivalence failure first.

## Tests and environments

- Native: Godot 4.7.2 Windows debug, `ed1daf0bf001b61586d9930840f2f1394092c079`.
- Browser: actual isolated headless Edge **157.0.4341.60**, V8 **15.7.11.7**, Windows 10; Godot 4.7.2 release WASM, Emscripten 4.0.20, single-threaded, no GDExtension. WebGL2 software rendering. Not owner Edge acceptance.
- The runner creates its own OS-TEMP project and user-data directory, serves a random loopback origin with no-store caching, and never attaches an existing browser or opens production IndexedDB. It copies tracked allowed assets only; protected boss DOC is excluded. The production project/export configuration and builds/web artifacts were not used or changed.
- Final isolated import/export completed with no Godot parser/script error. JavaScript `node --check` passed for all four new JS files.
- `git diff --check` passed; Git printed existing CRLF/LF notices for prior work in playable_character_persistence.gd and test_runner.gd, neither modified by #46J.

| Focused check | Result |
|---|---|
| 46C1 shared capture gate | 310 assertions PASS |
| 46C2 routine transactions | 95 assertions PASS |
| 46F temporary requests | 140 assertions PASS |
| 46H v3 coordinator, including fixed credit, five attributes/growth, NEW RUN and labelled stress | 306 assertions PASS |
| Native regression total | **851 assertions, 4 suites PASS** |
| Native fixture/control exporter | PASS, 20 independent source-oracle comparisons/assertions |
| Earlier standalone actual Edge/WASM preflight | 6 assertions PASS |
| Final actual Edge/WASM full-matrix attempt | **13 assertions PASS; assertion 14 FAIL** at complete native original-source current/evidence equality; later cases not reached |

The previous preflight and final run overlap; their counts are not an aggregate coverage count. The final run remains failing, exit 1. No full regression was run.

Reproduction commands (working repository):

```powershell
# Each is a focused registered suite, not a full regression:
& 'C:/Users/mxz/Desktop/GoDot/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/test_runner.gd -- '--suite=46H v3 coordinator'
# Other exact filters: 46C1 shared capture gate; 46C2 routine transactions; 46F temporary requests
node tests/browser/test_minimal_v3_edge.js
```

The browser runner deliberately fails on the untouched oracle. Its existing fixture input directory is recorded by `%TEMP%/arena46j-current-root.txt`; fixture generation is separate and rejects invalid/non-disposable output roots. Fresh fixture regeneration additionally requires the existing independently validated disposable inventory archive named in the fixture exporter; it is not an owner save.

## Measured timings, sizes and memory

Single final execution samples, not percentiles or general performance acceptance. Preparation, browser protocol, JS transaction completion and CDP wall timing use different boundaries. Crypto/hash/bridge/poll time is included in browser protocol totals, not the isolated transaction number.

| NORMAL case | Character prepare ms | IDB transaction ms | Cold readback validation ms | Browser protocol ms | Capture-to-ack ms | RPC wall ms |
|---|---:|---:|---:|---:|---:|---:|
| Initial selected record | admission 175.0 | 8.0 | 15.7 | 110.9 | N/A, no new capture | N/A |
| Defeat checkpoint, 12,852 bytes | 25.1 | 13.5 | 16.5 | 156.6 | 183.5 | 253.5 |
| Loot checkpoint, 14,118 bytes | 18.8 | 18.3 | 17.9 | 179.8 | 201.4 | 237.5 |

These completed storage operations precede the failed equivalence assertion and therefore are not full gameplay acceptance. The final selected row is one head plus two equal copies, not three generations.

Native #46H debug measurements in the focused regression: normal first-wave prepare 30.103 ms; native fixed-credit prepare 24.190 ms; five-attribute/growth prepare 34.531 ms; NEW RUN full-admission prepare 85.189 ms. Separate 1,005-item record: 1,107,597 bytes, cold admission 756.242 ms, prepare 594.433 ms. Native stress live/peak Godot counters were 288,623,492 / 306,447,742 bytes. These were concurrent regression processes and are not a matched native/browser benchmark or end-to-end save timings.

Final Edge fresh-release sample: JS used heap 10,984,916 bytes, total JS heap 18,350,080 bytes; observed WASM capacity 120,586,240 bytes. WASM capacity is not live allocated character memory. CDP returned multiple renderer processes; raw working-set samples were retained, but the runner did not establish exact target-to-renderer ownership. No single-renderer RSS, retention, peak-operation, post-cancel, garbage-collection or released-memory claim is made. Stress and final responsiveness samples were not reached. No comparison to the owner's 2 GB tab is supported by this partial test.

Final **isolated harness only** PCK SHA-256: `228131abb1e6c8ffe19f2e09220696db0b03b46b0ea8f75052f3cc77c0467e41`; PCK 3,510,504 bytes; WASM 39,514,754 bytes. No production BUILD was issued.

## Evidence locations and remaining work

All run evidence is disposable, outside the repository:

`C:\Users\mxz\AppData\Local\Temp\arena46j-24c0e0cdc70a42b985529d3216210f09`

Files: `import.log`, `export.log`, `partial-results.json`, `oracle-difference.json`, `fixtures/*_oracle.json`. The earlier `results.json` is only the earlier successful preflight, not the final full attempt. Final console/log: `%TEMP%/arena46j-final-edge.log`; native focused logs: `%TEMP%/arena46j-46h-regression.log`, `arena46j-46c1-regression.log`, `arena46j-46c2-regression.log`, `arena46j-46f-regression.log`. Baseline hashes/status: `%TEMP%/arena46j_baseline_ndgg7mc_/baseline.json`.

Required before accepting #46J: separately approve/fix the release Dodge mutation; rerun unchanged strict native/WASM equivalence; then execute and debug the still-unverified browser matrix, including DEV transactions/growth/credit, original run transitions, exact recovery, lifecycle faults, two tabs, quotas, cancellation, UI responsiveness and repeated-operation memory. A passing native suite cannot substitute for these browser checks. No production routing or next-stage integration should be enabled from this partial result.

## Git and protected-data preservation

- Branch `main`, HEAD `f9bb0db0235b0003895c477a12346191d4714469` unchanged. Index empty; no stage/commit/push/reset/stash/rebase/clean.
- Of 791 entry-hashed scoped existing files, only `scripts/rewards/minimal_character_transactions.gd` and `scripts/rewards/character_persistence_coordinator.gd` changed; no entry file missing. All other existing hashed source/tests/docs/native tools preserved byte-for-byte.
- Windows adapter/native helper, all snapshot/legacy codecs, source combat and gameplay rules, Roadmap and Combat Specification were not changed. No production caller selects the new route.
- `project.godot` retained its pre-existing modification and exact SHA-256 `8398f110f77d7712eb19c283eb9f745c7123feab9557187778da412639ba5692`.
- Protected boss DOC, `character saves/`, repository `tmp/`, owner backups and production browser data were not opened or modified. Their Git names can appear below without inspecting their contents.
- The original worktree contained 35 modified tracked files and 210 collapsed untracked entries. New source/test/report files remain unstaged; the task-relative manifest is above. Existing unrelated untracked material was not removed.

Exact final `git status --short`:

```text
 M project.godot
 M scripts/combat/arena_combat_session.gd
 M scripts/combat/character_development.gd
 M scripts/combat/combat_actor_definition.gd
 M scripts/combat/combat_actor_state.gd
 M scripts/combat/combat_clock.gd
 M scripts/combat/combat_simulation.gd
 M scripts/combat/deterministic_rng.gd
 M scripts/movement/prime_movement_model.gd
 M scripts/player/placeholder_player.gd
 M scripts/rewards/arena_reward_ledger.gd
 M scripts/rewards/browser_wave_candidate.gd
 M scripts/rewards/character_backup_contract.gd
 M scripts/rewards/character_backup_reader.gd
 M scripts/rewards/character_backup_restoration.gd
 M scripts/rewards/character_backup_task.gd
 M scripts/rewards/character_expc_grant.gd
 M scripts/rewards/character_level_progression.gd
 M scripts/rewards/character_persistence_coordinator.gd
 M scripts/rewards/character_profile_projection.gd
 M scripts/rewards/character_wave_checkpoint.gd
 M scripts/rewards/playable_browser_persistence.gd
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
?? docs/architecture/TASK_46B_MINIMAL_SNAPSHOT_CODEC.md
?? docs/architecture/TASK_46C1_SHARED_MUTATION_CAPTURE_GATE.md
?? docs/architecture/TASK_46C2_COORDINATOR_OWNED_ROUTINE_TRANSACTIONS.md
?? docs/architecture/TASK_46C_COORDINATOR_OWNED_ROUTINE_SAVES.md
?? docs/architecture/TASK_46D_COMMAND_EVIDENCE.md
?? docs/architecture/TASK_46E_COMMAND_RETENTION_AUDIT.md
?? docs/architecture/TASK_46F_STALE_REQUEST_RETIREMENT.md
?? docs/architecture/TASK_46G_COMPACT_SNAPSHOT_V3.md
?? docs/architecture/TASK_46H_V3_COORDINATOR_INTEGRATION.md
?? docs/architecture/TASK_46I1_WINDOWS_SAFE_REPLACEMENT.md
?? docs/architecture/TASK_46I_V3_WINDOWS_PUBLICATION.md
?? docs/architecture/TASK_46I_V3_WINDOWS_PUBLICATION_COMPLETION.md
?? docs/architecture/TASK_46J_V3_EDGE_PUBLICATION.md
?? docs/audits/TASK_45E_SAVE_LOAD_PERFORMANCE.md
?? docs/audits/TASK_45G_WEB_MEMORY_DIAGNOSIS.md
?? scripts/combat/arena_mana_recovery.gd
?? scripts/combat/arena_mana_recovery.gd.uid
?? scripts/rewards/character_capture_gate.gd
?? scripts/rewards/character_capture_gate.gd.uid
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
?? scripts/rewards/minimal_character_snapshot.gd
?? scripts/rewards/minimal_character_snapshot.gd.uid
?? scripts/rewards/minimal_character_snapshot_v2.gd
?? scripts/rewards/minimal_character_snapshot_v2.gd.uid
?? scripts/rewards/minimal_character_snapshot_v3.gd
?? scripts/rewards/minimal_character_snapshot_v3.gd.uid
?? scripts/rewards/minimal_character_transactions.gd
?? scripts/rewards/minimal_character_transactions.gd.uid
?? scripts/rewards/minimal_v3_browser_storage.gd
?? scripts/rewards/minimal_v3_browser_storage.gd.uid
?? scripts/rewards/minimal_v3_browser_store.js
?? scripts/rewards/minimal_v3_windows_storage.gd
?? scripts/rewards/minimal_v3_windows_storage.gd.uid
?? scripts/rewards/snapshot_command_evidence.gd
?? scripts/rewards/snapshot_command_evidence.gd.uid
?? scripts/rewards/temporary_character_requests.gd
?? scripts/rewards/temporary_character_requests.gd.uid
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
?? tests/browser/minimal_v3_edge_cases.js
?? tests/browser/minimal_v3_lifecycle_cases.js
?? tests/browser/minimal_v3_wasm_harness.gd
?? tests/browser/minimal_v3_wasm_harness.gd.uid
?? tests/browser/test_compact_v6_browser_edge.js
?? tests/browser/test_compact_v6_storage_edge.js
?? tests/browser/test_minimal_v3_edge.js
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
?? tests/minimal_snapshot_cold_process.gd
?? tests/minimal_snapshot_cold_process.gd.uid
?? tests/minimal_snapshot_commands_cold_process.gd
?? tests/minimal_snapshot_commands_cold_process.gd.uid
?? tests/minimal_snapshot_v3_cold_process.gd
?? tests/minimal_snapshot_v3_cold_process.gd.uid
?? tests/minimal_v3_browser_fixtures.gd
?? tests/minimal_v3_browser_fixtures.gd.uid
?? tests/minimal_v3_transactions_cold_process.gd
?? tests/minimal_v3_transactions_cold_process.gd.uid
?? tests/minimal_v3_windows_primitive_probe.gd
?? tests/minimal_v3_windows_primitive_probe.gd.uid
?? tests/minimal_v3_windows_process.gd
?? tests/minimal_v3_windows_process.gd.uid
?? tests/oracles/
?? tests/profile_compact_v6.py
?? tests/profile_compact_v6_costs.py
?? tests/profile_compact_v6_reuse.py
?? tests/temporary_requests_cold_process.gd
?? tests/temporary_requests_cold_process.gd.uid
?? tests/test_character_capture_gate.gd
?? tests/test_character_capture_gate.gd.uid
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
?? tests/test_minimal_character_snapshot.gd
?? tests/test_minimal_character_snapshot.gd.uid
?? tests/test_minimal_character_snapshot_v3.gd
?? tests/test_minimal_character_snapshot_v3.gd.uid
?? tests/test_minimal_character_transactions.gd
?? tests/test_minimal_character_transactions.gd.uid
?? tests/test_minimal_v3_transactions.gd
?? tests/test_minimal_v3_transactions.gd.uid
?? tests/test_minimal_v3_windows.gd
?? tests/test_minimal_v3_windows.gd.uid
?? tests/test_permanent_end_advancement.gd
?? tests/test_permanent_end_advancement.gd.uid
?? tests/test_snapshot_command_evidence.gd
?? tests/test_snapshot_command_evidence.gd.uid
?? tests/test_task_45d_dex_correction.gd
?? tests/test_task_45d_dex_correction.gd.uid
?? tests/test_task_45d_experience.gd
?? tests/test_task_45d_experience.gd.uid
?? tests/test_task_45d_mana_recovery.gd
?? tests/test_task_45d_mana_recovery.gd.uid
?? tests/test_task_45e_backup_integrity.gd
?? tests/test_task_45e_backup_integrity.gd.uid
?? tests/test_task_45g_release_scanner.py
?? tests/test_temporary_character_requests.gd
?? tests/test_temporary_character_requests.gd.uid
?? tests/test_windows_safe_head_replace.py
?? tests/windows_safe_head_bridge_smoke.gd
?? tests/windows_safe_head_bridge_smoke.gd.uid
?? tmp/
?? tools/
```

**NO-GO for the next controlled playable-integration planning pass. Stop for owner review; no automatic activation or further implementation.**
