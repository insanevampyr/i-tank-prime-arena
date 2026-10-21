class_name Task32DHadesSpecialsTests
extends RefCounted

const ArenaBattlefield = preload("res://scripts/combat/arena_battlefield.gd")
const ArenaCombatEventPresenter = preload("res://scripts/ui/arena_combat_event_presenter.gd")
const ArenaCombatSession = preload("res://scripts/combat/arena_combat_session.gd")
const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
const HadesFixture = preload("res://scripts/creatures/hades_combat_follower_fixture.gd")
const HitLocations = preload("res://scripts/combat/combat_hit_location_catalog.gd")
const TwoClientSyncHarness = preload("res://scripts/sync/two_client_sync_harness.gd")

const PLAYER_POSITION := Vector2i(20_000_000, 12_000_000)
const ENEMY_POSITION := Vector2i(24_000_000, 12_000_000)

var _failures: Array[String] = []


func run() -> Array[String]:
	_failures.clear()
	_test_dirt_gather_buff_and_interruption()
	_test_one_act_hand_equip()
	_test_autonomous_tactical_choices()
	_test_called_shot_covers_every_strike_in_one_act()
	_test_log_evidence_and_deterministic_reset()
	_test_material_state_two_client_convergence()
	return _failures


func _test_dirt_gather_buff_and_interruption() -> void:
	var session := _ready_session(320_401, false)
	var hades_id := _hades_id(session)
	var state := session.get_actor_state(hades_id)
	_expect_equal(state.hand_occupancy.get("right"), String(HadesFixture.WEAPON_REF), "The verified Short Sword must begin in the right hand.")
	_expect_equal(state.hand_occupancy.get("left"), "", "The follower's left hand must begin free.")
	var surface := session._battlefield.get_gatherable_material_at(state.position_microfeet, &"dirt")
	_expect_true(surface.get("available", false), "The authored Arena dirt floor must expose actual dirt terrain.")
	var gather := session.simulation.start_gather_material_action(hades_id, &"dirt", String(surface.get("surface_id", "")), "task32d_gather")
	_expect_true(gather.get("success", false), "A free left hand on dirt must permit the one-Act gathering action.")
	var gather_action := session.simulation.get_action(String(gather.get("action_instance_id", "")))
	_expect_equal(gather_action.final_effect_due_at_us - gather_action.started_at_us, 2_500_000, "Gathering dirt must cost one AT-2 Act.")
	_expect_true(state.held_materials.is_empty(), "Dirt must not exist before gathering completes.")
	session.simulation.advance_to(gather_action.final_effect_due_at_us)
	_expect_equal(state.held_materials.get("dirt"), 1, "Completed gathering must create exactly one held dirt material.")
	_expect_equal(state.hand_occupancy.get("left"), "material:dirt", "Gathered dirt must occupy the left hand.")
	var occupied_equip := session.simulation.start_equip_hand_item_action(hades_id, HadesFixture.WEAPON_REF, &"left", "task32d_equip_over_dirt")
	_expect_equal(occupied_equip.get("reason"), "hand_occupied", "No weapon or shield may be equipped over dirt held in the left hand.")
	var buff := session.simulation.start_verified_special_action(
		hades_id, hades_id, HadesFixture.make_defensive_buff_action_definition(), "task32d_buff"
	)
	_expect_true(buff.get("success", false), "Authoritatively held dirt must permit Defensive Buff.")
	var buff_action := session.simulation.get_action(String(buff.get("action_instance_id", "")))
	_expect_equal(buff_action.final_effect_due_at_us - buff_action.started_at_us, 5_000_000, "Defensive Buff must require two AT-2 Acts.")
	_expect_equal(buff_action.final_effect_due_at_us, 7_500_000, "Gathering plus Defensive Buff must total exactly three AT-2 Acts, or 7.5 seconds.")
	session.simulation.advance_to(buff_action.final_effect_due_at_us)
	_expect_equal(session.simulation.get_effective_actor_combat_stat(hades_id, "nal"), 3, "Defensive Buff must add +2 to the follower's source NAL 1.")
	_expect_true(state.held_materials.is_empty(), "Successful Defensive Buff must consume the gathered dirt.")
	_expect_equal(state.hand_occupancy.get("left"), "", "Consuming dirt must free the left hand.")

	var interrupted := _ready_session(320_402, false)
	var interrupted_id := _hades_id(interrupted)
	var interrupted_state := interrupted.get_actor_state(interrupted_id)
	var interrupted_surface := interrupted._battlefield.get_gatherable_material_at(interrupted_state.position_microfeet, &"dirt")
	var gather_again := interrupted.simulation.start_gather_material_action(interrupted_id, &"dirt", String(interrupted_surface.get("surface_id", "")), "task32d_gather_interrupt_fixture")
	interrupted.simulation.advance_to(interrupted.simulation.get_action(String(gather_again.get("action_instance_id", ""))).final_effect_due_at_us)
	var buff_interrupted := interrupted.simulation.start_verified_special_action(interrupted_id, interrupted_id, HadesFixture.make_defensive_buff_action_definition(), "task32d_buff_interrupted")
	var interrupted_action := interrupted.simulation.get_action(String(buff_interrupted.get("action_instance_id", "")))
	interrupted.simulation.schedule_interruption(interrupted_action.action_instance_id, interrupted.simulation.clock.get_elapsed_us() + 1_000_000, Fixture.PLAYER_ID, "task32d_verified_interrupt")
	interrupted.simulation.advance_to(interrupted_action.final_effect_due_at_us)
	_expect_equal(interrupted_state.held_materials.get("dirt"), 1, "Interrupted Defensive Buff must retain dirt because consumption occurs only on successful completion.")
	_expect_true(not interrupted_state.timed_stat_effects.has(String(HadesFixture.DEFENSIVE_BUFF_EFFECT_ID)), "Interrupted Defensive Buff must not apply its effect.")
	_expect_equal(interrupted_state.resources.get("ap"), 9, "Interrupted Defensive Buff must not spend AP while a daily use was available.")
	_expect_equal(interrupted_state.ability_daily_remaining.get(String(HadesFixture.DEFENSIVE_BUFF_ACTION_ID)), 1, "Interrupted Defensive Buff must retain its one committed daily-use payment.")


func _test_one_act_hand_equip() -> void:
	var simulation := CombatSimulation.new(320_403)
	var actor := HadesFixture.make_actor(&"equip_fixture", "Equip Fixture")
	_expect_true(simulation.register_actor(actor).get("success", false), "Equip fixture actor must register.")
	_expect_true(simulation.configure_actor_hand_occupancy(actor.actor_id, {}).get("success", false), "Equip fixture must begin with empty hands.")
	_expect_true(simulation.begin_combat().get("success", false), "Equip fixture combat must begin.")
	var equip := simulation.start_equip_hand_item_action(actor.actor_id, HadesFixture.WEAPON_REF, &"right", "task32d_equip")
	_expect_true(equip.get("success", false), "An available Short Sword and free right hand must start equipping.")
	var action := simulation.get_action(String(equip.get("action_instance_id", "")))
	_expect_equal(action.final_effect_due_at_us - action.started_at_us, 2_500_000, "Equipping must consume one complete AT-2 Act.")
	_expect_equal(simulation.get_actor_state(actor.actor_id).hand_occupancy.get("right"), "", "Equipment must not enter the hand before action completion.")
	simulation.advance_to(action.final_effect_due_at_us)
	_expect_equal(simulation.get_actor_state(actor.actor_id).hand_occupancy.get("right"), String(HadesFixture.WEAPON_REF), "Completed equip must occupy the selected hand exactly once.")


func _test_autonomous_tactical_choices() -> void:
	var rage_session := _ready_session(320_404, false)
	var rage_id := _hades_id(rage_session)
	var rage_choice := rage_session._run_hades_tactical_selection(rage_id, Fixture.PLAYER_ID)
	_expect_equal(rage_choice.get("status"), "casting_rage", "A healthy fresh follower must select Rage for useful offense.")

	var mist_session := _ready_session(320_405, false)
	var mist_id := _hades_id(mist_session)
	mist_session.get_actor_state(mist_id).current_hpc = 30
	var mist_choice := mist_session._run_hades_tactical_selection(mist_id, Fixture.PLAYER_ID)
	_expect_equal(mist_choice.get("status"), "casting_rejuvenating_mist", "A genuinely injured follower must prioritize useful healing.")

	var buff_session := _ready_session(320_406, false)
	var buff_id := _hades_id(buff_session)
	var buff_state := buff_session.get_actor_state(buff_id)
	buff_state.current_hpc = 35
	buff_state.resources["ap"] = 0
	buff_state.ability_daily_remaining[String(HadesFixture.REJUVENATING_MIST_ACTION_ID)] = 0
	var gather_choice := buff_session._run_hades_tactical_selection(buff_id, Fixture.PLAYER_ID)
	_expect_equal(gather_choice.get("status"), "gathering_dirt", "An injured follower with only Buff AP must gather real dirt first.")
	var gather_action := buff_session.simulation.get_action(buff_state.current_action_instance_id)
	buff_session.simulation.advance_to(gather_action.final_effect_due_at_us)
	var buff_choice := buff_session._run_hades_tactical_selection(buff_id, Fixture.PLAYER_ID)
	_expect_equal(buff_choice.get("status"), "casting_defensive_buff", "Held dirt and valuable protection must lead to Defensive Buff.")

	var called_session := _ready_session(320_407, false)
	var called_id := _hades_id(called_session)
	var called_state := called_session.get_actor_state(called_id)
	called_state.timed_stat_effects[String(HadesFixture.RAGE_EFFECT_ID)] = {"stat_modifiers": {}, "expires_at_us": 120_000_000}
	called_state.resources["ap"] = 0
	called_state.ability_daily_remaining[String(HadesFixture.REJUVENATING_MIST_ACTION_ID)] = 0
	called_state.ability_daily_remaining[String(HadesFixture.DEFENSIVE_BUFF_ACTION_ID)] = 0
	called_state.ability_daily_remaining[String(HadesFixture.RAGE_ACTION_ID)] = 0
	called_session.simulation.apply_authoritative_position(called_id, PLAYER_POSITION + Vector2i(1_000_000, 0), 180_000)
	var called_choice := called_session._run_hades_tactical_selection(called_id, Fixture.PLAYER_ID)
	_expect_equal(called_choice.get("status"), "preparing_called_shot", "An in-range offensive opportunity must permit deterministic Called Shot selection.")

	var fallback_session := _ready_session(320_408, true)
	var fallback_id := _hades_id(fallback_session)
	for actor_id: String in fallback_session.get_targetable_enemy_ids():
		if actor_id != String(fallback_id):
			fallback_session.get_actor_state(StringName(actor_id)).current_hpc = 0
	var fallback_state := fallback_session.get_actor_state(fallback_id)
	fallback_state.current_action_instance_id = ""
	fallback_state.resources["ap"] = 0
	for ability_id: String in fallback_state.ability_daily_remaining:
		fallback_state.ability_daily_remaining[ability_id] = 0
	fallback_session.simulation.apply_authoritative_position(fallback_id, PLAYER_POSITION + Vector2i(1_000_000, 0), 180_000)
	fallback_session._run_goblin_wave_behavior()
	_expect_true(not _events(fallback_session, &"physical_attack_declared", fallback_id).is_empty(), "AP exhaustion must fall back to a legal Short Sword attack through the session AI.")


func _test_called_shot_covers_every_strike_in_one_act() -> void:
	var session := _ready_session(320_409, false)
	var hades_id := _hades_id(session)
	session.simulation.apply_authoritative_position(hades_id, PLAYER_POSITION + Vector2i(1_000_000, 0), 180_000)
	var called := session.simulation.start_verified_special_action(hades_id, Fixture.PLAYER_ID, HadesFixture.make_called_shot_action_definition(), "task32d_called_multi", &"torso")
	session.simulation.advance_to(session.simulation.get_action(String(called.get("action_instance_id", ""))).final_effect_due_at_us)
	var multiattack := HadesFixture.make_attack_definition(HitLocations.get_same_size_attack_profile())
	multiattack.attack_definition_id = &"task32d_called_shot_two_strike_scheduler_fixture"
	multiattack.strikes_per_act = 2
	var attack := session.simulation.start_physical_attack(hades_id, Fixture.PLAYER_ID, multiattack, "task32d_called_multi_attack", &"torso", true)
	_expect_equal((attack.get("attack_instance_ids", []) as Array).size(), 2, "The inert scheduler fixture must create two strikes in one Act.")
	var action := session.simulation.get_action(String(attack.get("action_instance_id", "")))
	session.simulation.advance_to(action.final_effect_due_at_us)
	for attack_id: String in attack.get("attack_instance_ids", []):
		var strike := session.simulation.get_attack(attack_id)
		_expect_equal(strike.automatic_accuracy_reason, "called_shot", "Called Shot must apply to every strike in the following Act.")
		_expect_equal(strike.natural_roll, null, "No Called Shot strike may consume an ACC roll.")
	var consumed := _events(session, &"called_shot_consumed", hades_id)
	_expect_equal(consumed.size(), 1, "The Called Shot window must be consumed once by the shared Act.")
	if not consumed.is_empty():
		_expect_equal(consumed[0].payload.get("applied_strike_count"), 2, "Called Shot evidence must record both covered strikes.")


func _test_log_evidence_and_deterministic_reset() -> void:
	var session := _ready_session(320_410, true)
	var before_reset := _event_signature(session)
	_expect_true(session.reset_encounter(true).get("success", false), "Wave 3 must reset with Task 32D state.")
	_expect_equal(_event_signature(session), before_reset, "Reset must reproduce hand setup, tactical choice, RNG and event ordering.")
	var hades_id := _hades_id(session)
	var rage_events := _events(session, &"timed_stat_effect_applied", hades_id)
	if rage_events.is_empty():
		var current_action := session.simulation.get_action(session.get_actor_state(hades_id).current_action_instance_id)
		_expect_true(current_action != null and current_action.action_definition_id == HadesFixture.RAGE_ACTION_ID, "Active reset must reproduce the tactical Rage action.")
		if current_action != null:
			session.simulation.advance_to(current_action.final_effect_due_at_us)
		rage_events = _events(session, &"timed_stat_effect_applied", hades_id)
	_expect_true(not rage_events.is_empty(), "Rage must emit calculation-level effect evidence.")
	if not rage_events.is_empty():
		var line := ArenaCombatEventPresenter.format_event(rage_events[-1])
		_expect_true(line.contains("sb") and line.contains("nal") and line.contains("dt") and line.contains("dp"), "FULL LOG formatting must expose Rage's before/after combat calculations.")


func _test_material_state_two_client_convergence() -> void:
	var harness := TwoClientSyncHarness.new(320_411)
	var session := ArenaCombatSession.new(320_411, harness.authority.simulation, Fixture.ENCOUNTER_WAVE_THREE_SKELLY_HADES)
	session.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
	session.set_opponent_behavior_enabled(true)
	_expect_true(session.initialize_wave_three_skelly_hades(PLAYER_POSITION, ENEMY_POSITION, false).get("success", false), "External Task 32D authority must initialize.")
	var hades_id := _hades_id(session)
	var state := session.get_actor_state(hades_id)
	var surface := session._battlefield.get_gatherable_material_at(state.position_microfeet, &"dirt")
	var gather := session.simulation.start_gather_material_action(hades_id, &"dirt", String(surface.get("surface_id", "")), "task32d_sync_gather")
	session.simulation.advance_to(session.simulation.get_action(String(gather.get("action_instance_id", ""))).final_effect_due_at_us)
	var buff := session.simulation.start_verified_special_action(hades_id, hades_id, HadesFixture.make_defensive_buff_action_definition(), "task32d_sync_buff")
	session.simulation.advance_to(session.simulation.get_action(String(buff.get("action_instance_id", ""))).final_effect_due_at_us)
	harness.deliver_in_order(harness.authority.publish_current_events())
	_expect_true(harness.compare_clients().get("success", false), "Dirt, hand state and Defensive Buff events must converge on both simulated clients.")
	_expect_equal(harness.authority.get_state_digest(), harness.client_a.get_state_digest(), "Task 32D material/effect client digest must match authority.")


func _ready_session(seed: int, start_active: bool) -> ArenaCombatSession:
	var session := ArenaCombatSession.new(seed, null, Fixture.ENCOUNTER_WAVE_THREE_SKELLY_HADES)
	session.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
	session.set_opponent_behavior_enabled(true)
	_expect_true(session.initialize_wave_three_skelly_hades(PLAYER_POSITION, ENEMY_POSITION, start_active).get("success", false), "Task 32D Wave 3 session must initialize.")
	return session


func _hades_id(session: ArenaCombatSession) -> StringName:
	for actor_id: String in session.get_targetable_enemy_ids():
		if actor_id.begins_with("wave_3_hades_combat_follower_"):
			return StringName(actor_id)
	return &""


func _events(session: ArenaCombatSession, event_type: StringName, source_id: StringName) -> Array[CombatEvent]:
	var matches: Array[CombatEvent] = []
	for event: CombatEvent in session.get_resolved_events():
		if event.event_type == event_type and event.source_actor_id == source_id:
			matches.append(event)
	return matches


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
