class_name CommonSpadoodleFixture
extends RefCounted

const Catalog = preload("res://scripts/data/combat_definition_catalog.gd")
const HitLocations = preload("res://scripts/combat/combat_hit_location_catalog.gd")

const CREATURE_ID := &"common_spadoodle"
const CHARACTER_DEFINITION_ID := &"prime_v3_common_spadoodle"
const LOADOUT_DEFINITION_ID := &"prime_v3_common_spadoodle_claws"
const WEAPON_REF := &"prime_v3_common_spadoodle_claws"
const SOURCE_REF := "Common Spadoodle.doc, Common Spadoodle combat statistics, natural claws, and scale hide"
const TWO_CLAW_RULING_SOURCE := "Task 32A owner ruling: two independent claw strikes per AT-1 Act"


static func make_actor(actor_id: StringName, display_name: String) -> CombatActorDefinition:
	var catalog := Catalog.load_default_fixture_catalog()
	var result := catalog.instantiate_actor(CHARACTER_DEFINITION_ID, LOADOUT_DEFINITION_ID, actor_id, display_name)
	return result.get("actor") as CombatActorDefinition


static func make_attack_definition(targeting_profile: Dictionary) -> CombatAttackDefinition:
	var catalog := Catalog.load_default_fixture_catalog()
	var claws := catalog.get_weapon(WEAPON_REF)
	return null if claws == null else claws.make_attack_definition(&"prime_v3_common_spadoodle_claws_attack", targeting_profile) as CombatAttackDefinition


static func make_defense_profile(actor_id: StringName) -> CombatDefenseProfile:
	return CombatDefenseProfile.new(
		StringName("task32a_%s_defenses" % String(actor_id)),
		PackedStringArray(["dodge", "weapon_block", "shield_block", "physical_soak"]),
		{},
		null,
		null,
		PackedStringArray([SOURCE_REF])
	)


static func make_damage_protection_profile(actor_id: StringName) -> CombatDamageProtectionProfile:
	return CombatDamageProtectionProfile.new(
		StringName("task32a_%s_protection" % String(actor_id)),
		[],
		{},
		PackedStringArray(["Common Spadoodle.doc: scale hide grants NAL +2 all over; no worn armor"])
	)


static func validate_actor(actor: CombatActorDefinition, attack: CombatAttackDefinition) -> Dictionary:
	if actor == null or attack == null:
		return {"success": false, "reason": "spadoodle_component_missing"}
	if actor.size_category != HitLocations.SIZE_SMALL:
		return {"success": false, "reason": "spadoodle_size_invalid"}
	for field_name: String in ["hpm", "at", "init", "acc", "mr", "nal", "dt", "dp", "physical_soak", "rb", "sb"]:
		if actor.get_combat_stat(field_name) == null:
			return {"success": false, "reason": "spadoodle_combat_stat_unresolved", "field": field_name}
	if not actor.equipment_refs.has(String(WEAPON_REF)):
		return {"success": false, "reason": "spadoodle_claws_not_registered"}
	if attack.weapon_ref != WEAPON_REF or attack.maximum_range_microfeet != 2_000_000:
		return {"success": false, "reason": "spadoodle_claws_definition_mismatch"}
	if attack.strikes_per_act != 2 or attack.required_acts != 1:
		return {"success": false, "reason": "spadoodle_two_claw_ruling_missing"}
	return {"success": true}
