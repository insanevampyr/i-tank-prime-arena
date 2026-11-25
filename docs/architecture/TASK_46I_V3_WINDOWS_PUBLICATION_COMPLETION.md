# Task #46I resumed — Disposable compact v3 Windows publication

2026-11-19. **Complete for the isolated, supported-fixture Windows process-crash scope. GO for separately authorized disposable Edge/IndexedDB integration.** No playable activation, owner conversion, browser route, backup format, production packaging or unattended stale-lock reclamation is implemented.

## 1. Exact task manifest

Modified existing files:

1. `scripts/rewards/character_persistence_coordinator.gd` — explicit disposable `attach_minimal_windows()`, `publish_minimal_windows()` and `automatic_minimal_windows()` on the existing owner. Original production writer/authorization bodies remain unchanged.
2. `scripts/rewards/minimal_character_transactions.gd` — attach the bounded transport; publish owned current/pending bytes; real readback before request retirement; separate simulated acknowledgement from actual publication; defer item acknowledgement until dispatch ends; optional synchronous real checkpoints for original wave transitions; defer NEW RUN publication until its genuine request owner is bound; bounded timing metadata. This file was already untracked before the task.
3. `tests/test_runner.gd` — exactly one preload and one `46I Windows v3 publication` registration.

Added:

4. `scripts/rewards/minimal_v3_windows_storage.gd`
5. `scripts/rewards/minimal_v3_windows_storage.gd.uid` (`uid://bs46istorage`)
6. `tests/test_minimal_v3_windows.gd`
7. `tests/test_minimal_v3_windows.gd.uid` (`uid://bs46iwintest`)
8. `tests/minimal_v3_windows_process.gd`
9. `tests/minimal_v3_windows_process.gd.uid` (`uid://bs46iprocess`)
10. `docs/architecture/TASK_46I_V3_WINDOWS_PUBLICATION_COMPLETION.md`

The v1/v2/v3 codecs and semantic contracts, original capture/request helper, old Windows/browser adapters, native helper/build/diagnostics, gameplay rules, profile resources and old reports are untouched. The earlier #46I blocker report remains historical evidence; #46I-1 and this report document its resolved disposable boundary.

## 2. Architecture and expected-head protocol

The existing coordinator's `_minimal_owner` remains the only character aggregate. The new class is filesystem transport, not a second coordinator or wallet. Original commands, source ledger, receipts and full v3 cold validation authorize/verify character contents. A higher sequence, valid checksum, native exit code or caller flag does not authorize a new reward or a replacement profile.

The transport has no default production root. It accepts only a flat, explicitly selected OS-cache directory:

`%LOCALAPPDATA%/itank-storage-tests/minimal46i1_...`

The original aggregate's separate fixture/admission roots remain under its existing `minimal46c2_...` guard. No production storage root, old namespace or generation file is repurposed. NORMAL/DEV identities are supplied explicitly and checked against the source and head.

### Retained layout

```text
head.bin                          # sole authoritative descriptor
current_<full-record-SHA256>.json  # exact canonical v3 envelope
replica_<same-SHA256>.json         # byte-identical latest-state copy
writer.guard                      # zero-byte native transport guard, not a head
ownership/                        # original coordinator writer-directory guard
```

After verified maintenance there are exactly **three character-data files**. The empty native guard and technical ownership directory are not character history. During a commit, the previous selected pair and new pair, `current.pending`, `replica.pending`, `stage.bin`/`expected.bin` and repair staging can temporarily exist. Only `head.bin` selects authority. No reader selects a staged file or falls back to a previous pair. Successful maintenance removes only known obsolete SHA-named data/staging under ownership, never unrelated files or the selected pair.

The descriptor is a bounded, canonical JSON envelope containing `body` and its full SHA-256. Its body has exactly:

- `format = itank_arena_disposable_v3_windows_head`
- `layout_version = 1`, `reader_version = 3`, `record_version = 3`
- actual `profile`, `namespace`, trusted `source_digest`
- original `epoch`, monotonic `sequence`, stable original `commit_id`
- full `record_sha256` and UTF-8 `record_bytes`

This is an explicit disposable storage descriptor, not a reinterpretation or revision of snapshot v3. Existing strict JSON scanning, duplicate-key/bounds/UTF-8/canonical checks are reused. A descriptor must exactly reproduce the header derived from its fully cold-validated selected record. Head size is capped at 65,536 bytes; record limits remain the original v3 limits. Expected head comparison uses **exact canonical descriptor bytes**, not a partial token or numeric ordering.

### Ownership

The original `CharacterSaveStorage.acquire_writer()/release_writer()` guard is reused on the dedicated ownership root for the entire stage → head decision → readback → acknowledgement → maintenance interval. The native helper additionally holds its reviewed kernel handle guard while replacing the head. Actual competing process tests demonstrate exclusion; copied tokens or a new storage object are not ownership.

The legacy directory lock can survive a process death. It is not automatically deleted or stolen. A valid head/pair remains cold-readable; further writes/repairs requiring that unknown lease fail closed. The native helper's OS-released guard does not solve an older coordinator lease. This is a disclosed production-readiness limit, not an invented PID/time-based reclamation protocol.

An empty destination is recognized only when absent or genuinely empty. A used directory with a missing head never becomes a fresh character, even if both selected data files are also missing. Only the same in-memory first attempt may resume its exact unacknowledged staged pair; cold admission cannot infer an initial commit from orphan files.

## 3. Publication and actual acknowledgement

1. The original source checkpoint captures session/player/ledger together under the existing gate. Encoding occurs after the capture lease is released. Exactly one immutable pending record and issued request window remain owned by the existing helper.
2. Acquire the original writer guard and compare the exact expected acknowledged head. Fully cold-check the candidate and existing selected state, plus unchanged v3 extension semantics. Same installed candidate/commit/bytes is an exact retry, not a new transaction.
3. Write/flush/independently verify a new uniquely named current file, then its identical replica. Preserve the old selected pair. Godot rename is used **only to an absent data destination under ownership**, never to replace a head or intact acknowledged data.
4. Stage the small descriptor in the native helper's existing fixed `stage.bin`; supply exact old bytes through `expected.bin`. Recheck head/ownership before the native call.
5. Invoke the exact source-built #46I-1 executable directly. It uses the reviewed same-volume `MoveFileExW` operation and first-publication semantics. No native API or filename/context semantics were broadened.
6. Regardless of whether a native response was received, reread the actual head and selected pair, cold-validate the selected v3, verify exact equality to the owned candidate, and reread the head. The aggregate performs another owned independent readback before acknowledgement. A failed or uncertain response alone is never treated as a save.
7. Adopt only the owned pending persistence metadata/cursor/IDs. Retire its captured volatile request window only after the real storage proof. Do not reinstall an older actor, resource/RNG/Running state or replay any gameplay effect.
8. Under the same ownership, verify the selected pair again and remove only obsolete data/staging. Release ownership. Maintenance failure is reported separately from an already verified commit, without replaying its effects.

The common in-memory adoption bookkeeping is shared with the previous simulation prototype, but public simulated acknowledgement is blocked while Windows owns the aggregate. A real result is `disposable_windows_verified`, `durable:true`, with `durable_power_loss_guaranteed:false`. Here “durable” means independently verified filesystem publication surviving the tested process failures; it is not hardware power-loss certification or production persistence.

### Source boundaries and continued gameplay

Original NEXT WAVE requires a secured checkpoint synchronously before progressing and again at entry. The explicit `automatic_minimal_windows(true)` option fulfills that existing source contract through actual publication/readback. It is not enabled by attaching a route, and no playable caller selects it. Manual mode retains immutable pending bytes for diagnostics. NEW RUN waits for original bootstrap and the genuine new request owner before publishing its first pending entry.

Equipment/consumable commands must finish caching their original result and release dispatch ownership before acknowledgement. The existing after-dispatch hook performs real publication in automatic mode. No new source rules, costs or effects are introduced. Original simulator acceptance maps and all lifetime irreversible identities remain intact.

On a failed/lost storage response, the original pending operation remains uncertain and cannot be silently discarded. New gameplay can advance in its new request window. Exact retry recognizes the already installed commit and changes only persistence acknowledgement metadata. Tests explicitly advance actual external Running after the earlier capture and verify that reconciliation preserves the newer runtime and does not rerun effects.

## 4. Native dependency boundary

Reused the already source-built, reviewed #46I-1 x64 helper without changes:

- Source `tools/windows/safe_head_replace.c` SHA-256: `6b2fd81d62a099c6e39a207af4bcc76c25f9dd6151ab6ee630a0b21d70728bfd`.
- Explicit test executable: `%TEMP%/arena46i1_native/safe_head_replace.exe`.
- Executable SHA-256: `a6dac728d1bf305b3754461876eff7213d8bf3625aa52c21f8c4f46470d1ed1b`.
- Reviewed build: installed MSVC x64 `/O2 /MT /W4 /WX`, Windows SDK 10.0.26100.0, only Windows `KERNEL32.dll` imported, no bundled/custom DLL, shell, PowerShell or runtime package.

The transport verifies the supplied executable's exact identity and allowed TEMP prefix. Tests independently pass the explicit SHA through `ARENA_46I_HELPER_SHA`. The native helper still accepts only its flat dedicated test directory and fixed head/stage filenames, bounded to local fixed NTFS. Thus no native adaptation or repeat of the already-proven sentinel matrix was required. The actual head replacement/failure paths are exercised again with real compact records in this integration.

No binary was added to Git, shipped or exported. Production executable discovery, packaging/signing, arbitrary storage locations or other filesystems remain outside the task.

## 5. Crash, failure and recovery matrix

The test child cold-loads a real acknowledged v3 character, issues an actual original NAC configuration change, captures it through the genuine coordinator, writes one expected test output outside the publication directory, then publishes. Original source control fixtures live separately; they are not a hidden archive in the new route.

**Eleven actual Godot child-process self-terminations** were exercised. A closed pre-termination marker identifies the reached stage; no post-kill marker or returned-publication message may exist. Windows `OS.kill(self)` can result in exit code zero, so the test does not invent a required nonzero code. Each outcome is then checked by another fresh process performing full v3 semantic validation. This differs from an injected return/error condition.

| Controlled stage | Actual recovered authority |
| --- | --- |
| Before new pair | Exact old head/current/replica. |
| After current pending write | Exact old head/pair; staged file is not authority. |
| After current immutable name | Exact old head/pair; new current is unacknowledged. |
| After replica pending write | Exact old head/pair. |
| After replica immutable name | Exact old head/pair; higher new sequence does not select itself. |
| After descriptor staging | Exact old head/pair. |
| Immediately before native head replacement | Exact old head/pair. |
| After native return, before adapter readback/response | Exact new selected state, despite absent acknowledgement. |
| After adapter readback | Exact new selected state. |
| Before maintenance, after aggregate acknowledgement | Exact new selected state; old files do not become current. |
| After maintenance | Exact new selected pair; no old data archive remains. |

The earlier #46I-1 evidence covers 24 actual native-helper terminations before/after its native call and independent readback; those tests were not rerun or counted as new results. Neither test set claims termination at an exact instruction inside the kernel rename syscall, an OS crash, power failure or controller-cache flush proof.

Other final cases:

| Case | Result |
| --- | --- |
| Current corrupt, latest replica intact | Full cold validation of exact head-bound replica; repair current through verified staging; exact reread. |
| Replica corrupt, current intact | Intact current remains usable; repair identical replica. |
| Both latest copies corrupt | Fail closed, including recovery; no previous record is selected. |
| Head missing, including all three selected files missing in a used directory | Fail closed; no inference of virgin/new character. |
| Rehashed but conflicting sequence/profile or unsupported reader | Reject; no guessed newer/older record. |
| Actual open head blocks native replacement | Old exact acknowledged state and immutable pending identity preserved; original candidate succeeds after the blocker is released. |
| Wrong expected head for a new candidate | Reject before publication; old head intact. |
| Injected current/replica/head staging disk-full failure | Old selected pair/head remain exact; pending candidate is retained; exact retry succeeds. These are controlled I/O-failure simulations, not a physically full disk. |
| Head publication succeeds, response deliberately lost | New head is independently readable, exact old pending bytes retained; retry reconciles the same commit without replay or runtime replacement. |
| Actual second Godot writer holds original directory lease | Competing publication rejects; head remains unchanged; owner releases normally. |
| Killed writer leaves original lease | Cold exact state remains readable; writes fail closed. No automatic stale-lock reclamation claimed. |
| Cold irreversible-use replay | Original consumed ID rejects before source effects/RNG. |
| Repeated normal commits / maintenance | Only selected current, identical replica and authoritative head remain as character data. |

Repair removes only a copy already proven damaged while the head and the other exact selected copy remain intact. Godot is not asked to replace an intact selected file. A repair interruption may leave one good copy and a staged repair, but cannot justify older-state fallback. Repair with an unknown stale writer lease is blocked, not falsely reported successful.

## 6. Gameplay, progression and exact-ID acceptance

Final supported fixtures cover NORMAL x1 and eligible DEV x10, original source awards/loot/growth, real equip/unequip/stow and timed/interrupted draw, actual potion acquisition/use, terminal zero ownership, independent original simulation/events/RNG/Running and v3 current-state equivalence. Source-oracle checks compare every supported character/evidence field; no difference is normalized away in these Windows comparisons.

The historical fixture originates from the original verified disposable V2 history. Native fixed credit uses the original confirmation/eligibility contract and matches independent original credit output: exactly +10,000 EXPC, zero EXPM. Real disk acknowledgement, cold restart and NEW RUN cannot repeat it. All five actual attribute requests, DEX allocation, interleaved END/HPB/WIS growth, original dice, level/resources and later source wave transitions survive cold Windows readback.

NEW RUN first demonstrates the original `run_identity_reused` rejection from the fixture's retained global run-ID override. The successful case clears that test override and uses the **original genuine allocator**, not an invented ID or changed authorization. Original epoch, namespace and all permanent facts remain exact; a genuine new run and locked x1 policy are appended after the old DEV x10 run. The existing NORMAL policy restrictions remain unchanged and are also covered by #46H regression. No owner character or production run was used.

The separate 1,005-item fixture comes from the prior source-validated disposable archive and is independently checked by the original full V6 validator, then v3 cold validation. The unsupported historical 233-generation conversion is not fabricated or activated; #46H's missing-consumption-evidence rejection continues passing in its regression.

## 7. Focused test results

Godot **4.7.2 native Windows debug/headless**, installed official `ed1daf0bf`, Windows 11/local NTFS. Final successful logs contain no script errors, warnings or failed assertions.

| Exact suite | Count | Result / TEMP evidence |
| --- | ---: | --- |
| `46I Windows v3 publication` | 333 integration + 40 independent source-oracle assertions | PASS, `arena46i-final.log` |
| `46H v3 coordinator` | 306 | PASS, `arena46i-regression-h.log` |
| `46C2 routine transactions` | 95 | PASS, `arena46i-regression-c2-final.log` (final legacy exact-retry label preservation) |
| `46F temporary requests` | 140 | PASS, `arena46i-regression-f.log` |
| `Task 36J-Pass2 persistence coordinator` | Existing suite does not print a count | PASS, `arena46i-regression-legacy.log` |

**914 counted assertions**, plus the original coordinator suite without an invented count. #46I-1's 359 prior diagnostic assertions are reused evidence, not added to this new-run total. No full regression, export, browser or production test was run.

Command:

```powershell
$env:ARENA_46I_HELPER_SHA = (Get-FileHash -LiteralPath "$env:TEMP/arena46i1_native/safe_head_replace.exe" -Algorithm SHA256).Hash.ToLowerInvariant()
$env:ARENA_46I_SECTION = ''
& 'C:/Users/mxz/Desktop/GoDot/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/test_runner.gd -- '--suite=46I Windows v3 publication'
```

The optional `history` section was used during diagnosis to avoid repeating the crash/stress matrix. Final acceptance ran the complete suite with no section filter. Earlier failed development runs are not acceptance evidence. Corrections were limited to new transport/test integration: explicit `empty:false` read results, original consumable API/free-hand legality, genuine changed crash input instead of an unchanged NAC no-op, synchronous secured wave boundaries and NEW RUN request-owner binding. No codec, gameplay rule or original rejection was weakened.

Additional verification: parsing via the actual focused runner, exact helper identity, new UID uniqueness/whitespace and `git diff --check`. Existing CRLF advisories from unrelated accumulated work are not whitespace errors; no line-ending normalization was performed.

## 8. Native Windows measurements

Single final consolidated run, no concurrent regression processes during its measurements. Values below are individual workload observations, not release/browser guarantees. `publication` includes cold candidate/extension validation, staging, native call and its cold readback. `acknowledged save` additionally includes aggregate readback/adoption and verified maintenance. `capture → ack` is measured from the original source checkpoint start through filesystem acknowledgement/release; manual stress includes the test host's intervening state-observation overhead. These intervals overlap and must not be added together.

| Fixture | Record bytes | Prepare ms | Publication ms | Native process ms | Cold readback ms | Acknowledged save ms | Capture → ack ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| NORMAL loot checkpoint | 14,118 | 16.816 | 119.709 | 26.788 | 18.151 | 172.899 | 192.838 |
| DEV loot checkpoint | 12,790 | 15.124 | 119.289 | 26.843 | 18.043 | 171.556 | 189.820 |
| Native fixed credit | 19,006 | 24.060 | 138.056 | 30.016 | 21.525 | 199.901 | 228.011 |
| END purchase | 20,156 | 16.870 | 139.444 | 26.565 | 22.852 | 203.181 | 223.478 |
| SPD purchase after interleaved growth | 41,093 | 34.422 | 194.372 | 24.455 | 35.728 | 289.060 | 327.665 |
| Genuine NEW RUN Wave 1 publication | 41,120 | 26.548 | 201.060 | 26.986 | 36.003 | 296.402 | 329.341 |
| **Separate stress: 1,005 items** | **1,107,597** | **600.414** | **3,452.241** | **369.701** | **713.971** | **5,193.625** | **5,867.681** |

Across 32 representative nonstress checkpoint samples, excluding deliberately lost-response/fault retry cases and initial bootstraps, capture-to-ack p50 was **205.762 ms**, nearest-rank p95 **327.665 ms**, maximum **329.341 ms**. This describes this small sample/fixture sequence, not all future characters. NEW RUN's table measures its checkpoint, not its earlier quote/confirmation/entire admission UI.

Exact repair samples:

- NORMAL 18,337-byte current: **52.151 ms**; replica: **51.874 ms**.
- DEV 16,101-byte current: **50.189 ms**; replica: **50.197 ms**.
- Separate stress current: **1,438.097 ms**; replica: **1,438.765 ms**.

The final stress directory retains two 1,107,597-byte character copies plus one **598-byte head**: **2,215,792 character-data bytes**, plus technical guard/directory overhead. The 41,120-byte historical multi-run fixture retains **82,838 character-data bytes**. There is no retained generation archive. Native helper staging inputs are removed after verified maintenance.

Post-operation Godot allocator live observations across the fixture sequence ranged **190,191,714–278,474,422 bytes**, with process allocator high-water **325,841,663 bytes**. The stress preparation itself sampled 291,896,199 live bytes. These include source controls/fixtures/cold validators and are not OS RSS, per-case peak, leak evidence, Edge memory or WASM capacity. The routine record does not retain whole source histories; independent legacy test controls still exist only as test oracles outside the storage root.

The 1,005-item result exceeds the desired 1–3 second routine-save range. Full unchanged semantic checks run at several boundaries: candidate validation, current read, v3 extension validation of both sides, selected new readback, aggregate readback and maintenance. This residual work is deliberately preserved; no validation caching or framework was added to improve numbers. Native process overhead is measured separately and does not account for most of the 5.19-second stress publication/acknowledgement interval. Stress scaling and synchronous native/debug processing remain production performance limitations, not hidden acceptance claims.

## 9. Remaining limits and preservation

1. The proof is local NTFS **process-crash** behavior. Data-file Godot flush/close and head `FlushFileBuffers`/write-through do not establish hardware power-loss, OS-crash, all-filter-driver or other-filesystem durability.
2. Original unknown stale directory leases block further writes/repair after a killed writer; read-only exact-state recovery works. No unattended lock reclamation or old-writer production fencing/upgrade was invented.
3. Calls are synchronous native/headless operations. Representative timings are responsive enough for this disposable boundary; stress latency is not production accepted. No asynchronous/storage architecture rewrite is part of this pass.
4. Full cold verification stays mandatory on restart/import. No owner conversion or inferred historical irreversible evidence is permitted; old reader/format behavior is unchanged.
5. Production source packaging, actual playable control integration, portable backups, upgrades, owner acceptance and browser CAS/recovery require separate authorization. A Windows success is not proof of IndexedDB behavior.

Unchanged branch `main`, HEAD `f9bb0db0235b0003895c477a12346191d4714469`; empty index. Entry baseline under `%TEMP%/arena46i_resume__a17cg_n/baseline.json` recorded **784** scoped existing project files and **35 modified tracked / 203 collapsed untracked entries**. Only the three intended existing files above may differ; seven new paths are this task's additions. In-memory removal of the new task blocks reconstructs the exact entry hashes of the existing helper, coordinator and runner, including their original line endings; no disk revert occurred.

`project.godot` retains SHA-256 `8398f110f77d7712eb19c283eb9f745c7123feab9557187778da412639ba5692`. Protected boss documents, `character saves/` and repository `tmp/` were observed only as Git status names; their contents were not read/hashed/modified. No owner save, backup or production browser storage was accessed. All mutable fixture, expected-output and crash files are dedicated OS-cache test data. No Git mutation, export, production activation, Roadmap/Combat Specification edit or #45U resumption occurred.

**GO for separately authorized disposable Edge/IndexedDB integration. STOP after this task. Production activation remains NO-GO pending its own storage/upgrade, latency, durability and owner acceptance work.**

## Exact final Git status

Final preservation: **781 of 784 baseline files byte-identical**; the other three are precisely the approved integration/helper/runner changes. No baseline files missing. **35 modified tracked / 210 collapsed untracked entries**.

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
?? docs/architecture/TASK_46E_COMMAND_RETENTION_AUDIT.md
?? docs/architecture/TASK_46F_STALE_REQUEST_RETIREMENT.md
?? docs/architecture/TASK_46G_COMPACT_SNAPSHOT_V3.md
?? docs/architecture/TASK_46H_V3_COORDINATOR_INTEGRATION.md
?? docs/architecture/TASK_46I1_WINDOWS_SAFE_REPLACEMENT.md
?? docs/architecture/TASK_46I_V3_WINDOWS_PUBLICATION.md
?? docs/architecture/TASK_46I_V3_WINDOWS_PUBLICATION_COMPLETION.md
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
?? scripts/rewards/minimal_character_snapshot_v3.gd
?? scripts/rewards/minimal_character_snapshot_v3.gd.uid
?? scripts/rewards/minimal_character_transactions.gd
?? scripts/rewards/minimal_character_transactions.gd.uid
?? scripts/rewards/minimal_v3_windows_storage.gd
?? scripts/rewards/minimal_v3_windows_storage.gd.uid
?? scripts/rewards/snapshot_command_evidence.gd
?? scripts/rewards/snapshot_command_evidence.gd.uid
?? scripts/rewards/temporary_character_requests.gd
?? scripts/rewards/temporary_character_requests.gd.uid
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
?? tests/minimal_snapshot_v3_cold_process.gd
?? tests/minimal_snapshot_v3_cold_process.gd.uid
?? tests/minimal_v3_transactions_cold_process.gd
?? tests/minimal_v3_transactions_cold_process.gd.uid
?? tests/minimal_v3_windows_primitive_probe.gd
?? tests/minimal_v3_windows_primitive_probe.gd.uid
?? tests/minimal_v3_windows_process.gd
?? tests/minimal_v3_windows_process.gd.uid
?? tests/oracles/
?? tests/profile_compact_v6.py
?? tests/profile_compact_v6_costs.py
?? tests/profile_compact_v6_reuse.py
?? tests/temporary_requests_cold_process.gd
?? tests/temporary_requests_cold_process.gd.uid
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
?? tests/test_minimal_character_snapshot_v3.gd
?? tests/test_minimal_character_snapshot_v3.gd.uid
?? tests/test_minimal_character_transactions.gd
?? tests/test_minimal_character_transactions.gd.uid
?? tests/test_minimal_v3_transactions.gd
?? tests/test_minimal_v3_transactions.gd.uid
?? tests/test_minimal_v3_windows.gd
?? tests/test_minimal_v3_windows.gd.uid
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
?? tests/test_temporary_character_requests.gd
?? tests/test_temporary_character_requests.gd.uid
?? tests/test_windows_safe_head_replace.py
?? tests/windows_safe_head_bridge_smoke.gd
?? tests/windows_safe_head_bridge_smoke.gd.uid
?? tmp/
?? tools/
```
