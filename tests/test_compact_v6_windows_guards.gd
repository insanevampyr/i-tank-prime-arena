extends RefCounted
const Windows = preload("res://scripts/rewards/compact_v6_windows_storage.gd")
const Host = preload("res://tests/compact_v6_windows_host.gd")
const Historical = preload("res://tests/test_historical_vaelis_admission.gd")
var failures: Array[String] = []
var assertions := 0
class SwitchingReader extends Windows:
	var reads := 0
	var publish: Callable
	func _manifest() -> Dictionary:
		reads += 1
		if reads == 2 and publish.is_valid(): publish.call()
		return super._manifest()
func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok: failures.append(message)
func run() -> Array[String]:
	var old := PlayableCharacterPersistence.test_nonpersistent
	var storage := PlayableCharacterPersistence.test_storage
	var run_id := PlayableCharacterPersistence.test_run_id
	PlayableCharacterPersistence.test_nonpersistent = false
	var root := OS.get_cache_dir().path_join("itank-storage-tests/compact45s_guards_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()])
	var host := Host.new()
	var f: Dictionary = host.native_start(root,"normal",1)
	check(f.success,"Guard source fixture.")
	if f.success:
		var p: Host.NativeService = f.service
		var route: RefCounted = p.route
		Historical.new().helper._defeat_wave(f.session)
		check(not Windows.new("user://character_documents",p.source,p.profile_id,p.mode).load_current().success,"Forbidden production root rejects without opening storage.")
		check(not p.coordinator.prepare_compact(route,RefCounted.new(),RefCounted.new(),null).success,"Claimed/foreign candidate objects are not authority.")
		var before: Dictionary = route.load_current()
		var ownership: Dictionary = route.acquire()
		check(ownership.success and not Windows.new(root,p.source,p.profile_id,p.mode).acquire().success,"Independent compact writers cannot own the same profile concurrently.")
		route.release(ownership.owner)
		p.before_commit = func():
			var sealed: RefCounted = p.coordinator._compact_pending
			var copied := CharacterPersistenceCoordinator.CompactPrepared.new(sealed.copy())
			check(p.coordinator.commit_compact(copied).get("reason") == "foreign_compact_prepared_operation","A copied valid request cannot replace the privately admitted handle.")
			var proposal: Dictionary = p._prepared.duplicate(true)
			p._prepared.payload.xp.unspent += 1
			check(not p.coordinator.commit_compact(sealed).success,"Changed authorized request rejects before publication.")
			p._prepared = proposal
		check(f.session.request_character_development("preferences",{"order":["nac","block","dodge","soak"]},"45s_guard_valid").get("persistence",{}).get("success",false),"Restored original request publishes normally after rejected forgeries.")
		var latest: Dictionary = route.load_current()
		check(latest.record.accounting == before.record.accounting,"Rejected forgeries cannot create XP, credit, purchases or items.")
		var forged := {"success":true,"format":6,"candidate_digest":"0".repeat(64)}
		check(not p.ack_compact_disposable(forged,route).success,"A claimed success flag cannot acknowledge another state.")
		var baseline: Dictionary = route.load_current()
		var peer: Dictionary = host.native_start(root,"normal",null,baseline.record)
		check(peer.success,"Independent admitted writer for readback race.")
		if peer.success:
			var reader := SwitchingReader.new(root,p.source,p.profile_id,p.mode)
			reader.publish = func(): check(peer.session.request_character_development("preferences",{"order":["nac","dodge","block","soak"]},"45s_read_race").get("persistence",{}).get("success",false),"Actual competing writer publishes during cold reader validation.")
			check(reader.load_current().get("reason") == "compact_head_changed_during_validation","Reader cannot return a stale head after a concurrent publication.")
			peer.service.before_commit = func(): peer.service.observer.cancel()
			var unacknowledged: Dictionary = route.load_current()
			var canceled: Dictionary = peer.session.request_character_development("preferences",{"order":["nac","dodge","block","soak"]},"45s_cancel")
			check(not canceled.get("persistence",{}).get("success",true) and route.load_current().text == unacknowledged.text,"Cancellation invalidates pending authorization without writes or rollback.")
			peer.service.before_commit = Callable()
		p.before_commit = Callable()
	PlayableCharacterPersistence.test_nonpersistent = old; PlayableCharacterPersistence.test_storage = storage; PlayableCharacterPersistence.test_run_id = run_id
	print("45S Windows guards: %d assertions." % assertions)
	return failures
