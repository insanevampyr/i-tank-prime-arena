extends "res://tests/browser/compact_v6_wasm_harness.gd"
const Host = preload("res://tests/compact_v6_browser_host.gd")
const BrowserRoute = preload("res://scripts/rewards/compact_v6_browser_storage.gd")
const Async = preload("res://scripts/rewards/compact_v6_browser_coordinator.gd")
var contexts := {}
var serial := 0
func _request(values: Array) -> void:
	if values.size() != 1 or not values[0] is String: return
	var job: Dictionary = JSON.parse_string(values[0])
	var a: Dictionary = CharacterSaveContract._normalize_json_numbers(job.value)
	if not str(a.get("kind","")).begins_with("browser_"): super._request(values); return
	var result := _browser(a)
	_respond(job.id,result)
func _browser(a: Dictionary) -> Dictionary:
	if a.kind == "browser_create":
		var mode: String = a.get("mode","dev_normal")
		var starter := PlayableCharacterAdmission.prepare_starter(&"vaelis_thorn",mode,a.get("baseline",Credit.BASELINE if mode == "dev_normal" else ""))
		if not starter.success: return starter
		serial += 1; var id := "context_%d" % serial
		var route := BrowserRoute.new(a.database,starter.source,starter.profile_id,mode)
		if not route.valid_context(): return {"success":false,"reason":"invalid_context"}
		contexts[id] = {"route":route,"host":Host.new(),"coordinator":null,"fixture":{}}
		return {"success":true,"context":id}
	if a.kind == "browser_preview":
		var mode: String = a.get("mode","dev_normal")
		var trusted := PlayableCharacterAdmission.prepare_starter(&"vaelis_thorn",mode,a.get("baseline",Credit.BASELINE if mode == "dev_normal" else ""))
		var t := Time.get_ticks_usec(); var decoded := Portable.decode(a.portable,trusted.source)
		return {"success":true,"preview":decoded.preview,"preview_ms":float(Time.get_ticks_usec()-t)/1000.0} if decoded.success else decoded
	if not contexts.has(a.get("context")): return {"success":false,"reason":"unknown_context"}
	var c: Dictionary = contexts[a.context]; var route: RefCounted = c.route
	match a.kind:
		"browser_transport": return route.begin(a.operation,a.get("arguments",{}))
		"browser_transport_poll": return route.poll(a.job)
		"browser_load":
			c.coordinator = Async.new(); return c.coordinator.begin_load(route,a.get("repair",false))
		"browser_activation":
			c.coordinator = Async.new(); return c.coordinator.begin_activation(route,func(q): return {"confirmed":a.get("confirmed",false),"binding":V6.digest(q)})
		"browser_restore":
			c.coordinator = Async.new(); return c.coordinator.begin_restore(route,a.portable,a.get("expected"),func(q): return {"confirmed":a.get("confirmed",false),"binding":q.binding})
		"browser_poll":
			var result: Dictionary = c.coordinator.poll_compact()
			if result.get("state") != "pending" and result.get("success",false): return {"success":true,"state":"verified_committed","result":_summary(route),"ack":result if not result.has("record") else {}}
			return result
		"browser_start":
			c.fixture = c.host.start_browser(route,a.get("multiplier"))
			return {"success":c.fixture.get("success",false),"pending":c.fixture.get("pending",false),"reason":c.fixture.get("reason","")}
		"browser_flush":
			if c.fixture.is_empty(): return {"success":false,"reason":"fixture_missing"}
			var result: Dictionary = c.fixture.service.poll_publication()
			if result.get("state") != "pending" and result.get("success",false):
				if c.get("grant",false):
					var applied: Dictionary = c.host.apply_grant_runtime(c.fixture,result)
					if not applied.success: return applied
					c.grant = false
				return {"success":true,"state":"verified_committed","result":_summary(route),"ack":result}
			return result
		"browser_command":
			var f: Dictionary = c.fixture
			if f.is_empty() or f.service.pending: return {"success":false,"reason":"operation_in_flight_or_no_session"}
			var result := {}
			match a.command:
				"defeat": c.host.Historical.new().helper._defeat_wave(f.session); result = {"success":true}
				"next": result = f.session.request_next_wave()
				"loot": result = f.session.collect_all_ground_loot()
				"development": result = f.session.request_character_development("preferences",{"order":["nac","block","dodge","soak"]},a.id)
				"purchase": result = f.session.request_character_advancement(&"attribute",StringName(a.attribute),a.id,a.details)
				"credit": result = c.host.grant_browser(f); c.grant = f.service.pending
				"inventory":
					var state: CombatActorState = f.session.get_actor_state(&"player")
					var e: CombatEvent = f.session.simulation.record_reward_event(&"reward_source_item_fixture",&"player",&"player",{})
					for i in range(a.get("count",1000)):
						var created: Dictionary = f.session.simulation.create_ground_loot_item("45t_currency_%d" % i,{"definition_id":"prime_v3_gold","quantity":1,"display_name":"Gold","item_kind":"currency","source_ref":"PRIME-V3 currency; disposable source-origin fixture"},state.position_microfeet,&"player",e.event_id)
						if not created.success: return {"success":false,"reason":"isolated_inventory_setup:"+str(created),"index":i,"geometry_installed":f.session.simulation._world_item_landing_resolver.is_valid(),"position":state.position_microfeet}
					result = f.session.collect_all_ground_loot()
			if f.service.pending: f.service.coordinator.fault = a.get("fault","")
			return {"success":result.get("success",false),"pending":f.service.pending,"reason":result.get("reason",""),"original":result}
		"browser_routine_probe":
			return load("res://tests/compact_v6_routine_probe.gd").new().measure(c.fixture.service.observer,c.fixture.service.last_prepared,a.get("samples",3))
		"browser_phase":
			return {"success":true,"phase":c.fixture.service.coordinator.phase,"target":c.fixture.service.coordinator.target,"acknowledged_generation":c.fixture.service.generation}
		"browser_cancel": return c.fixture.service.coordinator.cancel_before_publication()
		"browser_retry":
			var service: Host.Service = c.fixture.service
			service.coordinator = Async.new()
			var r: Dictionary = service.coordinator.begin_compact(route,service.observer,service.last_prepared,route.token(route.load_current()))
			service.pending = r.get("state") == "pending"
			return r
		"browser_summary": return _summary(route)
		"browser_export":
			var loaded: Dictionary = route.load_current()
			if not loaded.success or not route.readback_verified(): return {"success":false,"reason":"fresh_readback_required"}
			var t := Time.get_ticks_usec(); var file := Portable.export_record(loaded.text,loaded.history,route.source)
			return {"success":true,"portable":file.text,"bytes":file.text.to_utf8_buffer().size(),"sha256":file.text.sha256_text(),"export_ms":float(Time.get_ticks_usec()-t)/1000.0} if file.success else file
		"browser_rejections":
			var loaded: Dictionary = route.load_current()
			var r: Dictionary = loaded.record
			var checks := []
			var mutated := r.duplicate(true); mutated.operations.append(mutated.operations[0].duplicate(true)); checks.append(not V6.validate(mutated,route.source).success)
			mutated = r.duplicate(true); mutated.applied_ids.append(mutated.applied_ids[0].duplicate(true)); checks.append(not V6.validate(mutated,route.source).success)
			mutated = r.duplicate(true); mutated.accounting.expc_available += 1; checks.append(not V6.validate(mutated,route.source).success)
			if not r.evidence.awards.is_empty():
				mutated = r.duplicate(true); mutated.evidence.awards.append(mutated.evidence.awards[0].duplicate(true)); checks.append(not V6.validate(mutated,route.source).success)
			if not r.evidence.purchases.is_empty():
				mutated = r.duplicate(true); mutated.evidence.purchases.append(mutated.evidence.purchases[0].duplicate(true)); checks.append(not V6.validate(mutated,route.source).success)
			return {"success":true,"checks":checks,"journal":r.recent_journal.size(),"operations":r.operations.size(),"ids":r.applied_ids.size()}
	return {"success":false,"reason":"unknown_browser_kind"}
func _summary(route: RefCounted) -> Dictionary:
	var loaded: Dictionary = route.load_current()
	if not loaded.success: return loaded
	if loaded.get("empty",false): return {"success":true,"empty":true}
	var r: Dictionary = loaded.record
	return {"success":true,"token":route.token(loaded),"text_sha":loaded.text.sha256_text(),"accounting":r.accounting,"attributes":V6.validate(r,route.source).actor.attributes,"growth":r.evidence.growth,"items":r.current.items.size(),"operations":r.operations.size(),"ids":r.applied_ids.size(),"generation":r.current.generation,"record_bytes":loaded.text.to_utf8_buffer().size(),"capsule_bytes":loaded.capsule_text.to_utf8_buffer().size(),"recovery_needed":loaded.exact_recovery_needed}
