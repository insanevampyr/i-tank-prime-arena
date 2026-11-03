class_name CharacterAttributeProjection
extends RefCounted

# Inspection only. The caller supplies effective values from the existing authority.
# Chart references never authorize recalculation, allocation, grants or corrections.
const Rules = preload("res://scripts/combat/prime_v3_attribute_engine.gd")
const FIELDS := {
	"SB":"sb", "PPG":"ppg", "MWC":"mwc", "NAL":"nal",
	"PS":"physical_soak", "HPB":"hpb", "MR":"mr", "AT":"at",
	"DT":"dt", "DP":"dp", "ACC":"acc", "SS":"ss", "MSL":"msl",
	"INIT":"init", "RB":"rb", "PAR":"par", "CHA":"cha",
}

static func project_actor(actor: CombatActorDefinition, state: CombatActorState, mode: String,
		effective: Dictionary = {}, authored_exceptions: Dictionary = {}) -> Dictionary:
	if actor == null: return _fail("missing_actor")
	return project(actor.to_dictionary(), mode, {} if state == null else state.to_dictionary(), effective, authored_exceptions)

static func project(actor: Dictionary, mode: String, state: Dictionary = {},
		effective: Dictionary = {}, authored_exceptions: Dictionary = {}) -> Dictionary:
	if not _plain(actor) or not _plain(state) or not _plain(effective) or not _plain(authored_exceptions): return _fail("unsupported_input_data")
	if mode not in ["mana", "regular"]: return _fail("explicit_chart_mode_required")
	if not actor.get("actor_id") is String or actor.actor_id.is_empty(): return _fail("missing_actor_identity")
	if not actor.get("attributes") is Dictionary: return _fail("missing_attributes")
	for field: String in ["base_combat_stats", "combat_stats", "equipment_stat_modifiers", "resource_maxima", "field_sources"]:
		if actor.has(field) and not actor[field] is Dictionary: return _fail("invalid_"+field)
	if not state.is_empty() and state.get("actor_id") != actor.actor_id: return _fail("state_actor_mismatch")
	for field: String in ["resources", "progression", "ability_daily_maxima", "ability_daily_remaining", "persistent_damage_shields"]:
		if state.has(field) and not state[field] is Dictionary: return _fail("invalid_state_"+field)
	for key: Variant in actor.attributes:
		if not key is String or not Rules.PRIMARY_NAMES.has(key.to_upper()) or key != key.to_lower(): return _fail("unsupported_primary_field")
	for key: Variant in effective:
		if not key is String or (not FIELDS.values().has(key) and key not in ["sr","tb"]) or typeof(effective[key]) != TYPE_INT: return _fail("invalid_effective_stat")
	for key: Variant in authored_exceptions:
		if not key is String or not FIELDS.has(key) or not authored_exceptions[key] is String or authored_exceptions[key].is_empty(): return _fail("invalid_authored_exception")
	var allocation := _allocation(actor,state)
	if not allocation.success: return allocation
	var result := {"success":true, "identity":{"actor_id":actor.actor_id,
		"actor_kind":actor.get("actor_kind"), "display_name":actor.get("display_name")},
		"mode":mode, "primaries":{}, "derived":{}, "resistances":{}, "resources":{},
		"differences":[], "unavailable":[], "complete":true,
		"source_provenance":actor.get("field_sources",{}).duplicate(true),
		"authoritative_values_changed":false, "grants_entitlements":false}
	for primary: String in Rules.PRIMARY_NAMES:
		var key := primary.to_lower()
		var present: bool = actor.attributes.has(key) and actor.attributes[key] != null
		var value: Variant = actor.attributes.get(key)
		if present and (typeof(value) != TYPE_INT or value < 0 or value > 35): return _fail("unsupported_primary_score:"+primary)
		var reference: Dictionary = Rules.lookup(primary,value,mode) if present else {}
		result.primaries[primary] = {"name":Rules.PRIMARY_NAMES[primary], "stored":_number(actor.attributes,key),
			"chart_reference":reference, "origin":"stored_permanent", "effective":_missing("not_supplied")}
		if not present: result.unavailable.append("primary:"+primary)
		for descriptor: Dictionary in Rules.derived_descriptors(primary,mode).entries:
			var id: String = descriptor.abbreviation
			var field: String = FIELDS.get(id, "")
			var base := _number(actor.get("base_combat_stats",{}),field)
			var stored := _number(actor.get("combat_stats",{}),field)
			if base.kind == "invalid" or stored.kind == "invalid": return _fail("invalid_derived_stat:"+id)
			var chart: Dictionary = reference.get("values",{}).get(id, {"kind":"unavailable","reason":"primary_missing"})
			var comparison := "unavailable"
			if chart.kind == "integer" and base.kind == "integer":
				comparison = "match" if base.value == chart.value else "different"
				if comparison == "different": result.differences.append({"stat":id,"authoritative_base":base.value,"chart_reference":chart.value})
			elif chart.kind in ["allocation_required", "dead", "unlimited"]: comparison = "not_numeric_comparable"
			var allocated: Dictionary = allocation.get("values",{}).get(id,_missing("allocation_not_verified"))
			var entry := {"name":descriptor.name, "governing_primary":primary, "storage_field":field,
				"authoritative_base":base, "stored_calculated":stored,
				"equipment_modifier":_number(actor.get("equipment_stat_modifiers",{}),field),
				"effective":_number(effective,field), "allocated":allocated,
				"chart_reference":chart.duplicate(true), "comparison":comparison,
				"definition_page":descriptor.definition_page, "chart_page":reference.get("printed_page"),
				"authored_exception":authored_exceptions.get(id), "exception_origin":"caller_supplied_annotation"}
			if id in ["RR/G","ToF"]: entry["entitlement_status"] = "unresolved_no_grants"
			if id in ["AP","KP"]: entry["allocation_status"] = "unresolved_no_persuasion_record"
			result.derived[id] = entry
			if base.kind == "unavailable": result.unavailable.append("derived:"+id)
	for id: String in ["SR","TB"]:
		var field := id.to_lower()
		var stored := _number(actor.get("combat_stats",{}),field)
		var base := _number(actor.get("base_combat_stats",{}),field)
		if base.kind == "invalid" or stored.kind == "invalid": return _fail("invalid_resistance:"+id)
		result.resistances[id] = {"descriptor":Rules.resistance_descriptor(id),
			"authoritative_base":base, "stored_calculated":stored, "effective":_number(effective,field), "chart_reference":null}
		if stored.kind == "unavailable": result.unavailable.append("resistance:"+id)
	var maxima: Dictionary = actor.get("resource_maxima",{})
	var current: Dictionary = state.get("resources",{})
	result.resources["hpc"] = {"maximum":_number(actor.get("combat_stats",{}),"hpm"),"current":_number(state,"current_hpc")}
	if result.resources.hpc.maximum.kind == "invalid" or result.resources.hpc.current.kind == "invalid": return _fail("invalid_hpc")
	var resource_keys: Array = maxima.keys()
	for key: Variant in current:
		if not resource_keys.has(key): resource_keys.append(key)
	resource_keys.sort()
	for key: Variant in resource_keys:
		if not key is String: return _fail("invalid_resource_key")
		var maximum := _number(maxima,key)
		var remaining := _number(current,key)
		if maximum.kind == "invalid" or remaining.kind == "invalid": return _fail("invalid_resource:"+key)
		result.resources[key] = {"maximum":maximum,"current":remaining}
	result.resources["daily_allowances"] = {"maximum":state.get("ability_daily_maxima",{}).duplicate(true),"remaining":state.get("ability_daily_remaining",{}).duplicate(true)}
	result.resources["damage_shields"] = state.get("persistent_damage_shields",{}).duplicate(true)
	result.complete = result.unavailable.is_empty()
	return result

static func _allocation(actor: Dictionary, state: Dictionary) -> Dictionary:
	var progression: Dictionary = state.get("progression",{})
	if not progression.has("development"): return {"success":true,"values":{}}
	if not progression.development is Dictionary: return _fail("invalid_development_record")
	var checked := CharacterDevelopment.inspect(progression.development)
	if not checked.success: return _fail("invalid_development_record")
	# Describe the validated, recorded permanent split; never allocate or derive it.
	var totals := DexAllocation.validate(checked.allocation)
	if totals.totals.dex != actor.attributes.get("dex"): return _fail("allocation_actor_mismatch")
	for field: String in ["dt","dp"]:
		var base: Dictionary = actor.get("base_combat_stats",{})
		if base.has(field) and base[field] != totals.totals[field]: return _fail("allocation_base_mismatch")
	return {"success":true,"values":{"DT":{"kind":"integer","value":totals.totals.dt,"origin":"recorded_permanent_allocation"},
		"DP":{"kind":"integer","value":totals.totals.dp,"origin":"recorded_permanent_allocation"}}}

static func _number(values: Dictionary, field: String) -> Dictionary:
	if field.is_empty() or not values.has(field) or values[field] == null: return _missing("not_recorded")
	if typeof(values[field]) != TYPE_INT: return {"kind":"invalid"}
	return {"kind":"integer","value":values[field]}

static func _missing(reason: String) -> Dictionary:
	return {"kind":"unavailable","reason":reason}

static func _fail(reason: String) -> Dictionary:
	return {"success":false,"reason":reason}

static func _plain(value: Variant, depth: int = 0) -> bool:
	if depth > 32: return false
	if value is Dictionary:
		for key: Variant in value:
			if not key is String or not _plain(value[key],depth+1): return false
		return true
	if value is Array or value is PackedStringArray:
		for entry: Variant in value:
			if not _plain(entry,depth+1): return false
		return true
	return typeof(value) in [TYPE_NIL,TYPE_INT,TYPE_FLOAT,TYPE_BOOL,TYPE_STRING,TYPE_STRING_NAME]
