extends RefCounted

const Contract = preload("res://scripts/rewards/character_save_contract.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	var payload := _fixture()
	var encoded := Contract.encode(payload)
	if not encoded.get("success", false):
		return ["Valid isolated save contract failed encoding: %s" % encoded]
	var decoded := Contract.decode(encoded.text)
	if not decoded.get("success", false) or decoded.get("payload") != payload:
		failures.append("JSON roundtrip must retain exact XP, identities, provenance and SHP.")
	if Contract.encode(payload).text != encoded.text: failures.append("Serialization must be deterministic.")
	for field: String in ["position_microfeet", "current_hpc", "test_mode", "reward_state", "rng"]:
		var invalid := payload.duplicate(true)
		invalid[field] = 1
		if Contract.validate(invalid).success: failures.append("Temporary/test snapshot field accepted: %s" % field)
	var duplicate := payload.duplicate(true)
	duplicate.items.append(duplicate.items[0].duplicate(true))
	if Contract.validate(duplicate).success: failures.append("Duplicate item instance accepted.")
	duplicate = payload.duplicate(true)
	duplicate.purchases.append(duplicate.purchases[0].duplicate(true))
	if Contract.validate(duplicate).success: failures.append("Duplicate purchase accepted.")
	var bad_xp := payload.duplicate(true)
	bad_xp.xp.unspent = 99
	if Contract.validate(bad_xp).success: failures.append("Inconsistent XP accepted.")
	var envelope: Dictionary = JSON.parse_string(encoded.text)
	envelope.payload_json += " "
	if Contract.decode(JSON.stringify(envelope)).get("reason") != "checksum_mismatch": failures.append("Corruption was not detected.")
	envelope = JSON.parse_string(encoded.text)
	envelope.version = 2
	if Contract.decode(JSON.stringify(envelope)).get("success", false): failures.append("Future version accepted without migration.")
	if Contract.decode("{").get("success", false): failures.append("Truncated JSON accepted.")
	var next := payload.duplicate(true)
	next.generation = 2
	if not Contract.validate_replacement(payload, next).success: failures.append("Sequential replacement rejected.")
	if Contract.validate_replacement(next, payload).success: failures.append("Stale replacement accepted.")
	next.secured_checkpoints.clear()
	if Contract.validate_replacement(payload, next).success: failures.append("Secured checkpoint removal accepted.")
	if payload.items[0].mutable_state.shp != 7: failures.append("Contract mutated its input.")
	return failures


func _fixture() -> Dictionary:
	return {
		"character_id": "isolated:character:1", "definition_id": "isolated:definition",
		"rules_revision": "isolated-contract-test", "generation": 1,
		"base_attributes": {"str": 10}, "xp": {"earned": 2000, "spent": 1000, "unspent": 1000},
		"purchases": [{"purchase_id": "isolated:purchase:1", "source_ref": "test-only"}],
		"items": [{"instance_id": "isolated:item:1", "definition_id": "isolated:shield", "quantity": 1,
			"provenance": {"run_id": "isolated:run:1", "event_id": "isolated:event:1"},
			"equipped_slots": ["shield"], "mutable_state": {"shp": 7}}],
		"secured_checkpoints": ["isolated:run:1:wave:1"],
	}
