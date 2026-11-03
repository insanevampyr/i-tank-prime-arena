# Task 37C owner rulings on PAR and attribute limits

Continuation status: the negative-allocation and temporary-Luck questions below
have since been resolved by explicit owner rulings. See
`TASK_37C_TERMINOLOGY_AND_LUCK_RULINGS.md` for the current policy and next WIS
question. Historical questions below are preserved, not newly open blockers.

Authority: explicit owner continuation ruling, 2 November 2026. Audit and
documentation only; no calculation, purchase, migration or eligibility is enabled.
This supplements the frozen source catalog without changing its bytes/checksum.

## PAR clarification

V3 p.23 is not an erratum. PAR 10 is maximum normal physical beauty within the
character's race. Values above 10 represent supernatural physical attraction.
The numerical APP progression on pp.54/56 remains authoritative through PAR 18.
Never cap chart-derived PAR at 10. PAR alone grants no additional persuasion,
social or supernatural mechanics. The previous PAR applicability question is
resolved by this owner clarification, not by a manuscript correction.

## Attribute eligibility

- Up to 20: normal mortal limit, subject to legal advancement requirements.
- 21-25: requires a qualifying Special or Special-imbued equipment.
- Magical effects cannot raise a mortal attribute above 25.
- 26+: requires Immortality as a distinct eligibility condition, not wealth or EXPC.
- Printed chart coverage ends at 35; do not extrapolate.
- Separate permanent purchases from temporary or magically enhanced effective
  values. A printed chart row never grants eligibility by itself.
- Retain any source-specific Immortality distinctions and limitations. No list
  of qualifying Immortality forms is invented or activated in this audit.

These explicit owner restrictions supplement the generic chart footnotes. A
future evaluator must require verified eligibility/provenance before accepting
high scores; the engine must not turn an unknown eligibility claim into permission.

## Historical negative allocation question now resolved

Negative allocation behavior remains unresolved. Printed p.38 says temporary
attribute penalties affect tied derived values, but does not select which side
of a previously confirmed allocation loses points. The approved MAN rules cover
positive growth and bonuses, not reductions.

Concrete question: with permanent DEX 9 and confirmed DT 6 / DP 3, how should a
temporary -1 DEX change effective DT/DP? What general reduction rule applies to
both DEX and MAN pools, and does permanent loss follow the same rule? Removal
of a temporary penalty must not silently rewrite historical confirmations.

Existing `DexAllocation._apply` accepts positive temporary points only, and
`CombatSimulation.get_effective_actor_combat_stat` rejects negative DEX
modifiers. No signed allocation-reduction policy is implemented. This gate is
preserved; no hypothetical reduced values are asserted as V3 mechanics.

That question is resolved by the continuation below. Temporary Luck entitlements, WIS-related maximum
changes and the remaining previously documented gates are not resolved by the
PAR or attribute-limit decisions. MAN and Time Sense rulings remain unchanged.

## Owner approved negative DEX and MAN allocation rule

Authority: explicit owner-approved Arena allocation rule, not a printed V3
formula. Universal for eligible characters and creatures.

Reduce whichever allocated value is currently higher, repeating one point at a
time. At a tie reduce DT before DP, or Aggressive Persuasion before Kindly
Persuasion. Never reduce a side below zero. The effective allocation total must
equal the legally reduced attribute pool within its valid bounds.

| DEX penalty on confirmed 6 DT / 3 DP | Effective DT | Effective DP |
| --- | --- | --- |
| 0 | 6 | 3 |
| -1 | 5 | 3 |
| -2 | 4 | 3 |
| -3 | 3 | 3 |
| -4 | 2 | 3 |

| MAN penalty on confirmed 7 AP / 3 KP | Effective AP | Effective KP |
| --- | --- | --- |
| -1 | 6 | 3 |
| -2 | 5 | 3 |
| -3 | 4 | 3 |
| -4 | 3 | 3 |
| -5 | 2 | 3 |

Temporary penalties affect only effective values. Recompute deterministically
from active source-qualified modifiers, without duplicate application or point
loss. Expiry restores the allocation appropriate to the remaining active sources;
with no penalties remaining, the original confirmed allocation remains intact.
Do not rewrite permanent confirmations.

Permanent reductions use the same higher-first and tie-break rules, recorded
through validated development history with event-time ordering and deterministic
replay. Do not silently restore permanently lost points or permit redistribution.
Any undefined later recovery/advancement operation remains gated. Existing
positive MAN allocation rules, authored exceptions and historical preservation
remain in force. No runtime support is enabled by this document.

## Next required ruling on temporary Luck entitlements

V3 p.23 defines ToF as accumulated points and RR/G as a per-game allowance;
p.38 says temporary attribute bonuses affect tied derived values. The charts
on pp.53/55 change the ToF entry from zero at LUK4 to +1 at LUK5, and RR/G
from zero at LUK15 to one at LUK16. Those entries do not define temporary
grant/spend/expiry behavior.

Questions: does temporarily crossing a ToF threshold grant a spendable point?
If yes, what happens to an unspent or already spent point on expiry and later
reactivation? For temporary RR/G, how is use accounted for after the bonus
expires or is reapplied during the same game? No entitlement or reset policy is
selected. Audit pauses for this ruling; no implementation is authorized.
