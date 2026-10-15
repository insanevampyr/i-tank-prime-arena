class_name CombatCriticalRecord
extends RefCounted

const RARITY_COMMON := &"common"
const RARITY_UNCOMMON := &"uncommon"
const RARITY_RARE := &"rare"
const CONSEQUENCE_UNASSIGNED := &"unassigned"
const CONSEQUENCE_SELECTED := &"selected"
const CONSEQUENCE_PENDING := &"pending"
const CONSEQUENCE_APPLIED := &"applied"
const CONSEQUENCE_PARTIAL := &"partially_applied"
const CONSEQUENCE_BLOCKED := &"blocked"

var critical_record_id: String
var roll_id: String
var roll_category: StringName
var result_kind: StringName
var natural_d20: int
var policy_id: StringName
var base_critical_success_max: int
var success_range_bonus: int
var critical_success_max: int
var critical_failure_min: int
var trigger_source_ref: String
var rarity_roll: int
var rarity_rng_draw_index: int
var rarity: StringName
var consequence_table_id: StringName
var outcome_id: StringName = &""
var consequence_status: StringName = CONSEQUENCE_UNASSIGNED
var consequence_reason: String = ""
var applied_effect_ids: PackedStringArray = PackedStringArray()
var blocked_effect_ids: PackedStringArray = PackedStringArray()
var source_actor_id: StringName
var target_actor_id: StringName
var resource_commits: Dictionary
var parent_event_id: String
var dependency_event_ids: PackedStringArray
var child_event_ids: PackedStringArray = PackedStringArray()
var event_id: String = ""


func _init(
	p_critical_record_id: String,
	p_roll_id: String,
	p_roll_category: StringName,
	p_result_kind: StringName,
	p_natural_d20: int,
	p_policy: CombatCriticalTriggerPolicy,
	p_rarity_roll: int,
	p_rarity_rng_draw_index: int,
	p_source_actor_id: StringName,
	p_target_actor_id: StringName,
	p_parent_event_id: String,
	p_dependency_event_ids: PackedStringArray = PackedStringArray(),
	p_resource_commits: Dictionary = {}
) -> void:
	assert(not p_critical_record_id.is_empty(), "Critical records require a stable identifier.")
	assert(not p_roll_id.is_empty(), "Critical records require a stable source-roll identifier.")
	assert(p_policy != null, "Critical records require their trigger policy.")
	assert(p_result_kind == CombatCriticalTriggerPolicy.RESULT_SUCCESS or p_result_kind == CombatCriticalTriggerPolicy.RESULT_FAILURE, "Critical records require a qualifying result.")
	assert(p_rarity_roll >= 1 and p_rarity_roll <= 100, "Critical rarity requires a d100 result.")
	critical_record_id = p_critical_record_id
	roll_id = p_roll_id
	roll_category = p_roll_category
	result_kind = p_result_kind
	natural_d20 = p_natural_d20
	policy_id = p_policy.policy_id
	base_critical_success_max = p_policy.critical_success_max
	success_range_bonus = p_policy.success_range_bonus
	critical_success_max = p_policy.get_effective_success_max()
	critical_failure_min = p_policy.critical_failure_min
	trigger_source_ref = p_policy.get_trigger_source(p_result_kind)
	rarity_roll = p_rarity_roll
	rarity_rng_draw_index = p_rarity_rng_draw_index
	rarity = classify_rarity(p_rarity_roll)
	consequence_table_id = p_policy.consequence_table_id
	source_actor_id = p_source_actor_id
	target_actor_id = p_target_actor_id
	resource_commits = p_resource_commits.duplicate(true)
	parent_event_id = p_parent_event_id
	dependency_event_ids = p_dependency_event_ids.duplicate()


static func classify_rarity(natural_d100: int) -> StringName:
	assert(natural_d100 >= 1 and natural_d100 <= 100, "Critical rarity classification requires a natural d100 result.")
	if natural_d100 <= 70:
		return RARITY_COMMON
	if natural_d100 <= 95:
		return RARITY_UNCOMMON
	return RARITY_RARE


func to_dictionary() -> Dictionary:
	return {
		"critical_record_id": critical_record_id,
		"roll_id": roll_id,
		"roll_category": String(roll_category),
		"result_kind": String(result_kind),
		"natural_d20": natural_d20,
		"policy_id": String(policy_id),
		"base_critical_success_max": base_critical_success_max,
		"success_range_bonus": success_range_bonus,
		"critical_success_max": critical_success_max,
		"critical_failure_min": critical_failure_min,
		"trigger_source_ref": trigger_source_ref,
		"rarity_roll": rarity_roll,
		"rarity_rng_draw_index": rarity_rng_draw_index,
		"rarity": String(rarity),
		"consequence_table_id": String(consequence_table_id),
		"outcome_id": String(outcome_id),
		"consequence_status": String(consequence_status),
		"consequence_reason": consequence_reason,
		"applied_effect_ids": Array(applied_effect_ids),
		"blocked_effect_ids": Array(blocked_effect_ids),
		"source_actor_id": String(source_actor_id),
		"target_actor_id": String(target_actor_id),
		"resource_commits": resource_commits.duplicate(true),
		"parent_event_id": parent_event_id,
		"dependency_event_ids": Array(dependency_event_ids),
		"child_event_ids": Array(child_event_ids),
		"event_id": event_id,
	}
