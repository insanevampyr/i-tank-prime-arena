class_name CombatActionInstance
extends RefCounted

const STATUS_IN_PROGRESS := "in_progress"
const STATUS_AWAITING_DEPENDENCIES := "awaiting_dependencies"
const STATUS_COMPLETED := "completed"
const STATUS_INTERRUPTED := "interrupted"

var action_instance_id: String
var action_definition_id: StringName
var actor_id: StringName
var initiative: int
var declared_at_us: int
var started_at_us: int
var at_at_start: int
var timing_anchor_us: int
var starting_interval_index: int
var final_effect_due_at_us: int
var completed_at_us: Variant = null
var interrupted_at_us: Variant = null
var required_acts: int
var completed_acts: int = 0
var status: String = STATUS_IN_PROGRESS
var dependency_action_ids: PackedStringArray
var request_id: String
var cause_event_id: String = ""
var interruption_reason: String = ""
var declaration_event_id: String = ""
var start_event_id: String = ""
var final_event_id: String = ""
var finalization_scheduled: bool = false
var revision: int = 0


func _init(
	p_action_instance_id: String,
	p_definition: CombatActionDefinition,
	p_actor_id: StringName,
	p_initiative: int,
	p_timestamp_us: int,
	p_at_at_start: int,
	p_timing_anchor_us: int,
	p_starting_interval_index: int,
	p_final_effect_due_at_us: int,
	p_dependency_action_ids: PackedStringArray,
	p_request_id: String
) -> void:
	action_instance_id = p_action_instance_id
	action_definition_id = p_definition.action_definition_id
	actor_id = p_actor_id
	initiative = p_initiative
	declared_at_us = p_timestamp_us
	started_at_us = p_timestamp_us
	at_at_start = p_at_at_start
	timing_anchor_us = p_timing_anchor_us
	starting_interval_index = p_starting_interval_index
	final_effect_due_at_us = p_final_effect_due_at_us
	required_acts = p_definition.required_acts
	dependency_action_ids = p_dependency_action_ids.duplicate()
	request_id = p_request_id


func is_terminal() -> bool:
	return status == STATUS_COMPLETED or status == STATUS_INTERRUPTED


func to_dictionary() -> Dictionary:
	return {
		"action_instance_id": action_instance_id,
		"action_definition_id": String(action_definition_id),
		"actor_id": String(actor_id),
		"initiative": initiative,
		"declared_at_us": declared_at_us,
		"started_at_us": started_at_us,
		"at_at_start": at_at_start,
		"timing_anchor_us": timing_anchor_us,
		"starting_interval_index": starting_interval_index,
		"final_effect_due_at_us": final_effect_due_at_us,
		"completed_at_us": completed_at_us,
		"interrupted_at_us": interrupted_at_us,
		"required_acts": required_acts,
		"completed_acts": completed_acts,
		"status": status,
		"dependency_action_ids": Array(dependency_action_ids),
		"request_id": request_id,
		"cause_event_id": cause_event_id,
		"interruption_reason": interruption_reason,
		"declaration_event_id": declaration_event_id,
		"start_event_id": start_event_id,
		"final_event_id": final_event_id,
		"finalization_scheduled": finalization_scheduled,
		"revision": revision,
	}
