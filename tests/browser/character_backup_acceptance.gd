extends "res://tests/browser/playable_persistence_acceptance.gd"

var _backup_before := {}
var _backup_document := ""
var _backup_generation := 0

func _ready() -> void:
	super._ready()
	JavaScriptBridge.eval("(()=>{const p=document.getElementById('playable-test-results').parentElement;for(const pair of [['prepare','Prepare backup character'],['check','Check preview zero writes']]){const b=document.createElement('button');b.textContent=pair[1];b.onclick=()=>window.arena36lCommand=pair[0];p.prepend(b);}})();",true)

func _process(delta: float) -> void:
	if busy: return
	var command: String = str(JavaScriptBridge.eval("window.arena36lCommand || ''",true))
	if command.is_empty():
		super._process(delta)
		return
	JavaScriptBridge.eval("window.arena36lCommand='';",true)
	busy = true
	if command == "prepare":
		controller._character_selector.pressed.emit()
		await settle(true)
		if controller._session._playable_persistence == null:
			check(false,"Backup fixture requires actual acknowledged admission")
		else:
			controller._encounter_button.pressed.emit()
			var combat := preload("res://tests/test_playable_vaelis_persistence.gd").new()
			combat._defeat_wave(controller._session)
			await settle()
			check(combat._failures.is_empty(),"Source physical attacks secure real XP/growth for backup fixture")
			controller._collect_loot_button.pressed.emit()
			await settle()
			await remember_backup()
			line("READY: right-click CHAR: VAELIS, then EXPORT BACKUP / PREVIEW BACKUP. Use the actual download and file picker. Restoration requires separate explicit confirmation.")
	elif command == "check":
		var actions := controller._backup_actions
		for index in range(1200):
			if actions.last_result.get("state") == "preview": break
			await get_tree().process_frame
		var after := await read_document(controller._session._playable_persistence.profile_id)
		check(actions.last_result.get("state") == "preview" and actions.last_result.get("classification") in ["exact_match","divergent_history","backup_older_than_destination","destination_exact_prefix"],"Actual selected browser file validates and classifies destination: %s" % actions.last_result.get("classification","unavailable"))
		check(controller._session.get_state_snapshot() == _backup_before and after == _backup_document and controller._session._playable_persistence.generation == _backup_generation,"Actual file preview causes ZERO persistent writes, RNG/action/resource/reward mutations")
		check(controller._session.get_state_snapshot().schema_version == 12,"Backup interface leaves schema 12 unchanged")
	busy = false

func remember_backup() -> void:
	_backup_document = await read_document(controller._session._playable_persistence.profile_id)
	_backup_before = controller._session.get_state_snapshot().duplicate(true)
	_backup_generation = controller._session._playable_persistence.generation

func verify_loaded() -> void:
	super.verify_loaded()
	await remember_backup()
