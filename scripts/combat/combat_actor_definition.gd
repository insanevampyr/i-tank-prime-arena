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
var size_category: StringName
var level: int
var progression_policy: Dictionary = {}
var class_names: PackedStringArray = PackedStringArray()
var progression_hpm_increase: int = 0
var attributes: Dictionary
var base_combat_stats: Dictionary
var combat_stats: Dictionary
var equipment_stat_modifiers: Dictionary
var resource_maxima: Dictionary
var ability_allowances: Dictionary
var inventory_records: Dictionary
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
	p_unresolved_fields: PackedStringArray = PackedStringArray(),
	p_size_category: StringName = &"",
	p_ability_allowances: Dictionary = {},
	p_inventory_records: Dictionary = {},
	p_level: int = -1
) -> void:
	assert(not String(p_actor_id).is_empty(), "Combat actors require a stable identifier.")
	assert(not String(p_actor_kind).is_empty(), "Combat actors require a stable kind.")
	actor_id = p_actor_id
	actor_kind = p_actor_kind
	display_name = p_display_name
	size_category = p_size_category
	level = p_level
	attributes = p_attributes.duplicate(true)
	base_combat_stats = p_combat_stats.duplicate(true)
	combat_stats = base_combat_stats.duplicate(true)
	if progression_hpm_increase != 0: combat_stats["hpm"] = int(combat_stats["hpm"]) + progression_hpm_increase
	equipment_stat_modifiers = {"mr": 0, "dt": 0, "dp": 0}
	resource_maxima = p_resource_maxima.duplicate(true)
	ability_allowances = p_ability_allowances.duplicate(true)
	inventory_records = p_inventory_records.duplicate(true)
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


func get_base_combat_stat(field_name: String) -> Variant:
	if not base_combat_stats.has(field_name):
		return null
	return base_combat_stats[field_name]


func apply_equipment_stat_modifiers(modifiers: Dictionary) -> void:
	for field_name: String in ["mr", "dt", "dp"]:
		var modifier_value: Variant = modifiers.get(field_name, 0)
		assert(typeof(modifier_value) == TYPE_INT, "Equipment stat modifiers must be integers.")
		equipment_stat_modifiers[field_name] = int(modifier_value)
	combat_stats = base_combat_stats.duplicate(true)
	for field_name: String in equipment_stat_modifiers:
		if combat_stats.has(field_name):
			combat_stats[field_name] = int(base_combat_stats[field_name]) + int(equipment_stat_modifiers[field_name])
	if progression_hpm_increase != 0: combat_stats["hpm"] = int(base_combat_stats["hpm"]) + progression_hpm_increase


func apply_verified_resistance_advancement(
	field_name: String,
	expected_current_value: int,
	target_value: int
) -> Dictionary:
	if not ["sr", "tb"].has(field_name):
		return {"success": false, "reason": "unsupported_advancement_field"}
	if not base_combat_stats.has(field_name) or typeof(base_combat_stats[field_name]) != TYPE_INT:
		return {"success": false, "reason": "source_current_value_unresolved"}
	var current_value := int(base_combat_stats[field_name])
	if current_value != expected_current_value:
		return {"success": false, "reason": "stale_advancement_value"}
	if target_value != current_value + 1:
		return {"success": false, "reason": "advancement_must_increase_one_point"}
	base_combat_stats[field_name] = target_value
	apply_equipment_stat_modifiers(equipment_stat_modifiers)
	return {
		"success": true,
		"field_name": field_name,
		"value_before": current_value,
		"value_after": target_value,
	}


func to_dictionary() -> Dictionary:
	var snapshot := {
		"actor_id": String(actor_id),
		"actor_kind": String(actor_kind),
		"display_name": display_name,
		"size_category": String(size_category),
		"level": level,
		"attributes": attributes.duplicate(true),
		"base_combat_stats": base_combat_stats.duplicate(true),
		"combat_stats": combat_stats.duplicate(true),
		"equipment_stat_modifiers": equipment_stat_modifiers.duplicate(true),
		"resource_maxima": resource_maxima.duplicate(true),
		"ability_allowances": ability_allowances.duplicate(true),
		"inventory_records": inventory_records.duplicate(true),
		"equipment_refs": Array(equipment_refs),
		"defensive_capabilities": defensive_capabilities.duplicate(true),
		"field_sources": field_sources.duplicate(true),
		"unresolved_fields": Array(unresolved_fields),
	}
	if not progression_policy.is_empty(): snapshot["progression_policy"] = progression_policy.duplicate(true)
	if not class_names.is_empty(): snapshot["class_names"] = Array(class_names)
	if progression_hpm_increase != 0: snapshot["progression_hpm_increase"] = progression_hpm_increase
	return snapshot


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
	for field_name: Variant in base_combat_stats:
		assert(typeof(base_combat_stats[field_name]) == TYPE_INT, "Known combat statistics must be stored as integers.")
	for field_name: Variant in resource_maxima:
		assert(typeof(resource_maxima[field_name]) == TYPE_INT, "Known resource maxima must be stored as integers.")
		assert(resource_maxima[field_name] >= 0, "Resource maxima cannot be negative.")
	for ability_id: Variant in ability_allowances:
		var allowance: Variant = ability_allowances[ability_id]
		assert(typeof(allowance) == TYPE_DICTIONARY, "Ability allowances must be dictionaries.")
		var profile: Dictionary = allowance
		assert(int(profile.get("base_daily_uses", 0)) > 0, "Ability base daily uses must be positive.")
		assert(int(profile.get("repurchase_count", 0)) >= 0, "Ability repurchase counts cannot be negative.")
		assert(int(profile.get("bonus_daily_uses", 0)) >= 0, "Ability bonus daily uses cannot be negative.")
	for inventory_id: Variant in inventory_records:
		var record: Variant = inventory_records[inventory_id]
		assert(typeof(record) == TYPE_DICTIONARY, "Inventory records must be dictionaries.")
		assert(int((record as Dictionary).get("quantity", 0)) > 0, "Inventory quantities must be positive.")
	if combat_stats.has("hpm"):
		assert(combat_stats["hpm"] >= 0, "HPM cannot be negative.")
	if combat_stats.has("at"):
		assert(combat_stats["at"] > 0, "A resolved AT must be positive.")


func get_ability_daily_maximum(ability_id: StringName) -> Variant:
	var key := String(ability_id)
	if not ability_allowances.has(key):
		return null
	var profile: Dictionary = ability_allowances[key]
	var base_daily_uses := int(profile.get("base_daily_uses", 0))
	var repurchase_count := int(profile.get("repurchase_count", 0))
	var bonus_daily_uses := int(profile.get("bonus_daily_uses", 0))
	return base_daily_uses * (repurchase_count + 1) + bonus_daily_uses
