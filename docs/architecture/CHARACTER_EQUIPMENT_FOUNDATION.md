# Character and Equipment Foundation

## Authority and available sources

Task 22 uses the ITank Prime V3 manuscript dated 03-01-2026 and the current project Rules Ledger. The locally available Arena Combat Specification and Roadmap both identify themselves internally as v1.8 dated 15 October 2026. Requested v1.9 documents were not available and were not treated as reviewed.

The data migration changes where verified fixture values live, not how combat resolves them. `CombatSimulation` remains authoritative. Resource definitions do not own current HPC, SHP, conditions, movement spending, action timing, RNG, events, or visual state.

## Definition layout

- `data/characters/prime_v3_uncommon_guard.tres` stores reusable identity, attributes, derived combat values, capabilities, Running fixture metadata and source references.
- `data/equipment/weapons/prime_v3_battle_axe.tres` stores the Battle Axe dice, fixed bonus, SB eligibility, Slashing type, three-foot reach, Strength requirements, Block, critical range and approved approach capability.
- `data/equipment/shields/prime_v3_metal_buckler.tres` stores Strength requirement, Block, maximum SHP and `2 Hands Free` evidence.
- `data/equipment/armor/prime_v3_plate_torso.tres` stores torso coverage, Bashing/Slashing/Piercing TAL, Strength requirement and the printed movement/Dodge penalties.
- `data/loadouts/arena_guard_plate_buckler.tres` composes the approved Arena vertical-slice loadout by stable reference.
- `CombatDefinitionCatalog` owns reference integrity and validation. It distinguishes `invalid`, `not_yet_implemented`, and `requires_source_verification` issues.

Each `instantiate_actor` call deep-copies definition dictionaries into a new `CombatActorDefinition`. `CombatActorState` owns mutable HPC, resources, equipment references and conditions. Weapon/shield/armor resources create fresh combat definitions, so shield SHP cannot leak between combatants or resets.

## Source mapping

| Field group | Stored value | Classification and source |
| --- | --- | --- |
| Guard identity | Uncommon Guard; race Varies; Fighter | Prime V3 p. 336 |
| Guard attributes | STR 16, END 10, SPD 12, DEX 14, WIS 8, INT 5, WIT 8, MAN 12, LUK 1, APP 8 | Prime V3 p. 336 |
| Guard combat values | HPM 100, SB 4, NAL 1, Physical Soak 4, MR 12, AT 2, DT 8, DP 6, ACC 12, INIT 4, RB 0 | Prime V3 p. 336 |
| Running profile | three investments, SCM 0, RB 0 | Explicit Task 3 test fixture; the Guard row does not print these Running investments |
| Battle Axe | `2d10 + 3 + eligible SB`, Slashing, reach 3 feet, STR 12, two-handed below STR 24, Block 2, critical success on natural 1-2 | Prime V3 p. 127 plus previously verified general SB handling |
| Approach capability | declaration may begin outside reach; final range/LOS gate before ACC | Approved Arena v1.8 section 18 adaptation; not a printed Battle Axe property |
| Metal Buckler | STR 8, Block 2, SHP 20, `2 Hands Free` | Prime V3 p. 137 |
| Plate torso | torso TAL 3 against Bashing/Slashing/Piercing; STR 16; MR -1; Dodge -2/-2 | Prime V3 p. 135 |
| Plate and buckler loadout | Guard plus Battle Axe, Plate torso and Metal Buckler | Approved assembled Arena test fixture; the printed Uncommon Guard instead lists full Leather armor and no buckler |

The printed Plate movement and Dodge penalties are now recorded but deliberately remain `not_yet_implemented`. Applying them during a schema migration would change the established MR 12 and defense fixture behavior. Their integration requires a separately approved, regression-tested rule task.

## Combat connection

`PrimeV3VerticalSliceFixture` loads the catalog, validates the selected character and loadout, creates independent player/opponent actor definitions, and converts equipment resources into the existing `CombatAttackDefinition`, `CombatBlockDefinition`, and `CombatArmorDefinition` types. Registration, opening Initiative, AT, ACC, defenses, damage, criticals, movement, Running, prone, Stagger, final geometry and event processing remain unchanged.

The Task 22 regression builds one exchange from a frozen pre-migration constructor and one from the resource-backed fixture using the same seed, actor positions, declarations and effect timestamp. It compares authoritative event signatures and runtime actor states. Existing replay and two-client suites remain active.

## Opponent activation finding

The opponent driver is enabled while the scene is prepared but the encounter is inactive until START. START immediately runs the driver. If the player owns opening Initiative rank 0, the opponent reports `blocked_opening_initiative_wait` and cannot declare until the player makes the first declaration. That declaration unlocks the next opening rank at the same simulation timestamp; there is no artificial real-time delay or attack-triggered aggro rule. The observed simultaneous declarations at 10.467 seconds are consistent with the player waiting 10.467 seconds before declaring and the lower-ranked opponent declaring immediately afterward.

## Battlefield rectangle finding

The right gray rectangle is `center_wall`. It rejects movement and Dodge paths, blocks line of sight, affects pathfinding and can prevent final attack legality. It adds no cover or ACC modifier.

The left brown/orange rectangle is `non_damaging_test_hazard_zone`. It is walkable, does not block line of sight, adds no MR or movement cost, supplies no cover or ACC modifier, and causes no damage. Its only authoritative effect is hazard tier 1 for automatic Dodge destination preference. Ordinary pathfinding does not treat it as difficult terrain. The scene now labels it `WALKABLE DODGE TEST` and labels the gray rectangle `WALL` so presentation matches authority.

## Safe extension procedure

Add a new resource with a unique stable ID and exact source references, then register it in a catalog. Do not add a loadout until every referenced definition exists and its verified requirements can be validated. Missing values remain explicit verification issues; unsupported mechanics remain not-yet-implemented gates. Never substitute a generic slot, proficiency, penalty or attribute formula.
