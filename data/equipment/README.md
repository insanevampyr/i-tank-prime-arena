# Equipment Data

Each `.tres` resource is permanent source data, not mutable equipped state. `CombatDefinitionCatalog` validates IDs, provenance, numeric fields and source-supported requirements before a resource can be used in a loadout.

Task 23 additions are intentionally small: Short Rod, Great Sword, Long Staff, Wood Buckler, Leather torso and Leather head. Task 24 adds explicit weapon hand requirements and shield mounting/occupancy. Great Sword and Long Staff are combat-ready after validation of minimum STR and the universal double-STR rule; neither is assigned to a production loadout. Wood and Metal Bucklers are arm-mounted and consume zero weapon hands while retaining their printed `2 Hands Free` evidence.

Every future weapon must state its base hand requirement. Every future shield must distinguish arm-mounted from hand-held use and state its hand occupancy. Do not infer an ordinary shield's mounting or occupancy from buckler data. See `docs/architecture/CHARACTER_EQUIPMENT_FOUNDATION.md` for source pages, validation behavior and safe extension rules.

Task 25 separates armor penalties into `mr_penalty`, `dt_penalty`, and `projectile_dodge_penalty`. Fixed Armor Chart values are zero or negative integers and stack additively across distinct equipped armor slots. Use `unresolved_penalty_fields` for a printed variable `V`; never encode `V` as zero. Catalog actor construction fails closed until every equipped variable component is verified.
