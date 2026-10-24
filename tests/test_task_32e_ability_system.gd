class_name Task32EAbilitySystemTests
extends RefCounted

const ArenaBattlefield = preload("res://scripts/combat/arena_battlefield.gd")
const ArenaCombatSession = preload("res://scripts/combat/arena_combat_session.gd")
const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
const HadesFixture = preload("res://scripts/creatures/hades_combat_follower_fixture.gd")

const PLAYER_POSITION := Vector2i(20_000_000, 12_000_000)
const ENEMY_POSITION := Vector2i(24_000_000, 12_000_000)

var _failures: Array[String] = []


func run() -> Array[String]:
	_failures.clear()
	_test_allowances_repeat_purchase_and_fresh_state()
	_test_free_uses_then_shared_ap()
	_test_interruption_commits_once_without_ss_roll()
	_test_authoritative_midnight_and_between_wave_persistence()
	_test_touched_ally_healing_and_contact_loss()
	_test_dirt_hand_and_touched_ally_buff()
	_test_session_ally_selection_and_enemy_rejection()
	_test_reset_restores_full_resources()
	return _failures


func _test_allowances_repeat_purchase_and_fresh_state() -> void:
	var actor := HadesFixture.make_actor(&"allowance_fixture", "Allowance Fixture")
	var expected := {
		String(HadesFixture.CALLED_SHOT_ACTION_ID): 2,
		String(HadesFixture.REJUVENATING_MIST_ACTION_ID): 3,
		String(HadesFixture.RAGE_ACTION_ID): 2,
		String(HadesFixture.DEFENSIVE_BUFF_ACTION_ID): 2,
	}
	for ability_id: String in expected:
		_expect_equal(actor.get_ability_daily_maximum(StringName(ability_id)), expected[ability_id], "Hades daily allowance must match the source parenthetical.")
	var purchased := CombatActorDefinition.new(
		&"repeat_purchase", &"ability_fixture", "Repeat Purchase", {}, {"hpm": 1, "at": 1, "init": 0},
		{"ap": 2}, PackedStringArray(), {}, {}, PackedStringArray(), &"medium",
		{"test_ability": {"base_daily_uses": 2, "repurchase_count": 2, "bonus_daily_uses": 0}}
	)
	_expect_equal(purchased.get_ability_daily_maximum(&"test_ability"), 6, "Each repeat purchase must add the full original allotment.")
	var simulation := CombatSimulation.new(320_501)
	_expect_true(simulation.register_actor(actor).get("success", false), "Ability fixture must register.")
	var state := simulation.get_actor_state(actor.actor_id)
	_expect_equal(state.ability_daily_remaining, expected, "A fresh encounter must begin with every independent daily counter full.")
	_expect_equal(state.resources.get("ap"), 9, "A fresh encounter must begin with the source AP maximum.")


func _test_free_uses_then_shared_ap() -> void:
	var setup := _ability_simulation(320_502)
	var simulation: CombatSimulation = setup["simulation"]
	var actor_id: StringName = setup["actor_id"]
	var state := simulation.get_actor_state(actor_id)
	var called := HadesFixture.make_called_shot_action_definition()
	for index in range(3):
		var result := simulation.start_verified_special_action(
			actor_id, &"ally", called, "called_payment_%s" % index, &"torso", true
		)
		_expect_true(result.get("success", false), "Called Shot payment fixture must start.")
		if not result.get("success", false):
			continue
		var action := simulation.get_action(String(result["action_instance_id"]))
		simulation.advance_to(action.final_effect_due_at_us)
		state.pending_called_shot = {}
	_expect_equal(state.ability_daily_remaining.get(String(HadesFixture.CALLED_SHOT_ACTION_ID)), 0, "Two free Called Shot uses must be consumed before AP.")
	_expect_equal(state.resources.get("ap"), 8, "The third Called Shot must cost exactly one shared AP.")
	_expect_equal(state.ability_daily_remaining.get(String(HadesFixture.RAGE_ACTION_ID)), 2, "Called Shot consumption must not alter Rage's independent counter.")
	var commits := _events(simulation, &"ability_use_committed", actor_id)
	_expect_equal(commits.size(), 3, "Each accepted activation must commit exactly one resource payment.")
	if commits.size() == 3:
		_expect_equal(commits[0].payload.get("payment_kind"), "daily_use", "First activation must use the daily allowance.")
		_expect_equal(commits[2].payload.get("payment_kind"), "ability_point", "Fallback activation must identify AP payment.")
	state.resources["ap"] = 0
	var rejected := simulation.start_verified_special_action(actor_id, &"ally", called, "called_no_resources", &"torso", true)
	_expect_equal(rejected.get("reason"), "insufficient_ability_resources", "An exhausted allowance and AP pool must fail closed.")


func _test_interruption_commits_once_without_ss_roll() -> void:
	var setup := _ability_simulation(320_503)
	var simulation: CombatSimulation = setup["simulation"]
	var actor_id: StringName = setup["actor_id"]
	var state := simulation.get_actor_state(actor_id)
	var draws_before := simulation.random.get_draw_count()
	var rage := simulation.start_verified_timed_stat_effect_action(actor_id, HadesFixture.make_rage_action_definition(), "rage_interrupt_32e")
	_expect_true(rage.get("success", false), "Rage must start without an SS casting check.")
	_expect_equal(simulation.random.get_draw_count(), draws_before, "Ability activation must consume no SS-check RNG draw.")
	var action := simulation.get_action(String(rage.get("action_instance_id", "")))
	if action == null:
		return
	simulation.schedule_interruption(action.action_instance_id, simulation.clock.get_elapsed_us() + 1_000_000, &"ally", "test_interrupt")
	simulation.advance_to(action.final_effect_due_at_us)
	_expect_equal(state.ability_daily_remaining.get(String(HadesFixture.RAGE_ACTION_ID)), 1, "Interrupted casting retains exactly one committed daily use.")
	_expect_equal(_events(simulation, &"ability_use_committed", actor_id).size(), 1, "Interruption must not duplicate resource commitment.")
	_expect_true(not state.timed_stat_effects.has(String(HadesFixture.RAGE_EFFECT_ID)), "Interrupted Rage must not apply its effect.")


func _test_authoritative_midnight_and_between_wave_persistence() -> void:
	var setup := _ability_simulation(320_504)
	var simulation: CombatSimulation = setup["simulation"]
	var actor_id: StringName = setup["actor_id"]
	var state := simulation.get_actor_state(actor_id)
	state.ability_daily_remaining[String(HadesFixture.CALLED_SHOT_ACTION_ID)] = 0
	state.ability_daily_remaining[String(HadesFixture.RAGE_ACTION_ID)] = 1
	state.resources["ap"] = 3
	state.current_hpc = 10
	var before_downtime := state.to_dictionary()
	var recovery := simulation.restore_actor_between_wave_resources(actor_id)
	_expect_equal(recovery.get("reason"), "automatic_between_wave_recovery_prohibited", "Between-wave downtime must reject the superseded automatic recovery path.")
	_expect_equal(state.to_dictionary(), before_downtime, "Between-wave downtime must preserve HPC, resources, daily uses and actor state exactly.")
	var draws_before := simulation.random.get_draw_count()
	var midnight := simulation.apply_authoritative_midnight_refresh("world_day_2_midnight")
	_expect_true(midnight.get("success", false), "An explicit game-world midnight boundary must refresh Ability resources.")
	_expect_equal(state.resources.get("ap"), 9, "Game-world midnight must restore AP.")
	_expect_equal(state.ability_daily_remaining, state.ability_daily_maxima, "Game-world midnight must restore every daily counter.")
	_expect_equal(simulation.random.get_draw_count(), draws_before, "Midnight refresh must not use RNG or a real-world clock.")
	_expect_equal(simulation.apply_authoritative_midnight_refresh("world_day_2_midnight").get("reason"), "duplicate_midnight_refresh", "A world-midnight ID must be idempotent.")


func _test_touched_ally_healing_and_contact_loss() -> void:
	var setup := _ability_simulation(320_505)
	var simulation: CombatSimulation = setup["simulation"]
	var actor_id: StringName = setup["actor_id"]
	var ally_state := simulation.get_actor_state(&"ally")
	ally_state.current_hpc = 5
	var touch_fact: Dictionary = setup["touch_fact"]
	var mist := simulation.start_verified_special_action(actor_id, &"ally", HadesFixture.make_rejuvenating_mist_action_definition(), "mist_ally", &"", true)
	_expect_true(mist.get("success", false), "Rejuvenating Mist must accept a legal touched ally.")
	var mist_action := simulation.get_action(String(mist.get("action_instance_id", "")))
	if mist_action != null:
		simulation.advance_to(mist_action.final_effect_due_at_us)
	_expect_true(int(ally_state.current_hpc) > 5 and int(ally_state.current_hpc) <= 20, "Mist must change the selected ally's HPC and cap it at HPM.")
	var healing_events := _events(simulation, &"verified_healing_resolved", actor_id)
	_expect_true(not healing_events.is_empty() and healing_events[-1].target_actor_id == &"ally", "Healing evidence must identify the actual recipient.")

	var lost_setup := _ability_simulation(320_506)
	var lost_simulation: CombatSimulation = lost_setup["simulation"]
	var lost_actor: StringName = lost_setup["actor_id"]
	var lost_ally := lost_simulation.get_actor_state(&"ally")
	lost_ally.current_hpc = 5
	var lost := lost_simulation.start_verified_special_action(lost_actor, &"ally", HadesFixture.make_rejuvenating_mist_action_definition(), "mist_touch_lost", &"", true)
	(lost_setup["touch_fact"] as Dictionary)["legal"] = false
	var lost_action := lost_simulation.get_action(String(lost.get("action_instance_id", "")))
	if lost_action != null:
		lost_simulation.advance_to(lost_action.final_effect_due_at_us)
	_expect_equal(lost_ally.current_hpc, 5, "Losing touch before completion must prevent ally healing.")
	_expect_equal(_events(lost_simulation, &"verified_special_completion_failed", lost_actor).size(), 1, "Lost touch must create explicit failure evidence.")


func _test_dirt_hand_and_touched_ally_buff() -> void:
	var setup := _ability_simulation(320_507)
	var simulation: CombatSimulation = setup["simulation"]
	var actor_id: StringName = setup["actor_id"]
	var state := simulation.get_actor_state(actor_id)
	(setup["material_fact"] as Dictionary)["legal"] = false
	var invalid := simulation.start_gather_material_action(actor_id, &"dirt", "authored_dirt", "invalid_dirt")
	_expect_equal(invalid.get("reason"), "gatherable_material_unverified", "Dirt cannot be fabricated from unsuitable terrain.")
	(setup["material_fact"] as Dictionary)["legal"] = true
	var gather := simulation.start_gather_material_action(actor_id, &"dirt", "authored_dirt", "legal_dirt")
	_expect_true(gather.get("success", false), "Authored dirt and a free left hand must permit gathering.")
	var gather_action := simulation.get_action(String(gather.get("action_instance_id", "")))
	if gather_action != null:
		simulation.advance_to(gather_action.final_effect_due_at_us)
	_expect_equal(state.hand_occupancy.get("left"), "material:dirt", "Gathered dirt must occupy the left hand.")
	_expect_equal(state.hand_occupancy.get("right"), String(HadesFixture.WEAPON_REF), "Gathering dirt must preserve the right-hand Short Sword.")
	var buff := simulation.start_verified_special_action(actor_id, &"ally", HadesFixture.make_defensive_buff_action_definition(), "ally_buff", &"", true)
	_expect_true(buff.get("success", false), "Defensive Buff must accept a legal touched ally while dirt is held.")
	var buff_action := simulation.get_action(String(buff.get("action_instance_id", "")))
	if buff_action != null:
		simulation.advance_to(buff_action.final_effect_due_at_us)
	_expect_equal(simulation.get_effective_actor_combat_stat(&"ally", "nal"), 2, "Defensive Buff must add +2 NAL to the selected ally.")
	_expect_true(state.held_materials.is_empty() and String(state.hand_occupancy.get("left", "")).is_empty(), "Successful completion must consume dirt and free the left hand.")


func _test_session_ally_selection_and_enemy_rejection() -> void:
	var mist_session := ArenaCombatSession.new(320_509, null, Fixture.ENCOUNTER_WAVE_THREE_SKELLY_HADES)
	mist_session.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
	_expect_true(mist_session.initialize_wave_three_skelly_hades(PLAYER_POSITION, ENEMY_POSITION, false).get("success", false), "Ally-selection fixture must initialize.")
	var hades_id := _hades_id(mist_session)
	var skelly_id := _first_skelly_id(mist_session)
	mist_session.simulation.apply_authoritative_position(hades_id, Vector2i(20_000_000, 5_000_000), 0)
	mist_session.simulation.apply_authoritative_position(skelly_id, Vector2i(21_000_000, 5_000_000), 180_000)
	mist_session.get_actor_state(skelly_id).current_hpc = 1
	var mist_choice := mist_session._run_hades_tactical_selection(hades_id, Fixture.PLAYER_ID)
	_expect_equal(mist_choice.get("status"), "casting_rejuvenating_mist", "The tactical follower must select a genuinely injured touched ally.")
	var mist_action := mist_session.simulation.get_action(mist_session.get_actor_state(hades_id).current_action_instance_id)
	if mist_action != null:
		_expect_equal(mist_action.execution_context.get("target_actor_id"), String(skelly_id), "Tactical Mist must lock the selected ally recipient.")

	var buff_session := ArenaCombatSession.new(320_510, null, Fixture.ENCOUNTER_WAVE_THREE_SKELLY_HADES)
	buff_session.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
	_expect_true(buff_session.initialize_wave_three_skelly_hades(PLAYER_POSITION, ENEMY_POSITION, false).get("success", false), "Ally Buff fixture must initialize.")
	var buff_hades := _hades_id(buff_session)
	var buff_skelly := _first_skelly_id(buff_session)
	buff_session.simulation.apply_authoritative_position(buff_hades, Vector2i(20_000_000, 5_000_000), 0)
	buff_session.simulation.apply_authoritative_position(buff_skelly, Vector2i(21_000_000, 5_000_000), 180_000)
	buff_session.get_actor_state(buff_skelly).current_hpc = 7
	var surface := buff_session._battlefield.get_gatherable_material_at(buff_session.get_actor_state(buff_hades).position_microfeet, &"dirt")
	var gather := buff_session.simulation.start_gather_material_action(buff_hades, &"dirt", String(surface.get("surface_id", "")), "ally_buff_dirt")
	var gather_action := buff_session.simulation.get_action(String(gather.get("action_instance_id", "")))
	if gather_action != null:
		buff_session.simulation.advance_to(gather_action.final_effect_due_at_us)
	var buff_choice := buff_session._run_hades_tactical_selection(buff_hades, Fixture.PLAYER_ID)
	_expect_equal(buff_choice.get("status"), "casting_defensive_buff", "The tactical follower must select a valuable touched ally Buff.")
	var buff_action := buff_session.simulation.get_action(buff_session.get_actor_state(buff_hades).current_action_instance_id)
	if buff_action != null:
		_expect_equal(buff_action.execution_context.get("target_actor_id"), String(buff_skelly), "Tactical Buff must lock the selected ally recipient.")

	var enemy_session := ArenaCombatSession.new(320_511, null, Fixture.ENCOUNTER_WAVE_THREE_SKELLY_HADES)
	enemy_session.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
	_expect_true(enemy_session.initialize_wave_three_skelly_hades(PLAYER_POSITION, ENEMY_POSITION, false).get("success", false), "Enemy-target rejection fixture must initialize.")
	var enemy_hades := _hades_id(enemy_session)
	enemy_session.simulation.apply_authoritative_position(enemy_hades, PLAYER_POSITION + Vector2i(1_000_000, 0), 180_000)
	var illegal_enemy_mist := enemy_session.simulation.start_verified_special_action(
		enemy_hades, Fixture.PLAYER_ID, HadesFixture.make_rejuvenating_mist_action_definition(), "enemy_mist_rejected", &"", true
	)
	_expect_equal(illegal_enemy_mist.get("reason"), "special_touch_unverified", "Self-or-ally Specials must never accept the opposing player as a touched recipient.")


func _test_reset_restores_full_resources() -> void:
	var session := ArenaCombatSession.new(320_508, null, Fixture.ENCOUNTER_WAVE_THREE_SKELLY_HADES)
	session.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
	_expect_true(session.initialize_wave_three_skelly_hades(PLAYER_POSITION, ENEMY_POSITION, false).get("success", false), "Wave 3 reset fixture must initialize.")
	var actor_id := _hades_id(session)
	var state := session.get_actor_state(actor_id)
	state.resources["ap"] = 0
	for ability_id: String in state.ability_daily_remaining:
		state.ability_daily_remaining[ability_id] = 0
	_expect_true(session.reset_encounter(false).get("success", false), "RESET must rebuild a fresh deterministic encounter.")
	var reset_state := session.get_actor_state(_hades_id(session))
	_expect_equal(reset_state.resources.get("ap"), 9, "RESET must restore full AP.")
	_expect_equal(reset_state.ability_daily_remaining, reset_state.ability_daily_maxima, "RESET must restore all daily uses.")


func _ability_simulation(seed: int) -> Dictionary:
	var simulation := CombatSimulation.new(seed)
	var hades := HadesFixture.make_actor(&"hades", "Hades")
	var ally := CombatActorDefinition.new(
		&"ally", &"ability_ally_fixture", "Ability Ally",
		{"str": 1, "end": 1, "spd": 1, "dex": 1, "wis": 1, "int": 1, "wit": 1, "man": 1, "luk": 1, "app": 1},
		{"hpm": 20, "acc": 1, "at": 1, "init": 0, "mr": 1, "nal": 0, "dt": 1, "dp": 1, "physical_soak": 0},
		{}, PackedStringArray(), {}, {}, PackedStringArray(), &"medium"
	)
	_expect_true(simulation.register_actor(hades).get("success", false), "Hades ability fixture must register.")
	_expect_true(simulation.register_actor(ally).get("success", false), "Touched ally fixture must register.")
	_expect_true(simulation.configure_actor_hand_occupancy(hades.actor_id, {"right": String(HadesFixture.WEAPON_REF)}).get("success", false), "Hades hand state must be authoritative.")
	var touch_fact := {"legal": true}
	var material_fact := {"legal": true}
	simulation.set_special_touch_resolver(func(_actor_id: StringName, _target_id: StringName) -> bool: return bool(touch_fact["legal"]))
	simulation.set_gatherable_material_resolver(func(_actor_id: StringName, material_id: StringName, surface_id: String) -> bool:
		return bool(material_fact["legal"]) and material_id == &"dirt" and surface_id == "authored_dirt"
	)
	_expect_true(simulation.begin_combat().get("success", false), "Ability fixture combat must begin.")
	return {"simulation": simulation, "actor_id": hades.actor_id, "touch_fact": touch_fact, "material_fact": material_fact}


func _hades_id(session: ArenaCombatSession) -> StringName:
	for actor_id: String in session.get_targetable_enemy_ids():
		if actor_id.begins_with("wave_3_hades_combat_follower_"):
			return StringName(actor_id)
	return &""


func _first_skelly_id(session: ArenaCombatSession) -> StringName:
	for actor_id: String in session.get_targetable_enemy_ids():
		if actor_id.begins_with("wave_3_common_skelly_"):
			return StringName(actor_id)
	return &""


func _events(simulation: CombatSimulation, event_type: StringName, source_id: StringName) -> Array[CombatEvent]:
	var matches: Array[CombatEvent] = []
	for event: CombatEvent in simulation.get_resolved_events():
		if event.event_type == event_type and event.source_actor_id == source_id:
			matches.append(event)
	return matches


func _expect_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s Expected %s, got %s." % [message, str(expected), str(actual)])
