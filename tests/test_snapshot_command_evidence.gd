extends RefCounted
const V1 = preload("res://scripts/rewards/minimal_character_snapshot.gd")
const V2 = preload("res://scripts/rewards/minimal_character_snapshot_v2.gd")
const Evidence = preload("res://scripts/rewards/snapshot_command_evidence.gd")
const Q = preload("res://tests/test_compact_v6_gameplay_candidate.gd")
const B = preload("res://tests/test_minimal_character_snapshot.gd")
const P = preload("res://tests/test_playable_vaelis_persistence.gd")
var failures: Array[String] = []
var assertions := 0
var root := ""

func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok: failures.append(label)

func build(f: Dictionary) -> Dictionary:
	var base: Dictionary = B.new().make(f.service.records.back(),f.service.source)
	var extracted := Evidence.from_session(f.session,base)
	check(extracted.success,"Extract real original source facts: "+str(extracted.get("reason","")))
	if not extracted.success: return extracted
	base["command_evidence"] = extracted.section
	base.lifetime_ids = V2.ids(base)
	return {"success":true,"body":base}

func run() -> Array[String]:
	var prior: Array = [PlayableCharacterPersistence.test_storage,PlayableCharacterPersistence.test_run_id,PlayableCharacterPersistence.test_nonpersistent]
	PlayableCharacterPersistence.test_nonpersistent = false
	root = OS.get_cache_dir().path_join("itank-storage-tests/commands46d_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()])
	for scope: String in ["normal","dev_normal"]: scenario(scope)
	active_scenario()
	PlayableCharacterPersistence.test_storage = prior[0]; PlayableCharacterPersistence.test_run_id = prior[1]; PlayableCharacterPersistence.test_nonpersistent = prior[2]
	print("46D command evidence: %d assertions; failures %s" % [assertions,str(failures)])
	return failures

func scenario(scope: String) -> void:
	var q := Q.new()
	var f := q.start(CharacterSaveStorage.new(root.path_join(scope)),scope,1 if scope=="normal" else 10)
	check(f.success,"Original fresh source "+scope)
	if not f.success: return
	var first := build(f)
	if not first.success: return
	check(V2.encode(first.body,f.service.source,f.service.profile_id,scope).success,"Initial v2 snapshot")
	var s: ArenaCombatSession = f.session
	var helper := P.new(); helper._defeat_wave(s)
	check(helper._failures.is_empty(),"Original defeat/XP source, not fabricated balance")
	var origin := s.simulation.record_reward_event(&"reward_source_item_fixture",&"player",&"player",{})
	for ref: String in ["health_potion","prime_v3_potion_12","prime_v3_metal_buckler"]:
		var item := {"definition_id":ref,"quantity":3 if ref=="health_potion" else 1,"display_name":ref,"item_kind":"potion" if not PrimeV3InventoryCatalog.get_verified_consumable(ref).is_empty() else "equipment","source_ref":"PRIME-V3 pp.120,137; disposable original acquisition fixture"}
		check(s.simulation.create_ground_loot_item("46d_item_"+ref,item,s.get_actor_state(&"player").position_microfeet,&"player",origin.event_id).success,"Original ground item creation")
	check(s.collect_all_ground_loot().success,"Original item acquisition/receipts")
	check(s.request_player_weapon_handling(&"prime_v3_short_wand","stow","46d_stow").success,"Original legal stow")
	# Disposable wounded setup; the heal and consumption themselves are original
	# source transactions with original dice, item selectors and request IDs.
	for i in range(3):
		s.get_actor_state(&"player").current_hpc = 1
		var result := s.request_player_inventory_consumable_use(&"health_potion","46d_use_"+str(i))
		check(result.success and result.get("persistence",{}).get("success",false),"Original actual potion use "+str(i))
	s.get_actor_state(&"player").resources["mana"] = 0
	check(s.request_player_inventory_consumable_use(&"prime_v3_potion_12","46d_mana").success,"Original three-d6 Mana potion and separate resource effect")
	check(s.request_player_inventory_unequip(&"prime_v3_short_wand","46d_unequip").success,"Original unequip")
	check(s.request_player_inventory_equip(&"prime_v3_short_wand","46d_equip").success,"Original equip")
	check(s.request_player_inventory_equip(&"prime_v3_metal_buckler","46d_shield").success,"Original shield legality")
	var duplicate_before := s.get_state_snapshot()
	check(not s.request_player_inventory_consumable_use(&"health_potion","46d_use_0").success,"Original identical accepted request cannot consume or roll again")
	check(not s.request_player_inventory_unequip(&"prime_v3_short_wand","46d_use_0").success,"Original shared request namespace rejects conflicting cross-kind replay")
	check(s.get_state_snapshot()==duplicate_before,"Rejected original replay preserves all simulation/RNG")
	for i in range(11):
		check(s.request_player_inventory_unequip(&"prime_v3_short_wand","46d_off_"+str(i)).success,"Original later unequip")
		check(s.request_player_inventory_equip(&"prime_v3_short_wand","46d_on_"+str(i)).success,"Original later equip")
	var found := build(f)
	if not found.success: return
	check(not Evidence.from_session(s,first.body).success,"A changed original committed head cannot supply evidence for an older checkpoint")
	var body: Dictionary = found.body
	var before := s.get_state_snapshot()
	var started := Time.get_ticks_usec()
	var encoded := V2.encode(body,f.service.source,f.service.profile_id,scope)
	var encode_us := Time.get_ticks_usec()-started
	check(encoded.success,"Full independent v2 command replay: "+str(encoded.get("reason",""))+str(encoded.get("details",{})))
	if not encoded.success: return
	check(V2.validate_extension(first.body,body,f.service.source,f.service.profile_id,scope).success,"Original immutable v2 prefix extends without ancestry snapshots")
	check(V2.validate_extension(body,body,f.service.source,f.service.profile_id,scope).get("exact_retry",false),"Exact identical record retry")
	check(s.get_state_snapshot()==before,"Cold validator never changes original simulation/events/RNG")
	check(encoded.snapshot.projection()==V1.V6._projection(f.service.records.back()),"Exact original independently validated current character/evidence")
	check(body.recent_journal.size()==20 and body.operations.size()>20,"Actual source checkpoints evict only recent journal")
	var old: Dictionary = body.command_evidence.facts.filter(func(row): return row.request_id=="46d_use_0")[0]
	check(encoded.snapshot.command_request(old.request_id,V2.command_binding(body,old)).get("reason")=="duplicate_command","Exact early command replay rejected after journal eviction")
	check(encoded.snapshot.command_request(old.request_id,"f".repeat(64)).reason=="conflicting_command_binding","Same original ID with changed binding rejected")
	check(encoded.snapshot.command_request("genuinely_new", "0".repeat(64)).success,"Unseen ID membership is distinct from authorization")
	var zeros: Array = body.current.recovery.ledger.profile_ownership.items.filter(func(item): return item.definition_id=="health_potion")
	check(zeros.size()==1 and zeros[0].quantity==0 and not body.current.items.any(func(item): return item.definition_id=="health_potion"),"Explicit terminal zero-quantity ownership survives three uses")
	var decoded := V2.decode_bytes(encoded.text.to_utf8_buffer(),f.service.source,f.service.profile_id,scope)
	check(decoded.success and decoded.snapshot.copy()==body,"Canonical bytes and cold command proof round-trip")
	var escaped: Dictionary = decoded.snapshot.copy(); escaped.command_evidence.facts.clear()
	check(decoded.snapshot.copy()==body,"No mutable evidence aliases escape the validated record")
	check(V2.encode(decoded.snapshot.copy(),f.service.source,f.service.profile_id,scope).text==encoded.text,"Exact canonical reencoding")
	check(not V1.decode(encoded.text,f.service.source,f.service.profile_id,scope).success,"Old v1 reader rejects successor")
	var base: Dictionary = body.duplicate(true); base.erase("command_evidence"); base.lifetime_ids=V1.V6._ids(base)
	var legacy := V1.encode(base,f.service.source,f.service.profile_id,scope)
	var inspected := V2.decode(legacy.text,f.service.source,f.service.profile_id,scope)
	check(legacy.success and inspected.success and inspected.format_version==1 and inspected.command_coverage=="unknown_read_only","V1 inspection retains original semantics and unknown command coverage")
	check(inspected.snapshot.copy()==base,"V1 bytes were not migrated or reinterpreted")
	check(not V2.encode(base,f.service.source,f.service.profile_id,scope).success,"No silent v1 upgrade")
	var restart := q.start(CharacterSaveStorage.new(root.path_join(scope)),scope,null,{},false)
	check(restart.success,"Original legacy cold resume control")
	if restart.success:
		check(not Evidence.from_session(restart.session,base).success,"Unavailable old source command IDs cannot be fabricated on resumed legacy admission")
	if scope=="dev_normal":
		rejections(body,f.service.source,f.service.profile_id,scope)
		cold_process(encoded.text,body,f.service.source)
	print("46D_METRICS "+JSON.stringify({"mode":scope,"bytes":encoded.text.to_utf8_buffer().size(),"facts":body.command_evidence.facts.size(),"commands":body.lifetime_ids.filter(func(row): return row.scope=="item_command").size(),"encode_us":encode_us,"native_live":OS.get_static_memory_usage(),"native_peak":OS.get_static_memory_peak_usage()}))
	check(q.failures.is_empty() and f.service.errors.is_empty(),"Original independent observer keeps all assertions")

func active_scenario() -> void:
	var q := Q.new()
	var f := q.start(CharacterSaveStorage.new(root.path_join("active")),"normal",1)
	check(f.success,"Fresh original active-use fixture")
	if not f.success: return
	var s: ArenaCombatSession = f.session
	var helper := P.new(); helper._defeat_wave(s)
	var origin := s.simulation.record_reward_event(&"reward_source_item_fixture",&"player",&"player",{})
	for ref: String in ["health_potion"]:
		var item := {"definition_id":ref,"quantity":2 if ref=="health_potion" else 1,"display_name":ref,"item_kind":"potion" if ref=="health_potion" else "equipment","source_ref":"PRIME-V3 pp.20,120,137; disposable source fixture"}
		check(s.simulation.create_ground_loot_item("46d_active_"+ref,item,s.get_actor_state(&"player").position_microfeet,&"player",origin.event_id).success,"Real active fixture acquisition")
	check(s.collect_all_ground_loot().success,"Actual active-use ownership")
	check(not s.request_player_weapon_handling(&"prime_v3_short_wand","hold_one","46d_illegal_hold").success,"Original rejects inapplicable one-hand hold without accepted evidence")
	check(s.request_player_weapon_handling(&"prime_v3_short_wand","stow","46d_active_stow").success,"Actual stow before timed draw")
	check(s.request_next_wave().success,"Original NEXT WAVE keeps source identity")
	s.set_opponent_behavior_enabled(false)
	if s.get_encounter_state()==ArenaCombatSession.ENCOUNTER_READY: check(s.start_encounter().success,"Original active wave starts")
	else: check(s.get_encounter_state()==ArenaCombatSession.ENCOUNTER_RUNNING,"NEXT WAVE already started original active combat")
	var generation: int = f.service.generation
	check(s.request_player_weapon_handling(&"prime_v3_short_wand","draw","46d_draw").success,"Original one-Act draw accepted")
	s.advance_by(6000000)
	check(s.request_player_weapon_handling(&"prime_v3_short_wand","stow","46d_active_free_hand").success,"Original active free-hand transition")
	s.get_actor_state(&"player").current_hpc = 1
	check(s.request_player_inventory_consumable_use(&"health_potion","46d_active_use").success,"Original two-Act potion request")
	var pending_base: Dictionary = B.new().make(f.service.records.back(),f.service.source)
	check(not Evidence.from_session(s,pending_base).success,"Cannot label an old committed checkpoint as current while a source action is pending")
	s.advance_by(11000000)
	check(f.service.generation==generation,"Multiple genuine item operations occur between checkpoints")
	check(s.get_actor_state(&"player").inventory_quantities.health_potion==1,"Original active resolution consumes once")
	var action := s.request_player_inventory_consumable_use(&"health_potion","46d_interrupted")
	check(action.success,"Original interrupted potion request accepted")
	if action.success:
		s.simulation.schedule_interruption(action.action_instance_id,s.simulation.clock.get_elapsed_us(),&"player","disposable_test_interruption")
		s.advance_by(1)
	helper._defeat_wave(s)
	check(helper._failures.is_empty(),"Original active wave finishes")
	var found := build(f)
	if not found.success: return
	var before := s.get_state_snapshot()
	var result := V2.encode(found.body,f.service.source,f.service.profile_id,"normal")
	check(result.success,"Active draw/use/handling/interrupt source proof: "+str(result))
	check(s.get_state_snapshot()==before,"Active cold proof leaves original gameplay/RNG unchanged")
	if result.success:
		for id: String in ["46d_draw","46d_active_free_hand","46d_active_use","46d_interrupted"]:
			check(not result.snapshot.command_request(id,"0".repeat(64)).success,"Exact accepted active ID retained: "+id)
		var bad: Dictionary = found.body.duplicate(true)
		for fact: Dictionary in bad.command_evidence.facts:
			if fact.request_id=="46d_draw": fact.action.due_us-=1
		bad.lifetime_ids=V2.ids(bad)
		check(not V2.validate(bad,f.service.source,f.service.profile_id,"normal").success,"Changed original timed-draw schedule cannot pass by rehashing")
		cold_process(result.text,found.body,f.service.source,"46d_interrupted")

func rejections(body: Dictionary, source: CombatCharacterDefinitionResource, profile: String, scope: String) -> void:
	var scenarios: Array = []
	var uses: Array = []
	for i in range(body.command_evidence.facts.size()):
		if body.command_evidence.facts[i].event_type=="downtime_consumable_used": uses.append(i)
	var b: Dictionary = body.duplicate(true); b.command_evidence.facts.remove_at(uses[0]); scenarios.append(["missing use",b])
	b=body.duplicate(true); b.command_evidence.facts[uses[1]].request_id=b.command_evidence.facts[uses[0]].request_id; scenarios.append(["duplicate request",b])
	b=body.duplicate(true); b.command_evidence.facts[uses[0]].payload.rolls[0]=11; scenarios.append(["forged die",b])
	b=body.duplicate(true); b.command_evidence.facts[uses[0]].payload.quantity_after+=1; scenarios.append(["forged quantity",b])
	b=body.duplicate(true); b.command_evidence.facts[uses[0]].payload.value_after+=1; scenarios.append(["forged effect",b])
	b=body.duplicate(true); b.command_evidence.facts[uses[0]].payload.ownership_selection[0].instance_id="unknown"; scenarios.append(["forged ownership",b])
	b=body.duplicate(true); b.command_evidence.facts.reverse(); scenarios.append(["reordered evidence",b])
	b=body.duplicate(true); b.command_evidence.coverage="assume_legacy_untrained"; scenarios.append(["unknown prefix policy",b])
	b=body.duplicate(true); b.command_evidence.facts[uses[0]].payload.rolls=null; scenarios.append(["malformed payload",b])
	b=body.duplicate(true); b.command_evidence.facts[uses[0]].progression_index=100000; scenarios.append(["false growth prefix",b])
	b=body.duplicate(true); b.command_evidence.facts.append(b.command_evidence.facts[uses[0]].duplicate(true)); b.command_evidence.facts.back().request_id="different_wrapper"; scenarios.append(["reused event in new request wrapper",b])
	var equipment: int = -1
	for i in range(body.command_evidence.facts.size()):
		if body.command_evidence.facts[i].event_type=="downtime_equipment_changed": equipment=i; break
	if equipment>=0:
		b=body.duplicate(true); b.command_evidence.facts[equipment].payload.hands_after={"left":"unowned","right":""}; scenarios.append(["illegal equipment hand effect",b])
		b=body.duplicate(true); b.command_evidence.facts[equipment].payload.equipment_after=null; scenarios.append(["malformed equipment refs",b])
	for pair: Array in scenarios:
		pair[1].lifetime_ids=V2.ids(pair[1]) # Rehashing cannot replace semantic proof.
		check(not V2.validate(pair[1],source,profile,scope).success,"Cold rejects "+pair[0])
	b=body.duplicate(true); b.lifetime_ids=b.lifetime_ids.filter(func(row): return row.scope!="item_command"); check(not V2.validate(b,source,profile,scope).success,"Missing exact lifetime command membership")
	b=body.duplicate(true); b.command_evidence.facts.resize(Evidence.MAX_FACTS+1); check(not V2.validate(b,source,profile,scope).success,"Explicit finite command-fact limit")
	b=body.duplicate(true); b.command_evidence["verified"]=true; check(not V2.validate(b,source,profile,scope).success,"Caller verification flag cannot replace the supported-prefix contract")
	# A locally fabricated but internally consistent narrative is not source
	# authorization. Comparing the admitted prefix MUST reject rebinding its ID.
	b=body.duplicate(true)
	b.sequence+=1; b.current.generation+=1
	b.operations.append({"id":"later_checkpoint","request_digest":"0".repeat(64)}); b.last_operation_id="later_checkpoint";b.recent_journal=b.operations.slice(b.operations.size()-20)
	var first: Dictionary = b.command_evidence.facts.filter(func(row): return row.event_type=="weapon_handling_changed")[0]
	first.request_id="rebound_original_id";first.payload.request_id=first.request_id;b.lifetime_ids=V2.ids(b)
	check(V2.validate(b,source,profile,scope).success,"Cold local semantics alone do not authenticate an opaque original ID")
	check(not V2.validate_extension(body,b,source,profile,scope).success,"Previously admitted original command bindings cannot be rewritten even with new checksum/operation")
	var text: String = V2.encode(body,source,profile,scope).text
	check(not V2.decode(text.left(text.length()-1),source,profile,scope).success,"Truncated envelope")
	check(not V2.decode(text.replace('"version":2','"version":3'),source,profile,scope).success,"Unsupported explicit version")
	check(not V2.decode(text.replace('"reader_version":2','"reader_version":1'),source,profile,scope).success,"V2 cannot claim older reader compatibility")
	check(not V2.decode(text.replace('"version":2','"version":2,"version":2'),source,profile,scope).success,"Duplicate JSON keys")
	check(not V2.decode(text.replace('"sha256":"','"sha256":"0'),source,profile,scope).success,"Damaged checksum")

func cold_process(text: String, body: Dictionary, source: CombatCharacterDefinitionResource, request_id: String = "46d_use_0") -> void:
	DirAccess.make_dir_recursive_absolute(root)
	var file := FileAccess.open(root.path_join("cold_v2.json"),FileAccess.WRITE); file.store_string(text); file.close()
	var output: Array=[]
	var code := OS.execute(OS.get_executable_path(),["--headless","--path",ProjectSettings.globalize_path("res://"),"--script","res://tests/minimal_snapshot_commands_cold_process.gd","--",root,body.current.character_id,body.current.profile_namespace,body.current.lineage.baseline_digest,text.sha256_text(),request_id],output,true)
	check(code==0 and str(output).contains("46D_COLD_PROCESS_PASS"),"Fresh process independently checks original full command IDs: "+str(output))
