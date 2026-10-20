class_name GoblinWallNavigationSeedControlsTests
extends RefCounted

const ArenaBattlefield = preload("res://scripts/combat/arena_battlefield.gd")
const ArenaCombatSession = preload("res://scripts/combat/arena_combat_session.gd")
const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")

const PLAYER_BEHIND_WALL := Vector2i(20_000_000, 12_000_000)
const GOBLIN_ACROSS_WALL := Vector2i(38_000_000, 12_000_000)
const FIST_REACH_MICROFEET := 1_000_000
const STEP_US := 100_000

var _failures: Array[String] = []


func run() -> Array[String]:
	_failures.clear()
	_test_attack_path_segments_are_directly_collision_clear()
	_test_both_wall_endpoints_retain_clearance_and_reach_attack_range()
	_test_seeded_counts_and_history_are_reproducible()
	_test_seed_ui_validation_lock_and_reset_semantics()
	return _failures


func _test_attack_path_segments_are_directly_collision_clear() -> void:
	var battlefield := ArenaBattlefield.create_task16_test_arena()
	var occupancy := {
		"player": PLAYER_BEHIND_WALL,
		"goblin": GOBLIN_ACROSS_WALL,
	}
	var result := battlefield.find_path_to_attack_position(
		&"goblin",
		GOBLIN_ACROSS_WALL,
		PLAYER_BEHIND_WALL,
		FIST_REACH_MICROFEET,
		occupancy
	)
	_expect_true(result.get("success", false), "The wall-corner reproduction requires a legal route.")
	var segment_start := GOBLIN_ACROSS_WALL
	for waypoint: Vector2i in result.get("waypoints", []):
		_expect_true(
			battlefield.is_direct_path_clear(&"goblin", segment_start, waypoint, occupancy),
			"Every returned waypoint segment must be directly footprint-clear; %s -> %s cuts a wall corner." % [segment_start, waypoint]
		)
		segment_start = waypoint


func _test_both_wall_endpoints_retain_clearance_and_reach_attack_range() -> void:
	var seed_value := _find_seed_for_count(2)
	_test_wall_endpoint(seed_value, Vector2i(20_000_000, 6_000_000), GOBLIN_ACROSS_WALL, true)
	_test_wall_endpoint(seed_value, Vector2i(20_000_000, 22_000_000), Vector2i(38_000_000, 18_000_000), false)


func _test_wall_endpoint(seed_value: int, player_position: Vector2i, goblin_position: Vector2i, use_top: bool) -> void:
	var session := _wave_session(seed_value, player_position, goblin_position)
	var goblin_id := StringName(session.get_targetable_enemy_ids()[0])
	var previous_position: Vector2i = session.get_actor_state(goblin_id).position_microfeet
	var cleared_endpoint := false
	for _step in range(450):
		session.advance_by(STEP_US)
		var current_position: Vector2i = session.get_actor_state(goblin_id).position_microfeet
		_expect_true(
			session.get_battlefield().is_direct_path_clear(goblin_id, previous_position, current_position, {String(goblin_id): current_position}),
			"Goblin movement toward the %s wall endpoint must remain one directly collision-clear segment." % ("top" if use_top else "bottom")
		)
		if current_position.x <= 28_500_000:
			cleared_endpoint = cleared_endpoint or (current_position.y <= 7_500_000 if use_top else current_position.y >= 20_500_000)
		previous_position = current_position
		if _events_for_source(session, "physical_attack_declared", goblin_id).size() >= 2:
			break
	_expect_true(cleared_endpoint, "The Goblin must travel beyond the %s endpoint with full footprint clearance before turning." % ("top" if use_top else "bottom"))
	_expect_true(_events_for_source(session, "physical_attack_declared", goblin_id).size() >= 2, "The Goblin must reach legal fist range after routing around the %s wall endpoint." % ("top" if use_top else "bottom"))


func _test_seeded_counts_and_history_are_reproducible() -> void:
	var seeds_by_count := _find_first_seeds_by_count()
	_expect_equal(seeds_by_count.size(), 7, "Authoritative 2d4 draws must expose seeds for all seven legal Goblin quantities.")
	for expected_count in range(2, 9):
		if not seeds_by_count.has(expected_count):
			continue
		var seed_value := int(seeds_by_count[expected_count])
		var first := _wave_session(seed_value, PLAYER_BEHIND_WALL, GOBLIN_ACROSS_WALL, false)
		var second := _wave_session(seed_value, PLAYER_BEHIND_WALL, GOBLIN_ACROSS_WALL, false)
		_expect_equal(first.get_targetable_enemy_ids().size(), expected_count, "Seed %d must produce %d Goblin(s)." % [seed_value, expected_count])
		_expect_equal(_event_signature(first), _event_signature(second), "Equivalent initialization with seed %d must reproduce authoritative history." % seed_value)
	print("METRIC: Task31H first_seed_by_goblin_count=%s" % str(seeds_by_count))


func _test_seed_ui_validation_lock_and_reset_semantics() -> void:
	var packed: PackedScene = load("res://scenes/test_arena.tscn")
	var scene := packed.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		_failures.append("SceneTree unavailable for authoritative seed UI verification.")
		scene.free()
		return
	tree.root.add_child(scene)
	var controller: ArenaCombatController = scene.get_node("CombatController")
	var initial := controller.get_seed_ui_state_for_testing()
	_expect_equal(initial.get("authoritative_seed"), 1, "The shipped encounter must display and use default authoritative seed 1.")
	_expect_equal(initial.get("label"), "SEED 1", "The seed label must show the actual authoritative seed.")
	for invalid_seed in ["not-a-seed", "9223372036854775808", "-9223372036854775809"]:
		_expect_true(not controller.set_seed_text_for_testing(invalid_seed).get("success", false), "Invalid or out-of-range seed '%s' must fail closed." % invalid_seed)
		_expect_equal(controller.get_seed_ui_state_for_testing().get("authoritative_seed"), 1, "Rejected seed input must not change authoritative RNG initialization.")
	var seeds_by_count := _find_first_seeds_by_count()
	var selected_seed := int(seeds_by_count.get(8, 1))
	_expect_true(controller.set_seed_text_for_testing(str(selected_seed)).get("success", false), "A valid signed seed must be accepted while the encounter is READY.")
	_expect_true(controller.select_encounter_fixture_for_testing(Fixture.ENCOUNTER_WAVE_ONE_GOBLINS).get("success", false), "Wave 1 must remain selectable after applying a seed.")
	var session := controller.get_combat_session_for_testing()
	_expect_equal(session.get_targetable_enemy_ids().size(), 8, "The selected seed must initialize the actual Wave 1 2d4 quantity.")
	_expect_true(controller.get_transcript_text_for_testing().contains("Seed: %d" % selected_seed), "The authoritative transcript must report the selected seed.")
	controller.press_encounter_control_for_testing()
	_expect_true(not controller.set_seed_text_for_testing("1").get("success", false), "An active encounter must reject a seed change.")
	_expect_equal(controller.get_seed_ui_state_for_testing().get("authoritative_seed"), selected_seed, "Blocked mid-encounter input must preserve the active authoritative seed.")
	controller.press_encounter_control_for_testing()
	session = controller.get_combat_session_for_testing()
	var reset_state := controller.get_seed_ui_state_for_testing()
	_expect_equal(reset_state.get("authoritative_seed"), selected_seed, "RESET must reuse the selected seed.")
	_expect_equal(session.get_targetable_enemy_ids().size(), 8, "RESET must reproduce the selected seed's Goblin quantity.")
	_expect_true(not bool(reset_state.get("input_disabled", true)) and not bool(reset_state.get("apply_disabled", true)), "Seed controls must become editable again after RESET.")
	tree.root.remove_child(scene)
	scene.free()


func _wave_session(seed_value: int, player_position: Vector2i, goblin_position: Vector2i, start_active: bool = true) -> ArenaCombatSession:
	var session := ArenaCombatSession.new(seed_value, null, Fixture.ENCOUNTER_WAVE_ONE_GOBLINS)
	session.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
	session.set_opponent_behavior_enabled(true)
	_expect_true(session.initialize_wave_one_goblins(player_position, goblin_position, start_active).get("success", false), "Task 31H Wave 1 fixture must initialize for seed %d." % seed_value)
	return session


func _find_seed_for_count(expected_count: int) -> int:
	return int(_find_first_seeds_by_count().get(expected_count, 1))


func _find_first_seeds_by_count() -> Dictionary:
	var seeds_by_count := {}
	for seed_value in range(1, 256):
		var session := _wave_session(seed_value, PLAYER_BEHIND_WALL, GOBLIN_ACROSS_WALL, false)
		var count := session.get_targetable_enemy_ids().size()
		if not seeds_by_count.has(count):
			seeds_by_count[count] = seed_value
		if seeds_by_count.size() == 7:
			break
	return seeds_by_count


func _events_for_source(session: ArenaCombatSession, event_type: String, source_actor_id: StringName) -> Array[CombatEvent]:
	var matching: Array[CombatEvent] = []
	for event: CombatEvent in session.get_resolved_events():
		if String(event.event_type) == event_type and event.source_actor_id == source_actor_id:
			matching.append(event)
	return matching


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


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s Expected %s, got %s." % [message, str(expected), str(actual)])


func _expect_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)
