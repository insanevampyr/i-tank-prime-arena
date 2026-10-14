class_name CombatDodgeEnvironment
extends RefCounted

var environment_id: StringName
var information_complete: bool
var candidates: Array[CombatDodgeCandidate]
var source_ref: String


func _init(
	p_environment_id: StringName,
	p_information_complete: bool,
	p_candidates: Array[CombatDodgeCandidate] = [],
	p_source_ref: String = ""
) -> void:
	assert(not String(p_environment_id).is_empty(), "Dodge environments require a stable identifier.")
	environment_id = p_environment_id
	information_complete = p_information_complete
	candidates = p_candidates.duplicate()
	source_ref = p_source_ref


func to_dictionary() -> Dictionary:
	var serialized_candidates: Array = []
	for candidate: CombatDodgeCandidate in candidates:
		serialized_candidates.append(candidate.to_dictionary())
	return {
		"environment_id": String(environment_id),
		"information_complete": information_complete,
		"candidates": serialized_candidates,
		"source_ref": source_ref,
	}
