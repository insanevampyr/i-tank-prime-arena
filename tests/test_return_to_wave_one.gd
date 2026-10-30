extends RefCounted

const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
const PlayableTests = preload("res://tests/test_playable_vaelis_persistence.gd")
const NextWaveTests = preload("res://tests/test_persistence_next_wave_fix.gd")
var _failures: Array[String] = []

func run() -> Array[String]:
	var root := OS.get_cache_dir().path_join("itank-storage-tests").path_join("playable_return_%s_%s" % [OS.get_process_id(),Time.get_ticks_usec()])
	var storage := NextWaveTests.FaultStorage.new(root)
	PlayableCharacterPersistence.test_nonpersistent = false
	PlayableCharacterPersistence.test_storage = storage
	_exercise(storage,"dev_normal",2,root)
	var dev: Dictionary = storage.read_profile("dev_vaelis_thorn").payload.duplicate(true)
	_exercise(storage,"normal",1,root)
	_expect(storage.read_profile("dev_vaelis_thorn").payload == dev,"Production returns cannot change the developer profile.")
	_unresolved_condition(root.path_join("unresolved"))
	PlayableCharacterPersistence.test_storage = storage
	_nonpersistent_isolation(storage)
	PlayableCharacterPersistence.test_nonpersistent = true
	PlayableCharacterPersistence.test_storage = null
	PlayableCharacterPersistence.test_run_id = ""
	assert(root.begins_with(OS.get_cache_dir().path_join("itank-storage-tests")+"/playable_return_"))
	PlayableTests.new()._remove_fixture(root)
	return _failures

func _scene(mode: String) -> Node:
	var scene := PlayableTests.new()._scene()
	var controller: ArenaCombatController = scene.get_node("CombatController")
	controller.combat_seed = 7
	controller._encounter_selector_index = 8 if mode == "dev_normal" else 0
	var selected := controller.select_player_character_for_testing(Fixture.PLAYER_CHARACTER_VAELIS)
	_expect(selected.get("success",false),"Vaelis must load through playable %s selection: %s" % [mode,selected])
	return scene

func _exercise(storage: CharacterSaveStorage, mode: String, runs: int, root: String) -> void:
	PlayableCharacterPersistence.test_run_id = "run_%s_initial" % mode
	var scene := _scene(mode)
	var controller: ArenaCombatController = scene.get_node("CombatController")
	var profile_id := "dev_vaelis_thorn" if mode == "dev_normal" else "prod_vaelis_thorn"
	for index in range(runs):
		var session := controller.get_combat_session_for_testing()
		session.set_opponent_behavior_enabled(false)
		_expect(not controller._return_wave_one_button.visible,"RETURN is unavailable while the player is not defeated.")
		controller._encounter_button.pressed.emit()
		if mode == "dev_normal" and index == 0:
			# Real ordinary casts establish the owner's persistent combat-effect
			# entry state; no ability or shield is fabricated for the character.
			for attempt in range(5):
				if session.get_actor_state(&"player").persistent_damage_shields.has("force_shield"): break
				var cast := session.request_player_special(VaelisForceFixture.FORCE_SHIELD_ID)
				if not cast.get("success",false): break
				session.advance_by(5000000)
			_expect(session.get_actor_state(&"player").persistent_damage_shields.has("force_shield"),"Combat-effect fixture must complete an actual Force Shield cast.")
		for wave in range(1,3):
			_defeat_wave(session)
			controller._on_collect_loot_pressed()
			if wave == 2 and session.get_reward_state().unspent_xp >= 2000 and session._playable_persistence._prior.purchases.is_empty():
				var purchase := session.request_character_advancement(&"special_resistance",&"sr","return_purchase")
				_expect(purchase.get("success",false) and purchase.get("persistence",{}).get("success",false),"A source-priced SR purchase must secure through the actual session.")
			if wave == 2:
				# Exact spent-resource entry fixture; no XP/item history is fabricated.
				var player := session.get_actor_state(&"player")
				player.current_hpc = 2
				player.resources.mana = 3
				player.resources.blood = 4
				if mode == "dev_normal" and index == 0:
					session.simulation.set_actor_defense_state(&"player",&"aware",PackedStringArray(["prone"]))
					controller._update_combat_movement_lock()
				_expect(session._checkpoint_character("character_changed").get("success",false),"The depleted Wave-2 downtime must save legally.")
			controller._encounter_button.pressed.emit()
			_expect(session._current_reward_wave_id() == "wave_%s" % (wave+1),"The actual NEXT WAVE button must reach the intended wave.")
		var secured: Dictionary = storage.read_profile(profile_id).payload.duplicate(true)
		_expect(secured.recovery.wave_id == "wave_3" and secured.recovery.phase == "entry","Return fixture must use the verified Wave-3 entry.")
		if mode == "dev_normal" and index == 1: _expect(not secured.purchases.is_empty(),"Repeated legitimate runs must provide a meaningful purchased-stat retention case.")
		# A genuine in-wave kill creates unsecured XP/loot which must be discarded.
		var target := StringName(session.get_targetable_enemy_ids()[0])
		if session.is_actor_prone(&"player"):
			_expect(session.request_player_stand("return_fixture_stand").get("success",false),"The prone source fixture must legally spend its standing Act before attacking.")
			session.advance_by(5000000)
		_defeat_actor(session,target)
		_expect(session.get_reward_state().earned_xp > secured.permanent.xp_baseline.earned,"Failed-wave fixture must contain genuinely unsecured earned XP.")
		_defeat_player(controller)
		_expect(controller._encounter_button.text == "RETRY WAVE" and controller._return_wave_one_button.visible,"Persistent defeat must offer both RETRY and RETURN.")
		_check_layout(controller)
		if index == 0:
			controller._encounter_button.pressed.emit()
			session = controller.get_combat_session_for_testing()
			var retried := session.get_actor_state(&"player")
			_expect(session._current_reward_wave_id() == "wave_3" and retried.current_hpc == 2 and retried.resources == secured.recovery.player.resources,"RETRY WAVE remains exact entry recovery without refills.")
			_expect(retried.persistent_damage_shields == secured.recovery.player.persistent_damage_shields,"RETRY must retain exact entry protection; NEW RUN cleanup cannot affect it.")
			_expect(Array(retried.conditions) == secured.recovery.player.conditions,"RETRY retains entry posture; it must not apply NEW RUN condition cleanup.")
			_expect(storage.read_profile(profile_id).payload == secured,"RETRY does not publish a new run or replay rewards.")
			controller._encounter_button.pressed.emit()
			_defeat_player(controller)
			session = controller.get_combat_session_for_testing()
		if mode == "dev_normal" and index == 0:
			controller._developer_test_mode = true
			controller._return_wave_one_button.pressed.emit()
			_expect(controller.get_combat_session_for_testing() == session,"A persistent defeat cannot silently fall through into a nonpersistent TEST initializer.")
			controller._developer_test_mode = false
			controller._encounter_selector_index = 0
			controller._return_wave_one_button.pressed.emit()
			_expect(controller.get_combat_session_for_testing() == session and not storage.read_profile("prod_vaelis_thorn").get("success",false),"A DEV defeat authorization cannot initialize or replace a production profile.")
			controller._encounter_selector_index = 8
			storage.reject_writes = true
			PlayableCharacterPersistence.test_run_id = "run_failed_return"
			var failed_state := session.get_state_snapshot()
			controller._return_wave_one_button.pressed.emit()
			_expect(controller.get_combat_session_for_testing() == session and session.get_state_snapshot() == failed_state and session.get_encounter_state() == ArenaCombatSession.ENCOUNTER_PLAYER_DEFEAT,"Failed publication leaves the defeated session intact.")
			controller.update_presentation_for_testing()
			_expect(controller.get_last_ui_message_for_testing().contains("fixture write denied") and controller._return_wave_one_button.visible,"A failed return must retain an actionable defeat screen and the real failure reason.")
			_expect(storage.read_profile(profile_id).payload == secured,"A rejected return cannot replace the last verified generation.")
			storage.reject_writes = false
		PlayableCharacterPersistence.test_run_id = "run_%s_return_%s" % [mode,index+1]
		controller._return_wave_one_button.pressed.emit()
		var returned := controller.get_combat_session_for_testing()
		_expect(returned != session and returned._current_reward_wave_id() == "wave_1" and returned.get_encounter_state() == ArenaCombatSession.ENCOUNTER_READY,"RETURN must create a fresh ready Wave 1 through the real button.")
		if returned == session:
			PlayableTests.new()._free(scene)
			return
		var saved: Dictionary = storage.read_profile(profile_id).payload
		_expect(returned._seed_value == String(secured.recovery.seed).to_int(),"A fresh circuit retains the selected authoritative seed, including after reload.")
		_expect(saved.generation == secured.generation+1 and saved.recovery.phase == "entry" and saved.recovery.wave_id == "wave_1","A verified new Wave-1 entry must publish before replacement is accepted.")
		for field: String in ["xp","purchases","items","permanent","settlements"]: _expect(saved[field] == secured[field],"RETURN must preserve secured %s exactly, excluding failed-wave changes." % field)
		_expect(saved.run_history.size() == secured.run_history.size()+1 and saved.run_history.back() == PlayableCharacterPersistence.test_run_id,"Each legitimate return has one fresh authorized run identity.")
		var player := returned.get_actor_state(&"player")
		_expect(player.current_hpc == returned.get_actor_max_hpm(&"player") and player.resources == returned.simulation.get_actor_definition(&"player").resource_maxima and player.ability_daily_remaining == player.ability_daily_maxima,"Existing NEW RUN maxima/daily restoration applies exactly once.")
		_expect(player.persistent_damage_shields.is_empty() and player.timed_stat_effects.is_empty() and player.conditions.is_empty(),"A fresh run must not retain old run-only combat effects.")
		for id: String in returned.get_targetable_enemy_ids(): _expect(returned.get_actor_state(StringName(id)).current_hpc == returned.get_actor_max_hpm(StringName(id)) and not returned.simulation.is_actor_retired(StringName(id)),"Wave-1 arrivals must be fresh source combatants.")
		var snapshot := returned.simulation.get_state_snapshot()
		var harness := TwoClientSyncHarness.new(7)
		harness.authority.simulation = returned.simulation
		harness.deliver_in_order(harness.authority.publish_current_events())
		_expect(snapshot.schema_version == 12 and harness.compare_clients().success and harness.client_a.get_state_snapshot() == snapshot,"New-run state must retain schema-12 convergence.")
		var generation: int = saved.generation
		controller._return_wave_one_button.pressed.emit()
		_expect(returned.simulation.get_state_snapshot() == snapshot and storage.read_profile(profile_id).payload.generation == generation,"A duplicate/hidden RETURN request cannot restore twice or publish another generation.")
		PlayableTests.new()._free(scene)
		scene = _scene(mode)
		controller = scene.get_node("CombatController")
		var reopened := controller.get_combat_session_for_testing()
		_expect(reopened._playable_persistence.items == saved.items and reopened.get_actor_state(&"player").current_hpc == player.current_hpc and reopened.get_actor_state(&"player").resources == player.resources,"Exit/reload must restore the newly secured character and entry.")
		for field: String in CharacterWaveCheckpoint.PLAYER_FIELDS:
			var actual: Variant = reopened.get_actor_state(&"player").get(field)
			if actual is PackedStringArray: actual = Array(actual)
			_expect(actual == saved.recovery.player[field],"Cold return entry must restore exact %s." % field)
		# New-run initialization emits default-NAC configuration; reload emits
		# recovery markers instead. Their revision/event counters are intentionally
		# different. Compare two complete reloads, without stripping any fields.
		var cold_snapshot := reopened.simulation.get_state_snapshot()
		PlayableTests.new()._free(scene)
		scene = _scene(mode)
		controller = scene.get_node("CombatController")
		_expect(controller.get_combat_session_for_testing().simulation.get_state_snapshot() == cold_snapshot,"Same-seed cold-entry replay must reproduce every authoritative snapshot field.")
		if index > 0:
			var new_run_receipts := 0
			for receipt: Dictionary in saved.settlements:
				if receipt.kind == "xp" and receipt.run_id == secured.run_history.back(): new_run_receipts += 1
			_expect(new_run_receipts > 0,"Repeated runs must secure fresh XP under their original distinct run identities.")
	PlayableTests.new()._free(scene)

func _defeat_wave(session: ArenaCombatSession) -> void:
	for id: String in session.get_targetable_enemy_ids(): _defeat_actor(session,StringName(id))
	_expect(session.get_encounter_state() == ArenaCombatSession.ENCOUNTER_BETWEEN_WAVE_DOWNTIME,"Source physical kills must produce real victory/downtime.")

func _defeat_actor(session: ArenaCombatSession, id: StringName) -> void:
	var helper := NextWaveTests.new()
	helper._defeat_actor(session,id)
	_expect(helper._failures.is_empty(),"Wounded source-combatant defeat fixture must resolve legally.")

func _defeat_player(controller: ArenaCombatController) -> void:
	var session := controller.get_combat_session_for_testing()
	session.get_actor_state(&"player").current_hpc = 0
	session.advance_by(1)
	controller.update_presentation_for_testing()

func _check_layout(controller: ArenaCombatController) -> void:
	var layout: ArenaResponsiveLayout = controller.get_parent()
	layout._apply_layout(Vector2(1152,648),Vector2(1152,648))
	_expect(not controller._return_wave_one_button.get_rect().intersects(controller._encounter_button.get_rect()) and controller._return_wave_one_button.get_rect().end.x <= 1152,"RETURN and RETRY must fit as distinct adjacent toolbar controls.")

func _nonpersistent_isolation(storage: CharacterSaveStorage) -> void:
	var saved: Dictionary = storage.read_profile("prod_vaelis_thorn").payload.duplicate(true)
	var scene := PlayableTests.new()._scene()
	var controller: ArenaCombatController = scene.get_node("CombatController")
	_expect(not controller._return_wave_one_button.visible,"Guard must not offer a persistent return.")
	controller._return_wave_one_button.pressed.emit()
	controller._developer_test_mode = true
	controller.select_player_character_for_testing(Fixture.PLAYER_CHARACTER_VAELIS)
	controller._encounter_button.pressed.emit()
	_defeat_player(controller)
	_expect(not controller._return_wave_one_button.visible and controller.get_combat_session_for_testing()._playable_persistence == null,"TEST must keep nonpersistent defeat handling.")
	controller._return_wave_one_button.pressed.emit()
	_expect(storage.read_profile("prod_vaelis_thorn").payload == saved,"TEST/Guard RETURN requests cannot alter production saves.")
	PlayableTests.new()._free(scene)

func _unresolved_condition(root: String) -> void:
	var storage := CharacterSaveStorage.new(root)
	PlayableCharacterPersistence.test_storage = storage
	PlayableCharacterPersistence.test_run_id = "run_unresolved_condition"
	var scene := _scene("normal")
	var controller: ArenaCombatController = scene.get_node("CombatController")
	var session := controller.get_combat_session_for_testing()
	session.set_opponent_behavior_enabled(false)
	controller._encounter_button.pressed.emit()
	for wave in range(1,3):
		_defeat_wave(session)
		if wave == 2:
			# An intentionally UNSOURCED persistent-condition sentinel must never
			# be interpreted as a curable injury or discarded as a combat posture.
			session.simulation.set_actor_defense_state(&"player",&"aware",PackedStringArray(["permanent_injury_unverified"]))
		controller._encounter_button.pressed.emit()
	var saved: Dictionary = storage.read_profile("prod_vaelis_thorn").payload.duplicate(true)
	_defeat_player(controller)
	var before := session.get_state_snapshot()
	controller._return_wave_one_button.pressed.emit()
	controller.update_presentation_for_testing()
	_expect(controller.get_combat_session_for_testing() == session and session.get_state_snapshot() == before,"Unresolved injury policy must preserve the defeated session atomically.")
	_expect(controller.get_last_ui_message_for_testing().contains("permanent injury unverified"),"A blocked permanent condition must be identified precisely.")
	_expect(storage.read_profile("prod_vaelis_thorn").payload == saved,"Blocked injury policy cannot replace the previous generation.")
	controller._encounter_button.pressed.emit()
	_expect(controller.get_combat_session_for_testing().get_actor_state(&"player").conditions.has("permanent_injury_unverified"),"RETRY must preserve unresolved entry conditions rather than cure them.")
	PlayableTests.new()._free(scene)

func _expect(value: bool, message: String) -> void:
	if not value: _failures.append(message)

