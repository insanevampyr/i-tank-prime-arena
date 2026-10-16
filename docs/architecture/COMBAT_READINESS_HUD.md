# Combat Readiness HUD

## Scope

Phase 1 Task 19 adds two read-only indicators to the existing Arena presentation. They do not schedule actions, advance time, spend movement, roll checks or create cooldowns. `CombatReadinessModel` derives display snapshots from the active `CombatActionInstance`, the current combat actor state, `ArenaCombatSession.get_attack_legality`, and `PrimeMovementModel.to_dictionary`.

## Attack indicator

| Display state | Authoritative source |
| --- | --- |
| READY | Current initiation legality succeeds and no ordinary action or Stagger is active; `APPROACH` notes that current geometry must improve before resolution |
| ATTACKING | The current ordinary attack's linked action is in progress; progress uses `started_at_us`, `final_effect_due_at_us` and the simulation clock |
| STAGGERED | `critical_stagger_until_us` is later than the simulation clock |
| BLOCKED | Encounter inactive/complete, player defeated, incapacitated/unconscious, prone and required to stand, another ordinary action active, waiting for opening-Initiative eligibility, or another verified legality gate |
| NO TARGET | No live selected target is available |
| OUT OF RANGE | Reserved for an attack type whose approved initiation policy requires current reach; the ordinary Battle Axe approach-attack does not use this state |

One Act still uses the action authority's cumulative integer schedule for `5 seconds / AT`. The HUD reads the scheduled timestamps, so AT 2 displays 2.5 seconds, AT 10 displays 0.5 seconds and AT 12 displays 0.416667 seconds. Completion creates no extra cooldown. An interrupted action stops contributing a countdown. Critical Reactions have no ordinary action instance and therefore do not reset or lock this indicator.

READY means an ordinary attack may be initiated. For the approved ordinary melee approach-attack, current reach or obstruction does not prohibit declaration: the indicator shows `READY / APPROACH`, and the player must establish legal reach and line of sight by the final effect timestamp. The indicator does not predict future reach or guarantee an ACC roll.

## Running indicator

| Display state | Authoritative source |
| --- | --- |
| READY | No combat restriction, retry delay or recovery debt prevents `request_running` |
| RUNNING | `is_running`; remaining time is maximum duration minus elapsed Running time |
| RECOVERING | Derived recovery debt remains after a run |
| RETRY | The existing failed-check five-second retry restriction remains |
| BLOCKED | Encounter inactive, focus unavailable, prone, Critical Stagger, defeat or recorded incapacitation/unconsciousness prevents the input |

The blue integration fixture retains baseline SPD 12, END 10 and MR 12, three Running investments, SCM 0 and RB 0. Task 25 applies its equipped Plate torso's verified MR -1, so authoritative walking MR is 11. Prime's verified Running target remains 10 and the three-investment fixture remains automatic; Running therefore exposes MR 17 and the same 50-second cap. Recovery still equals actual Running time, clears at 100 percent while standing and 50 percent while walking, and is not removed by releasing Shift. If retry and recovery coexist, the compact indicator shows RETRY first while DEBUG retains both exact values.

## Movement and action concurrency

Legal walking or Running remains available during an ordinary action because neither readiness indicator locks movement. The player may declare one ordinary Battle Axe attack outside its three-foot reach, then approach under direct WASD/touch control during AT execution. The deterministic opponent declares through the same authority and spends legal MR along its stable path during its own execution. At the final effect point, both actors must be within weapon reach and unobstructed or the attack records final-legality failure without an ACC draw. Nothing queues a later attack or refunds elapsed action time.

## Presentation and focus

The circular rings and code-drawn swords/footprints are passive `Control` nodes. Green means READY, blue means an active attack/run, amber means recovery/retry, and red means unavailable. Text accompanies every color. Focus loss clears touch input and replaces a potentially stale READY display with `FOCUS LOST`; it does not mutate combat state. Reset recreates the simulation and movement model before recalculating both indicators.

## Task 20 approach feedback

For the current Battle Axe fixture, an outside-reach or initially obstructed declaration remains `READY` with value `APPROACH`. The compact status explains that final three-foot reach and line of sight are required before ACC. Final geometry failure stops the countdown and reports that ACC was not rolled; it is not reclassified as a declaration-time cooldown.
