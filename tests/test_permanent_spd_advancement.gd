extends RefCounted

const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
const Strength = preload("res://tests/test_task_37b_strength.gd")
const Playable = preload("res://tests/test_playable_vaelis_persistence.gd")
const BrowserTests = preload("res://tests/test_playable_browser_persistence.gd")
# Independent expectations from V3 SPD cells and the accepted p.102 brackets.
const MR := [0,3,4,4,4,6,6,6,8,8,10,10,12,12,14,14,16,18,18,20,22]
const AT := [0,1,1,1,1,1,1,1,1,1,1,1,2,2,2,2,2,3,3,3,3]
var failures: Array[String] = []
var assertions := 0

func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok: failures.append(message)

func price(score: int) -> int:
	return 2000 if score <= 5 else (3000 if score <= 10 else (5000 if score <= 15 else 7000))

func selection(score: int) -> Dictionary:
	return {"expected_current_value":score,"expected_cost":price(score)}

func fixture(score: int = 11, mode: String = "mana", funds: int = 20000) -> Dictionary:
	var f: Dictionary = Strength.new().setup_actor(430,9,funds)
	f.actor.attributes.spd = score
	f.actor.base_combat_stats.mr = MR[score]
	f.actor.base_combat_stats.at = AT[score]
	f.actor.progression_policy.resource_mode = mode
	f.actor.apply_equipment_stat_modifiers(f.actor.equipment_stat_modifiers)
	return f

func run() -> Array[String]:
	boundaries()
	rejections()
	timing()
	historical()
	check(playable() == playable(),"Actual movement, purchases, action events and RNG replay identically.")
	persistence()
	print("43B permanent SPD: %d assertions." % assertions)
	return failures

func boundaries() -> void:
	for mode: String in ["mana","regular"]:
		for score in range(1,20):
			var f := fixture(score,mode)
			f.actor.apply_equipment_stat_modifiers({"mr":-2,"dt":-1,"dp":-3})
			var source: Dictionary = f.actor.source_character_definition.to_dictionary()
			var attributes: Dictionary = f.actor.attributes.duplicate(true)
			var stats: Dictionary = f.actor.combat_stats.duplicate(true)
			var before: Dictionary = f.state.to_dictionary()
			var rng: Dictionary = f.sim.random.wave_entry_state()
			var paid: Dictionary = f.ledger.purchase_advancement(f.sim,"speed_step",&"attribute",&"spd",selection(score))
			check(paid.success,"Legal +1 SPD purchase: %s/%s." % [mode,score])
			if not paid.success: continue
			check(f.actor.attributes.spd == score+1 and f.actor.base_combat_stats.mr == MR[score+1] and f.actor.base_combat_stats.at == AT[score+1] and f.ledger.spent_xp == price(score),"Independent chart values and current-score cost: %s/%s." % [mode,score])
			check(f.actor.combat_stats.mr == MR[score+1]-2 and f.actor.combat_stats.dt == stats.dt and f.actor.combat_stats.dp == stats.dp,"Armor applies once; Dodge allocation and penalties are unchanged.")
			attributes.spd = score+1
			check(f.actor.attributes == attributes and f.actor.combat_stats.acc == stats.acc and f.actor.combat_stats.init == stats.init,"Only SPD, MR and AT change; INIT, ACC and unrelated primaries stay intact.")
			for field: String in ["current_hpc","resources","conditions","timed_stat_effects","equipment_refs","inventory_quantities","hand_occupancy","remaining_mr_microfeet"]:
				check(f.state.to_dictionary()[field] == before[field],"SPD purchase preserves existing state: "+field)
			check(f.sim.random.wave_entry_state() == rng and f.actor.source_character_definition.to_dictionary() == source,"No purchase RNG or authored-identity mutation.")
			var unchanged: Dictionary = f.sim.get_state_snapshot()
			check(f.ledger.purchase_advancement(f.sim,"speed_step",&"attribute",&"spd",selection(score+1)).reason == "duplicate_advancement_request" and f.sim.get_state_snapshot() == unchanged,"Repeated request cannot spend, grant or append events again.")

func rejections() -> void:
	var f := fixture()
	for invalid: Dictionary in [{},selection(10),{"expected_current_value":11,"expected_cost":3000},{"expected_current_value":11.0,"expected_cost":5000},{"expected_current_value":11,"expected_cost":5000,"allocation":"dt"}]:
		var before: Dictionary = f.sim.get_state_snapshot()
		check(not f.ledger.purchase_advancement(f.sim,"invalid",&"attribute",&"spd",invalid).success and f.sim.get_state_snapshot() == before and f.ledger.spent_xp == 0,"Missing, stale, malformed or allocation-bearing SPD requests fail atomically.")
	var poor := fixture(11,"mana",4999)
	var untouched: Dictionary = poor.sim.get_state_snapshot()
	check(poor.ledger.purchase_advancement(poor.sim,"poor",&"attribute",&"spd",selection(11)).reason == "insufficient_xp" and poor.sim.get_state_snapshot() == untouched and poor.ledger.spent_xp == 0,"Insufficient EXPC cannot change SPD or spend funds.")
	for score in [0,20]:
		var invalid := fixture(score)
		var before: Dictionary = invalid.sim.get_state_snapshot()
		check(not invalid.ledger.purchase_advancement(invalid.sim,"cap",&"attribute",&"spd",selection(score)).success and invalid.sim.get_state_snapshot() == before,"No zero recovery or progression above 20.")
	for field: String in ["mr","at"]:
		var bad := fixture()
		bad.actor.base_combat_stats[field] += 1
		bad.actor.apply_equipment_stat_modifiers(bad.actor.equipment_stat_modifiers)
		var before: Dictionary = bad.sim.get_state_snapshot()
		check(bad.ledger.purchase_advancement(bad.sim,"bad",&"attribute",&"spd",selection(11)).reason == "speed_derived_source_mismatch" and bad.sim.get_state_snapshot() == before,"Unsupported authored MR/AT cannot be overwritten.")
	var unknown := fixture(11,"unknown")
	check(unknown.ledger.purchase_advancement(unknown.sim,"unknown",&"attribute",&"spd",selection(11)).reason == "speed_chart_mode_unavailable","Unknown source mode fails closed.")
	for mode: Variant in [null,42]:
		var malformed := fixture()
		malformed.actor.progression_policy.resource_mode = mode
		check(malformed.ledger.purchase_advancement(malformed.sim,"malformed",&"attribute",&"spd",selection(11)).reason == "speed_chart_mode_unavailable","Malformed mode data is rejected without fabricating a chart choice.")
	var test_mode := fixture()
	test_mode.ledger.configure("test",test_mode.actor.actor_id,1)
	check(test_mode.ledger.purchase_advancement(test_mode.sim,"test",&"attribute",&"spd",selection(11)).reason == "test_mode_advancement_prohibited","TEST retains its purchase prohibition.")
	for path: String in ["res://data/characters/prime_v3_rare_human_warrior_boss.tres","res://data/characters/prime_v3_uncommon_mini_gargoyle_swarmer.tres"]:
		var source: CombatCharacterDefinitionResource = load(path)
		var actor: CombatActorDefinition = source.instantiate_actor(&"exception",source.display_name,PackedStringArray())
		actor.progression_policy.resource_mode = "mana" # Explicit comparison mode; never modify the resource.
		var before := actor.to_dictionary()
		check(actor.apply_verified_speed_advancement(int(actor.attributes.spd),int(actor.attributes.spd)+1).reason == "speed_derived_source_mismatch" and actor.to_dictionary() == before,"Real authored creature MR exceptions are rejected without normalization.")

func timing() -> void:
	var f := fixture()
	var action := CombatActionDefinition.new(&"speed_timing",1)
	var first: Dictionary = f.sim.start_action(f.actor.actor_id,action,"old_act")
	check(first.success,"Begin an actual AT-1 Act.")
	var before: Dictionary = f.sim.get_state_snapshot()
	check(not f.ledger.purchase_advancement(f.sim,"busy",&"attribute",&"spd",selection(11)).success and f.sim.get_state_snapshot() == before,"In-progress actions prohibit SPD changes.")
	f.sim.advance_to(5000000)
	var completed: Dictionary = f.sim.get_action(first.action_instance_id).to_dictionary()
	check(f.ledger.purchase_advancement(f.sim,"idle_speed",&"attribute",&"spd",selection(11)).success,"Buy at the exact prior Act completion timestamp.")
	check(f.sim.get_action(first.action_instance_id).to_dictionary() == completed and f.state.action_timing_anchor_us == 5000000 and f.state.next_action_interval_index == 0,"Completed Act history stays unchanged; only future intervals rebase.")
	var next: Dictionary = f.sim.start_action(f.actor.actor_id,action,"new_act")
	var scheduled: CombatActionInstance = f.sim.get_action(next.action_instance_id)
	check(scheduled.at_at_start == 2 and scheduled.final_effect_due_at_us == 7500000,"AT improvement grants a full future 2.5-second Act, never an instant/stored Act.")
	f.sim.advance_to(7499999)
	check(scheduled.status == CombatActionInstance.STATUS_IN_PROGRESS,"New Act cannot complete early.")
	f.sim.advance_to(7500000)
	check(scheduled.completed_at_us == 7500000,"Actual action resolution uses new AT.")
	check(f.sim.get_action(first.action_instance_id).to_dictionary() == completed,"Later resolution cannot rewrite the old action.")
	var plateau := fixture(12)
	plateau.state.action_timing_anchor_us = 100
	plateau.state.action_timing_cursor_us = 200
	plateau.state.next_action_interval_index = 3
	check(plateau.ledger.purchase_advancement(plateau.sim,"plateau",&"attribute",&"spd",selection(12)).success and plateau.state.next_action_interval_index == 3 and plateau.state.action_timing_anchor_us == 100,"A chart plateau does not unnecessarily reset action timing.")

func historical() -> void:
	for digest: String in ["3df0412b72ba5d966b2eb645887fedfbb591782cffc7bff41c192e52583c6d20","6b0a4d543e890513fccc2efffb5feb6fab8e8f462651bd0b6903341eb47132d0"]:
		for mode: String in ["normal","dev_normal"]:
			var starter := PlayableCharacterAdmission.prepare_starter(&"vaelis_thorn",mode,digest)
			check(starter.success,"Allowlisted historical Vaelis source remains admissible.")
			if not starter.success: continue
			var actor: CombatActorDefinition = starter.actor
			var source := actor.source_character_definition.to_dictionary()
			var dodge := {"dt":actor.base_combat_stats.dt,"dp":actor.base_combat_stats.dp,"acc":actor.base_combat_stats.acc}
			check(actor.apply_verified_speed_advancement(11,12).success and actor.attributes.spd == 12,"Historical 3/6 and 6/3 variants support the same source-verified SPD step.")
			check(actor.base_combat_stats.dt == dodge.dt and actor.base_combat_stats.dp == dodge.dp and actor.base_combat_stats.acc == dodge.acc and actor.source_character_definition.to_dictionary() == source,"Historical allocations, Balance provenance and immutable baseline stay intact.")

func playable() -> Dictionary:
	var helper := Playable.new()
	var scene := helper._scene()
	var c: ArenaCombatController = scene.get_node("CombatController")
	c.set_physics_process(false)
	check(c.select_player_character_for_testing(Fixture.PLAYER_CHARACTER_VAELIS).success,"Use the actual playable scene without persistence.")
	var s := c._session
	s._reward_ledger.earned_xp = 10000 # Explicit disposable funds, never an award or owner profile.
	var player: Node = c._player
	var movement: PrimeMovementModel = player._movement
	movement.request_running()
	movement.advance(1000000,Vector2.ZERO)
	var motion := movement.wave_entry_state()
	var draws := s.simulation.random.wave_entry_state()
	c._on_inventory_toggle_pressed()
	c._update_rewards_panel(true)
	var index := -1
	for i in range(c._advancement_options.size()):
		if c._advancement_options[i].get("target_id") == "spd": index = i
	check(index >= 0,"READY offers permanent SPD advancement without an allocation selector.")
	if index >= 0:
		c._advancement_option.select(index)
		c._update_rewards_panel_text()
		check(c._rewards_label.text.contains("SPD 11 -> 12 | Base MR 10 -> 12 | AT 1 -> 2 | 5000 EXPC"),"Confirmation preview shows SPD, MR, AT and exact EXPC cost.")
		c._purchase_advancement_button.pressed.emit()
	check(player._movement == movement and player.test_effective_spd == 12 and movement.base_mr == 12 and movement.get_running_bonus_mr() == 6 and movement.get_effective_mr() == 18,"Real movement cache immediately uses SPD 12, walking 12 and Running 18.")
	check(movement.wave_entry_state().state == motion.state and movement.wave_entry_state().rng == motion.rng and s.simulation.random.wave_entry_state() == draws,"Refresh preserves Running fatigue, checks, cooldowns and both RNG streams.")
	var model := CharacterSheetProjection.capture(s)
	check(model.primaries.any(func(row): return row.id == "SPD" and row.original == 11 and row.permanent == 12 and row.effective == 12) and model.derived.any(func(row): return row.id == "MR" and row.effective == 12) and model.derived.any(func(row): return row.id == "AT" and row.effective == 2),"Character Sheet displays purchased SPD/MR/AT with original identity preserved.")
	movement.stop_running(PrimeMovementModel.RunningEndReason.INTENTIONAL_STOP)
	movement._running_retry_cooldown_us = 123456 # Nonzero disposable timer fixture.
	var cooldown := movement.wave_entry_state()
	check(s.request_character_advancement(&"attribute",&"spd","plateau_cache",selection(12)).success and movement.wave_entry_state().state == cooldown.state and movement.wave_entry_state().rng == cooldown.rng,"Later purchases preserve actual nonzero recovery/cooldown state.")
	s.set_opponent_behavior_enabled(false)
	check(s.start_encounter().success,"Start real combat using purchased SPD.")
	var start := s.get_actor_state(&"player").position_microfeet
	var displacement := movement.advance(1000000,Vector2.LEFT)
	var desired := start + Vector2i(roundi(displacement.x*1000000),roundi(displacement.y*1000000))
	var moved := c._resolve_player_movement(desired,movement.get_effective_mr())
	check(moved.success and moved.position_microfeet == start+Vector2i(-2400000,0),"Production movement resolver accepts actual 2.4-ft travel per second from new MR.")
	var unchanged := s.get_state_snapshot()
	check(not s.request_character_advancement(&"attribute",&"spd","combat",selection(13)).success and s.get_state_snapshot() == unchanged,"Active combat purchases remain blocked.")
	var declared := s.simulation.start_action(&"player",CombatActionDefinition.new(&"playable_speed_action",1),"playable_act")
	check(declared.success and s.simulation.get_action(declared.action_instance_id).final_effect_due_at_us-s.simulation.clock.get_elapsed_us() == 2500000,"Actual playable actor schedules a full AT-2 Act.")
	var snapshot := s.simulation.get_state_snapshot()
	var harness := TwoClientSyncHarness.new(42)
	harness.authority.simulation = s.simulation
	harness.deliver_in_order(harness.authority.publish_current_events())
	check(harness.compare_clients().success and harness.client_a.get_state_snapshot() == snapshot and snapshot.schema_version == 12,"Purchased SPD, movement, RNG and action history converge under schema 12.")
	helper._free(scene)
	return snapshot

func persistence() -> void:
	var old_storage := PlayableCharacterPersistence.test_storage
	var old_flag := PlayableCharacterPersistence.test_nonpersistent
	var root := OS.get_cache_dir().path_join("itank-storage-tests/spd43_%s_%s" % [OS.get_process_id(),Time.get_ticks_usec()])
	var storage := CharacterSaveStorage.new(root)
	PlayableCharacterPersistence.test_storage = storage
	PlayableCharacterPersistence.test_nonpersistent = false
	var helper := Playable.new()
	var scene := helper._scene()
	var c: ArenaCombatController = scene.get_node("CombatController")
	c.set_physics_process(false)
	c._profile_namespace = "dev_normal"
	check(c.select_player_character_for_testing(Fixture.PLAYER_CHARACTER_VAELIS).success,"Admit a disposable legacy namespace with no owner storage access.")
	for wave in range(4):
		helper._defeat_wave(c._session)
		if c._session.get_reward_state().unspent_xp >= 10000: break
		if wave < 3: check(c._session.request_next_wave().success,"Earn fixture EXPC through existing wave rewards.")
	check(helper._failures.is_empty(),"Existing physical combat still earns legitimate fixture receipts.")
	check(c._session.get_reward_state().unspent_xp >= 10000,"Fixture earns sufficient verified EXPC before attempting purchases.")
	var service := c._session._playable_persistence
	var prior := storage.read_profile("dev_vaelis_thorn")
	check(prior.success and CharacterSaveContract.decode(prior.document).version == 2,"Existing namespace-derived V2 histories remain unchanged before purchase.")
	var now := c._session.simulation.clock.get_elapsed_us()
	var old_actions := {}
	for id: String in c._session.simulation._actions: old_actions[id] = c._session.simulation._actions[id].to_dictionary()
	var bought := c._session.request_character_advancement(&"attribute",&"spd","durable_speed",selection(11))
	check(bought.success and bought.get("persistence",{}).success and service._last_ack,"Downtime SPD and its EXPC receipt publish in one acknowledged generation: %s" % bought)
	var stored := storage.read_profile("dev_vaelis_thorn")
	if bought.success and stored.success:
		check(stored.payload.purchases.slice(0,prior.payload.purchases.size()) == prior.payload.purchases and stored.payload.base_attributes == prior.payload.base_attributes and stored.payload.permanent.growth == prior.payload.permanent.growth,"Historical purchases, authored baseline and earned resource growth are unchanged.")
		check(stored.payload.purchases.back().cost == 5000 and stored.payload.purchases.back().target_id == "spd" and not stored.payload.purchases.back().has("allocation") and stored.payload.recovery.movement.profile.spd == 12 and stored.payload.recovery.movement.profile.mr == 12,"Existing receipt/checkpoint fields durably represent SPD without allocation or new schema.")
		check(c._session.request_next_wave().success and c._session.simulation.clock.get_elapsed_us() == now,"Immediate NEXT WAVE preserves the frozen clock after purchase.")
		var next := c._session.simulation.start_action(&"player",CombatActionDefinition.new(&"wave_speed_action",1),"next_wave_speed")
		check(next.success and c._session.simulation.get_action(next.action_instance_id).final_effect_due_at_us == now+2500000,"Immediate NEXT WAVE cannot reuse old AT intervals for a free action.")
		for id: String in old_actions: check(c._session.simulation._actions[id].to_dictionary() == old_actions[id],"Wave transition and purchase preserve every completed action.")
		helper._free(scene)
		scene = helper._scene(); c = scene.get_node("CombatController")
		check(c._open_legacy_profile().success,"Reload the verified SPD-bearing wave entry.")
		c._run_choice_dialog.get_ok_button().pressed.emit()
		service = c._session._playable_persistence
		check(c._session.simulation.get_actor_definition(&"player").attributes.spd == 12 and c._player._movement.effective_spd == 12 and c._player._movement.base_mr == 12,"Hydration and cached movement agree after reload.")
		check(c._session.request_character_advancement(&"attribute",&"spd","durable_speed",selection(12)).get("reason") == "duplicate_advancement_request","The original pre-reload request identity cannot spend twice.")
		var purchase_history := CharacterBackupReader.new().begin_export(service)
		check(purchase_history.success,"Freeze an independently funded history for the disposable Web purchase branch.")
		var second := c._session.request_character_advancement(&"attribute",&"spd","ready_speed",selection(12))
		check(second.success and second.get("persistence",{}).success,"A new READY purchase publishes through the existing entry transaction.")
		var exported := CharacterBackupReader.new().begin_export(service)
		check(exported.success and CharacterBackupContract.decode(exported.text,"dev_normal").success,"V2 history with SPD exports and validates unchanged.")
		check(c._session.start_encounter().success,"Start the restored paid entry before testing authorized defeat recovery.")
		c._session.get_actor_state(&"player").current_hpc = 0
		c._session.advance_by(1)
		var authorization: Dictionary = c._session.get_return_to_wave_one_authorization()
		check(authorization.success,"Use existing authorized new-run checkpoint.")
		if authorization.success:
			check(c._prepare_encounter_fixture(true,authorization.checkpoint,{},ArenaRewardLedger.resolve_run_policy("dev_normal",1)).success,"New V4 run retains permanent SPD history without namespace conversion.")
		service = c._session._playable_persistence
		var latest := storage.read_profile("dev_vaelis_thorn")
		check(latest.success and CharacterSaveContract.decode(latest.document).version == 4 and c._session.simulation.get_actor_definition(&"player").attributes.spd == 13,"V4 policies coexist with historical SPD purchases.")
		exported = CharacterBackupReader.new().begin_export(service)
		var destination := CharacterSaveStorage.new(root.path_join("restore"))
		var restore := CharacterBackupRestoration.new()
		check(restore.begin(exported.text,"dev_normal",null,destination).get("state") == "confirmation_required" and restore.confirm().success,"SPD backups require confirmation and restore transactionally in disposable storage.")
		restore.dispose()
		check(CharacterSaveStorage.history_records(destination.inspect_profile("dev_vaelis_thorn")) == exported.history,"Mixed V2/V4 documents and receipts retain exact backup history.")
		var backend := BrowserTests.Backend.new()
		backend.histories["dev_vaelis_thorn"] = exported.history.duplicate(true)
		PlayableBrowserPersistence.test_factory = func(): return CharacterBrowserStorage.new(backend.transport)
		var browser_scene := helper._scene()
		var browser: ArenaCombatController = browser_scene.get_node("CombatController")
		browser._open_legacy_profile()
		BrowserTests.new().pump(browser)
		browser._run_choice_dialog.get_ok_button().pressed.emit()
		check(browser._web_operation.is_empty() and browser._session._playable_persistence != null and browser._session._playable_persistence._prior == latest.payload and browser._player._movement.effective_spd == 13,"Asynchronous simulated Web admission recovers exact SPD history and cache.")
		helper._free(browser_scene)
		var purchase_backend := BrowserTests.Backend.new()
		purchase_backend.histories["dev_vaelis_thorn"] = purchase_history.history.duplicate(true)
		PlayableBrowserPersistence.test_factory = func(): return CharacterBrowserStorage.new(purchase_backend.transport)
		browser_scene = helper._scene(); browser = browser_scene.get_node("CombatController")
		browser._open_legacy_profile(); BrowserTests.new().pump(browser)
		browser._run_choice_dialog.get_ok_button().pressed.emit()
		var browser_buy := browser._session.request_character_advancement(&"attribute",&"spd","browser_speed",selection(12))
		check(browser_buy.success and browser_buy.persistence.state == "pending" and browser._player._movement.effective_spd == 13,"Web purchase updates the cache while retaining pending publication protection: %s" % browser_buy)
		check(not browser._session.request_character_advancement(&"attribute",&"spd","pending_duplicate",selection(13)).success,"Pending Web publication blocks a second purchase.")
		BrowserTests.new().pump(browser)
		check(browser._session._playable_persistence._last_ack and browser._session._playable_persistence._prior.purchases.back().value_after == 13,"Browser acknowledgement durably binds the single SPD transaction.")
		helper._free(browser_scene)
		PlayableBrowserPersistence.test_factory = Callable()
	helper._free(scene)
	PlayableCharacterPersistence.test_storage = old_storage
	PlayableCharacterPersistence.test_nonpersistent = old_flag
	helper._remove_fixture(root)
