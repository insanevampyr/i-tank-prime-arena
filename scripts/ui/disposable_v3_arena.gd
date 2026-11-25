extends "res://scripts/ui/arena_combat_controller.gd"

# Explicit alternate development scene ONLY. The default Arena scene and its
# production admission/routing never reference this controller.
const V3 = preload("res://scripts/rewards/minimal_character_snapshot_v3.gd")
const Birth = preload("res://scripts/rewards/disposable_v3_creation.gd")
const BrowserStore = preload("res://scripts/rewards/minimal_v3_browser_storage.gd")
const WindowsStore = preload("res://scripts/rewards/minimal_v3_windows_storage.gd")
const HELPER_HASH := "a6dac728d1bf305b3754461876eff7213d8bf3625aa52c21f8c4f46470d1ed1b"
var _enabled := false
var _slot := ""
var _mode := "normal"
var _owner: CharacterPersistenceCoordinator
var _route: RefCounted
var _opening := ""
var _creating := false
var _failed := ""
var _verified := false
var _ack_sequence := 0
var _ticking := false
var _player_template: PackedScene
var _panel: PanelContainer
var _status: Label
var _mode_option: OptionButton
var _buttons := {}
var _new_dialog: ConfirmationDialog
var _new_boost: Button
var _tools_toggle: Button
var _tools_open := true

func _ready() -> void:
	var value := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--arena-disposable-v3="): value = argument.trim_prefix("--arena-disposable-v3=")
	if OS.has_feature("web"):
		value = str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('arena_disposable_v3')||''"))
	var pattern := RegEx.new()
	var compiled := pattern.compile("^[a-z0-9][a-z0-9-]{0,23}$")
	_enabled = (OS.is_debug_build() or OS.has_feature("arena_disposable_v3")) and compiled == OK and pattern.search(value) != null
	if not _enabled:
		_player.set_physics_process(false)
		_combat_status.text = "DISPOSABLE V3 DISABLED — requires an explicit test build/scene and slot."
		set_physics_process(false)
		return
	_slot = value
	var visual := _player.duplicate()
	for child: Node in visual.find_children("*","",true,false): child.owner = visual
	_player_template = PackedScene.new()
	var packed := _player_template.pack(visual)
	visual.free()
	if packed != OK: _enabled = false; return
	# Bootstrap the inherited UI with its original nonpersistent Guard fixture.
	# No character or browser production admission is attempted on this path.
	_developer_test_mode = true
	super._ready()
	# Unsupported legacy file controls never remain executable in this route.
	var backups := _backup_actions
	var backup_controls := _rewards_label.get_parent().get_node_or_null("CharacterBackupControls")
	if backup_controls != null: backup_controls.queue_free()
	if backups != null:
		if backups._legacy_open_button != null: backups._legacy_open_button.queue_free()
		_backup_actions = null; backups.queue_free()
	if _expc_grant_actions != null:
		_expc_grant_actions._button.queue_free(); _expc_grant_actions.queue_free(); _expc_grant_actions = null
	_create_test_controls()
	_render_test_status()

func _create_test_controls() -> void:
	_panel = PanelContainer.new(); _panel.name = "DisposableV3Controls"
	_character_selector.get_parent().add_child(_panel)
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_panel.offset_left = -490; _panel.offset_right = -16; _panel.offset_top = -262; _panel.offset_bottom = -78
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_tools_toggle = Button.new(); _tools_toggle.name = "V3ToolsToggle"; _tools_toggle.text = "V3 SAVE TOOLS"; _tools_toggle.focus_mode = Control.FOCUS_NONE
	_character_selector.get_parent().add_child(_tools_toggle)
	_tools_toggle.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_tools_toggle.offset_left = -180; _tools_toggle.offset_right = -16; _tools_toggle.offset_top = -64; _tools_toggle.offset_bottom = -30
	_tools_toggle.pressed.connect(_toggle_test_tools)
	var column := VBoxContainer.new(); _panel.add_child(column)
	var title := Label.new(); title.text = "DISPOSABLE V3 · "+_slot+" · NOT A PRODUCTION CHARACTER"; title.add_theme_font_size_override("font_size",12); column.add_child(title)
	var row := HBoxContainer.new(); column.add_child(row)
	_mode_option = OptionButton.new(); _mode_option.name = "V3Namespace"; _mode_option.focus_mode = Control.FOCUS_NONE
	_mode_option.add_item("NORMAL ×1"); _mode_option.add_item("Eligible DEV ×10")
	_mode_option.item_selected.connect(func(index: int): _mode = "normal" if index == 0 else "dev_normal")
	row.add_child(_mode_option)
	_add_test_button(row,"Create","CREATE NEW",func(): _open_test(true))
	_add_test_button(row,"Load","LOAD / RESUME",func(): _open_test(false))
	row = HBoxContainer.new(); column.add_child(row)
	_add_test_button(row,"Save","SAVE CHECKPOINT",_save_test)
	_add_test_button(row,"Retry","RETRY SAME SAVE",_retry_test)
	_add_test_button(row,"NewRun","NEW RUN…",_ask_test_new_run)
	_status = Label.new(); _status.name = "V3SaveStatus"; _status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; _status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_character_selector.get_parent().add_child(_status)
	_status.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_status.offset_left = 16; _status.offset_right = -196; _status.offset_top = -70; _status.offset_bottom = -28
	_status.add_theme_font_size_override("font_size",14)
	_new_dialog = ConfirmationDialog.new(); _new_dialog.name = "V3NewRunConfirmation"; _new_dialog.title = "Abandon this disposable run?"
	_new_dialog.get_label().autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_new_dialog.min_size = Vector2i(600,230)
	_new_dialog.dialog_text = "Start a genuine new Wave 1 run? Committed permanent progression and items remain. The saved attempt is abandoned only by its original authorized transaction."
	_new_boost = _new_dialog.add_button("Next DEV run: XP ×1",false,"xp")
	_new_boost.toggle_mode = true
	_new_boost.pressed.connect(func(): _new_boost.text = "Next DEV run: XP ×10" if _new_boost.button_pressed else "Next DEV run: XP ×1")
	_new_dialog.confirmed.connect(_confirm_test_new_run); add_child(_new_dialog)

func _toggle_test_tools() -> void:
	if not _tools_open and _combat_inventory_open:
		_combat_inventory_open = false
		_update_rewards_panel(true)
	_set_test_tools(not _tools_open)

func _set_test_tools(open: bool) -> void:
	_tools_open = open
	_panel.visible = open
	_tools_toggle.text = "CLOSE V3 TOOLS" if open else "V3 SAVE TOOLS"
	if not open:
		var focused := get_viewport().gui_get_focus_owner()
		if focused != null and _panel.is_ancestor_of(focused): focused.release_focus()

func _add_test_button(row: Control, id: String, text: String, callback: Callable) -> void:
	var button := Button.new(); button.name = "V3"+id; button.text = text; button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback); row.add_child(button); _buttons[id] = button

func _native_store() -> RefCounted:
	var source: CombatCharacterDefinitionResource = PlayableCharacterAdmission.prepare_starter(&"vaelis_thorn",_mode).source
	var profile := "prod_vaelis_thorn" if _mode == "normal" else "dev_vaelis_thorn"
	var path := OS.get_cache_dir().path_join("itank-storage-tests/minimal46i1_46k_"+_slot+"_"+_mode)
	return WindowsStore.new(path,source,profile,_mode,OS.get_environment("TEMP").path_join("arena46i1_native/safe_head_replace.exe"),HELPER_HASH)

func _open_test(create: bool) -> void:
	if not _enabled or _owner != null or not _opening.is_empty(): return
	_failed = ""; _creating = create; _verified = false; _opening = "read"
	var starter := PlayableCharacterAdmission.prepare_starter(&"vaelis_thorn",_mode)
	if not starter.success: _test_failure(starter); return
	if OS.has_feature("web"):
		_route = BrowserStore.new("itank-arena-disposable-v3-46j-46k-"+_slot+"-"+_mode.replace("_","-"),starter.source,starter.profile_id,_mode)
		var queued: Dictionary = _route.begin_load(true)
		if queued.get("state") != "pending": _test_failure(queued)
	else:
		_route = _native_store()
		var loaded: Dictionary = _route.load_current()
		if loaded.success and not loaded.get("empty",true) and (loaded.repair_current or loaded.repair_replica): loaded = _route.recover()
		_complete_test_load(loaded)
	_render_test_status()

func _complete_test_load(loaded: Dictionary) -> void:
	if not loaded.success: _test_failure(loaded); return
	if loaded.get("empty",false) != _creating:
		_test_failure({"reason":"existing_test_character_cannot_be_replaced" if _creating else "disposable_character_missing_create_explicitly"}); return
	var starter := PlayableCharacterAdmission.prepare_starter(&"vaelis_thorn",_mode)
	var text: String = loaded.get("text","")
	if _creating:
		var birth := Birth.prepare(_mode,combat_seed)
		if not birth.success: _test_failure(birth); return
		text = birth.text
	_owner = CharacterPersistenceCoordinator.new(null)
	var root := OS.get_cache_dir().path_join("itank-storage-tests/minimal46c2_46k_"+_slot+"_"+_mode)
	var opened := _owner.admit_minimal_snapshot_v3(text,starter.source,starter.profile_id,_mode,root,_make_test_player)
	if not opened.success: _test_failure(opened); return
	var attached: Dictionary
	if OS.has_feature("web"):
		attached = _owner.attach_minimal_browser(_route)
	else:
		attached = _owner.attach_minimal_windows(_route.root,_route.executable,_route.executable_hash)
	if not attached.success: _test_failure(attached); return
	_adopt_test_runtime()
	_set_test_tools(false)
	if OS.has_feature("web"): _owner.automatic_minimal_browser(true)
	else: _owner.automatic_minimal_windows(true)
	if not _creating:
		_opening = ""; _verified = true
		_ack_sequence = int(JSON.parse_string(_owner.minimal_view().body_json).sequence)
		_last_ui_message = "Disposable character resumed from exact verified compact checkpoint."
		_update_presentation()
	else:
		_opening = "initial"
		var published := _owner.begin_minimal_browser() if OS.has_feature("web") else _owner.publish_minimal_windows()
		if published.get("state") != "pending": _finish_test_save(published)

func _make_test_player() -> PlaceholderPlayer:
	# Ready the actual visual/physics node BEFORE the gate binds its movement
	# identity. Reusing an old admitted node or resetting it afterward is forbidden.
	var player := _player_template.instantiate() as PlaceholderPlayer
	player.name = "DisposablePlayer"
	get_parent().add_child(player)
	player.set_authoritative_movement_resolver(_resolve_player_movement)
	return player

func _adopt_test_runtime() -> void:
	var next: PlaceholderPlayer = _owner._minimal_owner._player
	if is_instance_valid(_player) and _player != next: _player.free()
	_player = next; _session = _owner._minimal_owner._session
	_player_character_id = Fixture.PLAYER_CHARACTER_VAELIS; _profile_namespace = _mode; _developer_test_mode = false
	_encounter_selector_index = 0; _encounter_fixture_id = _session._encounter_fixture_id
	_player_hpc_label = _player.get_node_or_null("HPC"); _player_facing_marker = _player.get_node_or_null("FacingMarker")
	_configure_actor_health_label(_player_hpc_label,PLAYER_HPC_LABEL_SIZE,PLAYER_HPC_LABEL_COLOR,13)
	if _floating_combat_text != null: _floating_combat_text._player = _player; _floating_combat_text.clear()
	_session.set_opponent_behavior_enabled(true)
	_player.apply_authoritative_combat_position(_microfeet_to_feet(_session.get_actor_state(&"player").position_microfeet))
	_event_cursor = 0; _event_history_generation = -1; _delta_us_remainder = 0.0
	_applied_displacement_event_ids.clear(); _pending_player_displacement_event_ids.clear(); _invalidate_transcript_cache()
	_rebuild_encounter_visuals(); _process_new_events()

func _test_failure(result: Dictionary) -> void:
	_failed = str(result.get("reason","storage_unavailable")); _opening = ""
	_last_ui_message = "DISPOSABLE SAVE NOT CONFIRMED: "+_failed
	_render_test_status()

func _finish_test_save(result: Dictionary) -> void:
	if not result.get("success",false) or not result.get("durable",false): _test_failure(result); return
	_failed = ""; _opening = ""; _verified = true
	_ack_sequence = int(JSON.parse_string(_owner.minimal_view().body_json).sequence)
	_last_ui_message = "Disposable compact checkpoint independently read back and verified."
	_update_presentation()

func _poll_browser_persistence() -> void:
	if not _enabled: return
	if OS.has_feature("web") and _opening == "read":
		var loaded: Dictionary = _route.poll_load()
		if loaded.get("state") != "pending": _complete_test_load(loaded)
	elif OS.has_feature("web") and _owner != null and not _owner._minimal_owner._browser_phase.is_empty():
		var result := _owner.poll_minimal_browser()
		if result.get("state") != "pending": _finish_test_save(result)
	elif not OS.has_feature("web") and _owner != null and not _owner._minimal_owner._pending.is_empty() and _failed.is_empty():
		# Windows publication is synchronous. A remaining candidate after command
		# return is unacknowledged, regardless of an earlier successful result.
		_test_failure({"reason":"checkpoint_unacknowledged_retry_same_bytes"})
	_render_test_status()

func _save_test() -> void:
	if _owner == null or _browser_transition_blocked(): return
	if _session.get_encounter_state() != Session.ENCOUNTER_BETWEEN_WAVE_DOWNTIME:
		_last_ui_message = "Manual checkpoints require original safe downtime; entry is already saved."; return
	var result := _session._playable_persistence.checkpoint(_session,"downtime")
	if OS.has_feature("web") and result.get("state") == "pending": _opening = "save"
	elif not OS.has_feature("web") and result.get("success",false) and result.get("durable",false): _finish_test_save(result)
	elif not result.get("success",false): _test_failure(result)
	_render_test_status()

func _retry_test() -> void:
	if _owner == null:
		if _route != null and OS.has_feature("web"): _route.close()
		_route = null; _opening = ""; _open_test(_creating); return
	_failed = ""; _opening = "retry"
	var result := _owner.begin_minimal_browser() if OS.has_feature("web") else _owner.publish_minimal_windows()
	if result.get("state") != "pending": _finish_test_save(result)

func _ask_test_new_run() -> void:
	if _owner == null or _browser_transition_blocked() or not _session.get_abandon_run_authorization().success: return
	_new_boost.visible = _mode == "dev_normal"; _new_boost.button_pressed = false
	_new_dialog.popup_centered(Vector2i(600,230))

func _confirm_test_new_run() -> void:
	if _browser_transition_blocked(): return
	var multiplier := 10 if _mode == "dev_normal" and _new_boost.button_pressed else 1
	var result := _owner.prepare_minimal_new_run(multiplier,func(quote: Dictionary): return {"confirmed":true,"binding":V3.V6.digest(quote)})
	if _owner._minimal_owner._session != _session: _adopt_test_runtime()
	if result.success or result.get("state") == "pending":
		_opening = "new_run"
		if result.get("state") != "pending": _finish_test_save(result)
	else: _test_failure(result)

func _on_encounter_button_pressed() -> void:
	if _owner == null or _browser_transition_blocked(): return
	_set_test_tools(false)
	if OS.has_feature("web") and _session.get_encounter_state() == Session.ENCOUNTER_BETWEEN_WAVE_DOWNTIME:
		_freeze_browser_motion()
		var result := _owner.next_minimal_browser_wave()
		if result.get("state") == "pending": _opening = "next_wave"
		elif not result.success: _test_failure(result)
		_rebuild_encounter_visuals(); _render_test_status(); return
	if _session.get_encounter_state() in [Session.ENCOUNTER_PLAYER_DEFEAT,Session.ENCOUNTER_DOUBLE_DEFEAT]:
		_test_failure({"reason":"reload_exact_test_checkpoint_to_retry"}); return
	super._on_encounter_button_pressed()

func _issued_item(kind: String, definition: String, operation: String = "") -> Dictionary:
	var id := _session._next_request_id("v3_"+kind)
	var issued := _owner.issue_temporary_request(_owner.temporary_context(),kind,definition,operation,id)
	return _owner.execute_temporary_request(issued.request) if issued.success else issued

func _on_inventory_equip_pressed() -> void:
	if _owner == null or _browser_transition_blocked(): return
	var entry := _selected_inventory_entry()
	var result := _issued_item("unequip" if entry.get("equipped",false) else "equip",str(entry.get("definition_id","")))
	_last_ui_message = "Equipment updated; checkpoint status below." if result.success else "Equipment rejected: "+str(result.get("reason"))
	_update_rewards_panel(true); _update_presentation()

func _on_inventory_weapon_handling(operation: String) -> void:
	if _owner == null or _browser_transition_blocked(): return
	var result := _issued_item("handling",str(_selected_inventory_entry().get("definition_id","")),operation)
	_last_ui_message = "Original weapon handling accepted." if result.success else "Handling rejected: "+str(result.get("reason"))
	_update_rewards_panel(true); _update_presentation()

func _on_inventory_use_pressed() -> void:
	if _owner == null or _browser_transition_blocked(): return
	var result := _issued_item("use",str(_selected_inventory_entry().get("definition_id","")))
	_last_ui_message = "Original consumable action accepted." if result.success else "Use rejected: "+str(result.get("reason"))
	_update_rewards_panel(true); _update_presentation()

func _prepare_encounter_fixture(_new_run: bool = false, _defeated_checkpoint: Dictionary = {}, _restored_head: Dictionary = {}, _reward_policy: Dictionary = {}) -> Dictionary:
	if _owner != null: return {"success":false,"reason":"explicit_disposable_controls_required"}
	return super._prepare_encounter_fixture()

func _on_encounter_selector_pressed() -> void: pass
func _on_character_selector_pressed() -> void: pass
func _on_return_to_wave_one_pressed() -> void: _ask_test_new_run()
func _open_legacy_profile() -> Dictionary: return {"success":false,"reason":"legacy_profiles_excluded_from_test_route"}
func _use_browser_character_persistence() -> bool: return false

func _browser_transition_blocked() -> bool:
	if not _enabled: return true
	if not _failed.is_empty() or _owner == null: return true
	var pending: bool = not _owner._minimal_owner._browser_phase.is_empty() if OS.has_feature("web") else not _owner._minimal_owner._pending.is_empty()
	return not _opening.is_empty() or (pending and not _ticking)

func _physics_process(delta: float) -> void:
	if not _opening.is_empty() or not _failed.is_empty():
		_poll_browser_persistence()
		_update_presentation()
		return
	_ticking = true
	super._physics_process(delta)
	_ticking = false

func _attack_input_is_blocked_by_ui() -> bool:
	if not _enabled or not _failed.is_empty() or not _opening.is_empty(): return true
	if _new_dialog != null and _new_dialog.visible: return true
	if _panel != null and _panel.visible and _panel.get_global_rect().has_point(get_viewport().get_mouse_position()): return true
	return super._attack_input_is_blocked_by_ui()

func _unhandled_input(event: InputEvent) -> void:
	if _enabled:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and _tools_open:
			_set_test_tools(false); get_viewport().set_input_as_handled(); return
		super._unhandled_input(event)

func _update_presentation() -> void:
	super._update_presentation()
	if _panel != null:
		# Verbose inherited diagnostics are available through FULL LOG/DEV tools.
		# They must not cover the arena in this isolated playable scene.
		_combat_status.hide(); _event_log.hide()
		if _combat_inventory_open and _owner != null: _set_test_tools(false)
		_render_test_status()

func _render_test_status() -> void:
	if _panel == null: return
	var pending: bool = not _opening.is_empty() or (_owner != null and OS.has_feature("web") and not _owner._minimal_owner._browser_phase.is_empty())
	_mode_option.disabled = _owner != null or pending
	_buttons.Create.disabled = _owner != null or pending; _buttons.Load.disabled = _owner != null or pending
	_buttons.Save.disabled = _owner == null or pending or not _failed.is_empty()
	_buttons.Retry.disabled = pending or _failed.is_empty()
	_buttons.NewRun.disabled = _owner == null or pending or not _failed.is_empty() or not _session.get_abandon_run_authorization().success
	_encounter_selector.disabled = true; _character_selector.disabled = true
	if _backup_actions != null:
		var container := _rewards_label.get_parent().get_node_or_null("CharacterBackupControls")
		if container != null: container.hide()
		if _backup_actions._legacy_open_button != null: _backup_actions._legacy_open_button.hide()
	if _expc_grant_actions != null: _expc_grant_actions._button.hide() # Fresh source is ineligible; no legacy grant route.
	if not _failed.is_empty(): _status.text = "NOT SAVED / RECOVERY REQUIRED: "+_failed+". Last acknowledged head retained."
	elif pending: _status.text = "SAVING / VERIFYING — not acknowledged yet."
	elif _owner == null: _status.text = "Explicitly CREATE a new disposable character or LOAD this test slot. No legacy data is opened."
	else: _status.text = "COMPACT CHECKPOINT VERIFIED · "+_mode+" · generation "+str(_ack_sequence)+" · XP ×"+str(_session.get_run_reward_policy().xp_multiplier)+" LOCKED"

func _exit_tree() -> void:
	if _owner != null: _owner.close_minimal_prototype()
	if _route != null and OS.has_feature("web"): _route.close()
