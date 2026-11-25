# Task 45W — Simplified V6 snapshot + exact lifetime ledger

18 November 2026. **Complete: isolated first Architecture B package/recovery pass only.** V6 and Architecture B remain dormant. Task 45U remains paused.

## 1. Exact change manifest

Added:

- `scripts/rewards/compact_v6_snapshot_package.gd`
- `scripts/rewards/compact_v6_snapshot_package.gd.uid`
- `tests/test_compact_v6_snapshot_package.gd`
- `tests/test_compact_v6_snapshot_package.gd.uid`
- `tests/compact_v6_snapshot_process.gd`
- `tests/compact_v6_snapshot_process.gd.uid`
- This document, `docs/architecture/TASK_45W_SIMPLIFIED_V6_PACKAGE.md`.

Modified: `tests/test_runner.gd`: one preload and one registered **45W snapshot package** suite. Removing just those two lines reconstructs the exact pre-task runner SHA-256 `e108f57ef9d41bd3f2903740c1910943ea7ce9164bf8861382ca3e87bf483372`. Earlier registrations remain intact.

No existing codec, rule validator, candidate builder, coordinator, portable codec, Windows route, browser route or playable source was changed.

## 2. Preparation and version decisions

Read the V/J/O/Q/R/S/T reports and inspected their actual codec, lifetime-ID, candidate, fixed-credit, coordinator, portable, Windows and browser implementations. Earlier O missing-candidate/credit findings are historical: Q/R now exist and are preserved.

Existing reservations: character-save envelope **6**, inner compact versions **1/2**, existing portable format version **1**, and S4/S5 storage route version **1**. This pass introduces separate explicit domains, never reinterprets those versions:

| Component | Format | Version |
|---|---|---:|
| Snapshot package | `itank_arena_snapshot_ledger` | 1 |
| Receipt container | `itank_arena_snapshot_receipts` | 1 |
| External package head | `itank_arena_snapshot_head` | 2 |

These domain/version pairs were unused. The head is not an activated storage route. Old readers reject the new package; a future installation needs an explicitly compatible reader/recovery build. No minimum-reader fence or new storage publication was installed here.

## 3. Representation and integrity

One package consists of four canonical UTF-8 JSON frames, each terminated by LF:

1. Manifest binding target, trusted source/rules, epoch, sequence, current logical digest, exact encoded-record SHA-256, evidence/ledger/checkpoint/current/journal digests, counts and receipt tip.
2. **Exact original V6 encoded record bytes**, unchanged.
3. Compact immutable receipt chain.
4. SHA-256 integrity footer covering frames 1–3 including their LF separators.

The external canonical head binds the package SHA-256, manifest/tip, identity/source/rules, epoch/sequence, V6 logical and encoded-byte digests, and replica identity `[profile,namespace,epoch,sequence,"latest_exact_replica"]` plus exact package digest. The package does not hash its external head, so no digest cycle exists.

Finite limits: 24 MiB package, unchanged 16 MiB V6 record, 4 MiB receipt frame, 4,096 receipts, 64 KiB manifest, 16 KiB head. Limits fail closed; no pruning or implicit receipt reanchoring. Long-term receipt retention/anchor policy requires a later decision.

The existing V6 record remains the single logical current authority. It retains:

- Full scoped lifetime IDs and immutable bindings, full original operation IDs/request digests, and the existing final-20 recent journal.
- Essential source-valued awards/settlements, purchases, original growth/order, credit evidence, item origins/uses and current equipment.
- Original and permanent character facts, resources and the actual run/wave recovery checkpoint, RNG, movement, fatigue and timers.

There is no new wallet, competing ledger, reversible transition archive or full predecessor snapshot per commit. No evidence is removed to reduce size. In particular, the source-required native fixed-credit predecessor witness remains inside the unchanged V6 proof; it is necessary evidence, not a second writable current character.

An anchor wraps a fully validated record at its actual sequence (including sequence >1); it does not invent old receipts. A commit is constructed only after verifying the complete supplied parent package/head and applying unchanged `V6.validate_extension()` to the actual parent/candidate. Each receipt binds its actual current state, original operation ID/request, and exact parent epoch, sequence, logical/byte digests, receipt digest and operation binding.

## 4. Full standalone cold verification

`verify_package()` validates the complete self-contained package. `cold_verify()` additionally requires the externally supplied acknowledged head; no missing-head inference or "verified" flag exists.

Every cold invocation performs bounded duplicate-key/depth/size scanning, canonical-byte/checksum/version checks, exact target/source/rules comparison, and the existing **full V6 decoder/semantic validator**. This reuses original rules rather than writing another progression validator:

- Reconstructs permanent advancement and chronological END/HPB/WIS growth.
- Validates original creation maxima, rolls, event-time attributes, prices, EXPM/EXPC/spent/fixed-credit accounting and receipts.
- Validates item ownership, instances, quantities, consumption, equipment, current resources and run/checkpoint contract.
- Recomputes all exact scoped IDs/bindings and the 20-entry journal.
- Recomputes manifest facts from those verified bytes and checks closed receipt schemas, chain links, actual operation rows, latest state and head/replica bindings.

The W wrapper additionally requires nonempty current run/checkpoint evidence and equipment state. Source and expected profile/namespace are trusted inputs, not imported authority. Tests resolve exact allowlisted authored resources. Cold verification never loads original historical generations or reversible deltas.

**Trust limit:** local SHA-256 proves exact-byte integrity, not server authentication or authorization to award/spend/publish. A self-hashed supplied head is not independent proof that storage acknowledged it. Future routing must supply authoritative head/ownership/CAS and existing coordinator authorization. This package API grants no publication or restore authority.

## 5. Exact latest-state repair

`recover()` is a pure decision returning exact repair bytes; it writes nothing.

| Input | Verified result |
|---|---|
| Intact current and replica | Exact current returned. |
| Missing/truncated/damaged current, exact matching latest replica | Full cold validation of replica; byte-identical current repair returned. |
| Intact current, damaged replica | Current remains valid; exact replica repair proposed. |
| Current damaged, older valid replica | Rejected against newer acknowledged head. |
| Both copies damaged | Unrecoverable; no previous-state fallback. |
| Missing head or conflicting head witnesses | Fail closed. |
| Altered sequence, source/target, replica identity or head version | Rejected even after local checksums are recomputed. |

Every successful result has `restore_authorized:false`. Exact equality covers all IDs, XP/credit, growth, purchases, inventory and resources. A fresh child Godot process loads only the disposable package/head/replica plus allowlisted source context, cold-verifies independently, and repairs the damaged current without warm caches.

This demonstrates package logic, not disk flush, power-loss durability, atomic publication or automatic repair of real storage.

## 6. Lineage and restore limits

Receipt hashes structurally bind claimed earlier state digests and original operations to the latest chain. They do **not** independently replay omitted intermediate character states.

- Exact installed package: diagnostic no-op.
- Direct child with both actual full endpoints: unchanged full V6 extension validation; diagnostic `verified_direct_extension`.
- Older, conflicting same-sequence, unrelated epoch, missing receipt prefix, altered receipt or immutable binding: rejected.
- More than one step with receipts but absent intermediate semantic states: `receipt_path_requires_intermediate_semantic_proof`, even when structurally linked.
- A higher-sequence standalone anchor cannot establish missing ancestry.

The direct/sibling/two-step tests use source-valid transport-only fixture operations granting no XP, items or credits. They do not claim new gameplay authorization. Existing source-backed all-five-purchase/fixed-credit records are verified separately.

**All occupied-profile replacement remains blocked**, including direct-child diagnostic success. No restore API or storage integration was created. A later owner-approved, testable semantic batch/lineage authority is needed before receipts alone can authorize a longer occupied-profile replacement.

## 7. Focused tests and equivalence

Final executed checks, Godot 4.7.2 native debug:

| Check | Assertions | Result |
|---|---:|---|
| Registered W suite using fresh disposable histories, including actual first committed level-one character | 86 | PASS |
| W expanded existing frozen-fixture matrix and original 233-generation archive | 262 | PASS |
| Existing unchanged K full V6 reference suite | 814 | PASS |
| New package script and test parse checks | — | PASS |
| `git diff --check` and explicit new-file whitespace checks | — | PASS |

No expected failures in final runs. Earlier runs exposed a fixture reader that rejected valid disposable `.v6` files, an older fixture without a preference-development baseline, and test variable type-inference errors. Those test setup errors were corrected; no production rule or expected integrity result was weakened. The final registered suite creates its own source-backed fixtures and needs no surviving benchmark cache. The expanded matrix is explicitly opt-in.

Coverage includes NORMAL/DEV V2/V4-derived characters; fresh creation; 168/221/233/400-generation converted records; historical and native fixed credits; all five permanent attribute purchases; interleaved END/WIS and level growth; 1,445+ IDs surviving journal eviction; 1,005 items/2,029 IDs; duplicate awards/purchases/credit/operations; missing/altered ID bindings; changed totals, chronology, HPB/WIS and source; missing credit predecessor/checkpoint; truncation, unsupported versions, noncanonical bytes and untrusted verified flags; exact replica and cold-process checks; lineage conflicts; deterministic repeated output.

Every accepted package's original V6 bytes, complete current projection, full evidence and checkpoint equal the independently decoded original record. Invalid semantic variants are also independently rejected by the unchanged V6 validator after the test deliberately recomputes outer checksums.

Frozen 168/221/400 and 1,000-operation inputs are existing independently validated disposable K–S outputs, fully V6-validated again here. Their original full legacy archives were not all retained, so no new original-archive comparison is claimed for those. The exact frozen **233-generation original archive** was available: full legacy validation, conversion and independent original-character equivalence ran again; the new cold projection equals that original legacy head exactly. No source facts were fabricated.

Commands (PowerShell, repository root):

```powershell
$godot = 'C:/Users/mxz/Desktop/GoDot/Godot_v4.7.2-stable_win64_console.exe'
& $godot --headless --path . --check-only --script scripts/rewards/compact_v6_snapshot_package.gd
& $godot --headless --path . --check-only --script tests/test_compact_v6_snapshot_package.gd
& $godot --headless --path . --script tests/test_runner.gd -- '--suite=45W snapshot package'
# Additional bounded audit matrix uses the explicitly frozen disposable fixtures:
$env:ARENA45W_FROZEN_MATRIX = '1'
$env:ARENA45W_LEGACY_BUNDLE = (Get-Content -Raw "$env:TEMP/arena45s-frozen-bundle.txt").Trim()
& $godot --headless --path . --script tests/test_runner.gd -- '--suite=45W snapshot package'
Remove-Item Env:ARENA45W_FROZEN_MATRIX
Remove-Item Env:ARENA45W_LEGACY_BUNDLE
& $godot --headless --path . --script tests/test_runner.gd -- '--suite=45K compact V6 prototype'
git diff --check
```

Logs: `%TEMP%/arena45w-default.log`, `arena45w-final.log`, `arena45w-reference.log`. Fresh-process artifacts are only under `OS.get_cache_dir()/itank-storage-tests/compact45w_restart_*`; ordinary W fixture histories use `compact45w_fixture_*`. The frozen matrix reads only the previously established disposable M/N/S caches and explicit frozen S archive. No production storage is touched.

## 8. Measurements

Windows **native debug**, same process and fixtures, package/recovery operations only. Build includes full V6 decoding/semantic validation, manifest/receipt generation, canonical framing and hashes. Cold includes mandatory head, scanners, full V6 replay and package/receipt/head verification. Repair measures damaged current plus full latest-replica verification; no disk publication/readback/coordinator is included. One exact replica has exactly the package's byte count.

| Fixture | IDs / items | Package bytes | Head bytes | Build ms | Cold ms | Repair ms | n |
|---|---:|---:|---:|---:|---:|---:|---:|
| normal_v2 | 28 / 7 | 33,962 | 1,121 | 47.561 | 47.865 | 48.699 | 1 |
| normal_v4 | 40 / 7 | 38,954 | 1,121 | 49.739 | 50.478 | 51.179 | 3 |
| dev_normal_v2 | 32 / 5 | 38,201 | 1,127 | 50.175 | 51.769 | 51.832 | 1 |
| dev_normal_v4 | 42 / 5 | 39,927 | 1,127 | 50.223 | 51.238 | 51.708 | 1 |
| small | 32 / 5 | 37,781 | 1,127 | 49.720 | 50.402 | 51.635 | 1 |
| 168 | 381 / 14 | 201,293 | 1,127 | 181.714 | 181.682 | 180.842 | 1 |
| 221 | 487 / 14 | 237,598 | 1,127 | 205.205 | 208.326 | 207.402 | 1 |
| 233 | 511 / 14 | 245,818 | 1,127 | 208.833 | 213.295 | 212.687 | 3 |
| 400 | 845 / 14 | 360,213 | 1,127 | 282.158 | 286.321 | 284.894 | 1 |
| 1000 | 1445 / 14 | 545,107 | 1,127 | 365.863 | 367.516 | 373.853 | 1 |
| native_credit_all_five | 88 / 13 | 104,861 | 1,129 | 171.554 | 173.554 | 174.291 | 1 |
| inventory1005 | 2029 / 1005 | 2,102,587 | 1,127 | 1038.426 | 1086.879 | 1083.203 | 1 |
| legacy233_independent | 511 / 14 | 245,372 | 1,127 | 208.292 | 210.330 | 210.925 | 1 |

Rows with n=3 show medians; others are single observations, not p95 guarantees. For the frozen 233 case, build min/median/max **207.271 / 208.833 / 221.370 ms**; cold **211.122 / 213.295 / 213.519 ms**; repair **210.984 / 212.687 / 227.738 ms**. Timings are not constant-time claims and scale with full retained lifetime evidence/inventory.

The frozen 233 package adds **2,548 bytes** over unchanged V6 bytes; one anchor receipt is **1,216 bytes**. Current + exact replica + external head total **492,763 bytes**. The 1,005-item package is **2,102,587 bytes**; current + replica + head **4,206,301 bytes**. No reverse ancestor states are needed to represent these packages.

One-time 233 original-archive verification/conversion: **17,321,373 legacy document bytes**, **11,104.465 ms legacy validation**, **48.450 ms extraction**, **109.978 ms independent equivalence**, **11,491.739 ms total**; output **242,824 bytes**. These stages are excluded from ordinary package timings.

Process-wide Godot static allocations at expanded-suite completion: **239,948,453 bytes**, peak **572,718,017 bytes**, including every preloaded test, retained comparison packages and original-archive conversion. These are allocator statistics, **not renderer RSS, JS heap or WASM capacity**. Converter's field named `native_process_peak` also calls `OS.get_static_memory_peak_usage()`; it is not an OS RSS measurement. For the 233 samples, net live allocation deltas were **5,863,236 / 1,473,660 / 0 bytes**; high-inventory first-sample delta **42,258,984 bytes**. Samples retain reference/verification outputs, so these are not isolated peak allocations or a leak test.

No fresh Windows release, Edge/WASM or browser memory results were collected. No production export occurred. S4/S5 end-to-end save/acknowledgement and capsule tests have different boundaries, sequences and often bytes. Comparing them directly to these package-only numbers would be invalid; no routine-save speedup or 1–3 second integration acceptance is claimed.

## 9. Remaining blockers / stop conditions

1. Existing coordinator authority must be reused for a later sealed candidate/package boundary. W is not an incremental authorization optimization and does not resume U.
2. Later explicitly versioned Windows/browser routes must atomically publish/bind package, replica and acknowledged head, reject old writers, handle CAS/ownership/lost acknowledgement and independently compare actual readback. None is installed here.
3. Multi-step receipt-only semantic lineage is unproved. Occupied restore stays blocked. Do not infer a safe descendant from higher sequence, XP or matching identity.
4. Head conflict or loss of both exact latest copies must remain a diagnostic failure, never silent fallback.
5. Limits and O(lifetime evidence + operations + receipts + inventory) growth remain; no infinite-capacity or bounded-memory streaming claim.
6. Cold validation is intentionally full and may allocate/copy. S2/S3 work reuse, IO/readback integration and fresh release/Edge measurements need separate authorization.
7. No owner migration, compatibility-reader removal, Windows stale-lock handling, production backup control or networking work was performed.

## 10. Workspace protection and exact Git status

Branch **main**, HEAD **f9bb0db0235b0003895c477a12346191d4714469**. Index remains empty. At entry: **29 modified tracked paths / 125 collapsed untracked entries**. At completion: **29 / 132**; seven new W files, one W addition to the already-modified runner.

SHA-256 comparison of **702 pre-existing nonprotected project files** found only the intended runner change. Its two-line reversal matches the pre-task byte hash. All five preserved `arena45u-*` diagnostic/benchmark files match their entry hashes. The paused U candidate/benchmark sources and earlier B–T/V work remain unchanged.

`project.godot` is byte-identical to task entry, SHA-256 `8398f110f77d7712eb19c283eb9f745c7123feab9557187778da412639ba5692`. Protected boss documents, `character saves/`, repository `tmp/`, owner backups and owner browser storage were not opened or modified. Git status lists protected paths by name only. No staging, commits, pushes, resets, rebases, stashes or cleanup occurred.

The following status is a filename-only audit; pre-existing generated/unrelated entries were preserved, not approved for staging.

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

**STOP: no coordinator integration, Windows/browser routing, migration or activation.**


