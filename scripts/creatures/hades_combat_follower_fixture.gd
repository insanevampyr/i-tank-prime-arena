class_name HadesCombatFollowerFixture
extends RefCounted

const Catalog = preload("res://scripts/data/combat_definition_catalog.gd")
const HitLocations = preload("res://scripts/combat/combat_hit_location_catalog.gd")

const CREATURE_ID := &"hades_combat_follower"
const CHARACTER_DEFINITION_ID := &"prime_v3_uncommon_hades_combat_follower"
const LOADOUT_DEFINITION_ID := &"prime_v3_hades_combat_follower_short_sword"
const WEAPON_REF := &"prime_v3_hades_follower_short_sword"
const RAGE_ACTION_ID := &"prime_v3_hades_combat_follower_rage"
const RAGE_EFFECT_ID := &"combat_rage"
const CALLED_SHOT_ACTION_ID := &"prime_v3_hades_combat_follower_called_shot"
const REJUVENATING_MIST_ACTION_ID := &"prime_v3_hades_combat_follower_rejuvenating_mist"
const DEFENSIVE_BUFF_ACTION_ID := &"prime_v3_hades_combat_follower_defensive_buff"
const DEFENSIVE_BUFF_EFFECT_ID := &"combat_defensive_buff"
const RAGE_DURATION_US := 120_000_000
const ABILITY_FALLBACK_AP_COST := 1
const SOURCE_REF := "Uncommon Hades Follower Combat.doc and ITank Prime V3 Combat Rage entry"


static func make_actor(actor_id: StringName, display_name: String) -> CombatActorDefinition:
	var catalog := Catalog.load_default_fixture_catalog()
	var result := catalog.instantiate_actor(CHARACTER_DEFINITION_ID, LOADOUT_DEFINITION_ID, actor_id, display_name)
	return result.get("actor") as CombatActorDefinition


static func make_attack_definition(targeting_profile: Dictionary) -> CombatAttackDefinition:
	var catalog := Catalog.load_default_fixture_catalog()
	var sword := catalog.get_weapon(WEAPON_REF)
	return null if sword == null else sword.make_attack_definition(&"prime_v3_hades_follower_short_sword_attack", targeting_profile) as CombatAttackDefinition


static func make_rage_action_definition() -> CombatActionDefinition:
	return CombatActionDefinition.new(
		RAGE_ACTION_ID,
		2,
		true,
		true,
		{},
		{
			"ability_use": {"ability_id": String(RAGE_ACTION_ID), "fallback_ap_cost": ABILITY_FALLBACK_AP_COST},
			"timed_stat_effect": {
				"effect_id": String(RAGE_EFFECT_ID),
				"duration_us": RAGE_DURATION_US,
				"stat_modifiers": {"sb": 2, "nal": -2, "dt": -1, "dp": -1},
				"successful_hit_knockback_microfeet": 2_000_000,
			},
			"verified_special": {"kind": "timed_stat_effect", "target_mode": "self"},
		},
		PackedStringArray([
			"ITank Prime V3 Combat Rage: two-Act activation; +2 SB, -2 NAL, -1 DT, -1 DP for two minutes",
			"Uncommon Hades Follower Combat.doc: casts Rage first and has Combat Rage (2)",
		])
	)


static func make_called_shot_action_definition() -> CombatActionDefinition:
	return CombatActionDefinition.new(
		CALLED_SHOT_ACTION_ID, 1, true, true, {},
		{
			"ability_use": {"ability_id": String(CALLED_SHOT_ACTION_ID), "fallback_ap_cost": ABILITY_FALLBACK_AP_COST},
			"verified_special": {"kind": "called_shot", "target_mode": "other"},
		},
		PackedStringArray(["ITank Prime V3 p. 236: Called Shot selects and announces a body location during the first Act; attacks in the next Act are accurate without an ACC roll"])
	)


static func make_rejuvenating_mist_action_definition() -> CombatActionDefinition:
	return CombatActionDefinition.new(
		REJUVENATING_MIST_ACTION_ID, 1, true, true, {},
		{
			"ability_use": {"ability_id": String(REJUVENATING_MIST_ACTION_ID), "fallback_ap_cost": ABILITY_FALLBACK_AP_COST},
			"verified_special": {"kind": "healing", "target_mode": "self_or_touch", "dice_count": 2, "die_sides": 6, "flat_bonus": 2},
		},
		PackedStringArray(["ITank Prime V3 p. 236: Rejuvenating Mist restores 2d6+2 HPC to self or a touched target"])
	)


static func make_defensive_buff_action_definition() -> CombatActionDefinition:
	return CombatActionDefinition.new(
		DEFENSIVE_BUFF_ACTION_ID, 2, true, true, {},
		{
			"ability_use": {"ability_id": String(DEFENSIVE_BUFF_ACTION_ID), "fallback_ap_cost": ABILITY_FALLBACK_AP_COST},
			"verified_special": {"kind": "timed_stat_effect", "target_mode": "self_or_touch", "requires_material": "dirt"},
			"timed_stat_effect": {
				"effect_id": String(DEFENSIVE_BUFF_EFFECT_ID),
				"duration_us": RAGE_DURATION_US,
				"stat_modifiers": {"nal": 2},
			},
		},
		PackedStringArray(["ITank Prime V3 p. 236: Defensive Buff requires dirt, takes two Acts, grants +2 NAL for two minutes, and does not stack"])
	)


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
		{},
		PackedStringArray(["Uncommon Hades Follower Combat.doc: no worn armor; effective NAL +1 from follower ability"])
	)


static func validate_actor(actor: CombatActorDefinition, attack: CombatAttackDefinition) -> Dictionary:
	if actor == null or attack == null:
		return {"success": false, "reason": "hades_follower_component_missing"}
	if actor.size_category != HitLocations.SIZE_MEDIUM:
		return {"success": false, "reason": "hades_follower_size_invalid"}
	for field_name: String in ["hpm", "at", "init", "acc", "mr", "nal", "dt", "dp", "physical_soak", "rb", "sb"]:
		if actor.get_combat_stat(field_name) == null:
			return {"success": false, "reason": "hades_follower_combat_stat_unresolved", "field": field_name}
	if int(actor.attributes.get("str", -1)) < 6:
		return {"success": false, "reason": "hades_follower_short_sword_strength_requirement_not_met"}
	if not actor.equipment_refs.has(String(WEAPON_REF)):
		return {"success": false, "reason": "hades_follower_short_sword_not_registered"}
	if attack.weapon_ref != WEAPON_REF or attack.maximum_range_microfeet != 2_000_000:
		return {"success": false, "reason": "hades_follower_short_sword_definition_mismatch"}
	if attack.strikes_per_act != 1 or attack.required_acts != 1:
		return {"success": false, "reason": "hades_follower_attack_sequence_invalid"}
	if int(actor.resource_maxima.get("ap", -1)) != 9:
		return {"success": false, "reason": "hades_follower_ap_invalid"}
	var expected_allowances := {
		String(CALLED_SHOT_ACTION_ID): 2,
		String(REJUVENATING_MIST_ACTION_ID): 3,
		String(RAGE_ACTION_ID): 2,
		String(DEFENSIVE_BUFF_ACTION_ID): 2,
	}
	for ability_id: String in expected_allowances:
		if actor.get_ability_daily_maximum(StringName(ability_id)) != expected_allowances[ability_id]:
			return {"success": false, "reason": "hades_follower_ability_allowance_invalid", "ability_id": ability_id}
	return {"success": true}
