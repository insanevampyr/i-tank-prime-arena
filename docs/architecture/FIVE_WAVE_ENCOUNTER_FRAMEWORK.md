# Deterministic Five-Wave Encounter Framework

## Scope

Task 31B introduced the configuration and authoritative lifecycle state. Tasks 31C-33B subsequently integrated independently playable Waves 1-4, and Tasks 35I-35J integrated Wave 5 plus continuous transitions. Task 35B established the shared between-wave boundary. Task 36A adds temporary within-run XP, Random Drops and physical loot without permanent profiles or networking. The Guard-versus-Guard encounter remains an independent regression fixture.

## Approved roster configuration

| Wave | Configured roster | Quantity authority |
| --- | --- | --- |
| 1 | Common Goblin | Prime baseline `1d4`; Arena override `2d4` |
| 2 | Common Spadoodle | authoritative `1d3` |
| 3 | Common Skelly; Hades Combat Follower | authoritative `1d2`; fixed one |
| 4 | Mini Gargoyle Swarmer | authoritative `1d4` |
| 5 | Rare Human Warrior | fixed one |

The catalog identifies creatures and count rules only. It intentionally contains no attributes, equipment, attacks, defenses, movement, behavior, or presentation assets.

## Lifecycle

`ArenaWaveStateMachine` owns the deterministic state contract:

`uninitialized -> blocked_creature_integration -> active_combat -> victory_detected -> between_wave_downtime -> blocked_creature_integration`

Every verified victory, including Wave 5, enters safe downtime. A solo player advances with one explicit NEXT WAVE request; the final request completes the circuit. A future multiplayer host may supply authoritative real-time deltas to a separate 120-second deadline interface. Those deltas never advance combat simulation time. A wave becomes `active_combat` only when creature integration has explicitly registered every roster type and supplied exactly the already-resolved number of real authoritative enemy actor identifiers. The session detects victory only when every bound actor has authoritative HPC at or below zero.

With no creature integrations in Task 31B, every initialized wave deliberately stops at `blocked_creature_integration`. It cannot start the legacy Guard duel, skip a wave, or fabricate a victory.

## RNG, events, snapshots, and replay

The session resolves dice quantities with `CombatSimulation.roll_int`. Every dice result records its draw index and every fixed quantity is recorded as non-random in the retained event history. The framework emits `arena_wave_*` events for circuit initialization, quantity resolution, blocked availability, activation, verified victory, downtime start, explicit/deadline advancement, and completion.

The current wave state is copied into the simulation snapshot before publication. Therefore the normal replay history, authoritative event IDs/timestamps/order, and existing two-client envelopes/digests carry the same state; no side channel or presentation timer owns wave state.

`reset_five_wave_arena()` rebuilds the ready Guard fixture and then creates a fresh wave circuit with the original seed. It replays the same quantity draws and wave event sequence. Ordinary `reset_encounter()` remains the Guard-duel reset and clears any opt-in wave framework.

## Safe downtime and persistence boundary

Downtime performs no implicit actor mutation:

- Current HPC, Mana, applicable AP, equipment references, hand/material state, conditions, timed effects, daily-use counters and persistent shields remain exact.
- The combat clock does not advance, so timed effects neither expire nor replenish while waiting.
- Recovery can occur only through a separately legal item, Special or skill action with its normal costs and limits.
- Solo downtime is unlimited. Multiplayer's future-compatible deadline accepts authority-owned elapsed real time; it is not derived from a client clock and does not spend combat time.
- Advancement is idempotent: once committed, another NEXT WAVE/deadline request cannot advance again.

The deprecated automatic-restoration entry point fails closed. RESET still reconstructs the selected deterministic fixture from its starting definition; it is not a persistent character operation. Task 36A inventory and XP exist only inside the current normal five-wave simulation. Permanent profiles, saves and cross-run progression remain separate future work.

## Future integration seams

Future creature work must explicitly register creature availability, spawn and bind real authoritative actor IDs, and call the existing victory evaluator after actor-state changes. Lighting, stealth, flight, and individual creature integration remain named extension points only; they have no Task 31B behavior.

## Task 31C: implemented Wave 1 Common Goblins

Wave 1 remains an independently selectable playable wave. Prime V3's `1d4` baseline is superseded for this Arena encounter by the Task 31O `2d4` quantity override. Both d4s use the existing seeded `CombatSimulation` RNG; their ordered results and draw indexes plus the resolved sum are retained as `arena_wave_quantity_resolved` evidence. The session registers one independent authoritative `Common Goblin` actor per resolved result, activates Wave 1 with those exact actor IDs, and uses the normal combat event, action, defense, damage, defeat, snapshot, replay, and two-client synchronization paths.

The reusable source-backed definition is `data/characters/prime_v3_common_goblin.tres`; the associated natural-fist attack data is `data/equipment/weapons/prime_v3_common_goblin_fists.tres`. The character resource records `Small` as a Task 31C designer ruling rather than a sheet value. Each Goblin uses MR 6 walking pursuit only; Task 31C does not issue Running requests because no Running investment is printed. Its one-foot fists are not marked approach-capable, so the existing deterministic behavior moves to legal reach before it declares an ordinary attack. The approved two-fist behavior is represented as two ordered attack instances attached to one AT-1 action: each fist independently verifies final legality and resolves ACC, defenses, damage and legitimate criticals without creating a second Act.

The existing player target list, Tab cycling and numbered hit locations operate across all living Goblin IDs. The current test scene adds compact `#32864A` green-square Goblin markers with white `G` glyphs and individual HPC labels for Wave 1 through its pre-existing development encounter selector; `DUEL M/M` and `DUEL M/S*` remain intact. The selector's `WAVE 1` option is a development encounter control, not a production creature-selection interface.

After the final active Goblin reaches zero authoritative HPC, the state machine records `arena_wave_victory_detected` and enters safe downtime without recovery or automatic advancement. Wave 2 remains a separate development selector option until continuous next-wave creature spawning is integrated. The source's leader-defeat scattering statement is also deferred because no verified leader actor or morale rule has been integrated.

### Battlefield assessment and deferred Wave Arena configuration

The retained Guard test battlefield is `44 x 23` feet (`x=2..46`, `y=2..25`) with one central wall. Task 31O verifies that its unchanged geometry can legally place and run the Arena maximum of eight Goblins. The original four spawn offsets remain unchanged; four additional offsets extend the same two-column formation by two feet above and below. This supports the quantity override without changing authoritative bounds, scale, collision, or navigation. The compact fixture remains a combat-development arena rather than a designed multi-direction wave map.

## Task 32A: implemented Wave 2 Common Spadoodles

Wave 2 can be initialized directly for development play without fabricating a Wave 1 victory. The state machine validates the requested catalog wave, performs one authoritative seeded d3 draw, records its draw index/result and resolved 1-3 count, then remains blocked until the real `common_spadoodle` integration registers the exact actor IDs. Waves 4-5 remain blocked and are never skipped or simulated.

`Common Spadoodle.doc` supplies the physical-combat fixture: HPM 10, STR 4, SB 1, END 1, NAL +2 scale hide, SPD/MR 10, AT 1, DEX/DT 6, PD/DP 0, ACC 7, WIT/INIT 1, AP/RB/Physical Soak 0, and two slashing claws at two-foot reach for `1d6` damage. The verified two-foot creature uses Prime V3's Small directional hit-location tables. No held weapon, shield, worn armor, weapon Block, Running investment, Special, or additional combat skill is invented.

The Task 32A owner ruling defines `2 x claws` as two independent ordered attack instances attached to one AT-1 action. Each locks the same declared target/location and independently performs final reach/LOS legality, ACC, defenses, damage and legitimate critical processing. The action still takes exactly five seconds and creates no second Act or extra movement. Eligible physical Strength Bonus remains handled by the existing Prime damage pipeline.

Wave 2 reuses the authoritative Wave 1 multi-actor pursuit, collision, occupancy, target cycling, action scheduler, event history, replay and synchronization paths. Its maximum of three actors uses the unchanged `44 x 23`-foot battlefield and the first three legal wave formation offsets. Presentation uses distinct brown-gold squares with white `S` glyphs, individual HPC labels, target highlights and authoritative facing arrows. Defeating every registered Spadoodle enters safe downtime; it does not automatically begin Wave 3.

## Task 32B: implemented Wave 3 Skellys and Hades Combat Follower

Wave 3 may be initialized directly for development play without simulating earlier victories. The wave state machine performs one authoritative seeded d2 draw for one or two `common_skelly` actors and adds exactly one fixed `hades_combat_follower` without consuming another RNG draw. Quantity evidence, unique actor IDs, mutable actor state, opening Initiative, movement, attacks, defeat and victory all remain in the existing authoritative event/snapshot paths.

Skellys use the source-correct Medium profile, two one-foot `1d6` slashing claws in one AT-1 Act, and exact piercing immunity. The owner-approved general natural-attack rule is represented by `strikes_per_act`: verified natural weapons determine the independent strikes inside the Act, while AT controls only Act frequency. Skelly Light-Special weakness, Faith, Turning, live summoner control, Dispel/Banish and summon expiry remain gated outside this physical Wave 3 slice.

The fixed follower uses its verified Human profile and STR-6 Short Sword. Its deterministic tactical driver selects only among the four verified Combat Specials and an ordinary Short Sword attack. It evaluates current HPC, independent daily allowances, shared AP, active nonstacking effects, attack opportunity, legal self/ally recipients, held dirt and explicitly authored terrain. It records the chosen action, recipient and rejected alternatives without reading hidden player data. Rage remains a two-Act action at AT 2 and its qualifying damaging hits automatically apply the approved two-foot collision-limited knockback. Called Shot covers every verified strike in the following Act; Rejuvenating Mist heals `2d6+2` up to HPM; Defensive Buff requires gathered dirt and adds `+2 NAL` for two minutes.

The test Arena declares its existing floor as packed dirt in authoritative terrain data. Gathering dirt requires a free left hand and one completed Act; terrain remains validated at completion. The material remains in that hand until a successfully completed two-Act Defensive Buff consumes it, while the right-hand Short Sword remains equipped. Self/ally Mist and Buff require a living legal recipient; a different recipient must stay in touch and unobstructed through completion. The deterministic driver can approach an eligible ally without treating the player as an ally. Hand/material state, daily uses/AP payment, recipient, effects, interruption and expiry are retained in snapshots and event history. Other battlefield definitions provide no dirt unless they author a matching material region.

Task 32E models the printed parenthetical numbers as free daily uses: Called Shot 2, Rejuvenating Mist 3, Rage 2 and Defensive Buff 2. Each counter is independent. Once a counter reaches zero, another activation spends exactly one point from the shared AP pool. Ability activation makes no SS check. Fresh initialization and RESET construct full counters/AP; between-wave downtime preserves their current values. A distinct idempotent game-world-midnight command restores them without consulting the host clock.

The unchanged `44 x 23`-foot battlefield supports the two-to-three enemy roster at legal nonoverlapping starts. Existing deterministic pursuit, occupancy reservations, targeting, nine locations, final reach/LOS, HPC labels and facing indicators are reused. Bone-colored `K` and purple `H` placeholders distinguish the two types. Defeating all registered Wave 3 actors enters safe downtime without automatically beginning Wave 4; Wave 5 remains blocked.

The source lists Climb and fear of creatures bigger than Medium. The current flat Arena supplies no climbable surface, and the current Medium Guard is not bigger than Medium. Task 32A therefore adds no climbing or fear behavior; later use requires a source-driven environment/target trigger rather than a fabricated generic effect.

## Task 33A: implemented Wave 4 Mini Gargoyle Swarmers

Wave 4 is independently selectable for development play. Its one authoritative seeded d4 draw, draw index, result and resolved count create one to four independent `mini_gargoyle_swarmer` actors. Each actor has its own source-backed HPC, Initiative, position/elevation, action state, daily Fury use and defeat state. Every registered Gargoyle must reach zero HPC before the wave enters safe downtime; Wave 5 remains inactive and is not fabricated.

Each AT-1 attack Act owns three ordered independent attack instances: slashing claw, slashing claw and piercing bite. The two claws use `1d6 + eligible SB`; the bite uses `1d8 + eligible SB`. All three retain the declared target/location but independently revalidate three-dimensional reach and obstruction, roll ACC, resolve defenses and apply exact damage/critical processing. The owner-approved Small classification selects Prime's directional Small-versus-Medium hit-location modifiers against the current Guard.

Flight extends authoritative position with integer micro-foot elevation. Takeoff and landing are continuous movement funded by the same MR 16 ledger as airborne travel and cost zero ordinary Acts. Three-dimensional movement cost is Euclidean, so a simultaneous three-foot horizontal/four-foot vertical displacement costs five feet. Hovering changes no position or resource, and turning has no separate charge. The authored test Arena stores a ten-foot altitude cap and eight-foot wall height, allowing legal overflight only after the Gargoyle's authoritative base elevation clears the wall. Ground movement, flight movement, final melee reach, line of sight, actor occupancy, events and snapshots all use simulation state rather than visuals.

Fury is committed once to one eligible natural-attack action, consumes one daily use and one NAC-cap slot, and applies exact x2 damage to each qualifying strike in that action. It does not add attacks, extend reach, alter AT or bypass defenses. A subsequent ordinary Act contains no Fury multiplier. RESET reconstructs the original daily allowance and seeded roster; continuous-wave restoration does not invent another use.

Presentation uses gray-blue `M` placeholders, independent HPC/facing markers and an actor-owned altitude label. `▲ 6 ft` and fractional equivalents are read from authoritative elevation and disappear when the actor is grounded, defeated or removed. Wave 4's nighttime premise and printed 100-foot Dark Sight are recorded, but generalized darkness, detection and hidden-information rules remain deferred rather than approximated. Wave 5 remains configured and blocked.

## Inactive Wave 5 equipment mechanics foundation

Tasks 35C-35E keep Wave 5 inactive while validating the Rare Human Warrior's source data and physical equipment pathways. The boss's complete Scale mail, racial NAL +1, hand-held Boar Spear, 30% weapon Block, source-specific 18-foot thrown mode, authoritative dropped-item possession, one-Act interrupted retrieval and one-strike Human unarmed fallback now reuse the shared deterministic combat scheduler. A released spear is unavailable for melee and Block until a legal retrieval completes.

No printed rule supplies miss/block/hit landing coordinates. Task 35E-Fix1 adds an explicit owner-approved Arena rule without changing Prime: the existing pending world item now lands from the attack's authoritative resolution position and established trajectory. Hits and physical interceptions stop at contact; misses and successful Dodges continue only to the spear's verified 18-foot maximum; solid obstacles and battlefield edges stop travel first. Coordinates stay in integer micro-feet, landing evidence remains in events/snapshots, and retrieval still requires legal movement, both hands and one completed Act.

Task 35G resolves the boss's source-listed Combat 1-3 Ability field as Called Shot, Rejuvenating Mist, Rage and Defensive Buff using the already-authoritative Combat Special implementation. Their independent daily allowances and shared AP fallback are mutable actor state; Mana and SS are not used for these Ability activations. The boss's two source-listed Health Potions are also independent mutable inventory state. Task 36G-Fix1 corrects the original one-Act carried-potion shortcut: retrieval plus drinking now uses the player's shared interruptible two-Act action (five seconds at AT 2), requires legal free-hand occupancy, consumes one potion on successful completion, then resolves deterministic `1d10+2` healing capped at HPM 200. Interrupted incomplete drinking consumes neither item nor healing RNG. Actor inventory is included in simulation snapshot schema 12, replay evidence and synchronization digests. Wave 5 remained inactive at Task 35G, which did not implement or authorize boss tactical AI or encounter presentation.

## Task 33B: Wave 4 swarm behavior and legal dive attacks

Wave 4 now drives its existing actors through deterministic, creature-specific tactical states: takeoff, high staging, diving, striking, withdrawing and blocked recovery. Stable roster-index lanes surround the current target, one active diver normally leaves the other actors staged, and an unavailable preferred contact point falls back through the other lanes. The attack remains one AT-1 action containing claw/claw/bite; movement during that action spends the existing MR 16 budget and updates its endpoint against the target's current authoritative position without restarting the action.

The legal contact point is the exact one-foot 3D boundary: 0.8 feet horizontally plus 0.6 feet vertically. Integer squared-distance collision prevents float precision from falsely treating that point as occupied. Final effect still independently validates actual 3D reach and LOS before each strike rolls ACC. After completion the actor withdraws with ordinary MR and later re-engages. Injury changes only the staging radius from four to five feet; it grants no combat modifier and never disables pursuit.

Airborne actors with at least one actor diameter of vertical separation are excluded from ground-plane occupancy queries, removing the reproduced overhead movement lock. Three-dimensional flight collision itself remains unchanged and continues to prevent same-altitude overlap and wall intersection. Authoritative movement events, Fury, damage, replay, state snapshots and synchronization are retained in full.

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

The Arena development HUD now shows the active simulation seed and accepts a signed 64-bit seed before START. Applying a valid value rebuilds the selected ready fixture with that RNG seed; invalid values fail closed, and the control is disabled after combat starts. RESET recreates the encounter with the same selected seed for reproducible retesting. FULL LOG, COPY LOG and SAVE LOG identify the actual simulation seed rather than a presentation-only value. The default remains seed 1; from Task 31O forward, Wave 1 resolves two consecutive authoritative d4 draws and sums them.

## Task 31O: Arena 2d4 quantity override

Task 31O changes only Wave 1's encounter quantity. The Prime V3 baseline remains documented as `1d4`, while the approved Arena configuration is `2d4` Common Goblins. `ArenaWaveStateMachine` consumes each die through the same authority callback and stores `dice_count`, ordered `dice_results`, legacy first `rng_draw_index`, all ordered `rng_draw_indices`, and `resolved_count`. Retaining the first-draw field preserves older consumers while the arrays provide complete two-die evidence.

The encounter supports every total from two through eight. Actor registration, targeting, individual HPC, pursuit, victory detection, transcripts, RESET, replay, snapshots, and simulated-client publication remain count-driven. No uniform `2..8` roll or seed lookup table exists. The first four spawn positions are unchanged and four additional legal positions use the same deterministic formation inside the existing `44 x 23`-foot battlefield.

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

## Task 35H: isolated Wave 5 boss decision controller

The Rare Human Warrior now has an isolated deterministic tactical controller, but Wave 5 is still not registered or selectable. The controller reads authoritative actor, equipment, world-item, resource, effect and battlefield facts; it submits only existing ordinary actions to `CombatSimulation`. Combat timing, ACC, defenses, damage, criticals, potion completion, Ability payment, spear landing and retrieval remain authoritative engine responsibilities. No AI result is resolved locally.

The controller retains the Boar Spear for legal six-foot melee opportunities, uses the verified 18-foot throw only when it provides an immediate legal opportunity that same-Act movement cannot reproduce, and then uses legal unarmed defense or obstacle-aware retrieval. Existing whole-foot pathfinding, collision, occupancy, MR expenditure and unchanged-failure caching govern pursuit. Healing considers actual recoverable injury, active threats, hand availability and action opportunity rather than a percentage-only script. Combat Ability choices respect active/pending effects, independent daily uses and shared AP fallback.

Decision evidence is recorded as `tactical_action_selected` without RNG prediction or concealed player-state access. Identical unchanged decisions are not repeatedly published. The controller adds no snapshot fields; all consequential state remains inside schema 12, so same-seed replay and synchronization use the existing authoritative event and digest contracts. Playable Wave 5 activation, boss presentation and encounter lifecycle wiring remain separate owner-controlled work.

## Task 35I: playable Wave 5 and developer Test Mode

Task 35I authorizes the completed Rare Human Warrior fixture and deterministic decision controller for playable Wave 5. Direct Wave 5 initialization registers exactly one boss, its full Scale-mail protection and racial NAL, two-handed Boar Spear, 30% weapon Block, two potions, Combat 1-3 abilities, world-item throw/retrieval callbacks and existing AI against the selected player fixture. Boss actions still enter the shared scheduler and ACC/defense/damage pipeline; the AI does not resolve results locally. Wave victory enters the approved safe downtime, and the final explicit NEXT WAVE acknowledgement enters the existing completed-circuit victory state without creating Wave 6.

The visible encounter selector now distinguishes normal Arena start (`NORMAL / WAVE 1`) from temporary `TEST MODE / WAVE 1` through `WAVE 5`. Each direct selection constructs the actual authoritative wave with the selected seed and character. RESET reconstructs that temporary fixture from immutable source data, clearing actions, effects, enemies and world items without touching any future persistent profile. Guard and Synthetic Small remain available as labeled test fixtures after the five wave choices.

Task 35J supersedes the former continuous-transition gate. General registration APIs remain closed after `begin_combat()`, but one bounded batch API validates and registers a complete arriving wave roster. The same transaction supplies defenses, protection, critical-reaction attack data and authoritative hand occupancy, then rolls Initiative only for the arriving enemies from the continuing RNG stream. The surviving player is never rebuilt or rerolled. Defeated prior-wave actors remain in schema-12 history and snapshots under `retired_actor_ids`; their pending events are canceled, they cannot initiate new actions, and session targeting, occupancy and AI use only the active wave roster.

Normal solo play now remains inside one `CombatSimulation` for Wave 1 through Wave 5. Verified victory enters untimed safe downtime, exactly one NEXT WAVE request resolves the configured quantity and installs the next official roster, and Wave 5's final acknowledgement completes the circuit without a Wave 6. Current player HPC, resources, inventory, ability uses, equipment, effects, action timing, combat clock, RNG draw position, event IDs and historical records continue unchanged. Spawn placement first uses each existing authored formation, then uses a deterministic collision-checked whole-foot fallback only if the continuing player occupies a preferred arrival position. RESET still reconstructs the originally selected normal or Test Mode fixture.

Dropped Boar Spear state remains authoritative in `world_items`. Task 35J adds a presentation-only outlined spear marker at the serialized authoritative landing coordinate. It is created once while the item is `dropped`, removed on retrieval or RESET, and never participates in collision, pickup, targeting, RNG, snapshots or synchronization.

Task 35K-Fix1 separates combat attack positioning from dropped-item contact positioning. A spear intercepted at a wall face no longer becomes unreachable merely because combat LOS correctly rejects the wall endpoint: deterministic pathfinding selects a collision-legal adjacent pickup position, and the existing one-Act retrieval still revalidates exact one-foot contact. If static topology supplies no recovery route, the cached failure switches the disarmed boss to its already verified one-strike Human unarmed pursuit rather than repeating `approach_spear`. Initial and final spear attack legality continue to require authoritative LOS, so a target moving behind the wall before resolution produces no ACC roll and the released spear lands at the actual obstacle contact. Lack of current attack reach alone no longer triggers minor Rejuvenating Mist use; legal emergency healing and nonstacking Defensive Buff remain available.

## Task 36A: within-run rewards and ground loot

NORMAL Wave 1 initializes one `ArenaRewardLedger` inside the persistent session. Qualifying damage events that cross an active enemy from positive HPC to zero or below resolve that actor's verified reward exactly once. Wave transitions reset only the current-wave XP window; cumulative earned/spent/unspent XP, collected inventory, uncollected ground records, authoritative RNG position and complete event history remain in the same `CombatSimulation` through Wave 5.

Random Drops use the continuing combat RNG and publish each chart roll with its draw index. Creature possessions use separate transfer records. If the Wave 5 Boar Spear already exists as a dropped world item, defeat reuses that record rather than recreating the equipped item. The protected boss EXP/drop entry remains blocked, so Wave 5 currently provides only accepted pre-existing possessions and no fabricated XP or generated treasure.

Safe downtime exposes a small read-only reward summary and one `COLLECT NEAREST LOOT` request. Authority still requires one-foot collision-reachable contact; the UI does not move the player or collect through walls. NEXT WAVE never auto-collects and never removes an uncollected item. Developer TEST MODE records suppression before reward RNG and creates no permanent reward. RESET reconstructs the selected fixture with a fresh temporary ledger and no prior world items.

Reward state is added to the existing schema-12 snapshot without changing its version or removing any field. XP awards, chart outcomes, ground creation/collection and source gates are ordinary ordered `CombatEvent` records, so existing replay publication and simulated-client convergence remain the authority path. See `REWARDS_AND_ADVANCEMENT_FOUNDATION.md` for chart coverage and advancement gates.

## Task 36B: bounded advancement during safe downtime

NORMAL-mode downtime now exposes the authoritative XP ledger as a minimal character-advancement transaction surface. The player selects a catalog entry and explicitly confirms the purchase. The only currently executable entry is source-backed Vaelis SR 1 to 2 for 2,000 EXPC; every incomplete category exposes its exact blocker and spends nothing. Purchases do not advance the wave, consume combat time, roll RNG, restore resources, alter equipment, or discard conditions and effects.

Purchased definition data, cumulative spent XP, available XP, processed request identifiers and immutable history remain in the continuing schema-12 simulation through later waves. TEST MODE rejects spending. RESET reconstructs the selected immutable fixture and fresh temporary ledger, so no advancement survives the run until the separately approved saved-character system exists.

## Task 36C: inventory and equipment through downtime

Collected inventory, equipped references and consumed quantities stay in the same surviving player actor state. During safe NORMAL-mode downtime, exact registered equipment can be changed through one authoritative transaction that rebuilds only verified attack, defense, protection and armor-derived modifiers. It never refills resources, clears conditions or rebuilds the player. NEXT WAVE therefore carries the accepted loadout and quantities forward.

TEST MODE rejects item-management mutations and RESET restores the selected fixture's starting equipment and inventory. Abstract Random Drop categories remain visible with provenance but cannot silently gain statistics. Existing dropped Boar Spear world-item identity and combat retrieval remain separate and unchanged.
