extends RefCounted

const Profiles = preload("res://scripts/rewards/character_profile_projection.gd")
const Credit = preload("res://scripts/rewards/character_expc_credit.gd")
var failures: Array[String] = []
var assertions := 0

func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok: failures.append(message)

# Frozen authorized historical baseline + isolated V5 credit permits a funded
# level-one fixture without fabricated EXPM or a production wallet mutation.
func history(steps: Array) -> Dictionary:
	var starter := PlayableCharacterAdmission.prepare_starter(&"vaelis_thorn","dev_normal",Credit.BASELINE)
	var source: CombatCharacterDefinitionResource = starter.source
	var actor: CombatActorDefinition = source.instantiate_actor(&"player",source.display_name,PackedStringArray(starter.prepared.payload.permanent.equipment_refs))
	var sim := CombatSimulation.new(44001)
	sim.register_actor(actor)
	var state := sim.get_actor_state(&"player")
	state.resources.mana = 2
	state.progression = {"exp_type":8,"level":1,"expm":0,"expc":10000,"run_earned_xp":0,"run_spent_xp":0,"expc_credit_total":10000,"award_ids":[],"history":[],"base_hpm":actor.get_combat_stat("hpm"),"base_resource_maxima":source.resource_maxima.duplicate(true)}
	var payload: Dictionary = starter.prepared.payload.duplicate(true)
	payload.generation = 2
	payload["expc_credits"] = {"version":1,"records":[{"grant_id":Credit.GRANT_ID,"profile_id":Credit.PROFILE,"amount":10000,"after_generation":1,"head_digest":Credit.digest(starter.prepared.payload)}]}
	var earned := 0
	var spent := 0
	for step: String in steps:
		if step == "buy":
			var before: int = actor.attributes.wis
			var cost: int = 3000 if before <= 10 else 5000
			check(actor.apply_verified_wisdom_advancement(before,before+1).success,"Replay fixture uses legal source-backed purchase.")
			spent += cost
			state.progression.run_spent_xp = spent
			state.progression.expc = 10000+earned-spent
			payload.purchases.append({"purchase_id":"dev_vaelis_thorn/starter_admission/wis_%d" % before,"purchase_kind":"attribute","target_id":"wis","value_before":before,"value_after":before+1,"cost":cost,"source_ref":PrimeV3AdvancementCatalog.PURCHASE_SOURCE_REF})
		else:
			var level: int = state.progression.level+1
			var target: int = PrimeV3LevelCatalog.threshold(8,level)
			var award := "award_%d" % level
			check(sim.apply_character_experience_award(&"player",award,target-earned,target,spent).success,"Event-time fixture level gain remains legal.")
			payload.permanent.award_receipts.append({"award_id":"dev_vaelis_thorn/starter_admission/"+award,"xp":target-earned})
			earned = target
	payload.xp = {"earned":earned,"spent":spent,"unspent":10000+earned-spent}
	payload.permanent.xp_baseline = {"expm":0,"expc":0,"earned":earned,"spent":spent}
	payload.permanent.level = state.progression.level
	payload.permanent.resource_maxima = actor.resource_maxima.duplicate(true)
	payload.permanent.growth = []
	for record: Dictionary in state.progression.history:
		var row := {"growth_id":"dev_vaelis_thorn/starter_admission/level_%d" % record.level}
		for field: String in Profiles.HISTORY_FIELDS: row[field] = record[field]
		payload.permanent.growth.append(row)
	var verifier := func(_op: String,binding: String) -> Dictionary: return {"authorized":true,"binding":binding,"lineage":payload.lineage}
	return {"payload":payload,"source":source,"verifier":verifier,"actor":actor,"state":state,"sim":sim}

func hydrate(f: Dictionary, payload: Dictionary = {}) -> Dictionary:
	return Profiles.hydrate(f.payload if payload.is_empty() else payload,f.source,Credit.PROFILE,PlayableCharacterAdmission.RULES,f.verifier)

func run() -> Array[String]:
	# Independent expected maxima: starting20; level gains10 at WIS10/11,
	# 11 at WIS12; every purchase adds1, never to current Mana.
	var cases := [
		{"steps":["buy","level"],"mana":31,"wisdom":[11]},
		{"steps":["level","buy"],"mana":31,"wisdom":[10]},
		{"steps":["buy","level","buy","level"],"mana":43,"wisdom":[11,12]},
		{"steps":["level","buy","level","buy","level"],"mana":53,"wisdom":[10,11,12]},
		{"steps":["buy"],"mana":21,"wisdom":[]},
	]
	for c: Dictionary in cases:
		var f := history(c.steps)
		var before: Dictionary = f.payload.duplicate(true)
		var result := hydrate(f)
		check(result.success,"Recorded chronology hydrates: %s / %s" % [c.steps,result])
		if result.success:
			check(result.actor_definition.resource_maxima.mana == c.mana,"Independent event-time Mana total: %s" % [c.steps])
			check(result.actor_definition.to_dictionary() == hydrate(f).actor_definition.to_dictionary(),"Repeated hydration is deterministic.")
			check(PrimeV3LevelCatalog.validate(result.actor_definition.progression_policy,result.actor_definition).is_empty(),"Level-one purchased Mana is not a malformed starting profile.")
		check(f.payload.permanent.growth.map(func(g): return g.wisdom) == c.wisdom,"Original event-time inputs remain exact.")
		check(f.payload == before and f.state.resources.mana == 2 and f.source.attributes.wis == 10,"No input, current Mana or authored starting WIS mutation.")
		var encoded := CharacterSaveContract.encode(f.payload)
		check(encoded.success and CharacterSaveContract.decode(encoded.text).payload == before,"V5 roundtrip preserves every original record.")
	var f := history(["level","buy","level","buy","level"])
	for kind: String in ["missing_purchase","missing_wisdom","wrong_wisdom","wrong_maximum","changed_cost","decreased_wisdom","reordered_purchases","duplicate_purchase"]:
		var bad: Dictionary = f.payload.duplicate(true)
		match kind:
			"missing_purchase": bad.purchases.pop_back()
			"missing_wisdom": bad.permanent.growth[0].erase("wisdom")
			"wrong_wisdom": bad.permanent.growth[0].wisdom = 11
			"wrong_maximum": bad.permanent.growth[1].maximum_before += 1
			"changed_cost": bad.purchases[0].cost += 1
			"decreased_wisdom": bad.permanent.growth[2].wisdom = 10
			"reordered_purchases": bad.purchases.reverse()
			"duplicate_purchase": bad.purchases.append(bad.purchases[0].duplicate(true))
		check(not hydrate(f,bad).success,"Reject unproven/inconsistent chronology: "+kind)
	# A plausible alternate arithmetic history cannot replace an already
	# committed prefix. Use the existing coordinator, not a new authority.
	var rewritten: Dictionary = f.payload.duplicate(true)
	rewritten.generation += 1
	rewritten.permanent.growth[0].wisdom = 11
	rewritten.permanent.growth[0].maximum_before += 1
	rewritten.permanent.growth[0].maximum_after += 1
	check(not CharacterPersistenceCoordinator._validate_continuity(f.payload,rewritten).success,"Even arithmetically plausible historical reassignment violates immutable generation history.")
	var legacy := history(["level","level","level","level","level","level","level","buy","level"])
	legacy.payload.erase("expc_credits")
	legacy.payload.xp.unspent -= 10000
	var v2 := CharacterSaveContract.encode(legacy.payload)
	check(v2.success and CharacterSaveContract.decode(v2.text).version == 2 and hydrate(legacy).success,"Uncredited V2 event-time WIS history remains valid without any migration.")
	print("44B historical Mana replay: %d assertions." % assertions)
	return failures
