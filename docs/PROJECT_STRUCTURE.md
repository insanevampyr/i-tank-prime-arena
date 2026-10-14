# Project Structure

This layout keeps deterministic rules and canonical movement separate from presentation and input.

- `assets/art` and `assets/audio`: source-controlled game assets and their provenance records.
- `data/characters`: future data-driven character definitions.
- `data/creatures`: future data-driven creature definitions.
- `docs/rules`: the source-of-truth rules ledger and later rule-audit evidence.
- `docs/architecture`: boundaries and migration paths for authoritative systems.
- `docs/platform`: platform feasibility findings and export requirements.
- `scenes`: Godot scenes. Phase 0 contains only the temporary test arena.
- `scripts/combat`: deterministic, presentation-independent combat timing, actor state, action lifecycle, opening Initiative, physical ACC/defense/damage transactions, source-driven armor and protection profiles, authority-supplied Dodge environments, attack-specific duck eligibility and event primitives. Missing Prime, multiplier and environment facts remain explicit unresolved fields.
- `scripts/characters` and `scripts/creatures`: future runtime adapters for data definitions.
- `scripts/movement`: verified Running Skill calculation plus canonical feet/MR, maintenance, duration, recovery and cooldown state independent of rendering and input.
- `scripts/player`: temporary WASD/Shift input and feet-to-pixels presentation adapter used by the test scene.
- `scripts/sync`: transport-free authoritative event/state-snapshot envelopes, observers, and state comparison.
- `scripts/ui`: future UI controllers.
- `tests`: dependency-free headless regression tests.
- `ui`: future UI scenes, themes, and resources.

No combat rule belongs in a scene, input handler, renderer, or UI controller. Authoritative simulation code must remain usable without a display or local player input.
