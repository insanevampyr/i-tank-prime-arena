extends RefCounted

const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
const Playable = preload("res://tests/test_playable_vaelis_persistence.gd")
const ProjectionTests = preload("res://tests/test_character_profile_projection.gd")
var failures: Array[String] = []

func check(value: bool, message: String) -> void:
	if not value: failures.append(message)

func run() -> Array[String]:
	check(PrimeV3AdvancementCatalog.make_purchase_preview(&"attribute",&"str",9,10).cost == 3000,"Printed p.102: STR 9 to 10 costs exactly 3000 EXPC.")
	var first := transactions(37)
	check(first == transactions(37),"Same-seed STR purchases must produce identical history, snapshots and RNG state.")
	source_history()
	playable()
	return failures

func setup_actor(seed_value: int, strength: int = 9, funds: int = 6000, baseline: int = 0) -> Dictionary:
	var actor := Fixture.make_player_actor(Fixture.PLAYER_CHARACTER_VAELIS)
	actor.actor_id = &"generic_buyer" # No character ID/name grants mechanical permission.
	actor.attributes.str = strength
	actor.base_combat_stats.sb = PrimeV3StrengthChart.derived(strength).sb
	actor.apply_equipment_stat_modifiers(actor.equipment_stat_modifiers)
	var sim := CombatSimulation.new(seed_value)
	sim.register_actor(actor)
	var ledger := ArenaRewardLedger.new()
	ledger.configure("normal",actor.actor_id,1,baseline)
	ledger.earned_xp = funds # Explicit isolated transaction balance, not a gameplay award.
	return {"actor":actor,"sim":sim,"ledger":ledger,"state":sim.get_actor_state(actor.actor_id)}

func transactions(seed_value: int) -> Dictionary:
	var f := setup_actor(seed_value)
	var state: CombatActorState = f.state
	state.current_hpc = 3
	state.resources.mana = 1
	state.conditions.append("prone")
	state.timed_stat_effects["verified_sb_bonus"] = {"stat_modifiers":{"sb":2}}
	var preserved := state.to_dictionary()
	var draws: int = f.sim.random.get_draw_count()
	var result: Dictionary = f.ledger.purchase_advancement(f.sim,"purchase/STR/one",&"attribute",&"str")
	check(result.success and f.actor.attributes.str == 10 and f.ledger.spent_xp == 3000 and f.ledger.to_dictionary().unspent_xp == 3000,"One legal request must add one permanent STR and spend exactly 3000 EXPC.")
	check(f.actor.combat_stats.sb == 2 and f.actor.combat_stats.ppg == 9 and f.actor.combat_stats.mwc == 300,"Printed chart: 9 to 10 keeps SB 2 and updates PPG/MWC to 9/300.")
	check(f.sim.get_effective_actor_combat_stat(f.actor.actor_id,"sb") == 4,"Existing temporary SB bonus must remain independent.")
	var current := state.to_dictionary()
	for field: String in ["current_hpc","resources","conditions","timed_stat_effects","equipment_refs","hand_occupancy","weapon_handling","inventory_quantities"]:
		check(current.get(field) == preserved.get(field),"STR purchase must preserve actor state: "+field)
	check(f.sim.random.get_draw_count() == draws,"STR purchasing/recalculation consumes no RNG.")
	var before: Dictionary = f.sim.get_state_snapshot()
	check(not f.ledger.purchase_advancement(f.sim,"purchase/STR/one",&"attribute",&"str").success and f.sim.get_state_snapshot() == before,"Duplicate transaction cannot grant another point, spend EXPC or append events.")
	var catalog := CombatDefinitionCatalog.load_default_fixture_catalog()
	var sword := PackedStringArray(["prime_v3_great_sword"])
	check(not catalog.validate_equipment_strength(9,sword).success and catalog.validate_equipment_strength(10,sword).success,"STR 10 satisfies the registered Great Sword requirement without granting/equipping it.")
	var harness := TwoClientSyncHarness.new(seed_value)
	harness.authority.simulation = f.sim
	harness.deliver_in_order(harness.authority.publish_current_events())
	check(harness.compare_clients().success and harness.client_a.get_state_snapshot() == before and before.schema_version == 12,"Purchased STR must converge with authoritative schema-12 state.")
	var poor := setup_actor(seed_value,9,2999)
	var poor_before: Dictionary = poor.sim.get_state_snapshot()
	check(poor.ledger.purchase_advancement(poor.sim,"poor",&"attribute",&"str").get("reason") == "insufficient_xp" and poor.sim.get_state_snapshot() == poor_before,"Unaffordable purchase must fail without mutations.")
	var higher := setup_actor(seed_value,11)
	check(higher.ledger.purchase_advancement(higher.sim,"higher",&"attribute",&"str").success and higher.actor.combat_stats.sb == 3,"STR 11 to 12 must use the actual chart SB increase, not a generic +1 damage grant.")
	var cap := setup_actor(seed_value,20,9000)
	check(not cap.ledger.purchase_advancement(cap.sim,"mortal_cap",&"attribute",&"str").success and cap.ledger.spent_xp == 0,"No unverified immortal/magic exception permits a mortal STR 20 to 21 purchase.")
	check(not f.actor.apply_verified_strength_advancement(10,12).success,"An arbitrary two-point increase must be rejected.")
	var busy_actor := setup_actor(seed_value)
	busy_actor.state.current_action_instance_id = "fixture_active_act"
	check(busy_actor.ledger.purchase_advancement(busy_actor.sim,"busy",&"attribute",&"str").get("reason") == "advancement_requires_idle_actor" and busy_actor.ledger.spent_xp == 0,"An in-progress Act must not be altered by STR advancement.")
	var bad := setup_actor(seed_value)
	bad.actor.base_combat_stats.sb = 99
	check(not bad.ledger.purchase_advancement(bad.sim,"bad_source",&"attribute",&"str").success and bad.ledger.spent_xp == 0,"Unverified derived source data must fail closed.")
	var illegal_gear := setup_actor(seed_value)
	illegal_gear.actor.equipment_refs = PackedStringArray(["prime_v3_battle_axe"])
	check(not illegal_gear.ledger.purchase_advancement(illegal_gear.sim,"invalid_gear",&"attribute",&"str").success and illegal_gear.actor.attributes.str == 9 and illegal_gear.ledger.spent_xp == 0,"An invalid STR-12 loadout must fail before any attribute or XP mutation.")
	check(not f.ledger.purchase_advancement(f.sim,"no_dex",&"attribute",&"dex").success,"DEX and unfinished primary-attribute purchases must remain unavailable.")
	var initial := setup_actor(seed_value,9,0,3000)
	check(initial.ledger.purchase_advancement(initial.sim,"initial_expc",&"attribute",&"str").success and initial.ledger.to_dictionary().unspent_xp == 0,"Authored initial EXPC is spendable once without inventing an earned award.")
	return {"snapshot":before,"purchases":f.ledger.purchase_records.duplicate(true),"draws":draws}

func source_history() -> void:
	var helper := ProjectionTests.new()
	var f := helper._fixture()
	var actor: CombatActorDefinition = f.sim.get_actor_definition(&"player")
	var state: CombatActorState = f.sim.get_actor_state(&"player")
	var original := CharacterProfileProjection.project(f.source,actor,state,f.ledger.to_dictionary(),f.defense,f.verifier)
	check(original.success,"Legacy SR-purchase source must project before STR advancement.")
	if not original.success: return
	check(CharacterProfileProjection.hydrate(original.payload,f.source,"profile_a","rules_test",f.verifier).success,"Legacy SR-only histories must hydrate unchanged.")
	f.ledger.initial_expc = 40
	var result: Dictionary = f.ledger.purchase_advancement(f.sim,"STR",&"attribute",&"str")
	check(result.success and state.progression.expc == 40,"Nonzero starting EXPM/EXPC must not be lost or double-counted.")
	var payload: Dictionary = original.payload.duplicate(true)
	var p: Dictionary = result.purchase
	var row := {"purchase_id":"profile_a/run_a/purchase_STR"}
	for key: String in CharacterProfileProjection.PURCHASE_FIELDS: row[key] = p[key]
	payload.purchases.append(row)
	payload.permanent.xp_baseline.spent += 3000
	payload.xp.spent += 3000
	payload.xp.unspent -= 3000
	var hydrated := CharacterProfileProjection.hydrate(payload,f.source,"profile_a","rules_test",f.verifier)
	check(hydrated.success and hydrated.actor_definition.attributes.str == 10 and hydrated.xp.unspent == 40,"V2 existing purchase records must replay STR exactly, retaining authored baselines.")
	var bad := payload.duplicate(true)
	bad.purchases.back().cost = 1
	check(not CharacterProfileProjection.hydrate(bad,f.source,"profile_a","rules_test",f.verifier).success,"Wrong-cost STR history must not hydrate.")
	bad = payload.duplicate(true)
	bad.purchases.append(row.duplicate(true))
	check(not CharacterProfileProjection.hydrate(bad,f.source,"profile_a","rules_test",f.verifier).success,"Duplicated STR receipts must not hydrate or charge twice.")
	check(helper._failures.is_empty(),"Existing source fixture must remain valid.")

func playable() -> void:
	var old_storage := PlayableCharacterPersistence.test_storage
	var old_mode := PlayableCharacterPersistence.test_nonpersistent
	var root := OS.get_cache_dir().path_join("itank-storage-tests/str37_%s_%s" % [OS.get_process_id(),Time.get_ticks_usec()])
	var storage := CharacterSaveStorage.new(root)
	PlayableCharacterPersistence.test_storage = storage
	PlayableCharacterPersistence.test_nonpersistent = false
	var helper := Playable.new()
	var scene := helper._scene()
	var c: ArenaCombatController = scene.get_node("CombatController")
	c.set_physics_process(false)
	c._encounter_selector_index = 8
	check(c.select_player_character_for_testing(Fixture.PLAYER_CHARACTER_VAELIS).success,"Disposable DEV profile must enter through actual character selection.")
	var session := c._session
	for wave in range(4):
		session.set_opponent_behavior_enabled(false)
		helper._defeat_wave(session)
		if session.get_reward_state().unspent_xp >= 3000: break
		check(session.request_next_wave().success,"Source-backed progression must continue toward sufficient earned EXPC.")
	check(helper._failures.is_empty() and session.get_reward_state().unspent_xp >= 3000,"Actual combat rewards must fund the purchase without injected XP.")
	c._update_rewards_panel(true)
	var selected := -1
	for index in range(c._advancement_options.size()):
		var option: Dictionary = c._advancement_options[index]
		if option.purchase_kind == "attribute" and option.target_id == "str": selected = index
	check(selected >= 0,"Legal downtime UI must expose only the newly supported STR attribute option.")
	if selected >= 0:
		c._advancement_option.select(selected)
		c._advancement_option.item_selected.emit(selected)
		check(c._advancement_option.get_item_text(selected).contains("9 -> 10 (3000 EXPC)"),"UI must show actual STR values and verified EXPC cost.")
		var resources := session.get_actor_state(&"player").resources.duplicate(true)
		var hpc: Variant = session.get_actor_state(&"player").current_hpc
		var earned: int = session.get_reward_state().earned_xp
		c._purchase_advancement_button.pressed.emit()
		var service := session._playable_persistence
		var original_request := String(session._reward_ledger.purchase_records.back().request_id)
		check(service._last_ack and session.simulation.get_actor_definition(&"player").attributes.str == 10 and session.get_reward_state().spent_xp == 3000,"Actual UI confirmation must publish a verified STR purchase checkpoint.")
		check(session.get_reward_state().earned_xp == earned and session.get_actor_state(&"player").resources == resources and session.get_actor_state(&"player").current_hpc == hpc,"UI purchase cannot reduce EXPM, heal or refill resources.")
		var exported := CharacterBackupReader.new().begin_export(service)
		check(exported.success and CharacterBackupContract.decode(exported.text,"dev_normal").success,"Full-history export/preview must retain STR purchases.")
		if exported.success:
			var destination := CharacterSaveStorage.new(root.path_join("restored"))
			var restorer := CharacterBackupRestoration.new()
			check(restorer.begin(exported.text,"dev_normal",null,destination).get("state") == "confirmation_required","STR-bearing files must retain explicit restore confirmation.")
			check(restorer.confirm().get("state") == "verified_committed","STR-bearing full history must restore transactionally to disposable storage.")
			restorer.dispose()
			PlayableCharacterPersistence.test_storage = destination
			var restored_service := PlayableCharacterPersistence.new()
			check(restored_service.open("dev_normal").success and restored_service.candidate.actor_definition.attributes.str == 10 and restored_service.candidate.permanent.xp_baseline.spent == 3000,"Restored profile must retain STR and exactly one paid receipt.")
			PlayableCharacterPersistence.test_storage = storage
		var reload_service := PlayableCharacterPersistence.new()
		check(reload_service.open("dev_normal").success and reload_service.candidate.actor_definition.attributes.str == 10,"Desktop reload must replay purchased STR without repeating cost or starter grants.")
		helper._free(scene)
		scene = helper._scene()
		c = scene.get_node("CombatController")
		c._encounter_selector_index = 8
		check(c.select_player_character_for_testing(Fixture.PLAYER_CHARACTER_VAELIS).success and c._session.simulation.get_actor_definition(&"player").attributes.str == 10,"Actual character selection must apply purchased STR from durable storage.")
		check(c._session.request_character_advancement(&"attribute",&"str",original_request).get("reason") == "duplicate_advancement_request" and c._session.simulation.get_actor_definition(&"player").attributes.str == 10,"Replaying the original STR request after reload must not become another purchase.")
		check(c._session.request_next_wave().success and c._session.simulation.get_actor_definition(&"player").attributes.str == 10,"NEXT WAVE must preserve purchased STR.")
	helper._free(scene)
	PlayableCharacterPersistence.test_storage = old_storage
	PlayableCharacterPersistence.test_nonpersistent = old_mode
