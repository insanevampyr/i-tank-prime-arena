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

static func validate_source(record: Dictionary, source: CombatCharacterDefinitionResource) -> bool:
	var checked := inspect(record)
	if not checked.success: return false
	var expected := {"dex":source.attributes.get("dex"),"dt":source.combat_stats.get("dt"),"dp":source.combat_stats.get("dp")}
	if record.baseline != expected: return false
	# DEX purchases remain blocked. No new permanent attribute history is invented.
	return DexAllocation.contributions(checked.allocation).permanent_dex == source.attributes.get("dex")

static func fail(reason: String) -> Dictionary:
	return {"success":false,"reason":reason}
