extends RefCounted
const Backup = preload("res://scripts/rewards/character_backup_contract.gd")
const Task = preload("res://scripts/rewards/character_backup_task.gd")
const Historical = preload("res://tests/test_historical_vaelis_admission.gd")
const Credit = preload("res://scripts/rewards/character_expc_credit.gd")
var failures: Array[String] = []
var assertions := 0
var ticks := 0
var max_tick_us := 0
func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok: failures.append(message)
func drain(task: RefCounted) -> Dictionary:
	for _i in range(10000):
		var before: int = task.job.get("cursor",0)
		var started := Time.get_ticks_usec()
		var result: Dictionary = task.step()
		max_tick_us = maxi(max_tick_us,Time.get_ticks_usec()-started)
		ticks += 1
		if not task.job.is_empty(): check(int(task.job.get("cursor",0))-before <= 1,"A history step validates at most one generation.")
		if result.get("state") != "pending": return result
	return {"success":false,"reason":"diagnostic_step_limit"}
func run() -> Array[String]:
	PlayableCharacterPersistence.test_nonpersistent = false
	var h := Historical.new()
	h.root = OS.get_cache_dir().path_join("itank-storage-tests/backup_progress_%s_%s" % [OS.get_process_id(),Time.get_ticks_usec()])
	var fixture := h.make_history("dev_normal",Credit.BASELINE,4,"perf")
	var history := {"success":true,"generations":fixture.records.duplicate(true)}
	var small: Dictionary = history.duplicate(true)
	var source: Dictionary = fixture.payload.duplicate(true)
	while history.generations.size() < 168:
		source.generation = history.generations.size()+1
		history.generations.append({"generation":source.generation,"transaction_id":"diag_%d" % source.generation,"document":CharacterSaveContract.encode(source).text})
	var bytes := 0
	for row: Dictionary in history.generations: bytes += row.document.to_utf8_buffer().size()
	for index in range(history.generations.size()):
		var padding: int = (16_315_722-bytes)/(history.generations.size()-index)
		history.generations[index].document += "\t".repeat(mini(256,padding))+" ".repeat(maxi(0,padding-256))
		bytes += padding
	var original: Dictionary = history.duplicate(true)
	var begin := Time.get_ticks_usec()
	var sync := Backup.create(history,"dev_normal","2026-11-15T00:00:00Z")
	var sync_ms := (Time.get_ticks_usec()-begin)/1000.0
	check(sync.success,"Synchronous baseline still performs all existing full checks.")
	begin = Time.get_ticks_usec()
	var incremental := Task.new("export","dev_normal",history,"","2026-11-15T00:00:00Z")
	check(incremental.result.get("state") == "pending","Creation returns immediately as pending.")
	var result := drain(incremental)
	var incremental_ms := (Time.get_ticks_usec()-begin)/1000.0
	check(result.success and result.text == sync.text and result.history == sync.history,"Incremental export is byte-equivalent to complete synchronous validation.")
	check(history == original and result.history.size() == 168,"No source/history mutation, truncation or pruning.")
	check(ticks > 168,"Progress yields between generations and bounded scanner slices.")
	var imported := drain(Task.new("decode","dev_normal",{},result.text))
	check(imported.success and imported.history == result.history,"Untrusted import still validates every generation and preserves exact bytes.")
	var corrupted: Dictionary = JSON.parse_string(result.text)
	corrupted.sha256 = "0".repeat(64)
	var rejected := drain(Task.new("decode","dev_normal",{},JSON.stringify(corrupted,"",true,true)))
	check(rejected.get("reason") == "backup_checksum_mismatch","Incremental path rejects corrupt checksums.")
	for text: String in ['{"x":1,"\\u0078":2}',"[".repeat(65)+"]".repeat(65),'["unterminated']:
		var scan := Backup.JsonScan.new(text,Backup.MAX_FILE_BYTES)
		while scan.result.get("state") == "pending": scan.step(1)
		check(not scan.result.success,"One-character scan slices preserve duplicate/depth/truncation rejection.")
	var canceled := Task.new("export","dev_normal",history,"","2026-11-15T00:00:00Z")
	canceled.step(); canceled.cancel()
	check(canceled.step().get("state") == "cancelled" and history == original,"Cancellation does not mutate an input or publish anything.")
	# Real UI controller, disposable storage: progress must pause both clocks.
	PlayableCharacterPersistence.test_storage = fixture.storage
	var scene := h.web.make_scene()
	var c: ArenaCombatController = scene.get_node("CombatController")
	c._admit_existing_profile("dev_normal"); c._resume_loaded_run()
	var state := c._session.get_state_snapshot()
	var motion := c._player.capture_wave_entry_motion()
	c._backup_actions._on_action(&"export")
	var reader := c._backup_actions._reader
	check(c._backup_actions._dialog.visible and reader._result.get("state") == "pending" and c._backup_actions._dialog.dialog_text.contains("Reading saved history"),"Actual SAVE shows visible busy text before expensive processing.")
	c._backup_actions._on_action(&"export")
	check(c._backup_actions._reader == reader,"Repeated SAVE is single-flight.")
	var labels := {}
	for _i in range(10000):
		c._physics_process(1.0)
		c._backup_actions._process(0.0)
		labels[c._backup_actions._dialog.dialog_text] = true
		if reader._result.get("state") != "pending": break
	check(reader._result.get("state") == "export_ready" and labels.size() > 3,"UI advances through multiple actual progress stages.")
	check(c._session.get_state_snapshot() == state and c._player.capture_wave_entry_motion() == motion,"Backup work advances neither combat nor Running clocks/RNG/resources.")
	c._backup_actions._dialog.hide()
	c._backup_actions._on_action(&"export")
	c._backup_actions._close()
	check(c._backup_actions._reader == null and CharacterSaveStorage.history_records(fixture.storage.inspect_profile(fixture.profile)) == small.generations,"UI cancellation leaves storage and character history unchanged.")
	h.helper._free(scene)
	PlayableCharacterPersistence.test_storage = null
	PlayableCharacterPersistence.test_nonpersistent = true
	PlayableCharacterPersistence.test_run_id = ""
	h.helper._remove_fixture(h.root)
	print("43E backup: raw=%d file=%d synchronous_ms=%.2f incremental_ms=%.2f max_step_ms=%.2f steps=%d; %d assertions." % [bytes,result.text.to_utf8_buffer().size(),sync_ms,incremental_ms,max_tick_us/1000.0,ticks,assertions])
	return failures
