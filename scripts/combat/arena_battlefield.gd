class_name ArenaBattlefield
extends RefCounted

const MICROFEET_PER_FOOT := 1_000_000
const DEFAULT_ACTOR_RADIUS_MICROFEET := 500_000
const NAVIGATION_STEP_MICROFEET := MICROFEET_PER_FOOT
const DIRECT_PATH_BOUNDARY_EPSILON_MICROFEET := 2_048

var bounds_microfeet: Rect2i
var actor_radius_microfeet: int
var navigation_authoritative: bool
var _obstacles: Array[Dictionary] = []
var _hazards: Array[Dictionary] = []
var _direct_path_exact_sample_count: int = 0


func _init(
	p_bounds_microfeet: Rect2i,
	p_obstacles: Array[Dictionary] = [],
	p_actor_radius_microfeet: int = DEFAULT_ACTOR_RADIUS_MICROFEET,
	p_navigation_authoritative: bool = false,
	p_hazards: Array[Dictionary] = []
) -> void:
	assert(p_bounds_microfeet.size.x > 0 and p_bounds_microfeet.size.y > 0, "Battlefield bounds must be positive.")
	assert(p_actor_radius_microfeet >= 0, "Actor collision radius cannot be negative.")
	bounds_microfeet = p_bounds_microfeet
	actor_radius_microfeet = p_actor_radius_microfeet
	navigation_authoritative = p_navigation_authoritative
	for obstacle: Dictionary in p_obstacles:
		assert(obstacle.has("id") and obstacle.has("rect_microfeet"), "Every battlefield obstacle needs a stable ID and rectangle.")
		_obstacles.append({
			"id": String(obstacle["id"]),
			"rect_microfeet": obstacle["rect_microfeet"],
			"hazard_tier": int(obstacle.get("hazard_tier", 0)),
		})
	_obstacles.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return String(left["id"]) < String(right["id"]))
	for hazard: Dictionary in p_hazards:
		assert(hazard.has("id") and hazard.has("rect_microfeet") and hazard.has("hazard_tier"), "Every battlefield hazard needs an ID, rectangle and known tier.")
		_hazards.append({
			"id": String(hazard["id"]),
			"rect_microfeet": hazard["rect_microfeet"],
			"hazard_tier": int(hazard["hazard_tier"]),
		})
	_hazards.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return String(left["id"]) < String(right["id"]))


static func create_open(bounds: Rect2i) -> ArenaBattlefield:
	return ArenaBattlefield.new(bounds)


static func create_task16_test_arena() -> ArenaBattlefield:
	# Geometry is an Arena test fixture, not a new Prime terrain rule. Canonical
	# distances remain feet; the scene applies pixels-per-foot for presentation.
	return ArenaBattlefield.new(
		Rect2i(2_000_000, 2_000_000, 44_000_000, 23_000_000),
		[
			{
				"id": "center_wall",
				"rect_microfeet": Rect2i(29_000_000, 8_000_000, 2_000_000, 12_000_000),
				"hazard_tier": 0,
			},
		],
		DEFAULT_ACTOR_RADIUS_MICROFEET,
		true,
		[
			{
				"id": "non_damaging_test_hazard_zone",
				"rect_microfeet": Rect2i(7_000_000, 20_000_000, 5_000_000, 3_000_000),
				"hazard_tier": 1,
			},
		]
	)


func get_obstacles() -> Array[Dictionary]:
	return _obstacles.duplicate(true)


func get_hazards() -> Array[Dictionary]:
	return _hazards.duplicate(true)


func to_dictionary() -> Dictionary:
	var serialized_obstacles: Array[Dictionary] = []
	for obstacle: Dictionary in _obstacles:
		var rect: Rect2i = obstacle["rect_microfeet"]
		serialized_obstacles.append({
			"id": obstacle["id"],
			"rect_microfeet": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
			"hazard_tier": obstacle["hazard_tier"],
		})
	var serialized_hazards: Array[Dictionary] = []
	for hazard: Dictionary in _hazards:
		var rect: Rect2i = hazard["rect_microfeet"]
		serialized_hazards.append({
			"id": hazard["id"],
			"rect_microfeet": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
			"hazard_tier": hazard["hazard_tier"],
		})
	return {
		"bounds_microfeet": [bounds_microfeet.position.x, bounds_microfeet.position.y, bounds_microfeet.size.x, bounds_microfeet.size.y],
		"actor_radius_microfeet": actor_radius_microfeet,
		"navigation_authoritative": navigation_authoritative,
		"obstacles": serialized_obstacles,
		"hazards": serialized_hazards,
		"navigation_step_microfeet": NAVIGATION_STEP_MICROFEET,
	}


func is_position_legal(actor_id: StringName, position_microfeet: Vector2i, occupancy: Dictionary) -> Dictionary:
	var minimum := bounds_microfeet.position + Vector2i(actor_radius_microfeet, actor_radius_microfeet)
	var maximum := bounds_microfeet.end - Vector2i(actor_radius_microfeet, actor_radius_microfeet)
	if position_microfeet.x < minimum.x or position_microfeet.y < minimum.y \
		or position_microfeet.x > maximum.x or position_microfeet.y > maximum.y:
		return {"legal": false, "reason": "outside_battlefield_bounds"}
	for obstacle: Dictionary in _obstacles:
		if _position_overlaps_rect(position_microfeet, obstacle["rect_microfeet"], actor_radius_microfeet):
			return {"legal": false, "reason": "blocked_by_obstacle", "obstacle_id": obstacle["id"]}
	var minimum_separation := actor_radius_microfeet * 2
	for occupied_actor_key: Variant in occupancy.keys():
		if StringName(occupied_actor_key) == actor_id:
			continue
		var occupied_position: Vector2i = occupancy[occupied_actor_key]
		var offset := occupied_position - position_microfeet
		if offset.length_squared() < minimum_separation * minimum_separation:
			return {"legal": false, "reason": "occupied_by_actor", "actor_id": String(occupied_actor_key)}
	return {"legal": true, "reason": "legal"}


func resolve_motion(
	actor_id: StringName,
	start_microfeet: Vector2i,
	desired_microfeet: Vector2i,
	occupancy: Dictionary
) -> Dictionary:
	var start_legality := is_position_legal(actor_id, start_microfeet, occupancy)
	if not start_legality["legal"]:
		return {"success": false, "reason": "start_%s" % start_legality["reason"], "position_microfeet": start_microfeet}
	var resolved := start_microfeet
	# Stable X-then-Y collision resolution provides deterministic wall sliding.
	resolved = _furthest_legal_on_segment(actor_id, resolved, Vector2i(desired_microfeet.x, resolved.y), occupancy)
	resolved = _furthest_legal_on_segment(actor_id, resolved, Vector2i(resolved.x, desired_microfeet.y), occupancy)
	var cost := roundi(Vector2(resolved - start_microfeet).length())
	return {
		"success": true,
		"position_microfeet": resolved,
		"movement_cost_microfeet": cost,
		"blocked": resolved != desired_microfeet,
		"reason": "collision_limited" if resolved != desired_microfeet else "legal",
	}


func is_path_clear(
	actor_id: StringName,
	start_microfeet: Vector2i,
	end_microfeet: Vector2i,
	occupancy: Dictionary
) -> bool:
	if not is_position_legal(actor_id, end_microfeet, occupancy)["legal"]:
		return false
	var resolved := resolve_motion(actor_id, start_microfeet, end_microfeet, occupancy)
	return resolved.get("success", false) and resolved["position_microfeet"] == end_microfeet


func is_direct_path_clear(
	actor_id: StringName,
	start_microfeet: Vector2i,
	end_microfeet: Vector2i,
	occupancy: Dictionary
) -> bool:
	if not is_position_legal(actor_id, end_microfeet, occupancy)["legal"]:
		return false
	# Reject segments that certainly enter the actor-footprint-expanded interior
	# of a static obstacle before invoking the exact sampled collision resolver.
	# A narrow boundary band preserves the existing rule that touching an
	# obstacle boundary is legal while avoiding expensive sampling for the
	# common across-wall navigation case.
	if _segment_definitely_crosses_static_obstacle(start_microfeet, end_microfeet):
		return false
	if _segment_definitely_crosses_occupied_actor(actor_id, start_microfeet, end_microfeet, occupancy):
		return false
	if not _segment_may_require_static_collision_sampling(start_microfeet, end_microfeet) \
		and not _segment_may_require_occupied_actor_sampling(actor_id, start_microfeet, end_microfeet, occupancy):
		return true
	_direct_path_exact_sample_count += 1
	return _furthest_legal_on_segment(actor_id, start_microfeet, end_microfeet, occupancy) == end_microfeet


func get_direct_path_exact_sample_count_for_testing() -> int:
	return _direct_path_exact_sample_count


func reset_direct_path_exact_sample_count_for_testing() -> void:
	_direct_path_exact_sample_count = 0


func _segment_definitely_crosses_static_obstacle(start_microfeet: Vector2i, end_microfeet: Vector2i) -> bool:
	# Vector2 segment math loses single-microfoot precision at Arena-scale
	# coordinates. Leave a narrow boundary band for the exact resolver so legal
	# tangent travel is never rejected by the broad phase.
	var interior_margin := maxi(0, actor_radius_microfeet - DIRECT_PATH_BOUNDARY_EPSILON_MICROFEET)
	for obstacle: Dictionary in _obstacles:
		var obstacle_rect: Rect2i = obstacle["rect_microfeet"]
		var expanded_interior := Rect2i(
			obstacle_rect.position - Vector2i(interior_margin, interior_margin),
			obstacle_rect.size + Vector2i(interior_margin * 2, interior_margin * 2)
		)
		if _segment_intersects_rect(start_microfeet, end_microfeet, expanded_interior):
			return true
	return false


func _segment_may_require_static_collision_sampling(start_microfeet: Vector2i, end_microfeet: Vector2i) -> bool:
	for obstacle: Dictionary in _obstacles:
		var obstacle_rect: Rect2i = obstacle["rect_microfeet"]
		var expanded := Rect2i(
			obstacle_rect.position - Vector2i(actor_radius_microfeet, actor_radius_microfeet),
			obstacle_rect.size + Vector2i(actor_radius_microfeet * 2, actor_radius_microfeet * 2)
		)
		if _segment_intersects_rect(start_microfeet, end_microfeet, expanded):
			return true
	return false


func _segment_definitely_crosses_occupied_actor(
	actor_id: StringName,
	start_microfeet: Vector2i,
	end_microfeet: Vector2i,
	occupancy: Dictionary
) -> bool:
	var minimum_separation := actor_radius_microfeet * 2
	var definite_overlap_distance := maxi(0, minimum_separation - DIRECT_PATH_BOUNDARY_EPSILON_MICROFEET)
	var definite_overlap_distance_squared := float(definite_overlap_distance) * float(definite_overlap_distance)
	var start := Vector2(start_microfeet)
	var segment := Vector2(end_microfeet - start_microfeet)
	var segment_length_squared := segment.length_squared()
	for occupied_actor_key: Variant in occupancy.keys():
		if StringName(occupied_actor_key) == actor_id:
			continue
		var occupied_position: Vector2i = occupancy[occupied_actor_key]
		var point := Vector2(occupied_position)
		var fraction := 0.0
		if segment_length_squared > 0.0:
			fraction = clampf((point - start).dot(segment) / segment_length_squared, 0.0, 1.0)
		var closest := start + segment * fraction
		if closest.distance_squared_to(point) < definite_overlap_distance_squared:
			return true
	return false


func _segment_may_require_occupied_actor_sampling(
	actor_id: StringName,
	start_microfeet: Vector2i,
	end_microfeet: Vector2i,
	occupancy: Dictionary
) -> bool:
	var possible_overlap_distance := actor_radius_microfeet * 2 + DIRECT_PATH_BOUNDARY_EPSILON_MICROFEET
	var possible_overlap_distance_squared := float(possible_overlap_distance) * float(possible_overlap_distance)
	var start := Vector2(start_microfeet)
	var segment := Vector2(end_microfeet - start_microfeet)
	var segment_length_squared := segment.length_squared()
	for occupied_actor_key: Variant in occupancy.keys():
		if StringName(occupied_actor_key) == actor_id:
			continue
		var point := Vector2(occupancy[occupied_actor_key])
		var fraction := 0.0
		if segment_length_squared > 0.0:
			fraction = clampf((point - start).dot(segment) / segment_length_squared, 0.0, 1.0)
		if (start + segment * fraction).distance_squared_to(point) <= possible_overlap_distance_squared:
			return true
	return false


func has_line_of_sight(start_microfeet: Vector2i, end_microfeet: Vector2i) -> bool:
	for obstacle: Dictionary in _obstacles:
		if _segment_intersects_rect(start_microfeet, end_microfeet, obstacle["rect_microfeet"]):
			return false
	return true


func is_attack_position_legal(position_microfeet: Vector2i, target_microfeet: Vector2i, attack_range_microfeet: int) -> bool:
	return _within_reach_and_visible(position_microfeet, target_microfeet, attack_range_microfeet)


func find_path_to_attack_position(
	mover_id: StringName,
	start_microfeet: Vector2i,
	target_microfeet: Vector2i,
	attack_range_microfeet: int,
	occupancy: Dictionary
) -> Dictionary:
	if _within_reach_and_visible(start_microfeet, target_microfeet, attack_range_microfeet):
		return {"success": true, "waypoints": [], "reason": "already_in_range"}
	var attack_positions := _legal_attack_position_candidates(
		mover_id, start_microfeet, target_microfeet, attack_range_microfeet, occupancy
	)
	if attack_positions.is_empty():
		return {"success": false, "reason": "no_legal_attack_position", "waypoints": []}
	var start_node_result: Variant = _nearest_legal_navigation_node(mover_id, start_microfeet, occupancy)
	if start_node_result == null:
		return {"success": false, "reason": "no_legal_navigation_start", "waypoints": []}
	var start_node: Vector2i = start_node_result
	var frontier: Array[Vector2i] = [start_node]
	var came_from: Dictionary = {start_node: start_node}
	var directions: Array[Vector2i] = [Vector2i.LEFT, Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN]
	var goal: Variant = null
	var final_attack_position: Variant = null
	var index := 0
	while index < frontier.size() and index < 10_000:
		var current: Vector2i = frontier[index]
		index += 1
		final_attack_position = _first_reachable_attack_position(mover_id, current, attack_positions, occupancy)
		if final_attack_position != null:
			goal = current
			break
		for direction: Vector2i in directions:
			var neighbor := current + direction * NAVIGATION_STEP_MICROFEET
			if came_from.has(neighbor):
				continue
			if not is_position_legal(mover_id, neighbor, occupancy)["legal"]:
				continue
			if not is_path_clear(mover_id, current, neighbor, occupancy):
				continue
			came_from[neighbor] = current
			frontier.append(neighbor)
	if goal == null:
		return {"success": false, "reason": "no_legal_path", "waypoints": []}
	var reversed: Array[Vector2i] = []
	var cursor: Vector2i = goal
	while cursor != start_node:
		reversed.append(cursor)
		cursor = came_from[cursor]
	reversed.reverse()
	if start_microfeet != start_node:
		reversed.push_front(start_node)
	if final_attack_position != goal:
		reversed.append(final_attack_position)
	return {"success": true, "reason": "legal_path", "waypoints": reversed}


func _legal_attack_position_candidates(
	mover_id: StringName,
	start_microfeet: Vector2i,
	target_microfeet: Vector2i,
	attack_range_microfeet: int,
	occupancy: Dictionary
) -> Array[Vector2i]:
	var directions: Array[Vector2i] = [Vector2i.LEFT, Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN]
	var candidates: Array[Dictionary] = []
	for direction_index in range(directions.size()):
		var position := target_microfeet + directions[direction_index] * attack_range_microfeet
		if not is_position_legal(mover_id, position, occupancy).get("legal", false):
			continue
		if not _within_reach_and_visible(position, target_microfeet, attack_range_microfeet):
			continue
		var offset := position - start_microfeet
		candidates.append({
			"position": position,
			"distance_squared": offset.length_squared(),
			"direction_index": direction_index,
		})
	candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		if int(left["distance_squared"]) != int(right["distance_squared"]):
			return int(left["distance_squared"]) < int(right["distance_squared"])
		return int(left["direction_index"]) < int(right["direction_index"])
	)
	var positions: Array[Vector2i] = []
	for candidate: Dictionary in candidates:
		positions.append(candidate["position"])
	return positions


func _first_reachable_attack_position(
	mover_id: StringName,
	start_microfeet: Vector2i,
	attack_positions: Array[Vector2i],
	occupancy: Dictionary
) -> Variant:
	for attack_position: Vector2i in attack_positions:
		if is_direct_path_clear(mover_id, start_microfeet, attack_position, occupancy):
			return attack_position
	return null


func build_dodge_candidate_facts(
	defender_id: StringName,
	defender_position: Vector2i,
	attacker_position: Vector2i,
	maximum_distance_feet: int,
	attack_range_microfeet: int,
	occupancy: Dictionary
) -> Array[Dictionary]:
	var facts: Array[Dictionary] = []
	var directions: Array[Vector2i] = [Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN, Vector2i.RIGHT]
	for distance_feet in range(1, maximum_distance_feet + 1):
		var movement_cost := distance_feet * MICROFEET_PER_FOOT
		for direction_index in range(directions.size()):
			var destination := defender_position + directions[direction_index] * movement_cost
			var destination_legal: Dictionary = is_position_legal(defender_id, destination, occupancy)
			var path_clear: bool = bool(destination_legal["legal"]) and is_path_clear(defender_id, defender_position, destination, occupancy)
			var offset := destination - attacker_position
			facts.append({
				"id": "step_%02d_dir_%02d" % [distance_feet, direction_index],
				"destination_microfeet": destination,
				"movement_cost_microfeet": movement_cost,
				"path_valid": path_clear,
				"collision_free": path_clear,
				"terrain_legal": destination_legal["legal"],
				"unoccupied": destination_legal["legal"] or destination_legal.get("reason", "") != "occupied_by_actor",
				"escapes_attack": offset.length_squared() > attack_range_microfeet * attack_range_microfeet,
				"hazard_tier": get_hazard_tier(destination),
			})
	return facts


func get_hazard_tier(position_microfeet: Vector2i) -> int:
	var tier := 0
	for hazard: Dictionary in _hazards:
		var rect: Rect2i = hazard["rect_microfeet"]
		if rect.has_point(position_microfeet):
			tier = maxi(tier, int(hazard["hazard_tier"]))
	return tier


func _nearest_legal_navigation_node(actor_id: StringName, position_microfeet: Vector2i, occupancy: Dictionary) -> Variant:
	var base := Vector2i(
		roundi(float(position_microfeet.x) / NAVIGATION_STEP_MICROFEET) * NAVIGATION_STEP_MICROFEET,
		roundi(float(position_microfeet.y) / NAVIGATION_STEP_MICROFEET) * NAVIGATION_STEP_MICROFEET
	)
	var offsets: Array[Vector2i] = [Vector2i.ZERO, Vector2i.LEFT, Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN]
	for offset: Vector2i in offsets:
		var candidate := base + offset * NAVIGATION_STEP_MICROFEET
		if is_position_legal(actor_id, candidate, occupancy)["legal"] and is_direct_path_clear(actor_id, position_microfeet, candidate, occupancy):
			return candidate
	return null


func _within_reach_and_visible(position: Vector2i, target: Vector2i, attack_range_microfeet: int) -> bool:
	var offset := target - position
	return offset.length_squared() <= attack_range_microfeet * attack_range_microfeet \
		and has_line_of_sight(position, target)


func _furthest_legal_on_segment(
	actor_id: StringName,
	start_microfeet: Vector2i,
	end_microfeet: Vector2i,
	occupancy: Dictionary
) -> Vector2i:
	if start_microfeet == end_microfeet:
		return end_microfeet
	var delta := end_microfeet - start_microfeet
	var span := maxi(absi(delta.x), absi(delta.y))
	var sample_step := 100_000
	@warning_ignore("integer_division")
	var sample_count := maxi(1, (span + sample_step - 1) / sample_step)
	var last_legal := start_microfeet
	for sample_index in range(1, sample_count + 1):
		var candidate := Vector2i(
			start_microfeet.x + int(int(delta.x) * sample_index / sample_count),
			start_microfeet.y + int(int(delta.y) * sample_index / sample_count)
		)
		if not is_position_legal(actor_id, candidate, occupancy)["legal"]:
			return _furthest_legal_between(actor_id, last_legal, candidate, occupancy)
		last_legal = candidate
	return end_microfeet


func _furthest_legal_between(
	actor_id: StringName,
	legal_start: Vector2i,
	blocked_end: Vector2i,
	occupancy: Dictionary
) -> Vector2i:
	var low := 0
	var high := MICROFEET_PER_FOOT
	while low + 1 < high:
		var middle := (low + high) / 2
		var candidate := Vector2i(
			legal_start.x + int((int(blocked_end.x) - int(legal_start.x)) * middle / MICROFEET_PER_FOOT),
			legal_start.y + int((int(blocked_end.y) - int(legal_start.y)) * middle / MICROFEET_PER_FOOT)
		)
		if is_position_legal(actor_id, candidate, occupancy)["legal"]:
			low = middle
		else:
			high = middle
	return Vector2i(
		legal_start.x + int((int(blocked_end.x) - int(legal_start.x)) * low / MICROFEET_PER_FOOT),
		legal_start.y + int((int(blocked_end.y) - int(legal_start.y)) * low / MICROFEET_PER_FOOT)
	)


func _position_overlaps_rect(position: Vector2i, rect: Rect2i, radius: int) -> bool:
	return position.x + radius > rect.position.x \
		and position.x - radius < rect.end.x \
		and position.y + radius > rect.position.y \
		and position.y - radius < rect.end.y


func _segment_intersects_rect(start: Vector2i, finish: Vector2i, rect: Rect2i) -> bool:
	var direction := Vector2(finish - start)
	var t_min := 0.0
	var t_max := 1.0
	var minimum := Vector2(rect.position)
	var maximum := Vector2(rect.end)
	for axis in range(2):
		var origin := float(start[axis])
		var delta := direction[axis]
		if is_zero_approx(delta):
			if origin >= minimum[axis] and origin <= maximum[axis]:
				continue
			return false
		var inverse := 1.0 / delta
		var near := (minimum[axis] - origin) * inverse
		var far := (maximum[axis] - origin) * inverse
		if near > far:
			var swap := near
			near = far
			far = swap
		t_min = maxf(t_min, near)
		t_max = minf(t_max, far)
		if t_min > t_max:
			return false
	return true
