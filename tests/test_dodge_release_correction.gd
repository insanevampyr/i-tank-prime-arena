extends RefCounted

# The same checks run in native debug and an isolated release-WASM scene.
# Comparisons use the original debug snapshots, not release-normalized fields.
const Defenses = preload("res://tests/test_physical_defenses.gd")
const Original = preload("res://tests/test_playable_vaelis_persistence.gd")
const V3 = preload("res://scripts/rewards/minimal_character_snapshot_v3.gd")
var assertions := 0
var failures: Array[String] = []
var samples := {}

func check(value: bool, message: String) -> void:
	assertions += 1
	if not value: failures.append(message)

func unchanged(simulation: CombatSimulation, before: Dictionary, events: Array, message: String) -> void:
	check(simulation.get_state_snapshot() == before, message+": state and RNG")
	check(serialized_events(simulation) == events, message+": events")

func serialized_events(simulation: CombatSimulation) -> Array:
	var events := []
	for event: CombatEvent in simulation.get_resolved_events(): events.append(event.to_dictionary())
	return events

func record(label: String, simulation: CombatSimulation, before: Dictionary, result: Dictionary) -> void:
	samples[label] = {"before":before,"after":simulation.get_state_snapshot(),"events":serialized_events(simulation),"result":result}

func run() -> Array[String]:
	assertions = 0; failures.clear(); samples.clear()
	var d := Defenses.new()
	var seed_value: int = d._find_seed_for_d20_sequence([5,3])
	for automatic: bool in [false,true]:
		var f: Dictionary = d._build_pending_attack(seed_value,d._make_profile(&"release_once"))
		var sim: CombatSimulation = f.simulation
		var state: CombatActorState = sim.get_actor_state(&"target")
		var before := sim.get_state_snapshot()
		var revision: int = state.revision
		var draws: int = sim.random.get_draw_count()
		var result: Dictionary
		if automatic:
			result = sim.resolve_pending_defense_automatically(f.attack_id,"dodge_once",d._environment(&"release_candidates",true,[d._candidate(&"near",Vector2i(2_000_000,0),2_000_000)]))
		else:
			result = sim.resolve_pending_defense(f.attack_id,"dodge_once",d._resolved_dodge(Vector2i(2_000_000,0),2_000_000))
		check(result.success,"Resolved successful Dodge")
		check(state.remaining_mr_microfeet == 8_000_000,"Successful Dodge spends exactly 2 feet once")
		check(state.revision == revision+2,"One spend revision plus one displacement revision")
		check(state.position_microfeet == Vector2i(2_000_000,0),"Original destination preserved")
		check(sim.random.get_draw_count() == draws+1,"Exactly one original defense roll")
		var resolution: CombatDefenseResolution = sim.get_defense_resolution(result.defense_resolution_id)
		check(resolution.attempts[0].resources_spent == {"mr_microfeet":2_000_000},"Exact original resource event binding")
		record("automatic" if automatic else "resolved",sim,before,result)
		var settled := sim.get_state_snapshot(); var events := serialized_events(sim)
		check(sim.resolve_pending_defense(f.attack_id,"dodge_once",d._resolved_dodge(Vector2i(4_000_000,0),2_000_000)).get("reason") == "duplicate_defense_request","Duplicate request rejected")
		unchanged(sim,settled,events,"Duplicate cannot spend movement or draw again")
		check(sim.resolve_pending_defense(f.attack_id,"late_new_id",d._resolved_dodge(Vector2i(4_000_000,0),2_000_000)).get("reason") == "attack_not_pending_defense","New ID cannot resolve a completed attack")
		unchanged(sim,settled,events,"Completed attack cannot spend twice")

	var f: Dictionary = d._build_pending_attack(seed_value,d._make_profile(&"release_pending"))
	var sim: CombatSimulation = f.simulation; var state: CombatActorState = sim.get_actor_state(&"target")
	var before := sim.get_state_snapshot(); var revision: int = state.revision
	var pending: Dictionary = sim.resolve_pending_defense(f.attack_id,"choose_later",CombatDodgeContext.new(CombatDodgeContext.SELECTION_AMBIGUOUS,Vector2i.ZERO,null,false,true,true,"TEST-FIXTURE"))
	check(pending.success and state.remaining_mr_microfeet == 10_000_000 and state.revision == revision,"Ambiguous success waits without spending")
	var waiting := sim.get_state_snapshot(); var events := serialized_events(sim)
	var invalid: Dictionary = sim.complete_pending_dodge_displacement(f.attack_id,"invalid_cost",d._resolved_dodge(Vector2i(6_000_000,0),6_000_000))
	check(invalid.get("reason") == "dodge_exceeds_half_mr","Invalid destination cost still rejected")
	unchanged(sim,waiting,events,"Invalid completion does not mutate or roll")
	var draws: int = sim.random.get_draw_count()
	var result: Dictionary = sim.complete_pending_dodge_displacement(f.attack_id,"chosen",d._resolved_dodge(Vector2i(3_000_000,0),3_000_000))
	check(result.success and state.remaining_mr_microfeet == 7_000_000,"Pending completion spends exactly 3 feet once")
	check(state.revision == revision+2,"Pending completion has one spend and one position revision")
	check(sim.random.get_draw_count() == draws,"Completion never rerolls Dodge")
	record("pending_completion",sim,before,result)
	var settled := sim.get_state_snapshot(); events = serialized_events(sim)
	check(sim.complete_pending_dodge_displacement(f.attack_id,"chosen",d._resolved_dodge(Vector2i(4_000_000,0),1_000_000)).get("reason") == "duplicate_defense_request","Repeated completion rejected")
	unchanged(sim,settled,events,"Repeated completion cannot spend twice")

	f = d._build_pending_attack(d._find_seed_for_d20_sequence([5,10,10,10]),d._make_profile(&"release_failed"))
	sim = f.simulation; state = sim.get_actor_state(&"target"); before = sim.get_state_snapshot(); revision = state.revision; draws = sim.random.get_draw_count()
	result = sim.resolve_pending_defense(f.attack_id,"failed",d._resolved_dodge(Vector2i(2_000_000,0),2_000_000))
	check(result.success,"Failed roll still resolves original defense")
	check(state.remaining_mr_microfeet == 10_000_000 and state.position_microfeet == Vector2i.ZERO and state.revision == revision,"Failed Dodge never spends or moves")
	check(sim.random.get_draw_count() == draws+3,"Failed Dodge and original legal block fallbacks retain their three rolls")
	record("failed_roll",sim,before,result)

	f = d._build_pending_attack(seed_value,d._make_profile(&"release_invalid")); sim = f.simulation
	before = sim.get_state_snapshot(); events = serialized_events(sim)
	check(sim.resolve_pending_defense(f.attack_id,"",d._resolved_dodge(Vector2i(2_000_000,0),2_000_000)).get("reason") == "missing_request_id","Missing ID rejected")
	unchanged(sim,before,events,"Missing ID has no effects")
	check(sim.resolve_pending_defense("unknown","invalid_attack",d._resolved_dodge(Vector2i(2_000_000,0),2_000_000)).get("reason") == "unknown_attack","Unknown attack rejected")
	unchanged(sim,before,events,"Unknown attack has no effects")
	check(sim.resolve_pending_defense(f.attack_id,"missing_context").get("reason") == "dodge_context_unresolved","Missing context rejected")
	unchanged(sim,before,events,"Missing context has no effects")
	record("invalid_requests",sim,before,{"reason":"unchanged"})

	f = d._build_pending_attack(seed_value,d._make_profile(&"release_duck"),{},&"hand_held",true,PackedStringArray(["bashing"]),false,CombatAttackDefinition.DUCKING_ALLOWED)
	sim = f.simulation; state = sim.get_actor_state(&"target"); before = sim.get_state_snapshot(); revision = state.revision
	result = sim.resolve_pending_defense_automatically(f.attack_id,"duck",d._environment(&"release_duck",true,[d._candidate(&"duck",Vector2i.ZERO,0,true,true,true,true,true,true,true)]))
	check(result.success and state.remaining_mr_microfeet == 10_000_000 and state.position_microfeet == Vector2i.ZERO,"Legal duck still costs zero movement")
	check(state.revision == revision+1,"Zero-cost successful spend retains original single revision")
	record("duck",sim,before,result)
	check(d._failures.is_empty(),"Existing source fixture assertions")
	return failures

# Same frozen original #46J source/seed and verified admission boundary. No
# IndexedDB connection or storage publication, and no alteration of its oracle.
func checkpoint_sample(initial_text: String) -> Dictionary:
	var body: Dictionary = JSON.parse_string(JSON.parse_string(initial_text).body_json)
	var source: CombatCharacterDefinitionResource = PlayableCharacterAdmission.prepare_starter(&"vaelis_thorn",body.current.profile_namespace,body.current.lineage.baseline_digest).source
	var coordinator := CharacterPersistenceCoordinator.new(null)
	var root := OS.get_cache_dir().path_join("itank-storage-tests/minimal46c2_46j1_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()])
	var admitted := coordinator.admit_minimal_snapshot_v3(initial_text,source,body.current.character_id,body.current.profile_namespace,root)
	if not admitted.success: return admitted
	var automatic := coordinator.simulate_minimal_automatic_checkpoints(true)
	if not automatic.success: coordinator.close_minimal_prototype(); return automatic
	var session: ArenaCombatSession = coordinator._minimal_owner._session
	Original.new()._defeat_wave(session)
	var loot := session.collect_all_ground_loot()
	var result := {"body":JSON.parse_string(coordinator.minimal_view().body_json),"simulation":session.get_state_snapshot(),"loot_success":loot.success}
	coordinator.close_minimal_prototype()
	return result
