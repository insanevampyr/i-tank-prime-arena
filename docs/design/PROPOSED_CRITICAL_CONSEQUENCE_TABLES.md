# Proposed Critical Consequence Tables

> **DESIGN PROPOSAL — NOT APPROVED — NOT IMPLEMENTED**
>
> Every outcome in this document is a candidate Arena mechanic for designer review. None is a current rule, none is production data, and none authorizes gameplay code. Prime examples are cited as inspiration only where their exact automation is not defined.

> **SUPERSEDED FOR OUTCOME SELECTION:** The designer-locked `ITank_Prime_Arena_Approved_Critical_Tables.md` and Combat Specification v1.7 section 18 now control production critical outcomes. This file remains historical and must not be used to select or implement a consequence.

## v1.6 supersession notice

Combat Specification v1.6 section 16 supersedes conflicting proposals in this Task #10 draft:

- `DELAY_NEXT_ACTION_ONE_INTERVAL` and `ZERO_REMAINING_MR` are rejected as generic critical penalties.
- `REFUND_DODGE_MR` and `RESTORE_HALF_BASE_MR` are rejected as generic critical rewards.
- `BACKFIRE_SELF_HIT` is rejected as unavoidable self-damage; a weapon-specific backfire may threaten the attacker only when an approved table selects it, and every legal reaction remains available.
- Approved future immediate follow-ups/counterattacks are zero ordinary Acts, separate from NACs, and still require ordinary legality, ACC, defenses, damage, and later critical handling.
- The approved architectural candidate for interruption is a distinct 0.5-second Critical Stagger, with the exact boundaries in v1.6. It is not an approved outcome in any row below.

Any row below that relies on a rejected contract is **RETIRED BY v1.6**, not awaiting approval in its current form. All other rows remain **NOT APPROVED** and **NOT IMPLEMENTED**. Task #11 adds only inert schemas and trigger/rarity records; it activates no row from this document.

## Design constraints

- A qualifying natural or explicitly expanded-range d20 result first resolves its ordinary success/failure meaning.
- The consequence supplements that result. It does not silently replace normal ACC, defense, damage, equipment, movement, or timing rules.
- Roll Bonus never changes whether the natural die triggered a critical.
- A critical failure is not cancelled by a later critical success. Each legal trigger creates its own causal resolution.
- Legitimate subsequent d20 rolls may themselves trigger criticals. There is no gameplay chain-depth cap.
- Duplicate request/event rejection and causal-cycle rejection remain technical validity rules, not limits on legitimate chains.
- Proposed outcomes use only existing concepts: authoritative HPC, MR, action eligibility time, equipped attacks, the normal defense pipeline, and deterministic events. They introduce no new currency, status-condition catalog, weapon-breakage rule, or shield-damage formula.
- A successful Shield Block still spends exactly one SHP. A failed Shield Block spends no SHP unless a future source expressly says otherwise.
- A successful Physical Soak still causes zero ordinary damage. A later counterattack is a separate event, not damage leaking through Soak.

## Proposed deterministic rarity selection

The approved distribution is Common 70%, Uncommon 25%, and Rare 5%. The following encoding is itself part of this proposal:

| Authoritative d100 | Rarity | Weight |
| --- | --- | --- |
| 1-70 | Common | 70% |
| 71-95 | Uncommon | 25% |
| 96-100 | Rare | 5% |

The authority makes one seeded d100 draw after a critical trigger is accepted and records the natural d20 trigger, trigger source/range, d100 result, RNG draw index, table/version ID, and outcome ID. Clients never choose or reroll a consequence.

If an approved future table contains an outcome whose prerequisite is not met, that outcome must define an explicit fallback. The tables below avoid prerequisite-only entries so rarity weights are not silently distorted.

## Shared proposed effect contracts

These contracts make the table rows precise and avoid repeating mechanics.

### `DELAY_NEXT_ACTION_ONE_INTERVAL`

The affected actor's next ordinary action that has not started may not start until one additional interval of that actor's current `5 seconds / AT` has elapsed. An already-running action is not interrupted or stretched. The delay does not create or spend an Act, change AT, affect movement, or count as a NAC. The delay event uses the critical result as its parent.

### `ZERO_REMAINING_MR`

Set the affected actor's remaining MR for the current five-second round to zero. Position does not change. No MR debt carries into a later round.

### `REFUND_DODGE_MR`

After a successful legal Dodge displacement finalizes, restore exactly the MR spent by that displacement, capped at the actor's MR available at the start of the current round. Position is not changed a second time.

### `RESTORE_HALF_BASE_MR`

Restore `min(MR already spent this round, floor(base MR / 2))` to current-round remaining MR. This does not increase MR above its round-start amount and does not alter position.

### `IMMEDIATE_COUNTERATTACK`

After the triggering defense and the parent attack fully finalize, the defender declares one immediate physical attack with an already-equipped, currently legal weapon against the original attacker at the same target location used by that weapon's ordinary default. The attack consumes no ordinary Act and is a proposed critical reaction, not a NAC. It must pass all current declaration legality checks, rolls mandatory ACC, permits every legal defense, uses normal damage rules, and can create subsequent criticals. If no legal equipped attack exists at dispatch, record `counterattack_ineligible` and make no substitute attack.

### `IMMEDIATE_FOLLOW_UP`

After the original attack fully finalizes, the attacker repeats one physical attack using the same weapon/mode, target, and declared location. It consumes no ordinary Act and is a proposed critical reaction, not a NAC. Range, line of sight, actor state, equipment, and target legality are revalidated at dispatch. It rolls mandatory ACC, permits every legal defense, uses normal damage rules, and can create subsequent criticals. If no longer legal, record `follow_up_ineligible` and do not retarget.

### `X2_CONSEQUENCE_MULTIPLIER`

Add an exact `2/1` consequence multiplier to the affected physical damage packet. It participates in the approved product of all legitimate multipliers, followed by one floor before TAL and NAL. It does not bypass immunity, successful Soak, armor, NAL, or the normal minimum-one/exception policy.

### `BACKFIRE_SELF_HIT`

The failed attack misses its intended target. As a dependent event, roll the attack's verified weapon damage against the attacker at torso, include SB only if that same attack mode was SB-eligible, and add one `2/1` critical-failure consequence multiplier. No ACC roll is made for this self-hit, so it cannot itself generate an ACC critical. Active defenses are not offered against the actor's own backfire; passive torso TAL, NAL, verified immunity/weakness, and minimum-one exceptions still apply. This contract is inspired by Prime V3 p. 16's “double damage to self” example but remains an unapproved Arena specification.

## Physical attack — critical success

All three outcomes begin with an ACC critical success and continue through ordinary legal defenses. A successful defense can stop the original damage but cannot erase a separately scheduled follow-up.

| Rarity | Outcome ID and name | Exact proposed consequence | Additional roll / chain behavior |
| --- | --- | --- | --- |
| Common | `ATTACK_CS_C_POTENT_STRIKE` — Potent Strike | Add `X2_CONSEQUENCE_MULTIPLIER` to the original attack if it ultimately reaches damage. | No new roll. The original defense chain remains legal. |
| Uncommon | `ATTACK_CS_U_RELENTLESS_FOLLOW_UP` — Relentless Follow-through | Resolve the original attack normally, then dispatch `IMMEDIATE_FOLLOW_UP`. | Follow-up rolls ACC against the original target; all legal defenses apply; any d20 critical creates a new resolution. |
| Rare | `ATTACK_CS_R_PERFECT_SEQUENCE` — Perfect Sequence | Add `X2_CONSEQUENCE_MULTIPLIER` to the original attack and, after it finalizes, dispatch `IMMEDIATE_FOLLOW_UP`. | The follow-up uses ordinary ACC/defenses and may create further criticals. |

## Physical attack — critical failure

The intended attack misses. A consequence is still resolved and is never cancelled merely because a later roll critically succeeds.

| Rarity | Outcome ID and name | Exact proposed consequence | Additional roll / chain behavior |
| --- | --- | --- | --- |
| Common | `ATTACK_CF_C_RECOVERY_DELAY` — Recovery Delay | Apply `DELAY_NEXT_ACTION_ONE_INTERVAL` to the attacker. | No new roll. |
| Uncommon | `ATTACK_CF_U_OVEREXTENDED` — Overextended | Apply `ZERO_REMAINING_MR` and `DELAY_NEXT_ACTION_ONE_INTERVAL` to the attacker. | No new roll. |
| Rare | `ATTACK_CF_R_BACKFIRE` — Backfire | Resolve `BACKFIRE_SELF_HIT`. | Rolls only the verified weapon damage dice. No ACC/defense d20 occurs; therefore no new d20 critical is created by the self-hit. |

## Dodge — critical success

The Dodge succeeds under its ordinary legality and destination-selection rules before the consequence applies.

| Rarity | Outcome ID and name | Exact proposed consequence | Additional roll / chain behavior |
| --- | --- | --- | --- |
| Common | `DODGE_CS_C_EFFORTLESS_EVASION` — Effortless Evasion | Apply `REFUND_DODGE_MR` after the selected displacement finalizes. | No new roll. |
| Uncommon | `DODGE_CS_U_STOLEN_TEMPO` — Stolen Tempo | Complete the Dodge and apply `DELAY_NEXT_ACTION_ONE_INTERVAL` to the original attacker. | No new roll. |
| Rare | `DODGE_CS_R_TURNABOUT` — Turnabout | Complete the Dodge, apply `REFUND_DODGE_MR`, then dispatch `IMMEDIATE_COUNTERATTACK`. | Counterattack rolls ACC; all legal defenses apply; subsequent criticals remain live. |

## Dodge — critical failure

The Dodge fails, no displacement occurs, and the remaining configured defense chain continues where otherwise legal.

| Rarity | Outcome ID and name | Exact proposed consequence | Additional roll / chain behavior |
| --- | --- | --- | --- |
| Common | `DODGE_CF_C_HESITATION` — Hesitation | Apply `DELAY_NEXT_ACTION_ONE_INTERVAL` to the defender. | No new roll. |
| Uncommon | `DODGE_CF_U_WRONG_FOOTED` — Wrong-footed | Apply `ZERO_REMAINING_MR` and `DELAY_NEXT_ACTION_ONE_INTERVAL` to the defender. | No new roll. Legal Block fallback remains available. |
| Rare | `DODGE_CF_R_INTO_THE_BLOW` — Into the Blow | Add `X2_CONSEQUENCE_MULTIPLIER` to the incoming attack if it ultimately reaches damage. | No new roll. Inspired by Prime V3 p. 16. Other legal defenses still occur and may themselves critically resolve. |

## Weapon Block — critical success

The Weapon Block succeeds and stops ordinary damage from the parent attack. No weapon durability change is proposed.

| Rarity | Outcome ID and name | Exact proposed consequence | Additional roll / chain behavior |
| --- | --- | --- | --- |
| Common | `WEAPON_BLOCK_CS_C_BOUND_MOMENTUM` — Bound Momentum | Apply `DELAY_NEXT_ACTION_ONE_INTERVAL` to the original attacker. | No new roll. |
| Uncommon | `WEAPON_BLOCK_CS_U_RIPOSTE` — Riposte | Dispatch `IMMEDIATE_COUNTERATTACK` after the blocked attack finalizes. | Counterattack rolls ACC and permits all legal defenses. |
| Rare | `WEAPON_BLOCK_CS_R_DOMINANT_PARRY` — Dominant Parry | Apply `ZERO_REMAINING_MR` and `DELAY_NEXT_ACTION_ONE_INTERVAL` to the attacker, then dispatch `IMMEDIATE_COUNTERATTACK`. | Counterattack may create additional criticals; none cancels the parent result. |

## Weapon Block — critical failure

The Weapon Block fails. The remaining configured legal defense chain continues; no weapon damage, breakage, drop, or unequip effect is inferred.

| Rarity | Outcome ID and name | Exact proposed consequence | Additional roll / chain behavior |
| --- | --- | --- | --- |
| Common | `WEAPON_BLOCK_CF_C_SLOW_RECOVERY` — Slow Recovery | Apply `DELAY_NEXT_ACTION_ONE_INTERVAL` to the defender. | No new roll. |
| Uncommon | `WEAPON_BLOCK_CF_U_LOST_GROUND` — Lost Ground | Apply `ZERO_REMAINING_MR` and `DELAY_NEXT_ACTION_ONE_INTERVAL` to the defender. | No new roll. Legal shield Block or other fallback remains available. |
| Rare | `WEAPON_BLOCK_CF_R_OPEN_GUARD` — Open Guard | Add `X2_CONSEQUENCE_MULTIPLIER` to the incoming attack if it ultimately reaches damage. | No new roll. Later legal defenses can still prevent damage but do not erase this consequence. |

## Shield Block — critical success

The Shield Block succeeds, ordinary parent damage is stopped, and the shield still loses exactly one SHP under the existing verified rule.

| Rarity | Outcome ID and name | Exact proposed consequence | Additional roll / chain behavior |
| --- | --- | --- | --- |
| Common | `SHIELD_BLOCK_CS_C_ABSORBED_MOMENTUM` — Absorbed Momentum | Apply `ZERO_REMAINING_MR` to the original attacker. The shield loses its normal one SHP. | No new roll. |
| Uncommon | `SHIELD_BLOCK_CS_U_HARD_REBUFF` — Hard Rebuff | Apply `DELAY_NEXT_ACTION_ONE_INTERVAL` to the original attacker. The shield loses its normal one SHP. | No new roll. |
| Rare | `SHIELD_BLOCK_CS_R_SHIELDED_REVERSAL` — Shielded Reversal | Apply `DELAY_NEXT_ACTION_ONE_INTERVAL` to the attacker and dispatch `IMMEDIATE_COUNTERATTACK`. The shield loses its normal one SHP. | Counterattack uses an otherwise legal equipped physical attack, not an invented shield-bash profile. |

## Shield Block — critical failure

The Shield Block fails, spends no SHP, and the remaining configured legal defense chain continues.

| Rarity | Outcome ID and name | Exact proposed consequence | Additional roll / chain behavior |
| --- | --- | --- | --- |
| Common | `SHIELD_BLOCK_CF_C_LATE_RECOVERY` — Late Recovery | Apply `DELAY_NEXT_ACTION_ONE_INTERVAL` to the defender. | No new roll. |
| Uncommon | `SHIELD_BLOCK_CF_U_DRIVEN_BACK` — Driven Back | Apply `ZERO_REMAINING_MR` and `DELAY_NEXT_ACTION_ONE_INTERVAL` to the defender without changing position. | No new roll. A legal weapon Block or other fallback remains available. |
| Rare | `SHIELD_BLOCK_CF_R_CRUSHED_GUARD` — Crushed Guard | Add `X2_CONSEQUENCE_MULTIPLIER` to the incoming attack if it ultimately reaches damage. No extra SHP loss occurs. | No new roll. Later defenses still resolve normally. |

## Physical Soak — critical success

The eligible Soak succeeds and the parent attack deals no ordinary damage.

| Rarity | Outcome ID and name | Exact proposed consequence | Additional roll / chain behavior |
| --- | --- | --- | --- |
| Common | `SOAK_CS_C_SECOND_WIND` — Second Wind | Apply `RESTORE_HALF_BASE_MR` to the defender. | No new roll. |
| Uncommon | `SOAK_CS_U_BROKEN_TEMPO` — Broken Tempo | Apply `DELAY_NEXT_ACTION_ONE_INTERVAL` to the original attacker. | No new roll. |
| Rare | `SOAK_CS_R_UNMOVED_REVERSAL` — Unmoved Reversal | Apply `RESTORE_HALF_BASE_MR` and dispatch `IMMEDIATE_COUNTERATTACK`. | Counterattack rolls ACC and permits all legal defenses. Successful Soak remains intact. |

## Physical Soak — critical failure

The Soak fails and the remaining configured legal Block opportunities continue. Dodge remains excluded because Soak was actually attempted.

| Rarity | Outcome ID and name | Exact proposed consequence | Additional roll / chain behavior |
| --- | --- | --- | --- |
| Common | `SOAK_CF_C_WINDED` — Winded | Apply `DELAY_NEXT_ACTION_ONE_INTERVAL` to the defender. | No new roll. |
| Uncommon | `SOAK_CF_U_SPENT` — Spent | Apply `ZERO_REMAINING_MR` and `DELAY_NEXT_ACTION_ONE_INTERVAL` to the defender. | No new roll. Legal Block fallback remains available. |
| Rare | `SOAK_CF_R_BODY_GIVES_WAY` — Body Gives Way | Add `X2_CONSEQUENCE_MULTIPLIER` to the incoming attack if it ultimately reaches damage. | No new roll. A later successful Block prevents the damage but does not delete the recorded critical-failure consequence. |

## Proposed event lifecycle

1. Resolve and record the natural d20 plus adjusted value.
2. Match a source-backed trigger policy. A natural trigger and an expanded-range trigger create one critical for that roll, not duplicate criticals.
3. Create a `critical_triggered` event dependent on the roll event.
4. Draw and record the authoritative d100 rarity result.
5. Resolve the stable table/version and outcome ID.
6. Preflight the entire outcome: affected actors, timing, MR bounds, equipment, damage facts, follow-up legality boundary, and dependencies.
7. Commit immediate mutations atomically and schedule dependent follow-up events.
8. Finish normal attack/defense resolution in the order required by the selected outcome.
9. Process any new d20 critical as a new child resolution. Never subtract or cancel earlier success/failure records.
10. Serialize all records and counters into the authoritative snapshot before client digest comparison.

## Proposed implementation data

| Record | Required fields |
| --- | --- |
| Trigger policy | Policy ID/version, roll kind, success results/range, failure results/range, source references, precedence |
| Table | Table ID/version, category, exact rarity bands, ordered outcome IDs, approval status |
| Outcome | Outcome ID, rarity, effect descriptors, eligibility/fallback, affected actor, timing phase, allowed child-roll contract |
| Resolution | Resolution ID, trigger event/roll, natural result, policy source, rarity d100, RNG draw index, outcome ID, status, parent/dependencies, child event IDs |
| Mutation plan | Expected state revision, ordered writes, resource/movement/timing deltas, damage packet additions, rollback-safe preflight evidence |

All protocol-facing values should remain integers, strings, booleans, arrays, dictionaries, or null. Fractional damage factors should use integer numerator/denominator pairs and be combined before the one floor operation.

## Acceptance tests after approval

- Rarity boundaries `1`, `70`, `71`, `95`, `96`, and `100` select the intended rows reproducibly.
- Each of the thirty outcome IDs is covered by a deterministic focused test.
- Natural and expanded triggers create exactly one consequence selection per source roll.
- RB never changes the trigger.
- Follow-up and counterattack ACC rolls use normal legality, defenses, and damage; their criticals form ordered child events.
- A critical-failure damage factor and a later critical-success damage factor both remain in the exact multiplier product when both legitimately apply.
- Delay effects never alter an active action, stored Acts, AT, NAC limits, or movement.
- MR effects never exceed the current round's start value and never carry debt across rounds.
- Shield criticals do not create unapproved SHP changes.
- Physical Soak success still results in zero parent damage.
- Duplicate delivery/request attempts do not repeat a rarity draw, mutation, counterattack, damage, or SHP cost.
- Replay and both simulated clients converge on the same event stream, RNG draw counts, snapshots, and digest.

## Designer decisions required

### Genuine source and approval gates

Combat Specification v1.6 resolves head/neck at Prime's `x1.5`, makes `+1 Critical Range` success-only, and preserves Dwarvestek/Grentek natural `18-20` failures while replacing guaranteed self-damage with weapon-specific weighted failures. The remaining gates are approval of each exact consequence, source-specific prerequisites/weakness stages, and the weapon-specific Dwarvestek/Grentek tables.

### Optional creative choices

1. Approve, revise, or reject each proposed outcome and shared effect contract.
2. Select which categories, if any, may receive the approved zero-Act Critical Reaction or 0.5-second Critical Stagger contracts.
3. Decide explicit unavailable-result/fallback behavior for each approved outcome whose prerequisites can fail.
4. Approve weapon-specific consequence tables where Prime or v1.6 requires them, including Dwarvestek/Grentek.

Until those choices are approved, the current implementation must continue to record triggers and fail closed where a critical consequence is required for damage.
