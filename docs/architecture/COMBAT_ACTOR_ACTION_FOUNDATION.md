# Combat Actor and Action Foundation

## Authority and version check

The current Combat Specification contains the approved v1.3 action-timing amendment, and the current Roadmap contains the v1.5 timing milestone. These amendments supersede Task 4's stored-Act interpretation. Neither source document is modified by implementation work.

Prime V3 pp. 19-25 defines the attribute and derived-stat meanings used by the actor schema. AT, MR, ACC, INIT, NAL, DT, DP and Physical Soak remain explicit source values; the model does not infer a formula from the Prime lookup charts. Combat Specification section 15 supplies the controlling Arena action contract: one Act lasts `5 seconds / AT`, no action currency is stored, multi-Act actions occupy successive intervals, and their effect occurs on the final interval. Sections 3 and 15 supply timestamp ordering, interruption-before-finalization and same-timestamp INIT priority.

## Runtime boundary

`CombatActorDefinition` stores immutable, source-referenced inputs for player and enemy actors. Missing core attributes or required combat statistics are listed in `unresolved_fields`; missing data is never converted to zero. `CombatActorState` stores match-only HPC, resource pools, equipment references, conditions, awareness, integer-microfeet position, facing, continuous timing state, current action and revision.

`CombatActionDefinition` stores an explicit Act count, movement compatibility, interruptibility, resource-commitment descriptors and reserved reaction/NAC metadata. These fields do not spend resources or resolve NACs. `CombatActionInstance` records declaration, start, Act progress, terminal status, timestamps, dependencies and causal event identifiers.

`CombatSimulation` is the only actor/action state writer. It validates a request completely before mutation, rejects duplicate request IDs, processes only due events when `advance_to()` is used, and resolves timestamp ties through the existing queue order: timestamp, descending INIT, stable sequence, event ID. An action waiting on dependencies cannot finalize until every referenced action is terminal. An interruption only changes a nonterminal interruptible action.

## Deterministic AT cadence

Simulation time is integer microseconds. For resolved AT `A`, interval boundary `k` occurs at `anchor + ceil(k * 5,000,000 / A)`. An action begins with zero completed intervals and completes/effects only on its final required boundary. Immediately sequential actions retain the same anchor and cumulative interval index; an idle gap establishes a new anchor. This ceiling policy never resolves early and keeps fractional sequences such as AT 3 aligned to exactly five seconds after three intervals. INIT never changes a duration. Round intervals remain half-open: `[0, 5,000,000)`, `[5,000,000, 10,000,000)`, and so on.

Actor state contains only the timing anchor, last completed interval boundary, cumulative interval index and current action identifier. It contains no Act balance, regeneration clock, initial reserve or token expenditure. Actions crossing a round boundary retain their original schedule.

## Synchronization boundary

Authoritative envelopes now carry a canonical combat-state snapshot as well as the ordered event. Observer digests cover both their transcript and latest snapshot. The snapshot contains source definitions, actor states, action definitions/instances, pending events, simulation revision, RNG seed/draw count and next stable sequences. Protocol values remain integers, strings, arrays, dictionaries, booleans or null for Windows/Web parity.

Phase 1 Task 6 extends that snapshot with opening-Initiative evidence/ranks and physical attack definitions/instances. ACC successes are serialized as `pending_defense`, misses as `missed`, and pre-roll interruptions as `interrupted`; none of these states applies damage.

This remains an in-process synchronization harness. There is no network transport, prediction, rollback, matchmaking or client-owned combat decision.

## Deferred mechanics

No attack, ACC roll, damage, armor, critical consequence, defense resolution, Special, NAC resolution, AI, loot or progression behavior is present. Resource commitments are descriptive only. Aren Valecrest and Garrick Ironward still require source-audited definitions before they are entered as production combat data.
