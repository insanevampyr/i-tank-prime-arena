# Critical System Foundation and Approved Consequences

## Authority and scope

Phase 1 Task #12 activates the ten general designer-approved critical tables in `ITank_Prime_Arena_Approved_Critical_Tables.md`, using Combat Specification v1.7 section 18 as the controlling execution contract. Prime V3 remains authoritative for natural/printed critical ranges and the ordinary rules beneath an outcome. The older `PROPOSED_CRITICAL_CONSEQUENCE_TABLES.md` is retained only as historical design material; none of its conflicting rows is live.

## Trigger and selection

- `CombatCriticalTriggerPolicy` classifies the unmodified d20. Generic natural 1/20, source-approved success-only expanded ranges, and Dwarvestek/Grentek 18-20 failure policies remain data-driven. RB never changes critical eligibility.
- One stable roll ID produces one `CombatCriticalRecord` and one authority-owned d100. Common is 1-70, Uncommon 71-95, and Rare 96-100.
- `CombatCriticalConsequenceCatalog` contains exactly the 30 approved general rows. A record stores its table, named outcome, applied and unavailable effect IDs, reason, causal children, and `selected`, `pending`, `applied`, `partially_applied`, or `blocked` status.
- Authoritative snapshots include every record, deferred reaction, registered reaction attack, RNG draw count, and actor/action mutation. Passive clients never choose an outcome.

## Effect processing

### Exact damage factors

Approved x2 outcomes attach one record-scoped rational factor to the parent attack. They do not guarantee a hit and do not apply after a successful defense. The damage transaction multiplies all legitimate factors exactly, floors once, then subtracts TAL and NAL before HPC. If a source definition also carries a legacy critical factor, the selected approved consequence factor is not duplicated.

### Critical Stagger

Critical Stagger sets an authoritative end timestamp exactly 500,000 microseconds after application. It removes queued progress/finalization events for an unfinished interruptible action, records the interruption, blocks new ordinary actions and voluntary movement, and expires on deterministic simulation time. It does not remove committed resource evidence, completed effects, passive protection, or otherwise legal defense rolls.

### Prone and standing

Prone is idempotent. It adds no implicit Stagger and no extra cost when already present. Ordinary action starts are rejected while prone except `start_stand_action`, which occupies one full Act and clears prone at completion.

### Critical Reactions

A reactor must have a registered, equipped attack definition plus authoritative line-of-sight/range/target facts. A legal reaction is declared only after its parent attack becomes terminal, costs zero ordinary Acts, is not a NAC, rolls fresh ACC, enters the ordinary defense/damage pipeline, and may generate another critical record. No chain cap is imposed. Missing equipment, range, target, attack definition, ACC, or line of sight records an unavailable effect instead of a substitute reward.

### Defense-specific boundaries

- Perfect Evasion uses the existing deterministic legal Dodge candidate. It grants no additional MR or teleport. If displacement remains unresolved, its consequence remains pending until the supplied destination validates.
- Unshakable records attack-scoped protection only; it never removes an earlier or unrelated condition.
- Successful shield Blocks still spend one SHP. Devastating Reversal applies prone only when `verified_shield_contact` is explicitly true; an unavailable prone component does not suppress an independently legal counterattack.
- Failed shield Blocks do not spend SHP.
- Disastrous Backfire remains explicitly blocked because verified redirection/contact geometry is not yet represented. It never becomes automatic self-damage.

## Dwarvestek and Grentek gate

Separate typed firearm and explosive table IDs preserve the verified 18-20 failure trigger and approved Common/Uncommon/Rare severity themes. Every exact effect is deliberately blocked. Scatter, blast radius, fuse/timer behavior, persistent malfunction or jam state, jam clearing, and numeric self-damage are not inferred. Firearm and explosive mechanics require distinct source-backed definitions before activation.

## Non-goals

Task #12 does not implement Specials, NAC effects, AI, loot, progression, network transport, production weapons, or unverified Dwarvestek/Grentek behavior. Critical Reactions use explicit attack registrations rather than selecting weapons or targets by an invented AI policy.
