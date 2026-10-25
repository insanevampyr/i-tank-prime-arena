class_name Task35GRareHumanWarriorPotionsAndCombatTests
extends RefCounted

const Fixture = preload("res://scripts/creatures/rare_human_warrior_fixture.gd")

var _failures: Array[String] = []


func run() -> Array[String]:
	_failures.clear()
	_test_source_access_and_fresh_inventory()
	_test_potion_timing_consumption_healing_and_cap()
	_test_potion_invalid_and_interrupted_use()
	_test_combat_specials_and_resources()
	_test_boss_ability_allowance_and_ap_fallback()
	_test_replay_snapshot_and_two_client_convergence()
	return _failures


func _test_source_access_and_fresh_inventory() -> void:
	var catalog := CombatDefinitionCatalog.load_default_fixture_catalog()
	var character: CombatCharacterDefinitionResource = catalog.characters.get(String(Fixture.CHARACTER_DEFINITION_ID))
	_expect_true(character != null, "The source-backed boss character must load.")
	if character == null:
		return
	_expect_equal(character.ability_access.get("activation_mode"), "ability", "Combat 1-3 must use the source Ability-user pathway, not spend Mana or roll SS.")
	_expect_equal(character.ability_access.get("verified_ability_ids"), [
		String(Fixture.CALLED_SHOT_ACTION_ID), String(Fixture.REJUVENATING_MIST_ACTION_ID),
		String(Fixture.RAGE_ACTION_ID), String(Fixture.DEFENSIVE_BUFF_ACTION_ID),
	], "Combat 1-3 must expose exactly the four sequential Prime Combat Specials.")
	var expected_allowances := {
		String(Fixture.CALLED_SHOT_ACTION_ID): 2,
		String(Fixture.REJUVENATING_MIST_ACTION_ID): 3,
		String(Fixture.RAGE_ACTION_ID): 2,
		String(Fixture.DEFENSIVE_BUFF_ACTION_ID): 2,
	}
	var first := _boss_actor(&"task35g_inventory_a")
	var second := _boss_actor(&"task35g_inventory_b")
	if first == null or second == null:
		return
	for ability_id: String in expected_allowances:
		_expect_equal(first.get_ability_daily_maximum(StringName(ability_id)), expected_allowances[ability_id], "Each Combat Special must retain its own printed daily allowance.")
	var first_state := CombatActorState.new(first)
	var second_state := CombatActorState.new(second)
	_expect_equal(first_state.inventory_quantities.get(String(Fixture.HEALTH_POTION_INVENTORY_ID)), 2, "A fresh boss must own exactly two Health Potions.")
	first_state.inventory_quantities[String(Fixture.HEALTH_POTION_INVENTORY_ID)] = 0
	_expect_equal(second_state.inventory_quantities.get(String(Fixture.HEALTH_POTION_INVENTORY_ID)), 2, "Independent boss instances must not share mutable consumable state.")
	_expect_equal(first_state.ability_daily_remaining, expected_allowances, "A fresh actor must initialize every Combat Ability allowance independently.")


func _test_potion_timing_consumption_healing_and_cap() -> void:
	var setup := _boss_simulation(350_701, true)
	var simulation: CombatSimulation = setup["simulation"]
	var actor_id: StringName = setup["actor_id"]
	var state := simulation.get_actor_state(actor_id)
	state.current_hpc = 190
	var started := simulation.start_verified_consumable_healing_action(
		actor_id, Fixture.make_health_potion_action_definition(), "task35g_potion_one"
	)
	_expect_true(started.get("success", false), "A living injured boss with a free hand and potion must begin drinking.")
	var action := simulation.get_action(String(started.get("action_instance_id", "")))
	if action == null:
		return
	_expect_equal(action.final_effect_due_at_us - action.started_at_us, 2_500_000, "One ordinary Act at AT 2 must take exactly 2.5 seconds.")
	_expect_equal(state.inventory_quantities.get(String(Fixture.HEALTH_POTION_INVENTORY_ID)), 2, "The potion must remain available until the drinking Act completes.")
	simulation.advance_to(action.final_effect_due_at_us)
	_expect_equal(state.inventory_quantities.get(String(Fixture.HEALTH_POTION_INVENTORY_ID)), 1, "Successful completion must consume exactly one potion.")
	var events := _events(simulation, &"consumable_healing_resolved", actor_id)
	_expect_equal(events.size(), 1, "A completed potion action must emit exactly one authoritative healing event.")
	if not events.is_empty():
		var payload := events[0].payload
		var rolled := int(payload.get("rolled_healing", 0))
		_expect_true(rolled >= 3 and rolled <= 12, "Health Potion healing must remain within 1d10+2.")
		_expect_equal(payload.get("quantity_before"), 2, "Healing evidence must record the pre-consumption quantity.")
		_expect_equal(payload.get("quantity_after"), 1, "Healing evidence must record the post-consumption quantity.")
		_expect_equal(state.current_hpc, mini(190 + rolled, 200), "Potion healing must cap at the boss HPM 200.")
	state.current_hpc = 199
	var second := simulation.start_verified_consumable_healing_action(
		actor_id, Fixture.make_health_potion_action_definition(), "task35g_potion_two"
	)
	var second_action := simulation.get_action(String(second.get("action_instance_id", "")))
	if second_action != null:
		simulation.advance_to(second_action.final_effect_due_at_us)
	_expect_equal(state.current_hpc, 200, "The second potion must never raise current HPC above 200.")
	_expect_equal(state.inventory_quantities.get(String(Fixture.HEALTH_POTION_INVENTORY_ID)), 0, "Both independently tracked potion uses must be exhaustible.")
	var exhausted := simulation.start_verified_consumable_healing_action(
		actor_id, Fixture.make_health_potion_action_definition(), "task35g_potion_exhausted"
	)
	_expect_equal(exhausted.get("reason"), "consumable_unavailable", "A consumed potion cannot be reused.")


func _test_potion_invalid_and_interrupted_use() -> void:
	var occupied := _boss_simulation(350_702, false)
	var occupied_simulation: CombatSimulation = occupied["simulation"]
	var occupied_id: StringName = occupied["actor_id"]
	var blocked := occupied_simulation.start_verified_consumable_healing_action(
		occupied_id, Fixture.make_health_potion_action_definition(), "task35g_hands_blocked"
	)
	_expect_equal(blocked.get("reason"), "consumable_free_hand_required", "The two-handed spear must prevent potion use while both hands are occupied.")
	var occupied_state := occupied_simulation.get_actor_state(occupied_id)
	_expect_equal(occupied_state.inventory_quantities.get(String(Fixture.HEALTH_POTION_INVENTORY_ID)), 2, "Rejected use must not consume inventory.")
	occupied_state.current_hpc = 0
	var incapacitated := occupied_simulation.start_verified_consumable_healing_action(
		occupied_id, Fixture.make_health_potion_action_definition(), "task35g_incapacitated"
	)
	_expect_equal(incapacitated.get("reason"), "actor_not_eligible", "An incapacitated actor cannot begin drinking a potion.")

	var interrupted := _boss_simulation(350_703, true)
	var simulation: CombatSimulation = interrupted["simulation"]
	var actor_id: StringName = interrupted["actor_id"]
	var state := simulation.get_actor_state(actor_id)
	state.current_hpc = 150
	var draws_before := simulation.random.get_draw_count()
	var started := simulation.start_verified_consumable_healing_action(
		actor_id, Fixture.make_health_potion_action_definition(), "task35g_interrupted"
	)
	var duplicate := simulation.start_verified_consumable_healing_action(
		actor_id, Fixture.make_health_potion_action_definition(), "task35g_competing"
	)
	_expect_equal(duplicate.get("reason"), "actor_action_in_progress", "A second ordinary action cannot overlap the potion Act.")
	var action := simulation.get_action(String(started.get("action_instance_id", "")))
	if action == null:
		return
	_expect_true(simulation.schedule_interruption(action.action_instance_id, action.started_at_us + 1_000_000, actor_id, "test_interrupt").get("success", false), "The drinking Act must use ordinary interruptible action scheduling.")
	simulation.advance_to(action.final_effect_due_at_us)
	_expect_equal(state.inventory_quantities.get(String(Fixture.HEALTH_POTION_INVENTORY_ID)), 2, "An interrupted, incomplete drink must not consume a potion.")
	_expect_equal(state.current_hpc, 150, "An interrupted drink must not heal.")
	_expect_equal(simulation.random.get_draw_count(), draws_before, "Interrupted potion use must consume no healing RNG.")
	_expect_true(_events(simulation, &"consumable_healing_resolved", actor_id).is_empty(), "Interrupted use must produce no healing resolution.")


func _test_combat_specials_and_resources() -> void:
	var called_setup := _boss_and_target_simulation(350_704)
	var called_simulation: CombatSimulation = called_setup["simulation"]
	var actor_id: StringName = called_setup["actor_id"]
	var called_state := called_simulation.get_actor_state(actor_id)
	var mana_before := int(called_state.resources.get("mana", -1))
	var draws_before := called_simulation.random.get_draw_count()
	var called := called_simulation.start_verified_special_action(
		actor_id, &"target", Fixture.make_called_shot_action_definition(), "task35g_called", &"head", true
	)
	var called_action := called_simulation.get_action(String(called.get("action_instance_id", "")))
	_expect_true(called.get("success", false) and called_action != null, "Combat 1 Called Shot must start through the shared Ability pathway.")
	if called_action != null:
		_expect_equal(called_action.final_effect_due_at_us - called_action.started_at_us, 2_500_000, "Called Shot preparation must cost one Act at AT 2.")
		called_simulation.advance_to(called_action.final_effect_due_at_us)
	_expect_equal(called_state.pending_called_shot.get("target_location"), "head", "Called Shot must lock the selected location for the following Act.")
	_expect_equal(called_state.ability_daily_remaining.get(String(Fixture.CALLED_SHOT_ACTION_ID)), 1, "Called Shot must consume one of its two independent daily uses.")
	_expect_equal(called_state.resources.get("mana"), mana_before, "Ability-mode Combat Specials must not spend Mana.")
	_expect_equal(called_simulation.random.get_draw_count(), draws_before, "Ability activation must not make an SS roll.")

	var mist_setup := _boss_simulation(350_705, true)
	var mist_simulation: CombatSimulation = mist_setup["simulation"]
	var mist_id: StringName = mist_setup["actor_id"]
	var mist_state := mist_simulation.get_actor_state(mist_id)
	mist_state.current_hpc = 180
	var mist := mist_simulation.start_verified_special_action(
		mist_id, mist_id, Fixture.make_rejuvenating_mist_action_definition(), "task35g_mist"
	)
	var mist_action := mist_simulation.get_action(String(mist.get("action_instance_id", "")))
	if mist_action != null:
		mist_simulation.advance_to(mist_action.final_effect_due_at_us)
	_expect_true(int(mist_state.current_hpc) > 180 and int(mist_state.current_hpc) <= 194, "Combat 2 Rejuvenating Mist must heal deterministic 2d6+2 HPC.")
	_expect_equal(mist_state.ability_daily_remaining.get(String(Fixture.REJUVENATING_MIST_ACTION_ID)), 2, "Mist must consume one of its three daily uses.")

	var rage_setup := _boss_simulation(350_706, true)
	var rage_simulation: CombatSimulation = rage_setup["simulation"]
	var rage_id: StringName = rage_setup["actor_id"]
	var rage_state := rage_simulation.get_actor_state(rage_id)
	var rage := rage_simulation.start_verified_timed_stat_effect_action(
		rage_id, Fixture.make_rage_action_definition(), "task35g_rage"
	)
	var rage_action := rage_simulation.get_action(String(rage.get("action_instance_id", "")))
	if rage_action != null:
		_expect_equal(rage_action.final_effect_due_at_us - rage_action.started_at_us, 5_000_000, "Combat 3 Rage must require two Acts at AT 2.")
		rage_simulation.advance_to(rage_action.final_effect_due_at_us)
	_expect_equal(rage_simulation.get_effective_actor_combat_stat(rage_id, "sb"), 6, "Rage must add +2 to the boss's source SB 4.")
	_expect_equal(rage_simulation.get_effective_actor_combat_stat(rage_id, "nal"), -1, "Rage must apply -2 to racial NAL +1 without inventing a floor.")
	_expect_equal(rage_simulation.get_effective_actor_combat_stat(rage_id, "dt"), 7, "Rage must apply -1 after the boss's authoritative armor-adjusted DT 8.")
	_expect_equal(rage_simulation.get_effective_actor_combat_stat(rage_id, "dp"), 1, "Rage must apply -1 after the boss's authoritative armor-adjusted DP 2.")
	_expect_equal(rage_state.ability_daily_remaining.get(String(Fixture.RAGE_ACTION_ID)), 1, "Rage must consume one of its two daily uses.")

	var buff_setup := _boss_simulation(350_707, true)
	var buff_simulation: CombatSimulation = buff_setup["simulation"]
	var buff_id: StringName = buff_setup["actor_id"]
	var buff_state := buff_simulation.get_actor_state(buff_id)
	buff_simulation.set_gatherable_material_resolver(func(_actor: StringName, material: StringName, surface: String) -> bool:
		return material == &"dirt" and surface == "authored_dirt"
	)
	var gather := buff_simulation.start_gather_material_action(buff_id, &"dirt", "authored_dirt", "task35g_gather")
	var gather_action := buff_simulation.get_action(String(gather.get("action_instance_id", "")))
	if gather_action != null:
		buff_simulation.advance_to(gather_action.final_effect_due_at_us)
	var buff := buff_simulation.start_verified_special_action(
		buff_id, buff_id, Fixture.make_defensive_buff_action_definition(), "task35g_buff"
	)
	var buff_action := buff_simulation.get_action(String(buff.get("action_instance_id", "")))
	if buff_action != null:
		_expect_equal(buff_action.final_effect_due_at_us - buff_action.started_at_us, 5_000_000, "Defensive Buff must require two Acts at AT 2.")
		buff_simulation.advance_to(buff_action.final_effect_due_at_us)
	_expect_equal(buff_simulation.get_effective_actor_combat_stat(buff_id, "nal"), 3, "Defensive Buff must add +2 NAL to racial NAL +1.")
	_expect_true(buff_state.held_materials.is_empty(), "Successful Defensive Buff must consume its held dirt.")
	_expect_equal(buff_state.ability_daily_remaining.get(String(Fixture.DEFENSIVE_BUFF_ACTION_ID)), 1, "Defensive Buff must consume one of its two daily uses.")
	var duplicate_buff := buff_simulation.start_verified_special_action(
		buff_id, buff_id, Fixture.make_defensive_buff_action_definition(), "task35g_buff_duplicate"
	)
	_expect_equal(duplicate_buff.get("reason"), "timed_stat_effect_already_active", "The nonstacking Defensive Buff must reject duplicate activation.")


func _test_replay_snapshot_and_two_client_convergence() -> void:
	var first := _potion_transaction(350_708)
	var replay := _potion_transaction(350_708)
	_expect_equal(replay.get("events"), first.get("events"), "Same-seed potion event history must replay exactly.")
	_expect_equal(replay.get("snapshot"), first.get("snapshot"), "Same-seed inventory, HPC and RNG snapshots must replay exactly.")
	var snapshot: Dictionary = first.get("snapshot", {})
	_expect_equal(snapshot.get("schema_version"), 12, "Authoritative snapshots must identify the inventory-state schema extension.")
	var actors: Array = snapshot.get("actors", [])
	if not actors.is_empty():
		_expect_equal(actors[0].get("state", {}).get("inventory_quantities", {}).get(String(Fixture.HEALTH_POTION_INVENTORY_ID)), 1, "The snapshot must preserve the remaining potion count.")
	var harness: TwoClientSyncHarness = first.get("harness")
	_expect_true(harness != null and harness.compare_clients().get("success", false), "Potion state and events must converge on two simulated clients.")
	if harness != null:
		_expect_equal(harness.client_a.get_state_digest(), harness.authority.get_state_digest(), "Client A must match the authoritative potion digest.")
		_expect_equal(harness.client_b.get_state_digest(), harness.authority.get_state_digest(), "Client B must match the authoritative potion digest.")


func _test_boss_ability_allowance_and_ap_fallback() -> void:
	var setup := _boss_and_target_simulation(350_709)
	var simulation: CombatSimulation = setup["simulation"]
	var actor_id: StringName = setup["actor_id"]
	var state := simulation.get_actor_state(actor_id)
	for index in range(3):
		var result := simulation.start_verified_special_action(
			actor_id, &"target", Fixture.make_called_shot_action_definition(),
			"task35g_called_payment_%s" % index, &"torso", true
		)
		_expect_true(result.get("success", false), "Each legal Called Shot activation must reach the shared Ability-payment boundary.")
		var action := simulation.get_action(String(result.get("action_instance_id", "")))
		if action != null:
			simulation.advance_to(action.final_effect_due_at_us)
		state.pending_called_shot.clear()
	_expect_equal(state.ability_daily_remaining.get(String(Fixture.CALLED_SHOT_ACTION_ID)), 0, "Two free Called Shot uses must be consumed before AP fallback.")
	_expect_equal(state.resources.get("ap"), 11, "The third Called Shot activation must spend exactly one of the boss's 12 shared AP.")
	_expect_equal(state.resources.get("mana"), 24, "Ability AP fallback must still leave the boss's Mana unchanged.")
	state.resources["ap"] = 0
	var rejected := simulation.start_verified_special_action(
		actor_id, &"target", Fixture.make_called_shot_action_definition(),
		"task35g_called_exhausted", &"torso", true
	)
	_expect_equal(rejected.get("reason"), "insufficient_ability_resources", "Exhausted daily uses and AP must fail closed without starting an action.")


func _potion_transaction(seed_value: int) -> Dictionary:
	var harness := TwoClientSyncHarness.new(seed_value)
	var simulation := harness.authority.simulation
	var actor := _boss_actor(&"task35g_replay_boss")
	if actor == null:
		return {}
	simulation.register_actor(actor)
	simulation.configure_actor_hand_occupancy(actor.actor_id, {})
	simulation.begin_combat()
	var state := simulation.get_actor_state(actor.actor_id)
	state.current_hpc = 175
	var result := simulation.start_verified_consumable_healing_action(
		actor.actor_id, Fixture.make_health_potion_action_definition(), "task35g_replay_potion"
	)
	var action := simulation.get_action(String(result.get("action_instance_id", "")))
	if action != null:
		var envelopes := harness.authority.publish_due_events(action.final_effect_due_at_us)
		harness.deliver_in_order(envelopes)
	var events: Array = []
	for entry: Dictionary in harness.authority.get_published_transcript():
		events.append(entry.duplicate(true))
	return {"events": events, "snapshot": simulation.get_state_snapshot(), "harness": harness}


func _boss_simulation(seed_value: int, free_hands: bool) -> Dictionary:
	var simulation := CombatSimulation.new(seed_value)
	var actor := _boss_actor(StringName("task35g_boss_%s" % seed_value))
	_expect_true(actor != null, "The boss fixture must instantiate.")
	if actor == null:
		return {"simulation": simulation, "actor_id": &""}
	_expect_true(simulation.register_actor(actor).get("success", false), "The boss fixture must register.")
	var hands := {} if free_hands else {"left": String(Fixture.WEAPON_REF), "right": String(Fixture.WEAPON_REF)}
	_expect_true(simulation.configure_actor_hand_occupancy(actor.actor_id, hands).get("success", false), "Boss hand occupancy must be authoritative.")
	_expect_true(simulation.begin_combat().get("success", false), "The isolated boss fixture must begin combat.")
	return {"simulation": simulation, "actor_id": actor.actor_id}


func _boss_and_target_simulation(seed_value: int) -> Dictionary:
	var simulation := CombatSimulation.new(seed_value)
	var actor := _boss_actor(&"task35g_special_boss")
	var target := _target_actor()
	if actor == null:
		return {"simulation": simulation, "actor_id": &""}
	simulation.register_actor(actor)
	simulation.register_actor(target)
	simulation.configure_actor_hand_occupancy(actor.actor_id, {})
	simulation.set_special_touch_resolver(func(_actor: StringName, _target: StringName) -> bool: return true)
	simulation.begin_combat()
	return {"simulation": simulation, "actor_id": actor.actor_id}


func _boss_actor(actor_id: StringName) -> CombatActorDefinition:
	var result := Fixture.instantiate_foundation_actor(actor_id, "Task 35G Boss")
	return result.get("actor") as CombatActorDefinition


func _target_actor() -> CombatActorDefinition:
	return CombatActorDefinition.new(
		&"target", &"task35g_target", "Target",
		{"str": 10, "end": 10, "spd": 10, "dex": 10, "wis": 10, "int": 10, "wit": 10, "man": 10, "luk": 10, "app": 10},
		{"hpm": 50, "acc": 10, "at": 1, "init": 1, "mr": 10, "nal": 0, "dt": 1, "dp": 1, "physical_soak": 0},
		{}, PackedStringArray(), {}, {}, PackedStringArray(), &"medium"
	)


func _events(simulation: CombatSimulation, event_type: StringName, source_id: StringName) -> Array[CombatEvent]:
	var matches: Array[CombatEvent] = []
	for event: CombatEvent in simulation.get_resolved_events():
		if event.event_type == event_type and event.source_actor_id == source_id:
			matches.append(event)
	return matches


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s Expected %s, got %s." % [message, str(expected), str(actual)])


func _expect_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
