extends RefCounted

const Historical = preload("res://tests/test_historical_vaelis_admission.gd")
const BrowserTests = preload("res://tests/test_playable_browser_persistence.gd")
const Profiles = preload("res://scripts/rewards/character_profile_projection.gd")
const BASELINE := "3df0412b72ba5d966b2eb645887fedfbb591782cffc7bff41c192e52583c6d20"
var failures: Array[String] = []
var assertions := 0
var helper := Historical.new()

func check(value: bool, message: String) -> void:
	assertions += 1
	if not value: failures.append(message)

func run() -> Array[String]:
	helper.root = OS.get_cache_dir().path_join("itank-storage-tests/run_selection_%s_%s" % [OS.get_process_id(),Time.get_ticks_usec()])
	PlayableCharacterPersistence.test_nonpersistent = false
	for mode: String in ["dev_normal","normal"]:
		for version: int in [2,4]:
			var fixture := helper.make_history(mode,BASELINE,version,"%s_%s" % [mode,version])
			check(fixture.get("success",false),"Reconstruct a verified historical fixture: %s/%s" % [mode,version])
			if not fixture.get("success",false): continue
			_test_desktop(fixture,mode,version)
			if mode == "dev_normal" and version == 4:
				_test_browser(fixture)
	check(helper.failures.is_empty() and helper.helper._failures.is_empty(),"Source-verified fixture combat/advancement remains valid: %s / %s" % [helper.failures,helper.helper._failures])
	PlayableCharacterPersistence.test_storage = null
	PlayableCharacterPersistence.test_nonpersistent = true
	PlayableCharacterPersistence.test_run_id = ""
	PlayableBrowserPersistence.test_factory = Callable()
	helper.helper._remove_fixture(helper.root)
	check(not DirAccess.dir_exists_absolute(helper.root),"All disposable profile data is removed.")
	print("43D saved-run selection: %d assertions." % assertions)
	return failures

func open(fixture: Dictionary, mode: String) -> Node:
	PlayableCharacterPersistence.test_storage = fixture.storage
	var scene := helper.web.make_scene()
	var c: ArenaCombatController = scene.get_node("CombatController")
	check(c._admit_existing_profile(mode).success,"Existing historical profile loads read-only.")
	check(not c._loaded_run_choice.is_empty() and c._run_choice_dialog.visible,"Unfinished loaded run offers RESUME RUN / NEW RUN.")
	return scene

func _test_desktop(fixture: Dictionary, mode: String, version: int) -> void:
	var scene := open(fixture,mode)
	var c: ArenaCombatController = scene.get_node("CombatController")
	var service := c._session._playable_persistence
	var before: Array = CharacterSaveStorage.history_records(fixture.storage.inspect_profile(fixture.profile))
	var prior := service._prior.duplicate(true)
	var policy := c._session.get_run_reward_policy()
	var rng := c._session.simulation.random.wave_entry_state()
	var resources := c._session.get_actor_state(&"player").resources.duplicate(true)
	c._on_encounter_button_pressed()
	check(c._session.simulation.random.wave_entry_state() == rng and not c._session.is_encounter_active(),"Pending run choice blocks combat without RNG consumption.")
	c._run_choice_dialog.get_ok_button().pressed.emit()
	check(c._loaded_run_choice.is_empty() and c._session.get_run_reward_policy() == policy and c._session.get_actor_state(&"player").resources == resources and c._session.simulation.random.wave_entry_state() == rng,"RESUME preserves the locked policy, resources, RNG and checkpoint.")
	check(CharacterSaveStorage.history_records(fixture.storage.inspect_profile(fixture.profile)) == before,"RESUME writes no generation or receipt.")
	helper.helper._free(scene)
	scene = open(fixture,mode)
	c = scene.get_node("CombatController")
	c._confirm_abandon_loaded_run(10)
	check(CharacterSaveStorage.history_records(fixture.storage.inspect_profile(fixture.profile)) == before and not c._loaded_run_choice.is_empty(),"An unconfirmed request cannot abandon a run or publish a generation.")
	c._run_choice_dialog.custom_action.emit(&"new_run")
	check(c._abandon_run_dialog.visible,"NEW RUN requires a separate abandonment confirmation.")
	c._abandon_run_dialog.get_cancel_button().pressed.emit()
	check(c._run_choice_dialog.visible and CharacterSaveStorage.history_records(fixture.storage.inspect_profile(fixture.profile)) == before,"Cancel returns to the saved-run choice without publication.")
	c._ask_abandon_loaded_run()
	var selected: int = (1 if version == 2 else 10) if mode == "dev_normal" else policy.xp_multiplier
	check(c._abandon_run_boost.visible == (mode == "dev_normal"),"Only Legacy DEV gets a choice of both multipliers.")
	if mode == "normal":
		c._confirm_abandon_loaded_run(11-selected)
		check(not c._loaded_run_choice.is_empty() and CharacterSaveStorage.history_records(fixture.storage.inspect_profile(fixture.profile)) == before,"NORMAL cannot acquire a different policy through the abandonment action.")
	PlayableCharacterPersistence.test_run_id = "run_43d_%s_%s" % [mode,version]
	if mode == "dev_normal" and selected == 10: c._abandon_run_dialog.custom_action.emit(&"boost")
	else: c._abandon_run_dialog.get_ok_button().pressed.emit()
	c._confirm_abandon_loaded_run(selected)
	var after: Array = CharacterSaveStorage.history_records(fixture.storage.inspect_profile(fixture.profile))
	check(after.size() == before.size()+1 and after.slice(0,before.size()) == before,"One atomic generation appends; double confirmation never rewrites or duplicates history.")
	var next := c._session._playable_persistence._prior
	check(next.run_history.slice(0,prior.run_history.size()) == prior.run_history and next.run_history.size() == prior.run_history.size()+1 and next.recovery.run_id != prior.recovery.run_id,"New unique run ID preserves all prior run identities.")
	check(next.recovery.phase == "entry" and next.recovery.wave_id == "wave_1" and c._session.get_encounter_state() == ArenaCombatSession.ENCOUNTER_READY,"New policy, run ID and Wave 1 entry publish together before combat.")
	for field: String in ["xp","purchases","items","settlements","permanent","equipment_state","secured_checkpoints"]:
		check(next[field] == prior[field],"Committed %s is unchanged by abandoning the attempt." % field)
	check(c._session.get_run_reward_policy().xp_multiplier == selected and not c._can_select_next_run_xp(),"The selected policy is locked after publication.")
	check(CharacterSaveContract.decode(after.back().document).version == 4,"V2 history extends additively to V4; V4 stays V4.")
	check(c._session.start_encounter().success and not c._session.get_abandon_run_authorization().success,"Active combat cannot authorize abandoning the checkpoint through this loading flow.")
	var resumed_run: String = next.recovery.run_id
	helper.helper._free(scene)
	scene = open(fixture,mode)
	c = scene.get_node("CombatController")
	c._resume_loaded_run()
	check(c._session._playable_persistence.run_id == resumed_run and c._session.get_run_reward_policy().xp_multiplier == selected,"Reload recovers the committed run and policy without reassignment.")
	# A valid concurrent head appended after confirmation was displayed.
	c._offer_run_choice_on_load = true
	c._offer_loaded_run_choice()
	c._ask_abandon_loaded_run()
	var rival := next.duplicate(true)
	rival.generation += 1
	rival.recovery.player.current_hpc -= 1
	check(fixture.storage.write_profile(fixture.profile,rival,"rival_head").success,"Disposable rival writer advances the committed head.")
	var rival_history: Array = CharacterSaveStorage.history_records(fixture.storage.inspect_profile(fixture.profile))
	PlayableCharacterPersistence.test_run_id += "_stale"
	c._confirm_abandon_loaded_run(selected)
	check(CharacterSaveStorage.history_records(fixture.storage.inspect_profile(fixture.profile)) == rival_history and not c._loaded_run_choice.is_empty(),"Stale abandonment fails closed without publication or silently resuming combat.")
	c._resume_loaded_run()
	check(c._session._playable_persistence.generation == rival.generation and not c._loaded_run_choice.is_empty(),"RESUME rechecks a changed Desktop head and asks again using the new verified checkpoint.")
	c._resume_loaded_run()
	helper.helper._free(scene)

func _test_browser(fixture: Dictionary) -> void:
	var backend := BrowserTests.Backend.new()
	var before: Array = CharacterSaveStorage.history_records(fixture.storage.inspect_profile(fixture.profile))
	backend.histories[fixture.profile] = before.duplicate(true)
	PlayableBrowserPersistence.test_factory = func() -> CharacterBrowserStorage: return CharacterBrowserStorage.new(backend.transport)
	var scene := helper.web.make_scene()
	var c: ArenaCombatController = scene.get_node("CombatController")
	c._admit_existing_profile("dev_normal")
	helper.web.pump(c)
	check(not c._loaded_run_choice.is_empty() and backend.histories[fixture.profile] == before,"Async browser admission offers the same read-only decision.")
	c._ask_abandon_loaded_run()
	c._abandon_run_dialog.get_cancel_button().pressed.emit()
	check(backend.histories[fixture.profile] == before and c._run_choice_dialog.visible,"Browser confirmation cancellation publishes nothing.")
	c._ask_abandon_loaded_run()
	var previous := c._session
	previous._playable_persistence.browser.inject_test_fault("lost_ack")
	PlayableCharacterPersistence.test_run_id = "run_43d_web"
	c._abandon_run_dialog.custom_action.emit(&"boost")
	c._profile_namespace = "normal" # Stale visible selection must not retarget the captured request.
	c._next_run_xp_boost = false
	c._confirm_abandon_loaded_run(10)
	helper.web.pump(c)
	check(c._web_operation.get("phase") == "failed" and c._session == previous,"Lost acknowledgement retains the old live session and blocks speculative adoption.")
	check(not c._can_cancel_browser_load(),"An uncertain published new run cannot be canceled back into the old checkpoint.")
	var count: int = backend.histories[fixture.profile].size()
	c._retry_browser_operation()
	helper.web.pump(c)
	check(c._web_operation.is_empty() and backend.histories[fixture.profile].size() == count and count == before.size()+1,"Exact retry reconciles once without another run or rewards.")
	check(c._session.get_run_reward_policy().xp_multiplier == 10 and c._session._playable_persistence._prior.settlements == fixture.payload.settlements,"Recovered browser run keeps ×10 and original receipts.")
	check(c._session.get_reward_mode() == "dev_normal" and c._profile_namespace == "dev_normal","Async publication keeps the captured namespace independently of stale UI defaults.")
	helper.web.finish(scene)
	scene = helper.web.make_scene()
	c = scene.get_node("CombatController")
	c._admit_existing_profile("dev_normal")
	helper.web.pump(c)
	c._run_choice_dialog.get_ok_button().pressed.emit()
	check(c._session.get_run_reward_policy().xp_multiplier == 10 and backend.histories[fixture.profile].size() == count,"Browser reload and RESUME preserve the exact published policy.")
	c._offer_run_choice_on_load = true
	c._offer_loaded_run_choice()
	c._ask_abandon_loaded_run()
	var rival: Dictionary = CharacterSaveContract.decode(backend.histories[fixture.profile].back().document).payload
	rival.generation += 1
	rival.recovery.player.current_hpc -= 1
	backend.histories[fixture.profile].append({"generation":rival.generation,"transaction_id":"web_rival","document":CharacterSaveContract.encode(rival).text})
	var rival_count: int = backend.histories[fixture.profile].size()
	PlayableCharacterPersistence.test_run_id = "run_43d_web_stale"
	c._abandon_run_dialog.get_ok_button().pressed.emit()
	helper.web.pump(c)
	check(c._web_operation.get("phase") == "failed" and backend.histories[fixture.profile].size() == rival_count,"Stale browser head rejects the captured abandonment before publication.")
	check(c._can_cancel_browser_load(),"A rejected pre-publication attempt can be canceled.")
	c._cancel_browser_creation()
	helper.web.pump(c)
	check(c._session._playable_persistence.generation == rival.generation and not c._loaded_run_choice.is_empty() and backend.histories[fixture.profile].size() == rival_count,"Cancellation re-reads the verified current head without publishing or admitting stale state.")
	c._resume_loaded_run()
	helper.web.finish(scene)
	PlayableBrowserPersistence.test_factory = Callable()
