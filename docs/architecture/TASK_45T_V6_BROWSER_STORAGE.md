# Task 45T â€” Dormant V6 browser storage, S5

## Scope and status

S5 is explicitly disposable and dormant. No playable caller selects this route. Production IndexedDB, its database version/name and production browser/backup UI remain unchanged. No owner character, backup or browser profile was read. The original 45Bâ€“45S working tree and project.godot are preserved.

Primary checkout: `C:/Users/mxz/Desktop/Projects/ITank Prime/Video Game/ITank Arena/i-tank-prime-arena`, main, HEAD `f9bb0db0235b0003895c477a12346191d4714469`. Read 45O/S/R/Q/N and inspected actual coordinator, browser facade/transport, Web Lock protocol, compact adapter, portable codec and S4 implementation before editing. Test results and remaining limitations are recorded below; this is not production activation approval.

## Architecture and isolation

- `compact_v6_browser_store.js` accepts only `itank-arena-test-36k-45t-*` disposable names. No production default, alias or live database upgrade exists. Constructor and operation guards reject the production name before opening it.
- Additive IndexedDB schema 2 preserves the original `heads`, `generations` and `transactions` stores and every original legacy row unchanged. Added stores: `profile_routes` (profile key) and `compact_blobs` (profile, kind, exact digest key).
- Profile routes bind version/minimum reader, active format 6, identity, namespace, source/rules, epoch, sequence, logical digest, exact encoded digest, previous digest, capsule digest, original operation/request and legacy conversion boundary.
- Compact blobs contain canonical current envelope, retained known previous envelope and one current self-contained portable recovery capsule. The capsule proves full ancestry and can reconstruct the exact current state; a previous record alone never authorizes rollback. Empty-destination descendant restores can reconstruct their predecessor from the capsule without an original machine archive.
- Actual engine rules remain in Godot. The JS module is transport, like the existing browser store, not a new wallet, mutation authorizer or hostile-console authentication system. Hashes detect damage; they do not establish gameplay entitlement.

## Existing writer protocol and old-client exclusion

Reuse the actual production `ArenaCharacterBrowserStorage` implementation for profile Web Locks, busy/transfer/release checks and owner names. Both formats request the same `${database}:writer:${profile}` lock. There is no timeout/PID stealing.

Opening schema 2 creates empty additive stores, never converts a character. Cooperative schema-1 connections close on versionchange; in-flight transactions finish before the upgrade. A noncooperative connection reports `database_upgrade_blocked`; its data is not deleted. Once schema 2 is installed, the existing schema-1 implementation's explicit version-1 open receives VersionError (`unsupported_database_version`). A closed old connection cannot publish. An old tab can still own its Web Lock after closing its DB connection: S5 cannot steal it. Actual tab termination lets the browser release that lock, after which a new owner may acquire it.

Actual isolated Edge gate and multi-tab results are listed below. This excludes the inspected schema-1 clients, not arbitrary external tools replacing the complete storage image. Production upgrades still require separate approval.

## Coordinator, ordering and acknowledgements

`compact_v6_browser_coordinator.gd` extends the existing asynchronous browser coordinator and uses the unchanged `CharacterPersistenceCoordinator._authorize`, continuity, receipt and new-item validators. Live preparation requires the real S2 adapter and its privately owned pending handle. Original request bytes, candidate, logical parent, profile, namespace and source are pinned and rechecked; a supplied checksum/verification flag cannot authorize a purchase or award. S3 typed credit retains its fixed identity, explicit consent and original authority.

The single-flight pump performs:

1. Snapshot under the original Web Lock, full Godot semantic/capsule validation.
2. Recheck original gameplay authority and exact parent/checkpoints; construct the portable proof with existing codec/validators. Legacy activation instead fully validates the actual original rows through the converter and its independent comparison, then requires exact explicit consent.
3. Recheck complete route, relevant current/capsule bytes and original legacy head inside the read/write transaction. Initial conversion also compares every legacy row and receipt. Stage required immutable compact blobs and replace route in the **same** transaction; no asynchronous semantic/crypto work runs inside that transaction.
4. A new transport transaction reads exact committed route/blobs. Godot independently reads again, cold-validates the complete capsule and exact current bytes, then asks JS for one more fresh route/blob match before success.
5. Shared service `_ack` and S2 `adopt_compact` require exact generation, original request, projection, encoded digest and route binding. Queued/pending results never acknowledge progress. Lost acknowledgement reads the existing exact candidate instead of applying rewards/purchases again.

`playable_character_persistence.gd` adds an explicit browser-disposable admission entry and reuses S4's already verified admission/acknowledgement core. It does not change ordinary open(), browser admission, automatic publication, schema 12, run policies or progression rules. Browser admission requires complete validation plus a fresh readback match under the retained owner lease.

Routine snapshots count legacy generations but do not transfer/replay the archived generation array. It is fetched only for explicit conversion. Lifetime IDs and immutable bindings remain fully validated; the 20-entry recent journal is not authority. Canonical object comparisons ignore property insertion order while retaining every field/value and array order. Encoded character/portable bytes are never normalized away at publication.

## Interruption and recovery matrix

| Case | Required/observed result |
|---|---|
| Abort/before-transaction/injected quota error | No acknowledgement, original route remains current; explicit exact request can retry. Quota is failure injection, not physical disk exhaustion. |
| Commit succeeds, acknowledgement lost | Fresh full readback reconciles exactly once. |
| Cancel before publication | Drain original callback and reject publication. Retained original operation can be explicitly retried. |
| Cancel after possible publication | Do not undo; reconcile exact stored state. |
| Foreign/copied candidate or changed request | Existing authority/owned handle rejects. |
| Two same-parent authorized runtime requests | First secures state, stale peer cannot publish or adopt it as its own effect. |
| Wrong profile/namespace/source/version | Fail closed. |
| Current missing/truncated, matching capsule intact | Validate and repair exact acknowledged current with route/capsule CAS; repeated repair is idempotent. |
| Damaged capsule / missing or conflicting route | Fail closed. No older compact or legacy fallback. |
| Older/same-sequence conflicting/unrelated portable state | Existing full ancestry/relationship validator rejects rollback. |
| Page/WASM restart | New route must cold-validate persisted proof; no warm verification flag survives. |
| Outdated callbacks/owners | Request identity and Web Lock ownership reject them. |

IndexedDB strict durability is requested where available; no tested result is claimed to prove OS power-loss durability or prevent whole-database replacement/rollback.

## Test infrastructure and measurements

Native tests use an explicitly injected in-memory transport model, real gameplay sessions/S2/S3/coordinator and full cold validators. They are not actual IDB results. Browser tests use a fresh headless Edge process/profile, random loopback origin and separate TEMP Godot 4.7.2 release-WASM project. No production Web build/export configuration or localhost:8000 artifact is touched.

The frozen 233-generation disposable archive from S4 is reused exactly. It is SHA-checked, seeded unchanged into a schema-1 **disposable** DB, then independently fully converted and compared in release WASM. No UI-dependent history fabrication replaces that proof.

Historical development fixtures use the fixed DEV profile ID because the existing rules require it; they contain no owner data. Native and browser examples do not constitute owner acceptance.

## Verified performance limitations

One earlier instrumented release run fully passed conversion and three subsequent long-history saves before an inventory-harness type error stopped that aggregate run. Those timings are valid individual observations, not an aggregate PASS:

- Frozen 233-generation activation: 21,996.5 ms coordinator; 18,821.2 ms conversion/preparation, including full original history and independent equivalence checks. One-time conversion is excluded from routine-save targets.
- Subsequent long saves, including test-host preparation/adoption/summary: 4,332.0 / 5,602.7 / 7,249.9 ms. Coordinator-only portions: 2,262.2 / 2,961.2 / 3,845.4 ms. Actual IDB write transactions: 38.9 / 33.0 / 38.2 ms.
- Portable sample: 108,158 bytes, export codec 174.1 ms, preview 188.8 ms, restore coordinator 1,080.1 ms. This is not the large-inventory portable workload.

The inventory harness incorrectly typed a CombatActorState as Dictionary. Test-only correction restored source-qualified creation; no production combat/geometry rule was changed. A separate release run then verified 1,005 items / 2,023 lifetime IDs, record 2,097,220 bytes and capsule 3,978,989 bytes. Full host save 25,425.7 ms; coordinator 12,886.0 ms, preparation 6,565.7 ms, semantic snapshot validation 1,568.6 ms, IDB transaction 48.0 ms and transport readback 9.4 ms. These inclusive intervals overlap and must not be added. No performance target is claimed passed by that case.

This supports the S4 finding: full semantic replay/capsule reconstruction, bridge serialization and repeated verified representations dominate small raw IDB transactions. No validator/readback was removed. Differing native/browser fixtures and transition counts do not constitute a controlled speedup comparison.

Earlier conversion run: WASM capacity reached 1,107,755,008 bytes; largest owned renderer sampled RSS 1,303,478,272 bytes / peak working set 1,535,873,024 bytes. Separate inventory run: WASM 432,275,456 bytes; corresponding renderer RSS 581,750,784 / peak 647,761,920 bytes. These include retained disposable test contexts and one-time conversion; capacity/high working set does not by itself establish an idle leak. JS heap, WASM capacity and owned renderer readings are recorded separately in result files. No owner-tab memory was measured.

## Remaining release blockers

- Severe large-inventory save latency and synchronous semantic/main-thread stalls remain; S5 does not authorize a broad performance rewrite.
- Full portable ancestry, exact lifetime IDs and proof sizes grow under existing finite limits. No legitimate evidence is pruned.
- One-time complete legacy conversion can expand WASM capacity substantially; capacity is not promised to shrink until reload. Retained test probes contribute to memory and are not production idle measurements.
- Windows stale-lease recovery remains a separate S4 blocker; browser-native tab termination release does not fix Windows lease ownership.
- Browser quota/eviction and OS power-loss durability are not guaranteed. Missing authoritative route/exact recovery proof remains diagnostic-only.
- S6 playable backup UI, production schema upgrade/activation, owner conversion, networking and owner acceptance remain unimplemented and unauthorized.

## Final verification results

- **6/6 focused native suites PASS**, zero final assertion failures: new S5 **47**, existing S4 route **422**, S4 guards **13**, S3 credit **132**, and both legacy 36K browser suites. The four published counters sum to 614; the two older suites do not print complete assertion totals. No full regression was run. Native S5 allocator peak 280,480,016 / live completion 186,805,043 bytes includes runner's registered-suite preload overhead; this is a native-debug transport model, not Windows release or browser memory.
- Actual isolated Edge/release WASM complete workflow: **58 checks PASS**. Frozen 233-generation conversion, source-verified historical credit/growth, three later saves, real typed native credit, END/WIS purchases, duplicate evidence, abort/quota simulation, cancellation, stale callbacks, 1,000+ lifetime IDs outside journal, export/preview/restore, exact repair, wrong namespace/older backup rejection, hidden-tab progress and committed-but-unacknowledged page reload passed.
- That complete run preceded only test instrumentation and an idempotent JS module-initialization guard. The final storage/coordinator/codec logic is unchanged. **Final-source matrix: 48 checks PASS** (fresh/replay, credit, purchases, actual IDB fault/cancel matrix, portable restore/recovery, namespace and multi-tab gates). The final module is reused on later route construction, like the existing production bridge; this prevents resetting its handle registry and permits accurate bridge instrumentation.
- **Final-source actual pre-publication page termination: 19 checks PASS**, with unchanged old head/XP and browser-native lease release. The complete workflow separately passed actual page reload after observing a newer committed route while the engine still acknowledged its old generation: exact latest state recovered, no duplicate credit, XP, purchases or items.
- **Final-source instrumented release smoke: 18 checks PASS**, plus a final **20-check smoke/CAS run PASS** that directly reissues an original authorized transport request and verifies rejection against its outdated IndexedDB parent. **Final-source large portable workflow: 8 checks PASS**. These counts include repeated setup/guard controls; do not add them as distinct coverage counts.
- Final native/browser/runtime logs contain no Godot script errors, JS exceptions or resource-leak diagnostics. The earlier parse/setup failures and property-order rejection were investigated/corrected, never relabeled as passes or hidden by weakened expectations.
- Node syntax checks, Godot check-only/native compilation, TEMP harness import/release export, tracked diff whitespace and explicit task-file whitespace checks PASS. Git's pre-existing CRLF-to-LF informational notices are not script/export errors. No production export or full regression.

### Final complete-run timings (release WASM)

Single samples unless stated; intervals are inclusive and overlap. Host totals include real S2 preparation, service acknowledgement/adoption and test diagnostic summaries, which themselves perform full semantic validation. Coordinator timings start after S2 preparation. They are not pure disk/IDB timings.

| Workflow | Measured time |
|---|---:|
| Fresh initial NORMAL coordinator / independent replay | 175.4 / 149.3 ms |
| Frozen 233-generation activation, entire measured host call | 28,004.6 ms |
| Activation coordinator / conversion+proof preparation | 26,705.2 / 22,705.2 ms |
| Three later long-history host saves | 6,619.0 / 8,966.2 / 10,340.8 ms |
| Corresponding coordinator saves | 3,645.2 / 4,779.0 / 5,458.2 ms |
| Corresponding IDB write transactions | 37.3 / 40.2 / 52.3 ms |
| Complete-run high inventory, host / coordinator | 37,477.8 / 17,687.4 ms |
| High-inventory preparation / full snapshot semantic checks | 9,720.8 / 2,769.5 ms |
| High-inventory IDB transaction / transport readback | 50.3 / 5.7 ms |
| Small/credited portable export / preview / restore coordinator | 656.7 / 579.9 / 3,217.4 ms |

The complete-run inventory contains 1,005 items, 2,041 lifetime IDs and 12 operations at that save, 2,122,384-byte record / 4,107,306-byte capsule. After the deliberately uncertain publication/reload: 13 operations, 2,043 IDs, exact original credit and purchases preserved. This differs from the separate four-operation inventory benchmark above; it is not an A/B speed comparison.

For the three long-save observations only: p50 8,966.2 ms, nearest-rank p95/max 10,340.8 ms. With n=3 this is descriptive, not an estimated service-level p95. No percentiles are claimed for singleton workloads.

### Final-source large portable and cold-load measurements

Reused only the earlier **disposable** acknowledged 1,005-item fixture in its own temporary Edge profile/origin, with the final release PCK. No repeat legacy conversion or owner access was needed.

| Operation | Full measured host time | Inner codec/coordinator |
|---|---:|---:|
| Full cold load | 10,734.8 ms | not separately attributed |
| Export 4,844,408-byte portable file | 5,882.7 ms | codec 2,274.9 ms |
| Full imported-file preview | 2,937.1 ms | codec 2,720.4 ms |
| Independent confirmed restore | 18,547.9 ms | coordinator 15,025.1 ms |
| Exact repair/recovery after truncated current | 13,956.5 ms | not separately attributed |

Restored and repaired encoded-character hashes matched the original exactly. Portable SHA-256: `f2817e69f30da88cbd59839908bf45d64265a7b682bae56dfaa5f78f7b308c16`. No evidence was omitted to meet targets. These results **block production performance acceptance**.

### Bridge, memory and responsiveness

Final-source small workflow: actual S2 initial preparation 20.0 ms (construction 12.9, validation/encoding 5.9, seal 0.7); subsequent source-qualified wave checkpoint S2 56.0 ms (31.7 / 19.9 / 3.4). These samples are native engine work running in release WASM, not JS approximations. Final instrumented smoke adds endpoint measurements over 12 bridge requests / 22 polls: 375,841 UTF-8 request bytes, 262,229 response bytes, 4.5 ms cumulative JS endpoint synchronous work, maximum 1.1 ms. The endpoint timer excludes Godot-side parse/copy/replay and does not isolate all physical bridge overhead.

Large-portable workflow: 13 bridge requests / 32 polls transferred 43,304,553 request JSON bytes and 40,733,768 response JSON bytes, cumulative endpoint synchronous work 203.2 ms / max 37.9 ms. These include repeated snapshot/readback data, not only the 4.84 MB portable file. No lifetime proof cache replaced validation.

Complete release run: fresh JS used heap 8,355,072 bytes, WASM capacity 120,586,240 bytes; largest relevant renderer fresh RSS 318,529,536 bytes. After conversion/high-inventory work WASM capacity 1,084,030,976 bytes; largest owned renderer peak 1,448,693,760 bytes. After JS GC, JS used heap 8,674,288 bytes while WASM capacity stayed unchanged and that renderer RSS was 1,099,948,032 bytes. This distinguishes JS garbage from retained WASM/native capacity; it is not proof of continuously growing idle memory.

Final-source large portable in a fresh WASM instance: JS heap 50,276,020 -> 12,925,560 bytes after GC; WASM capacity remained 469,368,832 bytes; corresponding renderer RSS 672,088,064 -> 626,163,712, peak 738,390,016 bytes. Retained test contexts/probes and software WebGL renderers contribute. No owner memory acceptance is inferred.

20-ms event-loop probe: maximum delay **25,792.1 ms** in the complete run, **8,353.0 ms** during the large-portable workflow. Hidden-tab work completes without animation-frame pumping, but synchronous full semantic/capsule work still causes unacceptable main-thread stalls. Keep this as a separate optimization blocker, not a claim of responsive production UI.

## Artifacts, source identity and commands

Only the isolated TEMP harness was exported. Final PCK SHA-256: `4bf8f6520ca0ba5041b1bfc926760bfd16df220f79f6fc254f41fc8337cc7789`. Its storage JS, route/coordinator GDScripts, shared service, test host and WASM harness match current workspace bytes. Earlier full-workflow PCK: `7b544d39772ae9abe56d63899bd82102416381155fc40945a6eff404bbd20ab4`; only module-init guard and test instrumentation differ as described above. This is not a production BUILD identifier or deployed artifact.

Disposable result roots:

- Complete workflow: `%TEMP%/arena45t-edge-tTJQs5/` (58 checks, full timing/memory JSON).
- Final-source import/export/smoke: `%TEMP%/arena45t-edge-fsHTFm/` (18 checks).
- Final-source matrix: `%TEMP%/arena45t-edge-lTFSxq/` (48 checks).
- Final-source before-publication termination: `%TEMP%/arena45t-edge-IRGEJv/` (19 checks).
- Final-source transaction CAS/bridge smoke: `%TEMP%/arena45t-edge-HHEOfy/` (20 checks).
- Final-source large portable: `%TEMP%/arena45t-edge-JWBgq3/` (8 checks).

Commands from the primary checkout:

```powershell
$Godot = 'C:/Users/mxz/Desktop/GoDot/Godot_v4.7.2-stable_win64_console.exe'
& $Godot --headless --path . --check-only --script scripts/rewards/compact_v6_browser_coordinator.gd
& $Godot --headless --path . --check-only --script tests/browser/compact_v6_browser_wasm_harness.gd
& $Godot --headless --path . --script tests/test_runner.gd -- '--suite=45T browser compact route'
& $Godot --headless --path . --script tests/test_runner.gd -- '--suite=Task 36K-'
& $Godot --headless --path . --script tests/test_runner.gd -- '--suite=45S Windows guards'
& $Godot --headless --path . --script tests/test_runner.gd -- '--suite=45S Windows compact route'
& $Godot --headless --path . --script tests/test_runner.gd -- '--suite=45R native compact credit'
node tests/browser/test_compact_v6_browser_edge.js --schema-only
node tests/browser/test_compact_v6_browser_edge.js
node tests/browser/test_compact_v6_browser_edge.js --phase=smoke
node tests/browser/test_compact_v6_browser_edge.js --reuse="$env:TEMP/arena45t-edge-fsHTFm/project" --phase=matrix
node tests/browser/test_compact_v6_browser_edge.js --reuse="$env:TEMP/arena45t-edge-fsHTFm/project" --phase=termination
node tests/browser/test_compact_v6_browser_edge.js --reuse="$env:TEMP/arena45t-edge-fsHTFm/project" --resume-profile="$env:TEMP/arena45t-edge-tTJQs5/edge-profile" --phase=large-portable
git diff --check
```

The runner creates its own minimal project/export preset in TEMP and invokes Godot `--headless --editor --import` / `--export-release 'Disposable Web' web/index.html` there. `--reuse` uses an already verified disposable test PCK. `--resume-profile` above refers solely to the runner-created temporary profile, not a personal browser profile. Logs: `%TEMP%/arena45t-native-final2.log`, `arena45t-related-*.log`, `arena45t-edge-final.log`, `arena45t-matrix-final.log`, `arena45t-termination-final.log`, `arena45t-smoke-final.log`, `arena45t-cas-final.log`, `arena45t-large-portable.log`.

## Windows S4 differences and explicit limits

- Browser schema upgrade + native Web Lock exclusion replaces the Windows immutable legacy fence and filesystem lock directories. No legacy records are rewritten. IDB route/blobs publish atomically; Windows stages files then publishes one route rename.
- Browser page termination releases the native Web Lock automatically, proved in actual Edge. Windows stale filesystem leases remain fail-closed and need separate ownership/recovery work.
- Semantic/candidate rules, exact lifetime IDs, full portable proof and acknowledgement bindings are reused. No new reward authority or separate wallet.
- Quota is simulated by aborting a disposable transaction; physical browser-quota exhaustion and power-loss were not induced. Whole-origin/storage-image loss/rollback remains outside local hash guarantees.
- Headless software-WebGL Edge is actual release WASM, but not owner interactive/hardware-browser acceptance. No playable menu, production database or real profile was involved. No S6 backup UI integration or production activation is claimed.


## Exact task manifest

Added (15):

- `docs/architecture/TASK_45T_V6_BROWSER_STORAGE.md`
- `scripts/rewards/compact_v6_browser_coordinator.gd`
- `scripts/rewards/compact_v6_browser_coordinator.gd.uid`
- `scripts/rewards/compact_v6_browser_storage.gd`
- `scripts/rewards/compact_v6_browser_storage.gd.uid`
- `scripts/rewards/compact_v6_browser_store.js`
- `tests/browser/compact_v6_browser_edge_cases.js`
- `tests/browser/compact_v6_browser_multitab_cases.js`
- `tests/browser/compact_v6_browser_wasm_harness.gd`
- `tests/browser/compact_v6_browser_wasm_harness.gd.uid`
- `tests/browser/test_compact_v6_browser_edge.js`
- `tests/compact_v6_browser_host.gd`
- `tests/compact_v6_browser_host.gd.uid`
- `tests/test_compact_v6_browser_storage.gd`
- `tests/test_compact_v6_browser_storage.gd.uid`

Modified (2):

- `scripts/rewards/playable_character_persistence.gd`
- `tests/test_runner.gd`

## Git/workspace protection

- Main / HEAD unchanged: `f9bb0db0235b0003895c477a12346191d4714469`. Empty index. End inventory: **29 modified tracked files, 120 collapsed untracked entries**.
- Hash comparison against all 681 snapshotted original nonprotected source/test/document/config files: only the two intended existing task files above changed; no original file is missing. All earlier 45B–45S changes remain preserved. The 15 additions include five required UID sidecars.
- `project.godot` preserved SHA-256 `8398f110f77d7712eb19c283eb9f745c7123feab9557187778da412639ba5692`. Production browser transport/facade, Windows route, coordinator authority, V6 semantic rules and production backup behavior were not edited by S5.
- Protected boss document, `character saves/`, repository `tmp/`, owner backups and personal IndexedDB were not opened or modified. Git lists their names only. No Git mutation, cleanup, production export/deployment, owner conversion or S6 work occurred.

Exact status at closeout:

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
