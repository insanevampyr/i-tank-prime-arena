extends RefCounted
const Adapter = preload("res://scripts/rewards/compact_v6_gameplay_candidate.gd")
const V6 = preload("res://scripts/rewards/compact_character_v6_prototype.gd")
const Convert = preload("res://scripts/rewards/legacy_to_compact_v6_prototype.gd")
const Historical = preload("res://tests/test_historical_vaelis_admission.gd")
const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
const Credit = preload("res://scripts/rewards/character_expc_credit.gd")
var failures: Array[String] = []
var assertions := 0
var metrics: Array = []

# Only this disposable test host subscribes. No playable production hook exists.
class Observed extends PlayableCharacterPersistence:
	var observer: RefCounted
	var host: WeakRef
	var compact_parent := {}
	var enabled := true
	var errors: Array = []
	var records: Array = []
	var measures: Array = []
	var last_prepared: RefCounted
	var probes := 0
	var checkpoints := 0
	var lost_ack := false
	var before_commit: Callable
	func bind_runtime(session: ArenaCombatSession) -> Dictionary:
		host = weakref(session)
		if enabled: observer = Adapter.new(self,compact_parent)
		return super.bind_runtime(session)
	func ingest(session: ArenaCombatSession) -> Dictionary:
		var result := super.ingest(session)
		if result.success and enabled and observer != null:
			var capture: Dictionary = observer.observe(session)
			if not capture.success: errors.append(capture)
		return result
	func publish_prepared() -> Dictionary:
		checkpoints += 1
		var before := V6.digest(host.get_ref().get_state_snapshot())
		var candidate := {}
		if enabled:
			candidate = observer.prepare(observer.head())
			if not candidate.success: errors.append(candidate)
			else:
				last_prepared = candidate.prepared
				measures.append(candidate.metrics)
				var repeated: Dictionary = observer.prepare(observer.head())
				if not repeated.success or repeated.prepared != candidate.prepared: errors.append({"reason":"exact_retry_changed"})
				var checked: Dictionary = observer.check(candidate.prepared,observer.head())
				if not checked.success: errors.append(checked)
				# A modified returned copy and assignment to the sealed string cannot
				# mutate the prepared operation or its authorization binding.
				var original: String = candidate.prepared.bytes()
				var copy: Dictionary = candidate.prepared.copy()
				if copy.candidate_digest != copy.candidate_text.sha256_text(): errors.append({"reason":"candidate_digest_missing_or_changed"})
				copy.candidate_text += " "
				candidate.prepared._bytes = "forged"
				if candidate.prepared.bytes() != original: errors.append({"reason":"mutable_prepared_bytes"})
				if observer.check(Adapter.Prepared.new(copy),observer.head()).get("reason") != "foreign_or_changed_prepared_operation": errors.append({"reason":"forged_handle_accepted"})
				var stale: Dictionary = observer.head(); stale.sequence += 1
				if observer.check(candidate.prepared,stale).get("reason") != "stale_compact_head": errors.append({"reason":"stale_head_accepted"})
				var saved_proposal := _prepared.duplicate(true)
				_prepared.payload.xp.unspent += 1
				if observer.check(candidate.prepared,observer.head()).get("reason") != "checkpoint_request_changed": errors.append({"reason":"changed_request_accepted"})
				_prepared = saved_proposal
				var saved_source := source
				source = source.duplicate(true); source.attributes.wis += 1
				if observer.check(candidate.prepared,observer.head()).get("reason") != "trusted_source_changed": errors.append({"reason":"changed_source_accepted"})
				source = saved_source
				var saved_mode := mode
				mode = "normal" if mode == "dev_normal" else "dev_normal"
				if observer.check(candidate.prepared,observer.head()).get("reason") != "profile_context_changed": errors.append({"reason":"namespace_crossover_accepted"})
				mode = saved_mode
				var saved_facts: Array = observer._facts.duplicate(true)
				observer._facts.reverse()
				if saved_facts.size() > 1 and observer.check(candidate.prepared,observer.head()).success: errors.append({"reason":"reordered_facts_accepted"})
				observer._facts = saved_facts
				observer._cursor += 1
				if observer.check(candidate.prepared,observer.head()).get("reason") != "captured_operation_changed": errors.append({"reason":"changed_capture_interval_accepted"})
				observer._cursor -= 1
				var canceled := Adapter.new(self,observer.current_copy())
				canceled.cancel()
				if canceled.prepare(observer.head()).get("reason") != "candidate_canceled": errors.append({"reason":"cancellation_not_terminal"})
				var missing := Adapter.new(self,observer.current_copy())
				missing._start = host.get_ref().simulation.get_resolved_event_count()
				missing._cursor = missing._start
				missing.observe(host.get_ref())
				var no_events: Dictionary = missing.prepare(missing.head())
				var delta: Dictionary = V6._projection(observer.current_copy()) if not observer.current_copy().is_empty() else {}
				if _prepared.payload.purchases.size() > delta.get("purchases",[]).size() or _prepared.payload.permanent.award_receipts.size() > delta.get("permanent",{}).get("award_receipts",[]).size():
					if no_events.get("reason") != "unsupported_missing_ordered_causal_fact": errors.append({"reason":"missing_order_was_invented","result":no_events})
				probes += 10
		if before != V6.digest(host.get_ref().get_state_snapshot()): errors.append({"reason":"candidate_mutated_simulation"})
		if before_commit.is_valid():
			var callback := before_commit
			before_commit = Callable()
			callback.call()
		var result := super.publish_prepared()
		if enabled and candidate.get("success",false) and result.success:
			# Lost observer acknowledgement: the EXISTING coordinator has committed.
			# Retry must retain the identical sealed request, not manufacture a new op.
			if lost_ack:
				var retry: Dictionary = observer.prepare(observer.head())
				if not retry.success or retry.prepared != candidate.prepared: errors.append({"reason":"uncertain_ack_request_changed"})
				lost_ack = false
			var adopted: Dictionary = observer.adopt(candidate.prepared)
			if not adopted.success: errors.append(adopted)
			else: records.append(observer.current_copy())
		if before != V6.digest(host.get_ref().get_state_snapshot()): errors.append({"reason":"adoption_mutated_simulation"})
		return result

func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok: failures.append(message)

func run() -> Array[String]:
	var previous_storage := PlayableCharacterPersistence.test_storage
	var previous_run := PlayableCharacterPersistence.test_run_id
	var previous_nonpersistent := PlayableCharacterPersistence.test_nonpersistent
	PlayableCharacterPersistence.test_nonpersistent = false
	var root := OS.get_cache_dir().path_join("itank-storage-tests/compact45q_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()])
	for setting: Array in [["normal",1],["dev_normal",1],["dev_normal",10]]:
		var mode: String = setting[0]
		var multiplier: int = setting[1]
		var active := scenario(root.path_join(mode+str(multiplier)),mode,multiplier,true)
		var control := scenario(root.path_join(mode+str(multiplier)+"_control"),mode,multiplier,false)
		check(active.get("success",false) and control.get("success",false),"Source-valid independent gameplay/control sessions build.")
		if active.get("success",false) and control.get("success",false):
			check(active.snapshot == control.snapshot,"Dormant observation preserves RNG, events, 5/AT schedule and simulated-client convergence: "+mode+str(multiplier))
			check(active.payload == control.payload,"V2/V4 legacy projection and all balances/items/resources identical to control.")
			check(active.record == scenario(root.path_join(mode+str(multiplier)+"_replay"),mode,multiplier,true).get("record"),"Identical seed/commands replay identical V6 bytes/bindings.")
	complex(root)
	stale_publication(root.path_join("race"))
	PlayableCharacterPersistence.test_storage = previous_storage
	PlayableCharacterPersistence.test_run_id = previous_run
	PlayableCharacterPersistence.test_nonpersistent = previous_nonpersistent
	print("45Q_METRICS "+JSON.stringify({"samples":metrics,"native_static":OS.get_static_memory_usage(),"native_peak":OS.get_static_memory_peak_usage(),"scope":"native headless debug; no storage time in construction/validation; not Edge or Windows exported release"}))
	print("45Q gameplay candidate: %d assertions." % assertions)
	return failures

func start(store: CharacterSaveStorage, mode: String, multiplier: Variant, parent: Dictionary = {}, enabled: bool = true, new_run: bool = false, authorization: Dictionary = {}, service_factory: Callable = Callable()) -> Dictionary:
	PlayableCharacterPersistence.test_storage = store
	PlayableCharacterPersistence.test_run_id = "run_45q" if not new_run else "run_45q_new"
	var service: Observed = service_factory.call(store,mode,parent) if service_factory.is_valid() else Observed.new()
	service.enabled = enabled
	service.compact_parent = parent
	var opened := service.open(mode,new_run,authorization,multiplier)
	if not opened.success: check(false,"Disposable admission: "+str(opened)); return opened
	var session := ArenaCombatSession.new(1,null,Fixture.ENCOUNTER_WAVE_ONE_GOBLINS,Fixture.PLAYER_CHARACTER_VAELIS)
	session._playable_persistence = service
	session._run_reward_policy = service.get_run_reward_policy()
	session._entry_bootstrap = service.recovery.duplicate(true)
	if not service.recovery.is_empty():
		var wave: int = int(service.recovery.wave_id.trim_prefix("wave_"))
		session._encounter_fixture_id = [Fixture.ENCOUNTER_WAVE_ONE_GOBLINS,Fixture.ENCOUNTER_WAVE_TWO_SPADOODLES,Fixture.ENCOUNTER_WAVE_THREE_SKELLY_HADES,Fixture.ENCOUNTER_WAVE_FOUR_GARGOYLES,Fixture.ENCOUNTER_WAVE_FIVE_RARE_HUMAN_WARRIOR][wave-1]
		session.simulation.wave_entry_opening = service.recovery.opening.duplicate(true)
		for row: Dictionary in service.recovery.roster:
			for i in range(row.dice_results.size()): session._entry_dice.append({"value":row.dice_results[i],"rng_draw_index":row.rng_draw_indices[i]})
	session.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
	var initializer: String = ["initialize_wave_one_goblins","initialize_wave_two_spadoodles","initialize_wave_three_skelly_hades","initialize_wave_four_gargoyles","initialize_wave_five_rare_human_warrior"][int(service.recovery.get("wave_id","wave_1").trim_prefix("wave_"))-1]
	var initialized: Dictionary = session.call(initializer,Vector2i(14000000,8000000),Vector2i(17000000,8000000),false)
	if not initialized.success: return initialized
	var player_actor := session.simulation.get_actor_definition(&"player")
	var movement := PrimeMovementModel.new(player_actor.get_combat_stat("mr"),player_actor.attributes.spd,player_actor.attributes.end,3,0,0,DeterministicCombatRng.new(1))
	if not service.recovery.is_empty(): movement.restore_wave_entry(service.recovery.movement)
	session.player_movement_boundary_provider = movement.wave_entry_state
	session.player_endurance_profile_refresher = func(actor: CombatActorDefinition): movement.set_effective_end(actor.attributes.end)
	session.player_speed_profile_refresher = func(actor: CombatActorDefinition):
		movement.set_effective_spd(actor.attributes.spd)
		movement.base_mr = actor.get_combat_stat("mr")
	var configured := session.configure_reward_mode(mode)
	var finalized := session.finalize_playable_persistence()
	if not configured.success or not finalized.success: check(false,"Finalize real admission: "+str(finalized)); return finalized
	return {"success":true,"service":service,"session":session,"movement":movement}

func scenario(path: String, mode: String, multiplier: int, enabled: bool) -> Dictionary:
	var fixture := start(CharacterSaveStorage.new(path),mode,multiplier,{},enabled)
	if not fixture.success: return fixture
	var s: ArenaCombatSession = fixture.session
	var p: Observed = fixture.service
	if enabled:
		check(p.records.size() == 1 and p.records[0].head.sequence == 1,"New baseline is the actual first Wave 1 checkpoint.")
		if not p.records.is_empty(): verify(p.records.back(),p)
	var helper := Historical.new().helper
	helper._defeat_wave(s)
	check(helper._failures.is_empty(),"Actual ACC/defense/damage defeats, no fabricated XP.")
	check(s.collect_all_ground_loot().success,"Real inventory/currency acquisition.")
	if enabled:
		check(p.errors.is_empty(),"Observed checkpoint preparation: "+str(p.errors))
		if not p.records.is_empty(): verify(p.records.back(),p)
		check(p.records.any(func(r): return not r.evidence.growth.is_empty()),"Original causal growth captured after actual awards." ) if multiplier == 10 else check(true,"Ordinary award accepted.")
	check(s.request_next_wave().success,"NEXT WAVE keeps admitted namespace/policy.")
	if enabled:
		check(p.errors.is_empty(),"NEXT WAVE capture: "+str(p.errors))
		if not p.records.is_empty(): verify(p.records.back(),p)
		metrics.append({"fixture":mode+str(multiplier),"boundaries":p.measures})
		check(p.probes >= p.checkpoints*10,"Every prepared boundary ran stale, forged, changed-source, changed-bytes, reordered-fact and cancellation probes.")
	return {"success":true,"snapshot":s.get_state_snapshot(),"payload":p._prior.duplicate(true),"record":p.observer.current_copy() if enabled else {}}

func verify(record: Dictionary, service: Observed) -> void:
	var validated := V6.validate(record,service.source)
	check(validated.success,"Full cold V6 validation: "+str(validated.get("reason")))
	if not validated.success: return
	check(V6._projection(record) == CharacterSaveContract.decode(service._prepared.document).payload,"Entire cold legacy result exact: attributes, inventory, equipment, resources, checkpoint, RNG, timers, Mana remainder, run policy.")
	var original := CharacterProfileProjection.hydrate(service._prior,service.source,service.profile_id,PlayableCharacterAdmission.RULES,service._verify)
	check(original.success and original.actor_definition.to_dictionary() == validated.actor.to_dictionary(),"Independent authoritative actor hydration equals compact actor.")
	for growth: Dictionary in service._prior.permanent.growth:
		if not service._endurance_history.is_empty(): check(validated.end_growth.get(growth.growth_id) == service._endurance_history.growth.get(growth.growth_id),"Generation-backed event-time END/HPB witness exact.")
	var ids := {}
	for row: Dictionary in record.applied_ids: ids[JSON.stringify([row.scope,row.id])] = row.record_digest
	for group: Array in [["award",service._prior.permanent.award_receipts,"award_id"],["purchase",service._prior.purchases,"purchase_id"],["growth",service._prior.permanent.growth,"growth_id"],["settlement",service._prior.settlements,"receipt_id"],["credit",service._prior.get("expc_credits",{}).get("records",[]),"grant_id"]]:
		for row: Dictionary in group[1]: check(ids.get(JSON.stringify([group[0],row[group[2]]])) == V6.digest(row),"Exact lifetime original binding: "+group[0])
	check(not CharacterSaveContract.decode(V6.encode(record,service.source).text).success,"Production reader still rejects dormant V6.")

func complex(root: String, enabled: bool = true, service_factory: Callable = Callable(), core_only: bool = false) -> Dictionary:
	var h := Historical.new()
	h.root = root.path_join("history")
	var fixture := h.make_history("dev_normal",Credit.BASELINE,2,"v2")
	check(fixture.get("success",false),"Actual V2 history for verified conversion.")
	if not fixture.get("success",false): return {}
	var approve := func(binding: Dictionary): return {"confirmed":true,"binding":Credit.digest(binding)}
	var credit := Credit.prepare(fixture.payload,approve)
	check(credit.success,"Existing fixed historical credit, only disposable storage.")
	if not credit.success: return {}
	var proposal := CharacterPersistenceCoordinator.prepare(credit.payload,credit.payload.settlements,credit.transaction_id,fixture.payload.generation,fixture.payload.secured_checkpoints)
	var source: CombatCharacterDefinitionResource = PlayableCharacterAdmission.prepare_starter(&"vaelis_thorn","dev_normal",Credit.BASELINE).source
	if enabled:
		var uncredited := Convert.convert(fixture.records,"dev_normal")
		check(uncredited.success,"Verified uncredited parent for the B2 refusal control.")
		if uncredited.success:
			var parent: Dictionary = uncredited.record
			var e: Dictionary = parent.evidence.duplicate(true)
			e.credit = credit.payload.expc_credits.duplicate(true)
			e.credit_predecessor = {"format":"compact_legacy_credit_basis_v1","current":Convert.Conversion.strip(fixture.payload),"counts":{"awards":e.awards.size(),"purchases":e.purchases.size(),"growth":e.growth.size(),"settlements":e.settlements.size(),"order":e.order.size()}}
			e.order.append({"kind":"credit","id":Credit.GRANT_ID})
			var ops: Array = parent.operations.duplicate(true)
			ops.append({"id":credit.transaction_id,"request_digest":V6.digest(credit.payload)})
			var proposed_head: Dictionary = parent.head.duplicate(true)
			proposed_head.sequence += 1; proposed_head.parent_digest = V6.digest(parent)
			var grant := V6.assemble(Convert.Conversion.strip(credit.payload),e,ops,proposed_head,source)
			check(V6.validate(grant,source).success,"Negative control contains complete existing legacy credit proof; no new authorization invented.")
			check(V6.validate_extension(parent,grant,source).get("reason") == "credit_history_changed","B2 stays blocked: even well-formed post-conversion credit cannot be introduced by S2.")
	var verifier := func(_op: String,binding: String): return {"authorized":true,"binding":binding,"lineage":credit.payload.lineage}
	var committed := CharacterPersistenceCoordinator.new(fixture.storage).commit(proposal.prepared,source,fixture.profile,PlayableCharacterAdmission.RULES,verifier)
	check(committed.success,"Legacy V5 fixture credit uses established coordinator.")
	if not committed.success: return {}
	var rows := CharacterSaveStorage.history_records(fixture.storage.inspect_profile(fixture.profile))
	var converted := Convert.convert(rows,"dev_normal")
	check(converted.success,"Verified disposable V2/V5 baseline conversion.")
	if not converted.success: return {}
	var f := start(fixture.storage,"dev_normal",null,converted.record,enabled,false,{},service_factory)
	if not f.success: return {}
	var p: Observed = f.service
	var s: ArenaCombatSession = f.session
	check(s.request_next_wave().success,"Resume saved downtime into next wave.")
	h.helper._defeat_wave(s)
	check(s.collect_all_ground_loot().success,"Source-valid later loot and XP.")
	for attribute: String in ["end","wis","dex"]:
		var value := int(s.simulation.get_actor_definition(&"player").attributes[attribute])
		var cost := 3000 if value <= 10 else 5000
		var selection := {"expected_current_value":value,"expected_cost":cost}
		if attribute == "dex": selection["allocation"] = "dt"
		var purchased := s.request_character_advancement(&"attribute",StringName(attribute),"45q_"+attribute,selection)
		check(purchased.success,"Real source-priced "+attribute+" purchase: "+str(purchased.get("reason")))
		if not p.records.is_empty(): verify(p.records.back(),p)
	var hpc_before: int = s.get_actor_state(&"player").current_hpc
	var hpm_before: int = s.get_actor_max_hpm(&"player")
	check(s.request_character_advancement(&"attribute",&"end","45q_end8",{"expected_current_value":7,"expected_cost":3000}).success,"END7->8 crosses HPB threshold before subsequent level gains.")
	check(s.get_actor_state(&"player").current_hpc == hpc_before and s.get_actor_max_hpm(&"player") == hpm_before,"END purchase never retroactively increases HPM/HPC.")
	var state := s.get_actor_state(&"player")
	var origin := s.simulation.record_reward_event(&"reward_source_item_fixture",&"player",&"player",{})
	for ref: String in ["health_potion","prime_v3_metal_buckler"]:
		s.simulation.create_ground_loot_item("45q_item_"+ref,{"definition_id":ref,"quantity":3 if ref == "health_potion" else 1,"display_name":ref,"item_kind":"potion" if ref == "health_potion" else "equipment","source_ref":"PRIME-V3 pp.120,137; disposable source item fixture"},state.position_microfeet,&"player",origin.event_id)
	check(s.collect_all_ground_loot().success,"Source-backed potion/shield instances use actual acquisition and ownership receipts.")
	check(s.request_player_weapon_handling(Fixture.VAELIS_WAND_REF,"stow","45q_stow").success,"Legitimate hand/resource setup.")
	state.current_hpc = 3 # Disposable wounded starting condition, not a heal effect.
	check(s.request_player_inventory_consumable_use(&"health_potion","45q_potion").success,"Actual consumable operation and quantity decrement.")
	check(s.request_player_inventory_unequip(Fixture.VAELIS_WAND_REF,"45q_unequip").success,"Actual equipment removal.")
	check(s.request_player_inventory_equip(Fixture.VAELIS_WAND_REF,"45q_reequip").success,"Actual equipment restoration preserves instance.")
	check(s.request_player_inventory_equip(&"prime_v3_metal_buckler","45q_buckler").success,"Actual shield equip.")
	state.progression["mana_recovery_units"] = 123456
	check(s.request_character_development("preferences",{"order":["nac","block","dodge","soak"]},"45q_resources").success,"Existing remainder and resource/timer checkpoint captured without refill.")
	check(s.request_developer_character_refresh("45q_explicit_dev_refresh").success,"Explicit existing legacy-DEV downtime recovery prepares the condition fixture; builder grants no refill.")
	check(s.request_next_wave().success,"Further wave preserves purchased END/WIS for future growth.")
	var profile := s.simulation.get_defense_profile(&"player")
	var priority := profile.priority.duplicate()
	profile.priority = PackedStringArray(["shield_block","dodge","weapon_block","physical_soak"])
	var enemy := StringName(s.get_targetable_enemy_ids()[0])
	for i in range(40):
		if profile.shield_block.current_shp < 20 or s.get_actor_state(&"player").current_hpc <= 0: break
		if s.is_actor_prone(&"player"):
			s.request_player_stand("45q_wear_stand"); s.advance_by(5000000)
		s.simulation.apply_authoritative_spatial_position(enemy,s.get_actor_state(&"player").position_microfeet+Vector2i(1000000,0),0,180000)
		if s._request_actor_attack(enemy,&"player","45q_shield_wear").success: s.advance_by(5000000)
	profile.priority = priority
	check(profile.shield_block.current_shp < 20,"Real legal shield Block consumes SHP; no synthetic condition receipt.")
	h.helper._defeat_wave(s)
	check(s.collect_all_ground_loot().success,"Further real loot/currency.")
	check(s.request_character_advancement(&"attribute",&"str","45q_str",{"expected_current_value":9,"expected_cost":3000}).success,"Source-priced STR purchase after sufficient XP.")
	check(s.request_character_advancement(&"attribute",&"spd","45q_spd",{"expected_current_value":11,"expected_cost":5000}).success,"Source-priced SPD purchase after sufficient real XP.")
	var mana_before: Dictionary = s.get_actor_state(&"player").resources.duplicate(true)
	check(s.request_character_advancement(&"attribute",&"wis","45q_wis12",{"expected_current_value":11,"expected_cost":5000}).success,"WIS11->12 after original odd-WIS level gains.")
	check(s.get_actor_state(&"player").resources == mana_before,"Permanent WIS purchase changes no current resource balance.")
	check(p._prior.permanent.growth.any(func(row): return row.hpb == 2) and p._prior.permanent.growth.any(func(row): return row.wisdom == 11),"Future actual level gains use event-time END8 HPB2 and WIS11, never final WIS12.")
	if core_only:
		if enabled:
			check(p.errors.is_empty(),"Bounded mutation fixture preserves all coordinator checks: "+str(p.errors))
			if not p.records.is_empty(): verify(p.records.back(),p)
			var oracle := complex(root.path_join("core_control"),false,Callable(),true)
			check(oracle.get("success",false) and oracle.snapshot == s.get_state_snapshot(),"Complete mutation fixture converges with independent legacy combat/RNG control.")
			var expected: Dictionary = CharacterSaveContract.decode(CharacterSaveContract.encode(oracle.get("payload",{})).get("text","")).get("payload",{})
			check(expected == p._prior,"All XP, items/condition, attributes, growth, resources and receipts equal cold legacy control.")
		metrics.append({"fixture":"bounded_all_mutations","boundaries":p.measures})
		return {"success":true,"snapshot":s.get_state_snapshot(),"payload":p._prior.duplicate(true)}
	var balance_before: Dictionary = p._prior.xp.duplicate(true)
	s.get_actor_state(&"player").progression["mana_recovery_units"] = 123456
	var movement: PrimeMovementModel = f.movement
	movement.request_running()
	movement.advance(1000000,Vector2.RIGHT)
	movement.stop_running()
	var motion_before := movement.wave_entry_state()
	var old_generation := p.generation
	for i in range(23):
		p.lost_ack = i == 4
		check(s.request_character_development("preferences",{"order":["nac","block","dodge","soak"] if i%2 == 0 else ["nac","dodge","block","soak"]},"45q_lifetime_%d" % i).success,"Independent original development request outside recent journal.")
	check(p.generation == old_generation+23 and p._prior.xp == balance_before,"Lost acknowledgement/repeated checkpoints create no balances or duplicate grants.")
	var count := p.records.size()
	check(s.request_character_advancement(&"attribute",&"end","45q_end",{"expected_current_value":7,"expected_cost":3000}).get("reason") == "duplicate_advancement_request","Old purchase request remains rejected outside recent journal.")
	var award: Dictionary = s.get_reward_state().awards[0]
	check(not s._reward_ledger.process_defeat(s.simulation,StringName(award.actor_id),award.defeat_event_id).success,"Actual old defeat cannot reaward XP or loot.")
	check(p.records.size() == count and p._prior.xp == balance_before,"Rejected duplicates do not prepare another candidate or spend.")
	check(p.errors.is_empty(),"Interleaved mutation capture: "+str(p.errors))
	check(h.failures.is_empty() and h.helper._failures.is_empty(),"Source gameplay helper has no failures: "+str(h.helper._failures))
	if not p.records.is_empty(): verify(p.records.back(),p)
	metrics.append({"fixture":"converted_v5_complex" if enabled else "converted_v5_control","boundaries":p.measures})
	if not enabled: return {"success":true,"snapshot":s.get_state_snapshot(),"payload":p._prior.duplicate(true)}
	var control := complex(root.path_join("control"),false)
	check(control.get("success",false) and control.snapshot == s.get_state_snapshot(),"Full interleaved purchases, real combat/items/shield wear and 23 checkpoints converge with the unobserved client.")
	var control_payload: Variant = control.get("payload")
	if service_factory.is_valid() and control_payload is Dictionary:
		control_payload = CharacterSaveContract.decode(CharacterSaveContract.encode(control_payload).text).payload
	check(control_payload == p._prior,"Every current value and committed receipt matches independent legacy execution.")
	var latest: Dictionary = p.observer.current_copy()
	var original_credit: Dictionary = CharacterSaveContract.decode(rows[int(latest.evidence.credit.records[0].after_generation)-1].document).payload
	check(V6._historical_credit_basis(latest,p.source).get("payload") == original_credit,"Materialized credit witness equals the exact original legacy predecessor, not a reconstructed balance assertion.")
	var changed: Dictionary = latest.duplicate(true)
	changed.evidence.credit_predecessor.current.recovery.player.current_hpc -= 1
	changed = V6.assemble(changed.current,changed.evidence,changed.operations,changed.head,p.source)
	check(not V6.validate(changed,p.source).success,"Changed fixed-credit predecessor rejected even with recomputed registry/accounting.")
	var resumed := start(fixture.storage,"dev_normal",null,latest,true,false,{},service_factory)
	check(resumed.success and resumed.service.get_run_reward_policy() == p.get_run_reward_policy(),"RESUME preserves current locked policy, namespace and checkpoint.")
	if resumed.success:
		check(resumed.service._prior == CharacterSaveContract.decode(p._prepared.document).payload,"RESUME does not reaward or alter persisted resources/history.")
		check(resumed.session.get_actor_state(&"player").progression.get("mana_recovery_units") == 123456,"Nonzero authoritative Mana remainder survives cold RESUME.")
		check(resumed.movement.wave_entry_state() == motion_before,"Nonzero Running/recovery state and RNG survive cold RESUME exactly.")
		var authorization: Dictionary = resumed.session.get_abandon_run_authorization()
		check(authorization.success,"Explicit source-verified unfinished-run authorization.")
		if authorization.success:
			var restarted := start(fixture.storage,"dev_normal",1,latest,true,true,authorization.checkpoint,service_factory)
			check(restarted.success,"Confirmed NEW RUN uses actual admission boundary.")
			if restarted.success:
				var next: Observed = restarted.service
				check(next.errors.is_empty(),"NEW RUN ordered boundary: "+str(next.errors))
				check(next._prior.xp == p._prior.xp and next._prior.purchases == p._prior.purchases and next._prior.items == p._prior.items,"NEW RUN preserves all committed XP, purchases, equipment/inventory and credit.")
				check(next.get_run_reward_policy().xp_multiplier == 1 and next._prior.recovery.wave_id == "wave_1" and next.run_id != p.run_id,"New unique run locks selected x1 at first Wave 1; original x10 remains historical.")
				if not next.records.is_empty(): verify(next.records.back(),next)
				for wave in range(5):
					h.helper._defeat_wave(restarted.session)
					check(restarted.session.collect_all_ground_loot().success,"Resumed new-run source loot, no reused origin IDs.")
					check(restarted.session.request_next_wave().success,"New-run continuation/completion at actual wave boundary.")
				check(next._prior.recovery.phase == "complete" and next.errors.is_empty(),"Complete circuit captured under locked x1; unsupported boss rewards remain blocked by the existing source policy.")
				check(h.helper._failures.is_empty(),"Completion used actual source combat: "+str(h.helper._failures))
				if not next.records.is_empty(): verify(next.records.back(),next)
				metrics.append({"fixture":"new_run_x1_complete","boundaries":next.measures})
	return {"success":true}

func stale_publication(root: String) -> void:
	var store := CharacterSaveStorage.new(root)
	var first := start(store,"normal",1)
	if not first.success: check(false,"First race admission."); return
	var helper := Historical.new().helper
	helper._defeat_wave(first.session)
	check(helper._failures.is_empty(),"Race occurs at a legal actual post-wave boundary.")
	var second := start(store,"normal",null,{},false)
	if not second.success: check(false,"Second race admission."); return
	var parent: Dictionary = first.service.observer.current_copy()
	var peer_result := {}
	# Distinct valid commands race for the same acknowledged legacy generation.
	# Only the existing coordinator performs either publication.
	first.service.before_commit = func():
		peer_result["result"] = second.session.request_character_development("preferences",{"order":["nac","block","soak","dodge"]},"45q_peer")
	var losing: Dictionary = first.session.request_character_development("preferences",{"order":["nac","dodge","block","soak"]},"45q_stale")
	check(peer_result.get("result",{}).get("persistence",{}).get("success",false) and not losing.get("persistence",{}).get("success",true),"A competing valid writer wins; stale/conflicting candidate cannot publish: "+str(peer_result)+" / "+str(losing))
	check(first.service.observer.current_copy() == parent,"Failed legacy publication never advances dormant compact authority.")
	check(not first.service.observer.adopt(first.service.last_prepared).success,"Unacknowledged stale candidate cannot be adopted.")
	var latest: Dictionary = CharacterSaveContract.decode(CharacterSaveStorage.history_records(store.inspect_profile("prod_vaelis_thorn")).back().document).payload
	check(not second.service._prepared.is_empty() and latest == CharacterSaveContract.decode(second.service._prepared.document).payload and latest.xp == parent.current.xp,"Only the winner's original history reaches disk, with unchanged XP.")
