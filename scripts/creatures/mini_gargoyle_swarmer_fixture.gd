class_name MiniGargoyleSwarmerFixture
extends RefCounted

const Catalog = preload("res://scripts/data/combat_definition_catalog.gd")
const HitLocations = preload("res://scripts/combat/combat_hit_location_catalog.gd")

const CREATURE_ID := &"mini_gargoyle_swarmer"
const CHARACTER_DEFINITION_ID := &"prime_v3_uncommon_mini_gargoyle_swarmer"
const LOADOUT_DEFINITION_ID := &"prime_v3_mini_gargoyle_natural_attacks"
const WEAPON_REF := &"prime_v3_mini_gargoyle_natural_attacks"
const FURY_ABILITY_ID := &"fury"
const HEIGHT_MICROFEET := 3_000_000
const DARK_SIGHT_MICROFEET := 100_000_000
const SOURCE_REF := "Uncommon Mini Gargoyle Swarmers.doc and ITank Prime V3 p. 166"


static func make_actor(actor_id: StringName, display_name: String) -> CombatActorDefinition:
	var catalog := Catalog.load_default_fixture_catalog()
	var result := catalog.instantiate_actor(CHARACTER_DEFINITION_ID, LOADOUT_DEFINITION_ID, actor_id, display_name)
	return result.get("actor") as CombatActorDefinition


static func make_attack_definition(targeting_profile: Dictionary) -> CombatAttackDefinition:
	var catalog := Catalog.load_default_fixture_catalog()
	var natural_attacks := catalog.get_weapon(WEAPON_REF)
	if natural_attacks == null:
		return null
	var attack := natural_attacks.make_attack_definition(&"prime_v3_mini_gargoyle_natural_attack_sequence", targeting_profile) as CombatAttackDefinition
	if attack == null:
		return null
	attack.strike_profiles = [
		{"label": "claw_1", "dice_count": 1, "die_sides": 6, "damage_types": ["slashing"]},
		{"label": "claw_2", "dice_count": 1, "die_sides": 6, "damage_types": ["slashing"]},
		{"label": "bite", "dice_count": 1, "die_sides": 8, "damage_types": ["piercing"]},
	]
	return attack


static func make_defense_profile(actor_id: StringName) -> CombatDefenseProfile:
	return CombatDefenseProfile.new(
		StringName("task33a_%s_defenses" % String(actor_id)),
		PackedStringArray(["dodge", "weapon_block", "shield_block", "physical_soak"]),
		{}, null, null, PackedStringArray([SOURCE_REF])
	)


static func make_damage_protection_profile(actor_id: StringName) -> CombatDamageProtectionProfile:
	return CombatDamageProtectionProfile.new(
		StringName("task33a_%s_protection" % String(actor_id)), [], {},
		PackedStringArray(["Uncommon Mini Gargoyle Swarmers.doc: NAL +2; no worn armor"])
	)


static func validate_actor(actor: CombatActorDefinition, attack: CombatAttackDefinition) -> Dictionary:
	if actor == null or attack == null:
		return {"success": false, "reason": "mini_gargoyle_component_missing"}
	if actor.size_category != HitLocations.SIZE_SMALL:
		return {"success": false, "reason": "mini_gargoyle_size_invalid"}
	var expected := {"hpm": 15, "at": 1, "init": 8, "acc": 13, "mr": 16, "nal": 2, "dt": 15, "dp": 0, "physical_soak": 3, "sb": 1}
	for field_name: String in expected:
		if actor.get_combat_stat(field_name) != expected[field_name]:
			return {"success": false, "reason": "mini_gargoyle_stat_invalid", "field": field_name}
	if attack.weapon_ref != WEAPON_REF or attack.maximum_range_microfeet != 1_000_000:
		return {"success": false, "reason": "mini_gargoyle_attack_definition_mismatch"}
	if attack.required_acts != 1 or attack.strikes_per_act != 3 or attack.strike_profiles.size() != 3:
		return {"success": false, "reason": "mini_gargoyle_natural_sequence_invalid"}
	if actor.get_ability_daily_maximum(FURY_ABILITY_ID) != 1:
		return {"success": false, "reason": "mini_gargoyle_fury_allowance_invalid"}
	return {"success": true}
