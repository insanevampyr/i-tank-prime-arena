extends "res://tests/test_knockback_balance.gd"

const MOVER := &"mover"
const START := Vector2i(8_000_000, 5_000_000)
const BOUNDS := Rect2i(0, 0, 20_000_000, 10_000_000)


func run() -> Array[String]:
	_test_wall_faces_and_slide()
	_test_wall_corners()
	_test_unsupported_contacts()
	_test_live_source_contact()
	_test_wall_impact_geometry_and_guards()
	_test_wall_impact_protection()
	_test_collision_defeat_rewards()
	print("39L/39Y wall contact and damage: %d assertions." % _assertions)
	return _failures


func _wall(id: String, rect: Rect2i) -> Dictionary:
	return {"id": id, "rect_microfeet": rect, "knockback_surface": "solid_wall"}


func _geometry(battlefield: ArenaBattlefield, start: Vector2i, push: Vector2i, occupancy: Dictionary = {}, elevation: int = 0) -> Dictionary:
	var original := battlefield.resolve_motion(MOVER, start, start + push, occupancy)
	var resolved := battlefield.resolve_knockback_motion(MOVER, start, start + push, occupancy, elevation)
	var movement := resolved.duplicate(true)
	movement.erase("collision_contact")
	_expect(movement == original, "Geometry evidence must preserve the complete legacy displacement result.")
	return resolved


func _test_wall_faces_and_slide() -> void:
	var map := ArenaBattlefield.new(BOUNDS, [_wall("east_wall", Rect2i(9_500_000, 0, 1_000_000, 10_000_000))])
	var full := _geometry(map, START, Vector2i(500_000, 0))
	_expect(full.collision_contact.status == "none" and full.position_microfeet == Vector2i(8_500_000, 5_000_000), "Full travel creates no impact evidence.")
	var partial := _geometry(map, START, Vector2i(2_000_000, 0)).collision_contact as Dictionary
	_expect(partial.get("status") == "verified_static_wall" and partial.get("prevented_microfeet") == 1_000_000, "The expanded solid face prevents exactly one foot.")
	_expect(partial.get("contacts") == [{"wall_id": "east_wall", "blocking_normal": [-1, 0], "contact_point_microfeet": [9_500_000, 5_000_000], "prevented_microfeet": 1_000_000}], "Record the actual wall face, normal and contact coordinate.")
	var touching := Vector2i(9_000_000, 5_000_000)
	var stopped := _geometry(map, touching, Vector2i(2_000_000, 0))
	_expect(stopped.position_microfeet == touching and stopped.collision_contact.get("prevented_microfeet") == 2_000_000, "A push directly into a touching wall verifies the whole force despite zero travel.")
	var tangent := _geometry(map, touching, Vector2i(0, 1_600_000))
	_expect(tangent.collision_contact.status == "none" and tangent.position_microfeet.y == 6_600_000, "Pure tangency permits movement without an impact.")
	var slide := _geometry(map, touching, Vector2i(1_200_000, 1_600_000))
	_expect(slide.position_microfeet == tangent.position_microfeet and slide.collision_contact.get("prevented_components_microfeet") == [1_200_000, 0], "Diagonal clipping counts only the blocked normal component.")
	_expect(slide.collision_contact.get("prevented_microfeet") == 1_200_000, "Tangential travel is never charged as prevented distance.")
	var authored := ArenaBattlefield.create_task16_test_arena()
	var reverse := _geometry(authored, Vector2i(32_250_000, 12_000_000), Vector2i(-1_500_001, 0)).collision_contact as Dictionary
	_expect(reverse.get("prevented_microfeet") == 750_001, "Keep exact fractional microfeet on the actual authored wall.")
	_expect(reverse.get("contacts") == [{"wall_id": "center_wall", "blocking_normal": [1, 0], "contact_point_microfeet": [31_000_000, 12_000_000], "prevented_microfeet": 750_001}], "Reverse travel verifies the opposite wall face.")
	for wanted: int in [1_999_999, 2_000_000, 2_000_001]:
		var contact := _geometry(map, START, Vector2i(wanted, 0)).collision_contact as Dictionary
		_expect(contact.get("prevented_microfeet") == wanted - 1_000_000, "Exact boundary evidence must retain the microfoot above or below one foot.")


func _test_wall_corners() -> void:
	var east := _wall("east", Rect2i(9_100_000, 0, 1_000_000, 10_000_000))
	var south := _wall("south", Rect2i(0, 6_300_000, 20_000_000, 1_000_000))
	var push := Vector2i(1_200_000, 1_600_000)
	var map := ArenaBattlefield.new(BOUNDS, [south, east])
	var resolved := _geometry(map, START, push)
	var contact: Dictionary = resolved.collision_contact
	_expect(resolved.position_microfeet == Vector2i(8_600_000, 5_800_000), "Corner preserves X-then-Y position resolution.")
	_expect(contact.get("prevented_components_microfeet") == [600_000, 800_000] and contact.get("prevented_microfeet") == 1_000_000, "Simultaneous axes combine by vector length rather than summing both faces.")
	_expect(contact.get("contacts") == [
		{"wall_id": "east", "blocking_normal": [-1, 0], "contact_point_microfeet": [9_100_000, 5_800_000], "prevented_microfeet": 600_000},
		{"wall_id": "south", "blocking_normal": [0, -1], "contact_point_microfeet": [8_600_000, 6_300_000], "prevented_microfeet": 800_000},
	], "Both wall faces share a single impact with stable axis order.")
	_expect(_geometry(ArenaBattlefield.new(BOUNDS, [east, south]), START, push).collision_contact == contact, "Authored wall order cannot alter corner evidence.")
	var duplicate_normal := ArenaBattlefield.new(BOUNDS, [east, _wall("east_trim", east.rect_microfeet)])
	var faces := _geometry(duplicate_normal, START, push).collision_contact as Dictionary
	_expect(faces.get("contacts", []).size() == 2 and faces.get("prevented_microfeet") == 600_000, "Co-planar faces may share one normal without multiplying the force.")
	var diagonal := _geometry(ArenaBattlefield.new(BOUNDS, [_wall("east", Rect2i(8_500_000, 0, 1_000_000, 10_000_000)), _wall("south", Rect2i(0, 5_500_000, 20_000_000, 1_000_000))]), START, Vector2i(1_000_000, 1_000_000)).collision_contact as Dictionary
	_expect(diagonal.get("prevented_microfeet") == 1_414_213, "Corner length uses an integer floor with no floating rounding.")


func _test_unsupported_contacts() -> void:
	var open := ArenaBattlefield.new(BOUNDS)
	var push := Vector2i(2_000_000, 0)
	var occupied := _geometry(open, START, push, {"other": Vector2i(9_500_000, 5_000_000)})
	_expect(occupied.collision_contact == {"status": "unsupported", "reason": "occupied_by_actor"}, "Actor contact preserves clipping and fails closed for impact.")
	var bounds := _geometry(open, Vector2i(19_500_000, 5_000_000), push)
	_expect(bounds.collision_contact == {"status": "unsupported", "reason": "outside_battlefield_bounds"}, "Arena bounds have no inferred wall material.")
	var rect := Rect2i(9_500_000, 0, 1_000_000, 10_000_000)
	var unknown := _geometry(ArenaBattlefield.new(BOUNDS, [{"id": "unknown", "rect_microfeet": rect}]), START, push)
	_expect(unknown.collision_contact == {"status": "unsupported", "reason": "surface_unclassified"}, "A generic rectangle does not establish a verified solid-wall classification.")
	var map := ArenaBattlefield.new(BOUNDS, [_wall("east", rect)])
	var elevated := _geometry(map, START, push, {}, 1)
	_expect(elevated.collision_contact == {"status": "unsupported", "reason": "elevated_knockback"}, "Planar clipping does not prove an elevated contact.")
	var mixed := _geometry(map, START, push, {"other": Vector2i(10_000_000, 5_000_000)})
	_expect(mixed.collision_contact == {"status": "unsupported", "reason": "mixed_wall_contact"}, "A tied wall/actor obstruction fails closed.")
	var duplicate_id := _geometry(ArenaBattlefield.new(BOUNDS, [_wall("same", rect), _wall("same", rect)]), START, push)
	_expect(duplicate_id.collision_contact.status == "unsupported", "Duplicate identities cannot authorize an impact.")
	var sequential := _geometry(ArenaBattlefield.new(BOUNDS, [_wall("east", rect), _wall("south", Rect2i(0, 6_100_000, 20_000_000, 1_000_000))]), START, Vector2i(1_200_000, 1_600_000))
	_expect(sequential.collision_contact == {"status": "unsupported", "reason": "sequential_wall_contacts"}, "Non-simultaneous axes cannot be grouped into a fabricated corner.")
	var illegal := _geometry(map, Vector2i(9_500_000, 5_000_000), push)
	_expect(not illegal.success and not illegal.has("collision_contact"), "Illegal start does not produce impact evidence.")


func _test_live_source_contact() -> void:
	for kind: String in ["rage", "force_bolt", "force_shield"]:
		for row: Array in [["partial", 1, 1_000_000], ["blocked", 20, 0]]:
			var seed_value := _seed(kind, row[1])
			var mode_results: Array[Dictionary] = []
			for mode: String in [ArenaRewardLedger.MODE_NORMAL, ArenaRewardLedger.MODE_DEV_NORMAL]:
				var fixture := _resolve_fixture(kind, seed_value, row[0], "", mode)
				var sim: CombatSimulation = fixture.sim
				var event := _knockback(sim, kind)
				_expect(event != null and event.payload.has("collision_contact"), "Actual %s source emits contact evidence in %s." % [kind, mode])
				if event == null or not event.payload.has("collision_contact"): continue
				var contact: Dictionary = event.payload.collision_contact
				_expect(contact.get("status") == "verified_static_wall" and contact.get("prevented_microfeet") == DISTANCE - row[2] and contact.get("impact_id") == "%s:%s_knockback:%s:impact" % [event.parent_event_id, kind, event.target_actor_id], "Source impact identity derives from damage cause, kind and affected actor.")
				_expect(event.payload.resolved_distance_microfeet == row[2], "Both modes keep the legal source displacement, including zero travel.")
				var check: Dictionary = event.payload.get("balance_check", {})
				_expect(check.get("natural_roll") == row[1] and check.get("check_success") == (row[1] == 1) and check.get("rng_draw_index") == fixture.draws_before_damage + 2, "Both modes use the same natural roll, result and draw slot.")
				var impacts := _impacts(sim)
				_expect(impacts.size() == 1, "Each of the three supported sources resolves one damage event per impact.")
				if impacts.is_empty(): continue
				var impact := impacts[0]
				var dice: int = 1 if row[0] == "partial" else 2
				_expect(impact.parent_event_id == event.event_id and impact.stable_sequence == event.stable_sequence + 1 and impact.source_actor_id == event.source_actor_id and impact.target_actor_id == event.target_actor_id and impact.payload.impact_id == contact.impact_id, "Impact follows Balance and retains the exact source, target and causal ID.")
				_expect(impact.payload.damage_rolls.size() == dice and impact.payload.rng_draw_indices.front() == check.rng_draw_index + 1 and sim.random.get_draw_count() == check.rng_draw_index + dice, "Only the expected d10 draws follow the existing Balance draw.")
				var before := 100 if kind == "force_shield" else int(fixture.damage.payload.hpc_after)
				_expect(impact.payload.hpc_before == before and impact.payload.final_damage == impact.payload.raw_damage and sim.get_actor_state(event.target_actor_id).current_hpc == before - impact.payload.raw_damage, "Neither source damage nor prone or critical multipliers carry into wall damage.")
				_expect(sim.get_actor_state(event.target_actor_id).conditions.has("prone") == (row[1] == 20) and sim.clock.get_elapsed_us() == fixture.elapsed_before, "Wall damage changes neither footing nor Act timing.")
				_check_duplicate(fixture, event, kind)
				mode_results.append(_combat_evidence(sim))
			_expect(mode_results.size() == 2 and mode_results[0] == mode_results[1], "NORMAL and DEV NORMAL have identical combat state, RNG and causal history for %s/%s." % [kind, row[0]])

	var replays: Array = []
	for mode: String in [ArenaRewardLedger.MODE_NORMAL, ArenaRewardLedger.MODE_DEV_NORMAL, ArenaRewardLedger.MODE_DEV_NORMAL]:
		var fixture := _resolve_fixture("rage", _seed("rage", 20), "partial", "", mode)
		var evidence := _combat_evidence(fixture.sim)
		var harness: TwoClientSyncHarness = fixture.harness
		var envelopes := harness.authority.publish_current_events()
		for envelope: CombatEventEnvelope in envelopes: harness.client_a.receive(envelope)
		for reverse_index in range(envelopes.size() - 1, -1, -1):
			harness.client_b.receive(envelopes[reverse_index])
			harness.client_b.receive(envelopes[reverse_index])
		_expect(harness.compare_clients().success and harness.client_a.get_state_digest() == harness.authority.get_state_digest(), "Contact evidence converges on both clients despite reordering and duplicate delivery.")
		_expect(evidence.snapshot.schema_version == 12, "The existing event payload carries evidence with schema 12.")
		replays.append(evidence)
	_expect(replays[0] == replays[1] and replays[1] == replays[2], "Same-seed NORMAL and repeated DEV NORMAL reproduce contact, Balance and combat history.")
	var reentrant := _resolve_fixture("rage", _seed("rage", 1), "partial", "reentrant")
	_expect(_impacts(reentrant.sim).size() == 1 and reentrant.sim.random.get_draw_count() == reentrant.draws_before_damage + 3, "Reentrant verified contact applies its Balance and collision damage only once.")
	var dual := _resolve_fixture("dual", _seed("dual", 1), "dual_wall")
	var dual_impacts := _impacts(dual.sim)
	_expect(dual_impacts.size() == 2 and dual_impacts[0].target_actor_id == ATTACKER and dual_impacts[1].target_actor_id == TARGET, "Shield and Rage impacts from the same attack resolve independently, Shield first.")
	var test := _resolve_fixture("rage", _seed("rage", 1), "partial", "", ArenaRewardLedger.MODE_TEST)
	_expect(_impacts(test.sim).is_empty() and test.sim.random.get_draw_count() == test.draws_before_damage + 1, "TEST retains its movement-only knockback fixture and original draw count.")


func _impacts(sim: CombatSimulation) -> Array[CombatEvent]:
	var impacts: Array[CombatEvent] = []
	for event: CombatEvent in sim.get_resolved_events():
		if event.event_type == CombatSimulation.WALL_COLLISION_DAMAGE_EVENT: impacts.append(event)
	return impacts


func _push_at_wall(walls: Array[Dictionary], start: Vector2i, push: Vector2i, setup: Dictionary = {}) -> Dictionary:
	var session := ArenaCombatSession.new(579)
	var sim := session.simulation
	session.configure_battlefield(ArenaBattlefield.new(BOUNDS, walls))
	sim.set_rage_knockback_resolver(session._resolve_rage_knockback)
	sim.set_reward_state_snapshot({"mode": ArenaRewardLedger.MODE_NORMAL})
	for id: StringName in [ATTACKER, TARGET]:
		var actor: CombatActorDefinition = VAELIS.instantiate_actor(id, String(id), PackedStringArray(["wall_armor"]))
		actor.combat_stats["nal"] = 0
		sim.register_actor(actor)
	var armors: Array[CombatArmorDefinition] = []
	if setup.has("tal"):
		armors.append(CombatArmorDefinition.new(&"wall_armor", &"torso", PackedStringArray(["torso"]), {"bashing": setup.tal, "slashing":20}))
	var responses := {"bashing": {"kind":"immune"}} if setup.get("immune",false) else {}
	sim.register_damage_protection_profile(TARGET, CombatDamageProtectionProfile.new(&"wall_protection", armors, responses))
	sim.apply_authoritative_position(ATTACKER, start - push, 0)
	sim.apply_authoritative_position(TARGET, start, 0)
	if setup.has("occupant"):
		sim.register_actor(VAELIS.instantiate_actor(&"blocker", "Blocker", PackedStringArray()))
		sim.apply_authoritative_position(&"blocker", setup.occupant, 0)
	var state := sim.get_actor_state(TARGET)
	state.current_hpc = setup.get("hpc", 100)
	state.elevation_microfeet = setup.get("elevation", 0)
	if setup.get("prone", false): state.conditions.append("prone")
	if setup.has("nal_modifier"): state.timed_stat_effects["verified_fixture_nal"] = {"stat_modifiers":{"nal":setup.nal_modifier}}
	if setup.has("shield"): state.persistent_damage_shields["force_shield"] = {"capacity":setup.shield,"physical_attacker_knockback_microfeet":DISTANCE}
	var parent := sim._record_resolved_event(0, &"wall_impact_fixture_source", 0, ATTACKER, TARGET, {})
	sim._resolve_source_knockback("wall_impact_fixture", ATTACKER, TARGET, roundi(Vector2(push).length()), "rage_knockback", parent.event_id, setup.get("effect_id", String(HadesCombatFollowerFixture.RAGE_EFFECT_ID)))
	return {"sim":sim, "state":state, "knockback":_knockback(sim,"rage"), "impacts":_impacts(sim)}


func _test_wall_impact_geometry_and_guards() -> void:
	var rect := Rect2i(9_500_000, 0, 1_000_000, 10_000_000)
	var east := _wall("east", rect)
	var fractional := _push_at_wall([east], START, Vector2i(1_750_001,0), {"prone":true})
	_expect(fractional.knockback.payload.balance_reason == "balance_not_required_already_prone" and fractional.state.conditions.has("prone") and fractional.state.position_microfeet.x == 9_000_000, "Already-prone targets still slide or move legally and skip Balance.")
	var preview := DeterministicCombatRng.new(579)
	var first_roll := preview.next_int(1,10)
	_expect(fractional.impacts.size() == 1 and fractional.impacts[0].payload.prevented_microfeet == 750_001 and fractional.impacts[0].payload.damage_rolls == [first_roll] and fractional.impacts[0].payload.rng_draw_indices == [1], "A fractional verified impact consumes exactly the first seeded d10 when Balance is skipped.")
	var corner := _push_at_wall([_wall("east",Rect2i(9_100_000,0,1_000_000,10_000_000)), _wall("south",Rect2i(0,6_300_000,20_000_000,1_000_000))], START, Vector2i(1_200_000,1_600_000), {"prone":true})
	_expect(corner.knockback.payload.collision_contact.contacts.size() == 2 and corner.impacts.size() == 1 and corner.impacts[0].payload.damage_rolls == [first_roll], "Two verified corner faces spend one die for their one-foot combined impact.")
	var slide := _push_at_wall([east], Vector2i(9_000_000,5_000_000), Vector2i(1_200_000,1_600_000), {"prone":true})
	_expect(slide.state.position_microfeet == Vector2i(9_000_000,6_600_000) and slide.impacts.size() == 1 and slide.impacts[0].payload.prevented_microfeet == 1_200_000 and slide.impacts[0].payload.damage_rolls == [first_roll], "Wall sliding preserves tangential travel and charges only the stopped normal component.")
	for row: Array in [
		[[east], START, Vector2i(500_000,0), {}],
		[[east], Vector2i(9_000_000,5_000_000), Vector2i(0,1_600_000), {}],
		[[], START, Vector2i(2_000_000,0), {"occupant":Vector2i(9_500_000,5_000_000)}],
		[[east], START, Vector2i(2_000_000,0), {"occupant":Vector2i(10_000_000,5_000_000)}],
		[[], Vector2i(19_500_000,5_000_000), Vector2i(2_000_000,0), {}],
		[[{"id":"unknown", "rect_microfeet":rect}], START, Vector2i(2_000_000,0), {}],
		[[east], START, Vector2i(2_000_000,0), {"elevation":1}],
		[[east,_wall("south",Rect2i(0,6_100_000,20_000_000,1_000_000))], START, Vector2i(1_200_000,1_600_000), {}],
		[[east], START, Vector2i(2_000_000,0), {"effect_id":"inner_strength"}],
		[[east], START, Vector2i(2_000_000,0), {"hpc":0}],
	]:
		var walls: Array[Dictionary] = []
		walls.assign(row[0])
		var guarded := _push_at_wall(walls, row[1], row[2], row[3].merged({"prone":true}))
		_expect(guarded.impacts.is_empty() and guarded.sim.random.get_draw_count() == 0 and guarded.state.current_hpc == row[3].get("hpc",100), "Excluded contact/source or defeated target cannot roll or take collision damage: %s." % str(row))
	var defeated := _resolve_fixture("force_bolt", _seed("force_bolt", 1), "blocked", "incapacitated")
	_expect(_impacts(defeated.sim).is_empty() and defeated.sim.random.get_draw_count() == defeated.draws_before_damage + 1, "A lethal source hit cannot also apply collision damage or spend collision RNG.")


func _test_wall_impact_protection() -> void:
	var east := _wall("east", Rect2i(9_500_000,0,1_000_000,10_000_000))
	var preview := DeterministicCombatRng.new(579)
	var expected_rolls := [preview.next_int(1,10), preview.next_int(1,10)]
	for row: Dictionary in [{"tal":3,"nal_modifier":2}, {"tal":20,"nal_modifier":1}, {"tal":0}, {"immune":true,"shield":20}, {"shield":20}, {"shield":1}]:
		var result := _push_at_wall([east], Vector2i(9_000_000,5_000_000), Vector2i(2_000_000,0), row.merged({"prone":true}))
		_expect(result.impacts.size() == 1, "Protection retains one causal impact record.")
		if result.impacts.is_empty(): continue
		var damage: Dictionary = result.impacts[0].payload
		var reduced: int = damage.raw_damage - row.get("tal",0) - row.get("nal_modifier",0)
		var before_shield := 0 if row.get("immune",false) else maxi(1,reduced)
		var absorbed := mini(before_shield, int(row.get("shield",0)))
		_expect(damage.damage_rolls == expected_rolls and damage.raw_damage == expected_rolls[0] + expected_rolls[1] and damage.rng_draw_indices == [1,2] and damage.armor_tal == row.get("tal",0) and damage.natural_armor_level == row.get("nal_modifier",0), "Use the two exact seeded d10 results, matching torso bashing TAL and current effective NAL.")
		_expect(damage.immune == row.get("immune",false) and damage.minimum_one_applied == (not damage.immune and reduced < 1) and damage.final_damage == before_shield - absorbed and result.state.current_hpc == 100 - damage.final_damage, "Immunity and shield absorption may reach zero after the armor minimum.")
		_expect(damage.protective_points_absorbed == absorbed and damage.shield_depleted == (absorbed > 0 and absorbed == row.get("shield")) and _knockback(result.sim,"force_shield") == null, "Wall absorption spends only the applicable shield capacity and never retaliates.")
		if row.has("shield"):
			_expect(result.state.persistent_damage_shields.get("force_shield",{}).get("capacity",0) == row.shield - absorbed,"Partial absorption and depletion update the actual Force Shield state.")


func _test_collision_defeat_rewards() -> void:
	# Seed 10 resolves one real Goblin loot drop after the collision dice.
	var session := ArenaCombatSession.new(10, null, PrimeV3VerticalSliceFixture.ENCOUNTER_WAVE_ONE_GOBLINS)
	session.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
	session.set_opponent_behavior_enabled(false)
	var initialized := session.initialize_wave_one_goblins(Vector2i(20_000_000,5_000_000), Vector2i(24_000_000,5_000_000), false)
	_expect(initialized.success and session.configure_reward_mode(ArenaRewardLedger.MODE_NORMAL).success and session.start_encounter().success, "Start a real rewarded Wave 1 for collision defeat.")
	var sim := session.simulation
	var enemies := session.get_targetable_enemy_ids()
	var target := StringName(enemies[0])
	for other: String in enemies:
		if other != target: sim.get_actor_state(StringName(other)).current_hpc = 0
	sim.apply_authoritative_position(&"player", Vector2i(27_000_000,12_000_000), 0)
	sim.apply_authoritative_position(target, Vector2i(28_500_000,12_000_000), 0)
	var parent := sim._record_resolved_event(sim.clock.get_elapsed_us(), &"wall_impact_fixture_source", 0, &"player", target, {})
	sim._resolve_source_knockback("wall_impact_fixture", &"player", target, DISTANCE, "force_shield_knockback", parent.event_id)
	var impacts := _impacts(sim)
	_expect(impacts.size() == 1 and impacts[0].payload.hpc_before > 0 and impacts[0].payload.hpc_after <= 0, "A player-caused wall impact defeats the active enemy.")
	session.advance_by(1)
	var ledger := session.get_reward_state()
	_expect(ledger.earned_xp == 10 and ledger.awards.size() == 1 and not impacts.is_empty() and ledger.awards[0].defeat_event_id == impacts[0].event_id, "The ordinary reward ledger grants one Goblin XP award tied to the collision event.")
	_expect(sim.get_world_items_snapshot().size() == 1 and ledger.drop_resolutions.size() == 2, "Collision defeat resolves the Goblin's normal two drop opportunities and creates the seeded loot exactly once.")
	_expect(session.get_encounter_state() == ArenaCombatSession.ENCOUNTER_BETWEEN_WAVE_DOWNTIME, "Collision defeat advances to downtime.")
	var before := session.get_state_snapshot()
	session._process_reward_events()
	sim._resolve_source_knockback("wall_impact_fixture", &"player", target, DISTANCE, "force_shield_knockback", parent.event_id)
	_expect(session.get_state_snapshot() == before, "Duplicate settlement and impact cannot repeat XP, loot or RNG.")
	_expect(session.request_next_wave().success and session._current_reward_wave_id() == "wave_2" and session.get_reward_state().earned_xp == 10, "A collision defeat permits the ordinary next-wave transition without another reward.")
