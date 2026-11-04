class_name AttributeShadowComparison
extends RefCounted

# Explicit development/test boundary only. Never registered with the scheduler,
# session, UI or event bus; reports have no authoritative consumer.
const View = preload("res://scripts/combat/character_attribute_projection.gd")
const Rules = preload("res://scripts/combat/prime_v3_attribute_engine.gd")
const MAX_ACTORS := 32
const MAX_RECORDS := 512
const MAX_EFFECTS := 64

static func capture(simulation: CombatSimulation, modes: Dictionary, exceptions: Dictionary = {}) -> Dictionary:
	if simulation == null: return _fail("simulation_unavailable")
	if modes.is_empty() or modes.size() > MAX_ACTORS: return _fail("diagnostic_actor_budget")
	for id: Variant in modes:
		if not id is String or id.is_empty(): return _fail("invalid_actor_identity")
		if modes[id] not in ["mana","regular"]: return _fail("explicit_chart_mode_required")
	for id: Variant in exceptions:
		if not modes.has(id) or not exceptions[id] is Dictionary: return _fail("invalid_exception_annotation")
	var actors := {}
	var ids: Array = modes.keys()
	ids.sort()
	var count := 0
	for id: String in ids:
		var actor := simulation.get_actor_definition(StringName(id))
		var state := simulation.get_actor_state(StringName(id))
		if actor == null or state == null: return _fail("actor_unavailable:"+id)
		# Refuse absent source evidence rather than infer provenance or mode from a
		# name, a class or an actor-kind string. Authored creatures need no policy.
		for field: String in ["attributes","combat_stats"]:
			if not actor.field_sources.get(field) is String or String(actor.field_sources[field]).is_empty(): return _fail("source_provenance_unavailable:"+id+":"+field)
		for primary: String in Rules.PRIMARY_NAMES:
			if not actor.attributes.has(primary.to_lower()) or actor.attributes[primary.to_lower()] == null: return _fail("source_attribute_unavailable:"+id+":"+primary)
		if state.timed_stat_effects.size() > MAX_EFFECTS or state.inventory_quantities.size() > MAX_RECORDS: return _fail("diagnostic_record_budget")
		for field: String in ["history","award_ids"]:
			var records: Variant = state.progression.get(field,[])
			if not records is Array: return _fail("invalid_history_records")
			if records.size() > MAX_RECORDS: return _fail("diagnostic_record_budget")
		var development: Variant = state.progression.get("development",{})
		if not development is Dictionary or not development.get("commands",[]) is Array: return _fail("invalid_development_record")
		if development.get("commands",[]).size() > MAX_RECORDS: return _fail("diagnostic_record_budget")
		for effect: Variant in state.timed_stat_effects.values():
			if not effect is Dictionary or not effect.get("stat_modifiers",{}) is Dictionary: return _fail("invalid_temporary_effect")
			for value: Variant in effect.get("stat_modifiers",{}).values():
				if typeof(value) != TYPE_INT: return _fail("invalid_temporary_modifier")
		var effective := {}
		var fields: Array = View.FIELDS.values()
		fields.append_array(["sr","tb"])
		for field: String in fields:
			var value: Variant = simulation.get_effective_actor_combat_stat(actor.actor_id,field)
			if value != null: effective[field] = value
		var projected := View.project_actor(actor,state,modes[id],effective,exceptions.get(id,{}))
		if not projected.success: return _fail("projection_rejected:"+id+":"+String(projected.reason))
		var comparisons := {}
		var summary := {"match":0,"mismatch":0,"authored_exception":0,"unavailable":0,"not_numeric_comparable":0}
		for stat: String in projected.derived:
			var entry: Dictionary = projected.derived[stat].duplicate(true)
			var classification: String = entry.comparison
			if classification == "different": classification = "mismatch" if entry.authored_exception == null else "authored_exception"
			entry["classification"] = classification
			entry["compared_layer"] = "authoritative_base_vs_permanent_primary_chart"
			entry["automatic_gameplay_defect"] = false
			comparisons[stat] = entry
			summary[classification] += 1
			count += 1
		var protection := simulation.get_damage_protection_profile(actor.actor_id)
		var defense := simulation.get_defense_profile(actor.actor_id)
		actors[id] = {"identity":projected.identity,"mode":modes[id],"provenance":projected.source_provenance,
			"comparisons":comparisons,"summary":summary,"resistances":projected.resistances,
			"resources":projected.resources,"layers":{
				"equipment_modifiers":actor.equipment_stat_modifiers.duplicate(true),
				"temporary_effects":state.timed_stat_effects.duplicate(true),
				"conditions":Array(state.conditions),
				"encumbrance":{"status":"unavailable","reason":"no_separate_verified_carried_weight_ledger"},
				"protection_profile":null if protection == null else protection.to_dictionary(),
				"defense_profile":null if defense == null else defense.to_dictionary()},
			"resistance_comparison":"independent_no_primary_chart",
			"protection_comparison":"location_and_source_specific_not_an_END_chart_total"}
	return {"success":true,"policy":"explicit_test_boundary_only","actors":actors,
		"actor_count":ids.size(),"comparison_count":count,"authoritative":false}

static func compare_legacy_lookups() -> Dictionary:
	# Fixed bounded comparison; no actor, simulation, RNG or event access.
	var rows: Array[Dictionary] = []
	for mode: String in ["mana","regular"]:
		for score in range(1,21):
			var old := PrimeV3StrengthChart.derived(score)
			var reference := Rules.lookup("STR",score,mode)
			for stat: String in ["SB","PPG","MWC"]:
				rows.append(_legacy_row("STR",stat,score,mode,old[stat.to_lower()],reference.values[stat].value))
		for score in range(36):
			rows.append(_legacy_row("DEX","ACC",score,mode,PrimeV3DexChart.accuracy(score,mode),Rules.lookup("DEX",score,mode).values.ACC.value))
	return {"success":true,"comparisons":rows,"comparison_count":rows.size(),"authoritative":false}

static func _legacy_row(primary: String, stat: String, score: int, mode: String, value: int, reference: int) -> Dictionary:
	return {"primary":primary,"stat":stat,"score":score,"mode":mode,"legacy_value":value,
		"reference":reference,"classification":"match" if value == reference else "mismatch"}

static func _fail(reason: String) -> Dictionary:
	return {"success":false,"reason":reason,"authoritative":false}
