# Task 45R — Native compact fixed EXPC credit (dormant S3)

## Scope and outcome

S3 adds one typed transition to the dormant compact validator and S2 candidate observer. It does not route playable persistence to V6, publish an owner credit, modify the grant UI, or add a general credit API. All execution evidence below uses disposable characters reconstructed from authorized authored definitions. The actual owner's grant status was neither read nor assumed.

Baseline: primary Arena checkout, `main`, HEAD `f9bb0db0235b0003895c477a12346191d4714469`. Earlier 45B–45Q work remains uncommitted. The old export worktree was not edited.

## Exact task file manifest

Added:

- `scripts/rewards/compact_v6_fixed_credit.gd`
- `scripts/rewards/compact_v6_fixed_credit.gd.uid`
- `tests/test_compact_v6_credit.gd`
- `tests/test_compact_v6_credit.gd.uid`
- `tests/browser/compact_v6_credit_edge_cases.js`
- `docs/architecture/TASK_45R_V6_CREDIT_EXTENSION.md`

Modified existing dormant/test files:

- `scripts/rewards/compact_character_v6_prototype.gd`
- `scripts/rewards/compact_v6_gameplay_candidate.gd`
- `tests/compact_v6_storage_fixtures.gd`
- `tests/browser/compact_v6_wasm_harness.gd`
- `tests/browser/test_compact_v6_storage_edge.js`
- `tests/test_runner.gd`

The fixture builders and WASM successor builder now explicitly preserve the parent's compact version. The runner adds only the 45R preload/registration. Browser cases are opt-in with `--credit`; normal harness behavior is preserved.

## Version and proof representation

The outer envelope remains version **6**. Existing compact records retain inner `compact_version: 1`. A new native fixed-credit transition requires inner **2**, with `credit_predecessor.format: "compact_native_fixed_expc_credit"`, witness **version 1**. Inner 2 is rejected without this witness; inner 1 is rejected with it. Uncredited/converted historical-credit records are not silently upgraded or reinterpreted. Subsequent candidate operations preserve inner 2 and its immutable witness.

The native witness contains:

```text
format, version
current                 exact stripped uncredited parent snapshot
counts                  prefix lengths: awards, purchases, growth,
                        settlements, chronology and operations
parent_head             exact compact epoch/sequence/parent binding
binding
  kind
  quote
    identity            profile ID and namespace
    source_digest       trusted authored rules/character identity
    rules_revision
    parent              format 6, epoch, sequence, logical digest
    parent_compact_version
    storage             exact storage head, or null for a storage-free observer
    grant               original fixed ID, amount, zero EXPM, request ID
    accounting          complete predecessor accounting
    credit_status       absent
    predecessor_digest  parent snapshot/prefix/head integrity binding
    legacy_binding      original fixed-credit calculation binding
  legacy_prepared_digest
  runtime_digest
```

Lifetime evidence arrays are referenced by exact validated prefixes, not duplicated as new historical generation documents. The parent snapshot is retained once for independent cold reconstruction. All prior lifetime IDs and associated bindings remain, beyond the latest 20 journal entries.

Hash domains remain distinct: the compact logical digest is `V6.digest(record)`; the storage head binds the SHA-256 of the full canonical encoded envelope text. The original fixed contract's `head_digest` is the predecessor **projection** digest. It is not represented as a newly invented legacy-file checksum.

## Authorization and verification

The fixed grant remains exactly:

- ID `2a3dc1f6-3870-46f0-bf50-bcce11e77c6b`.
- Profile `dev_vaelis_thorn`, namespace `dev_normal`.
- Allowlisted baseline `3df0412b72ba5d966b2eb645887fedfbb591782cffc7bff41c192e52583c6d20`.
- +10,000 spendable EXPC; +0 EXPM.

`prepare_credit()` requires the real admitted service/session/source/run context, legal existing advancement boundary, exact acknowledged parent projection/generation, and unchanged current resources and external movement checkpoint. It offers the exact quote to a trusted host confirmation callback. Missing confirmation or a different quote digest grants nothing. Simulator and external movement state are pinned across confirmation and subsequent checks. An optional trusted storage reader must return fully decoded canonical bytes with the exact head; changed or unrelated heads fail closed.

The operation-local `credit_authority()` delegates to the **existing coordinator**. It rechecks consent, source/runtime/storage, recomputes the exact fixed proposal with the original credit contract, and permits only that precise coordinator request/payload. Modified/reencoded requests cannot borrow confirmation. Cancellation invalidates the permit. It does not install an unrestricted service permission or publish to a second production writer.

The pure expected-delta helper computes the original contract's result for comparison. That calculation, its checksums, or imported proof bytes are **not owner authorization**. A test verifies that this expected proposal cannot pass the original coordinator's authorization without the separately confirmed operation-local permit. Cold validation proves source/accounting/chronology consistency; the trusted host/coordinator still controls publication. This retains the local prototype's existing trust boundary, without claiming cryptographic proof of consent or remote earning.

Cold verification reconstructs the uncredited parent from its exact snapshot, head and evidence/operation prefixes, structurally validates it, then performs full V6 validation including source-valued awards, prices, receipts, END/HPB and WIS chronology. It recomputes the original fixed-credit delta and binding; checks the credit operation, order position, sequence distance and immediate parent link; then validates the credited current character. Extension validation additionally requires reconstructed parent equality with the actual supplied previous record, exactly the original fixed payload delta, one appended credit chronology entry, and all existing continuity/item/ID checks.

No EXPM, level, attributes, HPM/HPC, Mana/AP, equipment, inventory, run policy, RNG, action or movement change is bundled into the credit. Only original credit bookkeeping and generation advancement are allowed at the grant boundary.

## Precisely approved acceptance change

The old validator rejects adding a credit to an uncredited compact parent. That remains true for untyped/legacy-version evidence. The sole new accepted case is the explicit inner-2 native fixed-credit witness whose independently reconstructed parent equals the actual parent and whose whole delta equals the original fixed grant. 45Q's original negative historical-credit-extension test is retained. Existing converted historical-credit predecessor materialization and 45P exact scoped-ID lookup remain intact. The original production V2/V4/V5 save contract, coordinator, credit contract, grant controller and UI were not edited in this task.

## Test evidence

Final native and Edge results are recorded below after validation. The native suite uses actual source-valued combats, END/WIS purchases and growth through S2, an independent disposable legacy coordinator as the expected-payload oracle, and isolated native compact storage. It covers:

- Eligible uncredited converted parent; existing historical V5 credit conversion remains inner 1.
- Missing/changed confirmation, Running drift during confirmation, stale logical heads, forged storage heads, cancellation, and changed/reencoded coordinator proposals.
- Exact +10,000 EXPC, unchanged EXPM and complete expected projection, unchanged simulator snapshot/RNG, deterministic canonical encoding/cold decoding.
- Rehashed amount/identity/source/predecessor/count/accounting/order/request/duplicate/version/storage tampering, malformed parent structures, and unrelated HPC changes at the credit boundary.
- Interruption before staging and committed/lost acknowledgement with exact persisted readback/retry.
- 22 later actual S2 operations, lifetime credit identity surviving journal eviction, reload, RESUME and explicitly authorized NEW RUN without regrant.
- Self-contained portable export, read-only preview, separately authorized disposable restore, and original historical-credit conversion compatibility.

Browser coverage uses the existing temporary Godot project/release-WASM export, a new isolated Edge user-data directory, random localhost port and the existing `itank-arena-disposable-v6-45m-*` databases. It does not connect to an owner browser or the production database. It tests the native typed proof/storage/portable path, not playable UI confirmation. No production Web artifact is built.

Commands (primary source checkout):

```powershell
$godot = 'C:/Users/mxz/Desktop/GoDot/Godot_v4.7.2-stable_win64_console.exe'
& $godot --headless --path . --check-only --script tests/test_compact_v6_credit.gd
& $godot --headless --path . --script tests/test_runner.gd -- '--suite=45R'
$env:ARENA45P_FIXTURES = 'C:/Users/mxz/AppData/Local/itank-storage-tests/compact45m_45p_session_20261117'
$env:ARENA45M_FIXTURES = 'C:/Users/mxz/AppData/Local/itank-storage-tests/compact45m_session_20261117b'
# Separate focused runner invocations with --suite=:
# 45K,45L,45M,45N,45P,45Q,'Task 43E EXPC credit',
# 'Task 43G EXPC grant delivery','Task 36J-Pass2','Task 36L-'
$disposable45rFixtureRoot = (Get-Content "$env:TEMP/arena45r-edge-root.txt" -Raw).Trim()
node tests/browser/test_compact_v6_storage_edge.js $disposable45rFixtureRoot --credit
node --check tests/browser/compact_v6_credit_edge_cases.js
node --check tests/browser/test_compact_v6_storage_edge.js
git diff --check
```

## Performance and limitations

Native measurements are Godot 4.7.2 headless **debug**, not Windows release or Edge claims. Allocator usage includes preloaded registered suites and retained disposable test probes. Some longer storage tests overlap the related suites; timings are observations, not controlled S1 before/after benchmarks. Full cold validation and persisted readback were not optimized away. Native portable export exceeds the five-second goal; this S3 pass does not claim that performance blocker is solved.

## Remaining activation blockers / next boundary

1. S4 must explicitly connect native candidate publication, coordinator authority, exact durable acknowledgement/readback and runtime bookkeeping to one production storage authority. The current observer still adopts only after the **existing legacy coordinator's** verified acknowledgement; the independent native store is disposable test infrastructure.
2. Production V6 routing, fresh/legacy-character handling, old-writer rejection, Desktop/Web recovery fences and playable confirmation dispatch remain unimplemented. Old compact readers reject inner 2; live deployment must prevent unsupported older writers.
3. Portable latency and proof growth need separate measured optimization approval. No history retention policy or checkpoint architecture was changed here.
4. Actual owner-browser grant status/acceptance is unknown. No owner profile was accessed or credited. No production activation, migration, S4, networking or new grant authorization is included.

## Workspace protection

The task-start snapshot covers 670 existing nonprotected files. Only the six pre-existing dormant/test files in the manifest may differ from that snapshot; new task files are listed separately. `project.godot` retains SHA-256 `8398f110f77d7712eb19c283eb9f745c7123feab9557187778da412639ba5692`. No owner saves, backups, production IndexedDB, repository `tmp/`, `character saves/` or protected boss document contents were inspected or changed. No stage/commit/push/stash/reset/rebase/clean was performed. Existing untracked Python cache and all prior work remain.

## Final measured S3 results

Native final log: `%TEMP%/arena45r-final2.log`, **132 assertions, PASS**, no script errors, warnings or leak reports. The earlier 120-assertion run exposed only a test export path outside the disposable store root. The store correctly rejected that path; only the test path was corrected. Its isolation guard was not weakened. A subsequent 129-assertion run passed before adding the final malformed-predecessor cases; final 132 is the superseding result.

| Native headless-debug operation | Measured time |
| --- | ---: |
| Actual S2 fixed-credit preparation | 2,170.134 ms |
| Cold decode | 66.522 ms |
| Full validation, 3 samples | 41.240 / 41.178 / 40.846 ms |
| Canonical validated encoding, 3 samples | 45.762 / 44.115 / 45.169 ms |
| Cold decoding, 3 samples | 67.532 / 67.667 / 68.194 ms |
| Export after 22 further operations | 12,904.200 ms |
| Self-contained portable preview | 4,237.085 ms |

Fixture bytes: parent **70,688**, credited record **103,741**, native witness **28,760**, later record **121,991**, parent portable **256,085**, later portable **1,119,501**. The compact credit proof introduces no newly persisted legacy generations. The larger portable artifact includes the existing Pass D transition/recovery proof across the tested sequence; this pass does not redesign that format.

Native allocator at suite completion: **146,572,976 bytes**; process allocator peak **305,384,522 bytes**, including all preloaded suites and retained test fixtures. No process RSS/isolated credit-only peak is claimed.

Actual isolated Edge release-WASM run: **39 checks PASS**, including the existing 28-check storage matrix plus 11 credit-specific checks. Test PCK SHA-256:

`bc94a755817a166629cbc451fd3f0e80c6f0ae29bde6155792eca52150a76d69`

| Edge operation | Measured time |
| --- | ---: |
| Verify/restore portable uncredited parent into empty disposable IDB | 1,864.3 ms |
| Credit publication with lost acknowledgement plus exact retry | 3,002.9 ms |
| Read-only later-credit portable preview | 4,468.1 ms |
| Restore later-credit portable | 13,965.9 ms |
| Recover exact missing acknowledged current state | 9,169.5 ms |
| Export exact later-credit portable bytes | 8,800.7 ms |

Actual accounting: **EXPM 13,200 unchanged**; available EXPC **7,200 → 17,200**; fixed credit **10,000**. Later restore/reload retained all 120 lifetime IDs and the 20-entry recent journal. Native and WASM portable bytes matched exactly. An actual page/WASM restart loaded the same credited sequence 33 head, without repeating the grant. The existing browser matrix also exercised a 1,001-operation / 1,446-ID character and rejected reused lifetime operations and forged old rewards.

Before/after the credit-specific browser phase, JS used heap was **25,416,804 → 22,565,520 bytes**; JS backing-storage size **20,937,113 → 49,068,457 bytes**. WASM capacity at phase end was **120,586,240 bytes**. These are sampled capacities/heap values with test fixtures retained, not peak renderer RSS, a leak finding, or measurements of the owner's game. No renderer RSS/credit-only high-water sampler was added. Console collection had no Godot script or JS exceptions. Export/import were programmatic proof/IDB cases; playable grant UI and owner interaction were not exercised.

**Performance gate remains open:** native and Edge portable exports exceed 5 seconds, and Edge restore exceeds 10 seconds for the 33-sequence fixture. Full cold replay of embedded recovery ancestry remains costly. S3's correctness result does not certify production latency or activation readiness.

Disposable native result root: `C:/Users/mxz/AppData/Local/itank-storage-tests/compact45m_45r_22524_6030771`. The Edge run consumed the preceding 129-assertion artifact fixture and the final source (including malformed-proof guards). SHA-256 comparisons confirmed that both independent native runs produced byte-identical `parent.json`, `credited.json`, `later.json`, `parent.v6backup` and `credited.v6backup`. Its fresh test project was `%TEMP%/arena45m-wasm-RbwLGL/project`. Full Edge JSON is in the disposable fixture directory recorded by `%TEMP%/arena45r-edge-root.txt`; console/process diagnostics remain in `%TEMP%/arena45r-edge.log`. These files are diagnostic caches, not intended checkpoint files.

## Exact final Git inventory

Branch: main. HEAD: f9bb0db0235b0003895c477a12346191d4714469. Index: empty. Modified tracked paths: 29. Collapsed untracked entries: 86. All pre-existing tracked modifications remain; this task adds no new tracked production modification beyond its test-runner edits.

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

## Final focused compatibility matrix

| Suite | Result | Printed assertions |
| --- | --- | ---: |
| 45R native compact credit | PASS | 132 |
| 45K compact V6 | PASS | 814 |
| 45L legacy conversion | PASS | 912 |
| 45M disposable filesystem storage | PASS | 62 |
| 45N portable backup/recovery | PASS | 136 |
| 45P original full-validator / exact-ID oracle | PASS | 278 |
| 45Q authorized gameplay candidate / replay and simulated-client controls | PASS | 912 |
| Task 43E original fixed EXPC credit | PASS | 69 |
| Task 43G original grant delivery | PASS | 93 |
| Task 36J-Pass2 original persistence coordinator | PASS | No suite counter |
| Task 36L-Pass2 original backup restoration | PASS | No suite counter |
| Task 36L-Pass1 original export/preview | PASS | No suite total; includes 20 size-boundary and 15 generation-168 fixture assertions |

**12/12 focused native suites passed; 0 final failed assertions.** The nine full suite counters above total 3,408 assertions; the three older suites do not publish full assertion totals, so 3,408 is not claimed as the complete aggregate. Separate actual isolated Edge/WASM result: 39/39 checks passed. No expected-failure annotations or weakened assertions were introduced. Logs are `%TEMP%/arena45r-final2.log` and `%TEMP%/arena45r-related-*.log`. All final native logs were checked for script errors, errors, warnings and leak reports; none found. Node syntax checks, GDScript parsing, tracked `git diff --check`, and whitespace checks across all 12 task files passed.

The original backup export/preview suite also reproduced its disposable generation-168 fixture: decoded 16,315,722 bytes; encoded body 17,525,314 bytes; final file 19,880,133 bytes. Original complete-backup validation remains intact. No real historical backup was read.

Final preservation verification: the task-start 670-file snapshot has exactly the six planned existing-file differences, no missing files, and no unrelated differences. New task files are the six additions in the manifest. HEAD/index and the 29-modified/86-collapsed-untracked inventory above are unchanged. No production activation or owner acceptance is claimed. S3 ends here.
