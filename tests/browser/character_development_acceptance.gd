extends "res://tests/browser/playable_persistence_acceptance.gd"

func _ready() -> void:
	super._ready()
	JavaScriptBridge.eval("(()=>{const p=document.getElementById('playable-test-results').parentElement;for(const pair of [['verify','Verify 37A development'],['reload','Reload 37A development']]){const b=document.createElement('button');b.textContent=pair[1];b.onclick=()=>window.arena37Command=pair[0];p.prepend(b);}})();",true)

func _process(delta: float) -> void:
	if busy: return
	var command: String = str(JavaScriptBridge.eval("window.arena37Command || ''",true))
	if command.is_empty():
		super._process(delta)
		return
	JavaScriptBridge.eval("window.arena37Command='';",true)
	busy = true
	controller._encounter_selector_index = 8
	controller._character_selector.pressed.emit()
	await settle(command == "verify")
	var session := controller._session
	if not check(session._playable_persistence is PlayableBrowserPersistence,"Actual Web admission uses isolated IndexedDB and Web Lock"): busy = false; return
	if command == "verify":
		controller._encounter_button.pressed.emit()
		var helper := preload("res://tests/test_playable_vaelis_persistence.gd").new()
		helper._defeat_wave(session)
		await settle()
		check(helper._failures.is_empty(),"Source-backed combat reaches legal downtime")
		var state := session.get_actor_state(&"player")
		var hpc: Variant = state.current_hpc
		var resources := state.resources.duplicate(true)
		var result := session.request_character_development("preferences",{"order":["block","nac","dodge","soak"]},"browser_preference")
		check(result.success,"Authoritative development command accepted in downtime")
		await settle()
		check(session._playable_persistence._last_ack,"IndexedDB transaction and exact readback acknowledged")
		check(state.current_hpc == hpc and state.resources == resources,"Development creates no free resource recovery")
	var service: PlayableBrowserPersistence = session._playable_persistence
	var document := await read_document(service.profile_id)
	var decoded := CharacterSaveContract.decode(document)
	if check(decoded.success,"Stored V2 document validates"):
		var development: Dictionary = decoded.payload.permanent.get("development",{})
		var inspected := CharacterDevelopment.inspect(development)
		check(inspected.success and inspected.get("preferences",[]) == ["block","nac","dodge","soak"],"Saved defender preference order survives exact Web readback")
		check(session.get_actor_state(&"player").progression.get("development",{}) == development,"Playable Web state and committed profile agree")
		check(session.get_actor_state(&"player").resources == decoded.payload.recovery.player.resources and session.get_actor_state(&"player").current_hpc == decoded.payload.recovery.player.current_hpc,"Reload preserves exact checkpoint resources")
	check(session.get_state_snapshot().schema_version == 12,"Simulation schema remains 12")
	line("37A COMPLETE: "+command+"; no production database or profile used.")
	busy = false
