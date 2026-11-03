extends "res://tests/browser/playable_persistence_acceptance.gd"

var ready_observation := {}

func _ready() -> void:
	super._ready()
	JavaScriptBridge.eval("(()=>{const p=document.getElementById('playable-test-results').parentElement;for(const pair of [['prepare','Prepare funded entry'],['ready','Load READY purchase UI'],['verify','Verify manual purchase'],['buy','Verify downtime STR purchase'],['reload','Reload purchased STR']]){const b=document.createElement('button');b.textContent=pair[1];b.onclick=()=>window.str37Command=pair[0];p.prepend(b);}})();",true)

func _process(delta: float) -> void:
	if busy: return
	var command: String = str(JavaScriptBridge.eval("window.str37Command || ''",true))
	if command.is_empty():
		super._process(delta)
		return
	JavaScriptBridge.eval("window.str37Command='';",true)
	busy = true
	if command != "verify":
		controller._encounter_selector_index = 8
		controller._character_selector.pressed.emit()
		await settle(command in ["buy","prepare"])
	if not check(controller._session._playable_persistence is PlayableBrowserPersistence,"Actual disposable Web character admitted with IndexedDB/Web Lock"): busy = false; return
	if command in ["buy","prepare"]:
		var helper := preload("res://tests/test_playable_vaelis_persistence.gd").new()
		for wave in range(4):
			var session := controller._session
			session.set_opponent_behavior_enabled(false)
			helper._defeat_wave(session)
			await settle()
			if session.get_reward_state().unspent_xp >= 3000: break
			controller._encounter_button.pressed.emit()
			await settle()
		check(helper._failures.is_empty(),"Actual physical combat secures source-backed XP without injected rewards")
		if command == "prepare":
			controller._encounter_button.pressed.emit()
			await settle()
			check(controller._session._playable_persistence.recovery.phase == "entry","NEXT WAVE publishes an exact unfinished entry for page reload")
			line("READY SETUP COMPLETE: reload page, then Load READY purchase UI.")
			busy = false
			return
		controller._update_rewards_panel(true)
		var selected := -1
		for index in range(controller._advancement_options.size()):
			var option: Dictionary = controller._advancement_options[index]
			if option.purchase_kind == "attribute" and option.target_id == "str": selected = index
		if not check(selected >= 0,"STR option is available in real downtime UI"): busy = false; return
		controller._advancement_option.select(selected)
		controller._advancement_option.item_selected.emit(selected)
		var state := controller._session.get_actor_state(&"player")
		var resources := state.resources.duplicate(true)
		var hpc: Variant = state.current_hpc
		var draws := controller._session.simulation.random.get_draw_count()
		var balance: int = controller._session.get_reward_state().unspent_xp
		controller._purchase_advancement_button.pressed.emit()
		await settle()
		var original_request := String(controller._session._reward_ledger.purchase_records.back().request_id)
		JavaScriptBridge.eval("sessionStorage.setItem('str37_original_request',"+JSON.stringify(original_request)+")",true)
		check(controller._session.get_reward_state().unspent_xp == balance-3000,"UI confirmation spends exactly 3000 EXPC")
		check(state.resources == resources and state.current_hpc == hpc and controller._session.simulation.random.get_draw_count() == draws,"Purchase neither refills resources nor consumes RNG")
	if command == "ready":
		var session := controller._session
		check(session.get_encounter_state() == ArenaCombatSession.ENCOUNTER_READY,"Existing funded character reopens READY through actual playable admission")
		controller._update_rewards_panel(true)
		controller._combat_inventory_open = true
		controller._update_rewards_panel(true)
		for index in range(controller._advancement_options.size()):
			if controller._advancement_options[index].target_id == "str":
				controller._advancement_option.select(index)
				controller._advancement_option.item_selected.emit(index)
		for child: Node in controller._advancement_option.get_parent().get_children():
			if child is Button and child.text == "CHARACTER ADVANCEMENT": child.button_pressed = true
		check(not controller._purchase_advancement_button.disabled,"Actual READY confirmation button is enabled")
		ready_observation = {"balance":session.get_reward_state().unspent_xp,"resources":session.get_actor_state(&"player").resources.duplicate(true),"hpc":session.get_actor_state(&"player").current_hpc,"draws":session.simulation.random.get_draw_count()}
		line("READY UI: click the ordinary CONFIRM XP PURCHASE button, then Verify manual purchase.")
		busy = false
		return
	if command == "verify":
		await settle()
		var session := controller._session
		check(not ready_observation.is_empty() and session.get_reward_state().unspent_xp == ready_observation.balance-3000,"Manual READY UI purchase spends exactly 3000 EXPC")
		check(session.get_actor_state(&"player").resources == ready_observation.resources and session.get_actor_state(&"player").current_hpc == ready_observation.hpc and session.simulation.random.get_draw_count() == ready_observation.draws,"Manual READY purchase leaves resources and RNG unchanged")
		if not check(not session._reward_ledger.purchase_records.is_empty(),"Manual confirmation committed an authoritative purchase"): busy = false; return
		JavaScriptBridge.eval("sessionStorage.setItem('str37_original_request',"+JSON.stringify(String(session._reward_ledger.purchase_records.back().request_id))+")",true)
	var session := controller._session
	var service: PlayableBrowserPersistence = session._playable_persistence
	var stored := await read_document(service.profile_id)
	var decoded := CharacterSaveContract.decode(stored)
	if check(decoded.success,"Fresh IndexedDB readback validates original V2 document"):
		check(session.simulation.get_actor_definition(&"player").attributes.str == 10,"Purchased permanent STR is 10 after admission/reload")
		check(session.simulation.get_actor_definition(&"player").combat_stats.sb == 2,"STR 10 retains printed SB 2")
		var count := 0
		for purchase: Dictionary in decoded.payload.purchases:
			if purchase.purchase_kind == "attribute" and purchase.target_id == "str":
				count += 1
				check(purchase.value_before == 9 and purchase.value_after == 10 and purchase.cost == 3000,"Stored purchase has exact values and price")
		check(count == 1,"Reload does not duplicate purchases or spending")
		check(session.get_actor_state(&"player").resources == decoded.payload.recovery.player.resources and session.get_actor_state(&"player").current_hpc == decoded.payload.recovery.player.current_hpc,"Exact checkpoint resources retained")
	var original := str(JavaScriptBridge.eval("sessionStorage.getItem('str37_original_request') || ''",true))
	var before := session.get_state_snapshot()
	check(not original.is_empty() and session.request_character_advancement(&"attribute",&"str",original).get("reason") == "duplicate_advancement_request" and session.get_state_snapshot() == before,"Original caller request is rejected after reload without mutations")
	check(session.get_state_snapshot().schema_version == 12,"Simulation schema remains 12")
	line("37B COMPLETE: "+command+"; disposable database only.")
	busy = false
