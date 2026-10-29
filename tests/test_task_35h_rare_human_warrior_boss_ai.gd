class_name Task35HRareHumanWarriorBossAITests
extends RefCounted

const BossAI = preload("res://scripts/creatures/rare_human_warrior_boss_ai.gd")
const Fixture = preload("res://scripts/creatures/rare_human_warrior_fixture.gd")

var _failures: Array[String] = []


func run() -> Array[String]:
	_failures.clear()
	_test_melee_throw_and_retain_decisions()
	_test_retrieval_unarmed_and_block_boundary()
	_test_obstacle_pathfinding_and_moving_target()
	_test_both_central_wall_endpoint_routes()
	_test_wall_intercepted_spear_recovery()
	_test_obstructed_throw_and_unreachable_spear_fallback()
	_test_potion_and_combat_ability_decisions()
	_test_interruptions_defeat_and_decision_spam()
	_test_replay_and_two_client_convergence()
	return _failures


func _test_melee_throw_and_retain_decisions() -> void:
	var melee := _make_fixture(35_801, Vector2i(5_000_000, 0), true)
	_exhaust_abilities(melee["simulation"], melee["boss_id"])
	var melee_result: Dictionary = melee["ai"].evaluate_and_submit()
	_expect_equal(melee_result.get("selected_action"), "spear_melee", "A legal six-foot spear opportunity must use the hand-held spear.")
	_expect_true(melee_result.get("action_started", false), "A legal spear melee decision must submit one authoritative physical action.")

	var retain := _make_fixture(35_802, Vector2i(10_000_000, 0), true)
	_exhaust_abilities(retain["simulation"], retain["boss_id"])
	var retain_result: Dictionary = retain["ai"].evaluate_and_submit()
	_expect_equal(retain_result.get("selected_action"), "approach_spear_melee", "The boss must retain his spear when legal melee reach is attainable before the attack effect point.")
	_expect_true(not retain_result.get("action_started", true), "Retaining the spear must not fabricate an attack outside current reach.")

	var thrown := _make_fixture(35_803, Vector2i(18_000_000, 0), true)
	_exhaust_abilities(thrown["simulation"], thrown["boss_id"])
	var throw_result: Dictionary = thrown["ai"].evaluate_and_submit()
	_expect_equal(throw_result.get("selected_action"), "throw_spear", "At the legal 18-foot boundary, an immediate throw may replace an approach that cannot reach before effect resolution.")
	_expect_true(throw_result.get("action_started", false), "The tactical throw must use the verified thrown-weapon transaction.")
	_expect_true(thrown["simulation"].get_actor_state(thrown["boss_id"]).equipment_refs.has(String(Fixture.WEAPON_REF)), "A declared throw must not release the spear before its ordinary action reaches the authoritative effect point.")


func _test_retrieval_unarmed_and_block_boundary() -> void:
	var setup := _make_fixture(35_804, Vector2i(18_000_000, 0), true)
	var simulation: CombatSimulation = setup["simulation"]
	var boss_id: StringName = setup["boss_id"]
	_exhaust_abilities(simulation, boss_id)
	var thrown: Dictionary = setup["ai"].evaluate_and_submit()
	_terminalize_attack(simulation, thrown)
	var spear := _owned_spear_item(simulation, boss_id)
	_expect_equal(spear.get("state"), "dropped", "A completed tactical throw must retain one authoritative dropped spear.")
	var boss_state := simulation.get_actor_state(boss_id)
	_expect_true(not boss_state.equipment_refs.has(String(Fixture.WEAPON_REF)), "The dropped spear must remain unavailable for melee and weapon Block.")
	var block_profile := Fixture.make_defense_profile(boss_id)
	_expect_true(block_profile.weapon_block != null and not boss_state.equipment_refs.has(String(block_profile.weapon_block.equipment_ref)), "The existing defense eligibility gate must reject spear Block while the weapon is dropped.")

	var item_position: Vector2i = spear.get("position_microfeet", Vector2i.ZERO)
	if boss_state.critical_stagger_until_us > simulation.clock.get_elapsed_us():
		simulation.advance_to(boss_state.critical_stagger_until_us)
	simulation.apply_authoritative_position(boss_id, item_position, 0, 0)
	var retrieve: Dictionary = setup["ai"].evaluate_and_submit()
	_expect_equal(retrieve.get("selected_action"), "retrieve_spear", "A boss in pickup reach must prefer the source weapon retrieval action.")
	var retrieval_action: CombatActionInstance = simulation.get_action(String(retrieve.get("action_instance_id", "")))
	_expect_true(retrieval_action != null, "Retrieval must schedule an ordinary authoritative action.")
	if retrieval_action != null:
		_expect_equal(retrieval_action.final_effect_due_at_us - retrieval_action.started_at_us, 2_500_000, "One retrieval Act at AT 2 must last exactly 2.5 seconds.")
		simulation.advance_to(retrieval_action.final_effect_due_at_us)
	_expect_true(simulation.get_actor_state(boss_id).equipment_refs.has(String(Fixture.WEAPON_REF)), "Successful retrieval must restore exactly one spear to authoritative possession.")
	_expect_true(_owned_spear_item(simulation, boss_id).is_empty(), "Retrieval must remove the dropped world-item instance.")

	var unarmed := _make_fixture(35_805, Vector2i(1_000_000, 0), true)
	var unarmed_simulation: CombatSimulation = unarmed["simulation"]
	var unarmed_state: CombatActorState = unarmed_simulation.get_actor_state(unarmed["boss_id"])
	unarmed_state.equipment_refs.erase(String(Fixture.WEAPON_REF))
	unarmed_state.hand_occupancy = {"left": "", "right": ""}
	_exhaust_abilities(unarmed["simulation"], unarmed["boss_id"])
	var unarmed_result: Dictionary = unarmed["ai"].evaluate_and_submit()
	_expect_equal(unarmed_result.get("selected_action"), "unarmed_attack", "A genuinely spearless boss in fist reach must use the verified one-strike Human fallback.")


func _test_obstacle_pathfinding_and_moving_target() -> void:
	var battlefield := ArenaBattlefield.create_task16_test_arena()
	var setup := _make_fixture(
		35_806, Vector2i(33_000_000, 12_000_000), true,
		Vector2i(27_000_000, 12_000_000), battlefield
	)
	var simulation: CombatSimulation = setup["simulation"]
	var ai: RareHumanWarriorBossAI = setup["ai"]
	_exhaust_abilities(simulation, setup["boss_id"])
	var starting_position := simulation.get_actor_state(setup["boss_id"]).position_microfeet
	for tick in range(80):
		simulation.advance_to(simulation.clock.get_elapsed_us() + 250_000)
		ai.advance_movement(250_000)
		if tick == 20:
			simulation.apply_authoritative_position(setup["target_id"], Vector2i(34_000_000, 14_000_000), 0, 0)
	var final_position := simulation.get_actor_state(setup["boss_id"]).position_microfeet
	_expect_true(final_position != starting_position, "The boss must spend legal MR pursuing a target behind the central wall.")
	_expect_true(not _inside_central_wall(final_position), "Obstacle-aware pursuit must never place the boss inside the solid wall.")
	var target_position := simulation.get_actor_state(setup["target_id"]).position_microfeet
	_expect_true(
		battlefield.is_attack_position_legal(final_position, target_position, 6_000_000),
		"Obstacle-aware pursuit must finish within legal six-foot spear reach and line of sight."
	)
	_expect_true(ai.get_diagnostics().get("path_rebuild_count", 0) > 0, "Pursuit must reuse the existing deterministic battlefield pathfinder.")
	_expect_true(ai.get_diagnostics().get("path_rebuild_count", 0) < 20, "A moving target must not cause exhaustive route rebuilding every behavior tick.")


func _test_both_central_wall_endpoint_routes() -> void:
	for route: Dictionary in [
		{"name": "north", "boss": Vector2i(27_000_000, 10_000_000), "target": Vector2i(33_000_000, 10_000_000)},
		{"name": "south", "boss": Vector2i(27_000_000, 18_000_000), "target": Vector2i(33_000_000, 18_000_000)},
	]:
		var battlefield := ArenaBattlefield.create_task16_test_arena()
		var setup := _make_fixture(35_820 + (0 if route["name"] == "north" else 1), route["target"], true, route["boss"], battlefield)
		var simulation: CombatSimulation = setup["simulation"]
		var ai: RareHumanWarriorBossAI = setup["ai"]
		_exhaust_abilities(simulation, setup["boss_id"])
		for _tick in range(120):
			simulation.advance_to(simulation.clock.get_elapsed_us() + 250_000)
			ai.advance_movement(250_000)
			var boss_position := simulation.get_actor_state(setup["boss_id"]).position_microfeet
			if battlefield.is_attack_position_legal(boss_position, route["target"], 6_000_000):
				break
		var final_position := simulation.get_actor_state(setup["boss_id"]).position_microfeet
		_expect_true(battlefield.is_attack_position_legal(final_position, route["target"], 6_000_000), "The boss must navigate around the %s wall endpoint into legal spear reach." % route["name"])
		_expect_true(not _inside_central_wall(final_position), "The %s route must never cross the wall interior." % route["name"])


func _test_wall_intercepted_spear_recovery() -> void:
	var battlefield := ArenaBattlefield.create_task16_test_arena()
	var setup := _make_fixture(
		35_815, Vector2i(27_000_000, 12_000_000), true,
		Vector2i(14_000_000, 12_000_000), battlefield
	)
	var simulation: CombatSimulation = setup["simulation"]
	var ai: RareHumanWarriorBossAI = setup["ai"]
	_exhaust_abilities(simulation, setup["boss_id"])
	var thrown := ai.evaluate_and_submit()
	_expect_equal(thrown.get("selected_action"), "throw_spear", "The setup must declare an initially unobstructed legal throw.")
	simulation.apply_authoritative_position(setup["target_id"], Vector2i(33_000_000, 12_000_000), 0, 0)
	_terminalize_attack(simulation, thrown)
	var attack := simulation.get_attack(String(thrown.get("attack_instance_id", "")))
	_expect_true(attack != null and attack.status == CombatAttackInstance.STATUS_FINAL_LEGALITY_FAILED, "A target moving behind the wall before effect resolution must fail final legality before ACC.")
	_expect_true(attack != null and attack.natural_roll == null, "An obstructed final throw must consume no ACC roll.")
	var landed := _owned_spear_item(simulation, setup["boss_id"])
	_expect_equal(landed.get("state"), "dropped", "A target moving behind the wall must leave the released spear at an authoritative contact position.")
	_expect_equal(landed.get("position_microfeet"), Vector2i(29_000_000, 12_000_000), "The wall-intercepted spear must land at the west face of the central wall.")
	for _tick in range(250):
		simulation.advance_to(simulation.clock.get_elapsed_us() + 100_000)
		ai.advance_movement(100_000)
		ai.evaluate_and_submit()
		if _owned_spear_item(simulation, setup["boss_id"]).is_empty():
			break
	_expect_true(_owned_spear_item(simulation, setup["boss_id"]).is_empty(), "The boss must navigate to and complete legal retrieval of a spear resting against the wall face.")
	_expect_true(simulation.get_actor_state(setup["boss_id"]).equipment_refs.has(String(Fixture.WEAPON_REF)), "Wall-contact retrieval must restore the unique spear without duplication.")


func _test_obstructed_throw_and_unreachable_spear_fallback() -> void:
	var obstructed := _make_fixture(
		35_816, Vector2i(33_000_000, 12_000_000), true,
		Vector2i(14_000_000, 12_000_000), ArenaBattlefield.create_task16_test_arena()
	)
	_exhaust_abilities(obstructed["simulation"], obstructed["boss_id"])
	var blocked_decision: Dictionary = obstructed["ai"].evaluate_and_submit()
	_expect_equal(blocked_decision.get("selected_action"), "approach_spear_melee", "A wall-obstructed target must not permit spear melee or a thrown declaration through solid geometry.")
	_expect_true(not blocked_decision.get("action_started", true), "An obstructed throw must not enter the authoritative action queue.")

	var battlefield := _sealed_test_battlefield()
	var setup := _make_fixture(
		35_817, Vector2i(39_000_000, 5_000_000), true,
		Vector2i(22_000_000, 5_000_000), battlefield
	)
	var simulation: CombatSimulation = setup["simulation"]
	var ai: RareHumanWarriorBossAI = setup["ai"]
	_exhaust_abilities(simulation, setup["boss_id"])
	var thrown := ai.evaluate_and_submit()
	_expect_equal(thrown.get("selected_action"), "throw_spear", "The sealed fixture must first establish a legal unobstructed throw on one side of its wall.")
	_terminalize_attack(simulation, thrown)
	_expect_true(not _owned_spear_item(simulation, setup["boss_id"]).is_empty(), "The sealed fixture must retain one authoritative dropped spear.")
	simulation.apply_authoritative_position(setup["boss_id"], Vector2i(18_000_000, 5_000_000), 180_000, 0)
	simulation.apply_authoritative_position(setup["target_id"], Vector2i(12_000_000, 5_000_000), 0, 0)
	var boss_state := simulation.get_actor_state(setup["boss_id"])
	boss_state.current_hpc = 194
	var initial := ai.evaluate_and_submit()
	_expect_equal(initial.get("selected_action"), "approach_spear", "The boss may make one deterministic recovery attempt before the unreachable route is known.")
	var blocked_move := ai.advance_movement(100_000)
	_expect_true(not blocked_move.get("success", true), "A sealed wall must make the dropped spear route genuinely unreachable.")
	var fallback := ai.evaluate_and_submit()
	_expect_equal(fallback.get("selected_action"), "approach_unarmed", "A cached unreachable spear route must switch the boss to source-backed unarmed pursuit.")
	_expect_true(not ["rejuvenating_mist", "health_potion", "defensive_buff"].has(String(fallback.get("selected_action", ""))), "Minor injury must not replace offensive fallback merely because the spear is unreachable.")
	var unarmed_result := {}
	for _tick in range(100):
		simulation.advance_to(simulation.clock.get_elapsed_us() + 100_000)
		ai.advance_movement(100_000)
		unarmed_result = ai.evaluate_and_submit()
		if unarmed_result.get("selected_action") == "unarmed_attack" and unarmed_result.get("action_started", false):
			break
	_expect_equal(unarmed_result.get("selected_action"), "unarmed_attack", "An unreachable spear must not prevent the boss from closing to one-foot fist reach and attacking.")
	_expect_true(unarmed_result.get("action_started", false), "The verified one-strike Human unarmed definition must enter the ordinary action scheduler.")
	if unarmed_result.get("action_started", false):
		_terminalize_attack(simulation, unarmed_result)
		var unarmed_attack := simulation.get_attack(String(unarmed_result.get("attack_instance_id", "")))
		_expect_true(unarmed_attack != null and unarmed_attack.natural_roll != null, "The unarmed fallback must independently resolve authoritative ACC.")
	_expect_equal(ai.get_diagnostics().get("abandoned_spear_world_item_id"), String(_owned_spear_item(simulation, setup["boss_id"]).get("world_item_id", "")), "The unchanged failed route must remain cached instead of triggering endless spear searches.")
	_expect_true(int(ai.get_diagnostics().get("path_rebuild_count", 0)) < 10, "Unreachable recovery plus unarmed pursuit must remain bounded without exhaustive replanning.")


func _test_potion_and_combat_ability_decisions() -> void:
	var rage := _make_fixture(35_807, Vector2i(10_000_000, 0), true)
	var rage_result: Dictionary = rage["ai"].evaluate_and_submit()
	_expect_equal(rage_result.get("selected_action"), "rage", "An unbuffed boss outside spear reach may invest two Acts in the verified offensive buff.")

	var called := _make_fixture(35_808, Vector2i(5_000_000, 0), true)
	called["simulation"].get_actor_state(called["boss_id"]).ability_daily_remaining[String(Fixture.RAGE_ACTION_ID)] = 0
	var called_result: Dictionary = called["ai"].evaluate_and_submit()
	_expect_equal(called_result.get("selected_action"), "called_shot", "A durable target already in spear reach must permit legal Called Shot preparation.")

	var fallback := _make_fixture(35_814, Vector2i(5_000_000, 0), true)
	var fallback_simulation: CombatSimulation = fallback["simulation"]
	var fallback_state: CombatActorState = fallback_simulation.get_actor_state(fallback["boss_id"])
	fallback_state.ability_daily_remaining[String(Fixture.CALLED_SHOT_ACTION_ID)] = 0
	fallback_state.ability_daily_remaining[String(Fixture.RAGE_ACTION_ID)] = 0
	fallback_state.ability_daily_remaining[String(Fixture.REJUVENATING_MIST_ACTION_ID)] = 0
	fallback_state.ability_daily_remaining[String(Fixture.DEFENSIVE_BUFF_ACTION_ID)] = 0
	fallback_state.resources["ap"] = 1
	var fallback_result: Dictionary = fallback["ai"].evaluate_and_submit()
	_expect_equal(fallback_result.get("selected_action"), "called_shot", "After free uses are exhausted, tactical Called Shot may use the existing shared AP fallback.")
	_expect_equal(fallback_state.resources.get("ap"), 0, "The AI must spend exactly one shared AP through the authoritative Ability payment path.")

	var mist := _make_fixture(35_809, Vector2i(5_000_000, 0), true)
	var mist_simulation: CombatSimulation = mist["simulation"]
	var mist_state: CombatActorState = mist_simulation.get_actor_state(mist["boss_id"])
	mist_state.current_hpc = 180
	var mist_result: Dictionary = mist["ai"].evaluate_and_submit()
	_expect_equal(mist_result.get("selected_action"), "rejuvenating_mist", "Meaningful injury plus immediate threat must justify source-legal Rejuvenating Mist.")

	var potion := _make_fixture(35_810, Vector2i(8_000_000, 0), true)
	var potion_simulation: CombatSimulation = potion["simulation"]
	var potion_state: CombatActorState = potion_simulation.get_actor_state(potion["boss_id"])
	potion_state.current_hpc = 185
	potion_state.equipment_refs.erase(String(Fixture.WEAPON_REF))
	potion_state.hand_occupancy = {"left": "", "right": ""}
	potion_state.ability_daily_remaining[String(Fixture.REJUVENATING_MIST_ACTION_ID)] = 0
	potion_state.resources["ap"] = 0
	var potion_result: Dictionary = potion["ai"].evaluate_and_submit()
	_expect_equal(potion_result.get("selected_action"), "health_potion", "When healing Ability resources are exhausted and a hand is free, a valuable safe heal must use one real potion.")
	var potion_action: CombatActionInstance = potion_simulation.get_action(String(potion_result.get("action_instance_id", "")))
	_expect_equal(potion_state.inventory_quantities.get(String(Fixture.HEALTH_POTION_INVENTORY_ID)), 2, "Potion inventory must not change before the drink action completes.")
	if potion_action != null:
		_expect_equal(potion_action.final_effect_due_at_us - potion_action.started_at_us, 5_000_000, "AI drinking must include the same two-Act retrieval and drinking cost as a player at AT 2.")
		potion_simulation.advance_to(potion_action.final_effect_due_at_us)
	_expect_equal(potion_state.inventory_quantities.get(String(Fixture.HEALTH_POTION_INVENTORY_ID)), 1, "Successful tactical drinking must consume exactly one potion on completion.")

	var buff := _make_fixture(35_811, Vector2i(5_000_000, 0), true)
	var buff_simulation: CombatSimulation = buff["simulation"]
	var buff_state: CombatActorState = buff_simulation.get_actor_state(buff["boss_id"])
	buff_state.current_hpc = 199
	buff_state.equipment_refs.erase(String(Fixture.WEAPON_REF))
	buff_state.hand_occupancy = {"left": "material:dirt", "right": ""}
	buff_state.held_materials = {"dirt": 1}
	buff_state.ability_daily_remaining[String(Fixture.REJUVENATING_MIST_ACTION_ID)] = 0
	var buff_result: Dictionary = buff["ai"].evaluate_and_submit()
	_expect_equal(buff_result.get("selected_action"), "defensive_buff", "Prepared dirt plus a real defensive need must permit the verified nonstacking Defensive Buff.")


func _test_interruptions_defeat_and_decision_spam() -> void:
	var setup := _make_fixture(35_812, Vector2i(10_000_000, 0), true)
	var simulation: CombatSimulation = setup["simulation"]
	var ai: RareHumanWarriorBossAI = setup["ai"]
	var rage: Dictionary = ai.evaluate_and_submit()
	var action := simulation.get_action(String(rage.get("action_instance_id", "")))
	if action != null:
		simulation.schedule_interruption(action.action_instance_id, action.started_at_us + 1_000_000, setup["target_id"], "task35h_interruption")
		simulation.advance_to(action.final_effect_due_at_us)
	_expect_true(not simulation.get_actor_state(setup["boss_id"]).timed_stat_effects.has(String(Fixture.RAGE_EFFECT_ID)), "Interrupted Rage must not be treated as successfully active by the AI.")
	simulation.get_actor_state(setup["target_id"]).current_hpc = 0
	var stopped: Dictionary = ai.evaluate_and_submit()
	_expect_equal(stopped.get("selected_action"), "stopped_target_defeated", "The boss must never start a new action against an incapacitated target.")
	var before := _event_count(simulation, &"tactical_action_selected")
	ai.evaluate_and_submit()
	ai.evaluate_and_submit()
	var after := _event_count(simulation, &"tactical_action_selected")
	_expect_equal(after, before, "Repeated unchanged terminal decisions must not spam authoritative tactical events.")


func _test_replay_and_two_client_convergence() -> void:
	var first := _run_replay_transaction(35_813)
	var second := _run_replay_transaction(35_813)
	_expect_equal(second.get("events"), first.get("events"), "Same-seed boss decisions and movement must preserve exact event ordering and evidence.")
	_expect_equal(second.get("snapshot"), first.get("snapshot"), "Same-seed boss AI must preserve the complete schema-12 authoritative snapshot.")
	var harness: TwoClientSyncHarness = first.get("harness")
	_expect_true(harness != null and harness.compare_clients().get("success", false), "Boss AI events and state must converge on two simulated clients.")
	if harness != null:
		_expect_equal(harness.client_a.get_state_digest(), harness.authority.get_state_digest(), "Client A must match the boss-AI authority digest.")
		_expect_equal(harness.client_b.get_state_digest(), harness.authority.get_state_digest(), "Client B must match the boss-AI authority digest.")


func _run_replay_transaction(seed_value: int) -> Dictionary:
	var harness := TwoClientSyncHarness.new(seed_value)
	var battlefield := ArenaBattlefield.create_open(Rect2i(-20_000_000, -20_000_000, 60_000_000, 40_000_000))
	var setup := _configure_simulation(
		harness.authority.simulation, battlefield, Vector2i.ZERO, Vector2i(10_000_000, 0), true
	)
	var simulation: CombatSimulation = setup["simulation"]
	var ai := RareHumanWarriorBossAI.new(simulation, battlefield, setup["boss_id"], setup["target_id"])
	var decision := ai.evaluate_and_submit()
	var action := simulation.get_action(String(decision.get("action_instance_id", "")))
	if action != null:
		for step in range(5):
			simulation.advance_to(simulation.clock.get_elapsed_us() + 500_000)
			ai.advance_movement(500_000)
	var envelopes := harness.authority.publish_current_events()
	harness.deliver_in_order(envelopes)
	var events: Array = []
	for envelope: CombatEventEnvelope in envelopes:
		events.append(envelope.to_dictionary())
	return {
		"events": events,
		"snapshot": simulation.get_state_snapshot(),
		"harness": harness,
	}


func _make_fixture(
		seed_value: int,
		target_position: Vector2i,
		target_unaware: bool,
		boss_position: Vector2i = Vector2i.ZERO,
		battlefield: ArenaBattlefield = null) -> Dictionary:
	var active_battlefield := battlefield
	if active_battlefield == null:
		active_battlefield = ArenaBattlefield.create_open(Rect2i(-20_000_000, -20_000_000, 60_000_000, 40_000_000))
	var configured := _configure_simulation(
		CombatSimulation.new(seed_value), active_battlefield, boss_position, target_position, target_unaware
	)
	configured["ai"] = RareHumanWarriorBossAI.new(
		configured["simulation"], active_battlefield, configured["boss_id"], configured["target_id"]
	)
	return configured


func _configure_simulation(
		simulation: CombatSimulation,
		battlefield: ArenaBattlefield,
		boss_position: Vector2i,
		target_position: Vector2i,
		target_unaware: bool) -> Dictionary:
	var boss_result := Fixture.instantiate_foundation_actor(&"task35h_boss", "Task 35H Boss")
	var boss: CombatActorDefinition = boss_result.get("actor")
	var target := _target_actor()
	simulation.register_actor(boss)
	simulation.register_actor(target)
	simulation.configure_actor_hand_occupancy(
		boss.actor_id, {"left": String(Fixture.WEAPON_REF), "right": String(Fixture.WEAPON_REF)}
	)
	simulation.get_actor_state(boss.actor_id).position_microfeet = boss_position
	simulation.get_actor_state(target.actor_id).position_microfeet = target_position
	simulation.get_actor_state(target.actor_id).awareness = &"unaware" if target_unaware else &"aware"
	simulation.register_defense_profile(boss.actor_id, Fixture.make_defense_profile(boss.actor_id))
	simulation.register_damage_protection_profile(boss.actor_id, Fixture.make_damage_protection_profile(boss.actor_id))
	simulation.register_defense_profile(target.actor_id, _no_defense_profile())
	simulation.register_damage_protection_profile(target.actor_id, CombatDamageProtectionProfile.new(&"task35h_target_protection"))
	Fixture.configure_spear_landing_geometry(simulation, battlefield)
	var weak_simulation: WeakRef = weakref(simulation)
	simulation.set_attack_final_line_of_sight_resolver(func(attacker_id: StringName, defender_id: StringName) -> bool:
		var active: CombatSimulation = weak_simulation.get_ref()
		return active != null and battlefield.has_line_of_sight(
			active.get_actor_state(attacker_id).position_microfeet,
			active.get_actor_state(defender_id).position_microfeet
		)
	)
	simulation.set_world_item_pickup_resolver(func(actor_id: StringName, item: Dictionary) -> bool:
		var active: CombatSimulation = weak_simulation.get_ref()
		return active != null and item.get("position_microfeet") is Vector2i \
			and active.get_actor_state(actor_id).position_microfeet.distance_to(item["position_microfeet"]) <= 1_000_000.0
	)
	simulation.set_special_touch_resolver(func(actor_id: StringName, recipient_id: StringName) -> bool:
		var active: CombatSimulation = weak_simulation.get_ref()
		return active != null and active.get_actor_state(actor_id).position_microfeet.distance_to(
			active.get_actor_state(recipient_id).position_microfeet
		) <= 1_000_000.0
	)
	simulation.set_gatherable_material_resolver(func(actor_id: StringName, material: StringName, surface: String) -> bool:
		var active: CombatSimulation = weak_simulation.get_ref()
		if active == null:
			return false
		var fact := battlefield.get_gatherable_material_at(active.get_actor_state(actor_id).position_microfeet, material)
		return fact.get("available", false) and String(fact.get("surface_id", "")) == surface
	)
	simulation.begin_combat()
	return {"simulation": simulation, "battlefield": battlefield, "boss_id": boss.actor_id, "target_id": target.actor_id}


func _target_actor() -> CombatActorDefinition:
	return CombatActorDefinition.new(
		&"task35h_target", &"task_35h_target", "Task 35H Target",
		{"str": 10, "end": 10, "spd": 10, "dex": 10, "wis": 10, "int": 10, "wit": 10, "man": 10, "luk": 10, "app": 10},
		{"hpm": 200, "acc": 10, "at": 2, "init": 5, "mr": 10, "nal": 0, "dt": 0, "dp": 0, "physical_soak": 0, "rb": 0, "sb": 0},
		{}, PackedStringArray(),
		{"dodge": false, "weapon_block": false, "shield_block": false, "physical_soak": false},
		{"fixture": "Task 35H controlled observable target"}, PackedStringArray(),
		CombatHitLocationCatalog.SIZE_MEDIUM
	)


func _no_defense_profile() -> CombatDefenseProfile:
	return CombatDefenseProfile.new(
		&"task35h_no_defense", PackedStringArray(["dodge", "weapon_block", "shield_block", "physical_soak"]),
		{}, null, null, PackedStringArray(["Task 35H controlled no-defense target"])
	)


func _exhaust_abilities(simulation: CombatSimulation, boss_id: StringName) -> void:
	var state := simulation.get_actor_state(boss_id)
	for ability_id: String in state.ability_daily_remaining.keys():
		state.ability_daily_remaining[ability_id] = 0
	state.resources["ap"] = 0


func _terminalize_attack(simulation: CombatSimulation, start_result: Dictionary) -> void:
	var action := simulation.get_action(String(start_result.get("action_instance_id", "")))
	if action != null:
		simulation.advance_to(action.final_effect_due_at_us)
	var attack := simulation.get_attack(String(start_result.get("attack_instance_id", "")))
	if attack == null:
		return
	if attack.status == CombatAttackInstance.STATUS_PENDING_DEFENSE:
		var defense := simulation.resolve_pending_defense(attack.attack_instance_id, "task35h_terminal_defense")
		if defense.get("status") == CombatDefenseResolution.STATUS_EXHAUSTED:
			simulation.resolve_physical_damage(attack.attack_instance_id, "task35h_terminal_damage")


func _owned_spear_item(simulation: CombatSimulation, boss_id: StringName) -> Dictionary:
	for item: Dictionary in simulation.get_state_snapshot().get("world_items", []):
		if String(item.get("owner_actor_id", "")) == String(boss_id) \
		and String(item.get("equipment_ref", "")) == String(Fixture.WEAPON_REF):
			var copy := item.duplicate(true)
			var serialized: Variant = copy.get("position_microfeet")
			if serialized is Array and serialized.size() == 2:
				copy["position_microfeet"] = Vector2i(int(serialized[0]), int(serialized[1]))
			return copy
	return {}


func _inside_central_wall(position: Vector2i) -> bool:
	return position.x > 28_500_000 and position.x < 31_500_000 \
		and position.y > 7_500_000 and position.y < 20_500_000


func _sealed_test_battlefield() -> ArenaBattlefield:
	var obstacles: Array[Dictionary] = [{
		"id": "sealed_wall",
		"rect_microfeet": Rect2i(20_000_000, 0, 1_000_000, 10_000_000),
		"height_microfeet": 8_000_000,
	}]
	return ArenaBattlefield.new(
		Rect2i(0, 0, 40_000_000, 10_000_000),
		obstacles,
		ArenaBattlefield.DEFAULT_ACTOR_RADIUS_MICROFEET,
		true
	)


func _event_count(simulation: CombatSimulation, event_type: StringName) -> int:
	var count := 0
	for event: CombatEvent in simulation.get_resolved_events():
		if event.event_type == event_type:
			count += 1
	return count


func _expect_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s Expected %s, got %s." % [message, str(expected), str(actual)])
