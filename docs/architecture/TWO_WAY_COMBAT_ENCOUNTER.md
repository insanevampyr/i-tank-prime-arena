# Two-Way Controlled Combat Encounter

## Scope and authority

Phase 1 Task 15 extends the Task 14 presentation adapter; it does not add a second combat engine. `ArenaCombatSession` submits both combatants' legal intents to one `CombatSimulation`, advances only deterministic integer simulation time, and invokes the existing ACC, defense, damage and approved-critical transactions. The scripted opponent never rolls, applies damage, chooses a defense, or mutates HPC outside that authority.

The opponent is explicitly identified as `task15_deterministic_test_opponent`. It is a controlled fixture driver, not a general enemy AI system.

## Pre-combat fixture validation

Both actors use the same source-labeled Task 14 fixture. Before either actor is registered, validation requires all core/combat fields plus the exact equipped weapon, shield and armor references. It checks the Prime V3 source rows used by the fixture:

- Uncommon Guard values from pp. 350-351;
- Battle Axe STR 12, three-foot range, two-handed below STR 24, BLK 2 and `2d10 + 3` Slashing from p. 122;
- Plate torso STR 16 and TAL 3 versus Bashing/Slashing/Piercing from p. 133;
- Metal Buckler STR 8, BLK 2, 20 SHP and `2 Hands Free` from p. 134.

The guard's STR 16 satisfies the axe, buckler and torso-plate requirements. The axe remains two-handed; the buckler's printed two-free-hands property keeps that use legal. Any missing/mismatched requirement fails fixture initialization instead of substituting a statistic.

## Deterministic behavior priority

At every authoritative decision boundary, the scripted opponent applies this stable priority:

1. Stop if the encounter is inactive, either combatant is defeated, or actor data is unavailable.
2. Wait while unaware, critically staggered, or already executing/finalizing an attack.
3. If prone, request the existing one-Act standing action.
4. If alive, aware, equipped and otherwise action-eligible, request the same ordinary Battle Axe attack used by the player; current reach or obstruction does not prohibit this ordinary approach-attack declaration.
5. During AT execution, if current geometry is not legal, request a deterministic path and spend actual MR while approaching. At final resolution, require legal three-foot reach and line of sight before ACC.

The original Task 15 boundary remains for sessions that do not supply authoritative navigation facts: they expose `approach_blocked_unverified_path`. Task 16 supplies those facts only for its documented test arena; the opponent never treats visual pixels as authority. See `BATTLEFIELD_MOVEMENT_FOUNDATION.md`.

Opening Initiative remains `1d10 + INIT`. A lower opening rank waits for the higher rank's declaration without an invented time delay. Once legally released, both actions can begin at the same simulation timestamp and execute concurrently. After opening, ordinary attacks continue sequentially at the existing `5 seconds / AT` cadence. Critical Reactions remain separate zero-Act events.

## Encounter lifecycle

The scene prepares the fixture in `READY` at simulation time zero. `START` enables simulation advance and scripted behavior. `RESET` replaces the owned simulation with the same seed and original positions, rebuilds both fixture actors, restores clock/RNG/action/event state, clears presentation history and returns to `READY`. A second `START` begins the identical seeded encounter.

Space/Enter and touch ATTACK still share one player-intent boundary. If the player is prone, that input requests the existing one-Act stand rather than an illegal attack. `R` performs the same reset operation as the mouse/touch button. Duplicate inputs remain single-flight.

Victory, defeat and double defeat are derived only from authoritative HPC after all due same-timestamp effects have resolved. The encounter then stops accepting or generating ordinary actions. No loot, EXP, death flow, respawn, matchmaking or general AI is attached.

## Presentation and synchronization

The HUD distinguishes player/opponent attack, ACC, defense, damage, critical, stagger, prone, interruption and stand records. Compact text is derived from immutable authoritative events; the full event transcript remains available to replay/synchronization diagnostics. The session's deterministic two-way transcript and state snapshot converge through the existing duplicate/out-of-order two-client harness.

The UI supports mouse/touch `START` and `RESET`, keyboard/touch attacks, WASD/Shift and joystick/RUN. Web Single-Threaded remains the export target. Browser verification is separate from physical Android-device verification.

## Deliberate limits

- Out-of-range opponent approach is enabled only in the Task 16 authored battlefield; unauthored maps remain fail-closed.
- Player and opponent presentation now follow the same authoritative micro-foot positions and collision facts. The temporary player Running skill investment remains a labeled test-profile value rather than production Aren data.
- Backfire and Dwarvestek/Grentek effects remain behind their existing verification gates.
- No Specials, NAC abilities, general AI, hazards, loot, EXP, progression, real networking or Android package is introduced.
