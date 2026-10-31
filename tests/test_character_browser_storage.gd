extends RefCounted

const Browser = preload("res://scripts/rewards/character_browser_storage.gd")
const AsyncCoordinator = preload("res://scripts/rewards/character_browser_persistence.gd")
const Coordinator = preload("res://scripts/rewards/character_persistence_coordinator.gd")
const Contract = preload("res://scripts/rewards/character_save_contract.gd")
const Profiles = preload("res://scripts/rewards/character_profile_projection.gd")
var _failures: Array[String] = []

class Transport extends RefCounted:
	var responses: Array[Dictionary] = []
	var calls: Array[Dictionary] = []
	func call_transport(method: String, value: Dictionary) -> Dictionary:
		if method == "begin":
			calls.append(value.duplicate(true))
			return {"success":false,"state":"pending","job":"isolated_job"}
		return responses.pop_front() if not responses.is_empty() else {"success":false,"state":"pending"}

func run() -> Array[String]:
	var f := fixture()
	var before: Dictionary = f.sim.get_state_snapshot()
	var fake := Transport.new()
	var storage := Browser.new(fake.call_transport)
	var coordinator := AsyncCoordinator.new(storage)
	var pending := coordinator.begin_commit(f.prepared,f.source,f.payload.character_id,"rules_test","session_a",f.verifier)
	_expect(pending.state == "pending" and not pending.success,"Dispatch is pending, never a save acknowledgement.")
	_expect(coordinator.begin_commit(f.prepared,f.source,f.payload.character_id,"rules_test","session_a",f.verifier).reason == "operation_in_flight","One coordinator cannot issue competing writes.")
	_expect(coordinator.poll().state == "pending" and fake.calls.size() == 1,"Pending polls cannot write or tick combat.")
	fake.responses.append({"success":true,"state":"verified_committed","missing":true,"generations":[]})
	_expect(coordinator.poll().state == "pending" and fake.calls.back().operation == "publish","Authority checks precede dispatch to IDB publish.")
	fake.responses.append(ack(f))
	_expect(coordinator.poll().state == "verified_committed","Exact fresh-readback acknowledgement is accepted.")
	# Reconcile an uncertain write using history and a fresh read, no second publish.
	coordinator.begin_commit(f.prepared,f.source,f.payload.character_id,"rules_test","session_a",f.verifier,true)
	fake.responses.append(history(f))
	_expect(coordinator.poll().state == "pending" and fake.calls.back().operation == "reconcile","Exact retry must reconcile rather than publish a second generation.")
	fake.responses.append(ack(f))
	_expect(coordinator.poll().success,"Lost acknowledgement can reconcile exactly.")
	# Fault statuses are not interpreted as missing characters.
	for state: String in ["failed","unavailable","recovery_required"]:
		coordinator.begin_commit(f.prepared,f.source,f.payload.character_id,"rules_test","session_a",f.verifier)
		fake.responses.append({"success":false,"state":state,"reason":"injected_failure"})
		_expect(coordinator.poll().state == state and fake.calls.back().operation == "inspect","Read failure cannot create a blank profile.")
	coordinator.begin_commit(f.prepared,f.source,f.payload.character_id,"rules_test","session_a",f.verifier)
	fake.responses.append({"success":true,"state":"verified_committed","missing":true,"generations":[]})
	coordinator.poll()
	var wrong := ack(f); wrong.document += " "
	fake.responses.append(wrong)
	_expect(coordinator.poll().state == "recovery_required","Nonexact readback fails closed.")
	var corrupt := history(f); corrupt.generations[0].document = "corrupt"
	_expect(not Browser.inspection(corrupt).success,"Browser reads use the complete Godot contract validation.")
	var future := history(f)
	var envelope: Dictionary = JSON.parse_string(f.prepared.document); envelope.version = 999
	future.generations[0].document = JSON.stringify(envelope)
	_expect(not Browser.inspection(future).success,"Future contract versions cannot fall back to blank.")
	var bad: Dictionary = f.prepared.duplicate(true); bad.document += " "
	var count := fake.calls.size()
	_expect(not coordinator.begin_commit(bad,f.source,f.payload.character_id,"rules_test","session_a",f.verifier).success and fake.calls.size() == count,"Changed prepared bytes fail authority before transport.")
	var second: Dictionary = f.payload.duplicate(true); second.generation = 2
	var prepared: Dictionary = Coordinator.prepare(second,second.settlements,"test_txn_2",1,[]).prepared
	coordinator.begin_commit(prepared,f.source,f.payload.character_id,"rules_test","session_a",f.verifier)
	fake.responses.append({"success":true,"state":"verified_committed","missing":true,"generations":[]})
	_expect(coordinator.poll().reason == "stale_generation","Coordinator checks generation before dispatch; IDB compares again atomically.")
	_expect(f.sim.get_state_snapshot() == before and before.schema_version == 12,"Storage must not mutate RNG, snapshots, combat resources or event history.")
	var harness := TwoClientSyncHarness.new(36001)
	harness.authority.simulation = f.sim
	harness.deliver_in_order(harness.authority.publish_current_events())
	_expect(harness.compare_clients().get("success",false) and harness.client_a.get_state_snapshot() == before,"Browser boundary preserves schema-12 two-client equivalence.")
	var replay := fixture()
	_expect(replay.sim.get_state_snapshot() == before,"Same-seed replay remains identical.")
	if not OS.has_feature("web"):
		_expect(Browser.new().begin("inspect",{}).state == "unavailable","Desktop never invokes JavaScriptBridge/browser storage.")
	return _failures

# Native-authority-generated browser fixture, not a production character. The
# browser harness uses this exact canonical V2 document; no gameplay saves.
func fixture(profile: String = "prod_browser_fixture", save_namespace: String = "normal") -> Dictionary:
	var f := preload("res://tests/test_character_profile_projection.gd").new()._fixture()
	var projected := Profiles.project(f.source,f.sim.get_actor_definition(&"player"),f.sim.get_actor_state(&"player"),f.ledger.to_dictionary(),f.defense,f.verifier)
	assert(projected.success)
	var receipts: Array = preload("res://tests/test_character_persistence_coordinator.gd").new()._receipts(projected.payload)
	var payload: Dictionary = JSON.parse_string(JSON.stringify(projected.payload).replace("profile_a",profile))
	# Restore contract integer representation after JSON fixture transformation.
	payload = Contract._normalize_json_numbers(payload)
	payload.profile_namespace = save_namespace
	if save_namespace == "dev_normal": payload.lineage.mode_history = ["dev_normal"]
	var mapped_receipts: Array = Contract._normalize_json_numbers(JSON.parse_string(JSON.stringify(receipts).replace("profile_a",profile)))
	var prepared := Coordinator.prepare(payload,mapped_receipts,"test_txn_1",0,[])
	assert(prepared.success,str(prepared))
	payload = prepared.prepared.payload
	var lineage: Dictionary = payload.lineage.duplicate(true)
	f.verifier = func(_operation: String, binding: String) -> Dictionary: return {"authorized":true,"binding":binding,"lineage":lineage.duplicate(true)}
	f.payload = payload
	f.prepared = prepared.prepared
	return f

func ack(f: Dictionary) -> Dictionary:
	return {"success":true,"state":"verified_committed","document":f.prepared.document,"generation":1,"transaction_id":"test_txn_1"}

func history(f: Dictionary) -> Dictionary:
	return {"success":true,"state":"verified_committed","missing":false,"generations":[{"document":f.prepared.document,"generation":1,"transaction_id":"test_txn_1"}]}

func _expect(value: bool, message: String) -> void:
	if not value: _failures.append(message)
