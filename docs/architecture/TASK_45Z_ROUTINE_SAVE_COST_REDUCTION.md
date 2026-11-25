# Task 45Z — Targeted routine-save cost reduction

18 November 2026. Dormant-only bounded optimization. Task 45U remains paused. Experiment REJECTED and removed; final focused checks below. No production activation or publication.

## Scope and baseline

Entry: `main`, HEAD `f9bb0db0235b0003895c477a12346191d4714469`; empty index; 29 modified tracked paths and 145 collapsed untracked entries. Preservation snapshot: 725 pre-existing nonprotected source/test/document/config files and seven U diagnostics. Protected paths are listed by Git status only, never opened.

The actual repository is `C:/Users/mxz/Desktop/Projects/ITank Prime/Video Game/ITank Arena/i-tank-prime-arena`. No worktree switching or Git mutation was performed.

Y's checked proof boundary remains authoritative and dormant. This pass does not reduce validation again, change ID lookup, cache mutable authority, alter formats or change cold verification. The existing coordinator remains mandatory.

## Profiling method

`tests/profile_compact_v6_costs.py` reuses the existing Y disposable profiler. It adds fine-grained wrappers only in unique TEMP copies: S2 sealed-copy, head/context/event/causal methods; Y guard/bind/match/package methods; X fresh-head and prefix checks; V6 projection/assembly/continuity/digest; W package-state construction; contract encode/decode; original hydration. JSON parse/stringify are instrumented in those copied modules. Production source has no instrumentation hooks.

Nested/inclusive times overlap. Full-record copies are separately bounded by the assembly/projection intervals; parsing versus copy normalization is distinguished by nested JSON timers. Existing original coordinator and full semantic call counters remain enabled. Return values and canonical serialization are unchanged by instrumentation.

The same native Godot 4.7.2 debug workload, instrumentation and fixtures must be used before/after. Whole-suite peaks include one-time legacy conversion/oracles and must not be described as per-save memory. Godot net live deltas are not transient allocation totals or proof of a leak. No Edge/WASM or complete storage-save latency is measured here.

Early profiler setup errors (Python match access and a generated local name colliding with a parameter) were confined to the new harness/TEMP copies. Their logs are preserved; no measurements or product correctness claims use them. Explicit runner parse checking was added to fail before running an invalid instrumented project.

## Before-edit diagnosis

Measured before editing, two genuine consecutive 1,005-item checkpoints:

| Work | First large checkpoint, ms | Second large checkpoint, ms |
| --- | ---: | ---: |
| Full X preparation | 3732.150 | 3991.548 |
| S2 preparation | 2006.531 | 2164.998 |
| W packaging | 475.589 | 485.715 |
| Final seal/authority | 740.238 | 771.530 |
| JSON stringify, aggregate exclusive | 1566.406 / 13,308 calls | 1924.084 / 15,321 calls |
| V6 digest, inclusive | 988.580 / 4,120 calls | 1643.089 / 4,124 calls |
| S2 head digest, inclusive | 6.791 / 10 calls | 393.548 / 10 calls |
| Y mutable guard, inclusive | 5.503 / 6 calls | 242.825 / 6 calls |
| Sealed S2 copies, inclusive | 263.790 / 7 calls | 162.027 / 7 calls |
| V6 full projection copies | 38.090 / 7 calls | 60.674 / 7 calls |
| V6 assembly | 49.402 | 47.757 |
| Full extension continuity | 60.857 | 151.197 |
| Original coordinator authorization | 513.481 / 2 calls | 516.408 / 2 calls |
| Source hydration | 243.720 / 3 calls | 248.945 / 3 calls |

Rows overlap and are not additive. The second checkpoint has an already-large parent, explaining expensive parent hashing even though it has only one newly captured event. The first checkpoint captures 2,002 original events; six fresh unchanged-event checks take 125.982 ms. Those mutable checks remain.

The overall dominant category is canonicalization/hash work, much of it enforcing current request/runtime/parent identity and source authority. No safe permission to suppress those checks was established. The isolated, demonstrably avoidable cost selected for one experiment is seven full seal reconstructions. `Prepared.copy()` parses and normalizes the complete escaped candidate each time, although the candidate is already an immutable String. This is a limited slice of total cost; no multi-second improvement is predicted from removing it.

## Experiment and safety

One experiment only, in dormant S2 `Prepared`: retain canonical binding JSON and immutable candidate/digest strings, rather than a second complete escaped seal. `copy()` parses just the binding and shares immutable String values. `bytes()` reconstructs the exact original sorted-key seal from those original canonical parts; the digest remains the original full-seal SHA-256. This trades small byte-serialization work on demand for fewer large parses and no retained duplicate full seal.

Only the existing exact three-key shape is decomposed. Unknown keys, missing values, wrong types and empty String variants retain the original whole-seal path, preserving diagnostic/failure behavior. This eligibility condition is structural serialization, not semantic verification or authorization. There is no new proof flag, mutable Dictionary cache, coordinator or persistent format. All parts, including empty fallback-only parts, lock when initialization finishes.

Source, owner/head, runtime, pending request, coordinator checks, full V6 validation, prefix comparison and exact IDs are unchanged. Untrusted/cold inputs still take full verification. Original candidate/W/head signatures must remain identical. The old `_bytes` property still returns the exact original seal and ignores attempted replacement. Copies cannot modify internal parts.

**Rejected experiment, not current production code.** The entire S2 source is restored byte-for-byte to its pre-Z hash `96e3243c4d9573aa6b290247cd52749e1038acbc2d5741dd871de01fe4c56b82`. Outside the nested Prepared class was checked identical before restoring it. No Git restore/reset/revert was used. Experimental source is retained in `%TEMP%/arena45z-experimental-s2.gd`.

Manifest during the experiment: modified `scripts/rewards/compact_v6_gameplay_candidate.gd` (one nested class only), `tests/test_compact_v6_validation_reuse.gd` (serialization-equivalence/immutability assertions); added `tests/profile_compact_v6_costs.py` and this document. The matched before/after TEMP harness remains byte-identical; new direct tests run separately in the workspace.

An initial experimental run was stopped to finish locking empty fallback parts before final measurement. A new direct test then needed an explicit WeakRef type for Godot's strict parser. These new-code/harness corrections are documented; their interrupted/parse-error logs are not accepted results. All earlier work remains preserved.

## Results, costs and recommendation

**REJECT the serialization experiment.** Full large preparation improved only 1.09% and 1.27% in a single paired observation, despite much larger isolated-copy savings. That does not establish the requested substantial routine-save improvement and does not justify retaining an additional hand-assembled seal serializer. No further optimization was attempted. The original Y/S2 implementation is restored exactly; all earlier work remains.

### Matched observations

Native debug Godot 4.7.2, identical immutable disposable source, code except the experiment, harness and fine-grained instrumentation. One full traversal each, not statistical p95 results. Both passed **243 assertions, zero failures**. All **12 terminal record/package/head signature rows** were byte-identical. Full independent frozen V6 encoding/rejections, exact replica repair, cold restart and original legacy gameplay comparisons remain exercised.

Milliseconds, baseline → rejected experiment. X includes S2/W/final checks and excludes physical storage publication/readback/acknowledgement; subintervals overlap.

| Workload | X preparation | S2 preparation | W package | Final seal/authority |
| --- | ---: | ---: | ---: | ---: |
| normal1 / 12 IDs | 41.754 → 41.062 | 21.264 → 20.986 | 5.186 → 4.715 | 9.080 → 9.198 |
| normal1 / 19 IDs | 129.188 → 130.898 | 60.622 → 61.144 | 15.541 → 15.333 | 31.673 → 31.807 |
| normal1 / 24 IDs | 92.382 → 94.822 | 45.031 → 48.192 | 11.061 → 10.712 | 21.057 → 21.361 |
| normal1 / 25 IDs | 97.819 → 95.798 | 47.381 → 46.129 | 11.542 → 11.183 | 23.022 → 21.810 |
| dev_normal1 / 12 IDs | 40.332 → 39.856 | 20.504 → 20.541 | 4.753 → 4.591 | 8.910 → 8.936 |
| dev_normal1 / 19 IDs | 132.250 → 129.943 | 60.952 → 61.013 | 15.754 → 15.616 | 32.440 → 32.058 |
| dev_normal1 / 24 IDs | 93.037 → 95.943 | 45.338 → 48.688 | 10.814 → 10.572 | 21.590 → 21.163 |
| dev_normal1 / 25 IDs | 98.128 → 96.136 | 46.968 → 46.180 | 12.173 → 11.474 | 22.851 → 22.193 |
| dev_normal10 / 12 IDs | 40.816 → 40.516 | 20.944 → 21.079 | 5.071 → 4.959 | 8.717 → 8.472 |
| dev_normal10 / 21 IDs | 105.143 → 105.245 | 49.386 → 49.755 | 12.935 → 12.642 | 25.849 → 26.003 |
| dev_normal10 / 22 IDs | 79.262 → 78.118 | 39.229 → 38.636 | 9.658 → 9.518 | 17.505 → 17.455 |
| dev_normal10 / 23 IDs | 87.380 → 87.734 | 42.485 → 41.993 | 10.854 → 10.140 | 19.810 → 19.421 |
| original233 / 513 IDs | 517.672 → 503.584 | 291.931 → 286.650 | 59.923 → 57.474 | 92.758 → 88.930 |
| original233 / 515 IDs | 528.169 → 504.389 | 296.039 → 286.906 | 63.447 → 58.142 | 91.286 → 89.565 |
| inventory1000 / 2023 IDs | 3732.150 → 3691.411 | 2006.531 → 2010.752 | 475.589 → 459.254 | 740.238 → 730.599 |
| inventory1000 / 2025 IDs | 3991.548 → 3940.953 | 2164.998 → 2164.035 | 485.715 → 478.475 | 771.530 → 747.196 |
| native_fixed_credit_operation / 34 IDs | 260.183 → 257.410 | credit-specific | 11.639 → 10.897 | 48.504 → 46.292 |

Small NORMAL/DEV observations vary by a few milliseconds, including regressions. The short correctness run briefly overlapped the early part of the after-run; no small sub-percent CPU claim is justified. The large preparation measurements occurred after that focused process ended. No repeat was needed to justify rejection: a substantial improvement was not demonstrated, and final production bytes are unchanged.

Full validation/authorization counters did not change: ordinary checkpoints one V6 validation, one encode and two coordinator authorizations; original233 two validations (historical-credit proof), one encode and two authorizations; native credit fifteen validations, one encode, one decode, one public extension and two authorizations. Neither the experiment nor final state removes a semantic scan or fresh mutable-authority check.

### CPU attribution

The seven large seal copies fell from **263.790 → 103.532 ms** and **162.027 → 0.661 ms**. Aggregate JSON parse time fell 459.377 → 302.895 and 353.009 → 199.121 ms. Aggregate JSON stringify rose **1566.406 → 1640.534** and **1924.084 → 1985.808 ms**, with five extra calls per preparation. This is consistent with on-demand full-seal byte reconstruction offsetting parsing savings; it does not separately time every allocation/concatenation. Full X saved only 40.739/50.595 ms and S2 stayed approximately flat. Fewer expensive copies alone did not deliver the requested end-to-end CPU result.

### Memory and allocation observations

| Metric | Baseline | Rejected experiment |
| --- | ---: | ---: |
| Whole-process peak_working_set, bytes | 1,781,075,968 | 1,779,625,984 |
| Whole-process max sampled private, bytes | 1,863,352,320 | 1,867,563,008 |
| Whole matrix elapsed seconds | 189.232 | 188.001 |
| First large preparation net live delta, bytes | 47,768,800 | 38,319,280 |
| Next large preparation net live delta, bytes | 38,525,400 | 29,075,880 |
| First large copies, sum of per-call end live deltas | 110,307,288 | 44,160,648 |
| Next large copies, sum of per-call end live deltas | 66,226,076 | 79,436 |

The experiment reduced net live bytes at preparation completion by **9,449,520 bytes** for each large operation, but it is not retained. Summed copy deltas are allocation-churn indicators, not peak memory, distinct malloc totals or retained memory after acknowledgement; they must not be added to whole-process peaks. Whole-matrix peaks include original233 validation/conversion, fixtures and independent oracles, not only a routine save. Working-set peak decreased slightly while private peak increased slightly; no leak, steady-state browser or per-save process-peak claim follows.

New direct tests use WeakRef to verify release of each disposable seal. No new cache or process-local trust mechanism survives the rejected experiment. Browser/WASM memory and owner acceptance were not measured.

### Final focused checks

The new serialization characterization adds **32 assertions**: original canonical bytes/digest and normalized copies, integral/fractional/negative-zero numeric forms, escaping/Unicode, empty/missing/extra/wrong-type shapes, caller/returned-copy mutation isolation and seal lifetime. It passes on the original implementation as well as the experiment. It does not weaken any earlier expected result.

Restored-source checks: **197 checked short assertions; 53 complex checks plus 580 original Q lifecycle assertions (633); 86 original X short assertions**, all PASS with zero failures. Related original W **86** and K **814** assertions also PASS, zero failures. Q/R full suites were not repeated: all original production/prototype files are hash-identical to Y entry, the 243-assertion matched matrix exercises both historical/native credits and original unobserved gameplay, and the complex pass reuses the 580 Q lifecycle assertions. The earlier Q 912 / R 132 full-suite PASS results are Y evidence, not new Z executions. The experiment's final short checked suite passed 197 assertions. The matched before/after matrices each passed 243. Earlier profiler/test parse errors and the interrupted preliminary experiment are preserved but are not passing measurements.

### Evidence and commands

```powershell
python tests/profile_compact_v6_costs.py prepare before
python tests/profile_compact_v6_costs.py run "$env:TEMP/arena45y-45z-before-069g5iyg/project" before
python tests/profile_compact_v6_costs.py prepare final
# Final TEMP harness replaced with exact successful baseline Y harness only;
# new direct serialization assertions run separately in the workspace.
python tests/profile_compact_v6_costs.py run "$env:TEMP/arena45y-45z-final-jtfs7hzs/project" after-final
$Godot='C:/Users/mxz/Desktop/GoDot/Godot_v4.7.2-stable_win64_console.exe'
$env:ARENA45Y_CHECKED='1';$env:ARENA45X_CASE='remaining';$env:ARENA45X_SHORT='1'
& $Godot --headless --path . --script tests/test_runner.gd -- '--suite=45Y checked operation'
$env:ARENA45X_CASE='complex';$env:ARENA45X_SHORT=''
& $Godot --headless --path . --script tests/test_runner.gd -- '--suite=45Y checked operation'
$env:ARENA45X_CASE='remaining';$env:ARENA45X_SHORT='1'
& $Godot --headless --path . --script tests/test_runner.gd -- '--suite=45X incremental snapshot'
& $Godot --headless --path . --script tests/test_runner.gd -- '--suite=45W snapshot package'
& $Godot --headless --path . --script tests/test_runner.gd -- '--suite=45K compact V6 prototype'
git diff --check
```

JSON/log evidence is in the two TEMP project parent directories above: `before.{json,log}`, `after-final.{json,log}`. Final workspace logs are `%TEMP%/arena45z-final-{short,complex,45x,45w,45k}.log`. `arena45z-short-final.log` is the experimental version's successful short run, distinct from restored `arena45z-final-short.log`. The uninstrumented original and experimental S2 files are retained separately in TEMP. No artifact from an incomplete run is used as performance evidence.

### Remaining unavoidable costs / stop boundary

Full candidate semantic validation, current source/request/runtime checks, exact lifetime bindings, event order, source-qualified progression and original coordinator hydration remain. Ten parent-head serializations and six Y parent guards are visible hotspots, but the parent is mutable in the current adapter and tampering must remain detectable. Replacing those with a stale cached digest would violate the present contracts. Suppressing runtime/source/request checks or authorization to claim a larger gain was not attempted. This pass establishes no safe dominant-cost correction within its boundaries.

**No production optimization is retained.** A broader change to authority/ownership representation or serialization boundaries needs separate approval. Y remains the current dormant implementation. No routing, migration, activation or subsequent task begins.

## Final retained file manifest

Added:

- `tests/profile_compact_v6_costs.py`
- `docs/architecture/TASK_45Z_ROUTINE_SAVE_COST_REDUCTION.md`

Modified:

- `tests/test_compact_v6_validation_reuse.gd` — 32 additional serialization characterization assertions and invocation only.

**No production/prototype script changes remain.** The experiment is removed; its code, successful/failed/interrupted logs and both matched measurements are preserved under TEMP. No test-runner or UID change was needed.

## Preservation

No owner profile, backup, production IndexedDB, protected boss file, `character saves/` or repository `tmp/` is accessed. `project.godot` must remain SHA-256 `8398f110f77d7712eb19c283eb9f745c7123feab9557187778da412639ba5692`. No stage, commit, push, stash, reset, rebase, cleanup or export. Stop after Z.

Final preservation check: of 725 pre-existing nonprotected files, only the named characterization test differs; none are missing. Every production/prototype file and all seven paused-U diagnostic hashes match entry. `git diff --check`, explicit three-file whitespace/final-newline checks and Python AST parsing pass. Git emits only existing CRLF-to-LF notices for `playable_character_persistence.gd` and `test_runner.gd`, not whitespace errors. Final accepted test logs contain no errors, warnings or leaked-resource reports.

Final Git: `main`, unchanged HEAD, empty index; **29 modified tracked paths / 147 collapsed untracked entries**. Two new status entries are the Z profiler/report; all earlier entries remain.

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
