class_name CombatEventQueue
extends RefCounted

var _events: Array = []
var _event_ids: Dictionary = {}


func enqueue(event: CombatEvent) -> bool:
	if event == null or _event_ids.has(event.event_id):
		return false
	_events.append(event)
	_event_ids[event.event_id] = true
	_events.sort_custom(_event_precedes)
	return true


func pop_next() -> CombatEvent:
	if _events.is_empty():
		return null
	var event: CombatEvent = _events.pop_front()
	_event_ids.erase(event.event_id)
	return event


func peek_next() -> CombatEvent:
	if _events.is_empty():
		return null
	return _events.front()


func size() -> int:
	return _events.size()


func is_empty() -> bool:
	return _events.is_empty()


func clear() -> void:
	_events.clear()
	_event_ids.clear()


func cancel_action_events(action_instance_id: String) -> PackedStringArray:
	var canceled := PackedStringArray()
	var retained: Array = []
	for event: CombatEvent in _events:
		var event_action_id := String(event.payload.get("action_instance_id", ""))
		if event_action_id == action_instance_id and (event.event_type == &"action_act_due" or event.event_type == &"action_finalize_due"):
			canceled.append(event.event_id)
			_event_ids.erase(event.event_id)
		else:
			retained.append(event)
	_events = retained
	return canceled


func cancel_actor_events(actor_ids: PackedStringArray) -> PackedStringArray:
	var actor_set := {}
	for actor_id: String in actor_ids:
		actor_set[actor_id] = true
	var canceled := PackedStringArray()
	var retained: Array = []
	for event: CombatEvent in _events:
		if actor_set.has(String(event.source_actor_id)) or actor_set.has(String(event.target_actor_id)):
			canceled.append(event.event_id)
			_event_ids.erase(event.event_id)
		else:
			retained.append(event)
	_events = retained
	return canceled


func drain() -> Array:
	var ordered_events: Array = _events.duplicate()
	_events.clear()
	_event_ids.clear()
	return ordered_events


func pop_due(up_to_timestamp_us: int) -> Array:
	assert(up_to_timestamp_us >= 0, "Due-event timestamps cannot be negative.")
	var due_events: Array = []
	while not _events.is_empty() and (_events.front() as CombatEvent).timestamp_us <= up_to_timestamp_us:
		due_events.append(pop_next())
	return due_events


func snapshot() -> Array:
	var serialized_events: Array = []
	for event: CombatEvent in _events:
		serialized_events.append(event.to_dictionary())
	return serialized_events


static func _event_precedes(left: CombatEvent, right: CombatEvent) -> bool:
	if left.timestamp_us != right.timestamp_us:
		return left.timestamp_us < right.timestamp_us
	if left.initiative != right.initiative:
		return left.initiative > right.initiative
	if left.stable_sequence != right.stable_sequence:
		return left.stable_sequence < right.stable_sequence
	return left.event_id < right.event_id
