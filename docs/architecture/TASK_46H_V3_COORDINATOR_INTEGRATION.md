# Task #46H — Dormant compact v3 coordinator integration

## Result and continuation recovery

**Complete for the supported disposable, in-memory integration scope. GO for a separately authorized disposable Windows publication implementation.** This is not playable activation, a durable-save implementation, owner-character conversion, or proof of durable request retirement.

The interrupted implementation was inspected and continued, not rebuilt. Existing source-gameplay equivalence, historical/native fixed-credit work, and the compact v3 path were retained. Recovered logs `arena46h-sixth.log` (284 assertions) and `arena46h-seventh.log` (277 assertions) passed their then-current test revisions. The subsequent `arena46h-eighth.log` failed parsing before execution because `original_body` needed an explicit `String` type. The resume corrected that declaration in the new test only. Earlier development logs containing runtime script errors are not completion evidence, even if their runner printed PASS.

The final resumed suite passes **306 assertions**, including genuine NEW RUN, the remaining cancellation/stale-context acceptance cases, and the separate 1,005-item characterization. Original source authorization was preserved: an initial NEW RUN test setup incorrectly reused an unverified abandon checkpoint; the final control obtains the original authorization through verified reload. No production rule or codec validation was relaxed to accept it.

All requested supported integration features below are complete. The named 233-generation fixture remains explicitly **unsupported for v3 conversion**, because its historical item consumption lacks required original use identities. It is independently valid under the original V6 contract and correctly rejects under v3. No missing evidence was manufactured.

## Exact #46H file manifest across both sessions

| File | Change |
| --- | --- |
| `scripts/rewards/minimal_character_transactions.gd` | Adapt the existing dormant helper to explicit v3 admission, current-state preparation, essential facts, original item request contexts, fixed credit, NEW RUN, and nondurable acknowledgement. Preserve v1 behavior. This file already existed as untracked work before #46H. |
| `scripts/rewards/temporary_character_requests.gd` | Attach the existing request mechanism to the actual aggregate/capture owner; guard dispatch and completion; retain exact original issued handles through pending checkpoints. This file already existed as untracked work. |
| `scripts/rewards/character_persistence_coordinator.gd` | Add explicit v3 admission and fixed-credit/NEW RUN entry points to the same owner; delegate existing request APIs to that owner; reject overlapping standalone ownership. |
| `scripts/rewards/playable_character_persistence.gd` | Delegate dormant participant command guards to the admitted helper. Original source capture, authorization and receipt logic remain the authority. |
| `scripts/rewards/character_expc_grant.gd` | Extract the original runtime credit effect into `_apply_runtime(generation)`. The existing production publication path still requires its original verified response and acknowledgement before calling it. The disposable helper calls that same effect only after original fixed-credit eligibility and explicit confirmation. |
| `tests/test_runner.gd` | Add exactly the new suite preload and registration for #46H, preserving all earlier registrations. |
| `tests/test_minimal_v3_transactions.gd` | New original-source-backed integration, rejection, restart and measurement suite. Resume adds the explicit test-only `String` declaration noted above. |
| `tests/test_minimal_v3_transactions.gd.uid` | New test UID `uid://bs46htests`. |
| `tests/minimal_v3_transactions_cold_process.gd` | New fresh-Godot-process admission and irreversible-use rejection check, restricted to the named disposable cache prefix. |
| `tests/minimal_v3_transactions_cold_process.gd.uid` | New cold-process UID `uid://bs46hcold`. |
| `docs/architecture/TASK_46H_V3_COORDINATOR_INTEGRATION.md` | This completion report. |

No new snapshot format, codec version, coordinator, wallet, receipt chain or storage adapter was introduced. Existing v1/v2/v3 and V6 codecs/validators were not edited by #46H. Earlier changes in the broad working-tree diff belong to prior tasks, not this manifest.

## Coordinator ownership and authoritative capture

`CharacterPersistenceCoordinator.admit_minimal_snapshot_v3()` uses the existing `_minimal_owner`. Admission is opt-in, main-thread-only and restricted to OS-cache roots under `itank-storage-tests/minimal46c2_...`. It performs full original v3 cold decoding with the trusted source and exact profile/namespace. Default minimal admission remains v1. Standalone #46F ownership and aggregate ownership cannot overlap.

The helper owns one cold-validated current record, the actual original persistence service/session/player, one exact essential-ID lookup reconstructed from v3 facts, the existing shared capture gate, issued request contexts, and at most one immutable pending record. `_ids` stays empty on the v3 route: v1 operation arrays and duplicated persistent ID tables are not reconstructed.

Original `PlayableCharacterPersistence.checkpoint()` ingestion, original receipts/progression, and original session commands remain responsible for legality. A checkpoint acquires the existing legal capture scope, gathers the original checkpoint and external Running provider together, and releases the lease before encoding. New source events since the captured cursor append only genuine essential facts. Full unchanged v3 encoding/cold validation remains required; no cached verification flag replaces it.

The pending record contains current schema-12 checkpoint/resources/RNG/Running, original awards/purchases/growth/credit facts, immutable acquisitions and irreversible consumption, terminal ownership including zero quantities, real run IDs/policies, and at most 20 recent summaries. It contains no complete previous characters, generic lifetime checkpoint-operation array, equipment/handling transcript, historical potion-healing trajectory, W/X/Y receipt chain or ancestry capsule. Original simulator event/acceptance maps remain runtime source state; this task does not prune or optimize those maps.

Admission restores the complete terminal ownership map, not only positive-quantity inventory. Development serialization retains all permanent commands plus the source's latest preference, rather than a lifetime preference list. JSON-normalized string keys avoid the observed development-data serialization mismatch; the v3 codec was not changed.

### Original effects represented

| Path | Integration and evidence |
| --- | --- |
| XP, level growth and loot | Original source awards, settlement/provenance, rolled growth and causal order; EXPM/EXPC remain source-derived. |
| STR, DEX, SPD, WIS, END | Actual original purchase requests; original prices/allocation, receipts and chronological END/HPB/WIS witness; no fabricated final-balance transactions. |
| Acquisitions and consumption | Original item origins plus accepted irreversible request/resolved-event bindings; exact run-scoped membership checked before source effects or RNG. |
| Equipment/handling | Actual #46F issued handles authorize original commands; only current legal equipment persists, not permanent temporary-command transcripts. |
| Shield/currency/resources | Original current projections and source checkpoint validation; no second accounting engine. |
| Running, fatigue, cooldowns, RNG, Mana remainder | Joint session/player capture through the existing gate and original checkpoint; no movement reset on acknowledgement. |
| Fixed credit | Original fixed target, unique grant, exact amount and confirmation contract. +10,000 EXPC, zero EXPM; original shared effect; once-only after restart. |
| RESUME / NEXT WAVE / NEW RUN | Original verified admission, source run allocation, Wave 1 and subsequent source checkpoints, locked policy history and unchanged permanent identity. |

## Requests, pending state and simulated acknowledgement

The existing #46F helper binds actual aggregate ownership and its actual `Gate.Capture`. Entry and delayed completion use the originally issued handle; old callbacks do not receive a new context automatically. The irreversible-ID guard is inside dispatch, before the original source call. Exact retry in a still-valid context returns the cached result; conflicting bindings reject. Cold restart rejects a previously consumed ID even without the old temporary memo.

Checkpoint preparation seals the old request window and allows new gameplay in a new window. A later source checkpoint while one is pending is deferred, preserving exact pending bytes. Stow/draw, potion use, zero-direction Running and NEXT WAVE can continue according to original rules. Acknowledgement during active dispatch is deferred until the original result is cached and the dispatch returns.

`simulate_unknown()` requires a fresh owned capture. After it marks the exact pending operation uncertain, gameplay may advance. Exact simulated readback then advances only the aggregate's acknowledged record/cursor/read view and retires the old **volatile** request window. It does not reinstall an earlier actor, ledger, action, resource balance, external Running state or RNG, and does not replay rewards. A subsequent checkpoint captures newer runtime changes.

Known-unattempted stale captures cannot retroactively become attempted publications. Changed operation/revision/readback bytes reject. Uncertain operations cannot be canceled or disposed until reconciled; a known-unattempted cancellation adopts no new snapshot and requires readmission. Identity/namespace binding failures retire the v3 context; restoring a field cannot resurrect an old handle. Original accepted-ID maps are not deleted.

**Every acknowledgement in this prototype is explicitly nondurable.** No simulated outcome proves a Windows/IndexedDB CAS, writer lease, persisted readback, crash-safe head, durable context retirement or rollback protection across processes. These are requirements for a later storage task, not implemented behavior here.

### Genuine NEW RUN and credit

NEW RUN requires the current matched checkpoint, original abandon authorization, explicit confirmation bound to checkpoint/selected multiplier/current digest, and an unchanged revision/head. It calls the original `_open_existing_verified()` authorization before retiring the old request context, reuses the real run ID allocated by that original service, and prepares the genuine first Wave 1 checkpoint. It never invents IDs or changes global test settings in implementation code.

The final independent control uses original verified reload to pin abandon authorization. DEV changes from the original locked x10 run to a genuinely new x1 run; both run IDs/policies, epoch, namespace, permanent attributes, evidence, resources, original RNG and subsequent source-valued rewards compare correctly. NORMAL cannot select an unauthorized x10 policy. The NEW RUN control uses the original Player reset/profile APIs on both clients: the older generic Q test harness deliberately seeds its movement model differently, which is not a production NEW RUN defect.

Credit requires no pending checkpoint and exact current checkpoint/wallet matching the acknowledged character. The original fixed contract verifies the eligible legacy profile, original confirmation, and unique credit. The dormant result is `prepared_not_saved`; no production `_publish()` or fabricated durable response is used. Independent original `Credit.prepare()` and the original V6 native-credit builder agree with the resulting credit fact and XP accounting. Reconfirmation during pending rejects; after acknowledgement or cold restart it is the original no-op. The production grant delivery regression also passes after the small effect extraction.

## Independent acceptance and regression results

Executed on Windows, Godot **4.7.2 stable official `ed1daf0bf`**, native headless debug. Final runs have no test failures or script errors.

| Exact suite selector | Assertions reported | Final result | TEMP log |
| --- | ---: | --- | --- |
| `46H v3 coordinator` | 306 | PASS | `arena46h-resumed-final.log` |
| `46C2 routine transactions` | 95 | PASS | `arena46h-regression-c2.log` |
| `46F temporary requests` | 140 | PASS | `arena46h-regression-f.log` |
| `46C1 shared capture gate` | 310 | PASS | `arena46h-regression-gate.log` |
| `Task 43G EXPC grant delivery` | 93 | PASS | `arena46h-regression-grant.log` |
| `Task 36J-Pass2 persistence coordinator` | Suite does not print a count | PASS | `arena46h-regression-coordinator.log` |
| `Task 36J-Pass5 playable Vaelis persistence` | Suite does not print a count | PASS | `arena46h-regression-playable.log` |

Counted suites total **944 assertions**; the two original suites are additional and must not be assigned invented counts. Command form:

```powershell
& 'C:/Users/mxz/Desktop/GoDot/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/test_runner.gd -- '--suite=<exact selector>'
```

The new suite independently cold-validates each supported candidate and compares the complete original source simulation/event/RNG snapshot, external Running state, current character projection and essential evidence/order against separate original gameplay controls. Actual fresh Godot subprocesses admit the serialized record and reject already-consumed IDs before source calls or RNG. Same-process re-encoding/cold admission is not the sole restart evidence.

Specific final coverage includes actual acquisition, equip/unequip, stow/draw, downtime and active potion use, interrupted actions, zero terminal quantities, all five purchases, historical and native credits, END/HPB/WIS interleaving and original dice, repeated and conflicting requests, changed context/identity, stale and canceled captures, uncertain acknowledgement with newer gameplay, subsequent NEXT WAVE, genuine NEW RUN, immutable policy, and 23 real preference checkpoints with only 20 retained summaries. Source fixture observers' own failure collections must also remain empty.

In the cross-wave pending scenario the original control publishes two more checkpoints than the compact helper. The comparison asserts that exact generation-count difference **before** normalizing only the original publication count to v3's prepared-commit sequence for the projection comparison. No character, evidence, simulation or RNG differences are normalized away. The v3 sequence is not a reconstructed lifetime old-save archive.

The frozen 233-generation source is selected only from the prior disposable cache archive. Original V6 validation succeeds, but v3 rejects with `snapshot_v3_item_conservation` because original irreversible use IDs are unavailable. It was not admitted as an expected-success v3 fixture. The 1,005-item fixture is separately labelled stress and also comes from an existing disposable source-validated archive.

Additional checks: new test and cold-process script parsing, `git diff --check`, new-file whitespace and two UID uniqueness checks. Existing codec suites were not expensively repeated merely for unchanged codec files: the new integration suite directly executes the original cold validators and independent source/V6 comparisons. No full regression, release build, browser test or export was run for this continuation.

## Native preparation and memory measurements

Single final integration run, single sample per named workload. Times in milliseconds; encode includes the unchanged full v3 validation. Preparation is **not** storage latency. Admissions are initial cold-admission samples; repeated rows share their fixture's initial admission, not a fresh per-row decode.

| Disposable workload | Preparation ms | Encode ms | Encoded bytes | Initial cold admission ms |
| --- | ---: | ---: | ---: | ---: |
| NORMAL first wave | 16.819 | 8.969 | 14,118 | 11.305 |
| NORMAL equipment | 17.243 | 9.254 | 15,630 | 11.305 |
| NORMAL active use / zero quantities | 20.071 | 9.969 | 18,845 | 11.305 |
| NORMAL bounded journal | 21.405 | 10.441 | 20,781 | 11.305 |
| DEV first wave | 15.010 | 8.835 | 12,790 | 11.312 |
| DEV equipment | 16.478 | 9.395 | 14,297 | 11.312 |
| DEV active use / zero quantities | 17.898 | 9.443 | 16,607 | 11.312 |
| DEV bounded journal | 19.190 | 10.199 | 18,541 | 11.312 |
| Native fixed credit | 27.618 | 10.116 | 19,006 | — |
| Five attributes / historical credit / growth | 34.426 | 17.500 | 41,093 | 132.531 |
| Genuine new-run Wave 1 checkpoint | 27.654 | 17.864 | 41,045 | — |
| Genuine new-run awards | 32.976 | 19.481 | 45,649 | — |
| **Separate stress: 1,005 items** | **595.098** | **335.309** | **1,107,597** | **752.605** |

Full original NEW RUN admission plus preparation measured **96.187 ms**, separately from the Wave 1 checkpoint preparation above. Stress authorization/capture was 202.698 ms and construction 57.091 ms. Original ingest/receipts were 55.305 ms within the reported broader operation; do not sum overlapping instrumentation as independent total stages.

Sampled Godot allocator live memory in the final workload sequence ranged approximately **190,978,652–287,917,027 bytes**; sampled process allocator high-water mark was **304,417,995 bytes**. These include fixtures, original validators and retained comparison objects. They are not OS working set/RSS, a per-case allocation peak, retained-memory/leak proof, Edge renderer memory or WASM capacity. No browser/release/durable-save performance claim is made. Full cold CPU and copying still scale with essential inventory/progression facts.

## Remaining limits and publication prerequisites

1. Supported source evidence only: the 233-generation archive cannot recover missing original consumption IDs. Unsupported loss or unverifiable irreversible evidence must continue to fail closed. No owner conversion is authorized or claimed.
2. No persistent head/CAS or writer arbitration exists in this route. A Windows pass must independently prove current/replica binding, exact stored readback, crash/uncertain-ack reconciliation and monotonic acknowledged-head handling before durable retirement.
3. Local capture revision is not cross-process ownership. Simulated request-window retirement cannot justify pruning real acceptance maps or deleting records.
4. Full v3 codec verification is retained at preparation/admission; no incremental validator or browser performance acceptance is claimed. Keep stress measurements distinct from representative inventories.
5. The dormant credit modifies its disposable runtime before candidate acknowledgement, as ordinary gameplay effects do; it is not live grant publication. A preparation failure cannot be called saved; require readmission/reconciliation before any future storage retry. Production grants retain verified publication/readback before their original effect.
6. Cancellation can require readmission and refuses uncertain disposal. A later storage/UI task must preserve these explicit states rather than treating all errors as freely retryable fresh operations.

No remaining demonstrated blocker prevents a **separately approved disposable Windows publication pass for supported v3 fixtures**. Production activation, owner conversion and durable retirement remain NO-GO until that independent storage proof and later acceptance.

## Workspace preservation and exact final status

Branch `main`; unchanged HEAD `f9bb0db0235b0003895c477a12346191d4714469`; index empty. The prior session's recorded task-entry count was 35 modified tracked / 190 collapsed untracked entries. This resume began at 35 / 194, with the four new #46H test/UID paths present. Final report adds one path: **35 modified tracked / 195 collapsed untracked entries**.

A fresh resume baseline hashed 774 scoped project source/test/doc/config files. Of those, **773 remain byte-identical**; the only resumed existing-file change is the one explicit test variable type. No baseline file is missing. The report is the sole added scoped path during the resume. This confirms preservation during the resume; the earlier 770-file in-memory task-entry hash map was not available after interruption, so a new cryptographic comparison across the entire first session is not claimed. The combined intended manifest is listed above.

`project.godot` retains its pre-existing modification and SHA-256 `8398f110f77d7712eb19c283eb9f745c7123feab9557187778da412639ba5692`. Protected boss DOC, `character saves/` and repository `tmp/` were observed only as unchanged Git status path names, never read, hashed or modified. No owner saves, real backups or browser storage were accessed. Tests use original disposable OS-cache fixtures. No staging, commit, push, reset, stash, rebase, cleanup, production export, storage integration or #45U resumption occurred.

Exact final `git status --short` follows in the generated appendix. These are the entire pre-existing worktree plus the explicitly listed #46H files, not a staging manifest.

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
?? tests/minimal_snapshot_cold_process.gd
?? tests/minimal_snapshot_cold_process.gd.uid
?? tests/minimal_snapshot_commands_cold_process.gd
?? tests/minimal_snapshot_commands_cold_process.gd.uid
?? tests/minimal_snapshot_v3_cold_process.gd
?? tests/minimal_snapshot_v3_cold_process.gd.uid
?? tests/minimal_v3_transactions_cold_process.gd
?? tests/minimal_v3_transactions_cold_process.gd.uid
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
?? tmp/
```

**GO for a separately authorized disposable Windows publication implementation using supported v3 evidence. STOP after #46H; no automatic continuation.**
