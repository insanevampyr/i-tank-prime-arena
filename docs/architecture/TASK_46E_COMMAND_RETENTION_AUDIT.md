# Task #46E — Command retention audit

2026-11-19. **Read-only audit and design recommendation. This is the only file created or changed.** No #46C2 implementation resumed; no format, validator, gameplay, storage or test changes. #45U remains paused.

## 1. Decision

**Do not promote snapshot v2's lifetime command replay into the routine-save architecture.** #46D correctly demonstrated exact request membership under the existing opaque-string APIs, but retained substantially more history than a sustainable current-character save needs.

Recommended distinction:

- **KEEP** original permanent progression facts, immutable acquisition/ownership origins, irreversible consumption/loss facts and their exact semantic IDs/bindings.
- **BOUND** temporary equipment/handling requests, interrupted/no-effect attempts, detailed action traces and generic checkpoint retry results to their actual pending/current request lifetime and approximately 20 small recent summaries.
- **REMOVE from the proposed successor's lifetime record** historical equip/unequip/stow/draw before/after snapshots, temporary healing traces, general event timing and full checkpoint-operation history.

**Do not remove anything from current v1/v2 now.** Their validators require these fields and their live source APIs do not provide a sufficient expiration fence. Safe expiration must be established first. “It was saved,” “it is old,” and “it left the recent journal” are not expiration proofs.

This recommendation changes the future retention contract explicitly. Existing formats and all their checks must retain their original semantics.

## 2. Verified implementation findings

Read #46A, #46B, #46C2 and #46D and inspected the actual source. Source findings below are current; earlier assertion/timing reports were not rerun. Size measurements in section 8 are new read-only byte accounting of known disposable #46D artifacts, not owner data or performance benchmarks.

| Source | Verified behavior and implication |
| --- | --- |
| `snapshot_command_evidence.gd:5`, `:21`, `:30` | A lifetime `facts` array capped at 8,192, a `creation_to_checkpoint` coverage claim and an extractor requiring complete uninterrupted first-run events. The cap eventually rejects growth; it does not bound a rolling history. |
| `snapshot_command_evidence.gd:115` | Reconstructs ownership from the source starter, applies acquisitions and every retained command, then compares terminal ownership/equipment. Consequently simply deleting neutral command pairs is invalid under v2. |
| `snapshot_command_evidence.gd:93`, `:187`, `:213`, `:241`, `:256` | Replays progression prefixes, action timing, equipment, handling and potion details. This is a replay of an item-command history, even though it omits most combat events. |
| `minimal_character_snapshot_v2.gd:10`, `:20`, `:58` | Every non-acquisition fact creates an exact `item_command` ID/digest row. Both the full fact prefix and existing ID bindings are immutable. Lookup currently copies/parses the full record and scans the ID array; the 20-entry journal does not bound this work. |
| `minimal_character_snapshot.gd:134`, `:140` | `operations.size() == sequence == current.generation`; the recent journal is only the last 20 elements of a still-retained complete operation array. Every ordinary checkpoint therefore also leaves lifetime rows. |
| `compact_character_v6_prototype.gd:272` | `_ids()` adds operation, award, purchase, growth, settlement, item-origin, credit, development and run IDs. `lifetime_ids` repeats identities/digests already represented by source facts. Exact lookup is necessary; a second durable copy of every lookup row is not inherently necessary. |
| `combat_simulation.gd:369`, `:1355`, `:1458`, `:1587` | Accepted requests are protected by `_accepted_request_ids.has(request_id)`. These APIs accept raw string IDs, without a mandatory admitted-character/request-context/expected-revision envelope. Forgetting a previously accepted raw ID can make it eligible again when state allows the operation. |
| `arena_combat_session.gd:1288`–`:1391`, `:4525` | Explicit IDs are accepted; fallback IDs are `task14_<kind>_<counter>`. The counter resets during session reset and is restored from `CharacterWaveCheckpoint.request_sequence` on recovery. A counter value is not a complete lifetime acceptance set or a cross-run identity. |
| `playable_character_persistence.gd:_open_existing_verified()` | A new run allocates another run ID, preserves the profile/history and binds its policy. Current v2 command validation instead requires exactly one run and extension validation prohibits changing that run. It is not a multi-run save format as implemented. |
| `prime_v3_inventory_catalog.gd:get_verified_consumable()` | The currently supported potion effects change HPC or Mana Current and consume one carried unit. Their healing dice are temporary-resource history; their quantity expenditure is irreversible ownership evidence. No permanent-stat potion effect is established by this catalog. |

Current v2 also requires full reconstructed terminal condition/quantity equality. Independent wear/destruction not described by its command facts can fail closed. Adding an ever-growing transcript of all shield Blocks would extend the same problem. Persist current condition and essential irreversible retirement/loss evidence instead; retain original wear rules at their actual mutation boundary.

## 3. KEEP / BOUND / REMOVE by event type

These classifications describe the **proposed successor**, not permission to prune an existing v2 file. BOUND includes a request's entire unresolved lifetime; it is not a timer that can silently expire pending work.

| Retained v2 fact | Classification | Permanent evidence actually needed | Detail to bound/remove |
| --- | --- | --- | --- |
| `ground_loot_collected` | KEEP origin; REMOVE extra lifetime replay wrapper | Original immutable acquisition ID, item identity, initial quantity, owner/provenance and necessary source/reward binding | A second chronological “collection happened here” wrapper is unnecessary once the authoritative acquisition fact carries that evidence. A collection request may cover several origins; preserve their distinct identities. |
| `downtime_equipment_changed` | BOUND request; current state KEEP | Current equipped instance/slots, carried quantities, hand state and condition. The operation conserves owned quantities. | Lifetime equipment/inventory/modifier before/after arrays and every old equip request are not permanent progression evidence. Reject delayed old requests through context retirement before forgetting them. |
| `weapon_handling_changed` — stow/draw/hold/regrip | BOUND request; current posture KEEP | The current valid hand assignment/handling mode and any source-specific current-state warrant actually necessary | A lifetime sequence of all prior postures, Acts and start/completion references is unnecessary. Drawing consumes time; current timing/checkpoint state preserves its consequences. |
| `downtime_consumable_used` | KEEP minimal irreversible spend + exact ID | Original resolved-use ID, run/profile scope, definition/rule identity, exact instance selections and quantity debits | Historical HPC/Mana before/after, maximum, dice, draw indices and paused-clock details are not needed forever to prove item expenditure. They remain available while pending/recent if needed. |
| `consumable_healing_resolved` | KEEP minimal spend + exact ID | Same ownership debit and original accepted request binding, linked to its resolved use | Old action/declaration/completion trace and temporary healing calculation are not lifetime progression. Never replay the old heal on reload. |
| `consumable_mana_resolved` | KEEP minimal spend + exact ID | Same as healing; preserve the Mana-potion definition and quantity meaning | Historical restored Mana and its dice are temporary-resource detail. Do not confuse them with permanent WIS/Mana-Max or level-growth evidence. |
| `action_interrupted` for the supported draw/potion actions | BOUND accepted ID/outcome | Current elapsed timing/resources/RNG; any separate irreversible effect that actually occurred | These cases do not consume a potion or grant progression. Their accepted IDs are needed while retry/callbacks remain valid, but not as a permanent failed-attempt history after safe retirement. |
| `consumable_completion_failed` | BOUND accepted ID/outcome | Any independently resolved irreversible effect, if present; none may be presumed from failure alone | No-effect failure trace and reason do not belong in lifetime history. Do not discard a real resolved use merely because another event later reports failure/interruption. |
| `weapon_handling_failed` | BOUND accepted ID/outcome | Current valid posture and timing | Failed attempted posture and historical reason have no permanent ownership consequence. |

Future consumables that permanently alter attributes, remove currency, create items or grant progression require their own essential facts. This classification must not be generalized from current health/Mana potions to unimplemented Specials.

## 4. Exhaustive field classification

KEEP means essential durable data; BOUND means pending/current-context or bounded summary data; REMOVE means omit from the successor's lifetime history after the expiration conditions below hold. “Reconstructible” means deriving a projection from existing authoritative facts, never inventing an original ID or missing transaction.

### Fact envelope and action subrecord

| Current field(s) | Disposition and reason |
| --- | --- |
| `coverage` | REMOVE `creation_to_checkpoint` as a prerequisite for temporary-command replay. Replace with an explicit successor contract and proven request-retirement boundary; never use a verification flag as proof. Old unknown history remains unknown. |
| `run_id` | KEEP the original scope for irreversible facts and immutable per-run policy. It is not a list of previous-run commands. |
| `facts` | Split conceptually: KEEP compact irreversible facts; BOUND transient/retry summaries. Do not retain this mixed replay array forever. |
| `request_id` | KEEP full scoped original identity for irreversible operations. BOUND for transient commands only after all old envelopes can be rejected without that individual ID. No truncated IDs, approximate membership or final-inventory reconstruction. |
| `event_type` | KEEP the essential semantic kind/rule discriminator for irreversible facts; BOUND raw display/event naming for temporary traces. |
| `event_id`, `parent_event_id` | KEEP causal identities where required for permanent awards, origins, purchases, growth, grants or irreversible spend binding. REMOVE ordinary draw/start/completion event chains from lifetime saves. |
| `event_sequence`, `timestamp_us` | BOUND command chronology/debugging. KEEP original permanent-growth/transaction order where it proves rules; ordinary stow timestamps are not that order. |
| `progression_index` | KEEP event-time ordering for END/HPB/WIS/permanent growth. REMOVE copies attached solely to replaying old equipment or temporary healing. Runtime verifies the legal current attributes when the new command occurs. |
| `payload` | Retain only essential irreversible facts or current state; bound other fields as detailed below. |
| `action` | BOUND accepted/pending/terminal action detail. Current checkpoint timing/RNG/resources remain KEEP. The record must not replay every past action to recover them. |
| `action.instance_id`, `definition_id`, `declaration_id`, `start_id`, `terminal_id` | BOUND links for an unresolved request, result reconciliation and recent diagnostics. KEEP only a direct reference that is genuinely needed by a permanent fact; not its full chain. |
| `declaration_sequence`, `start_sequence`, `terminal_sequence` | BOUND action causality; REMOVE from lifetime temporary-action history. |
| `start_us`, `terminal_us`, `due_us`, `anchor_us`, `starting_interval_index`, `required_acts`, `completed_acts`, `at_at_start` | BOUND original action detail. KEEP only the current checkpoint's applicable timing cursor/anchor and any genuinely pending action state supported by its contract. Current safe checkpoints exclude pending player actions. |
| `terminal_type` | BOUND result/outcome. It must not convert an interrupted/no-effect use into a permanent item debit. |

### Payload fields

| Current field(s) | Disposition and reason |
| --- | --- |
| Acquisition `instance_id` | KEEP once in the original acquisition/ownership fact. The extra temporal wrapper is REMOVE after it contributes no distinct permanent authority. |
| Equipment `request_id` | BOUND for this conserving operation, under the same immutable request/context rules as its envelope. |
| `equipment_before`, `equipment_after` | Historical pair REMOVE. Current equipped instance references are KEEP; catalog legality is checked against current source-backed character/ownership. |
| `hands_before`, `hands_after`, `mode_before`, `mode_after` | Historical transitions REMOVE. Current hands/mode are KEEP. If an unusual current partial grip requires a source warrant, retain one warrant for that still-active posture, replacing it when the posture ends; not every prior transition. Unsupported exceptions still fail closed. |
| `inventory_before`, `inventory_after` | Equipment count mirrors are reconstructible from current ownership/origins and the current equip/carried partition. REMOVE historical copies. An equipment change must never create/consume quantity. |
| `modifiers_before`, `modifiers_after` | REMOVE historical armor-modifier mirrors. Derive current equipment modifiers from verified definitions, preserving independently authored/buff effects and rejecting unsupported exceptions. |
| `ownership_selections` on equipment | BOUND the accepted transaction's actual selections. Current equipped instance/slot identity is KEEP; it is not reconstructed by guessing which identical item was selected. |
| Handling `weapon_ref`, `operation` | BOUND intent/result. Current owned weapon reference and current handling mode are KEEP; the old operation sequence is REMOVE. |
| `owned` | REMOVE as a permanent assertion flag; reconstruct ownership from authoritative item origins/current disposition. A boolean is not authority. |
| `downtime_clock_paused`, temporary `required_acts` | BOUND source legality/timing at the operation boundary. REMOVE lifetime mirrors; preserve current authoritative clock/action state. |
| Consumable `inventory_id` / definition | KEEP the irreversible use's exact definition/rule association, or an unambiguous reference through its immutable selected origin. Do not infer a request ID from that definition. |
| `ownership_selection` | KEEP exact selected instance IDs and debited quantities, with the resolved-use ID and immutable bindings. |
| `quantity_before`, `quantity_after` | KEEP current/terminal quantity. Full before/after pairs need not be duplicated forever if original acquired quantity and exact positive spend/loss facts independently reconcile it. A final difference alone is not evidence of legitimate use. |
| `effect_kind`, `flat_bonus` | Known rule identity can supply the supported temporary effect; BOUND the detailed original resolution. Keep additional values only where a real permanent effect requires them. |
| `rolls`, `rng_draw_indices`, `rolled_amount`, `rolled_healing`, `rolled_recovery` | BOUND temporary potion-resolution detail. Current authoritative RNG state/draw count is KEEP. Permanent HD/HPB/WIS growth dice are a different category and remain KEEP. |
| `value_before`, `value_after`, `value_maximum`; `hpc_before`, `hpc_after`, `hpc_max`; `mana_before`, `mana_after`, `mana_max` | REMOVE old healing-resource trajectories from lifetime evidence. KEEP current resources/maxima/checkpoint, validate them and never refill on load. |
| Payload `action_instance_id` | BOUND request/completion correlation; retain only a minimal necessary irreversible binding if used by the source contract. |
| Failure `reason`, failure `quantity_after`, failed `weapon_ref` / `inventory_id` | BOUND result/diagnostic fields. No permanent spend is invented from a failure. |

The result deliberately stops cold validation from rerunning every temporary item effect. It does **not** remove source legality from the original mutation path, weaken old readers or allow imported balances to authorize rewards. It is a new-format decision requiring approval, with current-state and essential-evidence cold checks instead of a forensic replay of temporary commands.

## 5. Exact expiration safety requirements

### Why deletion is unsafe today

The original APIs accept an opaque request string. If its accepted-ID entry disappears, a delayed `stow`, `equip` or potion request can become legal again after intervening state changes. Current equipment already matching the request does not solve this: an old equip can arrive after a deliberate unequip. Current quantity being positive also does not distinguish an old consumption from a fresh intent.

Neither the persisted UI counter, local capture revision, wall-clock timeout, checkpoint age, run completion nor journal eviction alone closes that hole. A capture revision tracks freshness; it is not a complete accepted-ID prefix, durable storage ownership or proof that every smaller number executed.

### Required invariant before expiring a transient ID

Every request must carry an immutable, coordinator-issued binding to the exact character/profile namespace, character epoch, admitted runtime, run, request window and expected state revision. It must be captured **before** enqueueing/click handling/await and preserved through completion. Receivers must not attach today's context to an old raw string.

For the approved trusted in-process model, an exact private issued-context handle can identify the current admission/window; a caller-created equal-looking Dictionary or persisted `verified` flag cannot. New admission/reload invalidates previous runtime handles. Serialized external messages must not be silently rebound; any future serialized acceptance protocol needs an explicit durable freshness fence. A local handle does not replace Windows/Edge writer ownership or CAS.

All of the following must be demonstrated:

1. **Mandatory entry rejection:** every relevant mutation path/callback checks the actual issued context/revision before effects, RNG, resource spending or asynchronous continuation. No legacy raw-ID bypass remains reachable for the new admitted route.
2. **No rebinding:** delayed callbacks retain the captured old context. Cancellation, profile changes, reload, NEW RUN and stale admission invalidate it. They cannot mint a fresh wrapper for an old accepted intent.
3. **Terminal actions:** no accepted item action or future scheduled completion remains capable of applying an effect under the retiring window. Use original terminal/cancellation rules; a paused action is not terminal.
4. **Complete capture:** all effects/irreversible facts of the retiring prefix are in the immutable candidate at its actual legal boundary. No pending or post-capture effect is forgotten.
5. **No freeze during I/O:** under the existing capture gate, seal the captured window and issue the next volatile window before releasing gameplay. Later mutations belong to that new window. Acknowledging an earlier checkpoint must not overwrite newer runtime state or reapply effects.
6. **Uncertainty retained:** preserve the exact pending operation/bytes and required IDs until publication/readback is reconciled. No timeout or CANCEL may erase evidence after possible publication. One pending checkpoint is not 20 indefinitely retained candidate snapshots.
7. **Durable coverage before durable retirement:** the successor snapshot, its exact latest-state replica and acknowledged head/retirement binding must be committed consistently and reread before dependent state is released. A failed publication cannot leave a durable fence without its character effects, or effects without protection.
8. **Restart safety:** cold admission creates a fresh actual runtime context and does not reactivate old callback handles. Older-than-journal requests get `stale/expired context`, not an attempt to reconstruct/reexecute their old result.
9. **Branch safety:** fresh destination-head ownership/CAS and supported restore policy prevent installing an older checkpoint that reopens retired authority. Unsupported occupied-profile replacement remains blocked.
10. **Positive proof of closure:** if any caller/action/uncertain outcome cannot be fenced, keep its exact identity/binding and refuse unsafe eviction. Do not claim retirement is implemented because a scalar named `watermark` exists.

This rejects all requests from a closed context, including ones never accepted. It does **not** pretend those nonexistent IDs were processed and does not approximate an acceptance set. Exact retry lookup is needed only while that retry is still valid; rejection after retirement is sufficient.

Keep permanent consumption/acquisition/progression IDs in the first sustainable version. Even if a later proven retirement protocol could compact some irreversible request identities, optimizing that is unnecessary here and must not replace semantic duplicate protection with counters or balance checks.

## 6. Same character, multiple runs

| Identity/state | Proposed lifecycle |
| --- | --- |
| Profile ID, NORMAL/legacy DEV namespace, character epoch, original source | Persist unchanged. A new Arena run is not a new character or save namespace. |
| Permanent attributes, EXPM/EXPC, purchases, credits, growth, inventory/condition | Carry forward exactly. No new-run reaward, refill or historical reinterpretation beyond already-approved source rules. |
| Run ID and XP policy | Allocate/bind a new unique run ID and immutable policy at authorized admission with its first Wave 1 checkpoint. Keep a small original run-policy/ID table sufficient for historical award validation and run-ID nonreuse, including legacy policy ordering. No old-run gameplay transcript. |
| Current run/wave recovery state | Keep the one applicable authoritative checkpoint, RNG/resources/movement/timers and current run's relevant reward/entry state. NEXT WAVE/RETRY/RESUME preserve the admitted run/policy. |
| Closed run's awards/items/purchases/credits | Remain exact lifetime semantic facts/IDs. A new request wrapper cannot make the same defeat, item origin, purchase or fixed grant legitimate again. |
| Closed run's temporary requests | Reject by obsolete run/admission/window before mutation. Do not keep every draw/equip/interruption for that rejection. |
| Commit sequence | Continue monotonically across runs; it is not the number of retained history rows. Last commit identity plus pending/recent results serve reconciliation. |
| Recent journal | Approximately 20 bounded summaries, not complete batches/full snapshots hidden in each entry. Older resolved temporary results can be forgotten once stale rejection is proven. |

Original raw IDs such as `task14_weapon_stow_000001` can repeat after reset; they cannot be treated as globally unique just because a counter exists. Scope genuine new intents at issuance. Never retrospectively attach invented scope/IDs to unknown historical commands.

V2 currently rejects a second run. Lifting that check alone would leave lifetime command growth and potential raw-ID collisions. Multi-run support needs the lifecycle contract above and a new format; it must not reset permanent facts to make a new run fit.

For old profiles with incomplete command logs, preserve old read/inspection behavior. They need no guessed historical equipment transcript merely to display current equipment. Making them writable under a new retirement boundary is a separate explicitly verified conversion policy: validate available original progression/ownership evidence once and irrevocably reject old request contexts. Do not synthesize unknown consumed-use IDs from quantity differences. If required irreversible evidence is unavailable, reject conversion or offer a separately approved fresh character path; do not silently migrate.

## 7. Smallest sustainable successor record

An explicitly new snapshot version is justified: v2 requires the full command prefix, and v1/v2 require `operations.size() == sequence`. Pruning those arrays under version 2 would silently change its semantics. **Version 3 in the existing snapshot domain is a proposal only**, to be rechecked/approved before implementation. Keep v1/v2 readers and fixtures intact.

Recommended durable contents:

1. Header/identity/source/rules, character epoch, monotonic sequence, last stable commit ID, minimum reader and whole-body checksum.
2. One current complete character and safe run/checkpoint/RNG/resource/movement state; an exact byte-identical latest-state repair replica, not an older playable generation.
3. Original flat permanent award/purchase/growth/credit facts and their necessary chronology. Preserve original END/HPB/WIS/HD/Mana terms and original grant identity/eligibility; no retrospective rerolls or second wallet.
4. Immutable item origins and current terminal ownership/condition, including zero-quantity/tombstone dispositions. Compact exact irreversible consumption/loss facts bind original operation IDs to selected instances and quantities.
5. Minimal original run-policy/ID records and current request-retirement/recovery metadata required by the proven protocol.
6. About 20 small recent operation summaries. No complete lifetime checkpoint array or equipment transcript.

The full `(scope, original ID)` already present in essential facts can rebuild an exact in-memory lookup. Do not serialize another row per ID/digest when it provides no independent evidence. Preserve immutable associated values; a full binding hash may be used in memory, but a hash alone is not membership. Do not introduce a persistent secondary index.

Current positive `current.items` and checkpoint `profile_ownership.items` duplicate item content. A single normalized ownership table plus derived projections is a sensible target, but bounded duplication of *current* state is distinct from lifetime history. Avoid broad rewriting merely to remove this factor first. If normalized, materialize the existing rule/checkpoint projection temporarily for validation, verify exact equivalence and do not change simulation schema 12 or manufacture missing fields.

Reusing old helpers must not involve dummy operation rows. In particular, v1 uses the complete `operations[after_generation]` position for fixed-credit validation. A successor needs the genuine original grant operation identity/order as an explicit essential credit binding, extracted only from verified available evidence. It cannot remove the array and claim the old index proof still exists. New grant authority remains unchanged.

### Cold and routine validation boundary

Cold/import: validate all essential lifetime evidence and exact IDs, source-backed progression/accounting, item-origin/use conservation, current legal loadout/handling/condition, run policy and checkpoint. Current resources come from the verified snapshot and are range/rule checked. Do not replay old healing or all former equipment to obtain them.

New effect: the original source API validates current legality, resolves its original RNG/effects once and supplies the genuine transaction to the existing coordinator. The coordinator checks fresh context/exact identity, appends essential irreversible evidence and captures current state. A final balance alone never authorizes an award/use.

Future deterministic replay means the same captured checkpoint/RNG and same future legal commands converge. It does not require a character save to reconstruct every historical stow or potion animation. A separate isolated replay fixture may retain an input transcript for testing; it must not become mandatory lifetime character data or a bypass into the live mutation API.

## 8. Measured sizes and growth estimates

### Method and limits

Read only six existing disposable `commands46d_*/cold_v2.json` files under `%LOCALAPPDATA%/itank-storage-tests/`. No owner character, backup or browser storage was opened. Verified their stored body SHA-256 for byte accounting; no new Godot validation/test run is claimed.

Representative current active fixture: `commands46d_15452_5618252`, **38,989 file bytes / 35,294 body bytes**, sequence 6, eight facts. Representative earlier downtime draft: `commands46d_5996_7061245`, 79,510 file bytes, 30 command IDs. The latter predates final affected-inventory filtering; its equipment rows below are an **in-memory size-only projection applying the current filter**, not a claim that this earlier file passes the final v2 reader.

Body figures use exact UTF-8 source JSON substrings where applicable. File contributions account for the current outer `body_json` string escaping. Row commas/brackets add small overhead. Proposed minimal consumption figures use compact sorted JSON of genuine original ID/run/definition/selected-instance fields solely to estimate size; no new record, conversion or backup was written/validated.

| Retention unit | Body bytes, representative | Contribution inside current encoded file |
| --- | ---: | ---: |
| Current-filter equipment fact, projected mean | 867.6 | 969.2 |
| Equipment/item-command ID row, measured mean | 123.7 | 135.7 |
| Active handling fact, mean of stow/draw/stow | 686.7 | 774.0 |
| Active healing resolution | 1,024 | 1,130 |
| Interrupted accepted action | 763 | 843 |
| Downtime potion resolution, mean | 606.3 | 674.3 |
| Generic checkpoint operation row | 105–106 | 113–114 |
| Additional generic operation ID row | 124–125 | 136–137 |
| Minimal consumption ownership fact, size-only | 170–179 | 190–199 |
| Current positive item row, sample means | 442–459 | 477–506 |
| Full existing settlement row, sample means | 435–436 | 475–476 |
| Essential award row, sample means | 104–105 | 110–111 |
| Essential original growth row, sample mean | 338 | 374 |

An equipment fact plus its repeated ID costs about **1.1 KB**; a source downtime equipment change also publishes a checkpoint, adding approximately **250 bytes** of generic operation+ID history before other overhead. Active handling usually waits for the later legal checkpoint instead. Recent journal size 20 does not cap either accumulation.

Fixture IDs are short (`46d_use_0`, `run_45q`). Production `_new_run_id()` uses `run_` plus 32 hexadecimal characters, and generated request IDs are longer. A prudent illustrative consumption budget is **220–350 bytes** per compact fact, not a guaranteed 170 bytes. Long source/provenance/instance IDs can increase costs substantially.

### Illustrative hundreds-of-runs projections — not executed workloads

| Assumption | Current v2-style retained cost | Recommended retention |
| --- | --- | --- |
| 500 runs × 100 equipment changes = 50,000 downtime equipment commands | About 55.2 MB for equipment facts+IDs, plus 12.5 MB operation+ID history: roughly **67.8 MB per logical record**, before other state. Exact replica approximately doubles durable bytes. | No lifetime equipment-command component after safe retirement. Current loadout and bounded retry summaries remain. |
| 50,000 active handling commands at the observed mixed mean | About **45.8 MB** facts+IDs, before checkpoint/progression overhead | Current handling/timing and bounded request state; no lifetime handling transcript. |
| 500 runs × 10 actual uses = 5,000 consumptions | Roughly 4.1 MB of downtime detail+IDs or 6.4 MB of active detail+IDs, before checkpoint rows | Approximately **1.1–1.75 MB** at the conservative compact-fact budget; exact irreversible IDs/effects still grow legitimately. |
| 5,000 distinct acquired item instances/origins | Origin, current/terminal and receipt data remain necessary; current mirrored rows/ID arrays add overhead | An illustrative **2.5–5 MB** at 0.5–1 KB per origin/current ownership record, plus use/loss facts and progression. This is a budget, not a measured successor encoding. Stack quantity and distinct instance count are different. |
| 500 minimal run-policy records | No complete run transcript is justified | A 36-character run ID plus multiplier serializes to 68 bytes in the example; tens of KB, plus actual identity/legacy-policy metadata. |

The hypothetical 500-run v2 workload cannot actually be written today: v2 rejects a second run, caps mixed facts at 8,192 and inherits 16 MiB body / 24 MiB file and entry limits. Even 100 transient commands per run alone would exhaust that fact cap after roughly 81 runs if the single-run gate were merely lifted; acquisitions/consumptions exhaust it sooner. Limits failing closed are useful safety, not a sustainable retention design.

Essential XP/credit/purchase/growth/item data still adds to every estimate. Exact arbitrary lifetime irreversible identities cannot have constant storage cost without a separately proven restriction/retirement scheme. Keep finite limits, measure realistic intended horizons and reject unsupported growth explicitly. Do not promise infinite history or silently raise limits. These size estimates do not demonstrate browser memory, save latency or the cause of the owner's earlier 2 GB observations.

## 9. Risks and smallest next implementation

Main risks are premature ID eviction, implicit rebinding of delayed callbacks, uncertain publication, same raw strings reused in another run, resurrected zero-quantity origins, double grants under new wrapper IDs, losing historical growth terms, and changing a codec version's meaning without a new version.

**Smallest next task, only if approved: a dormant transient-request retirement prerequisite.** Use the existing coordinator ownership and capture gate. Prove with original equipment/handling/no-effect potion commands that a captured immutable old context is rejected after checkpoint closure, reload, cancellation and NEW RUN, even after its per-ID cache is deliberately removed. Test continued post-capture gameplay, exact retry, unknown acknowledgement, competing stale callbacks and zero added RNG/effects. Do not change persistence/codec/storage in that prerequisite.

Required stop condition: if every relevant callback/mutation path cannot be covered with a small explicit ownership change, keep IDs and report the gap; do not build another general security/state-machine framework or delete the cache anyway.

Only after that proof should a separately approved dormant successor codec remove temporary histories/generic operation arrays and implement compact irreversible ownership evidence. Preserve v1/v2 readers, original source rule validators, permanent chronology, current schema-12 semantics and exact duplicate protections; test new semantics independently. Do not resume the broad #46C2 implementation or storage integration before the retention decision is reviewed.

Owner decisions requested by this audit: approve bounded/fenced temporary-request retention instead of permanent individual histories; approve the stated current-state/essential-evidence cold-validation boundary; separately decide whether unsupported old profiles stay read-only or receive an explicitly verified conversion/fresh-start path. No such policy has been applied here.

## 10. Workspace preservation and validation

Only this report is added. All **755** baseline scoped project files remain byte-identical, including the v1/v2 codecs, #46C2 helper, tests, prior reports and `project.godot`. No earlier status entry is removed.

Branch `main`, HEAD `f9bb0db0235b0003895c477a12346191d4714469`; index remains empty. Entry status: 35 modified tracked / 175 collapsed untracked entries. Final status: 35 modified tracked / 176 collapsed untracked entries. The sole delta is:

```text
?? docs/architecture/TASK_46E_COMMAND_RETENTION_AUDIT.md
```

Protected paths were listed by Git name only and their contents were neither opened nor hashed. Owner profiles, browser storage, backups, protected boss documents and repository `tmp/` were not accessed. No source/tests/formats/configuration changes, no test execution, no staging/commit/push/reset/stash/cleanup, no export and no #45U work. Read-only source inspection, disposable artifact byte accounting and document/whitespace preservation checks were the only validation performed.

**Recommendation: hold v2 routine-save promotion and #46C2 resumption pending this retention decision. No implementation is authorized by this report.**
