extends RefCounted

const Admission = preload("res://scripts/rewards/playable_character_admission.gd")
const Profiles = preload("res://scripts/rewards/character_profile_projection.gd")
const Coordinator = preload("res://scripts/rewards/character_persistence_coordinator.gd")
const Contract = preload("res://scripts/rewards/character_save_contract.gd")
const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
var _failures: Array[String] = []

class LostAcknowledgement extends CharacterSaveStorage:
	func _init(path: String) -> void: super(path)
	func write_profile(profile: String, payload: Dictionary, transaction: String) -> Dictionary:
		var result := super.write_profile(profile,payload,transaction)
		return {"success":false,"reason":"test_lost_acknowledgement"} if result.success else result

func run() -> Array[String]:
	var root := OS.get_cache_dir().path_join("itank-storage-tests").path_join("admission_%s_%s" % [OS.get_process_id(),Time.get_ticks_usec()])
	_test_verified_sources()
	_test_source_record_roundtrip(root.path_join("profiles"))
	_test_rejected_authority(root.path_join("rejected"))
	_test_live_gates()
	assert(root.begins_with(OS.get_cache_dir().path_join("itank-storage-tests")+"/admission_"))
	_remove_fixture(root)
	return _failures

func _test_verified_sources() -> void:
	var guard := Admission.prepare_starter(Fixture.PLAYER_CHARACTER_GUARD,"normal")
	_expect(guard.get("reason") == "guard_permanent_starter_unverified","Guard cannot receive invented level/XP/HPB or starting possessions.")
	_expect(guard.get("details",{}).get("missing",[]).has("initial_EXPM_EXPC"),"Guard diagnostic must identify the missing permanent facts.")
	var f := Admission.prepare_starter(Fixture.PLAYER_CHARACTER_VAELIS,"normal")
	_expect(f.get("success",false),"Canonical Vaelis source starter must project without a test authority: %s" % f.get("reason"))
	if not f.get("success",false): return
	_expect(f.actor.get_combat_stat("hpm") == 9 and f.actor.resource_maxima == {"mana":20,"blood":10} and not f.actor.resource_maxima.has("ap"),"Source maxima must match; no invented AP pool.")
	_expect(f.state.inventory_quantities == {"prime_v3_gold":75,"vaelis_source_sword_sheath":1,"vaelis_source_basic_clothing":1},"Authored Gold/sheath/clothing grants must be exact.")
	var wand_count := 0
	for item: Dictionary in f.items:
		if item.definition_id == "prime_v3_short_wand": wand_count += item.quantity
	_expect(wand_count == 1 and f.items.size() == 5,"Equipped Wand and source inventory row identify one item, not two.")
	_expect(not f.playable_ready,"Source admission is not proof of safe run restoration.")
	var other := Admission.prepare_starter(Fixture.PLAYER_CHARACTER_VAELIS,"normal")
	_expect(f.prepared.document == other.prepared.document and f.items == other.items,"Registry/source admission must produce stable original grant identities.")
	f.state.inventory_quantities.prime_v3_gold = 0
	_expect(other.state.inventory_quantities.prime_v3_gold == 75,"Starter instances must own independent mutable state.")
	_expect(not Admission.prepare_starter(Fixture.PLAYER_CHARACTER_VAELIS,"test").success,"TEST never prepares a persistent starter.")

func _test_source_record_roundtrip(path: String) -> void:
	var storage := LostAcknowledgement.new(path)
	for mode: String in ["normal","dev_normal"]:
		var f := Admission.prepare_starter(Fixture.PLAYER_CHARACTER_VAELIS,mode)
		_expect(f.get("success",false),"Approved separate namespace must prepare: %s / %s" % [mode,f.get("reason")])
		if not f.get("success",false): continue
		var coordinator := Coordinator.new(storage)
		var committed := coordinator.commit(f.prepared,f.source,f.profile_id,Admission.RULES,f.authority)
		_expect(committed.get("success",false) and committed.get("reconciled",false),"Source admission lost acknowledgement must reconcile exactly: %s" % committed)
		var read := storage.read_profile(f.profile_id)
		_expect(read.get("success",false) and read.document == f.prepared.document,"Actual stored source record must survive closed/reopened FileAccess.")
		var reopened := CharacterSaveStorage.new(path)
		var cold := Admission.prepare_starter(Fixture.PLAYER_CHARACTER_VAELIS,mode)
		var candidate := Profiles.hydrate(reopened.read_profile(cold.profile_id).payload,cold.source,cold.profile_id,Admission.RULES,cold.authority)
		_expect(candidate.get("success",false) and candidate.items == f.items and candidate.xp == {"earned":0,"spent":0,"unspent":0},"Fresh authority must reconstruct identical source ownership/XP without grants replay.")
		if candidate.get("success",false):
			_expect(candidate.permanent.inventory_quantities.prime_v3_gold == 75 and not candidate.has("resources") and not candidate.has("current_hpc"),"Hydration preserves original Gold but never performs a resource refill.")
		for index in range(3):
			_expect(coordinator.commit(f.prepared,f.source,f.profile_id,Admission.RULES,f.authority).get("success",false),"Identical admission is an idempotent receipt read, not another starter grant.")
		_expect(storage.inspect_profile(f.profile_id).generations.size() == 1,"Repeated admissions cannot duplicate Gold, equipment or generations.")
		var lineage: Dictionary = f.prepared.payload.lineage.duplicate(true)
		lineage.mode_history = ["dev_normal","normal"]
		var tainted: Dictionary = f.prepared.payload.duplicate(true)
		tainted.lineage = lineage
		_expect(not Profiles.hydrate(tainted,f.source,f.profile_id,Admission.RULES,f.authority).success,"Mode changes cannot authorize a source record under another lineage.")
	var prod := Admission.profile_identity(Fixture.PLAYER_CHARACTER_VAELIS,"normal")
	var dev := Admission.profile_identity(Fixture.PLAYER_CHARACTER_VAELIS,"dev_normal")
	_expect(prod.profile_id != dev.profile_id and prod.profile_id != "player" and dev.profile_id != "player","Profile identities are stable and independent of combat actor IDs.")
	_expect(DirAccess.dir_exists_absolute(path.path_join(prod.profile_id)) and DirAccess.dir_exists_absolute(path.path_join(dev.profile_id)),"Developer and production generations occupy separate profile directories.")

func _test_rejected_authority(path: String) -> void:
	var f := Admission.prepare_starter(Fixture.PLAYER_CHARACTER_VAELIS,"normal")
	if not f.get("success",false): return
	var storage := CharacterSaveStorage.new(path)
	var coordinator := Coordinator.new(storage)
	var forged: Dictionary = f.prepared.payload.duplicate(true)
	forged.profile_namespace = "dev_normal"
	_expect(not Contract.validate(forged).success,"Production identity cannot be relabeled developer.")
	forged = f.prepared.payload.duplicate(true)
	forged.items[0].instance_id = "new_phantom_instance"
	var encoded := Contract.encode(forged)
	var proposal: Dictionary = f.prepared.duplicate(true)
	proposal.payload = forged
	proposal.document = encoded.text
	_expect(not coordinator.commit(proposal,f.source,f.profile_id,Admission.RULES,f.authority).success,"A new canonical checksum does not authorize phantom instance ownership.")
	var snapshot: Dictionary = f.state.to_dictionary()
	f.state.inventory_quantities.prime_v3_gold += 1
	var projected := Profiles.project(f.source,f.actor,f.state,f.ledger.to_dictionary(),f.defense,f.authority)
	_expect(projected.get("reason") == "source_authority_rejected","Quantity-only changes must not acquire fabricated origin evidence.")
	f.state.inventory_quantities.prime_v3_gold -= 1
	_expect(snapshot == f.state.to_dictionary() and not DirAccess.dir_exists_absolute(path),"Rejected candidates leave authority and storage unchanged.")
	_expect(coordinator.commit(f.prepared,f.source,f.profile_id,Admission.RULES,f.authority).success,"Control source admission must remain valid.")
	var directory := path.path_join(f.profile_id)
	var dir := DirAccess.open(directory)
	var file_path := directory.path_join(dir.get_files()[0])
	var corrupt := FileAccess.open(file_path,FileAccess.WRITE)
	corrupt.store_string("corrupt source profile")
	corrupt.close()
	_expect(not coordinator.commit(f.prepared,f.source,f.profile_id,Admission.RULES,f.authority).success,"Corrupt source profile cannot be silently initialized again.")
	_expect(FileAccess.get_file_as_string(file_path) == "corrupt source profile","Failed admission preserves corrupt evidence.")

func _test_live_gates() -> void:
	for character: StringName in [Fixture.PLAYER_CHARACTER_GUARD,Fixture.PLAYER_CHARACTER_VAELIS]:
		var session := ArenaCombatSession.new(7,null,Fixture.ENCOUNTER_WAVE_ONE_GOBLINS,character)
		session.initialize_wave_one_goblins(Vector2i.ZERO,Vector2i(3_000_000,0),false)
		var before := session.simulation.random.get_draw_count()
		session.configure_reward_mode("normal")
		var status := session.get_character_persistence_status()
		_expect(not status.persistent,"No incomplete restoration path may be advertised as permanent gameplay.")
		_expect(session.simulation.random.get_draw_count() == before,"Starter/source audit must not consume combat RNG.")
		if character == Fixture.PLAYER_CHARACTER_GUARD:
			_expect(status.reason == "guard_fixture_nonpersistent_by_design","Owner-approved Guard remains an intentionally nonpersistent test fixture.")
		else:
			_expect(status.get("starter_verified",false) and status.reason == "interrupted_wave_resource_checkpoint_and_instance_application_unavailable","Live Vaelis status must distinguish verified source admission from missing run restoration.")
		_expect(session.start_encounter().success,"Existing nonpersistent gameplay remains playable.")
		for id: String in session.get_targetable_enemy_ids(): session.get_actor_state(StringName(id)).current_hpc = 0
		session.advance_by(1)
		var player := session.get_actor_state(&"player")
		player.current_hpc = 3
		if player.resources.has("mana"): player.resources.mana = 1
		var resources := player.resources.duplicate(true)
		_expect(session.request_next_wave().success and player.current_hpc == 3 and player.resources == resources,"NEXT WAVE remains distinct from new-run refills.")
		_expect(session.reset_encounter(false).success,"Fixture RESET remains available and never calls profile deletion.")
	var developer := ArenaCombatSession.new(7,null,Fixture.ENCOUNTER_WAVE_ONE_GOBLINS,Fixture.PLAYER_CHARACTER_VAELIS)
	developer.initialize_wave_one_goblins(Vector2i.ZERO,Vector2i(3_000_000,0),false)
	developer.configure_reward_mode("dev_normal")
	_expect(developer.get_character_persistence_status().get("profile_namespace") == "dev_normal" and not developer.get_character_persistence_status().persistent,"Developer namespace availability must not imply activated permanent saving.")
	developer.configure_reward_mode("normal")
	_expect(developer.get_character_persistence_status().get("reason") == "nonproduction_mode_lineage","Switching back to NORMAL cannot reclassify earlier developer progression.")

func _remove_fixture(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path): return
	var dir := DirAccess.open(path)
	for name: String in dir.get_files(): DirAccess.remove_absolute(path.path_join(name))
	for name: String in dir.get_directories(): _remove_fixture(path.path_join(name))
	DirAccess.remove_absolute(path)

func _expect(value: bool, message: String) -> void:
	if not value: _failures.append(message)
