extends RefCounted
const Gate = preload("res://scripts/rewards/character_capture_gate.gd")
const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
const Player = preload("res://scripts/player/placeholder_player.gd")
const Playable = preload("res://tests/test_playable_vaelis_persistence.gd")
var failures: Array[String] = []
var assertions := 0

func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok: failures.append(label)

func fixture(enabled: bool = true, seed_value: int = 461, funds: int = 0, mode: String = "normal") -> Dictionary:
	var s := ArenaCombatSession.new(seed_value,null,Fixture.ENCOUNTER_WAVE_ONE_GOBLINS,Fixture.PLAYER_CHARACTER_VAELIS)
	s.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
	var setup := s.initialize_wave_one_goblins(Vector2i(14000000,8000000),Vector2i(17000000,8000000),false)
	check(setup.success,"Initialize genuine Vaelis wave fixture: "+str(setup))
	check(s.configure_reward_mode(mode).success,"Original reward policy")
	s._reward_ledger.earned_xp = funds # Disposable purchase-only funds; replay uses zero.
	var p := Player.new()
	p.reset_for_encounter(Vector2(14,8))
	check(p.configure_authoritative_actor_profile(s.simulation.get_actor_definition(&"player")).success,"Original source Running profile")
	s.player_movement_boundary_provider = p.capture_wave_entry_motion
	s.player_speed_profile_refresher = p.refresh_permanent_speed_profile
	s.player_endurance_profile_refresher = p.refresh_permanent_endurance_profile
	var gate := Gate.new()
	if enabled: check(gate.bind(s,p).success,"Opt-in bind all participants")
	return {"s":s,"p":p,"g":gate}

func frozen(f: Dictionary) -> Dictionary:
	return {"session":f.s.get_state_snapshot(),"ledger":f.s.get_reward_state(),"movement":f.p.capture_wave_entry_motion()}

func run() -> Array[String]:
	locks()
	movement()
	commands()
	items_and_development()
	resource_ticks_and_browser_freeze()
	persistent_boundaries()
	lifecycle()
	check(replay(true) == replay(false),"Gated versus ordinary gameplay/RNG exact")
	check(replay(true) == replay(true),"Independent same-seed simulated clients converge")
	check(replay(true,"dev_normal") == replay(false,"dev_normal"),"DEV original rewards and growth remain exact")
	print("46C1 capture gate: %d assertions; failures %s" % [assertions,str(failures)])
	return failures

func locks() -> void:
	var f := fixture(); var s: ArenaCombatSession = f.s; var p: PlaceholderPlayer = f.p; var g: RefCounted = f.g
	var before := frozen(f); var revision: int = g.revision()
	var acquired: Dictionary = g.acquire("entry")
	check(acquired.success,"Acquire only at original READY boundary")
	if not acquired.success: p.free(); return
	check(not g.acquire("entry").success,"Only one capture lease")
	check(not s.start_encounter().success,"Reject session start during capture")
	s.advance_by(1000000)
	s.simulation.advance_to(1000000)
	s.simulation.clock.advance(1000000)
	check(s.simulation.random.next_int(1,20) == 0,"No RNG draw during capture")
	check(not s.configure_player_nac_automation({"profile":"Aggressive"}).success,"Reject NAC configuration at actual mutation boundary")
	check(not s.simulation.configure_nac_automation(&"player",{}).success,"Direct simulator NAC entry also protected")
	check(not s.request_character_advancement(&"attribute",&"str","during").success,"Reject purchase before rule/ledger mutation")
	check(not s._reward_ledger.purchase_advancement(s.simulation,"during",&"attribute",&"str").success,"Direct original ledger purchase protected")
	check(not s.request_character_development("preferences",{},"during").success,"Reject development")
	check(not s.request_player_inventory_equip(&"health_potion","during").success,"Reject equipment")
	check(not s.request_player_inventory_consumable_use(&"health_potion","during").success,"Reject consumption")
	check(not s.collect_ground_loot("unknown").success,"Reject collection")
	check(not s.simulation.apply_authoritative_position(&"player",Vector2i(1000000,0),0).success,"Reject direct forced-position mutation")
	s.get_actor_state(&"player").set_position(Vector2i(1,2),90)
	check(not s.get_actor_state(&"player").spend_movement(0),"Low-level player movement mutator is also blocked")
	check(not s.simulation.get_actor_definition(&"player").apply_verified_strength_advancement(9,10).success,"Low-level permanent attribute mutator is also blocked")
	check(not CharacterLevelProgression.apply_award(s.simulation,&"player","forged_during_capture",1,1,0).success,"Direct growth entry cannot mutate during capture")
	var grant := preload("res://scripts/rewards/character_expc_grant.gd").new()
	grant._session = s
	check(not grant._published({}).success,"Fixed-credit acknowledgement cannot mutate during capture; no credit issued")
	check(p._movement.request_running() == PrimeMovementModel.RunningRequestResult.CAPTURE_BLOCKED,"Distinct capture rejection cannot fabricate a Running roll")
	check(p._movement.advance(1000000,Vector2.ZERO) == Vector2.ZERO,"Actual Running model advance blocked")
	p._physics_process(1.0)
	p.refresh_equipped_movement_rate(100)
	p.refresh_permanent_speed_profile(s.simulation.get_actor_definition(&"player"))
	p.refresh_permanent_endurance_profile(s.simulation.get_actor_definition(&"player"))
	p._movement.set_effective_end(20)
	p._movement.set_effective_spd(20)
	p.set_prone(true)
	check(not p.restore_wave_entry_motion(before.movement),"Restore/replacement blocked during capture")
	check(frozen(f) == before and g.revision() == revision,"Every rejected mutation leaves actual state, clocks, RNG and revision exact")
	var captured: Dictionary = g.collect(acquired.lease)
	check(captured.success and captured.capture.copy() == JSON.parse_string(JSON.stringify(before,"",true,true)),"Session, ledger and external movement captured as one logical state")
	check(g.is_current(captured.capture),"Issued handle has internally owned captured revision")
	var copy: Dictionary = captured.capture.copy(); copy.movement.clear()
	captured.capture._json = "forged"
	check(captured.capture.json() == JSON.stringify(before,"",true,true),"No mutable captured state or bytes escape")
	check(not g.is_current(Gate.Capture.new(captured.capture.json())),"Caller-created identical handle cannot supply internal revision")
	check(s.start_encounter().success,"Capture releases before future work; no background freeze")
	check(not g.is_current(captured.capture),"Resumed gameplay invalidates pending checkpoint")
	check(g.unbind().success,"Unbind outside mutation")
	p.free()

func movement() -> void:
	var f := fixture(); var g: RefCounted = f.g; var model: PrimeMovementModel = f.p._movement
	var run_result := model.request_running()
	check(run_result == PrimeMovementModel.RunningRequestResult.ACTIVATED,"Genuine original Running starts")
	model.advance(1000000,Vector2.RIGHT); model.stop_running()
	var captured: Dictionary = g.capture("entry")
	var before: Dictionary = model.wave_entry_state()
	model.advance(250000,Vector2.ZERO)
	check(model.wave_entry_state().state._recovery_remaining_units < before.state._recovery_remaining_units,"Zero-direction recovery still advances normally outside capture")
	check(not g.is_current(captured.capture),"Zero-direction recovery invalidates captured revision")
	check(model.wave_entry_state().rng == before.rng,"Recovery alone consumes no RNG")
	# Untrained Running explicitly exercises maintenance and separate movement RNG.
	check(g.unbind().success,"Release fixture before alternate verified Running profile")
	model.running_skill_investment = 0 # Disposable skill fixture, before rebind.
	model.skill_check_modifier = 50
	model.restore_wave_entry(model.wave_entry_state())
	model._recovery_remaining_units = 0
	model._running_retry_cooldown_us = 0
	var next := Gate.new(); check(next.bind(f.s,f.p).success,"Rebind independent gate to disposable untrained Running")
	model.request_running()
	var draws: int = model.wave_entry_state().rng.draw_count
	var c: Dictionary = next.capture("entry")
	model.advance(5000000,Vector2.RIGHT)
	check(model.wave_entry_state().rng.draw_count > draws,"Original maintenance RNG is exercised")
	check(model.get_recovery_remaining_us() > 0 and not next.is_current(c.capture),"Fatigue/maintenance invalidates pending capture")
	check(next.unbind().success,"Unbind maintenance fixture")
	f.p.free()

func commands() -> void:
	var f := fixture(true,461,60000); var s: ArenaCombatSession = f.s; var p: PlaceholderPlayer = f.p; var g: RefCounted = f.g
	for key: String in ["str","dex","spd","wis","end"]:
		var option := {}
		for row: Dictionary in s.get_character_advancement_options():
			if row.purchase_kind == "attribute" and row.target_id == key: option = row; break
		check(not option.is_empty() and option.available,"Original source-backed purchase preview "+key)
		if option.is_empty(): continue
		var captured: Dictionary = g.capture("entry")
		var before_motion: Dictionary = p.capture_wave_entry_motion()
		var selection := {}
		if key in ["dex","spd","wis","end"]: selection = {"expected_current_value":option.current_value,"expected_cost":option.cost}
		if key == "dex": selection["allocation"] = option.allocation
		var result := s.request_character_advancement(&"attribute",StringName(key),"capture_"+key,selection)
		check(result.success,"Genuine original purchase succeeds after gate release "+key+": "+str(result))
		check(not g.is_current(captured.capture),"Permanent purchase invalidates captured state "+key)
		if key == "spd": check(p.capture_wave_entry_motion().profile.spd == s.simulation.get_actor_definition(&"player").attributes.spd,"SPD external profile refreshed inside original transaction")
		if key == "end": check(p.capture_wave_entry_motion().profile.end == s.simulation.get_actor_definition(&"player").attributes.end,"END external profile refreshed inside original transaction")
		check(p.capture_wave_entry_motion().rng == before_motion.rng,"Profile refresh never resets/consumes Running RNG")
	var c: Dictionary = g.capture("entry")
	check(s.configure_player_nac_automation({"profile":"Guardian","priority":PackedStringArray(["force_shield","force_bolt"])}).success,"Original NAC priority/configuration succeeds after release")
	check(not g.is_current(c.capture),"NAC change invalidates old checkpoint")
	check(g.unbind().success,"Unbind purchase fixture")
	p.free()

func items_and_development() -> void:
	var f := fixture(false)
	var s: ArenaCombatSession = f.s
	var helper := Playable.new(); helper._defeat_wave(s)
	check(helper._failures.is_empty(),"Original combat prepares downtime fixture")
	s.get_actor_state(&"player").current_hpc = 1 # Legal wounded fixture, before opt-in binding.
	s.get_actor_state(&"player").inventory_quantities["health_potion"] = 1 # Source-defined consumable fixture, before binding; no award claimed.
	var g: RefCounted = f.g
	check(g.bind(s,f.p).success,"Bind actual wounded downtime fixture")
	var c: Dictionary = g.capture("downtime")
	check(s.collect_all_ground_loot().success and not g.is_current(c.capture),"Actual item/currency acquisition invalidates old capture")
	c = g.capture("downtime")
	var result := s.request_player_inventory_unequip(Fixture.VAELIS_WAND_REF,"gate_unequip")
	check(result.success and not g.is_current(c.capture),"Actual equipped instance moves to inventory")
	c = g.capture("downtime")
	check(s.request_player_inventory_equip(Fixture.VAELIS_WAND_REF,"gate_reequip").success and not g.is_current(c.capture),"Actual re-equip invalidates capture")
	s.request_player_weapon_handling(Fixture.VAELIS_WAND_REF,"stow","gate_stow")
	c = g.capture("downtime")
	var quantity: int = s.get_actor_state(&"player").inventory_quantities.get("health_potion",0)
	result = s.request_player_inventory_consumable_use(&"health_potion","gate_consume")
	check(result.success and not g.is_current(c.capture),"Actual original downtime healing/consumption invalidates capture: "+str(result))
	check(s.get_actor_state(&"player").inventory_quantities.get("health_potion",0) == quantity-1,"Exactly one original item consumed")
	c = g.capture("downtime")
	result = s.request_character_development("preferences",{"order":["soak","block","dodge","nac"]},"gate_preferences")
	check(result.success and not g.is_current(c.capture),"Actual persistent preference/development command: "+str(result))
	check(g.last_capture() != null and g.is_current(g.last_capture()),"Original character-change boundary captures after its resolved effects")
	check(g.unbind().success,"Unbind item/development fixture")
	f.p.free()

func resource_ticks_and_browser_freeze() -> void:
	var f := fixture(false)
	var s: ArenaCombatSession = f.s; var p: PlaceholderPlayer = f.p; var g: RefCounted = f.g
	s.set_opponent_behavior_enabled(false)
	s.get_actor_state(&"player").resources.mana = 0 # Valid current-resource fixture before binding.
	s.get_actor_state(&"player").timed_stat_effects["combat_rage"] = {"effect_id":"combat_rage","stat_modifiers":{"sb":2,"nal":-2,"dt":-1,"dp":-1},"expires_at_us":1000000}
	s.simulation.schedule_event(1000000,&"timed_stat_effect_expire_due",0,&"player",&"player",{"effect_id":"combat_rage","expected_expires_at_us":1000000})
	check(g.bind(s,p).success,"Bind real timer/resource fixture")
	var captured: Dictionary = g.capture("entry")
	var controller := ArenaCombatController.new()
	controller._player = p
	p.set_physics_process(true)
	controller._freeze_browser_motion()
	check(not p.is_physics_processing(),"Existing browser freeze disables actual player physics")
	var a: Dictionary = g.acquire("entry")
	var before := frozen(f)
	var thread := Thread.new()
	thread.start(func(): return g.acquire("entry").get("reason"))
	check(thread.wait_to_finish() == "capture_requires_main_thread","Worker-thread capture rejected before touching participants")
	thread.start(func(): return f.s.configure_player_nac_automation({"profile":"Guardian"}).get("reason"))
	check(thread.wait_to_finish() == "character_capture_in_progress" and frozen(f) == before,"Bound mutation APIs reject unsupported worker execution without changing state")
	s.simulation.advance_to(60000000)
	check(frozen(f) == before,"No timed expiry or Mana tick while capture is held")
	a.lease.cancel()
	controller._resume_browser_motion()
	check(p.is_physics_processing(),"Existing browser restore retains previous processing state")
	controller._player = null; controller.free()
	check(s.start_encounter().success,"Resume simulation immediately after short capture")
	var rng: Dictionary = s.simulation.random.wave_entry_state()
	s.advance_by(60000000)
	check(not s.get_actor_state(&"player").timed_stat_effects.has("combat_rage"),"Original timed status expiry runs after release")
	var wis: int = s.simulation.get_actor_definition(&"player").attributes.wis
	check(s.get_actor_state(&"player").resources.mana == floori(wis*0.5),"Original active-wave MR/Min advances by authoritative simulation time")
	check(s.simulation.random.wave_entry_state() == rng and not g.is_current(captured.capture),"Timed/resource ticks invalidate without new RNG draws")
	check(g.last_capture() == captured.capture,"Ordinary simulation ticks never serialize another capture")
	check(g.unbind().success,"Unbind timer fixture")
	p.free()

func persistent_boundaries() -> void:
	var prior: Array = [PlayableCharacterPersistence.test_storage,PlayableCharacterPersistence.test_run_id,PlayableCharacterPersistence.test_nonpersistent]
	PlayableCharacterPersistence.test_nonpersistent = false
	var root := OS.get_cache_dir().path_join("itank-storage-tests/capture46c1_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()])
	var q := preload("res://tests/test_compact_v6_gameplay_candidate.gd").new()
	var original: Dictionary = q.start(CharacterSaveStorage.new(root),"dev_normal",10,{},false)
	check(original.success,"Real disposable legacy service admission; compact observer disabled")
	if original.success:
		var s: ArenaCombatSession = original.session
		var p := Player.new(); p.reset_for_encounter(Vector2(14,8))
		check(p.configure_authoritative_actor_profile(s.simulation.get_actor_definition(&"player")).success and p.restore_wave_entry_motion(original.movement.wave_entry_state()),"Bind actual external player to exact admitted motion")
		s.player_movement_boundary_provider = p.capture_wave_entry_motion
		s.player_speed_profile_refresher = p.refresh_permanent_speed_profile
		s.player_endurance_profile_refresher = p.refresh_permanent_endurance_profile
		s.set_opponent_behavior_enabled(false)
		var g := Gate.new(); check(g.bind(s,p).success,"Bind original admitted service as a participant")
		var a: Dictionary = g.acquire("entry")
		check(a.success and not original.service.ingest(s).success,"Original service mutation also rejects during capture")
		check(g.collect(a.lease).success,"Release before original legacy publication")
		var helper := Playable.new(); helper._defeat_wave(s)
		check(helper._failures.is_empty() and s.collect_all_ground_loot().success,"Real DEV awards, growth and item acquisition")
		check(g.capture("downtime").success,"Capture complete acknowledged downtime after original command settled")
		check(s.request_next_wave().success,"Original admitted NEXT WAVE remains authorized")
		# Compare complete JSON projections on both sides; Godot's JSON parser
		# represents integral JSON numbers as floats before codec normalization.
		var expected_motion: Dictionary = JSON.parse_string(JSON.stringify(original.service._prior.recovery.movement,"",true,true))
		check(g.last_capture() != null and g.last_capture().copy().movement == expected_motion,"Actual entry seam captures the same external motion as the legacy schema-12 checkpoint")
		check(g.last_capture().copy().session == JSON.parse_string(JSON.stringify(s.get_state_snapshot(),"",true,true)),"Original entry capture matches final simulation when no later AI effects occur")
		check(not g.is_current(g.last_capture()),"Later legacy service mutation attempts conservatively invalidate capture, even if simulation values are equal")
		check(g.unbind().success,"Release original legacy fixture")
		p.free()
	PlayableCharacterPersistence.test_storage=prior[0]; PlayableCharacterPersistence.test_run_id=prior[1]; PlayableCharacterPersistence.test_nonpersistent=prior[2]

func lifecycle() -> void:
	var f := fixture(); var g: RefCounted = f.g
	var before := frozen(f)
	var a: Dictionary = g.acquire("entry")
	a.lease.cancel()
	check(not g.collect(a.lease).success and frozen(f) == before,"Canceled capture adopts nothing")
	check(g.capture("entry").success,"Capture recovers after explicit cancellation")
	a = g.acquire("entry"); a.clear()
	check(g.capture("entry").success,"Dropped/interrupted lease releases automatically")
	var scope: RefCounted = g.enter_mutation()
	check(not g.acquire("entry").success,"Reentrant capture cannot observe a half-complete original transaction")
	scope = null
	var c: Dictionary = g.capture("entry")
	check(c.success,"All mutation scopes release on return")
	var destination := ArenaCombatSession.new()
	BrowserWaveCandidate.copy_data(f.s,destination,["simulation","_arena_wave_state_machine","_reward_ledger","_playable_persistence"])
	check(destination._character_capture_gate == null,"Browser candidate cloning cannot copy process-local gate ownership")
	var exact: String = c.capture.json()
	check(ResourceUID.text_to_id(FileAccess.get_file_as_string("res://scripts/rewards/character_capture_gate.gd.uid").strip_edges()) != ResourceUID.INVALID_ID,"Gate UID is valid")
	check(ResourceUID.text_to_id(FileAccess.get_file_as_string("res://tests/test_character_capture_gate.gd.uid").strip_edges()) != ResourceUID.INVALID_ID,"Test UID is valid")
	var started := Time.get_ticks_usec()
	for i in range(100): check(g.capture("entry").success,"Repeated explicit read-only capture remains available")
	print("46C1_METRICS "+JSON.stringify({"captures":100,"total_us":Time.get_ticks_usec()-started,"native_live":OS.get_static_memory_usage(),"native_peak":OS.get_static_memory_peak_usage(),"scope":"native debug capture only; not save/publication/Edge"}))
	c = {"capture":g.last_capture()}; exact = c.capture.json()
	# The capture is not an acknowledgement; unchanged retry reads the same
	# immutable data. No reward operation or storage publication is performed.
	check(c.capture.json() == exact and g.is_current(c.capture),"Lost simulated acknowledgement retains exact capture, never reapplies rewards")
	f.s.configure_player_nac_automation({"profile":"Defensive"})
	check(not g.is_current(c.capture) and c.capture.json() == exact,"Stale local state cannot be adopted; original pending bytes remain available for future reconciliation")
	c = g.capture("entry")
	f.s.player_movement_boundary_provider = Callable()
	check(not g.is_current(c.capture),"Changed external provider invalidates the ownership binding")
	f.s.player_movement_boundary_provider = f.p.capture_wave_entry_motion
	check(not g.is_current(c.capture) and not g.capture("entry").success,"Restoring an invalidated binding cannot resurrect old capture authority")
	check(g.unbind().success and not g.is_current(c.capture),"Detachment permanently invalidates old handle")
	check(g.bind(f.s,f.p).success and g.capture("entry").success,"Explicit rebind creates a fresh local capture context")
	check(not g.is_current(c.capture) and g.unbind().success,"Prior-context handle remains stale after rebind")
	f.p.free()

func replay(enabled: bool, mode: String = "normal") -> Dictionary:
	var f := fixture(enabled,46,0,mode)
	var s: ArenaCombatSession = f.s; var p: PlaceholderPlayer = f.p; var g: RefCounted = f.g
	if enabled: check(g.capture("entry").success,"Initial capture is RNG-neutral")
	check(s.start_encounter().success,"Original START")
	s.set_opponent_behavior_enabled(false)
	p._movement.request_running(); p._movement.advance(500000,Vector2.RIGHT)
	s.advance_by(500000)
	var before: Dictionary = frozen(f)
	if enabled: check(not g.capture("entry").success and frozen(f) == before,"Active-wave capture rejected without changing gameplay")
	var helper := Playable.new(); helper._defeat_wave(s)
	check(helper._failures.is_empty(),"Original attacks, defenses, damage and reward events")
	check(s.collect_all_ground_loot().success,"Real loot/currency mutation")
	if enabled:
		var c: Dictionary = g.capture("downtime")
		check(c.success and g.is_current(c.capture),"Capture after original wave effects have settled")
	check(s.request_next_wave().success,"NEXT WAVE continues normally")
	if enabled:
		check(g.last_capture() != null and not g.is_current(g.last_capture()),"NEXT WAVE invalidates the original downtime capture when it continues")
		check(g.last_capture().copy() != JSON.parse_string(JSON.stringify(frozen(f),"",true,true)),"Never relabel old downtime request as the later active-wave state")
		check(not g.capture("entry").success,"Already-active wave is not a new manual entry capture")
	var result := frozen(f)
	if enabled: check(g.unbind().success,"Release complete fixture")
	p.free()
	return result
