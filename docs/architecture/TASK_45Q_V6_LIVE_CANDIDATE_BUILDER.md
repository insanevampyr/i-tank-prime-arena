# Task 45Q - Dormant V6 gameplay candidate builder, Stage S2

2026-11-17. **S2 implemented, dormant only.** This is not V6 production activation, storage integration, migration or a new credit implementation. Final focused validation and measurements are recorded below. Read 45O, 45P, 45J, 45K and 45L and inspected the actual ingestion, projection, progression, ledger, coordinator, codec and disposable test code before editing.

Baseline: primary Arena source checkout on `main`, HEAD `f9bb0db0235b0003895c477a12346191d4714469`, including all preserved uncommitted 45B-45P changes. The older export worktree was not edited.

## 1. Exact file manifest

Added:

- `scripts/rewards/compact_v6_gameplay_candidate.gd`
- `scripts/rewards/compact_v6_gameplay_candidate.gd.uid`
- `tests/test_compact_v6_gameplay_candidate.gd`
- `tests/test_compact_v6_gameplay_candidate.gd.uid`
- `docs/architecture/TASK_45Q_V6_LIVE_CANDIDATE_BUILDER.md` (this report)

Modified from the starting snapshot:

- `scripts/rewards/compact_character_v6_prototype.gd`: preserve an existing verified credit predecessor when its runtime-ledger prefix is no longer present after resume. Exact-ID optimization unchanged.
- `tests/test_runner.gd`: one new suite preload and registration. Existing registrations remain intact.

Seven intended files. No playable service/session, coordinator, progression, reward, combat, movement, UI, storage adapter, backup dispatch, database, export settings or project.godot edits. Temporary logs/probes and synthetic character histories are outside the repository.

## 2. Adapter architecture and boundary

`compact_v6_gameplay_candidate.gd` is an explicitly constructed in-memory observer. It takes the **actual trusted PlayableCharacterPersistence instance** and an independently validated compact parent, or an empty parent for a genuinely new character. It does not accept an imported declaration of authority, generic wallet delta or caller-provided verification flag.

The only subscriber is the test's `Observed` subclass:

1. At the existing `ingest(session)` boundary it calls the unchanged service first, then `observe(session)`. The adapter copies CombatEvent.to_dictionary() from the actual resolved-event cursor in its original array order. It neither sorts IDs/stable_sequence nor emits replacement events.
2. At the existing `publish_prepared()` seam, **before the unchanged legacy coordinator publishes**, it calls `prepare(expected_head)`. The input comes from the service's existing authorized `_prepared` proposal; no alternate projection builder or competing coordinator is installed.
3. `check(prepared, expected_head)` rechecks the owned sealed handle, source/profile/run context, original request, captured events, runtime snapshot and current coordinator authority. Full cold V6 decode/validation and extension validation remain.
4. Only after the original coordinator's verified legacy acknowledgement does `adopt(prepared)` advance the observer's in-memory parent. It requires the service's exact acknowledged payload/generation. It publishes or acknowledges **no V6 storage**. A conflicting/stale legacy publication leaves the compact parent unchanged.
5. Exact retry returns the same sealed handle and rechecks it. Cancellation is terminal for the observer, releases pending facts/output and cannot refund, undo or alter an existing legacy transaction.

The production classes have no new hook or call to this adapter. Tests subclass existing seams solely to exercise the real pipeline; playable code still creates the original service and writes its existing envelopes. This makes the builder testable before separately approving any routing/preparation split in later integration stages.

Existing characters need a verified compact parent supplied explicitly after Pass B conversion. Missing/mismatched parents fail closed; this API does not locate or migrate a profile. A resumed run with no new checkpoint creates no new compact operation.

## 3. Prepared operation and immutability

Each Prepared object owns a one-time-assigned JSON string and its SHA-256. Its getters return owned strings or newly parsed copies; later assignment to the stored strings is ignored. A forged Prepared instance, even with self-consistent hashes or copied data, is not the observer's privately owned pending handle.

The sealed body includes:

- Profile ID, NORMAL/DEV namespace, applicable rules and exact trusted saved-source digest.
- Expected parent format/epoch/sequence/digest; the logical digest is SHA-256 of the canonical **inner V6 record**, matching existing V6.validate_extension. A new baseline uses format 0/sequence 0/null parent.
- Original coordinator operation/request ID and digest of its complete original prepared request (including its exact legacy document bytes).
- Exact serialized ordered event facts, original event IDs, causal parents/dependencies, source/affected actors, original purchase request IDs, resources and draw provenance.
- Original event-cursor interval, whole current projection digest, locked run policy and whole authoritative session-snapshot digest.
- Exact canonical V6 candidate text and explicit SHA-256 of those text bytes. The whole body has a separate seal digest.

New operation rows retain the actual coordinator transaction ID and the digest of this binding. Existing legacy-document bindings and every lifetime scoped ID are retained. Command IDs/provenance are copied, not fabricated from balance differences. Metrics and wall-clock timings are **not** part of any authoritative binding or candidate.

Digest domains are deliberately distinct: the logical parent record digest is not the 45M filesystem/IndexedDB blob-head digest of an outer encoded envelope. Later storage integration must bind/check the actual stored head and outer bytes as well; this dormant model does not claim to have performed that CAS/readback for V6. The existing legacy coordinator remains the only publication authority in these tests.

This is a trusted engine-code boundary, not authentication against arbitrary hostile scripts in the engine process. No networking/PvP authority or unrestricted credit API is introduced.

## 4. Chronology, authorization and current state

`prepare()` calls existing CharacterPersistenceCoordinator._authorize with the service's own `_verify`, which requires a proposal admitted by the existing synchronous projection/checkpoint window. It reuses source-backed prices/caps, progression/hydration, full receipts and ownership validation. Checksums and V6 semantic consistency do not substitute for gameplay authorization.

New award/purchase/growth rows are selected by immutable prefix comparison. **Their combined chronology comes only from the captured event sequence**, not the order of independent maps or final totals:

- XP event IDs map through the service's already-proven award bindings to original persisted award IDs. The original preceding defeat is required and checked through the session's existing `_is_reward_eligible_defeat()` policy, including source-specific collision defeat behavior.
- Purchases retain request IDs, all existing purchase fields, source prices and DEX allocation. The adapter neither recalculates cost nor changes eligibility.
- Growth retains the original HD sides, rolls, HPB, event-time WIS, HPM/resource arithmetic and original growth IDs. Its actual preceding XP event is required. No growth reroll or final-WIS/final-HPB reconstruction.
- Every new semantic row must have a matching ordered fact exactly once. Missing, reordered/tampered captures, missing parents or unsupported coalesced authority return explicit failure rather than an invented event order.

The current candidate is derived from **CharacterSaveContract.decode(original_prepared.document)**, exactly as a cold legacy read does. This matters for live movement values such as `[0.0,0.0]`: the legacy decoder normalizes these integer-valued JSON numbers to `[0,0]`, while the compact codec requires canonical normalized numbers. The original legacy proposal bytes remain bound unchanged; no history or number is silently rewritten in storage.

The entire decoded original projection must equal V6._projection(candidate). That includes items/quantities/condition/equipment, XP, immutable creation attributes, current resources, run/checkpoint, schema-12 RNG, movement, fatigue, cooldowns, timing and Mana remainder. V6.encode and V6.validate_extension then run full standalone proof. No incremental/cached verification shortcut was added.

## 5. Existing-credit predecessor preservation (S2 prerequisite discovered)

45L sometimes deduplicates a historical fixed-credit predecessor's ledger arrays as `v6_current_ledger_prefix` references. Those references are valid at conversion, but `PlayableCharacterPersistence.restore_ledger()` legitimately rebuilds the current run ledger on admission: awards/drop arrays can start empty and purchase request representations change. Therefore merely copying those references into the next candidate produced `invalid_credit_ledger_reference` despite valid unchanged credit history.

The fix is limited to the dormant V6 proof:

- `materialize_credit_predecessor(validated_parent)` copies the **already verified exact parent-ledger prefixes** into the existing predecessor representation. It does not infer them from new totals or manufacture missing evidence.
- Extension still requires the actual credit record to remain exactly equal. A changed predecessor representation is allowed only when it equals this exact materialization of the fully validated parent. No count, unrelated field, credit amount/ID, predecessor generation, ordering or original binding may change.
- Candidate cold validation still proves that predecessor and its original credit binding. Tests independently compare it with the exact original decoded legacy generation and reject an altered predecessor even after rebuilding hashes/accounting.

This intentionally permits one representation transition the earlier dormant extension rejected. It is **not** a claim that every hypothetical new input is accepted/rejected identically to the pre-S2 validator. The original 45P equivalence/rejection input set still passes, and its exact-ID algorithm is unchanged. No new persistent field/version or production contract change.

**B2 remains closed:** the test constructs a standalone source-valid legacy-credit proof after an uncredited compact parent, then verifies extension rejects it with `credit_history_changed`. S2 cannot add any post-conversion credit, including the existing fixed grant. The only credit published during fixture setup is through the existing legacy credit contract/coordinator into disposable storage, before conversion.

## 6. Supported and verified transaction families

| Family | Source-valid operations and verification |
|---|---|
| New baseline | Actual first Wave 1 checkpoint; native compact epoch/sequence-one baseline; no starter history invented |
| XP | NORMAL x1 and legacy DEV x1/x10; source-valued physical combat defeats, original causal IDs, source-blocked boss reward stays blocked |
| Permanent advancement | Actual STR/DEX/SPD/WIS/END requests, DEX DT allocation, correct source costs; no new tables/prices/caps |
| Original growth | Legacy END6/HPB1 and WIS10; END7 plateau then END8/HPB2 and WIS11 before actual future growth; WIS12 afterward without retroactive changes |
| Resources | Unchanged immediate HPM/HPC on END purchase and unchanged current resource balances on WIS purchase; exact Mana remainder and checkpoint resources |
| Inventory/currency | Real collection/ownership/provenance, individual item origins, currency totals, equipment removal/re-equip and consumable quantity decrement |
| Shield condition | Actual legal incoming physical attacks and shield Block consuming SHP, then ingestion of that original event; no manufactured condition receipt |
| Run lifecycle | Wave completion/NEXT WAVE, cold RESUME, explicit head-bound abandonment/NEW RUN, new immutable x1 policy with original x10 history retained, complete five-wave circuit |
| Running/timers | Existing movement boundary provider and refresh callbacks; nonzero Running/recovery state/RNG and Mana remainder preserved exactly on RESUME |
| Development/dedup | 23 independent legal preference checkpoints; original purchases/defeats remain non-replayable after journal eviction; exact retry and uncertain observer acknowledgement |

Potion/shield fixtures are explicitly source-backed disposable acquisitions via the existing world-item ownership path, following 45L test infrastructure, not claims that those items dropped in a real owner's run. A legal explicit **legacy DEV downtime Refresh** prepares the shield condition fixture; any heal is that original operation, not the adapter. No new refresh authorization or behavior.

## 7. Independent equivalence and rejection tests

The test host compares against real unobserved legacy execution, not an expected balance produced by the packer:

- Repeated same-seed scenarios yield equal compact records. Independent observed/unobserved sessions produce equal complete simulation snapshots, authoritative event/RNG history and full legacy payloads.
- The complex interleaved END/WIS/all-five-purchase/item/shield/23-checkpoint command sequence is replayed independently without the observer. Entire snapshots and persisted projections match.
- Every supported snapshot matches the exact cold legacy result. Independent CharacterProfileProjection.hydrate produces the same permanent/equipment-adjusted actor; generation-backed EnduranceGrowthHistory witnesses match compact END/HPB witnesses. Original lifetime award/purchase/growth/settlement/credit bindings are enumerated from the original projection and compared exactly.
- Every prepared boundary probes immutable returned copies/strings, forged handles, stale tokens, changed source/request data, namespace crossover, reordered facts, terminal cancellation and missing chronological evidence. No simulator state changes across prepare/check/adopt.
- A real two-session cache-only writer race uses two distinct legal downtime commands. The existing coordinator publishes only the winner; the loser has a nested persistence failure, cannot adopt its unacknowledged candidate and does not overwrite the winner or change XP.
- Unknown/unobserved history, generation gaps and new post-conversion credits fail closed. The original full cold decoder/semantic validators remain in use.

These are deterministic replay and **simulated-client** comparisons, not multiplayer networking, actual Edge gameplay acceptance or V6 storage publication/recovery tests.

**8/8 focused native suites PASS; zero failures.** Six suites print **3,114 assertions** in total; the two existing coordinator/playable suites do not print their counts.

| Filter | Printed assertions | Result |
|---|---:|---|
| 45Q gameplay candidate | 912 | PASS |
| 45K compact V6 prototype | 814 | PASS |
| 45P exact lifetime lookup | 278 | PASS |
| 45L legacy conversion | 912 | PASS |
| 45M disposable storage | 62 | PASS |
| 45N portable backup | 136 | PASS |
| Task 36J-Pass2 coordinator | Not printed | PASS |
| Task 36J-Pass5 playable persistence | Not printed | PASS |

Final logs have no script errors, warnings or resource-leak reports. The original 45P frozen validator comparisons still pass. Focused compatibility/storage/backup cases are disposable native tests, not production publication. A bounded standalone race probe also passed before the final full 45Q focused run.

Commands from the primary source checkout:

```powershell
$godot = 'C:/Users/mxz/Desktop/GoDot/Godot_v4.7.2-stable_win64_console.exe'
$env:ARENA45P_FIXTURES = "$env:LOCALAPPDATA/itank-storage-tests/compact45m_45p_session_20261117"
$env:ARENA45M_FIXTURES = "$env:LOCALAPPDATA/itank-storage-tests/compact45m_session_20261117b"
& $godot --headless --path . --script tests/test_runner.gd -- '--suite=45Q'
& $godot --headless --path . --script tests/test_runner.gd -- '--suite=45K'
& $godot --headless --path . --script tests/test_runner.gd -- '--suite=45P'
& $godot --headless --path . --script tests/test_runner.gd -- '--suite=45L'
& $godot --headless --path . --script tests/test_runner.gd -- '--suite=45M'
& $godot --headless --path . --script tests/test_runner.gd -- '--suite=45N'
& $godot --headless --path . --script tests/test_runner.gd -- '--suite=Task 36J-Pass2'
& $godot --headless --path . --script tests/test_runner.gd -- '--suite=Task 36J-Pass5'
git diff --check
```

No full regression or Web export. GDScript parsing/compilation is exercised by the actual focused runs. Earlier development fixture failures (incorrect READY preference boundary, missing Running refresh provider and a wounded shield-test participant) were corrected by using the existing legal APIs/explicit DEV recovery; production rules or old test assertions were not weakened. Numeric cold-representation and existing-credit prefix failures led to the two narrow bridge corrections described above.


## 8. Native performance and memory

Godot 4.7.2 Windows headless debug/editor, disposable real-operation fixtures. Candidate construction measured separately from legacy storage publication. No production export or Edge measurement in this task.

- construction_ms: coordinator authorization, original decode, event/chronology capture processing, binding and candidate assembly.
- validation_encode_ms: full V6 validation/encoding and full previous/candidate extension proof.
- seal_ms: immutable prepared-body generation and exact byte digest.
- total_prepare_ms: full prepare call including context/head checks and equivalence checks. Repeated `check()`/`adopt()`, test probes and storage publication are not hidden inside this number.
- Native live-byte deltas are Godot allocator samples, not total allocation traffic or proof of retained memory. Global peak includes preloaded suites/resources and the test's deliberate retention of all candidate records for comparison.

These distributions span different real checkpoint batches, not statistical repetitions of one immutable large record. Small scenarios have two deterministic replay runs; p95 uses nearest rank. They cannot certify owner latency or extrapolate to 10,000 IDs; 45P's separate scale/oracle fixtures cover that lookup stress.

| Checkpoint family | n | Construction p50 / p95 / max ms | Full validation + encode p50 / p95 / max ms | Total prepare p50 / p95 / max ms |
|---|---:|---:|---:|---:|
| normal1 | 8 | 13.005 / 18.122 / 18.122 | 11.807 / 13.168 / 13.168 | 27.277 / 31.922 / 31.922 |
| dev_normal1 | 8 | 13.176 / 19.634 / 19.634 | 11.351 / 13.484 / 13.484 | 28.080 / 32.914 / 32.914 |
| dev_normal10 | 8 | 12.205 / 15.538 / 15.538 | 11.230 / 14.854 / 14.854 | 25.432 / 28.486 / 28.486 |
| converted_v5_complex | 45 | 49.516 / 57.501 / 60.775 | 74.462 / 87.059 / 91.006 | 129.228 / 150.574 / 156.652 |
| new_run_x1_complete | 16 | 58.350 / 91.352 / 91.352 | 88.423 / 119.905 / 119.905 | 154.438 / 221.348 / 221.348 |

| Family | Maximum record bytes | Maximum sealed-operation bytes | Maximum facts/batch | Max IDs / operations / awards / purchases / growth / current items |
|---|---:|---:|---:|---|
| normal1 | 27193 | 171773 | 193 | 25 / 4 / 3 / 0 / 0 / 7 |
| dev_normal1 | 27141 | 171750 | 193 | 25 / 4 / 3 / 0 / 0 / 7 |
| dev_normal10 | 24009 | 126129 | 134 | 23 / 4 / 3 / 0 / 2 / 5 |
| converted_v5_complex | 155028 | 312262 | 231 | 171 / 51 / 13 / 7 / 7 / 23 |
| new_run_x1_complete | 245051 | 448244 | 282 | 269 / 67 / 24 / 7 / 8 / 52 |

Across these batches, sealing median/p95/max: 1.929 / 3.597 / 4.830 ms. Maximum sampled prepare live-byte delta: 6,541,936 bytes. Godot allocator peak for the complete final test process: 382,324,620 bytes (364.61 MiB); allocator live bytes at final metrics: 145,657,872.
Own-process monitor observed a maximum process-reported peak working set of 529,702,912 bytes (505.16 MiB), over 2961 samples from process launch to exit at 100 ms. This is the largest observed OS peak counter, not a guaranteed last-instant lifetime peak or memory attributable only to the builder.

The compact record and sealed in-process request are different sizes: the latter additionally holds exact event facts for current authority. These are not portable-backup bytes or complete user-click/save latency. Related suites ran separately from the final timed run; no competing heavy benchmark was intentionally run. No Windows exported-release, Edge/WASM, browser renderer RSS, owner-save load or storage-publication latency claim is made.

Evidence: `%TEMP%/arena45q-final.log` (full focused run and raw metric samples), `%TEMP%/arena45q-check-*.log` (related suites), `%TEMP%/arena45q-race-probe.log` (bounded race diagnosis), `%TEMP%/arena45q-process-memory.json` (own-process memory sampling). Synthetic profile roots are OS-cache `itank-storage-tests/compact45q_*`; no production profile path is used.

## 9. Unsupported cases and remaining activation blockers

- No live callers, V6 route, storage writer/reader, database upgrade, backup dispatch or owner conversion. Later integration must expose/reuse the existing coordinator preparation seam and bind actual storage head/blob digest/ownership/readback; this observer does not install a second publication protocol.
- No new post-conversion EXPC grant (B2/S3), unrestricted credit or general wallet operation. Already proven historical credits alone survive.
- Requires actual authorized gameplay proposal, trusted source/context, exact parent and captured causal order. It does not reconstruct lost event facts, skip missing generations or authorize ambiguous coalesced END-purchase/growth histories that existing validation rejects.
- New characters/identities/resource modes are limited by existing playable admission and source rules. This test exercises the supported Mana-using source profiles, not hypothetical AP-class admission, new Specials, arbitrary actors or multiplayer authority.
- Runtime snapshot hashing, event copying and full proof remain O(transcript/evidence); outstanding wave facts can be large. No ancestry redesign, proof cache, incremental validation, transcript pruning or storage optimization. Routine V6 save latency and the owner's historical Edge memory issue are not solved or certified here.
- Cancellation stops this in-memory operation only; it cannot roll back an already committed legacy transaction. Technical previous state never grants a refund or authorizes an older character.
- S2 removes the missing logical gameplay-candidate-builder gap for the tested current boundaries. It is not approval to activate V6. S3 credit proof and later production-shaped ownership/routing/recovery/backup tests remain separate approval gates.

## 10. Git and protected-data status

Branch `main`, unchanged HEAD `f9bb0db0235b0003895c477a12346191d4714469`; index empty. 29 modified tracked paths; 80 collapsed untracked entries, including preserved earlier work and protected names.

A pre-edit SHA-256 snapshot covered 665 nonprotected project files. Only the two existing files in the manifest changed; all other 663 match byte-for-byte. This includes the 45P coordinator exact-ID optimization, profiling/oracle files, all 45B/45D/45E production changes and project.godot. Project.godot SHA-256 remains `8398f110f77d7712eb19c283eb9f745c7123feab9557187778da412639ba5692`. The prior Python cache is unchanged and remains outside the intended source manifest.

No owner Vaelis character, personal saved profile, backup, Edge tab or IndexedDB was read/converted/changed. Fixtures use authored source definitions and newly generated cache-only histories with the existing test profile IDs. Protected boss documents, `character saves/` and repository `tmp/` were not inspected or changed. The Git listing below contains names only for those protected paths.

No staging, commit, push, reset, rebase, stash, clean or other Git mutation. No production artifacts generated. The two new UID sidecars and all seven intended files passed scoped whitespace/final-newline checks; `git diff --check` passed.

Exact `git status --short` (Git's collapsed directory view):

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
?? docs/audits/TASK_45E_SAVE_LOAD_PERFORMANCE.md
?? docs/audits/TASK_45G_WEB_MEMORY_DIAGNOSIS.md
?? scripts/combat/arena_mana_recovery.gd
?? scripts/combat/arena_mana_recovery.gd.uid
?? scripts/rewards/compact_character_v6_prototype.gd
?? scripts/rewards/compact_character_v6_prototype.gd.uid
?? scripts/rewards/compact_v6_equivalence.gd
?? scripts/rewards/compact_v6_equivalence.gd.uid
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


Stop after S2. No S3, V6 activation or production integration is started.
