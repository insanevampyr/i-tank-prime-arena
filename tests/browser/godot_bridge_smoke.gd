extends Control

# Standalone disposable Web test project (see browser/README.md). This exercises
# actual Godot JavaScriptObject calls, not a native filesystem or bridge mock.
var _bridge: JavaScriptObject
var _handle := ""
var _job := ""
var _stage := 0
var _document := ""

func _ready() -> void:
	if not OS.has_feature("web"):
		_done("NOT RUN: requires isolated Web smoke export")
		return
	JavaScriptBridge.eval(FileAccess.get_file_as_string("res://character_browser_store.js"),true)
	_bridge = JavaScriptBridge.get_interface("ArenaCharacterBrowserStorage")
	if _bridge == null:
		_done("FAIL: JavaScriptBridge interface unavailable")
		return
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://character_storage_fixture.json"))
	_document = fixture.normal[0]
	_handle = str(_bridge.create(JSON.stringify({"testing":true,"database":"itank-arena-test-36k-godot-smoke"})))
	_send("acquire",{"profile":"prod_browser_fixture","owner":"smoke_session"})

func _process(_delta: float) -> void:
	if _job.is_empty(): return
	var response: Dictionary = JSON.parse_string(str(_bridge.poll(_handle,_job)))
	if response.state == "pending": return
	_job = ""
	if not response.success:
		_done("FAIL: %s" % response)
		return
	if _stage == 0:
		_stage = 1
		_send("publish",{"profile":"prod_browser_fixture","owner":"smoke_session","expected_generation":0,"transaction_id":"test_txn_1","document":_document})
	elif _stage == 1:
		if response.get("document") != _document or response.get("transaction_id") != "test_txn_1" or response.get("generation") != 1:
			_done("FAIL: Godot bridge exact readback mismatch")
			return
		_stage = 2
		_send("release",{"profile":"prod_browser_fixture","owner":"smoke_session"})
	else:
		_bridge.dispose(_handle)
		_done("PASS: Godot 4.7.2 JavaScriptBridge pending / IndexedDB publication / exact readback / lock release")

func _send(operation: String, arguments: Dictionary) -> void:
	_job = str(_bridge.request(_handle,operation,JSON.stringify(arguments)))
	if _job.is_empty(): _done("FAIL: Godot bridge queue rejected")

func _done(message: String) -> void:
	_job = ""
	var label := Label.new()
	label.text = message
	label.position = Vector2(16,16)
	add_child(label)
	print(message)
	# Expose the test result as DOM text for browser automation and manual QA.
	if OS.has_feature("web"):
		JavaScriptBridge.eval("(() => { const element = document.createElement('pre'); element.id = 'bridge-result'; element.style = 'position:fixed;top:10px;left:10px;z-index:9;background:white;color:black;padding:16px;white-space:pre-wrap;max-width:90vw'; element.textContent = %s; document.body.appendChild(element); })();" % JSON.stringify(message),true)
