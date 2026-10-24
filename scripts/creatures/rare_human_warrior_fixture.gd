class_name RareHumanWarriorFixture
extends RefCounted

const CHARACTER_DEFINITION_ID := &"prime_v3_rare_human_warrior_boss"
const LOADOUT_DEFINITION_ID := &"prime_v3_rare_human_warrior_boss"
const WEAPON_REF := &"prime_v3_rare_human_warrior_boar_spear"
const ACTOR_ID := &"wave_5_rare_human_warrior_1"
const ATTACK_DEFINITION_ID := &"prime_v3_rare_human_warrior_boar_spear_melee"
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
			"boar_spear_thrown_delivery_world_location_and_recovery_pipeline",
			"human_unarmed_strength_bonus_and_strikes_per_act",
			"health_potion_use_action_and_consumption_timing",
		]),
	}
