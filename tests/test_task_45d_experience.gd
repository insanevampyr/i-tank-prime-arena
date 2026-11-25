extends RefCounted
const Sheet = preload("res://scripts/ui/character_sheet_projection.gd")
const Historical = preload("res://tests/test_historical_vaelis_admission.gd")
const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
var failures: Array[String] = []
var assertions := 0
func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok: failures.append(message)
func run() -> Array[String]:
	var actor := Fixture.make_player_actor(Fixture.PLAYER_CHARACTER_VAELIS)
	var state := CombatActorState.new(actor)
	# Independent printed EXP Type8 thresholds: Level2=97, Level3=213,
	# Level4=469. Progress subtracts the CURRENT level threshold.
	for c: Array in [[1,0,0,97,97],[1,96,96,97,1],[2,97,0,116,116],[2,155,58,116,58],[2,212,115,116,1],[3,213,0,256,256]]:
		state.progression = {"level":c[0],"exp_type":8,"expm":c[1],"expc":10000,"run_spent_xp":0}
		var before := state.to_dictionary()
		var row := Sheet.experience(actor,state)
		check(row.level == c[0] and row.within_level == c[2] and row.level_span == c[3] and row.needed == c[4],"Independent current-level threshold boundary: %s" % [c])
		check(row.ratio == float(c[2])/float(c[3]) and state.to_dictionary() == before,"Numeric/bar progress is exact and read-only.")
	state.progression = {"level":2,"exp_type":8,"expm":155,"expc":5000,"run_spent_xp":3000}
	var before := Sheet.experience(actor,state)
	state.progression.expc += 10000
	state.progression["expc_credit_total"] = 10000
	check(Sheet.experience(actor,state).ratio == 0.5 and Sheet.experience(actor,state).expm == 155,"EXPC-only credits cannot alter EXPM or progress.")
	state.progression.expc -= 3000; state.progression.run_spent_xp += 3000
	var after := Sheet.experience(actor,state)
	check(after.ratio == before.ratio and after.level == before.level and after.spent_expc == 6000,"Purchases change available/recorded spending only.")
	for p: Dictionary in [{},{"level":2,"exp_type":8,"expm":0},{"level":1,"exp_type":0,"expm":0},{"level":1,"exp_type":8,"expm":-1},{"level":21,"exp_type":8,"expm":700000}]:
		state.progression = p
		check(Sheet.experience(actor,state).ratio == null,"Missing/malformed/inconsistent progression never invents a bar.")
	state.progression = {"level":20,"exp_type":8,"expm":593328}
	var maximum := Sheet.experience(actor,state)
	check(maximum.ratio == null and maximum.needed == null and maximum.status.contains("Maximum verified level"),"No extrapolated threshold beyond the printed level20 table.")
	var credit := preload("res://tests/test_wisdom_mana_replay.gd").new().history([])
	var credited := Sheet.experience(credit.actor,credit.state)
	check(credited.expm == 0 and credited.available_expc == 10000 and credited.level == 1 and credited.ratio == 0,"Real isolated V5 credit retains level1/zero EXPM progress.")
	layout_and_profiles()
	print("45D Experience: %d assertions." % assertions)
	return failures
func layout_and_profiles() -> void:
	var h := Historical.new()
	var scene := h.helper._scene()
	var c: ArenaCombatController = scene.get_node("CombatController")
	c.set_physics_process(false)
	check(c.select_player_character_for_testing(Fixture.PLAYER_CHARACTER_VAELIS).success,"Real Character Sheet fixture.")
	check(c._session.configure_reward_mode("normal").success,"Initialize the verified progression fixture before rendering a progress bar.")
	check(c._session.simulation.apply_character_experience_award(&"player","layout_initial",0,0,0).success,"Source-verified zero award initializes this disposable nonpersistent fixture.")
	var snapshot := c._session.get_state_snapshot()
	var ledger := c._session.get_reward_state()
	c.open_character_sheet()
	for size: Vector2 in [Vector2(1280,720),Vector2(800,360)]:
		c._character_sheet._last_display = size
		c._character_sheet._render()
		var section := c._character_sheet.content.find_child("ExperienceSection",true,false)
		check(section != null and section.find_child("ExperienceProgress",true,false) != null,"Compact/desktop attributes show numeric Experience and bar: %s / %s" % [c._character_sheet.model.get("experience"),section])
		for index in range(5): c._character_sheet.select_tab(index)
		c._character_sheet.select_tab(0)
		c._character_sheet.show_help("EXPERIENCE")
		check(c._character_sheet.help_layer.visible,"Experience contextual help works.")
		c._character_sheet.handle_escape()
	check(c._session.get_state_snapshot() == snapshot and c._session.get_reward_state() == ledger,"Experience display creates no simulation events, RNG, spending or persistence.")
	h.helper._free(scene)
	PlayableCharacterPersistence.test_nonpersistent = false
	h.root = OS.get_cache_dir().path_join("itank-storage-tests/experience45d_%s_%s" % [OS.get_process_id(),Time.get_ticks_usec()])
	for mode: String in ["normal","dev_normal"]:
		var f := h.make_history(mode,"3df0412b72ba5d966b2eb645887fedfbb591782cffc7bff41c192e52583c6d20",4,mode)
		check(f.get("success",false),"Verified disposable namespace history.")
		if not f.get("success",false): continue
		PlayableCharacterPersistence.test_storage = f.storage
		scene = h.web.make_scene(); c = scene.get_node("CombatController")
		check(c._admit_existing_profile(mode).success,"Historical profile reloads for read-only Experience.")
		var service := c._session._playable_persistence
		var old: Dictionary = service._prior.duplicate(true)
		var model := Sheet.capture(c._session)
		check(model.experience.expm == f.payload.xp.earned and model.experience.available_expc == f.payload.xp.unspent and model.experience.spent_expc == f.payload.xp.spent and model.experience.ratio != null,"NORMAL/Legacy DEV display verified cumulative balances and level-local progress.")
		check(Sheet.capture(c._session) == model and service._prior == old,"Projection neither republishes nor rewrites historical profile.")
		h.helper._free(scene)
	h.helper._remove_fixture(h.root)
	PlayableCharacterPersistence.test_storage = null
	PlayableCharacterPersistence.test_nonpersistent = true
	PlayableCharacterPersistence.test_run_id = ""
