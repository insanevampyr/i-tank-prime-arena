extends RefCounted
const Bench = preload("res://tests/compact_v6_performance.gd")
const Oracle = preload("res://tests/oracles/compact_v6_linear_45p.gd")
const Old = preload("res://tests/oracles/character_coordinator_linear_45p.gd")
var failures: Array[String] = []
var assertions := 0
func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok: failures.append(message)
func run() -> Array[String]:
	var root := OS.get_environment("ARENA45P_FIXTURES")
	if not Bench.Disk.allowed(root): check(false,"Disposable 45P fixture directory required"); return failures
	var source: CombatCharacterDefinitionResource = PlayableCharacterAdmission.prepare_starter(&"vaelis_thorn","dev_normal",preload("res://scripts/rewards/character_expc_credit.gd").BASELINE).source
	for name: String in ["ops1000","ops10000","awards","inventory","chain100","chain501"]:
		var text := FileAccess.get_file_as_string(root.path_join(name+".json"))
		var result := Bench.equivalence(text,source)
		assertions += int(result.get("assertions",0))
		check(result.success,"Full oracle equivalence "+name+": "+str(result.get("failures",result.get("reason"))))
		print("45P_EQUIVALENCE "+JSON.stringify({"fixture":name,"success":result.success,"assertions":result.get("assertions"),"hash":result.get("canonical_hash")}))
	var input := Oracle.decode(FileAccess.get_file_as_string(root.path_join("ops1000.json")),source)
	var p := Oracle._projection(input.record)
	var prepared := CharacterPersistenceCoordinator.prepare(p,p.settlements,"oracle_authority",p.generation-1,[])
	check(prepared.success,"Real candidate preparation remains valid")
	if prepared.success:
		var denied := func(_op: String,binding: String): return {"authorized":false,"binding":binding}
		check(Old._authorize(prepared.prepared,source,p.character_id,p.rules_revision,denied) == CharacterPersistenceCoordinator._authorize(prepared.prepared,source,p.character_id,p.rules_revision,denied),"Authorization refusal unchanged")
		var forged: Dictionary = prepared.prepared.duplicate(true); forged.document += " "
		check(Old._authorize(forged,source,p.character_id,p.rules_revision,denied) == CharacterPersistenceCoordinator._authorize(forged,source,p.character_id,p.rules_revision,denied),"Changed candidate bytes rejected identically")
		var row := {"transaction_id":prepared.prepared.transaction_id,"document":prepared.prepared.document,"payload":p}
		for history: Dictionary in [{"success":true,"generations":[row],"writer_locked":false,"pending_write":false},{"success":true,"generations":[],"writer_locked":false,"pending_write":false},{"success":false,"rejected_files":[{"reason":"unsupported_storage_version"}]}]:
			check(Old._find_transaction(prepared.prepared,history) == CharacterPersistenceCoordinator._find_transaction(prepared.prepared,history),"Unmodified transaction reconciliation matches full original oracle")
	var f := preload("res://tests/test_compact_character_v6.gd").new().fixture(["end","wis","award"])
	var before := Bench.V6.digest(f.sim.get_state_snapshot())
	check(Oracle.validate(f.record,f.source).success and Bench.V6.validate(f.record,f.source).success,"Interleaved END/WIS source and original RNG-produced growth remain valid")
	check(before == Bench.V6.digest(f.sim.get_state_snapshot()),"Full validation leaves RNG, simulation history, resources and actor state unchanged")
	print("45P exact lifetime lookup: %d assertions." % assertions)
	return failures
