extends RefCounted

const VAELIS = preload("res://data/characters/vaelis_thorn.tres")
const BOSS = preload("res://data/characters/prime_v3_rare_human_warrior_boss.tres")
const GUARD = preload("res://data/characters/prime_v3_uncommon_guard.tres")
var failures: Array[String] = []
var assertions := 0

func run() -> Array[String]:
	_test_arithmetic()
	_test_profiles()
	_test_rng_and_replay()
	print("39H Balance foundation: %d assertions; isolated evidence only, no live effect hooks." % assertions)
	return failures

func _profile(si: int = 1) -> Dictionary:
	return {"effective_dex": 9, "training": "untrained" if si == 0 else "trained",
		"investments": si, "scm": 0, "rb": 0, "modifier": 0, "source_ref": "TEST-FIXTURE V3 pp.67,69"}

func _test_arithmetic() -> void:
	# Independent expectations: DEX 9, printed initial -1, each extra SI +1.
	for pair: Array in [[0, 4], [1, 8], [2, 9], [3, 10], [4, 11], [5, 12]]:
		for raw in range(1, 21):
			var p := _profile(pair[0])
			var before := p.duplicate(true)
			var result := BalanceSkillCheck.resolve(p, raw)
			_expect(result.success and result.target == pair[1], "Independent SI target must match source arithmetic.")
			_expect(result.check_success == (raw == 1 or (raw != 20 and raw <= pair[1])), "Skill success must preserve natural critical overrides.")
			_expect(result.critical_success == (raw == 1) and result.critical_failure == (raw == 20), "Natural critical flags must reflect raw d20 only.")
			_expect(not result.automatic and p == before, "No SI grants automatic Balance; resolving is pure.")
	var p := _profile(2)
	p.scm = 2
	p.rb = 3
	p.modifier = -1
	var result := BalanceSkillCheck.resolve(p, 13)
	_expect(result.target == 10 and result.adjusted_roll == 10 and result.check_success, "SCM, verified modifiers and RB each apply once.")
	_expect(BalanceSkillCheck.resolve(p, 20).critical_failure, "RB never suppresses natural 20.")
	p.effective_dex = -10
	_expect(BalanceSkillCheck.resolve(p, 1).check_success, "Natural one remains critical success at a negative target.")
	for value: Variant in [null, 0, 21, 1.0, "1"]:
		_expect(not BalanceSkillCheck.resolve(_profile(), value).success, "Malformed natural rolls fail closed.")

func _actor(resource: CombatCharacterDefinitionResource, id: StringName = &"player") -> CombatActorDefinition:
	return resource.instantiate_actor(id, resource.display_name, PackedStringArray())

func _test_profiles() -> void:
	for definition: CombatCharacterDefinitionResource in [VAELIS, BOSS]:
		var actor := _actor(definition)
		var state := CombatActorState.new(actor)
		var source_before := definition.to_dictionary().duplicate(true)
		var actor_before := actor.to_dictionary().duplicate(true)
		var state_before := state.to_dictionary().duplicate(true)
		var result := BalanceActorProfile.capture(definition, actor, state, 0)
		if definition == BOSS:
			_expect(not result.success and result.reason == "balance_rb_unavailable", "Boss SI/SCM are sourced but absent live RB must not be invented.")
			_expect(definition.proficiencies.balance.investments == 1 and definition.proficiencies.balance.scm == 0, "Boss source-backed SI/SCM must remain intact.")
			continue
		_expect(result.success, "Real authored Balance profile must be available: %s" % result)
		if not result.success: continue
		_expect(BalanceSkillCheck.resolve(result.profile, 10).target == 9, "Vaelis SI2/SCM0 must preserve the authored Balance target.")
		_expect(result.profile.source_ref != "" and result.profile.definition_id == String(definition.definition_id), "Evidence must identify its original definition and source.")
		state.timed_stat_effects["temporary_dex"] = {"stat_modifiers": {"dex": -2}, "source_ref": "TEST-FIXTURE authorized signed DEX", "source_action_instance_id": "activation_1", "expires_at_us": 100}
		var changed := BalanceActorProfile.capture(definition, actor, state, 99)
		_expect(changed.success and changed.profile.effective_dex == actor.attributes.dex - 2, "Active signed DEX modifier must be read without clamping or allocation mutation.")
		_expect(BalanceActorProfile.capture(definition, actor, state, 100).profile.effective_dex == actor.attributes.dex, "Expired effects do not affect DEX; query does not remove them.")
		state.timed_stat_effects.temporary_dex.stat_modifiers.dex = 3
		_expect(BalanceActorProfile.capture(definition, actor, state, 0).profile.effective_dex == actor.attributes.dex + 3, "Positive temporary DEX must recompute from source.")
		state.timed_stat_effects.temporary_dex.stat_modifiers = {"dex": -1, "scm": 2, "rb": 1, "balance": -2}
		var combined := BalanceActorProfile.capture(definition, actor, state, 0)
		_expect(combined.success and combined.profile.scm == 2 and combined.profile.rb == 1 and combined.profile.modifier == -2, "Source-qualified relevant modifiers must each be projected once.")
		state.timed_stat_effects["duplicate"] = state.timed_stat_effects.temporary_dex.duplicate(true)
		_expect(BalanceActorProfile.capture(definition, actor, state, 0).reason == "balance_effect_activation_duplicated", "Duplicate activation must not grant DEX or skill modifiers twice.")
		state.timed_stat_effects.erase("duplicate")
		state.timed_stat_effects.temporary_dex.stat_modifiers.dex = "bad"
		_expect(not BalanceActorProfile.capture(definition, actor, state, 0).success, "Malformed effective DEX source must reject.")
		state.timed_stat_effects.temporary_dex.stat_modifiers.dex = 1
		state.timed_stat_effects.temporary_dex.erase("source_action_instance_id")
		_expect(not BalanceActorProfile.capture(definition, actor, state, 0).success, "Unverified relevant effect must fail closed.")
		state.timed_stat_effects.clear()
		state.conditions.append("prone")
		_expect(BalanceActorProfile.capture(definition, actor, state, 0).reason == "balance_not_required_already_prone", "Already-prone actor needs no Balance roll.")
		state.conditions.clear()
		_expect(definition.to_dictionary() == source_before and actor.to_dictionary() == actor_before and state.to_dictionary() == state_before, "Profile projection must leave source and actor data unchanged.")
	var guard := _actor(GUARD)
	_expect(BalanceActorProfile.capture(GUARD, guard, CombatActorState.new(guard), 0).reason == "balance_training_unknown", "Missing Guard skill data is unknown, not untrained.")
	var source: CombatCharacterDefinitionResource = VAELIS.duplicate(true)
	source.proficiencies.balance = {"training": "untrained", "investments": 0, "scm": 0, "source_ref": "TEST-FIXTURE explicit untrained"}
	var actor := _actor(source)
	var state := CombatActorState.new(actor)
	_expect(BalanceActorProfile.capture(source, actor, state, 0).profile.training == "untrained", "Explicit untrained must remain distinguishable from absent data.")
	_expect(not BalanceActorProfile.capture(BOSS, actor, state, 0).success, "Wrong definition binding must fail closed.")
	source.proficiencies.balance.erase("scm")
	_expect(not BalanceActorProfile.capture(source, actor, state, 0).success, "SCM is not inferred from INT or Running.")
	_expect(not BalanceActorProfile.capture(null, actor, state, 0).success, "Missing actor source fails closed.")

func _test_rng_and_replay() -> void:
	var rng := DeterministicCombatRng.new(579)
	for key: String in ["training", "investments", "effective_dex", "scm", "source_ref", "rb", "modifier"]:
		var invalid := _profile()
		invalid.erase(key)
		var before := rng.wave_entry_state().duplicate(true)
		_expect(not BalanceSkillCheck.roll(invalid, rng, "unavailable").success, "Missing evidence must reject before rolling.")
		_expect(rng.wave_entry_state() == before, "Rejected checks must fabricate no RNG draw.")
	_expect(not BalanceSkillCheck.roll(_profile(), rng, "").success and rng.get_draw_count() == 0, "Missing opportunity identity consumes no RNG.")
	for change: Dictionary in [{"training": "unknown"}, {"training": "untrained"}, {"investments": -1}, {"rb": -1}, {"scm": 1.0}, {"source_ref": ""}, {"modifier": 2_000_000}]:
		var invalid := _profile()
		invalid.merge(change, true)
		_expect(not BalanceSkillCheck.roll(invalid, rng, "invalid").success and rng.get_draw_count() == 0, "Malformed or conflicting profile rejects before any RNG.")
	for seed_value in [1, 579, 8400]:
		var outputs: Array = []
		for replay in range(2):
			var seeded := DeterministicCombatRng.new(seed_value)
			var evidence := BalanceSkillCheck.roll(_profile(3), seeded, "isolated_effect_1")
			_expect(seeded.get_draw_count() == 1 and evidence.rng_draw_index == 1, "Exactly one seeded d20 per eligible isolated check.")
			_expect(evidence.opportunity_id == "isolated_effect_1", "Evidence preserves supplied stable opportunity identity.")
			outputs.append(JSON.stringify(evidence, "", true))
		_expect(outputs[0] == outputs[1], "Seeded evidence must serialize deterministically on replay.")
	var controls: Array = []
	for evaluate in [false, true]:
		var harness := TwoClientSyncHarness.new(7)
		var sim: CombatSimulation = harness.authority.simulation
		var actor := _actor(VAELIS)
		sim.register_actor(actor)
		sim.begin_combat()
		sim.start_action(actor.actor_id, CombatActionDefinition.new(&"ordinary_control", 1), "ordinary_control")
		if evaluate:
			var before := sim.get_state_snapshot().duplicate(true)
			var profile := BalanceActorProfile.capture(VAELIS, actor, sim.get_actor_state(actor.actor_id), 0)
			_expect(profile.success, "Real registered actor profile must remain available.")
			# Isolated RNG: no speculative new draws in the live simulation.
			BalanceSkillCheck.roll(profile.profile, DeterministicCombatRng.new(7), "isolated_control")
			_expect(sim.get_state_snapshot() == before, "Opt-in isolated evaluation must not change the live snapshot or RNG.")
		sim.advance_to(5_000_000)
		var envelopes := harness.authority.publish_current_events()
		for envelope: CombatEventEnvelope in envelopes:
			harness.client_a.receive(envelope)
		for i in range(envelopes.size() - 1, -1, -1):
			harness.client_b.receive(envelopes[i])
			harness.client_b.receive(envelopes[i])
		_expect(harness.compare_clients().success, "Ordinary authoritative events must converge with reversed/duplicate delivery.")
		var events: Array = []
		for event: CombatEvent in sim.get_resolved_events(): events.append(event.to_dictionary())
		controls.append({"snapshot": sim.get_state_snapshot(), "events": events, "digest": harness.authority.get_state_digest()})
	_expect(controls[0] == controls[1], "Ordinary action outcomes, events and digest must be identical with/without isolated Balance.")

func _expect(ok: bool, message: String) -> void:
	assertions += 1
	if not ok: failures.append(message)
