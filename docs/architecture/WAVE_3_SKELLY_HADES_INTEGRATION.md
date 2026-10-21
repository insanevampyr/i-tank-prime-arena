# Wave 3: Common Skelly and Hades Combat Follower

## Authoritative roster

- One authoritative seeded d2 resolves one or two Common Skellys.
- One Uncommon Hades Combat Follower is fixed and consumes no quantity RNG draw.
- Every enemy has a unique actor ID, definition-backed HPM, mutable HPC, action state, position and navigation state.
- The existing 44 by 23-foot authoritative Arena and deterministic multi-actor driver are reused.

## Common Skelly

The controlling Prime V3 creature entry supplies Size Medium, HPM 10, AT 1, MR 6, ACC 8, INIT 1, DT 4 and DP 4. The supplied older sheet corroborates the remaining profile and two one-foot `1d6` slashing claws but contains conflicting DT/PD values; source precedence therefore keeps Prime V3 DT 4/DP 4.

The owner-approved natural-attack rule makes the two verified claws two independent strikes inside one five-second AT-1 Act. Each strike retains its own attack ID, final legality, ACC, defense, damage and critical chain. Piercing immunity is active through the existing exact damage-type protection response. Source-verified Light Special damage is multiplied by four at the authoritative final-damage boundary. Source-verified Faith damage is accepted only for actors with an explicit qualifying-supernatural response; ordinary actors fail closed. No generic Light or Faith attack is invented.

Prime V3's Cleric Turning rules are source-located, but this Arena has no verified Cleric actor, HSF qualification, level, hourly-use state, or Turning input path. Turning therefore remains an explicit integration gate rather than an instant-kill approximation. Summoner control, summoned-eye sight and maximum-summon mechanics are excluded by the Task 32C owner ruling; Wave 3 Skellys fight independently.

## Uncommon Hades Combat Follower

The follower uses its verified adult-Human profile and equipped Short Sword. The one-handed sword requirement is STR 6 and the actor has STR 6. It provides one two-foot combined Slashing/Piercing `1d6+1` strike per ordinary Act; eligible SB remains part of the existing physical damage pipeline.

Its deterministic tactical driver uses current HPC, independent daily-use counters, shared AP, active effects, attack opportunity, legal self/ally recipients, held material and authored terrain. A healthy fresh follower selects Combat Rage; useful healing, valuable protection preparation, Called Shot opportunities and ordinary attacks can produce different legal choices. Every choice, recipient, current resources and rejected alternative is written to the authoritative transcript. Rage requires two ordinary Acts, permits simultaneous legal movement, is interruptible, and commits one free Rage use before falling back to one shared AP after both uses are exhausted. At AT 2 it completes after exactly five seconds. Completion applies one nonstacking effect for 120 seconds:

- SB `+2`
- NAL `-2`
- DT `-1`
- DP `-1`

The effect and expiry are authoritative state/events. Baseline actor definition values are never mutated. Per the Task 32C owner ruling, each legally damaging physical Rage hit applies one mandatory two-foot forced displacement through the same authoritative battlefield collision/occupancy resolver. A wall or actor may shorten the displacement; misses, final-legality failures and successful defenses produce none. Forced displacement spends no MR.

The verified Combat Specials share the ordinary `5 / AT` scheduler. Their parenthetical numbers are independent free daily allowances, not AP prices. After one Special's allowance is exhausted, each extra activation costs exactly one shared AP:

- **Called Shot (2/day):** the first Act locks and announces a target actor and location without attacking. Every verified strike in the matching physical attack Act skips the ACC d20 only after final reach/LOS legality succeeds; normal defenses and damage rules remain.
- **Rejuvenating Mist (3/day):** one Act; deterministic `2d6+2` healing to self or a legal touched ally, capped at the recipient's HPM.
- **Defensive Buff (2/day):** two Acts; requires authoritative dirt possession, targets self or a legal touched ally, grants nonstacking `+2 NAL` for 120 seconds.
- **Rage (2/day):** two Acts; existing modifiers and duration above.

The selected daily use or one-AP fallback is committed once at declaration and is not refunded by interruption. Ability Users make no SS activation check. Fresh encounters/RESET start full; continuous waves preserve resources; an explicit game-world-midnight boundary restores daily uses and AP. Physical damage schedules immediate interruption of an executing verified Special. The current Arena floor explicitly supplies packed dirt: gathering takes one completed Act and a free left hand, then successful Buff completion consumes it. The Short Sword remains in the right hand. A touched ally must remain in legal touch/LOS for the entire cast; loss interrupts or blocks completion and preserves dirt. Equipping a held weapon or shield uses a separate one-Act action. Fire weakness remains gated because no verified fire-Special pipeline is part of this task.

## Development launch

From READY, cycle the encounter button to `WAVE 3`, choose a seed if desired, then press START. Existing mouse/touch selection, Tab/Shift+Tab, numbered locations, attack holds, movement/Running, HPC labels, facing arrows, FULL LOG and RESET remain unchanged. RESET rebuilds the same quantity and initial event history from the same seed. Victory requires all Skellys and the follower to reach defeat; Wave 4 remains blocked.
