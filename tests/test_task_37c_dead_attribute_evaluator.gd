extends RefCounted

const Evaluator = preload("res://scripts/combat/dead_attribute_evaluator.gd")
var failures: Array[String] = []
var assertions := 0

func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok: failures.append(message)

func fixture() -> Dictionary:
	var attributes := {}
	for name: String in Evaluator.PRIMARIES: attributes[name] = 10
	var state := {"permanent":attributes.duplicate(true),"effective":attributes.duplicate(true)}
	return {"phase":"transition","life_before":"living","change_kind":"permanent",
		"classification":{"kind":"living","source_ref":"explicit isolated authored baseline","authored_attributes":attributes,"initial_zero_exceptions":[]},
		"before":state.duplicate(true),"after":state.duplicate(true),"available_expc":2000}

func run() -> Array[String]:
	var text := FileAccess.get_file_as_string("res://docs/audits/TASK_37C_VERIFIED_SOURCE_CATALOG.json")
	check(text.sha256_text() == FileAccess.get_file_as_string("res://docs/audits/TASK_37C_VERIFIED_SOURCE_CATALOG.sha256").split(" ")[0],"Independent frozen source checksum must match.")
	var catalog: Dictionary = JSON.parse_string(text)
	for mode: String in ["mana","regular"]:
		for primary: String in catalog.charts[mode][0].cells:
			check((catalog.charts[mode][0].cells[primary] == "DEAD") == Evaluator.DEAD_AT_ZERO.has(primary.to_lower()),"Evaluator lethal list must match independent zero rows in both modes.")
	for attribute: String in Evaluator.DEAD_AT_ZERO:
		for kind: String in ["permanent","temporary"]:
			var context := fixture()
			context.change_kind = kind
			context.after.effective[attribute] = 0
			if kind == "permanent": context.after.permanent[attribute] = 0
			var preserved := context.duplicate(true)
			var result := Evaluator.evaluate(context)
			check(result.success and result.death_transition and result.life_after == "dead","Each lethal permanent/temporary zero crossing must identify death.")
			check(result.findings.has({"attribute":attribute,"kind":"living_crossed_to_zero","change_kind":kind}),"Exact primary and transition cause must remain explicit.")
			if kind == "permanent":
				check(result.emergency_recovery_quotes[0].cost_expc == 2000 and result.emergency_recovery_quotes[0].affordable and not result.emergency_recovery_quotes[0].revives,"Owner-approved permanent recovery quote is exactly 2000 without revival.")
			else:
				check(result.emergency_recovery_quotes.is_empty(),"A temporary-only zero cannot be quoted as a permanent recovery purchase.")
			check(result.expc_spent == 0 and not result.action_performed and not result.resurrection_performed,"No transaction/action/resurrection may be executed.")
			check(result == Evaluator.evaluate(context) and context == preserved,"Evaluation must be deterministic and nonmutating.")
			check(result.resurrection_eligibility == "blocked_by_nonpositive_effective_attribute","Effective zero blocks resurrection regardless of permanent/temporary source.")
			context.available_expc = 1999
			var unfunded := Evaluator.evaluate(context)
			check((unfunded.emergency_recovery_quotes.is_empty() or not unfunded.emergency_recovery_quotes[0].affordable) and context.available_expc == 1999,"Insufficient funds stay unspent; temporary penalties remain unpurchasable.")
			var recovery := fixture()
			recovery.life_before = "dead"
			recovery.change_kind = "recovery"
			recovery.before.permanent[attribute] = 0
			recovery.before.effective[attribute] = 0
			recovery.after.permanent[attribute] = 1
			recovery.after.effective[attribute] = 1
			var recovered := Evaluator.evaluate(recovery)
			check(recovered.success and recovered.life_after == "dead" and not recovered.death_transition and recovered.resurrection_barriers.is_empty(),"Recovery removes zero barrier but cannot revive or cause a new death.")
	for attribute: String in ["spd","dex","luk","app","man"]:
		var context := fixture()
		context.after.permanent[attribute] = 0
		context.after.effective[attribute] = 0
		var result := Evaluator.evaluate(context)
		check(result.success and not result.death_transition and result.life_after == "living" and result.emergency_recovery_quotes.is_empty(),"Nonlethal/MAN zero must not create death or emergency price.")
	_test_initial_and_undead()
	_test_nonpositive_and_expiration()
	_test_invalid_and_unresolved()
	_test_recovery_pricing()
	var simulation := CombatSimulation.new(37)
	simulation.register_actor(PrimeV3VerticalSliceFixture.make_player_actor(&"vaelis_thorn"))
	var before := simulation.get_state_snapshot()
	var report := Evaluator.evaluate(fixture())
	report.findings.append({"test":"changed output"})
	check(simulation.get_state_snapshot() == before and before.schema_version == 12,"Dormant evaluator cannot mutate simulation, RNG, events or schema.")
	print("37C dormant DEAD evaluator: %d assertions; five lethal primaries, five nonlethal/unlisted primaries, recovery, source rows and purity." % assertions)
	return failures

func _test_initial_and_undead() -> void:
	var source: CombatCharacterDefinitionResource = load("res://data/characters/prime_v3_common_skelly.tres")
	var context := fixture()
	context.phase = "creation"
	context.change_kind = "initial"
	context.classification = {"kind":"authored_undead","source_ref":"data/characters/prime_v3_common_skelly.tres; owner-approved initial WIS0/INT0 exception","authored_attributes":source.attributes.duplicate(true),"initial_zero_exceptions":["wis","int"]}
	context.before = {"permanent":source.attributes.duplicate(true),"effective":source.attributes.duplicate(true)}
	context.after = context.before.duplicate(true)
	var result := Evaluator.evaluate(context)
	check(result.success and result.life_after == "living" and not result.death_transition and result.resurrection_barriers.is_empty(),"Actual authored Skelly initial zeros cannot cause retroactive death/invalidation.")
	check(result.findings.size() == 2,"Both independently authored zero exceptions must be described.")
	context.phase = "transition"
	context.change_kind = "temporary"
	check(Evaluator.evaluate(context).success and not Evaluator.evaluate(context).death_transition,"Unchanged authored undead baseline stays valid after admission.")
	context.before.permanent.wis = 1
	context.before.effective.wis = 1
	context.change_kind = "permanent"
	check(Evaluator.evaluate(context).death_transition,"Authored initial-zero exception must not invent universal immunity to later positive-to-zero loss.")
	context = fixture()
	context.phase = "creation"
	context.change_kind = "initial"
	context.classification.authored_attributes.wis = 0
	context.before.permanent.wis = 0
	context.before.effective.wis = 0
	context.after = context.before.duplicate(true)
	check(Evaluator.evaluate(context).status == "unresolved","Unapproved initial living zero needs a creation policy, not fabricated death.")

func _test_invalid_and_unresolved() -> void:
	check(not Evaluator.evaluate({}).success,"Missing context must fail closed.")
	for key: String in fixture():
		var bad := fixture()
		bad.erase(key)
		check(not Evaluator.evaluate(bad).success,"Every required input must be explicit.")
	for value: Variant in [null,1.0,"10",true,{},[]]:
		var bad := fixture()
		bad.after.effective.wis = value
		check(not Evaluator.evaluate(bad).success,"Malformed attributes must not be coerced.")
	for value: Variant in [-1,2000.0,"2000",null]:
		var bad := fixture()
		bad.available_expc = value
		check(not Evaluator.evaluate(bad).success,"Missing/negative/noninteger EXPC must fail closed.")
	var context := fixture()
	context.after.effective.wis = -2
	check(Evaluator.evaluate(context).death_transition,"Overshooting effective zero now establishes death without clamping.")
	context = fixture()
	context.after.permanent.wis = 0
	check(Evaluator.evaluate(context).success and not Evaluator.evaluate(context).death_transition,"Positive effective WIS prevents attribute death despite permanent zero.")
	context = fixture()
	context.after.effective.wis = 36
	check(not Evaluator.evaluate(context).success,"No extrapolation beyond source range.")
	context = fixture()
	context.after.permanent.erase("wit")
	check(not Evaluator.evaluate(context).success,"Incomplete attribute snapshot cannot be inferred.")
	context = fixture()
	context.after.effective["con"] = 0
	check(not Evaluator.evaluate(context).success,"Unknown primary fields are unsupported.")
	context = fixture()
	context.classification.kind = "unknown"
	check(not Evaluator.evaluate(context).success,"Unknown classification fails closed.")
	context = fixture()
	context.classification.initial_zero_exceptions = ["wis"]
	check(not Evaluator.evaluate(context).success,"Living/nonzero authored data cannot claim undead zero immunity.")
	context = fixture()
	context.change_kind = "timed_update"
	check(not Evaluator.evaluate(context).success,"Evaluator must not accept a request to advance time.")
	context = fixture()
	context.before.permanent.wis = 0
	context.before.effective.wis = 0
	check(Evaluator.evaluate(context).status == "unresolved","An unexplained living-zero input cannot be legitimized by a later increase.")
	context = fixture()
	context.after.permanent.wis = 0
	context.after.effective.wis = 0
	context.after.permanent.str = 0
	context.after.effective.str = 0
	var result := Evaluator.evaluate(context)
	check(result.success and result.death_transition and result.resurrection_barriers.size() == 2 and result.emergency_recovery_quotes.size() == 2 and result.quote_scope == "individual_not_batch_authorization" and context.available_expc == 2000,"Multiple barriers produce individual quotes, never duplicate death actions or pretend both purchases were funded/executed.")

func _test_nonpositive_and_expiration() -> void:
	for attribute: String in Evaluator.DEAD_AT_ZERO:
		for kind: String in ["permanent","temporary"]:
			var context := fixture()
			context.change_kind = kind
			context.after.effective[attribute] = -2
			if kind == "permanent": context.after.permanent[attribute] = -2
			var before := context.duplicate(true)
			var result := Evaluator.evaluate(context)
			check(result.success and result.death_transition and result.life_after == "dead" and result.resurrection_barriers.has(attribute),"Each effective lethal overshoot must kill and block resurrection.")
			check(result.findings.has({"attribute":attribute,"kind":"effective_below_zero","effective":-2,"permanent":context.after.permanent[attribute]}),"Negative score must remain signed and visible in findings.")
			if kind == "permanent":
				check(result.emergency_recovery_quotes.size() == 1 and result.emergency_recovery_quotes[0].from == -2 and result.emergency_recovery_quotes[0].to == -1 and result.emergency_recovery_quotes[0].cost_expc == 2000 and result.unresolved_policies.is_empty(),"Negative permanent recovery now quotes exactly one owner-priced point.")
			else:
				check(result.emergency_recovery_quotes.is_empty() and result.unresolved_policies.is_empty(),"Negative temporary penalties cannot be purchased away.")
			check(Evaluator.evaluate(context) == result and context == before,"Signed evaluations must remain deterministic and nonmutating.")
		var positive := fixture()
		positive.life_before = "dead"
		positive.before.permanent[attribute] = 0
		positive.before.effective[attribute] = 0
		positive.after.permanent[attribute] = 0
		positive.after.effective[attribute] = 2
		positive.change_kind = "temporary"
		var lifted := Evaluator.evaluate(positive)
		check(lifted.success and lifted.life_after == "dead" and lifted.resurrection_barriers.is_empty() and not lifted.resurrection_performed,"Valid positive effective modifier lifts barrier without resurrection.")
		var expired := positive.duplicate(true)
		expired.before = positive.after.duplicate(true)
		expired.after = positive.before.duplicate(true)
		expired.change_kind = "effect_expiration"
		var barred := Evaluator.evaluate(expired)
		check(barred.success and barred.life_after == "dead" and not barred.death_transition and barred.resurrection_barriers.has(attribute),"Explicit expiration can reinstate a barrier while the character stays dead.")
		expired.life_before = "living" # Explicitly supplied prior successful resurrection; evaluator does not perform it.
		check(Evaluator.evaluate(expired).death_transition,"A living actor loses positive protection and dies when effective value reaches zero.")
		var recovered := fixture()
		recovered.life_before = "dead"
		recovered.change_kind = "effect_expiration"
		recovered.before.effective[attribute] = -1
		var relief := Evaluator.evaluate(recovered)
		check(relief.success and relief.life_after == "dead" and relief.resurrection_barriers.is_empty(),"An expired penalty removes the barrier without auto-revival.")
	var multiple := fixture()
	for attribute: String in ["str","end","wis"]: multiple.after.effective[attribute] = -1
	multiple.change_kind = "temporary"
	var result := Evaluator.evaluate(multiple)
	check(result.success and result.death_transition and result.resurrection_barriers == ["str","end","wis"] and result.expc_spent == 0,"Simultaneous nonpositive primaries produce one death-transition finding and all barriers deterministically.")
	for attribute: String in ["spd","dex","luk","app","man"]:
		var context := fixture()
		context.after.effective[attribute] = -2
		check(not Evaluator.evaluate(context).death_transition,"Nonlethal negative primaries must not inherit a lethal threshold.")
	var malformed := fixture()
	malformed.change_kind = "effect_expiration"
	malformed.after.permanent.wis = 9
	check(not Evaluator.evaluate(malformed).success,"Expiration snapshots cannot silently rewrite permanent attributes.")

func _test_recovery_pricing() -> void:
	for attribute: String in Evaluator.DEAD_AT_ZERO:
		for score: int in [-5,-4,-3,-2,-1,0]:
			var context := fixture()
			context.life_before = "dead"
			context.before.permanent[attribute] = score
			context.before.effective[attribute] = score
			context.after = context.before.duplicate(true)
			var preserved := context.duplicate(true)
			var result := Evaluator.evaluate(context)
			var quote: Dictionary = result.emergency_recovery_quotes[0]
			check(result.success and quote.from == score and quote.to == score+1 and quote.cost_expc == 2000 and quote.attribute_layer == "permanent","Each independent -5 through 0 starting score costs exactly2000 for one permanent point.")
			check(result.life_after == "dead" and result.resurrection_barriers == [attribute] and result.expc_spent == 0 and not result.resurrection_performed,"A quote cannot buy, revive or remove a current barrier.")
			context.available_expc = 1999
			check(not Evaluator.evaluate(context).emergency_recovery_quotes[0].affordable,"Every negative step checks affordability separately.")
			context.available_expc = 2000
			check(context == preserved and result == Evaluator.evaluate(context),"Pricing preserves inputs and deterministic evaluation.")
	var modified := fixture()
	modified.life_before = "dead"
	modified.before.permanent.wis = -3
	modified.before.effective.wis = 2
	modified.after = modified.before.duplicate(true)
	var result := Evaluator.evaluate(modified)
	check(result.emergency_recovery_quotes[0].from == -3 and result.resurrection_barriers.is_empty() and result.life_after == "dead","Positive effective value lifts eligibility barrier but does not rewrite permanent pricing or revive.")
