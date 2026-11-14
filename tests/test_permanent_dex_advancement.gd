extends RefCounted

const Strength = preload("res://tests/test_task_37b_strength.gd")
const Playable = preload("res://tests/test_playable_vaelis_persistence.gd")
const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
var failures: Array[String] = []
var assertions := 0

func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok: failures.append(message)

func selection(value: int, choice: String) -> Dictionary:
	return {"allocation":choice,"expected_current_value":value,"expected_cost":PrimeV3AdvancementCatalog.attribute_cost(value)}

func run() -> Array[String]:
	for mode: String in ["mana","regular"]:
		for choice: String in ["dt","dp"]:
			check(transaction(mode,choice) == transaction(mode,choice),"Seeded purchases, events and RNG reproduce exactly.")
	boundaries()
	historical_allocations()
	persistent()
	print("41B permanent DEX: %d assertions." % assertions)
	return failures

func transaction(mode: String, choice: String) -> Dictionary:
	var f: Dictionary = Strength.new().setup_actor(411,9,12000)
	f.actor.progression_policy.resource_mode = mode
	var source_before: Dictionary = f.actor.source_character_definition.to_dictionary()
	var state_before: Dictionary = f.state.to_dictionary()
	var draws: int = f.sim.random.get_draw_count()
	for invalid: Dictionary in [{},selection(8,choice),selection(9,"invalid")]:
		var before: Dictionary = f.sim.get_state_snapshot()
		check(not f.ledger.purchase_advancement(f.sim,"invalid",&"attribute",&"dex",invalid).success and f.sim.get_state_snapshot() == before and f.ledger.spent_xp == 0,"Missing, stale or unsupported choice is atomic.")
	var denied: Dictionary = f.sim.request_character_development(f.actor.actor_id,"free","dex_purchase",{"before":9,"after":10,"allocation":choice})
	check(not denied.success and f.ledger.spent_xp == 0,"Generic development commands cannot manufacture paid allocation grants.")
	var first: Dictionary = f.ledger.purchase_advancement(f.sim,"dex_one",&"attribute",&"dex",selection(9,choice))
	check(first.success,"A legal explicit DEX purchase succeeds.")
	if not first.success: return {}
	check(f.actor.attributes.dex == 10 and f.actor.base_combat_stats.acc == 9 and f.ledger.spent_xp == 3000,"9->10 costs exactly 3000 and correctly leaves ACC 9.")
	check(f.actor.base_combat_stats.dt == source_before.combat_stats.dt + (1 if choice == "dt" else 0) and f.actor.base_combat_stats.dp == source_before.combat_stats.dp + (1 if choice == "dp" else 0),"Only the selected permanent Dodge receives the new point.")
	check(f.state.current_hpc == state_before.current_hpc and f.state.resources == state_before.resources and f.state.inventory_quantities == state_before.inventory_quantities and f.sim.random.get_draw_count() == draws,"Purchase grants no resources, items, clock or RNG.")
	var snap: Dictionary = f.sim.get_state_snapshot()
	check(not f.ledger.purchase_advancement(f.sim,"dex_one",&"attribute",&"dex",selection(10,choice)).success and f.sim.get_state_snapshot() == snap,"Duplicate command changes nothing.")
	var second: Dictionary = f.ledger.purchase_advancement(f.sim,"dex_two",&"attribute",&"dex",selection(10,choice))
	check(second.success and f.actor.attributes.dex == 11 and f.sim.get_effective_actor_combat_stat(f.actor.actor_id,"acc") == 10 and f.ledger.spent_xp == 6000,"10->11 costs 3000 and authoritative ACC becomes 10.")
	if mode == "mana":
		var balance := BalanceActorProfile.capture(f.actor.source_character_definition,f.actor,f.state,0,f.ledger.purchase_records)
		check(balance.success and balance.profile.effective_dex == 11,"Balance accepts proven purchased DEX without rewriting source.")
	check(f.actor.source_character_definition.to_dictionary() == source_before,"Authored identity is immutable.")
	f.state.timed_stat_effects["dex_bonus"] = {"stat_modifiers":{"dex":2}}
	check(f.sim.get_effective_actor_combat_stat(f.actor.actor_id,"acc") == 11,"Temporary DEX uses permanent purchased DEX exactly once.")
	f.state.timed_stat_effects.clear()
	check(f.sim.get_effective_actor_combat_stat(f.actor.actor_id,"acc") == 10,"Expiry restores purchased ACC, not authored ACC.")
	var poor: Dictionary = Strength.new().setup_actor(1,9,2999)
	var unchanged: Dictionary = poor.sim.get_state_snapshot()
	check(not poor.ledger.purchase_advancement(poor.sim,"poor",&"attribute",&"dex",selection(9,choice)).success and poor.sim.get_state_snapshot() == unchanged and poor.ledger.spent_xp == 0,"Insufficient EXPC spends and grants nothing.")
	check(not PrimeV3AdvancementCatalog.make_purchase_preview(&"attribute",&"dex",20,21).available,"No progression above 20 is enabled.")
	var harness := TwoClientSyncHarness.new(411)
	harness.authority.simulation = f.sim
	harness.deliver_in_order(harness.authority.publish_current_events())
	check(harness.compare_clients().success and harness.client_a.get_state_snapshot() == f.sim.get_state_snapshot(),"Purchase events converge under schema 12.")
	return f.sim.get_state_snapshot()

func persistent() -> void:
	var old_storage := PlayableCharacterPersistence.test_storage
	var old_flag := PlayableCharacterPersistence.test_nonpersistent
	var root := OS.get_cache_dir().path_join("itank-storage-tests/dex41_%s_%s" % [OS.get_process_id(),Time.get_ticks_usec()])
	var storage := CharacterSaveStorage.new(root)
	PlayableCharacterPersistence.test_storage = storage
	PlayableCharacterPersistence.test_nonpersistent = false
	var helper := Playable.new()
	var scene := helper._scene()
	var c: ArenaCombatController = scene.get_node("CombatController")
	c.set_physics_process(false)
	c._profile_namespace = "dev_normal"
	check(c.select_player_character_for_testing(&"vaelis_thorn").success,"Admit only a disposable legacy fixture.")
	for wave in range(4):
		c._session.set_opponent_behavior_enabled(false)
		helper._defeat_wave(c._session)
		if c._session.get_reward_state().unspent_xp >= 6000: break
		check(c._session.request_next_wave().success,"Earn sufficient EXPC with existing combat.")
	check(helper._failures.is_empty(),"Fixture combat remains legal.")
	check(c._session.request_next_wave().success,"Secure unfinished entry for READY reload.")
	helper._free(scene)
	scene = helper._scene(); c = scene.get_node("CombatController")
	check(c._open_legacy_profile().success and c._session.get_encounter_state() == ArenaCombatSession.ENCOUNTER_READY,"Existing fixture loads READY.")
	c._on_inventory_toggle_pressed()
	c._update_rewards_panel(true)
	var chosen := -1
	for i in range(c._advancement_options.size()):
		var option: Dictionary = c._advancement_options[i]
		if option.get("target_id") == "dex" and option.get("allocation") == "dp": chosen = i
	check(chosen >= 0,"READY offers explicit DP purchase.")
	if chosen >= 0:
		c._advancement_option.select(chosen)
		c._purchase_advancement_button.pressed.emit()
	var service := c._session._playable_persistence
	var stored := storage.read_profile("dev_vaelis_thorn")
	check(stored.success and service._last_ack and c._session.simulation.get_actor_definition(&"player").attributes.dex == 10,"UI confirmation acknowledges the paid allocation and attribute together.")
	if stored.success and not stored.payload.purchases.is_empty():
		check(stored.payload.purchases.back().allocation == "dp" and stored.payload.base_attributes.dex == 9,"Receipt stores the choice; authored baseline stays 9.")
		var request: String = c._session._reward_ledger.purchase_records.back().request_id
		var expected: Dictionary = stored.payload.duplicate(true)
		var exported := CharacterBackupReader.new().begin_export(service)
		check(exported.success and CharacterBackupContract.decode(exported.text,"dev_normal").success,"Full history exports and validates purchased DEX.")
		helper._free(scene); scene = helper._scene(); c = scene.get_node("CombatController")
		check(c._open_legacy_profile().success,"Paid DEX reloads through existing-only admission.")
		check(c._session._playable_persistence._prior == expected and c._session.simulation.get_actor_definition(&"player").attributes.dex == 10,"Reload preserves exact progression and allocations.")
		check(c._session.request_character_advancement(&"attribute",&"dex",request,selection(10,"dt")).get("reason") == "duplicate_advancement_request","Original request cannot spend again after reload.")
		var changed := expected.duplicate(true)
		changed.purchases.back().allocation = "dt"
		check(not CharacterProfileProjection.hydrate(changed,service.source,service.profile_id,PlayableCharacterAdmission.RULES,service._verify).success,"Receipt/allocation conflicts fail closed.")
		var session := c._session
		var second := session.request_character_advancement(&"attribute",&"dex","second_paid_point",selection(10,"dt"))
		check(second.success and second.get("persistence",{}).success,"The other allocation choice also publishes atomically.")
		check(session.simulation.get_actor_definition(&"player").attributes.dex == 11 and session.simulation.get_effective_actor_combat_stat(&"player","acc") == 10,"Both paid choices survive the live development getter.")
		session.set_opponent_behavior_enabled(false)
		check(session.start_encounter().success,"Start actual combat with purchased DEX.")
		var blocked_before := session.get_state_snapshot()
		check(not session.request_character_advancement(&"attribute",&"dex","combat",selection(11,"dt")).success and session.get_state_snapshot() == blocked_before,"Active combat cannot purchase or allocate.")
		session.set_opponent_behavior_enabled(false)
		var attack_target := StringName(session.get_targetable_enemy_ids()[0])
		session.select_target(attack_target)
		session.simulation.apply_authoritative_position(&"player",Vector2i(8_000_000,5_000_000),0)
		session.simulation.apply_authoritative_position(attack_target,Vector2i(9_000_000,5_000_000),0)
		for i in range(20):
			session.request_player_attack("dex_attack_%s" % i)
			session.advance_by(500000)
		var seen := false
		for event: CombatEvent in session.simulation.get_resolved_events():
			if event.event_type == &"physical_attack_accuracy_resolved" and event.source_actor_id == &"player":
				seen = true
				check(event.payload.base_acc == 10,"Real attack ACC consumes the permanent purchased chart value.")
		check(seen,"Purchased DEX is exercised by an actual resolved attack.")
		session.get_actor_state(&"player").current_hpc = 0
		session.advance_by(1)
		var authorization := session.get_return_to_wave_one_authorization()
		check(authorization.success,"Prepare authorized return from the existing attempt checkpoint.")
		if authorization.success:
			var next := c._prepare_encounter_fixture(true,authorization.checkpoint,{},ArenaRewardLedger.resolve_run_policy("dev_normal",1))
			check(next.success and c._session.simulation.get_actor_definition(&"player").attributes.dex == 11,"Authorized V4 new run preserves pre-attempt paid DEX and allocations.")
		service = c._session._playable_persistence
		var latest := storage.read_profile("dev_vaelis_thorn")
		check(CharacterSaveContract.decode(latest.document).version == 4,"DEX and allocation survive policy-bearing V4 publication.")
		exported = CharacterBackupReader.new().begin_export(service)
		var destination := CharacterSaveStorage.new(root.path_join("restored"))
		var restore := CharacterBackupRestoration.new()
		check(restore.begin(exported.text,"dev_normal",null,destination).get("state") == "confirmation_required","DEX backup restoration requires explicit confirmation.")
		check(restore.confirm().success,"DEX-bearing complete history restores transactionally into disposable storage.")
		restore.dispose()
		check(CharacterSaveStorage.history_records(destination.inspect_profile("dev_vaelis_thorn")) == exported.history,"Restoration retains exact documents, receipts and allocation history.")
		var web = preload("res://tests/test_playable_browser_persistence.gd").new()
		var backend = preload("res://tests/test_playable_browser_persistence.gd").Backend.new()
		backend.histories["dev_vaelis_thorn"] = exported.history.duplicate(true)
		PlayableBrowserPersistence.test_factory = func(): return CharacterBrowserStorage.new(backend.transport)
		var browser_scene := helper._scene()
		var browser_controller: ArenaCombatController = browser_scene.get_node("CombatController")
		browser_controller._open_legacy_profile(); web.pump(browser_controller)
		check(browser_controller._web_operation.is_empty() and browser_controller._session._playable_persistence != null and browser_controller._session._playable_persistence._prior == latest.payload,"Simulated IndexedDB admission recovers exact paid DEX and V4 history.")
		check(backend.histories["dev_vaelis_thorn"] == exported.history,"Browser reload creates no duplicate purchases or grants.")
		helper._free(browser_scene)
		PlayableBrowserPersistence.test_factory = Callable()

	helper._free(scene)
	PlayableCharacterPersistence.test_storage = old_storage
	PlayableCharacterPersistence.test_nonpersistent = old_flag
	helper._remove_fixture(root)

func boundaries() -> void:
	# Independent V3 DEX ACC and p.102 prices, not generated from engine outputs.
	var expected_acc := [0,5,5,6,6,7,7,8,8,9,9,10,10,11,12,13,14,15,16,17,18]
	for mode: String in ["mana","regular"]:
		for score in range(1,20):
			var f: Dictionary = Strength.new().setup_actor(4,9,10000)
			f.actor.progression_policy.resource_mode = mode
			f.actor.attributes.dex = score
			f.actor.base_combat_stats.acc = expected_acc[score]
			f.actor.base_combat_stats.dt = score
			f.actor.base_combat_stats.dp = 0
			f.actor.apply_equipment_stat_modifiers(f.actor.equipment_stat_modifiers)
			var cost := 2000 if score <= 5 else (3000 if score <= 10 else (5000 if score <= 15 else 7000))
			var paid: Dictionary = f.ledger.purchase_advancement(f.sim,"boundary",&"attribute",&"dex",{"allocation":"dp","expected_current_value":score,"expected_cost":cost})
			check(paid.success and f.ledger.spent_xp == cost and f.sim.get_effective_actor_combat_stat(f.actor.actor_id,"acc") == expected_acc[score+1],"Every supported point uses independent cost/ACC expectations: %s/%s" % [mode,score])

func historical_allocations() -> void:
	for digest: String in ["3df0412b72ba5d966b2eb645887fedfbb591782cffc7bff41c192e52583c6d20","6b0a4d543e890513fccc2efffb5feb6fab8e8f462651bd0b6903341eb47132d0"]:
		for choice: String in ["dt","dp"]:
			var starter := PlayableCharacterAdmission.prepare_starter(&"vaelis_thorn","normal",digest)
			check(starter.success,"Reconstruct only allowlisted historical source fixtures.")
			if not starter.success: continue
			var actor: CombatActorDefinition = starter.actor
			var original := actor.source_character_definition.to_dictionary()
			var dt: int = actor.base_combat_stats.dt
			var dp: int = actor.base_combat_stats.dp
			actor.apply_equipment_stat_modifiers({"dt":-2,"dp":-1})
			var sim := CombatSimulation.new(41)
			sim.register_actor(actor)
			var ledger := ArenaRewardLedger.new()
			ledger.configure("normal",actor.actor_id,1)
			ledger.earned_xp = 3000
			check(ledger.purchase_advancement(sim,"historical_dex",&"attribute",&"dex",selection(9,choice)).success,"Verified historical allocations can buy exactly one new point.")
			check(actor.base_combat_stats.dt == dt + (1 if choice == "dt" else 0) and actor.base_combat_stats.dp == dp + (1 if choice == "dp" else 0),"Historical 3/6 and 6/3 points never redistribute.")
			check(sim.get_effective_actor_combat_stat(actor.actor_id,"dt") == actor.base_combat_stats.dt-2 and sim.get_effective_actor_combat_stat(actor.actor_id,"dp") == actor.base_combat_stats.dp-1,"Equipment modifiers apply once after purchasing.")
			check(actor.source_character_definition.to_dictionary() == original,"Historical source stays immutable.")
			check(BalanceActorProfile.capture(actor.source_character_definition,actor,sim.get_actor_state(actor.actor_id),0,ledger.purchase_records).success,"Historical runtime Balance retains verified provenance after DEX purchase.")
