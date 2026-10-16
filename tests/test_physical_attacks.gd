extends RefCounted

var _failures: Array[String] = []


func run() -> Array[String]:
	_test_opening_initiative_reproducibility_and_order()
	_test_opening_initiative_ties()
	_test_attack_declaration_validation_and_torso_default()
	_test_accuracy_success_failure_and_natural_criticals()
	_test_attack_timing_for_supported_at_values()
	_test_fractional_continuity_cross_round_movement_and_no_damage()
	_test_attack_interruption_and_dependency()
	_test_deterministic_replay_and_two_client_convergence()
	return _failures


func _test_opening_initiative_reproducibility_and_order() -> void:
	var first := _build_opening_fixture(601, 100, 0)
	var second := _build_opening_fixture(601, 100, 0)
	var first_result := first.begin_combat()
	var second_result := second.begin_combat()
	_expect_equal(first_result["opening_order"], second_result["opening_order"], "Equal seeds and actors must reproduce opening d10 rolls and order.")
	_expect_equal(first.get_state_snapshot(), second.get_state_snapshot(), "Opening Initiative must be part of the deterministic authoritative snapshot.")
	var alpha_state := first.get_actor_state(&"alpha")
	_expect_true(alpha_state.opening_initiative_roll >= 1 and alpha_state.opening_initiative_roll <= 10, "Opening Initiative must retain the original d10 result.")
	_expect_equal(alpha_state.opening_initiative_total, alpha_state.opening_initiative_roll + 100, "Opening Initiative total must equal natural d10 plus base INIT.")
	var blocked := first.start_action(&"beta", _make_generic_action(&"beta_first"), "beta_too_early")
	_expect_equal(blocked["reason"], "opening_initiative_wait", "A lower opening rank must not declare before the higher rank.")
	var alpha_start := first.start_action(&"alpha", _make_generic_action(&"alpha_first"), "alpha_first_request")
	_expect_true(alpha_start["success"], "The highest opening rank must be allowed to declare first.")
	var beta_start := first.start_action(&"beta", _make_generic_action(&"beta_first"), "beta_first_request")
	_expect_true(beta_start["success"], "The next opening rank must unlock after the prior declaration without an invented time delay.")
	_expect_equal(first.get_action(alpha_start["action_instance_id"]).started_at_us, 0, "Opening order must not create an arbitrary timestamp offset.")
	_expect_equal(first.get_action(beta_start["action_instance_id"]).started_at_us, 0, "Lower opening ranks may begin at the same simulation timestamp after declaration order is satisfied.")


func _test_opening_initiative_ties() -> void:
	var unequal_roll_seed := _find_seed_for_distinct_opening_rolls()
	var preview := DeterministicCombatRng.new(unequal_roll_seed)
	var alpha_roll := preview.next_int(1, 10)
	var beta_roll := preview.next_int(1, 10)
	var alpha_init := 20
	var beta_init := 20
	if alpha_roll < beta_roll:
		alpha_init += beta_roll - alpha_roll
	else:
		beta_init += alpha_roll - beta_roll
	var total_tie := _build_opening_fixture(unequal_roll_seed, alpha_init, beta_init)
	total_tie.begin_combat()
	var alpha_state := total_tie.get_actor_state(&"alpha")
	var beta_state := total_tie.get_actor_state(&"beta")
	_expect_equal(alpha_state.opening_initiative_total, beta_state.opening_initiative_total, "The fixture must produce equal opening totals.")
	var higher_init_state: CombatActorState = alpha_state if alpha_init > beta_init else beta_state
	var lower_init_state: CombatActorState = beta_state if alpha_init > beta_init else alpha_state
	_expect_true(int(higher_init_state.opening_order_rank) < int(lower_init_state.opening_order_rank), "Higher base INIT must break an equal opening total.")

	var exact_tie_seed := _find_seed_for_equal_opening_rolls()
	var exact_tie := _build_opening_fixture(exact_tie_seed, 7, 7)
	exact_tie.begin_combat()
	_expect_equal(exact_tie.get_actor_state(&"alpha").opening_order_rank, exact_tie.get_actor_state(&"beta").opening_order_rank, "Equal d10 totals and equal base INIT must share one simultaneous opening rank.")
	_expect_true(exact_tie.start_action(&"alpha", _make_generic_action(&"alpha_tie"), "alpha_tie_request")["success"], "The first exact-tie actor must be eligible.")
	_expect_true(exact_tie.start_action(&"beta", _make_generic_action(&"beta_tie"), "beta_tie_request")["success"], "The other exact-tie actor must remain simultaneously eligible.")


func _test_attack_declaration_validation_and_torso_default() -> void:
	var unresolved := CombatSimulation.new(602)
	unresolved.register_actor(_make_actor(&"attacker", 2, 100))
	unresolved.register_actor(_make_actor(&"target", 2, 0))
	var before_opening := unresolved.start_physical_attack(&"attacker", &"target", _make_attack(&"before_opening"), "before_opening", &"torso", true)
	_expect_equal(before_opening["reason"], "opening_initiative_unresolved", "Physical attacks must fail closed before opening Initiative.")
	var unequipped := CombatSimulation.new(604)
	unequipped.register_actor(_make_actor(&"attacker", 2, 100, 10, 0, false))
	unequipped.register_actor(_make_actor(&"target", 2, 0))
	unequipped.begin_combat()
	_expect_equal(unequipped.start_physical_attack(&"attacker", &"target", _make_attack(&"unequipped"), "unequipped", &"torso", true)["reason"], "weapon_not_equipped", "An attack must reject a weapon reference that is not equipped.")

	var simulation := CombatSimulation.new(603)
	simulation.register_actor(_make_actor(&"attacker", 2, 100))
	simulation.register_actor(_make_actor(&"target", 2, 0))
	simulation.begin_combat()
	var definition := _make_attack(&"declaration_fixture")
	_expect_equal(simulation.start_physical_attack(&"attacker", &"missing", definition, "missing_target", &"torso", true)["reason"], "unknown_target", "Unknown targets must be rejected.")
	_expect_equal(simulation.start_physical_attack(&"attacker", &"attacker", definition, "self_target", &"torso", true)["reason"], "self_target_not_allowed", "Self-targeted physical attacks must be rejected by this pipeline.")
	_expect_equal(simulation.start_physical_attack(&"attacker", &"target", definition, "bad_location", &"head", true)["reason"], "illegal_target_location", "Unsourced aimed locations must fail closed.")
	var unresolved_range := _make_attack(&"unresolved_range", 1, 0, null)
	_expect_equal(simulation.start_physical_attack(&"attacker", &"target", unresolved_range, "unresolved_range", &"torso", true)["reason"], "unresolved_attack_range", "Attacks without sourced range data must fail closed.")
	simulation.apply_authoritative_position(&"target", Vector2i(6_000_000, 0), 0)
	var approach_attack := simulation.start_physical_attack(&"attacker", &"target", definition, "approach_attack", &"", false)
	_expect_true(approach_attack["success"], "An ordinary melee attack may be declared outside reach or while its initial line of sight is obstructed.")
	_expect_equal(String(simulation.get_attack(approach_attack["attack_instance_id"]).target_location), "torso", "An omitted ordinary attack location must default to torso.")
	_expect_equal(simulation.start_physical_attack(&"attacker", &"target", definition, "approach_attack", &"torso", true)["reason"], "duplicate_request", "Duplicate attack requests must be rejected idempotently.")
	simulation.advance_to(2_500_000)
	var failed_approach := simulation.get_attack(approach_attack["attack_instance_id"])
	_expect_equal(failed_approach.status, CombatAttackInstance.STATUS_FINAL_LEGALITY_FAILED, "An attacker still outside reach at final resolution must fail before ACC.")
	_expect_equal(failed_approach.natural_roll, null, "Final geometry failure must consume no ACC roll.")


func _test_accuracy_success_failure_and_natural_criticals() -> void:
	var success := _resolve_attack_for_natural_roll(5, 10, 0, 0)
	_expect_true(success.accuracy_success, "A noncritical d20 result at or below applicable ACC must succeed.")
	_expect_equal(success.status, CombatAttackInstance.STATUS_PENDING_DEFENSE, "ACC success must stop at pending defensive resolution.")
	var failure := _resolve_attack_for_natural_roll(15, 10, 0, 0)
	_expect_true(not failure.accuracy_success, "A noncritical d20 result above applicable ACC must fail.")
	_expect_equal(failure.status, CombatAttackInstance.STATUS_MISSED, "ACC failure must be recorded as a miss before defenses or damage.")

	var natural_one := _resolve_attack_for_natural_roll(1, 10, 3, -100)
	_expect_true(natural_one.critical_success, "Natural 1 must be recorded as critical success from the unmodified die.")
	_expect_true(natural_one.accuracy_success, "Natural 1 must remain critical success despite RB and an otherwise impossible ordinary modifier.")
	var natural_twenty := _resolve_attack_for_natural_roll(20, 10, 3, 100)
	_expect_true(natural_twenty.critical_failure, "Natural 20 must be recorded as critical failure from the unmodified die.")
	_expect_true(not natural_twenty.accuracy_success, "Natural 20 must remain critical failure despite RB and an otherwise automatic ordinary target.")


func _test_attack_timing_for_supported_at_values() -> void:
	var expected_boundaries := {
		1: 5_000_000,
		2: 2_500_000,
		3: 1_666_667,
		4: 1_250_000,
		5: 1_000_000,
		10: 500_000,
		12: 416_667,
	}
	for at_value: int in expected_boundaries:
		var simulation := _build_attack_fixture(700 + at_value, at_value)
		var result := simulation.start_physical_attack(&"attacker", &"target", _make_attack(StringName("at_%d" % at_value)), "at_%d_request" % at_value, &"torso", true)
		var attack: CombatAttackInstance = simulation.get_attack(result["attack_instance_id"])
		var due_at: int = expected_boundaries[at_value]
		simulation.advance_to(due_at - 1)
		_expect_equal(attack.status, CombatAttackInstance.STATUS_EXECUTING, "AT %d attack must occupy its full action interval." % at_value)
		simulation.advance_to(due_at)
		_expect_equal(attack.resolved_at_us, due_at, "AT %d attack must resolve ACC at its deterministic effect point." % at_value)


func _test_fractional_continuity_cross_round_movement_and_no_damage() -> void:
	var twelfths := _build_attack_fixture(712, 12)
	var last_result: Dictionary
	for index in range(12):
		last_result = twelfths.start_physical_attack(&"attacker", &"target", _make_attack(&"twelfth_fixture"), "twelfth_%d" % index, &"torso", true)
		twelfths.advance_to(_ceil_div((index + 1) * CombatClock.ROUND_DURATION_US, 12))
	_expect_equal(twelfths.get_attack(last_result["attack_instance_id"]).resolved_at_us, 5_000_000, "Twelve continuous AT 12 attacks must align exactly to five seconds without cumulative drift.")

	var cross_round := CombatSimulation.new(713)
	cross_round.register_actor(_make_actor(&"attacker", 2, 100))
	cross_round.register_actor(_make_actor(&"target", 2, 0))
	cross_round.advance_to(4_500_000)
	cross_round.begin_combat()
	var initial_attacker_hpc: Variant = cross_round.get_actor_state(&"attacker").current_hpc
	var initial_target_hpc: Variant = cross_round.get_actor_state(&"target").current_hpc
	var result := cross_round.start_physical_attack(&"attacker", &"target", _make_attack(&"cross_round", 2), "cross_round_attack", &"torso", true)
	cross_round.advance_to(5_000_000)
	_expect_true(cross_round.apply_authoritative_position(&"attacker", Vector2i(1_000_000, 0), 0)["success"], "Legal movement must continue while a compatible attack executes.")
	cross_round.advance_to(9_500_000)
	_expect_equal(cross_round.get_attack(result["attack_instance_id"]).resolved_at_us, 9_500_000, "A multi-Act attack begun late in a round must take both full intervals across the boundary.")
	_expect_equal(cross_round.get_actor_state(&"attacker").current_hpc, initial_attacker_hpc, "Accuracy resolution must not change attacker HPC.")
	_expect_equal(cross_round.get_actor_state(&"target").current_hpc, initial_target_hpc, "Accuracy success must not apply premature damage to the target.")


func _test_attack_interruption_and_dependency() -> void:
	var interrupted := CombatSimulation.new(714)
	interrupted.register_actor(_make_actor(&"interrupter", 10, 100))
	interrupted.register_actor(_make_actor(&"attacker", 1, 50))
	interrupted.register_actor(_make_actor(&"target", 1, 0))
	interrupted.begin_combat()
	interrupted.start_action(&"interrupter", _make_generic_action(&"opening_interrupter"), "opening_interrupter")
	var attack_result := interrupted.start_physical_attack(&"attacker", &"target", _make_attack(&"interruptible"), "interruptible_attack", &"torso", true)
	interrupted.schedule_interruption(attack_result["action_instance_id"], 5_000_000, &"interrupter", "fixture_interrupt")
	interrupted.advance_to(5_000_000)
	var attack: CombatAttackInstance = interrupted.get_attack(attack_result["attack_instance_id"])
	_expect_equal(attack.status, CombatAttackInstance.STATUS_INTERRUPTED, "A legal higher-INIT interruption must stop the attack before ACC resolution.")
	_expect_equal(attack.natural_roll, null, "An interrupted attack must not consume an ACC roll.")

	var dependent := CombatSimulation.new(715)
	dependent.register_actor(_make_actor(&"dependency", 1, 100))
	dependent.register_actor(_make_actor(&"attacker", 1, 50))
	dependent.register_actor(_make_actor(&"target", 1, 0))
	dependent.begin_combat()
	var dependency_result := dependent.start_action(&"dependency", _make_generic_action(&"dependency_action"), "dependency_request")
	var dependent_attack := dependent.start_physical_attack(
		&"attacker", &"target", _make_attack(&"dependent_attack"), "dependent_attack_request", &"torso", true,
		PackedStringArray([dependency_result["action_instance_id"]])
	)
	dependent.advance_to(5_000_000)
	var resolved_dependent_attack: CombatAttackInstance = dependent.get_attack(dependent_attack["attack_instance_id"])
	_expect_true(resolved_dependent_attack.status != CombatAttackInstance.STATUS_EXECUTING, "ACC must resolve only after the attack action and its dependency become terminal.")
	_expect_equal(resolved_dependent_attack.resolved_at_us, 5_000_000, "Dependency release must preserve the attack's deterministic effect timestamp.")


func _test_deterministic_replay_and_two_client_convergence() -> void:
	var first := _build_resolved_replay(716)
	var second := _build_resolved_replay(716)
	_expect_equal(first.get_state_snapshot(), second.get_state_snapshot(), "Opening Initiative and ACC resolution must replay to the same state.")
	_expect_equal(_serialize_events(first.get_resolved_events()), _serialize_events(second.get_resolved_events()), "Opening and attack event records must replay identically.")

	var harness := TwoClientSyncHarness.new(717)
	harness.authority.simulation.register_actor(_make_actor(&"attacker", 2, 100))
	harness.authority.simulation.register_actor(_make_actor(&"target", 2, 0))
	harness.authority.simulation.begin_combat()
	harness.authority.simulation.start_physical_attack(&"attacker", &"target", _make_attack(&"sync_attack"), "sync_attack_request", &"torso", true)
	var envelopes := harness.authority.publish_due_events(2_500_000)
	for envelope: CombatEventEnvelope in envelopes:
		harness.client_a.receive(envelope)
	for index in range(envelopes.size() - 1, -1, -1):
		harness.client_b.receive(envelopes[index])
	_expect_true(harness.compare_clients()["success"], "Two clients must converge on opening Initiative and the authoritative pending-defense attack state.")
	_expect_equal(harness.client_a.get_state_digest(), harness.authority.get_state_digest(), "The complete attack observer must match the authoritative digest.")


func _build_opening_fixture(seed_value: int, alpha_init: int, beta_init: int) -> CombatSimulation:
	var simulation := CombatSimulation.new(seed_value)
	simulation.register_actor(_make_actor(&"alpha", 1, alpha_init))
	simulation.register_actor(_make_actor(&"beta", 1, beta_init))
	return simulation


func _build_attack_fixture(seed_value: int, at_value: int) -> CombatSimulation:
	var simulation := CombatSimulation.new(seed_value)
	simulation.register_actor(_make_actor(&"attacker", at_value, 100))
	simulation.register_actor(_make_actor(&"target", at_value, 0))
	simulation.begin_combat()
	return simulation


func _build_resolved_replay(seed_value: int) -> CombatSimulation:
	var simulation := _build_attack_fixture(seed_value, 3)
	simulation.start_physical_attack(&"attacker", &"target", _make_attack(&"replay_attack"), "replay_attack_request", &"torso", true)
	simulation.advance_to(1_666_667)
	return simulation


func _resolve_attack_for_natural_roll(target_roll: int, acc: int, roll_bonus: int, acc_modifier: int) -> CombatAttackInstance:
	var seed_value := _find_seed_for_third_roll(target_roll)
	var simulation := CombatSimulation.new(seed_value)
	simulation.register_actor(_make_actor(&"attacker", 5, 100, acc, roll_bonus))
	simulation.register_actor(_make_actor(&"target", 5, 0))
	simulation.begin_combat()
	var result := simulation.start_physical_attack(&"attacker", &"target", _make_attack(&"roll_fixture", 1, acc_modifier), "roll_fixture_request", &"torso", true)
	simulation.advance_to(1_000_000)
	return simulation.get_attack(result["attack_instance_id"])


func _make_actor(actor_id: StringName, at_value: int, init_value: int, acc_value: int = 10, roll_bonus: int = 0, equipped: bool = true) -> CombatActorDefinition:
	return CombatActorDefinition.new(
		actor_id,
		&"test_fixture",
		"Fixture %s" % String(actor_id),
		{
			"str": 8, "end": 8, "spd": 8, "dex": 8, "wis": 8,
			"int": 8, "wit": 8, "man": 8, "luk": 8, "app": 8,
		},
		{
			"hpm": 20, "acc": acc_value, "at": at_value, "init": init_value, "mr": 10,
			"nal": 1, "dt": 4, "dp": 4, "physical_soak": 5, "rb": roll_bonus,
		},
		{},
		PackedStringArray(["fixture_weapon"]) if equipped else PackedStringArray(),
		{},
		{
			"combat_stats.acc": "PRIME-V3 pp. 20, 91 test fixture",
			"combat_stats.init": "PRIME-V3 p. 21 test fixture",
		}
	)


func _make_attack(
	attack_id: StringName,
	required_acts: int = 1,
	acc_modifier: int = 0,
	maximum_range_microfeet: Variant = 5_000_000
) -> CombatAttackDefinition:
	return CombatAttackDefinition.new(
		attack_id,
		&"fixture_weapon",
		required_acts,
		true,
		true,
		acc_modifier,
		{"torso": 0},
		PackedStringArray(["torso"]),
		0,
		maximum_range_microfeet,
		true,
		PackedStringArray(["TEST-FIXTURE: explicit engine inputs; not production weapon data"]),
		&"",
		PackedStringArray(),
		null,
		CombatAttackDefinition.DUCKING_UNRESOLVED,
		null,
		null,
		true
	)


func _make_generic_action(action_id: StringName) -> CombatActionDefinition:
	return CombatActionDefinition.new(action_id, 1, true, true, {}, {}, PackedStringArray(["TEST-FIXTURE"]))


func _find_seed_for_third_roll(target_roll: int) -> int:
	for seed_value in range(1, 100_000):
		var preview := DeterministicCombatRng.new(seed_value)
		preview.next_int(1, 10)
		preview.next_int(1, 10)
		if preview.next_int(1, 20) == target_roll:
			return seed_value
	assert(false, "Unable to find deterministic fixture seed for requested d20 result.")
	return 0


func _find_seed_for_equal_opening_rolls() -> int:
	for seed_value in range(1, 10_000):
		var preview := DeterministicCombatRng.new(seed_value)
		if preview.next_int(1, 10) == preview.next_int(1, 10):
			return seed_value
	assert(false, "Unable to find deterministic fixture seed for equal opening d10 results.")
	return 0


func _find_seed_for_distinct_opening_rolls() -> int:
	for seed_value in range(1, 10_000):
		var preview := DeterministicCombatRng.new(seed_value)
		if preview.next_int(1, 10) != preview.next_int(1, 10):
			return seed_value
	assert(false, "Unable to find deterministic fixture seed for distinct opening d10 results.")
	return 0


func _ceil_div(numerator: int, denominator: int) -> int:
	@warning_ignore("integer_division")
	return (numerator + denominator - 1) / denominator


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
