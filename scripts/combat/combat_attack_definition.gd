class_name CombatAttackDefinition
extends RefCounted

const DUCKING_ALLOWED := &"allowed"
const DUCKING_PROHIBITED := &"prohibited"
const DUCKING_UNRESOLVED := &"unresolved"

var attack_definition_id: StringName
var weapon_ref: StringName
var required_acts: int
var allows_movement: bool
var interruptible: bool
var base_acc_modifier: int
var acc_modifiers_by_location: Dictionary
var allowed_target_locations: PackedStringArray
var minimum_range_microfeet: Variant
var maximum_range_microfeet: Variant
var requires_line_of_sight: bool
var source_refs: PackedStringArray
var delivery_class: StringName
var damage_types: PackedStringArray
var physical_soak_eligible: Variant
var ducking_policy: StringName
var physical_damage: CombatPhysicalDamageDefinition
var critical_trigger_policy: CombatCriticalTriggerPolicy
var allows_approach_during_execution: bool
var uses_size_based_location_acc: bool


func _init(
	p_attack_definition_id: StringName,
	p_weapon_ref: StringName,
	p_required_acts: int = 1,
	p_allows_movement: bool = true,
	p_interruptible: bool = true,
	p_base_acc_modifier: int = 0,
	p_acc_modifiers_by_location: Dictionary = {"torso": 0},
	p_allowed_target_locations: PackedStringArray = PackedStringArray(["torso"]),
	p_minimum_range_microfeet: Variant = null,
	p_maximum_range_microfeet: Variant = null,
	p_requires_line_of_sight: bool = true,
	p_source_refs: PackedStringArray = PackedStringArray(),
	p_delivery_class: StringName = &"",
	p_damage_types: PackedStringArray = PackedStringArray(),
	p_physical_soak_eligible: Variant = null,
	p_ducking_policy: StringName = DUCKING_UNRESOLVED,
	p_physical_damage: CombatPhysicalDamageDefinition = null,
	p_critical_trigger_policy: CombatCriticalTriggerPolicy = null,
	p_allows_approach_during_execution: bool = false,
	p_uses_size_based_location_acc: bool = false
) -> void:
	assert(not String(p_attack_definition_id).is_empty(), "Physical attack definitions require a stable identifier.")
	assert(not String(p_weapon_ref).is_empty(), "Physical attack definitions require an equipment reference.")
	assert(p_required_acts > 0, "Physical attacks must require at least one Act interval.")
	assert(p_allowed_target_locations.has("torso"), "Ordinary physical attacks must support the default torso location.")
	for location: Variant in p_acc_modifiers_by_location:
		assert(typeof(p_acc_modifiers_by_location[location]) == TYPE_INT, "ACC modifiers must be integers.")
	if p_minimum_range_microfeet != null:
		assert(typeof(p_minimum_range_microfeet) == TYPE_INT and p_minimum_range_microfeet >= 0, "Minimum range must be a non-negative integer distance.")
	if p_maximum_range_microfeet != null:
		assert(typeof(p_maximum_range_microfeet) == TYPE_INT and p_maximum_range_microfeet >= 0, "Maximum range must be a non-negative integer distance.")
	if p_minimum_range_microfeet != null and p_maximum_range_microfeet != null:
		assert(p_minimum_range_microfeet <= p_maximum_range_microfeet, "Minimum range cannot exceed maximum range.")
	assert(
		String(p_delivery_class).is_empty() or p_delivery_class == &"hand_held" or p_delivery_class == &"thrown",
		"Phase 1 physical delivery must be hand-held, thrown, or explicitly unresolved."
	)
	if p_physical_soak_eligible != null:
		assert(typeof(p_physical_soak_eligible) == TYPE_BOOL, "Physical Soak eligibility must be boolean or unresolved.")
	assert(
		p_ducking_policy == DUCKING_ALLOWED
		or p_ducking_policy == DUCKING_PROHIBITED
		or p_ducking_policy == DUCKING_UNRESOLVED,
		"Ducking policy must be allowed, prohibited, or unresolved."
	)
	attack_definition_id = p_attack_definition_id
	weapon_ref = p_weapon_ref
	required_acts = p_required_acts
	allows_movement = p_allows_movement
	interruptible = p_interruptible
	base_acc_modifier = p_base_acc_modifier
	acc_modifiers_by_location = p_acc_modifiers_by_location.duplicate(true)
	allowed_target_locations = p_allowed_target_locations.duplicate()
	minimum_range_microfeet = p_minimum_range_microfeet
	maximum_range_microfeet = p_maximum_range_microfeet
	requires_line_of_sight = p_requires_line_of_sight
	source_refs = p_source_refs.duplicate()
	delivery_class = p_delivery_class
	damage_types = p_damage_types.duplicate()
	physical_soak_eligible = p_physical_soak_eligible
	ducking_policy = p_ducking_policy
	physical_damage = p_physical_damage
	critical_trigger_policy = p_critical_trigger_policy
	allows_approach_during_execution = p_allows_approach_during_execution
	uses_size_based_location_acc = p_uses_size_based_location_acc
	if critical_trigger_policy == null:
		critical_trigger_policy = CombatCriticalTriggerPolicy.new()


func has_resolved_range() -> bool:
	return maximum_range_microfeet != null


func get_location_acc_modifier(target_location: StringName) -> Variant:
	var location_key := String(target_location)
	if not acc_modifiers_by_location.has(location_key):
		return null
	return acc_modifiers_by_location[location_key]


func to_action_definition() -> CombatActionDefinition:
	return CombatActionDefinition.new(
		StringName("physical_attack:%s" % String(attack_definition_id)),
		required_acts,
		allows_movement,
		interruptible,
		{},
		{
			"kind": "physical_attack",
			"attack_definition_id": String(attack_definition_id),
			"future_defensive_resolution": true,
		},
		source_refs
	)


func to_dictionary() -> Dictionary:
	return {
		"attack_definition_id": String(attack_definition_id),
		"weapon_ref": String(weapon_ref),
		"required_acts": required_acts,
		"allows_movement": allows_movement,
		"interruptible": interruptible,
		"base_acc_modifier": base_acc_modifier,
		"acc_modifiers_by_location": acc_modifiers_by_location.duplicate(true),
		"allowed_target_locations": Array(allowed_target_locations),
		"minimum_range_microfeet": minimum_range_microfeet,
		"maximum_range_microfeet": maximum_range_microfeet,
		"requires_line_of_sight": requires_line_of_sight,
		"source_refs": Array(source_refs),
		"delivery_class": String(delivery_class),
		"damage_types": Array(damage_types),
		"physical_soak_eligible": physical_soak_eligible,
		"ducking_policy": String(ducking_policy),
		"physical_damage": null if physical_damage == null else physical_damage.to_dictionary(),
		"critical_trigger_policy": critical_trigger_policy.to_dictionary(),
		"allows_approach_during_execution": allows_approach_during_execution,
		"uses_size_based_location_acc": uses_size_based_location_acc,
	}
