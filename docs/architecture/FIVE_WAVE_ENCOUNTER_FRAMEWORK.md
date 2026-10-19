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

## Task 31C: implemented Wave 1 Common Goblins

Wave 1 is now the sole playable wave. Its `1d4` count is still drawn by the existing seeded `CombatSimulation` RNG and retained as `arena_wave_quantity_resolved` evidence. The session registers one independent authoritative `Common Goblin` actor per resolved result, activates Wave 1 with those exact actor IDs, and uses the normal combat event, action, defense, damage, defeat, snapshot, replay, and two-client synchronization paths.

The reusable source-backed definition is `data/characters/prime_v3_common_goblin.tres`; the associated natural-fist attack data is `data/equipment/weapons/prime_v3_common_goblin_fists.tres`. The character resource records `Small` as a Task 31C designer ruling rather than a sheet value. Each Goblin uses MR 6 walking pursuit only; Task 31C does not issue Running requests because no Running investment is printed. Its one-foot fists are not marked approach-capable, so the existing deterministic behavior moves to legal reach before it declares an ordinary attack. The approved two-fist behavior is represented as two ordered attack instances attached to one AT-1 action: each fist independently verifies final legality and resolves ACC, defenses, damage and legitimate criticals without creating a second Act.

The existing player target list, Tab cycling and numbered hit locations operate across all living Goblin IDs. The current test scene adds compact `#32864A` green-square Goblin markers with white `G` glyphs and individual HPC labels for Wave 1 through its pre-existing development encounter selector; `DUEL M/M` and `DUEL M/S*` remain intact. The selector's `WAVE 1` option is a development encounter control, not a production creature-selection interface.

After the final active Goblin reaches zero authoritative HPC, the state machine records `arena_wave_victory_detected`. The playable encounter reports victory and stops; it deliberately does not enter recovery or advance into the unimplemented Wave 2 roster. The source's leader-defeat scattering statement is also deferred because no verified leader actor or morale rule has been integrated.

### Battlefield assessment and deferred Wave Arena configuration

The retained Guard test battlefield is `44 x 23` feet (`x=2..46`, `y=2..25`) with one central wall. Wave 1's current deterministic four-Goblin maximum is legal there, but its fixed spawn offsets occupy only a `2 x 2`-foot cluster. That is adequate for exercising independent actors and targeting, not a meaningful multi-direction encounter. A separate, presentation-aware Wave Arena is recommended as the next bounded task: `64 x 36` feet, preserving the one-foot canonical grid and the original Guard map, with four fixed legal spawn anchors roughly 8–12 feet around the player and an explicit camera/layout fit for desktop and landscape mobile. It is intentionally deferred because the existing battlefield view always draws the Guard geometry; changing only simulation bounds would desynchronize presentation from authoritative geometry.

## Task 31D: fractional-position pursuit correction

Task 31D profiling isolated the Wave-1 slowdown to repeated failed path searches, not the simulation clock, event history, snapshots, replay, wave state machine, or two-fist scheduling. Common Goblins have only one-foot reach. When their continuously moving target occupied a fractional-foot position, no whole-foot navigation node could be both collision-legal and within that reach. Each pursuing Goblin therefore exhausted the 10,000-node search bound again on each rendered frame.

The battlefield now builds stable exact attack-position candidates at the verified reach around the current authoritative target. Breadth-first search still uses the existing deterministic whole-foot navigation graph, then appends a collision-checked, line-of-sight-checked exact final waypoint. Movement remains continuous and charged through the existing MR ledger; this does not resample or suppress events, alter combat timing, or change reach. The hidden developer overlay also avoids rebuilding its complete diagnostic snapshot until opened; this is presentation-only.

Health presentation now obtains maximum HPM from the registered actor definition and current HPC from mutable actor state. The selected-opponent label and every individual Goblin label therefore retain their source maximum after damage or defeat.

## Task 31E: independent Initiative and moving-target pursuit

The controlling Arena Option B ruling retains each actor's opening `1d10 + INIT` record but removes the former first-declaration rank gate. Wave-1 Goblins therefore approach and attack whenever independently legal even if the player never attacks or rolled higher Initiative. Ordinary action duration remains `5 / AT`; INIT still orders genuinely simultaneous queued effects.

Moving-target pursuit preserves Task 31D's whole-foot graph and exact final attack waypoint. When the target moves, the session first translates that final waypoint by the authoritative target displacement and revalidates the final segment, collision, one-foot fist reach and LOS. A whole-route rebuild occurs only when this continuity update is illegal or no route remains. Goblins also reserve separate legal attack destinations where available, preventing multiple actors from repeatedly steering toward one stale point. No MR, collision, attack reach, event emission or combat formula changes.

Combat-log attack labels now use the authoritative declaration's weapon reference. The Guard remains `Battle Axe`; Common Goblin declarations display `Fists` with `1/2` or `2/2` so both strikes in the single Act are distinguishable.

## Task 31G: obstacle-aware route invalidation

Crowded pursuit around the center wall exposed a cache defect rather than a navigation-grid defect. An actor-limited partial move could leave a Goblin off its cached segment; if the next requested segment was then blocked by static geometry, the session retained that unusable route because the collision still produced positive movement. Goblins could consequently keep pressing into the wall instead of requesting a new legal route.

The session now distinguishes temporary actor blocking from a segment blocked by battlefield geometry. Only a static-geometry collision invalidates the cached route and releases its reserved attack destination; the next authoritative behavior tick rebuilds from the Goblin's actual position. Failed full searches are cached against the mover, target, reach, actor occupancy and destination reservations, so an unchanged sealed route does not repeat the bounded 10,000-node search. Any relevant position or reservation change produces a different signature and permits reconsideration. Whole-foot pathfinding, the exact fractional final waypoint, MR expenditure, collision, event emission, attack timing and replay contracts are unchanged.

## Task 31H: direct waypoint legality and reproducible seed control

The remaining wall-end stall was caused by using axis-separated motion resolution as a direct-segment predicate. `resolve_motion()` intentionally tries X and then Y so normal movement can slide against collision. A path shortcut could therefore reach a candidate through an implicit L-shaped route, return only the final diagonal waypoint, and send the Goblin directly into the wall corner. Navigation construction, cached final-waypoint retargeting and cached-segment validation now use one footprint-aware straight-segment predicate. The whole-foot route keeps its intermediate corner-clearance nodes until the exact fractional attack destination can be reached directly. Failed-route caching, destination reservations, continuous MR accounting and the complete authoritative position-event history are unchanged.

The Arena development HUD now shows the active simulation seed and accepts a signed 64-bit seed before START. Applying a valid value rebuilds the selected ready fixture with that RNG seed; invalid values fail closed, and the control is disabled after combat starts. RESET recreates the encounter with the same selected seed for reproducible retesting. FULL LOG, COPY LOG and SAVE LOG identify the actual simulation seed rather than a presentation-only value. The default remains seed 1 and the Wave-1 count is still resolved solely by the existing authoritative `1d4` draw.

## Task 31I: seed setup focus and combat HUD separation

Seed editing is now explicitly a READY-state setup surface. START hides the editable field and APPLY button, releases their GUI focus and retains only the read-only authoritative seed label. RESET reconstructs the same seeded encounter and restores the editable controls. The existing simulation-level READY gate still rejects direct seed mutation during active combat.

Active Tab and Shift+Tab target cycling is handled before Godot GUI focus traversal, so setup controls cannot consume combat target input. READY keeps normal LineEdit focus for entering a signed 64-bit seed. Mouse and touch selection continue through the unchanged target-selection path.

Responsive HUD metrics keep seed setup, movement state and combat status in separate vertical regions. The combat-status column is capped to the left safe area and the readiness/recent-results column is moved farther right, preventing the reference desktop actor labels from sharing those text regions. This is presentation-only and does not change authoritative positions, events, RNG or combat state.

## Task 31J: defeated occupancy and responsive battlefield presentation

The remaining seed-7 lock was caused by defeated actors remaining in the shared authoritative occupancy dictionary. Their former positions could collision-limit player motion to zero and could also remain in surviving Goblins' route facts even though defeated Goblins no longer act or reserve destinations. Occupancy now excludes actors whose authoritative HPC is at or below zero, and the Goblin behavior pass releases the defeated actor's cached path, target, attack-position reservation and failed-route cache. Living actors still use the same collision radius, occupancy checks and deterministic movement rules.

The test scene now calculates a presentation-only pixels-per-foot value from the available viewport using a stable `48 x 27`-foot display envelope around the unchanged `44 x 23`-foot authoritative Arena. The battlefield drawing, combatant positions, actor markers and target indicator share that conversion. At the original `1152 x 648` reference viewport the scale remains 24 pixels per foot; a `1920 x 1080` viewport uses 40 pixels per foot, while smaller viewports scale down to retain the complete Arena. No authoritative coordinate, obstacle, collision, MR, reach, LOS or event contract changes, and no scrolling or following camera is introduced.

Task 31J performance evidence did not justify another simulation or presentation optimization. Five simulated seconds with four active seed-7 Goblins remained bounded, with six total route builds and complete movement events. The incremental event cursor, hidden-by-default diagnostic serialization, failure cache and transcript cache remain unchanged.

## Task 31K: bounded HUD and facing presentation

The combat-status summary and recent-results stream now render inside separate clipped, scrolling or ellipsized dark panels. The selected Wave-1 actor uses a concise presentation name such as `GOBLIN 4`; authoritative actor IDs and the complete event transcript remain unchanged in FULL LOG. The right results lane is capped at 460 logical pixels on enlarged desktop viewports while the battlefield continues using the Task 31J responsive scale.

A small magenta arrow is always visible beside each living presented actor. Its rotation reads `CombatActorState.facing_millidegrees`; it is not derived from local visual motion. Existing voluntary player and scripted opponent/Goblin movement update that field to the accepted authoritative displacement direction, while a zero displacement retains the previous facing. The arrow sits outside the actor, target-outline and HPC-label footprints, scales with the actor presentation, and is hidden for defeated or removed actors. DEBUG and FULL LOG visibility do not control it. The indicator has no collision, selection, attack, perception or event behavior. Independent facing input, strafing, turning costs and facing-based combat rules remain deferred under the v1.19 boundary.

## Task 31L: measured navigation cost and actor-anchored health labels

Seed 7 profiling with four Goblins and a continuously moving player isolated the visible hitch to navigation route rebuilds. The direct-segment predicate previously reached the exact 0.1-foot sampled collision resolver for every candidate segment. Searches around the center wall therefore repeated that sampled work across many whole-foot nodes. The battlefield now performs conservative segment-versus-expanded-obstacle and segment-versus-actor broad-phase checks: definite collisions fail immediately, definitely clear segments pass immediately, and a narrow boundary band still uses the original exact sampler. This changes neither the navigation graph nor authoritative movement-event retention, MR, timing, reach, LOS, RNG, replay or synchronization contracts.

The reported long Goblin pause was not reproduced as a living actor navigation deadlock. In the deterministic Seed 7 scenario, living Goblins that were out of range, had movement available, and had no action, attack, stagger or prone restriction remained stationary for at most one 100 ms behavior tick. Longer stationary periods corresponded to legal action execution, movement exhaustion, or defeat; defeated actors remain excluded from occupancy by Task 31J.

Player, Guard, Synthetic Small and Wave-1 Goblin health labels are direct children of their actor visuals and use one fixed centered anchor above the actor. They move and scale with the same pixels-per-foot presentation transform as their owner. A small screen-edge clamp prevents clipping without searching for an alternate battlefield position; labels are never relocated to avoid actors, walls, hazards, HUD panels or other labels. Minor overlap during dense clustering is an accepted presentation tradeoff in favor of stable actor association. Labels use compact actor identifiers, authoritative current HPC over immutable source HPM, semitransparent identification colors and pointer-ignored controls. Defeated or removed actors lose their label, and RESET reconstructs it from authoritative state. Rendering never alters authoritative positions, events, RNG or selection rules.

Floating combat feedback uses a two-second presentation lifetime for ordinary and important results, including misses, defenses, damage, critical results and failed defenses. The existing movement and final fade remain proportional to that lifetime. Clearing or resetting the encounter removes outstanding messages immediately. This is local presentation timing only and does not change action timing, events, RNG, replay or the persistent transcript.
