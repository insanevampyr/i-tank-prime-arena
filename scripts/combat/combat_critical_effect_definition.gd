class_name CombatCriticalEffectDefinition
extends RefCounted

const TYPE_IMMEDIATE_REACTION := &"immediate_reaction"
const TYPE_BACKFIRE_THREAT := &"backfire_threat"
const TYPE_CRITICAL_STAGGER := &"critical_stagger"
const TYPE_DAMAGE_MULTIPLIER := &"damage_multiplier"
const TYPE_PRONE := &"prone"
const TYPE_PERFECT_EVASION := &"perfect_evasion"
const TYPE_SAME_ATTACK_PROTECTION := &"same_attack_protection"
const CRITICAL_STAGGER_DURATION_US := 500_000

var effect_id: StringName
var effect_type: StringName
var weapon_ref: StringName
var prerequisites: Dictionary
var ordinary_act_cost: int
var counts_as_nac: bool
var allows_legal_defensive_reactions: bool
var duration_us: int
var interrupts_executing_actions: bool
var stops_voluntary_movement: bool
var prevents_ordinary_action_start: bool
var source_refs: PackedStringArray


func _init(
	p_effect_id: StringName,
	p_effect_type: StringName,
	p_weapon_ref: StringName = &"",
	p_prerequisites: Dictionary = {},
	p_source_refs: PackedStringArray = PackedStringArray()
) -> void:
	assert(not String(p_effect_id).is_empty(), "Critical effect definitions require a stable identifier.")
	assert(
		p_effect_type == TYPE_IMMEDIATE_REACTION
		or p_effect_type == TYPE_BACKFIRE_THREAT
		or p_effect_type == TYPE_CRITICAL_STAGGER
		or p_effect_type == TYPE_DAMAGE_MULTIPLIER
		or p_effect_type == TYPE_PRONE
		or p_effect_type == TYPE_PERFECT_EVASION
		or p_effect_type == TYPE_SAME_ATTACK_PROTECTION,
		"Unsupported critical effect type."
	)
	effect_id = p_effect_id
	effect_type = p_effect_type
	weapon_ref = p_weapon_ref
	prerequisites = p_prerequisites.duplicate(true)
	source_refs = p_source_refs.duplicate()
	ordinary_act_cost = 0
	counts_as_nac = false
	allows_legal_defensive_reactions = p_effect_type == TYPE_IMMEDIATE_REACTION or p_effect_type == TYPE_BACKFIRE_THREAT
	duration_us = CRITICAL_STAGGER_DURATION_US if p_effect_type == TYPE_CRITICAL_STAGGER else 0
	interrupts_executing_actions = p_effect_type == TYPE_CRITICAL_STAGGER
	stops_voluntary_movement = p_effect_type == TYPE_CRITICAL_STAGGER
	prevents_ordinary_action_start = p_effect_type == TYPE_CRITICAL_STAGGER


func to_dictionary() -> Dictionary:
	return {
		"effect_id": String(effect_id),
		"effect_type": String(effect_type),
		"weapon_ref": String(weapon_ref),
		"prerequisites": prerequisites.duplicate(true),
		"ordinary_act_cost": ordinary_act_cost,
		"counts_as_nac": counts_as_nac,
		"allows_legal_defensive_reactions": allows_legal_defensive_reactions,
		"duration_us": duration_us,
		"interrupts_executing_actions": interrupts_executing_actions,
		"stops_voluntary_movement": stops_voluntary_movement,
		"prevents_ordinary_action_start": prevents_ordinary_action_start,
		"implementation_status": "data_driven_runtime_effect",
		"source_refs": Array(source_refs),
	}
