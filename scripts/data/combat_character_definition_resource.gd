class_name CombatCharacterDefinitionResource
extends Resource

@export var definition_id: StringName
@export var display_name: String
@export var actor_kind: StringName = &"prime_v3_verified_fixture"
@export var race_name: String = ""
@export var class_names: PackedStringArray = PackedStringArray()
@export var level: int = -1
@export var attributes: Dictionary = {}
@export var combat_stats: Dictionary = {}
@export var resource_maxima: Dictionary = {}
@export var defensive_capabilities: Dictionary = {}
@export var running_profile: Dictionary = {}
@export var source_refs: PackedStringArray = PackedStringArray()
@export var field_sources: Dictionary = {}
@export var unresolved_fields: PackedStringArray = PackedStringArray()


func validate_definition() -> Array[Dictionary]:
	var issues: Array[Dictionary] = []
	if String(definition_id).is_empty():
		issues.append(_issue("invalid", "missing_character_identifier"))
	if display_name.strip_edges().is_empty():
		issues.append(_issue("invalid", "missing_character_display_name"))
	if String(actor_kind).is_empty():
		issues.append(_issue("invalid", "missing_actor_kind"))
	for field_name: String in CombatActorDefinition.REQUIRED_CORE_ATTRIBUTES:
		_validate_integer_field(issues, attributes, field_name, "attributes", false)
	for field_name: String in CombatActorDefinition.REQUIRED_COMBAT_STATS:
		_validate_integer_field(issues, combat_stats, field_name, "combat_stats", false)
	for field_name: Variant in resource_maxima:
		if typeof(resource_maxima[field_name]) != TYPE_INT or int(resource_maxima[field_name]) < 0:
			issues.append(_issue("invalid", "malformed_resource_maximum", {"field": String(field_name)}))
	for field_name: String in ["running_skill_investment", "skill_check_modifier", "roll_bonus"]:
		_validate_integer_field(issues, running_profile, field_name, "running_profile", true)
	if source_refs.is_empty():
		issues.append(_issue("requires_source_verification", "character_source_missing"))
	for unresolved: String in unresolved_fields:
		issues.append(_issue("requires_source_verification", "unresolved_character_field", {"field": unresolved}))
	return issues


func instantiate_actor(actor_id: StringName, instance_display_name: String, equipment_refs: PackedStringArray) -> Variant:
	for issue: Dictionary in validate_definition():
		if issue["status"] == "invalid":
			return null
	return CombatActorDefinition.new(
		actor_id,
		actor_kind,
		instance_display_name,
		attributes,
		combat_stats,
		resource_maxima,
		equipment_refs,
		defensive_capabilities,
		field_sources,
		unresolved_fields
	)


func to_dictionary() -> Dictionary:
	return {
		"definition_id": String(definition_id),
		"display_name": display_name,
		"actor_kind": String(actor_kind),
		"race_name": race_name,
		"class_names": Array(class_names),
		"level": level,
		"attributes": attributes.duplicate(true),
		"combat_stats": combat_stats.duplicate(true),
		"resource_maxima": resource_maxima.duplicate(true),
		"defensive_capabilities": defensive_capabilities.duplicate(true),
		"running_profile": running_profile.duplicate(true),
		"source_refs": Array(source_refs),
		"field_sources": field_sources.duplicate(true),
		"unresolved_fields": Array(unresolved_fields),
	}


func _validate_integer_field(issues: Array[Dictionary], values: Dictionary, field_name: String, group: String, allow_negative: bool) -> void:
	if not values.has(field_name):
		issues.append(_issue("invalid", "missing_required_numeric_field", {"field": "%s.%s" % [group, field_name]}))
		return
	if typeof(values[field_name]) != TYPE_INT or (not allow_negative and int(values[field_name]) < 0):
		issues.append(_issue("invalid", "malformed_numeric_field", {"field": "%s.%s" % [group, field_name]}))


func _issue(status: String, code: String, details: Dictionary = {}) -> Dictionary:
	return {"status": status, "code": code, "details": details.duplicate(true)}
