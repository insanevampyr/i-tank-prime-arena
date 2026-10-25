extends RefCounted

const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")

const OUT_OF_RANGE_POSITION := Vector2i(28_000_000, 12_000_000)

var _failures: Array[String] = []


func run() -> Array[String]:
	_test_single_press_and_release()
	_test_exact_authoritative_cadence()
	_test_frame_rate_independence_and_replay()
	_test_release_focus_log_and_ui_focus()
	_test_touch_hold_and_mouse_boundary()
	_test_target_lock_and_switch_during_hold()
	return _failures


func _test_single_press_and_release() -> void:
	var scene := _make_active_scene(2)
	if scene == null:
		return
	var controller: ArenaCombatController = scene.get_node("CombatController")
	var session := controller.get_combat_session_for_testing()
	_press_attack_key(controller, KEY_SPACE)
	var echo := InputEventKey.new()
	echo.pressed = true
	echo.echo = true
	echo.physical_keycode = KEY_SPACE
	controller._unhandled_input(echo)
	controller.advance_combat_for_testing(0)
	_expect_equal(_count_player_declarations(session), 1, "Operating-system key repeat must not duplicate the initial declaration.")
	_expect_true(controller.get_attack_readiness_for_testing().get("hold_active", false), "The ATTACK indicator snapshot must expose retained input while the action executes.")
	_release_attack_key(controller, KEY_SPACE)
	_expect_true(session.is_player_attack_in_flight(), "Releasing a single Space press must not cancel its executing attack.")
	controller.advance_combat_for_testing(0)
	_expect_true(not controller.get_attack_readiness_for_testing().get("hold_active", true), "Releasing attack must remove the held HUD state without canceling the countdown.")
	controller.advance_combat_for_testing(5_000_000)
	_expect_equal(_count_player_declarations(session), 1, "One press and release must remain one ordinary attack with no automatic repeat.")
	_expect_true(not session.is_player_attack_in_flight(), "The released input must allow the existing action to complete normally.")
	scene.free()


func _test_exact_authoritative_cadence() -> void:
	var expected_counts := {1: 2, 2: 3, 5: 6, 10: 11}
	for at_value: int in expected_counts:
		var scene := _make_active_scene(at_value)
		if scene == null:
			continue
		var controller: ArenaCombatController = scene.get_node("CombatController")
		var session := controller.get_combat_session_for_testing()
		_press_attack_key(controller, KEY_ENTER)
		controller.advance_combat_for_testing(5_000_000)
		_expect_equal(
			_count_player_declarations(session),
			expected_counts[at_value],
			"Held Enter at AT %d must request the next attack only at each exact 5/AT legality boundary." % at_value
		)
		var declaration_times := _player_declaration_timestamps(session)
		var interval_us := 5_000_000 / at_value
		for index in range(declaration_times.size()):
			_expect_equal(declaration_times[index], index * interval_us, "AT %d held declarations must not accumulate rendered-frame drift." % at_value)
		_release_attack_key(controller, KEY_ENTER)
		scene.free()


func _test_frame_rate_independence_and_replay() -> void:
	var coarse := _make_active_scene(10)
	var fine := _make_active_scene(10)
	if coarse == null or fine == null:
		if coarse != null:
			coarse.free()
		if fine != null:
			fine.free()
		return
	var coarse_controller: ArenaCombatController = coarse.get_node("CombatController")
	var fine_controller: ArenaCombatController = fine.get_node("CombatController")
	_press_attack_key(coarse_controller, KEY_SPACE)
	_press_attack_key(fine_controller, KEY_SPACE)
	coarse_controller.advance_combat_for_testing(5_000_000)
	for _step in range(100):
		fine_controller.advance_combat_for_testing(50_000)
	var coarse_session := coarse_controller.get_combat_session_for_testing()
	var fine_session := fine_controller.get_combat_session_for_testing()
	_expect_equal(_serialize_events(coarse_session.get_resolved_events()), _serialize_events(fine_session.get_resolved_events()), "Held attacks must produce identical authoritative event IDs, timestamps, ordering and RNG history across frame partitions.")
	_expect_equal(coarse_session.get_state_snapshot(), fine_session.get_state_snapshot(), "Held attacks must converge on the same authoritative state snapshot across frame partitions.")
	var client_a := ObservedCombatClient.new("held_client_a")
	var client_b := ObservedCombatClient.new("held_client_b")
	var events := coarse_session.get_resolved_events()
	var snapshot := coarse_session.get_state_snapshot()
	var envelopes: Array[CombatEventEnvelope] = []
	for sequence in range(events.size()):
		envelopes.append(CombatEventEnvelope.new(sequence, (events[sequence] as CombatEvent).to_dictionary(), snapshot))
	for envelope: CombatEventEnvelope in envelopes:
		client_a.receive(envelope)
	for index in range(envelopes.size() - 1, -1, -1):
		client_b.receive(envelopes[index])
	_expect_true(SynchronizationReport.compare_clients([client_a, client_b]).get("success", false), "Held attack history must converge for in-order and out-of-order simulated clients.")
	coarse.free()
	fine.free()


func _test_release_focus_log_and_ui_focus() -> void:
	var scene := _make_active_scene(2)
	if scene == null:
		return
	var controller: ArenaCombatController = scene.get_node("CombatController")
	var session := controller.get_combat_session_for_testing()
	_press_attack_key(controller, KEY_SPACE)
	controller.set_application_focus_for_testing(false)
	_expect_true(not controller.get_attack_hold_state_for_testing()["active"], "Application focus loss must clear held attack intent.")
	controller.set_application_focus_for_testing(true)
	controller.advance_combat_for_testing(5_000_000)
	_expect_equal(_count_player_declarations(session), 1, "Focus loss must not leave a stuck repeat after the already-started attack completes.")

	_press_attack_key(controller, KEY_SPACE)
	controller.set_transcript_visible(true)
	_expect_true(not controller.get_attack_hold_state_for_testing()["active"], "Opening FULL LOG must clear held attack intent.")
	controller.set_transcript_visible(false)
	controller.advance_combat_for_testing(5_000_000)
	_expect_equal(_count_player_declarations(session), 2, "FULL LOG must not cancel the executing attack or retain a repeat intent.")

	var edit := LineEdit.new()
	scene.add_child(edit)
	edit.grab_focus()
	_press_attack_key(controller, KEY_ENTER)
	_expect_true(not controller.get_attack_hold_state_for_testing()["active"], "A focused text/HUD control must not capture a held combat intent.")
	_expect_equal(_count_player_declarations(session), 2, "A focused text/HUD control must not declare an attack.")
	edit.release_focus()
	edit.queue_free()

	_press_attack_key(controller, KEY_SPACE)
	controller.press_encounter_control_for_testing()
	_expect_true(not controller.get_attack_hold_state_for_testing()["active"], "RESET must clear held attack intent.")
	scene.free()


func _test_touch_hold_and_mouse_boundary() -> void:
	var scene := _make_active_scene(5)
	if scene == null:
		return
	var controller: ArenaCombatController = scene.get_node("CombatController")
	var session := controller.get_combat_session_for_testing()
	var touch: MobileTouchControls = scene.get_node("HUD/MobileTouchControls")
	touch.set_viewport_size_for_testing(Vector2(915, 412))
	var center: Vector2 = touch.get_layout_snapshot()["attack_center"]
	_expect_true(touch.handle_touch(7, true, center), "The ATTACK touch target must begin a held intent.")
	controller.advance_combat_for_testing(2_000_000)
	_expect_equal(_count_player_declarations(session), 3, "Held touch ATTACK at AT 5 must repeat at exact legal boundaries.")
	touch.handle_touch(7, false, center)
	controller.advance_combat_for_testing(2_000_000)
	_expect_equal(_count_player_declarations(session), 3, "Releasing touch ATTACK must stop new declarations without adding a queued attack.")

	controller.press_encounter_control_for_testing()
	controller.press_encounter_control_for_testing()
	session = controller.get_combat_session_for_testing()
	session.set_opponent_behavior_enabled(false)
	_set_actor_at_and_geometry(session, 5)
	var opponent: Node2D = scene.get_node("Opponent")
	controller.request_pointer_action_for_testing(opponent.global_position, true)
	controller.advance_combat_for_testing(2_000_000)
	_expect_equal(_count_player_declarations(session), 1, "A desktop mouse click and hold boundary must remain exactly one request.")
	scene.free()


func _test_target_lock_and_switch_during_hold() -> void:
	var scene := _make_ready_scene()
	if scene == null:
		return
	var controller: ArenaCombatController = scene.get_node("CombatController")
	controller.combat_seed = 7
	var selected := controller.select_encounter_fixture_for_testing(Fixture.ENCOUNTER_WAVE_ONE_GOBLINS)
	_expect_true(selected.get("success", false), "The seeded multi-target Wave 1 fixture must be selectable for held-target locking.")
	controller.press_encounter_control_for_testing()
	var session := controller.get_combat_session_for_testing()
	session.set_opponent_behavior_enabled(false)
	_set_actor_at_and_geometry(session, 2)
	var targets := session.get_targetable_enemy_ids()
	_expect_true(targets.size() >= 2, "Seed 7 must provide multiple targetable Goblins for held target switching.")
	if targets.size() < 2:
		scene.free()
		return
	session.select_target(StringName(targets[0]))
	_press_attack_key(controller, KEY_SPACE)
	var first_attack_id := session.get_active_player_attack_id()
	var first_attack := session.simulation.get_attack(first_attack_id)
	session.select_target(StringName(targets[1]))
	_expect_equal(first_attack.target_id, StringName(targets[0]), "Changing selection while held must not alter the declared attack's locked target.")
	controller.advance_combat_for_testing(2_500_000)
	var next_attack := session.simulation.get_attack(session.get_active_player_attack_id())
	_expect_true(next_attack != null, "Held intent must request the next legal attack after the first completes.")
	if next_attack != null:
		_expect_equal(next_attack.target_id, StringName(targets[1]), "Target switching while held must affect only the subsequent declaration.")
	session.clear_target()
	controller.advance_combat_for_testing(2_500_000)
	_expect_equal(_count_player_declarations(session), 2, "A missing target must block further held declarations without queuing them.")
	scene.free()


func _make_ready_scene() -> Node:
	var packed: PackedScene = load("res://scenes/test_arena.tscn")
	var scene := packed.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		_failures.append("SceneTree unavailable for held-attack integration tests.")
		scene.free()
		return null
	tree.root.add_child(scene)
	var controller: ArenaCombatController = scene.get_node("CombatController")
	var fixture_result := controller.select_encounter_fixture_for_testing(Fixture.ENCOUNTER_MEDIUM_GUARDS)
	_expect_true(fixture_result.get("success", false), "The Task 31M legacy input fixture must explicitly select the Guard duel.")
	return scene


func _make_active_scene(at_value: int) -> Node:
	var scene := _make_ready_scene()
	if scene == null:
		return null
	var controller: ArenaCombatController = scene.get_node("CombatController")
	controller.press_encounter_control_for_testing()
	var session := controller.get_combat_session_for_testing()
	session.set_opponent_behavior_enabled(false)
	_set_actor_at_and_geometry(session, at_value)
	return scene


func _set_actor_at_and_geometry(session: ArenaCombatSession, at_value: int) -> void:
	var definition := session.simulation.get_actor_definition(Fixture.PLAYER_ID)
	definition.combat_stats["at"] = at_value
	var opponent_state := session.get_actor_state(Fixture.OPPONENT_ID)
	if opponent_state != null:
		opponent_state.current_hpc = 100_000
		session.simulation.apply_authoritative_position(Fixture.OPPONENT_ID, OUT_OF_RANGE_POSITION, opponent_state.facing_millidegrees, 0)
	for actor_id: String in session.get_targetable_enemy_ids():
		var state := session.get_actor_state(StringName(actor_id))
		if state != null:
			state.current_hpc = 100_000


func _press_attack_key(controller: ArenaCombatController, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = keycode
	controller._unhandled_input(event)


func _release_attack_key(controller: ArenaCombatController, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.pressed = false
	event.physical_keycode = keycode
	controller._input(event)


func _count_player_declarations(session: ArenaCombatSession) -> int:
	return _player_declaration_timestamps(session).size()


func _player_declaration_timestamps(session: ArenaCombatSession) -> Array[int]:
	var timestamps: Array[int] = []
	for event: CombatEvent in session.get_resolved_events():
		if String(event.event_type) == "physical_attack_declared" and event.source_actor_id == Fixture.PLAYER_ID:
			timestamps.append(event.timestamp_us)
	return timestamps


func _serialize_events(events: Array) -> Array:
	var serialized: Array = []
	for event: CombatEvent in events:
		serialized.append(event.to_dictionary())
	return serialized


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s Expected %s, got %s." % [message, str(expected), str(actual)])


func _expect_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)
