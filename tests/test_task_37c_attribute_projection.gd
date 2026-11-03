extends RefCounted

const AttributeView = preload("res://scripts/combat/character_attribute_projection.gd")
const SOURCE := "res://docs/audits/TASK_37C_VERIFIED_SOURCE_CATALOG.json"
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func run() -> Array[String]:
	_test_independent_source()
	_test_actors_and_purity()
	_test_incomplete_and_invalid()
	return failures

func _test_independent_source() -> void:
	var text := FileAccess.get_file_as_string(SOURCE)
	var hash_text := FileAccess.get_file_as_string(SOURCE.replace(".json",".sha256")).split(" ")[0]
	check(text.sha256_text() == hash_text,"Independent source catalog checksum.")
	if text.is_empty() or text.sha256_text() != hash_text: return
	var source: Dictionary = JSON.parse_string(text)
	var comparisons := 0
	for mode: String in ["mana","regular"]:
		for row: Dictionary in source.charts[mode]:
			var actor := {"actor_id":"source_fixture","attributes":{},"base_combat_stats":{},"combat_stats":{}}
			for primary: String in ["STR","END","SPD","DEX","WIS","INT","WIT","MAN","LUK","APP"]:
				actor.attributes[primary.to_lower()] = int(row.score)
			var result := AttributeView.project(actor,mode)
			check(result.success,"All verified source scores must project without granting them.")
			if not result.success: continue
			for primary: String in row.cells:
				var expected: String = row.cells[primary]
				var actual: Dictionary = result.primaries[primary].chart_reference
				check(actual.printed_cell.replace(" ","") == expected.replace(" ","").replace("\n","") and actual.printed_page == row.printed_page,"Projected source cell/page mismatch: %s/%s/%s" % [mode,row.score,primary])
				comparisons += 1
				var ids: Variant = source.component_order[primary]
				if ids is Dictionary: ids = ids[mode]
				var tokens := expected.replace("ACC = ","").replace("\n","").replace(" ","").replace("+","-").split("-")
				for i in range(ids.size()):
					var ref: Dictionary = result.derived[ids[i]].chart_reference
					var wanted := {"kind":"dead"} if expected == "DEAD" else ({"kind":"unlimited"} if tokens[i] == "*" else {"kind":"integer","value":int(tokens[i])})
					check(ref == wanted,"Projected derived component must match independent source: "+String(ids[i]))
			check(result.derived.AP.chart_reference.kind == "allocation_required" and result.derived.DT.chart_reference.kind == "allocation_required","Never construct MAN/DEX allocations from chart score.")
			check(result.derived.ToF.entitlement_status == "unresolved_no_grants" and not result.grants_entitlements,"Luck references are not spendable grants.")
			check(result.derived.has("MR/H") == (mode == "mana") and result.derived.has("MNS") == (mode == "mana") and result.derived.has("MRF") == (mode == "regular"),"Mana/Regular descriptors stay distinct.")
	check(comparisons == 648,"AttributeView must cover all 648 independently verified source cells.")
	print("37C projection: %d independent printed cells and their source components checked." % comparisons)

func _test_actors_and_purity() -> void:
	var actors: Array[CombatActorDefinition] = [PrimeV3VerticalSliceFixture.make_player_actor(&"vaelis_thorn"),
		PrimeV3VerticalSliceFixture.make_player_actor(PrimeV3VerticalSliceFixture.PLAYER_CHARACTER_GUARD),
		CommonGoblinFixture.make_actor(&"goblin_projection","Authored Goblin")]
	for actor: CombatActorDefinition in actors:
		var sim := CombatSimulation.new(37)
		sim.register_actor(actor)
		var state := sim.get_actor_state(actor.actor_id)
		state.current_hpc = -3
		if state.resources.has("mana"): state.resources.mana = 7
		state.persistent_damage_shields = {"test_shield":{"remaining":11,"capacity":20}}
		var before := sim.get_state_snapshot()
		var draws := sim.random.get_draw_count()
		var input := actor.to_dictionary()
		var input_before := input.duplicate(true)
		var state_input := state.to_dictionary()
		var state_before := state_input.duplicate(true)
		var supplied := {"dt":-2,"dp":-3,"sr":4}
		var annotations := {"NAL":"Authored racial/source exception; descriptive only"}
		var result := AttributeView.project_actor(actor,state,"mana",supplied,annotations)
		check(result.success,"Existing player/NPC must project: "+String(actor.actor_id))
		if not result.success: continue
		check(result == AttributeView.project(input,"mana",state_input,supplied,annotations),"Typed and dictionary paths must agree.")
		check(result == AttributeView.project_actor(actor,state,"mana",supplied,annotations),"Repeated projections must be deterministic.")
		check(result.identity.actor_id == String(actor.actor_id),"Identity must not be rewritten.")
		print("37C authored comparison %s: %s" % [actor.actor_id,result.differences])
		check(result.derived.DT.effective.value == -2 and result.derived.DP.effective.value == -3,"Signed supplied effective Dodge remains separate.")
		check(result.derived.NAL.authored_exception == annotations.NAL,"Preserve explicit exception annotation without applying it.")
		check(result.derived.AP.authoritative_base.kind == "unavailable","Ability Points must not masquerade as MAN Aggressive Persuasion.")
		check(result.resources.hpc.current.value == -3 and result.resources.damage_shields.test_shield.remaining == 11,"Keep current HPC and separate Shield protection exactly.")
		check(result.resistances.SR.descriptor.governing_primary == null and result.resistances.TB.descriptor.name == "Tolerance Bonus","SR/TB independent and exact terminology.")
		check(result.resistances.SR.effective.value == 4,"Caller-supplied effective resistance remains distinct from stored value.")
		result.source_provenance["test"] = "changed copy"
		result.resources.damage_shields.test_shield.remaining = 999
		result.primaries.STR.chart_reference.values.SB["value"] = 999
		check(input == input_before and state_input == state_before and supplied.dt == -2 and annotations.size() == 1,"No source dictionary mutation.")
		check(sim.get_state_snapshot() == before and sim.random.get_draw_count() == draws,"Inspection cannot change simulation schema, actors, RNG, events, equipment or resources.")
		check(before.schema_version == 12,"Snapshot schema remains 12.")
		var regular := AttributeView.project_actor(actor,state,"regular")
		check(regular.success and regular.derived.has("MRF") and not regular.derived.has("MNS"),"Authored actors can be inspected with explicit Regular reference without being reclassified.")
	# Test an explicit numeric mismatch without 'correcting' its source.
	var source_actor := actors[0].to_dictionary()
	source_actor.base_combat_stats.sb = 99
	source_actor.combat_stats.sb = 99
	var mismatch := AttributeView.project(source_actor,"mana")
	check(mismatch.derived.SB.comparison == "different" and mismatch.derived.SB.authoritative_base.value == 99 and mismatch.derived.SB.chart_reference.value == 2,"Mismatch must preserve both 99 authored SB and STR9 chart SB2.")
	check(mismatch.differences.has({"stat":"SB","authoritative_base":99,"chart_reference":2}),"Explicit mismatch list contains compared layer and values.")
	var matched := AttributeView.project(actors[0].to_dictionary(),"mana")
	check(matched.derived.SB.comparison == "match","Vaelis STR9/SB2 match without requiring all NPC stats to match.")
	for split: Array in [[6,3],[3,6]]:
		var allocation := CharacterDevelopment.create(9,split[0],split[1])
		var state := {"actor_id":source_actor.actor_id,"progression":{"development":allocation.record}}
		var allocated_actor := source_actor.duplicate(true)
		allocated_actor.base_combat_stats.dt = split[0]
		allocated_actor.base_combat_stats.dp = split[1]
		var projected := AttributeView.project(allocated_actor,"mana",state)
		check(projected.success and projected.derived.DT.allocated.value == split[0] and projected.derived.DP.allocated.value == split[1],"Preserve validated current and legacy allocations without resetting or inventing them.")

func _test_incomplete_and_invalid() -> void:
	var actor := {"actor_id":"partial","attributes":{"str":9},"combat_stats":{"sb":5}}
	var input := actor.duplicate(true)
	var result := AttributeView.project(actor,"mana")
	check(result.success and not result.complete and result.primaries.END.stored.kind == "unavailable","Partial data stays inspectable with explicit missing primaries, no guessed defaults.")
	check(result.derived.SB.authoritative_base.kind == "unavailable" and result.derived.SB.stored_calculated.value == 5 and result.derived.SB.comparison == "unavailable","Do not guess base values from calculated stats.")
	check(result.derived.MR.chart_reference.kind == "unavailable" and result.derived.MR.effective.kind == "unavailable","Missing primary/derived/effective values stay unavailable.")
	check(result.resistances.TB.stored_calculated.kind == "unavailable" and actor == input,"No missing TB default or source mutation.")
	check(not AttributeView.project(actor,"").success and not AttributeView.project(actor,"unknown").success,"Mode must be explicit and supported.")
	check(not AttributeView.project({},"mana").success and not AttributeView.project({"actor_id":"x"},"mana").success,"Missing identity/attribute container fails closed.")
	for score: Variant in [-1,36,9.0,"9",true]:
		var invalid := actor.duplicate(true)
		invalid.attributes.str = score
		check(not AttributeView.project(invalid,"mana").success,"Unsupported primary score/type must reject rather than extrapolate.")
	var invalid := actor.duplicate(true)
	invalid.attributes.con = 10
	check(not AttributeView.project(invalid,"mana").success,"No CON substitution.")
	invalid = actor.duplicate(true)
	invalid.combat_stats.sb = "5"
	check(not AttributeView.project(invalid,"mana").success,"Noninteger derived data fails closed.")
	check(not AttributeView.project(actor,"mana",{"actor_id":"other"}).success,"Mismatched state identity fails closed.")
	check(not AttributeView.project(actor,"mana",{}, {"dt":1.0}).success,"Effective values must be explicit integers.")
	check(not AttributeView.project(actor,"mana",{"actor_id":"partial","progression":{"development":{}}}).success,"Invalid development cannot be shown as confirmed allocations.")
	var dev := CharacterDevelopment.create(10,6,4)
	check(not AttributeView.project(actor,"mana",{"actor_id":"partial","progression":{"development":dev.record}}).success,"Unrelated allocation cannot be attached to an actor.")
	var inconsistent := actor.duplicate(true)
	inconsistent.attributes.dex = 9
	inconsistent.base_combat_stats = {"dt":9,"dp":0}
	dev = CharacterDevelopment.create(9,6,3)
	check(not AttributeView.project(inconsistent,"mana",{"actor_id":"partial","progression":{"development":dev.record}}).success,"Recorded split cannot silently override a conflicting authoritative base.")
	var twin_a := CombatSimulation.new(37)
	var twin_b := CombatSimulation.new(37)
	for sim: CombatSimulation in [twin_a,twin_b]: sim.register_actor(PrimeV3VerticalSliceFixture.make_player_actor(&"vaelis_thorn"))
	var observed := AttributeView.project_actor(twin_a.get_actor_definition(&"player"),twin_a.get_actor_state(&"player"),"mana")
	check(observed.success and twin_a.get_state_snapshot() == twin_b.get_state_snapshot(),"AttributeView on one client cannot diverge same-seed authoritative snapshots.")
