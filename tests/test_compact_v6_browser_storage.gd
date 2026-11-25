extends "res://tests/compact_v6_browser_host.gd"
# Native deterministic transport model. Actual IndexedDB tests are independent.
class Memory extends RefCounted:
	var state := {"success":true,"state":"verified_committed","route":null,"blobs":[],"legacy_head":null,"legacy_rows":[],"legacy_receipts":[],"legacy_count":0,"transaction_ms":0.0}
	var jobs := {}
	var serial := 0
	var owner := ""
	func transport(op: String, args: Dictionary) -> Dictionary:
		if op == "poll":
			var result: Dictionary = jobs[args.job]; jobs.erase(args.job); return result
		serial += 1
		var a: Dictionary = args.arguments; var r := {"success":true,"state":"verified_committed"}
		match args.operation:
			"acquire":
				if owner.is_empty(): owner = a.owner
				else: r = {"success":false,"state":"unavailable","reason":"profile_in_use"}
			"snapshot": r = state.duplicate(true)
			"match":
				for key: String in ["route","blobs","legacy_head","legacy_rows","legacy_receipts"]:
					if a[key] != state[key]: r = {"success":false,"state":"recovery_required","reason":"head_or_bytes_changed_during_validation"}
			"publish":
				if a.owner != owner or a.expected_route != state.route: r = {"success":false,"state":"recovery_required","reason":"stale_compact_storage_head"}
				elif a.get("fault","") in ["abort","quota","before_transaction"]: r = {"success":false,"state":"recovery_required","reason":"injected_abort"}
				else:
					var retained: Array = state.blobs.filter(func(b): return b.kind == "record" and b.digest == a.route.previous)
					retained.append({"profile":a.profile,"kind":"record","digest":a.route.digest,"text":a.text})
					retained.append({"profile":a.profile,"kind":"capsule","digest":a.route.capsule_digest,"text":a.capsule})
					state.route = a.route.duplicate(true); state.blobs = retained
					if a.get("fault","") == "lost_ack": r = {"success":false,"state":"recovery_required","reason":"acknowledgement_lost"}
			"repair":
				if a.expected_route != state.route or a.text.sha256_text() != state.route.digest: r = {"success":false,"state":"recovery_required","reason":"repair_conflict"}
				else:
					state.blobs = state.blobs.filter(func(b): return not (b.kind == "record" and b.digest == state.route.digest))
					state.blobs.append({"profile":a.profile,"kind":"record","digest":state.route.digest,"text":a.text})
					r = state.duplicate(true)
			"release": owner = ""
			_: pass
		var id := "job_%d" % serial; jobs[id] = r
		return {"success":false,"state":"pending","job":id}

func transport_call(route: RefCounted, op: String, a: Dictionary = {}) -> Dictionary:
	var r: Dictionary = route.begin(op,a)
	return route.poll(r.job) if r.get("state") == "pending" else r
func pump(coordinator: RefCounted) -> Dictionary:
	for i in range(20):
		var r: Dictionary = coordinator.poll_compact()
		if r.get("state") != "pending": return r
	return {"success":false,"reason":"test_pump_exhausted"}
func flush(f: Dictionary) -> Dictionary:
	for i in range(20):
		var r: Dictionary = f.service.poll_publication()
		if r.get("state") != "pending": return r
	return {"success":false,"reason":"test_pump_exhausted"}
func build(mode: String = "normal", baseline: String = "") -> Dictionary:
	var starter := PlayableCharacterAdmission.prepare_starter(&"vaelis_thorn",mode,baseline)
	var memory := Memory.new()
	var route := BrowserRoute.new("itank-arena-test-36k-45t-native",starter.source,starter.profile_id,mode,memory.transport)
	check(transport_call(route,"acquire",{"owner":"native"}).success,"Existing writer ownership acquired")
	check(route.accept_snapshot(transport_call(route,"snapshot")).success,"Initial empty snapshot verified")
	var f := start_browser(route,1 if mode == "normal" else 10)
	f.memory = memory; f.route = route
	return f
func run() -> Array[String]:
	var prior_run := PlayableCharacterPersistence.test_run_id
	var prior_store := PlayableCharacterPersistence.test_storage
	var prior_flag := PlayableCharacterPersistence.test_nonpersistent
	PlayableCharacterPersistence.test_nonpersistent = false; PlayableCharacterPersistence.test_storage = null
	var f := build()
	check(f.success,"Actual fresh browser session prepares under existing service")
	if f.success:
		var p: Service = f.service
		check(p.pending and f.memory.state.route == null and p.generation == 0,"Queued candidate is never acknowledged or published early")
		var first := flush(f)
		check(first.success,"Full authority, transaction, cold readback, match and original ack: "+str(first))
		if not first.success: print("45T_FAILURE "+str(first)); return failures
		check(p.generation == 1 and p.records.size() == 1,"Exactly one initial Wave 1 operation")
		var saved: String = f.route.load_current().text
		var snapshot := V6.digest(f.session.get_state_snapshot())
		var foreign := Adapter.Prepared.new(p.last_prepared.copy())
		check(not BrowserCoordinator.new().begin_compact(f.route,p.observer,foreign,null).success,"Copied/forged pending handle is not authority")
		check(V6.digest(f.session.get_state_snapshot()) == snapshot,"Rejected request does not consume RNG or change events")
		check(not f.route.poll("stale_job").success,"Stale browser callback rejected")
		var opened := start_browser(f.route)
		check(opened.success and not opened.service.pending,"Cold source-verified admission resumes without new transaction")
		check(opened.service._prior == p._prior,"Reload preserves exact acknowledged character projection")
		Historical.new().helper._defeat_wave(f.session)
		check(p.pending and flush(f).success,"Real defeat/reward/growth checkpoint secured before downtime development")
		saved = f.route.load_current().text
		for fault_name: String in ["abort","quota","before_transaction","lost_ack"]:
			var development: Dictionary = f.session.request_character_development("preferences",{"order":["nac","dodge","block","soak"]},"45t_"+fault_name)
			check(p.pending,"Real authoritative development creates asynchronous checkpoint: "+str(development))
			if not p.pending: print("45T_DEVELOP "+str(development)); return failures
			p.coordinator.fault = fault_name
			var result := flush(f)
			if fault_name == "lost_ack":
				check(result.success and result.already_applied,"Committed lost acknowledgement reconciles exact bytes without effect replay")
			else:
				check(not result.success and f.route.load_current().text == saved,"Abort/quota preserves acknowledged state")
				p.errors.clear(); p.coordinator = BrowserCoordinator.new()
				var retried: Dictionary = p.coordinator.begin_compact(f.route,p.observer,p.last_prepared,BrowserRoute.token(f.route.load_current()))
				if retried.get("state") != "pending": check(false,"Retry preparation: "+str(retried)); print("45T_RETRY "+str(retried)); return failures
				p.pending = true
				check(flush(f).success,"Exact original operation retries safely after abort")
			saved = f.route.load_current().text
		var head: Dictionary = f.memory.state.route.duplicate(true)
		for row: Dictionary in f.memory.state.blobs:
			if row.kind == "record" and row.digest == head.digest: row.text = "truncated"
		var repair := BrowserCoordinator.new(); repair.begin_load(f.route,true)
		check(pump(repair).success and f.route.load_current().text == saved,"Exact capsule reconstructs latest acknowledged character; never previous")
		check(f.memory.state.route == head,"Repair preserves exact route and sequence")
		var cold := BrowserRoute.new(f.route.database,p.source,p.profile_id,p.mode,f.memory.transport)
		cold.owner = "native" # Model the same externally held native-test lease.
		var load_job := BrowserCoordinator.new(); load_job.begin_load(cold)
		check(pump(load_job).success and cold.load_current().text == saved,"Cold route runs full validation rather than a warm flag")
		var original: Array = f.memory.state.blobs.duplicate(true)
		for row: Dictionary in f.memory.state.blobs:
			if row.kind == "capsule": row.text += "damaged"
		var damaged := BrowserCoordinator.new(); damaged.begin_load(f.route,true)
		check(not pump(damaged).success,"Damaged recovery capsule fails closed")
		f.memory.state.blobs = original; f.memory.state.route = null
		var missing := BrowserCoordinator.new(); missing.begin_load(f.route)
		check(not pump(missing).success,"Missing route never falls back to legacy/previous data")
		f.memory.state.route = head
		var refresh_after_fault := BrowserCoordinator.new(); refresh_after_fault.begin_load(f.route)
		check(pump(refresh_after_fault).success,"Restore authentic cache after rejected corruption probes")
		# Cancellation drains its callback; the retained exact operation can retry.
		var canceled_head: Dictionary = f.memory.state.route.duplicate(true)
		f.session.request_character_development("preferences",{"order":["nac","block","dodge","soak"]},"45t_cancel")
		check(p.pending,"Cancellation source is a real pending operation")
		p.coordinator.cancel_before_publication()
		check(not flush(f).success and f.memory.state.route == canceled_head,"Cancel before publication does not change acknowledged progression")
		p.errors.clear(); p.coordinator = BrowserCoordinator.new()
		var retry_cancel: Dictionary = p.coordinator.begin_compact(f.route,p.observer,p.last_prepared,BrowserRoute.token(f.route.load_current()))
		check(retry_cancel.get("state") == "pending","Canceled candidate preserves exact request for explicit retry")
		p.pending = true; check(flush(f).success,"Explicit exact retry after canceled I/O applies once")
		# Independent runtime instances share one real parent, with independent callbacks.
		var routes: Array = []
		var peers: Array = []
		for i in range(2):
			var peer_route := BrowserRoute.new(f.route.database,p.source,p.profile_id,p.mode,f.memory.transport)
			peer_route.owner = "native"
			var reader := BrowserCoordinator.new(); reader.begin_load(peer_route)
			check(pump(reader).success,"Independent peer cold-validates acknowledged parent")
			routes.append(peer_route); peers.append(start_browser(peer_route))
		for i in range(2):
			peers[i].session.request_character_development("preferences",{"order":["nac","dodge","block","soak"]},"45t_competing_%d" % i)
		check(peers[0].service.pending and peers[1].service.pending,"Both same-parent requests are independently authorized")
		check(flush(peers[0]).success and not flush(peers[1]).success,"Only one same-parent request publishes; stale peer cannot acknowledge")
		check(peers[1].service.generation < peers[0].service.generation,"Stale client cannot adopt newer progression as its own effect")
	var dev := build("dev_normal",Credit.BASELINE)
	check(dev.success and flush(dev).success,"Historical source/namespace fresh compact admitted")
	if dev.success:
		Historical.new().helper._defeat_wave(dev.session)
		check(dev.service.pending and flush(dev).success,"DEV grant requires legitimate downtime checkpoint")
		var before_expm: int = dev.session.get_reward_state().earned_xp
		var offer := grant_browser(dev)
		check(offer.get("state") == "pending","Typed S3 fixed-credit confirmation prepares original authority")
		if dev.service.pending:
			var acknowledged := flush(dev)
			check(acknowledged.success and apply_grant_runtime(dev,acknowledged).success,"Existing grant accounting applies after exact browser acknowledgement")
			check(dev.session.get_reward_state().earned_xp == before_expm and dev.route.load_current().record.accounting.credit_expc == 10000,"EXPC-only credit never increases EXPM")
			check(grant_browser(dev).get("no_op",false) or not dev.service.pending,"Second fixed grant cannot publish twice")
			check(dev.route.load_current().record.current.character_id != f.route.profile,"NORMAL and legacy DEV remain distinct")
	PlayableCharacterPersistence.test_run_id = prior_run; PlayableCharacterPersistence.test_storage = prior_store; PlayableCharacterPersistence.test_nonpersistent = prior_flag
	print("45T_NATIVE_METRICS "+JSON.stringify({"allocator_peak":OS.get_static_memory_peak_usage(),"allocator_live":OS.get_static_memory_usage(),"scope":"Native debug transport model with registered-suite preload overhead"}))
	print("45T browser route: %d assertions." % assertions)
	return failures
