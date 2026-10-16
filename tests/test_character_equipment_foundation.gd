extends RefCounted

const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
const Digest = preload("res://scripts/sync/sync_state_digest.gd")

var _failures: Array[String] = []


func run() -> Array[String]:
	_failures.clear()
	_test_definition_loading_and_verified_values()
	_test_task23_catalog_expansion()
	_test_reference_validation_and_distinct_statuses()
	_test_independent_runtime_instances()
	_test_fixture_migration_and_deterministic_replay()
	_test_opponent_activation_condition()
	_test_hazard_and_wall_authority()
	_test_scene_and_floating_feedback_compatibility()
	return _failures


func _test_definition_loading_and_verified_values() -> void:
	var catalog := CombatDefinitionCatalog.load_default_fixture_catalog()
	var validation := catalog.validate_character_loadout(Fixture.CHARACTER_DEFINITION_ID, Fixture.LOADOUT_DEFINITION_ID)
	_expect_true(validation.get("success", false), "The source-backed Guard catalog and assembled loadout must load without invalid issues.")
	var character: CombatCharacterDefinitionResource = catalog.characters[String(Fixture.CHARACTER_DEFINITION_ID)]
	var weapon := catalog.get_weapon(Fixture.WEAPON_REF)
	var shield := catalog.get_shield(Fixture.SHIELD_REF)
	var armor := catalog.get_armor(Fixture.ARMOR_REF)
	_expect_equal(character.attributes, {"str": 16, "end": 10, "spd": 12, "dex": 14, "wis": 8, "int": 5, "wit": 8, "man": 12, "luk": 1, "app": 8}, "Guard attributes must match the frozen verified fixture.")
	_expect_equal(character.combat_stats, {"hpm": 100, "acc": 12, "at": 2, "init": 4, "mr": 12, "nal": 1, "dt": 8, "dp": 6, "physical_soak": 4, "rb": 0, "sb": 4}, "Guard derived combat values must match the frozen verified fixture.")
	_expect_true(weapon != null and weapon.damage_dice_count == 2 and weapon.damage_die_sides == 10 and weapon.fixed_damage_bonus == 3 and weapon.strength_bonus_eligible, "Battle Axe must remain 2d10 + 3 + eligible SB.")
	_expect_true(weapon.reach_microfeet == 3_000_000 and weapon.block_target == 2 and weapon.critical_success_max_natural == 2 and weapon.approach_attack_eligible, "Battle Axe reach, Block, critical range and Arena approach policy must remain explicit.")
	_expect_true(shield != null and shield.maximum_shp == 20 and shield.block_target == 2 and shield.two_hands_free, "Metal Buckler definition must retain SHP, Block and two-hands-free facts.")
	_expect_true(armor != null and armor.covered_locations == PackedStringArray(["torso"]) and armor.tal_by_damage_type == {"bashing": 3, "slashing": 3, "piercing": 3}, "Plate torso definition must retain location-specific B/S/P TAL 3.")
	var attack: CombatAttackDefinition = weapon.make_attack_definition(Fixture.ATTACK_ID)
	_expect_true(attack.physical_damage.dice_count == 2 and attack.physical_damage.die_sides == 10 and attack.physical_damage.flat_bonus == 3, "Catalog weapon conversion must supply the existing physical-damage transaction exactly.")
	_expect_true(attack.physical_damage.rounding_policy == CombatPhysicalDamageDefinition.ROUNDING_FLOOR, "Catalog weapon conversion must retain exact multiplier product and one floor before TAL/NAL.")


func _test_task23_catalog_expansion() -> void:
	var catalog := CombatDefinitionCatalog.load_default_fixture_catalog()
	var short_rod := catalog.get_weapon(&"prime_v3_short_rod")
	var great_sword := catalog.get_weapon(&"prime_v3_great_sword")
	var long_staff := catalog.get_weapon(&"prime_v3_long_staff")
	var wood_buckler := catalog.get_shield(&"prime_v3_wood_buckler")
	var leather_torso := catalog.get_armor(&"prime_v3_leather_torso")
	var leather_head := catalog.get_armor(&"prime_v3_leather_head")
	_expect_true(short_rod != null and short_rod.source_refs.has("PRIME-V3 p. 131, Short Rod"), "Short Rod must retain direct Prime page provenance.")
	_expect_true(short_rod.damage_dice_count == 1 and short_rod.damage_die_sides == 6 and short_rod.fixed_damage_bonus == 2 and short_rod.reach_microfeet == 2_000_000 and short_rod.strength_requirement == 4 and short_rod.block_target == 1, "Short Rod source data must preserve its verified damage, reach, STR and Block values.")
	_expect_true(short_rod.combat_ready and short_rod.make_attack_definition(&"task23_short_rod") != null, "A fully represented Short Rod must be eligible for the existing in-reach physical pipeline.")
	_expect_true(great_sword != null and great_sword.source_refs.has("PRIME-V3 p. 126, Great Sword"), "Great Sword must retain direct Prime page provenance.")
	_expect_true(great_sword.damage_dice_count == 2 and great_sword.damage_die_sides == 6 and great_sword.fixed_damage_bonus == 2 and great_sword.reach_microfeet == 4_000_000 and great_sword.strength_requirement == 10 and great_sword.one_hand_strength_requirement == 20 and great_sword.block_target == 2 and great_sword.critical_success_max_natural == 2, "Great Sword data must preserve every verified Task 23 field.")
	_expect_true(_has_issue(great_sword.validate_definition(), "not_yet_implemented", "weapon_not_combat_ready") and great_sword.make_attack_definition(&"task23_great_sword") == null, "Two-handed Great Sword handling must fail closed until occupancy is implemented.")
	_expect_true(long_staff != null and long_staff.source_refs.has("PRIME-V3 p. 131, Long Staff"), "Long Staff must retain direct Prime page provenance.")
	_expect_true(long_staff.damage_dice_count == 1 and long_staff.damage_die_sides == 6 and long_staff.fixed_damage_bonus == 2 and long_staff.reach_microfeet == 8_000_000 and long_staff.strength_requirement == 4 and long_staff.block_target == 2, "Long Staff data must preserve its verified damage, reach, STR and Block values.")
	_expect_true(_has_issue(long_staff.validate_definition(), "not_yet_implemented", "weapon_not_combat_ready") and long_staff.make_attack_definition(&"task23_long_staff") == null, "Two-handed Long Staff handling must fail closed until occupancy is implemented.")
	_expect_true(wood_buckler != null and wood_buckler.source_refs.has("PRIME-V3 p. 137, Shield Chart, Wood Buckler") and wood_buckler.strength_requirement == 7 and wood_buckler.block_target == 2 and wood_buckler.maximum_shp == 10 and wood_buckler.two_hands_free, "Wood Buckler data must preserve verified requirements, Block, SHP and two-hands-free status.")
	_expect_true(leather_torso != null and leather_torso.source_refs.has("PRIME-V3 p. 135, Armor Chart, Leather torso") and leather_torso.covered_locations == PackedStringArray(["torso"]) and leather_torso.tal_by_damage_type == {"slashing": 1} and leather_torso.strength_requirement == 7, "Leather torso data must preserve verified slashing TAL, torso coverage and STR requirement.")
	_expect_true(leather_head != null and leather_head.source_refs.has("PRIME-V3 p. 135, Armor Chart, Leather head") and leather_head.covered_locations == PackedStringArray(["head", "neck"]) and leather_head.tal_by_damage_type == {"slashing": 1} and leather_head.strength_requirement == 2, "Leather head data must preserve Prime TAL plus the existing approved head/neck mapping.")
	_expect_true(leather_torso.validate_definition().is_empty() and leather_head.validate_definition().is_empty(), "Zero-penalty leather definitions must be immediately usable by the existing armor schema.")
	var understrength_guard: CombatCharacterDefinitionResource = (catalog.characters[String(Fixture.CHARACTER_DEFINITION_ID)] as CombatCharacterDefinitionResource).duplicate(true)
	understrength_guard.definition_id = &"task23_understrength_guard"
	understrength_guard.display_name = "Task 23 Understrength Guard"
	understrength_guard.attributes = understrength_guard.attributes.duplicate(true)
	understrength_guard.attributes["str"] = 3
	var understrength_loadout := CombatLoadoutDefinitionResource.new()
	understrength_loadout.definition_id = &"task23_short_rod_loadout"
	understrength_loadout.display_name = "Task 23 Short Rod Loadout"
	understrength_loadout.primary_weapon_ref = &"prime_v3_short_rod"
	understrength_loadout.source_refs = PackedStringArray(["Task 23 validation fixture"])
	catalog.register_character(understrength_guard)
	catalog.register_loadout(understrength_loadout)
	var understrength_validation := catalog.validate_character_loadout(understrength_guard.definition_id, understrength_loadout.definition_id)
	_expect_true(not understrength_validation.get("success", true) and _has_issue(understrength_validation.get("issues", []), "invalid", "equipment_strength_requirement_not_met"), "An equipped weapon must fail closed when the character does not meet its verified STR requirement.")


func _test_reference_validation_and_distinct_statuses() -> void:
	var missing_catalog := CombatDefinitionCatalog.new()
	var missing := missing_catalog.validate_character_loadout(&"missing_character", &"missing_loadout")
	_expect_equal(missing["status"], "invalid", "Missing definitions must report invalid, not crash or masquerade as unverified.")
	var catalog := CombatDefinitionCatalog.load_default_fixture_catalog()
	var duplicate: CombatWeaponDefinitionResource = load(CombatDefinitionCatalog.DEFAULT_WEAPON_PATH)
	var duplicate_result := catalog.register_weapon(duplicate)
	_expect_true(not duplicate_result.get("success", true) and duplicate_result["issue"]["code"] == "duplicate_definition_identifier", "Duplicate identifiers must fail closed with a precise diagnostic.")
	var invalid_weapon := CombatWeaponDefinitionResource.new()
	invalid_weapon.definition_id = &"invalid_weapon"
	invalid_weapon.display_name = "Invalid weapon"
	var invalid_issues := invalid_weapon.validate_definition()
	_expect_true(_has_issue(invalid_issues, "invalid", "invalid_weapon_damage_dice"), "Malformed numeric weapon data must be invalid.")
	_expect_true(_has_issue(invalid_issues, "requires_source_verification", "weapon_strength_requirement_unresolved"), "A missing verified prerequisite must remain a source-verification status.")
	var armor := CombatArmorDefinitionResource.new()
	armor.definition_id = &"unsupported_armor"
	armor.display_name = "Unsupported armor"
	armor.armor_slot = &"torso"
	armor.covered_locations = PackedStringArray(["torso"])
	armor.tal_by_damage_type = {"energy": 2}
	armor.strength_requirement = 1
	_expect_true(_has_issue(armor.validate_definition(), "not_yet_implemented", "unsupported_armor_damage_type"), "Unsupported capabilities must remain distinct from invalid data and missing verification.")


func _test_independent_runtime_instances() -> void:
	var catalog := CombatDefinitionCatalog.load_default_fixture_catalog()
	var first_result := catalog.instantiate_actor(Fixture.CHARACTER_DEFINITION_ID, Fixture.LOADOUT_DEFINITION_ID, &"first", "First")
	var second_result := catalog.instantiate_actor(Fixture.CHARACTER_DEFINITION_ID, Fixture.LOADOUT_DEFINITION_ID, &"second", "Second")
	var first: CombatActorDefinition = first_result["actor"]
	var second: CombatActorDefinition = second_result["actor"]
	first.attributes["str"] = 99
	var first_state := CombatActorState.new(first)
	var second_state := CombatActorState.new(second)
	first_state.current_hpc = 1
	first_state.equipment_refs.remove_at(0)
	_expect_equal(second.attributes["str"], 16, "Character instances must deep-copy template attributes.")
	_expect_equal(second_state.current_hpc, 100, "Mutable HPC must live only in the actor state instance.")
	_expect_equal(second_state.equipment_refs.size(), 3, "Mutable equipment state must not leak between actor instances.")
	var first_shield: CombatBlockDefinition = catalog.get_shield(Fixture.SHIELD_REF).make_block_definition()
	var second_shield: CombatBlockDefinition = catalog.get_shield(Fixture.SHIELD_REF).make_block_definition()
	first_shield.current_shp = 0
	_expect_equal(second_shield.current_shp, 20, "Equipped shield instances must not share mutable SHP.")


func _test_fixture_migration_and_deterministic_replay() -> void:
	var actor := Fixture.make_guard_actor(&"legacy_compare", "Legacy Compare")
	_expect_equal(actor.attributes["str"], 16, "Migrated fixture must still resolve Guard STR 16.")
	_expect_equal(actor.get_combat_stat("at"), 2, "Migrated fixture must still resolve AT 2.")
	_expect_equal(actor.equipment_refs, PackedStringArray([String(Fixture.WEAPON_REF), String(Fixture.SHIELD_REF), String(Fixture.ARMOR_REF)]), "Migrated fixture must retain the same equipment reference order.")
	var legacy := _build_frozen_legacy_simulation(22022)
	var migrated := CombatSimulation.new(22022)
	Fixture.configure_simulation(migrated, Vector2i(20_000_000, 12_000_000), Vector2i(23_000_000, 12_000_000))
	_run_two_actor_exchange(legacy, _make_frozen_legacy_attack())
	_run_two_actor_exchange(migrated, Fixture.make_attack_definition())
	_expect_equal(_simulation_event_signature(legacy), _simulation_event_signature(migrated), "The resource-backed fixture must preserve the frozen legacy event order, rolls and outcomes for the same seed, inputs and timestamps.")
	for actor_id: StringName in [Fixture.PLAYER_ID, Fixture.OPPONENT_ID]:
		_expect_equal(legacy.get_actor_state(actor_id).to_dictionary(), migrated.get_actor_state(actor_id).to_dictionary(), "The migrated runtime actor state must equal the frozen legacy state after the same exchange.")
	var sessions: Array[ArenaCombatSession] = []
	for _index in range(2):
		var session := ArenaCombatSession.new(22022)
		session.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
		_expect_true(session.initialize(Vector2i(20_000_000, 12_000_000), Vector2i(23_000_000, 12_000_000)).get("success", false), "Migrated fixture must initialize through the authoritative session.")
		session.set_opponent_behavior_enabled(true)
		if int(session.get_actor_state(Fixture.PLAYER_ID).opening_order_rank) == 0:
			session.request_player_attack("migration_equivalence")
		session.advance_by(3_000_000)
		sessions.append(session)
	_expect_equal(Digest.compute(sessions[0].get_state_snapshot()), Digest.compute(sessions[1].get_state_snapshot()), "Same seed, definitions, timing and input must reproduce the migrated authoritative snapshot.")
	_expect_equal(_event_signature(sessions[0]), _event_signature(sessions[1]), "Same-seed migrated event ordering and outcomes must be reproducible.")


func _test_opponent_activation_condition() -> void:
	var player_first: ArenaCombatSession = null
	for seed_value in range(1, 500):
		var candidate := ArenaCombatSession.new(seed_value)
		candidate.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
		candidate.set_opponent_behavior_enabled(true)
		candidate.initialize(Vector2i(20_000_000, 12_000_000), Vector2i(23_000_000, 12_000_000), false)
		if int(candidate.get_actor_state(Fixture.PLAYER_ID).opening_order_rank) == 0 and int(candidate.get_actor_state(Fixture.OPPONENT_ID).opening_order_rank) > 0:
			player_first = candidate
			break
	_expect_true(player_first != null, "A deterministic player-first opening fixture must exist.")
	if player_first == null: return
	_expect_equal(player_first.get_opponent_behavior_status(), "idle", "Before START, the enabled opponent driver must remain prepared but inactive.")
	player_first.start_encounter()
	_expect_equal(player_first.get_opponent_behavior_status(), "blocked_opening_initiative_wait", "After START, a lower-ranked opponent must wait only for the player's opening declaration.")
	player_first.request_player_attack("unlock_opponent")
	_expect_true(player_first.is_opponent_attack_in_flight(), "The opponent must declare immediately at the same simulation time once the higher opening rank declares.")


func _test_hazard_and_wall_authority() -> void:
	var battlefield := ArenaBattlefield.create_task16_test_arena()
	var hazard_start := Vector2i(6_000_000, 21_000_000)
	var hazard_end := Vector2i(13_000_000, 21_000_000)
	var occupancy := {"player": hazard_start, "opponent": Vector2i(40_000_000, 5_000_000)}
	var hazard_motion := battlefield.resolve_motion(&"player", hazard_start, hazard_end, occupancy)
	_expect_true(hazard_motion.get("success", false) and not hazard_motion.get("blocked", true), "The brown/orange test zone must remain walkable.")
	_expect_true(battlefield.has_line_of_sight(hazard_start, hazard_end), "The brown/orange zone must not block line of sight.")
	_expect_equal(hazard_motion["movement_cost_microfeet"], 7_000_000, "The brown/orange zone must not add movement or MR cost.")
	_expect_equal(battlefield.get_hazard_tier(Vector2i(9_000_000, 21_000_000)), 1, "The brown/orange zone must influence only the authored Dodge hazard tier.")
	var wall_center := Vector2i(30_000_000, 12_000_000)
	_expect_equal(battlefield.is_position_legal(&"player", wall_center, occupancy)["reason"], "blocked_by_obstacle", "The gray wall must reject actor occupancy.")
	_expect_true(not battlefield.has_line_of_sight(Vector2i(27_000_000, 12_000_000), Vector2i(33_000_000, 12_000_000)), "The gray wall must block line of sight.")


func _test_scene_and_floating_feedback_compatibility() -> void:
	var packed: PackedScene = load("res://scenes/test_arena.tscn")
	var scene := packed.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		_failures.append("SceneTree unavailable for Task 22 scene compatibility test.")
		scene.free()
		return
	tree.root.add_child(scene)
	var view: ArenaBattlefieldView = scene.get_node("Battlefield")
	var legend := view.get_geometry_legend_for_testing()
	_expect_true(String(legend["center_wall"]).contains("blocks movement") and String(legend["non_damaging_test_hazard_zone"]).contains("walkable"), "The arena presentation must explicitly distinguish the wall from the walkable Dodge test zone.")
	var layer: ArenaFloatingCombatText = scene.get_node("FloatingCombatText")
	layer.present_authoritative_event(CombatEvent.new("task22_damage", 1, 1, 1, &"physical_damage_resolved", Fixture.PLAYER_ID, Fixture.OPPONENT_ID, "", PackedStringArray(), {"final_damage": 8, "hpc_after": 92}, {}))
	_expect_true(layer.get_active_messages_for_testing().size() == 1 and layer.get_active_messages_for_testing()[0]["actor_id"] == Fixture.OPPONENT_ID, "Definition-backed actor IDs must remain compatible with Task 21 authoritative floating feedback.")
	scene.free()


func _event_signature(session: ArenaCombatSession) -> Array[Dictionary]:
	var signature: Array[Dictionary] = []
	for event: CombatEvent in session.get_resolved_events():
		signature.append({"timestamp_us": event.timestamp_us, "event_type": String(event.event_type), "source": String(event.source_actor_id), "target": String(event.target_actor_id), "payload": event.payload.duplicate(true)})
	return signature


func _simulation_event_signature(simulation: CombatSimulation) -> Array[Dictionary]:
	var signature: Array[Dictionary] = []
	for event: CombatEvent in simulation.get_resolved_events():
		signature.append({"timestamp_us": event.timestamp_us, "event_type": String(event.event_type), "source": String(event.source_actor_id), "target": String(event.target_actor_id), "payload": event.payload.duplicate(true)})
	return signature


func _build_frozen_legacy_simulation(seed_value: int) -> CombatSimulation:
	var simulation := CombatSimulation.new(seed_value)
	var attack := _make_frozen_legacy_attack()
	for actor_id: StringName in [Fixture.PLAYER_ID, Fixture.OPPONENT_ID]:
		var actor := CombatActorDefinition.new(
			actor_id, &"prime_v3_verified_vertical_slice_fixture", String(actor_id),
			{"str": 16, "end": 10, "spd": 12, "dex": 14, "wis": 8, "int": 5, "wit": 8, "man": 12, "luk": 1, "app": 8},
			{"hpm": 100, "acc": 12, "at": 2, "init": 4, "mr": 12, "nal": 1, "dt": 8, "dp": 6, "physical_soak": 4, "rb": 0, "sb": 4},
			{}, PackedStringArray([String(Fixture.WEAPON_REF), String(Fixture.SHIELD_REF), String(Fixture.ARMOR_REF)]),
			{"dodge": true, "weapon_block": true, "shield_block": true, "physical_soak": true}
		)
		simulation.register_actor(actor)
		simulation.register_defense_profile(actor_id, CombatDefenseProfile.new(
			StringName("task14_%s_defenses" % String(actor_id)),
			PackedStringArray(["dodge", "weapon_block", "shield_block", "physical_soak"]), {},
			CombatBlockDefinition.new(CombatBlockDefinition.TYPE_WEAPON, Fixture.WEAPON_REF, 2, 0, true, true),
			CombatBlockDefinition.new(CombatBlockDefinition.TYPE_SHIELD, Fixture.SHIELD_REF, 2, 0, true, true, 20)
		))
		simulation.register_damage_protection_profile(actor_id, CombatDamageProtectionProfile.new(
			StringName("task14_%s_protection" % String(actor_id)),
			[CombatArmorDefinition.new(Fixture.ARMOR_REF, &"torso", PackedStringArray(["torso"]), {"bashing": 3, "slashing": 3, "piercing": 3})]
		))
		simulation.register_critical_reaction_attack(actor_id, attack, true)
	simulation.apply_authoritative_position(Fixture.PLAYER_ID, Vector2i(20_000_000, 12_000_000), 0)
	simulation.apply_authoritative_position(Fixture.OPPONENT_ID, Vector2i(23_000_000, 12_000_000), 180_000)
	simulation.begin_combat()
	return simulation


func _make_frozen_legacy_attack() -> CombatAttackDefinition:
	var damage := CombatPhysicalDamageDefinition.new(2, 10, 3, true, true, {"torso": {"numerator": 1, "denominator": 1, "source_ref": "legacy"}}, null, true, CombatPhysicalDamageDefinition.ROUNDING_FLOOR)
	var critical := CombatCriticalTriggerPolicy.new(&"prime_v3_battle_axe_critical_range", 2, 0, 20)
	return CombatAttackDefinition.new(Fixture.ATTACK_ID, Fixture.WEAPON_REF, 1, true, true, 0, {"torso": 0}, PackedStringArray(["torso"]), 0, 3_000_000, true, PackedStringArray(), &"hand_held", PackedStringArray(["slashing"]), true, CombatAttackDefinition.DUCKING_UNRESOLVED, damage, critical, true)


func _run_two_actor_exchange(simulation: CombatSimulation, attack: CombatAttackDefinition) -> void:
	var actors: Array[StringName] = [Fixture.PLAYER_ID, Fixture.OPPONENT_ID]
	actors.sort_custom(func(left: StringName, right: StringName) -> bool:
		return int(simulation.get_actor_state(left).opening_order_rank) < int(simulation.get_actor_state(right).opening_order_rank)
	)
	for actor_id: StringName in actors:
		var target_id := Fixture.OPPONENT_ID if actor_id == Fixture.PLAYER_ID else Fixture.PLAYER_ID
		simulation.start_physical_attack(actor_id, target_id, attack, "migration_%s" % String(actor_id), &"torso", true)
	simulation.advance_to(2_500_000)


func _has_issue(issues: Array[Dictionary], status: String, code: String) -> bool:
	for issue: Dictionary in issues:
		if issue.get("status") == status and issue.get("code") == code: return true
	return false


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected: _failures.append("%s Expected %s, got %s." % [message, str(expected), str(actual)])


func _expect_true(value: bool, message: String) -> void:
	if not value: _failures.append(message)
