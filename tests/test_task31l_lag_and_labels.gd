class_name Task31LLagAndLabelTests
extends RefCounted

const ArenaBattlefield = preload("res://scripts/combat/arena_battlefield.gd")
const ArenaCombatSession = preload("res://scripts/combat/arena_combat_session.gd")
const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")

const STEP_US := 100_000
const PLAYER_START := Vector2i(20_000_000, 12_000_000)
const GOBLIN_START := Vector2i(38_000_000, 12_000_000)

var _failures: Array[String] = []


func run() -> Array[String]:
	_failures.clear()
	_test_direct_path_broad_phase_preserves_collision_answers()
	_test_seed_seven_has_no_living_eligible_movement_stall()
	_test_actor_health_labels_remain_anchored()
	_test_health_label_values_death_and_reset()
	return _failures


func _test_direct_path_broad_phase_preserves_collision_answers() -> void:
	var battlefield := ArenaBattlefield.create_task16_test_arena()
	var mover := &"mover"
	var occupancy := {String(mover): Vector2i(20_000_000, 12_000_000)}
	var segments := [
		[Vector2i(20_000_000, 12_000_000), Vector2i(25_000_000, 12_000_000)],
		[Vector2i(28_000_000, 12_000_000), Vector2i(32_000_000, 12_000_000)],
		[Vector2i(28_000_000, 7_500_000), Vector2i(32_000_000, 7_500_000)],
		[Vector2i(28_000_000, 7_499_999), Vector2i(32_000_000, 7_499_999)],
		[Vector2i(28_000_000, 20_500_000), Vector2i(32_000_000, 20_500_000)],
	]
	for segment: Array in segments:
		var start: Vector2i = segment[0]
		var finish: Vector2i = segment[1]
		var exact: bool = battlefield.is_position_legal(mover, finish, occupancy).get("legal", false) \
			and battlefield._furthest_legal_on_segment(mover, start, finish, occupancy) == finish
		var optimized: bool = battlefield.is_direct_path_clear(mover, start, finish, occupancy)
		_expect_equal(optimized, exact, "The direct-path broad phase must preserve exact obstacle legality for %s -> %s." % [start, finish])

	battlefield.reset_direct_path_exact_sample_count_for_testing()
	_expect_true(not battlefield.is_direct_path_clear(mover, Vector2i(28_000_000, 12_000_000), Vector2i(32_000_000, 12_000_000), occupancy), "A segment through the center wall must remain blocked.")
	_expect_equal(battlefield.get_direct_path_exact_sample_count_for_testing(), 0, "A definite wall crossing must be rejected before the expensive sampled resolver.")


func _test_seed_seven_has_no_living_eligible_movement_stall() -> void:
	var session := ArenaCombatSession.new(3, null, Fixture.ENCOUNTER_WAVE_ONE_GOBLINS)
	session.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
	session.set_opponent_behavior_enabled(true)
	var initialized := session.initialize_wave_one_goblins(PLAYER_START, GOBLIN_START, true)
	_expect_true(initialized.get("success", false), "The four-Goblin lag regression must initialize.")
	if not initialized.get("success", false):
		return
	session.get_actor_state(Fixture.PLAYER_ID).current_hpc = 1_000_000
	var goblin_ids: Array = session.get_targetable_enemy_ids()
	_expect_equal(goblin_ids.size(), 4, "The representative seed must continue to produce the four-Goblin wave.")
	var previous_positions := {}
	var eligible_stall_ticks := {}
	var maximum_eligible_stall_ticks := {}
	for actor_id: String in goblin_ids:
		previous_positions[actor_id] = session.get_actor_state(StringName(actor_id)).position_microfeet
		eligible_stall_ticks[actor_id] = 0
		maximum_eligible_stall_ticks[actor_id] = 0
	var direction := 1
	for tick in range(300):
		if tick > 0 and tick % 20 == 0:
			direction *= -1
		var player_state := session.get_actor_state(Fixture.PLAYER_ID)
		session.request_player_movement(player_state.position_microfeet + Vector2i(direction * 100_000, 0), 11)
		session.advance_by(STEP_US)
		for actor_id: String in goblin_ids:
			var state := session.get_actor_state(StringName(actor_id))
			var geometry := session._get_actor_attack_geometry(StringName(actor_id), Fixture.PLAYER_ID)
			var eligible_to_move: bool = state.current_hpc != null and int(state.current_hpc) > 0 \
				and not bool(geometry.get("success", false)) \
				and state.current_action_instance_id.is_empty() \
				and not session._is_actor_attack_in_flight(StringName(actor_id)) \
				and state.critical_stagger_until_us <= session.simulation.clock.get_elapsed_us() \
				and not state.conditions.has("prone") \
				and int(session._goblin_movement_spent.get(actor_id, 0)) < 6_000_000
			if eligible_to_move and state.position_microfeet == previous_positions[actor_id]:
				eligible_stall_ticks[actor_id] = int(eligible_stall_ticks[actor_id]) + 1
				maximum_eligible_stall_ticks[actor_id] = maxi(int(maximum_eligible_stall_ticks[actor_id]), int(eligible_stall_ticks[actor_id]))
			else:
				eligible_stall_ticks[actor_id] = 0
			previous_positions[actor_id] = state.position_microfeet
	for actor_id: String in goblin_ids:
		_expect_true(int(maximum_eligible_stall_ticks[actor_id]) <= 2, "Living %s must not remain stationary while legally eligible to pursue; maximum was %d behavior ticks." % [actor_id, maximum_eligible_stall_ticks[actor_id]])


func _test_actor_health_labels_remain_anchored() -> void:
	var scene := _make_scene()
	if scene == null:
		return
	var controller: ArenaCombatController = scene.get_node("CombatController")
	_expect_true(controller.set_seed_text_for_testing("3").get("success", false), "The label regression requires the representative four-Goblin seed.")
	_expect_true(controller.select_encounter_fixture_for_testing(Fixture.ENCOUNTER_WAVE_ONE_GOBLINS).get("success", false), "Wave 1 must remain selectable for the label regression.")
	var session := controller.get_combat_session_for_testing()
	var goblin_ids: Array = session.get_targetable_enemy_ids()
	var formations := [
		[
			Vector2i(26_000_000, 7_000_000),
			Vector2i(28_000_000, 7_000_000),
			Vector2i(32_000_000, 7_000_000),
			Vector2i(34_000_000, 7_000_000),
		],
		[
			Vector2i(19_000_000, 11_000_000),
			Vector2i(20_000_000, 11_000_000),
			Vector2i(19_000_000, 12_000_000),
			Vector2i(20_000_000, 12_000_000),
		],
		[
			Vector2i(2_500_000, 2_500_000),
			Vector2i(45_500_000, 2_500_000),
			Vector2i(2_500_000, 24_500_000),
			Vector2i(45_500_000, 24_500_000),
		],
	]
	for formation: Array in formations:
		for index in range(goblin_ids.size()):
			session.get_actor_state(StringName(goblin_ids[index])).position_microfeet = formation[index]
		for viewport_size in [Vector2(1152.0, 648.0), Vector2(800.0, 450.0), Vector2(1920.0, 1080.0)]:
			scene.call("_apply_layout", viewport_size, viewport_size)
			controller.call("_refresh_non_player_actor_positions")
			var state_before_render: Dictionary = session.get_state_snapshot()
			var event_count_before_render := session.get_resolved_event_count()
			controller.update_presentation_for_testing()
			_verify_fixed_label_layout(controller, session, goblin_ids, viewport_size)
			_expect_equal(session.get_state_snapshot(), state_before_render, "Health-label rendering must not mutate authoritative state or RNG state.")
			_expect_equal(session.get_resolved_event_count(), event_count_before_render, "Health-label rendering must not append authoritative events.")

	var tracked_id := StringName(goblin_ids[0])
	var tracked_visual := controller._get_enemy_visual(tracked_id)
	var tracked_label := tracked_visual.get_node("Label") as Label
	session.get_actor_state(tracked_id).position_microfeet = Vector2i(18_000_000, 10_000_000)
	controller.call("_refresh_non_player_actor_positions")
	controller.update_presentation_for_testing()
	var initial_actor_position := tracked_visual.global_position
	var initial_label_position := tracked_label.global_position
	session.get_actor_state(tracked_id).position_microfeet = Vector2i(20_500_000, 12_500_000)
	controller.call("_refresh_non_player_actor_positions")
	controller.update_presentation_for_testing()
	_expect_true(tracked_visual.global_position - initial_actor_position == tracked_label.global_position - initial_label_position, "An actor-relative health label must follow diagonal movement exactly.")
	_free_scene(scene)


func _verify_fixed_label_layout(controller: ArenaCombatController, session: ArenaCombatSession, goblin_ids: Array, viewport_size: Vector2) -> void:
	var player_label := controller._player_hpc_label as Label
	_expect_equal(player_label.text, "HPC 100/100", "The player label must display mutable HPC over source HPM without an invented resource.")
	_expect_equal(player_label.mouse_filter, Control.MOUSE_FILTER_IGNORE, "The player health label must not intercept pointer input.")
	_expect_true(is_equal_approx(player_label.get_theme_color("font_color").a, ArenaCombatController.ACTOR_HPC_LABEL_TEXT_ALPHA), "The player label text must use the approved semitransparent presentation.")
	_expect_actor_label_anchor(controller._player, player_label, "player", viewport_size)
	var selected_id := session.get_selected_target_id()
	_expect_true(controller._target_indicator.visible, "The selected-target outline must remain visible while health labels render.")
	for actor_id: String in goblin_ids:
		var visual := controller._get_enemy_visual(StringName(actor_id))
		var label := visual.get_node("Label") as Label
		var state := session.get_actor_state(StringName(actor_id))
		_expect_true(label.visible, "%s living health label must remain visible even in a dense cluster." % actor_id)
		_expect_equal(label.mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s HPC label must not intercept target clicks." % actor_id)
		_expect_equal(label.text, "%s | HPC %s/%s" % [ArenaCombatController.compact_actor_name(StringName(actor_id)).replace("GOBLIN ", "G"), state.current_hpc, session.get_actor_max_hpm(StringName(actor_id))], "%s must display its own authoritative HPC and HPM." % actor_id)
		_expect_true(is_equal_approx(label.get_theme_color("font_color").a, ArenaCombatController.ACTOR_HPC_LABEL_TEXT_ALPHA), "%s must use semitransparent label text." % actor_id)
		_expect_actor_label_anchor(visual, label, actor_id, viewport_size)
		var marker := visual.get_node("FacingMarker") as Polygon2D
		_expect_true(marker.visible, "%s facing arrow must remain visible with the anchored label." % actor_id)
		if StringName(actor_id) == selected_id:
			_expect_true(controller._target_indicator.global_position.is_equal_approx(visual.global_position), "The target outline must remain aligned with the selected Goblin.")


func _test_health_label_values_death_and_reset() -> void:
	var scene := _make_scene()
	if scene == null:
		return
	var controller: ArenaCombatController = scene.get_node("CombatController")
	var session := controller.get_combat_session_for_testing()
	var player_label := controller._player_hpc_label as Label
	var opponent_label := controller._opponent_hpc_label as Label
	_expect_equal(player_label.text, "HPC 100/100", "The default player label must use the approved compact format.")
	_expect_equal(opponent_label.text, "GUARD | HPC 100/100", "The default Guard label must identify its fixture and health.")
	_expect_equal(opponent_label.mouse_filter, Control.MOUSE_FILTER_IGNORE, "The opponent health label must not intercept pointer input.")
	_expect_true(controller._player_facing_marker.visible and controller._opponent_facing_marker.visible, "Anchored health labels must preserve living Guard facing arrows.")
	controller.press_encounter_control_for_testing()
	session.get_actor_state(Fixture.OPPONENT_ID).current_hpc = 0
	controller.update_presentation_for_testing()
	_expect_true(not opponent_label.visible, "A defeated Guard must lose its health label.")
	controller.press_encounter_control_for_testing()
	_expect_true(opponent_label.visible and opponent_label.text == "GUARD | HPC 100/100", "RESET must restore the Guard health label and source HPM.")

	_expect_true(controller.select_encounter_fixture_for_testing(Fixture.ENCOUNTER_SYNTHETIC_SMALL_GUARD).get("success", false), "The Synthetic Small fixture must remain selectable.")
	opponent_label = controller._opponent_hpc_label as Label
	_expect_equal(opponent_label.text, "SYNTHETIC SMALL* | HPC 100/100", "The Synthetic Small fixture must retain explicit test-only identification.")

	_expect_true(controller.select_encounter_fixture_for_testing(Fixture.ENCOUNTER_WAVE_ONE_GOBLINS).get("success", false), "Wave 1 must remain selectable for death/reset label coverage.")
	controller.press_encounter_control_for_testing()
	session = controller.get_combat_session_for_testing()
	var goblin_id := session.get_selected_target_id()
	var goblin_visual := controller._get_enemy_visual(goblin_id)
	var goblin_label := goblin_visual.get_node("Label") as Label
	session.get_actor_state(goblin_id).current_hpc = 0
	controller.call("_refresh_non_player_actor_positions")
	controller.update_presentation_for_testing()
	_expect_true(not goblin_label.visible, "A defeated Goblin must lose its actor-attached health label.")
	controller.press_encounter_control_for_testing()
	session = controller.get_combat_session_for_testing()
	goblin_id = session.get_selected_target_id()
	goblin_visual = controller._get_enemy_visual(goblin_id)
	goblin_label = goblin_visual.get_node("Label") as Label
	_expect_true(goblin_label.visible and goblin_label.text.ends_with("HPC 1/1"), "RESET must reconstruct living Goblin labels from authoritative health data.")
	_free_scene(scene)


func _expect_actor_label_anchor(actor: Node2D, label: Label, actor_name: String, viewport_size: Vector2) -> void:
	var scale := actor.scale.abs()
	var rect := Rect2(label.global_position, label.size * scale)
	var horizontal_offset := absf(rect.get_center().x - actor.global_position.x)
	_expect_true(horizontal_offset <= rect.size.x * 0.5 + 0.01, "%s label may only shift enough to remain on-screen." % actor_name)
	_expect_true(rect.end.y < actor.global_position.y, "%s label must remain directly above its actor." % actor_name)
	_expect_true(rect.position.x >= -0.01 and rect.end.x <= viewport_size.x + 0.01, "%s label must remain within horizontal screen bounds." % actor_name)
	_expect_true(rect.position.y >= -0.01 and rect.end.y <= viewport_size.y + 0.01, "%s label must remain within vertical screen bounds." % actor_name)
	if rect.position.x > 0.01 and rect.end.x < viewport_size.x - 0.01 and rect.position.y > 0.01:
		_expect_true(is_equal_approx(label.position.x + label.size.x * 0.5, 0.0), "%s unclamped label must remain horizontally centered." % actor_name)
		_expect_true(is_equal_approx(label.position.y, ArenaCombatController.ACTOR_HPC_LABEL_TOP), "%s unclamped label must use the single fixed vertical anchor." % actor_name)


func _make_scene() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		_failures.append("SceneTree unavailable for Task 31L label verification.")
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


func _expect_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s Expected %s, got %s." % [message, str(expected), str(actual)])
