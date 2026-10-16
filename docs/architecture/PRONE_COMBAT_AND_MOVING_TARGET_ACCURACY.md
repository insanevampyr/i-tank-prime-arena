# Prone Combat and Moving-Target Accuracy

## Authority and source finding

Prime V3 page 36 defines Prone as being on the ground or destabilized, states that movement and position are impaired, and leaves applicable offensive/defensive penalties to the Storyteller. Prime V3 pages 95-98 instead publish an ACC chart by attacker size, target size and numbered hit location. For the controlled vertical slice's SAME SIZE torso/chest location 3, the chart says `No Change`; it contains no prone-posture row or universal prone ACC adjustment.

The implementation therefore keeps the verified Prime chart and the approved Arena playtest adaptations separate. It applies the fixture's verified location-3 modifier of zero and does not invent a posture modifier. The 25% crawl rate, no-Running rule, final range/line-of-sight timing, and `x1.5` prone physical-damage factor are Task 17 Arena rulings.

## Attack lifecycle

1. Declaration validates the attacker, target, equipment, target location, opening Initiative and action availability. Under the later approved Arena approach-attack ruling, current melee reach and obstruction do not prohibit an ordinary declaration.
2. The ordinary action occupies its complete `5 seconds / AT` interval. Movement remains independently legal during that interval.
3. At the final effect timestamp, the authority snapshots both current positions and revalidates weapon range.
4. If range is legal, the battlefield revalidates line of sight. Moved endpoints without an authoritative geometry resolver fail closed as unresolved.
5. Only after both final facts are legal does the authority draw the ACC d20.
6. Final illegality records the reason, no ACC draw, no defense or damage, and no elapsed-action-time refund.

The attacker may approach, legally Run, or otherwise move during the interval where movement is permitted. Movement out of range or behind an obstacle during the interval is not itself terminal. If final reach and line of sight are legal, the attack continues to ACC; otherwise it fails without ACC. The system does not home, retarget, or guarantee connection.

## Prone movement and defenses

Prone movement uses one quarter of the existing effective walking MR in integer micro-feet, retaining fractional feet without rounding the allowance to whole MR. It consumes the same round movement ledger and uses the same bounds, swept collision, occupancy, Stagger and input-intent path as upright movement. Running requests fail while prone. The existing one-Act stand is unchanged.

Dodge remains subject to every existing eligibility and environment requirement. For a prone actor, the Task 17 crawl allowance is established first and Prime's half-MR Dodge limit is then rounded down to whole feet. Weapon Block, shield Block and Physical Soak receive no blanket prone penalty; they remain available only when their existing awareness, equipment and attack-specific prerequisites are satisfied.

## Damage and determinism

One `arena_prone_target` exact rational factor of `3/2` is added only to qualifying physical damage when the target is prone at damage preparation. It combines with legitimate critical, head/neck, weakness and other factors before one floor, after which TAL, NAL and HPC follow the established transaction. It neither changes ACC nor bypasses defense.

Declaration/final positions, final legality facts and failure reasons are serialized into attack records. Prone posture, exact movement allowance, accepted movement, the prone factor and resulting HPC remain authoritative snapshot/event data. Seeded replay and passive two-client observers therefore converge without allowing presentation frames to decide range, line of sight, movement or damage.

## Remaining source boundary

Prime provides no universal prone ACC value in the audited chart. Only source-transcribed size/location entries may be used, and any future attack-type or positional exception requires a specific Prime rule or approved Arena ruling. Prone offensive actions in the controlled UI remain gated by the existing stand-first adapter; Task 17 does not invent attack-while-prone penalties or permissions beyond the requested defenses and movement.
