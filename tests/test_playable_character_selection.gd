extends RefCounted

const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
const Digest = preload("res://scripts/sync/sync_state_digest.gd")

var _failures: Array[String] = []


func run() -> Array[String]:
	_failures.clear()
	_test_catalog_and_physical_profile()
	_test_session_attack_reset_and_magic_boundary()
	_test_selector_and_seeded_wave_stability()
	_test_replay_digest()
	return _failures


func _test_catalog_and_physical_profile() -> void:
	var catalog := CombatDefinitionCatalog.load_default_fixture_catalog()
	var validation := catalog.validate_character_loadout(Fixture.VAELIS_CHARACTER_DEFINITION_ID, Fixture.VAELIS_LOADOUT_DEFINITION_ID)
	_expect_true(validation.get("success", false), "Vaelis's verified physical profile must pass catalog validation.")
	var actor := Fixture.make_player_actor(Fixture.PLAYER_CHARACTER_VAELIS)
	_expect_true(actor != null, "Vaelis must instantiate as an independent player actor.")
	if actor == null:
		return
	_expect_equal(actor.display_name, "Vaelis Thorn", "Vaelis identity must remain distinct from the Guard.")
	_expect_equal(actor.size_category, &"medium", "Vaelis's supplied 5 ft 7 in height must resolve to Medium.")
	_expect_equal(actor.attributes, {"str": 9, "end": 6, "spd": 11, "dex": 9, "wis": 10, "int": 5, "wit": 3, "man": 0, "luk": 0, "app": 14}, "Vaelis attributes must match the supplied record.")
	for expected: Array in [["hpm", 9], ["acc", 9], ["at", 1], ["init", 2], ["mr", 10], ["nal", 1], ["dt", 3], ["dp", 6], ["physical_soak", 3], ["sb", 2]]:
		_expect_equal(actor.get_combat_stat(expected[0]), expected[1], "Vaelis derived %s must match the verified Mana chart/supplied allocation." % expected[0])
	_expect_equal(actor.equipment_refs, PackedStringArray(["prime_v3_short_sword", "prime_v3_short_wand"]), "Vaelis must retain right-hand sword and left-hand wand as separate equipped definitions.")
	_expect_equal(actor.equipment_stat_modifiers, {"mr": 0, "dt": 0, "dp": 0}, "Vaelis's no-armor loadout must apply no armor penalties.")
	var attack := Fixture.make_player_attack_definition(Fixture.PLAYER_CHARACTER_VAELIS)
	_expect_true(attack != null and attack.weapon_ref == Fixture.VAELIS_WEAPON_REF and attack.maximum_range_microfeet == 2_000_000, "Vaelis's physical sequence must use the verified 2-foot Short Sword as its primary strike.")
	_expect_true(attack.physical_damage.dice_count == 1 and attack.physical_damage.die_sides == 6 and attack.physical_damage.flat_bonus == 1 and attack.physical_damage.strength_bonus_eligible, "Short Sword must resolve 1d6+1 plus eligible SB.")
	_expect_equal(attack.strikes_per_act, 2, "One Vaelis ATTACK request must attempt Sword and Wand strikes in the same Act.")
	_expect_equal(attack.strike_profiles[1].get("weapon_ref"), String(Fixture.VAELIS_WAND_REF), "The second physical strike must use the Short Wand definition.")
	var guard := Fixture.make_player_actor(Fixture.PLAYER_CHARACTER_GUARD)
	_expect_equal(guard.get_combat_stat("hpm"), 100, "Guard default statistics must remain unchanged.")
	_expect_equal(Fixture.make_player_attack_definition(Fixture.PLAYER_CHARACTER_GUARD).weapon_ref, Fixture.WEAPON_REF, "Guard must retain the Battle Axe.")


func _test_session_attack_reset_and_magic_boundary() -> void:
	var session := _make_vaelis_session(34_001)
	_expect_true(session != null, "Vaelis duel must initialize through the authoritative session.")
	if session == null:
		return
	var state := session.get_actor_state(Fixture.PLAYER_ID)
	_expect_equal(state.current_hpc, 9, "Vaelis must initialize at HPC 9.")
	_expect_equal(state.resources, {"blood": 10, "mana": 20}, "Supplied Blood and Mana maxima must initialize without fabricated uses.")
	_expect_equal(state.hand_occupancy, {"left": "prime_v3_short_wand", "right": "prime_v3_short_sword"}, "Vaelis hand occupancy must be authoritative.")
	_expect_equal(session.get_player_nac_automation().get("profile"), "Balanced", "Vaelis must initialize isolated, snapshot-visible NAC settings.")
	session.simulation.set_actor_defense_state(Fixture.OPPONENT_ID, &"unaware", PackedStringArray())
	var attack := session.request_player_attack("task34")
	_expect_true(attack.get("success", false), "Vaelis must be able to declare her legal two-strike physical action.")
	_expect_equal((attack.get("attack_instance_ids", []) as Array).size(), 2, "The physical action must create exactly two strike instances.")
	session.advance_by(5_000_000)
	_expect_equal(_event_count(session, &"physical_attack_accuracy_resolved", Fixture.PLAYER_ID), 2, "Both legal physical strikes must reach independent ACC resolution.")
	_expect_true(_has_declared_weapon(session, "prime_v3_short_sword"), "Authoritative attack history must identify Vaelis's declared Short Sword.")
	_expect_true(_has_declared_weapon(session, "prime_v3_short_wand"), "Authoritative attack history must identify Vaelis's declared Short Wand.")
	var reset := session.reset_encounter(false)
	_expect_true(reset.get("success", false), "RESET must reconstruct the selected Vaelis profile.")
	_expect_equal(session.get_player_character_id(), Fixture.PLAYER_CHARACTER_VAELIS, "RESET must preserve the selected character.")
	_expect_equal(session.get_actor_state(Fixture.PLAYER_ID).current_hpc, 9, "RESET must restore Vaelis's independent HPC.")


func _test_selector_and_seeded_wave_stability() -> void:
	var packed: PackedScene = load("res://scenes/test_arena.tscn")
	var scene := packed.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		_failures.append("SceneTree unavailable for Task 34 selector test.")
		scene.free()
		return
	tree.root.add_child(scene)
	var controller: ArenaCombatController = scene.get_node("CombatController")
	_expect_equal(controller.get_player_character_id_for_testing(), Fixture.PLAYER_CHARACTER_GUARD, "Guard must be the default UI selection.")
	_expect_true(controller.select_player_character_for_testing(Fixture.PLAYER_CHARACTER_VAELIS).get("success", false), "Vaelis must be selectable before START.")
	controller.press_encounter_control_for_testing()
	var transcript := controller.get_transcript_text_for_testing()
	_expect_true(transcript.contains("Fixture: wave_1_common_goblins"), "Transcript must report the Task 35I normal Wave 1 fixture rather than the historical Guard-duel default.")
	_expect_true(transcript.contains("Player: Vaelis Thorn (vaelis_thorn)"), "Transcript must identify the selected player character.")
	_expect_true(transcript.contains("Loadout: vaelis_thorn_short_sword_wand"), "Transcript must identify Vaelis's actual loadout.")
	_expect_true(transcript.contains("prime_v3_short_sword") and transcript.contains("prime_v3_short_wand"), "Transcript loadout evidence must list both equipped Vaelis weapons.")
	_expect_true(transcript.contains("Project version: 0.1.0-phase1-task20"), "The static project version must be labeled accurately rather than presented as a generated build identity.")
	controller.press_encounter_control_for_testing()
	_expect_equal(controller.get_combat_session_for_testing().get_player_character_id(), Fixture.PLAYER_CHARACTER_VAELIS, "Selection must apply to the actual encounter player actor.")
	_expect_true(controller.select_player_character_for_testing(Fixture.PLAYER_CHARACTER_GUARD).get("success", false), "Repeated pre-encounter switching must remain legal.")
	controller.press_encounter_control_for_testing()
	_expect_true(not controller.select_player_character_for_testing(Fixture.PLAYER_CHARACTER_VAELIS).get("success", true), "Character switching must be blocked during active combat.")
	scene.free()

	var guard_wave := ArenaCombatSession.new(34_002, null, Fixture.ENCOUNTER_WAVE_ONE_GOBLINS, Fixture.PLAYER_CHARACTER_GUARD)
	var vaelis_wave := ArenaCombatSession.new(34_002, null, Fixture.ENCOUNTER_WAVE_ONE_GOBLINS, Fixture.PLAYER_CHARACTER_VAELIS)
	guard_wave.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
	vaelis_wave.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
	var guard_setup := guard_wave.initialize_wave_one_goblins(Vector2i(20_000_000, 12_000_000), Vector2i(38_000_000, 12_000_000), false)
	var vaelis_setup := vaelis_wave.initialize_wave_one_goblins(Vector2i(20_000_000, 12_000_000), Vector2i(38_000_000, 12_000_000), false)
	_expect_true(guard_setup.get("success", false) and vaelis_setup.get("success", false), "Both player profiles must initialize the same seeded Wave 1.")
	_expect_equal(guard_setup.get("resolved_goblin_count"), vaelis_setup.get("resolved_goblin_count"), "Character selection must not perturb seeded enemy quantity RNG.")


func _test_replay_digest() -> void:
	var first := _make_vaelis_session(34_003)
	var second := _make_vaelis_session(34_003)
	if first == null or second == null:
		_failures.append("Vaelis replay sessions failed to initialize.")
		return
	for session: ArenaCombatSession in [first, second]:
		session.request_player_attack("task34_replay")
		session.advance_by(5_000_000)
	_expect_equal(_event_signature(first), _event_signature(second), "Same-seed Vaelis event history must replay identically.")
	_expect_equal(Digest.compute(first.get_state_snapshot()), Digest.compute(second.get_state_snapshot()), "Same-seed Vaelis authoritative snapshots must converge.")

	var harness := TwoClientSyncHarness.new(34_004)
	var authority := ArenaCombatSession.new(34_004, harness.authority.simulation, Fixture.ENCOUNTER_MEDIUM_GUARDS, Fixture.PLAYER_CHARACTER_VAELIS)
	authority.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
	_expect_true(authority.initialize(Vector2i(20_000_000, 12_000_000), Vector2i(22_000_000, 12_000_000), true).get("success", false), "Vaelis must initialize on the in-process authority.")
	authority.request_player_attack("task34_sync")
	authority.advance_by(5_000_000)
	var envelopes := harness.authority.publish_current_events()
	for envelope: CombatEventEnvelope in envelopes:
		harness.client_a.receive(envelope)
	for index in range(envelopes.size() - 1, -1, -1):
		harness.client_b.receive(envelopes[index])
	if not envelopes.is_empty():
		harness.client_b.receive(envelopes[0])
	_expect_true(harness.compare_clients().get("success", false), "Vaelis event delivery must converge after duplicate and out-of-order input.")
	_expect_equal(harness.client_a.get_state_digest(), harness.authority.get_state_digest(), "Vaelis clients must match the authority digest.")


func _make_vaelis_session(seed_value: int) -> ArenaCombatSession:
	var session := ArenaCombatSession.new(seed_value, null, Fixture.ENCOUNTER_MEDIUM_GUARDS, Fixture.PLAYER_CHARACTER_VAELIS)
	session.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
	var result := session.initialize(Vector2i(20_000_000, 12_000_000), Vector2i(21_000_000, 12_000_000), true)
	return session if result.get("success", false) else null


func _has_event(session: ArenaCombatSession, event_type: StringName, source_id: StringName) -> bool:
	for event: CombatEvent in session.get_resolved_events():
		if event.event_type == event_type and event.source_actor_id == source_id:
			return true
	return false


func _event_count(session: ArenaCombatSession, event_type: StringName, source_id: StringName) -> int:
	var count := 0
	for event: CombatEvent in session.get_resolved_events():
		if event.event_type == event_type and event.source_actor_id == source_id:
			count += 1
	return count


func _has_declared_weapon(session: ArenaCombatSession, weapon_ref: String) -> bool:
	for event: CombatEvent in session.get_resolved_events():
		if event.event_type == &"physical_attack_declared" and event.source_actor_id == Fixture.PLAYER_ID and event.payload.get("weapon_ref") == weapon_ref:
			return true
	return false


func _event_signature(session: ArenaCombatSession) -> Array[Dictionary]:
	var signature: Array[Dictionary] = []
	for event: CombatEvent in session.get_resolved_events():
		signature.append({"id": event.event_id, "timestamp": event.timestamp_us, "type": String(event.event_type), "source": String(event.source_actor_id), "target": String(event.target_actor_id), "payload": event.payload.duplicate(true)})
	return signature


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s Expected %s, got %s." % [message, str(expected), str(actual)])


func _expect_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)
