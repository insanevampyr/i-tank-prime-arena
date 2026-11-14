class_name BalanceActorProfile
extends RefCounted

# Explicit resource + live actor query. No inferred training, charts or persistent fields.
static func capture(definition: CombatCharacterDefinitionResource, actor: CombatActorDefinition,
		state: CombatActorState, now_us: int, purchases: Array = []) -> Dictionary:
	if definition == null or actor == null or state == null or now_us < 0:
		return _fail("balance_actor_unavailable")
	if state.actor_id != actor.actor_id or definition.actor_kind != actor.actor_kind \
	or definition.field_sources != actor.field_sources:
		return _fail("balance_definition_binding_mismatch")
	if state.conditions.has("prone"): return _fail("balance_not_required_already_prone")
	var dex: Variant = actor.attributes.get("dex")
	if typeof(dex) != TYPE_INT or dex < 0 or dex > 35 :
		return _fail("balance_permanent_dex_reference_unavailable")
	if dex != definition.attributes.get("dex"):
		if not state.progression.has("development") or not CharacterDevelopment.validate_source(state.progression.development,definition,purchases) or DexAllocation.validate(CharacterDevelopment.inspect(state.progression.development).allocation).totals.dex != dex: return _fail("balance_permanent_dex_reference_unavailable")
	var record: Variant = definition.proficiencies.get("balance")
	if typeof(record) != TYPE_DICTIONARY: return _fail("balance_training_unknown")
	var profile: Dictionary = record.duplicate(true)
	profile.effective_dex = dex
	profile.modifier = 0
	var rb: Variant = actor.get_combat_stat("rb")
	if typeof(rb) != TYPE_INT: return _fail("balance_rb_unavailable")
	profile.rb = rb
	var effects: Array = []
	var activations := {}
	var keys: Array = state.timed_stat_effects.keys()
	keys.sort()
	for key: Variant in keys:
		var effect: Variant = state.timed_stat_effects[key]
		if typeof(effect) != TYPE_DICTIONARY: return _fail("balance_effect_unverified")
		var modifiers: Variant = effect.get("stat_modifiers", {})
		if typeof(modifiers) != TYPE_DICTIONARY: return _fail("balance_effect_unverified")
		var relevant := false
		for field: String in ["dex", "scm", "rb", "balance"]:
			if modifiers.has(field): relevant = true
		if not relevant: continue
		if typeof(effect.get("expires_at_us")) != TYPE_INT: return _fail("balance_effect_expiry_unverified")
		if effect.expires_at_us <= now_us: continue
		for field: String in ["source_ref", "source_action_instance_id"]:
			if typeof(effect.get(field)) != TYPE_STRING or String(effect[field]).strip_edges().is_empty():
				return _fail("balance_effect_source_unverified")
		if activations.has(effect.source_action_instance_id): return _fail("balance_effect_activation_duplicated")
		activations[effect.source_action_instance_id] = true
		for field: String in ["dex", "scm", "rb", "balance"]:
			if not modifiers.has(field): continue
			if typeof(modifiers[field]) != TYPE_INT or modifiers[field] < -1_000_000 or modifiers[field] > 1_000_000:
				return _fail("balance_effect_modifier_unverified")
			if field == "dex": profile.effective_dex += modifiers[field]
			elif field == "scm":
				if typeof(profile.get("scm")) != TYPE_INT: return _fail("balance_scm_unavailable")
				profile.scm += modifiers[field]
			elif field == "rb": profile.rb += modifiers[field]
			else: profile.modifier += modifiers[field]
		effects.append({"effect_id": String(key), "source_ref": effect.source_ref,
			"activation_id": effect.source_action_instance_id, "expires_at_us": effect.expires_at_us,
			"modifiers": modifiers.duplicate(true)})
	var checked := BalanceSkillCheck.validate(profile)
	if not checked.success: return checked
	profile.definition_id = String(definition.definition_id)
	profile.actor_id = String(actor.actor_id)
	profile.effects = effects
	return {"success": true, "profile": profile}

static func _fail(reason: String) -> Dictionary:
	return {"success": false, "reason": reason}
