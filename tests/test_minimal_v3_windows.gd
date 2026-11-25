extends RefCounted
const H = preload("res://tests/test_minimal_v3_transactions.gd")
const Q = H.Q
const G = H.G
const P = H.P
const Hist = H.H
const Store = preload("res://scripts/rewards/minimal_v3_windows_storage.gd")
const V3 = Store.V3
const Credit = V3.Credit
var failures: Array[String] = []
var assertions := 0
var oracle_assertions := 0
var measures: Array = []
var prefix := ""
var root := ""
var executable := ""
var executable_hash := ""

func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok: failures.append(label)

func directory(label: String) -> String:
	return OS.get_cache_dir().path_join("itank-storage-tests/minimal46i1_46i_%s_%s" % [prefix,label])

func write(path: String, text: String) -> void:
	var f := FileAccess.open(path,FileAccess.WRITE); f.store_string(text); f.close()

func approve(value: Dictionary) -> Dictionary:
	return {"confirmed":true,"binding":V3.V6.digest(value)}

func publish(c: CharacterPersistenceCoordinator, label: String) -> Dictionary:
	var before: Dictionary = c._minimal_owner._session.get_state_snapshot()
	var movement: Dictionary = c._minimal_owner._player.capture_wave_entry_motion()
	var result := c.publish_minimal_windows()
	check(result.success and result.get("durable",false) and result.state == "disposable_windows_verified","Actual Windows acknowledgement "+label+": "+str(result.get("reason","")))
	check(before == c._minimal_owner._session.get_state_snapshot() and movement == c._minimal_owner._player.capture_wave_entry_motion(),"Publication changes no gameplay/RNG/Running: "+label)
	if result.success:
		var route: RefCounted = c._minimal_owner._windows_route
		var loaded: Dictionary = route.load_current()
		check(loaded.success and not loaded.repair_current and not loaded.repair_replica,"Exact selected pair readback "+label)
		check(route._data_names().size() == 2 and not result.maintenance_required,"Only latest character and replica retained "+label)
		var measured: Dictionary = c._minimal_owner._windows_last_result
		if measured.head_text != result.head_text: measured = result
		measures.append({"fixture":label,"prepare":c.minimal_view().metrics,"acknowledged_save_us":measured.acknowledged_save_us,"capture_to_ack_us":measured.capture_to_ack_us,"publication_us":measured.storage_metrics.publication_us,"native_us":measured.storage_metrics.native_us,"readback_us":loaded.cold_readback_us,"native_live":OS.get_static_memory_usage(),"native_peak":OS.get_static_memory_peak_usage()})
	return result

func admitted(record: Dictionary, source: CombatCharacterDefinitionResource, label: String) -> CharacterPersistenceCoordinator:
	var helper := H.new(); helper.root = root
	var c: CharacterPersistenceCoordinator = helper.admit(record,source,label)
	check(helper.failures.is_empty(),"Independent source v3 admission "+label+str(helper.failures)); oracle_assertions += helper.assertions
	if c._minimal_owner != null:
		check(c.attach_minimal_windows(directory(label),executable,executable_hash).success,"Attach explicit disposable transport "+label)
		publish(c,label+"_first")
	return c

func run() -> Array[String]:
	prefix = "%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	root = OS.get_cache_dir().path_join("itank-storage-tests/minimal46c2_46i_"+prefix)
	DirAccess.make_dir_recursive_absolute(root)
	executable = OS.get_environment("TEMP").path_join("arena46i1_native/safe_head_replace.exe")
	executable_hash = OS.get_environment("ARENA_46I_HELPER_SHA")
	check(V3.V6._hash(executable_hash) and FileAccess.get_sha256(executable) == executable_hash,"Explicit source-built helper identity")
	if not failures.is_empty(): return failures
	var previous := [PlayableCharacterPersistence.test_nonpersistent,PlayableCharacterPersistence.test_storage,PlayableCharacterPersistence.test_run_id]
	PlayableCharacterPersistence.test_nonpersistent = false
	var section := OS.get_environment("ARENA_46I_SECTION")
	if section.is_empty():
		for scope: String in ["normal","dev_normal"]: scenario(scope)
	if section in ["","history"]: historical()
	if section in ["","stress"]: stress()
	PlayableCharacterPersistence.test_nonpersistent = previous[0]; PlayableCharacterPersistence.test_storage = previous[1]; PlayableCharacterPersistence.test_run_id = previous[2]
	print("46I_METRICS "+JSON.stringify(measures))
	print("46I Windows: %d assertions + %d original oracle assertions; failures %s" % [assertions,oracle_assertions,str(failures)])
	return failures

func scenario(scope: String) -> void:
	var q := Q.new()
	var original := q.start(CharacterSaveStorage.new(root.path_join("control_"+scope)),scope,1 if scope == "normal" else 10)
	check(original.success,"Genuine first wave "+scope)
	if not original.success: return
	var c := admitted(original.service.records.back(),original.service.source,scope)
	if c._minimal_owner == null: return
	var owner: RefCounted = c._minimal_owner; var s: ArenaCombatSession = owner._session
	check(c.automatic_minimal_windows(true).success,"Opt-in real checkpoint publication at original source boundaries")
	var helper := H.new(); helper.root = root
	var control := q.start(original.service.storage,scope,null,original.service.records.back(),true)
	check(control.success,"Original independent verified reload "+scope)
	if not control.success: c.close_minimal_prototype(); return
	var p := P.new(); var pc := P.new()
	p._defeat_wave(s); pc._defeat_wave(control.session)
	publish(c,scope+"_awards_growth")
	check(s.collect_all_ground_loot().success and control.session.collect_all_ground_loot().success,"Genuine loot/item ownership")
	publish(c,scope+"_loot")
	helper.compare(c,control,scope+"_original_equivalence")
	check(helper.failures.is_empty(),"Original state/event/evidence/RNG equivalence "+str(helper.failures))
	oracle_assertions += helper.assertions; helper.assertions = 0
	# Actual potion acquisition/use, terminal quantity zero and equipment.
	for sim_session: ArenaCombatSession in [s,control.session]:
		var cause := sim_session.simulation.record_reward_event(&"reward_source_fixture",&"player",&"player",{})
		sim_session.simulation.create_ground_loot_item("46i_potion",{"definition_id":"health_potion","quantity":1,"display_name":"Health Potion","item_kind":"potion","source_ref":"Prime V3 p.120; disposable fixture"},sim_session.get_actor_state(&"player").position_microfeet,&"player",cause.event_id)
		check(sim_session.collect_all_ground_loot().success,"Actual acquisition")
	publish(c,scope+"_acquisition")
	check(helper.item(c,"unequip","prime_v3_short_wand","","46i_off").success and control.session.request_player_inventory_unequip(&"prime_v3_short_wand","46i_off").success,"Original unequip")
	publish(c,scope+"_unequip")
	check(helper.item(c,"equip","prime_v3_short_wand","","46i_on").success and control.session.request_player_inventory_equip(&"prime_v3_short_wand","46i_on").success,"Original equip")
	publish(c,scope+"_equip")
	check(helper.item(c,"handling","prime_v3_short_wand","stow","46i_stow").success and control.session.request_player_weapon_handling(&"prime_v3_short_wand","stow","46i_stow").success,"Original stow frees the legal potion hand")
	publish(c,scope+"_stow")
	# Match original resource damage before using the same genuine command.
	for session: ArenaCombatSession in [s,control.session]: session.get_actor_state(&"player").current_hpc = 1
	check(helper.item(c,"use","health_potion","","46i_use").success and control.session.request_player_inventory_consumable_use(&"health_potion","46i_use").success,"Original once-only potion")
	publish(c,scope+"_consumption")
	check(s.request_next_wave().success and control.session.request_next_wave().success,"Original secured NEXT WAVE")
	publish(c,scope+"_next_wave")
	s.set_opponent_behavior_enabled(false); control.session.set_opponent_behavior_enabled(false)
	var drawing := helper.item(c,"handling","prime_v3_short_wand","draw","46i_draw")
	var control_draw: Dictionary = control.session.request_player_weapon_handling(&"prime_v3_short_wand","draw","46i_draw")
	check(drawing.success and control_draw.success,"Original timed draw starts under actual issued request")
	if drawing.success and control_draw.success:
		s.simulation.schedule_interruption(drawing.result.action_instance_id,s.simulation.clock.get_elapsed_us(),&"player","fixture_interrupt")
		control.session.simulation.schedule_interruption(control_draw.action_instance_id,control.session.simulation.clock.get_elapsed_us(),&"player","fixture_interrupt")
		s.advance_by(1); control.session.advance_by(1)
	p._defeat_wave(s); pc._defeat_wave(control.session)
	publish(c,scope+"_interrupted_handling")
	helper.compare(c,control,scope+"_items_equivalence")
	check(helper.failures.is_empty(),"Complete source control remains exact "+str(helper.failures)); oracle_assertions += helper.assertions; helper.assertions = 0
	var route: RefCounted = owner._windows_route
	var loaded: Dictionary = route.load_current()
	check(loaded.snapshot.copy().current.items.any(func(i): return i.quantity == 0),"Terminal zero ownership saved")
	recovery(route,loaded)
	if scope == "normal": failures_and_crashes(c,loaded)
	loaded = route.load_current()
	var cold := CharacterPersistenceCoordinator.new(null)
	check(cold.admit_minimal_snapshot_v3(loaded.text,route.source,route.profile,scope,root.path_join("cold_"+scope)).success,"Cold original v3 admission from Windows")
	if cold._minimal_owner != null:
		check(cold.attach_minimal_windows(route.root,executable,executable_hash).success,"Cold binding to exact stored head")
		var issued := cold.issue_temporary_request(cold.temporary_context(),"use","health_potion","","46i_use")
		var before: Dictionary = cold._minimal_owner._session.get_state_snapshot()
		check(issued.success and cold.execute_temporary_request(issued.request).get("reason") == "reused_irreversible_consumption" and before == cold._minimal_owner._session.get_state_snapshot(),"Cold consumed ID rejects before effects/RNG")
		cold.close_minimal_prototype()
	check(q.failures.is_empty() and p._failures.is_empty() and pc._failures.is_empty(),"Original independent fixture assertions")
	c.close_minimal_prototype()

func recovery(route: RefCounted, loaded: Dictionary) -> void:
	var current: String = route.root.path_join("current_"+loaded.head.record_sha256+".json")
	var replica: String = route.root.path_join("replica_"+loaded.head.record_sha256+".json")
	write(current,"damaged")
	var r: Dictionary = route.recover()
	check(r.success and FileAccess.get_file_as_string(current) == loaded.text and FileAccess.get_file_as_string(replica) == loaded.text,"Repair exact current from latest replica")
	if r.success: measures.append({"fixture":"repair_current_"+str(loaded.head.record_bytes),"recovery_us":r.recovery_us,"native_live":OS.get_static_memory_usage(),"native_peak":OS.get_static_memory_peak_usage()})
	write(replica,"damaged")
	r = route.recover()
	check(r.success and FileAccess.get_file_as_string(replica) == loaded.text,"Repair exact replica from intact current")
	if r.success: measures.append({"fixture":"repair_replica_"+str(loaded.head.record_bytes),"recovery_us":r.recovery_us})
	write(current,"damaged"); write(replica,"damaged")
	check(not route.load_current().success and not route.recover().success,"Both damaged never fall back")
	write(current,loaded.text); write(replica,loaded.text)
	DirAccess.remove_absolute(route.root.path_join("head.bin"))
	check(not route.load_current().success,"Missing head does not select any complete record")
	write(route.root.path_join("head.bin"),loaded.head_text)
	for field: String in ["sequence","reader_version","profile"]:
		var head: Dictionary = loaded.head.duplicate(true)
		head[field] = head[field]+1 if field != "profile" else "wrong_profile"
		var body := JSON.stringify(head,"",true,true)
		write(route.root.path_join("head.bin"),JSON.stringify({"body":body,"sha256":body.sha256_text()},"",true,true))
		check(not route.load_current().success,"Conflicting/unsupported acknowledged head "+field)
	write(route.root.path_join("head.bin"),loaded.head_text)
	check(route.load_current().success,"Restore only disposable injected corruption")
	DirAccess.remove_absolute(route.root.path_join("head.bin")); DirAccess.remove_absolute(current); DirAccess.remove_absolute(replica)
	check(not route.load_current().success,"All selected authority missing in a used directory never becomes a virgin character")
	write(current,loaded.text); write(replica,loaded.text); write(route.root.path_join("head.bin"),loaded.head_text)

func child_args(mode: String, route: RefCounted, at: String, output: String) -> Array:
	var baseline: String = route.load_current().snapshot.copy().current.lineage.baseline_digest
	return ["--headless","--path",ProjectSettings.globalize_path("res://"),"--script","res://tests/minimal_v3_windows_process.gd","--",mode,route.root,route.scope,baseline,executable,executable_hash,at,output]

func failures_and_crashes(c: CharacterPersistenceCoordinator, initial: Dictionary) -> void:
	var owner: RefCounted = c._minimal_owner; var route: RefCounted = owner._windows_route
	check(c.automatic_minimal_windows(false).success,"Manual immutable pending for failure diagnostics")
	owner._session.configure_player_nac_automation({"profile":"Aggressive"})
	owner._service.checkpoint(owner._session,initial.snapshot.copy().current.recovery.phase)
	var pending: String = c.minimal_view().pending_text
	check(not pending.is_empty(),"Actual original NAC checkpoint pending")
	var wrong_lease: Dictionary = route.acquire()
	var wrong_parent: Dictionary = route.publish(pending,"wrong expected head",wrong_lease.owner)
	check(not wrong_parent.success and wrong_parent.reason == "stale_expected_head" and route.load_current().text == initial.text,"Wrong expected head cannot publish a new candidate")
	route.release(wrong_lease.owner)
	check(not c.simulate_minimal_acknowledgement(pending).success,"Simulated acknowledgement cannot bypass attached Windows readback")
	var held := FileAccess.open(route.root.path_join("head.bin"),FileAccess.READ)
	var blocked := c.publish_minimal_windows()
	check(not blocked.success and c.minimal_view().pending_text == pending and route.load_current().text == initial.text,"Blocked native head replacement preserves exact acknowledged state and pending")
	held.close()
	var before: Dictionary = owner._session.get_state_snapshot()
	route.fault = "after_native"
	var lost := c.publish_minimal_windows()
	check(not lost.success and c.minimal_view().pending_text == pending and route.load_current().text == pending,"Successful publication/lost response retains exact pending identity")
	# Original gameplay advances after the earlier capture; acknowledgement must
	# not install earlier state. Marked uncertainty is from the real attempt.
	owner._player._movement.request_running(); owner._player._movement.advance(100000,Vector2.ZERO)
	var newer_movement: Dictionary = owner._player.capture_wave_entry_motion()
	route.fault = ""
	var reconciled := publish(c,"normal_lost_response_retry")
	check(reconciled.success and reconciled.exact_retry and owner._session.get_state_snapshot() == before and owner._player.capture_wave_entry_motion() == newer_movement,"Exact retry does not reapply effects or replace newer runtime")
	# Faults before head publication preserve original acknowledged pair.
	for fault: String in ["disk_full_current.pending","disk_full_replica.pending","disk_full_head"]:
		owner._session.configure_player_nac_automation({"profile":"Defensive" if owner._session.get_player_nac_automation().get("profile") != "Defensive" else "Aggressive"})
		owner._player._movement.advance(100000,Vector2.ZERO)
		owner._service.checkpoint(owner._session,initial.snapshot.copy().current.recovery.phase)
		var old: Dictionary = route.load_current()
		route.fault = fault
		var failed_write := c.publish_minimal_windows()
		check(not failed_write.success and route.load_current().text == old.text,"Injected disk-full preserves old head: "+fault+str(failed_write.get("reason","")))
		route.fault = ""; publish(c,"retry_"+fault)
	var current: Dictionary = route.load_current()
	var pid := OS.create_process(OS.get_executable_path(),child_args("hold",route,"none",root.path_join("unused")),false)
	var until := Time.get_ticks_msec()+10000
	while not FileAccess.file_exists(route.root.path_join("writer_held")) and Time.get_ticks_msec() < until: OS.delay_msec(5)
	check(pid > 0 and FileAccess.file_exists(route.root.path_join("writer_held")),"Actual competing Godot writer owns original lease")
	var contested := c.publish_minimal_windows()
	check(not contested.success and route.load_current().text == current.text,"Second process cannot replace the current acknowledged head")
	write(route.root.path_join("release_writer"),"release")
	until = Time.get_ticks_msec()+10000
	while OS.is_process_running(pid) and Time.get_ticks_msec() < until: OS.delay_msec(5)
	check(not OS.is_process_running(pid),"Competing writer released and exited normally")
	var code_output: Array = []
	var code := OS.execute(OS.get_executable_path(),child_args("verify",route,"none",root.path_join("unused")),code_output,true)
	check(code == 0 and str(code_output).contains("46I_COLD "+current.text.sha256_text()),"Fresh native process full v3 semantic cold reader")
	# Each crash starts from a real independently cold-validated acknowledged
	# source snapshot. The killed child issues the original NAC command/capture.
	for at: String in ["before_pair","staged_current.pending","current_published","staged_replica.pending","replica_published","head_staged","before_native","after_native","after_readback","before_maintenance","after_maintenance"]:
		var isolated := Store.new(directory("crash_"+at.replace(".","_")),route.source,route.profile,route.scope,executable,executable_hash)
		var lease := isolated.acquire()
		var installed := isolated.publish(current.text,"",lease.owner)
		check(installed.success,"Crash fixture genuine initial publication "+at)
		isolated.maintain(lease.owner,installed.head_text); isolated.release(lease.owner)
		var expected := root.path_join("expected_"+at.replace(".","_")+".json")
		var output: Array = []
		OS.execute(OS.get_executable_path(),child_args("crash",isolated,at,expected),output,true)
		check(FileAccess.get_file_as_string(isolated.root.path_join("crash_reached")) == at and not FileAccess.file_exists(isolated.root.path_join("kill_returned")) and not str(output).contains("CRASH_DID_NOT_OCCUR"),"Actual process termination marker, no post-kill success "+at+str(output))
		var expected_text: String = FileAccess.get_file_as_string(expected) if at in ["after_native","after_readback","before_maintenance","after_maintenance"] else current.text
		var recovered := isolated.load_current()
		check(recovered.success and recovered.text == expected_text,"Exact acknowledged cold state after actual process termination "+at+": "+str(recovered.get("reason","")))
		check(not isolated.acquire().success,"Unknown original stale directory lock never stolen "+at)
		output.clear()
		code = OS.execute(OS.get_executable_path(),child_args("verify",isolated,"none",root.path_join("unused")),output,true)
		check(code == 0 and str(output).contains("46I_COLD "+expected_text.sha256_text()),"Independent process sees exact post-crash authority "+at)

func historical() -> void:
	var h := Hist.new(); h.root = root.path_join("historical")
	var f := h.make_history("dev_normal",Credit.BASELINE,2,"native")
	check(f.get("success",false),"Actual V2 historical character")
	if not f.get("success",false): return
	var converted := H.Convert.convert(f.records,"dev_normal")
	check(converted.success and converted.comparison.success,"Independently verified original legacy conversion")
	if not converted.success: return
	var source: CombatCharacterDefinitionResource = PlayableCharacterAdmission.prepare_starter(&"vaelis_thorn","dev_normal",Credit.BASELINE).source
	var c := admitted(converted.record,source,"historical")
	if c._minimal_owner == null: return
	var owner: RefCounted = c._minimal_owner
	var original_credit := Credit.prepare(V3.projection(H.new().body(c)),approve)
	check(c.prepare_minimal_fixed_credit(approve).get("state") == "prepared_not_saved","Original confirmed native fixed credit")
	publish(c,"native_fixed_credit")
	check(H.new().body(c).current.xp == original_credit.payload.xp and H.new().body(c).evidence.credit == original_credit.payload.expc_credits,"Exact +10000 EXPC, zero EXPM, original credit evidence")
	check(c.prepare_minimal_fixed_credit(approve).get("no_op",false),"Credit once-only after real acknowledgement")
	check(c.automatic_minimal_windows(true).success,"Real secured synchronous original wave-transition boundaries")
	# Actual original purchases and source-valued future growth, no fixture stats.
	for spec: Array in [["end",6,3000,""],["wis",10,3000,""],["dex",9,3000,"dt"]]:
		var selection := {"expected_current_value":spec[1],"expected_cost":spec[2]}
		if spec[3] != "": selection.allocation = spec[3]
		check(owner._session.request_character_advancement(&"attribute",StringName(spec[0]),"46i_"+spec[0]+str(spec[1]),selection).success,"Original "+spec[0]+" purchase")
		publish(c,"purchase_"+spec[0])
	var p := P.new()
	for i in range(2):
		check(owner._session.request_next_wave().success,"Original next wave")
		publish(c,"history_next_wave")
		p._defeat_wave(owner._session); publish(c,"history_growth")
		owner._session.collect_all_ground_loot(); publish(c,"history_loot")
		if i == 0:
			check(owner._session.request_character_advancement(&"attribute",&"end","46i_end7",{"expected_current_value":7,"expected_cost":3000}).success,"Interleaved END8 purchase")
			publish(c,"interleaved_end")
	for spec: Array in [["str",9,3000],["spd",11,5000]]:
		check(owner._session.request_character_advancement(&"attribute",StringName(spec[0]),"46i_"+spec[0],{"expected_current_value":spec[1],"expected_cost":spec[2]}).success,"Actual "+spec[0]+" purchase")
		publish(c,"purchase_"+spec[0])
	var before: Dictionary = H.new().body(c)
	check(before.evidence.growth.any(func(row): return row.hpb == 2 and row.wisdom == 11),"Original event-time END/HPB/WIS growth")
	check(c.prepare_minimal_new_run(1,approve).get("reason") == "run_identity_reused" and H.new().body(c) == before,"Original allocator rejects the fixture's repeated run identity without mutation")
	PlayableCharacterPersistence.test_run_id = "" # Restore the genuine source allocator; never invent an ID.
	var new_run := c.prepare_minimal_new_run(1,approve)
	check(new_run.success,"Genuine original confirmed NEW RUN: "+str(new_run))
	publish(c,"genuine_new_run")
	var after: Dictionary = H.new().body(c)
	check(after.epoch == before.epoch and after.current.profile_namespace == before.current.profile_namespace and after.evidence == before.evidence and after.current.run_history.size() == before.current.run_history.size()+1 and after.current.run_reward_policy.runs.back().xp_multiplier == 1,"NEW RUN preserves epoch/permanent evidence/namespace and appends locked genuine x1 policy")
	var route: RefCounted = owner._windows_route
	var reloaded: Dictionary = route.load_current()
	check(reloaded.success and reloaded.snapshot.copy() == after,"Cold full semantic reload after all five purchases/credit/new run")
	var restart := CharacterPersistenceCoordinator.new(null)
	check(restart.admit_minimal_snapshot_v3(reloaded.text,source,Credit.PROFILE,"dev_normal",root.path_join("history_cold")).success,"Actual historical credited multi-run cold admission")
	if restart._minimal_owner != null:
		check(restart.attach_minimal_windows(route.root,executable,executable_hash).success and restart.prepare_minimal_fixed_credit(approve).get("no_op",false),"Stored credited profile cannot regrant after restart/NEW RUN")
		restart.close_minimal_prototype()
	check(p._failures.is_empty() and h.failures.is_empty(),"Original history and combat fixture checks")
	c.close_minimal_prototype()

func stress() -> void:
	var w := H.W.new()
	var text := w.current_from_cache("compact45s_bench_25204_2215533/inventory")
	check(not text.is_empty(),"Existing isolated 1005-item stress source")
	if text.is_empty(): return
	var source: CombatCharacterDefinitionResource = w.trusted(text).source
	var decoded := V3.V6.decode(text,source)
	check(decoded.success,"Independent original full V6 stress oracle")
	if not decoded.success: return
	var c := admitted(decoded.record,source,"stress_1005")
	if c._minimal_owner == null: return
	var owner: RefCounted = c._minimal_owner
	owner._session.configure_player_nac_automation({"profile":"Aggressive"})
	owner._service.checkpoint(owner._session,H.new().body(c).current.recovery.phase)
	publish(c,"separate_stress_1005")
	var loaded: Dictionary = owner._windows_route.load_current()
	check(loaded.success and loaded.snapshot.copy().current.items.size() == 1005,"Exact complete stress inventory after cold readback")
	recovery(owner._windows_route,loaded)
	check(w.failures.is_empty(),"Original frozen fixture isolation")
	c.close_minimal_prototype()
