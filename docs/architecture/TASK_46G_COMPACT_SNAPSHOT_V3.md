# Task #46G — Compact character snapshot v3

2026-11-19. **Complete: isolated dormant codec and focused tests only.** No playable admission, coordinator routing, storage, backup, migration or retirement implementation. #45U remains paused.

## 1. Exact task manifest

Added:

1. `scripts/rewards/minimal_character_snapshot_v3.gd`
2. `scripts/rewards/minimal_character_snapshot_v3.gd.uid`
3. `tests/test_minimal_character_snapshot_v3.gd`
4. `tests/test_minimal_character_snapshot_v3.gd.uid`
5. `tests/minimal_snapshot_v3_cold_process.gd`
6. `tests/minimal_snapshot_v3_cold_process.gd.uid`
7. `docs/architecture/TASK_46G_COMPACT_SNAPSHOT_V3.md`

Modified:

8. `tests/test_runner.gd` — exactly one preload and one `46G compact snapshot v3` suite registration. Prior bytes/registrations are preserved.

No existing codec, validator, gameplay script, coordinator, capture gate, request helper, source resource, UI, save route or configuration was changed. This manifest is the task delta, not the accumulated working-tree diff from HEAD.

## 2. Audit and supported trust boundary

Read #46A, #46B, #46C2, #46D, #46E and #46F. Inspected the actual v1/v2/V6 codecs, original progression/credit/receipt/ownership/checkpoint helpers, current partial aggregate, source command paths, development allocations and request retirement implementation.

The v1/v2 operation list is tied to generation count and retains every checkpoint. V2 additionally replays lifetime equipment/handling/temporary potion effects. Neither contract can be pruned under its original version. V3 is separate; old readers and validators remain byte-identical and continue rejecting v3.

This follows the approved local trusted-gameplay model. Original APIs authorize new effects; cold validation checks self-contained source rules, original facts, accounting, conservation and current-state consistency. A local checksum is not authentication that a battle occurred or owner consent was given. For example, a coherently renamed opaque consumption ID can pass standalone local semantics; comparison with an already admitted immutable prefix rejects reassignment. Tests demonstrate that distinction explicitly.

## 3. Explicit record contract

Domain **`itank_arena_character_snapshot`**, **version 3 / reader version 3**. Version 3 was not implemented in this domain before this task. Separate v1/v2 readers retain their original semantics. The v3 reader accepts only v3; it neither upgrades nor silently delegates old files.

The canonical JSON envelope has exactly `format`, `version`, `reader_version`, `body_json`, `sha256`. SHA-256 binds the exact canonical UTF-8 body. Original strict JSON scanning, duplicate-key rejection, UTF-8 checking, safe numbers and limits are reused without modifying them.

The body has exactly:

| Field | Meaning |
| --- | --- |
| `epoch` | Original character epoch, bounded to 256 characters. NEW RUN does not create a new character epoch. |
| `sequence` | Positive monotonic commit ordinal, equal to `current.generation`. It is independent of retained history length. |
| `last_operation_id` | Stable original current commit/operation ID. It is not executable request authority. |
| `source_digest` | Full trusted authored-source fingerprint. |
| `current` | One complete current state in the v3 representation below. |
| `evidence` | Original essential progression/ownership facts, not a general gameplay transcript. |
| `recent_journal` | Exactly the final min(20, sequence) summaries, each containing `sequence`, original `id`, original `request_digest`. Sequences are contiguous and the last ID must match the header. |

There is **no** `operations`, `lifetime_ids`, `command_evidence`, receipt chain, previous-character snapshot, ancestry capsule, recursive credit predecessor or durable retirement/context flag.

### Current state

Retain original profile/namespace/definition/rules/lineage, immutable starting attributes, permanent level/resource maxima/allowances/XP baseline, current equipment references and quantities, authoritative XP balances, run history/policy, completed wave identity markers, current hands/posture and the existing legal checkpoint.

`current.items` is the **single complete terminal ownership list**, including zero-quantity instances. A zero row must have no equipped slots or mutable condition. Positive rows retain current quantities, equipped slots and supported condition. The cold rule adapter constructs a temporary positive-only legacy item view and matching `profile_ownership` for the unchanged original validators; these are not duplicated durable lists.

The checkpoint keeps existing version-1/schema-12 safe-boundary semantics: entry, downtime or complete, including RNG, clock, current HPC/resources, Mana remainder, Running profile/state/RNG, fatigue, cooldowns, movement and existing timers/status. It does not invent active mid-wave recovery.

Its ledger retains current scalar accounting/policy/wave state, current-run processed actor identities and next world-item sequence. Mirrored `awards`, `drop_resolutions`, `purchase_records`, processed defeat-event/purchase IDs, collected world-item IDs and duplicate `profile_ownership` are omitted. Lifetime semantic membership instead comes from essential evidence. No old run's combat/event log is retained.

Permanent DEX/allocation commands stay in original order with original IDs/payloads. At most **one original latest defense-preference command** represents current preferences; previous temporary preference changes are not lifetime evidence. Its original ID is retained as current-state data, never synthesized. The required checkpoint development mirror matches this bounded representation. Original allocation and preference validators still check the resulting state. Comparison preserves permanent command prefixes while allowing current preferences to change.

### Essential evidence

Exactly `awards`, `purchases`, `growth`, `settlements`, `credit`, `order`, `item_debits`:

- Awards retain exact original XP IDs/amounts and source-bound run/wave/defeat receipt bindings.
- Purchases retain original IDs, costs, before/after values, DEX choices and source references for all five attributes and already supported resistance purchases.
- Growth retains original HD sides/flat bonuses/dice, event-time HPB/WIS and HPM/Mana before/after arithmetic. `order` preserves original award/purchase/growth/fixed-credit chronology. Event-time END witnesses are derived from this source-backed order, never from final END alone or an imported proof flag.
- Settlements retain original reward/purchase/acquisition identity and provenance facts once. These original facts are not W/X/Y cryptographic ancestry receipts.
- `credit` retains the original fixed grant record, including exact target, amount, grant ID and original predecessor-generation/digest reference. No predecessor character is embedded or reconstructed. The original fixed-credit inspection and chronological EXPC accounting are reused; a record does not grant publication permission.
- Each compact debit has exactly `run_id`, `request_id`, `event_id`, `kind`, `definition_id`, `selection`. Each selection has original `instance_id` and positive `quantity`. The original accepted request and resolved effect IDs come from actual source events/actions. No healing dice, historical HPC/Mana trajectory, action duration or equip/stow/draw trace is retained.

Currently the only supported debit kind is `consume`, for an original catalog-verified consumable and exactly one total unit. Other loss/destruction/hazard sources return **`snapshot_v3_unsupported_loss_source`**. No generic loss rule or missing source authority is invented. Shield condition uses the unchanged current-condition validator; a claimed quantity loss cannot be disguised as shield wear.

### Limits and exact membership

Inherit 16 MiB body / 24 MiB encoded file, 1 MiB individual strings, 50,000 collection entries, 500,000 total values, depth 48 and safe JSON numeric bounds. Field-specific identities remain bounded. Excessive input fails rather than truncating history. Essential lifetime data still grows; this is not an infinite-history or constant-size claim.

Cold admission reconstructs an exact in-memory `(scope, full ID)` map and full immutable binding from explicit facts: awards, purchases, growth, settlements, acquisition origins, fixed credits, permanent development and run policies. Consumptions have separate exact `(run ID, original request ID)` and `(run ID, original resolved event ID)` membership. Reusing an effect under a different wrapper or changing its binding rejects. The map is **not serialized**. Journal eviction never evicts irreversible identities.

`Record.transaction()` distinguishes unseen IDs from duplicate/conflicting bindings. Unseen membership is not action authorization. Record views return copied dictionaries or immutable text, and no API accepts a caller-created Record/context/verified flag as executable authority.

## 4. Cold verification and comparison

The v3 verifier performs structural/canonical checks, then reuses unchanged helpers:

| Invariant | Original helper / v3-specific addition |
| --- | --- |
| Source/profile/rules and current shape | Trusted source digest, `profile_identity()`, strict v3 fields, original contract/hydration |
| Reward amounts, causal identities and policy | Original receipt and playable XP-award validation; exact original run/wave/defeat bindings; current ledger multiplier/wave XP/balance agreement |
| Five attributes, affordability and growth | Original V6 `_chronology()` plus original advancement/growth functions; original `_accounting()` and `Profiles.hydrate()` |
| Fixed credits | Original `Credit.inspect()`, original essential credit order and EXPC-only arithmetic; no credit operation is executed |
| Ownership and equipment | Original terminal ownership, acquisition, source catalog, armor/hands/shield and inventory validators |
| Conservation | Source starter receipts must match exact authored starter receipts. Gameplay origins must belong to actual retained runs. Initial quantity minus exact supported debits must equal each terminal quantity, including zero. Every origin requires its terminal row. |
| Checkpoint | Original actor-aware checkpoint and Running validation; exact current resource/maxima/policy/progression consistency |
| Lifetime duplicate protection | Exact scoped map rebuilt from the validated essential facts; no approximate hashes or final-balance inference |

The source starter scope is `starter_admission`, distinct from an Arena run. It is checked against the actual authored starter, not accepted as an arbitrary run or allowed as a consumption run.

`validate_extension()` is a **pure comparison**, not save/restore permission. Both inputs undergo full cold validation. It requires exact retry or a single forward sequence with a new commit ID, unchanged identity and retained journal bindings, immutable essential/permanent-allocation prefixes, immutable old run/policy bindings and original credit continuity. Older/same-sequence conflicting states reject. There is no CAS, disk head or occupied-profile restore authority here.

## 5. Multi-run and historical support

Original source-authorized NEW RUN tests retain character epoch, namespace, progression, purchases, receipts, item origins and consumptions while appending genuine run IDs and immutable policies. Legacy namespace-derived policies remain valid where originally applicable; new V4-style run entries retain their explicit multipliers. Actual DEV ×10 followed by a new ×1 run and NORMAL ×1 continuation are covered. Same raw use IDs in distinct genuine runs are separately scoped, not relabeled old requests.

Original legacy resume supplies a positive-only item view in some paths. Tests explicitly show that this alone is insufficient for v3 when earlier acquisitions were exhausted. They carry forward **actual previously verified zero rows** plus original resolved consumption facts from the earlier current state. These rows still undergo origin/provenance/conservation checks. No original source records are changed, and no missing request ID or zero quantity is inferred. The existing dormant #46C2 already restores its service's full terminal ownership explicitly; future integration must retain that invariant.

The selected disposable converted 233-generation fixture lacks original resolved consumption IDs. It rejects with **`snapshot_v3_item_conservation`** when supplied without those facts. Its valid V6 status does not invent the absent evidence. Historical V2/V4 fixtures with complete available essential facts, and independently verified historical/native fixed-credit fixtures, do validate. There is no automatic conversion/migration API or owner-character operation in this pass.

## 6. Request-retirement dependency and integration blockers

#46F proves only the dormant trusted in-process ownership boundary and **simulated**, nondurable acknowledgement/reconciliation. V3 does not serialize an executable context or claim that its sequence/journal retires old live requests. No original simulator acceptance map, history or ID was pruned.

A separately approved dormant #46C2 pass must replace its v1 assumptions about `operations` and duplicated ID tables, capture actual resolved irreversible source facts before losing them, retain full terminal ownership and bind the original issued request/gate lifecycle. #46F and the current partial aggregate deliberately remain separate admission routes; a preload swap alone is insufficient.

Before real storage/retirement, separately specify and test exact pending bytes/ownership, expected head/CAS, current-state replica, atomic acknowledged retirement binding and persisted readback. Pending/uncertain work must not disappear on cancellation/reload. Neither this record nor its comparison API permits installing an older checkpoint or restoring over an occupied profile.

Unknown loss sources, missing irreversible command evidence, unsupported historical conversions or incomplete source chronology remain explicit rejection/stop conditions. No fallback to invented facts, old checkpoints or silent fresh-start migration is authorized.

## 7. Focused results and measurements

Godot **4.7.2 native Windows debug/headless**:

| Suite | Assertions | Result | Own TEMP log |
| --- | ---: | --- | --- |
| `46G compact snapshot v3` | 445 | PASS | `arena46g-verified.log` |
| `46B minimal snapshot` | 227 | PASS | `arena46g-v1.log` |
| `46D command evidence` | 174 | PASS | `arena46g-v2.log` |
| `46F temporary requests` | 140 | PASS | `arena46g-retirement.log` |

**4/4 suites, 986 assertions PASS; zero final failures.**

Exact command pattern, once for each listed filter in the final verification:

```powershell
& 'C:/Users/mxz/Desktop/GoDot/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/test_runner.gd -- '--suite=<suite from table>'
```

Additional checks: `--check-only` on the new codec and cold-process script; `git diff --check`; direct whitespace checks on new files; uniqueness of all three new UIDs. All pass. Git emits the existing CRLF conversion advisories for playable persistence and the runner, without whitespace errors. No normalization of those files was performed.

Tests use actual original equip/unequip/stow, acquisitions, downtime/active potion effects and interrupted no-effect requests. They compare full original current projections, source-authorized actor hydration, original V6 validation, retained progression and complete source simulation/RNG before/after. Independent fresh-process cold validation checks canonical bytes, exact expected current projection and old consumption membership. Byte re-encoding and independent original source verification are required, not a cached trust flag.

Coverage includes NORMAL/DEV, both run policies, multiple real runs, all five actual purchases, chronological END/HPB/WIS growth, both existing fixed-credit forms, currency/shield/current resources, terminal zero ownership, journal eviction, unchanged old readers, malformed/truncated/noncanonical/oversized/invalid-UTF-8/duplicate-key files, source/namespace mismatch, conflicting/reused use/effect IDs, forged quantities/rewards/credits/prices/dice/growth, missing evidence, invalid RNG/Running/Mana remainder and stale/rebound extension comparisons.

Development runs caught a test-assembly StringName key, the distinct starter-admission origin scope, an unaffordable extra fixture purchase, positive-only legacy resume ownership and an already-stowed source control. These were corrected in new code/test assembly without weakening an existing assertion or changing source rules. Invalid operations are not counted as expected successes.

### Measured final codec samples

One sample per named fixture in the final run; these are not p50/p95 estimates. Encode includes full cold validation. Decode includes strict parsing, checksum/canonical checks and full cold validation. Source gameplay, one-time legacy validation/conversion and filesystem publication are outside these timings.

| Fixture | Portable codec bytes | Cold validation ms | Encode ms | Decode ms |
| --- | ---: | ---: | ---: | ---: |
| Fresh NORMAL, 5 items | 9,464 | 7.421 | 8.268 | 11.758 |
| Fresh DEV, 5 items | 9,450 | 7.333 | 7.883 | 11.872 |
| NORMAL, consumed/zero items, 33 original checkpoints | 20,675 | 9.767 | 10.190 | 22.467 |
| DEV, active resolved use + interruption | 30,962 | 12.643 | 24.165 | 42.491 |
| NORMAL second run with retained uses | 31,094 | 12.824 | 13.105 | 24.338 |
| DEV second run with retained uses | 30,843 | 12.768 | 13.212 | 24.773 |
| Historical V2 | 18,303 | 128.188 | 128.029 | 135.835 |
| Historical V4/multiple runs | 20,244 | 128.416 | 128.738 | 137.957 |
| Original native fixed credit | 18,838 | 127.718 | 129.164 | 136.214 |
| Original historical fixed credit | 18,838 | 127.822 | 128.507 | 135.061 |
| All five attributes/interleaved growth | 40,513 | 17.195 | 17.350 | 31.797 |
| Same character after 24 preference checkpoints | 41,095 | 17.402 | 17.778 | 32.685 |
| **Separate stress: 1,005 actual item instances** | **1,107,466** | **444.013** | **452.105** | **821.019** |

The all-five record moves from original generation 18 to 42 without retaining another 24 operations or preferences: v3 retains 20 summaries and one original current preference. The encoded-size difference also includes those bounded summaries and current metadata; it is not a claim of zero growth from future essential facts. The 1,005-item fixture is the explicitly selected existing disposable stress record, not whitespace padding. Realistic gameplay fixtures have 5–13 terminal items.

Measured Godot allocator net live deltas across validation/encoding/decoding while retaining the returned records were roughly 319 KB fresh, 1.43–1.44 MB all-five and 34.70 MB stress. The sampled process allocator high-water mark was 302,164,401 bytes across the fixture sequence, including original validators/fixtures. This is **not** per-case OS RSS, a leak measurement, WASM capacity or Edge memory. No release/browser timings, complete save latency, storage durability or performance acceptance is claimed. Full cold CPU/memory still scales with essential facts; imported maximum-size browser behavior requires later isolated testing.

## 8. Workspace and owner-data preservation

Branch `main`, unchanged HEAD `f9bb0db0235b0003895c477a12346191d4714469`, empty index. Entry status: **35 modified tracked / 183 collapsed untracked entries**. Final status: **35 modified tracked / 190 collapsed untracked entries**, reflecting seven added files and the already-modified runner.

Of 763 baseline scoped project files, **762 remain byte-identical**; the only existing-file delta is the runner's two intended lines. Removing those lines in memory reproduces its entry SHA-256 `e4b2efe3481cc8f889d6901ec2553618597d168467f60184b560990e00c3e9cf`. No disk revert occurred. All v1/v2/V6 validators, #46C2, #46D–F, earlier #45 work, reports and benchmarks remain intact. `project.godot` retains its pre-existing change and entry SHA-256 `8398f110f77d7712eb19c283eb9f745c7123feab9557187778da412639ba5692`.

Protected boss DOC, `character saves/` and repository `tmp/` were seen only as unchanged Git status names; their contents were not read, hashed or modified. No owner profile, backup or production browser storage was accessed. Original source fixtures use unique OS-cache `snapshot46g_...` test roots or the explicitly selected prior disposable cache fixtures. No full regression, Web export, storage activation, Git mutation or #45U resumption occurred.

**GO for integrating v3 into the dormant #46C2 coordinator in a separately approved, supported-evidence pass.** This is not approval for playable/storage activation, history deletion, durable request retirement, owner conversion or an automatic next task. Missing facts and the integration boundaries above must continue to fail closed.
