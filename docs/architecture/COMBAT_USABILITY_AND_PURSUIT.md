# Combat Usability and Pursuit

## Scope

Phase 1 Task 18 improves the Task 14-17 playtest adapter without changing combat rules. The authoritative simulation, AT schedule, opening Initiative, final range/line-of-sight check, ACC, defenses, critical consequences, damage, movement ledger and client-observer protocol remain unchanged.

## Controls

- Desktop left-click on the opponent selects it and requests one ordinary Battle Axe attack through `ArenaCombatSession.request_player_attack`.
- A second deliberate click is accepted only when that authority says another action is legal. An in-flight action rejects the request; nothing is queued and no auto-attack state exists.
- Empty terrain clears selection. Right-click remains unused. Space and Enter use the same request boundary.
- On touch, tapping the opponent selects only. The ATTACK control emits the existing one-shot request. WASD/touch movement and Shift/RUN still reduce to the same movement and Running intents.

## Pursuit correction

The previous driver cleared `_opponent_path` after every nonzero player movement request. Since the player adapter submits continuous authoritative motion, a moving player could invalidate the route every rendered physics step. The opponent repeatedly searched from scratch and appeared hesitant or ineffective.

The corrected driver stores the authoritative target position used to build a route. It retains the stable route during sub-foot motion and rebuilds after a cumulative one-foot change, matching the existing navigation lattice. It also approaches when line of sight is blocked, not only when range is exceeded. The approved approach-attack correction lets it declare when otherwise eligible, then spend actual Guard MR during AT execution; final range and line of sight remain mandatory gates before ACC. Collision, occupancy, prone and Stagger remain enforced. This is a deterministic controlled-opponent policy, not general AI.

## HUD split

The default view shows player/opponent HPC, selected target, current attack legality/range, conditions, concise Running/recovery status, important combat outcomes, and START/RESET. The visible DEBUG button or F3 toggles a developer overlay with simulation time/round, action phases, opponent-driver state, route rebuild count, Running calculation evidence and detailed formatted authoritative events. Hiding the overlay does not discard event data.

Before START, rejected movement now returns the actor's existing authoritative position. This prevents the player presentation from snapping to `(0,0)` while combat is inactive.

## Blue movement-test fixture

The visible blue actor is `Player Guard Fixture`, actor kind `prime_v3_verified_vertical_slice_fixture`; it is not Aren Valecrest or a production character.

| Field | Value | Authority |
| --- | ---: | --- |
| SPD | 12 | Prime V3 Uncommon Guard fixture |
| END | 10 | Prime V3 Uncommon Guard fixture |
| Walking MR | 12 | Prime V3 Uncommon Guard fixture |
| Running investments | 3 | Explicit Task 3 movement-test profile, not the Guard source row |
| SCM | 0 | Explicit Task 3 movement-test profile |
| RB | 0 | Prime V3 Uncommon Guard fixture |
| Prime Running target | `10 + 0 + 0 = 10` | END plus third-investment modifier plus SCM |
| Automatic | Yes | Prime proficiency mark at three investments |
| Arena Running bonus | `floor(12 / 2) = 6 MR` | Approved Arena Running rule |
| Active MR | 18 | 12 walking plus 6 nonstacking bonus |
| Maximum duration | `10 x 5 = 50 seconds` | Approved Arena Running rule |

Automatic proficiency bypasses activation and five-second maintenance rolls only. Actual Running time creates equal recovery debt; standing recovers at 100%, walking at 50%. A failed check normally adds a five-second retry cooldown, but this automatic fixture does not roll and therefore cannot produce that failure cooldown absent a future verified modifier that removes automatic proficiency.

## Test boundary

Automated coverage verifies single-click request count, duplicate rejection, empty selection, keyboard/touch separation, stable and target-change repathing, obstacle approach, attack transition, deterministic replay, Running configuration and responsive overlay bounds. Browser automation must separately confirm that a real DOM/canvas mouse click reaches the exported Web build. Physical Android touch remains a manual-device boundary.

## Task 19 readiness extension

`COMBAT_READINESS_HUD.md` documents the passive ATTACK and RUN indicators added above the combat-results region. They display existing action, legality, Stagger, Running, recovery and retry state only. Legal movement and Running continue during ordinary attacks; the ordinary attack is declared immediately rather than queued, and both actors require final effect-point range and line-of-sight legality before ACC.
