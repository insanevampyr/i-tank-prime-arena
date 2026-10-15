# Battlefield Movement Foundation

## Scope and authority

Phase 1 Task 16 replaces the Task 14-15 open-floor presentation boundary with one authoritative `ArenaBattlefield`. Prime V3 page 19 defines MR as the feet/squares a character may move in a turn and permits movement alongside actions; the approved Arena timing adaptation maps that budget to `effective MR / 5` feet per second. Canonical geometry therefore uses integer micro-feet (`1 foot = 1,000,000 micro-feet`). Godot pixels are presentation only (`24 pixels = 1 foot` in this fixture).

The battlefield owns bounds, blocked rectangles, actor-footprint occupancy, known hazard tiers, line-of-sight facts and deterministic path queries. `PrimeMovementModel` remains the one player movement/running model. Keyboard and touch produce the same intent; `ArenaCombatSession` resolves that intended endpoint against battlefield geometry, spends actual authoritative MR and returns the accepted position for rendering. Godot physics and sprite overlap never decide combat state.

## Authored test arena

The Task 16 scene uses a 44-by-23-foot playable rectangle beginning at `(2, 2)` feet, one visible two-by-twelve-foot center wall, and a visible non-damaging test hazard zone. The hazard zone supplies only an explicit Dodge hazard tier; it causes no damage, movement modifier, cover, or immunity. The half-foot actor collision radius and one-foot pathfinding lattice are Arena test-fixture geometry, not claimed Prime character formulas.

Movement is continuous between deterministic waypoints. The one-foot lattice selects a stable route with neighbor priority left, up, right, down; it is not an action grid or turn system. Each 0.1-second authoritative opponent movement boundary advances by `MR / 5` using integer remainder carry, spends the actual path distance, and records `actor_position_changed`. Round boundaries are split so the same round MR budget is not silently reused. A sealed route reports `approach_blocked_no_legal_path`.

## Legal movement and concurrency

- Bounds, obstacles and other actor footprints reject illegal destinations. Swept sampling plus an integer binary boundary prevents tunneling through a wall even when the requested endpoint is clear.
- Collision truncates displacement without treating that contact as an intentional Running stop. Running checks, duration, recovery and direction limits remain in `PrimeMovementModel`.
- The player and opponent spend the same round MR resource used by Dodge. Running may expand the player's current allowance only by the already-approved effective-MR bonus.
- Critical Stagger blocks voluntary movement for its exact 0.5-second simulation interval. The controlled slice blocks voluntary prone travel and requires the existing one-Act stand; no crawl rule or prone movement penalty is inferred.
- Movement-compatible actions continue while the player moves. AT execution and five-second combat rounds remain independent from render frames and movement-path decisions.

## Opponent approach

The Task 15 scripted opponent remains a controlled fixture, not general AI. Its order is unchanged except that an out-of-range result now requests a deterministic legal path. It moves at its verified MR, re-evaluates the player position when the player's authoritative movement invalidates the path, and declares the same Battle Axe action only after range and line of sight are legal. It cannot teleport, cross occupied space, move while prone or critically staggered, exceed remaining round MR, or bypass opening Initiative.

## Dodge integration

The battlefield now supplies every Dodge candidate's swept path, collision, terrain, occupancy, escape and known hazard tier. The existing defense resolver still selects lowest hazard tier, shortest displacement and stable candidate ID. The center wall and actors block Dodge paths and destinations. No in-place candidate is supplied for the Battle Axe because its duck eligibility remains unresolved; Perfect Evasion therefore remains pending if it cannot receive an independently legal displacement.

## Determinism and synchronization

Battlefield configuration and movement-ledger state are included in the session snapshot. Accepted positions and MR spending remain ordinary authoritative combat events, so duplicate/out-of-order observer delivery converges without adding network transport. Reset rebuilds the original seed, actors, clock, path, integer movement remainder, battlefield and presentation state.

## Verified boundary and unresolved rules

The existing physical-attack contract validates range and line of sight when the action is declared and carries those authoritative facts through its AT interval. Prime V3 and Combat Specification v1.7 do not yet establish whether a moving target must be rechecked at the final effect timestamp. Task 16 does not silently change that timing. A designer ruling is required before adding completion-time range/line-of-sight cancellation, retargeting or pursuit.

Prime identifies prone as impaired movement, while the approved critical rule requires a one-Act stand. Exact crawl distance, prone movement penalties and any attack-specific movement exception remain unresolved. The vertical slice fails closed on voluntary prone travel rather than inventing them.

No cover modifiers, terrain costs, projectile behavior, advanced tactics, flanking, dynamic pathfinding intelligence, Specials, NACs or network transport are added.

## Manual fixture check

1. Run `scenes/test_arena.tscn` and press **START**.
2. Use WASD or the touch joystick to push against the green arena edge, gray center wall and opponent. The player must stop or slide without crossing them.
3. Hold Shift or **RUN** while moving into the same geometry. Running must remain active through collision, while the accepted position stays legal.
4. Move away from the opponent or around the far side of the wall. The HUD should show `approaching`; the opponent should travel around the wall at MR speed and attack only after it has legal three-foot reach and line of sight.
5. Press Space/Enter or **ATTACK** while moving. A legal action continues concurrently; Critical Stagger or prone visibly stops voluntary movement.
6. Repeat **RESET**, **START** with the same inputs to compare the same seeded event sequence. The orange test-hazard rectangle has no damage or movement effect; it exists only to exercise deterministic Dodge hazard preference.
