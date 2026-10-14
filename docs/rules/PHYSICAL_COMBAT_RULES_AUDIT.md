# Physical Combat Rules Audit

## Purpose and authority

This audit defines the verified rules boundary for Phase 1 physical combat. It does not authorize gameplay code by itself. The authority order is:

1. `ITank Prime V3 03-01-2026` (`PRIME-V3`), using the matching PDF for stable page references.
2. Explicit designer corrections recorded in the Arena Combat Specification.
3. Approved Arena adaptations in the Combat Specification, including the internal v1.2 Running addendum, controlling v1.3 action-timing amendment and v1.4 implementation gate.
4. Phase and scope direction in the Roadmap, including the internal v1.4 movement and v1.5 timing milestones.

`Confirmed` means the cited source supplies enough information to preserve the rule. `Ambiguous` means the source establishes the concept but not every implementation detail. `Unresolved` means code must not choose an answer without designer approval or additional authoritative text.

## Source map

| Source | Relevant location | Content used |
| --- | --- | --- |
| PRIME-V3 | pp. 16, 19-25 | Criticals; SB; NAL; Physical Soak; MR; AT; DT; DP; ACC; INIT; SR; RB; LTAL/TAL; weapon and block definitions |
| PRIME-V3 | pp. 27, 31-32 | Shield damage on a successful block; authoritative combat and defense order |
| PRIME-V3 | pp. 35-40 | Conditions, prone, physical damage and effect timing framework |
| PRIME-V3 | pp. 52-56 | Attribute-chart lookup method and the Mana/Regular derived-attribute tables |
| PRIME-V3 | pp. 67 and 69 | Generic Skill equation, SCM/investment rules, untrained penalty, automatic markers and Running's END `-2` listing |
| PRIME-V3 | pp. 91-94 | Core d20 checks, modifiers, critical results and rule precedence |
| PRIME-V3 | pp. 95-98 | Size categories, aimed-location ACC modifiers, location numbers and head/neck damage multiplier |
| PRIME-V3 | pp. 105-109, 112 | Generic Skill investment/automatic rules, Running, Balance, shield proficiencies, Throw and incomplete knockback maneuver guidance |
| PRIME-V3 | pp. 124-138 | Printed weapons, damage dice/types, weapon Block ratings, armor and shield charts, exceptional critical ranges |
| PRIME-V3 | pp. 348-351 | Consolidated combat, dice, damage and condition quick references |
| ARENA-COMBAT-1.0 | sections 2-6 and section 10 | Real-time timing, automated defenses, event finalization, physical-soak correction, damage constraints, knockback and critical-table direction |
| ARENA-ROADMAP-1.2 | sections 3, 5 and 7 | Phase 1 scope, required regression gates and authoritative architecture |
| ARENA-COMBAT-1.2 | section 14 addendum | Final five-second Running maintenance, END-based cap, recovery and cooldown rules; supersedes earlier Running timing references |
| ARENA-ROADMAP-1.4 | section 10 milestone | Phase 1 Task 3 Running completion and validation scope |
| ARENA-COMBAT-1.3 | section 15 amendment | Controlling no-storage `5 seconds / AT` action duration and cross-round timing rule |
| ARENA-COMBAT-1.4 | section 16 reconciliation | Confirms Task 5 timing and identifies opening Initiative plus ACC as the next implementation boundary |
| ARENA-ROADMAP-1.5 | section 11 milestone | Targeted Task 5 correction scope and validation gate |

## ACC attack accuracy

**Status:** Confirmed rule; derived values require exact table transcription.

**Original Prime mechanic:** ACC is the DEX-derived target number used whenever a character attempts to hit physically or magically. Roll `1d20`; a natural result equal to or below the applicable ACC succeeds after declared modifiers. The DEX column in the appropriate Mana or Regular Attribute Chart supplies ACC as a lookup value rather than a formula. Hit-location and size differences apply the printed ACC modifiers on pp. 95-97. Prime also contains weapon-specific expanded critical ranges, which do not change the ordinary success target.

**Approved Arena adaptation:** Every otherwise-valid attack must roll ACC. Visual collision never substitutes for the roll. Ordinary attacks target the torso; aimed-location attacks use the Prime size/location modifier table. Sources: ARENA-COMBAT-1.0 section 3; ARENA-ROADMAP-1.2 section 3.

**Dependencies:** DEX-derived ACC, Mana/Regular character type, equipment and condition modifiers, attacker/target size category, selected hit location, natural-roll critical handling, range, line of sight and target validity.

**Open verification:** The complete ACC lookup tables must be transcribed as source data and tested row by row. Weapon text that says `2 or lower ... is a critical strike` needs an approved effect definition; it cannot be assumed to mean the generic natural-1 result or automatic double damage.

**Task 6 implementation:** The authority validates actor/target identity, equipped weapon reference, resolved range, integer position, torso/aimed-location support and authoritative line-of-sight evidence before scheduling. At the final action boundary it records base ACC, sourced modifiers, RB, natural d20, adjusted result, RNG draw index and critical trigger. Success enters `pending_defense`; failure enters `missed`. Only explicitly labeled test fixtures supply weapon/range/modifier values until production tables are transcribed.

## AT actions and attack timing

**Status:** Prime mechanic confirmed; Arena timing model confirmed; exception catalog incomplete.

**Original Prime mechanic:** AT is the SPD-derived number of actions available in a turn. One-action characters take approximately five seconds per action; characters with more AT complete their actions within the same approximately five-second round. Movement does not consume an action. Actions that cannot reasonably finish in one act may require multiple acts. Sources: PRIME-V3 pp. 20, 31-32 and the SPD lookup tables on pp. 53-56.

**Approved Arena adaptation:** The controlling v1.3 rule removes storage and recharge. One ordinary Act lasts `5 seconds / AT`; an eligible action begins immediately and occupies its full interval. Multi-Act actions occupy successive intervals and take effect on the final required interval. Actions continue normally across five-second round boundaries. INIT controls opening/simultaneous ordering but never execution speed. NACs are independent and cost zero ordinary Acts. Sources: ARENA-COMBAT-1.3 section 15; ARENA-ROADMAP-1.5 section 11.

**Dependencies:** Combat clock, round index, actor AT, cumulative rational interval index, action definition, action start/effect/finalization timestamps, interruptions and committed costs.

**Open verification:** All physical actions need an explicit Act cost. The general weapon attack cost appears to be one Act, but reload, rate, draw/equip and exceptional weapon text must be represented individually rather than inferred. Timing exceptions outside the audited physical subset remain deferred.

## INIT initiative

**Status:** Prime opening initiative and Arena timestamp tie-break confirmed; one printed tie rule is superseded for deterministic Arena play.

**Original Prime mechanic:** At combat start each participant rolls `1d10 + INIT`; highest total acts first. PRIME-V3 p. 21 says tied totals use higher base INIT and an exact remaining tie acts simultaneously. PRIME-V3 p. 31 instead allows Storyteller discretion favoring awareness and positioning, otherwise simultaneous action. Initiative normally remains for the combat.

**Approved Arena adaptation:** Opening initiative remains `1d10 + INIT`. Exact simultaneous effect timestamps resolve by higher base INIT, followed by a stable deterministic server tie-breaker. If both effects legally reached that point, both may still land unless a legal interruption changes the second outcome. Sources: ARENA-COMBAT-1.0 sections 2-3; ARENA-ROADMAP-1.2 section 3.

**Dependencies:** WIT-derived INIT lookup, opening d10 roll, effect timestamp, stable sequence and interruption/finalization state.

**Open verification:** Prime supplies order but no seconds-based separation between opening positions. Task 6 gates first declarations by ranked order at one simulation timestamp and gives exact total/base-INIT ties simultaneous eligibility. It does not invent an Initiative-to-time conversion. Special- or condition-specific initiative changes must be audited when those sources enter scope.

## MR movement rate and Running

**Status:** Prime Running calculation confirmed; Arena real-time activation, maintenance, duration and recovery rules approved and implemented.

**Original Prime mechanic:** MR is the SPD-derived feet/squares available per turn. It may be split before, during and after acts. Movement is not an action. Dodge movement consumes remaining MR. Encumbrance and armor can reduce MR. Sources: PRIME-V3 pp. 19-20, 31, 53-56 and 135.

**Original Prime Running mechanic:** Running is listed under END with modifier `-2` and marker `ª`. A recorded Skill uses `attribute + printed modifier + SCM` as its roll-at-or-under d20 target. The first investment grants the printed modifier; each additional investment raises it by `+1`. Because Running lacks `Ø`, an untrained attempt is legal with the general additional `-4` penalty. Three investments make the Skill automatic. RB beneficially adjusts attribute-related rolls but cannot turn a natural 1 into anything but critical success or a natural 20 into anything but critical failure. The historical Running entry adds 3 MR per successful check, permits stacking, requires ten movement spaces before action, limits turns to 45 degrees, checks every five minutes, permits `END x 5 minutes` maximum duration and requires equal rest. Sources: PRIME-V3 pp. 23, 67, 69, 105-106.

**Approved Arena adaptation:** MR is canonical feet traveled per exact five-second round, making speed `effective MR / 5` feet per second. Movement may continue during eligible attacks, casting and Specials. Shift plus movement requests immediate activation with the verified Running check and adds one nonstacking `floor(current effective SPD / 2)` MR bonus on success. The same check repeats every five seconds unless the Skill is automatic. Maintenance failure ends Running immediately and starts a five-second cooldown. Maximum continuous time is `END x 5 seconds`; that cap wins a simultaneous maintenance tie without another roll. Recovery debt equals actual Running time, clears at 100% while standing or 50% while walking, and must reach zero along with cooldown before another attempt. Intentional stop or Shift release ends Running; transient input loss/collision does not. The 45-degree restriction remains. Automatic proficiency bypasses activation and maintenance rolls but not cap, recovery or movement restrictions. Sources: ARENA-COMBAT-1.2 section 14; ARENA-ROADMAP-1.4 section 10.

**Dependencies:** Effective SPD and END, Running investments, SCM, RB, authoritative d20 source, armor/encumbrance/condition/Special modifiers, canonical feet, visual scale, integer simulation time, collision/path rules and Dodge displacement.

**Resolution:** For Skill investment `SI`, the implemented target is `END - 2 + SCM + max(SI - 1, 0)`, with an additional `-4` when `SI = 0`. RB benefits the rolled result while critical classification uses the unmodified natural die. The historical stacking `+3 MR`, ten-space buildup, five-minute maintenance and minute-based cap are expressly superseded by ARENA-COMBAT-1.2. No Running formula remains unresolved.

## Dodge DT and DP

**Status:** Core eligibility confirmed; automated spatial choice requires an engineering policy constrained by Prime.

**Original Prime mechanic:** DEX supplies a pool of points allocated between DT and DP. DT defends against hand-held physical attacks; it does not defend against thrown weapons or magical projectiles. DP defends against thrown weapons and magical projectiles; it does not defend against hand-held physical attacks. Roll `1d20` at or below the applicable value. A character may Dodge when not surprised or held, but may not Dodge and Physical Soak against the same attack. A successful Dodge may move up to half MR, rounded down, and must leave the attack range/path; the distance spent reduces remaining round MR. A feasible in-place duck is allowed. Sources: PRIME-V3 p. 20 and combat order p. 31.

**Approved Arena adaptation:** Legal defenses are attempted automatically according to a saved priority. Default balanced priority is Dodge, then Block, then Physical Soak. Mutually incompatible defenses remain incompatible after an actual attempt; merely considering or rejecting an ineligible Dodge does not exclude Physical Soak. Automatic Dodge selects the nearest candidate within the safest known legal hazard tier and uses stable candidate identity as the final tie-break. A legally sufficient in-place duck is considered at zero movement cost. Collision, occupancy, terrain, escape/duck legality, path cost and known hazard tier are authoritative environment data rather than inferred rules. Sources: ARENA-COMBAT-1.0 section 3; approved Phase 1 Task 8 ruling.

**Dependencies:** Attack delivery class, DT/DP allocation and modifiers, surprise/awareness, restraint, remaining MR, threat geometry, collision/path validation, saved priority and critical defense outcomes.

**Resolved automation boundary:** Phase 1 Task 8 supplies the deterministic selection rule. It does not alter Prime's half-MR or escape requirement. If the authority cannot provide complete environmental facts, selection remains pending rather than guessing a destination.

**Task 7 implementation:** The authority selects DT for hand-held delivery and DP for thrown delivery, then records one RB-aware d20 when Dodge is otherwise legal. A resolved authority-supplied destination must have verified path/escape facts, cost no more than half base MR rounded down, and fit within remaining round MR. A successful resolved Dodge spends that cost and moves once. A successful ambiguous Dodge remains `pending_dodge_displacement` with no movement or resource spending until a validated destination is supplied. The engine does not choose a direction.

**Task 8 implementation:** The authority accepts a complete, stable candidate set from the future collision/navigation boundary. It rejects blocked paths, collisions, illegal terrain, occupied destinations, failed escape/duck facts, invalid displacement and candidates over the half-MR or remaining-MR limits. It then selects the shortest authoritative path cost in the lowest known hazard tier, with candidate ID and coordinates as stable fallbacks. Incomplete environment information produces the existing synchronized pending state. No generic collision shape, hazard score, terrain rule or duck permission is fabricated by combat code.

**Task 9 refinement:** Each attack/effect now carries `allowed`, `prohibited` or `unresolved` duck eligibility. Prime p. 20 supports geometry-dependent examples, not universal permission. Only `allowed` admits a legal in-place duck. The other states continue evaluating independent displacement; unresolved-only ducking remains pending with an explicit reason. No production Special policy is assigned.

## Blocking and shields

**Status:** Prime check confirmed; Arena multi-block, Act cost, awareness and shield lifecycle rulings approved.

**Original Prime mechanic:** A listed weapon or shield has a BLK target number. Roll `1d20` at or below BLK. Block applies to physical things, not Specials. PRIME-V3 p. 31 permits Block in addition to the Dodge-or-Soak choice. Shield proficiency skills are item-size-specific. On a successful shield block, the shield's Hits Taken/SHP record takes one point regardless of the incoming damage. Sources: PRIME-V3 pp. 25, 27, 31, 107, 109 and shield chart p. 137.

**Approved Arena adaptation:** Block is one candidate in the saved automated defense priority and is attempted only if legal. If both are legal, one weapon Block and one shield Block may be attempted independently against the same attack when the first fails. They cost zero Acts unless a specific rule overrides. Surprised or unaware defenders cannot Block. SHP means Shield Hit Points. A shield above 0 SHP may be repaired by an appropriate blacksmith, ability or Special; at 0 it is destroyed, automatically unequipped, removed from inventory and irreparable. That destruction rule does not extend to non-shield equipment. Sources: ARENA-COMBAT-1.0 section 3; approved Phase 1 Task 2 ruling.

**Dependencies:** Equipped blocking item, proficiency, STR requirement, free-hand/equipment state, physical-versus-Special classification, shield current SHP and defense priority.

**Tasks 7-9 implementation:** Weapon and shield Block are separate profile candidates with separate equipment, proficiency, BLK and source fields. Either order is supported. Each legal candidate rolls once at or below BLK and costs zero Acts. Task 9 applies Prime's one-SHP loss on a successful shield Block. At 0 SHP the shield becomes unusable and its equipped reference is removed. The project has no separate inventory or repair subsystem yet.

**Open verification:** Item-specific exceptions still govern. Prime does not establish a generic durability loss for a blocking weapon, so none may be invented.

## Physical Soak

**Status:** Eligibility and success effect confirmed; Arena fallback contract approved.

**Original Prime mechanic:** Physical Soak is the END-derived PS target number. Roll `1d20` at or below PS once per eligible physical attack; success means no damage. Physical Soak cannot be combined with Dodge, cannot be used when surprised or back-attacked, and cannot be used against magic/Specials, Dwarvestek/Grentek or piercing damage. Source: PRIME-V3 p. 19. PRIME-V3 p. 31 places the Dodge-or-Soak choice before Block.

**Approved Arena adaptation and correction:** Automated priority governs selection. Dodge and Physical Soak remain mutually exclusive, while other legal fallback defenses remain available. Active Physical Soak is unavailable while surprised or unaware and costs zero Acts unless a specific rule overrides. ARENA-COMBAT-1.0 section 3 explicitly corrects a mistaken combat reference from `OR ATTEMPTS SR` to `OR ATTEMPTS PHYSICAL SOAK`; SR means Special Resistance, never Saving Roll. Special-specific overrides remain authoritative.

**Dependencies:** END-derived PS lookup, attack damage/delivery type, surprise/back-attack state, Dodge exclusivity, defense priority and critical defense handling.

**Resolution:** PRIME-V3 p. 32 contains the known incorrect `NAL ... or attempt SR` step. Arena uses the saved legal-defense priority (default Dodge, Block, Physical Soak), preserves Dodge/Soak exclusivity, and permits independent legal Block fallback attempts. This deterministic Arena ruling supersedes Prime's tabletop presentation order without changing eligibility or outcomes.

**Task 7 implementation:** The authority uses the actor's explicit Physical Soak target and one RB-aware d20 only when the attack carries resolved source eligibility and is not piercing, back-attacking, surprise/unaware, or mutually excluded by Dodge. Missing eligibility or target data fails that candidate closed. Success stops the physical defense chain without applying damage.

## NAL and TAL

**Status:** Reduction concept confirmed; Arena coverage and combined-type policy approved; printed naming discrepancy retained.

**Original Prime mechanic:** NAL is the END-derived amount subtracted from every accurate physical hit. Even when reduction reaches zero, the hit deals at least one damage. It does not protect against magic/Specials or Dwarvestek/Grentek. Armor contributes location-specific armor to NAL only when its protection types cover the incoming damage. PRIME-V3 p. 25 calls this `LTAL`; the armor chart on p. 135 labels the same location value `TAL`.

**Approved Arena adaptation:** Resolve armor by struck location and damage type; never sum all equipped armor or double-count an NAL bonus. Helmets cover head and neck; leg armor covers legs and feet. For combined physical damage types, use the lowest applicable protection and do not stack protections. Sources: ARENA-COMBAT-1.0 section 4; approved Phase 1 Task 2 ruling.

**Dependencies:** END-derived NAL, hit location, equipped armor slot, armor TAL, protected damage types, immunities/weaknesses and physical damage classification.

**Open verification:** Prime uses both `LTAL` on p. 25 and `TAL` on p. 135 for location armor. Arena documentation and code use canonical field name `TAL`; source-import records should preserve the printed label for traceability. Prime-specific exceptions to the minimum-one rule still require source-by-source audit.

**Task 9 implementation:** Armor is explicit source data by item, slot, covered location and B/S/P TAL. Missing protection values fail closed. Helmet head/neck and leg-armor leg/feet coverage are supported, combined types select the lowest applicable TAL, and NAL is subtracted separately before the one-time HPC mutation.

## Weapon damage SB and damage types

**Status:** Generic components and Arena calculation order confirmed; fractional multiplier rounding remains unresolved.

**Original Prime mechanic:** Roll the printed weapon damage. Add SB to melee and thrown-projectile physical hits, including the unarmed `1d4 B` base; do not add SB to shot weapons. Printed physical types include Bashing (`B`), Slashing (`S`) and Piercing (`P`); `M` denotes a special-effect weapon category. The weapon chart is authoritative for dice, range, handedness, Block and exceptions. Sources: PRIME-V3 pp. 19, 25 and 124-138.

**Approved Arena adaptation:** Preserve every printed die, damage type, SB eligibility and exception as data. The calculation order is: printed weapon damage plus eligible SB; approved critical/location multipliers; applicable armor TAL; NAL; then HPC. Combined types select the lowest applicable protection without stacking. A successfully damaging physical hit deals at least 1 HPC unless a verified Prime-specific exception applies. Sources: ARENA-COMBAT-1.0 section 4; approved Phase 1 Task 2 ruling.

**Dependencies:** Weapon definition, attack mode, melee/thrown/shot classification, SB, critical result, hit-location multiplier, defense outcome, NAL/TAL, immunities/weaknesses and HPC.

**Open verification:** Fractional results from the `x1.5` location multiplier still need an explicit rounding ruling, as do any future critical effects that create fractions. Expanded weapon critical-range text needs item-specific effect verification.

**Task 9 implementation:** Seeded weapon dice, explicit SB eligibility, B/S/P types, exact-type immunity/weakness stages, the approved order, minimum-one policy and deterministic HPC records are implemented. Fractional rounding, multiplier stacking and unauthored critical damage fail before damage RNG or HPC mutation. All current test items are labeled fixtures, not production transcriptions.

## Armor coverage and hit locations

**Status:** Location list, size modifiers and Arena head/neck and leg/feet mappings confirmed.

**Original Prime mechanic:** Locations are: 1 Head (`x1.5` damage), 2 Neck (`x1.5`), 3 Torso, 4 Shoulders/Upper Arms, 5 Elbows, 6 Hands, 7 Groin/Upper Legs, 8 Knees/Lower Legs and 9 Feet. Pages 95-97 provide ACC penalties by attacker/target size and location. Armor on p. 135 is grouped as Torso, Head, Arms, Legs, and Elbows/Knees/Hands, with material-specific B/S/P protection and MR/DT/DP penalties.

**Approved Arena adaptation:** Ordinary attacks automatically use torso. Optional aimed attacks select a location and apply Prime's size/location ACC modifier and location armor. Helmets cover head and neck; leg armor covers legs and feet. Sources: ARENA-COMBAT-1.0 section 3; approved Phase 1 Task 2 ruling.

**Dependencies:** Size category, aim selection, ACC modifier, location multiplier, armor-slot mapping, protection type and armor penalties.

**Resolution:** The Task 2 Arena ruling supplies the previously missing neck and feet mappings. Other printed slot/location relationships remain subject to the p. 135 chart and must be transcribed rather than generalized.

## Critical successes and failures

**Status:** Natural trigger and rarity weights confirmed; automated outcome entries unresolved.

**Original Prime mechanic:** On applicable d20 skill, attribute and derived-attribute checks, natural 1 is critical success and natural 20 is critical failure. The Storyteller doubles a relevant effect or applies another situational consequence. Criticals continue through normal resolution and do not inherently bypass defenses. Specific weapons/Specials may change the critical range or result. Sources: PRIME-V3 pp. 16, 92-94 and 350; weapon exceptions pp. 124-138.

**Approved Arena adaptation:** Only an unmodified natural 1 is critical success and an unmodified natural 20 is critical failure unless an explicit rule overrides the trigger. Roll Bonus does not alter this trigger. Consequences may chain through normal resolution and do not cancel merely because success and failure both occur. Context-specific automated tables will use 70% Common, 25% Uncommon and 5% Rare outcomes that are dramatic but reasonable. Sources: ARENA-COMBAT-1.0 section 6; approved Phase 1 Task 2 ruling.

**Dependencies:** Roll kind, natural die value, item/Special overrides, normal defense pipeline, deterministic outcome table and effect legality.

**Unresolved:** Exact physical-attack, defense and skill outcome entries are not authored and must not be invented. Expanded weapon critical ranges need explicit trigger/effect treatment. These block a complete automated critical implementation; approved weights alone are not tables.

## Knockback Balance and prone

**Status:** Source-specific knockback and Arena consequences confirmed; generic Balance target unresolved.

**Original Prime mechanic:** Balance is a DEX skill described as keeping balance when knocked down/back (p. 107). Individual Specials and abilities specify knockback distances. `Inner Strength` states that each untraveled foot of collision knockback deals 2 damage to the target and struck object/person (p. 254). Prone impairs movement/positioning, with penalties and standing cost determined by the Storyteller (p. 36). Martial Arts lists possible knockback/trips but explicitly leaves detail for later (p. 112).

**Approved Arena adaptation:** Physical and magical knockback call for a Balance check unless the governing effect overrides it. Success retains footing while displacement still occurs. Failure causes prone plus a 0.5-second stagger; standing costs one Act. Paralysis and unconsciousness are condition states, not Balance challenges. No collision damage is added unless Prime or the source effect supplies it. Sources: ARENA-COMBAT-1.0 section 5; approved Phase 1 Task 2 ruling.

**Dependencies:** Knockback source and distance, prevention, collision path, Balance target/modifier, ground state, prone transition and action/movement locks.

**Unresolved:** Prime does not provide a universal Balance target/modifier for knockback or universal prone penalties. Do not invent either. Collision damage from p. 254 remains specific to Inner Strength unless explicitly generalized.

## Five-second combat rounds

**Status:** Confirmed with an explicit Arena timing adaptation.

**Original Prime mechanic:** All participants act within the same approximately five seconds; a round is approximately five seconds. Each participant gets a turn containing Acts, and initiative provides table order. Sources: PRIME-V3 pp. 20-22 and 31-32.

**Approved Arena adaptation:** The simulation uses exact five-second boundaries for deterministic round-scoped rules while actions progress continuously in real time. Sources: ARENA-COMBAT-1.0 section 2; Rules Ledger `TIME-001`.

**Dependencies:** Integer simulation clock, exact boundary convention, continuous action intervals, per-round MR and later NAC budgets.

**Open verification:** Mechanics that begin exactly on a boundary need one consistent half-open interval rule. The recommended engineering convention is `[round_start, round_end)`, but this convention is not itself a gameplay formula and should be documented when implemented.

## Resource costs and defensive eligibility

**Status:** Core physical costs and Arena reactive defense costs confirmed for the audited boundary.

**Original Prime mechanic:** Physical attacks, equip/draw, reload and similar actions consume printed Acts. MR is a separate per-turn budget and Dodge spends it. Ammunition, clip, rate and reload values are weapon data. Failed Special checks consume resources as specified by the source; generic missing Mana cost is `Special level x 2`, but Specials are outside this Phase 1 task. Sources: PRIME-V3 pp. 20, 24-25, 31-32, 92 and 124-138.

**Approved Arena adaptation:** A begun Special commits its full resource cost, and an interrupted multi-Act action retains only intervals already completed. Dodge, weapon Block, shield Block, Physical Soak and NACs consume zero ordinary Acts unless a specific rule overrides; Dodge still spends its Prime MR distance. Surprised/unaware actors cannot actively Dodge, Block, Physical Soak, use Special Resistance or start awareness-dependent reactive NACs; passive protection remains. The event model must record commitments even though this task does not implement these mechanics. Sources: ARENA-COMBAT-1.3 section 15; approved Phase 1 Task 2 defense ruling.

**Dependencies:** Action definition, actor Act/MR/ammunition state, event start/effect/finalize phases, defense eligibility and item state.

**Open verification:** Item-, condition- and Special-specific overrides still require their own source audits. The generic zero-Act ruling must never erase an explicit override.

## Rule conflicts that must stay visible

1. **Defense sequence:** Prime presents Dodge-or-Soak before Block; Arena deliberately uses saved priority (default Dodge, Block, Soak), preserves Dodge/Soak exclusivity and allows both legal weapon/shield Blocks after failures.
2. **Initiative ties:** Prime permits Storyteller discretion or simultaneous action; Arena replaces discretionary ordering with higher base INIT and a deterministic fallback while preserving simultaneous legal effects.
3. **Critical effects:** Prime expects contextual Storyteller outcomes; Arena supplies fixed rarity weights but still requires authored action-specific table entries.
4. **Armor terminology:** `LTAL` on p. 25 and `TAL` on p. 135 describe location armor; Arena uses `TAL` canonically while imports retain the printed source label.
5. **Knockback:** Prime mostly defines knockback per source; Arena supplies general footing/prone/stagger/standing consequences but no Balance target/modifier.
6. **Running:** Prime's historical stacking bonus, ten-space buildup, five-minute interval and minute-based duration are replaced by the approved single SPD-derived bonus, immediate activation, five-second maintenance, second-based cap and proportional recovery. The verified Prime Skill calculation, automatic threshold, natural criticals, RB rule and 45-degree restriction remain.

## Safe implementation boundary

The following are safe to build once source tables are transcribed: deterministic d20 checks; lookup-derived ACC/AT/INIT/MR/NAL/PS; five-second round accounting; opening initiative; canonical MR movement; torso attacks; declared aimed locations and ACC modifiers; DT/DP eligibility; approved defense fallback reporting; raw weapon dice and SB eligibility; approved location/combined-type armor selection; authoritative event recording.

The Running system is safe within the recorded Task 3 scope and no longer has a pending formula boundary. Tasks 7-8 implement the generic physical defense roll/fallback and automatic Dodge-selection boundaries with labeled fixtures. The following physical-combat items remain gated: fractional multiplier rounding; authored critical outcomes and expanded-range effects; complete production environment/collision/hazard data; generic knockback Balance target/modifier; production actor/equipment rows; and unaudited Special/item exceptions.
