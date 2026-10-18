class_name SeedFocusTargetHudTests
extends RefCounted

const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
const ResponsiveLayout = preload("res://scripts/ui/arena_responsive_layout.gd")

var _failures: Array[String] = []


func run() -> Array[String]:
	_failures.clear()
	_test_seed_focus_lifecycle_and_target_cycle()
	_test_responsive_hud_regions_do_not_overlap()
	return _failures


func _test_seed_focus_lifecycle_and_target_cycle() -> void:
	var scene := _make_scene()
	if scene == null:
		return
	var controller: ArenaCombatController = scene.get_node("CombatController")
	var seed_input := scene.get_node("HUD/UI/SeedInput") as LineEdit
	var ready := controller.get_seed_ui_state_for_testing()
	_expect_true(ready.get("input_visible", false) and ready.get("apply_visible", false), "READY must show the editable seed input and APPLY control.")
	_expect_true(not ready.get("input_disabled", true) and not ready.get("apply_disabled", true), "READY seed controls must be enabled.")
	seed_input.grab_focus()
	_expect_true(seed_input.has_focus(), "Seed entry must retain normal text focus before START.")
	_expect_true(controller.set_seed_text_for_testing("7").get("success", false), "Seed 7 must remain a valid READY-state seed.")
	_expect_true(controller.select_encounter_fixture_for_testing(Fixture.ENCOUNTER_WAVE_ONE_GOBLINS).get("success", false), "Wave 1 must remain selectable after seed entry.")
	var session := controller.get_combat_session_for_testing()
	_expect_equal(session.get_targetable_enemy_ids().size(), 4, "Seed 7 must still produce four authoritative Goblins.")
	seed_input.grab_focus()
	controller.press_encounter_control_for_testing()
	var active := controller.get_seed_ui_state_for_testing()
	_expect_true(not active.get("input_visible", true) and not active.get("apply_visible", true), "ACTIVE must hide seed editing controls.")
	_expect_true(not active.get("input_has_focus", true) and not active.get("apply_has_focus", true), "Hidden seed controls must release keyboard focus.")
	_expect_equal(active.get("label"), "SEED 7", "ACTIVE must retain a read-only authoritative seed indicator.")

	var visited := {}
	visited[String(session.get_selected_target_id())] = true
	for _index in range(session.get_targetable_enemy_ids().size()):
		_send_tab(controller, false)
		visited[String(session.get_selected_target_id())] = true
	_expect_equal(visited.size(), 4, "Active Tab cycling must reach every living Goblin even after seed entry held focus.")
	var forward_target := session.get_selected_target_id()
	_send_tab(controller, true)
	_expect_true(session.get_selected_target_id() != forward_target, "Shift+Tab must cycle backward during active combat.")

	var living_ids := session.get_targetable_enemy_ids()
	var defeated_id := StringName(living_ids[1])
	session.get_actor_state(defeated_id).current_hpc = 0
	for _index in range(6):
		_send_tab(controller, false)
		_expect_true(session.get_selected_target_id() != defeated_id, "Keyboard cycling must skip a defeated Goblin.")

	var selectable_ids := session.get_targetable_enemy_ids()
	var touch_target := StringName(selectable_ids[0])
	var touch_visual := controller._get_enemy_visual(touch_target)
	_expect_true(touch_visual != null, "The touch-selection regression requires a living Goblin visual.")
	if touch_visual != null:
		var touch_result := controller.request_pointer_action_for_testing(touch_visual.global_position, false)
		_expect_equal(StringName(touch_result.get("selection", {}).get("target_id", &"")), touch_target, "Touch selection must remain functional.")
	var mouse_target := StringName(selectable_ids[selectable_ids.size() - 1])
	var mouse_visual := controller._get_enemy_visual(mouse_target)
	_expect_true(mouse_visual != null, "The mouse-selection regression requires a living Goblin visual.")
	if mouse_visual != null:
		var mouse_result := controller.request_pointer_action_for_testing(mouse_visual.global_position, true)
		_expect_equal(StringName(mouse_result.get("selection", {}).get("target_id", &"")), mouse_target, "Desktop click selection must remain functional.")
	_expect_equal(controller.get_seed_ui_state_for_testing().get("authoritative_seed"), 7, "Target switching must never apply or mutate a seed.")
	_expect_true(not controller.set_seed_text_for_testing("3").get("success", false), "Programmatic seed mutation must remain rejected during ACTIVE.")

	controller.press_encounter_control_for_testing()
	var reset := controller.get_seed_ui_state_for_testing()
	_expect_true(reset.get("input_visible", false) and reset.get("apply_visible", false), "RESET must restore seed editing controls.")
	_expect_true(not reset.get("input_disabled", true) and not reset.get("apply_disabled", true), "RESET seed controls must be enabled.")
	_expect_equal(reset.get("authoritative_seed"), 7, "RESET must retain the selected seed.")
	_expect_equal(reset.get("input"), "7", "RESET must restore the retained seed text.")
	_free_scene(scene)


func _test_responsive_hud_regions_do_not_overlap() -> void:
	for viewport_size in [Vector2(1152.0, 648.0), Vector2(960.0, 540.0), Vector2(800.0, 450.0)]:
		var layout := ResponsiveLayout.calculate_layout(viewport_size, viewport_size)
		var seed_label: Rect2 = layout["seed_label_rect"]
		var seed_input: Rect2 = layout["seed_input_rect"]
		var seed_apply: Rect2 = layout["seed_apply_button_rect"]
		var movement: Rect2 = layout["movement_debug_rect"]
		var status: Rect2 = layout["combat_status_rect"]
		var attack: Rect2 = layout["attack_readiness_rect"]
		var run: Rect2 = layout["run_readiness_rect"]
		var log_rect: Rect2 = layout["combat_log_rect"]
		for named_rect in [
			["seed label", seed_label], ["seed input", seed_input], ["seed apply", seed_apply],
			["movement", movement], ["combat status", status], ["attack readiness", attack],
			["run readiness", run], ["combat log", log_rect],
		]:
			_expect_rect_inside(named_rect[1], viewport_size, "%s at %s" % [named_rect[0], viewport_size])
		_expect_true(not seed_label.intersects(movement) and not seed_input.intersects(movement) and not seed_apply.intersects(movement), "Seed setup and movement status must not overlap at %s." % viewport_size)
		_expect_true(not movement.intersects(status), "Movement and combat status must remain vertically separated at %s." % viewport_size)
		_expect_true(status.end.x <= viewport_size.x * 0.32, "Combat status must leave the central actor-label lane clear at %s." % viewport_size)
		_expect_true(not status.intersects(attack) and not status.intersects(run), "Combat status must not overlap readiness indicators at %s." % viewport_size)
		_expect_true(not status.intersects(log_rect), "Combat status and recent results must use separate columns at %s." % viewport_size)
		_expect_true(not attack.intersects(run), "ATTACK and RUN readiness indicators must remain separate at %s." % viewport_size)

	var reference := ResponsiveLayout.calculate_layout(Vector2(1152.0, 648.0), Vector2(1152.0, 648.0))
	var player_label := Rect2(Vector2(438.0, 283.6), Vector2(116.0, 44.0))
	var opponent_label := Rect2(Vector2(684.4, 283.6), Vector2(126.0, 44.0))
	_expect_true(not (reference["combat_status_rect"] as Rect2).intersects(player_label), "The reference desktop combat-status column must not cross the player HPC label.")
	_expect_true(not (reference["attack_readiness_rect"] as Rect2).intersects(opponent_label), "The reference desktop ATTACK indicator must not cross the opponent HPC label.")
	_expect_true(not (reference["run_readiness_rect"] as Rect2).intersects(opponent_label), "The reference desktop RUN indicator must not cross the opponent HPC label.")
	_expect_true(not (reference["combat_log_rect"] as Rect2).intersects(opponent_label), "The reference desktop recent-results panel must not cross the opponent HPC label.")


func _send_tab(controller: ArenaCombatController, backwards: bool) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = KEY_TAB
	event.shift_pressed = backwards
	controller._input(event)


func _make_scene() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		_failures.append("SceneTree unavailable for Task 31I UI verification.")
		return null
	var packed: PackedScene = load("res://scenes/test_arena.tscn")
	var scene := packed.instantiate()
	tree.root.add_child(scene)
	return scene


func _free_scene(scene: Node) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and scene.get_parent() == tree.root:
		tree.root.remove_child(scene)
	scene.free()


func _expect_rect_inside(rect: Rect2, bounds: Vector2, label: String) -> void:
	_expect_true(rect.position.x >= 0.0 and rect.position.y >= 0.0 and rect.end.x <= bounds.x and rect.end.y <= bounds.y, "%s must remain inside the viewport; got %s." % [label, rect])


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s Expected %s, got %s." % [message, str(expected), str(actual)])


func _expect_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)
