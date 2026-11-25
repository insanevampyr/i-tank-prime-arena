# Task #46C2 — Coordinator-owned routine transactions

Date: 2026-11-19. Status: **PARTIAL / BLOCKED. NO-GO for disposable Windows storage integration.**

This is a dormant, cache-isolated subset, not completed #46C support or a production save system. Basic original NORMAL/legacy DEV XP, loot and consecutive checkpoint preparation are verified against the original writer. The required exact equipment/consumption command-ID contract cannot currently be represented by the unchanged #46B v1 format. This pass stops at that demonstrated format blocker; it does not reinterpret v1 or introduce another format. New native credits, NEW RUN preparation and the full large-history/all-five-advancement matrix remain unfinished.

## 1. Exact task file manifest

Modified existing working-tree files (including earlier uncommitted work):

1. `scripts/rewards/character_persistence_coordinator.gd` — dormant aggregate ownership and explicitly simulated APIs only; existing prepare/commit/reconcile unchanged.
2. `scripts/rewards/playable_character_persistence.gd` — null-by-default weak owner, original fact-loop extraction, checkpoint dispatch and prototype-only pending/unsupported-command guards.
3. `scripts/rewards/character_capture_gate.gd` — one source-service checkpoint acquisition seam; existing #46C-1 semantics retained.
4. `scripts/combat/arena_combat_session.gd` — exactly three guard calls identify equipment or consumption before the existing source command mutates state.
5. `tests/test_runner.gd` — one preload and one new registration; existing registrations preserved.

Added:

6. `scripts/rewards/minimal_character_transactions.gd`
7. `scripts/rewards/minimal_character_transactions.gd.uid`
8. `tests/test_minimal_character_transactions.gd`
9. `tests/test_minimal_character_transactions.gd.uid`
10. `docs/architecture/TASK_46C2_COORDINATOR_OWNED_ROUTINE_TRANSACTIONS.md`

No #46B, V6 or legacy format/validator changes. No W/X/Y code changes, production routing, player controls, browser/database changes, Roadmap/Combat Specification changes or project configuration changes.

## 2. Authority and ownership

The existing `CharacterPersistenceCoordinator` owns a single private `minimal_character_transactions` helper. This helper is not a second reward wallet or coordinator: all original gameplay occurs in the existing session, simulation, reward ledger and playable service. Admission requires an explicit disposable cache-root prefix, main thread, exact profile/namespace and successful full #46B `decode()` against the trusted character source. No playable factory or controller calls this entry point.

The helper privately owns the immutable admitted `Codec.Record`, trusted source copy, existing service/session/player, #46C-1 gate, exact scoped ID/binding lookup, event cursor, internal revision and at most one immutable pending record. Public methods return immutable strings or copied dictionaries. Tests inspect private runtime objects solely to invoke and compare the original engine; this is guarded gameplay-API ownership, not protection against arbitrary private-field reflection or malicious native code.

Admission reuses original source-baseline allowlisting, flat character hydration, derived END witness, item/receipt checks, runtime Balance provenance, wave initialization and checkpoint restoration. `_open_existing_verified()` also performs original flat legacy prepare/encode checks on admission. There is no generation archive read or reconstruction. The service's `_prior` is an original-rule read view derived from the owned flat snapshot, not a second authoritative wallet. Hydration is not invoked again during routine preparation.

| Source boundary | Actual authority retained | This pass |
| --- | --- | --- |
| XP and levels | Original eligible-defeat event, causal XP event, ledger, original proof maps and receipt rules | Exercised NORMAL ×1 and legacy DEV ×10, exact original control |
| Permanent purchases | Original management boundary, request/affordability/rules, ledger and source purchase proof | Original normalization reused; new aggregate's five-attribute matrix not executed |
| END/HPB/WIS growth | Original event payload and source chronology; unchanged full codec | Cold validator retained; interleaved live aggregate matrix unfinished |
| Loot/currency | Original collection, original item-origin and settlement proof, current ownership | Original real wave collection and complete projection compared |
| Equipment/consumption | Original command guards and original request events | Explicitly unavailable before effects in this prototype; see blocker |
| Resource/RNG/movement | Original session plus external player/model captured through gate | Checkpoint and external Running invalidation exercised |
| NAC | Original configuration command, tracked gate revision | Repeated genuine configuration/checkpoint coverage |
| Fixed credits | Existing source-specific contract only | Existing credited cold-codec cases rerun; new grant transaction not implemented |
| RESUME/NEXT WAVE | Original restore and authorized entry boundaries | Original cold resume and consecutive NEXT WAVE compared |
| NEW RUN | Original identity/policy authority must remain intact | Changed run history/policy rejected; new-run aggregate preparation not implemented |

Default old behavior remains selected when the new weak marker is null. In a prototype, the marker also prohibits legacy `publish_prepared()` fallback. No production storage write is performed by the new helper.

## 3. Actual checkpoint ordering

The #46C-1 `checkpoint_boundary()` capture is deliberately early. Original service ingestion/receipt normalization and NEXT WAVE initialization can make that capture stale. It cannot be reused at command return as a newer Wave-entry checkpoint.

The new seam runs synchronously inside the original `PlayableCharacterPersistence.checkpoint()` after its existing phase, ingestion, action-idle and immutable reward-policy checks. The three original award/purchase/growth loops were extracted verbatim into `_collect_progression_facts()` so both routes use the same proof and normalized receipt rules.

Then:

1. `Gate.acquire_service_checkpoint()` verifies the exact bound service/session/participants, active original mutation scope and legal entry/downtime/completion boundary. Entry still requires the session's actual `_authorized_entry_write`.
2. The original `_capture()` builds and validates the checkpoint, including the external movement provider.
3. Original events since the owned cursor are copied in causal order; the same gate collects immutable session/ledger/player movement state.
4. The gate releases immediately after capture. It is not held during construction, encoding or simulated acknowledgement.
5. Only original normalized awards/purchases/growth, append-only settlements and actual current checkpoint state are used. Award causes must precede awards and be original reward-eligible defeats. Growth must follow its original award. Expected XP is independently derived from the previous snapshot plus genuine new facts, then compared with the ledger.
6. Earlier evidence bindings are checked; original canonical grouping is retained. Full #46B encoding/cold validation seals the immutable candidate. No W/X/Y proof chain, full legacy generation encode or routine profile hydration is used.

The new checkpoint's JSON numeric representation is normalized through the existing contract helper, including negative sentinels; this is not rewriting lifetime evidence. Actual candidate envelope decode and a fresh child process are tested, not just in-process dictionary equality.

There is no per-frame serialization. The source call remains synchronous, so encoding CPU still runs on the main thread. These small native measurements do not prove browser responsiveness or large-character latency.

## 4. Pending and acknowledgement semantics

- Preparation takes an owned operation ID and internal revision, never a caller candidate or verification flag.
- Identical source facts/checkpoint return identical pending bytes. A changed binding cannot replace them. At most one pending exists.
- Relevant later mutations invalidate the current-runtime capture claim; a local revision is not storage ownership or CAS.
- Simulated publication uncertainty may be entered only while the original capture is fresh. Later exact readback can reconcile that already-authorized earlier immutable checkpoint, without recapturing later state or replaying effects.
- A stale capture without a previously fresh simulated attempt is rejected. Cancellation after uncertainty is rejected until reconciliation. Ordinary cancellation adopts nothing and terminally invalidates the context; busy gate release fails closed.
- An identical repeated simulated acknowledgement is idempotent. A changed readback/revision is rejected. No reward, loot, resource cost or purchase is reexecuted by acknowledgement.
- Every new-path status says `durable:false`, `persistent:false` / “Simulation only — not saved.” The optional automatic acknowledgement switch is explicitly test-only and default OFF; it acknowledges only in-memory exact bytes. It is not an OS or browser readback.
- Current-head, profile, source, namespace, rules-derived record, run-policy and participant ownership remain bound. Cross-process storage freshness, crash recovery and actual durable acknowledgement do not exist in this pass.

## 5. Confirmed v1 exact-command blocker

Source locations:

- `minimal_character_snapshot.gd::_check()` binds operation count to sequence/current generation and enforces exact operation fields (`id`, `request_digest`, optional original legacy binding kind).
- `compact_character_v6_prototype.gd::_ids()` derives lifetime scopes from operations, awards, purchases, growth, settlements, item origins, fixed credits, development and runs.
- `character_settlement_receipt.gd::validate()` accepts only XP, purchase, item and currency content shapes.
- The original reward/checkpoint ledger does not retain the full individual equipment/consumption accepted-request map. Original runtime events do contain those request/ownership facts.

**Dynamic reproduction:** a real original wave, original loot collection and original `request_player_inventory_unequip()` successfully commit in the original control. The genuine equipment event contains its exact original request ID and ownership binding. Conversion to v1 verifies the resulting terminal equipment state, but its lifetime registry contains no such request ID. Adding a purported `equipment` lifetime scope is correctly rejected by the unchanged v1 cold validator.

Thus a commit digest or acquired item origin is not exact lifetime membership for each command. Multiple legitimate uses can occur before one legal checkpoint. A 20-entry journal cannot supply permanent membership. Terminal quantity zero prevents resurrecting a consumed origin but does not independently establish the original opaque command ID after restart.

The prototype therefore rejects equipment and consumable commands with `minimal_v1_command_identity_evidence_unavailable` **before their actual effects**. An event-stage fail-closed guard also rejects unsupported events if those early guards were bypassed. No success expectation was changed to pretend the command is supported.

Consumption has the analogous source-format gap. An attempted dynamic consumption fixture legitimately lacked the requested potion (`consumable_unavailable`); that newly attempted invalid fixture case was removed rather than manufacturing provenance. Consequently dynamic actual-consumption equivalence is **not verified** here. Equipment is the real generated-event reproduction.

**Owner decision required:** approve an explicit compatible revision of the minimum snapshot contract with essential original equipment/consumption command facts, derived full scoped IDs/bindings and a clear unsupported/unknown legacy-prefix policy, or explicitly approve a narrower identity guarantee. Keep one checkpoint commit per generation. Do not overload commit sequence, use a batch hash as membership, invent old command facts or silently reinterpret v1. No such revision is implemented in this task.

## 6. Focused verification

Commands executed from the actual Arena project, with Godot 4.7.2 Windows console binary:

```powershell
$godot = 'C:/Users/mxz/Desktop/GoDot/Godot_v4.7.2-stable_win64_console.exe'
$arena = 'C:/Users/mxz/Desktop/Projects/ITank Prime/Video Game/ITank Arena/i-tank-prime-arena'
& $godot --headless --path $arena --script res://tests/test_runner.gd -- '--suite=46C2 routine transactions'
& $godot --headless --path $arena --script res://tests/test_runner.gd -- '--suite=46C1 shared capture gate'
& $godot --headless --path $arena --script res://tests/test_runner.gd -- '--suite=46B minimal snapshot'
& $godot --headless --path $arena --script res://tests/test_runner.gd -- '--suite=Task 36J-Pass2 persistence coordinator'
& $godot --headless --path $arena --script res://tests/test_runner.gd -- '--suite=Task 36J-Pass5 playable Vaelis persistence'
git diff --check
```

| Final relevant suite | Result | Evidence in `%TEMP%` |
| --- | --- | --- |
| 46C2 routine transactions | 95 assertions, zero failures | `arena46c2-final.log` |
| 46C1 shared capture gate | 310 assertions, zero failures | `arena46c2-gate-final.log` |
| 46B minimal snapshot | 227 assertions, zero failures | `arena46c2-46b.log` |
| Existing persistence coordinator | PASS; suite does not print assertion count | `arena46c2-old-coordinator.log` |
| Existing playable Vaelis persistence | PASS; suite does not print assertion count | `arena46c2-legacy-final.log` |

Five focused suites passed; 632 explicitly counted assertions plus the two older suites' unreported counts. Final logs contain no script errors or resource-leak messages. Headless runner success means selected suites only, not full regression. Direct helper/test script parsing also passed. `git diff --check` passed; existing CRLF-to-LF advisories for the service/runner are not whitespace failures.

New tests cover genuine NORMAL/DEV commands, complete original simulation/event/RNG equality, complete original flat projection/evidence equality including generation, original cold-resume control, actual candidate envelope decode, two fresh-process full admissions, immutable public views, one aggregate, exact/conflicting retries, stale revision, changed readback, uncertain-readback reconciliation after external Running change, cancellation, idempotence, 23 genuine later NAC checkpoints, journal eviction retaining lifetime IDs, and the confirmed equipment blocker. Original controls and the old codecs are unmodified.

Earlier development attempts failed for an optional missing zero-credit field, dynamic type inference and inconsistent numeric representation; these were corrected before the final passing runs. The invalid potion-fixture attempt is separately limited above. These are not historical production defects. The new format limitation remains a blocker despite the passing characterization suite.

**Not executed/completed for this aggregate:** five live attribute purchases, interleaved live END/WIS growth, original 233-generation and 1,005-item stress, new fixed-credit publication, native-credit replay, NEW RUN policy transition, dynamic consumption/zero-quantity terminal equivalence, storage, Edge or browser restart. The existing 46B credited cases passing does not establish new credit transaction support. This is not the complete requested acceptance matrix.

## 7. Native performance and residual costs

Final single native debug observations at the genuine Wave 2 entry (other focused tests were also running). No percentiles or matched W/X/Y speedup claims:

| Observation | NORMAL | Legacy DEV |
| --- | ---: | ---: |
| Encoded candidate bytes | 26,905 | 23,718 |
| Original source ingestion/receipt work | 1.463 ms | 1.454 ms |
| Source authorization/capture interval | 8.498 ms | 8.024 ms |
| Construction/ID interval | 0.342 ms | 0.311 ms |
| Full codec validation + encoding | 5.903 ms | 5.543 ms |
| Total source checkpoint preparation | 14.743 ms | 13.878 ms |
| Independent full dictionary validation sample | 5.766 ms | 5.606 ms |
| Admission `Codec.decode()` only | 7.834 ms | 7.271 ms |
| Process native allocator live bytes | 190,909,364 | 190,512,773 |
| Process native allocator peak bytes | 295,764,659 | 295,764,659 |

Ingestion is included in the authorization/capture interval; do not add it twice. Admission decode is not total runtime startup. Memory includes the preloaded complete test runner and fixtures, not isolated aggregate allocation, renderer RSS or WASM capacity. There is no browser memory, leak, p50/p95, load/publication or large-record performance claim.

Residual costs are explicit: full current/evidence copies; rebuilding canonical lifetime bindings through `_ids()`; full #46B semantic validation, chronology, receipt/item checks and original hydration inside the codec; canonical JSON/hash work. The private exact lookup protects append bindings but does not eliminate these full cold scans. No cold validation/readback was optimized away. No routine legacy history archives, W/X/Y seals or reversible ancestry are constructed.

## 8. Decision and stop conditions

**NO-GO for disposable Windows integration.** Required original equipment/consumption exact-ID evidence is missing from the approved unchanged v1 contract. Do not connect this partial route to a writer or claim native credits/NEW RUN support. Resolve the explicit format/legacy-evidence decision first, then finish the independently observed source-transaction matrix and only afterward reconsider storage.

Other unfinished obligations include source-authorized native credit integration, NEW RUN identity/policy preparation, complete five-attribute and mixed-growth evidence, large conversion/stress coverage and durable ownership/readback/recovery. These are not permission to broaden this pass. #45U stays paused. No next pass begins automatically.

## 9. Workspace and protected-data preservation

Branch `main`; HEAD remains `f9bb0db0235b0003895c477a12346191d4714469`; index empty. Entry status: 35 modified tracked / 161 collapsed untracked entries. Final status with this report: 35 modified tracked / 166 collapsed untracked entries. No entry status removed; five new files are this task's helper/test pairs and report.

Baseline covered 741 nonprotected scoped project files. Exactly the five existing files in this manifest changed; 736 remain byte-identical and none are missing. For all five touched files, removing only task additions and inlining the extracted exact original receipt loops in a comparison buffer reconstructs the entry bytes exactly, including original line endings. This is a read-only comparison, not restoration. All seven recorded paused #45U diagnostic/benchmark files are unchanged.

`project.godot` remains SHA-256 `8398f110f77d7712eb19c283eb9f745c7123feab9557187778da412639ba5692` and retains its prior modification. Earlier untracked source/tests/docs remain intact. Existing formats, source documents, owner saves/backups, repository `tmp/`, `character saves/`, protected boss contents and owner browser storage were not opened or modified. Protected paths are listed by Git names only; their contents were deliberately not hashed or inspected. Test artifacts use disposable OS cache/TEMP roots only. No staging, commit, push, reset, stash, cleanup, full regression or Web export.

Exact final `git status --short` follows.

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
?? scripts/rewards/minimal_character_transactions.gd
?? scripts/rewards/minimal_character_transactions.gd.uid
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
?? tests/test_minimal_character_transactions.gd
?? tests/test_minimal_character_transactions.gd.uid
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
