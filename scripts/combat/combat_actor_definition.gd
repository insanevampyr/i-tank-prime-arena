class_name CombatActorDefinition
extends RefCounted

const REQUIRED_CORE_ATTRIBUTES := [
	"str", "end", "spd", "dex", "wis", "int", "wit", "man", "luk", "app",
]
const REQUIRED_COMBAT_STATS := [
	"hpm", "acc", "at", "init", "mr", "nal", "dt", "dp", "physical_soak",
]

var actor_id: StringName
var actor_kind: StringName
var display_name: String
var attributes: Dictionary
var combat_stats: Dictionary
var resource_maxima: Dictionary
var equipment_refs: PackedStringArray
var defensive_capabilities: Dictionary
var field_sources: Dictionary
var unresolved_fields: PackedStringArray


func _init(
	p_actor_id: StringName,
	p_actor_kind: StringName,
	p_display_name: String,
	p_attributes: Dictionary,
	p_combat_stats: Dictionary,
	p_resource_maxima: Dictionary = {},
	p_equipment_refs: PackedStringArray = PackedStringArray(),
	p_defensive_capabilities: Dictionary = {},
	p_field_sources: Dictionary = {},
	p_unresolved_fields: PackedStringArray = PackedStringArray()
) -> void:
	assert(not String(p_actor_id).is_empty(), "Combat actors require a stable identifier.")
	assert(not String(p_actor_kind).is_empty(), "Combat actors require a stable kind.")
	actor_id = p_actor_id
	actor_kind = p_actor_kind
	display_name = p_display_name
	attributes = p_attributes.duplicate(true)
	combat_stats = p_combat_stats.duplicate(true)
	resource_maxima = p_resource_maxima.duplicate(true)
	equipment_refs = p_equipment_refs.duplicate()
	defensive_capabilities = p_defensive_capabilities.duplicate(true)
	field_sources = p_field_sources.duplicate(true)
	unresolved_fields = _build_unresolved_fields(p_unresolved_fields)
	_validate_known_values()


func has_resolved_field(field_name: String) -> bool:
	return attributes.has(field_name) or combat_stats.has(field_name) or resource_maxima.has(field_name)


func get_combat_stat(field_name: String) -> Variant:
	if not combat_stats.has(field_name):
		return null
	return combat_stats[field_name]


func to_dictionary() -> Dictionary:
	return {
		"actor_id": String(actor_id),
		"actor_kind": String(actor_kind),
		"display_name": display_name,
		"attributes": attributes.duplicate(true),
		"combat_stats": combat_stats.duplicate(true),
		"resource_maxima": resource_maxima.duplicate(true),
		"equipment_refs": Array(equipment_refs),
		"defensive_capabilities": defensive_capabilities.duplicate(true),
		"field_sources": field_sources.duplicate(true),
		"unresolved_fields": Array(unresolved_fields),
	}


func _build_unresolved_fields(explicit_fields: PackedStringArray) -> PackedStringArray:
	var unresolved: Array[String] = []
	for field_name: String in explicit_fields:
		if not unresolved.has(field_name):
			unresolved.append(field_name)
	for field_name: String in REQUIRED_CORE_ATTRIBUTES:
		var path := "attributes.%s" % field_name
		if not attributes.has(field_name) and not unresolved.has(path):
			unresolved.append(path)
	for field_name: String in REQUIRED_COMBAT_STATS:
		var path := "combat_stats.%s" % field_name
		if not combat_stats.has(field_name) and not unresolved.has(path):
			unresolved.append(path)
	unresolved.sort()
	return PackedStringArray(unresolved)


func _validate_known_values() -> void:
	for field_name: Variant in attributes:
		assert(typeof(attributes[field_name]) == TYPE_INT, "Known Prime attributes must be stored as integers.")
	for field_name: Variant in combat_stats:
		assert(typeof(combat_stats[field_name]) == TYPE_INT, "Known combat statistics must be stored as integers.")
	for field_name: Variant in resource_maxima:
		assert(typeof(resource_maxima[field_name]) == TYPE_INT, "Known resource maxima must be stored as integers.")
		assert(resource_maxima[field_name] >= 0, "Resource maxima cannot be negative.")
	if combat_stats.has("hpm"):
		assert(combat_stats["hpm"] >= 0, "HPM cannot be negative.")
	if combat_stats.has("at"):
		assert(combat_stats["at"] > 0, "A resolved AT must be positive.")
