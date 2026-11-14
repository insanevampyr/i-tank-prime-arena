class_name CharacterDevelopment
extends RefCounted

# Optional V2 extension, carried in schema-12's existing progression dictionary.
# Immutable command history; no UI, storage, RNG or resource restoration.
const DEFAULT_ORDER := ["nac","dodge","block","soak"]
const STANDARD_POLICY := "standard_pool9_dt6_dp3"

static func starting(policy: String, pool: int) -> Dictionary:
	if policy != STANDARD_POLICY or pool != 9: return fail("starting_allocation_policy_unverified")
	return DexAllocation.create(pool,6,3)

static func create(dex: int, dt: int, dp: int) -> Dictionary:
	var initial := DexAllocation.create(dex,dt,dp)
	if not initial.success: return initial
	return {"success":true,"record":{"version":1,"baseline":initial.state.baseline,"commands":[]}}

static func inspect(record: Dictionary) -> Dictionary:
	if record.size() != 3 or record.get("version") != 1 or not record.get("baseline") is Dictionary or not record.get("commands") is Array: return fail("invalid_development_record")
	var b: Dictionary = record.baseline
	if b.size() != 3: return fail("invalid_development_baseline")
	for key: String in ["dex","dt","dp"]:
		if typeof(b.get(key)) != TYPE_INT: return fail("invalid_development_baseline")
	var initial := DexAllocation.create(b.dex,b.dt,b.dp)
	if not initial.success: return initial
	var allocation: Dictionary = initial.state
	var preferences := DEFAULT_ORDER.duplicate()
	var ids := {}
	for command: Variant in record.commands:
		if not command is Dictionary or command.size() != 3 or not command.get("id") is String or command.id.is_empty() or ids.has(command.id) or not command.get("payload") is Dictionary: return fail("invalid_or_duplicate_development_command")
		if command.get("kind") == "preferences":
			if command.payload.size() != 1 or not command.payload.get("order") is Array or not DefensivePreferences.valid(command.payload.order): return fail("invalid_defense_preferences")
			preferences = command.payload.order.duplicate()
		elif command.get("kind") == "dex_purchase":
			var p: Dictionary = command.payload
			var totals: Dictionary = DexAllocation.validate(allocation).totals
			if p.size() != 3 or typeof(p.get("before")) != TYPE_INT or typeof(p.get("after")) != TYPE_INT or p.get("allocation") not in ["dt","dp"] or p.before != totals.dex or p.after != p.before+1 or p.before < 1 or p.after > 20 or command.id != "dex_purchase_%s" % p.after: return fail("invalid_dex_purchase_allocation")
			var grant := DexAllocation.request(allocation,{"op":"grant","id":command.id+"_grant","dex":p.after})
			if not grant.success: return grant
			var assigned := DexAllocation.request(grant.state,{"op":"allocate","id":command.id+"_allocate","dt":1 if p.allocation == "dt" else 0,"dp":1 if p.allocation == "dp" else 0,"confirmed":true})
			if not assigned.success: return assigned
			allocation = assigned.state
		elif command.get("kind") == "allocation":
			var result := DexAllocation.request(allocation,command.payload)
			if not result.success: return result
			allocation = result.state
		else: return fail("unsupported_development_command")
		ids[command.id] = true
	return {"success":true,"allocation":allocation,"preferences":preferences,"ids":ids}

static func append(record: Dictionary, id: String, kind: String, payload: Dictionary) -> Dictionary:
	var checked := inspect(record)
	if not checked.success: return checked
	if id.is_empty() or checked.ids.has(id): return fail("duplicate_or_missing_development_request")
	var candidate := record.duplicate(true)
	candidate.commands.append({"id":id,"kind":kind,"payload":payload.duplicate(true)})
	checked = inspect(candidate)
	if not checked.success: return checked
	return {"success":true,"record":candidate}

static func continuity(previous: Dictionary, candidate: Dictionary) -> bool:
	if not inspect(candidate).success: return false
	if previous.is_empty(): return true
	return inspect(previous).success and previous.baseline == candidate.baseline and candidate.commands.slice(0,previous.commands.size()) == previous.commands

static func validate_source(record: Dictionary, source: CombatCharacterDefinitionResource, purchases: Array = []) -> bool:
	var checked := inspect(record)
	if not checked.success: return false
	var expected := {"dex":source.attributes.get("dex"),"dt":source.combat_stats.get("dt"),"dp":source.combat_stats.get("dp")}
	if record.baseline != expected: return false
	var expected_dex: int = source.attributes.get("dex",-1)
	var expected_commands: Array = []
	for purchase: Dictionary in purchases:
		if not purchase.get("purchase_kind") is String or not purchase.get("target_id") is String or purchase.purchase_kind != "attribute" or purchase.target_id != "dex": continue
		for field: String in ["value_before","value_after","cost"]:
			if typeof(purchase.get(field)) != TYPE_INT: return false
		if not purchase.get("allocation") is String: return false
		if purchase.get("value_before") != expected_dex or purchase.get("value_after") != expected_dex+1 or purchase.get("allocation") not in ["dt","dp"] or purchase.get("cost") != PrimeV3AdvancementCatalog.attribute_cost(expected_dex): return false
		expected_dex += 1
		expected_commands.append({"id":"dex_purchase_%s" % expected_dex,"kind":"dex_purchase","payload":{"before":expected_dex-1,"after":expected_dex,"allocation":purchase.allocation}})
	var actual: Array = record.commands.filter(func(c): return c.kind == "dex_purchase")
	return actual == expected_commands and DexAllocation.contributions(checked.allocation).permanent_dex == expected_dex

static func fail(reason: String) -> Dictionary:
	return {"success":false,"reason":reason}
