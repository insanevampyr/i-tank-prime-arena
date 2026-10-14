class_name CombatActorState
extends RefCounted

var actor_id: StringName
var current_hpc: Variant = null
var resources: Dictionary = {}
var equipment_refs: PackedStringArray = PackedStringArray()
var conditions: PackedStringArray = PackedStringArray()
var awareness: StringName = &"aware"
var position_microfeet: Vector2i = Vector2i.ZERO
var facing_millidegrees: int = 0
var movement_round_index: int = 0
var remaining_mr_microfeet: Variant = null
var opening_initiative_roll: Variant = null
var opening_initiative_rng_draw_index: Variant = null
var opening_initiative_total: Variant = null
var opening_order_rank: Variant = null
var opening_action_declared: bool = false
var current_action_instance_id: String = ""
var action_timing_anchor_us: int = 0
var action_timing_cursor_us: int = 0
var next_action_interval_index: int = 0
var revision: int = 0


func _init(definition: CombatActorDefinition) -> void:
	assert(definition != null, "Actor state requires a definition.")
	actor_id = definition.actor_id
	current_hpc = definition.get_combat_stat("hpm")
	for resource_name: Variant in definition.resource_maxima:
		resources[resource_name] = definition.resource_maxima[resource_name]
	equipment_refs = definition.equipment_refs.duplicate()
	var mr_value: Variant = definition.get_combat_stat("mr")
	if mr_value != null:
		remaining_mr_microfeet = int(mr_value) * 1_000_000


func to_dictionary() -> Dictionary:
	return {
		"actor_id": String(actor_id),
		"current_hpc": current_hpc,
		"resources": resources.duplicate(true),
		"equipment_refs": Array(equipment_refs),
		"conditions": Array(conditions),
		"awareness": String(awareness),
		"position_microfeet": [position_microfeet.x, position_microfeet.y],
		"facing_millidegrees": facing_millidegrees,
		"movement_round_index": movement_round_index,
		"remaining_mr_microfeet": remaining_mr_microfeet,
		"opening_initiative_roll": opening_initiative_roll,
		"opening_initiative_rng_draw_index": opening_initiative_rng_draw_index,
		"opening_initiative_total": opening_initiative_total,
		"opening_order_rank": opening_order_rank,
		"opening_action_declared": opening_action_declared,
		"current_action_instance_id": current_action_instance_id,
		"action_timing_anchor_us": action_timing_anchor_us,
		"action_timing_cursor_us": action_timing_cursor_us,
		"next_action_interval_index": next_action_interval_index,
		"revision": revision,
	}


func set_position(value: Vector2i, facing: int) -> void:
	position_microfeet = value
	facing_millidegrees = facing
	revision += 1


func refresh_movement_budget(definition: CombatActorDefinition, round_index: int) -> void:
	if movement_round_index == round_index:
		return
	movement_round_index = round_index
	var mr_value: Variant = definition.get_combat_stat("mr")
	remaining_mr_microfeet = null if mr_value == null else int(mr_value) * 1_000_000
	revision += 1


func spend_movement(amount_microfeet: int) -> bool:
	assert(amount_microfeet >= 0, "Movement spending cannot be negative.")
	if remaining_mr_microfeet == null or amount_microfeet > int(remaining_mr_microfeet):
		return false
	remaining_mr_microfeet = int(remaining_mr_microfeet) - amount_microfeet
	revision += 1
	return true
