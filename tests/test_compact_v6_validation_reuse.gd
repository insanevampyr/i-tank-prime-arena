extends "res://tests/test_compact_v6_incremental_snapshot.gd"
const Oracle = preload("res://tests/oracles/compact_v6_full_45y.gd")
const Trace = preload("res://tests/compact_v6_perf_trace.gd")

class Metered extends X:
	func prepare(expected_head: String) -> Dictionary:
		Trace.reset()
		var result := super.prepare(expected_head)
		if result.success and result.has("metrics"): result.metrics["proof_calls"] = Trace.snapshot().stages
		return result
	func prepare_credit(session: ArenaCombatSession, expected_head: String, confirmation: Callable = Callable()) -> Dictionary:
		Trace.reset()
		var result := super.prepare_credit(session,expected_head,confirmation)
		if result.success and result.has("metrics"): result.metrics["proof_calls"] = Trace.snapshot().stages
		return result

class CheckedService extends Observed:
	func _make_observer() -> RefCounted:
		var adapter := Metered.new(self,witness.read)
		if OS.get_environment("ARENA45Y_CHECKED") == "1":
			var enabled: Dictionary = adapter.call("enable_checked")
			if not enabled.success: errors.append(enabled)
		return adapter

func factory(store: CharacterSaveStorage, _mode: String, _parent: Dictionary) -> Observed:
	var p := CheckedService.new()
	if witnesses.has(store._root): p.witness = witnesses[store._root]
	else: witnesses[store._root] = p.witness
	services.append(p)
	return p

func probes(p: Observed, built: Dictionary) -> void:
	super.probes(p,built)
	if OS.get_environment("ARENA45Y_CHECKED")!="1": return
	check(not Package.build_checked(RefCounted.new(),p.observer._s2,p.observer._s2_pending).success,"Caller flags/foreign context cannot select checked packaging")
	var context: RefCounted=p.observer._checked
	var input: Dictionary=context.package_input(p.observer._s2,p.observer._s2_pending)
	check(input.success,"Actual issued checked representation can supply immutable bytes")
	if input.success:
		input.record.accounting.expc_available+=1; input.entries.clear()
		check(p.observer.check(built.prepared,p.observer.head()).success,"Returned dictionary mutation cannot poison owned proof")
	for mutation: String in ["parent","pending","request","ownership","source","cancel"]:
		var w:=Witness.new(); w.value=p.witness.read()
		var adapter:=X.new(p,w.read)
		check(adapter.enable_checked().success,"Independent full-cold proof context "+mutation)
		adapter.observe(p.host.get_ref())
		var ready:=adapter.prepare(adapter.head())
		check(ready.success,"Owned candidate in checked invalidation probe "+mutation)
		if not ready.success: continue
		var before_source:=p.source; var before_request:=p._prepared.duplicate(true)
		match mutation:
			"parent": adapter._s2._parent.current.generation+=1
			"pending":
				var body: Dictionary=adapter._s2_pending.copy(); body.candidate_text+=" ";body.candidate_digest=body.candidate_text.sha256_text()
				adapter._s2._pending=adapter._s2.Prepared.new(body)
			"request": p._prepared.document+=" "
			"ownership": w.value.owner+="changed"
			"source": p.source=p.source.duplicate(true);p.source.attributes.end+=1
			"cancel": adapter.cancel()
		check(not Package.build_checked(adapter._checked,adapter._s2,adapter._s2_pending).success,"W consumer independently rejects stale checked proof: "+mutation)
		check(not adapter.check(ready.prepared,adapter.head()).success,"Checked proof cannot survive changed "+mutation)
		p.source=before_source;p._prepared=before_request
		check(not adapter.check(ready.prepared,adapter.head()).success,"Changed operation cannot regain proof reuse by resetting inputs")

func run() -> Array[String]:
	var result := super.run()
	sealed_request_contract()
	var signatures: Array=[]
	for p: Observed in services:
		if p.observer == null: continue
		var current: Dictionary = p.observer.current_copy()
		if current.is_empty(): continue
		var full := Oracle.encode(current,p.source)
		check(full.success,"Frozen original full encoder accepts complete current character")
		if full.success:
			check(full.text == p.observer._ctx.text.split("\n")[1],"Frozen full oracle produces byte-identical canonical candidate")
			signatures.append({"profile":p.profile_id,"run":p.run_id,"generation":current.current.generation,"record_sha256":full.text.sha256_text(),"package_sha256":p.observer._ctx.text.sha256_text(),"head_sha256":p.observer.head().sha256_text()})
		for kind: String in ["ids","accounting","growth","items"]:
			var bad:=current.duplicate(true)
			match kind:
				"ids": bad.applied_ids.append(bad.applied_ids[0].duplicate(true))
				"accounting": bad.accounting.expc_available+=1
				"growth":
					if bad.evidence.growth.is_empty(): continue
					bad.evidence.growth[0].hpb+=1
				"items": bad.current.items.append(bad.current.items[0].duplicate(true))
			check(Oracle.validate(bad,p.source)==V6.validate(bad,p.source),"Frozen full rejection result/reason remains identical: "+kind)
	print("45Y_CHECKS "+JSON.stringify({"assertions":assertions,"failures":failures,"signatures":signatures,"optimized":OS.get_environment("ARENA45Y_CHECKED")=="1"}))
	return result

func sealed_request_contract() -> void:
	# The original complete seal decoder is the serialization oracle for any
	# in-memory representation; correct serialization grants no authority.
	var cases: Array = [
		{"binding":{"nested":[{"n":1.0,"fraction":0.5}],"unicode":"rún / Ω","negative_zero":-0.0},"candidate_text":"quotes \" slash \\ newline\nΩ","candidate_digest":"digest"},
		{"binding":{},"candidate_text":"{}","candidate_digest":"digest"},
		{"binding":{},"candidate_text":"","candidate_digest":"digest"},
		{"binding":{},"candidate_text":"{}","candidate_digest":""},
		{"binding":[],"candidate_text":"{}","candidate_digest":"digest"},
		{"binding":{},"candidate_text":"{}","candidate_digest":"digest","extra":{"preserved":true}},
		{"binding":{},"candidate_text":null,"candidate_digest":false},
		{},
	]
	for body: Dictionary in cases:
		var original := JSON.stringify(body,"",true,true)
		var expected: Dictionary=CharacterSaveContract._normalize_json_numbers(JSON.parse_string(original))
		var request: RefCounted=X.S2.Prepared.new(body)
		check(request.bytes()==original and request._bytes==original and request.digest()==original.sha256_text(),"Z exact original seal bytes/digest for normal and fallback shapes")
		check(request.copy()==expected,"Z copy equals original full decoder, including numeric normalization")
		var copy: Dictionary=request.copy()
		if copy.get("binding") is Dictionary: copy.binding["changed"]=true
		copy["candidate_text"]="changed"; copy["extra"]="changed"
		body["binding"]={"caller":"changed"};body["candidate_text"]="changed"
		request._bytes="forged"
		check(request.bytes()==original and request.copy()==expected,"Z caller aliases and returned copies cannot mutate the original seal")
		var lifetime: WeakRef = weakref(request);request=null
		check(lifetime.get_ref()==null,"Z sealed operation has no self-retaining reference")
