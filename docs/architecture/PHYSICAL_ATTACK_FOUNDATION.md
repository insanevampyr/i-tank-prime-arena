# Opening Initiative and Physical Attack Accuracy Foundation

## Authority and scope

Prime V3 pages 20-23 and 31 establish physical ACC, opening `1d10 + INIT`, higher-base-INIT tie-breaking, exact simultaneous ties, five-second rounds, movement during actions and RB treatment. Pages 91-94 confirm roll-at-or-under checks and natural d20 critical triggers. The Arena Combat Specification sections 3, 15 and 16 require mandatory ACC, torso defaulting, deterministic continuous `5 seconds / AT` execution and a pending defense boundary.

The Task 6 attack component stops after physical attack accuracy. Phase 1 Task 7 extends its `pending_defense` result through the separate physical-defense transaction documented in `PHYSICAL_DEFENSE_FOUNDATION.md`. Neither component rolls damage or changes HPC.

## Opening Initiative boundary

`CombatSimulation.begin_combat()` validates that every registered actor has a resolved INIT, then draws one authoritative d10 per actor in stable actor-ID order. Each actor snapshot stores the natural d10, RNG draw index, base INIT, total and opening rank.

Opening ranks sort by total descending and then base INIT descending and remain recorded as evidence. Under the controlling Task 31E Option B ruling, those ranks do not gate declarations: every actor may move and independently begin any legal action as soon as combat starts. INIT orders genuinely competing effect events at the same authoritative timestamp; the existing stable sequence and event identifier remain the fallback. No Initiative-to-seconds delay or priority window exists.

This is a declaration-order gate, not a turn queue or arbitrary opening delay. A future input layer still needs an explicit pass/forfeit intention so combat cannot wait forever for a participant that chooses not to declare.

## Physical attack data boundary

`CombatAttackDefinition` contains only explicit attack inputs: stable ID, weapon reference, required Act intervals, movement/interruption flags, ACC modifiers by supported location, resolved integer range, line-of-sight requirement and source references. An unresolved maximum range fails closed. Task 6 includes only labeled engine fixtures; it does not create production weapon statistics.

`CombatAttackInstance` links the definition to its action, attacker, target, weapon and location. It records base ACC, all represented modifiers, RB, natural d20, adjusted result, RNG draw index, critical flags, resolution timestamp and one of these states:

- `executing`: action intervals or dependencies remain unresolved.
- `pending_defense`: ACC succeeded; future defense resolution is required.
- `missed`: ACC failed; no defense or damage follows from this attack stage.
- `interrupted`: the linked action was interrupted before accuracy resolution; no ACC die was drawn.

## Declaration validation

The authority rejects an attack before action mutation or RNG use when any required fact is invalid or unresolved:

- Opening Initiative has not been resolved. Once resolved, rank never delays an otherwise legal declaration.
- Attacker or target is missing, identical, or has no positive current HPC.
- The declared weapon reference is not equipped.
- ACC, target location modifier or maximum range is unresolved.
- The selected location is unsupported; an omitted location becomes torso.
- Authoritative line of sight is required but unverified.
- Canonical integer positions fall outside the resolved minimum/maximum range.
- The request ID or definition ID conflicts with an existing authoritative record.

The current line-of-sight value is an authority-supplied validation fact because no Arena map collision service exists yet. A client assertion must never be wired directly to this parameter.

## Accuracy resolution

At the linked action's final effect point, after dependencies are terminal, the authority draws one d20. RB beneficially lowers the adjusted roll. The natural die independently determines critical classification: natural 1 is critical success and natural 20 is critical failure. No critical consequence is selected in this task.

A successful accuracy check records `pending_defense` and `damage_applied: false`. It is not a final hit and cannot alter HPC. Interruption before finalization records `interrupted` without consuming the d20. Deterministic snapshots and simulated clients include opening and attack state.

## Deferred decisions and data

- Production ACC lookup rows, actor data, weapons, ranges, size categories and aimed-location matrices require source transcription.
- The rules do not specify a real-time delay between opening Initiative ranks; none is invented.
- The future input layer needs a deterministic opening pass/forfeit operation.
- Mid-action AT changes and source-specific timing/ACC exceptions remain source-gated.
- Defenses, damage, armor, expanded weapon critical ranges and critical consequences are outside Task 6.
