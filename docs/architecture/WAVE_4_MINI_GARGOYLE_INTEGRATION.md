# Wave 4 Mini Gargoyle Swarmer Integration

## Runtime boundary

Task 33A activates the configured Wave 4 roster as one seeded d4 Small Uncommon Mini Gargoyle Swarmers. It reuses the existing authoritative actor, action, attack, defense, damage, critical, wave, replay and synchronization systems. It does not create a separate flight combat engine or begin Wave 5.

The reusable definition records the creature sheet's HPM 15, MR 16, AT 1, ACC 13, INIT 8, NAL +2, natural claw/claw/bite sequence, Flight at normal MR, Dark Sight 100 feet and Fury once per day. Small is an owner-approved Arena classification. No held weapon, shield, worn armor, Running privilege or unlisted ability is added.

## Natural attack action and Fury

One ordinary AT-1 Act lasts five seconds and owns three attack instances in stable order:

1. Claw 1: `1d6 + eligible SB`, slashing.
2. Claw 2: `1d6 + eligible SB`, slashing.
3. Bite: `1d8 + eligible SB`, piercing.

Target and location are locked with the action; each strike independently performs final three-dimensional reach/LOS, ACC, defense, damage and critical resolution. Fury is a zero-ordinary-Act NAC committed to exactly one eligible natural attack Act. Its exact x2 factor is attached to all three strike records, combines with other legitimate multipliers before one floor, and consumes one daily use plus one slot under the existing five-NAC round cap. No AP fallback is permitted.

## Flight and authored Arena geometry

Authoritative state stores X/Y position plus elevation in micro-feet. Takeoff and landing are continuous MR-funded spatial movement and cost zero ordinary Acts. During transition and ordinary airborne travel, MR 16 supplies `16 / 5` feet per second and all components of a diagonal displacement share one Euclidean cost. Hovering costs nothing; turning has no separate Act/MR cost; no Running or flight endurance mechanic is inferred.

The existing 44-by-23-foot test Arena authors a ten-foot altitude cap and an eight-foot center wall. A grounded actor cannot cross it. A Gargoyle may rise continuously, clear the wall with its base elevation, cross using legal 3D collision, and land continuously near a legal one-foot attack position. Actual 3D separation controls melee reach and final line of sight. These map values are provisional authored test geometry for owner acceptance, not Prime rules.

## Presentation and perception boundary

Each living Gargoyle is a gray-blue square with a white `M`, its existing HPC/facing presentation and a compact altitude label such as `▲ 6 ft`. Fractional authoritative altitude is shown without false integer rounding. The label is hidden while grounded or defeated and cannot modify simulation state.

Wave 4 is authored at night and retains the printed 100-foot Dark Sight fact. General darkness, alertness, Hide/Sneak, light sources, vision cones and actor-knowledge simulation are not source-complete in this task and remain deferred. World position remains authoritative, but no omniscience rule is newly claimed.

## Validation targets

Regression coverage verifies all d4 counts, independent actor state, zero-Act MR-funded takeoff/landing, Euclidean 3-4-5 movement, ten-foot cap, eight-foot wall clearance, three independent natural strikes, one-Act Fury scope, daily/NAC accounting, reset, digest/two-client convergence, altitude formatting and all prior suites. Owner browser acceptance should confirm selector access, visible altitude labels, wall overflight, legal landing/attack behavior and victory after the last Gargoyle is defeated.

## Task 33B swarm tactics and dive interception

The owner-approved Swarmer profile is creature-specific: Gargoyles stage at nine feet, use stable actor-owned approach lanes, begin an approach-capable attack while airborne, descend during that same five-second AT-1 Act, strike only after strict final 3D reach/LOS succeeds, then spend ordinary MR withdrawing to staging height. Only one existing diver is used as a coordination signal; no fixed turn rotation, free retreat, schedule, ACC bonus, damage bonus or immunity is introduced. A wounded Gargoyle at half HPM or less uses a cautious five-foot staging radius instead of four feet, but remains willing to attack.

The failed owner builds selected a mathematically legal strike point 0.8 feet horizontally and 0.6 feet vertically from the target. That is exactly one foot away, but spatial occupancy converted integer micro-foot deltas to a floating `Vector3`; precision loss rounded the squared separation below the one-foot collision diameter. Every candidate was therefore rejected as occupied, so the Gargoyle stayed near nine feet and all three strikes failed final range without ACC. Spatial actor separation now uses exact integer squared distance. The same-plane collision rule is unchanged, while the exact 3-4-5 contact boundary is stable across platforms and replay.

Ground-plane occupancy also filters actors whose authoritative vertical separation is at least the collision diameter. An airborne Gargoyle directly over a grounded actor therefore no longer freezes legal ground movement, while actors on the same plane still cannot overlap. Failed preferred endpoints use the remaining stable lanes; actor congestion is recorded and retried without suppressing authoritative events. Moving targets may still lawfully escape reach before final effect, and such attacks remain unrefunded final-legality failures.

Owner Seed 7 playtest acceptance confirmed the intended four-Gargoyle encounter behavior: coordinated legal dives produced damage, the swarm withdrew and re-engaged, and all four Gargoyles could be defeated. This is playtest evidence for the existing tactics, not a new combat rule.
