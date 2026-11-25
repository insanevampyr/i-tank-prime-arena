# Task 45S — Dormant Windows compact persistence, S4

## Status and safety boundary

Dormant S4 implementation and focused correctness verification. **Production activation remains blocked by latency and unattended stale-lease recovery.** No playable dispatch, owner conversion, production storage/browser upgrade, public export or Git mutation is included.

Primary checkout: `C:/Users/mxz/Desktop/Projects/ITank Prime/Video Game/ITank Arena/i-tank-prime-arena`, `main`, HEAD `f9bb0db0235b0003895c477a12346191d4714469`, preserving the uncommitted 45B–45R work. The older export worktree was not edited. Requested 45O/P/Q/R/M/N designs, actual legacy storage/coordinator/service, S2/S3, portable codec and disposable adapters were reviewed first.

All new route construction requires an absolute OS-cache `itank-storage-tests/compact45s_*` path and native Windows execution. There is no default production directory. Context is rechecked at file operations; changing root/guard/layout invalidates it. `user://character_documents` is rejected before file access. Production `open()`, `commit()`, browser admission and backup dispatch never select this route.

## Exact file manifest

Added:

- `scripts/rewards/compact_v6_windows_storage.gd`
- `scripts/rewards/compact_v6_windows_storage.gd.uid`
- `scripts/rewards/compact_v6_portable.gd`
- `scripts/rewards/compact_v6_portable.gd.uid`
- `tests/compact_v6_windows_host.gd`
- `tests/compact_v6_windows_host.gd.uid`
- `tests/test_compact_v6_windows_storage.gd`
- `tests/test_compact_v6_windows_storage.gd.uid`
- `tests/test_compact_v6_windows_crash.gd`
- `tests/test_compact_v6_windows_crash.gd.uid`
- `tests/compact_v6_windows_crash_process.gd`
- `tests/compact_v6_windows_crash_process.gd.uid`
- `tests/test_compact_v6_windows_guards.gd`
- `tests/test_compact_v6_windows_guards.gd.uid`
- `tests/compact_v6_windows_benchmark.gd`
- `tests/compact_v6_windows_benchmark.gd.uid`
- `tests/compact_v6_windows_benchmark_process.gd`
- `tests/compact_v6_windows_benchmark_process.gd.uid`
- `docs/architecture/TASK_45S_V6_WINDOWS_STORAGE.md`

Modified existing files:

- `scripts/rewards/character_persistence_coordinator.gd`: explicit compact preparation/publication/activation methods; original legacy authorization and mutation rules preserved.
- `scripts/rewards/playable_character_persistence.gd`: extract existing admission tail for reuse; explicit cache-only compact admission/acknowledgement, canonical head binding and bounded END request witness alias. Ordinary legacy behavior is unchanged.
- `scripts/rewards/compact_v6_gameplay_candidate.gd`: privately owned publication handoff and native readback/adoption; no independent writer.
- `tests/compact_v6_portable_backup.gd`: compatibility shim to the promoted shared pure codec.
- `tests/test_compact_v6_gameplay_candidate.gd`: optional fixture service factory and bounded all-mutation variant; default original suite remains complete.
- `tests/test_runner.gd`: three S4 registrations/preloads, preserving earlier suites.

19 additions including nine UID sidecars, and six existing-file modifications: **25 task files**. The existing prototype/production validators were reused rather than replacing the persistence authority or duplicating rules in another wallet.

## Format and publication architecture

The Windows route has version 1, active character format 6. It supports both existing compact inner versions (1, or the typed native fixed-credit version 2). Simulation schema 12 and production V2/V4/V5 contracts are unchanged.

Under the existing profile directory:

```text
<profile>/
  original generation_*.json and restoration_*.bundle   unchanged archive
  generation_<legacy-count+1>.json                      immutable technical fence
  compact/
    route.json                                        one current route decision
    record_<current-envelope-sha>.v6                   exact acknowledged current
    record_<previous-envelope-sha>.v6                  technical previous
    capsule_<portable-sha>.v6backup                    current exact recovery proof
```

Staging uses `record.pending`, `capsule.pending`, `route.pending`, and an initial `activation.pending`. The profile's existing outer writer directory and oldest inner `writer.lock` are both held. The source-valid record and complete capsule are written/flushed/read back and semantically verified before publication. A staged closed/checksummed route replaces `route.json` through `DirAccess.rename_absolute`. Independent cold readback precedes acknowledgement. Known unreferenced compact records/capsules are pruned only under ownership after verified publication; original legacy generations/bundles are never deleted.

The route binds profile/namespace, trusted source/rules, epoch/sequence, logical inner-record digest, exact encoded-envelope digest, previous envelope digest, capsule digest, original operation ID/request binding and immutable fence digest/name. A separate token includes the exact route-file SHA-256. Logical, document, capsule and manifest digests are deliberately distinct.

`load_current()` validates metadata/fence, complete self-contained capsule, all standalone source/chronology/receipt/ID rules and ancestry, current bytes, and then rereads the actual route decision. A changed head during validation rejects. It does not reparse the archived hundreds of legacy generations on routine load. A damaged current can be reconstructed exactly from its bound capsule, with `exact_recovery_needed`; admission/acknowledgement require repair. A damaged previous never becomes current.

Same-volume staged replacement and exact readback were exercised on Windows. This is **not power-loss, disk-controller flush or universal filesystem atomicity proof**. Result flags retain `durable_power_loss_guaranteed:false`.

## Tested old-writer fence

An unsupported **storage wrapper** alone is unsafe for the oldest reader: `babb9ba` treats it as damaged and can scan back to an older generation. The selected fence therefore uses a supported wrapper (`storage_version:1`, transaction `compact_v6_fence`) containing a known-format **character envelope version 6**, which all tested legacy contracts explicitly reject with `unsupported_format_or_version` before trying to use its body as a character.

The inner fence body is separately typed `compact_windows_fence`, version 1. It commits identity/source, exact legacy history count/digest, and the initial descriptor digest. To avoid a hash cycle, this descriptor digest uses the route with its fence-digest field empty; recovery fills the verified actual fence digest before publishing the real route. It is not mislabeled as the actual final route-file hash.

Read-only `git show` extracted the actual storage and contract implementations from `babb9ba`, `9753c3c`, `256b3f7`, `42eca40` into disposable caches. Only global `class_name` declarations and the contract preload path were changed to load side-by-side; reader/writer algorithms were not rewritten. Each historical writer first successfully created two legitimate foundation generations. After the chosen fence:

| Historical revision | Reader | Writer |
| --- | --- | --- |
| babb9ba | `unsupported_format_or_version`, no fallback | `generation_repair_required` |
| 9753c3c | `unsupported_format_or_version` | `unsupported_format_or_version` |
| 256b3f7 | `unsupported_format_or_version` | `generation_recovery_required` |
| 42eca40 | `unsupported_format_or_version` | `generation_recovery_required` |

Current legacy reader/writer also rejects an active compact profile. Holding both lock generations excludes old and current writers during staging, before the fence exists. A route marker alone was not used as exclusion. These tests cover the repository's actual historical implementations, not arbitrary unknown software or an external tool deleting the fence.

## One coordinator, authorization and acknowledgement

`CharacterPersistenceCoordinator.prepare_compact()` accepts only the real cache-gated route, real S2 adapter and its privately owned pending candidate. It calls the existing `_authorize()` with the actual service verifier (or S3's operation-local fixed-credit authority), then binds the original proposal/request, source, identity, logical parent, actual storage token, exact candidate bytes and complete capsule in a sealed coordinator-owned request.

`commit_compact()` reacquires exclusive ownership, rechecks the original authority, request and parent, applies the unchanged continuity/item rules, stages/publishes and independently reads back. A copied sealed request or changed source/proposal is not authorization. Exact replay of the same already-published candidate reconciles without writing a new operation. A stale competing parent loses; its S2 observer does not advance.

The service applies the existing `_ack()` only after native readback fields and full projection equality match. The adapter independently verifies native bytes, route digest and original request acknowledgement before adopting the new in-memory parent. The test host calls this route instead of the legacy commit: it does **not** dual-write a native store and a legacy oracle. Independent legacy controls run in different disposable roots solely for equivalence.

Two native representation issues were corrected without changing legacy behavior:

1. V6 stores canonical decoded numbers/arrays, while live original proposals can contain integral floats and packed arrays. Native acknowledgement retains the exact canonical acknowledged view, and unchanged native checkpoints compare the two full existing-contract roundtrips. This prevents phantom extra generations and makes explicit NEW RUN head hashes stable across reload.
2. The exact already-verified END witness for the unchanged original request remains available alongside the canonical current witness until the next acknowledgement. Rechecking the original same-generation request must not be misinterpreted as a new END generation. Both representations are admitted only after full native readback/projection equality; this is a bounded transient witness, not a saved flag or a weaker history validator.

The old admission branch was moved into shared private helpers; existing legacy `open_verified_history()` still performs all of its original history checks before those helpers. New `open_compact_disposable()` performs full compact source validation and builds the END witness, then uses those same run-policy/namespace/condition checks. It never fabricates a one-row legacy archive.

Explicit conversion activation holds both locks, fully validates the actual legacy history through the existing converter/independent comparison, offers a source/head-bound confirmation, rechecks the unchanged source, stages proof and publishes the fence/route. No claim that a checksum alone authorizes progression is made.

## Portable-code correctness repair

The existing pure Pass D codec was promoted once; the old test path inherits it. It was not connected to playable backup controls. Actual S2 historical-credit materialization changes a prefix-reference Dictionary into its verified Array. The old generic delta builder compared those unlike Variant types directly and produced a Godot runtime error. Type-safe equality/field-precondition guards fix that legitimate transition and reject malformed type substitutions safely. Complete V6 endpoint and ancestry validation remains. This is a directly reproduced storage correctness repair, not a portable performance optimization or format rewrite.

## Crash, interruption and corruption evidence

| Boundary or fault | Verified outcome |
| --- | --- |
| Injected write failure/disk-full result, partial record, capsule failure, before fence | No compact acknowledgement; original legacy state remains intact. Same authorized activation can retry. These are I/O-failure simulations, not a physically filled drive. |
| Fence published, route not published | Old reader/writer excluded. Exact staged initial descriptor/capsule can finish activation under a fresh uncontested lease. |
| Route published but I/O reports failure / acknowledgement is lost | Exact independent readback determines success; repeated candidate does not duplicate rewards, purchases, items or credit. |
| Two actual same-parent gameplay writers | One wins; stale candidate cannot publish or advance its acknowledged parent. |
| Actual writer advances during cold reader validation | Reader rejects `compact_head_changed_during_validation`. |
| Current truncated/missing, capsule intact | Reconstruct exact current only; locked repair/readback, repeated recovery idempotent. |
| Previous damaged | Exact current remains available; no fallback. |
| Required capsule damaged | Fail closed, preserve diagnostic data; previous is insufficient. |
| Later route missing/truncated/rehashed stale/wrong namespace/source | Fail closed; no archived legacy state or old initial intent is substituted. |
| Cancellation, foreign/copied handle, changed proposal, claimed success | No publication/acknowledgement based on those requests. |
| Real child process self-termination after record, fence or route rename, including an incremental earned-XP publication | Unverified writer leases survive and are never stolen. After route publication exact current is readable; before it, no older compact character is guessed. |

Windows `OS.kill(self)` returned exit code 0 in these tests; the pre-termination marker, absence of the post-call return marker and retained locks establish abrupt termination. No claim of nonzero termination codes was substituted for evidence.

**Unattended crash-write recovery is intentionally blocked:** the inherited lease format cannot prove a dead process's lifetime/ownership safely. The implementation does not use PID-only/timeouts, remove unknown locks or resume an older character. Read-only exact-state diagnostics remain possible; further writes need a separately reviewed verifiable lease-release/recovery protocol. This limits production readiness even though it preserves acknowledged progression.

## Focused correctness results

- S4 route/gameplay matrix: **422 assertions PASS**.
- Real process-termination matrix: **22 assertions PASS**.
- Forgery, cancellation, competing writer and changing-reader-head guards: **13 assertions PASS**.
- Historical source/contract fence probe: all four positive controls and four old-reader/writer pairs passed.
- Earlier compact/legacy compatibility results and final diagnostic checks are recorded below.

S4's bounded fixture still executes actual source-valued combat, NORMAL x1 and DEV x1/x10, all STR/DEX/SPD/WIS/END purchases, original END/HPB/WIS growth/dice, real item acquisition/consumption/equipment/shield wear, native and historical credits, RESUME/NEW RUN, and strict seeded simulator-state convergence against independent legacy execution. Complete canonical current projections and all relevant receipts are compared. The existing full 45Q default suite remains unchanged in scope.

An initial test compared raw live numeric/container representations to decoded values; the test now uses the same complete cold-contract representation as the original Q tests. Two actual native acknowledgement/witness issues and the portable type-comparison defect were fixed, rather than weakening state or history validation. An invalid guard fixture originally attempted a downtime-only command in combat; moving it to actual downtime fixed the fixture. No assertion was marked expected failure.

The first combined S4 fixture repeated 23 live checkpoints plus a full subsequent circuit; it was stopped after roughly 20 minutes of expensive complete ancestry validation. The bounded S4 mutation-equivalence fixture passed; separate long-history/large-inventory stress measurements retain the slow costs. No runtime validation was removed to shorten a test.

## Performance observations — not activation certification

Full raw observations are in `%TEMP%/arena45s-benchmark-debug-final.log` and `%TEMP%/arena45s-benchmark-release-verified.log`. Source fixtures contain actual semantic growth, purchases and item-origin evidence, not whitespace padding. The 1,000-origin acquisition is explicitly a source-backed disposable world-item fixture, not a claim of gameplay-earned loot. One-time legacy construction/conversion is excluded from routine checkpoint timings but included in whole-process memory peaks.

The first isolated release harness lacked the fixture scene, then could not construct the UI-driven long-history fixture. That run's overall result is **not PASS**, despite its successful small/credited/inventory cases. A matched frozen-archive rerun is recorded separately below. No production UI/admission change was made to mask a harness limitation.

Native debug observations (some overlap with other focused suites; no controlled speedup claim):

- Small first checkpoint about 0.24 s; subsequent small operations about 0.62–1.33 s.
- 233-generation converted character: compact record 236,268 bytes, retained compact footprint 997,268 bytes; three native checkpoints about **7.08 / 8.98 / 11.48 s**.
- 1,005 current items, 2,029 lifetime IDs: record **2,099,956 bytes**, retained compact footprint **10,380,410 bytes**; three subsequent checkpoints **55.85 / 68.27 / 77.17 s**. Cold load **6.80 s**, exact recovery **13.90 s**.
- Debug allocator peak **1,305,012,114 bytes**, completion live allocator **150,746,054 bytes**. These include the 233-generation legacy construction/conversion and retained test probes; they are not routine-production idle/leak measurements.

Earlier Windows release inventory observations: identical item/ID counts and record/footprint bytes; subsequent checkpoints **49.54 / 63.74 / 73.34 s**. Release Godot's static allocator counters returned 0 (unavailable), not zero actual process memory. External Windows process memory sampling is recorded separately. These stress observations predate the final candidate-object guard; the matched final-source rerun below provides comparable controlled-source cases. No false claim that the source revisions or machine contention were identical is made.

Repeated full portable ancestry replay, repeated standalone semantic validation/encoding, staging verification and multiple independent readbacks dominate growing lineages/inventories. S4 does not remove those guarantees or optimize portable export/restore. In particular, the coordinator, service and observer each validate their handoff/readback; the complete capsule is replayed repeatedly. Merely compacting hundreds of legacy files does not meet the 1–3 second routine target.

## Blockers and next boundary

1. **Performance:** large routine operations miss targets severely. A separately approved optimization must reduce redundant owned-operation work while retaining full cold semantic validation, mutation authority and persisted readback. Separating routine exact recovery evidence from portable ancestry may require an explicit retention/architecture decision; it was not implemented here.
2. **Stale leases:** no automatic safe writer recovery after actual process death. Do not activate until a verifiable ownership/lifetime protocol is reviewed and tested. No PID/timeout workaround.
3. **Publication durability:** no power-loss, hardware disk-full or universal atomic-replacement guarantee. Actual NTFS file operations plus injected failures/process termination are the evidence.
4. **Activation:** cache-only constructor/entry points deliberately remain. Production root dispatch, old-build release fencing, portable UI dispatch and owner conversion require later authorization. The playable Windows path still writes V2/V4/V5.
5. **Browser:** S5, production IndexedDB/schema upgrades and browser writer coordination remain untouched/unimplemented.

Stop after S4. No owner migration, production activation or browser pass is authorized by this report.

## Matched final-source Windows measurements

The UI-dependent long fixture was replaced **only in the benchmark setup** by the exact frozen 233-generation legacy bundle produced by the successful debug run. It was copied into a new empty disposable input root and fully revalidated by the original legacy storage/converter and independent comparison in both builds. It is not a claimed verification flag, an owner backup, a forged predecessor or a rollback of an existing destination. No game UI correction was attempted.

Both final matched reruns passed with empty failure lists:

| Same frozen 233-generation source | Godot native debug | Windows release |
| --- | ---: | ---: |
| Converter call, excluded from routine saves | 11,370.499 ms | 9,808.734 ms |
| Actual S2 preparation (three operations) | 231.687 / 231.305 / 251.313 ms | 215.178 / 191.055 / 193.093 ms |
| Existing-coordinator preparation/capsule | 940.687 / 1,227.304 / 1,532.991 ms | 918.133 / 1,098.000 / 1,251.912 ms |
| Commit, including authority/ownership/staging/readbacks/release | 1,984.047 / 2,824.705 / 3,613.711 ms | 1,783.719 / 2,503.800 / 3,372.867 ms |
| Full end-to-end checkpoint | 4,392.842 / 5,956.925 / 7,461.497 ms | 3,996.621 / 5,321.709 / 6,647.382 ms |
| Cold load | 575.537 ms | 488.660 ms |
| Exact-current repair/recovery | 1,168.636 ms | 1,015.686 ms |

Three samples, not a latency guarantee. Median end-to-end: debug 5,956.925 ms / release 5,321.709 ms; nearest-rank p95 and maximum equal the largest sample with n=3. One converter-call time is not the entire activation/admission time: locked source verification and rechecking are additional one-time work. Machine load differed; these are comparable fixture observations, not a claimed optimization speedup.

Both outputs retained **11 awards, 7 original growth records, 3 purchases, 14 current items, 517 lifetime IDs, 236 lifetime operations**, compact sequence 4. Current record **236,268 bytes**; compact footprint **997,268 bytes**. SHA-256 comparison showed byte-identical `route.json`, both retained records and the recovery capsule across debug and release. No dice or history was reinterpreted to achieve this equivalence.

Final-source release core rerun also passed: small first checkpoint **189.696 ms**, later small operations **433.998 / 711.045 / 701.295 ms**; the converted native-credit/all-five-attribute scenario passed, including later slower checkpoints up to **7,279.004 ms**. The unsupported UI fixture setup from the earlier full stress run remains honestly recorded above; it does not invalidate the separately validated frozen-source rerun or turn that earlier aggregate failure into a PASS.

The temporary release project was `%TEMP%/arena45s-release-3c58588aa3424436adfd88c6fa70cdfb/project`; its independently configured Windows test executable SHA-256 was:

`62ad9985cb348aa8abca19ba09a5f8eeb847d509201fd1c85971578d8752101a`

Only TEMP project/export settings were used. Initial harness packaging mistakes (console wrapper configured debug-only; missing fixture scene) were corrected in TEMP, never in `project.godot` or production export configuration. No production game or Web build was exported. Additional native-only I/O instrumentation was added after this test export; it is not claimed to be in that executable.

External own-process Windows sampling measured peak working sets of **1,293,807,616 bytes** for matched release long-history processing and **251,740,160 bytes** for release core tests. Debug matched-long allocator peak was **1,213,530,712 bytes**, completion **146,835,452 bytes**. The earlier all-workload debug process reached Windows peak working set **1,381,412,864 bytes**. Peaks include one-time complete legacy input validation/conversion and retained comparison fixtures; they do not demonstrate an idle-game leak or routine-save memory acceptance. Release allocator zero counters mean unavailable; browser/WASM memory was not measured in S4.

A native-only source-valid single-wave I/O probe measured **486.244 ms** end-to-end, including **94.279 ms** coordinator preparation and **226.351 ms** commit. The transport instrumentation observed:

- 8 full `load_current()` calls: **175.366 ms** inclusive.
- 48 instrumented file reads: **8.762 ms**.
- 3 writes/flush/exact-byte-readbacks: **15.567 ms**.
- 3 renames: **1.985 ms**.
- Staging/publication including staged semantic verification: **96.424 ms** inclusive.

Inclusive categories overlap and are not additive. The probe establishes repeated complete proof work and modest raw filesystem time in this small case; it is not an exact exclusive-cost breakdown of the 1,000-item case. The much larger observed capsule/ancestry costs remain an activation blocker.

## Final focused suites and commands

**13/13 native focused suites PASS; zero final failed assertions or expected failures.** S4's three counters sum to **457 assertions** (422 + 22 + 13). Compatibility suites: K 814, P 278, Q 912, R 132, N 136, original grant delivery 93; original persistence coordinator, playable Vaelis persistence, backup restoration and backup export/preview also passed (those older suites do not publish complete assertion totals). Existing Q's full unbounded legacy suite passed; it was not shortened globally. No full registered regression was run.

Final native correctness logs: `%TEMP%/arena45s-bounded-final.log`, `arena45s-hard-crash-final2.log`, `arena45s-guards-final3.log`, and `arena45s-related-*.log`. Benchmark logs: `arena45s-matched-debug-long.log`, `arena45s-matched-release-long.log`, `arena45s-matched-release-core.log`, `arena45s-io.log`. Superseded failed/aborted probes are not counted as passes. Final logs were scanned separately for script errors, warnings and resource leaks.

Commands (primary source checkout):

```powershell
$godot = 'C:/Users/mxz/Desktop/GoDot/Godot_v4.7.2-stable_win64_console.exe'
& $godot --headless --path . --check-only --script tests/test_compact_v6_windows_storage.gd
& $godot --headless --path . --script tests/test_runner.gd -- '--suite=45S Windows compact route'
& $godot --headless --path . --script tests/test_runner.gd -- '--suite=45S hard crash'
& $godot --headless --path . --script tests/test_runner.gd -- '--suite=45S Windows guards'
# Separate focused invocations: 45K,45P,45Q,45R,45N,
# 'Task 36J-Pass2','Task 36J-Pass5','Task 43G EXPC grant delivery','Task 36L-'.
# 45P/45N use previously generated disposable ARENA45P_FIXTURES/ARENA45M_FIXTURES.
& $godot --headless --path . --script tests/compact_v6_windows_benchmark_process.gd
# Matched runs use ARENA45S_BENCH_KIND=long or core, and the OS-cache-only
# ARENA45S_LEGACY_BUNDLE recorded in %TEMP%/arena45s-frozen-bundle.txt.
# Native I/O probe uses ARENA45S_BENCH_KIND=io.
# TEMP-only Windows harness:
& $godot --headless --path $temporaryProject --editor --import
& $godot --headless --path $temporaryProject --export-release 'Disposable Windows' build/bench.exe
& "$temporaryProject/build/bench.console.exe" --headless

git diff --check
```

Native filesystem recovery uses fresh adapters and real child process termination; these are automated disposable tests, not owner acceptance. No Edge/browser S5 checks were run or claimed.

## Exact Git/workspace status and preservation

Branch main; HEAD f9bb0db0235b0003895c477a12346191d4714469; index empty. Modified tracked paths: 29. Collapsed untracked entries: 105.

The task-start snapshot covers 676 existing nonprotected files. Exactly the six existing files in this manifest changed; no earlier file is missing and all unrelated files retain their hashes. All 19 additions are listed above including sidecars/report. project.godot retains SHA-256 8398f110f77d7712eb19c283eb9f745c7123feab9557187778da412639ba5692. No owner profile, browser IndexedDB, backup, protected boss document contents, character saves/ or repository tmp/ was accessed or modified. Protected entries appear below by names only. No staging, commit, push, stash, reset, rebase or Git cleanup occurred. Diagnostic cache fixtures/failed-attempt logs remain outside the project; no owner data was cleaned.

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
?? docs/audits/TASK_45E_SAVE_LOAD_PERFORMANCE.md
?? docs/audits/TASK_45G_WEB_MEMORY_DIAGNOSIS.md
?? scripts/combat/arena_mana_recovery.gd
?? scripts/combat/arena_mana_recovery.gd.uid
?? scripts/rewards/compact_character_v6_prototype.gd
?? scripts/rewards/compact_character_v6_prototype.gd.uid
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
?? tests/browser/compact_v6_credit_edge_cases.js
?? tests/browser/compact_v6_performance_edge_cases.js
?? tests/browser/compact_v6_store.js
?? tests/browser/compact_v6_wasm_harness.gd
?? tests/browser/compact_v6_wasm_harness.gd.uid
?? tests/browser/test_compact_v6_storage_edge.js
?? tests/browser/test_task_45e_edge.js
?? tests/compact_v6_backup_store.gd
?? tests/compact_v6_backup_store.gd.uid
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

## Resume closeout — verified existing results, no benchmark repeat

The interrupted frozen-archive verification had already completed. Inspection confirmed:

- `%TEMP%/arena45s-matched-release-long.log`: `debug:false`, `success:true`, empty failures, 233-generation input fully validated; exact outputs and timings above.
- `%TEMP%/arena45s-matched-debug-long.log`: `debug:true`, `success:true`, empty failures.
- `%TEMP%/arena45s-matched-release-core.log`: `success:true`, empty failures.
- The newer crash run supersedes the original 16-assertion result: **22 assertions PASS**, including actual newly earned XP and its growth surviving incremental route publication followed by process termination before acknowledgement. Exact latest state is readable; writes remain blocked by the unverified stale lease.
- Latest guard closeout: **13 assertions PASS**, without the superseded fixture's resource leaks.

No Windows build, fixture construction or expensive benchmark was repeated during resume. Only read-only evidence/source/workspace inspection, report corrections, artifact hash comparisons and final integrity checks were needed. Earlier failed infrastructure probes remain distinguished from these successful final cases. No remaining long-history release uncertainty is concealed.

**S4 verification is complete as a dormant, disposable prototype. It is not approved for production activation.** Routine-save latency and safe unattended stale-lease reclamation remain explicit blockers. Stop here; no S5/browser work or owner conversion.
