extends RefCounted
const Codec = preload("res://scripts/rewards/minimal_character_snapshot_v3.gd")
const V1 = Codec.V1
const V2 = preload("res://scripts/rewards/minimal_character_snapshot_v2.gd")
const V6 = Codec.V6
const Q = preload("res://tests/test_compact_v6_gameplay_candidate.gd")
const H = preload("res://tests/test_historical_vaelis_admission.gd")
const Convert = preload("res://scripts/rewards/legacy_to_compact_v6_prototype.gd")
const Native = preload("res://scripts/rewards/compact_v6_fixed_credit.gd")
const W = preload("res://tests/test_compact_v6_snapshot_package.gd")
var failures: Array[String] = []
var assertions := 0
var metrics: Array = []
var root := ""
var sample := {}

func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok: failures.append(label)

# Test-only projection of independently validated source fixtures. Not migration
# or gameplay authority. Debits MUST come from actual original resolved events.
func pack(r: Dictionary, debits: Array = [], known_zeros: Array = []) -> Dictionary:
	var c: Dictionary = r.current.duplicate(true)
	c.items = c.recovery.ledger.profile_ownership.items.duplicate(true)
	for item: Dictionary in known_zeros:
		check(item.quantity == 0,"Carried terminal fact is an actual previously recorded zero, never an inferred quantity")
		if not c.items.any(func(current): return current.instance_id == item.instance_id): c.items.append(item.duplicate(true))
	var ledger := {}
	for key: String in Codec.LEDGER+["xp_multiplier","expc_credit_total"]:
		if c.recovery.ledger.has(key): ledger[key] = c.recovery.ledger[key]
	c.recovery.ledger = ledger
	if c.permanent.has("development"):
		var kept: Array = []
		var preferences := {}
		for command: Dictionary in c.permanent.development.commands:
			if command.kind == "preferences": preferences = command
			else: kept.append(command)
		if not preferences.is_empty(): kept.append(preferences)
		c.permanent.development.commands = kept
		c.recovery.player.development = c.permanent.development.duplicate(true)
	var e: Dictionary = r.evidence.duplicate(true); e.erase("credit_predecessor"); e["item_debits"] = debits.duplicate(true)
	var journal: Array = []
	for i in range(maxi(0,r.operations.size()-20),r.operations.size()):
		journal.append({"sequence":i+1,"id":r.operations[i].id,"request_digest":r.operations[i].request_digest})
	return Codec.assemble(c,e,r.head.epoch,journal.back().id,journal,PlayableCharacterAdmission.prepare_starter(&"vaelis_thorn",c.profile_namespace,c.lineage.baseline_digest).source)

func debits(session: ArenaCombatSession) -> Array:
	var rows: Array = []
	for event: CombatEvent in session.get_resolved_events():
		if event.source_actor_id != &"player" or event.event_type not in [&"downtime_consumable_used",&"consumable_healing_resolved",&"consumable_mana_resolved"]: continue
		var d: Dictionary = event.payload
		var id: String = d.get("request_id","")
		if id.is_empty():
			var action: CombatActionInstance = session.simulation.get_action(d.action_instance_id)
			check(action != null and action.actor_id == &"player" and action.status == CombatActionInstance.STATUS_COMPLETED and action.final_event_id == event.parent_event_id,"Actual accepted action and terminal causality supply original consumption ID")
			if action == null: continue
			id = action.request_id
		rows.append({"run_id":session._playable_persistence.run_id,"request_id":id,"event_id":event.event_id,"kind":"consume","definition_id":d.inventory_id,"selection":d.ownership_selection.duplicate(true)})
	return V1.Contract._normalize_json_numbers(rows)

func exercise(label: String, r: Dictionary, source: CombatCharacterDefinitionResource, uses: Array = [], original_verifier: Callable = Callable(), known_zeros: Array = []) -> Dictionary:
	var old := V6.validate(r,source)
	check(old.success,"Independent existing V6 reference: "+label+": "+str(old.get("reason","")))
	if not old.success: return {}
	var b := pack(r,uses,known_zeros)
	var before := V6.digest(r); var source_before := V6.digest(source.to_dictionary())
	var mem := OS.get_static_memory_usage()
	var start := Time.get_ticks_usec()
	var validated := Codec.validate(b,source,b.current.character_id,b.current.profile_namespace)
	var validation_us := Time.get_ticks_usec()-start
	check(validated.success,"Cold v3 original semantic evidence: "+label+": "+str(validated.get("reason",""))+str(validated.get("details",{})))
	if not validated.success: return {}
	print("46G_CASE "+label+": cold PASS")
	var expected: Dictionary = V6._projection(r)
	for item: Dictionary in known_zeros:
		if not expected.recovery.ledger.profile_ownership.items.any(func(current): return current.instance_id == item.instance_id): expected.recovery.ledger.profile_ownership.items.append(item.duplicate(true))
	# Explicitly ignore ONLY replaced ledger mirrors and earlier temporary prefs.
	var expected_ledger := {}
	for key: String in Codec.LEDGER+["xp_multiplier","expc_credit_total","profile_ownership"]:
		if expected.recovery.ledger.has(key): expected_ledger[key] = expected.recovery.ledger[key]
	expected.recovery.ledger = expected_ledger
	if expected.permanent.has("development"):
		var prior_preferences: Array = expected.permanent.development.commands.filter(func(row): return row.kind == "preferences")
		expected.permanent.development.commands = expected.permanent.development.commands.filter(func(row): return row.kind != "preferences")
		if not prior_preferences.is_empty(): expected.permanent.development.commands.append(prior_preferences.back())
		expected.recovery.player.development = expected.permanent.development.duplicate(true)
	check(validated.snapshot.projection() == expected,"Every current source value and permanent evidence exact except explicitly omitted mirrors/temp history: "+label)
	check(b.evidence.order == r.evidence.order and b.evidence.growth == r.evidence.growth and b.evidence.purchases == r.evidence.purchases,"Original END/WIS/HD dice and permanent chronology retained exactly: "+label)
	if original_verifier.is_valid():
		var actual: Dictionary = original_verifier.get_object()._prior
		var original := CharacterProfileProjection.hydrate(actual,source,b.current.character_id,PlayableCharacterAdmission.RULES,original_verifier)
		check(original.success and original.actor_definition.to_dictionary() == old.actor.to_dictionary(),"Original source-authorized actor independent of v3: "+label+": "+str(original.get("reason","")))
	check(not b.has("operations") and not b.has("lifetime_ids") and not b.has("command_evidence") and not b.evidence.has("credit_predecessor"),"No lifetime checkpoints/temporary command transcript/duplicate index/predecessor snapshots")
	start = Time.get_ticks_usec(); var encoded := Codec.encode(b,source,b.current.character_id,b.current.profile_namespace); var encode_us := Time.get_ticks_usec()-start
	check(encoded.success,"Encode "+label)
	if not encoded.success: return {}
	start = Time.get_ticks_usec(); var decoded := Codec.decode_bytes(encoded.text.to_utf8_buffer(),source,b.current.character_id,b.current.profile_namespace); var decode_us := Time.get_ticks_usec()-start
	check(decoded.success and decoded.snapshot.copy() == b,"Byte codec and independent full cold roundtrip: "+label)
	check(Codec.encode(decoded.snapshot.copy(),source,b.current.character_id,b.current.profile_namespace).text == encoded.text,"Identical canonical bytes/hashes: "+label)
	var escaped: Dictionary = decoded.snapshot.copy(); escaped.current.items.clear()
	check(decoded.snapshot.copy() == b,"No mutable record dictionaries escape")
	check(V6.digest(r) == before and V6.digest(source.to_dictionary()) == source_before,"Source record/rules unchanged by codec")
	check(not V1.decode(encoded.text,source,b.current.character_id,b.current.profile_namespace).success and not V2.decode(encoded.text,source,b.current.character_id,b.current.profile_namespace).success,"Original readers reject v3 without reinterpretation")
	metrics.append({"fixture":label,"bytes":encoded.text.to_utf8_buffer().size(),"body_bytes":decoded.snapshot.json().to_utf8_buffer().size(),"old_operation_count":r.operations.size(),"recent":b.recent_journal.size(),"items":b.current.items.size(),"debits":uses.size(),"validate_us":validation_us,"encode_us":encode_us,"decode_us":decode_us,"net_native_live_bytes":OS.get_static_memory_usage()-mem,"native_process_peak":OS.get_static_memory_peak_usage()})
	return {"body":b,"text":encoded.text,"source":source,"snapshot":decoded.snapshot,"expected":expected}

func run() -> Array[String]:
	var prior: Array = [PlayableCharacterPersistence.test_storage,PlayableCharacterPersistence.test_run_id,PlayableCharacterPersistence.test_nonpersistent]
	PlayableCharacterPersistence.test_nonpersistent = false
	root = OS.get_cache_dir().path_join("itank-storage-tests/snapshot46g_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()])
	for scope: String in ["normal","dev_normal"]: scenario(scope)
	historical()
	frozen_rejection()
	if not sample.is_empty(): rejections(sample); cold_process(sample)
	PlayableCharacterPersistence.test_storage = prior[0]; PlayableCharacterPersistence.test_run_id = prior[1]; PlayableCharacterPersistence.test_nonpersistent = prior[2]
	print("46G_METRICS "+JSON.stringify({"fixtures":metrics,"scope":"native Windows debug cold codec; not save latency, Edge or release"}))
	print("46G compact snapshot v3: %d assertions; failures %s" % [assertions,str(failures)])
	return failures

func scenario(scope: String) -> void:
	var q := Q.new()
	var f := q.start(CharacterSaveStorage.new(root.path_join(scope)),scope,1 if scope == "normal" else 10)
	check(f.success,"Actual original fresh "+scope)
	if not f.success: return
	exercise(scope+"_fresh",f.service.records.back(),f.service.source,[],f.service._verify)
	var helper := H.new().helper; var s: ArenaCombatSession = f.session
	helper._defeat_wave(s)
	check(s.collect_all_ground_loot().success,"Real wave acquisitions")
	var cause := s.simulation.record_reward_event(&"reward_fixture_origin",&"player",&"player",{})
	for ref: String in ["health_potion","prime_v3_potion_12","prime_v3_metal_buckler"]:
		check(s.simulation.create_ground_loot_item("46g_"+ref,{"definition_id":ref,"quantity":2 if ref == "health_potion" else 1,"display_name":ref,"item_kind":"potion" if ref != "prime_v3_metal_buckler" else "equipment","source_ref":"Prime V3 pp.120,137; disposable source fixture"},s.get_actor_state(&"player").position_microfeet,&"player",cause.event_id).success,"Real source acquisition")
	check(s.collect_all_ground_loot().success and s.request_player_weapon_handling(&"prime_v3_short_wand","stow","46g_stow").success,"Original collection and legal hands")
	for i in range(2):
		s.get_actor_state(&"player").current_hpc = 1 # Disposable injury only, not a fabricated use.
		check(s.request_player_inventory_consumable_use(&"health_potion","same_use_"+str(i)).success,"Real irreversible potion quantity debit")
	s.get_actor_state(&"player").resources.mana = 0
	check(s.request_player_inventory_consumable_use(&"prime_v3_potion_12","46g_mana").success,"Real original Mana potion")
	for i in range(12):
		check(s.request_player_inventory_unequip(&"prime_v3_short_wand","46g_off_"+str(i)).success and s.request_player_inventory_equip(&"prime_v3_short_wand","46g_on_"+str(i)).success,"Actual equip cycles do not require lifetime v3 rows")
	check(s.request_player_inventory_equip(&"prime_v3_metal_buckler","46g_shield").success,"Current shield equipment source legality")
	var before := s.get_state_snapshot()
	var built := exercise(scope+"_consumed",f.service.records.back(),f.service.source,debits(s),f.service._verify)
	check(s.get_state_snapshot() == before,"Codec leaves complete original events, RNG, resources and movement unchanged")
	if built.is_empty(): return
	check(built.body.recent_journal.size() == 20 and built.body.evidence.item_debits.size() == 3,"Journal bounded after genuine checkpoints; only irreversible uses retained")
	var use: Dictionary = built.body.evidence.item_debits[0]
	var id := JSON.stringify([use.run_id,use.request_id])
	check(not built.snapshot.transaction("item_use",id,Codec.binding(built.body,"item_use",use)).success,"Exact early consumption remains protected after operation journal eviction")
	check(built.snapshot.transaction("item_use",id,"0".repeat(64)).reason == "snapshot_v3_conflicting_transaction","Conflicting old use binding rejects")
	check(built.body.current.items.any(func(item): return item.quantity == 0 and item.definition_id == "health_potion"),"Terminal zero remains, never inferred missing")
	check(s.request_player_inventory_unequip(&"prime_v3_short_wand","46g_extension_off").success,"Actual adjacent checkpoint for immutable extension comparison")
	var adjacent := exercise(scope+"_adjacent_checkpoint",f.service.records.back(),f.service.source,debits(s),f.service._verify)
	if not adjacent.is_empty():
		check(Codec.validate_extension(built.body,adjacent.body,f.service.source,f.service.profile_id,scope).success,"Actual next sequence/journal/policy and lifetime prefix compare")
		check(not Codec.validate_extension(adjacent.body,built.body,f.service.source,f.service.profile_id,scope).success,"An older individually valid checkpoint cannot be a forward extension")
		var rebound: Dictionary = adjacent.body.duplicate(true); rebound.evidence.item_debits[0].request_id = "rebound_resolved_request"
		check(Codec.validate(rebound,f.service.source,f.service.profile_id,scope).success,"Cold local semantics cannot authenticate an opaque renamed ID")
		check(not Codec.validate_extension(built.body,rebound,f.service.source,f.service.profile_id,scope).success,"Previously admitted original permanent binding cannot be reassigned")
		rebound = adjacent.body.duplicate(true); rebound.recent_journal[0].request_digest = "f".repeat(64)
		check(Codec.validate(rebound,f.service.source,f.service.profile_id,scope).success and not Codec.validate_extension(built.body,rebound,f.service.source,f.service.profile_id,scope).success,"An immutable retained journal binding cannot be reassigned")
		rebound = adjacent.body.duplicate(true); rebound.current.recovery.player.current_hpc -= 1
		check(Codec.validate(rebound,f.service.source,f.service.profile_id,scope).success and not Codec.validate_extension(adjacent.body,rebound,f.service.source,f.service.profile_id,scope).success,"Different valid current state at the same sequence conflicts")
	check(s.request_player_inventory_equip(&"prime_v3_short_wand","46g_extension_on").success,"Original source restores desired loadout")
	check(s.request_next_wave().success,"Actual next wave before active consumption")
	s.set_opponent_behavior_enabled(false)
	# All potions are exhausted; a genuine new acquisition is needed for active use.
	helper._defeat_wave(s)
	var cause2 := s.simulation.record_reward_event(&"reward_fixture_origin",&"player",&"player",{})
	s.simulation.create_ground_loot_item("46g_active",{"definition_id":"health_potion","quantity":2,"display_name":"Health Potion","item_kind":"potion","source_ref":"Prime V3 p.120; disposable active fixture"},s.get_actor_state(&"player").position_microfeet,&"player",cause2.event_id)
	check(s.collect_all_ground_loot().success and s.request_player_weapon_handling(&"prime_v3_short_wand","stow","46g_stow_active").success,"Genuine acquired active-use stock")
	check(s.request_next_wave().success,"Actual active wave")
	s.set_opponent_behavior_enabled(false)
	s.get_actor_state(&"player").current_hpc = 1
	var active := s.request_player_inventory_consumable_use(&"health_potion","46g_active_use")
	check(active.success,"Real timed consumable accepted")
	s.advance_by(11000000)
	var no_effect := s.request_player_inventory_consumable_use(&"health_potion","46g_interrupt")
	check(no_effect.success,"Real interrupted request accepted")
	if no_effect.success: s.simulation.schedule_interruption(no_effect.action_instance_id,s.simulation.clock.get_elapsed_us(),&"player","disposable_interrupt"); s.advance_by(1)
	helper._defeat_wave(s)
	var active_built := exercise(scope+"_active",f.service.records.back(),f.service.source,debits(s),f.service._verify)
	if not active_built.is_empty():
		check(not active_built.body.evidence.item_debits.any(func(row): return row.request_id == "46g_interrupt"),"No-effect accepted request has no fabricated irreversible debit")
		check(active_built.body.evidence.item_debits.any(func(row): return row.request_id == "46g_active_use"),"Timed use retains actual action request binding without temporary trajectory")
		if scope == "dev_normal": sample = active_built
	# Actual original reload and authorized NEW RUN, not a fabricated run ID.
	var latest: Dictionary = f.service.records.back()
	var known_zeros: Array = active_built.body.current.items.filter(func(item): return item.quantity == 0) if not active_built.is_empty() else []
	var resumed := q.start(CharacterSaveStorage.new(f.service.storage._root),scope,null,latest,true)
	check(resumed.success,"Original verified resume before explicit abandon")
	if resumed.success:
		var auth: Dictionary = resumed.session.get_abandon_run_authorization()
		check(auth.success,"Genuine abandon checkpoint authorization")
		if auth.success:
			var next := q.start(CharacterSaveStorage.new(f.service.storage._root),scope,1,latest,true,true,auth.checkpoint)
			check(next.success,"Actual new run first Wave 1 publication")
			if next.success:
				var incomplete := pack(next.service.records.back(),debits(s))
				check(not Codec.validate(incomplete,next.service.source,next.service.profile_id,scope).success,"Legacy resumed positive-only ownership alone cannot invent missing zero rows")
				var entry := exercise(scope+"_second_run",next.service.records.back(),next.service.source,debits(s),next.service._verify,known_zeros)
				check(not entry.is_empty() and entry.body.current.run_history.size() == 2 and entry.body.current.xp == latest.current.xp,"Multi-run preserves original permanent progression and balances")
				helper._defeat_wave(next.session)
				check(next.session.collect_all_ground_loot().success,"New run origins/rewards remain distinct")
				if next.session.get_actor_state(&"player").weapon_handling.get("prime_v3_short_wand","") != CombatWeaponHandling.STOWED:
					check(next.session.request_player_weapon_handling(&"prime_v3_short_wand","stow","46g_new_stow").success,"New run original legal stow when needed")
				else: check(true,"Original new-run checkpoint preserves already-stowed weapon")
				if next.session.get_actor_state(&"player").inventory_quantities.get("health_potion",0) > 0:
					next.session.get_actor_state(&"player").current_hpc = 1
					check(next.session.request_player_inventory_consumable_use(&"health_potion","same_use_0").success,"Same raw string is a genuine different-run use")
				var multi := exercise(scope+"_second_run_rewards",next.service.records.back(),next.service.source,debits(s)+debits(next.session),next.service._verify,known_zeros)
				if not multi.is_empty():
					check(multi.body.current.run_history == next.service._prior.run_history and multi.body.evidence.awards.size() > latest.evidence.awards.size(),"Both run identities and source-valued awards persist without prior run logs")
	check(q.failures.is_empty() and f.service.errors.is_empty() and helper._failures.is_empty(),"All original source observer checks retained: "+str(f.service.errors))

func historical() -> void:
	var h := H.new(); h.root = root.path_join("histories")
	for version: int in [2,4]:
		var f := h.make_history("dev_normal",Codec.Credit.BASELINE,version,"v"+str(version))
		check(f.get("success",false),"Reconstructed source-authorized historical V"+str(version))
		if not f.get("success",false): continue
		var converted := Convert.convert(f.records,"dev_normal")
		check(converted.success and converted.comparison.success,"Independent full legacy conversion validates original evidence")
		if not converted.success: continue
		var source: CombatCharacterDefinitionResource = PlayableCharacterAdmission.prepare_starter(&"vaelis_thorn","dev_normal",Codec.Credit.BASELINE).source
		exercise("historical_v"+str(version),converted.record,source)
		if version == 2:
			var quote := Native.quote(converted.record,source,null,V6)
			var native := Native.build(converted.record,source,quote.quote,V6.digest(converted.record.current.recovery),V6) if quote.success else quote
			check(native.success,"Original independently validated native fixed credit")
			if native.success: exercise("native_fixed_credit",native.record,source)
			complex_history(f,converted,source)
	check(h.failures.is_empty() and h.helper._failures.is_empty(),"Historical fixture assertions retained")

func complex_history(f: Dictionary, parent: Dictionary, source: CombatCharacterDefinitionResource) -> void:
	var approve := func(value: Dictionary): return {"confirmed":true,"binding":Codec.Credit.digest(value)}
	var grant := Codec.Credit.prepare(f.payload,approve)
	check(grant.success,"Original exact EXPC-only grant, disposable profile only")
	if not grant.success: return
	var proposal := CharacterPersistenceCoordinator.prepare(grant.payload,grant.payload.settlements,grant.transaction_id,f.payload.generation,f.payload.secured_checkpoints)
	var verifier := func(_op: String, binding: String): return {"authorized":true,"binding":binding,"lineage":grant.payload.lineage}
	check(CharacterPersistenceCoordinator.new(f.storage).commit(proposal.prepared,source,f.profile,PlayableCharacterAdmission.RULES,verifier).success,"Original coordinator publishes credit once")
	var rows := CharacterSaveStorage.history_records(f.storage.inspect_profile(f.profile))
	var credited := Convert.convert(rows,"dev_normal")
	check(credited.success and credited.comparison.success,"Full historical credit/predecessor proof before compact omission")
	if not credited.success: return
	exercise("historical_fixed_credit",credited.record,source)
	var q := Q.new(); var next := q.start(f.storage,"dev_normal",null,credited.record,true)
	check(next.success,"Original credited historical resume")
	if not next.success: return
	var s: ArenaCombatSession = next.session; var helper := H.new().helper
	for spec: Array in [["end",6,3000,""],["wis",10,3000,""],["dex",9,3000,"dt"]]: purchase(s,spec)
	check(s.request_next_wave().success,"Original future growth wave")
	helper._defeat_wave(s)
	check(s.collect_all_ground_loot().success,"Genuine complex loot")
	purchase(s,["end",7,3000,""])
	check(s.request_next_wave().success,"Original END8/WIS11 future growth")
	helper._defeat_wave(s)
	check(s.collect_all_ground_loot().success,"Genuine later loot")
	for spec: Array in [["str",9,3000,""],["spd",11,5000,""]]: purchase(s,spec)
	var built := exercise("all_five_interleaved",next.service.records.back(),source,[],next.service._verify)
	if not built.is_empty():
		for attr: String in ["str","dex","spd","wis","end"]: check(built.body.evidence.purchases.any(func(row): return row.target_id == attr and row.purchase_kind == "attribute"),"Actual permanent "+attr+" purchase")
		check(built.body.evidence.growth.any(func(row): return row.hpb == 2) and built.body.evidence.growth.any(func(row): return row.wisdom == 11),"Event-time END/HPB/WIS gains differ from final attributes")
		check(built.body.evidence.credit == credited.record.evidence.credit and built.body.current.xp.earned == next.service._prior.xp.earned,"Fixed grant not reawarded; EXPM stays source-earned")
		var prior_preferences: Dictionary = built.body
		for i in range(24):
			check(s.request_character_development("preferences",{"order":["nac","block","dodge","soak"] if i%2 else ["nac","dodge","block","soak"]},"46g_preferences_"+str(i)).success,"Real temporary preference checkpoints")
			if i < 2:
				var candidate := pack(next.service.records.back())
				check(Codec.validate_extension(prior_preferences,candidate,source,f.profile,"dev_normal").success,"Current preferences can be replaced while exact permanent allocation facts stay immutable")
				prior_preferences = candidate
		var later := exercise("all_five_bounded_preferences",next.service.records.back(),source,[],next.service._verify)
		if not later.is_empty(): check(later.body.current.permanent.development.commands.filter(func(row): return row.kind == "preferences").size() == 1,"Only original latest preferences retained, no general temporary command history")
		for mutation: String in ["credit_amount","credit_id","hpb","wis","roll","price","lost_growth"]:
			var bad: Dictionary = built.body.duplicate(true)
			match mutation:
				"credit_amount": bad.evidence.credit.records[0].amount += 1
				"credit_id": bad.evidence.credit.records[0].grant_id = "another_credit"
				"hpb": bad.evidence.growth.back().hpb += 1
				"wis": bad.evidence.growth.back().wisdom += 1
				"roll": bad.evidence.growth.back().roll = 0
				"price": bad.evidence.purchases.back().cost -= 1
				"lost_growth": bad.evidence.growth.pop_back()
			check(not Codec.validate(bad,source,f.profile,"dev_normal").success,"Original credit/growth/purchase rejection: "+mutation)
	check(q.failures.is_empty() and next.service.errors.is_empty() and helper._failures.is_empty(),"All-five original source checks retained")

func purchase(s: ArenaCombatSession, spec: Array) -> void:
	var selection := {"expected_current_value":spec[1],"expected_cost":spec[2]}
	if spec[3] != "": selection["allocation"] = spec[3]
	var result := s.request_character_advancement(&"attribute",StringName(spec[0]),"46g_"+spec[0]+str(spec[1]),selection)
	check(result.success,"Original authorized "+str(spec)+": "+str(result.get("reason","")))

func frozen_rejection() -> void:
	var helper := W.new()
	var cache := OS.get_cache_dir().path_join("itank-storage-tests/")
	var text := helper.read_fixture(cache.path_join("compact45m_45n_session_20261117e/233.json"))
	check(not text.is_empty(),"Explicit known disposable 233-generation archive")
	if not text.is_empty():
		var source: CombatCharacterDefinitionResource = helper.trusted(text).source
		var original := V6.decode(text,source)
		check(original.success,"Independent existing 233-generation validator")
		if original.success:
			var b := pack(original.record)
			check(Codec.validate(b,source,b.current.character_id,b.current.profile_namespace).get("reason") == "snapshot_v3_item_conservation","Missing original resolved consumption facts: explicit unsupported conversion, never inferred from zeros")
	# Separately labelled genuine high-inventory source fixture, no padding.
	text = helper.current_from_cache("compact45s_bench_25204_2215533/inventory")
	if not text.is_empty():
		var source: CombatCharacterDefinitionResource = helper.trusted(text).source
		var original := V6.decode(text,source)
		check(original.success,"Independent 1005-item stress validator")
		if original.success:
			var b := pack(original.record)
			var attempt := Codec.validate(b,source,b.current.character_id,b.current.profile_namespace)
			if attempt.success: exercise("stress_1005_items",original.record,source)
			else: check(attempt.reason == "snapshot_v3_item_conservation","Stress fixture with unknown uses cannot invent missing provenance")
	check(helper.failures.is_empty(),"Frozen fixture isolation checks")

func rejections(f: Dictionary) -> void:
	var b: Dictionary = f.body
	var cases: Array = []
	for field: String in ["operations","lifetime_ids","command_evidence","verified","request_context"]:
		var bad := b.duplicate(true); bad[field] = []; cases.append([field,bad])
	var bad := b.duplicate(true); bad.evidence.item_debits.remove_at(0); cases.append(["missing debit",bad])
	bad = b.duplicate(true); bad.evidence.item_debits.append(bad.evidence.item_debits[0].duplicate(true)); cases.append(["duplicate use",bad])
	bad = b.duplicate(true); bad.evidence.item_debits.back().event_id = bad.evidence.item_debits[0].event_id; cases.append(["reused effect new wrapper",bad])
	bad = b.duplicate(true); bad.evidence.item_debits[0].selection[0].quantity += 1; cases.append(["changed spend",bad])
	bad = b.duplicate(true); bad.evidence.item_debits[0].selection[0].instance_id = "unknown"; cases.append(["unowned spend",bad])
	bad = b.duplicate(true); bad.evidence.item_debits[0].kind = "wall_destroyed"; cases.append(["unsupported loss",bad])
	bad = b.duplicate(true); bad.evidence.item_debits[0].definition_id = "gold"; cases.append(["currency as potion",bad])
	bad = b.duplicate(true); bad.evidence.item_debits[0].run_id = "invented_run"; cases.append(["unknown run",bad])
	bad = b.duplicate(true); bad.current.items = bad.current.items.filter(func(row): return row.quantity > 0); cases.append(["lost terminal zeros",bad])
	bad = b.duplicate(true); bad.current.items[0].equipped_slots = ["illegal_slot"]; cases.append(["illegal equipment",bad])
	bad = b.duplicate(true); bad.evidence.order.reverse(); cases.append(["changed progression order",bad])
	bad = b.duplicate(true); bad.evidence.growth[0].wisdom += 1; cases.append(["changed event WIS",bad])
	bad = b.duplicate(true); bad.evidence.awards[0].xp += 1; cases.append(["forged reward",bad])
	bad = b.duplicate(true); bad.current.xp.unspent += 10000; cases.append(["forged EXPC",bad])
	bad = b.duplicate(true); bad.source_digest = "0".repeat(64); cases.append(["source",bad])
	bad = b.duplicate(true); bad.current.recovery.rng.draw_count = -1; cases.append(["malformed RNG",bad])
	bad = b.duplicate(true); bad.current.recovery.player.mana_recovery_units = ArenaManaRecovery.UNITS_PER_MANA; cases.append(["remainder",bad])
	bad = b.duplicate(true); bad.current.recovery.movement.profile.end = 99; cases.append(["Running",bad])
	bad = b.duplicate(true); bad.current.run_reward_policy.runs[0].xp_multiplier = 1; cases.append(["historical multiplier",bad])
	bad = b.duplicate(true); bad.recent_journal[0].sequence += 1; cases.append(["journal gap",bad])
	for pair: Array in cases: check(not Codec.validate(pair[1],f.source,b.current.character_id,b.current.profile_namespace).success,"Cold reject "+pair[0])
	check(Codec.validate_extension(b,b,f.source,b.current.character_id,b.current.profile_namespace).get("exact_retry",false),"Identical immutable record comparison")
	check(not Codec.validate(b,f.source,"prod_vaelis_thorn","normal").success,"Namespace crossover rejected")
	for text: String in [f.text.left(-1),f.text+" ",f.text.replace('"version":3','"version":2'),f.text.replace('"version":3','"version":3,"version":3'),f.text.replace('"sha256":"','"sha256":"0')]: check(not Codec.decode(text,f.source,b.current.character_id,b.current.profile_namespace).success,"Malformed/version/noncanonical/duplicate-key/checksum rejection")
	check(not Codec.decode(" ".repeat(V1.MAX_FILE_BYTES+1),f.source,b.current.character_id,b.current.profile_namespace).success,"Finite file bytes")
	check(not Codec.decode_bytes(PackedByteArray([255]),f.source,b.current.character_id,b.current.profile_namespace).success,"Invalid UTF-8 rejection")

func cold_process(f: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(root)
	var file := FileAccess.open(root.path_join("v3.json"),FileAccess.WRITE); file.store_string(f.text); file.close()
	file = FileAccess.open(root.path_join("expected.json"),FileAccess.WRITE); file.store_string(JSON.stringify(f.expected,"",true,true)); file.close()
	var output: Array = []
	var code := OS.execute(OS.get_executable_path(),["--headless","--path",ProjectSettings.globalize_path("res://"),"--script","res://tests/minimal_snapshot_v3_cold_process.gd","--",root,f.body.current.character_id,f.body.current.profile_namespace,f.body.current.lineage.baseline_digest,f.text.sha256_text()],output,true)
	check(code == 0 and str(output).contains("46G_COLD_PASS"),"Fresh process full independent validation/equivalence, no request authority or prior trust: "+str(output))
