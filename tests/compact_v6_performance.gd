extends RefCounted
const V6 = preload("res://scripts/rewards/compact_character_v6_prototype.gd")
const Oracle = preload("res://tests/oracles/compact_v6_linear_45p.gd")
const OldCoordinator = preload("res://tests/oracles/character_coordinator_linear_45p.gd")
const Portable = preload("res://tests/compact_v6_portable_backup.gd")
const Trace = preload("res://tests/compact_v6_perf_trace.gd")
const Disk = preload("res://tests/compact_v6_backup_store.gd")

static func next(record: Dictionary, id: String, source: CombatCharacterDefinitionResource) -> Dictionary:
	var r := record.duplicate(true)
	r.head.sequence += 1; r.head.parent_digest = V6.digest(record); r.current.generation += 1
	r.operations.append({"id":id,"request_digest":V6.digest({"kind":"disposable_noop_checkpoint","id":id})})
	return V6.assemble(r.current,r.evidence,r.operations,r.head,source)

static func stats(samples: Array) -> Dictionary:
	var sorted := samples.duplicate(); sorted.sort()
	if sorted.is_empty(): return {}
	return {"n":samples.size(),"p50_ms":sorted[int(ceil(sorted.size()*0.5))-1],"p95_ms":sorted[int(ceil(sorted.size()*0.95))-1],"max_ms":sorted.back(),"samples_ms":samples}

static func slim(result: Dictionary) -> Dictionary:
	var out := result.duplicate()
	if out.has("actor"): out.actor = out.actor.to_dictionary()
	return out

static func sample(args: Dictionary, source: CombatCharacterDefinitionResource) -> Dictionary:
	if args.kind == "perf_equivalence": return equivalence(args.text,source)
	if args.kind == "perf_reset": Trace.reset(); return {"success":true}
	if args.kind == "perf_snapshot":
		var snap := Trace.snapshot(); Trace.enabled = false; return {"success":true,"trace":snap}
	if args.kind == "perf_next":
		var input := V6.decode(args.text,source)
		return V6.encode(next(input.record,args.id,source),source) if input.success else input
	var decoded := V6.decode(args.text,source)
	if not decoded.success: return decoded
	var record: Dictionary = decoded.record
	var history: Array = args.get("history",[])
	var candidate := next(record,"perf_next",source)
	var output := {"success":true,"kind":args.kind,"operations":record.operations.size(),"ids":record.applied_ids.size(),"transitions":history.size(),"samples":{},"traces":{},"record_hash":V6.digest(record)}
	Trace.reset()
	for stage: String in (["history"] if args.kind == "perf_history" else ["construct","encode","decode","validate","extension","oracle_extension"]):
		var times: Array = []
		Trace.reset()
		for i in range(int(args.get("samples",3))):
			var t := Time.get_ticks_usec(); var r: Variant
			match stage:
				"construct": r = next(record,"perf_next",source)
				"encode": r = V6.encode(candidate,source)
				"decode": r = V6.decode(args.text,source)
				"validate": r = V6.validate(candidate,source)
				"extension": r = V6.validate_extension(record,candidate,source)
				"oracle_extension": r = Oracle.validate_extension(record,candidate,source)
				"history": r = Portable.verify_history(record,history,source)
			times.append(float(Time.get_ticks_usec()-t)/1000.0)
			if r is Dictionary and r.has("success") and not r.success: Trace.enabled = false; return r
		output.samples[stage] = stats(times)
		output.traces[stage] = Trace.snapshot()
	output.trace = Trace.snapshot(); Trace.enabled = false
	output.canonical_hash = V6.encode(candidate,source).text.sha256_text()
	output.accounting = candidate.accounting.duplicate()
	return output

static func build(root: String, source: CombatCharacterDefinitionResource, original: String) -> Dictionary:
	if not Disk.allowed(root): return {"success":false,"reason":"disposable_root_required"}
	Trace.enabled = false
	DirAccess.make_dir_recursive_absolute(root)
	var large := V6.decode(FileAccess.get_file_as_string(original.path_join("1000.json")),source)
	if not large.success: return large
	write(root.path_join("ops1000.json"),V6.encode(large.record,source).text)
	# Core endpoint stress only. Not a portable 10,000-generation conversion:
	# intermediate compact ancestry is intentionally not claimed or fabricated.
	var stress: Dictionary = large.record.duplicate(true)
	for i in range(stress.operations.size(),10000): stress.operations.append({"id":"stress_noop_%d" % i,"request_digest":V6.digest({"disposable_noop":i})})
	stress.head.sequence = stress.operations.size()-stress.head.legacy_operation_count+1
	stress.head.parent_digest = V6.digest({"core_endpoint_only":9999})
	stress.current.generation = stress.operations.size()
	stress = V6.assemble(stress.current,stress.evidence,stress.operations,stress.head,source)
	var encoded := V6.encode(stress,source)
	if not encoded.success: return encoded
	write(root.path_join("ops10000.json"),encoded.text)
	var base := V6.decode(FileAccess.get_file_as_string(original.path_join("small.json")),source)
	if not base.success: return base
	if not FileAccess.file_exists(root.path_join("chain501.history")):
		var cursor: Dictionary = base.record
		var history: Array = []
		for i in range(501):
			var candidate := next(cursor,"lineage_%d" % i,source)
			var step := Portable.transition(cursor,candidate,source)
			if not step.success: return step
			history.append(step.transition); cursor = candidate
			if i+1 in [100,501]:
				write(root.path_join("chain%d.json" % (i+1)),V6.encode(cursor,source).text)
				write(root.path_join("chain%d.history" % (i+1)),JSON.stringify(history,"",true,true))
	if not FileAccess.file_exists(root.path_join("awards.json")):
		var generator := preload("res://tests/test_compact_character_v6.gd").new()
		var steps: Array = []
		for i in range(200):
			steps.append("award")
			if i in [30,90]: steps.append("end")
			if i == 60: steps.append("wis")
		var high := generator.fixture(steps)
		if not generator.failures.is_empty(): return {"success":false,"reason":"fixture_failed","failures":generator.failures}
		encoded = V6.encode(high.record,source)
		if not encoded.success: return encoded
		write(root.path_join("awards.json"),encoded.text)
	# Valid synthetic acquisition-instance stress, not a gameplay award command.
	var inv: Dictionary = base.record.duplicate(true)
	var payload := V6._projection(inv)
	var template := {}
	for item: Dictionary in payload.items:
		if item.definition_id == "prime_v3_gold": template = item; break
	if template.is_empty(): return {"success":false,"reason":"gold_fixture_missing"}
	for i in range(1000):
		var item: Dictionary = template.duplicate(true)
		item.instance_id = payload.character_id+"/"+payload.recovery.run_id+"/wave_1/stress_gold_%d" % i
		item.provenance.origin_id = item.instance_id; item.quantity = 1
		payload.items.append(item)
		payload.permanent.inventory_quantities.prime_v3_gold += 1
		payload.settlements.append({"version":1,"receipt_id":item.instance_id,"profile_id":payload.character_id,"run_id":payload.recovery.run_id,"wave_id":"wave_1","claim_id":"stress_gold_%d" % i,"kind":"currency","content":{"instance_id":item.instance_id,"definition_id":item.definition_id,"quantity":1,"provenance_digest":V6.digest(item.provenance)}})
	inv.current = preload("res://scripts/rewards/legacy_to_compact_v6_prototype.gd").Conversion.strip(payload)
	inv.evidence.settlements = payload.settlements
	inv = V6.assemble(inv.current,inv.evidence,inv.operations,inv.head,source)
	encoded = V6.encode(inv,source)
	if not encoded.success: return encoded
	write(root.path_join("inventory.json"),encoded.text)
	return {"success":true,"fixture_root":root,"files":["ops1000","ops10000","chain100","chain501","awards","inventory"]}

static func write(path: String, value: String) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE); file.store_string(value); file.close()

static func equivalence(text: String, source: CombatCharacterDefinitionResource) -> Dictionary:
	Trace.enabled = false
	var parsed := Oracle.decode(text,source)
	if not parsed.success: return parsed
	var previous: Dictionary = parsed.record
	var candidate := next(previous,"equivalence_next",source)
	var before_hash := V6.digest([previous,candidate,source.to_dictionary()])
	var failures: Array = []; var count := 0
	for name: String in ["valid","missing_id","duplicate_id","reordered_ids","conflicting_id","reused_operation","changed_request","duplicate_award","duplicate_purchase","changed_growth","missing_growth","reordered_order","stale_head","changed_bytes"]:
		var c: Dictionary = candidate.duplicate(true)
		match name:
			"missing_id": c.applied_ids.pop_front()
			"duplicate_id": c.applied_ids.append(c.applied_ids[0])
			"reordered_ids": c.applied_ids.reverse()
			"conflicting_id": c.applied_ids[0].record_digest = "0".repeat(64)
			"reused_operation": c = next(previous,previous.operations[0].id,source)
			"changed_request":
				c.operations[0].request_digest = "0".repeat(64)
				c = V6.assemble(c.current,c.evidence,c.operations,c.head,source)
			"duplicate_award":
				if c.evidence.awards.is_empty(): continue
				c.evidence.awards.append(c.evidence.awards[0]); c = V6.assemble(c.current,c.evidence,c.operations,c.head,source)
			"duplicate_purchase":
				if c.evidence.purchases.is_empty(): continue
				c.evidence.purchases.append(c.evidence.purchases[0]); c = V6.assemble(c.current,c.evidence,c.operations,c.head,source)
			"changed_growth", "missing_growth":
				if c.evidence.growth.is_empty(): continue
				if name == "changed_growth": c.evidence.growth[0].hpb += 1
				else: c.evidence.growth.pop_front()
				c = V6.assemble(c.current,c.evidence,c.operations,c.head,source)
			"reordered_order": c.evidence.order.reverse()
			"stale_head": c.head.parent_digest = "0".repeat(64)
			"changed_bytes": c.current.xp.unspent += 1
		var a := slim(Oracle.validate_extension(previous,c,source))
		var b := slim(V6.validate_extension(previous,c,source))
		count += 1
		if a != b or (name == "valid" and not b.success) or (name != "valid" and b.success): failures.append({"case":name,"old":a,"new":b})
		# Rehashed envelopes must not turn rejected semantic evidence into truth.
		var body := JSON.stringify(c,"",true,true)
		var envelope := JSON.stringify({"format":"itank_arena_character","version":6,"payload_json":body,"sha256":body.sha256_text()},"",true,true)
		count += 1
		if Oracle.decode(envelope,source) != V6.decode(envelope,source): failures.append({"case":name,"kind":"decode_difference"})
	var old_encoded := Oracle.encode(candidate,source)
	count += 1
	if old_encoded != V6.encode(candidate,source): failures.append({"case":"canonical_bytes"})
	var modified_source := source.duplicate(true)
	modified_source.attributes.wis += 1
	count += 1
	if slim(Oracle.validate(candidate,modified_source)) != slim(V6.validate(candidate,modified_source)): failures.append({"case":"changed_source"})
	var p := V6._projection(previous); var q := V6._projection(candidate)
	for kind: String in ["valid","missing","duplicate","reorder","alter","unknown_extra","missing_identifier"]:
		var c := q.duplicate(true)
		match kind:
			"missing": c.settlements.pop_front()
			"duplicate": c.settlements.append(c.settlements[0])
			"reorder": c.settlements.reverse()
			"alter": c.settlements[0].content["unapproved"] = 1
			"unknown_extra": c.settlements.append({"receipt_id":"unused","unapproved":true})
			"missing_identifier": c.settlements.append({"unapproved":true})
		count += 2
		if OldCoordinator._validate_continuity(p,c) != CharacterPersistenceCoordinator._validate_continuity(p,c): failures.append({"case":"continuity_"+kind})
		if OldCoordinator._validate_receipts(c) != CharacterPersistenceCoordinator._validate_receipts(c): failures.append({"case":"receipts_"+kind})
	count += 1
	if before_hash != V6.digest([previous,candidate,source.to_dictionary()]): failures.append({"case":"input_mutation"})
	return {"success":failures.is_empty(),"assertions":count,"failures":failures,"canonical_hash":old_encoded.text.sha256_text(),"accounting":candidate.accounting,"inventory_digest":V6.digest(candidate.current.items),"growth_digest":V6.digest(candidate.evidence.growth)}
