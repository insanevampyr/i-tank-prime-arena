class_name BalanceSkillCheck
extends RefCounted

# Isolated rules query. No condition, event queue, clock or spending mutations.
const SOURCE := "PRIME-V3 pp. 23, 27, 67, 69, 107; owner Task 39H"

static func validate(profile: Dictionary) -> Dictionary:
	for key: String in ["effective_dex", "investments", "scm", "rb", "modifier"]:
		if typeof(profile.get(key)) != TYPE_INT:
			return _fail("balance_" + key + "_unavailable")
	if profile.investments < 0 or profile.rb < 0:
		return _fail("invalid_balance_investment_or_rb")
	if profile.get("training") not in ["trained", "untrained"]:
		return _fail("balance_training_unknown")
	if (profile.training == "trained") != (profile.investments >= 1):
		return _fail("conflicting_balance_training")
	if typeof(profile.get("source_ref")) != TYPE_STRING or String(profile.source_ref).strip_edges().is_empty():
		return _fail("balance_source_unavailable")
	# Bound arithmetic inputs; these are overflow guards, not gameplay score caps.
	for key: String in ["effective_dex", "investments", "scm", "rb", "modifier"]:
		if profile[key] < -1_000_000 or profile[key] > 1_000_000:
			return _fail("balance_arithmetic_out_of_bounds")
	return {"success": true}

static func resolve(profile: Dictionary, natural_roll: Variant) -> Dictionary:
	var checked := validate(profile)
	if not checked.success: return checked
	if typeof(natural_roll) != TYPE_INT or natural_roll < 1 or natural_roll > 20:
		return _fail("invalid_balance_natural_roll")
	var skill_modifier: int = -5 if profile.training == "untrained" else -1 + profile.investments - 1
	var target: int = profile.effective_dex + skill_modifier + profile.scm + profile.modifier
	var adjusted: int = natural_roll - profile.rb
	return {"success": true, "check_kind": "balance", "natural_roll": natural_roll,
		"critical_success": natural_roll == 1, "critical_failure": natural_roll == 20,
		"check_success": natural_roll == 1 or (natural_roll != 20 and adjusted <= target),
		"target": target, "adjusted_roll": adjusted, "skill_modifier": skill_modifier,
		"automatic": false, "inputs": profile.duplicate(true), "rules_source": SOURCE}

static func roll(profile: Dictionary, rng: DeterministicCombatRng, opportunity_id: String) -> Dictionary:
	var checked := validate(profile)
	if not checked.success: return checked
	if rng == null or opportunity_id.strip_edges().is_empty(): return _fail("balance_rng_or_opportunity_unavailable")
	var result := resolve(profile, rng.next_int(1, 20))
	result.opportunity_id = opportunity_id
	result.rng_draw_index = rng.get_draw_count()
	# Evidence only, deliberately NOT published as a live CombatEvent.
	return result

static func _fail(reason: String) -> Dictionary:
	return {"success": false, "reason": reason}
