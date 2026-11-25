extends RefCounted
const Recovery = preload("res://scripts/combat/arena_mana_recovery.gd")
const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
const Historical = preload("res://tests/test_historical_vaelis_admission.gd")
var failures: Array[String] = []
var assertions := 0
func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok: failures.append(message)
func fixture(wisdom: int = 10) -> Dictionary:
	var sim := CombatSimulation.new(45046)
	var actor := Fixture.make_player_actor(Fixture.PLAYER_CHARACTER_VAELIS)
	actor.attributes.wis = wisdom
	sim.register_actor(actor)
	sim.begin_combat()
	sim.mana_recovery_enabled = true
	var state := sim.get_actor_state(&"player")
	state.resources.mana = 0
	return {"sim":sim,"actor":actor,"state":state}
func run() -> Array[String]:
	for wisdom in range(1,21):
		var f := fixture(wisdom)
		var rng: Dictionary = f.sim.random.wave_entry_state()
		f.sim.advance_to(120000000)
		check(f.state.resources.mana == wisdom and f.state.progression.get("mana_recovery_units",0) == 0,"WIS1-20 recovers exactly WIS Mana in two active minutes: %s" % wisdom)
		check(f.sim.random.wave_entry_state() == rng,"Recovery adds no RNG draws.")
		var first := Recovery.step(0,100,wisdom,0,59999999)
		check(first.current == (wisdom*59999999)/120000000 and first.units == (wisdom*59999999)%120000000,"Integer fractions are retained, never rounded to a Mana grant.")
	var f := fixture(10)
	f.sim.advance_to(11999999)
	check(f.state.resources.mana == 0 and f.state.progression.mana_recovery_units == 119999990,"No premature whole Mana.")
	f.sim.advance_to(12000000)
	check(f.state.resources.mana == 1 and f.state.progression.mana_recovery_units == 0,"Exact twelve-second boundary at WIS10.")
	f.sim.mana_recovery_enabled = false
	f.sim.advance_to(72000000)
	check(f.state.resources.mana == 1,"Paused recovery never catches up using elapsed stopped/menu time.")
	f.sim.mana_recovery_enabled = true
	f.sim.advance_to(84000000)
	check(f.state.resources.mana == 2,"Only new eligible time resumes recovery.")
	f = fixture(3)
	f.sim.advance_to(20000000)
	f.state.timed_stat_effects["wis_control"] = {"stat_modifiers":{"wis":4},"expires_at_us":30000000}
	f.sim.advance_to(40000000)
	check(f.state.resources.mana == 1 and f.state.progression.mana_recovery_units == 40000000,"Effective WIS changes and expiry apply prospectively to their own intervals.")
	f = fixture(20)
	f.state.resources.mana = 19
	f.state.progression.mana_recovery_units = 119999999
	f.sim.advance_to(60000000)
	check(f.state.resources.mana == 20 and f.state.progression.mana_recovery_units == 0,"Maximum saturation discards excess fractions; no banked refill exploit.")
	f.state.resources.mana = 19
	f.sim.advance_to(60000001)
	check(f.state.resources.mana == 19,"Spending after saturation cannot release banked recovery.")
	check(not Recovery.step(0,20,10,-1,1).success and not Recovery.step(0,20,10,120000000,1).success,"Malformed remainder is rejected.")
	var first_award := fixture(10)
	first_award.sim.advance_to(1000000)
	check(first_award.sim.apply_character_experience_award(&"player","first_award",0,0,0).success and first_award.state.progression.mana_recovery_units == 10000000 and first_award.state.progression.has("award_ids"),"First legitimate XP accounting initializes after recovery without losing its fraction.")
	var invalid_award := fixture(10)
	invalid_award.state.progression["mana_recovery_units"] = -1
	check(invalid_award.sim.apply_character_experience_award(&"player","invalid_remainder",0,0,0).get("reason") == "invalid_mana_recovery_state","First-award initialization never admits malformed recovery evidence.")
	check(replay() == replay(),"Seeded recovery history/RNG/snapshots replay identically.")
	ui_and_persistence()
	print("45D Mana recovery: %d assertions." % assertions)
	return failures
func replay() -> Dictionary:
	var f := fixture(7)
	f.sim.advance_to(45000000)
	var sync := TwoClientSyncHarness.new(45046)
	sync.authority.simulation = f.sim
	sync.deliver_in_order(sync.authority.publish_current_events())
	var events: Array = f.sim.get_resolved_events()
	check(sync.compare_clients().success and sync.client_a.get_state_snapshot() == f.sim.get_state_snapshot(),"Recovery resources and fractional progression converge in simulated clients.")
	return {"snapshot":f.sim.get_state_snapshot(),"rng":f.sim.random.wave_entry_state(),"events":events.map(func(e): return e.to_dictionary())}
func ui_and_persistence() -> void:
	var h := Historical.new()
	var scene := h.helper._scene()
	var c: ArenaCombatController = scene.get_node("CombatController")
	c.set_physics_process(false)
	check(c.select_player_character_for_testing(Fixture.PLAYER_CHARACTER_VAELIS).success,"Real Vaelis UI.")
	var session := c._session
	var state := session.get_actor_state(&"player")
	state.resources.mana = 0
	session.advance_by(60000000)
	check(state.resources.mana == 0,"READY never recovers.")
	session.set_opponent_behavior_enabled(false)
	check(session.start_encounter().success,"Active wave starts.")
	c._advance_session_with_attack_hold(12000000)
	check(state.resources.mana == 1,"Real session uses active simulation time.")
	c.open_character_sheet()
	c._advance_session_with_attack_hold(12000000)
	check(state.resources.mana == 1,"Character Sheet pauses only passive recovery; no free recovery during menus.")
	var model := CharacterSheetProjection.capture(session)
	var row: Dictionary = model.derived.filter(func(r): return r.id == "MR/Min")[0]
	var msl: Dictionary = model.derived.filter(func(r): return r.id == "MSL")[0]
	check(row.original == 5 and row.permanent == 5 and row.effective == 5 and msl.original == 3 and msl.permanent == 3 and msl.effective == 3,"MSL uses verified WIS10 chart value3; Arena recovery has its own label/formula.")
	var definition := session.simulation.get_actor_definition(&"player")
	var original_source := definition.source_character_definition
	definition.source_character_definition = original_source.duplicate(true)
	definition.source_character_definition.combat_stats["msl"] = 77
	definition.base_combat_stats["msl"] = 88
	definition.apply_equipment_stat_modifiers(definition.equipment_stat_modifiers)
	var authored: Dictionary = CharacterSheetProjection.capture(session).derived.filter(func(r): return r.id == "MSL")[0]
	check(authored.original == 77 and authored.permanent == 88 and authored.effective == 88,"Explicit authored MSL is preserved ahead of chart references.")
	definition.source_character_definition = original_source
	definition.base_combat_stats.erase("msl")
	definition.apply_equipment_stat_modifiers(definition.equipment_stat_modifiers)
	state.timed_stat_effects["wis_ui"] = {"stat_modifiers":{"wis":1}}
	model = CharacterSheetProjection.capture(session)
	row = model.derived.filter(func(r): return r.id == "MR/Min")[0]
	check(row.effective == 5.5 and CharacterSheetProjection.show_value(row.effective).contains("5.5"),"Effective half-points are displayed without rounding.")
	c._character_sheet.close_sheet()
	c._on_inventory_toggle_pressed()
	c._advance_session_with_attack_hold(10000000)
	check(state.resources.mana == 1,"Character Menu does not recover Mana.")
	h.helper._free(scene)
	PlayableCharacterPersistence.test_nonpersistent = false
	h.root = OS.get_cache_dir().path_join("itank-storage-tests/mana45d_%s_%s" % [OS.get_process_id(),Time.get_ticks_usec()])
	var f := h.make_history("dev_normal","3df0412b72ba5d966b2eb645887fedfbb591782cffc7bff41c192e52583c6d20",4,"fraction")
	check(f.get("success",false),"Disposable historical V4 fixture.")
	if f.get("success",false):
		PlayableCharacterPersistence.test_storage = f.storage
		scene = h.web.make_scene(); c = scene.get_node("CombatController")
		check(c._admit_existing_profile("dev_normal").success,"Admit isolated profile.")
		c._run_choice_dialog.get_ok_button().pressed.emit()
		session = c._session; state = session.get_actor_state(&"player")
		state.resources.mana = 2
		state.progression["mana_recovery_units"] = 60000000
		session._authorized_entry_write = true
		var committed := session._playable_persistence.checkpoint(session,session._playable_persistence.recovery.phase)
		session._authorized_entry_write = false
		check(committed.success,"Bounded fraction publishes in the existing checkpoint, without a new envelope version: %s" % [committed])
		var saved: Dictionary = CharacterSaveContract.decode(CharacterSaveContract.encode(session._playable_persistence._prior).text).payload
		check(saved.recovery.player.mana_recovery_units == 60000000,"Fraction has durable integer evidence.")
		var backup := CharacterBackupReader.new().begin_export(session._playable_persistence)
		check(backup.success and CharacterBackupContract.decode(backup.text,"dev_normal").success,"Complete fractional-history backup validates.")
		var destination := CharacterSaveStorage.new(h.root.path_join("restored_fraction"))
		var restoration := CharacterBackupRestoration.new()
		check(restoration.begin(backup.text,"dev_normal",null,destination).success and restoration.confirm().success,"Fractional V4 history restores only in disposable storage.")
		restoration.dispose()
		check(CharacterSaveStorage.history_records(destination.inspect_profile(f.profile)) == backup.history,"Restoration keeps complete byte-exact history and fractional state.")
		var corrupt: Dictionary = saved.recovery.duplicate(true)
		corrupt.player.mana_recovery_units = 120000000
		check(not CharacterWaveCheckpoint.validate(corrupt,session.simulation.get_actor_definition(&"player")).success,"Out-of-range fraction fails closed.")
		h.helper._free(scene)
		scene = h.web.make_scene(); c = scene.get_node("CombatController")
		check(c._admit_existing_profile("dev_normal").success,"Reload fractional checkpoint.")
		c._run_choice_dialog.get_ok_button().pressed.emit()
		state = c._session.get_actor_state(&"player")
		check(state.resources.mana == 2 and state.progression.mana_recovery_units == 60000000 and c._session._playable_persistence._prior == saved,"RESUME restores exact fraction/current Mana with no loading grant: %s / %s / %s" % [state.resources,state.progression.get("mana_recovery_units"),c._session._playable_persistence._prior == saved])
		c._session.advance_by(60000000)
		check(state.resources.mana == 2 and state.progression.mana_recovery_units == 60000000,"Inactive checkpoint time/reload does not duplicate recovery.")
		# Existing V5 accounting adds no EXPM or Mana and preserves this fraction.
		var Credit = preload("res://scripts/rewards/character_expc_credit.gd")
		var credit := Credit.prepare(saved,func(binding): return {"confirmed":true,"binding":Credit.digest(binding)})
		var prepared := CharacterPersistenceCoordinator.prepare(credit.payload,credit.payload.settlements,credit.transaction_id,saved.generation,saved.secured_checkpoints)
		var verifier := func(_op,binding): return {"authorized":true,"binding":binding,"lineage":credit.payload.lineage}
		check(CharacterPersistenceCoordinator.new(f.storage).commit(prepared.prepared,session._playable_persistence.source,f.profile,PlayableCharacterAdmission.RULES,verifier).success,"Disposable V5 credit coexists with fractional checkpoints.")
		h.helper._free(scene)
		scene = h.web.make_scene(); c = scene.get_node("CombatController")
		check(c._admit_existing_profile("dev_normal").success,"V5 fractional history reloads.")
		c._run_choice_dialog.get_ok_button().pressed.emit()
		session = c._session; state = session.get_actor_state(&"player")
		check(state.resources.mana == 2 and state.progression.mana_recovery_units == 60000000 and session._playable_persistence._prior.xp.earned == saved.xp.earned,"V5 readback preserves current Mana/fraction and EXPM.")
		check(session.request_next_wave().success,"NEXT WAVE carries the committed fractional profile.")
		state = session.get_actor_state(&"player")
		check(state.progression.mana_recovery_units == 60000000,"Wave transition retains the remainder independently of resource restoration.")
		state.resources.mana = 2 # Disposable partial-resource control after entry capture.
		session.set_opponent_behavior_enabled(false)
		check(session.is_encounter_active(),"NEXT WAVE already starts the eligible active simulation.")
		session.advance_by(6000000)
		check(state.resources.mana == 3 and state.progression.mana_recovery_units == 0,"Retained half-Mana completes only after six new active seconds at WIS10.")
		state.current_hpc = 0; session.advance_by(1)
		c._on_encounter_button_pressed()
		check(c._session.get_encounter_state() == ArenaCombatSession.ENCOUNTER_READY and c._session.get_actor_state(&"player").progression.mana_recovery_units == 60000000,"RETRY restores the verified entry, not elapsed discarded-attempt recovery.")
		h.helper._free(scene)
		scene = h.web.make_scene(); c = scene.get_node("CombatController")
		check(c._admit_existing_profile("dev_normal").success,"An unfinished run remains explicit on reload.")
		var prior: Dictionary = c._session._playable_persistence._prior.duplicate(true)
		c._ask_abandon_loaded_run()
		PlayableCharacterPersistence.test_run_id = "mana_recovery_new_run"
		c._abandon_run_dialog.get_ok_button().pressed.emit()
		var next: Dictionary = c._session._playable_persistence._prior
		check(next.recovery.run_id != prior.recovery.run_id and next.xp == prior.xp and next.permanent == prior.permanent and next.recovery.player.mana_recovery_units == 60000000,"NEW RUN preserves committed history/fraction without awarding XP or replaying Mana recovery.")
		h.helper._free(scene)
		var Backend = preload("res://tests/test_playable_browser_persistence.gd").Backend
		var backend := Backend.new()
		backend.histories[f.profile] = CharacterSaveStorage.history_records(f.storage.inspect_profile(f.profile))
		var count: int = backend.histories[f.profile].size()
		PlayableBrowserPersistence.test_factory = func(): return CharacterBrowserStorage.new(backend.transport)
		scene = h.web.make_scene(); c = scene.get_node("CombatController")
		c._admit_existing_profile("dev_normal"); h.web.pump(c)
		c._run_choice_dialog.get_ok_button().pressed.emit()
		check(c._session.get_actor_state(&"player").progression.mana_recovery_units == 60000000 and backend.histories[f.profile].size() == count,"Simulated Web admission preserves V5 fraction without creating a generation or recovery grant.")
		h.helper._free(scene)
		PlayableBrowserPersistence.test_factory = Callable()
	h.helper._remove_fixture(h.root)
	PlayableCharacterPersistence.test_nonpersistent = true
	PlayableCharacterPersistence.test_storage = null
	PlayableCharacterPersistence.test_run_id = ""
