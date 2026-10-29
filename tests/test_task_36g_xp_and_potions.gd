extends RefCounted

const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
const Ledger = preload("res://scripts/rewards/arena_reward_ledger.gd")
const Catalog = preload("res://scripts/rewards/prime_v3_reward_catalog.gd")
const Boss = preload("res://scripts/creatures/rare_human_warrior_fixture.gd")
var _failures: Array[String] = []

func run() -> Array[String]:
	_failures.clear()
	var normal := _rewards(Ledger.MODE_NORMAL)
	var dev := _rewards(Ledger.MODE_DEV_NORMAL)
	_expect(normal.earned == 690 and dev.earned == 6900, "Arena rewards and developer multiplier must total 690/6900.")
	_expect(normal.drops == dev.drops and normal.items == dev.items and normal.rng == dev.rng, "XP multiplier must not change drops, item identity or RNG.")
	_expect(_rewards(Ledger.MODE_TEST).earned == 0, "TEST MODE must remain reward-free.")
	_expect(Catalog.get_reward("common_goblin").xp == 1 and Catalog.get_reward("common_spadoodle").xp == 3 and Catalog.get_reward("common_skelly").xp == 10, "Printed source EXP must remain unmodified.")
	_test_combat_potions()
	_test_player_npc_potion_parity()
	_test_developer_launcher()
	var replay_a := _potion_replay()
	var replay_b := _potion_replay()
	_expect(replay_a == replay_b, "Same-seed potion actions/events/RNG must replay identically.")
	return _failures


func _rewards(mode: String) -> Dictionary:
	var simulation := CombatSimulation.new(367)
	var actor_fixture := Fixture.make_player_actor(Fixture.PLAYER_CHARACTER_VAELIS)
	# Isolate the multiplier/drop contract: real level-up HD rolls are covered by 36H.
	actor_fixture.progression_policy.clear()
	simulation.register_actor(actor_fixture)
	simulation.set_world_item_landing_resolver(func(_item: Dictionary, _position: Vector2i) -> bool: return true)
	var ledger := Ledger.new()
	ledger.configure(mode, &"player", 11)
	var ids := ["wave_1_common_goblin_01", "wave_2_common_spadoodle_01", "wave_3_common_skelly_01", "wave_3_hades_combat_follower_01", "wave_4_mini_gargoyle_swarmer_01"]
	var expected := [10, 30, 50, 100, 500]
	for index in range(ids.size()):
		var actor := Fixture.make_guard_actor(StringName(ids[index]), "isolated reward fixture")
		simulation.register_actor(actor)
		simulation.get_actor_state(actor.actor_id).current_hpc = 0
		var result := ledger.process_defeat(simulation, actor.actor_id, "defeat:%s" % ids[index])
		if mode != Ledger.MODE_TEST: _expect(result.get("xp") == expected[index] * (10 if mode == Ledger.MODE_DEV_NORMAL else 1), "Each individual creature award must use its Arena value.")
	var reward_snapshot := {"earned": ledger.earned_xp, "drops": ledger.drop_resolutions.duplicate(true), "items": simulation.get_world_items_snapshot(), "rng": simulation.random.to_dictionary()}
	if mode == Ledger.MODE_DEV_NORMAL:
		var state := simulation.get_actor_state(&"player")
		state.current_hpc = 3
		state.resources.mana = 2
		_expect(ledger.purchase_advancement(simulation, "dev:sr", &"special_resistance", &"sr").get("success", false), "Developer NORMAL must allow verified SR advancement.")
		_expect(ledger.spent_xp == 2000 and state.current_hpc == 3 and state.resources.mana == 2, "Advancement must spend exact XP without refills.")
	return reward_snapshot


func _session() -> ArenaCombatSession:
	var session := ArenaCombatSession.new(367, null, Fixture.ENCOUNTER_WAVE_ONE_GOBLINS, Fixture.PLAYER_CHARACTER_VAELIS)
	session.set_opponent_behavior_enabled(false)
	session.initialize_wave_one_goblins(Vector2i(20_000_000,12_000_000), Vector2i(24_000_000,12_000_000), false)
	var state := session.get_actor_state(&"player")
	state.hand_occupancy.left = ""
	# Isolated fixture supplies the legally free hand; runtime never stows for free.
	session.start_encounter()
	return session


func _test_combat_potions() -> void:
	for potion: StringName in [&"prime_v3_potion_06", &"prime_v3_potion_12"]:
		var session := _session()
		var state := session.get_actor_state(&"player")
		state.inventory_quantities[String(potion)] = 2
		state.current_hpc = 1
		state.resources.mana = 1
		var started := session.request_player_inventory_consumable_use(potion, "potion:one")
		_expect(started.get("success", false), "Free-hand combat potion must schedule.")
		if not started.get("success", false): continue
		var action := session.simulation.get_action(started.action_instance_id)
		_expect(action.final_effect_due_at_us-action.started_at_us == 10_000_000, "Retrieve plus drink must cost two Acts, ten seconds for Vaelis AT 1.")
		_expect(not session.request_player_inventory_consumable_use(potion, "potion:overlap").get("success", false), "Potion cannot overlap an ordinary action.")
		session.advance_by(9_999_999)
		_expect(state.inventory_quantities[String(potion)] == 2, "No consumption before completion.")
		session.advance_by(1)
		_expect(state.inventory_quantities[String(potion)] == 1, "Exactly one potion consumed at completion.")
		_expect(not session.request_player_inventory_consumable_use(potion, "potion:one").get("success", false), "Duplicate potion request must reject.")
		_expect(state.current_hpc <= 9 and state.resources.mana <= 20, "Potion resource maxima remain enforced.")
		if potion == &"prime_v3_potion_06":
			_expect(state.current_hpc > 1 and state.resources.mana == 1, "Health Potion must heal without restoring Mana.")
		else:
			_expect(state.resources.mana > 1 and state.current_hpc == 1, "Mana Potion must restore Mana without healing.")
		var second := session.request_player_inventory_consumable_use(potion, "potion:interrupt")
		if second.get("success", false):
			var action2 := session.simulation.get_action(second.action_instance_id)
			session.simulation.schedule_interruption(action2.action_instance_id, action2.started_at_us + 1, &"player", "test")
			session.advance_by(10_000_000)
			_expect(state.inventory_quantities[String(potion)] == 1, "Interrupted potion must not consume another item.")
		if potion == &"prime_v3_potion_06": state.current_hpc = 8
		else: state.resources.mana = 19
		var capped := session.request_player_inventory_consumable_use(potion, "potion:cap")
		_expect(capped.get("success", false), "Resource-cap test must schedule a legal use.")
		if capped.get("success", false):
			var cap_action := session.simulation.get_action(capped.action_instance_id)
			session.advance_by(cap_action.final_effect_due_at_us - session.simulation.clock.get_elapsed_us())
			_expect((state.current_hpc == 9 if potion == &"prime_v3_potion_06" else state.resources.mana == 20), "Potion healing/recovery must cap exactly at source maxima.")
	var occupied := _session()
	occupied.get_actor_state(&"player").hand_occupancy.left = String(Fixture.VAELIS_WAND_REF)
	occupied.get_actor_state(&"player").inventory_quantities["prime_v3_potion_06"] = 1
	_expect(occupied.request_player_inventory_consumable_use(&"prime_v3_potion_06", "occupied").get("reason") == "consumable_free_hand_required", "Occupied hands must block without free stowing.")
	var attacking := _session()
	attacking.get_actor_state(&"player").inventory_quantities["prime_v3_potion_06"] = 1
	attacking.get_actor_state(&"player").hand_occupancy.left = String(Fixture.VAELIS_WAND_REF)
	attacking.select_target(StringName(attacking.get_targetable_enemy_ids()[0]))
	attacking.get_actor_state(StringName(attacking.get_targetable_enemy_ids()[0])).position_microfeet = attacking.get_actor_state(&"player").position_microfeet + Vector2i(1_000_000, 0)
	var attack_result := attacking.request_player_attack("test")
	_expect(attack_result.get("success", false), "The active-attack potion test must actually declare an attack: %s" % attack_result)
	_expect(not attacking.request_player_inventory_consumable_use(&"prime_v3_potion_06", "attack:potion").get("success", false), "Potion action cannot overlap an existing physical attack.")
	_expect(attacking.get_actor_state(&"player").inventory_quantities["prime_v3_potion_06"] == 1, "Blocked overlap must preserve inventory.")


func _potion_replay() -> Dictionary:
	var session := _session()
	var state := session.get_actor_state(&"player")
	state.current_hpc = 2
	state.inventory_quantities["prime_v3_potion_06"] = 1
	var result := session.request_player_inventory_consumable_use(&"prime_v3_potion_06", "replay:potion")
	_expect(result.get("success", false), "Replay fixture potion must start.")
	session.advance_by(10_000_000)
	var snapshot := session.simulation.get_state_snapshot()
	_expect(snapshot.schema_version == 12, "Potion/mode changes must preserve schema 12.")
	var harness := TwoClientSyncHarness.new(367)
	harness.authority.simulation = session.simulation
	harness.deliver_in_order(harness.authority.publish_current_events())
	_expect(harness.compare_clients().get("success", false) and harness.client_a.get_state_snapshot() == snapshot, "Potion actions must preserve complete two-client snapshots.")
	return snapshot


func _test_developer_launcher() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var scene := (load("res://scenes/test_arena.tscn") as PackedScene).instantiate()
	tree.root.add_child(scene)
	var controller := scene.get_node("CombatController") as ArenaCombatController
	for index in range(8): controller._on_encounter_selector_pressed()
	_expect(controller.get_combat_session_for_testing().get_reward_mode() == Ledger.MODE_DEV_NORMAL, "Ninth selector entry must be distinct Developer NORMAL.")
	controller._reset_encounter()
	_expect(controller.get_combat_session_for_testing().get_reward_state().earned_xp == 0, "RESET clears accelerated temporary XP.")
	controller.select_player_character_for_testing(Fixture.PLAYER_CHARACTER_VAELIS)
	controller.press_encounter_control_for_testing()
	var session := controller.get_combat_session_for_testing()
	session.set_opponent_behavior_enabled(false)
	var state := session.get_actor_state(&"player")
	state.hand_occupancy.left = ""
	state.inventory_quantities["prime_v3_potion_06"] = 1
	state.current_hpc = 1
	scene.get_node("HUD/UI/CombatInventory").emit_signal("pressed")
	_expect(controller.is_rewards_panel_visible_for_testing(), "Combat INVENTORY button must expose the actual item controls.")
	_expect(controller._inventory_use_button.focus_mode == Control.FOCUS_NONE, "Space/Enter must not activate a focused potion USE button.")
	for index in range(controller._inventory_entries.size()):
		if controller._inventory_entries[index].get("definition_id") == "prime_v3_potion_06":
			controller._inventory_option.select(index)
			controller._on_inventory_use_pressed()
	_expect(not state.current_action_instance_id.is_empty() and state.inventory_quantities["prime_v3_potion_06"] == 1, "Actual UI USE must schedule potion timing without premature consumption.")
	tree.root.remove_child(scene)
	scene.free()


func _test_player_npc_potion_parity() -> void:
	for role: String in ["player", "npc"]:
		for hand_mode: String in ["occupied", "half_spear", "free", "interrupted", "hand_lost"]:
			var simulation := CombatSimulation.new(3671)
			var actor := Boss.instantiate_foundation_actor(StringName(role)).get("actor") as CombatActorDefinition
			_expect(actor != null, "Parity fixture must instantiate the verified warrior.")
			if actor == null: continue
			simulation.register_actor(actor)
			var state := simulation.get_actor_state(actor.actor_id)
			state.current_hpc = 150
			var hands := {"left": String(Boss.WEAPON_REF), "right": String(Boss.WEAPON_REF)}
			if hand_mode == "half_spear": hands.left = ""
			elif hand_mode != "occupied": hands = {"left": "", "right": ""}
			simulation.configure_actor_hand_occupancy(actor.actor_id, hands)
			simulation.begin_combat()
			var definition := Boss.make_health_potion_action_definition()
			if role == "player":
				definition = PrimeV3InventoryCatalog.make_carried_potion_action_definition("health_potion", &"player_parity_potion")
			var before_hands := state.hand_occupancy.duplicate(true)
			var before_equipment := state.equipment_refs.duplicate()
			var before_draws := simulation.random.get_draw_count()
			var result := simulation.start_verified_consumable_healing_action(actor.actor_id, definition, "parity:potion")
			if hand_mode in ["occupied", "half_spear"]:
				_expect(not result.get("success", false), "%s must reject %s potion use without free weapon transitions." % [role, hand_mode])
				_expect(state.inventory_quantities.health_potion == 2 and simulation.random.get_draw_count() == before_draws, "Rejected use must not consume items or RNG.")
				continue
			_expect(result.get("success", false), "%s free-hand potion must schedule." % role)
			if not result.get("success", false): continue
			var action := simulation.get_action(result.action_instance_id)
			_expect(action.final_effect_due_at_us - action.started_at_us == 5_000_000, "%s AT-2 carried potion must take two Acts, not one." % role)
			if hand_mode == "interrupted":
				simulation.schedule_interruption(action.action_instance_id, action.started_at_us + 3_000_000, actor.actor_id, "parity_interrupt")
			elif hand_mode == "hand_lost":
				state.hand_occupancy = {"left": String(Boss.WEAPON_REF), "right": String(Boss.WEAPON_REF)}
			simulation.advance_to(action.final_effect_due_at_us - 1)
			_expect(state.inventory_quantities.health_potion == 2 and state.current_hpc == 150, "No potion effect or consumption before final completion.")
			simulation.advance_to(action.final_effect_due_at_us)
			var completed := hand_mode == "free"
			_expect(state.inventory_quantities.health_potion == (1 if completed else 2), "Both roles must consume once only after an eligible completion.")
			_expect((state.current_hpc > 150) == completed, "Interrupted or occupied-hand completion must not heal either role.")
			_expect(simulation.random.get_draw_count() - before_draws == (1 if completed else 0), "Only completed healing consumes its one d10 RNG draw.")
			if hand_mode != "hand_lost": _expect(state.hand_occupancy == before_hands, "Drinking must not stow or re-equip a weapon.")
			_expect(state.equipment_refs == before_equipment, "Drinking cannot mutate equipment possession.")
			_expect(not simulation.start_verified_consumable_healing_action(actor.actor_id, definition, "parity:potion").get("success", false), "Replayed potion request cannot consume twice.")
			var harness := TwoClientSyncHarness.new(3671)
			harness.authority.simulation = simulation
			harness.deliver_in_order(harness.authority.publish_current_events())
			_expect(harness.compare_clients().get("success", false) and harness.client_a.get_state_snapshot() == simulation.get_state_snapshot(), "Both potion roles must converge through schema-12 publication.")
			var shortcut := Boss.make_health_potion_action_definition()
			shortcut.required_acts = 1
			state.hand_occupancy = {"left": "", "right": ""}
			_expect(not simulation.start_verified_consumable_healing_action(actor.actor_id, shortcut, "parity:shortcut").get("success", false), "Shared validation must reject a one-Act carried-potion shortcut for either role.")


func _expect(value: bool, message: String) -> void:
	if not value: _failures.append(message)
