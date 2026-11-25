extends Node
const Scene = preload("res://scenes/disposable_v3_arena.tscn")
const Codec = preload("res://scripts/rewards/minimal_character_snapshot_v3.gd")
var assertions := 0
var failures: Array[String] = []
var measures := []
var scene: Node
var controller: Node

func check(value: bool, label: String) -> void:
	assertions += 1
	if not value: failures.append(label)
	print("46K_CHECK ",assertions," ",value," ",label)

func pointer(control: Control) -> void:
	if controller != null and controller._panel != null and controller._panel.is_ancestor_of(control) and not controller._panel.visible:
		controller._combat_inventory_open=false;controller._update_rewards_panel(true)
		await pointer(controller._tools_toggle)
	await get_tree().process_frame
	await get_tree().process_frame
	check(control != null and control.is_visible_in_tree(),"Actual playable control visible: "+str(control.name if control != null else "missing"))
	if control == null: return
	var viewport := control.get_viewport()
	var position := control.get_global_transform_with_canvas()* (control.size/2)
	print("46K_POINTER ",control.name," at ",position," control ",control.get_global_rect()," view ",viewport.get_visible_rect()," disabled ",control.get("disabled"))
	var motion := InputEventMouseMotion.new(); motion.window_id=control.get_window().get_window_id(); motion.position=position; motion.global_position=position; viewport.push_input(motion,true)
	print("46K_HOVER ",viewport.gui_get_hovered_control())
	for down: bool in [true,false]:
		var event := InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.position=position; event.global_position=position; event.pressed=down
		event.window_id=control.get_window().get_window_id()
		viewport.push_input(event,true)
	await get_tree().process_frame

func wait_saved() -> void:
	var started := Time.get_ticks_usec()
	for i in range(2000):
		controller._poll_browser_persistence()
		if not controller._failed.is_empty(): check(false,"Unexpected save failure: "+controller._failed); return
		if controller._owner != null and controller._opening.is_empty() and controller._owner._minimal_owner._pending.is_empty() and controller._owner._minimal_owner._browser_phase.is_empty():
			check(controller._owner._minimal_owner._gate._attached(),"Scene player/movement remain the exact capture participants")
			measures.append({"wait_us":Time.get_ticks_usec()-started,"bytes":controller._owner.minimal_view().body_json.to_utf8_buffer().size()})
			return
		await get_tree().create_timer(0.01).timeout
	check(false,"Bounded playable save timeout")

func body() -> Dictionary:
	return JSON.parse_string(controller._owner.minimal_view().body_json)

func open_scene(mode: String, create: bool) -> void:
	scene = Scene.instantiate()
	controller = scene.get_node("CombatController"); controller.combat_seed = 1
	get_tree().root.add_child(scene)
	await get_tree().process_frame
	controller.set_physics_process(false) # deterministic test stepping only
	controller._player.set_physics_process(false)
	check(controller._enabled,"Explicit disposable scene/slot enabled")
	if mode == "dev_normal":
		# The actual OptionButton/PopupMenu signal chooses the same UI namespace.
		controller._mode_option.select(1)
		controller._mode_option.item_selected.emit(1)
		check(controller._mode == mode,"Player-facing namespace option selected")
	await pointer(controller._buttons.Create if create else controller._buttons.Load)
	await wait_saved()
	if controller._owner == null: return
	controller._player.set_physics_process(false)
	check(controller._player == controller._owner._minimal_owner._player and controller._player.is_inside_tree(),"Actual scene player is the coordinator-owned player")
	check(controller._session == controller._owner._minimal_owner._session,"One authoritative session, no parallel playable engine")
	check(controller._session.get_reward_mode()==mode,"Original reward namespace retained")

func close_scene() -> void:
	if is_instance_valid(scene): scene.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	scene=null; controller=null

func keyboard_attack() -> void:
	var viewport: Viewport = controller.get_viewport()
	var focus := viewport.gui_get_focus_owner()
	if focus != null: focus.release_focus()
	var motion := InputEventMouseMotion.new(); motion.position=Vector2(150,300); motion.global_position=motion.position; viewport.push_input(motion)
	for down: bool in [true,false]:
		var event := InputEventKey.new(); event.keycode=KEY_SPACE; event.physical_keycode=KEY_SPACE; event.pressed=down
		viewport.push_input(event,true)
	await get_tree().process_frame

func defeat_wave() -> void:
	var s: ArenaCombatSession = controller._session
	s.set_opponent_behavior_enabled(false)
	if s.get_encounter_state()==ArenaCombatSession.ENCOUNTER_READY: await pointer(controller._encounter_button)
	check(s.get_encounter_state()==ArenaCombatSession.ENCOUNTER_RUNNING,"START reaches real original combat")
	check(not controller._panel.visible,"Creation/tools panel is closed during combat")
	controller._update_combat_movement_lock()
	var original_position:Vector2=controller._player.position
	var key:=InputEventKey.new();key.physical_keycode=KEY_D;key.keycode=KEY_D;key.pressed=true
	Input.parse_input_event(key);Input.flush_buffered_events()
	controller._player._physics_process(0.1)
	key=InputEventKey.new();key.physical_keycode=KEY_D;key.keycode=KEY_D;key.pressed=false;Input.parse_input_event(key)
	check(controller._player.position!=original_position,"WASD reaches the original movement path with toolbox closed")
	check(not controller._combat_status.visible and not controller._event_log.visible,"Verbose HUD does not overlap combat")
	for id: String in s.get_targetable_enemy_ids():
		# Source-backed wounded combat fixtures isolate persistence, not balance.
		# Killing attack/ACC/defense/damage/XP still use original gameplay controls.
		s.get_actor_state(StringName(id)).current_hpc=1
		for i in range(80):
			if int(s.get_actor_state(StringName(id)).current_hpc)<=0: break
			s.simulation.apply_authoritative_spatial_position(StringName(id),s.get_actor_state(&"player").position_microfeet+Vector2i(1000000,0),0,180000)
			s.select_target(StringName(id))
			await keyboard_attack()
			controller._physics_process(5.0)
		check(int(s.get_actor_state(StringName(id)).current_hpc)<=0,"Actual keyboard attack defeats "+id)
	check(s.get_encounter_state()==ArenaCombatSession.ENCOUNTER_BETWEEN_WAVE_DOWNTIME,"Real wave completion reaches authoritative downtime")
	await wait_saved()
	controller._update_rewards_panel(true)
	await get_tree().process_frame
	await pointer(controller._collect_loot_button)
	await wait_saved()

func exercise(mode: String) -> void:
	await open_scene(mode,true)
	if controller._owner==null: return
	var initial:=body()
	check(initial.sequence==1 and initial.evidence.awards.is_empty(),"Fresh source-authorized genesis only; no historical character relabelled fresh")
	var credit: Dictionary = controller._owner.prepare_minimal_fixed_credit(func(quote):return {"confirmed":true,"binding":Codec.V6.digest(quote)})
	check(not credit.success and body()==initial,"Fresh source rejects historical-only EXPC credit without changing balances")
	await defeat_wave()
	check(body().current.xp.earned>initial.current.xp.earned,"Original committed XP/EXPM survives actual play")
	var stored:=body()
	await close_scene()
	await open_scene(mode,false)
	check(body()==stored,"Exit/load/RESUME preserves complete exact acknowledged character")
	check(controller._session.get_encounter_state()==ArenaCombatSession.ENCOUNTER_BETWEEN_WAVE_DOWNTIME,"Resumed checkpoint remains genuine downtime")
	# Real equipment buttons dispatch original issued handles, not raw request IDs.
	controller._combat_inventory_open=true; controller._update_rewards_panel(true)
	for button: Button in controller._rewards_panel.find_children("*","Button",true,false):
		if button.text=="INVENTORY / EQUIPMENT" and not button.button_pressed:await pointer(button)
	for i in range(controller._inventory_entries.size()):
		if controller._inventory_entries[i].get("definition_id")=="prime_v3_short_wand": controller._inventory_option.select(i)
	controller._on_inventory_option_selected(controller._inventory_option.selected)
	await get_tree().process_frame
	await pointer(controller._inventory_equip_button); await wait_saved()
	check(not controller._session.get_actor_state(&"player").equipment_refs.has("prime_v3_short_wand"),"UNEQUIP button uses original issued command")
	await pointer(controller._inventory_equip_button); await wait_saved()
	check(controller._session.get_actor_state(&"player").equipment_refs.has("prime_v3_short_wand"),"EQUIP button uses original issued command")
	await pointer(controller._weapon_handling_buttons.stow);await wait_saved()
	check(controller._session.get_actor_state(&"player").hand_occupancy.left=="","Actual STOW button frees the source-required potion hand")
	# Acquire a verified source fixture consumable through original world loot.
	var s: ArenaCombatSession=controller._session
	var cause:=s.simulation.record_reward_event(&"reward_source_fixture",&"player",&"player",{})
	s.simulation.create_ground_loot_item("46k_potion",{"definition_id":"health_potion","quantity":1,"display_name":"Health Potion","item_kind":"potion","source_ref":"Prime V3 p.120; disposable original fixture"},s.get_actor_state(&"player").position_microfeet,&"player",cause.event_id)
	controller._refresh_world_item_markers();controller._update_rewards_panel(true)
	await pointer(controller._collect_loot_button);await wait_saved()
	controller._update_rewards_panel(true)
	for i in range(controller._inventory_entries.size()):
		if controller._inventory_entries[i].get("definition_id")=="health_potion":controller._inventory_option.select(i)
	controller._on_inventory_option_selected(controller._inventory_option.selected)
	s.get_actor_state(&"player").current_hpc=1
	controller._update_rewards_panel(true)
	await pointer(controller._inventory_use_button);await wait_saved()
	check(body().evidence.item_debits.size()==1 and body().current.items.any(func(item):return item.definition_id=="health_potion" and item.quantity==0),"USE button preserves irreversible ID and terminal zero ownership")
	# A changed legal safe checkpoint, injected failed publication and exact retry.
	s.configure_player_nac_automation({"profile":"Defensive"})
	if OS.has_feature("web"):controller._route._bridge.fault(controller._route._handle,"abort_after_put")
	else:controller._owner._minimal_owner._windows_route.fault="disk_full_current.pending"
	await pointer(controller._buttons.Save)
	for i in range(2000):
		controller._poll_browser_persistence()
		if not controller._failed.is_empty():break
		await get_tree().create_timer(0.01).timeout
	check(not controller._failed.is_empty() and "NOT SAVED" in controller._status.text,"Failed save is explicit and never displayed as successful")
	var pending:String=controller._owner.minimal_view().pending_text
	check(not pending.is_empty(),"Failed save retains the exact owned pending candidate")
	if OS.has_feature("web"):controller._route._bridge.fault(controller._route._handle,"")
	else:controller._owner._minimal_owner._windows_route.fault=""
	await pointer(controller._buttons.Retry);await wait_saved()
	check(controller._owner.minimal_view().pending_text.is_empty(),"RETRY acknowledges the original pending operation")
	var before:=body()
	controller._combat_inventory_open=false;controller._update_rewards_panel(true)
	await pointer(controller._encounter_button);await wait_saved()
	check(controller._session.get_reward_state().current_wave_id=="wave_2","NEXT WAVE remains on admitted profile")
	await defeat_wave()
	if mode=="dev_normal":
		for wave in [3,4]:
			controller._combat_inventory_open=false;controller._update_rewards_panel(true)
			await pointer(controller._encounter_button);await wait_saved();await defeat_wave()
		for button: Button in controller._rewards_panel.find_children("*","Button",true,false):
			if button.text=="CHARACTER ADVANCEMENT" and not button.button_pressed:await pointer(button)
		for i in range(controller._advancement_options.size()):
			if controller._advancement_options[i].get("target_id")=="end":controller._advancement_option.select(i);break
		controller._on_advancement_option_selected(controller._advancement_option.selected)
		await get_tree().process_frame
		var exp_before: Dictionary = body().current.xp
		if not controller._purchase_advancement_button.disabled:
			await pointer(controller._purchase_advancement_button);await wait_saved()
			check(body().evidence.purchases.any(func(p):return p.target_id=="end") and body().current.xp.earned==exp_before.earned,"Actual advancement button permanently spends only EXPC")
		else:
			print("46K_ADVANCEMENT ",JSON.stringify(controller._advancement_options)," SELECT ",controller._advancement_option.selected," REWARDS ",JSON.stringify(body().current.xp)," ELIGIBLE ",controller._session.get_character_advancement_eligibility())
			check(false,"DEV source awards must afford focused END purchase")
	stored=body()
	await pointer(controller._buttons.NewRun)
	await get_tree().process_frame
	check(controller._new_dialog.visible,"NEW RUN requires explicit abandonment confirmation")
	var confirm: Button=controller._new_dialog.get_ok_button()
	confirm.grab_focus()
	for down: bool in [true,false]:
		var key:=InputEventKey.new();key.window_id=confirm.get_window().get_window_id();key.keycode=KEY_ENTER;key.physical_keycode=KEY_ENTER;key.pressed=down
		confirm.get_viewport().push_input(key,true)
	await get_tree().process_frame
	await wait_saved()
	controller._player.set_physics_process(false)
	check(body().epoch==stored.epoch and body().current.run_history.size()==stored.current.run_history.size()+1 and body().evidence==stored.evidence,"Confirmed NEW RUN retains permanent character and all committed facts")
	check(controller._session.get_run_reward_policy().xp_multiplier==1,"Original NEW RUN ×1 selection is locked")
	check(controller._owner._minimal_owner._gate._attached(),"NEW RUN binds a fresh real scene player without reopening retired contexts")
	stored=body();await close_scene();await open_scene(mode,false)
	check(body()==stored,"NEW RUN and permanent advancement survive exit/load")
	await close_scene()

func run() -> Dictionary:
	for mode: String in ["normal","dev_normal"]:
		await exercise(mode)
		if not failures.is_empty(): break
	if failures.is_empty():
		await open_scene("normal",false)
		await pointer(controller._encounter_button)
		await get_tree().process_frame
		var screen:=Rect2(Vector2.ZERO,get_viewport().get_visible_rect().size)
		check(screen.encloses(controller._tools_toggle.get_global_rect()) and screen.encloses(controller._status.get_global_rect()),"Footer controls/status inside actual viewport")
		check(not controller._tools_toggle.get_global_rect().intersects(controller._status.get_global_rect()),"Status does not overlap toggle")
		check(controller._status.mouse_filter==Control.MOUSE_FILTER_IGNORE and not controller._panel.visible,"Closed toolbox and passive status cannot intercept combat mouse input")
		var menu:Button=controller._character_selector.get_parent().get_node("CombatInventory")
		await pointer(menu)
		check(controller._rewards_panel.visible,"Actual CHARACTER MENU opens inventory")
		await pointer(controller._tools_toggle)
		check(controller._panel.visible and not controller._rewards_panel.visible,"Tools and inventory do not overlap")
		await pointer(controller._tools_toggle)
		check(not controller._panel.visible and get_viewport().gui_get_focus_owner()==null,"Closing toolbox releases focus for WASD")
		if not OS.has_feature("web") and DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0]+".png")
	return {"success":failures.is_empty(),"assertions":assertions,"failures":failures,"measures":measures,"scope":"real Godot playable controls; disposable wounded source combat fixtures"}
