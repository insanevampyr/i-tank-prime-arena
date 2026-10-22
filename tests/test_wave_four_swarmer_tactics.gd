class_name WaveFourSwarmerTacticsTests
extends RefCounted

const ArenaBattlefield = preload("res://scripts/combat/arena_battlefield.gd")
const ArenaCombatSession = preload("res://scripts/combat/arena_combat_session.gd")
const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
const TwoClientSyncHarness = preload("res://scripts/sync/two_client_sync_harness.gd")

const PLAYER_POSITION := Vector2i(20_000_000, 12_000_000)
const GARGOYLE_POSITION := Vector2i(34_000_000, 12_000_000)
const ONE_FOOT_SQUARED := 1_000_000_000_000

var _failures: Array[String] = []


func run() -> Array[String]:
	_failures.clear()
	_test_exact_spatial_contact_and_elevation_occupancy()
	_test_one_gargoyle_completes_dive_withdraw_and_second_attack()
	_test_four_gargoyle_stationary_swarm_and_fury()
	_test_four_gargoyles_intercept_moving_player()
	_test_injury_changes_staging_without_disabling_combat()
	_test_reset_partition_replay_and_two_client_convergence()
	return _failures


func _test_exact_spatial_contact_and_elevation_occupancy() -> void:
	var arena := ArenaBattlefield.create_task16_test_arena()
	var occupancy := {"player": Vector3i(20_000_000, 12_000_000, 0)}
	var legal_contact := arena.is_spatial_position_legal(
		&"gargoyle", Vector3i(20_800_000, 12_000_000, 600_000), occupancy
	)
	_expect_true(legal_contact.get("legal", false), "An exact 3-4-5 one-foot spatial contact must remain legal without floating-point boundary loss.")
	var same_plane_overlap := arena.is_spatial_position_legal(
		&"gargoyle", Vector3i(20_800_000, 12_000_000, 0), occupancy
	)
	_expect_equal(same_plane_overlap.get("reason"), "occupied_by_actor", "Same-plane actors inside the one-foot collision diameter must remain blocked.")

	var session := _make_active_session(7)
	var overhead_id := StringName(session.get_targetable_enemy_ids()[0])
	var overhead_state := session.get_actor_state(overhead_id)
	_expect_true(
		session.simulation.apply_authoritative_spatial_position(
			overhead_id, PLAYER_POSITION, 2_000_000, overhead_state.facing_millidegrees
		).get("success", false),
		"The authoritative fixture must place an airborne actor over the player."
	)
	var movement := session.request_player_movement(PLAYER_POSITION + Vector2i(500_000, 0), 6)
	_expect_true(
		movement.get("success", false) and int(movement.get("movement_cost_microfeet", 0)) > 0,
		"An airborne actor with legal vertical separation must not create a false ground-plane movement deadlock."
	)

	var alternate_lane_session := _make_active_session(7)
	var ids := alternate_lane_session.get_targetable_enemy_ids()
	var first_id := StringName(ids[0])
	var blocker_id := StringName(ids[1])
	var blocker := alternate_lane_session.get_actor_state(blocker_id)
	alternate_lane_session.simulation.apply_authoritative_spatial_position(
		blocker_id, PLAYER_POSITION + Vector2i(800_000, 0), 600_000, blocker.facing_millidegrees
	)
	var alternate_goal := alternate_lane_session._gargoyle_attack_goal(first_id, Fixture.PLAYER_ID)
	_expect_true(alternate_goal.get("success", false), "A blocked preferred strike endpoint must select another legal approach lane.")
	_expect_true(int(alternate_goal.get("lane_index", 0)) != 0, "Alternative positioning must not retry the occupied preferred lane.")


func _test_one_gargoyle_completes_dive_withdraw_and_second_attack() -> void:
	var seed := _find_seed_for_gargoyle_count(1)
	_expect_true(seed > 0, "A deterministic one-Gargoyle seed must exist in the bounded search.")
	if seed <= 0:
		return
	var session := _make_active_session(seed)
	var actor_id := StringName(session.get_targetable_enemy_ids()[0])
	session.advance_by(45_000_000)

	var declarations := _events(session, &"physical_attack_declared", actor_id)
	var action_ids := _unique_action_ids(declarations)
	var accuracy := _events(session, &"physical_attack_accuracy_resolved", actor_id)
	var final_failures := _events(session, &"physical_attack_final_legality_failed", actor_id)
	_expect_true(action_ids.size() >= 2, "One Gargoyle must complete a dive, withdraw, and return for a second attack Act.")
	_expect_true(accuracy.size() >= 6, "Two Gargoyle attack Acts must independently resolve claw, claw and bite through ACC.")
	_expect_equal(final_failures.size(), 0, "A stationary reachable player must not produce out-of-range dive failures.")
	if action_ids.is_empty():
		return

	var first_action_id: String = action_ids[0]
	var first_declarations: Array[CombatEvent] = []
	for event: CombatEvent in declarations:
		if String(event.payload.get("action_instance_id", "")) == first_action_id:
			first_declarations.append(event)
	_expect_equal(first_declarations.size(), 3, "A Mini Gargoyle ordinary Act must declare exactly claw, claw and bite.")
	var first_action := session.simulation.get_action(first_action_id)
	if first_action != null and not first_declarations.is_empty():
		_expect_equal(first_action.final_effect_due_at_us - first_declarations[0].timestamp_us, 5_000_000, "AT 1 dive attacks must retain the exact five-second action interval.")

	var first_attack := _attack_snapshot(session, String(first_declarations[0].payload.get("attack_instance_id", ""))) if not first_declarations.is_empty() else {}
	if not first_attack.is_empty():
		var declared_z := int(first_attack.get("declared_attacker_elevation_microfeet", 0))
		var final_z := int(first_attack.get("final_attacker_elevation_microfeet", 0))
		_expect_true(declared_z > 1_000_000, "The approach-capable attack must begin above natural-attack reach.")
		_expect_true(final_z < declared_z, "The Gargoyle must descend during the active five-second attack Act.")
		_expect_true(bool(first_attack.get("final_range_legal", false)), "The completed dive must pass true 3D final range validation.")
		_expect_equal(int(first_attack.get("final_distance_squared_microfeet", -1)), ONE_FOOT_SQUARED, "The chosen strike endpoint must be exactly one foot from the target without overlap.")

	var tactical := _events(session, &"tactical_action_selected", actor_id)
	_expect_true(_has_tactical_selection(tactical, "withdrawing"), "A completed strike must transition into legal upward withdrawal.")
	_expect_true(_has_tactical_reason(tactical, "staging_altitude_recovered"), "Withdrawal must return the Gargoyle to high-altitude staging before another dive.")
	_expect_true(_events(session, &"physical_defense_attempted", Fixture.PLAYER_ID).size() > 0, "Normal player defenses must remain active against legal Gargoyle strikes.")


func _test_four_gargoyle_stationary_swarm_and_fury() -> void:
	var session := _make_active_session(7)
	_expect_equal(session.get_targetable_enemy_ids().size(), 4, "Seed 7 must retain the four-Gargoyle stress fixture.")
	var started_us := Time.get_ticks_usec()
	session.advance_by(150_000_000)
	var processing_us := Time.get_ticks_usec() - started_us
	var metrics := _collect_metrics(session, processing_us)

	_expect_true(int(metrics["attack_acts_declared"]) >= 8, "The four-Gargoyle swarm must complete repeated legal dive opportunities.")
	_expect_true(int(metrics["attack_acts_completed"]) >= 8, "Declared Gargoyle attack Acts must reach authoritative completion.")
	_expect_true(int(metrics["acc_resolutions"]) >= 24, "Legal natural strikes must reach ACC rather than failing at range.")
	_expect_equal(int(metrics["out_of_range_rejections"]), 0, "A stationary reachable player must not generate final-range rejections.")
	_expect_true(int(metrics["damaging_hits"]) > 0, "The sustained stationary scenario must demonstrate actual authoritative damage.")
	_expect_true(int(metrics["withdrawals"]) >= 4, "Each swarm lane must demonstrate a post-strike withdrawal opportunity.")
	_expect_true(int(metrics["actors_with_second_attack"]) >= 2, "Multiple Gargoyles must return for a second attack rather than cycle altitude indefinitely.")
	_expect_true(int(metrics["failed_approaches"]) < 32, "Alternative lanes must avoid the former hundreds of repeated failed approaches.")
	_expect_true(int(metrics["congestion_events"]) < 16, "Staggered, lane-separated dives must avoid persistent actor congestion.")

	var lane_set := {}
	for event: CombatEvent in _events_of_type(session, &"tactical_action_selected"):
		if String(event.source_actor_id).begins_with("wave_4_") and String(event.payload.get("selected_action", "")) == "diving":
			lane_set[int(event.payload.get("lane_index", -1))] = true
	_expect_equal(lane_set.size(), 4, "Four Gargoyles must use four deterministic approach lanes before fallbacks.")

	var fury_attacks := 0
	var ordinary_followups := 0
	for attack: Dictionary in session.simulation.get_state_snapshot().get("attacks", []):
		if not String(attack.get("attacker_id", "")).begins_with("wave_4_") or String(attack.get("action_instance_id", "")).is_empty():
			continue
		var has_fury := (attack.get("consequence_damage_multipliers", []) as Array).any(
			func(multiplier: Dictionary) -> bool: return String(multiplier.get("kind", "")) == "fury"
		)
		if has_fury:
			fury_attacks += 1
		else:
			ordinary_followups += 1
	_expect_true(fury_attacks >= 3, "Fury must apply to the full claw/claw/bite sequence of an eligible Act.")
	_expect_true(ordinary_followups >= 3, "Spent Fury must not leak into later ordinary attack Acts.")

	var examples := _legal_dive_examples(session, 2)
	_expect_equal(examples.size(), 2, "The stress run must retain coordinate evidence for two legal completed dives.")
	print("METRIC: Task33B stationary seed=7 %s examples=%s" % [str(metrics), str(examples)])


func _test_four_gargoyles_intercept_moving_player() -> void:
	var session := _make_active_session(7)
	var direction := 1
	var successful_player_moves := 0
	var started_us := Time.get_ticks_usec()
	for unused in range(900):
		var player := session.get_actor_state(Fixture.PLAYER_ID)
		if player == null or (player.current_hpc != null and int(player.current_hpc) <= 0):
			break
		if player.position_microfeet.x >= 24_000_000:
			direction = -1
		elif player.position_microfeet.x <= 17_000_000:
			direction = 1
		var movement := session.request_player_movement(
			player.position_microfeet + Vector2i(direction * 150_000, 0),
			int(session._actor_definition_snapshot(Fixture.PLAYER_ID).get("combat_stats", {}).get("mr", 0))
		)
		if movement.get("success", false) and int(movement.get("movement_cost_microfeet", 0)) > 0:
			successful_player_moves += 1
		session.advance_by(100_000)
	var processing_us := Time.get_ticks_usec() - started_us
	var metrics := _collect_metrics(session, processing_us)
	_expect_true(successful_player_moves > 10, "The moving-player stress fixture must exercise authoritative ground movement.")
	_expect_true(int(metrics["attack_acts_declared"]) >= 4, "Gargoyles must continue pursuing and declaring attacks against moving prey.")
	_expect_true(int(metrics["acc_resolutions"]) > 0, "Lawful interception must deliver at least one moving-target attack to ACC.")
	_expect_true(int(metrics["actors_with_second_attack"]) > 0, "At least one Gargoyle must re-engage moving prey after withdrawal.")
	_expect_true(int(metrics["failed_approaches"]) < 80, "Moving-target replanning must not recreate the former repeated impossible-space loop.")
	print("METRIC: Task33B moving seed=7 successful_player_moves=%d %s" % [successful_player_moves, str(metrics)])


func _test_injury_changes_staging_without_disabling_combat() -> void:
	var seed := _find_seed_for_gargoyle_count(1)
	if seed <= 0:
		return
	var session := _make_active_session(seed)
	var actor_id := StringName(session.get_targetable_enemy_ids()[0])
	var actor := session.get_actor_state(actor_id)
	actor.current_hpc = 7
	var goal := session._gargoyle_staging_goal(actor_id, Fixture.PLAYER_ID)
	var target := session.get_actor_state(Fixture.PLAYER_ID)
	var planar_offset := Vector2i(goal.x, goal.y) - target.position_microfeet
	_expect_equal(planar_offset.length_squared(), 25_000_000_000_000, "An injured Gargoyle must use the approved cautious five-foot staging radius.")
	session.advance_by(45_000_000)
	_expect_true(_unique_action_ids(_events(session, &"physical_attack_declared", actor_id)).size() >= 2, "Cautious injured staging must not disable combat or cause indefinite refusal.")
	_expect_true(_has_tactical_reason(_events(session, &"tactical_action_selected", actor_id), "injured_cautious_withdrawal"), "Injury-driven caution must be explicit in authoritative tactical history.")


func _test_reset_partition_replay_and_two_client_convergence() -> void:
	var coarse := _make_active_session(7)
	var partitioned := _make_active_session(7)
	coarse.advance_by(20_000_000)
	for unused in range(200):
		partitioned.advance_by(100_000)
	_expect_equal(_event_signature(partitioned), _event_signature(coarse), "Gargoyle tactics must be invariant to caller frame partitioning.")
	_expect_equal(partitioned.get_state_snapshot(), coarse.get_state_snapshot(), "Frame partitioning must preserve the complete authoritative snapshot.")

	var replay := _make_active_session(7)
	replay.advance_by(20_000_000)
	_expect_equal(_event_signature(replay), _event_signature(coarse), "Identical seeds must replay the complete Gargoyle transcript.")
	_expect_equal(replay.get_state_snapshot(), coarse.get_state_snapshot(), "Identical seeds must reproduce tactical states, positions and combat state.")
	var before_reset_events := _event_signature(replay)
	var before_reset_snapshot := replay.get_state_snapshot()
	_expect_true(replay.reset_encounter(true).get("success", false), "Wave 4 RESET must rebuild the active encounter.")
	replay.advance_by(20_000_000)
	_expect_equal(_event_signature(replay), before_reset_events, "RESET must clear tactical state and reproduce the seeded authoritative history.")
	_expect_equal(replay.get_state_snapshot(), before_reset_snapshot, "RESET must reproduce the complete post-dive state without leaked reservations.")

	var harness := TwoClientSyncHarness.new(7)
	var authority := ArenaCombatSession.new(7, harness.authority.simulation, Fixture.ENCOUNTER_WAVE_FOUR_GARGOYLES)
	authority.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
	authority.set_opponent_behavior_enabled(true)
	_expect_true(authority.initialize_wave_four_gargoyles(PLAYER_POSITION, GARGOYLE_POSITION, true).get("success", false), "External Wave 4 authority must initialize.")
	authority.advance_by(20_000_000)
	var envelopes := harness.authority.publish_current_events()
	for envelope: CombatEventEnvelope in envelopes:
		harness.client_a.receive(envelope)
	for index in range(envelopes.size() - 1, -1, -1):
		harness.client_b.receive(envelopes[index])
	if not envelopes.is_empty():
		harness.client_b.receive(envelopes[0])
	_expect_true(harness.compare_clients().get("success", false), "Both simulated clients must converge after full dive combat with reversed and duplicate delivery.")
	_expect_equal(harness.client_a.get_state_digest(), harness.authority.get_state_digest(), "The authoritative and observed Wave 4 digests must match.")


func _make_active_session(seed: int) -> ArenaCombatSession:
	var session := ArenaCombatSession.new(seed, null, Fixture.ENCOUNTER_WAVE_FOUR_GARGOYLES)
	session.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
	session.set_opponent_behavior_enabled(true)
	_expect_true(session.initialize_wave_four_gargoyles(PLAYER_POSITION, GARGOYLE_POSITION, true).get("success", false), "Wave 4 fixture must initialize.")
	return session


func _find_seed_for_gargoyle_count(count: int) -> int:
	for seed in range(1, 128):
		var session := ArenaCombatSession.new(seed, null, Fixture.ENCOUNTER_WAVE_FOUR_GARGOYLES)
		session.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
		session.initialize_wave_four_gargoyles(PLAYER_POSITION, GARGOYLE_POSITION, false)
		if session.get_targetable_enemy_ids().size() == count:
			return seed
	return -1


func _collect_metrics(session: ArenaCombatSession, processing_us: int) -> Dictionary:
	var action_ids := {}
	var actions_by_actor := {}
	var completed := {}
	var acc_resolutions := 0
	var legitimate_misses := 0
	var defended_hits := 0
	var damaging_hits := 0
	var out_of_range := 0
	var withdrawals := 0
	var congestion := 0
	for event: CombatEvent in session.get_resolved_events():
		var source := String(event.source_actor_id)
		if event.event_type == &"physical_attack_declared" and source.begins_with("wave_4_"):
			var action_id := String(event.payload.get("action_instance_id", ""))
			if not action_id.is_empty():
				action_ids[action_id] = true
				if not actions_by_actor.has(source):
					actions_by_actor[source] = {}
				(actions_by_actor[source] as Dictionary)[action_id] = true
		elif event.event_type == &"action_completed" and action_ids.has(String(event.payload.get("action_instance_id", ""))):
			completed[String(event.payload.get("action_instance_id", ""))] = true
		elif event.event_type == &"physical_attack_accuracy_resolved" and source.begins_with("wave_4_"):
			acc_resolutions += 1
			if not bool(event.payload.get("accuracy_success", false)):
				legitimate_misses += 1
		elif event.event_type == &"physical_attack_final_legality_failed" and source.begins_with("wave_4_"):
			if String(event.payload.get("reason", "")) == "target_out_of_range_at_resolution":
				out_of_range += 1
		elif event.event_type == &"physical_damage_resolved" and source.begins_with("wave_4_"):
			damaging_hits += 1
		elif event.event_type == &"tactical_action_selected" and source.begins_with("wave_4_"):
			if String(event.payload.get("selected_action", "")) == "withdrawing":
				withdrawals += 1
			if String(event.payload.get("reason", "")) == "actor_congestion":
				congestion += 1
	var actors_with_second := 0
	for actor_actions: Variant in actions_by_actor.values():
		if (actor_actions as Dictionary).size() >= 2:
			actors_with_second += 1
	var failed_approaches := 0
	for value: Variant in session.get_state_snapshot().get("gargoyle_failed_approach_counts", {}).values():
		failed_approaches += int(value)
	for attack: Dictionary in session.simulation.get_state_snapshot().get("attacks", []):
		if String(attack.get("attacker_id", "")).begins_with("wave_4_") and String(attack.get("status", "")) == "defended":
			defended_hits += 1
	return {
		"simulated_us": session.simulation.clock.get_elapsed_us(),
		"processing_us": processing_us,
		"attack_acts_declared": action_ids.size(),
		"attack_acts_completed": completed.size(),
		"acc_resolutions": acc_resolutions,
		"legitimate_misses": legitimate_misses,
		"defended_hits": defended_hits,
		"damaging_hits": damaging_hits,
		"out_of_range_rejections": out_of_range,
		"withdrawals": withdrawals,
		"actors_with_second_attack": actors_with_second,
		"failed_approaches": failed_approaches,
		"congestion_events": congestion,
		"movement_events": _events_of_type(session, &"actor_position_changed").size(),
		"total_events": session.get_resolved_event_count(),
		"movement_deadlock": session.get_last_error() == "encounter_advance_iteration_limit",
	}


func _legal_dive_examples(session: ArenaCombatSession, maximum: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seen_actions := {}
	for event: CombatEvent in session.get_resolved_events():
		if event.event_type != &"physical_attack_accuracy_resolved" or not String(event.source_actor_id).begins_with("wave_4_"):
			continue
		var attack := _attack_snapshot(session, String(event.payload.get("attack_instance_id", "")))
		if attack.is_empty() or not bool(attack.get("final_range_legal", false)):
			continue
		var action_id := String(attack.get("action_instance_id", ""))
		if seen_actions.has(action_id):
			continue
		seen_actions[action_id] = true
		result.append({
			"event_id": event.event_id,
			"timestamp_us": event.timestamp_us,
			"actor_id": String(event.source_actor_id),
			"action_instance_id": action_id,
			"declared_xy": attack.get("declared_attacker_position_microfeet", []),
			"declared_z": attack.get("declared_attacker_elevation_microfeet", 0),
			"final_xy": attack.get("final_attacker_position_microfeet", []),
			"final_z": attack.get("final_attacker_elevation_microfeet", 0),
			"target_xy": attack.get("final_target_position_microfeet", []),
			"target_z": attack.get("final_target_elevation_microfeet", 0),
			"distance_squared": attack.get("final_distance_squared_microfeet", 0),
		})
		if result.size() >= maximum:
			break
	return result


func _unique_action_ids(events: Array[CombatEvent]) -> Array[String]:
	var seen := {}
	var result: Array[String] = []
	for event: CombatEvent in events:
		var action_id := String(event.payload.get("action_instance_id", ""))
		if action_id.is_empty() or seen.has(action_id):
			continue
		seen[action_id] = true
		result.append(action_id)
	return result


func _has_tactical_selection(events: Array[CombatEvent], selection: String) -> bool:
	return events.any(func(event: CombatEvent) -> bool: return String(event.payload.get("selected_action", "")) == selection)


func _has_tactical_reason(events: Array[CombatEvent], reason: String) -> bool:
	return events.any(func(event: CombatEvent) -> bool: return String(event.payload.get("reason", "")) == reason)


func _events(session: ArenaCombatSession, event_type: StringName, source_actor_id: StringName) -> Array[CombatEvent]:
	var result: Array[CombatEvent] = []
	for event: CombatEvent in session.get_resolved_events():
		if event.event_type == event_type and event.source_actor_id == source_actor_id:
			result.append(event)
	return result


func _events_of_type(session: ArenaCombatSession, event_type: StringName) -> Array[CombatEvent]:
	var result: Array[CombatEvent] = []
	for event: CombatEvent in session.get_resolved_events():
		if event.event_type == event_type:
			result.append(event)
	return result


func _attack_snapshot(session: ArenaCombatSession, attack_id: String) -> Dictionary:
	for attack: Dictionary in session.simulation.get_state_snapshot().get("attacks", []):
		if String(attack.get("attack_instance_id", "")) == attack_id:
			return attack
	return {}


func _event_signature(session: ArenaCombatSession) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event: CombatEvent in session.get_resolved_events():
		result.append(event.to_dictionary())
	return result


func _expect_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s Expected %s, got %s." % [message, str(expected), str(actual)])
