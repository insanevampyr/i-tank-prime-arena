class_name CombatEventEnvelope
extends RefCounted

var protocol_sequence: int
var combat_event: Dictionary
var state_snapshot: Dictionary


func _init(p_protocol_sequence: int, p_combat_event: Dictionary, p_state_snapshot: Dictionary = {}) -> void:
	assert(p_protocol_sequence >= 0, "Protocol sequence numbers cannot be negative.")
	assert(not p_combat_event.is_empty(), "Authoritative envelopes require combat event data.")
	protocol_sequence = p_protocol_sequence
	combat_event = p_combat_event.duplicate(true)
	state_snapshot = p_state_snapshot.duplicate(true)


func to_dictionary() -> Dictionary:
	return {
		"protocol_sequence": protocol_sequence,
		"combat_event": combat_event.duplicate(true),
		"state_snapshot": state_snapshot.duplicate(true),
	}
