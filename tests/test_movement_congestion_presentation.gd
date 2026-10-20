class_name MovementCongestionPresentationTests
extends RefCounted

const ArenaBattlefield = preload("res://scripts/combat/arena_battlefield.gd")
const ArenaCombatSession = preload("res://scripts/combat/arena_combat_session.gd")
const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
const ResponsiveLayout = preload("res://scripts/ui/arena_responsive_layout.gd")

const PLAYER_START := Vector2i(20_000_000, 12_000_000)
const GOBLIN_START := Vector2i(38_000_000, 12_000_000)
const DEFEATED_POSITION := Vector2i(21_000_000, 12_000_000)

var _failures: Array[String] = []


func run() -> Array[String]:
	_failures.clear()
	_test_defeated_goblin_does_not_block_player_movement()
	_test_last_goblin_pursues_after_three_defeats()
	_test_live_actor_congestion_preserves_a_legal_escape()
	_test_four_goblin_navigation_cost_remains_bounded()
	_test_responsive_battlefield_scale_and_targeting()
	return _failures


func _test_defeated_goblin_does_not_block_player_movement() -> void:
	var session := ArenaCombatSession.new(3, null, Fixture.ENCOUNTER_WAVE_ONE_GOBLINS)
	session.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
	session.set_opponent_behavior_enabled(true)
	var initialized := session.initialize_wave_one_goblins(PLAYER_START, GOBLIN_START, true)
	_expect_true(initialized.get("success", false), "The representative four-Goblin congestion fixture must initialize.")
	var goblin_ids: Array = session.get_targetable_enemy_ids()
	_expect_equal(goblin_ids.size(), 4, "The representative seed must retain the four-Goblin regression quantity.")
	if goblin_ids.size() != 4:
		return
	for index in range(3):
		var defeated_state := session.get_actor_state(StringName(goblin_ids[index]))
		defeated_state.current_hpc = 0
		defeated_state.position_microfeet = DEFEATED_POSITION if index == 0 else Vector2i(34_000_000 + index * 2_000_000, 18_000_000)
	var movement := session.request_player_movement(DEFEATED_POSITION, 11)
	print("METRIC: Task31J defeated-occupancy requested=%s resolved=%s blocked=%s" % [
		str(DEFEATED_POSITION), str(movement.get("position_microfeet", Vector2i.ZERO)), str(movement.get("blocked", true)),
	])
	_expect_true(movement.get("success", false), "A legal player movement request must remain accepted after three Goblins are defeated.")
	_expect_equal(
		movement.get("position_microfeet", Vector2i.ZERO),
		DEFEATED_POSITION,
		"A defeated Goblin's former position must not collision-lock the player."
	)
	_expect_true(not bool(movement.get("blocked", true)), "Defeated actors must not remain authoritative movement blockers.")


func _test_last_goblin_pursues_after_three_defeats() -> void:
	var sessions: Array[ArenaCombatSession] = []
	var signatures: Array[Array] = []
	for _replay_index in range(2):
		var session := _make_four_goblin_session()
		var ids: Array = session.get_targetable_enemy_ids()
		for index in range(3):
			session.get_actor_state(StringName(ids[index])).current_hpc = 0
		var survivor_id := StringName(ids[3])
		var survivor_start: Vector2i = session.get_actor_state(survivor_id).position_microfeet
		var initial_distance := _distance(survivor_start, session.get_actor_state(Fixture.PLAYER_ID).position_microfeet)
		var began_us := Time.get_ticks_usec()
		for _step in range(50):
			session.advance_by(100_000)
		var elapsed_us := Time.get_ticks_usec() - began_us
		var survivor_finish: Vector2i = session.get_actor_state(survivor_id).position_microfeet
		var final_distance := _distance(survivor_finish, session.get_actor_state(Fixture.PLAYER_ID).position_microfeet)
		var rebuild_count := int(session.get_goblin_path_rebuild_counts_for_testing().get(String(survivor_id), 0))
		var movement_events := _count_events(session, &"actor_position_changed", survivor_id)
		_expect_true(survivor_finish != survivor_start, "The final living Goblin must not remain position-locked after three defeats.")
		_expect_true(final_distance < initial_distance, "The final living Goblin must continue making net pursuit progress.")
		_expect_true(rebuild_count <= 4, "Defeated occupancy cleanup must not trigger repeated full route searches.")
		_expect_true(movement_events > 0, "The final living Goblin must retain complete authoritative movement events.")
		print("METRIC: Task31J post-defeat pursuit_us=%d rebuilds=%d movement_events=%d distance=%d->%d" % [
			elapsed_us, rebuild_count, movement_events, initial_distance, final_distance,
		])
		sessions.append(session)
		signatures.append(_event_signature(session))
	_expect_equal(signatures[0], signatures[1], "Post-defeat pursuit must reproduce identical authoritative event history.")
	_expect_equal(sessions[0].get_state_snapshot(), sessions[1].get_state_snapshot(), "Post-defeat pursuit must reproduce identical authoritative state.")


func _test_live_actor_congestion_preserves_a_legal_escape() -> void:
	var session := _make_four_goblin_session()
	var ids: Array = session.get_targetable_enemy_ids()
	var player := session.get_actor_state(Fixture.PLAYER_ID)
	player.position_microfeet = PLAYER_START
	session.get_actor_state(StringName(ids[0])).position_microfeet = PLAYER_START + Vector2i.RIGHT * 1_000_000
	session.get_actor_state(StringName(ids[1])).position_microfeet = PLAYER_START + Vector2i.UP * 1_000_000
	session.get_actor_state(StringName(ids[2])).position_microfeet = PLAYER_START + Vector2i.DOWN * 1_000_000
	session.get_actor_state(StringName(ids[3])).position_microfeet = Vector2i(38_000_000, 18_000_000)
	var escape_position := PLAYER_START + Vector2i.LEFT * 1_000_000
	var movement := session.request_player_movement(escape_position, 11)
	_expect_true(movement.get("success", false), "Live actors may legally block occupied directions without freezing every available direction.")
	_expect_equal(movement.get("position_microfeet", Vector2i.ZERO), escape_position, "The player must retain the legal open escape from temporary live-actor congestion.")


func _test_four_goblin_navigation_cost_remains_bounded() -> void:
	var session := _make_four_goblin_session()
	var began_us := Time.get_ticks_usec()
	for _step in range(50):
		session.advance_by(100_000)
	var elapsed_us := Time.get_ticks_usec() - began_us
	var rebuild_counts := session.get_goblin_path_rebuild_counts_for_testing()
	var total_rebuilds := 0
	for value: Variant in rebuild_counts.values():
		total_rebuilds += int(value)
	var movement_events := 0
	for event: CombatEvent in session.get_resolved_events():
		if event.event_type == &"actor_position_changed" and String(event.source_actor_id).begins_with("wave_1_common_goblin_"):
			movement_events += 1
	_expect_true(elapsed_us < 5_000_000, "Five simulated seconds with four Goblins must remain within the established bounded navigation budget.")
	_expect_true(total_rebuilds <= 12, "Four Goblins must not perform repeated exhaustive route rebuilds during a stable five-second pursuit.")
	print("METRIC: Task31J four-active simulation_us=%d route_rebuilds=%d movement_events=%d total_events=%d" % [
		elapsed_us, total_rebuilds, movement_events, session.get_resolved_event_count(),
	])


func _test_responsive_battlefield_scale_and_targeting() -> void:
	var reference := ResponsiveLayout.calculate_battlefield_presentation(Vector2(1152.0, 648.0))
	var large := ResponsiveLayout.calculate_battlefield_presentation(Vector2(1920.0, 1080.0))
	var compact := ResponsiveLayout.calculate_battlefield_presentation(Vector2(800.0, 450.0))
	_expect_equal(float(reference["pixels_per_foot"]), 24.0, "The established 1152x648 presentation must retain its 24-pixel foot scale.")
	_expect_true(float(large["pixels_per_foot"]) > float(reference["pixels_per_foot"]), "A larger desktop window must display the same Arena substantially larger.")
	_expect_true(float(compact["pixels_per_foot"]) < float(reference["pixels_per_foot"]), "A compact viewport must scale the complete Arena down without changing world geometry.")
	for entry in [[Vector2(1152.0, 648.0), reference], [Vector2(1920.0, 1080.0), large], [Vector2(800.0, 450.0), compact]]:
		var viewport_size: Vector2 = entry[0]
		var arena_rect: Rect2 = entry[1]["arena_rect"]
		_expect_true(arena_rect.position.x >= 0.0 and arena_rect.position.y >= 0.0 and arena_rect.end.x <= viewport_size.x and arena_rect.end.y <= viewport_size.y, "The scaled authoritative Arena must remain inside %s." % viewport_size)
		_expect_true(is_equal_approx(arena_rect.size.x / arena_rect.size.y, 44.0 / 23.0), "Responsive presentation must preserve the 44x23-foot battlefield aspect ratio.")

	var scene := _make_scene()
	if scene == null:
		return
	var controller: ArenaCombatController = scene.get_node("CombatController")
	var session := controller.get_combat_session_for_testing()
	var player_position_before: Vector2i = session.get_actor_state(Fixture.PLAYER_ID).position_microfeet
	scene.call("_apply_layout", Vector2(1920.0, 1080.0), Vector2(1920.0, 1080.0))
	var battlefield: ArenaBattlefieldView = scene.get_node("Battlefield")
	var player: PlaceholderPlayer = scene.get_node("PlaceholderPlayer")
	_expect_equal(battlefield.pixels_per_foot, 40.0, "The large desktop viewport must use the calculated 40-pixel foot presentation scale.")
	_expect_equal(player.pixels_per_foot, 40.0, "Player and battlefield presentation conversions must remain aligned.")
	_expect_equal(session.get_actor_state(Fixture.PLAYER_ID).position_microfeet, player_position_before, "Presentation scaling must not mutate authoritative coordinates.")
	_expect_true(controller.set_seed_text_for_testing("3").get("success", false), "The scaled targeting fixture must accept the representative four-Goblin seed.")
	_expect_true(controller.select_encounter_fixture_for_testing(Fixture.ENCOUNTER_WAVE_ONE_GOBLINS).get("success", false), "The scaled targeting fixture must load Wave 1.")
	var target_id := StringName(controller.get_combat_session_for_testing().get_targetable_enemy_ids()[2])
	var target_visual := controller._get_enemy_visual(target_id)
	_expect_true(target_visual != null, "The scaled targeting fixture requires a Goblin visual.")
	if target_visual != null:
		_expect_true(is_equal_approx(target_visual.scale.x, 40.0 / 24.0), "Actor visuals must retain their world-relative size at the enlarged scale.")
		var selection := controller.request_pointer_action_for_testing(target_visual.global_position, false)
		_expect_equal(StringName(selection.get("selection", {}).get("target_id", &"")), target_id, "Click/touch targeting must remain aligned after responsive scaling.")
	controller.press_encounter_control_for_testing()
	_expect_equal(controller.get_combat_session_for_testing().get_actor_state(Fixture.PLAYER_ID).position_microfeet, PLAYER_START, "START after scaling must retain the authoritative player start.")
	_expect_equal(player.position, Vector2(PLAYER_START) / 1_000_000.0 * 40.0, "START after scaling must retain visual/authoritative player alignment.")
	controller.press_encounter_control_for_testing()
	_expect_equal(controller.get_combat_session_for_testing().get_actor_state(Fixture.PLAYER_ID).position_microfeet, PLAYER_START, "RESET after scaling must retain the authoritative player start.")
	_free_scene(scene)


func _make_four_goblin_session() -> ArenaCombatSession:
	var session := ArenaCombatSession.new(3, null, Fixture.ENCOUNTER_WAVE_ONE_GOBLINS)
	session.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
	session.set_opponent_behavior_enabled(true)
	var initialized := session.initialize_wave_one_goblins(PLAYER_START, GOBLIN_START, true)
	_expect_true(initialized.get("success", false), "The four-Goblin Task 31J fixture must initialize.")
	return session


func _make_scene() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		_failures.append("SceneTree unavailable for Task 31J presentation verification.")
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


func _count_events(session: ArenaCombatSession, event_type: StringName, actor_id: StringName) -> int:
	var count := 0
	for event: CombatEvent in session.get_resolved_events():
		if event.event_type == event_type and event.source_actor_id == actor_id:
			count += 1
	return count


func _event_signature(session: ArenaCombatSession) -> Array[Dictionary]:
	var signature: Array[Dictionary] = []
	for event: CombatEvent in session.get_resolved_events():
		signature.append({
			"event_id": event.event_id,
			"timestamp_us": event.timestamp_us,
			"initiative": event.initiative,
			"event_type": String(event.event_type),
			"source": String(event.source_actor_id),
			"target": String(event.target_actor_id),
			"payload": event.payload.duplicate(true),
		})
	return signature


func _distance(left: Vector2i, right: Vector2i) -> int:
	return roundi(Vector2(left - right).length())


func _expect_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s Expected %s, got %s." % [message, str(expected), str(actual)])
