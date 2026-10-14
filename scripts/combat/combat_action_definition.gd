class_name CombatActionDefinition
extends RefCounted

var action_definition_id: StringName
var required_acts: int
var allows_movement: bool
var interruptible: bool
var resource_commitments: Dictionary
var extension_metadata: Dictionary
var source_refs: PackedStringArray


func _init(
	p_action_definition_id: StringName,
	p_required_acts: int,
	p_allows_movement: bool = true,
	p_interruptible: bool = true,
	p_resource_commitments: Dictionary = {},
	p_extension_metadata: Dictionary = {},
	p_source_refs: PackedStringArray = PackedStringArray()
) -> void:
	assert(not String(p_action_definition_id).is_empty(), "Action definitions require a stable identifier.")
	assert(p_required_acts > 0, "Actions must require at least one Act.")
	action_definition_id = p_action_definition_id
	required_acts = p_required_acts
	allows_movement = p_allows_movement
	interruptible = p_interruptible
	resource_commitments = p_resource_commitments.duplicate(true)
	extension_metadata = p_extension_metadata.duplicate(true)
	source_refs = p_source_refs.duplicate()


func to_dictionary() -> Dictionary:
	return {
		"action_definition_id": String(action_definition_id),
		"required_acts": required_acts,
		"allows_movement": allows_movement,
		"interruptible": interruptible,
		"resource_commitments": resource_commitments.duplicate(true),
		"extension_metadata": extension_metadata.duplicate(true),
		"source_refs": Array(source_refs),
	}
