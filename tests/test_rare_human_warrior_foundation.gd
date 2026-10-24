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
	_test_deterministic_thrown_landing()
	_test_spear_geometry_resolvers_release_simulation()
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
	_expect_true(not weapon.blocked_capabilities.has("automatic_thrown_landing_position_policy_unverified"), "Task 35E-Fix1 must resolve the former automatic landing gate.")
	var profile := CombatHitLocationCatalog.get_same_size_attack_profile()
	var attack := Fixture.make_melee_attack_definition(profile)
	var thrown := Fixture.make_thrown_attack_definition(profile)
	var unarmed := Fixture.make_unarmed_attack_definition(profile)
	_expect_true(attack != null and attack.delivery_class == &"hand_held", "The verified hand-held spear mode must remain available.")
	_expect_true(thrown != null and thrown.delivery_class == &"thrown", "The boss fixture must expose the source-verified thrown spear delivery.")
	if thrown != null:
		_expect_equal(thrown.maximum_range_microfeet, 18_000_000, "The specific one-square-per-STR boss rule must resolve STR 18 to 18 feet, not the generic chart's longer range.")
		_expect_equal(thrown.damage_types, PackedStringArray(["piercing"]), "Prime's thrown Boar Spear mode must retain Piercing delivery.")
		_expect_true(thrown.physical_damage.strength_bonus_eligible == true, "Prime thrown physical weapons must retain eligible SB.")
	_expect_true(unarmed != null and unarmed.delivery_class == &"hand_held", "The source-verified Human unarmed fallback must be available.")
	if unarmed != null:
		_expect_true(unarmed.physical_damage.dice_count == 1 and unarmed.physical_damage.die_sides == 4 and unarmed.physical_damage.strength_bonus_eligible == true, "Unarmed fallback must use Prime's 1d4 Bashing plus eligible SB.")
		_expect_equal(unarmed.maximum_range_microfeet, 1_000_000, "Unarmed fallback must retain one-foot reach.")
		_expect_equal(unarmed.strikes_per_act, 1, "The Human fallback must use one generic Unarmed Strike per Act and must not copy Goblin two-fist sequencing.")
		_expect_true(not unarmed.requires_equipped_weapon and not unarmed.requires_hand_occupancy, "A natural unarmed strike must not masquerade as held equipment.")
	var supported := _run_throw_retrieval_unarmed_transaction(4)
	_expect_true(supported.get("success", false), "The source-supported throw, pending landing, movement-gated retrieval and unarmed fallback must complete deterministically.")
	if supported.get("success", false):
		_expect_equal(supported.get("throw_damage_flat_bonus"), 8, "Thrown spear damage must retain the printed +8 exactly once.")
		_expect_equal(supported.get("throw_damage_strength_bonus"), 4, "Thrown spear damage must add the boss's eligible SB +4 exactly once.")
		_expect_true(bool(supported.get("pending_landing_observed", false)), "A resolved throw must relinquish the spear into an explicit pending-landing state.")
		_expect_true(bool(supported.get("retrieval_required_movement", false)), "Retrieval must remain illegal until authoritative pickup reach is satisfied by movement.")
		_expect_equal(supported.get("retrieval_duration_us"), 2_500_000, "AT 2 one-Act retrieval must take exactly 2.5 seconds.")
		_expect_equal(supported.get("unarmed_strength_bonus"), 4, "The unarmed fallback must apply the source-verified boss SB +4.")
	var replay := _run_throw_retrieval_unarmed_transaction(4)
	_expect_true(replay.get("success", false), "The same-seed Task 35E transaction must replay successfully.")
	if supported.get("success", false) and replay.get("success", false):
		_expect_equal(replay.get("events"), supported.get("events"), "Throw, landing, unarmed fallback and retrieval event history must replay exactly.")
		_expect_equal(replay.get("snapshot"), supported.get("snapshot"), "World-item and equipment state must replay exactly.")
		var harness: TwoClientSyncHarness = supported.get("harness")
		_expect_true(harness.compare_clients().get("success", false), "Task 35E authoritative history must converge on both simulated clients.")
	var interrupted := _run_interrupted_retrieval_transaction()
	_expect_true(interrupted.get("success", false), "An interrupted retrieval must leave the spear dropped and unavailable.")
	var miss_and_defense := _verify_throw_miss_defense_and_boundaries()
	_expect_true(miss_and_defense.get("success", false), "Thrown miss, successful defense, range and LOS boundaries must remain deterministic and source-safe.")
	var unresolved: PackedStringArray = Fixture.get_activation_status().get("unresolved", PackedStringArray())
	_expect_true(not unresolved.has("automatic_boar_spear_miss_block_hit_landing_position_policy"), "The designer-approved deterministic landing rule must replace the former source gate.")
	_expect_true(not Fixture.get_activation_status().get("encounter_ready", true), "Equipment completion must not activate Wave 5.")


func _run_throw_retrieval_unarmed_transaction(seed_value: int) -> Dictionary:
	var harness := TwoClientSyncHarness.new(seed_value)
	var simulation := harness.authority.simulation
	var boss_result := Fixture.instantiate_foundation_actor(&"task35e_boss", "Task 35E Boss")
	var boss: CombatActorDefinition = boss_result.get("actor")
	var target := _make_test_actor(&"task35e_target", PackedStringArray(), false, 500, 0)
	if boss == null:
		return {"success": false, "reason": "boss_instantiation"}
	simulation.register_actor(boss)
	simulation.register_actor(target)
	if not simulation.configure_actor_hand_occupancy(boss.actor_id, {"left": String(Fixture.WEAPON_REF), "right": String(Fixture.WEAPON_REF)}).get("success", false):
		return {"success": false, "reason": "two_hand_configuration"}
	simulation.get_actor_state(target.actor_id).position_microfeet = Vector2i(1_000_000, 0)
	simulation.get_actor_state(target.actor_id).awareness = &"unaware"
	simulation.register_defense_profile(target.actor_id, _make_no_defense_profile(&"task35e_no_defense"))
	simulation.register_damage_protection_profile(target.actor_id, CombatDamageProtectionProfile.new(&"task35e_target_protection"))
	var landing_position := Vector2i(1_000_000, 0)
	var battlefield := ArenaBattlefield.create_open(Rect2i(-20_000_000, -20_000_000, 60_000_000, 40_000_000))
	Fixture.configure_spear_landing_geometry(simulation, battlefield)
	var pickup_simulation_reference: WeakRef = weakref(simulation)
	simulation.set_world_item_pickup_resolver(func(actor_id: StringName, item: Dictionary) -> Dictionary:
		var active_simulation: CombatSimulation = pickup_simulation_reference.get_ref()
		return {
			"success": active_simulation != null \
				and active_simulation.get_actor_state(actor_id).position_microfeet == item.get("position_microfeet"),
			"reason": "world_item_out_of_pickup_reach",
		}
	)
	simulation.begin_combat()
	var started := Fixture.start_spear_throw(simulation, boss.actor_id, target.actor_id, "task35e_throw", &"torso", true)
	if not started.get("success", false):
		return {"success": false, "reason": "throw_start", "details": started}
	var action: CombatActionInstance = simulation.get_action(String(started.get("action_instance_id", "")))
	simulation.advance_to(2_500_000)
	var attack: CombatAttackInstance = simulation.get_attack(String(started.get("attack_instance_id", "")))
	if attack == null or attack.status != CombatAttackInstance.STATUS_PENDING_DEFENSE:
		return {"success": false, "reason": "throw_accuracy", "status": "null" if attack == null else attack.status}
	var state := simulation.get_actor_state(boss.actor_id)
	var world_item_id := String(started.get("world_item_id", ""))
	var pending_item := simulation.get_world_item(world_item_id)
	var pending_observed := not state.equipment_refs.has(String(Fixture.WEAPON_REF)) \
		and not state.hand_occupancy.values().has(String(Fixture.WEAPON_REF)) \
		and String(pending_item.get("state", "")) == "pending_landing" \
		and pending_item.get("position_microfeet") == null
	var defense := simulation.resolve_pending_defense(attack.attack_instance_id, "task35e_throw_defense")
	if defense.get("status") != CombatDefenseResolution.STATUS_EXHAUSTED:
		return {"success": false, "reason": "throw_defense", "details": defense}
	var damage := simulation.resolve_physical_damage(attack.attack_instance_id, "task35e_throw_damage")
	if not damage.get("success", false):
		return {"success": false, "reason": "throw_damage", "details": damage}
	var damage_resolution: CombatDamageResolution = simulation.get_damage_resolution(String(damage.get("damage_resolution_id", "")))
	var landed_item := simulation.get_world_item(world_item_id)
	if String(landed_item.get("state", "")) != "dropped" or landed_item.get("position_microfeet") != landing_position:
		return {"success": false, "reason": "automatic_hit_landing", "details": landed_item}
	var unarmed_started := Fixture.start_unarmed_fallback_attack(simulation, boss.actor_id, target.actor_id, "task35e_unarmed", &"torso", true)
	if not unarmed_started.get("success", false):
		return {"success": false, "reason": "unarmed_start", "details": unarmed_started}
	simulation.advance_to(5_000_000)
	var unarmed_attack: CombatAttackInstance = simulation.get_attack(String(unarmed_started.get("attack_instance_id", "")))
	if unarmed_attack == null or unarmed_attack.status != CombatAttackInstance.STATUS_PENDING_DEFENSE:
		return {"success": false, "reason": "unarmed_accuracy", "status": "null" if unarmed_attack == null else unarmed_attack.status}
	var unarmed_defense := simulation.resolve_pending_defense(unarmed_attack.attack_instance_id, "task35e_unarmed_defense")
	if unarmed_defense.get("status") != CombatDefenseResolution.STATUS_EXHAUSTED:
		return {"success": false, "reason": "unarmed_defense"}
	var unarmed_damage := simulation.resolve_physical_damage(unarmed_attack.attack_instance_id, "task35e_unarmed_damage")
	if not unarmed_damage.get("success", false):
		return {"success": false, "reason": "unarmed_damage"}
	var unarmed_resolution: CombatDamageResolution = simulation.get_damage_resolution(String(unarmed_damage.get("damage_resolution_id", "")))
	var too_far := simulation.start_world_item_retrieval_action(boss.actor_id, world_item_id, "task35e_retrieve_too_far")
	var movement_required: bool = not bool(too_far.get("success", false)) and String(too_far.get("reason", "")) == "world_item_out_of_pickup_reach"
	simulation.apply_authoritative_position(boss.actor_id, landing_position, 0, 5_000_000)
	var retrieve_started := simulation.start_world_item_retrieval_action(boss.actor_id, world_item_id, "task35e_retrieve")
	if not retrieve_started.get("success", false):
		return {"success": false, "reason": "retrieve_start", "details": retrieve_started}
	var retrieve_action: CombatActionInstance = simulation.get_action(String(retrieve_started.get("action_instance_id", "")))
	var duration := retrieve_action.final_effect_due_at_us - retrieve_action.started_at_us
	if simulation.get_actor_state(boss.actor_id).equipment_refs.has(String(Fixture.WEAPON_REF)):
		return {"success": false, "reason": "retrieved_before_completion"}
	simulation.advance_to(retrieve_action.final_effect_due_at_us)
	state = simulation.get_actor_state(boss.actor_id)
	if not state.equipment_refs.has(String(Fixture.WEAPON_REF)) \
	or String(state.hand_occupancy.get("left", "")) != String(Fixture.WEAPON_REF) \
	or String(state.hand_occupancy.get("right", "")) != String(Fixture.WEAPON_REF) \
	or not simulation.get_world_item(world_item_id).is_empty():
		return {"success": false, "reason": "retrieve_completion"}
	var envelopes := harness.authority.publish_current_events()
	harness.deliver_in_order(envelopes)
	var events: Array = []
	for envelope: CombatEventEnvelope in envelopes:
		events.append(envelope.to_dictionary())
	return {
		"success": true,
		"pending_landing_observed": pending_observed,
		"retrieval_required_movement": movement_required,
		"retrieval_duration_us": duration,
		"throw_damage_flat_bonus": damage_resolution.flat_bonus,
		"throw_damage_strength_bonus": damage_resolution.strength_bonus,
		"unarmed_strength_bonus": unarmed_resolution.strength_bonus,
		"events": events,
		"snapshot": simulation.get_state_snapshot(),
		"harness": harness,
	}


func _test_deterministic_thrown_landing() -> void:
	var battlefield := ArenaBattlefield.create_task16_test_arena()
	var obstacle_trace := battlefield.resolve_ground_projectile_trajectory(
		Vector2i(27_000_000, 12_000_000), Vector2i(33_000_000, 12_000_000),
		Fixture.THROW_RANGE_MICROFEET, true
	)
	_expect_true(obstacle_trace.get("success", false), "The authoritative battlefield must resolve a wall-intercepted spear trajectory.")
	_expect_equal(obstacle_trace.get("position_microfeet"), Vector2i(29_000_000, 12_000_000), "A spear must stop at the center wall's first contact coordinate.")
	_expect_equal(obstacle_trace.get("contact_kind"), "solid_obstacle", "Wall interception must remain distinct from impact and maximum range.")
	var edge_trace := battlefield.resolve_ground_projectile_trajectory(
		Vector2i(44_000_000, 5_000_000), Vector2i(45_000_000, 5_000_000),
		Fixture.THROW_RANGE_MICROFEET, false
	)
	_expect_true(edge_trace.get("success", false), "The battlefield must clip a missed throw at its authored edge.")
	_expect_equal(edge_trace.get("position_microfeet"), Vector2i(46_000_000, 5_000_000), "A missed spear must not leave the 46-foot Arena edge.")
	_expect_equal(edge_trace.get("contact_kind"), "battlefield_edge", "Edge clipping must be recorded explicitly.")
	var moving := _run_moving_target_hit_landing()
	_expect_true(moving.get("success", false), "A hit must land at the target's authoritative resolution position rather than its declared position.")
	var obstacle := _run_moving_target_obstacle_landing()
	_expect_true(obstacle.get("success", false), "A target moving behind the wall must produce an obstacle-contact landing without an ACC roll.")
	var edge := _run_battlefield_edge_miss_landing()
	_expect_true(edge.get("success", false), "A missed throw must land at the battlefield edge and remain legally retrievable.")


func _run_moving_target_hit_landing() -> Dictionary:
	for seed_value in range(1, 100):
		var battlefield := ArenaBattlefield.create_open(Rect2i(-20_000_000, -20_000_000, 60_000_000, 40_000_000))
		var fixture := _make_automatic_landing_simulation(
			seed_value, battlefield, Vector2i.ZERO, Vector2i(5_000_000, 0), true
		)
		var simulation: CombatSimulation = fixture["simulation"]
		var started := Fixture.start_spear_throw(
			simulation, fixture["boss_id"], fixture["target_id"],
			"task35e_fix1_moving_hit_%d" % seed_value, &"torso", true
		)
		if not started.get("success", false):
			continue
		simulation.apply_authoritative_position(fixture["target_id"], Vector2i(8_000_000, 0), 0, 1_000_000)
		simulation.advance_to(2_500_000)
		var attack: CombatAttackInstance = simulation.get_attack(String(started.get("attack_instance_id", "")))
		if attack == null or attack.status != CombatAttackInstance.STATUS_PENDING_DEFENSE:
			continue
		var defense := simulation.resolve_pending_defense(attack.attack_instance_id, "task35e_fix1_moving_defense_%d" % seed_value)
		if defense.get("status") != CombatDefenseResolution.STATUS_EXHAUSTED:
			continue
		if not simulation.resolve_physical_damage(attack.attack_instance_id, "task35e_fix1_moving_damage_%d" % seed_value).get("success", false):
			continue
		var world_item_id := String(started.get("world_item_id", ""))
		var item := simulation.get_world_item(world_item_id)
		if item.get("position_microfeet") != Vector2i(8_000_000, 0):
			continue
		return {
			"success": _retrieve_landed_spear(simulation, fixture["boss_id"], world_item_id, Vector2i(7_000_000, 0), "moving_hit"),
		}
	return {"success": false, "reason": "no_successful_moving_hit_seed"}


func _run_moving_target_obstacle_landing() -> Dictionary:
	var battlefield := ArenaBattlefield.create_task16_test_arena()
	var fixture := _make_automatic_landing_simulation(
		35_501, battlefield, Vector2i(27_000_000, 12_000_000), Vector2i(28_000_000, 12_000_000), true
	)
	var simulation: CombatSimulation = fixture["simulation"]
	var started := Fixture.start_spear_throw(
		simulation, fixture["boss_id"], fixture["target_id"],
		"task35e_fix1_obstacle", &"torso", true
	)
	if not started.get("success", false):
		return {"success": false, "reason": "throw_start", "details": started}
	simulation.apply_authoritative_position(fixture["target_id"], Vector2i(33_000_000, 12_000_000), 0, 1_000_000)
	simulation.advance_to(2_500_000)
	var attack: CombatAttackInstance = simulation.get_attack(String(started.get("attack_instance_id", "")))
	var world_item_id := String(started.get("world_item_id", ""))
	var item := simulation.get_world_item(world_item_id)
	var evidence: Dictionary = item.get("landing_evidence", {})
	var valid: bool = attack != null \
		and attack.status == CombatAttackInstance.STATUS_FINAL_LEGALITY_FAILED \
		and attack.natural_roll == null \
		and item.get("position_microfeet") == Vector2i(29_000_000, 12_000_000) \
		and String(evidence.get("contact_kind", "")) == "solid_obstacle"
	if not valid:
		return {"success": false, "reason": "obstacle_landing", "attack": null if attack == null else attack.to_dictionary(), "item": item}
	return {
		"success": _retrieve_landed_spear(simulation, fixture["boss_id"], world_item_id, Vector2i(28_000_000, 12_000_000), "obstacle"),
	}


func _run_battlefield_edge_miss_landing() -> Dictionary:
	for seed_value in range(1, 100):
		var battlefield := ArenaBattlefield.create_task16_test_arena()
		var fixture := _make_automatic_landing_simulation(
			seed_value, battlefield, Vector2i(44_000_000, 5_000_000), Vector2i(45_000_000, 5_000_000), true
		)
		var simulation: CombatSimulation = fixture["simulation"]
		var started := Fixture.start_spear_throw(
			simulation, fixture["boss_id"], fixture["target_id"],
			"task35e_fix1_edge_%d" % seed_value, &"torso", true
		)
		if not started.get("success", false):
			continue
		simulation.advance_to(2_500_000)
		var attack: CombatAttackInstance = simulation.get_attack(String(started.get("attack_instance_id", "")))
		if attack == null or attack.status != CombatAttackInstance.STATUS_MISSED:
			continue
		var world_item_id := String(started.get("world_item_id", ""))
		var item := simulation.get_world_item(world_item_id)
		var evidence: Dictionary = item.get("landing_evidence", {})
		if item.get("position_microfeet") != Vector2i(46_000_000, 5_000_000) \
		or String(evidence.get("contact_kind", "")) != "battlefield_edge":
			continue
		return {
			"success": _retrieve_landed_spear(simulation, fixture["boss_id"], world_item_id, Vector2i(45_000_000, 5_000_000), "edge"),
		}
	return {"success": false, "reason": "no_edge_miss_seed"}


func _make_automatic_landing_simulation(
	seed_value: int,
	battlefield: ArenaBattlefield,
	boss_position: Vector2i,
	target_position: Vector2i,
	target_unaware: bool
) -> Dictionary:
	var simulation := CombatSimulation.new(seed_value)
	var boss_result := Fixture.instantiate_foundation_actor(&"task35e_fix1_boss", "Task 35E-Fix1 Boss")
	var boss: CombatActorDefinition = boss_result.get("actor")
	var target := _make_test_actor(&"task35e_fix1_target", PackedStringArray(), false, 500, 0)
	simulation.register_actor(boss)
	simulation.register_actor(target)
	simulation.configure_actor_hand_occupancy(boss.actor_id, {"left": String(Fixture.WEAPON_REF), "right": String(Fixture.WEAPON_REF)})
	simulation.get_actor_state(boss.actor_id).position_microfeet = boss_position
	simulation.get_actor_state(target.actor_id).position_microfeet = target_position
	simulation.get_actor_state(target.actor_id).awareness = &"unaware" if target_unaware else &"aware"
	simulation.register_defense_profile(target.actor_id, _make_no_defense_profile(&"task35e_fix1_no_defense"))
	simulation.register_damage_protection_profile(target.actor_id, CombatDamageProtectionProfile.new(&"task35e_fix1_protection"))
	Fixture.configure_spear_landing_geometry(simulation, battlefield)
	var line_of_sight_simulation_reference: WeakRef = weakref(simulation)
	simulation.set_attack_final_line_of_sight_resolver(func(attacker_id: StringName, target_id: StringName) -> bool:
		var active_simulation: CombatSimulation = line_of_sight_simulation_reference.get_ref()
		if active_simulation == null:
			return false
		return battlefield.has_line_of_sight(
			active_simulation.get_actor_state(attacker_id).position_microfeet,
			active_simulation.get_actor_state(target_id).position_microfeet
		)
	)
	simulation.begin_combat()
	return {"simulation": simulation, "boss_id": boss.actor_id, "target_id": target.actor_id}


func _retrieve_landed_spear(
	simulation: CombatSimulation,
	boss_id: StringName,
	world_item_id: String,
	pickup_position: Vector2i,
	request_suffix: String
) -> bool:
	var item_before := simulation.get_world_item(world_item_id)
	if String(item_before.get("state", "")) != "dropped":
		return false
	var pickup_simulation_reference: WeakRef = weakref(simulation)
	simulation.set_world_item_pickup_resolver(func(actor_id: StringName, item: Dictionary) -> bool:
		var active_simulation: CombatSimulation = pickup_simulation_reference.get_ref()
		return active_simulation != null \
			and active_simulation.get_actor_state(actor_id).position_microfeet.distance_to(item["position_microfeet"]) <= 1_000_000.0
	)
	simulation.apply_authoritative_position(boss_id, pickup_position, 0, simulation.clock.get_elapsed_us())
	var started := simulation.start_world_item_retrieval_action(
		boss_id, world_item_id, "task35e_fix1_retrieve_%s" % request_suffix
	)
	if not started.get("success", false):
		return false
	var action: CombatActionInstance = simulation.get_action(String(started.get("action_instance_id", "")))
	simulation.advance_to(action.final_effect_due_at_us)
	var state := simulation.get_actor_state(boss_id)
	var spear_count := 0
	for equipment_ref: String in state.equipment_refs:
		if equipment_ref == String(Fixture.WEAPON_REF):
			spear_count += 1
	return spear_count == 1 \
		and String(state.hand_occupancy.get("left", "")) == String(Fixture.WEAPON_REF) \
		and String(state.hand_occupancy.get("right", "")) == String(Fixture.WEAPON_REF) \
		and simulation.get_world_item(world_item_id).is_empty()


func _run_interrupted_retrieval_transaction() -> Dictionary:
	var simulation := CombatSimulation.new(31)
	var boss_result := Fixture.instantiate_foundation_actor(&"task35e_interrupt_boss", "Task 35E Interrupt Boss")
	var boss: CombatActorDefinition = boss_result.get("actor")
	var target := _make_test_actor(&"task35e_interrupt_target", PackedStringArray(), false, 500, 0)
	simulation.register_actor(boss)
	simulation.register_actor(target)
	simulation.configure_actor_hand_occupancy(boss.actor_id, {"left": String(Fixture.WEAPON_REF), "right": String(Fixture.WEAPON_REF)})
	simulation.get_actor_state(target.actor_id).position_microfeet = Vector2i(1_000_000, 0)
	simulation.get_actor_state(target.actor_id).awareness = &"unaware"
	simulation.register_defense_profile(target.actor_id, _make_no_defense_profile(&"task35e_interrupt_defense"))
	simulation.register_damage_protection_profile(target.actor_id, CombatDamageProtectionProfile.new(&"task35e_interrupt_protection"))
	Fixture.configure_spear_landing_geometry(
		simulation,
		ArenaBattlefield.create_open(Rect2i(-20_000_000, -20_000_000, 60_000_000, 40_000_000))
	)
	simulation.set_world_item_pickup_resolver(func(_actor_id: StringName, _item: Dictionary) -> bool: return true)
	simulation.begin_combat()
	var started := Fixture.start_spear_throw(simulation, boss.actor_id, target.actor_id, "task35e_interrupt_throw", &"torso", true)
	if not started.get("success", false):
		return {"success": false, "reason": "throw_start"}
	simulation.advance_to(2_500_000)
	var attack: CombatAttackInstance = simulation.get_attack(String(started.get("attack_instance_id", "")))
	if attack.status == CombatAttackInstance.STATUS_PENDING_DEFENSE:
		var defense := simulation.resolve_pending_defense(attack.attack_instance_id, "task35e_interrupt_throw_defense")
		if defense.get("status") == CombatDefenseResolution.STATUS_EXHAUSTED:
			simulation.resolve_physical_damage(attack.attack_instance_id, "task35e_interrupt_throw_damage")
	if not [CombatAttackInstance.STATUS_MISSED, CombatAttackInstance.STATUS_DAMAGE_RESOLVED].has(attack.status):
		return {"success": false, "reason": "throw_not_terminal", "status": attack.status}
	var world_item_id := String(started.get("world_item_id", ""))
	if String(simulation.get_world_item(world_item_id).get("state", "")) != "dropped":
		return {"success": false, "reason": "landing"}
	var retrieval := simulation.start_world_item_retrieval_action(boss.actor_id, world_item_id, "task35e_interrupted_retrieval")
	if not retrieval.get("success", false):
		return {"success": false, "reason": "retrieval_start"}
	var retrieval_action: CombatActionInstance = simulation.get_action(String(retrieval.get("action_instance_id", "")))
	simulation.schedule_interruption(retrieval_action.action_instance_id, 3_000_000, target.actor_id, "task35e_test_interruption")
	simulation.advance_to(5_000_000)
	var state := simulation.get_actor_state(boss.actor_id)
	return {
		"success": retrieval_action.status == CombatActionInstance.STATUS_INTERRUPTED \
			and String(simulation.get_world_item(world_item_id).get("state", "")) == "dropped" \
			and not state.equipment_refs.has(String(Fixture.WEAPON_REF)) \
			and not state.hand_occupancy.values().has(String(Fixture.WEAPON_REF)),
	}


func _verify_throw_miss_defense_and_boundaries() -> Dictionary:
	var profile := CombatHitLocationCatalog.get_same_size_attack_profile()
	var thrown := Fixture.make_thrown_attack_definition(profile)
	var in_range := _make_throw_boundary_simulation(18_000_000, true)
	var in_range_start := Fixture.start_spear_throw(in_range["simulation"], in_range["boss_id"], in_range["target_id"], "task35e_in_range", &"torso", true)
	if not in_range_start.get("success", false):
		return {"success": false, "reason": "exact_range_rejected"}
	var outside := _make_throw_boundary_simulation(18_000_001, true)
	var outside_start := Fixture.start_spear_throw(outside["simulation"], outside["boss_id"], outside["target_id"], "task35e_outside", &"torso", true)
	if outside_start.get("success", false) or outside_start.get("reason") != "target_out_of_range":
		return {"success": false, "reason": "outside_range_accepted", "details": outside_start}
	var blocked_los := _make_throw_boundary_simulation(10_000_000, true)
	var blocked_start := Fixture.start_spear_throw(blocked_los["simulation"], blocked_los["boss_id"], blocked_los["target_id"], "task35e_blocked_los", &"torso", false)
	if blocked_start.get("success", false) or blocked_start.get("reason") != "line_of_sight_unverified":
		return {"success": false, "reason": "blocked_los_accepted", "details": blocked_start}
	var miss_verified := false
	for seed_value in range(1, 80):
		var fixture := _make_throw_boundary_simulation(10_000_000, true, seed_value)
		var simulation: CombatSimulation = fixture["simulation"]
		var result := Fixture.start_spear_throw(simulation, fixture["boss_id"], fixture["target_id"], "task35e_miss_%d" % seed_value, &"torso", true)
		if not result.get("success", false):
			continue
		simulation.advance_to(2_500_000)
		var attack: CombatAttackInstance = simulation.get_attack(String(result.get("attack_instance_id", "")))
		if attack != null and attack.status == CombatAttackInstance.STATUS_MISSED:
			var world_item_id := String(result.get("world_item_id", ""))
			var item := simulation.get_world_item(world_item_id)
			miss_verified = String(item.get("state", "")) == "dropped" \
				and item.get("position_microfeet") == Vector2i(18_000_000, 0) \
				and String((item.get("landing_evidence", {}) as Dictionary).get("contact_kind", "")) == "maximum_range" \
				and _retrieve_landed_spear(simulation, fixture["boss_id"], world_item_id, Vector2i(17_000_000, 0), "miss")
			break
	if not miss_verified:
		return {"success": false, "reason": "miss_not_verified"}
	var defense_verified := false
	for seed_value in range(1, 80):
		var fixture := _make_throw_boundary_simulation(10_000_000, false, seed_value, true)
		var simulation: CombatSimulation = fixture["simulation"]
		var result := Fixture.start_spear_throw(simulation, fixture["boss_id"], fixture["target_id"], "task35e_defended_%d" % seed_value, &"torso", true)
		if not result.get("success", false):
			continue
		simulation.advance_to(2_500_000)
		var attack: CombatAttackInstance = simulation.get_attack(String(result.get("attack_instance_id", "")))
		if attack == null or attack.status != CombatAttackInstance.STATUS_PENDING_DEFENSE:
			continue
		var defense := simulation.resolve_pending_defense(attack.attack_instance_id, "task35e_defense_%d" % seed_value)
		if defense.get("status") != CombatDefenseResolution.STATUS_DEFENDED:
			continue
		var world_item_id := String(result.get("world_item_id", ""))
		var item := simulation.get_world_item(world_item_id)
		defense_verified = String(item.get("state", "")) == "dropped" \
			and item.get("position_microfeet") == Vector2i(10_000_000, 0) \
			and String((item.get("landing_evidence", {}) as Dictionary).get("trajectory_outcome", "")) == "blocked" \
			and _retrieve_landed_spear(simulation, fixture["boss_id"], world_item_id, Vector2i(9_000_000, 0), "blocked")
		break
	return {"success": defense_verified and thrown != null}


func _test_spear_geometry_resolvers_release_simulation() -> void:
	for iteration in range(3):
		var simulation_reference := _make_configured_simulation_weak_reference(iteration)
		_expect_true(
			simulation_reference.get_ref() == null,
			"Spear geometry callbacks must not retain a discarded CombatSimulation instance."
		)


func _make_configured_simulation_weak_reference(seed_offset: int) -> WeakRef:
	var simulation := CombatSimulation.new(200 + seed_offset)
	Fixture.configure_spear_landing_geometry(
		simulation,
		ArenaBattlefield.create_open(Rect2i(-5_000_000, -5_000_000, 10_000_000, 10_000_000))
	)
	return weakref(simulation)


func _make_throw_boundary_simulation(
	distance_microfeet: int,
	target_unaware: bool,
	seed_value: int = 97,
	guaranteed_weapon_block: bool = false
) -> Dictionary:
	var simulation := CombatSimulation.new(seed_value)
	var boss_result := Fixture.instantiate_foundation_actor(&"task35e_boundary_boss", "Task 35E Boundary Boss")
	var boss: CombatActorDefinition = boss_result.get("actor")
	var target_equipment := PackedStringArray(["task35e_block_weapon"]) if guaranteed_weapon_block else PackedStringArray()
	var target := _make_test_actor(&"task35e_boundary_target", target_equipment, false, 500, 0)
	simulation.register_actor(boss)
	simulation.register_actor(target)
	simulation.configure_actor_hand_occupancy(boss.actor_id, {"left": String(Fixture.WEAPON_REF), "right": String(Fixture.WEAPON_REF)})
	simulation.get_actor_state(target.actor_id).position_microfeet = Vector2i(distance_microfeet, 0)
	simulation.get_actor_state(target.actor_id).awareness = &"unaware" if target_unaware else &"aware"
	if guaranteed_weapon_block:
		simulation.get_actor_state(target.actor_id).conditions.append("held")
		var block := CombatBlockDefinition.new(CombatBlockDefinition.TYPE_WEAPON, &"task35e_block_weapon", 20, 0, true, true, null, PackedStringArray(["Task 35E guaranteed defense fixture"]))
		simulation.register_defense_profile(target.actor_id, CombatDefenseProfile.new(
			&"task35e_block_profile", PackedStringArray(["dodge", "weapon_block", "shield_block", "physical_soak"]), {}, block, null,
			PackedStringArray(["Task 35E guaranteed defense fixture"])
		))
	else:
		simulation.register_defense_profile(target.actor_id, _make_no_defense_profile(&"task35e_boundary_defense"))
	simulation.register_damage_protection_profile(target.actor_id, CombatDamageProtectionProfile.new(&"task35e_boundary_protection"))
	Fixture.configure_spear_landing_geometry(
		simulation,
		ArenaBattlefield.create_open(Rect2i(-20_000_000, -20_000_000, 60_000_000, 40_000_000))
	)
	simulation.begin_combat()
	return {"simulation": simulation, "boss_id": boss.actor_id, "target_id": target.actor_id}


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
