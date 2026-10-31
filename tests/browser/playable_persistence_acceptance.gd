extends Node

# Isolated Web project only. Its main scene is explicitly different from the
# shipped game; the factory can address ONLY the validated disposable test DB.
const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
var scene: Node
var controller: ArenaCombatController
var busy := false
var token := ""
var checks := 0

func _ready() -> void:
	token = str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('test') || ''",true))
	if token.is_empty() or token.length() > 32 or not token.replace("-","_").is_valid_identifier():
		line("BLOCKED: supply an isolated ?test=token")
		return
	PlayableCharacterPersistence.test_nonpersistent = false
	PlayableBrowserPersistence.test_factory = func() -> CharacterBrowserStorage: return CharacterBrowserStorage.new(Callable(),"itank-arena-test-36k-playable-"+token)
	JavaScriptBridge.eval("(() => { const p=document.createElement('div'); p.style='position:fixed;right:0;top:0;z-index:100;background:#eef;color:#112;padding:12px;max-width:600px;max-height:90vh;overflow:auto'; for(const pair of [['run','Run DEV lifecycle'],['run_normal','Run NORMAL lifecycle'],['load','Load saved DEV character'],['load_normal','Load saved NORMAL character'],['retry','Retry blocked storage'],['pending','Prepare pending reload'],['ambiguous','Test ambiguous acknowledgement'],['advance','Advance loaded downtime']]) {const b=document.createElement('button'); b.textContent=pair[1]; b.onclick=()=>{window.arena36kCommand=pair[0]};p.appendChild(b);} const log=document.createElement('pre');log.id='playable-test-results';log.style='white-space:pre-wrap';log.textContent='Ready. Disposable browser integration only.';p.appendChild(log);document.body.appendChild(p); })();",true)
	make_scene()

func _process(_delta: float) -> void:
	if busy: return
	var command: Variant = JavaScriptBridge.eval("window.arena36kCommand || ''",true)
	if str(command).is_empty(): return
	JavaScriptBridge.eval("window.arena36kCommand='';",true)
	busy = true
	if command == "run": await run_lifecycle()
	elif command == "run_normal": await run_lifecycle("normal")
	elif command == "load": await load_existing()
	elif command == "load_normal": await load_existing("normal")
	elif command == "pending": await prepare_pending_reload()
	elif command == "ambiguous": await test_ambiguous_write()
	elif command == "advance":
		controller._encounter_button.pressed.emit()
		await settle()
		check(controller._web_operation.is_empty() and controller._session._current_reward_wave_id() == "wave_2","Reloaded downtime advances through verified entry publication")
		remember_expected()
	elif command == "retry":
		controller._encounter_button.pressed.emit()
		await settle()
		verify_loaded()
	busy = false

func make_scene() -> void:
	scene = (load("res://scenes/test_arena.tscn") as PackedScene).instantiate()
	add_child(scene)
	controller = scene.get_node("CombatController")
	# Combat time is explicit; real player physics stays enabled to verify the
	# host pauses its separate movement/recovery process during persistence.
	controller.set_physics_process(false)
	controller._encounter_selector_index = 8

func settle(confirm: bool = false) -> void:
	for index in range(1200):
		controller._poll_browser_persistence()
		if controller._web_operation.get("phase") == "confirmation":
			if not confirm: return
			controller._web_creation_dialog.get_ok_button().pressed.emit()
		if controller._web_operation.get("phase") == "failed": return
		if controller._session._playable_persistence is PlayableBrowserPersistence and controller._session._playable_persistence._browser_result.get("state") in ["failed","unavailable","recovery_required"]:
			controller._update_presentation()
			return
		if not controller._browser_transition_blocked():
			controller._process_new_events()
			controller._update_presentation()
			return
		await get_tree().process_frame
	check(false,"Storage timeout (not a missing character)")

func run_lifecycle(save_mode: String = "dev_normal") -> void:
	controller._encounter_selector_index = 0 if save_mode == "normal" else 8
	var other_profile := "dev_vaelis_thorn" if save_mode == "normal" else "prod_vaelis_thorn"
	var other_before: String = await read_document(other_profile)
	controller._character_selector.pressed.emit()
	check(not controller._player.is_physics_processing() and controller._browser_status_text() == "Loading character","Pending load pauses real movement/recovery and displays Loading character")
	await settle()
	if not check(controller._web_operation.get("phase") == "confirmation","First-time admission requires explicit confirmation"): return
	controller._web_creation_dialog.get_ok_button().pressed.emit()
	await settle()
	if not check(controller._web_operation.is_empty(),"Actual Web selection creates verified character"): return
	check(controller._session._playable_persistence.generation == 1,"First immutable generation acknowledged")
	controller._encounter_button.pressed.emit()
	var session := controller._session
	session.set_opponent_behavior_enabled(false)
	# Real Force casting pipeline, then isolated partially-absorbed fixture.
	for attempt in range(5):
		if session.get_actor_state(&"player").persistent_damage_shields.has("force_shield"): break
		var cast := session.request_player_special(VaelisForceFixture.FORCE_SHIELD_ID)
		if not cast.get("success",false): break
		session.advance_by(5000000)
	var state := session.get_actor_state(&"player")
	if not check(state.persistent_damage_shields.has("force_shield"),"Source-legal Force Shield completes before checkpoint"): return
	state.persistent_damage_shields.force_shield.capacity = 13
	state.current_hpc = 3; state.resources.mana = 7; state.resources.blood = 6
	defeat_wave(session)
	await settle()
	check(session.get_encounter_state() == ArenaCombatSession.ENCOUNTER_BETWEEN_WAVE_DOWNTIME and session._playable_persistence._last_ack,"Completed-wave rewards publish before saved status")
	controller._collect_loot_button.pressed.emit()
	await settle()
	var snapshot := session.get_state_snapshot()
	var generation := session._playable_persistence.generation
	session._playable_persistence.browser.inject_test_fault("abort")
	controller._encounter_button.pressed.emit()
	check(controller._session == session and session.get_state_snapshot() == snapshot and not controller._player.is_physics_processing() and controller._browser_status_text() == "Saving progress","Pending NEXT freezes combat/movement, preserves history and displays Saving progress")
	await settle()
	check(controller._web_operation.get("phase") == "failed" and controller._session == session and session.get_state_snapshot() == snapshot and controller._browser_status_text() == "Progress not saved","Real IDB abort preserves old session and reports Progress not saved")
	check(session._playable_persistence.generation == generation,"Failed publication never acknowledges a newer generation")
	controller._encounter_button.pressed.emit()
	await settle()
	if not check(controller._web_operation.is_empty() and controller._session._current_reward_wave_id() == "wave_2" and controller._browser_status_text() == "Progress saved","UI retry verifies checkpoint, activates Wave 2 and reports Progress saved"): return
	check_resources()
	controller._session.set_opponent_behavior_enabled(false)
	defeat_wave(controller._session)
	await settle()
	controller._encounter_button.pressed.emit()
	await settle()
	if not check(controller._session._current_reward_wave_id() == "wave_3","Continuing NEXT activates Wave 3"): return
	check_resources()
	var secured := summary()
	controller._session.get_actor_state(&"player").current_hpc = 0
	controller._session.advance_by(1)
	controller._update_presentation()
	if not check(controller._encounter_button.text == "RETRY WAVE" and controller._encounter_button.is_visible_in_tree() and controller._return_wave_one_button.is_visible_in_tree(),"Wave 3 defeat renders both actual recovery buttons"): return
	controller._encounter_button.pressed.emit()
	await settle()
	check(controller._session._current_reward_wave_id() == "wave_3","RETRY loads authorized Wave 3 entry")
	check_resources()
	controller._encounter_button.pressed.emit()
	controller._session.set_opponent_behavior_enabled(false)
	controller._session.get_actor_state(&"player").current_hpc = 0
	controller._session.advance_by(1)
	controller._update_presentation()
	controller._return_wave_one_button.pressed.emit()
	await settle()
	if not check(controller._session._current_reward_wave_id() == "wave_1" and controller._web_operation.is_empty(),"RETURN verifies fresh Wave 1 before replacing defeat"): return
	var returned := summary()
	check(returned.xp == secured.xp and returned.items == secured.items and returned.growth == secured.growth,"RETURN retains secured XP/items/HPM history without starter duplication")
	check(returned.run_id != secured.run_id and returned.hpc == controller._session.get_actor_max_hpm(&"player") and returned.mana == controller._session.simulation.get_actor_definition(&"player").resource_maxima.mana,"New run identity and approved restoration exactly once")
	check(not controller._session.get_actor_state(&"player").persistent_damage_shields.has("force_shield"),"New-run combat-only cleanup; no shield persistence into a new circuit")
	JavaScriptBridge.eval("sessionStorage.setItem(%s,%s)" % [JSON.stringify(expected_key()),JSON.stringify(JSON.stringify(returned))],true)
	var other_after: String = await read_document(other_profile)
	check(other_before == other_after,"Lifecycle leaves the other NORMAL/DEV namespace unchanged")
	line("LIFECYCLE COMPLETE — %s checks (%s). Reload and load this mode; keep the tab open for contention testing." % [checks,save_mode])

func load_existing(save_mode: String = "dev_normal") -> void:
	controller._encounter_selector_index = 0 if save_mode == "normal" else 8
	controller._character_selector.pressed.emit()
	await settle()
	if controller._web_operation.get("phase") == "failed":
		check(controller._web_operation.service.status().text == "Character currently open in another tab","Actual competing tab rejected; no new starter or session replacement")
		return
	verify_loaded()

func verify_loaded() -> void:
	if not check(controller._web_operation.is_empty() and controller._session._playable_persistence is PlayableBrowserPersistence,"Actual reopened page hydrates saved character"): return
	var actor := controller._session.get_actor_state(&"player")
	var entry: Dictionary = controller._session._playable_persistence._prior.recovery
	check(actor.current_hpc == entry.player.current_hpc and actor.resources == entry.player.resources and actor.persistent_damage_shields == entry.player.persistent_damage_shields,"Reload applies exact stored HPC/resources/protection, with no refill")
	var expected: Variant = JavaScriptBridge.eval("sessionStorage.getItem(%s) || ''" % JSON.stringify(expected_key()),true)
	if not str(expected).is_empty():
		var decoded: Dictionary = CharacterSaveContract._normalize_json_numbers(JSON.parse_string(str(expected)))
		check(JSON.stringify(summary(),"",true,true) == JSON.stringify(decoded,"",true,true),"Page reload preserves exact entry resources, XP, items, growth, generation and run identity")
	var sync := TwoClientSyncHarness.new(1)
	var snapshot := controller._session.simulation.get_state_snapshot()
	var batch := controller._session.simulation.get_resolved_events_from(0)
	var envelopes: Array = []
	for event: CombatEvent in batch.events: envelopes.append(CombatEventEnvelope.new(envelopes.size(),event.to_dictionary(),snapshot))
	sync.deliver_in_order(envelopes)
	check(sync.compare_clients().success and controller._session.get_state_snapshot().schema_version == 12,"Loaded browser gameplay converges under unchanged schema 12")
	check(controller._session.simulation.get_resolved_event_count() == batch.next_cursor,"Read-only synchronization check preserves complete authoritative history")
	line("LOAD COMPLETE. Writer lock remains held until this tab closes.")

func check_resources() -> void:
	var state := controller._session.get_actor_state(&"player")
	check(state.current_hpc == 3 and state.resources.mana == 7 and state.resources.blood == 6 and state.persistent_damage_shields.get("force_shield",{}).get("capacity") == 13,"Exact HPC/Mana/Blood/Shield continuity without refills")

func prepare_pending_reload() -> void:
	if controller._session._playable_persistence == null or controller._session.get_encounter_state() != ArenaCombatSession.ENCOUNTER_READY:
		line("Load an existing entry before the pending-reload test.")
		return
	JavaScriptBridge.eval("sessionStorage.setItem(%s,%s)" % [JSON.stringify(expected_key()),JSON.stringify(JSON.stringify(summary()))],true)
	controller._encounter_button.pressed.emit()
	controller._session.set_opponent_behavior_enabled(false)
	controller._session.get_actor_state(&"player").current_hpc = 2
	controller._session.get_actor_state(&"player").resources.mana = 1
	controller._session._playable_persistence.browser.inject_test_fault("pause_before_transaction")
	defeat_wave(controller._session)
	for index in range(120):
		controller._poll_browser_persistence()
		var service := controller._session._playable_persistence as PlayableBrowserPersistence
		if service._async != null and service._async._phase == "publish":
			check(controller._browser_transition_blocked(),"Pending publication freezes the actual playable host")
			line("READY FOR RELOAD OR TAB CLOSE: uncommitted publication held in disposable adapter. Reload, then Load saved DEV character; exact earlier entry must return.")
			return
		await get_tree().process_frame
	check(false,"Could not reach pending publication: %s / %s / %s" % [controller._session.get_encounter_state(),controller._session._playable_persistence.status(),controller._session._playable_persistence._phase])

func expected_key() -> String:
	return "arena36kExpected:"+controller._session._playable_persistence.mode

func remember_expected() -> void:
	JavaScriptBridge.eval("sessionStorage.setItem(%s,%s)" % [JSON.stringify(expected_key()),JSON.stringify(JSON.stringify(summary()))],true)

func test_ambiguous_write() -> void:
	if controller._session._playable_persistence == null or controller._session.get_encounter_state() != ArenaCombatSession.ENCOUNTER_READY:
		line("Load a saved entry before testing ambiguous acknowledgement.")
		return
	var service := controller._session._playable_persistence as PlayableBrowserPersistence
	var generation := service.generation
	controller._encounter_button.pressed.emit()
	controller._session.set_opponent_behavior_enabled(false)
	controller._session.get_actor_state(&"player").current_hpc = 2
	controller._session.get_actor_state(&"player").resources.mana = 1
	service.browser.inject_test_fault("lost_ack")
	defeat_wave(controller._session)
	await settle()
	var committed: String = await read_document(service.profile_id)
	var decoded := CharacterSaveContract.decode(committed)
	check(not service._last_ack and controller._browser_status_text() == "Recovery required" and decoded.get("success",false) and decoded.payload.generation == generation+1,"Committed-but-lost acknowledgement reports Recovery required, not saved")
	controller._encounter_button.pressed.emit()
	await settle()
	var reconciled: String = await read_document(service.profile_id)
	check(service._last_ack and service.generation == generation+1 and reconciled == committed and controller._browser_status_text() == "Progress saved","Actual browser reconciliation verifies the exact generation without duplicate XP/items/publication")
	remember_expected()

func read_document(profile: String) -> String:
	var reader := CharacterBrowserStorage.new(Callable(),"itank-arena-test-36k-playable-"+token)
	var operation := reader.begin("inspect",{"profile":profile})
	for index in range(1200):
		var response := reader.poll(operation.job)
		if response.state != "pending":
			reader.dispose()
			if not response.get("success",false):
				check(false,"Namespace inspection unavailable")
				return "read_failed"
			return response.get("document","")
		await get_tree().process_frame
	check(false,"Namespace inspection timed out")
	return "timeout"

func summary() -> Dictionary:
	var service := controller._session._playable_persistence
	var state := controller._session.get_actor_state(&"player")
	return {"xp":service._prior.xp,"items":service._prior.items,"growth":service._prior.permanent.growth,"level":service._prior.permanent.level,"generation":service.generation,"wave":controller._session._current_reward_wave_id(),"run_id":service.run_id,"hpc":state.current_hpc,"mana":state.resources.mana,"blood":state.resources.blood}

func defeat_wave(session: ArenaCombatSession) -> void:
	for id: String in session.get_targetable_enemy_ids(): session.get_actor_state(StringName(id)).current_hpc = 0
	session.advance_by(1)

func check(value: bool, message: String) -> bool:
	checks += 1
	line(("PASS: " if value else "FAIL: ")+message)
	return value

func line(message: String) -> void:
	print(message)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("(() => { const log=document.getElementById('playable-test-results'); if(log) log.textContent += %s+'\\n'; })();" % JSON.stringify(message),true)
