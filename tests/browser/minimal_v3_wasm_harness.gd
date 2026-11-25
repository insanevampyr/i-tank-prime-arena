extends Node
const V3 = preload("res://scripts/rewards/minimal_character_snapshot_v3.gd")
const Store = preload("res://scripts/rewards/minimal_v3_browser_storage.gd")
const H = preload("res://tests/test_minimal_v3_transactions.gd")
var callback: JavaScriptObject
var contexts := {}
var serial := 0
func _ready() -> void:
	callback = JavaScriptBridge.create_callback(_request)
	JavaScriptBridge.get_interface("window").arena46jNative = callback
	JavaScriptBridge.eval("window.arena46j={next:0,results:{},call(value){const id=++this.next;return new Promise(resolve=>{this.results[id]=resolve;window.arena46jNative(JSON.stringify({id,value}));});}};window.arena46jReady=true;",true)
func _request(values: Array) -> void:
	if values.size()!=1: return
	var input: Dictionary = V3.Contract._normalize_json_numbers(JSON.parse_string(str(values[0])))
	var r := command(input.value)
	JavaScriptBridge.eval("{const id="+str(int(input.id))+";const f=window.arena46j.results[id];delete window.arena46j.results[id];f("+JSON.stringify(r,"",true,true)+");}",true)
func command(a: Dictionary) -> Dictionary:
	if a.op == "create":
		var outer: Dictionary = JSON.parse_string(a.text); var body: Dictionary = JSON.parse_string(outer.body_json)
		var scope: String = body.current.profile_namespace; var profile: String = body.current.character_id
		var source: CombatCharacterDefinitionResource = PlayableCharacterAdmission.prepare_starter(&"vaelis_thorn",scope,body.current.lineage.baseline_digest).source
		var c := CharacterPersistenceCoordinator.new(null)
		var path := OS.get_cache_dir().path_join("itank-storage-tests/minimal46c2_46j_%d_%d" % [Time.get_ticks_usec(),serial])
		var start := Time.get_ticks_usec(); var admitted := c.admit_minimal_snapshot_v3(a.text,source,profile,scope,path)
		if not admitted.success: return admitted
		serial+=1;var id: String = "context_"+str(serial)
		var route := Store.new(a.database,source,profile,scope)
		contexts[id]={"c":c,"route":route,"text":a.text,"admission_us":Time.get_ticks_usec()-start}
		return {"success":route.valid(),"context":id,"handle":route._handle,"admission_us":contexts[id].admission_us}
	if not contexts.has(a.get("context","")): return {"success":false,"reason":"context_missing"}
	var ctx: Dictionary = contexts[a.context]; var route: RefCounted = ctx.route; var c: CharacterPersistenceCoordinator = ctx.c
	match a.op:
		"reader_begin": return route.begin_load(a.get("repair",false))
		"reader_poll":
			var r: Dictionary = route.poll_load()
			if r.get("state") == "pending": return r
			if r.success and not r.get("empty",false): return {"success":true,"head":r.head_text,"text":r.text,"cold_validate_us":r.cold_validate_us,"repair_current":r.repair_current,"repair_replica":r.repair_replica}
			return r
		"transport": return route.begin(a.kind,a.get("arguments",{}))
		"transport_poll": return route.poll(a.job)
		"attach": return c.attach_minimal_browser(route)
		"reload_admit":
			var loaded: Dictionary = route._loaded
			if not loaded.get("success",false) or loaded.get("empty",true): return {"success":false,"reason":"existing_verified_browser_profile_required"}
			c.close_minimal_prototype()
			var next := CharacterPersistenceCoordinator.new(null)
			var own_path := OS.get_cache_dir().path_join("itank-storage-tests/minimal46c2_46j_cold_%d" % Time.get_ticks_usec())
			var admitted := next.admit_minimal_snapshot_v3(loaded.text,route.source,route.profile,route.scope,own_path)
			if not admitted.success: return admitted
			ctx.c = next; ctx.text = ""
			return next.attach_minimal_browser(route)
		"begin": return c.begin_minimal_browser()
		"poll": return c.poll_minimal_browser()
		"cancel": return c.cancel_minimal_browser()
		"automatic": return c.automatic_minimal_browser(a.enabled)
		"fault": route._bridge.fault(route._handle,a.value); return {"success":true}
		"resume_barrier": route._bridge.resume(route._handle); return {"success":true}
		"command":
			var owner: RefCounted = c._minimal_owner; var s: ArenaCombatSession = owner._session
			var result := {}
			match a.kind:
				"defeat": H.P.new()._defeat_wave(s); result = {"success":true}
				"loot": result = s.collect_all_ground_loot()
				"next": result = c.next_minimal_browser_wave()
				"new_run":
					PlayableCharacterPersistence.test_run_id = ""
					result = c.prepare_minimal_new_run(a.multiplier,func(q): return {"confirmed":true,"binding":V3.V6.digest(q)})
				"credit": result = c.prepare_minimal_fixed_credit(func(q): return {"confirmed":true,"binding":V3.V6.digest(q)})
				"purchase": result = s.request_character_advancement(&"attribute",StringName(a.attribute),a.id,a.details)
				"preferences": result = s.request_character_development("preferences",a.details,a.id)
				"nac":
					result = s.configure_player_nac_automation(a.details)
					if result.success: result["checkpoint"] = owner._service.checkpoint(s,JSON.parse_string(c.minimal_view().body_json).current.recovery.phase)
				"running": result = owner._player._movement.request_running(); owner._player._movement.advance(100000,Vector2.ZERO)
				"acquire":
					var e := s.simulation.record_reward_event(&"reward_source_fixture",&"player",&"player",{})
					s.simulation.create_ground_loot_item("46j_potion",{"definition_id":"health_potion","quantity":1,"display_name":"Health Potion","item_kind":"potion","source_ref":"Prime V3 p.120; disposable original fixture"},s.get_actor_state(&"player").position_microfeet,&"player",e.event_id)
					result = s.collect_all_ground_loot()
				"item":
					if a.kind_item == "use" and a.get("fixture_damage",false): s.get_actor_state(&"player").current_hpc = 1
					var issued := c.issue_temporary_request(c.temporary_context(),a.kind_item,a.definition,a.get("handling",""),a.id)
					result = c.execute_temporary_request(issued.request) if issued.success else issued
			return {"success":result.get("success",false),"state":result.get("state",""),"reason":result.get("reason",""),"original":result,"phase":owner._browser_phase,"pending":not c.minimal_view().pending_text.is_empty()}
		"summary":
			var b: Dictionary = JSON.parse_string(c.minimal_view().body_json)
			return {"success":true,"body":b,"simulation":c._minimal_owner._session.get_state_snapshot(),"encounter_state":c._minimal_owner._session.get_encounter_state(),"movement":c._minimal_owner._player.capture_wave_entry_motion(),"live_xp":c._minimal_owner._session.get_actor_state(&"player").progression,"pending":c.minimal_view().pending_text,"phase":c._minimal_owner._browser_phase,"admission_us":ctx.admission_us}
		"phase": return {"phase":c._minimal_owner._browser_phase,"native_bytes":c.minimal_view().pending_text.to_utf8_buffer().size(),"jobs":route._job}
		"close":
			c.close_minimal_prototype()
			if c._minimal_owner != null: return {"success":false,"reason":"pending_owner_requires_reconciliation"}
			route.close(); contexts.erase(a.context); return {"success":true}
	return {"success":false,"reason":"unknown_command"}
