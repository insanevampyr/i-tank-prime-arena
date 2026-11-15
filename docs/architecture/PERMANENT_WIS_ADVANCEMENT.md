# Permanent WIS advancement and event-time Mana replay — Task 44B

Scope: one-point permanent WIS purchases from current scores 1–19, producing at most 20. No zero recovery, cap-breaking, END, temporary WIS, regeneration, Meditation or learning system is enabled.

## Authority and purchase

V3 p.102 prices use CURRENT permanent score: 1–5 costs 2,000 EXPC; 6–10 costs 3,000; 11–15 costs 5,000; 16–19 costs 7,000. SS comes from the verified Universal Attribute Engine (both Mana and Regular charts). Existing chart cells/citations are untouched.

The owner supplement to V3 pp.21/72 grants exactly +1 Mana Max per purchased permanent WIS point for Mana users. Current Mana is unchanged. Regular Ability users have no Mana pool and receive no extra AP from WIS. No EXPM, earned XP, level, HPM, unrelated attribute, inventory or equipment change is authorized.

Preview/apply validates integer permanent WIS, explicit Mana/Ability mode, source provenance, and exact chart-equivalent base SS before mutation. Stored authored SS exceptions, missing data and actors with authored MSL/MR/H fields are rejected, never silently recalculated. Only SS becomes a new authoritative base value. MSL/MR/H remain chart references; no recovery clock, learning eligibility system or newly stored MSL/MR/H statistic is created. Existing equipment MR/DT/DP and independently source-qualified effects remain separate.

## Historical replay before purchase activation

No timestamps or new persistent chronology fields are invented. Each original growth record already records event-time WIS and maximum_before/increase/after. Each supported WIS receipt describes a monotone, priced +1 step from its previous permanent score.

Hydration first validates the complete purchase sequence, costs, identities and immutable authored baseline. WIS steps are deferred. Before each original growth record, replay consumes only the validated WIS steps necessary to reach that record's WIS. Growth then validates the recorded maximum_before and exact level gain against that event-time score. Remaining purchases occur after the final recorded growth. This reconstructs starting Mana + original chronological level gains + positive WIS purchase contributions without recalculating any old gain from final WIS.

Missing purchase evidence, decreases, reordered/duplicated steps, modified growth arithmetic and final-max inconsistencies fail closed. Existing generation-prefix and settlement checks prevent rewriting a previously committed growth history into a different otherwise plausible arithmetic chronology. The existing unsigned local-backup policy is unchanged; this is not a new authentication system.

A transient actor counter accumulates only successfully replayed positive WIS Mana contributions. It lets level-one validation distinguish starting Mana from purchased Mana. It is reconstructed from purchases on every hydration and is not a new serialized save/snapshot field. It is not a net current-WIS-minus-starting-WIS formula and does not introduce permanent-loss support.

## Persistence and UI

Reuse the existing safe READY/downtime eligibility, stale quote, request deduplication, receipt, atomic generation, writer lease, exact retry and readback paths. WIS requests retain their request hash in durable purchase identity, including after reload. Pending publication blocks further mutations. Immutable initial_wis/base_attributes, old growth, receipts and both profile namespaces remain unchanged. V2/V4/V5 envelopes and simulation schema12 retain their existing shapes; no migration is performed.

The existing management preview shows current/next WIS, cost, spendable EXPC, SS change and +1 Mana Max with explicit no-refill text. The Character Sheet consumes the already-updated permanent WIS, stored SS and Mana maximum.

## Validation and owner acceptance

Independent frozen source-chart expectations, every supported score/cost and affordability edge, level-one/interleaved event-time replay, tamper rejection, actual UI/casting, deterministic replay/client convergence, Desktop/host-simulated-Web persistence, lost acknowledgments, backup restoration, NEW RUN/NEXT WAVE/RETRY and credited V5 fixtures are covered by the new focused suites. All fixtures are disposable. No owner profile or IndexedDB is accessed.

Actual owner Edge acceptance remains pending: WIS purchase/SS/Mana Max/reload; existing one-time EXPC confirmation with unchanged EXPM; SPD movement/timing; RESUME/NEW RUN and DEV multiplier; backup progress/preview/cancel; crowded pursuit.
