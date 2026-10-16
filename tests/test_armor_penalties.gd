extends RefCounted

const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
const Digest = preload("res://scripts/sync/sync_state_digest.gd")

var _failures: Array[String] = []


func run() -> Array[String]:
	_failures.clear()
	_test_confirmed_individual_and_stacked_penalties()
	_test_mixed_materials_strength_slots_and_variable_boundary()
	_test_effective_stats_preserve_baselines_and_do_not_accumulate()
	_test_movement_running_and_defense_use_effective_values()
	_test_deterministic_replay_independent_instances_and_guard_regression()
	return _failures


func _test_confirmed_individual_and_stacked_penalties() -> void:
	var catalog := _catalog_with_test_plate_locations()
	_expect_modifiers(catalog, PackedStringArray(["prime_v3_leather_torso"]), 0, 0, 0, "Torso Leather")
	_expect_modifiers(catalog, PackedStringArray(["prime_v3_plate_torso"]), -1, -2, -2, "Torso Plate")
	_expect_modifiers(catalog, PackedStringArray(["task25_plate_head"]), 0, -1, -1, "Head Plate")
	_expect_modifiers(catalog, PackedStringArray(["task25_plate_arms"]), -1, -1, -1, "Arms Plate")
	_expect_modifiers(catalog, PackedStringArray(["task25_plate_legs"]), -1, -2, -2, "Legs Plate")
	_expect_modifiers(
		catalog,
		PackedStringArray(["prime_v3_plate_torso", "task25_plate_head", "task25_plate_arms", "task25_plate_legs"]),
		-3, -6, -6, "Full Plate"
	)


func _test_mixed_materials_strength_slots_and_variable_boundary() -> void:
	var catalog := _catalog_with_test_plate_locations()
	var hard_head := _make_armor(&"task25_hard_head", &"head", 3, 0, 0, 0)
	var chain_arms := _make_armor(&"task25_chain_arms", &"arms", 5, 0, 0, 0)
	var hard_legs := _make_armor(&"task25_hard_legs", &"legs", 10, 0, -1, -1)
	for armor: CombatArmorDefinitionResource in [hard_head, chain_arms, hard_legs]:
		catalog.register_armor(armor)
	_expect_modifiers(
		catalog,
		PackedStringArray(["prime_v3_plate_torso", "task25_hard_head", "task25_chain_arms", "task25_hard_legs"]),
		-1, -3, -3, "Mixed armor"
	)

	var legal := _make_actor(16, PackedStringArray([
		"prime_v3_short_rod", "prime_v3_plate_torso", "task25_plate_head", "task25_plate_arms", "task25_plate_legs",
	]))
	_expect_true(catalog.validate_actor_equipment(legal).get("success", false), "Full Plate must be legal at the highest applicable minimum STR boundary of 16.")
	for boundary: Array in [
		["task25_plate_head", 10], ["task25_plate_arms", 8], ["task25_plate_legs", 16], ["prime_v3_plate_torso", 16],
	]:
		var armor_ref: String = boundary[0]
		var minimum_strength: int = boundary[1]
		var at_boundary := catalog.validate_actor_equipment(_make_actor(minimum_strength, PackedStringArray(["prime_v3_short_rod", armor_ref])))
		var below_boundary := catalog.validate_actor_equipment(_make_actor(minimum_strength - 1, PackedStringArray(["prime_v3_short_rod", armor_ref])))
		_expect_true(at_boundary.get("success", false), "%s must be legal at its exact minimum STR %d." % [armor_ref, minimum_strength])
		_expect_true(not below_boundary.get("success", true) and _has_issue(below_boundary.get("issues", []), "equipment_strength_requirement_not_met"), "%s must fail closed one point below its minimum STR." % armor_ref)

	var duplicate_slot := _make_actor(16, PackedStringArray(["prime_v3_short_rod", "prime_v3_plate_torso", "prime_v3_leather_torso"]))
	var duplicate_result := catalog.validate_actor_equipment(duplicate_slot)
	_expect_true(not duplicate_result.get("success", true) and _has_issue(duplicate_result.get("issues", []), "equipment_slot_conflict"), "Two torso armor definitions must remain an explicit slot conflict.")

	var variable := _make_armor(&"task25_variable_armor", &"head", 2, 0, 0, 0)
	variable.unresolved_penalty_fields = PackedStringArray(["dt"])
	catalog.register_armor(variable)
	var variable_result := catalog.calculate_armor_stat_modifiers(PackedStringArray(["task25_variable_armor"]))
	_expect_true(not variable_result.get("success", true) and variable_result.get("status") == "requires_source_verification", "A V armor penalty must fail closed instead of becoming zero.")


func _test_effective_stats_preserve_baselines_and_do_not_accumulate() -> void:
	var catalog := CombatDefinitionCatalog.load_default_fixture_catalog()
	var result := catalog.instantiate_actor(Fixture.CHARACTER_DEFINITION_ID, Fixture.LOADOUT_DEFINITION_ID, &"task25_guard", "Task 25 Guard")
	_expect_true(result.get("success", false), "The verified Guard loadout must instantiate with its armor penalties.")
	var actor: CombatActorDefinition = result.get("actor")
	_expect_equal(actor.get_base_combat_stat("mr"), 12, "Armor must preserve baseline MR 12.")
	_expect_equal(actor.get_base_combat_stat("dt"), 8, "Armor must preserve baseline DT 8.")
	_expect_equal(actor.get_base_combat_stat("dp"), 6, "Armor must preserve baseline projectile Dodge 6.")
	_expect_equal(actor.equipment_stat_modifiers, {"mr": -1, "dt": -2, "dp": -2}, "Plate torso penalties must be recorded separately from baseline stats.")
	_expect_equal(actor.get_combat_stat("mr"), 11, "Plate torso must reduce effective MR to 11.")
	_expect_equal(actor.get_combat_stat("dt"), 6, "Plate torso must reduce effective DT to 6.")
	_expect_equal(actor.get_combat_stat("dp"), 4, "Plate torso must reduce effective projectile Dodge to 4.")
	actor.apply_equipment_stat_modifiers(actor.equipment_stat_modifiers)
	actor.apply_equipment_stat_modifiers(actor.equipment_stat_modifiers)
	_expect_equal(actor.get_combat_stat("mr"), 11, "Repeated recalculation must derive from baseline and never accumulate MR penalties.")
	_expect_equal(actor.get_combat_stat("dt"), 6, "Repeated recalculation must never accumulate DT penalties.")
	_expect_equal(actor.get_combat_stat("dp"), 4, "Repeated recalculation must never accumulate projectile Dodge penalties.")

	var leather_loadout := CombatLoadoutDefinitionResource.new()
	leather_loadout.definition_id = &"task25_leather_loadout"
	leather_loadout.display_name = "Task 25 Leather Replacement"
	leather_loadout.primary_weapon_ref = &"prime_v3_short_rod"
	leather_loadout.armor_refs = PackedStringArray(["prime_v3_leather_torso"])
	leather_loadout.source_refs = PackedStringArray(["Task 25 replacement test fixture"])
	catalog.register_loadout(leather_loadout)
	var leather_result := catalog.instantiate_actor(Fixture.CHARACTER_DEFINITION_ID, leather_loadout.definition_id, &"task25_leather_guard", "Leather Guard")
	var leather_actor: CombatActorDefinition = leather_result.get("actor")
	_expect_equal(leather_actor.equipment_stat_modifiers, {"mr": 0, "dt": 0, "dp": 0}, "Replacing Plate with Leather in a newly constructed loadout must remove all armor penalties.")
	_expect_equal(leather_actor.get_combat_stat("mr"), 12, "Replacement construction must recalculate from baseline MR, not the prior actor's effective MR.")


func _test_movement_running_and_defense_use_effective_values() -> void:
	var actor := Fixture.make_guard_actor(&"task25_movement_guard", "Task 25 Movement Guard")
	var movement := PrimeMovementModel.new(
		int(actor.get_combat_stat("mr")), int(actor.attributes["spd"]), int(actor.attributes["end"]),
		Fixture.PLAYER_RUNNING_SKILL_INVESTMENT, Fixture.PLAYER_RUNNING_SCM, int(actor.get_combat_stat("rb"))
	)
	var walking_displacement := movement.advance(5_000_000, Vector2.RIGHT)
	_expect_equal(roundi(walking_displacement.x * 1_000_000.0), 11_000_000, "Effective armored MR 11 must allow exactly 11 feet per five seconds.")
	var running := PrimeMovementModel.new(11, 12, 10, 3, 0, 0)
	_expect_equal(running.request_running(), PrimeMovementModel.RunningRequestResult.ACTIVATED, "Existing automatic Running proficiency must remain unchanged.")
	_expect_equal(running.get_effective_mr(), 17, "Running must add the existing SPD-derived +6 bonus to armored walking MR 11.")

	var hand_held: Variant = _resolve_dodge_target(actor, &"hand_held", 25_001)
	_expect_equal(hand_held, 6, "Hand-held Dodge resolution must read effective DT 6 from the authoritative actor definition.")
	var thrown: Variant = _resolve_dodge_target(Fixture.make_guard_actor(&"task25_thrown_guard", "Task 25 Thrown Guard"), &"thrown", 25_002)
	_expect_equal(thrown, 4, "Thrown Dodge resolution must read effective projectile Dodge 4, independently of DT.")


func _test_deterministic_replay_independent_instances_and_guard_regression() -> void:
	var first := Fixture.make_guard_actor(&"task25_replay", "Replay Guard")
	var second := Fixture.make_guard_actor(&"task25_replay", "Replay Guard")
	_expect_equal(first.to_dictionary(), second.to_dictionary(), "Identical source definitions must construct identical effective armor stats.")
	_expect_equal(Digest.compute(first.to_dictionary()), Digest.compute(second.to_dictionary()), "Effective actor construction must remain digest-reproducible.")
	first.apply_equipment_stat_modifiers({"mr": 0, "dt": 0, "dp": 0})
	_expect_equal(second.get_combat_stat("mr"), 11, "Independent actor instances must not share mutable effective-stat dictionaries.")

	var simulations: Array[CombatSimulation] = []
	for _index in range(2):
		var simulation := CombatSimulation.new(25_003)
		var setup := Fixture.configure_simulation(simulation, Vector2i(20_000_000, 12_000_000), Vector2i(23_000_000, 12_000_000))
		_expect_true(setup.get("success", false), "Guard-versus-Guard must initialize after armor penalty activation.")
		var order: Array = setup.get("opening_order", [])
		var attacker_id: StringName = StringName(order[0]["actor_id"])
		var target_id := Fixture.OPPONENT_ID if attacker_id == Fixture.PLAYER_ID else Fixture.PLAYER_ID
		var attack := simulation.start_physical_attack(attacker_id, target_id, Fixture.make_attack_definition(), "task25_guard_attack", &"torso", true)
		_expect_true(attack.get("success", false), "The Guard baseline must still declare its verified Battle Axe attack.")
		simulation.advance_to(2_500_000)
		simulations.append(simulation)
	_expect_equal(simulations[0].get_state_snapshot(), simulations[1].get_state_snapshot(), "Same-seed Guard-versus-Guard authoritative replay must remain identical with armor penalties.")
	_expect_equal(Digest.compute(simulations[0].get_state_snapshot()), Digest.compute(simulations[1].get_state_snapshot()), "Two simulated observers of the same effective actor state must converge on one digest.")

	var harness := TwoClientSyncHarness.new(25_004)
	Fixture.configure_simulation(harness.authority.simulation, Vector2i(20_000_000, 12_000_000), Vector2i(23_000_000, 12_000_000))
	var envelopes: Array = harness.authority.publish_current_events()
	for envelope: CombatEventEnvelope in envelopes:
		harness.client_a.receive(envelope)
	for index in range(envelopes.size() - 1, -1, -1):
		harness.client_b.receive(envelopes[index])
	_expect_true(harness.compare_clients().get("success", false), "In-order and out-of-order clients must converge on the effective armored actor snapshot.")
	_expect_equal(harness.client_a.get_state_digest(), harness.authority.get_state_digest(), "The client digest must match the authoritative armor-adjusted snapshot.")


func _resolve_dodge_target(target: CombatActorDefinition, delivery_class: StringName, seed_value: int) -> Variant:
	var simulation := CombatSimulation.new(seed_value)
	var attacker := CombatActorDefinition.new(
		&"task25_attacker", &"task25_fixture", "Task 25 Attacker",
		{"str": 10, "end": 10, "spd": 10, "dex": 10, "wis": 10, "int": 10, "wit": 10, "man": 10, "luk": 10, "app": 10},
		{"hpm": 20, "acc": 20, "at": 5, "init": 10, "mr": 10, "nal": 0, "dt": 0, "dp": 0, "physical_soak": 0, "rb": 0},
		{}, PackedStringArray(["task25_weapon"])
	)
	simulation.register_actor(attacker)
	simulation.register_actor(target)
	simulation.register_defense_profile(target.actor_id, CombatDefenseProfile.new(
		&"task25_dodge_first",
		PackedStringArray(["dodge", "weapon_block", "shield_block", "physical_soak"])
	))
	simulation.begin_combat()
	var attack_definition := CombatAttackDefinition.new(
		StringName("task25_%s_attack" % String(delivery_class)), &"task25_weapon", 1, true, true, 0,
		{"torso": 0}, PackedStringArray(["torso"]), 0, 5_000_000, true,
		PackedStringArray(["Task 25 defense integration fixture"]), delivery_class, PackedStringArray(["bashing"]), true
	)
	var attack := simulation.start_physical_attack(attacker.actor_id, target.actor_id, attack_definition, "task25_attack", &"torso", true)
	if not attack.get("success", false):
		_failures.append("Task 25 defense integration attack could not start: %s" % String(attack.get("reason", "unknown")))
		return null
	simulation.advance_to(1_000_000)
	var attack_state: CombatAttackInstance = simulation.get_attack(attack["attack_instance_id"])
	if attack_state.status != CombatAttackInstance.STATUS_PENDING_DEFENSE:
		_failures.append("Task 25 defense integration requires a deterministic successful ACC roll.")
		return null
	var context := CombatDodgeContext.new(
		CombatDodgeContext.SELECTION_RESOLVED, Vector2i(1_000_000, 0), 1_000_000,
		false, true, true, "Task 25 authoritative Dodge fixture"
	)
	var result := simulation.resolve_pending_defense(attack_state.attack_instance_id, "task25_defense", context)
	var resolution: CombatDefenseResolution = simulation.get_defense_resolution(result.get("defense_resolution_id", ""))
	return null if resolution == null or resolution.attempts.is_empty() else resolution.attempts[0].base_target


func _catalog_with_test_plate_locations() -> CombatDefinitionCatalog:
	var catalog := CombatDefinitionCatalog.load_default_fixture_catalog()
	catalog.register_armor(_make_armor(&"task25_plate_head", &"head", 10, 0, -1, -1))
	catalog.register_armor(_make_armor(&"task25_plate_arms", &"arms", 8, -1, -1, -1))
	catalog.register_armor(_make_armor(&"task25_plate_legs", &"legs", 16, -1, -2, -2))
	return catalog


func _make_armor(id: StringName, slot: StringName, strength: int, mr: int, dt: int, dp: int) -> CombatArmorDefinitionResource:
	var armor := CombatArmorDefinitionResource.new()
	armor.definition_id = id
	armor.display_name = String(id)
	armor.armor_slot = slot
	armor.covered_locations = PackedStringArray([String(slot)])
	armor.tal_by_damage_type = {}
	armor.strength_requirement = strength
	armor.mr_penalty = mr
	armor.dt_penalty = dt
	armor.projectile_dodge_penalty = dp
	armor.source_refs = PackedStringArray(["Task 25 owner-confirmed Prime V3 Armor Chart penalty row; test-only definition"])
	return armor


func _make_actor(strength: int, equipment: PackedStringArray) -> CombatActorDefinition:
	return CombatActorDefinition.new(
		&"task25_equipment_actor", &"task25_fixture", "Task 25 Equipment Actor",
		{"str": strength, "end": 10, "spd": 10, "dex": 10, "wis": 10, "int": 10, "wit": 10, "man": 10, "luk": 10, "app": 10},
		{"hpm": 20, "acc": 10, "at": 2, "init": 2, "mr": 12, "nal": 0, "dt": 8, "dp": 6, "physical_soak": 0, "rb": 0},
		{}, equipment
	)


func _expect_modifiers(catalog: CombatDefinitionCatalog, equipment: PackedStringArray, mr: int, dt: int, dp: int, label: String) -> void:
	var result := catalog.calculate_armor_stat_modifiers(equipment)
	_expect_true(result.get("success", false), "%s penalty aggregation must resolve." % label)
	_expect_equal(result.get("modifiers"), {"mr": mr, "dt": dt, "dp": dp}, "%s penalties must match the confirmed Armor Chart." % label)


func _has_issue(issues: Array, code: String) -> bool:
	for issue: Dictionary in issues:
		if issue.get("code") == code:
			return true
	return false


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s Expected %s, got %s." % [message, str(expected), str(actual)])


func _expect_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)
