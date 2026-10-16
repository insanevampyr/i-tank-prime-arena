# Task 20 Playtest Quality and Combat Logs

## Authority boundary

The Task 20 work changes input feedback, the controlled opponent driver, and presentation only. `CombatSimulation` remains authoritative for action timing, final range/line-of-sight checks, ACC, defenses, damage, RNG, events, and state mutation. The transcript reads resolved events and cannot schedule actions or consume RNG.

## Approach-capable Battle Axe

Arena Combat Specification v1.8 section 18 explicitly marks the current Battle Axe fixture as `APPROACH_CAPABLE`. Player and opponent may declare its ordinary melee attack while outside three-foot reach or while an obstacle initially blocks line of sight. Other declaration prerequisites still apply. The actor may Walk or legally Run during the AT 2 execution interval. Immediately before ACC, the simulation rechecks three-foot reach and line of sight. Failure records `physical_attack_final_legality_failed`, consumes the elapsed action time, and rolls no ACC.

The ATTACK readiness indicator therefore reports `READY / APPROACH`, not `OUT OF RANGE`, for this fixture. A rejected declaration now displays the actual blocking reason. A final geometry failure displays that the action finished but ACC was not rolled.

## Sustained pursuit correction

The former controlled opponent driver followed deterministic paths but always spent only baseline MR 12. Task 20 moved it to the same `PrimeMovementModel` as the player with the fixture's documented SPD 12, END 10, three Running investments, SCM 0, and RB 0. Task 25 applies the equipped Plate torso's verified MR -1 to both actors: walking MR is 11 and automatic legal Running is MR 17. The driver still obeys the 50-second duration cap, accrues equal recovery debt, and falls back to walking during recovery. It receives no artificial speed, free MR, or teleportation.

Path selection still uses current authoritative target position, obstacle/occupancy facts, one-foot deterministic navigation nodes, and stable tie-breaking. A one-foot target displacement rebuilds the route; a collision invalidates the route for a deterministic rebuild. The driver stops Running at legal attack geometry, while blocked, staggered, prone, or not executing an approach attack. F3 displays driver state, rebuild count, and the Running/recovery snapshot.

## Encounter transcript

`FULL LOG` or F4 opens a collapsible, scrollable transcript. It is generated from every resolved authoritative event in the current encounter, not the eight-line recent-results view. Each UTF-8 line includes timestamp, event ID, stable sequence, INIT, event type, participants, causal parent/dependencies, resource commitments, and payload/roll evidence. The header includes build, Godot version, seed, fixture ID, transcript schema, simulation schema, and event count.

Retention is explicit: the full current encounter remains available until RESET; RESET starts a new transcript. The compact `RECENT RESULTS` panel intentionally retains only eight player-facing summaries and labels itself accordingly.

- Desktop `COPY LOG` writes the complete transcript to the system clipboard. `SAVE LOG` writes to Godot's safe per-user `user://encounter_logs` directory and reports the resolved local path only to the local player.
- Web `COPY LOG` requests `navigator.clipboard.writeText` from the button's user gesture. Success or denial is reported. If denied or unavailable, use `SAVE LOG`.
- Web `SAVE LOG` invokes Godot's browser download API and downloads a UTF-8 `.txt` file. The exported transcript contains no local filesystem paths.

## HUD readability

When combatants are within 150 presentation pixels, the player label moves above-left and the opponent label above-right. At wider separation both use centered labels. This is presentation-only and does not affect authoritative distance or targeting. FULL LOG and DEBUG are collapsed by default; readiness rings, START/RESET, touch controls, and the recent results remain available.
