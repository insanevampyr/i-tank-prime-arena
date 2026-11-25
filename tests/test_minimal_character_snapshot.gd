extends RefCounted
const Codec = preload("res://scripts/rewards/minimal_character_snapshot.gd")
const V6 = preload("res://scripts/rewards/compact_character_v6_prototype.gd")
const Oracle = preload("res://tests/oracles/compact_v6_full_45y.gd")
const Q = preload("res://tests/test_compact_v6_gameplay_candidate.gd")
const H = preload("res://tests/test_historical_vaelis_admission.gd")
const L = preload("res://tests/test_legacy_to_compact_v6.gd")
const Convert = preload("res://scripts/rewards/legacy_to_compact_v6_prototype.gd")
const Credit = preload("res://scripts/rewards/character_expc_credit.gd")
const Native = preload("res://scripts/rewards/compact_v6_fixed_credit.gd")
const W = preload("res://tests/test_compact_v6_snapshot_package.gd")
var failures: Array[String]=[]
var assertions:=0
var metrics: Array=[]
var examples: Dictionary={}
var root: String

func check(ok: bool, label: String) -> void:
	assertions+=1
	if not ok: failures.append(label)

func make(r: Dictionary, source: CombatCharacterDefinitionResource) -> Dictionary:
	var e: Dictionary=r.evidence.duplicate(true);e.erase("credit_predecessor")
	return Codec.assemble(r.current,e,r.operations,r.head.epoch,source)

func target(r: Dictionary) -> Dictionary:
	return PlayableCharacterAdmission.prepare_starter(&"vaelis_thorn",r.current.profile_namespace,r.current.lineage.baseline_digest)

func exercise(label: String, r: Dictionary, source: CombatCharacterDefinitionResource) -> void:
	var original_hash:=V6.digest(r);var source_hash:=V6.digest(source.to_dictionary())
	var oracle:=Oracle.validate(r,source)
	check(oracle.success,"Independent frozen V6 reference accepts "+label)
	if not oracle.success: return
	var b:=make(r,source);var profile: String=r.current.character_id;var scope: String=r.current.profile_namespace
	var started:=Time.get_ticks_usec();var cold:=Codec.validate(b,source,profile,scope)
	var validation_ms:=float(Time.get_ticks_usec()-started)/1000.0
	check(cold.success,"Independent new cold check "+label+": "+str(cold))
	if not cold.success: return
	check(cold.snapshot.projection()==V6._projection(r),"Complete original character projection: "+label)
	check(cold.snapshot.copy().lifetime_ids==r.applied_ids,"Every original lifetime ID/binding: "+label)
	check(cold.snapshot.copy().evidence.order==r.evidence.order,"Original END/HPB/WIS/award order: "+label)
	check(not b.evidence.has("credit_predecessor") and not b.has("head") and not b.has("accounting"),"No ancestor snapshot/receipt chain/second accounting authority: "+label)
	var memory:=OS.get_static_memory_usage()
	started=Time.get_ticks_usec();var encoded:=Codec.encode(b,source,profile,scope)
	var encode_ms:=float(Time.get_ticks_usec()-started)/1000.0
	check(encoded.success,"Canonical encode "+label)
	if not encoded.success: return
	started=Time.get_ticks_usec();var decoded:=Codec.decode(encoded.text,source,profile,scope)
	var decode_ms:=float(Time.get_ticks_usec()-started)/1000.0
	check(decoded.success and decoded.snapshot.copy()==b,"Exact independent decode "+label)
	if not decoded.success: return
	check(Codec.encode(decoded.snapshot.copy(),source,profile,scope).text==encoded.text,"Deterministic byte-identical round trip "+label)
	started=Time.get_ticks_usec();var byte_read:=Codec.decode_bytes(encoded.text.to_utf8_buffer(),source,profile,scope)
	var bytes_ms:=float(Time.get_ticks_usec()-started)/1000.0
	check(byte_read.success,"Safe UTF-8 byte admission "+label)
	byte_read.clear()
	var old_text: String=Oracle.encode(r,source).text
	check(not Codec.decode(old_text,source,profile,scope).success,"New reader never reinterprets V6")
	var old_profile:=CharacterSaveContract.encode(V6._projection(r))
	check(old_profile.success and not Codec.decode(old_profile.text,source,profile,scope).success,"New reader never reinterprets V2/V4/V5")
	check(not CharacterSaveContract.decode(encoded.text).success,"Production legacy reader still rejects new dormant domain")
	var copy: Dictionary=decoded.snapshot.copy();copy.current.xp.unspent+=1
	var projection: Dictionary=decoded.snapshot.projection();projection.items.clear()
	decoded.snapshot._json="forged"
	check(decoded.snapshot.copy()==b and decoded.snapshot.projection()==V6._projection(r),"No mutable references escape owned record")
	check(V6.digest(r)==original_hash and V6.digest(source.to_dictionary())==source_hash,"No source or original character mutation")
	if label=="dev_normal_next":
		DirAccess.make_dir_recursive_absolute(root)
		var file:=FileAccess.open(root.path_join("cold.json"),FileAccess.WRITE);file.store_string(encoded.text);file.close()
		var output: Array=[]
		var code:=OS.execute(OS.get_executable_path(),["--headless","--path",ProjectSettings.globalize_path("res://"),"--script","res://tests/minimal_snapshot_cold_process.gd","--",root,profile,scope,r.current.lineage.baseline_digest,encoded.text.sha256_text()],output,true)
		check(code==0 and str(output).contains("46B_COLD_PROCESS_PASS"),"Independent process has no prior verification/cache/authority flags: "+str(output))
	var samples: Array=[]
	if label in ["normal_next","original233","inventory1005"]:
		for n in range(3):
			started=Time.get_ticks_usec();var v:=Codec.validate(b,source,profile,scope);var vm:=float(Time.get_ticks_usec()-started)/1000.0
			started=Time.get_ticks_usec();var e:=Codec.encode(b,source,profile,scope);var em:=float(Time.get_ticks_usec()-started)/1000.0
			started=Time.get_ticks_usec();var d:=Codec.decode(encoded.text,source,profile,scope);var dm:=float(Time.get_ticks_usec()-started)/1000.0
			check(v.success and e.success and d.success and e.text==encoded.text,"Repeated cold proof has no cached flag or semantic/byte drift")
			samples.append({"validate_ms":vm,"encode_ms":em,"decode_ms":dm})
	metrics.append({"fixture":label,"items":r.current.items.size(),"ids":r.applied_ids.size(),"operations":r.operations.size(),"old_v6_bytes":old_text.to_utf8_buffer().size(),"bytes":encoded.text.to_utf8_buffer().size(),"body_bytes":cold.snapshot.json().to_utf8_buffer().size(),"validate_ms":validation_ms,"encode_ms":encode_ms,"decode_ms":decode_ms,"decode_bytes_ms":bytes_ms,"samples":samples,"net_live_bytes":OS.get_static_memory_usage()-memory,"process_native_peak":OS.get_static_memory_peak_usage(),"sha256":encoded.text.sha256_text()})
	examples[label]={"body":b,"source":source,"text":encoded.text,"original":r}

func run() -> Array[String]:
	var prior: Array=[PlayableCharacterPersistence.test_storage,PlayableCharacterPersistence.test_run_id,PlayableCharacterPersistence.test_nonpersistent]
	PlayableCharacterPersistence.test_nonpersistent=false
	root=OS.get_cache_dir().path_join("itank-storage-tests/minimal46b_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()])
	var h:=H.new();h.root=root.path_join("historical")
	var q:=Q.new()
	for mode: String in ["normal","dev_normal"]:
		var f:=q.start(CharacterSaveStorage.new(root.path_join(mode)),mode,1 if mode=="normal" else 10)
		check(f.get("success",false),"Real fresh "+mode+" admission")
		if not f.get("success",false): continue
		exercise(mode+"_initial",f.service.records[0],f.service.source)
		h.helper._defeat_wave(f.session)
		check(f.session.collect_all_ground_loot().success and f.session.request_next_wave().success,"Real rewards/items/next wave")
		exercise(mode+"_next",f.service.records.back(),f.service.source)
		var control:=Q.new().scenario(root.path_join(mode+"_control"),mode,1 if mode=="normal" else 10,false)
		check(control.success and control.snapshot==f.session.get_state_snapshot(),"Unobserved legacy deterministic RNG/history control")
		# The live legacy ack retains PackedStringArray values; the actual
		# document and both cold readers represent those as ordinary JSON arrays.
		var stored_control:=CharacterSaveContract.decode(CharacterSaveContract.encode(control.payload).text)
		check(stored_control.success and stored_control.payload==V6._projection(f.service.records.back()),"Complete original stored legacy progression/current resources exact")
	for version: int in [2,4]:
		var f:=h.make_history("dev_normal",Credit.BASELINE,version,"v%d" % version)
		check(f.get("success",false),"Actual historical V%d fixture" % version)
		if not f.get("success",false): continue
		var converted:=Convert.convert(f.records,"dev_normal")
		check(converted.success and converted.comparison.success,"Full independent historical comparison")
		if not converted.success: continue
		var source: CombatCharacterDefinitionResource=target(converted.record).source
		exercise("legacy_v%d" % version,converted.record,source)
		if version==2:
			var credited:=L.new().credit_history(f.records)
			check(credited.success,"Original fixed historical grant preparation")
			if credited.success:
				var c:=Convert.convert(credited.rows,"dev_normal")
				check(c.success and c.comparison.success,"V5 credited history verified before stripping predecessor")
				if c.success: exercise("historical_credit",c.record,source)
			var quote:=Native.quote(converted.record,source,null,V6)
			check(quote.success,"Source-eligible native fixed-credit quote")
			if quote.success:
				var native:=Native.build(converted.record,source,quote.quote,V6.digest(converted.record.current.recovery),V6)
				check(native.success,"Original native fixed transition")
				if native.success:
					exercise("native_credit",native.record,source)
					check(native.record.accounting.expm_total==converted.record.accounting.expm_total and native.record.accounting.expc_available==converted.record.accounting.expc_available+10000,"Credit +10000 spendable, zero EXPM")
	check(h.failures.is_empty() and h.helper._failures.is_empty() and q.failures.is_empty(),"Original fixture helpers retain every assertion")
	if OS.get_environment("ARENA46B_FROZEN")=="1": frozen()
	if examples.has("dev_normal_next"): rejection_matrix(examples.dev_normal_next)
	for label: String in ["historical_credit","native_credit","all_five","original233"]:
		if examples.has(label): chronology_rejections(examples[label])
	PlayableCharacterPersistence.test_storage=prior[0];PlayableCharacterPersistence.test_run_id=prior[1];PlayableCharacterPersistence.test_nonpersistent=prior[2]
	print("46B_METRICS "+JSON.stringify({"fixtures":metrics,"scope":"native Godot debug cold codec only, not routine save/storage/Edge","native_live":OS.get_static_memory_usage(),"native_peak":OS.get_static_memory_peak_usage()}))
	print("46B minimal snapshot: %d assertions; failures %s" % [assertions,str(failures)])
	return failures

func frozen() -> void:
	var helper:=W.new()
	var cache:=OS.get_cache_dir().path_join("itank-storage-tests/")
	for name: String in ["233","1000"]:
		var text:=helper.read_fixture(cache.path_join("compact45m_45n_session_20261117e/"+name+".json"))
		check(not text.is_empty(),"Required explicitly selected frozen disposable fixture "+name)
		if text.is_empty(): continue
		var source: CombatCharacterDefinitionResource=helper.trusted(text).source
		var decoded:=Oracle.decode(text,source)
		check(decoded.success,"Frozen independent full validator "+name)
		if decoded.success: exercise("converted"+name,decoded.record,source)
	for pair: Array in [["all_five","compact45s_bench_19316_960654/historical/v2"],["inventory1005","compact45s_bench_25204_2215533/inventory"]]:
		var text: String=helper.current_from_cache(pair[1])
		var source: CombatCharacterDefinitionResource=helper.trusted(text).source
		var decoded:=Oracle.decode(text,source)
		check(decoded.success,"Frozen native/equipment independent full validator")
		if decoded.success: exercise(pair[0],decoded.record,source)
	if examples.has("all_five"):
		var purchases: Array=examples.all_five.body.evidence.purchases
		for attr: String in ["str","dex","spd","wis","end"]: check(purchases.any(func(p): return p.purchase_kind=="attribute" and p.target_id==attr),"Actual permanent "+attr+" retained")
		check(examples.all_five.body.evidence.growth.size()>1,"Interleaved original growth retained")
	if examples.has("inventory1005"): check(examples.inventory1005.body.current.items.size()==1005,"Exact stress inventory, not whitespace padding")
	if examples.has("converted1000"):
		var b: Dictionary=examples.converted1000.body
		check(b.operations.size()==1000 and b.recent_journal.size()==20 and b.lifetime_ids.size()>1000,"Journal eviction never evicts lifetime IDs")
		var lost:=b.duplicate(true);lost.lifetime_ids.remove_at(0)
		check(not Codec.validate(lost,examples.converted1000.source,b.current.character_id,b.current.profile_namespace).success,"Evicted old operation ID remains mandatory")
	if examples.has("converted233"):
		var f: Dictionary=examples.converted233
		var b: Dictionary=f.body.duplicate(true)
		var terminal: Array=b.current.recovery.ledger.profile_ownership.items
		var zeros: Array=terminal.filter(func(item): return item.quantity==0)
		check(not zeros.is_empty(),"Original explicit fully consumed instance evidence retained")
		if not zeros.is_empty():
			terminal.erase(zeros[0])
			check(Codec.validate(b,f.source,b.current.character_id,b.current.profile_namespace).reason=="snapshot_consumption_evidence_unavailable","Missing terminal consumed row is unsupported, never invented")
			b=f.body.duplicate(true)
			var item: Dictionary=zeros[0].duplicate(true);item.quantity=1;item.equipped_slots=[];item.mutable_state={}
			b.current.items.append(item)
			check(not Codec.validate(b,f.source,b.current.character_id,b.current.profile_namespace).success,"Consumed acquisition cannot be reintroduced against terminal ownership")
	var path:=OS.get_environment("ARENA46B_LEGACY_BUNDLE").replace("\\","/").simplify_path()
	check(path.begins_with(cache+"compact45s_") and path.get_file().begins_with("restoration_") and path.ends_with(".bundle"),"Explicit original archive restricted to known disposable root")
	if path.begins_with(cache+"compact45s_") and path.ends_with(".bundle"):
		var outer: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
		check(outer.sha256==outer.body_json.sha256_text(),"Frozen original archive exact checksum")
		var rows: Array=CharacterSaveContract._normalize_json_numbers(JSON.parse_string(outer.body_json))
		var converted:=Convert.convert(rows,"dev_normal")
		check(converted.success and converted.generation_count==233 and converted.comparison.success,"Original 233-generation independent full legacy comparison")
		if converted.success: exercise("original233",converted.record,target(converted.record).source)
	check(helper.failures.is_empty(),"Frozen path isolation assertions")

func rebind(b: Dictionary) -> void:
	b.lifetime_ids=V6._ids(b)

func chronology_rejections(f: Dictionary) -> void:
	for kind: String in ["award","price","growth","wisdom","dice","hpm","order","credit","credit_generation","credit_operation"]:
		var b: Dictionary=f.body.duplicate(true)
		match kind:
			"award":
				if b.evidence.awards.is_empty(): continue
				b.evidence.awards[0].xp+=1
			"price":
				if b.evidence.purchases.is_empty(): continue
				b.evidence.purchases[0].cost+=1
			"growth":
				if b.evidence.growth.is_empty(): continue
				b.evidence.growth[0].hpb+=1
			"wisdom":
				if b.evidence.growth.is_empty(): continue
				b.evidence.growth[0].wisdom+=1
			"dice":
				if b.evidence.growth.is_empty(): continue
				b.evidence.growth[0].roll=0
			"hpm":
				if b.evidence.growth.is_empty(): continue
				b.evidence.growth[0].hpm_after+=1
			"order": b.evidence.order.reverse()
			"credit":
				if b.evidence.credit==null: continue
				b.evidence.credit.records[0].amount+=1
			"credit_generation":
				if b.evidence.credit==null: continue
				b.evidence.credit.records[0].after_generation+=1
			"credit_operation":
				if b.evidence.credit==null: continue
				b.operations[b.evidence.credit.records[0].after_generation].id+="_forged"
				b.last_operation_id=b.operations.back().id;b.recent_journal=b.operations.slice(maxi(0,b.operations.size()-20)).duplicate(true)
		rebind(b)
		var rejected:=Codec.validate(b,f.source,b.current.character_id,b.current.profile_namespace)
		check(not rejected.success,"Rebound IDs/checksum cannot legitimize "+kind)
		if kind=="credit_operation": check(rejected.reason=="snapshot_credit_operation_binding","Flat grant bound to its original committed generation/operation")

func rejection_matrix(f: Dictionary) -> void:
	var profile: String=f.body.current.character_id;var scope: String=f.body.current.profile_namespace
	for kind: String in ["source","identity","namespace","sequence","last","ids","binding","operation","journal","balance","item","origin","equipment","rng","mana","movement","phase","unknown","predecessor","creation","checkpoint","policy"]:
		var b: Dictionary=f.body.duplicate(true)
		match kind:
			"source": b.source_digest="0".repeat(64)
			"identity": b.current.character_id="other_profile"
			"namespace": b.current.profile_namespace="normal"
			"sequence": b.sequence+=1
			"last": b.last_operation_id="forged"
			"ids": b.lifetime_ids.append(b.lifetime_ids[0].duplicate(true))
			"binding": b.lifetime_ids[0].record_digest="0".repeat(64)
			"operation": b.operations.append(b.operations[0].duplicate(true));b.sequence+=1;b.current.generation+=1
			"journal": b.recent_journal.clear()
			"balance": b.current.xp.unspent+=1
			"item": b.current.items[0].quantity+=1
			"origin": b.current.items[0].provenance.origin_id="forged_origin"
			"equipment": b.current.permanent.equipment_refs.append("unverified_equipment")
			"rng": b.current.recovery.rng.seed="999999"
			"mana": b.current.recovery.player.resources.mana=999999
			"movement": b.current.recovery.movement.profile.end+=1
			"phase": b.current.recovery.phase="combat"
			"unknown": b.verified=true
			"predecessor": b.evidence.credit_predecessor={"forged":true}
			"creation": b.current.base_attributes.end+=1
			"checkpoint": b.current.recovery={}
			"policy": b.current.recovery.ledger.xp_multiplier=999
		check(not Codec.validate(b,f.source,profile,scope).success,"Reject "+kind)
	check(not Codec.decode(f.text,f.source,"prod_vaelis_thorn","normal").success,"Explicit cross-target admission cannot switch namespace")
	check(not Codec.validate(f.body,null,profile,scope).success,"Missing trusted source rejected")
	check(not Codec.validate(f.body,f.source,profile,"test").success,"TEST never admitted as a persistent character")
	for field: String in ["source_digest","epoch","last_operation_id"]:
		var b: Dictionary=f.body.duplicate(true);b[field]=[]
		check(not Codec.validate(b,f.source,profile,scope).success,"Wrong scalar metadata type: "+field)
	for field: String in ["character_id","profile_namespace","rules_revision","generation"]:
		var b: Dictionary=f.body.duplicate(true);b.current[field]=[]
		check(not Codec.validate(b,f.source,profile,scope).success,"Wrong character scalar type: "+field)
	var malformed: Dictionary=f.body.duplicate(true);malformed.current.lineage.baseline_digest=[]
	check(not Codec.validate(malformed,f.source,profile,scope).success,"Wrong source-lineage scalar type")
	for kind: String in ["level","refs","lineage","ledger","item","resource"]:
		var b: Dictionary=f.body.duplicate(true)
		match kind:
			"level": b.current.permanent.erase("level")
			"refs": b.current.permanent.equipment_refs=[7]
			"lineage": b.current.lineage=[]
			"ledger": b.current.recovery.ledger="bad"
			"item": b.current.items=[null]
			"resource": b.current.permanent.resource_maxima=[]
		check(not Codec.validate(b,f.source,profile,scope).success,"Malformed nested fields reject safely: "+kind)
	for kind: String in ["format","version","reader","checksum","truncated","duplicate_outer","duplicate_body","noncanonical","malformed"]:
		var text: String=f.text;var outer: Dictionary=JSON.parse_string(text)
		match kind:
			"format": outer.format="itank_arena_character"
			"version": outer.version=6
			"reader": outer.reader_version=2
			"checksum": outer.sha256="0".repeat(64)
			"truncated": text=text.left(text.length()-1)
			"duplicate_outer": text=text.insert(1,'"format":"'+Codec.FORMAT+'",')
			"duplicate_body":
				outer.body_json=outer.body_json.insert(1,'"epoch":"duplicate",');outer.sha256=outer.body_json.sha256_text()
			"noncanonical": text+=" "
			"malformed": text="{]\n"
		if kind in ["format","version","reader","checksum","duplicate_body"]: text=JSON.stringify(outer,"",true,true)
		check(not Codec.decode(text,f.source,profile,scope).success,"Reject file "+kind)
	check(Codec.decode(" ".repeat(Codec.MAX_FILE_BYTES+1),f.source,profile,scope).reason=="snapshot_file_limit","Finite file bound before parsing")
	var large:=JSON.stringify({"format":Codec.FORMAT,"version":1,"reader_version":1,"body_json":" ".repeat(Codec.MAX_BODY_BYTES+1),"sha256":"0".repeat(64)},"",true,true)
	check(Codec.decode(large,f.source,profile,scope).reason=="snapshot_body_limit","Separate finite decoded body bound")
	var oversized: Dictionary=f.body.duplicate(true);oversized.current.lineage.run_id="x".repeat(Codec.MAX_STRING_BYTES+1)
	check(not Codec.validate(oversized,f.source,profile,scope).success,"Finite individual field bound")
	var entries: Array=[];entries.resize(Codec.MAX_ENTRIES+1)
	oversized=f.body.duplicate(true);oversized.operations=entries
	check(not Codec.validate(oversized,f.source,profile,scope).success,"Finite section entry bound")
	check(Codec._utf8("ASCII Ω 😀".to_utf8_buffer()),"Valid multibyte UTF-8 accepted")
	for bytes: PackedByteArray in [PackedByteArray([255]),PackedByteArray([192,128]),PackedByteArray([237,160,128]),PackedByteArray([244,144,128,128]),PackedByteArray([226,130])]:
		check(Codec.decode_bytes(bytes,f.source,profile,scope).reason=="snapshot_invalid_utf8","Reject invalid/overlong/surrogate UTF-8 without decoding")
	for number: Variant in [NAN,INF,9007199254740992]:
		var b: Dictionary=f.body.duplicate(true);b.current.xp.unspent=number
		check(not Codec.validate(b,f.source,profile,scope).success,"Reject unsafe/nonfinite numeric data")
	var deep: Array=[];var tail: Array=deep
	for i in range(Codec.MAX_DEPTH+2):
		var next: Array=[];tail.append(next);tail=next
	var bad: Dictionary=f.body.duplicate(true);bad.current.deep=deep
	check(not Codec.validate(bad,f.source,profile,scope).success,"Finite nesting depth")
	for label: String in ["legacy_v2","legacy_v4","native_credit"]:
		if examples.has(label): check(not examples[label].body.evidence.has("credit_predecessor"),"Flat evidence only for "+label)
