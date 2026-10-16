class_name PlaytestQualityTests
extends RefCounted

const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
const Transcript = preload("res://scripts/ui/arena_encounter_transcript.gd")
const ResponsiveLayout = preload("res://scripts/ui/arena_responsive_layout.gd")
const Digest = preload("res://scripts/sync/sync_state_digest.gd")

const PLAYER_START := Vector2i(20_000_000, 12_000_000)
const OPPONENT_START := Vector2i(26_000_000, 12_000_000)

var _failures: Array[String] = []


func run() -> Array[String]:
	_failures.clear()
	_test_approach_declaration_and_final_failure()
	_test_initial_obstruction_declaration()
	_test_continuously_moving_target_pursuit()
	_test_pursuit_replay_convergence()
	_test_transcript_completeness_and_purity()
	_test_scene_log_and_crowded_labels()
	_test_task20_layouts()
	return _failures


func _test_approach_declaration_and_final_failure() -> void:
	var session := _player_opening_session(PLAYER_START, OPPONENT_START)
	var legality := session.get_attack_legality()
	_expect_true(legality.get("success", false), "An APPROACH-capable Battle Axe must be declaration-legal outside three-foot reach.")
	_expect_true(legality.get("approach_required", false), "Outside reach must be reported as APPROACH, not as a declaration rejection.")
	var result := session.request_player_attack("task20_out_of_range")
	_expect_true(result.get("success", false), "The authoritative player attack request must start outside reach.")
	session.advance_by(2_500_000)
	_expect_true(not _has_event(session, "physical_attack_accuracy_resolved", Fixture.PLAYER_ID), "An attacker still outside reach at final resolution must not roll ACC.")
	_expect_true(_has_event(session, "physical_attack_final_legality_failed", Fixture.PLAYER_ID), "Final range failure must be recorded explicitly.")


func _test_initial_obstruction_declaration() -> void:
	var session := _player_opening_session(Vector2i(27_000_000, 12_000_000), Vector2i(33_000_000, 12_000_000))
	var legality := session.get_attack_legality()
	_expect_true(legality.get("success", false), "The approved Battle Axe approach policy must permit declaration through an initial obstruction.")
	_expect_true(not legality.get("currently_unobstructed", true), "The obstruction fixture must actually begin without line of sight.")
	_expect_true(session.request_player_attack("task20_initial_obstruction").get("success", false), "Initial obstruction must not be mistaken for final attack legality.")


func _test_continuously_moving_target_pursuit() -> void:
	var session := _opponent_opening_session(Vector2i(20_000_000, 5_000_000), Vector2i(43_000_000, 5_000_000))
	session.set_opponent_behavior_enabled(true)
	var initial_distance := _distance(session)
	var max_rebuilds := 0
	for step in range(60):
		var player := session.get_actor_state(Fixture.PLAYER_ID)
		var direction := -1 if step < 30 else 1
		var desired := player.position_microfeet + Vector2i(direction * 240_000, 0)
		session.request_player_movement(desired, 12)
		session.advance_by(100_000)
		max_rebuilds = maxi(max_rebuilds, session.get_opponent_path_rebuild_count_for_testing())
		var opponent := session.get_actor_state(Fixture.OPPONENT_ID)
		_expect_true(int(opponent.remaining_mr_microfeet) >= 0, "Pursuit must never overspend authoritative MR.")
	var final_distance := _distance(session)
	var movement: Dictionary = session.get_state_snapshot().get("opponent_movement", {})
	_expect_true(bool(movement.get("running_automatic", false)), "The opponent fixture must use its verified automatic Running qualification, not a speed boost.")
	_expect_true(movement.get("last_check_result", "") == "automatic_success" or movement.get("is_running", false), "Opponent Running must use the existing legal Running model.")
	_expect_true(final_distance < initial_distance, "Legal Running pursuit must gain ground on a continuously moving equal-MR player.")
	_expect_true(max_rebuilds > 1 and max_rebuilds < 100, "Moving-target pursuit must repath when needed without an unbounded rebuild loop.")


func _test_pursuit_replay_convergence() -> void:
	var seed_value := _find_opponent_opening_seed(Vector2i(20_000_000, 5_000_000), Vector2i(43_000_000, 5_000_000))
	if seed_value < 0:
		_failures.append("No deterministic seed available for Task 20 pursuit replay.")
		return
	var sessions: Array[ArenaCombatSession] = []
	for _replica in range(2):
		var session := ArenaCombatSession.new(seed_value)
		session.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
		session.initialize(Vector2i(20_000_000, 5_000_000), Vector2i(43_000_000, 5_000_000))
		session.set_opponent_behavior_enabled(true)
		sessions.append(session)
	for step in range(40):
		var direction := -1 if step < 20 else 1
		for session: ArenaCombatSession in sessions:
			var player := session.get_actor_state(Fixture.PLAYER_ID)
			session.request_player_movement(player.position_microfeet + Vector2i(direction * 240_000, 0), 12)
			session.advance_by(100_000)
	_expect_equal(Digest.compute(sessions[0].get_state_snapshot()), Digest.compute(sessions[1].get_state_snapshot()), "Identical moving-target inputs must reproduce the same path, Running state and combat snapshot.")


func _test_transcript_completeness_and_purity() -> void:
	var session := _player_opening_session(PLAYER_START, OPPONENT_START)
	for index in range(20):
		session.simulation.apply_authoritative_position(Fixture.PLAYER_ID, PLAYER_START, 0, 0)
	var before := Digest.compute(session.get_state_snapshot())
	var text := Transcript.build_text(session, 1, "task20-test")
	var after := Digest.compute(session.get_state_snapshot())
	_expect_equal(before, after, "Building or viewing the transcript must not mutate authoritative simulation state.")
	_expect_true(text.contains("Transcript schema: 1") and text.contains("Seed: 1"), "The export must include reproducibility metadata.")
	var events := session.get_resolved_events()
	_expect_true(events.size() > 8, "The completeness fixture must exceed the recent-results display limit.")
	for event: CombatEvent in events:
		_expect_true(text.contains("id=%s" % event.event_id), "The full transcript must retain every authoritative event ID.")


func _test_scene_log_and_crowded_labels() -> void:
	var packed: PackedScene = load("res://scenes/test_arena.tscn")
	var scene := packed.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		_failures.append("SceneTree unavailable for Task 20 scene test.")
		scene.free()
		return
	tree.root.add_child(scene)
	var controller: ArenaCombatController = scene.get_node("CombatController")
	controller.press_encounter_control_for_testing()
	controller.set_transcript_visible(true)
	_expect_true(controller.is_transcript_visible(), "FULL LOG must open the collapsible transcript viewer.")
	_expect_true(controller.get_transcript_text_for_testing().contains("Authoritative Encounter Transcript"), "The viewer must expose the complete authoritative transcript text.")
	var player: Node2D = scene.get_node("PlaceholderPlayer")
	var opponent: Node2D = scene.get_node("Opponent")
	opponent.position = player.position + Vector2(40.0, 0.0)
	controller.call("_update_actor_label_layout")
	var rects := controller.get_actor_label_rects_for_testing()
	_expect_true(not (rects[0] as Rect2).intersects(rects[1] as Rect2), "Crowded combatants must retain distinct identity/HPC label rectangles.")
	controller.set_transcript_visible(false)
	_expect_true(not controller.is_transcript_visible(), "The transcript viewer must collapse without discarding encounter state.")
	scene.free()


func _test_task20_layouts() -> void:
	for size: Vector2 in [Vector2(915, 412), Vector2(800, 360), Vector2(1280, 720)]:
		var layout := ResponsiveLayout.calculate_layout(size, size)
		var panel: Rect2 = layout["transcript_panel_rect"]
		var log_button: Rect2 = layout["log_button_rect"]
		var debug_button: Rect2 = layout["debug_button_rect"]
		var encounter_button: Rect2 = layout["encounter_button_rect"]
		_expect_true(panel.position.x >= 0.0 and panel.position.y >= 0.0 and panel.end.x <= size.x and panel.end.y <= size.y, "The full transcript panel must remain inside supported viewports.")
		_expect_true(log_button.position.x >= 0.0 and log_button.end.x <= size.x, "The FULL LOG control must remain visible at supported widths.")
		_expect_true(not log_button.intersects(debug_button) and not debug_button.intersects(encounter_button), "The FULL LOG, DEBUG and START/RESET controls must not overlap.")


func _player_opening_session(player_position: Vector2i, opponent_position: Vector2i) -> ArenaCombatSession:
	for seed_value in range(1, 500):
		var session := ArenaCombatSession.new(seed_value)
		session.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
		if session.initialize(player_position, opponent_position).get("success", false) \
		and int(session.get_actor_state(Fixture.PLAYER_ID).opening_order_rank) == 0:
			return session
	_failures.append("No deterministic player-opening seed found for Task 20 tests.")
	return ArenaCombatSession.new(1)


func _opponent_opening_session(player_position: Vector2i, opponent_position: Vector2i) -> ArenaCombatSession:
	var seed_value := _find_opponent_opening_seed(player_position, opponent_position)
	if seed_value >= 0:
		var session := ArenaCombatSession.new(seed_value)
		session.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
		session.initialize(player_position, opponent_position)
		return session
	_failures.append("No deterministic opponent-opening seed found for Task 20 tests.")
	return ArenaCombatSession.new(1)


func _find_opponent_opening_seed(player_position: Vector2i, opponent_position: Vector2i) -> int:
	for seed_value in range(1, 500):
		var session := ArenaCombatSession.new(seed_value)
		session.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
		if session.initialize(player_position, opponent_position).get("success", false) \
		and int(session.get_actor_state(Fixture.OPPONENT_ID).opening_order_rank) == 0:
			return seed_value
	return -1


func _distance(session: ArenaCombatSession) -> int:
	var player := session.get_actor_state(Fixture.PLAYER_ID)
	var opponent := session.get_actor_state(Fixture.OPPONENT_ID)
	return roundi(Vector2(player.position_microfeet - opponent.position_microfeet).length())


func _has_event(session: ArenaCombatSession, event_type: String, source_id: StringName) -> bool:
	for event: CombatEvent in session.get_resolved_events():
		if String(event.event_type) == event_type and event.source_actor_id == source_id:
			return true
	return false


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s Expected %s, got %s." % [message, str(expected), str(actual)])


func _expect_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)
