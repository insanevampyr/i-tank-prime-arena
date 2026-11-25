extends RefCounted
# Disposable 46J transport + cold reader. No character mutation authority.
const V3 = preload("res://scripts/rewards/minimal_character_snapshot_v3.gd")
const PREFIX := "itank-arena-disposable-v3-46j-"
const FORMAT := "itank_arena_disposable_v3_browser_head"
const KEYS := ["format","layout_version","reader_version","record_version","profile","namespace","source_digest","epoch","sequence","commit_id","record_sha256","record_bytes"]
var database := ""
var profile := ""
var scope := ""
var source: CombatCharacterDefinitionResource
var _bridge: JavaScriptObject
var _handle := ""
var _job := ""
var _reader_phase := ""
var _reader_owner := ""
var _reader_result := {}
var _repair := false
var _raw := {}
var _loaded := {}

static func allowed(name: String) -> bool:
	return name.begins_with(PREFIX) and name.length() <= 160 and name.to_lower() == name and name.replace("-","").is_valid_identifier()

func _init(name: String, definition: CombatCharacterDefinitionResource, identity: String, namespace_id: String) -> void:
	if not OS.has_feature("web") or not allowed(name) or definition == null or not CharacterSaveStorage._valid_id(identity) or namespace_id not in ["normal","dev_normal"]: return
	database = name; source = definition.duplicate(true); profile = identity; scope = namespace_id
	JavaScriptBridge.eval(FileAccess.get_file_as_string("res://scripts/rewards/minimal_v3_browser_store.js"),true)
	_bridge = JavaScriptBridge.get_interface("ArenaV3Browser")
	_handle = str(_bridge.create(name)) if _bridge != null else ""

static func fail(reason: String, detail: Dictionary = {}) -> Dictionary:
	return {"success":false,"state":"recovery_required","reason":reason,"details":detail}

func valid() -> bool:
	return OS.has_feature("web") and allowed(database) and not _handle.is_empty() and source != null

func begin(operation: String, arguments: Dictionary = {}) -> Dictionary:
	if not valid(): return fail("disposable_browser_required")
	if not _job.is_empty(): return fail("browser_operation_in_flight")
	var a := arguments.duplicate(true); a.profile = profile
	_job = str(_bridge.request(_handle,operation,JSON.stringify(a,"",true,true)))
	return {"success":false,"state":"pending","job":_job} if not _job.is_empty() else fail("browser_queue_failed")

func poll(job: String) -> Dictionary:
	if not valid() or job.is_empty() or job != _job: return fail("stale_browser_callback")
	var value: Variant = V3.Contract._normalize_json_numbers(JSON.parse_string(str(_bridge.poll(_handle,job))))
	if not value is Dictionary: return fail("invalid_browser_response")
	if value.get("state") != "pending": _job = ""
	return value

func head_text(snapshot: RefCounted, text: String) -> String:
	var b: Dictionary = snapshot.copy()
	var h := {"format":FORMAT,"layout_version":1,"reader_version":3,"record_version":3,"profile":profile,"namespace":scope,"source_digest":b.source_digest,"epoch":b.epoch,"sequence":b.sequence,"commit_id":b.last_operation_id,"record_sha256":text.sha256_text(),"record_bytes":text.to_utf8_buffer().size()}
	var body := JSON.stringify(h,"",true,true)
	return JSON.stringify({"body":body,"sha256":body.sha256_text()},"",true,true)

func decode_snapshot(response: Dictionary) -> Dictionary:
	if not response.get("success",false) or not response.has("row"): return fail("unverified_browser_snapshot")
	if response.row == null: return {"success":true,"empty":true,"head_text":"","raw":null}
	var raw: Variant = response.row
	if not raw is Dictionary or not V3.V1.Scan.keys(raw,["profile","head","current","replica"]) or raw.profile != profile or not raw.head is String or raw.head.is_empty(): return fail("missing_or_conflicting_head")
	if not V3.V1.Scan.scan_json(raw.head,65536).success: return fail("invalid_head_json")
	var outer: Variant = JSON.parse_string(raw.head)
	if not outer is Dictionary or not V3.V1.Scan.keys(outer,["body","sha256"]) or not outer.body is String or outer.sha256 != outer.body.sha256_text() or not V3.V1.Scan.scan_json(outer.body,65536).success: return fail("invalid_head_checksum")
	var h: Variant = V3.Contract._normalize_json_numbers(JSON.parse_string(outer.body))
	if not h is Dictionary or not V3.V1.Scan.keys(h,KEYS) or h.format != FORMAT or h.layout_version != 1 or h.reader_version != 3 or h.record_version != 3 or h.profile != profile or h.namespace != scope or h.source_digest != V3.V6.digest(source.to_dictionary()) or not V3.V6._hash(h.record_sha256) or not V3.V6._uint(h.record_bytes) or h.record_bytes > V3.V1.MAX_FILE_BYTES: return fail("unsupported_or_conflicting_head")
	var c: bool = raw.current is String and raw.current.to_utf8_buffer().size() == h.record_bytes and raw.current.sha256_text() == h.record_sha256
	var r: bool = raw.replica is String and raw.replica.to_utf8_buffer().size() == h.record_bytes and raw.replica.sha256_text() == h.record_sha256
	if not c and not r: return fail("both_latest_copies_damaged")
	var text: String = raw.current if c else raw.replica
	var decoded := V3.decode(text,source,profile,scope)
	if not decoded.success: return decoded
	if head_text(decoded.snapshot,text) != raw.head or (c and r and raw.current != raw.replica): return fail("head_record_conflict")
	return {"success":true,"empty":false,"snapshot":decoded.snapshot,"text":text,"head_text":raw.head,"raw":raw.duplicate(true),"repair_current":not c,"repair_replica":not r}

func begin_load(repair: bool = false) -> Dictionary:
	if not _reader_phase.is_empty() or not _job.is_empty(): return fail("browser_reader_busy")
	_repair = repair; _reader_owner = "load_"+Crypto.new().generate_random_bytes(12).hex_encode()
	_reader_phase = "acquire"; _reader_result = {}
	return begin("acquire",{"owner":_reader_owner})

func poll_load() -> Dictionary:
	if _reader_phase.is_empty(): return fail("browser_load_missing")
	var response := poll(_job)
	if response.get("state") == "pending": return response
	if _reader_phase == "release":
		_reader_phase = ""; var result := _reader_result; _reader_result = {}; _raw = {}
		_loaded = result if response.success and result.get("success",false) else {}
		return result if response.success else fail("browser_reader_release_failed")
	if not response.get("success",false):
		_reader_result = response
		if _reader_phase == "acquire": _reader_phase = ""; return response
		_reader_phase = "release"; return begin("release",{"owner":_reader_owner})
	if _reader_phase == "acquire" or _reader_phase == "repair":
		_reader_phase = "snapshot"; return begin("snapshot")
	if _reader_phase == "snapshot":
		var start := Time.get_ticks_usec()
		_reader_result = decode_snapshot(response); _reader_result["cold_validate_us"] = Time.get_ticks_usec()-start
		if _reader_result.success and not _reader_result.get("empty",false):
			if _repair and (_reader_result.repair_current or _reader_result.repair_replica):
				_reader_phase = "repair"
				return begin("repair",{"owner":_reader_owner,"expected":_reader_result.head_text,"head":_reader_result.head_text,"text":_reader_result.text,"raw":response.row})
			_reader_phase = "match"; return begin("match",{"raw":response.row})
		_reader_phase = "release"; return begin("release",{"owner":_reader_owner})
	_reader_phase = "release"; return begin("release",{"owner":_reader_owner})

func clear() -> void:
	_reader_result = {}; _raw = {}; _loaded = {}

func take_loaded() -> Dictionary:
	var result := _loaded; _loaded = {}; return result

func close() -> void:
	if valid(): _bridge.dispose(_handle)
	_handle = ""
