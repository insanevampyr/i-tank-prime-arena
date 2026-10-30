extends RefCounted

const ProfileAdapter = preload("res://scripts/rewards/character_profile_projection.gd")
const Contract = preload("res://scripts/rewards/character_save_contract.gd")
var _failures: Array[String] = []

func run() -> Array[String]:
	var f := _fixture()
	var sim: CombatSimulation = f.sim
	var before := sim.get_state_snapshot()
	var actor: CombatActorDefinition = sim.get_actor_definition(&"player")
	var state := sim.get_actor_state(&"player")
	var projected := ProfileAdapter.project(f.source,actor,state,f.ledger.to_dictionary(),f.defense,f.verifier)
	_expect(projected.get("success",false),"Leveled source must project: %s" % projected)
	if not projected.get("success",false): return _failures
	var payload: Dictionary = projected.payload
	var decoded := Contract.decode(projected.text)
	_expect(decoded.get("success",false) and decoded.get("version") == 2 and decoded.get("payload") == payload,"V2 canonical JSON must roundtrip exactly: %s" % decoded)
	if not decoded.get("success",false): return _failures
	_expect(Contract.encode(payload).text == projected.text,"Repeated encoding is canonical.")
	var candidate := ProfileAdapter.hydrate(decoded.payload,f.source,"profile_a","rules_test",f.verifier)
	_expect(candidate.get("success",false),"Complete profile must hydrate: %s" % candidate)
	if candidate.get("success",false):
		_expect(candidate.actor_definition.to_dictionary() == f.expected_actor,"Permanent actor statistics must reconstruct exactly.")
		_expect(candidate.permanent.growth == payload.permanent.growth and candidate.items == payload.items,"Recorded rolls, provenance and original instances must survive.")
		_expect(candidate.permanent.growth.size() == state.progression.history.size(),"Every original growth record must be represented.")
		for index in range(candidate.permanent.growth.size()):
			for field: String in ProfileAdapter.HISTORY_FIELDS:
				_expect(candidate.permanent.growth[index][field] == state.progression.history[index][field],"Original historical growth input/output must survive: %s." % field)
		_expect(candidate.xp == {"earned":5050,"spent":2010,"unspent":3040},"Nonzero initial EXPM 50 / EXPC 40 and 2000-XP purchase must not double count.")
		_expect(candidate.shield_blocks.prime_v3_metal_buckler.current_shp == 7,"Damaged shield must retain SHP, not refill.")
		for key in ["current_hpc","resources","ability_daily_remaining","position_microfeet","current_action_instance_id","rng"]:
			_expect(not candidate.has(key) and not candidate.permanent.has(key),"Hydration must not initialize temporary %s." % key)
	_expect(sim.get_state_snapshot() == before,"ProfileAdapter/hydration must not mutate authority, RNG, events or resources.")
	_expect(not ProfileAdapter.project(f.source,actor,state,f.ledger.to_dictionary(),f.defense).get("success",false),"Current live model without lineage port must fail closed.")
	_expect(not ProfileAdapter.hydrate(payload,f.source,"profile_b","rules_test",f.verifier).get("success",false),"A profile cannot hydrate into another character identity.")
	for mode in ["test","dev_normal"]:
		var tainted := _fixture([mode,"normal"])
		var rejected := ProfileAdapter.project(tainted.source,tainted.sim.get_actor_definition(&"player"),tainted.sim.get_actor_state(&"player"),tainted.ledger.to_dictionary(),tainted.defense,tainted.verifier)
		_expect(not rejected.get("success",false),"Changing current mode cannot cleanse %s lineage." % mode)
	_test_invalid(payload,f)
	var legacy: Dictionary = preload("res://tests/test_task_36d_character_save_contract.gd").new()._fixture()
	_expect(Contract.decode(Contract.encode(legacy).text).get("success",false),"V1 saves remain readable without changing their shape.")
	_expect(ProfileAdapter.hydrate(legacy,f.source,"profile_a","rules_test",f.verifier).get("reason") == "v1_lossless_migration_requires_missing_history","V1 missing growth cannot be guessed into v2.")
	var prior := legacy.duplicate(true)
	prior.character_id = payload.character_id
	prior.definition_id = payload.definition_id
	prior.rules_revision = payload.rules_revision
	var upgrade := payload.duplicate(true)
	upgrade.generation = prior.generation+1
	_expect(Contract.validate_replacement(prior,upgrade).get("reason") == "profile_version_transition_requires_verified_migration","Storage replacement must not implicitly migrate v1 profiles.")
	var envelope: Dictionary = JSON.parse_string(projected.text)
	envelope.version = 3
	_expect(not Contract.decode(JSON.stringify(envelope)).get("success",false),"Future schema must fail closed.")
	var harness := TwoClientSyncHarness.new(36001)
	harness.authority.simulation = sim
	harness.deliver_in_order(harness.authority.publish_current_events())
	_expect(before.schema_version == 12 and harness.compare_clients().get("success",false) and harness.client_a.get_state_snapshot() == before,"Pure translation must preserve schema-12 convergence.")
	var replay := _fixture()
	_expect(replay.sim.get_state_snapshot() == before,"Ordinary source simulation must replay unchanged.")
	return _failures

func _fixture(modes: Array = ["normal"]) -> Dictionary:
	# Explicit isolated test baseline, NOT a new production Vaelis profile.
	var source: CombatCharacterDefinitionResource = (load("res://data/characters/vaelis_thorn.tres") as Resource).duplicate(true)
	source.progression_policy.initial_expm = 50
	source.progression_policy.initial_expc = 40
	var refs := PackedStringArray(["prime_v3_short_sword","prime_v3_metal_buckler","prime_v3_leather_torso"])
	var actor: CombatActorDefinition = source.instantiate_actor(&"player",source.display_name,refs)
	var catalog := CombatDefinitionCatalog.load_default_fixture_catalog()
	actor.apply_equipment_stat_modifiers(catalog.calculate_armor_stat_modifiers(refs).modifiers)
	var sim := CombatSimulation.new(36001)
	sim.register_actor(actor)
	var state := sim.get_actor_state(&"player")
	state.hand_occupancy = CombatWeaponHandling.initial_assignments(refs,catalog,actor)
	state.hand_occupancy_authoritative = true
	state.inventory_quantities = {"prime_v3_gold":6,"health_potion":2}
	state.current_hpc = 3
	state.resources.mana = 1
	state.conditions.append("prone")
	var leveled := sim.apply_character_experience_award(&"player","fixture_award",5000,5000,0)
	assert(leveled.get("success",false))
	var ledger := ArenaRewardLedger.new()
	ledger.configure("normal",&"player",1)
	ledger.earned_xp = 5000
	var purchase := ledger.purchase_advancement(sim,"request:sr",&"special_resistance",&"sr")
	assert(purchase.get("success",false))
	var block: CombatBlockDefinition = catalog.get_shield(&"prime_v3_metal_buckler").make_block_definition()
	block.current_shp = 7
	var defense := CombatDefenseProfile.new(&"isolated_profile",PackedStringArray(["dodge","weapon_block","shield_block","physical_soak"]),{},null,block)
	sim.register_defense_profile(&"player",defense)
	var items: Array = []
	# These identities are supplied by the isolated authority, not minted by projection.
	var index := 0
	for ref: String in refs:
		var slots: Array = ["right"] if ref == "prime_v3_short_sword" else (["shield"] if ref == "prime_v3_metal_buckler" else ["armor:torso"])
		items.append({"instance_id":"original_instance_%s" % index,"definition_id":ref,"quantity":1,"provenance":{"origin_id":"original_source_%s" % index,"source_ref":"isolated fixture"},"equipped_slots":slots,"mutable_state":{"shp":7,"usable":true} if ref == "prime_v3_metal_buckler" else {}})
		index += 1
	for ref: String in ["prime_v3_gold","health_potion"]:
		items.append({"instance_id":"carried_"+ref,"definition_id":ref,"quantity":state.inventory_quantities[ref],"provenance":{"origin_id":"isolated_reward_"+ref,"source_ref":"isolated fixture"},"equipped_slots":[],"mutable_state":{}})
	var evidence := {"profile_id":"profile_a","definition_id":String(source.definition_id),"rules_revision":"rules_test","run_id":"run_a","generation":1,"mode_history":modes.duplicate(),"baseline_digest":ProfileAdapter.fingerprint(source.to_dictionary()),"items":items,"purchase_ids":{"request:sr":"profile_a/run_a/purchase_sr"},"growth_ids":{},"secured_checkpoints":[]}
	evidence["award_receipts"] = {"fixture_award":{"award_id":"profile_a/run_a/xp_award","xp":5000}}
	for record: Dictionary in state.progression.history:
		evidence.growth_ids["%s:%s" % [record.award_id,record.level]] = "profile_a/run_a/growth_%s" % record.level
	var source_binding := ProfileAdapter.fingerprint({"actor":actor.to_dictionary(),"state":state.to_dictionary(),"ledger":ledger.to_dictionary(),"defense":defense.to_dictionary()})
	var lineage := {}
	for field: String in ProfileAdapter.LINEAGE_FIELDS: lineage[field] = evidence[field]
	var verifier := func(operation: String, binding: String) -> Dictionary:
		if operation == "project": return evidence.merged({"authorized":binding == source_binding,"binding":binding})
		return {"authorized":true,"binding":binding,"lineage":lineage.duplicate(true)}
	var expected_actor := actor.to_dictionary()
	expected_actor.actor_id = "profile_candidate"
	return {"sim":sim,"ledger":ledger,"source":source,"defense":defense,"verifier":verifier,"expected_actor":expected_actor}

func _test_invalid(payload: Dictionary, f: Dictionary) -> void:
	var before: Dictionary = f.sim.get_state_snapshot()
	var mutations: Array[Dictionary] = []
	var bad := payload.duplicate(true)
	bad.items.append(bad.items[0].duplicate(true)); mutations.append(bad)
	bad = payload.duplicate(true); bad.permanent.inventory_quantities.health_potion += 1; mutations.append(bad)
	bad = payload.duplicate(true); bad.items[1].mutable_state.shp = 99999; mutations.append(bad)
	bad = payload.duplicate(true); bad.permanent.growth[0].roll += 1; mutations.append(bad)
	bad = payload.duplicate(true); bad.purchases[0].cost = 1; mutations.append(bad)
	bad = payload.duplicate(true); bad.permanent.resource_maxima.mana = -1; mutations.append(bad)
	bad = payload.duplicate(true); bad.permanent.current_hpc = 99; mutations.append(bad)
	bad = payload.duplicate(true); bad.permanent.ability_allowances = {"invented_ability":1}; mutations.append(bad)
	bad = payload.duplicate(true); bad.definition_id = "wrong_character"; mutations.append(bad)
	bad = payload.duplicate(true); bad.rules_revision = "wrong_rules"; mutations.append(bad)
	bad = payload.duplicate(true); bad.lineage.mode_history = ["test","normal"]; mutations.append(bad)
	bad = payload.duplicate(true); bad.purchases[0].purchase_id = "request:sr"; mutations.append(bad)
	bad = payload.duplicate(true); bad.permanent.award_receipts.append(bad.permanent.award_receipts[0].duplicate(true)); mutations.append(bad)
	bad = payload.duplicate(true); bad.permanent.award_receipts[0].xp += 1; mutations.append(bad)
	bad = payload.duplicate(true); bad.purchases[0].purchase_kind = {}; mutations.append(bad)
	for record: Dictionary in mutations:
		var rejected := ProfileAdapter.hydrate(record,f.source,"profile_a","rules_test",f.verifier)
		_expect(not rejected.get("success",false) and not rejected.has("actor_definition"),"Invalid record must not partially hydrate: %s" % record)
	_expect(f.sim.get_state_snapshot() == before,"All invalid hydrations must leave live source untouched.")
	var state: CombatActorState = f.sim.get_actor_state(&"player")
	state.inventory_quantities.health_potion += 1
	_expect(not ProfileAdapter.project(f.source,f.sim.get_actor_definition(&"player"),state,f.ledger.to_dictionary(),f.defense,f.verifier).get("success",false),"Stale ownership evidence must reject changed source.")
	state.inventory_quantities.health_potion -= 1

func _expect(value: bool, message: String) -> void:
	if not value: _failures.append(message)
