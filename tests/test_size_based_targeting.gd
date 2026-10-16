extends RefCounted

const HitLocations = preload("res://scripts/combat/combat_hit_location_catalog.gd")
const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
const TwoClientSyncHarness = preload("res://scripts/sync/two_client_sync_harness.gd")

var _failures: Array[String] = []


func run() -> Array[String]:
	_failures.clear()
	_test_all_non_tiny_directional_profiles()
	_test_same_size_and_location_boundaries()
	_test_tiny_exception()
	_test_actor_size_validation_and_fail_closed_resolution()
	_test_authoritative_modifier_locking_and_replay()
	_test_two_client_convergence()
	return _failures


func _test_all_non_tiny_directional_profiles() -> void:
	var expected := {
		"small_to_medium": [-4, -6, -1, -2, -3, -2, 0, 0, 0],
		"small_to_large": [-5, -7, -2, -3, -4, -3, -1, 0, 0],
		"small_to_extra_large": [-6, -8, -3, -4, -5, -4, -2, -1, 0],
		"small_to_gigantic": [-7, -9, -4, -5, -6, -5, -3, -2, -1],
		"small_to_enormous": [-8, -10, -5, -6, -7, -6, -4, -3, -2],
		"medium_to_small": [0, -1, -3, -2, -3, -4, -5, -6, -7],
		"medium_to_large": [-4, -6, -1, -2, -3, -2, 0, 0, 0],
		"medium_to_extra_large": [-5, -7, -2, -3, -4, -2, -1, 0, 0],
		"medium_to_gigantic": [-6, -8, -3, -4, -5, -3, -2, -1, 0],
		"medium_to_enormous": [-7, -9, -4, -5, -6, -4, -3, -2, -1],
		"large_to_small": [-1, -2, -4, -3, -4, -5, -6, -7, -8],
		"large_to_medium": [0, -1, -3, -2, -3, -4, -5, -6, -7],
		"large_to_extra_large": [-4, -6, -1, -2, -3, -2, 0, 0, 0],
		"large_to_gigantic": [-5, -7, -2, -3, -4, -3, -1, 0, 0],
		"large_to_enormous": [-6, -8, -3, -4, -5, -4, -2, -1, 0],
		"extra_large_to_small": [-2, -3, -5, -4, -5, -6, -7, -8, -9],
		"extra_large_to_medium": [-1, -2, -4, -3, -4, -5, -6, -7, -8],
		"extra_large_to_large": [0, -1, -3, -2, -3, -4, -5, -6, -7],
		"extra_large_to_gigantic": [-4, -6, -1, -2, -3, -2, 0, 0, 0],
		"extra_large_to_enormous": [-5, -7, -2, -3, -4, -3, -1, 0, 0],
		"gigantic_to_small": [-3, -4, -6, -5, -6, -7, -8, -9, -10],
		"gigantic_to_medium": [-2, -3, -5, -4, -5, -6, -7, -8, -9],
		"gigantic_to_large": [-1, -2, -4, -3, -4, -5, -5, -6, -7],
		"gigantic_to_extra_large": [0, -1, -3, -2, -3, -4, -4, -5, -6],
		"gigantic_to_enormous": [-4, -6, -1, -2, -3, -2, 0, 0, 0],
		"enormous_to_small": [-4, -5, -7, -6, -7, -8, -9, -10, -11],
		"enormous_to_medium": [-3, -4, -6, -5, -6, -7, -8, -9, -10],
		"enormous_to_large": [-2, -3, -5, -4, -5, -6, -7, -8, -9],
		"enormous_to_extra_large": [-1, -2, -4, -3, -4, -5, -6, -7, -8],
		"enormous_to_gigantic": [0, -1, -3, -2, -3, -4, -5, -6, -7],
	}
	for relationship: String in expected:
		var sizes := relationship.split("_to_")
		var profile := HitLocations.resolve_attack_profile(StringName(sizes[0]), StringName(sizes[1]))
		_expect_true(profile.get("success", false), "%s must be a source-supported directional profile." % relationship)
		_expect_equal(profile.get("size_relationship"), relationship, "%s must retain attacker-to-target direction." % relationship)
		var values: Array = expected[relationship]
		for location_number in range(1, 10):
			var location := HitLocations.get_by_number(location_number)
			_expect_equal(_modifier(profile, StringName(location["id"])), values[location_number - 1], "%s location %d must match Prime." % [relationship, location_number])
		_expect_equal(_modifier(profile, HitLocations.LOCATION_8_LOWER_LEG), values[7], "%s Lower Leg must retain printed location 8." % relationship)


func _test_same_size_and_location_boundaries() -> void:
	for size_name: StringName in [HitLocations.SIZE_SMALL, HitLocations.SIZE_MEDIUM, HitLocations.SIZE_LARGE, HitLocations.SIZE_EXTRA_LARGE, HitLocations.SIZE_GIGANTIC, HitLocations.SIZE_ENORMOUS]:
		var profile := HitLocations.resolve_attack_profile(size_name, size_name)
		_expect_true(profile.get("success", false), "%s same-size profile must resolve." % String(size_name))
		_expect_equal(profile.get("size_relationship"), "same_size", "Same-size profile must not inherit a directional row.")
		_expect_equal(_modifier(profile, &"head"), -3, "Same-size Head must remain -3.")
		_expect_equal(_modifier(profile, &"neck"), -5, "Same-size Neck must remain -5.")
		_expect_equal(_modifier(profile, &"torso"), 0, "Same-size Torso must remain unchanged.")
		_expect_equal(_modifier(profile, HitLocations.LOCATION_8_KNEE), -3, "Same-size Knee must retain location 8 -3.")
		_expect_equal(_modifier(profile, HitLocations.LOCATION_8_LOWER_LEG), -3, "Same-size Lower Leg must retain location 8 -3.")
		_expect_equal(profile["location_multipliers"]["head"], {"numerator": 3, "denominator": 2, "source_ref": "PRIME-V3 pp. 95-98, Head location 1"}, "Size profiles must not change Head x1.5.")
		_expect_equal(profile["location_multipliers"]["neck"], {"numerator": 3, "denominator": 2, "source_ref": "PRIME-V3 pp. 95-98, Neck location 2"}, "Size profiles must not change Neck x1.5.")
	_expect_equal(Fixture.make_guard_actor(&"size_guard", "Size Guard").size_category, HitLocations.SIZE_MEDIUM, "The Guard fixture must explicitly remain Medium.")


func _test_tiny_exception() -> void:
	var tiny_attacker := HitLocations.resolve_attack_profile(HitLocations.SIZE_TINY, HitLocations.SIZE_MEDIUM)
	_expect_true(tiny_attacker.get("success", false), "Tiny attacker exception must be represented outside non-Tiny matrices.")
	_expect_equal(tiny_attacker.get("size_relationship"), "tiny_attacker", "Tiny attacker must use the explicit exception profile.")
	for location_id: StringName in HitLocations.get_selectable_location_ids():
		_expect_equal(_modifier(tiny_attacker, location_id), 0, "Tiny attacker must receive no hit-location ACC change.")
	var tiny_small := HitLocations.resolve_attack_profile(HitLocations.SIZE_SMALL, HitLocations.SIZE_TINY)
	var tiny_medium := HitLocations.resolve_attack_profile(HitLocations.SIZE_MEDIUM, HitLocations.SIZE_TINY)
	var tiny_enormous := HitLocations.resolve_attack_profile(HitLocations.SIZE_ENORMOUS, HitLocations.SIZE_TINY)
	_expect_equal(tiny_small.get("tiny_target_dodge_bonus"), 2, "Tiny target must gain +2 Dodge versus Small.")
	_expect_equal(tiny_medium.get("tiny_target_dodge_bonus"), 3, "Tiny target must gain +3 Dodge versus Medium.")
	_expect_equal(tiny_enormous.get("tiny_target_dodge_bonus"), 7, "Tiny target must gain +7 Dodge versus Enormous.")
	for location_id: StringName in HitLocations.get_selectable_location_ids():
		_expect_equal(_modifier(tiny_medium, location_id), 0, "Targeting Tiny must receive no hit-location ACC change.")


func _test_actor_size_validation_and_fail_closed_resolution() -> void:
	var missing := _make_actor(&"missing", &"", 100)
	var medium := _make_actor(&"medium", HitLocations.SIZE_MEDIUM, 0)
	var simulation := _make_simulation(missing, medium)
	var rejected := simulation.start_physical_attack(&"missing", &"medium", _size_aware_attack(), "missing_size", &"torso", true)
	_expect_equal(rejected.get("reason"), "unresolved_attacker_size_category", "Size-aware attack must fail closed when attacker size is absent.")
	var unsupported := _make_actor(&"unsupported", &"colossal", 100)
	var invalid_simulation := _make_simulation(unsupported, medium)
	var invalid_result := invalid_simulation.start_physical_attack(&"unsupported", &"medium", _size_aware_attack(), "unsupported_size", &"torso", true)
	_expect_equal(invalid_result.get("reason"), "unsupported_attacker_size_category", "Unknown size categories must not inherit an ACC row.")


func _test_authoritative_modifier_locking_and_replay() -> void:
	var first := _make_simulation(_make_actor(&"attacker", HitLocations.SIZE_SMALL, 100), _make_actor(&"target", HitLocations.SIZE_LARGE, 0))
	var started := first.start_physical_attack(&"attacker", &"target", _size_aware_attack(), "small_to_large", &"knee", true)
	_expect_true(started.get("success", false), "Verified Small-to-Large attack must enter the authoritative pipeline.")
	if started.get("success", false):
		var attack := first.get_attack(String(started["attack_instance_id"]))
		_expect_equal(attack.location_acc_modifier, 0, "Small-to-Large Knee must use Prime location 8 No Change.")
		_expect_equal(attack.size_relationship, &"small_to_large", "Attack must lock its directional size relationship at declaration.")
		_expect_equal(attack.target_size_category, HitLocations.SIZE_LARGE, "Attack must lock target size at declaration.")
		_expect_equal(attack.target_location, HitLocations.LOCATION_8_KNEE, "Size selection must preserve the approved Knee subdivision.")
	var second := _make_simulation(_make_actor(&"attacker", HitLocations.SIZE_SMALL, 100), _make_actor(&"target", HitLocations.SIZE_LARGE, 0))
	second.start_physical_attack(&"attacker", &"target", _size_aware_attack(), "small_to_large", &"knee", true)
	_expect_equal(first.get_state_snapshot(), second.get_state_snapshot(), "Directional size selection must replay deterministically.")


func _test_two_client_convergence() -> void:
	var harness := TwoClientSyncHarness.new(2828)
	var authority := harness.authority.simulation
	_configure_simulation(authority, _make_actor(&"attacker", HitLocations.SIZE_ENORMOUS, 100), _make_actor(&"target", HitLocations.SIZE_GIGANTIC, 0))
	var started := authority.start_physical_attack(&"attacker", &"target", _size_aware_attack(), "enormous_to_gigantic", &"lower_leg", true)
	_expect_true(started.get("success", false), "Source-supported Enormous-to-Gigantic attack must start.")
	var envelopes := harness.authority.publish_current_events()
	for envelope: CombatEventEnvelope in envelopes:
		harness.client_a.receive(envelope)
	for index in range(envelopes.size() - 1, -1, -1):
		harness.client_b.receive(envelopes[index])
	_expect_true(harness.compare_clients().get("success", false), "Simulated clients must converge for directional size events.")
	_expect_equal(harness.client_a.get_state_digest(), harness.authority.get_state_digest(), "Directional size events must preserve authority digest convergence.")


func _make_simulation(attacker: CombatActorDefinition, target: CombatActorDefinition) -> CombatSimulation:
	var simulation := CombatSimulation.new(2828)
	_configure_simulation(simulation, attacker, target)
	return simulation


func _configure_simulation(simulation: CombatSimulation, attacker: CombatActorDefinition, target: CombatActorDefinition) -> void:
	simulation.register_actor(attacker)
	simulation.register_actor(target)
	simulation.begin_combat()


func _make_actor(actor_id: StringName, size_category: StringName, init_value: int) -> CombatActorDefinition:
	return CombatActorDefinition.new(
		actor_id, &"task28_size_fixture", "Task 28 %s" % String(actor_id),
		{"str": 10, "end": 10, "spd": 10, "dex": 10, "wis": 10, "int": 10, "wit": 10, "man": 10, "luk": 10, "app": 10},
		{"hpm": 20, "acc": 12, "at": 5, "init": init_value, "mr": 10, "nal": 0, "dt": 4, "dp": 4, "physical_soak": 0, "rb": 0},
		{}, PackedStringArray(["task28_weapon"]), {}, {}, PackedStringArray(), size_category
	)


func _size_aware_attack() -> CombatAttackDefinition:
	var profile := HitLocations.get_same_size_attack_profile()
	return CombatAttackDefinition.new(
		&"task28_size_aware", &"task28_weapon", 1, true, true, 0,
		profile["acc_modifiers_by_location"], profile["allowed_target_locations"], 0, 3_000_000, true,
		PackedStringArray(["PRIME-V3 pp. 95-97 size-chart test fixture"]), &"hand_held", PackedStringArray(["slashing"]),
		true, CombatAttackDefinition.DUCKING_UNRESOLVED, null, null, true, true
	)


func _modifier(profile: Dictionary, location_id: StringName) -> Variant:
	return (profile.get("acc_modifiers_by_location", {}) as Dictionary).get(String(location_id))


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s Expected %s, got %s." % [message, expected, actual])


func _expect_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)
