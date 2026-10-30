extends RefCounted

const Boundary = preload("res://scripts/rewards/character_persistence_session.gd")
const Profiles = preload("res://scripts/rewards/character_profile_projection.gd")
const ProjectionFixtures = preload("res://tests/test_character_profile_projection.gd")
const ReceiptFixtures = preload("res://tests/test_character_persistence_coordinator.gd")
const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
var _failures: Array[String] = []

class BlockedWeb extends CharacterSaveStorage:
	func _init(path: String) -> void: super(path)
	func get_storage_status() -> Dictionary:
		return {"success":false,"reason":"web_write_coordination_unverified"}

class LostAcknowledgement extends CharacterSaveStorage:
	func _init(path: String) -> void: super(path)
	func write_profile(profile: String, payload: Dictionary, transaction: String) -> Dictionary:
		var result := super.write_profile(profile,payload,transaction)
		return {"success":false,"reason":"test_lost_acknowledgement"} if result.success else result

class UnsecuredCheckpoint extends CharacterPersistenceSession:
	func requires_checkpoint() -> bool: return true
	func checkpoint(_actor: CombatActorDefinition, _state: CombatActorState, _ledger: Dictionary, _defense: CombatDefenseProfile, _boundary: String) -> Dictionary:
		return {"success":false,"reason":"isolated_uncertain_checkpoint"}

class NoPublication extends CharacterSaveStorage:
	var writes := 0
	func _init(path: String) -> void: super(path)
	func write_profile(_profile: String, _payload: Dictionary, _transaction: String) -> Dictionary:
		writes += 1
		return {"success":true}

func run() -> Array[String]:
	var root := OS.get_cache_dir().path_join("itank-storage-tests").path_join("session_%s_%s" % [OS.get_process_id(),Time.get_ticks_usec()])
	_test_attested_checkpoint(root.path_join("checkpoint"))
	_test_mode_and_platform_gates(root)
	_test_uncertain_acknowledgement(root.path_join("uncertain"))
	_test_live_sessions()
	_test_live_checkpoint_failure()
	_test_actual_status_presentation()
	# Delete only files created under this test's unique, asserted cache root.
	assert(root.begins_with(OS.get_cache_dir().path_join("itank-storage-tests")+"/session_"))
	_remove_fixture(root)
	return _failures

func _authority(f: Dictionary) -> Callable:
	# Isolated ownership fixture, NOT a production provider or a UI authorization.
	var base: Callable = f.verifier
	var binding := Profiles.fingerprint({"profile_id":"profile_a","rules_revision":"rules_test","source":f.source.to_dictionary()})
	var projected := Profiles.project(f.source,f.sim.get_actor_definition(&"player"),f.sim.get_actor_state(&"player"),f.ledger.to_dictionary(),f.defense,base)
	assert(projected.success)
	var receipts: Array = ReceiptFixtures.new()._receipts(projected.payload)
	var source_binding := Profiles.fingerprint({"actor":f.sim.get_actor_definition(&"player").to_dictionary(),"state":f.sim.get_actor_state(&"player").to_dictionary(),"ledger":f.ledger.to_dictionary(),"defense":f.defense.to_dictionary()})
	var proposals := {}
	for boundary: String in ["run_admission","wave_completed","next_wave","character_changed"]:
		proposals[Profiles.fingerprint({"source":source_binding,"boundary":boundary,"payload":projected.payload})] = true
	return func(operation: String, digest: String) -> Dictionary:
		if operation == "bind": return {"authorized":digest == binding,"binding":digest}
		if operation == "checkpoint": return {"authorized":proposals.has(digest),"binding":digest,"settlements":receipts.duplicate(true),"transaction_id":"session_checkpoint","expected_generation":0,"expected_checkpoints":[]}
		return base.call(operation,digest)

func _test_attested_checkpoint(path: String) -> void:
	var f := ProjectionFixtures.new()._fixture()
	var before: Dictionary = f.sim.get_state_snapshot()
	var storage := LostAcknowledgement.new(path)
	var boundary := Boundary.new(storage)
	_expect(boundary.bind_before_run(f.source,"profile_a","rules_test",_authority(f)).success,"Host ownership must bind before the run.")
	var duplicate := Boundary.new(storage)
	_expect(duplicate.bind_before_run(f.source,"profile_a","rules_test",_authority(f)).get("reason") == "profile_already_owned_by_session","A second session cannot take an owned profile ID.")
	boundary.observe_mode("normal")
	_expect(not boundary.can_start_run(),"Bound character cannot start before admission is verified.")
	_expect(boundary.inspect_before_run().get("reason") == "starter_instance_admission_required","Missing profile does not fabricate starter identities.")
	var committed := boundary.checkpoint(f.sim.get_actor_definition(&"player"),f.sim.get_actor_state(&"player"),f.ledger.to_dictionary(),f.defense,"run_admission")
	_expect(committed.get("success",false) and committed.get("reconciled",false),"Exact lost acknowledgement must reconcile through Pass2: %s" % committed)
	_expect(boundary.can_start_run() and boundary.get_status().persistent,"Verified attested admission/checkpoint is distinguished from a failed write.")
	for index in range(3):
		_expect(boundary.checkpoint(f.sim.get_actor_definition(&"player"),f.sim.get_actor_state(&"player"),f.ledger.to_dictionary(),f.defense,"run_admission").get("success",false),"Repeated unchanged checkpoint must reuse the exact proposal.")
	_expect(boundary.checkpoint(f.sim.get_actor_definition(&"player"),f.sim.get_actor_state(&"player"),f.ledger.to_dictionary(),f.defense,"next_wave").get("reason") == "completed_wave_checkpoint_identity_required","An admission acknowledgement cannot stand in for a missing completed-wave checkpoint.")
	_expect(storage.inspect_profile("profile_a").generations.size() == 1,"Repeated checkpoint does not duplicate XP, currency, items or a generation.")
	var payload: Dictionary = storage.read_profile("profile_a").payload
	var candidate := Profiles.hydrate(payload,f.source,"profile_a","rules_test",f.verifier)
	_expect(candidate.get("success",false) and candidate.xp == {"earned":5050,"spent":2010,"unspent":3040},"Saved XP baselines and purchase totals must hydrate exactly.")
	if candidate.get("success",false):
		_expect(candidate.items == payload.items and candidate.shield_blocks.prime_v3_metal_buckler.current_shp == 7,"Original item instances/gold and damaged shield survive the actual checkpoint.")
		_expect(candidate.permanent.growth == payload.permanent.growth,"Historical HPM rolls must remain unchanged.")
	_expect(f.sim.get_state_snapshot() == before,"Checkpoint/readback cannot mutate HPC, resources, effects, RNG, events or schema-12 state.")
	boundary.fixture_reset()
	_expect(not boundary.get_status().persistent and storage.inspect_profile("profile_a").generations.size() == 1,"Fixture RESET must not delete or rewrite a permanent profile.")
	boundary = null
	var reload := Boundary.new(storage)
	_expect(reload.bind_before_run(f.source,"profile_a","rules_test",_authority(f)).success,"Lease must release when the session is destroyed.")
	reload.observe_mode("normal")
	_expect(reload.inspect_before_run().get("reason") == "new_run_history_and_instance_application_unavailable","Validated saved data must not be misapplied as a fresh run.")
	_expect(not reload.can_start_run(),"Unsupported new-run hydration is a hard block, never a fresh-character fallback.")
	# The canonical storage filename is discovered, not assumed by the fault test.
	var dir := DirAccess.open(path.path_join("profile_a"))
	var names := dir.get_files()
	var corrupt := FileAccess.open(path.path_join("profile_a").path_join(names[0]),FileAccess.WRITE)
	corrupt.store_string("incomplete")
	corrupt.close()
	_expect(reload.inspect_before_run().get("reason") == "profile_history_requires_review" and not reload.can_start_run(),"Corrupt saved history must remain blocked and untouched.")
	_expect(FileAccess.get_file_as_string(path.path_join("profile_a").path_join(names[0])) == "incomplete","Inspection never repairs or overwrites corruption.")

func _test_uncertain_acknowledgement(path: String) -> void:
	var f := ProjectionFixtures.new()._fixture()
	var storage := NoPublication.new(path)
	var boundary := Boundary.new(storage)
	_expect(boundary.bind_before_run(f.source,"profile_a","rules_test",_authority(f)).success,"Fault fixture must bind only its isolated owner.")
	boundary.observe_mode("normal")
	boundary.inspect_before_run()
	var result := boundary.checkpoint(f.sim.get_actor_definition(&"player"),f.sim.get_actor_state(&"player"),f.ledger.to_dictionary(),f.defense,"run_admission")
	_expect(not result.success and not boundary.can_start_run(),"Unverified acknowledgement cannot admit a playable persistent run.")
	for index in range(3):
		_expect(not boundary.checkpoint(f.sim.get_actor_definition(&"player"),f.sim.get_actor_state(&"player"),f.ledger.to_dictionary(),f.defense,"run_admission").success,"Uncertain checkpoint retries must remain unverified.")
	_expect(storage.writes == 1,"Uncertain acknowledgements reconcile read-only; they never blindly issue another write.")

func _test_mode_and_platform_gates(root: String) -> void:
	for mode: String in ["test","dev_normal"]:
		var f := ProjectionFixtures.new()._fixture()
		var path := root.path_join(mode)
		var boundary := Boundary.new(CharacterSaveStorage.new(path))
		_expect(boundary.bind_before_run(f.source,"profile_a","rules_test",_authority(f)).success,"Isolated mode fixture binding must succeed.")
		boundary.observe_mode(mode)
		boundary.observe_mode("normal")
		_expect(boundary.inspect_before_run().get("reason") == "nonproduction_mode_lineage","Changing mode must not authorize earlier %s progression." % mode)
		_expect(not DirAccess.dir_exists_absolute(path),"Rejected lineage never creates profile files.")
		boundary = null
	var web_path := root.path_join("web")
	var web := Boundary.new(BlockedWeb.new(web_path))
	web.observe_mode("normal")
	_expect(web.inspect_before_run().get("reason") == "web_write_coordination_unverified" and not web.get_status().persistent,"Web adapter must report nonpersistent, never success.")
	_expect(not DirAccess.dir_exists_absolute(web_path),"Blocked Web adapter never touches profile storage.")
	var untrusted := Boundary.new(CharacterSaveStorage.new(root.path_join("untrusted")))
	var source: CombatCharacterDefinitionResource = load("res://data/characters/vaelis_thorn.tres")
	_expect(not untrusted.bind_before_run(source,"profile_b","rules_test",func(_operation: String, _digest: String) -> Variant: return "not_authority").success,"Malformed identity approvals cannot bind a profile.")
	_expect(not untrusted.bind_before_run(source,"../profile","rules_test",func(_operation: String, _digest: String) -> Dictionary: return {}).success,"Profile identifiers cannot escape storage.")

func _test_live_sessions() -> void:
	var sessions: Array[ArenaCombatSession] = []
	for character: StringName in [Fixture.PLAYER_CHARACTER_GUARD,Fixture.PLAYER_CHARACTER_VAELIS]:
		var session := ArenaCombatSession.new(7,null,Fixture.ENCOUNTER_WAVE_ONE_GOBLINS,character)
		session.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
		_expect(session.initialize_wave_one_goblins(Vector2i(20_000_000,12_000_000),Vector2i(23_000_000,12_000_000),false).success,"Existing playable fixture must initialize.")
		_expect(session.configure_reward_mode("normal").success and not session.get_character_persistence_status().persistent,"Unattested fixtures must explicitly continue nonpersistent.")
		var before := session.get_state_snapshot()
		for index in range(3): session.get_character_persistence_status()
		_expect(before == session.get_state_snapshot(),"Persistence presentation must not mutate simulation/replay state.")
		_expect(session.start_encounter().success,"Nonpersistent gameplay must remain available.")
		for id: String in session.get_targetable_enemy_ids(): session.get_actor_state(StringName(id)).current_hpc = 0
		session.advance_by(1)
		var player := session.get_actor_state(&"player")
		player.current_hpc = 3
		if player.resources.has("mana"): player.resources.mana = 1
		var resources := player.resources.duplicate(true)
		_expect(session.request_next_wave().success,"Nonpersistent NEXT WAVE must continue to work.")
		_expect(player.current_hpc == 3 and player.resources == resources,"NEXT WAVE must never perform a new-run refill.")
		_expect(session.reset_encounter(false).success and not session.get_character_persistence_status().persistent,"RESET stays a fixture operation, not NEW RUN/load/delete.")
		sessions.append(session)
	# Two independently replayed sessions and real replica publication retain schema 12.
	var a := ArenaCombatSession.new(1)
	var b := ArenaCombatSession.new(1)
	for session: ArenaCombatSession in [a,b]:
		session.initialize(Vector2i.ZERO,Vector2i(2_000_000,0),false)
		session.configure_reward_mode("normal")
		session.start_encounter()
		session.advance_by(100_000)
	_expect(a.get_state_snapshot() == b.get_state_snapshot(),"Same-seed replay must retain exact event/RNG/state order.")
	var harness := TwoClientSyncHarness.new(1)
	harness.authority.simulation = a.simulation
	harness.deliver_in_order(harness.authority.publish_current_events())
	_expect(a.get_state_snapshot().schema_version == 12 and harness.compare_clients().success and harness.client_a.get_state_snapshot() == a.simulation.get_state_snapshot(),"Schema-12 authoritative state and two client digests must converge.")

func _test_live_checkpoint_failure() -> void:
	var session := ArenaCombatSession.new(7,null,Fixture.ENCOUNTER_WAVE_ONE_GOBLINS,Fixture.PLAYER_CHARACTER_VAELIS)
	session.initialize_wave_one_goblins(Vector2i.ZERO,Vector2i(3_000_000,0),false)
	session.configure_reward_mode("normal")
	session.start_encounter()
	for id: String in session.get_targetable_enemy_ids(): session.get_actor_state(StringName(id)).current_hpc = 0
	session.advance_by(1)
	# Inject a host I/O failure at the completed-wave boundary, not combat logic.
	session._character_persistence = UnsecuredCheckpoint.new()
	var before := session.get_state_snapshot()
	var rejected := session.request_next_wave()
	_expect(rejected.get("reason") == "character_checkpoint_not_secured" and before == session.get_state_snapshot(),"Unsecured checkpoint must block before retirement, wave RNG, events or refill.")
	_expect(session.get_encounter_state() == ArenaCombatSession.ENCOUNTER_BETWEEN_WAVE_DOWNTIME,"Failed persistence must leave completed-wave downtime intact.")

func _test_actual_status_presentation() -> void:
	var scene := (load("res://scenes/test_arena.tscn") as PackedScene).instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(scene)
	var controller := scene.get_node("CombatController") as ArenaCombatController
	_expect(controller._combat_status.text.contains("Progress not saved"),"Actual gameplay status must explicitly identify ephemeral progression.")
	var before := controller._session.get_state_snapshot()
	controller._update_presentation()
	_expect(before == controller._session.get_state_snapshot(),"Rendering persistence status cannot alter authoritative history or RNG.")
	scene.get_parent().remove_child(scene)
	scene.free()

func _remove_fixture(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path): return
	var dir := DirAccess.open(path)
	for name: String in dir.get_files(): DirAccess.remove_absolute(path.path_join(name))
	for name: String in dir.get_directories(): _remove_fixture(path.path_join(name))
	DirAccess.remove_absolute(path)

func _expect(value: bool, message: String) -> void:
	if not value: _failures.append(message)
