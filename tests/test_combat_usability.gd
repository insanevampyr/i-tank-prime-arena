extends RefCounted

const Session = preload("res://scripts/combat/arena_combat_session.gd")
const Battlefield = preload("res://scripts/combat/arena_battlefield.gd")
const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
const Controller = preload("res://scripts/ui/arena_combat_controller.gd")
const ResponsiveLayout = preload("res://scripts/ui/arena_responsive_layout.gd")
const RunningSkillCheckRule = preload("res://scripts/movement/running_skill_check.gd")
const PrimeMovement = preload("res://scripts/movement/prime_movement_model.gd")
const PlayerInputIntent = preload("res://scripts/input/arena_player_input_intent.gd")

const PLAYER_START := Vector2i(35_000_000, 14_000_000)
const OPPONENT_START := Vector2i(25_000_000, 14_000_000)

var _failures: Array[String] = []


func run() -> Array[String]:
	_test_pointer_attack_and_selection_routing()
	_test_keyboard_shortcut_and_debug_overlay()
	_test_stable_repathing_and_attack_transition()
	_test_running_fixture_calculation_and_shared_intent()
	_test_responsive_hud_regions()
	return _failures


func _test_pointer_attack_and_selection_routing() -> void:
	_expect_true(Controller.is_pointer_over_target(Vector2(10, 10), Vector2(20, 10), 10.0), "A boundary left click must hit the target once.")
	_expect_true(not Controller.is_pointer_over_target(Vector2.ZERO, Vector2(50, 0), 40.0), "Empty terrain must not classify as the target.")
	var scene := _make_scene()
	if scene == null:
		return
	var controller: ArenaCombatController = scene.get_node("CombatController")
	var prestart_session := controller.get_combat_session_for_testing()
	var prestart_position := prestart_session.get_actor_state(Fixture.PLAYER_ID).position_microfeet
	var prestart_motion := prestart_session.request_player_movement(prestart_position, 12)
	_expect_equal(prestart_motion.get("position_microfeet"), prestart_position, "An inactive encounter must preserve the authoritative player position instead of snapping presentation to zero.")
	controller.press_encounter_control_for_testing()
	var session := controller.get_combat_session_for_testing()
	var opponent: Node2D = scene.get_node("Opponent")
	var declarations_before := _count_events(session, "physical_attack_declared", Fixture.PLAYER_ID)
	var first := controller.request_pointer_action_for_testing(opponent.global_position, true)
	_expect_true(first.get("attack", {}).get("success", false), "A deliberate desktop click on the selected enemy must request one legal attack.")
	_expect_equal(_count_events(session, "physical_attack_declared", Fixture.PLAYER_ID), declarations_before + 1, "One desktop click must produce exactly one authoritative declaration.")
	var repeated := controller.request_pointer_action_for_testing(opponent.global_position, true)
	_expect_equal(repeated.get("attack", {}).get("reason"), "attack_in_progress", "A repeated click during execution must be rejected rather than queued.")
	_expect_equal(_count_events(session, "physical_attack_declared", Fixture.PLAYER_ID), declarations_before + 1, "A rejected repeat click must not duplicate the declaration.")
	controller.request_pointer_action_for_testing(Vector2.ZERO, true)
	_expect_equal(session.get_selected_target_id(), &"", "Clicking empty terrain must clear selection without attacking.")
	scene.free()

	var touch_scene := _make_scene()
	if touch_scene == null:
		return
	var touch_controller: ArenaCombatController = touch_scene.get_node("CombatController")
	touch_controller.press_encounter_control_for_testing()
	var touch_session := touch_controller.get_combat_session_for_testing()
	var touch_opponent: Node2D = touch_scene.get_node("Opponent")
	var touch_result := touch_controller.request_pointer_action_for_testing(touch_opponent.global_position, false)
	_expect_true(touch_result.get("selection", {}).get("success", false), "A mobile tap on the enemy must select it.")
	_expect_true(touch_result.get("attack") == null, "A mobile target tap must not also duplicate the separate ATTACK-button intent.")
	_expect_equal(_count_events(touch_session, "physical_attack_declared", Fixture.PLAYER_ID), 0, "Mobile selection alone must not declare an attack.")
	touch_scene.free()


func _test_keyboard_shortcut_and_debug_overlay() -> void:
	var scene := _make_scene()
	if scene == null:
		return
	var controller: ArenaCombatController = scene.get_node("CombatController")
	controller.press_encounter_control_for_testing()
	_expect_true(not controller.is_debug_overlay_visible(), "The technical overlay must be hidden by default.")
	var debug_button: Button = scene.get_node("HUD/UI/DebugButton")
	debug_button.pressed.emit()
	_expect_true(controller.is_debug_overlay_visible(), "The technical overlay must remain available through its visible desktop toggle.")
	debug_button.pressed.emit()
	_expect_true(not controller.is_debug_overlay_visible(), "The visible debug toggle must restore the clean default HUD.")
	var key := InputEventKey.new()
	key.pressed = true
	key.physical_keycode = KEY_SPACE
	controller._unhandled_input(key)
	_expect_equal(_count_events(controller.get_combat_session_for_testing(), "physical_attack_declared", Fixture.PLAYER_ID), 1, "Space must retain the same one-shot authoritative attack pathway.")
	scene.free()


func _test_stable_repathing_and_attack_transition() -> void:
	var seed_value := _find_opponent_opening_seed()
	_expect_true(seed_value > 0, "A deterministic opponent-opening seed must exist for pursuit tests.")
	if seed_value <= 0:
		return
	var first := _make_pursuit_session(seed_value)
	var second := _make_pursuit_session(seed_value)
	var initial_rebuilds := first.get_opponent_path_rebuild_count_for_testing()
	_expect_equal(initial_rebuilds, 1, "The initial out-of-range pursuit must build one route.")
	for session: ArenaCombatSession in [first, second]:
		for _step in range(4):
			var player_state := session.get_actor_state(Fixture.PLAYER_ID)
			session.request_player_movement(player_state.position_microfeet + Vector2i(200_000, 0), 12)
			session.advance_by(100_000)
	_expect_equal(first.get_opponent_path_rebuild_count_for_testing(), initial_rebuilds, "Sub-foot target motion must not discard and rebuild the route every simulation tick.")
	for session: ArenaCombatSession in [first, second]:
		var player_state := session.get_actor_state(Fixture.PLAYER_ID)
		session.request_player_movement(player_state.position_microfeet + Vector2i(400_000, 0), 12)
		session.advance_by(100_000)
	_expect_equal(first.get_opponent_path_rebuild_count_for_testing(), initial_rebuilds + 1, "A cumulative one-foot target change must deterministically request a fresh route.")
	first.advance_by(15_000_000)
	second.advance_by(15_000_000)
	_expect_true(_count_events(first, "actor_position_changed", Fixture.OPPONENT_ID) > 0, "The opponent must make authoritative progress around the obstacle.")
	_expect_true(_count_events(first, "physical_attack_declared", Fixture.OPPONENT_ID) > 0, "Pursuit must transition to the existing legal attack pipeline once range and line of sight are satisfied.")
	_expect_equal(first.get_state_snapshot(), second.get_state_snapshot(), "Target-change repathing and attack transition must replay deterministically.")
	_expect_equal(_serialize_events(first.get_resolved_events()), _serialize_events(second.get_resolved_events()), "Pursuit event histories must be identical for the same seed and inputs.")


func _test_running_fixture_calculation_and_shared_intent() -> void:
	var actor := Fixture.make_guard_actor(Fixture.PLAYER_ID, "Player Guard Fixture")
	_expect_equal(actor.attributes.get("spd"), 12, "The blue fixture SPD must remain the verified Guard value 12.")
	_expect_equal(actor.attributes.get("end"), 10, "The blue fixture END must remain the verified Guard value 10.")
	_expect_equal(actor.get_combat_stat("mr"), 12, "The blue fixture walking MR must remain 12.")
	_expect_equal(Fixture.PLAYER_RUNNING_SKILL_INVESTMENT, 3, "The explicit movement-test profile must retain three Running investments.")
	_expect_equal(Fixture.PLAYER_RUNNING_SCM, 0, "The explicit movement-test profile must retain SCM 0.")
	_expect_equal(actor.get_combat_stat("rb"), 0, "The blue fixture RB must remain 0.")
	_expect_equal(RunningSkillCheckRule.get_target(10, 0, 3), 10, "END 10 plus the third-investment skill modifier 0 plus SCM 0 must produce Running target 10.")
	_expect_true(RunningSkillCheckRule.is_automatic(3), "Three Running investments must bypass activation and maintenance rolls.")
	var model := PrimeMovement.new(12, 12, 10, 3, 0, 0)
	_expect_equal(model.get_running_bonus_mr(), 6, "Successful Running must add floor(SPD 12 / 2) = 6 MR.")
	_expect_equal(model.request_running(), PrimeMovement.RunningRequestResult.ACTIVATED, "The fixture's automatic Running must activate without a d20 draw.")
	_expect_equal(model.get_effective_mr(), 18, "The active fixture must move at MR 18 without stacking.")
	_expect_equal(model.get_max_running_duration_us(), 50_000_000, "END 10 must cap continuous Running at 50 seconds.")
	model.advance(2_000_000, Vector2.RIGHT)
	model.stop_running(PrimeMovement.RunningEndReason.SHIFT_RELEASED)
	_expect_equal(model.get_recovery_remaining_us(), 2_000_000, "Two seconds of actual Running must create two seconds of recovery debt.")
	_expect_equal(model.get_running_retry_cooldown_us(), 0, "Voluntary release by an automatic runner must not fabricate a failed-check cooldown.")
	_expect_true(PlayerInputIntent.combine_run(true, false), "Shift must request the shared Running intent.")
	_expect_true(PlayerInputIntent.combine_run(false, true), "Touch RUN must request the same shared Running intent.")


func _test_responsive_hud_regions() -> void:
	for size: Vector2 in [Vector2(800, 360), Vector2(915, 412), Vector2(1280, 720)]:
		var layout := ResponsiveLayout.calculate_layout(size)
		var overlay: Rect2 = layout["developer_debug_rect"]
		var movement: Rect2 = layout["movement_debug_rect"]
		var status: Rect2 = layout["combat_status_rect"]
		var log: Rect2 = layout["combat_log_rect"]
		_expect_true(overlay.position.x >= 0.0 and overlay.position.y >= 0.0, "The debug overlay must start inside the viewport.")
		_expect_true(overlay.end.x <= size.x and overlay.end.y <= float(layout["touch_control_top"]), "The responsive debug overlay must stay above touch controls and inside the viewport.")
		_expect_true(not movement.intersects(status), "Movement and combat status regions must not overlap.")
		_expect_true(not status.intersects(log), "Player status and combat-result regions must not overlap in landscape layouts.")


func _make_scene() -> Node:
	var packed: PackedScene = load("res://scenes/test_arena.tscn")
	var scene := packed.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		_failures.append("SceneTree unavailable for input/HUD integration test.")
		scene.free()
		return null
	tree.root.add_child(scene)
	return scene


func _make_pursuit_session(seed_value: int) -> ArenaCombatSession:
	var session := ArenaCombatSession.new(seed_value)
	session.configure_battlefield(Battlefield.create_task16_test_arena())
	var result := session.initialize(PLAYER_START, OPPONENT_START)
	_expect_true(result.get("success", false), "The authored pursuit fixture must initialize.")
	session.set_opponent_behavior_enabled(true)
	return session


func _find_opponent_opening_seed() -> int:
	for seed_value in range(1, 500):
		var session := ArenaCombatSession.new(seed_value)
		session.configure_battlefield(Battlefield.create_task16_test_arena())
		if not session.initialize(PLAYER_START, OPPONENT_START).get("success", false):
			continue
		if int(session.get_actor_state(Fixture.OPPONENT_ID).opening_order_rank) == 0:
			return seed_value
	return 0


func _count_events(session: ArenaCombatSession, event_type: String, actor_id: StringName) -> int:
	var count := 0
	for event: CombatEvent in session.get_resolved_events():
		if String(event.event_type) == event_type and event.source_actor_id == actor_id:
			count += 1
	return count


func _serialize_events(events: Array) -> Array:
	var result: Array = []
	for event: CombatEvent in events:
		result.append(event.to_dictionary())
	return result


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s Expected %s, got %s." % [message, str(expected), str(actual)])


func _expect_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)
