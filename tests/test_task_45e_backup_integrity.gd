extends RefCounted
const Backup = preload("res://scripts/rewards/character_backup_contract.gd")
const Task = preload("res://scripts/rewards/character_backup_task.gd")
const Historical = preload("res://tests/test_historical_vaelis_admission.gd")
var failures: Array[String] = []
var assertions := 0
func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok: failures.append(message)
func drain(task: RefCounted) -> Dictionary:
	for i in range(10000):
		var result: Dictionary = task.step()
		if result.get("state") != "pending": return result
	return Backup.fail("diagnostic_step_limit")
func run() -> Array[String]:
	# Every possible small slice must keep escape/key state. The same lexical
	# rejection gates precede native JSON grammar parsing for all imported files.
	var good := JSON.stringify({"unicode":"Ω😀","slashes":"\\".repeat(9000),"quoted":"x\"y","nested":[{"a":1}]})
	for budget in [1,2,3,7,31,8191,8192,16383,32768,1048576]:
		var scan := Backup.JsonScan.new(good,Backup.MAX_FILE_BYTES)
		check(Backup.JsonScan.string_run.is_valid() and Backup.JsonScan.space_run.is_valid(),"Scanner regex initialization must execute independently of debug assertions.")
		while scan.result.get("state") == "pending": scan.step(budget)
		check(scan.result.success,"Bounded scans preserve long escapes/Unicode at slice %s." % budget)
		for bad: String in ['{"a":1,"\\u0061":2}','{"x":"unterminated',"[".repeat(65)+"]".repeat(65)]:
			scan = Backup.JsonScan.new(bad,Backup.MAX_FILE_BYTES)
			while scan.result.get("state") == "pending": scan.step(budget)
			check(not scan.result.success,"Duplicate/depth/truncated input stays rejected at slice %s." % budget)
	var valid_spaces: RegEx = Backup.JsonScan.space_run
	Backup.JsonScan.space_run = RegEx.new()
	var unavailable := Backup.JsonScan.new("{}",Backup.MAX_FILE_BYTES)
	check(unavailable.result.get("reason") == "backup_scanner_unavailable","Invalid scanner initialization fails closed before any regex search.")
	Backup.JsonScan.space_run = valid_spaces
	PlayableCharacterPersistence.test_nonpersistent = false
	var h := Historical.new()
	h.root = OS.get_cache_dir().path_join("itank-storage-tests/backup45e_%s_%s" % [OS.get_process_id(),Time.get_ticks_usec()])
	var fixture := h.make_history("dev_normal","3df0412b72ba5d966b2eb645887fedfbb591782cffc7bff41c192e52583c6d20",4,"integrity")
	check(fixture.get("success",false),"Disposable verified historical fixture.")
	if not fixture.get("success",false): return failures
	var history := {"success":true,"generations":fixture.records.duplicate(true)}
	var original := history.duplicate(true)
	var task := Task.new("export","dev_normal",history,"","2026-11-15T00:00:00Z")
	var encoded := drain(task)
	check(encoded.success and Backup.decode(encoded.text,"dev_normal").success,"Constructed output independently passes the COMPLETE untrusted decoder.")
	check(task.text.is_empty() and task.job.is_empty() and task.history.is_empty() and task.checked.is_empty() and task.scan == null,"Completed task releases private working buffers even while the task is retained.")
	var imported := drain(Task.new("decode","dev_normal",{},encoded.text))
	check(imported.success and imported.history == fixture.records and history == original,"Full import, immutable snapshot and canonical bytes remain equivalent.")
	var empty := CharacterSaveStorage.new(h.root.path_join("empty"))
	var reader := CharacterBackupReader.new()
	check(reader.begin_preview(encoded.text,"dev_normal",empty).read_only,"Preview is read-only.")
	check(not reader.validated_preview(encoded.text+" ","dev_normal").success and not reader.validated_preview(encoded.text,"normal").success,"Changed text and namespace cannot reuse a verified result.")
	var fresh := CharacterBackupReader.new()
	check(not fresh.validated_preview(encoded.text,"dev_normal").success,"A new/unverified reader cannot attest imported data.")
	fresh.dispose()
	var restorer := CharacterBackupRestoration.new()
	check(restorer.begin(encoded.text,"dev_normal",null,empty,null,reader).state == "confirmation_required","Typed exact preview handoff still requires explicit confirmation.")
	reader.dispose()
	check(reader._backup.is_empty() and reader._verified_text.is_empty(),"Disposed reader releases selected text and parsed generations.")
	restorer.backup.payload.xp.unspent += 1
	check(restorer.confirm().get("reason") == "backup_changed" and empty.inspect_profile(fixture.profile).generations.is_empty(),"Mutated cached payload is rejected before any write.")
	restorer.dispose()
	for mutation: String in ["text","document","transaction","header","preview"]:
		var destination := CharacterSaveStorage.new(h.root.path_join(mutation))
		restorer = CharacterBackupRestoration.new()
		check(restorer.begin(encoded.text,"dev_normal",null,destination).success,"Fresh validation for each isolated restoration.")
		match mutation:
			"text": restorer._text += " "
			"document": restorer.backup.history.back().document += " "
			"transaction": restorer.backup.history.back().transaction_id = "tampered"
			"header": restorer.backup.manifest.head_generation += 1
			"preview": restorer.backup.preview.level += 1
		check(restorer.confirm().get("reason") == "backup_changed" and destination.inspect_profile(fixture.profile).generations.is_empty(),"No changed/forged cached evidence bypasses validation: "+mutation)
		restorer.dispose()
	for mutation: String in ["header","document","payload"]:
		reader = CharacterBackupReader.new()
		check(reader.begin_preview(encoded.text,"dev_normal",empty).read_only,"Each preview reuse begins with complete fresh validation.")
		match mutation:
			"header": reader._backup.manifest.created_utc = "2026-11-16T00:00:00Z"
			"document": reader._backup.history.back().document += " "
			"payload": reader._backup.payload.xp.unspent += 1
		check(not reader.validated_preview(encoded.text,"dev_normal").success,"Changed reader metadata/record bytes cannot attest a cached preview: "+mutation)
		reader.dispose()
	# Confirmed data are read back exactly, then large source representations are
	# released even if the UI keeps the completed coordinator alive.
	restorer = CharacterBackupRestoration.new()
	check(restorer.begin(encoded.text,"dev_normal",null,empty).success and restorer.confirm().success,"Actual filesystem restoration remains verified.")
	check(restorer._text.is_empty() and restorer._validated_text.is_empty() and not restorer.backup.has("history") and restorer._expected.is_empty(),"Completed restoration retains no complete backup strings/history.")
	check(CharacterSaveStorage.history_records(empty.inspect_profile(fixture.profile)) == fixture.records,"All generations, receipts, credits and inventory bytes are preserved.")
	restorer.dispose()
	var changed: Dictionary = JSON.parse_string(encoded.text)
	changed.sha256 = "0".repeat(64)
	check(not drain(Task.new("decode","dev_normal",{},JSON.stringify(changed,"",true,true))).success,"Corrupt container hashes still fail full import validation.")
	reader = CharacterBackupReader.new()
	reader.begin_preview(encoded.text,"dev_normal",empty,null,true)
	reader.poll(); reader.cancel_read_only()
	check(reader._backup.is_empty() and reader._verified_text.is_empty() and reader.poll().state == "cancelled","Canceled preview releases data and cannot publish.")
	reader.dispose()
	PlayableCharacterPersistence.test_storage = fixture.storage
	var scene := h.web.make_scene()
	var controller: ArenaCombatController = scene.get_node("CombatController")
	check(controller._admit_existing_profile("dev_normal").success,"Disposable UI admits the verified profile without altering history.")
	controller._resume_loaded_run()
	var actions: CharacterBackupActions = controller._backup_actions
	var previous_reader := CharacterBackupReader.new()
	previous_reader._backup = imported
	actions._reader = previous_reader
	actions._export = encoded
	actions.last_result = encoded.duplicate(true)
	actions._preview_source = encoded.text
	actions._on_action(&"export")
	check(actions._reader != previous_reader and actions._export.is_empty() and actions.last_result.is_empty() and actions._preview_source.is_empty() and previous_reader._backup.is_empty(),"Starting the next SAVE releases the previous complete output before constructing another.")
	actions._close(false)
	h.helper._free(scene)
	h.helper._remove_fixture(h.root)
	PlayableCharacterPersistence.test_storage = null
	PlayableCharacterPersistence.test_nonpersistent = true
	PlayableCharacterPersistence.test_run_id = ""
	print("45E backup integrity: %d assertions." % assertions)
	return failures
