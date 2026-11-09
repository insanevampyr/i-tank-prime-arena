# Task 39H: isolated Balance foundation

No live critical, knockback, collision, death, persistence or AI hooks call these queries.
Save Contract V2 and simulation schema 12 remain unchanged.

## Interfaces

`BalanceSkillCheck.resolve(profile, natural_roll)` is pure. `roll(profile, rng,
opportunity_id)` validates first, then consumes one supplied seeded d20. It returns
local evidence (opportunity identity, draw index, raw/adjusted roll, target, critical
flags and source inputs), not a published CombatEvent. It changes no conditions.
The caller owns eligibility and future exactly-once opportunity processing; repeated
calls are not a receipt store. Do not pass live simulation RNG until separately
approved integration defines causal placement and deduplication.

`BalanceActorProfile.capture(resource, actor, state, now_us)` queries an explicitly
supplied definition and matching actor/state. It requires matching actor kind,
field-source dictionaries and permanent DEX reference; unsupported changed permanent
DEX is rejected rather than reconstructed. No skill is inferred from missing data.
These checks are consistency checks, not authentication of arbitrary caller data.

Balance records live in the existing resource `proficiencies` dictionary. The adapter
requires training, SI, explicit SCM and a source reference. Existing actor RB must be
present. No actor fields, snapshots, saves or admission paths are extended.
Vaelis has authored SI2, SCM0 and live RB0. The boss has sourced SI1/SCM0 but lacks
live RB: `balance_rb_unavailable` is intentional. Other actors without skill records
return `balance_training_unknown`; an explicit SI0/untrained record is different.

Active existing timed-stat records may supply DEX, SCM, RB or Balance modifiers.
Relevant entries require integer values, encounter expiry and source/activation IDs.
Projection sums signed modifiers deterministically by sorted effect keys, rejects
duplicate activation identities, and ignores expired entries without removing them.
Only encounter time supplied by the caller is read; no wall-clock aging is added.
A record is a source declaration, not permission to add an unapproved Special.

## Verified rules

V3 pp.27/67: each additional SI adds one; SCM contributes to target. Page69 lists
Balance under DEX with initial -1 and no automatic/trained-only symbol. Page107
specifies maintaining footing when knocked down/back. Page23 preserves natural
criticals despite RB. SI>=1 target = effective DEX -1 +(SI-1) +SCM +verified modifier.
Explicit untrained target = effective DEX -1 -4 +SCM +verified modifier. Adjusted roll
is raw d20 minus legal RB; natural1 succeeds critically, natural20 fails critically.
There is no SI3 automatic Balance and no Balance-specific consequence table.
Numeric bounds in input validation prevent unsafe arithmetic, not chart extrapolation
or new attribute eligibility. Negative effective values remain signed.

## Approved owner policy, NOT activated here

Each independently resolved eligible knockdown/knockback effect has one Balance
opportunity unless already prone or explicitly excepted. Success preserves footing,
not displacement; failure permits prone without automatic Critical Stagger.
Obstacle-blocked knockback still requires Balance; already-prone targets still undergo
legal displacement/collision handling. Owner collision pricing is 1d10 per whole foot
prevented (fractional feet rounded down), minimum1 for a valid damaging collision,
default bashing. TAL/NAL and surface classification remain verification gates.
No collision calculation or RNG is implemented in this foundation.

Future work must establish live opportunity identities, eligible source exceptions,
causal event evidence, chain ordering and unknown-actor handling before connecting
critical fall rows or Rage/Force Bolt/Force Shield. Existing knockdown behavior stays
unchanged until separately authorized. Production persistence of skill development
and dynamic permanent-DEX rebasing are outside this pass.
