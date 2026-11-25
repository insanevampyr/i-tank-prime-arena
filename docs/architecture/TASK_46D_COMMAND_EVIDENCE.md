# Task #46D — Exact equipment and consumption command evidence

2026-11-19. **Complete: dormant format extension and focused tests only.** No playable activation, production storage, migration, backup changes or continuation of the full #46C2 aggregate. Task #45U remains paused.

## 1. Exact manifest

Added:

1. `scripts/rewards/minimal_character_snapshot_v2.gd`
2. `scripts/rewards/minimal_character_snapshot_v2.gd.uid`
3. `scripts/rewards/snapshot_command_evidence.gd`
4. `scripts/rewards/snapshot_command_evidence.gd.uid`
5. `tests/test_snapshot_command_evidence.gd`
6. `tests/test_snapshot_command_evidence.gd.uid`
7. `tests/minimal_snapshot_commands_cold_process.gd`
8. `tests/minimal_snapshot_commands_cold_process.gd.uid`
9. `docs/architecture/TASK_46D_COMMAND_EVIDENCE.md`

Modified:

10. `tests/test_runner.gd`: exactly one preload and one `46D command evidence` suite registration. Earlier registrations and CRLF bytes are preserved.

The original snapshot v1 codec, V6 validators, production coordinator, #46C2 partial aggregate, capture gate, session/simulation/ledger, source catalogs, storage, backup code and UI are unchanged. The existing v1 aggregate still rejects unsupported equipment/consumption; it has not been switched to v2.

## 2. Audited source path and authority

Read the #46A, #46B, #46C-1 and #46C2 reports and inspected actual codecs, original commands, item selectors, receipt normalization, checkpoints, action timing and test fixtures.

| Original path | Original facts retained / reused |
| --- | --- |
| `ArenaCombatSession.request_player_inventory_equip()/unequip()` → `_apply_player_equipment_transaction()` → `CombatSimulation.apply_downtime_equipment_transaction()` | Original accepted request ID; before/after equipment and hands; affected inventory counts; armor modifier vectors; source-selected instance IDs and quantities; required Act and paused-downtime fields. |
| `request_player_weapon_handling()` → `request_weapon_handling()` → `_commit_weapon_handling()` | Original request ID, weapon, operation, before/after handling mode and hands, ownership and Act requirements. Active zero-Act stow has no action-start event; active draw does. |
| `request_player_inventory_consumable_use()` → `use_verified_consumable_during_downtime()` | Actual request, potion definition/effect, selected original instance, quantity before/after, original individual dice and RNG indices, bonus, current/max resource before/after and source Act requirement. |
| Active potion request → `start_verified_consumable_healing_action()` → original declaration/start/completion → `_apply_verified_consumable_healing()` | Resolution events lack a direct request ID. The extractor binds them to the actual original action declaration/request, start, timing context and terminal event. Healing and Mana resolution retain their distinct original fields. |
| Accepted timed action interrupted before its effect | The original accepted request and action identity remain lifetime evidence even though no item is consumed and no healing occurs. Interrupted actions are not treated as unsuccessful/unaccepted requests. |
| `ground_loot_collected` → original `ingest()` and settlement/item-origin receipts | Exact acquired instance reference and its position among commands. Quantities/provenance come from original already-validated acquisition receipts; no item is manufactured from terminal inventory. |
| Original `ingest()`, `select_instances()`, `_sync_items()` and checkpoint | Original selectors bind actual instance ownership. Explicit zero-quantity rows remain in terminal ownership even when absent from current positive-quantity inventory. |

### Cold checks reuse original rules

The v2 validator first calls the unchanged complete v1 semantic validator on the original base sections/IDs. This retains source/rules identity, five attributes, original END/HPB/WIS growth chronology, balances/credits, receipts, current inventory/equipment and schema-12 checkpoint validation.

For additional command checks it reconstructs item availability from the original source starter and ordered original acquisition references. Equipment changes are replayed through the **original session equip/unequip APIs** in a private scratch session with no persistence attached. Original `CombatWeaponHandling.plan()`, catalog validation/modifiers, `PrimeV3InventoryCatalog` potion definitions/hand rules, original instance selection and original `_sync_items()` are reused. Resource arithmetic and recorded dice are checked independently without rerolling source history. Source-backed progression prefixes provide the applicable permanent STR, HP maximum and Mana maximum; the existing v1 chronology has already validated those purchases/growth.

This scratch session is a validator, not another gameplay authority or wallet. It never mutates the original actor, session, ledger, RNG, source or committed profile. The whole original simulation snapshot, including events/RNG, is compared before and after validation.

Runtime eligibility remains the responsibility of the original successful command paths. A self-contained local file cannot authenticate that an omitted combat/status episode actually happened. The cold checker verifies the replayable item rules, original timing constraints, ownership and arithmetic; it is not a combat-transcript replay or an anti-cheat signature system. This is the approved #46A local trust model.

## 3. Explicit successor format

Domain remains `itank_arena_character_snapshot`; **envelope version 2, reader version 2**. Version 2 was unused in this domain before this task. Existing save envelopes and V6/W versions are unrelated and untouched.

The v2 module is separate. Its reader delegates version 1 to the unchanged v1 decoder and labels that result `format_version:1`, `command_coverage:"unknown_read_only"`. It returns the original immutable v1 record; no migration/rewriting occurs. The old reader rejects v2. Unknown versions/readers reject.

The envelope still contains exactly format, version, reader version, canonical `body_json` and full body SHA-256. Existing strict parser, duplicate-key, UTF-8, safe-number, canonical serialization, 16 MiB body / 24 MiB file, depth, total-value and per-field limits are retained. Hashes detect corruption and bind bytes; they do not authenticate earnings or source consent.

The base body is unchanged except:

```text
command_evidence = {
  coverage: "creation_to_checkpoint",
  run_id: <the original single run ID>,
  facts: [ <ordered acquisition/command facts> ]
}
```

There are at most **8,192 facts**, including acquisition references. No pruning or truncation occurs. Other inherited limits may be reached earlier.

Each fact has exactly:

- `event_type`, original `event_id`, `parent_event_id`, original `event_sequence`, `timestamp_us`;
- `progression_index`: the original essential progression prefix applicable at this event;
- original `request_id` (acquisition references retain the source collection request when present);
- `payload`: the necessary original command fields, or just the acquired instance reference;
- `action`: empty for immediate commands, otherwise original action identity, declaration/start/terminal references and sequences, start/terminal times, required/completed Acts, event-time AT, timing anchor, starting interval index and due time.

The timing fields are read from the actual original action, never invented. Due times are checked through the original `_get_action_interval_timestamp()` with safe integer bounds. A completed action must satisfy its required Acts and original due time; a resolved effect must refer to that completion. An interrupted action binds its actual terminal event and cannot masquerade as completed healing/draw. Reusing an action instance for another accepted command rejects.

Equipment inventory maps retain **only affected definitions**, preserving original key presence and zero values. The source replay regenerates the same restricted maps. Unchanged inventory is reconstructed from origins and commands; it is not copied into every fact. No complete historical character, duplicated general combat transcript, receipt chain, reverse ancestry, second wallet or persistent lookup index is stored.

### Exact lifetime membership

All old scoped IDs remain under their original semantics. Each non-acquisition command adds:

```text
scope = "item_command"
id = the FULL original accepted request ID
record_digest = full SHA-256 of {
  epoch, profile_id, namespace, rules, source_digest, run_id, fact
}
```

Equipment, handling and consumption share this scope, matching the original shared accepted-request protection. IDs are never truncated, normalized, reconstructed from inventory or replaced with checkpoint IDs. Acquisition origins continue to use the original `item_origin` scope/receipt authority; collection references can share one collection request across multiple items.

The entire registry is independently rebuilt from explicit facts and compared exactly. Journal eviction cannot delete a command fact or ID. Sequence remains the original checkpoint operation/generation count; multiple commands may occur between two checkpoints. The approximately 20-entry recent journal remains the original suffix of checkpoint operations.

`Record.command_request()` checks exact membership and immutable binding: identical old binding returns `duplicate_command`; a changed binding under the same original ID returns `conflicting_command_binding`. A new ID is only an absence result, **not authorization to perform an effect**.

`validate_extension()` independently cold-validates both records, then preserves identity, lineage, operation/evidence/command prefixes and every original scoped binding. Same-sequence unequal records reject. This is a pure comparison, not publication or gameplay authority. It does not implement NEW RUN or new-credit authorization.

## 4. Supported-prefix and legacy policy

The source extractor `from_session()` is dormant and has no playable caller. It accepts only:

1. A genuine original service/session with an exact independently valid committed base view.
2. No pending player action and an original `_capture()` matching that committed checkpoint exactly.
3. A complete available first-run source event prefix, including the original profile-applied marker at generation 0 with no restored checkpoint.
4. A single known original run, original progression facts in their actual order, all nonstarter acquisitions and complete original action request/timing records.

It rejects changed heads, pending/stale runtime checkpoints, restored/partial logs, unknown original requests, ambiguous acquisitions, missing action timing, multiple runs and credit histories requiring new integration. It does not retrospectively invent facts from current equipment, quantity or operation hashes.

This extractor is a bounded **disposable source-fixture/cold proof bridge**, not the new routine transaction producer. Future #46C2 work must append newly observed original facts at its owned capture boundary and carry the admitted immutable prefix. It must not scan/reconstruct a lifetime combat transcript on every save.

Historical v1/V2/V4/V5-derived profiles lacking original equipment/consumption facts remain inspectable under their old semantics. They cannot be silently upgraded to command-verified v2. In particular, the old 233-generation fixture is **not claimed to have verified missing command IDs**. A future conversion is supported only where the complete genuine required evidence is independently available. Otherwise the precise result is unavailable prefix/history, not an inferred empty ledger.

No additional owner ruling is needed to reject unsupported conversions; that is explicitly approved in #46D. If future activation must keep such characters writable with a weaker/unknown legacy prefix, that requires a separate explicit policy decision. This pass does not provide it.

## 5. Tests and evidence

All data is disposable. Source fixtures use the existing original gameplay helper/legacy writer and independently checked V6 projection. Potions/shield are acquired through the established source-backed disposable ground-item creation/collection paths; original ownership receipts are real. Wounded/spent-Mana setup is explicitly disposable setup, not a fabricated healing/credit event. Every tested item use, dice result, equipment transaction and accepted ID comes from the original API.

| Focused suite | Final result | `%TEMP%` evidence |
| --- | --- | --- |
| 46D command evidence | **174 assertions, 0 failures** | `arena46d-verified.log` |
| Existing 46B minimal snapshot | **227 assertions, 0 failures** | `arena46d-v1.log` |
| Existing 46C2 routine transactions | **95 assertions, 0 failures** | `arena46d-46c2.log` |
| Original Task 36C inventory/equipment | PASS; assertion count not printed | `arena46d-inventory.log` |
| Original Task 36G-Fix2 weapon handling | PASS; assertion count not printed | `arena46d-handling.log` |

Five selected suites passed: **496 explicitly counted assertions**, plus unreported assertion counts in the two original suites. Final logs contain no script errors, warnings or resource-leak messages. These are not full regression or browser/Release acceptance results.

Coverage:

- Fresh NORMAL and legacy DEV identities; actual equip, unequip, shield equip, stow and one-Act active draw.
- Health potion 1d10+2 and Mana potion 3d6+2 from the original verified catalog, actual original RNG draws and instance selections.
- Three uses exhaust a real stack; its explicit terminal zero row remains while current positive inventory excludes it.
- Original duplicate requests and cross-kind conflicting reuse produce no additional effects or RNG.
- Multiple genuine active operations occur without another checkpoint generation.
- An interrupted accepted potion request remains an exact lifetime ID without another consumption/heal.
- More than 20 genuine source checkpoints evict only the recent journal; old commands remain in the full registry.
- Two fresh child processes independently decode actual v2 bytes and reject the old consumed/interrupted request IDs without prior process trust.
- Full canonical round-trip, no mutable record aliases, old-reader v2 rejection, v1 inspection without reinterpretation and no implicit upgrade.
- Original current projection/evidence equality and unchanged original session/events/RNG before/after cold validation.
- Rehashed missing uses, duplicate IDs, reused original event under a new wrapper, changed quantities/effects/dice/ownership, illegal hand assignment, missing IDs, malformed equipment/consumption payloads, reordered facts, false progression prefixes, unsupported coverage and caller verification flags reject.
- Truncated files, damaged checksums, duplicate JSON keys, incompatible versions/readers and explicit command-section limits reject.
- Changing a timed draw's source due time cannot pass by rebuilding hashes.
- A changed but internally consistent opaque ID can satisfy standalone local semantics; comparing the admitted immutable prefix rejects that substitution. This explicitly tests the difference between cold consistency and original gameplay authority.

Commands (from the actual Arena checkout):

```powershell
$godot = 'C:/Users/mxz/Desktop/GoDot/Godot_v4.7.2-stable_win64_console.exe'
& $godot --headless --path . --script res://tests/test_runner.gd -- '--suite=46D command evidence'
& $godot --headless --path . --script res://tests/test_runner.gd -- '--suite=46B minimal snapshot'
& $godot --headless --path . --script res://tests/test_runner.gd -- '--suite=46C2 routine transactions'
& $godot --headless --path . --script res://tests/test_runner.gd -- '--suite=Task 36C source-verified inventory and equipment'
& $godot --headless --path . --script res://tests/test_runner.gd -- '--suite=Task 36G-Fix2 shared weapon handling'
git diff --check
```

The child process uses `tests/minimal_snapshot_commands_cold_process.gd`, restricted to the explicit disposable `commands46d_` OS-cache prefix and a fixed filename. It verifies the exact source baseline and exported text hash before full decode.

Development failures were retained in TEMP logs: a new test used a Godot StringName dictionary key rejected by the strict JSON boundary; an initial source-field assumption was corrected to the original actor-instantiation pattern; an unavailable Great Sword fixture was removed rather than changing its STR rule; NEXT WAVE already starts combat, so the fixture now checks that legitimate state; and active zero-Act stow was initially incorrectly required to have an action-start record. These are corrected new-code/fixture issues, not newly reported gameplay defects. No existing test expectations or rules were weakened.

## 6. Size and bounded native observations

Final single native Godot debug samples, with other focused processes running:

| Fixture | Facts | Exact item-command IDs | File bytes | Full v2 encode/validation |
| --- | ---: | ---: | ---: | ---: |
| NORMAL | 35 | 30 | 75,636 | 53.400 ms |
| Legacy DEV | 33 | 30 | 71,367 | 52.474 ms |

Allocator live readings were 204,050,712 / 202,232,568 bytes; process peak 297,487,005 bytes. These include the preloaded project test runner and original fixture machinery, not isolated command-evidence allocation, renderer RSS or WASM capacity. No percentile, production save, browser latency or memory-optimization claim is made. This task has no storage publication.

## 7. Remaining limitations and next-pass conditions

- No new credit or NEW RUN transaction integration. Existing v1 credited compatibility still passes; it is not evidence that the new source extractor supports those transitions.
- No unknown historical command-prefix conversion. Neutral old equip/unequip pairs cannot be recovered from the final loadout.
- Exact offline hashes/checksums are not proof against a locally fabricated, internally consistent narrative. Only genuine original API capture plus immutable admitted-prefix comparison may authorize new effects.
- Positive active draw/use and interruption are tested. The validator has explicit failure-event handling, but positive completion-failure fixtures were not executed. Legal hold-one/regrip planning reuses the original rule helper; new v2 positive two-hand fixtures were not claimed. The original shared-handling suite passes.
- This command-only replay does not invent independent equipment wear/destruction events. If reconstructed terminal condition/quantity differs from the supplied terminal ownership for effects outside the retained command facts, it fails closed (`command_terminal_ownership`). Broader independent condition/loss integration must be characterized in the later owned producer, not silently inferred from a smaller balance or SHP value here.
- Real owner histories, Edge/WASM, storage/CAS, backups, exact durable acknowledgements and production activation are untested and untouched.
- The full #46C2 acceptance matrix, including its new credits/NEW RUN/large-history cases and storage decision, remains unfinished. This report does not supersede its NO-GO for Windows integration.

## 8. Preservation

Actual checkout: `C:/Users/mxz/Desktop/Projects/ITank Prime/Video Game/ITank Arena/i-tank-prime-arena`.

Branch remains `main`, HEAD `f9bb0db0235b0003895c477a12346191d4714469`, index empty. Entry: 35 modified tracked / 166 collapsed untracked entries. Final with this document: 35 modified tracked / 175 collapsed untracked entries. No prior status entry disappeared.

Of 746 baseline scoped project files, 745 remain byte-identical. Only `tests/test_runner.gd` changed; removing exactly its two new lines in a comparison buffer reconstructs the entry bytes exactly, including line endings. No actual restore/revert was performed. Earlier #45B–#46C2 source, reports, tests and paused #45U work are preserved.

`project.godot` retains its pre-existing modification and SHA-256 `8398f110f77d7712eb19c283eb9f745c7123feab9557187778da412639ba5692`. Protected boss files, `character saves/`, repository `tmp/`, owner backups and production browser data were not opened or modified. Git lists protected names only; their contents were not inspected or hashed. Disposable artifacts remain in OS cache/TEMP. No staging, commit, push, reset, stash, cleanup, production import/export or full regression.

Final checks: `git diff --check` passed. Its CRLF-to-LF advisories concern the existing service/runner working copies; no line-ending conversion was made. Direct checks of all nine new UTF-8 files found no whitespace errors or missing final newline. Each of the four new UID values occurs exactly once. All seven previously recorded paused #45U TEMP evidence files remain byte-identical.

Exact final `git status --short`:

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
?? scripts/rewards/minimal_character_transactions.gd
?? scripts/rewards/minimal_character_transactions.gd.uid
?? scripts/rewards/snapshot_command_evidence.gd
?? scripts/rewards/snapshot_command_evidence.gd.uid
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
?? tests/test_minimal_character_transactions.gd
?? tests/test_minimal_character_transactions.gd.uid
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
?? tmp/
```

## 9. Recommendation

**GO for resuming #46C2 using explicit v2 and supported complete-prefix fixtures, after owner review.** Carry the exact immutable command facts and IDs through its existing owned transaction boundary. Keep unavailable old prefixes read-only/unsupported, preserve its source authority and complete its remaining tests. This is not permission to start that work now, integrate storage or activate playable saves.
