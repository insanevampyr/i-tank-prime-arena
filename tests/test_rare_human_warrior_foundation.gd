class_name RareHumanWarriorFoundationTests
extends RefCounted

const Fixture = preload("res://scripts/creatures/rare_human_warrior_fixture.gd")
const ExistingFixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")

var _failures: Array[String] = []


func run() -> Array[String]:
	_failures.clear()
	_test_source_character_definition()
	_test_boar_spear_melee_and_activation_gate()
	_test_scale_mail_location_definitions()
	_test_loadout_inventory_and_unresolved_boundaries()
	_test_deterministic_independent_actor_instances()
	_test_authoritative_spear_damage_and_sync()
	_test_location_protection_and_weapon_block()
	_test_throw_retrieval_and_unarmed_gates()
	_test_existing_fixture_definitions_remain_valid()
	_test_wave_five_remains_inactive()
	return _failures


func _test_source_character_definition() -> void:
	var catalog := CombatDefinitionCatalog.load_default_fixture_catalog()
	var character: CombatCharacterDefinitionResource = catalog.characters.get(String(Fixture.CHARACTER_DEFINITION_ID))
	_expect_true(character != null, "The official Rare Human Warrior definition must load through the shared catalog.")
	if character == null:
		return
	_expect_equal(character.size_category, &"medium", "The sheet's explicit Medium Human classification must be retained.")
	_expect_equal(character.attributes, {
		"str": 18, "end": 4, "spd": 15, "dex": 14, "wis": 10, "int": 8,
		"wit": 19, "man": 12, "luk": 13, "app": 15, "sr": 5,
	}, "Every printed boss attribute must be retained without substitution.")
	for expected: Dictionary in [
		{"field": "hpm", "value": 200}, {"field": "sb", "value": 4},
		{"field": "hpb", "value": 5}, {"field": "mr", "value": 12},
		{"field": "dt", "value": 10}, {"field": "init", "value": 10},
		{"field": "at", "value": 2}, {"field": "acc", "value": 12},
		{"field": "dp", "value": 4}, {"field": "physical_soak", "value": 2},
		{"field": "nal", "value": 1}, {"field": "bm", "value": 10},
		{"field": "mwc", "value": 525}, {"field": "ss", "value": 9},
		{"field": "msl", "value": 9}, {"field": "s_number", "value": 26},
		{"field": "scm", "value": 0}, {"field": "miur", "value": 1},
		{"field": "mns_mrf", "value": 8}, {"field": "rcl", "value": 16},
		{"field": "kp", "value": 0}, {"field": "tof", "value": 2},
	]:
		_expect_equal(character.combat_stats.get(expected["field"]), expected["value"], "Boss derived field %s must match the official sheet or owner correction." % expected["field"])
	_expect_equal(character.resource_maxima, {"mana": 24, "ap": 12}, "Boss Mana and AP maxima must match the official sheet.")
	_expect_equal(character.running_profile.get("running_skill_investment"), 1, "The source-listed single Running investment must remain distinct from automatic three-investment proficiency.")
	_expect_equal(character.proficiencies.get("throw", {}).get("investments"), 2, "The boss's source-listed Throw investments must be retained.")
	_expect_equal(character.proficiencies.get("alertness", {}).get("investments"), 3, "The boss's source-listed Alertness investments must be retained.")
	_expect_equal(character.ability_access.get("printed_levels"), [1, 2, 3], "Combat ability levels 1-3 must be recorded without inventing exact abilities.")
	_expect_true(character.unresolved_fields.has("ability_access.exact_combat_abilities_and_prerequisites"), "Exact Combat ability access must remain an explicit validation gate.")
	_expect_true(character.unresolved_fields.has("combat_stats.rb"), "The blank source RB field must remain unresolved rather than fabricated.")


func _test_boar_spear_melee_and_activation_gate() -> void:
	var catalog := CombatDefinitionCatalog.load_default_fixture_catalog()
	var weapon := catalog.get_weapon(Fixture.WEAPON_REF)
	_expect_true(weapon != null, "The source-linked enchanted Boar Spear must load.")
	if weapon == null:
		return
	_expect_true(weapon.damage_dice_count == 3 and weapon.damage_die_sides == 10 and weapon.fixed_damage_bonus == 8 and weapon.strength_bonus_eligible, "The weapon must store printed 3d10+8(+SB) exactly once.")
	_expect_equal(weapon.damage_types, PackedStringArray(["slashing", "piercing"]), "The official slash-or-pierce modes must remain explicit.")
	_expect_equal(weapon.reach_microfeet, 6_000_000, "Prime V3 BOR SPEAR reach must remain six feet.")
	_expect_equal(weapon.strength_requirement, 15, "Prime V3 BOR SPEAR minimum STR must remain 15.")
	_expect_equal(weapon.effective_hands_required(18), 2, "The STR 18 boss must legally wield the spear with two hands.")
	_expect_equal(weapon.effective_hands_required(30), 1, "The established double-STR rule must permit one-handed use only at STR 30.")
	_expect_equal(weapon.effective_hands_required(14), CombatWeaponDefinitionResource.INVALID_HAND_REQUIREMENT, "Below STR 15 must remain illegal.")
	_expect_equal(weapon.block_target, 6, "The printed 30% weapon Block must be represented as a d20 target of 6.")
	_expect_equal(weapon.enchantment_bonus, 5, "The source-listed +5 enchantment must remain separate metadata.")
	_expect_equal(weapon.enchantment_damage_policy, CombatWeaponDefinitionResource.ENCHANTMENT_INCLUDED_IN_PRINTED_DAMAGE, "The owner-confirmed +5 enchantment must be marked as already included in the printed +8.")
	_expect_equal(weapon.throw_range_formula, &"one_square_per_thrower_strength", "The source throw formula must be retained without inventing a projectile conversion.")
	_expect_true(weapon.combat_ready, "The fully verified spear melee mode must be combat-ready independently of its gated thrown mode.")
	var attack := Fixture.make_melee_attack_definition(CombatHitLocationCatalog.get_same_size_attack_profile())
	_expect_true(attack != null, "The boss fixture must expose the verified Boar Spear melee definition.")
	if attack != null:
		_expect_equal(attack.weapon_ref, Fixture.WEAPON_REF, "The melee action must use the equipped Boar Spear.")
		_expect_equal(attack.maximum_range_microfeet, 6_000_000, "The melee definition must retain six-foot reach.")
		_expect_equal(attack.damage_types, PackedStringArray(["slashing", "piercing"]), "The official slash/pierce modes must remain explicit.")
		_expect_true(attack.physical_damage.dice_count == 3 and attack.physical_damage.die_sides == 10 and attack.physical_damage.flat_bonus == 8 and attack.physical_damage.strength_bonus_eligible == true, "The active melee definition must use 3d10+8 plus eligible SB exactly once.")
	var block: CombatBlockDefinition = weapon.make_block_definition()
	_expect_true(block != null and block.block_target == 6, "The independently source-verified 30% weapon Block representation must remain inspectable.")


func _test_scale_mail_location_definitions() -> void:
	var catalog := CombatDefinitionCatalog.load_default_fixture_catalog()
	var expected := {
		"prime_v3_scale_mail_torso": {"slot": "torso", "str": 10, "dt": -1, "dp": -1, "locations": ["torso"]},
		"prime_v3_scale_mail_head": {"slot": "head", "str": 3, "dt": 0, "dp": 0, "locations": ["head", "neck"]},
		"prime_v3_scale_mail_arms": {"slot": "arms", "str": 3, "dt": 0, "dp": 0, "locations": ["shoulders_upper_arms"]},
		"prime_v3_scale_mail_legs": {"slot": "legs", "str": 10, "dt": -1, "dp": -1, "locations": ["groin_upper_legs", "lower_leg", "feet"]},
		"prime_v3_scale_mail_elbows": {"slot": "elbows", "str": 3, "dt": 0, "dp": 0, "locations": ["elbows"]},
		"prime_v3_scale_mail_knees": {"slot": "knees", "str": 3, "dt": 0, "dp": 0, "locations": ["knee"]},
		"prime_v3_scale_mail_hands": {"slot": "hands", "str": 3, "dt": 0, "dp": 0, "locations": ["hands"]},
	}
	for armor_id: String in expected:
		var armor := catalog.get_armor(StringName(armor_id))
		var fields: Dictionary = expected[armor_id]
		_expect_true(armor != null, "%s must load as a source-verified location-specific Scale definition." % armor_id)
		if armor == null:
			continue
		_expect_equal(String(armor.armor_slot), fields["slot"], "%s must retain its distinct armor slot." % armor_id)
		_expect_equal(armor.strength_requirement, fields["str"], "%s must retain the Prime chart STR requirement." % armor_id)
		_expect_equal(armor.dt_penalty, fields["dt"], "%s must retain the left Dodge/DT penalty." % armor_id)
		_expect_equal(armor.projectile_dodge_penalty, fields["dp"], "%s must retain the right projectile-Dodge penalty." % armor_id)
		_expect_equal(Array(armor.covered_locations), fields["locations"], "%s must retain approved location coverage." % armor_id)
		_expect_equal(armor.tal_by_damage_type, {"slashing": 1, "piercing": 1}, "%s must protect only source-listed Slashing/Piercing at TAL 1." % armor_id)
	var full_scale := catalog.calculate_armor_stat_modifiers(PackedStringArray(Fixture.SCALE_ARMOR_REFS))
	_expect_true(full_scale.get("success", false), "The seven distinct Scale slots must be structurally legal together for validation.")
	_expect_equal(full_scale.get("modifiers"), {"mr": 0, "dt": -2, "dp": -2}, "Source chart penalties must aggregate by location without altering racial NAL.")


func _test_loadout_inventory_and_unresolved_boundaries() -> void:
	var catalog := CombatDefinitionCatalog.load_default_fixture_catalog()
	var loadout := catalog.get_loadout(Fixture.LOADOUT_DEFINITION_ID)
	_expect_true(loadout != null, "The boss source loadout must load.")
	if loadout == null:
		return
	var expected_equipment := PackedStringArray([String(Fixture.WEAPON_REF)])
	expected_equipment.append_array(PackedStringArray(Fixture.SCALE_ARMOR_REFS))
	_expect_equal(loadout.equipment_refs(), expected_equipment, "The authoritative loadout must contain the spear and all seven approved Scale-mail locations.")
	_expect_equal(loadout.armor_refs, PackedStringArray(Fixture.SCALE_ARMOR_REFS), "The complete Scale-mail set must be equipped without duplicate slots.")
	var scale_record: Dictionary = loadout.inventory_records.get("scale_mail", {})
	_expect_equal(scale_record.get("equipped_location_refs"), Array(Fixture.SCALE_ARMOR_REFS), "The source inventory record must identify the same seven equipped armor resources.")
	var potion: Dictionary = loadout.inventory_records.get("health_potion", {})
	_expect_equal(potion.get("quantity"), 2, "The source inventory must retain exactly two Health Potions.")
	_expect_true(potion.get("effect_dice_count") == 1 and potion.get("effect_die_sides") == 10 and potion.get("effect_fixed_bonus") == 2 and potion.get("effect_resource") == "hpc", "Each potion record must preserve the printed 1d10+2 HPC effect.")
	_expect_equal(potion.get("gameplay_supported"), false, "Potion-use gameplay must remain unavailable in this data-only task.")
	_expect_true(not loadout.unresolved_fields.has("equipment.scale_mail_equipped_locations"), "The owner-approved complete Scale-mail ruling must remove the old location gate.")
	var validation := catalog.validate_character_loadout(Fixture.CHARACTER_DEFINITION_ID, Fixture.LOADOUT_DEFINITION_ID)
	_expect_true(validation.get("success", false), "Known boss data must be structurally valid even while source gates remain.")
	_expect_equal(validation.get("status"), "requires_source_verification", "The boss foundation must fail closed for encounter activation rather than fabricate missing rules.")
	_expect_true(not Fixture.get_activation_status().get("encounter_ready", true), "Wave 5 activation must remain explicitly disabled.")


func _test_deterministic_independent_actor_instances() -> void:
	var first_result := Fixture.instantiate_foundation_actor(&"boss_fixture_a", "Boss A")
	var second_result := Fixture.instantiate_foundation_actor(&"boss_fixture_b", "Boss B")
	_expect_true(first_result.get("success", false) and second_result.get("success", false), "The validated definition must create independent data-only actor fixtures.")
	var first: CombatActorDefinition = first_result.get("actor")
	var second: CombatActorDefinition = second_result.get("actor")
	if first == null or second == null:
		return
	_expect_equal(first.combat_stats, second.combat_stats, "Repeated fixture creation must be deterministic.")
	_expect_equal(first.resource_maxima, second.resource_maxima, "Repeated fixture resources must be deterministic.")
	_expect_equal(first.get_base_combat_stat("nal"), 1, "Racial NAL +1 must remain a base actor value independent of Scale-mail TAL.")
	_expect_equal(first.combat_stats.get("nal"), 1, "Equipping Scale mail must not merge armor TAL into racial NAL.")
	_expect_equal(first.equipment_stat_modifiers, {"mr": 0, "dt": -2, "dp": -2}, "Complete Scale-mail penalties must aggregate exactly once.")
	_expect_equal(first.get_base_combat_stat("mr"), 12, "Armor must preserve baseline MR.")
	_expect_equal(first.get_base_combat_stat("dt"), 10, "Armor must preserve baseline DT.")
	_expect_equal(first.get_base_combat_stat("dp"), 4, "Armor must preserve baseline projectile Dodge.")
	_expect_equal(first.combat_stats.get("mr"), 12, "Complete Scale mail has no MR penalty in this seven-piece configuration.")
	_expect_equal(first.combat_stats.get("dt"), 8, "Torso and leg Scale penalties must reduce effective DT from 10 to 8.")
	_expect_equal(first.combat_stats.get("dp"), 2, "Torso and leg Scale penalties must reduce effective projectile Dodge from 4 to 2.")
	var first_state := CombatActorState.new(first)
	var second_state := CombatActorState.new(second)
	first_state.current_hpc = 1
	first_state.resources["mana"] = 0
	_expect_equal(second_state.current_hpc, 200, "One boss instance's mutable HPC must not leak to another.")
	_expect_equal(second_state.resources.get("mana"), 24, "One boss instance's mutable resources must not leak to another.")
	_expect_true(not bool(first_result.get("encounter_ready", true)) and not bool(second_result.get("encounter_ready", true)), "Data actors must not accidentally enable Wave 5.")


func _test_authoritative_spear_damage_and_sync() -> void:
	var selected_seed := -1
	var first: Dictionary = {}
	for seed_value in range(1, 20):
		var candidate := _run_authoritative_spear_transaction(seed_value)
		if candidate.get("success", false):
			selected_seed = seed_value
			first = candidate
			break
	_expect_true(selected_seed > 0, "A deterministic non-critical successful spear transaction must be available for focused verification.")
	if selected_seed <= 0:
		return
	var resolution: CombatDamageResolution = first["damage_resolution"]
	_expect_equal(resolution.flat_bonus, 8, "The spear damage transaction must apply the printed fixed +8 once.")
	_expect_equal(resolution.strength_bonus, 4, "The STR 18 boss must add its eligible SB +4 once.")
	_expect_equal(resolution.pre_multiplier_total, resolution.weapon_dice_total + 12, "The +5 enchantment metadata must not be added again to 3d10+8+SB.")
	_expect_equal(resolution.final_damage, resolution.pre_multiplier_total, "An unarmored NAL-0 torso fixture must receive exactly the verified pre-protection spear total.")

	var second := _run_authoritative_spear_transaction(selected_seed)
	_expect_true(second.get("success", false), "The selected deterministic spear transaction must replay successfully.")
	if second.get("success", false):
		_expect_equal(second.get("events"), first.get("events"), "Same-seed boss melee history must replay identically.")
		_expect_equal(second.get("snapshot"), first.get("snapshot"), "Same-seed boss melee state must replay identically.")

	var harness: TwoClientSyncHarness = first["harness"]
	_expect_true(harness.compare_clients().get("success", false), "Both simulated clients must converge on the authoritative boss melee state.")
	_expect_equal(harness.client_a.get_state_digest(), harness.authority.get_state_digest(), "Client A must match the authoritative boss damage digest.")
	_expect_equal(harness.client_b.get_state_digest(), harness.authority.get_state_digest(), "Client B must match the authoritative boss damage digest.")


func _test_location_protection_and_weapon_block() -> void:
	var protection := Fixture.make_damage_protection_profile(&"boss_protection_test")
	_expect_true(protection != null and protection.armors.size() == 7, "The boss protection profile must contain all seven distinct Scale-mail resources.")
	if protection == null:
		return
	var expected_by_location := {
		"head": "prime_v3_scale_mail_head",
		"neck": "prime_v3_scale_mail_head",
		"torso": "prime_v3_scale_mail_torso",
		"shoulders_upper_arms": "prime_v3_scale_mail_arms",
		"elbows": "prime_v3_scale_mail_elbows",
		"hands": "prime_v3_scale_mail_hands",
		"groin_upper_legs": "prime_v3_scale_mail_legs",
		"knee": "prime_v3_scale_mail_knees",
		"lower_leg": "prime_v3_scale_mail_legs",
		"feet": "prime_v3_scale_mail_legs",
	}
	for location: String in expected_by_location:
		var matching_refs: Array[String] = []
		for armor: CombatArmorDefinition in protection.armors:
			if armor.covered_locations.has(location):
				matching_refs.append(String(armor.equipment_ref))
		_expect_equal(matching_refs, [expected_by_location[location]], "%s must select exactly one legitimate Scale-mail location without TAL stacking." % location)
		var hit := _resolve_boss_armor_hit(StringName(location))
		_expect_true(hit.get("success", false), "A deterministic %s armor transaction must resolve." % location)
		if hit.get("success", false):
			var resolution: CombatDamageResolution = hit["damage_resolution"]
			_expect_equal(String(resolution.armor_equipment_ref), expected_by_location[location], "%s must use its designated armor resource." % location)
			_expect_equal(resolution.armor_tal, 1, "%s must apply Scale TAL 1 exactly once." % location)
			_expect_equal(resolution.natural_armor_level, 1, "%s must then retain separate racial NAL +1." % location)

	var block_result := _find_successful_boss_weapon_block()
	_expect_true(block_result.get("success", false), "The equipped spear must provide a deterministic legal 30% weapon Block opportunity.")
	if block_result.get("success", false):
		var resolution: CombatDefenseResolution = block_result["defense_resolution"]
		_expect_equal(resolution.successful_defense_type, CombatDefenseProfile.WEAPON_BLOCK, "The successful boss defense must be recorded as weapon Block.")
		var attempted_block: CombatDefenseAttempt = null
		for attempt: CombatDefenseAttempt in resolution.attempts:
			if attempt.defense_type == CombatDefenseProfile.WEAPON_BLOCK:
				attempted_block = attempt
				break
		_expect_true(attempted_block != null, "The defense history must retain the independent weapon Block attempt.")
		if attempted_block != null:
			_expect_equal(attempted_block.equipment_ref, Fixture.WEAPON_REF, "The block must require the equipped Boar Spear.")
			_expect_equal(attempted_block.base_target, 6, "A 30% d20 Block must use target 6.")


func _test_throw_retrieval_and_unarmed_gates() -> void:
	var catalog := CombatDefinitionCatalog.load_default_fixture_catalog()
	var weapon := catalog.get_weapon(Fixture.WEAPON_REF)
	_expect_true(weapon.blocked_capabilities.has("thrown_spear_delivery_and_recovery_not_implemented"), "Thrown delivery, dropped position and one-Act recovery must remain a single explicit gate.")
	var attack := Fixture.make_melee_attack_definition(CombatHitLocationCatalog.get_same_size_attack_profile())
	_expect_true(attack != null and attack.delivery_class == &"hand_held", "Task 35D must activate only the hand-held spear mode.")
	var unresolved: PackedStringArray = Fixture.get_activation_status().get("unresolved", PackedStringArray())
	_expect_true(unresolved.has("boar_spear_thrown_delivery_world_location_and_recovery_pipeline"), "Wave 5 must remain gated on the missing authoritative thrown/world-item transaction.")
	_expect_true(unresolved.has("human_unarmed_strength_bonus_and_strikes_per_act"), "Human unarmed fallback must remain gated until SB eligibility and attacks-per-Act are sourced.")
	_expect_true(not Fixture.get_activation_status().get("encounter_ready", true), "Equipment completion must not activate Wave 5.")


func _run_authoritative_spear_transaction(seed_value: int) -> Dictionary:
	var harness := TwoClientSyncHarness.new(seed_value)
	var simulation := harness.authority.simulation
	var boss_result := Fixture.instantiate_foundation_actor(&"boss_attacker", "Rare Human Warrior")
	if not boss_result.get("success", false):
		return {"success": false, "reason": "boss_instantiation", "details": boss_result}
	var boss: CombatActorDefinition = boss_result.get("actor")
	var target := _make_test_actor(&"spear_target", PackedStringArray(), false, 500, 0)
	simulation.register_actor(boss)
	simulation.register_actor(target)
	simulation.get_actor_state(target.actor_id).awareness = &"unaware"
	simulation.register_defense_profile(target.actor_id, _make_no_defense_profile(&"spear_target_defenses"))
	simulation.register_damage_protection_profile(target.actor_id, CombatDamageProtectionProfile.new(&"spear_target_protection"))
	simulation.begin_combat()
	var attack_definition := Fixture.make_melee_attack_definition(CombatHitLocationCatalog.get_same_size_attack_profile())
	var started := simulation.start_physical_attack(boss.actor_id, target.actor_id, attack_definition, "boss_spear_request", &"torso", true)
	if not started.get("success", false):
		return {"success": false, "reason": "attack_start", "details": started}
	simulation.advance_to(2_500_000)
	var attack: CombatAttackInstance = simulation.get_attack(started.get("attack_instance_id", ""))
	if attack == null or attack.status != CombatAttackInstance.STATUS_PENDING_DEFENSE or attack.natural_roll == 1:
		return {"success": false, "reason": "accuracy", "status": "null" if attack == null else attack.status, "natural_roll": null if attack == null else attack.natural_roll}
	var defense := simulation.resolve_pending_defense(attack.attack_instance_id, "boss_spear_defense")
	if defense.get("status") != CombatDefenseResolution.STATUS_EXHAUSTED:
		return {"success": false, "reason": "defense", "details": defense}
	var damage := simulation.resolve_physical_damage(attack.attack_instance_id, "boss_spear_damage")
	if not damage.get("success", false):
		return {"success": false, "reason": "damage", "details": damage}
	var envelopes := harness.authority.publish_current_events()
	harness.deliver_in_order(envelopes)
	var events: Array = []
	for envelope: CombatEventEnvelope in envelopes:
		events.append(envelope.to_dictionary())
	return {
		"success": true,
		"damage_resolution": simulation.get_damage_resolution(damage.get("damage_resolution_id", "")),
		"events": events,
		"snapshot": simulation.get_state_snapshot(),
		"harness": harness,
	}


func _resolve_boss_armor_hit(target_location: StringName) -> Dictionary:
	for seed_value in range(1, 20):
		var simulation := CombatSimulation.new(seed_value)
		var attacker := _make_test_actor(&"armor_attacker", PackedStringArray(["armor_test_weapon"]), true, 100, 0)
		var boss_result := Fixture.instantiate_foundation_actor(&"armored_boss", "Armored Boss")
		var boss: CombatActorDefinition = boss_result.get("actor")
		boss.defensive_capabilities = {"dodge": false, "weapon_block": false, "shield_block": false, "physical_soak": false}
		simulation.register_actor(attacker)
		simulation.register_actor(boss)
		simulation.get_actor_state(boss.actor_id).awareness = &"unaware"
		simulation.register_defense_profile(boss.actor_id, _make_no_defense_profile(&"armor_test_defenses"))
		simulation.register_damage_protection_profile(boss.actor_id, Fixture.make_damage_protection_profile(boss.actor_id))
		simulation.begin_combat()
		var started := simulation.start_physical_attack(attacker.actor_id, boss.actor_id, _make_armor_test_attack(), "armor_hit_%s_%d" % [String(target_location), seed_value], target_location, true)
		if not started.get("success", false):
			continue
		simulation.advance_to(2_500_000)
		var attack: CombatAttackInstance = simulation.get_attack(started.get("attack_instance_id", ""))
		if attack == null or attack.status != CombatAttackInstance.STATUS_PENDING_DEFENSE or attack.natural_roll == 1:
			continue
		var defense := simulation.resolve_pending_defense(attack.attack_instance_id, "armor_defense_%s_%d" % [String(target_location), seed_value])
		if defense.get("status") != CombatDefenseResolution.STATUS_EXHAUSTED:
			continue
		var damage := simulation.resolve_physical_damage(attack.attack_instance_id, "armor_damage_%s_%d" % [String(target_location), seed_value])
		if damage.get("success", false):
			return {"success": true, "damage_resolution": simulation.get_damage_resolution(damage.get("damage_resolution_id", ""))}
	return {"success": false}


func _find_successful_boss_weapon_block() -> Dictionary:
	for seed_value in range(1, 30):
		var simulation := CombatSimulation.new(seed_value)
		var attacker := _make_test_actor(&"block_attacker", PackedStringArray(["armor_test_weapon"]), true, 100, 0)
		var boss_result := Fixture.instantiate_foundation_actor(&"blocking_boss", "Blocking Boss")
		var boss: CombatActorDefinition = boss_result.get("actor")
		boss.defensive_capabilities = {"dodge": false, "weapon_block": true, "shield_block": false, "physical_soak": false}
		simulation.register_actor(attacker)
		simulation.register_actor(boss)
		simulation.get_actor_state(boss.actor_id).conditions.append("held")
		simulation.register_defense_profile(boss.actor_id, Fixture.make_defense_profile(boss.actor_id))
		simulation.register_damage_protection_profile(boss.actor_id, Fixture.make_damage_protection_profile(boss.actor_id))
		simulation.begin_combat()
		var started := simulation.start_physical_attack(attacker.actor_id, boss.actor_id, _make_armor_test_attack(), "block_hit_%d" % seed_value, &"torso", true)
		if not started.get("success", false):
			continue
		simulation.advance_to(2_500_000)
		var attack: CombatAttackInstance = simulation.get_attack(started.get("attack_instance_id", ""))
		if attack == null or attack.status != CombatAttackInstance.STATUS_PENDING_DEFENSE:
			continue
		var defense := simulation.resolve_pending_defense(attack.attack_instance_id, "block_defense_%d" % seed_value)
		if defense.get("status") != CombatDefenseResolution.STATUS_DEFENDED:
			continue
		var resolution: CombatDefenseResolution = simulation.get_defense_resolution(defense.get("defense_resolution_id", ""))
		if resolution != null and resolution.successful_defense_type == CombatDefenseProfile.WEAPON_BLOCK:
			return {"success": true, "defense_resolution": resolution, "seed": seed_value}
	return {"success": false}


func _make_test_actor(
	actor_id: StringName,
	equipment_refs: PackedStringArray,
	is_attacker: bool,
	hpm: int,
	nal: int
) -> CombatActorDefinition:
	return CombatActorDefinition.new(
		actor_id,
		&"task_35d_test_fixture",
		"Task 35D fixture",
		{"str": 10, "end": 10, "spd": 10, "dex": 10, "wis": 10, "int": 10, "wit": 10, "man": 10, "luk": 10, "app": 10},
		{"hpm": hpm, "acc": 100 if is_attacker else 0, "at": 2, "init": 5, "mr": 10, "nal": nal, "dt": 0, "dp": 0, "physical_soak": 0, "rb": 0, "sb": 0},
		{},
		equipment_refs,
		{"dodge": false, "weapon_block": false, "shield_block": false, "physical_soak": false},
		{"fixture": "Task 35D focused deterministic transaction"},
		PackedStringArray(),
		CombatHitLocationCatalog.SIZE_MEDIUM
	)


func _make_no_defense_profile(profile_id: StringName) -> CombatDefenseProfile:
	return CombatDefenseProfile.new(
		profile_id,
		PackedStringArray(["dodge", "weapon_block", "shield_block", "physical_soak"]),
		{}, null, null,
		PackedStringArray(["Task 35D focused no-defense fixture"])
	)


func _make_armor_test_attack() -> CombatAttackDefinition:
	var profile := CombatHitLocationCatalog.get_same_size_attack_profile()
	var damage := CombatPhysicalDamageDefinition.new(
		1, 1, 9, false, true,
		profile.get("location_multipliers", {}),
		null, true, CombatPhysicalDamageDefinition.ROUNDING_FLOOR,
		PackedStringArray(["Task 35D fixed slashing armor fixture"])
	)
	return CombatAttackDefinition.new(
		&"task_35d_armor_test_attack", &"armor_test_weapon", 1, true, true, 0,
		profile.get("acc_modifiers_by_location", {}),
		profile.get("allowed_target_locations", PackedStringArray(["torso"])),
		0, 6_000_000, true,
		PackedStringArray(["Task 35D fixed slashing armor fixture"]),
		&"hand_held", PackedStringArray(["slashing"]), true,
		CombatAttackDefinition.DUCKING_PROHIBITED, damage, CombatCriticalTriggerPolicy.new(),
		false, true
	)


func _test_existing_fixture_definitions_remain_valid() -> void:
	var catalog := CombatDefinitionCatalog.load_default_fixture_catalog()
	var fixtures := [
		[ExistingFixture.CHARACTER_DEFINITION_ID, ExistingFixture.LOADOUT_DEFINITION_ID, "Guard"],
		[ExistingFixture.VAELIS_CHARACTER_DEFINITION_ID, ExistingFixture.VAELIS_LOADOUT_DEFINITION_ID, "Vaelis"],
		[&"prime_v3_common_goblin", &"prime_v3_common_goblin_fists", "Wave 1 Goblin"],
		[&"prime_v3_common_spadoodle", &"prime_v3_common_spadoodle_claws", "Wave 2 Spadoodle"],
		[&"prime_v3_common_skelly", &"prime_v3_common_skelly_claws", "Wave 3 Skelly"],
		[&"prime_v3_uncommon_hades_combat_follower", &"prime_v3_hades_combat_follower_short_sword", "Wave 3 Hades follower"],
		[&"prime_v3_uncommon_mini_gargoyle_swarmer", &"prime_v3_mini_gargoyle_natural_attacks", "Wave 4 Gargoyle"],
	]
	for fixture: Array in fixtures:
		var result := catalog.validate_character_loadout(fixture[0], fixture[1])
		_expect_true(result.get("success", false), "%s definition/loadout validation must remain intact." % fixture[2])


func _test_wave_five_remains_inactive() -> void:
	var waves := ArenaWaveCatalog.definitions()
	var wave_five: Dictionary = waves[4]
	_expect_equal(wave_five.get("wave_id"), "wave_5", "The existing Wave 5 catalog slot must remain stable.")
	var roster: Array = wave_five.get("roster", [])
	_expect_true(roster.size() == 1 and roster[0].get("creature_id") == "rare_human_warrior", "Wave 5 must still configure exactly one Rare Human Warrior.")
	_expect_equal(roster[0].get("creature_integration_status"), "not_implemented", "Task 35C must not activate Wave 5.")


func _expect_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s Expected %s, got %s." % [message, str(expected), str(actual)])
