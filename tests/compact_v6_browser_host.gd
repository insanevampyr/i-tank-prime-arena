extends "res://tests/test_compact_v6_gameplay_candidate.gd"
const BrowserRoute = preload("res://scripts/rewards/compact_v6_browser_storage.gd")
const BrowserCoordinator = preload("res://scripts/rewards/compact_v6_browser_coordinator.gd")
const Grant = preload("res://scripts/rewards/character_expc_grant.gd")

class Service extends Observed:
	var route: RefCounted
	var coordinator: RefCounted
	var pending := false
	var writes: Array = []
	var candidate_metrics := {}
	func open(p_mode: String, new_run: bool = false, authorization: Dictionary = {}, multiplier: Variant = null, existing_only: bool = false) -> Dictionary:
		var loaded: Dictionary = route.load_current()
		if not loaded.success: return loaded
		if not loaded.get("empty",false):
			compact_parent = loaded.record
			return open_compact_browser_disposable(route,new_run,authorization,multiplier)
		if existing_only or not loaded.legacy.legacy_rows.is_empty(): return {"success":false,"reason":"explicit_conversion_required"}
		mode = p_mode; source = route.source; profile_id = route.profile
		var starter := PlayableCharacterAdmission.prepare_starter(&"vaelis_thorn",mode,CharacterProfileProjection.fingerprint(source.to_dictionary()))
		var opened := open_verified_history(starter,{"success":true,"generations":[],"writer_locked":false,"pending_write":false},false,{},multiplier)
		if opened.success:
			if CharacterProfileProjection.fingerprint(source.to_dictionary()) != CharacterProfileProjection.fingerprint(route.source.to_dictionary()): return {"success":false,"reason":"test_source_mismatch"}
			route.source = source
		return opened
	func publish_prepared() -> Dictionary:
		if pending: return {"success":false,"state":"pending","reason":"operation_in_flight"}
		var offered: Dictionary = observer.prepare(observer.head())
		if not offered.success: errors.append(offered); return offered
		last_prepared = offered.prepared
		candidate_metrics = offered.get("metrics",{}).duplicate(true)
		coordinator = load("res://scripts/rewards/compact_v6_browser_coordinator.gd").new()
		var response: Dictionary = coordinator.begin_compact(route,observer,last_prepared,route.token(route.load_current()))
		pending = response.get("state") == "pending"
		return response
	func poll_publication() -> Dictionary:
		if not pending: return {"success":false,"reason":"no_pending_operation"}
		var response: Dictionary = coordinator.poll_compact()
		if response.get("state") == "pending": return response
		pending = false
		if not response.success: errors.append(response); return response
		var ack := ack_compact_disposable(response,route)
		if not ack.success: errors.append(ack); return ack
		var adopted: Dictionary = observer.adopt_compact(last_prepared,response,route)
		if not adopted.success: errors.append(adopted); return adopted
		response.metrics["s2_candidate"] = candidate_metrics.duplicate(true)
		records.append(observer.current_copy()); writes.append(response.get("metrics",{}))
		return response

var prepared_route: RefCounted
func factory(_store: CharacterSaveStorage, _mode: String, _parent: Dictionary) -> Service:
	var result := Service.new(); result.route = prepared_route; return result

# Same real session/ingest/checkpoint construction as Q, allowing the existing
# browser's pending result rather than pretending queued work is acknowledged.
func start_browser(route: RefCounted, multiplier: Variant = null) -> Dictionary:
	prepared_route = route
	PlayableCharacterPersistence.test_run_id = "run_45q"
	var service := Service.new(); service.route = route
	var opened := service.open(route.scope,false,{},multiplier)
	if not opened.success: return opened
	var session := ArenaCombatSession.new(1,null,Fixture.ENCOUNTER_WAVE_ONE_GOBLINS,Fixture.PLAYER_CHARACTER_VAELIS)
	session._playable_persistence = service; session._run_reward_policy = service.get_run_reward_policy(); session._entry_bootstrap = service.recovery.duplicate(true)
	var wave: int = int(service.recovery.get("wave_id","wave_1").trim_prefix("wave_"))
	session._encounter_fixture_id = [Fixture.ENCOUNTER_WAVE_ONE_GOBLINS,Fixture.ENCOUNTER_WAVE_TWO_SPADOODLES,Fixture.ENCOUNTER_WAVE_THREE_SKELLY_HADES,Fixture.ENCOUNTER_WAVE_FOUR_GARGOYLES,Fixture.ENCOUNTER_WAVE_FIVE_RARE_HUMAN_WARRIOR][wave-1]
	if not service.recovery.is_empty():
		session.simulation.wave_entry_opening = service.recovery.opening.duplicate(true)
		for row: Dictionary in service.recovery.roster:
			for i in range(row.dice_results.size()): session._entry_dice.append({"value":row.dice_results[i],"rng_draw_index":row.rng_draw_indices[i]})
	session.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
	var initializer: String = ["initialize_wave_one_goblins","initialize_wave_two_spadoodles","initialize_wave_three_skelly_hades","initialize_wave_four_gargoyles","initialize_wave_five_rare_human_warrior"][wave-1]
	var initialized: Dictionary = session.call(initializer,Vector2i(14000000,8000000),Vector2i(17000000,8000000),false)
	if not initialized.success: return initialized
	var actor := session.simulation.get_actor_definition(&"player")
	var movement := PrimeMovementModel.new(actor.get_combat_stat("mr"),actor.attributes.spd,actor.attributes.end,3,0,0,DeterministicCombatRng.new(1))
	if not service.recovery.is_empty(): movement.restore_wave_entry(service.recovery.movement)
	session.player_movement_boundary_provider = movement.wave_entry_state
	session.player_endurance_profile_refresher = func(a): movement.set_effective_end(a.attributes.end)
	session.player_speed_profile_refresher = func(a): movement.set_effective_spd(a.attributes.spd); movement.base_mr = a.get_combat_stat("mr")
	var configured := session.configure_reward_mode(route.scope)
	if not configured.success: return configured
	session._authorized_entry_write = true
	var finalized := service.bind_runtime(session)
	session._authorized_entry_write = false
	if not finalized.get("success",false) and finalized.get("state") != "pending": return finalized
	return {"success":true,"service":service,"session":session,"movement":movement,"pending":service.pending}

func grant_browser(f: Dictionary) -> Dictionary:
	var service: Service = f.service
	if service.pending: return {"success":false,"reason":"operation_in_flight"}
	var offered: Dictionary = service.observer.prepare_credit(f.session,service.observer.head(),func(q): return {"confirmed":true,"binding":V6.digest(q)},service.route.load_current)
	if not offered.success or offered.get("no_op",false): return offered
	service.last_prepared = offered.prepared
	service._prepared = service.observer.publication_request(offered.prepared).proposal
	service.coordinator = BrowserCoordinator.new()
	var response: Dictionary = service.coordinator.begin_compact(service.route,service.observer,offered.prepared,service.route.token(service.route.load_current()))
	service.pending = response.get("state") == "pending"
	return response
func apply_grant_runtime(f: Dictionary, ack: Dictionary) -> Dictionary:
	var delivery := Grant.new(); delivery._session = f.session; delivery._service = f.service; delivery._prepared = f.service._prepared; delivery._runtime = delivery._runtime_digest()
	return delivery._published(ack)
