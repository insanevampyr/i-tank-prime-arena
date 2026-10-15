extends RefCounted

var _failures: Array[String] = []


func run() -> Array[String]:
	_test_weapon_damage_sb_armor_nal_and_minimum()
	_test_damage_types_locations_and_type_responses()
	_test_defense_damage_gating_and_shield_destruction()
	_test_multiplier_precision_and_critical_boundary()
	_test_ducking_eligibility_policies()
	_test_timing_replay_and_two_client_convergence()
	return _failures


func _test_weapon_damage_sb_armor_nal_and_minimum() -> void:
	var armor := _armor(&"torso_armor", &"body", PackedStringArray(["torso"]), {"bashing": 2, "slashing": 3, "piercing": 1})
	var damage := _damage_definition(2, 6, true, true)
	var fixture := _build_damage_fixture(
		_find_seed_for_rolls(5, [4, 3], 6), damage, PackedStringArray(["bashing"]), &"torso", [armor]
	)
	var resolution := _resolve_fixture_damage(fixture, "weapon_sb")
	_expect_equal(resolution.weapon_rolls, [4, 3], "Weapon damage must use the authoritative seeded dice results.")
	_expect_equal(resolution.strength_bonus, 2, "Eligible hand-held physical damage must add the explicit SB value.")
	_expect_equal(resolution.armor_tal, 2, "Applicable torso armor must subtract its bashing TAL.")
	_expect_equal(resolution.natural_armor_level, 1, "NAL must be subtracted after TAL.")
	_expect_equal(resolution.final_damage, 6, "Damage order must be weapon dice plus SB, less TAL, then less NAL.")
	_expect_equal(resolution.hpc_after, 24, "Resolved damage must reduce authoritative HPC exactly once.")

	var combined := _build_damage_fixture(
		_find_seed_for_rolls(5, [4], 6),
		_damage_definition(1, 6, false, true),
		PackedStringArray(["bashing", "piercing"]),
		&"torso",
		[armor]
	)
	var combined_resolution := _resolve_fixture_damage(combined, "combined_types")
	_expect_equal(combined_resolution.armor_tal, 1, "Combined physical damage types must use the lowest applicable armor TAL.")
	_expect_equal(combined_resolution.final_damage, 2, "Combined-type damage must then subtract NAL normally.")

	var heavy_armor := _armor(&"heavy", &"body", PackedStringArray(["torso"]), {"bashing": 99})
	var minimum := _build_damage_fixture(
		_find_seed_for_rolls(5, [1], 6), _damage_definition(1, 6, false, true), PackedStringArray(["bashing"]), &"torso", [heavy_armor]
	)
	var minimum_resolution := _resolve_fixture_damage(minimum, "minimum_one")
	_expect_equal(minimum_resolution.final_damage, 1, "A successfully damaging physical hit must retain the verified minimum of one HPC.")
	_expect_true(minimum_resolution.minimum_one_applied, "Minimum-one application must be explicit in the damage record.")


func _test_damage_types_locations_and_type_responses() -> void:
	var typed_armor := _armor(
		&"typed", &"body", PackedStringArray(["torso"]), {"bashing": 1, "slashing": 2, "piercing": 3}
	)
	for damage_type: String in ["bashing", "slashing", "piercing"]:
		var typed := _build_damage_fixture(
			_find_seed_for_rolls(5, [6], 6),
			_damage_definition(1, 6, false, true),
			PackedStringArray([damage_type]),
			&"torso",
			[typed_armor]
		)
		var typed_resolution := _resolve_fixture_damage(typed, "type_%s" % damage_type)
		_expect_equal(typed_resolution.armor_tal, {"bashing": 1, "slashing": 2, "piercing": 3}[damage_type], "Each verified physical damage type must select its own TAL.")

	var helmet := _armor(&"helmet", &"head", PackedStringArray(["head", "neck"]), {"bashing": 2})
	var leg_armor := _armor(&"leg_armor", &"legs", PackedStringArray(["left_leg", "right_leg", "left_foot", "right_foot"]), {"bashing": 3})
	for location: String in ["head", "neck"]:
		var head_fixture := _build_damage_fixture(
			_find_seed_for_rolls(5, [6], 6), _damage_definition(1, 6, false, true, _unit_locations()), PackedStringArray(["bashing"]), StringName(location), [helmet, leg_armor]
		)
		_expect_equal(_resolve_fixture_damage(head_fixture, "helmet_%s" % location).armor_equipment_ref, &"helmet", "Helmet coverage must include head and neck.")
	for location: String in ["left_leg", "right_leg", "left_foot", "right_foot"]:
		var leg_fixture := _build_damage_fixture(
			_find_seed_for_rolls(5, [6], 6), _damage_definition(1, 6, false, true, _unit_locations()), PackedStringArray(["bashing"]), StringName(location), [helmet, leg_armor]
		)
		_expect_equal(_resolve_fixture_damage(leg_fixture, "leg_%s" % location).armor_equipment_ref, &"leg_armor", "Leg armor coverage must include legs and feet.")

	var immune := _build_damage_fixture(
		_find_seed_for_rolls(5, [6], 6),
		_damage_definition(1, 6, false, true),
		PackedStringArray(["bashing"]),
		&"torso",
		[],
		{"bashing": {"kind": CombatDamageProtectionProfile.RESPONSE_IMMUNE, "source_ref": "TEST-FIXTURE"}}
	)
	_expect_equal(_resolve_fixture_damage(immune, "immune").final_damage, 0, "An explicit verified immunity must override the ordinary minimum-one rule.")

	var weak := _build_damage_fixture(
		_find_seed_for_rolls(5, [4], 6),
		_damage_definition(1, 6, false, true),
		PackedStringArray(["bashing"]),
		&"torso",
		[],
		{"bashing": {"kind": CombatDamageProtectionProfile.RESPONSE_MULTIPLIER, "numerator": 2, "denominator": 1, "stage": CombatDamageProtectionProfile.STAGE_PRE_PROTECTION, "source_ref": "TEST-FIXTURE"}}
	)
	_expect_equal(_resolve_fixture_damage(weak, "weakness").final_damage, 7, "An explicit pre-protection weakness must apply before NAL.")

	var incomplete_armor := _armor(&"incomplete", &"body", PackedStringArray(["torso"]), {"bashing": 2})
	var unresolved_tal := _build_damage_fixture(
		_find_seed_for_d20_sequence([5]), _damage_definition(1, 6, false, true), PackedStringArray(["piercing"]), &"torso", [incomplete_armor]
	)
	unresolved_tal["simulation"].resolve_pending_defense(unresolved_tal["attack_id"], "unresolved_tal_defense")
	_expect_equal(unresolved_tal["simulation"].resolve_physical_damage(unresolved_tal["attack_id"], "unresolved_tal_damage")["reason"], "armor_tal_unresolved", "Missing armor protection for an incoming type must fail closed instead of becoming zero TAL.")


func _test_defense_damage_gating_and_shield_destruction() -> void:
	var block_profile := CombatDefenseProfile.new(
		&"block",
		PackedStringArray(["weapon_block", "dodge", "shield_block", "physical_soak"]),
		{},
		CombatBlockDefinition.new(CombatBlockDefinition.TYPE_WEAPON, &"block_weapon", 20, 0, true),
		null,
		PackedStringArray(["TEST-FIXTURE"])
	)
	var blocked := _build_damage_fixture(
		_find_seed_for_d20_sequence([5, 3]), _damage_definition(1, 6, true, true), PackedStringArray(["bashing"]), &"torso", [], {}, 5, block_profile, true
	)
	var blocked_defense: Dictionary = blocked["simulation"].resolve_pending_defense(blocked["attack_id"], "block_defense")
	_expect_equal(blocked_defense["status"], CombatDefenseResolution.STATUS_DEFENDED, "A successful legal Block must defend the attack.")
	_expect_equal(blocked["simulation"].resolve_physical_damage(blocked["attack_id"], "blocked_damage")["reason"], "attack_not_damage_eligible", "A successful defense must prevent ordinary damage.")
	_expect_equal(blocked["simulation"].get_actor_state(&"target").current_hpc, 30, "A defended attack must not mutate HPC.")

	var failed_block_profile := CombatDefenseProfile.new(
		&"failed_block",
		PackedStringArray(["weapon_block", "dodge", "shield_block", "physical_soak"]),
		{},
		CombatBlockDefinition.new(CombatBlockDefinition.TYPE_WEAPON, &"block_weapon", 0, 0, true),
		null,
		PackedStringArray(["TEST-FIXTURE"])
	)
	var failed_block := _build_damage_fixture(
		_find_seed_for_defense_and_damage(5, 10, 4, 6), _damage_definition(1, 6, false, true), PackedStringArray(["bashing"]), &"torso", [], {}, 5, failed_block_profile, true
	)
	var failed_block_result: Dictionary = failed_block["simulation"].resolve_pending_defense(failed_block["attack_id"], "failed_block_defense")
	_expect_equal(failed_block_result["status"], CombatDefenseResolution.STATUS_EXHAUSTED, "A failed legal defense must leave the attack damage eligible after remaining defenses are exhausted.")
	var failed_block_damage: Dictionary = failed_block["simulation"].resolve_physical_damage(failed_block["attack_id"], "failed_block_damage")
	_expect_true(failed_block_damage["success"], "Damage must resolve after an actual legal defense roll fails.")

	var soak_profile := CombatDefenseProfile.new(
		&"soak",
		PackedStringArray(["physical_soak", "dodge", "weapon_block", "shield_block"]),
		{}, null, null, PackedStringArray(["TEST-FIXTURE"])
	)
	var soaked := _build_damage_fixture(
		_find_seed_for_d20_sequence([5, 3]), _damage_definition(1, 6, true, true), PackedStringArray(["bashing"]), &"torso", [], {}, 5, soak_profile, true, true
	)
	soaked["simulation"].resolve_pending_defense(soaked["attack_id"], "soak_defense")
	_expect_equal(soaked["simulation"].resolve_physical_damage(soaked["attack_id"], "soaked_damage")["reason"], "attack_not_damage_eligible", "Successful Physical Soak must prevent ordinary damage.")

	var exhausted := _build_damage_fixture(
		_find_seed_for_rolls(5, [4], 6), _damage_definition(1, 6, false, true), PackedStringArray(["bashing"])
	)
	exhausted["simulation"].resolve_pending_defense(exhausted["attack_id"], "exhausted_defense")
	var first: Dictionary = exhausted["simulation"].resolve_physical_damage(exhausted["attack_id"], "one_damage")
	var hpc_after: Variant = exhausted["simulation"].get_actor_state(&"target").current_hpc
	_expect_true(first["success"], "An ACC success with exhausted defenses must become damage eligible.")
	_expect_equal(exhausted["simulation"].resolve_physical_damage(exhausted["attack_id"], "one_damage")["reason"], "duplicate_damage_request", "Duplicate damage requests must be rejected.")
	_expect_equal(exhausted["simulation"].resolve_physical_damage(exhausted["attack_id"], "second_damage")["reason"], "attack_not_damage_eligible", "A resolved attack must not apply damage a second time.")
	_expect_equal(exhausted["simulation"].get_actor_state(&"target").current_hpc, hpc_after, "Rejected duplicate damage must not mutate HPC.")

	var shield := CombatBlockDefinition.new(CombatBlockDefinition.TYPE_SHIELD, &"shield", 20, 0, true, true, 1, PackedStringArray(["PRIME-V3 p.27"]))
	var shield_profile := CombatDefenseProfile.new(
		&"shield_destroy", PackedStringArray(["shield_block", "dodge", "weapon_block", "physical_soak"]), {}, null, shield, PackedStringArray(["TEST-FIXTURE"])
	)
	var shield_fixture := _build_damage_fixture(
		_find_seed_for_d20_sequence([5, 3]), _damage_definition(1, 6, false, true), PackedStringArray(["bashing"]), &"torso", [], {}, 5, shield_profile, true
	)
	shield_fixture["simulation"].resolve_pending_defense(shield_fixture["attack_id"], "shield_defense")
	_expect_equal(shield.current_shp, 0, "A successful shield Block must reduce verified SHP by exactly one.")
	_expect_true(not shield.usable, "A shield reaching zero SHP must be permanently unusable.")
	_expect_true(not shield_fixture["simulation"].get_actor_state(&"target").equipment_refs.has("shield"), "A zero-SHP shield must be removed from authoritative equipped-item references.")


func _test_multiplier_precision_and_critical_boundary() -> void:
	var critical := _build_damage_fixture(
		_find_seed_for_d20_sequence([1]), _damage_definition(1, 6, false, true), PackedStringArray(["bashing"])
	)
	critical["simulation"].resolve_pending_defense(critical["attack_id"], "critical_defense")
	var critical_before: int = critical["simulation"].random.get_draw_count()
	var critical_result: Dictionary = critical["simulation"].resolve_physical_damage(critical["attack_id"], "critical_damage")
	_expect_true(critical_result["success"], "An approved critical consequence must no longer hit the former unassigned-effect gate.")
	_expect_equal(critical["simulation"].random.get_draw_count(), critical_before + 1, "Resolved approved critical damage must consume exactly the configured weapon-damage roll.")

	var prime_locations := _unit_locations()
	prime_locations["head"] = {"numerator": 3, "denominator": 2, "source_ref": "PRIME-V3 p.98"}
	prime_locations["neck"] = {"numerator": 3, "denominator": 2, "source_ref": "PRIME-V3 p.98"}
	for location: String in ["head", "neck"]:
		var fractional := _build_damage_fixture(
			_find_seed_for_rolls(5, [5], 6),
			_damage_definition(1, 6, false, true, prime_locations),
			PackedStringArray(["bashing"]),
			StringName(location)
		)
		var fractional_resolution := _resolve_fixture_damage(fractional, "fractional_%s" % location)
		_expect_equal(fractional_resolution.multiplied_total, 7, "Prime head/neck x1.5 must floor 7.5 to 7 exactly once.")
		_expect_equal(fractional_resolution.final_damage, 6, "NAL must subtract after the head/neck product is floored.")
		_expect_equal(fractional_resolution.combined_multiplier_numerator, 3, "Head/neck multiplier numerator must remain exact.")
		_expect_equal(fractional_resolution.combined_multiplier_denominator, 2, "Head/neck multiplier denominator must remain exact.")

	var combined_locations := _unit_locations()
	combined_locations["head"] = {"numerator": 3, "denominator": 2, "source_ref": "PRIME-V3 p.98"}
	var combined_damage := CombatPhysicalDamageDefinition.new(
		1,
		6,
		0,
		false,
		true,
		combined_locations,
		{"numerator": 2, "denominator": 1, "source_ref": "TEST-FIXTURE: source-valid critical multiplier"},
		true,
		CombatPhysicalDamageDefinition.ROUNDING_FLOOR,
		PackedStringArray(["TEST-FIXTURE: exact multiplier composition"])
	)
	var combined_armor := _armor(&"head_armor", &"head", PackedStringArray(["head"]), {"bashing": 2})
	var combined := _build_damage_fixture(
		_find_seed_for_critical_damage(1, 5, 6),
		combined_damage,
		PackedStringArray(["bashing"]),
		&"head",
		[combined_armor],
		{"bashing": {"kind": CombatDamageProtectionProfile.RESPONSE_MULTIPLIER, "numerator": 3, "denominator": 2, "stage": CombatDamageProtectionProfile.STAGE_PRE_PROTECTION, "source_ref": "TEST-FIXTURE: source-valid weakness"}}
	)
	var combined_resolution := _resolve_fixture_damage(combined, "combined_fractional")
	_expect_equal(combined_resolution.weapon_dice_total, 5, "Combined multiplier fixture must retain its verified weapon roll.")
	_expect_equal(combined_resolution.combined_multiplier_numerator, 9, "Critical x2, location x1.5 and weakness x1.5 must combine to an exact 9/2 product.")
	_expect_equal(combined_resolution.combined_multiplier_denominator, 2, "Combined fractional factors must retain one exact denominator.")
	_expect_equal(combined_resolution.multiplied_total, 22, "5 x 2 x 1.5 x 1.5 must floor once from 22.5 to 22.")
	_expect_equal(combined_resolution.armor_tal, 2, "TAL must subtract only after the complete product is floored.")
	_expect_equal(combined_resolution.natural_armor_level, 1, "NAL must subtract after TAL.")
	_expect_equal(combined_resolution.final_damage, 19, "Combined fractional damage must be floor-once, then TAL, then NAL.")


func _test_ducking_eligibility_policies() -> void:
	var candidates: Array[CombatDodgeCandidate] = [
		CombatDodgeCandidate.new(&"step", Vector2i(1_000_000, 0), 1_000_000, false, true, true, true, true, true, false, 0, "TEST-FIXTURE"),
		CombatDodgeCandidate.new(&"duck", Vector2i.ZERO, 0, true, true, true, true, true, true, true, 0, "PRIME-V3 p.20 geometry fixture"),
	]
	var environment := CombatDodgeEnvironment.new(&"duck_policy", true, candidates, "TEST-FIXTURE")
	for policy: StringName in [CombatAttackDefinition.DUCKING_ALLOWED, CombatAttackDefinition.DUCKING_PROHIBITED, CombatAttackDefinition.DUCKING_UNRESOLVED]:
		var fixture := _build_dodge_fixture(_find_seed_for_d20_sequence([5, 3]), policy)
		var result: Dictionary = fixture["simulation"].resolve_pending_defense_automatically(fixture["attack_id"], "duck_%s" % String(policy), environment)
		var resolution: CombatDefenseResolution = fixture["simulation"].get_defense_resolution(result["defense_resolution_id"])
		var selected := String(resolution.attempts[0].resolution_context.get("candidate_id", ""))
		var expected := "duck" if policy == CombatAttackDefinition.DUCKING_ALLOWED else "step"
		_expect_equal(selected, expected, "Ducking policy must gate only the in-place duck candidate while preserving independently legal movement.")

	var only_duck_environment := CombatDodgeEnvironment.new(
		&"only_duck", true, [candidates[1]], "TEST-FIXTURE"
	)
	var unresolved := _build_dodge_fixture(_find_seed_for_d20_sequence([5, 3]), CombatAttackDefinition.DUCKING_UNRESOLVED)
	var unresolved_result: Dictionary = unresolved["simulation"].resolve_pending_defense_automatically(unresolved["attack_id"], "unresolved_only_duck", only_duck_environment)
	var unresolved_resolution: CombatDefenseResolution = unresolved["simulation"].get_defense_resolution(unresolved_result["defense_resolution_id"])
	_expect_equal(unresolved_resolution.status, CombatDefenseResolution.STATUS_PENDING_DODGE_DISPLACEMENT, "Unresolved duck eligibility must retain the pending-displacement boundary when no independent destination exists.")
	_expect_equal(unresolved_resolution.pending_dodge_context.get("selection_reason"), "attack_ducking_policy_unresolved", "The pending boundary must identify the unresolved attack policy.")


func _test_timing_replay_and_two_client_convergence() -> void:
	for at_value: int in [10, 12]:
		var fixture := _build_damage_fixture(
			_find_seed_for_rolls(5, [4], 6), _damage_definition(1, 6, false, true), PackedStringArray(["bashing"]), &"torso", [], {}, at_value
		)
		var expected_time := 500_000 if at_value == 10 else 416_667
		_expect_equal(fixture["simulation"].get_attack(fixture["attack_id"]).resolved_at_us, expected_time, "AT 10/12 timing must remain on the deterministic integer-time boundary.")

	var seed_value := _find_seed_for_rolls(5, [4, 3], 6)
	var first := _build_damage_fixture(seed_value, _damage_definition(2, 6, true, true), PackedStringArray(["bashing"]))
	var second := _build_damage_fixture(seed_value, _damage_definition(2, 6, true, true), PackedStringArray(["bashing"]))
	_resolve_fixture_damage(first, "replay")
	_resolve_fixture_damage(second, "replay")
	_expect_equal(first["simulation"].get_state_snapshot(), second["simulation"].get_state_snapshot(), "Equal seeds and inputs must reproduce damage state exactly.")
	_expect_equal(_serialize_events(first["simulation"].get_resolved_events()), _serialize_events(second["simulation"].get_resolved_events()), "Damage event histories must replay deterministically.")

	var harness := TwoClientSyncHarness.new(seed_value)
	_configure_simulation(harness.authority.simulation, _damage_definition(2, 6, true, true), PackedStringArray(["bashing"]), &"torso", [], {}, 5)
	harness.authority.simulation.begin_combat()
	var attack_result: Dictionary = harness.authority.simulation.start_physical_attack(&"attacker", &"target", _attack(&"sync", _damage_definition(2, 6, true, true), PackedStringArray(["bashing"])), "sync_attack", &"torso", true)
	harness.authority.simulation.advance_to(1_000_000)
	harness.authority.simulation.resolve_pending_defense(attack_result["attack_instance_id"], "sync_defense")
	harness.authority.simulation.resolve_physical_damage(attack_result["attack_instance_id"], "sync_damage")
	var envelopes: Array = harness.authority.publish_current_events()
	for envelope: CombatEventEnvelope in envelopes:
		harness.client_a.receive(envelope)
	for index in range(envelopes.size() - 1, -1, -1):
		harness.client_b.receive(envelopes[index])
	_expect_true(harness.compare_clients()["success"], "Both simulated clients must converge on authoritative damage state despite out-of-order delivery.")
	_expect_equal(harness.client_a.get_state_digest(), harness.authority.get_state_digest(), "Client damage state must match the authoritative digest.")


func _build_damage_fixture(
	seed_value: int,
	damage: CombatPhysicalDamageDefinition,
	damage_types: PackedStringArray,
	target_location: StringName = &"torso",
	armors: Array = [],
	type_responses: Dictionary = {},
	at_value: int = 5,
	defense_profile: CombatDefenseProfile = null,
	include_defense_equipment: bool = false,
	physical_soak_eligible: bool = false
) -> Dictionary:
	var simulation := CombatSimulation.new(seed_value)
	_configure_simulation(simulation, damage, damage_types, target_location, armors, type_responses, at_value, defense_profile, include_defense_equipment, physical_soak_eligible)
	simulation.begin_combat()
	var result: Dictionary = simulation.start_physical_attack(
		&"attacker", &"target", _attack(&"damage_fixture", damage, damage_types, target_location, physical_soak_eligible), "attack_request", target_location, true
	)
	var due_time := _ceil_div(5_000_000, at_value)
	simulation.advance_to(due_time)
	_expect_equal(simulation.get_attack(result["attack_instance_id"]).status, CombatAttackInstance.STATUS_PENDING_DEFENSE, "Damage fixtures require successful ACC resolution.")
	return {"simulation": simulation, "attack_id": result["attack_instance_id"]}


func _configure_simulation(
	simulation: CombatSimulation,
	damage: CombatPhysicalDamageDefinition,
	damage_types: PackedStringArray,
	target_location: StringName,
	armors: Array,
	type_responses: Dictionary,
	at_value: int,
	defense_profile: CombatDefenseProfile = null,
	include_defense_equipment: bool = false,
	physical_soak_eligible: bool = false
) -> void:
	simulation.register_actor(_actor(&"attacker", at_value, 100, true, 2, 1, include_defense_equipment, physical_soak_eligible))
	simulation.register_actor(_actor(&"target", at_value, 0, false, 0, 1, include_defense_equipment, physical_soak_eligible, armors))
	var actual_profile := defense_profile
	if actual_profile == null:
		actual_profile = CombatDefenseProfile.new(&"none", PackedStringArray(["dodge", "weapon_block", "shield_block", "physical_soak"]), {}, null, null, PackedStringArray(["TEST-FIXTURE"]))
	simulation.register_defense_profile(&"target", actual_profile)
	var typed_armors: Array[CombatArmorDefinition] = []
	for armor: CombatArmorDefinition in armors:
		typed_armors.append(armor)
	simulation.register_damage_protection_profile(&"target", CombatDamageProtectionProfile.new(&"target_protection", typed_armors, type_responses, PackedStringArray(["TEST-FIXTURE"])))


func _resolve_fixture_damage(fixture: Dictionary, request_suffix: String) -> CombatDamageResolution:
	var simulation: CombatSimulation = fixture["simulation"]
	var attack_id: String = fixture["attack_id"]
	var defense: Dictionary = simulation.resolve_pending_defense(attack_id, "%s_defense" % request_suffix)
	_expect_equal(defense.get("status"), CombatDefenseResolution.STATUS_EXHAUSTED, "Fixture defenses must be exhausted before damage.")
	var result: Dictionary = simulation.resolve_physical_damage(attack_id, "%s_damage" % request_suffix)
	_expect_true(result.get("success", false), "A fully verified fixture must resolve physical damage.")
	return simulation.get_damage_resolution(result.get("damage_resolution_id", ""))


func _build_dodge_fixture(seed_value: int, ducking_policy: StringName) -> Dictionary:
	var simulation := CombatSimulation.new(seed_value)
	simulation.register_actor(_actor(&"attacker", 5, 100, true, 0, 1, false, false))
	simulation.register_actor(_actor(&"target", 5, 0, false, 0, 1, false, false, [], true))
	var profile := CombatDefenseProfile.new(&"dodge", PackedStringArray(["dodge", "weapon_block", "shield_block", "physical_soak"]), {}, null, null, PackedStringArray(["TEST-FIXTURE"]))
	simulation.register_defense_profile(&"target", profile)
	simulation.begin_combat()
	var definition := _attack(&"duck_fixture", _damage_definition(1, 6, false, true), PackedStringArray(["bashing"]), &"torso", false, ducking_policy)
	var result: Dictionary = simulation.start_physical_attack(&"attacker", &"target", definition, "duck_attack", &"torso", true)
	simulation.advance_to(1_000_000)
	return {"simulation": simulation, "attack_id": result["attack_instance_id"]}


func _actor(
	actor_id: StringName,
	at_value: int,
	init_value: int,
	attacker: bool,
	sb_value: int,
	nal_value: int,
	include_defense_equipment: bool,
	include_soak: bool,
	armors: Array = [],
	include_dodge: bool = false
) -> CombatActorDefinition:
	var stats := {"hpm": 30, "acc": 20, "at": at_value, "init": init_value, "mr": 10, "nal": nal_value, "rb": 0, "sb": sb_value}
	if include_soak:
		stats["physical_soak"] = 20
	if include_dodge:
		stats["dt"] = 20
		stats["dp"] = 20
	var equipment := PackedStringArray(["fixture_weapon"]) if attacker else PackedStringArray()
	if include_defense_equipment and not attacker:
		equipment.append("block_weapon")
		equipment.append("shield")
	for armor: CombatArmorDefinition in armors:
		if not equipment.has(String(armor.equipment_ref)):
			equipment.append(String(armor.equipment_ref))
	return CombatActorDefinition.new(
		actor_id, &"test_fixture", "Fixture %s" % String(actor_id),
		{"str": 8, "end": 8, "spd": 8, "dex": 8, "wis": 8, "int": 8, "wit": 8, "man": 8, "luk": 8, "app": 8},
		stats, {}, equipment, {}, {"combat_stats": "TEST-FIXTURE explicit audited inputs"}
	)


func _attack(
	attack_id: StringName,
	damage: CombatPhysicalDamageDefinition,
	damage_types: PackedStringArray,
	target_location: StringName = &"torso",
	physical_soak_eligible: bool = false,
	ducking_policy: StringName = CombatAttackDefinition.DUCKING_PROHIBITED
) -> CombatAttackDefinition:
	var locations := PackedStringArray(["torso"])
	if not locations.has(String(target_location)):
		locations.append(String(target_location))
	var modifiers := {"torso": 0}
	modifiers[String(target_location)] = 0
	return CombatAttackDefinition.new(
		attack_id, &"fixture_weapon", 1, true, true, 0, modifiers, locations, 0, 5_000_000, true,
		PackedStringArray(["TEST-FIXTURE"]), &"hand_held", damage_types, physical_soak_eligible, ducking_policy, damage
	)


func _damage_definition(
	dice_count: int,
	die_sides: int,
	sb_eligible: bool,
	minimum_one: bool,
	locations: Dictionary = {"torso": {"numerator": 1, "denominator": 1, "source_ref": "TEST-FIXTURE"}}
) -> CombatPhysicalDamageDefinition:
	return CombatPhysicalDamageDefinition.new(
		dice_count, die_sides, 0, sb_eligible, minimum_one, locations, null, false,
		CombatPhysicalDamageDefinition.ROUNDING_UNRESOLVED, PackedStringArray(["TEST-FIXTURE"])
	)


func _armor(equipment_ref: StringName, slot: StringName, locations: PackedStringArray, tal: Dictionary) -> CombatArmorDefinition:
	return CombatArmorDefinition.new(equipment_ref, slot, locations, tal, PackedStringArray(["TEST-FIXTURE"]))


func _unit_locations() -> Dictionary:
	var result := {}
	for location: String in ["torso", "head", "neck", "left_leg", "right_leg", "left_foot", "right_foot"]:
		result[location] = {"numerator": 1, "denominator": 1, "source_ref": "TEST-FIXTURE"}
	return result


func _find_seed_for_rolls(acc_roll: int, damage_rolls: Array, die_sides: int) -> int:
	for seed_value in range(1, 500_000):
		var preview := DeterministicCombatRng.new(seed_value)
		preview.next_int(1, 10)
		preview.next_int(1, 10)
		if preview.next_int(1, 20) != acc_roll:
			continue
		var matches := true
		for expected: int in damage_rolls:
			if preview.next_int(1, die_sides) != expected:
				matches = false
				break
		if matches:
			return seed_value
	assert(false, "Unable to find deterministic damage seed.")
	return 0


func _find_seed_for_d20_sequence(expected_rolls: Array) -> int:
	for seed_value in range(1, 500_000):
		var preview := DeterministicCombatRng.new(seed_value)
		preview.next_int(1, 10)
		preview.next_int(1, 10)
		var matches := true
		for expected: int in expected_rolls:
			if preview.next_int(1, 20) != expected:
				matches = false
				break
		if matches:
			return seed_value
	assert(false, "Unable to find deterministic d20 sequence seed.")
	return 0


func _find_seed_for_defense_and_damage(acc_roll: int, defense_roll: int, damage_roll: int, die_sides: int) -> int:
	for seed_value in range(1, 500_000):
		var preview := DeterministicCombatRng.new(seed_value)
		preview.next_int(1, 10)
		preview.next_int(1, 10)
		if preview.next_int(1, 20) == acc_roll \
		and preview.next_int(1, 20) == defense_roll \
		and preview.next_int(1, die_sides) == damage_roll:
			return seed_value
	assert(false, "Unable to find deterministic defense/damage seed.")
	return 0


func _find_seed_for_critical_damage(acc_roll: int, damage_roll: int, die_sides: int) -> int:
	for seed_value in range(1, 500_000):
		var preview := DeterministicCombatRng.new(seed_value)
		preview.next_int(1, 10)
		preview.next_int(1, 10)
		if preview.next_int(1, 20) != acc_roll:
			continue
		preview.next_int(1, 100)
		if preview.next_int(1, die_sides) == damage_roll:
			return seed_value
	assert(false, "Unable to find deterministic critical damage seed.")
	return 0


func _ceil_div(numerator: int, denominator: int) -> int:
	@warning_ignore("integer_division")
	return (numerator + denominator - 1) / denominator


func _serialize_events(events: Array) -> Array:
	var result: Array = []
	for event: CombatEvent in events:
		result.append(event.to_dictionary())
	return result


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s Expected %s, got %s." % [message, str(expected), str(actual)])


func _expect_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)
