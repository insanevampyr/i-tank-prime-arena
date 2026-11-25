extends RefCounted
# Test-only instrumentation. Hooks are injected into TEMP project copies only.
static var enabled := false
static var stack: Array = []
static var rows := {}
static func reset() -> void:
	stack = []; rows = {}; enabled = true
static func enter(label: String) -> Variant:
	if not enabled: return null
	var frame := {"name":label,"start":Time.get_ticks_usec(),"child":0,"memory":OS.get_static_memory_usage()}
	stack.append(frame)
	return frame
static func leave(frame: Variant) -> void:
	if frame == null: return
	var elapsed: int = Time.get_ticks_usec()-frame.start
	var delta := OS.get_static_memory_usage()-int(frame.memory)
	stack.pop_back()
	if not stack.is_empty(): stack.back().child += elapsed
	var r: Dictionary = rows.get(frame.name,{"calls":0,"inclusive_us":0,"exclusive_us":0,"max_us":0,"live_delta_bytes":0})
	r.calls += 1; r.inclusive_us += elapsed; r.exclusive_us += elapsed-int(frame.child)
	r.max_us = maxi(r.max_us,elapsed); r.live_delta_bytes += delta
	rows[frame.name] = r
static func stringify(value: Variant, indent: String = "", sorted: bool = true, precision: bool = true) -> String:
	var frame: Variant = enter("json.stringify")
	var result := JSON.stringify(value,indent,sorted,precision)
	leave(frame); return result
static func sha256(text: String) -> String:
	var frame: Variant = enter("hash.sha256")
	var result := text.sha256_text()
	leave(frame); return result
static func snapshot() -> Dictionary:
	return {"stages":rows.duplicate(true),"native_static":OS.get_static_memory_usage(),"native_peak":OS.get_static_memory_peak_usage(),"scope":"instrumented test-project copies; inclusive stages overlap; live deltas are not peak allocations"}
