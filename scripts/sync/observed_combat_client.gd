class_name ObservedCombatClient
extends RefCounted

var client_id: String

var _expected_sequence: int = 0
var _pending_by_sequence: Dictionary = {}
var _applied_by_sequence: Dictionary = {}
var _transcript: Array = []
var _failures: Array[String] = []


func _init(p_client_id: String) -> void:
	assert(not p_client_id.is_empty(), "Observed clients require a stable identifier.")
	client_id = p_client_id


func receive(envelope: CombatEventEnvelope) -> void:
	if envelope == null:
		_failures.append("Client '%s' received a null event envelope." % client_id)
		return

	var sequence := envelope.protocol_sequence
	var serialized := envelope.to_dictionary()
	if sequence < _expected_sequence:
		_compare_duplicate(sequence, serialized, _applied_by_sequence, "applied")
		return
	if _pending_by_sequence.has(sequence):
		_compare_duplicate(sequence, serialized, _pending_by_sequence, "pending")
		return

	_pending_by_sequence[sequence] = serialized
	_apply_contiguous_events()


func get_transcript() -> Array:
	return _transcript.duplicate(true)


func get_state_digest() -> String:
	return SyncStateDigest.compute(_transcript)


func get_applied_event_count() -> int:
	return _transcript.size()


func has_failure() -> bool:
	return not _failures.is_empty()


func get_failure_report() -> String:
	return "\n".join(PackedStringArray(_failures))


func _apply_contiguous_events() -> void:
	while _pending_by_sequence.has(_expected_sequence):
		var serialized: Dictionary = _pending_by_sequence[_expected_sequence]
		_pending_by_sequence.erase(_expected_sequence)
		_applied_by_sequence[_expected_sequence] = serialized.duplicate(true)
		_transcript.append(serialized.duplicate(true))
		_expected_sequence += 1


func _compare_duplicate(sequence: int, serialized: Dictionary, collection: Dictionary, state: String) -> void:
	if SyncStateDigest.compute(serialized) == SyncStateDigest.compute(collection[sequence]):
		return
	_failures.append(
		"Client '%s' received conflicting duplicate sequence %d for an %s event." % [client_id, sequence, state]
	)
