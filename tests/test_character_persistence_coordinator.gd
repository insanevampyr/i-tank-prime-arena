extends RefCounted

const Coordinator = preload("res://scripts/rewards/character_persistence_coordinator.gd")
const Profiles = preload("res://scripts/rewards/character_profile_projection.gd")
const Fixtures = preload("res://tests/test_character_profile_projection.gd")
const Contract = preload("res://scripts/rewards/character_save_contract.gd")
var _failures: Array[String] = []

class LostAcknowledgement extends CharacterSaveStorage:
	func _init(path: String = "") -> void: super(path)
	func write_profile(profile: String, payload: Dictionary, transaction: String) -> Dictionary:
		var result := super.write_profile(profile,payload,transaction)
		return {"success":false,"reason":"simulated_lost_acknowledgement"} if result.success else result

class NoPublication extends CharacterSaveStorage:
	func _init(path: String = "") -> void: super(path)
	func write_profile(_profile: String, _payload: Dictionary, _transaction: String) -> Dictionary:
		return {"success":true}

class BlockedWeb extends CharacterSaveStorage:
	func _init(path: String = "") -> void: super(path)
	func get_storage_status() -> Dictionary:
		return {"success":false,"reason":"web_write_coordination_unverified","state":"unverified"}

class RacingWriter extends CharacterSaveStorage:
	func _init(path: String = "") -> void: super(path)
	func write_profile(profile: String, payload: Dictionary, transaction: String) -> Dictionary:
		var rival := super.write_profile(profile,payload,"competing_writer")
		if not rival.success: return rival
		return super.write_profile(profile,payload,transaction)

func run() -> Array[String]:
	var f := Fixtures.new()._fixture()
	var before: Dictionary = f.sim.get_state_snapshot()
	var projected := Profiles.project(f.source,f.sim.get_actor_definition(&"player"),f.sim.get_actor_state(&"player"),f.ledger.to_dictionary(),f.defense,f.verifier)
	if not projected.get("success",false): return ["Coordinator source projection failed: %s" % projected]
	var payload: Dictionary = projected.payload
	var receipts := _receipts(payload)
	var prepared := Coordinator.prepare(payload,receipts,"transaction_a",0,[])
	if not prepared.get("success",false): return ["Coordinator preparation failed: %s" % prepared]
	var request: Dictionary = prepared.prepared
	var root := OS.get_cache_dir().path_join("itank-storage-tests").path_join("coordinator_%s_%s" % [OS.get_process_id(),Time.get_ticks_usec()])
	var cases: Array[String] = []
	for name: String in ["normal","lost_ack","unpublished","pending","locked","corrupt","future_inner","future_outer","gap","web","race","legacy"]: cases.append(name)
	var storage := CharacterSaveStorage.new(root.path_join("normal"))
	var coordinator := Coordinator.new(storage)
	var committed := _commit(coordinator,request,f)
	_expect(committed.get("success",false) and committed.get("generation") == 1,"Valid profile+receipts commit must verify generation one: %s" % committed)
	var loaded := storage.read_profile("profile_a")
	_expect(loaded.get("payload") == request.payload and loaded.get("document") == request.document,"Canonical profile and all receipts must be published together.")
	_expect(_commit(coordinator,request,f).get("success",false),"Identical retry must reconcile to committed success.")
	_expect(coordinator.reconcile(request,f.source,"profile_a","rules_test",f.verifier).get("success",false),"Explicit reconciliation must read the exact existing transaction.")
	_expect(storage.inspect_profile("profile_a").generations.size() == 1,"Retry cannot create another generation or payout.")
	var second_payload: Dictionary = request.payload.duplicate(true)
	second_payload.generation = 2
	second_payload.secured_checkpoints.append("profile_a/run_a/wave_2")
	var second: Dictionary = Coordinator.prepare(second_payload,receipts,"transaction_b",1,[]).prepared
	_expect(_commit(coordinator,second,f).get("success",false),"Sequential complete-profile checkpoint should succeed.")
	var old_retry := _commit(coordinator,request,f)
	_expect(old_retry.get("success",false) and old_retry.get("latest_generation") == 2,"Old acknowledged transaction returns proof, never rolls the active generation back.")
	var reused: Dictionary = Coordinator.prepare(second_payload,receipts,"transaction_a",1,[]).prepared
	_expect(_commit(coordinator,reused,f).get("reason") == "transaction_payload_conflict","Transaction identity cannot be reused with different canonical data.")
	var competing: Dictionary = Coordinator.prepare(payload,receipts,"other_writer",0,[]).prepared
	_expect(_commit(coordinator,competing,f).get("state") == "conflict","Different writer cannot occupy an existing generation.")
	var stale_payload := second_payload.duplicate(true)
	stale_payload.generation = 3
	var wrong_checkpoints: Dictionary = Coordinator.prepare(stale_payload,receipts,"bad_checkpoint",2,[]).prepared
	_expect(_commit(coordinator,wrong_checkpoints,f).get("reason") == "checkpoint_comparison_failed","Expected checkpoint must match actual durable checkpoint.")
	var stale: Dictionary = Coordinator.prepare(stale_payload,receipts,"stale",2,["profile_a/run_a/wave_2"]).prepared
	var stale_changed: Dictionary = stale.duplicate(true)
	stale_changed.expected_generation = 1
	_expect(not _commit(coordinator,stale_changed,f).get("success",false),"Generation mismatch/rollback must fail.")
	for receipt: Dictionary in receipts:
		var duplicate_set := receipts.duplicate(true)
		var duplicate := receipt.duplicate(true)
		duplicate.claim_id += "_retry"
		duplicate.receipt_id += "_retry"
		duplicate_set.append(duplicate)
		_expect(not Coordinator.prepare(stale_payload,duplicate_set,"duplicate",2,["profile_a/run_a/wave_2"]).get("success",false),"XP/gold/loot/purchase effect cannot be claimed under another identity: %s." % receipt.kind)
	var conflict_set := receipts.duplicate(true)
	conflict_set[0].content.amount += 1
	_expect(not Coordinator.prepare(stale_payload,conflict_set,"changed_effect",2,["profile_a/run_a/wave_2"]).get("success",false),"Conflicting settlement payload must reject.")
	var duplicate_origin := receipts.duplicate(true)
	var disguised: Dictionary = receipts.back().duplicate(true)
	disguised.claim_id += "_other"
	disguised.receipt_id += "_other"
	disguised.content.instance_id += "_other"
	duplicate_origin.append(disguised)
	_expect(not Coordinator.prepare(stale_payload,duplicate_origin,"renamed_origin",2,["profile_a/run_a/wave_2"]).get("success",false),"Renaming an instance cannot claim its same acquisition provenance twice.")
	for item: Dictionary in stale_payload.items:
		if item.equipped_slots.is_empty():
			var inflated := stale_payload.duplicate(true)
			for entry: Dictionary in inflated.items:
				if entry.instance_id == item.instance_id:
					entry.quantity *= 2
					inflated.permanent.inventory_quantities[entry.definition_id] *= 2
			var increase: Dictionary = Coordinator.prepare(inflated,receipts,"inflated_"+item.definition_id,2,["profile_a/run_a/wave_2"]).prepared
			_expect(not _commit(coordinator,increase,f).get("success",false),"Another transaction cannot inflate existing gold/loot quantities without an acquisition.")
	var forged := request.duplicate(true)
	forged.payload.items[0].quantity = 9
	_expect(not _commit(coordinator,forged,f).get("success",false),"Prepared request mutation must reject before writing.")
	_expect(not coordinator.commit(request,f.source,"profile_a","rules_test").get("success",false),"Missing authority cannot publish production state.")
	var malformed_authority := func(_operation: String, _binding: String) -> Variant: return false
	_expect(not coordinator.commit(request,f.source,"profile_a","rules_test",malformed_authority).get("success",false),"Malformed authority responses must fail closed without script errors.")
	_expect(not coordinator.commit(request,f.source,"other_profile","rules_test",f.verifier).get("success",false),"Wrong profile identity cannot publish.")
	_expect(not coordinator.commit(request,f.source,"profile_a","wrong_rules",f.verifier).get("success",false),"Wrong rules identity cannot publish.")
	for mode: String in ["test","dev_normal"]:
		var tainted := Fixtures.new()._fixture([mode,"normal"])
		var changed := request.duplicate(true)
		changed.payload.lineage.mode_history = [mode,"normal"]
		changed.document = Contract.encode(changed.payload).text
		_expect(not _commit(coordinator,changed,tainted).get("success",false),"Historical %s lineage cannot commit after changing current mode." % mode)
	var lost := Coordinator.new(LostAcknowledgement.new(root.path_join("lost_ack")))
	var recovered := _commit(lost,request,f)
	_expect(recovered.get("success",false) and recovered.get("reconciled",false),"Published write with lost acknowledgement must reconcile exact bytes without another payout.")
	var unpublished := Coordinator.new(NoPublication.new(root.path_join("unpublished")))
	_expect(_commit(unpublished,request,f).get("state") == "uncertain","Storage success without exact publication must never become acknowledged success.")
	var race_storage := RacingWriter.new(root.path_join("race"))
	var race := Coordinator.new(race_storage)
	_expect(_commit(race,request,f).get("state") == "conflict" and race_storage.inspect_profile("profile_a").generations.size() == 1,"A writer racing after preflight must be caught by the existing locked generation check, not overwritten.")
	var legacy_storage := CharacterSaveStorage.new(root.path_join("legacy"))
	_expect(legacy_storage.write_profile("profile_a",payload,"legacy").get("success",false),"Pre-settlement Pass1 v2 remains readable/writable through its isolated foundation.")
	_expect(_commit(Coordinator.new(legacy_storage),second,f).get("reason") == "legacy_settlement_history_unavailable","Unreceipted legacy progression cannot be silently adopted by the coordinator.")
	for name: String in ["pending","locked","corrupt","future_inner","future_outer","gap"]:
		var case_root := root.path_join(name)
		var store := CharacterSaveStorage.new(case_root)
		var c := Coordinator.new(store)
		_expect(_commit(c,request,f).get("success",false),"Recovery fixture must publish a known baseline.")
		var directory := case_root.path_join("profile_a")
		if name == "pending": _write(directory.path_join("write.pending"),"partial write")
		elif name == "locked": DirAccess.make_dir_absolute(directory.path_join("writer.lock"))
		else:
			var wrapper := {"storage_version":1,"transaction_id":"unknown_second","document":second.document}
			if name == "future_inner":
				var envelope: Dictionary = JSON.parse_string(second.document)
				envelope.version = 999
				wrapper.document = JSON.stringify(envelope)
			elif name == "future_outer": wrapper.storage_version = 999
			elif name == "gap": wrapper.document = stale.document
			_write(directory.path_join("generation_0000000000000003.json" if name == "gap" else "generation_0000000000000002.json"),"corrupt" if name == "corrupt" else JSON.stringify(wrapper))
		var outcome := _commit(c,second,f)
		_expect(not outcome.get("success",false) and outcome.get("state") in ["blocked","uncertain"],"Ambiguous recovery must retain evidence, not repair automatically: %s." % name)
		if name in ["future_inner","future_outer"]:
			_expect(store.read_profile("profile_a").get("reason") == ("unsupported_storage_version" if name == "future_outer" else "unsupported_format_or_version"),"Future formats must not downgrade to a backup.")
		elif name == "corrupt":
			_expect(store.read_profile("profile_a").get("recovered_previous_generation",false),"Valid older generation remains available for explicit recovery review.")
			_write(directory.path_join("generation_0000000000000001.json"),"corrupt backup")
			_expect(not c.reconcile(request,f.source,"profile_a","rules_test",f.verifier).get("success",false),"Corrupt backup must not reconcile to success or blank progression.")
		_expect(FileAccess.file_exists(directory.path_join("generation_0000000000000001.json")),"Recovery must preserve prior valid generation.")
		if name == "locked": _expect(DirAccess.dir_exists_absolute(directory.path_join("writer.lock")),"Coordinator must not steal uncertain lock.")
		if name == "pending": _expect(FileAccess.file_exists(directory.path_join("write.pending")),"Coordinator must not discard incomplete write.")
	var web := Coordinator.new(BlockedWeb.new(root.path_join("web")))
	_expect(_commit(web,request,f).get("reason") == "web_write_coordination_unverified" and not DirAccess.dir_exists_absolute(root.path_join("web")),"Unverified Web adapter must remain blocked without writes.")
	_expect(f.sim.get_state_snapshot() == before,"Coordinator must not touch combat, RNG, resources, event history or digests.")
	# Tests alone remove their own explicitly created files/directories. Runtime
	# coordinator never deletes evidence. No live user:// path is referenced.
	assert(root.simplify_path().begins_with(OS.get_cache_dir().path_join("itank-storage-tests").simplify_path()+"/coordinator_"))
	for name: String in cases:
		var directory := root.path_join(name).path_join("profile_a")
		if DirAccess.dir_exists_absolute(directory):
			if DirAccess.dir_exists_absolute(directory.path_join("writer.lock")): DirAccess.remove_absolute(directory.path_join("writer.lock"))
			var dir := DirAccess.open(directory)
			for file: String in dir.get_files(): DirAccess.remove_absolute(directory.path_join(file))
			DirAccess.remove_absolute(directory)
		if DirAccess.dir_exists_absolute(root.path_join(name)): DirAccess.remove_absolute(root.path_join(name))
	if DirAccess.dir_exists_absolute(root): DirAccess.remove_absolute(root)
	return _failures

func _receipts(payload: Dictionary) -> Array:
	var receipts: Array = []
	for award: Dictionary in payload.permanent.award_receipts:
		receipts.append(_receipt("xp","xp_award",{"award_id":award.award_id,"amount":award.xp}))
	for purchase: Dictionary in payload.purchases:
		receipts.append(_receipt("purchase","sr_purchase",{"purchase_id":purchase.purchase_id,"cost":purchase.cost}))
	for item: Dictionary in payload.items:
		receipts.append(_receipt("currency" if item.definition_id == "prime_v3_gold" else "item",item.instance_id,{"instance_id":item.instance_id,"definition_id":item.definition_id,"quantity":item.quantity,"provenance_digest":Profiles.fingerprint(item.provenance)}))
	return receipts

func _receipt(kind: String, claim: String, content: Dictionary) -> Dictionary:
	return {"version":1,"receipt_id":"profile_a/run_a/wave_1/"+claim,"profile_id":"profile_a","run_id":"run_a","wave_id":"wave_1","claim_id":claim,"kind":kind,"content":content}

func _commit(c: CharacterPersistenceCoordinator, request: Dictionary, f: Dictionary) -> Dictionary:
	return c.commit(request,f.source,"profile_a","rules_test",f.verifier)

func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	assert(file != null,"Isolated fault fixture could not be created.")
	file.store_string(text)
	file.close()

func _expect(value: bool, message: String) -> void:
	if not value: _failures.append(message)
