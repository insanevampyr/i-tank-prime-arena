extends RefCounted

const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
const InputIntent = preload("res://scripts/input/arena_player_input_intent.gd")
const PrimeMovementModel = preload("res://scripts/movement/prime_movement_model.gd")

const OUT_OF_RANGE_POSITION := Vector2i(28_000_000, 12_000_000)

var _failures: Array[String] = []


func run() -> Array[String]:
	_test_mouse_click_release_and_hold_cadence()
	_test_mouse_movement_target_switch_and_defeat()
	_test_mouse_cancellation_and_independent_sources()
	_test_arrow_key_equivalence_running_and_focus_gate()
	_test_mouse_hold_frame_independence_and_convergence()
	return _failures


func _test_mouse_click_release_and_hold_cadence() -> void:
	var scene := _make_active_scene(2)
	if scene == null:
		return
	var controller: ArenaCombatController = scene.get_node("CombatController")
	var session := controller.get_combat_session_for_testing()
	var opponent: Node2D = scene.get_node("Opponent")
	controller.set_mouse_attack_for_testing(opponent.global_position, true)
	controller.set_mouse_attack_for_testing(opponent.global_position, false)
	_expect_equal(_count_player_declarations(session), 1, "A click-release must declare exactly one ordinary attack.")
	_expect_true(not controller.get_attack_hold_state_for_testing()["mouse"], "Mouse release must clear only the retained mouse intent.")
	_expect_true(session.is_player_attack_in_flight(), "Mouse release must not cancel the attack already executing.")
	controller.advance_combat_for_testing(2_500_000)
	_expect_equal(_count_player_declarations(session), 1, "A released click must not repeat when the action completes.")

	controller.set_mouse_attack_for_testing(opponent.global_position, true)
	controller.advance_combat_for_testing(5_000_000)
	_expect_equal(_count_player_declarations(session), 4, "Sustained left-click at AT 2 must repeat only on exact 2.5-second authoritative boundaries.")
	controller.set_mouse_attack_for_testing(opponent.global_position, false)
	controller.advance_combat_for_testing(2_500_000)
	_expect_equal(_count_player_declarations(session), 4, "Releasing sustained left-click must stop future declarations while the current action finishes.")
	scene.free()


func _test_mouse_movement_target_switch_and_defeat() -> void:
	var scene := _make_wave_scene(7, 2)
	if scene == null:
		return
	var controller: ArenaCombatController = scene.get_node("CombatController")
	var session := controller.get_combat_session_for_testing()
	var targets := session.get_targetable_enemy_ids()
	_expect_true(targets.size() >= 2, "Seed 7 must provide multiple Goblins for mouse-held target switching.")
	if targets.size() < 2:
		scene.free()
		return
	var first_target := StringName(targets[0])
	var first_visual: Node2D = controller._get_enemy_visual(first_target)
	controller.set_mouse_attack_for_testing(first_visual.global_position, true)
	var first_attack := session.simulation.get_attack(session.get_active_player_attack_id())
	_expect_true(first_attack != null, "Clicking the first living target must begin one attack.")

	var player_state := session.get_actor_state(Fixture.PLAYER_ID)
	var movement := session.request_player_movement(player_state.position_microfeet + Vector2i(100_000, 0), 11)
	_expect_true(movement.get("success", false), "Legal authoritative movement must remain available while left-click attack intent is held.")
	_expect_true(controller.get_attack_hold_state_for_testing()["mouse"], "Legal movement must not clear mouse-held attack intent.")

	var tab := InputEventKey.new()
	tab.pressed = true
	tab.physical_keycode = KEY_TAB
	controller._input(tab)
	var second_target := session.get_selected_target_id()
	_expect_true(second_target != first_target and second_target != &"", "Tab must change the selected target while left-click remains held.")
	if first_attack != null:
		_expect_equal(first_attack.target_id, first_target, "An executing attack must retain the enemy locked at declaration.")
	controller.advance_combat_for_testing(2_500_000)
	var next_attack := session.simulation.get_attack(session.get_active_player_attack_id())
	_expect_true(next_attack != null, "Held mouse intent must request the next legal attack after target switching.")
	if next_attack != null:
		_expect_equal(next_attack.target_id, second_target, "The next declaration must use the newly selected target.")

	var selected_state := session.get_actor_state(second_target)
	selected_state.current_hpc = 0
	controller.advance_combat_for_testing(2_500_000)
	_expect_equal(_count_player_declarations(session), 2, "A defeated selected target must block further held declarations.")
	_expect_equal(session.get_selected_target_id(), second_target, "Target defeat must not silently auto-select another enemy.")
	controller.set_mouse_attack_for_testing(Vector2.ZERO, false)
	scene.free()


func _test_mouse_cancellation_and_independent_sources() -> void:
	var scene := _make_active_scene(2)
	if scene == null:
		return
	var controller: ArenaCombatController = scene.get_node("CombatController")
	var session := controller.get_combat_session_for_testing()
	var opponent: Node2D = scene.get_node("Opponent")

	controller.set_mouse_attack_for_testing(Vector2(-500.0, -500.0), true)
	_expect_true(not controller.get_attack_hold_state_for_testing()["mouse"], "Holding empty terrain must not activate mouse-held attack intent.")
	_expect_equal(_count_player_declarations(session), 0, "An empty-terrain press must not declare an attack.")

	var edit := LineEdit.new()
	scene.add_child(edit)
	edit.grab_focus()
	controller.set_mouse_attack_for_testing(opponent.global_position, true)
	_expect_true(not controller.get_attack_hold_state_for_testing()["mouse"], "A focused HUD or text control must block mouse-held combat input.")
	_expect_equal(_count_player_declarations(session), 0, "A HUD-blocked mouse press must not declare an attack.")
	edit.release_focus()
	edit.queue_free()

	_press_attack_key(controller, KEY_SPACE)
	controller.set_mouse_attack_for_testing(opponent.global_position, true)
	_expect_equal(_count_player_declarations(session), 1, "Simultaneous keyboard and mouse holds must not duplicate an in-flight declaration.")
	_release_attack_key(controller, KEY_SPACE)
	_expect_true(controller.get_attack_hold_state_for_testing()["mouse"], "Releasing keyboard attack must not cancel independent mouse-held intent.")
	controller.set_mouse_attack_for_testing(opponent.global_position, false)
	_expect_true(not controller.get_attack_hold_state_for_testing()["active"], "Releasing the final active input source must clear retained intent.")

	controller.set_mouse_attack_for_testing(opponent.global_position, true)
	controller._notification(Node.NOTIFICATION_WM_MOUSE_EXIT)
	_expect_true(not controller.get_attack_hold_state_for_testing()["mouse"], "Mouse exit or drag cancellation must clear mouse-held intent.")
	controller.set_mouse_attack_for_testing(opponent.global_position, true)
	controller.set_application_focus_for_testing(false)
	_expect_true(not controller.get_attack_hold_state_for_testing()["active"], "Application focus loss must clear every held attack source.")
	controller.set_application_focus_for_testing(true)
	controller.set_mouse_attack_for_testing(opponent.global_position, true)
	controller.set_transcript_visible(true)
	_expect_true(not controller.get_attack_hold_state_for_testing()["mouse"], "Opening FULL LOG must clear mouse-held intent.")
	controller.set_transcript_visible(false)
	controller.set_mouse_attack_for_testing(opponent.global_position, true)
	controller.press_encounter_control_for_testing()
	_expect_true(not controller.get_attack_hold_state_for_testing()["mouse"], "RESET must clear mouse-held intent.")
	scene.free()


func _test_arrow_key_equivalence_running_and_focus_gate() -> void:
	var wasd_right := PlaceholderPlayer.resolve_keyboard_direction(Vector2.RIGHT, Vector2.ZERO, false)
	var arrow_right := PlaceholderPlayer.resolve_keyboard_direction(Vector2.ZERO, Vector2.RIGHT, false)
	_expect_equal(arrow_right, wasd_right, "Right Arrow and D must resolve to the same movement intent.")
	var wasd_up := PlaceholderPlayer.resolve_keyboard_direction(Vector2.UP, Vector2.ZERO, false)
	var arrow_up := PlaceholderPlayer.resolve_keyboard_direction(Vector2.ZERO, Vector2.UP, false)
	_expect_equal(arrow_up, wasd_up, "Up Arrow and W must resolve to the same movement intent.")

	var mixed_same := PlaceholderPlayer.resolve_keyboard_direction(Vector2.RIGHT, Vector2.RIGHT, false)
	var mixed_diagonal := PlaceholderPlayer.resolve_keyboard_direction(Vector2.UP, Vector2.RIGHT, false)
	_expect_float(mixed_same.length(), 1.0, "Mixed equivalent WASD and arrow input must not double movement speed or MR consumption.")
	_expect_float(mixed_diagonal.length(), 1.0, "Mixed diagonal WASD and arrow input must remain normalized.")
	_expect_equal(PlaceholderPlayer.resolve_keyboard_direction(Vector2.RIGHT, Vector2.LEFT, false), Vector2.ZERO, "Opposed WASD and arrow inputs must cancel rather than adding speed.")
	_expect_equal(PlaceholderPlayer.resolve_keyboard_direction(Vector2.RIGHT, Vector2.RIGHT, true), Vector2.ZERO, "Focused HUD or text controls must block arrow and WASD gameplay movement.")
	_expect_true(PlaceholderPlayer.resolve_keyboard_run(true, false), "Shift must remain active for arrow-key Running during gameplay.")
	_expect_true(not PlaceholderPlayer.resolve_keyboard_run(true, true), "Focused HUD or text controls must block Shift-to-Run with arrow keys.")

	var wasd_model := PrimeMovementModel.new(12, 12, 10, 3)
	var arrow_model := PrimeMovementModel.new(12, 12, 10, 3)
	_expect_equal(wasd_model.request_running(), PrimeMovementModel.RunningRequestResult.ACTIVATED, "The verified automatic Running fixture must activate for Shift+WASD comparison.")
	_expect_equal(arrow_model.request_running(), PrimeMovementModel.RunningRequestResult.ACTIVATED, "Shift+Arrow must activate the same verified Running model.")
	wasd_model.advance(1_000_000, wasd_right)
	arrow_model.advance(1_000_000, arrow_right)
	_expect_equal(arrow_model.to_dictionary(), wasd_model.to_dictionary(), "Shift+Arrow and Shift+WASD must produce identical Running, endurance, recovery, direction and distance state.")


func _test_mouse_hold_frame_independence_and_convergence() -> void:
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
	coarse_controller.set_mouse_attack_for_testing((coarse.get_node("Opponent") as Node2D).global_position, true)
	fine_controller.set_mouse_attack_for_testing((fine.get_node("Opponent") as Node2D).global_position, true)
	coarse_controller.advance_combat_for_testing(5_000_000)
	for _step in range(100):
		fine_controller.advance_combat_for_testing(50_000)
	var coarse_session := coarse_controller.get_combat_session_for_testing()
	var fine_session := fine_controller.get_combat_session_for_testing()
	_expect_equal(_serialize_events(coarse_session.get_resolved_events()), _serialize_events(fine_session.get_resolved_events()), "Mouse-held attacks must preserve exact authoritative history across rendered-frame partitions.")
	_expect_equal(coarse_session.get_state_snapshot(), fine_session.get_state_snapshot(), "Mouse-held attacks must preserve final state and digest inputs across rendered-frame partitions.")

	var client_a := ObservedCombatClient.new("mouse_hold_a")
	var client_b := ObservedCombatClient.new("mouse_hold_b")
	var events := coarse_session.get_resolved_events()
	var snapshot := coarse_session.get_state_snapshot()
	var envelopes: Array[CombatEventEnvelope] = []
	for sequence in range(events.size()):
		envelopes.append(CombatEventEnvelope.new(sequence, (events[sequence] as CombatEvent).to_dictionary(), snapshot))
	for envelope: CombatEventEnvelope in envelopes:
		client_a.receive(envelope)
	for index in range(envelopes.size() - 1, -1, -1):
		client_b.receive(envelopes[index])
	_expect_true(SynchronizationReport.compare_clients([client_a, client_b]).get("success", false), "Mouse-held authoritative history must converge for in-order and out-of-order simulated clients.")
	coarse.free()
	fine.free()


func _make_ready_scene() -> Node:
	var packed: PackedScene = load("res://scenes/test_arena.tscn")
	var scene := packed.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		_failures.append("SceneTree unavailable for Task 31N integration tests.")
		scene.free()
		return null
	tree.root.add_child(scene)
	var controller: ArenaCombatController = scene.get_node("CombatController")
	var fixture_result := controller.select_encounter_fixture_for_testing(Fixture.ENCOUNTER_MEDIUM_GUARDS)
	_expect_true(fixture_result.get("success", false), "The Task 31N legacy input fixture must explicitly select the Guard duel.")
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


func _make_wave_scene(seed: int, at_value: int) -> Node:
	var scene := _make_ready_scene()
	if scene == null:
		return null
	var controller: ArenaCombatController = scene.get_node("CombatController")
	controller.combat_seed = seed
	var selection := controller.select_encounter_fixture_for_testing(Fixture.ENCOUNTER_WAVE_ONE_GOBLINS)
	_expect_true(selection.get("success", false), "The Wave 1 fixture must be selectable for Task 31N target tests.")
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
	var count := 0
	for event: CombatEvent in session.get_resolved_events():
		if String(event.event_type) == "physical_attack_declared" and event.source_actor_id == Fixture.PLAYER_ID:
			count += 1
	return count


func _serialize_events(events: Array) -> Array:
	var serialized: Array = []
	for event: CombatEvent in events:
		serialized.append(event.to_dictionary())
	return serialized


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s Expected %s, got %s." % [message, str(expected), str(actual)])


func _expect_float(actual: float, expected: float, message: String) -> void:
	if not is_equal_approx(actual, expected):
		_failures.append("%s Expected %.6f, got %.6f." % [message, expected, actual])


func _expect_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)
