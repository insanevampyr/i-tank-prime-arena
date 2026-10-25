extends RefCounted

const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
const VaelisForce = preload("res://scripts/combat/vaelis_force_fixture.gd")
const Digest = preload("res://scripts/sync/sync_state_digest.gd")
const INCAPACITATION_SEED := 35_604

var _failures: Array[String] = []


func run() -> Array[String]:
	_failures.clear()
	_test_sword_and_wand_share_one_act()
	_test_weapon_specific_reach_resolves_independently()
	_test_committed_multistrike_incapacitation()
	_test_force_bolt_nac_accounting_and_cap()
	_test_force_shield_persistence_absorption_and_cancel()
	_test_automatic_danger_boundary_and_settings()
	_test_force_bolt_physical_action_interruption_size_gate()
	_test_player_special_controls()
	_test_resource_hud_and_force_shield_visibility()
	_test_force_replay_and_digest()
	return _failures


func _test_sword_and_wand_share_one_act() -> void:
	var session := _session(34_101, Vector2i(21_000_000, 12_000_000))
	if session == null:
		_failures.append("Vaelis multi-strike session failed to initialize.")
		return
	session.simulation.set_actor_defense_state(Fixture.OPPONENT_ID, &"unaware", PackedStringArray())
	var started := session.request_player_attack("task34b_multistrike")
	_expect_true(started.get("success", false), "Vaelis physical ATTACK must start.")
	_expect_equal((started.get("attack_instance_ids", []) as Array).size(), 2, "One ATTACK must create exactly two strikes.")
	var action := session.simulation.get_action(String(started.get("action_instance_id", "")))
	_expect_equal(action.final_effect_due_at_us - action.started_at_us, 5_000_000, "Two strikes must share Vaelis's single AT-1 Act interval.")
	session.advance_by(5_000_000)
	var declared_weapons: Array[String] = []
	var accuracy_ids: Dictionary = {}
	for event: CombatEvent in session.get_resolved_events():
		if event.event_type == &"physical_attack_declared" and event.source_actor_id == Fixture.PLAYER_ID:
			declared_weapons.append(String(event.payload.get("weapon_ref", "")))
		if event.event_type == &"physical_attack_accuracy_resolved" and event.source_actor_id == Fixture.PLAYER_ID:
			accuracy_ids[String(event.payload.get("attack_instance_id", ""))] = true
	_expect_equal(declared_weapons, [String(Fixture.VAELIS_WEAPON_REF), String(Fixture.VAELIS_WAND_REF)], "Sword then Wand must be declared as distinct weapon strikes.")
	_expect_equal(accuracy_ids.size(), 2, "Sword and Wand must receive independent ACC resolutions.")


func _test_weapon_specific_reach_resolves_independently() -> void:
	var session := _session(34_111, Vector2i(21_500_000, 12_000_000))
	if session == null:
		_failures.append("Vaelis weapon-range session failed to initialize.")
		return
	session.simulation.set_actor_defense_state(Fixture.OPPONENT_ID, &"unaware", PackedStringArray())
	var started := session.request_player_attack("task34b_weapon_ranges")
	_expect_true(started.get("success", false), "The two-strike action must be declarable at Short Sword reach.")
	session.advance_by(5_000_000)
	var sword_accuracy := 0
	var wand_final_failure := 0
	for event: CombatEvent in session.get_resolved_events():
		if event.source_actor_id != Fixture.PLAYER_ID:
			continue
		var attack := session.simulation.get_attack(String(event.payload.get("attack_instance_id", "")))
		if event.event_type == &"physical_attack_accuracy_resolved" and attack != null \
		and attack.weapon_ref == Fixture.VAELIS_WEAPON_REF:
			sword_accuracy += 1
		if event.event_type == &"physical_attack_final_legality_failed" and attack != null \
		and attack.weapon_ref == Fixture.VAELIS_WAND_REF:
			wand_final_failure += 1
	_expect_equal(sword_accuracy, 1, "The two-foot Short Sword must receive its own ACC resolution at 1.5 feet.")
	_expect_equal(wand_final_failure, 1, "The one-foot Short Wand must fail final reach independently without canceling the Sword.")


func _test_committed_multistrike_incapacitation() -> void:
	var session := _run_committed_multistrike_incapacitation(INCAPACITATION_SEED)
	_expect_true(session != null, "A deterministic Vaelis fixture must incapacitate on strike one while strike two remains committed.")
	if session == null:
		return
	var damage_events := _events_of_type(session, &"physical_damage_resolved")
	_expect_equal(damage_events.size(), 2, "Both legally committed strikes must finish damage resolution after strike one incapacitates.")
	if damage_events.size() != 2:
		return
	var first_attack := session.simulation.get_attack(String(damage_events[0].payload.get("attack_instance_id", "")))
	var second_attack := session.simulation.get_attack(String(damage_events[1].payload.get("attack_instance_id", "")))
	_expect_equal(first_attack.strike_index, 1, "The incapacitating damage must belong to the first committed strike.")
	_expect_equal(second_attack.strike_index, 2, "The post-incapacitation damage must belong to the second committed strike.")
	_expect_true(int(damage_events[0].payload.get("hpc_after", 1)) <= 0, "Incapacitation must take effect immediately after strike one damage.")
	_expect_equal(
		damage_events[1].payload.get("hpc_before"),
		damage_events[0].payload.get("hpc_after"),
		"Overkill accounting must continue from the authoritative HPC established by strike one."
	)
	_expect_equal(
		int(damage_events[1].payload.get("hpc_before", 0)) - int(damage_events[1].payload.get("final_damage", 0)),
		damage_events[1].payload.get("hpc_after"),
		"The remaining committed strike must record exact overkill damage and final HPC."
	)
	var first_defense := session.simulation.get_defense_resolution(first_attack.defense_resolution_id)
	var second_defense := session.simulation.get_defense_resolution(second_attack.defense_resolution_id)
	_expect_true(first_defense != null and not first_defense.attempts.is_empty(), "Strike one's already resolved defense history must remain intact.")
	_expect_true(second_defense != null and second_defense.attempts.is_empty(), "An incapacitated target must not initiate a fresh defense against strike two.")
	_expect_equal(_count_events(session, &"physical_defense_skipped_incapacitated"), 1, "Strike two must record exactly one authoritative no-new-defense transition.")
	var rejected := session._request_actor_attack(Fixture.OPPONENT_ID, Fixture.PLAYER_ID, "task34d_defeated_actor", &"torso")
	_expect_true(not rejected.get("success", false), "An incapacitated actor must not initiate a new ordinary action.")
	_expect_equal(rejected.get("reason"), "attacker_not_eligible", "The existing defeated-actor eligibility boundary must reject the new action.")

	var replay := _run_committed_multistrike_incapacitation(INCAPACITATION_SEED)
	_expect_true(replay != null, "The selected incapacitation seed must replay successfully.")
	if replay != null:
		_expect_equal(_event_signature(session), _event_signature(replay), "Committed-strike incapacitation event IDs, ordering, and payloads must replay identically.")
		_expect_equal(Digest.compute(session.get_state_snapshot()), Digest.compute(replay.get_state_snapshot()), "Committed-strike overkill and defense state must produce identical replay digests.")
	var harness := TwoClientSyncHarness.new(INCAPACITATION_SEED)
	var authority := ArenaCombatSession.new(INCAPACITATION_SEED, harness.authority.simulation, Fixture.ENCOUNTER_MEDIUM_GUARDS, Fixture.PLAYER_CHARACTER_VAELIS)
	authority.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
	var initialized := authority.initialize(Vector2i(20_000_000, 12_000_000), Vector2i(21_000_000, 12_000_000), true)
	_expect_true(initialized.get("success", false), "The incapacitation convergence authority must initialize.")
	if initialized.get("success", false):
		var authority_target := authority.get_actor_state(Fixture.OPPONENT_ID)
		authority_target.current_hpc = 1
		authority_target.revision += 1
		authority.request_player_attack("task34d_committed_multistrike")
		authority.advance_by(5_000_000)
		var envelopes := harness.authority.publish_current_events()
		for envelope: CombatEventEnvelope in envelopes:
			harness.client_a.receive(envelope)
		for envelope_index in range(envelopes.size() - 1, -1, -1):
			harness.client_b.receive(envelopes[envelope_index])
		if not envelopes.is_empty():
			harness.client_b.receive(envelopes[0])
		_expect_true(harness.compare_clients().get("success", false), "Committed-strike incapacitation envelopes must converge after duplicate and out-of-order delivery.")
		_expect_equal(harness.client_a.get_state_digest(), harness.authority.get_state_digest(), "Both simulated clients must match the incapacitation authority event digest.")


func _test_force_bolt_nac_accounting_and_cap() -> void:
	var session := _session(34_102, Vector2i(22_000_000, 12_000_000))
	if session == null:
		_failures.append("Vaelis Force Bolt session failed to initialize.")
		return
	session.simulation.set_actor_defense_state(Fixture.OPPONENT_ID, &"unaware", PackedStringArray())
	for use_index in range(5):
		var result := session.request_player_special(VaelisForce.FORCE_BOLT_ID)
		_expect_true(result.get("success", false), "Each of the first five Force Bolt NAC activations in one round must be accepted when Mana remains.")
	var state := session.get_actor_state(Fixture.PLAYER_ID)
	_expect_equal(state.nac_uses_this_round, 5, "Force Bolt must consume the shared five-NAC round budget.")
	_expect_equal(state.resources.get("mana"), 10, "Five Force Bolt attempts must commit their full two Mana each, including failed SS/ACC rolls.")
	var sixth := session.request_player_special(VaelisForce.FORCE_BOLT_ID)
	_expect_equal(sixth.get("reason"), "nac_round_cap_reached", "A sixth NAC in the same five-second round must fail closed.")
	_expect_equal(state.resources.get("mana"), 10, "A rejected sixth NAC must not spend Mana.")
	_expect_true(_count_events(session, &"nac_special_committed") == 5, "Every accepted Force Bolt must have one authoritative commitment event.")
	_expect_true(state.current_action_instance_id.is_empty(), "Manual zero-Act Force Bolt NACs must not create or occupy an ordinary action.")
	var damaging_session := _find_force_bolt_damage_session()
	_expect_true(damaging_session != null, "A deterministic Force Bolt fixture must include at least one damaging legal hit.")
	if damaging_session == null:
		return
	var damage_events := _events_of_type(damaging_session, &"force_bolt_damage_resolved")
	_expect_true(not damage_events.is_empty(), "The deterministic Force Bolt fixture must include at least one damaging legal hit.")
	for damage_event: CombatEvent in damage_events:
		var rolled := int(damage_event.payload.get("damage_roll", 0))
		_expect_true(rolled >= 1 and rolled <= 6, "Force Bolt damage must be an authoritative 1d6 roll.")
		_expect_equal(damage_event.payload.get("final_damage"), rolled, "Force Bolt must apply the source 1d6 result without fabricated bonus damage.")
	for knockback_event: CombatEvent in _events_of_type(damaging_session, &"force_bolt_knockback_resolved"):
		_expect_equal(knockback_event.payload.get("requested_distance_microfeet"), 2_000_000, "Force Bolt must request exactly two feet of knockback.")


func _test_force_shield_persistence_absorption_and_cancel() -> void:
	var shield_session: ArenaCombatSession = null
	for seed_value in range(34_200, 34_260):
		var candidate := _session(seed_value, Vector2i(21_000_000, 12_000_000))
		if candidate == null:
			continue
		var cast := candidate.request_player_special(VaelisForce.FORCE_SHIELD_ID)
		if not cast.get("success", false):
			continue
		candidate.advance_by(5_000_000)
		if candidate.get_actor_state(Fixture.PLAYER_ID).persistent_damage_shields.has(String(VaelisForce.FORCE_SHIELD_ID)):
			shield_session = candidate
			break
	_expect_true(shield_session != null, "At least one deterministic fixture seed must complete the SS-gated Force Shield cast.")
	if shield_session == null:
		return
	var shield_state := shield_session.get_actor_state(Fixture.PLAYER_ID)
	_expect_equal(shield_state.resources.get("mana"), 16, "Force Shield must commit four Mana at declaration.")
	_expect_equal((shield_state.persistent_damage_shields[String(VaelisForce.FORCE_SHIELD_ID)] as Dictionary).get("capacity"), 20, "Force Shield must begin with 20 separate protective points.")
	var nonstack := shield_session.request_player_special(VaelisForce.FORCE_SHIELD_ID)
	_expect_equal(nonstack.get("reason"), "persistent_damage_shield_already_active", "Force Shield must fail closed instead of stacking.")
	var illegal_enemy_touch := shield_session.request_player_special(VaelisForce.FORCE_SHIELD_ID, Fixture.OPPONENT_ID)
	_expect_equal(illegal_enemy_touch.get("reason"), "special_touch_unverified", "Touch targeting must reject the opposing duel actor rather than treating proximity as ally eligibility.")
	shield_session.advance_by(120_000_000)
	_expect_true(shield_state.persistent_damage_shields.has(String(VaelisForce.FORCE_SHIELD_ID)), "Force Shield must not expire on a timer.")
	var canceled := shield_session.cancel_player_force_shield()
	_expect_true(canceled.get("success", false), "Vaelis must be able to voluntarily cancel her persistent Force Shield.")
	_expect_true(not shield_state.persistent_damage_shields.has(String(VaelisForce.FORCE_SHIELD_ID)), "Cancel must remove the shield without changing ordinary action timing.")

	var absorbed := _find_shield_absorption_session()
	_expect_true(absorbed != null, "A deterministic physical hit must exercise Force Shield absorption.")
	if absorbed != null:
		var damage_event := _shielded_player_damage_event(absorbed)
		_expect_true(damage_event != null, "Shield fixture must retain the player-targeted absorption event.")
		if damage_event == null:
			return
		_expect_true(int(damage_event.payload.get("protective_points_absorbed", 0)) > 0, "Force Shield must absorb post-NAL physical damage before HPC.")
		_expect_equal(
			int(damage_event.payload.get("protective_points_absorbed", 0)) + int(damage_event.payload.get("final_damage", 0)),
			int(damage_event.payload.get("multiplied_total", 0)) - int(damage_event.payload.get("armor_tal", 0)) - int(damage_event.payload.get("natural_armor_level", 0)),
			"TAL and NAL must be subtracted before Force Shield capacity and any overflow are applied."
		)
		_expect_equal(
			int(damage_event.payload.get("hpc_before", 0)) - int(damage_event.payload.get("hpc_after", 0)),
			int(damage_event.payload.get("final_damage", 0)),
			"Only damage left after the separate Force Shield capacity may reduce actual HPC."
		)
		_expect_true(_count_events(absorbed, &"force_shield_knockback_resolved") == 1, "A physical attacker contacting Force Shield must receive one source-defined knockback resolution.")
	var overflow := _find_shield_overflow_session()
	_expect_true(overflow != null, "A deterministic repeated-hit fixture must verify Force Shield overflow into HPC.")
	if overflow != null:
		var overflow_event := _shield_overflow_damage_event(overflow)
		_expect_true(overflow_event != null, "Overflow evidence must retain the authoritative damage event.")
		if overflow_event != null:
			_expect_true(int(overflow_event.payload.get("protective_points_absorbed", 0)) > 0 and int(overflow_event.payload.get("final_damage", 0)) > 0, "A depleted Shield must absorb its remainder and pass only the excess into HPC.")


func _test_automatic_danger_boundary_and_settings() -> void:
	var session := _session(34_301, Vector2i(21_000_000, 12_000_000))
	if session == null:
		_failures.append("Vaelis NAC automation session failed to initialize.")
		return
	var configured := session.configure_player_nac_automation({
		"profile": "Guardian", "automatic_enabled": true,
		"minimum_mana_reserve": 4, "automatic_nac_budget": 1,
		"emergency_defense_enabled": true, "offensive_triggers_enabled": true,
		"ally_protection_enabled": true, "priority": PackedStringArray(["force_bolt"]),
	})
	_expect_true(configured.get("success", false), "Editable Guardian NAC settings must validate.")
	var events_before := _count_events(session, &"nac_special_committed")
	session.advance_by(100_000)
	_expect_equal(_count_events(session, &"nac_special_committed"), events_before, "Proximity alone must not trigger automatic Force Bolt.")
	var attack := session._request_actor_attack(Fixture.OPPONENT_ID, Fixture.PLAYER_ID, "task34b_danger", &"torso")
	_expect_true(attack.get("success", false), "The opponent's physical declaration must be legal in the danger fixture.")
	_expect_equal(_count_events(session, &"nac_special_committed"), events_before + 1, "A perceived hostile physical declaration may trigger exactly one automatic Force Bolt.")
	_expect_equal(session.get_actor_state(Fixture.PLAYER_ID).automatic_nac_uses_this_round, 1, "Automatic use must remain separately budgeted while sharing the global NAC cap.")
	_expect_equal(session.get_actor_state(Fixture.PLAYER_ID).resources.get("mana"), 18, "Automatic Force Bolt must commit the same two Mana as manual activation.")
	_expect_true(session.get_actor_state(Fixture.PLAYER_ID).current_action_instance_id.is_empty(), "Automatic zero-Act Force Bolt must not occupy Vaelis's ordinary action slot.")
	_expect_equal(_count_events(session, &"special_skill_resolved"), 1, "Automatic Force Bolt must use the authoritative SS pathway.")
	_expect_equal(session.get_player_nac_automation().get("profile"), "Guardian", "Profile choice must be actor-local authoritative state.")


func _test_force_replay_and_digest() -> void:
	var first := _session(34_401, Vector2i(22_000_000, 12_000_000))
	var second := _session(34_401, Vector2i(22_000_000, 12_000_000))
	if first == null or second == null:
		_failures.append("Vaelis Force replay sessions failed to initialize.")
		return
	for session: ArenaCombatSession in [first, second]:
		session.simulation.set_actor_defense_state(Fixture.OPPONENT_ID, &"unaware", PackedStringArray())
		session.request_player_special(VaelisForce.FORCE_BOLT_ID)
		session.request_player_attack("task34b_replay")
		session.advance_by(5_000_000)
	_expect_equal(_event_signature(first), _event_signature(second), "Force and physical multi-strike event histories must replay identically.")
	_expect_equal(Digest.compute(first.get_state_snapshot()), Digest.compute(second.get_state_snapshot()), "Force resources, shields, NAC state, strikes, and positions must produce identical digests.")
	var harness := TwoClientSyncHarness.new(34_402)
	var authority := ArenaCombatSession.new(34_402, harness.authority.simulation, Fixture.ENCOUNTER_MEDIUM_GUARDS, Fixture.PLAYER_CHARACTER_VAELIS)
	authority.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
	_expect_true(authority.initialize(Vector2i(20_000_000, 12_000_000), Vector2i(22_000_000, 12_000_000), true).get("success", false), "Vaelis Force authority must initialize.")
	authority.simulation.set_actor_defense_state(Fixture.OPPONENT_ID, &"unaware", PackedStringArray())
	authority.request_player_special(VaelisForce.FORCE_BOLT_ID)
	var envelopes := harness.authority.publish_current_events()
	for envelope: CombatEventEnvelope in envelopes:
		harness.client_a.receive(envelope)
	for index in range(envelopes.size() - 1, -1, -1):
		harness.client_b.receive(envelopes[index])
	if not envelopes.is_empty():
		harness.client_b.receive(envelopes[0])
	_expect_true(harness.compare_clients().get("success", false), "Force event envelopes must converge after duplicate and out-of-order delivery.")
	_expect_equal(harness.client_a.get_state_digest(), harness.authority.get_state_digest(), "Both simulated clients must match the Force authority event digest.")

	var automatic_first := _session(34_403, Vector2i(21_000_000, 12_000_000))
	var automatic_second := _session(34_403, Vector2i(21_000_000, 12_000_000))
	for automatic_session: ArenaCombatSession in [automatic_first, automatic_second]:
		automatic_session.configure_player_nac_automation({
			"profile": "Aggressive", "automatic_enabled": true,
			"minimum_mana_reserve": 0, "automatic_nac_budget": 1,
			"emergency_defense_enabled": false, "offensive_triggers_enabled": true,
			"ally_protection_enabled": false, "priority": PackedStringArray(["force_bolt"]),
		})
		automatic_session._request_actor_attack(Fixture.OPPONENT_ID, Fixture.PLAYER_ID, "task34c_auto_replay", &"torso")
	_expect_equal(_event_signature(automatic_first), _event_signature(automatic_second), "Automatic danger-triggered Force Bolt must replay with identical authoritative logging.")
	_expect_equal(Digest.compute(automatic_first.get_state_snapshot()), Digest.compute(automatic_second.get_state_snapshot()), "Automatic NAC resources and combat state must produce identical digests.")


func _test_player_special_controls() -> void:
	var packed: PackedScene = load("res://scenes/test_arena.tscn")
	var scene := packed.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		_failures.append("SceneTree unavailable for Task 34B control test.")
		scene.free()
		return
	tree.root.add_child(scene)
	var controller: ArenaCombatController = scene.get_node("CombatController")
	_expect_true(controller.select_player_character_for_testing(Fixture.PLAYER_CHARACTER_VAELIS).get("success", false), "Vaelis must be selectable before testing Special controls.")
	controller.press_encounter_control_for_testing()
	controller.get_combat_session_for_testing().simulation.set_actor_defense_state(Fixture.OPPONENT_ID, &"unaware", PackedStringArray())
	var opponent: Node2D = scene.get_node("Opponent")
	var right_click := controller.set_mouse_special_for_testing(opponent.global_position, true)
	_expect_true(right_click.get("success", false), "Right-click on the selected enemy must request the assigned Force Bolt once.")
	_expect_equal(controller.get_special_control_state_for_testing().get("assigned_special_id"), String(VaelisForce.FORCE_BOLT_ID), "Force Bolt must be the default assigned right-click Special.")
	controller.set_mouse_special_for_testing(opponent.global_position, false)
	var n_key := InputEventKey.new()
	n_key.physical_keycode = KEY_N
	n_key.pressed = true
	controller._unhandled_input(n_key)
	_expect_true(controller.get_special_control_state_for_testing().get("settings_visible", false), "N must expose the compact editable NAC settings panel for Vaelis.")
	scene.free()


func _test_resource_hud_and_force_shield_visibility() -> void:
	var failed_cast_fixture := _controller_fixture(34_000)
	var failed_cast_scene: Node = failed_cast_fixture.get("scene")
	var failed_cast_controller: ArenaCombatController = failed_cast_fixture.get("controller")
	if failed_cast_scene == null or failed_cast_controller == null:
		_failures.append("Task 34E failed-cast HUD fixture did not initialize.")
		return
	var guard_hud := failed_cast_controller.get_player_resource_hud_state_for_testing()
	_expect_equal(guard_hud.get("text"), "HPC 100/100", "Guard HUD must show HPC without fabricated Mana, AP, or Shield resources.")
	_expect_equal((failed_cast_controller._player_hpc_label as Label).text, "HPC 100/100", "Guard overhead label must remain HPC-only.")
	_expect_true(not String(guard_hud.get("combat_status_text", "")).contains("MANA"), "Guard combat status must omit inapplicable Mana.")
	_expect_true(failed_cast_controller.select_player_character_for_testing(Fixture.PLAYER_CHARACTER_VAELIS).get("success", false), "Vaelis must be selectable for the resource HUD test.")
	var vaelis_hud := failed_cast_controller.get_player_resource_hud_state_for_testing()
	_expect_equal(vaelis_hud.get("text"), "HPC 9/9 | MANA 20/20", "Vaelis HUD must show authoritative initial HPC and Mana maxima.")
	_expect_equal((failed_cast_controller._player_hpc_label as Label).text, "HPC 9/9\nMANA 20/20", "Vaelis overhead label must show the same initial HPC and Mana values on separate compact lines.")
	_expect_true(not String(vaelis_hud.get("text", "")).contains("AP"), "Vaelis must not display an AP pool that her resource schema does not contain.")
	var failed_session := failed_cast_controller.get_combat_session_for_testing()
	var draw_count_before := failed_session.simulation.random.get_draw_count()
	var digest_before := Digest.compute(failed_session.get_state_snapshot())
	failed_cast_controller.update_presentation_for_testing()
	failed_cast_controller.update_presentation_for_testing()
	_expect_equal(failed_session.simulation.random.get_draw_count(), draw_count_before, "HUD refresh must not consume authoritative RNG.")
	_expect_equal(Digest.compute(failed_session.get_state_snapshot()), digest_before, "HUD refresh must not mutate authoritative state.")
	var player_definition := failed_session.simulation.get_actor_definition(Fixture.PLAYER_ID)
	var player_state := failed_session.get_actor_state(Fixture.PLAYER_ID)
	player_definition.resource_maxima["ap"] = 5
	player_state.resources["ap"] = 3
	failed_cast_controller.update_presentation_for_testing()
	_expect_true(String(failed_cast_controller.get_player_resource_hud_state_for_testing().get("text", "")).contains("AP 3/5"), "An actually tracked AP resource must display from its authoritative current and maximum values.")
	player_definition.resource_maxima.erase("ap")
	player_state.resources.erase("ap")
	failed_cast_controller.update_presentation_for_testing()
	failed_cast_controller.press_encounter_control_for_testing()
	var failed_bolt := failed_cast_controller.request_special_for_testing(VaelisForce.FORCE_BOLT_ID)
	_expect_true(failed_bolt.get("success", false), "The deterministic failed-SS Force Bolt must still be an accepted, resource-spending activation.")
	_expect_true(_has_failed_special_skill(failed_session, VaelisForce.FORCE_BOLT_ID), "Seed 34000 must retain a failed authoritative Force Bolt SS result.")
	_expect_equal(failed_cast_controller.get_player_resource_hud_state_for_testing().get("mana"), 18, "Failed Force Bolt must immediately display its committed two-Mana expenditure.")
	_expect_equal((failed_cast_controller._player_hpc_label as Label).text, "HPC 9/9\nMANA 18/20", "Failed Force Bolt must immediately update authoritative Mana in the overhead label.")
	failed_cast_scene.free()

	var shield_fixture := _controller_fixture(34_000, Fixture.PLAYER_CHARACTER_VAELIS)
	var shield_scene: Node = shield_fixture.get("scene")
	var shield_controller: ArenaCombatController = shield_fixture.get("controller")
	if shield_scene == null or shield_controller == null:
		_failures.append("Task 34E Shield HUD fixture did not initialize.")
		return
	shield_controller.press_encounter_control_for_testing()
	var shield_session := shield_controller.get_combat_session_for_testing()
	var shield_request := shield_controller.request_special_for_testing(VaelisForce.FORCE_SHIELD_ID)
	_expect_true(shield_request.get("success", false), "Force Shield cast must start in the deterministic HUD fixture.")
	var casting_hud := shield_controller.get_player_resource_hud_state_for_testing()
	_expect_equal(casting_hud.get("mana"), 16, "Force Shield declaration must immediately display its four-Mana commitment.")
	_expect_true(not casting_hud.get("shield_active", true) and not casting_hud.get("shield_visual_active", true), "Shield value and aura must remain off until the successful cast completes.")
	_expect_equal((shield_controller._player_hpc_label as Label).text, "HPC 9/9\nMANA 16/20", "Force Shield declaration must update overhead Mana immediately without showing protection before completion.")
	shield_controller.advance_combat_for_testing(5_000_000)
	var active_hud := shield_controller.get_player_resource_hud_state_for_testing()
	_expect_equal(active_hud.get("shield_capacity"), 20, "Successful Force Shield must display 20 current protection points.")
	_expect_equal(active_hud.get("shield_maximum"), 20, "Force Shield must display its separate 20-point maximum.")
	_expect_true(String(active_hud.get("text", "")).contains("SHIELD 20/20"), "Active Shield must have a distinct current/maximum HUD value.")
	var active_overhead := shield_controller._player_hpc_label as Label
	_expect_equal(active_overhead.text, "HPC 9/9\nMANA 16/20\nSHIELD 20/20", "Successful Force Shield must appear in the actual overhead label without combining it with HPC.")
	_expect_equal(active_overhead.text, String(active_hud.get("text", "")).replace(" | ", "\n"), "Overhead and upper-left resource values must agree exactly.")
	_expect_equal(active_overhead.size.y, ArenaCombatController.PLAYER_HPC_LABEL_SIZE.y * 3.0, "The overhead label must expand to three readable resource lines.")
	var active_overhead_rect := Rect2(active_overhead.global_position, active_overhead.size * active_overhead.get_global_transform().get_scale().abs())
	_expect_true(active_overhead_rect.end.y < shield_controller._player.global_position.y, "The expanded resource label must remain above Vaelis instead of obscuring her token.")
	_expect_true(active_hud.get("shield_visual_active", false), "Successful Shield completion must enable the cyan player-token aura.")
	var canceled: Dictionary = shield_controller.call("_cancel_force_shield")
	_expect_true(canceled.get("success", false), "The active Shield must remain cancellable.")
	var canceled_hud := shield_controller.get_player_resource_hud_state_for_testing()
	_expect_true(not canceled_hud.get("shield_active", true) and not canceled_hud.get("shield_visual_active", true), "Cancel must immediately remove both Shield value and aura.")
	_expect_equal((shield_controller._player_hpc_label as Label).text, "HPC 9/9\nMANA 16/20", "Cancel must immediately remove the overhead Shield line without restoring spent Mana.")
	var absorbed_session := _find_partial_shield_absorption_session()
	_expect_true(absorbed_session != null, "The Shield HUD test requires a verified authoritative absorption session.")
	if absorbed_session != null:
		shield_controller._session = absorbed_session
		shield_controller.update_presentation_for_testing()
	var absorbed_hud := shield_controller.get_player_resource_hud_state_for_testing()
	var absorbed_value: Variant = absorbed_hud.get("shield_capacity", 0)
	var absorbed_capacity := 0 if absorbed_value == null else int(absorbed_value)
	_expect_true(absorbed_capacity > 0 and absorbed_capacity < 20, "Authoritative Shield absorption must immediately display its deterministic remaining capacity.")
	_expect_true(String(absorbed_hud.get("text", "")).contains("SHIELD %d/20" % absorbed_capacity), "Partial Shield capacity must remain separate from HPC.")
	_expect_true((shield_controller._player_hpc_label as Label).text.contains("SHIELD %d/20" % absorbed_capacity), "Authoritative Shield absorption must immediately update the actual overhead value.")
	shield_controller._session = shield_session
	shield_controller.update_presentation_for_testing()
	shield_controller.press_encounter_control_for_testing()
	var reset_hud := shield_controller.get_player_resource_hud_state_for_testing()
	_expect_equal(reset_hud.get("text"), "HPC 9/9 | MANA 20/20", "RESET must restore Vaelis resources and clear Shield presentation.")
	_expect_equal((shield_controller._player_hpc_label as Label).text, "HPC 9/9\nMANA 20/20", "RESET must restore the Vaelis overhead resources and clear its Shield line.")
	_expect_true(shield_controller.select_player_character_for_testing(Fixture.PLAYER_CHARACTER_GUARD).get("success", false), "Guard switching must remain legal after RESET.")
	_expect_equal(shield_controller.get_player_resource_hud_state_for_testing().get("text"), "HPC 100/100", "Switching back to Guard must remove inapplicable Mana and Shield presentation.")
	_expect_equal((shield_controller._player_hpc_label as Label).text, "HPC 100/100", "Guard overhead presentation must remove Vaelis-specific resources.")
	shield_scene.free()

	var depletion_fixture := _controller_fixture(34_000, Fixture.PLAYER_CHARACTER_VAELIS)
	var depletion_scene: Node = depletion_fixture.get("scene")
	var depletion_controller: ArenaCombatController = depletion_fixture.get("controller")
	if depletion_scene == null or depletion_controller == null:
		_failures.append("Task 34E Shield depletion HUD fixture did not initialize.")
		return
	var depletion_session := _find_shield_overflow_session()
	_expect_true(depletion_session != null, "The Shield HUD test requires a verified authoritative depletion session.")
	if depletion_session != null:
		depletion_controller._session = depletion_session
		depletion_controller.update_presentation_for_testing()
	var depleted_hud := depletion_controller.get_player_resource_hud_state_for_testing()
	_expect_true(not depleted_hud.get("shield_active", true) and not depleted_hud.get("shield_visual_active", true), "Authoritative Shield depletion must remove both Shield value and aura.")
	_expect_true(not (depletion_controller._player_hpc_label as Label).text.contains("SHIELD"), "Authoritative Shield depletion must remove the overhead Shield line.")
	depletion_scene.free()


func _test_force_bolt_physical_action_interruption_size_gate() -> void:
	var interrupt_seed := -1
	for seed_value in range(34_900, 35_200):
		var candidate := _session(seed_value, Vector2i(21_000_000, 12_000_000))
		if candidate == null:
			continue
		candidate.simulation.set_actor_defense_state(Fixture.OPPONENT_ID, &"unaware", PackedStringArray())
		var ordinary := candidate._request_actor_attack(Fixture.OPPONENT_ID, Fixture.PLAYER_ID, "nac_interrupt", &"torso")
		if not ordinary.get("success", false):
			continue
		candidate.request_player_special(VaelisForce.FORCE_BOLT_ID, Fixture.OPPONENT_ID)
		var action := candidate.simulation.get_action(String(ordinary.get("action_instance_id", "")))
		if action != null and action.status == CombatActionInstance.STATUS_INTERRUPTED:
			interrupt_seed = seed_value
			break
	_expect_true(interrupt_seed >= 0, "A legal Force Bolt hit must be able to interrupt a same-size target's unfinished physical action.")
	if interrupt_seed < 0:
		return
	var larger := _session(interrupt_seed, Vector2i(21_000_000, 12_000_000))
	larger.simulation.get_actor_definition(Fixture.OPPONENT_ID).size_category = &"large"
	larger.simulation.set_actor_defense_state(Fixture.OPPONENT_ID, &"unaware", PackedStringArray())
	var larger_action_result := larger._request_actor_attack(Fixture.OPPONENT_ID, Fixture.PLAYER_ID, "nac_size_gate", &"torso")
	_expect_true(larger_action_result.get("success", false), "The larger-target size gate fixture must start a physical action.")
	larger.request_player_special(VaelisForce.FORCE_BOLT_ID, Fixture.OPPONENT_ID)
	var larger_action := larger.simulation.get_action(String(larger_action_result.get("action_instance_id", "")))
	_expect_true(larger_action != null and larger_action.status != CombatActionInstance.STATUS_INTERRUPTED, "Force Bolt must not interrupt a physical action by a larger target.")


func _find_shield_absorption_session() -> ArenaCombatSession:
	for seed_value in range(34_500, 34_800):
		var session := _session(seed_value, Vector2i(21_000_000, 12_000_000))
		if session == null:
			continue
		if not session.request_player_special(VaelisForce.FORCE_SHIELD_ID).get("success", false):
			continue
		session.advance_by(5_000_000)
		if not session.get_actor_state(Fixture.PLAYER_ID).persistent_damage_shields.has(String(VaelisForce.FORCE_SHIELD_ID)):
			continue
		session.simulation.set_actor_defense_state(Fixture.PLAYER_ID, &"unaware", PackedStringArray())
		if not session._request_actor_attack(Fixture.OPPONENT_ID, Fixture.PLAYER_ID, "shield_contact", &"torso").get("success", false):
			continue
		session.advance_by(5_000_000)
		if _count_events(session, &"persistent_damage_shield_absorbed") > 0:
			return session
	return null


func _find_partial_shield_absorption_session() -> ArenaCombatSession:
	for seed_value in range(34_500, 34_800):
		var session := _session(seed_value, Vector2i(21_000_000, 12_000_000))
		if session == null or not session.request_player_special(VaelisForce.FORCE_SHIELD_ID).get("success", false):
			continue
		session.advance_by(5_000_000)
		var player_state := session.get_actor_state(Fixture.PLAYER_ID)
		if not player_state.persistent_damage_shields.has(String(VaelisForce.FORCE_SHIELD_ID)):
			continue
		session.simulation.set_actor_defense_state(Fixture.PLAYER_ID, &"unaware", PackedStringArray())
		if not session._request_actor_attack(Fixture.OPPONENT_ID, Fixture.PLAYER_ID, "shield_hud_contact", &"torso").get("success", false):
			continue
		session.advance_by(5_000_000)
		if _count_events(session, &"persistent_damage_shield_absorbed") > 0 \
		and player_state.persistent_damage_shields.has(String(VaelisForce.FORCE_SHIELD_ID)):
			return session
	return null


func _controller_fixture(seed_value: int, player_character_id: StringName = Fixture.PLAYER_CHARACTER_GUARD) -> Dictionary:
	var packed: PackedScene = load("res://scenes/test_arena.tscn")
	var scene := packed.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		scene.free()
		return {}
	tree.root.add_child(scene)
	var controller: ArenaCombatController = scene.get_node("CombatController")
	if not controller.set_seed_text_for_testing(str(seed_value)).get("success", false):
		scene.free()
		return {}
	if not controller.select_encounter_fixture_for_testing(Fixture.ENCOUNTER_MEDIUM_GUARDS).get("success", false):
		scene.free()
		return {}
	if player_character_id != Fixture.PLAYER_CHARACTER_GUARD \
	and not controller.select_player_character_for_testing(player_character_id).get("success", false):
		scene.free()
		return {}
	return {"scene": scene, "controller": controller}


func _has_failed_special_skill(session: ArenaCombatSession, special_id: StringName) -> bool:
	for event: CombatEvent in session.get_resolved_events():
		if event.event_type == &"special_skill_resolved" \
		and event.payload.get("special_id") == String(special_id) \
		and not event.payload.get("success", true):
			return true
	return false


func _run_committed_multistrike_incapacitation(seed_value: int) -> ArenaCombatSession:
	var session := _session(seed_value, Vector2i(21_000_000, 12_000_000))
	if session == null:
		return null
	var target_state := session.get_actor_state(Fixture.OPPONENT_ID)
	target_state.current_hpc = 1
	target_state.revision += 1
	var started := session.request_player_attack("task34d_committed_multistrike")
	if not started.get("success", false):
		return null
	session.advance_by(5_000_000)
	return session


func _find_force_bolt_damage_session() -> ArenaCombatSession:
	for seed_value in range(34_800, 35_100):
		var session := _session(seed_value, Vector2i(21_000_000, 12_000_000))
		if session == null:
			continue
		session.simulation.set_actor_defense_state(Fixture.OPPONENT_ID, &"unaware", PackedStringArray())
		if not session.request_player_special(VaelisForce.FORCE_BOLT_ID).get("success", false):
			continue
		if _count_events(session, &"force_bolt_damage_resolved") > 0:
			return session
	return null


func _find_shield_overflow_session() -> ArenaCombatSession:
	for seed_value in range(35_200, 35_500):
		var session := _session(seed_value, Vector2i(21_000_000, 12_000_000))
		if session == null or not session.request_player_special(VaelisForce.FORCE_SHIELD_ID).get("success", false):
			continue
		session.advance_by(5_000_000)
		if not session.get_actor_state(Fixture.PLAYER_ID).persistent_damage_shields.has(String(VaelisForce.FORCE_SHIELD_ID)):
			continue
		session.simulation.set_actor_defense_state(Fixture.PLAYER_ID, &"unaware", PackedStringArray())
		for attack_index in range(5):
			var attack := session._request_actor_attack(Fixture.OPPONENT_ID, Fixture.PLAYER_ID, "shield_overflow_%d" % attack_index, &"torso")
			if not attack.get("success", false):
				break
			session.advance_by(5_000_000)
			if _shield_overflow_damage_event(session) != null:
				return session
	return null


func _shield_overflow_damage_event(session: ArenaCombatSession) -> CombatEvent:
	for event: CombatEvent in session.get_resolved_events():
		if event.event_type == &"physical_damage_resolved" and event.target_actor_id == Fixture.PLAYER_ID \
		and int(event.payload.get("protective_points_absorbed", 0)) > 0 \
		and int(event.payload.get("final_damage", 0)) > 0:
			return event
	return null


func _session(seed_value: int, opponent_position: Vector2i) -> ArenaCombatSession:
	var session := ArenaCombatSession.new(seed_value, null, Fixture.ENCOUNTER_MEDIUM_GUARDS, Fixture.PLAYER_CHARACTER_VAELIS)
	session.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
	var result := session.initialize(Vector2i(20_000_000, 12_000_000), opponent_position, true)
	return session if result.get("success", false) else null


func _count_events(session: ArenaCombatSession, event_type: StringName) -> int:
	var count := 0
	for event: CombatEvent in session.get_resolved_events():
		if event.event_type == event_type:
			count += 1
	return count


func _events_of_type(session: ArenaCombatSession, event_type: StringName) -> Array[CombatEvent]:
	var events: Array[CombatEvent] = []
	for event: CombatEvent in session.get_resolved_events():
		if event.event_type == event_type:
			events.append(event)
	return events


func _last_event(session: ArenaCombatSession, event_type: StringName) -> CombatEvent:
	var result: CombatEvent = null
	for event: CombatEvent in session.get_resolved_events():
		if event.event_type == event_type:
			result = event
	return result


func _shielded_player_damage_event(session: ArenaCombatSession) -> CombatEvent:
	for event: CombatEvent in session.get_resolved_events():
		if event.event_type == &"physical_damage_resolved" and event.target_actor_id == Fixture.PLAYER_ID \
		and int(event.payload.get("protective_points_absorbed", 0)) > 0:
			return event
	return null


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
