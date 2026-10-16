# Battlefield Movement Foundation

## Scope and authority

Phase 1 Task 16 replaces the Task 14-15 open-floor presentation boundary with one authoritative `ArenaBattlefield`. Prime V3 page 19 defines MR as the feet/squares a character may move in a turn and permits movement alongside actions; the approved Arena timing adaptation maps that budget to `effective MR / 5` feet per second. Canonical geometry therefore uses integer micro-feet (`1 foot = 1,000,000 micro-feet`). Godot pixels are presentation only (`24 pixels = 1 foot` in this fixture).

The battlefield owns bounds, blocked rectangles, actor-footprint occupancy, known hazard tiers, line-of-sight facts and deterministic path queries. `PrimeMovementModel` remains the one player movement/running model. Keyboard and touch produce the same intent; `ArenaCombatSession` resolves that intended endpoint against battlefield geometry, spends actual authoritative MR and returns the accepted position for rendering. Godot physics and sprite overlap never decide combat state.

## Authored test arena

The Task 16 scene uses a 44-by-23-foot playable rectangle beginning at `(2, 2)` feet, one visible two-by-twelve-foot center wall, and a visible non-damaging test hazard zone. The hazard zone supplies only an explicit Dodge hazard tier; it causes no damage, movement modifier, cover, or immunity. The half-foot actor collision radius and one-foot pathfinding lattice are Arena test-fixture geometry, not claimed Prime character formulas.

Task 22 confirms the reported rectangle behavior. The gray center wall blocks movement, Dodge paths and line of sight and participates in pathfinding. The brown/orange rectangle is intentionally walkable and line-of-sight transparent; it adds no movement cost, MR penalty, cover or ACC modifier. It affects only automatic Dodge destination preference through authored hazard tier 1. Presentation now labels the two regions `WALL` and `WALKABLE DODGE TEST`.

Movement is continuous between deterministic waypoints. The one-foot lattice selects a stable route with neighbor priority left, up, right, down; it is not an action grid or turn system. Each 0.1-second authoritative opponent movement boundary advances by `MR / 5` using integer remainder carry, spends the actual path distance, and records `actor_position_changed`. Round boundaries are split so the same round MR budget is not silently reused. A sealed route reports `approach_blocked_no_legal_path`.

## Legal movement and concurrency

- Bounds, obstacles and other actor footprints reject illegal destinations. Swept sampling plus an integer binary boundary prevents tunneling through a wall even when the requested endpoint is clear.
- Collision truncates displacement without treating that contact as an intentional Running stop. Running checks, duration, recovery and direction limits remain in `PrimeMovementModel`.
- The player and opponent spend the same round MR resource used by Dodge. Running may expand the player's current allowance only by the already-approved effective-MR bonus.
- Critical Stagger blocks voluntary movement for its exact 0.5-second simulation interval. Under the approved Task 17 Arena playtest rule, prone actors may crawl at exactly 25% of effective walking MR but cannot Run; the existing one-Act stand remains available.
- Movement-compatible actions continue while the player moves. AT execution and five-second combat rounds remain independent from render frames and movement-path decisions.

## Opponent approach

The Task 15 scripted opponent remains a controlled fixture, not general AI. Once initiation restrictions and opening Initiative permit, it declares the same ordinary Battle Axe action even when current geometry is outside reach or obstructed. During that AT execution it requests a deterministic path and moves at verified MR toward legal final geometry. It cannot teleport, cross occupied space, move while prone or critically staggered, exceed remaining round MR, or bypass opening Initiative.

Task 18 corrects a steering defect: every accepted player movement frame previously cleared the route, so a moving target could force path rebuilding every frame. The driver now keeps the stable route until the target has moved at least the authored one-foot navigation step, then deterministically replans from current authoritative positions. This threshold is test-fixture steering behavior, not a Prime movement rule and grants no distance. A genuine collision or no-path result remains explicit; static paths do not oscillate between equal alternatives.

## Dodge integration

The battlefield now supplies every Dodge candidate's swept path, collision, terrain, occupancy, escape and known hazard tier. The existing defense resolver still selects lowest hazard tier, shortest displacement and stable candidate ID. The center wall and actors block Dodge paths and destinations. No in-place candidate is supplied for the Battle Axe because its duck eligibility remains unresolved; Perfect Evasion therefore remains pending if it cannot receive an independently legal displacement.

## Determinism and synchronization

Battlefield configuration and movement-ledger state are included in the session snapshot. Accepted positions and MR spending remain ordinary authoritative combat events, so duplicate/out-of-order observer delivery converges without adding network transport. Reset rebuilds the original seed, actors, clock, path, integer movement remainder, battlefield and presentation state.

## Verified boundary and unresolved rules

The current approved timing validates ordinary melee reach and line of sight at the final effect timestamp before ACC, not as declaration prohibitions. Temporary illegality during the AT interval does not cancel an attack if both facts are legal at resolution. Final illegality records a deterministic no-connection event, consumes no ACC RNG, and does not refund elapsed action time. The authoritative battlefield supplies final line of sight; a moved-endpoint fixture without geometry fails closed.

Prime V3 page 36 identifies prone movement/position as impaired but delegates the applicable offensive/defensive penalties to the Storyteller. Task 17 therefore labels 25% crawling and no Running as Arena playtest rules rather than Prime formulas. Crawl distance remains exact in integer micro-feet, uses the existing effective walking MR, and passes through the same bounds, swept collision, occupancy, status and round-MR authority as standing movement.

No cover modifiers, terrain costs, projectile behavior, advanced tactics, flanking, dynamic pathfinding intelligence, Specials, NACs or network transport are added.

## Manual fixture check

1. Run `scenes/test_arena.tscn` and press **START**.
2. Use WASD or the touch joystick to push against the green arena edge, gray center wall and opponent. The player must stop or slide without crossing them.
3. Hold Shift or **RUN** while moving into the same geometry. Running must remain active through collision, while the accepted position stays legal.
4. Move away from the opponent or around the far side of the wall. The opponent should declare when otherwise eligible, travel during AT execution at MR speed, and replan after meaningful target movement. It rolls ACC only when final three-foot reach and line of sight are legal. Press F3 to inspect path status and rebuild count.
5. While outside three-foot reach, press Space/Enter or **ATTACK**, then approach during the visible ATTACKING interval. Legal walking or Running continues concurrently; Critical Stagger stops voluntary movement. A prone player can crawl but cannot Run; ATTACK remains the existing one-Act stand intent while prone.
6. Repeat **RESET**, **START** with the same inputs to compare the same seeded event sequence. The orange test-hazard rectangle has no damage or movement effect; it exists only to exercise deterministic Dodge hazard preference.

## Task 20 sustained pursuit correction

The previous deterministic driver spent base MR 12 while the continuously walking player also had MR 12. Repathing could retain a lawful route but could not close equal-speed distance. Task 20 routes the opponent through the existing `PrimeMovementModel`; Task 25 now supplies the Guard fixture's armor-adjusted walking MR 11. The documented three-investment test profile automatically activates Running at MR 17, observes the 50-second END cap, accrues exact recovery debt, and walks at MR 11 during recovery. No movement multiplier, teleport, or free MR was added. Current authoritative target position is the only pursuit target fact, and F3 exposes Running state and path rebuild count.
