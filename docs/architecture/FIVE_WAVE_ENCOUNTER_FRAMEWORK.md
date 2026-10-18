# Deterministic Five-Wave Encounter Framework

## Scope

Task 31B introduces configuration and authoritative lifecycle state only. It does **not** add creatures, monster statistics, spawn logic, enemy behavior, simulated victories, or a player-facing five-wave launcher. The existing Guard-versus-Guard encounter remains the default playable regression fixture.

## Approved roster configuration

| Wave | Configured roster | Quantity authority |
| --- | --- | --- |
| 1 | Common Goblin | authoritative `1d4` |
| 2 | Common Spadoodle | authoritative `1d3` |
| 3 | Common Skelly; Hades Combat Follower | authoritative `1d2`; fixed one |
| 4 | Mini Gargoyle Swarmer | authoritative `1d4` |
| 5 | Rare Human Warrior | fixed one |

The catalog identifies creatures and count rules only. It intentionally contains no attributes, equipment, attacks, defenses, movement, behavior, or presentation assets.

## Lifecycle

`ArenaWaveStateMachine` owns the deterministic state contract:

`uninitialized -> blocked_creature_integration -> active_combat -> victory_detected -> between_wave_recovery -> blocked_creature_integration`

After the fifth verified victory, the circuit transitions directly to `complete`; there is no post-circuit recovery phase. A wave becomes `active_combat` only when future creature integration has explicitly registered every roster type and supplied exactly the already-resolved number of real authoritative enemy actor identifiers. The session then detects victory only when every bound actor has authoritative HPC at or below zero.

With no creature integrations in Task 31B, every initialized wave deliberately stops at `blocked_creature_integration`. It cannot start the legacy Guard duel, skip a wave, or fabricate a victory.

## RNG, events, snapshots, and replay

The session resolves dice quantities with `CombatSimulation.roll_int`. Every dice result records its draw index and every fixed quantity is recorded as non-random in the retained event history. The framework emits `arena_wave_*` events for circuit initialization, quantity resolution, blocked availability, activation, verified victory, recovery start/application, and completion.

The current wave state is copied into the simulation snapshot before publication. Therefore the normal replay history, authoritative event IDs/timestamps/order, and existing two-client envelopes/digests carry the same state; no side channel or presentation timer owns wave state.

`reset_five_wave_arena()` rebuilds the ready Guard fixture and then creates a fresh wave circuit with the original seed. It replays the same quantity draws and wave event sequence. Ordinary `reset_encounter()` remains the Guard-duel reset and clears any opt-in wave framework.

## Recovery boundary

Between non-final waves, the player restoration call uses only existing actor state:

- `current_hpc` is restored from the registered `hpm` combat stat.
- Each resource in the definition's `resource_maxima` dictionary is restored to its registered maximum. This includes Mana, AP, and ability-use entries only when those entries actually exist in the definition.

The framework does not invent absent resource pools, reset equipment, repair shields, remove conditions, refund unmodeled consumables, or interrupt an action in progress.

## Future integration seams

Future creature work must explicitly register creature availability, spawn and bind real authoritative actor IDs, and call the existing victory evaluator after actor-state changes. Lighting, stealth, flight, and individual creature integration remain named extension points only; they have no Task 31B behavior.
