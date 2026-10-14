class_name SynchronizationReport
extends RefCounted


static func compare_clients(clients: Array) -> Dictionary:
	if clients.size() < 2:
		return {
			"success": false,
			"message": "Synchronization comparison requires at least two observed clients.",
			"mismatches": [],
		}

	var reference: ObservedCombatClient = clients[0]
	var reference_digest := reference.get_state_digest()
	var mismatches: Array = []
	for index in range(1, clients.size()):
		var client: ObservedCombatClient = clients[index]
		var client_digest := client.get_state_digest()
		if client_digest == reference_digest and not client.has_failure():
			continue
		mismatches.append({
			"client_id": client.client_id,
			"digest": client_digest,
			"event_count": client.get_applied_event_count(),
			"local_failure": client.get_failure_report(),
		})

	if mismatches.is_empty() and not reference.has_failure():
		return {
			"success": true,
			"message": "Clients are synchronized at digest %s after %d authoritative events." % [
				reference_digest,
				reference.get_applied_event_count(),
			],
			"reference_client_id": reference.client_id,
			"reference_digest": reference_digest,
			"mismatches": [],
		}

	var details := PackedStringArray()
	if reference.has_failure():
		details.append("reference client '%s' local failure: %s" % [reference.client_id, reference.get_failure_report()])
	for mismatch: Dictionary in mismatches:
		details.append(
			"client '%s' digest %s after %d events; local failure: %s" % [
				mismatch["client_id"],
				mismatch["digest"],
				mismatch["event_count"],
				mismatch["local_failure"] if not mismatch["local_failure"].is_empty() else "none",
			]
		)
	return {
		"success": false,
		"message": "Synchronization failure against reference client '%s' digest %s after %d events: %s" % [
			reference.client_id,
			reference_digest,
			reference.get_applied_event_count(),
			"; ".join(details),
		],
		"reference_client_id": reference.client_id,
		"reference_digest": reference_digest,
		"mismatches": mismatches,
	}
