class_name CombatActorState
extends RefCounted

var actor_id: StringName
var current_hpc: Variant = null
var resources: Dictionary = {}
var ability_daily_maxima: Dictionary = {}
var ability_daily_remaining: Dictionary = {}
var inventory_quantities: Dictionary = {}
var timed_stat_effects: Dictionary = {}
var pending_called_shot: Dictionary = {}
var hand_occupancy: Dictionary = {"left": "", "right": ""}
var hand_occupancy_authoritative: bool = false
# Sparse handling overrides; absent entries retain legacy equipped/held behavior.
var weapon_handling: Dictionary = {}
var progression: Dictionary = {}
var held_materials: Dictionary = {}
var equipment_refs: PackedStringArray = PackedStringArray()
var conditions: PackedStringArray = PackedStringArray()
var awareness: StringName = &"aware"
var position_microfeet: Vector2i = Vector2i.ZERO
var elevation_microfeet: int = 0
var facing_millidegrees: int = 0
var movement_round_index: int = 0
var remaining_mr_microfeet: Variant = null
var opening_initiative_roll: Variant = null
var opening_initiative_rng_draw_index: Variant = null
var opening_initiative_total: Variant = null
var opening_order_rank: Variant = null
var opening_action_declared: bool = false
var current_action_instance_id: String = ""
var critical_stagger_until_us: int = 0
var action_timing_anchor_us: int = 0
var action_timing_cursor_us: int = 0
var next_action_interval_index: int = 0
var nac_round_index: int = -1
var nac_uses_this_round: int = 0
var automatic_nac_uses_this_round: int = 0
var persistent_damage_shields: Dictionary = {}
var nac_automation_settings: Dictionary = {}
var revision: int = 0


func _init(definition: CombatActorDefinition) -> void:
	assert(definition != null, "Actor state requires a definition.")
	actor_id = definition.actor_id
	current_hpc = definition.get_combat_stat("hpm")
	for resource_name: Variant in definition.resource_maxima:
		resources[resource_name] = definition.resource_maxima[resource_name]
	for ability_id: Variant in definition.ability_allowances:
		var maximum: Variant = definition.get_ability_daily_maximum(StringName(String(ability_id)))
		if maximum != null:
			ability_daily_maxima[String(ability_id)] = int(maximum)
			ability_daily_remaining[String(ability_id)] = int(maximum)
	for inventory_id: Variant in definition.inventory_records:
		var record: Dictionary = definition.inventory_records[inventory_id]
		inventory_quantities[String(inventory_id)] = int(record.get("quantity", 0))
	equipment_refs = definition.equipment_refs.duplicate()
	var mr_value: Variant = definition.get_combat_stat("mr")
	if mr_value != null:
		remaining_mr_microfeet = int(mr_value) * 1_000_000


func to_dictionary() -> Dictionary:
	var snapshot := {
		"actor_id": String(actor_id),
		"current_hpc": current_hpc,
		"resources": resources.duplicate(true),
		"ability_daily_maxima": ability_daily_maxima.duplicate(true),
		"ability_daily_remaining": ability_daily_remaining.duplicate(true),
		"inventory_quantities": inventory_quantities.duplicate(true),
		"timed_stat_effects": timed_stat_effects.duplicate(true),
		"pending_called_shot": pending_called_shot.duplicate(true),
		"hand_occupancy": hand_occupancy.duplicate(true),
		"hand_occupancy_authoritative": hand_occupancy_authoritative,
		"held_materials": held_materials.duplicate(true),
		"equipment_refs": Array(equipment_refs),
		"conditions": Array(conditions),
		"awareness": String(awareness),
		"position_microfeet": [position_microfeet.x, position_microfeet.y],
		"elevation_microfeet": elevation_microfeet,
		"is_airborne": elevation_microfeet > 0,
		"facing_millidegrees": facing_millidegrees,
		"movement_round_index": movement_round_index,
		"remaining_mr_microfeet": remaining_mr_microfeet,
		"opening_initiative_roll": opening_initiative_roll,
		"opening_initiative_rng_draw_index": opening_initiative_rng_draw_index,
		"opening_initiative_total": opening_initiative_total,
		"opening_order_rank": opening_order_rank,
		"opening_action_declared": opening_action_declared,
		"current_action_instance_id": current_action_instance_id,
		"critical_stagger_until_us": critical_stagger_until_us,
		"action_timing_anchor_us": action_timing_anchor_us,
		"action_timing_cursor_us": action_timing_cursor_us,
		"next_action_interval_index": next_action_interval_index,
		"nac_round_index": nac_round_index,
		"nac_uses_this_round": nac_uses_this_round,
		"automatic_nac_uses_this_round": automatic_nac_uses_this_round,
		"persistent_damage_shields": persistent_damage_shields.duplicate(true),
		"nac_automation_settings": nac_automation_settings.duplicate(true),
		"revision": revision,
	}
	# Additive schema-12 extension; unchanged legacy fixtures retain exact snapshots.
	if not weapon_handling.is_empty(): snapshot["weapon_handling"] = weapon_handling.duplicate(true)
	if not progression.is_empty(): snapshot["progression"] = progression.duplicate(true)
	return snapshot


func set_position(value: Vector2i, facing: int) -> void:
	position_microfeet = value
	facing_millidegrees = facing
	revision += 1


func set_spatial_position(value: Vector2i, elevation: int, facing: int) -> void:
	assert(elevation >= 0, "Authoritative elevation cannot be negative.")
	position_microfeet = value
	elevation_microfeet = elevation
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
