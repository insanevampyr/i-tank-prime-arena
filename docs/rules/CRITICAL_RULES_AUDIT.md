# Critical Rules Audit

## Status and authority

This audit began as the documentation-only Phase 1 Task #10 deliverable. Phase 1 Task #11 updates it with the controlling v1.6 rulings and implementation status. No individual critical consequence is approved or implemented.

The controlling sources are:

1. **Prime V3** dated 01 March 2026 for original tabletop rules and item-specific exceptions.
2. **Arena Combat Specification, internal section 16 / v1.6 addendum dated 14 October 2026** for critical ranges, reactions, backfires, Critical Stagger, Dwarvestek/Grentek handling, the Prime `x1.5` head/neck value, exact multiplier composition, and one-time floor. It supersedes conflicting provisional consequence proposals and the earlier illustrative `x2 head` example.
3. **Rules Ledger** for previously approved deterministic automation boundaries.

The current Roadmap's internal v1.5 milestone predates Tasks #6-#10 and does not add critical mechanics. It remains scope guidance, not a source for consequence entries.

Status terms used below:

- **Confirmed**: the cited source states the rule sufficiently for the audited boundary.
- **Approved Arena adaptation**: a designer-approved rule for Arena, distinct from Prime's tabletop text.
- **Ambiguous**: source text exists but is insufficiently precise for deterministic implementation.
- **Unresolved**: no authoritative rule was found for the required decision.

## Source-verification matrix

| Topic | Original Prime rule | Exact source | Arena ruling / dependency | Status |
| --- | --- | --- | --- | --- |
| Natural critical triggers | On an applicable d20 skill, attribute, or derived-attribute check, natural `1` is critical success and natural `20` is critical failure. The Storyteller doubles a relevant positive/negative effect or supplies a related situational consequence. | Prime V3 pp. 16, 67, 92-94, 350 | The unmodified die controls the trigger. Normal attack/defense resolution still occurs; a critical does not itself bypass legal defenses. | **Confirmed** |
| Roll Bonus | RB adjusts a roll by `+1` or `-1`, whichever benefits the character, but cannot turn another result into a critical or remove a natural critical. | Prime V3 p. 23 | Store natural and adjusted values independently. | **Confirmed** |
| Critical consequence semantics | The consequence may double a relevant effect or be an additional situation-specific consequence. Prime examples include self-damage, a Dodge into the attack, a lodged weapon, and becoming exposed; those examples are not universal tables or fully specified mechanics. | Prime V3 pp. 16, 92-94 | Arena requires authored, action-specific deterministic tables. No example becomes a production rule merely because it appears in explanatory text. | **Confirmed principle; individual outcomes unresolved until approved** |
| Normal-resolution boundary | A critical attack proceeds through normal resolution, with damage and consequences handled by combat rules. | Prime V3 pp. 93, 350 | ACC success still permits every independently legal defense. A later critical success does not erase an earlier critical failure, and a later defense may stop the immediate threat without cancelling already-created consequences. | **Confirmed; Arena chain rule approved** |
| Printed expanded ACC range | Stiletto Dagger, Great Sword, Battle Axe, and Plated Arrow say an ACC result of `2 or lower` is a critical strike. | Prime V3 pp. 124, 126-127, 130 | These are item-specific trigger overrides. Their exact consequence still depends on the governing critical outcome rule/table. | **Trigger confirmed; automated consequence unresolved** |
| Magical-item critical-range modifier | The magic-item chart offers `+1 Critical Range to weapon/item`, maximum one per MIUR. | Prime V3 p. 85 | v1.6 rules that `+1 Critical Range` expands only the success range toward 20, including a printed expanded range, and never expands failure. | **Prime item modifier confirmed; Arena combination rule approved** |
| Dwarvestek / Grentek ranges | These weapons report critical success with `x2 damage` on ACC `3 or lower` and critical failure with `x2 damage` on ACC `18 or higher`. | Prime V3 p. 138 | v1.6 preserves natural `18-20` as the failure trigger, rejects guaranteed self-damage, and requires weapon-specific weighted failure tables. A rolled self-damage result targets the attacker and preserves legal reactions. Physical Soak remains prohibited. | **Trigger and target boundary confirmed; individual tables/effects unresolved** |
| Separate weapon special rolls | Club/Blackjack uses a post-hit d10 where natural `1` can cause unconsciousness; Spiked Club uses natural `1 or 2` on that d10. | Prime V3 pp. 125, 129 | These are printed weapon effects on a non-d20 roll, not expansions of the ACC critical range and not entries in the generic critical table. | **Confirmed distinction** |
| Critical damage multiplier | Prime's general rule permits doubling the relevant effect but does not state that every attack critical always doubles damage. | Prime V3 pp. 16, 92-93 | Combat Specification v1.5 uses an `x2 critical` as a legitimate worked multiplier. That example validates multiplication/rounding when an `x2` critical consequence applies; it does not by itself make every critical a damage multiplier. | **Calculation confirmed; universal eligibility not confirmed** |
| Hit-location multiplier | Head and neck are printed as `x1.5 damage`; all other listed locations have no printed generic damage multiplier. | Prime V3 pp. 95-98, specifically the hit-location chart on p. 98 | Existing Arena armor coverage maps helmet to head/neck and leg armor to legs/feet. | **Prime multiplier confirmed** |
| Head/neck correction | Prime prints head/neck at `x1.5`. | Prime V3 p. 98 | Combat Specification v1.6 states the earlier `x2 head` example was illustrative and not an override. | **Confirmed; conflict resolved in favor of `x1.5`** |
| Multiplier composition and rounding | Prime does not provide a complete general stacking/rounding algorithm for multiple fractional factors. | Prime V3 pp. 92-98 and source-specific effects | Combat Specification v1.5 section 17 locks: add weapon damage and eligible SB; multiply all legitimate critical/location/weakness/source factors together; floor once after the complete product; then TAL, NAL, and HPC. No intermediate rounding. | **Approved Arena adaptation, confirmed** |
| Physical Soak | Roll d20 at or below PS once per eligible physical attack. Success causes no damage. It cannot combine with Dodge and cannot apply to surprise/back attacks, piercing, magic/Specials, or Dwarvestek/Grentek. | Prime V3 p. 19; combat order p. 31 | A successful legal Soak ends ordinary physical damage before weapon damage is rolled. Any source-specific override must be represented explicitly. | **Confirmed for the stated cases** |
| Minimum-one physical damage | After an accurate physical hit, subtract NAL; if total damage reaches zero, the target still takes one point. | Prime V3 p. 19 | Arena applies the floor to an otherwise successfully damaging ordinary physical hit after TAL and NAL. It does not override a successful Soak or a verified immunity, because those rules say no damage is taken. | **Confirmed general rule; exception catalog incomplete** |
| Armor protection | Location armor contributes only when its printed protection includes the incoming Bashing, Slashing, or Piercing type. | Prime V3 p. 25 and armor chart p. 135 | Arena uses the lowest applicable TAL for combined physical types, then subtracts NAL. | **Confirmed / approved Arena combination rule** |
| Physical immunity | Physical Weapon Immunity prevents effects from ordinary physical weapons and fists, while making all Specials, healing, and regeneration deal `x1.5`; it is mutually exclusive with Specials Immunity. Shadow Form also states immunity to physical effects. | Prime V3 pp. 149-150, 273 | A verified immunity results in zero physical damage and therefore precedes/minimizes the ordinary minimum-one rule. Each immunity must be source data, not inferred from a creature/theme name. | **Confirmed examples; full catalog unresolved** |
| Physical weakness | Specials Immunity makes physical damage `x1.5` and prohibits Physical Soak. Other sources define type-specific weaknesses, such as Shadow Form's `x2` FIRE weakness. | Prime V3 pp. 150, 273-274 | Under v1.5, a legitimate weakness multiplier participates in the combined pre-protection product unless its own source expressly sets a different stage. | **Confirmed examples; source-by-source catalog required** |
| Source-specific critical failure | Magical Inaptitude adds `x2` damage on top of regular damage whenever SS or SR critically fails. | Prime V3 p. 60 | This is a specific drawback rule for SS/SR, not a generic physical attack/defense outcome. | **Confirmed exception; outside current physical table scope** |

## Approved damage calculation

For a damage-bearing physical consequence whose factors are all legally applicable:

```text
subtotal = rolled weapon damage + eligible SB
multiplied = floor(subtotal * product(all legitimate multipliers))
after_armor = multiplied - applicable TAL
after_nal = after_armor - NAL
final HPC damage = source-legal immunity/minimum-one result
```

Rules attached to that expression:

1. Multiply the exact rational factors together before division or rounding.
2. Round down exactly once, after the complete multiplier product and before TAL.
3. Do not infer a critical, location, weakness, or other factor merely to make the pipeline produce a value.
4. Apply a verified immunity or successful Physical Soak as its source directs; the ordinary minimum-one rule cannot turn “no damage” into one damage.
5. Apply the ordinary minimum-one rule only after TAL and NAL and only when no verified exception overrides it.

The former v1.5 `10 x 2 x 2 = 40` example verifies multiplication but its `x2 head` label was illustrative. The controlling v1.6 ruling preserves Prime's printed `x1.5` head/neck factor. A legitimate `x2` critical consequence combined with that location therefore gives `10 x 2 x 1.5 = 30` before protection.

## Physical Soak and minimum-one exception findings

- A successful, eligible Physical Soak states that the target takes no damage (Prime V3 p. 19). It is not “damage reduced to zero,” so the ordinary minimum-one rule does not reintroduce damage.
- Physical Soak is not legal against piercing, surprise/back attacks, magic/Specials, or Dwarvestek/Grentek (p. 19).
- Specials Immunity expressly prohibits Physical Soak and makes physical damage `x1.5` (p. 150).
- A verified physical immunity states that the physical effect does not apply; it is therefore a minimum-one exception (pp. 149, 273).
- No exhaustive Prime-wide exception registry was found. Every production item, creature, condition, and Special still needs source-specific import review.

## Existing implementation compatibility

### Compatible foundations

- `CombatAttackInstance` and `CombatDefenseAttempt` retain the natural d20 separately from the RB-adjusted result and serialize critical-success/failure flags.
- Attack and defense resolution checks natural `1` and natural `20` before evaluating the adjusted target, so RB cannot manufacture or suppress the current generic triggers.
- Seeded RNG draw counts, stable event IDs, parent/dependency fields, authoritative snapshots, SHA-256 state digests, duplicate request rejection, and timestamp/INIT/stable ordering are suitable foundations for replayable critical chains.
- Damage records already retain rolled dice, applied multiplier metadata, TAL, NAL, HPC before/after, and the causal event identity.

### Task #11 implementation status

1. **Single-floor calculation corrected:** `resolve_physical_damage()` now composes legitimate pre-protection factors as an exact reduced rational product, multiplies once, floors once, then subtracts TAL and NAL. It records the combined numerator/denominator and multiplied total.
2. **Controlling rounding normalized:** physical damage definitions retain compatible constructor fields but normalize legitimate multiplier composition to the v1.6 floor-once rule. Eligibility remains source-driven and unresolved critical effects still fail closed.
3. **Weakness stage preserved:** pre-protection weaknesses join the exact product. An explicitly source-declared post-protection response remains a source-specific exception rather than being silently moved.
4. **Data-driven ranges implemented:** each attack carries a trigger policy with success maximum, success-only `+1` bonus, failure minimum, table reference, and exact source references. Generic defenses use natural `1`/`20`; item-specific production policies still require source-data import.
5. **Trigger records implemented, consequences inert:** every qualifying attack/defense roll creates one deduplicated authority-owned record with natural d20, effective range, source, seeded d100, 70/25/5 rarity, causal IDs, resource evidence, and blank outcome. Records participate in snapshots/digests. No table outcome executes.
6. **Effect/table schemas are inert:** definitions can describe immediate zero-Act non-NAC reactions, legal backfire defenses, 0.5-second Critical Stagger, weapon prerequisites, and table approval/activation gates. No effect dispatcher or consequence data is active.

## Required integration shape after approval

The smallest compatible extension is data-driven rather than branching by attack name:

- `CriticalTriggerPolicy`: roll kind, success range, failure range, explicit source, and exception precedence.
- `CriticalConsequenceTable`: stable table/version ID, category, rarity bands, outcome IDs, eligibility predicates, and approved effect descriptors.
- `CriticalResolution`: triggering roll/event, source policy, rarity roll and RNG draw index, selected outcome, preflight result, parent/dependency IDs, spawned event IDs, and final status.
- A transaction planner that validates every consequence and follow-up before mutating actor, equipment, movement, timing, or damage state.
- A chain dispatcher using the existing event queue. It must allow every legitimate subsequent d20 critical, with no gameplay chain cap, while still rejecting duplicate event IDs, repeated requests, and causal cycles.
- Snapshot and digest coverage for trigger policies, tables, critical resolutions, RNG positions, spawned events, and any resulting authoritative state mutation.

Follow-up attacks must use mandatory ACC, ordinary legal defenses, and the approved damage pipeline. A consequence is not a NAC unless an approved rule explicitly classifies it as one. Action-delay outcomes must move only the affected actor's next ordinary-action eligibility and must not create stored Acts or alter AT.

## Validation requirements for a later implementation task

- Natural `1`/`20` classification remains independent of RB and other adjusted values.
- Each approved expanded range is tested independently, including a legal success-only `+1` stacked on a printed range.
- Deterministic rarity boundaries: Common 70%, Uncommon 25%, Rare 5%.
- Every table row is tested for eligibility, ordinary effect preservation, spawned rolls, legal defenses, and dependencies.
- A later critical cannot algebraically cancel an earlier critical consequence.
- Legitimate chains have no arbitrary depth cap; exact duplicate/cycle rejection remains deterministic.
- A rounding discriminator proves floor-once behavior, for example `5 x 3/2 x 3/2 = floor(11.25) = 11`, not `10` from intermediate flooring.
- Head and neck `3/2` is tested directly, including its product with another legitimate fractional/critical/weakness factor.
- Immunity, successful Soak, weakness, TAL, NAL, and minimum-one ordering receive separate source-backed tests.
- Replay and both simulated clients produce identical critical records, RNG draw counts, snapshots, and state digests.

## Designer decisions required

### Genuine missing rules or approvals

1. Approve exact weapon-specific Dwarvestek/Grentek weighted failure tables and the legality/prerequisites of each result.
2. Confirm each source-specific weakness stage when its Prime source supplies a factor but no explicit protection-order stage.
3. Approve any individual critical consequence outcome before it is added as active production data.

### Safe to defer

- A complete production catalog of creature-, item-, condition-, and Special-specific immunities, weaknesses, minimum-one exceptions, and critical overrides can be imported incrementally. Unknown required data must continue to fail closed.
- Nonphysical critical tables, critical consequence visuals/audio, and narrative text can wait until their owning mechanics enter scope.
