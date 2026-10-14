class_name CombatDamageResolution
extends RefCounted

const STATUS_RESOLVED := "resolved"

var damage_resolution_id: String
var attack_instance_id: String
var attacker_id: StringName
var target_id: StringName
var request_id: String
var resolved_at_us: int
var weapon_rolls: Array[int] = []
var rng_draw_indices: Array[int] = []
var weapon_dice_total: int = 0
var flat_bonus: int = 0
var strength_bonus: int = 0
var pre_multiplier_total: int = 0
var applied_multipliers: Array = []
var multiplied_total: int = 0
var armor_equipment_ref: StringName = &""
var armor_slot: StringName = &""
var armor_tal: int = 0
var natural_armor_level: int = 0
var type_response: Dictionary = {}
var minimum_one_applied: bool = false
var final_damage: int = 0
var hpc_before: int = 0
var hpc_after: int = 0
var event_id: String = ""
var status: String = STATUS_RESOLVED


func _init(
	p_damage_resolution_id: String,
	p_attack_instance_id: String,
	p_attacker_id: StringName,
	p_target_id: StringName,
	p_request_id: String,
	p_resolved_at_us: int
) -> void:
	damage_resolution_id = p_damage_resolution_id
	attack_instance_id = p_attack_instance_id
	attacker_id = p_attacker_id
	target_id = p_target_id
	request_id = p_request_id
	resolved_at_us = p_resolved_at_us


func to_dictionary() -> Dictionary:
	return {
		"damage_resolution_id": damage_resolution_id,
		"attack_instance_id": attack_instance_id,
		"attacker_id": String(attacker_id),
		"target_id": String(target_id),
		"request_id": request_id,
		"resolved_at_us": resolved_at_us,
		"weapon_rolls": weapon_rolls.duplicate(),
		"rng_draw_indices": rng_draw_indices.duplicate(),
		"weapon_dice_total": weapon_dice_total,
		"flat_bonus": flat_bonus,
		"strength_bonus": strength_bonus,
		"pre_multiplier_total": pre_multiplier_total,
		"applied_multipliers": applied_multipliers.duplicate(true),
		"multiplied_total": multiplied_total,
		"armor_equipment_ref": String(armor_equipment_ref),
		"armor_slot": String(armor_slot),
		"armor_tal": armor_tal,
		"natural_armor_level": natural_armor_level,
		"type_response": type_response.duplicate(true),
		"minimum_one_applied": minimum_one_applied,
		"final_damage": final_damage,
		"hpc_before": hpc_before,
		"hpc_after": hpc_after,
		"event_id": event_id,
		"status": status,
	}
