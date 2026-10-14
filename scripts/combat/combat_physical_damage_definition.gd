class_name CombatPhysicalDamageDefinition
extends RefCounted

const ROUNDING_UNRESOLVED := &"unresolved"
const ROUNDING_FLOOR := &"floor"
const ROUNDING_CEIL := &"ceil"

var dice_count: int
var die_sides: int
var flat_bonus: int
var strength_bonus_eligible: Variant
var minimum_one_applies: Variant
var location_multipliers: Dictionary
var critical_multiplier: Variant
var multiplier_stacking_resolved: bool
var rounding_policy: StringName
var source_refs: PackedStringArray


func _init(
	p_dice_count: int,
	p_die_sides: int,
	p_flat_bonus: int = 0,
	p_strength_bonus_eligible: Variant = null,
	p_minimum_one_applies: Variant = null,
	p_location_multipliers: Dictionary = {"torso": {"numerator": 1, "denominator": 1}},
	p_critical_multiplier: Variant = null,
	p_multiplier_stacking_resolved: bool = false,
	p_rounding_policy: StringName = ROUNDING_UNRESOLVED,
	p_source_refs: PackedStringArray = PackedStringArray()
) -> void:
	assert(p_dice_count > 0, "Physical weapon damage requires at least one die.")
	assert(p_die_sides > 0, "Physical weapon damage dice require positive sides.")
	if p_strength_bonus_eligible != null:
		assert(typeof(p_strength_bonus_eligible) == TYPE_BOOL, "SB eligibility must be boolean or unresolved.")
	if p_minimum_one_applies != null:
		assert(typeof(p_minimum_one_applies) == TYPE_BOOL, "Minimum-one eligibility must be boolean or unresolved.")
	assert(
		p_rounding_policy == ROUNDING_UNRESOLVED
		or p_rounding_policy == ROUNDING_FLOOR
		or p_rounding_policy == ROUNDING_CEIL,
		"Unsupported damage multiplier rounding policy."
	)
	for location: Variant in p_location_multipliers:
		_validate_multiplier(p_location_multipliers[location])
	if p_critical_multiplier != null:
		_validate_multiplier(p_critical_multiplier)
	dice_count = p_dice_count
	die_sides = p_die_sides
	flat_bonus = p_flat_bonus
	strength_bonus_eligible = p_strength_bonus_eligible
	minimum_one_applies = p_minimum_one_applies
	location_multipliers = p_location_multipliers.duplicate(true)
	critical_multiplier = null if p_critical_multiplier == null else (p_critical_multiplier as Dictionary).duplicate(true)
	multiplier_stacking_resolved = p_multiplier_stacking_resolved
	rounding_policy = p_rounding_policy
	source_refs = p_source_refs.duplicate()


func get_location_multiplier(location: StringName) -> Variant:
	return location_multipliers.get(String(location), null)


func to_dictionary() -> Dictionary:
	return {
		"dice_count": dice_count,
		"die_sides": die_sides,
		"flat_bonus": flat_bonus,
		"strength_bonus_eligible": strength_bonus_eligible,
		"minimum_one_applies": minimum_one_applies,
		"location_multipliers": location_multipliers.duplicate(true),
		"critical_multiplier": null if critical_multiplier == null else (critical_multiplier as Dictionary).duplicate(true),
		"multiplier_stacking_resolved": multiplier_stacking_resolved,
		"rounding_policy": String(rounding_policy),
		"source_refs": Array(source_refs),
	}


func _validate_multiplier(value: Variant) -> void:
	assert(typeof(value) == TYPE_DICTIONARY, "Damage multipliers require numerator and denominator fields.")
	var multiplier: Dictionary = value
	assert(typeof(multiplier.get("numerator")) == TYPE_INT, "Damage multiplier numerator must be an integer.")
	assert(typeof(multiplier.get("denominator")) == TYPE_INT and int(multiplier["denominator"]) > 0, "Damage multiplier denominator must be positive.")
	assert(int(multiplier["numerator"]) >= 0, "Damage multiplier numerator cannot be negative.")
