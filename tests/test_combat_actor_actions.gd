extends RefCounted

var _failures: Array[String] = []


func run() -> Array[String]:
	_test_actor_initialization_and_serialization()
	_test_at_execution_durations_and_fractional_precision()
	_test_single_and_multi_act_timing()
	_test_cross_round_and_sequential_actions()
	_test_simultaneous_actions_use_init()
	_test_simultaneous_actors_with_different_at()
	_test_interruption_and_dependencies()
	_test_movement_during_action()
	_test_deterministic_replay()
	_test_two_client_actor_state_sync()
	_test_invalid_and_duplicate_requests()
	return _failures


func _test_actor_initialization_and_serialization() -> void:
	var sparse := CombatActorDefinition.new(
		&"sparse",
		&"enemy",
		"Sparse Fixture",
		{"str": 5},
		{"at": 1, "init": 2},
		{},
		PackedStringArray(["fixture_weapon"]),
		{"can_block": true},
		{"combat_stats.at": "PRIME-V3 SPD lookup fixture"}
	)
	_expect_true(sparse.unresolved_fields.has("combat_stats.acc"), "Missing derived statistics must remain explicitly unresolved.")
	_expect_true(sparse.unresolved_fields.has("attributes.end"), "Missing Prime attributes must remain explicitly unresolved.")
	var simulation := CombatSimulation.new(100)
	var player_result := simulation.register_actor(_make_actor(&"player", &"player", 2, 8))
	var enemy_result := simulation.register_actor(_make_actor(&"enemy", &"enemy", 1, 5))
	_expect_true(player_result["success"] and enemy_result["success"], "Player and enemy actors must use the same core registration model.")
	var snapshot := simulation.get_state_snapshot()
	_expect_equal(snapshot["actors"].size(), 2, "Actor snapshots must serialize every authoritative actor.")
	_expect_equal(simulation.get_actor_state(&"player").current_hpc, 20, "Actor state must initialize HPC from explicit HPM data.")
	_expect_equal(simulation.get_actor_state(&"player").equipment_refs, PackedStringArray(["fixture_weapon"]), "Actor state must retain equipment references.")
	_expect_true(not simulation.get_actor_state(&"player").to_dictionary().has("available_acts"), "Actor state must not expose a stored-Act balance.")


func _test_at_execution_durations_and_fractional_precision() -> void:
	var expected_durations := {
		1: 5_000_000,
		2: 2_500_000,
		3: 1_666_667,
		4: 1_250_000,
		5: 1_000_000,
	}
	for at_value: int in expected_durations:
		var simulation := CombatSimulation.new(200 + at_value)
		var actor_id := StringName("at_%d" % at_value)
		simulation.register_actor(_make_actor(actor_id, &"player", at_value, 5))
		simulation.take_resolved_events()
		var result := simulation.start_action(actor_id, _make_action(StringName("at_%d_action" % at_value), 1), "at_%d_request" % at_value)
		var action: CombatActionInstance = simulation.get_action(result["action_instance_id"])
		var expected_us: int = expected_durations[at_value]
		simulation.advance_to(expected_us - 1)
		_expect_equal(action.status, CombatActionInstance.STATUS_IN_PROGRESS, "AT %d must occupy its full deterministic interval." % at_value)
		simulation.advance_to(expected_us)
		_expect_equal(action.completed_at_us, expected_us, "AT %d must complete one Act at ceil(5,000,000 / AT) microseconds." % at_value)

	var thirds := CombatSimulation.new(303)
	thirds.register_actor(_make_actor(&"thirds", &"player", 3, 5))
	thirds.take_resolved_events()
	var expected_boundaries := [1_666_667, 3_333_334, 5_000_000]
	for index in range(expected_boundaries.size()):
		var result := thirds.start_action(&"thirds", _make_action(&"third_action", 1), "third_request_%d" % index)
		thirds.advance_to(expected_boundaries[index])
		_expect_equal(thirds.get_action(result["action_instance_id"]).completed_at_us, expected_boundaries[index], "AT 3 sequential actions must use cumulative rational boundaries without drift.")
	_expect_equal(thirds.clock.get_elapsed_us(), 5_000_000, "Three continuous AT 3 actions must total exactly five seconds.")


func _test_single_and_multi_act_timing() -> void:
	var single := CombatSimulation.new(101)
	single.register_actor(_make_actor(&"single", &"player", 1, 4))
	single.take_resolved_events()
	var single_result := single.start_action(&"single", _make_action(&"single_act", 1), "single_request")
	var single_action: CombatActionInstance = single.get_action(single_result["action_instance_id"])
	_expect_equal(single_action.status, CombatActionInstance.STATUS_IN_PROGRESS, "A single-Act action must start before its due event is processed.")
	single.advance_to(4_999_999)
	_expect_equal(single_action.status, CombatActionInstance.STATUS_IN_PROGRESS, "An AT 1 action must not complete before its full five-second interval.")
	single.advance_to(5_000_000)
	_expect_equal(single_action.status, CombatActionInstance.STATUS_COMPLETED, "An AT 1 action must complete after its full interval.")

	var multi := CombatSimulation.new(102)
	multi.register_actor(_make_actor(&"multi", &"player", 2, 4))
	multi.take_resolved_events()
	var multi_result := multi.start_action(&"multi", _make_action(&"three_act", 3), "multi_request")
	var multi_action: CombatActionInstance = multi.get_action(multi_result["action_instance_id"])
	multi.advance_to(2_499_999)
	_expect_equal(multi_action.completed_acts, 0, "The first interval of a multi-Act action must not resolve early.")
	multi.advance_to(2_500_000)
	_expect_equal(multi_action.completed_acts, 1, "AT 2 must complete the first interval at 2.5 seconds.")
	multi.advance_to(4_999_999)
	_expect_equal(multi_action.status, CombatActionInstance.STATUS_IN_PROGRESS, "A three-Act action must remain pending before the five-second boundary.")
	multi.advance_to(5_000_000)
	_expect_equal(multi_action.completed_acts, 2, "The second interval must complete at the five-second boundary without finalizing a three-Act action.")
	multi.advance_to(7_500_000)
	_expect_equal(multi_action.status, CombatActionInstance.STATUS_COMPLETED, "A three-Act AT 2 action must complete after 7.5 seconds.")
	_expect_equal(multi_action.completed_at_us, 7_500_000, "Completion timestamps must use deterministic simulation time.")
	_expect_equal(multi.clock.get_round_index(), 1, "Exactly five seconds must remain the start of round one.")


func _test_cross_round_and_sequential_actions() -> void:
	var cross_round := CombatSimulation.new(304)
	cross_round.register_actor(_make_actor(&"cross_round", &"player", 1, 5))
	cross_round.advance_to(4_500_000)
	cross_round.take_resolved_events()
	var cross_result := cross_round.start_action(
		&"cross_round",
		_make_action(&"cross_round_action", 1, {"special_resource_fixture": 1}),
		"cross_round_request"
	)
	var cross_action: CombatActionInstance = cross_round.get_action(cross_result["action_instance_id"])
	cross_round.advance_to(9_499_999)
	_expect_equal(cross_action.status, CombatActionInstance.STATUS_IN_PROGRESS, "An action started with 0.5 seconds left in a round must continue across the boundary.")
	cross_round.advance_to(9_500_000)
	_expect_equal(cross_action.completed_at_us, 9_500_000, "Round boundaries must not reset or shorten an active action.")
	var cross_round_starts := _events_of_type(cross_round.get_resolved_events(), "action_started")
	_expect_equal(cross_round_starts.size(), 1, "Crossing a round boundary must not duplicate action-start records or commitments.")
	_expect_equal(cross_round_starts[0].resource_commitments, {"special_resource_fixture": 1}, "A future Special commitment must be recorded exactly once at action start.")

	var sequential := CombatSimulation.new(305)
	sequential.register_actor(_make_actor(&"sequential", &"player", 2, 5))
	sequential.take_resolved_events()
	var first := sequential.start_action(&"sequential", _make_action(&"sequential_action", 1), "sequential_1")
	sequential.advance_to(2_500_000)
	var second := sequential.start_action(&"sequential", _make_action(&"sequential_action", 1), "sequential_2")
	sequential.advance_to(5_000_000)
	_expect_equal(sequential.get_action(first["action_instance_id"]).completed_at_us, 2_500_000, "The first AT 2 action must take 2.5 seconds.")
	_expect_equal(sequential.get_action(second["action_instance_id"]).completed_at_us, 5_000_000, "The next ordinary action must begin immediately without a recharge delay.")


func _test_simultaneous_actions_use_init() -> void:
	var simulation := CombatSimulation.new(103)
	simulation.register_actor(_make_actor(&"low", &"enemy", 1, 3))
	simulation.register_actor(_make_actor(&"high", &"player", 1, 9))
	simulation.take_resolved_events()
	simulation.start_action(&"low", _make_action(&"low_action", 1), "low_request")
	simulation.start_action(&"high", _make_action(&"high_action", 1), "high_request")
	simulation.advance_to(5_000_000)
	var completed := _events_of_type(simulation.get_resolved_events(), "action_completed")
	_expect_equal(completed.size(), 2, "Both simultaneous legal actions must complete.")
	_expect_equal(String(completed[0].source_actor_id), "high", "Higher INIT must resolve the first simultaneous effect point.")
	_expect_equal(String(completed[1].source_actor_id), "low", "Lower INIT must follow without being silently cancelled.")


func _test_simultaneous_actors_with_different_at() -> void:
	var simulation := CombatSimulation.new(306)
	simulation.register_actor(_make_actor(&"at_two", &"player", 2, 4))
	simulation.register_actor(_make_actor(&"at_four", &"enemy", 4, 8))
	simulation.take_resolved_events()
	simulation.start_action(&"at_two", _make_action(&"at_two_action", 1), "at_two_request")
	simulation.start_action(&"at_four", _make_action(&"at_four_action", 2), "at_four_request")
	simulation.advance_to(2_500_000)
	var completed := _events_of_type(simulation.get_resolved_events(), "action_completed")
	_expect_equal(completed.size(), 2, "Different AT values may still produce the same deterministic effect timestamp.")
	_expect_equal(String(completed[0].source_actor_id), "at_four", "INIT must order equal effect timestamps without changing either action duration.")
	_expect_equal(String(completed[1].source_actor_id), "at_two", "The lower-INIT simultaneous effect must remain legal and complete second.")


func _test_interruption_and_dependencies() -> void:
	var interrupted_sim := CombatSimulation.new(104)
	interrupted_sim.register_actor(_make_actor(&"target", &"player", 1, 4))
	interrupted_sim.register_actor(_make_actor(&"interrupter", &"enemy", 1, 10))
	interrupted_sim.take_resolved_events()
	var target_result := interrupted_sim.start_action(&"target", _make_action(&"long_action", 2), "target_request")
	var target_action: CombatActionInstance = interrupted_sim.get_action(target_result["action_instance_id"])
	var interrupt_result := interrupted_sim.schedule_interruption(
		target_action.action_instance_id,
		10_000_000,
		&"interrupter",
		"fixture_interrupt"
	)
	_expect_true(interrupt_result["success"], "A valid future interruption must be scheduled.")
	interrupted_sim.advance_to(10_000_000)
	_expect_equal(target_action.status, CombatActionInstance.STATUS_INTERRUPTED, "A higher-INIT interruption at the same timestamp must resolve before completion.")
	_expect_equal(target_action.completed_acts, 1, "Interrupted multi-Act actions must not spend an unperformed future Act.")

	var completed_sim := CombatSimulation.new(110)
	completed_sim.register_actor(_make_actor(&"completed_target", &"player", 1, 10))
	completed_sim.register_actor(_make_actor(&"late_interrupter", &"enemy", 1, 4))
	completed_sim.take_resolved_events()
	var completed_result := completed_sim.start_action(&"completed_target", _make_action(&"completed_action", 1), "completed_request")
	var completed_action: CombatActionInstance = completed_sim.get_action(completed_result["action_instance_id"])
	completed_sim.schedule_interruption(completed_action.action_instance_id, 5_000_000, &"late_interrupter", "too_late")
	completed_sim.advance_to(5_000_000)
	_expect_equal(completed_action.status, CombatActionInstance.STATUS_COMPLETED, "A lower-INIT interruption at the effect timestamp must not retroactively cancel a completed action.")
	_expect_equal(_events_of_type(completed_sim.get_resolved_events(), "action_interruption_ignored").size(), 1, "A post-completion interruption must be recorded as ignored.")

	var dependency_sim := CombatSimulation.new(105)
	dependency_sim.register_actor(_make_actor(&"dependency", &"enemy", 1, 2))
	dependency_sim.register_actor(_make_actor(&"dependent", &"player", 1, 9))
	dependency_sim.take_resolved_events()
	var dependency_result := dependency_sim.start_action(&"dependency", _make_action(&"dependency_action", 1), "dependency_request")
	var dependent_result := dependency_sim.start_action(
		&"dependent",
		_make_action(&"dependent_action", 1),
		"dependent_request",
		PackedStringArray([dependency_result["action_instance_id"]])
	)
	dependency_sim.advance_to(5_000_000)
	var completions := _events_of_type(dependency_sim.get_resolved_events(), "action_completed")
	_expect_equal(completions.size(), 2, "A dependent action must finalize after its dependency becomes terminal.")
	_expect_equal(String(completions[0].source_actor_id), "dependency", "An unresolved dependency must hold back a higher-INIT dependent finalization.")
	_expect_equal(String(completions[1].source_actor_id), "dependent", "The dependent action must finalize deterministically after dependency resolution.")
	_expect_equal(dependency_sim.get_action(dependent_result["action_instance_id"]).status, CombatActionInstance.STATUS_COMPLETED, "Dependency release must leave the dependent action completed.")


func _test_movement_during_action() -> void:
	var simulation := CombatSimulation.new(106)
	simulation.register_actor(_make_actor(&"mover", &"player", 1, 6))
	simulation.take_resolved_events()
	var result := simulation.start_action(&"mover", _make_action(&"moving_action", 2), "moving_request")
	simulation.advance_to(1_000_000)
	var move_result := simulation.apply_authoritative_position(&"mover", Vector2i(1_500_000, -250_000), 90_000)
	_expect_true(move_result["success"], "An action that permits movement must not block authoritative position updates.")
	_expect_equal(simulation.get_actor_state(&"mover").position_microfeet, Vector2i(1_500_000, -250_000), "Movement must update canonical integer position.")
	_expect_equal(simulation.get_action(result["action_instance_id"]).status, CombatActionInstance.STATUS_IN_PROGRESS, "Legal movement must not interrupt an active action.")


func _test_deterministic_replay() -> void:
	var first := _build_replay_fixture(107)
	var second := _build_replay_fixture(107)
	_expect_equal(first.get_state_snapshot(), second.get_state_snapshot(), "Equal actor/action inputs must reproduce the same authoritative state snapshot.")
	_expect_equal(_serialize_events(first.get_resolved_events()), _serialize_events(second.get_resolved_events()), "Equal actor/action inputs must reproduce the same lifecycle records.")


func _test_two_client_actor_state_sync() -> void:
	var harness := TwoClientSyncHarness.new(108)
	harness.authority.simulation.register_actor(_make_actor(&"synced", &"player", 1, 7))
	harness.authority.simulation.start_action(&"synced", _make_action(&"sync_action", 1), "sync_request")
	var envelopes := harness.authority.publish_due_events(5_000_000)
	for envelope: CombatEventEnvelope in envelopes:
		harness.client_a.receive(envelope)
	for index in range(envelopes.size() - 1, -1, -1):
		harness.client_b.receive(envelopes[index])
	var report := harness.compare_clients()
	_expect_true(report["success"], "Two out-of-order observers must converge on the authoritative actor/action snapshot.")
	_expect_equal(harness.client_a.get_state_digest(), harness.authority.get_state_digest(), "A complete client must match the authority's transcript plus state digest.")
	_expect_equal(harness.client_b.get_state_snapshot(), harness.authority.simulation.get_state_snapshot(), "Both clients must observe the authoritative completed action state.")


func _test_invalid_and_duplicate_requests() -> void:
	var simulation := CombatSimulation.new(109)
	simulation.register_actor(_make_actor(&"valid", &"player", 1, 5))
	simulation.take_resolved_events()
	var before_invalid := SyncStateDigest.compute(simulation.get_state_snapshot())
	var invalid := simulation.start_action(&"missing", _make_action(&"invalid_action", 1), "invalid_request")
	_expect_true(not invalid["success"], "Unknown actors must be rejected without mutation.")
	_expect_equal(SyncStateDigest.compute(simulation.get_state_snapshot()), before_invalid, "Invalid requests must not partially mutate authoritative state.")

	var accepted := simulation.start_action(&"valid", _make_action(&"valid_action", 2), "duplicate_request")
	_expect_true(accepted["success"], "The first stable request identifier must be accepted when legal.")
	var after_accepted := SyncStateDigest.compute(simulation.get_state_snapshot())
	var duplicate := simulation.start_action(&"valid", _make_action(&"valid_action", 2), "duplicate_request")
	_expect_equal(duplicate["reason"], "duplicate_request", "Duplicate request identifiers must be rejected explicitly.")
	_expect_equal(SyncStateDigest.compute(simulation.get_state_snapshot()), after_accepted, "Duplicate delivery must be idempotent and must not schedule another effect.")


func _build_replay_fixture(seed_value: int) -> CombatSimulation:
	var simulation := CombatSimulation.new(seed_value)
	simulation.register_actor(_make_actor(&"alpha", &"player", 2, 7))
	simulation.register_actor(_make_actor(&"beta", &"enemy", 1, 4))
	simulation.start_action(&"alpha", _make_action(&"replay_multi", 2), "replay_request")
	simulation.advance_to(2_500_000)
	simulation.apply_authoritative_position(&"alpha", Vector2i(2_000_000, 0), 0)
	return simulation


func _make_actor(actor_id: StringName, actor_kind: StringName, at_value: int, init_value: int) -> CombatActorDefinition:
	return CombatActorDefinition.new(
		actor_id,
		actor_kind,
		"Fixture %s" % String(actor_id),
		{
			"str": 8, "end": 8, "spd": 8, "dex": 8, "wis": 8,
			"int": 8, "wit": 8, "man": 8, "luk": 8, "app": 8,
		},
		{
			"hpm": 20, "acc": 10, "at": at_value, "init": init_value, "mr": 10,
			"nal": 1, "dt": 4, "dp": 4, "physical_soak": 5,
		},
		{"mana": 12},
		PackedStringArray(["fixture_weapon"]),
		{"dodge_touch": true, "dodge_projectile": true, "block": true, "physical_soak": true},
		{"combat_stats.at": "PRIME-V3 SPD lookup fixture"},
		PackedStringArray()
	)


func _make_action(action_id: StringName, required_acts: int, resource_commitments: Dictionary = {}) -> CombatActionDefinition:
	return CombatActionDefinition.new(
		action_id,
		required_acts,
		true,
		true,
		resource_commitments,
		{"future_reaction_slots": [], "future_nac_chain": {}},
		PackedStringArray(["ARENA-COMBAT section 2"])
	)


func _events_of_type(events: Array, event_type: String) -> Array:
	var matches: Array = []
	for event: CombatEvent in events:
		if String(event.event_type) == event_type:
			matches.append(event)
	return matches


func _serialize_events(events: Array) -> Array:
	var serialized: Array = []
	for event: CombatEvent in events:
		serialized.append(event.to_dictionary())
	return serialized


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s Expected %s, got %s." % [message, str(expected), str(actual)])


func _expect_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)
