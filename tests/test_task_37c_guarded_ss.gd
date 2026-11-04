extends RefCounted

const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
const ForceTests = preload("res://tests/test_vaelis_force_magic.gd")
const BossTests = preload("res://tests/test_task_35g_rare_human_warrior_potions_and_combat.gd")
const Boss = preload("res://scripts/creatures/rare_human_warrior_fixture.gd")
const Rules = preload("res://scripts/combat/prime_v3_attribute_engine.gd")
const SOURCE := "res://docs/audits/TASK_37C_VERIFIED_SOURCE_CATALOG.json"
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

static func legacy_get(actor: CombatActorDefinition, field: String) -> Variant:
	if not actor.combat_stats.has(field): return null
	return actor.combat_stats[field]

func run() -> Array[String]:
	var text := FileAccess.get_file_as_string(SOURCE)
	check(text.sha256_text() == FileAccess.get_file_as_string(SOURCE.replace(".json",".sha256")).split(" ")[0],"Independent source catalog checksum.")
	var source: Dictionary = JSON.parse_string(text)
	var comparisons := 0
	var dead_references := 0
	for mode: String in ["mana","regular"]:
		for row: Dictionary in source.charts[mode]:
			var actor := Fixture.make_player_actor(Fixture.PLAYER_CHARACTER_VAELIS)
			actor.attributes["wis"] = int(row.score)
			actor.progression_policy["resource_mode"] = "mana" if mode == "mana" else "ability"
			var reference := Rules.lookup("WIS",int(row.score),mode)
			if row.cells.WIS == "DEAD":
				check(reference.values.SS == {"kind":"dead"},"WIS0 must retain its printed DEAD tag, never become numeric SS0.")
				actor.combat_stats["ss"] = 11
				var unchanged := actor.to_dictionary()
				check(actor.get_combat_stat("ss") == 11 and actor.to_dictionary() == unchanged,"Nonnumeric reference must preserve stored SS without applying death or recalculation.")
				comparisons += 1
				dead_references += 1
				continue
			var expected := int(String(row.cells.WIS).replace(" ","").split("-")[0])
			check(reference.values.SS == {"kind":"integer","value":expected},"Engine SS must independently match the frozen source, not merely pass the stored-value fallback.")
			check(reference.values.SS == Rules.lookup("WIS",int(row.score),"mana").values.SS,"Canonical SS reference must agree across both modes at every score.")
			actor.combat_stats["ss"] = expected
			var before := actor.to_dictionary()
			check(typeof(actor.get_combat_stat("ss")) == TYPE_INT and actor.get_combat_stat("ss") == expected and actor.get_combat_stat("ss") == legacy_get(actor,"ss"),"Guarded SS must equal source/stored integer in both modes.")
			check(actor.to_dictionary() == before,"Lookup must not write authoritative stats or source snapshots.")
			actor.combat_stats["ss"] = expected+1
			check(actor.get_combat_stat("ss") == expected+1,"Authored mismatch must never be corrected from WIS.")
			comparisons += 1
	check(comparisons == 72,"All 72 SS references must be checked.")
	check(dead_references == 2,"Both modes include WIS0 DEAD; the other 70 SS references are numeric.")
	_test_fallbacks()
	check(replay_case() == replay_case(),"Same-seed casts, ability actions, event sequences, RNG and digests must replay identically.")
	print("37C guarded SS: 72 source references (70 numeric, 2 DEAD), authored mismatches, exact Variant fallbacks and cast replay checked.")
	return failures

func _test_fallbacks() -> void:
	var actor := Fixture.make_player_actor(Fixture.PLAYER_CHARACTER_VAELIS)
	for value: Variant in [-1,0,9,99,9.0,"9",true,null,{},[],&"nine"]:
		actor.combat_stats["ss"] = value
		var actual: Variant = actor.get_combat_stat("ss")
		check(typeof(actual) == typeof(value) and actual == legacy_get(actor,"ss"),"Every stored SS Variant/type must retain its original contract.")
	actor.combat_stats.erase("ss")
	check(actor.get_combat_stat("ss") == null and not actor.combat_stats.has("ss"),"Missing SS cannot be inferred from WIS.")
	actor.combat_stats["ss"] = 9
	for wisdom: Variant in [null,-1,36,10.0,"10",true,{},[]]:
		actor.attributes["wis"] = wisdom
		check(actor.get_combat_stat("ss") == 9 and actor.get_combat_stat("acc") == legacy_get(actor,"acc"),"Malformed/unsupported WIS and unrelated getters preserve stored values.")
	actor.attributes.erase("wis")
	check(actor.get_combat_stat("ss") == 9,"Missing permanent WIS retains SS.")
	actor.attributes["wis"] = 10
	actor.field_sources.erase("attributes")
	check(actor.get_combat_stat("ss") == 9,"Missing WIS provenance retains stored SS.")
	actor.field_sources["attributes"] = "source-qualified fixture"
	actor.unresolved_fields.append("attributes.wis")
	check(actor.get_combat_stat("ss") == 9,"Unresolved permanent WIS retains stored SS.")
	actor.unresolved_fields.clear()
	var sim := CombatSimulation.new(37)
	sim.register_actor(actor)
	var state := sim.get_actor_state(actor.actor_id)
	state.timed_stat_effects["temporary_wis"] = {"stat_modifiers":{"wis":20,"ss":3,"acc":2}}
	state.resources.mana = 1
	var before := sim.get_state_snapshot()
	check(actor.get_combat_stat("ss") == 9,"SS getter cannot infer or apply temporary WIS or direct modifiers.")
	check(sim.get_effective_actor_combat_stat(actor.actor_id,"ss") == 12,"Existing separate effective-stat layer keeps its direct SS modifier.")
	check(sim.get_state_snapshot() == before,"Getter/effective reads must preserve resources, RNG, events, schema and conditions.")
	state.timed_stat_effects.clear()
	check(actor.get_combat_stat("ss") == 9,"Temporary expiration alone cannot rewrite base SS.")

func replay_case() -> Dictionary:
	var helper := ForceTests.new()
	var reports: Array = []
	for seed_value in [1,2,3,4]:
		var session := helper._session(seed_value,Vector2i(22_000_000,12_000_000))
		session.set_opponent_behavior_enabled(false)
		session.simulation.set_actor_defense_state(Fixture.OPPONENT_ID,&"unaware",PackedStringArray())
		check(session.request_player_special(VaelisForceFixture.FORCE_SHIELD_ID).success,"Force Shield must use the existing legal action pipeline.")
		session.advance_by(5_000_000)
		check(session.request_player_special(VaelisForceFixture.FORCE_BOLT_ID).success,"Force Bolt must use the existing NAC pipeline.")
		var harness := TwoClientSyncHarness.new(seed_value)
		harness.authority.simulation = session.simulation
		harness.deliver_in_order(harness.authority.publish_current_events())
		check(harness.compare_clients().success and harness.client_a.get_state_digest() == harness.authority.get_state_digest(),"Force casts must retain two-client convergence.")
		reports.append({"snapshot":session.get_state_snapshot(),"digest":harness.authority.get_state_digest()})
	var boss_helper := BossTests.new()
	var setup: Dictionary = boss_helper._boss_and_target_simulation(37)
	var sim: CombatSimulation = setup.simulation
	var action := sim.start_verified_special_action(setup.actor_id,&"target",Boss.make_called_shot_action_definition(),"ss_boundary_boss",&"head",true)
	check(action.success,"Boss Ability activation remains legal without introducing an SS roll.")
	var started := sim.get_action(action.action_instance_id)
	sim.advance_to(started.final_effect_due_at_us)
	reports.append({"boss":sim.get_state_snapshot()})
	return {"cases":reports}
