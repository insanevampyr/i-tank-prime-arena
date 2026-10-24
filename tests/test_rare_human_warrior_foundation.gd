class_name RareHumanWarriorFoundationTests
extends RefCounted

const Fixture = preload("res://scripts/creatures/rare_human_warrior_fixture.gd")
const ExistingFixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")

var _failures: Array[String] = []


func run() -> Array[String]:
	_failures.clear()
	_test_source_character_definition()
	_test_boar_spear_definition_and_activation_gate()
	_test_scale_mail_location_definitions()
	_test_loadout_inventory_and_unresolved_boundaries()
	_test_deterministic_independent_actor_instances()
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


func _test_boar_spear_definition_and_activation_gate() -> void:
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
	_expect_equal(weapon.enchantment_damage_policy, CombatWeaponDefinitionResource.ENCHANTMENT_UNRESOLVED_DO_NOT_APPLY_SEPARATELY, "The unresolved enchantment must never be added on top of the printed +8.")
	_expect_equal(weapon.throw_range_formula, &"one_square_per_thrower_strength", "The source throw formula must be retained without inventing a projectile conversion.")
	_expect_true(not weapon.combat_ready and weapon.make_attack_definition(&"forbidden_wave_five_attack") == null, "Unresolved enchantment and thrown-attack rules must keep the boss weapon unavailable for combat.")
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
	_expect_equal(loadout.equipment_refs(), PackedStringArray([String(Fixture.WEAPON_REF)]), "Only the legally resolved two-handed spear may enter equipped references.")
	_expect_true(loadout.armor_refs.is_empty(), "The sheet's unspecified Scale locations must not be guessed into the equipped loadout.")
	var potion: Dictionary = loadout.inventory_records.get("health_potion", {})
	_expect_equal(potion.get("quantity"), 2, "The source inventory must retain exactly two Health Potions.")
	_expect_true(potion.get("effect_dice_count") == 1 and potion.get("effect_die_sides") == 10 and potion.get("effect_fixed_bonus") == 2 and potion.get("effect_resource") == "hpc", "Each potion record must preserve the printed 1d10+2 HPC effect.")
	_expect_equal(potion.get("gameplay_supported"), false, "Potion-use gameplay must remain unavailable in this data-only task.")
	_expect_true(loadout.unresolved_fields.has("equipment.scale_mail_equipped_locations"), "Exact equipped Scale locations must remain an explicit loadout gate.")
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
	_expect_equal(first.combat_stats.get("nal"), 1, "Racial NAL +1 must remain independent of unresolved Scale-mail TAL.")
	_expect_equal(first.equipment_stat_modifiers, {"mr": 0, "dt": 0, "dp": 0}, "Unresolved Scale locations must not silently apply armor penalties.")
	var first_state := CombatActorState.new(first)
	var second_state := CombatActorState.new(second)
	first_state.current_hpc = 1
	first_state.resources["mana"] = 0
	_expect_equal(second_state.current_hpc, 200, "One boss instance's mutable HPC must not leak to another.")
	_expect_equal(second_state.resources.get("mana"), 24, "One boss instance's mutable resources must not leak to another.")
	_expect_true(not bool(first_result.get("encounter_ready", true)) and not bool(second_result.get("encounter_ready", true)), "Data actors must not accidentally enable Wave 5.")


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
