class_name WavePerformanceHpcTests
extends RefCounted

const ArenaBattlefield = preload("res://scripts/combat/arena_battlefield.gd")
const ArenaCombatSession = preload("res://scripts/combat/arena_combat_session.gd")
const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")

const FRACTIONAL_PLAYER_POSITION := Vector2i(24_000_000, 13_500_000)
const FRACTIONAL_GOBLIN_POSITION := Vector2i(27_000_000, 15_666_667)
const PLAYER_POSITION := Vector2i(20_000_000, 12_000_000)
const GOBLIN_POSITION := Vector2i(24_000_000, 12_000_000)

var _failures: Array[String] = []


func run() -> Array[String]:
	_failures.clear()
	_test_fractional_target_attack_position_path()
	_test_all_wave_counts_advance_responsively()
	_test_hpc_display_retains_definition_hpm()
	return _failures


func _test_fractional_target_attack_position_path() -> void:
	var battlefield := ArenaBattlefield.create_task16_test_arena()
	var mover := &"wave_1_common_goblin_01"
	var occupancy := {
		"player": FRACTIONAL_PLAYER_POSITION,
		String(mover): FRACTIONAL_GOBLIN_POSITION,
	}
	var result := battlefield.find_path_to_attack_position(mover, FRACTIONAL_GOBLIN_POSITION, FRACTIONAL_PLAYER_POSITION, 1_000_000, occupancy)
	_expect_true(result.get("success", false), "A one-foot melee path must support a target positioned between whole-foot navigation nodes.")
	var waypoints: Array = result.get("waypoints", [])
	_expect_true(not waypoints.is_empty(), "The fractional target fixture must produce a legal approach path.")
	if not waypoints.is_empty():
		_expect_true(battlefield.is_attack_position_legal(waypoints[-1], FRACTIONAL_PLAYER_POSITION, 1_000_000), "The final off-grid waypoint must be in legal one-foot reach with line of sight.")


func _test_all_wave_counts_advance_responsively() -> void:
	var sessions_by_count := {}
	for seed in range(1, 256):
		var session := _wave_session(seed)
		var count := session.get_targetable_enemy_ids().size()
		if not sessions_by_count.has(count):
			sessions_by_count[count] = session
		if sessions_by_count.size() == 7:
			break
	_expect_equal(sessions_by_count.size(), 7, "Wave-1 performance coverage must include every Arena 2d4 count from 2 through 8.")
	for count in sessions_by_count:
		var session: ArenaCombatSession = sessions_by_count[count]
		var starting_positions := {}
		for actor_id: String in session.get_targetable_enemy_ids():
			starting_positions[actor_id] = session.get_actor_state(StringName(actor_id)).position_microfeet
		var began := Time.get_ticks_usec()
		for frame in range(60):
			session.advance_by(16_667)
		var elapsed_us := Time.get_ticks_usec() - began
		_expect_true(elapsed_us < 5_000_000, "A one-second Wave-1 simulation with %d Goblin(s) must not repeat an exhaustive path search every frame; measured %d us." % [count, elapsed_us])
		_expect_true(not session.get_opponent_behavior_status().contains("no_legal_path"), "A legal Wave-1 approach must not report no_legal_path for %d Goblin(s)." % count)
		var moved_count := 0
		for actor_id: String in session.get_targetable_enemy_ids():
			if session.get_actor_state(StringName(actor_id)).position_microfeet != starting_positions[actor_id]:
				moved_count += 1
		_expect_true(moved_count > 0, "At least one legal Goblin approach must visibly progress during the first simulated second.")


func _test_hpc_display_retains_definition_hpm() -> void:
	var packed: PackedScene = load("res://scenes/test_arena.tscn")
	var scene := packed.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		_failures.append("SceneTree unavailable for Task 31D HPC presentation test.")
		scene.free()
		return
	tree.root.add_child(scene)
	var controller: ArenaCombatController = scene.get_node("CombatController")
	var session := controller.get_combat_session_for_testing()
	var opponent_state := session.get_actor_state(Fixture.OPPONENT_ID)
	opponent_state.current_hpc = 37
	controller.update_presentation_for_testing()
	var opponent_label: Label = scene.get_node("Opponent/HPC")
	_expect_true(opponent_label.text.contains("HPC 37/100"), "Damage must change current Guard HPC without replacing its source HPM in the HUD.")
	_expect_equal(session.get_actor_max_hpm(Fixture.OPPONENT_ID), 100, "The Guard's maximum HPM must remain definition-owned after damage.")

	var selection := controller.select_encounter_fixture_for_testing(Fixture.ENCOUNTER_WAVE_ONE_GOBLINS)
	_expect_true(selection.get("success", false), "The Wave-1 fixture must remain selectable for Goblin HPC presentation verification.")
	session = controller.get_combat_session_for_testing()
	var goblin_id := session.get_selected_target_id()
	controller.update_presentation_for_testing()
	var goblin_label := (controller._get_enemy_visual(goblin_id).get_node("Label") as Label)
	_expect_true(goblin_label.text.contains("HPC 1/1"), "A healthy Common Goblin must display current HPC 1 and source HPM 1.")
	session.get_actor_state(goblin_id).current_hpc = 0
	controller.call("_refresh_non_player_actor_positions")
	controller.update_presentation_for_testing()
	_expect_true(goblin_label.text.contains("HPC 0/1"), "A defeated Common Goblin label must retain maximum HPM 1 even while hidden.")
	_expect_true(not goblin_label.visible, "A defeated Common Goblin health label must no longer be rendered.")
	tree.root.remove_child(scene)
	scene.free()


func _wave_session(seed: int) -> ArenaCombatSession:
	var session := ArenaCombatSession.new(seed, null, Fixture.ENCOUNTER_WAVE_ONE_GOBLINS)
	session.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
	session.set_opponent_behavior_enabled(true)
	var result := session.initialize_wave_one_goblins(PLAYER_POSITION, GOBLIN_POSITION, true)
	_expect_true(result.get("success", false), "Wave-1 performance fixture must initialize for seed %d." % seed)
	return session


func _expect_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s Expected %s, got %s." % [message, str(expected), str(actual)])
