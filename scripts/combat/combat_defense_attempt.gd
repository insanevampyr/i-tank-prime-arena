class_name CombatDefenseAttempt
extends RefCounted

const INELIGIBLE := "ineligible"
const ELIGIBLE_NOT_SELECTED := "eligible_not_selected"
const ATTEMPTED := "attempted"

var defense_type: StringName
var equipment_ref: StringName = &""
var eligibility: String = INELIGIBLE
var eligibility_reason: String = ""
var base_target: Variant = null
var target_modifier: int = 0
var final_target: Variant = null
var roll_bonus: int = 0
var natural_roll: Variant = null
var adjusted_roll: Variant = null
var rng_draw_index: Variant = null
var success: Variant = null
var critical_success: bool = false
var critical_failure: bool = false
var roll_id: String = ""
var critical_record_id: String = ""
var resources_spent: Dictionary = {}
var resolution_context: Dictionary = {}
var parent_event_id: String = ""
var result_event_id: String = ""


func _init(p_defense_type: StringName) -> void:
	defense_type = p_defense_type


func to_dictionary() -> Dictionary:
	return {
		"defense_type": String(defense_type),
		"equipment_ref": String(equipment_ref),
		"eligibility": eligibility,
		"eligibility_reason": eligibility_reason,
		"base_target": base_target,
		"target_modifier": target_modifier,
		"final_target": final_target,
		"roll_bonus": roll_bonus,
		"natural_d20": natural_roll,
		"adjusted_roll": adjusted_roll,
		"rng_draw_index": rng_draw_index,
		"success": success,
		"critical_success": critical_success,
		"critical_failure": critical_failure,
		"roll_id": roll_id,
		"critical_record_id": critical_record_id,
		"resources_spent": resources_spent.duplicate(true),
		"resolution_context": resolution_context.duplicate(true),
		"parent_event_id": parent_event_id,
		"result_event_id": result_event_id,
	}
