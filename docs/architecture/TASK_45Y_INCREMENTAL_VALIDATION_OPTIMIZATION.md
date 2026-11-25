# Task 45Y — Operation-local V6 verification reuse

18 November 2026. Dormant optimization implemented; focused verification below. Task 45U remains paused. No playable activation, production routing, migration, restore authorization or export.

## Exact Y manifest

Added (8):

- `scripts/rewards/compact_v6_checked_operation.gd`
- `scripts/rewards/compact_v6_checked_operation.gd.uid`
- `tests/oracles/compact_v6_full_45y.gd`
- `tests/oracles/compact_v6_full_45y.gd.uid`
- `tests/test_compact_v6_validation_reuse.gd`
- `tests/test_compact_v6_validation_reuse.gd.uid`
- `tests/profile_compact_v6_reuse.py`
- `docs/architecture/TASK_45Y_INCREMENTAL_VALIDATION_OPTIMIZATION.md`

Modified (7):

- `scripts/rewards/compact_character_v6_prototype.gd`
- `scripts/rewards/compact_v6_gameplay_candidate.gd`
- `scripts/rewards/compact_v6_snapshot_package.gd`
- `scripts/rewards/compact_v6_incremental_snapshot.gd`
- `tests/test_compact_v6_incremental_snapshot.gd`
- `tests/compact_v6_incremental_process.gd`
- `tests/test_runner.gd`

These are changes relative to Y entry, including earlier untracked modules; the whole worktree diff against HEAD also contains earlier tasks. Test runner adds exactly the Y preload/registration; prior registrations remain.

## Verification boundary and invalidation

X has an explicit dormant `enable_checked()` opt-in. It performs full W cold admission again and attaches an issuer-owned context to the actual S2 observer. Default X/S2 behavior remains the original full path. No playable code or storage route enables reuse.

The context binds actual service/source object identity (exact decimal strings), source fingerprint, rules, profile/namespace/run, exact acknowledged package/head, immutable parent logical digest and receipt bytes. It owns immutable strings for the current state and one candidate. It accepts no imported verification property, persistent cache or mutable Dictionary proof. Host/issuer/service/pending references are weak where needed to avoid a host/context ownership cycle.

Ordinary S2 preparation retains original coordinator authorization and original causal selection. The candidate is fully proved once by original V6 encoding. Original endpoint-continuity rules then run against this exact candidate and the cold-verified immutable parent. The public V6 extension API still fully validates both endpoints before invoking that same unchanged rule body. Exact lifetime-ID algorithms from P are unchanged.

Before reuse, the proof must match the actual S2-owned immutable pending object and exact bytes, original request/binding, ordered event facts, complete authorized projection, parent, actual service/source and fresh X head/ownership witness. Normal operations freshly recheck the original commit permit. Changed events, cursor, request, policy, runtime, external movement model, source, head or ownership invalidate reuse. Cancellation is terminal; restoring changed inputs does not revive an invalidated context.

S3 keeps original typed fixed-credit authorization and exact quote/confirmation. Its checked attachment performs a full independent candidate decode plus original extension proof before reuse. Recursive predecessor and event-time growth rules remain. No new credit authorization or generic amount/target interface exists.

W's checked constructor accepts only the actual context script and issuer-owned pending operation. Inputs are reconstructed as copies from owned immutable bytes. Full and checked construction share the same pure package assembler; format/version constants, frame bytes, receipts, limits and replica identity are unchanged. No reverse ancestry or new persistent indexes are introduced.

Final S2 checks still run coordinator authorization/hydration. Only repeated identical parent/candidate semantic replay is replaced by proof matching. Adoption additionally requires the original verified service acknowledgement and exact fresh package/head readback. Cold load/import/repair remain full independent verification; restart cannot deserialize trust from a flag. Physical publication, CAS and locks are outside Y.

## Instrumentation and correctness method

The profiler creates unique TEMP projects containing `scripts/`, `data/`, `tests/` excluding Python caches, one explicitly allowlisted authored character JSON, and a minimal new disposable project configuration. It does not copy protected boss documents, saves, backups or repository `tmp/`. The actual `project.godot` is unchanged. No Web build is created.

Counters wrap V6 validation/encoding/decoding/extension, coordinator authorization and W cold verification only in those TEMP projects. Before/after use identical fixtures, wrappers and harnesses. Process-tree memory sampling is limited to that invocation. Inclusive nested proof counters are not summed as independent timings.

The first baseline checker wrongly compared older observers against their newer shared witness. It was corrected to compare each observer's own acknowledged package, and the baseline was rerun successfully. Intermediate failed logs are preserved. No production expectations were weakened.

The frozen pre-Y V6 oracle differs only by one explanatory comment and its self-load paths. Reversing those changes yields exact original SHA-256 `b9a5be5ed930d5023b8e3a2e21b45ab5aaf44424f59a9368e1d45f2881e60cea`. The new private continuity body is text-identical to the original full validator's continuity body.

## Full-validation call counts

Two original coordinator `_authorize` calls remain per measured preparation. Admission is excluded from routine counters and stays full, including the opt-in's additional cold admission.

| Preparation kind | Full V6 validate before → after | V6 decode | V6 encode | Public extension | W parent cold |
| --- | ---: | ---: | ---: | ---: | ---: |
| Fresh character anchor | 3 → 1 | 2 → 0 | 1 → 1 | 0 → 0 | 0 → 0 |
| Existing ordinary character | 10 → 1 | 3 → 0 | 1 → 1 | 3 → 0 | 1 → 0 |
| Original-233 historical credit | 20 → 2 | 3 → 0 | 1 → 1 | 3 → 0 | 1 → 0 |
| Native fixed-credit operation | 25 → 15 | 3 → 1 | 1 → 1 | 3 → 1 | 1 → 0 |

Private continuity proof still runs. Recursive historical/native credit validation deliberately remains less optimized than ordinary checkpoints.

## Matched native timings

Godot 4.7.2 native debug. One paired matrix traversal per implementation: observations, not statistical p95 claims. Both passed 170 assertions; all 12 ordered terminal record/package/head signatures matched exactly.

Milliseconds, before → after. X preparation includes S2, W, exact ID checks and final authority rechecking, excluding physical publication/readback/acknowledgement. S2 and W are subintervals, not additive with X.

| Workload | X preparation | S2 preparation | W package | Full cold verify | Exact replica repair |
| --- | ---: | ---: | ---: | ---: | ---: |
| Small NORMAL, fresh | 36.792 → 39.266 | 9.397 → 19.809 | 9.763 → 4.872 | 9.713 → 10.301 | 10.205 → 10.383 |
| Small NORMAL, first wave checkpoint | 109.940 → 126.402 | 30.437 → 58.414 | 31.054 → 15.479 | 15.375 → 15.306 | 15.474 → 15.695 |
| Small NORMAL, later checkpoint | 108.066 → 89.033 | 26.130 → 43.307 | 39.322 → 10.444 | 17.175 → 17.120 | 17.692 → 17.328 |
| Small NORMAL, next checkpoint | 112.902 → 94.765 | 26.674 → 45.161 | 41.762 → 11.194 | 17.552 → 17.566 | 17.857 → 17.765 |
| Original 233, first | 959.324 → 512.937 | 236.962 → 282.122 | 399.340 → 61.570 | 148.884 → 151.013 | 148.508 → 149.178 |
| Original 233, next | 957.926 → 490.624 | 233.126 → 273.295 | 401.893 → 60.397 | 151.672 → 156.174 | 151.278 → 152.406 |
| 1,005 items / 2,023 IDs | 4346.594 → 3669.474 | 1182.865 → 1958.173 | 1296.257 → 478.530 | 1042.364 → 1053.463 | 1077.925 → 1069.040 |
| 1,005 items / 2,025 IDs | 6363.569 → 3990.427 | 1515.632 → 2182.316 | 2671.140 → 487.775 | 1067.507 → 1058.526 | 1053.081 → 1052.326 |
| Native fixed credit | 339.794 → 246.099 | credit-specific path | 101.490 → 11.151 | 44.353 → 43.839 | 46.202 → 44.598 |

Large preparations improved 15.6% and 37.3%, but **3.67/3.99 seconds still misses the one-second goal**. W's repeated replay is removed; S2 became slower because exact request/runtime/authority guards, causal comparison and immutable-byte reconstruction now run within its interval. Small fresh and first-wave preparations regressed. Do not generalize a speedup to every operation.

Small NORMAL/DEV ×1/DEV ×10 ranges: 36.115–113.616 ms before, 39.075–128.139 ms after. Original-233 preparation is below one second. Cold/repair costs remain essentially unchanged with run variation; no cold optimization is claimed.

The large second checkpoint now spends 2182.316 ms in S2, 487.775 ms in W and 763.314 ms in final seal/authority rechecking. Single full V6 validation: 204.824 ms; both coordinator calls: 511.730 ms. Source/runtime/event hashing, exact comparison, canonical JSON construction, owned-byte parsing and sealed copies remain costly. No broad cache or authorization removal was used to chase the target.

## Memory

- Before: peak process working set 1,763,635,200 bytes; peak private 1,834,303,488 bytes; whole matrix 217.618 seconds.
- After: peak process working set 1,776,906,240 bytes; peak private 1,851,187,200 bytes; whole matrix 187.711 seconds.

Peak process memory rose slightly; **no memory reduction or leak resolution is claimed**. Whole-matrix peaks include the original 233-generation legacy archive's full validation, fixtures, oracle and legacy publication, not routine-save preparation alone. Godot live allocation deltas at the end of the two large preparations were 47,731,740 → 47,764,072 and 38,488,340 → 38,520,672 bytes. These are net live deltas, not transient allocation totals. Weak references avoid a new host/context retention cycle. Browser JS/WASM/renderer memory, GC and background behavior were not measured.

## Focused tests and commands

- Matched before/final after: **170 assertions each, zero failures**, 12 terminal canonical record/package/head signatures identical. Includes genuine consecutive checkpoints, original233, 1,005 items/2,025 IDs, historical/native fixed credits, full cold validation and replica repair, unobserved original legacy controls and exact projections.
- Optimized short suite: **165 assertions, zero failures**. Includes direct W rejection for changed source, parent, pending bytes/identity, request, ownership and cancellation; foreign proof rejection; copied-dictionary mutation isolation; terminal invalidation; original X head/event/movement/causal-order checks, lost acknowledgement and exact retry. Cold child enables reuse only after full new-process cold admission.
- Optimized complex fixture: **21 X/Y assertions plus 580 Q reference assertions, zero failures**, 61 real checkpoints, all five attributes, interleaved original END/HPB/WIS growth, items, consumption, equipment/shield, historical credit, journal eviction, RESUME, NEXT WAVE and NEW RUN. Exact unobserved legacy projections and simulation/RNG are independently compared.
- Related original full focused suites: **Q 912, W 86, K 814, R 132 assertions; all four PASS, zero failures** (1,944 related assertions). Final accepted logs contain no script errors, errors, warnings or leaked-resource reports. R also exercises original cold portable export/preview/restore; its 7,760.986 ms debug export remains outside the Y routine-preparation optimization and is not claimed improved.

PowerShell commands (repository root):

```powershell
$Godot = 'C:/Users/mxz/Desktop/GoDot/Godot_v4.7.2-stable_win64_console.exe'
# TEMP-only prepare includes an isolated minimal project import.
python tests/profile_compact_v6_reuse.py prepare before
python tests/profile_compact_v6_reuse.py run "$env:TEMP/arena45y-before-taw4a42r/project" 0 before-verified
python tests/profile_compact_v6_reuse.py prepare after
python tests/profile_compact_v6_reuse.py run "$env:TEMP/arena45y-after-5peb3md7/project" 1 after-final
$env:ARENA45Y_CHECKED = '1'
$env:ARENA45X_CASE = 'remaining'
$env:ARENA45X_SHORT = '1'
& $Godot --headless --path . --script tests/test_runner.gd -- '--suite=45Y checked operation'
$env:ARENA45X_CASE = 'complex'
$env:ARENA45X_SHORT = ''
& $Godot --headless --path . --script tests/test_runner.gd -- '--suite=45Y checked operation'
& $Godot --headless --path . --script tests/test_runner.gd -- '--suite=45Q gameplay candidate'
& $Godot --headless --path . --script tests/test_runner.gd -- '--suite=45W snapshot package'
& $Godot --headless --path . --script tests/test_runner.gd -- '--suite=45K compact V6 prototype'
& $Godot --headless --path . --script tests/test_runner.gd -- '--suite=45R native compact credit'
git diff --check
```

For matched measurements, the successful baseline's exact Y/child test harness was copied into the after TEMP project. Additional checked-only adversarial probes and checked cold child were tested separately in the current workspace. After core code is the final version including direct W guards. This keeps negative-probe workload out of the comparison.

Evidence: `%TEMP%/arena45y-before-taw4a42r/before-verified.{json,log}`, `%TEMP%/arena45y-after-5peb3md7/after-final.{json,log}`, `%TEMP%/arena45y-final-short.log`, `arena45y-complex.log`, `arena45y-related-{q,w,k,r}.log`. Preliminary runs are preserved but not used for final performance. No full regression, production export, Edge/WASM, complete-save or owner-acceptance claim.

## Remaining blockers

- Full candidate proof, exact ID/continuity checks, original coordinator authorization/hydration and fresh mutable-authority checks remain necessary. Cold validation/readback is not optimized away.
- Source-specific credit proof remains recursive. No new credit permission exists.
- Production writer ownership, CAS, atomic/recoverable current/replica/head publication, persisted exact readback, old-writer exclusion and acknowledgement integration remain outside Y.
- W's unsupported occupied-profile lineage replacements stay blocked. No restoration/rollback authority is added.
- Under-one-second large preparation remains unmet. Further optimization needs separate scope; Y does not resume U or change formats.

## Workspace safety and exact Git status

Entry: `main`, HEAD `f9bb0db0235b0003895c477a12346191d4714469`, empty index; 29 modified tracked paths, 139 collapsed untracked entries. Preservation baseline: 717 pre-existing nonprotected files and seven U diagnostics.

Final preservation comparison: exactly the seven original Y files in the manifest changed; no baseline file missing. All seven U diagnostic hashes match. `project.godot` remains SHA-256 `8398f110f77d7712eb19c283eb9f745c7123feab9557187778da412639ba5692`. New UID values are unique; Python AST parses without creating bytecode. `git diff --check` passes; all 15 Y files also pass direct trailing-whitespace/final-newline checks, including untracked files. Git emits existing CRLF-to-LF notices for `playable_character_persistence.gd` and `test_runner.gd`; no whitespace errors. Final status follows.

Protected owner files, real Vaelis, backups, production IndexedDB, `character saves/`, repository `tmp/` and boss documents were not accessed. Status only lists protected names. No staging, committing, pushing, resetting, rebasing, stashing, cleaning or export. Stop after Y.

Final `git status --short`: 29 modified tracked paths, 145 collapsed untracked entries; index empty. The six additional collapsed status entries are Y files; two new oracle files reside under the already-untracked `tests/oracles/` directory. All earlier entries remain.

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
