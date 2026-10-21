class_name CommonSkellyFixture
extends RefCounted

const Catalog = preload("res://scripts/data/combat_definition_catalog.gd")
const HitLocations = preload("res://scripts/combat/combat_hit_location_catalog.gd")

const CREATURE_ID := &"common_skelly"
const CHARACTER_DEFINITION_ID := &"prime_v3_common_skelly"
const LOADOUT_DEFINITION_ID := &"prime_v3_common_skelly_claws"
const WEAPON_REF := &"prime_v3_common_skelly_claws"
const SOURCE_REF := "ITank Prime V3 current Summoned Skeleton entry and Common Skelly.doc"
const NATURAL_ATTACK_RULING_SOURCE := "Task 32B owner ruling: verified natural attacks determine strikes per Act; AT determines Act frequency"


static func make_actor(actor_id: StringName, display_name: String) -> CombatActorDefinition:
	var catalog := Catalog.load_default_fixture_catalog()
	var result := catalog.instantiate_actor(CHARACTER_DEFINITION_ID, LOADOUT_DEFINITION_ID, actor_id, display_name)
	return result.get("actor") as CombatActorDefinition


static func make_attack_definition(targeting_profile: Dictionary) -> CombatAttackDefinition:
	var catalog := Catalog.load_default_fixture_catalog()
	var claws := catalog.get_weapon(WEAPON_REF)
	return null if claws == null else claws.make_attack_definition(&"prime_v3_common_skelly_claws_attack", targeting_profile) as CombatAttackDefinition


static func make_defense_profile(actor_id: StringName) -> CombatDefenseProfile:
	return CombatDefenseProfile.new(
		StringName("task32b_%s_defenses" % String(actor_id)),
		PackedStringArray(["dodge", "weapon_block", "shield_block", "physical_soak"]),
		{},
		null,
		null,
		PackedStringArray([SOURCE_REF])
	)


static func make_damage_protection_profile(actor_id: StringName) -> CombatDamageProtectionProfile:
	return CombatDamageProtectionProfile.new(
		StringName("task32b_%s_protection" % String(actor_id)),
		[],
		{
			"piercing": {
				"kind": CombatDamageProtectionProfile.RESPONSE_IMMUNE,
				"source_ref": "ITank Prime V3 current Summoned Skeleton entry: immune to piercing",
			},
		},
		PackedStringArray(["ITank Prime V3 p. 314: NAL 0, piercing immunity, Light damage x4, Faith/Cleric Turning eligibility"]),
		{
			"light": {"eligible": true, "numerator": 4, "denominator": 1, "source_ref": "ITank Prime V3 p. 314: Light-based Specials do four times damage"},
			"faith": {"eligible": true, "numerator": 1, "denominator": 1, "source_ref": "ITank Prime V3 pp. 249-250 and p. 314: source-specific Faith Specials may damage qualifying undead"},
		}
	)


static func validate_actor(actor: CombatActorDefinition, attack: CombatAttackDefinition) -> Dictionary:
	if actor == null or attack == null:
		return {"success": false, "reason": "skelly_component_missing"}
	if actor.size_category != HitLocations.SIZE_MEDIUM:
		return {"success": false, "reason": "skelly_size_invalid"}
	for field_name: String in ["hpm", "at", "init", "acc", "mr", "nal", "dt", "dp", "physical_soak", "rb", "sb"]:
		if actor.get_combat_stat(field_name) == null:
			return {"success": false, "reason": "skelly_combat_stat_unresolved", "field": field_name}
	if not actor.equipment_refs.has(String(WEAPON_REF)):
		return {"success": false, "reason": "skelly_claws_not_registered"}
	if attack.weapon_ref != WEAPON_REF or attack.maximum_range_microfeet != 1_000_000:
		return {"success": false, "reason": "skelly_claws_definition_mismatch"}
	if attack.strikes_per_act != 2 or attack.required_acts != 1:
		return {"success": false, "reason": "skelly_two_claw_ruling_missing"}
	return {"success": true}
