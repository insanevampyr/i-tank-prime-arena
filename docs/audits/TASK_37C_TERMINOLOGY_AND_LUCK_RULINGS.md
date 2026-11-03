# Task 37C terminology and consolidated owner rulings

Final audit review, 3 November 2026. Documentation only at main 22cbcd3.
Frozen extraction, source catalog and checksums remain unchanged.

## Exact terminology verification


| ABBREVIATION | EXACT V3 NAME | GOVERNING ATTRIBUTE | BOOK PAGE | CODE/DOCUMENT STATUS |
| --- | --- | --- | --- | --- |
| STR | Strength | Primary attribute | 19 | MATCH: ten stored primary keys; CON is not one of them. |
| END | Endurance | Primary attribute | 19 | MATCH: ten stored primary keys; CON is not one of them. |
| SPD | Speed | Primary attribute | 19 | MATCH: ten stored primary keys; CON is not one of them. |
| DEX | Dexterity | Primary attribute | 20 | MATCH: ten stored primary keys; CON is not one of them. |
| WIS | Wisdom | Primary attribute | 20 | MATCH: ten stored primary keys; CON is not one of them. |
| INT | Intelligence | Primary attribute | 21 | MATCH: ten stored primary keys; CON is not one of them. |
| WIT | Wits | Primary attribute | 21 | MATCH: ten stored primary keys; CON is not one of them. |
| MAN | Mannerisms | Primary attribute | 22 | MATCH: ten stored primary keys; CON is not one of them. |
| LUK | Luck | Primary attribute | 23 | MATCH: ten stored primary keys; CON is not one of them. |
| APP | Appearance | Primary attribute | 23 | MATCH: ten stored primary keys; CON is not one of them. |
| PAR | Personal Appearance Rating | APP | [23, 24] | Personal Appearance Rating verified; never Physical Attraction Rating; chart through 18. |
| CHA | Charisma | APP | [23, 24] | Source label verified; universal runtime lookup missing. |
| DT | Dodge Touch | DEX | 20 | MATCH naming/dependency; allocation ledger implemented; negative ruling not implemented. |
| DP | Dodge Projectile | DEX | 20 | MATCH naming/dependency; allocation ledger implemented; negative ruling not implemented. |
| ACC | Accuracy | DEX | 20 | MATCH: shared DEX ACC lookup 0-35, Mana/Regular. |
| NAL | Natural Armor Level | END | 19 | Live authored statistic/consumer exists; this is not a complete universal primary lookup. |
| PS | Physical Soak | END | 19 | Live authored statistic/consumer exists; this is not a complete universal primary lookup. |
| HPB | Hit Point Bonus | END | 19 | Live authored statistic/consumer exists; this is not a complete universal primary lookup. |
| S# | Skill Number | INT | [21, 67] | Source label verified; universal runtime lookup missing. |
| SCM | Skill Check Modifier | INT | [21, 67] | Source label verified; universal runtime lookup missing. |
| MIUR | Magic Item Use Rating | INT | [21, 67] | Source label verified; universal runtime lookup missing. |
| RB | Roll Bonus | LUK | 23 | Live authored statistic/consumer exists; this is not a complete universal primary lookup. |
| RR/G | Re-Rolls per Game | LUK | 23 | Exact printed label preserved; proposed Arena RR/W is owner-approved, not implemented. |
| ToF | Twists of Fate | LUK | 23 | Twists of Fate verified; no runtime entitlement ledger. Never Touch of Fate. |
| AP | Aggressive Persuasion | MAN | [22, 23] | Authored persuasion fields; no live effective calculation. AP is not Ability Points. |
| KP | Kindly Persuasion | MAN | [22, 23] | Authored persuasion fields; no live effective calculation. AP is not Ability Points. |
| MR | Movement Rate | SPD | [19, 20] | Live authored statistic/consumer exists; this is not a complete universal primary lookup. |
| AT | Action Total | SPD | [19, 20] | Live authored statistic/consumer exists; this is not a complete universal primary lookup. |
| SB | Strength Bonus | STR | 19 | MATCH: shared STR lookup 1-20; PPG/MWC are not initially registered in live Vaelis stats. |
| PPG | Push, Pull & Grip | STR | 19 | MATCH: shared STR lookup 1-20; PPG/MWC are not initially registered in live Vaelis stats. |
| MWC | Max Weight Capacity | STR | 19 | MATCH: shared STR lookup 1-20; PPG/MWC are not initially registered in live Vaelis stats. |
| SS | Special Success | WIS | [20, 21] | Live authored statistic/consumer exists; this is not a complete universal primary lookup. |
| MSL | Max Special Level | WIS | [20, 21] | Source label verified; universal runtime lookup missing. |
| MR/H | Mana Recovery per Hour | WIS | [20, 21] | Source label verified; universal runtime lookup missing. |
| INIT | Initiative | WIT | [21, 22] | Live authored statistic/consumer exists; this is not a complete universal primary lookup. |
| MNS | Max Number of Specials | WIT | [21, 22] | Source label verified; universal runtime lookup missing. |
| MRF | Max Regular Fields | WIT | [21, 22] | Source label verified; universal runtime lookup missing. |
| RCL | Resist Control Loss | WIT | [21, 22] | Source label verified; universal runtime lookup missing. |
| SR | Special Resistance | Independent resistance | 24 | Stored as sr; not derived from WIS by a fabricated formula. |
| TB | Tolerance Bonus | Independent; applicable tolerance skill | 24 | MISMATCH: catalog identifier talent_bonus and Rules Ledger Talent Bonus. Flag only; no identifier/save migration. |
| AP (resource) | Ability Points | Ability-user level progression | 24, 72 | Separate shared resource, not MAN persuasion AP. |
| HPM | Hit Points Max | Racial start, HD, END-derived HPB, recorded growth | 16, 17, 44, 72 | Authored baseline plus recorded level growth; no rerolls. |
| HPC | Hit Points Current | Current health state | 17 | Resource expenditure, not primary-derived maximum. |
| BM | Blood Max | Racial/authored source | 16, 44 | No invented END-to-BM formula. |
| BC | Blood Current | Current blood state | 16 | Distinct resource; source-defined loss impacts STR/END. |
| Mana Max | Mana Max | WIS and event-time level growth | 21, 24, 72 | Current growth implemented; WIS purchase effect still gated. |
| Mana Current | Mana Current | Current Mana state | 24 | Not automatically refilled by maximum changes. |


## Resistances as independent character statistics

SR (Special Resistance) and TB (Tolerance Bonus) are neither primaries nor
derived attributes. V3 p.24 places them under Resistances. V3 p.43 supplies racial
starting values; authored actor definitions and explicit Specials/items may
supply additional source-qualified values. Neither has a primary-to-resistance
formula. Do not derive SR from WIS or TB from END.

| Resistance | Printed mechanic | Advancement and current implementation |
| --- | --- | --- |
| SR — Special Resistance | p.24: eligible unwanted magic/abilities can be resisted by d20 <= SR when not surprised. May precede or follow a Dodge/Soak; this does not authorize combining Dodge and Soak. Applicable Special exceptions still control. | p.102 price brackets; stored sr and supported resistance purchase/projection. General Special-resistance resolution remains unimplemented/source-gated. Existing ledger SR-001 separately approves automatic eligible attempts; do not mislabel that Arena automation as the printed optional wording. |
| TB — Tolerance Bonus | p.24: add TB to applicable tolerance Skill check number for toxins/alcohol/poison. Example END-based Poison Tolerance -10 becomes -9 with TB1. END governs that skill, not TB itself. | Same p.102 brackets, independent stored tb. Current Vaelis TB0 has no printed zero-to-one purchase price and remains blocked. Generic tolerance resolution is not implemented by the advancement catalog. |

Current-value brackets, under the existing accepted Arena interpretation, are
1-5: 2000; 6-10: 3000; 11-15: 5000; 16-20: 7000; 21-30: 8000; 31+: 10000 EXPC.
No zero price or primary-attribute ceiling is inferred for a resistance. Attribute
20/25/Immortality limits do not silently become SR/TB caps. Validate each explicit
modifier's source, duration, stacking and applicability without inventing bonuses.

The internal purchase kind `talent_bonus` is incorrect terminology but may occur
in receipts, validators and saved histories. Safest eventual correction: first
map that unchanged identifier to player-facing “Tolerance Bonus” in the display
layer and correct explanatory documentation in a separately authorized pass.
Keep canonical wire/storage identities and checksum-covered historical records
unchanged. A later canonical identifier change would require explicit versioning,
legacy-read compatibility and receipt/deduplication tests; never bulk rename it.
No identifier, live label or save was changed in this audit.

Future read-only Character Sheet: separate categories for Primaries, Derived
Attributes, Resistances and Resources. Show SR/TB from admitted authoritative
actor state, with base/effective values and modifier provenance where actually
available. An unresolved value is “unavailable,” not zero. SR/TB are not placed
under WIS/END or represented as extra primary attributes. Sheet inspection must
consume no RNG, spend nothing, and neither hydrate nor save a character.


## Owner approved temporary Twists of Fate policy

Explicit Arena adaptation pending implementation. A temporary LUK increase may
grant temporary spendable ToF when an actual printed threshold is crossed.
Track it separately from permanent cumulative ToF. Unspent entitlement disappears
on expiry; spent entitlement remains consumed. Reactivating the same source
cannot regenerate spent entitlement. Expiry never reverses an already resolved
effect. Source identity and spending history must survive save/reload. No toggle
or repeated-cast farming, permanent-pool mutation or invented replenishment.


## Owner approved Arena RR/W adaptation

Keep original V3 “Re-Rolls per Game” (RR/G) in source transcription. Arena uses
Rerolls per Wave (RR/W), pending implementation, based on the printed LUK allowance.
The first eligible critical failure automatically spends one available reroll.
The replacement substitutes for the original even if unsuccessful; it cannot
trigger a further reroll. Later distinct eligible failures may use remaining
allowance. No duplicate activation or RNG-order ambiguity is permitted.

Unused allowance expires on wave completion. Each genuinely new authorized wave
has its applicable Luck allowance. Temporary Luck counts only while legally
active; expiry/reapplication must not replenish already spent rerolls within
that wave. Equipment changes, Special reactivation, save/load, NEXT WAVE retries
and UI navigation do not establish a new wave identity. Preserve authoritative
history, deterministic RNG/replay and client convergence.

V3 pp.16/92 define ordinary critical results for d20 skill, attribute and derived
attribute checks, not ordinary damage/HD rolls or d10 initiative. RR/W must not
invent additional critical categories. Natural die and replacement lineage need
separate records; replacement resolution precedes committing its consequences.
The p.271 One True God “LUCK” Special is a separate source-specific reroll with
its own once-per-game-session, NAC, no-SS and Mana rules. Do not convert it into
RR/W, auto-grant it, or reset its separate allowance each wave. Future interaction
with another reroll source must be checked before integration, not guessed.


## Proposed architecture additions only

Use a wave-qualified entitlement ledger separate from chart-derived capacity.
Record provenance, source lifetime, capacity, debits, original roll identity and
replacement identity. Idempotent debit/publication prevents two consumers from
rerolling one opportunity. Preserve same-source spending tombstones after expiry.
ToF and RR/W need distinct histories; neither is the RB roll modifier. Replay
must never re-run the entitlement grant logic as a fresh award.

This requires explicit future persistence validation: never place unrecognized
fields in V2 saves or silently reset spending on hydration. No schema change,
new grant, reroll or entitlement storage is implemented in this pass.


## Confirmed permanent WIS and Mana Max ruling

Explicit designer ruling supplementing V3 pp.21/72, pending implementation.
For a legal permanent WIS10->11 purchase, WIS and Mana Max each increase by
exactly one; current Mana does not change. Earlier recorded level-up Mana gains
do not change. Each future level gain uses its own applicable event-time WIS.

The proposed accounting is the legal starting Mana Max, plus actual recorded
level-up gains, plus validated post-creation permanent WIS-increase contributions.
The subsequent owner ruling excludes temporary WIS contributions entirely.
The WIS10->11 contribution is exactly +1, applied once. Never recompute old level
gains using current WIS, refill current Mana, or apply the contribution again on
reload, restoration, replay or synchronization.

Historical starting WIS and event-time growth remain authoritative. Where an old
history lacks sufficient evidence, reject the unsupported reconstruction or gate
that operation explicitly; do not invent a roll, WIS value, grant or chronology.
This is a compatibility requirement, not a finding that current accepted profiles
are invalid: WIS purchases are currently disabled.

Subsequent confirmed temporary-WIS and permanent-loss policies below govern those cases; no new recovery mechanic is authorized.


## Confirmed temporary WIS and Mana ruling

Explicit owner ruling, audit only: temporary WIS increases do not affect Mana
Max or current Mana. Temporary WIS changes never automatically grant, remove,
refill or clamp Mana. Their expiration changes neither Mana value solely because
the modifier expires. This supersedes proposed temporary-WIS-to-Mana
calculations; no temporary Mana contribution is to be inferred from the generic
V3 p.38 derived-value rule.

Permanent +1 WIS remains distinct: exactly +1 Mana Max, current Mana unchanged,
past level-up gains unchanged, and future gains evaluated at their applicable
event-time WIS. Retain starting, purchased and historical growth provenance;
do not duplicate any contribution on hydration, restoration, replay or sync.
The historical questions above are resolved, not current blockers.


## Confirmed permanent WIS loss ruling

Explicit designer ruling, pending implementation: permanent WIS loss does not
reduce existing Mana Max or current Mana. The reduced permanent score affects
future level-up Mana growth only, using the score applicable at that event.
Never recompute historical level gains from current WIS.

The asymmetry is intentional: permanent +1 WIS grants +1 Mana Max without
refilling current Mana; permanent WIS loss causes no immediate change to either
Mana value; temporary WIS changes also cause no change to either value. No
inverse deduction, clamp, refund, historical rewrite or new recovery operation
is authorized. Prior permanent-WIS-loss questions above are resolved.

An eventual Mana projection must sum validated positive permanent WIS grant
events, not substitute current WIS minus starting WIS as a net-delta formula.
Loss events still affect the applicable WIS for subsequent growth. Stable event
identities and chronology must prevent replaying an increase as a fresh grant.
Do not manufacture missing history or authorize a later recovery/purchase merely
because the increase calculation is known.


## Confirmed encumbrance threshold ruling

Explicit designer-approved Arena interpretation of V3 p.19, pending implementation.
At exactly MWC, penalties are zero. For positive whole-pound excess E, subtract
floor(E/10)+1 from effective MR and floor(E/20)+1 from each of DT and DP.
This is not ceil(E/10) or ceil(E/20): exact positive multiples enter the next
penalty band under the owner's specified formula.

| Excess weight lb | MR modifier | DT modifier | DP modifier |
| --- | --- | --- | --- |
| 0 | 0 | 0 | 0 |
| 1-9 | -1 | -1 | -1 |
| 10-19 | -2 | -1 | -1 |
| 20-29 | -3 | -2 | -2 |
| 30-39 | -4 | -2 | -2 |
| 40-49 | -5 | -3 | -3 |
| 50-59 | -6 | -3 | -3 |

Penalties affect effective derived values, not permanent primary scores or
confirmed allocations. Removing excess weight removes its penalty contribution.
Retain source identity to prevent repeated application. DT is Dodge Touch,
never Dodge Target. The scoped labels search found no incorrect DT expansion;
generic prose about the target number of a Dodge is not an expansion of DT.

Implementation still requires verified carried-item weights. Existing Rules
Ledger equipment gates do not supply a complete inventory-weight total; the new
formula does not authorize inventing item weights or a capacity system.


## Confirmed signed Dodge and MR floor ruling

Explicit owner-approved universal rule, documentation only. Effective DT (Dodge
Touch) and DP (Dodge Projectile) may be negative. Sum all legitimate signed
bonuses and penalties once; preserve the signed result for later modifiers.
Negative Dodge does not add another die-roll penalty and is never clamped to
zero. Established natural 1/20 critical rules and ordinary threshold comparisons
remain unchanged. Effective MR (Movement Rate) cannot fall below zero.

Example: DP1 with encumbrance -3 yields effective DP-2; a later legitimate +5
yields DP3, not DP5. These effective modifiers do not change confirmed permanent
DT/DP allocations. The separate nonnegative allocation-point rule remains valid.

Code comparison: `CombatSimulation.get_effective_actor_combat_stat` returns
signed derived modifiers; the defense pipeline adds target modifiers without a
zero clamp. It resolves natural critical success/failure before comparing the
adjusted roll to the final target. `PrimeMovementModel.get_walking_mr` uses a
zero floor. This is source/code inspection, not a newly executed gameplay test.
Encumbrance and signed allocation-loss integration are still not implemented.


## Source-specific Immortality evidence

V3 p.64 lists racial Immortal abilities; p.141 explicitly permits Angels to
exceed normal 20/25 limits. Demon text on p.146 permits exceeding mortal limits.
Frozen in Time (p.253) explicitly permits scores above 25 and imposes double
fire damage, among its source conditions. Named Immortality entries on pp.258
and 269 describe freedom from old-age death, not immunity to outside forces,
and preserve prior eating/drinking/sleep requirements. Do not erase those
distinctions or grant an ability from its chart row. Eligibility must cite its
actual source and validated possession; no new Immortality system is implemented.


## Additional confirmed rulings retained

MAN permanent AP+KP=MAN; new standard 50/50 whole-point split, balancing odd
points with a documented deterministic tie-break; no combat RNG or free respec.
Temporary MAN increases split automatically as separately tracked contributions.
Authored exceptions and historical allocations remain untouched. Full details
remain in TASK_37C_OWNER_RULINGS_PAR_AND_LIMITS.md; its former questions are historical.
Negative DEX/MAN reductions use higher-first removal with DT/AP tie-breaks,
nonnegative allocation points and event-time permanent history. Effective Dodge
modifiers remain signed separately from that allocation-point floor.
PAR above 10 follows printed progression through 18 as supernatural attraction;
no new social powers are inferred. Attributes 21-25 require a qualifying Special
or Special-imbued item; 26+ requires separately established Immortality. No
extrapolation beyond 35. Time Sense p.67 is the confirmed erratum: SI1-5 gives
-2,-1,0,+1,+2, preserving automatic-skill exceptions (p.27 general rule).

## Historical questions resolved

The former MAN base allocation, Time Sense worked example, PAR range, negative
allocations, temporary Luck, permanent WIS gain, temporary WIS, permanent WIS
loss, encumbrance threshold and derived lower-bound questions are CLOSED by the
owner rulings above. They are not requests for new decisions. Earlier appended
HTML questions have been moved out of the current comparison.

## Genuine remaining boundaries

TB0->1 has no printed price; do not enable that purchase without authority.
Fractional carried-weight handling is outside the approved whole-pound rule;
missing item weights cannot be invented. Undefined permanent recovery operations
and interactions between future additional reroll sources remain gated. These
are not blockers for a dormant table/read-only descriptor phase. Event-time
resource history, durable Luck identities and a general MAN development record
need explicit compatibility design before live integration, not silent migration.
