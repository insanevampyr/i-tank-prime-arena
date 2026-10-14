class_name TwoClientSyncHarness
extends RefCounted

var authority: AuthoritativeCombatSession
var client_a: ObservedCombatClient
var client_b: ObservedCombatClient


func _init(seed_value: int) -> void:
	authority = AuthoritativeCombatSession.new(seed_value)
	client_a = ObservedCombatClient.new("client_a")
	client_b = ObservedCombatClient.new("client_b")


func deliver_in_order(envelopes: Array) -> void:
	for envelope: CombatEventEnvelope in envelopes:
		client_a.receive(envelope)
		client_b.receive(envelope)


func compare_clients() -> Dictionary:
	return SynchronizationReport.compare_clients([client_a, client_b])
