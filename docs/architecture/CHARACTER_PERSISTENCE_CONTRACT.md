# Task 36D: proposed character persistence contract

Task 36E adds a separate, isolated desktop storage coordinator and fault fixtures; see `CHARACTER_STORAGE_INFRASTRUCTURE.md`. This supersedes only the statement that no storage adapter exists. No gameplay writer/loader or permanent progression is enabled. Web writes remain explicitly gated.

Status: architecture and isolated in-memory validation only. No gameplay caller, disk writer, loader, save button or automatic retention is enabled. Schema-12 combat snapshots, replay and synchronization remain unchanged.

## Boundaries and audit

`CombatActorDefinition` owns source identity, attributes, base/derived stats, resource maxima and immutable starting loadout records. `CombatActorState` owns current resources, quantities, equipment, hands, conditions, effects, action clocks and position. `ArenaRewardLedger` owns earned/spent XP, purchases and processed within-run reward IDs. RESET currently reconstructs the selected fixture and clears temporary rewards/advancements/items. NEXT WAVE retains the existing actor and simulation.

These are not interchangeable save formats. A combat snapshot is an exact encounter/replay record; loading it as permanent progression could restore enemies, RNG, old rewards and consumed items. The proposed character record contains no combat clock, RNG, actions, position, ground loot or TEST MODE state.

## Character envelope v1

`character_save_contract.gd` defines `format=itank_arena_character`, `version=1`, `payload_json` and SHA-256 of that exact UTF-8 JSON string. SHA-256 detects accidental corruption; it is not authentication or protection against local editing.

Payload fields:

| Field | Contract |
| --- | --- |
| character_id | Stable independent profile identity; never the shared combat actor ID `player` |
| definition_id, rules_revision | Source character/catalog identity and explicit rules revision |
| generation | Positive sequential revision used for compare-and-swap replacement |
| base_attributes | Source baseline attributes; purchased changes are separate |
| xp | Integer earned, spent and unspent; unspent equals earned minus spent |
| purchases | Immutable records with unique purchase_id; later adapter must retain source, cost, before/after, run and causal event and validate against the advancement catalog |
| items | Unique instance_id, definition_id, quantity, provenance, equipped_slots and mutable_state (including SHP where applicable) |
| secured_checkpoints | Unique run/wave transaction keys already incorporated into this profile |

Equipped items have quantity one and reserve exclusive slot keys; a two-hand weapon reserves both hands in one instance record. Inventory/equipment are views of that record, not two copies. Incomplete definitions retain provenance and blocked capability status. Creature-specific weapon properties must not be silently generalized to other owners. Quantity-only current inventory cannot yet supply complete instance ownership or damaged shield storage: a provenance-preserving instance adapter is required before production saving.

The validator checks structural invariants and corruption. It does not authorize catalog legality, purchase costs or retention: a future source-aware projection must validate those independently. JSON integer fields are bounded to the exactly representable range through 2^53-1; identifiers remain strings. Temporary fields and unknown top-level keys are rejected. No snapshot-to-profile conversion is currently supplied.

## Saving and retention authority

Existing owner decisions from Task 35B already require securing earned progression after each completed wave and after legal progression/equipment changes; later death does not erase previously secured progression. Wave 5 completion retains secured progression. A new run begins at Wave 1 with current character resource maxima. Multiple profiles must remain independent; fixture RESET must never delete a permanent profile.

Proposed writer eligibility: NORMAL authority only, verified completed-wave downtime or a legal explicit progression transaction, no unresolved operation, and approved retention policy. TEST MODE cannot mint a profile, publish checkpoints or merge fixture rewards. Failed/incomplete runs must not promote uncompleted-wave rewards. Saving must replace a complete validated profile once, never replay XP awards or merge quantities from an old snapshot. Use globally unique run IDs plus wave checkpoint IDs and durable purchase IDs; current actor/event IDs restart between runs and are insufficient alone.

Owner decisions still required before enabling a writer:

- Which possessions, consumables consumed, equipment damage/loss and injuries are secured on failure after the last completed wave? Do post-checkpoint consumption and equipment changes commit immediately during active combat, or only at an approved boundary?
- How should an abandoned/crashed active run be handled: resume it, abandon it, or prevent new runs until resolved? A profile-only save cannot safely provide crash-resume without a separate run journal.
- What happens to uncollected battlefield loot at completion/failure? No automatic collection or reward promotion is assumed.
- Active Specials and the midnight clock across run creation still require explicit policy. Task 36I resolves the new-run daily-use refill only, as documented below.

Do not enable saving until these are resolved. Effect durations paused during downtime remain an in-run rule, not permission to persist effects across runs.

### Task 36I owner-approved future NEW RUN — KEEP CHARACTER (document only)

After defeat, an explicitly requested new run starts Wave 1 and restores HPC, Mana, shared AP, applicable Blood, and each daily ability allowance to their current applicable maxima exactly once. Retain level, attributes, EXPM, EXPC, purchased improvements, learned Specials, equipment, possessions, Gold and other permanent progression. No XP, currency, item or progression death penalties apply. This is an owner-approved Arena adaptation, not a printed Prime rule. It does not authorize retaining unsupported active effects or resolving abandoned-run/checkpoint duplication implicitly.

NEXT WAVE never refills these resources. Fixture RESET is separate and must never delete saved progression. NEW RUN, character persistence wiring and cross-run retention remain unimplemented; no save/load or resource behavior changes in Task 36I.

## Local storage plan (not implemented)

Desktop: use Godot `user://` in a future storage adapter. Single writer per profile. Validate expected generation, serialize a complete candidate, write a temporary sibling file, check open/write errors, flush/close, reread and validate checksum and contract, then rename within the same directory where atomic replacement is supported. Retain the prior valid generation as backup; do not delete the last valid file before replacement. Report failure without acknowledging a secured reward. Rename and flush are not a universal power-loss durability guarantee; validate actual target filesystem behavior. On startup validate primary/backup independently, refuse unsupported versions, and report corruption rather than resetting to a blank character. A backup recovery may be older: never silently replay awards to compensate.

Web: `user://` uses browser-backed persistence (IndexedDB). Availability, quota, private browsing, eviction, origin changes and asynchronous synchronization can prevent durability. A filesystem write/rename or `OS.is_userfs_persistent()` alone does not prove IndexedDB commit completion. A future Web adapter must confirm the actual storage synchronization result before reporting saved, handle failure visibly, and serialize writes across tabs or reject conflicting generations. Browser storage is per origin/device and is not an off-device backup. Same-directory rename does not establish a browser power-loss atomicity guarantee. Do not introduce tokens, accounts or a backend.

Official references: [Godot FileAccess](https://docs.godotengine.org/en/stable/classes/class_fileaccess.html), [Web export persistence](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html#using-persistent-user-data). Platform behavior remains subject to installed Godot 4.7.2 runtime acceptance; no storage implementation is claimed by this task.

## Migration, rollback and duplicate prevention

Character format v1 is separate from simulation schema 12. Unknown older/future versions fail closed. Future migrations must be explicit sequential pure transforms, preserve the original bytes/backup, validate before and after, and never reroll rewards, infer missing equipment or mint new items. Missing provenance requires a gate. Pin catalog/rules revision; a new catalog cannot silently reinterpret saved stats. Contract validation must precede runtime Resource instantiation; do not deserialize executable Resources from save input.

`validate_replacement` tests identity, sequential generation and retained checkpoint keys. It is an in-memory precondition, not a cross-process lock or durable exactly-once guarantee. The future storage coordinator must perform compare-and-swap under one writer and atomically persist state plus checkpoint receipt. Loading replaces state without re-awarding records. Rollback/tamper prevention across copied local files cannot be guaranteed without an external authority; no such service is in scope.

## Next bounded implementation and home testing

After owner retention approval: build the source-aware profile projection and item-instance adapter first, with no save UI; validate resource-loss policy, immutable purchases and checkpoint receipts. Then implement isolated desktop/Web storage adapters with injected test roots and crash/fault tests. Only after those pass should NORMAL checkpoint persistence be wired. Keep active-run resume separate.

Task 36D tests are entirely in memory and touch no live save location. They cover roundtrip/provenance/SHP, deterministic serialization, malformed/truncated JSON, checksum failure, future version rejection, XP mismatch, duplicate items/purchases, stale generations and checkpoint removal. Existing reward/inventory/replay/client tests remain the combat authority evidence.

Future home checks: browser storage denial/quota/private mode, two tabs, close during synchronization, corrupted primary with valid backup, wrong rules version, independent profiles, and restart after consumption/checkpoint. These are planned storage acceptance tests, not completed browser verification. Tasks 36A-C browser acceptance still requires a fresh local Web export.
