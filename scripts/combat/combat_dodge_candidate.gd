class_name CombatDodgeCandidate
extends RefCounted

var candidate_id: StringName
var destination_microfeet: Vector2i
var movement_cost_microfeet: int
var in_place_duck: bool
var path_clear: bool
var collision_free: bool
var terrain_legal: bool
var unoccupied: bool
var escapes_attack: bool
var duck_legally_sufficient: bool
var known_hazard_score: int
var source_ref: String


func _init(
	p_candidate_id: StringName,
	p_destination_microfeet: Vector2i,
	p_movement_cost_microfeet: int,
	p_in_place_duck: bool = false,
	p_path_clear: bool = true,
	p_collision_free: bool = true,
	p_terrain_legal: bool = true,
	p_unoccupied: bool = true,
	p_escapes_attack: bool = true,
	p_duck_legally_sufficient: bool = false,
	p_known_hazard_score: int = 0,
	p_source_ref: String = ""
) -> void:
	assert(not String(p_candidate_id).is_empty(), "Dodge candidates require a stable identifier.")
	assert(p_movement_cost_microfeet >= 0, "Dodge candidate movement cost must be non-negative.")
	assert(p_known_hazard_score >= 0, "Dodge candidate hazard score must be non-negative.")
	candidate_id = p_candidate_id
	destination_microfeet = p_destination_microfeet
	movement_cost_microfeet = p_movement_cost_microfeet
	in_place_duck = p_in_place_duck
	path_clear = p_path_clear
	collision_free = p_collision_free
	terrain_legal = p_terrain_legal
	unoccupied = p_unoccupied
	escapes_attack = p_escapes_attack
	duck_legally_sufficient = p_duck_legally_sufficient
	known_hazard_score = p_known_hazard_score
	source_ref = p_source_ref


func to_dictionary() -> Dictionary:
	return {
		"candidate_id": String(candidate_id),
		"destination_microfeet": [destination_microfeet.x, destination_microfeet.y],
		"movement_cost_microfeet": movement_cost_microfeet,
		"in_place_duck": in_place_duck,
		"path_clear": path_clear,
		"collision_free": collision_free,
		"terrain_legal": terrain_legal,
		"unoccupied": unoccupied,
		"escapes_attack": escapes_attack,
		"duck_legally_sufficient": duck_legally_sufficient,
		"known_hazard_score": known_hazard_score,
		"source_ref": source_ref,
	}
