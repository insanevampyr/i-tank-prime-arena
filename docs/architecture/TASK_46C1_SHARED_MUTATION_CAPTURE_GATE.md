# Task 46C-1 — Shared mutation and character capture gate

18 November 2026. **Complete: dormant prerequisite only. GO to resume 46C under the trusted gameplay-API contract below.** No routine aggregate, new save format, storage writer or playable activation is included. 45U remains paused.

## 1. Exact task manifest

Added:

1. `scripts/rewards/character_capture_gate.gd`
2. `scripts/rewards/character_capture_gate.gd.uid`
3. `tests/test_character_capture_gate.gd`
4. `tests/test_character_capture_gate.gd.uid`
5. `docs/architecture/TASK_46C1_SHARED_MUTATION_CAPTURE_GATE.md`

Modified existing files:

6. `scripts/combat/arena_combat_session.gd`
7. `scripts/combat/combat_actor_definition.gd`
8. `scripts/combat/combat_actor_state.gd`
9. `scripts/combat/combat_clock.gd`
10. `scripts/combat/combat_simulation.gd`
11. `scripts/combat/deterministic_rng.gd`
12. `scripts/movement/prime_movement_model.gd`
13. `scripts/player/placeholder_player.gd`
14. `scripts/rewards/arena_reward_ledger.gd`
15. `scripts/rewards/browser_wave_candidate.gd`
16. `scripts/rewards/character_expc_grant.gd`
17. `scripts/rewards/character_level_progression.gd`
18. `scripts/rewards/playable_browser_persistence.gd`
19. `scripts/rewards/playable_character_persistence.gd`
20. `tests/test_runner.gd`

Total: **20 files**. The existing coordinator, 46B codec, formats, database code, source catalogs and rules are unchanged. The runner gains exactly one preload and one suite registration; earlier registrations remain intact.

The mechanism is small, but covering the existing API surface requires explicit entry guards: **180 scoped mutation entries across 13 scripts**, one original session checkpoint notification and exclusion of process-local ownership from browser candidate copying. No original method is renamed, no original statement is deleted/reordered and no rule body is rewritten. The one appended Running return enum value is `CAPTURE_BLOCKED`; all existing enum ordinals remain unchanged.

## 2. Audit and covered mutation paths

Read 46A, 46B and the 46C stop report; re-inspected actual runtime, player/model, coordinator/service, ledger, progression, fixed-credit and controller/candidate paths.

| Path | Coverage |
| --- | --- |
| Session commands and advancement | Opt-in entry scopes on original public mutators, including START/reset, wave commands, advancement/development, inventory/equipment/handling/loot, NAC and special commands. |
| Simulation changes | Original public mutation entry points, including action/defense/damage resolution, event processing, position changes, reward/arena snapshots, timed effects, NAC, shield cancellation, actor registration and source/resolver changes. |
| Clock and deterministic RNG | Their mutating APIs participate directly, preventing clock/RNG changes even when called below the session façade. No additional draws. |
| Player Running | Both the player physics entry and actual model mutators are covered. Zero-direction recovery is guarded; input locking alone is not used as a freeze. |
| External profile/lifecycle | SPD/END/MR profile refresh, player motion restore/reset, prone and position changes participate. Replacing a bound object/provider invalidates the context and requires explicit rebind. |
| Player actor methods | Actual movement-budget/position methods and verified permanent-attribute/equipment modifier methods participate; nested calls remain one synchronous command. |
| Ledger and growth | Original defeat/collection/purchase entries and direct level-growth entry participate. Original dice, END/HPB/WIS, costs and accounting bodies remain untouched. |
| Existing service lifecycle | Admission, restoration, bind, ingest/items, checkpoint and acknowledgement entries are covered when explicitly bound. Browser overrides also participate. Existing storage/routing logic stays unchanged. |
| Fixed EXPC grant | Original confirmed publication callback is covered, including its direct actor/ledger writes. Consent, target, amount and exactly-once rules are unchanged; no grant is issued by this task. |
| Browser cloning | `BrowserWaveCandidate.copy_data()` excludes only `_character_capture_gate`. A new candidate must not inherit another runtime's local lock/revision ownership. Existing browser transport/freeze/restore rules remain unchanged. |

### Supported ownership contract and limits

This is a **main-thread, trusted internal gameplay-API boundary**, consistent with 46A. No playable caller binds it; only the new disposable suite does. All participants default to a null gate. Unknown movement/provider participants fail binding rather than being treated as covered.

The gate does not make every public Godot Dictionary or Object magically immutable. Existing raw actor/ledger/source references still exist for legacy internal code. The audited direct writes occur within the newly guarded original transactions/restoration/grant paths. New code must use those guarded paths; arbitrary reflection, unreviewed direct Dictionary assignments, custom overriding writers and foreign-thread edits are not authorized by this contract. **If future 46C code exposes mutable admitted state or introduces a write outside these paths, the GO no longer applies: stop and extend the narrow mutation audit.** This is not an anti-cheat or general interception framework.

Enemy mutations through the original simulation/session methods are guarded. Direct player actor method access is additionally guarded because player state is the persistent character. There is no new authorization for arbitrary external editing of NPC objects, battlefield dictionaries or source definitions.

## 3. Gate acquisition and capture

- `bind(session, player)` explicitly binds one existing runtime, ledger, clock/RNG, external movement and RNG, player actor/state, and optional original playable service. It checks the exact provider method and refuses already-bound or unsupported participants.
- Mutators with a null gate execute their unchanged original bodies. With a gate, a local RefCounted mutation scope increments the private revision and active depth. Its destruction releases depth on return; nested source calls are allowed.
- Accepted mutation **attempts** conservatively increment revision, including failed/no-op attempts. This deliberately favors false invalidation over missed changes. A mutation rejected because capture is held changes neither gameplay state nor revision.
- Public `capture(phase)` acquires, collects synchronously and releases before returning immutable bytes. READY entry, authoritative downtime and completed-run presentation are allowed; active-wave manual captures are rejected. Player action-in-progress also rejects.
- `acquire()/collect()/cancel()` expose the same lease for focused host/test use. A foreign lease cannot collect. Cancellation or dropping the only lease releases the lock. Callers must not retain a lease across encoding, I/O or await; ordinary use should call synchronous `capture()`.
- Collection takes session, reward ledger and external player motion as one logical state, then owns one JSON string. It executes no await, custom resolver, signal or arbitrary provider callback. Returned maps are freshly parsed copies; caller assignment cannot replace captured bytes.
- Worker-thread capture and bound mutation API execution reject before touching gameplay. No cross-process ownership is inferred.

### Exact original checkpoint seam; no deferred relabeling

An opt-in notification in `ArenaCombatSession._checkpoint_character()` captures **at that existing checkpoint call**, while the surrounding trusted command owns its mutation scopes. It locks all participants during collection and immediately releases them.

It must not delay a downtime request to command return: NEXT WAVE may retire/register actors, draw RNG and start the next wave or AI before then. An intermediate deferred approach was rejected and removed. Tests now require the original downtime capture to become stale when NEXT WAVE continues; it is never relabeled as a later entry state.

For an actual disposable admitted legacy character, the real `next_wave_entry` seam captures external movement equal to the original schema-12 checkpoint. With later AI disabled, the captured simulation matches the final original simulation. Later legacy service mutation attempts conservatively invalidate the handle even when simulation values happen to remain equal. A future 46C owner must arrange its authorization/capture order; this gate does not remove that requirement or claim a successful legacy save makes a capture current.

No routine frame/tick serializes another capture. The unbound production path contains no capture construction. Manual/explicit checkpoint capture is the only serialization performed by the new helper.

## 4. Revision, pending and invalidation contract

| Situation | Defined behavior |
| --- | --- |
| Capture complete, gameplay immediately resumes | The lease is already released; original gameplay proceeds. Any admitted mutation attempt changes revision, making the earlier capture ineligible as current. |
| Request to capture during a half-complete transaction | Public acquisition rejects while mutation depth is nonzero. The original safe checkpoint notification is the deliberately restricted internal seam. |
| Repeated use of unchanged issued capture | Same immutable bytes remain available; no effects are executed. Only the gate's actual latest issued handle can be current. A caller-created byte-identical handle is rejected. |
| Failed/no-op command after capture | Conservatively stale, even if final values equal. The future coordinator must not call mutators just to verify freshness. |
| Changed participant/provider | Mismatch invalidates the binding and revision. Restoring the old provider cannot resurrect authority. Explicit unbind/rebind creates a fresh local context. |
| Capture cancellation/interruption | No character change is adopted, no gameplay rollback occurs, ownership releases. Subsequent valid capture works. |
| Lost publication acknowledgement | This gate neither publishes nor acknowledges. Retain the exact immutable pending bytes in the future coordinator and reconcile actual readback/commit identity; do not rerun the gameplay command. Tests model retaining those bytes unchanged after a missing notification and after newer local gameplay invalidates freshness. |
| Old capture versus newer local state | `is_current()` rejects, including after explicit rebind. |
| Newer state from another process/tab | Local revision cannot detect/protect this. Windows/Edge writer ownership, expected-head CAS and exact readback remain mandatory later work. |

No durable flag, receipt chain, imported revision, caller-provided verified flag, new wallet or parallel character authority was added.

## 5. Focused verification

Godot **4.7.2 native headless debug**, disposable fixtures only.

| Suite | Assertions reported by suite | Result |
| --- | ---: | --- |
| New 46C1 shared capture gate | **310** | PASS |
| Existing 46B minimal snapshot (standalone) | 227 | PASS |
| Existing permanent SPD | 741 | PASS |
| Existing permanent END | 2,443 | PASS |
| Existing 45D Mana recovery | 104 | PASS |
| Existing playable browser persistence | Not enumerated by runner | PASS |
| Existing two-client synchronization | Not enumerated by runner | PASS |
| Existing Prime movement | Not enumerated by runner | PASS |

**8/8 focused suites PASS; zero final failures.** The five suites with reported counts total 3,825 assertions; this is not an invented total for the other three suites. Final logs contain no script errors, warnings or leak reports.

The new suite exercises actual model/session/simulation/ledger/actor mutation boundaries, all five real purchase paths, zero-direction recovery, untrained Running maintenance RNG, source-defined timed expiry and Mana recovery, NAC priority, actual equipment/consumption/development, exact session-plus-motion capture, wrong-handle rejection, explicit/drop cancellation, worker rejection, reentrant acquisition rejection, changed-provider terminal invalidation, browser physics freeze/restore, clone ownership isolation, no per-frame capture and actual disposable legacy DEV admission/NEXT WAVE. Original gameplay controls and independently seeded gated clients require complete simulation/ledger/motion equality. Captures add no authoritative event or RNG draw.

Fixture distinctions:
- Purchase tests use explicit disposable funding without claiming those balances as earned reward evidence.
- Wounded/current-resource and one source-defined potion setup occur **before binding**; the actual consumption/development methods then execute unchanged.
- Replay controls use zero injected award funds and genuine source XP/loot/growth through original combat.
- The admitted DEV fixture uses the original disposable legacy service with the earlier compact observer disabled. It does not activate 46B or a new writer.
- JSON comparisons compare complete JSON projections on both sides, accounting for Godot's integral-JSON-number float representation. No field or outcome is omitted.

During development, malformed test call signatures and an incorrect fixture initializer caused parse/setup failures; those were corrected in the new test. Wrong assumed starter gear/potion/preference names were replaced with actual source-defined fixture setup and valid commands. The deferred checkpoint approach failed the precise boundary audit and was removed as described above. No existing test or rule was weakened. Intermediate logs are retained and are not reported as successful runs.

Commands (repository root):

```powershell
$Godot='C:/Users/mxz/Desktop/GoDot/Godot_v4.7.2-stable_win64_console.exe'
& $Godot --headless --path . --check-only --script scripts/rewards/character_capture_gate.gd
& $Godot --headless --path . --check-only --script tests/test_character_capture_gate.gd
& $Godot --headless --path . --script tests/test_runner.gd -- '--suite=46C1 shared capture gate'
& $Godot --headless --path . --script tests/test_runner.gd -- '--suite=46B minimal snapshot'
& $Godot --headless --path . --script tests/test_runner.gd -- '--suite=Task 43B permanent SPD advancement'
& $Godot --headless --path . --script tests/test_runner.gd -- '--suite=45B permanent END'
& $Godot --headless --path . --script tests/test_runner.gd -- '--suite=45D Mana recovery'
& $Godot --headless --path . --script tests/test_runner.gd -- '--suite=Task 36K-Pass2 playable browser persistence'
& $Godot --headless --path . --script tests/test_runner.gd -- '--suite=two-client synchronization'
& $Godot --headless --path . --script tests/test_runner.gd -- '--suite=Prime movement'
git diff --check
```

Final new log: `%TEMP%/arena46c1-completion.log`. Related logs: `arena46c1-46b.log`, `arena46c1-{43spd,45end,mana,sync,movement,browser}-final.log`. Script parsing also occurs in each runner invocation. No full regression, import/startup certification, actual Edge/WASM, production export or owner-browser test is claimed.

## 6. Native observation and remaining risks

100 explicit fresh-fixture captures took **116,450 microseconds total**, approximately **1.165 ms per capture including the loop/assertion overhead**, in the final run. This is native debug capture construction only, not routine authorization, cold verification, save, publication or browser latency. There is no equivalent “before” capture implementation to benchmark; do not infer a production speedup.

At that measurement point, whole-process Godot allocator usage was **184,818,299 bytes**, peak **294,553,856 bytes**, including all runner preloads and prior fixtures. This is not per-record peak, RSS, JS heap, WASM capacity or an Edge memory fix. Only one latest immutable capture is retained by the gate; callers may still retain their own old captures until released.

Mutation scopes allocate only when explicitly bound. The null/default path adds guarded entry checks but performs no new allocation, hash, JSON pass or RNG draw. Existing physics processing is not toggled by the gate. The browser's existing explicit freeze/restore behavior remains independently covered.

Remaining work, **not implemented**:
- 46C's exclusive admitted aggregate, new-fact append/authorization, full cold admission and pending request ownership.
- Choosing the final authorized capture ordering relative to those new effects; stale handles must not be silently refreshed/adopted.
- Storage CAS, replica/readback, durable acknowledgement, unknown-publication reconciliation and version fencing.
- Rebinding explicitly after runtime/player/model/service replacement. The helper intentionally fails closed on changed bindings.
- Actual Edge/WASM acceptance and comprehensive checkpoint validation at future integration. This raw capture is not a new save/checkpoint schema or a cold-validation substitute.
- Maintain the audited writer contract: any future direct field writer/new API must be enrolled or force re-admission; raw mutable references must not escape the future aggregate.

**GO for resuming dormant 46C, using only the guarded trusted seams and this local freshness contract. NO-GO for playable activation, production storage integration, arbitrary external state edits or treating captures as acknowledged saves. Separate owner authorization remains required for the next task.**

## 7. Git and protected-data preservation

Entry: `main`, HEAD `f9bb0db0235b0003895c477a12346191d4714469`; empty index; 29 modified tracked paths and 156 collapsed untracked entries. Baseline: 736 existing scoped files plus seven paused-U diagnostic hashes.

Final exact comparison/status is appended below. Original byte comparisons strip only the enumerated new guards/metadata/checkpoint notification, clone exclusion, appended enum value and two runner lines from the edited files. They reproduce the entry hashes exactly, preserving all prior work, original statements, line endings and earlier test registrations.

No Roadmap, Combat Specification, protected boss document, repository `tmp/`, `character saves/`, owner backup, actual owner browser profile or production IndexedDB was opened. Protected names are listed by Git only; no content-comparison claim is made for those excluded paths. `project.godot` remains untouched. No staging, commit, push, reset, stash, rebase, clean or export occurred. Disposable legacy test roots are confined to the existing cache test namespace; source baseline copies and logs remain under the task's own system TEMP directory.

### Final verification

- **736 entry files checked:** 721 remain byte-identical; the 15 intentionally edited files reproduce their exact entry hashes after removing only this task's enumerated insertions. No entry file is missing.
- Exactly five additions match the task manifest. All seven paused-U diagnostic hashes are unchanged. No entry status line disappeared.
- `project.godot` retains SHA-256 `8398f110f77d7712eb19c283eb9f745c7123feab9557187778da412639ba5692`.
- Branch/HEAD remain `main` / `f9bb0db0235b0003895c477a12346191d4714469`; index is empty.
- Final status: **35 modified tracked paths / 161 collapsed untracked entries**, including all prior owner work.
- `git diff --check` exits 0. Existing CRLF-to-LF advisories for `playable_character_persistence.gd` and `tests/test_runner.gd` are not whitespace failures or normalization. All five new files pass direct trailing-whitespace checks. Both new UID values are valid and unique among scoped project UID files.
- Final eight test logs have no script errors, failure markers, warnings or leak messages. Intermediate unsuccessful test logs remain separate and preserved.

Exact final `git status --short` (names only):

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
?? docs/architecture/TASK_46C_COORDINATOR_OWNED_ROUTINE_SAVES.md
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
?? tests/oracles/
?? tests/profile_compact_v6.py
?? tests/profile_compact_v6_costs.py
?? tests/profile_compact_v6_reuse.py
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


