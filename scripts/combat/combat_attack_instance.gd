class_name CombatAttackInstance
extends RefCounted

const STATUS_EXECUTING := "executing"
const STATUS_PENDING_DEFENSE := "pending_defense"
const STATUS_MISSED := "missed"
const STATUS_FINAL_LEGALITY_FAILED := "final_legality_failed"
const STATUS_INTERRUPTED := "interrupted"
const STATUS_PENDING_DODGE_DISPLACEMENT := "pending_dodge_displacement"
const STATUS_DEFENDED := "defended"
const STATUS_DEFENSES_EXHAUSTED := "defenses_exhausted"
const STATUS_DAMAGE_RESOLVED := "damage_resolved"

var attack_instance_id: String
var attack_definition_id: StringName
var action_instance_id: String
var attacker_id: StringName
var target_id: StringName
var weapon_ref: StringName
var target_location: StringName
var size_relationship: StringName = &""
var attacker_size_category: StringName = &""
var target_size_category: StringName = &""
var tiny_target_dodge_bonus: int = 0
var delivery_class: StringName
var damage_types: PackedStringArray
var physical_soak_eligible: Variant
var ducking_policy: StringName
var is_back_attack: bool
var declared_at_us: int
var declared_attacker_position_microfeet := Vector2i.ZERO
var declared_target_position_microfeet := Vector2i.ZERO
var declared_attacker_elevation_microfeet: int = 0
var declared_target_elevation_microfeet: int = 0
var declaration_line_of_sight_verified: Variant = null
var resolved_at_us: Variant = null
var final_attacker_position_microfeet: Variant = null
var final_target_position_microfeet: Variant = null
var final_attacker_elevation_microfeet: Variant = null
var final_target_elevation_microfeet: Variant = null
var final_distance_squared_microfeet: Variant = null
var final_range_legal: Variant = null
var final_line_of_sight_legal: Variant = null
var final_legality_reason: String = ""
var base_acc: int
var base_acc_modifier: int
var location_acc_modifier: int
var acc_target: int
var roll_bonus: int
var rng_draw_index: Variant = null
var natural_roll: Variant = null
var adjusted_roll: Variant = null
var accuracy_success: Variant = null
var critical_success: bool = false
var critical_failure: bool = false
var critical_record_id: String = ""
var accuracy_event_id: String = ""
var status: String = STATUS_EXECUTING
var result_event_id: String = ""
var defense_resolution_id: String = ""
var damage_resolution_id: String = ""
var consequence_damage_multipliers: Array[Dictionary] = []
var same_attack_condition_protected_actor_id: StringName = &""
var revision: int = 0
var strike_index: int = 1
var strikes_per_act: int = 1
var automatic_accuracy_reason: String = ""
var strike_label: String = ""
var damage_dice_count_override: Variant = null
var damage_die_sides_override: Variant = null


func _init(
	p_attack_instance_id: String,
	p_definition: CombatAttackDefinition,
	p_action_instance_id: String,
	p_attacker_id: StringName,
	p_target_id: StringName,
	p_target_location: StringName,
	p_declared_at_us: int,
	p_base_acc: int,
	p_location_acc_modifier: int,
	p_roll_bonus: int,
	p_is_back_attack: bool = false,
	p_size_relationship: StringName = &"",
	p_attacker_size_category: StringName = &"",
	p_target_size_category: StringName = &"",
	p_tiny_target_dodge_bonus: int = 0,
	p_strike_index: int = 1,
	p_strikes_per_act: int = 1
) -> void:
	attack_instance_id = p_attack_instance_id
	attack_definition_id = p_definition.attack_definition_id
	action_instance_id = p_action_instance_id
	attacker_id = p_attacker_id
	target_id = p_target_id
	weapon_ref = p_definition.weapon_ref
	target_location = p_target_location
	size_relationship = p_size_relationship
	attacker_size_category = p_attacker_size_category
	target_size_category = p_target_size_category
	tiny_target_dodge_bonus = p_tiny_target_dodge_bonus
	delivery_class = p_definition.delivery_class
	damage_types = p_definition.damage_types.duplicate()
	physical_soak_eligible = p_definition.physical_soak_eligible
	ducking_policy = p_definition.ducking_policy
	is_back_attack = p_is_back_attack
	declared_at_us = p_declared_at_us
	base_acc = p_base_acc
	base_acc_modifier = p_definition.base_acc_modifier
	location_acc_modifier = p_location_acc_modifier
	acc_target = base_acc + base_acc_modifier + location_acc_modifier
	roll_bonus = p_roll_bonus
	strike_index = p_strike_index
	strikes_per_act = p_strikes_per_act


func to_dictionary() -> Dictionary:
	return {
		"attack_instance_id": attack_instance_id,
		"attack_definition_id": String(attack_definition_id),
		"action_instance_id": action_instance_id,
		"attacker_id": String(attacker_id),
		"target_id": String(target_id),
		"weapon_ref": String(weapon_ref),
		"target_location": String(target_location),
		"size_relationship": String(size_relationship),
		"attacker_size_category": String(attacker_size_category),
		"target_size_category": String(target_size_category),
		"tiny_target_dodge_bonus": tiny_target_dodge_bonus,
		"delivery_class": String(delivery_class),
		"damage_types": Array(damage_types),
		"physical_soak_eligible": physical_soak_eligible,
		"ducking_policy": String(ducking_policy),
		"is_back_attack": is_back_attack,
		"declared_at_us": declared_at_us,
		"declared_attacker_position_microfeet": [declared_attacker_position_microfeet.x, declared_attacker_position_microfeet.y],
		"declared_target_position_microfeet": [declared_target_position_microfeet.x, declared_target_position_microfeet.y],
		"declared_attacker_elevation_microfeet": declared_attacker_elevation_microfeet,
		"declared_target_elevation_microfeet": declared_target_elevation_microfeet,
		"declaration_line_of_sight_verified": declaration_line_of_sight_verified,
		"resolved_at_us": resolved_at_us,
		"final_attacker_position_microfeet": null if final_attacker_position_microfeet == null else [final_attacker_position_microfeet.x, final_attacker_position_microfeet.y],
		"final_target_position_microfeet": null if final_target_position_microfeet == null else [final_target_position_microfeet.x, final_target_position_microfeet.y],
		"final_attacker_elevation_microfeet": final_attacker_elevation_microfeet,
		"final_target_elevation_microfeet": final_target_elevation_microfeet,
		"final_distance_squared_microfeet": final_distance_squared_microfeet,
		"final_range_legal": final_range_legal,
		"final_line_of_sight_legal": final_line_of_sight_legal,
		"final_legality_reason": final_legality_reason,
		"base_acc": base_acc,
		"base_acc_modifier": base_acc_modifier,
		"location_acc_modifier": location_acc_modifier,
		"acc_target": acc_target,
		"roll_bonus": roll_bonus,
		"rng_draw_index": rng_draw_index,
		"natural_roll": natural_roll,
		"adjusted_roll": adjusted_roll,
		"accuracy_success": accuracy_success,
		"critical_success": critical_success,
		"critical_failure": critical_failure,
		"critical_record_id": critical_record_id,
		"accuracy_event_id": accuracy_event_id,
		"status": status,
		"result_event_id": result_event_id,
		"defense_resolution_id": defense_resolution_id,
		"damage_resolution_id": damage_resolution_id,
		"consequence_damage_multipliers": consequence_damage_multipliers.duplicate(true),
		"same_attack_condition_protected_actor_id": String(same_attack_condition_protected_actor_id),
		"revision": revision,
		"strike_index": strike_index,
		"strikes_per_act": strikes_per_act,
		"automatic_accuracy_reason": automatic_accuracy_reason,
		"strike_label": strike_label,
		"damage_dice_count_override": damage_dice_count_override,
		"damage_die_sides_override": damage_die_sides_override,
	}
