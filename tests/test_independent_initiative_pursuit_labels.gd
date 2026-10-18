class_name IndependentInitiativePursuitLabelTests
extends RefCounted

const ArenaCombatSession = preload("res://scripts/combat/arena_combat_session.gd")
const ArenaBattlefield = preload("res://scripts/combat/arena_battlefield.gd")
const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
const EventPresenter = preload("res://scripts/ui/arena_combat_event_presenter.gd")
const TwoClientSyncHarness = preload("res://scripts/sync/two_client_sync_harness.gd")

const PLAYER_POSITION := Vector2i(20_000_000, 12_000_000)
const GOBLIN_POSITION := Vector2i(38_000_000, 12_000_000)
const STEP_US := 100_000

var _failures: Array[String] = []


func run() -> Array[String]:
	_failures.clear()
	_test_lower_initiative_enemy_acts_without_player_attack()
	_test_true_simultaneous_effects_still_use_init()
	_test_stationary_and_moving_target_pursuit()
	_test_reach_changes_use_legal_exact_destinations()
	_test_authoritative_attack_labels()
	_test_moving_pursuit_replay_and_client_convergence()
	return _failures


func _test_lower_initiative_enemy_acts_without_player_attack() -> void:
	var fixture := _find_lower_initiative_goblin_fixture()
	var session: ArenaCombatSession = fixture.get("session")
	var goblin_id := StringName(fixture.get("goblin_id", ""))
	_expect_true(session != null and not String(goblin_id).is_empty(), "A seeded lower-Initiative Goblin fixture must exist.")
	if session == null or String(goblin_id).is_empty():
		return
	var player_rank := int(session.get_actor_state(Fixture.PLAYER_ID).opening_order_rank)
	var goblin_rank := int(session.get_actor_state(goblin_id).opening_order_rank)
	_expect_true(goblin_rank > player_rank, "The focused Goblin must genuinely have lower opening Initiative than the player.")
	_expect_true(session.simulation.apply_authoritative_position(goblin_id, PLAYER_POSITION + Vector2i(1_000_000, 0), 180_000).get("success", false), "The lower-Initiative Goblin test position must be authoritative.")
	_expect_true(session.start_encounter().get("success", false), "The prepared Wave-1 encounter must start.")
	var declarations := _events_for_source(session, "physical_attack_declared", goblin_id)
	_expect_equal(declarations.size(), 2, "A lower-Initiative Goblin must independently declare both fists without any player attack.")
	_expect_equal(_events_for_source(session, "physical_attack_declared", Fixture.PLAYER_ID).size(), 0, "The independent-enemy test must not submit a player attack.")
	if declarations.size() == 2:
		_expect_equal(declarations[0].timestamp_us, 0, "Independent enemy declaration must not add an Initiative delay.")
		_expect_equal(declarations[0].payload.get("action_instance_id"), declarations[1].payload.get("action_instance_id"), "Both fists must remain one ordinary Act.")


func _test_true_simultaneous_effects_still_use_init() -> void:
	var simulation := CombatSimulation.new(31_501)
	simulation.schedule_event(1_000_000, &"lower_init_effect", 3)
	simulation.schedule_event(1_000_000, &"higher_init_effect", 9)
	var ordered := simulation.event_queue.drain()
	_expect_equal(String(ordered[0].event_type), "higher_init_effect", "Higher INIT must still win a genuine same-timestamp effect tie.")
	_expect_equal(String(ordered[1].event_type), "lower_init_effect", "Independent declaration must not remove the existing INIT effect ordering.")


func _test_stationary_and_moving_target_pursuit() -> void:
	var stationary_seed := _find_seed_for_count(2)
	var stationary := _wave_session(stationary_seed, PLAYER_POSITION, Vector2i(24_000_000, 12_000_000), true)
	for _step in range(70):
		stationary.advance_by(STEP_US)
	_expect_true(_count_goblin_events(stationary, "physical_attack_declared") > 0, "Goblins must continue approaching and attacking a stationary target.")

	for goblin_count in range(2, 5):
		var seed_value := _find_seed_for_count(goblin_count)
		var session := _wave_session(seed_value, PLAYER_POSITION, GOBLIN_POSITION, true)
		var ids: Array = session.get_targetable_enemy_ids()
		var initial_distances := {}
		var previous_positions := {}
		var previous_steps := {}
		var reversals := {}
		for actor_id: String in ids:
			var position: Vector2i = session.get_actor_state(StringName(actor_id)).position_microfeet
			initial_distances[actor_id] = _distance(position, PLAYER_POSITION)
			previous_positions[actor_id] = position
			previous_steps[actor_id] = Vector2i.ZERO
			reversals[actor_id] = 0
		_apply_turning_player_path(session, ids, previous_positions, previous_steps, reversals)
		var final_player := session.get_actor_state(Fixture.PLAYER_ID).position_microfeet
		var rebuilds := session.get_goblin_path_rebuild_counts_for_testing()
		for actor_id: String in ids:
			var final_position: Vector2i = session.get_actor_state(StringName(actor_id)).position_microfeet
			_expect_true(_distance(final_position, final_player) < int(initial_distances[actor_id]), "%s must make net legal pursuit progress against a moving target." % actor_id)
			_expect_true(int(reversals[actor_id]) <= 6, "%s must not oscillate across repeated opposite movement directions." % actor_id)
			_expect_true(int(rebuilds.get(actor_id, 0)) <= 5, "%s must retain/retarget its route rather than repeatedly run full searches." % actor_id)


func _test_reach_changes_use_legal_exact_destinations() -> void:
	var battlefield := ArenaBattlefield.create_task16_test_arena()
	var mover := &"reach_probe"
	var start := Vector2i(38_000_000, 12_000_000)
	var target := Vector2i(20_350_000, 13_250_000)
	var occupancy := {String(mover): start, "player": target}
	for reach in [1_000_000, 3_000_000]:
		var result := battlefield.find_path_to_attack_position(mover, start, target, reach, occupancy)
		_expect_true(result.get("success", false), "Changing verified melee reach must still produce a deterministic legal path.")
		var path: Array = result.get("waypoints", [])
		_expect_true(not path.is_empty(), "The reach fixture must produce an exact final attack destination.")
		if not path.is_empty():
			_expect_true(battlefield.is_attack_position_legal(path[-1], target, reach), "The final waypoint must satisfy the currently supplied reach and LOS.")


func _test_authoritative_attack_labels() -> void:
	var guard := ArenaCombatSession.new(31_502)
	_expect_true(guard.initialize(PLAYER_POSITION, PLAYER_POSITION + Vector2i(3_000_000, 0)).get("success", false), "Guard label fixture must initialize.")
	var guard_start := guard.request_player_attack("label_test")
	_expect_true(guard_start.get("success", false), "Guard label fixture must declare the Battle Axe attack.")
	var guard_event := _last_event_from(guard, "physical_attack_declared", Fixture.PLAYER_ID)
	_expect_true(guard_event != null and EventPresenter.format_event(guard_event).contains("Battle Axe attack"), "Player declarations must retain the genuine Battle Axe label.")

	var goblin_fixture := _find_lower_initiative_goblin_fixture()
	var wave: ArenaCombatSession = goblin_fixture.get("session")
	var goblin_id := StringName(goblin_fixture.get("goblin_id", ""))
	if wave == null or String(goblin_id).is_empty():
		_failures.append("Goblin label fixture requires a valid seeded encounter.")
		return
	wave.simulation.apply_authoritative_position(goblin_id, PLAYER_POSITION + Vector2i(1_000_000, 0), 180_000)
	wave.start_encounter()
	var declarations := _events_for_source(wave, "physical_attack_declared", goblin_id)
	_expect_equal(declarations.size(), 2, "Goblin label fixture must expose both declared fists.")
	if declarations.size() == 2:
		var first_label := EventPresenter.format_event(declarations[0])
		var second_label := EventPresenter.format_event(declarations[1])
		_expect_true(first_label.contains("Fists attack 1/2") and not first_label.contains("Battle Axe"), "First Goblin strike must identify Fists 1/2, never Battle Axe.")
		_expect_true(second_label.contains("Fists attack 2/2") and not second_label.contains("Battle Axe"), "Second Goblin strike must identify Fists 2/2, never Battle Axe.")


func _test_moving_pursuit_replay_and_client_convergence() -> void:
	var seed_value := _find_seed_for_count(4)
	var sessions: Array[ArenaCombatSession] = []
	for _index in range(2):
		var session := _wave_session(seed_value, PLAYER_POSITION, GOBLIN_POSITION, true)
		_apply_simple_player_path(session)
		sessions.append(session)
	_expect_equal(_event_signature(sessions[0]), _event_signature(sessions[1]), "Same-seed moving pursuit must reproduce the complete authoritative event history.")
	_expect_equal(sessions[0].get_goblin_path_rebuild_counts_for_testing(), sessions[1].get_goblin_path_rebuild_counts_for_testing(), "Moving-target route continuity must be deterministic.")

	var harness := TwoClientSyncHarness.new(seed_value)
	var authority_session := ArenaCombatSession.new(seed_value, harness.authority.simulation, Fixture.ENCOUNTER_WAVE_ONE_GOBLINS)
	authority_session.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
	authority_session.set_opponent_behavior_enabled(true)
	_expect_true(authority_session.initialize_wave_one_goblins(PLAYER_POSITION, GOBLIN_POSITION, true).get("success", false), "Synchronization pursuit fixture must initialize.")
	_apply_simple_player_path(authority_session)
	var envelopes := harness.authority.publish_current_events()
	for envelope: CombatEventEnvelope in envelopes:
		harness.client_a.receive(envelope)
	for index in range(envelopes.size() - 1, -1, -1):
		harness.client_b.receive(envelopes[index])
	_expect_true(harness.compare_clients().get("success", false), "Moving-pursuit events must converge after out-of-order simulated delivery.")
	_expect_equal(harness.authority.get_state_digest(), harness.client_a.get_state_digest(), "Moving-pursuit authority and client digest must match.")


func _apply_turning_player_path(session: ArenaCombatSession, ids: Array, previous_positions: Dictionary, previous_steps: Dictionary, reversals: Dictionary) -> void:
	for step in range(120):
		var direction := Vector2i(50_000, 0) if step < 40 else (Vector2i(0, 50_000) if step < 80 else Vector2i(-50_000, 0))
		var player := session.get_actor_state(Fixture.PLAYER_ID)
		var movement := session.request_player_movement(player.position_microfeet + direction, 11)
		_expect_true(movement.get("success", false), "Turning-path player movement must remain legal.")
		session.advance_by(STEP_US)
		for actor_id: String in ids:
			var position: Vector2i = session.get_actor_state(StringName(actor_id)).position_microfeet
			var actor_step: Vector2i = position - previous_positions[actor_id]
			var prior_step: Vector2i = previous_steps[actor_id]
			if actor_step != Vector2i.ZERO and prior_step != Vector2i.ZERO and Vector2(actor_step).dot(Vector2(prior_step)) < 0:
				reversals[actor_id] = int(reversals[actor_id]) + 1
			if actor_step != Vector2i.ZERO:
				previous_steps[actor_id] = actor_step
			previous_positions[actor_id] = position


func _apply_simple_player_path(session: ArenaCombatSession) -> void:
	for step in range(60):
		var direction := Vector2i(50_000, 0) if step < 30 else Vector2i(0, 50_000)
		var player := session.get_actor_state(Fixture.PLAYER_ID)
		session.request_player_movement(player.position_microfeet + direction, 11)
		session.advance_by(STEP_US)


func _find_lower_initiative_goblin_fixture() -> Dictionary:
	for seed_value in range(1, 512):
		var session := _wave_session(seed_value, PLAYER_POSITION, Vector2i(24_000_000, 12_000_000), false)
		var player_rank := int(session.get_actor_state(Fixture.PLAYER_ID).opening_order_rank)
		for actor_id: String in session.get_targetable_enemy_ids():
			if int(session.get_actor_state(StringName(actor_id)).opening_order_rank) > player_rank:
				return {"session": session, "goblin_id": actor_id}
	return {}


func _find_seed_for_count(expected_count: int) -> int:
	for seed_value in range(1, 256):
		var session := ArenaCombatSession.new(seed_value, null, Fixture.ENCOUNTER_WAVE_ONE_GOBLINS)
		session.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
		if not session.initialize_wave_one_goblins(PLAYER_POSITION, GOBLIN_POSITION, false).get("success", false):
			continue
		if session.get_targetable_enemy_ids().size() == expected_count:
			return seed_value
	_failures.append("No deterministic seed produced %d Goblins." % expected_count)
	return 1


func _wave_session(seed_value: int, player_position: Vector2i, goblin_position: Vector2i, start_active: bool) -> ArenaCombatSession:
	var session := ArenaCombatSession.new(seed_value, null, Fixture.ENCOUNTER_WAVE_ONE_GOBLINS)
	session.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
	session.set_opponent_behavior_enabled(true)
	var result := session.initialize_wave_one_goblins(player_position, goblin_position, start_active)
	_expect_true(result.get("success", false), "Wave-1 Task 31E fixture must initialize.")
	return session


func _distance(left: Vector2i, right: Vector2i) -> int:
	return roundi(Vector2(left - right).length())


func _events_for_source(session: ArenaCombatSession, event_type: String, actor_id: StringName) -> Array[CombatEvent]:
	var matching: Array[CombatEvent] = []
	for event: CombatEvent in session.get_resolved_events():
		if String(event.event_type) == event_type and event.source_actor_id == actor_id:
			matching.append(event)
	return matching


func _last_event_from(session: ArenaCombatSession, event_type: String, actor_id: StringName) -> CombatEvent:
	var events := _events_for_source(session, event_type, actor_id)
	return null if events.is_empty() else events[-1]


func _count_goblin_events(session: ArenaCombatSession, event_type: String) -> int:
	var count := 0
	for event: CombatEvent in session.get_resolved_events():
		if String(event.event_type) == event_type and String(event.source_actor_id).begins_with("wave_1_common_goblin_"):
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


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s Expected %s, got %s." % [message, str(expected), str(actual)])


func _expect_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)
