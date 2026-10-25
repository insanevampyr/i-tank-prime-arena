# Playable Combat Vertical Slice

## Authority boundary

Phase 1 Task 14 connects the temporary Arena scene to one `CombatSimulation`. `ArenaCombatSession` is an intent and orchestration adapter: it selects an existing target, samples the canonical movement position when an attack is requested, advances deterministic simulation time, submits the existing automatic-defense transaction, and invokes the existing physical-damage transaction only after defenses are exhausted. It does not calculate ACC, AT duration, defense eligibility, criticals, damage, TAL, NAL, SHP, or HPC.

Desktop left-click, keyboard Space/Enter, and touch ATTACK all call the same `request_player_attack` boundary. A desktop press on a living opponent selects it and requests one ordinary attack; Task 31N retains mouse intent while held. A touch tap selects only, preserving the separate mobile ATTACK control. Task 31M/31N may retain keyboard, mouse and touch intent locally, but duplicate input remains rejected while the player attack is in flight. Visual positions, labels, and animation never decide an outcome.

## Source-verified fixture

Production Aren/Garrick definitions are still unavailable. The scene therefore labels both combatants as **verified Prime V3 fixtures**, not production characters. The fixture transcribes:

- the Prime V3 Uncommon Guard attribute/derived-stat block (pp. 350-351);
- Battle Axe: three-foot range, `2d10 + 3` Slashing, BLK 2, Strength Bonus eligible, natural 1-2 critical-success range (Prime V3 weapon chart, p. 122);
- Plate torso armor: TAL 3 against Bashing/Slashing/Piercing (Prime V3 armor chart, p. 133);
- Metal Buckler: BLK 2 and 20 SHP (Prime V3 shield chart, p. 134).

Task 14 combines those verified rows only as a controlled integration fixture. It does not claim that this assembled loadout is Aren Valecrest, Garrick Ironward, or a saved production character.

Task 22 moves those values into reusable Godot Resource definitions and a validated loadout catalog. Player and opponent remain independent instances of the same definition, while mutable HPC, conditions and equipment durability remain simulation state. The printed Uncommon Guard uses Leather and does not list the buckler; Plate plus Metal Buckler remains an approved assembled Arena test loadout rather than a printed NPC loadout. See `CHARACTER_EQUIPMENT_FOUNDATION.md`.

## Playable flow

1. The scene initializes both actors, their equipment/protection/defense profiles, critical-reaction registrations, positions, seeded RNG, and opening Initiative in the authority.
2. The opponent is selected by default. Left-clicking it selects and requests one attack; tapping it or pressing Tab/Shift+Tab selects only. Clicking/tapping empty arena space clears selection. Desktop top-row and keypad 1-9 select a Prime aim location without attacking or consuming an Act.
3. The player moves with WASD, equivalent arrow keys, or the touch joystick through the same movement and Running path. Mixed keyboard inputs are normalized. At attack input, the adapter submits the current canonical player position to the combat authority.
4. The authority validates alive state, equipped Battle Axe, selected source-supported location, opening Initiative, and action availability. The target actor and aim location are copied into the attack instance at declaration, so later selection changes cannot retarget an executing action. Ordinary melee reach and obstruction are checked at final resolution rather than prohibiting an approach-attack declaration.
5. One Act executes at the fixture's AT 2, so ACC occurs after exactly 2.5 simulation seconds.
6. An ACC hit enters the existing ordered Dodge, weapon Block, shield Block, and Physical Soak pipeline. The open fixture arena supplies bounded, collision-free, unoccupied, hazard-free Dodge candidates; no in-place duck is supplied because Battle Axe duck eligibility is unresolved.
7. If defenses are exhausted, the existing exact damage transaction applies Battle Axe dice plus eligible SB, approved critical factors, Plate TAL, NAL, and HPC once.
8. The player-facing log renders important authoritative attack, defense, damage, critical, condition and interruption results. F3 toggles a hidden developer overlay containing timing, path status and the more detailed authoritative event transcript.

## Deterministic presentation

The session never rolls locally. Event-log text is derived from immutable `CombatEvent` payloads. Successful Dodge positions come from authoritative actor state. Critical Stagger locks the existing player movement adapter until its simulation-time expiry. The same configured simulation remains compatible with the existing sequence-numbered two-client observer harness.

Release builds enqueue scheduled events before evaluating the uniqueness assertion. Godot strips `assert` expressions from release exports, so queue mutation must never be embedded inside an assertion. The Web Single-Threaded browser check verifies that the AT 2 completion event still fires and reaches ACC, defenses, damage, and HPC presentation.

## Task 15 extension

Task 15 keeps this same authority boundary and adds a deterministic two-way encounter driver, explicit `START`/`RESET`, player defeat/victory, legal one-Act standing and clearer actor-specific event presentation. See `TWO_WAY_COMBAT_ENCOUNTER.md`.

## Task 18 usability extension

Task 18 adds desktop click-to-attack without queued Acts, keeps touch selection separate from ATTACK, reduces the default HUD to play-relevant state, and moves technical detail behind F3. Task 31M later adds bounded hold intent to keyboard/touch ATTACK while preserving one-shot mouse clicks. Task 18 also validates the blue Task 3 movement-test profile against the Guard fixture before play. See `COMBAT_USABILITY_AND_PURSUIT.md`.

## Task 19 readiness extension

Task 19 adds passive ATTACK and RUN rings sourced from the existing action, legality and movement snapshots. The attack countdown uses the linked action's actual scheduled start/effect timestamps; the Running ring uses actual endurance, recovery and retry state. These controls do not issue intents or add cooldowns. Movement and Running remain legal during actions where existing rules permit, and final range/line-of-sight validation still precedes ACC. See `COMBAT_READINESS_HUD.md`.

Task 31M lets Space, Enter, and touch ATTACK retain local held intent; Task 31N extends that presentation behavior to left mouse held on a living enemy. The next ordinary attack is submitted only at an exact authoritative legality boundary; releasing one source does not cancel an action already executing or another held source. Empty terrain, HUD/text input, focus loss and mouse cancellation cannot leave a retained mouse attack. No held input changes AT, queues an Act, bypasses final geometry, or adds an auto-attack state to simulation/replay.

## Task 32A Wave 2 development encounter

While READY, cycle the encounter selector to `WAVE 2`, optionally enter an authoritative seed, and press START. The seeded d3 creates one to three independent source-backed Common Spadoodles. Existing mouse/touch selection, Tab/Shift+Tab, numbered aim locations, held attack inputs, movement/Running controls, target locking, final reach/LOS validation, defenses, damage, criticals, HPC labels, FULL LOG and RESET remain on their existing pathways. Brown-gold `S` markers distinguish Spadoodles from green `G` Goblins. The encounter ends only after every registered Spadoodle is genuinely defeated; it does not auto-advance.

## Task 32B Wave 3 development encounter

While READY, cycle the encounter selector to `WAVE 3`, optionally choose an authoritative seed, and press START. One seeded d2 creates one or two source-backed Common Skellys and the roster always includes one fixed Uncommon Hades Combat Follower. Bone `K` and purple `H` markers distinguish them. Skellys pursue and resolve two independent claw strikes in each AT-1 Act. The follower moves while legal actions execute and deterministically selects among Rage, Rejuvenating Mist, dirt preparation plus Defensive Buff, Called Shot and its verified Short Sword attack according to current authoritative state. FULL LOG records the actual recipient, independent daily-use or one-AP payment, stat changes, healing rolls, touch/material prerequisites, Called Shot coverage and Rage knockback. Fresh encounters and RESET begin full; these Ability resources persist across continuous waves until an authoritative game-world-midnight refresh. All existing target selection, nine-location aiming, held attack controls, movement/Running, final reach/LOS, defenses, damage, criticals, labels and RESET use the same authoritative paths. Victory requires every Wave 3 actor defeated and does not begin Wave 4.

## Deliberate limits

- The opponent's Task 15 behavior is a fixed, labeled encounter script rather than general AI. It initiates the same ordinary attack only when authoritative legality succeeds.
- The Task 16 battlefield supplies deterministic authoritative navigation for this one arena. The opponent declares through the same authority when otherwise eligible, approaches through legal paths during AT execution, and reaches ACC only when final range and line of sight are legal; it never teleports or infers terrain from presentation pixels.
- Battle Axe in-place duck eligibility remains unresolved; displacement candidates remain legal and deterministic.
- Prime location 8 uses the approved Arena alternating selection: Knee, then Lower Leg. The declared subdivision selects knee armor or leg armor exclusively; their TAL never stacks.
- Rare shield-contact prone is unavailable when exact contact is not verified, and the log reports that boundary.
- Backfire and Dwarvestek/Grentek remain blocked behind their existing verification gates.
- Defeat is displayed and further targeting/attacks are rejected. No death flow, loot, EXP, progression, respawn, or match result is invented.
- This fixture is not Phase 1 production-character acceptance. Aren/Garrick and production item imports still require independent source audits.

## Task 35I Wave 5 and Test Mode controls

The default Arena now opens in `NORMAL / WAVE 1`. While READY, the encounter selector cycles through temporary `TEST MODE / WAVE 1` to `WAVE 5`, followed by the Guard and Synthetic Small regression fixtures. Select the player and seed, choose a wave, then press START. RESET reconstructs the chosen temporary run from its verified fixture; after RESET the selector can choose another wave. The same visible controls are used in desktop and Web builds, with no console command or URL parameter.

Wave 5 presents one red-brown `W` Rare Human Warrior with authoritative HPC and facing. His committed Task 35H controller may use spear melee, the verified throw/drop/retrieval path, one-strike unarmed fallback, potions and Combat 1-3 actions according to current authoritative state. All movement, timing, targeting, defenses, damage, effects, inventory and RNG remain in the existing combat engine. FULL LOG retains detailed tactical and world-item evidence. A small outlined spear marker now appears at the authoritative dropped position and disappears on legal retrieval or RESET; it is presentation-only.

Normal NEXT WAVE now preserves resources and advances the complete Wave 1-to-5 circuit without replacing `CombatSimulation`. Each defeated roster is retired from action, occupancy, targeting and AI while its history remains in schema-12 snapshots. Arriving enemies are batch-registered with their existing official fixtures and receive fresh Initiative draws from the continuing RNG stream; the player is neither rebuilt nor rerolled. Solo downtime remains unlimited and explicit, duplicate advancement is rejected, and Wave 5 requires one final acknowledgement before completed-run victory. Direct Test Mode launch and RESET for every wave remain independent and functional.
