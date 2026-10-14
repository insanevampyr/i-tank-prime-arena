class_name CombatEvent
extends RefCounted

var event_id: String
var timestamp_us: int
var initiative: int
var stable_sequence: int
var event_type: StringName
var source_actor_id: StringName
var target_actor_id: StringName
var parent_event_id: String
var dependency_event_ids: PackedStringArray
var payload: Dictionary
var resource_commitments: Dictionary


func _init(
	p_event_id: String,
	p_timestamp_us: int,
	p_initiative: int,
	p_stable_sequence: int,
	p_event_type: StringName,
	p_source_actor_id: StringName = &"",
	p_target_actor_id: StringName = &"",
	p_parent_event_id: String = "",
	p_dependency_event_ids: PackedStringArray = PackedStringArray(),
	p_payload: Dictionary = {},
	p_resource_commitments: Dictionary = {}
) -> void:
	assert(not p_event_id.is_empty(), "Combat events require an identifier.")
	assert(p_timestamp_us >= 0, "Combat event timestamps cannot be negative.")
	event_id = p_event_id
	timestamp_us = p_timestamp_us
	initiative = p_initiative
	stable_sequence = p_stable_sequence
	event_type = p_event_type
	source_actor_id = p_source_actor_id
	target_actor_id = p_target_actor_id
	parent_event_id = p_parent_event_id
	dependency_event_ids = p_dependency_event_ids.duplicate()
	payload = p_payload.duplicate(true)
	resource_commitments = p_resource_commitments.duplicate(true)


func to_dictionary() -> Dictionary:
	return {
		"event_id": event_id,
		"timestamp_us": timestamp_us,
		"initiative": initiative,
		"stable_sequence": stable_sequence,
		"event_type": String(event_type),
		"source_actor_id": String(source_actor_id),
		"target_actor_id": String(target_actor_id),
		"parent_event_id": parent_event_id,
		"dependency_event_ids": Array(dependency_event_ids),
		"payload": payload.duplicate(true),
		"resource_commitments": resource_commitments.duplicate(true),
	}
