extends Node

const Grant = preload("res://scripts/rewards/character_expc_grant.gd")
var _controller: Node
var _button: Button
var _dialog: ConfirmationDialog
var _retry_button: Button
var _grant: RefCounted

func setup(controller: Node) -> void:
	_controller = controller
	_button = Button.new()
	_button.name = "OneTimeDevExpcCredit"
	_button.text = "REVIEW ONE-TIME +10,000 EXPC"
	_button.tooltip_text = "Review the owner-authorized testing credit for this Legacy DEV character. EXPM and levels are unchanged."
	_button.focus_mode = Control.FOCUS_NONE
	_button.pressed.connect(_begin)
	_controller._rewards_label.get_parent().add_child(_button)
	_controller._rewards_label.get_parent().move_child(_button,3)
	_dialog = ConfirmationDialog.new()
	_dialog.title = "One-time Legacy DEV testing credit"
	_dialog.dialog_hide_on_ok = false
	_dialog.get_label().autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialog.get_ok_button().text = "CONFIRM +10,000 EXPC / +0 EXPM"
	_dialog.get_cancel_button().text = "NOT NOW"
	_dialog.confirmed.connect(_confirm)
	_dialog.canceled.connect(_cancel)
	_retry_button = _dialog.add_button("CHECK / RETRY SAME GRANT",false,"retry")
	_dialog.custom_action.connect(func(action: StringName) -> void:
		if action == &"retry" and _grant != null: _grant.retry(); _render()
	)
	add_child(_dialog)
	_process(0.0)

func blocks_gameplay() -> bool:
	return _grant != null and _grant.blocks_gameplay()

func _process(_delta: float) -> void:
	if _button == null: return
	var session: ArenaCombatSession = _controller._session
	var service: PlayableCharacterPersistence = session._playable_persistence if session != null else null
	_button.visible = Grant.target(service)
	var credited: bool = service != null and service._prior.has("expc_credits")
	_button.text = "ONE-TIME DEV EXPC CREDIT: APPLIED" if credited else "REVIEW ONE-TIME +10,000 EXPC"
	_button.disabled = credited or _controller._browser_transition_blocked() or session == null or not session.get_character_advancement_eligibility().success
	if _grant != null and _grant.status.get("state") == "pending": _grant.poll(); _render()

func _begin() -> void:
	if _controller._browser_transition_blocked(): return
	_grant = Grant.new()
	_grant.begin(_controller._session)
	_render()

func _confirm() -> void:
	if _grant == null: return
	if _controller._session != _grant._session:
		_grant.cancel()
		_dialog.hide()
		return
	_grant.confirm(String(_grant.quote.get("token","")))
	_render()

func _cancel() -> void:
	if _grant != null and not _grant.cancel(): _render(); return
	_dialog.hide()
	_controller._update_combat_movement_lock()

func _render() -> void:
	var state: String = _grant.status.get("state","")
	_dialog.get_ok_button().visible = state == "confirmation_required"
	_dialog.get_cancel_button().disabled = state in ["pending","recovery_required"]
	_dialog.get_cancel_button().text = "NOT NOW" if state == "confirmation_required" else "CLOSE"
	_retry_button.visible = state == "recovery_required"
	if state == "confirmation_required":
		var q: Dictionary = _grant.status.quote
		_dialog.dialog_text = "Profile: %s | Namespace: %s\nVerified committed generation: %d\nEXPC: %d -> %d (+10,000 spendable EXPC)\nEXPM: %d -> %d (UNCHANGED)\nNo levels, resources, purchases or items are granted or rewritten.\nThis fixed testing credit can be applied only once.\nHead SHA-256: %s\nHistory SHA-256: %s\nCONFIRM publishes one verified save generation. NOT NOW changes nothing." % [q.profile_id,q.namespace,q.generation,q.expc_before,q.expc_after,q.expm,q.expm,q.head_digest,q.history_digest]
	elif state == "pending":
		_dialog.dialog_text = "%s\n%d / %d\nGameplay and character changes are paused." % [_grant.status.get("stage","Checking grant result"),_grant.status.get("progress",0),_grant.status.get("total",0)]
	elif state in ["applied","already_applied"]:
		_dialog.dialog_text = "The one-time +10,000 EXPC credit is verified in saved history. EXPM is unchanged.\nIt cannot be granted again after reload or NEW RUN.\nOlder builds without V5 support must not be used to write this character."
		if state == "applied": _dialog.dialog_text += "\nVerified generation: %d\nEXPC: %d\nEXPM: %d (UNCHANGED)" % [_grant.status.generation,_grant.status.expc,_grant.status.expm]
	else:
		_dialog.dialog_text = "Credit not confirmed: %s.\nNo live balance has been changed without verified readback.\nCHECK / RETRY retains the exact confirmed grant; it never creates another grant. Reload the character if storage or the verified head changed." % _grant.status.get("reason","unavailable")
	if not _dialog.visible: _dialog.popup_centered_clamped(Vector2i(740,430),0.9)
	_controller._update_rewards_panel(true)
	_controller._update_combat_movement_lock()
