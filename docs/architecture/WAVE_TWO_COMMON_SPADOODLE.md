# Wave 2 Common Spadoodle Integration

## Source and scope

Task 32A transcribes the supplied `Common Spadoodle.doc` into the existing definition/catalog architecture. The stable Arena Combat Specification and Roadmap identify Wave 2 as authoritative `1d3` Common Spadoodles. Prime V3's size chart supplies directional Small/Medium hit-location ACC relationships. No creature library, generalized AI, new combat formula, Wave 3 actor, loot, EXP, climbing surface or fear system is introduced.

## Authoritative creature fixture

- HPM 10; STR 4; SB 1; END 1; SPD 10; MR 10; AT 1.
- DEX 6; DT 6; PD/DP 0; ACC 7; WIT 1; INIT 1.
- Base NAL 0 plus source scale hide NAL +2 all over; Physical Soak 0.
- Two natural slashing claws; each has two-foot reach and `1d6` damage.
- Small size for the verified two-foot creature fixture.
- No held weapon, shield, worn armor, weapon Block, Running investment, Special or unlisted skill is supplied.

The owner-resolved attack sequence uses two independent claw attack instances linked to one AT-1 action. Both declarations share the action's five-second interval. Each strike carries a stable index and independently applies final legality, ACC, defense, damage and critical gates. This is not two Acts and does not double movement or declaration cadence.

## Wave lifecycle and determinism

The development launcher initializes catalog `wave_2` directly. This does not fake Wave 1 completion. One call to the seeded combat RNG resolves `1d3`; the wave history stores `dice_count = 1`, the ordered die result/draw index and final count. The session registers and activates the exact actor IDs, and victory occurs only when all of those actors have authoritative HPC at or below zero. RESET recreates the same count, IDs, opening Initiative rolls and event history from the same seed.

The Wave 1 multi-actor behavior path is reused for deterministic walking pursuit, wall navigation, occupancy reservations, legal attack entry, defeat removal and status reporting. Spadoodles do not use Running because the source supplies no Running investment. The unchanged battlefield supports the maximum three-spawn formation without scale or geometry changes.

## Presentation and controls

Before START, press the encounter selector until it reads `WAVE 2`. Optionally enter a seed and press APPLY, then START. Brown-gold squares with white `S` glyphs identify Common Spadoodles. Tab/Shift+Tab, click/tap selection, aim-location keys, mouse/keyboard/touch attack input, movement, RUN, DEBUG, FULL LOG and RESET retain their established behavior. Each living Spadoodle displays its own HPC and target/facing feedback.

Defeating every Spadoodle ends the Wave 2 development encounter. It does not enter Wave 3. The source Climb entry remains inactive because the test arena has no climbable geometry; the printed fear statement does not trigger against the current Medium Guard because it refers to creatures bigger than Medium.
