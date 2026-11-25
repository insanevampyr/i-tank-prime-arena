extends RefCounted
const X = preload("res://scripts/rewards/compact_v6_incremental_snapshot.gd")
const Package = preload("res://scripts/rewards/compact_v6_snapshot_package.gd")
const V6 = preload("res://scripts/rewards/compact_character_v6_prototype.gd")
const Q = preload("res://tests/test_compact_v6_gameplay_candidate.gd")
const Historical = preload("res://tests/test_historical_vaelis_admission.gd")
const Convert = preload("res://scripts/rewards/legacy_to_compact_v6_prototype.gd")
const Credit = preload("res://scripts/rewards/character_expc_credit.gd")
const Grant = preload("res://scripts/rewards/character_expc_grant.gd")
var failures: Array[String] = []
var assertions := 0
var services: Array = []
var metrics: Array = []
var witnesses := {}
var root := ""
func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok: failures.append(label)

# A disposable ACKNOWLEDGEMENT WITNESS, not a storage writer/coordinator. Only
# the original legacy coordinator writes files. Never used by playable code.
class Witness extends RefCounted:
	var value := {"success":true,"owner":"45x_host_lease","head_text":"","text":"","replica":""}
	func read() -> Dictionary: return value.duplicate(true)
	func remember(b: Dictionary) -> void:
		value.head_text = b.head_text; value.text = b.text; value.replica = b.replica

class Observed extends Q.Observed:
	var witness := Witness.new()
	var audit: Callable
	var samples: Array = []
	func bind_runtime(session: ArenaCombatSession) -> Dictionary:
		host = weakref(session)
		if not compact_parent.is_empty() and witness.value.head_text.is_empty():
			var original := V6.encode(compact_parent,source)
			var baseline := Package.build(original.get("text",""),source,profile_id,mode)
			if not baseline.success: errors.append(baseline); return baseline
			witness.remember(baseline)
		observer = _make_observer()
		if not observer._failure.is_empty(): errors.append({"reason":observer._failure})
		# Q's base binds the actual runtime; disabled only around its observer
		# installation. Its inherited ingest still calls our X observer.
		var saved := enabled; enabled = false
		var result := super.bind_runtime(session)
		enabled = saved
		return result
	func _make_observer() -> RefCounted: return X.new(self,witness.read)
	func ingest(session: ArenaCombatSession) -> Dictionary:
		var saved := enabled; enabled = false
		var result := super.ingest(session)
		enabled = saved
		if result.success and observer != null:
			var captured: Dictionary = observer.observe(session)
			if not captured.success: errors.append(captured)
		return result
	func publish_prepared() -> Dictionary:
		checkpoints += 1
		var before: Dictionary = host.get_ref().get_state_snapshot()
		var built: Dictionary = observer.prepare(observer.head())
		if not built.success: errors.append(built); return built
		last_prepared = built.prepared
		var repeated: Dictionary = observer.prepare(observer.head())
		if not repeated.success or repeated.prepared != last_prepared: errors.append({"reason":"nonexact_retry"})
		if not observer.check(last_prepared,observer.head()).success: errors.append({"reason":"sealed_authority_check"})
		if observer.adopt(last_prepared).success: errors.append({"reason":"adopt_without_ack"})
		if audit.is_valid(): audit.call(self,built)
		if before_commit.is_valid():
			var callback := before_commit; before_commit = Callable(); callback.call()
		# Exact existing playable publication statement, using disposable files.
		var result := _ack(CharacterPersistenceCoordinator.new(storage).commit(_prepared,source,profile_id,PlayableCharacterAdmission.RULES,_verify))
		if not result.success: return result
		witness.remember(last_prepared.copy())
		if lost_ack:
			var uncertain: Dictionary = observer.prepare(observer.head())
			if not uncertain.success or not uncertain.get("already_applied",false) or uncertain.prepared != last_prepared: errors.append({"reason":"lost_ack_not_exact"})
			lost_ack = false
		var adopted: Dictionary = observer.adopt(last_prepared)
		if not adopted.success: errors.append(adopted)
		else: records.append(observer.current_copy())
		if host.get_ref().get_state_snapshot() != before: errors.append({"reason":"adapter_mutated_simulation"})
		var cold_started := Time.get_ticks_usec()
		var cold := Package.cold_verify(witness.value.head_text,witness.value.text,source,profile_id,mode)
		var cold_ms := float(Time.get_ticks_usec()-cold_started)/1000.0
		if not cold.success or cold.projection != CharacterSaveContract.decode(_prepared.document).payload: errors.append({"reason":"cold_original_equivalence_failed","cold":cold.get("reason")})
		if cold.success and V6.encode(cold.record,source).text != cold.record_json: errors.append({"reason":"canonical_candidate_changed"})
		var repair := Package.recover(witness.value.head_text,"damaged",witness.value.replica,source,profile_id,mode)
		if not repair.success or repair.text != witness.value.text: errors.append({"reason":"exact_repair_failed"})
		samples.append(built.metrics.merged({"cold_ms":cold_ms,"repair_ms":repair.get("recovery_ms")}))
		return result

# Reuse the original complete LEGACY-control scenario. Its optional factory
# parameter otherwise selects native-ack representation expectations. Inject
# only the observer through start(), leaving every original assertion intact.
class Gameplay extends Q:
	var make: Callable
	func start(store: CharacterSaveStorage, mode: String, multiplier: Variant, parent: Dictionary = {}, enabled: bool = true, new_run: bool = false, authorization: Dictionary = {}, service_factory: Callable = Callable()) -> Dictionary:
		return super.start(store,mode,multiplier,parent,enabled,new_run,authorization,make if enabled else service_factory)

func factory(store: CharacterSaveStorage, _mode: String, _parent: Dictionary) -> Observed:
	var p := Observed.new()
	if witnesses.has(store._root): p.witness = witnesses[store._root]
	else: witnesses[store._root] = p.witness
	services.append(p); return p
func start(path: String, mode: String = "normal", multiplier: Variant = 1, parent: Dictionary = {}, new_run: bool = false, authorization: Dictionary = {}) -> Dictionary:
	return Q.new().start(CharacterSaveStorage.new(path),mode,multiplier,parent,true,new_run,authorization,factory)
func verify(f: Dictionary, label: String) -> void:
	var p: Observed = f.service
	check(p.errors.is_empty(),label+": "+str(p.errors))
	var r: Dictionary = p.observer.current_copy()
	check(not r.is_empty() and V6.validate(r,p.source).success,"Original full V6 oracle accepts "+label)
	if r.is_empty(): return
	check(Package.canonical(V6._projection(r)) == Package.canonical(CharacterSaveContract.decode(p._prepared.document).payload),"Complete original legacy projection equal "+label)
	check(p.witness.value.text == p.witness.value.replica,"Exact latest replica "+label)
	metrics.append({"fixture":label,"samples":p.samples,"admission":p.observer.admission_metrics,"package_bytes":p.witness.value.text.to_utf8_buffer().size(),"ids":r.applied_ids.size(),"items":r.current.items.size()})

func run() -> Array[String]:
	var saved := [PlayableCharacterPersistence.test_storage,PlayableCharacterPersistence.test_run_id,PlayableCharacterPersistence.test_nonpersistent]
	PlayableCharacterPersistence.test_nonpersistent = false
	root = OS.get_cache_dir().path_join("itank-storage-tests/compact45x_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()])
	var selected := OS.get_environment("ARENA45X_CASE")
	print("45X_BEGIN "+JSON.stringify({"pid":OS.get_process_id(),"selection":selected,"root":root}))
	if selected == "credit": native_credit()
	elif selected == "complex": complex_gameplay()
	else:
		for setting: Array in [["normal",1],["dev_normal",1],["dev_normal",10]]: ordinary(setting[0],setting[1])
		stale_competing()
	if selected in ["","remaining"] and OS.get_environment("ARENA45X_SHORT") != "1":
		if selected.is_empty(): complex_gameplay()
		native_credit()
		high_inventory()
		if not OS.get_environment("ARENA45X_LEGACY_BUNDLE").is_empty(): long_history()
		else: print("45X optional original 233 archive matrix not requested; no original-archive equivalence claim from this invocation")
	PlayableCharacterPersistence.test_storage = saved[0]; PlayableCharacterPersistence.test_run_id = saved[1]; PlayableCharacterPersistence.test_nonpersistent = saved[2]
	print("45X_METRICS "+JSON.stringify({"fixtures":metrics,"pid":OS.get_process_id(),"root":root,"static_bytes":OS.get_static_memory_usage(),"static_peak_bytes":OS.get_static_memory_peak_usage(),"scope":"native debug; no Windows/browser publication or Edge latency claim"}))
	print("45X incremental snapshot: %d assertions." % assertions)
	return failures

func ordinary(mode: String, multiplier: int) -> void:
	var path := root.path_join(mode+str(multiplier))
	var f := start(path,mode,multiplier)
	check(f.get("success",false),"Fresh authoritative Wave 1 "+mode+str(multiplier)+": "+str(f))
	if not f.get("success",false): return
	var p: Observed = f.service; var s: ArenaCombatSession = f.session
	check(p.records.size() == 1 and p.records[0].head.sequence == 1,"Actual fresh anchor, no invented earlier character")
	if mode == "normal": p.audit = probes
	Historical.new().helper._defeat_wave(s)
	check(s.collect_all_ground_loot().success,"Real item/currency collection")
	p.audit = Callable(); p.lost_ack = true
	if mode == "normal":
		var denied: Dictionary = p.observer.prepare_credit(s,p.observer.head(),func(q): return {"confirmed":true,"binding":V6.digest(q)})
		check(not denied.success and denied.get("reason") == "expc_credit_profile_mismatch","NORMAL cannot gain the fixed historical DEV credit")
	check(s.request_next_wave().success,"Real NEXT WAVE with lost observer acknowledgement")
	verify(f,mode+str(multiplier))
	var control := Q.new().scenario(path+"_control",mode,multiplier,false)
	check(control.get("success",false) and s.get_state_snapshot() == control.snapshot,"Unobserved same-seed legacy simulation/RNG/event history convergence")
	check(p._prior == control.payload,"Unobserved original progression/resources/receipts and exact generation equal")
	if mode == "normal":
		var replay := start(path+"_replay",mode,multiplier)
		Historical.new().helper._defeat_wave(replay.session); replay.session.collect_all_ground_loot(); replay.session.request_next_wave()
		check(replay.service.witness.value.text == p.witness.value.text and replay.service.witness.value.head_text == p.witness.value.head_text,"Same commands yield exact canonical package/head bytes")
		var resumed := start(path,mode,null,p.observer.current_copy())
		check(resumed.get("success",false) and resumed.service._prior == CharacterSaveContract.decode(p._prepared.document).payload,"Cold RESUME keeps current policy and exact original checkpoint")
		if resumed.get("success",false):
			Historical.new().helper._defeat_wave(resumed.session)
			check(resumed.session.collect_all_ground_loot().success,"Incremental operation after cold re-admission")
			# NEW RUN confirmation references the exact decoded durable checkpoint,
			# as in the original Q RESUME/NEW RUN control, not raw float variants.
			var loaded := start(path,mode,null,resumed.service.observer.current_copy())
			check(loaded.get("success",false),"Fresh exact durable checkpoint before explicit abandonment")
			if not loaded.get("success",false): return
			var auth: Dictionary = loaded.session.get_abandon_run_authorization()
			check(auth.success,"Existing explicit abandonment authorization")
			if auth.success:
				var next := start(path,mode,1,loaded.service.observer.current_copy(),true,auth.checkpoint)
				check(next.get("success",false) and next.service.get_run_reward_policy().xp_multiplier == 1,"NEW RUN uses original policy/unique run authorization: "+str(next))
				if next.get("success",false):
					verify(next,"normal_new_run")
					restart(next,path)

func restart(f: Dictionary, legacy_root: String) -> void:
	var dir := root.path_join("restart"); DirAccess.make_dir_recursive_absolute(dir)
	var value: Dictionary = f.service.witness.read()
	var file := FileAccess.open(dir.path_join("context.json"),FileAccess.WRITE)
	file.store_string(Package.canonical({"legacy_root":legacy_root,"scope":f.service.mode,"witness":value})); file.close()
	var output: Array = []
	var exit := OS.execute(OS.get_executable_path(),["--headless","--path",ProjectSettings.globalize_path("res://"),"--script","res://tests/compact_v6_incremental_process.gd","--",dir],output,true)
	check(exit == 0 and str(output).contains("45X_RESTART_OK") and not str(output).contains("ERROR:"),"New OS process cold-admits exact package and executes subsequent actual coordinator checkpoint: "+str(output).left(600))

func probes(p: Observed, built: Dictionary) -> void:
	# Probe once at a real prepared boundary; invalid contexts are disposable.
	p.audit = Callable()
	var b: Dictionary = built.prepared.copy(); var copy := b.duplicate(true); copy.text += " "
	built.prepared._package = "forged"
	check(built.prepared.copy() == b,"Caller copies and field assignment cannot rewrite owned sealed bytes")
	check(not p.observer.check(p.observer.Operation.new(copy.seal,copy.text,copy.head_text),p.observer.head()).success,"Self-hashed foreign handle rejected")
	check(not p.observer.check(built.prepared,"wrong head").success,"Stale expected head rejected")
	for mutation: String in ["source","request","owner","head","bytes","facts","reorder","movement","canceled"]:
		var w := Witness.new(); w.value = p.witness.read()
		var a := X.new(p,w.read); a.observe(p.host.get_ref())
		var prepared := a.prepare(a.head())
		check(prepared.success,"Independent real prepared probe "+mutation)
		if not prepared.success: continue
		var original_source := p.source; var original_request := p._prepared.duplicate(true)
		var model: PrimeMovementModel = p.host.get_ref().player_movement_boundary_provider.get_object()
		var movement_before := model.wave_entry_state()
		match mutation:
			"source": p.source = p.source.duplicate(true); p.source.attributes.wis += 1
			"request": p._prepared.document += " "
			"owner": w.value.owner += "changed"
			"head": w.value.head_text += " "
			"bytes": w.value.text += " "
			"facts": a._s2._facts[0].event_type = "forged"
			"reorder": a._s2._facts.reverse()
			"movement": model.request_running(); model.advance(100000,Vector2.RIGHT)
			"canceled": a.cancel()
		check(not a.check(prepared.prepared,a.head()).success,"Changed "+mutation+" invalidates sealed operation")
		p.source = original_source; p._prepared = original_request
		if mutation == "movement": check(model.restore_wave_entry(movement_before),"Only disposable movement fixture restored after invalidation probe")
		check(not a.check(prepared.prepared,a.head()).success,"Invalidated context cannot resurrect after restoring inputs")
	var candidate: Dictionary = CharacterSaveContract._normalize_json_numbers(JSON.parse_string(JSON.parse_string(b.text.split("\n")[1]).payload_json))
	for mutation: String in ["duplicate","missing","binding"]:
		var r := candidate.duplicate(true)
		if mutation == "duplicate": r.applied_ids.append(r.applied_ids[0].duplicate(true))
		elif mutation == "missing": r.applied_ids.remove_at(0)
		else: r.applied_ids[0].record_digest = "0".repeat(64)
		check(not p.observer._delta(r).success and not V6.validate(r,p.source).success,"Exact ID map and original full oracle reject "+mutation)
	for field: String in ["awards","purchases","settlements"]:
		if candidate.evidence[field].is_empty(): continue
		var bad := candidate.duplicate(true); bad.evidence[field].append(bad.evidence[field][0].duplicate(true))
		check(not V6.validate(bad,p.source).success,"Reused semantic "+field+" cannot become a new transaction")
	var replica_witness := Witness.new(); replica_witness.value = p.witness.read(); replica_witness.value.replica = "damaged"
	var intact := X.new(p,replica_witness.read)
	check(intact._failure.is_empty(),"Damaged replica does not invalidate intact cold current")
	intact.observe(p.host.get_ref())
	var replacement := intact.prepare(intact.head())
	check(replacement.success and replacement.prepared.copy().replica == replacement.prepared.copy().text,"Next genuine candidate carries a matching replacement replica")
	replica_witness.value.replica = ""
	check(X.new(p,replica_witness.read)._failure.is_empty(),"Missing replica does not relabel intact current as corrupt")
	var conflict := Witness.new(); conflict.value = p.witness.read(); conflict.value.other_head = "conflict"
	check(not X.new(p,conflict.read)._failure.is_empty(),"Conflicting head authority fails closed")
	var damaged := Witness.new(); damaged.value = p.witness.read(); damaged.value.text = "damaged"
	check(not X.new(p,damaged.read)._failure.is_empty(),"Damaged current needs explicit exact recovery before incremental admission")

func stale_competing() -> void:
	var path := root.path_join("competing")
	var first := start(path)
	if not first.get("success",false): check(false,"First competing admission"); return
	Historical.new().helper._defeat_wave(first.session); first.session.collect_all_ground_loot()
	var p: Observed = first.service
	var parent: Dictionary = p.observer.current_copy()
	var second := start(path,"normal",null,parent)
	if not second.get("success",false): check(false,"Second competing admission"); return
	var peer := {}
	p.before_commit = func(): peer["result"] = second.session.request_character_development("preferences",{"order":["nac","block","soak","dodge"]},"45x_peer")
	var loser: Dictionary = first.session.request_character_development("preferences",{"order":["nac","dodge","block","soak"]},"45x_loser")
	check(peer.get("result",{}).get("persistence",{}).get("success",false) and not loser.get("persistence",{}).get("success",true),"Existing coordinator admits only one real competing request")
	check(p.observer.current_copy() == parent and not p.observer.adopt(p.last_prepared).success,"Stale losing operation cannot adopt/overwrite acknowledged winner")
	var persisted := CharacterSaveStorage.history_records(p.storage.inspect_profile(p.profile_id))
	check(CharacterSaveContract.decode(persisted.back().document).payload == CharacterSaveContract.decode(second.service._prepared.document).payload,"Exact winner readback, no duplicate progression")

func complex_gameplay() -> void:
	var helper := Gameplay.new(); helper.make = factory
	var result := helper.complex(root.path_join("complex"))
	check(result.get("success",false) and helper.failures.is_empty(),"Real all-five purchases, interleaved END/HPB/WIS, items/consumption/equipment/shield and unobserved control: "+str(helper.failures))
	metrics.append({"fixture":"complex_reference_assertions","assertions":helper.assertions,"failures":helper.failures})
	for p: Observed in services:
		if p._prior.get("purchases",[]).size() >= 6 and not p.samples.is_empty():
			check(p.errors.is_empty(),"All-five transaction checks: "+str(p.errors))
			metrics.append({"fixture":"all_five_historical_credit","samples":p.samples})

func native_credit() -> void:
	var h := Historical.new(); h.root = root.path_join("credit_history")
	var original := h.make_history("dev_normal",Credit.BASELINE,2,"uncredited")
	check(original.get("success",false),"Actual eligible historical uncredited character")
	if not original.get("success",false): return
	var converted := Convert.convert(original.records,"dev_normal")
	check(converted.success,"Full source-backed uncredited conversion")
	if not converted.success: return
	var f := start(original.storage._root,"dev_normal",null,converted.record)
	if not f.get("success",false): check(false,"Credit resume"); return
	var p: Observed = f.service; var a: RefCounted = p.observer
	check(not a.prepare_credit(f.session,a.head()).success,"No fixed grant without explicit consent")
	var before: Dictionary = f.session.get_state_snapshot()
	var offered: Dictionary = a.prepare_credit(f.session,a.head(),func(q): return {"confirmed":true,"binding":V6.digest(q)})
	check(offered.success and f.session.get_state_snapshot() == before,"Existing S3 confirmation produces pure fixed-credit candidate")
	if not offered.success: return
	var bytes: Dictionary = offered.prepared.copy()
	var t := Time.get_ticks_usec()
	var verified := Package.cold_verify(bytes.head_text,bytes.text,p.source,p.profile_id,p.mode)
	var cold_ms := float(Time.get_ticks_usec()-t)/1000.0
	var repaired := Package.recover(bytes.head_text,"damaged",bytes.replica,p.source,p.profile_id,p.mode)
	check(verified.success and repaired.success and repaired.text == bytes.text,"Independent cold verification and exact replica recovery of native fixed credit")
	metrics.append({"fixture":"native_fixed_credit_operation","samples":[offered.metrics.merged({"cold_ms":cold_ms,"repair_ms":repaired.get("recovery_ms")})]})
	var retry: Dictionary = a.prepare_credit(f.session,a.head())
	check(retry.success and retry.prepared == offered.prepared,"Confirmed grant exact retry needs no second approval")
	var request: Dictionary = a._s2.publication_request(a._s2_pending)
	check(request.success,"Original confirmed coordinator permit is available")
	if not request.success: return
	p._prepared = request.proposal; p._last_ack = false
	var ack := CharacterPersistenceCoordinator.new(p.storage).commit(request.proposal,p.source,p.profile_id,PlayableCharacterAdmission.RULES,request.verifier)
	check(ack.success and p._ack(ack).success,"Only original coordinator publishes disposable credit")
	if not ack.success: return
	p.witness.remember(offered.prepared.copy())
	check(a.prepare(a.head()).get("already_applied",false) and a.adopt(offered.prepared).success,"Uncertain credit acknowledgement reconciles exact package, no second grant")
	var grant := Grant.new(); grant._session = f.session; grant._service = p; grant._prepared = request.proposal; grant._runtime = grant._runtime_digest()
	check(grant._published(ack).success,"Existing explicit credit runtime bookkeeping, no new wallet")
	check(a.current_copy().accounting.credit_expc == 10000 and a.current_copy().accounting.expm_total == converted.record.accounting.expm_total,"EXPC-only +10000, earned EXPM unchanged")
	check(a.prepare_credit(f.session,a.head()).get("no_op",false),"Fixed lifetime credit cannot repeat")
	for i in range(21): check(f.session.request_character_development("preferences",{"order":["nac","block","dodge","soak"]},"45x_credit_after_%d" % i).get("persistence",{}).get("success",false),"Actual operation after native credit")
	check(not a.current_copy().recent_journal.any(func(row): return row.id == a.Credit.transaction_id()) and a.prepare_credit(f.session,a.head()).get("no_op",false),"Native credit remains exactly once after eviction from recent journal")
	verify(f,"native_credit")

func high_inventory() -> void:
	var f := start(root.path_join("inventory"),"dev_normal",10)
	if not f.get("success",false): check(false,"Inventory fixture admission"); return
	var p: Observed = f.service
	var operations := inventory_commands(f)
	check(operations.collected.get("persistence",{}).get("success",false),"1000 source-backed owned item origins, actual collection checkpoint")
	check(p.observer.current_copy().applied_ids.size() >= 1000 and p.observer.current_copy().current.items.size() >= 1000,"Exact full lifetime map and high inventory")
	check(operations.next.get("persistence",{}).get("success",false),"Subsequent legitimate high-inventory checkpoint")
	verify(f,"inventory1000")
	var control := Q.new().start(CharacterSaveStorage.new(root.path_join("inventory_control")),"dev_normal",10,{},false)
	check(control.get("success",false),"Independent unobserved large-inventory admission")
	if control.get("success",false):
		var expected := inventory_commands(control)
		check(expected.collected.success and expected.next.success and f.session.get_state_snapshot() == control.session.get_state_snapshot(),"High-inventory unobserved legacy RNG/events/current state converge")
		check(p._prior == control.service._prior,"High-inventory complete legacy proof, generation and ownership equal")

func inventory_commands(f: Dictionary) -> Dictionary:
	var s: ArenaCombatSession = f.session
	Historical.new().helper._defeat_wave(s); s.collect_all_ground_loot()
	var origin := s.simulation.record_reward_event(&"reward_source_item_fixture",&"player",&"player",{})
	for i in range(1000):
		s.simulation.create_ground_loot_item("45x_currency_%d" % i,{"definition_id":"prime_v3_gold","quantity":1,"display_name":"Gold","item_kind":"currency","source_ref":"PRIME-V3 currency; disposable source-origin fixture"},s.get_actor_state(&"player").position_microfeet,&"player",origin.event_id)
	return {"collected":s.collect_all_ground_loot(),"next":s.request_character_development("preferences",{"order":["nac","block","dodge","soak"]},"45x_inventory_next")}

func long_history() -> void:
	var archive := OS.get_environment("ARENA45X_LEGACY_BUNDLE").replace("\\","/").simplify_path()
	var allowed := OS.get_cache_dir().replace("\\","/").path_join("itank-storage-tests/compact45s_")
	if not archive.begins_with(allowed) or not archive.get_file().begins_with("restoration_") or not archive.ends_with(".bundle"): check(false,"Explicit frozen archive must be isolated"); return
	var outer: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(archive))
	check(outer.sha256 == outer.body_json.sha256_text(),"Frozen original archive checksum")
	var rows: Array = CharacterSaveContract._normalize_json_numbers(JSON.parse_string(outer.body_json))
	var converted := Convert.convert(rows,"dev_normal")
	check(converted.success and converted.generation_count == 233 and converted.comparison.success,"Full frozen 233-generation validation and independent character equivalence")
	if not converted.success: return
	var original_package := Package.build(converted.text,PlayableCharacterAdmission.prepare_starter(&"vaelis_thorn","dev_normal",Credit.BASELINE).source,Credit.PROFILE,"dev_normal")
	check(original_package.success and original_package.text.sha256_text() == "c8e6f1494e61ecdd04f859daf43e296076f1c3121b4496a835b6bc489851b670","Existing W canonical package bytes unchanged by timing-only instrumentation")
	var guard := CharacterSaveStorage.new(root.path_join("long")); var lease := guard.acquire_writer(Credit.PROFILE)
	check(lease.success,"Original writer ownership for disposable fixture installation")
	if not lease.success: return
	var restored := guard.restore_history(Credit.PROFILE,rows,[],lease.owner); guard.release_writer(Credit.PROFILE,lease.owner)
	check(restored.success,"Exact original archive restored only into new disposable legacy oracle")
	if not restored.success: return
	var f := start(guard._root,"dev_normal",null,converted.record)
	check(f.get("success",false),"Cold converted 233-character gameplay admission")
	if not f.get("success",false): return
	for i in range(2): check(f.session.request_character_development("preferences",{"order":["nac","block","dodge","soak"]},"45x_long_%d" % i).get("persistence",{}).get("success",false),"Real consecutive checkpoint after 233 original generations")
	verify(f,"original233")
