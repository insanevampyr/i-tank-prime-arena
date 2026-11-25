extends RefCounted
const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
const Strength = preload("res://tests/test_task_37b_strength.gd")
const Historical = preload("res://tests/test_historical_vaelis_admission.gd")
const Web = preload("res://tests/test_playable_browser_persistence.gd")
const Credit = preload("res://scripts/rewards/character_expc_credit.gd")
var failures: Array[String] = []
var assertions := 0

func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok: failures.append(message)

func price(score: int) -> int:
	return 2000 if score <= 5 else (3000 if score <= 10 else (5000 if score <= 15 else 7000))

func selection(score: int) -> Dictionary:
	return {"expected_current_value":score,"expected_cost":price(score)}

func fixture(score: int = 6, mode: String = "mana", funds: int = 10000) -> Dictionary:
	var f: Dictionary = Strength.new().setup_actor(45002,9,funds)
	f.actor.attributes.end = score
	f.actor.progression_policy.resource_mode = mode
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/audits/TASK_37C_VERIFIED_SOURCE_CATALOG.json"))
	var values := String(source.charts["mana" if mode == "mana" else "regular"][score].cells.END).split("-")
	f.actor.base_combat_stats.nal = int(values[0])
	f.actor.base_combat_stats.physical_soak = int(values[1])
	f.actor.base_combat_stats.hpb = int(values[2])
	f.actor.apply_equipment_stat_modifiers(f.actor.equipment_stat_modifiers)
	return f

func run() -> Array[String]:
	boundaries()
	rejections()
	combat_consumers()
	check(playable() == playable(),"Purchased END, Running, events and simulated clients replay deterministically.")
	persistence()
	print("45B permanent END: %d assertions." % assertions)
	return failures

func boundaries() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/audits/TASK_37C_VERIFIED_SOURCE_CATALOG.json"))
	for mode: String in ["mana","ability"]:
		for score in range(1,20):
			for difference in [-1,0,1]:
				var f := fixture(score,mode,price(score)+difference)
				var attributes: Dictionary = f.actor.attributes.duplicate(true)
				var stats: Dictionary = f.actor.combat_stats.duplicate(true)
				var state: Dictionary = f.state.to_dictionary()
				var rng: Dictionary = f.sim.random.wave_entry_state()
				var bought: Dictionary = f.ledger.purchase_advancement(f.sim,"end_step",&"attribute",&"end",selection(score))
				check(bought.success == (difference >= 0),"Every END price/affordability edge: %s/%s/%s." % [mode,score,difference])
				if difference < 0:
					check(f.state.to_dictionary() == state and f.actor.attributes == attributes and f.actor.combat_stats == stats,"Unaffordable rejection has no mutation.")
				else:
					var expected := String(source.charts["mana" if mode == "mana" else "regular"][score+1].cells.END).split("-")
					check(f.actor.attributes.end == score+1 and f.actor.get_combat_stat("nal") == int(expected[0]) and f.actor.get_combat_stat("physical_soak") == int(expected[1]) and f.actor.get_combat_stat("hpb") == int(expected[2]),"Independent frozen NAL/PS/HPB after purchase.")
					check(f.ledger.spent_xp == price(score) and f.ledger.to_dictionary().unspent_xp == difference and f.ledger.earned_xp == price(score)+difference,"Exactly one EXPC deduction and no earned-XP mutation.")
					for field: String in attributes:
						if field != "end": check(f.actor.attributes[field] == attributes[field],"Unrelated primary remains exact: "+field)
					for field: String in stats:
						if field not in ["nal","physical_soak","hpb"]: check(f.actor.combat_stats[field] == stats[field],"Unrelated combat statistic, including HPM, remains exact: "+field)
					check(f.state.resources == state.resources and f.state.current_hpc == state.current_hpc and f.state.inventory_quantities == state.inventory_quantities,"No HPC/resource refill or inventory change.")
					var snapshot: Dictionary = f.sim.get_state_snapshot()
					check(f.ledger.purchase_advancement(f.sim,"end_step",&"attribute",&"end",selection(score+1)).get("reason") == "duplicate_advancement_request" and f.sim.get_state_snapshot() == snapshot,"Duplicate submission is an atomic no-op.")
				check(f.sim.random.wave_entry_state() == rng,"END purchases never consume RNG.")

func rejections() -> void:
	for score in [-1,0,20,21,35]:
		check(not PrimeV3AdvancementCatalog.make_purchase_preview(&"attribute",&"end",score,score+1).available,"Reject invalid score/current cap: %s" % score)
	for kind: String in ["nal","physical_soak","hpb","source","missing","mode","busy","stale","preview","test"]:
		var f := fixture()
		match kind:
			"nal","physical_soak","hpb": f.actor.base_combat_stats[kind] += 1
			"source": f.actor.field_sources.clear()
			"missing": f.actor.attributes.erase("end")
			"mode": f.actor.progression_policy.resource_mode = "unknown"
			"busy": f.state.current_action_instance_id = "pending"
			"test": f.ledger.mode = "test"
		var quoted := selection(5) if kind == "stale" else ({} if kind == "preview" else selection(6))
		var before: Dictionary = f.sim.get_state_snapshot()
		check(not f.ledger.purchase_advancement(f.sim,"reject",&"attribute",&"end",quoted).success and f.sim.get_state_snapshot() == before and f.ledger.spent_xp == 0,"Reject unsupported/authored/stale input without mutation: "+kind)
	var f := fixture(9)
	f.actor.apply_equipment_stat_modifiers({"mr":-2,"dt":-1,"dp":-3})
	f.state.timed_stat_effects["rage"] = {"stat_modifiers":{"nal":-2}}
	check(f.ledger.purchase_advancement(f.sim,"layer",&"attribute",&"end",selection(9)).success and f.actor.combat_stats.nal == 2 and f.sim.get_effective_actor_combat_stat(f.actor.actor_id,"nal") == 0 and f.actor.combat_stats.mr == 8 and f.actor.combat_stats.dt == 5,"Independent armor penalties and Rage NAL apply exactly once.")

	var wounded := fixture(7)
	wounded.state.current_hpc = 3
	check(wounded.ledger.purchase_advancement(wounded.sim,"wounded",&"attribute",&"end",selection(7)).success and wounded.state.current_hpc == 3 and wounded.actor.get_combat_stat("hpm") == 9,"Purchasing HPB2 cannot refill a wounded character or increase HPM.")

func playable() -> Dictionary:
	var helper := Historical.new().helper
	var scene := helper._scene()
	var c: ArenaCombatController = scene.get_node("CombatController")
	c.set_physics_process(false)
	check(c.select_player_character_for_testing(Fixture.PLAYER_CHARACTER_VAELIS).success,"Use real admitted Vaelis UI fixture.")
	var s := c._session
	s._reward_ledger.earned_xp = 10000 # Disposable nonpersistent UI funds only.
	c._on_inventory_toggle_pressed(); c._update_rewards_panel(true)
	var index := -1
	for i in range(c._advancement_options.size()):
		if c._advancement_options[i].get("target_id") == "end": index = i
	check(index >= 0,"Existing Character Management offers END without allocation.")
	var movement: PrimeMovementModel = c._player._movement
	movement.request_running(); movement.advance(1000000,Vector2.ZERO)
	movement._running_retry_cooldown_us = 123456
	movement._recovery_remaining_units = 777
	var dynamic := movement.wave_entry_state()
	var combat_rng: Dictionary = s.simulation.random.wave_entry_state()
	if index >= 0:
		c._advancement_option.select(index); c._update_rewards_panel_text()
		check(c._rewards_label.text.contains("END 6 -> 7 | NAL 1 -> 1 | PS 3 -> 3 | HPB 1 -> 1 | 3000 EXPC") and c._rewards_label.text.contains("HPM/HPC unchanged"),"Explicit price/derived/HPM preview.")
		c._purchase_advancement_button.pressed.emit()
	check(c._player._movement == movement and movement.effective_end == 7 and movement.get_max_running_duration_us() == 35000000,"Same Running model immediately uses END7/35 seconds.")
	check(movement.wave_entry_state().state == dynamic.state and movement.wave_entry_state().rng == dynamic.rng and s.simulation.random.wave_entry_state() == combat_rng,"Fatigue, elapsed time, recovery, cooldowns and RNG are unchanged.")
	check(movement.get_running_bonus_mr() == 5 and movement.base_mr == 10 and movement.effective_spd == 11,"MR, speed and SPD-derived Running bonus unchanged.")
	var second := s.request_character_advancement(&"attribute",&"end","end8",selection(7))
	var actor := s.simulation.get_actor_definition(&"player")
	check(second.success and movement.get_max_running_duration_us() == 40000000 and actor.get_combat_stat("physical_soak") == 4 and actor.get_combat_stat("hpb") == 2 and actor.get_combat_stat("hpm") == 9 and s.get_actor_state(&"player").current_hpc == 9,"END7->8 changes PS/HPB/Running only, never existing HPM/HPC.")
	var model := CharacterSheetProjection.capture(s)
	check(model.primaries.any(func(row): return row.id == "END" and row.original == 6 and row.permanent == 8) and model.derived.any(func(row): return row.id == "HPB" and row.effective == 2),"Character Sheet retains original END and shows purchased values.")
	movement.stop_running(PrimeMovementModel.RunningEndReason.INTENTIONAL_STOP)
	s.set_opponent_behavior_enabled(false)
	check(s.start_encounter().success,"Start combat with purchased END.")
	var before: Dictionary = s.get_state_snapshot()
	check(not s.request_character_advancement(&"attribute",&"end","combat",selection(8)).success and s.get_state_snapshot() == before,"Active combat cannot buy END.")
	var harness := TwoClientSyncHarness.new(45002)
	harness.authority.simulation = s.simulation
	harness.deliver_in_order(harness.authority.publish_current_events())
	check(harness.compare_clients().success and harness.client_a.get_state_snapshot() == s.simulation.get_state_snapshot(),"Unchanged schema12 events and snapshots converge.")
	var result := {"snapshot":s.simulation.get_state_snapshot(),"rng":s.simulation.random.wave_entry_state()}
	helper._free(scene)
	return result

func persistence() -> void:
	var h := Historical.new()
	h.root = OS.get_cache_dir().path_join("itank-storage-tests/end45_%s_%s" % [OS.get_process_id(),Time.get_ticks_usec()])
	var old_storage := PlayableCharacterPersistence.test_storage
	var old_nonpersistent := PlayableCharacterPersistence.test_nonpersistent
	PlayableCharacterPersistence.test_nonpersistent = false
	for entry: Dictionary in [{"mode":"normal","version":4,"credit":false},{"mode":"dev_normal","version":2,"credit":false},{"mode":"dev_normal","version":4,"credit":true}]:
		var mode: String = entry.mode
		var f := h.make_history(mode,Credit.BASELINE,entry.version,mode+str(entry.version))
		if not f.get("success",false): check(false,"Historical history prepares."); continue
		if entry.credit:
			var q := Credit.prepare(f.payload,func(binding): return {"confirmed":true,"binding":Credit.digest(binding)})
			var prepared := CharacterPersistenceCoordinator.prepare(q.payload,q.payload.settlements,q.transaction_id,f.payload.generation,f.payload.secured_checkpoints)
			var verifier := func(_op,binding): return {"authorized":true,"binding":binding,"lineage":q.payload.lineage}
			check(CharacterPersistenceCoordinator.new(f.storage).commit(prepared.prepared,PlayableCharacterAdmission.prepare_starter(&"vaelis_thorn",mode,Credit.BASELINE).source,f.profile,PlayableCharacterAdmission.RULES,verifier).success,"Disposable V5 credit publishes only through existing coordinator.")
		PlayableCharacterPersistence.test_storage = f.storage
		var scene := h.web.make_scene()
		var c: ArenaCombatController = scene.get_node("CombatController")
		check(c._admit_existing_profile(mode).success,"Open isolated historical profile.")
		c._run_choice_dialog.get_ok_button().pressed.emit()
		for funding_wave in range(4):
			if c._session.get_reward_state().unspent_xp >= 6000: break
			check(c._session.request_next_wave().success,"Earn next verified fixture wave.")
			h.helper._defeat_wave(c._session)
		var service := c._session._playable_persistence
		var before: Dictionary = service._prior.duplicate(true)
		var hpm_before: int = c._session.get_actor_max_hpm(&"player")
		var hpc_before: int = c._session.get_actor_state(&"player").current_hpc
		var refresher := c._session.player_endurance_profile_refresher
		c._session.player_endurance_profile_refresher = Callable()
		check(c._session.request_character_advancement(&"attribute",&"end","missing_refresher",selection(6)).get("reason") == "endurance_running_profile_refresh_unavailable" and service._prior == before,"Missing Running boundary rejects before any permanent mutation.")
		c._session.player_endurance_profile_refresher = refresher
		var bought := c._session.request_character_advancement(&"attribute",&"end","durable_end",selection(6))
		check(bought.success and bought.get("persistence",{}).success and service._last_ack,"END/EXPC/HPM publish in one verified generation: %s" % bought)
		if not bought.success: h.helper._free(scene); continue
		check(service._prior.purchases.slice(0,before.purchases.size()) == before.purchases and service._prior.settlements.slice(0,before.settlements.size()) == before.settlements,"Every prior purchase and settlement receipt remains exact.")
		check(c._session.get_actor_max_hpm(&"player") == hpm_before and c._session.get_actor_state(&"player").current_hpc == hpc_before,"Persistent END purchase cannot increase either HPM or HPC.")
		var saved: Dictionary = CharacterSaveContract.decode(CharacterSaveContract.encode(service._prior).text).payload
		check(saved.generation == before.generation+1 and saved.xp.earned == before.xp.earned and saved.xp.unspent == before.xp.unspent-3000 and saved.permanent.growth == before.permanent.growth and saved.base_attributes == before.base_attributes and saved.items == before.items,"Immutable old progression, receipts, identity, items and exact EXPC deduction.")
		check(saved.recovery.player.resources == before.recovery.player.resources and saved.permanent.resource_maxima == before.permanent.resource_maxima and saved.recovery.movement.profile.end == 7,"Checkpoint current HPM does not refill.")
		if c._session.get_encounter_state() == ArenaCombatSession.ENCOUNTER_BETWEEN_WAVE_DOWNTIME:
			check(c._session.request_next_wave().success,"NEXT WAVE preserves purchased END and acknowledged history.")
			saved = CharacterSaveContract.decode(CharacterSaveContract.encode(service._prior).text).payload
			check(c._session.simulation.get_actor_definition(&"player").get_combat_stat("hpb") == 1 and saved.purchases.back().target_id == "end","NEXT WAVE uses purchased HPB without another purchase or grant.")
		var exported := CharacterBackupReader.new().begin_export(service)
		check(exported.success and CharacterBackupContract.decode(exported.text,mode).success,"Complete END backup exports and previews.")
		var restored := CharacterSaveStorage.new(h.root.path_join("restored_"+mode+str(entry.version)))
		var restore := CharacterBackupRestoration.new()
		check(restore.begin(exported.text,mode,null,restored).success and restore.confirm().success,"END backup restores transactionally.")
		restore.dispose()
		check(CharacterSaveStorage.history_records(restored.inspect_profile(f.profile)) == exported.history,"Restoration retains byte-exact history.")
		h.helper._free(scene)
		scene = h.web.make_scene(); c = scene.get_node("CombatController")
		check(c._admit_existing_profile(mode).success,"Reload durable END.")
		c._run_choice_dialog.get_ok_button().pressed.emit()
		check(c._session.simulation.get_actor_definition(&"player").attributes.end == 7 and c._session._playable_persistence._prior == saved,"Reload reconstructs exact END/HPM history: %s / %s / %s" % [c._session.simulation.get_actor_definition(&"player").attributes,difference(c._session._playable_persistence._prior,saved),saved.generation])
		check(c._session.request_character_advancement(&"attribute",&"end","durable_end",selection(7)).get("reason") == "duplicate_advancement_request","Original request cannot repurchase after reload.")
		h.helper._free(scene)
		# Explicit NEW RUN must retain permanent END and original growth while
		# publishing a new run/policy atomically in the same namespace.
		scene = h.web.make_scene(); c = scene.get_node("CombatController")
		c._admit_existing_profile(mode)
		c._ask_abandon_loaded_run()
		PlayableCharacterPersistence.test_run_id = "end_new_run_"+mode
		c._abandon_run_dialog.get_ok_button().pressed.emit()
		var new_run: Dictionary = c._session._playable_persistence._prior
		check(new_run.purchases == saved.purchases and new_run.permanent == saved.permanent and new_run.xp == saved.xp and new_run.recovery.run_id != saved.recovery.run_id and c._session._playable_persistence.mode == mode,"NEW RUN preserves committed END, HPM, XP and history; namespace never changes.")
		check(c._session.start_encounter().success,"Start the new paid END entry.")
		c._session.get_actor_state(&"player").current_hpc = 0
		c._session.advance_by(1)
		c._on_encounter_button_pressed()
		check(c._session.get_encounter_state() == ArenaCombatSession.ENCOUNTER_READY and c._session.simulation.get_actor_definition(&"player").attributes.end == 7 and c._session._playable_persistence._prior.purchases == saved.purchases,"Actual RETRY restores the verified entry with END purchases exactly once.")
		h.helper._free(scene)
		var backend := Web.Backend.new()
		backend.histories[f.profile] = exported.history.duplicate(true)
		PlayableBrowserPersistence.test_factory = func(): return CharacterBrowserStorage.new(backend.transport)
		scene = h.web.make_scene(); c = scene.get_node("CombatController")
		c._admit_existing_profile(mode); h.web.pump(c); c._run_choice_dialog.get_ok_button().pressed.emit()
		service = c._session._playable_persistence
		check(service._prior == saved,"Simulated Web reload preserves V4/V5 END evidence and namespace: %s / %s" % [difference(service._prior,saved),saved.generation])
		service.browser.inject_test_fault("lost_ack")
		var browser_buy := c._session.request_character_advancement(&"attribute",&"end","web_end",selection(7))
		check(browser_buy.success and browser_buy.persistence.state == "pending","Browser END publication is single-flight.")
		check(not c._session.request_character_advancement(&"attribute",&"end","second_pending",selection(8)).success,"Pending acknowledgement rejects another purchase.")
		h.web.pump(c)
		var count: int = backend.histories[f.profile].size()
		service.reconcile(); h.web.pump(c)
		check(service._last_ack and backend.histories[f.profile].size() == count and service._prior.purchases.back().value_after == 8,"Lost acknowledgement reconciles exactly once without another deduction.")
		h.helper._free(scene)
		PlayableBrowserPersistence.test_factory = Callable()
	check(h.failures.is_empty() and h.helper._failures.is_empty() and h.web.failures.is_empty(),"Underlying source-backed combat and storage fixtures remain valid.")
	PlayableCharacterPersistence.test_storage = old_storage
	PlayableCharacterPersistence.test_nonpersistent = old_nonpersistent
	PlayableCharacterPersistence.test_run_id = ""
	h.helper._remove_fixture(h.root)

func difference(a: Dictionary, b: Dictionary) -> Array:
	var result: Array = []
	for key: Variant in b:
		if a.get(key) != b[key]: result.append(str(key))
	return result

# Real physical/Soak/Special resolvers consume purchased values; no duplicate
# damage implementation or substitute formula is used in these controls.
func calibrate_target(actor: CombatActorDefinition, score: int) -> void:
	actor.attributes.end = score
	actor.progression_policy.resource_mode = "mana"
	actor.field_sources["attributes.end"] = "TEST-FIXTURE verified END chart reference"
	actor.base_combat_stats.nal = 1
	actor.base_combat_stats.physical_soak = 3 if score == 7 else 4
	actor.base_combat_stats.hpb = 1 if score == 7 else 2
	# The generic damage fixture starts without PS; these explicitly supplied
	# chart inputs resolve only those fixture fields.
	for field: String in ["nal","physical_soak","hpb"]: actor.unresolved_fields.erase("combat_stats."+field)
	actor.apply_equipment_stat_modifiers(actor.equipment_stat_modifiers)

func combat_consumers() -> void:
	var helper := preload("res://tests/test_physical_damage.gd").new()
	var results := []
	for purchased: bool in [false,true]:
		var sim := CombatSimulation.new(helper._find_seed_for_rolls(5,[6],6))
		var damage := helper._damage_definition(1,6,false,true)
		var armor := helper._armor(&"torso",&"body",PackedStringArray(["torso"]),{"bashing":2})
		helper._configure_simulation(sim,damage,PackedStringArray(["bashing"]),&"torso",[armor],{},5)
		var target := sim.get_actor_definition(&"target")
		calibrate_target(target,9)
		if purchased: check(target.apply_verified_endurance_advancement(9,10).success,"Source-qualified NAL threshold purchase.")
		sim.begin_combat()
		var attack := sim.start_physical_attack(&"attacker",&"target",helper._attack(&"end_physical",damage,PackedStringArray(["bashing"])),"end_physical",&"torso",true)
		sim.advance_to(1000000)
		var resolved := helper._resolve_fixture_damage({"simulation":sim,"attack_id":attack.attack_instance_id},"end_physical")
		check(resolved.armor_tal == 2 and resolved.natural_armor_level == (2 if purchased else 1) and resolved.final_damage == (2 if purchased else 3),"Purchased NAL is used after separate torso TAL by actual physical damage.")
		results.append(sim.random.wave_entry_state())
	check(results[0] == results[1],"NAL improvement changes damage, never RNG consumption.")
	for purchased: bool in [false,true]:
		var sim := CombatSimulation.new(helper._find_seed_for_d20_sequence([5,4]))
		var damage := helper._damage_definition(1,6,false,true)
		var profile := CombatDefenseProfile.new(&"end_soak",PackedStringArray(["physical_soak","dodge","weapon_block","shield_block"]),{},null,null,PackedStringArray(["TEST-FIXTURE"]))
		helper._configure_simulation(sim,damage,PackedStringArray(["bashing"]),&"torso",[],{},5,profile,false,true)
		var target := sim.get_actor_definition(&"target")
		calibrate_target(target,7)
		if purchased: check(target.apply_verified_endurance_advancement(7,8).success,"Source-qualified PS/HPB threshold purchase.")
		sim.begin_combat()
		var attack := sim.start_physical_attack(&"attacker",&"target",helper._attack(&"end_soak",damage,PackedStringArray(["bashing"]),&"torso",true),"end_soak",&"torso",true)
		sim.advance_to(1000000)
		var defense := sim.resolve_pending_defense(attack.attack_instance_id,"end_soak")
		check(defense.status == (CombatDefenseResolution.STATUS_DEFENDED if purchased else CombatDefenseResolution.STATUS_EXHAUSTED),"The same ordinary roll4 fails PS3 and succeeds purchased PS4.")
	check(helper._failures.is_empty(),"Actual physical resolver controls remain valid.")
	var magic := preload("res://tests/test_vaelis_force_magic.gd").new()
	var bolts := []
	for purchased: bool in [false,true]:
		var session: ArenaCombatSession = magic._session(579,Vector2i(20000000,21000000))
		var target := session.simulation.get_actor_definition(Fixture.OPPONENT_ID)
		calibrate_target(target,9)
		if purchased: check(target.apply_verified_endurance_advancement(9,10).success,"Magic isolation has an actual purchased NAL increase.")
		var cast := session.request_player_special(preload("res://scripts/combat/vaelis_force_fixture.gd").FORCE_BOLT_ID)
		var event: CombatEvent = magic._last_event(session,&"force_bolt_damage_resolved")
		check(cast.get("special_success",false) and event != null and event.payload.final_damage == 6,"Purchased physical NAL/PS never reduce Force Bolt Special damage.")
		bolts.append(session.simulation.random.wave_entry_state())
	check(bolts[0] == bolts[1],"Physical protection changes do not alter magic RNG.")
