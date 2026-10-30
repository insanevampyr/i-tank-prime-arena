extends RefCounted

const Policy = preload("res://scripts/rewards/playable_character_persistence.gd")
const ForceTests = preload("res://tests/test_vaelis_force_magic.gd")
const Force = preload("res://scripts/combat/vaelis_force_fixture.gd")
var _failures: Array[String] = []

func run() -> Array[String]:
	_test_policy()
	var first := _shield_sequence(36_903)
	_expect(first == _shield_sequence(36_903),"Identical authorized SS sequences must reproduce complete events/digests.")
	var successes := 0
	var failures := 0
	for seed_value in range(36_904,36_924):
		var result := _shield_sequence(seed_value)
		successes += int(result.get("successes",0))
		failures += int(result.get("failures",0))
	_expect(successes > 0 and failures > 0,"The source SS-9 fixtures must demonstrate both success and failure without modifying SS/RNG.")
	print("FORCE_SHIELD_SS_AUDIT: 100 independent completion draws; successes=%s failures=%s" % [successes,failures])
	return _failures

func _test_policy() -> void:
	var empty := {"conditions":[],"timed_stat_effects":{},"persistent_damage_shields":{},"pending_called_shot":{},"held_materials":{}}
	_expect(Policy.validate_new_run_conditions(empty).success,"Empty combat state must permit the existing NEW RUN path.")
	var unknown_awareness := empty.merged({"awareness":"unverified_persistent_state"},true)
	_expect(not Policy.validate_new_run_conditions(unknown_awareness).success,"Unclassified awareness cannot be treated as a curable persistent condition.")
	var combat := empty.duplicate(true)
	combat.conditions = ["prone","critical_stagger","combat_rage","combat_defensive_buff"]
	# Source effect records exercise classification without granting Vaelis any
	# new abilities. Full checkpoint validation remains mandatory in open().
	combat.timed_stat_effects = {
		"combat_rage":{"effect_id":"combat_rage","applied_at_us":0,"expires_at_us":120000000,"stat_modifiers":{"sb":2,"nal":-2,"dt":-1,"dp":-1},"source_action_instance_id":"prior_rage","successful_hit_knockback_microfeet":2000000},
		"combat_defensive_buff":{"effect_id":"combat_defensive_buff","applied_at_us":0,"expires_at_us":120000000,"stat_modifiers":{"nal":2},"source_action_instance_id":"prior_buff","successful_hit_knockback_microfeet":0}}
	combat.persistent_damage_shields = {"force_shield":{"shield_id":"force_shield","capacity":13,"maximum_capacity":20,"source_actor_id":"player","source_action_instance_id":"prior_shield","physical_attacker_knockback_microfeet":2000000}}
	combat.pending_called_shot = {"target_actor_id":"previous_wave_enemy","target_location":"torso","prepared_at_us":5000000,"source_action_instance_id":"prior_act","source_event_id":"prior_event"}
	var before := combat.duplicate(true)
	_expect(Policy.validate_new_run_conditions(combat).success and combat == before,"Explicit combat-only classifications must permit a fresh run without mutating the prior checkpoint.")
	for field: String in ["conditions","timed_stat_effects","persistent_damage_shields","held_materials","pending_called_shot"]:
		var unknown := empty.duplicate(true)
		if field == "conditions": unknown[field] = ["permanent_injury_unverified"]
		else: unknown[field] = {"unverified_persistent_record":1}
		var result := Policy.validate_new_run_conditions(unknown)
		_expect(not result.success and result.reason.contains("unverified" if field != "pending_called_shot" else "pending_called_shot"),"Unresolved %s must fail closed with its specific identity." % field)

func _shield_sequence(seed_value: int) -> Dictionary:
	var session: ArenaCombatSession = ForceTests.new()._session(seed_value,Vector2i(22000000,12000000))
	if session == null:
		_expect(false,"Source Vaelis SS fixture must initialize.")
		return {}
	session.set_opponent_behavior_enabled(false)
	var player := session.get_actor_state(&"player")
	var successes := 0
	var failures := 0
	for attempt in range(5):
		if attempt % 2 == 0: session.select_target(&"opponent")
		else: session.clear_target()
		var before := session.simulation.random.get_draw_count()
		var expected_rng := DeterministicCombatRng.new(0)
		_expect(expected_rng.restore_wave_entry(session.simulation.random.wave_entry_state()),"SS audit must clone, not reseed or mutate, the authoritative RNG boundary.")
		var expected_roll := expected_rng.next_int(1,20)
		var mana_before: int = player.resources.mana
		var request := session.request_player_special(Force.FORCE_SHIELD_ID)
		_expect(request.get("success",false),"A legal Shield cast must start with or without an enemy selected.")
		_expect(session.simulation.random.get_draw_count() == before and player.resources.mana == mana_before-4,"Declaration spends source Mana but consumes no premature SS draw.")
		var cursor := session.get_resolved_event_count()
		session.advance_by(5000000)
		var checks: Array = []
		for event: CombatEvent in session.simulation.get_resolved_events_from(cursor).events:
			if event.event_type == &"special_skill_resolved": checks.append(event)
		_expect(checks.size() == 1 and session.simulation.random.get_draw_count() == before+1,"Each completed Shield cast consumes exactly one SS draw, with no reroll/reseed.")
		if checks.size() != 1: continue
		var check: CombatEvent = checks[0]
		var data: Dictionary = check.payload
		_expect(check.target_actor_id == &"player" and data.special_id == "force_shield","Shield SS must resolve against self regardless of current enemy selection.")
		_expect(data.ss_target == 9 and data.roll_bonus == 0 and data.natural_d20 == expected_roll and data.adjusted_roll == expected_roll and data.rng_draw_index == before+1,"SS must use source SS 9/RB 0 and the next exact authorized d20.")
		_expect(data.success == (expected_roll <= 9),"The source SS comparison is inclusive adjusted d20 <= target.")
		_expect(player.persistent_damage_shields.has("force_shield") == data.success,"Protection is applied only on SS success.")
		if data.success:
			successes += 1
			session.cancel_player_force_shield()
		else: failures += 1
	_expect(player.resources.mana == 0,"Five legal completed casts consume precisely the existing 20 Mana, including failures.")
	var snapshot := session.simulation.get_state_snapshot()
	var harness := TwoClientSyncHarness.new(seed_value)
	harness.authority.simulation = session.simulation
	harness.deliver_in_order(harness.authority.publish_current_events())
	_expect(snapshot.schema_version == 12 and harness.compare_clients().success and harness.client_a.get_state_snapshot() == snapshot,"SS outcomes must retain complete schema-12 convergence.")
	var events: Array = []
	for event: CombatEvent in session.get_resolved_events(): events.append(event.to_dictionary())
	return {"events":events,"digest":SyncStateDigest.compute(snapshot),"successes":successes,"failures":failures}

func _expect(value: bool, message: String) -> void:
	if not value: _failures.append(message)
