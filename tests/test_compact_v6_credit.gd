extends RefCounted
const Adapter = preload("res://scripts/rewards/compact_v6_gameplay_candidate.gd")
const Native = preload("res://scripts/rewards/compact_v6_fixed_credit.gd")
const V6 = preload("res://scripts/rewards/compact_character_v6_prototype.gd")
const Convert = preload("res://scripts/rewards/legacy_to_compact_v6_prototype.gd")
const Q = preload("res://tests/test_compact_v6_gameplay_candidate.gd")
const Historical = preload("res://tests/test_historical_vaelis_admission.gd")
const Store = preload("res://tests/compact_v6_backup_store.gd")
const Portable = preload("res://tests/compact_v6_portable_backup.gd")
const Credit = preload("res://scripts/rewards/character_expc_credit.gd")
const Grant = preload("res://scripts/rewards/character_expc_grant.gd")
const Fixtures = preload("res://tests/compact_v6_storage_fixtures.gd")
var failures: Array[String] = []
var assertions := 0
var timings := {}

func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok: failures.append(message)
func approve(value: Dictionary) -> Dictionary:
	return {"confirmed":true,"binding":V6.digest(value)}
func token(head: Dictionary) -> Dictionary:
	return {"sequence":head.sequence,"digest":head.digest}
func run() -> Array[String]:
	var old_storage := PlayableCharacterPersistence.test_storage
	var old_run := PlayableCharacterPersistence.test_run_id
	var old_nonpersistent := PlayableCharacterPersistence.test_nonpersistent
	PlayableCharacterPersistence.test_nonpersistent = false
	var root := OS.get_cache_dir().path_join("itank-storage-tests/compact45m_45r_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()])
	var helper := Q.new()
	var h := Historical.new(); h.root = root.path_join("legacy")
	var original := h.make_history("dev_normal",Credit.BASELINE,2,"uncredited")
	check(original.get("success",false),"Disposable eligible real V2 history, no assumed owner grant status.")
	if original.get("success",false): exercise(root,original,helper,h)
	for mode: String in ["normal","dev_normal"]:
		var forbidden: Dictionary = helper.start(CharacterSaveStorage.new(root.path_join("ineligible_"+mode)),mode,1)
		check(forbidden.get("success",false),"Disposable ineligible profile fixture.")
		if forbidden.get("success",false): check(forbidden.service.observer.prepare_credit(forbidden.session,forbidden.service.observer.head(),approve).get("reason") == "expc_credit_profile_mismatch","NORMAL/current nonallowlisted DEV baseline cannot receive the fixed historical grant.")
	check(helper.failures.is_empty() and h.failures.is_empty() and h.helper._failures.is_empty(),"Reused real-operation helpers have no failures: "+str(helper.failures)+str(h.helper._failures))
	PlayableCharacterPersistence.test_storage = old_storage
	PlayableCharacterPersistence.test_run_id = old_run
	PlayableCharacterPersistence.test_nonpersistent = old_nonpersistent
	print("45R_METRICS "+JSON.stringify(timings.merged({"native_static":OS.get_static_memory_usage(),"native_peak":OS.get_static_memory_peak_usage(),"fixture_root":root,"scope":"native headless debug, disposable files and legacy oracle; not owner data or Edge"})))
	print("45R native compact credit: %d assertions." % assertions)
	return failures

func exercise(root: String, original: Dictionary, helper: RefCounted, h: RefCounted) -> void:
	var converted := Convert.convert(original.records,"dev_normal")
	check(converted.success,"Uncredited V2 conversion remains compact version 1.")
	if not converted.success: return
	var f: Dictionary = helper.start(original.storage,"dev_normal",null,converted.record)
	check(f.get("success",false),"Verified legacy oracle admits independently.")
	if not f.get("success",false): return
	var s: ArenaCombatSession = f.session
	var p: PlayableCharacterPersistence = f.service
	for wave in range(2):
		check(s.request_next_wave().success,"Real wave transition before maintenance credit.")
		h.helper._defeat_wave(s)
		check(s.collect_all_ground_loot().success,"Real source-valued XP/loot before credit.")
	for attribute: String in ["end","wis"]:
		var before: int = s.simulation.get_actor_definition(&"player").attributes[attribute]
		check(s.request_character_advancement(&"attribute",StringName(attribute),"45r_"+attribute,{"expected_current_value":before,"expected_cost":3000}).success,"Actual "+attribute+" purchase remains in predecessor.")
	check(f.service.errors.is_empty(),"S2 gameplay preparation before credit: "+str(f.service.errors))
	var parent: Dictionary = f.service.observer.current_copy()
	var source: CombatCharacterDefinitionResource = p.source
	var store := Store.new(root.path_join("compact"),source,Credit.PROFILE,"dev_normal")
	var installed := store.publish(converted.text,null)
	check(installed.success,"Independent compact baseline publishes only in disposable storage.")
	if not installed.success: return
	for record: Dictionary in f.service.records:
		installed = store.publish(V6.encode(record,source).text,token(installed.head))
		check(installed.success,"Existing source-valid S2 records enter the disposable ancestry.")
		if not installed.success: return
	check(installed.record == parent,"Exact native parent, after growth and purchases.")
	var parent_file := store.root.path_join("parent.v6backup")
	var parent_export := store.export_file(parent_file)
	check(parent_export.success,"Uncredited parent portable artifact is independently verified.")
	if not parent_export.success: return
	write(root.path_join("parent.v6backup"),FileAccess.get_file_as_string(parent_file))
	var a: RefCounted = f.service.observer
	a.observe(s)
	var before := s.get_state_snapshot()
	var rejected: Dictionary = a.prepare_credit(s,a.head(),Callable(),store.load_current)
	check(rejected.get("reason") == "expc_credit_confirmation_required","No owner callback, no credit proposal.")
	var unsigned := Native.proposal(parent,source,load("res://scripts/rewards/compact_character_v6_prototype.gd"))
	check(unsigned.success and not CharacterPersistenceCoordinator._authorize(unsigned.prepared,source,Credit.PROFILE,PlayableCharacterAdmission.RULES,a.credit_authority).success,"Verification-only arithmetic cannot authorize a coordinator mutation.")
	var forged := func(value: Dictionary):
		value.grant.amount += 1
		return {"confirmed":true,"binding":V6.digest(value)}
	check(a.prepare_credit(s,a.head(),forged,store.load_current).get("reason") == "expc_credit_confirmation_required","Changed confirmation quote cannot approve another amount.")
	var motion: Dictionary = f.movement.wave_entry_state()
	var drift := func(value: Dictionary):
		f.movement.request_running(); f.movement.advance(100000,Vector2.RIGHT)
		return approve(value)
	check(a.prepare_credit(s,a.head(),drift,store.load_current).get("reason") == "credit_context_changed_during_confirmation","Changed Running/timer state cannot reuse an owner confirmation.")
	check(f.movement.restore_wave_entry(motion),"Restore only this disposable movement fixture after adversarial callback.")
	var wrong: Dictionary = a.head(); wrong.sequence += 1
	check(not a.prepare_credit(s,wrong,approve,store.load_current).success,"Stale logical head rejected.")
	var started := Time.get_ticks_usec()
	var prepared: Dictionary = a.prepare_credit(s,a.head(),approve,store.load_current)
	timings["prepare_ms"] = float(Time.get_ticks_usec()-started)/1000.0
	check(prepared.success,"Typed compact fixed grant prepares: "+str(prepared))
	if not prepared.success: return
	timings["preparer"] = prepared.metrics
	var sealed: RefCounted = prepared.prepared
	var saved: Dictionary = a._credit_proposal.duplicate(true)
	a._credit_proposal.payload.recovery.player.current_hpc -= 1
	a._credit_proposal.document = CharacterSaveContract.encode(a._credit_proposal.payload).text
	check(not CharacterPersistenceCoordinator._authorize(a._credit_proposal,source,Credit.PROFILE,PlayableCharacterAdmission.RULES,a.credit_authority).success,"Confirmation cannot authorize a changed/reencoded unrelated resource request.")
	check(not a.check(sealed,a.head()).success,"Changed private proposal invalidates sealed credit binding.")
	a._credit_proposal = saved
	var canceled := Adapter.new(p,parent)
	canceled.observe(s)
	var cancel_prepared := canceled.prepare_credit(s,canceled.head(),approve,store.load_current)
	check(cancel_prepared.success and canceled.cancel().reason == "candidate_canceled" and not canceled.check(cancel_prepared.prepared,canceled.head()).success,"Cancellation before publication grants nothing and invalidates its permit.")
	var unknown := Adapter.new(p,parent)
	unknown.observe(s)
	var bad_reader := func():
		var value := store.load_current()
		value.head.digest = "0".repeat(64)
		return value
	check(not unknown.prepare_credit(s,unknown.head(),approve,bad_reader).success,"Forged storage-head response fails full byte/hash binding.")
	var text: String = sealed.copy().candidate_text
	started = Time.get_ticks_usec(); var cold := V6.decode(text,source)
	timings["cold_decode_ms"] = float(Time.get_ticks_usec()-started)/1000.0
	check(cold.success,"Cold V6 decoding validates typed native predecessor: "+str(cold.get("reason")))
	if not cold.success: return
	var credited: Dictionary = cold.record
	timings["validation_ms"] = []; timings["encoding_ms"] = []; timings["cold_decode_samples_ms"] = []
	for i in range(3):
		started = Time.get_ticks_usec(); var valid := V6.validate(credited,source)
		timings.validation_ms.append(float(Time.get_ticks_usec()-started)/1000.0)
		started = Time.get_ticks_usec(); var encoded := V6.encode(credited,source)
		timings.encoding_ms.append(float(Time.get_ticks_usec()-started)/1000.0)
		started = Time.get_ticks_usec(); var decoded := V6.decode(text,source)
		timings.cold_decode_samples_ms.append(float(Time.get_ticks_usec()-started)/1000.0)
		check(valid.success and encoded.success and encoded.text == text and decoded.success and decoded.record == credited,"Deterministic canonical encode/cold-decode after native credit.")
	check(credited.compact_version == 2 and credited.evidence.credit_predecessor.format == Native.FORMAT,"Explicit inner version 2 and typed witness version 1; outer envelope stays 6.")
	check(credited.accounting.expc_available == parent.accounting.expc_available+10000 and credited.accounting.expm_total == parent.accounting.expm_total,"Exactly +10000 EXPC and zero EXPM.")
	check(V6._projection(credited) == a._credit_proposal.payload,"Exact independent original fixed-credit payload; no unrelated field changes.")
	check(s.get_state_snapshot() == before,"Preparing/checking credit changes no simulator state, RNG, resource, action or clock.")
	corruption(parent,credited,source)
	var interrupted := store.publish(text,token(installed.head),"before_stage")
	check(not interrupted.success and store.load_current().text == installed.text,"Interruption before publication preserves acknowledged parent.")
	check(a.prepare_credit(s,a.head(),Callable()).prepared == sealed,"Uncertain retry retains same confirmed immutable request; no new prompt/operation.")
	var lost := store.publish(text,token(installed.head),"lost_ack")
	check(not lost.success,"Simulated committed/lost acknowledgement reported uncertain.")
	var retried: Dictionary = a.prepare_credit(s,a.head(),Callable())
	check(retried.success and retried.prepared == sealed and retried.already_applied,"Exact persisted readback reconciles committed grant without reissuance.")
	var read := Store.new(store.root,source,Credit.PROFILE,"dev_normal").load_current()
	check(read.success and read.text == text,"Fresh adapter reload retains exact credited bytes.")
	# Publish the SAME delta through the original coordinator to an independent
	# disposable legacy oracle. The native witness never references this document.
	var proposal: Dictionary = a._credit_proposal.duplicate(true)
	p._allowed_payloads[CharacterProfileProjection.fingerprint(proposal.payload)] = p._lineage.duplicate(true)
	p._allowed_proposals[CharacterProfileProjection.fingerprint(proposal)] = true
	p._prepared = proposal; p._last_ack = false
	var ack := CharacterPersistenceCoordinator.new(original.storage).commit(proposal,source,Credit.PROFILE,PlayableCharacterAdmission.RULES,a.credit_authority)
	check(ack.success,"Original coordinator publishes only the confirmed fixed delta to disposable legacy oracle.")
	if not ack.success: return
	check(p._ack(ack).success and a.adopt(sealed).success,"Observer adopts only original verified legacy acknowledgement plus exact compact readback.")
	var grant := Grant.new()
	grant._session = s; grant._service = p; grant._prepared = proposal; grant._runtime = grant._runtime_digest()
	check(grant._published(ack).success,"Unmodified original grant bookkeeping applies explicit confirmed credit to disposable runtime.")
	check(s.get_actor_state(&"player").progression.expc == parent.accounting.expc_available+10000 and s.get_actor_state(&"player").progression.expm == parent.accounting.expm_total,"Live oracle credit bookkeeping preserves earned XP/level.")
	check(a.prepare_credit(s,a.head(),approve,store.load_current).get("no_op",false),"Repeated grant, regardless of wrapper, is a lifetime no-op.")
	var cursor: int = f.service.records.size()
	installed = read
	for i in range(22):
		check(s.request_character_development("preferences",{"order":["nac","block","dodge","soak"] if i%2 == 0 else ["nac","dodge","block","soak"]},"45r_after_credit_%d" % i).success,"Real source operation after native credit.")
		for record: Dictionary in f.service.records.slice(cursor):
			installed = store.publish(V6.encode(record,source).text,token(installed.head))
			check(installed.success,"New native-credit version preserved on subsequent S2 checkpoint.")
		cursor = f.service.records.size()
	check(f.service.errors.is_empty(),"S2 after credit: "+str(f.service.errors))
	var latest: Dictionary = a.current_copy()
	check(latest.recent_journal.size() == 20 and not latest.recent_journal.any(func(row): return row.id == Native.transaction_id()),"Grant is outside recent journal but remains in exact lifetime registry.")
	check(a.prepare_credit(s,a.head(),approve,store.load_current).get("no_op",false) and latest.accounting.credit_expc == 10000,"No second grant after journal eviction.")
	backup_and_resume(root,store,latest,f,helper,original)
	timings["record_bytes"] = text.to_utf8_buffer().size()
	timings["proof_bytes"] = JSON.stringify(credited.evidence.credit_predecessor,"",true,true).to_utf8_buffer().size()
	write(root.path_join("parent.json"),installed_parent_text(parent,source))
	write(root.path_join("credited.json"),text)
	write(root.path_join("later.json"),V6.encode(latest,source).text)
	# Separate fixture to verify existing historical-credit conversion stays v1.
	var rows := CharacterSaveStorage.history_records(original.storage.inspect_profile(Credit.PROFILE))
	var old_conversion := Convert.convert(rows,"dev_normal")
	check(old_conversion.success and old_conversion.record.compact_version == 1,"Existing complete V2/V5 legacy credit history still converts by the historical path.")

func installed_parent_text(parent: Dictionary, source: CombatCharacterDefinitionResource) -> String:
	return V6.encode(parent,source).text
func write(path: String, text: String) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE); file.store_string(text); file.close()

func corruption(parent: Dictionary, credited: Dictionary, source: CombatCharacterDefinitionResource) -> void:
	for kind: String in ["amount","profile","source","parent","counts","accounting","chronology","missing","request","duplicate","downgrade","reorder","grant_parent_digest","storage","version","missing_parent_head","missing_parent_state","malformed_parent_state"]:
		var c: Dictionary = credited.duplicate(true)
		match kind:
			"amount": c.evidence.credit.records[0].amount += 1
			"profile": c.current.character_id = "prod_vaelis_thorn"
			"source": c.source_digest = "0".repeat(64)
			"parent": c.evidence.credit_predecessor.parent_head.sequence += 1
			"counts": c.evidence.credit_predecessor.counts.purchases -= 1
			"accounting": c.evidence.credit_predecessor.binding.quote.accounting.expc_available += 1
			"chronology": c.evidence.order.pop_back()
			"missing": c.evidence.credit_predecessor = null
			"request": c.operations.back().id = "new_wrapper_for_old_grant"
			"duplicate": c.evidence.credit.records.append(c.evidence.credit.records[0].duplicate(true))
			"downgrade": c.compact_version = 1
			"reorder": c.evidence.order.reverse()
			"grant_parent_digest": c.head.parent_digest = "0".repeat(64)
			"storage": c.evidence.credit_predecessor.binding.quote.storage.digest = "0".repeat(64)
			"version": c.evidence.credit_predecessor.version = 2
			"missing_parent_head": c.evidence.credit_predecessor.parent_head = {}
			"missing_parent_state": c.evidence.credit_predecessor.current = {}
			"malformed_parent_state": c.evidence.credit_predecessor.current.permanent.development = 2
		# Refresh ordinary hashes/derived ID registry: integrity alone is no proof.
		if kind != "source": c = V6.assemble(c.current,c.evidence,c.operations,c.head,source,c.compact_version)
		check(not V6.validate(c,source).success,"Rehashed native credit tamper rejected: "+kind)
	var changed: Dictionary = credited.duplicate(true)
	changed.current.recovery.player.current_hpc -= 1
	changed = V6.assemble(changed.current,changed.evidence,changed.operations,changed.head,source,2)
	check(V6.validate(changed,source).success and not V6.validate_extension(parent,changed,source).success,"Individually valid unrelated HPC mutation cannot be coalesced into credit.")

func backup_and_resume(root: String, store: RefCounted, latest: Dictionary, f: Dictionary, helper: RefCounted, original: Dictionary) -> void:
	var source: CombatCharacterDefinitionResource = f.service.source
	var started := Time.get_ticks_usec()
	var exported: Dictionary = store.export_file(store.root.path_join("credited.v6backup"))
	timings["backup_export_ms"] = float(Time.get_ticks_usec()-started)/1000.0
	check(exported.success,"Self-contained native-credit portable export: "+str(exported.get("reason")))
	if not exported.success: return
	var file := FileAccess.get_file_as_string(store.root.path_join("credited.v6backup"))
	write(root.path_join("credited.v6backup"),file) # Disposable cross-platform artifact only.
	started = Time.get_ticks_usec(); var preview := Portable.decode(file,source)
	timings["preview_ms"] = float(Time.get_ticks_usec()-started)/1000.0
	check(preview.success and preview.record == latest,"Cold portable preview reconstructs exact native credit without legacy files.")
	var dest := Store.new(root.path_join("restored"),source,Credit.PROFILE,"dev_normal")
	check(not dest.restore(file,null,"").success,"No restore without explicit separate authorization.")
	var restored: Dictionary = dest.restore(file,null,Portable.confirmation(file.sha256_text(),null,Credit.PROFILE,"dev_normal"))
	check(restored.success and restored.record == latest,"Restore preserves original grant, resources, level, evidence and lifetime IDs.")
	var resumed: Dictionary = helper.start(original.storage,"dev_normal",null,latest)
	check(resumed.success,"Original legacy oracle RESUME alongside cold compact head.")
	if resumed.success:
		check(resumed.service.observer.prepare_credit(resumed.session,resumed.service.observer.head(),approve,dest.load_current).get("no_op",false),"Reload/RESUME does not reissue credit.")
		var auth: Dictionary = resumed.session.get_abandon_run_authorization()
		check(auth.success,"New-run decision uses original explicit head authorization.")
		if auth.success:
			var next: Dictionary = helper.start(original.storage,"dev_normal",1,latest,true,true,auth.checkpoint)
			check(next.success and next.service.errors.is_empty(),"NEW RUN retains native credit with new locked policy.")
			if next.success: check(next.service.observer.prepare_credit(next.session,next.service.observer.head(),approve).get("no_op",false),"New run cannot repeat lifetime grant.")
