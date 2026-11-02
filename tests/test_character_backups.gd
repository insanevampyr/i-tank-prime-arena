extends RefCounted

const Backup = preload("res://scripts/rewards/character_backup_contract.gd")
const Reader = preload("res://scripts/rewards/character_backup_reader.gd")
const Files = preload("res://scripts/ui/character_backup_files.gd")
const PlayableTests = preload("res://tests/test_playable_vaelis_persistence.gd")
const BrowserTests = preload("res://tests/test_playable_browser_persistence.gd")
const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
var failures: Array[String] = []

class SpyStorage extends CharacterSaveStorage:
	var writes := 0
	func _init(root: String) -> void: super(root)
	func write_profile(profile: String, payload: Dictionary, transaction: String) -> Dictionary:
		writes += 1
		return super.write_profile(profile,payload,transaction)

func run() -> Array[String]:
	var root := OS.get_cache_dir().path_join("itank-storage-tests/backup_%s_%s" % [OS.get_process_id(),Time.get_ticks_usec()])
	var storage := SpyStorage.new(root)
	PlayableCharacterPersistence.test_storage = storage
	PlayableCharacterPersistence.test_nonpersistent = false
	PlayableCharacterPersistence.test_run_id = "run_backup_test"
	var helper := PlayableTests.new()
	var scene := helper._scene()
	var c: ArenaCombatController = scene.get_node("CombatController")
	c.set_physics_process(false)
	c._encounter_selector_index = 8
	var selected := c.select_player_character_for_testing(Fixture.PLAYER_CHARACTER_VAELIS)
	check(selected.success,"Actual desktop admission must create the disposable profile.")
	if selected.success:
		var session := c._session
		var ready_before := session.get_state_snapshot()
		c._on_inventory_toggle_pressed()
		var ready_controls := c._rewards_label.get_parent().get_node("CharacterBackupControls")
		check(ready_controls.is_visible_in_tree() and ready_controls.get_index() == 1,"Loaded READY character must expose backup controls before expandable inventory sections.")
		check(session.get_state_snapshot() == ready_before,"Opening character management must not mutate the admitted character.")
		c._on_inventory_toggle_pressed()
		session.set_opponent_behavior_enabled(false)
		c._on_encounter_button_pressed()
		c._backup_actions._update_controls()
		check(ready_controls.get_node("ExportBackup").disabled and ready_controls.get_node("PreviewRestoreBackup").disabled,"Both backup controls must be unavailable during active combat.")
		helper._defeat_wave(session)
		# Shared source-valid inventory and wear pathways, not fabricated backup data.
		var origin := session.simulation.record_reward_event(&"reward_backup_item_fixture",&"player",&"player",{})
		for ref: String in ["health_potion","prime_v3_metal_buckler"]:
			session.simulation.create_ground_loot_item("backup_"+ref,{"definition_id":ref,"quantity":10 if ref == "health_potion" else 1,"display_name":ref,"item_kind":"potion" if ref == "health_potion" else "equipment","source_ref":"PRIME-V3 pp. 120, 137; isolated backup fixture"},session.get_actor_state(&"player").position_microfeet,&"player",origin.event_id)
		check(session.collect_all_ground_loot().success,"Collected ownership must be established by a real transaction.")
		check(session.request_player_inventory_equip(&"prime_v3_metal_buckler","backup_equip").success,"Source-backed shield fixture must equip legally.")
		for wave in range(2):
			check(session.request_next_wave().success,"Progression fixture advances through actual NEXT WAVE.")
			session.set_opponent_behavior_enabled(false)
			helper._defeat_wave(session)
		check(helper._failures.is_empty(),"Existing physical-combat fixture must succeed: %s" % [helper._failures])
		var purchase := session.request_character_advancement(&"special_resistance",&"sr","backup_purchase")
		check(purchase.success,"Verified SR purchase must be secured before backup: %s" % purchase)
		var service := session._playable_persistence
		c._update_presentation()
		var controls := c._rewards_label.get_parent().get_node("CharacterBackupControls")
		check(controls.is_visible_in_tree() and controls.get_node("ExportBackup").is_visible_in_tree() and controls.get_node("PreviewRestoreBackup").is_visible_in_tree(),"Actual downtime panel must expose both backup buttons outside collapsed sections.")
		controls.get_node("ExportBackup").pressed.emit()
		check(c._backup_actions.last_result.get("state") == "export_ready" and c._backup_actions._dialog.visible,"Visible EXPORT BACKUP button must open the existing verified export path.")
		c._backup_actions._dialog.hide()
		check(service._last_ack,"Fixture must end with a verified committed checkpoint.")
		var before := session.get_state_snapshot()
		var draw_count := session.simulation.random.get_draw_count()
		var writes_before := storage.writes
		var service_before := service._prior.duplicate(true)
		var history := storage.inspect_profile(service.profile_id)
		var reader := Reader.new()
		var exported := reader.begin_export(service)
		check(exported.get("success",false),"Full durable history must export: %s" % exported.get("reason",""))
		if exported.get("success",false):
			check(exported.history.size() == history.generations.size() and exported.history.size() > 2,"Every generation must be preserved.")
			for index in range(exported.history.size()):
				check(exported.history[index].document == history.generations[index].document and exported.history[index].transaction_id == history.generations[index].transaction_id,"Exact original bytes and transactions roundtrip.")
			check(exported.payload == CharacterSaveContract.decode(CharacterSaveContract.encode(service_before).text).payload and exported.payload.purchases.size() > 0 and exported.payload.permanent.growth.size() > 0,"XP/purchases/growth/equipment/resources/loot/receipts roundtrip losslessly.")
			var output := root.path_join("verified.itankbackup.json")
			check(Files.save_new_file(output,exported.text).success,"Desktop output must write and verify exact bytes.")
			check(not Files.save_new_file(output,exported.text).success,"Export must not overwrite an existing backup.")
			var readback := Files.read_file(output)
			check(readback.success and readback.text == exported.text,"Desktop file selection/readback is exact.")
			_test_contract(exported,history)
			var preview := Reader.new().begin_preview(readback.text,"dev_normal",storage)
			check(preview.get("success",false) and preview.classification == "exact_match" and preview.read_only,"Desktop preview compares without restoration.")
			c._backup_actions._namespace = "dev_normal"
			c._backup_actions.preview_text(readback.text)
			check(c._backup_actions.last_result.get("classification") == "exact_match" and c._backup_actions._dialog.dialog_text.contains("READ ONLY"),"Actual character-actions preview exposes comparison and no restore control.")
			c._backup_actions._dialog.hide()
			_test_browser(exported,history,service)
		check(session.get_state_snapshot() == before and service._prior == service_before and session.simulation.random.get_draw_count() == draw_count,"Backup/preview cannot mutate session, progression, RNG or history.")
		check(storage.writes == writes_before and storage.inspect_profile(service.profile_id) == history,"Export/preview must perform ZERO persistent writes.")
		var acknowledged: bool = service._last_ack
		service._last_ack = false
		check(not Reader.new().begin_export(service).success,"Unacknowledged export must fail closed.")
		service._last_ack = acknowledged
		check(not Reader.new().begin_export(null).success,"Nonpersistent actors cannot export fabricated profiles.")
		var reopened_scene := helper._scene()
		var reopened_controller: ArenaCombatController = reopened_scene.get_node("CombatController")
		reopened_controller._encounter_selector_index = 8
		check(reopened_controller.select_player_character_for_testing(Fixture.PLAYER_CHARACTER_VAELIS).success,"Existing disposable profile must reopen through actual character selection.")
		var reexport := Reader.new().begin_export(reopened_controller._session._playable_persistence)
		check(reexport.get("success",false) and reexport.history == exported.get("history"),"A verified loaded profile exports without requiring a new write acknowledgement.")
		helper._free(reopened_scene)
	helper._free(scene)
	PlayableCharacterPersistence.test_storage = null
	PlayableCharacterPersistence.test_nonpersistent = true
	PlayableCharacterPersistence.test_run_id = ""
	helper._remove_fixture(root)
	return failures

func _test_contract(exported: Dictionary, history: Dictionary) -> void:
	var text: String = exported.text
	check(Backup.decode(text,"dev_normal").get("success",false),"Complete canonical container must validate.")
	check(not Backup.decode(text,"normal").success,"DEV cannot be cloned to NORMAL.")
	for bad: String in [text.substr(0,text.length()-5),"{}",text.replace('"backup_version":1','"backup_version":2'),text.replace('"sha256":"','"sha256":"0')]:
		check(not Backup.decode(bad,"dev_normal").success,"Truncated, malformed, future and tampered containers must be rejected.")
	check(not Backup.decode('{"format":"x","format":"y"}',"dev_normal").success,"Duplicate JSON keys must not be silently accepted.")
	check(not Backup.scan_json("[".repeat(65)+"]".repeat(65)).success,"Depth limit must precede parsing.")
	check(not Backup.scan_json(" ".repeat(Backup.MAX_BYTES+1)).success,"Size limit must fail explicitly.")
	check(not Backup.valid_date("2026-02-31T00:00:00Z"),"Invalid informational dates are rejected.")
	var duplicate: Dictionary = exported.manifest.duplicate(true)
	duplicate.generations[1].transaction_id = duplicate.generations[0].transaction_id
	check(not Backup.decode(pack(duplicate),"dev_normal").success,"Duplicate transaction identities must fail.")
	var repeated_receipt: Dictionary = exported.manifest.duplicate(true)
	var receipt_payload: Dictionary = CharacterSaveContract.decode(repeated_receipt.generations.back().document).payload
	check(not receipt_payload.settlements.is_empty(),"Physical victory must supply receipts for duplicate validation.")
	if not receipt_payload.settlements.is_empty():
		receipt_payload.settlements.append(receipt_payload.settlements[0].duplicate(true))
		var envelope: Dictionary = JSON.parse_string(repeated_receipt.generations.back().document)
		envelope.payload_json = JSON.stringify(receipt_payload,"",true,true)
		envelope.sha256 = envelope.payload_json.sha256_text()
		repeated_receipt.generations.back().document = JSON.stringify(envelope,"",true,true)
		check(not Backup.decode(pack(repeated_receipt),"dev_normal").success,"Recomputed backup checksums cannot authorize duplicate settlement receipts.")
	var missing: Dictionary = exported.manifest.duplicate(true)
	missing.generations.remove_at(1)
	check(not Backup.decode(pack(missing),"dev_normal").success,"History gaps must fail.")
	var illegal: Dictionary = exported.manifest.duplicate(true)
	var payload: Dictionary = CharacterSaveContract.decode(illegal.generations.back().document).payload
	payload.recovery.player_position = [30000000,10000000]
	illegal.generations.back().document = CharacterSaveContract.encode(payload).text
	check(not Backup.decode(pack(illegal),"dev_normal").success,"Even a recomputed checksum cannot admit an illegal checkpoint position.")
	# Independent, explicitly authored damaged-condition input. This tests backup
	# representation, not whether Vaelis has proficiency to execute a shield Block.
	var worn: Dictionary = exported.manifest.duplicate(true)
	var worn_payload: Dictionary = CharacterSaveContract.decode(worn.generations.back().document).payload
	for item: Dictionary in worn_payload.items:
		if item.definition_id == "prime_v3_metal_buckler": item.mutable_state.shp = 19
	worn.generations.back().document = CharacterSaveContract.encode(worn_payload).text
	var worn_text := pack(worn)
	var worn_checked := Backup.decode(worn_text,"dev_normal")
	check(worn_checked.success and worn_checked.payload == worn_payload and worn_checked.history.back().document == worn.generations.back().document,"A valid worn-shield record preserves exact SHP, ownership and original document bytes.")
	check(Backup.compare(exported,{"success":true,"generations":[]},"dev_normal") == "empty_destination","Missing destination is classified without creating it.")
	check(Backup.compare(exported,{"success":false},"dev_normal") == "corrupt_or_uncertain_destination","Read failure is not missing.")
	var prefix := history.duplicate(true)
	prefix.generations.pop_back()
	check(Backup.compare(exported,prefix,"dev_normal") == "destination_exact_prefix","Exact prefix classification.")
	var older := Backup.create(prefix,"dev_normal","2026-10-30T00:00:00Z")
	check(older.success and Backup.compare(older,history,"dev_normal") == "backup_older_than_destination","Older backup never replaces newer history.")
	var divergent := history.duplicate(true)
	divergent.generations[0].transaction_id = "different_valid_transaction"
	check(Backup.compare(exported,divergent,"dev_normal") == "divergent_history","Divergent identities remain distinct.")

func _test_browser(exported: Dictionary, history: Dictionary, service: PlayableCharacterPersistence) -> void:
	var backend := BrowserTests.Backend.new()
	backend.histories[service.profile_id] = exported.history.duplicate(true)
	var methods: Array[String] = []
	var transport := func(method: String, args: Dictionary) -> Dictionary:
		if method == "begin": methods.append(args.operation)
		return backend.transport(method,args)
	var browser := CharacterBrowserStorage.new(transport)
	var reader := Reader.new()
	var result := reader.begin_preview(exported.text,"dev_normal",null,browser)
	check(result.get("state") == "pending","Web preview is asynchronous.")
	result = reader.poll()
	check(result.get("classification") == "exact_match","Web durable inspection matches exact backup.")
	var web := PlayableBrowserPersistence.new()
	web.browser = browser; web.mode = service.mode; web.profile_id = service.profile_id
	web.generation = service.generation; web._prior = service._prior.duplicate(true)
	web._prepared = service._prepared.duplicate(true); web._last_ack = true
	web._status = service.status(); web._owns_lease = true
	web._browser_result = {"state":"verified_committed"}
	var export_reader := Reader.new()
	result = export_reader.begin_export(web)
	check(result.get("state") == "pending","Web export begins with a durable read, not optimistic success.")
	result = export_reader.poll()
	check(result.get("success",false) and result.history == exported.history,"Web and Desktop export identical character history.")
	for state: String in ["pending","failed","unavailable","recovery_required"]:
		web._browser_result = {"state":state}
		check(not Reader.new().begin_export(web).success,"Web export blocks "+state)
	web._prepared = {}; web._last_ack = false
	web._status = {"persistent":true,"reason":"validated_profile_loaded"}
	web._browser_result = {"state":"loaded"}
	var loaded_reader := Reader.new()
	check(loaded_reader.begin_export(web).get("state") == "pending" and loaded_reader.poll().get("success",false),"Verified browser reload can export the original committed history without publishing again.")
	check(methods.all(func(value: String) -> bool: return value == "inspect"),"Web export/preview may invoke ONLY inspect, never publish/acquire/restore.")
	check(backend.histories[service.profile_id] == exported.history and history.generations.size() == exported.history.size(),"Browser inspection cannot modify generation history.")

func pack(body: Dictionary) -> String:
	var json := JSON.stringify(body,"",true,true)
	return JSON.stringify({"format":Backup.FORMAT,"backup_version":1,"body_json":json,"sha256":json.sha256_text()},"",true,true)

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
