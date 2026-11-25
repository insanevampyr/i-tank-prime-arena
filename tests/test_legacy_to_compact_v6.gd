extends RefCounted

const Convert = preload("res://scripts/rewards/legacy_to_compact_v6_prototype.gd")
const Compare = preload("res://scripts/rewards/compact_v6_equivalence.gd")
const V6 = preload("res://scripts/rewards/compact_character_v6_prototype.gd")
const Historical = preload("res://tests/test_historical_vaelis_admission.gd")
const Credit = preload("res://scripts/rewards/character_expc_credit.gd")
const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
var failures: Array[String] = []
var assertions := 0

func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok: failures.append(message)

func approve(binding: Dictionary) -> Dictionary:
	return {"confirmed":true,"binding":Credit.digest(binding)}

func run() -> Array[String]:
	var old_storage := PlayableCharacterPersistence.test_storage
	var old_run := PlayableCharacterPersistence.test_run_id
	var old_nonpersistent := PlayableCharacterPersistence.test_nonpersistent
	var h := Historical.new()
	h.root = OS.get_cache_dir().path_join("itank-storage-tests/compact45l_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()])
	PlayableCharacterPersistence.test_nonpersistent = false
	var legacy_fixtures := {}
	for mode: String in ["normal","dev_normal"]:
		for version: int in [2,4]:
			var f := h.make_history(mode,Credit.BASELINE,version,"%s_%d" % [mode,version])
			check(f.get("success",false),"Independent disposable legacy history builds.")
			if not f.get("success",false): continue
			legacy_fixtures[mode+str(version)] = f
			var input_digest := V6.digest(f.records)
			var job := Convert.begin(f.records,mode)
			while job.result.get("state") == "pending": job.step()
			var result: Dictionary = job.result
			check(result.success,"Convert %s V%d: %s" % [mode,version,result if not result.success else result.comparison])
			if not result.success: continue
			check(V6._projection(result.record) == f.payload,"Every original current-head value matches exactly.")
			check(result.record.operations.size() == f.records.size() and result.record.head.sequence == 1,"Original transactions remain lifetime bindings; conversion creates no fictional compact predecessor.")
			check(V6.decode(result.text,job.source).get("success",false),"Converted record independently decodes.")
			check(not CharacterSaveContract.decode(result.text).success,"Production reader still rejects dormant V6.")
			check(V6.digest(f.records) == input_digest,"Conversion never edits original generations.")
			var repeat := Convert.convert(f.records,mode)
			check(repeat.success and repeat.record == result.record and repeat.text == result.text,"Repeated immutable conversion is byte/semantic identical.")
			independent_checks(f,result,job.source)
	if legacy_fixtures.has("dev_normal2"):
		var f: Dictionary = legacy_fixtures.dev_normal2
		var credited := credit_history(f.records)
		check(credited.get("success",false),"A genuine late fixed credit binds its real predecessor.")
		if credited.get("success",false):
			var result := Convert.convert(credited.rows,"dev_normal")
			check(result.success,"Late V2-to-V5 credit conversion: %s" % (result if not result.success else result.comparison))
			if result.success:
				check(result.record.accounting.expm_total == f.payload.xp.earned and result.record.accounting.expc_available == f.payload.xp.unspent+10000,"Late credit increases EXPC only, with original expenditure intact.")
				check(result.metrics.get("deduplicated_credit_ledger_bytes",0) > 0,"Unchanged predecessor ledger prefixes reconstruct exactly without duplicate storage.")
				credit_rejections(result,credited.rows)
				cancellation_and_changes(credited.rows,result)
		var complex := complex_history(h,f)
		if complex.get("success",false):
			rejections(complex.rows)
			ambiguous_history(complex.rows)
			var rows: Array = extend_preferences(complex.rows,400)
			for count: int in [168,221,233,400]:
				var selection: Array = rows.slice(0,count)
				var result := Convert.convert(selection,"dev_normal")
				check(result.success,"Dense %d-generation conversion: %s" % [count,result if not result.success else result.comparison])
				if result.success:
					print("45L_METRICS "+JSON.stringify(result.metrics.merged({"generations":count,"lifetime_ids":result.record.applied_ids.size(),"growth_records":result.record.evidence.growth.size(),"purchases":result.record.evidence.purchases.size(),"awards":result.record.evidence.awards.size(),"development_commands":result.record.current.permanent.get("development",{}).get("commands",[]).size(),"scope":"native debug, in-memory disposable records, not Edge or Windows release"})))
					check(V6._projection(result.record) == CharacterSaveContract.decode(selection.back().document).payload,"Dense fixture preserves whole current state exactly.")
					check(result.metrics.compact_bytes < result.metrics.legacy_bytes,"Dense archive shrinks without dropping lifetime evidence.")
					if count == 233:
						var repeated := Convert.convert(selection,"dev_normal")
						check(repeated.success and repeated.text == result.text,"Dense conversion remains deterministic.")
						credit_rejections(result,selection)
						cancellation_and_changes(selection,result)
	if legacy_fixtures.has("dev_normal4"):
		var credited := credit_history(legacy_fixtures.dev_normal4.records)
		var result := Convert.convert(credited.rows,"dev_normal") if credited.get("success",false) else credited
		check(result.success,"V4-to-V5 late credit preserves mixed policy history: %s" % result.get("reason"))
		if result.success: check(result.record.current.run_reward_policy == legacy_fixtures.dev_normal4.payload.run_reward_policy,"Credit conversion never reassigns a run multiplier.")
	credit_after_attributes(h)
	check(h.failures.is_empty() and h.helper._failures.is_empty(),"Reused gameplay/history fixtures have no hidden failures: %s / %s" % [h.failures,h.helper._failures])
	PlayableCharacterPersistence.test_storage = old_storage
	PlayableCharacterPersistence.test_run_id = old_run
	PlayableCharacterPersistence.test_nonpersistent = old_nonpersistent
	check(h.root.begins_with(OS.get_cache_dir().path_join("itank-storage-tests/compact45l_")),"Cleanup restricted to unique disposable fixture root.")
	h.helper._remove_fixture(h.root)
	check(not DirAccess.dir_exists_absolute(h.root),"Disposable fixtures removed; original source arrays remain untouched.")
	print("45L legacy-to-V6: %d assertions." % assertions)
	return failures

func independent_checks(f: Dictionary, converted: Dictionary, source: CombatCharacterDefinitionResource) -> void:
	var verifier := func(_op: String,binding: String): return {"authorized":true,"binding":binding,"lineage":f.payload.lineage}
	var original := CharacterProfileProjection.hydrate(f.payload,source,f.profile,PlayableCharacterAdmission.RULES,verifier)
	check(original.success,"Independent expected actor comes from the original fixture, not conversion.")
	if not original.success: return
	var altered: Dictionary = converted.record.duplicate(true)
	altered.current.recovery.player.current_hpc -= 1
	check(V6.validate(altered,source).success,"A different but individually valid current HPC demonstrates the need for comparison.")
	check(Compare.compare(altered,f.payload,original.actor_definition,{},source,f.records).get("reason") == "legacy_projection_mismatch","Independent comparison catches a valid-looking changed current resource.")
	var actor: CombatActorDefinition = original.actor_definition
	actor.combat_stats.acc += 1
	check(Compare.compare(converted.record,f.payload,actor,{},source,f.records).get("reason") == "permanent_or_equipment_adjusted_actor_mismatch","Independent comparison includes actual equipment-adjusted combat values.")

func credit_history(rows: Array) -> Dictionary:
	var before: Dictionary = CharacterSaveContract.decode(rows.back().document).payload
	var credit := Credit.prepare(before,approve)
	if not credit.success: return credit
	var result := rows.duplicate(true)
	result.append({"generation":credit.payload.generation,"transaction_id":credit.transaction_id,"document":CharacterSaveContract.encode(credit.payload).text})
	return {"success":true,"rows":result,"credit":credit}

func complex_history(h: RefCounted, f: Dictionary) -> Dictionary:
	var quoted := Credit.prepare(f.payload,approve)
	if not quoted.success: check(false,"Late fixture grant prepares."); return {}
	var prepared := CharacterPersistenceCoordinator.prepare(quoted.payload,quoted.payload.settlements,quoted.transaction_id,f.payload.generation,f.payload.secured_checkpoints)
	var verifier := func(_op: String,binding: String): return {"authorized":true,"binding":binding,"lineage":quoted.payload.lineage}
	var source: CombatCharacterDefinitionResource = PlayableCharacterAdmission.prepare_starter(&"vaelis_thorn","dev_normal",Credit.BASELINE).source
	var published := CharacterPersistenceCoordinator.new(f.storage).commit(prepared.prepared,source,f.profile,PlayableCharacterAdmission.RULES,verifier)
	check(published.success,"Fixed late credit publishes only to this disposable fixture through existing coordinator.")
	if not published.success: return {}
	PlayableCharacterPersistence.test_storage = f.storage
	var scene: Node = h.web.make_scene()
	var c: ArenaCombatController = scene.get_node("CombatController")
	c.set_physics_process(false)
	var admitted := c._admit_existing_profile("dev_normal")
	check(admitted.success,"Admit credited disposable history.")
	if not admitted.success: h.helper._free(scene); return {}
	c._run_choice_dialog.get_ok_button().pressed.emit()
	var session := c._session
	check(session.request_character_advancement(&"attribute",&"end","45l_end7",{"expected_current_value":6,"expected_cost":3000}).success,"END6->7 before later level gains.")
	check(session.request_character_advancement(&"attribute",&"wis","45l_wis11",{"expected_current_value":10,"expected_cost":3000}).success,"WIS10->11 with no historical recomputation.")
	check(session.request_next_wave().success,"Real next wave preserves source-qualified progression.")
	h.helper._defeat_wave(session)
	check(session.collect_all_ground_loot().success,"Actual item acquisitions retain original instance/provenance receipts.")
	check(session.request_character_advancement(&"attribute",&"end","45l_end8",{"expected_current_value":7,"expected_cost":3000}).success,"END7->8 after newly recorded growth.")
	check(session.request_next_wave().success,"Future wave uses purchased END8 and WIS11.")
	h.helper._defeat_wave(session)
	check(session.collect_all_ground_loot().success,"Later source-qualified awards and items remain distinct.")
	check(session._playable_persistence._prior.permanent.growth.any(func(row): return row.hpb == 2),"A real future level gain uses END8 HPB2.")
	var player := session.get_actor_state(&"player")
	# Established source-valid item fixture path: real creation/collection,
	# provenance receipts and ordinary consumable effects, no direct inventory edits.
	var origin := session.simulation.record_reward_event(&"reward_persistence_item_fixture",&"player",&"player",{})
	for ref: String in ["health_potion","prime_v3_metal_buckler"]:
		session.simulation.create_ground_loot_item("45l_item_"+ref,{"definition_id":ref,"quantity":2 if ref == "health_potion" else 1,"display_name":ref,"item_kind":"potion" if ref == "health_potion" else "equipment","source_ref":"PRIME-V3 pp. 120, 137; isolated source item fixture"},player.position_microfeet,&"player",origin.event_id)
	check(session.collect_all_ground_loot().success,"Verified fixture item acquisitions use real ground ownership receipts.")
	check(session.request_player_weapon_handling(Fixture.VAELIS_WAND_REF,"stow","45l_free_hand").success,"Free a legal healing hand through the shared engine.")
	for index in range(2):
		player.current_hpc = 3
		var potion := session.request_player_inventory_consumable_use(&"health_potion","45l_potion_%d" % index)
		check(potion.success,"Actual potion consumption uses existing rules: %s" % potion)
	check(player.inventory_quantities.get("health_potion",0) == 0,"A fully consumed acquisition remains in lifetime evidence.")
	check(session.request_player_inventory_unequip(Fixture.VAELIS_WAND_REF,"45l_unequip").success,"Actual equipment change preserves the instance.")
	check(session.request_player_inventory_equip(Fixture.VAELIS_WAND_REF,"45l_reequip").success,"Actual re-equipping does not create another item.")
	check(session.request_player_inventory_equip(&"prime_v3_metal_buckler","45l_buckler").success,"Equipment instance and condition remain source-backed.")
	# Existing supported remainder/state fields are captured through the normal
	# fixture checkpoint; conversion does not update or advance them.
	player.progression["mana_recovery_units"] = 123456
	check(session.request_character_development("preferences",{"order":["nac","block","dodge","soak"]},"45l_preferences").success,"Persist legitimate preferences and existing resource remainder.")
	var inspection: Dictionary = f.storage.inspect_profile(f.profile)
	var rows := CharacterSaveStorage.history_records(inspection)
	check(inspection.success and not rows.is_empty(),"Complex source history remains valid in existing storage.")
	h.helper._free(scene)
	return {"success":inspection.success,"rows":rows}

func extend_preferences(input: Array, count: int) -> Array:
	var rows := input.duplicate(true)
	var payload: Dictionary = CharacterSaveContract.decode(rows.back().document).payload
	while rows.size() < count:
		var id := "45l_preference_%d" % rows.size()
		var order: Array = ["nac","dodge","block","soak"] if rows.size()%2 == 0 else ["nac","block","soak","dodge"]
		var development := CharacterDevelopment.append(payload.permanent.development,id,"preferences",{"order":order})
		check(development.success,"Dense fixture adds a genuine independent development command, not padding.")
		payload.generation += 1
		payload.permanent.development = development.record
		payload.recovery.player.development = development.record.duplicate(true)
		var encoded := CharacterSaveContract.encode(payload)
		check(encoded.success,"Dense disposable generation is source-format valid.")
		rows.append({"generation":payload.generation,"transaction_id":id,"document":encoded.text})
	return rows

func credit_rejections(converted: Dictionary, rows: Array) -> void:
	var source: CombatCharacterDefinitionResource = PlayableCharacterAdmission.prepare_starter(&"vaelis_thorn","dev_normal",Credit.BASELINE).source
	check(V6.decode(converted.text,source).success,"Late historical credit proof independently decodes without the old archive.")
	for kind: String in ["missing_basis","prefix_count","basis_generation","basis_xp","ledger_reference","original_binding","duplicate_credit"]:
		var bad: Dictionary = converted.record.duplicate(true)
		match kind:
			"missing_basis": bad.evidence.credit_predecessor = null
			"prefix_count": bad.evidence.credit_predecessor.counts.awards += 1
			"basis_generation": bad.evidence.credit_predecessor.current.generation -= 1
			"basis_xp": bad.evidence.credit_predecessor.current.xp.unspent += 1
			"ledger_reference": bad.evidence.credit_predecessor.current.recovery.ledger.awards = {"v6_current_ledger_prefix":1000000}
			"original_binding": bad.evidence.credit.records[0].head_digest = "0".repeat(64)
			"duplicate_credit": bad.evidence.credit.records.append(bad.evidence.credit.records[0].duplicate(true))
		check(not V6.validate(bad,source).success,"Reject changed historical credit evidence: "+kind)
	check(converted.record.operations.back().request_digest == rows.back().document.sha256_text(),"Legacy operation binds original bytes, not a fabricated request.")
	print("45L_CREDIT_PROOF "+JSON.stringify({"generation_count":rows.size(),"grant_after_generation":converted.record.evidence.credit.records[0].after_generation,"precredit_purchase_count":converted.record.evidence.credit_predecessor.counts.purchases,"deduplicated_ledger_bytes":converted.metrics.get("deduplicated_credit_ledger_bytes",0)}))

func cancellation_and_changes(rows: Array, completed: Dictionary) -> void:
	var original_digest := V6.digest(rows)
	var job := Convert.begin(rows,"dev_normal")
	job.step()
	check(job.cancel().get("state") == "canceled" and job.step().get("state") == "canceled","Cancellation remains terminal and returns no artifact.")
	check(not job.result.has("record") and V6.digest(rows) == original_digest,"Canceled conversion changes no source generation.")
	if rows.size() < 40:
		for stage: String in ["convert","verify","source_check"]:
			job = Convert.begin(rows,"dev_normal")
			while job.result.get("state") == "pending" and job.result.stage != stage: job.step()
			check(job.result.get("state") == "pending" and job.cancel().get("state") == "canceled" and not job.result.has("record") and job._record.is_empty(),"Cancel during %s releases staged output and exposes no artifact." % stage)
	var interrupted := Convert.begin(rows,"dev_normal")
	interrupted.step(); interrupted = null
	var restarted := Convert.convert(rows,"dev_normal")
	check(restarted.success and restarted.text == completed.text,"Interrupted in-memory conversion restarts deterministically without effects.")
	var changed := rows.duplicate(true)
	job = Convert.begin(changed,"dev_normal")
	job.step()
	changed[0].document += " " # valid JSON, different original bytes
	while job.result.get("state") == "pending": job.step()
	check(job.result.get("reason") == "source_changed_during_conversion" and not job.result.has("record"),"Changing an already processed source row prevents completion.")
	changed = rows.duplicate(true)
	job = Convert.begin(changed,"dev_normal")
	changed.append(changed.back())
	check(job.step().get("reason") == "source_changed_during_conversion","Changing source length is detected before validation proceeds.")
	changed = rows.duplicate(true)
	job = Convert.begin(changed,"dev_normal")
	changed[0].transaction_id = "changed_identity"
	check(job.step().get("reason") == "source_changed_during_conversion","Changing source transaction metadata rejects before decoding.")

func raw_replace(rows: Array, index: int, payload: Dictionary) -> void:
	var outer: Dictionary = JSON.parse_string(rows[index].document)
	outer.payload_json = JSON.stringify(payload,"",true,true)
	outer.sha256 = outer.payload_json.sha256_text()
	rows[index].document = JSON.stringify(outer,"",true,true)

func rejections(rows: Array) -> void:
	check(not CharacterSaveContract.decode(rows.back().document).payload.purchases.is_empty(),"Duplicate-purchase fixture contains genuine original purchases.")
	for kind: String in ["gap","duplicate_transaction","truncated","checksum","unsupported_version","duplicate_award","duplicate_purchase","conflicting_receipt","missing_credit_predecessor","wrong_credit_binding"]:
		var bad := rows.duplicate(true)
		var last: Dictionary = CharacterSaveContract.decode(bad.back().document).payload
		match kind:
			"gap": bad.remove_at(1)
			"duplicate_transaction": bad[1].transaction_id = bad[0].transaction_id
			"truncated": bad[-1].document = bad[-1].document.left(40)
			"checksum", "unsupported_version":
				var outer: Dictionary = JSON.parse_string(bad[-1].document)
				if kind == "checksum": outer.sha256 = "0".repeat(64)
				else: outer.version = 99
				bad[-1].document = JSON.stringify(outer)
			"duplicate_award": last.permanent.award_receipts.append(last.permanent.award_receipts[0]); raw_replace(bad,bad.size()-1,last)
			"duplicate_purchase": last.purchases.append(last.purchases[0]); raw_replace(bad,bad.size()-1,last)
			"conflicting_receipt": last.settlements[0].content.quantity += 1; raw_replace(bad,bad.size()-1,last)
			"missing_credit_predecessor": bad.remove_at(bad.size()-2)
			"wrong_credit_binding": last.expc_credits.records[0].head_digest = "0".repeat(64); raw_replace(bad,bad.size()-1,last)
		var result := Convert.convert(bad,"dev_normal")
		check(not result.success and not result.has("record") and result.has("reason"),"Damaged source fails without an artifact: %s / %s" % [kind,result.get("reason")])
	check(not Convert.convert(rows,"normal").success,"Namespace crossover rejects.")
	check(not Convert.convert([],"normal").success,"Missing history rejects.")

func ambiguous_history(rows: Array) -> void:
	# This reconstructed fixture combines an existing WIS purchase and a later
	# award into one generation. Existing arithmetic may be valid, but no new
	# chronology evidence is invented by the converter.
	var previous := {}
	var purchase_index := -1
	var award_index := -1
	var before_awards := 0
	for index in range(rows.size()):
		var payload: Dictionary = CharacterSaveContract.decode(rows[index].document).payload
		var delta: Array = payload.purchases.slice(previous.get("purchases",[]).size())
		if purchase_index == -1 and delta.any(func(p): return p.target_id == "wis"):
			purchase_index = index; before_awards = payload.permanent.award_receipts.size()
		elif purchase_index >= 0 and payload.permanent.award_receipts.size() > before_awards:
			award_index = index; break
		previous = payload
	check(purchase_index > 0 and award_index > purchase_index,"Ambiguity fixture has separately verified purchase and award boundaries.")
	if purchase_index < 1 or award_index < 0: return
	var coalesced: Array = rows.slice(0,purchase_index).duplicate(true)
	var payload: Dictionary = CharacterSaveContract.decode(rows[award_index].document).payload
	payload.generation = coalesced.size()+1
	coalesced.append({"generation":payload.generation,"transaction_id":"45l_coalesced","document":rows[award_index].document})
	raw_replace(coalesced,coalesced.size()-1,payload)
	check(Convert.convert(coalesced,"dev_normal").get("reason") == "unsupported_ambiguous_purchase_award_order","Coalesced evidence receives a precise unsupported result instead of invented order.")

func credit_after_attributes(h: RefCounted) -> void:
	var f: Dictionary = h.make_history("dev_normal",Credit.BASELINE,2,"credit_after_attributes")
	check(f.get("success",false),"Build independent uncredited source for a post-purchase grant.")
	if not f.get("success",false): return
	PlayableCharacterPersistence.test_storage = f.storage
	var scene: Node = h.web.make_scene()
	var c: ArenaCombatController = scene.get_node("CombatController")
	c.set_physics_process(false)
	var admission := c._admit_existing_profile("dev_normal")
	check(admission.success,"Admit uncredited fixture to earn purchase funds normally.")
	if not admission.success: h.helper._free(scene); return
	c._run_choice_dialog.get_ok_button().pressed.emit()
	var session := c._session
	for wave in range(3):
		if session.get_reward_state().unspent_xp >= 6000: break
		check(session.request_next_wave().success,"Earn source-valued funds before either END/WIS purchase or credit.")
		h.helper._defeat_wave(session)
		check(session.collect_all_ground_loot().success,"Secure earned items without changing prior acquisitions.")
	check(session.request_character_advancement(&"attribute",&"end","45l_precredit_end",{"expected_current_value":6,"expected_cost":3000}).success,"END purchase precedes the first and only grant.")
	check(session.request_character_advancement(&"attribute",&"wis","45l_precredit_wis",{"expected_current_value":10,"expected_cost":3000}).success,"WIS purchase precedes the first and only grant.")
	var rows := CharacterSaveStorage.history_records(f.storage.inspect_profile(f.profile))
	h.helper._free(scene)
	var credited := credit_history(rows)
	check(credited.get("success",false),"Pure fixed-credit contract binds the actual post-purchase predecessor.")
	if not credited.get("success",false): return
	var converted := Convert.convert(credited.rows,"dev_normal")
	check(converted.success,"Late credit after END/WIS progression converts: %s" % converted.get("reason"))
	if converted.success:
		check(converted.record.evidence.credit_predecessor.counts.purchases >= 2,"Credit proof retains actual pre-grant purchase counts.")
		credit_rejections(converted,credited.rows)
