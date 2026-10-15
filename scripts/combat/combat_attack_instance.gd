class_name CombatAttackInstance
extends RefCounted

const STATUS_EXECUTING := "executing"
const STATUS_PENDING_DEFENSE := "pending_defense"
const STATUS_MISSED := "missed"
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
var delivery_class: StringName
var damage_types: PackedStringArray
var physical_soak_eligible: Variant
var ducking_policy: StringName
var is_back_attack: bool
var declared_at_us: int
var resolved_at_us: Variant = null
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
	p_is_back_attack: bool = false
) -> void:
	attack_instance_id = p_attack_instance_id
	attack_definition_id = p_definition.attack_definition_id
	action_instance_id = p_action_instance_id
	attacker_id = p_attacker_id
	target_id = p_target_id
	weapon_ref = p_definition.weapon_ref
	target_location = p_target_location
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


func to_dictionary() -> Dictionary:
	return {
		"attack_instance_id": attack_instance_id,
		"attack_definition_id": String(attack_definition_id),
		"action_instance_id": action_instance_id,
		"attacker_id": String(attacker_id),
		"target_id": String(target_id),
		"weapon_ref": String(weapon_ref),
		"target_location": String(target_location),
		"delivery_class": String(delivery_class),
		"damage_types": Array(damage_types),
		"physical_soak_eligible": physical_soak_eligible,
		"ducking_policy": String(ducking_policy),
		"is_back_attack": is_back_attack,
		"declared_at_us": declared_at_us,
		"resolved_at_us": resolved_at_us,
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
	}
