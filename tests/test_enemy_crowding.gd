extends RefCounted
const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
var failures: Array[String] = []
var assertions := 0
func check(value: bool, message: String) -> void:
	assertions += 1
	if not value: failures.append(message)
func probe(seed_value: int, moving: bool) -> Dictionary:
	var s := ArenaCombatSession.new(seed_value,null,Fixture.ENCOUNTER_WAVE_ONE_GOBLINS)
	s.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
	s.set_opponent_behavior_enabled(true)
	check(s.initialize_wave_one_goblins(Vector2i(20_000_000,12_000_000),Vector2i(38_000_000,12_000_000),true).success,"Source-backed seeded fixture initializes.")
	var starts := {}; var previous := {}; var directions := {}; var reversals := {}
	var authored := {}; var saw_staging := false
	for id: String in s.get_targetable_enemy_ids():
		authored[id] = s.simulation.get_actor_definition(StringName(id)).to_dictionary().duplicate(true)
		starts[id] = s.get_actor_state(StringName(id)).position_microfeet
		previous[id] = starts[id]
	for tick in range(350):
		# Isolated diagnostic target stays alive; authored definitions are unchanged.
		s.get_actor_state(&"player").current_hpc = 1000000
		if moving:
			var p := s.get_actor_state(&"player").position_microfeet
			s.request_player_movement(p+Vector2i(0,25000 if (tick/50)%2 == 0 else -25000),11)
		s.advance_by(100000)
		saw_staging = saw_staging or not s._goblin_staging.is_empty()
		for id: String in s.get_targetable_enemy_ids():
			var position := s.get_actor_state(StringName(id)).position_microfeet
			var delta: Vector2i = position-previous[id]
			if delta != Vector2i.ZERO:
				if directions.has(id) and Vector2(delta).dot(Vector2(directions[id])) < 0: reversals[id] = int(reversals.get(id,0))+1
				directions[id] = delta
			previous[id] = position
			check(s.get_battlefield().is_position_legal(StringName(id),position,s._actor_occupancy()).legal,"Crowding never overlaps an actor, wall or boundary.")
			var mr: int = s.simulation.get_actor_definition(StringName(id)).get_combat_stat("mr")
			check(int(s._goblin_movement_spent.get(id,0)) <= mr*1000000,"Staging preserves ordinary MR expenditure.")
	var metrics := {}
	for id: String in s.get_targetable_enemy_ids():
		check(s.simulation.get_actor_definition(StringName(id)).to_dictionary() == authored[id],"Staging never changes authored attributes, movement or weapon reach.")
		var net := roundi(Vector2(s.get_actor_state(StringName(id)).position_microfeet-starts[id]).length())
		var rebuilds: int = s.get_goblin_path_rebuild_counts_for_testing().get(id,0)
		metrics[id] = {"net":net,"rebuilds":rebuilds,"reversals":reversals.get(id,0)}
		check(net >= 10000000,"%s seed %d must stage/pursue rather than remain near spawn: %d" % [id,seed_value,net])
		check(rebuilds <= (48 if moving else 32),"%s seed %d must bound full searches: %d" % [id,seed_value,rebuilds])
		check(int(reversals.get(id,0)) <= (12 if moving else 6),"No persistent crowding oscillation.")
	if seed_value == 23 and not moving:
		check(saw_staging,"Occupied melee slots produce explicit navigation-only staging.")
		var waiting: Array[String] = []
		var release := ""
		for id: String in s.get_targetable_enemy_ids():
			if s._get_actor_attack_geometry(StringName(id),&"player").success:
				if release.is_empty(): release = id
			else: waiting.append(id)
		check(not release.is_empty() and not waiting.is_empty(),"Crowded case contains an attacker and waiting actors.")
		if not release.is_empty(): s.get_actor_state(StringName(release)).current_hpc = 0
		for _tick in range(100):
			s.get_actor_state(&"player").current_hpc = 1000000
			s.advance_by(100000)
		var resumed := false
		for id: String in waiting:
			if s._get_actor_attack_geometry(StringName(id),&"player").success: resumed = true
		check(resumed,"A waiting actor resumes pursuit when a melee position is released.")
	print("43E crowding seed=%d moving=%s: %s" % [seed_value,moving,metrics])
	return {"session":s,"events":s.get_resolved_events().map(func(e): return e.to_dictionary())}

func check_mode_parity() -> void:
	var sessions: Array[ArenaCombatSession] = []
	for mode: String in ["normal","dev_normal"]:
		var s := ArenaCombatSession.new(23,null,Fixture.ENCOUNTER_WAVE_ONE_GOBLINS)
		s.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
		s.set_opponent_behavior_enabled(true)
		check(s.initialize_wave_one_goblins(Vector2i(20_000_000,12_000_000),Vector2i(38_000_000,12_000_000),false).success,"Parity fixture initializes before admission.")
		check(s.configure_reward_mode(mode).success and s.start_encounter().success,"Both persistent modes use the shared pursuit engine in disposable fixtures.")
		for _tick in range(250):
			s.get_actor_state(&"player").current_hpc = 1000000
			s.advance_by(100000)
		sessions.append(s)
	var normal := sessions[0].simulation.get_state_snapshot()
	var dev := sessions[1].simulation.get_state_snapshot()
	# The historical namespaces intentionally retain distinct reward policies.
	# Compare every combat field, including pending events, counters and RNG.
	normal.erase("reward_state"); dev.erase("reward_state")
	check(normal == dev,"NORMAL/DEV crowded combat snapshots, action clocks and RNG remain identical apart from the intended reward policy.")
	check(sessions[0].get_goblin_path_rebuild_counts_for_testing() == sessions[1].get_goblin_path_rebuild_counts_for_testing(),"NORMAL/DEV navigation work remains identical.")

func run() -> Array[String]:
	PlayableCharacterPersistence.test_nonpersistent = true
	probe(3,false)
	probe(3,true)
	var a := probe(23,false)
	var b := probe(23,false)
	check(a.events == b.events and a.session.get_state_snapshot() == b.session.get_state_snapshot(),"Crowded pursuit has deterministic RNG, events and replay state.")
	var sync := TwoClientSyncHarness.new(23)
	# A bounded initial crowding window exercises every event through both
	# clients. Full 35-second histories above are compared directly for replay;
	# do not attach thousands of copies of a large terminal snapshot to them.
	var window := ArenaCombatSession.new(23,null,Fixture.ENCOUNTER_WAVE_ONE_GOBLINS)
	window.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
	window.set_opponent_behavior_enabled(true)
	window.initialize_wave_one_goblins(Vector2i(20_000_000,12_000_000),Vector2i(38_000_000,12_000_000),true)
	for _i in range(20):
		window.get_actor_state(&"player").current_hpc = 1000000
		window.advance_by(100000)
	sync.authority.simulation = window.simulation
	sync.deliver_in_order(sync.authority.publish_current_events())
	check(sync.compare_clients().success and sync.authority.get_state_digest() == sync.client_a.get_state_digest(),"Crowding event history converges on simulated clients.")
	probe(23,true)
	check_mode_parity()
	print("43E crowding: %d assertions." % assertions)
	return failures
