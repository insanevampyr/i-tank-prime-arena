extends RefCounted

const WEAPON := &"prime_v3_long_staff"
const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
const BossTests = preload("res://tests/test_task_35h_rare_human_warrior_boss_ai.gd")
const Boss = preload("res://scripts/creatures/rare_human_warrior_fixture.gd")
var _failures: Array[String] = []


func run() -> Array[String]:
	_test_free_handling_and_ownership()
	_test_draw_timing_and_interruptions()
	for role: StringName in [&"player", &"npc"]:
		for at in [1, 2]:
			_test_potions(role, at, false)
			_test_potions(role, at, true)
	_test_boss_integration()
	_test_wave_continuity_and_reset()
	_test_player_controls()
	_expect(_replay() == _replay(), "Same-seed handling, potion, events and RNG must replay exactly.")
	return _failures


func _setup(role: StringName = &"player", at: int = 2) -> CombatSimulation:
	var sim := CombatSimulation.new(3672)
	# Explicit synthetic fixture: real catalog equipment, not a printed character.
	var actor := CombatActorDefinition.new(&"subject", role, "Generic handling fixture",
		{"str": 5, "end": 10, "spd": 10, "dex": 10, "wis": 10, "int": 10, "wit": 10, "man": 10, "luk": 10, "app": 10},
		{"hpm": 50, "at": at, "acc": 12, "init": 5, "mr": 10, "nal": 0, "dt": 5, "dp": 5, "physical_soak": 0, "sb": 0},
		{}, PackedStringArray([String(WEAPON)]), {}, {}, PackedStringArray(), &"medium", {}, {"health_potion": {"quantity": 2}})
	sim.register_actor(actor)
	sim.register_actor(CombatActorDefinition.new(&"target", &"npc", "Synthetic target", actor.attributes,
		{"hpm": 50, "at": 1, "acc": 10, "init": 1, "mr": 10, "nal": 0, "dt": 0, "dp": 0, "physical_soak": 0}, {}, PackedStringArray(), {}, {}, PackedStringArray(), &"medium"))
	sim.configure_actor_hand_occupancy(&"subject", {"left": String(WEAPON), "right": String(WEAPON)})
	sim.get_actor_state(&"target").position_microfeet = Vector2i(3_000_000, 0)
	sim.begin_combat()
	return sim


func _test_free_handling_and_ownership() -> void:
	for role: StringName in [&"player", &"npc"]:
		var sim := _setup(role)
		var state := sim.get_actor_state(&"subject")
		var before_items := state.inventory_quantities.duplicate(true)
		var before_refs := state.equipment_refs.duplicate()
		var before_rng := sim.random.get_draw_count()
		var block := CombatBlockDefinition.new(CombatBlockDefinition.TYPE_WEAPON, WEAPON, 2, 0, true)
		_expect(sim._evaluate_block_eligibility(state, block, CombatDefenseProfile.WEAPON_BLOCK, 0).eligible, "Ready weapon may Block.")
		_expect(sim.request_weapon_handling(&"subject", WEAPON, "hold_one", "hold").get("success", false), "Either controller may hold a two-handed weapon in one hand.")
		_expect(state.hand_occupancy.right == String(WEAPON) and state.hand_occupancy.left == "", "Holding must free exactly one real hand.")
		var attack := CombatDefinitionCatalog.load_default_fixture_catalog().get_weapon(WEAPON).make_attack_definition(&"handling_attack") as CombatAttackDefinition
		_expect(sim.start_physical_attack(&"subject", &"target", attack, "held_attack", &"torso", true).get("reason") == "weapon_grip_not_ready", "Holding is not a legal two-handed attack grip.")
		_expect(not sim._evaluate_block_eligibility(state, block, CombatDefenseProfile.WEAPON_BLOCK, 0).eligible, "Holding cannot grant weapon Block.")
		var unchanged := sim.get_state_snapshot()
		_expect(not sim.request_weapon_handling(&"subject", WEAPON, "hold_one", "hold").get("success", false) and sim.get_state_snapshot() == unchanged, "Duplicate transitions must be rejected atomically.")
		state.hand_occupancy.left = "prime_v3_wood_buckler" # Adversarial authoritative occupancy fixture.
		unchanged = sim.get_state_snapshot()
		_expect(not sim.request_weapon_handling(&"subject", WEAPON, "regrip", "shield_blocked").get("success", false) and sim.get_state_snapshot() == unchanged, "Re-grip must not evict a shield or other held object.")
		state.hand_occupancy.left = ""
		_expect(sim.request_weapon_handling(&"subject", WEAPON, "regrip", "regrip").get("success", false), "A held weapon can re-grip without drawing.")
		_expect(sim._evaluate_block_eligibility(state, block, CombatDefenseProfile.WEAPON_BLOCK, 0).eligible, "Re-grip restores legal Block.")
		_expect(sim.request_weapon_handling(&"subject", WEAPON, "stow", "stow").get("success", false), "Stowing is a legal free transition.")
		_expect(not sim._evaluate_block_eligibility(state, block, CombatDefenseProfile.WEAPON_BLOCK, 0).eligible, "Stowed weapons cannot Block.")
		_expect(state.hand_occupancy.left == "" and state.hand_occupancy.right == "", "Stowing releases occupied hands.")
		_expect(sim.get_world_items_snapshot().is_empty() and state.inventory_quantities == before_items and state.equipment_refs == before_refs, "Stowing preserves unique ownership and quantities, with no ground item.")
		_expect(sim.clock.get_elapsed_us() == 0 and sim.random.get_draw_count() == before_rng and state.current_action_instance_id == "", "Free transitions spend no time, Acts or RNG.")
		_expect(not sim.request_weapon_handling(&"subject", WEAPON, "regrip", "stowed_regrip").get("success", false), "Re-grip cannot draw a stowed weapon.")
		state.hand_occupancy_authoritative = false
		_expect(sim.request_weapon_handling(&"subject", WEAPON, "draw", "unknown_anatomy").get("reason") == "weapon_hand_anatomy_unresolved", "Unresolved anatomy must fail closed.")


func _test_draw_timing_and_interruptions() -> void:
	var sim := _setup()
	var state := sim.get_actor_state(&"subject")
	sim.request_weapon_handling(&"subject", WEAPON, "stow", "stow")
	var start := sim.request_weapon_handling(&"subject", WEAPON, "draw", "draw_interrupted")
	_expect(start.get("success", false), "Drawing a stowed weapon must schedule an ordinary action.")
	if not start.get("success", false): return
	var action := sim.get_action(start.action_instance_id)
	_expect(action.final_effect_due_at_us - action.started_at_us == 2_500_000, "Draw costs one full Act at AT 2.")
	sim.schedule_interruption(action.action_instance_id, 1_000_000, &"target", "test")
	sim.advance_to(action.final_effect_due_at_us)
	_expect(state.weapon_handling.get(String(WEAPON)) == CombatWeaponHandling.STOWED, "Interrupted draw leaves the weapon stowed.")
	start = sim.request_weapon_handling(&"subject", WEAPON, "draw", "draw_complete")
	_expect(start.get("success", false), "A subsequent draw request may succeed.")
	if not start.get("success", false): return
	action = sim.get_action(start.action_instance_id)
	sim.advance_to(action.final_effect_due_at_us - 1)
	_expect(not sim.is_weapon_attack_ready(&"subject", WEAPON), "Drawing does not restore readiness prematurely.")
	sim.advance_to(action.final_effect_due_at_us)
	_expect(sim.is_weapon_attack_ready(&"subject", WEAPON) and state.hand_occupancy.left == String(WEAPON) and state.hand_occupancy.right == String(WEAPON), "Completion restores both required hands and readiness.")
	sim.request_weapon_handling(&"subject", WEAPON, "stow", "stow_again")
	start = sim.request_weapon_handling(&"subject", WEAPON, "draw", "draw_invalid_completion")
	action = sim.get_action(start.action_instance_id)
	state.hand_occupancy.left = "material:dirt"
	sim.advance_to(action.final_effect_due_at_us)
	_expect(state.weapon_handling.get(String(WEAPON)) == CombatWeaponHandling.STOWED and state.hand_occupancy.left == "material:dirt", "Invalid draw completion cannot remove occupied items or equip prematurely.")


func _test_potions(role: StringName, at: int, interrupted: bool) -> void:
	var sim := _setup(role, at)
	var state := sim.get_actor_state(&"subject")
	state.current_hpc = 20
	sim.request_weapon_handling(&"subject", WEAPON, "hold_one", "potion_hold")
	var draws := sim.random.get_draw_count()
	var result := sim.start_verified_consumable_healing_action(&"subject", PrimeV3InventoryCatalog.make_carried_potion_action_definition("health_potion", &"generic_potion"), "potion")
	_expect(result.get("success", false), "Player and NPC must use potions while legally holding a two-handed weapon.")
	if not result.get("success", false): return
	var action := sim.get_action(result.action_instance_id)
	_expect(action.final_effect_due_at_us - action.started_at_us == 10_000_000 / at, "Potion use costs two Acts at the actor's actual AT.")
	var unchanged := sim.get_state_snapshot()
	_expect(not sim.request_weapon_handling(&"subject", WEAPON, "regrip", "busy_regrip").get("success", false) and sim.get_state_snapshot() == unchanged, "Free transitions cannot bypass an ongoing potion action.")
	if interrupted: sim.schedule_interruption(action.action_instance_id, action.started_at_us + 5_000_000 / at + 1, &"target", "test")
	sim.advance_to(action.final_effect_due_at_us - 1)
	_expect(state.current_hpc == 20 and state.inventory_quantities.health_potion == 2 and sim.random.get_draw_count() == draws, "No healing, consumption or RNG before full legal completion.")
	sim.advance_to(action.final_effect_due_at_us)
	_expect(state.inventory_quantities.health_potion == (2 if interrupted else 1), "Consumption is exactly once and only after uninterrupted completion.")
	_expect((state.current_hpc > 20) != interrupted and sim.random.get_draw_count() == draws + (0 if interrupted else 1), "Independent potion resolution preserves the shared effect and RNG policy.")
	_expect(sim.request_weapon_handling(&"subject", WEAPON, "regrip", "potion_regrip").get("success", false), "Both roles may legally re-grip after the potion action ends.")
	_expect(state.equipment_refs == PackedStringArray([String(WEAPON)]) and sim.get_world_items_snapshot().is_empty(), "Potion handling cannot drop or duplicate the retained weapon.")
	var harness := TwoClientSyncHarness.new(3672)
	harness.authority.simulation = sim
	harness.deliver_in_order(harness.authority.publish_current_events())
	_expect(harness.compare_clients().get("success", false) and harness.client_a.get_state_snapshot() == sim.get_state_snapshot(), "Handling and potion state must converge, including complete events.")
	_expect(sim.get_state_snapshot().schema_version == 12, "Handling extends schema 12 additively without replacing it.")


func _test_boss_integration() -> void:
	var helpers := BossTests.new()
	var setup := helpers._make_fixture(36721, Vector2i(8_000_000, 0), true)
	var sim: CombatSimulation = setup.simulation
	var state := sim.get_actor_state(setup.boss_id)
	helpers._exhaust_abilities(sim, setup.boss_id)
	state.current_hpc = 150
	var result: Dictionary = setup.ai.evaluate_and_submit()
	_expect(result.get("selected_action") == "health_potion" and result.get("action_started", false), "Armed injured boss must request shared hold and potion actions, not drop his spear.")
	if not result.get("action_started", false): return
	var action := sim.get_action(result.action_instance_id)
	_expect(state.weapon_handling.get(String(Boss.WEAPON_REF)) == CombatWeaponHandling.ONE_HAND_HOLD and state.equipment_refs.has(String(Boss.WEAPON_REF)), "Boss retains spear ownership while freeing one hand.")
	_expect(action.final_effect_due_at_us - action.started_at_us == 5_000_000, "Actual AI potion uses two Acts at AT 2.")
	sim.advance_to(action.final_effect_due_at_us)
	state.current_hpc = 200 # Isolate post-potion offensive decision from a second justified heal.
	var target := sim.get_actor_state(setup.target_id)
	target.position_microfeet = state.position_microfeet + Vector2i(5_000_000, 0)
	result = setup.ai.evaluate_and_submit()
	_expect(result.get("selected_action") == "spear_melee" and not state.weapon_handling.has(String(Boss.WEAPON_REF)), "AI re-grips through the shared engine and resumes legal spear melee.")
	_expect(state.inventory_quantities.health_potion == 1 and sim.get_world_items_snapshot().is_empty(), "AI consumes one potion without creating a dropped spear.")
	_expect(helpers._failures.is_empty(), "Reused boss integration setup must be valid.")


func _test_wave_continuity_and_reset() -> void:
	var session := ArenaCombatSession.new(36722, null, Fixture.ENCOUNTER_WAVE_ONE_GOBLINS)
	session.initialize_wave_one_goblins(Vector2i(20_000_000,12_000_000), Vector2i(24_000_000,12_000_000), true)
	session.set_opponent_behavior_enabled(false)
	var weapon_ref := Fixture.WEAPON_REF
	_expect(session.request_player_weapon_handling(weapon_ref, "stow").get("success", false), "Player stowing must use the shared request path.")
	for enemy_id: String in session.get_targetable_enemy_ids(): session.get_actor_state(StringName(enemy_id)).current_hpc = 0
	session.advance_by(1)
	_expect(session.request_next_wave().get("success", false), "The next wave must remain functional.")
	_expect(session.get_actor_state(&"player").weapon_handling.get(String(weapon_ref)) == CombatWeaponHandling.STOWED, "NEXT WAVE preserves stowed ownership and hand state.")
	session.reset_encounter(false)
	_expect(session.get_actor_state(&"player").weapon_handling.is_empty(), "RESET restores the original held/equipped fixture.")


func _test_player_controls() -> void:
	var scene := (load("res://scenes/test_arena.tscn") as PackedScene).instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	var controller := scene.get_node("CombatController") as ArenaCombatController
	controller.press_encounter_control_for_testing()
	var session := controller.get_combat_session_for_testing()
	session.set_opponent_behavior_enabled(false)
	scene.get_node("HUD/UI/CombatInventory").emit_signal("pressed")
	for index in range(controller._inventory_entries.size()):
		if controller._inventory_entries[index].definition_id == String(Fixture.WEAPON_REF):
			controller._inventory_option.select(index)
	controller._on_inventory_option_selected(0)
	var stow: Button = controller._weapon_handling_buttons.stow
	_expect(stow.focus_mode == Control.FOCUS_NONE and not stow.disabled, "Actual inventory must expose usable non-keyboard-stealing handling controls.")
	stow.emit_signal("pressed")
	_expect(controller.format_inventory_entry(controller._selected_inventory_entry()).contains("STOWED"), "Actual inventory list must display authoritative stowed state.")
	var draw: Button = controller._weapon_handling_buttons.draw
	_expect(not draw.disabled, "Actual draw control must become available for a stowed weapon.")
	draw.emit_signal("pressed")
	var action := session.simulation.get_action(session.get_actor_state(&"player").current_action_instance_id)
	_expect(action != null and action.required_acts == 1, "Actual UI draw must submit the shared one-Act action.")
	tree.root.remove_child(scene)
	scene.free()


func _replay() -> Dictionary:
	var sim := _setup()
	sim.request_weapon_handling(&"subject", WEAPON, "hold_one", "replay_hold")
	var result := sim.start_verified_consumable_healing_action(&"subject", PrimeV3InventoryCatalog.make_carried_potion_action_definition("health_potion", &"replay_potion"), "replay_potion")
	if result.get("success", false): sim.advance_to(sim.get_action(result.action_instance_id).final_effect_due_at_us)
	sim.request_weapon_handling(&"subject", WEAPON, "regrip", "replay_regrip")
	var events: Array = []
	for event: CombatEvent in sim.get_resolved_events(): events.append(event.to_dictionary())
	return {"snapshot": sim.get_state_snapshot(), "events": events, "rng": sim.random.to_dictionary()}


func _expect(value: bool, message: String) -> void:
	if not value: _failures.append(message)
