extends RefCounted

# Dormant, bounded command facts. No writer, migration or playable observer.
const V1 = preload("res://scripts/rewards/minimal_character_snapshot.gd")
const MAX_FACTS := 8192
const TYPES := ["ground_loot_collected","downtime_equipment_changed","weapon_handling_changed","downtime_consumable_used","consumable_healing_resolved","consumable_mana_resolved","action_interrupted","consumable_completion_failed","weapon_handling_failed"]
const FIELDS := ["event_type","event_id","parent_event_id","event_sequence","timestamp_us","progression_index","request_id","payload","action"]

static func _affected_inventory(inventory: Dictionary, selections: Dictionary) -> Dictionary:
	var result := {}
	for ref: String in selections:
		if inventory.has(ref): result[ref] = inventory[ref]
	return result

static func _equipment_payload(original: Dictionary) -> Dictionary:
	var d: Dictionary = original.duplicate(true)
	d.inventory_before = _affected_inventory(d.inventory_before,d.ownership_selections)
	d.inventory_after = _affected_inventory(d.inventory_after,d.ownership_selections)
	return d

static func structure(section: Dictionary) -> Dictionary:
	if not V1.V6._keys(section,["coverage","run_id","facts"]) or section.coverage != "creation_to_checkpoint" or not V1._id(section.run_id) or not section.facts is Array or section.facts.size() > MAX_FACTS: return V1.fail("command_coverage_or_limit")
	for f: Variant in section.facts:
		if not f is Dictionary or not V1.V6._keys(f,FIELDS) or not f.event_type in TYPES or not V1._id(f.event_id) or not f.parent_event_id is String or (f.parent_event_id != "" and not V1._id(f.parent_event_id)) or not V1.V6._uint(f.event_sequence) or not V1.V6._uint(f.timestamp_us) or not V1.V6._uint(f.progression_index) or not f.request_id is String or not f.payload is Dictionary or not f.action is Dictionary: return V1.fail("command_fact_fields")
	return {"success":true}

# A fact extractor, not an admission capability. Requires the ORIGINAL live
# service's complete, uninterrupted first-run events and exact committed view.
# Imported v1 histories cannot supply their absent command IDs through this API.
static func from_session(session: ArenaCombatSession, base: Dictionary) -> Dictionary:
	if session == null or session.simulation == null: return V1.fail("original_command_source_required")
	var service: PlayableCharacterPersistence = session._playable_persistence
	if service == null or service._minimal_transactions != null: return V1.fail("original_command_source_required")
	var cold := V1.validate(base,service.source,service.profile_id,service.mode)
	if not cold.success: return cold
	if V1.Contract._normalize_json_numbers(JSON.parse_string(JSON.stringify(service._prior,"",true,true))) != V1.V6._projection(base): return V1.fail("command_source_checkpoint_mismatch")
	if not session.get_actor_state(&"player").current_action_instance_id.is_empty(): return V1.fail("command_checkpoint_action_pending")
	var captured := service._capture(session,base.current.recovery.phase)
	if not captured.success or V1.Contract._normalize_json_numbers(JSON.parse_string(JSON.stringify(captured.checkpoint,"",true,true))) != base.current.recovery: return V1.fail("command_source_checkpoint_not_current")
	if base.current.run_history.size() != 1: return V1.fail("command_complete_prefix_unavailable")
	var section := {"coverage":"creation_to_checkpoint","run_id":service.run_id,"facts":[]}
	var declarations := {}; var starts := {}; var terminals := {}; var receipts := {}; var prefix := 0; var creation := false
	for row: Dictionary in base.evidence.settlements:
		if row.kind in ["item","currency"]: receipts[row.content.instance_id] = row
	for event: CombatEvent in session.get_resolved_events():
		if event.event_type == &"action_interrupted" and event.target_actor_id != &"player": continue
		if event.event_type == &"reward_character_profile_applied":
			if creation or event.payload.get("generation") != 0 or event.payload.get("restored_from_wave_boundary") != false or event.payload.get("profile_id") != service.profile_id or event.payload.get("profile_namespace") != service.mode or event.payload.get("run_id") != service.run_id: return V1.fail("command_complete_prefix_unavailable")
			creation = true
		if event.source_actor_id != &"player" and event.event_type != &"reward_xp_awarded" and event.event_type != &"action_interrupted": continue
		var d: Dictionary = event.payload
		var fact_id := ""
		match String(event.event_type):
			"reward_xp_awarded": fact_id = service._awards.get(event.event_id,{}).get("award_id","")
			"reward_advancement_purchased": fact_id = service._purchases.get(d.get("request_id",""),"")
			"reward_character_level_gained": fact_id = service._growth.get("%s:%s" % [d.get("award_id",""),d.get("level",0)],"")
		if not fact_id.is_empty():
			if prefix >= base.evidence.order.size() or base.evidence.order[prefix].id != fact_id: return V1.fail("command_progression_order_unavailable")
			prefix += 1
		if event.event_type == &"action_declared" and event.source_actor_id == &"player": declarations[d.action_instance_id] = event
		if event.event_type == &"action_started" and event.source_actor_id == &"player": starts[d.action_instance_id] = event
		if event.event_type == &"action_completed" and event.source_actor_id == &"player": terminals[d.action_instance_id] = event
		if not String(event.event_type) in TYPES: continue
		if not creation: return V1.fail("command_complete_prefix_unavailable")
		var payload: Dictionary = d.duplicate(true); var action := {}; var request_id := String(d.get("request_id",""))
		if event.event_type == &"downtime_equipment_changed": payload = _equipment_payload(d)
		if event.event_type == &"ground_loot_collected":
			var matches: Array = receipts.keys().filter(func(id: String): return id.ends_with("/"+String(d.get("world_item_id",""))))
			if matches.size() != 1: return V1.fail("command_acquisition_receipt_unavailable")
			var receipt: Dictionary = receipts[matches[0]]
			if receipt.content.definition_id != d.get("item_definition",{}).get("definition_id") or receipt.content.quantity != d.get("quantity"): return V1.fail("command_acquisition_conflict")
			payload = {"instance_id":matches[0]}
		elif d.has("action_instance_id") or (event.event_type == &"weapon_handling_changed" and not bool(d.downtime_clock_paused) and d.required_acts == 1):
			var instance := String(d.get("action_instance_id",""))
			if instance.is_empty():
				for id: String in terminals:
					if terminals[id].event_id == event.parent_event_id: instance = id; break
			if not declarations.has(instance) or not starts.has(instance): return V1.fail("command_action_request_missing")
			var declared: CombatEvent = declarations[instance]; var start: CombatEvent = starts[instance]
			var definition := String(declared.payload.action_definition_id)
			if not definition.begins_with("player_carried_potion:") and not definition.begins_with("draw_stowed_weapon:"): continue
			var terminal: CombatEvent = event if event.event_type == &"action_interrupted" else terminals.get(instance)
			if terminal == null: return V1.fail("command_action_terminal_missing")
			var original_action := session.simulation.get_action(instance)
			if original_action == null or original_action.request_id != declared.payload.request_id: return V1.fail("command_original_action_timing_unavailable")
			request_id = declared.payload.request_id
			action = {"instance_id":instance,"definition_id":definition,"declaration_id":declared.event_id,"declaration_sequence":declared.stable_sequence,"start_id":start.event_id,"start_sequence":start.stable_sequence,"start_us":start.timestamp_us,"required_acts":start.payload.required_acts,"at_at_start":start.payload.at_at_start,"anchor_us":original_action.timing_anchor_us,"starting_interval_index":original_action.starting_interval_index,"due_us":start.payload.final_effect_due_at_us,"terminal_id":terminal.event_id,"terminal_sequence":terminal.stable_sequence,"terminal_us":terminal.timestamp_us,"terminal_type":String(terminal.event_type),"completed_acts":terminal.payload.completed_acts}
			if event.event_type == &"action_interrupted": payload = {"action_instance_id":instance,"reason":d.reason}
		section.facts.append({"event_type":String(event.event_type),"event_id":event.event_id,"parent_event_id":event.parent_event_id,"event_sequence":event.stable_sequence,"timestamp_us":event.timestamp_us,"progression_index":prefix,"request_id":request_id,"payload":payload,"action":action})
	if not creation or prefix != base.evidence.order.size() or base.evidence.credit != null: return V1.fail("command_complete_prefix_unavailable")
	return {"success":true,"section":V1.Contract._normalize_json_numbers(section)}

static func _actor_prefix(source: CombatCharacterDefinitionResource, body: Dictionary, count: int) -> CombatActorDefinition:
	var actor: CombatActorDefinition = source.instantiate_actor(&"player",source.display_name,PackedStringArray(body.current.permanent.equipment_refs))
	var rows := {}
	for pair: Array in [["purchase","purchases","purchase_id"],["growth","growth","growth_id"]]:
		for row: Dictionary in body.evidence[pair[1]]: rows[row[pair[2]]] = row
	for entry: Dictionary in body.evidence.order.slice(0,count):
		if entry.kind == "purchase":
			var p: Dictionary = rows[entry.id]
			if p.purchase_kind == "attribute":
				match p.target_id:
					"str": actor.apply_verified_strength_advancement(p.value_before,p.value_after,false)
					"dex": actor.apply_verified_dexterity_advancement(p.value_before,p.value_after,p.allocation)
					"spd": actor.apply_verified_speed_advancement(p.value_before,p.value_after)
					"wis": actor.apply_verified_wisdom_advancement(p.value_before,p.value_after)
					"end": actor.apply_verified_endurance_advancement(p.value_before,p.value_after)
		elif entry.kind == "growth":
			var g: Dictionary = rows[entry.id]
			actor.progression_hpm_increase += g.hpm_increase
			actor.resource_maxima[g.resource] = g.maximum_after
	actor.apply_equipment_stat_modifiers({})
	return actor

static func validate(body: Dictionary, source: CombatCharacterDefinitionResource) -> Dictionary:
	var section: Dictionary = body.command_evidence
	if not structure(section).success: return V1.fail("command_structure")
	if body.current.run_history != [section.run_id] or body.current.recovery.run_id != section.run_id: return V1.fail("command_complete_single_run_prefix_required")
	var starter := PlayableCharacterAdmission.prepare_starter(source.definition_id,body.current.profile_namespace,body.current.lineage.baseline_digest)
	if not starter.success: return starter
	# Original source legality is exercised in an isolated scratch session. No
	# persistence is attached, no file/storage APIs and no live game are involved.
	var scratch := ArenaCombatSession.new(1,null,PrimeV3VerticalSliceFixture.ENCOUNTER_WAVE_ONE_GOBLINS,&"vaelis_thorn")
	var initialized := scratch.initialize_wave_one_goblins(Vector2i(14000000,8000000),Vector2i(17000000,8000000),false)
	if not initialized.success: return initialized
	scratch._encounter_state = ArenaCombatSession.ENCOUNTER_BETWEEN_WAVE_DOWNTIME
	scratch._reward_mode = body.current.profile_namespace
	scratch.simulation._combat_started = true
	scratch.simulation._arena_wave_state = {"state":"between_wave_downtime"}
	var owner := PlayableCharacterPersistence.new()
	owner.profile_id = body.current.character_id; owner.mode = body.current.profile_namespace; owner.run_id = section.run_id
	owner.items = starter.items.duplicate(true)
	scratch.simulation.set_inventory_instance_resolver(owner.select_instances)
	var state: CombatActorState = starter.state
	scratch.simulation._actor_states["player"] = state
	var known := {}; var origins := {}; var requests := {}; var events := {}; var actions := {}; var last_sequence := -1; var last_prefix := 0; var last_draw := -1
	for item: Dictionary in owner.items: known[item.instance_id] = true
	for row: Dictionary in body.evidence.settlements:
		if row.kind in ["item","currency"]: origins[row.content.instance_id] = row
	for fact: Dictionary in section.facts:
		if fact.event_sequence <= last_sequence or fact.progression_index < last_prefix or fact.progression_index > body.evidence.order.size() or events.has(fact.event_id): return V1.fail("command_event_order")
		last_sequence = fact.event_sequence; last_prefix = fact.progression_index; events[fact.event_id] = true
		if fact.event_type == "ground_loot_collected":
			if (fact.request_id != "" and not V1._id(fact.request_id)) or not fact.action.is_empty() or not V1.V6._keys(fact.payload,["instance_id"]): return V1.fail("command_acquisition_fields")
			var id: Variant = fact.payload.instance_id
			if not id is String or not origins.has(id) or known.has(id) or origins[id].run_id != section.run_id: return V1.fail("command_acquisition_duplicate_or_missing")
			var terminal: Array = body.current.recovery.ledger.profile_ownership.items.filter(func(i: Dictionary): return i.instance_id == id)
			if terminal.size() != 1: return V1.fail("command_acquisition_terminal_missing")
			var item: Dictionary = terminal[0].duplicate(true); item.quantity = origins[id].content.quantity; item.equipped_slots = []
			var shield := CombatDefinitionCatalog.load_default_fixture_catalog().get_shield(StringName(item.definition_id))
			item.mutable_state = {"shp":shield.maximum_shp,"usable":true} if shield != null else {}
			owner.items.append(item); known[id] = true
			state.inventory_quantities[item.definition_id] = int(state.inventory_quantities.get(item.definition_id,0))+int(item.quantity)
			continue
		if not V1._id(fact.request_id) or requests.has(fact.request_id): return V1.fail("command_duplicate_or_conflicting_request")
		requests[fact.request_id] = true
		var actor := _actor_prefix(source,body,fact.progression_index)
		actor.equipment_refs = state.equipment_refs.duplicate()
		actor.apply_equipment_stat_modifiers(CombatDefinitionCatalog.load_default_fixture_catalog().calculate_armor_stat_modifiers(actor.equipment_refs).get("modifiers",{}))
		scratch.simulation._actor_definitions["player"] = actor
		var action_check := _action(fact,actor,scratch.simulation)
		if not action_check.success: return action_check
		if not fact.action.is_empty():
			if actions.has(fact.action.instance_id): return V1.fail("command_reused_action_instance")
			actions[fact.action.instance_id] = true
		var result := {}
		match fact.event_type:
			"downtime_equipment_changed": result = _equipment(fact,scratch,owner)
			"weapon_handling_changed": result = _handling(fact,state,actor)
			"downtime_consumable_used", "consumable_healing_resolved", "consumable_mana_resolved":
				result = _consume(fact,state,actor,owner,last_draw)
				if result.success: last_draw = result.last_draw
			"action_interrupted", "consumable_completion_failed", "weapon_handling_failed": result = _no_effect(fact,state,actor)
			_: return V1.fail("command_event_unsupported")
		if not result.success: return result
		var synced := owner._sync_items(scratch)
		if not synced.success: return V1.fail("command_ownership_effect",synced)
	if known.size() != origins.size(): return V1.fail("command_missing_acquisition")
	var terminal: Array = body.current.recovery.ledger.profile_ownership.items
	if owner.items.size() != terminal.size(): return V1.fail("command_terminal_ownership")
	for item: Dictionary in owner.items:
		var matching: Array = terminal.filter(func(i: Dictionary): return i.instance_id == item.instance_id)
		if matching.size() != 1 or matching[0] != item: return V1.fail("command_terminal_ownership")
	if Array(state.equipment_refs) != body.current.permanent.equipment_refs or state.inventory_quantities != body.current.permanent.inventory_quantities or state.hand_occupancy != body.current.equipment_state.hands or state.weapon_handling != body.current.equipment_state.handling: return V1.fail("command_terminal_equipment")
	return {"success":true}

static func _action(f: Dictionary, actor: CombatActorDefinition, simulation: CombatSimulation) -> Dictionary:
	var a: Dictionary = f.action
	if a.is_empty():
		return {"success":true} if f.event_type in ["downtime_equipment_changed","downtime_consumable_used"] or (f.event_type == "weapon_handling_changed" and f.payload.get("required_acts") == 0) else V1.fail("command_action_missing")
	var fields := ["instance_id","definition_id","declaration_id","declaration_sequence","start_id","start_sequence","start_us","required_acts","at_at_start","anchor_us","starting_interval_index","due_us","terminal_id","terminal_sequence","terminal_us","terminal_type","completed_acts"]
	if not V1.V6._keys(a,fields): return V1.fail("command_action_fields")
	for key: String in ["instance_id","definition_id","declaration_id","start_id","terminal_id"]:
		if not V1._id(a[key]): return V1.fail("command_action_identity")
	for key: String in ["declaration_sequence","start_sequence","start_us","required_acts","at_at_start","anchor_us","starting_interval_index","due_us","terminal_sequence","terminal_us","completed_acts"]:
		if not V1.V6._uint(a[key]): return V1.fail("command_action_number")
	var draw: bool = a.definition_id.begins_with("draw_stowed_weapon:")
	if not draw and not a.definition_id.begins_with("player_carried_potion:"): return V1.fail("command_action_definition")
	if a.required_acts != (1 if draw else 2) or a.at_at_start != actor.get_combat_stat("at") or a.declaration_sequence >= a.start_sequence or a.start_sequence >= a.terminal_sequence or a.terminal_sequence > f.event_sequence or a.start_us > a.terminal_us or a.terminal_us > f.timestamp_us or a.due_us <= a.start_us: return V1.fail("command_action_binding")
	# Bound multiplication using the existing codec's safe integer ceiling.
	@warning_ignore("integer_division")
	var max_interval: int = V1.Contract.MAX_SAFE_INTEGER / CombatClock.ROUND_DURATION_US - 2
	if a.at_at_start < 1 or a.anchor_us > a.start_us or a.starting_interval_index > max_interval: return V1.fail("command_action_timing_range")
	var due: int = simulation._get_action_interval_timestamp(a.anchor_us,a.starting_interval_index+a.required_acts,a.at_at_start)
	if due != a.due_us: return V1.fail("command_action_timing")
	if a.terminal_type == "action_completed":
		if a.completed_acts != a.required_acts or a.terminal_us < a.due_us or a.terminal_sequence >= f.event_sequence or f.parent_event_id != a.terminal_id: return V1.fail("command_action_completion")
	elif a.terminal_type == "action_interrupted":
		if f.event_type != "action_interrupted" or a.completed_acts >= a.required_acts or a.terminal_id != f.event_id: return V1.fail("command_action_interruption")
	else: return V1.fail("command_action_terminal")
	return {"success":true}

static func _equipment(f: Dictionary, s: ArenaCombatSession, owner: PlayableCharacterPersistence) -> Dictionary:
	var d: Dictionary = f.payload
	var fields := ["request_id","equipment_before","equipment_after","hands_before","hands_after","inventory_before","inventory_after","modifiers_before","modifiers_after","required_acts","downtime_clock_paused","ownership_selections"]
	if not V1.V6._keys(d,fields) or d.request_id != f.request_id or not f.action.is_empty(): return V1.fail("command_equipment_fields")
	for key: String in ["equipment_before","equipment_after"]:
		if not d[key] is Array: return V1.fail("command_equipment_types")
		for ref: Variant in d[key]:
			if not V1._id(ref): return V1.fail("command_equipment_types")
	for key: String in ["hands_before","hands_after","inventory_before","inventory_after","modifiers_before","modifiers_after","ownership_selections"]:
		if not d[key] is Dictionary: return V1.fail("command_equipment_types")
	var state := s.get_actor_state(&"player")
	if d.equipment_before != Array(state.equipment_refs) or d.hands_before != state.hand_occupancy or d.inventory_before != _affected_inventory(state.inventory_quantities,d.ownership_selections): return V1.fail("command_equipment_before")
	var added: Array = d.equipment_after.filter(func(ref: String): return not d.equipment_before.has(ref))
	var removed: Array = d.equipment_before.filter(func(ref: String): return not d.equipment_after.has(ref))
	var result := {}
	if added.size() == 1: result = s.request_player_inventory_equip(StringName(added[0]),f.request_id)
	elif added.is_empty() and removed.size() == 1: result = s.request_player_inventory_unequip(StringName(removed[0]),f.request_id)
	else: return V1.fail("command_equipment_operation")
	if not result.success: return V1.fail("command_equipment_source_rejected",result)
	var generated: CombatEvent = s.simulation.get_resolved_events_from(0).events.back()
	if generated.event_type != &"downtime_equipment_changed" or _equipment_payload(generated.payload) != d: return V1.fail("command_equipment_effect_mismatch")
	for ref: String in d.ownership_selections:
		for selection: Dictionary in d.ownership_selections[ref]:
			var item := owner._item(selection.instance_id)
			if item.is_empty(): return V1.fail("command_equipment_owner_missing")
			item.equipped_slots = ["pending_equipped"] if d.equipment_after.has(ref) else []
	return {"success":true}

static func _handling(f: Dictionary, state: CombatActorState, actor: CombatActorDefinition) -> Dictionary:
	var d: Dictionary = f.payload
	if not V1.V6._keys(d,["request_id","weapon_ref","operation","mode_before","mode_after","hands_before","hands_after","required_acts","owned","downtime_clock_paused"]) or d.request_id != f.request_id or d.hands_before != state.hand_occupancy or d.mode_before != state.weapon_handling.get(d.weapon_ref,"") or d.owned != true: return V1.fail("command_handling_before")
	for key: String in ["weapon_ref","operation","mode_before","mode_after"]:
		if not d[key] is String: return V1.fail("command_handling_types")
	if not V1.V6._uint(d.required_acts) or not d.downtime_clock_paused is bool or not d.owned is bool: return V1.fail("command_handling_types")
	var plan := CombatWeaponHandling.plan(state,CombatDefinitionCatalog.load_default_fixture_catalog().get_weapon(StringName(d.weapon_ref)),int(actor.attributes.str),d.operation)
	if not plan.success or plan.mode != d.mode_after or plan.hand_occupancy != d.hands_after or plan.required_acts != d.required_acts: return V1.fail("command_handling_plan")
	if d.required_acts == 1 and d.downtime_clock_paused == true: return V1.fail("command_persistent_downtime_draw_prohibited")
	if not f.action.is_empty() and (d.operation != "draw" or f.action.definition_id != "draw_stowed_weapon:"+String(d.weapon_ref) or f.action.terminal_type != "action_completed"): return V1.fail("command_handling_action")
	state.hand_occupancy = d.hands_after.duplicate(true)
	if d.mode_after == "": state.weapon_handling.erase(d.weapon_ref)
	else: state.weapon_handling[d.weapon_ref] = d.mode_after
	return {"success":true}

static func _consume(f: Dictionary, state: CombatActorState, actor: CombatActorDefinition, owner: PlayableCharacterPersistence, last_draw: int) -> Dictionary:
	var d: Dictionary = f.payload
	var downtime: bool = f.event_type == "downtime_consumable_used"
	var kind: String = "hpc" if f.event_type == "consumable_healing_resolved" else "mana"
	if downtime:
		if not d.get("effect_kind") is String: return V1.fail("command_consumable_types")
		kind = d.effect_kind
	var before_key := "value_before" if downtime else "hpc_before" if kind == "hpc" else "mana_before"
	var after_key := "value_after" if downtime else "hpc_after" if kind == "hpc" else "mana_after"
	var max_key := "value_maximum" if downtime else "hpc_max" if kind == "hpc" else "mana_max"
	var rolled_key := "rolled_amount" if downtime else "rolled_healing" if kind == "hpc" else "rolled_recovery"
	var fields := ["inventory_id","quantity_before","quantity_after","rolls","rng_draw_indices","flat_bonus",before_key,after_key,max_key,rolled_key,"ownership_selection"]
	fields += ["request_id","effect_kind","required_acts","downtime_clock_paused"] if downtime else ["action_instance_id"]
	if not V1.V6._keys(d,fields): return V1.fail("command_consumable_fields")
	if not d.inventory_id is String or not d.ownership_selection is Array: return V1.fail("command_consumable_types")
	var potion := PrimeV3InventoryCatalog.get_verified_consumable(d.inventory_id)
	if potion.is_empty() or potion.effect_kind != kind or d.flat_bonus != potion.flat_bonus or not d.rolls is Array or d.rolls.size() != potion.dice_count or not d.rng_draw_indices is Array or d.rng_draw_indices.size() != d.rolls.size(): return V1.fail("command_consumable_source")
	if not PrimeV3InventoryCatalog.validate_potion_hands(state,int(actor.attributes.str)).is_empty(): return V1.fail("command_consumable_hands")
	if downtime:
		if d.request_id != f.request_id or d.required_acts != potion.required_acts or d.downtime_clock_paused != true or not f.action.is_empty(): return V1.fail("command_consumable_request")
	elif f.action.definition_id != "player_carried_potion:"+String(d.inventory_id) or f.action.instance_id != d.action_instance_id or f.action.terminal_type != "action_completed": return V1.fail("command_consumable_action")
	var maximum: int = actor.get_combat_stat("hpm") if kind == "hpc" else actor.resource_maxima.get(kind,-1)
	for key: String in [before_key,after_key,max_key,"quantity_before","quantity_after",rolled_key]:
		if not V1.V6._uint(d[key]): return V1.fail("command_consumable_number")
	if d[max_key] != maximum or d[before_key] > maximum or (downtime and d[before_key] >= maximum) or (kind == "hpc" and d[before_key] == 0): return V1.fail("command_consumable_resource")
	var amount: int = potion.flat_bonus
	for i in range(d.rolls.size()):
		if not V1.V6._uint(d.rolls[i]) or d.rolls[i] < 1 or d.rolls[i] > potion.die_sides or not V1.V6._uint(d.rng_draw_indices[i]) or d.rng_draw_indices[i] <= last_draw: return V1.fail("command_consumable_roll")
		amount += d.rolls[i]; last_draw = d.rng_draw_indices[i]
	if amount != d[rolled_key] or mini(maximum,d[before_key]+amount) != d[after_key] or d.quantity_before != state.inventory_quantities.get(d.inventory_id,0) or d.quantity_after != d.quantity_before-1: return V1.fail("command_consumable_effect")
	var selected := owner.select_instances(&"player",d.inventory_id,1,false)
	if not selected.success or selected.get("selection") != d.ownership_selection: return V1.fail("command_consumable_ownership")
	for item: Dictionary in d.ownership_selection: owner._item(item.instance_id).quantity -= item.quantity
	state.inventory_quantities[d.inventory_id] = d.quantity_after
	return {"success":true,"last_draw":last_draw}

static func _no_effect(f: Dictionary, state: CombatActorState, actor: CombatActorDefinition) -> Dictionary:
	if f.action.is_empty() or f.payload.get("action_instance_id") != f.action.instance_id: return V1.fail("command_failed_action_binding")
	if f.event_type == "action_interrupted":
		if not V1.V6._keys(f.payload,["action_instance_id","reason"]) or not V1._id(f.payload.reason): return V1.fail("command_interrupted_fields")
	else:
		var fields := ["action_instance_id","reason"]+(["inventory_id","quantity_after"] if f.event_type == "consumable_completion_failed" else ["weapon_ref"])
		if not V1.V6._keys(f.payload,fields) or not V1._id(f.payload.reason): return V1.fail("command_failed_fields")
	var definition: String = f.action.definition_id
	if definition.begins_with("player_carried_potion:"):
		var id := definition.trim_prefix("player_carried_potion:")
		if PrimeV3InventoryCatalog.get_verified_consumable(id).is_empty() or state.inventory_quantities.get(id,0) < 1 or not PrimeV3InventoryCatalog.validate_potion_hands(state,int(actor.attributes.str)).is_empty(): return V1.fail("command_interrupted_consumable_eligibility")
	elif definition.begins_with("draw_stowed_weapon:"):
		var plan := CombatWeaponHandling.plan(state,CombatDefinitionCatalog.load_default_fixture_catalog().get_weapon(StringName(definition.trim_prefix("draw_stowed_weapon:"))),int(actor.attributes.str),"draw")
		if not plan.success: return V1.fail("command_interrupted_draw_eligibility")
	else: return V1.fail("command_failed_definition")
	return {"success":true}
