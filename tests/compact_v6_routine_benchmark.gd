extends "res://tests/compact_v6_windows_host.gd"
const Portable = preload("res://scripts/rewards/compact_v6_portable.gd")
var results: Array = []
var work_root := ""
func run_bench() -> Dictionary:
	PlayableCharacterPersistence.test_nonpersistent = false
	work_root = OS.get_cache_dir().path_join("itank-storage-tests/compact45s_45u_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()])
	var only := OS.get_environment("ARENA45U_ONLY")
	var f := native_start(work_root.path_join("small"),"normal",1) if only.is_empty() or only == "small" else {"success":false,"skipped":true}
	if f.success:
		Historical.new().helper._defeat_wave(f.session); f.session.collect_all_ground_loot(); exercise("small",f,3)
	elif not f.get("skipped",false): check(false,"Small actual admission")
	for spec: Array in [["233","compact45s_bench_19412_2096865/long"],["inventory","compact45s_bench_25204_2215533/inventory"],["credited","compact45s_bench_19316_960654/historical/v2"]]:
		if not only.is_empty() and only != spec[0]: continue
		var copied := clone_compact(spec[0],OS.get_cache_dir().path_join("itank-storage-tests/"+spec[1]))
		if copied.success:
			if copied.session.get_encounter_state() == ArenaCombatSession.ENCOUNTER_READY:
				Historical.new().helper._defeat_wave(copied.session); copied.session.collect_all_ground_loot()
			exercise(spec[0],copied,1)
	return {"success":failures.is_empty(),"failures":failures,"root":work_root,"results":results,"native_peak":OS.get_static_memory_peak_usage(),"native_static":OS.get_static_memory_usage(),"debug":OS.is_debug_build()}
func clone_compact(label: String, original: String) -> Dictionary:
	if not Windows.allowed(original): check(false,"Disposable source guard"); return {"success":false}
	var directory := original.path_join("dev_vaelis_thorn")
	var wrapper: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("compact/route.json")))
	if wrapper.is_empty(): check(false,"Frozen route missing: "+original); return {"success":false}
	var m: Dictionary = JSON.parse_string(wrapper.body)
	var text := FileAccess.get_file_as_string(directory.path_join("compact/record_"+m.digest+".v6"))
	var raw: Dictionary = JSON.parse_string(JSON.parse_string(text).payload_json)
	var source := PlayableCharacterAdmission.prepare_starter(&"vaelis_thorn","dev_normal",raw.current.lineage.baseline_digest)
	if not source.success: check(false,"Frozen source"); return source
	var checked := Windows.new(original,source.source,"dev_vaelis_thorn","dev_normal").load_current()
	if not checked.success: check(false,"Full frozen proof: "+str(checked)); return checked
	var destination := work_root.path_join(label)
	var target := destination.path_join("dev_vaelis_thorn")
	DirAccess.make_dir_recursive_absolute(target.path_join("compact"))
	for file: String in ["compact/route.json",m.fence_file,"compact/record_"+m.digest+".v6","compact/record_"+str(m.previous)+".v6","compact/capsule_"+m.capsule_digest+".v6backup"]:
		if FileAccess.file_exists(directory.path_join(file)): check(DirAccess.copy_absolute(directory.path_join(file),target.path_join(file)) == OK,"Exact disposable clone bytes")
	var f := native_start(destination,"dev_normal",null,checked.record)
	if not f.success: check(false,"Frozen admission: "+str(f)); return f
	check(f.service._prior == V6._projection(checked.record),"Frozen exact character equivalence")
	return f
func exercise(label: String, f: Dictionary, samples: int) -> void:
	var service: NativeService = f.service
	var initial: Dictionary = service.route.load_current()
	var input_sha: String = initial.text.sha256_text()
	var times: Array = []
	for i in range(samples):
		var t := Time.get_ticks_usec()
		var request: Dictionary = f.session.request_character_development("preferences",{"order":["nac","block","dodge","soak"]},"45u_"+label+"_%d" % i)
		var elapsed := float(Time.get_ticks_usec()-t)/1000.0
		check(request.get("persistence",{}).get("success",false) and service.errors.is_empty(),"Real authorized "+label+" checkpoint")
		if service.writes.is_empty() or service.measures.is_empty(): return
		times.append({"end_to_end_ms":elapsed,"write":service.writes.back(),"candidate":service.measures.back()})
	var t := Time.get_ticks_usec(); var cold: Dictionary = service.route.load_current(); var load_ms := float(Time.get_ticks_usec()-t)/1000.0
	check(cold.success and V6._projection(cold.record) == service._prior,"Cold full character equivalence")
	t = Time.get_ticks_usec(); var exported := Portable.export_record(cold.text,cold.history,service.source); var export_ms := float(Time.get_ticks_usec()-t)/1000.0
	t = Time.get_ticks_usec(); var preview := Portable.decode(exported.text,service.source); var preview_ms := float(Time.get_ticks_usec()-t)/1000.0
	check(exported.success and preview.success and preview.text == cold.text,"Independent complete portable proof")
	results.append({"fixture":label,"input_sha":input_sha,"output_sha":cold.text.sha256_text(),"capsule_sha":cold.capsule_text.sha256_text(),"samples":times,"cold_load_ms":load_ms,"export_ms":export_ms,"preview_ms":preview_ms,"items":cold.record.current.items.size(),"ids":cold.record.applied_ids.size(),"operations":cold.record.operations.size()})
