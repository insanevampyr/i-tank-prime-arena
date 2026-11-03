extends RefCounted

const Defenses = preload("res://tests/test_physical_defenses.gd")
const Playable = preload("res://tests/test_playable_vaelis_persistence.gd")
const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
var failures: Array[String] = []

func run() -> Array[String]:
	commands()
	var first_replay := replay_case()
	var second_replay := replay_case()
	check(first_replay == second_replay,"Same-seed development commands and temporary activation history must replay to identical snapshots/digests.")
	for first in [true,false]: defensive_case(first,false)
	defensive_case(false,true)
	defensive_case(true,true,&"thrown")
	defensive_case(true,true,&"hand_held",true)
	defensive_case(false,false,&"hand_held",false,2)
	persistence()
	return failures

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func replay_case() -> Dictionary:
	var sim := CombatSimulation.new(37)
	var helper := Defenses.new()
	var actor: CombatActorDefinition = helper._make_actor(&"generic",1,1,{"dt":6,"dp":3})
	actor.attributes.dex = 10
	sim.register_actor(actor)
	sim.begin_combat()
	sim.set_arena_wave_state_snapshot({"state":"between_wave_downtime"})
	check(sim.request_character_development(&"generic","replay/preferences","preferences",{"order":["block","nac","dodge","soak"]}).success,"Replay fixture preference must be authoritative.")
	check(sim.request_character_development(&"generic","replay/allocation","allocation",{"op":"allocate","id":"point/one","dt":1,"dp":0,"confirmed":true}).success,"Replay fixture allocation must be authoritative.")
	var state := sim.get_actor_state(&"generic")
	state.progression["development_run_id"] = "verified_run"
	state.timed_stat_effects["verified_source"] = {"source_action_instance_id":"activation","stat_modifiers":{"dex":1}}
	check(sim._sync_temporary_dex(&"generic").success,"Replay temporary source must validate.")
	var snapshot := sim.get_state_snapshot()
	verify_observers(sim)
	return {"snapshot":snapshot,"digest":SyncStateDigest.compute(snapshot),"draws":sim.random.get_draw_count()}

func commands() -> void:
	var helper := Defenses.new()
	var sim := CombatSimulation.new(1)
	var actor: CombatActorDefinition = helper._make_actor(&"actor",1,1,{"dt":6,"dp":3})
	actor.attributes.dex = 10 # Isolated source with one genuinely unassigned point.
	sim.register_actor(actor)
	var state := sim.get_actor_state(&"actor")
	var before := sim.get_state_snapshot()
	check(not sim.request_character_development(&"actor","one","preferences",{"order":["block","nac","dodge","soak"]}).success and sim.get_state_snapshot() == before,"Commands outside safe downtime must leave authoritative state unchanged.")
	sim.set_arena_wave_state_snapshot({"state":"between_wave_downtime"})
	var resources := state.resources.duplicate(true)
	var hpc: Variant = state.current_hpc
	var draws := sim.random.get_draw_count()
	check(sim.request_character_development(&"actor","one","preferences",{"order":["block","nac","dodge","soak"]}).success,"Authoritative preference command must succeed during safe downtime.")
	check(sim.request_character_development(&"actor","two","allocation",{"op":"allocate","id":"allocation/one","dt":1,"dp":0,"confirmed":true}).success,"Additional verified point must be allocatable without redistribution.")
	check(sim.get_effective_actor_combat_stat(&"actor","dt") == 7 and sim.get_effective_actor_combat_stat(&"actor","dp") == 3,"Confirmed allocation must affect actual combat stats.")
	before = sim.get_state_snapshot()
	check(not sim.request_character_development(&"actor","two","preferences",{"order":["nac","block","soak","dodge"]}).success and sim.get_state_snapshot() == before,"Duplicate request cannot change preferences or repeat allocation.")
	check(not sim.request_character_development(&"actor","three","allocation",{"op":"grant","id":"fabricated","dex":20}).success,"Caller cannot invent permanent DEX growth.")
	check(not sim.request_character_development(&"actor","four","preferences",{"order":["nac","nac","dodge","soak"]}).success,"Invalid preferences must fail closed.")
	var invalid_effect := CombatActionDefinition.new(&"unsupported_negative_dex",1,true,true,{"mana":2},{"verified_special":{"kind":"timed_stat_effect","target_mode":"self"},"timed_stat_effect":{"effect_id":"unsupported","duration_us":1000000,"stat_modifiers":{"dex":-1}}})
	var before_effect := sim.get_state_snapshot()
	check(sim.start_verified_special_action(&"actor",&"actor",invalid_effect,"negative_dex").get("reason") == "negative_or_unverified_dex_modifier" and sim.get_state_snapshot() == before_effect,"Unsupported negative DEX must fail before any action/resource/RNG mutation.")
	check(state.resources == resources and state.current_hpc == hpc and sim.random.get_draw_count() == draws,"Development must not refill resources or consume RNG.")
	check(CharacterDevelopment.starting(CharacterDevelopment.STANDARD_POLICY,9).state.baseline == {"dex":9,"dt":6,"dp":3} and not CharacterDevelopment.starting(CharacterDevelopment.STANDARD_POLICY,8).success,"Standard starting policy is explicit and only legal for pool 9.")
	temporary(sim,state)
	actor.attributes.dex = 11 # Represents an independently verified permanent grant.
	check(sim.request_character_development(&"actor","verified_growth","allocation",{"op":"grant","id":"growth/one","dex":11}).success,"An already-authorized positive DEX change must grant only its additional point.")
	var granted := CharacterDevelopment.inspect(state.progression.development)
	check(DexAllocation.contributions(granted.allocation).pending == 1,"Growth must not repeat earlier grants or redistribute assigned points.")

func temporary(sim: CombatSimulation, state: CombatActorState) -> void:
	state.timed_stat_effects["test_source"] = {"source_action_instance_id":"activation_one","stat_modifiers":{"dex":3}}
	check(sim._sync_temporary_dex(&"actor").success,"Verified positive source must receive automatic allocation.")
	check(sim.get_effective_actor_combat_stat(&"actor","dt") == 9 and sim.get_effective_actor_combat_stat(&"actor","dp") == 4 and sim.get_effective_actor_combat_stat(&"actor","acc") == 11,"Temporary DEX must affect live DT/DP/ACC from effective DEX 13.")
	check(sim.request_character_development(&"actor","customize","allocation",{"op":"customize","source":"test_source","activation":"activation_one","dt":0,"dp":3,"safe_downtime":true,"confirmed":true}).success,"Live customization must be source-bound and confirmed.")
	state.timed_stat_effects["explicit"] = {"source_action_instance_id":"explicit_one","stat_modifiers":{"dt":2}}
	check(sim.get_effective_actor_combat_stat(&"actor","dt") == 9 and sim.get_effective_actor_combat_stat(&"actor","dp") == 6,"Explicit DT modifier must remain independent of DEX allocation.")
	state.timed_stat_effects.erase("test_source")
	check(sim._sync_temporary_dex(&"actor").success and sim.get_effective_actor_combat_stat(&"actor","dt") == 9 and sim.get_effective_actor_combat_stat(&"actor","dp") == 3,"Source removal must remove only its temporary allocation.")
	state.timed_stat_effects["test_source"] = {"source_action_instance_id":"activation_one","stat_modifiers":{"dex":3}}
	check(sim._sync_temporary_dex(&"actor").success and sim.get_effective_actor_combat_stat(&"actor","dp") == 6,"Reapplying the same activation must retain its confirmed allocation.")
	state.progression["development_run_id"] = "new_authorized_run"
	check(sim._sync_temporary_dex(&"actor").success and sim.get_effective_actor_combat_stat(&"actor","dt") == 11 and sim.get_effective_actor_combat_stat(&"actor","dp") == 4,"New run activation identity must not inherit a previous run's customization lock; explicit DT remains additive.")
	state.timed_stat_effects.erase("test_source")
	check(sim._sync_temporary_dex(&"actor").success,"New activation must expire independently.")
	verify_observers(sim)

func verify_observers(sim: CombatSimulation) -> void:
	var harness := TwoClientSyncHarness.new(1)
	harness.authority.simulation = sim
	harness.deliver_in_order(harness.authority.publish_current_events())
	check(harness.compare_clients().success,"Development history must converge across two simulated clients.")
	check(harness.client_a.get_state_digest() == harness.authority.get_state_digest(),"Development-bearing authoritative state must match the observer digest.")

func seed_for_block(success: bool, strikes: int = 1) -> int:
	for seed_value in range(1,10000):
		var rng := DeterministicCombatRng.new(seed_value)
		rng.next_int(1,10); rng.next_int(1,10)
		var accuracy := rng.next_int(1,20)
		var extra_valid := true
		for strike in range(1,strikes):
			var extra := rng.next_int(1,20)
			if extra <= 1 or extra >= 20: extra_valid = false
		var block := rng.next_int(1,20)
		rng.next_int(1,20) # SS target 20.
		var reaction_acc := rng.next_int(1,20)
		if extra_valid and accuracy > 1 and accuracy < 20 and block > 1 and block < 20 and (block <= 4) == success and reaction_acc > 1 and reaction_acc <= 8: return seed_value
	return -1

func defensive_case(block_success: bool, nac_first: bool, delivery: StringName = &"hand_held", miss: bool = false, strikes: int = 1) -> void:
	var helper := Defenses.new()
	var profile: CombatDefenseProfile = helper._make_profile(&"generic_defensive_source")
	profile.shield_block = null
	profile.defensive_nacs = [{"special_id":&"force_bolt","mana_cost":2,"definition":VaelisForceFixture.make_force_bolt_attack_definition(&"fixture_weapon")}]
	var sim := CombatSimulation.new(helper._find_seed_for_d20_sequence([20]) if miss else seed_for_block(block_success,strikes))
	var actor: CombatActorDefinition = helper._make_actor(&"target",5,0)
	actor.size_category = &"medium"
	var attacker: CombatActorDefinition = helper._make_actor(&"attacker",5,100)
	attacker.size_category = &"medium"
	actor.base_combat_stats.ss = 20
	actor.combat_stats.ss = 20
	actor.resource_maxima.mana = 20
	sim.register_actor(attacker)
	sim.register_actor(actor)
	sim.register_defense_profile(&"target",profile)
	check(sim.register_defense_profile(&"attacker",CombatDefenseProfile.new(&"attacker_defense")).success,"Reaction recipient must have a legally registered defense profile before combat.")
	sim.begin_combat()
	var definition: CombatAttackDefinition = helper._make_attack(&"incoming",delivery)
	definition.strikes_per_act = strikes
	var declared := sim.start_physical_attack(&"attacker",&"target",definition,"incoming",&"torso",true)
	sim.advance_to(1_000_000)
	var incoming := sim.get_attack(declared.attack_instance_id)
	var state := sim.get_actor_state(&"target")
	state.resources.mana = 20
	var created := CharacterDevelopment.create(8,4,4)
	var order := ["nac","block","dodge","soak"] if nac_first else ["block","nac","dodge","soak"]
	state.progression.development = CharacterDevelopment.append(created.record,"fixture/preference","preferences",{"order":order}).record
	sim.configure_nac_automation(&"target",{"automatic_enabled":true,"automatic_nac_budget":1,"minimum_mana_reserve":0,"priority":["force_bolt"]})
	sim.set_actor_defense_state(&"attacker",&"unaware",PackedStringArray())
	sim.set_attack_final_line_of_sight_resolver(func(_a: StringName,_b: StringName) -> bool: return true)
	sim.defensive_dodge_environment_resolver = func(_attack: CombatAttackInstance) -> CombatDodgeEnvironment: return CombatDodgeEnvironment.new(&"complete_empty",true,[],"TEST: no legal destination")
	if miss:
		check(incoming.status == CombatAttackInstance.STATUS_MISSED,"Miss fixture must resolve incoming ACC as a miss.")
		var draw_count := sim.random.get_draw_count()
		check(not sim.resolve_pending_defense(incoming.attack_instance_id,"miss",helper._unavailable_dodge()).success and sim.random.get_draw_count() == draw_count and state.resources.mana == 20,"An incoming miss must not enter defenses or spend defensive Mana.")
		return
	var result := sim.resolve_pending_defense(incoming.attack_instance_id,"resolve_once",helper._unavailable_dodge())
	var diagnostics: Array = []
	for event: CombatEvent in sim.get_resolved_events():
		if event.event_type in [&"defensive_nac_evaluated",&"physical_defense_started",&"special_attack_accuracy_resolved",&"force_bolt_damage_resolved",&"defensive_nac_strike_interrupted"]: diagnostics.append(event.payload)
	check(result.success,"Generic actor defensive sequence must resolve.")
	if delivery == &"thrown":
		check(state.resources.mana == 20 and sim.get_actor_state(&"attacker").current_hpc == 20,"Released physical projectiles must not be canceled by automatically attacking the thrower.")
	elif block_success and not nac_first:
		check(state.resources.mana == 20 and incoming.status == CombatAttackInstance.STATUS_DEFENDED,"Block-first success must suppress NAC and all Mana expenditure.")
	else:
		# NAC-first uses the first post-ACC die as SS; avoid assuming a fixed die
		# assignment when the preference order intentionally changes RNG order.
		if nac_first:
			check(state.resources.mana == 18,"NAC-first must commit exactly one legal cost before Block: %s" % [diagnostics])
		else:
			check(state.resources.mana == 18 and incoming.status == CombatAttackInstance.STATUS_INTERRUPTED,"Failed Block must permit post-ACC Force Bolt to interrupt this unresolved strike: %s" % [diagnostics])
		check(sim.get_action(incoming.action_instance_id).status == CombatActionInstance.STATUS_COMPLETED,"Defensive interruption must preserve completed Act and spent time.")
	if strikes > 1:
		var sibling := sim.get_attack(declared.attack_instance_ids[1])
		check(incoming.status == CombatAttackInstance.STATUS_INTERRUPTED and sibling.status == CombatAttackInstance.STATUS_PENDING_DEFENSE,"Only the incoming unresolved strike is canceled; its committed sibling remains eligible.")
	var after := sim.get_state_snapshot()
	check(not sim.resolve_pending_defense(incoming.attack_instance_id,"resolve_once",helper._unavailable_dodge()).success and sim.get_state_snapshot() == after,"Repeated defense request must not spend Mana or activate twice.")
	check(helper._failures.is_empty(),"Source defense fixture must be legal.")
	check(sim.get_state_snapshot().schema_version == 12,"Live defense integration must retain simulation schema 12.")
	state.current_hpc = 0
	for defense_type: StringName in [CombatDefenseProfile.DODGE,CombatDefenseProfile.WEAPON_BLOCK,CombatDefenseProfile.SHIELD_BLOCK,CombatDefenseProfile.PHYSICAL_SOAK]:
		check(not sim._evaluate_defense_eligibility(incoming,state,actor,profile,defense_type,helper._unavailable_dodge(),false).eligible,"Execution-time eligibility must forbid new defenses after incapacitation.")
	verify_observers(sim)

func persistence() -> void:
	var previous := PlayableCharacterPersistence.test_storage
	var previous_mode := PlayableCharacterPersistence.test_nonpersistent
	var root := OS.get_cache_dir().path_join("itank-storage-tests/live37_%s_%s" % [OS.get_process_id(),Time.get_ticks_usec()])
	PlayableCharacterPersistence.test_storage = CharacterSaveStorage.new(root)
	PlayableCharacterPersistence.test_nonpersistent = false
	var helper := Playable.new()
	var scene := helper._scene()
	var c: ArenaCombatController = scene.get_node("CombatController")
	c.set_physics_process(false)
	check(c.select_player_character_for_testing(Fixture.PLAYER_CHARACTER_VAELIS).success,"Actual playable admission must succeed against isolated storage.")
	var session := c._session
	session.set_opponent_behavior_enabled(false)
	c._on_encounter_button_pressed()
	helper._defeat_wave(session)
	check(helper._failures.is_empty(),"Source-backed combat must reach safe downtime.")
	var hpc: Variant = session.get_actor_state(&"player").current_hpc
	var mana := session.get_actor_state(&"player").resources.duplicate(true)
	var result := session.request_character_development("preferences",{"order":["block","nac","dodge","soak"]},"set_order")
	check(result.success and result.get("persistence",{}).get("success",false),"Development must commit through real playable checkpoint publication: %s" % result)
	check(session.get_actor_state(&"player").current_hpc == hpc and session.get_actor_state(&"player").resources == mana,"Saved preference changes must not refill resources.")
	var service := session._playable_persistence
	var history := service.storage.inspect_profile(service.profile_id)
	var before := session.get_state_snapshot()
	var backup := CharacterBackupContract.create(history,"normal","2026-11-02T00:00:00Z")
	check(backup.success,"Full-history backup must validate optional development state: %s" % backup.get("reason",""))
	if backup.success: check(CharacterBackupContract.decode(backup.text,"normal").success,"Read-only preview must accept development state.")
	if backup.success:
		var destination := CharacterSaveStorage.new(root.path_join("restore"))
		var restoration := CharacterBackupRestoration.new()
		check(restoration.begin(backup.text,"normal",null,destination).get("state") == "confirmation_required","Development backup restoration still requires explicit confirmation.")
		var restored := restoration.confirm()
		check(restored.get("state") == "verified_committed","Transactional restore must acknowledge the development-bearing backup.")
		var restored_history := destination.inspect_profile(service.profile_id)
		check(restored_history.success and restored_history.generations.back().payload.permanent.development == service._prior.permanent.development,"Restored development identity/history must be lossless.")
		restoration.dispose()
	check(session.get_state_snapshot() == before,"Backup preparation/preview must not mutate simulation.")
	var reload_service := PlayableCharacterPersistence.new()
	var loaded := reload_service.open("normal")
	check(loaded.success and reload_service.candidate.permanent.get("development",{}) == service._prior.permanent.get("development",{}),"Native reload must retain exact authoritative development history.")
	check(not session.request_character_development("preferences",{"order":["nac","block","dodge","soak"]},"set_order").success,"Persisted command identity prevents repeated changes.")
	scene.free()
	PlayableCharacterPersistence.test_storage = previous
	PlayableCharacterPersistence.test_nonpersistent = previous_mode
