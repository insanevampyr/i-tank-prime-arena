class_name CombatActorDefinition
extends RefCounted

const AttributeRules = preload("res://scripts/combat/prime_v3_attribute_engine.gd")

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
# Derived only by replaying verified purchases; not a new save/snapshot field.
var wisdom_mana_purchase_increase: int = 0
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
# Authored input for source-qualified checks. Actor snapshots keep their existing shape.
var source_character_definition: CombatCharacterDefinitionResource
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
	var stored: Variant = combat_stats[field_name]
	if field_name == "ss" and typeof(stored) == TYPE_INT:
		# Definition attributes are permanent; never inspect temporary actor effects.
		var wisdom: Variant = attributes.get("wis")
		var source: Variant = field_sources.get("attributes.wis", field_sources.get("attributes"))
		if typeof(wisdom) == TYPE_INT and wisdom >= 0 and wisdom <= 35 \
		and source is String and not source.is_empty() \
		and not unresolved_fields.has("attributes.wis") and not unresolved_fields.has("attributes"):
			# SS agrees in both printed modes. This reference mode grants no class,
			# resource or ability permission; authored differences retain stored SS.
			var reference := AttributeRules.lookup("WIS", wisdom, "mana")
			var ss: Dictionary = reference.get("values", {}).get("SS", {})
			if reference.get("success", false) and ss.get("kind") == "integer" \
			and typeof(ss.get("value")) == TYPE_INT and ss.value == stored:
				return ss.value
	return stored


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


func apply_verified_strength_advancement(expected_current_value: int, target_value: int, validate_equipment: bool = true) -> Dictionary:
	if typeof(attributes.get("str")) != TYPE_INT: return {"success":false,"reason":"source_strength_unresolved"}
	if attributes.str != expected_current_value: return {"success":false,"reason":"stale_advancement_value"}
	if target_value != expected_current_value+1: return {"success":false,"reason":"advancement_must_increase_one_point"}
	var before := PrimeV3StrengthChart.derived(expected_current_value)
	var after := PrimeV3StrengthChart.derived(target_value)
	if not before.success or not after.success: return {"success":false,"reason":"strength_chart_or_mortal_limit_unverified"}
	for field: String in ["sb","ppg","mwc"]:
		if (field == "sb" or base_combat_stats.has(field)) and base_combat_stats.get(field) != before[field]: return {"success":false,"reason":"strength_derived_source_mismatch"}
	if validate_equipment:
		var catalog := CombatDefinitionCatalog.load_default_fixture_catalog()
		var equipment := catalog.validate_equipment_strength(target_value,equipment_refs)
		if not equipment.success: return {"success":false,"reason":"advancement_equipment_unverified","issues":equipment.issues}
	# Commit only after all values/equipment have been checked. No actor state,
	# hand assignment, temporary effect or resource is modified here.
	attributes.str = target_value
	for field: String in ["sb","ppg","mwc"]: base_combat_stats[field] = after[field]
	apply_equipment_stat_modifiers(equipment_stat_modifiers)
	return {"success":true,"value_before":expected_current_value,"value_after":target_value,"derived_before":before,"derived_after":after}


func apply_verified_dexterity_advancement(expected: int, target: int, allocation: String) -> Dictionary:
	if typeof(attributes.get("dex")) != TYPE_INT or attributes.dex != expected: return {"success":false,"reason":"stale_advancement_value"}
	if expected < 1 or target != expected+1 or target > 20 or allocation not in ["dt","dp"]: return {"success":false,"reason":"invalid_dex_advancement"}
	var mode := "mana" if progression_policy.get("resource_mode") == "mana" else "regular"
	if base_combat_stats.get("acc") != PrimeV3DexChart.accuracy(expected,mode): return {"success":false,"reason":"dex_derived_source_mismatch"}
	for key: String in ["dt","dp"]:
		if typeof(base_combat_stats.get(key)) != TYPE_INT: return {"success":false,"reason":"dex_allocation_unavailable"}
	attributes.dex = target
	base_combat_stats.acc = PrimeV3DexChart.accuracy(target,mode)
	base_combat_stats[allocation] += 1
	apply_equipment_stat_modifiers(equipment_stat_modifiers)
	return {"success":true,"derived_after":{"acc":base_combat_stats.acc,"dt":base_combat_stats.dt,"dp":base_combat_stats.dp}}


func preview_verified_speed_advancement(expected: int, target: int) -> Dictionary:
	if typeof(attributes.get("spd")) != TYPE_INT or attributes.spd != expected:
		return {"success":false,"reason":"stale_advancement_value"}
	if expected < 1 or target != expected + 1 or target > 20:
		return {"success":false,"reason":"speed_mortal_purchase_limit"}
	var mode: Variant = progression_policy.get("resource_mode", "")
	if typeof(mode) != TYPE_STRING or mode not in ["mana", "regular"]:
		return {"success":false,"reason":"speed_chart_mode_unavailable"}
	var before := AttributeRules.lookup("SPD", expected, mode)
	var after := AttributeRules.lookup("SPD", target, mode)
	if not before.success or not after.success:
		return {"success":false,"reason":"speed_chart_mode_unavailable"}
	var old_values := {"mr":before.values.MR.value,"at":before.values.AT.value}
	var new_values := {"mr":after.values.MR.value,"at":after.values.AT.value}
	for field: String in ["mr", "at"]:
		if typeof(base_combat_stats.get(field)) != TYPE_INT or base_combat_stats[field] != old_values[field]:
			return {"success":false,"reason":"speed_derived_source_mismatch"}
	return {"success":true,"derived_before":old_values,"derived_after":new_values}


func apply_verified_speed_advancement(expected: int, target: int) -> Dictionary:
	var checked := preview_verified_speed_advancement(expected, target)
	if not checked.success: return checked
	# All source checks precede mutation. Equipment remains a separate layer.
	attributes.spd = target
	for field: String in ["mr", "at"]: base_combat_stats[field] = checked.derived_after[field]
	apply_equipment_stat_modifiers(equipment_stat_modifiers)
	return checked


func preview_verified_wisdom_advancement(expected: int, target: int) -> Dictionary:
	if typeof(attributes.get("wis")) != TYPE_INT or attributes.wis != expected:
		return {"success":false,"reason":"stale_advancement_value"}
	if expected < 1 or target != expected + 1 or target > 20:
		return {"success":false,"reason":"wisdom_mortal_purchase_limit"}
	var mode: Variant = progression_policy.get("resource_mode")
	if mode not in ["mana", "ability"]:
		return {"success":false,"reason":"wisdom_chart_mode_unavailable"}
	var source: Variant = field_sources.get("attributes.wis",field_sources.get("attributes"))
	if not source is String or source.is_empty() or unresolved_fields.has("attributes.wis") or unresolved_fields.has("attributes"):
		return {"success":false,"reason":"wisdom_source_unavailable"}
	var before := AttributeRules.lookup("WIS",expected,"mana" if mode == "mana" else "regular")
	var after := AttributeRules.lookup("WIS",target,"mana" if mode == "mana" else "regular")
	if typeof(base_combat_stats.get("ss")) != TYPE_INT or base_combat_stats.ss != before.values.SS.value:
		return {"success":false,"reason":"wisdom_derived_source_mismatch"}
	# Other chart references remain references, never newly activated mechanics.
	for field: String in ["msl","mana_recovery_per_hour"]:
		if base_combat_stats.has(field): return {"success":false,"reason":"wisdom_authored_derived_exception_unsupported"}
	if mode == "mana" and (typeof(resource_maxima.get("mana")) != TYPE_INT or resource_maxima.mana < 0):
		return {"success":false,"reason":"wisdom_mana_source_unavailable"}
	return {"success":true,"derived_before":{"ss":before.values.SS.value},"derived_after":{"ss":after.values.SS.value},
		"mana_max_before":resource_maxima.get("mana"),"mana_max_increase":1 if mode == "mana" else 0,
		"mana_max_after":int(resource_maxima.mana)+1 if mode == "mana" else null}


func apply_verified_wisdom_advancement(expected: int, target: int) -> Dictionary:
	var checked := preview_verified_wisdom_advancement(expected,target)
	if not checked.success: return checked
	attributes.wis = target
	base_combat_stats.ss = checked.derived_after.ss
	if checked.mana_max_increase == 1:
		resource_maxima.mana = checked.mana_max_after
		wisdom_mana_purchase_increase += 1
	apply_equipment_stat_modifiers(equipment_stat_modifiers)
	return checked


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
