extends RefCounted

const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
var _failures: Array[String] = []

func run() -> Array[String]:
	var values := PackedStringArray()
	for t in range(1,14):
		for level in range(2,21):
			values.append(str(PrimeV3LevelCatalog.threshold(t,level)))
			_expect(PrimeV3LevelCatalog.level_for(t,int(PrimeV3LevelCatalog.threshold(t,level))-1) == level-1,"Below each exact printed threshold must retain the preceding level.")
			_expect(PrimeV3LevelCatalog.level_for(t,int(PrimeV3LevelCatalog.threshold(t,level))) == level,"Each exact printed threshold must level immediately.")
	_expect(",".join(values).sha256_text() == "0ab384cdbd1c68f8e178b1d87133b2627f159762b0400e76598c90836fbdec52","All 247 cells must equal the independently PDF-extracted, visually verified printed tables.")
	_expect(PrimeV3LevelCatalog.threshold(8,21) == null,"Do not extrapolate LVL 21.")
	for name: String in PrimeV3LevelCatalog.BASE_TYPES:
		_expect(PrimeV3LevelCatalog.type_for_classes([name]) == PrimeV3LevelCatalog.BASE_TYPES[name],"Verify every base class mapping.")
	for a: String in PrimeV3LevelCatalog.BASE_TYPES:
		for b: String in PrimeV3LevelCatalog.BASE_TYPES:
			_expect(PrimeV3LevelCatalog.type_for_classes([a,b]) == PrimeV3LevelCatalog.type_for_classes([b,a]),"Dual class assignment is order-independent.")
	_expect(PrimeV3LevelCatalog.type_for_classes(["Fighter","Mage"]) == 8 and PrimeV3LevelCatalog.type_for_classes(["Force Mage"]) == 0,"Specialty names require explicitly verified class families, not guessed aliases.")
	_expect(PrimeV3LevelCatalog.HIT_DICE == [[8,0],[6,0],[4,0],[4,0],[8,0],[6,1],[6,0],[6,0],[4,1],[4,1],[4,0],[4,0],[4,0]],"Verify all thirteen printed Hit Dice.")
	for mode in ["mana","ability"]:
		for wisdom in [10,11]: _test_growth(mode,wisdom)
	_test_reward_integration()
	_test_spending_independence_and_waves()
	_expect(_replay() == _replay(),"Same-seed level RNG, snapshots and complete history must replay exactly.")
	return _failures

func _setup(mode: String = "mana", wisdom: int = 10, start_combat: bool = true) -> CombatSimulation:
	var sim := CombatSimulation.new(368)
	var actor := Fixture.make_player_actor(Fixture.PLAYER_CHARACTER_VAELIS)
	actor.attributes.wis = wisdom
	actor.resource_maxima.mana = wisdom+10
	actor.progression_policy.initial_wis = wisdom
	actor.progression_policy.resource_mode = mode
	if mode == "ability":
		actor.resource_maxima.erase("mana")
		actor.resource_maxima.ap = 0
	sim.register_actor(actor)
	if start_combat: sim.begin_combat()
	return sim

func _test_growth(mode: String, wisdom: int) -> void:
	var sim := _setup(mode,wisdom)
	var state := sim.get_actor_state(&"player")
	var actor := sim.get_actor_definition(&"player")
	state.current_hpc = 4
	if mode == "mana": state.resources.mana = 2
	var start := sim.start_action(&"player",CombatActionDefinition.new(&"ongoing",2),"ongoing")
	var action := sim.get_action(start.action_instance_id)
	var timing := action.to_dictionary()
	var draws := sim.random.get_draw_count()
	var result := sim.apply_character_experience_award(&"player","award:multi",469,469,0)
	_expect(result.get("success",false) and state.progression.level == 4,"One award processes LVL 2,3,4 immediately, before downtime.")
	_expect(sim.random.get_draw_count() == draws+3 and state.progression.history.size() == 3,"One HPM draw per earned level, exactly once.")
	var growth := 0
	for record: Dictionary in state.progression.history:
		_expect(record.hpb == 1 and record.hpm_increase == record.roll+1,"Use authoritative HPB on each gain.")
		growth += int(record.hpm_increase)
	_expect(actor.get_combat_stat("hpm") == 9+growth and state.current_hpc == 4,"Only HPM maximum increases, never HPC.")
	_expect(action.to_dictionary() == timing and sim.clock.get_elapsed_us() == 0,"Leveling cannot change actions, execution timing or combat time.")
	var snapshot := sim.get_state_snapshot()
	_expect(not sim.apply_character_experience_award(&"player","award:multi",469,469,0).get("success",false) and snapshot == sim.get_state_snapshot(),"Duplicate awards must be atomic no-ops.")
	if mode == "mana":
		_expect(actor.resource_maxima.mana == wisdom+10+3*(int(wisdom/2)+5) and state.resources.mana == 2 and not actor.resource_maxima.has("ap"),"Mana users gain exact maxima, never refill or receive AP.")
	else:
		_expect(actor.resource_maxima.ap == 3 and state.resources.ap == 0,"Ability User gains one AP maximum, no current AP and no second entitlement.")
		_expect(state.ability_daily_remaining.is_empty(),"Leveling must not create listed daily-use allowances.")
		sim.apply_authoritative_midnight_refresh("world:midnight")
		_expect(state.resources.ap == 3,"Only authoritative midnight replenishes the new AP maximum.")
	var history: Array = state.progression.history.duplicate(true)
	actor.attributes.wis = wisdom+2
	actor.combat_stats.hpb = 2
	actor.base_combat_stats.hpb = 2
	sim.apply_character_experience_award(&"player","award:next",563,1032,0)
	_expect(state.progression.level == 5 and (state.progression.history as Array).slice(0,3) == history,"Later Wisdom/HPB changes never reroll historical rewards.")
	_expect(state.progression.history.back().hpb == 2,"The next level uses the current HPB.")
	var harness := TwoClientSyncHarness.new(368)
	harness.authority.simulation = sim
	harness.deliver_in_order(harness.authority.publish_current_events())
	_expect(harness.compare_clients().get("success",false) and harness.client_a.get_state_snapshot() == sim.get_state_snapshot(),"Schema-12 progression events and snapshots converge on both clients.")
	_expect(sim.get_state_snapshot().schema_version == 12,"Preserve schema 12.")

func _test_reward_integration() -> void:
	for mode in [ArenaRewardLedger.MODE_NORMAL,ArenaRewardLedger.MODE_DEV_NORMAL,ArenaRewardLedger.MODE_TEST]:
		var sim := _setup("mana",10,false)
		var ledger := ArenaRewardLedger.new()
		ledger.configure(mode,&"player",1)
		var enemy := Fixture.make_guard_actor(&"wave_1_common_goblin_01","Isolated reward identity")
		_expect(sim.register_actor(enemy).get("success",false),"Reward integration fixture must register its enemy before combat.")
		sim.begin_combat()
		sim.get_actor_state(enemy.actor_id).current_hpc = 0
		ledger.process_defeat(sim,enemy.actor_id,"defeat")
		var state := sim.get_actor_state(&"player")
		_expect(ledger.earned_xp == (0 if mode == "test" else (100 if mode == "dev_normal" else 10)),"Preserve NORMAL, DEV 10x and TEST reward rules.")
		if mode == "dev_normal": _expect(state.progression.level == 2,"Developer NORMAL awards must level immediately.")
		if mode == "test": _expect(state.progression.is_empty(),"TEST MODE cannot create progression.")
		var unchanged := sim.get_state_snapshot()
		ledger.process_defeat(sim,enemy.actor_id,"defeat")
		_expect(unchanged == sim.get_state_snapshot(),"Duplicate defeat cannot duplicate XP or progression.")
	var fixed := CombatSimulation.new(368)
	fixed.register_actor(Fixture.make_guard_actor(&"fixed","Fixed source fixture"))
	var draws := fixed.random.get_draw_count()
	_expect(not fixed.apply_character_experience_award(&"fixed","award",100,100,0).get("success",false) and draws == fixed.random.get_draw_count(),"Unverified Guard starting progression must fail closed without rolls.")

func _replay() -> Dictionary:
	var sim := _setup()
	sim.apply_character_experience_award(&"player","replay",994,994,0)
	var events: Array = []
	for event: CombatEvent in sim.get_resolved_events(): events.append(event.to_dictionary())
	return {"events":events,"snapshot":sim.get_state_snapshot(),"rng":sim.random.to_dictionary()}

func _test_spending_independence_and_waves() -> void:
	var sim := _setup("mana",10,false)
	var second := Fixture.make_player_actor(Fixture.PLAYER_CHARACTER_VAELIS,&"second")
	sim.register_actor(second)
	var enemy := Fixture.make_guard_actor(&"wave_4_mini_gargoyle_swarmer_01","Isolated reward fixture")
	sim.register_actor(enemy)
	sim.begin_combat()
	sim.get_actor_state(enemy.actor_id).current_hpc = 0
	var ledger := ArenaRewardLedger.new()
	ledger.configure(ArenaRewardLedger.MODE_DEV_NORMAL,&"player",1)
	ledger.process_defeat(sim,enemy.actor_id,"defeat:purchase")
	var state := sim.get_actor_state(&"player")
	var level := int(state.progression.level)
	var history: Array = state.progression.history.duplicate(true)
	var draws := sim.random.get_draw_count()
	_expect(ledger.purchase_advancement(sim,"buy:sr",&"special_resistance",&"sr").get("success",false),"Existing verified SR purchases must remain functional after leveling.")
	_expect(state.progression.expm == 5000 and state.progression.expc == 3000 and state.progression.level == level and state.progression.history == history and sim.random.get_draw_count() == draws,"EXPC spending never lowers lifetime EXPM/level or rerolls benefits.")
	_expect(sim.get_actor_state(&"second").progression.is_empty() and sim.get_actor_definition(&"second").get_combat_stat("hpm") == 9,"Independent actors must not share mutable advancement state.")
	_expect(sim.apply_character_experience_award(&"second","second:award",97,97,0).get("success",false) and sim.get_actor_state(&"second").progression.level == 2,"Another actor can advance independently through the same core engine.")
	var session := ArenaCombatSession.new(3682,null,Fixture.ENCOUNTER_WAVE_ONE_GOBLINS,Fixture.PLAYER_CHARACTER_VAELIS)
	session.set_opponent_behavior_enabled(false)
	session.initialize_wave_one_goblins(Vector2i(20_000_000,12_000_000),Vector2i(24_000_000,12_000_000),false)
	session.configure_reward_mode(ArenaRewardLedger.MODE_DEV_NORMAL)
	session.start_encounter()
	var player := session.get_actor_state(&"player")
	player.current_hpc = 4
	player.resources.mana = 2
	for id: String in session.get_targetable_enemy_ids():
		session.get_actor_state(StringName(id)).current_hpc = 0
		session._reward_ledger.process_defeat(session.simulation,StringName(id),"fixture:defeat:%s" % id)
	session.advance_by(1)
	var progression := player.progression.duplicate(true)
	_expect(int(progression.get("level",1)) >= 2 and player.current_hpc == 4 and player.resources.mana == 2,"Actual accelerated wave XP must level without restoring resources: level=%s HPC=%s Mana=%s XP=%s mode=%s" % [progression.get("level",1),player.current_hpc,player.resources.mana,session.get_reward_state().earned_xp,session.get_reward_mode()])
	_expect(session.request_next_wave().get("success",false) and player.progression == progression and player.current_hpc == 4 and player.resources.mana == 2,"NEXT WAVE preserves all progression and spent resources.")
	session.reset_encounter(false)
	_expect(session.get_actor_state(&"player").progression.is_empty() and session.get_actor_max_hpm(&"player") == 9,"RESET reconstructs the original temporary fixture without cross-run progression.")

func _expect(value: bool, message: String) -> void:
	if not value: _failures.append(message)
