extends RefCounted

const V6 = preload("res://scripts/rewards/compact_character_v6_prototype.gd")
const Mana = preload("res://tests/test_wisdom_mana_replay.gd")
const Credit = preload("res://scripts/rewards/character_expc_credit.gd")
const Profiles = preload("res://scripts/rewards/character_profile_projection.gd")
const Historical = preload("res://tests/test_historical_vaelis_admission.gd")
var failures: Array[String] = []
var assertions := 0

func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok: failures.append(message)

func receipt(payload: Dictionary, kind: String, content: Dictionary, claim: String) -> Dictionary:
	return {"version":1,"receipt_id":"%s/%s/wave_1/%s" % [payload.character_id,payload.lineage.run_id,claim],"profile_id":payload.character_id,"run_id":payload.lineage.run_id,"wave_id":"wave_1","claim_id":claim,"kind":kind,"content":content}

# New, explicitly ordered disposable facts; no archive converter or owner data.
# Awards are source-valued DEV goblins (10 x 10), not arbitrary funding entries.
func fixture(steps: Array, generation_count: int = 1) -> Dictionary:
	var f := Mana.new().history([])
	var p: Dictionary = f.payload
	var starter := PlayableCharacterAdmission.prepare_starter(&"vaelis_thorn","dev_normal",Credit.BASELINE)
	var order: Array = [{"kind":"credit","id":Credit.GRANT_ID}]
	var snapshots: Array = [p.duplicate(true)]
	var earned := 0
	var spent := 0
	var award_number := 0
	for step: String in steps:
		p.generation += 1
		if step in ["end","wis"]:
			var value: int = f.actor.attributes[step]
			var price: int = PrimeV3AdvancementCatalog.attribute_cost(value)
			var applied: Dictionary = f.actor.apply_verified_endurance_advancement(value,value+1) if step == "end" else f.actor.apply_verified_wisdom_advancement(value,value+1)
			check(applied.success,"Fixture source-qualified purchase.")
			var row := {"purchase_id":"dev_vaelis_thorn/starter_admission/%s_%d" % [step,value],"purchase_kind":"attribute","target_id":step,"value_before":value,"value_after":value+1,"cost":price,"source_ref":PrimeV3AdvancementCatalog.PURCHASE_SOURCE_REF}
			p.purchases.append(row)
			p.settlements.append(receipt(p,"purchase",{"purchase_id":row.purchase_id,"cost":price},"buy_%s_%d" % [step,value]))
			order.append({"kind":"purchase","id":row.purchase_id})
			spent += price
			f.state.progression.run_spent_xp = spent
			f.state.progression.expc = 10000+earned-spent
		else:
			award_number += 1
			var id := "dev_vaelis_thorn/starter_admission/run_fixture/wave_1/defeat/wave_1_common_goblin_%d" % award_number
			var old_growth: int = f.state.progression.history.size()
			earned += 100
			check(f.sim.apply_character_experience_award(&"player",id,100,earned,spent).success,"Fixture uses real level-up logic and original seeded HD rolls.")
			p.permanent.award_receipts.append({"award_id":id,"xp":100})
			p.settlements.append(receipt(p,"xp",{"award_id":id,"amount":100},"award_%d" % award_number))
			order.append({"kind":"award","id":id})
			for index in range(old_growth,f.state.progression.history.size()):
				var raw: Dictionary = f.state.progression.history[index]
				var row := {"growth_id":"dev_vaelis_thorn/starter_admission/growth_%d" % raw.level}
				for field: String in Profiles.HISTORY_FIELDS: row[field] = raw[field]
				p.permanent.growth.append(row)
				order.append({"kind":"growth","id":row.growth_id})
		p.xp = {"earned":earned,"spent":spent,"unspent":10000+earned-spent}
		p.permanent.xp_baseline = {"expm":0,"expc":0,"earned":earned,"spent":spent}
		p.permanent.resource_maxima = f.actor.resource_maxima.duplicate(true)
		p.permanent.level = f.state.progression.level
		snapshots.append(p.duplicate(true))
	while snapshots.size() < generation_count:
		p.generation += 1
		snapshots.append(p.duplicate(true))
	var operations: Array = []
	for index in range(snapshots.size()): operations.append({"id":"checkpoint_%d" % index,"request_digest":V6.digest({"fixture_checkpoint":index})})
	f["order"] = order
	f["operations"] = operations
	f["snapshots"] = snapshots
	f["credit_predecessor"] = starter.prepared.payload
	f["record"] = pack(p,order,operations,f.credit_predecessor,f.source)
	return f

func pack(payload: Dictionary, order: Array, operations: Array, credit_basis: Variant, source: CombatCharacterDefinitionResource, parent: Variant = null) -> Dictionary:
	var current := payload.duplicate(true)
	var e := {"awards":current.permanent.award_receipts,"growth":current.permanent.growth,"purchases":current.purchases,"settlements":current.settlements,"credit":current.get("expc_credits"),"credit_predecessor":credit_basis,"order":order}
	current.erase("purchases"); current.erase("settlements"); current.erase("expc_credits")
	current.permanent.erase("growth"); current.permanent.erase("award_receipts")
	return V6.assemble(current,e,operations,{"epoch":"isolated_pass_a","sequence":operations.size(),"parent_digest":parent if operations.size() == 1 else (V6.digest({"fixture_parent":operations.size()-1}) if parent == null else parent)},source)

func reseal(record: Dictionary, source: CombatCharacterDefinitionResource) -> Dictionary:
	return V6.assemble(record.current,record.evidence,record.operations,record.head,source)

func run() -> Array[String]:
	var f := fixture(["end","award","wis","end","award","award","award","award"],232)
	var record: Dictionary = f.record
	var untouched := record.duplicate(true)
	var checked := V6.validate(record,f.source)
	check(checked.success,"232-generation fixture compact validation: %s" % checked)
	if not checked.success: return failures
	# Independent expected values: original END6/WIS10/HPM9/Mana20.
	check(checked.actor.attributes.end == 8 and checked.actor.attributes.wis == 11,"Permanent END/WIS replay.")
	check(checked.actor.resource_maxima.mana == 51,"WIS +1 once; three original level gains of 10, without final-WIS reinterpretation.")
	check(record.accounting == {"initial_expm":0,"initial_expc":0,"earned_award_xp":500,"credit_expc":10000,"spent_expc":9000,"expm_total":500,"expc_available":1500},"EXPM, expenditure, EXPC-only credit and available EXPC independently calculated.")
	check(record.evidence.growth.map(func(row): return row.hpb) == [1,2,2],"END7 plateau and END8 transition preserve historical HPB.")
	check(checked.actor.get_combat_stat("hpm") == 9+record.evidence.growth[0].roll+1+record.evidence.growth[1].roll+2+record.evidence.growth[2].roll+2,"Original creation HPM and original Hit Dice are preserved.")
	check(f.state.resources.mana == 2 and f.source.attributes.end == 6 and f.source.attributes.wis == 10,"No current Mana refill or source mutation.")
	check(record.recent_journal.size() == 20 and record.operations.size() == 232,"Only journal bounded; lifetime operation registry keeps all 232 IDs.")
	check(record.applied_ids.any(func(row): return row.scope == "operation" and row.id == "checkpoint_0"),"Evicted operation remains exactly tracked.")
	var encoded := V6.encode(record,f.source)
	check(encoded.success,"Encode valid V6.")
	if not encoded.success: return failures
	var decoded := V6.decode(encoded.text,f.source)
	check(decoded.success and decoded.record == record,"Deterministic lossless V6 decode.")
	check(V6.encode(decoded.record,f.source).text == encoded.text,"Byte-identical encoding after decode.")
	check(not CharacterSaveContract.decode(encoded.text).success,"Playable legacy dispatcher still rejects dormant V6.")
	check(not V6.decode(encoded.text.left(encoded.text.length()-1),f.source).success,"Truncation rejects.")
	var outer: Dictionary = JSON.parse_string(encoded.text)
	outer.sha256 = "0".repeat(64)
	check(not V6.decode(JSON.stringify(outer),f.source).success,"Checksum rejects.")
	outer.version = 7
	check(not V6.decode(JSON.stringify(outer),f.source).success,"Unknown envelope version rejects.")
	check(not V6.decode('{"format":1,"format":2}',f.source).success,"Duplicate JSON keys reject.")
	check(not V6.decode("[".repeat(65)+"]".repeat(65),f.source).success,"Excessive nesting rejects.")
	var unicode := record.duplicate(true)
	unicode.operations[0].id = "checkpoint_Ω😀\"\\"
	unicode = reseal(unicode,f.source)
	var unicode_text := V6.encode(unicode,f.source)
	check(unicode_text.success and V6.decode(unicode_text.text,f.source).record == unicode,"UTF-8 and escaped IDs preserve exact bytes and bindings.")
	var cloned_source: CombatCharacterDefinitionResource = f.source.duplicate(true)
	check(V6.decode(encoded.text,cloned_source).success,"Trusted source comparison uses source content, not object identity.")
	cloned_source.attributes.wis += 1
	check(not V6.decode(encoded.text,cloned_source).success,"A changed source cannot authorize imported evidence.")
	for kind: String in ["missing_id","altered_id_binding","duplicate_operation","duplicate_award","duplicate_purchase","duplicate_credit","missing_growth","tamper_hpb","tamper_wis","tamper_roll","tamper_cost","tamper_xp","tamper_balance","missing_order","conflicting_order","credit_binding","credit_expm","missing_settlement","forged_settlement","wrong_source","unknown_field","malformed_evidence"]:
		var bad := record.duplicate(true)
		match kind:
			"missing_id": bad.applied_ids.pop_front()
			"altered_id_binding": bad.applied_ids[0].record_digest = "0".repeat(64)
			"duplicate_operation": bad.operations.append(bad.operations[0])
			"duplicate_award": bad.evidence.awards.append(bad.evidence.awards[0])
			"duplicate_purchase": bad.evidence.purchases.append(bad.evidence.purchases[0])
			"duplicate_credit": bad.evidence.credit.records.append(bad.evidence.credit.records[0])
			"missing_growth": bad.evidence.growth.pop_back()
			"tamper_hpb": bad.evidence.growth[0].hpb = 2
			"tamper_wis": bad.evidence.growth[0].wisdom = 11
			"tamper_roll": bad.evidence.growth[0].roll = 7
			"tamper_cost": bad.evidence.purchases[0].cost -= 1
			"tamper_xp": bad.evidence.awards[0].xp += 1
			"tamper_balance": bad.accounting.expc_available += 1
			"missing_order": bad.evidence.order.pop_front()
			"conflicting_order": bad.evidence.order.reverse()
			"credit_binding": bad.evidence.credit.records[0].head_digest = "0".repeat(64)
			"credit_expm": bad.current.xp.earned += 10000
			"missing_settlement": bad.evidence.settlements.pop_back()
			"forged_settlement": bad.evidence.settlements.back().content.amount += 1
			"wrong_source": bad.source_digest = "0".repeat(64)
			"unknown_field": bad["verified"] = true
			"malformed_evidence": bad.evidence.growth = [null]
		check(not V6.validate(bad,f.source).success,"Fail closed: "+kind)
		# Updating all local integrity hashes must not bypass semantic validation.
		if kind.begins_with("tamper_") and kind != "tamper_balance":
			check(not V6.validate(reseal(bad,f.source),f.source).success,"Rehashed semantic tamper rejects: "+kind)
	continuity(f)
	for kind: String in ["credit_type","settlement_content","equipment_type","missing_level","missing_xp","operation_type","growth_number","award_number","purchase_number","order_type"]:
		var malformed := record.duplicate(true)
		match kind:
			"credit_type": malformed.evidence.credit = 1
			"settlement_content": malformed.evidence.settlements[0].content = "not a receipt"
			"equipment_type": malformed.current.permanent.equipment_refs = 1
			"missing_level": malformed.current.permanent.erase("level")
			"missing_xp": malformed.current.erase("xp")
			"operation_type": malformed.operations[0] = null
			"growth_number": malformed.evidence.growth[0].roll = 1.5
			"award_number": malformed.evidence.awards[0].xp = -1
			"purchase_number": malformed.evidence.purchases[0].cost = "3000"
			"order_type": malformed.evidence.order[0] = null
		check(not V6.validate(malformed,f.source).success,"Malformed inputs fail closed without runtime errors: "+kind)
	var unfunded := record.duplicate(true)
	var credit_first: Dictionary = unfunded.evidence.order.pop_front()
	unfunded.evidence.order.append(credit_first)
	check(not V6.validate(reseal(unfunded,f.source),f.source).success,"A future EXPC-only credit cannot pay for an earlier unaffordable purchase.")
	additional_histories()
	checkpoint_fixtures()
	var dense_steps: Array = ["end","award","wis","end","award","award","award","award"]
	for index in range(195): dense_steps.append("award")
	var dense := fixture(dense_steps,232)
	var dense_output := V6.encode(dense.record,dense.source)
	check(dense_output.success and dense.record.evidence.awards.size() == 200,"Benchmark includes 200 distinct source-valued awards, not whitespace padding.")
	if dense_output.success: measure(dense,dense_output.text)
	check(record == untouched,"Validation/encoding/decoding leave input unchanged.")
	print("45K compact V6: %d assertions." % assertions)
	return failures

func continuity(f: Dictionary) -> void:
	var previous: Dictionary = f.record
	var p: Dictionary = f.payload.duplicate(true)
	p.generation += 1
	var operations: Array = f.operations.duplicate(true)
	operations.append({"id":"checkpoint_next","request_digest":V6.digest({"next":true})})
	var next := pack(p,f.order,operations,f.credit_predecessor,f.source,V6.digest(previous))
	check(V6.validate_extension(previous,next,f.source).success,"Pure next-generation extension accepts unchanged committed progress.")
	check(not V6.validate_extension(next,next,f.source).success,"Retry against the already accepted head cannot apply the candidate a second time.")
	check(not V6.validate_extension(next,previous,f.source).success,"Older record cannot replace a known newer head.")
	for kind: String in ["stale","wrong_parent","old_operation","changed_request","missing_lifetime_id","replayed_award","replayed_purchase","replayed_item_origin","rewritten_plateau"]:
		var bad := next.duplicate(true)
		match kind:
			"stale": bad.head.sequence -= 1
			"wrong_parent": bad.head.parent_digest = "0".repeat(64)
			"old_operation": bad.operations[-1] = previous.operations[0]
			"changed_request": bad.operations[0].request_digest = "0".repeat(64)
			"missing_lifetime_id": bad.applied_ids.pop_front()
			"replayed_award": bad.evidence.awards.append(bad.evidence.awards[0])
			"replayed_purchase": bad.evidence.purchases.append(bad.evidence.purchases[0])
			"replayed_item_origin": bad.evidence.settlements.append(bad.evidence.settlements[0])
			"rewritten_plateau":
				# END6 and END7 share HPB1. A plausible alternative order must
				# not replace a known immutable prefix despite identical totals.
				var order: Array = bad.evidence.order
				var temporary: Dictionary = order[1]
				order[1] = order[2]; order[2] = order[3]; order[3] = temporary
		if kind != "missing_lifetime_id": bad = reseal(bad,f.source)
		check(not V6.validate_extension(previous,bad,f.source).success,"Never reapply/rewrite lifetime effects under a new request: "+kind)
	check(not V6.validate_extension(previous,next,f.source).has("published"),"Prototype never performs publication.")

func additional_histories() -> void:
	for steps: Array in [["award","end","end","award"],["end","end","award","wis","award","award"],["wis","award","end","award","end","award"],["wis","award","wis","award","award"],["wis"]]:
		var f := fixture(steps)
		var result := V6.validate(f.record,f.source)
		check(result.success,"Explicit purchases before/after growth, HPB plateaus and level-one WIS: %s / %s" % [steps,result])
		if not result.success: continue
		check(result.actor.resource_maxima == f.actor.resource_maxima and result.actor.get_combat_stat("hpm") == f.actor.get_combat_stat("hpm"),"Compact replay equals original event-time actor, without rerolls.")
		check(V6.decode(V6.encode(f.record,f.source).text,f.source).success,"Each historical arrangement roundtrips independently.")
		if steps.count("wis") == 2:
			check(result.actor.resource_maxima.mana == 43 and f.record.evidence.growth.map(func(row): return row.wisdom) == [11,12],"Independent odd/even WIS: +2 purchases, 10 then 11 Mana growth; original values retained.")
	# Uncredited V2 still works: remove only the test grant from a no-purchase
	# creation fixture, never from an owner profile or a spent credit history.
	var f := fixture([])
	var p: Dictionary = f.payload.duplicate(true)
	p.erase("expc_credits"); p.xp.unspent = 0
	var plain := pack(p,[],f.operations,null,f.source)
	check(CharacterSaveContract.decode(CharacterSaveContract.encode(p).text).version == 2,"Legacy V2 fixture remains V2.")
	check(V6.validate(plain,f.source).success,"Uncredited V2 semantic fixture validates without a credit.")

func measure(f: Dictionary, encoded: String) -> void:
	var generations: int = f.snapshots.size()
	var archive_bytes := 0
	var start := Time.get_ticks_usec()
	for payload: Dictionary in f.snapshots:
		var legacy := CharacterSaveContract.encode(payload)
		check(legacy.success,"Each disposable full historical generation encodes.")
		archive_bytes += legacy.text.to_utf8_buffer().size()
	var legacy_ms := float(Time.get_ticks_usec()-start)/1000.0
	start = Time.get_ticks_usec()
	var proof := {}
	for index in range(1,f.snapshots.size()):
		var payload: Dictionary = f.snapshots[index]
		proof = EnduranceGrowthHistory.extend(f.source,payload,f.snapshots[index-1],proof)
		check(proof.success,"Actual consecutive disposable generations independently prove END timing.")
	var historical_proof_ms := float(Time.get_ticks_usec()-start)/1000.0
	check(proof.growth == V6.validate(f.record,f.source).end_growth,"Compact explicit timeline reproduces existing generation-backed HPB evidence exactly.")
	var with_legacy := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	# Release only this in-memory benchmark archive, not files or player history.
	# The compact proof keeps all lifetime facts and IDs after release.
	f.snapshots.clear()
	var settled := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var encode_ms: Array = []
	var decode_ms: Array = []
	var validate_ms: Array = []
	var retained: Array = []
	for iteration in range(5):
		start = Time.get_ticks_usec()
		var valid := V6.validate(f.record,f.source)
		validate_ms.append(float(Time.get_ticks_usec()-start)/1000.0)
		start = Time.get_ticks_usec()
		var output := V6.encode(f.record,f.source)
		encode_ms.append(float(Time.get_ticks_usec()-start)/1000.0)
		start = Time.get_ticks_usec()
		var input := V6.decode(output.text,f.source)
		decode_ms.append(float(Time.get_ticks_usec()-start)/1000.0)
		check(valid.success and output.success and input.success,"Repeated full validation remains deterministic.")
		valid.clear(); output.clear(); input.clear()
		retained.append(int(Performance.get_monitor(Performance.MEMORY_STATIC)))
	check(encoded.to_utf8_buffer().size() < archive_bytes,"Evidence stored once is smaller than 232 cumulative complete snapshots.")
	print("45K_METRICS "+JSON.stringify({"fixture_generations":generations,"distinct_awards":f.record.evidence.awards.size(),"purchases":f.record.evidence.purchases.size(),"growth_records":f.record.evidence.growth.size(),"lifetime_ids":f.record.applied_ids.size(),"legacy_generation_bytes":archive_bytes,"legacy_encode_ms":legacy_ms,"legacy_end_proof_ms":historical_proof_ms,"v6_bytes":encoded.to_utf8_buffer().size(),"v6_payload_bytes":JSON.stringify(f.record,"",true,true).to_utf8_buffer().size(),"validate_ms":validate_ms,"encode_ms":encode_ms,"decode_ms":decode_ms,"native_static_with_legacy_archive":with_legacy,"native_static_before":settled,"native_static_after_each":retained,"native_process_static_peak":OS.get_static_memory_peak_usage(),"memory_scope":"native debug Godot allocator; includes all fixtures and preloaded suites; not Edge RSS or WASM capacity"}))

func checkpoint_fixtures() -> void:
	# Reuse the established disposable profile generator for genuine V2/V4
	# receipts, items, movement, RNG, checkpoints and namespace reward policies.
	# Only this test helper extracts first-appearance order from its own fixtures.
	var old_store := PlayableCharacterPersistence.test_storage
	var old_run := PlayableCharacterPersistence.test_run_id
	var old_nonpersistent := PlayableCharacterPersistence.test_nonpersistent
	var h := Historical.new()
	h.root = OS.get_cache_dir().path_join("itank-storage-tests/compact45k_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()])
	PlayableCharacterPersistence.test_nonpersistent = false
	for mode: String in ["normal","dev_normal"]:
		for version: int in [2,4]:
			var fixture_result := h.make_history(mode,Credit.BASELINE,version,"%s_%d" % [mode,version])
			check(fixture_result.get("success",false),"Independent disposable %s V%d history builds." % [mode,version])
			if not fixture_result.get("success",false): continue
			var payload: Dictionary = fixture_result.payload
			var starter := PlayableCharacterAdmission.prepare_starter(&"vaelis_thorn",mode,Credit.BASELINE)
			var order: Array = []
			var seen := {}
			for document: Dictionary in fixture_result.records:
				var row: Dictionary = CharacterSaveContract.decode(document.document).payload
				for award: Dictionary in row.permanent.award_receipts:
					if seen.has(award.award_id): continue
					order.append({"kind":"award","id":award.award_id}); seen[award.award_id] = true
					# Existing growth IDs preserve their causal award ID, including
					# when several awards publish together in one generation.
					for fact: Dictionary in row.permanent.growth:
						if fact.growth_id.begins_with(award.award_id+"/level_"):
							order.append({"kind":"growth","id":fact.growth_id}); seen[fact.growth_id] = true
				for fact: Dictionary in row.purchases:
					if not seen.has(fact.purchase_id):
						order.append({"kind":"purchase","id":fact.purchase_id}); seen[fact.purchase_id] = true
			var operations: Array = [{"id":"fixture_checkpoint","request_digest":V6.digest({"namespace":mode,"version":version})}]
			var record := pack(payload,order,operations,null,starter.source)
			var result := V6.validate(record,starter.source)
			check(result.success,"Existing complete checkpoint, receipts and namespace policy validate: %s" % result)
			if not result.success: continue
			var encoded := V6.encode(record,starter.source)
			var decoded := V6.decode(encoded.text,starter.source)
			check(decoded.success and decoded.record.current == record.current,"Complete current checkpoint roundtrip: resources, movement, RNG, inventory and policy unchanged.")
			check(record.accounting.expm_total == payload.xp.earned and record.accounting.expc_available == payload.xp.unspent,"Legacy namespace/V4 source-valued XP accounting exact.")
	check(h.failures.is_empty() and h.helper._failures.is_empty(),"Reused historical fixture did not hide failures.")
	PlayableCharacterPersistence.test_storage = old_store
	PlayableCharacterPersistence.test_run_id = old_run
	PlayableCharacterPersistence.test_nonpersistent = old_nonpersistent
	check(h.root.begins_with(OS.get_cache_dir().path_join("itank-storage-tests/compact45k_")),"Cleanup restricted to this test's disposable cache root.")
	h.helper._remove_fixture(h.root)
	check(not DirAccess.dir_exists_absolute(h.root),"Disposable checkpoint fixtures cleaned up.")
