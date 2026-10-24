class_name RareHumanWarriorFixture
extends RefCounted

const CHARACTER_DEFINITION_ID := &"prime_v3_rare_human_warrior_boss"
const LOADOUT_DEFINITION_ID := &"prime_v3_rare_human_warrior_boss"
const WEAPON_REF := &"prime_v3_rare_human_warrior_boar_spear"
const ACTOR_ID := &"wave_5_rare_human_warrior_1"
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


static func get_activation_status() -> Dictionary:
	return {
		"encounter_ready": false,
		"reason": "wave_5_boss_rules_unresolved",
		"unresolved": PackedStringArray([
			"exact_combat_abilities_and_prerequisites",
			"boar_spear_enchantment_damage_interaction",
			"boar_spear_thrown_attack_pipeline",
			"scale_mail_equipped_locations",
			"health_potion_use_action_and_consumption_timing",
		]),
	}
