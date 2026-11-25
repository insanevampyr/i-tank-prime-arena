# Task 46C — Coordinator-owned routine saves: ownership audit stop

18 November 2026. **Status: BLOCKED at the mandatory pre-implementation ownership gate.** No routine aggregate, transaction adapter, pending lifecycle or storage code was implemented. Task 45U remains paused.

The owner explicitly required: “STOP and report if an untracked mutation path makes this ownership model unsafe.” The approved 46A design likewise requires every relevant mutation to pass through the owner/gate before replacing source/runtime checks with an internal revision. Current seams do not establish that invariant. This is an integration prerequisite, not a claim that current production persistence has lost or corrupted data.

## 1. Exact changed-file manifest

Added only:

- `docs/architecture/TASK_46C_COORDINATOR_OWNED_ROUTINE_SAVES.md` (this report).

No source, tests, UID files, runner registrations, configuration, previous report or generated artifact was changed.

## 2. Baseline and inspection

Actual repository: `C:/Users/mxz/Desktop/Projects/ITank Prime/Video Game/ITank Arena/i-tank-prime-arena`.

Entry: `main`, HEAD `f9bb0db0235b0003895c477a12346191d4714469`, empty index, 29 modified tracked paths / 155 collapsed untracked entries. Read 46A/46B architecture and inspected the current coordinator, playable persistence, reward/purchase/growth, fixed-credit, item ownership, checkpoint, simulation/session, external player movement and existing X invalidation paths. No repository AGENTS file was found by the scoped search.

A read-only preservation inventory captured 735 pre-existing nonprotected project files plus seven paused-U diagnostic files before any edit. Protected paths were excluded from content inspection/hashing; Git status lists their names only.

## 3. Confirmed ownership blocker

### External Running state can change without a coordinator/session revision

Verified call path:

1. `scripts/player/placeholder_player.gd:79` — the player node has its own `_physics_process()`.
2. Lines 102–117 — movement locking sets direction to zero and releases Running, but still calls `_movement.advance(delta_us, direction)`. Blocking movement input is **not** a freeze of persistent Running state.
3. `scripts/movement/prime_movement_model.gd:263` — advancement updates Running elapsed time, fatigue/recovery, maintenance checks and its own RNG. Lines 381–387 reduce retry cooldown and recovery debt even with zero requested direction.
4. `scripts/movement/prime_movement_model.gd:64` — `wave_entry_state()` serializes that dynamic state and its separate RNG. It is required checkpoint data.
5. `scripts/player/placeholder_player.gd:178` — `capture_wave_entry_motion()` exposes a value snapshot, not an exclusive ownership/freeze/revision protocol.
6. `scripts/ui/arena_combat_controller.gd:1209` binds this external provider to the session. Lines 1210–1211 also bind external SPD/END profile refresh callbacks.
7. `scripts/combat/arena_combat_session.gd:2230` — `get_state_snapshot()` includes session and opponent motion, but does not include the external player's Running model.
8. `scripts/rewards/playable_character_persistence.gd:627` — `_capture()` explicitly samples that provider to include it in the legal checkpoint. Sampling its value does not subscribe to later changes or prevent them.

Neither movement advancement nor the external profile refresh functions update a coordinator-owned local revision or emit a simulation event for every Running-state change. A counter updated only by rewards/purchases or simulation events would therefore miss a required persisted mutation.

This is supported independently by existing dormant code: `compact_v6_incremental_snapshot.gd:120–121,160–163` separately captures and rechecks the provider and rejects `movement_changed_after_capture`. The existing test at `tests/test_compact_v6_incremental_snapshot.gd:197–218` mutates the actual disposable movement model during pending work and requires invalidation. Those tests were inspected, not rerun here. They are evidence of an already recognized external-state boundary, not permission to reuse the prohibited X proof cascade.

### Existing pause/guards do not supply a general owned boundary

- `arena_combat_controller.gd:246–255,2586–2595` freezes the player's physics processing for existing browser transitions. This is a concrete UI/browser path, not a coordinator-owned guard available to the new dormant aggregate.
- `arena_combat_session.gd:1843–1844` suppresses advancement specifically for `PlayableBrowserPersistence.pending_or_unsecured()`. It does not consult an arbitrary new aggregate's pending state.
- `playable_character_persistence.gd:383–386` guards its existing `_prepared` request. It is not a universal revision source or a lock over external motion.
- `arena_combat_session.gd:2016–2019` forwards NAC configuration without calling that mutation guard. The simulator correctly emits `nac_automation_configured` and increments its own revisions at `combat_simulation.gd:6144–6168`; it is **not an eventless mutation**, but it does not update a new coordinator revision or honor its pending transaction. UI currently has its own browser guard at `arena_combat_controller.gd:738–751`.
- `arena_combat_session.gd:2203–2204` and `combat_simulation.gd:3217–3222` return actual mutable actor/definition objects. This alone does not establish a real gameplay defect: 46A trusts internal gameplay code. It does mean a new aggregate cannot claim exclusive runtime ownership simply by copying its admitted snapshot and counting its own API calls.

A private copy protects the aggregate from aliases but does not by itself observe original gameplay. Ignoring the external state would lose required fatigue/timer/RNG changes; accepting arbitrary final replacements would fail the genuine-transaction requirement. Keeping X's full runtime/provider fingerprints or inventing a generic proof framework would evade the approved simplification rather than establish the missing ownership invariant.

**Stop decision:** do not introduce a revision-only aggregate or claim safe cancellation, exact retry and immutable pending checkpoint behavior until the shared mutation/capture gate is established. No demonstrated production corruption, reward duplication or owner-data loss is asserted.

## 4. Mutation-family map inspected before stopping

This is the concrete inventory reached during the ownership audit, not a certification that all remaining engine writes have been exhaustively gated.

| Family | Existing authoritative path | Relevant capture/validation | Disposition |
| --- | --- | --- | --- |
| Defeat XP, loot and level gains | Session `_process_reward_events()` → ledger `process_defeat()` → `CharacterLevelProgression.apply_award()` | Original defeat/award causal IDs, original dice/HPB/WIS; service `ingest()/checkpoint()`; source XP validation | Reuse rule paths; no authority from final balances. Existing events are available, but no new owned revision/batch was connected. |
| STR/DEX/SPD/WIS/END purchases | Session `request_character_advancement()` → ledger `purchase_advancement()` → simulator `apply_verified_character_advancement()` | Existing cost/preview/eligibility/request rules, `reward_advancement_purchased`; ordered growth in checkpoint | Reuse. SPD/END also refresh external movement via callbacks; their complete mutation must be in the same ownership gate. |
| Development/allocation | Session `request_character_development()` → simulator `request_character_development()` | `character_development_committed`, existing source checks and checkpoint development record | Must be included; not merely the five permanent attribute purchase APIs. |
| Item/currency acquisition | Session collection methods → simulator `collect_ground_loot_item()` | `ground_loot_collected`, exact world/instance provenance and acquisition receipts | Source-backed seam exists. No new identity/binding rules introduced. |
| Consumption | Simulator downtime and action-completion consumable paths | `downtime_consumable_used`, `consumable_healing_resolved`, `consumable_mana_resolved`, original ownership selections | Preserve terminal zero-quantity ownership, not only positive inventory. Missing evidence remains unsupported as in 46B. |
| Equipment, weapon handling, shield condition | Session equipment/handling; simulator `apply_downtime_equipment_transaction()`; defense events | Service `ingest()/ _sync_items()`, hands/handling/condition, exact selected instances | Existing instance checks must be retained. No inferred item creation. |
| Combat resources, conditions, shields, positions, timing, Mana remainder | Simulation actions/damage/specials/clock; session `advance_by()` | Existing schema-12 safe checkpoint fields and `CharacterWaveCheckpoint.validate()` | Checkpoint capture must happen under a stable shared gate. No arbitrary active-wave resume added. |
| NAC settings and DEV Refresh | Session configuration / `request_developer_character_refresh()` | Simulator events, original DEV/downtime/alive restrictions; checkpoint | NAC lacks the generic persistence guard at the session entry. Do not alter Refresh permissions. |
| External Running/fatigue/cooldown/RNG | Player physics → `PrimeMovementModel`; external SPD/END refresh/restore | Provider capture, movement checkpoint validator | **Confirmed untracked-by-proposed-revision path; blocker.** |
| Resume, NEXT WAVE, NEW RUN, return/retry | Existing admission/run-policy and session transition/checkpoint paths | Original run IDs, immutable multiplier history, authorized entry, roster/seed/checkpoint | Must retain namespace/policy and exact IDs. No new transitions or simulation changes made. |
| Fixed historical/native EXPC credit | `character_expc_credit.gd:inspect()/continuity()/prepare()` | Exact fixed target/baseline/grant/amount, consent bound to current generation/digest; existing coordinator publication | Reuse existing consent/eligibility; never add a balance-only grant or new authorization. 46B's flat evidence is a cold record, not live consent. |

The old coordinator still prepares/copies/serializes a complete externally provided legacy proposal and invokes `_authorize()` and hydration (`character_persistence_coordinator.gd:148–224`). Its checks cannot simply be removed while the runtime remains shared and mutable. No second coordinator/wallet or alternate reward authority was created.

## 5. Minimum prerequisite recommendation

**Recommendation only; not implemented or separately authorized by this stop report.**

1. Define one opt-in mutation/capture gate controlled by the existing coordinator/service for the dormant path. Admission and legal checkpoint entry must explicitly bind the runtime plus the external movement provider. Keep current playable callers unchanged.
2. Establish the complete command/tick boundary: all persistent management commands and external Running advancement/profile refresh/restoration must either participate in that gate or be demonstrably frozen for the full capture/pending interval. Input locking alone is insufficient. Preserve original timing and no arbitrary simulation freezes during normal gameplay.
3. Give that owner a private local revision incremented by every accepted relevant mutation, with no caller-provided revision/trust flag. Close mutable-reference escape at the dormant façade. Do not replace the original combat actors/ledger with a second character or wallet.
4. Prove gate coverage first with narrow deterministic tests: zero-direction fatigue/cooldown advancement, external Running RNG, SPD/END callback refresh, NAC setting changes, resource ticks and source/profile change during pending capture; cancellation/unlock and legitimate continuation must preserve exact state.
5. Resume the requested routine aggregate only after those tests establish ownership. Then reuse original transaction paths to append facts, one exact-ID registry and one pending canonical 46B record. Full cold admission remains mandatory. A simulated acknowledgement must stay explicitly nondurable; actual readback/storage remains a later pass.

If the owner prefers leaving current mutation seams untouched, retaining exact capture/recheck of genuinely mutable external checkpoint state is an alternative to discuss. It must not be silently described as revision-only ownership, and this report does not implement or authorize that alternative.

## 6. Transaction, equivalence and performance status

| Requested 46C deliverable | Result |
| --- | --- |
| Ownership audit | Blocker confirmed above; stopped as instructed. |
| Coordinator-owned aggregate/private IDs/journal/revision | Not implemented. |
| Genuine routine transaction append and canonical snapshot preparation | Not implemented. |
| Pending exact retry/conflict/cancel/unknown-ack lifecycle | Not implemented; no durable acknowledgement issued. |
| New ID/evidence preservation and independent canonical comparisons | Not run; no new candidate exists. Prior 46B results are not claimed as 46C tests. |
| Cold restart tests, historical233 and inventory1005 workloads | Not rerun. Existing 46B evidence remains intact. |
| Native preparation timings / memory | Not measured. There is no 46C implementation to benchmark; no routine-save latency or memory improvement claimed. |
| Windows/Edge publication | Excluded and still pending; ownership, CAS, atomic publication, exact readback and reader fencing require later approval. |

No Godot suite, import/startup, browser test, full regression or export was run. Source inspection establishes the blocker; no new tests or production fixes were introduced to work around it. Git whitespace and preservation checks follow.

## 7. Preservation and exact Git status

Final comparison: all **735 pre-existing scoped files** and all **seven paused-U diagnostics** retain their entry hashes. No file is missing and no entry status line disappeared. The only addition is this report. Branch/HEAD remain `main` / `f9bb0db0235b0003895c477a12346191d4714469`; index remains empty. Final status is **29 modified tracked paths / 156 collapsed untracked entries**. Exact final status is the complete entry listing below plus this one added line:

```text
?? docs/architecture/TASK_46C_COORDINATOR_OWNED_ROUTINE_SAVES.md
```

`project.godot` retains SHA-256 `8398f110f77d7712eb19c283eb9f745c7123feab9557187778da412639ba5692`. `git diff --check` exits 0; the existing CRLF-to-LF advisories for `playable_character_persistence.gd` and `tests/test_runner.gd` do not indicate a whitespace failure or a file mutation. Direct report trailing-whitespace check passes.

No protected owner data, source boss document, character-save directory, repository tmp, backup, browser IndexedDB, Roadmap or Combat Specification was opened. Protected-file confirmation means no access or writes, not a content comparison of those excluded paths. No Git mutation was performed.

Entry status (names only; all earlier work preserved):

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

