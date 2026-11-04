extends RefCounted

const Dex = preload("res://scripts/combat/prime_v3_dex_chart.gd")
const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
const SOURCE := "res://docs/audits/TASK_37C_VERIFIED_SOURCE_CATALOG.json"
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

# Exact implementation at 51bd02e; frozen ACC remains available for rollback.
static func legacy_accuracy(effective_dex: int, chart: String) -> Variant:
	if chart not in ["mana","regular"] or effective_dex < 0 or effective_dex >= Dex.ACC.size(): return null
	return Dex.ACC[effective_dex]

static func legacy_allocation_result(state: Dictionary, mode: String) -> Dictionary:
	var result := DexAllocation.contributions(state)
	if not result.success: return result
	var accuracy: Variant = legacy_accuracy(result.permanent_dex+result.temporary_dex,mode)
	if accuracy == null: return {"success":false,"reason":"effective_dex_chart_unverified"}
	result["acc"] = accuracy
	return result

func run() -> Array[String]:
	var text := FileAccess.get_file_as_string(SOURCE)
	check(text.sha256_text() == FileAccess.get_file_as_string(SOURCE.replace(".json",".sha256")).split(" ")[0],"Independent numerical source snapshot checksum must validate.")
	var source: Dictionary = JSON.parse_string(text)
	var comparisons := 0
	for mode: String in ["mana","regular"]:
		for score in range(36):
			var value: Variant = Dex.accuracy(score,mode)
			var expected := int(String(source.charts[mode][score].cells.DEX).replace(" ","").replace("ACC=",""))
			check(typeof(value) == TYPE_INT and value == legacy_accuracy(score,mode) and value == expected,"DEX ACC must equal previous integer and independent source value at %s/%s." % [mode,score])
			var allocation: Dictionary = DexAllocation.create(score,score,0).state
			var before := allocation.duplicate(true)
			check(DexAllocation.derived(allocation,mode) == legacy_allocation_result(allocation,mode),"Entire allocation consumer dictionary must retain its old values and shape.")
			check(allocation == before,"ACC lookup must not allocate or redistribute points.")
			comparisons += 1
		for invalid: int in [-9223372036854775807,-100,-1,36,100,9223372036854775807]:
			check(Dex.accuracy(invalid,mode) == legacy_accuracy(invalid,mode) and Dex.accuracy(invalid,mode) == null,"Unsupported integer scores must keep null rejection.")
	for invalid_mode: String in ["","Mana","REGULAR","unknown"," mana"]:
		for score in [-1,0,9,35,36]:
			check(Dex.accuracy(score,invalid_mode) == legacy_accuracy(score,invalid_mode) and Dex.accuracy(score,invalid_mode) == null,"Invalid chart modes must not default or normalize.")
	var current := _method(Dex,"accuracy")
	var previous := _method(get_script(),"legacy_accuracy")
	check(current.args == previous.args and current.return == previous.return and current.flags == previous.flags,"Typed int/String -> Variant static interface must remain unchanged.")
	_test_temporary_and_recorded_allocations()
	_test_authored_values()
	check(comparisons == 72,"All 36 scores in both modes must be compared.")
	print("37C authoritative DEX ACC: %d source/legacy comparisons plus complete consumer dictionaries, mode/range rejection and unchanged typed interface." % comparisons)
	return failures

func _method(script: Script, name: String) -> Dictionary:
	for entry: Dictionary in script.get_script_method_list():
		if entry.name == name: return entry
	return {}

func _test_temporary_and_recorded_allocations() -> void:
	for split: Array in [[6,3],[3,6]]:
		var allocation: Dictionary = DexAllocation.create(9,split[0],split[1]).state
		var active := DexAllocation.request(allocation,{"op":"activate","source":"verified_source","activation":"activation_one","points":2})
		check(active.success,"Existing positive temporary DEX fixture must activate legally.")
		var before: Dictionary = active.state.duplicate(true)
		for mode: String in ["mana","regular"]:
			check(DexAllocation.derived(active.state,mode) == legacy_allocation_result(active.state,mode) and active.state == before,"Current/legacy allocations, temporary contributions and histories must remain exact.")
		var expired := DexAllocation.request(active.state,{"op":"remove","source":"verified_source","activation":"activation_one"})
		check(expired.success and DexAllocation.derived(expired.state,"mana") == legacy_allocation_result(expired.state,"mana"),"Temporary removal must retain the existing allocation rules.")
	var sim := CombatSimulation.new(37)
	var actor := Fixture.make_player_actor(Fixture.PLAYER_CHARACTER_VAELIS)
	sim.register_actor(actor)
	var state := sim.get_actor_state(actor.actor_id)
	state.progression["development"] = CharacterDevelopment.create(9,6,3).record
	state.timed_stat_effects["source_one"] = {"source_action_instance_id":"fixture_activation","stat_modifiers":{"dex":2,"acc":3}}
	check(sim._sync_temporary_dex(actor.actor_id).success,"Existing temporary-Dex authority must synchronize its own record.")
	var before := sim.get_state_snapshot()
	var events := sim.get_resolved_event_count()
	check(sim.get_effective_actor_combat_stat(actor.actor_id,"acc") == int(legacy_accuracy(11,"mana"))+3,"Temporary DEX lookup must precede existing direct ACC modifier exactly as before.")
	check(sim.get_effective_actor_combat_stat(actor.actor_id,"dt") == 7 and sim.get_effective_actor_combat_stat(actor.actor_id,"dp") == 4,"Temporary Dodge contributions remain separate and unchanged.")
	check(sim.get_state_snapshot() == before and sim.get_resolved_event_count() == events,"Lookup cannot change allocation history, RNG, resources, events or schema12 state.")
	state.timed_stat_effects.clear()
	check(sim._sync_temporary_dex(actor.actor_id).success,"Existing effect-expiration authority must succeed.")
	check(sim.get_effective_actor_combat_stat(actor.actor_id,"acc") == legacy_accuracy(9,"mana") and sim.get_effective_actor_combat_stat(actor.actor_id,"dt") == 6 and sim.get_effective_actor_combat_stat(actor.actor_id,"dp") == 3,"Expiration retains base allocation and ACC without new grants.")
	var excessive: Dictionary = DexAllocation.request(DexAllocation.create(35,35,0).state,{"op":"activate","source":"source","activation":"activation","points":1}).state
	check(DexAllocation.derived(excessive,"mana") == legacy_allocation_result(excessive,"mana"),"Existing consumer must still reject effective DEX36 without clamping.")

func _test_authored_values() -> void:
	for actor: CombatActorDefinition in [Fixture.make_player_actor(Fixture.PLAYER_CHARACTER_GUARD),CommonGoblinFixture.make_actor(&"goblin","Authored Goblin")]:
		var before := actor.to_dictionary()
		for mode: String in ["mana","regular"]:
			for score in range(36): Dex.accuracy(score,mode)
		check(actor.to_dictionary() == before,"Lookup must not recalculate authored NPC ACC, identity, Dodge allocations or exceptions.")
		if actor.actor_id == &"goblin": check(actor.combat_stats.sb == 0,"Goblin authored SB0 remains untouched.")
		else: check(actor.combat_stats.nal == 1,"Guard authored NAL1 remains untouched.")
