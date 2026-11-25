extends RefCounted

# Initial candidate only. The selected disposable storage must independently
# establish an empty head and CAS before any playable acknowledgement.
const V3 = preload("res://scripts/rewards/minimal_character_snapshot_v3.gd")
const Strip = preload("res://scripts/rewards/legacy_to_compact_v6_prototype.gd")
const Player = preload("res://scripts/player/placeholder_player.gd")

# Reuse original creation/projection/receipt authorization. Never publish a V2
# generation or run the legacy storage writer while building the first v3 record.
class Genesis extends PlayableCharacterPersistence:
	func publish_prepared() -> Dictionary:
		return {"success":false,"state":"initial_candidate_not_saved","durable":false}

static func prepare(scope: String, seed_value: int) -> Dictionary:
	var starter := PlayableCharacterAdmission.prepare_starter(&"vaelis_thorn",scope)
	if not starter.success: return starter
	var service := Genesis.new()
	service.mode = scope; service.profile_id = starter.profile_id
	service.storage = CharacterSaveStorage.new(OS.get_cache_dir().path_join("itank-storage-tests/minimal46c2_46k_genesis"))
	# This creates source-authorized starting grants only, not a claimed imported
	# verification result. Existing destination inspection/publication is separate.
	var opened := service.open_verified_history(starter,{"success":true,"generations":[],"writer_locked":false,"pending_write":false,"profile_directory_exists":false},false,{})
	if not opened.success: return opened
	var session := ArenaCombatSession.new(seed_value,null,PrimeV3VerticalSliceFixture.ENCOUNTER_WAVE_ONE_GOBLINS,&"vaelis_thorn")
	session._playable_persistence = service
	session.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
	var initialized := session.initialize_wave_one_goblins(Vector2i(14000000,8000000),Vector2i(17000000,8000000),false)
	if not initialized.success: return initialized
	var player := Player.new(); player.reset_for_encounter(Vector2(14,8))
	var configured := player.configure_authoritative_actor_profile(session.simulation.get_actor_definition(&"player"))
	if not configured.success: player.free(); return configured
	session.player_movement_boundary_provider = player.capture_wave_entry_motion
	session.player_speed_profile_refresher = player.refresh_permanent_speed_profile
	session.player_endurance_profile_refresher = player.refresh_permanent_endurance_profile
	var rewards := session.configure_reward_mode(scope)
	var finished := session.finalize_playable_persistence()
	if not rewards.success or finished.get("state") != "initial_candidate_not_saved" or service._prepared.is_empty():
		player.free(); return {"success":false,"reason":"initial_source_checkpoint_unavailable","details":finished}
	var authorized := CharacterPersistenceCoordinator._authorize(service._prepared,service.source,service.profile_id,PlayableCharacterAdmission.RULES,service._verify)
	if not authorized.success: player.free(); return authorized
	var decoded := CharacterSaveContract.decode(service._prepared.document)
	if not decoded.success: player.free(); return decoded
	var payload: Dictionary = decoded.payload
	if payload.generation != 1 or not payload.purchases.is_empty() or not payload.permanent.growth.is_empty() or not payload.permanent.award_receipts.is_empty() or payload.has("expc_credits"):
		player.free(); return {"success":false,"reason":"initial_candidate_not_fresh"}
	var current: Dictionary = Strip.Conversion.strip(payload)
	var ledger := {}
	for key: String in V3.LEDGER+["xp_multiplier","expc_credit_total"]:
		if current.recovery.ledger.has(key): ledger[key] = current.recovery.ledger[key]
	current.recovery.ledger = ledger
	var evidence := {"awards":[],"purchases":[],"growth":[],"settlements":payload.settlements.duplicate(true),"credit":null,"order":[],"item_debits":[]}
	var request_digest := V3.V6.digest(service._prepared)
	var epoch := "native_"+V3.V6.digest([service.profile_id,scope,payload.lineage,payload.run_history,request_digest])
	var journal := [{"sequence":1,"id":service._prepared.transaction_id,"request_digest":request_digest}]
	var body := V3.assemble(current,evidence,epoch,service._prepared.transaction_id,journal,service.source)
	var encoded := V3.encode(body,service.source,service.profile_id,scope)
	player.free()
	if encoded.success: encoded["source_projection"] = payload; encoded["source"] = service.source
	return encoded
