extends RefCounted

const Battlefield = preload("res://scripts/combat/arena_battlefield.gd")
const Session = preload("res://scripts/combat/arena_combat_session.gd")
const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
const PrimeMovement = preload("res://scripts/movement/prime_movement_model.gd")
const DeterministicRng = preload("res://scripts/combat/deterministic_rng.gd")
const PlayerInputIntent = preload("res://scripts/input/arena_player_input_intent.gd")

const PLAYER_START := Vector2i(35_000_000, 14_000_000)
const OPPONENT_START := Vector2i(25_000_000, 14_000_000)

var _failures: Array[String] = []


func run() -> Array[String]:
	_test_boundaries_obstacles_occupancy_and_los()
	_test_mr_conversion_and_collision()
	_test_authoritative_player_movement_restrictions()
	_test_keyboard_and_touch_share_movement_authority()
	_test_deterministic_path_and_opponent_approach()
	_test_opponent_approaches_during_attack_execution()
	_test_dodge_geometry_and_known_hazards()
	_test_replay_reset_and_two_client_convergence()
	return _failures


func _test_boundaries_obstacles_occupancy_and_los() -> void:
	var battlefield := Battlefield.create_task16_test_arena()
	var occupancy := {"player": Vector2i(20_000_000, 7_000_000)}
	_expect_true(battlefield.is_position_legal(&"opponent", Vector2i(25_000_000, 14_000_000), occupancy)["legal"], "An open in-bounds actor position must be legal.")
	_expect_equal(battlefield.is_position_legal(&"opponent", Vector2i(1_000_000, 14_000_000), occupancy)["reason"], "outside_battlefield_bounds", "Actor footprint must not cross the authored map boundary.")
	_expect_equal(battlefield.is_position_legal(&"opponent", Vector2i(30_000_000, 14_000_000), occupancy)["reason"], "blocked_by_obstacle", "Static obstacle occupancy must be authoritative.")
	_expect_equal(battlefield.is_position_legal(&"opponent", Vector2i(20_500_000, 7_000_000), occupancy)["reason"], "occupied_by_actor", "Actor footprints must not overlap.")
	var through_wall := battlefield.resolve_motion(&"opponent", Vector2i(25_000_000, 14_000_000), Vector2i(35_000_000, 14_000_000), occupancy)
	_expect_true(through_wall["blocked"] and int(through_wall["position_microfeet"].x) < 29_000_000, "A long displacement must not tunnel through an obstacle even when its endpoint is legal.")
	_expect_true(not battlefield.has_line_of_sight(Vector2i(25_000_000, 14_000_000), Vector2i(35_000_000, 14_000_000)), "The wall must block line of sight independently of movement-path reachability.")
	_expect_true(battlefield.has_line_of_sight(Vector2i(20_000_000, 7_000_000), Vector2i(23_000_000, 7_000_000)), "Open three-foot melee reach must preserve line of sight.")


func _test_mr_conversion_and_collision() -> void:
	var movement := PrimeMovement.new(12, 12, 10, 0, 0, 0, DeterministicRng.new(1))
	var displacement := movement.advance(5_000_000, Vector2.RIGHT)
	_expect_equal(roundi(displacement.x * 1_000_000.0), 12_000_000, "MR 12 must travel exactly 12 feet in one five-second round.")
	var battlefield := Battlefield.create_task16_test_arena()
	var occupancy := {"opponent": Vector2i(23_000_000, 7_000_000)}
	var walking := battlefield.resolve_motion(&"player", Vector2i(29_000_000, 7_000_000), Vector2i(29_000_000, 12_000_000), occupancy)
	var running := battlefield.resolve_motion(&"player", Vector2i(29_000_000, 7_000_000), Vector2i(29_000_000, 20_000_000), occupancy)
	_expect_true(walking["blocked"] and running["blocked"], "Walking and Running displacement must use the same obstacle collision boundary.")
	_expect_true(int(walking["position_microfeet"].y) <= 7_500_000 and int(running["position_microfeet"].y) <= 7_500_000, "Neither walking nor Running may clip through the wall.")


func _test_authoritative_player_movement_restrictions() -> void:
	var session := _make_session(1, Vector2i(20_000_000, 4_000_000), Vector2i(35_000_000, 4_000_000), false)
	var moved := session.request_player_movement(Vector2i(40_000_000, 4_000_000), 12)
	_expect_true(moved.get("success", false), "A legal player movement intent must enter the authoritative movement transaction.")
	_expect_true(int(moved["movement_cost_microfeet"]) <= 12_000_000, "One round must not spend more than the supplied effective MR.")
	_expect_true(session.get_actor_state(Fixture.PLAYER_ID).position_microfeet.x <= 32_000_000, "A large input displacement must be limited instead of teleporting.")
	var simultaneous := _make_session(1, Vector2i(20_000_000, 7_000_000), Vector2i(23_000_000, 7_000_000), false)
	var attack := simultaneous.request_player_attack("movement_concurrency")
	_expect_true(attack.get("success", false), "The fixture must begin a legal action for movement-concurrency coverage.")
	var during_action := simultaneous.request_player_movement(Vector2i(20_500_000, 7_000_000), 12)
	_expect_true(during_action.get("success", false), "A movement-compatible physical attack must not serialize legal movement behind the action.")
	var player_state := simultaneous.get_actor_state(Fixture.PLAYER_ID)
	player_state.critical_stagger_until_us = 500_000
	_expect_equal(simultaneous.request_player_movement(Vector2i(21_000_000, 7_000_000), 12)["reason"], "movement_blocked_by_critical_stagger", "Critical Stagger must stop voluntary battlefield movement.")
	player_state.critical_stagger_until_us = 0
	player_state.conditions.append("prone")
	var prone_crawl := simultaneous.request_player_movement(Vector2i(21_000_000, 7_000_000), 12)
	_expect_true(prone_crawl["success"], "The approved Task 17 prone crawl must use the same authoritative battlefield movement path.")
	_expect_true(int(prone_crawl["movement_cost_microfeet"]) <= 3_000_000, "Prone crawl must remain capped at 25% of the fixture's 12 MR walking allowance.")


func _test_keyboard_and_touch_share_movement_authority() -> void:
	var keyboard_direction := PlayerInputIntent.combine_movement(Vector2.RIGHT, Vector2.ZERO)
	var touch_direction := PlayerInputIntent.combine_movement(Vector2.ZERO, Vector2.RIGHT)
	_expect_equal(keyboard_direction, touch_direction, "Keyboard and touch directions must normalize through the same input-intent adapter.")
	var keyboard_session := _make_session(1, Vector2i(20_000_000, 4_000_000), Vector2i(35_000_000, 4_000_000), false)
	var touch_session := _make_session(1, Vector2i(20_000_000, 4_000_000), Vector2i(35_000_000, 4_000_000), false)
	var keyboard_destination := Vector2i(20_000_000, 4_000_000) + Vector2i(keyboard_direction * 1_000_000.0)
	var touch_destination := Vector2i(20_000_000, 4_000_000) + Vector2i(touch_direction * 1_000_000.0)
	keyboard_session.request_player_movement(keyboard_destination, 12)
	touch_session.request_player_movement(touch_destination, 12)
	_expect_equal(keyboard_session.get_state_snapshot(), touch_session.get_state_snapshot(), "Equivalent keyboard and touch movement must produce identical authoritative state.")


func _test_deterministic_path_and_opponent_approach() -> void:
	var battlefield := Battlefield.create_task16_test_arena()
	var occupancy := {"player": PLAYER_START, "opponent": OPPONENT_START}
	var first_path := battlefield.find_path_to_attack_position(&"opponent", OPPONENT_START, PLAYER_START, 3_000_000, occupancy)
	var second_path := battlefield.find_path_to_attack_position(&"opponent", OPPONENT_START, PLAYER_START, 3_000_000, occupancy)
	_expect_true(first_path.get("success", false), "A legal route around the authored wall must be found.")
	_expect_equal(first_path, second_path, "Equal path inputs must produce identical stable waypoints.")
	var blocked_field := Battlefield.new(
		Rect2i(0, 0, 10_000_000, 10_000_000),
		[{"id": "sealed_wall", "rect_microfeet": Rect2i(4_000_000, 0, 2_000_000, 10_000_000), "hazard_tier": 0}],
		500_000,
		true
	)
	var blocked_path := blocked_field.find_path_to_attack_position(&"opponent", Vector2i(2_000_000, 5_000_000), Vector2i(8_000_000, 5_000_000), 1_000_000, {"player": Vector2i(8_000_000, 5_000_000), "opponent": Vector2i(2_000_000, 5_000_000)})
	_expect_equal(blocked_path.get("reason"), "no_legal_path", "A fully sealed route must report a deterministic blocked-approach reason.")

	var seed_value := _find_opponent_opening_seed()
	_expect_true(seed_value > 0, "A deterministic fixture seed must permit the opponent's first legal attack after approach.")
	if seed_value <= 0:
		return
	var session := _make_session(seed_value, PLAYER_START, OPPONENT_START, true)
	var previous := session.get_actor_state(Fixture.OPPONENT_ID).position_microfeet
	session.advance_by(10_000_000)
	var current := session.get_actor_state(Fixture.OPPONENT_ID).position_microfeet
	_expect_true(current != previous, "The scripted opponent must spend MR to approach instead of remaining permanently blocked.")
	_expect_true(_has_event(session, "actor_position_changed", Fixture.OPPONENT_ID), "Authoritative approach positions must be event-recorded.")
	_expect_true(_has_event(session, "physical_attack_declared", Fixture.OPPONENT_ID), "The opponent must attack through the existing pipeline after reaching legal range.")


func _test_opponent_approaches_during_attack_execution() -> void:
	var player_position := Vector2i(20_000_000, 7_000_000)
	var opponent_position := Vector2i(26_000_000, 7_000_000)
	var seed_value := _find_opponent_opening_seed()
	var session := ArenaCombatSession.new(seed_value)
	session.configure_battlefield(Battlefield.new(
		Rect2i(2_000_000, 2_000_000, 44_000_000, 23_000_000),
		[],
		Battlefield.DEFAULT_ACTOR_RADIUS_MICROFEET,
		true
	))
	_expect_true(session.initialize(player_position, opponent_position).get("success", false), "The authoritative open approach-attack fixture must initialize.")
	session.set_opponent_behavior_enabled(true)
	var attack_id := session.get_active_opponent_attack_id()
	_expect_true(not attack_id.is_empty(), "The opponent must declare its ordinary attack while still six feet from the player.")
	_expect_equal(session.get_actor_state(Fixture.OPPONENT_ID).position_microfeet, opponent_position, "Declaration itself must not teleport the opponent into reach.")
	session.advance_by(100_000)
	_expect_true(session.get_actor_state(Fixture.OPPONENT_ID).position_microfeet != opponent_position, "The opponent must spend authoritative MR while its AT action is executing.")
	_expect_equal(session.simulation.get_attack(attack_id).status, CombatAttackInstance.STATUS_EXECUTING, "Approach movement must occur before the attack's final effect point.")
	session.advance_by(2_400_000)
	_expect_true(_has_event(session, "physical_attack_accuracy_resolved", Fixture.OPPONENT_ID), "An opponent that reaches three-foot Battle Axe reach before resolution must proceed to ACC.")


func _test_dodge_geometry_and_known_hazards() -> void:
	var battlefield := Battlefield.create_task16_test_arena()
	var facts := battlefield.build_dodge_candidate_facts(
		&"player",
		Vector2i(8_000_000, 19_000_000),
		Vector2i(8_000_000, 16_000_000),
		6,
		3_000_000,
		{"player": Vector2i(8_000_000, 19_000_000), "opponent": Vector2i(8_000_000, 16_000_000)}
	)
	var saw_safe := false
	var saw_known_hazard := false
	for fact: Dictionary in facts:
		_expect_true(int(fact["movement_cost_microfeet"]) > 0, "Unresolved Battle Axe ducking must not create an in-place candidate.")
		if int(fact["hazard_tier"]) == 0 and fact["path_valid"]:
			saw_safe = true
		if int(fact["hazard_tier"]) == 1 and fact["path_valid"]:
			saw_known_hazard = true
	_expect_true(saw_safe and saw_known_hazard, "Dodge geometry must expose both safe and explicitly authored hazard tiers to the existing safest-tier selector.")


func _test_replay_reset_and_two_client_convergence() -> void:
	var seed_value := _find_opponent_opening_seed()
	if seed_value <= 0:
		return
	var first := _make_session(seed_value, PLAYER_START, OPPONENT_START, true)
	var second := _make_session(seed_value, PLAYER_START, OPPONENT_START, true)
	first.advance_by(10_000_000)
	second.advance_by(10_000_000)
	_expect_equal(first.get_state_snapshot(), second.get_state_snapshot(), "Battlefield pathing and movement must replay to identical authoritative state.")
	_expect_equal(_serialize_events(first.get_resolved_events()), _serialize_events(second.get_resolved_events()), "Battlefield movement and attack event transcripts must replay identically.")
	var original_snapshot := first.get_state_snapshot()
	first.reset_encounter(true)
	first.advance_by(10_000_000)
	_expect_equal(first.get_state_snapshot(), original_snapshot, "Reset must restore the seed, path state, movement ledger and combat result without leaked movement events.")

	var harness := TwoClientSyncHarness.new(seed_value)
	var authority := ArenaCombatSession.new(seed_value, harness.authority.simulation)
	authority.configure_battlefield(Battlefield.create_task16_test_arena())
	authority.initialize(PLAYER_START, OPPONENT_START)
	authority.set_opponent_behavior_enabled(true)
	authority.advance_by(10_000_000)
	var envelopes := harness.authority.publish_current_events()
	for envelope: CombatEventEnvelope in envelopes:
		harness.client_a.receive(envelope)
	for index in range(envelopes.size() - 1, -1, -1):
		harness.client_b.receive(envelopes[index])
	if not envelopes.is_empty():
		harness.client_b.receive(envelopes[0])
	_expect_true(harness.compare_clients().get("success", false), "Two clients must converge after duplicate and out-of-order delivery of battlefield movement and combat events.")
	_expect_equal(harness.client_a.get_state_digest(), harness.authority.get_state_digest(), "The client and authoritative movement/combat digests must match.")


func _make_session(seed_value: int, player_position: Vector2i, opponent_position: Vector2i, behavior_enabled: bool) -> ArenaCombatSession:
	var session := ArenaCombatSession.new(seed_value)
	session.configure_battlefield(Battlefield.create_task16_test_arena())
	var initialized := session.initialize(player_position, opponent_position)
	_expect_true(initialized.get("success", false), "The authored Task 16 battlefield fixture must initialize legally.")
	session.set_opponent_behavior_enabled(behavior_enabled)
	return session


func _find_opponent_opening_seed() -> int:
	for seed_value in range(1, 500):
		var session := _make_session(seed_value, PLAYER_START, OPPONENT_START, false)
		if int(session.get_actor_state(Fixture.OPPONENT_ID).opening_order_rank) == 0:
			return seed_value
	return 0


func _has_event(session: ArenaCombatSession, event_type: String, actor_id: StringName) -> bool:
	for event: CombatEvent in session.get_resolved_events():
		if String(event.event_type) == event_type and event.source_actor_id == actor_id:
			return true
	return false


func _serialize_events(events: Array) -> Array:
	var serialized: Array = []
	for event: CombatEvent in events:
		serialized.append(event.to_dictionary())
	return serialized


func _expect_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s Expected %s, got %s." % [message, expected, actual])
