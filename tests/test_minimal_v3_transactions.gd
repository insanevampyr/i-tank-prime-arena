extends RefCounted
const Codec = preload("res://scripts/rewards/minimal_character_snapshot_v3.gd")
const Q = preload("res://tests/test_compact_v6_gameplay_candidate.gd")
const G = preload("res://tests/test_minimal_character_snapshot_v3.gd")
const P = preload("res://tests/test_playable_vaelis_persistence.gd")
const H = preload("res://tests/test_historical_vaelis_admission.gd")
const Convert = preload("res://scripts/rewards/legacy_to_compact_v6_prototype.gd")
const Credit = Codec.Credit
const W = preload("res://tests/test_compact_v6_snapshot_package.gd")
const Native = preload("res://scripts/rewards/compact_v6_fixed_credit.gd")
const Player = preload("res://scripts/player/placeholder_player.gd")

# The older Q harness deliberately uses Running RNG seed 1. For NEW RUN use
# the actual original Player reset/profile API on BOTH clients, so this control
# exercises production reset semantics rather than a different test profile.
class PlayerControl extends Q.Observed:
	var player: Node
	func bind_runtime(session: ArenaCombatSession) -> Dictionary:
		player = preload("res://scripts/player/placeholder_player.gd").new()
		player.reset_for_encounter(Vector2(14,8))
		var configured: Dictionary = player.configure_authoritative_actor_profile(session.simulation.get_actor_definition(&"player"))
		if not configured.success: return configured
		session.player_movement_boundary_provider = player.capture_wave_entry_motion
		session.player_speed_profile_refresher = player.refresh_permanent_speed_profile
		session.player_endurance_profile_refresher = player.refresh_permanent_endurance_profile
		return super.bind_runtime(session)
var failures: Array[String] = []
var assertions := 0
var root := ""
var measures: Array = []

func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok: failures.append(label)

func body(c: CharacterPersistenceCoordinator) -> Dictionary:
	return Codec.Contract._normalize_json_numbers(JSON.parse_string(c.minimal_view().body_json))

func admit(r: Dictionary, source: CombatCharacterDefinitionResource, label: String) -> CharacterPersistenceCoordinator:
	var packed: Dictionary = G.new().pack(r)
	var encoded := Codec.encode(packed,source,packed.current.character_id,packed.current.profile_namespace)
	check(encoded.success,"Independent v3 fixture "+label)
	var c := CharacterPersistenceCoordinator.new(null)
	if not encoded.success: return c
	var result := c.admit_minimal_snapshot_v3(encoded.text,source,packed.current.character_id,packed.current.profile_namespace,root.path_join("owned_"+label))
	check(result.success,"Existing coordinator owns v3: "+label+": "+str(result))
	return c

func item(c: CharacterPersistenceCoordinator, kind: String, ref: String, operation: String, id: String) -> Dictionary:
	var issued := c.issue_temporary_request(c.temporary_context(),kind,ref,operation,id)
	if not issued.success: return issued
	return c.execute_temporary_request(issued.request)

func ack(c: CharacterPersistenceCoordinator) -> void:
	var v := c.minimal_view()
	var prepared := c.prepare_minimal_snapshot(v.pending_operation,v.revision)
	check(prepared.success,"Owned immutable pending bytes")
	if prepared.success: check(c.simulate_minimal_acknowledgement(prepared.text).success,"Explicit simulated exact readback only")

func compare(c: CharacterPersistenceCoordinator, control: Dictionary, label: String, commit_gap: int = 0) -> void:
	var a: RefCounted = c._minimal_owner
	var b := body(c)
	var cold := Codec.validate(b,a._source,a._service.profile_id,a._service.mode)
	check(cold.success,"Independent cold verifier after source effects: "+label+": "+str(cold.get("reason",""))+str(cold.get("details",{})))
	check(a._session.get_state_snapshot() == control.session.get_state_snapshot(),"Complete original gameplay/event/RNG equivalence: "+label)
	check(a._player.capture_wave_entry_motion() == control.movement.wave_entry_state(),"External Running/movement/RNG equivalence: "+label)
	if not cold.success: return
	var r: Dictionary = control.service.records.back()
	var expected: Dictionary = G.new().pack(r,G.new().debits(control.session))
	check(expected.current.generation == b.sequence+commit_gap,"Explicit original-save count versus compact committed sequence: "+label)
	# v3 counts prepared commits, not every original control publication. When
	# two control saves occur during one immutable pending operation, assert the
	# exact known gap; compare every character/checkpoint/evidence field intact.
	expected.current.generation = b.sequence
	check(cold.snapshot.projection() == Codec.projection(expected),"Full original supported projection including original growth/items/resources: "+label)
	check(b.evidence == expected.evidence,"Original independent essential evidence/order/debits exact: "+label)
	check(not b.has("operations") and not b.has("lifetime_ids") and not b.has("command_evidence") and a._ids.is_empty(),"No hidden checkpoint archive, permanent temporary transcript or duplicate ID table")
	check(b.recent_journal.size() <= 20,"Bounded journal")
	measures.append({"fixture":label,"metrics":c.minimal_view().metrics,"admission_cold_us":c.minimal_view().admission_cold_us})

func run() -> Array[String]:
	var prior: Array = [PlayableCharacterPersistence.test_storage,PlayableCharacterPersistence.test_run_id,PlayableCharacterPersistence.test_nonpersistent]
	PlayableCharacterPersistence.test_nonpersistent = false
	root = OS.get_cache_dir().path_join("itank-storage-tests/minimal46c2_46h_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()])
	for scope: String in ["normal","dev_normal"]: scenario(scope)
	historical()
	stress_and_unsupported()
	PlayableCharacterPersistence.test_storage = prior[0]; PlayableCharacterPersistence.test_run_id = prior[1]; PlayableCharacterPersistence.test_nonpersistent = prior[2]
	print("46H_METRICS "+JSON.stringify({"fixtures":measures,"scope":"native Windows Godot debug prepare only; no storage, Edge or save-latency claim"}))
	print("46H v3 coordinator: %d assertions; failures %s" % [assertions,str(failures)])
	return failures

func scenario(scope: String) -> void:
	var q := Q.new()
	var initial := q.start(CharacterSaveStorage.new(root.path_join("control_"+scope)),scope,1 if scope == "normal" else 10)
	check(initial.success,"Genuine source first Wave 1")
	if not initial.success: return
	var r: Dictionary = initial.service.records.back()
	var c := admit(r,initial.service.source,scope)
	if c._minimal_owner == null: return
	var a: RefCounted = c._minimal_owner
	var s: ArenaCombatSession = a._session
	var control := q.start(CharacterSaveStorage.new(initial.service.storage._root),scope,null,r,true)
	check(control.success,"Independent original acknowledged reload control")
	if not control.success: c.close_minimal_prototype(); return
	check(c.simulate_minimal_automatic_checkpoints(true).success,"Opt-in nondurable automatic test acknowledgement")
	var helper := P.new(); var original := P.new()
	helper._defeat_wave(s); original._defeat_wave(control.session)
	check(s.collect_all_ground_loot().success and control.session.collect_all_ground_loot().success,"Real source-valued XP/items/growth")
	compare(c,control,scope+"_first_wave")
	for session: ArenaCombatSession in [s,control.session]:
		var cause := session.simulation.record_reward_event(&"reward_source_fixture",&"player",&"player",{})
		session.simulation.create_ground_loot_item("46h_potions",{"definition_id":"health_potion","quantity":3,"display_name":"Health Potion","item_kind":"potion","source_ref":"Prime V3 p.120; disposable original fixture"},session.get_actor_state(&"player").position_microfeet,&"player",cause.event_id)
		check(session.collect_all_ground_loot().success,"Actual owned potion acquisition")
	check(item(c,"unequip","prime_v3_short_wand","","off").success and control.session.request_player_inventory_unequip(&"prime_v3_short_wand","off").success,"Genuine original unequip")
	check(item(c,"equip","prime_v3_short_wand","","on").success and control.session.request_player_inventory_equip(&"prime_v3_short_wand","on").success,"Genuine original equip")
	compare(c,control,scope+"_equipment")
	check(c.simulate_minimal_automatic_checkpoints(false).success,"Manual pending simulation")
	var old_context: RefCounted = c.temporary_context()
	var issued := c.issue_temporary_request(old_context,"handling","prime_v3_short_wand","stow","pending_stow")
	check(issued.success,"Actual issued request context")
	if not issued.success: c.close_minimal_prototype(); return
	var result := c.execute_temporary_request(issued.request)
	check(result.success and control.session.request_player_weapon_handling(&"prime_v3_short_wand","stow","pending_stow").success,"Original stow effects captured")
	var before := s.get_state_snapshot()
	check(c.execute_temporary_request(issued.request).get("exact_retry",false) and s.get_state_snapshot() == before,"Valid exact retry does not enter gameplay/RNG")
	check(not c.issue_temporary_request(old_context,"handling","prime_v3_short_wand","draw","pending_stow").success,"Conflicting same-ID binding rejected")
	var view := c.minimal_view()
	var pending := c.prepare_minimal_snapshot(view.pending_operation,view.revision)
	check(pending.success and Codec.decode(pending.text,a._source,a._service.profile_id,scope).success,"Pending v3 bytes cold verify")
	check(c.simulate_minimal_unknown_outcome().success,"Only current owned checkpoint begins simulated uncertainty")
	check(not c.cancel_minimal_snapshot().success,"Uncertain bytes cannot be discarded")
	a._player._movement.request_running(); control.movement.request_running()
	a._player._movement.advance(100000,Vector2.ZERO); control.movement.advance(100000,Vector2.ZERO)
	check(not c.prepare_minimal_snapshot(view.pending_operation,view.revision).current_runtime,"External zero-direction Running advancement invalidates the older current-state claim")
	for session: ArenaCombatSession in [s,control.session]: session.get_actor_state(&"player").current_hpc = 1
	check(item(c,"use","health_potion","","downtime_use").success and control.session.request_player_inventory_consumable_use(&"health_potion","downtime_use").success,"New-window genuine consumption proceeds during earlier uncertainty")
	check(s.request_next_wave().success and control.session.request_next_wave().success,"Original NEXT WAVE proceeds while an earlier capture is uncertain")
	s.set_opponent_behavior_enabled(false); control.session.set_opponent_behavior_enabled(false)
	check(item(c,"handling","prime_v3_short_wand","draw","draw").success and control.session.request_player_weapon_handling(&"prime_v3_short_wand","draw","draw").success,"Original one-Act draw begins under the new window before prior reconciliation")
	var newer := s.get_state_snapshot(); var motion: Dictionary = a._player.capture_wave_entry_motion()
	check(c.minimal_view().pending_text == pending.text,"Continued gameplay cannot replace immutable pending bytes")
	check(c.simulate_minimal_acknowledgement(pending.text).success and s.get_state_snapshot() == newer and a._player.capture_wave_entry_motion() == motion,"Earlier readback never installs an older runtime or replays effects")
	check(old_context._tickets.is_empty() and not c.execute_temporary_request(issued.request).success,"Retired callback rejected after volatile memo clears")
	check(c.simulate_minimal_automatic_checkpoints(true).success,"Resume automatic nondurable test mode")
	s.advance_by(6000000); control.session.advance_by(6000000)
	check(s.simulation.is_weapon_attack_ready(&"player",&"prime_v3_short_wand") and s.get_state_snapshot() == control.session.get_state_snapshot(),"New-window action completes after old-window retirement with original events/RNG")
	check(item(c,"handling","prime_v3_short_wand","stow","stow_active").success and control.session.request_player_weapon_handling(&"prime_v3_short_wand","stow","stow_active").success,"Original zero-Act active stow")
	for session: ArenaCombatSession in [s,control.session]: session.get_actor_state(&"player").current_hpc = 1
	check(item(c,"use","health_potion","","active_use").success and control.session.request_player_inventory_consumable_use(&"health_potion","active_use").success,"Original timed potion accepted")
	s.advance_by(11000000); control.session.advance_by(11000000)
	var interrupted := item(c,"use","health_potion","","interrupted")
	var control_interrupted: Dictionary = control.session.request_player_inventory_consumable_use(&"health_potion","interrupted")
	check(interrupted.success and control_interrupted.success,"Original interrupted action accepted")
	if interrupted.success and control_interrupted.success:
		s.simulation.schedule_interruption(interrupted.result.action_instance_id,s.simulation.clock.get_elapsed_us(),&"player","fixture_interrupt")
		control.session.simulation.schedule_interruption(control_interrupted.action_instance_id,control.session.simulation.clock.get_elapsed_us(),&"player","fixture_interrupt")
		s.advance_by(1); control.session.advance_by(1)
	helper._defeat_wave(s); original._defeat_wave(control.session)
	for session: ArenaCombatSession in [s,control.session]: session.get_actor_state(&"player").current_hpc = 1
	check(item(c,"use","health_potion","","last_use").success and control.session.request_player_inventory_consumable_use(&"health_potion","last_use").success,"Actual terminal zero quantity")
	compare(c,control,scope+"_active_and_zero",2)
	for i in range(23):
		var preferences := {"order":["nac","block","dodge","soak"] if i%2 else ["nac","dodge","block","soak"]}
		check(s.request_character_development("preferences",preferences,"pref_"+str(i)).success and control.session.request_character_development("preferences",preferences,"pref_"+str(i)).success,"Source checkpoint without lifetime operation growth")
	compare(c,control,scope+"_bounded_journal",2)
	var current := body(c)
	var encoded := Codec.encode(current,a._source,a._service.profile_id,scope)
	var source: CombatCharacterDefinitionResource = a._source
	negative_cases(encoded.text,source,scope)
	var old_ticket: RefCounted = issued.request
	c.close_minimal_prototype()
	var reopened := CharacterPersistenceCoordinator.new(null)
	check(reopened.admit_minimal_snapshot_v3(encoded.text,source,current.current.character_id,scope,root.path_join("cold_"+scope)).success,"Cold restart uses only current v3 record")
	if reopened._minimal_owner != null:
		var b: RefCounted = reopened._minimal_owner
		var saved: Dictionary = b._session.get_state_snapshot(); var calls: int = b._requests.status().source_calls
		check(not reopened.execute_temporary_request(old_ticket).success,"Old runtime handle cannot enter cold admission")
		var reuse := reopened.issue_temporary_request(reopened.temporary_context(),"use","health_potion","","downtime_use")
		check(reuse.success and reopened.execute_temporary_request(reuse.request).get("reason") == "reused_irreversible_consumption","Original irreversible ID survives journal eviction and cold restart")
		check(b._session.get_state_snapshot() == saved and b._requests.status().source_calls == calls,"Cold replay rejection precedes original mutation and RNG")
		cold_process(c,encoded.text,source,scope)
		reopened.close_minimal_prototype()
	check(helper._failures.is_empty() and original._failures.is_empty() and q.failures.is_empty() and control.service.errors.is_empty(),"All independent original source assertions retained: "+str(control.service.errors))
	check(not DirAccess.dir_exists_absolute(root.path_join("owned_"+scope)),"No prototype storage writes or slot creation")

func negative_cases(text: String, source: CombatCharacterDefinitionResource, scope: String) -> void:
	var c := CharacterPersistenceCoordinator.new(null)
	var profile := "prod_vaelis_thorn" if scope == "normal" else "dev_vaelis_thorn"
	check(c.admit_minimal_snapshot_v3(text,source,profile,scope,root.path_join("negative_"+scope)).success,"Separate negative disposable admission")
	if c._minimal_owner == null: return
	var a: RefCounted = c._minimal_owner; var s: ArenaCombatSession = a._session
	var original := s.get_state_snapshot(); var original_body: String = c.minimal_view().body_json
	check(not c.prepare_minimal_fixed_credit(approve).success and s.get_state_snapshot() == original,"Wrong profile/baseline never receives the historical fixed grant")
	if scope == "normal":
		var denied := c.prepare_minimal_new_run(10,approve)
		check(denied.get("reason") == "normal_run_policy_changed" and s.get_state_snapshot() == original,"Original NORMAL policy cannot escalate through NEW RUN")
	var ticket := c.issue_temporary_request(c.temporary_context(),"handling","prime_v3_short_wand","draw","cancel_before_dispatch")
	check(ticket.success and c.cancel_temporary_request(ticket.request).success and not c.execute_temporary_request(ticket.request).success,"Canceled unexecuted request never reaches source")
	check(s.configure_player_nac_automation({"profile":"Aggressive"}).success,"Original configuration mutation")
	var prepared: Dictionary = a._service.checkpoint(s,"downtime")
	check(prepared.get("state") == "prepared_not_saved","One pending original boundary")
	var view := c.minimal_view()
	var request := c.prepare_minimal_snapshot(view.pending_operation,view.revision)
	check(request.success and c.prepare_minimal_snapshot(view.pending_operation,view.revision).text == request.text,"Exact repeated preparation retains original bytes")
	check(not c.prepare_minimal_snapshot(view.pending_operation,view.revision+1).success and not c.simulate_minimal_acknowledgement(request.text+" ").success,"Wrong revision and changed readback rejected")
	check(not a._service.publish_prepared().success and not a._service.reconcile().success,"Legacy publication/reconciliation are not available to the dormant owner")
	s.configure_player_nac_automation({"profile":"Guardian"})
	check(not c.simulate_minimal_unknown_outcome().success and not c.simulate_minimal_acknowledgement(request.text).success,"Unattempted stale capture cannot gain retrospective publication authority")
	check(c.cancel_minimal_snapshot().success and c.minimal_view().body_json == original_body,"Known-unattempted cancellation adopts no new snapshot")
	check(not c.execute_temporary_request(ticket.request).success,"Cancellation closes original callbacks")
	c.close_minimal_prototype()
	var identity := CharacterPersistenceCoordinator.new(null)
	check(identity.admit_minimal_snapshot_v3(text,source,profile,scope,root.path_join("identity_"+scope)).success,"Fresh identity-rejection fixture")
	if identity._minimal_owner != null:
		a = identity._minimal_owner
		var issued := identity.issue_temporary_request(identity.temporary_context(),"handling","prime_v3_short_wand","draw","changed_identity")
		var run: String = a._service.run_id
		a._service.run_id = "changed_run"
		check(not identity.execute_temporary_request(issued.request).success,"Changed actual admitted run closes ownership before source")
		a._service.run_id = run
		check(not identity.execute_temporary_request(issued.request).success,"Restoring values cannot resurrect retired authority")
		identity.close_minimal_prototype()

func approve(value: Dictionary) -> Dictionary:
	return {"confirmed":true,"binding":Codec.V6.digest(value)}

func historical() -> void:
	var h := H.new(); h.root = root.path_join("original_history")
	var f := h.make_history("dev_normal",Credit.BASELINE,2,"source")
	check(f.get("success",false),"Actual historical V2 source")
	if not f.get("success",false): return
	var converted := Convert.convert(f.records,"dev_normal")
	check(converted.success and converted.comparison.success,"Original history fully validated independently")
	if not converted.success: return
	var source: CombatCharacterDefinitionResource = PlayableCharacterAdmission.prepare_starter(&"vaelis_thorn","dev_normal",Credit.BASELINE).source
	native_credit(converted.record,source)
	# Existing historical grant goes through the original coordinator in the
	# ORIGINAL disposable control store; the prototype writes no storage.
	var grant := Credit.prepare(f.payload,approve)
	check(grant.success,"Original fixed historical grant contract")
	if not grant.success: return
	var proposal := CharacterPersistenceCoordinator.prepare(grant.payload,grant.payload.settlements,grant.transaction_id,f.payload.generation,f.payload.secured_checkpoints)
	var verifier := func(_op: String,binding: String): return {"authorized":true,"binding":binding,"lineage":grant.payload.lineage}
	check(CharacterPersistenceCoordinator.new(f.storage).commit(proposal.prepared,source,f.profile,PlayableCharacterAdmission.RULES,verifier).success,"Original disposable fixed grant publication")
	var rows := CharacterSaveStorage.history_records(f.storage.inspect_profile(f.profile))
	var credited := Convert.convert(rows,"dev_normal")
	check(credited.success and credited.comparison.success,"Independently verified historical V5 credit proof")
	if not credited.success: return
	var c := admit(credited.record,source,"all_five")
	if c._minimal_owner == null: return
	var a: RefCounted = c._minimal_owner; var s: ArenaCombatSession = a._session
	var q := Q.new(); var control := q.start(f.storage,"dev_normal",null,credited.record,true)
	check(control.success and c.simulate_minimal_automatic_checkpoints(true).success,"Both source and dormant credited admissions")
	if not control.success: c.close_minimal_prototype(); return
	for spec: Array in [["end",6,3000,""],["wis",10,3000,""],["dex",9,3000,"dt"]]: purchase(s,control.session,spec)
	var helper := P.new(); var original := P.new()
	check(s.request_next_wave().success and control.session.request_next_wave().success,"Original post-purchase future wave")
	helper._defeat_wave(s); original._defeat_wave(control.session)
	check(s.collect_all_ground_loot().success and control.session.collect_all_ground_loot().success,"Original post-purchase awards/loot")
	purchase(s,control.session,["end",7,3000,""])
	check(s.request_next_wave().success and control.session.request_next_wave().success,"Future END8/WIS11 source growth")
	helper._defeat_wave(s); original._defeat_wave(control.session)
	check(s.collect_all_ground_loot().success and control.session.collect_all_ground_loot().success,"Further real progression")
	for spec: Array in [["str",9,3000,""],["spd",11,5000,""]]: purchase(s,control.session,spec)
	compare(c,control,"five_attributes_credit_growth")
	var b := body(c)
	for attr: String in ["str","dex","spd","wis","end"]: check(b.evidence.purchases.any(func(row): return row.purchase_kind == "attribute" and row.target_id == attr),"Actual captured permanent "+attr)
	check(b.evidence.growth.any(func(row): return row.hpb == 2 and row.wisdom == 11),"Source-valued chronological END/HPB/WIS retained")
	check(not c.prepare_minimal_fixed_credit(approve).get("payload",{}).is_empty(),"Existing credited character returns original no-op, not another grant")
	var before := s.get_state_snapshot()
	check(not s.request_character_advancement(&"attribute",&"end","46h_end7",{"expected_current_value":8,"expected_cost":3000}).success and s.get_state_snapshot() == before,"Original prior purchase request rejected, no second deduction")
	var old_context: RefCounted = c.temporary_context()
	var old_request := c.issue_temporary_request(old_context,"handling","prime_v3_short_wand","stow","old_run_callback")
	check(old_request.success,"Actual old-run issued callback")
	check(not c.prepare_minimal_new_run(1,Callable()).success,"Unfinished run requires explicit confirmation")
	var control_head: Dictionary = control.service.records.back()
	control = q.start(f.storage,"dev_normal",null,control_head,true)
	check(control.success,"Original control reload pins exact committed abandon authorization")
	var original_auth: Dictionary = control.session.get_abandon_run_authorization()
	check(original_auth.success,"Original control authorizes its exact committed head")
	PlayableCharacterPersistence.test_run_id = "run_45q_new"
	var new_run_started := Time.get_ticks_usec()
	var started := c.prepare_minimal_new_run(1,approve)
	measures.append({"fixture":"new_run_full_admission_prepare","total_us":Time.get_ticks_usec()-new_run_started})
	check(started.success,"Original NEW RUN authority and atomic pending preparation: "+str(started))
	if started.success and original_auth.success:
		var factory := func(_store: CharacterSaveStorage,_mode: String,_parent: Dictionary): return PlayerControl.new()
		var next := q.start(f.storage,"dev_normal",1,control_head,true,true,original_auth.checkpoint,factory)
		check(next.success,"Independent original NEW RUN: "+str(next.get("reason","")))
		if next.success:
			next.movement = next.service.player._movement
			a = c._minimal_owner; s = a._session
			check(not c.execute_temporary_request(old_request.request).success,"Old context never acquires new-run authority")
			compare(c,next,"new_run_x1")
			check(body(c).current.run_history.size() == 2 and body(c).current.run_reward_policy.runs.back().xp_multiplier == 1,"Original two run IDs and locked historical/new policy")
			helper._defeat_wave(s); original._defeat_wave(next.session)
			check(s.collect_all_ground_loot().success and next.session.collect_all_ground_loot().success,"Genuine next-run rewards remain exactly once")
			compare(c,next,"new_run_source_rewards")
			check(q.failures.is_empty() and next.service.errors.is_empty(),"Original NEW RUN observer checks")
			next.service.player.free()
	c.close_minimal_prototype()
	check(h.failures.is_empty() and h.helper._failures.is_empty() and helper._failures.is_empty() and original._failures.is_empty(),"Original historical combat assertions retained")

func purchase(s: ArenaCombatSession, control: ArenaCombatSession, spec: Array) -> void:
	var selection := {"expected_current_value":spec[1],"expected_cost":spec[2]}
	if spec[3] != "": selection["allocation"] = spec[3]
	var result := s.request_character_advancement(&"attribute",StringName(spec[0]),"46h_"+spec[0]+str(spec[1]),selection)
	check(result.success,"Original dormant purchase "+str(spec)+": "+str(result))
	check(control.request_character_advancement(&"attribute",StringName(spec[0]),"46h_"+spec[0]+str(spec[1]),selection).success,"Independent original purchase "+str(spec))

func native_credit(r: Dictionary, source: CombatCharacterDefinitionResource) -> void:
	var c := admit(r,source,"native_credit")
	if c._minimal_owner == null: return
	var a: RefCounted = c._minimal_owner
	var saved: Dictionary = a._session.get_state_snapshot()
	check(not c.prepare_minimal_fixed_credit(Callable()).success and a._session.get_state_snapshot() == saved,"No confirmation, no fixed credit effect")
	var expected := Credit.prepare(Codec.projection(body(c)),approve)
	check(expected.success,"Independent original Credit.prepare computes the exact allowed fact")
	var granted := c.prepare_minimal_fixed_credit(approve)
	check(granted.get("state") == "prepared_not_saved","Native confirmed credit is only an immutable nondurable proposal: "+str(granted))
	if c.minimal_view().pending_text.is_empty(): c.close_minimal_prototype(); return
	var pending := Codec.decode(c.minimal_view().pending_text,source,Credit.PROFILE,"dev_normal")
	check(pending.success and pending.snapshot.copy().evidence.credit == expected.payload.expc_credits,"Original exact target/grant/head/amount bindings retained")
	check(a._session.get_actor_state(&"player").progression.expc == expected.payload.xp.unspent and a._session.get_actor_state(&"player").progression.expm == expected.payload.xp.earned,"Shared original grant effect changes EXPC only")
	var after: Dictionary = a._session.get_state_snapshot()
	check(not c.prepare_minimal_fixed_credit(approve).success and a._session.get_state_snapshot() == after,"Pending credit cannot execute twice")
	ack(c)
	var once: Dictionary = a._session.get_state_snapshot()
	check(c.prepare_minimal_fixed_credit(approve).get("no_op",false) and a._session.get_state_snapshot() == once,"Once-only grant after simulated ack")
	var quote := Native.quote(r,source,null,Codec.V6)
	var full := Native.build(r,source,quote.quote,Codec.V6.digest(r.current.recovery),Codec.V6) if quote.success else quote
	check(full.success and full.record.current.xp == body(c).current.xp,"Independent original native V6 credit accounting matches without predecessor reconstruction in v3")
	measures.append({"fixture":"native_fixed_credit","metrics":c.minimal_view().metrics})
	var encoded := Codec.encode(body(c),source,Credit.PROFILE,"dev_normal")
	c.close_minimal_prototype()
	var restart := CharacterPersistenceCoordinator.new(null)
	check(restart.admit_minimal_snapshot_v3(encoded.text,source,Credit.PROFILE,"dev_normal",root.path_join("native_restart")).success,"Cold credited v3 admission")
	if restart._minimal_owner != null:
		check(restart.prepare_minimal_fixed_credit(approve).get("no_op",false),"Cold restart cannot duplicate fixed grant")
		restart.close_minimal_prototype()

func stress_and_unsupported() -> void:
	var w := W.new()
	var cache := OS.get_cache_dir().path_join("itank-storage-tests/")
	var text := w.read_fixture(cache.path_join("compact45m_45n_session_20261117e/233.json"))
	if not text.is_empty():
		var source: CombatCharacterDefinitionResource = w.trusted(text).source
		var original := Codec.V6.decode(text,source)
		check(original.success,"Original frozen 233-generation character independently validates")
		if original.success:
			var incomplete: Dictionary = G.new().pack(original.record)
			check(Codec.encode(incomplete,source,Credit.PROFILE,"dev_normal").get("reason") == "snapshot_v3_item_conservation","233-generation source missing use IDs remains explicitly unsupported")
	else: check(false,"Required named disposable 233-generation fixture")
	text = w.current_from_cache("compact45s_bench_25204_2215533/inventory")
	if not text.is_empty():
		var source: CombatCharacterDefinitionResource = w.trusted(text).source
		var original := Codec.V6.decode(text,source)
		check(original.success,"Original 1005-item stress source validates")
		if original.success:
			var c := admit(original.record,source,"stress_1005")
			if c._minimal_owner != null:
				var a: RefCounted = c._minimal_owner
				a._session.configure_player_nac_automation({"profile":"Aggressive"})
				var prepared: Dictionary = a._service.checkpoint(a._session,body(c).current.recovery.phase)
				check(prepared.get("state") == "prepared_not_saved","Stress preparation uses original source boundary")
				if not c.minimal_view().pending_text.is_empty():
					var decoded := Codec.decode(c.minimal_view().pending_text,source,a._service.profile_id,a._service.mode)
					check(decoded.success and decoded.snapshot.copy().current.items.size() == 1005,"Cold independent stress candidate exact inventory")
					measures.append({"fixture":"separate_stress_1005","metrics":c.minimal_view().metrics,"admission_cold_us":c.minimal_view().admission_cold_us})
					ack(c)
				c.close_minimal_prototype()
	else: check(false,"Required named disposable stress fixture")
	check(w.failures.is_empty(),"Frozen-fixture isolation checks")

func cold_process(_old_coordinator: CharacterPersistenceCoordinator, text: String, source: CombatCharacterDefinitionResource, scope: String) -> void:
	var path := root.path_join("child_"+scope)
	DirAccess.make_dir_recursive_absolute(path)
	var file := FileAccess.open(path.path_join("record.json"),FileAccess.WRITE); file.store_string(text); file.close()
	var output: Array = []
	var code := OS.execute(OS.get_executable_path(),["--headless","--path",ProjectSettings.globalize_path("res://"),"--script","res://tests/minimal_v3_transactions_cold_process.gd","--",path,scope,Codec.V6.digest(source.to_dictionary())],output,true)
	check(code == 0 and str(output).contains("46H_COLD_PASS"),"Actual fresh-process v3 aggregate with exact irreversible IDs: "+str(output))
