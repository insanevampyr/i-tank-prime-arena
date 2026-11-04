extends RefCounted

const Shadow = preload("res://scripts/combat/attribute_shadow_comparison.gd")
const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
const ProfileTests = preload("res://tests/test_character_profile_projection.gd")
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func run() -> Array[String]:
	_test_classification()
	_test_rejections()
	_test_persistence_and_growth()
	for character: StringName in [Fixture.PLAYER_CHARACTER_GUARD,Fixture.PLAYER_CHARACTER_VAELIS]:
		var ordinary := _combat_case(character,false)
		var observed := _combat_case(character,true)
		check(ordinary == observed,"Shadow enabled/disabled must retain identical movement, attacks, defenses, damage, event order, RNG and digests: "+String(character))
		check(observed == _combat_case(character,true),"Same-seed shadow capture must replay identically.")
	return failures

func _capture_unchanged(sim: CombatSimulation, modes: Dictionary, exceptions: Dictionary = {}) -> Dictionary:
	var before := sim.get_state_snapshot()
	var events := sim.get_resolved_events().map(func(event: CombatEvent) -> Dictionary: return event.to_dictionary())
	var rng := sim.random.to_dictionary()
	var report := Shadow.capture(sim,modes,exceptions)
	check(sim.get_state_snapshot() == before and sim.random.to_dictionary() == rng,"Boundary capture must not mutate complete state or RNG.")
	check(events == sim.get_resolved_events().map(func(event: CombatEvent) -> Dictionary: return event.to_dictionary()),"Capture must not emit/reorder events.")
	return report

func _test_classification() -> void:
	var sim := CombatSimulation.new(37)
	var vaelis := Fixture.make_player_actor(Fixture.PLAYER_CHARACTER_VAELIS)
	var guard := Fixture.make_player_actor(Fixture.PLAYER_CHARACTER_GUARD)
	guard.actor_id = &"guard"
	sim.register_actor(vaelis)
	sim.register_actor(guard)
	sim.register_actor(CommonGoblinFixture.make_actor(&"goblin","Authored Goblin"))
	var modes := {"player":"mana","guard":"regular","goblin":"regular"}
	var exceptions := {"guard":{"NAL":"PRIME-V3 p.336 authored Guard NAL1"},"goblin":{"SB":"Common Goblin authored combat row SB0"}}
	var report := _capture_unchanged(sim,modes,exceptions)
	check(report.success,"Real player/NPC source-backed fixtures must support shadow capture.")
	if not report.success: return
	check(report.actors.guard.comparisons.NAL.classification == "authored_exception" and report.actors.guard.comparisons.NAL.authoritative_base.value == 1 and report.actors.guard.comparisons.NAL.chart_reference.value == 2,"Guard NAL1/chart2 must remain an explicitly annotated exception.")
	check(report.actors.goblin.comparisons.SB.classification == "authored_exception" and report.actors.goblin.comparisons.SB.authoritative_base.value == 0 and report.actors.goblin.comparisons.SB.chart_reference.value == 1,"Goblin SB0/chart1 must stay unchanged.")
	check(report.actors.player.comparisons.SB.classification == "match","Vaelis base SB matches STR9.")
	check(report.actors.player.comparisons.DT.classification == "not_numeric_comparable","DEX pool must not fabricate a DT chart target.")
	check(report.actors.player.comparisons.PPG.classification == "unavailable","Missing PPG must not be populated from reference.")
	check(report.actors.player.resistances.SR.chart_reference == null and report.actors.player.resistances.TB.descriptor.name == "Tolerance Bonus","SR/TB remain independent from chart-derived combat stats.")
	var unannotated := _capture_unchanged(sim,modes)
	check(unannotated.actors.goblin.comparisons.SB.classification == "mismatch" and not unannotated.actors.goblin.comparisons.SB.automatic_gameplay_defect,"An unannotated difference is not automatically a defect.")
	check(report == Shadow.capture(sim,{"goblin":"regular","guard":"regular","player":"mana"},exceptions),"Actor order and repeated captures must be deterministic.")
	report.actors.player.resources.hpc.current.value = 999
	check(sim.get_actor_state(&"player").current_hpc != 999,"Report mutation cannot affect actors.")
	# Existing separate equipment and direct-effect layers must remain visible.
	guard.apply_equipment_stat_modifiers({"mr":-2,"dt":-3,"dp":-4})
	sim.get_actor_state(&"guard").timed_stat_effects["source_qualified_bonus"] = {"stat_modifiers":{"sb":2,"dt":-5},"source_ref":"isolated direct-stat fixture"}
	var modified := _capture_unchanged(sim,modes,exceptions)
	check(modified.actors.guard.comparisons.MR.authoritative_base.value == guard.base_combat_stats.mr and modified.actors.guard.comparisons.MR.equipment_modifier.value == -2,"Compare base MR independently from equipment penalty.")
	check(modified.actors.guard.comparisons.SB.effective.value == guard.combat_stats.sb+2 and modified.actors.guard.layers.temporary_effects.has("source_qualified_bonus"),"Keep direct SB effects separate from permanent STR reference.")
	sim.get_actor_state(&"guard").timed_stat_effects.clear()
	check(_capture_unchanged(sim,modes).actors.guard.comparisons.SB.effective.value == guard.combat_stats.sb,"Expired effects must not become permanent chart deltas.")
	var start := Time.get_ticks_usec()
	for index in range(10): Shadow.capture(sim,modes,exceptions)
	print("37C shadow diagnostic: 3 actors x10 explicit captures = %d us total (native headless; not browser frame timing)." % (Time.get_ticks_usec()-start))
	var legacy := Shadow.compare_legacy_lookups()
	check(legacy.comparison_count == 192,"All supported STR/DEX scalar helper comparisons must be recorded.")
	for row: Dictionary in legacy.comparisons: check(row.classification == "match","Old/new helper discrepancy: "+str(row))

func _test_rejections() -> void:
	check(not Shadow.capture(null,{"x":"mana"}).success,"No absent simulation fallback.")
	var sim := CombatSimulation.new(37)
	var actor := Fixture.make_player_actor(Fixture.PLAYER_CHARACTER_VAELIS)
	sim.register_actor(actor)
	check(not _capture_unchanged(sim,{"player":""}).success,"No guessed chart mode.")
	check(not _capture_unchanged(sim,{"absent":"mana"}).success,"No absent actor fallback.")
	actor.field_sources.erase("attributes")
	check(_capture_unchanged(sim,{"player":"mana"}).reason.begins_with("source_provenance_unavailable"),"Missing provenance must stop that diagnostic, not guess origin.")
	actor.field_sources["attributes"] = "isolated source"
	actor.attributes.erase("wis")
	check(_capture_unchanged(sim,{"player":"mana"}).reason.begins_with("source_attribute_unavailable"),"Missing primary must stop instead of deriving a default SS.")
	actor.attributes["wis"] = 10
	actor.base_combat_stats.erase("ss")
	actor.combat_stats.erase("ss")
	var partial := _capture_unchanged(sim,{"player":"mana"})
	check(partial.success and partial.actors.player.comparisons.SS.classification == "unavailable","Missing derived value is reported; chart cannot substitute for it.")
	sim.get_actor_state(&"player").timed_stat_effects["malformed"] = {"stat_modifiers":1}
	check(_capture_unchanged(sim,{"player":"mana"}).reason == "invalid_temporary_effect","Malformed diagnostic inputs must fail before calling an effective-stat consumer.")
	sim.get_actor_state(&"player").timed_stat_effects.clear()
	var too_many := {}
	for index in range(Shadow.MAX_ACTORS+1): too_many[str(index)] = "mana"
	check(not _capture_unchanged(sim,too_many).success,"Diagnostic actor work is bounded.")
	for index in range(Shadow.MAX_EFFECTS+1): sim.get_actor_state(&"player").timed_stat_effects[str(index)] = {}
	check(_capture_unchanged(sim,{"player":"mana"}).reason == "diagnostic_record_budget","Large effect collections fail closed without per-tick work.")

func _test_persistence_and_growth() -> void:
	# Reuse isolated leveled/purchased/damaged-shield save fixture; no file writes.
	var helper := ProfileTests.new()
	var f := helper._fixture()
	var sim: CombatSimulation = f.sim
	var actor := sim.get_actor_definition(&"player")
	var state := sim.get_actor_state(&"player")
	var before := CharacterProfileProjection.project(f.source,actor,state,f.ledger.to_dictionary(),f.defense,f.verifier)
	check(before.success,"Existing isolated save projection must validate.")
	var report := _capture_unchanged(sim,{"player":"mana"})
	check(report.success and report.actors.player.resources.hpc.current.value == 3 and report.actors.player.resources.mana.current.value == 1,"Growth/purchase shadow preserves expended resources.")
	check(report.actors.player.layers.defense_profile == f.defense.to_dictionary(),"Damaged shield and defense source remain separate from chart values.")
	var after := CharacterProfileProjection.project(f.source,actor,state,f.ledger.to_dictionary(),f.defense,f.verifier)
	check(before == after and CharacterSaveContract.encode(before.payload) == CharacterSaveContract.encode(after.payload),"Shadow must not change save projection, receipts, history, shield SHP or canonical envelope.")
	check(helper._failures.is_empty(),"Existing profile fixture remains valid.")

func _combat_case(character: StringName, shadow: bool) -> Dictionary:
	var session := ArenaCombatSession.new(37,null,Fixture.ENCOUNTER_MEDIUM_GUARDS,character)
	session.set_opponent_behavior_enabled(false)
	check(session.initialize(Vector2i(20_000_000,7_000_000),Vector2i(23_000_000,7_000_000)).success,"Real combat session must initialize.")
	var modes := {"player":"mana" if character == Fixture.PLAYER_CHARACTER_VAELIS else "regular","opponent":"regular"}
	var captures := 0
	if shadow:
		check(_capture_unchanged(session.simulation,modes).success,"Post-initialization shadow boundary.")
		captures += 1
	var movement := session.request_player_movement(Vector2i(21_000_000,7_000_000),10)
	check(movement.get("success",false),"Real authoritative movement must execute.")
	for index in range(4):
		var target := session.simulation.get_actor_state(&"opponent")
		session.request_player_movement(target.position_microfeet-Vector2i(1_000_000,0),10)
		check(session.request_player_attack("shadow_comparison_fixture").get("success",false),"Real attack declaration must succeed.")
		session.advance_by(6_000_000)
	if shadow:
		check(_capture_unchanged(session.simulation,modes).success,"Completed test-step shadow boundary.")
		captures += 1
	check(captures == (2 if shadow else 0),"No evaluation inside attack/movement/tick loop.")
	var defense_events := 0
	for event: CombatEvent in session.simulation.get_resolved_events():
		if event.event_type == &"physical_defense_started": defense_events += 1
	check(defense_events > 0,"Scenario must exercise actual defense resolution, not only initialization.")
	var harness := TwoClientSyncHarness.new(37)
	harness.authority.simulation = session.simulation
	harness.deliver_in_order(harness.authority.publish_current_events())
	check(harness.compare_clients().success and harness.client_a.get_state_digest() == harness.authority.get_state_digest(),"Shadow-observed combat must retain authoritative two-client digest agreement.")
	check(session.simulation.get_state_snapshot().schema_version == 12,"Schema12 remains unchanged.")
	return {"snapshot":session.get_state_snapshot(),"movement":movement,"digest":harness.authority.get_state_digest()}
