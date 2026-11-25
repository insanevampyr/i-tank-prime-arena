extends RefCounted
const Full = preload("res://tests/oracles/compact_v6_candidate_full_45u.gd")
const Adapter = preload("res://scripts/rewards/compact_v6_gameplay_candidate.gd")
const V6 = preload("res://scripts/rewards/compact_character_v6_prototype.gd")
func measure(adapter: RefCounted, candidate: RefCounted, samples: int = 3) -> Dictionary:
	var ordinary: Array = []; var full: Array = []; var assertions := 0
	for i in range(samples):
		var t := Time.get_ticks_usec(); var a: Dictionary = adapter.check(candidate,adapter.head()); ordinary.append(float(Time.get_ticks_usec()-t)/1000.0)
		t = Time.get_ticks_usec(); var b := Full.check(adapter,candidate,adapter.head()); full.append(float(Time.get_ticks_usec()-t)/1000.0)
		assertions += 1
		if a != b: return {"success":false,"reason":"oracle_mismatch","actual":a,"oracle":b}
	var body: Dictionary = candidate.copy()
	var source: CombatCharacterDefinitionResource = adapter._service.get_ref().source
	var decoded := V6.decode(body.candidate_text,source)
	if not decoded.success: return decoded
	return {"success":true,"ordinary_ms":ordinary,"oracle_ms":full,"assertions":assertions,"bytes":body.candidate_text.to_utf8_buffer().size(),"candidate_sha":body.candidate_digest,"record_digest":V6.digest(decoded.record),"ids":decoded.record.applied_ids.size(),"items":decoded.record.current.items.size()}
