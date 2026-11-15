extends RefCounted
const Credit = preload("res://scripts/rewards/character_expc_credit.gd")
const Historical = preload("res://tests/test_historical_vaelis_admission.gd")
const Web = preload("res://tests/test_playable_browser_persistence.gd")
var failures: Array[String] = []
var assertions := 0
func check(ok: bool, text: String) -> void:
	assertions += 1
	if not ok: failures.append(text)
func approve(binding: Dictionary) -> Dictionary:
	return {"confirmed":true,"binding":Credit.digest(binding)}
func run() -> Array[String]:
	var h := Historical.new()
	h.root = OS.get_cache_dir().path_join("itank-storage-tests/expc_credit_%s_%s" % [OS.get_process_id(),Time.get_ticks_usec()])
	PlayableCharacterPersistence.test_nonpersistent = false
	for version in [2,4]:
		var f := h.make_history("dev_normal",Credit.BASELINE,version,"credit_%d" % version)
		var before: Dictionary = f.payload.duplicate(true)
		check(not Credit.prepare(before).success,"No grant without head-bound owner confirmation.")
		var quoted := Credit.prepare(before,approve)
		check(quoted.success,"Explicitly authorized disposable grant prepares.")
		if not quoted.success: continue
		var next: Dictionary = quoted.payload
		check(next.xp.unspent == before.xp.unspent+10000 and next.xp.earned == before.xp.earned and next.xp.spent == before.xp.spent,"Credit is exactly EXPC-only; earned/spent history is unchanged.")
		for field: String in ["permanent","items","purchases","settlements","run_history","base_attributes","equipment_state"]:
			check(next[field] == before[field],"Grant does not modify "+field)
		check(next.recovery.player == before.recovery.player and next.recovery.rng == before.recovery.rng,"No refill, stat change, level-up or RNG draw.")
		var prepared := CharacterPersistenceCoordinator.prepare(next,next.settlements,quoted.transaction_id,before.generation,before.secured_checkpoints)
		check(prepared.success and CharacterSaveContract.decode(prepared.prepared.document).version == 5,"Credit uses unused envelope V5 with old fields intact.")
		var verifier := func(_op: String, binding: String) -> Dictionary:
			return {"authorized":true,"binding":binding,"lineage":next.lineage}
		var source: CombatCharacterDefinitionResource = PlayableCharacterAdmission.prepare_starter(&"vaelis_thorn","dev_normal",Credit.BASELINE).source
		var coordinator := CharacterPersistenceCoordinator.new(f.storage)
		check(coordinator.commit(prepared.prepared,source,f.profile,PlayableCharacterAdmission.RULES,verifier).success,"Existing coordinator publishes the confirmed credit.")
		check(coordinator.commit(prepared.prepared,source,f.profile,PlayableCharacterAdmission.RULES,verifier).success,"Exact interrupted acknowledgement/retry is idempotent.")
		var loaded: Dictionary = f.storage.read_profile(f.profile)
		check(loaded.payload == next and Credit.prepare(loaded.payload).get("no_op",false),"Reload retains grant identity; duplicate grant cannot pay twice.")
		var stale: Dictionary = quoted.payload.duplicate(true)
		stale.expc_credits.records[0].head_digest = "0".repeat(64)
		check(not CharacterSaveContract.validate_replacement(before,stale).success,"Stale grant head fails continuity before publication.")
		var erased := next.duplicate(true)
		erased.erase("expc_credits")
		check(not CharacterSaveContract.validate_replacement(next,erased).success,"Credit history cannot be removed by downgrade or rollback.")
		var wrong := before.duplicate(true)
		wrong.character_id = "prod_vaelis_thorn"; wrong.profile_namespace = "normal"
		check(not Credit.prepare(wrong,approve).success,"NORMAL cannot receive the DEV credit.")
		var duplicate := next.duplicate(true)
		duplicate.expc_credits.records.append(duplicate.expc_credits.records[0].duplicate(true))
		check(not Credit.inspect(duplicate).success,"Duplicated persistent grant records fail closed.")
		var altered := next.duplicate(true)
		altered.expc_credits.records[0].amount = 10001
		check(not Credit.inspect(altered).success,"The maintenance mechanism cannot credit an arbitrary amount.")
		for invalid_field: String in ["lineage","generation"]:
			var malformed := next.duplicate(true)
			malformed[invalid_field] = "malformed"
			check(not Credit.inspect(malformed).success,"Malformed credit "+invalid_field+" fails without runtime exceptions.")
		var exported := CharacterBackupContract.create(f.storage.inspect_profile(f.profile),"dev_normal","2026-11-15T00:00:00Z")
		check(exported.success and exported.payload == next,"Mixed V2/V4/V5 full history exports and previews losslessly.")
		var restored := CharacterSaveStorage.new(h.root.path_join("restore_%d" % version))
		var restore := CharacterBackupRestoration.new()
		check(restore.begin(exported.text,"dev_normal",null,restored).success and restore.confirm().success,"Credit backup restores only after normal explicit confirmation.")
		restore.dispose()
		check(restored.read_profile(f.profile).payload == next,"Restoration preserves the grant exactly once.")
		PlayableCharacterPersistence.test_storage = f.storage
		var scene := h.web.make_scene()
		var c: ArenaCombatController = scene.get_node("CombatController")
		check(c._admit_existing_profile("dev_normal").success,"Credited historical profile hydrates through ordinary admission.")
		c._resume_loaded_run()
		check(c._session.get_reward_state().unspent_xp == next.xp.unspent and c._session.get_actor_state(&"player").progression.expm == before.xp.earned,"Authoritative wallet includes credit; EXPM does not.")
		var purchase := c._session.request_character_advancement(&"special_resistance",&"sr","credit_spend_%d" % version)
		check(purchase.success and c._session.get_actor_state(&"player").progression.expm == before.xp.earned,"Credit can fund a normal verified purchase without adding EXPM.")
		var remaining: int = c._session.get_reward_state().unspent_xp
		check(c._session.request_next_wave().success,"Credited profile can advance to the next checkpoint.")
		c._session.get_actor_state(&"player").current_hpc = 0
		c._session.advance_by(1)
		c._on_encounter_button_pressed()
		check(c._session.get_reward_state().unspent_xp == remaining and c._session._playable_persistence._prior.expc_credits == next.expc_credits,"RETRY restores the checkpoint without refunding spending or paying the grant again.")
		c._session.start_encounter()
		c._session.get_actor_state(&"player").current_hpc = 0
		c._session.advance_by(1)
		var authorization := c._session.get_return_to_wave_one_authorization()
		PlayableCharacterPersistence.test_run_id = "run_credit_return_%d" % version
		check(authorization.success and c._prepare_encounter_fixture(true,authorization.checkpoint,{},ArenaRewardLedger.resolve_run_policy("dev_normal",1)).success,"RETURN retains credit through existing atomic run admission.")
		check(c._session.get_reward_state().unspent_xp == remaining and c._session._playable_persistence._prior.expc_credits == next.expc_credits,"RETURN neither refunds nor reapplies the credit.")
		h.helper._free(scene)
		var backend := Web.Backend.new()
		backend.histories[f.profile] = f.records.duplicate(true)
		var browser := CharacterBrowserStorage.new(backend.transport)
		browser.begin("acquire",{"profile":f.profile,"owner":"credit_owner"})
		browser.poll("1")
		browser.inject_test_fault("lost_ack")
		var async := CharacterBrowserPersistence.new(browser)
		async.begin_commit(prepared.prepared,source,f.profile,PlayableCharacterAdmission.RULES,"credit_owner",verifier)
		var result := {"state":"pending"}
		for _i in range(12):
			result = async.poll()
			if result.state != "pending": break
		check(not result.success and backend.histories[f.profile].size() == f.records.size()+1,"Lost Web acknowledgement cannot duplicate the committed grant.")
		var retry := CharacterBrowserPersistence.new(browser)
		retry.begin_commit(prepared.prepared,source,f.profile,PlayableCharacterAdmission.RULES,"credit_owner",verifier)
		for _i in range(12):
			result = retry.poll()
			if result.state != "pending": break
		check(result.success and backend.histories[f.profile].size() == f.records.size()+1,"Web reconciliation acknowledges exact existing credit bytes.")
		browser.dispose()
	check(h.failures.is_empty() and h.helper._failures.is_empty(),"Source fixtures remain legal.")
	PlayableCharacterPersistence.test_storage = null
	PlayableCharacterPersistence.test_nonpersistent = true
	PlayableCharacterPersistence.test_run_id = ""
	h.helper._remove_fixture(h.root)
	print("43E EXPC credit: %d assertions." % assertions)
	return failures
