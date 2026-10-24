class_name FiveWaveEncounterFrameworkTests
extends RefCounted

const ArenaCombatSession = preload("res://scripts/combat/arena_combat_session.gd")
const ArenaWaveCatalog = preload("res://scripts/combat/arena_wave_catalog.gd")
const ArenaWaveStateMachine = preload("res://scripts/combat/arena_wave_state_machine.gd")
const CombatActorDefinition = preload("res://scripts/combat/combat_actor_definition.gd")
const CombatSimulation = preload("res://scripts/combat/combat_simulation.gd")
const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
const TwoClientSyncHarness = preload("res://scripts/sync/two_client_sync_harness.gd")

const PLAYER_POSITION := Vector2i(20_000_000, 12_000_000)
const OPPONENT_POSITION := Vector2i(22_000_000, 12_000_000)

var _failures: Array[String] = []


func run() -> Array[String]:
	_failures.clear()
	_test_catalog_is_exact_and_creature_free()
	_test_seeded_initialization_blocks_without_creature_integrations()
	_test_state_machine_transition_contract()
	_test_automatic_between_wave_recovery_is_prohibited()
	_test_safe_downtime_preserves_authoritative_actor_state()
	_test_multiplayer_deadline_uses_separate_authoritative_time()
	_test_next_wave_control_presentation()
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
	_expect_true(machine.begin_between_wave_downtime().get("success", false), "Only detected victory may enter between-wave downtime.")
	_expect_equal(machine.get_state(), ArenaWaveStateMachine.STATE_BETWEEN_WAVE_DOWNTIME, "Wave 1 victory must enter between-wave downtime.")
	_expect_true(machine.advance_from_between_wave_downtime(roll_quantity, "solo_next_wave").get("success", false), "An explicit downtime action must advance deterministically to the next configured wave.")
	_expect_equal(machine.get_current_wave_id(), "wave_2", "Advancement must select Wave 2.")
	_expect_equal(machine.get_state(), ArenaWaveStateMachine.STATE_BLOCKED, "Wave 2 must block until its own creature integration exists.")


func _test_automatic_between_wave_recovery_is_prohibited() -> void:
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
	var preserved := state.to_dictionary()
	var recovery := simulation.restore_actor_between_wave_resources(&"recovery_actor")
	_expect_true(not recovery.get("success", false), "The obsolete automatic recovery entry point must fail closed.")
	_expect_equal(recovery.get("reason"), "automatic_between_wave_recovery_prohibited", "The recovery rejection must identify the superseding downtime rule.")
	_expect_equal(state.to_dictionary(), preserved, "The rejected recovery call must preserve HPC, Mana, AP, uses and all other actor state exactly.")


func _test_safe_downtime_preserves_authoritative_actor_state() -> void:
	var session := ArenaCombatSession.new(35_101, null, Fixture.ENCOUNTER_WAVE_ONE_GOBLINS, Fixture.PLAYER_CHARACTER_VAELIS)
	_expect_true(session.initialize_wave_one_goblins(PLAYER_POSITION, OPPONENT_POSITION, true).get("success", false), "Playable Wave 1 must initialize for downtime coverage.")
	var player_state := session.get_actor_state(Fixture.PLAYER_ID)
	player_state.current_hpc = 6
	player_state.resources["mana"] = 11
	player_state.resources["ap"] = 2
	player_state.ability_daily_remaining["fixture_daily_use"] = 0
	player_state.equipment_refs.append(&"preserved_test_equipment")
	player_state.hand_occupancy = {"left": "preserved_item", "right": "short_wand"}
	player_state.hand_occupancy_authoritative = true
	player_state.held_materials = {"dirt": 1}
	player_state.conditions.append(&"preserved_injury")
	player_state.timed_stat_effects["paused_effect"] = {
		"effect_id": "paused_effect",
		"expires_at_us": session.simulation.clock.get_elapsed_us() + 5_000_000,
		"stat_modifiers": {"nal": 2},
	}
	player_state.persistent_damage_shields["force_shield"] = {
		"shield_id": "force_shield",
		"capacity": 13,
		"maximum_capacity": 20,
	}
	var preserved := player_state.to_dictionary()
	_forcibly_defeat_active_wave(session)
	session.advance_by(1)
	_expect_equal(session.get_encounter_state(), ArenaCombatSession.ENCOUNTER_BETWEEN_WAVE_DOWNTIME, "Wave victory must enter safe downtime automatically.")
	_expect_equal(session.get_arena_wave_state().get("state"), ArenaWaveStateMachine.STATE_BETWEEN_WAVE_DOWNTIME, "Authoritative wave state must identify downtime explicitly.")
	_expect_equal(player_state.to_dictionary(), preserved, "Entering downtime must preserve HPC, Mana, AP, equipment, held materials, injuries, effects and Force Shield capacity exactly.")
	var combat_clock_us := session.simulation.clock.get_elapsed_us()
	var event_count := session.get_resolved_event_count()
	session.advance_by(300_000_000)
	_expect_equal(session.simulation.clock.get_elapsed_us(), combat_clock_us, "Unlimited solo downtime must not advance combat simulation time.")
	_expect_equal(session.get_resolved_event_count(), event_count, "Waiting in downtime must not create combat or enemy-action events.")
	_expect_equal(player_state.to_dictionary(), preserved, "Arbitrary downtime must not restore resources or expire effects.")
	var advance := session.request_next_wave()
	_expect_true(advance.get("success", false), "Solo NEXT WAVE must perform one explicit authoritative advancement.")
	_expect_equal(session.get_arena_wave_state().get("current_wave_id"), "wave_2", "Solo NEXT WAVE must select Wave 2 exactly once.")
	_expect_equal(player_state.to_dictionary(), preserved, "Explicit wave advancement must carry the complete actor state forward unchanged.")
	_expect_equal(session.request_next_wave().get("reason"), "wave_advance_already_committed", "A repeated NEXT WAVE request must not advance twice.")
	_expect_equal(_count_wave_events(session, "arena_wave_downtime_completed"), 1, "Solo advancement must record one downtime completion event.")
	_expect_true(session.reset_encounter(false).get("success", false), "RESET must remain a safe deterministic fixture reconstruction after downtime.")
	_expect_equal(session.get_encounter_state(), ArenaCombatSession.ENCOUNTER_READY, "RESET must return the development fixture to READY without implying persistent-profile deletion.")
	_expect_equal(session.get_arena_wave_state().get("current_wave_id"), "wave_1", "Wave fixture RESET must return to its configured starting wave.")
	_expect_true(session.get_actor_state(Fixture.PLAYER_ID).persistent_damage_shields.is_empty(), "RESET must reconstruct fresh temporary encounter state rather than carrying the prior run's shield.")


func _test_multiplayer_deadline_uses_separate_authoritative_time() -> void:
	var first := _multiplayer_downtime_session(35_102)
	var second := _multiplayer_downtime_session(35_102)
	var first_clock_us := first.simulation.clock.get_elapsed_us()
	_expect_true(first.advance_multiplayer_downtime_real_time(119_999).get("success", false), "An authoritative multiplayer downtime delta below the deadline must be accepted.")
	_expect_equal(first.get_arena_wave_state().get("state"), ArenaWaveStateMachine.STATE_BETWEEN_WAVE_DOWNTIME, "Multiplayer downtime must remain active before 120 seconds.")
	_expect_equal(first.simulation.clock.get_elapsed_us(), first_clock_us, "Multiplayer wall-clock downtime must not advance combat simulation time.")
	var deadline := first.advance_multiplayer_downtime_real_time(1)
	_expect_true(deadline.get("success", false) and deadline.get("advanced", false), "The authoritative 120-second boundary must advance automatically.")
	second.advance_multiplayer_downtime_real_time(60_000)
	second.advance_multiplayer_downtime_real_time(60_000)
	_expect_equal(first.get_state_snapshot(), second.get_state_snapshot(), "Equivalent authoritative downtime totals must converge without using a client clock.")
	_expect_equal(_wave_event_signature(first), _wave_event_signature(second), "Equivalent deadline inputs must preserve deterministic wave event history.")
	_expect_equal(_count_wave_events(first, "arena_wave_multiplayer_deadline_reached"), 1, "The multiplayer deadline must be recorded exactly once.")
	_expect_true(not first.advance_multiplayer_downtime_real_time(1).get("success", false), "A completed multiplayer deadline must reject duplicate advancement.")

	var harness := TwoClientSyncHarness.new(35_103)
	var authority_session := ArenaCombatSession.new(35_103, harness.authority.simulation, Fixture.ENCOUNTER_WAVE_ONE_GOBLINS)
	authority_session.set_session_mode(ArenaCombatSession.SESSION_MODE_MULTIPLAYER)
	_expect_true(authority_session.initialize_wave_one_goblins(PLAYER_POSITION, OPPONENT_POSITION, true).get("success", false), "External multiplayer authority must initialize Wave 1.")
	_forcibly_defeat_active_wave(authority_session)
	authority_session.advance_by(1)
	authority_session.advance_multiplayer_downtime_real_time(120_000)
	var envelopes := harness.authority.publish_current_events()
	harness.deliver_in_order(envelopes)
	_expect_true(harness.compare_clients().get("success", false), "Downtime and deadline events must converge for two simulated clients.")
	_expect_equal(harness.authority.get_state_digest(), harness.client_a.get_state_digest(), "The deadline transition snapshot must match the authoritative digest.")


func _test_next_wave_control_presentation() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		_failures.append("SceneTree unavailable for NEXT WAVE control verification.")
		return
	var packed: PackedScene = load("res://scenes/test_arena.tscn")
	var scene := packed.instantiate()
	tree.root.add_child(scene)
	var controller := scene.get_node("CombatController") as ArenaCombatController
	_expect_true(controller.select_encounter_fixture_for_testing(Fixture.ENCOUNTER_WAVE_ONE_GOBLINS).get("success", false), "Wave 1 must remain selectable for NEXT WAVE control coverage.")
	controller.press_encounter_control_for_testing()
	var session := controller.get_combat_session_for_testing()
	_forcibly_defeat_active_wave(session)
	session.advance_by(1)
	controller.call("_update_presentation")
	var encounter_button := scene.get_node("HUD/UI/EncounterButton") as Button
	_expect_equal(encounter_button.text, "NEXT WAVE", "Solo downtime must expose the explicit NEXT WAVE control.")
	controller.press_encounter_control_for_testing()
	_expect_equal(session.get_arena_wave_state().get("current_wave_id"), "wave_2", "The NEXT WAVE control must advance the authoritative circuit.")
	_expect_equal(encounter_button.text, "RESET", "After one advancement the control must not continue issuing duplicate NEXT WAVE requests.")
	tree.root.remove_child(scene)
	scene.free()


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


func _multiplayer_downtime_session(seed_value: int) -> ArenaCombatSession:
	var session := ArenaCombatSession.new(seed_value, null, Fixture.ENCOUNTER_WAVE_ONE_GOBLINS)
	_expect_true(session.set_session_mode(ArenaCombatSession.SESSION_MODE_MULTIPLAYER).get("success", false), "The future-compatible multiplayer mode must configure before combat.")
	_expect_true(session.initialize_wave_one_goblins(PLAYER_POSITION, OPPONENT_POSITION, true).get("success", false), "Multiplayer deadline fixture must initialize Wave 1.")
	_forcibly_defeat_active_wave(session)
	session.advance_by(1)
	_expect_equal(session.get_encounter_state(), ArenaCombatSession.ENCOUNTER_BETWEEN_WAVE_DOWNTIME, "Multiplayer Wave victory must enter downtime.")
	return session


func _forcibly_defeat_active_wave(session: ArenaCombatSession) -> void:
	for actor_id: String in session.get_targetable_enemy_ids():
		session.get_actor_state(StringName(actor_id)).current_hpc = 0


func _count_wave_events(session: ArenaCombatSession, event_type: String) -> int:
	var count := 0
	for event: CombatEvent in session.get_resolved_events():
		if String(event.event_type) == event_type:
			count += 1
	return count


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
