class_name BrowserWaveCandidate
extends RefCounted

# In-memory NEXT WAVE candidate only, never a save schema or arbitrary combat
# resume. The source must already be frozen, fully retired, acknowledged downtime.
static func prepare(source: ArenaCombatSession) -> Dictionary:
	if source.get_encounter_state() != ArenaCombatSession.ENCOUNTER_BETWEEN_WAVE_DOWNTIME or not source._playable_persistence is PlayableBrowserPersistence: return {"success":false,"reason":"verified_browser_downtime_required"}
	if not source._playable_persistence.mutation_guard().success: return {"success":false,"reason":"checkpoint_not_secured"}
	for id: String in source._wave_enemy_actor_ids():
		if not source.simulation.is_actor_retired(StringName(id)): return {"success":false,"reason":"wave_retirement_required"}
	var candidate := ArenaCombatSession.new(source._seed_value,null,source._encounter_fixture_id,source._player_character_id)
	copy_data(source,candidate,["simulation","_arena_wave_state_machine","_reward_ledger","_playable_persistence"])
	copy_data(source.simulation,candidate.simulation,["clock","random","event_queue"])
	copy_data(source.simulation.clock,candidate.simulation.clock)
	copy_data(source.simulation.event_queue,candidate.simulation.event_queue)
	if not candidate.simulation.random.restore_wave_entry(source.simulation.random.wave_entry_state()): return {"success":false,"reason":"candidate_rng_invalid"}
	# Registered definitions/resolved history are immutable here. Mutable actor
	# states are copied; no pending candidate operation can change the source.
	for id: String in source.simulation._actor_states:
		var state := CombatActorState.new(source.simulation.get_actor_definition(StringName(id)))
		copy_data(source.simulation._actor_states[id],state)
		candidate.simulation._actor_states[id] = state
	candidate._arena_wave_state_machine = ArenaWaveStateMachine.new()
	copy_data(source._arena_wave_state_machine,candidate._arena_wave_state_machine)
	candidate._reward_ledger = ArenaRewardLedger.new()
	copy_data(source._reward_ledger,candidate._reward_ledger)
	var persistence := PlayableBrowserPersistence.new()
	copy_data(source._playable_persistence,persistence,["_async","_job","owner","previous_owner","_owns_lease"])
	persistence.owner = "session_"+Crypto.new().generate_random_bytes(12).hex_encode()
	persistence.previous_owner = source._playable_persistence.owner
	candidate._playable_persistence = persistence
	candidate.simulation.set_inventory_instance_resolver(persistence.select_instances)
	candidate.simulation.set_attack_final_line_of_sight_resolver(candidate._resolve_attack_final_line_of_sight)
	candidate.simulation.set_rage_knockback_resolver(candidate._resolve_rage_knockback)
	candidate.simulation.set_special_touch_resolver(candidate._resolve_special_touch)
	candidate.simulation.set_gatherable_material_resolver(candidate._resolve_gatherable_material)
	candidate.simulation.set_world_item_pickup_resolver(candidate._resolve_world_item_pickup)
	# Stage registrations/RNG/events with the established transition, but do not
	# permit opponent declarations until durable publication and host adoption.
	candidate._opponent_behavior_enabled = false
	return {"success":true,"candidate":candidate,"opponent_behavior":source._opponent_behavior_enabled}

static func copy_data(source: Object, target: Object, excluded: Array = []) -> void:
	for property: Dictionary in source.get_script().get_script_property_list():
		var field := String(property.name)
		if not (int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) or excluded.has(field): continue
		var value: Variant = source.get(field)
		target.set(field,value.duplicate(true) if value is Dictionary or value is Array else value)
