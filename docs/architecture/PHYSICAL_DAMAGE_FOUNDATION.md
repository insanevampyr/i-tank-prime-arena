# Physical Damage Foundation

## Scope and authority

Phase 1 Task 9 extends attacks whose ACC succeeded and whose legal defenses were exhausted into deterministic physical damage. Prime V3 pages 19, 25, 27, 95-98 and 124-138 provide weapon damage, eligible Strength Bonus, NAL, physical damage types, shield Block loss, hit-location multipliers and printed equipment data. The approved Arena damage ruling defines the order `weapon + eligible SB -> approved multipliers -> TAL -> NAL -> HPC`, the armor coverage mapping, combined-type protection, minimum-one rule and shield lifecycle.

This foundation does not contain production weapon or armor rows. Tests use clearly labeled fixtures. Specials, magical damage, critical consequence tables, NACs, AI, loot and progression remain outside this boundary.

## Source-driven data boundary

`CombatAttackDefinition` carries three-state duck eligibility and an optional `CombatPhysicalDamageDefinition`. A damage definition owns explicit dice, flat bonus, SB eligibility, minimum-one policy, location multipliers, optional critical multiplier, multiplier-stacking status, rounding policy and source references. Missing required facts stop resolution before damage RNG or mutation.

`CombatArmorDefinition` owns an equipment reference, one armor slot, explicit covered locations and explicit Bashing/Slashing/Piercing TAL values. A missing TAL for an incoming type is unresolved; it is not treated as zero. `CombatDamageProtectionProfile` owns equipped armor candidates plus exact-type immunity or weakness responses. A weakness must state its multiplier and whether it applies before or after protection.

Production imports must transcribe Prime rows and their exceptions. The engine does not infer dice, SB eligibility, TAL, immunity, weakness, location multiplier, critical multiplier, multiplier stacking or rounding from names.

## Authoritative transaction

Only an attack in `defenses_exhausted` may enter damage resolution. The authority preflights every required rule fact, then performs one transaction:

1. roll each weapon die from the seeded RNG;
2. add the explicit flat bonus and eligible SB;
3. reduce and combine every legitimate pre-protection type, location and critical multiplier as one exact rational product, multiply the subtotal, and round down exactly once;
4. select armor covering the struck location and subtract the lowest TAL for combined physical types;
5. subtract NAL;
6. apply an explicit source-specific post-protection response when applicable;
7. enforce the approved minimum-one policy unless an explicit immunity/exception overrides it;
8. reduce authoritative HPC once and record the complete causal result.

The record contains all weapon rolls and RNG draw indexes, components, applied multipliers, the exact combined numerator/denominator, the once-rounded multiplied total, selected armor/slot/TAL, NAL, type response, minimum-one flag, HPC before/after and event identity. The attack becomes `damage_resolved`, preventing a second application. A successful Dodge, Block or Physical Soak remains `defended` and is never damage eligible.

## Exact multiplier and fail-closed eligibility boundary

A natural or source-expanded ACC critical remains a recorded trigger, but physical damage does not invent its consequence. If no source-driven critical multiplier/effect exists, resolution returns `critical_damage_effect_unresolved` before damage RNG. When every factor is legitimate, Task #11 uses exact integer numerator/denominator composition with cross-cancellation and one floor before TAL and NAL. The old intermediate-rounding and unresolved-stacking paths are superseded by Combat Specification v1.6; unsupported factor eligibility still fails closed.

Head and neck use Prime's `3/2` (`x1.5`) location factor. The prior `x2 head` example was illustrative and is not production data.

These boundaries deliberately permit the verified ordinary subset while preventing an implementation convenience from becoming a rule.

## Duck eligibility

Prime V3 page 20 makes ducking geometry-dependent: a feasible horizontal threat may permit ducking while an overhead threat may not. Every attack/effect therefore declares `allowed`, `prohibited` or `unresolved`. Only `allowed` permits an in-place duck candidate. `prohibited` and `unresolved` continue evaluating independently legal displacement candidates. If unresolved ducking is the only otherwise viable candidate, the existing synchronized pending-displacement boundary records `attack_ducking_policy_unresolved` without movement or MR spending.

No production Special receives a duck policy in this task.

## Shield lifecycle

Prime V3 page 27 states that a successful shield Block costs one shield hit regardless of incoming damage. The authority subtracts exactly one SHP on a successful shield Block. The approved Arena rule makes zero SHP permanent destruction: the shield becomes unusable and is removed from authoritative equipped-item references. This project does not yet have a separate inventory subsystem; that future adapter must also delete the destroyed item rather than returning it to storage. Repair systems are not implemented.

## Determinism and synchronization

Damage definitions, protection profiles, resolutions, HPC, SHP and sequence counters are included in the authoritative snapshot. The physical-damage event follows its defense-resolution event causally at the same deterministic simulation timestamp. Passive clients receive the resulting transcript and snapshot; they never roll dice, choose armor or mutate HPC.

## Remaining designer/source gates

- Verify the protection-order stage for each source-specific weakness whose source does not state one.
- Author physical critical-success/failure consequences and item-specific expanded critical effects.
- Transcribe production weapons, armor, immunities, weaknesses and Prime-specific exceptions to minimum-one damage.
- Assign source-backed duck policies to production attacks and Specials individually.
- Define any item-specific shield interaction beyond the verified one-SHP successful Block rule.
