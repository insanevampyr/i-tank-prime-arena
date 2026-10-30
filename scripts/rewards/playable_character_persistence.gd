class_name PlayableCharacterPersistence
extends RefCounted

const Admission = preload("res://scripts/rewards/playable_character_admission.gd")
const Profiles = preload("res://scripts/rewards/character_profile_projection.gd")
const Coordinator = preload("res://scripts/rewards/character_persistence_coordinator.gd")
const Boundary = preload("res://scripts/rewards/character_wave_checkpoint.gd")
# Explicit runner injection: ordinary gameplay never uses test directories.
static var test_nonpersistent := false
static var test_storage: CharacterSaveStorage
static var test_run_id := ""
var storage: CharacterSaveStorage
var source: CombatCharacterDefinitionResource
var candidate: Dictionary = {}
var recovery: Dictionary = {}
var mode := ""
var profile_id := ""
var run_id := ""
var _runs: Array = []
var generation := 0
var items: Array = []
var receipts: Array = []
var _prior: Dictionary = {}
var _awards: Dictionary = {}
var _purchases: Dictionary = {}
var _growth: Dictionary = {}
var _cursor := 0
var _world_claims: Dictionary = {}
var _proved_awards: Dictionary = {}
var _proved_purchases: Dictionary = {}
var _proved_growth: Dictionary = {}
var _catalog := CombatDefinitionCatalog.load_default_fixture_catalog()
var _last_item_state: Dictionary = {}
var _allowed_payloads: Dictionary = {}
var _allowed_proposals: Dictionary = {}
var _evidence: Dictionary = {}
var _source_binding := ""
var _projection_window := false
var _lineage: Dictionary = {}
var _prepared: Dictionary = {}
var _prepared_fingerprint := ""
var _last_ack := false
var _failure := ""
var _reset := false
var _status := {"persistent":false,"reason":"not_initialized","text":"Progress not saved"}

func open(p_mode: String, new_run: bool = false, defeated_checkpoint: Dictionary = {}) -> Dictionary:
	mode = p_mode
	if not defeated_checkpoint.is_empty() and not new_run: return _fail("defeat_restart_requires_new_run")
	if mode not in ["normal","dev_normal"]: return _fail("test_mode_nonpersistent")
	storage = test_storage if test_storage != null else CharacterSaveStorage.new()
	var platform := storage.get_storage_status()
	if not platform.success: return _fail(String(platform.get("reason","storage_unavailable")))
	var starter := Admission.prepare_starter(&"vaelis_thorn",mode)
	if not starter.get("success",false): return starter
	source = starter.source
	profile_id = starter.profile_id
	var history := storage.inspect_profile(profile_id)
	if not history.success or history.writer_locked or history.pending_write: return _fail("profile_history_or_lock_requires_review")
	for index in range(1,history.generations.size()):
		var before: Dictionary = history.generations[index-1].payload
		var after: Dictionary = history.generations[index].payload
		if not CharacterSaveContract.validate_replacement(before,after).success or not Coordinator._validate_continuity(before,after).success or not Coordinator._validate_new_items(before,after).success: return _fail("profile_generation_continuity_invalid")
	if history.generations.is_empty():
		if not defeated_checkpoint.is_empty(): return _fail("defeated_profile_checkpoint_missing")
		if history.get("profile_directory_exists",false): return _fail("empty_profile_history_requires_review")
		_prior = starter.prepared.payload.duplicate(true)
		items = _prior.items.duplicate(true)
		receipts = _prior.settlements.duplicate(true)
		_lineage = _prior.lineage.duplicate(true)
		_allowed_payloads[Profiles.fingerprint(_prior)] = _lineage.duplicate(true)
		candidate = Profiles.hydrate(_prior,source,profile_id,Admission.RULES,_verify)
		if not candidate.success: return candidate
		run_id = _new_run_id()
		_runs = [run_id]
	else:
		_prior = history.generations.back().payload.duplicate(true)
		if _prior.get("profile_namespace") != mode or _prior.character_id != profile_id or _prior.rules_revision != Admission.RULES or _prior.get("lineage",{}).get("baseline_digest") != Profiles.fingerprint(source.to_dictionary()): return _fail("profile_source_namespace_mismatch")
		if not _prior.has("recovery") or not _prior.has("equipment_state") or not _prior.has("run_history"): return _fail("legacy_profile_requires_explicit_boundary_migration")
		_runs = _prior.run_history.duplicate()
		_lineage = _prior.lineage.duplicate(true)
		if _lineage != starter.prepared.payload.lineage: return _fail("profile_lineage_mismatch")
		_allowed_payloads[Profiles.fingerprint(_prior)] = _lineage.duplicate(true)
		candidate = Profiles.hydrate(_prior,source,profile_id,Admission.RULES,_verify)
		if not candidate.success: return candidate
		var checked := Coordinator.prepare(_prior,_prior.settlements,history.generations.back().transaction_id,int(_prior.generation)-1,[])
		if not checked.success: return checked
		# Validate complete receipt ownership, not only structural JSON/checksum.
		var receipt_check := Coordinator._validate_new_items({},_prior)
		if not receipt_check.success: return receipt_check
		generation = int(_prior.generation)
		items = _prior.items.duplicate(true)
		receipts = _prior.settlements.duplicate(true)
		recovery = _prior.recovery.duplicate(true)
		run_id = recovery.run_id
		if new_run:
			if not defeated_checkpoint.is_empty():
				var expected := {"profile_id":profile_id,"mode":mode,"run_id":run_id,"wave_id":recovery.wave_id,"generation":generation}
				if recovery.phase != "entry" or defeated_checkpoint != expected: return _fail("defeated_checkpoint_changed_or_unverified")
			elif recovery.phase != "complete": return _fail("new_run_requires_completed_circuit")
			var condition_policy := validate_new_run_conditions(recovery.player)
			if not condition_policy.success: return _fail(condition_policy.reason)
			run_id = _new_run_id()
			if _runs.has(run_id): return _fail("run_identity_reused")
			_runs.append(run_id)
			recovery = {}
	for receipt: Dictionary in receipts:
		if receipt.kind in ["item","currency"]: _world_claims[receipt.content.instance_id] = true
	for award: Dictionary in _prior.permanent.award_receipts: _awards[award.award_id] = award.duplicate(true)
	for purchase: Dictionary in _prior.purchases: _purchases[purchase.purchase_id] = purchase.purchase_id
	for record: Dictionary in _prior.permanent.growth: _growth[record.growth_id+":"+str(record.level)] = record.growth_id
	return {"success":true,"recovery":recovery.duplicate(true)}

static func validate_new_run_conditions(player: Dictionary) -> Dictionary:
	# Called only after complete profile/checkpoint validation. This scopes the
	# owner-approved run boundary; it does not expire/cancel effects in the old
	# run, heal an injury, or modify a save. The existing fresh candidate clears
	# these encounter fields after this gate and before durable publication.
	if player.has("awareness") and player.awareness not in ["aware","unaware"]:
		return {"success":false,"reason":"new_run_awareness_policy_unavailable:%s" % str(player.awareness)}
	var combat_effects := ["combat_rage","combat_defensive_buff"]
	var conditions: Array = player.get("conditions",[]).duplicate()
	conditions.sort()
	for condition: String in conditions:
		if condition in ["prone","critical_stagger"]: continue
		if combat_effects.has(condition) and player.get("timed_stat_effects",{}).has(condition): continue
		return {"success":false,"reason":"new_run_condition_policy_unavailable:%s" % condition}
	for effect: String in player.get("timed_stat_effects",{}):
		if not combat_effects.has(effect): return {"success":false,"reason":"new_run_effect_policy_unavailable:%s" % effect}
	for shield: String in player.get("persistent_damage_shields",{}):
		# Indefinite protection within a run is not permanent character growth.
		# It still carries across waves and RETRY; this rule ends it only on a
		# separately authorized NEW RUN, per Task 36J-Fix3.
		if shield != "force_shield": return {"success":false,"reason":"new_run_shield_policy_unavailable:%s" % shield}
	var preparation: Dictionary = player.get("pending_called_shot",{})
	if not preparation.is_empty() and (preparation.size() != 5 or not preparation.has_all(["target_actor_id","target_location","prepared_at_us","source_action_instance_id","source_event_id"])):
		return {"success":false,"reason":"new_run_preparation_policy_unavailable:pending_called_shot"}
	var materials: Array = player.get("held_materials",{}).keys()
	materials.sort()
	if not materials.is_empty(): return {"success":false,"reason":"new_run_held_material_policy_unavailable:%s" % materials[0]}
	return {"success":true}

func _new_run_id() -> String:
	return test_run_id if not test_run_id.is_empty() else "run_"+Crypto.new().generate_random_bytes(16).hex_encode()

func apply_player(session: ArenaCombatSession) -> Dictionary:
	var state := session.simulation.get_actor_state(&"player")
	if state == null: return _fail("restoration_player_unavailable")
	state.inventory_quantities = candidate.permanent.inventory_quantities.duplicate(true)
	state.hand_occupancy = candidate.hand_occupancy.duplicate(true)
	state.hand_occupancy_authoritative = true
	state.weapon_handling = _prior.get("equipment_state",{}).get("handling",{}).duplicate(true)
	if recovery.is_empty(): session.simulation.configure_nac_automation(&"player",VaelisForceFixture.default_nac_automation_settings())
	var p: Dictionary = candidate.permanent
	state.progression = {"exp_type":source.progression_policy.exp_type,"level":p.level,"expm":candidate.xp.earned,"expc":candidate.xp.unspent,"run_earned_xp":p.xp_baseline.earned,"run_spent_xp":p.xp_baseline.spent,"award_ids":[],"history":[],"base_hpm":source.combat_stats.hpm,"base_resource_maxima":source.resource_maxima.duplicate(true)}
	for award: Dictionary in p.award_receipts: state.progression.award_ids.append(award.award_id)
	for record: Dictionary in p.growth:
		var restored := record.duplicate(true)
		# Historical identity anchor, not a newly emitted/replayed XP award.
		restored["award_id"] = record.growth_id
		state.progression.history.append(restored)
	if not recovery.is_empty():
		if recovery.battlefield_digest != Profiles.fingerprint(session.get_battlefield().to_dictionary()): return _fail("recovery_battlefield_mismatch")
		for field: String in Boundary.PLAYER_FIELDS:
			if field == "conditions": state.conditions = PackedStringArray(recovery.player.conditions)
			else: state.set(field,recovery.player[field].duplicate(true) if recovery.player[field] is Dictionary or recovery.player[field] is Array else recovery.player[field])
		state.position_microfeet = Vector2i(recovery.player_position[0],recovery.player_position[1])
		if not session.get_battlefield().is_position_legal(&"player",state.position_microfeet,{"player":state.position_microfeet}).get("legal",false): return _fail("recovery_position_illegal")
	return {"success":true}

func restore_ledger(ledger: ArenaRewardLedger) -> void:
	ledger.earned_xp = int(candidate.permanent.xp_baseline.earned)
	ledger.spent_xp = int(candidate.permanent.xp_baseline.spent)
	ledger.player_level = int(candidate.permanent.level)
	ledger.purchase_records.clear()
	for purchase: Dictionary in _prior.purchases:
		var record := purchase.duplicate(true)
		record["request_id"] = purchase.purchase_id
		ledger.purchase_records.append(record)
		ledger.processed_purchase_request_ids[purchase.purchase_id] = true
	if not recovery.is_empty():
		ledger.current_wave_earned_xp = int(recovery.ledger.get("current_wave_earned_xp",0))
		for id: String in recovery.ledger.get("processed_actor_ids",[]): ledger.processed_actor_ids[id] = true
		ledger._next_world_item_sequence = int(recovery.ledger.get("next_world_item_sequence",0))

func bind_runtime(session: ArenaCombatSession) -> Dictionary:
	if not recovery.is_empty():
		if not session.simulation.random.restore_wave_entry(recovery.rng): return _fail("invalid_entry_rng")
		session.simulation.clock.advance(int(recovery.clock_us))
		session._next_request_sequence = int(recovery.request_sequence)
		if recovery.phase != "entry":
			var retired := session.simulation.retire_wave_combatants(session._wave_enemy_actor_ids())
			if not retired.success: return retired
			session._arena_wave_state_machine._state = ArenaWaveStateMachine.STATE_COMPLETE if recovery.phase == "complete" else ArenaWaveStateMachine.STATE_BETWEEN_WAVE_DOWNTIME
			session._arena_wave_state_machine._active_enemy_ids = PackedStringArray()
			session._encounter_state = ArenaCombatSession.ENCOUNTER_PLAYER_VICTORY if recovery.phase == "complete" else ArenaCombatSession.ENCOUNTER_BETWEEN_WAVE_DOWNTIME
			for field: String in ["_goblin_actor_ids","_spadoodle_actor_ids","_skelly_actor_ids","_hades_follower_actor_ids","_gargoyle_actor_ids","_rare_human_warrior_actor_ids"]: session.set(field,PackedStringArray())
			for item: Dictionary in recovery.uncollected_loot:
				if item.get("world_item_kind") != "loot" or item.get("collection_status") != "uncollected" or item.get("state") != "dropped" or not item.get("position_microfeet") is Array: return _fail("unsupported_downtime_world_item")
				var restored := item.duplicate(true)
				var owned_id := "%s/%s/%s/%s" % [profile_id,run_id,recovery.wave_id,String(item.get("world_item_id",""))]
				if _world_claims.has(owned_id) or session.simulation._world_items.has(item.get("world_item_id","")): return _fail("recovery_loot_already_owned_or_duplicated")
				restored.position_microfeet = Vector2i(item.position_microfeet[0],item.position_microfeet[1])
				session.simulation._world_items[item.world_item_id] = restored
		else:
			for id: String in recovery.enemy_positions:
				var enemy := session.simulation.get_actor_state(StringName(id))
				if enemy == null: return _fail("entry_enemy_identity_mismatch")
				var pos: Array = recovery.enemy_positions[id]
				if not session.get_battlefield().is_position_legal(StringName(id),Vector2i(pos[0],pos[1]),{id:Vector2i(pos[0],pos[1])}).get("legal",false): return _fail("entry_enemy_position_illegal")
				enemy.position_microfeet = Vector2i(pos[0],pos[1])
				enemy.elevation_microfeet = int(pos[2])
		var reapplied := apply_player(session)
		if not reapplied.success: return reapplied
		session._sync_wave_snapshot()
		for effect_id: String in session.get_actor_state(&"player").timed_stat_effects:
			var effect: Dictionary = session.get_actor_state(&"player").timed_stat_effects[effect_id]
			var expires := int(effect.get("expires_at_us",-1))
			if expires < int(recovery.clock_us): return _fail("entry_effect_expiry_invalid")
			session.simulation.schedule_event(expires,&"timed_stat_effect_expire_due",0,&"player",&"player",{"effect_id":effect_id,"expected_expires_at_us":expires})
	# No callback owns session/simulation: avoid the previous ObjectDB cycles.
	session.simulation.set_inventory_instance_resolver(select_instances)
	_cursor = session.simulation.get_resolved_event_count()
	session._reward_event_cursor = _cursor
	var player := session.get_actor_state(&"player")
	if not recovery.is_empty():
		session._player_movement_round_index = int(recovery.movement_ledger.round_index)
		session._player_movement_spent_microfeet = int(recovery.movement_ledger.spent_microfeet)
	session._goblin_last_movement_us = session.simulation.clock.get_elapsed_us()
	session._initialize_wave_enemy_navigation_state()
	session.simulation.record_reward_event(&"reward_character_profile_applied",&"player",&"player",{"profile_id":profile_id,"profile_namespace":mode,"generation":generation,"run_id":run_id,"restored_from_wave_boundary":not recovery.is_empty()})
	var owned := _sync_items(session)
	if not owned.success: return owned
	_cursor = session.simulation.get_resolved_event_count()
	session._reward_event_cursor = _cursor
	_status = {"persistent":true,"reason":"validated_profile_loaded","text":"Wave entry saved" if recovery.get("phase") == "entry" else "Progress saved","generation":generation,"profile_namespace":mode}
	if generation == 0 or recovery.is_empty(): return checkpoint(session,"entry")
	return {"success":true}

func select_instances(actor_id: StringName, definition: String, quantity: int, equipped: bool) -> Dictionary:
	if actor_id != &"player": return {"success":true}
	if not _failure.is_empty(): return _fail(_failure)
	var matches: Array = []
	for item: Dictionary in items:
		if item.definition_id == definition and item.quantity > 0 and (not item.equipped_slots.is_empty()) == equipped: matches.append(item)
	matches.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.instance_id < b.instance_id)
	if matches.is_empty(): return _fail("owned_item_instance_unavailable")
	# Distinct wear cannot be selected from an aggregate UI without an instance choice.
	for item: Dictionary in matches:
		if item.mutable_state != matches[0].mutable_state: return _fail("ambiguous_item_condition_requires_instance_selection")
	var selection: Array = []
	var remaining := quantity
	for item: Dictionary in matches:
		var amount := mini(remaining,int(item.quantity))
		selection.append({"instance_id":item.instance_id,"quantity":amount})
		remaining -= amount
		if remaining == 0: return {"success":true,"selection":selection}
	return _fail("owned_quantity_insufficient")

func mutation_guard() -> Dictionary:
	if not _failure.is_empty(): return {"success":false,"reason":_failure}
	if not _prepared.is_empty() and not _last_ack: return {"success":false,"reason":"persistent_checkpoint_pending"}
	return {"success":true}

func equipment_condition(ref: String) -> Dictionary:
	var matches: Array = []
	for item: Dictionary in items:
		if item.definition_id == ref and item.quantity > 0: matches.append(item)
	if matches.is_empty(): return _fail("equipment_instance_missing")
	for item: Dictionary in matches:
		if item.mutable_state != matches[0].mutable_state: return _fail("ambiguous_equipment_condition")
	return {"success":true,"condition":matches[0].mutable_state.duplicate(true)}

func owned_description(ref: String) -> Dictionary:
	for item: Dictionary in items:
		if item.definition_id != ref or item.quantity <= 0: continue
		var text := String(item.provenance.get("source_ref",""))
		if text.begins_with("{"):
			var parser := JSON.new()
			if parser.parse(text) == OK and parser.data is Dictionary and parser.data.get("definition") is Dictionary: return parser.data.definition.duplicate(true)
		if ref == "vaelis_source_sword_sheath": return {"display_name":"Short sword sheath","source_ref":text}
		if ref == "vaelis_source_basic_clothing": return {"display_name":"Basic clothing","source_ref":text}
	return {}

func owned_provenance(ref: String) -> Dictionary:
	var origins: Array = []
	for item: Dictionary in items:
		if item.definition_id == ref and item.quantity > 0: origins.append({"instance_id":item.instance_id,"quantity":item.quantity,"provenance":item.provenance.duplicate(true)})
	return {"owned_instances":origins}

func ingest(session: ArenaCombatSession) -> Dictionary:
	var batch := session.simulation.get_resolved_events_from(_cursor)
	if not batch.success: return _fail("ownership_cursor_invalid")
	for event: CombatEvent in batch.events:
		if String(event.event_type) == "reward_xp_awarded" and event.target_actor_id == &"player": _proved_awards[event.event_id] = event.payload.duplicate(true)
		if String(event.event_type) == "reward_advancement_purchased" and event.source_actor_id == &"player": _proved_purchases[event.event_id] = event.payload.duplicate(true)
		if String(event.event_type) == "reward_character_level_gained" and event.source_actor_id == &"player": _proved_growth["%s:%s" % [event.payload.award_id,event.payload.level]] = event.payload.duplicate(true)
		if event.source_actor_id != &"player": continue
		var data: Dictionary = event.payload
		match String(event.event_type):
			"physical_defense_attempted":
				var attempt: Dictionary = data.get("attempt",{})
				if attempt.get("defense_type") == "shield_block" and attempt.get("resources_spent",{}).get("shield_shp") == 1:
					var item: Dictionary = {}
					for owned: Dictionary in items:
						if owned.definition_id == attempt.equipment_ref and not owned.equipped_slots.is_empty(): item = owned
					if item.is_empty(): return _fail("shield_damage_instance_proof_missing")
					var after := int(attempt.resolution_context.shield_shp_after)
					if after != int(item.mutable_state.get("shp",-1))-1: return _fail("shield_damage_history_mismatch")
					item.mutable_state = {"shp":after,"usable":after > 0}
					if after == 0:
						item.quantity = 0
						item.equipped_slots = []
			"ground_loot_collected":
				var origin := String(data.world_item_id)
				var instance := "%s/%s/%s/%s" % [profile_id,run_id,session._current_reward_wave_id(),origin]
				if _world_claims.has(instance): return _fail("duplicate_item_origin")
				var world: Dictionary = session.simulation._world_items.get(origin,{})
				if world.get("collected_by_actor_id") != "player" or world.get("quantity") != data.quantity: return _fail("collection_ownership_proof_missing")
				var provenance := {"origin_id":instance,"source_ref":JSON.stringify({"definition":data.item_definition,"provenance":world.get("provenance",{}),"origin_event_id":world.get("origin_event_id","")},"",true,true)}
				var item := {"instance_id":instance,"definition_id":String(data.item_definition.definition_id),"quantity":int(data.quantity),"provenance":provenance,"equipped_slots":[],"mutable_state":{}}
				var shield := _catalog.get_shield(StringName(item.definition_id))
				if shield != null: item.mutable_state = {"shp":shield.maximum_shp,"usable":true}
				items.append(item)
				_world_claims[instance] = true
				_add_receipt("currency" if item.definition_id == "prime_v3_gold" else "item","item_"+instance.sha256_text().substr(0,48),{"instance_id":instance,"definition_id":item.definition_id,"quantity":item.quantity,"provenance_digest":Profiles.fingerprint(provenance)},session._current_reward_wave_id())
			"downtime_consumable_used", "consumable_healing_resolved", "consumable_mana_resolved":
				if not data.has("ownership_selection"): return _fail("consumption_instance_proof_missing")
				for selected: Dictionary in data.ownership_selection:
					var item := _item(selected.instance_id)
					if item.is_empty() or not item.equipped_slots.is_empty() or item.quantity < selected.quantity: return _fail("consumption_instance_invalid")
					item.quantity -= selected.quantity
			"downtime_equipment_changed":
				if not data.has("ownership_selections"): return _fail("equipment_instance_proof_missing")
				for ref: String in data.ownership_selections:
					var selected: Array = data.ownership_selections[ref]
					if selected.size() != 1: return _fail("equipment_stack_split_unavailable")
					var item := _item(selected[0].instance_id)
					if item.is_empty() or item.quantity != 1: return _fail("equipment_instance_invalid")
					item.equipped_slots = ["pending_equipped"] if data.equipment_after.has(ref) else []
	_cursor = int(batch.next_cursor)
	return _sync_items(session)

func _item(id: String) -> Dictionary:
	for item: Dictionary in items:
		if item.instance_id == id: return item
	return {}

func _sync_items(session: ArenaCombatSession) -> Dictionary:
	var state := session.get_actor_state(&"player")
	var catalog := _catalog
	var defense := session.simulation.get_defense_profile(&"player")
	var signature := {"inventory":state.inventory_quantities,"equipment":Array(state.equipment_refs),"hands":state.hand_occupancy,"handling":state.weapon_handling,"shield":defense.shield_block.to_dictionary() if defense.shield_block != null else {}}
	if signature == _last_item_state: return {"success":true}
	var carried := {}
	var equipped := {}
	for item: Dictionary in items:
		if item.quantity == 0: continue
		var ref := String(item.definition_id)
		if item.equipped_slots.is_empty(): carried[ref] = int(carried.get(ref,0))+int(item.quantity)
		else:
			if equipped.has(ref) or not state.equipment_refs.has(ref): return _fail("equipped_instance_ambiguous")
			equipped[ref] = item.instance_id
			var slots: Array = []
			if catalog.get_weapon(StringName(ref)) != null:
				for hand: String in ["left","right"]:
					if state.hand_occupancy[hand] == ref: slots.append(hand)
				if state.weapon_handling.get(ref) == CombatWeaponHandling.STOWED: slots = ["stowed:"+ref]
			elif catalog.get_armor(StringName(ref)) != null: slots = ["armor:"+String(catalog.get_armor(StringName(ref)).armor_slot)]
			elif catalog.get_shield(StringName(ref)) != null:
				slots = ["left"] if catalog.get_shield(StringName(ref)).hand_occupancy == 1 else ["shield"]
				var block := session.simulation.get_defense_profile(&"player").shield_block
				if block == null or block.equipment_ref != StringName(ref): return _fail("shield_instance_unavailable")
				if not item.mutable_state.is_empty() and block.current_shp != item.mutable_state.shp: return _fail("shield_damage_authoritative_proof_missing")
				item.mutable_state = {"shp":block.current_shp,"usable":block.usable}
			else: return _fail("equipped_instance_definition_unavailable")
			item.equipped_slots = slots
	for ref: String in state.equipment_refs:
		if not equipped.has(ref): return _fail("equipped_instance_missing")
	var expected := state.inventory_quantities.duplicate(true)
	for ref: String in expected.keys():
		if expected[ref] == 0: expected.erase(ref)
	if carried != expected: return _fail("inventory_instance_totals_mismatch")
	session._reward_ledger.profile_ownership = {"profile_id":profile_id,"run_id":run_id,"profile_namespace":mode,"items":items.duplicate(true)}
	session.simulation.set_reward_state_snapshot(session._reward_ledger.to_dictionary())
	_last_item_state = signature.duplicate(true)
	return {"success":true}

func checkpoint(session: ArenaCombatSession, phase: String) -> Dictionary:
	if _reset: return {"success":true,"persistent":false}
	if phase == "entry" and not session._authorized_entry_write: return _fail("checkpoint_requires_wave_entry_boundary",false)
	if phase == "downtime" and session.get_encounter_state() != ArenaCombatSession.ENCOUNTER_BETWEEN_WAVE_DOWNTIME: return _fail("checkpoint_requires_authoritative_downtime",false)
	if phase == "complete" and session._arena_wave_state_machine.get_state() != ArenaWaveStateMachine.STATE_COMPLETE: return _fail("checkpoint_requires_completed_circuit",false)
	if not _failure.is_empty(): return _fail(_failure)
	var synced := ingest(session)
	if not synced.success: return synced
	var state := session.get_actor_state(&"player")
	if not state.current_action_instance_id.is_empty(): return _fail("wave_checkpoint_pending_player_action",false)
	var actor := session.simulation.get_actor_definition(&"player")
	var ledger := session.get_reward_state()
	if ledger.mode != mode: return _fail("persistent_mode_lineage_changed")
	for award: Dictionary in ledger.awards:
		var key := String(award.get("award_event_id",""))
		if _awards.has(key): continue
		var proof: Dictionary = _proved_awards.get(key,{})
		if proof.get("actor_id") != award.actor_id or proof.get("wave_id") != award.wave_id or proof.get("xp") != award.xp: return _fail("xp_award_authoritative_proof_missing")
		var id := "%s/starter_admission/%s/%s/defeat/%s" % [profile_id,run_id,award.wave_id,award.actor_id]
		var receipt := {"award_id":id,"xp":int(award.xp)}
		_awards[key] = receipt
		_add_receipt("xp","xp_"+id.sha256_text().substr(0,48),{"award_id":id,"amount":award.xp},award.wave_id)
	for purchase: Dictionary in ledger.purchase_records:
		var key := String(purchase.request_id)
		if _purchases.has(key): continue
		var proof: Dictionary = _proved_purchases.get(String(purchase.get("event_id","")),{})
		for field: String in Profiles.PURCHASE_FIELDS:
			if proof.get(field) != purchase.get(field): return _fail("purchase_authoritative_proof_missing")
		var id := "%s/starter_admission/%s/%s/purchase/%s/%s" % [profile_id,run_id,session._current_reward_wave_id(),purchase.target_id,purchase.value_after]
		_purchases[key] = id
		_add_receipt("purchase","purchase_"+id.sha256_text().substr(0,48),{"purchase_id":id,"cost":purchase.cost},session._current_reward_wave_id())
	for record: Dictionary in state.progression.get("history",[]):
		var key := "%s:%s" % [record.get("award_id",""),record.level]
		if _growth.has(key): continue
		if not _awards.has(record.award_id): return _fail("growth_award_proof_missing")
		var proof: Dictionary = _proved_growth.get(key,{})
		for field: String in Profiles.HISTORY_FIELDS:
			if proof.get(field) != record.get(field): return _fail("growth_authoritative_proof_missing")
		_growth[key] = _awards[record.award_id].award_id+"/level_"+str(record.level)
	var equipment := {"hands":state.hand_occupancy.duplicate(true),"handling":state.weapon_handling.duplicate(true)}
	var checkpoints: Array = _prior.secured_checkpoints.duplicate()
	if phase != "entry":
		var checkpoint_id := "%s/%s/%s" % [profile_id,run_id,session._current_reward_wave_id()]
		if not checkpoints.has(checkpoint_id): checkpoints.append(checkpoint_id)
	_evidence = _lineage.merged({"profile_namespace":mode,"run_history":_runs.duplicate(),"generation":generation+1,"items":items.filter(func(item: Dictionary) -> bool: return item.quantity > 0).duplicate(true),"award_receipts":_awards.duplicate(true),"purchase_ids":_purchases.duplicate(true),"growth_ids":_growth.duplicate(true),"secured_checkpoints":checkpoints,"equipment_state":equipment},true)
	var defense := session.simulation.get_defense_profile(&"player")
	_source_binding = Profiles.fingerprint({"actor":actor.to_dictionary(),"state":state.to_dictionary(),"ledger":ledger,"defense":defense.to_dictionary()})
	_projection_window = true
	var projected := Profiles.project(source,actor,state,ledger,defense,_verify)
	_projection_window = false
	if not projected.get("success",false): return _fail(String(projected.get("reason","projection_failed")))
	var boundary := _capture(session,phase)
	if not boundary.get("success",false): return boundary
	var payload: Dictionary = projected.payload
	payload["recovery"] = boundary.checkpoint
	payload["settlements"] = receipts.duplicate(true)
	_allowed_payloads[Profiles.fingerprint(payload)] = _lineage.duplicate(true)
	var fingerprint := Profiles.fingerprint(payload)
	# Repeated unchanged safe boundaries do not publish another generation.
	var previous := _prior.duplicate(true)
	previous.generation = payload.generation
	if generation > 0 and Profiles.fingerprint(previous) == fingerprint: return {"success":true,"generation":generation}
	if not _prepared.is_empty() and not _last_ack:
		if fingerprint != _prepared_fingerprint: return _fail("pending_checkpoint_source_changed",false)
		return reconcile()
	var proposal := Coordinator.prepare(payload,receipts,"checkpoint_%s" % str(generation+1),generation,_prior.secured_checkpoints if generation > 0 else [])
	if not proposal.success: return _fail(String(proposal.get("reason","checkpoint_preparation_failed")))
	_prepared = proposal.prepared
	_prepared_fingerprint = fingerprint
	_allowed_payloads[Profiles.fingerprint(_prepared.payload)] = _lineage.duplicate(true)
	_allowed_proposals[Profiles.fingerprint(_prepared)] = true
	_last_ack = false
	return _ack(Coordinator.new(storage).commit(_prepared,source,profile_id,Admission.RULES,_verify))

func reconcile() -> Dictionary:
	if _prepared.is_empty(): return _fail("no_pending_checkpoint")
	return _ack(Coordinator.new(storage).reconcile(_prepared,source,profile_id,Admission.RULES,_verify))

func _ack(result: Dictionary) -> Dictionary:
	if not result.get("success",false) or result.get("recovery_required",false) or result.get("generation") != result.get("latest_generation"): return _fail(String(result.get("reason","checkpoint_acknowledgement_unverified")),false)
	_prior = _prepared.payload.duplicate(true)
	generation = int(result.generation)
	recovery = _prior.recovery.duplicate(true)
	_last_ack = true
	_status = {"persistent":true,"reason":"checkpoint_verified","text":"Wave entry saved" if recovery.phase == "entry" else "Progress saved","generation":generation,"profile_namespace":mode}
	return result

func _capture(session: ArenaCombatSession, phase: String) -> Dictionary:
	if not session.player_movement_boundary_provider.is_valid(): return _fail("movement_checkpoint_provider_unavailable")
	var state := session.get_actor_state(&"player")
	var player := {}
	for field: String in Boundary.PLAYER_FIELDS:
		var value: Variant = state.get(field)
		player[field] = Array(value) if value is PackedStringArray else (value.duplicate(true) if value is Dictionary or value is Array else value)
	player["awareness"] = String(state.awareness)
	var retain: bool = phase != "entry" and not recovery.is_empty() and recovery.wave_id == session._current_reward_wave_id()
	var opening: Dictionary = recovery.opening.duplicate(true) if retain else {}
	var positions: Dictionary = recovery.enemy_positions.duplicate(true) if retain else {}
	for id: String in ["player"]+Array(session._wave_enemy_actor_ids()):
		var actor := session.get_actor_state(StringName(id))
		if actor == null: continue
		opening[id] = {"roll":actor.opening_initiative_roll,"draw_index":actor.opening_initiative_rng_draw_index}
		if id != "player": positions[id] = [actor.position_microfeet.x,actor.position_microfeet.y,actor.elevation_microfeet]
	var loot: Array = []
	if phase != "entry":
		for item: Dictionary in session.get_ground_loot():
			if item.get("collection_status") == "uncollected": loot.append(item.duplicate(true))
	var checkpoint := {"version":1,"phase":phase,"run_id":run_id,"wave_id":session._current_reward_wave_id(),"seed":str(session._seed_value),"clock_us":session.simulation.clock.get_elapsed_us(),"rng":session.simulation.random.wave_entry_state(),"battlefield_digest":Profiles.fingerprint(session.get_battlefield().to_dictionary()),"player_position":[state.position_microfeet.x,state.position_microfeet.y],"opponent_spawn":[session._initial_opponent_position_microfeet.x,session._initial_opponent_position_microfeet.y],"player":player,"roster":session._arena_wave_state_machine.get_resolved_roster(),"opening":opening,"enemy_positions":positions,"uncollected_loot":loot,"ledger":session.get_reward_state(),"request_sequence":session._next_request_sequence}
	checkpoint["movement"] = session.player_movement_boundary_provider.call()
	# Equipment transactions update actor MR before the controller refreshes its
	# motion view. Preserve dynamic fatigue while binding the new verified MR.
	checkpoint.movement.profile.mr = int(session.simulation.get_actor_definition(&"player").get_combat_stat("mr"))
	checkpoint["movement_ledger"] = {"round_index":session._player_movement_round_index,"spent_microfeet":session._player_movement_spent_microfeet}
	var valid := Boundary.validate(checkpoint,session.simulation.get_actor_definition(&"player"))
	return {"success":true,"checkpoint":checkpoint} if valid.success else valid

func _add_receipt(kind: String, claim: String, content: Dictionary, wave: String) -> void:
	var receipt_id := "%s/%s/%s/%s" % [profile_id,run_id,wave,claim]
	for receipt: Dictionary in receipts:
		if receipt.receipt_id == receipt_id: return
	receipts.append({"version":1,"receipt_id":receipt_id,"profile_id":profile_id,"run_id":run_id,"wave_id":wave,"claim_id":claim,"kind":kind,"content":content.duplicate(true)})

func _verify(operation: String, binding: String) -> Dictionary:
	if operation == "project": return _evidence.merged({"authorized":binding == _source_binding,"binding":binding},true).duplicate(true)
	if operation == "hydrate":
		# Only the synchronous source-verified projection may introduce a hash;
		# disk loads are pinned after full storage/source inspection in open().
		if _projection_window: _allowed_payloads[binding] = _lineage.duplicate(true)
		return {"authorized":_allowed_payloads.has(binding),"binding":binding,"lineage":_allowed_payloads.get(binding,{})}
	return {"authorized":operation == "commit" and _allowed_proposals.has(binding),"binding":binding}

func fixture_reset() -> void:
	_reset = true
	_status = {"persistent":false,"reason":"fixture_reset_is_nonpersistent","text":"Progress not saved"}

func status() -> Dictionary: return _status.duplicate(true)

func _fail(reason: String, sticky: bool = true) -> Dictionary:
	if sticky: _failure = reason
	_status = {"persistent":false,"reason":reason,"text":"Progress not saved"}
	return {"success":false,"reason":reason}
