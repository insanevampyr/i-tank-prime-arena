extends RefCounted

var _failures: Array[String] = []


func run() -> Array[String]:
	_test_all_thirty_approved_outcomes()
	_test_attack_multiplier_and_exact_damage_order()
	_test_critical_stagger_interruption_and_exact_gate()
	_test_prone_and_one_act_standing()
	_test_pending_perfect_evasion_waits_for_destination()
	_test_rare_shield_contact_and_reaction_boundary()
	_test_reaction_chain_and_two_client_sync()
	_test_reaction_current_line_of_sight()
	_test_reaction_unverified_line_of_sight()
	_test_reaction_current_effective_accuracy()
	_test_reaction_existing_legality_gates()
	_test_reaction_fresh_roll_defenses_and_replay()
	_test_backfire_and_weapon_specific_gates()
	return _failures


func _test_all_thirty_approved_outcomes() -> void:
	var expected := [
		"potent_strike", "relentless_follow_up", "perfect_sequence",
		"off_balance", "bad_opening", "disastrous_backfire",
		"perfect_evasion", "wrong_footed", "turnabout",
		"stumble", "hard_fall", "catastrophic_misstep",
		"jarring_parry", "riposte", "masterful_reversal",
		"shaken_guard", "knocked_down", "guard_shattered",
		"shield_bash", "shield_reversal", "devastating_reversal",
		"buckled_guard", "driven_down", "crushing_breakthrough",
		"unshakable", "immovable", "overpowering_resilience",
		"overwhelmed", "brought_down", "crushing_impact",
	]
	var outcomes := CombatCriticalConsequenceCatalog.get_all_outcomes()
	_expect_equal(outcomes.size(), 30, "The ten approved general tables must expose exactly thirty rarity rows.")
	var actual: Array[String] = []
	var supported_effect_types := [
		"damage_multiplier", "critical_reaction", "critical_stagger", "backfire_redirect",
		"perfect_evasion", "prone", "shield_contact_prone", "same_attack_protection",
	]
	for outcome: Dictionary in outcomes:
		actual.append(String(outcome["outcome_id"]))
		_expect_true(not (outcome["effects"] as Array).is_empty(), "Every approved outcome must have an explicit effect descriptor.")
		for effect: Dictionary in outcome["effects"]:
			_expect_true(supported_effect_types.has(String(effect["type"])), "Every approved effect must route to a supported or explicit gated processor.")
	actual.sort()
	expected.sort()
	_expect_equal(actual, expected, "The data catalog must preserve every designer-approved outcome identifier without reviving proposed-table rows.")


func _test_attack_multiplier_and_exact_damage_order() -> void:
	var simulation := _base_simulation(_seed_for_attack_critical(1, 1, 70))
	var damage := CombatPhysicalDamageDefinition.new(
		1, 1, 4, false, true,
		{"torso": {"numerator": 3, "denominator": 2, "source_ref": "PRIME-V3 p.98 fixture"}},
		null, true, CombatPhysicalDamageDefinition.ROUNDING_FLOOR,
		PackedStringArray(["TEST-FIXTURE"])
	)
	var attack_definition := _attack(&"potent_strike_attack", &"fixture_weapon", damage)
	_register_no_defense(simulation, &"target")
	simulation.register_damage_protection_profile(&"target", CombatDamageProtectionProfile.new(&"none"))
	simulation.begin_combat()
	var started := simulation.start_physical_attack(&"attacker", &"target", attack_definition, "potent_request", &"torso", true)
	simulation.advance_to(1_000_000)
	var attack: CombatAttackInstance = simulation.get_attack(started["attack_instance_id"])
	var record := simulation.get_critical_record(attack.critical_record_id)
	_expect_equal(record.outcome_id, &"potent_strike", "A Common physical-attack critical success must select Potent Strike.")
	simulation.resolve_pending_defense(attack.attack_instance_id, "potent_defense")
	var result := simulation.resolve_physical_damage(attack.attack_instance_id, "potent_damage")
	var resolution := simulation.get_damage_resolution(result.get("damage_resolution_id", ""))
	_expect_true(result["success"], "Potent Strike must remain damage-resolvable after legal defenses are exhausted.")
	_expect_equal(resolution.combined_multiplier_numerator, 3, "Potent Strike x2 and torso fixture x1.5 must reduce to exact x3.")
	_expect_equal(resolution.combined_multiplier_denominator, 1, "The exact product must not introduce sequential rounding.")
	_expect_equal(resolution.multiplied_total, 15, "(1 weapon + 4 flat) x2 x1.5 must resolve before TAL/NAL.")
	_expect_equal(resolution.final_damage, 14, "NAL must subtract after the single exact multiplier product.")


func _test_critical_stagger_interruption_and_exact_gate() -> void:
	var simulation := _base_simulation(_seed_for_defense_critical(5, 20, 1, 70), true)
	var block := CombatBlockDefinition.new(CombatBlockDefinition.TYPE_WEAPON, &"block_weapon", 0, 0, true)
	var profile := CombatDefenseProfile.new(&"weapon_failure", PackedStringArray(["weapon_block", "dodge", "shield_block", "physical_soak"]), {}, block)
	simulation.register_defense_profile(&"target", profile)
	simulation.begin_combat()
	var attack_started := simulation.start_physical_attack(&"attacker", &"target", _attack(&"stagger_parent"), "stagger_parent", &"torso", true)
	var committed_action := CombatActionDefinition.new(&"committed_special_fixture", 3, true, true, {"special_resource": 2}, {}, PackedStringArray(["TEST-FIXTURE committed before interruption"]))
	var target_action := simulation.start_action(&"target", committed_action, "committed_action")
	simulation.advance_to(1_000_000)
	simulation.resolve_pending_defense(attack_started["attack_instance_id"], "stagger_defense")
	var record: CombatCriticalRecord = simulation.get_critical_records()[0]
	_expect_equal(record.outcome_id, &"shaken_guard", "A Common weapon-Block critical failure must select Shaken Guard.")
	_expect_equal(simulation.get_action(target_action["action_instance_id"]).status, CombatActionInstance.STATUS_INTERRUPTED, "Critical Stagger must interrupt an unfinished multi-Act action immediately.")
	_expect_equal(simulation.get_action(target_action["action_instance_id"]).interruption_reason, "critical_stagger", "The interruption must retain its critical cause.")
	for pending_event: Dictionary in simulation.get_state_snapshot()["pending_events"]:
		_expect_true(String((pending_event["payload"] as Dictionary).get("action_instance_id", "")) != target_action["action_instance_id"], "Critical Stagger must remove queued progress/finalization events for the interrupted action.")
	_expect_equal(committed_action.resource_commitments, {"special_resource": 2}, "Critical Stagger must not erase an already committed Special resource declaration.")
	_expect_equal(simulation.start_action(&"target", CombatActionDefinition.new(&"blocked_action", 1), "blocked_action")["reason"], "actor_critically_staggered", "Critical Stagger must block ordinary action starts for its exact duration.")
	_expect_equal(simulation.apply_authoritative_position(&"target", Vector2i(1, 0), 0)["reason"], "movement_blocked_by_critical_stagger", "Critical Stagger must block voluntary movement.")
	simulation.advance_to(1_500_000)
	_expect_true(simulation.start_action(&"target", CombatActionDefinition.new(&"after_stagger", 1), "after_stagger")["success"], "The action gate must end exactly 0.5 simulation seconds after application.")


func _test_prone_and_one_act_standing() -> void:
	var simulation := _base_simulation(_seed_for_defense_critical(5, 20, 71, 95), true)
	var block := CombatBlockDefinition.new(CombatBlockDefinition.TYPE_WEAPON, &"block_weapon", 0, 0, true)
	simulation.register_defense_profile(&"target", CombatDefenseProfile.new(&"prone_failure", PackedStringArray(["weapon_block", "dodge", "shield_block", "physical_soak"]), {}, block))
	simulation.begin_combat()
	var attack_started := simulation.start_physical_attack(&"attacker", &"target", _attack(&"prone_parent"), "prone_parent", &"torso", true)
	var falling_action := simulation.start_action(&"target", CombatActionDefinition.new(&"cinematic_falling_attack_fixture", 3), "prone_target_action")
	simulation.advance_to(1_000_000)
	simulation.resolve_pending_defense(attack_started["attack_instance_id"], "prone_defense")
	var record: CombatCriticalRecord = simulation.get_critical_records()[0]
	_expect_equal(record.outcome_id, &"knocked_down", "An Uncommon weapon-Block critical failure must select Knocked Down.")
	_expect_true(simulation.get_actor_state(&"target").conditions.has("prone"), "Knocked Down must set prone without an invented Stagger.")
	_expect_true(not simulation.get_actor_state(&"target").conditions.has("critical_stagger"), "Prone alone must not add a phantom 0.5-second Stagger.")
	_expect_equal(simulation.get_action(falling_action["action_instance_id"]).status, CombatActionInstance.STATUS_IN_PROGRESS, "Hard Fall/prone alone must not cancel a legitimate unfinished cinematic attack.")
	simulation.advance_to(3_000_000)
	_expect_equal(simulation.get_action(falling_action["action_instance_id"]).status, CombatActionInstance.STATUS_COMPLETED, "An unfinished attack preserved through prone must complete at its authoritative effect time.")
	_expect_equal(simulation.start_action(&"target", CombatActionDefinition.new(&"illegal_while_prone", 1), "illegal_while_prone")["reason"], "actor_prone", "Prone must block ordinary actions other than standing.")
	var stand := simulation.start_stand_action(&"target", "stand_once")
	_expect_true(stand["success"], "A prone actor must be able to begin the approved one-Act stand action.")
	simulation.advance_to(4_000_000)
	_expect_true(not simulation.get_actor_state(&"target").conditions.has("prone"), "Completing one Act of standing must clear prone exactly once.")
	_expect_equal(simulation.start_stand_action(&"target", "phantom_stand")["reason"], "actor_not_prone", "An already-standing actor must not accumulate phantom stand costs.")


func _test_pending_perfect_evasion_waits_for_destination() -> void:
	var simulation := _base_simulation(_seed_for_defense_critical(5, 1, 1, 70), false, false, true)
	simulation.register_defense_profile(&"target", CombatDefenseProfile.new(&"dodge_pending"))
	simulation.begin_combat()
	var started := simulation.start_physical_attack(&"attacker", &"target", _attack(&"dodge_parent"), "dodge_parent", &"torso", true)
	simulation.advance_to(1_000_000)
	var incomplete_environment := CombatDodgeEnvironment.new(&"incomplete", false, [], "TEST-FIXTURE incomplete environment")
	var defense := simulation.resolve_pending_defense_automatically(started["attack_instance_id"], "pending_dodge", incomplete_environment)
	var record: CombatCriticalRecord = simulation.get_critical_records()[0]
	_expect_equal(defense["status"], CombatDefenseResolution.STATUS_PENDING_DODGE_DISPLACEMENT, "A critical Dodge with incomplete environment must retain the existing pending displacement boundary.")
	_expect_equal(record.outcome_id, &"perfect_evasion", "A Common Dodge critical success must select Perfect Evasion.")
	_expect_equal(record.consequence_status, CombatCriticalRecord.CONSEQUENCE_PENDING, "Perfect Evasion must remain pending until a legal destination is supplied.")
	_expect_equal(simulation.get_actor_state(&"target").position_microfeet, Vector2i.ZERO, "Pending Perfect Evasion must not teleport or spend movement.")
	var resolved_context := CombatDodgeContext.new(
		CombatDodgeContext.SELECTION_RESOLVED, Vector2i(1_000_000, 0), 1_000_000, false,
		true, true, "TEST-FIXTURE legal destination", &"resolved_step", &"complete_environment",
		true, true, true, 0, "designer-supplied legal destination"
	)
	var completed := simulation.complete_pending_dodge_displacement(started["attack_instance_id"], "complete_pending_dodge", resolved_context)
	_expect_true(completed["success"], "Supplying a verified legal destination must complete the pending Dodge.")
	_expect_equal(record.consequence_status, CombatCriticalRecord.CONSEQUENCE_APPLIED, "Perfect Evasion must apply only after the legal destination validates.")
	_expect_equal(simulation.get_actor_state(&"target").position_microfeet, Vector2i(1_000_000, 0), "Completed Perfect Evasion must use the supplied legal destination without extra movement.")


func _test_rare_shield_contact_and_reaction_boundary() -> void:
	for contact_value: Variant in [true, null]:
		var simulation := _base_simulation(_seed_for_defense_critical(5, 1, 96, 100), true, true)
		var shield := CombatBlockDefinition.new(CombatBlockDefinition.TYPE_SHIELD, &"shield", 20, 0, true, true, 2, PackedStringArray(["PRIME-V3 p.27"]), contact_value)
		var profile := CombatDefenseProfile.new(&"rare_shield", PackedStringArray(["shield_block", "dodge", "weapon_block", "physical_soak"]), {}, null, shield)
		simulation.register_defense_profile(&"target", profile)
		_register_no_defense(simulation, &"attacker")
		simulation.register_critical_reaction_attack(&"target", _attack(&"target_counter", &"counter_weapon"), true)
		simulation.begin_combat()
		var started := simulation.start_physical_attack(&"attacker", &"target", _attack(&"shield_parent"), "shield_parent_%s" % str(contact_value), &"torso", true)
		simulation.advance_to(1_000_000)
		simulation.resolve_pending_defense(started["attack_instance_id"], "shield_defense_%s" % str(contact_value))
		var record: CombatCriticalRecord = simulation.get_critical_records()[0]
		_expect_equal(record.outcome_id, &"devastating_reversal", "A Rare shield-Block success must select Devastating Reversal.")
		_expect_equal(shield.current_shp, 1, "A critical shield-Block success must still spend exactly one SHP.")
		_expect_equal(simulation.get_actor_state(&"attacker").conditions.has("prone"), contact_value == true, "The prone component must require the explicit verified shield-contact predicate.")
		_expect_true(_count_events(simulation, &"critical_reaction_attack_declared") == 1, "The independently legal counterattack must remain available even when shield contact is unverified.")
		if contact_value == null:
			_expect_true(record.consequence_status == CombatCriticalRecord.CONSEQUENCE_PARTIAL, "Unavailable shield-contact prone plus a legal counterattack must record partial application.")


func _test_backfire_and_weapon_specific_gates() -> void:
	var backfire := _base_simulation(_seed_for_attack_critical(20, 96, 100))
	backfire.begin_combat()
	backfire.start_physical_attack(&"attacker", &"target", _attack(&"backfire"), "backfire", &"torso", true)
	backfire.advance_to(1_000_000)
	var backfire_record: CombatCriticalRecord = backfire.get_critical_records()[0]
	_expect_equal(backfire_record.outcome_id, &"disastrous_backfire", "A Rare physical-attack critical failure must select Disastrous Backfire.")
	_expect_equal(backfire_record.consequence_status, CombatCriticalRecord.CONSEQUENCE_BLOCKED, "Backfire must fail closed while verified redirect geometry is unavailable.")
	_expect_equal(backfire.get_actor_state(&"attacker").current_hpc, 30, "Blocked Backfire must never become an automatic undefendable self-hit.")

	for table_id: StringName in [CombatCriticalConsequenceCatalog.DWARVESTEK_FIREARM_TABLE, CombatCriticalConsequenceCatalog.GRENTEK_EXPLOSIVE_TABLE]:
		var policy := CombatCriticalTriggerPolicy.new(&"source_weapon_fixture", 3, 0, 18, table_id, "PRIME-V3 p.138", "PRIME-V3 p.138")
		var simulation := _base_simulation(_seed_for_attack_critical(18, 1, 100))
		simulation.begin_combat()
		simulation.start_physical_attack(&"attacker", &"target", _attack(&"source_weapon", &"fixture_weapon", null, policy), "source_%s" % String(table_id), &"torso", true)
		simulation.advance_to(1_000_000)
		var record: CombatCriticalRecord = simulation.get_critical_records()[0]
		_expect_equal(record.consequence_table_id, table_id, "Dwarvestek/Grentek must retain separate typed consequence tables.")
		_expect_equal(record.consequence_status, CombatCriticalRecord.CONSEQUENCE_BLOCKED, "Source-specific severity themes must stay inert until exact mechanics are verified.")
		_expect_true(record.consequence_reason.contains("unresolved"), "The weapon-specific gate must explain why no jam, scatter, blast, timer or self-damage was invented.")


func _test_reaction_chain_and_two_client_sync() -> void:
	var seed_value := _seed_for_reaction_chain()
	var harness := TwoClientSyncHarness.new(seed_value)
	var simulation: CombatSimulation = harness.authority.simulation
	var damage := CombatPhysicalDamageDefinition.new(1, 1, 0, false, true)
	simulation.set_attack_final_line_of_sight_resolver(func(_source: StringName, _target: StringName) -> bool: return true) # Open fixture geometry.
	simulation.register_actor(_actor(&"attacker", 100, PackedStringArray(["fixture_weapon"])))
	simulation.register_actor(_actor(&"target", 0, PackedStringArray()))
	_register_no_defense(simulation, &"target")
	simulation.register_damage_protection_profile(&"target", CombatDamageProtectionProfile.new(&"chain_protection"))
	var definition := _attack(&"chain_attack", &"fixture_weapon", damage)
	simulation.register_critical_reaction_attack(&"attacker", definition, true)
	simulation.begin_combat()
	var started := simulation.start_physical_attack(&"attacker", &"target", definition, "chain_parent", &"torso", true)
	var initial_envelopes := harness.authority.publish_due_events(1_000_000)
	harness.deliver_in_order(initial_envelopes)
	var parent_record: CombatCriticalRecord = simulation.get_critical_records()[0]
	_expect_equal(parent_record.outcome_id, &"relentless_follow_up", "The chain fixture must select the approved follow-up reaction.")
	simulation.resolve_pending_defense(started["attack_instance_id"], "chain_parent_defense")
	simulation.resolve_physical_damage(started["attack_instance_id"], "chain_parent_damage")
	_expect_equal(simulation.get_critical_records().size(), 2, "A reaction ACC critical must create a fresh child critical record without suppressing the parent.")
	var records := simulation.get_critical_records()
	_expect_true((records[1] as CombatCriticalRecord).parent_event_id != parent_record.event_id, "The child critical must retain its reaction-ACC causal parent rather than overwrite the source record.")
	var final_envelopes := harness.authority.publish_current_events()
	for envelope: CombatEventEnvelope in final_envelopes:
		harness.client_a.receive(envelope)
	for index in range(final_envelopes.size() - 1, -1, -1):
		harness.client_b.receive(final_envelopes[index])
	_expect_true(harness.compare_clients()["success"], "Two simulated clients must converge after a deterministic critical-reaction chain delivered out of order.")
	_expect_equal(harness.client_a.get_state_digest(), harness.authority.get_state_digest(), "Client critical-chain state must match the authoritative digest.")


# Task 39A/39B: assert the approved legality contract without weakening it.
# The follow-up is earned by a real Uncommon parent critical and stays deferred
# until that parent's defenses/damage finish. No private reaction call or RNG stub.
func _test_reaction_current_line_of_sight() -> void:
	for change: String in ["wall_appears", "target_moves_behind_wall"]:
		var fixture := _reaction_legality_fixture()
		var simulation: CombatSimulation = fixture.simulation
		if change == "wall_appears":
			fixture.los_context.battlefield = ArenaBattlefield.new(
				Rect2i(-2_000_000, -2_000_000, 12_000_000, 12_000_000),
				[{"id": "new_wall", "rect_microfeet": Rect2i(2_000_000, -1_000_000, 500_000, 2_000_000)}]
			)
		else:
			_expect_true(simulation.apply_authoritative_position(&"target", Vector2i(4_000_000, 3_000_000), 0, 3_000_000).success, "39A: target movement before the deferred reaction must be legal.")
		var battlefield: ArenaBattlefield = fixture.los_context.battlefield
		_expect_true(not battlefield.has_line_of_sight(simulation.get_actor_state(&"attacker").position_microfeet, simulation.get_actor_state(&"target").position_microfeet), "39A: actual wall geometry must obstruct current LOS.")
		var draws_before := simulation.random.get_draw_count()
		_finish_reaction_parent(fixture)
		_expect_reaction_unavailable(fixture, draws_before + 1, "39A %s: current blocked LOS" % change)
		# The same current geometry already blocks an ordinary attack before ACC.
		var ordinary := simulation.start_physical_attack(&"attacker", &"target", fixture.definition, "39a_wall_control", &"torso", true)
		_expect_true(ordinary.success, "39A: the ordinary approach-attack declaration must remain legal.")
		if ordinary.success:
			var ordinary_draws := simulation.random.get_draw_count()
			simulation.advance_to(2_000_000)
			var resolved := simulation.get_attack(ordinary.attack_instance_id)
			_expect_equal(resolved.final_legality_reason, "line_of_sight_blocked_at_resolution", "39A: ordinary final legality must reject the same current wall.")
			_expect_equal(resolved.natural_roll, null, "39A: ordinary blocked LOS must prevent ACC.")
			_expect_equal(simulation.random.get_draw_count(), ordinary_draws, "39A: the ordinary blocked-LOS control must consume no RNG.")

	# Registration really occurs behind the wall; the target then moves clear
	# before the ordinary parent begins. A stale false must not veto fresh LOS.
	var cleared := _reaction_legality_fixture(20, false)
	_finish_reaction_parent(cleared)
	_expect_equal(_count_events(cleared.simulation, &"critical_reaction_attack_declared"), 1, "39A cleared wall: current clear LOS must supersede stale blocked registration.")


func _test_reaction_current_effective_accuracy() -> void:
	for values: Array in [[4, 6, 10, true], [12, -6, 6, false]]:
		var fixture := _reaction_legality_fixture(int(values[0]))
		var simulation: CombatSimulation = fixture.simulation
		# Source-qualified, isolated direct-ACC effect fixture, not a new ability.
		simulation.get_actor_state(&"attacker").timed_stat_effects["39a_temporary_acc"] = {
			"source_action_instance_id": "39a_effect_activation",
			"source_ref": "TEST-FIXTURE temporary ACC modifier",
			"stat_modifiers": {"acc": int(values[1])},
			"expires_at_us": 10_000_000,
		}
		_expect_equal(simulation.get_effective_actor_combat_stat(&"attacker", "acc"), values[2], "39A: effective ACC must include the active signed modifier.")
		_finish_reaction_parent(fixture)
		var reaction := _reaction_attack(simulation)
		_expect_true(reaction != null, "39A: a valid ACC modifier must not suppress a legal reaction.")
		if reaction == null:
			continue
		_expect_equal(reaction.natural_roll, 8, "39A: the reaction must use its own seeded noncritical ACC roll.")
		_expect_equal(reaction.base_acc, values[2], "39A: reaction ACC must use the current effective value, not stored ACC %d." % int(values[0]))
		_expect_equal(reaction.accuracy_success, values[3], "39A: temporary ACC must affect the reaction's actual hit/miss result.")
		var ordinary := simulation.start_physical_attack(&"attacker", &"target", fixture.definition, "39a_effective_ordinary", &"torso", true)
		_expect_true(ordinary.success, "39A: an ordinary attack under the same effect must remain legal.")
		if ordinary.success:
			_expect_equal(simulation.get_attack(ordinary.attack_instance_id).base_acc, values[2], "39A: the ordinary attack is the effective-ACC control at the same time.")


func _test_reaction_unverified_line_of_sight() -> void:
	for geometry: String in ["missing", "unresolved", "not_required"]:
		var fixture := _reaction_legality_fixture()
		var simulation: CombatSimulation = fixture.simulation
		simulation.set_attack_final_line_of_sight_resolver(Callable())
		if geometry == "unresolved":
			simulation.set_attack_final_line_of_sight_resolver(func(_source: StringName, _target: StringName) -> Variant: return null)
		elif geometry == "not_required":
			fixture.definition.requires_line_of_sight = false
		var draws_before := simulation.random.get_draw_count()
		_finish_reaction_parent(fixture)
		if geometry == "not_required":
			_expect_equal(_count_events(simulation, &"critical_reaction_attack_declared"), 1, "39B: an attack that does not require LOS must not acquire a new LOS restriction.")
			_expect_equal(simulation.random.get_draw_count(), draws_before + 2, "39B: a legal no-LOS reaction must retain its fresh ACC roll.")
		else:
			_expect_reaction_unavailable(fixture, draws_before + 1, "39B %s geometry" % geometry)
			_expect_equal(simulation.get_critical_records()[0].consequence_reason, "critical_reaction_line_of_sight_unverified", "39B: missing or unresolved current geometry must fail closed with an explicit reason.")


func _test_reaction_existing_legality_gates() -> void:
	for gate: String in ["range", "equipment", "awareness", "defeated_reactor"]:
		var fixture := _reaction_legality_fixture()
		var simulation: CombatSimulation = fixture.simulation
		match gate:
			"range":
				_expect_true(simulation.apply_authoritative_position(&"target", Vector2i(6_000_000, 0), 0, 2_000_000).success, "39A: out-of-reach fixture movement must succeed.")
			"equipment":
				# Isolated post-parent-ACC equipment-loss fixture; no new equipment rule.
				simulation.get_actor_state(&"attacker").equipment_refs.remove_at(0)
			"awareness":
				simulation.set_actor_defense_state(&"attacker", &"unaware", PackedStringArray())
			"defeated_reactor":
				simulation.get_actor_state(&"attacker").current_hpc = 0
		var draws_before := simulation.random.get_draw_count()
		_finish_reaction_parent(fixture)
		_expect_reaction_unavailable(fixture, draws_before + 1, "39A %s gate" % gate)
		var reasons := {
			"range": "critical_reaction_target_out_of_range", "equipment": "critical_reaction_weapon_not_equipped",
			"awareness": "critical_reaction_awareness_restricted", "defeated_reactor": "critical_reaction_actor_not_eligible",
		}
		_expect_equal(simulation.get_critical_records()[0].consequence_reason, reasons[gate], "39A: unavailable reaction must retain the actual legality reason.")


func _test_reaction_fresh_roll_defenses_and_replay() -> void:
	# Replay the unchanged legal path and both corrected paths. The preceding
	# tests independently verify legality; snapshot equality verifies determinism.
	for scenario: String in ["legal_block", "blocked_los", "effective_acc"]:
		var replays: Array[Dictionary] = []
		for replay_index in range(2):
			var fixture := _reaction_legality_fixture(20, true, scenario == "legal_block")
			var simulation: CombatSimulation = fixture.simulation
			if scenario == "blocked_los":
				simulation.apply_authoritative_position(&"target", Vector2i(4_000_000, 3_000_000), 0, 3_000_000)
			elif scenario == "effective_acc":
				simulation.get_actor_state(&"attacker").timed_stat_effects["39a_replay_acc"] = {"source_ref": "TEST-FIXTURE", "stat_modifiers": {"acc": -14}, "expires_at_us": 10_000_000}
			_finish_reaction_parent(fixture)
			var reaction := _reaction_attack(simulation)
			if scenario == "legal_block":
				_expect_true(reaction != null, "39A: unchanged legal reaction must execute.")
				if reaction != null:
					_expect_equal(reaction.natural_roll, 8, "39A: follow-up must roll fresh ACC instead of inheriting the parent's natural 1.")
					_expect_equal(reaction.rng_draw_index, 6, "39A: the reaction ACC must follow opening, parent ACC/rarity and parent Block draws.")
					_expect_equal(reaction.action_instance_id, "", "39A: zero-Act reaction must not create an ordinary action.")
					_expect_equal(reaction.status, CombatAttackInstance.STATUS_PENDING_DEFENSE, "39A: reaction ACC success must wait for normal defenses.")
					var defense := simulation.resolve_pending_defense(reaction.attack_instance_id, "39a_reaction_block")
					_expect_true(defense.success, "39A: the reaction must accept ordinary legal defenses.")
					var resolved := simulation.get_defense_resolution(reaction.defense_resolution_id)
					_expect_equal(resolved.successful_defense_type, &"weapon_block", "39A: a normal weapon Block must defend the reaction.")
					var rolled: Array = resolved.attempts.filter(func(attempt: CombatDefenseAttempt) -> bool: return attempt.eligibility == CombatDefenseAttempt.ATTEMPTED)
					_expect_equal(rolled.size(), 1, "39A: successful Block must stop further defense rolls.")
					if not rolled.is_empty():
						_expect_equal(rolled[0].natural_roll, 6, "39A: the reaction's normal defense must use a separate fresh d20.")
					_expect_equal(simulation.get_actor_state(&"target").current_hpc, 30, "39A: successfully defended parent and reaction must cause no damage.")
					_expect_equal(simulation.random.get_draw_count(), 7, "39A: only opening, parent ACC/rarity/Block and reaction ACC/Block may draw RNG.")
					var draws_before := simulation.random.get_draw_count()
					var events_before := simulation.get_resolved_events().size()
					simulation.resolve_pending_defense(reaction.attack_instance_id, "39a_reaction_block")
					_expect_equal(simulation.random.get_draw_count(), draws_before, "39A: duplicate defense request must not roll again.")
					_expect_equal(simulation.get_resolved_events().size(), events_before, "39A: duplicate defense request must not create another reaction/event.")
			var harness: TwoClientSyncHarness = fixture.harness
			var envelopes := harness.authority.publish_current_events()
			for envelope: CombatEventEnvelope in envelopes:
				harness.client_a.receive(envelope)
			for index in range(envelopes.size() - 1, -1, -1):
				harness.client_b.receive(envelopes[index])
			_expect_true(harness.compare_clients().success, "39A %s: in-order and reversed delivery must converge." % scenario)
			_expect_equal(harness.client_a.get_state_digest(), harness.authority.get_state_digest(), "39A: simulated clients must match authority on legal and rejected reaction paths.")
			var events: Array = []
			for event: CombatEvent in simulation.get_resolved_events():
				events.append(event.to_dictionary())
				if event.event_type == &"critical_reaction_attack_declared":
					_expect_equal(event.parent_event_id, simulation.get_critical_records()[0].event_id, "39A: reaction declaration must retain its critical cause.")
					_expect_equal(event.payload.ordinary_act_cost, 0, "39A: reaction must remain zero ordinary Acts.")
					_expect_equal(event.payload.counts_as_nac, false, "39A: reaction must remain separate from NACs.")
			_expect_equal(simulation.clock.get_elapsed_us(), 1_000_000, "39A: reactions must not refund or add to the parent's 5/AT interval.")
			replays.append({"snapshot": simulation.get_state_snapshot(), "events": events, "digest": harness.authority.get_state_digest()})
		_expect_equal(replays[0], replays[1], "39A %s: same-seed replay must preserve RNG state, events and complete snapshot/digest." % scenario)


func _reaction_legality_fixture(stored_acc: int = 20, registration_clear: bool = true, with_block: bool = false) -> Dictionary:
	var harness := TwoClientSyncHarness.new(_seed_for_reaction_legality(with_block))
	var simulation: CombatSimulation = harness.authority.simulation
	var attacker := _actor(&"attacker", 100, PackedStringArray(["fixture_weapon"]))
	attacker.combat_stats.acc = stored_acc
	simulation.register_actor(attacker)
	simulation.register_actor(_actor(&"target", 0, PackedStringArray(["block_weapon"]) if with_block else PackedStringArray()))
	if with_block:
		var block := CombatBlockDefinition.new(CombatBlockDefinition.TYPE_WEAPON, &"block_weapon", 20, 0, true)
		simulation.register_defense_profile(&"target", CombatDefenseProfile.new(&"39a_block", PackedStringArray(["weapon_block", "dodge", "shield_block", "physical_soak"]), {}, block))
	else:
		_register_no_defense(simulation, &"target")
	simulation.register_damage_protection_profile(&"target", CombatDamageProtectionProfile.new(&"39a_protection"))
	var los_context := {"battlefield": ArenaBattlefield.new(
		Rect2i(-2_000_000, -2_000_000, 12_000_000, 12_000_000),
		[{"id": "side_wall", "rect_microfeet": Rect2i(2_000_000, 1_000_000, 500_000, 1_000_000)}]
	)}
	var simulation_ref: WeakRef = weakref(simulation) # Avoid a Callable/RefCounted cycle.
	simulation.set_attack_final_line_of_sight_resolver(func(source_id: StringName, target_id: StringName) -> bool:
		var current := simulation_ref.get_ref() as CombatSimulation
		return los_context.battlefield.has_line_of_sight(current.get_actor_state(source_id).position_microfeet, current.get_actor_state(target_id).position_microfeet)
	)
	simulation.apply_authoritative_position(&"target", Vector2i(4_000_000, 0 if registration_clear else 3_000_000), 0)
	var definition := _attack(&"39a_follow_up", &"fixture_weapon", CombatPhysicalDamageDefinition.new(1, 1, 1, false, true))
	_expect_true(simulation.register_critical_reaction_attack(&"attacker", definition, registration_clear).success, "39A: reaction registration must succeed.")
	if not registration_clear:
		_expect_true(not los_context.battlefield.has_line_of_sight(Vector2i.ZERO, Vector2i(4_000_000, 3_000_000)), "39A: stale-false fixture must initially be obstructed.")
		simulation.apply_authoritative_position(&"target", Vector2i(4_000_000, 0), 0)
	simulation.begin_combat()
	var started := simulation.start_physical_attack(&"attacker", &"target", definition, "39a_parent", &"torso", true)
	_expect_true(started.success, "39A: parent attack must start legally.")
	simulation.advance_to(1_000_000)
	var parent := simulation.get_attack(started.attack_instance_id)
	_expect_equal(parent.status, CombatAttackInstance.STATUS_PENDING_DEFENSE, "39A: parent ACC must complete before changing the deferred reaction's context.")
	_expect_equal(simulation.get_critical_records()[0].outcome_id, &"relentless_follow_up", "39A: fixture must earn an actual Uncommon follow-up.")
	_expect_equal(_count_events(simulation, &"critical_reaction_attack_declared"), 0, "39A: reaction must wait until the parent becomes terminal.")
	return {"harness": harness, "simulation": simulation, "parent": parent, "definition": definition, "los_context": los_context, "with_block": with_block}


func _finish_reaction_parent(fixture: Dictionary) -> void:
	var simulation: CombatSimulation = fixture.simulation
	_expect_true(simulation.resolve_pending_defense(fixture.parent.attack_instance_id, "39a_parent_defense").success, "39A: parent defenses must resolve through the normal transaction.")
	if not fixture.with_block:
		_expect_true(simulation.resolve_physical_damage(fixture.parent.attack_instance_id, "39a_parent_damage").success, "39A: parent damage must finish before the follow-up executes.")


func _expect_reaction_unavailable(fixture: Dictionary, expected_draws: int, context: String) -> void:
	var simulation: CombatSimulation = fixture.simulation
	_expect_equal(_count_events(simulation, &"critical_reaction_attack_declared"), 0, "%s must reject the reaction before ACC." % context)
	_expect_equal(_count_events(simulation, &"critical_effect_unavailable"), 1, "%s must explicitly record the unavailable effect." % context)
	_expect_equal(simulation.random.get_draw_count(), expected_draws, "%s must consume only the already-earned parent damage draw, no reaction ACC." % context)
	_expect_equal(fixture.parent.status, CombatAttackInstance.STATUS_DAMAGE_RESOLVED, "39A: unavailable reaction must not undo finalized parent damage.")
	_expect_equal(simulation.get_actor_state(&"target").current_hpc, 29, "39A: unavailable reaction must preserve the parent's resolved one damage.")
	_expect_equal(simulation.clock.get_elapsed_us(), 1_000_000, "39A: unavailable reaction must not refund spent Act time.")


func _reaction_attack(simulation: CombatSimulation) -> CombatAttackInstance:
	for event: CombatEvent in simulation.get_resolved_events():
		if event.event_type == &"critical_reaction_attack_declared":
			return simulation.get_attack(event.payload.attack_instance_id)
	return null


func _seed_for_reaction_legality(with_block: bool) -> int:
	for seed_value in range(1, 2_000_000):
		var preview := DeterministicCombatRng.new(seed_value)
		preview.next_int(1, 10)
		preview.next_int(1, 10)
		if preview.next_int(1, 20) != 1:
			continue
		var rarity := preview.next_int(1, 100)
		if rarity < 71 or rarity > 95:
			continue
		if with_block:
			if preview.next_int(1, 20) != 5:
				continue
		else:
			preview.next_int(1, 1)
		if preview.next_int(1, 20) != 8:
			continue
		if with_block and preview.next_int(1, 20) != 6:
			continue
		return seed_value
	assert(false, "Unable to find deterministic reaction-legality seed.")
	return 0


func _base_simulation(seed_value: int, target_block_weapon: bool = false, target_counter_weapon: bool = false, target_dodge: bool = false) -> CombatSimulation:
	var simulation := CombatSimulation.new(seed_value)
	simulation.set_attack_final_line_of_sight_resolver(func(_source: StringName, _target: StringName) -> bool: return true) # Open fixture geometry.
	simulation.register_actor(_actor(&"attacker", 100, PackedStringArray(["fixture_weapon"])))
	var target_equipment := PackedStringArray()
	if target_block_weapon:
		target_equipment.append("block_weapon")
	if target_counter_weapon:
		target_equipment.append("counter_weapon")
		target_equipment.append("shield")
	simulation.register_actor(_actor(&"target", 0, target_equipment, target_dodge))
	return simulation



func _actor(actor_id: StringName, initiative: int, equipment: PackedStringArray, include_dodge: bool = false) -> CombatActorDefinition:
	var combat_stats := {"hpm": 30, "acc": 20, "at": 5, "init": initiative, "mr": 10, "nal": 1, "rb": 0, "sb": 0}
	if include_dodge:
		combat_stats["dt"] = 20
		combat_stats["dp"] = 20
	return CombatActorDefinition.new(
		actor_id, &"test_fixture", "Fixture", {"str": 8, "end": 8, "spd": 8, "dex": 8, "wis": 8, "int": 8, "wit": 8, "man": 8, "luk": 8, "app": 8},
		combat_stats, {}, equipment, {}, {"combat_stats": "TEST-FIXTURE"}
	)


func _attack(
	attack_id: StringName,
	weapon_ref: StringName = &"fixture_weapon",
	damage: CombatPhysicalDamageDefinition = null,
	policy: CombatCriticalTriggerPolicy = null
) -> CombatAttackDefinition:
	return CombatAttackDefinition.new(
		attack_id, weapon_ref, 1, true, true, 0, {"torso": 0}, PackedStringArray(["torso"]), 0, 5_000_000, true,
		PackedStringArray(["TEST-FIXTURE"]), &"hand_held", PackedStringArray(["bashing"]), false,
		CombatAttackDefinition.DUCKING_PROHIBITED, damage, policy
	)


func _register_no_defense(simulation: CombatSimulation, actor_id: StringName) -> void:
	simulation.register_defense_profile(actor_id, CombatDefenseProfile.new(&"none_%s" % String(actor_id)))


func _seed_for_attack_critical(natural_d20: int, rarity_min: int, rarity_max: int) -> int:
	for seed_value in range(1, 1_000_000):
		var preview := DeterministicCombatRng.new(seed_value)
		preview.next_int(1, 10)
		preview.next_int(1, 10)
		if preview.next_int(1, 20) == natural_d20:
			var rarity := preview.next_int(1, 100)
			if rarity >= rarity_min and rarity <= rarity_max:
				return seed_value
	assert(false, "Unable to find deterministic attack-critical seed.")
	return 0


func _seed_for_defense_critical(attack_roll: int, defense_roll: int, rarity_min: int, rarity_max: int) -> int:
	for seed_value in range(1, 1_000_000):
		var preview := DeterministicCombatRng.new(seed_value)
		preview.next_int(1, 10)
		preview.next_int(1, 10)
		if preview.next_int(1, 20) != attack_roll or preview.next_int(1, 20) != defense_roll:
			continue
		var rarity := preview.next_int(1, 100)
		if rarity >= rarity_min and rarity <= rarity_max:
			return seed_value
	assert(false, "Unable to find deterministic defense-critical seed.")
	return 0


func _seed_for_reaction_chain() -> int:
	for seed_value in range(1, 2_000_000):
		var preview := DeterministicCombatRng.new(seed_value)
		preview.next_int(1, 10)
		preview.next_int(1, 10)
		if preview.next_int(1, 20) != 1:
			continue
		var parent_rarity := preview.next_int(1, 100)
		if parent_rarity < 71 or parent_rarity > 95:
			continue
		preview.next_int(1, 1)
		if preview.next_int(1, 20) != 1:
			continue
		if preview.next_int(1, 100) <= 70:
			return seed_value
	assert(false, "Unable to find deterministic reaction-chain seed.")
	return 0


func _count_events(simulation: CombatSimulation, event_type: StringName) -> int:
	var count := 0
	for event: CombatEvent in simulation.get_resolved_events():
		if event.event_type == event_type:
			count += 1
	return count


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s Expected %s, got %s." % [message, str(expected), str(actual)])


func _expect_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)
