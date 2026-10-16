# Equipment Data

Each `.tres` resource is permanent source data, not mutable equipped state. `CombatDefinitionCatalog` validates IDs, provenance, numeric fields and source-supported requirements before a resource can be used in a loadout.

Task 23 additions are intentionally small: Short Rod, Great Sword, Long Staff, Wood Buckler, Leather torso and Leather head. Great Sword and Long Staff remain registered but not combat-ready because the current authoritative model has no hand-occupancy enforcement. See `docs/architecture/CHARACTER_EQUIPMENT_FOUNDATION.md` for source pages, readiness status and safe extension rules.
