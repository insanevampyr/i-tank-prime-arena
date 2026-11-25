extends RefCounted
const Fixtures = preload("res://tests/compact_v6_storage_fixtures.gd")
const Disk = preload("res://tests/compact_v6_disposable_store.gd")
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
func run() -> Array[String]:
	var root := OS.get_cache_dir().path_join("itank-storage-tests/compact45m_native_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()])
	var fixture_root := OS.get_environment("ARENA45M_FIXTURES")
	var own_fixtures := fixture_root.is_empty()
	if own_fixtures: fixture_root = root.path_join("fixtures")
	if not Disk.allowed(fixture_root): check(false,"Invalid supplied disposable fixture root."); return failures
	if own_fixtures:
		var built := Fixtures.build(fixture_root)
		check(built.success,"Disposable V2/V4/V5-derived fixtures build: %s" % built)
		if not built.success: return failures
	var source: CombatCharacterDefinitionResource = PlayableCharacterAdmission.prepare_starter(&"vaelis_thorn","dev_normal",Fixtures.Credit.BASELINE).source
	for name: String in ["small","168","221","233","400"]:
		var text := FileAccess.get_file_as_string(fixture_root.path_join(name+".json"))
		var store := Disk.new(root.path_join(name),source,"dev_vaelis_thorn","dev_normal")
		var initial := store.publish(text,null)
		check(initial.success,"Initial %s compact write/readback." % name)
		if not initial.success: continue
		var previous: Dictionary = initial.record
		var candidate := Fixtures.next(previous,"native_next_"+name)
		var next_text: String = V6.encode(candidate,source).text
		var next := store.publish(next_text,token(initial.head))
		check(next.success and next.text == next_text,"Exact subsequent publication: "+name)
		check(store.previous_diagnostic().get("is_current") == false,"Previous recovery record remains diagnostic, never a rollback.")
		check(store.publish(text,token(initial.head)).get("reason") == "transaction_already_applied","Old save cannot replace newer progression.")
		check(store.publish(next_text,token(initial.head)).get("already_applied",false),"Lost acknowledgement retry is exactly once.")
		var loaded := Disk.new(store.root,source,"dev_vaelis_thorn","dev_normal").load_current()
		check(loaded.success and loaded.record == candidate,"New adapter reload preserves entire state.")
		print("45M_NATIVE "+JSON.stringify({"fixture":name,"bytes":text.to_utf8_buffer().size(),"initial_save_ms":initial.get("save_ms"),"subsequent_save_ms":next.get("save_ms"),"readback_ms":next.get("readback_ms"),"load_ms":loaded.get("load_ms"),"native_peak":OS.get_static_memory_peak_usage()}))
		if name == "small": matrix(store,initial,next,source)
		if name == "small":
			for fault: String in ["partial_stage","after_stage","after_publish"]:
				var fresh := Disk.new(root.path_join("initial_"+fault),source,"dev_vaelis_thorn","dev_normal")
				check(not fresh.publish(text,null,fault).success and fresh.publish(text,null).success,"Initial interrupted request retries exactly: "+fault)
		if name == "400":
			var large_text := FileAccess.get_file_as_string(fixture_root.path_join("1000.json"))
			var large_store := Disk.new(root.path_join("lifetime"),source,"dev_vaelis_thorn","dev_normal")
			var a := large_store.publish(large_text,null)
			var following := Fixtures.next(a.record,"thousand_next")
			var b := large_store.publish(V6.encode(following,source).text,token(a.head))
			check(b.success and b.record.operations.size() >= 1000 and b.record.applied_ids.size() >= 1000,"1000+ actual lifetime transaction IDs persist beyond journal20.")
			var replay: Dictionary = b.record.duplicate(true)
			replay = Fixtures.next(replay,replay.operations[0].id)
			check(not V6.validate(replay,source).success,"Operation older than journal cannot be replayed.")
			var reward_replay := Fixtures.next(b.record,"new_wrapper_same_award")
			reward_replay.evidence.awards.append(reward_replay.evidence.awards[0])
			check(not large_store.publish(JSON.stringify({"format":"itank_arena_character","version":6,"payload_json":JSON.stringify(reward_replay,"",true,true),"sha256":V6.digest(reward_replay)}),token(b.head)).success,"New operation ID does not permit replaying an old award.")
			var big_loaded := large_store.load_current()
			check(big_loaded.success and big_loaded.text == b.text,"Rejected old rewards and IDs leave all acknowledged progression unchanged.")
			print("45M_NATIVE_LIFETIME "+JSON.stringify({"bytes":large_text.to_utf8_buffer().size(),"operations":b.record.operations.size(),"lifetime_ids":b.record.applied_ids.size(),"save_ms":b.get("save_ms"),"readback_ms":b.get("readback_ms"),"load_ms":big_loaded.get("load_ms")}))
	check(not Disk.new("user://character_documents",source,"dev_vaelis_thorn","dev_normal").load_current().success,"Production-root fallback is impossible.")
	preload("res://tests/test_playable_vaelis_persistence.gd").new()._remove_fixture(root)
	print("45M disposable native storage: %d assertions." % assertions)
	return failures

func matrix(store: RefCounted, initial: Dictionary, current: Dictionary, source: CombatCharacterDefinitionResource) -> void:
	var candidate := Fixtures.next(current.record,"matrix_next")
	var text: String = V6.encode(candidate,source).text
	var recoveries: Array = []
	for fault: String in ["before_stage","partial_stage","after_stage","partial_head","head_staged"]:
		check(not store.publish(text,token(current.head),fault).success,"Injected pre-publication failure: "+fault)
		var recovered: Dictionary = store.recover()
		check(recovered.success and recovered.text == current.text,"Recover acknowledged current after "+fault)
		recoveries.append({"fault":fault,"ms":recovered.get("recovery_ms")})
	var other := Fixtures.next(current.record,"conflicting_next")
	check(store.publish(text,token(current.head),"lost_ack").get("reason") == "acknowledgement_lost","Commit can precede acknowledgement.")
	check(store.publish(text,token(current.head)).get("already_applied",false),"Exact retry reconciles lost acknowledgement.")
	check(not store.publish(V6.encode(other,source).text,token(current.head)).success,"Competing same-parent update rejects.")
	var newest: Dictionary = store.load_current()
	var previous_path: String = store._file(newest.head.previous)
	var previous_text := FileAccess.get_file_as_string(previous_path)
	raw(previous_path,"damaged")
	check(store.load_current().success and not store.previous_diagnostic().success,"Damaged previous never invalidates the sound latest record.")
	raw(previous_path,previous_text)
	var latest_path: String = store._file(newest.head.digest)
	raw(latest_path,"damaged")
	check(not store.load_current().success and not store.recover().success and store.previous_diagnostic().success,"Damaged acknowledged latest fails closed even with a sound previous record.")
	check(not store.repair_exact(initial.text).success,"Older backup is not a repair for acknowledged newer progress.")
	check(store.repair_exact(newest.text).success,"Exact acknowledged artifact repairs without reapplying transactions.")
	DirAccess.remove_absolute(latest_path)
	check(not store.load_current().success and store.repair_exact(newest.text).success,"Missing latest requires exact repair, never fallback.")
	var head_text := FileAccess.get_file_as_string(store.root.path_join("head.json"))
	raw(store.root.path_join("head.json"),"truncated")
	check(not store.load_current().success,"Damaged head fails closed without choosing an older record.")
	raw(store.root.path_join("head.json"),head_text)
	DirAccess.remove_absolute(store.root.path_join("head.json"))
	check(not store.load_current().success and not store.publish(initial.text,null).success,"Missing head cannot be mistaken for a new empty character.")
	raw(store.root.path_join("head.json"),head_text)
	var lease: Dictionary = store.guard.acquire_writer("dev_vaelis_thorn")
	check(lease.success and not store.publish(text,token(newest.head)).success,"Active competing writer cannot publish.")
	store.guard.release_writer("dev_vaelis_thorn",lease.owner)
	var output: Array = []
	var code := OS.execute(OS.get_executable_path(),["--headless","--path",ProjectSettings.globalize_path("res://"),"--script","tests/compact_v6_storage_process.gd","--","load",store.root],output,true)
	check(code == 0 and " ".join(output).contains('"success":true'),"A separate process loads acknowledged compact state.")
	var orphan := Fixtures.next(newest.record,"process_orphan")
	var orphan_path: String = store.root.path_join("orphan_fixture.json")
	raw(orphan_path,V6.encode(orphan,source).text)
	output = []
	code = OS.execute(OS.get_executable_path(),["--headless","--path",ProjectSettings.globalize_path("res://"),"--script","tests/compact_v6_storage_process.gd","--","orphan",store.root,orphan_path],output,true)
	var recovered: Dictionary = store.recover()
	check(code == 0 and recovered.success and recovered.record == orphan,"Dead-process writer lock and lost publication acknowledgement recover at exact latest state.")
	recoveries.append({"fault":"process_orphan","ms":recovered.get("recovery_ms")})
	print("45M_NATIVE_RECOVERY "+JSON.stringify(recoveries))
	check(Array(DirAccess.get_files_at(store.root)).filter(func(p): return p.begins_with("record_") and p.ends_with(".v6")).size() == 2,"Only current/previous records remain after recovery.")
