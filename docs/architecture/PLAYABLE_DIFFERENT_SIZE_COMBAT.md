# Playable Different-Size Combat Verification

## Scope and fixture identity

Task 29 adds one opt-in development encounter for playable verification of Task 28's directional size-based ACC catalog. It does not add a creature library or a second combat path.

The opponent is explicitly named **Synthetic Small Guard Test Fixture**. Its attributes, derived statistics, Battle Axe, Plate torso, Metal Buckler, Running profile and scripted opponent behavior are the existing Guard fixture without modification. Only immutable `size_category` changes from Prime `Medium` to Prime `Small`. The synthetic actor is not an authentic printed Prime creature or NPC and must not be presented as one.

This fallback was selected because the reviewed printed non-Medium creatures require natural attacks, creature protection, immunities, Specials or other creature-specific data that the narrow Guard/equipment vertical slice cannot represent completely without expanding scope. Prime V3 pp. 95-97 remain the authority for size categories and directional hit-location ACC modifiers; the reused Uncommon Guard values are from Prime V3 p. 336.

## Launching the encounters

The Arena opens in the unchanged `MEDIUM vs MEDIUM` Guard encounter. While the encounter is `READY`, use the `DUEL M/M` button once to select `DUEL M/S*`, then press `START`. The asterisk identifies the synthetic test opponent. The selector is disabled after START so a running authoritative simulation cannot change fixture identity.

`RESET` rebuilds the simulation clock, seed, actors, equipment, battlefield and presentation while preserving the selected duel variant. After RESET returns the encounter to READY, the duel selector can be changed again.

## Authoritative integration

Both duel variants use `ArenaCombatSession`, `CombatSimulation`, the existing battlefield, the existing input adapter and the existing deterministic opponent driver. No ACC formula is duplicated in the UI.

For every valid attack, the authoritative attack instance locks:

- attacker and target identifiers;
- selected numbered location, including Knee or Lower Leg for location 8;
- attacker and target size categories;
- directional size-relationship identifier;
- location ACC modifier and final ACC target.

The declaration and ACC-resolution event payloads retain those locked values. The player-facing transcript formats the event data, so changing the current target or aim selection during execution cannot alter or mislabel an already-declared attack.

With the current ACC 12 Guard fixtures and torso targeting:

- Medium player to Small opponent uses `medium_to_small`, location modifier `-3`, final ACC target `9`.
- Small opponent to Medium player uses `small_to_medium`, location modifier `-1`, final ACC target `11`.
- The default Medium-to-Medium duel remains `same_size`, location modifier `0`, final ACC target `12`.

Unsupported encounter identifiers and missing or unsupported actor-size data fail closed. Size changes no weapon reach, movement speed, equipment requirement, armor coverage, damage multiplier or defensive rule.
