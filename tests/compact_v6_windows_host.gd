extends "res://tests/test_compact_v6_gameplay_candidate.gd"

const Windows = preload("res://scripts/rewards/compact_v6_windows_storage.gd")
const Grant = preload("res://scripts/rewards/character_expc_grant.gd")
var routes: Array = []
var activation_failures: Array = []

class NativeService extends Observed:
	var route: RefCounted
	var coordinator: CharacterPersistenceCoordinator
	var writes: Array = []
	func open(p_mode: String, new_run: bool = false, authorization: Dictionary = {}, multiplier: Variant = null, existing_only: bool = false) -> Dictionary:
		var loaded: Dictionary = route.load_current()
		var opened: Dictionary
		if loaded.get("success",false) and not loaded.get("empty",false):
			opened = open_compact_disposable(route,new_run,authorization,multiplier)
			compact_parent = loaded.record
		else:
			opened = super.open(p_mode,new_run,authorization,multiplier,existing_only)
			if opened.success:
				if route.V6.digest(source.to_dictionary()) != route.V6.digest(route.source.to_dictionary()): return {"success":false,"reason":"test_route_source_mismatch"}
				route.source = source
		coordinator = CharacterPersistenceCoordinator.new(route.guard)
		return opened
	func publish_prepared() -> Dictionary:
		checkpoints += 1
		var begun := Time.get_ticks_usec()
		var candidate: Dictionary = observer.prepare(observer.head())
		if not candidate.success: errors.append(candidate); return candidate
		last_prepared = candidate.prepared
		measures.append(candidate.metrics)
		var before: Dictionary = route.load_current()
		var expected: Variant = route.token(before) if before.get("success",false) and not before.get("empty",false) else null
		var staged := coordinator.prepare_compact(route,observer,candidate.prepared,expected)
		if not staged.success: errors.append(staged); return staged
		if before_commit.is_valid():
			var callback := before_commit; before_commit = Callable(); callback.call()
		var result := coordinator.commit_compact(staged.prepared)
		if result.success and lost_ack:
			var retry := coordinator.commit_compact(staged.prepared)
			if not retry.get("already_applied",false): errors.append({"reason":"compact_exact_retry_not_reconciled"})
			result = retry; lost_ack = false
		if not result.success: errors.append(result); return result
		var acknowledged := ack_compact_disposable(result,route)
		if not acknowledged.success: errors.append(acknowledged); return acknowledged
		var adopted: Dictionary = observer.adopt_compact(candidate.prepared,result,route)
		if not adopted.success: errors.append(adopted); return adopted
		records.append(observer.current_copy())
		coordinator.finish_compact(staged.prepared)
		writes.append({"total_ms":float(Time.get_ticks_usec()-begun)/1000.0,"coordinator_prepare_ms":staged.get("prepare_ms"),"commit_ms":result.get("commit_ms"),"bytes":candidate.prepared.copy().candidate_text.to_utf8_buffer().size()})
		return result

func factory(store: CharacterSaveStorage, mode: String, parent: Dictionary) -> NativeService:
	var source: CombatCharacterDefinitionResource = PlayableCharacterAdmission.prepare_starter(&"vaelis_thorn",mode,parent.current.lineage.baseline_digest if not parent.is_empty() else "").source
	var profile: String = "dev_vaelis_thorn" if mode == "dev_normal" else "prod_vaelis_thorn"
	var route := Windows.new(store._root,source,profile,mode)
	route.guard = store
	if not parent.is_empty() and not route._fence().success:
		var activated := CharacterPersistenceCoordinator.new(store).activate_compact(route,func(q): return {"confirmed":true,"binding":V6.digest(q)})
		if not activated.success: activation_failures.append(activated)
	routes.append(route)
	var service := NativeService.new(); service.route = route
	return service

func native_start(path: String, mode: String, multiplier: Variant, parent: Dictionary = {}, new_run: bool = false, authorization: Dictionary = {}) -> Dictionary:
	return start(CharacterSaveStorage.new(path),mode,multiplier,parent,true,new_run,authorization,factory)

func grant_native(f: Dictionary) -> Dictionary:
	var p: NativeService = f.service
	var a: RefCounted = p.observer
	var offer: Dictionary = a.prepare_credit(f.session,a.head(),func(q): return {"confirmed":true,"binding":V6.digest(q)},p.route.load_current)
	if not offer.success or offer.get("no_op",false): return offer
	var proposal: Dictionary = a.publication_request(offer.prepared).proposal
	var old := p._prepared.duplicate(true)
	var staged := p.coordinator.prepare_compact(p.route,a,offer.prepared,Windows.token(p.route.load_current()))
	if not staged.success: return staged
	var ack := p.coordinator.commit_compact(staged.prepared)
	if not ack.success: return ack
	p._prepared = proposal
	var applied := p.ack_compact_disposable(ack,p.route)
	if not applied.success: p._prepared = old; return applied
	var adopted: Dictionary = a.adopt_compact(offer.prepared,ack,p.route)
	if not adopted.success: return adopted
	var delivery := Grant.new(); delivery._session = f.session; delivery._service = p; delivery._prepared = proposal; delivery._runtime = delivery._runtime_digest()
	var result := delivery._published(ack)
	p.coordinator.finish_compact(staged.prepared)
	return result
