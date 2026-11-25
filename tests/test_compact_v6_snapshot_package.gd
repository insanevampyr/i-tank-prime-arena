extends RefCounted
const Package = preload("res://scripts/rewards/compact_v6_snapshot_package.gd")
const V6 = preload("res://scripts/rewards/compact_character_v6_prototype.gd")
const Historical = preload("res://tests/test_historical_vaelis_admission.gd")
const Convert = preload("res://scripts/rewards/legacy_to_compact_v6_prototype.gd")
const Credit = preload("res://scripts/rewards/character_expc_credit.gd")
var failures: Array[String] = []
var assertions := 0
var metrics: Array = []
var examples := {}
func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok: failures.append(label)
func trusted(text: String) -> Dictionary:
	var r: Dictionary = JSON.parse_string(JSON.parse_string(text).payload_json)
	return PlayableCharacterAdmission.prepare_starter(&"vaelis_thorn",r.current.profile_namespace,r.current.lineage.baseline_digest)
func read_fixture(path: String) -> String:
	var base := OS.get_cache_dir().replace("\\","/").path_join("itank-storage-tests/")
	if not path.replace("\\","/").simplify_path().begins_with(base) or path.get_extension() not in ["json","v6"]: check(false,"Own disposable fixture path only"); return ""
	return FileAccess.get_file_as_string(path)
func current_from_cache(root: String) -> String:
	var directory := OS.get_cache_dir().path_join("itank-storage-tests/"+root+"/dev_vaelis_thorn/compact")
	var route: Dictionary = JSON.parse_string(JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("route.json"))).body)
	return read_fixture(directory.path_join("record_"+route.digest+".v6"))
func run() -> Array[String]:
	if OS.get_environment("ARENA45W_FROZEN_MATRIX") == "1": frozen_matrix()
	else: fresh_fixtures()
	if examples.has("normal_v4"):
		recovery_matrix(examples.normal_v4)
		lineage_matrix(examples.normal_v4)
		restart(examples.normal_v4)
		negative_matrix(examples.normal_v4)
	if examples.has("233"): negative_matrix(examples["233"])
	if examples.has("native_credit_all_five"): negative_matrix(examples.native_credit_all_five)
	if OS.get_environment("ARENA45W_FROZEN_MATRIX") == "1": legacy_reference()
	print("45W_METRICS "+JSON.stringify({"samples":metrics,"allocator_live":OS.get_static_memory_usage(),"allocator_peak":OS.get_static_memory_peak_usage(),"scope":"Windows native Godot debug, package/recovery logic only; no routine-save integration, Windows release or Edge claims"}))
	print("45W snapshot package: %d assertions." % assertions)
	return failures

# The registered suite has no dependency on a surviving external benchmark
# cache. The larger, already frozen audit matrix is explicitly opt-in.
func fresh_fixtures() -> void:
	var old_storage := PlayableCharacterPersistence.test_storage
	var old_run := PlayableCharacterPersistence.test_run_id
	var old_nonpersistent := PlayableCharacterPersistence.test_nonpersistent
	PlayableCharacterPersistence.test_nonpersistent = false
	var helper := Historical.new()
	helper.root = OS.get_cache_dir().path_join("itank-storage-tests/compact45w_fixture_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()])
	for version: int in [2,4]:
		var original := helper.make_history("normal",Credit.BASELINE,version,str(version))
		check(original.get("success",false),"Fresh disposable V%d original history" % version)
		if not original.get("success",false): continue
		if version == 2:
			var fresh := Convert.convert(original.records.slice(0,1),"normal")
			check(fresh.success and fresh.record.current.permanent.level == 1 and fresh.record.evidence.awards.is_empty(),"Actual first committed level-one character, no fabricated creation evidence")
			if fresh.success: exercise("fresh_level_one",fresh.text,1)
		var converted := Convert.convert(original.records,"normal")
		check(converted.success and converted.comparison.success,"Fresh source-backed conversion and independent equivalence")
		if converted.success: exercise("normal_v%d" % version,converted.text,1)
	check(helper.failures.is_empty() and helper.helper._failures.is_empty(),"Reused source fixture assertions pass")
	PlayableCharacterPersistence.test_storage = old_storage
	PlayableCharacterPersistence.test_run_id = old_run
	PlayableCharacterPersistence.test_nonpersistent = old_nonpersistent

func frozen_matrix() -> void:
	var root := OS.get_cache_dir().path_join("itank-storage-tests/compact45m_45n_session_20261117e")
	for name: String in ["normal_v2","normal_v4","dev_normal_v2","dev_normal_v4","small","168","221","233","400","1000"]:
		var text := read_fixture(root.path_join(name+".json"))
		if text.is_empty(): check(false,"Required frozen fixture missing "+name); continue
		exercise(name,text,3 if name in ["normal_v4","233"] else 1)
	exercise("native_credit_all_five",current_from_cache("compact45s_bench_19316_960654/historical/v2"),1)
	exercise("inventory1005",current_from_cache("compact45s_bench_25204_2215533/inventory"),1)
	if examples.has("native_credit_all_five"):
		var r: Dictionary = examples.native_credit_all_five.record
		var attrs: Array = []
		for purchase: Dictionary in r.evidence.purchases:
			if purchase.purchase_kind == "attribute" and not attrs.has(purchase.target_id): attrs.append(purchase.target_id)
		check(["str","dex","spd","wis","end"].all(func(a): return attrs.has(a)),"All five original real purchases retained")
		check(r.compact_version == 2 and r.accounting.credit_expc == 10000,"Original native credit witness/version and EXPC-only accounting retained")
	if examples.has("1000"):
		check(examples["1000"].record.applied_ids.size() >= 1000 and examples["1000"].record.recent_journal.size() == 20,"Exact lifetime registry survives 20-entry journal eviction")
	if examples.has("inventory1005"): check(examples.inventory1005.record.current.items.size() == 1005,"Every high-inventory instance retained")
func exercise(name: String, text: String, samples: int) -> void:
	var starter := trusted(text)
	check(starter.success,"Trusted allowlisted source "+name)
	if not starter.success: return
	var source: CombatCharacterDefinitionResource = starter.source
	var reference := V6.decode(text,source)
	check(reference.success,"Existing full V6 reference accepts "+name)
	if not reference.success: return
	var r: Dictionary = reference.record
	var timings: Array = []; var built := {}
	for i in range(samples):
		var memory := OS.get_static_memory_usage()
		built = Package.build(text,source,r.current.character_id,r.current.profile_namespace)
		check(built.success,"Independent package construction "+name+": "+str(built.get("reason")))
		if not built.success: return
		var t := Time.get_ticks_usec()
		var verified := Package.cold_verify(built.head_text,built.text,source,r.current.character_id,r.current.profile_namespace)
		var cold_ms := float(Time.get_ticks_usec()-t)/1000.0
		check(verified.success,"Full standalone cold verification "+name+": "+str(verified.get("reason")))
		if not verified.success: return
		check(verified.record_json == text and verified.record == r and verified.projection == V6._projection(r),"Exact bytes, complete current projection and evidence match independent V6 reference "+name)
		check(verified.record.applied_ids == r.applied_ids and verified.record.evidence == r.evidence and verified.record.current.recovery == r.current.recovery,"Lifetime bindings, original growth/credit, items and checkpoint/RNG/timers preserved "+name)
		var recovery := Package.recover(built.head_text,"truncated",built.replica,source,r.current.character_id,r.current.profile_namespace)
		check(recovery.success and recovery.repair_current and recovery.text == built.text,"Exact latest replica repair "+name)
		check(not recovery.restore_authorized,"Pure recovery never authorizes publication "+name)
		if i == 0: examples[name] = {"built":built,"source":source,"record":r}
		else: check(examples[name].built.text == built.text and examples[name].built.head_text == built.head_text,"Deterministic canonical output "+name)
		timings.append({"build_ms":built.build_ms,"cold_ms":cold_ms,"recover_ms":recovery.recovery_ms,"live_delta":OS.get_static_memory_usage()-memory})
	metrics.append({"fixture":name,"samples":timings,"v6_bytes":text.to_utf8_buffer().size(),"package_bytes":built.package_bytes,"replica_bytes":built.replica_bytes,"head_bytes":built.head_text.to_utf8_buffer().size(),"receipt_bytes":built.receipt_bytes,"ids":r.applied_ids.size(),"operations":r.operations.size(),"items":r.current.items.size(),"record_sha256":text.sha256_text(),"package_sha256":built.text.sha256_text()})
func recovery_matrix(f: Dictionary) -> void:
	var b: Dictionary = f.built; var source: CombatCharacterDefinitionResource = f.source
	var profile: String = f.record.current.character_id; var scope: String = f.record.current.profile_namespace
	check(b.text == b.replica,"Primary and recovery replica byte-identical")
	for pair: Array in [[b.text,b.replica,false,false],["",b.replica,true,false],["partial",b.replica,true,false],[b.text,"damaged",false,true]]:
		var restored := Package.recover(b.head_text,pair[0],pair[1],source,profile,scope)
		check(restored.success and restored.text == b.text and restored.repair_current == pair[2] and restored.repair_replica == pair[3],"Primary/replica independent damage handling")
	check(not Package.recover(b.head_text,"bad","bad",source,profile,scope).success,"Both copies damaged: no older fallback")
	check(not Package.recover("",b.text,b.replica,source,profile,scope).success,"Missing acknowledged head fails closed")
	check(not Package.cold_verify("",b.text,source,profile,scope).success,"Standalone current admission requires head authority")
	var h: Dictionary = JSON.parse_string(b.head_text).body; h.sequence += 1
	check(not Package.recover(Package._seal_head(h),b.text,b.replica,source,profile,scope).success,"Rehashed conflicting sequence cannot introduce another head")
	check(not Package.recover(b.head_text,b.text,b.replica,source,profile,scope,Package._seal_head(h)).success,"Conflicting head witnesses never select higher sequence")
	h = JSON.parse_string(b.head_text).body; h.replica.identity[4] = "older_copy"
	check(not Package.cold_verify(Package._seal_head(h),b.text,source,profile,scope).success,"Replica identity bound to exact latest head")
	h = JSON.parse_string(b.head_text).body; h.version = 1
	check(not Package.cold_verify(Package._seal_head(h),b.text,source,profile,scope).success,"Unsupported head/route version rejected")
	check(not Package.cold_verify(b.head_text,b.text,source,"dev_vaelis_thorn","dev_normal").success,"Cross-profile/namespace source context rejected")
	check(not CharacterSaveContract.decode(b.text).success,"Legacy save reader cannot silently accept new package")
func lineage_matrix(f: Dictionary) -> void:
	var b: Dictionary = f.built; var source: CombatCharacterDefinitionResource = f.source
	var profile: String = f.record.current.character_id; var scope: String = f.record.current.profile_namespace
	# Source-valid transport-only fixture; no fabricated XP/items or gameplay claim.
	var first_record := next_record(f.record,"45w_direct",source)
	check(not first_record.is_empty(),"Existing successor fixture source-valid")
	var first_text := V6.encode(first_record,source)
	check(first_text.success,"Independent V6 successor validates")
	if not first_text.success: return
	var first := Package.build(first_text.text,source,profile,scope,b.text,b.head_text)
	check(first.success,"Receipt bound to actual complete parent and original request")
	if not first.success: return
	var direct := Package.relationship(b.head_text,b.text,first.head_text,first.text,source,profile,scope)
	check(direct.success and direct.classification == "verified_direct_extension" and not direct.restore_authorized,"Known direct descendant independently verified, no restore performed")
	var exact := Package.relationship(first.head_text,first.text,first.head_text,first.text,source,profile,scope)
	check(exact.success and exact.classification == "exact_installed" and not exact.restore_authorized,"Exact installed package is a diagnostic no-op")
	check(not Package.relationship(first.head_text,first.text,b.head_text,b.text,source,profile,scope).success,"Older progression rejected")
	check(not Package.recover(first.head_text,"damaged",b.replica,source,profile,scope).success,"Older valid replica cannot repair newer acknowledged head")
	var branch_record := next_record(f.record,"45w_branch",source)
	var branch := Package.build(V6.encode(branch_record,source).text,source,profile,scope,b.text,b.head_text)
	check(branch.success and not Package.relationship(first.head_text,first.text,branch.head_text,branch.text,source,profile,scope).success,"Same-sequence valid conflicting branch rejected")
	var anchored := Package.build(first_text.text,source,profile,scope)
	check(anchored.success and not Package.relationship(b.head_text,b.text,anchored.head_text,anchored.text,source,profile,scope).success,"Higher anchored snapshot cannot invent missing lineage")
	var second_record := next_record(first_record,"45w_second",source)
	var second := Package.build(V6.encode(second_record,source).text,source,profile,scope,first.text,first.head_text)
	check(second.success,"Second real rule-valid current builds without reverse history")
	var distant := Package.relationship(b.head_text,b.text,second.head_text,second.text,source,profile,scope)
	check(not distant.success and distant.reason == "receipt_path_requires_intermediate_semantic_proof" and not distant.restore_authorized,"Longer receipt path explicitly unsupported, never promoted to restore authority")
	var cold := Package.cold_verify(second.head_text,second.text,source,profile,scope)
	check(cold.success and cold.receipts.size() == 3 and cold.record_json == V6.encode(second_record,source).text,"Cold current verifies receipt links without reconstructing prior snapshots")
	var changed: Dictionary = JSON.parse_string(first.text.split("\n")[2]); changed.entries[0].body.operation.request_digest = "0".repeat(64)
	var altered := reframe(first.text,null,changed.entries)
	check(not Package.cold_verify(altered.head_text,altered.text,source,profile,scope).success,"Rehashed changed receipt/original request rejected")
	if examples.has("normal_v2"):
		var other: Dictionary = examples.normal_v2.built
		var unrelated := Package.relationship(b.head_text,b.text,other.head_text,other.text,source,profile,scope)
		check(not unrelated.success and unrelated.reason == "unrelated_epoch","Two independently valid unrelated epochs rejected")

# Transport-only fixture with its exact trusted source. It grants no XP,
# items or credit and is never passed off as gameplay authorization.
func next_record(record: Dictionary, id: String, source: CombatCharacterDefinitionResource) -> Dictionary:
	var c := record.duplicate(true)
	c.head.sequence += 1; c.head.parent_digest = V6.digest(record); c.current.generation += 1
	c.operations.append({"id":id,"request_digest":V6.digest({"kind":"disposable_transport_fixture","id":id})})
	return V6.assemble(c.current,c.evidence,c.operations,c.head,source,c.compact_version)

func reframe(package: String, record: Variant = null, receipts: Variant = null) -> Dictionary:
	var lines := package.trim_suffix("\n").split("\n")
	var text: String = lines[1]
	var entries: Array = JSON.parse_string(lines[2]).entries if receipts == null else receipts
	if record != null:
		var body := Package.canonical(record)
		text = Package.canonical({"format":CharacterSaveContract.FORMAT,"version":6,"payload_json":body,"sha256":body.sha256_text()})
		var old: Dictionary = entries.back().body
		entries[-1] = Package._entry(old.kind,Package._state(record,text),record.operations.back(),old.parent)
	var manifest := Package._manifest(Package._state(JSON.parse_string(JSON.parse_string(text).payload_json),text),entries)
	var result := Package._text(manifest,text,entries)
	return {"text":result,"head_text":Package._seal_head(Package._head(manifest,result))}
func negative_matrix(f: Dictionary) -> void:
	var b: Dictionary = f.built; var source: CombatCharacterDefinitionResource = f.source
	var profile: String = f.record.current.character_id; var scope: String = f.record.current.profile_namespace
	var variants: Array = []
	var r: Dictionary = f.record.duplicate(true); r.applied_ids.remove_at(0); variants.append(r)
	r = f.record.duplicate(true); r.applied_ids.append(r.applied_ids[0].duplicate(true)); variants.append(r)
	r = f.record.duplicate(true); r.applied_ids[0].record_digest = "0".repeat(64); variants.append(r)
	r = f.record.duplicate(true); r.operations.append(r.operations[0].duplicate(true)); variants.append(r)
	r = f.record.duplicate(true); r.accounting.expc_available += 1; variants.append(r)
	r = f.record.duplicate(true); r.current.items.append(r.current.items[0].duplicate(true)); variants.append(r)
	if not f.record.evidence.awards.is_empty():
		r = f.record.duplicate(true); r.evidence.awards.append(r.evidence.awards[0].duplicate(true)); variants.append(r)
	if not f.record.evidence.purchases.is_empty():
		r = f.record.duplicate(true); r.evidence.purchases.append(r.evidence.purchases[0].duplicate(true)); variants.append(r)
	if not f.record.evidence.growth.is_empty():
		r = f.record.duplicate(true); r.evidence.growth[0].hpb += 1; variants.append(r)
		r = f.record.duplicate(true); r.evidence.growth[0].wisdom += 1; variants.append(r)
		r = f.record.duplicate(true); r.evidence.order.reverse(); variants.append(r)
	if f.record.evidence.credit != null:
		r = f.record.duplicate(true); r.evidence.credit.records.append(r.evidence.credit.records[0].duplicate(true)); variants.append(r)
		r = f.record.duplicate(true); r.evidence.credit_predecessor = null; variants.append(r)
	for invalid: Dictionary in variants:
		var forged := reframe(b.text,invalid)
		var independent := V6.decode(forged.text.split("\n")[1],source)
		check(not independent.success,"Original full validator independently rejects forged semantic evidence")
		check(not Package.cold_verify(forged.head_text,forged.text,source,profile,scope).success,"Recomputed package/head checksums cannot launder invalid evidence")
	check(not Package.cold_verify(b.head_text,b.text.left(b.text.length()-1),source,profile,scope).success,"Truncated file rejected")
	check(not Package.verify_package(b.text+"extra\n",source,profile,scope).success,"Unknown trailing frame rejected")
	var omitted: Dictionary = f.record.duplicate(true); omitted.current.erase("recovery")
	var incomplete := reframe(b.text,omitted)
	check(not Package.cold_verify(incomplete.head_text,incomplete.text,source,profile,scope).success,"Missing current checkpoint authority rejected")
	var frames: PackedStringArray = b.text.split("\n")
	var flagged: Dictionary = JSON.parse_string(frames[0]); flagged.verified = true
	var flag_text := Package._text(flagged,frames[1],JSON.parse_string(frames[2]).entries)
	check(not Package.verify_package(flag_text,source,profile,scope).success,"Persisted verified flag cannot replace closed proof contract")
	var noncanonical := Package._text(JSON.parse_string(frames[0])," "+frames[1],JSON.parse_string(frames[2]).entries)
	check(not Package.verify_package(noncanonical,source,profile,scope).success,"Noncanonical current bytes rejected even with recomputed package checksum")
	var lines: PackedStringArray = b.text.trim_suffix("\n").split("\n"); var m: Dictionary = JSON.parse_string(lines[0]); m.version = 2; lines[0] = Package.canonical(m)
	var body: String = lines[0]+"\n"+lines[1]+"\n"+lines[2]+"\n"; var wrong_version: String = body+Package.canonical({"kind":"integrity","sha256":body.sha256_text()})+"\n"
	check(not Package.verify_package(wrong_version,source,profile,scope).success,"Unsupported new package version rejected")
	var wrong_source: CombatCharacterDefinitionResource = source.duplicate(true); wrong_source.attributes.dex += 1
	check(not Package.cold_verify(b.head_text,b.text,wrong_source,profile,scope).success,"Changed trusted source cannot borrow earlier verification")
func restart(f: Dictionary) -> void:
	var path := OS.get_cache_dir().path_join("itank-storage-tests/compact45w_restart_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()])
	DirAccess.make_dir_recursive_absolute(path)
	for pair: Array in [["current",f.built.text],["replica",f.built.replica],["head",f.built.head_text],["context",Package.canonical({"profile":f.record.current.character_id,"scope":f.record.current.profile_namespace,"baseline":f.record.current.lineage.baseline_digest})]]:
		var file := FileAccess.open(path.path_join(pair[0]+".txt"),FileAccess.WRITE); file.store_string(pair[1]); file.close()
	var output: Array = []
	var exit := OS.execute(OS.get_executable_path(),["--headless","--path",ProjectSettings.globalize_path("res://"),"--script","res://tests/compact_v6_snapshot_process.gd","--",path],output,true)
	check(exit == 0 and str(output).contains("45W_RESTART_OK") and not str(output).contains("ERROR:"),"Fresh process independently cold-verifies bytes, checkpoint and replica without warm flags")
func legacy_reference() -> void:
	var hint := OS.get_environment("ARENA45W_LEGACY_BUNDLE")
	check(not hint.is_empty(),"Explicit existing frozen disposable legacy archive supplied")
	if hint.is_empty(): return
	var allowed := OS.get_cache_dir().replace("\\","/").path_join("itank-storage-tests/compact45s_")
	if not hint.replace("\\","/").simplify_path().begins_with(allowed) or not hint.get_file().begins_with("restoration_") or not hint.ends_with(".bundle"): check(false,"Frozen legacy archive isolation"); return
	var outer: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(hint))
	check(outer.sha256 == outer.body_json.sha256_text(),"Frozen original archive integrity")
	var rows: Array = CharacterSaveContract._normalize_json_numbers(JSON.parse_string(outer.body_json))
	var converted := Convert.convert(rows,"dev_normal")
	check(converted.success and converted.generation_count == 233 and converted.comparison.success,"Full original 233-generation walk and independent original-character equivalence")
	if not converted.success: return
	exercise("legacy233_independent",converted.text,1)
	var projected := V6._projection(examples.legacy233_independent.record)
	var original := CharacterSaveContract.decode(rows.back().document)
	check(original.success and original.payload == projected,"Complete new cold projection equals original legacy head, not merely converter totals")
	metrics.append({"fixture":"one_time_legacy_conversion","metrics":converted.metrics,"excluded_from_package_timings":true})
