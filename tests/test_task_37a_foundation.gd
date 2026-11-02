extends RefCounted

const Allocation = preload("res://scripts/combat/dex_allocation.gd")
const Chart = preload("res://scripts/combat/prime_v3_dex_chart.gd")
const Preferences = preload("res://scripts/combat/defensive_preferences.gd")
const Admission = preload("res://scripts/rewards/playable_character_admission.gd")
var failures: Array[String] = []

func run() -> Array[String]:
	var starter := Admission.prepare_starter(&"vaelis_thorn","normal")
	check(starter.success,"Fresh authored Vaelis must still pass admission.")
	if starter.success:
		check(starter.actor.attributes.dex == 9 and starter.actor.combat_stats.dt == 6 and starter.actor.combat_stats.dp == 3 and starter.actor.combat_stats.acc == 9,"Owner-approved premade changes only its DEX allocation.")
	permanent()
	temporary()
	preferences()
	legacy()
	for mode: String in ["mana","regular"]:
		check(Chart.accuracy(0,mode) == 0 and Chart.accuracy(1,mode) == 5 and Chart.accuracy(9,mode) == 9 and Chart.accuracy(10,mode) == 9 and Chart.accuracy(11,mode) == 10 and Chart.accuracy(20,mode) == 18 and Chart.accuracy(25,mode) == 20 and Chart.accuracy(35,mode) == 30,"V3 chart boundaries and non-linear ACC transitions must match both charts.")
	check(Chart.accuracy(-1,"mana") == null and Chart.accuracy(36,"mana") == null and Chart.accuracy(9,"unknown") == null,"Unsupported chart inputs must not invent values.")
	check(not PrimeV3AdvancementCatalog.make_purchase_preview(&"attribute",&"dex",9,10).available,"DEX purchases remain blocked.")
	return failures

func permanent() -> void:
	var state: Dictionary = Allocation.create(9,6,3).state
	var before := state.duplicate(true)
	state = Allocation.request(state,{"op":"grant","id":"profile/growth/one","dex":11}).state
	check(Allocation.contributions(state).pending == 2 and Allocation.contributions(state).dt == 6 and before.history.is_empty(),"Growth grants only the delta and never redistributes/mutates the original.")
	check(not Allocation.request(state,{"op":"grant","id":"profile/growth/one","dex":12}).success,"Repeated growth receipt cannot grant points twice.")
	check(not Allocation.request(state,{"op":"allocate","id":"profile/allocation/one","dt":1,"dp":1,"confirmed":false}).success,"Permanent assignment needs explicit confirmation.")
	state = Allocation.request(state,{"op":"allocate","id":"profile/allocation/one","dt":1,"dp":1,"confirmed":true}).state
	var totals := Allocation.contributions(state)
	check(totals.dt == 7 and totals.dp == 4 and totals.pending == 0,"Permanent assignments conserve points.")
	check(not Allocation.request(state,{"op":"allocate","id":"profile/allocation/two","dt":1,"dp":0,"confirmed":true}).success,"Locked points cannot be reassigned.")
	check(not Allocation.request(state,{"op":"grant","id":"profile/growth/two","dex":10}).success,"Negative permanent DEX policy stays gated.")
	var encoded := JSON.stringify(state)
	var decoded: Dictionary = CharacterSaveContract._normalize_json_numbers(JSON.parse_string(encoded))
	check(Allocation.validate(decoded).success and Allocation.contributions(decoded) == totals,"Isolated model history reload grants no duplicate points.")
	decoded.history[0].dex = 8
	check(not Allocation.validate(decoded).success,"Inconsistent recorded growth must fail closed.")

func temporary() -> void:
	var state: Dictionary = Allocation.create(9,6,3).state
	for bonus in range(1,6):
		var sample := Allocation.request(state,{"op":"activate","source":"item/one","activation":"cast/one","points":bonus})
		var t := Allocation.contributions(sample.state)
		check(t.dt == 6+(bonus+1)/2 and t.dp == 3+bonus/2,"Temporary DEX must split even/odd correctly.")
	state = Allocation.request(state,{"op":"activate","source":"item/one","activation":"cast/one","points":3}).state
	state = Allocation.request(state,{"op":"activate","source":"item/two","activation":"cast/one","points":2}).state
	var unchanged := state.duplicate(true)
	check(not Allocation.request(state,{"op":"customize","source":"item/one","activation":"cast/one","dt":0,"dp":3,"safe_downtime":false,"confirmed":true}).success and state == unchanged,"Combat cannot confirm draft allocation or mutate accepted state.")
	state = Allocation.request(state,{"op":"customize","source":"item/one","activation":"cast/one","dt":0,"dp":3,"safe_downtime":true,"confirmed":true}).state
	check(not Allocation.request(state,{"op":"customize","source":"item/one","activation":"cast/one","dt":3,"dp":0,"safe_downtime":true,"confirmed":true}).success,"Customization locks the activation.")
	state = Allocation.request(state,{"op":"remove","source":"item/one","activation":"cast/one"}).state
	check(Allocation.contributions(state).dt == 7 and Allocation.contributions(state).dp == 4,"Removing an activation leaves the other source intact.")
	state = Allocation.request(state,{"op":"activate","source":"item/one","activation":"cast/one","points":3}).state
	check(Allocation.contributions(state).dp == 7,"Same activation restores its remembered split, including the lock.")
	state = Allocation.request(state,{"op":"remove","source":"item/one","activation":"cast/one"}).state
	state = Allocation.request(state,{"op":"activate","source":"item/one","activation":"cast/two","points":3}).state
	check(Allocation.contributions(state).dt == 9 and Allocation.contributions(state).dp == 5,"New activation receives fresh automatic split.")
	check(not Allocation.request(state,{"op":"activate","source":"item/one","activation":"cast/three","points":1}).success,"Unverified same-source stacking is blocked.")
	check(not Allocation.request(state,{"op":"activate","source":"item/three","activation":"cast/one","points":-1}).success,"Negative DEX cannot enter positive allocation model.")
	check(not Allocation.request(state,{"op":"activate","source":"item/three","activation":"cast/one","points":1,"dt":1}).success,"Explicit DT/DP effects cannot be silently interpreted as generic DEX.")
	check(Allocation.derived(state,"mana").acc == 12,"ACC automatically follows effective DEX 14 without reallocating it.")

func preferences() -> void:
	var facts := {"dodge":{"eligible":true,"value":6},"soak":{"eligible":true,"value":8}}
	var blocks := [{"source":"weapon/one","eligible":true},{"source":"shield/one","eligible":true}]
	var nacs := [{"source":"bolt/one","eligible":false},{"source":"special/two","eligible":true}]
	var p := Preferences.plan(["nac","dodge","block","soak"],facts,blocks,nacs)
	check(p.success and p.choices == [{"kind":"nac","source":"special/two"},{"kind":"soak","source":"soak"},{"kind":"block","source":"weapon/one"},{"kind":"block","source":"shield/one"}],"Higher legal Soak is selected at first Dodge/Soak slot, and independent Block/NAC sources retain order.")
	facts.soak.eligible = false
	facts.soak.value = 100
	p = Preferences.plan(["block","soak","nac","dodge"],facts,blocks,[])
	check(p.choices.size() == 3 and p.choices[2].kind == "dodge","Ineligible Soak, regardless of value, cannot displace legal Dodge.")
	facts.soak = {"eligible":true,"value":6}
	check(Preferences.plan(["soak","block","nac","dodge"],facts,[],[]).choices[0].kind == "soak","Equal defenses follow player preference.")
	check(not Preferences.plan(["soak","block","nac","nac"],facts,[],[]).success,"Duplicate/missing preference entries are invalid.")
	check(not Preferences.plan(["soak","block","nac","dodge"],facts,blocks+[blocks[0]],[]).success,"A Block source cannot gain duplicate attempts.")
	facts.soak.eligible = "yes"
	check(not Preferences.plan(["soak","block","nac","dodge"],facts,[],[]).success,"Unverified eligibility cannot enable a defense.")

func legacy() -> void:
	var current: CombatCharacterDefinitionResource = load("res://data/characters/vaelis_thorn.tres")
	var historical := current.duplicate(true)
	historical.combat_stats.dt = 3
	historical.combat_stats.dp = 6
	historical.field_sources.combat_stats = "PRIME-V3 p. 53 Mana Attribute Chart applied to supplied attributes; DEX split 3 DT / 6 DP supplied"
	var digest := CharacterProfileProjection.fingerprint(historical.to_dictionary())
	for mode: String in ["normal","dev_normal"]:
		var old := Admission.prepare_starter(&"vaelis_thorn",mode,digest)
		check(old.success,"Exact historical authored baseline must remain available in both namespaces.")
		if old.success:
			check(old.actor.combat_stats.dt == 3 and old.actor.combat_stats.dp == 6 and old.prepared.payload.lineage.baseline_digest == digest,"Historical profile remains 3/6 with unchanged lineage.")
			legacy_playable(old,mode)
	check(current.combat_stats.dt == 6 and not Admission.prepare_starter(&"vaelis_thorn","normal","arbitrary_digest").success,"Legacy compatibility must not mutate new definitions or accept arbitrary histories.")

func legacy_playable(starter: Dictionary, mode: String) -> void:
	var path := OS.get_cache_dir().path_join("itank-storage-tests/legacy37_%s_%s_%s" % [mode,OS.get_process_id(),Time.get_ticks_usec()])
	var storage := CharacterSaveStorage.new(path)
	var service := PlayableCharacterPersistence.new()
	service.storage = storage
	service.mode = mode
	var opened := service.open_verified_history(starter,{"success":true,"writer_locked":false,"pending_write":false,"generations":[]},false,{})
	check(opened.success,"Historical baseline can start an isolated playable session.")
	if not opened.success: return
	var previous_test_mode := PlayableCharacterPersistence.test_nonpersistent
	PlayableCharacterPersistence.test_nonpersistent = false
	var session := ArenaCombatSession.new(7,null,PrimeV3VerticalSliceFixture.ENCOUNTER_WAVE_ONE_GOBLINS,&"vaelis_thorn")
	session.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
	# Arrange a checkpoint produced by the previous authored version. The reload
	# below goes through the ordinary native admission API against isolated storage.
	session._reward_mode = mode
	session._playable_persistence = service
	var initialized := session.initialize_wave_one_goblins(Vector2i(10000000,12000000),Vector2i(13000000,12000000),false)
	check(initialized.success,"Historical candidate must initialize with legal battlefield state: %s" % initialized)
	if initialized.success:
		var movement := PrimeMovementModel.new(10,11,6,3,0,0,DeterministicCombatRng.new(7))
		session.player_movement_boundary_provider = movement.wave_entry_state
		check(session.configure_reward_mode(mode).success,"Legacy fixture ledger must use the same namespace.")
		var committed := session.finalize_playable_persistence()
		check(committed.success,"Historical playable checkpoint must commit through verified storage: %s" % committed)
		var reloaded := PlayableCharacterPersistence.new()
		var prior_storage := PlayableCharacterPersistence.test_storage
		PlayableCharacterPersistence.test_storage = storage
		var loaded := reloaded.open(mode)
		PlayableCharacterPersistence.test_storage = prior_storage
		check(loaded.success,"Existing 3/6 history must load under new 6/3 authored definition.")
		if loaded.success: check(reloaded.candidate.actor_definition.combat_stats.dt == 3 and reloaded.candidate.actor_definition.combat_stats.dp == 6,"Reload must not redistribute historical allocation.")
		var backup := CharacterBackupContract.create(storage.inspect_profile(starter.profile_id),mode,"2026-11-02T00:00:00Z")
		check(backup.success,"Legacy complete history must still export and validate without migration: %s" % backup.get("reason",""))
		if backup.success: check(CharacterBackupContract.decode(backup.text,mode).success,"Legacy backup preview remains compatible.")
	PlayableCharacterPersistence.test_nonpersistent = previous_test_mode

func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
