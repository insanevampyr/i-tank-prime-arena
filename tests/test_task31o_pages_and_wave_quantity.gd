class_name Task31OPagesAndWaveQuantityTests
extends RefCounted

const ArenaBattlefield = preload("res://scripts/combat/arena_battlefield.gd")
const ArenaCombatSession = preload("res://scripts/combat/arena_combat_session.gd")
const ArenaWaveStateMachine = preload("res://scripts/combat/arena_wave_state_machine.gd")
const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
const TwoClientSyncHarness = preload("res://scripts/sync/two_client_sync_harness.gd")

const PLAYER_POSITION := Vector2i(20_000_000, 12_000_000)
const GOBLIN_POSITION := Vector2i(38_000_000, 12_000_000)

var _failures: Array[String] = []


func run() -> Array[String]:
	_failures.clear()
	_test_two_dice_quantity_contract_and_distribution()
	_test_eight_goblin_registration_targeting_completion_and_reset()
	_test_eight_goblin_navigation_performance_and_convergence()
	_test_pages_workflow_contract()
	return _failures


func _test_two_dice_quantity_contract_and_distribution() -> void:
	var observed_frequencies := {}
	for first_die in range(1, 5):
		for second_die in range(1, 5):
			var machine := ArenaWaveStateMachine.new()
			var scripted_results := [first_die, second_die]
			var draw_state := {"index": 0}
			var roll_quantity := func(sides: int) -> Dictionary:
				var value: int = scripted_results[int(draw_state["index"])]
				draw_state["index"] = int(draw_state["index"]) + 1
				return {"value": value, "rng_draw_index": int(draw_state["index"]), "sides": sides}
			var initialized := machine.initialize(roll_quantity)
			_expect_true(initialized.get("success", false), "Every legal pair of d4 results must initialize Wave 1.")
			_expect_equal(draw_state["index"], 2, "Wave 1 must consume two independent quantity draws, not one uniform draw.")
			var roster: Array = machine.to_dictionary().get("resolved_roster", [])
			var entry: Dictionary = roster[0]
			var expected_count := first_die + second_die
			_expect_equal(entry.get("dice_results"), [first_die, second_die], "Wave evidence must retain both ordered d4 results.")
			_expect_equal(entry.get("rng_draw_indices"), [1, 2], "Wave evidence must retain both ordered RNG draw indexes.")
			_expect_equal(entry.get("resolved_count"), expected_count, "Resolved Goblin quantity must be the exact sum of both d4 results.")
			observed_frequencies[expected_count] = int(observed_frequencies.get(expected_count, 0)) + 1
	_expect_equal(observed_frequencies, {2: 1, 3: 2, 4: 3, 5: 4, 6: 3, 7: 2, 8: 1}, "Exhaustive d4 pairs must produce the triangular 2d4 distribution, not uniform 2-8 selection.")


func _test_eight_goblin_registration_targeting_completion_and_reset() -> void:
	var seed_value := _find_seed_for_count(8)
	_expect_true(seed_value > 0, "A deterministic seed producing eight Goblins must be discoverable.")
	if seed_value <= 0:
		return
	var session := _wave_session(seed_value, false)
	var ids := session.get_targetable_enemy_ids()
	_expect_equal(ids.size(), 8, "The maximum Arena 2d4 result must register eight independent Goblins.")
	var unique_positions := {}
	var visited_targets := {}
	for actor_id: String in ids:
		var state := session.get_actor_state(StringName(actor_id))
		_expect_true(state != null and state.current_hpc == 1, "%s must have independent authoritative HPC." % actor_id)
		if state != null:
			unique_positions[state.position_microfeet] = true
		visited_targets[String(session.get_selected_target_id())] = true
		session.cycle_target(1)
	_expect_equal(unique_positions.size(), 8, "All eight Goblins must begin at distinct legal positions.")
	_expect_equal(visited_targets.size(), 8, "Target cycling must visit all eight living Goblins.")
	var initial_signature := _event_signature(session)
	_expect_true(session.reset_encounter(false).get("success", false), "RESET must rebuild the maximum-count encounter.")
	_expect_equal(session.get_targetable_enemy_ids().size(), 8, "RESET with the same seed must reproduce eight Goblins.")
	_expect_equal(_event_signature(session), initial_signature, "RESET with the same seed must reproduce the complete authoritative history.")
	_expect_true(session.start_encounter().get("success", false), "The reset maximum-count encounter must start before victory evaluation.")
	for actor_id: String in session.get_targetable_enemy_ids():
		session.get_actor_state(StringName(actor_id)).current_hpc = 0
	session.advance_by(1)
	_expect_equal(session.get_encounter_state(), ArenaCombatSession.ENCOUNTER_PLAYER_VICTORY, "Wave victory must wait for and then recognize all eight defeated Goblins.")


func _test_eight_goblin_navigation_performance_and_convergence() -> void:
	var seed_value := _find_seed_for_count(8)
	if seed_value <= 0:
		return
	var first := _wave_session(seed_value, true)
	var second := _wave_session(seed_value, true)
	var began_us := Time.get_ticks_usec()
	for unused_step in range(50):
		first.advance_by(100_000)
		second.advance_by(100_000)
	var elapsed_us := Time.get_ticks_usec() - began_us
	_expect_true(elapsed_us < 10_000_000, "Two deterministic five-second simulations with eight Goblins must remain within a bounded local test budget; measured %d us." % elapsed_us)
	_expect_equal(_event_signature(first), _event_signature(second), "Eight-Goblin navigation must replay with identical authoritative events.")
	_expect_equal(first.get_state_snapshot(), second.get_state_snapshot(), "Eight-Goblin navigation must replay with identical authoritative state.")
	var rebuilds := 0
	for count: Variant in first.get_goblin_path_rebuild_counts_for_testing().values():
		rebuilds += int(count)
	var movement_events := 0
	for event: CombatEvent in first.get_resolved_events():
		if event.event_type == &"actor_position_changed" and String(event.source_actor_id).begins_with("wave_1_common_goblin_"):
			movement_events += 1
	_expect_true(movement_events > 0, "The eight-Goblin stress encounter must preserve authoritative movement progress and history.")
	print("METRIC: Task31O eight-goblin two-replay simulation_us=%d route_rebuilds=%d movement_events=%d total_events=%d" % [elapsed_us, rebuilds, movement_events, first.get_resolved_event_count()])

	var harness := TwoClientSyncHarness.new(seed_value)
	var authority_session := ArenaCombatSession.new(seed_value, harness.authority.simulation, Fixture.ENCOUNTER_WAVE_ONE_GOBLINS)
	authority_session.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
	_expect_true(authority_session.initialize_wave_one_goblins(PLAYER_POSITION, GOBLIN_POSITION, false).get("success", false), "The synchronized eight-Goblin authority must initialize.")
	var envelopes := harness.authority.publish_current_events()
	harness.deliver_in_order(envelopes)
	_expect_true(harness.compare_clients().get("success", false), "Both simulated clients must converge on the eight-Goblin authoritative event stream.")
	_expect_equal(harness.authority.get_state_digest(), harness.client_a.get_state_digest(), "The maximum-count wave must retain the authoritative state digest.")


func _test_pages_workflow_contract() -> void:
	var workflow_path := "res://.github/workflows/deploy-pages.yml"
	_expect_true(FileAccess.file_exists(workflow_path), "The GitHub Pages workflow must be version-controlled project configuration.")
	var workflow := FileAccess.get_file_as_string(workflow_path)
	for required_text in [
		"branches:\n      - main",
		"Godot_v4.7.2-stable_linux.x86_64.zip",
		"Godot_v4.7.2-stable_export_templates.tpz",
		"sha256sum --check --strict",
		"--export-release Web builds/web/index.html",
		"actions/upload-pages-artifact@7b1f4a764d45c48632c6b24a0339c27f5614fb0b",
		"actions/deploy-pages@d6db90164ac5ed86f2b6aed7e0febac5b3c0c03e",
		"pages: write",
		"id-token: write",
		"path: builds/web",
	]:
		_expect_true(workflow.contains(required_text), "Pages workflow is missing required controlled behavior: %s" % required_text)
	_expect_true(not workflow.contains("git push") and not workflow.contains("builds/web/**"), "Deployment must publish an artifact without writing generated export files back to Git.")
	_expect_true(workflow.contains("tmp/*") or workflow.contains("'*/tmp/*'"), "Artifact validation must reject protected temporary content.")
	var presets := ConfigFile.new()
	_expect_equal(presets.load("res://export_presets.cfg"), OK, "Deployment must use the readable project Web preset.")
	_expect_equal(presets.get_value("preset.0.options", "variant/thread_support", true), false, "Pages deployment must remain Web Single-Threaded.")
	_expect_equal(presets.get_value("preset.0.options", "progressive_web_app/ensure_cross_origin_isolation_headers", true), false, "Single-threaded Pages deployment must not require cross-origin isolation headers.")
	var exclusions := String(presets.get_value("preset.0", "exclude_filter", "")).split(",")
	for excluded_path in ["tmp/*", "tests/*", "docs/*", ".github/*"]:
		_expect_true(exclusions.has(excluded_path), "Published PCK must exclude development-only path %s." % excluded_path)
	var ignore := FileAccess.get_file_as_string("res://.gitignore")
	_expect_true(ignore.contains("/builds/*"), "Generated Web exports must remain excluded from version control.")


func _find_seed_for_count(expected_count: int) -> int:
	for seed_value in range(1, 512):
		var session := _wave_session(seed_value, false)
		if session.get_targetable_enemy_ids().size() == expected_count:
			return seed_value
	return -1


func _wave_session(seed_value: int, start_active: bool) -> ArenaCombatSession:
	var session := ArenaCombatSession.new(seed_value, null, Fixture.ENCOUNTER_WAVE_ONE_GOBLINS)
	session.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
	session.set_opponent_behavior_enabled(true)
	var initialized := session.initialize_wave_one_goblins(PLAYER_POSITION, GOBLIN_POSITION, start_active)
	_expect_true(initialized.get("success", false), "Wave 1 must initialize for deterministic seed %d." % seed_value)
	return session


func _event_signature(session: ArenaCombatSession) -> Array[Dictionary]:
	var signature: Array[Dictionary] = []
	for event: CombatEvent in session.get_resolved_events():
		signature.append(event.to_dictionary())
	return signature


func _expect_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s Expected %s, got %s." % [message, str(expected), str(actual)])
