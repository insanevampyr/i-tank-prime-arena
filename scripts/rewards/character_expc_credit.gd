extends RefCounted

# One owner-authorized maintenance grant. No player command, UI or startup caller.
const GRANT_ID := "2a3dc1f6-3870-46f0-bf50-bcce11e77c6b"
const AMOUNT := 10000
const PROFILE := "dev_vaelis_thorn"
const BASELINE := "3df0412b72ba5d966b2eb645887fedfbb591782cffc7bff41c192e52583c6d20"

static func digest(value: Dictionary) -> String:
	return JSON.stringify(value,"",true,true).sha256_text()

static func inspect(payload: Dictionary) -> Dictionary:
	if not payload.has("expc_credits"): return {"success":true,"total":0}
	var extension: Variant = payload.expc_credits
	if not extension is Dictionary or extension.size() != 2 or extension.get("version") != 1 or not extension.get("records") is Array or extension.records.size() != 1: return fail("invalid_expc_credits")
	var row: Variant = extension.records[0]
	if not row is Dictionary or row.size() != 5 or not row.has_all(["grant_id","profile_id","amount","after_generation","head_digest"]): return fail("invalid_expc_credit")
	var lineage: Variant = payload.get("lineage")
	if payload.get("character_id") != PROFILE or payload.get("profile_namespace") != "dev_normal" or not lineage is Dictionary or lineage.get("baseline_digest") != BASELINE: return fail("expc_credit_profile_mismatch")
	if row.grant_id != GRANT_ID or row.profile_id != PROFILE or typeof(row.amount) != TYPE_INT or row.amount != AMOUNT: return fail("unsupported_expc_credit")
	if typeof(payload.get("generation")) != TYPE_INT or typeof(row.after_generation) != TYPE_INT or row.after_generation < 1 or row.after_generation >= payload.generation or not row.head_digest is String or row.head_digest.length() != 64 or not row.head_digest.is_valid_hex_number(false): return fail("invalid_expc_credit_head")
	return {"success":true,"total":AMOUNT}

static func continuity(current: Dictionary, next: Dictionary) -> Dictionary:
	var checked := inspect(next)
	if not checked.success: return checked
	if current.has("expc_credits"):
		return {"success":true} if next.get("expc_credits") == current.expc_credits else fail("expc_credit_history_changed")
	if not next.has("expc_credits"): return {"success":true}
	var row: Dictionary = next.expc_credits.records[0]
	if row.after_generation != current.get("generation") or row.head_digest != digest(current): return fail("expc_credit_stale_head")
	return {"success":true}

# Pure preparation only. A trusted host must confirm this exact head binding,
# then use the existing coordinator, writer ownership and verified readback.
# Neither this function nor its absence from gameplay grants access to storage.
static func prepare(current: Dictionary, confirmation: Callable = Callable()) -> Dictionary:
	if not CharacterSaveContract.validate(current).get("success",false): return fail("invalid_credit_source")
	if current.get("character_id") != PROFILE or current.get("profile_namespace") != "dev_normal" or current.get("lineage",{}).get("baseline_digest") != BASELINE: return fail("expc_credit_profile_mismatch")
	if current.has("expc_credits"): return {"success":true,"no_op":true,"payload":current.duplicate(true)}
	if not current.get("recovery") is Dictionary or not current.recovery.get("ledger") is Dictionary: return fail("credit_requires_verified_checkpoint")
	var binding := {"grant_id":GRANT_ID,"profile_id":PROFILE,"namespace":"dev_normal","amount":AMOUNT,"generation":current.generation,"head_digest":digest(current)}
	if not confirmation.is_valid(): return fail("expc_credit_confirmation_required")
	var approval: Variant = confirmation.call(binding.duplicate(true))
	if not approval is Dictionary or not approval.get("confirmed",false) or approval.get("binding") != digest(binding): return fail("expc_credit_confirmation_required")
	var next := current.duplicate(true)
	next.generation += 1
	next["expc_credits"] = {"version":1,"records":[{"grant_id":GRANT_ID,"profile_id":PROFILE,"amount":AMOUNT,"after_generation":current.generation,"head_digest":binding.head_digest}]}
	next.xp.unspent += AMOUNT
	next.recovery.ledger["expc_credit_total"] = AMOUNT
	next.recovery.ledger.unspent_xp += AMOUNT
	return {"success":true,"payload":next,"transaction_id":"expc_credit_"+GRANT_ID.replace("-","")}

static func fail(reason: String) -> Dictionary:
	return {"success":false,"reason":reason}
