class_name CommonSpadoodleWaveTests
extends RefCounted

const ArenaCombatSession = preload("res://scripts/combat/arena_combat_session.gd")
const ArenaBattlefield = preload("res://scripts/combat/arena_battlefield.gd")
const ArenaWaveStateMachine = preload("res://scripts/combat/arena_wave_state_machine.gd")
const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
const CommonSpadoodleFixture = preload("res://scripts/creatures/common_spadoodle_fixture.gd")
const HitLocations = preload("res://scripts/combat/combat_hit_location_catalog.gd")
const TwoClientSyncHarness = preload("res://scripts/sync/two_client_sync_harness.gd")

const PLAYER_POSITION := Vector2i(20_000_000, 12_000_000)
const SPADOODLE_POSITION := Vector2i(24_000_000, 12_000_000)

var _failures: Array[String] = []


func run() -> Array[String]:
	_failures.clear()
	_test_source_backed_definition()
	_test_all_seeded_d3_counts_and_independent_instances()
	_test_two_claws_resolve_in_one_at_one_act()
	_test_directional_size_targeting_and_location_armor()
	_test_wave_victory_reset_replay_and_two_client_convergence()
	_test_maximum_wave_navigation_and_frame_partition()
	_test_launcher_and_presentation()
	return _failures


func _test_source_backed_definition() -> void:
	var actor := CommonSpadoodleFixture.make_actor(&"source_spadoodle", "Source Spadoodle")
	_expect_true(actor != null, "Common Spadoodle source definition must instantiate.")
	if actor == null:
		return
	_expect_equal(actor.size_category, HitLocations.SIZE_SMALL, "The verified two-foot Common Spadoodle must use Small size targeting.")
	for stat_and_value in [
		["hpm", 10], ["at", 1], ["mr", 10], ["acc", 7], ["init", 1],
		["dt", 6], ["dp", 0], ["nal", 2], ["physical_soak", 0], ["sb", 1],
	]:
		_expect_equal(actor.get_combat_stat(stat_and_value[0]), stat_and_value[1], "Spadoodle %s must match Common Spadoodle.doc." % stat_and_value[0])
	_expect_equal(actor.attributes.get("str"), 4, "Spadoodle STR must match Common Spadoodle.doc.")
	_expect_equal(actor.attributes.get("spd"), 10, "Spadoodle SPD must match Common Spadoodle.doc.")
	_expect_equal(actor.attributes.get("end"), 1, "Spadoodle END must match Common Spadoodle.doc.")
	_expect_true(not actor.defensive_capabilities.get("weapon_block", true), "Natural claws must not invent Weapon Block capability.")
	_expect_true(not actor.defensive_capabilities.get("shield_block", true), "Spadoodles must not invent a shield.")

	var attack := CommonSpadoodleFixture.make_attack_definition(HitLocations.get_same_size_attack_profile())
	_expect_true(attack != null, "Common Spadoodle claws must produce a combat-ready attack definition.")
	if attack == null:
		return
	_expect_equal(attack.required_acts, 1, "Spadoodle claws require exactly one Act.")
	_expect_equal(attack.strikes_per_act, 2, "The owner-approved two independent claws must share one Act.")
	_expect_equal(attack.maximum_range_microfeet, 2_000_000, "Each claw must retain two-foot reach.")
	_expect_equal(Array(attack.damage_types), ["slashing"], "Each claw must deal slashing damage.")
	_expect_equal(attack.physical_damage.dice_count, 1, "Each claw rolls one damage die.")
	_expect_equal(attack.physical_damage.die_sides, 6, "Each claw rolls source-verified d6 damage.")
	_expect_true(attack.physical_damage.strength_bonus_eligible, "Prime's eligible Strength Bonus must remain attached to the physical claw hit.")


func _test_all_seeded_d3_counts_and_independent_instances() -> void:
	var observed_counts := {}
	for seed in range(1, 128):
		var session := _ready_wave_session(seed, false)
		var state := session.get_arena_wave_state()
		var roster: Array = state.get("resolved_roster", [])
		var count := int(roster[0].get("resolved_count", 0)) if not roster.is_empty() else 0
		observed_counts[count] = true
		_expect_equal(state.get("current_wave_id"), "wave_2", "The direct playable fixture must initialize Wave 2, not simulate Wave 1 victory.")
		_expect_equal(session.get_targetable_enemy_ids().size(), count, "Every 1d3 result must create that many independently targetable Spadoodles.")
		if not roster.is_empty():
			_expect_equal(roster[0].get("dice_count"), 1, "Wave 2 quantity must consume exactly one d3 draw.")
			_expect_equal((roster[0].get("dice_results", []) as Array).size(), 1, "Wave 2 quantity history must record the authoritative die result.")
		for actor_id: String in session.get_targetable_enemy_ids():
			var state_for_actor := session.get_actor_state(StringName(actor_id))
			_expect_true(state_for_actor != null and state_for_actor.current_hpc == 10, "Each Spadoodle must own independent 10-HPC mutable state.")
		if observed_counts.size() == 3:
			break
	_expect_equal(observed_counts.size(), 3, "The deterministic seed sample must produce every legal 1d3 result.")
	for expected in range(1, 4):
		_expect_true(observed_counts.has(expected), "The Wave 2 d3 must produce %d within the deterministic seed sample." % expected)


func _test_two_claws_resolve_in_one_at_one_act() -> void:
	var session := _ready_wave_session(32_201, true)
	var spadoodle_id := StringName(session.get_targetable_enemy_ids()[0])
	_expect_true(session.simulation.apply_authoritative_position(spadoodle_id, PLAYER_POSITION + Vector2i(2_000_000, 0), 180_000).get("success", false), "Focused claw position must be legal.")
	var declarations := _advance_until_declarations(session, spadoodle_id, 2)
	_expect_equal(declarations.size(), 2, "One eligible Spadoodle Act must declare exactly two claw strikes.")
	if declarations.size() != 2:
		return
	var first: CombatEvent = declarations[0]
	var second: CombatEvent = declarations[1]
	_expect_true(first.event_id != second.event_id, "Each claw must retain a unique authoritative attack event.")
	_expect_equal(first.payload.get("action_instance_id"), second.payload.get("action_instance_id"), "Both claws must belong to one action instance.")
	_expect_equal(first.payload.get("strike_index"), 1, "First claw must use stable strike index 1.")
	_expect_equal(second.payload.get("strike_index"), 2, "Second claw must use stable strike index 2.")
	_expect_equal(first.payload.get("strikes_per_act"), 2, "The declaration must record the two-strike Act contract.")
	var action := _action_snapshot(session, String(first.payload.get("action_instance_id", "")))
	_expect_equal(action.get("required_acts"), 1, "Two claws must not become two Acts.")
	_expect_equal(action.get("at_at_start"), 1, "Spadoodle attack timing must remain AT 1.")
	_expect_equal(int(action.get("final_effect_due_at_us", 0)) - int(action.get("started_at_us", 0)), 5_000_000, "The shared AT-1 Act must last exactly five seconds.")
	session.advance_by(int(action.get("final_effect_due_at_us", 0)) - session.simulation.clock.get_elapsed_us())
	var accuracy_events := _events_for_source(session, &"physical_attack_accuracy_resolved", spadoodle_id)
	_expect_equal(accuracy_events.size(), 2, "Each claw must independently reach ACC resolution.")
	if accuracy_events.size() == 2:
		_expect_equal(accuracy_events[0].payload.get("strike_index"), 1, "First claw ACC result must remain distinct.")
		_expect_equal(accuracy_events[1].payload.get("strike_index"), 2, "Second claw ACC result must remain distinct.")
	var attack_ids := PackedStringArray([String(first.payload.get("attack_instance_id", "")), String(second.payload.get("attack_instance_id", ""))])
	_expect_true(attack_ids[0] != attack_ids[1], "Independent claw resolution requires independent attack instances.")
	for attack_id: String in attack_ids:
		var snapshot := _attack_snapshot(session, attack_id)
		_expect_true(not snapshot.is_empty() and String(snapshot.get("status", "")) != "executing", "Each claw must independently terminate through ACC, defense, and damage gates.")


func _test_directional_size_targeting_and_location_armor() -> void:
	var session := _ready_wave_session(32_202, true)
	var target_id := StringName(session.get_targetable_enemy_ids()[0])
	_expect_true(session.select_target(target_id).get("success", false), "Spadoodle must be selectable.")
	_expect_true(session.select_target_location_by_number(1).get("success", false), "All existing hit locations must remain selectable.")
	var player_attack := session.request_player_attack("task32a")
	_expect_true(player_attack.get("success", false), "Guard must declare the existing approach-capable attack against a Spadoodle.")
	var declaration := _last_event(session, &"physical_attack_declared", Fixture.PLAYER_ID)
	_expect_true(declaration != null, "Guard declaration must be recorded.")
	if declaration != null:
		_expect_equal(declaration.payload.get("size_relationship"), "medium_to_small", "Guard-to-Spadoodle targeting must use directional Medium-to-Small ACC.")
		_expect_equal(declaration.payload.get("target_location"), "head", "Declared hit location must lock independently of later selection.")

	var reverse := _ready_wave_session(32_203, true)
	var attacker_id := StringName(reverse.get_targetable_enemy_ids()[0])
	reverse.simulation.apply_authoritative_position(attacker_id, PLAYER_POSITION + Vector2i(2_000_000, 0), 180_000)
	var reverse_declarations := _advance_until_declarations(reverse, attacker_id, 2)
	if reverse_declarations.size() >= 1:
		_expect_equal(reverse_declarations[0].payload.get("size_relationship"), "small_to_medium", "Spadoodle-to-Guard targeting must use directional Small-to-Medium ACC.")
	else:
		_failures.append("Spadoodle reverse-direction attack did not declare in verified claw reach.")


func _test_wave_victory_reset_replay_and_two_client_convergence() -> void:
	var session := _ready_wave_session(32_204, true)
	var ids := session.get_targetable_enemy_ids()
	for index in range(ids.size() - 1):
		session.get_actor_state(StringName(ids[index])).current_hpc = 0
		session.evaluate_current_wave_victory()
		_expect_equal(session.get_arena_wave_state().get("state"), ArenaWaveStateMachine.STATE_ACTIVE, "Wave 2 must remain active while any Spadoodle lives.")
	session.get_actor_state(StringName(ids[ids.size() - 1])).current_hpc = 0
	session.advance_by(1)
	_expect_equal(session.get_arena_wave_state().get("state"), ArenaWaveStateMachine.STATE_VICTORY_DETECTED, "Wave 2 victory requires every active Spadoodle defeated.")
	_expect_equal(session.get_encounter_state(), ArenaCombatSession.ENCOUNTER_PLAYER_VICTORY, "Wave 2 victory must stop without beginning Wave 3.")

	var replay := _ready_wave_session(32_205, false)
	var before_reset := _event_signature(replay)
	var before_state := replay.get_arena_wave_state()
	_expect_true(replay.reset_encounter(false).get("success", false), "Wave 2 reset must rebuild from the same seed.")
	_expect_equal(_event_signature(replay), before_reset, "Wave 2 reset must reproduce the authoritative event history.")
	_expect_equal(replay.get_arena_wave_state(), before_state, "Wave 2 reset must reproduce quantity and active roster state.")

	var harness := TwoClientSyncHarness.new(32_206)
	var authority_session := ArenaCombatSession.new(32_206, harness.authority.simulation, Fixture.ENCOUNTER_WAVE_TWO_SPADOODLES)
	authority_session.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
	_expect_true(authority_session.initialize_wave_two_spadoodles(PLAYER_POSITION, SPADOODLE_POSITION, false).get("success", false), "External authority must initialize Wave 2.")
	harness.deliver_in_order(harness.authority.publish_current_events())
	_expect_true(harness.compare_clients().get("success", false), "Wave 2 event delivery must converge on both simulated clients.")
	_expect_equal(harness.authority.get_state_digest(), harness.client_a.get_state_digest(), "Wave 2 replay digest must match the authoritative digest.")


func _test_maximum_wave_navigation_and_frame_partition() -> void:
	var seed := _find_seed_for_count(3)
	_expect_true(seed > 0, "A deterministic seed for three Spadoodles must be discoverable.")
	if seed <= 0:
		return
	var coarse := _ready_wave_session(seed, true)
	var partitioned := _ready_wave_session(seed, true)
	coarse.advance_by(5_000_000)
	for unused in range(50):
		partitioned.advance_by(100_000)
	_expect_equal(_event_signature(partitioned), _event_signature(coarse), "Maximum Wave 2 movement/combat must be independent of caller frame partitioning.")
	_expect_equal(partitioned.simulation.get_state_snapshot(), coarse.simulation.get_state_snapshot(), "Maximum Wave 2 final combat state must remain deterministic.")
	for rebuild_count: Variant in partitioned.get_goblin_path_rebuild_counts_for_testing().values():
		_expect_true(int(rebuild_count) < 100, "Three-Spadoodle pursuit must not trigger pathological route rebuilding in five seconds.")


func _test_launcher_and_presentation() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		_failures.append("SceneTree unavailable for Wave 2 launcher verification.")
		return
	var packed: PackedScene = load("res://scenes/test_arena.tscn")
	var scene := packed.instantiate()
	tree.root.add_child(scene)
	var controller := scene.get_node("CombatController") as ArenaCombatController
	var selected := controller.select_encounter_fixture_for_testing(Fixture.ENCOUNTER_WAVE_TWO_SPADOODLES)
	_expect_true(selected.get("success", false), "Wave 2 must be selectable through the existing development encounter control.")
	var session := controller.get_combat_session_for_testing()
	_expect_equal(session.get_arena_wave_state().get("current_wave_id"), "wave_2", "Launcher selection must instantiate the playable Wave 2 fixture.")
	for actor_id: String in session.get_targetable_enemy_ids():
		var visual := controller._get_enemy_visual(StringName(actor_id))
		_expect_true(visual != null and visual.visible, "Each living Spadoodle must have a visible selectable actor presentation.")
		if visual != null:
			var glyph := visual.get_node_or_null("Glyph") as Label
			_expect_equal(glyph.text if glyph != null else "", "S", "Spadoodle placeholders must be visibly distinguished from Goblins.")
	_expect_equal(ArenaCombatController.compact_actor_name(&"wave_2_common_spadoodle_03"), "SPADOODLE 3", "Wave 2 actor IDs need concise HUD names.")
	tree.root.remove_child(scene)
	scene.free()


func _ready_wave_session(seed: int, start_active: bool) -> ArenaCombatSession:
	var session := ArenaCombatSession.new(seed, null, Fixture.ENCOUNTER_WAVE_TWO_SPADOODLES)
	session.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
	session.set_opponent_behavior_enabled(true)
	_expect_true(session.initialize_wave_two_spadoodles(PLAYER_POSITION, SPADOODLE_POSITION, start_active).get("success", false), "Common Spadoodle Wave 2 fixture must initialize.")
	return session


func _find_seed_for_count(expected_count: int) -> int:
	for seed in range(1, 256):
		var session := _ready_wave_session(seed, false)
		if session.get_targetable_enemy_ids().size() == expected_count:
			return seed
	return -1


func _advance_until_declarations(session: ArenaCombatSession, actor_id: StringName, required_count: int) -> Array[CombatEvent]:
	for unused in range(120):
		var declarations := _events_for_source(session, &"physical_attack_declared", actor_id)
		if declarations.size() >= required_count:
			return declarations
		session.advance_by(100_000)
	return _events_for_source(session, &"physical_attack_declared", actor_id)


func _events_for_source(session: ArenaCombatSession, event_type: StringName, actor_id: StringName) -> Array[CombatEvent]:
	var result: Array[CombatEvent] = []
	for event: CombatEvent in session.get_resolved_events():
		if event.event_type == event_type and event.source_actor_id == actor_id:
			result.append(event)
	return result


func _last_event(session: ArenaCombatSession, event_type: StringName, actor_id: StringName) -> CombatEvent:
	for index in range(session.get_resolved_events().size() - 1, -1, -1):
		var event: CombatEvent = session.get_resolved_events()[index]
		if event.event_type == event_type and event.source_actor_id == actor_id:
			return event
	return null


func _action_snapshot(session: ArenaCombatSession, action_id: String) -> Dictionary:
	for action: Dictionary in session.simulation.get_state_snapshot().get("actions", []):
		if String(action.get("action_instance_id", "")) == action_id:
			return action
	return {}


func _attack_snapshot(session: ArenaCombatSession, attack_id: String) -> Dictionary:
	for attack: Dictionary in session.simulation.get_state_snapshot().get("attacks", []):
		if String(attack.get("attack_instance_id", "")) == attack_id:
			return attack
	return {}


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
