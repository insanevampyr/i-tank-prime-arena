extends RefCounted

const Backup = preload("res://scripts/rewards/character_backup_contract.gd")
const Restore = preload("res://scripts/rewards/character_backup_restoration.gd")
const Playable = preload("res://tests/test_playable_vaelis_persistence.gd")
const WebTests = preload("res://tests/test_playable_browser_persistence.gd")
const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
var failures: Array[String] = []
var helper := Playable.new()
var roots: Array[String] = []

class Backend extends WebTests.Backend:
	var operations: Array[String] = []
	func execute(operation: String, args: Dictionary) -> Dictionary:
		operations.append(operation)
		if operation != "restore": return super.execute(operation,args)
		if locks.get(args.profile) != args.owner: return result("unavailable","writer_lock_required")
		var history: Array = histories.get(args.profile,[])
		if history == args.records: return {"success":true,"state":"verified_committed","missing":false,"generations":history.duplicate(true)}
		if history != args.expected or args.records.slice(0,history.size()) != history: return result("failed","stale_generation")
		if args.get("fault") in ["abort","quota"]: return result("failed","injected_restoration_abort")
		histories[args.profile] = args.records.duplicate(true)
		if args.get("fault") in ["lost_ack","readback_mismatch"]: return result("recovery_required",args.fault)
		return {"success":true,"state":"verified_committed","missing":false,"generations":args.records.duplicate(true)}

func run() -> Array[String]:
	PlayableCharacterPersistence.test_nonpersistent = false
	var source := make_storage("source")
	PlayableCharacterPersistence.test_storage = source
	var scene := helper._scene()
	var c: ArenaCombatController = scene.get_node("CombatController")
	c._encounter_selector_index = 8
	check(c.select_player_character_for_testing(&"vaelis_thorn").success,"Disposable source admission.")
	c._on_encounter_button_pressed()
	c._session.set_opponent_behavior_enabled(false)
	helper._defeat_wave(c._session)
	check(helper._failures.is_empty(),"Source physical-combat fixture remains legal.")
	var exported := CharacterBackupReader.new().begin_export(c._session._playable_persistence)
	check(exported.get("success",false) and exported.history.size() > 1,"Actual committed multi-generation source exports.")
	helper._free(scene)
	if exported.get("success",false):
		test_native(exported)
		test_web(exported)
		check(not Restore.new().begin(exported.text,"normal",null,make_storage("namespace")).success,"Wrong namespace rejected before ownership/publication.")
		check(not Restore.new().begin(exported.text.left(30),"dev_normal",null,make_storage("corrupt")).success,"Truncated/checksum-invalid backup rejected.")
	PlayableCharacterPersistence.test_storage = null
	PlayableCharacterPersistence.test_nonpersistent = true
	PlayableBrowserPersistence.test_factory = Callable()
	for root: String in roots: helper._remove_fixture(root)
	return failures

func test_native(exported: Dictionary) -> void:
	var destination := make_storage("ui")
	PlayableCharacterPersistence.test_storage = destination
	var scene := helper._scene()
	var c: ArenaCombatController = scene.get_node("CombatController")
	c._encounter_selector_index = 8
	check(c._session.configure_reward_mode("dev_normal").success,"Matching destination namespace selected.")
	var original := c._session.get_state_snapshot()
	var actions := c._backup_actions
	actions._namespace = "dev_normal"
	actions.preview_text(exported.text)
	check(actions.last_result.get("classification") == "empty_destination" and c._session.get_state_snapshot() == original,"Actual empty-destination UI preview is read-only.")
	actions._dialog.custom_action.emit(&"restore")
	check(actions._confirmation.visible and actions.restoration_blocked and actions._restore_button.text == "CONFIRM LOAD" and actions._confirmation.get_ok_button().text == "CONFIRM LOAD","CONFIRM LOAD acquires ownership then requires separate explicit confirmation.")
	check(actions._confirmation.title == "Confirm Load Character" and actions._confirmation.dialog_text.contains("Older saves and saves with conflicting history cannot replace your progress"),"Load confirmation must explain compatibility and no-overwrite protections.")
	actions._confirmation.get_cancel_button().pressed.emit()
	check(not actions.restoration_blocked and destination.inspect_profile("dev_vaelis_thorn").generations.is_empty() and c._session.get_state_snapshot() == original,"Actual CANCEL preserves destination and gameplay.")
	check(actions._dialog.dialog_text == "Load canceled. Your character was not changed.","Canceled confirmation must use clear no-change language.")
	actions._dialog.custom_action.emit(&"restore")
	actions._confirmation.get_ok_button().pressed.emit()
	check(actions.last_result.get("state") == "verified_committed","Actual confirmation publishes and acknowledges complete history.")
	var loaded := c._session._playable_persistence
	check(loaded != null and loaded._prior == exported.payload,"Actual playable admission restores exact permanent/checkpoint data.")
	var actor := c._session.get_actor_state(&"player")
	check(actor.current_hpc == exported.payload.recovery.player.current_hpc and actor.resources == exported.payload.recovery.player.resources and actor.persistent_damage_shields == exported.payload.recovery.player.persistent_damage_shields,"Live checkpoint resources and protection are restored without refilling.")
	check(CharacterSaveStorage.history_records(destination.inspect_profile(exported.manifest.profile_id)) == exported.history,"Native restoration retains exact original transactions and documents.")
	var sync := TwoClientSyncHarness.new(1)
	var batch := c._session.simulation.get_resolved_events_from(0)
	var envelopes: Array = []
	for event: CombatEvent in batch.events: envelopes.append(CombatEventEnvelope.new(envelopes.size(),event.to_dictionary(),c._session.simulation.get_state_snapshot()))
	sync.deliver_in_order(envelopes)
	check(sync.compare_clients().success and c._session.simulation.get_resolved_event_count() == batch.next_cursor,"Restored playable session converges without draining its authoritative history.")
	var before := c._session.get_state_snapshot()
	actions.preview_text(exported.text)
	actions._dialog.custom_action.emit(&"restore")
	actions._confirmation.get_ok_button().pressed.emit()
	check(CharacterSaveStorage.history_records(destination.inspect_profile(exported.manifest.profile_id)) == exported.history,"Repeated restore is an exact no-op; no duplicate rewards/items or starter grants.")
	check(c._session.get_state_snapshot() == before,"Replaying the same verified checkpoint reproduces the complete authoritative snapshot/event ordering.")
	check(c._session.get_state_snapshot().schema_version == 12 and before.schema_version == 12,"Restoration leaves schema 12 unchanged.")
	check(c._session.request_next_wave().success,"Normal publication/NEXT WAVE works after bundled restoration.")
	check(destination.inspect_profile(exported.manifest.profile_id).success,"Subsequent native generation remains a contiguous coherent history.")
	helper._free(scene)
	var prefix := prefix_backup(exported)
	for fault: String in ["abort","lost_ack","readback_mismatch","interrupted"]:
		var store := make_storage(fault)
		var seed := Restore.new()
		check(seed.begin(prefix.text,"dev_normal",null,store).success and seed.confirm().success,"Prepare known verified destination prefix: "+fault)
		seed.dispose()
		var restorer := Restore.new()
		check(restorer.begin(exported.text,"dev_normal",null,store).get("classification") == "destination_exact_prefix","Prefix-only eligibility.")
		var rival := CharacterSaveStorage.new(store._root)
		check(not rival.acquire_writer(exported.manifest.profile_id).success,"Another desktop writer cannot enter while awaiting confirmation.")
		store.inject_restoration_test_fault(fault)
		check(not restorer.confirm().success and restorer.uncertain,"Injected publication must not report success: "+fault)
		var history := store.inspect_owned(exported.manifest.profile_id,restorer._owner)
		if fault == "abort":
			check(CharacterSaveStorage.history_records(history) == prefix.history,"Abort preserves the old checkpoint exactly.")
			check(restorer.reconcile().get("state") == "confirmation_required","Known-unpublished abort requires a new explicit confirmation.")
		elif fault == "interrupted":
			check(history.pending_write and CharacterSaveStorage.history_records(history) == prefix.history,"Incomplete staging preserves prior checkpoint and blocks admission.")
			check(not restorer.reconcile().success,"Interrupted staging is not silently treated as success or a missing character.")
		else:
			check(restorer.reconcile().success and CharacterSaveStorage.history_records(history) == exported.history,"Fresh readback reconciles exact committed data without duplicate publication: "+fault)
		restorer.dispose()
	var stale_store := make_storage("stale")
	var stale := Restore.new()
	stale.begin(exported.text,"dev_normal",null,stale_store)
	stale_store.release_writer(exported.manifest.profile_id,stale._owner)
	check(not stale.confirm().success,"Lost desktop ownership rejects publication.")
	stale.dispose()
	var newer := Restore.new()
	newer.begin(exported.text,"dev_normal",null,stale_store); newer.confirm(); newer.dispose()
	var old := Restore.new()
	check(not old.begin(prefix.text,"dev_normal",null,stale_store).success,"Older backup cannot replace a newer verified destination.")
	old.dispose()
	var changed: Array = exported.history.duplicate(true)
	changed[0].transaction_id = "another_valid_original_transaction"
	var divergent := Backup.create({"success":true,"generations":changed},"dev_normal","2026-10-31T00:00:00Z")
	var conflict := Restore.new()
	check(divergent.success and conflict.begin(divergent.text,"dev_normal",null,stale_store).get("reason") == "divergent_history","A structurally valid divergent history cannot replace current progression.")
	conflict.dispose()

func test_web(exported: Dictionary) -> void:
	var backend := Backend.new()
	PlayableBrowserPersistence.test_factory = func() -> CharacterBrowserStorage: return CharacterBrowserStorage.new(backend.transport)
	var scene := helper._scene()
	var c: ArenaCombatController = scene.get_node("CombatController")
	c._encounter_selector_index = 8
	c._session.configure_reward_mode("dev_normal")
	var actions := c._backup_actions
	actions._namespace = "dev_normal"
	actions.preview_text(exported.text)
	pump(c)
	check(actions.last_result.get("classification") == "empty_destination","Async UI preview recognizes a verified missing destination.")
	actions._dialog.custom_action.emit(&"restore")
	pump(c)
	check(actions._confirmation.visible,"Async restore awaits explicit confirmation, not optimistic publication.")
	var old_session := c._session
	var original := old_session.get_state_snapshot()
	actions._confirmation.get_ok_button().pressed.emit()
	check(actions.restoration_blocked,"Browser publication keeps conflicting controls locked.")
	c._physics_process(1.0)
	check(old_session.get_state_snapshot() == original and not c._player.is_physics_processing(),"Pending restoration freezes combat and the independent movement model.")
	pump(c)
	check(actions.last_result.get("state") == "verified_committed" and c._web_operation.is_empty(),"UI restoration awaits exact readback and existing async admission.")
	check(c._session._playable_persistence._prior == exported.payload,"Web UI hydrates the same exact payload as desktop.")
	var reader := CharacterBackupReader.new()
	check(reader.begin_export(c._session._playable_persistence).get("state") == "pending" and reader.poll().get("success",false),"Transferred restored profile remains acknowledged/persistent and immediately exportable.")
	check(backend.histories[exported.manifest.profile_id] == exported.history,"Web original transactions and receipts preserved exactly.")
	check(backend.operations.has("restore") and backend.operations.count("inspect") >= 4,"Fresh independent destination/readback/admission inspections occur.")
	helper._free(scene)
	for fault: String in ["abort","quota","lost_ack","readback_mismatch"]:
		var own_backend := Backend.new()
		var adapter := CharacterBrowserStorage.new(own_backend.transport)
		var restorer := Restore.new()
		restorer.begin(exported.text,"dev_normal",null,null,adapter)
		pump_restorer(restorer)
		adapter.inject_test_fault(fault)
		restorer.confirm()
		pump_restorer(restorer)
		check(not restorer.status.success and restorer.uncertain,"Web failure is not a success acknowledgement: "+fault)
		restorer.reconcile(); pump_restorer(restorer)
		check(restorer.status.state == ("confirmation_required" if fault in ["abort","quota"] else "verified_committed"),"Async recovery distinguishes unchanged from exactly committed data: "+fault)
		restorer.dispose()
	PlayableBrowserPersistence.test_factory = Callable()

func pump(c: ArenaCombatController) -> void:
	for index in range(90):
		c._backup_actions._process(0.0)
		c._physics_process(0.0)

func pump_restorer(restorer: CharacterBackupRestoration) -> void:
	for index in range(20):
		if restorer.status.state != "pending": break
		restorer.poll()

func prefix_backup(exported: Dictionary) -> Dictionary:
	return Backup.create({"success":true,"generations":exported.history.slice(0,1)},"dev_normal","2026-10-31T00:00:00Z")

func make_storage(label: String) -> CharacterSaveStorage:
	var path := OS.get_cache_dir().path_join("itank-storage-tests/restore_%s_%s_%s" % [label,OS.get_process_id(),Time.get_ticks_usec()])
	roots.append(path)
	return CharacterSaveStorage.new(path)

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
