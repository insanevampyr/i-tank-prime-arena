class_name DeadAttributeEvaluator
extends RefCounted

# Dormant inspection only: no actor, simulation, RNG, storage or purchase access.
const PRIMARIES := ["str","end","spd","dex","wis","int","wit","man","luk","app"]
const DEAD_AT_ZERO := ["str","end","wis","int","wit"]
const RECOVERY_COST := 2000

static func evaluate(context: Dictionary) -> Dictionary:
	if not _keys(context,["phase","life_before","change_kind","classification","before","after","available_expc"]): return _fail("invalid_context")
	if context.phase not in ["creation","transition"] or context.life_before not in ["living","dead"]: return _fail("invalid_phase_or_life")
	if context.change_kind not in ["initial","permanent","temporary","recovery","effect_expiration"]: return _fail("invalid_change_kind")
	if typeof(context.available_expc) != TYPE_INT or context.available_expc < 0: return _fail("invalid_expc")
	var classification: Variant = context.classification
	if not classification is Dictionary or not _keys(classification,["kind","source_ref","authored_attributes","initial_zero_exceptions"]): return _fail("invalid_classification")
	if classification.kind not in ["living","authored_undead"] or not classification.source_ref is String or classification.source_ref.strip_edges().is_empty(): return _fail("classification_source_required")
	var reason := _attributes(classification.authored_attributes, false)
	if not reason.is_empty(): return _fail(reason)
	if not classification.initial_zero_exceptions is Array: return _fail("invalid_authored_exceptions")
	var seen := {}
	for attribute: Variant in classification.initial_zero_exceptions:
		if not attribute is String or not DEAD_AT_ZERO.has(attribute) or seen.has(attribute): return _fail("invalid_authored_exception")
		if classification.kind != "authored_undead" or classification.authored_attributes[attribute] != 0: return _fail("exception_not_authored_zero")
		seen[attribute] = true
	for name: String in ["before","after"]:
		var snapshot: Variant = context[name]
		if not snapshot is Dictionary or not _keys(snapshot,["permanent","effective"]): return _fail("invalid_snapshot")
		for layer: String in ["permanent","effective"]:
			reason = _attributes(snapshot[layer])
			if not reason.is_empty(): return _fail(reason)
	if context.phase == "creation":
		if context.change_kind != "initial" or context.life_before != "living" or context.before != context.after or context.after.permanent != classification.authored_attributes or context.after.effective != context.after.permanent: return _fail("invalid_creation_context")
	elif context.change_kind == "initial": return _fail("initial_kind_requires_creation")
	if context.change_kind in ["temporary","effect_expiration"] and context.before.permanent != context.after.permanent: return _fail("temporary_change_altered_permanent")
	if context.change_kind == "recovery" and context.life_before != "dead": return _fail("recovery_requires_dead_context")
	var findings: Array[Dictionary] = []
	var barriers: Array[String] = []
	var quotes: Array[Dictionary] = []
	var unresolved: Array[String] = []
	var died := false
	for attribute: String in DEAD_AT_ZERO:
		var old: int = context.before.effective[attribute]
		var current: int = context.after.effective[attribute]
		var permanent: int = context.after.permanent[attribute]
		var authored_before: bool = seen.has(attribute) and context.before.permanent[attribute] == 0 and old == 0
		if context.phase == "transition" and context.life_before == "living" and old <= 0 and not authored_before:
			unresolved.append(attribute+":unexplained_living_nonpositive")
			continue
		var original_zero: bool = seen.has(attribute) and context.before.permanent[attribute] == 0 and old == 0 and permanent == 0 and current == 0
		if original_zero and context.life_before == "living":
			findings.append({"attribute":attribute,"kind":"initial_authored_undead_zero","source_ref":classification.source_ref})
			continue
		if original_zero and context.life_before == "dead":
			unresolved.append(attribute+":authored_zero_death_history_required")
			continue
		if context.phase == "creation" and current == 0:
			unresolved.append(attribute+":initial_zero_creation_policy")
			continue
		if current <= 0:
			if context.life_before == "living" and old > 0:
				died = true
				findings.append({"attribute":attribute,"kind":"living_crossed_to_zero" if current == 0 else "living_crossed_below_zero","change_kind":context.change_kind})
			elif context.life_before == "living": unresolved.append(attribute+":unexplained_living_nonpositive")
			barriers.append(attribute)
			findings.append({"attribute":attribute,"kind":("permanent_zero" if permanent == 0 else "temporary_zero") if current == 0 else "effective_below_zero","effective":current,"permanent":permanent})
		elif old <= 0 and context.life_before == "dead":
			findings.append({"attribute":attribute,"kind":"recovered_after_death","revives":false})
		# Quote the permanent point, never the temporary penalty or an automatic debit.
		if permanent < 1:
			quotes.append({"attribute":attribute,"attribute_layer":"permanent","from":permanent,"to":permanent+1,"cost_expc":RECOVERY_COST,"affordable":context.available_expc >= RECOVERY_COST,"operation":"quote_only","revives":false})
	if not unresolved.is_empty(): return {"success":false,"status":"unresolved","reasons":unresolved,"findings":findings,"action_performed":false}
	var life_after: String = "dead" if died or context.life_before == "dead" else "living"
	return {"success":true,"status":"evaluated","findings":findings,"death_transition":died,
		"life_after":life_after,"resurrection_barriers":barriers,"emergency_recovery_quotes":quotes,
		"quote_scope":"individual_not_batch_authorization",
		"attribute_nonpositive_barrier_present":not barriers.is_empty(),"resurrection_performed":false,
		"resurrection_eligibility":"blocked_by_nonpositive_effective_attribute" if not barriers.is_empty() else "requires_separate_legitimate_effect_and_other_requirements",
		"unresolved_policies":unresolved,
		"action_performed":false,"expc_spent":0}

static func _attributes(value: Variant, allow_negative: bool = true) -> String:
	if not value is Dictionary or not _keys(value,PRIMARIES): return "complete_primary_attributes_required"
	for attribute: String in PRIMARIES:
		if typeof(value[attribute]) != TYPE_INT: return "integer_primary_required"
		if not allow_negative and value[attribute] < 0: return "negative_authored_baseline_unsupported"
		if value[attribute] > 35: return "outside_verified_chart_range"
	return ""

static func _keys(value: Dictionary, names: Array) -> bool:
	return value.size() == names.size() and value.has_all(names)

static func _fail(reason: String, status: String = "invalid") -> Dictionary:
	return {"success":false,"status":status,"reason":reason,"action_performed":false}
