# Character and Equipment Foundation

## Authority and available sources

Task 22 established this architecture from the ITank Prime V3 manuscript dated 03-01-2026 and the project Rules Ledger. The current stable-filename Arena Combat Specification and Roadmap now identify their controlling addenda internally as v1.12 dated 16 October 2026. Task 24 uses those addenda plus its locked designer ruling where the task explicitly resolves the addenda's earlier Long Staff question.

The data migration changes where verified fixture values live, not how combat resolves them. `CombatSimulation` remains authoritative. Resource definitions do not own current HPC, SHP, conditions, movement spending, action timing, RNG, events, or visual state.

## Definition layout

- `data/characters/prime_v3_uncommon_guard.tres` stores reusable identity, Prime size category, attributes, derived combat values, capabilities, Running fixture metadata and source references.
- `data/equipment/weapons/prime_v3_battle_axe.tres` stores the Battle Axe dice, fixed bonus, SB eligibility, Slashing type, three-foot reach, Strength requirements, Block, critical range and approved approach capability.
- `data/equipment/shields/prime_v3_metal_buckler.tres` stores Strength requirement, Block, maximum SHP and `2 Hands Free` evidence.
- `data/equipment/armor/prime_v3_plate_torso.tres` stores torso coverage, Bashing/Slashing/Piercing TAL, Strength requirement and the printed movement/Dodge penalties.
- `data/loadouts/arena_guard_plate_buckler.tres` composes the approved Arena vertical-slice loadout by stable reference.
- `CombatDefinitionCatalog` owns reference integrity and validation. It distinguishes `invalid`, `not_yet_implemented`, and `requires_source_verification` issues.

Each `instantiate_actor` call deep-copies definition dictionaries into a new `CombatActorDefinition`. `CombatActorState` owns mutable HPC, resources, equipment references and conditions. Weapon/shield/armor resources create fresh combat definitions, so shield SHP cannot leak between combatants or resets.

Task 28 adds `size_category` as immutable actor-definition data, validated against Prime's printed Tiny, Small, Medium, Large, Extra Large, Gigantic and Enormous categories before a catalog-backed actor can register. It is separate from mutable combat state and equipment. A size-aware attack fails closed if either participant lacks a supported category.

## Source mapping

| Field group | Stored value | Classification and source |
| --- | --- | --- |
| Guard identity | Uncommon Guard; race Varies; Fighter | Prime V3 p. 336 |
| Guard size category | Medium | Prime V3 pp. 95-97 printed height bands; approved Task 28 fixture classification |
| Guard attributes | STR 16, END 10, SPD 12, DEX 14, WIS 8, INT 5, WIT 8, MAN 12, LUK 1, APP 8 | Prime V3 p. 336 |
| Guard combat values | HPM 100, SB 4, NAL 1, Physical Soak 4, MR 12, AT 2, DT 8, DP 6, ACC 12, INIT 4, RB 0 | Prime V3 p. 336 |
| Running profile | three investments, SCM 0, RB 0 | Explicit Task 3 test fixture; the Guard row does not print these Running investments |
| Battle Axe | `2d10 + 3 + eligible SB`, Slashing, reach 3 feet, STR 12, two-handed below STR 24, Block 2, critical success on natural 1-2 | Prime V3 p. 127 plus previously verified general SB handling |
| Approach capability | declaration may begin outside reach; final range/LOS gate before ACC | Approved Arena v1.8 section 18 adaptation; not a printed Battle Axe property |
| Metal Buckler | STR 8, Block 2, SHP 20, `2 Hands Free` | Prime V3 p. 137 |
| Plate torso | torso TAL 3 against Bashing/Slashing/Piercing; STR 16; MR -1; DT -2; projectile Dodge -2 | Prime V3 p. 135; Task 25 owner-confirmed left/right Dodge interpretation |
| Plate and buckler loadout | Guard plus Battle Axe, Plate torso and Metal Buckler | Approved assembled Arena test fixture; the printed Uncommon Guard instead lists full Leather armor and no buckler |

Task 25 activates the printed armor penalties through the definition catalog. Armor stores independent MR, DT and projectile-Dodge components. The catalog sums each component across equipped armor, preserves the character definition's unmodified values as `base_combat_stats`, and exposes the adjusted values through authoritative `combat_stats`. Recalculation always starts from the baseline dictionary, so repeated derivation cannot compound a penalty. A variable `V` component is recorded in `unresolved_penalty_fields` and blocks actor construction instead of becoming zero.

For the current assembled Guard fixture, Prime V3 p. 336 remains the source of baseline MR 12, DT 8 and DP 6. The equipped Plate torso row on Prime V3 p. 135 applies MR -1, DT -2 and DP -2, producing effective MR 11, DT 6 and DP 4. Running still adds `floor(SPD / 2)` to effective walking MR, so this fixture runs at MR 17; its skill target, automatic proficiency, endurance cap, recovery and retry rules are unchanged.

## Task 23 catalog expansion

Task 23 added only printed Prime V3 equipment data and made no new hand-occupancy assumption. Task 24 subsequently supplies and implements the approved occupancy rulings described below.

| Definition | Verified data | Prime source | Combat readiness |
| --- | --- | --- | --- |
| Short Rod | STR 4; Bashing; 2-foot reach; `1d6 + 2`; Block 1 | p. 131 | Ready for the existing in-reach physical pipeline; not assigned to a production loadout |
| Great Sword | STR 10; Slashing/Piercing; 4-foot reach; `2d6 + 2`; Block 2; natural 1-2 critical; two-handed unless STR 20 | p. 126 | Combat-ready after Task 24 occupancy validation; not assigned to a production loadout |
| Long Staff | STR 4; Bashing; 8-foot reach; `1d6 + 2`; Block 2; printed two-handed | p. 131 | Combat-ready after Task 24 applies the locked universal double-STR ruling; not assigned to a production loadout |
| Wood Buckler | STR 7; Block 2; SHP 10; `2 Hands Free` | p. 137 | Fully represented; not assigned to a production loadout |
| Leather torso | STR 7; torso TAL 1 versus Slashing; no printed MR/Dodge penalty | p. 135 | Fully represented; not assigned to a production loadout |
| Leather head | STR 2; head TAL 1 versus Slashing; no printed MR/Dodge penalty | p. 135; existing approved head/neck mapping | Fully represented; not assigned to a production loadout |

`CombatWeaponDefinitionResource` records a `combat_ready` boundary and explicit blocked capabilities. A non-ready weapon cannot produce a `CombatAttackDefinition`; this prevents an unimplemented mandatory restriction from being silently activated. This is data validation, not a combat-engine rewrite.

## Task 24 hand occupancy

Weapon definitions now state whether their printed base use occupies one or two hands. For a two-handed weapon, the authoritative effective requirement is two hands from minimum STR through one below double STR, then one hand at `2 x listed STR` or higher. Strength below the listed minimum remains illegal. Battle Axe therefore resolves as 12-23 STR/two hands and 24+ STR/one hand; Great Sword as 10-19/two and 20+/one; Long Staff as 4-7/two and 8+/one under the locked Task 24 universal ruling. Short Rod remains one-handed at STR 4+.

Shield definitions separately record mounting type and weapon-hand occupancy. The Wood and Metal Buckler retain Prime's `2 Hands Free` chart fact and the approved Arena clarification models them as arm-mounted bucklers consuming zero weapon hands. A hand-held shield consumes one weapon hand. No production ordinary-shield resource was added; tests use an explicitly non-production hand-held shield fixture to verify the generic validator.

`CombatDefinitionCatalog` validates the complete authoritative equipment reference set against the actor's actual STR before actor registration. It rejects missing definitions, unmet STR, multiple primary weapons, multiple shields, repeated armor slots and weapon-plus-shield hand totals above the two-hand capacity. Great Sword and Long Staff can now create their existing attack definitions because the former occupancy gate is implemented. Their damage, reach, Block and critical properties are unchanged.

The Guard remains STR 16 with a two-handed Battle Axe. Its arm-mounted Metal Buckler consumes zero weapon hands, so the approved Battle Axe + Metal Buckler + Plate torso test loadout remains legal without inventing a STR 24 exception. Dynamic equipping, dual-wield combat and ordinary-shield production definitions remain outside this task.

No additional character template was added. `ITank_Arena_Aren_Valecrest_Character.pdf` is labelled an audit draft rather than an approved character source, so its values were not promoted to a combat definition.

## Combat connection

`PrimeV3VerticalSliceFixture` loads the catalog, validates the selected character and loadout, creates independent player/opponent actor definitions, and converts equipment resources into the existing `CombatAttackDefinition`, `CombatBlockDefinition`, and `CombatArmorDefinition` types. Registration, opening Initiative, AT, ACC, defenses, damage, criticals, movement, Running, prone, Stagger, final geometry and event processing remain unchanged.

The Task 22 regression builds one exchange from a frozen pre-migration constructor and one from the resource-backed fixture using the same seed, actor positions, declarations and effect timestamp. It compares authoritative event signatures and runtime actor states. Existing replay and two-client suites remain active.

## Opponent activation finding

The opponent driver is enabled while the scene is prepared but the encounter is inactive until START. START immediately runs the driver. Task 31E's controlling Option B ruling supersedes the former rank gate: every actor may independently declare a legal action regardless of opening rank, while INIT remains the ordering key for genuinely simultaneous effect events. There is no artificial real-time delay, priority window, or attack-triggered aggro rule.

## Battlefield rectangle finding

The right gray rectangle is `center_wall`. It rejects movement and Dodge paths, blocks line of sight, affects pathfinding and can prevent final attack legality. It adds no cover or ACC modifier.

The left brown/orange rectangle is `non_damaging_test_hazard_zone`. It is walkable, does not block line of sight, adds no MR or movement cost, supplies no cover or ACC modifier, and causes no damage. Its only authoritative effect is hazard tier 1 for automatic Dodge destination preference. Ordinary pathfinding does not treat it as difficult terrain. The scene now labels it `WALKABLE DODGE TEST` and labels the gray rectangle `WALL` so presentation matches authority.

## Safe extension procedure

Add a new resource with a unique stable ID and exact source references, then register it in a catalog. Do not add a loadout until every referenced definition exists and its verified requirements can be validated. Missing values remain explicit verification issues; unsupported mechanics remain not-yet-implemented gates. Never substitute a generic slot, proficiency, penalty or attribute formula.
