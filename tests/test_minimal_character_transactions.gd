extends RefCounted
const Codec = preload("res://scripts/rewards/minimal_character_snapshot.gd")
const V6 = preload("res://scripts/rewards/compact_character_v6_prototype.gd")
const Q = preload("res://tests/test_compact_v6_gameplay_candidate.gd")
const Fixtures = preload("res://tests/test_minimal_character_snapshot.gd")
const Playable = preload("res://tests/test_playable_vaelis_persistence.gd")
var failures: Array[String] = []
var assertions := 0
var root := ""

func difference(a: Variant, b: Variant, path: String = "") -> String:
	if a is Dictionary and b is Dictionary:
		for key: Variant in a:
			if not b.has(key): return path+"/missing "+str(key)
			var d := difference(a[key],b[key],path+"/"+str(key))
			if not d.is_empty(): return d
		for key: Variant in b:
			if not a.has(key): return path+"/extra "+str(key)
		return ""
	if a is Array and b is Array:
		if a.size()!=b.size(): return path+"/size %s != %s" % [a.size(),b.size()]
		for i in range(a.size()):
			var d := difference(a[i],b[i],path+"/"+str(i))
			if not d.is_empty(): return d
		return ""
	return "" if a==b else path+" %s != %s" % [str(a).left(120),str(b).left(120)]

func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok: failures.append(label)

func run() -> Array[String]:
	var prior: Array = [PlayableCharacterPersistence.test_storage,PlayableCharacterPersistence.test_run_id,PlayableCharacterPersistence.test_nonpersistent]
	PlayableCharacterPersistence.test_nonpersistent = false
	root = OS.get_cache_dir().path_join("itank-storage-tests/minimal46c2_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()])
	for mode: String in ["normal","dev_normal"]: scenario(mode)
	PlayableCharacterPersistence.test_storage=prior[0]; PlayableCharacterPersistence.test_run_id=prior[1]; PlayableCharacterPersistence.test_nonpersistent=prior[2]
	print("46C2 transactions: %d assertions; failures %s" % [assertions,str(failures)])
	return failures

func scenario(mode: String) -> void:
	var q := Q.new()
	var f := q.start(CharacterSaveStorage.new(root.path_join("original_"+mode)),mode,1 if mode=="normal" else 10)
	check(f.success,"Original source fixture "+mode)
	if not f.success: return
	var b: Dictionary = Fixtures.new().make(f.service.records[0],f.service.source)
	var encoded := Codec.encode(b,f.service.source,f.service.profile_id,mode)
	check(encoded.success,"Independent cold initial fixture")
	var c := CharacterPersistenceCoordinator.new(null)
	var admitted := c.admit_minimal_snapshot(encoded.text,f.service.source,f.service.profile_id,mode,root.path_join("owned_"+mode))
	check(admitted.success,"Coordinator cold admission: "+str(admitted))
	if not admitted.success: return
	var initial := c.minimal_view()
	initial.metrics["forged"] = true
	initial.body_json = "forged"
	check(c.minimal_view().body_json != "forged" and not c.minimal_view().metrics.has("forged"),"No mutable aggregate state escapes public view")
	check(not c.admit_minimal_snapshot(encoded.text,f.service.source,f.service.profile_id,mode,root.path_join("second")).success,"Coordinator owns at most one admitted aggregate")
	var a: RefCounted = c._minimal_owner # Test-only inspection, never a returned API reference.
	var s: ArenaCombatSession = a._session
	check(c.minimal_view().durable == false and not a._service.status().persistent,"Prototype never claims real persistence")
	check(c.simulate_minimal_automatic_checkpoints(true).success,"Explicit test-only automatic simulated readback")
	var helper := Playable.new()
	helper._defeat_wave(s)
	check(helper._failures.is_empty(),"Original combat commands settle genuine rewards")
	check(s.collect_all_ground_loot().success,"Original source item/currency acquisition")
	check(c.minimal_view().pending_operation.is_empty(),"One simulated adopted checkpoint at a time")
	var current: Dictionary = JSON.parse_string(c.minimal_view().body_json)
	var cold := Codec.validate(current,f.service.source,f.service.profile_id,mode)
	check(cold.success,"Independent full cold validator accepts new genuine effects: "+str(cold))
	var downtime := Codec.encode(current,f.service.source,f.service.profile_id,mode)
	check(s.request_next_wave().success,"Original NEXT WAVE policy continues after explicit simulation")
	current = JSON.parse_string(c.minimal_view().body_json)
	var sample_started := Time.get_ticks_usec()
	cold = Codec.validate(current,f.service.source,f.service.profile_id,mode)
	var cold_sample_us := Time.get_ticks_usec()-sample_started
	check(cold.success,"Consecutive Wave entry independently cold-validates: "+str(cold))
	var portable := Codec.encode(current,f.service.source,f.service.profile_id,mode)
	var cold_root := OS.get_cache_dir().path_join("itank-storage-tests/minimal46b_46c2_%s_%d_%d" % [mode,OS.get_process_id(),Time.get_ticks_usec()])
	DirAccess.make_dir_recursive_absolute(cold_root)
	var file := FileAccess.open(cold_root.path_join("cold.json"),FileAccess.WRITE)
	file.store_string(portable.text); file.close()
	var output: Array = []
	var code := OS.execute(OS.get_executable_path(),["--headless","--path",ProjectSettings.globalize_path("res://"),"--script","res://tests/minimal_snapshot_cold_process.gd","--",cold_root,f.service.profile_id,mode,current.current.lineage.baseline_digest,portable.text.sha256_text()],output,true)
	check(code==0 and str(output).contains("46B_COLD_PROCESS_PASS"),"Fresh process full cold admission of actual prepared record: "+str(output))
	check(not c.prepare_minimal_snapshot({"verified":true},0).success,"Arbitrary candidate/verified dictionary cannot authorize preparation")
	# Same cold-admitted source, original unobserved legacy writer control.
	var control := q.start(CharacterSaveStorage.new(root.path_join("original_"+mode)),mode,null,{},false)
	check(control.success,"Independent original cold-resume control")
	if control.success:
		var other := Playable.new(); other._defeat_wave(control.session)
		check(other._failures.is_empty() and control.session.collect_all_ground_loot().success and control.session.request_next_wave().success,"Independent original source commands")
		check(s.get_state_snapshot() == control.session.get_state_snapshot(),"Complete original simulation, events and RNG equivalence")
		var actual: Dictionary = Codec.validate(current,f.service.source,f.service.profile_id,mode).snapshot.projection()
		var expected: Dictionary = CharacterSaveContract._normalize_json_numbers(JSON.parse_string(JSON.stringify(control.service._prior,"",true,true)))
		check(actual == expected,"Complete original character evidence/projection equivalence: "+difference(actual,expected))
	print("46C2_METRICS "+JSON.stringify({"mode":mode,"metrics":c.minimal_view().metrics,"independent_validation_sample_us":cold_sample_us,"admission_cold_us":c.minimal_view().admission_cold_us}))
	check(q.failures.is_empty(),"Original independent fixture assertions")
	c.close_minimal_prototype()
	if mode == "dev_normal":
		pending_cases(downtime.text,f.service.source,f.service.profile_id,mode)
		command_identity_stop(mode)

func pending_cases(text: String, source: CombatCharacterDefinitionResource, profile: String, mode: String) -> void:
	var c := CharacterPersistenceCoordinator.new(null)
	check(c.admit_minimal_snapshot(text,source,profile,mode,root.path_join("pending")).success,"Cold readmission of new complete record")
	var a: RefCounted = c._minimal_owner
	var s: ArenaCombatSession = a._session
	s.configure_player_nac_automation({"profile":"Aggressive"})
	var attempt: Dictionary = a._service.checkpoint(s,"downtime")
	check(attempt.get("state") == "prepared_not_saved","Prepared operation is explicitly nondurable")
	var v := c.minimal_view()
	var request := c.prepare_minimal_snapshot(v.pending_operation,v.revision)
	check(request.success and request.current_runtime,"Current capture prepares immutable bytes")
	check(Codec.decode(request.text,source,profile,mode).success,"Actual candidate envelope independently decodes, including signed sentinels")
	check(c.prepare_minimal_snapshot(v.pending_operation,v.revision).text == request.text,"Exact retry returns identical bytes")
	check(not c.prepare_minimal_snapshot(v.pending_operation,v.revision+1).success,"Reject stale admitted revision")
	check(not c.simulate_minimal_acknowledgement(request.text+" ").success,"Reject altered simulated readback")
	var retried: Dictionary = a._service.checkpoint(s,"downtime")
	check(retried.get("exact_retry",false) and c.minimal_view().pending_text == request.text,"Exact source checkpoint retry preserves operation and candidate")
	check(c.simulate_minimal_unknown_outcome().success,"Simulate uncertain publication only while original authorization is fresh")
	a._player._movement.request_running(); a._player._movement.advance(100000,Vector2.ZERO)
	check(not c.prepare_minimal_snapshot(v.pending_operation,v.revision).current_runtime,"External Running/fatigue change makes current-state claim stale")
	check(not c.cancel_minimal_snapshot().success,"Unknown publication cannot be canceled into an uncommitted state")
	check(c.simulate_minimal_acknowledgement(request.text).success,"Exact unknown-outcome readback reconciles original earlier checkpoint")
	var adopted := c.minimal_view()
	check(c.simulate_minimal_acknowledgement(request.text).success and c.minimal_view().revision == adopted.revision,"Repeated simulated readback never reapplies effects")
	check(not a._service.status().persistent,"Simulated adoption never claims actual save")
	check(c.simulate_minimal_automatic_checkpoints(true).success,"Enable explicit simulation for bounded journal test")
	for i in range(23):
		s.configure_player_nac_automation({"profile":"Defensive" if i%2==0 else "Guardian"})
		check(a._service.checkpoint(s,"downtime").success,"Genuine later checkpoint "+str(i))
	var b: Dictionary = CharacterSaveContract._normalize_json_numbers(JSON.parse_string(c.minimal_view().body_json))
	check(b.recent_journal.size()==20 and b.operations.size()>20,"Journal evicts only recent entries")
	check(b.lifetime_ids.any(func(row: Dictionary): return row.scope=="operation" and row.id==v.pending_operation),"Lifetime operation survives journal eviction")
	check(Codec.validate(b,source,profile,mode).success,"Independent full cold proof after repeated checkpoints")
	c.simulate_minimal_automatic_checkpoints(false)
	s.configure_player_nac_automation({"profile":"Balanced"})
	a._service.checkpoint(s,"downtime")
	v = c.minimal_view(); request = c.prepare_minimal_snapshot(v.pending_operation,v.revision)
	s.configure_player_nac_automation({"profile":"Aggressive"})
	check(not a._service.checkpoint(s,"downtime").success and c.minimal_view().pending_text==request.text,"Changed request/checkpoint rejected without substituting candidate")
	check(not c.simulate_minimal_acknowledgement(request.text).success,"Stale capture with no prior publication attempt fails closed")
	var old_body: String = c.minimal_view().body_json
	check(c.cancel_minimal_snapshot().success and c.minimal_view().body_json==old_body,"Cancellation adopts no uncommitted character change")
	check(not c.prepare_minimal_snapshot(v.pending_operation,v.revision).success,"Cancellation terminally invalidates context")
	c.close_minimal_prototype()

func command_identity_stop(mode: String) -> void:
	var q := Q.new()
	var f := q.start(CharacterSaveStorage.new(root.path_join("command_control")),mode,10)
	check(f.success,"Original source fixture for command identity audit")
	if not f.success: return
	var h := Playable.new(); h._defeat_wave(f.session)
	check(h._failures.is_empty() and f.session.collect_all_ground_loot().success,"Original acquired/owned items before command")
	var before: Dictionary = f.service.records.back()
	var id := "original_equipment_request_for_cold_replay"
	var changed: Dictionary = f.session.request_player_inventory_unequip(&"prime_v3_short_wand",id)
	check(changed.success and changed.get("persistence",{}).get("success",false),"Genuine original equipment request commits in original control")
	var event: CombatEvent
	for live: CombatEvent in f.session.get_resolved_events():
		if live.event_type==&"downtime_equipment_changed" and live.payload.get("request_id")==id: event=live
	check(event!=null,"Original runtime event retains exact request ID and ownership binding")
	var body: Dictionary = Fixtures.new().make(f.service.records.back(),f.service.source)
	var encoded := Codec.encode(body,f.service.source,f.service.profile_id,mode)
	check(encoded.success,"Current v1 can verify terminal equipment state")
	check(not body.lifetime_ids.any(func(row: Dictionary): return row.id==id),"Characterization: commit IDs/origins are not individual equipment request IDs")
	var extended: Dictionary = body.duplicate(true)
	extended.lifetime_ids.append({"scope":"equipment","id":id,"record_digest":V6.digest(event.payload)})
	check(not Codec.validate(extended,f.service.source,f.service.profile_id,mode).success,"Unapproved new lifetime scope is correctly rejected by unchanged v1")
	var original := Codec.encode(Fixtures.new().make(before,f.service.source),f.service.source,f.service.profile_id,mode)
	var c := CharacterPersistenceCoordinator.new(null)
	check(c.admit_minimal_snapshot(original.text,f.service.source,f.service.profile_id,mode,root.path_join("command_blocked")).success,"Cold owner admits original pre-command state")
	var a: RefCounted = c._minimal_owner
	var old: String = c.minimal_view().body_json
	changed = a._session.request_player_inventory_unequip(&"prime_v3_short_wand",id)
	check(not changed.success and changed.get("reason")=="minimal_v1_command_identity_evidence_unavailable","Reject unsupported command before gameplay effects or candidate preparation")
	check(c.minimal_view().pending_text.is_empty() and c.minimal_view().body_json==old,"Unsupported command does not replace admitted record or create pending save")
	c.close_minimal_prototype()
