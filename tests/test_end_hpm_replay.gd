extends RefCounted

const Mana = preload("res://tests/test_wisdom_mana_replay.gd")
const Profiles = preload("res://scripts/rewards/character_profile_projection.gd")
const Credit = preload("res://scripts/rewards/character_expc_credit.gd")
var failures: Array[String] = []
var assertions := 0

func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok: failures.append(message)

# Independent temporal fixture. The pre-existing isolated V5 baseline gives
# spendable EXPC at level1 without inventing earned XP or touching owner data.
func history(steps: Array) -> Dictionary:
	var f := Mana.new().history([])
	var current: Dictionary = f.payload.duplicate(true)
	var proof := {}
	var snapshots: Array = [current.duplicate(true)]
	var proofs: Array = [{}]
	var costs := 0
	var earned := 0
	for step: String in steps:
		var previous: Dictionary = current.duplicate(true)
		current.generation += 1
		var hpm: int = f.actor.get_combat_stat("hpm")
		var hpc: int = f.state.current_hpc
		if step in ["end","wis"]:
			var value: int = f.actor.attributes[step]
			var price := 3000 if value <= 10 else 5000
			var applied: Dictionary = f.actor.apply_verified_endurance_advancement(value,value+1) if step == "end" else f.actor.apply_verified_wisdom_advancement(value,value+1)
			check(applied.success,"Isolated source-qualified attribute step: "+step)
			costs += price
			f.state.progression.run_spent_xp = costs
			f.state.progression.expc = 10000+earned-costs
			current.purchases.append({"purchase_id":"dev_vaelis_thorn/starter_admission/%s_%d" % [step,value],"purchase_kind":"attribute","target_id":step,"value_before":value,"value_after":value+1,"cost":price,"source_ref":PrimeV3AdvancementCatalog.PURCHASE_SOURCE_REF})
			check(f.actor.get_combat_stat("hpm") == hpm and f.state.current_hpc == hpc,"END/WIS purchasing cannot alter HPM/HPC.")
		else:
			var level: int = f.state.progression.level+1
			var target: int = PrimeV3LevelCatalog.threshold(8,level)
			var award := "end_level_%d" % level
			check(f.sim.apply_character_experience_award(&"player",award,target-earned,target,costs).success,"A legitimate level uses current HPB and permanent WIS.")
			current.permanent.award_receipts.append({"award_id":"dev_vaelis_thorn/starter_admission/"+award,"xp":target-earned})
			earned = target
		current.xp = {"earned":earned,"spent":costs,"unspent":10000+earned-costs}
		current.permanent.xp_baseline = {"expm":0,"expc":0,"earned":earned,"spent":costs}
		current.permanent.resource_maxima = f.actor.resource_maxima.duplicate(true)
		current.permanent.level = f.state.progression.level
		current.permanent.growth = []
		for record: Dictionary in f.state.progression.history:
			var row := {"growth_id":"dev_vaelis_thorn/starter_admission/end_level_%d" % record.level}
			for field: String in Profiles.HISTORY_FIELDS: row[field] = record[field]
			current.permanent.growth.append(row)
		if EnduranceGrowthHistory.has_purchases(current):
			proof = EnduranceGrowthHistory.extend(f.source,current,previous,proof)
			check(proof.success,"Generation-bound END proof: %s" % proof)
		var bound: Dictionary = proof.duplicate(true)
		var verifier := func(_op: String,binding: String): return {"authorized":true,"binding":binding,"lineage":current.lineage,"endurance_history":bound}
		var result := Profiles.hydrate(current,f.source,Credit.PROFILE,PlayableCharacterAdmission.RULES,verifier)
		check(result.success,"Every intermediate generation hydrates without a migration: %s" % result)
		if result.success:
			check(result.actor_definition.get_combat_stat("hpm") == f.actor.get_combat_stat("hpm") and result.actor_definition.attributes.end == f.actor.attributes.end,"Replayed HPM/END equal authoritative event-time results.")
		snapshots.append(current.duplicate(true)); proofs.append(proof.duplicate(true))
	f.payload = current
	f["snapshots"] = snapshots
	f["proofs"] = proofs
	return f

func run() -> Array[String]:
	var cases := [
		{"steps":["end","level"],"ends":[7],"hpb":[1]},
		{"steps":["level","end","end","level"],"ends":[6,8],"hpb":[1,2]},
		{"steps":["end","end","level"],"ends":[8],"hpb":[2]},
		{"steps":["end","level","end","level"],"ends":[7,8],"hpb":[1,2]},
		{"steps":["level","wis","end","level","end","level"],"ends":[6,7,8],"hpb":[1,1,2]},
	]
	for c: Dictionary in cases:
		var f := history(c.steps)
		var proof: Dictionary = f.proofs.back()
		var rows: Array = f.payload.permanent.growth
		check(rows.map(func(row): return row.hpb) == c.hpb,"Independent expected historical HPB sequence.")
		check(rows.map(func(row): return proof.growth[row.growth_id].end) == c.ends,"Plateau END is known from first-appearance generation, never inferred from HPB.")
		var expected := 9
		for index in range(rows.size()):
			check(rows[index].hit_die_sides == 6 and rows[index].die_flat_bonus == 0,"END does not change class Hit Dice.")
			expected += int(rows[index].roll)+int(c.hpb[index])
		check(f.actor.get_combat_stat("hpm") == expected and f.source.combat_stats.hpm == 9 and f.source.attributes.end == 6,"Starting HPM/END are immutable; no retrospective HPB or HD reroll.")
		var encoded := CharacterSaveContract.encode(f.payload)
		check(encoded.success and CharacterSaveContract.decode(encoded.text).payload == f.payload,"Existing V5 serializes exactly; no chronology field added.")
	var f := history(["end","level","end","level"])
	var previous: Dictionary = f.snapshots[3]
	var final: Dictionary = f.snapshots[4]
	var prior: Dictionary = f.proofs[3]
	for kind: String in ["stale","gap","old_hpb","future_hpb","missing_head","wrong_head","identity","duplicate","reordered"]:
		var bad := final.duplicate(true)
		var evidence := prior.duplicate(true)
		match kind:
			"stale": bad.generation -= 1
			"gap": bad.generation += 1
			"old_hpb": bad.permanent.growth[0].hpb = 2
			"future_hpb": bad.permanent.growth.back().hpb = 1
			"missing_head": evidence = {}
			"wrong_head": evidence.head_digest = "0".repeat(64)
			"identity": bad.character_id = "prod_vaelis_thorn"
			"duplicate": bad.purchases.append(bad.purchases[0].duplicate(true))
			"reordered": bad.purchases.reverse()
		check(not EnduranceGrowthHistory.extend(f.source,bad,previous,evidence).success,"Reject unsupported generation evidence: "+kind)
	var combined: Dictionary = f.snapshots[2].duplicate(true)
	combined.generation = f.snapshots[0].generation+1
	check(EnduranceGrowthHistory.extend(f.source,combined,f.snapshots[0]).get("reason") == "end_purchase_growth_same_generation_ambiguous","Never invent within-generation order, even when HPB is on a plateau.")
	var no_proof := func(_op: String,binding: String): return {"authorized":true,"binding":binding,"lineage":final.lineage}
	check(Profiles.hydrate(final,f.source,Credit.PROFILE,PlayableCharacterAdmission.RULES,no_proof).get("reason") == "end_generation_history_unavailable","A standalone latest document cannot manufacture its missing generation proof.")
	print("45B generation-backed HPB replay: %d assertions." % assertions)
	return failures
