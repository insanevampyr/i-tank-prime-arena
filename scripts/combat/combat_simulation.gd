class_name CombatSimulation
extends RefCounted

var clock: CombatClock
var event_queue: CombatEventQueue
var random: DeterministicCombatRng

var _next_sequence: int = 0


func _init(seed_value: int) -> void:
	clock = CombatClock.new()
	event_queue = CombatEventQueue.new()
	random = DeterministicCombatRng.new(seed_value)


func schedule_event(
	timestamp_us: int,
	event_type: StringName,
	initiative: int,
	source_actor_id: StringName = &"",
	target_actor_id: StringName = &"",
	payload: Dictionary = {},
	parent_event_id: String = "",
	dependency_event_ids: PackedStringArray = PackedStringArray(),
	resource_commitments: Dictionary = {}
) -> CombatEvent:
	assert(timestamp_us >= 0, "Combat event timestamps cannot be negative.")
	var sequence := _next_sequence
	_next_sequence += 1
	var event := CombatEvent.new(
		_make_event_id(sequence),
		timestamp_us,
		initiative,
		sequence,
		event_type,
		source_actor_id,
		target_actor_id,
		parent_event_id,
		dependency_event_ids,
		payload,
		resource_commitments
	)
	event_queue.enqueue(event)
	return event


func roll_int(min_inclusive: int, max_inclusive: int) -> int:
	return random.next_int(min_inclusive, max_inclusive)


func _make_event_id(sequence: int) -> String:
	return "event_%010d" % sequence
