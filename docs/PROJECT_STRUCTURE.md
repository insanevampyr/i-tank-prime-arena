# Project Structure

This layout keeps deterministic rules and canonical movement separate from presentation and input.

- `assets/art` and `assets/audio`: source-controlled game assets and their provenance records.
- `data/characters`: future data-driven character definitions.
- `data/creatures`: future data-driven creature definitions.
- `docs/rules`: the source-of-truth rules ledger and later rule-audit evidence.
- `docs/architecture`: boundaries and migration paths for authoritative systems.
- `docs/platform`: platform feasibility findings and export requirements.
- `scenes`: Godot scenes. Phase 0 contains only the temporary test arena.
- `scripts/combat`: deterministic, presentation-independent combat timing, actor state, action lifecycle, opening Initiative, physical ACC/defense/damage transactions, source-driven armor and protection profiles, authoritative battlefield geometry, Dodge environments, attack-specific duck eligibility and event primitives. Tasks 14-16 use one source-labeled fixture and combat-session adapter for player and scripted-opponent intents; they do not form a second engine.
- `scripts/characters` and `scripts/creatures`: future runtime adapters for data definitions.
- `scripts/movement`: verified Running Skill calculation plus canonical feet/MR, maintenance, duration, recovery and cooldown state independent of rendering and input.
- `scripts/input`: presentation-only input intent composition shared by desktop and touch controls; it contains no movement or combat rules.
- `scripts/player`: temporary WASD/Shift plus touch-intent adapter and feet-to-pixels presentation adapter used by the test scene.
- `scripts/sync`: transport-free authoritative event/state-snapshot envelopes, observers, and state comparison.
- `scripts/ui`: responsive test-scene layout, multitouch controls, code-drawn battlefield presentation, authoritative event presentation and the thin playable-scene controller. The verified fixture exposes target, movement/Running, ordinary attack/stand, and START/RESET controls only.
- `tests`: dependency-free headless regression tests.
- `ui`: future UI scenes, themes, and resources.

No combat rule belongs in a scene, input handler, renderer, or UI controller. Authoritative simulation code must remain usable without a display or local player input.
