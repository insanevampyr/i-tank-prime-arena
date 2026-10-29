class_name CharacterSaveContract
extends RefCounted

# A proposal/serialization contract only. No filesystem or gameplay callers.
const FORMAT := "itank_arena_character"
const VERSION := 1
const MAX_SAFE_INTEGER := 9_007_199_254_740_991
const PAYLOAD_KEYS := ["character_id", "definition_id", "rules_revision", "generation", "base_attributes", "xp", "purchases", "items", "secured_checkpoints"]


static func validate(payload: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	for key: Variant in payload:
		if not PAYLOAD_KEYS.has(String(key)): errors.append("unsupported_field:%s" % key)
	for key: String in PAYLOAD_KEYS:
		if not payload.has(key): errors.append("missing_field:%s" % key)
	for key: String in ["character_id", "definition_id", "rules_revision"]:
		if typeof(payload.get(key)) != TYPE_STRING or String(payload.get(key, "")).is_empty(): errors.append("invalid_identity:%s" % key)
	if not _integer(payload.get("generation"), 1): errors.append("invalid_generation")
	var attributes: Variant = payload.get("base_attributes")
	if not attributes is Dictionary or attributes.is_empty():
		errors.append("invalid_base_attributes")
	else:
		for key: Variant in attributes:
			if not _integer(attributes[key], 0): errors.append("invalid_attribute:%s" % key)
	var xp: Variant = payload.get("xp")
	if not xp is Dictionary or not xp.has_all(["earned", "spent", "unspent"]):
		errors.append("invalid_xp")
	else:
		if xp.size() != 3: errors.append("unsupported_xp_field")
		for key: String in ["earned", "spent", "unspent"]:
			if not _integer(xp[key], 0): errors.append("invalid_xp:%s" % key)
		if errors.is_empty() and (xp.spent > xp.earned or xp.unspent != xp.earned - xp.spent): errors.append("xp_accounting_mismatch")
	_validate_records(payload.get("purchases"), "purchase_id", errors, "purchase")
	_validate_records(payload.get("items"), "instance_id", errors, "item")
	var slots := {}
	var items: Variant = payload.get("items")
	if items is Array:
		for item: Variant in items:
			if not item is Dictionary: continue
			if not item.has_all(["definition_id", "quantity", "provenance", "equipped_slots", "mutable_state"]):
				errors.append("incomplete_item")
				continue
			if typeof(item.definition_id) != TYPE_STRING or String(item.definition_id).is_empty(): errors.append("invalid_item_definition")
			if not _integer(item.quantity, 1): errors.append("invalid_item_quantity")
			if not item.provenance is Dictionary or item.provenance.is_empty(): errors.append("missing_item_provenance")
			if not item.mutable_state is Dictionary: errors.append("invalid_item_mutable_state")
			if not item.equipped_slots is Array:
				errors.append("invalid_equipped_slots")
				continue
			if not item.equipped_slots.is_empty() and item.quantity != 1: errors.append("equipped_stack_not_allowed")
			for slot: Variant in item.equipped_slots:
				if typeof(slot) != TYPE_STRING or String(slot).is_empty() or slots.has(slot): errors.append("duplicate_or_invalid_equipment_slot")
				slots[slot] = true
	var checkpoints: Variant = payload.get("secured_checkpoints")
	if not checkpoints is Array:
		errors.append("invalid_checkpoints")
	else:
		var seen := {}
		for checkpoint: Variant in checkpoints:
			if typeof(checkpoint) != TYPE_STRING or String(checkpoint).is_empty() or seen.has(checkpoint): errors.append("duplicate_or_invalid_checkpoint")
			seen[checkpoint] = true
	return {"success": errors.is_empty(), "errors": errors}


static func encode(payload: Dictionary) -> Dictionary:
	var validation := validate(payload)
	if not validation.success: return validation
	var serialized := JSON.stringify(payload, "", true, true)
	return {"success": true, "text": JSON.stringify({
		"format": FORMAT, "version": VERSION, "payload_json": serialized,
		"sha256": serialized.sha256_text(),
	}, "", true, true)}


static func decode(text: String) -> Dictionary:
	var parser := JSON.new()
	if parser.parse(text) != OK or not parser.data is Dictionary:
		return {"success": false, "reason": "invalid_json"}
	var envelope: Dictionary = parser.data
	if envelope.get("format") != FORMAT or envelope.get("version") != VERSION:
		return {"success": false, "reason": "unsupported_format_or_version"}
	if envelope.size() != 4 or typeof(envelope.get("payload_json")) != TYPE_STRING or typeof(envelope.get("sha256")) != TYPE_STRING:
		return {"success": false, "reason": "invalid_envelope"}
	var serialized := String(envelope.payload_json)
	if serialized.sha256_text() != envelope.sha256:
		return {"success": false, "reason": "checksum_mismatch"}
	if parser.parse(serialized) != OK or not parser.data is Dictionary:
		return {"success": false, "reason": "invalid_payload_json"}
	var payload: Dictionary = parser.data
	var validation := validate(payload)
	if not validation.success: return validation
	return {"success": true, "payload": _normalize_json_numbers(payload)}


static func _normalize_json_numbers(value: Variant) -> Variant:
	if value is Dictionary:
		var result := {}
		for key: Variant in value: result[key] = _normalize_json_numbers(value[key])
		return result
	if value is Array:
		var result: Array = []
		for entry: Variant in value: result.append(_normalize_json_numbers(entry))
		return result
	if typeof(value) == TYPE_FLOAT and _integer(value, 0): return int(value)
	return value


static func validate_replacement(current: Dictionary, candidate: Dictionary) -> Dictionary:
	for payload: Dictionary in [current, candidate]:
		var result := validate(payload)
		if not result.success: return result
	if current.character_id != candidate.character_id:
		return {"success": false, "reason": "character_identity_mismatch"}
	if candidate.generation != current.generation + 1:
		return {"success": false, "reason": "stale_or_nonsequential_generation"}
	for checkpoint: Variant in current.secured_checkpoints:
		if not candidate.secured_checkpoints.has(checkpoint): return {"success": false, "reason": "secured_checkpoint_removed"}
	return {"success": true}


static func _integer(value: Variant, minimum: int) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(float(value)) and value >= minimum and value <= MAX_SAFE_INTEGER and floor(float(value)) == float(value)


static func _validate_records(records: Variant, id_key: String, errors: Array[String], kind: String) -> void:
	if not records is Array:
		errors.append("invalid_%s_records" % kind)
		return
	var seen := {}
	for record: Variant in records:
		if not record is Dictionary or typeof(record.get(id_key)) != TYPE_STRING or String(record.get(id_key, "")).is_empty():
			errors.append("invalid_%s_identity" % kind)
			continue
		if seen.has(record[id_key]): errors.append("duplicate_%s_identity" % kind)
		seen[record[id_key]] = true
