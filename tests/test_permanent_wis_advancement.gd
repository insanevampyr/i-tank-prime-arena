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

func fixture(score: int = 10, mode: String = "mana", funds: int = 10000) -> Dictionary:
	var f: Dictionary = Strength.new().setup_actor(44002,9,funds)
	f.actor.attributes.wis = score
	f.actor.base_combat_stats.ss = score-1
	f.actor.progression_policy.resource_mode = mode
	f.actor.progression_policy.initial_wis = score
	if mode == "mana":
		f.actor.resource_maxima.mana = score+10
		f.state.resources.mana = 2
	else:
		f.actor.resource_maxima.erase("mana")
		f.actor.resource_maxima.ap = 0
		f.state.resources.erase("mana")
		f.state.resources.ap = 0
	f.actor.apply_equipment_stat_modifiers(f.actor.equipment_stat_modifiers)
	return f

func run() -> Array[String]:
	boundaries()
	rejections()
	var first := playable()
	check(first == playable(),"Real UI purchase and subsequent cast replay identically.")
	persistence()
	print("44B permanent WIS: %d assertions." % assertions)
	return failures

func boundaries() -> void:
	var frozen: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/audits/TASK_37C_VERIFIED_SOURCE_CATALOG.json"))
	for mode: String in ["mana","ability"]:
		for score in range(1,20):
			for difference in [-1,0,1]:
				var f := fixture(score,mode,price(score)+difference)
				var state: Dictionary = f.state.to_dictionary()
				var stats: Dictionary = f.actor.combat_stats.duplicate(true)
				var original: Dictionary = f.actor.source_character_definition.to_dictionary()
				var rng: Dictionary = f.sim.random.wave_entry_state()
				var result: Dictionary = f.ledger.purchase_advancement(f.sim,"wis_step",&"attribute",&"wis",selection(score))
				check(result.success == (difference >= 0),"Exact affordability %s/%s/%s." % [mode,score,difference])
				if difference < 0:
					check(f.actor.attributes.wis == score and f.ledger.spent_xp == 0 and f.state.to_dictionary() == state,"Unaffordable purchase cannot mutate anything.")
				else:
					var rows: Array = frozen.charts["mana" if mode == "mana" else "regular"]
					var expected: int = int(String(rows[score+1].cells.WIS).split("-")[0])
					check(f.actor.attributes.wis == score+1 and f.actor.get_combat_stat("ss") == expected and f.ledger.spent_xp == price(score) and f.ledger.to_dictionary().unspent_xp == difference,"Permanent WIS, independent frozen SS and exact EXPC deduction.")
					check(f.actor.resource_maxima.get("mana") == (score+11 if mode == "mana" else null),"Only Mana users receive +1 maximum; never invent an Ability-user Mana pool.")
					check(f.state.resources == state.resources and f.state.current_hpc == state.current_hpc,"No current resource/HPC refill or clamp.")
					for field: String in stats:
						if field != "ss": check(f.actor.combat_stats[field] == stats[field],"Unrelated statistic remains exact: "+field)
					check(not f.actor.base_combat_stats.has("msl") and not f.actor.base_combat_stats.has("mana_recovery_per_hour"),"Chart references do not activate MSL/MR/H systems.")
					var snapshot: Dictionary = f.sim.get_state_snapshot()
					check(f.ledger.purchase_advancement(f.sim,"wis_step",&"attribute",&"wis",selection(score+1)).get("reason") == "duplicate_advancement_request" and f.sim.get_state_snapshot() == snapshot,"Duplicate request is an atomic no-op.")
				check(f.sim.random.wave_entry_state() == rng and f.actor.source_character_definition.to_dictionary() == original,"No purchase RNG or authored-identity mutation.")
				check(f.state.inventory_quantities == state.inventory_quantities and f.state.equipment_refs == PackedStringArray(state.equipment_refs),"Inventory/equipment unchanged.")

func rejections() -> void:
	for score in [-1,0,20,21,35]:
		var p := PrimeV3AdvancementCatalog.make_purchase_preview(&"attribute",&"wis",score,score+1)
		check(not p.available,"Reject unsupported current WIS %s." % score)
	for kind: String in ["ss_exception","missing_ss","missing_wis","missing_mode","missing_mana","authored_msl","busy","stale","missing_preview","test"]:
		var f := fixture()
		match kind:
			"ss_exception": f.actor.base_combat_stats.ss = 19; f.actor.apply_equipment_stat_modifiers({})
			"missing_ss": f.actor.base_combat_stats.erase("ss")
			"missing_wis": f.actor.attributes.erase("wis")
			"missing_mode": f.actor.progression_policy.erase("resource_mode")
			"missing_mana": f.actor.resource_maxima.erase("mana")
			"authored_msl": f.actor.base_combat_stats.msl = 9
			"busy": f.state.current_action_instance_id = "ongoing"
			"test": f.ledger.mode = "test"
		var preview := selection(9) if kind == "stale" else ({} if kind == "missing_preview" else selection(10))
		var before: Dictionary = f.sim.get_state_snapshot()
		check(not f.ledger.purchase_advancement(f.sim,"reject",&"attribute",&"wis",preview).success and f.sim.get_state_snapshot() == before and f.ledger.spent_xp == 0,"Fail closed without mutation: "+kind)
	var equipment := fixture()
	equipment.actor.apply_equipment_stat_modifiers({"mr":-2,"dt":-1,"dp":-2})
	equipment.state.timed_stat_effects["separate_effect"] = {"stat_modifiers":{"wis":5,"ss":3}}
	var layered: Dictionary = equipment.ledger.purchase_advancement(equipment.sim,"layer",&"attribute",&"wis",selection(10))
	check(layered.success and equipment.actor.combat_stats.ss == 10 and equipment.actor.combat_stats.mr == 8 and equipment.sim.get_effective_actor_combat_stat(equipment.actor.actor_id,"ss") == 13,"Equipment/direct modifiers remain separate and apply once; temporary WIS is not inferred: %s / %s / %s" % [layered,equipment.actor.combat_stats,equipment.sim.get_effective_actor_combat_stat(equipment.actor.actor_id,"ss")])

func playable() -> Dictionary:
	var helper := Historical.new().helper
	var scene := helper._scene()
	var c: ArenaCombatController = scene.get_node("CombatController")
	c.set_physics_process(false)
	check(c.select_player_character_for_testing(Fixture.PLAYER_CHARACTER_VAELIS).success,"Real UI fixture admits.")
	var session := c._session
	session._reward_ledger.earned_xp = 10000 # Disposable nonpersistent UI fixture only.
	session.get_actor_state(&"player").resources.mana = 4
	c._on_inventory_toggle_pressed(); c._update_rewards_panel(true)
	var index := -1
	for i in range(c._advancement_options.size()):
		if c._advancement_options[i].get("target_id") == "wis": index = i
	check(index >= 0,"READY offers WIS in existing advancement UI.")
	if index >= 0:
		c._advancement_option.select(index); c._update_rewards_panel_text()
		check(c._rewards_label.text.contains("WIS 10 -> 11 | SS 9 -> 10 | 3000 EXPC | Available EXPC 10000") and c._rewards_label.text.contains("Mana Max 20 -> 21 (+1). Current Mana unchanged"),"Full WIS/SS/Mana/price/balance preview.")
		c._purchase_advancement_button.pressed.emit()
	var actor := session.simulation.get_actor_definition(&"player")
	check(actor.attributes.wis == 11 and actor.get_combat_stat("ss") == 10 and actor.resource_maxima.mana == 21 and session.get_actor_state(&"player").resources.mana == 4,"Actual button invokes authoritative purchase.")
	var model := CharacterSheetProjection.capture(session)
	check(model.primaries.any(func(row): return row.id == "WIS" and row.original == 10 and row.permanent == 11) and model.derived.any(func(row): return row.id == "SS" and row.effective == 10),"Character Sheet shows purchased WIS/SS and unchanged original.")
	var sim := session.simulation
	# Real Force Shield uses the new authoritative SS; no alternate casting path.
	session.set_opponent_behavior_enabled(false)
	check(session.start_encounter().success,"Purchased actor can enter normal combat.")
	check(session.request_player_special(VaelisForceFixture.FORCE_SHIELD_ID).success,"Real Special accepts the purchased actor.")
	session.advance_by(5000000)
	check(sim.get_resolved_events().any(func(event): return event.event_type == &"special_skill_resolved" and event.payload.ss_target == 10),"Actual authoritative cast rolls against purchased SS10.")
	var rng: Dictionary = sim.random.wave_entry_state()
	var harness := TwoClientSyncHarness.new(44002)
	harness.authority.simulation = sim
	harness.deliver_in_order(harness.authority.publish_current_events())
	check(harness.compare_clients().success and harness.client_a.get_state_snapshot() == sim.get_state_snapshot(),"WIS state/events converge through unchanged schema12.")
	var result := {"snapshot":sim.get_state_snapshot(),"events":sim.get_resolved_events(),"rng":rng}
	helper._free(scene)
	return result

func persistence() -> void:
	var h := Historical.new()
	h.root = OS.get_cache_dir().path_join("itank-storage-tests/wis44_%s_%s" % [OS.get_process_id(),Time.get_ticks_usec()])
	var old_storage := PlayableCharacterPersistence.test_storage
	var old_nonpersistent := PlayableCharacterPersistence.test_nonpersistent
	PlayableCharacterPersistence.test_nonpersistent = false
	for mode: String in ["normal","dev_normal"]:
		var f := h.make_history(mode,Credit.BASELINE,4 if mode == "normal" else 2,mode)
		if not f.get("success",false): check(false,"Historical history prepares."); continue
		if mode == "dev_normal":
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
			if c._session.get_reward_state().unspent_xp >= 3000: break
			check(c._session.request_next_wave().success,"Earn next verified fixture wave.")
			h.helper._defeat_wave(c._session)
		var service := c._session._playable_persistence
		var before: Dictionary = service._prior.duplicate(true)
		var bought := c._session.request_character_advancement(&"attribute",&"wis","durable_wis",selection(10))
		check(bought.success and bought.get("persistence",{}).success and service._last_ack,"WIS/EXPC/Mana publish in one verified generation: %s" % bought)
		if not bought.success: h.helper._free(scene); continue
		check(service._prior.purchases.slice(0,before.purchases.size()) == before.purchases and service._prior.settlements.slice(0,before.settlements.size()) == before.settlements,"Every prior purchase and settlement receipt remains exact.")
		var saved: Dictionary = CharacterSaveContract.decode(CharacterSaveContract.encode(service._prior).text).payload
		check(saved.generation == before.generation+1 and saved.xp.earned == before.xp.earned and saved.xp.unspent == before.xp.unspent-3000 and saved.permanent.growth == before.permanent.growth and saved.base_attributes == before.base_attributes and saved.items == before.items,"Immutable old progression, receipts, identity, items and exact EXPC deduction.")
		check(saved.recovery.player.resources == before.recovery.player.resources and saved.permanent.resource_maxima.mana == before.permanent.resource_maxima.mana+1,"Checkpoint current Mana does not refill.")
		if c._session.get_encounter_state() == ArenaCombatSession.ENCOUNTER_BETWEEN_WAVE_DOWNTIME:
			check(c._session.request_next_wave().success,"NEXT WAVE preserves purchased WIS and acknowledged history.")
			saved = CharacterSaveContract.decode(CharacterSaveContract.encode(service._prior).text).payload
			check(c._session.simulation.get_actor_definition(&"player").get_combat_stat("ss") == 10 and saved.purchases.back().target_id == "wis","NEXT WAVE uses purchased SS without another purchase or grant.")
		var exported := CharacterBackupReader.new().begin_export(service)
		check(exported.success and CharacterBackupContract.decode(exported.text,mode).success,"Complete WIS backup exports and previews.")
		var restored := CharacterSaveStorage.new(h.root.path_join("restored_"+mode))
		var restore := CharacterBackupRestoration.new()
		check(restore.begin(exported.text,mode,null,restored).success and restore.confirm().success,"WIS backup restores transactionally.")
		restore.dispose()
		check(CharacterSaveStorage.history_records(restored.inspect_profile(f.profile)) == exported.history,"Restoration retains byte-exact history.")
		h.helper._free(scene)
		scene = h.web.make_scene(); c = scene.get_node("CombatController")
		check(c._admit_existing_profile(mode).success,"Reload durable WIS.")
		c._run_choice_dialog.get_ok_button().pressed.emit()
		check(c._session.simulation.get_actor_definition(&"player").attributes.wis == 11 and c._session._playable_persistence._prior == saved,"Reload reconstructs exact WIS/Mana history: %s / %s / %s" % [c._session.simulation.get_actor_definition(&"player").attributes,difference(c._session._playable_persistence._prior,saved),saved.generation])
		check(c._session.request_character_advancement(&"attribute",&"wis","durable_wis",selection(11)).get("reason") == "duplicate_advancement_request","Original request cannot repurchase after reload.")
		h.helper._free(scene)
		# Explicit NEW RUN must retain permanent WIS and original growth while
		# publishing a new run/policy atomically in the same namespace.
		scene = h.web.make_scene(); c = scene.get_node("CombatController")
		c._admit_existing_profile(mode)
		c._ask_abandon_loaded_run()
		PlayableCharacterPersistence.test_run_id = "wis_new_run_"+mode
		c._abandon_run_dialog.get_ok_button().pressed.emit()
		var new_run: Dictionary = c._session._playable_persistence._prior
		check(new_run.purchases == saved.purchases and new_run.permanent == saved.permanent and new_run.xp == saved.xp and new_run.recovery.run_id != saved.recovery.run_id and c._session._playable_persistence.mode == mode,"NEW RUN preserves committed WIS, Mana, XP and history; namespace never changes.")
		check(c._session.start_encounter().success,"Start the new paid WIS entry.")
		c._session.get_actor_state(&"player").current_hpc = 0
		c._session.advance_by(1)
		c._on_encounter_button_pressed()
		check(c._session.get_encounter_state() == ArenaCombatSession.ENCOUNTER_READY and c._session.simulation.get_actor_definition(&"player").attributes.wis == 11 and c._session._playable_persistence._prior.purchases == saved.purchases,"Actual RETRY restores the verified entry with WIS purchases exactly once.")
		h.helper._free(scene)
		var backend := Web.Backend.new()
		backend.histories[f.profile] = exported.history.duplicate(true)
		PlayableBrowserPersistence.test_factory = func(): return CharacterBrowserStorage.new(backend.transport)
		scene = h.web.make_scene(); c = scene.get_node("CombatController")
		c._admit_existing_profile(mode); h.web.pump(c); c._run_choice_dialog.get_ok_button().pressed.emit()
		service = c._session._playable_persistence
		check(service._prior == saved,"Simulated Web reload preserves V4/V5 WIS evidence and namespace: %s / %s" % [difference(service._prior,saved),saved.generation])
		service.browser.inject_test_fault("lost_ack")
		var browser_buy := c._session.request_character_advancement(&"attribute",&"wis","web_wis",selection(11))
		check(browser_buy.success and browser_buy.persistence.state == "pending","Browser WIS publication is single-flight.")
		check(not c._session.request_character_advancement(&"attribute",&"wis","second_pending",selection(12)).success,"Pending acknowledgement rejects another purchase.")
		h.web.pump(c)
		var count: int = backend.histories[f.profile].size()
		service.reconcile(); h.web.pump(c)
		check(service._last_ack and backend.histories[f.profile].size() == count and service._prior.purchases.back().value_after == 12,"Lost acknowledgement reconciles exactly once without another deduction.")
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
