# Phase 1 Physical Combat Implementation Blueprint

## Objective and boundary

Phase 1 should produce one deterministic physical duel without adding Specials, NAC resolution, enemy AI, loot, progression or real networking. The rules/simulation layer remains authoritative and independent of graphics and input. Presentation submits intentions and renders results; it never decides hits, defenses, damage or randomness.

This plan depends on `PHYSICAL_COMBAT_RULES_AUDIT.md`. Any item marked unresolved is an implementation gate, not an invitation to choose a conventional RPG answer.

## Safest implementation sequence

### 1 Source data and validation

Transcribe the relevant rows from the Mana/Regular Attribute Charts, hit-location modifier tables, weapon chart, armor chart and shield chart into versioned resources. Preserve the printed value and page reference beside every row. Add schema validation for duplicate IDs, invalid dice notation, unsupported damage types, missing strength requirements and incomplete armor coverage.

Do not derive a smooth formula from a Prime lookup table. The table is the rule.

### 2 Actor state and derived statistics

Create immutable character definitions and mutable match-state snapshots. Resolve ACC, AT, MR, INIT, NAL, PS, SB, DT and DP from audited source data plus explicitly identified equipment/condition modifiers. Keep base, equipment, temporary and final values separately so the combat log can explain the result.

The first duel data for Aren Valecrest and Garrick Ironward requires a separate character-sheet/equipment audit before entry.

### 2A Canonical movement and Running

Store authoritative position and distance in feet. Derive base speed as `MR / 5` feet per second and keep the configurable pixels-per-foot conversion entirely in presentation. Effective MR composes current verified equipment, condition and Special modifiers before applying the one nonstacking Running bonus `floor(current effective SPD / 2)`.

Running input is an intention, not authority. Shift plus nonzero movement requests one activation. For nonautomatic Running, the authority rolls against `END - 2 + SCM + max(SI - 1, 0)`, with the general additional `-4` penalty at zero investment. RB beneficially adjusts the die result while the unmodified natural die controls critical success/failure. Three investments make Running automatic. Every check records raw roll, adjusted roll, target, components, result and deterministic check sequence.

The same calculation applies every five seconds of continuous Running unless automatic. Failure ends Running and starts a five-second cooldown. The `END x 5 seconds` cap wins ties with maintenance and ends Running without a roll. Recovery debt accrues one-for-one with actual Running time, clears at full rate while standing and half rate while walking, and independently blocks a new attempt alongside cooldown. Intentional stop or Shift release ends Running, while a transient zero-input frame or collision does not. Direction changes retain the 45-degree restriction.

### 3 Time budgets and opening initiative

At combat start, the authority rolls and records `1d10 + INIT` for each actor. Schedule actions on the existing integer microsecond clock. One ordinary Act occupies `5 seconds / AT`; there is no stored balance, recharge or initial reserve. Multi-Act actions occupy consecutive full intervals and effect on the last one. Track MR as a five-second round budget independently from action timing.

Task 6 implements the verified opening order as a first-declaration gate: total descending, then base INIT descending, with exact ties sharing simultaneous eligibility. Prime supplies no real-time delay between ranks, so rank release does not fabricate a timestamp offset. A future input layer still requires an explicit pass/forfeit intention.

Define round membership with a documented half-open interval and write boundary tests before gameplay integration. No renderer delta may directly advance authoritative time without deterministic quantization.

### 4 Action declaration and scheduling

Accept a physical attack intention containing actor, target, weapon/mode, desired location, direction and client input sequence. Validate actor condition, equipment, action availability, target existence, range, line of sight and location legality. Reject invalid intentions without rolling.

On acceptance, schedule the required number of continuous Act intervals according to the audited action definition. No Act currency is reserved or spent. Visual animation follows declaration, start and effect timestamps.

### 5 ACC resolution

At the effect point, compute the explained ACC target from the actor snapshot, equipment/condition modifiers and any aimed-location size modifier. Roll one authoritative d20, record the raw die and target, and classify ordinary success/failure plus a possible critical trigger. A miss finalizes without defense or damage.

Task 6 implements this boundary with source-referenced attack definitions and labeled test fixtures. ACC success enters `pending_defense`; it is not final damage and does not reduce HPC. An interrupted attack consumes no ACC draw.

Critical outcome application remains gated until the physical critical tables are approved. The engine may record the trigger, but Phase 1 cannot claim critical behavior is complete without resolving it.

### 6 Defensive eligibility and priority

Build defense candidates from rule facts rather than UI preference:

- DT only for hand-held physical delivery.
- DP only for thrown weapons or magical projectiles; Phase 1 uses the thrown subset only.
- Dodge unavailable while surprised, immobilized or without a legal escape/duck and sufficient MR.
- Physical Soak unavailable after an actual Dodge attempt, when surprised/back-attacked, or against piercing, Specials, Dwarvestek or Grentek. A considered but ineligible Dodge does not exclude it.
- Block requires a legal equipped item and applicable proficiency and applies only where Prime permits physical blocking.
- Surprise or lack of awareness makes active Dodge, Block, Physical Soak, Special Resistance and awareness-dependent reactive NACs ineligible; passive protection remains.

Then apply the saved defense priority. Actually attempting Dodge removes Physical Soak from the same attack. Identical inputs must produce the same candidate list, chosen defense sequence and recorded rejection reasons.

The saved priority controls the sequence (default Dodge, Block, Physical Soak). An actual Dodge attempt permanently excludes Physical Soak for that attack; an ineligible Dodge does not. A legal weapon Block and legal shield Block are independent candidates; after the first fails, the other may be attempted. These reactions consume zero Acts unless an explicit source overrides; Dodge still spends MR. Failed candidates fall through only to combinations the ledger permits.

### 7 Location armor and physical damage

After defenses fail or are unavailable:

1. Resolve the declared/default hit location.
2. Roll the weapon's printed damage dice through the authoritative RNG.
3. Add SB only for an eligible melee or thrown attack.
4. Apply only source-approved critical/location multipliers to the damage-plus-SB subtotal.
5. Select armor for that location: helmets cover head/neck and leg armor covers legs/feet. For combined physical types, use the lowest applicable protection without stacking.
6. Subtract applicable location TAL, then NAL, exactly once each.
7. Apply Prime's minimum-one physical damage rule where eligible.
8. Reduce HPC and evaluate blunt unconsciousness/defeat thresholds.

The order and coverage are approved. Fractional multiplier rounding, Prime-specific minimum-one exceptions and unaudited item exceptions remain gates; do not infer them.

### 8 Knockback and conditions

Represent knockback as a separate dependent effect containing source, requested distance, prevention, actual path, collision and Balance requirement. Never infer knockback from damage. Apply source-specific collision damage only when its source says so.

Physical and magical knockback both request Balance unless the source effect overrides. Success retains footing while displacement still occurs. Failure applies prone plus a 0.5-second stagger, and standing costs one Act. Paralysis and unconsciousness are not Balance challenges. The generic Balance target/modifier and universal prone penalties remain gated, so the initial playable duel should exclude unresolved knockback resolution.

### 9 Finalization and publication

An attack does not finalize merely because its ACC or defense roll succeeded. Finalization occurs after all legal dependencies have resolved and state mutations have committed atomically. Publish sequence-numbered resolved events only after authority validation. Store raw rolls, derived targets, legal-defense reasons, resource changes, armor selection and final damage in the authoritative transcript.

## Required data structures

| Structure | Required fields | Responsibility |
| --- | --- | --- |
| `DerivedStatTable` | character type, source attribute, source value, derived values, source page | Exact Prime lookup data; no inferred formula |
| `ActorDefinition` | stable ID, size, character type, base attributes, DT/DP allocation, skills, equipment IDs | Immutable source-approved character data |
| `ActorCombatState` | HPC, condition set, position, facing, opening Initiative evidence/rank, continuous interval progress, remaining MR, ammunition, equipment durability, revision | Authoritative mutable match state |
| `MovementState` | position feet, base/effective MR, effective SPD/END, Running investment/state, activation result/evidence, retry cooldown, maintenance/duration/rest clocks, last legal direction | Canonical movement independent of pixels and input devices |
| `WeaponDefinition` | ID, attack modes, delivery class, damage dice, damage types, SB eligibility, range, rate, clip, reload Acts, BLK, STR requirement, handedness, exceptions, source | Data-driven weapon rule |
| `ArmorDefinition` | ID, slot, TAL, protected damage types, STR requirement, MR/DT/DP penalties, source | Location/type-specific protection |
| `ShieldDefinition` | ID, size, BLK, max/current SHP, STR requirement, proficiency, success behavior, repair eligibility, source | Shield Block eligibility and shield-only destruction lifecycle |
| `HitLocationDefinition` | number, name, ACC modifier matrix, damage multiplier, armor slot, source | Aimed attack and coverage data |
| `AttackIntent` | actor, target, weapon/mode, location, aim/direction, input sequence, requested timestamp | Untrusted input to authority validation |
| `ActionInstance` | action ID, definition ID, declaration/start/effect/finalize timestamps, required/completed interval count, status, dependencies, commitments | Multi-stage deterministic lifecycle |
| `CombatAttackDefinition` | stable ID, weapon, interval count, source-referenced range/location modifiers, movement/interruption flags | Fail-closed physical attack inputs without damage data |
| `CombatAttackInstance` | action, actors, weapon/location, explained ACC target, RB, natural/adjusted roll, critical flags, pending-defense/miss/interrupted state | Task 6 authoritative accuracy record |
| `RollRecord` | roll ID, event ID, die expression, raw dice, modifiers, target, result, critical trigger, RNG position | Reproducible evidence for every roll |
| `DefenseCandidate` | type, source item/stat, eligible, rejection reasons, target number, MR cost, exclusivity group | Explainable automated defense selection |
| `DamagePacket` | source, dice components, SB, types, hit location, multipliers, reductions, floor, final amount | Auditable damage calculation without hidden bonuses |
| `CombatStateSnapshot` | simulation time, round, actor states, pending actions, RNG state/version, next sequences | Replay, save and future reconnect boundary |

Protocol-facing values should use integers, strings, arrays and dictionaries already supported by `SyncStateDigest`. Positions should be fixed simulation units or explicitly serialized integer components, not renderer-dependent floating-point objects.

## Proposed systems and responsibilities

- **Source data repository:** Loads and validates audited character, weapon, armor, shield and lookup data.
- **Derived stat resolver:** Produces explainable final stats from source rows and modifiers.
- **Combat scheduler:** Owns exact time, round boundaries, cumulative `5 seconds / AT` interval scheduling and due-event processing.
- **Movement model:** Owns canonical feet, effective MR, Running transitions, cooldown and verified timing boundaries; never reads keyboard state or pixels.
- **Movement input/presentation adapter:** Converts WASD/Shift to intentions and canonical feet to pixels; it has no authority over checks or modifiers.
- **Intent validator:** Rejects illegal attacks before any roll or state commitment.
- **Dice service:** Owns seeded RNG access and emits a `RollRecord` for every draw.
- **Attack resolver:** Coordinates ACC, defenses, location and damage without rendering knowledge.
- **Defense eligibility service:** Produces legal candidates and rejection reasons; the priority selector cannot make an illegal defense legal.
- **Damage resolver:** Applies only approved ordering, armor and floors; returns a detailed `DamagePacket`.
- **Condition/knockback resolver:** Applies explicit source effects and never creates generic consequences.
- **State transaction:** Commits resource, item and HPC changes atomically at finalization.
- **Combat log/replay projector:** Converts authoritative records into readable messages and deterministic replay data.
- **Presentation adapter:** Maps input to intents and events to visuals; it has no rule authority.

## Combat event lifecycle

1. `intent_received` - retain input sequence and requested action.
2. `intent_rejected` or `action_declared` - record validation result and source state revision.
3. `action_started` - commit the applicable Act/action resource.
4. `action_effect_due` - enter deterministic ordering by timestamp, INIT and stable sequence.
5. `attack_roll_resolved` - record ACC roll, target and critical trigger.
6. `defense_candidates_evaluated` - record eligibility and rejection reasons.
7. `defense_roll_resolved` - record selected defense and costs; repeat only where the approved sequence permits.
8. `damage_resolved` - record dice, SB, location, armor, NAL and final value.
9. Optional dependent `knockback_resolved` and `condition_changed` records.
10. `action_finalized` or `action_interrupted` - commit final state and release/cancel remaining dependencies.
11. Publish the resolved envelope and updated state digest.

An interruption references the affected action and waits in the dependency graph. Queue order alone is insufficient to express whether an action may finalize.

## Deterministic dice requirements

- Only the authoritative simulation draws combat randomness.
- Every draw records die expression, raw results, declared modifiers, target, outcome and an RNG sequence/index.
- Replays consume recorded outcomes; observers do not reroll.
- Test seeds are fixed and named in fixtures.
- Cross-platform clients compare authoritative results and state digests rather than assuming Godot's RNG algorithm will remain stable across engine versions.
- No visual timing, frame rate, dictionary order or input arrival race may change the draw order.

## Existing foundation assessment

| Existing component | Fit | Missing extension point or defect |
| --- | --- | --- |
| `CombatClock` | Exact five-second microsecond constant and boundary helpers are suitable. | Uses floating conversion for round index; integer division should replace it before extremely long sessions. It has no due-event progression or round-budget hooks. |
| `DeterministicCombatRng` | Seeded integer draws are a valid authority-only starting point. | No roll index, state snapshot, domain separation or emitted roll evidence. Replay currently depends on identical call order. |
| `CombatEvent` | IDs, timestamps, INIT, stable sequence, dependencies, payload and commitments cover the neutral envelope. | Needs typed lifecycle/status semantics, state revision and explicit declaration/start/effect/finalize records; dictionaries alone should not become undocumented gameplay schema. |
| `CombatEventQueue` | Timestamp, descending INIT and stable fallback match Arena ordering. | `drain()` releases all future events without consulting the clock. Dependencies are stored but not enforced; cancellation/interruption/finalization are absent. |
| `CombatSimulation` | Correct separation from graphics/input and one RNG owner. | No actor state, transactional mutations, due-event loop, rule validation or replay snapshot. These can be added around the foundation without replacing it. |
| `AuthoritativeCombatSession` | Correct single authority and sequence-numbered publication boundary. | It labels drained scheduled events as resolved without a rule-resolution stage. Publication must move after validated finalization. |
| Observer/digest harness | Duplicate/out-of-order transcript convergence is useful and should remain. | Digest covers transcript only, not authoritative actor/pending-action state. Supported digest types exclude vectors/resources; protocol values must stay canonical. |
| `RunningSkillCheck` | Implements the Prime END/Skill/SCM/RB calculation and records natural-roll evidence without owning randomness. | Complete for the generic Running check; source-specific modifiers remain explicit caller data. |
| `PrimeMovementModel` | Separates feet, MR, five-second maintenance, END-based duration, recovery and cooldown from rendering/input. | Uses an injected authority-owned d20 source and serializes position as integer micro-feet; no transport or prediction exists. |

No existing file requires wholesale restructuring. Add narrow services and typed records around the current clock, queue, RNG and publication boundary. The one semantic correction required before gameplay is to stop treating queue drainage as equivalent to resolution.

### Phase 1 Task 4 status

The actor/action foundation supplies typed definitions and match state, explicit unresolved fields, due-event advancement, Act progress, terminal interruption/completion, dependency-gated finalization, authoritative snapshots, RNG draw counts and transcript-plus-state observer digests. Legacy `publish_resolved_events()` remains an all-pending test helper; time-bounded gameplay and synchronization use `advance_to()` / `publish_due_events()`. At the Task 4 boundary, attack validation and every attack/defense/damage mechanic were still unimplemented; the current Task 6 attack status is recorded below.

The Task 4 stored-Act model is superseded. Task 5 removes token balances and uses cumulative rational interval boundaries. Each boundary is rounded upward to the first whole microsecond; immediate sequential actions retain the same rational phase, while an idle gap starts a new timing anchor. This keeps AT 3 at `1,666,667`, `3,333,334`, then exactly `5,000,000` microseconds instead of accumulating rounding drift.

### Phase 1 Task 6 status

Opening Initiative and the pre-defense physical ACC stage are implemented. The authority records natural d10/d20 values and RNG draw indexes, gates first declarations by verified opening order, validates physical attack identity/equipment/range/location/line-of-sight facts, resolves ACC only at the final action boundary and serializes the result for deterministic replay and two-client comparison. Successful ACC remains `pending_defense`; no defense or damage behavior is present. Production actor/weapon/location data is not supplied by Task 6.

### Phase 1 Task 7 status

The generic physical defense transaction is implemented. Configurable profiles order Dodge, weapon Block, shield Block and Physical Soak; every option records eligibility and causal evidence, legal failures fall through once, Block opportunities remain separate, and Dodge/Soak exclusion is enforced. DT/DP selection follows explicit physical delivery, active defenses reject surprise/unawareness, and critical triggers use natural d20 values independently of RB. A validated successful Dodge spends exact round MR and moves once. Ambiguous destination selection remains synchronized as `pending_dodge_displacement` without movement or spending. Successful defense and exhausted defense states do not apply damage, HPC loss, shield SHP loss or critical consequences. Production data remains unpopulated.

### Phase 1 Task 8 status

Automatic Dodge selection is implemented as an authoritative, deterministic policy over data supplied by the collision/navigation boundary. Each candidate states path and collision clearance, terrain legality, occupancy, escape or duck sufficiency, integer path cost and known hazard tier. Complete data selects the nearest candidate within the safest known legal tier, then candidate ID and coordinates provide stable tie-breaks. Incomplete data preserves `pending_dodge_displacement`; a complete environment with no legal candidate makes Dodge ineligible without consuming a roll or excluding Physical Soak. The defense attempt stores the selection evidence for replay and synchronization. Combat code does not infer geometry, hazard severity or duck legality.

### Phase 1 Task 9 status

The verified ordinary physical-damage subset is implemented. Attack definitions carry explicit duck policy and source-driven damage data. Exhausted defenses permit one authoritative transaction covering weapon dice, eligible SB, explicit multipliers, struck-location/combined-type TAL, NAL, minimum-one policy and HPC. Exact-type immunity/weakness responses declare their resolution stage. Unsupported fractional rounding, multiplier stacking and unauthored critical damage fail closed before damage RNG or mutation. Results and protection profiles are included in deterministic snapshots; simulated clients converge without resolving damage locally. Successful shield Block spends one SHP and 0 SHP enforces the approved destruction/equipped-reference boundary.

## Defensive resolution and fallback contract

The resolver must distinguish three states for every defense: `ineligible`, `eligible_not_selected` and `attempted`. A failed attempt does not create a retry of that candidate. An attempted Dodge permanently disqualifies Physical Soak for that attack; consideration or ineligibility does not. Weapon Block and shield Block remain distinct legal candidates and may follow one another after failure. Surprise/unawareness rejects all active candidates identified in the ledger while leaving passive protection intact.

When a preferred defense is ineligible, the selector proceeds to the next configured legal candidate. When it is eligible and fails, the resolver proceeds only to a defense Prime/Arena explicitly permits in combination. Every skipped option logs its reason.

This contract supports future NAC defenses without implementing them: NACs can become dependent candidates with their own eligibility, resource commitments and interrupt targets.

## Testing requirements

### Source and derived data

- Every relevant Mana and Regular chart row reproduces the printed derived values.
- DT + DP allocation obeys the approved character definition and modifiers.
- Every Phase 1 weapon/armor/shield field matches its cited page.
- Invalid or incomplete source data fails closed.

### Timing and ordering

- AT 1, 2, 3, 4 and 5 actions occupy exactly their deterministic `5 seconds / AT` intervals.
- Actor snapshots contain no stored-Act, recharge or starting-reserve state.
- Sequential fractional intervals use cumulative boundaries without drift.
- MR resets exactly at the approved boundary and Dodge spends the same budget.
- Exact timestamp ties use higher INIT then stable sequence.
- A future event cannot resolve when an earlier clock time is processed.

### Accuracy and critical triggers

- ACC success on target, failure one above target, natural 1 and natural 20.
- Torso has no invented aimed modifier.
- Each audited size/location matrix entry applies exactly.
- Mandatory ACC cannot be bypassed by collision or animation.

### Defenses

- DT versus melee and DP versus thrown delivery.
- Surprise/restraint/MR exclusions.
- Dodge/Soak exclusivity.
- Successful Dodge must have a legal escape/duck.
- Piercing and exceptional technology reject Physical Soak.
- Block requires legal equipment/proficiency.
- Priority fallback records why each option was selected or skipped.
- Duplicate defense attempts are impossible.
- A failed legal weapon/shield Block can fall through to the other legal Block exactly once.
- All generic active defenses cost zero Acts, while Dodge still spends MR.
- Surprise/unawareness rejects active defense and reactive-awareness candidates but not passive armor/NAL.

### Damage and state

- Melee/thrown attacks add SB; shot attacks do not.
- Helmet head/neck and leg-armor legs/feet mappings select the correct struck-location TAL.
- Combined types choose the lowest applicable protection without stacking.
- NAL/TAL are not double-counted.
- Minimum-one rule, blunt unconsciousness and zero-HPC outcomes match Prime fixtures.
- Damage follows weapon plus eligible SB, multipliers, TAL, NAL, then HPC; fractional rounding is tested as an explicit fail-closed boundary until approved.
- Natural 1/20 triggers ignore RB; rarity selection uses 70/25/5 only after action-specific outcome tables are authored.
- The same seed and intents produce identical rolls, events, final state and digest.

### Synchronization and presentation separation

- Two simulated clients converge on the final actor-state digest, not only the transcript.
- Duplicate and reversed delivery remain idempotent.
- Client attempts to submit resolved hit/damage values are ignored or rejected.
- Headless tests need no scene, sprites, animation or player input.

### Movement

- Exactly five seconds of unobstructed movement covers current effective MR feet.
- Running bonus floors odd effective SPD, applies once and updates when effective SPD changes.
- One/two/untrained investments reproduce the verified END, printed modifier, SCM and general untrained-penalty targets.
- RB changes ordinary success without changing natural 1/20 critical classification.
- Activation and each five-second maintenance boundary use the same calculation and recorded authority roll.
- The END-based cap wins a simultaneous maintenance boundary without drawing another roll.
- Failure blocks retry for exactly five seconds; recovery remains independently required.
- Standing, walking and mixed recovery clear debt at exact full/half rates without frame-rounding loss.
- Automatic proficiency at three investments bypasses activation and maintenance rolls but not duration/recovery.
- Intentional stop and Shift release end Running and accrue recovery; Shift tapping cannot bypass it.
- Legal direction changes retain continuity and the 45-degree restriction; isolated zero input does not stop a run.
- Equal initial state, authoritative evidence and time/input sequence yield equal canonical movement digest.

## Acceptance criteria for the first playable duel

1. Aren and Garrick data have independent source audits and pass schema validation.
2. Both actors move in canonical feet at `effective MR / 5` feet per second; pixels-per-foot remains a configurable presentation value.
3. Opening initiative and continuous Act timing are visible in an authoritative combat log.
4. Every legal physical attack performs ACC and records the roll.
5. Torso attacks and at least one approved aimed location use correct modifiers and armor.
6. Automated defense priority uses only legal DT/DP, Block and Physical Soak behavior, with no silent retries.
7. Weapon damage, SB, location armor, NAL and HPC changes match deterministic worked fixtures.
8. Critical triggers and effects behave according to approved tables, or Phase 1 is not declared complete.
9. Any included knockback has approved Balance/prone rules; otherwise knockback sources are excluded from the duel data.
10. The same seed/input stream produces identical event transcript and actor-state digest in repeated runs and both simulated clients.
11. The duel runs in the main scene on Windows and the Web Single-Threaded export without rule divergence.
12. No attack result is decided by sprite collision, client state or animation completion.

## Recommended incremental Codex tasks

1. **Phase 1 Task 2 - Prime Movement Foundation:** Completed by the isolated movement model and temporary WASD/Shift presentation harness.
2. **Phase 1 Task 3 - Running, Endurance and Recovery:** Completed with verified checks, maintenance, cap, recovery, debug state and deterministic tests.
3. **Phase 1 Task 4 - Combat Actor and Action Foundation:** Completed with shared actor definitions/state, lifecycle events, dependencies, interruptions, movement compatibility and authoritative snapshots.
4. **Phase 1 Task 5 - Continuous Action-Timing Correction:** Completed with no stored Acts, cumulative `5 seconds / AT` interval boundaries, fractional no-drift scheduling and preserved synchronization.
5. **Phase 1 Task 6 - Opening Initiative and Physical ACC:** Completed within the pre-defense boundary using labeled fixtures and fail-closed unresolved production data.
6. **Future task - Source Data Schemas and Fixtures:** Add validated actor lookup, weapon, armor, shield and hit-location data using only audited rows; no invented duel content.
7. **Phase 1 Task 7 - Physical Defense Eligibility:** Completed with deterministic candidates/fallback, separate Blocks, MR-accounted/pending Dodge displacement, natural critical evidence and synchronized state; no damage is applied.
8. **Phase 1 Task 8 - Automatic Dodge Movement:** Completed with deterministic safest-tier/nearest selection, stable ties, explicit environment facts, exact MR spending and preserved pending-data boundary.
9. **Phase 1 Task 9 - Duck Eligibility and Physical Damage:** Completed for source-declared ordinary physical data, deterministic defenses-exhausted gating, armor/NAL/HPC, SHP and fail-closed unresolved multipliers; production tables and critical consequences remain gated.
10. **Future task - Knockback and Conditions:** Proceed only after the Balance target/modifier is resolved; otherwise explicitly defer.
11. **Future task - Duel Integration:** Connect WASD/mouse intentions and event-driven presentation for Aren versus Garrick without moving authority into the scene.
11. **Future task - Replay, Web and Acceptance Verification:** Compare repeated state digests, two observers, Windows startup and Web runtime; create the Phase 1 checkpoint only after acceptance passes.

Each task should end with the standard seven-part report and stop before the next task. No task should combine a designer decision with its implementation without first recording that decision in the Rules Ledger.
