class_name VaelisForceFixture
extends RefCounted

const HitLocations = preload("res://scripts/combat/combat_hit_location_catalog.gd")

const FORCE_BOLT_ID := &"force_bolt"
const FORCE_SHIELD_ID := &"force_shield"
const FORCE_BOLT_ATTACK_ID := &"vaelis_force_bolt_projectile"
const FORCE_SHIELD_ACTION_ID := &"vaelis_force_shield_cast"
const FORCE_BOLT_MANA_COST := 2
const FORCE_SHIELD_MANA_COST := 4
const FORCE_BOLT_RANGE_MICROFEET := 10_000_000
const FORCE_KNOCKBACK_MICROFEET := 2_000_000
const FORCE_SHIELD_CAPACITY := 20
const SOURCE_REF := "PRIME-V3 p. 250, Force Bolt and Force Shield; supplied Vaelis record"


static func make_force_bolt_attack_definition(casting_focus_ref: StringName) -> CombatAttackDefinition:
	var targeting: Dictionary = HitLocations.get_same_size_attack_profile()
	var location_multipliers: Dictionary = (targeting.get("location_multipliers", {}) as Dictionary).duplicate(true)
	var damage := CombatPhysicalDamageDefinition.new(
		1, 6, 0, false, true, location_multipliers, null, true,
		CombatPhysicalDamageDefinition.ROUNDING_FLOOR, PackedStringArray([SOURCE_REF])
	)
	return CombatAttackDefinition.new(
		FORCE_BOLT_ATTACK_ID, casting_focus_ref, 1, true, true, 0,
		targeting.get("acc_modifiers_by_location", {}).duplicate(true),
		targeting.get("allowed_target_locations", PackedStringArray()).duplicate(),
		0, FORCE_BOLT_RANGE_MICROFEET, true, PackedStringArray([SOURCE_REF]),
		&"magic_projectile", PackedStringArray(["force"]), false,
		CombatAttackDefinition.DUCKING_UNRESOLVED, damage,
		CombatCriticalTriggerPolicy.new(&"vaelis_force_bolt_critical", 1, 0, 20, &"", "PRIME natural 1", "PRIME natural 20", PackedStringArray([SOURCE_REF])),
		false, true, 1
	)


static func make_force_shield_action_definition() -> CombatActionDefinition:
	return CombatActionDefinition.new(
		FORCE_SHIELD_ACTION_ID, 1, true, true, {"mana": FORCE_SHIELD_MANA_COST},
		{
			"verified_special": {
				"kind": "persistent_damage_shield",
				"special_id": String(FORCE_SHIELD_ID),
				"target_mode": "self_or_touch",
				"requires_ss_check": true,
				"shield_id": String(FORCE_SHIELD_ID),
				"capacity": FORCE_SHIELD_CAPACITY,
				"physical_attacker_knockback_microfeet": FORCE_KNOCKBACK_MICROFEET,
			},
		},
		PackedStringArray([SOURCE_REF, "Task 34B owner ruling: no duration; persists until depleted or voluntarily canceled"])
	)


static func default_nac_automation_settings() -> Dictionary:
	return {
		"profile": "Balanced",
		"automatic_enabled": false,
		"minimum_mana_reserve": 0,
		"automatic_nac_budget": 5,
		"emergency_defense_enabled": true,
		"offensive_triggers_enabled": true,
		"ally_protection_enabled": false,
		"priority": PackedStringArray(["force_bolt"]),
	}
