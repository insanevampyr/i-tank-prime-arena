extends "res://tests/browser/character_backup_acceptance.gd"

var restore_text := ""
var restore_payload := {}
var restoring_target := false

func _ready() -> void:
	super._ready()
	restore_text = str(JavaScriptBridge.eval("sessionStorage.getItem(%s) || ''" % JSON.stringify("36l2-"+token),true))
	restoring_target = bool(JavaScriptBridge.eval("new URLSearchParams(location.search).has('restore_target')",true))
	if restoring_target: target_factory()
	JavaScriptBridge.eval("(()=>{const p=document.getElementById('playable-test-results').parentElement;for(const pair of [['stage','Stage disposable restoration'],['verify','Verify restored checkpoint'],['faults','Test restoration failures']]){const b=document.createElement('button');b.textContent=pair[1];b.onclick=()=>window.arena36lRestoreCommand=pair[0];p.prepend(b);}})();",true)

func target_factory() -> void:
	PlayableBrowserPersistence.test_factory = func() -> CharacterBrowserStorage: return CharacterBrowserStorage.new(Callable(),"itank-arena-test-36k-playable-"+token+"-restore")

func _process(delta: float) -> void:
	if busy: return
	var command := str(JavaScriptBridge.eval("window.arena36lRestoreCommand || ''",true))
	if command.is_empty():
		super._process(delta)
		return
	JavaScriptBridge.eval("window.arena36lRestoreCommand='';",true)
	busy = true
	if command == "stage": await stage()
	elif command == "verify": await verify_restored()
	elif command == "faults": await verify_faults()
	busy = false

func stage() -> void:
	if restore_text.is_empty():
		var reader := CharacterBackupReader.new()
		var exported := reader.begin_export(controller._session._playable_persistence)
		while exported.get("state") == "pending":
			await get_tree().process_frame
			exported = reader.poll()
		if not check(exported.get("success",false),"Source backup is exported from acknowledged durable storage"): return
		restore_text = exported.text
		JavaScriptBridge.eval("sessionStorage.setItem(%s,%s)" % [JSON.stringify("36l2-"+token),JSON.stringify(restore_text)],true)
	var validated := CharacterBackupContract.decode(restore_text,"dev_normal")
	if not check(validated.success,"Generated isolated input passes complete backup validation"): return
	restore_payload = validated.payload
	if not restoring_target:
		scene.free()
		target_factory()
		make_scene()
		restoring_target = true
	controller._encounter_selector_index = 7
	controller._encounter_selector.pressed.emit()
	var before := controller._session.get_state_snapshot()
	controller._backup_actions._namespace = "dev_normal"
	controller._backup_actions.preview_text(restore_text)
	for index in range(1200):
		if controller._backup_actions.last_result.get("state") == "preview": break
		await get_tree().process_frame
	check(controller._session.get_state_snapshot() == before,"Browser preview changes no live snapshot/RNG/resources")
	line("READY: generated isolated input only; ordinary file selection is separate. Click RESTORE, then the explicit confirmation or CANCEL. Destination: "+String(controller._backup_actions.last_result.get("classification","unavailable")))

func verify_restored() -> void:
	for index in range(1200):
		controller._poll_browser_persistence()
		if controller._backup_actions.last_result.get("state") == "verified_committed" and controller._web_operation.is_empty(): break
		await get_tree().process_frame
	var validated := CharacterBackupContract.decode(restore_text,"dev_normal")
	var service: PlayableCharacterPersistence = controller._session._playable_persistence
	if not check(service != null and controller._web_operation.is_empty(),"Actual restore confirmation hydrates playable character"): return
	check(service._prior == validated.payload,"Restored level/XP/growth/purchases/items/resources/checkpoint exactly equal backup")
	check(service.status().get("persistent",false),"Transferred restored profile reports acknowledged permanent storage")
	var document := await read_document(service.profile_id)
	check(document == validated.history.back().document and service.generation == validated.manifest.head_generation,"Fresh IndexedDB inspection proves exact committed head and original identity")
	check(controller._session.get_state_snapshot().schema_version == 12,"Restored session retains schema 12")
	check(await read_document("prod_vaelis_thorn") == "","DEV restoration does not create NORMAL data")
	remember_expected()
	line("RESTORATION VERIFIED. Reload this URL with &restore_target=1 and Load saved DEV character. A second target tab must be excluded while this tab holds its lock.")

func verify_faults() -> void:
	if not check(not restore_text.is_empty(),"Prepare isolated source backup before fault tests"): return
	var attempt := str(Time.get_ticks_usec())
	for fault: String in ["abort","quota","lost_ack","readback_mismatch"]:
		var adapter := CharacterBrowserStorage.new(Callable(),"itank-arena-test-36k-"+token+"-restore-"+fault.replace("_","-")+"-"+attempt)
		var restorer := CharacterBackupRestoration.new()
		restorer.begin(restore_text,"dev_normal",null,null,adapter)
		await pump_restore(restorer)
		adapter.inject_test_fault(fault)
		restorer.confirm()
		await pump_restore(restorer)
		check(not restorer.status.success and restorer.uncertain,"Actual IDB injected "+fault+" is never reported as success")
		restorer.reconcile()
		await pump_restore(restorer)
		check(restorer.status.state == ("confirmation_required" if fault in ["abort","quota"] else "verified_committed"),"Actual fresh IDB read reconciles "+fault+" without duplicate grants")
		restorer.dispose()
	var stale_adapter := CharacterBrowserStorage.new(Callable(),"itank-arena-test-36k-"+token+"-restore-stale-"+attempt)
	var stale := CharacterBackupRestoration.new()
	stale.begin(restore_text,"dev_normal",null,null,stale_adapter)
	await pump_restore(stale)
	var request := stale_adapter.begin("restore",{"profile":stale.backup.manifest.profile_id,"owner":stale._owner,"expected":stale.backup.history.slice(0,1),"records":stale.backup.history})
	var response := request
	for index in range(1200):
		response = stale_adapter.poll(request.job)
		if response.state != "pending": break
		await get_tree().process_frame
	check(not response.success,"Actual IDB refuses stale expected history without publishing")
	stale.dispose()
	line("Actual IndexedDB failure/reconciliation cases complete. Quota/abort faults are explicitly injected, not browser settings changes.")

func pump_restore(restorer: CharacterBackupRestoration) -> void:
	for index in range(1200):
		if restorer.status.state != "pending": return
		restorer.poll()
		await get_tree().process_frame
	check(false,"Restoration storage timeout")
