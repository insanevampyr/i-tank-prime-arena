extends RefCounted

const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
const MouseTests = preload("res://tests/test_mouse_hold_arrow_movement.gd")
var _failures: Array[String] = []

func run() -> Array[String]:
	_test_approach_inputs()
	_test_approach_completion_and_hold()
	_test_presentation_controls()
	var item := PrimeV3InventoryCatalog.describe_item("prime_v3_short_sword",0,true,CombatDefinitionCatalog.load_default_fixture_catalog())
	_expect(item.blocked_reason == "", "A valid equipped Short Sword is not an unavailable item.")
	if ArenaCombatSession.new(3681).has_method("request_developer_character_refresh"):
		_test_refresh()
		_expect(_refresh_replay() == _refresh_replay(),"Same-seed developer refresh must preserve replay events and state digests.")
	else: _expect(false,"Developer refresh must have an authoritative session request.")
	return _failures

func _scene(character: StringName) -> Node:
	var helper := MouseTests.new()
	var scene := helper._make_ready_scene()
	var controller: ArenaCombatController = scene.get_node("CombatController")
	controller.select_player_character_for_testing(character)
	controller.get_combat_session_for_testing().set_opponent_behavior_enabled(false)
	controller.press_encounter_control_for_testing()
	var session := controller.get_combat_session_for_testing()
	session.set_opponent_behavior_enabled(false)
	session.get_actor_state(&"player").position_microfeet = Vector2i(20_000_000,12_000_000)
	session.get_actor_state(Fixture.OPPONENT_ID).position_microfeet = Vector2i(26_000_000,12_000_000)
	session.select_target(Fixture.OPPONENT_ID)
	controller._update_presentation()
	return scene

func _test_approach_inputs() -> void:
	for character: StringName in [Fixture.PLAYER_CHARACTER_GUARD,Fixture.PLAYER_CHARACTER_VAELIS]:
		for input in ["space","enter","mouse"]:
			var scene := _scene(character)
			var controller: ArenaCombatController = scene.get_node("CombatController")
			var session := controller.get_combat_session_for_testing()
			var before_rng := session.simulation.random.get_draw_count()
			_expect(controller.get_attack_readiness_for_testing().get("state") == "ready","Out-of-reach approach declaration must show READY.")
			if input == "mouse":
				controller.set_mouse_attack_for_testing(controller._get_enemy_visual(Fixture.OPPONENT_ID).global_position,true)
			else:
				var key := InputEventKey.new()
				key.physical_keycode = KEY_SPACE if input == "space" else KEY_ENTER
				key.pressed = true
				controller._unhandled_input(key)
			var state := session.get_actor_state(&"player")
			var action := session.simulation.get_action(state.current_action_instance_id)
			_expect(action != null,"%s %s must declare outside reach, not reject it." % [character,input])
			if action != null:
				_expect(action.final_effect_due_at_us-action.started_at_us == (5_000_000 if character == Fixture.PLAYER_CHARACTER_VAELIS else 2_500_000),"Approach declaration must preserve exact AT timing.")
				_expect(session.simulation.random.get_draw_count() == before_rng,"No early ACC draw at declaration.")
				controller._clear_attack_hold_intent()
				session.advance_by(action.final_effect_due_at_us-session.simulation.clock.get_elapsed_us())
				_expect(session.simulation.random.get_draw_count() == before_rng,"Final out-of-range failure must not roll ACC.")
				var declarations := 0
				for event: CombatEvent in session.get_resolved_events():
					if event.event_type == &"action_declared" and event.source_actor_id == &"player": declarations += 1
				_expect(declarations == 1,"One press/click must not schedule duplicate ordinary Acts.")
			_free_scene(scene)

func _downtime(mode: String) -> ArenaCombatSession:
	var session := ArenaCombatSession.new(3681,null,Fixture.ENCOUNTER_WAVE_ONE_GOBLINS,Fixture.PLAYER_CHARACTER_VAELIS)
	session.set_opponent_behavior_enabled(false)
	session.initialize_wave_one_goblins(Vector2i(20_000_000,12_000_000),Vector2i(24_000_000,12_000_000),false)
	session.configure_reward_mode(mode)
	session.start_encounter()
	for id: String in session.get_targetable_enemy_ids(): session.get_actor_state(StringName(id)).current_hpc = 0
	session.advance_by(1)
	return session

func _test_approach_completion_and_hold() -> void:
	for blocked in [false,true]:
		var scene := _scene(Fixture.PLAYER_CHARACTER_VAELIS)
		var controller: ArenaCombatController = scene.get_node("CombatController")
		var session := controller.get_combat_session_for_testing()
		var result := controller._request_attack("test_approach")
		_expect(result.get("success",false),"Moving-approach fixture must actually declare the action.")
		if result.get("success",false):
			var draws := session.simulation.random.get_draw_count()
			_expect(session.request_player_movement(Vector2i(25_000_000,12_000_000),10).get("success",false),"Approaching during execution must spend legal movement.")
			if blocked: session.simulation.set_attack_final_line_of_sight_resolver(func(_a: StringName,_b: StringName) -> bool: return false)
			var action := session.simulation.get_action(result.action_instance_id)
			session.advance_by(action.final_effect_due_at_us-session.simulation.clock.get_elapsed_us())
			var accuracy_count := 0
			for event: CombatEvent in session.get_resolved_events():
				if event.event_type == &"physical_attack_accuracy_resolved" and event.source_actor_id == &"player": accuracy_count += 1
			_expect(accuracy_count == 0 if blocked else accuracy_count > 0,"ACC occurs only after legal final reach and LOS (blocked=%s, ACC events=%s)." % [blocked,accuracy_count])
			if blocked: _expect(session.simulation.random.get_draw_count() == draws,"Final LOS failure rolls no ACC or damage RNG.")
		_free_scene(scene)
	var held_scene := _scene(Fixture.PLAYER_CHARACTER_VAELIS)
	var held_controller: ArenaCombatController = held_scene.get_node("CombatController")
	var session := held_controller.get_combat_session_for_testing()
	var key := InputEventKey.new()
	key.physical_keycode = KEY_SPACE
	key.pressed = true
	held_controller._unhandled_input(key)
	held_controller._advance_session_with_attack_hold(5_000_000)
	var declarations := 0
	for event: CombatEvent in session.get_resolved_events():
		if event.event_type == &"action_declared" and event.source_actor_id == &"player": declarations += 1
	_expect(declarations == 2,"Held approach attacks repeat only at the next legal AT boundary, without a range prohibition.")
	held_controller._clear_attack_hold_intent()
	_free_scene(held_scene)

func _test_presentation_controls() -> void:
	var helper := MouseTests.new()
	var scene := helper._make_ready_scene()
	var controller: ArenaCombatController = scene.get_node("CombatController")
	controller.select_player_character_for_testing(Fixture.PLAYER_CHARACTER_VAELIS)
	# Use the real selector, not a UI-side authority override.
	for _index in range(9):
		if controller.get_test_mode_state_for_testing().selector_index == 8: break
		controller._on_encounter_selector_pressed()
	controller.press_encounter_control_for_testing()
	var session := controller.get_combat_session_for_testing()
	session.set_opponent_behavior_enabled(false)
	controller._update_rewards_panel(true)
	_expect(not controller._developer_refresh_button.visible,"Actual refresh button must be hidden during combat.")
	for id: String in session.get_targetable_enemy_ids(): session.get_actor_state(StringName(id)).current_hpc = 0
	session.advance_by(1)
	controller._update_rewards_panel(true)
	_expect(controller._developer_refresh_button.visible,"Actual refresh control appears in DEV NORMAL downtime.")
	_expect(controller.get_rewards_panel_text_for_testing().contains("Purchase History:"),"Actual panel must identify the history as EXPC purchases.")
	for index in range(controller._inventory_entries.size()):
		if controller._inventory_entries[index].definition_id == "prime_v3_short_sword": controller._inventory_option.select(index)
	controller._on_inventory_option_selected(0)
	_expect(not controller.get_rewards_panel_text_for_testing().contains("Unavailable: item unavailable"),"Equipped Sword detail must not falsely report item unavailability.")
	var state := session.get_actor_state(&"player")
	state.current_hpc = 3
	state.resources.mana = 1
	controller._developer_refresh_button.emit_signal("pressed")
	_expect(state.current_hpc == session.get_actor_max_hpm(&"player") and state.resources.mana == 20,"Actual button must submit the authoritative refresh request.")
	_free_scene(scene)

func _refresh_replay() -> Dictionary:
	var session := _downtime(ArenaRewardLedger.MODE_DEV_NORMAL)
	session.get_actor_state(&"player").current_hpc = 3
	session.get_actor_state(&"player").resources.mana = 1
	session.request_developer_character_refresh("replay:refresh")
	var events: Array = []
	for event: CombatEvent in session.get_resolved_events(): events.append(event.to_dictionary())
	return {"events":events,"snapshot":session.simulation.get_state_snapshot(),"digest":SyncStateDigest.compute(session.simulation.get_state_snapshot())}

func _test_refresh() -> void:
	for mode in [ArenaRewardLedger.MODE_NORMAL,ArenaRewardLedger.MODE_TEST]:
		var blocked := _downtime(mode)
		var before := blocked.simulation.get_state_snapshot()
		_expect(not blocked.request_developer_character_refresh("reject").get("success",false) and blocked.simulation.get_state_snapshot() == before,"NORMAL/TEST refresh rejection must leave authority unchanged.")
	var session := _downtime(ArenaRewardLedger.MODE_DEV_NORMAL)
	var state := session.get_actor_state(&"player")
	var actor := session.simulation.get_actor_definition(&"player")
	state.current_hpc = 3
	state.resources.mana = 1
	# Explicit isolated Ability resource fixture exercises the shared restoration path.
	actor.resource_maxima.ap = 4
	state.resources.ap = 1
	state.ability_daily_maxima = {"known_fixture_ability":2}
	state.ability_daily_remaining = {"known_fixture_ability":0}
	state.persistent_damage_shields = {"fixture_shield":{"remaining_points":7}}
	state.timed_stat_effects = {"fixture_defensive_buff":{"expires_at_us":120_000_000,"stat_modifiers":{"nal":2}}}
	state.conditions.append("prone")
	var before := state.to_dictionary()
	var definition_before := actor.to_dictionary()
	var rewards_before := session.get_reward_state()
	var clock_before := session.simulation.clock.get_elapsed_us()
	var rng_before := session.simulation.random.get_draw_count()
	_expect(session.request_developer_character_refresh("refresh").get("success",false),"DEV downtime must accept explicit refresh.")
	_expect(state.current_hpc == actor.get_combat_stat("hpm") and state.resources.mana == actor.resource_maxima.mana and state.resources.ap == 4 and state.ability_daily_remaining.known_fixture_ability == 2,"Refresh restores exact current HPC/Mana/AP/known daily maxima.")
	_expect(actor.to_dictionary() == definition_before and session.get_reward_state() == rewards_before,"Refresh must not change maxima, level, XP, purchases or rewards.")
	for field in ["progression","persistent_damage_shields","conditions","equipment_refs","hand_occupancy","inventory_quantities","timed_stat_effects"]:
		_expect(state.to_dictionary().get(field) == before.get(field),"Refresh must preserve %s." % field)
	_expect(session.simulation.clock.get_elapsed_us() == clock_before and session.simulation.random.get_draw_count() == rng_before,"Refresh must not advance combat time or RNG.")
	var snapshot := session.simulation.get_state_snapshot()
	_expect(snapshot.schema_version == 12,"Developer refresh must preserve snapshot schema 12.")
	_expect(not session.request_developer_character_refresh("refresh").get("success",false) and session.simulation.get_state_snapshot() == snapshot,"Duplicate refresh request is rejected exactly once.")
	_expect(session.request_developer_character_refresh("refresh:full").get("success",false) and state.current_hpc == actor.get_combat_stat("hpm"),"Repeated full refresh cannot increase capacity or rewards.")
	var harness := TwoClientSyncHarness.new(3681)
	harness.authority.simulation = session.simulation
	harness.deliver_in_order(harness.authority.publish_current_events())
	_expect(harness.compare_clients().get("success",false) and harness.client_a.get_state_snapshot() == session.simulation.get_state_snapshot(),"Developer event and schema-12 snapshot must converge.")
	state.conditions.erase("prone")
	_expect(session.request_next_wave().get("success",false),"NEXT WAVE must remain usable after refresh.")
	var active_snapshot := session.simulation.get_state_snapshot()
	_expect(not session.request_developer_character_refresh("combat").get("success",false) and active_snapshot == session.simulation.get_state_snapshot(),"Active combat must reject developer refresh.")
	session.reset_encounter(false)
	_expect(session.get_actor_state(&"player").persistent_damage_shields.is_empty(),"RESET restores the fixture without leaked developer state.")
	var defeated := _downtime(ArenaRewardLedger.MODE_DEV_NORMAL)
	defeated.get_actor_state(&"player").current_hpc = 0
	_expect(not defeated.request_developer_character_refresh("dead").get("success",false),"Refresh cannot resurrect a defeated character.")

func _free_scene(scene: Node) -> void:
	scene.get_parent().remove_child(scene)
	scene.free()

func _expect(value: bool, message: String) -> void:
	if not value: _failures.append(message)
