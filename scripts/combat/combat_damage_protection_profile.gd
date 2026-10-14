class_name CombatDamageProtectionProfile
extends RefCounted

const RESPONSE_IMMUNE := "immune"
const RESPONSE_MULTIPLIER := "multiplier"
const STAGE_PRE_PROTECTION := "pre_protection"
const STAGE_POST_PROTECTION := "post_protection"

var profile_id: StringName
var armors: Array[CombatArmorDefinition]
var exact_type_responses: Dictionary
var source_refs: PackedStringArray


func _init(
	p_profile_id: StringName,
	p_armors: Array[CombatArmorDefinition] = [],
	p_exact_type_responses: Dictionary = {},
	p_source_refs: PackedStringArray = PackedStringArray()
) -> void:
	assert(not String(p_profile_id).is_empty(), "Damage protection profiles require a stable identifier.")
	for response_key: Variant in p_exact_type_responses:
		_validate_response(p_exact_type_responses[response_key])
	profile_id = p_profile_id
	armors = p_armors.duplicate()
	exact_type_responses = p_exact_type_responses.duplicate(true)
	source_refs = p_source_refs.duplicate()


func get_exact_type_response(damage_types: PackedStringArray) -> Variant:
	var ordered := damage_types.duplicate()
	ordered.sort()
	return exact_type_responses.get("+".join(ordered), null)


func to_dictionary() -> Dictionary:
	var serialized_armors: Array = []
	for armor: CombatArmorDefinition in armors:
		serialized_armors.append(armor.to_dictionary())
	return {
		"profile_id": String(profile_id),
		"armors": serialized_armors,
		"exact_type_responses": exact_type_responses.duplicate(true),
		"source_refs": Array(source_refs),
	}


func _validate_response(value: Variant) -> void:
	assert(typeof(value) == TYPE_DICTIONARY, "Damage type responses must be dictionaries.")
	var response: Dictionary = value
	var kind := String(response.get("kind", ""))
	assert(kind == RESPONSE_IMMUNE or kind == RESPONSE_MULTIPLIER, "Damage type response kind must be immune or multiplier.")
	if kind == RESPONSE_IMMUNE:
		return
	assert(typeof(response.get("numerator")) == TYPE_INT and int(response["numerator"]) >= 0, "Weakness multiplier numerator must be a non-negative integer.")
	assert(typeof(response.get("denominator")) == TYPE_INT and int(response["denominator"]) > 0, "Weakness multiplier denominator must be positive.")
	var stage := String(response.get("stage", ""))
	assert(stage == STAGE_PRE_PROTECTION or stage == STAGE_POST_PROTECTION, "Weakness multiplier requires an explicit source-driven resolution stage.")
