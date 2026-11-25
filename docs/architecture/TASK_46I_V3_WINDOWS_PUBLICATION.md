# Task #46I — Compact v3 Windows publication prerequisite

2026-11-19. **BLOCKED at the explicitly required Windows head-publication safety gate. NO-GO for disposable Edge/IndexedDB integration as a continuation of completed #46I.** The publication implementation is not complete. No adapter or coordinator routing was added, and no durable request retirement is claimed.

## 1. Result and exact changed-file manifest

The task requires stopping if a safe head replacement protocol cannot be proven with existing primitives. Actual Windows testing demonstrated that the existing `DirAccess.rename_absolute(staged, head)` primitive can delete the previously acknowledged head and then fail to move the staged replacement. It cannot be treated as atomic head replacement. Successful normal-case readback and earlier S4 crash tests did not cover this failure inside the rename call.

Added only:

1. `tests/minimal_v3_windows_primitive_probe.gd` — standalone, bounded native Windows diagnostic; writes only newly created disposable OS-cache sentinel files and tests the original exclusive writer primitive. Does not open or create a character snapshot.
2. `tests/minimal_v3_windows_primitive_probe.gd.uid` — `uid://bs46iprimitive`.
3. `docs/architecture/TASK_46I_V3_WINDOWS_PUBLICATION.md` — this blocked-task report.

**No existing project file was modified.** The probe is deliberately not registered in the general regression runner: it characterizes a prerequisite failure, not a working v3 publication path. It should not be mistaken for an adapter acceptance test.

## 2. Audit and source evidence

Read the #46A, #46E, #46F, #46G and #46H reports and inspected the actual v3 codec, existing coordinator/transaction helper, request acknowledgement/capture paths, original Windows storage and dormant S4 adapter/crash helpers. The starting shell was in the clean, detached export worktree. The actual prior #46H changes reside in the original `main` checkout, which was inspected and used without moving or copying changes:

`C:/Users/mxz/Desktop/Projects/ITank Prime/Video Game/ITank Arena/i-tank-prime-arena`

Relevant original code:

- `character_save_storage.gd:_write_locked()` stages, flushes and reads a document, then renames to a previously nonexistent generation filename. That historical use is distinct from replacing an existing head; it was not changed or declared corrupt.
- `character_save_storage.gd:acquire_writer()/release_writer()/_owns_writer()` uses exclusive directory creation plus an original process-local owner binding. Unknown stale locks fail closed.
- `compact_v6_windows_storage.gd:_rename()` delegates to `DirAccess.rename_absolute()`. `install()` uses it to replace `route.json`; its existing capsule/fence layout is not reused for v3.
- `minimal_character_transactions.gd:prepare()/simulate_unknown()/simulate_ack()` owns immutable pending bytes and only nondurable acknowledgements. These methods remain unchanged. Their simulated responses cannot be promoted to durable results before verified storage publication/readback.
- `temporary_character_requests.gd:acknowledge()` retires the captured volatile request window and does not replace newer gameplay. No storage acknowledgement or acceptance-map pruning was added here.
- The v3 codec retains its approved domain/version, source-backed essential facts, exact irreversible identities and schema-12 checkpoint. No new package/head format was selected or activated.

### Exact installed engine source

The running executable identifies itself as **Godot 4.7.2 stable official**, hash **`ed1daf0bf001b61586d9930840f2f1394092c079`**. Upstream source fetched at that exact commit prefix confirms:

- [`DirAccessWindows::rename`, lines 319–325](https://github.com/godotengine/godot/blob/ed1daf0bf/drivers/windows/dir_access_windows.cpp#L319): for different source/destination paths, remove an existing destination first, then call `MoveFileW`. The removal and move are separate operations.
- [`FileAccessWindows::flush`, lines 353–359](https://github.com/godotengine/godot/blob/ed1daf0bf/drivers/windows/file_access_windows.cpp#L353): uses C `fflush`, not an explicit Windows device-cache durability barrier. This report does not infer hardware power-loss durability from it.
- The engine's internal backup-save close path uses `ReplaceFileW`, but `FileAccess.set_backup_save` is not bound as a GDScript method. Both upstream bindings and actual `ClassDB` inspection were checked. No global editor setting, engine configuration or `project.godot` change was made to try to expose it.

This is source evidence plus an actual failure reproduction on the installed executable, not a conclusion drawn only from generic filesystem documentation. It does not assert that no possible safe Windows protocol exists; it establishes that the repository's demonstrated GDScript head-replacement primitive is insufficient.

## 3. Actual Windows probe

Command from the original checkout:

```powershell
& 'C:/Users/mxz/Desktop/GoDot/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/minimal_v3_windows_primitive_probe.gd
```

Final evidence: `%TEMP%/arena46i-primitive.log`, exit code 0, **19 diagnostic assertions passed, failures `[]`**. A preliminary parse error used SceneTree's reserved `root` member; it was corrected to `test_root` in the new probe before execution. No existing test or rule was changed.

The sentinel strings are explicitly not character records or an invented save format. Final run used:

`C:/Users/mxz/AppData/Local/itank-storage-tests/minimal46i_primitive_15280_1355209`

| Diagnostic | Actual result |
| --- | --- |
| Stage, flush, close and independent exact-byte readback | Passed. |
| Ordinary staged replacement of an existing sentinel head | `OK` (0); new bytes read back. One sample: **840 microseconds**. |
| Keep the valid staged source open with actual `FileAccess.READ`, then replace an existing head | `FAILED` (1); **old head absent**, staged source still present with its exact bytes. One sample: **313 microseconds**. |
| Rename a nonexistent staged source over an existing sentinel head | `FAILED` (1); **old head absent**. |
| Runtime GDScript exposure of `FileAccess.set_backup_save` | Not exposed. |
| Original exclusive writer acquisition | Succeeds in the dedicated disposable root. |
| Competing storage instance | Rejected while the original owner holds the lock. This is a same-process, separate-instance check, not a cross-process contention matrix. |
| Copy the owner token to a different storage instance | Cannot release the actual owner's lock. |
| Release by the actual owner | Succeeds. |
| Drop the in-memory owner while its disposable lock remains, then reacquire elsewhere | Rejects. Unknown stale lock was not stolen or removed. This simulates owner loss; no OS process crash is claimed for this case. |

The assertions verifying destination loss establish the **blocker**; they do not mean that deleting acknowledged authority is accepted save behavior. No ordinary character, owner browser, backup or production path was used.

## 4. Disk layout and publication sequence — not implemented

The requested bounded design remains appropriate: head-selected current and exact replica, a small exact head descriptor, exclusive writer, and temporary new/previous pairs only during a commit. After verified maintenance only the latest pair/head should remain. No cumulative archives or receipts are necessary.

The intended sequence would be:

1. Existing coordinator owns a fresh capture and immutable v3 pending bytes.
2. Acquire exclusive storage ownership and compare the exact expected head/version/identity.
3. Write the new current and byte-identical replica to distinct staged locations; check errors and independent bytes. Do not overwrite the old head's pair.
4. Stage the small new head and replace the acknowledged head through a **demonstrated safe replacement primitive**.
5. Independently reread the selected head and both exact copies; reconcile original commit ID and bytes.
6. Only then acknowledge/retire the pending request window without reinstalling older runtime state.
7. Under ownership, verified bounded maintenance removes obsolete staging/previous files.

**Step 4 is blocked.** The existing remove-then-move primitive has a demonstrated failure window. Replacing the head using it would not meet the task's pre-publication preservation requirement. The presence of a newer staged file does not make it acknowledged authority. Selecting an older head, previous pair, greater sequence or highest-XP file would violate the fail-closed recovery contract.

Adding a two-head fallback, permanent intent/receipt history, speculative rollback or a hidden ancestry archive was not used to bypass this stop condition. No new head/reader format was implemented.

## 5. Crash and recovery matrix

| Required stage/scenario | Verified now / remaining |
| --- | --- |
| Before new pair staging | Design retains old head/pair; no v3 storage implementation tested. |
| During current/replica staged write; disk full | Not implemented/executed after stop. Original independent staging/error primitives are available but do not prove this new sequence. |
| Before replacing head | Old pair may remain intact, but safe transition of head authority is not demonstrated. |
| Inside existing head replacement | **Demonstrated prerequisite failure:** valid old destination is deleted before a move error. An abrupt interruption between those operations is a source-established risk, not a newly executed process-kill case. |
| After successful new head publication | No new v3 publication/cold-recovery test performed; cannot claim exact newly acknowledged-state recovery. |
| Lost response / exact retry | #46H nondurable identity behavior remains intact; real Windows reconciliation not connected or claimed. |
| Corrupt current with exact latest replica | Required future test; no new adapter to test. |
| Corrupt replica with intact current | Required future test; no new adapter to test. |
| Missing/conflicting head | Must fail closed; no fallback implementation introduced. |
| Unknown stale writer | Existing guard rejects, as the diagnostic confirms. Automatic reclamation remains unsupported. |
| Unsupported readers, incorrect expected head, cross-process races | Future adapter acceptance tests, not newly implemented. |
| Fresh-process source equivalence, NORMAL/DEV, NEW RUN, equipment/consumption, stress and no archive accumulation | #46H reported integration evidence remains unchanged. It was not rerun or presented as #46I durable publication proof. |

No crash/failed-write result is silently called an acknowledgement. The task stops before wiring `simulate_ack()` or any request retirement to real disk operations.

## 6. Timings, preservation and smallest safe follow-up

Only primitive timings above are new measurements. There are **no #46I measurements** for preparation, cold readback, recovery, complete acknowledged-save latency or the 1,005-item stress save, because no safe adapter was built. No browser/WASM/release, memory-peak or performance-goal acceptance is claimed. Prior #46H timings remain its native preparation evidence only.

The smallest recommended next authorization is a **Windows head-replacement primitive prerequisite**, with no coordinator/storage activation:

- Review a small native bridge exposing an appropriate Windows same-volume replacement operation with explicit failure/error handling and independent readback, including the initial no-destination case. Do not silently add a shell/process dependency or assume the API name proves every failure/power-loss behavior.
- Test actual Windows failed/locked source and destination, competing readers/writers, and abrupt process interruption before/during/after the replacement. Define the supported process-crash durability boundary explicitly; hardware power-loss guarantees require separate evidence.
- Preserve the previous head on known failures, or establish precise recoverable authority under a separately approved protocol. Missing/conflicting authority must never mean automatic fallback.
- Only after that proof, resume the existing #46I sequence with its original coordinator, expected-head CAS, exact pair/readback, lost-ack and stress tests. Do not create another coordinator or change v3 semantics.

A native bridge or alternate durable authority protocol is a new dependency/design choice; it was not implemented speculatively after encountering the explicit stop condition. No owner decision about giving up progression or converting a character is necessary to resolve this primitive issue.

## 7. Workspace and protected data

Branch `main`, unchanged HEAD `f9bb0db0235b0003895c477a12346191d4714469`. Index empty. Entry: **35 modified tracked / 195 collapsed untracked entries**. Final: **35 modified tracked / 198 collapsed untracked entries**, adding only the three paths above.

Entry baseline stored under `%TEMP%/arena46i_baseline_k_xin84q/baseline.json` hashes 775 scoped project source/test/document/configuration files. Final verification must retain all 775 byte-identically; none is removed. `project.godot` remains at SHA-256 `8398f110f77d7712eb19c283eb9f745c7123feab9557187778da412639ba5692`. The final appendix records exact Git status. This report's status is a full accumulated worktree inventory, not an approved staging list.

Protected boss file, `character saves/` and repository `tmp/` were observed only as status names; their contents were not read, hashed, modified or cleaned. No owner save, backup or production browser database was accessed. All prior #45/#46 work, including #46H and paused #45U, remains untouched. No gameplay, old reader/validator, production route, Roadmap, Combat Specification, configuration, export or Git mutation occurred. `git diff --check` and direct new-file whitespace/UID checks are part of final verification.

**Status: BLOCKED. NO-GO for disposable Edge/IndexedDB integration following #46I completion. STOP at the requested safety gate; publication and durable retirement remain unimplemented.**

## Exact final Git status

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
?? docs/architecture/TASK_46I_V3_WINDOWS_PUBLICATION.md
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
?? tests/minimal_v3_windows_primitive_probe.gd
?? tests/minimal_v3_windows_primitive_probe.gd.uid
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
