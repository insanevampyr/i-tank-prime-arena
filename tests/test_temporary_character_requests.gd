extends RefCounted
const Owner = preload("res://scripts/rewards/temporary_character_requests.gd")
const Codec = preload("res://scripts/rewards/minimal_character_snapshot.gd")
const B = preload("res://tests/test_minimal_character_snapshot.gd")
const Q = preload("res://tests/test_compact_v6_gameplay_candidate.gd")
const P = preload("res://tests/test_playable_vaelis_persistence.gd")
const Player = preload("res://scripts/player/placeholder_player.gd")
var failures: Array[String] = []
var assertions := 0
var root := ""

func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok: failures.append(label)

func setup(path: String, enabled: bool = true, mode: String = "dev_normal") -> Dictionary:
	var q := Q.new()
	var f := q.start(CharacterSaveStorage.new(path),mode,10 if mode=="dev_normal" else 1)
	check(f.success,"Original fresh disposable admission")
	if not f.success: return f
	f["q"] = q
	f["p"] = Player.new(); f.p.reset_for_encounter(Vector2(14,8))
	check(f.p.configure_authoritative_actor_profile(f.session.simulation.get_actor_definition(&"player")).success and f.p.restore_wave_entry_motion(f.movement.wave_entry_state()),"Actual external player matches original movement")
	f.session.player_movement_boundary_provider = f.p.capture_wave_entry_motion
	f.session.player_speed_profile_refresher = f.p.refresh_permanent_speed_profile
	f.session.player_endurance_profile_refresher = f.p.refresh_permanent_endurance_profile
	f["c"] = CharacterPersistenceCoordinator.new(null)
	if enabled:
		var body: Dictionary = B.new().make(f.service.records.back(),f.service.source)
		var text: String = Codec.encode(body,f.service.source,f.service.profile_id,mode).text
		check(f.c.bind_temporary_requests(f.session,f.p,text).success,"Coordinator binds cold verified identity and real capture gate")
	return f

func snapshot(f: Dictionary) -> Dictionary:
	return {"session":f.session.get_state_snapshot(),"movement":f.p.capture_wave_entry_motion(),"profile":f.service._prior.duplicate(true),"generation":f.service.generation}

func issue(f: Dictionary, kind: String, definition: String, operation: String, id: String) -> Dictionary:
	return f.c.issue_temporary_request(f.c.temporary_context(),kind,definition,operation,id)

func execute(f: Dictionary, kind: String, definition: String, operation: String, id: String) -> Dictionary:
	var ticket := issue(f,kind,definition,operation,id)
	if not ticket.success: return ticket
	return f.c.execute_temporary_request(ticket.request)

func run() -> Array[String]:
	var prior: Array = [PlayableCharacterPersistence.test_storage,PlayableCharacterPersistence.test_run_id,PlayableCharacterPersistence.test_nonpersistent]
	PlayableCharacterPersistence.test_nonpersistent = false
	root = OS.get_cache_dir().path_join("itank-storage-tests/temporary46f_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()])
	var original := gameplay(root.path_join("control"),false)
	var guarded := gameplay(root.path_join("guarded"),true)
	check(original==guarded,"Complete original gameplay/loot/growth/resources/clock/RNG/movement equivalence")
	check(gameplay(root.path_join("client2"),true)==guarded,"Independently seeded simulated clients converge")
	lifecycle()
	invalid_identity()
	namespace_isolation()
	PlayableCharacterPersistence.test_storage=prior[0]; PlayableCharacterPersistence.test_run_id=prior[1]; PlayableCharacterPersistence.test_nonpersistent=prior[2]
	print("46F temporary requests: %d assertions; failures %s" % [assertions,str(failures)])
	return failures

func gameplay(path: String, bound: bool) -> Dictionary:
	var f := setup(path,bound)
	if not f.success: return {}
	var s: ArenaCombatSession = f.session
	var helper := P.new(); helper._defeat_wave(s)
	var origin := s.simulation.record_reward_event(&"reward_source_item_fixture",&"player",&"player",{})
	s.simulation.create_ground_loot_item("46f_potions",{"definition_id":"health_potion","quantity":2,"display_name":"Health Potion","item_kind":"potion","source_ref":"PRIME-V3 p.120; disposable original acquisition fixture"},s.get_actor_state(&"player").position_microfeet,&"player",origin.event_id)
	check(s.collect_all_ground_loot().success,"Original acquired consumable origins")
	for command: Array in [["unequip","prime_v3_short_wand","","shared_raw"],["equip","prime_v3_short_wand","","reequip"],["handling","prime_v3_short_wand","stow","stow"]]:
		var result: Dictionary = execute(f,command[0],command[1],command[2],command[3]) if bound else original_command(s,command)
		check(result.success,"Genuine original equipment/handling "+str(command))
	s.get_actor_state(&"player").current_hpc=1 # Disposable wounded setup, not fabricated healing.
	check((execute(f,"use","health_potion","","use_once") if bound else s.request_player_inventory_consumable_use(&"health_potion","use_once")).success,"Original successful use still consumes/rolls exactly once")
	check(s.request_next_wave().success,"Original NEXT WAVE")
	s.set_opponent_behavior_enabled(false)
	check((execute(f,"handling","prime_v3_short_wand","draw","draw") if bound else s.request_player_weapon_handling(&"prime_v3_short_wand","draw","draw")).success,"Genuine timed draw")
	s.advance_by(6000000)
	if bound:
		var after_draw := snapshot(f)
		var original_draw: RefCounted=s.simulation.get_action(issue(f,"handling","prime_v3_short_wand","draw","draw").request._context.get_ref()._results.draw.action_instance_id)
		check(not s.simulation._commit_weapon_handling(&"player","prime_v3_short_wand","draw",{},"draw",original_draw.final_event_id).success and snapshot(f)==after_draw,"Original draw completion cannot be applied twice")
	check((execute(f,"handling","prime_v3_short_wand","stow","free_hand") if bound else s.request_player_weapon_handling(&"prime_v3_short_wand","stow","free_hand")).success,"Original active stow")
	var result: Dictionary = execute(f,"use","health_potion","","interrupted") if bound else s.request_player_inventory_consumable_use(&"health_potion","interrupted")
	check(result.success,"Original accepted no-effect potion request")
	var action_id: String = result.get("result",result).get("action_instance_id","")
	var interrupted: RefCounted
	if bound:
		interrupted=issue(f,"use","health_potion","","interrupted").request
		check(not f.c.cancel_temporary_request(interrupted).success,"Accepted action must use original interruption, never a fabricated cancellation/refund")
		check(not f.c.capture_temporary_checkpoint("entry","pending_action").success and not f.c.close_temporary_requests().success,"Capture/closure cannot retire a pending action")
	if not action_id.is_empty():
		check(s.simulation.schedule_interruption(action_id,s.simulation.clock.get_elapsed_us(),&"player","disposable_interrupt").success,"Original interruption scheduling")
		s.advance_by(1)
	check(s.get_actor_state(&"player").inventory_quantities.health_potion==1,"Interrupted use consumes no extra unit")
	helper._defeat_wave(s)
	check(helper._failures.is_empty() and f.service.errors.is_empty(),"Original source fixture assertions retained")
	var final := snapshot(f)
	if bound:
		var retired: RefCounted=f.c.temporary_context()
		var captured: Dictionary = f.c.capture_temporary_checkpoint("downtime","interrupted_terminal")
		check(captured.success and f.c.simulate_temporary_ack(captured.capture,captured.text).success,"Actual terminal capture and normal simulated ack safely retire no-effect action requests")
		check(retired._tickets.is_empty() and not f.c.execute_temporary_request(interrupted).success,"Interrupted accepted request remains rejected after new reply cache is cleared")
		var old_action: CombatActionInstance=s.simulation.get_action(action_id)
		var definition: CombatActionDefinition=s.simulation._action_definitions[String(old_action.action_definition_id)]
		check(not s.simulation._apply_verified_consumable_healing(s.get_actor_state(&"player"),old_action,definition.extension_metadata.verified_consumable,old_action.final_event_id) and snapshot(f)==final,"Retired late consumable completion changes no resource, item or RNG")
		check(f.c.close_temporary_requests().success,"Terminal idle admission closes")
	f.p.free()
	return final

func original_command(s: ArenaCombatSession, command: Array) -> Dictionary:
	match command[0]:
		"equip": return s.request_player_inventory_equip(StringName(command[1]),command[3])
		"unequip": return s.request_player_inventory_unequip(StringName(command[1]),command[3])
		_: return s.request_player_weapon_handling(StringName(command[1]),command[2],command[3])

func lifecycle() -> void:
	var f := setup(root.path_join("lifecycle"))
	if not f.success: return
	var s: ArenaCombatSession = f.session; var c: CharacterPersistenceCoordinator = f.c
	var helper := P.new(); helper._defeat_wave(s)
	check(helper._failures.is_empty(),"Authoritative downtime reached")
	var old_context: RefCounted = c.temporary_context()
	var old := issue(f,"unequip","prime_v3_short_wand","","shared_raw")
	check(old.success,"Issue immutable actual-context request")
	var delayed: Callable = func(): return c.execute_temporary_request(old.request)
	var result: Dictionary = delayed.call()
	check(result.success,"Delayed callback keeps issued context and dispatches once while valid")
	var after := snapshot(f); var revision: int = s._character_capture_gate.revision()
	check(delayed.call().get("exact_retry",false) and snapshot(f)==after and s._character_capture_gate.revision()==revision,"Exact valid retry does not enter source or consume RNG")
	check(c.issue_temporary_request(old_context,"unequip","prime_v3_short_wand","","shared_raw").request==old.request,"Exact issuance retry returns original handle")
	check(not c.issue_temporary_request(old_context,"equip","prime_v3_short_wand","","shared_raw").success,"Changed binding under same ID rejects")
	var never := issue(f,"equip","prime_v3_short_wand","","never_accepted")
	var stale := issue(f,"equip","prime_v3_short_wand","","issued_before_other_attempt")
	check(not execute(f,"equip","not_an_owned_definition","","unrelated_invalid_attempt").success,"Original failed validation still preserves original rules")
	var stale_state := snapshot(f)
	check(c.execute_temporary_request(stale.request).get("reason")=="temporary_request_revision_stale" and snapshot(f)==stale_state,"Stale expected revision rejects before an otherwise legal equipment effect")
	check(issue(f,"equip","prime_v3_short_wand","","issued_before_other_attempt").request==stale.request,"Reissuing an old intent cannot refresh its expected revision")
	var data: Dictionary = old.request.copy(); data.intent.id="forged"
	old.request._json="forged"
	check(not c.execute_temporary_request(Owner.Request.new(old_context,JSON.stringify(data))).success,"Caller-created equal-looking request is not issued authority")
	var before_raw := snapshot(f); revision=s._character_capture_gate.revision()
	check(not s.request_player_inventory_equip(&"prime_v3_short_wand","raw_bypass").success,"Session raw-ID bypass rejects before mutation")
	check(not s.simulation.request_weapon_handling(&"player",&"prime_v3_short_wand","draw","raw_bypass").success,"Simulator raw entry bypass rejects")
	var potion := PrimeV3InventoryCatalog.make_carried_potion_action_definition("health_potion",&"forged_item_action")
	check(not s.simulation.start_action(&"player",potion,"raw_bypass").success,"Generic action entry cannot bypass item context")
	check(not s.simulation.start_equip_hand_item_action(&"player",&"prime_v3_short_wand",&"left","raw_bypass").success,"Auxiliary hand-equipment entry cannot bypass request context")
	check(snapshot(f)==before_raw and s._character_capture_gate.revision()==revision,"Raw rejections precede gate revisions, source effects and RNG")
	check(not s._character_capture_gate.unbind().success,"Unbinding cannot reopen old raw APIs")
	var captured := c.capture_temporary_checkpoint("downtime","checkpoint_1")
	check(captured.success and not captured.durable,"Original legal joint capture is explicitly nondurable")
	if not captured.success: f.p.free(); return
	check(not c.capture_temporary_checkpoint("downtime","parallel").success,"One pending capture")
	check(not c.execute_temporary_request(never.request).success,"Sealed window cannot execute a previously unaccepted request")
	check(delayed.call().get("exact_retry",false),"Accepted exact retry remains available while sealed and unresolved")
	check(not c.simulate_temporary_ack(captured.capture,captured.text+" ").success,"Changed simulated readback rejects")
	check(c.simulate_temporary_unknown(captured.capture).success,"Only a fresh owned capture starts uncertain simulation")
	check(not c.cancel_temporary_checkpoint().success and not c.close_temporary_requests().success,"Uncertain capture is preserved, not canceled/discarded")
	check(execute(f,"equip","prime_v3_short_wand","","post_capture").success,"New-context gameplay continues without an I/O freeze")
	check(s.request_next_wave().success,"Actual gameplay clock, roster and RNG continue while earlier acknowledgement is uncertain")
	s.set_opponent_behavior_enabled(false)
	check(execute(f,"handling","prime_v3_short_wand","stow","during_uncertainty_stow").success,"Current-window handling remains legal after capture")
	var in_flight := execute(f,"handling","prime_v3_short_wand","draw","during_uncertainty_draw")
	check(in_flight.success,"Current-window asynchronous action begins before earlier acknowledgement")
	var newer := snapshot(f); var accepted_ids := s.simulation._accepted_request_ids.duplicate(true)
	check(not s._character_capture_gate.is_current(captured.capture),"New gameplay makes old current-state claim stale")
	check(c.simulate_temporary_ack(captured.capture,captured.text).success,"Exact earlier uncertain outcome reconciles without recapture/reexecution")
	check(snapshot(f)==newer,"Earlier checkpoint cannot replace newer actor, RNG, movement or original committed profile")
	check(old_context._tickets.is_empty() and old_context._results.is_empty(),"Only new volatile per-ID reply/issuance cache is released after retirement")
	var calls: int = c.temporary_request_status().source_calls; revision=s._character_capture_gate.revision()
	check(not delayed.call().success and not c.execute_temporary_request(never.request).success,"Retired accepted and never-accepted requests reject with empty memo")
	check(not c.issue_temporary_request(old_context,"equip","prime_v3_short_wand","","old_callback_refresh").success,"Old callback cannot acquire a fresh context automatically")
	check(c.temporary_request_status().source_calls==calls and s._character_capture_gate.revision()==revision and snapshot(f)==newer,"Expired requests never enter any source mutation")
	check(s.simulation._accepted_request_ids==accepted_ids,"Original simulator acceptance IDs are never deleted")
	s.advance_by(6000000)
	check(s.simulation.is_weapon_attack_ready(&"player",&"prime_v3_short_wand"),"Earlier-window retirement cannot erase a current-window action's completion authority")
	helper._defeat_wave(s)
	check(helper._failures.is_empty(),"Later wave completes after reconciliation")
	check(not c.simulate_temporary_ack(captured.capture,captured.text).success,"Old checkpoint cannot be acknowledged again")
	var canceled := issue(f,"unequip","prime_v3_short_wand","","canceled_before_dispatch")
	check(c.cancel_temporary_request(canceled.request).success and not c.execute_temporary_request(canceled.request).success,"Cancellation prevents later execution")
	var next := c.capture_temporary_checkpoint("downtime","checkpoint_2")
	check(next.success,"Next actual checkpoint captures current context")
	var cancellation_state := snapshot(f)
	if next.success:
		check(not c.simulate_temporary_ack(captured.capture,captured.text).success,"Stale checkpoint cannot replace a newer pending checkpoint")
		check(execute(f,"handling","prime_v3_short_wand","stow","after_second_capture").success,"Gameplay also continues after a second capture")
		cancellation_state=snapshot(f)
		check(not c.simulate_temporary_ack(next.capture,next.text).success and not c.simulate_temporary_unknown(next.capture).success,"Unattempted stale capture cannot later claim publication authorization")
		check(c.cancel_temporary_checkpoint().success,"Known-unpublished capture cancellation releases only its context")
	check(snapshot(f)==cancellation_state,"Cancellation never rolls back effects or adopts a checkpoint")
	var auth := s.get_abandon_run_authorization()
	var latest: Dictionary = f.service.records.back()
	var text: String = Codec.encode(B.new().make(latest,f.service.source),f.service.source,f.service.profile_id,"dev_normal").text
	check(c.close_temporary_requests().success,"Idle admission closes without reopening raw APIs")
	check(not s.request_player_inventory_unequip(&"prime_v3_short_wand","after_close").success,"Disposed owner leaves fail-closed old runtime marker")
	f.p.free()
	reopen(f,text,latest,auth,old.request)

func reopen(old: Dictionary, text: String, latest: Dictionary, auth: Dictionary, old_request: RefCounted) -> void:
	var q := Q.new()
	var resumed := q.start(CharacterSaveStorage.new(old.service.storage._root),"dev_normal",null,latest,true)
	check(resumed.success,"Original reload source path")
	if not resumed.success: return
	var p := Player.new(); p.reset_for_encounter(Vector2(14,8))
	p.configure_authoritative_actor_profile(resumed.session.simulation.get_actor_definition(&"player")); p.restore_wave_entry_motion(resumed.movement.wave_entry_state())
	resumed.session.player_movement_boundary_provider=p.capture_wave_entry_motion
	var c: CharacterPersistenceCoordinator = old.c
	check(c.bind_temporary_requests(resumed.session,p,text).success,"Reload creates a fresh actual admission context")
	check(not c.execute_temporary_request(old_request).success,"Same coordinator cannot rebind the old admission's issued request")
	check(not c.execute_temporary_request(Owner.Request.new(c.temporary_context(),"{}" )).success,"Serialized/forged old request cannot become new authority")
	var current := c.issue_temporary_request(c.temporary_context(),"unequip","prime_v3_short_wand","","reload_current")
	check(current.success and c.cancel_temporary_request(current.request).success,"Reloaded context issues a fresh intent; canceled intent changes no source head")
	auth=resumed.session.get_abandon_run_authorization()
	check(c.close_temporary_requests().success,"Close reloaded context before NEW RUN")
	p.free()
	check(auth.success,"Existing NEW RUN authorization is source-generated")
	var fresh := q.start(CharacterSaveStorage.new(old.service.storage._root),"dev_normal",10,latest,true,true,auth.checkpoint)
	check(fresh.success,"Original authorized NEW RUN, no new implementation: "+str(fresh.get("reason","")))
	if not fresh.success: return
	var body: Dictionary=B.new().make(fresh.service.records.back(),fresh.service.source)
	check(body.current.recovery.run_id!=old.service.run_id,"Actual new run identity differs")
	p=Player.new();p.reset_for_encounter(Vector2(14,8));p.configure_authoritative_actor_profile(fresh.session.simulation.get_actor_definition(&"player"));p.restore_wave_entry_motion(fresh.movement.wave_entry_state())
	fresh.session.player_movement_boundary_provider=p.capture_wave_entry_motion
	c=CharacterPersistenceCoordinator.new(null)
	check(c.bind_temporary_requests(fresh.session,p,Codec.encode(body,fresh.service.source,fresh.service.profile_id,"dev_normal").text).success,"Original NEW RUN gets fresh request context with preserved epoch/profile")
	check(body.epoch==JSON.parse_string(JSON.parse_string(text).body_json).epoch,"NEW RUN preserves the actual admitted character epoch")
	check(not c.execute_temporary_request(old_request).success,"Old issued request cannot cross into an actual new run")
	var helper := P.new(); helper._defeat_wave(fresh.session)
	check(helper._failures.is_empty(),"Original new run reaches legal equipment boundary")
	var request := c.issue_temporary_request(c.temporary_context(),"unequip","prime_v3_short_wand","","shared_raw")
	check(request.success and c.execute_temporary_request(request.request).success,"Same raw text in a different run is a genuinely new issued request")
	check(c.close_temporary_requests().success,"NEW RUN fixture closes")
	p.free()
	cold_restart(fresh,old_request.json())

func cold_restart(f: Dictionary, old_json: String) -> void:
	var record: Dictionary=B.new().make(f.service.records.back(),f.service.source)
	var text: String=Codec.encode(record,f.service.source,f.service.profile_id,"dev_normal").text
	var path := root.path_join("cold_restart.json")
	DirAccess.make_dir_recursive_absolute(root)
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"storage_root":f.service.storage._root,"snapshot_text":text,"old_request":old_json},"",true,true));file.close()
	var output: Array=[]
	var code := OS.execute(OS.get_executable_path(),["--headless","--path",ProjectSettings.globalize_path("res://"),"--script","res://tests/temporary_requests_cold_process.gd","--",root],output,true)
	check(code==0 and str(output).contains("46F_COLD_PASS"),"Fresh process original reload rejects old bytes/raw callbacks and runs new issued command: "+str(output))

func invalid_identity() -> void:
	var f := setup(root.path_join("invalid"))
	if not f.success: return
	var ticket := issue(f,"unequip","prime_v3_short_wand","","old_identity")
	var saved: String=f.service.run_id;f.service.run_id="different_run"
	check(not f.c.execute_temporary_request(ticket.request).success,"Changed actual source identity invalidates admission")
	f.service.run_id=saved
	check(not f.c.execute_temporary_request(ticket.request).success,"Restoring old values cannot resurrect invalidated authority")
	f.p.free()

func namespace_isolation() -> void:
	var a := setup(root.path_join("normal_identity"),true,"normal")
	var b := setup(root.path_join("dev_identity"))
	if not a.success or not b.success: return
	var context_a: RefCounted=a.c.temporary_context();var context_b: RefCounted=b.c.temporary_context()
	var identity_a: Dictionary=JSON.parse_string(context_a.json());var identity_b: Dictionary=JSON.parse_string(context_b.json())
	check(identity_a.profile==a.service.profile_id and identity_a.namespace=="normal" and identity_b.profile==b.service.profile_id and identity_b.namespace=="dev_normal" and identity_a.profile!=identity_b.profile,"Contexts bind actual distinct NORMAL/DEV profile identities")
	var request: Dictionary=b.c.issue_temporary_request(context_b,"unequip","prime_v3_short_wand","","same_literal")
	var before := snapshot(a)
	check(not a.c.execute_temporary_request(request.request).success and snapshot(a)==before,"Foreign profile/namespace request cannot enter source rules")
	check(a.c.close_temporary_requests().success and b.c.close_temporary_requests().success,"Both independent admissions close")
	a.p.free();b.p.free()
