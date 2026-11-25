# Task 46B — Minimal character snapshot record and cold codec

18 November 2026. **Dormant Pass 1 only.** No playable activation, coordinator integration, storage adapter, backup/restore implementation, migration or export. Task 45U remains paused.

## 1. Exact manifest

Added:

- `scripts/rewards/minimal_character_snapshot.gd`
- `scripts/rewards/minimal_character_snapshot.gd.uid`
- `tests/test_minimal_character_snapshot.gd`
- `tests/test_minimal_character_snapshot.gd.uid`
- `tests/minimal_snapshot_cold_process.gd`
- `tests/minimal_snapshot_cold_process.gd.uid`
- `docs/architecture/TASK_46B_MINIMAL_SNAPSHOT_CODEC.md`

Modified:

- `tests/test_runner.gd`: one preload and one `46B minimal snapshot` registration. Removing exactly those two lines reproduces its entry SHA-256; all earlier registrations and line endings are preserved.

No existing codec, rule implementation, production coordinator, gameplay script, save router, UI or configuration changed.

## 2. Format specification

New domain **`itank_arena_character_snapshot`**, version **1**, supported reader version **1**. The domain was previously proposed in 46A and unused in code. Neither old character envelopes 2/4/5/6 nor W package/head versions are reinterpreted.

The canonical JSON envelope has exactly:

| Field | Contract |
| --- | --- |
| `format` | Exact new domain |
| `version` | Integer 1 |
| `reader_version` | Integer 1; unknown requirements fail closed |
| `body_json` | Canonical JSON object text |
| `sha256` | Full lowercase SHA-256 of the exact UTF-8 body text |

The body has exactly:

| Field | Meaning |
| --- | --- |
| `epoch` | Bounded nonempty character epoch; old fixture epochs are preserved as identity data, not a proof of ancestry |
| `sequence` | Positive commit count, equal to `current.generation` and complete `operations.size()` |
| `last_operation_id` | Exact last lifetime operation ID |
| `source_digest` | Full trusted authored-source fingerprint |
| `current` | Complete stripped current profile projection: original base attributes/lineage, profile/namespace/rules identity, permanent state, items/equipment, authoritative XP values, run policy/history and full existing safe checkpoint |
| `evidence` | Exactly `awards`, `purchases`, `growth`, `settlements`, `credit`, `order` |
| `operations` | All original operation IDs and immutable request bindings; supported legacy-document binding annotations remain intact |
| `lifetime_ids` | All explicit scoped IDs and full associated fact bindings, including original operations, rewards, purchases, growth, settlements, acquisition origins, credits, development commands and runs |
| `recent_journal` | Exactly the final min(20, operation count) operations; lifetime entries are never evicted |

The new sequence is explicitly the complete operation/current generation count, not the old V6 converted anchor's sequence or a W storage-head sequence. No parent digest, reversible delta, receipt chain, previous-character snapshot, recursive pre-credit snapshot or second accounting section is stored.

The original checkpoint remains the schema-12-compatible `CharacterWaveCheckpoint` contract, version 1, with its existing player/resource/RNG/clock/movement/Running/fatigue/timer/Mana-remainder fields. Its valid phases remain **entry, downtime, complete**. An unfinished wave can resume at its verified entry checkpoint; this pass does not invent arbitrary active mid-wave resume.

### Limits

| Limit | Value |
| --- | ---: |
| Decoded body | 16 MiB |
| Encoded file | 24 MiB |
| Individual data string | 1 MiB UTF-8 |
| Entries per array/dictionary/operation section | 50,000 |
| Total inspected values | 500,000 |
| Data nesting depth | 48 |
| ID / dictionary key | 1,024 characters |
| Epoch | 256 characters |
| Integer magnitude | Existing safe JSON integer bound, 9,007,199,254,740,991 |

The existing bounded scanner also applies its token/depth rules. These are file-safety bounds, not new inventory or progression rules. Both body and outer encoded-size limits must hold; an unusually escape-heavy body can reach the file limit first. There is no truncation/pruning or promise that every possible 16 MiB body fits a 24 MiB envelope.

### API and ownership

- `assemble()` constructs an **unverified** candidate from explicit JSON-shaped current facts/evidence/operations. It is not a gameplay candidate builder, grant or migration authority.
- `validate()` independently checks the body and returns a `Record` owning only immutable canonical text.
- `encode()` performs one full body validation and uses Godot's ordinary canonical JSON serializer for the body/envelope. No hand-assembled JSON serializer.
- `decode()` bounds/scans/parses both layers, verifies checksum/canonical bytes and performs one full semantic body check.
- `decode_bytes()` additionally rejects malformed UTF-8 before Godot decodes it: overlong encodings, surrogates, out-of-range scalars and truncated sequences. This prevents replacement characters and engine Unicode errors.
- `Record.copy()` and `projection()` reconstruct independent copies. No internal mutable Dictionary or actor/source reference escapes. Reassigning its owned text after initialization is ignored.

Nonnegative integral JSON numeric values use the existing contract's canonical normalization. Nonfinite/unsafe values, non-JSON object types, duplicate keys and unsupported fields/versions reject. Encoder-produced bytes round-trip exactly; noncanonical imported bytes reject rather than silently becoming a different canonical document.

`Record` is a data holder, **not an authorization capability**. No API accepts a caller-created Record or a persisted verified flag instead of independent validation. Callers must supply a trusted source and explicit expected profile/namespace; the codec does not load an arbitrary source declared by the file.

## 3. Cold validation and reused authority/rules

The new codec does not call the complete old `V6.validate()` or its recursive credit verifier. It reuses narrow original helpers without changing them:

| Original helper | Purpose in new cold verification |
| --- | --- |
| `CharacterSaveContract.validate()` | Original current-profile structure, resources/run extension basics and accounting representation |
| Coordinator `_validate_receipts()` | Original reward/purchase settlement identity, amount, event/run/wave and acquisition duplicate checks |
| Coordinator `_validate_new_items()` | Join current/terminal item provenance, definition and quantities to exact original acquisition receipts |
| V6 `_ids()` | Rebuild exact existing scoped lifetime fact bindings; no truncated/approximate IDs |
| Profile `validate_playable_xp_award()` and run-policy helpers | Original source-valued XP and immutable legacy/new per-run multiplier semantics |
| `CharacterExpcCredit.inspect()` | Original single fixed grant ID, exact eligible historical DEV profile/baseline, +10,000 EXPC and generation-reference constraints |
| V6 `_chronology()` | Original ordered awards/purchases/growth/credit facts, affordability and all five attribute applications; original event-time END/HPB/WIS, HD rolls, HPM/Mana before/after values |
| V6 `_accounting()` | Reconcile source-backed starting EXPM/EXPC, awards, spending and EXPC-only credit; no stored competing wallet |
| `CharacterProfileProjection.hydrate()` | Existing derived-stat, equipment, ownership, resource maxima, level and checkpoint/source checks |
| `CharacterWaveCheckpoint.validate()` via hydration | Existing legal phase, RNG, resource bounds, external movement profile/state, timing and run-policy consistency |
| Existing backup JSON scanner | Bounded lexical/depth/token/duplicate-key checks only; no backup/history operation is invoked |

Starting attributes and original creation HPM/Mana remain source-backed. The internally derived END proof comes from full ordered replay, never from an imported proof flag. Earlier growth uses its original event-time values; later purchases do not change those records. No current Mana/HPC refill, roll, stat allocation, reward modification or source mutation occurs.

Cold hydration still rechecks some growth arithmetic after chronological replay because that is the existing helper interface. Full scoped binding reconstruction still hashes the original binding rows. These are measured cold costs, not a new routine-save framework or another persistent index. A future shared-helper extraction is outside this pass.

### Flat credit fact, no predecessor character

`evidence.credit` preserves the existing small fixed-credit record, including original grant/target/amount/predecessor-generation reference. The complete lifetime operation list must contain the **exact original fixed-credit transaction ID at that generation's successor position**. This rejects relabelled or reassigned credit operations even after other ID bindings are recomputed. Chronology checks placement relative to awards/purchases and affordability; accounting adds the credit only to spendable EXPC.

The old scalar `head_digest` is preserved as its original reference. The new cold reader does **not** claim to authenticate that historical head or owner confirmation from a hash; it requires no prior character to look up. The trusted gameplay grant/confirmation/publication path remains unchanged and unconnected to this codec. There is no new credit command or authorization.

This is the approved 46A local trust model: bounds, exact bindings and source-backed semantic consistency, not proof of honest play from a local file. An internally consistent forged local history is not made authentic by recomputed checksums. Old V6 proof rules remain unchanged for old records and independent reference comparisons.

### Terminal ownership and consumption

The current schema-12 checkpoint's `ledger.profile_ownership` retains all acquired instance rows, including explicit zero quantities. The new cold reader requires a complete terminal row for every acquisition receipt, rejects duplicate/missing identities and wrong profile/run/namespace, checks provenance/quantity bounds through the original coordinator helper, and requires positive rows to equal the current item list exactly. This prevents accidental reintroduction of a consumed instance against its terminal state.

Some older histories may have lost terminal zero rows after reload. Such a record returns **`snapshot_consumption_evidence_unavailable`**, or `snapshot_terminal_ownership_required` when the entire section is absent. It is not silently treated as fully consumed or corrected. Existing origin/commit IDs and terminal quantities are preserved; individual historical use-event IDs/timestamps that were never recorded are not invented. Future transaction integration must retain/capture the necessary actual action identities and terminal state; this pass does not implement that adapter.

## 4. Tests and independent comparisons

Registered suite: **`46B minimal snapshot`**. Default setup creates fresh disposable current NORMAL/DEV characters and genuine combat/reward/loot/NEXT WAVE checkpoints, plus V2/V4 histories and legitimate historical/native fixed-credit candidates. It does not depend on a surviving cache for those cases.

The explicitly expanded run additionally reads only already-established disposable frozen fixtures and the exact original 233-generation archive. Its complete legacy validation/conversion and independent comparison run again; no owner profile is read. Old V6 records are checked by the **frozen pre-Y full validator** before removing predecessor state. New projections, complete ordered facts and every original ID/binding must match exactly.

Final results:

| Focused check | Assertions | Result |
| --- | ---: | --- |
| New expanded suite: 13 representative fixtures, full original233 comparison | 352 | PASS |
| Final standalone default suite, no frozen-cache option | 227 | PASS |
| Existing K full V6 reference | 814 | PASS |
| Existing generation-backed HPB replay | 141 | PASS |
| Existing historical Mana replay | 73 | PASS |

The 352 new-suite count excludes existing fixture helpers' internal checks; those are also required to have no failures. There are **13 complete independent V6/current-projection/ID comparisons**, two unobserved original-legacy simulation/RNG/current-state controls, source-backed historical conversion comparisons, and a separate fresh Godot process decoding only the new file with explicit expected source/profile context. It has no prior operation context, old character file, persisted verified flag or cached validation result.

Coverage includes:

- First committed level-one Wave 1 and subsequent NORMAL/DEV checkpoints; legacy V2/V4; both credit forms and unchanged EXPM; all five actual attribute purchases and interleaved original growth.
- Complete current resources, equipment/shield condition, gold/item quantities and ownership, RNG, movement/Running, timers and Mana remainder through whole-projection equality.
- 1,000 operations and more than 1,000 explicit lifetime IDs with only 20 journal entries; evicted IDs remain mandatory. Stress fixture has exactly 1,005 real items.
- Fully consumed instance retention, missing terminal evidence rejection and attempted reintroduction rejection.
- Source, profile, namespace, missing source, TEST, commit count, last operation, journal, duplicate/conflicting IDs, changed bindings, malformed nested data/types and unknown authority flags.
- Tampered prices/XP/HPB/WIS/HD/HPM/order/fixed-credit amount/generation/operation, including recomputed ID bindings, rather than merely checksum failures.
- Current balance, source creation attributes, item provenance/equipment, invalid resource maxima/current Mana, RNG seed, movement profile, missing checkpoint, invalid multiplier and unsupported active-combat phase.
- Truncation, malformed JSON, both-layer duplicate keys, unsupported domain/version/reader, noncanonical bytes, checksum failure, separate body/file limits, field/entry/depth limits, unsafe/nonfinite numbers and invalid/overlong/surrogate/truncated UTF-8.
- Canonical decode/encode equality, new reader rejection of old envelope domains, unchanged legacy dispatcher rejection of the new domain, immutable result isolation and unchanged original/source records.

No expected failures in final acceptance. Initial runs failed two test-control comparisons because live acknowledgements contain PackedStringArray values while actual stored JSON contains Arrays. The test now compares the **complete original encoded/decoded stored document**; no fields were omitted or expected gameplay result changed. A new provenance negative test then found the missing cold acquisition join; the new codec added the existing pure ownership check and complete terminal-row checks. Existing validators were not repaired or weakened. Intermediate diagnostic/failing logs remain preserved.

## 5. Performance and size

Native Godot 4.7.2 **debug/headless**, semantic cold validation on every call, with normal source-resource caching. Not Windows exported release, Edge/WASM, owner acceptance or total routine-save latency. Fixture creation, full original history conversion, independent legacy/V6 oracles and process startup are outside individual codec timers.

Encode includes one full cold body validation. String decode includes both JSON scanners/parsers, checksum/canonical checks and full semantics. Byte decode adds strict UTF-8 preflight. Table values and repeated samples follow below. No coordinator or physical publication/readback has been implemented or timed.

| Fixture | Items / lifetime IDs | New bytes (old V6 bytes) | Validate ms | Encode ms | String decode ms | Byte decode ms | n |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| normal_initial | 5 / 12 | 14,156 (14,377) | 3.628 | 3.614 | 7.730 | 7.977 | 1 |
| normal_next | 7 / 25 | 26,905 (27,193) | 5.591 | 5.697 | 12.209 | 13.561 | 3 |
| dev_normal_initial | 5 / 12 | 14,125 (14,346) | 3.446 | 3.519 | 7.309 | 7.774 | 1 |
| dev_normal_next | 5 / 23 | 23,718 (24,009) | 5.202 | 5.593 | 11.691 | 12.700 | 1 |
| legacy_v2 | 5 / 32 | 34,746 (35,005) | 38.746 | 41.051 | 48.781 | 47.830 | 1 |
| historical_credit | 5 / 34 | 35,813 (47,324) | 37.623 | 37.630 | 46.789 | 48.734 | 1 |
| native_credit | 5 / 34 | 35,739 (55,735) | 37.706 | 37.553 | 46.577 | 49.693 | 1 |
| legacy_v4 | 5 / 42 | 36,197 (36,456) | 40.235 | 37.505 | 46.359 | 48.435 | 1 |
| converted233 | 14 / 511 | 224,934 (243,270) | 88.560 | 90.526 | 145.100 | 153.084 | 1 |
| converted1000 | 14 / 1445 | 524,219 (542,550) | 147.992 | 146.994 | 263.389 | 292.530 | 1 |
| all_five | 13 / 88 | 70,123 (102,229) | 43.654 | 44.283 | 60.225 | 63.821 | 1 |
| inventory1005 | 1005 / 2029 | 2,099,665 (2,099,956) | 380.918 | 404.562 | 817.403 | 921.181 | 3 |
| original233 | 14 / 511 | 224,498 (242,824) | 90.107 | 91.846 | 144.804 | 154.556 | 3 |

For n=3, validation/encode/string-decode columns are medians of three additional full independent calls; byte decoding is a single observation in all rows. Other rows are single observations. These are not p95 claims. Repeated calls must produce identical canonical bytes and perform complete semantic checking; there is no validation cache.

- normal_next repeated min/max (ms): validate_ms 5.514–5.727; encode_ms 5.623–5.790; decode_ms 12.079–12.227;
- inventory1005 repeated min/max (ms): validate_ms 380.848–383.746; encode_ms 400.347–408.241; decode_ms 815.632–820.421;
- original233 repeated min/max (ms): validate_ms 87.101–91.974; encode_ms 91.343–91.878; decode_ms 144.262–145.081;

Whole expanded suite Godot static allocator usage at completion: **245,671,917 bytes**; peak **579,026,113 bytes**. Includes legacy conversion, oracle comparisons, scenes/fixtures and retained test examples/results. It is not per-record peak memory, renderer RSS, JS heap or WASM capacity. Per-fixture net-live values in the log also include test-held codec/oracle outputs; no production memory or leak-resolution claim follows. Process RSS/private memory and actual Edge/WASM were not measured.

The current record remains proportional to inventory and essential lifetime facts. Native credit predecessor removal reduces the all-five fixture from 102,229 to 70,123 bytes; the 1,005-item record remains about 2.1 MB because the actual item/evidence data is retained. Original233 output is 224,498 bytes; no original generation archive is embedded. Fixture conversion cost is excluded from codec timing and no size/performance claim is made about an uninspected owner character.

## 6. Source gaps, risks and stop boundary

- No new Prime advancement, reward, growth or equipment formula was invented. Supported current/historical Vaelis sources use the existing catalogs/allowlist. Unsupported authored exceptions or incomplete evidence return the original helper reason wrapped in a snapshot failure; arbitrary new character definitions/TEST fixtures are not silently admitted.
- A valid snapshot does not prove local earnings, owner confirmation, freshness, safe ancestry or permission to replace an installed character. Opaque historical hashes/epoch metadata are not authentication. Occupied-profile restore, head/CAS ownership and acknowledged replica recovery belong to future passes.
- Missing terminal consumption rows are a real conversion limitation, not permission to infer them. No real legacy profile was inspected or converted. Existing legacy history/conversion limits were not raised.
- Actual live battlefield construction and gameplay admission still need their existing runtime checks. Cold validation preserves and checks the existing supported checkpoint contract; it does not add arbitrary mid-wave resume or replay every prior combat event.
- Full cold source/growth/ownership/ID checking remains intentional. This isolated result establishes no routine-save, browser-memory, idle-leak or storage-durability improvement. The rejected Z serializer was not reused.
- The codec reuses narrow private prototype/rule helpers. Their contracts need regression coverage if later extracted/changed; existing V6 semantics stay untouched. Snapshot v1 has explicit reader/field limits and must not be silently reinterpreted later.
- Pass 2 must authorize actual new effects, preserve original command IDs and ordering, publish atomically through the existing coordinator and independently read back. None of those permissions follow from this cold reader.

**Stop after this record/codec pass. No candidate integration, Windows/IndexedDB routing, backup/restore, migration or activation begins without separate approval.**

## 7. Commands and preservation

PowerShell, repository root:

```powershell
$Godot='C:/Users/mxz/Desktop/GoDot/Godot_v4.7.2-stable_win64_console.exe'
& $Godot --headless --path . --check-only --script scripts/rewards/minimal_character_snapshot.gd
& $Godot --headless --path . --check-only --script tests/test_minimal_character_snapshot.gd
& $Godot --headless --path . --check-only --script tests/minimal_snapshot_cold_process.gd
& $Godot --headless --path . --script tests/test_runner.gd -- '--suite=46B minimal snapshot'
$env:ARENA46B_FROZEN='1'
$env:ARENA46B_LEGACY_BUNDLE=(Get-Content -Raw "$env:TEMP/arena45s-frozen-bundle.txt").Trim()
& $Godot --headless --path . --script tests/test_runner.gd -- '--suite=46B minimal snapshot'
# Related filters invoked separately:
& $Godot --headless --path . --script tests/test_runner.gd -- '--suite=45K compact V6 prototype'
& $Godot --headless --path . --script tests/test_runner.gd -- '--suite=45B HPB generation replay'
& $Godot --headless --path . --script tests/test_runner.gd -- '--suite=44B historical Mana replay'
git diff --check
```

Logs: `%TEMP%/arena46b-acceptance.log` (final expanded), `arena46b-standalone-acceptance.log` (final default), `arena46b-related-{45k,45b,44b}.log`. Disposable fresh histories/cold file remain under `OS.get_cache_dir()/itank-storage-tests/minimal46b_*`. Frozen inputs are the already established N/S disposable caches; the original archive path is supplied only through the explicit hint and checked against the S-test prefix. No production character files, browser database or owner backup was opened. Intermediate logs are distinct and retained.

Entry: `main`, HEAD `f9bb0db0235b0003895c477a12346191d4714469`, empty index; 29 modified tracked paths and 148 collapsed untracked entries. A preservation hash inventory captured 728 existing nonprotected source/data/test/document/config files and seven paused-U diagnostics. Final comparison/status follows below.

Roadmap and Combat Specification were not opened or modified; no alternate documents created. `project.godot`, protected boss DOC, `character saves/`, repository `tmp/`, owner data/backups/IndexedDB and earlier work remain untouched. No staging, committing, pushing, resetting, stashing, rebasing, cleaning, production import/export or full regression.

### Final preservation result

- Branch/HEAD remain `main` / `f9bb0db0235b0003895c477a12346191d4714469`; index remains empty.
- Compared all 728 entry hashes: the only changed pre-existing file is `tests/test_runner.gd`. Removing the two intended registration lines reproduces its entry bytes exactly. No existing file is missing.
- Exactly seven scoped additions match the manifest; all seven paused-U diagnostic hashes match entry. No entry status line disappeared.
- Final collapsed status: **29 modified tracked paths, 155 untracked entries**. These include earlier owner work; only the eight manifest files belong to this task.
- `project.godot` retains entry SHA-256 `8398f110f77d7712eb19c283eb9f745c7123feab9557187778da412639ba5692`.
- Final five acceptance logs contain no script errors, warnings, failure markers or leak messages. All three new UID values are unique among scoped project UID files.
- `git diff --check` passes. Git emits existing CRLF-to-LF advisories for `playable_character_persistence.gd` and the runner; no file was normalized. Direct whitespace/conflict-marker checks pass for every new file.
- Protected paths were not opened or hashed. Their names appear only in Git status; no claim is made of inspecting their contents.

Exact final `git status --short`:

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
?? docs/architecture/TASK_46A_MINIMUM_VIABLE_SAVE_SYSTEM.md
?? docs/architecture/TASK_46B_MINIMAL_SNAPSHOT_CODEC.md
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

