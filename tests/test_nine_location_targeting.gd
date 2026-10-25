extends RefCounted

const HitLocations = preload("res://scripts/combat/combat_hit_location_catalog.gd")
const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
const Controller = preload("res://scripts/ui/arena_combat_controller.gd")

const PLAYER_POSITION := Vector2i(20_000_000, 12_000_000)
const OPPONENT_POSITION := Vector2i(23_000_000, 12_000_000)

var _failures: Array[String] = []


func run() -> Array[String]:
	_failures.clear()
	_test_source_verified_same_size_profile()
	_test_number_row_and_keypad_selection()
	_test_location_8_selection_cycle_and_no_side_effects()
	_test_target_cycle_and_invalid_target_filtering()
	_test_attack_locks_target_and_location()
	_test_location_8_declaration_locks_subdivision()
	_test_selection_feedback_is_local_only()
	_test_location_replay_and_two_client_convergence()
	return _failures


func _test_source_verified_same_size_profile() -> void:
	var expected := [
		[1, &"head", -3, PackedStringArray(["head"])],
		[2, &"neck", -5, PackedStringArray(["head"])],
		[3, &"torso", 0, PackedStringArray(["torso"])],
		[4, &"shoulders_upper_arms", -1, PackedStringArray(["arms"])],
		[5, &"elbows", -2, PackedStringArray(["elbows"])],
		[6, &"hands", -3, PackedStringArray(["hands"])],
		[7, &"groin_upper_legs", -2, PackedStringArray(["legs"])],
		[8, &"knee", -3, PackedStringArray(["knees"])],
		[8, &"lower_leg", -3, PackedStringArray(["legs"])],
		[9, &"feet", -4, PackedStringArray(["legs"])],
	]
	for row: Array in expected:
		var location := HitLocations.get_by_id(StringName(row[1]))
		_expect_equal(location.get("number"), row[0], "Target %s must retain Prime location number %d." % [String(row[1]), int(row[0])])
		_expect_equal(location.get("id"), row[1], "Prime location %d must retain its stable anatomical identifier." % int(row[0]))
		_expect_equal(location.get("same_size_acc_modifier"), row[2], "Prime location %d must retain its same-size ACC modifier." % int(row[0]))
		_expect_equal(PackedStringArray(location.get("armor_slots", [])), row[3], "Prime location %d must retain only its owner-confirmed armor slot boundary." % int(row[0]))
	var definition := Fixture.make_attack_definition()
	_expect_equal(definition.get_location_acc_modifier(&"head"), -3, "The same-size Guard fixture must source Head ACC -3 from the explicit profile.")
	_expect_equal(definition.get_location_acc_modifier(&"neck"), -5, "The same-size Guard fixture must source Neck ACC -5 from the explicit profile.")
	_expect_true(definition.allowed_target_locations.has("knee"), "The approved Knee subdivision must be a legal same-size attack location.")
	_expect_true(definition.allowed_target_locations.has("lower_leg"), "The approved Lower Leg subdivision must be a legal same-size attack location.")
	_expect_equal(definition.get_location_acc_modifier(&"knee"), -3, "Knee must retain Prime location 8 ACC -3.")
	_expect_equal(definition.get_location_acc_modifier(&"lower_leg"), -3, "Lower Leg must retain Prime location 8 ACC -3.")
	for location_id: String in ["head", "neck", "torso", "shoulders_upper_arms", "elbows", "hands", "groin_upper_legs", "feet"]:
		_expect_true(definition.allowed_target_locations.has(location_id), "Previously implemented location %s must remain operational." % location_id)
	_expect_equal(definition.physical_damage.get_location_multiplier(&"head"), {"numerator": 3, "denominator": 2, "source_ref": "PRIME-V3 pp. 95-98, Head location 1"}, "Head must retain the exact 3/2 multiplier.")


func _test_number_row_and_keypad_selection() -> void:
	var scene := _make_scene()
	if scene == null:
		return
	var controller: ArenaCombatController = scene.get_node("CombatController")
	var session := controller.get_combat_session_for_testing()
	var actions_before: int = session.simulation.get_state_snapshot()["actions"].size()
	var attacks_before := _count_events(session, "physical_attack_declared")
	var top_row := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9]
	var keypad := [KEY_KP_1, KEY_KP_2, KEY_KP_3, KEY_KP_4, KEY_KP_5, KEY_KP_6, KEY_KP_7, KEY_KP_8, KEY_KP_9]
	for index in range(9):
		_send_key(controller, top_row[index])
		var expected_top: StringName = HitLocations.LOCATION_8_KNEE if index == 7 else StringName(HitLocations.get_by_number(index + 1)["id"])
		_expect_equal(session.get_selected_target_location(), expected_top, "Top-row key %d must select Prime location %d." % [index + 1, index + 1])
		_send_key(controller, keypad[index])
		var expected_keypad: StringName = HitLocations.LOCATION_8_LOWER_LEG if index == 7 else StringName(HitLocations.get_by_number(index + 1)["id"])
		_expect_equal(session.get_selected_target_location(), expected_keypad, "Keypad key %d must select the same Prime location." % (index + 1))
	var numlock_off := InputEventKey.new()
	numlock_off.pressed = true
	numlock_off.physical_keycode = KEY_KP_1
	numlock_off.keycode = KEY_END
	controller._unhandled_input(numlock_off)
	_expect_equal(session.get_selected_target_location(), &"head", "Physical keypad identity must preserve keypad 1 selection when Num Lock reports a navigation keycode.")
	_expect_equal(session.simulation.get_state_snapshot()["actions"].size(), actions_before, "Aim selection must consume no Act or create an action.")
	_expect_equal(_count_events(session, "physical_attack_declared"), attacks_before, "Aim selection must never declare an attack.")
	scene.free()


func _test_location_8_selection_cycle_and_no_side_effects() -> void:
	var session := _make_session()
	var action_count: int = session.simulation.get_state_snapshot()["actions"].size()
	var draw_count := session.simulation.random.get_draw_count()
	var player_position := session.get_actor_state(Fixture.PLAYER_ID).position_microfeet
	_expect_equal(session.select_target_location_by_number(8).get("target_location"), "knee", "The first 8 press must select Knee.")
	_expect_equal(session.select_target_location_by_number(8).get("target_location"), "lower_leg", "The second 8 press must select Lower Leg.")
	_expect_equal(session.select_target_location_by_number(8).get("target_location"), "knee", "The third 8 press must return to Knee.")
	_expect_equal(session.select_target_location_by_number(2).get("target_location"), "neck", "Another numbered location must remain selectable.")
	_expect_equal(session.select_target_location_by_number(8).get("target_location"), "knee", "Switching away must reset the next 8 press to Knee.")
	_expect_equal(session.simulation.get_state_snapshot()["actions"].size(), action_count, "Location selection must consume no Act or create an action.")
	_expect_equal(session.simulation.random.get_draw_count(), draw_count, "Location selection must consume no authoritative RNG.")
	_expect_equal(session.get_actor_state(Fixture.PLAYER_ID).position_microfeet, player_position, "Location selection must not interrupt or mutate authoritative movement position.")


func _test_target_cycle_and_invalid_target_filtering() -> void:
	var candidates := PackedStringArray(["guard_c", "guard_a", "guard_b"])
	_expect_equal(ArenaCombatSession.choose_cycled_target(&"guard_a", candidates, 1), &"guard_b", "Forward target cycling must use stable identifier ordering.")
	_expect_equal(ArenaCombatSession.choose_cycled_target(&"guard_a", candidates, -1), &"guard_c", "Reverse target cycling must wrap in stable order.")
	var scene := _make_scene()
	if scene == null:
		return
	var controller: ArenaCombatController = scene.get_node("CombatController")
	var session := controller.get_combat_session_for_testing()
	session.clear_target()
	_send_key(controller, KEY_TAB)
	_expect_equal(session.get_selected_target_id(), Fixture.OPPONENT_ID, "Tab must select the next living target without attacking.")
	var reverse_tab := InputEventKey.new()
	reverse_tab.pressed = true
	reverse_tab.physical_keycode = KEY_TAB
	reverse_tab.shift_pressed = true
	controller._unhandled_input(reverse_tab)
	_expect_equal(session.get_selected_target_id(), Fixture.OPPONENT_ID, "Shift+Tab must select the previous living target.")
	_expect_equal(_count_events(session, "physical_attack_declared"), 0, "Enemy selection must not declare an attack.")
	session.get_actor_state(Fixture.OPPONENT_ID).current_hpc = 0
	_expect_true(session.get_targetable_enemy_ids().is_empty(), "Defeated enemies must be excluded from target cycling.")
	_expect_equal(session.cycle_target(1).get("reason"), "no_target_available", "Cycling with no living enemy must fail without selecting an invalid target.")
	scene.free()


func _test_attack_locks_target_and_location() -> void:
	var session := _make_session()
	session.select_target_location(&"head")
	var started := session.request_player_attack("task27_lock")
	_expect_true(started.get("success", false), "A source-verified Head attack must enter the existing authoritative action pipeline.")
	if not started.get("success", false):
		return
	var attack := session.simulation.get_attack(String(started["attack_instance_id"]))
	_expect_equal(attack.target_id, Fixture.OPPONENT_ID, "The selected enemy must be copied into the declared attack instance.")
	_expect_equal(attack.target_location, &"head", "The selected location must be copied into the declared attack instance.")
	_expect_equal(attack.location_acc_modifier, -3, "The locked Head attack must use the same-size Prime ACC modifier.")
	session.select_target_location(&"neck")
	session.clear_target()
	_expect_equal(attack.target_id, Fixture.OPPONENT_ID, "Changing selection during execution must not retarget the declared attack.")
	_expect_equal(attack.target_location, &"head", "Changing aim during execution must not alter the declared attack location.")


func _test_location_8_declaration_locks_subdivision() -> void:
	var session := _make_session()
	_expect_equal(session.select_target_location_by_number(8).get("target_location"), "knee", "The first location 8 declaration fixture must select Knee.")
	var result := session.request_player_attack("task27_location_8")
	_expect_true(result.get("success", false), "The approved Knee subdivision must enter the existing action pipeline.")
	if not result.get("success", false):
		return
	var attack := session.simulation.get_attack(String(result["attack_instance_id"]))
	_expect_equal(attack.target_location, HitLocations.LOCATION_8_KNEE, "Attack declaration must lock the Knee subdivision.")
	_expect_equal(attack.location_acc_modifier, -3, "Knee must use the same-size Prime location 8 ACC modifier.")
	var action := session.simulation.get_action(String(result["action_instance_id"]))
	_expect_equal(action.final_effect_due_at_us - action.started_at_us, 2_500_000, "Location 8 selection must add no delay to the Guard's existing AT 2 attack.")
	_expect_equal(session.select_target_location_by_number(8).get("target_location"), "lower_leg", "Selection may advance to Lower Leg while an attack executes.")
	_expect_equal(attack.target_location, HitLocations.LOCATION_8_KNEE, "Mid-attack subdivision changes must not modify the declared attack.")
	session.advance_by(2_500_000)
	var accuracy_event: CombatEvent = null
	for event: CombatEvent in session.get_resolved_events():
		if event.event_type == &"physical_attack_accuracy_resolved" and String(event.payload.get("attack_instance_id", "")) == attack.attack_instance_id:
			accuracy_event = event
	_expect_true(accuracy_event != null, "A legal Knee attack must reach the existing ACC resolution point.")
	if accuracy_event != null:
		_expect_equal(accuracy_event.payload.get("acc_target"), 9, "Guard ACC 12 plus location 8 modifier -3 must produce ACC target 9.")


func _test_selection_feedback_is_local_only() -> void:
	var scene := _make_scene()
	if scene == null:
		return
	var controller: ArenaCombatController = scene.get_node("CombatController")
	var session := controller.get_combat_session_for_testing()
	var event_count := session.get_resolved_events().size()
	controller.select_location_for_testing(1)
	var layer: ArenaFloatingCombatText = scene.get_node("FloatingCombatText")
	var messages := layer.get_active_messages_for_testing()
	_expect_true(not messages.is_empty() and String(messages.back()["text"]) == "AIM: HEAD", "Aim changes must use brief local floating feedback.")
	controller.select_location_for_testing(8)
	_expect_equal(String(layer.get_active_messages_for_testing().back()["text"]), "AIM: KNEE", "The first 8 selection must display the approved Knee feedback.")
	controller.select_location_for_testing(8)
	_expect_equal(String(layer.get_active_messages_for_testing().back()["text"]), "AIM: LOWER LEG", "The second 8 selection must display the approved Lower Leg feedback.")
	_expect_equal(session.get_resolved_events().size(), event_count, "Local selection feedback must not impersonate an authoritative combat event.")
	scene.free()


func _test_location_replay_and_two_client_convergence() -> void:
	var first := _make_session()
	var second := _make_session()
	for session: ArenaCombatSession in [first, second]:
		session.select_target_location_by_number(8)
		session.request_player_attack("task27_replay")
		session.advance_by(2_500_000)
	_expect_equal(first.get_state_snapshot(), second.get_state_snapshot(), "Equal location selections and inputs must replay to identical authoritative state.")
	_expect_equal(_serialize_events(first.get_resolved_events()), _serialize_events(second.get_resolved_events()), "Location-targeted event histories must replay identically.")

	var harness := TwoClientSyncHarness.new(ArenaCombatSession.DEFAULT_SEED)
	var authority_session := ArenaCombatSession.new(ArenaCombatSession.DEFAULT_SEED, harness.authority.simulation)
	authority_session.initialize(PLAYER_POSITION, OPPONENT_POSITION)
	authority_session.select_target_location_by_number(8)
	authority_session.request_player_attack("task27_sync")
	authority_session.advance_by(2_500_000)
	var envelopes := harness.authority.publish_current_events()
	for envelope: CombatEventEnvelope in envelopes:
		harness.client_a.receive(envelope)
	for index in range(envelopes.size() - 1, -1, -1):
		harness.client_b.receive(envelopes[index])
	_expect_true(harness.compare_clients().get("success", false), "Both clients must converge after a location-targeted authoritative event stream.")
	_expect_equal(harness.client_a.get_state_digest(), harness.authority.get_state_digest(), "Location-targeted authority and clients must share one digest.")


func _make_session() -> ArenaCombatSession:
	var session := ArenaCombatSession.new(ArenaCombatSession.DEFAULT_SEED)
	var result := session.initialize(PLAYER_POSITION, OPPONENT_POSITION)
	_expect_true(result.get("success", false), "The Task 27 fixture must initialize.")
	return session


func _make_scene() -> Node:
	var packed: PackedScene = load("res://scenes/test_arena.tscn")
	var scene := packed.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		_failures.append("SceneTree unavailable for Task 27 input tests.")
		scene.free()
		return null
	tree.root.add_child(scene)
	var controller: ArenaCombatController = scene.get_node("CombatController")
	var fixture_result := controller.select_encounter_fixture_for_testing(Fixture.ENCOUNTER_MEDIUM_GUARDS)
	_expect_true(fixture_result.get("success", false), "The Task 27 legacy input fixture must explicitly select the Guard duel.")
	return scene


func _send_key(controller: ArenaCombatController, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = keycode
	controller._unhandled_input(event)


func _count_events(session: ArenaCombatSession, event_type: String) -> int:
	var count := 0
	for event: CombatEvent in session.get_resolved_events():
		if String(event.event_type) == event_type:
			count += 1
	return count


func _serialize_events(events: Array) -> Array:
	var result: Array = []
	for event: CombatEvent in events:
		result.append(event.to_dictionary())
	return result


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s Expected %s, got %s." % [message, expected, actual])


func _expect_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)
