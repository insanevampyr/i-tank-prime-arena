# Physical Defense Foundation

## Scope and authority

Phase 1 Tasks 7-9 extend a successful physical ACC result through deterministic Dodge, weapon Block, shield Block and Physical Soak resolution, including automatic Dodge destination selection and attack-specific duck eligibility. Prime V3 pages 19-20, 23, 25, 27, 31 and 91-94 define the relevant targets, roll-at-or-below checks, MR cost and natural critical triggers. The Arena Combat Specification supplies saved priority, independent Block fallback, awareness restrictions, zero-Act defense cost and shield lifecycle rulings.

Damage after exhausted defenses is documented separately in `PHYSICAL_DAMAGE_FOUNDATION.md`. This defense layer does not resolve Specials/NACs or apply critical consequences.

## Data boundary

`CombatAttackDefinition` now carries explicit physical delivery, damage-type and Physical Soak eligibility facts. Missing delivery or Soak eligibility remains unresolved; the defense selector does not infer them from a weapon name.

`CombatDefenseProfile` stores all four supported candidates exactly once in configurable order, candidate modifiers, and optional source-referenced weapon/shield Block definitions. `CombatBlockDefinition` stores the equipment reference, BLK target, proficiency/usable evidence and current shield SHP when applicable. Production item rows are not included; tests use labeled fixtures.

`CombatDefenseResolution` owns the saved priority, ordered attempts, status, successful candidate, causal events and any pending Dodge selection. Each `CombatDefenseAttempt` records:

- defense type and equipment;
- `ineligible`, `eligible_not_selected` or `attempted` status and reason;
- base target, declared modifier and final target;
- RB, natural d20, adjusted roll, RNG draw index and natural critical flags;
- ordinary success/failure, exact resources spent and causal event identifiers.

## Transaction lifecycle

Only the authoritative simulation may resolve a `pending_defense` attack. It validates the profile and Dodge context before consuming RNG, then creates one defense transaction. Each legal failure proceeds to the next configured candidate exactly once. Weapon and shield Blocks are independent candidates. The first successful defense stops further rolls; remaining entries are retained as `eligible_not_selected`. If no candidate succeeds, the attack becomes `defenses_exhausted`, which is a future damage input rather than damage itself.

Actually attempting Dodge or Physical Soak excludes the other for that attack. Merely considering or rejecting an ineligible candidate does not. Surprise or unawareness makes every active physical defense ineligible. Block requires its exact equipped, proficient and usable item. Physical Soak requires explicit source eligibility and rejects piercing and back attacks. Natural 1/20 flags use the unmodified d20; RB changes only the adjusted ordinary result. Critical consequences remain unauthored.

## Dodge displacement boundary

`CombatDodgeEnvironment` is the authoritative candidate-set boundary. Each `CombatDodgeCandidate` provides a stable ID, integer destination and path cost, path/collision/terrain/occupancy facts, attack-escape or duck-sufficiency evidence, a nonnegative source-owned known-hazard tier and a source reference. Combat code does not calculate collision shapes, terrain rules, hazard severity or duck permission.

For complete environmental data, the authority rejects illegal candidates and candidates beyond Prime's half-MR or remaining-round-MR limits. It chooses the nearest path cost within the lowest known hazard tier, followed by stable candidate ID and coordinates. A legally sufficient in-place duck has zero cost and therefore wins nearest selection in its safety tier only when the attack's explicit policy is `allowed`. `prohibited` and `unresolved` skip ducking while retaining legal displacement candidates. `CombatDodgeContext` retains this selection evidence. Successful Dodge spends the exact cost once and changes position only for displacement.

When authoritative environmental information is incomplete, automatic selection produces an `ambiguous` context. A successful roll changes the attack to `pending_dodge_displacement`; position and MR remain untouched and are included in the synchronized snapshot. An authority-supplied resolved context at the same simulation timestamp completes the same successful Dodge without another d20. If time has advanced, completion fails closed instead of spending a later round's MR. Duplicate completion cannot spend MR twice.

The engine chooses only among authority-supplied candidates. It never guesses missing geometry, treats hazards as harmless, invents duck eligibility, crosses an unverified path or teleports an actor.

## Shield boundary

Current SHP is preserved in the defense profile snapshot. Prime p. 27 charges one SHP for every successful shield Block. Task 9 subtracts that point in the authoritative defense transaction. At 0 SHP the shield becomes unusable and its equipped reference is removed according to the approved Arena destruction rule. Repair and separate inventory integration remain deferred.

## Determinism and synchronization

The authoritative snapshot schema includes defense profiles, resolutions, attempts, pending Dodge state, remaining round MR and defense sequence counters. Defense events use the existing integer timestamp, INIT and stable-sequence ordering. The transport-neutral observers receive only authoritative event/state envelopes; they never roll defenses or choose outcomes.

## Phase 1 Task 9 refinement

Attack definitions now require an explicit duck policy. An allowed in-place duck participates in normal deterministic selection; prohibited or unresolved ducking cannot be silently chosen. An unresolved-only candidate preserves the synchronized pending boundary. Successful shield Blocks spend one SHP and enforce the approved zero-SHP destruction state. Ordinary damage after exhausted defenses is handled by the separate physical-damage foundation.

## Deferred decisions and data

- Author action-specific critical success/failure consequences. Task 7 records triggers only.
- Supply production collision/navigation candidate generation, terrain legality, occupancy, known-hazard tiers and attack-specific duck/escape facts. Incomplete data intentionally remains pending.
- Transcribe production actor DT/DP/PS/RB, weapon BLK, shield BLK/SHP/proficiency and physical delivery/type data.
- Integrate the approved 0-SHP deletion with a future inventory subsystem and keep repair source-driven.
- Keep magical projectiles, Special Resistance, NACs and source-specific exceptional technology outside this physical-only boundary.
