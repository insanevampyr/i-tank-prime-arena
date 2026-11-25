extends "res://tests/compact_v6_disposable_store.gd"

# Pass D only. The immutable capsule is staged BEFORE the existing head rename.
# Its name binds the exact acknowledged bytes, not an assertion of trust.
const Portable = preload("res://tests/compact_v6_portable_backup.gd")
var restoring := false
var restore_file := ""
var restore_confirmation := ""

func _capsule(digest: String) -> String:
	return root.path_join("portable_"+digest+".v6backup")

func _portable_read(path: String) -> Dictionary:
	if not allowed(root) or not path.simplify_path().begins_with(root+"/"): return _fail("invalid_disposable_root")
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null: return _fail("portable_file_missing")
	if file.get_length() > Portable.MAX_BYTES: file.close(); return _fail("portable_size_limit")
	var bytes := file.get_buffer(file.get_length()); var error := file.get_error(); file.close()
	var text := bytes.get_string_from_utf8()
	if text.to_utf8_buffer() != bytes: return _fail("invalid_portable_utf8")
	return {"success":true,"text":text} if error == OK else _fail("portable_read_failed")

func capsule(head: Dictionary) -> Dictionary:
	var raw := _portable_read(_capsule(head.digest))
	if not raw.success: return raw
	var pack := Portable.decode(raw.text,source)
	if not pack.success: return pack
	if pack.text.sha256_text() != head.digest or pack.record.head.sequence != head.sequence or pack.record.head.epoch != head.epoch or pack.record.current.character_id != profile or pack.record.current.profile_namespace != save_namespace: return _fail("capsule_head_mismatch")
	return pack.merged({"portable_text":raw.text})

func load_current() -> Dictionary:
	var started := Time.get_ticks_usec()
	var loaded := super.load_current()
	if not loaded.success: return loaded
	var pack := capsule(loaded.head)
	if not pack.success: return pack
	return loaded.merged({"history":pack.history,"load_ms":float(Time.get_ticks_usec()-started)/1000.0},true)

func _publish_locked(text: String, expected: Variant, fault: String) -> Dictionary:
	var started := Time.get_ticks_usec()
	var incoming := _document(text)
	if not incoming.success: return incoming
	var history: Array = []
	var current := {}
	var head := _head()
	if restoring:
		var pack := Portable.decode(restore_file,source)
		if not pack.success: return pack
		if restore_confirmation != Portable.confirmation(restore_file.sha256_text(),expected,profile,save_namespace): return _fail("explicit_restore_confirmation_required")
		if pack.text != text or pack.preview.profile != profile or pack.preview.namespace != save_namespace: return _fail("restore_identity_mismatch")
		if head.success:
			current = load_current()
			if current.success:
				var relation := Portable.relationship(pack,current.record,current.head.digest,source)
				if not relation.success: return relation
				if relation.classification == "identical": return current.merged({"already_applied":true})
			elif text.sha256_text() != head.head.digest or pack.record.head.epoch != head.head.epoch or pack.record.head.sequence != head.head.sequence:
				return _fail("exact_acknowledged_record_required",{"validation":current})
			if expected != {"sequence":head.head.sequence,"digest":head.head.digest}: return _fail("stale_expected_head")
		elif expected != null or FileAccess.file_exists(root.path_join("head.json")): return _fail("unknown_or_existing_head")
		else:
			# Reconcile only this exact staged import after an initial interruption.
			var permitted := {"record_"+text.sha256_text()+".v6":text,"portable_"+text.sha256_text()+".v6backup":restore_file}
			if not pack.previous.is_empty():
				var prior_text: String = V6.encode(pack.previous,source).text
				permitted["record_"+prior_text.sha256_text()+".v6"] = prior_text
			for name: String in DirAccess.get_files_at(root):
				if name.begins_with("record_") or name.begins_with("portable_"):
					if not permitted.has(name) or FileAccess.get_file_as_string(root.path_join(name)) != permitted[name]: return _fail("unknown_or_existing_head")
		history = pack.history
		# Keep the incoming immediate predecessor, not a skipped destination.
		if not pack.previous.is_empty():
			var prior := V6.encode(pack.previous,source)
			if not prior.success or not _write(_file(prior.text.sha256_text()),prior.text): return _fail("previous_stage_failed")
			current = {"head":{"digest":prior.text.sha256_text()}}
	else:
		if head.success:
			current = load_current()
			if not current.success: return current
			if current.head.digest == text.sha256_text(): return current.merged({"already_applied":true})
			if expected != {"sequence":head.head.sequence,"digest":head.head.digest}: return _fail("stale_expected_head")
			var step := Portable.transition(current.record,incoming.record,source)
			if not step.success: return step
			history = current.history.duplicate(true); history.append(step.transition)
		elif expected != null or FileAccess.file_exists(root.path_join("head.json")): return _fail("unknown_or_existing_head")
		else:
			if incoming.record.head.sequence != 1: return _fail("initial_baseline_required")
			for name: String in DirAccess.get_files_at(root):
				if name.begins_with("record_") and name != "record_"+text.sha256_text()+".v6": return _fail("unknown_or_existing_head")
	var portable := Portable.export_record(text,history,source)
	if not portable.success: return portable
	if not _write(_capsule(text.sha256_text()),portable.text): return _fail("capsule_stage_failed")
	var installed := _install_verified(text,incoming,current,fault,started)
	if installed.success: _prune_capsules(installed.head)
	return installed

func restore(portable_text: String, expected: Variant, confirmation: String, fault: String = "") -> Dictionary:
	if restoring: return _fail("restore_in_flight")
	var pack := Portable.decode(portable_text,source)
	if not pack.success: return pack
	restoring = true; restore_file = portable_text; restore_confirmation = confirmation
	var result := publish(pack.text,expected,fault)
	restoring = false; restore_file = ""; restore_confirmation = ""
	return result

func preview_file(path: String) -> Dictionary:
	var raw := _portable_read(path)
	return Portable.decode(raw.text,source) if raw.success else raw

func export_file(path: String, before_recheck: Callable = Callable()) -> Dictionary:
	var started := Time.get_ticks_usec()
	var current := load_current()
	if not current.success: return current
	var pack := capsule(current.head)
	if not pack.success: return pack
	if before_recheck.is_valid(): before_recheck.call()
	var fresh := _head()
	if not fresh.success or fresh.head != current.head: return _fail("export_head_changed")
	if FileAccess.file_exists(path): return _fail("export_file_already_exists")
	if not _write(path,pack.portable_text): return _fail("export_write_failed")
	var checked := preview_file(path)
	if not checked.success or checked.text != current.text: return _fail("export_readback_failed")
	return checked.merged({"export_ms":float(Time.get_ticks_usec()-started)/1000.0,"bytes":pack.portable_text.to_utf8_buffer().size()})

func recover() -> Dictionary:
	var started := Time.get_ticks_usec()
	var loaded := super.recover()
	if loaded.success: _prune_capsules(loaded.head); return loaded
	# The existing pointer is the watermark. Never scan for an older substitute.
	if loaded.get("reason") != "latest_record_damaged": return loaded
	var head := _head()
	if not head.success: return head
	var pack := capsule(head.head)
	if not pack.success: return _fail("exact_recovery_evidence_unavailable",{"validation":pack})
	var repaired := repair_exact(pack.text)
	return repaired.merged({"recovered_exact_head":repaired.success,"recovery_ms":float(Time.get_ticks_usec()-started)/1000.0})

func _prune_capsules(head: Dictionary) -> void:
	for name: String in DirAccess.get_files_at(root):
		if name.begins_with("portable_") and name.ends_with(".v6backup") and name != "portable_"+head.digest+".v6backup":
			var digest := name.trim_prefix("portable_").trim_suffix(".v6backup")
			if V6._hash(digest): DirAccess.remove_absolute(root.path_join(name))
