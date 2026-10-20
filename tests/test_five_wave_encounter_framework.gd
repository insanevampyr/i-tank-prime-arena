class_name FiveWaveEncounterFrameworkTests
extends RefCounted

const ArenaCombatSession = preload("res://scripts/combat/arena_combat_session.gd")
const ArenaWaveCatalog = preload("res://scripts/combat/arena_wave_catalog.gd")
const ArenaWaveStateMachine = preload("res://scripts/combat/arena_wave_state_machine.gd")
const CombatActorDefinition = preload("res://scripts/combat/combat_actor_definition.gd")
const CombatSimulation = preload("res://scripts/combat/combat_simulation.gd")
const TwoClientSyncHarness = preload("res://scripts/sync/two_client_sync_harness.gd")

const PLAYER_POSITION := Vector2i(20_000_000, 12_000_000)
const OPPONENT_POSITION := Vector2i(22_000_000, 12_000_000)

var _failures: Array[String] = []


func run() -> Array[String]:
	_failures.clear()
	_test_catalog_is_exact_and_creature_free()
	_test_seeded_initialization_blocks_without_creature_integrations()
	_test_state_machine_transition_contract()
	_test_recovery_restores_only_modeled_resources()
	_test_reset_replays_wave_draws_and_history()
	_test_replay_and_two_client_convergence()
	return _failures


func _test_catalog_is_exact_and_creature_free() -> void:
	var waves := ArenaWaveCatalog.definitions()
	_expect_equal(waves.size(), 5, "Five-wave catalog must have exactly five configured waves.")
	var expected := [
		["common_goblin", "dice", 4, 2],
		["common_spadoodle", "dice", 3],
		["common_skelly", "dice", 2, "hades_combat_follower", "fixed", 1],
		["mini_gargoyle_swarmer", "dice", 4],
		["rare_human_warrior", "fixed", 1],
	]
	for index in range(expected.size()):
		var roster: Array = waves[index]["roster"]
		_expect_equal(String(roster[0]["creature_id"]), expected[index][0], "Wave %d primary roster identity must match the approved sequence." % (index + 1))
		_expect_equal(String(roster[0]["quantity"]["kind"]), expected[index][1], "Wave %d primary quantity kind must match the approved sequence." % (index + 1))
		var quantity := roster[0]["quantity"] as Dictionary
		var quantity_value := int(quantity.get("sides", quantity.get("count", -1)))
		_expect_equal(quantity_value, expected[index][2], "Wave %d primary quantity value must match the approved sequence." % (index + 1))
		_expect_equal(int(quantity.get("dice_count", 0)), (2 if index == 0 else 1) if expected[index][1] == "dice" else 0, "Wave %d dice count must match its approved quantity expression." % (index + 1))
		for entry: Dictionary in roster:
			_expect_equal(entry.get("creature_integration_status"), "not_implemented", "Task 31B roster entries must not claim creature implementation.")
	_expect_equal(String(waves[2]["roster"][1]["creature_id"]), expected[2][3], "Wave 3 must retain the Hades Combat Follower.")


func _test_seeded_initialization_blocks_without_creature_integrations() -> void:
	var first := _ready_session(31_001)
	var second := _ready_session(31_001)
	var first_result := first.initialize_five_wave_arena()
	var second_result := second.initialize_five_wave_arena()
	_expect_true(first_result.get("success", false) and second_result.get("success", false), "Ready encounters must initialize the wave framework.")
	var first_state := first.get_arena_wave_state()
	var second_state := second.get_arena_wave_state()
	_expect_equal(first_state.get("state"), ArenaWaveStateMachine.STATE_BLOCKED, "Wave 1 must block until an actual creature integration exists.")
	_expect_equal(first_state.get("current_wave_id"), "wave_1", "Wave initialization must begin at Wave 1.")
	_expect_equal(first_state.get("resolved_roster"), second_state.get("resolved_roster"), "Same seed must resolve identical wave quantities.")
	var roster: Array = first_state.get("resolved_roster", [])
	_expect_true(not roster.is_empty() and int(roster[0].get("resolved_count", 0)) >= 2 and int(roster[0].get("resolved_count", 0)) <= 8, "Wave 1 must record a legal Arena 2d4 count.")
	_expect_true(roster.size() == 1 and (roster[0].get("rng_draw_indices", []) as Array).size() == 2, "Wave 1 must preserve both authoritative RNG draw indexes.")
	_expect_equal(roster[0].get("resolved_count"), int(roster[0].get("dice_results", [0, 0])[0]) + int(roster[0].get("dice_results", [0, 0])[1]), "Wave 1 count must be the sum of its two retained die results.")
	var event_types := _event_types(first)
	_expect_true(event_types.has("arena_wave_circuit_initialized"), "Wave initialization must enter the retained authoritative event history.")
	_expect_true(event_types.has("arena_wave_quantity_resolved"), "Wave quantity resolution must enter the retained authoritative event history.")
	_expect_true(event_types.has("arena_wave_blocked"), "Unsupported creature waves must explicitly block in the retained history.")
	_expect_true(not first.start_encounter().get("success", false), "Wave framework setup must not accidentally start or alter the Guard duel.")


func _test_state_machine_transition_contract() -> void:
	var machine := ArenaWaveStateMachine.new()
	var draw_state := {"index": 0}
	var roll_quantity := func(sides: int) -> Dictionary:
		draw_state["index"] = int(draw_state["index"]) + 1
		return {"value": 2, "rng_draw_index": int(draw_state["index"]), "sides": sides}
	_expect_true(machine.initialize(roll_quantity).get("success", false), "State machine must initialize deterministically.")
	_expect_equal(draw_state["index"], 2, "Arena Wave 1 must consume exactly two independent quantity draws.")
	_expect_equal(machine.get_state(), ArenaWaveStateMachine.STATE_BLOCKED, "Unintegrated wave must block rather than simulate a victory.")
	machine.set_creature_integration_available(&"common_goblin", true)
	var active_ids := PackedStringArray(["integration_contract_enemy_01", "integration_contract_enemy_02", "integration_contract_enemy_03", "integration_contract_enemy_04"])
	_expect_true(machine.activate_current_wave(active_ids).get("success", false), "A future verified integration may activate only its resolved roster count.")
	_expect_equal(machine.get_state(), ArenaWaveStateMachine.STATE_ACTIVE, "Activation must enter active-combat state.")
	var alive := {}
	for actor_id: String in active_ids:
		alive[actor_id] = {"defeated": false}
	_expect_true(machine.observe_active_enemy_states(alive).get("success", false), "Active-state observation must accept complete authoritative status data.")
	_expect_equal(machine.get_state(), ArenaWaveStateMachine.STATE_ACTIVE, "Any living wave enemy must keep the wave active.")
	for actor_id: String in active_ids:
		alive[actor_id] = {"defeated": true}
	_expect_true(machine.observe_active_enemy_states(alive).get("success", false), "All defeated authoritative statuses must detect victory.")
	_expect_equal(machine.get_state(), ArenaWaveStateMachine.STATE_VICTORY_DETECTED, "Victory must be a distinct transition before recovery.")
	_expect_true(machine.begin_between_wave_recovery().get("success", false), "Only detected victory may enter between-wave recovery.")
	_expect_equal(machine.get_state(), ArenaWaveStateMachine.STATE_BETWEEN_WAVE_RECOVERY, "Wave 1 victory must enter between-wave recovery.")
	_expect_true(machine.complete_between_wave_recovery(roll_quantity).get("success", false), "Recovery completion must advance deterministically to the next configured wave.")
	_expect_equal(machine.get_current_wave_id(), "wave_2", "Advancement must select Wave 2.")
	_expect_equal(machine.get_state(), ArenaWaveStateMachine.STATE_BLOCKED, "Wave 2 must block until its own creature integration exists.")


func _test_recovery_restores_only_modeled_resources() -> void:
	var simulation := CombatSimulation.new(31_002)
	var definition := CombatActorDefinition.new(
		&"recovery_actor",
		&"task31b_recovery_contract",
		"Recovery Contract Actor",
		{},
		{"hpm": 25, "at": 1, "init": 0},
		{"mana": 7, "ap": 3, "ability_uses": 2}
	)
	_expect_true(simulation.register_actor(definition).get("success", false), "Recovery test actor must register.")
	var state := simulation.get_actor_state(&"recovery_actor")
	state.current_hpc = 4
	state.resources = {"mana": 1, "ap": 0, "ability_uses": 0}
	var recovery := simulation.restore_actor_between_wave_resources(&"recovery_actor")
	_expect_true(recovery.get("success", false), "Modeled between-wave recovery must restore legal maxima.")
	_expect_equal(state.current_hpc, 25, "Recovery must restore HPC from the registered HPM value.")
	_expect_equal(state.resources, {"mana": 7, "ap": 3, "ability_uses": 2}, "Recovery must restore only maxima-backed resources, including modeled ability uses.")


func _test_reset_replays_wave_draws_and_history() -> void:
	var session := _ready_session(31_003)
	_expect_true(session.initialize_five_wave_arena().get("success", false), "Initial wave setup must succeed.")
	var first_state := session.get_arena_wave_state().duplicate(true)
	var first_events := _wave_event_signature(session)
	var reset := session.reset_five_wave_arena()
	_expect_true(reset.get("success", false), "Explicit wave reset must rebuild the deterministic wave circuit.")
	_expect_equal(session.get_arena_wave_state().get("resolved_roster"), first_state.get("resolved_roster"), "Wave reset must replay the same seed-derived quantity.")
	_expect_equal(_wave_event_signature(session), first_events, "Wave reset must reproduce the same wave event history from a fresh simulation.")


func _test_replay_and_two_client_convergence() -> void:
	var first := _ready_session(31_004)
	var second := _ready_session(31_004)
	first.initialize_five_wave_arena()
	second.initialize_five_wave_arena()
	_expect_equal(_wave_event_signature(first), _wave_event_signature(second), "Seeded wave replay must preserve events, IDs, timestamps and ordering.")
	_expect_equal(first.get_state_snapshot().get("arena_wave_state"), second.get_state_snapshot().get("arena_wave_state"), "Seeded wave replay must preserve authoritative wave snapshots.")
	var harness := TwoClientSyncHarness.new(31_005)
	var authority_session := ArenaCombatSession.new(31_005, harness.authority.simulation)
	_expect_true(authority_session.initialize(PLAYER_POSITION, OPPONENT_POSITION, false).get("success", false), "External-authority session must initialize.")
	authority_session.initialize_five_wave_arena()
	var envelopes := harness.authority.publish_current_events()
	harness.deliver_in_order(envelopes)
	_expect_true(harness.compare_clients().get("success", false), "Wave events and snapshot must converge for both observed clients.")
	_expect_true(harness.authority.get_state_digest() == harness.client_a.get_state_digest(), "Published wave history must match the authority digest.")


func _ready_session(seed_value: int) -> ArenaCombatSession:
	var session := ArenaCombatSession.new(seed_value)
	_expect_true(session.initialize(PLAYER_POSITION, OPPONENT_POSITION, false).get("success", false), "Test fixture must initialize in READY state.")
	return session


func _event_types(session: ArenaCombatSession) -> Array[String]:
	var types: Array[String] = []
	for event: CombatEvent in session.get_resolved_events():
		types.append(String(event.event_type))
	return types


func _wave_event_signature(session: ArenaCombatSession) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event: CombatEvent in session.get_resolved_events():
		if String(event.event_type).begins_with("arena_wave_"):
			result.append(event.to_dictionary())
	return result


func _expect_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s Expected %s, got %s." % [message, str(expected), str(actual)])
