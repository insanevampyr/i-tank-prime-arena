class_name PlayableBrowserPersistence
extends PlayableCharacterPersistence

const Browser = preload("res://scripts/rewards/character_browser_storage.gd")
const AsyncCoordinator = preload("res://scripts/rewards/character_browser_persistence.gd")
# Test injection never selects the production database from a URL or save input.
static var test_factory: Callable
var browser: CharacterBrowserStorage
var owner := ""
var previous_owner := ""
var _job := ""
var _phase := ""
var _starter := {}
var _new_run := false
var _defeated := {}
var _async: CharacterBrowserPersistence
var _browser_result := {"success":false,"state":"unavailable","reason":"not_initialized"}
var _confirmed_missing := false
var _owns_lease := false

func open_browser(p_mode: String, previous: PlayableBrowserPersistence = null, new_run: bool = false, defeated: Dictionary = {}) -> Dictionary:
	mode = p_mode
	_starter = Admission.prepare_starter(&"vaelis_thorn",mode)
	if not _starter.get("success",false): return _starter
	source = _starter.source
	profile_id = _starter.profile_id
	_new_run = new_run
	_defeated = defeated.duplicate(true)
	owner = "session_"+Crypto.new().generate_random_bytes(12).hex_encode()
	if previous != null and previous.profile_id == profile_id and previous._owns_lease:
		browser = previous.browser
		previous_owner = previous.owner
		return _send("inspect",{"profile":profile_id})
	browser = test_factory.call() if test_factory.is_valid() else Browser.new()
	return _send("acquire",{"profile":profile_id,"owner":owner})

func _send(operation: String, arguments: Dictionary) -> Dictionary:
	_phase = operation
	_browser_result = browser.begin(operation,arguments)
	_job = _browser_result.get("job","")
	_status = {"persistent":false,"state":_browser_result.state,"reason":_browser_result.get("reason","pending"),"text":"Loading character" if operation in ["acquire","inspect"] else "Saving progress"}
	return _browser_result

func poll_browser() -> Dictionary:
	if _phase == "publication":
		var publication := _async.poll()
		if publication.state == "pending": return publication
		_browser_result = publication
		_phase = "finished"
		if publication.get("success",false):
			var acknowledged := _ack(publication)
			if not acknowledged.success: return _error("recovery_required",acknowledged.reason)
			return publication
		return _error(publication.state,publication.get("reason","publication_failed"))
	if _browser_result.get("state") != "pending": return _browser_result
	var response := browser.poll(_job)
	if response.state == "pending": return response
	if not response.get("success",false): return _error(response.state,response.get("reason","storage_failed"))
	if _phase == "acquire":
		_owns_lease = true
		return _send("inspect",{"profile":profile_id})
	if _phase == "inspect":
		var history := Browser.inspection(response,profile_id)
		if not history.get("success",false): return _error("recovery_required",history.get("reason","invalid_history"))
		if history.generations.is_empty() and not _confirmed_missing:
			_browser_result = {"success":false,"state":"confirmation_required","reason":"new_character_confirmation_required"}
			_status = {"persistent":false,"state":"confirmation_required","text":"No saved character. Confirm creation.","reason":"new_character_confirmation_required"}
			return _browser_result
		var opened := open_verified_history(_starter,history,_new_run,_defeated)
		if not opened.success: return _error("recovery_required",opened.get("reason","character_validation_failed"))
		_browser_result = {"success":true,"state":"loaded"}
		_phase = "loaded"
		return _browser_result
	if _phase == "transfer":
		previous_owner = ""
		_owns_lease = true
	if _phase == "release":
		_owns_lease = false
		browser.dispose()
	_browser_result = response
	return response

func confirm_creation() -> Dictionary:
	if _browser_result.get("state") != "confirmation_required": return Browser.status("failed","confirmation_not_requested")
	_confirmed_missing = true
	# Re-read after confirmation; never replace a profile that appeared meanwhile.
	return _send("inspect",{"profile":profile_id})

func publish_prepared() -> Dictionary:
	_async = AsyncCoordinator.new(browser)
	_browser_result = _async.begin_commit(_prepared,source,profile_id,Admission.RULES,owner if previous_owner.is_empty() else previous_owner,_verify)
	_phase = "publication"
	_status = {"persistent":false,"state":"pending","text":"Saving progress","reason":"checkpoint_pending"}
	return _browser_result

func reconcile() -> Dictionary:
	# The retained exact proposal is checked for an existing transaction first;
	# if an aborted write did not publish, retrying the same proposal is safe.
	if _prepared.is_empty(): return Browser.status("failed","no_pending_checkpoint")
	return publish_prepared()

func transfer_lease() -> Dictionary:
	if previous_owner.is_empty(): return {"success":true}
	return _send("transfer",{"profile":profile_id,"owner":previous_owner,"next_owner":owner})

func release_lease() -> Dictionary:
	if not _owns_lease: return {"success":true}
	return _send("release",{"profile":profile_id,"owner":owner})

func pending_or_unsecured() -> bool:
	return _browser_result.get("state") in ["pending","confirmation_required"] or (not _prepared.is_empty() and not _last_ack)

func _error(state: String, reason: String) -> Dictionary:
	_browser_result = Browser.status(state,reason)
	var text := "Recovery required" if state == "recovery_required" else ("Character currently open in another tab" if reason == "profile_in_use" else ("Storage unavailable" if state == "unavailable" else "Progress not saved"))
	_status = {"persistent":false,"state":state,"reason":reason,"text":text}
	return _browser_result
