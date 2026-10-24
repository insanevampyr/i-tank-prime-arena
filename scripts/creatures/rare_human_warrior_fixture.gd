class_name RareHumanWarriorFixture
extends RefCounted

const CHARACTER_DEFINITION_ID := &"prime_v3_rare_human_warrior_boss"
const LOADOUT_DEFINITION_ID := &"prime_v3_rare_human_warrior_boss"
const WEAPON_REF := &"prime_v3_rare_human_warrior_boar_spear"
const ACTOR_ID := &"wave_5_rare_human_warrior_1"
const ATTACK_DEFINITION_ID := &"prime_v3_rare_human_warrior_boar_spear_melee"
const THROWN_ATTACK_DEFINITION_ID := &"prime_v3_rare_human_warrior_boar_spear_thrown"
const UNARMED_ATTACK_DEFINITION_ID := &"prime_v3_rare_human_warrior_unarmed_strike"
const UNARMED_WEAPON_REF := &"prime_v3_human_unarmed_strike"
const THROW_RANGE_MICROFEET := 18_000_000
const SCALE_ARMOR_REFS := [
	"prime_v3_scale_mail_torso",
	"prime_v3_scale_mail_head",
	"prime_v3_scale_mail_arms",
	"prime_v3_scale_mail_legs",
	"prime_v3_scale_mail_elbows",
	"prime_v3_scale_mail_knees",
	"prime_v3_scale_mail_hands",
]


static func instantiate_foundation_actor(
	actor_id: StringName = ACTOR_ID,
	display_name: String = "Rare Human Warrior"
) -> Dictionary:
	var catalog := CombatDefinitionCatalog.load_default_fixture_catalog()
	var result := catalog.instantiate_actor(
		CHARACTER_DEFINITION_ID,
		LOADOUT_DEFINITION_ID,
		actor_id,
		display_name
	)
	result["encounter_ready"] = false
	result["activation_gate"] = "wave_5_boss_rules_unresolved"
	return result


static func make_melee_attack_definition(targeting_profile: Dictionary) -> CombatAttackDefinition:
	var catalog := CombatDefinitionCatalog.load_default_fixture_catalog()
	var weapon := catalog.get_weapon(WEAPON_REF)
	return null if weapon == null else weapon.make_attack_definition(ATTACK_DEFINITION_ID, targeting_profile) as CombatAttackDefinition


static func make_thrown_attack_definition(targeting_profile: Dictionary) -> CombatAttackDefinition:
	var catalog := CombatDefinitionCatalog.load_default_fixture_catalog()
	var weapon := catalog.get_weapon(WEAPON_REF)
	return null if weapon == null else weapon.make_thrown_attack_definition(
		THROWN_ATTACK_DEFINITION_ID,
		THROW_RANGE_MICROFEET,
		targeting_profile,
		PackedStringArray(["piercing"])
	) as CombatAttackDefinition


static func make_unarmed_attack_definition(targeting_profile: Dictionary) -> CombatAttackDefinition:
	var acc_modifiers: Dictionary = targeting_profile.get("acc_modifiers_by_location", {}).duplicate(true)
	var allowed_locations: PackedStringArray = targeting_profile.get("allowed_target_locations", PackedStringArray()).duplicate()
	var location_multipliers: Dictionary = targeting_profile.get("location_multipliers", {}).duplicate(true)
	if not allowed_locations.has("torso") or acc_modifiers.keys().size() != allowed_locations.size() \
	or location_multipliers.keys().size() != allowed_locations.size():
		return null
	var source_refs := PackedStringArray([
		"PRIME-V3 p. 19: fist damage is 1d4 Bashing and eligible physical/thrown hits add SB",
		"PRIME-V3 p. 134: Unarmed Strike has STR 1, one-foot reach and 1d4 Bashing damage",
		"Task 35E source boundary: generic Human unarmed fallback uses one strike per ordinary Act; no Goblin two-fist sequence",
	])
	for profile_source: String in targeting_profile.get("source_refs", PackedStringArray()):
		if not source_refs.has(profile_source):
			source_refs.append(profile_source)
	var damage := CombatPhysicalDamageDefinition.new(
		1, 4, 0, true, true, location_multipliers, null, true,
		CombatPhysicalDamageDefinition.ROUNDING_FLOOR, source_refs
	)
	return CombatAttackDefinition.new(
		UNARMED_ATTACK_DEFINITION_ID, UNARMED_WEAPON_REF, 1, true, true, 0,
		acc_modifiers, allowed_locations, 0, 1_000_000, true, source_refs,
		&"hand_held", PackedStringArray(["bashing"]), true,
		CombatAttackDefinition.DUCKING_UNRESOLVED, damage,
		CombatCriticalTriggerPolicy.new(), false, true, 1, [], false, false
	)


static func start_spear_throw(
	simulation: CombatSimulation,
	attacker_id: StringName,
	target_id: StringName,
	request_id: String,
	target_location: StringName,
	authoritative_line_of_sight: bool
) -> Dictionary:
	var catalog := CombatDefinitionCatalog.load_default_fixture_catalog()
	var character: CombatCharacterDefinitionResource = catalog.characters.get(String(CHARACTER_DEFINITION_ID))
	var throw_profile: Dictionary = {} if character == null else character.proficiencies.get("throw", {})
	if int(throw_profile.get("investments", 0)) < 1:
		return {"success": false, "reason": "automatic_throw_proficiency_unverified"}
	var definition := make_thrown_attack_definition(CombatHitLocationCatalog.get_same_size_attack_profile())
	return simulation.start_thrown_weapon_attack(
		attacker_id, target_id, definition, request_id, target_location,
		authoritative_line_of_sight, PackedStringArray(["left", "right"]), 15,
		"Official boss sheet: Throw proficiency; one square per STR. PRIME-V3 p. 26: one Throw investment is automatic."
	)


static func configure_spear_landing_geometry(
	simulation: CombatSimulation,
	battlefield: ArenaBattlefield
) -> void:
	simulation.set_thrown_weapon_trajectory_resolver(func(request: Dictionary) -> Dictionary:
		return battlefield.resolve_ground_projectile_trajectory(
			request["start_microfeet"],
			request["direction_point_microfeet"],
			int(request["maximum_distance_microfeet"]),
			bool(request["stop_at_direction_point"])
		)
	)
	simulation.set_world_item_landing_resolver(func(_item: Dictionary, position: Vector2i) -> bool:
		return battlefield.is_ground_world_item_position_legal(position)
	)


static func start_unarmed_fallback_attack(
	simulation: CombatSimulation,
	attacker_id: StringName,
	target_id: StringName,
	request_id: String,
	target_location: StringName,
	authoritative_line_of_sight: bool
) -> Dictionary:
	var actor_state := simulation.get_actor_state(attacker_id)
	if actor_state == null:
		return {"success": false, "reason": "unknown_attacker"}
	if actor_state.equipment_refs.has(String(WEAPON_REF)) \
	or actor_state.hand_occupancy.values().has(String(WEAPON_REF)):
		return {"success": false, "reason": "boar_spear_still_available"}
	var definition := make_unarmed_attack_definition(CombatHitLocationCatalog.get_same_size_attack_profile())
	return simulation.start_physical_attack(
		attacker_id, target_id, definition, request_id, target_location,
		authoritative_line_of_sight
	)


static func make_defense_profile(actor_id: StringName = ACTOR_ID) -> CombatDefenseProfile:
	var catalog := CombatDefinitionCatalog.load_default_fixture_catalog()
	var weapon := catalog.get_weapon(WEAPON_REF)
	var weapon_block: CombatBlockDefinition = null if weapon == null else weapon.make_block_definition()
	return CombatDefenseProfile.new(
		StringName("rare_human_warrior_%s_defenses" % String(actor_id)),
		PackedStringArray(["dodge", "weapon_block", "shield_block", "physical_soak"]),
		{},
		weapon_block,
		null,
		PackedStringArray([
			"assets/Rare Human Warrior (Boss).doc: Boar Spear 30% weapon Block",
			"PRIME-V3 pp. 127-128: BOR SPEAR Block 6",
		])
	)


static func make_damage_protection_profile(actor_id: StringName = ACTOR_ID) -> CombatDamageProtectionProfile:
	var catalog := CombatDefinitionCatalog.load_default_fixture_catalog()
	var equipped_armors: Array[CombatArmorDefinition] = []
	var source_refs := PackedStringArray([
		"PRIME-V3 p. 135: Hard Studded/Scale TAL and penalties",
		"Task 27 owner-confirmed armor coverage",
		"Task 35D owner ruling: complete seven-location Scale-mail loadout",
	])
	for armor_ref: String in SCALE_ARMOR_REFS:
		var armor := catalog.get_armor(StringName(armor_ref))
		if armor == null:
			return null
		var definition: CombatArmorDefinition = armor.make_combat_armor_definition()
		if definition == null:
			return null
		equipped_armors.append(definition)
	return CombatDamageProtectionProfile.new(
		StringName("rare_human_warrior_%s_protection" % String(actor_id)),
		equipped_armors,
		{},
		source_refs
	)


static func get_activation_status() -> Dictionary:
	return {
		"encounter_ready": false,
		"reason": "wave_5_boss_rules_unresolved",
		"unresolved": PackedStringArray([
			"exact_combat_abilities_and_prerequisites",
			"health_potion_use_action_and_consumption_timing",
		]),
	}
