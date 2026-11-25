extends RefCounted
const Backup = preload("res://scripts/rewards/character_backup_contract.gd")
var kind: String
var mode: String
var history: Dictionary
var text: String
var date: String
var phase := "history"
var job := {}
var checked := {}
var outer := {}
var manifest := {}
var scan: Backup.JsonScan
var result := {"success":false,"state":"pending","stage":"Preparing character file"}

func _init(operation: String, save_namespace: String, records: Dictionary = {}, source: String = "", created: String = "") -> void:
	kind = operation; mode = save_namespace; history = records.duplicate(); text = source; date = created
	if records.get("generations") is Array:
		history["generations"] = []
		for row: Variant in records.generations: history.generations.append(row.duplicate() if row is Dictionary else row)
	if kind == "decode": phase = "start_file"

func pending(stage: String, progress: int = 0, total: int = 0) -> Dictionary:
	result = {"success":false,"state":"pending","stage":stage,"progress":progress,"total":total}
	return result

func step() -> Dictionary:
	var output := _step()
	if output.get("state") != "pending": _release_buffers()
	return output

func _release_buffers() -> void:
	history = {}; job = {}; checked = {}; manifest = {}; outer = {}; text = ""; scan = null

func _step() -> Dictionary:
	if result.get("state") != "pending": return result
	if mode not in ["normal","dev_normal"]:
		result = Backup.fail("unsupported_namespace"); return result
	if phase in ["history","decoded_history"]:
		if job.is_empty():
			job = Backup.begin_history_validation(history,mode)
			if not job.success: result = job; return result
			return pending("Validating history",0,job.rows.size())
		var next := Backup.step_history_validation(job)
		if next.get("state") == "pending": result = next; return result
		if not next.success: result = next; return result
		checked = next
		if phase == "decoded_history":
			result = Backup._finish_manifest(manifest,checked,outer.sha256); return result
		phase = "encode"
		return pending("Encoding complete history")
	if phase == "encode":
		result = Backup._encode_checked(checked,mode,date)
		return result
	if phase == "start_file":
		scan = Backup.JsonScan.new(text,Backup.MAX_FILE_BYTES)
		phase = "file"
		return pending("Checking encoded file",0,text.length())
	if phase == "file":
		var next := scan.step(1048576)
		if next.get("state") == "pending": return pending("Checking encoded file",scan.cursor,text.length())
		if not next.success: result = next; return result
		var parsed: Variant = JSON.parse_string(text)
		if not parsed is Dictionary or not parsed.get("body_json") is String:
			result = Backup.fail("invalid_backup_container"); return result
		outer = parsed
		scan = Backup.JsonScan.new(outer.body_json,Backup.MAX_BODY_BYTES)
		phase = "body"
		return pending("Checking manifest",0,outer.body_json.length())
	if phase == "body":
		var next := scan.step(1048576)
		if next.get("state") == "pending": return pending("Checking manifest",scan.cursor,outer.body_json.length())
		if not next.success: result = next; return result
		var parsed := Backup._parse_scanned_manifest(outer,mode)
		if not parsed.success: result = parsed; return result
		manifest = parsed.manifest
		if kind == "export":
			# Reuse only this operation's privately owned, fully validated snapshot.
			# Exact decoded documents/transaction identities must match byte-for-byte.
			if manifest.generations != checked.records:
				result = Backup.fail("export_roundtrip_mismatch"); return result
			result = Backup._finish_manifest(manifest,checked,outer.sha256)
			if result.success: result["text"] = text
			return result
		history = {"success":true,"generations":manifest.generations}
		job = {}; phase = "decoded_history"
		return pending("Validating history",0,manifest.generations.size())
	result = Backup.fail("invalid_backup_task")
	return result

func cancel() -> void:
	result = {"success":false,"state":"cancelled","reason":"backup_cancelled"}
	_release_buffers()
