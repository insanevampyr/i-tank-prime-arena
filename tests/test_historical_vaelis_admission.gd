extends RefCounted

const Admission = preload("res://scripts/rewards/playable_character_admission.gd")
const Web = preload("res://tests/test_playable_browser_persistence.gd")
const Playable = preload("res://tests/test_playable_vaelis_persistence.gd")
const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
# Independent expected source identities verified against the pre-39H resources.
const OLD_SPLITS := {
	"3df0412b72ba5d966b2eb645887fedfbb591782cffc7bff41c192e52583c6d20":[3,6],
	"6b0a4d543e890513fccc2efffb5feb6fab8e8f462651bd0b6903341eb47132d0":[6,3],
}
var failures: Array[String] = []
var assertions := 0
var helper := Playable.new()
var web := Web.new()
var root := ""

class DelayedBackend extends Web.Backend:
	var hold := false
	var operations: Array[String] = []
	var inspect_failure := {}
	func transport(method: String, value: Dictionary) -> Dictionary:
		if method == "poll" and hold: return result("pending","operation_pending")
		return super.transport(method,value)
	func execute(operation: String, args: Dictionary) -> Dictionary:
		operations.append(operation)
		if operation == "inspect" and not inspect_failure.is_empty(): return inspect_failure.duplicate(true)
		return super.execute(operation,args)

func run() -> Array[String]:
	root = OS.get_cache_dir().path_join("itank-storage-tests").path_join("historical_vaelis_%s_%s" % [OS.get_process_id(),Time.get_ticks_usec()])
	PlayableCharacterPersistence.test_nonpersistent = false
	var index := 0
	for digest: String in OLD_SPLITS:
		var starter := Admission.prepare_starter(&"vaelis_thorn","normal",digest)
		check(starter.success and CharacterProfileProjection.fingerprint(starter.source.to_dictionary()) == digest,"Exact historical source fingerprint is reconstructed.")
		check(starter.source.proficiencies.is_empty(),"Historical persisted definition remains pre-Balance.")
		check(starter.source.combat_stats.dt == OLD_SPLITS[digest][0] and starter.source.combat_stats.dp == OLD_SPLITS[digest][1],"Historical allocation remains exact.")
		for mode: String in ["normal","dev_normal"]:
			for version in [2,4]:
				index += 1
				var fixture := make_history(mode,digest,version,str(index))
				if not fixture.get("success",false): continue
				check_loading(fixture,mode,digest)
	check(Admission.prepare_starter(&"vaelis_thorn","normal").success,"Current source admission remains valid.")
	check(Admission.prepare_starter(&"vaelis_thorn","normal","229feacd9264c8088abc7eb0654fde29715a33cee594ff9e926fc88f8c209ae3").success,"Existing post-39H legacy split remains valid.")
	check(Admission.prepare_starter(&"vaelis_thorn","normal","0".repeat(64)).get("reason") == "unsupported_authored_baseline","Unknown source fingerprints fail closed.")
	check_failures_and_requests()
	PlayableBrowserPersistence.test_factory = Callable()
	PlayableCharacterPersistence.test_storage = null
	PlayableCharacterPersistence.test_run_id = ""
	PlayableCharacterPersistence.test_nonpersistent = true
	check(helper._failures.is_empty(),"Reconstructed fixtures use legal source combat: %s" % [helper._failures])
	check(web.failures.is_empty(),"Browser fixture requests settle: %s" % [web.failures])
	assert(root.begins_with(OS.get_cache_dir().path_join("itank-storage-tests")+"/historical_vaelis_"))
	helper._remove_fixture(root)
	print("39W Fix4: %d assertions; historical source/namespace/V2-V4 and failed admission coverage." % assertions)
	return failures

func make_history(mode: String, digest: String, version: int, suffix: String) -> Dictionary:
	var store := CharacterSaveStorage.new(root.path_join(suffix))
	PlayableCharacterPersistence.test_storage = store
	PlayableCharacterPersistence.test_run_id = "run_historical_"+suffix
	var service := PlayableCharacterPersistence.new()
	service.mode = mode
	service.storage = store
	var starter := Admission.prepare_starter(&"vaelis_thorn",mode,digest)
	var opened := service.open_verified_history(starter,{"success":true,"generations":[],"writer_locked":false,"pending_write":false},false,{})
	check(opened.success,"Reconstructed historical starter admits without altering any file.")
	if not opened.success: return {}
	var session := ArenaCombatSession.new(1,null,Fixture.ENCOUNTER_WAVE_ONE_GOBLINS,Fixture.PLAYER_CHARACTER_VAELIS)
	session._playable_persistence = service
	session._run_reward_policy = service.get_run_reward_policy()
	session.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
	var initialized := session.initialize_wave_one_goblins(Vector2i(14_000_000,8_000_000),Vector2i(17_000_000,8_000_000),false)
	check(initialized.success,"Historical actor initializes through the real combat fixture.")
	var movement := PrimeMovementModel.new(10,11,6,3,0,0,DeterministicCombatRng.new(1))
	session.player_movement_boundary_provider = movement.wave_entry_state
	var configured := session.configure_reward_mode(mode)
	var finalized := session.finalize_playable_persistence()
	check(configured.success and finalized.success,"Only disposable fixture storage receives reconstructed Wave 1: %s / %s" % [configured,finalized])
	if not configured.success or not finalized.success: return {}
	helper._defeat_wave(session)
	check(session.collect_all_ground_loot().success,"Historical fixture secures actual loot.")
	check(session.request_next_wave().success,"Historical fixture publishes the next entry.")
	helper._defeat_wave(session)
	if session.get_reward_state().unspent_xp >= 2000:
		check(session.request_character_advancement(&"special_resistance",&"sr","historical_purchase").success,"Fixture records a real affordable purchase.")
	if version == 4:
		check(session.request_next_wave().success,"Prepare a legitimate discarded attempt before a new policy-bearing run.")
		session.get_actor_state(&"player").current_hpc = 0
		session.advance_by(1)
		var authorization := session.get_return_to_wave_one_authorization()
		check(authorization.success,"Historical return uses the actual verified checkpoint.")
		PlayableCharacterPersistence.test_run_id += "_v4"
		var next := ArenaCombatSession.new(1,null,Fixture.ENCOUNTER_WAVE_ONE_GOBLINS,Fixture.PLAYER_CHARACTER_VAELIS)
		var admitted := next.prepare_playable_persistence(mode,true,authorization.get("checkpoint",{}),null,10 if mode == "normal" else 1)
		check(admitted.success,"V2 legacy prefix extends through authorized V4 admission.")
		if not admitted.success: return {}
		next.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
		next.player_movement_boundary_provider = movement.wave_entry_state
		check(next.initialize_wave_one_goblins(Vector2i(14_000_000,8_000_000),Vector2i(17_000_000,8_000_000),false).success,"V4 fixture initializes.")
		check(next.configure_reward_mode(mode).success and next.finalize_playable_persistence().success,"V4 first entry and policy publish together in disposable storage.")
		session = next
		helper._defeat_wave(session)
	var profile := "prod_vaelis_thorn" if mode == "normal" else "dev_vaelis_thorn"
	var records := CharacterSaveStorage.history_records(store.inspect_profile(profile))
	check(not records.is_empty() and CharacterSaveContract.decode(records.back().document).version == version,"Fixture carries the requested final envelope version.")
	return {"success":true,"storage":store,"profile":profile,"records":records,"payload":CharacterSaveContract.decode(records.back().document).payload}

func check_loading(fixture: Dictionary, mode: String, digest: String) -> void:
	PlayableBrowserPersistence.test_factory = Callable()
	PlayableCharacterPersistence.test_storage = fixture.storage
	var before: Array = fixture.records.duplicate(true)
	var scene := web.make_scene()
	var c: ArenaCombatController = scene.get_node("CombatController")
	var result: Dictionary = c._admit_existing_profile(mode)
	check(result.success,"Desktop admits verified historical %s: %s" % [mode,result])
	if not result.success:
		web.finish(scene)
		return
	check(c._session._playable_persistence._prior == fixture.payload,"Desktop preserves every XP, receipt, item, purchase, checkpoint and run-history field.")
	var actor := c._session.simulation.get_actor_definition(&"player")
	var state := c._session.get_actor_state(&"player")
	var captured := BalanceActorProfile.capture(actor.source_character_definition,actor,state,c._session.simulation.clock.get_elapsed_us())
	check(captured.success and BalanceSkillCheck.resolve(captured.get("profile",{}),9).get("target") == 9,"Historical actor retains current verified SI2/SCM0/RB0 Balance.")
	check(c._session._playable_persistence.source.proficiencies.is_empty() and CharacterProfileProjection.fingerprint(c._session._playable_persistence.source.to_dictionary()) == digest,"Runtime Balance does not rewrite saved source provenance.")
	check(actor.get_combat_stat("dt") == OLD_SPLITS[digest][0] and actor.get_combat_stat("dp") == OLD_SPLITS[digest][1],"Runtime skill evolution does not redistribute Dodge allocations.")
	var snapshot := c._session.get_state_snapshot()
	var events := c._session.simulation.get_resolved_events().map(func(e): return e.to_dictionary())
	var rng := c._session.simulation.random.wave_entry_state()
	var harness := TwoClientSyncHarness.new(1)
	harness.authority.simulation = c._session.simulation
	harness.deliver_in_order(harness.authority.publish_current_events())
	check(harness.compare_clients().success and harness.client_a.get_state_snapshot() == c._session.simulation.get_state_snapshot(),"Historical runtime retains schema-12 simulated-client convergence.")
	web.finish(scene)
	var backend := DelayedBackend.new()
	backend.histories[fixture.profile] = before.duplicate(true)
	PlayableBrowserPersistence.test_factory = func(): return CharacterBrowserStorage.new(backend.transport)
	scene = web.make_scene(); c = scene.get_node("CombatController")
	c._admit_existing_profile(mode)
	web.pump(c)
	check(c._web_operation.is_empty() and c._session._playable_persistence != null,"Async browser admission reaches ADMITTED.")
	check(c._session.get_state_snapshot() == snapshot and c._session.simulation.random.wave_entry_state() == rng and c._session.simulation.get_resolved_events().map(func(e): return e.to_dictionary()) == events,"Desktop/browser recovery has identical RNG, causal events and authoritative state.")
	check(c._session._playable_persistence._prior == fixture.payload and backend.histories[fixture.profile] == before,"Browser preserves exact documents and progression.")
	check(not backend.operations.has("publish") and not backend.operations.has("restore"),"Existing historical admission performs no publication or restore.")
	c._on_dev_tools_pressed()
	check(c._xp_multiplier_button.text.ends_with("LOCKED"),"Admitted policy is LOCKED, never LOADING.")
	web.finish(scene)
	check(CharacterSaveStorage.history_records(fixture.storage.inspect_profile(fixture.profile)) == before,"Native historical reload is byte-preserving.")
	PlayableBrowserPersistence.test_factory = Callable()

func check_failures_and_requests() -> void:
	var backend := DelayedBackend.new()
	PlayableBrowserPersistence.test_factory = func(): return CharacterBrowserStorage.new(backend.transport)
	var starter := Admission.prepare_starter(&"vaelis_thorn","normal")
	var corrupt: Dictionary = starter.prepared.payload.duplicate(true)
	corrupt.lineage.baseline_digest = "0".repeat(64)
	var encoded := CharacterSaveContract.encode(corrupt)
	backend.histories.prod_vaelis_thorn = [{"document":encoded.text,"generation":1,"transaction_id":"unknown_baseline"}]
	var before := backend.histories.duplicate(true)
	var scene := web.make_scene()
	var c: ArenaCombatController = scene.get_node("CombatController")
	var guard := c._session
	var guard_snapshot := guard.get_state_snapshot()
	c._on_dev_tools_pressed()
	backend.hold = true
	c._character_selector.pressed.emit()
	var old_service: PlayableBrowserPersistence = c._web_operation.service
	var old_job := old_service._job
	for _i in range(3): c._poll_browser_persistence()
	c._update_presentation()
	check(c._xp_multiplier_button.text.ends_with("LOADING") and c._character_selector.disabled and c._encounter_button.disabled,"PENDING is distinct and cannot switch admission targets or play.")
	backend.hold = false
	web.pump(c); c._update_presentation()
	check(c._session == guard and c._web_operation.phase == "failed" and c._can_cancel_browser_load(),"Failed admission preserves the prior session and permits safe cancellation.")
	check(guard.get_state_snapshot() == guard_snapshot and c._browser_transition_blocked() and not c._player.is_physics_processing(),"Failed admission freezes unauthorized gameplay without consuming RNG or changing the prior snapshot.")
	check(c._xp_multiplier_button.text.ends_with("RECOVERY REQUIRED") and not c._xp_multiplier_button.text.contains("LOADING"),"Failed recovery removes misleading LOADING.")
	check(c._browser_status_text().contains("original definition is not supported") and c._last_ui_message.contains("Cannot load character"),"Player sees the specific understandable failure cause.")
	check(c._event_log.text.contains("original definition is not supported") and c._event_log.text.contains("unsupported_authored_baseline"),"Wrapping recent-results text retains the full explanation and developer diagnostic code even when the compact HUD truncates.")
	check(c._encounter_button.text == "RETRY STORAGE" and not c._encounter_button.disabled and c._character_selector.text == "CANCEL LOAD","Only appropriate retry/cancel actions remain enabled.")
	c._retry_browser_operation(); web.pump(c)
	check(c._web_operation.service == old_service and c._web_operation.phase == "failed" and backend.histories == before,"Retry rechecks the same profile without publication.")
	c._on_character_selector_pressed()
	check(c._web_operation.is_empty() and c._session == guard and c._last_ui_message.contains("canceled") and not c._xp_multiplier_button.text.contains("LOADING"),"CANCELED clears pending presentation without changing the character.")
	# A late result remains attached to its old job, never the new profile request.
	backend.jobs[old_job] = {"operation":"inspect","arguments":{"profile":"prod_vaelis_thorn"}}
	c._open_legacy_profile()
	var new_service: PlayableBrowserPersistence = c._web_operation.service
	old_service.browser.poll(old_job)
	check(c._web_operation.service == new_service and new_service.profile_id == "dev_vaelis_thorn","Late old response cannot retarget the current legacy request.")
	web.pump(c)
	check(c._session == guard and c._web_operation.is_empty() and backend.histories == before and not backend.histories.has("dev_vaelis_thorn"),"Missing legacy target and stale completion create no starter or namespace crossover.")
	check(not backend.operations.has("publish") and not backend.operations.has("restore"),"Rejected, retried, canceled and stale admission never publishes.")
	web.finish(scene)
	for state: String in ["failed","unavailable"]:
		backend = DelayedBackend.new()
		backend.inspect_failure = backend.result(state,"indexeddb_unavailable")
		PlayableBrowserPersistence.test_factory = func(): return CharacterBrowserStorage.new(backend.transport)
		scene = web.make_scene(); c = scene.get_node("CombatController")
		c._on_dev_tools_pressed(); c._character_selector.pressed.emit(); web.pump(c); c._update_presentation()
		check(c._xp_multiplier_button.text.ends_with("LOAD FAILED") and c._browser_status_text().contains("browser character storage is unavailable"),"Failed/unavailable storage shows its cause instead of LOADING.")
		check(c._can_cancel_browser_load() and not c._encounter_button.disabled and backend.histories.is_empty(),"Storage failures expose safe retry/cancel without a starter write.")
		c._on_character_selector_pressed()
		web.finish(scene)
	backend = DelayedBackend.new()
	PlayableBrowserPersistence.test_factory = func(): return CharacterBrowserStorage.new(backend.transport)
	scene = web.make_scene(); c = scene.get_node("CombatController")
	c._on_dev_tools_pressed(); c._character_selector.pressed.emit(); web.pump(c,false); c._update_presentation()
	check(c._xp_multiplier_button.text.ends_with("AWAITING CONFIRMATION") and c._web_operation.phase == "confirmation" and backend.histories.is_empty(),"Missing profile awaits explicit confirmation without publication.")
	c._web_creation_dialog.get_cancel_button().pressed.emit()
	check(c._web_operation.is_empty() and not c._xp_multiplier_button.text.contains("LOADING") and backend.histories.is_empty(),"Canceling creation removes pending indicators without publishing a character.")
	web.finish(scene)

func check(value: bool, message: String) -> void:
	assertions += 1
	if not value: failures.append(message)
