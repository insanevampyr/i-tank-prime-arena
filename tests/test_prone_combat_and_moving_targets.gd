extends RefCounted

const MICROFEET_PER_FOOT := 1_000_000

var _failures: Array[String] = []
var _final_los_allowed: Variant = true


func run() -> Array[String]:
	_test_final_range_and_line_of_sight_revalidation()
	_test_prone_crawl_and_running_boundary()
	_test_prone_damage_floor_once_and_prime_acc_boundary()
	_test_prone_defense_eligibility()
	_test_task17_replay_and_two_client_convergence()
	return _failures


func _test_final_range_and_line_of_sight_revalidation() -> void:
	var out_of_range := _make_attack_simulation(1_201, 5_000_000)
	var range_attack := out_of_range.start_physical_attack(&"attacker", &"target", _attack(&"range_final", 5_000_000), "range_final", &"torso", true)
	var draws_before_resolution := out_of_range.random.get_draw_count()
	out_of_range.apply_authoritative_position(&"target", Vector2i(6_000_000, 0), 0)
	out_of_range.advance_to(1_000_000)
	var resolved_range: CombatAttackInstance = out_of_range.get_attack(range_attack["attack_instance_id"])
	_expect_equal(resolved_range.status, CombatAttackInstance.STATUS_FINAL_LEGALITY_FAILED, "A target outside weapon range at the final effect must not connect.")
	_expect_equal(resolved_range.final_legality_reason, "target_out_of_range_at_resolution", "Final range failure must have an explicit deterministic reason.")
	_expect_equal(resolved_range.natural_roll, null, "ACC must not roll after final range validation fails.")
	_expect_equal(out_of_range.random.get_draw_count(), draws_before_resolution, "Failed final legality must consume no ACC randomness.")
	_expect_equal(out_of_range.clock.get_elapsed_us(), 1_000_000, "Final-legality failure must not refund the elapsed AT interval.")

	var blocked_los := _make_attack_simulation(1_202, 5_000_000)
	_final_los_allowed = true
	blocked_los.set_attack_final_line_of_sight_resolver(_resolve_test_line_of_sight)
	var blocked_attack := blocked_los.start_physical_attack(&"attacker", &"target", _attack(&"los_final", 5_000_000), "los_final", &"torso", true)
	_final_los_allowed = false
	var blocked_draws := blocked_los.random.get_draw_count()
	blocked_los.advance_to(1_000_000)
	var resolved_blocked: CombatAttackInstance = blocked_los.get_attack(blocked_attack["attack_instance_id"])
	_expect_equal(resolved_blocked.final_legality_reason, "line_of_sight_blocked_at_resolution", "An obstruction present at the final effect must prevent connection.")
	_expect_equal(resolved_blocked.natural_roll, null, "Blocked final line of sight must prevent the ACC roll.")
	_expect_equal(blocked_los.random.get_draw_count(), blocked_draws, "Blocked final line of sight must not consume ACC randomness.")

	var returned := _make_attack_simulation(1_203, 5_000_000)
	_final_los_allowed = true
	returned.set_attack_final_line_of_sight_resolver(_resolve_test_line_of_sight)
	var returned_attack := returned.start_physical_attack(&"attacker", &"target", _attack(&"returned_final", 5_000_000), "returned_final", &"torso", true)
	returned.apply_authoritative_position(&"target", Vector2i(6_000_000, 0), 0)
	_final_los_allowed = false
	returned.apply_authoritative_position(&"target", Vector2i(5_000_000, 0), 0)
	_final_los_allowed = true
	returned.advance_to(1_000_000)
	var resolved_returned: CombatAttackInstance = returned.get_attack(returned_attack["attack_instance_id"])
	_expect_true(resolved_returned.natural_roll != null, "Temporary range/obstruction changes must not cancel an attack that is legal again at its final effect.")
	_expect_true(resolved_returned.status != CombatAttackInstance.STATUS_FINAL_LEGALITY_FAILED, "Only declaration and final-effect legality are authoritative for this approved timing rule.")


func _test_prone_crawl_and_running_boundary() -> void:
	var movement := PrimeMovementModel.new(12, 12, 10, 3, 0, 0, DeterministicCombatRng.new(1_204))
	movement.set_prone(true)
	_expect_equal(movement.get_effective_movement_allowance_microfeet(), 3_000_000, "Prone crawling must be exactly 25% of 12 walking MR without whole-MR rounding.")
	_expect_equal(movement.request_running(), PrimeMovementModel.RunningRequestResult.PRONE, "Running must be prohibited while prone.")
	var displacement := movement.advance(5_000_000, Vector2.RIGHT)
	_expect_true(is_equal_approx(displacement.x, 3.0), "Five seconds of prone crawl at 12 MR must travel exactly three feet.")

	var session := ArenaCombatSession.new(1_205)
	session.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
	_expect_true(session.initialize(Vector2i(20_000_000, 7_000_000), Vector2i(23_000_000, 7_000_000))["success"], "Prone crawl fixture must initialize.")
	session.simulation.set_actor_defense_state(PrimeV3VerticalSliceFixture.PLAYER_ID, &"aware", PackedStringArray(["prone"]))
	var crawl := session.request_player_movement(Vector2i(20_000_000, 12_000_000), 12)
	_expect_equal(crawl["movement_cost_microfeet"], 3_000_000, "Authoritative prone movement must cap a five-foot request at exactly three feet.")
	_expect_equal(crawl["position_microfeet"], Vector2i(20_000_000, 10_000_000), "Prone crawl must keep the rendered/simulation endpoint on the exact authoritative cap.")
	var modified_session := ArenaCombatSession.new(1_214)
	modified_session.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
	modified_session.initialize(Vector2i(20_000_000, 7_000_000), Vector2i(23_000_000, 7_000_000))
	modified_session.simulation.set_actor_defense_state(PrimeV3VerticalSliceFixture.PLAYER_ID, &"aware", PackedStringArray(["prone"]))
	var modified_crawl := modified_session.request_player_movement(Vector2i(20_000_000, 10_000_000), 10)
	_expect_equal(modified_crawl["movement_cost_microfeet"], 2_500_000, "Prone crawl must quarter effective walking MR and retain fractional feet without whole-MR rounding.")

	var collision := ArenaCombatSession.new(1_206)
	collision.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
	collision.initialize(Vector2i(29_000_000, 7_000_000), Vector2i(23_000_000, 7_000_000))
	collision.simulation.set_actor_defense_state(PrimeV3VerticalSliceFixture.PLAYER_ID, &"aware", PackedStringArray(["prone"]))
	var blocked := collision.request_player_movement(Vector2i(29_000_000, 12_000_000), 12)
	_expect_true(blocked["blocked"], "Prone crawling must use the same wall collision boundary as standing movement.")
	_expect_true(int(blocked["position_microfeet"].y) <= 7_500_000, "A crawling actor must not clip through the center wall.")

	var keyboard := ArenaCombatSession.new(1_207)
	var touch := ArenaCombatSession.new(1_207)
	for candidate: ArenaCombatSession in [keyboard, touch]:
		candidate.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
		candidate.initialize(Vector2i(20_000_000, 7_000_000), Vector2i(23_000_000, 7_000_000))
		candidate.simulation.set_actor_defense_state(PrimeV3VerticalSliceFixture.PLAYER_ID, &"aware", PackedStringArray(["prone"]))
	keyboard.request_player_movement(Vector2i(20_000_000, 9_000_000), 12)
	touch.request_player_movement(Vector2i(20_000_000, 9_000_000), 12)
	_expect_equal(keyboard.get_state_snapshot(), touch.get_state_snapshot(), "Desktop and touch intents must converge through the same prone movement authority.")


func _test_prone_damage_floor_once_and_prime_acc_boundary() -> void:
	var seed_value := _find_seed_for_rolls(5, 5)
	var simulation := CombatSimulation.new(seed_value)
	_configure_attack_simulation(simulation, 5_000_000, true)
	simulation.register_defense_profile(&"target", _defense_profile(&"damage_defenses", &"dodge", 0))
	simulation.register_damage_protection_profile(&"target", CombatDamageProtectionProfile.new(&"no_armor", [], {}, PackedStringArray(["TASK17 TEST FIXTURE"])))
	simulation.set_actor_defense_state(&"target", &"unaware", PackedStringArray(["prone", "surprised"]))
	simulation.begin_combat()
	var definition := _damage_attack(&"prone_damage", &"head")
	var started := simulation.start_physical_attack(&"attacker", &"target", definition, "prone_damage", &"head", true)
	simulation.advance_to(1_000_000)
	var attack: CombatAttackInstance = simulation.get_attack(started["attack_instance_id"])
	attack.consequence_damage_multipliers.append({"kind": "approved_critical_x2_fixture", "numerator": 2, "denominator": 1, "source_ref": "TASK17 TEST FIXTURE"})
	var defense := simulation.resolve_pending_defense(attack.attack_instance_id, "prone_damage_defense")
	_expect_equal(defense.get("status"), CombatDefenseResolution.STATUS_EXHAUSTED, "Surprise must preserve the existing active-defense restriction before prone damage.")
	var damage_result := simulation.resolve_physical_damage(attack.attack_instance_id, "prone_damage_resolution")
	var resolution: CombatDamageResolution = simulation.get_damage_resolution(damage_result["damage_resolution_id"])
	_expect_equal(resolution.weapon_dice_total, 5, "Prone multiplier fixture must retain its deterministic weapon roll.")
	_expect_equal(resolution.combined_multiplier_numerator, 9, "Head x1.5, approved critical x2 and prone x1.5 must combine as exact 9/2.")
	_expect_equal(resolution.combined_multiplier_denominator, 2, "Combined prone damage factors must retain an exact denominator until one floor.")
	_expect_equal(resolution.multiplied_total, 22, "Five damage times 9/2 must floor once to 22, not round between multipliers.")
	_expect_equal(_multiplier_kind_count(resolution.applied_multipliers, "arena_prone_target"), 1, "The prone damage multiplier must be recorded and applied exactly once.")

	var acc_only := _make_attack_simulation(1_208, 5_000_000)
	acc_only.set_actor_defense_state(&"target", &"aware", PackedStringArray(["prone"]))
	var acc_started := acc_only.start_physical_attack(&"attacker", &"target", _attack(&"prone_acc", 5_000_000), "prone_acc", &"torso", true)
	var acc_attack: CombatAttackInstance = acc_only.get_attack(acc_started["attack_instance_id"])
	_expect_equal(acc_attack.location_acc_modifier, 0, "Prime V3 pp. 95-98 gives same-size torso location 3 no ACC change; prone posture adds no invented blanket modifier.")
	_expect_equal(acc_attack.acc_target, 20, "Prone posture must not double-count an unsupported ACC adjustment.")


func _test_prone_defense_eligibility() -> void:
	var legal_dodge := _make_defense_simulation(1_209, &"dodge", PackedStringArray(["prone"]))
	var dodge_attack: CombatAttackInstance = legal_dodge["attack"]
	var legal_context := CombatDodgeContext.new(
		CombatDodgeContext.SELECTION_RESOLVED, Vector2i(6_000_000, 0), 1_000_000, false,
		true, true, "TASK17 legal prone Dodge fixture", &"one_foot", &"fixture", true, true, true, 0
	)
	var legal_result := (legal_dodge["simulation"] as CombatSimulation).resolve_pending_defense(dodge_attack.attack_instance_id, "legal_prone_dodge", legal_context)
	_expect_true(legal_result.get("success", false), "A one-foot prone Dodge fixture must resolve: %s" % legal_result.get("reason", "unknown"))
	var legal_resolution: CombatDefenseResolution = (legal_dodge["simulation"] as CombatSimulation).get_defense_resolution(legal_result.get("defense_resolution_id", ""))
	if legal_resolution == null:
		return
	_expect_equal(legal_resolution.attempts[0].eligibility, CombatDefenseAttempt.ATTEMPTED, "Prone Dodge remains legal when its maneuver fits the 25%-MR posture limit and all normal prerequisites.")

	var illegal_dodge := _make_defense_simulation(1_210, &"dodge", PackedStringArray(["prone"]))
	var illegal_attack: CombatAttackInstance = illegal_dodge["attack"]
	var illegal_context := CombatDodgeContext.new(
		CombatDodgeContext.SELECTION_RESOLVED, Vector2i(7_000_000, 0), 2_000_000, false,
		true, true, "TASK17 excessive prone Dodge fixture", &"two_feet", &"fixture", true, true, true, 0
	)
	var illegal_result := (illegal_dodge["simulation"] as CombatSimulation).resolve_pending_defense(illegal_attack.attack_instance_id, "illegal_prone_dodge", illegal_context)
	_expect_true(illegal_result.get("success", false), "An excessive prone Dodge must resolve as an ineligible attempt: %s" % illegal_result.get("reason", "unknown"))
	var illegal_resolution: CombatDefenseResolution = (illegal_dodge["simulation"] as CombatSimulation).get_defense_resolution(illegal_result.get("defense_resolution_id", ""))
	if illegal_resolution == null:
		return
	_expect_equal(illegal_resolution.attempts[0].eligibility_reason, "dodge_exceeds_half_mr", "Prone Dodge must reject displacement beyond half of the approved crawl MR.")

	for defense_type: StringName in [&"weapon_block", &"shield_block", &"physical_soak"]:
		var fixture := _make_defense_simulation(1_211, defense_type, PackedStringArray(["prone", "held"]))
		var fixture_attack: CombatAttackInstance = fixture["attack"]
		var result := (fixture["simulation"] as CombatSimulation).resolve_pending_defense(fixture_attack.attack_instance_id, "prone_%s" % String(defense_type))
		var resolution: CombatDefenseResolution = (fixture["simulation"] as CombatSimulation).get_defense_resolution(result["defense_resolution_id"])
		_expect_equal(resolution.attempts[0].eligibility, CombatDefenseAttempt.ATTEMPTED, "%s must remain eligible while prone when its ordinary prerequisites are satisfied." % String(defense_type))


func _test_task17_replay_and_two_client_convergence() -> void:
	var first := _resolved_out_of_range_fixture(1_212)
	var second := _resolved_out_of_range_fixture(1_212)
	_expect_equal(first.get_state_snapshot(), second.get_state_snapshot(), "Moving-target final legality must replay to an identical authoritative state.")

	var harness := TwoClientSyncHarness.new(1_213)
	var authority := harness.authority.simulation
	_configure_attack_simulation(authority, 5_000_000)
	authority.begin_combat()
	authority.start_physical_attack(&"attacker", &"target", _attack(&"sync_final_legality", 5_000_000), "sync_final_legality", &"torso", true)
	authority.apply_authoritative_position(&"target", Vector2i(6_000_000, 0), 0)
	var envelopes := harness.authority.publish_due_events(1_000_000)
	for envelope: CombatEventEnvelope in envelopes:
		harness.client_a.receive(envelope)
	for index in range(envelopes.size() - 1, -1, -1):
		harness.client_b.receive(envelopes[index])
	_expect_true(harness.compare_clients()["success"], "Both clients must converge on the authoritative no-ACC final-legality result.")
	_expect_equal(harness.client_a.get_state_digest(), harness.authority.get_state_digest(), "The Task 17 final-legality snapshot must be digest-stable.")


func _make_attack_simulation(seed_value: int, range_microfeet: int, damage_ready: bool = false) -> CombatSimulation:
	var simulation := CombatSimulation.new(seed_value)
	_configure_attack_simulation(simulation, range_microfeet, damage_ready)
	simulation.begin_combat()
	return simulation


func _configure_attack_simulation(simulation: CombatSimulation, range_microfeet: int, _damage_ready: bool = false) -> void:
	simulation.register_actor(_actor(&"attacker", 100, PackedStringArray(["weapon", "shield"])))
	simulation.register_actor(_actor(&"target", 0, PackedStringArray(["weapon", "shield"])))
	simulation.apply_authoritative_position(&"attacker", Vector2i.ZERO, 0)
	simulation.apply_authoritative_position(&"target", Vector2i(range_microfeet, 0), 180_000)


func _make_defense_simulation(seed_value: int, first_defense: StringName, conditions: PackedStringArray) -> Dictionary:
	var actual_seed := _find_seed_for_defense_rolls(5, 5, seed_value)
	var simulation := CombatSimulation.new(actual_seed)
	_configure_attack_simulation(simulation, 5_000_000)
	simulation.register_defense_profile(&"target", _defense_profile(StringName("profile_%s" % String(first_defense)), first_defense, 20))
	simulation.set_actor_defense_state(&"target", &"aware", conditions)
	simulation.begin_combat()
	var started := simulation.start_physical_attack(&"attacker", &"target", _attack(StringName("attack_%s" % String(first_defense)), 5_000_000), "attack_%s" % String(first_defense), &"torso", true)
	simulation.advance_to(1_000_000)
	return {"simulation": simulation, "attack": simulation.get_attack(started["attack_instance_id"])}


func _defense_profile(profile_id: StringName, first_defense: StringName, target_value: int) -> CombatDefenseProfile:
	var order: Array[String] = [String(first_defense)]
	for defense_name: String in ["dodge", "weapon_block", "shield_block", "physical_soak"]:
		if not order.has(defense_name):
			order.append(defense_name)
	var weapon_block := CombatBlockDefinition.new(&"weapon_block", &"weapon", target_value, 0, true, true, null, PackedStringArray(["TASK17 TEST FIXTURE"]))
	var shield_block := CombatBlockDefinition.new(&"shield_block", &"shield", target_value, 0, true, true, 10, PackedStringArray(["TASK17 TEST FIXTURE"]), true)
	return CombatDefenseProfile.new(profile_id, PackedStringArray(order), {}, weapon_block, shield_block, PackedStringArray(["TASK17 TEST FIXTURE"]))


func _actor(actor_id: StringName, init_value: int, equipment: PackedStringArray) -> CombatActorDefinition:
	return CombatActorDefinition.new(
		actor_id, &"task17_fixture", String(actor_id),
		{"str": 10, "end": 10, "spd": 12, "dex": 20, "wis": 10, "int": 10, "wit": 10, "man": 10, "luk": 0, "app": 10},
		{"hpm": 100, "acc": 20, "at": 5, "init": init_value, "mr": 12, "nal": 0, "dt": 20, "dp": 20, "physical_soak": 20, "rb": 0, "sb": 0},
		{}, equipment,
		{"dodge": true, "weapon_block": true, "shield_block": true, "physical_soak": true},
		{"task17": "PRIME-V3 and approved Arena Task 17 fixtures"}, PackedStringArray()
	)


func _attack(attack_id: StringName, maximum_range_microfeet: int) -> CombatAttackDefinition:
	return CombatAttackDefinition.new(
		attack_id, &"weapon", 1, true, true, 0, {"torso": 0}, PackedStringArray(["torso"]),
		0, maximum_range_microfeet, true,
		PackedStringArray(["PRIME-V3 pp. 95-98: same-size torso hit location 3 = No Change", "ARENA-TASK-17 final legality timing"]),
		&"hand_held", PackedStringArray(["bashing"]), true
	)


func _damage_attack(attack_id: StringName, target_location: StringName) -> CombatAttackDefinition:
	var damage := CombatPhysicalDamageDefinition.new(
		1, 6, 0, false, true,
		{
			"torso": {"numerator": 1, "denominator": 1, "source_ref": "PRIME-V3 pp. 95-98"},
			"head": {"numerator": 3, "denominator": 2, "source_ref": "PRIME-V3 p. 119"},
		},
		null, true, CombatPhysicalDamageDefinition.ROUNDING_FLOOR,
		PackedStringArray(["TASK17 exact multiplier fixture"])
	)
	return CombatAttackDefinition.new(
		attack_id, &"weapon", 1, true, true, 0, {"torso": 0, "head": -3}, PackedStringArray(["torso", "head"]),
		0, 5_000_000, true, PackedStringArray(["TASK17 TEST FIXTURE"]), &"hand_held", PackedStringArray(["bashing"]), true,
		CombatAttackDefinition.DUCKING_PROHIBITED, damage
	)


func _resolved_out_of_range_fixture(seed_value: int) -> CombatSimulation:
	var simulation := _make_attack_simulation(seed_value, 5_000_000)
	simulation.start_physical_attack(&"attacker", &"target", _attack(&"replay_final_legality", 5_000_000), "replay_final_legality", &"torso", true)
	simulation.apply_authoritative_position(&"target", Vector2i(6_000_000, 0), 0)
	simulation.advance_to(1_000_000)
	return simulation


func _resolve_test_line_of_sight(_attacker_id: StringName, _target_id: StringName) -> Variant:
	return _final_los_allowed


func _multiplier_kind_count(entries: Array, kind: String) -> int:
	var count := 0
	for entry: Dictionary in entries:
		if String(entry.get("kind", "")) == kind:
			count += 1
	return count


func _find_seed_for_rolls(acc_roll: int, damage_roll: int) -> int:
	for seed_value in range(1, 500_000):
		var preview := DeterministicCombatRng.new(seed_value)
		preview.next_int(1, 10)
		preview.next_int(1, 10)
		if preview.next_int(1, 20) == acc_roll and preview.next_int(1, 6) == damage_roll:
			return seed_value
	assert(false, "Unable to find Task 17 ACC/damage seed.")
	return 1


func _find_seed_for_defense_rolls(acc_roll: int, defense_roll: int, start_seed: int) -> int:
	for seed_value in range(start_seed, start_seed + 500_000):
		var preview := DeterministicCombatRng.new(seed_value)
		preview.next_int(1, 10)
		preview.next_int(1, 10)
		if preview.next_int(1, 20) == acc_roll and preview.next_int(1, 20) == defense_roll:
			return seed_value
	assert(false, "Unable to find Task 17 defense seed.")
	return start_seed


func _expect_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s Expected %s, got %s." % [message, expected, actual])
