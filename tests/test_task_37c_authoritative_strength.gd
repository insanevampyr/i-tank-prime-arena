extends RefCounted

const Strength = preload("res://scripts/combat/prime_v3_strength_chart.gd")
const Rules = preload("res://scripts/combat/prime_v3_attribute_engine.gd")
const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
const SOURCE := "res://docs/audits/TASK_37C_VERIFIED_SOURCE_CATALOG.json"
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

# Exact previous implementation at 19ac972; its frozen ROWS remain in the helper.
# Rollback is replacement of derived()'s body with these three statements.
static func legacy_derived(strength: int) -> Dictionary:
	if strength < 1 or strength > Strength.ROWS.size(): return {"success":false,"reason":"strength_chart_or_mortal_limit_unverified"}
	var row: Array = Strength.ROWS[strength-1]
	return {"success":true,"sb":row[0],"ppg":row[1],"mwc":row[2]}

func run() -> Array[String]:
	var source_text := FileAccess.get_file_as_string(SOURCE)
	check(source_text.sha256_text() == FileAccess.get_file_as_string(SOURCE.replace(".json",".sha256")).split(" ")[0],"Independent source snapshot must retain its checksum.")
	var source: Dictionary = JSON.parse_string(source_text)
	var comparisons := 0
	for mode: String in ["mana","regular"]:
		for score in range(1,21):
			var previous := legacy_derived(score)
			var actual := Strength.derived(score)
			check(actual == previous,"Entire old/new STR return contract differs at "+str(score))
			var raw: String = source.charts[mode][score].cells.STR
			var parts := raw.replace(" ","").split("-")
			var ref: Dictionary = Rules.lookup("STR",score,mode).values
			var fields := ["sb","ppg","mwc"]
			for index in range(fields.size()):
				check(typeof(actual[fields[index]]) == TYPE_INT and actual[fields[index]] == int(parts[index]) and actual[fields[index]] == ref[fields[index].to_upper()].value,"STR scalar must match independent book fixture and both chart modes.")
				comparisons += 1
	check(comparisons == 120,"All sixty supported STR components must match each of the two modes.")
	for invalid: int in [-9223372036854775807,-100,-1,0,21,25,26,35,36,100,9223372036854775807]:
		check(Strength.derived(invalid) == legacy_derived(invalid),"Invalid integer/range rejection must remain byte-for-byte compatible.")
	var method: Dictionary = {}
	for entry: Dictionary in (load("res://scripts/combat/prime_v3_strength_chart.gd") as Script).get_script_method_list():
		if entry.name == "derived": method = entry
	check(not method.is_empty() and method.args.size() == 1 and method.args[0].type == TYPE_INT and method.return.type == TYPE_DICTIONARY,"Public argument/return types must remain int -> Dictionary.")
	var changed := Strength.derived(9)
	changed.sb = 999
	check(Strength.derived(9).sb == 2 and legacy_derived(9).sb == 2,"Returned values cannot mutate old or new chart sources.")
	_test_application()
	_test_authored_exceptions()
	print("37C authoritative STR: 120 source scalar comparisons; old/new dictionaries, invalid integer boundaries and unchanged typed interface checked.")
	return failures

func _test_application() -> void:
	var actor := Fixture.make_player_actor(Fixture.PLAYER_CHARACTER_VAELIS)
	actor.attributes.str = 11
	var previous := legacy_derived(11)
	for field: String in ["sb","ppg","mwc"]: actor.base_combat_stats[field] = previous[field]
	actor.apply_equipment_stat_modifiers(actor.equipment_stat_modifiers)
	var expected := Fixture.make_player_actor(Fixture.PLAYER_CHARACTER_VAELIS)
	expected.attributes.str = 12
	var after := legacy_derived(12)
	for field: String in ["sb","ppg","mwc"]: expected.base_combat_stats[field] = after[field]
	expected.apply_equipment_stat_modifiers(expected.equipment_stat_modifiers)
	var sim := CombatSimulation.new(37)
	sim.register_actor(actor)
	var state := sim.get_actor_state(actor.actor_id)
	state.current_hpc = 3
	state.resources.mana = 1
	state.conditions.append("prone")
	state.timed_stat_effects["independent_bonus"] = {"stat_modifiers":{"sb":2}}
	var before := state.to_dictionary()
	var rng := sim.random.to_dictionary()
	var events := sim.get_resolved_event_count()
	var applied := actor.apply_verified_strength_advancement(11,12)
	check(applied.success and actor.to_dictionary() == expected.to_dictionary(),"Existing authoritative STR application must equal the actor built with old chart results, including SB threshold.")
	check(applied.derived_before == previous and applied.derived_after == after,"Public advancement payload must retain old chart values/shape.")
	check(state.to_dictionary() == before and sim.random.to_dictionary() == rng and sim.get_resolved_event_count() == events,"Lookup replacement must preserve expended resources, conditions, ownership, temporary effects, RNG and events.")
	check(sim.get_effective_actor_combat_stat(actor.actor_id,"sb") == 5,"Existing temporary SB remains additive after permanent SB3; no modifier-order change.")

func _test_authored_exceptions() -> void:
	for actor: CombatActorDefinition in [Fixture.make_player_actor(Fixture.PLAYER_CHARACTER_GUARD),CommonGoblinFixture.make_actor(&"goblin","Authored Goblin")]:
		var before := actor.to_dictionary()
		for score in range(1,21): Strength.derived(score)
		check(actor.to_dictionary() == before,"Lookup must never recalculate or overwrite authored NPC identity/statistics.")
		if actor.actor_id == &"goblin": check(actor.combat_stats.sb == 0 and Strength.derived(int(actor.attributes.str)).sb == 1,"Goblin SB0 remains an authored exception to chart SB1.")
		else: check(actor.combat_stats.nal == 1,"Guard authored NAL remains unchanged.")
