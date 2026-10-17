class_name ArenaFloatingCombatText
extends Node2D

const Mapper = preload("res://scripts/ui/combat_floating_text_mapper.gd")

const MAX_ACTIVE_MESSAGES := 10
const MAX_ACTIVE_PER_ACTOR := 4
const LANE_COUNT := 3
const BASE_DURATION_SECONDS := 0.9
const IMPORTANT_DURATION_SECONDS := 1.15
const SAFE_TOP_PIXELS := 90.0
const EDGE_MARGIN_PIXELS := 6.0
const LABEL_SIZE := Vector2(190.0, 28.0)
const CROWDED_ACTOR_DISTANCE_PIXELS := 210.0
const CROWDED_HORIZONTAL_OFFSET_PIXELS := 58.0

@export var player_path: NodePath
@export var opponent_path: NodePath

var _presented_event_ids: Dictionary = {}
var _active_messages: Array[Dictionary] = []
var _next_local_message_sequence: int = 0

@onready var _player: Node2D = get_node_or_null(player_path)
@onready var _opponent: Node2D = get_node_or_null(opponent_path)


func present_authoritative_event(event: CombatEvent) -> void:
	if event == null or not Mapper.supports_event_type(event.event_type) or _presented_event_ids.has(event.event_id):
		return
	var intents: Array = Mapper.messages_for_event(event)
	if intents.is_empty():
		return
	_presented_event_ids[event.event_id] = true
	for intent: Dictionary in intents:
		_add_message(intent, event.event_id)


func present_local_selection(actor_id: StringName, text: String) -> void:
	_next_local_message_sequence += 1
	_add_message(
		{"actor_id": actor_id, "text": text, "category": "selection", "priority": 3},
		"local_selection_%06d" % _next_local_message_sequence
	)


func clear() -> void:
	for message: Dictionary in _active_messages:
		var label: Label = message.get("label")
		if is_instance_valid(label):
			label.queue_free()
	_active_messages.clear()
	_presented_event_ids.clear()
	_next_local_message_sequence = 0


func get_active_messages_for_testing() -> Array[Dictionary]:
	var snapshot: Array[Dictionary] = []
	for message: Dictionary in _active_messages:
		snapshot.append({
			"actor_id": String(message.get("actor_id", "")),
			"text": String(message.get("text", "")),
			"priority": int(message.get("priority", 0)),
			"lane": int(message.get("lane", 0)),
		})
	return snapshot


func get_presented_event_id_count_for_testing() -> int:
	return _presented_event_ids.size()


func _process(delta: float) -> void:
	for index in range(_active_messages.size() - 1, -1, -1):
		var message: Dictionary = _active_messages[index]
		var age := float(message.get("age", 0.0)) + delta
		var duration := float(message.get("duration", BASE_DURATION_SECONDS))
		var label: Label = message.get("label")
		if age >= duration or not is_instance_valid(label):
			if is_instance_valid(label):
				label.queue_free()
			_active_messages.remove_at(index)
			continue
		message["age"] = age
		label.modulate.a = clampf(1.0 - maxf(0.0, (age / duration - 0.55) / 0.45), 0.0, 1.0)
		_place_message(label, StringName(message.get("actor_id", "")), int(message.get("lane", 0)), age)


func _add_message(intent: Dictionary, event_id: String) -> void:
	var actor_id := StringName(intent.get("actor_id", ""))
	if _actor_node(actor_id) == null:
		return
	var priority := int(intent.get("priority", 0))
	var category := String(intent.get("category", "neutral"))
	if category == "failure" and priority <= 1 and _combine_recent_low_priority_failure(actor_id):
		return
	if _active_messages.size() >= MAX_ACTIVE_MESSAGES or _count_for_actor(actor_id) >= MAX_ACTIVE_PER_ACTOR:
		if not _evict_lower_priority_message(actor_id, priority):
			return
	var label := Label.new()
	label.text = String(intent.get("text", ""))
	label.size = LABEL_SIZE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 10
	label.add_theme_font_size_override("font_size", 16 if priority < 6 else 18)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color(0.015, 0.025, 0.04, 0.96))
	label.add_theme_color_override("font_color", _color_for_category(String(intent.get("category", "neutral"))))
	add_child(label)
	var lane := _next_lane(actor_id)
	_active_messages.append({
		"event_id": event_id,
		"actor_id": actor_id,
		"text": label.text,
		"category": category,
		"priority": priority,
		"lane": lane,
		"label": label,
		"age": 0.0,
		"duration": IMPORTANT_DURATION_SECONDS if priority >= 5 else BASE_DURATION_SECONDS,
	})
	_place_message(label, actor_id, lane, 0.0)


func _combine_recent_low_priority_failure(actor_id: StringName) -> bool:
	for index in range(_active_messages.size() - 1, -1, -1):
		var message: Dictionary = _active_messages[index]
		if StringName(message.get("actor_id", "")) != actor_id or String(message.get("category", "")) != "failure" or int(message.get("priority", 0)) > 1:
			continue
		if float(message.get("age", 0.0)) > 0.25:
			continue
		var count := int(message.get("combined_count", 1)) + 1
		message["combined_count"] = count
		message["text"] = "DEFENSES FAILED x%d" % count
		message["age"] = 0.0
		var label: Label = message.get("label")
		if is_instance_valid(label):
			label.text = String(message["text"])
		return true
	return false


func _evict_lower_priority_message(actor_id: StringName, incoming_priority: int) -> bool:
	var candidate_index := -1
	var candidate_priority := incoming_priority
	for index in range(_active_messages.size()):
		var message: Dictionary = _active_messages[index]
		if StringName(message.get("actor_id", "")) != actor_id and _active_messages.size() < MAX_ACTIVE_MESSAGES:
			continue
		var priority := int(message.get("priority", 0))
		if priority < candidate_priority:
			candidate_priority = priority
			candidate_index = index
	if candidate_index < 0:
		return false
	var label: Label = _active_messages[candidate_index].get("label")
	if is_instance_valid(label):
		label.queue_free()
	_active_messages.remove_at(candidate_index)
	return true


func _count_for_actor(actor_id: StringName) -> int:
	var count := 0
	for message: Dictionary in _active_messages:
		if StringName(message.get("actor_id", "")) == actor_id:
			count += 1
	return count


func _next_lane(actor_id: StringName) -> int:
	return _count_for_actor(actor_id) % LANE_COUNT


func _place_message(label: Label, actor_id: StringName, lane: int, age: float) -> void:
	var actor := _actor_node(actor_id)
	if actor == null:
		return
	var horizontal_offset := 0.0
	if _player != null and _opponent != null and _player.global_position.distance_to(_opponent.global_position) < CROWDED_ACTOR_DISTANCE_PIXELS:
		horizontal_offset = -CROWDED_HORIZONTAL_OFFSET_PIXELS if actor_id == PrimeV3VerticalSliceFixture.PLAYER_ID else CROWDED_HORIZONTAL_OFFSET_PIXELS
	var desired := actor.global_position + Vector2(-LABEL_SIZE.x * 0.5 + horizontal_offset, -100.0 - lane * 25.0 - age * 18.0)
	var visible_rect := get_viewport().get_visible_rect()
	desired.x = clampf(desired.x, visible_rect.position.x + EDGE_MARGIN_PIXELS, visible_rect.end.x - LABEL_SIZE.x - EDGE_MARGIN_PIXELS)
	desired.y = clampf(desired.y, visible_rect.position.y + SAFE_TOP_PIXELS, visible_rect.end.y - LABEL_SIZE.y - EDGE_MARGIN_PIXELS)
	label.global_position = desired


func _actor_node(actor_id: StringName) -> Node2D:
	if actor_id == PrimeV3VerticalSliceFixture.PLAYER_ID:
		return _player
	if actor_id == PrimeV3VerticalSliceFixture.OPPONENT_ID:
		return _opponent
	return null


static func _color_for_category(category: String) -> Color:
	match category:
		"defense":
			return Color(0.42, 0.94, 0.62, 1.0)
		"critical_success":
			return Color(1.0, 0.82, 0.26, 1.0)
		"critical_failure", "failure", "defeat":
			return Color(1.0, 0.33, 0.33, 1.0)
		"damage":
			return Color(1.0, 0.5, 0.22, 1.0)
	return Color(0.93, 0.96, 1.0, 1.0)
