class_name AuthoritativeCombatSession
extends RefCounted

var simulation: CombatSimulation

var _next_protocol_sequence: int = 0
var _published_transcript: Array = []


func _init(seed_value: int) -> void:
	simulation = CombatSimulation.new(seed_value)


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
	return simulation.schedule_event(
		timestamp_us,
		event_type,
		initiative,
		source_actor_id,
		target_actor_id,
		payload,
		parent_event_id,
		dependency_event_ids,
		resource_commitments
	)


func publish_resolved_events() -> Array:
	var envelopes: Array = []
	for event: CombatEvent in simulation.event_queue.drain():
		var envelope := CombatEventEnvelope.new(_next_protocol_sequence, event.to_dictionary())
		_next_protocol_sequence += 1
		envelopes.append(envelope)
		_published_transcript.append(envelope.to_dictionary())
	return envelopes


func get_published_transcript() -> Array:
	return _published_transcript.duplicate(true)


func get_state_digest() -> String:
	return SyncStateDigest.compute(_published_transcript)
