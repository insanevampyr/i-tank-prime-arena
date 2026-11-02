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
	character_button.tooltip_text = "Select character. Right-click for character backup actions."
	character_button.gui_input.connect(_character_input)
	_dialog = AcceptDialog.new()
	_dialog.name = "CharacterBackupDialog"
	_dialog.title = "Character backups"
	_dialog.min_size = Vector2i(540,220)
	_dialog.get_label().autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialog.get_ok_button().text = "CLOSE"
	_dialog.add_button("EXPORT BACKUP",false,"export")
	_dialog.add_button("PREVIEW BACKUP",false,"preview")
	_dialog.custom_action.connect(_on_action)
	_dialog.confirmed.connect(_close)
	_dialog.canceled.connect(_close)
	add_child(_dialog)
	_picker = FileDialog.new()
	_picker.name = "CharacterBackupFilePicker"
	_picker.access = FileDialog.ACCESS_FILESYSTEM
	_picker.use_native_dialog = true
	_picker.filters = PackedStringArray(["*.itankbackup.json,*.json ; Character backup"])
	_picker.file_selected.connect(_file_selected)
	_picker.canceled.connect(func(): _show("File selection cancelled. No character data changed."))
	add_child(_picker)
	_confirmation = ConfirmationDialog.new()
	_confirmation.title = "Confirm character backup restoration"
	_confirmation.min_size = Vector2i(540,280)
	_confirmation.get_label().autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirmation.get_ok_button().text = "RESTORE"
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
		button.text = "EXPORT BACKUP" if action == "export" else "PREVIEW / RESTORE BACKUP"
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
	_show("EXPORT creates a backup of verified committed progression.\nPREVIEW validates a file and compares history; it never restores or writes a profile.\nUnsigned local backups provide integrity, not authenticity.")

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
		else: _show("Restoration is awaiting confirmation or verification. Cancel the confirmation, or verify the result before continuing.")
		return
	if _selecting or (_reader != null and _reader._result.get("state") == "pending"):
		_show("A backup operation is already pending.")
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
			_show("Browser download requested. This does not prove the file was retained.\nUse PREVIEW BACKUP to select and validate the downloaded file.")
		else:
			_picker.file_mode = FileDialog.FILE_MODE_SAVE_FILE
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
			_show("Choose one backup file. Preview is read-only.")
		else:
			_picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
			_dialog.hide()
			_picker.popup_centered_ratio(0.65)

func _process(_delta: float) -> void:
	_update_controls()
	if _restorer != null and _restorer.status.state == "pending": _handle_restore(_restorer.poll())
	if _admitting and _controller._web_operation.is_empty():
		_admitting = false
		_show("Restoration verified and character checkpoint loaded. No rewards were replayed.")
	elif _admitting and _controller._web_operation.get("phase") == "failed":
		_admitting = false
		_show("Restoration is committed, but character admission is blocked: "+String(_controller._web_operation.service.status().get("reason","unavailable"))+". The previous session remains intact.")
	for index in range(_draining.size()-1,-1,-1):
		if _draining[index].poll().get("state") != "pending":
			_draining[index].dispose()
			_draining.remove_at(index)
	if _selecting:
		var selected: Variant = JSON.parse_string(str(_bridge.poll()))
		if selected is Dictionary and selected.get("state") != "pending":
			_selecting = false
			if selected.get("state") == "selected": preview_text(selected.text)
			elif selected.get("state") == "cancelled": _show("File selection cancelled. No character data changed.")
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
		_show("Backup file written and exact bytes read back: %s" % written.path if written.success else "Backup failed: %s" % written.reason)
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
		_show("Reading verified history. No character data is being written.")
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
			_download_button = _dialog.add_button("DOWNLOAD / SAVE PREPARED BACKUP",false,"download")
		_download_button.show()
		_show(_preview_text(result.preview)+"\nVerified backup ready. Click DOWNLOAD / SAVE PREPARED BACKUP.\nOnly the last secured boundary is included; no mid-combat state.")
	else:
		if _restore_button == null: _restore_button = _dialog.add_button("RESTORE",false,"restore")
		_restore_button.show()
		_restore_button.disabled = result.classification not in ["empty_destination","exact_match","destination_exact_prefix"]
		_show(_preview_text(result.preview)+"\nDestination: "+String(result.classification).replace("_"," ")+"\nREAD ONLY preview — no profile data changed. RESTORE requires separate confirmation.")

func _preview_text(value: Dictionary) -> String:
	return "%s | %s | Backup v%s\nProfile: %s | Level %s | Generation %s\nXP earned %s / spent %s / available %s | Gold %s\nEquipment: %s\nInventory: %s (%s entries)\nSecured: %s / %s / %s\nBackup UTC: %s\nIntegrity validated; unsigned and not authenticated." % [value.character,value.namespace,value.backup_version,value.profile_id,value.level,value.generation,value.xp.earned,value.xp.spent,value.xp.unspent,value.gold,", ".join(value.equipment),", ".join(value.inventory.slice(0,4)),value.inventory.size(),value.checkpoint.wave_id,value.checkpoint.phase,value.checkpoint.run_id,value.created_utc]

func _filename() -> String:
	return "%s_g%s_%s_%s%s" % [_export.manifest.profile_id,_export.manifest.head_generation,String(_export.manifest.created_utc).replace(":","-"),String(_export.backup_digest).substr(0,8),Files.EXTENSION]

func _show_result(result: Dictionary) -> void:
	last_result = result.duplicate(true)
	_show("Backup unavailable: %s. No profile data changed." % String(result.get("reason","unavailable")).replace("_"," "))

func _show(text: String) -> void:
	_dialog.dialog_text = text
	if not _dialog.visible: _dialog.popup_centered_clamped(Vector2i(720,380),0.9)

func _close() -> void:
	if restoration_blocked:
		if _restorer != null and _restorer.status.state != "pending" and not _restorer.uncertain: _cancel_restore()
		else: _show("Restoration requires verification before closing. Use VERIFY RESULT.")
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
		_show("Restoration blocked: gameplay or namespace changed. Cancel and preview again.")
		return
	_handle_restore(_restorer.confirm())

func _cancel_restore() -> void:
	if _restorer == null: return
	_confirmation.hide()
	var cancelled := _restorer.cancel()
	if not cancelled.success:
		_show("Cannot cancel an uncertain publication. Use VERIFY RESULT.")
		return
	_restorer = null
	restoration_blocked = false
	_show("Restoration cancelled. No character data changed.")

func _handle_restore(result: Dictionary) -> void:
	if result.get("state") == "pending":
		_show("Restoration pending. Combat, movement and conflicting character actions are paused. No success is assumed.")
	elif result.get("state") == "confirmation_required":
		_dialog.hide()
		if _verify_button != null: _verify_button.hide()
		_confirmation.dialog_text = _preview_text(_restorer.backup.preview)+"\nDestination: "+String(result.classification).replace("_"," ")+"\nWARNING: Replace saved progress with this exact checkpoint?\nOlder or divergent histories cannot be restored. No merging or cloning."
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
			_show("Restoration verified in storage. Loading the exact secured character checkpoint.")
		elif loaded.get("success",false): _show("Restoration verified and character checkpoint loaded. No rewards were replayed.")
		else: _show("Restoration committed; character admission blocked: "+String(loaded.get("reason","unavailable")))
		last_result = result.duplicate(true)
		_preview_source = ""
		if _restore_button != null: _restore_button.hide()
		if _verify_button != null: _verify_button.hide()
	else:
		_show("Restoration blocked: "+String(result.get("reason","unavailable"))+". Previous generations are preserved.")
		if _restorer.uncertain:
			if _verify_button == null: _verify_button = _dialog.add_button("VERIFY RESULT",false,"verify")
			_verify_button.show()

func _exit_tree() -> void:
	if _restorer != null: _restorer.dispose()
	_restorer = null
	restoration_blocked = false
	_close()
	for reader: CharacterBackupReader in _draining: reader.dispose()
	_draining.clear()
