class_name CombatCriticalTriggerPolicy
extends RefCounted

const RESULT_NONE := &"none"
const RESULT_SUCCESS := &"success"
const RESULT_FAILURE := &"failure"

var policy_id: StringName
var critical_success_max: int
var success_range_bonus: int
var critical_failure_min: int
var consequence_table_id: StringName
var success_source_ref: String
var failure_source_ref: String
var source_refs: PackedStringArray


func _init(
	p_policy_id: StringName = &"generic_d20",
	p_critical_success_max: int = 1,
	p_success_range_bonus: int = 0,
	p_critical_failure_min: int = 20,
	p_consequence_table_id: StringName = &"",
	p_success_source_ref: String = "PRIME-V3 pp. 16, 92, 350",
	p_failure_source_ref: String = "PRIME-V3 pp. 16, 92, 350",
	p_source_refs: PackedStringArray = PackedStringArray()
) -> void:
	assert(not String(p_policy_id).is_empty(), "Critical trigger policies require a stable identifier.")
	assert(p_critical_success_max >= 1 and p_critical_success_max <= 19, "Critical-success maximum must be within the d20 success range.")
	assert(p_success_range_bonus == 0 or p_success_range_bonus == 1, "+1 Critical Range may expand success only and by exactly one.")
	assert(p_critical_failure_min >= 2 and p_critical_failure_min <= 20, "Critical-failure minimum must be within the d20 failure range.")
	assert(p_critical_success_max + p_success_range_bonus < p_critical_failure_min, "Critical success and failure ranges cannot overlap.")
	policy_id = p_policy_id
	critical_success_max = p_critical_success_max
	success_range_bonus = p_success_range_bonus
	critical_failure_min = p_critical_failure_min
	consequence_table_id = p_consequence_table_id
	success_source_ref = p_success_source_ref
	failure_source_ref = p_failure_source_ref
	source_refs = p_source_refs.duplicate()


func get_effective_success_max() -> int:
	return critical_success_max + success_range_bonus


func classify(natural_d20: int) -> StringName:
	assert(natural_d20 >= 1 and natural_d20 <= 20, "Critical classification requires a natural d20 result.")
	if natural_d20 <= get_effective_success_max():
		return RESULT_SUCCESS
	if natural_d20 >= critical_failure_min:
		return RESULT_FAILURE
	return RESULT_NONE


func get_trigger_source(result_kind: StringName) -> String:
	if result_kind == RESULT_SUCCESS:
		return success_source_ref
	if result_kind == RESULT_FAILURE:
		return failure_source_ref
	return ""


func to_dictionary() -> Dictionary:
	return {
		"policy_id": String(policy_id),
		"critical_success_max": critical_success_max,
		"success_range_bonus": success_range_bonus,
		"effective_success_max": get_effective_success_max(),
		"critical_failure_min": critical_failure_min,
		"consequence_table_id": String(consequence_table_id),
		"success_source_ref": success_source_ref,
		"failure_source_ref": failure_source_ref,
		"source_refs": Array(source_refs),
	}
