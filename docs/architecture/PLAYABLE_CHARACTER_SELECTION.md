# Playable Character Selection

Task 34 adds a bounded READY-state selector to the existing Arena scene. `CHAR: GUARD` is the default; pressing it toggles to `CHAR: VAELIS`. The selected character name is also shown in the combat status. Selection rebuilds the chosen duel/wave with the current seed, remains disabled after START, and is preserved by RESET.

## Runtime profiles

- **Uncommon Guard:** unchanged Battle Axe, Metal Buckler and Plate torso Arena regression fixture.
- **Vaelis Thorn:** separate Medium female actor with the supplied/verified physical statistics, Short Sword in the right hand, Short Wand in the left, no armor and no shield. One ordinary ATTACK action attempts both independently legal physical strikes: Short Sword first, then Short Wand. The two strikes share one AT-1 Act but retain their own equipment, reach, ACC, defense, damage and critical resolution.

Mutable HPC, Mana, Blood, conditions, movement/action state and hand occupancy are created per encounter. Switching before START creates a new actor instance; Guard and Vaelis definitions are never overwritten or shared as mutable state.

## Verification boundary

Prime V3 independently confirms the supplied attributes' Mana-chart derived combat values and both weapons. HPM 9 depends on the supplied level-one HD result, while DT 3 / DP 6 is the supplied legal DEX allocation. The supplied character-creation rolls, freebie-point choices, gold and noncombat skill selections are preserved as character-record facts but are not recomputed by Arena.

## Force controls and authoritative behavior

Vaelis has the following bounded controls; Guard behavior is unchanged:

- Right-click assigns/uses Force Bolt by default. Holding right-click repeats only while each new activation is legal; it does not create stored Acts or bypass Mana, range, line of sight, SS, ACC, defense, NAC or interruption checks.
- `Q` starts Force Shield as an ordinary one-Act cast. `E` voluntarily cancels Vaelis's active Force Shield without spending an Act.
- `F` restores the right-click assignment to Force Bolt. `N` opens the compact NAC settings panel.

Force Bolt costs 2 Mana, has ten-foot range, rolls SS and then ACC, deals `1d6` Force damage, and requests two feet of legal knockback on a damaging hit. It is a zero-Act NAC and uses the shared maximum of five NAC activations per actor per five-second round. Automatic Force Bolt is disabled by default and only evaluates a hostile physical-attack declaration as perceived danger; proximity alone never triggers it. The Balanced, Defensive, Aggressive and Guardian profiles configure only the actor's automatic-use toggle, Mana reserve and per-round automatic budget. Manual use remains authoritative and legal-state checked.

Force Shield costs 4 Mana, rolls SS, and occupies one ordinary Act at Vaelis's current level. It may target Vaelis or a character within touch range, is nonstacking, persists without a time expiry, and may be voluntarily canceled. Its 20 separate protective points absorb applicable physical damage after TAL and NAL and before HPC changes; a physical attacker that is actually absorbed is submitted to the existing legal two-foot knockback resolver. Shield capacity, Mana, NAC counts and automation settings are part of authoritative snapshots and digests.

The current implementation deliberately does not fabricate Special Resistance, magic-specific critical consequences, or additional Force effects. A recorded natural critical trigger remains visible, but unsupported magic consequence resolution stays unavailable.

Character selection performs no RNG draw. Wave quantities are resolved from the same first authoritative draws for Guard and Vaelis at the same seed. Attack/action events use the stable `player` actor ID and the selected actor definition/equipment snapshot, preserving existing replay and synchronization contracts.

The exported FULL/COPY/SAVE transcript reports the actual encounter fixture, selected character ID/display name, loadout ID and authoritative equipped-item references. The `application/config/version` value remains a manually maintained project version and is labeled `Project version`; it is not presented as a generated per-task build identifier.

For an ordinary multi-strike Act, all strikes that were legal when committed remain eligible to finish in their stable sequence. If an earlier strike reduces the target to zero HPC or below, that state takes effect immediately: a later committed strike may still complete its own legal resolution and overkill accounting, but the incapacitated target cannot initiate a fresh defense against it. Any defense already resolved before incapacitation is retained unchanged. This is the Task 34D owner-approved Arena ruling, not a rule attributed to the printed Prime V3 manuscript.
