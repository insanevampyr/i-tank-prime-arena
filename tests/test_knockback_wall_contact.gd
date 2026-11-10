extends "res://tests/test_knockback_balance.gd"

const MOVER := &"mover"
const START := Vector2i(8_000_000, 5_000_000)
const BOUNDS := Rect2i(0, 0, 20_000_000, 10_000_000)


func run() -> Array[String]:
	_test_wall_faces_and_slide()
	_test_wall_corners()
	_test_unsupported_contacts()
	_test_live_source_contact()
	print("39L wall contact: %d assertions." % _assertions)
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
				_expect(sim.random.get_draw_count() == fixture.draws_before_damage + 2, "A verified wall contact adds one Balance d20 and no collision draw.")
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
