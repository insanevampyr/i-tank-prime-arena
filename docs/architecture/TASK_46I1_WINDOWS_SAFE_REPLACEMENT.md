# Task #46I-1 — Windows save-head replacement prerequisite

2026-11-19. **Complete within the isolated sentinel scope. GO for resuming disposable #46I Windows publication under the process-crash and filesystem limits below.** No full adapter, production save routing, durable character acknowledgement or format change was implemented.

## 1. Exact manifest and preservation boundary

Added:

1. `tools/windows/safe_head_replace.c` — small Windows-native sentinel replacement executable, explicitly restricted to dedicated OS-cache directories. One native move operation; no remove-then-move, copy/delete, shell or rollback fallback.
2. `tools/windows/build_safe_head_replace.py` — standard-library-only development build script using already installed MSVC and Windows SDK. Build products are restricted to a dedicated `TEMP/arena46i1_*` directory.
3. `tests/test_windows_safe_head_replace.py` — independent native-process/Win32 sentinel diagnostics and actual process-termination tests.
4. `tests/windows_safe_head_bridge_smoke.gd` — direct Godot `OS.execute()` first/replace/readback smoke, restricted to the source-built TEMP executable with its exact supplied SHA-256.
5. `tests/windows_safe_head_bridge_smoke.gd.uid` — `uid://bs46i1smoke`.
6. `docs/architecture/TASK_46I1_WINDOWS_SAFE_REPLACEMENT.md` — this report.

No existing file was edited. No DLL or executable was added to the repository. The new tests are standalone prerequisites, not registrations in or changes to the existing gameplay regression runner.

Read #46I/#46H and inspected the existing Windows adapters, original writer guard, v3 pending capture/acknowledgement and exact installed engine source. All earlier #45/#46 work remains in the original `main` checkout. #45U remains paused.

## 2. Primitive selection and deployment

### Exact old failure

At installed Godot **4.7.2 stable official `ed1daf0bf001b61586d9930840f2f1394092c079`**, [`DirAccessWindows::rename()`](https://github.com/godotengine/godot/blob/ed1daf0bf/drivers/windows/dir_access_windows.cpp#L319) removes an existing different-name destination before `MoveFileW`. The #46I actual failed-source reproduction remains valid; that primitive is not used by this bridge. [`FileAccessWindows::flush()`](https://github.com/godotengine/godot/blob/ed1daf0bf/drivers/windows/file_access_windows.cpp#L353) calls `fflush`; its internal backup-save option is not exposed to GDScript. No engine/configuration change was made to enable it.

### Alternatives reviewed

- [`ReplaceFileW`](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-replacefilew) merges metadata and documents partial-failure states. Errors 1176/1177 can remove or relocate the old name depending on backup parameters. A bare call is not a universal preserve-old-head guarantee; its write-through flag is unsupported. It was not selected or silently called as a fallback.
- [`MoveFileExW`](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-movefileexw) provides same-volume replacement without an explicit destination deletion by our code. **Selected:** `MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH` for replacing an acknowledged sentinel; only `MOVEFILE_WRITE_THROUGH` for first publication. `MOVEFILE_COPY_ALLOWED`, reboot deferral and delete/copy fallbacks are never used.
- Handle-based rename/engine patches and additional transaction frameworks were unnecessary for this bounded test. No engine rebuild, package download, PowerShell runtime, third-party library or new character authority was introduced.

The flags/API name alone are not the evidence of crash safety. The actual observed failure/readback/process results below establish the supported prerequisite. They are not a proof for every filesystem, filter driver, kernel failure or power outage. In particular, the documented write-through behavior must not be extrapolated into a complete power-loss guarantee for this character system.

### Build/runtime requirements

Built **x64 Release C**, MSVC `/O2 /MT /W4 /WX`, against installed SDK **10.0.26100.0**:

`C:/Program Files (x86)/Microsoft Visual Studio/18/BuildTools/VC/Tools/MSVC/14.50.35717/bin/Hostx64/x64/cl.exe`

No compiler warnings in the final build. `dumpbin /DEPENDENTS` shows **only `KERNEL32.dll`** (the existing Windows system API). Static CRT avoids an extra Visual C++ runtime distribution requirement. Python and MSVC/SDK are development tools only. The helper runs directly as an executable; Godot smoke confirms no shell is required.

Current generated test artifact, outside the repository:

`%TEMP%/arena46i1_native/safe_head_replace.exe`

- C source SHA-256: `6b2fd81d62a099c6e39a207af4bcc76c25f9dd6151ab6ee630a0b21d70728bfd`
- Executable SHA-256: `a6dac728d1bf305b3754461876eff7213d8bf3625aa52c21f8c4f46470d1ed1b`
- Executable size: **152,576 bytes**.

Rebuilding is source-controlled work, not a promise that PE timestamps produce the same executable hash. Capture the newly built hash before the direct Godot smoke. No binary deployment/export/signing or production executable discovery was added. A later disposable #46I pass may use this source-built helper explicitly; promoting a binary into a shipped build remains separate work.

## 3. Narrow command and ownership contract

Commands are `first`, `replace`, and read-only `verify`, with a disposable directory and explicit diagnostic barrier argument. Output is one bounded JSON result with protocol 1, state, phase, original native error, whether the API ran/succeeded, independent readback error, and `power_loss_guaranteed:false`. Protocol 1 is a bridge response, **not** a new save/head format.

The only data names are fixed sentinel filenames: `stage.bin`, `head.bin`, `expected.bin` and `verify.bin`. No character decoder, wallet, source rule, receipt/history or current/replica storage layout exists here. Current head inputs are limited to **65,536 bytes**, with nonempty staged bytes. Expected/verify files are disposable caller inputs for exact comparison, not proof of gameplay or new persistent character evidence.

Isolation rejects directories outside `%LOCALAPPDATA%/itank-storage-tests/minimal46i1_*`, nested/escaped suffixes, resolved-path mismatches and reparse roots. Supported storage is a **local fixed NTFS volume**, with short bounded paths. Opened data must be regular, non-reparse, single-link files on that exact volume. Same-directory fixed names plus volume checks and no copy flag exclude cross-volume publication. Actual cross-device moves were not executed; unsupported paths/link identities are rejected before mutation rather than tested on owner volumes.

For publication:

1. Acquire an exclusive Win32 handle to the fixed `writer.guard` file with share mode zero. Its mere on-disk presence is not ownership. Competing bridge processes reject; Windows releases the actual handle on process termination. No timeout lock theft/deletion or changes to existing coordinator locks were added.
2. Open/bound/read the staged source, retaining a handle that denies in-place writers. For replacement, compare the actual old head to the exact `expected.bin` bytes under ownership. For first publication, require head absence.
3. Call `FlushFileBuffers` on the staged handle and check its result. This is an explicit OS request, not hardware durability certification.
4. Release our old destination read handle, still under exclusive writer ownership, then perform the single selected native operation. The tested filesystem can refuse rename while a destination reader is open even when it shares DELETE. Retaining our own old reader would therefore obstruct successful replacement.
5. Independently reopen/read the new pathname while source and writer ownership remain held; compare exact full bytes. Report `published_verified` only if the native call succeeded **and** readback exactly matches.
6. If the native call fails, report its exact error. `failed_preserved` requires independent readback equal to the old acknowledged bytes. Unverifiable/missing/changed readback is `uncertain`, never success. Release handles after emitting the result.

Preflight rejection means this helper did not invoke replacement. Native errors and readback errors have separate fields: success from the syscall alone cannot acknowledge a save. If the process disappears without a response, its caller must retain original pending identity/bytes and independently reconcile. **Never rerun rewards or infer a character commit from process exit, a barrier file, or a caller-supplied expected file.**

This is a trusted internal, cooperating-writer primitive boundary, not an anti-cheat/security sandbox against arbitrary code editing a directory or replacing environment variables. External uncoordinated deletion is explicitly detected as uncertain in a test. The native guard is transport exclusion, not a replacement coordinator; original future coordinator authorization and expected durable character head remain mandatory.

### Concurrent readers

Readers use ordinary handles, not a long gameplay freeze. In this environment, held destination handles can make the replacement return access denied; old bytes remain intact. Compatible readers observed only entire old/new files. A future caller must release short-lived read handles before retry and retain the same pending operation. Do not force-close another process's handles or turn an access-denied result into success. Poll/retry scheduling and real reader integration are outside this prerequisite.

### First publication

First publication is separate and never sets REPLACE_EXISTING. If another head appears after the absence check, the native operation cannot overwrite it. The test injects precisely that race; it rejects/returns uncertain rather than treating the appearing head as our acknowledged work. No remove-old fallback is permitted.

## 4. Focused Windows results

Environment: **Windows 11, build 10.0.26300**, local fixed NTFS, native x64 executable. Final native diagnostics: **353 assertions, failures `[]`**, 40 unique disposable sentinel roots. Concurrent scheduling changes the number of observed preserved rejections and therefore its explicit count; the reported number is from the final run, not an invented fixed total. Direct Godot smoke: **6 assertions, failures `[]`**. **359 counted assertions total.**

| Diagnostic | Observed result |
| --- | --- |
| Ordinary replace | Native success, exact new pathname bytes, consumed stage name. |
| Missing stage | Error **2**, `stage_open`, no native replacement, exact old head retained and verified in a new process. |
| Stage held without DELETE sharing | Error **32**, preflight rejection, exact old head retained. |
| Exclusively locked destination | Error **32**, head-open rejection, exact old head retained. |
| Destination reader permits validation but blocks actual native move | Native error **5**, `api_called:true`, `api_success:false`, `failed_preserved` after exact old readback. |
| Destination reader includes DELETE sharing | In this run also error **5** with exact old authority preserved. Tests permit an exact successful replacement on a platform where that reader is compatible; never missing/partial head. |
| Incorrect expected head | Error **1306** before native replacement; exact current head preserved. |
| Empty/oversized stage and hardlinked source | Error **13**, rejected before native replacement. |
| Directory outside allowed test prefix | Rejected without creating a guard/sentinel file. |
| First publication absent | Native success, exact intended bytes. |
| First publication existing | Error **80**, no replacement. |
| Head appears between first precheck and native call | First-mode native call rejects; it does not overwrite the new occupant. Fresh process verifies that exact occupant. |
| Two actual helper writer processes | Second process rejects error **32** while first holds the native guard. Only original owner publishes. Later stale expected bytes reject with 1306. |
| Post-native success followed by deliberate removal of the disposable head | Exit **3**, `uncertain`, `api_success:true`, `win32_error:0`, **`readback_error:2`**. No acknowledgement despite syscall success. This is an injected data-change test, not a crash. |
| Continuous native-reader sampling / 20 attempted 64 KiB replacements | **4,775 samples**; **14 exact publications / 6 preserved rejections**; no missing, partial or unexpected head sampled. |
| Maximum 64 KiB staged head | Exact success and independent process verification. |
| Direct Godot first/replace/verify | Six checks pass through `OS.execute()` of the exact source-built executable without shell involvement. |

Native error numbers are observed Windows results; do not hard-code access denied as the only possible failure from antivirus, storage filters or different permissions. Unexpected results must stay rejected/uncertain until reconciled.

### Actual process termination matrix

**24 actual `TerminateProcess` cases**: `first` and `replace`, four controlled barriers, three repetitions each. Each child was confirmed alive at the barrier, killed externally, returned exit code 1 and emitted no success response. Subsequent verification ran as a separate native process. The empty guard file was not removed; OS handle release permitted subsequent valid retry.

| Termination barrier | Replacement mode | First mode |
| --- | --- | --- |
| Before explicit stage flush | Exact old head; exact retry can succeed. | No head; first retry can succeed. |
| Before native move, after flush | Exact old head; exact retry can succeed. | No head; first retry can succeed. |
| After native move, before independent readback | Exact new head independently verified, despite absent response. | Exact new head independently verified. |
| After exact readback, before response | Exact new head independently verified, despite lost acknowledgement. | Exact new head independently verified. |

These are real process-crash observations, not injected return codes. The diagnostic barriers themselves are bounded to 15 seconds and are test hooks only. **No test claims it terminated a thread at a particular instruction inside the kernel rename syscall.** Concurrent readers and before/after process tests support the measured local process-crash boundary; hardware reset, OS crash, failing disk controller and arbitrary filters are unverified.

Development checks found and corrected a helper self-interference: holding our own old-head reader prevented native replacement, and independent new-head readback had to share the retained staged handle's existing access. The final helper releases only its own old reader under ownership and uses appropriate readback sharing. Earlier smoke failure was correctly reported as `failed_preserved`; no old authority was lost. No original gameplay/validator or existing test was changed to obtain success.

## 5. Commands, artefacts and timing limits

```powershell
python tools/windows/build_safe_head_replace.py --output "$env:TEMP/arena46i1_native"
python tests/test_windows_safe_head_replace.py --exe "$env:TEMP/arena46i1_native/safe_head_replace.exe" --report "$env:TEMP/arena46i1-native-results.json"
# Supply the freshly computed executable SHA-256 as the final argument:
& 'C:/Users/mxz/Desktop/GoDot/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/windows_safe_head_bridge_smoke.gd -- <TEMP-executable> <SHA256>
```

Final retained evidence: `%TEMP%/arena46i1-build.log`, `arena46i1-tests.log`, `arena46i1-native-results.json`, `arena46i1-godot-smoke.log`. Diagnostic stdout and the JSON report identify every fixture root. `dumpbin /DEPENDENTS` was inspected separately. New files/UID and `git diff --check` pass; build warnings are errors. Existing unrelated Git CRLF advisories do not indicate whitespace failures and no normalization was performed.

Final direct-process samples include launch, argument/path/ownership checks, native operation or rejection, readback and exit; they are not exclusive syscall timings or character-save latency:

| Command samples | n | p50 ms | nearest-rank p95 ms | max ms |
| --- | ---: | ---: | ---: | ---: |
| `replace` (successes and explicit rejections) | 40 | 21.215 | 24.306 | 24.893 |
| `first` (including rejection/retry cases) | 8 | 12.176 | 13.348 | 13.348 |
| Fresh-process `verify` | 47 | 9.740 | 14.080 | 15.117 |

No complete snapshot preparation, replica publication, recovery, large-inventory save, browser timing or memory benchmark was run or claimed. No full regression or export was needed because all existing source remains byte-identical and this route is not connected to playable code.

## 6. Remaining limits and #46I continuation conditions

- This bridge is **disposable-only**, x64, fixed local NTFS, bounded heads and trusted cooperating processes. No production path exception exists. Different volumes/filesystems/readers need explicit review; no cross-volume copy/move test or universal atomicity guarantee is claimed.
- A future #46I adapter must still stage and verify actual current/replica bytes before head replacement, bind the exact expected head/commit/format, hold original coordinator ownership, perform independent persisted readback, reconcile lost responses without replay, and do bounded maintenance only after successful verification. This prerequisite alone does none of those character operations.
- Diagnostic barriers and sentinel names are not production format or authority. Any later non-diagnostic packaging must preserve the reviewed native semantics and failure states, and explicitly select the source-built binary. No new broad distribution infrastructure is necessary for disposable continuation, but no production shipping arrangement is approved here.
- The bridge's OS-released guard does not retroactively solve existing legacy stale directory locks. Existing coordinator guard ownership rules were not changed or bypassed. Full storage lock composition remains #46I work.
- `published_verified` describes only native sentinel/readback success. It is not a character settlement, durable retirement permit, backup proof or a guarantee that the latest character survived power failure. Missing result/readback remains uncertain. Hardware power-loss and exact kernel-internal interruption remain unverified.

## 7. Git and protected-file preservation

Unchanged branch `main`, HEAD `f9bb0db0235b0003895c477a12346191d4714469`, empty index. Entry baseline: **35 modified tracked / 198 collapsed untracked entries**, 778 scoped existing source/test/document/configuration files, recorded in `%TEMP%/arena46i1_baseline_t2zyx2bm/baseline.json`. Final verification compares all 778; no existing file may differ or disappear. Exact final inventory follows in the appendix.

`project.godot` remains at SHA-256 `8398f110f77d7712eb19c283eb9f745c7123feab9557187778da412639ba5692`. Protected boss documents, `character saves/` and repository `tmp/` were seen only as unchanged Git status names, never opened/hashed/modified. No owner character, backup or IndexedDB was accessed. Compiled artefacts, diagnostic fixtures and logs are in dedicated OS-cache/TEMP directories only. No existing save format, coordinator, capture gate, production route, gameplay rule, Roadmap, Combat Specification, export or Git state was changed. #45U remains paused.

**GO for resuming disposable #46I Windows publication, limited to the reviewed same-volume local NTFS process-crash boundary. STOP after #46I-1; no storage adapter or automatic continuation is authorized by this report.**

## Exact final Git status

Final preservation check: all **778** baseline files remain byte-identical; none is missing. Final collapsed status: **35 modified tracked / 203 untracked entries**.

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
?? tests/test_windows_safe_head_replace.py
?? tests/windows_safe_head_bridge_smoke.gd
?? tests/windows_safe_head_bridge_smoke.gd.uid
?? tmp/
?? tools/
```
