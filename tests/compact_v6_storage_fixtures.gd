extends RefCounted
const L = preload("res://tests/test_legacy_to_compact_v6.gd")
const Historical = preload("res://tests/test_historical_vaelis_admission.gd")
const Convert = preload("res://scripts/rewards/legacy_to_compact_v6_prototype.gd")
const V6 = preload("res://scripts/rewards/compact_character_v6_prototype.gd")
const Disk = preload("res://tests/compact_v6_disposable_store.gd")
const Credit = preload("res://scripts/rewards/character_expc_credit.gd")

static func next(record: Dictionary, id: String, preference_count: int = 0) -> Dictionary:
	var candidate := record.duplicate(true)
	candidate.head.sequence += 1
	candidate.head.parent_digest = V6.digest(record)
	candidate.current.generation += 1
	candidate.operations.append({"id":id,"request_digest":V6.digest({"id":id,"preferences":preference_count})})
	for index in range(preference_count):
		var development := CharacterDevelopment.append(candidate.current.permanent.development,id+"_preference_%d" % index,"preferences",{"order":["nac","dodge","block","soak"]})
		if not development.success: return {}
		candidate.current.permanent.development = development.record
		candidate.current.recovery.player.development = development.record.duplicate(true)
	return V6.assemble(candidate.current,candidate.evidence,candidate.operations,candidate.head,PlayableCharacterAdmission.prepare_starter(&"vaelis_thorn","dev_normal",Credit.BASELINE).source,int(record.get("compact_version",1)))

static func build(root: String) -> Dictionary:
	if not Disk.allowed(root): return {"success":false,"reason":"invalid_fixture_root"}
	DirAccess.make_dir_recursive_absolute(root)
	var h := Historical.new()
	h.root = root.path_join("history")
	var generator := L.new()
	var old_store := PlayableCharacterPersistence.test_storage
	var old_nonpersistent := PlayableCharacterPersistence.test_nonpersistent
	var old_run := PlayableCharacterPersistence.test_run_id
	PlayableCharacterPersistence.test_nonpersistent = false
	var f := h.make_history("dev_normal",Credit.BASELINE,2,"source")
	var result := {"success":false,"reason":"fixture_generation_failed"}
	if f.get("success",false):
		var small := Convert.convert(f.records,"dev_normal")
		var complex := generator.complex_history(h,f)
		if small.success and complex.get("success",false):
			var rows: Array = generator.extend_preferences(complex.rows,400)
			var fixtures := {"small":small.text}
			for count: int in [168,221,233,400]:
				var converted := Convert.convert(rows.slice(0,count),"dev_normal")
				if not converted.success: result = converted; break
				fixtures[str(count)] = converted.text
			if fixtures.has("400"):
				for key: String in fixtures:
					var file := FileAccess.open(root.path_join(key+".json"),FileAccess.WRITE)
					file.store_string(fixtures[key]); file.close()
				result = make_thousand(root)
	PlayableCharacterPersistence.test_storage = old_store
	PlayableCharacterPersistence.test_nonpersistent = old_nonpersistent
	PlayableCharacterPersistence.test_run_id = old_run
	h.helper._remove_fixture(h.root)
	if not h.failures.is_empty() or not h.helper._failures.is_empty() or not generator.failures.is_empty(): return {"success":false,"reason":"fixture_assertions_failed","failures":h.failures+h.helper._failures+generator.failures}
	return result

static func make_thousand(root: String) -> Dictionary:
	if not Disk.allowed(root): return {"success":false,"reason":"invalid_fixture_root"}
	var source: CombatCharacterDefinitionResource = PlayableCharacterAdmission.prepare_starter(&"vaelis_thorn","dev_normal",Credit.BASELINE).source
	var base: Dictionary = V6.decode(FileAccess.get_file_as_string(root.path_join("400.json")),source).record
	var payload := V6._projection(base)
	var operations: Array = base.operations.duplicate(true)
	# Source-identical, valid checkpoint transactions. Each has real encoded
	# legacy bytes and an exact identity; no fabricated XP or random hashes.
	# This constructs a test fixture, not a shortcut in the legacy converter.
	for generation in range(payload.generation+1,1001):
		payload.generation = generation
		var encoded := CharacterSaveContract.encode(payload)
		if not encoded.success: return encoded
		operations.append({"id":"fixture_checkpoint_%d" % generation,"request_digest":encoded.text.sha256_text(),"binding_kind":"legacy_document"})
	var current := Convert.Conversion.strip(payload)
	var head := {"epoch":"legacy_"+V6.digest(operations),"sequence":1,"parent_digest":null,"legacy_operation_count":operations.size()}
	var large := V6.assemble(current,base.evidence,operations,head,source)
	var encoded := V6.encode(large,source)
	if not encoded.success: return encoded
	var file := FileAccess.open(root.path_join("1000.json"),FileAccess.WRITE)
	file.store_string(encoded.text); file.close()
	var manifest := {"baseline":Credit.BASELINE,"profile":"dev_vaelis_thorn","namespace":"dev_normal","files":["small","168","221","233","400","1000"],"lifetime_ids":large.applied_ids.size(),"operation_count":operations.size()}
	file = FileAccess.open(root.path_join("manifest.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest)); file.close()
	return {"success":true,"manifest":manifest}
