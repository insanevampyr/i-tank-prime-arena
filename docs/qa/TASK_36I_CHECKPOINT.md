# Task 36I checkpoint and deferred browser QA

Owner authorized the #36I / Fix1 / Fix2 / Fix3 checkpoint and push without browser acceptance on 29 October 2026. This is not browser acceptance.

## Browser QA status

Each check below is **NOT TESTED — DEFERRED BY OWNER** for this checkpoint:

- Hold right-click: exactly one NAC attempt.
- Five distinct rapid right-clicks: five legal NAC attempts, costing 10 Mana.
- NAC during sword attack: no interruption.
- Wave 1 and Wave 2: automatic rewards display.
- DEV NORMAL refresh during downtime on both waves.
- NEXT WAVE closes rewards and preserves progression.

Automated input, simulation and geometry tests do not substitute for these browser checks. Permanent gameplay persistence, NEW RUN and graphics are not enabled by this checkpoint.

## Scope and audit

The last committed baseline was 0afbe2bf1683e7497e0add7d67c2eba56246aa71 on main. The checkpoint includes previously approved uncommitted #36A-H reward, inventory, progression, isolated-storage and shared-weapon dependencies used by #36I and its tests. It is not an isolated UI-only diff against that older baseline. The storage infrastructure remains disconnected from permanent gameplay saving. No unrelated project modifications were identified in the reviewed source/test/document paths.

Protected tmp/, boss source DOC and Word lock files are excluded. Generated Web exports, caches, remote attachments and machine-local files are excluded. Godot script .uid files are intentional project identity metadata, not exported build artifacts. No credential patterns were found in the reviewed data/docs/scripts/tests paths.

## Validation

Fresh checkpoint validation on Godot 4.7.2 completed successfully:

- `--headless --path . --script res://tests/test_runner.gd`: all 62 registered suites passed, exit 0. No ObjectDB leak or retained-resource warnings were reported.
- `--headless --editor --path . --quit`: import/editor validation, exit 0.
- `--headless --path . --quit-after 3`: main-scene startup, exit 0.
- `--headless --path . --export-release Web builds/web/index.html`: Single-Threaded release export, exit 0. Required HTML/JS/WASM/PCK artifacts are nonempty. No forbidden standalone documentation/source artifacts, symlinks or root-absolute HTML asset paths were found in the export.
- `git diff --check` and `git diff --cached --check`: passed. Staged audit exposed redundant blank EOF lines in four previously untracked dependency files; only those whitespace lines were removed, with no semantic changes.

The generated Web output remains ignored and is not part of this commit. Deployment configuration is unchanged. These automated results do not change any browser QA status above.

## Exact checkpoint file manifest

- `data/characters/vaelis_thorn.tres`
- `data/equipment/weapons/prime_v3_short_sword.tres`
- `data/equipment/weapons/prime_v3_short_wand.tres`
- `docs/architecture/CHARACTER_PERSISTENCE_CONTRACT.md`
- `docs/architecture/CHARACTER_STORAGE_INFRASTRUCTURE.md`
- `docs/architecture/FIVE_WAVE_ENCOUNTER_FRAMEWORK.md`
- `docs/architecture/PLAYABLE_COMBAT_VERTICAL_SLICE.md`
- `docs/architecture/REWARDS_AND_ADVANCEMENT_FOUNDATION.md`
- `docs/architecture/TASK_36F_REWARDS_USABILITY.md`
- `docs/qa/TASK_36I_CHECKPOINT.md`
- `docs/rules/RULES_LEDGER.md`
- `scripts/combat/arena_combat_session.gd`
- `scripts/combat/combat_actor_definition.gd`
- `scripts/combat/combat_actor_state.gd`
- `scripts/combat/combat_simulation.gd`
- `scripts/combat/combat_weapon_handling.gd`
- `scripts/combat/combat_weapon_handling.gd.uid`
- `scripts/combat/prime_v3_vertical_slice_fixture.gd`
- `scripts/creatures/rare_human_warrior_boss_ai.gd`
- `scripts/creatures/rare_human_warrior_fixture.gd`
- `scripts/data/combat_character_definition_resource.gd`
- `scripts/player/placeholder_player.gd`
- `scripts/rewards/arena_reward_ledger.gd`
- `scripts/rewards/arena_reward_ledger.gd.uid`
- `scripts/rewards/character_level_progression.gd`
- `scripts/rewards/character_level_progression.gd.uid`
- `scripts/rewards/character_save_contract.gd`
- `scripts/rewards/character_save_contract.gd.uid`
- `scripts/rewards/character_save_storage.gd`
- `scripts/rewards/character_save_storage.gd.uid`
- `scripts/rewards/prime_v3_advancement_catalog.gd`
- `scripts/rewards/prime_v3_advancement_catalog.gd.uid`
- `scripts/rewards/prime_v3_inventory_catalog.gd`
- `scripts/rewards/prime_v3_inventory_catalog.gd.uid`
- `scripts/rewards/prime_v3_level_catalog.gd`
- `scripts/rewards/prime_v3_level_catalog.gd.uid`
- `scripts/rewards/prime_v3_random_drop_resolver.gd`
- `scripts/rewards/prime_v3_random_drop_resolver.gd.uid`
- `scripts/rewards/prime_v3_reward_catalog.gd`
- `scripts/rewards/prime_v3_reward_catalog.gd.uid`
- `scripts/ui/arena_combat_controller.gd`
- `scripts/ui/arena_combat_event_presenter.gd`
- `scripts/ui/arena_responsive_layout.gd`
- `tests/test_combat_readiness_hud.gd`
- `tests/test_runner.gd`
- `tests/test_task_35g_rare_human_warrior_potions_and_combat.gd`
- `tests/test_task_35h_rare_human_warrior_boss_ai.gd`
- `tests/test_task_36a_rewards_and_loot.gd`
- `tests/test_task_36a_rewards_and_loot.gd.uid`
- `tests/test_task_36b_character_advancement.gd`
- `tests/test_task_36b_character_advancement.gd.uid`
- `tests/test_task_36c_inventory_equipment_consumables.gd`
- `tests/test_task_36c_inventory_equipment_consumables.gd.uid`
- `tests/test_task_36d_character_save_contract.gd`
- `tests/test_task_36d_character_save_contract.gd.uid`
- `tests/test_task_36e_character_storage.gd`
- `tests/test_task_36e_character_storage.gd.uid`
- `tests/test_task_36f_rewards_usability.gd`
- `tests/test_task_36f_rewards_usability.gd.uid`
- `tests/test_task_36g_fix2_weapon_handling.gd`
- `tests/test_task_36g_fix2_weapon_handling.gd.uid`
- `tests/test_task_36g_xp_and_potions.gd`
- `tests/test_task_36g_xp_and_potions.gd.uid`
- `tests/test_task_36h_character_leveling.gd`
- `tests/test_task_36h_character_leveling.gd.uid`
- `tests/test_task_36h_fix1_playtest.gd`
- `tests/test_task_36h_fix1_playtest.gd.uid`
- `tests/test_task_36i_fix3_nac_input.gd`
- `tests/test_task_36i_fix3_nac_input.gd.uid`
- `tests/test_task_36i_ui_cleanup.gd`
- `tests/test_task_36i_ui_cleanup.gd.uid`
