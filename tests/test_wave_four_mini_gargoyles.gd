class_name WaveFourMiniGargoyleTests
extends RefCounted

const ArenaBattlefield = preload("res://scripts/combat/arena_battlefield.gd")
const ArenaCombatController = preload("res://scripts/ui/arena_combat_controller.gd")
const ArenaCombatSession = preload("res://scripts/combat/arena_combat_session.gd")
const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
const GargoyleFixture = preload("res://scripts/creatures/mini_gargoyle_swarmer_fixture.gd")
const HitLocations = preload("res://scripts/combat/combat_hit_location_catalog.gd")
const TwoClientSyncHarness = preload("res://scripts/sync/two_client_sync_harness.gd")

const PLAYER_POSITION := Vector2i(20_000_000, 12_000_000)
const GARGOYLE_POSITION := Vector2i(34_000_000, 12_000_000)

var _failures: Array[String] = []


func run() -> Array[String]:
	_failures.clear()
	_test_source_definition_and_natural_sequence()
	_test_seeded_d4_counts_and_independent_state()
	_test_spatial_geometry_and_euclidean_movement()
	_test_takeoff_and_landing_use_mr_not_acts()
	_test_fury_applies_to_one_three_strike_act()
	_test_autonomous_wall_overflight_and_victory()
	_test_four_gargoyle_performance_and_partition_determinism()
	_test_wave_four_replay_sync_and_presentation()
	return _failures


func _test_source_definition_and_natural_sequence() -> void:
	var actor := GargoyleFixture.make_actor(&"source_gargoyle", "Source Mini Gargoyle")
	var attack := GargoyleFixture.make_attack_definition(HitLocations.get_same_size_attack_profile())
	_expect_true(actor != null and attack != null, "Mini Gargoyle source-backed actor and natural attacks must instantiate.")
	if actor == null or attack == null:
		return
	_expect_equal(actor.size_category, HitLocations.SIZE_SMALL, "The owner-approved Mini Gargoyle size is Small.")
	for stat_and_value in [
		["hpm", 15], ["mr", 16], ["at", 1], ["acc", 13], ["init", 8], ["nal", 2],
	]:
		_expect_equal(actor.get_combat_stat(stat_and_value[0]), stat_and_value[1], "Mini Gargoyle %s must match its verified source." % stat_and_value[0])
	_expect_equal(actor.get_ability_daily_maximum(GargoyleFixture.FURY_ABILITY_ID), 1, "Fury must have exactly one daily use.")
	_expect_equal(attack.strikes_per_act, 3, "One AT-1 Act must contain claw, claw and bite.")
	_expect_equal(attack.strike_profiles.size(), 3, "Every natural strike needs its own deterministic profile.")
	_expect_equal(attack.strike_profiles[0].get("label"), "claw_1", "The first strike must be the first claw.")
	_expect_equal(attack.strike_profiles[1].get("label"), "claw_2", "The second strike must be the second claw.")
	_expect_equal(attack.strike_profiles[2].get("label"), "bite", "The third strike must be the bite.")
	_expect_equal(attack.strike_profiles[2].get("die_sides"), 8, "The bite must roll d8 damage independently of the d6 claws.")


func _test_seeded_d4_counts_and_independent_state() -> void:
	var observed := {}
	for seed in range(1, 256):
		var session := _ready_session(seed, false, false)
		var roster: Array = session.get_arena_wave_state().get("resolved_roster", [])
		var count := session.get_targetable_enemy_ids().size()
		observed[count] = true
		_expect_true(count >= 1 and count <= 4, "Wave 4 must resolve one through four Gargoyles.")
		if not roster.is_empty():
			_expect_equal(roster[0].get("dice_results", []).size(), 1, "Wave 4 quantity must preserve its one authoritative d4 draw.")
			_expect_equal(roster[0].get("resolved_count"), count, "The spawned actor count must match the recorded d4 result.")
		for actor_id: String in session.get_targetable_enemy_ids():
			var state := session.get_actor_state(StringName(actor_id))
			_expect_true(state != null and state.current_hpc == 15, "Every Gargoyle must own independent 15-HPC state.")
		if observed.size() == 4:
			break
	_expect_equal(observed.size(), 4, "The deterministic seed sample must cover all four legal d4 counts.")


func _test_spatial_geometry_and_euclidean_movement() -> void:
	var battlefield := ArenaBattlefield.new(Rect2i(0, 0, 30_000_000, 30_000_000), [], 500_000, true, [], [], 10_000_000)
	var diagonal := battlefield.resolve_spatial_motion(
		&"flyer", Vector3i(5_000_000, 5_000_000, 0), Vector3i(8_000_000, 5_000_000, 4_000_000), {}
	)
	_expect_true(diagonal.get("success", false), "Legal 3D flight movement must resolve.")
	_expect_equal(diagonal.get("movement_cost_microfeet"), 5_000_000, "A simultaneous 3-4 displacement must cost exactly five feet of MR.")
	var arena := ArenaBattlefield.create_task16_test_arena()
	var grounded := arena.resolve_spatial_motion(&"flyer", Vector3i(28_000_000, 12_000_000, 0), Vector3i(32_000_000, 12_000_000, 0), {})
	_expect_true(grounded.get("position_microfeet") != Vector3i(32_000_000, 12_000_000, 0), "A grounded actor must not pass through the eight-foot wall.")
	var airborne := arena.resolve_spatial_motion(&"flyer", Vector3i(28_000_000, 12_000_000, 9_000_000), Vector3i(32_000_000, 12_000_000, 9_000_000), {})
	_expect_equal(airborne.get("position_microfeet"), Vector3i(32_000_000, 12_000_000, 9_000_000), "An actor whose base clears the eight-foot wall may cross at nine feet.")
	_expect_true(not arena.is_spatial_position_legal(&"flyer", Vector3i(10_000_000, 10_000_000, 10_000_001), {}).get("legal", true), "The authored Wave 4 altitude cap must be ten feet.")


func _test_takeoff_and_landing_use_mr_not_acts() -> void:
	var session := _ready_session(33_401, true, false)
	var actor_id := StringName(session.get_targetable_enemy_ids()[0])
	var state := session.get_actor_state(actor_id)
	session.set_opponent_behavior_enabled(true)
	var takeoff := session._run_gargoyle_tactical_selection(actor_id, Fixture.PLAYER_ID)
	_expect_equal(takeoff.get("status"), "taking_off", "Grounded Gargoyle tactics must select MR-funded takeoff.")
	_expect_true(not takeoff.get("action_started", true), "Takeoff must not start or spend an ordinary Act.")
	_expect_equal(state.current_action_instance_id, "", "Takeoff must leave the ordinary action slot free.")
	session._advance_gargoyle_flight(1_000_000)
	_expect_equal(state.elevation_microfeet, 3_200_000, "One second of vertical takeoff at MR 16 must travel 3.2 feet.")
	_expect_equal(state.current_action_instance_id, "", "MR-funded takeoff must not create a delayed action cooldown.")
	var airborne := Vector3i(state.position_microfeet.x, state.position_microfeet.y, state.elevation_microfeet)
	var grounded := Vector3i(state.position_microfeet.x, state.position_microfeet.y, 0)
	var landing := session.get_battlefield().resolve_spatial_motion(actor_id, airborne, grounded, session._actor_spatial_occupancy())
	_expect_true(landing.get("success", false), "A legal vertical landing path must resolve through the ordinary spatial movement system.")
	_expect_equal(landing.get("movement_cost_microfeet"), 3_200_000, "Landing must charge its actual vertical MR distance.")
	_expect_true(session.simulation.apply_authoritative_spatial_position(actor_id, state.position_microfeet, 0, state.facing_millidegrees, int(landing.get("movement_cost_microfeet", 0))).get("success", false), "Landing must apply as authoritative MR-funded movement.")
	_expect_equal(state.elevation_microfeet, 0, "Landing must finish grounded.")
	_expect_equal(state.current_action_instance_id, "", "Landing must not spend an ordinary Act.")
	_expect_equal(_events(session, &"action_initiated", actor_id).size(), 0, "Takeoff and landing must not emit ordinary action lifecycle events.")


func _test_fury_applies_to_one_three_strike_act() -> void:
	var session: ArenaCombatSession = null
	var actor_id := &""
	var result := {}
	var damage_events: Array[CombatEvent] = []
	for seed in range(1, 65):
		var candidate := _ready_session(seed, true, false)
		var candidate_id := StringName(candidate.get_targetable_enemy_ids()[0])
		var target_state := candidate.get_actor_state(Fixture.PLAYER_ID)
		candidate.simulation.set_actor_defense_state(Fixture.PLAYER_ID, &"unaware", PackedStringArray())
		candidate.simulation.apply_authoritative_position(candidate_id, target_state.position_microfeet + Vector2i(1_000_000, 0), 180_000)
		var candidate_result := candidate._request_actor_attack(candidate_id, Fixture.PLAYER_ID, "task33a_fury", &"head")
		if not candidate_result.get("success", false):
			continue
		var candidate_action := candidate.simulation.get_action(String(candidate_result.get("action_instance_id", "")))
		candidate.advance_by(candidate_action.final_effect_due_at_us - candidate.simulation.clock.get_elapsed_us())
		var candidate_damage := _events(candidate, &"physical_damage_resolved", candidate_id)
		if candidate_damage.is_empty():
			continue
		session = candidate
		actor_id = candidate_id
		result = candidate_result
		damage_events = candidate_damage
		break
	_expect_true(session != null, "A deterministic source-valid seed must produce Fury damage evidence within the bounded sample.")
	if session == null:
		return
	var state := session.get_actor_state(actor_id)
	var declarations := _events(session, &"physical_attack_declared", actor_id)
	_expect_equal(declarations.size(), 3, "Fury must enhance exactly one claw/claw/bite action containing three strikes.")
	var action_ids := {}
	var strike_labels: Array[String] = []
	for declaration: CombatEvent in declarations:
		action_ids[String(declaration.payload.get("action_instance_id", ""))] = true
		strike_labels.append(String(declaration.payload.get("strike_label", "")))
		_expect_equal(declaration.payload.get("nac_ability_id"), "fury", "Each strike declaration in the Fury Act must identify the same NAC.")
	_expect_equal(action_ids.size(), 1, "Fury must not create extra Acts.")
	_expect_equal(strike_labels, ["claw_1", "claw_2", "bite"], "Natural strike order must remain stable.")
	_expect_equal(state.ability_daily_remaining.get("fury"), 0, "Fury must consume its single daily use once, not once per strike.")
	_expect_equal(state.nac_uses_this_round, 1, "One Fury-enhanced Act must count as one NAC use toward the round cap.")
	_expect_equal(_events(session, &"physical_attack_accuracy_resolved", actor_id).size(), 3, "Every Fury strike must independently reach ACC resolution.")
	var commitments := _events(session, &"nac_attack_enhancement_committed", actor_id)
	_expect_equal(commitments.size(), 1, "One Fury-enhanced Act must serialize one authoritative NAC commitment.")
	if not commitments.is_empty():
		_expect_equal(commitments[0].payload.get("daily_before"), 1, "Fury commitment must record its available daily use.")
		_expect_equal(commitments[0].payload.get("daily_after"), 0, "Fury commitment must serialize the exhausted daily allowance.")
		_expect_equal(commitments[0].payload.get("ordinary_acts_spent"), 0, "Fury must spend zero ordinary Acts.")
		_expect_equal(commitments[0].payload.get("ap_spent"), 0, "Fury must not acquire an unapproved AP fallback.")
		_expect_equal((commitments[0].payload.get("attack_instance_ids", []) as Array).size(), 3, "The single commitment must bind all three natural strikes.")
	for damage_event: CombatEvent in damage_events:
		var numerator := int(damage_event.payload.get("combined_multiplier_numerator", 0))
		var denominator := int(damage_event.payload.get("combined_multiplier_denominator", 0))
		_expect_true(denominator == 1 and numerator >= 3 and numerator % 3 == 0, "Head x1.5 and Fury x2 must compose into one exact product before protection and the single floor.")
		var damage_snapshot := _damage_snapshot(session, String(damage_event.payload.get("damage_resolution_id", "")))
		var multiplier_kinds: Array[String] = []
		for multiplier: Dictionary in damage_snapshot.get("applied_multipliers", []):
			multiplier_kinds.append(String(multiplier.get("kind", "")))
		_expect_true(multiplier_kinds.has("location") and multiplier_kinds.has("fury"), "Resolved damage evidence must retain both the location and Fury factors.")
		_expect_equal(
			int(damage_snapshot.get("multiplied_total", -1)),
			int(damage_snapshot.get("pre_multiplier_total", 0)) * numerator / denominator,
			"The combined Fury/location product must be applied once before TAL and NAL."
		)
	for attack_id: String in result.get("attack_instance_ids", []):
		var snapshot := _attack_snapshot(session, attack_id)
		var multipliers: Array = snapshot.get("consequence_damage_multipliers", [])
		_expect_true(multipliers.any(func(value: Dictionary) -> bool: return String(value.get("kind", "")) == "fury" and int(value.get("numerator", 0)) == 2), "Each qualifying strike must retain the exact Fury x2 multiplier.")
	var second := session._request_actor_attack(actor_id, Fixture.PLAYER_ID, "task33a_no_second_fury")
	_expect_true(second.get("success", false), "A later ordinary natural attack must remain legal after Fury is spent.")
	for attack_id: String in second.get("attack_instance_ids", []):
		var snapshot := _attack_snapshot(session, attack_id)
		_expect_true((snapshot.get("consequence_damage_multipliers", []) as Array).is_empty(), "Spent Fury must not leak into a later Act.")


func _test_autonomous_wall_overflight_and_victory() -> void:
	var session := _ready_session(33_405, true, true)
	var ids := session.get_targetable_enemy_ids()
	var first_id := StringName(ids[0])
	var first_state := session.get_actor_state(first_id)
	_expect_equal(first_state.current_action_instance_id, "", "A grounded Gargoyle must begin MR-funded takeoff without occupying its ordinary action slot.")
	var cleared_wall := false
	var reached_authored_flight_height := false
	for unused in range(200):
		session.advance_by(100_000)
		first_state = session.get_actor_state(first_id)
		reached_authored_flight_height = reached_authored_flight_height or first_state.elevation_microfeet > 8_000_000
		cleared_wall = cleared_wall or (first_state.position_microfeet.x < 29_000_000 and first_state.elevation_microfeet > 8_000_000)
		_expect_true(first_state.elevation_microfeet <= 10_000_000, "Autonomous flight must never exceed the authored ten-foot cap.")
		if cleared_wall:
			break
	_expect_true(reached_authored_flight_height, "The Gargoyle must rise above the authored eight-foot wall.")
	_expect_true(cleared_wall, "The Gargoyle must use true airborne movement to cross the center wall.")
	for actor_id: String in ids:
		session.get_actor_state(StringName(actor_id)).current_hpc = 0
	session.advance_by(1)
	_expect_equal(session.get_encounter_state(), ArenaCombatSession.ENCOUNTER_BETWEEN_WAVE_DOWNTIME, "Wave 4 victory must enter safe downtime only after every spawned Gargoyle is defeated.")


func _test_four_gargoyle_performance_and_partition_determinism() -> void:
	var seed := -1
	for candidate_seed in range(1, 256):
		var candidate := _ready_session(candidate_seed, false, false)
		if candidate.get_targetable_enemy_ids().size() == 4:
			seed = candidate_seed
			break
	_expect_true(seed > 0, "A deterministic seed for four Gargoyles must be discoverable.")
	if seed <= 0:
		return
	var coarse := _ready_session(seed, true, true)
	var partitioned := _ready_session(seed, true, true)
	var started_us := Time.get_ticks_usec()
	coarse.advance_by(10_000_000)
	var simulation_us := Time.get_ticks_usec() - started_us
	for unused in range(100):
		partitioned.advance_by(100_000)
	_expect_equal(_event_signature(partitioned), _event_signature(coarse), "Four-Gargoyle flight/combat must be independent of caller frame partitioning.")
	_expect_equal(partitioned.get_state_snapshot(), coarse.get_state_snapshot(), "Four-Gargoyle authoritative state must remain deterministic.")
	_expect_equal(coarse.get_last_error(), "", "Four-Gargoyle pursuit must not hit an authoritative session error.")
	var movement_events := _events_of_type(coarse, &"actor_position_changed").size()
	print("METRIC: Task33A four-Gargoyle seed=%d simulation_us=%d movement_events=%d total_events=%d" % [seed, simulation_us, movement_events, coarse.get_resolved_event_count()])


func _test_wave_four_replay_sync_and_presentation() -> void:
	var session := _ready_session(33_403, false, false)
	var events_before := _event_signature(session)
	var snapshot_before := session.get_state_snapshot()
	_expect_true(session.reset_encounter(false).get("success", false), "Wave 4 RESET must rebuild the encounter.")
	_expect_equal(_event_signature(session), events_before, "Wave 4 RESET must reproduce the authoritative event history.")
	_expect_equal(session.get_state_snapshot(), snapshot_before, "Wave 4 RESET must reproduce the full authoritative state.")

	var harness := TwoClientSyncHarness.new(33_404)
	var authority := ArenaCombatSession.new(33_404, harness.authority.simulation, Fixture.ENCOUNTER_WAVE_FOUR_GARGOYLES)
	authority.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
	_expect_true(authority.initialize_wave_four_gargoyles(PLAYER_POSITION, GARGOYLE_POSITION, false).get("success", false), "External authority must initialize Wave 4.")
	harness.deliver_in_order(harness.authority.publish_current_events())
	_expect_true(harness.compare_clients().get("success", false), "Wave 4 initialization must converge on both simulated clients.")
	_expect_equal(harness.authority.get_state_digest(), harness.client_a.get_state_digest(), "Wave 4 client digest must match authority.")
	_expect_equal(ArenaCombatController.format_altitude_indicator(6_000_000), "▲ 6 ft", "The compact altitude label must describe authoritative height.")
	_expect_equal(ArenaCombatController.format_altitude_indicator(6_500_000), "▲ 6.5 ft", "Fractional authoritative altitude must not be rounded to a false whole foot.")


func _ready_session(seed: int, start_active: bool, behavior_enabled: bool) -> ArenaCombatSession:
	var session := ArenaCombatSession.new(seed, null, Fixture.ENCOUNTER_WAVE_FOUR_GARGOYLES)
	session.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
	session.set_opponent_behavior_enabled(behavior_enabled)
	_expect_true(session.initialize_wave_four_gargoyles(PLAYER_POSITION, GARGOYLE_POSITION, start_active).get("success", false), "Wave 4 fixture must initialize.")
	return session


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


func _damage_snapshot(session: ArenaCombatSession, resolution_id: String) -> Dictionary:
	for resolution: Dictionary in session.simulation.get_state_snapshot().get("damage_resolutions", []):
		if String(resolution.get("damage_resolution_id", "")) == resolution_id:
			return resolution
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
