extends RefCounted

var _failures: Array[String] = []


func run() -> Array[String]:
	_test_natural_and_expanded_trigger_policies()
	_test_rarity_boundaries_and_single_record()
	_test_defensive_trigger_recording()
	_test_inert_effect_and_table_architecture()
	_test_deterministic_replay_and_two_client_convergence()
	return _failures


func _test_natural_and_expanded_trigger_policies() -> void:
	var generic := CombatCriticalTriggerPolicy.new()
	var natural_one := _resolve_attack_for_roll(1, generic, 10, -100)
	_expect_true(natural_one["attack"].critical_success, "Natural 1 must remain critical success regardless of RB and ordinary ACC modifiers.")
	var natural_twenty := _resolve_attack_for_roll(20, generic, 10, 100)
	_expect_true(natural_twenty["attack"].critical_failure, "Natural 20 must remain critical failure regardless of RB and ordinary ACC modifiers.")

	var expanded := CombatCriticalTriggerPolicy.new(
		&"expanded_success_fixture",
		3,
		1,
		20,
		&"",
		"TEST-FIXTURE: source-approved success range 1-3 plus legal +1",
		"PRIME-V3 natural 20",
		PackedStringArray(["ARENA-COMBAT-1.6: +1 expands success only"])
	)
	var expanded_four := _resolve_attack_for_roll(4, expanded, 0, -100)
	_expect_true(expanded_four["attack"].critical_success, "Legal +1 Critical Range must expand success from 1-3 to 1-4.")
	_expect_true(expanded_four["attack"].accuracy_success, "An expanded critical success must retain critical-success resolution.")
	var expanded_record: CombatCriticalRecord = expanded_four["simulation"].get_critical_records()[0]
	_expect_equal(expanded_record.base_critical_success_max, 3, "Critical evidence must retain the source base success range.")
	_expect_equal(expanded_record.success_range_bonus, 1, "Critical evidence must distinguish the legal success-only +1 range modifier.")
	_expect_equal(expanded_record.critical_success_max, 4, "Critical evidence must retain the effective source-approved success range.")
	_expect_equal(expanded_record.trigger_source_ref, "TEST-FIXTURE: source-approved success range 1-3 plus legal +1", "Critical evidence must retain its source reference.")
	var ordinary_five := _resolve_attack_for_roll(5, expanded, 10, 0)
	_expect_true(not ordinary_five["attack"].critical_success, "RB must not expand critical eligibility beyond the natural 1-4 range.")

	var dwarvestek := CombatCriticalTriggerPolicy.new(
		&"dwarvestek_fixture",
		3,
		0,
		18,
		&"",
		"PRIME-V3 p.138 success trigger fixture",
		"PRIME-V3 p.138 failure trigger fixture"
	)
	var failure_eighteen := _resolve_attack_for_roll(18, dwarvestek, 10, 100)
	_expect_true(failure_eighteen["attack"].critical_failure, "A source-specific natural 18-20 failure policy must be representable without applying a consequence.")
	_expect_true(not failure_eighteen["attack"].accuracy_success, "A qualifying expanded critical failure must retain failure classification.")


func _test_rarity_boundaries_and_single_record() -> void:
	var expected := {
		1: CombatCriticalRecord.RARITY_COMMON,
		70: CombatCriticalRecord.RARITY_COMMON,
		71: CombatCriticalRecord.RARITY_UNCOMMON,
		95: CombatCriticalRecord.RARITY_UNCOMMON,
		96: CombatCriticalRecord.RARITY_RARE,
		100: CombatCriticalRecord.RARITY_RARE,
	}
	for roll: int in expected:
		_expect_equal(CombatCriticalRecord.classify_rarity(roll), expected[roll], "Critical d100 boundary %d must classify deterministically." % roll)

	var overlapping_policy := CombatCriticalTriggerPolicy.new(
		&"overlap_fixture", 3, 1, 20, &"", "TEST-FIXTURE", "PRIME-V3 natural 20"
	)
	var resolved := _resolve_attack_for_roll(1, overlapping_policy)
	var simulation: CombatSimulation = resolved["simulation"]
	var attack: CombatAttackInstance = resolved["attack"]
	var records := simulation.get_critical_records()
	_expect_equal(records.size(), 1, "One qualifying roll must create exactly one critical record even when natural and expanded ranges overlap.")
	_expect_true(not attack.critical_record_id.is_empty(), "The source attack must reference its critical record.")
	var record: CombatCriticalRecord = records[0]
	_expect_true(record.rarity_roll >= 1 and record.rarity_roll <= 100, "A qualifying critical must record one authoritative d100 rarity roll.")
	_expect_true(not String(record.outcome_id).is_empty(), "Approved v1.7 general critical outcomes must be assigned from the authoritative rarity row.")
	_expect_true(record.consequence_status != CombatCriticalRecord.CONSEQUENCE_UNASSIGNED, "Approved consequences must leave the former unassigned Task #11 boundary.")
	_expect_equal(simulation.get_actor_state(&"target").current_hpc, 20, "Critical trigger recording alone must not change target HPC.")
	var trigger_event_count := 0
	for event: CombatEvent in simulation.get_resolved_events():
		if event.event_type == &"critical_trigger_recorded":
			trigger_event_count += 1
	_expect_equal(trigger_event_count, 1, "One source roll must emit exactly one critical-trigger event.")


func _test_defensive_trigger_recording() -> void:
	var seed_value := _find_seed_for_attack_defense_critical(5, 1)
	var simulation := CombatSimulation.new(seed_value)
	simulation.register_actor(_actor(&"attacker", 5, 100, true, 10, 0))
	simulation.register_actor(_actor(&"target", 5, 0, false, 10, 10, true))
	var block := CombatBlockDefinition.new(CombatBlockDefinition.TYPE_WEAPON, &"block_weapon", 0, 0, true)
	var profile := CombatDefenseProfile.new(
		&"critical_defense_fixture",
		PackedStringArray(["weapon_block", "dodge", "shield_block", "physical_soak"]),
		{"weapon_block": -100},
		block,
		null,
		PackedStringArray(["TEST-FIXTURE"])
	)
	simulation.register_defense_profile(&"target", profile)
	simulation.begin_combat()
	var attack_result := simulation.start_physical_attack(&"attacker", &"target", _attack(&"defense_trigger"), "defense_trigger_attack", &"torso", true)
	simulation.advance_to(1_000_000)
	var defense_result := simulation.resolve_pending_defense(
		attack_result["attack_instance_id"],
		"defense_trigger_resolution",
		CombatDodgeContext.new(CombatDodgeContext.SELECTION_UNAVAILABLE, Vector2i.ZERO, null, false, false, false, "TEST-FIXTURE")
	)
	var resolution := simulation.get_defense_resolution(defense_result["defense_resolution_id"])
	var attempt: CombatDefenseAttempt = resolution.attempts[0]
	_expect_true(attempt.critical_success, "A natural defensive 1 must retain its generic critical trigger.")
	_expect_true(not attempt.critical_record_id.is_empty(), "A qualifying defensive roll must reference one critical record.")
	_expect_equal(simulation.get_critical_records().size(), 1, "The defensive source roll must create one critical record.")
	_expect_equal(simulation.get_critical_records()[0].resource_commits, attempt.resources_spent, "Critical evidence must preserve the source attempt's authoritative resource record.")


func _test_inert_effect_and_table_architecture() -> void:
	var reaction := CombatCriticalEffectDefinition.new(
		&"fixture_reaction",
		CombatCriticalEffectDefinition.TYPE_IMMEDIATE_REACTION,
		&"fixture_weapon",
		{"range_must_be_legal": true},
		PackedStringArray(["ARENA-COMBAT-1.6 architecture fixture"])
	)
	_expect_equal(reaction.ordinary_act_cost, 0, "Immediate Critical Reactions must remain independent of ordinary Acts.")
	_expect_true(not reaction.counts_as_nac, "Immediate Critical Reactions must remain separate from NACs.")
	_expect_true(reaction.allows_legal_defensive_reactions, "Immediate attack reactions must preserve ordinary legal defenses.")

	var backfire := CombatCriticalEffectDefinition.new(&"fixture_backfire", CombatCriticalEffectDefinition.TYPE_BACKFIRE_THREAT)
	_expect_true(backfire.allows_legal_defensive_reactions, "Backfire threats must be able to preserve source-legal defensive reactions.")
	var stagger := CombatCriticalEffectDefinition.new(&"fixture_stagger", CombatCriticalEffectDefinition.TYPE_CRITICAL_STAGGER)
	_expect_equal(stagger.duration_us, 500_000, "Critical Stagger architecture must carry the approved 0.5-second duration.")
	_expect_true(stagger.interrupts_executing_actions, "Critical Stagger architecture must declare executing-action interruption.")
	_expect_true(stagger.stops_voluntary_movement and stagger.prevents_ordinary_action_start, "Critical Stagger architecture must represent its movement and action-start gates.")

	var table := CombatCriticalTableDefinition.new(
		&"fixture_weapon_table",
		&"physical_attack",
		&"fixture_weapon",
		{"common": ["fixture_outcome"]},
		{"fixture_outcome": {"requires_equipped_weapon": true}},
		false,
		false,
		PackedStringArray(["TEST-FIXTURE: inert table"])
	)
	_expect_true(not table.approved and not table.active, "Unapproved consequence-table fixtures must remain inert.")
	_expect_equal(table.prerequisites_by_outcome["fixture_outcome"]["requires_equipped_weapon"], true, "Weapon-specific consequence prerequisites must be serializable data.")


func _test_deterministic_replay_and_two_client_convergence() -> void:
	var policy := CombatCriticalTriggerPolicy.new(&"sync_expanded", 2, 0, 20, &"", "TEST-FIXTURE", "PRIME-V3 natural 20")
	var seed_value := _find_seed_for_third_roll(2)
	var first := _build_resolved_attack(seed_value, policy)
	var second := _build_resolved_attack(seed_value, policy)
	_expect_equal(first.get_state_snapshot(), second.get_state_snapshot(), "Critical policy, rarity and record state must replay identically.")
	_expect_equal(_serialize_events(first.get_resolved_events()), _serialize_events(second.get_resolved_events()), "Critical trigger events must replay identically.")

	var harness := TwoClientSyncHarness.new(seed_value)
	_configure_attack_simulation(harness.authority.simulation)
	harness.authority.simulation.begin_combat()
	harness.authority.simulation.start_physical_attack(&"attacker", &"target", _attack(&"sync_critical", policy), "sync_critical_request", &"torso", true)
	var envelopes := harness.authority.publish_due_events(1_000_000)
	for envelope: CombatEventEnvelope in envelopes:
		harness.client_a.receive(envelope)
	for index in range(envelopes.size() - 1, -1, -1):
		harness.client_b.receive(envelopes[index])
	_expect_true(harness.compare_clients()["success"], "Both simulated clients must converge on authoritative critical trigger state.")
	_expect_equal(harness.client_a.get_state_digest(), harness.authority.get_state_digest(), "Critical-record observers must match the authoritative digest.")


func _resolve_attack_for_roll(
	target_roll: int,
	policy: CombatCriticalTriggerPolicy,
	roll_bonus: int = 0,
	acc_modifier: int = 0
) -> Dictionary:
	var simulation := CombatSimulation.new(_find_seed_for_third_roll(target_roll))
	_configure_attack_simulation(simulation, roll_bonus)
	simulation.begin_combat()
	var result := simulation.start_physical_attack(
		&"attacker", &"target", _attack(&"roll_fixture", policy, acc_modifier), "roll_fixture_request", &"torso", true
	)
	simulation.advance_to(1_000_000)
	return {"simulation": simulation, "attack": simulation.get_attack(result["attack_instance_id"])}


func _build_resolved_attack(seed_value: int, policy: CombatCriticalTriggerPolicy) -> CombatSimulation:
	var simulation := CombatSimulation.new(seed_value)
	_configure_attack_simulation(simulation)
	simulation.begin_combat()
	simulation.start_physical_attack(&"attacker", &"target", _attack(&"replay_critical", policy), "replay_critical_request", &"torso", true)
	simulation.advance_to(1_000_000)
	return simulation


func _configure_attack_simulation(simulation: CombatSimulation, roll_bonus: int = 0) -> void:
	simulation.register_actor(_actor(&"attacker", 5, 100, true, 10, roll_bonus))
	simulation.register_actor(_actor(&"target", 5, 0, false, 10, 0))


func _actor(
	actor_id: StringName,
	at_value: int,
	init_value: int,
	attacker: bool,
	acc_value: int,
	roll_bonus: int,
	include_block_weapon: bool = false
) -> CombatActorDefinition:
	var equipment := PackedStringArray(["fixture_weapon"]) if attacker else PackedStringArray()
	if include_block_weapon:
		equipment.append("block_weapon")
	return CombatActorDefinition.new(
		actor_id,
		&"test_fixture",
		"Fixture %s" % String(actor_id),
		{"str": 8, "end": 8, "spd": 8, "dex": 8, "wis": 8, "int": 8, "wit": 8, "man": 8, "luk": 8, "app": 8},
		{"hpm": 20, "acc": acc_value, "at": at_value, "init": init_value, "mr": 10, "nal": 1, "dt": 4, "dp": 4, "physical_soak": 5, "rb": roll_bonus},
		{},
		equipment,
		{},
		{"combat_stats": "TEST-FIXTURE explicit audited inputs"}
	)


func _attack(
	attack_id: StringName,
	policy: CombatCriticalTriggerPolicy = null,
	acc_modifier: int = 0
) -> CombatAttackDefinition:
	return CombatAttackDefinition.new(
		attack_id,
		&"fixture_weapon",
		1,
		true,
		true,
		acc_modifier,
		{"torso": 0},
		PackedStringArray(["torso"]),
		0,
		5_000_000,
		true,
		PackedStringArray(["TEST-FIXTURE"]),
		&"hand_held",
		PackedStringArray(["bashing"]),
		false,
		CombatAttackDefinition.DUCKING_PROHIBITED,
		null,
		policy
	)


func _find_seed_for_third_roll(target_roll: int) -> int:
	for seed_value in range(1, 500_000):
		var preview := DeterministicCombatRng.new(seed_value)
		preview.next_int(1, 10)
		preview.next_int(1, 10)
		if preview.next_int(1, 20) == target_roll:
			return seed_value
	assert(false, "Unable to find deterministic critical fixture seed.")
	return 0


func _find_seed_for_attack_defense_critical(attack_roll: int, defense_roll: int) -> int:
	for seed_value in range(1, 500_000):
		var preview := DeterministicCombatRng.new(seed_value)
		preview.next_int(1, 10)
		preview.next_int(1, 10)
		if preview.next_int(1, 20) == attack_roll and preview.next_int(1, 20) == defense_roll:
			return seed_value
	assert(false, "Unable to find deterministic defensive critical fixture seed.")
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
