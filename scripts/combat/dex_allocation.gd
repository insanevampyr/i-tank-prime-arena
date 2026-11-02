class_name DexAllocation
extends RefCounted

# Isolated #37A foundation. Callers must supply authority-verified growth/source
# identities. This model grants no XP purchases, items, effects or resources.
static func create(dex: int, dt: int, dp: int) -> Dictionary:
	if mini(dex, mini(dt, dp)) < 0 or dt + dp > dex:
		return _fail("invalid_authored_allocation")
	return {"success":true,"state":{"version":1,"baseline":{"dex":dex,"dt":dt,"dp":dp},"history":[]}}

static func validate(state: Dictionary) -> Dictionary:
	if state.keys().size() != 3 or state.get("version") != 1 or not state.get("baseline") is Dictionary or not state.get("history") is Array:
		return _fail("invalid_allocation_record")
	var base: Dictionary = state.baseline
	if base.size() != 3: return _fail("invalid_allocation_baseline")
	for key: String in ["dex","dt","dp"]:
		if typeof(base.get(key)) != TYPE_INT: return _fail("invalid_allocation_integer")
	if not create(base.dex,base.dt,base.dp).success: return _fail("invalid_allocation_baseline")
	var result := {"dex":base.dex,"dt":base.dt,"dp":base.dp,"pending":base.dex-base.dt-base.dp,"sources":{},"ids":{}}
	for command: Variant in state.history:
		if not command is Dictionary: return _fail("invalid_allocation_command")
		var applied := _apply(result,command)
		if not applied.success: return applied
	return {"success":true,"totals":result}

static func request(state: Dictionary, command: Dictionary) -> Dictionary:
	var checked := validate(state)
	if not checked.success: return checked
	var applied := _apply(checked.totals,command)
	if not applied.success: return applied
	var candidate := state.duplicate(true)
	candidate.history.append(command.duplicate(true))
	return {"success":true,"state":candidate}

static func _apply(t: Dictionary, c: Dictionary) -> Dictionary:
	var op: String = c.get("op","")
	var fields: Array = {"grant":["op","id","dex"],"allocate":["op","id","dt","dp","confirmed"],"activate":["op","source","activation","points"],"remove":["op","source","activation"],"customize":["op","source","activation","dt","dp","safe_downtime","confirmed"]}.get(op,[])
	if fields.is_empty() or c.size() != fields.size() or not c.has_all(fields): return _fail("unsupported_allocation_operation")
	for key: String in ["id","source","activation"]:
		if c.has(key) and (not c[key] is String or c[key].is_empty()): return _fail("missing_authoritative_identity")
	for key: String in ["dex","dt","dp","points"]:
		if c.has(key) and (typeof(c[key]) != TYPE_INT or c[key] < 0): return _fail("negative_or_unverified_allocation")
	for key: String in ["confirmed","safe_downtime"]:
		if c.has(key) and typeof(c[key]) != TYPE_BOOL: return _fail("invalid_confirmation")
	if op in ["grant","allocate"]:
		if t.ids.has(c.id): return _fail("duplicate_allocation_receipt")
		if op == "grant":
			if c.dex <= t.dex: return _fail("permanent_growth_must_increase")
			t.pending += c.dex-t.dex
			t.dex = c.dex
		else:
			if not c.confirmed: return _fail("explicit_confirmation_required")
			if c.dt+c.dp <= 0 or c.dt+c.dp > t.pending: return _fail("allocation_exceeds_pending_points")
			t.pending -= c.dt+c.dp
			t.dt += c.dt
			t.dp += c.dp
		t.ids[c.id] = true
	else:
		# Nest identities instead of joining user-controlled delimiters.
		var activations: Dictionary = t.sources.get(c.source,{})
		var entry: Dictionary = activations.get(c.activation,{})
		if op == "activate":
			if c.points <= 0: return _fail("positive_dex_bonus_required")
			for other: String in activations:
				if other != c.activation and activations[other].active: return _fail("same_source_stacking_unverified")
			if not entry.is_empty():
				if entry.points != c.points or entry.active: return _fail("duplicate_or_changed_activation")
				entry.active = true
			else:
				entry = {"points":c.points,"dt":(c.points+1)/2,"dp":c.points/2,"locked":false,"active":true}
		elif entry.is_empty(): return _fail("unknown_activation")
		elif op == "remove":
			if not entry.active: return _fail("activation_already_removed")
			entry.active = false
		else:
			if not c.safe_downtime or not c.confirmed: return _fail("safe_confirmed_allocation_required")
			if not entry.active or entry.locked: return _fail("activation_allocation_locked_or_inactive")
			if c.dt+c.dp != entry.points: return _fail("temporary_point_conservation")
			entry.dt = c.dt
			entry.dp = c.dp
			entry.locked = true
		activations[c.activation] = entry
		t.sources[c.source] = activations
	return {"success":true}

static func contributions(state: Dictionary) -> Dictionary:
	var checked := validate(state)
	if not checked.success: return checked
	var t: Dictionary = checked.totals
	var result := {"success":true,"permanent_dex":t.dex,"pending":t.pending,"dt":t.dt,"dp":t.dp,"temporary_dex":0}
	for activations: Dictionary in t.sources.values():
		for entry: Dictionary in activations.values():
			if entry.active:
				result.temporary_dex += entry.points
				result.dt += entry.dt
				result.dp += entry.dp
	return result

static func derived(state: Dictionary, chart: String) -> Dictionary:
	var result := contributions(state)
	if not result.success: return result
	var accuracy: Variant = PrimeV3DexChart.accuracy(result.permanent_dex+result.temporary_dex,chart)
	if accuracy == null: return _fail("effective_dex_chart_unverified")
	result["acc"] = accuracy
	return result

static func _fail(reason: String) -> Dictionary:
	return {"success":false,"reason":reason}
