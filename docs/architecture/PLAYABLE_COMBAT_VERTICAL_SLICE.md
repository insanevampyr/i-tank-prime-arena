# Playable Combat Vertical Slice

## Authority boundary

Phase 1 Task 14 connects the temporary Arena scene to one `CombatSimulation`. `ArenaCombatSession` is an intent and orchestration adapter: it selects an existing target, samples the canonical movement position when an attack is requested, advances deterministic simulation time, submits the existing automatic-defense transaction, and invokes the existing physical-damage transaction only after defenses are exhausted. It does not calculate ACC, AT duration, defense eligibility, criticals, damage, TAL, NAL, SHP, or HPC.

Keyboard Space/Enter and the one-shot touch ATTACK button both call the same `request_player_attack` boundary. Repeated input is rejected while the player attack is in flight. Visual positions, labels, and animation never decide an outcome.

## Source-verified fixture

Production Aren/Garrick definitions are still unavailable. The scene therefore labels both combatants as **verified Prime V3 fixtures**, not production characters. The fixture transcribes:

- the Prime V3 Uncommon Guard attribute/derived-stat block (pp. 350-351);
- Battle Axe: three-foot range, `2d10 + 3` Slashing, BLK 2, Strength Bonus eligible, natural 1-2 critical-success range (Prime V3 weapon chart, p. 122);
- Plate torso armor: TAL 3 against Bashing/Slashing/Piercing (Prime V3 armor chart, p. 133);
- Metal Buckler: BLK 2 and 20 SHP (Prime V3 shield chart, p. 134).

Task 14 combines those verified rows only as a controlled integration fixture. It does not claim that this assembled loadout is Aren Valecrest, Garrick Ironward, or a saved production character.

## Playable flow

1. The scene initializes both actors, their equipment/protection/defense profiles, critical-reaction registrations, positions, seeded RNG, and opening Initiative in the authority.
2. The opponent is selected by default; clicking/tapping it or pressing Tab selects it again. Clicking/tapping empty arena space clears selection.
3. The player moves with the existing WASD/touch joystick and Running path. At attack input, the adapter submits the current canonical player position to the combat authority.
4. The authority validates alive state, equipped Battle Axe, torso target, line of sight, three-foot range, opening Initiative, and action availability.
5. One Act executes at the fixture's AT 2, so ACC occurs after exactly 2.5 simulation seconds.
6. An ACC hit enters the existing ordered Dodge, weapon Block, shield Block, and Physical Soak pipeline. The open fixture arena supplies bounded, collision-free, unoccupied, hazard-free Dodge candidates; no in-place duck is supplied because Battle Axe duck eligibility is unresolved.
7. If defenses are exhausted, the existing exact damage transaction applies Battle Axe dice plus eligible SB, approved critical factors, Plate TAL, NAL, and HPC once.
8. The event log renders authoritative ACC, defense, damage, critical rarity/outcome, Stagger, prone, reaction, interruption, pending, blocked, and unavailable records.

## Deterministic presentation

The session never rolls locally. Event-log text is derived from immutable `CombatEvent` payloads. Successful Dodge positions come from authoritative actor state. Critical Stagger locks the existing player movement adapter until its simulation-time expiry. The same configured simulation remains compatible with the existing sequence-numbered two-client observer harness.

Release builds enqueue scheduled events before evaluating the uniqueness assertion. Godot strips `assert` expressions from release exports, so queue mutation must never be embedded inside an assertion. The Web Single-Threaded browser check verifies that the AT 2 completion event still fires and reaches ACC, defenses, damage, and HPC presentation.

## Task 15 extension

Task 15 keeps this same authority boundary and adds a deterministic two-way encounter driver, explicit `START`/`RESET`, player defeat/victory, legal one-Act standing and clearer actor-specific event presentation. See `TWO_WAY_COMBAT_ENCOUNTER.md`.

## Deliberate limits

- The opponent's Task 15 behavior is a fixed, labeled encounter script rather than general AI. It initiates the same ordinary attack only when authoritative legality succeeds.
- Out-of-range approach is blocked because no authoritative navigation path is authored; the opponent never teleports or infers terrain from presentation pixels.
- Battle Axe in-place duck eligibility remains unresolved; displacement candidates remain legal and deterministic.
- Rare shield-contact prone is unavailable when exact contact is not verified, and the log reports that boundary.
- Backfire and Dwarvestek/Grentek remain blocked behind their existing verification gates.
- Defeat is displayed and further targeting/attacks are rejected. No death flow, loot, EXP, progression, respawn, or match result is invented.
- This fixture is not Phase 1 production-character acceptance. Aren/Garrick and production item imports still require independent source audits.
