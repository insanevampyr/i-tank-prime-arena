extends RefCounted

const VAELIS = preload("res://data/characters/vaelis_thorn.tres")
const ATTACKER := &"attacker"
const TARGET := &"target"
const DISTANCE := 2_000_000
var _failures: Array[String] = []
var _assertions := 0


func run() -> Array[String]:
	_test_footing_and_displacement()
	_test_unavailable_and_negated_sources()
	_test_independent_knockbacks_and_replay()
	print("39J knockback Balance: %d assertions." % _assertions)
	return _failures


func _test_footing_and_displacement() -> void:
	for kind: String in ["rage", "force_bolt", "force_shield"]:
		for row: Array in [["full", 1, DISTANCE], ["partial", 20, 1_000_000], ["blocked", 1, 0], ["blocked", 20, 0]]:
			var fixture := _resolve_fixture(kind, _seed(kind, row[1]), row[0])
			var event := _knockback(fixture.sim, kind)
			_expect(event != null and event.payload.has("balance_check"), "%s/%s must resolve one real check." % [kind, row[0]])
			if event == null or not event.payload.has("balance_check"): continue
			var sim: CombatSimulation = fixture.sim
			var check: Dictionary = event.payload.balance_check
			var state := sim.get_actor_state(event.target_actor_id)
			_expect(check.natural_roll == row[1] and check.check_success == (row[1] == 1), "Natural 1/20 must retain skill critical semantics.")
			_expect(check.critical_success == (row[1] == 1) and check.critical_failure == (row[1] == 20), "Balance records exact natural critical flags.")
			_expect(state.conditions.has("prone") == (row[1] == 20) and not state.conditions.has("critical_stagger"), "Balance changes footing without Stagger.")
			_expect(event.payload.resolved_distance_microfeet == row[2] and event.payload.blocked == (row[0] != "full"), "Legal displacement must match geometry independently of Balance.")
			_expect(abs(state.position_microfeet.x - int(event.payload.start_microfeet[0])) == row[2], "The authoritative actor must occupy the resolved position.")
			_expect(state.remaining_mr_microfeet == fixture.mr_before, "Forced displacement consumes no voluntary MR.")
			_expect(check.rng_draw_index == fixture.draws_before_damage + 2 and sim.random.get_draw_count() == check.rng_draw_index, "Damage draws first, then exactly one Balance d20 without rarity.")
			_expect(event.parent_event_id == fixture.damage.event_id and check.opportunity_id == event.payload.balance_opportunity_id, "Balance evidence must descend from the source damage event.")
			_expect(check.inputs.definition_id == "vaelis_thorn" and check.inputs.actor_id == String(event.target_actor_id), "Use the affected actor's sourced skill data.")
			_check_source_controls(fixture, kind)
			_check_duplicate(fixture, event, kind)


func _test_unavailable_and_negated_sources() -> void:
	for row: Array in [["rage", "missing_training", "balance_training_unknown"], ["force_bolt", "missing_rb", "balance_rb_unavailable"], ["force_shield", "missing_scm", "balance_scm_unavailable"], ["rage", "already_prone", "balance_not_required_already_prone"], ["force_bolt", "incapacitated", "balance_actor_incapacitated"]]:
		var fixture := _resolve_fixture(row[0], _seed(row[0], 1), "full", row[1])
		var event := _knockback(fixture.sim, row[0])
		_expect(event != null and event.payload.get("balance_reason") == row[2] and not event.payload.has("balance_check"), "Unavailable check must report %s." % row[2])
		if event != null:
			_expect(event.payload.resolved_distance_microfeet == DISTANCE, "Unavailable or already-prone check must preserve displacement.")
			_expect(fixture.sim.get_actor_state(event.target_actor_id).conditions.has("prone") == (row[1] == "already_prone"), "Skipped check cannot create a fall or stand an actor up.")
		_expect(fixture.sim.random.get_draw_count() == fixture.draws_before_damage + 1, "Skipped Balance must add no RNG.")

	for row: Array in [["rage", "inactive_rage"], ["rage", "absorbed"], ["force_bolt", "defended"], ["force_shield", "no_absorption"], ["rage", "no_direction"]]:
		var fixture := _resolve_fixture(row[0], _seed(row[0], 1, row[1]), "full", row[1])
		_expect(_knockback(fixture.sim, row[0]) == null, "Ineligible %s/%s must emit no knockback/check." % row)
		var expected_draws := 0 if row[1] == "defended" else 1
		if row[1] == "absorbed":
			var shield := _knockback(fixture.sim, "force_shield")
			_expect(shield != null and shield.payload.has("balance_check") and fixture.damage.payload.final_damage == 0, "Full absorption negates Rage while qualifying shield contact still pushes the attacker.")
			expected_draws += 1
		_expect(fixture.sim.random.get_draw_count() == fixture.draws_before_damage + expected_draws, "Ineligible %s/%s cannot consume Balance RNG." % row)

	for mode: String in [ArenaRewardLedger.MODE_TEST, ArenaRewardLedger.MODE_DEV_NORMAL]:
		var fixture := _resolve_fixture("rage", _seed("rage", 20), "full", "", mode)
		var event := _knockback(fixture.sim, "rage")
		_expect(event != null and not event.payload.has("balance_opportunity_id") and fixture.sim.random.get_draw_count() == fixture.draws_before_damage + 1, "Legacy mode still displaces without a Balance draw.")


func _test_independent_knockbacks_and_replay() -> void:
	var reentrant := _resolve_fixture("rage", _seed("rage", 1), "full", "reentrant")
	var event := _knockback(reentrant.sim, "rage")
	_expect(event != null and event.payload.resolved_distance_microfeet == DISTANCE, "Reentrant source processing preserves the original displacement.")
	_expect(reentrant.sim.random.get_draw_count() == reentrant.draws_before_damage + 2, "Reentrant geometry callback cannot repeat Balance.")
	var count := 0
	for entry: CombatEvent in reentrant.sim.get_resolved_events():
		if entry.event_type == &"rage_knockback_resolved": count += 1
	_expect(count == 1, "Reentrant processing emits exactly one source event.")
	var seed_value := _seed("dual", 1)
	var replays: Array = []
	for replay_index in range(2):
		var fixture := _resolve_fixture("dual", seed_value)
		var sim: CombatSimulation = fixture.sim
		var shield := _knockback(sim, "force_shield")
		var rage := _knockback(sim, "rage")
		_expect(shield != null and rage != null, "Partial absorption can produce both independently legal knockbacks.")
		if shield == null or rage == null: return
		_expect(shield.parent_event_id == rage.parent_event_id and shield.target_actor_id == ATTACKER and rage.target_actor_id == TARGET, "One damage event can cause two knockbacks with distinct recipients.")
		_expect(shield.payload.balance_opportunity_id != rage.payload.balance_opportunity_id, "Independently resolved sources have distinct causal keys.")
		_expect(shield.payload.balance_check.natural_roll == 1 and rage.payload.balance_check.natural_roll == 20, "Shield then Rage each consume their own seeded d20.")
		_expect(shield.stable_sequence < rage.stable_sequence and sim.random.get_draw_count() == fixture.draws_before_damage + 3, "The source ordering stays shield first, Rage second.")
		_expect(sim.get_state_snapshot().schema_version == 12, "Knockback evidence preserves schema 12.")
		var harness: TwoClientSyncHarness = fixture.harness
		var envelopes := harness.authority.publish_current_events()
		for envelope: CombatEventEnvelope in envelopes: harness.client_a.receive(envelope)
		for index in range(envelopes.size() - 1, -1, -1):
			harness.client_b.receive(envelopes[index])
			harness.client_b.receive(envelopes[index])
		_expect(harness.compare_clients().success and harness.client_a.get_state_digest() == harness.authority.get_state_digest(), "Both clients must converge through duplicate/reordered knockback evidence.")
		replays.append({"snapshot": sim.get_state_snapshot(), "rng": sim.random.wave_entry_state(), "digest": harness.authority.get_state_digest()})
	_expect(replays[0] == replays[1], "Same-seed replay preserves events, RNG and snapshot.")


func _resolve_fixture(kind: String, seed_value: int, geometry: String = "full", gate: String = "", mode: String = ArenaRewardLedger.MODE_NORMAL) -> Dictionary:
	var harness := TwoClientSyncHarness.new(seed_value)
	var sim: CombatSimulation = harness.authority.simulation
	var session := ArenaCombatSession.new(seed_value, sim)
	sim.set_reward_state_snapshot({"mode": mode})
	var affected := ATTACKER if kind == "force_shield" else TARGET
	var obstacles: Array[Dictionary] = []
	if geometry != "full":
		var clearance := 1_000_000 if geometry == "partial" else 0
		var wall_x := 2_500_000 - clearance if affected == ATTACKER else 8_500_000 + clearance
		obstacles.append({"id": "39j_wall", "rect_microfeet": Rect2i(wall_x, 0, 1_000_000, 10_000_000)})
	session.configure_battlefield(ArenaBattlefield.new(Rect2i(0, 0, 20_000_000, 10_000_000), obstacles))
	sim.set_rage_knockback_resolver(session._resolve_rage_knockback)
	sim.set_attack_final_line_of_sight_resolver(func(_source: StringName, _target: StringName) -> bool: return true)
	for id: StringName in [ATTACKER, TARGET]:
		var source: CombatCharacterDefinitionResource = VAELIS.duplicate(true)
		source.combat_stats.merge({"acc": 19, "ss": 19, "at": 5, "init": 100 if id == ATTACKER else 0, "hpm": 100, "nal": 100 if id == TARGET and gate == "no_absorption" else 0}, true)
		if id == affected:
			if gate == "missing_rb": source.combat_stats.erase("rb")
			if gate == "missing_training": source.proficiencies.erase("balance")
			if gate == "missing_scm": source.proficiencies.balance.erase("scm")
		if id == ATTACKER:
			source.ability_allowances[String(HadesCombatFollowerFixture.RAGE_ACTION_ID)] = {"base_daily_uses": 2, "repurchase_count": 0}
		var actor: CombatActorDefinition = source.instantiate_actor(id, String(id), PackedStringArray(["39j_weapon"]))
		if gate == "defended" and id == TARGET:
			actor.combat_stats.dp = 20
		else:
			actor.combat_stats.erase("dt")
			actor.combat_stats.erase("dp")
		sim.register_actor(actor)
		sim.register_defense_profile(id, CombatDefenseProfile.new(&"39j_defense"))
		sim.register_damage_protection_profile(id, CombatDamageProtectionProfile.new(&"39j_protection"))
		var x := 4_000_000 if id == ATTACKER or gate == "no_direction" else 8_000_000
		sim.apply_authoritative_position(id, Vector2i(x, 5_000_000), 0)
	sim.begin_combat()
	if kind in ["rage", "dual"] and gate != "inactive_rage":
		var rage := sim.start_verified_special_action(ATTACKER, ATTACKER, HadesCombatFollowerFixture.make_rage_action_definition(), "39j_rage")
		_expect(rage.success, "Use the real Rage action to establish the effect.")
		sim.advance_to(2_000_000)
	if kind in ["force_shield", "dual"] or gate == "absorbed":
		var shield := sim.start_verified_special_action(TARGET, TARGET, VaelisForceFixture.make_force_shield_action_definition(), "39j_shield")
		_expect(shield.success, "Use the real Force Shield action to establish the shield.")
		sim.advance_to(sim.clock.get_elapsed_us() + 1_000_000)
		var shields := sim.get_actor_state(TARGET).persistent_damage_shields
		_expect(shields.has("force_shield"), "The shield must finish its actual SS check.")
		if kind == "dual" and shields.has("force_shield"): shields.force_shield.capacity = 1
	var weapon := CombatAttackDefinition.new(&"39j_hit", &"39j_weapon", 1, true, true, 0, {"torso": 0}, PackedStringArray(["torso"]), 0, 5_000_000, true,
		PackedStringArray(["TEST-FIXTURE"]), &"hand_held", PackedStringArray(["bashing"]), false,
		CombatAttackDefinition.DUCKING_PROHIBITED, CombatPhysicalDamageDefinition.new(1, 6, 4, false, false))
	var started: Dictionary
	var ongoing: Dictionary
	if kind == "force_bolt":
		ongoing = sim.start_physical_attack(TARGET, ATTACKER, weapon, "39j_ongoing", &"torso", true)
		started = sim.start_nac_projectile_special(ATTACKER, TARGET, VaelisForceFixture.make_force_bolt_attack_definition(&"39j_weapon"), "39j_bolt", &"force_bolt", 2, &"torso", true)
	else:
		started = sim.start_physical_attack(ATTACKER, TARGET, weapon, "39j_hit", &"torso", true)
		ongoing = sim.start_action(TARGET, CombatActionDefinition.new(&"39j_ongoing", 3), "39j_ongoing")
		sim.advance_to(sim.clock.get_elapsed_us() + 1_000_000)
	_expect(started.has("attack_instance_id"), "The source attack must be declared.")
	var attack_id := String(started.get("attack_instance_id", ""))
	var context: CombatDodgeContext = null
	if gate == "defended":
		context = CombatDodgeContext.new(CombatDodgeContext.SELECTION_RESOLVED, Vector2i(8_000_000, 6_000_000), 1_000_000, false, true, true, "TEST-FIXTURE", &"step", &"open", true, true, true, 0, "legal step")
	_expect(sim.resolve_pending_defense(attack_id, "39j_defense", context).success, "Resolve through the ordinary defense boundary.")
	if gate == "already_prone": sim.set_actor_defense_state(affected, &"aware", PackedStringArray(["prone"]))
	if gate == "incapacitated": sim.get_actor_state(affected).current_hpc = 1
	var draws := sim.random.get_draw_count()
	var mr_before: Variant = sim.get_actor_state(affected).remaining_mr_microfeet
	var elapsed_before := sim.clock.get_elapsed_us()
	var timing_before := [sim.get_actor_state(ATTACKER).next_action_interval_index, sim.get_actor_state(TARGET).next_action_interval_index]
	if gate == "reentrant":
		var reentry := {"attempted": false}
		sim.set_rage_knockback_resolver(func(source_id: StringName, target_id: StringName, distance: int) -> Dictionary:
			if not reentry.attempted:
				reentry.attempted = true
				var parent: CombatEvent = sim.get_resolved_events().back()
				sim._resolve_source_knockback(attack_id, source_id, target_id, distance, "rage_knockback", parent.event_id, "combat_rage")
			return session._resolve_rage_knockback(source_id, target_id, distance)
		)
	var result := _damage(sim, kind, attack_id, "39j_damage")
	if gate == "reentrant": sim.set_rage_knockback_resolver(Callable())
	_expect(result.success == (gate != "defended"), "A defended source is ineligible for damage/knockback.")
	var damage: CombatEvent = null
	for event: CombatEvent in sim.get_resolved_events():
		if event.event_type in [&"physical_damage_resolved", &"force_bolt_damage_resolved"]: damage = event
	return {"sim": sim, "harness": harness, "session": session, "attack_id": attack_id, "ongoing": ongoing,
		"damage": damage, "draws_before_damage": draws, "mr_before": mr_before,
		"elapsed_before": elapsed_before, "timing_before": timing_before}


func _check_source_controls(fixture: Dictionary, kind: String) -> void:
	var sim: CombatSimulation = fixture.sim
	var damage: Dictionary = fixture.damage.payload
	var target := sim.get_actor_state(TARGET)
	_expect(sim.clock.get_elapsed_us() == fixture.elapsed_before and [sim.get_actor_state(ATTACKER).next_action_interval_index, target.next_action_interval_index] == fixture.timing_before, "Knockback and Balance neither spend nor refund Acts.")
	_expect(target.current_hpc == damage.hpc_after and sim.get_actor_state(ATTACKER).current_hpc == 100, "The existing damage is the only HPC change.")
	if kind == "force_bolt":
		_expect(damage.final_damage == damage.damage_roll and sim.get_actor_state(ATTACKER).resources.mana == 18, "Bolt retains its d6 damage and two-Mana cost.")
		var action := sim.get_action(sim.get_attack(fixture.ongoing.attack_instance_id).action_instance_id)
		_expect(action.interruption_reason == "force_bolt_nac_interrupt" and action.status == CombatActionInstance.STATUS_INTERRUPTED, "Bolt's existing physical-action interruption survives either Balance result.")
	else:
		var action := sim.get_action(fixture.ongoing.action_instance_id)
		_expect(action.status == CombatActionInstance.STATUS_IN_PROGRESS and action.final_effect_due_at_us > sim.clock.get_elapsed_us(), "The ordinary action keeps its timing after displacement and footing resolution.")
		if kind == "force_shield":
			_expect(damage.final_damage == 0 and damage.protective_points_absorbed == damage.weapon_rolls[0] + 4 and target.resources.mana == 16, "Force Shield retains absorption and its four-Mana cost.")
			_expect(target.persistent_damage_shields.force_shield.capacity == 20 - damage.protective_points_absorbed, "Shield capacity decreases once by the absorbed damage.")
		else:
			_expect(damage.final_damage == damage.weapon_rolls[0] + 4 and sim.get_actor_state(ATTACKER).ability_daily_remaining[String(HadesCombatFollowerFixture.RAGE_ACTION_ID)] == 1, "Rage retains damage and one spent daily use.")


func _check_duplicate(fixture: Dictionary, event: CombatEvent, kind: String) -> void:
	var sim: CombatSimulation = fixture.sim
	var before := sim.get_state_snapshot().duplicate(true)
	var rng := sim.random.wave_entry_state()
	var count := sim.get_resolved_events().size()
	_expect(not _damage(sim, kind, fixture.attack_id, "39j_damage").success and not _damage(sim, kind, fixture.attack_id, "39j_duplicate").success, "Both repeated and fresh requests for resolved damage reject.")
	sim._resolve_source_knockback(fixture.attack_id, event.source_actor_id, event.target_actor_id, DISTANCE, kind + "_knockback", event.parent_event_id)
	_expect(sim.get_state_snapshot() == before and sim.random.wave_entry_state() == rng and sim.get_resolved_events().size() == count, "Reprocessing the same source cannot move, roll or emit again.")


func _damage(sim: CombatSimulation, kind: String, attack_id: String, request_id: String) -> Dictionary:
	if kind == "force_bolt": return sim.resolve_nac_projectile_damage(attack_id, request_id)
	return sim.resolve_physical_damage(attack_id, request_id)


func _knockback(sim: CombatSimulation, kind: String) -> CombatEvent:
	for event: CombatEvent in sim.get_resolved_events():
		if event.event_type == StringName(kind + "_knockback_resolved"): return event
	return null


func _seed(kind: String, footing: int, gate: String = "") -> int:
	for seed_value in range(1, 10_000):
		var preview := DeterministicCombatRng.new(seed_value)
		preview.next_int(1, 10)
		preview.next_int(1, 10)
		if kind in ["force_bolt", "force_shield", "dual"] or gate == "absorbed":
			if preview.next_int(1, 20) == 20: continue
		if preview.next_int(1, 20) not in range(2, 20): continue
		if gate == "defended":
			if preview.next_int(1, 20) in range(2, 20): return seed_value
			continue
		preview.next_int(1, 6)
		if preview.next_int(1, 20) != footing: continue
		if kind == "dual" and preview.next_int(1, 20) != 20: continue
		return seed_value
	_expect(false, "Could not find a deterministic source/footing fixture seed.")
	return 0


func _expect(value: bool, message: String) -> void:
	_assertions += 1
	if not value: _failures.append(message)
