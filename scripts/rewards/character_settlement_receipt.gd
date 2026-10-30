class_name CharacterSettlementReceipt
extends RefCounted

const Contract = preload("res://scripts/rewards/character_save_contract.gd")
const Identity = preload("res://scripts/rewards/character_save_storage.gd")
const FIELDS := ["version","receipt_id","profile_id","run_id","wave_id","claim_id","kind","content"]

static func validate(receipt: Dictionary) -> Dictionary:
	if receipt.size() != FIELDS.size() or not receipt.has_all(FIELDS): return _fail("invalid_settlement_fields")
	if receipt.version != 1: return _fail("unsupported_settlement_version")
	for field: String in ["profile_id","run_id","wave_id","claim_id"]:
		if not receipt[field] is String or not Identity._valid_id(receipt[field]): return _fail("invalid_settlement_identity")
	if receipt.receipt_id != "/".join([receipt.profile_id,receipt.run_id,receipt.wave_id,receipt.claim_id]): return _fail("settlement_namespace_mismatch")
	if not receipt.content is Dictionary: return _fail("invalid_settlement_content")
	var content: Dictionary = receipt.content
	var keys: Array = []
	match receipt.kind:
		"xp": keys = ["award_id","amount"]
		"purchase": keys = ["purchase_id","cost"]
		"item", "currency": keys = ["instance_id","definition_id","quantity","provenance_digest"]
		_: return _fail("unsupported_settlement_kind")
	if content.size() != keys.size() or not content.has_all(keys): return _fail("invalid_settlement_content")
	for key: String in keys:
		if key in ["amount","cost","quantity"]:
			if not Contract._integer(content[key],0 if key == "amount" else 1): return _fail("invalid_settlement_quantity")
		elif not content[key] is String or content[key].is_empty(): return _fail("invalid_settlement_reference")
	return {"success":true}

static func effect_id(receipt: Dictionary) -> String:
	match receipt.kind:
		"xp": return "xp:"+String(receipt.content.award_id)
		"purchase": return "purchase:"+String(receipt.content.purchase_id)
	return "item:"+String(receipt.content.instance_id)

static func _fail(reason: String) -> Dictionary:
	return {"success":false,"reason":reason}
