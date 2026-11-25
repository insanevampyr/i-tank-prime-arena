extends SceneTree
# Opt-in diagnostic only: --script tests/benchmark_task_45e.gd -- setup
# then -- small / 168 / 221. Disposable OS-cache fixtures, never owner storage.
# The large fixtures repeat verified generations with legal whitespace padding;
# they reproduce byte volume/depth, not the owner's unseen progression contents.
# Tight CPU polling excludes browser frame waits and actual IndexedDB latency.
const CharacterExpcCredit = preload("res://scripts/rewards/character_expc_credit.gd")
const H = preload("res://tests/test_historical_vaelis_admission.gd")
const Backup = preload("res://scripts/rewards/character_backup_contract.gd")
const Task = preload("res://scripts/rewards/character_backup_task.gd")
const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
class ReadStorage extends CharacterSaveStorage:
	var rows: Array = []
	func inspect_profile(_profile: String) -> Dictionary: return {"success":true,"generations":rows,"writer_locked":false,"pending_write":false}
var base: String
var stages := {}
var steps := 0
var maximum_step_us := 0
func row(label: String, data: Dictionary = {}) -> void:
	data["label"] = label
	data["static_bytes"] = int(Performance.get_monitor(Performance.MEMORY_STATIC))
	data["static_peak_bytes"] = int(Performance.get_monitor(Performance.MEMORY_STATIC_MAX))
	print("MEASURE ",JSON.stringify(data))
func begin(label: String) -> int:
	row("BEGIN_"+label)
	return Time.get_ticks_usec()
func finish(label: String, started: int, extra: Dictionary = {}) -> void:
	extra["ms"] = (Time.get_ticks_usec()-started)/1000.0
	row(label,extra)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	base = OS.get_cache_dir().path_join("itank-storage-tests/45e_performance")
	row("fixture_root",{"path":base})
	DirAccess.make_dir_recursive_absolute(base)
	PlayableCharacterPersistence.test_nonpersistent = true
	if args[0] == "setup": setup()
	elif args[0] == "retention": await retention()
	else: measure(args[0])
	quit(0)
func setup() -> void:
	var h := H.new()
	h.root = base.path_join("seed_storage")
	PlayableCharacterPersistence.test_nonpersistent = false
	var f := h.make_history("dev_normal",CharacterExpcCredit.BASELINE,2,"source")
	assert(f.get("success",false),str(h.failures))
	PlayableCharacterPersistence.test_storage = f.storage
	var scene := h.web.make_scene()
	var c: ArenaCombatController = scene.get_node("CombatController")
	assert(c._admit_existing_profile("dev_normal").success)
	c._resume_loaded_run()
	for _i in range(2):
		if c._session.get_actor_state(&"player").progression.level >= 9: break
		assert(c._session.request_next_wave().success)
		h.helper._defeat_wave(c._session)
	assert(h.failures.is_empty() and h.helper._failures.is_empty())
	var history := CharacterSaveStorage.history_records(f.storage.inspect_profile(f.profile))
	var head: Dictionary = CharacterSaveContract.decode(history.back().document).payload
	row("source_fixture",{"level":head.permanent.level,"xp":head.xp,"generations":history.size(),"head_bytes":history.back().document.to_utf8_buffer().size()})
	write_case(history,history.size(),0,0,"small")
	write_case(history,168,17000000,20000000,"168")
	write_case(history,221,31943753,41342410,"221")
	h.helper._free(scene)
	PlayableCharacterPersistence.test_storage = null
	PlayableCharacterPersistence.test_nonpersistent = true
	PlayableCharacterPersistence.test_run_id = ""
	h.helper._remove_fixture(h.root)
func write_case(seed: Array, count: int, target_body: int, target_file: int, label: String) -> void:
	var rows: Array = seed.duplicate(true)
	var payload: Dictionary = CharacterSaveContract.decode(seed.back().document).payload
	while rows.size() < count:
		payload.generation = rows.size()+1
		rows.append({"generation":payload.generation,"transaction_id":"perf_generation_%d" % payload.generation,"document":CharacterSaveContract.encode(payload).text})
	var body := {"profile_id":payload.character_id,"namespace":"dev_normal","definition_id":payload.definition_id,"rules_revision":payload.rules_revision,"created_utc":"2026-11-15T00:00:00Z","head_generation":rows.size(),"head_transaction_id":rows.back().transaction_id,"generations":rows}
	var encoded := JSON.stringify(body,"",true,true)
	var wire := JSON.stringify({"format":Backup.FORMAT,"backup_version":1,"body_json":encoded,"sha256":"0".repeat(64)},"",true,true)
	var tabs := 0
	var spaces := 0
	if target_body > 0:
		tabs = target_file-target_body-(wire.to_utf8_buffer().size()-encoded.to_utf8_buffer().size())
		spaces = target_body-encoded.to_utf8_buffer().size()-2*tabs
		assert(tabs >= 0 and spaces >= 0)
		for i in range(rows.size()):
			@warning_ignore("integer_division")
			var t := tabs/(rows.size()-i)
			@warning_ignore("integer_division")
			var s := spaces/(rows.size()-i)
			rows[i].document += "\t".repeat(t)+" ".repeat(s)
			tabs -= t; spaces -= s
	var file := FileAccess.open(base.path_join(label+".json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"success":true,"generations":rows},"",true,true)); file.close()
	var raw := 0
	for r: Dictionary in rows: raw += r.document.to_utf8_buffer().size()
	row("fixture_"+label,{"generations":rows.size(),"raw_bytes":raw,"target_body":target_body,"target_file":target_file})
func drain(task: RefCounted) -> Dictionary:
	for _i in range(100000):
		var phase: String = task.phase
		var started := Time.get_ticks_usec()
		var output: Dictionary = task.step()
		var elapsed := Time.get_ticks_usec()-started
		stages[phase] = int(stages.get(phase,0))+elapsed
		maximum_step_us = maxi(maximum_step_us,elapsed)
		steps += 1
		if output.get("state") != "pending": return output
	assert(false,"Benchmark step limit")
	return {}
func measure(label: String) -> void:
	var started := begin("fixture_read")
	var history: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(base.path_join(label+".json")))
	finish("fixture_read",started)
	var records: Array = history.generations
	var response := {"success":true,"state":"verified_committed","generations":records,"missing":false}
	started = begin("bridge_json")
	var wire := JSON.stringify(response,"",true,true)
	var parsed: Dictionary = JSON.parse_string(wire)
	finish("bridge_json",started,{"wire_bytes":wire.to_utf8_buffer().size()})
	wire = ""; response = {}
	started = begin("browser_contract_inspection")
	var inspected := CharacterBrowserStorage.inspection(parsed,"dev_vaelis_thorn")
	assert(inspected.success)
	finish("browser_contract_inspection",started)
	parsed = {}
	var service := PlayableCharacterPersistence.new()
	service.mode = "dev_normal"
	var storage := ReadStorage.new(base.path_join("read_only"))
	storage.rows = records
	service.storage = storage
	var starter := PlayableCharacterAdmission.prepare_starter(&"vaelis_thorn","dev_normal",CharacterExpcCredit.BASELINE)
	started = begin("authorized_hydration")
	assert(service.open_verified_history(starter,inspected,false,{}).success)
	finish("authorized_hydration",started,{"generation":service.generation,"level":service.candidate.permanent.level})
	inspected = {}
	var h := H.new()
	PlayableCharacterPersistence.test_nonpersistent = true
	var scene := h.helper._scene()
	var controller: ArenaCombatController = scene.get_node("CombatController")
	controller.set_physics_process(false)
	var sim := CombatSimulation.new(45)
	service.candidate.actor_definition.actor_id = &"player"
	sim.register_actor(service.candidate.actor_definition)
	var session := ArenaCombatSession.new(45,sim,Fixture.ENCOUNTER_WAVE_ONE_GOBLINS,Fixture.PLAYER_CHARACTER_VAELIS)
	session.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
	session._playable_persistence = service
	var applied := service.apply_player(session)
	assert(applied.success,str(applied))
	service.restore_ledger(session._reward_ledger)
	controller._session = session
	started = begin("sheet_open")
	controller.open_character_sheet()
	finish("sheet_open",started)
	controller._character_sheet.close_sheet()
	started = begin("sheet_with_long_transcript")
	for i in range(5000): sim.record_reward_event(&"reward_diagnostic_fixture",&"player",&"player",{"index":i})
	var sheet_started := Time.get_ticks_usec()
	controller.open_character_sheet()
	finish("sheet_with_long_transcript",sheet_started,{"events":sim.get_resolved_event_count()})
	controller._character_sheet.close_sheet()
	started = begin("export")
	var task := Task.new("export","dev_normal",history,"","2026-11-15T00:00:00Z")
	var exported := drain(task)
	assert(exported.success)
	finish("export",started,{"file_bytes":exported.text.to_utf8_buffer().size(),"phase_us":stages,"steps":steps,"max_step_ms":maximum_step_us/1000.0})
	task = null; stages = {}; steps = 0; maximum_step_us = 0
	var text: String = exported.text
	exported = {}
	started = begin("preview")
	task = Task.new("decode","dev_normal",{},text)
	var decoded := drain(task)
	assert(decoded.success)
	finish("preview",started,{"phase_us":stages,"steps":steps,"max_step_ms":maximum_step_us/1000.0})
	task = null; decoded = {}; stages = {}; steps = 0
	started = begin("restoration_begin")
	var restorer := CharacterBackupRestoration.new()
	var target := CharacterSaveStorage.new(base.path_join("restore_"+label+"_"+str(Time.get_ticks_usec())))
	assert(restorer.begin(text,"dev_normal",null,target).success)
	finish("restoration_begin",started)
	started = begin("restoration_confirm")
	assert(restorer.confirm().success)
	finish("restoration_confirm",started)
	restorer.dispose(); restorer = null
	started = begin("cancel_and_release")
	task = Task.new("decode","dev_normal",{},text)
	for i in range(4): task.step()
	task.cancel(); task = null
	text = ""; history = {}; records = []; service = null; storage.rows = []; storage = null
	h.helper._free(scene)
	controller = null; session = null; sim = null; starter = {}
	finish("cancel_and_release",started)
	row("complete")

# Separate settling probe: frame boundaries release deferred UI/temporary values.
# Run after setup with -- retention; no output is published to character storage.
func retention() -> void:
	var history: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(base.path_join("221.json")))
	row("retention_source_loaded")
	for i in range(4):
		var task := Task.new("export","dev_normal",history,"","2026-11-15T00:00:00Z")
		var result := drain(task)
		assert(result.get("success",false))
		var text: String = result.text
		task = Task.new("decode","dev_normal",{},text)
		result = drain(task)
		assert(result.get("success",false))
		task.cancel()
		result = {}; text = ""; task = null
		await process_frame
		await process_frame
		row("retention_released_cycle_%d" % i)
		var canceled := Task.new("decode","dev_normal",{},JSON.stringify({"foo":"bar"}))
		canceled.step(); canceled.cancel(); canceled = null
		await process_frame
		row("retention_canceled_cycle_%d" % i)
	history = {}
	await process_frame
	await process_frame
	row("retention_all_released")
