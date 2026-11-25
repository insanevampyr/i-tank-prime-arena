# Task 45N - Compact V6 portable backup and exact recovery, Pass D

2026-11-17. Isolated prototype only. Baseline main `f9bb0db0235b0003895c477a12346191d4714469`. No playable V6 dispatch, owner conversion, production persistence change, database upgrade or production Web export.

## Files

Added:

- `tests/compact_v6_portable_backup.gd` and `.gd.uid`
- `tests/compact_v6_backup_store.gd` and `.gd.uid`
- `tests/test_compact_v6_backup.gd` and `.gd.uid`
- `tests/browser/compact_v6_backup_store.js`
- `tests/browser/compact_v6_backup_edge_cases.js`
- This report.

Modified:

- `tests/compact_v6_disposable_store.gd`: extract the existing staged-publication/readback body into a shared helper. Pass C validation and publication semantics remain unchanged.
- `tests/compact_v6_storage_process.gd`: optional portable adapter for own-cache subprocess load/lost-acknowledgement testing.
- `tests/browser/compact_v6_store.js`: extract the existing IndexedDB publication CAS, permitting validated extra records in that same transaction.
- `tests/browser/compact_v6_wasm_harness.gd`: expose the portable codec through the existing direct callback, normalize JSON integer values, load the test-only adapter.
- `tests/browser/test_compact_v6_storage_edge.js`: include the isolated codec/adapter in the temporary project, and optionally invoke Pass D cases with `--backup`.
- `tests/test_runner.gd`: add one preload and one 45N suite registration, preserving earlier registrations.

No production source was modified by 45N. Existing 45B-45M work remains uncommitted.

## Portable contract

Canonical UTF-8 line-framed version 1, format `itank_arena_compact_portable`:

1. Closed manifest: profile, namespace, epoch, sequence, exact current-document SHA-256, transition count and authored source description.
2. One exact canonical V6 envelope, on its own line without another JSON string-escaping layer.
3. Zero or more reversible transition frames, in sequence order.
4. An integrity footer committing every preceding byte including line delimiters. Final newline is required.

There is no timestamp, machine path, backend field or cumulative full-generation archive. The same immutable source produces identical native/Web bytes. A backup contains the complete current state and all lifetime evidence already verified by 45K/45L: original progression dice and event-time END/HPB/WIS, purchases, XP receipts, credits, item origins, consumed items, equipment/condition, run policy, recovery/checkpoint resources, RNG and movement state. It needs no original legacy generation files. The receiving application still supplies its trusted rules/source catalog; the embedded source description MUST equal that trusted resource. It is not allowed to authorize itself.

The codec reuses V6.decode/validate/validate_extension and the existing bounded duplicate-key/depth/token scanner. A checksum or claimed verification flag never replaces semantic validation. Unknown fields/versions, changed totals, incomplete lifetime evidence, wrong identity, corrupted frames and missing ancestry reject. Native file reads verify UTF-8 byte round-trip, bounded lengths and own-cache paths.

Transitions are data, not executable game commands: sorted field changes and array splices, old/new preconditions, endpoint digests, epoch/sequence and operation ID. Reverse replay reconstructs one predecessor at a time and applies the existing extension validator to both endpoints. The chain must reach compact sequence 1; converted legacy histories begin there with their lifetime proof intact. For restore into an existing destination, replay must reconstruct that exact destination record, not merely repeat a claimed ancestor hash.

Experimental finite limits: 34 MiB total portable bytes, 16 MiB individual JSON frame/current V6 envelope, 16 MiB ancestry, 4,096 compact transitions, 4,096 changes per transition, path depth 64, plus existing scanner/core limits. These are prototype bounds, not production growth guarantees. Framing is bounded-memory, not a fully streaming parser: strings and parsed frames coexist. Ancestry and exact lifetime identities grow; no evidence is silently evicted.

## Storage reuse and recovery

Pass D subclasses the Pass C disposable adapters; it does not replace any production coordinator. Windows paths remain restricted to OS-cache `itank-storage-tests/compact45m_*`. Browser names remain restricted to `itank-arena-disposable-v6-45m-*`. The separate test DB stays at version 1 with its existing head/records stores. Production DB name/version are untouched.

The added recovery capsule is the portable file named/keyed by the exact current document hash. On Windows it is written/flushed/read back before the existing immutable-record staging and one head rename. IndexedDB installs head, current record, previous record and capsule in one exclusive read/write transaction, with the existing fresh-head and exact-current-byte CAS. Expensive native proof checks occur outside the transaction. Strict IDB durability is requested, not represented as proven power-loss durability.

Successful state retains two full compact records and one current capsule (the capsule contains one additional current copy plus compact transitions). This intentionally trades bounded snapshot redundancy for exact reconstruction after current-file damage. It is not an archive of full generations. Unreferenced known capsule/record staging is pruned only after a verified head; arbitrary files are preserved. Storage overhead is measured below.

Recovery uses the existing authoritative head as watermark. It validates the matching capsule and can reconstruct EXACT acknowledged current bytes when current is damaged/missing, then uses the existing locked/CAS repair and exact readback. It does not reapply purchases, credits, rewards or items. Previous alone is never sufficient. Missing/corrupt capsule plus damaged current returns unrecoverable; an external fully verified backup may repair only the exact acknowledged head. Missing/damaged head also fails closed: no scanning for the highest filename or silently choosing an older character. Preserve disposable files and inspect/preview them read-only; authoritative head evidence is required before repair. Entire-storage-image rollback is not prevented by offline local hashes.

## Restore protocol and cancellation

Preview performs full proof validation without opening a destination database or creating its directory. It reports profile, namespace, level, EXPM, EXPC, equipment references and compact sequence. No preview result is trusted as a cache on restore.

Explicit confirmation binds exact portable-file hash, expected destination head, profile and namespace. Restore parses and verifies the complete input again under the native lease or before the IDB transaction; publication verifies the head again. Identical installed bytes acknowledge idempotently. Newer descendants must prove exact ancestry. Older, unrelated, same-sequence conflicting, mismatched and stale imports reject. Changed files cannot reuse another preview confirmation. Empty destinations accept a completely validated compact baseline/descendant. An initial interrupted Windows restore reconciles only its own exactly matching staged files; unknown existing records block initialization.

Cancellation is modeled before publication (preview without confirmation, before-stage rejection, and aborted IDB transaction). After publication or lost acknowledgement, reconciliation returns the exact current state; cancellation is not an undo/refund. Native calls are synchronous and no playable progress/cancel UI is implemented.

## Validation and measurements

Final automated checks:

- Windows native 45N: **136/136 assertions PASS**, no failures.
- Existing 45K semantic/accounting/END/WIS proof: **814/814 PASS**.
- Existing 45M filesystem/storage: **62/62 PASS** after shared-helper extraction, including separate-process recovery.
- Actual isolated Edge + release Godot WASM/IndexedDB: **61/61 PASS** (28 existing Pass C checks and 33 Pass D checks).
- No final Godot script errors, JS exceptions, warnings or resource-leak diagnostics in captured native/import/export/browser logs.
- `git diff --check`, explicit whitespace checks for all nine new files and six edited harness/test files, and `node --check` for four JS scripts PASS.
- No full regression or production export was run. The only Web export was the disposable harness in the temporary project.

Coverage includes all six sizes; V2/V4 NORMAL and DEV profiles; V5 fixed credit accounting; original growth/equipment/checkpoints; multi-step descendants; conflicting branches/same sequence; older backups; exact confirmation and stale heads; forged totals with recomputed checksums; incomplete ancestry; truncation/version errors; no-write previews/cancellation; writer exclusion and competing IDB publication; initial and subsequent interrupted restore; repeated/lost acknowledgement; changed source head during export; exact current recovery; missing recovery proof; exact external-backup repair; evicted lifetime IDs; and three repeated large export/preview cycles.

The large fixture has 1,002 actual lifetime transport operations and 1,447 total semantic/operation bindings after two updates; its journal remains 20. V6 core tests reject duplicate rewards/purchases/credits and source-inconsistent HPB/WIS growth even when transport hashes are recomputed. Pass D restores the complete canonical record and rejects reuse of an old operation ID.

Native debug/editor filesystem measurements (seconds):

| Fixture | Portable bytes | Export | Preview | Restore + uncertain-ack retry/readback | Exact recovery | Routine save | Full routine load |
|---|---:|---:|---:|---:|---:|---:|---:|
| small | 41,522 | 0.611 | 0.186 | 1.650 | 0.495 | 0.743 | 0.234 |
| 168 | 215,946 | 1.884 | 0.557 | 4.983 | 1.457 | 2.276 | 0.713 |
| 221 | 252,251 | 2.084 | 0.630 | 5.484 | 1.606 | 2.527 | 0.786 |
| 233 | 260,471 | 2.105 | 0.643 | 5.571 | 1.642 | 2.586 | 0.808 |
| 400 | 374,866 | 2.893 | 0.896 | 7.233 | 2.133 | 3.360 | 1.049 |
| 1000 | 560,083 | 3.410 | 1.078 | 8.978 | 2.819 | 4.147 | 1.409 |

Actual Edge release WASM measurements (seconds):

| Fixture | Portable bytes | Export | Preview | Restore + uncertain-ack retry/readback | Exact recovery | Routine save | Full routine load |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| small | 41,522 | 0.163 | 0.060 | 0.385 | 0.201 | 0.324 | 0.094 |
| 168 | 215,946 | 1.033 | 0.351 | 1.837 | 0.859 | 2.779 | 0.426 |
| 221 | 252,251 | 0.925 | 0.389 | 2.322 | 1.104 | 1.860 | 0.544 |
| 233 | 260,471 | 0.962 | 0.404 | 2.253 | 1.069 | 3.124 | 0.528 |
| 400 | 374,866 | 1.413 | 0.605 | 3.417 | 1.587 | 2.979 | 0.786 |
| 1000 | 560,083 | 2.026 | 0.833 | 4.758 | 2.187 | 4.491 | 1.119 |

All measured export/preview/restore goals passed for these fixtures. The ideal 1-3 second routine-save target was missed by some cases (largest native 4.147 s, Edge 4.491 s). Load goals passed. Restore totals deliberately include the lost-acknowledgement attempt AND its successful exact retry/readback. The browser first lost-ack call returns before readback; it is not reported as a completed restore on its own. Timings are individual measurements, not percentile guarantees.

Repeated largest Edge export times were 1.971 s, 1.913 s, 1.945 s. Preview plus an additional verified load took 1.935 s, 1.950 s, 1.897 s. Native and browser portable bytes matched exactly for all six measured fixtures.

Storage overhead:

| Fixture | Baseline compact bytes | Portable/recovery capsule bytes | Delta ancestry bytes | Active native storage bytes |
|---|---:|---:|---:|---:|
| small | 35,245 | 41,522 | 2,881 | 113,698 |
| 168 | 198,745 | 215,946 | 14,131 | 614,633 |
| 221 | 235,050 | 252,251 | 14,131 | 723,548 |
| 233 | 243,270 | 260,471 | 14,131 | 748,208 |
| 400 | 357,665 | 374,866 | 14,131 | 1,091,393 |
| 1000 | 542,550 | 560,083 | 14,465 | 1,646,377 |

The largest active store is 1,646,377 bytes, including two complete records, one 560,083-byte current capsule and the checksummed head. The 14,465-byte transition representation preserves two compact transitions; the 1,000-operation legacy baseline is already included in current lifetime proof. No full legacy archive is inside the portable file.

Memory (separate scopes; MiB = 1,048,576 bytes):

- Native Godot allocator peak: 266.15 MiB, including all preloaded test suites and fixtures. Own native process peak working set: 364.16 MiB; last sampled working set 249.20 MiB. This is not Windows exported-release performance.
- Edge WASM linear capacity reached 115.00 MiB (memory capacity, not JS heap or live-character size).
- JS used heap before Pass D 16.66 MiB; after all cases/repeats 66.83 MiB; after explicit CDP garbage collection 7.83 MiB. Backing-storage bytes after GC: 2,757,226. The collection is measurement-only, not a runtime optimization.
- Renderer memory was filtered to descendants of the newly spawned disposable Edge process. Largest owned renderer: peak working set 561.97 MiB, sampled end 294.60 MiB. Other owned/spare renderers were present; this is not a single-tab allocation attribution or aggregate peak. Full per-process readings are in the disposable result JSON.
- These bounded tests do not establish absence of a leak over indefinite gameplay, nor diagnose the owner's existing 2 GB playable tab. No owner browser process, storage or character was used.

Actual browser interaction: CDP set the isolated HTML file input to the native small portable artifact, then release WASM validated its bytes and preview. A real Blob/link download landed in the temporary test directory and matched the native bytes exactly. No personal file picker or Downloads directory was used. Human/playable UI acceptance is unverified.

Commands actually used (repository root; a fresh output directory is required for a repeat):

```powershell
$godot = "C:/Users/mxz/Desktop/GoDot/Godot_v4.7.2-stable_win64_console.exe"
$env:ARENA45M_FIXTURES = "C:/Users/mxz/AppData/Local/itank-storage-tests/compact45m_session_20261117b"
$env:ARENA45N_OUTPUT = "C:/Users/mxz/AppData/Local/itank-storage-tests/compact45m_45n_session_20261117e"
& $godot --headless --path . --script tests/test_runner.gd -- "--suite=45N"
& $godot --headless --path . --script tests/test_runner.gd -- "--suite=45K"
& $godot --headless --path . --script tests/test_runner.gd -- "--suite=45M"
node tests/browser/test_compact_v6_storage_edge.js $env:ARENA45N_OUTPUT --backup
git diff --check
```

The PowerShell setup copied the six existing disposable JSON fixtures and manifest into the new fixture root. The browser runner creates a separate temporary Godot project, performs its own `--editor --import` and `--export-release "Disposable Web" web/index.html`, serves a random 127.0.0.1 port and launches Edge with a new temporary user-data directory. There is no production export or localhost:8000 interaction.

Initial development runs found/fixed the test output-path guard usage and JSON numeric-normalization bridge; the final counts above are from corrected source, without weakening semantic checks.

Evidence:

- Native results: `C:/Users/mxz/AppData/Local/itank-storage-tests/compact45m_45n_session_20261117e/native-results.json`.
- Edge results: `C:/Users/mxz/AppData/Local/itank-storage-tests/compact45m_45n_session_20261117e/edge-results.json`.
- Logs: `%TEMP%/arena45n-native-final.log`, `arena45n-45K.log`, `arena45n-45M.log`, `arena45n-edge-final.log`.
- Test-only release project: `C:\Users\mxz\AppData\Local\Temp\arena45m-wasm-VOfI3c\project`.
- Test-only PCK SHA-256: `ef31ce5b7e6ab5db4b715ada2e7ab7af98bc9a3ccf8b2ef713e1ce4b625de4bd`.
- No production BUILD identifier was generated or changed.

## Remaining blockers and limits

- No production activation, routing, migration, database upgrade, owner character conversion, UI or production backup compatibility dispatch.
- Unauthenticated local files are not a PvP/co-op authorization system. Verified local rules and known destination ancestry are the scope.
- Missing authoritative head, or current plus all exact recovery evidence, cannot be repaired automatically. An older previous record is diagnostic only.
- The additional capsule costs approximately one extra current record plus delta history; alternatives such as erasure coding or transaction-only reconstruction are deferred.
- Tested large archives convert to compact sequence 1 and then receive two native compact transitions. These measurements do not establish latency for 4,096 native transitions or indefinitely growing lifetime history. Full reverse proof work grows with both.
- Independently reconverting a later legacy archive can create a different compact epoch; those snapshots are not assumed to be descendants. Restore requires one proven compact lineage.
- This parser is bounded rather than streaming. Production paging, growth budgets and longer-chain/cancellation responsiveness need further evaluation before integration.
- Windows native debug timings and actual Edge release WASM are separate measurements. No Windows exported-release performance, real power cut, filesystem cache flush guarantee, disk-full failure, OS crash or browser process kill is proven by injected interruption/abort tests.
- Actual browser tests automate the isolated file input and download API. They do not certify the playable file dialog, owner character, human confirmation UI, mobile browser or production recovery route.

## Safety and Git

Before/after hashes cover 77 existing nonprotected changed/untracked project files. Exactly the six intended test/harness files changed; the other 71 remain byte-identical. No prior file is missing. `project.godot` remains SHA-256 `8398f110f77d7712eb19c283eb9f745c7123feab9557187778da412639ba5692`. All existing production changes are byte-identical to the start of Pass D.

Main/HEAD remain `f9bb0db0235b0003895c477a12346191d4714469`. Nothing is staged. No commit, push, reset, rebase or clean occurred. There are 28 modified tracked files and 61 untracked entries (including the three protected entries); this includes all older uncommitted work. The nine Pass D additions and six intentional test edits are listed above.

Protected boss DOC, `character saves/`, repo `tmp/`, owner backups, owner IndexedDB and owner browser tabs were not read or modified. Only cache/TEMP disposable characters were used. The pre-existing protected entries remain excluded. No production DB name/version, save/load/export/restore route, playable controls, combat, AI, rewards or advancement rules changed.

Automated prototype acceptance is complete. Owner/playable acceptance and production integration are not performed or authorized by this pass.

Exact working-tree status after Pass D:

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
?? docs/audits/TASK_45E_SAVE_LOAD_PERFORMANCE.md
?? docs/audits/TASK_45G_WEB_MEMORY_DIAGNOSIS.md
?? scripts/combat/arena_mana_recovery.gd
?? scripts/combat/arena_mana_recovery.gd.uid
?? scripts/rewards/compact_character_v6_prototype.gd
?? scripts/rewards/compact_character_v6_prototype.gd.uid
?? scripts/rewards/compact_v6_equivalence.gd
?? scripts/rewards/compact_v6_equivalence.gd.uid
?? scripts/rewards/endurance_growth_history.gd
?? scripts/rewards/endurance_growth_history.gd.uid
?? scripts/rewards/legacy_to_compact_v6_prototype.gd
?? scripts/rewards/legacy_to_compact_v6_prototype.gd.uid
?? tests/benchmark_task_45e.gd
?? tests/benchmark_task_45e.gd.uid
?? tests/browser/compact_v6_backup_edge_cases.js
?? tests/browser/compact_v6_backup_store.js
?? tests/browser/compact_v6_store.js
?? tests/browser/compact_v6_wasm_harness.gd
?? tests/browser/compact_v6_wasm_harness.gd.uid
?? tests/browser/test_compact_v6_storage_edge.js
?? tests/browser/test_task_45e_edge.js
?? tests/compact_v6_backup_store.gd
?? tests/compact_v6_backup_store.gd.uid
?? tests/compact_v6_disposable_store.gd
?? tests/compact_v6_disposable_store.gd.uid
?? tests/compact_v6_portable_backup.gd
?? tests/compact_v6_portable_backup.gd.uid
?? tests/compact_v6_storage_fixtures.gd
?? tests/compact_v6_storage_fixtures.gd.uid
?? tests/compact_v6_storage_process.gd
?? tests/compact_v6_storage_process.gd.uid
?? tests/test_compact_character_v6.gd
?? tests/test_compact_character_v6.gd.uid
?? tests/test_compact_v6_backup.gd
?? tests/test_compact_v6_backup.gd.uid
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

Pass D stops here. No production integration or next pass is authorized.
