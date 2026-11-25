extends RefCounted
const Windows = preload("res://scripts/rewards/compact_v6_windows_storage.gd")
const Historical = preload("res://tests/test_historical_vaelis_admission.gd")
const Credit = preload("res://scripts/rewards/character_expc_credit.gd")
var assertions := 0
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok: failures.append(message)
func run() -> Array[String]:
	var saved := PlayableCharacterPersistence.test_nonpersistent
	var store := PlayableCharacterPersistence.test_storage
	var run_id := PlayableCharacterPersistence.test_run_id
	PlayableCharacterPersistence.test_nonpersistent = false
	var cache := OS.get_cache_dir().path_join("itank-storage-tests/compact45s_crash_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()])
	var h := Historical.new(); h.root = cache.path_join("source")
	var base := h.make_history("dev_normal",Credit.BASELINE,2,"history")
	if base.get("success",false):
		for cut: String in ["record","fence","route","incremental"]:
			var definition: CombatCharacterDefinitionResource = PlayableCharacterAdmission.prepare_starter(&"vaelis_thorn","dev_normal",Credit.BASELINE).source
			var route := Windows.new(cache.path_join(cut),definition,Credit.PROFILE,"dev_normal")
			var owner := route.guard.acquire_writer(Credit.PROFILE)
			var restored := route.guard.restore_history(Credit.PROFILE,base.records,[],owner.owner)
			route.guard.release_writer(Credit.PROFILE,owner.owner)
			check(restored.success,"Disposable immutable source for hard crash.")
			var output: Array = []
			var code := OS.execute(OS.get_executable_path(),["--headless","--path",ProjectSettings.globalize_path("res://"),"--script","res://tests/compact_v6_windows_crash_process.gd","--",route.root,cut],output,true)
			# Windows OS.kill may terminate with exit 0. The durable locks and
			# absence of the post-activation return marker prove abrupt termination.
			check(str(output).contains("45S_SELF_CRASH") and not str(output).contains("45S_UNEXPECTED_SURVIVAL") and DirAccess.dir_exists_absolute(route.directory.path_join("writer.lock")),"Child kills only itself at verified publication boundary: "+cut)
			var loaded := route.load_current()
			check(loaded.get("success",false) == (cut in ["route","incremental"]),"Restart never guesses an old character: "+cut)
			if cut == "route": check(route.V6._projection(loaded.record) == base.payload,"Published current survives real process termination exactly.")
			if cut == "incremental": check(loaded.get("success",false) and loaded.record.accounting.expm_total > base.payload.xp.earned and loaded.record.current.generation > base.payload.generation,"Actual newly earned XP and original growth survive route publication/process death, with no fallback.")
			check(not route.recover().success,"Stale unverified owner is not stolen after a process crash.")
			check(not route.guard.write_profile(Credit.PROFILE,base.payload,"old_writer_after_crash").success,"Old writer stays excluded across restart/crash.")
			print("45S_HARD_CRASH "+JSON.stringify({"cut":cut,"exit":code,"current_readable":loaded.get("success",false),"root":route.root,"writer_recovery":"blocked_without_verified_lease_release"}))
	else: check(false,"Hard-crash source fixture.")
	PlayableCharacterPersistence.test_nonpersistent = saved; PlayableCharacterPersistence.test_storage = store; PlayableCharacterPersistence.test_run_id = run_id
	print("45S hard crash: %d assertions." % assertions)
	return failures
