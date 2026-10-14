class_name CombatDodgeContext
extends RefCounted

const SELECTION_RESOLVED := &"resolved"
const SELECTION_AMBIGUOUS := &"ambiguous"
const SELECTION_UNAVAILABLE := &"unavailable"

var selection_status: StringName
var destination_microfeet: Vector2i
var movement_cost_microfeet: Variant
var in_place_duck: bool
var authoritative_path_valid: bool
var authoritative_escape_valid: bool
var source_ref: String
var candidate_id: StringName
var environment_id: StringName
var authoritative_collision_free: Variant
var authoritative_terrain_legal: Variant
var authoritative_unoccupied: Variant
var known_hazard_score: Variant
var selection_reason: String


func _init(
	p_selection_status: StringName,
	p_destination_microfeet: Vector2i = Vector2i.ZERO,
	p_movement_cost_microfeet: Variant = null,
	p_in_place_duck: bool = false,
	p_authoritative_path_valid: bool = false,
	p_authoritative_escape_valid: bool = false,
	p_source_ref: String = "",
	p_candidate_id: StringName = &"",
	p_environment_id: StringName = &"",
	p_authoritative_collision_free: Variant = null,
	p_authoritative_terrain_legal: Variant = null,
	p_authoritative_unoccupied: Variant = null,
	p_known_hazard_score: Variant = null,
	p_selection_reason: String = ""
) -> void:
	assert(
		p_selection_status == SELECTION_RESOLVED
		or p_selection_status == SELECTION_AMBIGUOUS
		or p_selection_status == SELECTION_UNAVAILABLE,
		"Dodge selection status must be resolved, ambiguous, or unavailable."
	)
	if p_movement_cost_microfeet != null:
		assert(typeof(p_movement_cost_microfeet) == TYPE_INT and int(p_movement_cost_microfeet) >= 0, "Dodge movement cost must be a non-negative integer.")
	if p_known_hazard_score != null:
		assert(typeof(p_known_hazard_score) == TYPE_INT and int(p_known_hazard_score) >= 0, "Dodge hazard score must be a non-negative integer.")
	selection_status = p_selection_status
	destination_microfeet = p_destination_microfeet
	movement_cost_microfeet = p_movement_cost_microfeet
	in_place_duck = p_in_place_duck
	authoritative_path_valid = p_authoritative_path_valid
	authoritative_escape_valid = p_authoritative_escape_valid
	source_ref = p_source_ref
	candidate_id = p_candidate_id
	environment_id = p_environment_id
	authoritative_collision_free = p_authoritative_collision_free
	authoritative_terrain_legal = p_authoritative_terrain_legal
	authoritative_unoccupied = p_authoritative_unoccupied
	known_hazard_score = p_known_hazard_score
	selection_reason = p_selection_reason


func to_dictionary() -> Dictionary:
	return {
		"selection_status": String(selection_status),
		"destination_microfeet": [destination_microfeet.x, destination_microfeet.y],
		"movement_cost_microfeet": movement_cost_microfeet,
		"in_place_duck": in_place_duck,
		"authoritative_path_valid": authoritative_path_valid,
		"authoritative_escape_valid": authoritative_escape_valid,
		"source_ref": source_ref,
		"candidate_id": String(candidate_id),
		"environment_id": String(environment_id),
		"authoritative_collision_free": authoritative_collision_free,
		"authoritative_terrain_legal": authoritative_terrain_legal,
		"authoritative_unoccupied": authoritative_unoccupied,
		"known_hazard_score": known_hazard_score,
		"selection_reason": selection_reason,
	}
