class_name Task36CInventoryEquipmentConsumableTests
extends RefCounted

const Session = preload("res://scripts/combat/arena_combat_session.gd")
const Battlefield = preload("res://scripts/combat/arena_battlefield.gd")
const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
const Ledger = preload("res://scripts/rewards/arena_reward_ledger.gd")
const InventoryCatalog = preload("res://scripts/rewards/prime_v3_inventory_catalog.gd")
const Digest = preload("res://scripts/sync/sync_state_digest.gd")
const TwoClientSyncHarness = preload("res://scripts/sync/two_client_sync_harness.gd")

var _failures: Array[String] = []


func run() -> Array[String]:
	_failures.clear()
	_test_inventory_inspection_and_fail_closed_items()
	_test_transactional_weapon_and_armor_management()
	_test_consumables_exactly_once_and_reset_boundaries()
	_test_deterministic_snapshot_and_ui()
	return _failures


func _test_inventory_inspection_and_fail_closed_items() -> void:
	var session := _make_downtime_session(36_301)
	var state := session.get_actor_state(Fixture.PLAYER_ID)
	state.inventory_quantities["prime_v3_hades_follower_short_sword"] = 1
	state.inventory_quantities["prime_v3_random_weapon"] = 1
	state.inventory_quantities["prime_v3_potion_06"] = 1
	var entries := session.get_player_inventory_entries()
	var sword := _find(entries, "prime_v3_hades_follower_short_sword")
	_expect_equal(sword.get("category"), "weapon", "Exact collected equipment must expose its verified category.")
	_expect_true(sword.get("equipable", false), "The source-defined Short Sword must be equipable.")
	var abstract_drop := _find(entries, "prime_v3_random_weapon")
	_expect_equal(abstract_drop.get("blocked_reason"), "item_definition_incomplete", "Abstract Random Drop results must remain visible and fail closed.")
	_expect_equal(session.request_player_inventory_equip(&"prime_v3_random_weapon", "36c:unsupported").get("reason"), "item_definition_incomplete", "Incomplete equipment must not mutate the loadout.")
	var potion := _find(entries, "prime_v3_potion_06")
	_expect_true(potion.get("usable", false), "A source-identified Health Potion must expose its verified use.")


func _test_transactional_weapon_and_armor_management() -> void:
	var session := _make_downtime_session(36_302)
	var state := session.get_actor_state(Fixture.PLAYER_ID)
	var actor := session.simulation.get_actor_definition(Fixture.PLAYER_ID)
	state.inventory_quantities["prime_v3_hades_follower_short_sword"] = 1
	state.inventory_quantities["prime_v3_leather_torso"] = 1
	state.inventory_quantities["prime_v3_wood_buckler"] = 1
	var hpc_before: Variant = state.current_hpc
	var conditions_before := state.conditions.duplicate()
	var equip := session.request_player_inventory_equip(&"prime_v3_hades_follower_short_sword", "36c:equip:sword")
	_expect_true(equip.get("success", false), "A legal exact weapon replacement must commit atomically.")
	_expect_true(state.equipment_refs.has("prime_v3_hades_follower_short_sword"), "The Short Sword must become authoritative equipment.")
	_expect_true(not state.equipment_refs.has(String(Fixture.WEAPON_REF)), "The replaced two-hand Battle Axe must leave the equipped set.")
	_expect_equal(state.inventory_quantities.get(String(Fixture.WEAPON_REF)), 1, "Replaced equipment must return to inventory exactly once.")
	_expect_equal(state.inventory_quantities.get("prime_v3_hades_follower_short_sword"), 0, "Equipping must consume one carried instance.")
	_expect_equal(state.current_hpc, hpc_before, "Equipment changes must not heal HPC.")
	_expect_equal(state.conditions, conditions_before, "Equipment changes must preserve conditions.")
	_expect_equal(session.get_player_primary_weapon_display_name(), "SHORT SWORD", "The player-facing primary weapon must reflect the active attack definition.")
	var duplicate_digest := Digest.compute(session.get_state_snapshot())
	_expect_equal(session.request_player_inventory_equip(&"prime_v3_hades_follower_short_sword", "36c:equip:sword").get("reason"), "item_already_equipped", "An already equipped item must not consume another instance.")
	_expect_equal(Digest.compute(session.get_state_snapshot()), duplicate_digest, "Rejected equipment requests must be atomic.")

	var mr_with_plate := int(actor.get_combat_stat("mr"))
	var armor := session.request_player_inventory_equip(&"prime_v3_leather_torso", "36c:equip:armor")
	_expect_true(armor.get("success", false), "Legal same-slot armor replacement must succeed.")
	_expect_true(state.equipment_refs.has("prime_v3_leather_torso"), "Leather torso must replace plate torso in the same slot.")
	_expect_true(not state.equipment_refs.has(String(Fixture.ARMOR_REF)), "Unrelated torso TAL must not remain equipped or stack.")
	_expect_true(int(actor.get_combat_stat("mr")) >= mr_with_plate, "Removing Plate's verified MR penalty must recalculate effective MR from baseline.")
	_expect_equal(state.inventory_quantities.get(String(Fixture.ARMOR_REF)), 1, "Replaced Plate must remain uniquely owned in inventory.")
	var unequip := session.request_player_inventory_unequip(&"prime_v3_leather_torso", "36c:unequip:armor")
	_expect_true(unequip.get("success", false), "Verified armor may be unequipped during untimed downtime.")
	_expect_equal(state.inventory_quantities.get("prime_v3_leather_torso"), 1, "Unequip must return exactly one armor instance.")
	var shield := session.request_player_inventory_equip(&"prime_v3_wood_buckler", "36c:equip:shield")
	_expect_true(shield.get("success", false), "A verified arm-mounted buckler must remain compatible with the one-hand weapon.")
	_expect_true(state.equipment_refs.has("prime_v3_wood_buckler"), "The replacement shield must enter the authoritative equipped set.")
	var shield_block := session.simulation.get_defense_profile(Fixture.PLAYER_ID).shield_block
	shield_block.current_shp = 1
	_expect_equal(session.request_player_inventory_unequip(&"prime_v3_wood_buckler", "36c:damaged:shield").get("reason"), "damaged_shield_instance_storage_not_supported", "Quantity-only storage must not refill a damaged shield on re-equip.")

	var vaelis_session := _make_downtime_session(36_306, Ledger.MODE_NORMAL, Fixture.PLAYER_CHARACTER_VAELIS)
	var vaelis_state := vaelis_session.get_actor_state(Fixture.PLAYER_ID)
	vaelis_state.inventory_quantities["prime_v3_rare_human_warrior_boar_spear"] = 1
	var invalid := vaelis_session.request_player_inventory_equip(&"prime_v3_rare_human_warrior_boar_spear", "36c:equip:strength")
	_expect_equal(invalid.get("reason"), "equipment_strength_requirement_not_met", "STR requirements must fail before any partial equipment mutation.")
	_expect_true(vaelis_state.equipment_refs.has(String(Fixture.VAELIS_WEAPON_REF)), "A failed replacement must preserve prior equipment.")
	_expect_true(session.request_next_wave().get("success", false), "One explicit NEXT WAVE must advance after inventory management.")
	_expect_true(session.get_actor_state(Fixture.PLAYER_ID).equipment_refs.has("prime_v3_hades_follower_short_sword"), "Accepted equipment must persist into the next wave.")
	_expect_equal(session.get_actor_state(Fixture.PLAYER_ID).inventory_quantities.get("prime_v3_wood_buckler", 0), 0, "Equipped item quantities must remain consumed across NEXT WAVE.")


func _test_consumables_exactly_once_and_reset_boundaries() -> void:
	var session := _make_downtime_session(36_303)
	var state := session.get_actor_state(Fixture.PLAYER_ID)
	state.inventory_quantities["prime_v3_hades_follower_short_sword"] = 1
	_expect_true(session.request_player_inventory_equip(&"prime_v3_hades_follower_short_sword", "36c:freehand").get("success", false), "The fixture requires one verified free hand.")
	state.inventory_quantities["prime_v3_potion_06"] = 2
	state.current_hpc = 2
	var first := session.request_player_inventory_consumable_use(&"prime_v3_potion_06", "36c:potion:once")
	_expect_true(first.get("success", false), "The printed Health Potion must resolve in downtime.")
	_expect_equal(state.inventory_quantities.get("prime_v3_potion_06"), 1, "Successful use must consume exactly one potion.")
	var hpc_after: Variant = state.current_hpc
	var duplicate := session.request_player_inventory_consumable_use(&"prime_v3_potion_06", "36c:potion:once")
	_expect_equal(duplicate.get("reason"), "duplicate_request", "Repeated delivery must not consume twice.")
	_expect_equal(state.current_hpc, hpc_after, "Duplicate use must not reapply healing.")
	_expect_equal(state.inventory_quantities.get("prime_v3_potion_06"), 1, "Duplicate use must preserve quantity.")
	state.inventory_quantities["prime_v3_potion_12"] = 1
	_expect_equal(session.request_player_inventory_consumable_use(&"prime_v3_potion_12", "36c:mana").get("reason"), "consumable_effect_target_unavailable", "Mana Potion must fail closed for a character without Mana.")
	_expect_equal(session.request_player_inventory_consumable_use(&"prime_v3_potion_07", "36c:unknown").get("reason"), "consumable_effect_unverified", "Other potion identities must not inherit a generic effect.")
	var vaelis := _make_downtime_session(36_308, Ledger.MODE_NORMAL, Fixture.PLAYER_CHARACTER_VAELIS)
	var vaelis_state := vaelis.get_actor_state(Fixture.PLAYER_ID)
	_expect_true(vaelis.request_player_inventory_unequip(Fixture.VAELIS_WAND_REF, "36c:vaelis:freehand").get("success", false), "Vaelis may unequip one of two legal weapons to free a hand.")
	vaelis_state.resources["mana"] = 1
	vaelis_state.inventory_quantities["prime_v3_potion_12"] = 1
	var mana_use := vaelis.request_player_inventory_consumable_use(&"prime_v3_potion_12", "36c:mana:use")
	_expect_true(mana_use.get("success", false), "The printed Mana Potion must restore a character with an authoritative Mana pool.")
	_expect_equal(vaelis_state.inventory_quantities.get("prime_v3_potion_12"), 0, "Mana Potion use must decrement the identified quantity exactly once.")
	_expect_true(int(vaelis_state.resources.get("mana", 0)) > 1, "Mana Potion must update authoritative Mana rather than HPC.")

	var test_session := _make_downtime_session(36_304, Ledger.MODE_TEST)
	test_session.get_actor_state(Fixture.PLAYER_ID).inventory_quantities["prime_v3_potion_06"] = 1
	_expect_equal(test_session.request_player_inventory_consumable_use(&"prime_v3_potion_06", "36c:test").get("reason"), "test_mode_inventory_management_prohibited", "TEST MODE inventory mutations must remain isolated.")
	_expect_true(session.reset_encounter(false).get("success", false), "RESET must reconstruct the original run fixture.")
	_expect_equal(session.get_actor_state(Fixture.PLAYER_ID).inventory_quantities.get("prime_v3_potion_06", 0), 0, "RESET must remove temporary collected and consumed inventory state.")


func _test_deterministic_snapshot_and_ui() -> void:
	var first := _make_downtime_session(36_305)
	var second := _make_downtime_session(36_305)
	for session: ArenaCombatSession in [first, second]:
		var state := session.get_actor_state(Fixture.PLAYER_ID)
		state.inventory_quantities["prime_v3_hades_follower_short_sword"] = 1
		state.inventory_quantities["prime_v3_potion_06"] = 1
		state.current_hpc = 1
		_expect_true(session.request_player_inventory_equip(&"prime_v3_hades_follower_short_sword", "36c:det:equip").get("success", false), "Deterministic equipment transaction must succeed.")
		_expect_true(session.request_player_inventory_consumable_use(&"prime_v3_potion_06", "36c:det:use").get("success", false), "Deterministic consumable transaction must succeed.")
	_expect_equal(first.get_state_snapshot(), second.get_state_snapshot(), "Same-seed inventory operations must preserve complete snapshot equivalence.")
	_expect_equal(first.get_state_snapshot().get("schema_version"), 12, "Inventory management must preserve schema-12 compatibility.")
	var harness := TwoClientSyncHarness.new(36_307)
	var sync_session := _make_downtime_session_with_simulation(36_307, harness.authority.simulation)
	var sync_state := sync_session.get_actor_state(Fixture.PLAYER_ID)
	sync_state.inventory_quantities["prime_v3_hades_follower_short_sword"] = 1
	_expect_true(sync_session.request_player_inventory_equip(&"prime_v3_hades_follower_short_sword", "36c:sync:equip").get("success", false), "The synchronized equipment transaction must succeed.")
	var authoritative_snapshot := harness.authority.simulation.get_state_snapshot()
	harness.deliver_in_order(harness.authority.publish_current_events())
	_expect_true(harness.compare_clients().get("success", false), "Both simulated clients must converge after inventory/equipment events.")
	_expect_equal(harness.client_a.get_state_snapshot(), authoritative_snapshot, "The complete authoritative inventory snapshot must replicate.")

	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		_failures.append("SceneTree unavailable for Task 36C inventory UI coverage.")
		return
	var scene := (load("res://scenes/test_arena.tscn") as PackedScene).instantiate()
	tree.root.add_child(scene)
	var controller := scene.get_node("CombatController") as ArenaCombatController
	controller.press_encounter_control_for_testing()
	var ui_session := controller.get_combat_session_for_testing()
	_complete_current_wave(ui_session)
	ui_session.get_actor_state(Fixture.PLAYER_ID).inventory_quantities["prime_v3_potion_06"] = 1
	controller.update_presentation_for_testing()
	_expect_true(controller.get_rewards_panel_text_for_testing().contains("INVENTORY / EQUIPMENT"), "Downtime HUD must expose the inventory section.")
	_expect_true(controller.get_inventory_option_count_for_testing() > 0, "Downtime HUD must expose authoritative inventory entries.")
	tree.root.remove_child(scene)
	scene.free()


func _make_downtime_session(seed: int, mode: String = Ledger.MODE_NORMAL, player_character: StringName = Fixture.PLAYER_CHARACTER_GUARD) -> ArenaCombatSession:
	return _make_downtime_session_with_simulation(seed, null, mode, player_character)


func _make_downtime_session_with_simulation(seed: int, external_simulation: CombatSimulation, mode: String = Ledger.MODE_NORMAL, player_character: StringName = Fixture.PLAYER_CHARACTER_GUARD) -> ArenaCombatSession:
	var session := Session.new(seed, external_simulation, Fixture.ENCOUNTER_WAVE_ONE_GOBLINS, player_character)
	session.configure_battlefield(Battlefield.create_task16_test_arena())
	session.set_opponent_behavior_enabled(false)
	session.initialize_wave_one_goblins(Vector2i(20_000_000, 12_000_000), Vector2i(24_000_000, 12_000_000), false)
	session.configure_reward_mode(mode)
	session.start_encounter()
	_complete_current_wave(session)
	return session


func _complete_current_wave(session: ArenaCombatSession) -> void:
	for actor_id: String in session.get_targetable_enemy_ids():
		session.get_actor_state(StringName(actor_id)).current_hpc = 0
	session.advance_by(1)


func _find(entries: Array[Dictionary], definition_id: String) -> Dictionary:
	for entry: Dictionary in entries:
		if String(entry.get("definition_id", "")) == definition_id:
			return entry
	return {}


func _expect_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s Expected %s, got %s." % [message, expected, actual])
