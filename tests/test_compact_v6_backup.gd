extends RefCounted
const Portable = preload("res://tests/compact_v6_portable_backup.gd")
const Store = preload("res://tests/compact_v6_backup_store.gd")
const Fixtures = preload("res://tests/compact_v6_storage_fixtures.gd")
const V6 = preload("res://scripts/rewards/compact_character_v6_prototype.gd")
var failures: Array[String] = []
var assertions := 0
func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok: failures.append(message)
func token(head: Dictionary) -> Dictionary:
	return {"sequence":head.sequence,"digest":head.digest}
func raw(path: String, text: String) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE); file.store_string(text); file.close()
func reframed(lines: PackedStringArray) -> String:
	var body := "\n".join(lines.slice(0,lines.size()-1))+"\n"
	return body+Portable.canonical({"kind":"integrity","sha256":body.sha256_text()})+"\n"
func run() -> Array[String]:
	var root := OS.get_environment("ARENA45N_OUTPUT")
	if root.is_empty(): root = OS.get_cache_dir().path_join("itank-storage-tests/compact45m_45n_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()])
	var fixture_root := OS.get_environment("ARENA45M_FIXTURES")
	if not Store.allowed(root) or not Store.allowed(fixture_root): check(false,"Disposable fixture paths required."); return failures
	DirAccess.make_dir_recursive_absolute(root)
	var source: CombatCharacterDefinitionResource = PlayableCharacterAdmission.prepare_starter(&"vaelis_thorn","dev_normal",Fixtures.Credit.BASELINE).source
	var timings: Array = []
	for name: String in ["small","168","221","233","400","1000"]:
		var text := FileAccess.get_file_as_string(fixture_root.path_join(name+".json"))
		var store := Store.new(root.path_join("source_"+name),source,"dev_vaelis_thorn","dev_normal")
		var initial := store.publish(text,null)
		check(initial.success,"Initial compact record "+name+": "+str(initial.get("reason")))
		if not initial.success: continue
		var baseline := store.export_file(store.root.path_join("baseline.v6backup"))
		check(baseline.success,"Standalone baseline export "+name+": "+str(baseline.get("reason")))
		var current := initial
		for i in range(2):
			var candidate := Fixtures.next(current.record,"portable_"+name+"_"+str(i))
			current = store.publish(V6.encode(candidate,source).text,token(current.head))
			check(current.success,"Native transition publication "+name+"/"+str(i)+": "+str(current.get("reason")))
			if not current.success: break
		if not current.success: continue
		raw(root.path_join("baseline_"+name+".v6backup"),FileAccess.get_file_as_string(store.root.path_join("baseline.v6backup")))
		var path := store.root.path_join("export.v6backup")
		var exported := store.export_file(path)
		check(exported.success,"Portable export "+name+": "+str(exported.get("reason")))
		if not exported.success: continue
		var file := FileAccess.get_file_as_string(path)
		raw(root.path_join(name+".v6backup"),file)
		var started := Time.get_ticks_usec()
		var pack := Portable.decode(file,source)
		var preview_ms := float(Time.get_ticks_usec()-started)/1000.0
		check(pack.success and pack.text == current.text and pack.record == current.record,"Self-contained preview matches complete state/equipment/growth/IDs "+name)
		check(Portable.export_record(pack.text,pack.history,source).text == file,"Deterministic bytes "+name)
		var destination := Store.new(root.path_join("destination_"+name),source,"dev_vaelis_thorn","dev_normal")
		check(not destination.restore(file,null,"").success and not FileAccess.file_exists(destination.root.path_join("head.json")),"No restore without explicit confirmation "+name)
		started = Time.get_ticks_usec()
		var confirmed := Portable.confirmation(file.sha256_text(),null,destination.profile,destination.save_namespace)
		var installed := destination.restore(file,null,confirmed,"lost_ack")
		var publication_ms := float(Time.get_ticks_usec()-started)/1000.0
		var restored := destination.restore(file,null,confirmed)
		var restore_ms := float(Time.get_ticks_usec()-started)/1000.0
		check(not installed.success and restored.success and restored.get("already_applied",false) and restored.text == current.text,"Lost acknowledgement retry installs exact latest once "+name)
		var old := FileAccess.get_file_as_string(root.path_join("baseline_"+name+".v6backup"))
		check(destination.restore(old,token(restored.head),Portable.confirmation(old.sha256_text(),token(restored.head),destination.profile,destination.save_namespace)).get("reason") == "older_backup_rejected","Older standalone backup cannot overwrite newer "+name)
		raw(destination._file(restored.head.digest),"truncated")
		var recovered := destination.recover()
		check(recovered.success and recovered.get("recovered_exact_head",false) and recovered.text == current.text,"Recover exact acknowledged head, never previous "+name)
		check(destination.recover().success,"Repeated exact recovery "+name)
		var repeated := Fixtures.next(restored.record,restored.record.operations[0].id)
		check(not V6.validate(repeated,source).success and destination.load_current().text == current.text,"Lifetime IDs remain non-replayable after restore "+name)
		var files := DirAccess.get_files_at(destination.root)
		var disk_bytes := 0
		for entry: String in files:
			var f := FileAccess.open(destination.root.path_join(entry),FileAccess.READ)
			if f != null: disk_bytes += f.get_length(); f.close()
		timings.append({"fixture":name,"record_bytes":text.to_utf8_buffer().size(),"portable_bytes":file.to_utf8_buffer().size(),"transition_bytes":Portable.history_text(pack.history).to_utf8_buffer().size(),"export_ms":exported.export_ms,"preview_ms":preview_ms,"restore_lost_ack_plus_retry_ms":restore_ms,"restore_publish_ms":publication_ms,"routine_save_ms":current.save_ms,"routine_load_ms":recovered.get("load_ms"),"recovery_ms":recovered.recovery_ms,"storage_bytes":disk_bytes,"native_peak":OS.get_static_memory_peak_usage(),"operations":current.record.operations.size(),"lifetime_ids":current.record.applied_ids.size()})
		if name == "small": matrix(root,store,source,file,old)
	compatibility_cases(root)
	print("45N_NATIVE "+JSON.stringify({"metrics":timings,"assertions":assertions,"failures":failures,"native_current":OS.get_static_memory_usage(),"native_peak":OS.get_static_memory_peak_usage()}))
	raw(root.path_join("native-results.json"),JSON.stringify({"metrics":timings,"assertions":assertions,"failures":failures},"\t"))
	print("45N portable backup: %d assertions." % assertions)
	return failures

func matrix(root: String, store: RefCounted, source: CombatCharacterDefinitionResource, file: String, old: String) -> void:
	var pack := Portable.decode(file,source)
	for damaged: String in [file.left(file.length()/2),file.trim_suffix("\n"),file.replace("\"version\":1","\"version\":99"),file.replace("integrity","tampered")]:
		check(not Portable.decode(damaged,source).success,"Truncated/corrupt/unsupported file rejected")
	var frames := file.trim_suffix("\n").split("\n")
	var header: Dictionary = JSON.parse_string(frames[0]); header.profile = "prod_vaelis_thorn"; frames[0] = Portable.canonical(header)
	check(not Portable.decode(reframed(frames),source).success,"Recomputed checksum cannot authorize mismatched identity")
	frames = file.trim_suffix("\n").split("\n")
	var envelope: Dictionary = JSON.parse_string(frames[1]); var record: Dictionary = JSON.parse_string(envelope.payload_json)
	record.accounting.expc_available += 10000; envelope.payload_json = Portable.canonical(record); envelope.sha256 = envelope.payload_json.sha256_text(); frames[1] = Portable.canonical(envelope)
	header = JSON.parse_string(frames[0]); header.document_digest = frames[1].sha256_text(); frames[0] = Portable.canonical(header)
	check(not Portable.decode(reframed(frames),source).success,"Forged totals rejected despite all valid checksums")
	frames = file.trim_suffix("\n").split("\n"); frames.remove_at(2); header = JSON.parse_string(frames[0]); header.transition_count -= 1; frames[0] = Portable.canonical(header)
	check(not Portable.decode(reframed(frames),source).success,"Missing ancestry evidence rejected")
	var wrong := Store.new(root.path_join("wrong"),source,"prod_vaelis_thorn","normal")
	check(not wrong.restore(file,null,Portable.confirmation(file.sha256_text(),null,wrong.profile,wrong.save_namespace)).success,"Exact namespace/profile required")
	var baseline := Portable.decode(old,source)
	var branch := Fixtures.next(baseline.record,"different_branch")
	branch = Fixtures.next(branch,"different_branch_2")
	check(not Portable.relationship(pack,branch,V6.encode(branch,source).text.sha256_text(),source).success,"Same sequence conflicting content rejected")
	var branch_one := Fixtures.next(baseline.record,"different_parent")
	check(Portable.relationship(pack,branch_one,V6.encode(branch_one,source).text.sha256_text(),source).get("reason") == "unrelated_or_conflicting_branch","Unrelated branch ancestry rejected")
	check(Portable.relationship(pack,baseline.record,baseline.text.sha256_text(),source).success,"Multi-step exact descendant proved from all transitions")
	for fault: String in ["before_stage","partial_stage","after_stage","partial_head","head_staged","after_publish"]:
		var target := Store.new(root.path_join("fault_"+fault),source,"dev_vaelis_thorn","dev_normal")
		var initial := target.restore(old,null,Portable.confirmation(old.sha256_text(),null,target.profile,target.save_namespace))
		var expected := token(initial.head)
		var confirm := Portable.confirmation(file.sha256_text(),expected,target.profile,target.save_namespace)
		var interrupted := target.restore(file,expected,confirm,fault)
		var loaded := target.load_current()
		check(not interrupted.success and loaded.success and loaded.text == (pack.text if fault == "after_publish" else baseline.text),"Publication boundary holds after restore interruption: "+fault)
		check(target.restore(file,expected,confirm).success,"Exact restore retry after "+fault)
	for fault: String in ["before_stage","partial_stage","after_stage","partial_head","head_staged","after_publish"]:
		var empty := Store.new(root.path_join("empty_"+fault),source,"dev_vaelis_thorn","dev_normal")
		var confirmed := Portable.confirmation(file.sha256_text(),null,empty.profile,empty.save_namespace)
		check(not empty.restore(file,null,confirmed,fault).success and empty.restore(file,null,confirmed).success,"Initial empty restore interruption reconciles exact staged input: "+fault)
	var repair := Store.new(root.path_join("external_repair"),source,"dev_vaelis_thorn","dev_normal")
	var installed := repair.restore(file,null,Portable.confirmation(file.sha256_text(),null,repair.profile,repair.save_namespace))
	DirAccess.remove_absolute(repair._file(installed.head.digest)); DirAccess.remove_absolute(repair._capsule(installed.head.digest))
	check(not repair.recover().success,"No automatic recovery without exact durable evidence")
	check(repair.restore(file,token(installed.head),Portable.confirmation(file.sha256_text(),token(installed.head),repair.profile,repair.save_namespace)).success,"Explicit external exact-head backup repairs missing current and capsule")
	var stale := Store.new(root.path_join("stale"),source,"dev_vaelis_thorn","dev_normal")
	check(stale.restore(old,null,Portable.confirmation(old.sha256_text(),null,stale.profile,stale.save_namespace)).success,"Prepare stale destination")
	var wrong_head := {"sequence":999,"digest":"0".repeat(64)}
	check(stale.restore(file,wrong_head,Portable.confirmation(file.sha256_text(),wrong_head,stale.profile,stale.save_namespace)).get("reason") == "stale_expected_head","Valid confirmation cannot bypass fresh destination head")
	check(not stale.restore(old,null,Portable.confirmation(file.sha256_text(),null,stale.profile,stale.save_namespace)).success,"Changed file cannot reuse another preview confirmation")
	var process_store := Store.new(root.path_join("process"),source,"dev_vaelis_thorn","dev_normal")
	var process_initial := process_store.restore(file,null,Portable.confirmation(file.sha256_text(),null,process_store.profile,process_store.save_namespace))
	var next := Fixtures.next(process_initial.record,"portable_process_orphan")
	var input := process_store.root.path_join("candidate.json")
	raw(input,V6.encode(next,source).text)
	var output: Array = []
	var code := OS.execute(OS.get_executable_path(),["--headless","--path",ProjectSettings.globalize_path("res://"),"--script","tests/compact_v6_storage_process.gd","--","orphan_portable",process_store.root,input],output,true)
	var recovered := process_store.recover()
	check(code == 0 and recovered.success and recovered.record == next,"Separate-process lost acknowledgement and abandoned writer recover exact portable head")
	var cancel := Store.new(root.path_join("canceled"),source,"dev_vaelis_thorn","dev_normal")
	check(Portable.decode(file,source).success and not DirAccess.dir_exists_absolute(cancel.root),"Preview/cancel has no destination writes, including directory creation")
	var current: Dictionary = store.load_current()
	check(not store.restore(file,{"sequence":999,"digest":"0".repeat(64)},"unconfirmed").success,"Forged/stale confirmation rejected")
	var candidate := Fixtures.next(current.record,"head_changed_during_export")
	var change := func(): store.publish(V6.encode(candidate,source).text,token(current.head))
	check(store.export_file(root.path_join("stale_export.v6backup"),change).get("reason") == "export_head_changed" and not FileAccess.file_exists(root.path_join("stale_export.v6backup")),"Source head change during export produces no file")
	current = store.load_current()
	var lock: Dictionary = store.guard.acquire_writer(store.profile)
	check(not store.restore(file,token(current.head),Portable.confirmation(file.sha256_text(),token(current.head),store.profile,store.save_namespace)).success,"Exclusive writer blocks restore")
	store.guard.release_writer(store.profile,lock.owner)
	DirAccess.remove_absolute(store._file(current.head.digest)); raw(store._capsule(current.head.digest),"broken")
	check(not store.recover().success and store.previous_diagnostic().success,"Previous alone never repairs acknowledged latest without exact evidence")
	check(not Store.new("user://profiles",source,"dev_vaelis_thorn","dev_normal").recover().success,"No production path fallback")

func compatibility_cases(root: String) -> void:
	var h := preload("res://tests/test_historical_vaelis_admission.gd").new()
	h.root = root.path_join("legacy_fixtures")
	var old_storage := PlayableCharacterPersistence.test_storage
	var old_run := PlayableCharacterPersistence.test_run_id
	var old_nonpersistent := PlayableCharacterPersistence.test_nonpersistent
	PlayableCharacterPersistence.test_nonpersistent = false
	for scope: String in ["normal","dev_normal"]:
		for version: int in [2,4]:
			var name := scope+"_v"+str(version)
			var original := h.make_history(scope,Fixtures.Credit.BASELINE,version,name)
			check(original.get("success",false),"Disposable namespace/version fixture "+name)
			if not original.get("success",false): continue
			var converted := preload("res://scripts/rewards/legacy_to_compact_v6_prototype.gd").convert(original.records,scope)
			check(converted.success,"Convert independently verified "+name)
			if not converted.success: continue
			var definition: CombatCharacterDefinitionResource = PlayableCharacterAdmission.prepare_starter(&"vaelis_thorn",scope,Fixtures.Credit.BASELINE).source
			var portable := Portable.export_record(converted.text,[],definition)
			check(portable.success,"Portable legacy version "+name)
			if not portable.success: continue
			raw(root.path_join(name+".json"),converted.text)
			raw(root.path_join(name+".v6backup"),portable.text)
			var destination := Store.new(root.path_join("compat_"+name),definition,original.profile,scope)
			var restored := destination.restore(portable.text,null,Portable.confirmation(portable.text.sha256_text(),null,original.profile,scope))
			check(restored.success and V6._projection(restored.record) == original.payload,"Complete namespace/policy/progression projection preserved "+name)
	check(h.failures.is_empty() and h.helper._failures.is_empty(),"Legacy fixture builders have no hidden failures")
	PlayableCharacterPersistence.test_storage = old_storage
	PlayableCharacterPersistence.test_run_id = old_run
	PlayableCharacterPersistence.test_nonpersistent = old_nonpersistent
