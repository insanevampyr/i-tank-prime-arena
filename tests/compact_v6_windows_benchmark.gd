extends RefCounted
const Core = preload("res://tests/test_compact_v6_windows_storage.gd")
const Host = preload("res://tests/compact_v6_windows_host.gd")
const L = preload("res://tests/test_legacy_to_compact_v6.gd")
const Historical = preload("res://tests/test_historical_vaelis_admission.gd")
const V6 = preload("res://scripts/rewards/compact_character_v6_prototype.gd")
const Credit = preload("res://scripts/rewards/character_expc_credit.gd")
var results: Array = []
var failures: Array[String] = []
var bench_root := ""
class MeteredRoute extends Host.Windows:
	var measured := {"read_io_ms":0.0,"write_flush_byte_readback_ms":0.0,"rename_ms":0.0,"stage_publish_inclusive_ms":0.0,"full_load_inclusive_ms":0.0,"read_calls":0,"write_calls":0,"rename_calls":0,"load_calls":0}
	func _read(path: String, limit: int = 34*1024*1024) -> Dictionary:
		var t := Time.get_ticks_usec(); var result := super._read(path,limit)
		measured.read_calls += 1; measured.read_io_ms += float(Time.get_ticks_usec()-t)/1000.0; return result
	func _write(path: String, text: String) -> bool:
		var t := Time.get_ticks_usec(); var result := super._write(path,text)
		measured.write_calls += 1; measured.write_flush_byte_readback_ms += float(Time.get_ticks_usec()-t)/1000.0; return result
	func _rename(a: String, b: String) -> bool:
		var t := Time.get_ticks_usec(); var result := super._rename(a,b)
		measured.rename_calls += 1; measured.rename_ms += float(Time.get_ticks_usec()-t)/1000.0; return result
	func install(text: String, capsule: String, expected: Variant, legacy: Dictionary, owner: String) -> Dictionary:
		var t := Time.get_ticks_usec(); var result := super.install(text,capsule,expected,legacy,owner)
		measured.stage_publish_inclusive_ms += float(Time.get_ticks_usec()-t)/1000.0; return result
	func load_current() -> Dictionary:
		var t := Time.get_ticks_usec(); var result := super.load_current()
		measured.load_calls += 1; measured.full_load_inclusive_ms += float(Time.get_ticks_usec()-t)/1000.0; return result
func run() -> Dictionary:
	PlayableCharacterPersistence.test_nonpersistent = false
	bench_root = OS.get_cache_dir().path_join("itank-storage-tests/compact45s_bench_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()])
	var core := Core.new(); core.root = bench_root
	var kind := OS.get_environment("ARENA45S_BENCH_KIND")
	if kind == "io":
		io_probe()
		return {"success":failures.is_empty(),"failures":failures,"results":results,"root":bench_root,"debug":OS.is_debug_build()}
	if kind != "long": core.fresh("normal",1); core.converted_credit()
	failures.append_array(core.failures); results.append_array(core.metrics)
	if kind != "core": long_history()
	if kind.is_empty(): high_inventory()
	return {"success":failures.is_empty(),"failures":failures,"results":results,"root":bench_root,"debug":OS.is_debug_build(),"native_static":OS.get_static_memory_usage(),"native_peak":OS.get_static_memory_peak_usage(),"pid":OS.get_process_id()}
func io_probe() -> void:
	var host := Host.new(); var f: Dictionary = host.native_start(bench_root.path_join("io"),"normal",1)
	if not f.success: require(false,"I/O source"); return
	var p: Host.NativeService = f.service
	var meter := MeteredRoute.new(p.route.root,p.source,p.profile_id,p.mode); meter.guard = p.storage; p.route = meter
	Historical.new().helper._defeat_wave(f.session)
	require(p.errors.is_empty(),"Metered source-valid publication")
	results.append({"fixture":"one_source_wave_completion","measurements":meter.measured,"writes":p.writes.back(),"scope":"Inclusive semantic load/staging timers overlap I/O timers; not additive, no gameplay hooks"})
func require(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func long_history() -> void:
	var archive := OS.get_environment("ARENA45S_LEGACY_BUNDLE")
	if not archive.is_empty():
		if not Host.Windows.allowed(archive.get_base_dir().get_base_dir()) or not archive.get_file().begins_with("restoration_") or not archive.ends_with(".bundle"): require(false,"Invalid frozen disposable source path"); return
		var copied := bench_root.path_join("long/dev_vaelis_thorn").path_join(archive.get_file())
		DirAccess.make_dir_recursive_absolute(copied.get_base_dir())
		if DirAccess.copy_absolute(archive,copied) != OK: require(false,"Frozen archive copy"); return
		var guard := CharacterSaveStorage.new(bench_root.path_join("long"))
		var inspection := guard.inspect_profile(Credit.PROFILE)
		if not inspection.success: require(false,"Frozen source storage validation"); return
		measure_legacy_rows(CharacterSaveStorage.history_records(inspection),guard)
		return
	var h := Historical.new(); h.root = bench_root.path_join("long_source")
	var f := h.make_history("dev_normal",Credit.BASELINE,2,"seed")
	if not f.get("success",false): require(false,"Long source fixture"); return
	var generator := L.new(); var complex := generator.complex_history(h,f)
	if not complex.get("success",false): require(false,"Long source complexity"); return
	var rows := generator.extend_preferences(complex.rows,233)
	var guard := CharacterSaveStorage.new(bench_root.path_join("long"))
	var lease := guard.acquire_writer(Credit.PROFILE)
	var restored := guard.restore_history(Credit.PROFILE,rows,[],lease.owner)
	guard.release_writer(Credit.PROFILE,lease.owner)
	if not restored.success: require(false,"Long restored source: "+str(restored)); return
	measure_legacy_rows(rows,guard)

func measure_legacy_rows(rows: Array, guard: CharacterSaveStorage) -> void:
	var started := Time.get_ticks_usec()
	var converted: Dictionary = preload("res://scripts/rewards/legacy_to_compact_v6_prototype.gd").convert(rows,"dev_normal")
	var conversion_ms := float(Time.get_ticks_usec()-started)/1000.0
	if not converted.success: require(false,"Long conversion"); return
	var helper := Host.new()
	var current: Dictionary = helper.native_start(guard._root,"dev_normal",null,converted.record)
	if not current.success: require(false,"Long compact admission: "+str(current)); return
	for i in range(3): require(current.session.request_character_development("preferences",{"order":["nac","block","dodge","soak"]},"45s_long_%d" % i).get("persistence",{}).get("success",false),"Actual long-history native checkpoint")
	require(current.service.errors.is_empty(),"Long source authority: "+str(current.service.errors))
	measure("233_generations",current,conversion_ms)
func high_inventory() -> void:
	var helper := Host.new()
	var f: Dictionary = helper.native_start(bench_root.path_join("inventory"),"dev_normal",10)
	if not f.success: require(false,"Inventory source"); return
	Historical.new().helper._defeat_wave(f.session)
	f.session.collect_all_ground_loot()
	var s: ArenaCombatSession = f.session
	var state := s.get_actor_state(&"player")
	var origin := s.simulation.record_reward_event(&"reward_source_item_fixture",&"player",&"player",{})
	for i in range(1000): s.simulation.create_ground_loot_item("45s_currency_%d" % i,{"definition_id":"prime_v3_gold","quantity":1,"display_name":"Gold","item_kind":"currency","source_ref":"PRIME-V3 currency; disposable source-origin fixture"},state.position_microfeet,&"player",origin.event_id)
	require(s.collect_all_ground_loot().get("persistence",{}).get("success",false),"1000 distinct source-backed item origins publish once")
	for i in range(3): require(s.request_character_development("preferences",{"order":["nac","dodge","block","soak"]},"45s_inventory_%d" % i).get("persistence",{}).get("success",false),"Actual inventory native checkpoint")
	require(f.service.errors.is_empty(),"Inventory source authority: "+str(f.service.errors))
	measure("1000_item_origins",f)
func measure(label: String, f: Dictionary, conversion_ms: float = 0.0) -> void:
	var p: Host.NativeService = f.service
	var t := Time.get_ticks_usec(); var cold: Dictionary = p.route.load_current()
	var load_ms := float(Time.get_ticks_usec()-t)/1000.0
	require(cold.success and V6._projection(cold.record) == p._prior,"Cold entire-character equivalence: "+label)
	if not cold.success: return
	p.route._write(p.route.objects.path_join("record_"+cold.head.digest+".v6"),"damaged")
	t = Time.get_ticks_usec(); var recovery: Dictionary = p.route.recover()
	var recovery_ms := float(Time.get_ticks_usec()-t)/1000.0
	require(recovery.success and recovery.text == cold.text,"Exact acknowledged recovery: "+label)
	var footprint := 0
	for name: String in DirAccess.get_files_at(p.route.objects):
		var file := FileAccess.open(p.route.objects.path_join(name),FileAccess.READ)
		footprint += file.get_length(); file.close()
	results.append({"fixture":label,"conversion_ms_excluded":conversion_ms,"operations":cold.record.operations.size(),"awards":cold.record.evidence.awards.size(),"items":cold.record.current.items.size(),"lifetime_ids":cold.record.applied_ids.size(),"record_bytes":cold.text.to_utf8_buffer().size(),"retained_compact_bytes":footprint,"cold_load_ms":load_ms,"exact_recovery_ms":recovery_ms,"writes":p.writes,"preparation":p.measures,"native_peak":OS.get_static_memory_peak_usage()})
