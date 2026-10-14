extends RefCounted

var _failures: Array[String] = []


func run() -> Array[String]:
	_test_dodge_success_failure_and_exclusivity()
	_test_weapon_and_shield_block_order()
	_test_soak_delivery_awareness_and_equipment_eligibility()
	_test_natural_critical_triggers_and_roll_bonus()
	_test_pending_dodge_displacement_boundary()
	_test_interruption_duplicates_and_no_damage()
	_test_deterministic_history_and_two_client_convergence()
	_test_automatic_dodge_nearest_duck_and_ties()
	_test_automatic_dodge_environmental_filters_and_limits()
	_test_automatic_dodge_pending_and_exclusivity_refinement()
	_test_automatic_dodge_replay_and_two_client_convergence()
	return _failures


func _test_dodge_success_failure_and_exclusivity() -> void:
	var successful := _build_pending_attack(_find_seed_for_d20_sequence([5, 3]), _make_profile(&"dodge_success"))
	var successful_state: CombatActorState = successful["simulation"].get_actor_state(&"target")
	var initial_hpc: Variant = successful_state.current_hpc
	var result: Dictionary = successful["simulation"].resolve_pending_defense(
		successful["attack_id"], "dodge_success", _resolved_dodge(Vector2i(2_000_000, 0), 2_000_000)
	)
	var resolution: CombatDefenseResolution = successful["simulation"].get_defense_resolution(result["defense_resolution_id"])
	_expect_equal(resolution.status, CombatDefenseResolution.STATUS_DEFENDED, "A successful legal Dodge must defend the attack.")
	_expect_equal(resolution.successful_defense_type, CombatDefenseProfile.DODGE, "Dodge must be recorded as the successful defense.")
	_expect_equal(successful_state.position_microfeet, Vector2i(2_000_000, 0), "A selected validated Dodge destination must be applied.")
	_expect_equal(successful_state.remaining_mr_microfeet, 8_000_000, "A successful two-foot Dodge must spend exactly two feet of round MR.")
	_expect_equal(resolution.attempts[0].resources_spent, {"mr_microfeet": 2_000_000}, "Dodge attempt history must record exact MR spending.")
	_expect_true(not resolution.attempts[0].parent_event_id.is_empty() and not resolution.attempts[0].result_event_id.is_empty(), "Defense attempts must retain causal parent and result event identifiers.")
	_expect_equal(resolution.attempts[1].eligibility, CombatDefenseAttempt.ELIGIBLE_NOT_SELECTED, "Candidates after the first successful defense must be recorded without extra rolls.")
	_expect_equal(successful_state.current_hpc, initial_hpc, "A completed defense must not change HPC.")
	successful["simulation"].advance_to(5_000_000)
	_expect_equal(successful_state.remaining_mr_microfeet, 10_000_000, "The five-second round boundary must deterministically restore the actor's MR budget.")

	var fallback_profile := _make_profile(
		&"dodge_mutex",
		PackedStringArray(["dodge", "physical_soak", "weapon_block", "shield_block"]),
		4,
		0
	)
	var failed := _build_pending_attack(_find_seed_for_d20_sequence([5, 10, 10, 10]), fallback_profile)
	var failed_state: CombatActorState = failed["simulation"].get_actor_state(&"target")
	var failed_result: Dictionary = failed["simulation"].resolve_pending_defense(
		failed["attack_id"], "dodge_failure", _resolved_dodge(Vector2i(2_000_000, 0), 2_000_000)
	)
	var failed_resolution: CombatDefenseResolution = failed["simulation"].get_defense_resolution(failed_result["defense_resolution_id"])
	_expect_equal(failed_resolution.attempts[0].success, false, "A failed Dodge roll must be recorded as failed.")
	_expect_equal(failed_resolution.attempts[1].eligibility, CombatDefenseAttempt.INELIGIBLE, "Physical Soak must become ineligible after a Dodge attempt.")
	_expect_equal(failed_resolution.attempts[1].eligibility_reason, "mutually_exclusive_with_dodge", "Dodge/Soak exclusion must be explicit in the history.")
	_expect_equal(failed_state.remaining_mr_microfeet, 10_000_000, "A failed Dodge must not spend displacement MR.")
	_expect_equal(failed_state.position_microfeet, Vector2i.ZERO, "A failed Dodge must not move the defender.")


func _test_weapon_and_shield_block_order() -> void:
	var weapon_then_shield := _make_profile(
		&"weapon_then_shield",
		PackedStringArray(["weapon_block", "shield_block", "dodge", "physical_soak"]),
		4,
		10
	)
	var first := _build_pending_attack(_find_seed_for_d20_sequence([5, 10, 3]), weapon_then_shield)
	var first_result: Dictionary = first["simulation"].resolve_pending_defense(
		first["attack_id"], "weapon_then_shield", _unavailable_dodge()
	)
	var first_resolution: CombatDefenseResolution = first["simulation"].get_defense_resolution(first_result["defense_resolution_id"])
	_expect_equal(first_resolution.attempts[0].defense_type, CombatDefenseProfile.WEAPON_BLOCK, "Configured weapon-first order must be preserved.")
	_expect_equal(first_resolution.attempts[0].success, false, "A failed weapon Block must permit the next legal Block.")
	_expect_equal(first_resolution.attempts[1].defense_type, CombatDefenseProfile.SHIELD_BLOCK, "Shield Block must remain a separate fallback opportunity.")
	_expect_equal(first_resolution.attempts[1].success, true, "The independent shield Block must be able to defend after weapon Block fails.")
	_expect_equal(weapon_then_shield.shield_block.current_shp, 9, "A successful shield Block must consume exactly one SHP.")

	var zero_shp_profile := _make_profile(
		&"zero_shp",
		PackedStringArray(["shield_block", "weapon_block", "dodge", "physical_soak"])
	)
	zero_shp_profile.shield_block.current_shp = 0
	var zero_shp := _build_pending_attack(_find_seed_for_d20_sequence([5, 3]), zero_shp_profile)
	var zero_result: Dictionary = zero_shp["simulation"].resolve_pending_defense(zero_shp["attack_id"], "zero_shp", _unavailable_dodge())
	var zero_resolution: CombatDefenseResolution = zero_shp["simulation"].get_defense_resolution(zero_result["defense_resolution_id"])
	_expect_equal(zero_resolution.attempts[0].eligibility_reason, "shield_has_zero_shp", "A 0-SHP shield must be ineligible without Task 7 mutating inventory or destruction state.")

	var shield_then_weapon := _make_profile(
		&"shield_then_weapon",
		PackedStringArray(["shield_block", "weapon_block", "dodge", "physical_soak"]),
		10,
		4
	)
	var second := _build_pending_attack(_find_seed_for_d20_sequence([5, 10, 3]), shield_then_weapon)
	var second_result: Dictionary = second["simulation"].resolve_pending_defense(
		second["attack_id"], "shield_then_weapon", _unavailable_dodge()
	)
	var second_resolution: CombatDefenseResolution = second["simulation"].get_defense_resolution(second_result["defense_resolution_id"])
	_expect_equal(second_resolution.attempts[0].defense_type, CombatDefenseProfile.SHIELD_BLOCK, "Configured shield-first order must be preserved.")
	_expect_equal(second_resolution.attempts[0].success, false, "A failed shield Block must permit the next legal Block.")
	_expect_equal(second_resolution.attempts[1].defense_type, CombatDefenseProfile.WEAPON_BLOCK, "Weapon Block must remain a separate fallback opportunity.")
	_expect_equal(second_resolution.attempts[1].success, true, "The independent weapon Block must be able to defend after shield Block fails.")


func _test_soak_delivery_awareness_and_equipment_eligibility() -> void:
	var soak_profile := _make_profile(
		&"soak_first",
		PackedStringArray(["physical_soak", "weapon_block", "shield_block", "dodge"]),
		0,
		0
	)
	var soak := _build_pending_attack(_find_seed_for_d20_sequence([5, 3]), soak_profile)
	var soak_result: Dictionary = soak["simulation"].resolve_pending_defense(soak["attack_id"], "soak_success", _unavailable_dodge())
	var soak_resolution: CombatDefenseResolution = soak["simulation"].get_defense_resolution(soak_result["defense_resolution_id"])
	_expect_equal(soak_resolution.successful_defense_type, CombatDefenseProfile.PHYSICAL_SOAK, "A legal roll at or below Physical Soak must defend the attack.")

	var thrown_profile := _make_profile(&"thrown_dodge")
	var thrown := _build_pending_attack(
		_find_seed_for_d20_sequence([5, 10]),
		thrown_profile,
		{"dt": 0, "dp": 12},
		&"thrown"
	)
	var thrown_result: Dictionary = thrown["simulation"].resolve_pending_defense(
		thrown["attack_id"], "thrown_dodge", _resolved_dodge(Vector2i(1_000_000, 0), 1_000_000)
	)
	var thrown_resolution: CombatDefenseResolution = thrown["simulation"].get_defense_resolution(thrown_result["defense_resolution_id"])
	_expect_equal(thrown_resolution.attempts[0].base_target, 12, "Thrown physical attacks must use DP rather than DT.")
	_expect_equal(thrown_resolution.attempts[0].success, true, "A thrown attack Dodge must resolve against DP.")

	var restricted := _build_pending_attack(_find_seed_for_d20_sequence([5]), _make_profile(&"restricted"))
	restricted["simulation"].set_actor_defense_state(&"target", &"aware", PackedStringArray(["surprised"]))
	var restricted_result: Dictionary = restricted["simulation"].resolve_pending_defense(
		restricted["attack_id"], "surprised", _unavailable_dodge()
	)
	var restricted_resolution: CombatDefenseResolution = restricted["simulation"].get_defense_resolution(restricted_result["defense_resolution_id"])
	for attempt: CombatDefenseAttempt in restricted_resolution.attempts:
		_expect_equal(attempt.eligibility_reason, "defender_unaware_or_surprised", "Surprise must reject every active defense without rolling.")
		_expect_equal(attempt.natural_roll, null, "Ineligible surprised defenses must not consume d20 rolls.")

	var unaware := _build_pending_attack(_find_seed_for_d20_sequence([5]), _make_profile(&"unaware"))
	unaware["simulation"].set_actor_defense_state(&"target", &"unaware", PackedStringArray())
	var unaware_result: Dictionary = unaware["simulation"].resolve_pending_defense(
		unaware["attack_id"], "unaware", _unavailable_dodge()
	)
	var unaware_resolution: CombatDefenseResolution = unaware["simulation"].get_defense_resolution(unaware_result["defense_resolution_id"])
	_expect_equal(unaware_resolution.attempts[0].eligibility_reason, "defender_unaware_or_surprised", "Unaware defenders must not actively Dodge.")
	_expect_equal(unaware_resolution.attempts[1].eligibility_reason, "defender_unaware_or_surprised", "Unaware defenders must not actively Block.")
	_expect_equal(unaware_resolution.attempts[3].eligibility_reason, "defender_unaware_or_surprised", "Unaware defenders must not actively use Physical Soak.")

	var illegal_profile := _make_profile(&"illegal_equipment")
	var illegal := _build_pending_attack(_find_seed_for_d20_sequence([5]), illegal_profile, {}, &"hand_held", false)
	var illegal_result: Dictionary = illegal["simulation"].resolve_pending_defense(
		illegal["attack_id"], "illegal_equipment", _unavailable_dodge()
	)
	var illegal_resolution: CombatDefenseResolution = illegal["simulation"].get_defense_resolution(illegal_result["defense_resolution_id"])
	_expect_equal(illegal_resolution.attempts[1].eligibility_reason, "blocking_equipment_not_equipped", "Weapon Block must fail closed when its item is not equipped.")
	_expect_equal(illegal_resolution.attempts[2].eligibility_reason, "blocking_equipment_not_equipped", "Shield Block must fail closed when its item is not equipped.")

	var piercing := _build_pending_attack(
		_find_seed_for_d20_sequence([5]), soak_profile, {}, &"hand_held", true, PackedStringArray(["piercing"])
	)
	var piercing_result: Dictionary = piercing["simulation"].resolve_pending_defense(
		piercing["attack_id"], "piercing_soak", _unavailable_dodge()
	)
	var piercing_resolution: CombatDefenseResolution = piercing["simulation"].get_defense_resolution(piercing_result["defense_resolution_id"])
	_expect_equal(piercing_resolution.attempts[0].eligibility_reason, "attack_not_physical_soak_eligible", "Piercing attacks must reject Physical Soak without rolling.")

	var back_attack := _build_pending_attack(
		_find_seed_for_d20_sequence([5]), soak_profile, {}, &"hand_held", true, PackedStringArray(["bashing"]), true
	)
	var back_result: Dictionary = back_attack["simulation"].resolve_pending_defense(back_attack["attack_id"], "back_attack", _unavailable_dodge())
	var back_resolution: CombatDefenseResolution = back_attack["simulation"].get_defense_resolution(back_result["defense_resolution_id"])
	_expect_equal(back_resolution.attempts[0].eligibility_reason, "back_attack", "Back attacks must reject Physical Soak without rolling.")


func _test_natural_critical_triggers_and_roll_bonus() -> void:
	var critical_success_profile := _make_profile(
		&"critical_success",
		PackedStringArray(["weapon_block", "shield_block", "dodge", "physical_soak"]),
		0,
		0,
		{"weapon_block": -100}
	)
	var critical_success := _build_pending_attack(
		_find_seed_for_d20_sequence([5, 1]), critical_success_profile, {"rb": 10}
	)
	var success_result: Dictionary = critical_success["simulation"].resolve_pending_defense(
		critical_success["attack_id"], "critical_success", _unavailable_dodge()
	)
	var success_attempt: CombatDefenseAttempt = critical_success["simulation"].get_defense_resolution(success_result["defense_resolution_id"]).attempts[0]
	_expect_true(success_attempt.critical_success, "Natural 1 must record defensive critical success from the unmodified die.")
	_expect_equal(success_attempt.success, true, "Natural 1 must succeed despite an otherwise impossible modifier.")

	var critical_failure_profile := _make_profile(
		&"critical_failure",
		PackedStringArray(["weapon_block", "shield_block", "dodge", "physical_soak"]),
		100,
		0
	)
	var critical_failure := _build_pending_attack(
		_find_seed_for_d20_sequence([5, 20, 2]), critical_failure_profile, {"rb": 10}
	)
	var failure_result: Dictionary = critical_failure["simulation"].resolve_pending_defense(
		critical_failure["attack_id"], "critical_failure", _unavailable_dodge()
	)
	var failure_attempt: CombatDefenseAttempt = critical_failure["simulation"].get_defense_resolution(failure_result["defense_resolution_id"]).attempts[0]
	_expect_true(failure_attempt.critical_failure, "Natural 20 must record defensive critical failure from the unmodified die.")
	_expect_equal(failure_attempt.success, false, "Natural 20 must fail despite RB and an otherwise automatic target.")


func _test_pending_dodge_displacement_boundary() -> void:
	var fixture := _build_pending_attack(_find_seed_for_d20_sequence([5, 3]), _make_profile(&"ambiguous_dodge"))
	var state: CombatActorState = fixture["simulation"].get_actor_state(&"target")
	var result: Dictionary = fixture["simulation"].resolve_pending_defense(
		fixture["attack_id"],
		"ambiguous_dodge",
		CombatDodgeContext.new(CombatDodgeContext.SELECTION_AMBIGUOUS, Vector2i.ZERO, null, false, true, true, "TEST-FIXTURE")
	)
	var resolution: CombatDefenseResolution = fixture["simulation"].get_defense_resolution(result["defense_resolution_id"])
	_expect_equal(resolution.status, CombatDefenseResolution.STATUS_PENDING_DODGE_DISPLACEMENT, "A successful Dodge with no approved destination choice must remain pending.")
	_expect_equal(fixture["simulation"].get_attack(fixture["attack_id"]).status, CombatAttackInstance.STATUS_PENDING_DODGE_DISPLACEMENT, "The attack must remain unresolved while Dodge displacement is pending.")
	_expect_equal(state.position_microfeet, Vector2i.ZERO, "Ambiguous Dodge selection must not teleport the actor.")
	_expect_equal(state.remaining_mr_microfeet, 10_000_000, "Ambiguous Dodge selection must not spend unselected MR.")
	var completed: Dictionary = fixture["simulation"].complete_pending_dodge_displacement(
		fixture["attack_id"], "resolved_dodge", _resolved_dodge(Vector2i(3_000_000, 0), 3_000_000)
	)
	_expect_true(completed["success"], "An authoritative validated destination must complete pending Dodge displacement.")
	_expect_equal(state.position_microfeet, Vector2i(3_000_000, 0), "Completed pending Dodge displacement must use the supplied destination.")
	_expect_equal(state.remaining_mr_microfeet, 7_000_000, "Completed pending Dodge displacement must spend its exact MR cost once.")
	_expect_equal(
		fixture["simulation"].complete_pending_dodge_displacement(fixture["attack_id"], "resolved_dodge", _resolved_dodge(Vector2i(4_000_000, 0), 1_000_000))["reason"],
		"duplicate_defense_request",
		"Duplicate displacement delivery must not move or spend MR twice."
	)

	var stale := _build_pending_attack(_find_seed_for_d20_sequence([5, 3]), _make_profile(&"stale_dodge"))
	stale["simulation"].resolve_pending_defense(
		stale["attack_id"],
		"stale_ambiguous",
		CombatDodgeContext.new(CombatDodgeContext.SELECTION_AMBIGUOUS, Vector2i.ZERO, null, false, true, true, "TEST-FIXTURE")
	)
	stale["simulation"].advance_to(2_000_000)
	_expect_equal(
		stale["simulation"].complete_pending_dodge_displacement(stale["attack_id"], "stale_resolved", _resolved_dodge(Vector2i(1_000_000, 0), 1_000_000))["reason"],
		"dodge_displacement_time_advanced",
		"Pending Dodge displacement must fail closed rather than spend MR after simulation time advances."
	)


func _test_interruption_duplicates_and_no_damage() -> void:
	var interrupted := CombatSimulation.new(801)
	interrupted.register_actor(_make_actor(&"interrupter", 10, 100))
	interrupted.register_actor(_make_actor(&"attacker", 1, 50))
	interrupted.register_actor(_make_actor(&"target", 1, 0))
	interrupted.register_defense_profile(&"target", _make_profile(&"interrupted"))
	interrupted.begin_combat()
	interrupted.start_action(&"interrupter", CombatActionDefinition.new(&"opening", 1), "opening")
	var attack_result: Dictionary = interrupted.start_physical_attack(
		&"attacker", &"target", _make_attack(&"interrupted"), "interrupted_attack", &"torso", true
	)
	interrupted.schedule_interruption(attack_result["action_instance_id"], 5_000_000, &"interrupter", "fixture")
	interrupted.advance_to(5_000_000)
	_expect_equal(
		interrupted.resolve_pending_defense(attack_result["attack_instance_id"], "invalid_defense", _unavailable_dodge())["reason"],
		"attack_not_pending_defense",
		"An interrupted attack must never enter defensive rolling."
	)

	var dependent := CombatSimulation.new(_find_seed_for_d20_sequence([5]))
	dependent.register_actor(_make_actor(&"dependency", 1, 100))
	dependent.register_actor(_make_actor(&"attacker", 1, 50))
	dependent.register_actor(_make_actor(&"target", 1, 0))
	dependent.register_defense_profile(&"target", _make_profile(&"dependent"))
	dependent.begin_combat()
	var dependency_result := dependent.start_action(&"dependency", CombatActionDefinition.new(&"dependency", 2), "dependency")
	var dependent_attack := dependent.start_physical_attack(
		&"attacker", &"target", _make_attack(&"dependent"), "dependent_attack", &"torso", true,
		PackedStringArray([dependency_result["action_instance_id"]])
	)
	dependent.advance_to(5_000_000)
	_expect_equal(
		dependent.resolve_pending_defense(dependent_attack["attack_instance_id"], "too_early", _unavailable_dodge())["reason"],
		"attack_not_pending_defense",
		"Defense rolls must not begin while an attack still awaits a causal dependency."
	)
	dependent.advance_to(10_000_000)
	_expect_true(
		dependent.resolve_pending_defense(dependent_attack["attack_instance_id"], "after_dependency", _unavailable_dodge())["success"],
		"Defense resolution must become legal after the attack and its dependency finalize."
	)

	var fixture := _build_pending_attack(_find_seed_for_d20_sequence([5, 3]), _make_profile(&"duplicate"))
	var target_state: CombatActorState = fixture["simulation"].get_actor_state(&"target")
	var starting_hpc: Variant = target_state.current_hpc
	var first: Dictionary = fixture["simulation"].resolve_pending_defense(fixture["attack_id"], "one_request", _resolved_dodge(Vector2i(1_000_000, 0), 1_000_000))
	_expect_true(first["success"], "The first defense request must resolve.")
	_expect_equal(
		fixture["simulation"].resolve_pending_defense(fixture["attack_id"], "one_request", _resolved_dodge(Vector2i(2_000_000, 0), 1_000_000))["reason"],
		"duplicate_defense_request",
		"Duplicate defense requests must not roll or spend resources twice."
	)
	_expect_equal(target_state.remaining_mr_microfeet, 9_000_000, "Duplicate defense delivery must not double-spend MR.")
	_expect_equal(target_state.current_hpc, starting_hpc, "Defense completion must not apply damage or reduce HPC.")


func _test_deterministic_history_and_two_client_convergence() -> void:
	var seed_value := _find_seed_for_d20_sequence([5, 10, 3])
	var first := _build_pending_attack(seed_value, _make_profile(&"replay"))
	var second := _build_pending_attack(seed_value, _make_profile(&"replay"))
	first["simulation"].resolve_pending_defense(first["attack_id"], "replay_defense", _resolved_dodge(Vector2i(2_000_000, 0), 2_000_000))
	second["simulation"].resolve_pending_defense(second["attack_id"], "replay_defense", _resolved_dodge(Vector2i(2_000_000, 0), 2_000_000))
	_expect_equal(first["simulation"].get_state_snapshot(), second["simulation"].get_state_snapshot(), "Equal seeds and defense inputs must reproduce the same authoritative state.")
	_expect_equal(_serialize_events(first["simulation"].get_resolved_events()), _serialize_events(second["simulation"].get_resolved_events()), "Defense roll histories and causal event records must replay identically.")

	var harness := TwoClientSyncHarness.new(seed_value)
	harness.authority.simulation.register_actor(_make_actor(&"attacker", 5, 100))
	harness.authority.simulation.register_actor(_make_actor(&"target", 5, 0))
	harness.authority.simulation.register_defense_profile(&"target", _make_profile(&"sync"))
	harness.authority.simulation.begin_combat()
	var attack_result: Dictionary = harness.authority.simulation.start_physical_attack(
		&"attacker", &"target", _make_attack(&"sync"), "sync_attack", &"torso", true
	)
	var envelopes: Array = harness.authority.publish_due_events(1_000_000)
	harness.authority.simulation.resolve_pending_defense(
		attack_result["attack_instance_id"], "sync_defense", _resolved_dodge(Vector2i(2_000_000, 0), 2_000_000)
	)
	envelopes.append_array(harness.authority.publish_current_events())
	for envelope: CombatEventEnvelope in envelopes:
		harness.client_a.receive(envelope)
	for index in range(envelopes.size() - 1, -1, -1):
		harness.client_b.receive(envelopes[index])
	if not envelopes.is_empty():
		harness.client_b.receive(envelopes[0])
	_expect_true(harness.compare_clients()["success"], "In-order and out-of-order clients must converge on the authoritative defense state.")
	_expect_equal(harness.client_a.get_state_digest(), harness.authority.get_state_digest(), "Completed defense state must match the authoritative digest.")
	_expect_true(not harness.client_b.has_failure(), "A byte-identical duplicate defense event must be ignored safely.")


func _test_automatic_dodge_nearest_duck_and_ties() -> void:
	var nearest := _build_pending_attack(_find_seed_for_d20_sequence([5, 3]), _make_profile(&"automatic_nearest"))
	var nearest_environment := _environment(&"nearest", true, [
		_candidate(&"far", Vector2i(3_000_000, 0), 3_000_000),
		_candidate(&"near", Vector2i(1_000_000, 0), 1_000_000),
	])
	var nearest_result: Dictionary = nearest["simulation"].resolve_pending_defense_automatically(
		nearest["attack_id"], "automatic_nearest", nearest_environment
	)
	var nearest_resolution: CombatDefenseResolution = nearest["simulation"].get_defense_resolution(nearest_result["defense_resolution_id"])
	var nearest_state: CombatActorState = nearest["simulation"].get_actor_state(&"target")
	_expect_equal(nearest_state.position_microfeet, Vector2i(1_000_000, 0), "Automatic Dodge must select the nearest legal destination by authoritative path cost.")
	_expect_equal(nearest_state.remaining_mr_microfeet, 9_000_000, "Automatic Dodge must spend the selected destination's exact MR cost.")
	_expect_equal(nearest_resolution.attempts[0].resolution_context["candidate_id"], "near", "The selected Dodge candidate must be retained in deterministic attempt history.")

	var duck := _build_pending_attack(
		_find_seed_for_d20_sequence([5, 3]),
		_make_profile(&"automatic_duck"),
		{},
		&"hand_held",
		true,
		PackedStringArray(["bashing"]),
		false,
		CombatAttackDefinition.DUCKING_ALLOWED
	)
	var duck_environment := _environment(&"duck", true, [
		_candidate(&"step", Vector2i(1_000_000, 0), 1_000_000),
		_candidate(&"duck", Vector2i.ZERO, 0, true, true, true, true, true, true, true),
	])
	var duck_result: Dictionary = duck["simulation"].resolve_pending_defense_automatically(
		duck["attack_id"], "automatic_duck", duck_environment
	)
	var duck_resolution: CombatDefenseResolution = duck["simulation"].get_defense_resolution(duck_result["defense_resolution_id"])
	var duck_state: CombatActorState = duck["simulation"].get_actor_state(&"target")
	_expect_equal(duck_state.position_microfeet, Vector2i.ZERO, "A legally sufficient in-place duck must not displace the actor.")
	_expect_equal(duck_state.remaining_mr_microfeet, 10_000_000, "A legally sufficient in-place duck must spend zero MR.")
	_expect_equal(duck_resolution.attempts[0].resolution_context["candidate_id"], "duck", "A legal zero-cost duck must win nearest selection.")

	var tied := _build_pending_attack(_find_seed_for_d20_sequence([5, 3]), _make_profile(&"automatic_tie"))
	var tied_environment := _environment(&"tie", true, [
		_candidate(&"z_route", Vector2i(-2_000_000, 0), 2_000_000),
		_candidate(&"a_route", Vector2i(2_000_000, 0), 2_000_000),
	])
	var tied_result: Dictionary = tied["simulation"].resolve_pending_defense_automatically(
		tied["attack_id"], "automatic_tie", tied_environment
	)
	var tied_attempt: CombatDefenseAttempt = tied["simulation"].get_defense_resolution(tied_result["defense_resolution_id"]).attempts[0]
	_expect_equal(tied_attempt.resolution_context["candidate_id"], "a_route", "Equal safety and distance must use the stable candidate identifier tie-break.")


func _test_automatic_dodge_environmental_filters_and_limits() -> void:
	var filtered := _build_pending_attack(_find_seed_for_d20_sequence([5, 3]), _make_profile(&"automatic_filters"))
	var filtered_environment := _environment(&"filters", true, [
		_candidate(&"blocked_path", Vector2i(1_000_000, 0), 1_000_000, false, false),
		_candidate(&"collision", Vector2i(0, 1_000_000), 1_000_000, false, true, false),
		_candidate(&"terrain", Vector2i(-1_000_000, 0), 1_000_000, false, true, true, false),
		_candidate(&"occupied", Vector2i(0, -1_000_000), 1_000_000, false, true, true, true, false),
		_candidate(&"over_half_mr", Vector2i(6_000_000, 0), 6_000_000),
		_candidate(&"near_hazard", Vector2i(1_500_000, 0), 1_500_000, false, true, true, true, true, true, false, 5),
		_candidate(&"safe", Vector2i(2_000_000, 0), 2_000_000),
	])
	var filtered_result: Dictionary = filtered["simulation"].resolve_pending_defense_automatically(
		filtered["attack_id"], "automatic_filters", filtered_environment
	)
	var filtered_resolution: CombatDefenseResolution = filtered["simulation"].get_defense_resolution(filtered_result["defense_resolution_id"])
	_expect_equal(filtered_resolution.attempts[0].resolution_context["candidate_id"], "safe", "Blocked, colliding, illegal-terrain, occupied, over-limit, and avoidably hazardous destinations must not be selected.")
	_expect_equal(filtered["simulation"].get_actor_state(&"target").position_microfeet, Vector2i(2_000_000, 0), "The safest legal candidate must be applied when a nearer candidate is obviously more hazardous.")

	var half_mr := _build_pending_attack(_find_seed_for_d20_sequence([5, 3]), _make_profile(&"automatic_half_mr"))
	var half_mr_environment := _environment(&"half_mr", true, [
		_candidate(&"too_far", Vector2i(5_000_001, 0), 5_000_001),
		_candidate(&"exact_half", Vector2i(5_000_000, 0), 5_000_000),
	])
	var half_result: Dictionary = half_mr["simulation"].resolve_pending_defense_automatically(
		half_mr["attack_id"], "automatic_half_mr", half_mr_environment
	)
	var half_attempt: CombatDefenseAttempt = half_mr["simulation"].get_defense_resolution(half_result["defense_resolution_id"]).attempts[0]
	_expect_equal(half_attempt.resolution_context["candidate_id"], "exact_half", "A destination exactly at half MR must remain legal while a farther one is rejected.")
	_expect_equal(half_mr["simulation"].get_actor_state(&"target").remaining_mr_microfeet, 5_000_000, "An exact half-MR Dodge must spend exactly half the round budget.")


func _test_automatic_dodge_pending_and_exclusivity_refinement() -> void:
	var incomplete := _build_pending_attack(_find_seed_for_d20_sequence([5, 3]), _make_profile(&"automatic_incomplete"))
	var incomplete_result: Dictionary = incomplete["simulation"].resolve_pending_defense_automatically(
		incomplete["attack_id"], "automatic_incomplete", _environment(&"incomplete", false, [])
	)
	var incomplete_resolution: CombatDefenseResolution = incomplete["simulation"].get_defense_resolution(incomplete_result["defense_resolution_id"])
	_expect_equal(incomplete_resolution.status, CombatDefenseResolution.STATUS_PENDING_DODGE_DISPLACEMENT, "Incomplete environmental information must preserve pending Dodge displacement after a successful check.")
	_expect_equal(incomplete["simulation"].get_actor_state(&"target").remaining_mr_microfeet, 10_000_000, "Pending automatic displacement must not spend MR.")

	var ineligible_profile := _make_profile(
		&"automatic_ineligible_fallback",
		PackedStringArray(["dodge", "physical_soak", "weapon_block", "shield_block"]),
		0,
		0
	)
	var ineligible := _build_pending_attack(_find_seed_for_d20_sequence([5, 3]), ineligible_profile)
	var no_legal_destination := _environment(&"none", true, [
		_candidate(&"occupied", Vector2i(1_000_000, 0), 1_000_000, false, true, true, true, false),
	])
	var ineligible_result: Dictionary = ineligible["simulation"].resolve_pending_defense_automatically(
		ineligible["attack_id"], "automatic_ineligible_fallback", no_legal_destination
	)
	var ineligible_resolution: CombatDefenseResolution = ineligible["simulation"].get_defense_resolution(ineligible_result["defense_resolution_id"])
	_expect_equal(ineligible_resolution.attempts[0].eligibility_reason, "no_legal_dodge_destination", "A considered but environmentally ineligible Dodge must not roll.")
	_expect_equal(ineligible_resolution.attempts[1].eligibility, CombatDefenseAttempt.ATTEMPTED, "An ineligible Dodge must not exclude the next legal Physical Soak.")
	_expect_equal(ineligible_resolution.successful_defense_type, CombatDefenseProfile.PHYSICAL_SOAK, "Legal Physical Soak must remain available after an ineligible Dodge is skipped.")

	var attempted := _build_pending_attack(
		_find_seed_for_d20_sequence([5, 10]),
		_make_profile(&"automatic_attempt_mutex", PackedStringArray(["dodge", "physical_soak", "weapon_block", "shield_block"]), 0, 0),
		{"dt": 4}
	)
	var attempted_result: Dictionary = attempted["simulation"].resolve_pending_defense_automatically(
		attempted["attack_id"],
		"automatic_attempt_mutex",
		_environment(&"attempt", true, [_candidate(&"legal", Vector2i(1_000_000, 0), 1_000_000)])
	)
	var attempted_resolution: CombatDefenseResolution = attempted["simulation"].get_defense_resolution(attempted_result["defense_resolution_id"])
	_expect_equal(attempted_resolution.attempts[0].eligibility, CombatDefenseAttempt.ATTEMPTED, "A legal automatic Dodge must count as an actual attempt even when it fails.")
	_expect_equal(attempted_resolution.attempts[1].eligibility_reason, "mutually_exclusive_with_dodge", "An actually attempted Dodge must exclude Physical Soak.")


func _test_automatic_dodge_replay_and_two_client_convergence() -> void:
	var seed_value := _find_seed_for_d20_sequence([5, 3])
	var first := _build_pending_attack(seed_value, _make_profile(&"automatic_replay"))
	var second := _build_pending_attack(seed_value, _make_profile(&"automatic_replay"))
	var first_environment := _environment(&"replay", true, [
		_candidate(&"b", Vector2i(-2_000_000, 0), 2_000_000),
		_candidate(&"a", Vector2i(2_000_000, 0), 2_000_000),
	])
	var second_environment := _environment(&"replay", true, [
		_candidate(&"a", Vector2i(2_000_000, 0), 2_000_000),
		_candidate(&"b", Vector2i(-2_000_000, 0), 2_000_000),
	])
	first["simulation"].resolve_pending_defense_automatically(first["attack_id"], "automatic_replay", first_environment)
	second["simulation"].resolve_pending_defense_automatically(second["attack_id"], "automatic_replay", second_environment)
	_expect_equal(first["simulation"].get_state_snapshot(), second["simulation"].get_state_snapshot(), "Automatic Dodge selection must replay identically regardless of candidate input order.")
	_expect_equal(_serialize_events(first["simulation"].get_resolved_events()), _serialize_events(second["simulation"].get_resolved_events()), "Automatic Dodge event histories must be deterministic.")

	var harness := TwoClientSyncHarness.new(seed_value)
	harness.authority.simulation.register_actor(_make_actor(&"attacker", 5, 100))
	harness.authority.simulation.register_actor(_make_actor(&"target", 5, 0))
	harness.authority.simulation.register_defense_profile(&"target", _make_profile(&"automatic_sync"))
	harness.authority.simulation.begin_combat()
	var attack_result: Dictionary = harness.authority.simulation.start_physical_attack(
		&"attacker", &"target", _make_attack(&"automatic_sync"), "automatic_sync_attack", &"torso", true
	)
	var envelopes: Array = harness.authority.publish_due_events(1_000_000)
	harness.authority.simulation.resolve_pending_defense_automatically(
		attack_result["attack_instance_id"],
		"automatic_sync_defense",
		_environment(&"sync", true, [_candidate(&"sync_destination", Vector2i(2_000_000, 0), 2_000_000)])
	)
	envelopes.append_array(harness.authority.publish_current_events())
	for envelope: CombatEventEnvelope in envelopes:
		harness.client_a.receive(envelope)
	for index in range(envelopes.size() - 1, -1, -1):
		harness.client_b.receive(envelopes[index])
	_expect_true(harness.compare_clients()["success"], "Two clients must converge on the authority-selected automatic Dodge state.")
	_expect_equal(harness.client_a.get_state_digest(), harness.authority.get_state_digest(), "Automatic Dodge client state must match the authoritative digest.")


func _build_pending_attack(
	seed_value: int,
	profile: CombatDefenseProfile,
	stat_overrides: Dictionary = {},
	delivery_class: StringName = &"hand_held",
	defense_items_equipped: bool = true,
	damage_types: PackedStringArray = PackedStringArray(["bashing"]),
	is_back_attack: bool = false,
	ducking_policy: StringName = CombatAttackDefinition.DUCKING_UNRESOLVED
) -> Dictionary:
	var simulation := CombatSimulation.new(seed_value)
	simulation.register_actor(_make_actor(&"attacker", 5, 100))
	simulation.register_actor(_make_actor(&"target", 5, 0, stat_overrides, defense_items_equipped))
	simulation.register_defense_profile(&"target", profile)
	simulation.begin_combat()
	var result := simulation.start_physical_attack(
		&"attacker", &"target", _make_attack(&"defense_fixture", delivery_class, damage_types, ducking_policy), "attack_request", &"torso", true,
		PackedStringArray(), is_back_attack
	)
	simulation.advance_to(1_000_000)
	_expect_equal(simulation.get_attack(result["attack_instance_id"]).status, CombatAttackInstance.STATUS_PENDING_DEFENSE, "Defense fixtures require a successful ACC result.")
	return {"simulation": simulation, "attack_id": result["attack_instance_id"]}


func _make_actor(
	actor_id: StringName,
	at_value: int,
	init_value: int,
	stat_overrides: Dictionary = {},
	defense_items_equipped: bool = true
) -> CombatActorDefinition:
	var stats := {
		"hpm": 20, "acc": 20, "at": at_value, "init": init_value, "mr": 10,
		"nal": 1, "dt": 4, "dp": 4, "physical_soak": 5, "rb": 0,
	}
	stats.merge(stat_overrides, true)
	var equipment := PackedStringArray(["fixture_weapon"])
	if actor_id == &"target" and defense_items_equipped:
		equipment.append("fixture_block_weapon")
		equipment.append("fixture_shield")
	return CombatActorDefinition.new(
		actor_id,
		&"test_fixture",
		"Fixture %s" % String(actor_id),
		{
			"str": 8, "end": 8, "spd": 8, "dex": 8, "wis": 8,
			"int": 8, "wit": 8, "man": 8, "luk": 8, "app": 8,
		},
		stats,
		{},
		equipment,
		{},
		{"combat_stats": "TEST-FIXTURE: explicit audited inputs"}
	)


func _make_attack(
	attack_id: StringName,
	delivery_class: StringName = &"hand_held",
	damage_types: PackedStringArray = PackedStringArray(["bashing"]),
	ducking_policy: StringName = CombatAttackDefinition.DUCKING_UNRESOLVED
) -> CombatAttackDefinition:
	return CombatAttackDefinition.new(
		attack_id,
		&"fixture_weapon",
		1,
		true,
		true,
		0,
		{"torso": 0},
		PackedStringArray(["torso"]),
		0,
		5_000_000,
		true,
		PackedStringArray(["TEST-FIXTURE: not production weapon data"]),
		delivery_class,
		damage_types,
		true,
		ducking_policy
	)


func _make_profile(
	profile_id: StringName,
	priority: PackedStringArray = PackedStringArray(["dodge", "weapon_block", "shield_block", "physical_soak"]),
	weapon_block_target: int = 4,
	shield_block_target: int = 4,
	modifiers: Dictionary = {}
) -> CombatDefenseProfile:
	return CombatDefenseProfile.new(
		profile_id,
		priority,
		modifiers,
		CombatBlockDefinition.new(
			CombatBlockDefinition.TYPE_WEAPON, &"fixture_block_weapon", weapon_block_target, 0, true, true, null,
			PackedStringArray(["TEST-FIXTURE: Prime BLK roll boundary"])
		),
		CombatBlockDefinition.new(
			CombatBlockDefinition.TYPE_SHIELD, &"fixture_shield", shield_block_target, 0, true, true, 10,
			PackedStringArray(["TEST-FIXTURE: Prime shield BLK/SHP boundary"])
		),
		PackedStringArray(["TEST-FIXTURE: Arena defense priority"])
	)


func _resolved_dodge(destination: Vector2i, movement_cost_microfeet: int) -> CombatDodgeContext:
	return CombatDodgeContext.new(
		CombatDodgeContext.SELECTION_RESOLVED,
		destination,
		movement_cost_microfeet,
		false,
		true,
		true,
		"TEST-FIXTURE: authoritative path and escape validation"
	)


func _unavailable_dodge() -> CombatDodgeContext:
	return CombatDodgeContext.new(CombatDodgeContext.SELECTION_UNAVAILABLE, Vector2i.ZERO, null, false, false, false, "TEST-FIXTURE")


func _candidate(
	candidate_id: StringName,
	destination_microfeet: Vector2i,
	movement_cost_microfeet: int,
	in_place_duck: bool = false,
	path_clear: bool = true,
	collision_free: bool = true,
	terrain_legal: bool = true,
	unoccupied: bool = true,
	escapes_attack: bool = true,
	duck_legally_sufficient: bool = false,
	known_hazard_score: int = 0
) -> CombatDodgeCandidate:
	return CombatDodgeCandidate.new(
		candidate_id,
		destination_microfeet,
		movement_cost_microfeet,
		in_place_duck,
		path_clear,
		collision_free,
		terrain_legal,
		unoccupied,
		escapes_attack,
		duck_legally_sufficient,
		known_hazard_score,
		"TEST-FIXTURE: authoritative environmental candidate"
	)


func _environment(environment_id: StringName, information_complete: bool, candidates: Array) -> CombatDodgeEnvironment:
	var typed_candidates: Array[CombatDodgeCandidate] = []
	for candidate: CombatDodgeCandidate in candidates:
		typed_candidates.append(candidate)
	return CombatDodgeEnvironment.new(
		environment_id,
		information_complete,
		typed_candidates,
		"TEST-FIXTURE: complete authoritative Dodge environment"
	)


func _find_seed_for_d20_sequence(expected_rolls: Array) -> int:
	for seed_value in range(1, 500_000):
		var preview := DeterministicCombatRng.new(seed_value)
		preview.next_int(1, 10)
		preview.next_int(1, 10)
		var matches := true
		for expected_roll: int in expected_rolls:
			if preview.next_int(1, 20) != expected_roll:
				matches = false
				break
		if matches:
			return seed_value
	assert(false, "Unable to find deterministic fixture seed for requested defense rolls.")
	return 0


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
