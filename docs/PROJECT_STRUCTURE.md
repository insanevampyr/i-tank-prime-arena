# Project Structure

This Phase 0 layout keeps the deterministic rules simulation separate from presentation and input.

- `assets/art` and `assets/audio`: source-controlled game assets and their provenance records.
- `data/characters`: future data-driven character definitions.
- `data/creatures`: future data-driven creature definitions.
- `docs/rules`: the source-of-truth rules ledger and later rule-audit evidence.
- `docs/architecture`: boundaries and migration paths for authoritative systems.
- `docs/platform`: platform feasibility findings and export requirements.
- `scenes`: Godot scenes. Phase 0 contains only the temporary test arena.
- `scripts/combat`: deterministic, presentation-independent combat timing and event primitives.
- `scripts/characters` and `scripts/creatures`: future runtime adapters for data definitions.
- `scripts/player`: temporary local input and movement used by the test scene.
- `scripts/sync`: transport-free authoritative event envelopes, observers, and state comparison.
- `scripts/ui`: future UI controllers.
- `tests`: dependency-free headless regression tests.
- `ui`: future UI scenes, themes, and resources.

No combat rule belongs in a scene, input handler, renderer, or UI controller. Authoritative simulation code must remain usable without a display or local player input.
