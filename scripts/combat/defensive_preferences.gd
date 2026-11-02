class_name DefensivePreferences
extends RefCounted

# Owner-approved #37A policy. This plans choices using authoritative eligibility
# facts; it performs no defense rolls and cannot grant a defense or NAC.
const OPTIONS := ["nac","dodge","block","soak"]

static func valid(order: Array) -> bool:
	if order.size() != OPTIONS.size(): return false
	for option: String in OPTIONS:
		if order.count(option) != 1: return false
	return true

static func plan(order: Array, facts: Dictionary, blocks: Array, nacs: Array) -> Dictionary:
	if not valid(order): return {"success":false,"reason":"invalid_defense_preference_order"}
	var selected := ""
	var d: Dictionary = facts.get("dodge",{})
	var s: Dictionary = facts.get("soak",{})
	if typeof(d.get("eligible",false)) != TYPE_BOOL or typeof(s.get("eligible",false)) != TYPE_BOOL: return {"success":false,"reason":"unverified_defense_eligibility"}
	if d.get("eligible",false) and typeof(d.get("value")) != TYPE_INT: return {"success":false,"reason":"unverified_dodge_value"}
	if s.get("eligible",false) and typeof(s.get("value")) != TYPE_INT: return {"success":false,"reason":"unverified_soak_value"}
	if d.get("eligible",false): selected = "dodge"
	if s.get("eligible",false) and (selected.is_empty() or s.value > d.value or (s.value == d.value and order.find("soak") < order.find("dodge"))): selected = "soak"
	var choices: Array = []
	var used := {}
	var dodge_soak_considered := false
	for option: String in order:
		if option in ["dodge","soak"]:
			if not dodge_soak_considered and not selected.is_empty(): choices.append({"kind":selected,"source":selected})
			dodge_soak_considered = true
		else:
			# Input order is already the verified per-Block/per-Special order.
			for candidate: Variant in (blocks if option == "block" else nacs):
				if not candidate is Dictionary or not candidate.get("source") is String or candidate.source.is_empty(): return {"success":false,"reason":"defense_source_identity_required"}
				if typeof(candidate.get("eligible",false)) != TYPE_BOOL: return {"success":false,"reason":"unverified_defense_eligibility"}
				var key: Array = [option,candidate.source]
				if used.has(key): return {"success":false,"reason":"duplicate_defense_source"}
				used[key] = true
				if candidate.get("eligible",false): choices.append({"kind":option,"source":candidate.source})
	return {"success":true,"choices":choices}
