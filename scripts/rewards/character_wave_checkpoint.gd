class_name CharacterWaveCheckpoint
extends RefCounted

# Separate safe-boundary contract; never an arbitrary combat-resume snapshot.
const PLAYER_FIELDS := ["current_hpc","resources","ability_daily_remaining","conditions","timed_stat_effects","pending_called_shot","held_materials","persistent_damage_shields","awareness","facing_millidegrees","elevation_microfeet","movement_round_index","remaining_mr_microfeet","critical_stagger_until_us","action_timing_anchor_us","action_timing_cursor_us","next_action_interval_index","nac_round_index","nac_uses_this_round","automatic_nac_uses_this_round","nac_automation_settings"]
const FIELDS := ["version","phase","run_id","wave_id","seed","clock_us","rng","battlefield_digest","player_position","opponent_spawn","player","roster","opening","enemy_positions","uncollected_loot","ledger","request_sequence","movement","movement_ledger"]

static func validate(value: Dictionary, actor: CombatActorDefinition = null) -> Dictionary:
	if value.size() != FIELDS.size() or not value.has_all(FIELDS) or value.version != 1 or value.phase not in ["entry","downtime","complete"]: return _fail("invalid_wave_checkpoint")
	if not value.run_id is String or not value.run_id.is_valid_identifier() or value.run_id.length() > 64 or value.wave_id not in ["wave_1","wave_2","wave_3","wave_4","wave_5"]: return _fail("invalid_wave_checkpoint_identity")
	if not value.seed is String or not value.seed.is_valid_int() or not _integer(value.clock_us,0) or not _integer(value.request_sequence,0): return _fail("invalid_wave_checkpoint_clock")
	if not value.movement_ledger is Dictionary or value.movement_ledger.size() != 2 or not _integer(value.movement_ledger.get("round_index"),-1) or not _integer(value.movement_ledger.get("spent_microfeet"),0): return _fail("invalid_entry_movement_ledger")
	if not value.battlefield_digest is String or value.battlefield_digest.length() != 64 or not _position(value.player_position) or not _position(value.opponent_spawn): return _fail("invalid_wave_checkpoint_geometry")
	if not value.rng is Dictionary: return _fail("invalid_entry_rng")
	var random := DeterministicCombatRng.new(0)
	if not random.restore_wave_entry(value.rng): return _fail("invalid_entry_rng")
	if value.rng.seed != value.seed: return _fail("entry_rng_seed_mismatch")
	if not value.player is Dictionary or value.player.size() != PLAYER_FIELDS.size() or not value.player.has_all(PLAYER_FIELDS): return _fail("invalid_entry_player")
	for key: String in ["resources","ability_daily_remaining","timed_stat_effects","pending_called_shot","held_materials","persistent_damage_shields","nac_automation_settings"]:
		if not value.player[key] is Dictionary: return _fail("invalid_entry_player_field")
	if not value.player.conditions is Array or not value.player.awareness is String or not _integer(value.player.current_hpc,-1000000): return _fail("invalid_entry_player_field")
	for key: String in ["facing_millidegrees","elevation_microfeet","movement_round_index","critical_stagger_until_us","action_timing_anchor_us","action_timing_cursor_us","next_action_interval_index","nac_round_index","nac_uses_this_round","automatic_nac_uses_this_round"]:
		if not _integer(value.player[key],-1): return _fail("invalid_entry_player_number")
	if value.player.remaining_mr_microfeet != null and not _integer(value.player.remaining_mr_microfeet,0): return _fail("invalid_entry_movement")
	for condition: Variant in value.player.conditions:
		if not condition is String or condition.is_empty(): return _fail("invalid_entry_condition")
	for amount: Variant in value.player.resources.values():
		if not _integer(amount,0): return _fail("invalid_entry_resource")
	for amount: Variant in value.player.ability_daily_remaining.values():
		if not _integer(amount,0): return _fail("invalid_entry_allowance")
	var effects := {"combat_rage":{"sb":2,"nal":-2,"dt":-1,"dp":-1},"combat_defensive_buff":{"nal":2}}
	for id: String in value.player.timed_stat_effects:
		var effect: Variant = value.player.timed_stat_effects[id]
		if not effects.has(id) or not effect is Dictionary or effect.get("effect_id") != id or effect.get("stat_modifiers") != effects[id] or not _integer(effect.get("expires_at_us"),int(value.clock_us)): return _fail("unsupported_entry_effect")
	for id: String in value.player.persistent_damage_shields:
		var shield: Variant = value.player.persistent_damage_shields[id]
		if id != "force_shield" or not shield is Dictionary or shield.get("shield_id") != id or shield.get("maximum_capacity") != 20 or not _integer(shield.get("capacity"),1) or shield.capacity > 20 or shield.get("physical_attacker_knockback_microfeet") != 2000000: return _fail("unsupported_entry_damage_shield")
	if actor != null:
		var movement := PrimeMovementModel.new(int(actor.get_combat_stat("mr")),int(actor.attributes.spd),int(actor.attributes.end),int(actor.combat_stats.get("running_skill_investment",3)),int(actor.combat_stats.get("running_scm",0)),int(actor.get_combat_stat("rb")),DeterministicCombatRng.new(0))
		if not value.movement is Dictionary or not movement.restore_wave_entry(value.movement): return _fail("invalid_entry_running_state")
		if value.player.current_hpc > actor.get_combat_stat("hpm") or value.player.resources.keys().size() != actor.resource_maxima.size(): return _fail("entry_resource_maximum_mismatch")
		for key: String in actor.resource_maxima:
			if not value.player.resources.has(key) or value.player.resources[key] > actor.resource_maxima[key]: return _fail("entry_resource_maximum_mismatch")
		if value.player.ability_daily_remaining.size() != actor.ability_allowances.size(): return _fail("entry_allowance_mismatch")
		for key: String in actor.ability_allowances:
			if value.player.ability_daily_remaining.get(key,-1) > actor.get_ability_daily_maximum(StringName(key)): return _fail("entry_allowance_mismatch")
	if not value.roster is Array or not value.opening is Dictionary or not value.enemy_positions is Dictionary or not value.uncollected_loot is Array or not value.ledger is Dictionary: return _fail("invalid_entry_roster")
	var definitions: Array = ArenaWaveCatalog.definitions()
	var expected: Array = definitions[int(String(value.wave_id).trim_prefix("wave_"))-1].roster
	if value.roster.size() != expected.size(): return _fail("invalid_entry_roster")
	var total := 0
	for index in range(expected.size()):
		var row: Variant = value.roster[index]
		if not row is Dictionary or row.get("creature_id") != expected[index].creature_id or not row.get("dice_results") is Array: return _fail("invalid_entry_roster")
		var quantity: Dictionary = expected[index].quantity
		var count := 0
		if quantity.kind == "dice":
			if row.dice_results.size() != int(quantity.get("dice_count",1)): return _fail("invalid_entry_roster")
			if not row.get("rng_draw_indices") is Array or row.rng_draw_indices.size() != row.dice_results.size(): return _fail("invalid_entry_quantity_evidence")
			for index_value: Variant in row.rng_draw_indices:
				if not _integer(index_value,1): return _fail("invalid_entry_quantity_evidence")
			for die: Variant in row.dice_results:
				if not _integer(die,1) or die > quantity.sides: return _fail("invalid_entry_roster")
				count += int(die)
		else: count = quantity.count
		if row.get("resolved_count") != count: return _fail("invalid_entry_roster")
		total += count
	if value.opening.size() != total+1 or not value.opening.has("player") or value.enemy_positions.size() != total: return _fail("entry_actor_set_mismatch")
	for id: String in value.enemy_positions:
		if not value.opening.has(id) or id == "player": return _fail("entry_actor_set_mismatch")
	for key: String in value.opening:
		var entry: Variant = value.opening[key]
		if not entry is Dictionary or not _integer(entry.get("roll"),1) or entry.roll > 10 or not _integer(entry.get("draw_index"),0): return _fail("invalid_entry_initiative")
	for pos: Variant in value.enemy_positions.values():
		if not pos is Array or pos.size() != 3 or not _position(pos.slice(0,2)) or not _integer(pos[2],0) or pos[2] > 10000000: return _fail("invalid_entry_geometry")
	return {"success":true}

static func _position(value: Variant) -> bool:
	return value is Array and value.size() == 2 and _integer(value[0],-1000000000) and _integer(value[1],-1000000000)

static func _integer(value: Variant, minimum: int) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(float(value)) and value >= minimum and value <= 9007199254740991 and floor(float(value)) == float(value)

static func _fail(reason: String) -> Dictionary:
	return {"success":false,"reason":reason}
