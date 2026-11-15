extends RefCounted
const Grant = preload("res://scripts/rewards/character_expc_grant.gd")
const Credit = preload("res://scripts/rewards/character_expc_credit.gd")
const Historical = preload("res://tests/test_historical_vaelis_admission.gd")
const Web = preload("res://tests/test_playable_browser_persistence.gd")
var failures: Array[String] = []
var assertions := 0
var helper := Historical.new()
func check(value: bool, message: String) -> void:
	assertions += 1
	if not value: failures.append(message)
func pump(c: ArenaCombatController) -> void:
	for _i in range(10000):
		c._physics_process(0.0)
		c._expc_grant_actions._process(0.0)
		if c._expc_grant_actions._grant.status.get("state") != "pending": return
	check(false,"Bounded maintenance operation settles.")
func open(fixture: Dictionary, browser: bool = false) -> Node:
	PlayableCharacterPersistence.test_storage = fixture.storage
	var scene := helper.web.make_scene()
	var c: ArenaCombatController = scene.get_node("CombatController")
	c._admit_existing_profile("dev_normal")
	if browser: Web.new().pump(c)
	c._resume_loaded_run()
	if not c._rewards_panel.visible: c._on_inventory_toggle_pressed()
	c._expc_grant_actions._process(0.0)
	return scene
func run() -> Array[String]:
	PlayableCharacterPersistence.test_nonpersistent = false
	helper.root = OS.get_cache_dir().path_join("itank-storage-tests/grant_delivery_%s_%s" % [OS.get_process_id(),Time.get_ticks_usec()])
	for version: int in [2,4]: native(version)
	stale()
	for fault: String in ["", "lost_ack", "abort", "forged_ack"]: browser(fault)
	var normal := helper.make_history("normal",Credit.BASELINE,2,"normal")
	PlayableCharacterPersistence.test_storage = normal.storage
	var scene := helper.web.make_scene()
	var c: ArenaCombatController = scene.get_node("CombatController")
	c._admit_existing_profile("normal"); c._resume_loaded_run()
	c._expc_grant_actions._process(0.0)
	check(not c._expc_grant_actions._button.visible and not Grant.new().begin(c._session).success,"NORMAL, including its multiplier, cannot access the fixed DEV grant.")
	helper.helper._free(scene)
	check(helper.failures.is_empty() and helper.helper._failures.is_empty(),"Historical fixtures remain source-verified.")
	PlayableCharacterPersistence.test_storage = null
	PlayableCharacterPersistence.test_nonpersistent = true
	PlayableCharacterPersistence.test_run_id = ""
	PlayableBrowserPersistence.test_factory = Callable()
	helper.helper._remove_fixture(helper.root)
	check(not DirAccess.dir_exists_absolute(helper.root),"All profiles were disposable and cleaned up.")
	print("43G grant delivery: %d assertions." % assertions)
	return failures

func native(version: int) -> void:
	var f := helper.make_history("dev_normal",Credit.BASELINE,version,"native_%d" % version)
	var scene := open(f)
	var c: ArenaCombatController = scene.get_node("CombatController")
	if version == 4:
		check(c._session.request_next_wave().success,"Secure a new entry before testing READY maintenance.")
		helper.helper._free(scene)
		scene = open(f); c = scene.get_node("CombatController")
	var service := c._session._playable_persistence
	var original := service._prior.duplicate(true)
	var records := CharacterSaveStorage.history_records(f.storage.inspect_profile(f.profile))
	var player := c._session.get_actor_state(&"player")
	var resources := player.resources.duplicate(true)
	var hpc: int = player.current_hpc
	var rng := c._session.simulation.random.wave_entry_state()
	var actions: Node = c._expc_grant_actions
	check(not original.has("expc_credits") and actions._button.visible,"Loading never applies a credit; the fixed-profile review action is discoverable.")
	check(actions._button.is_visible_in_tree() and actions._button.get_index() == 3,"The real Character Menu exposes the review action alongside save/load and Legacy DEV access.")
	actions._button.pressed.emit(); pump(c)
	check(actions._grant.status.state == "confirmation_required" and actions._dialog.visible,"Actual menu action offers explicit confirmation only after history verification.")
	if actions._grant.status.state != "confirmation_required":
		print("43G quote rejection: ",actions._grant.status)
		helper.helper._free(scene)
		return
	var q: Dictionary = actions._grant.status.quote
	check(q.profile_id == f.profile and q.namespace == "dev_normal" and q.generation == original.generation and q.head_digest == Credit.digest(original) and q.history_digest.length() == 64,"Confirmation binds the actual profile, generation, head and complete history.")
	check(actions._dialog.dialog_text.contains("EXPC: %d -> %d" % [original.xp.unspent,original.xp.unspent+10000]) and actions._dialog.dialog_text.contains("EXPM: %d -> %d (UNCHANGED)" % [original.xp.earned,original.xp.earned]),"UI displays exact before/after EXPC and unchanged EXPM.")
	c._on_encounter_button_pressed()
	var same_session := c._session
	c._on_character_selector_pressed(); c._on_encounter_selector_pressed(); c._reset_encounter()
	check(c._session == same_session,"Selectors and RESET cannot replace the quoted session.")
	check(not c._session.is_encounter_active() and CharacterSaveStorage.history_records(f.storage.inspect_profile(f.profile)) == records,"Confirmation blocks gameplay without publishing.")
	check(not actions._grant.confirm("forged_token").success,"A forged confirmation cannot publish.")
	actions._dialog.get_cancel_button().pressed.emit()
	check(not actions.blocks_gameplay() and CharacterSaveStorage.history_records(f.storage.inspect_profile(f.profile)) == records,"NOT NOW changes neither character nor storage.")
	actions._button.pressed.emit(); pump(c)
	actions._grant.quote.expc_after += 1
	check(not actions._grant.confirm(actions._grant.quote.token).success,"Tampered quote data cannot authorize the grant.")
	actions._grant.quote.expc_after -= 1
	actions._dialog.get_ok_button().pressed.emit()
	check(actions._grant.status.state == "applied" and service._last_ack,"Confirmation publishes and verifies one generation through the existing coordinator.")
	check(actions._dialog.dialog_text.contains("EXPM: %d (UNCHANGED)" % original.xp.earned),"Verified result displays the unchanged EXPM balance.")
	actions._dialog.get_cancel_button().pressed.emit()
	check(not actions._dialog.visible and not actions.blocks_gameplay(),"CLOSE dismisses the verified result and resumes normal management.")
	var after: Dictionary = f.storage.read_profile(f.profile).payload
	check(after.generation == original.generation+1 and after.xp.unspent == original.xp.unspent+10000 and after.xp.earned == original.xp.earned and after.xp.spent == original.xp.spent,"Exactly +10,000 EXPC; no EXPM or historical-spending change.")
	for field: String in ["permanent","base_attributes","purchases","items","settlements","run_history","equipment_state"]:
		check(after[field] == original[field],"Grant preserves "+field)
	check(after.recovery.player == original.recovery.player and player.resources == resources and player.current_hpc == hpc and c._session.simulation.random.wave_entry_state() == rng,"No refill, resource loss, actions, levels or RNG draws from maintenance.")
	var count: int = f.storage.inspect_profile(f.profile).generations.size()
	actions._dialog.get_ok_button().pressed.emit(); actions._process(0.0)
	check(f.storage.inspect_profile(f.profile).generations.size() == count and c._session.get_reward_state().unspent_xp == after.xp.unspent and actions._button.disabled,"Repeated confirmation/rendering cannot pay twice.")
	var snapshot := c._session.simulation.get_state_snapshot()
	var sync := TwoClientSyncHarness.new(1)
	var envelopes: Array = []
	for event: CombatEvent in c._session.simulation.get_resolved_events_from(0).events:
		envelopes.append(CombatEventEnvelope.new(envelopes.size(),event.to_dictionary(),snapshot))
	sync.deliver_in_order(envelopes)
	check(sync.compare_clients().success and sync.client_a.get_state_snapshot() == snapshot,"Maintenance provenance and wallet converge without consuming RNG.")
	if version == 2:
		check(c._session.request_developer_character_refresh("credited_refresh").success and c._session.get_reward_state().unspent_xp == after.xp.unspent and service._prior.expc_credits == after.expc_credits,"Authorized DEV Refresh neither reapplies the credit nor changes EXPC.")
	var paid := c._session.request_character_advancement(&"attribute",&"spd","grant_funded_spd",{"expected_current_value":11,"expected_cost":5000})
	check(paid.success and paid.get("persistence",{}).get("success",false),"V5 credit funds and persists an ordinary permanent SPD purchase: %s" % paid.get("persistence",paid))
	var bought: Dictionary = f.storage.read_profile(f.profile).payload
	check(bought.xp.unspent == original.xp.unspent+5000 and bought.xp.earned == original.xp.earned and bought.purchases.back().target_id == "spd" and bought.purchases.back().cost == 5000,"SPD spends only its ordinary price and retains EXPM.")
	var exported := CharacterBackupReader.new().begin_export(service)
	var destination := CharacterSaveStorage.new(helper.root.path_join("restore_%d" % version))
	var restore := CharacterBackupRestoration.new()
	check(exported.success and restore.begin(exported.text,"dev_normal",null,destination).success and restore.confirm().success,"V5 grant plus SPD history round-trips through confirmed backup restoration: %s" % exported.get("reason",""))
	restore.dispose()
	check(destination.read_profile(f.profile).get("payload") == bought,"Restored purchases, credit identity and balances are exact.")
	helper.helper._free(scene)
	scene = open(f); c = scene.get_node("CombatController")
	check(c._session.simulation.get_actor_definition(&"player").attributes.spd == 12 and c._session.get_reward_state().unspent_xp == bought.xp.unspent,"V5 reload retains purchased SPD and the credited wallet.")
	var repeated := Grant.new(); repeated.begin(c._session)
	for _i in range(10000):
		if repeated.status.state != "pending": break
		repeated.poll()
	check(repeated.status.state == "already_applied" and f.storage.inspect_profile(f.profile).generations.size() == count+1,"Reloaded grant is a no-op, including after spending part of it.")
	c._offer_run_choice_on_load = true; c._offer_loaded_run_choice(); c._ask_abandon_loaded_run()
	PlayableCharacterPersistence.test_run_id = "run_43g_new_%d" % version
	c._confirm_abandon_loaded_run(1)
	check(c._session._playable_persistence._prior.expc_credits == after.expc_credits and c._session.get_reward_state().unspent_xp == bought.xp.unspent,"NEW RUN retains the single grant and prior SPD spending without paying again.")
	helper.helper._free(scene)

func stale() -> void:
	var f := helper.make_history("dev_normal",Credit.BASELINE,2,"stale")
	var scene := open(f)
	var c: ArenaCombatController = scene.get_node("CombatController")
	c._expc_grant_actions._button.pressed.emit(); pump(c)
	var rival: Dictionary = f.storage.read_profile(f.profile).payload.duplicate(true)
	rival.generation += 1; rival.recovery.player.current_hpc -= 1
	check(f.storage.write_profile(f.profile,rival,"rival_before_credit").success,"Disposable concurrent generation is valid.")
	var before: int = c._session.get_reward_state().unspent_xp
	c._expc_grant_actions._dialog.get_ok_button().pressed.emit()
	check(c._expc_grant_actions._grant.status.state == "recovery_required" and f.storage.read_profile(f.profile).payload == rival and c._session.get_reward_state().unspent_xp == before,"Stale head publication rejects without changing storage or live balances.")
	helper.helper._free(scene)

func browser(fault: String) -> void:
	var f := helper.make_history("dev_normal",Credit.BASELINE,4,"web_"+("ok" if fault.is_empty() else fault))
	var backend := Web.Backend.new()
	backend.histories[f.profile] = f.records.duplicate(true)
	var corrupt_ack := {"enabled":fault == "forged_ack"}
	PlayableBrowserPersistence.test_factory = func():
		return CharacterBrowserStorage.new(func(method: String, args: Dictionary) -> Dictionary:
			var response := backend.transport(method,args)
			if corrupt_ack.enabled and method == "poll" and response.has("document"):
				corrupt_ack.enabled = false
				response.document += " "
			return response
		)
	var scene := open(f,true)
	var c: ArenaCombatController = scene.get_node("CombatController")
	var service := c._session._playable_persistence as PlayableBrowserPersistence
	var before: int = c._session.get_reward_state().unspent_xp
	c._expc_grant_actions._button.pressed.emit(); pump(c)
	check(c._expc_grant_actions._grant.status.state == "confirmation_required" and backend.histories[f.profile] == f.records,"Browser review is read-only and uses its actual loaded namespace/head.")
	if fault in ["lost_ack","abort"]: service.browser.inject_test_fault(fault)
	c._expc_grant_actions._dialog.get_ok_button().pressed.emit()
	check(not c._session.request_character_advancement(&"attribute",&"spd","pending_credit_spd",{"expected_current_value":11,"expected_cost":5000}).success,"A pending grant cannot fund an optimistic purchase.")
	c._on_encounter_button_pressed()
	pump(c)
	if not fault.is_empty():
		check(c._expc_grant_actions._grant.status.state == "recovery_required" and c._session.get_reward_state().unspent_xp == before and service.pending_or_unsecured(),"Interrupted acknowledgment/abort never updates the live balance optimistically.")
		check(backend.histories[f.profile].size() == f.records.size()+(0 if fault == "abort" else 1),"Injected fault has the expected durable outcome.")
		c._expc_grant_actions._dialog.custom_action.emit(&"retry"); pump(c)
	check(c._expc_grant_actions._grant.status.state == "applied" and backend.histories[f.profile].size() == f.records.size()+1 and c._session.get_reward_state().unspent_xp == before+10000 and service._last_ack,"Browser exact retry/readback publishes precisely one credited V5 generation.")
	var replay_snapshot := c._session.simulation.get_state_snapshot()
	var replay_events := c._session.simulation.get_resolved_events().map(func(event): return event.to_dictionary())
	var exact: Array = backend.histories[f.profile].duplicate(true)
	helper.helper._free(scene)
	scene = open(f,true); c = scene.get_node("CombatController")
	check(c._session.get_reward_state().unspent_xp == before+10000 and backend.histories[f.profile] == exact and c._expc_grant_actions._button.disabled,"Cold simulated Web reload retains the grant without another write.")
	if fault.is_empty():
		c._on_encounter_button_pressed(); Web.new().pump(c)
		check(c._session.get_reward_state().unspent_xp == before+10000 and c._session._playable_persistence._prior.expc_credits.records.size() == 1,"Asynchronous NEXT WAVE preserves the V5 wallet and single grant.")
	helper.helper._free(scene)
	if fault.is_empty():
		var replay_backend := Web.Backend.new()
		replay_backend.histories[f.profile] = f.records.duplicate(true)
		PlayableBrowserPersistence.test_factory = func(): return CharacterBrowserStorage.new(replay_backend.transport)
		scene = open(f,true); c = scene.get_node("CombatController")
		c._expc_grant_actions._button.pressed.emit(); pump(c)
		c._expc_grant_actions._dialog.get_ok_button().pressed.emit(); pump(c)
		check(c._session.simulation.get_state_snapshot() == replay_snapshot and c._session.simulation.get_resolved_events().map(func(event): return event.to_dictionary()) == replay_events,"Separate confirmations replay identical combat state, RNG and authoritative credit events.")
		helper.helper._free(scene)
	PlayableBrowserPersistence.test_factory = Callable()
