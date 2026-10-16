extends RefCounted

var _failures: Array[String] = []


func run() -> Array[String]:
	_test_all_thirty_approved_outcomes()
	_test_attack_multiplier_and_exact_damage_order()
	_test_critical_stagger_interruption_and_exact_gate()
	_test_prone_and_one_act_standing()
	_test_pending_perfect_evasion_waits_for_destination()
	_test_rare_shield_contact_and_reaction_boundary()
	_test_reaction_chain_and_two_client_sync()
	_test_backfire_and_weapon_specific_gates()
	return _failures


func _test_all_thirty_approved_outcomes() -> void:
	var expected := [
		"potent_strike", "relentless_follow_up", "perfect_sequence",
		"off_balance", "bad_opening", "disastrous_backfire",
		"perfect_evasion", "wrong_footed", "turnabout",
		"stumble", "hard_fall", "catastrophic_misstep",
		"jarring_parry", "riposte", "masterful_reversal",
		"shaken_guard", "knocked_down", "guard_shattered",
		"shield_bash", "shield_reversal", "devastating_reversal",
		"buckled_guard", "driven_down", "crushing_breakthrough",
		"unshakable", "immovable", "overpowering_resilience",
		"overwhelmed", "brought_down", "crushing_impact",
	]
	var outcomes := CombatCriticalConsequenceCatalog.get_all_outcomes()
	_expect_equal(outcomes.size(), 30, "The ten approved general tables must expose exactly thirty rarity rows.")
	var actual: Array[String] = []
	var supported_effect_types := [
		"damage_multiplier", "critical_reaction", "critical_stagger", "backfire_redirect",
		"perfect_evasion", "prone", "shield_contact_prone", "same_attack_protection",
	]
	for outcome: Dictionary in outcomes:
		actual.append(String(outcome["outcome_id"]))
		_expect_true(not (outcome["effects"] as Array).is_empty(), "Every approved outcome must have an explicit effect descriptor.")
		for effect: Dictionary in outcome["effects"]:
			_expect_true(supported_effect_types.has(String(effect["type"])), "Every approved effect must route to a supported or explicit gated processor.")
	actual.sort()
	expected.sort()
	_expect_equal(actual, expected, "The data catalog must preserve every designer-approved outcome identifier without reviving proposed-table rows.")


func _test_attack_multiplier_and_exact_damage_order() -> void:
	var simulation := _base_simulation(_seed_for_attack_critical(1, 1, 70))
	var damage := CombatPhysicalDamageDefinition.new(
		1, 1, 4, false, true,
		{"torso": {"numerator": 3, "denominator": 2, "source_ref": "PRIME-V3 p.98 fixture"}},
		null, true, CombatPhysicalDamageDefinition.ROUNDING_FLOOR,
		PackedStringArray(["TEST-FIXTURE"])
	)
	var attack_definition := _attack(&"potent_strike_attack", &"fixture_weapon", damage)
	_register_no_defense(simulation, &"target")
	simulation.register_damage_protection_profile(&"target", CombatDamageProtectionProfile.new(&"none"))
	simulation.begin_combat()
	var started := simulation.start_physical_attack(&"attacker", &"target", attack_definition, "potent_request", &"torso", true)
	simulation.advance_to(1_000_000)
	var attack: CombatAttackInstance = simulation.get_attack(started["attack_instance_id"])
	var record := simulation.get_critical_record(attack.critical_record_id)
	_expect_equal(record.outcome_id, &"potent_strike", "A Common physical-attack critical success must select Potent Strike.")
	simulation.resolve_pending_defense(attack.attack_instance_id, "potent_defense")
	var result := simulation.resolve_physical_damage(attack.attack_instance_id, "potent_damage")
	var resolution := simulation.get_damage_resolution(result.get("damage_resolution_id", ""))
	_expect_true(result["success"], "Potent Strike must remain damage-resolvable after legal defenses are exhausted.")
	_expect_equal(resolution.combined_multiplier_numerator, 3, "Potent Strike x2 and torso fixture x1.5 must reduce to exact x3.")
	_expect_equal(resolution.combined_multiplier_denominator, 1, "The exact product must not introduce sequential rounding.")
	_expect_equal(resolution.multiplied_total, 15, "(1 weapon + 4 flat) x2 x1.5 must resolve before TAL/NAL.")
	_expect_equal(resolution.final_damage, 14, "NAL must subtract after the single exact multiplier product.")


func _test_critical_stagger_interruption_and_exact_gate() -> void:
	var simulation := _base_simulation(_seed_for_defense_critical(5, 20, 1, 70), true)
	var block := CombatBlockDefinition.new(CombatBlockDefinition.TYPE_WEAPON, &"block_weapon", 0, 0, true)
	var profile := CombatDefenseProfile.new(&"weapon_failure", PackedStringArray(["weapon_block", "dodge", "shield_block", "physical_soak"]), {}, block)
	simulation.register_defense_profile(&"target", profile)
	simulation.begin_combat()
	var attack_started := simulation.start_physical_attack(&"attacker", &"target", _attack(&"stagger_parent"), "stagger_parent", &"torso", true)
	var committed_action := CombatActionDefinition.new(&"committed_special_fixture", 3, true, true, {"special_resource": 2}, {}, PackedStringArray(["TEST-FIXTURE committed before interruption"]))
	var target_action := simulation.start_action(&"target", committed_action, "committed_action")
	simulation.advance_to(1_000_000)
	simulation.resolve_pending_defense(attack_started["attack_instance_id"], "stagger_defense")
	var record: CombatCriticalRecord = simulation.get_critical_records()[0]
	_expect_equal(record.outcome_id, &"shaken_guard", "A Common weapon-Block critical failure must select Shaken Guard.")
	_expect_equal(simulation.get_action(target_action["action_instance_id"]).status, CombatActionInstance.STATUS_INTERRUPTED, "Critical Stagger must interrupt an unfinished multi-Act action immediately.")
	_expect_equal(simulation.get_action(target_action["action_instance_id"]).interruption_reason, "critical_stagger", "The interruption must retain its critical cause.")
	for pending_event: Dictionary in simulation.get_state_snapshot()["pending_events"]:
		_expect_true(String((pending_event["payload"] as Dictionary).get("action_instance_id", "")) != target_action["action_instance_id"], "Critical Stagger must remove queued progress/finalization events for the interrupted action.")
	_expect_equal(committed_action.resource_commitments, {"special_resource": 2}, "Critical Stagger must not erase an already committed Special resource declaration.")
	_expect_equal(simulation.start_action(&"target", CombatActionDefinition.new(&"blocked_action", 1), "blocked_action")["reason"], "actor_critically_staggered", "Critical Stagger must block ordinary action starts for its exact duration.")
	_expect_equal(simulation.apply_authoritative_position(&"target", Vector2i(1, 0), 0)["reason"], "movement_blocked_by_critical_stagger", "Critical Stagger must block voluntary movement.")
	simulation.advance_to(1_500_000)
	_expect_true(simulation.start_action(&"target", CombatActionDefinition.new(&"after_stagger", 1), "after_stagger")["success"], "The action gate must end exactly 0.5 simulation seconds after application.")


func _test_prone_and_one_act_standing() -> void:
	var simulation := _base_simulation(_seed_for_defense_critical(5, 20, 71, 95), true)
	var block := CombatBlockDefinition.new(CombatBlockDefinition.TYPE_WEAPON, &"block_weapon", 0, 0, true)
	simulation.register_defense_profile(&"target", CombatDefenseProfile.new(&"prone_failure", PackedStringArray(["weapon_block", "dodge", "shield_block", "physical_soak"]), {}, block))
	simulation.begin_combat()
	var attack_started := simulation.start_physical_attack(&"attacker", &"target", _attack(&"prone_parent"), "prone_parent", &"torso", true)
	var falling_action := simulation.start_action(&"target", CombatActionDefinition.new(&"cinematic_falling_attack_fixture", 3), "prone_target_action")
	simulation.advance_to(1_000_000)
	simulation.resolve_pending_defense(attack_started["attack_instance_id"], "prone_defense")
	var record: CombatCriticalRecord = simulation.get_critical_records()[0]
	_expect_equal(record.outcome_id, &"knocked_down", "An Uncommon weapon-Block critical failure must select Knocked Down.")
	_expect_true(simulation.get_actor_state(&"target").conditions.has("prone"), "Knocked Down must set prone without an invented Stagger.")
	_expect_true(not simulation.get_actor_state(&"target").conditions.has("critical_stagger"), "Prone alone must not add a phantom 0.5-second Stagger.")
	_expect_equal(simulation.get_action(falling_action["action_instance_id"]).status, CombatActionInstance.STATUS_IN_PROGRESS, "Hard Fall/prone alone must not cancel a legitimate unfinished cinematic attack.")
	simulation.advance_to(3_000_000)
	_expect_equal(simulation.get_action(falling_action["action_instance_id"]).status, CombatActionInstance.STATUS_COMPLETED, "An unfinished attack preserved through prone must complete at its authoritative effect time.")
	_expect_equal(simulation.start_action(&"target", CombatActionDefinition.new(&"illegal_while_prone", 1), "illegal_while_prone")["reason"], "actor_prone", "Prone must block ordinary actions other than standing.")
	var stand := simulation.start_stand_action(&"target", "stand_once")
	_expect_true(stand["success"], "A prone actor must be able to begin the approved one-Act stand action.")
	simulation.advance_to(4_000_000)
	_expect_true(not simulation.get_actor_state(&"target").conditions.has("prone"), "Completing one Act of standing must clear prone exactly once.")
	_expect_equal(simulation.start_stand_action(&"target", "phantom_stand")["reason"], "actor_not_prone", "An already-standing actor must not accumulate phantom stand costs.")


func _test_pending_perfect_evasion_waits_for_destination() -> void:
	var simulation := _base_simulation(_seed_for_defense_critical(5, 1, 1, 70), false, false, true)
	simulation.register_defense_profile(&"target", CombatDefenseProfile.new(&"dodge_pending"))
	simulation.begin_combat()
	var started := simulation.start_physical_attack(&"attacker", &"target", _attack(&"dodge_parent"), "dodge_parent", &"torso", true)
	simulation.advance_to(1_000_000)
	var incomplete_environment := CombatDodgeEnvironment.new(&"incomplete", false, [], "TEST-FIXTURE incomplete environment")
	var defense := simulation.resolve_pending_defense_automatically(started["attack_instance_id"], "pending_dodge", incomplete_environment)
	var record: CombatCriticalRecord = simulation.get_critical_records()[0]
	_expect_equal(defense["status"], CombatDefenseResolution.STATUS_PENDING_DODGE_DISPLACEMENT, "A critical Dodge with incomplete environment must retain the existing pending displacement boundary.")
	_expect_equal(record.outcome_id, &"perfect_evasion", "A Common Dodge critical success must select Perfect Evasion.")
	_expect_equal(record.consequence_status, CombatCriticalRecord.CONSEQUENCE_PENDING, "Perfect Evasion must remain pending until a legal destination is supplied.")
	_expect_equal(simulation.get_actor_state(&"target").position_microfeet, Vector2i.ZERO, "Pending Perfect Evasion must not teleport or spend movement.")
	var resolved_context := CombatDodgeContext.new(
		CombatDodgeContext.SELECTION_RESOLVED, Vector2i(1_000_000, 0), 1_000_000, false,
		true, true, "TEST-FIXTURE legal destination", &"resolved_step", &"complete_environment",
		true, true, true, 0, "designer-supplied legal destination"
	)
	var completed := simulation.complete_pending_dodge_displacement(started["attack_instance_id"], "complete_pending_dodge", resolved_context)
	_expect_true(completed["success"], "Supplying a verified legal destination must complete the pending Dodge.")
	_expect_equal(record.consequence_status, CombatCriticalRecord.CONSEQUENCE_APPLIED, "Perfect Evasion must apply only after the legal destination validates.")
	_expect_equal(simulation.get_actor_state(&"target").position_microfeet, Vector2i(1_000_000, 0), "Completed Perfect Evasion must use the supplied legal destination without extra movement.")


func _test_rare_shield_contact_and_reaction_boundary() -> void:
	for contact_value: Variant in [true, null]:
		var simulation := _base_simulation(_seed_for_defense_critical(5, 1, 96, 100), true, true)
		var shield := CombatBlockDefinition.new(CombatBlockDefinition.TYPE_SHIELD, &"shield", 20, 0, true, true, 2, PackedStringArray(["PRIME-V3 p.27"]), contact_value)
		var profile := CombatDefenseProfile.new(&"rare_shield", PackedStringArray(["shield_block", "dodge", "weapon_block", "physical_soak"]), {}, null, shield)
		simulation.register_defense_profile(&"target", profile)
		_register_no_defense(simulation, &"attacker")
		simulation.register_critical_reaction_attack(&"target", _attack(&"target_counter", &"counter_weapon"), true)
		simulation.begin_combat()
		var started := simulation.start_physical_attack(&"attacker", &"target", _attack(&"shield_parent"), "shield_parent_%s" % str(contact_value), &"torso", true)
		simulation.advance_to(1_000_000)
		simulation.resolve_pending_defense(started["attack_instance_id"], "shield_defense_%s" % str(contact_value))
		var record: CombatCriticalRecord = simulation.get_critical_records()[0]
		_expect_equal(record.outcome_id, &"devastating_reversal", "A Rare shield-Block success must select Devastating Reversal.")
		_expect_equal(shield.current_shp, 1, "A critical shield-Block success must still spend exactly one SHP.")
		_expect_equal(simulation.get_actor_state(&"attacker").conditions.has("prone"), contact_value == true, "The prone component must require the explicit verified shield-contact predicate.")
		_expect_true(_count_events(simulation, &"critical_reaction_attack_declared") == 1, "The independently legal counterattack must remain available even when shield contact is unverified.")
		if contact_value == null:
			_expect_true(record.consequence_status == CombatCriticalRecord.CONSEQUENCE_PARTIAL, "Unavailable shield-contact prone plus a legal counterattack must record partial application.")


func _test_backfire_and_weapon_specific_gates() -> void:
	var backfire := _base_simulation(_seed_for_attack_critical(20, 96, 100))
	backfire.begin_combat()
	backfire.start_physical_attack(&"attacker", &"target", _attack(&"backfire"), "backfire", &"torso", true)
	backfire.advance_to(1_000_000)
	var backfire_record: CombatCriticalRecord = backfire.get_critical_records()[0]
	_expect_equal(backfire_record.outcome_id, &"disastrous_backfire", "A Rare physical-attack critical failure must select Disastrous Backfire.")
	_expect_equal(backfire_record.consequence_status, CombatCriticalRecord.CONSEQUENCE_BLOCKED, "Backfire must fail closed while verified redirect geometry is unavailable.")
	_expect_equal(backfire.get_actor_state(&"attacker").current_hpc, 30, "Blocked Backfire must never become an automatic undefendable self-hit.")

	for table_id: StringName in [CombatCriticalConsequenceCatalog.DWARVESTEK_FIREARM_TABLE, CombatCriticalConsequenceCatalog.GRENTEK_EXPLOSIVE_TABLE]:
		var policy := CombatCriticalTriggerPolicy.new(&"source_weapon_fixture", 3, 0, 18, table_id, "PRIME-V3 p.138", "PRIME-V3 p.138")
		var simulation := _base_simulation(_seed_for_attack_critical(18, 1, 100))
		simulation.begin_combat()
		simulation.start_physical_attack(&"attacker", &"target", _attack(&"source_weapon", &"fixture_weapon", null, policy), "source_%s" % String(table_id), &"torso", true)
		simulation.advance_to(1_000_000)
		var record: CombatCriticalRecord = simulation.get_critical_records()[0]
		_expect_equal(record.consequence_table_id, table_id, "Dwarvestek/Grentek must retain separate typed consequence tables.")
		_expect_equal(record.consequence_status, CombatCriticalRecord.CONSEQUENCE_BLOCKED, "Source-specific severity themes must stay inert until exact mechanics are verified.")
		_expect_true(record.consequence_reason.contains("unresolved"), "The weapon-specific gate must explain why no jam, scatter, blast, timer or self-damage was invented.")


func _test_reaction_chain_and_two_client_sync() -> void:
	var seed_value := _seed_for_reaction_chain()
	var harness := TwoClientSyncHarness.new(seed_value)
	var simulation: CombatSimulation = harness.authority.simulation
	var damage := CombatPhysicalDamageDefinition.new(1, 1, 0, false, true)
	simulation.register_actor(_actor(&"attacker", 100, PackedStringArray(["fixture_weapon"])))
	simulation.register_actor(_actor(&"target", 0, PackedStringArray()))
	_register_no_defense(simulation, &"target")
	simulation.register_damage_protection_profile(&"target", CombatDamageProtectionProfile.new(&"chain_protection"))
	var definition := _attack(&"chain_attack", &"fixture_weapon", damage)
	simulation.register_critical_reaction_attack(&"attacker", definition, true)
	simulation.begin_combat()
	var started := simulation.start_physical_attack(&"attacker", &"target", definition, "chain_parent", &"torso", true)
	var initial_envelopes := harness.authority.publish_due_events(1_000_000)
	harness.deliver_in_order(initial_envelopes)
	var parent_record: CombatCriticalRecord = simulation.get_critical_records()[0]
	_expect_equal(parent_record.outcome_id, &"relentless_follow_up", "The chain fixture must select the approved follow-up reaction.")
	simulation.resolve_pending_defense(started["attack_instance_id"], "chain_parent_defense")
	simulation.resolve_physical_damage(started["attack_instance_id"], "chain_parent_damage")
	_expect_equal(simulation.get_critical_records().size(), 2, "A reaction ACC critical must create a fresh child critical record without suppressing the parent.")
	var records := simulation.get_critical_records()
	_expect_true((records[1] as CombatCriticalRecord).parent_event_id != parent_record.event_id, "The child critical must retain its reaction-ACC causal parent rather than overwrite the source record.")
	var final_envelopes := harness.authority.publish_current_events()
	for envelope: CombatEventEnvelope in final_envelopes:
		harness.client_a.receive(envelope)
	for index in range(final_envelopes.size() - 1, -1, -1):
		harness.client_b.receive(final_envelopes[index])
	_expect_true(harness.compare_clients()["success"], "Two simulated clients must converge after a deterministic critical-reaction chain delivered out of order.")
	_expect_equal(harness.client_a.get_state_digest(), harness.authority.get_state_digest(), "Client critical-chain state must match the authoritative digest.")


func _base_simulation(seed_value: int, target_block_weapon: bool = false, target_counter_weapon: bool = false, target_dodge: bool = false) -> CombatSimulation:
	var simulation := CombatSimulation.new(seed_value)
	simulation.register_actor(_actor(&"attacker", 100, PackedStringArray(["fixture_weapon"])))
	var target_equipment := PackedStringArray()
	if target_block_weapon:
		target_equipment.append("block_weapon")
	if target_counter_weapon:
		target_equipment.append("counter_weapon")
		target_equipment.append("shield")
	simulation.register_actor(_actor(&"target", 0, target_equipment, target_dodge))
	return simulation



func _actor(actor_id: StringName, initiative: int, equipment: PackedStringArray, include_dodge: bool = false) -> CombatActorDefinition:
	var combat_stats := {"hpm": 30, "acc": 20, "at": 5, "init": initiative, "mr": 10, "nal": 1, "rb": 0, "sb": 0}
	if include_dodge:
		combat_stats["dt"] = 20
		combat_stats["dp"] = 20
	return CombatActorDefinition.new(
		actor_id, &"test_fixture", "Fixture", {"str": 8, "end": 8, "spd": 8, "dex": 8, "wis": 8, "int": 8, "wit": 8, "man": 8, "luk": 8, "app": 8},
		combat_stats, {}, equipment, {}, {"combat_stats": "TEST-FIXTURE"}
	)


func _attack(
	attack_id: StringName,
	weapon_ref: StringName = &"fixture_weapon",
	damage: CombatPhysicalDamageDefinition = null,
	policy: CombatCriticalTriggerPolicy = null
) -> CombatAttackDefinition:
	return CombatAttackDefinition.new(
		attack_id, weapon_ref, 1, true, true, 0, {"torso": 0}, PackedStringArray(["torso"]), 0, 5_000_000, true,
		PackedStringArray(["TEST-FIXTURE"]), &"hand_held", PackedStringArray(["bashing"]), false,
		CombatAttackDefinition.DUCKING_PROHIBITED, damage, policy
	)


func _register_no_defense(simulation: CombatSimulation, actor_id: StringName) -> void:
	simulation.register_defense_profile(actor_id, CombatDefenseProfile.new(&"none_%s" % String(actor_id)))


func _seed_for_attack_critical(natural_d20: int, rarity_min: int, rarity_max: int) -> int:
	for seed_value in range(1, 1_000_000):
		var preview := DeterministicCombatRng.new(seed_value)
		preview.next_int(1, 10)
		preview.next_int(1, 10)
		if preview.next_int(1, 20) == natural_d20:
			var rarity := preview.next_int(1, 100)
			if rarity >= rarity_min and rarity <= rarity_max:
				return seed_value
	assert(false, "Unable to find deterministic attack-critical seed.")
	return 0


func _seed_for_defense_critical(attack_roll: int, defense_roll: int, rarity_min: int, rarity_max: int) -> int:
	for seed_value in range(1, 1_000_000):
		var preview := DeterministicCombatRng.new(seed_value)
		preview.next_int(1, 10)
		preview.next_int(1, 10)
		if preview.next_int(1, 20) != attack_roll or preview.next_int(1, 20) != defense_roll:
			continue
		var rarity := preview.next_int(1, 100)
		if rarity >= rarity_min and rarity <= rarity_max:
			return seed_value
	assert(false, "Unable to find deterministic defense-critical seed.")
	return 0


func _seed_for_reaction_chain() -> int:
	for seed_value in range(1, 2_000_000):
		var preview := DeterministicCombatRng.new(seed_value)
		preview.next_int(1, 10)
		preview.next_int(1, 10)
		if preview.next_int(1, 20) != 1:
			continue
		var parent_rarity := preview.next_int(1, 100)
		if parent_rarity < 71 or parent_rarity > 95:
			continue
		preview.next_int(1, 1)
		if preview.next_int(1, 20) != 1:
			continue
		if preview.next_int(1, 100) <= 70:
			return seed_value
	assert(false, "Unable to find deterministic reaction-chain seed.")
	return 0


func _count_events(simulation: CombatSimulation, event_type: StringName) -> int:
	var count := 0
	for event: CombatEvent in simulation.get_resolved_events():
		if event.event_type == event_type:
			count += 1
	return count


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s Expected %s, got %s." % [message, str(expected), str(actual)])


func _expect_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)
