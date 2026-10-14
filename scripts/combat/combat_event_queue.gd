class_name CombatEventQueue
extends RefCounted

var _events: Array = []
var _event_ids: Dictionary = {}


func enqueue(event: CombatEvent) -> void:
	assert(event != null, "Cannot enqueue a null combat event.")
	assert(not _event_ids.has(event.event_id), "Combat event identifiers must be unique within a queue.")
	_events.append(event)
	_event_ids[event.event_id] = true
	_events.sort_custom(_event_precedes)


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


func drain() -> Array:
	var ordered_events: Array = _events.duplicate()
	_events.clear()
	_event_ids.clear()
	return ordered_events


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
