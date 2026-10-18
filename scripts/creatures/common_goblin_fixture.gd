class_name CommonGoblinFixture
extends RefCounted

const Catalog = preload("res://scripts/data/combat_definition_catalog.gd")
const HitLocations = preload("res://scripts/combat/combat_hit_location_catalog.gd")

const CREATURE_ID := &"common_goblin"
const CHARACTER_DEFINITION_ID := &"prime_v3_common_goblin"
const LOADOUT_DEFINITION_ID := &"prime_v3_common_goblin_fists"
const WEAPON_REF := &"prime_v3_common_goblin_fists"
const SOURCE_REF := "Common Goblin.doc, Common Goblin combat statistics and equipment entry"
const SIZE_RULING_SOURCE := "Task 31C designer-approved Arena ruling: Common Goblins use Small; not printed on Common Goblin.doc"


static func make_actor(actor_id: StringName, display_name: String) -> CombatActorDefinition:
	var catalog := Catalog.load_default_fixture_catalog()
	var result := catalog.instantiate_actor(CHARACTER_DEFINITION_ID, LOADOUT_DEFINITION_ID, actor_id, display_name)
	return result.get("actor") as CombatActorDefinition


static func make_attack_definition(targeting_profile: Dictionary) -> CombatAttackDefinition:
	var catalog := Catalog.load_default_fixture_catalog()
	var fists := catalog.get_weapon(WEAPON_REF)
	return null if fists == null else fists.make_attack_definition(&"prime_v3_common_goblin_fists_attack", targeting_profile) as CombatAttackDefinition


static func make_defense_profile(actor_id: StringName) -> CombatDefenseProfile:
	return CombatDefenseProfile.new(
		StringName("task31c_%s_defenses" % String(actor_id)),
		PackedStringArray(["dodge", "weapon_block", "shield_block", "physical_soak"]),
		{},
		null,
		null,
		PackedStringArray([SOURCE_REF])
	)


static func make_damage_protection_profile(actor_id: StringName) -> CombatDamageProtectionProfile:
	return CombatDamageProtectionProfile.new(
		StringName("task31c_%s_protection" % String(actor_id)),
		[],
		{},
		PackedStringArray(["Common Goblin.doc: Armor X; NAL 0"])
	)


static func validate_actor(actor: CombatActorDefinition, attack: CombatAttackDefinition) -> Dictionary:
	if actor == null or attack == null:
		return {"success": false, "reason": "goblin_component_missing"}
	if actor.size_category != HitLocations.SIZE_SMALL:
		return {"success": false, "reason": "goblin_size_ruling_missing"}
	for field_name: String in ["hpm", "at", "init", "acc", "mr", "nal", "dt", "dp", "physical_soak", "rb", "sb"]:
		if actor.get_combat_stat(field_name) == null:
			return {"success": false, "reason": "goblin_combat_stat_unresolved", "field": field_name}
	if not actor.equipment_refs.has(String(WEAPON_REF)):
		return {"success": false, "reason": "goblin_fists_not_registered"}
	if attack.weapon_ref != WEAPON_REF or attack.maximum_range_microfeet != 1_000_000:
		return {"success": false, "reason": "goblin_fists_definition_mismatch"}
	return {"success": true}
