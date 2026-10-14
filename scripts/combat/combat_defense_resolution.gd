class_name CombatDefenseResolution
extends RefCounted

const STATUS_RESOLVING := "resolving"
const STATUS_DEFENDED := "defended"
const STATUS_EXHAUSTED := "defenses_exhausted"
const STATUS_PENDING_DODGE_DISPLACEMENT := "pending_dodge_displacement"

var defense_resolution_id: String
var attack_instance_id: String
var defender_id: StringName
var profile_id: StringName
var priority: PackedStringArray
var requested_at_us: int
var resolved_at_us: Variant = null
var status: String = STATUS_RESOLVING
var successful_defense_type: StringName = &""
var attempts: Array[CombatDefenseAttempt] = []
var pending_dodge_context: Dictionary = {}
var start_event_id: String = ""
var final_event_id: String = ""
var request_id: String
var revision: int = 0


func _init(
	p_defense_resolution_id: String,
	p_attack_instance_id: String,
	p_defender_id: StringName,
	p_profile: CombatDefenseProfile,
	p_requested_at_us: int,
	p_request_id: String
) -> void:
	defense_resolution_id = p_defense_resolution_id
	attack_instance_id = p_attack_instance_id
	defender_id = p_defender_id
	profile_id = p_profile.profile_id
	priority = p_profile.priority.duplicate()
	requested_at_us = p_requested_at_us
	request_id = p_request_id


func to_dictionary() -> Dictionary:
	var serialized_attempts: Array = []
	for attempt: CombatDefenseAttempt in attempts:
		serialized_attempts.append(attempt.to_dictionary())
	return {
		"defense_resolution_id": defense_resolution_id,
		"attack_instance_id": attack_instance_id,
		"defender_id": String(defender_id),
		"profile_id": String(profile_id),
		"priority": Array(priority),
		"requested_at_us": requested_at_us,
		"resolved_at_us": resolved_at_us,
		"status": status,
		"successful_defense_type": String(successful_defense_type),
		"attempts": serialized_attempts,
		"pending_dodge_context": pending_dodge_context.duplicate(true),
		"start_event_id": start_event_id,
		"final_event_id": final_event_id,
		"request_id": request_id,
		"revision": revision,
	}
