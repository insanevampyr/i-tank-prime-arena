extends RefCounted
const Host = preload("res://tests/compact_v6_windows_host.gd")
const Windows = preload("res://scripts/rewards/compact_v6_windows_storage.gd")
const V6 = preload("res://scripts/rewards/compact_character_v6_prototype.gd")
const Historical = preload("res://tests/test_historical_vaelis_admission.gd")
const Credit = preload("res://scripts/rewards/character_expc_credit.gd")
var failures: Array[String] = []
var assertions := 0
var metrics: Array = []
var root := ""
class FailingRoute extends Windows:
	var fault := ""
	var triggered := false
	func _write(path: String, text: String) -> bool:
		if not triggered and ((fault == "disk_full" and path.ends_with("record.pending")) or (fault == "capsule_write" and path.ends_with("capsule.pending")) or (fault == "route_stage" and path.ends_with("route.pending"))):
			triggered = true; return false
		if not triggered and fault == "partial_record" and path.ends_with("record.pending"):
			triggered = true; super._write(path,text.left(text.length()/2)); return false
		return super._write(path,text)
	func _rename(a: String, b: String) -> bool:
		if not triggered and fault == "before_fence" and a.ends_with("fence.pending"):
			triggered = true; return false
		var result := super._rename(a,b)
		if result and not triggered and ((fault == "after_fence" and a.ends_with("fence.pending")) or (fault == "after_route" and b.ends_with("route.json"))):
			triggered = true; return false
		return result
func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok: failures.append(message)
func approve(q: Dictionary) -> Dictionary: return {"confirmed":true,"binding":V6.digest(q)}
func run() -> Array[String]:
	var old_storage := PlayableCharacterPersistence.test_storage
	var old_nonpersistent := PlayableCharacterPersistence.test_nonpersistent
	var old_run := PlayableCharacterPersistence.test_run_id
	PlayableCharacterPersistence.test_nonpersistent = false
	root = OS.get_cache_dir().path_join("itank-storage-tests/compact45s_native_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()])
	for setting: Array in [["normal",1],["dev_normal",1],["dev_normal",10]]: fresh(setting[0],setting[1])
	converted_credit()
	interruption_matrix()
	race()
	legacy_versions()
	var complete := Host.new()
	complete.complex(root.path_join("full_gameplay"),true,complete.factory,true)
	assertions += complete.assertions
	failures.append_array(complete.failures)
	check(complete.activation_failures.is_empty(),"Complex gameplay activation remains verified.")
	metrics.append({"fixture":"complete_gameplay","boundaries":complete.metrics})
	PlayableCharacterPersistence.test_storage = old_storage
	PlayableCharacterPersistence.test_nonpersistent = old_nonpersistent
	PlayableCharacterPersistence.test_run_id = old_run
	print("45S_METRICS "+JSON.stringify({"samples":metrics,"root":root,"native_static":OS.get_static_memory_usage(),"native_peak":OS.get_static_memory_peak_usage()}))
	print("45S Windows compact route: %d assertions." % assertions)
	return failures

func fresh(mode: String, multiplier: int) -> void:
	var helper := Host.new()
	var f: Dictionary = helper.native_start(root.path_join(mode+str(multiplier)),mode,multiplier)
	check(f.success,"Fresh compact Wave 1 admitted: "+str(f.get("reason")))
	if not f.success: return
	var p: Host.NativeService = f.service
	var s: ArenaCombatSession = f.session
	check(p.errors.is_empty() and p.records.size() == 1,"One native publication, no legacy generation save.")
	if p.records.is_empty(): return
	var loaded: Dictionary = p.route.load_current()
	check(loaded.success and loaded.record == p.records.back() and loaded.record.head.sequence == 1,"Exact first acknowledged compact Wave 1.")
	check(not p.storage.read_profile(p.profile_id).success and not p.storage.write_profile(p.profile_id,p._prior,"legacy_after_activation").success,"Current legacy writer cannot cross the fence.")
	var combat := Historical.new().helper
	combat._defeat_wave(s)
	p.lost_ack = true
	check(s.collect_all_ground_loot().success,"Actual source XP and loot persist compactly.")
	check(s.request_next_wave().success,"Compact NEXT WAVE keeps admitted policy.")
	check(p.errors.is_empty(),"Coordinator-only publication: "+str(p.errors))
	var cold: Dictionary = p.route.load_current()
	check(cold.success and V6._projection(cold.record) == CharacterSaveContract.decode(CharacterSaveContract.encode(p._prior).text).payload,"Cold whole-character equivalence.")
	check(p.get_run_reward_policy().xp_multiplier == multiplier,"Admitted immutable reward multiplier.")
	var control := Host.new()
	var original: Dictionary = control.start(CharacterSaveStorage.new(root.path_join(mode+str(multiplier)+"_control")),mode,multiplier,{},false)
	if original.success:
		combat._defeat_wave(original.session); original.session.collect_all_ground_loot(); original.session.request_next_wave()
		check(original.session.get_state_snapshot() == s.get_state_snapshot() and CharacterSaveContract.decode(CharacterSaveContract.encode(original.service._prior).text).payload == p._prior,"Native/legacy seeded replay and simulated-client full state converge.")
	else: check(false,"Independent ordinary persistence control.")
	var resumed: Dictionary = helper.native_start(p.route.root,mode,null,cold.record)
	check(resumed.success and resumed.service._prior == CharacterSaveContract.decode(CharacterSaveContract.encode(p._prior).text).payload,"Cold compact RESUME equals the existing canonical cold-contract representation.")
	check(helper.failures.is_empty() and helper.activation_failures.is_empty() and combat._failures.is_empty(),"Real source fixtures remain valid: "+str(helper.failures))
	metrics.append({"fixture":mode+str(multiplier),"writes":p.writes,"prepare":p.measures,"load_ms":cold.get("load_ms")})
	if mode == "normal": corruption(p.route)

func converted_credit() -> void:
	var h := Historical.new(); h.root = root.path_join("historical")
	var legacy := h.make_history("dev_normal",Credit.BASELINE,2,"v2")
	check(legacy.get("success",false),"Disposable V2 with actual history.")
	if not legacy.get("success",false): return
	var converted := preload("res://scripts/rewards/legacy_to_compact_v6_prototype.gd").convert(legacy.records,"dev_normal")
	if not converted.success: check(false,"Initial conversion"); return
	var helper := Host.new()
	var f: Dictionary = helper.native_start(legacy.storage._root,"dev_normal",null,converted.record)
	check(f.success and helper.activation_failures.is_empty(),"Explicit full-verified conversion activation: "+str(helper.activation_failures))
	if not f.success: return
	var p: Host.NativeService = f.service
	var s: ArenaCombatSession = f.session
	for i in range(2):
		check(s.request_next_wave().success,"Native resumed continuation.")
		h.helper._defeat_wave(s)
		check(s.collect_all_ground_loot().success,"Real awards before compact fixed credit.")
	for attr: String in ["end","wis"]:
		var value: int = s.simulation.get_actor_definition(&"player").attributes[attr]
		check(s.request_character_advancement(&"attribute",StringName(attr),"45s_"+attr,{"expected_current_value":value,"expected_cost":3000}).success,"Native actual "+attr+" advancement.")
	var previous: Dictionary = p._prior.duplicate(true)
	var credited := helper.grant_native(f)
	check(credited.success,"Confirmed native credit through sole coordinator: "+str(credited.get("reason")))
	check(p._prior.xp.earned == previous.xp.earned and p._prior.xp.unspent == previous.xp.unspent+10000,"Native fixed credit changes EXPC only.")
	check(helper.grant_native(f).get("no_op",false),"Repeated fixed request is lifetime exactly once.")
	for attr: String in ["str","dex","spd"]:
		var value: int = s.simulation.get_actor_definition(&"player").attributes[attr]
		var selection := {"expected_current_value":value,"expected_cost":3000 if value <= 10 else 5000}
		if attr == "dex": selection.allocation = "dt"
		check(s.request_character_advancement(&"attribute",StringName(attr),"45s_"+attr,selection).success,"Native actual "+attr+" advancement.")
	var cold: Dictionary = p.route.load_current()
	check(cold.success and cold.record.compact_version == 2 and V6._projection(cold.record) == CharacterSaveContract.decode(CharacterSaveContract.encode(p._prior).text).payload,"Cold native-credit and all five advancements exact.")
	check(p.errors.is_empty() and helper.failures.is_empty(),"Actual native operations preserve source authority: "+str(p.errors)+str(helper.failures))
	metrics.append({"fixture":"converted_native_credit","writes":p.writes,"prepare":p.measures,"load_ms":cold.get("load_ms")})
	check(Array(DirAccess.get_files_at(p.route.directory)).filter(func(n): return n.begins_with("generation_")).size() == legacy.records.size()+1,"Legacy prefix is preserved; only one technical fence added, never new legacy characters.")
	var authorization: Dictionary = s.get_abandon_run_authorization()
	check(authorization.success,"Existing explicit NEW RUN authorization remains required.")
	if authorization.success:
		var next: Dictionary = helper.native_start(p.route.root,"dev_normal",1,cold.record,true,authorization.checkpoint)
		check(next.success and next.service._prior.xp == p._prior.xp and next.service.get_run_reward_policy().xp_multiplier == 1,"New unique run preserves credits/history and locks selected x1: "+str(next.get("reason"))+str(helper.failures)+(str(next.service.errors) if next.success else ""))

func corruption(route: RefCounted) -> void:
	var initial: Dictionary = route.load_current()
	if not initial.success: check(false,"Corruption baseline"); return
	var current: String = route.objects.path_join("record_"+initial.route.digest+".v6")
	var capsule: String = route.objects.path_join("capsule_"+initial.route.capsule_digest+".v6backup")
	var metadata: String = route.objects.path_join("route.json")
	var meta_text := FileAccess.get_file_as_string(metadata)
	route._write(current,"truncated")
	var recovered: Dictionary = route.load_current()
	check(recovered.success and recovered.exact_recovery_needed and recovered.text == initial.text,"Capsule reconstructs exactly current, never previous.")
	check(route.recover().get("success",false) and not route.load_current().exact_recovery_needed,"Locked exact repair and independent readback.")
	check(route.recover().text == initial.text,"Repeated recovery cannot duplicate effects.")
	var previous: String = route.objects.path_join("record_"+initial.route.previous+".v6")
	var previous_text := FileAccess.get_file_as_string(previous)
	route._write(previous,"corrupt previous")
	check(route.load_current().text == initial.text,"Damaged previous does not replace or prevent exact current proof.")
	route._write(previous,previous_text)
	route._write(capsule,"corrupt capsule")
	check(not route.load_current().success and not route.recover().success,"Damaged required capsule fails closed despite previous record.")
	route._write(capsule,initial.capsule_text)
	for kind: String in ["truncated","missing","stale","namespace","source"]:
		if kind == "missing": DirAccess.remove_absolute(metadata)
		elif kind == "truncated": route._write(metadata,"{")
		else:
			var m: Dictionary = initial.route.duplicate(true)
			if kind == "stale": m.sequence -= 1
			if kind == "namespace": m.namespace = "dev_normal"
			if kind == "source": m.source_digest = "0".repeat(64)
			route._write(metadata,route._pack(m))
		check(not route.load_current().success and not route.recover().success,"Missing/changed authority never falls back to legacy or previous: "+kind)
		route._write(metadata,meta_text)
	check(route.load_current().text == initial.text,"Disposable damage tests leave exact acknowledged state restored.")
	var records: Array = Array(DirAccess.get_files_at(route.objects)).filter(func(n): return n.begins_with("record_") and n.ends_with(".v6"))
	var capsules: Array = Array(DirAccess.get_files_at(route.objects)).filter(func(n): return n.begins_with("capsule_") and n.ends_with(".v6backup"))
	check(records.size() == 2 and capsules.size() == 1,"Bounded technical retention: two records and one capsule.")

func interruption_matrix() -> void:
	var h := Historical.new(); h.root = root.path_join("faults")
	var base := h.make_history("dev_normal",Credit.BASELINE,2,"base")
	if not base.get("success",false): check(false,"Fault matrix source"); return
	var source: CombatCharacterDefinitionResource = PlayableCharacterAdmission.prepare_starter(&"vaelis_thorn","dev_normal",Credit.BASELINE).source
	for fault: String in ["disk_full","partial_record","capsule_write","before_fence","after_fence","route_stage","after_route"]:
		var route := FailingRoute.new(root.path_join("fault_"+fault),source,Credit.PROFILE,"dev_normal")
		var lease: Dictionary = route.guard.acquire_writer(Credit.PROFILE)
		var restored: Dictionary = route.guard.restore_history(Credit.PROFILE,base.records,[],lease.owner)
		route.guard.release_writer(Credit.PROFILE,lease.owner)
		check(restored.success,"Disposable original legacy archive for "+fault)
		var coordinator := CharacterPersistenceCoordinator.new(route.guard)
		route.fault = fault
		var result := coordinator.activate_compact(route,approve)
		check(route.triggered,"Failure injected at real I/O boundary: "+fault)
		if fault == "after_route":
			check(result.success and route.load_current().success,"Publication followed by reported failure reconciles exact readback.")
		elif fault in ["after_fence","route_stage"]:
			check(not result.success and not route.guard.read_profile(Credit.PROFILE).success,"Fence makes partial activation fail closed for old reader: "+fault)
			route.fault = ""
			var recovered: Dictionary = route.recover()
			check(recovered.success and recovered.record.current.generation == base.records.size(),"Restart completes exact staged initial activation: "+fault+str(recovered.get("reason")))
		else:
			check(not result.success and route.guard.read_profile(Credit.PROFILE).success,"Before fence, legitimate legacy head remains intact: "+fault)
			route.fault = ""
			check(coordinator.activate_compact(route,approve).success,"Exact authorized activation retry: "+fault)
		var before: Dictionary = route.load_current()
		check(before.success,"Every isolated interruption recovers exact original compact head.")
		if before.success:
			var count: int = Array(DirAccess.get_files_at(route.directory)).filter(func(n):return n.begins_with("generation_")).size()
			check(count == 1,"Restored original history remains in its exact bundle plus one technical fence.")
			var blocked := route.acquire()
			check(blocked.success and not CharacterSaveStorage.new(route.root).write_profile(Credit.PROFILE,V6._projection(before.record),"competing_legacy").success,"Competing legacy writer cannot acquire the compact writer's lease.")
			check(not Windows.new(route.root,source,Credit.PROFILE,"dev_normal").recover().success,"Restart never steals a live or unverified writer lease.")
			route.release(blocked.owner)
	check(h.failures.is_empty() and h.helper._failures.is_empty(),"Fault fixture history is legitimate source progression.")

func race() -> void:
	var helper := Host.new()
	var a: Dictionary = helper.native_start(root.path_join("race"),"normal",1)
	if not a.success: check(false,"Race initial"); return
	Historical.new().helper._defeat_wave(a.session)
	var baseline: Dictionary = a.service.route.load_current()
	var b: Dictionary = helper.native_start(a.service.route.root,"normal",null,baseline.record)
	if not b.success: check(false,"Race second"); return
	a.service.before_commit = func():
		check(b.session.request_character_development("preferences",{"order":["nac","block","dodge","soak"]},"45s_race_b").success,"Second independently prepared writer commits first.")
	var rejected: Dictionary = a.session.request_character_development("preferences",{"order":["nac","dodge","block","soak"]},"45s_race_a")
	check(not a.service.errors.is_empty() and a.service.generation == baseline.record.current.generation,"First writer's stale prepared parent cannot receive a persistence acknowledgement: "+str(rejected))
	check(not rejected.get("persistence",{}).get("success",true) and a.service.observer.current_copy() == baseline.record,"Losing mutation reports failed persistence and cannot advance its acknowledged compact parent.")
	var latest: Dictionary = a.service.route.load_current()
	check(latest.success and latest.record == b.service.observer.current_copy() and latest.record.head.sequence == baseline.record.head.sequence+1,"Exactly one competing operation is acknowledged; no second reward/item mutation.")

func legacy_versions() -> void:
	var h := Historical.new(); h.root = root.path_join("versions")
	for setting: Array in [["normal",4],["dev_normal",4],["dev_normal",5]]:
		var mode: String = setting[0]; var version: int = setting[1]
		var f := h.make_history(mode,Credit.BASELINE,4 if version == 4 else 2,mode+str(version))
		check(f.get("success",false),"Historical disposable V%d %s" % [version,mode])
		if not f.get("success",false): continue
		if version == 5:
			var credit: Dictionary = preload("res://tests/test_legacy_to_compact_v6.gd").new().credit_history(f.records)
			if not credit.success: check(false,"Existing historical fixed credit"); continue
			var guard := CharacterSaveStorage.new(root.path_join("v5_records"))
			var lease := guard.acquire_writer(Credit.PROFILE)
			var restore := guard.restore_history(Credit.PROFILE,credit.rows,[],lease.owner)
			guard.release_writer(Credit.PROFILE,lease.owner)
			check(restore.success,"Existing V5 credit preserved in independent verified legacy archive.")
			f.storage = guard; f.records = credit.rows
		var converted: Dictionary = preload("res://scripts/rewards/legacy_to_compact_v6_prototype.gd").convert(f.records,mode)
		if not converted.success: check(false,"Legacy version conversion"); continue
		var host := Host.new()
		var opened: Dictionary = host.native_start(f.storage._root,mode,null,converted.record)
		check(opened.success and host.activation_failures.is_empty(),"Full V%d activation/cold admission" % version)
		if opened.success:
			var p: Host.NativeService = opened.service
			check(p._prior == V6._projection(converted.record) and p.get_run_reward_policy().xp_multiplier == (converted.record.current.run_reward_policy.runs.back().xp_multiplier if version == 4 else 10),"All original balances, history, items, resources and locked policy retained.")
			if version == 5: check(host.grant_native(opened).get("no_op",false),"Already credited historical V5 can never receive the native grant.")
