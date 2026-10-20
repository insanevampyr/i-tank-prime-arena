class_name GoblinWallNavigationTests
extends RefCounted

const ArenaBattlefield = preload("res://scripts/combat/arena_battlefield.gd")
const ArenaCombatSession = preload("res://scripts/combat/arena_combat_session.gd")
const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
const TwoClientSyncHarness = preload("res://scripts/sync/two_client_sync_harness.gd")

const CORNER_PLAYER_START := Vector2i(29_200_000, 7_400_000)
const CORNER_PLAYER_AFTER := Vector2i(28_400_000, 7_600_000)
const GOBLIN_START := Vector2i(38_000_000, 12_000_000)
const STEP_US := 100_000

var _failures: Array[String] = []


func run() -> Array[String]:
	_failures.clear()
	_test_stationary_target_routes_around_wall_and_attacks()
	_test_moving_target_stays_on_legal_wall_route()
	_test_subfoot_corner_transition_rebuilds_invalid_route()
	_test_multiple_goblins_share_wall_route_legally()
	_test_unreachable_route_is_cached_and_reconsidered()
	_test_wall_pursuit_replay_and_client_convergence()
	return _failures


func _test_stationary_target_routes_around_wall_and_attacks() -> void:
	var seed_value := _find_seed_for_count(2)
	var session := _wave_session(seed_value, Vector2i(20_000_000, 12_000_000), GOBLIN_START)
	var goblin_id := String(session.get_targetable_enemy_ids()[0])
	var previous_position: Vector2i = session.get_actor_state(StringName(goblin_id)).position_microfeet
	for _step in range(350):
		session.advance_by(STEP_US)
		var current_position: Vector2i = session.get_actor_state(StringName(goblin_id)).position_microfeet
		_expect_static_segment_clear(session, StringName(goblin_id), previous_position, current_position)
		previous_position = current_position
	var declarations := _events_for_source(session, "physical_attack_declared", StringName(goblin_id))
	print("METRIC: Task31G stationary-wall final_position=%s distance=%d rebuilds=%d static_collisions=%d declarations=%d" % [
		str(previous_position),
		_distance(previous_position, session.get_actor_state(Fixture.PLAYER_ID).position_microfeet),
		int(session.get_goblin_path_rebuild_counts_for_testing().get(goblin_id, 0)),
		int(session.get_goblin_static_collision_counts_for_testing().get(goblin_id, 0)),
		declarations.size(),
	])
	_expect_true(declarations.size() >= 2, "A Goblin must route around the center wall and declare both legal fist strikes.")
	if declarations.size() >= 2:
		_expect_equal(declarations[0].payload.get("action_instance_id"), declarations[1].payload.get("action_instance_id"), "Both fist strikes must remain one AT-1 Act after wall pursuit.")


func _test_moving_target_stays_on_legal_wall_route() -> void:
	var seed_value := _find_seed_for_count(2)
	var session := _wave_session(seed_value, Vector2i(20_000_000, 12_000_000), GOBLIN_START)
	var goblin_id := String(session.get_targetable_enemy_ids()[0])
	var initial_distance := _distance(session.get_actor_state(StringName(goblin_id)).position_microfeet, Vector2i(20_000_000, 12_000_000))
	var previous_position: Vector2i = session.get_actor_state(StringName(goblin_id)).position_microfeet
	for step in range(120):
		var player := session.get_actor_state(Fixture.PLAYER_ID)
		var vertical_step := Vector2i(0, 25_000 if step < 60 else -25_000)
		_expect_true(session.request_player_movement(player.position_microfeet + vertical_step, 11).get("success", false), "The moving wall-target path must remain legal.")
		session.advance_by(STEP_US)
		var current_position: Vector2i = session.get_actor_state(StringName(goblin_id)).position_microfeet
		_expect_static_segment_clear(session, StringName(goblin_id), previous_position, current_position)
		previous_position = current_position
	var final_player: Vector2i = session.get_actor_state(Fixture.PLAYER_ID).position_microfeet
	_expect_true(_distance(previous_position, final_player) < initial_distance, "A Goblin must make net progress toward a continuously moving target behind the wall.")


func _test_subfoot_corner_transition_rebuilds_invalid_route() -> void:
	var seed_value := _find_seed_for_count(2)
	var session := _wave_session(seed_value, CORNER_PLAYER_START, GOBLIN_START)
	var goblin_id := String(session.get_targetable_enemy_ids()[0])
	var rebuilds_before := int(session.get_goblin_path_rebuild_counts_for_testing().get(goblin_id, 0))
	_expect_true(rebuilds_before > 0, "The corner fixture must begin with a cached Goblin approach route.")
	var move := session.request_player_movement(CORNER_PLAYER_AFTER, 11)
	_expect_true(move.get("success", false), "The player must legally cross the wall corner by less than one foot.")
	var rebuilds_after := rebuilds_before
	var previous_position: Vector2i = session.get_actor_state(StringName(goblin_id)).position_microfeet
	for _step in range(160):
		session.advance_by(STEP_US)
		var current_position: Vector2i = session.get_actor_state(StringName(goblin_id)).position_microfeet
		_expect_static_segment_clear(session, StringName(goblin_id), previous_position, current_position)
		previous_position = current_position
		rebuilds_after = int(session.get_goblin_path_rebuild_counts_for_testing().get(goblin_id, 0))
		if rebuilds_after > rebuilds_before:
			break
	_expect_equal(rebuilds_after, rebuilds_before + 1, "An illegal sub-foot endpoint retarget must rebuild before the obsolete route can persistently stall pursuit.")


func _test_multiple_goblins_share_wall_route_legally() -> void:
	var seed_value := _find_seed_for_count(4)
	var session := _wave_session(seed_value, Vector2i(20_000_000, 12_000_000), GOBLIN_START)
	var ids: Array = session.get_targetable_enemy_ids()
	var previous_positions := {}
	var previous_steps := {}
	var reversals := {}
	for actor_id: String in ids:
		previous_positions[actor_id] = session.get_actor_state(StringName(actor_id)).position_microfeet
		previous_steps[actor_id] = Vector2i.ZERO
		reversals[actor_id] = 0
	for _step in range(180):
		session.advance_by(STEP_US)
		var occupancy := {}
		for actor_id: String in ids:
			occupancy[actor_id] = session.get_actor_state(StringName(actor_id)).position_microfeet
		for actor_id: String in ids:
			var current_position: Vector2i = occupancy[actor_id]
			_expect_static_segment_clear(session, StringName(actor_id), previous_positions[actor_id], current_position)
			_expect_true(session.get_battlefield().is_position_legal(StringName(actor_id), current_position, occupancy).get("legal", false), "%s must not overlap a wall, boundary, or another Goblin." % actor_id)
			var movement_step: Vector2i = current_position - (previous_positions[actor_id] as Vector2i)
			var prior_step: Vector2i = previous_steps[actor_id]
			if movement_step != Vector2i.ZERO and prior_step != Vector2i.ZERO and Vector2(movement_step).dot(Vector2(prior_step)) < 0:
				reversals[actor_id] = int(reversals[actor_id]) + 1
			if movement_step != Vector2i.ZERO:
				previous_steps[actor_id] = movement_step
			previous_positions[actor_id] = current_position
	var rebuilds := session.get_goblin_path_rebuild_counts_for_testing()
	var static_collisions := session.get_goblin_static_collision_counts_for_testing()
	var movement_events := _count_goblin_events(session, "actor_position_changed")
	for actor_id: String in ids:
		_expect_true(int(reversals[actor_id]) <= 12, "%s must not persistently oscillate while sharing the wall route." % actor_id)
		_expect_true(int(rebuilds.get(actor_id, 0)) <= 12, "%s must not repeat excessive full route searches while sharing the wall route." % actor_id)
	_expect_equal(_sum_dictionary_values(static_collisions), 0, "Direct wall-clear routes must not repeatedly drive Goblins into static obstacles.")
	_expect_true(movement_events > 0, "Wall navigation must preserve authoritative position events.")
	print("METRIC: Task31G four-Goblin wall rebuilds=%s reversals=%s static_collisions=%s movement_events=%d" % [
		str(rebuilds), str(reversals), str(static_collisions), movement_events,
	])


func _test_unreachable_route_is_cached_and_reconsidered() -> void:
	var battlefield := ArenaBattlefield.new(
		Rect2i(2_000_000, 2_000_000, 44_000_000, 23_000_000),
		[{"id": "sealed_wall", "rect_microfeet": Rect2i(29_000_000, 2_000_000, 2_000_000, 23_000_000)}],
		ArenaBattlefield.DEFAULT_ACTOR_RADIUS_MICROFEET,
		true
	)
	var seed_value := _find_seed_for_count(2)
	var session := ArenaCombatSession.new(seed_value, null, Fixture.ENCOUNTER_WAVE_ONE_GOBLINS)
	session.configure_battlefield(battlefield)
	session.set_opponent_behavior_enabled(true)
	var result := session.initialize_wave_one_goblins(Vector2i(20_000_000, 12_000_000), GOBLIN_START, true)
	_expect_true(result.get("success", false), "The sealed-route fixture must initialize.")
	for _step in range(20):
		session.advance_by(STEP_US)
	var goblin_id := String(session.get_targetable_enemy_ids()[0])
	var rebuilds := int(session.get_goblin_path_rebuild_counts_for_testing().get(goblin_id, 0))
	var cache_hits := int(session.get_goblin_failed_path_cache_hits_for_testing().get(goblin_id, 0))
	_expect_equal(rebuilds, 1, "An unchanged sealed route must perform exactly one full path search.")
	_expect_true(cache_hits > 0, "Subsequent unchanged sealed-route checks must use the deterministic failure cache.")
	_expect_true(session.simulation.apply_authoritative_position(Fixture.PLAYER_ID, Vector2i(35_000_000, 12_000_000), 0).get("success", false), "The blocked-condition fixture must move the player to the Goblin side authoritatively.")
	session.advance_by(STEP_US)
	rebuilds = int(session.get_goblin_path_rebuild_counts_for_testing().get(goblin_id, 0))
	_expect_equal(rebuilds, 2, "A changed target position must invalidate the failed-route cache and permit one new search.")
	print("METRIC: Task31G sealed-route full_rebuilds_before_change=1 cache_hits=%d rebuilds_after_change=%d" % [cache_hits, rebuilds])


func _test_wall_pursuit_replay_and_client_convergence() -> void:
	var seed_value := _find_seed_for_count(2)
	var sessions: Array[ArenaCombatSession] = []
	for _index in range(2):
		var session := _wave_session(seed_value, Vector2i(20_000_000, 12_000_000), GOBLIN_START)
		for _step in range(100):
			session.advance_by(STEP_US)
		sessions.append(session)
	_expect_equal(_event_signature(sessions[0]), _event_signature(sessions[1]), "Same-seed wall pursuit must reproduce complete authoritative event history.")
	_expect_equal(sessions[0].get_goblin_path_rebuild_counts_for_testing(), sessions[1].get_goblin_path_rebuild_counts_for_testing(), "Wall-route rebuild counts must be deterministic.")

	var harness := TwoClientSyncHarness.new(seed_value)
	var authority_session := ArenaCombatSession.new(seed_value, harness.authority.simulation, Fixture.ENCOUNTER_WAVE_ONE_GOBLINS)
	authority_session.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
	authority_session.set_opponent_behavior_enabled(true)
	_expect_true(authority_session.initialize_wave_one_goblins(Vector2i(20_000_000, 12_000_000), GOBLIN_START, true).get("success", false), "The wall synchronization fixture must initialize.")
	for _step in range(100):
		authority_session.advance_by(STEP_US)
	var envelopes := harness.authority.publish_current_events()
	for envelope: CombatEventEnvelope in envelopes:
		harness.client_a.receive(envelope)
	for index in range(envelopes.size() - 1, -1, -1):
		harness.client_b.receive(envelopes[index])
	_expect_true(harness.compare_clients().get("success", false), "Wall-pursuit events must converge after out-of-order simulated delivery.")
	_expect_equal(harness.authority.get_state_digest(), harness.client_a.get_state_digest(), "Wall-pursuit authority and client digests must match.")


func _find_seed_for_count(expected_count: int) -> int:
	for seed_value in range(1, 256):
		var session := ArenaCombatSession.new(seed_value, null, Fixture.ENCOUNTER_WAVE_ONE_GOBLINS)
		session.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
		if not session.initialize_wave_one_goblins(CORNER_PLAYER_START, GOBLIN_START, false).get("success", false):
			continue
		if session.get_targetable_enemy_ids().size() == expected_count:
			return seed_value
	_failures.append("No deterministic seed produced %d Goblin(s)." % expected_count)
	return 1


func _wave_session(seed_value: int, player_position: Vector2i, goblin_position: Vector2i) -> ArenaCombatSession:
	var session := ArenaCombatSession.new(seed_value, null, Fixture.ENCOUNTER_WAVE_ONE_GOBLINS)
	session.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
	session.set_opponent_behavior_enabled(true)
	var result := session.initialize_wave_one_goblins(player_position, goblin_position, true)
	_expect_true(result.get("success", false), "The wall-navigation fixture must initialize.")
	return session


func _expect_static_segment_clear(session: ArenaCombatSession, actor_id: StringName, start: Vector2i, finish: Vector2i) -> void:
	_expect_true(
		session.get_battlefield().is_direct_path_clear(actor_id, start, finish, {String(actor_id): finish}),
		"%s must never traverse a solid obstacle between authoritative positions." % String(actor_id)
	)


func _events_for_source(session: ArenaCombatSession, event_type: String, actor_id: StringName) -> Array[CombatEvent]:
	var matching: Array[CombatEvent] = []
	for event: CombatEvent in session.get_resolved_events():
		if String(event.event_type) == event_type and event.source_actor_id == actor_id:
			matching.append(event)
	return matching


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


func _sum_dictionary_values(values: Dictionary) -> int:
	var total := 0
	for value: Variant in values.values():
		total += int(value)
	return total


func _distance(left: Vector2i, right: Vector2i) -> int:
	return roundi(Vector2(left - right).length())


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s Expected %s, got %s." % [message, str(expected), str(actual)])


func _expect_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)
