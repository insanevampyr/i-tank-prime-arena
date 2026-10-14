# ITank Prime Arena Rules Ledger

## Purpose

This ledger distinguishes verified Prime rules, approved designer corrections, locked Arena adaptations, provisional values, and unresolved items. It prevents implementation details from silently becoming game rules.

No missing formula, threshold, probability, creature statistic, Special effect, or exception may be inferred from genre convention. A disputed or incomplete rule remains unimplemented until its authoritative source is recorded and a designer ruling is obtained when necessary.

## Authority order

1. Actual ITank Prime V3 text and applicable Special descriptions.
2. Explicit designer corrections.
3. Approved Arena adaptations in the Combat Specification.
4. Provisional tuning values identified as provisional.

Legacy creature records and older Special sheets remain historical references. They do not automatically override a higher-authority source.

## Source registry

| Source ID | Source | Role | Current verification state |
| --- | --- | --- | --- |
| PRIME-V3 | ITank Prime V3 dated 03-01-2026 | Authority for tabletop mechanics and printed formulas | Exact excerpts and page pointers not yet entered in this project |
| ARENA-COMBAT-1.0 | ITank Prime Arena Combat Specification v1.0 dated 13 October 2026 | Approved Phase 0 Arena adaptation contract | Available; governs this foundation |
| ARENA-ROADMAP-1.2 | ITank Prime Arena Development Roadmap v1.2 dated 13 October 2026 | Approved phase and scope guidance | Available; governs Task 1 scope |
| CREATURE-PROTOCOL-2012 | Protocols for Creature / NPC Creating dated 2012 | Historical creature construction reference | Not yet audited into this project |
| BOOK-OF-BEINGS | Original Book of Beings records | Historical creature source records | Individual records not yet audited into this project |

## Confirmed and approved rules

| Rule ID | Classification | Rule | Source | Task 1 implementation status |
| --- | --- | --- | --- | --- |
| TIME-001 | ARENA LOCK | A combat round is approximately five seconds and remains the scope for round-limited rules. | ARENA-COMBAT-1.0 sections 2 and 10; ARENA-ROADMAP-1.2 section 3 | Implemented as an exact five-second simulation boundary in `CombatClock`; gameplay timing exceptions remain unresolved |
| EVENT-001 | ARENA LOCK | Authoritative actions are timestamped and ordered. Resolution success and finalization are distinct concepts. | ARENA-COMBAT-1.0 section 3 | Foundation event fields exist; action mechanics are not implemented |
| EVENT-002 | ARENA LOCK | Events at the same effect timestamp use higher INIT first, then a deterministic server tie-breaker. | ARENA-COMBAT-1.0 sections 2 and 3; ARENA-ROADMAP-1.2 section 3 | Implemented as descending INIT followed by stable creation sequence and event identifier |
| EVENT-003 | ARCHITECTURE LOCK | Combat simulation and authoritative event production remain independent of rendering, input, audio, saves, and network transport. | ARENA-ROADMAP-1.2 sections 1 and 7 | Implemented in the Phase 0 module boundary |
| SYNC-001 | ARCHITECTURE LOCK | A future host or server owns authoritative combat state and resolved event ordering; clients observe validated results rather than deciding them. | ARENA-COMBAT-1.0 section 10; ARENA-ROADMAP-1.2 sections 1 and 7 | In-process sequence, duplicate-delivery, ordering, and digest harness implemented; no transport exists |
| RNG-001 | ARCHITECTURE LOCK | Random choices used by rules must be seedable so tests and event replays are reproducible. | ARENA-COMBAT-1.0 section 10; ARENA-ROADMAP-1.2 section 7 | Seeded RNG wrapper implemented; no rule rolls implemented |
| ACC-001 | ARENA LOCK | ACC is checked for every valid attack; sprite contact is not an automatic hit. | ARENA-COMBAT-1.0 section 3 | Not implemented in Task 1 |
| HIT-001 | ARENA LOCK | Ordinary attacks target the torso; optional aimed locations use applicable Prime modifiers and armor coverage. | ARENA-COMBAT-1.0 section 3 | Not implemented in Task 1 |
| DEF-001 | ARENA LOCK | Attempt each remaining legal defense according to the saved priority, without combining incompatible defenses or inventing retries. | ARENA-COMBAT-1.0 section 3 | Not implemented in Task 1 |
| SR-001 | PRIME-BASED DESIGNER CORRECTION | SR automatically attempts to resist eligible unwanted Specials when lawful. A mistaken general reference to SR for physical soak is corrected to physical soak; individual Specials override. | ARENA-COMBAT-1.0 section 3 | Not implemented in Task 1; exact Prime cases require audit |
| NAC-001 | DESIGNER CLARIFICATION | A character may use at most five NACs in a five-second round. | ARENA-COMBAT-1.0 section 3; ARENA-ROADMAP-1.2 section 3 | Event schema can represent dependencies; NAC mechanics are not implemented |
| NAC-002 | ARENA LOCK | Magical NACs do not interrupt spells or other magical NACs. Physical interruption applies only where size and Special text permit. | ARENA-COMBAT-1.0 section 3 | Not implemented in Task 1 |
| COST-001 | ARENA LOCK | A begun Special commits its full resource cost even if unsuccessful or interrupted; unused future Acts are not spent. | ARENA-COMBAT-1.0 sections 2 and 3 | Event schema can record commitments; spending mechanics are not implemented |
| EXP-001 | ARENA LOCK | EXPM is lifetime experience and EXPC is spendable advancement experience. Spending EXPC does not reduce EXPM. | ARENA-COMBAT-1.0 section 8 | Not implemented in Task 1 |
| LOOT-001 | ARENA LOCK | Generate each creature's printed drops once into one physical reward pool, not once per participant. | ARENA-COMBAT-1.0 section 9 | Not implemented in Task 1 |
| LOOT-002 | DESIGNER CORRECTION | The armor-drop ten-outcome chart uses a d10 rather than the stated d20. | ARENA-COMBAT-1.0 section 9 | Not implemented in Task 1; exact table still requires transcription |

## Provisional values not treated as final rules

| Item | Current provisional direction | Source | Implementation state |
| --- | --- | --- | --- |
| MR global multiplier | Initial value 2x | ARENA-COMBAT-1.0 section 2 | Not implemented |
| Failed knockback Balance stagger | 0.5 seconds | ARENA-COMBAT-1.0 section 5 | Not implemented |
| Critical tables and weights | Three legal outcome tiers per category; entries and weights not authored | ARENA-COMBAT-1.0 section 6 | Not implemented |
| Player-relative scaling | EXPM-based, without punishing earned gear, Teleport, or Specials | ARENA-COMBAT-1.0 sections 7 and 8 | Coefficients unresolved; not implemented |
| Defeat penalties | Capped gold and unspent EXPC percentages, with a rare non-equipped item loss | ARENA-ROADMAP-1.2 section 4 | Values require approval; not implemented |

## Verify before code

- Transcribe exact Prime formulas and source page pointers for ACC, physical damage, armor by location and damage type, Dodge, Block, physical soak, SR, criticals, skills, experience bookkeeping, book drops, and creature creation.
- Record all exceptions to the per-action timing model, including zero-cost or NAC Specials, simultaneous actions, ongoing effects, and source-defined alternate timing.
- Produce deterministic worked examples for hit plus failed defense, successful defense, armor by location/type, SR, interrupted multi-Act Specials, dependent multi-NAC chains, and exact timestamp simultaneity.
- Audit Aren Valecrest, Garrick Ironward, and the first six creature candidates against current Prime requirements before implementing their combat data.
- Transcribe the original loot charts, including no-result and special-result entries, and independently validate the d10 armor correction and book-winner method.
- Obtain approval for exact movement scale, critical outcomes and weights, EXP scaling, co-op multipliers, participation thresholds, loot assignment edge cases, procedural item legality, and any Special-specific exception not present in the authoritative source.

## Task 1 implementation boundary

Task 1 implements only neutral infrastructure: integer timestamps, five-second boundary calculation, seeded random generation, deterministic event identifiers, dependency and resource-commitment fields, and queue ordering. It does not interpret payloads or implement attacks, defenses, Specials, NAC resolution, interruptions, damage, character progression, loot, creatures, AI, saves, or networking.

## Task 2 implementation boundary

Task 2 wraps authoritative simulation output in a sequence-numbered, transport-neutral protocol and verifies that two passive observers converge after duplicate and out-of-order delivery. State digests cover the canonical observed event transcript. This is not network transport, rollback, prediction, matchmaking, account state, or gameplay resolution.
