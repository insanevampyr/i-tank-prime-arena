class_name CharacterBackupActions
extends Node

const Reader = preload("res://scripts/rewards/character_backup_reader.gd")
const Files = preload("res://scripts/ui/character_backup_files.gd")
const Backup = preload("res://scripts/rewards/character_backup_contract.gd")
var _controller: Node
var _dialog: AcceptDialog
var _picker: FileDialog
var _reader: CharacterBackupReader
var _bridge: JavaScriptObject
var _selecting := false
var _namespace := ""
var _export_service: PlayableCharacterPersistence
var _export := {}
var _download_button: Button
var last_result := {}
var _draining: Array[CharacterBackupReader] = []
var restoration_blocked := false
var _restorer: CharacterBackupRestoration
var _confirmation: ConfirmationDialog
var _restore_button: Button
var _verify_button: Button
var _preview_source := ""
var _admitting := false
var _controls: HBoxContainer

func setup(controller: Node, character_button: Button) -> void:
	_controller = controller
	character_button.tooltip_text = "Select character. Right-click to save or load a character file."
	character_button.gui_input.connect(_character_input)
	_dialog = AcceptDialog.new()
	_dialog.name = "CharacterBackupDialog"
	_dialog.title = "Save / Load Character"
	_dialog.min_size = Vector2i(540,220)
	_dialog.get_label().autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialog.get_ok_button().text = "CANCEL"
	_dialog.add_button("SAVE CHARACTER",false,"export")
	_dialog.add_button("SELECT SAVE FILE",false,"preview")
	_dialog.custom_action.connect(_on_action)
	_dialog.confirmed.connect(_close)
	_dialog.canceled.connect(_close)
	add_child(_dialog)
	_picker = FileDialog.new()
	_picker.name = "CharacterBackupFilePicker"
	_picker.access = FileDialog.ACCESS_FILESYSTEM
	_picker.use_native_dialog = true
	_picker.filters = PackedStringArray(["*.itankbackup.json,*.json ; Character save file"])
	_picker.file_selected.connect(_file_selected)
	_picker.canceled.connect(func(): _show("File selection canceled. Your character was not changed."))
	add_child(_picker)
	_confirmation = ConfirmationDialog.new()
	_confirmation.title = "Confirm Load Character"
	_confirmation.min_size = Vector2i(540,280)
	_confirmation.get_label().autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirmation.get_ok_button().text = "CONFIRM LOAD"
	_confirmation.get_cancel_button().text = "CANCEL"
	_confirmation.confirmed.connect(_confirm_restore)
	_confirmation.canceled.connect(_cancel_restore)
	add_child(_confirmation)
	# Keep backup management discoverable outside the collapsed inventory and
	# advancement sections. All requests still use the existing safety gates.
	var controls := HBoxContainer.new()
	_controls = controls
	controls.name = "CharacterBackupControls"
	for action: String in ["export", "preview"]:
		var button := Button.new()
		button.name = "ExportBackup" if action == "export" else "PreviewRestoreBackup"
		button.text = "SAVE CHARACTER" if action == "export" else "LOAD CHARACTER"
		button.tooltip_text = "Save a copy of your character to your computer." if action == "export" else "Select an existing character save file. Nothing changes until you confirm loading."
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_on_action.bind(StringName(action)))
		controls.add_child(button)
	_controller._rewards_label.get_parent().add_child(controls)
	_controller._rewards_label.get_parent().move_child(controls, 1)

func _character_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_controller.get_viewport().set_input_as_handled()
		open_actions()

func open_actions() -> void:
	_show("SAVE CHARACTER — Save a copy of your secured character progress to your computer.\nSELECT SAVE FILE — Browse for a saved character and review a read-only preview. Your character changes only after you confirm loading.\nCANCEL — Exit without changing your character.")

func _safe(read_only_preview: bool = false) -> Dictionary:
	if _controller._session == null or _controller._session.is_encounter_active(): return Backup.fail("backups_require_ready_downtime_or_defeat")
	if _controller._browser_transition_blocked():
		var failed: bool = _controller._web_operation.get("phase") == "failed"
		var service: PlayableCharacterPersistence = _controller._session._playable_persistence
		if service is PlayableBrowserPersistence and service._browser_result.get("state") in ["failed","unavailable","recovery_required"]: failed = true
		if not read_only_preview or not failed: return Backup.fail("character_storage_pending_or_uncertain")
	if _controller._session._reward_mode not in ["normal","dev_normal"]: return Backup.fail("test_mode_backups_unavailable")
	return {"success":true}

func _on_action(action: StringName) -> void:
	if restoration_blocked:
		if action == &"verify" and _restorer != null: _handle_restore(_restorer.reconcile())
		else: _show("Loading is waiting for confirmation or a save check. Choose CANCEL in the confirmation, or CHECK SAVE RESULT before continuing.")
		return
	if _selecting or (_reader != null and _reader._result.get("state") == "pending"):
		_show("A save or load request is already in progress. Please wait.")
		return
	var permitted := _safe(action == &"preview")
	if not permitted.success:
		_show_result(permitted)
		return
	if action == &"restore":
		if _namespace != _controller._session._reward_mode:
			_show_result(Backup.fail("namespace_changed_reselect_backup"))
			return
		if _preview_source.is_empty() or last_result.get("state") != "preview" or last_result.get("classification") not in ["empty_destination","exact_match","destination_exact_prefix"]:
			_show_result(Backup.fail("eligible_backup_preview_required"))
			return
		_restorer = CharacterBackupRestoration.new()
		var service: PlayableCharacterPersistence = _controller._session._playable_persistence
		var started := _restorer.begin(_preview_source,_namespace,service)
		restoration_blocked = true
		_handle_restore(started)
		return
	if action == &"download":
		var eligible := Reader.export_eligibility(_export_service)
		if not eligible.success or _controller._session._playable_persistence != _export_service or _export_service.generation != _export.get("manifest",{}).get("head_generation"):
			_show_result(Backup.fail("export_admission_changed_prepare_again"))
			return
		if OS.has_feature("web"):
			if _bridge == null: _bridge = Files.web_bridge()
			if _bridge == null:
				_show_result(Backup.fail("browser_file_transfer_unavailable"))
				return
			_bridge.download(_export.text,_filename())
			_show("Download started. Check your browser's downloads to confirm the file was saved to your computer.\nUse SELECT SAVE FILE to review it without changing your character.")
		else:
			_picker.file_mode = FileDialog.FILE_MODE_SAVE_FILE
			_picker.title = "Save Character File"
			_picker.current_file = _filename()
			_dialog.hide()
			_picker.popup_centered_ratio(0.65)
		return
	_namespace = _controller._session._reward_mode
	if action == &"export":
		_export_service = _controller._session._playable_persistence
		_reader = Reader.new()
		_accept(_reader.begin_export(_export_service))
	elif action == &"preview":
		_export.clear()
		if _download_button != null: _download_button.hide()
		if _restore_button != null: _restore_button.hide()
		if OS.has_feature("web"):
			if _bridge == null: _bridge = Files.web_bridge()
			if _bridge == null:
				_show_result(Backup.fail("browser_file_transfer_unavailable"))
				return
			_selecting = bool(_bridge.choose(Backup.MAX_BYTES))
			_show("Select a character save file. The preview is read-only; your character will not change until you confirm loading.")
		else:
			_picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
			_picker.title = "Select Save File"
			_dialog.hide()
			_picker.popup_centered_ratio(0.65)

func _process(_delta: float) -> void:
	_update_controls()
	if _restorer != null and _restorer.status.state == "pending": _handle_restore(_restorer.poll())
	if _admitting and _controller._web_operation.is_empty():
		_admitting = false
		_show("Character loaded from the saved checkpoint. No rewards were added again.")
	elif _admitting and _controller._web_operation.get("phase") == "failed":
		_admitting = false
		var reason := String(_controller._web_operation.service.status().get("reason","unavailable"))
		_log_reason(reason)
		_show("The save file was added to storage, but the character could not be opened. Your previous session is still active.\n"+_failure_text(reason))
	for index in range(_draining.size()-1,-1,-1):
		if _draining[index].poll().get("state") != "pending":
			_draining[index].dispose()
			_draining.remove_at(index)
	if _selecting:
		var selected: Variant = JSON.parse_string(str(_bridge.poll()))
		if selected is Dictionary and selected.get("state") != "pending":
			_selecting = false
			if selected.get("state") == "selected": preview_text(selected.text)
			elif selected.get("state") == "cancelled": _show("File selection canceled. Your character was not changed.")
			else: _show_result(Backup.fail(selected.get("reason","file_selection_failed")))
	if _reader != null and _reader._result.get("state") == "pending": _accept(_reader.poll())

func _update_controls() -> void:
	if _controls == null: return
	for button: Button in _controls.get_children():
		button.disabled = restoration_blocked or _selecting or not _safe(button.name == "PreviewRestoreBackup").success

func _file_selected(path: String) -> void:
	if _picker.file_mode == FileDialog.FILE_MODE_SAVE_FILE:
		var safe := _safe()
		if not safe.success or _controller._session._playable_persistence != _export_service or not Reader.export_eligibility(_export_service).success or _export_service.generation != _export.get("manifest",{}).get("head_generation"):
			_show_result(Backup.fail("export_admission_changed_prepare_again"))
			return
		var written := Files.save_new_file(path,_export.text)
		last_result = written
		if written.success: _show("Character file saved and verified: %s" % written.path)
		else: _show_result(written)
	else:
		var read := Files.read_file(path)
		if read.success: preview_text(read.text)
		else: _show_result(read)

func preview_text(text: String) -> void:
	var safe := _safe(true)
	if not safe.success:
		_show_result(safe)
		return
	_preview_source = text
	if _namespace != _controller._session._reward_mode:
		_show_result(Backup.fail("namespace_changed_reselect_file"))
		return
	_reader = Reader.new()
	var service: PlayableCharacterPersistence = _controller._session._playable_persistence
	var browser: CharacterBrowserStorage = service.browser if service is PlayableBrowserPersistence else null
	var storage: CharacterSaveStorage = service.storage if service != null else null
	_accept(_reader.begin_preview(text,_namespace,storage,browser))

func _accept(result: Dictionary) -> void:
	if result.get("state") == "pending":
		_show("Checking your saved character. No character data is being changed.")
		return
	last_result = result.duplicate(true)
	if not result.get("success",false):
		_show_result(result)
		return
	if result.get("state") == "export_ready":
		if _controller._session._playable_persistence != _export_service:
			_show_result(Backup.fail("export_admission_changed_prepare_again"))
			return
		_export = result
		if _download_button == null:
			_download_button = _dialog.add_button("SAVE FILE",false,"download")
		_download_button.show()
		_show(_preview_text(result.preview)+"\nYour character file is ready. Choose SAVE FILE to save it to your computer.\nIncludes your last secured checkpoint, not unfinished combat.")
	else:
		if _restore_button == null: _restore_button = _dialog.add_button("CONFIRM LOAD",false,"restore")
		_restore_button.show()
		_restore_button.disabled = result.classification not in ["empty_destination","exact_match","destination_exact_prefix"]
		_log_reason("preview: %s; destination: %s" % [result.classification,result.get("destination_reason","")])
		_show(_preview_text(result.preview)+"\n"+_comparison_text(result.classification)+"\nREAD ONLY preview — your character has not changed. CONFIRM LOAD opens a separate confirmation; CANCEL leaves your character unchanged.")

func _preview_text(value: Dictionary) -> String:
	return "%s | %s | Level %s\nXP earned %s / spent %s / available %s | Gold %s\nEquipment: %s\nInventory: %s (%s entries)\nLast saved checkpoint: %s / %s\nSave revision: %s | File created (UTC): %s\nFile integrity checked. This does not prove who created the file." % [value.character,"DEV NORMAL (developer character)" if value.namespace == "dev_normal" else "NORMAL",value.level,value.xp.earned,value.xp.spent,value.xp.unspent,value.gold,", ".join(value.equipment),", ".join(value.inventory.slice(0,4)),value.inventory.size(),String(value.checkpoint.wave_id).replace("_"," ").capitalize(),String(value.checkpoint.phase).replace("_"," "),value.generation,value.created_utc]

func _filename() -> String:
	return "%s_g%s_%s_%s%s" % [_export.manifest.profile_id,_export.manifest.head_generation,String(_export.manifest.created_utc).replace(":","-"),String(_export.backup_digest).substr(0,8),Files.EXTENSION]

func _show_result(result: Dictionary) -> void:
	last_result = result.duplicate(true)
	var reason := String(result.get("reason","unavailable"))
	_log_reason(reason)
	_show(_failure_text(reason))

func _log_reason(reason: String) -> void:
	_controller._append_log("Character save/load: "+reason)
	var service: PlayableCharacterPersistence = _controller._session._playable_persistence if _controller._session != null else null
	if service != null and not service._failure.is_empty(): _controller._append_log("Character storage detail: "+service._failure)

func _comparison_text(classification: String) -> String:
	match classification:
		"empty_destination": return "No character is saved here yet. This compatible file can be loaded after confirmation."
		"exact_match": return "This file matches your saved character. Loading it adds no rewards or items."
		"destination_exact_prefix": return "This file continues your character's saved history and can be loaded after confirmation."
		"backup_older_than_destination": return "Cannot load: this file is older than your saved progress. Your newer progress will be kept."
		"divergent_history": return "Cannot load: this file does not match your character's history. Progress cannot be combined or overwritten."
		"unsupported_namespace_or_version": return "Cannot load: this file uses a different character mode or unsupported save version."
		_: return "Cannot load: your existing saved character could not be verified. It will not be replaced."

func _failure_text(reason: String) -> String:
	match reason:
		"backups_require_ready_downtime_or_defeat", "restoration_admission_not_safe":
			return "Cannot save or load during combat. Wait until your character is in a safe state."
		"test_mode_backups_unavailable": return "Save / Load Character is unavailable in TEST mode. Use NORMAL or DEV NORMAL."
		"admitted_acknowledged_character_required":
			var service: PlayableCharacterPersistence = _controller._session._playable_persistence if _controller._session != null else null
			if _controller._web_operation.get("kind") == "load" and _controller._web_operation.get("phase") != "failed": return "Cannot save yet. Your character is still loading."
			if service == null: return "Cannot save this character. Select a character with verified saving in NORMAL or DEV NORMAL."
			if service._reset: return "Cannot save this reset session. Reload your saved character first."
			return "Cannot save yet. Your character's saved progress has not been verified. See FULL LOG for details."
		"character_storage_pending_or_uncertain", "checkpoint_pending_or_uncertain", "browser_storage_pending_or_unavailable":
			if _controller._web_operation.get("kind") == "load" and _controller._web_operation.get("phase") != "failed": return "Cannot continue yet. Your character is still loading."
			return "Your saved progress is still being saved or could not be verified. Wait for a confirmed save, or check the save-status message before trying again."
		"desktop_storage_unavailable": return "Character storage on this computer is unavailable. Check access and free disk space; no save file was prepared."
		"browser_file_transfer_unavailable": return "Your browser cannot open or download character files right now. No character data was changed."
		"namespace_mismatch", "namespace_changed_reselect_backup", "namespace_changed_reselect_file", "restoration_namespace_changed":
			return "Cannot load this file in the selected mode. NORMAL and DEV NORMAL characters are separate. Select a file for the current mode."
		"profile_source_or_namespace_mismatch", "destination_admission_pending_or_mismatched":
			return "This file or saved profile does not match the selected character, rules, or mode. Wait for character loading to finish and select a compatible file."
		"unsupported_backup_version", "unsupported_character_version", "unsupported_format_or_version":
			return "Cannot load this save-file version. It requires a compatible game version. Your character was not changed."
		"backup_size_limit", "backup_depth_limit", "backup_structure_limit", "invalid_or_oversized_generation_history":
			return "This save file exceeds the supported size or complexity limit. It cannot be opened safely."
		"backup_file_read_failed", "invalid_or_unreadable_utf8", "file_selection_failed":
			return "The selected save file could not be read. Check that it is accessible and complete, then select it again."
		"backup_output_already_exists": return "A file already exists at that location. Choose a new filename; the existing file will not be overwritten."
		"backup_cannot_target_profile_storage": return "Choose a different folder. Character files cannot be written into the game's internal save folder."
		"invalid_backup_output": return "Choose a filename ending in .itankbackup.json and keep the file within the supported size limit."
		"backup_output_unavailable", "backup_output_publish_failed": return "The character file could not be saved at that location. Check folder permissions and free disk space, then choose a new filename."
		"backup_output_verification_failed": return "The written character file could not be verified. Do not rely on it; keep your previous save and try a new filename."
		"stored_head_not_acknowledged_character", "stored_transaction_not_acknowledged_character", "export_admission_changed_prepare_again":
			return "Your saved character changed while this file was being prepared. Wait for saving to finish, then choose SAVE CHARACTER again."
		"committed_history_unavailable": return "Your complete saved character history could not be read. A trusted character file cannot be prepared yet."
		"eligible_backup_preview_required", "explicit_restoration_confirmation_required": return "Select a compatible save file and review its read-only preview before confirming the load."
		"backup_older_than_destination", "divergent_history", "corrupt_or_uncertain_destination", "unsupported_namespace_or_version": return _comparison_text(reason)
		"destination_changed_after_preview", "stale_generation", "backup_changed": return "Saved progress or the selected file changed after preview. Cancel and select the file again; the previous save is kept."
		"profile_in_use", "profile_in_use_or_acquiring", "writer_locked", "writer_busy", "writer_lock_busy", "writer_lock_required", "writer_unavailable": return "This character is in use by another window or tab, or its save lock is unavailable. Close the other character session and try again."
		"quota_exceeded", "quota_exhausted": return "Storage is full. Free space before trying again. A completed save has not been confirmed."
		"permission_denied": return "Permission to use character storage was denied. Check your browser or folder permissions. A completed save has not been confirmed."
	if reason.begins_with("invalid_") or reason.begins_with("duplicate_") or reason in ["backup_checksum_mismatch","noncanonical_backup_body","truncated_json","generation_gap","history_conflict","backup_manifest_head_mismatch"]:
		return "This save file is damaged, incomplete, or contains inconsistent character history. It could not be verified; no character was loaded. See FULL LOG for details."
	return "The save or load request could not be completed safely. Check the save-status message and FULL LOG for details before trying again."

func _show(text: String) -> void:
	_dialog.dialog_text = text
	if not _dialog.visible: _dialog.popup_centered_clamped(Vector2i(720,380),0.9)

func _close() -> void:
	if restoration_blocked:
		if _restorer != null and _restorer.status.state != "pending" and not _restorer.uncertain: _cancel_restore()
		else: _show("The load result must be checked before closing. Use CHECK SAVE RESULT.")
		return
	if _bridge != null: _bridge.cancel()
	_selecting = false
	if _reader != null:
		if _reader._result.get("state") == "pending": _draining.append(_reader)
		else: _reader.dispose()
	_reader = null
	_export.clear()
	last_result.clear()
	if _download_button != null: _download_button.hide()
	if _restore_button != null: _restore_button.hide()
	_preview_source = ""

func _confirm_restore() -> void:
	if _restorer == null: return
	_confirmation.hide()
	if _controller._session.is_encounter_active() or _controller._session._reward_mode != _namespace or not _controller._web_operation.is_empty():
		_show("Cannot load now: gameplay or character mode changed. Cancel and select the save file again.")
		return
	_handle_restore(_restorer.confirm())

func _cancel_restore() -> void:
	if _restorer == null: return
	_confirmation.hide()
	var cancelled := _restorer.cancel()
	if not cancelled.success:
		_show("Loading may already have saved data. Use CHECK SAVE RESULT before continuing; cancellation cannot undo an unconfirmed save.")
		return
	_restorer = null
	restoration_blocked = false
	_show("Load canceled. Your character was not changed.")

func _handle_restore(result: Dictionary) -> void:
	if result.get("state") == "pending":
		_show("Loading and checking the save. Combat, movement and character changes are paused. Please wait for confirmation.")
	elif result.get("state") == "confirmation_required":
		_dialog.hide()
		if _verify_button != null: _verify_button.hide()
		_confirmation.dialog_text = _preview_text(_restorer.backup.preview)+"\n"+_comparison_text(result.classification)+"\nLoad this exact saved checkpoint? CONFIRM LOAD applies this compatible save. CANCEL leaves your character unchanged.\nOlder saves and saves with conflicting history cannot replace your progress. Characters and rewards cannot be combined."
		_confirmation.popup_centered_clamped(Vector2i(760,440),0.9)
	elif result.get("state") == "verified_committed":
		var payload: Dictionary = result.payload
		var lease: PlayableBrowserPersistence = _restorer.lease_service
		var handed := _restorer.handoff()
		if not handed.success:
			_handle_restore(handed)
			return
		restoration_blocked = false
		var loaded: Dictionary = _controller._load_backup_checkpoint(payload,lease)
		if loaded.get("state") == "pending":
			_admitting = true
			_show("Save verified. Opening your character at the saved checkpoint.")
		elif loaded.get("success",false): _show("Character loaded from the saved checkpoint. No rewards were added again.")
		else:
			var reason := String(loaded.get("reason","unavailable"))
			_log_reason(reason)
			_show("The save file was added to storage, but the character could not be opened. Your previous session is still active.\n"+_failure_text(reason))
		last_result = result.duplicate(true)
		_preview_source = ""
		if _restore_button != null: _restore_button.hide()
		if _verify_button != null: _verify_button.hide()
	else:
		var reason := String(result.get("reason","unavailable"))
		_log_reason(reason)
		_show(_failure_text(reason)+"\nYour previous verified saves are kept.")
		if _restorer.uncertain:
			if _verify_button == null: _verify_button = _dialog.add_button("CHECK SAVE RESULT",false,"verify")
			_verify_button.show()

func _exit_tree() -> void:
	if _restorer != null: _restorer.dispose()
	_restorer = null
	restoration_blocked = false
	_close()
	for reader: CharacterBackupReader in _draining: reader.dispose()
	_draining.clear()
