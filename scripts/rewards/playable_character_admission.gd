class_name PlayableCharacterAdmission
extends RefCounted

# Authored registry: one named starter per playable definition and namespace.
# This admits NEW source grants, never reconstructs identities from a live stack.
const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
const Profiles = preload("res://scripts/rewards/character_profile_projection.gd")
const Coordinator = preload("res://scripts/rewards/character_persistence_coordinator.gd")
const VAELIS_RECORD := "res://assets/Character Choices/Vaelis_Thorn_Elven_Fighter_Force_Mage_Arena_Character_Data.json"
const RULES := "prime_v3_arena_starter_v1"

static func audit(character: StringName) -> Dictionary:
	if character == Fixture.PLAYER_CHARACTER_GUARD:
		return _fail("guard_permanent_starter_unverified", {"missing":["level","initial_EXPM_EXPC","HPB_and_progression_policy","starting_gold_and_carried_possessions"],"source":"PRIME-V3 p. 336; data/characters/prime_v3_uncommon_guard.tres; data/loadouts/arena_guard_plate_buckler.tres"})
	if character != Fixture.PLAYER_CHARACTER_VAELIS: return _fail("unsupported_playable_starter")
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(VAELIS_RECORD)) != OK or not parser.data is Dictionary: return _fail("vaelis_authored_record_unavailable")
	var record: Dictionary = parser.data
	if not record.has_all(["character","progression","attributes","derived","resources","equipment"]): return _fail("vaelis_authored_record_incomplete")
	for field: String in ["character","progression","attributes","derived","resources","equipment"]:
		if not record[field] is Dictionary: return _fail("vaelis_authored_record_incomplete")
	var source: CombatCharacterDefinitionResource = load("res://data/characters/vaelis_thorn.tres")
	var loadout: CombatLoadoutDefinitionResource = load("res://data/loadouts/vaelis_thorn_short_sword_wand.tres")
	var actor := Fixture.make_player_actor(character)
	if source == null or loadout == null or actor == null: return _fail("vaelis_definition_unavailable")
	for key: String in source.attributes:
		if record.attributes.get(key.to_upper()) != source.attributes[key]: return _fail("vaelis_attribute_source_mismatch")
	var stat_sources := {"hpm":"HPM","acc":"ACC","at":"AT","mr":"MR_ft","dt":"DT","dp":"DP","init":"INIT","sb":"SB","hpb":"HPB","nal":"NAL","physical_soak":"PS","ss":"SS","rb":"RB"}
	for key: String in stat_sources:
		var values: Dictionary = record.resources if key == "hpm" else record.derived
		if source.combat_stats.get(key) != values.get(stat_sources[key]): return _fail("vaelis_derived_source_mismatch")
	if source.combat_stats.get("sr") != record.attributes.get("SR") or source.combat_stats.get("tb") != record.attributes.get("TB"): return _fail("vaelis_resistance_source_mismatch")
	if source.level != record.character.get("level") or source.resource_maxima.get("mana") != record.resources.get("mana_max") or source.resource_maxima.get("blood") != record.resources.get("BM") or record.resources.get("ability_points") != null: return _fail("vaelis_resource_source_mismatch")
	if record.resources.get("HPC") != record.resources.get("HPM") or record.resources.get("mana_current") != record.resources.get("mana_max") or record.resources.get("BC") != record.resources.get("BM"): return _fail("vaelis_initial_resource_state_requires_review")
	if source.progression_policy.get("initial_expm") != record.progression.get("EXPM") or source.progression_policy.get("initial_expc") != record.progression.get("EXPC") or source.progression_policy.get("exp_type") != record.character.get("experience_type") or not PrimeV3LevelCatalog.validate(source.progression_policy,actor).is_empty(): return _fail("vaelis_progression_source_mismatch")
	if record.character.get("classes") != source.progression_policy.get("classes") or record.character.get("sex") != "Female" or record.character.get("race") != "Elf": return _fail("vaelis_character_source_mismatch")
	var weapons: Variant = record.equipment.get("weapons")
	if not weapons is Array or weapons.size() != 2 or record.equipment.get("shield") != null: return _fail("vaelis_weapon_source_requires_review")
	var expected_weapons := [{"name":"Short Sword","hand":"Right","range_ft":2,"damage":"1d6+1+SB","type":"S/P"},{"name":"Short Wand","hand":"Left","range_ft":1,"damage":"1d4+SB","type":"B"}]
	for index in range(2):
		if not weapons[index] is Dictionary: return _fail("vaelis_weapon_source_requires_review")
		for key: String in expected_weapons[index]:
			if weapons[index].get(key) != expected_weapons[index][key]: return _fail("vaelis_weapon_source_requires_review")
	# Exact authored possessions. The inventory's Wand is explicitly the equipped
	# left-hand Wand, not a second grant. No mechanics are assigned to clothing/sheath.
	var inventory: Variant = record.equipment.get("inventory")
	if not inventory is Array or inventory.size() != 4 or record.resources.get("gold_gp") != 75: return _fail("vaelis_starter_inventory_requires_review")
	var expected := {"Short sword sheath":1,"Short wand":1,"Basic clothing":1,"Gold pieces":75}
	for row: Variant in inventory:
		if not row is Dictionary or not expected.has(row.get("name")) or row.get("quantity") != expected[row.name]: return _fail("vaelis_starter_inventory_requires_review")
		expected.erase(row.name)
	if not expected.is_empty(): return _fail("vaelis_starter_inventory_requires_review")
	if Array(loadout.equipment_refs()) != ["prime_v3_short_sword","prime_v3_short_wand"] or not loadout.inventory_records.is_empty(): return _fail("vaelis_loadout_requires_review")
	var quantities := {"prime_v3_gold":75,"vaelis_source_sword_sheath":1,"vaelis_source_basic_clothing":1}
	return {"success":true,"source":source.duplicate(true),"actor":actor,"loadout":loadout,"quantities":quantities,"authored_digest":Profiles.fingerprint(record),"source_ref":VAELIS_RECORD}

static func profile_identity(character: StringName, mode: String) -> Dictionary:
	if mode not in ["normal","dev_normal"]: return _fail("test_mode_nonpersistent")
	if character not in [Fixture.PLAYER_CHARACTER_GUARD,Fixture.PLAYER_CHARACTER_VAELIS]: return _fail("unsupported_playable_starter")
	var prefix := "prod_" if mode == "normal" else "dev_"
	return {"success":true,"profile_id":prefix+String(character),"profile_namespace":mode,"rules_revision":RULES}

static func prepare_starter(character: StringName, mode: String) -> Dictionary:
	var identity := profile_identity(character,mode)
	if not identity.success: return identity
	var verified := audit(character)
	if not verified.success: return verified
	var profile: String = identity.profile_id
	var source: CombatCharacterDefinitionResource = verified.source
	var actor: CombatActorDefinition = verified.actor
	var state := CombatActorState.new(actor)
	state.inventory_quantities = verified.quantities.duplicate(true)
	state.hand_occupancy = CombatWeaponHandling.initial_assignments(actor.equipment_refs,CombatDefinitionCatalog.load_default_fixture_catalog(),actor)
	state.hand_occupancy_authoritative = true
	var defense := Fixture.make_player_defense_profile(character)
	var ledger := ArenaRewardLedger.new()
	ledger.configure(mode,Fixture.PLAYER_ID,source.level)
	var items: Array = []
	for ref: String in actor.equipment_refs:
		var slots: Array = []
		for hand: String in ["left","right"]:
			if state.hand_occupancy[hand] == ref: slots.append(hand)
		items.append(_grant(profile,ref,1,slots,verified.authored_digest))
	for ref: String in verified.quantities:
		items.append(_grant(profile,ref,int(verified.quantities[ref]),[],verified.authored_digest))
	var lineage := {"profile_id":profile,"definition_id":String(source.definition_id),"rules_revision":RULES,"run_id":"starter_admission","mode_history":[mode],"baseline_digest":Profiles.fingerprint(source.to_dictionary())}
	var payload := {"character_id":profile,"definition_id":String(source.definition_id),"rules_revision":RULES,"generation":1,"base_attributes":source.attributes.duplicate(true),"xp":{"earned":0,"spent":0,"unspent":0},"purchases":[],"items":items,"secured_checkpoints":[],"lineage":lineage,"profile_namespace":mode,
		"permanent":{"level":source.level,"growth":[],"resource_maxima":actor.resource_maxima.duplicate(true),"ability_allowances":actor.ability_allowances.duplicate(true),"equipment_refs":Array(state.equipment_refs),"inventory_quantities":state.inventory_quantities.duplicate(true),"xp_baseline":{"expm":0,"expc":0,"earned":0,"spent":0},"award_receipts":[]}}
	var settlements: Array = []
	for item: Dictionary in items:
		var claim: String = item.definition_id
		settlements.append({"version":1,"receipt_id":"%s/starter_admission/starter/%s" % [profile,claim],"profile_id":profile,"run_id":"starter_admission","wave_id":"starter","claim_id":claim,"kind":"currency" if item.definition_id == "prime_v3_gold" else "item","content":{"instance_id":item.instance_id,"definition_id":item.definition_id,"quantity":item.quantity,"provenance_digest":Profiles.fingerprint(item.provenance)}})
	var prepared := Coordinator.prepare(payload,settlements,"starter_admission",0,[])
	if not prepared.success: return prepared
	var evidence := lineage.merged({"generation":1,"profile_namespace":mode,"items":items,"secured_checkpoints":[],"award_receipts":{},"purchase_ids":{},"growth_ids":{}})
	var source_binding := Profiles.fingerprint({"actor":actor.to_dictionary(),"state":state.to_dictionary(),"ledger":ledger.to_dictionary(),"defense":defense.to_dictionary()})
	var payload_hashes := [Profiles.fingerprint(payload),Profiles.fingerprint(prepared.prepared.payload)]
	var proposal_binding := Profiles.fingerprint(prepared.prepared)
	# This provider authorizes ONLY the independently built source starter. It
	# cannot attest a leveled fixture or a snapshot merely relabeled NORMAL.
	var authority := func(operation: String, binding: String) -> Dictionary:
		match operation:
			"project": return evidence.merged({"authorized":binding == source_binding,"binding":binding},true).duplicate(true)
			"hydrate": return {"authorized":payload_hashes.has(binding),"binding":binding,"lineage":lineage.duplicate(true)}
			"commit": return {"authorized":binding == proposal_binding,"binding":binding}
		return {"authorized":false}
	var projected := Profiles.project(source,actor,state,ledger.to_dictionary(),defense,authority)
	if not projected.get("success",false) or projected.payload != payload: return _fail("source_starter_projection_failed",projected)
	return {"success":true,"profile_id":profile,"profile_namespace":mode,"source":source,"actor":actor,"state":state,"ledger":ledger,"defense":defense,"items":items.duplicate(true),"prepared":prepared.prepared,"authority":authority,"playable_ready":false,"blocked_reason":"interrupted_wave_resource_checkpoint_and_instance_application_unavailable"}

static func _grant(profile: String, definition: String, quantity: int, slots: Array, authored_digest: String) -> Dictionary:
	return {"instance_id":"%s/starter/%s" % [profile,definition],"definition_id":definition,"quantity":quantity,"provenance":{"origin_id":"%s/starter/%s" % [profile,definition],"source_ref":VAELIS_RECORD+"#"+authored_digest},"equipped_slots":slots.duplicate(),"mutable_state":{}}

static func _fail(reason: String, details: Dictionary = {}) -> Dictionary:
	return {"success":false,"reason":reason,"details":details}
