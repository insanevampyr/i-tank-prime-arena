class_name WaveThreeSkellyHadesTests
extends RefCounted

const ArenaCombatSession = preload("res://scripts/combat/arena_combat_session.gd")
const ArenaBattlefield = preload("res://scripts/combat/arena_battlefield.gd")
const ArenaWaveStateMachine = preload("res://scripts/combat/arena_wave_state_machine.gd")
const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
const CommonSkellyFixture = preload("res://scripts/creatures/common_skelly_fixture.gd")
const HadesFixture = preload("res://scripts/creatures/hades_combat_follower_fixture.gd")
const HitLocations = preload("res://scripts/combat/combat_hit_location_catalog.gd")
const EventPresenter = preload("res://scripts/ui/arena_combat_event_presenter.gd")
const TwoClientSyncHarness = preload("res://scripts/sync/two_client_sync_harness.gd")

const PLAYER_POSITION := Vector2i(20_000_000, 12_000_000)
const ENEMY_POSITION := Vector2i(24_000_000, 12_000_000)

var _failures: Array[String] = []


func run() -> Array[String]:
	_failures.clear()
	_test_source_backed_profiles()
	_test_seeded_roster_and_independent_instances()
	_test_natural_attack_counts_at_one_and_two()
	_test_hades_rage_activation_effect_and_expiry()
	_test_hades_remaining_combat_specials()
	_test_rage_knockback_and_collision()
	_test_skelly_light_and_faith_responses()
	_test_victory_reset_replay_and_two_client_convergence()
	_test_maximum_wave_frame_partition_and_navigation()
	_test_launcher_and_presentation()
	return _failures


func _test_source_backed_profiles() -> void:
	var skelly := CommonSkellyFixture.make_actor(&"source_skelly", "Source Skelly")
	_expect_true(skelly != null, "Common Skelly source definition must instantiate.")
	if skelly != null:
		_expect_equal(skelly.size_category, HitLocations.SIZE_MEDIUM, "Prime V3 explicitly lists Skelly Size M.")
		for stat_and_value in [
			["hpm", 10], ["at", 1], ["mr", 6], ["acc", 8], ["init", 1],
			["dt", 4], ["dp", 4], ["nal", 0], ["physical_soak", 0], ["sb", 2],
		]:
			_expect_equal(skelly.get_combat_stat(stat_and_value[0]), stat_and_value[1], "Skelly %s must match the controlling Prime V3 profile." % stat_and_value[0])
		_expect_true(not skelly.defensive_capabilities.get("weapon_block", true), "Natural claws must not invent Weapon Block.")
	var skelly_attack := CommonSkellyFixture.make_attack_definition(HitLocations.get_same_size_attack_profile())
	_expect_true(skelly_attack != null, "Skelly claws must produce a combat-ready attack.")
	if skelly_attack != null:
		_expect_equal(skelly_attack.strikes_per_act, 2, "Two verified Skelly claws must make two strikes in one Act.")
		_expect_equal(skelly_attack.required_acts, 1, "Two claws must not become two Acts.")
		_expect_equal(skelly_attack.maximum_range_microfeet, 1_000_000, "Each Skelly claw has one-foot reach.")
		_expect_equal(Array(skelly_attack.damage_types), ["slashing"], "Skelly claws deal slashing damage.")
		_expect_equal(skelly_attack.physical_damage.die_sides, 6, "Each Skelly claw deals 1d6.")
	var protection := CommonSkellyFixture.make_damage_protection_profile(&"source_skelly")
	_expect_equal(protection.get_exact_type_response(PackedStringArray(["piercing"])).get("kind"), CombatDamageProtectionProfile.RESPONSE_IMMUNE, "Skelly piercing immunity must be source-backed and exact-type gated.")

	var hades := HadesFixture.make_actor(&"source_hades", "Source Hades Follower")
	_expect_true(hades != null, "Hades Combat Follower source definition must instantiate.")
	if hades != null:
		for stat_and_value in [
			["hpm", 50], ["at", 2], ["mr", 12], ["acc", 14], ["init", 4],
			["dt", 8], ["dp", 8], ["nal", 1], ["physical_soak", 0], ["sb", 1],
		]:
			_expect_equal(hades.get_combat_stat(stat_and_value[0]), stat_and_value[1], "Hades follower %s must match its source sheet." % stat_and_value[0])
		_expect_equal(hades.attributes.get("str"), 6, "Hades follower must meet the Short Sword STR 6 requirement exactly.")
		_expect_equal(hades.resource_maxima.get("ap"), 9, "The follower must expose its printed AP pool for owner-approved Special costs.")
	var hades_attack := HadesFixture.make_attack_definition(HitLocations.get_same_size_attack_profile())
	_expect_true(hades_attack != null, "Hades follower Short Sword must be combat ready.")
	if hades_attack != null:
		_expect_equal(hades_attack.strikes_per_act, 1, "A held Short Sword must not inherit the natural multi-attack ruling.")
		_expect_equal(hades_attack.maximum_range_microfeet, 2_000_000, "Short Sword reach must remain two feet.")
		_expect_equal(Array(hades_attack.damage_types), ["slashing", "piercing"], "Short Sword keeps its verified combined damage types.")
		_expect_equal(hades_attack.physical_damage.flat_bonus, 1, "Short Sword keeps its verified +1 fixed damage.")


func _test_seeded_roster_and_independent_instances() -> void:
	var observed_counts := {}
	for seed in range(1, 128):
		var session := _ready_wave_session(seed, false)
		var roster: Array = session.get_arena_wave_state().get("resolved_roster", [])
		var skelly_count := _roster_count(roster, "common_skelly")
		var hades_count := _roster_count(roster, "hades_combat_follower")
		observed_counts[skelly_count] = true
		_expect_equal(hades_count, 1, "Wave 3 must contain exactly one fixed Hades follower.")
		_expect_equal(session.get_targetable_enemy_ids().size(), skelly_count + 1, "Wave 3 actor count must match one d2 plus one fixed follower.")
		var skelly_entry := _roster_entry(roster, "common_skelly")
		var hades_entry := _roster_entry(roster, "hades_combat_follower")
		_expect_equal(skelly_entry.get("dice_count"), 1, "Wave 3 must consume exactly one d2 draw for Skelly quantity.")
		_expect_equal((skelly_entry.get("dice_results", []) as Array).size(), 1, "The d2 result must be retained in authoritative history.")
		_expect_equal((hades_entry.get("rng_draw_indices", []) as Array).size(), 0, "The fixed follower must not consume an RNG draw.")
		var mutable_states := []
		for actor_id: String in session.get_targetable_enemy_ids():
			mutable_states.append(session.get_actor_state(StringName(actor_id)))
		for left in range(mutable_states.size()):
			for right in range(left + 1, mutable_states.size()):
				_expect_true(mutable_states[left] != mutable_states[right], "Every Wave 3 enemy must own independent mutable state.")
		if observed_counts.size() == 2:
			break
	_expect_true(observed_counts.has(1) and observed_counts.has(2), "Deterministic seed sampling must produce both legal 1d2 Skelly quantities.")


func _test_natural_attack_counts_at_one_and_two() -> void:
	var at_one := _ready_wave_session(32_301, false)
	var skelly_id := _first_actor_with_prefix(at_one, "wave_3_common_skelly_")
	var at_one_result := _declare_skelly_attack_direct(at_one, skelly_id, 1)
	_expect_equal(at_one_result.get("declaration_count"), 2, "AT 1 plus two claws must declare exactly two independent strikes.")
	_expect_equal(at_one_result.get("duration_us"), 5_000_000, "AT 1 natural-attack Act must last five seconds.")
	_expect_equal(at_one_result.get("accuracy_count"), 2, "Both AT 1 claws must independently resolve ACC.")

	var at_two := _ready_wave_session(32_302, false)
	var at_two_skelly_id := _first_actor_with_prefix(at_two, "wave_3_common_skelly_")
	var definition := at_two.simulation.get_actor_definition(at_two_skelly_id)
	definition.base_combat_stats["at"] = 2
	definition.combat_stats["at"] = 2
	var at_two_result := _declare_skelly_attack_direct(at_two, at_two_skelly_id, 2)
	_expect_equal(at_two_result.get("declaration_count"), 2, "AT 2 changes Act frequency, not the verified two-claw strike count.")
	_expect_equal(at_two_result.get("duration_us"), 2_500_000, "AT 2 natural-attack Act must last 2.5 seconds.")
	_expect_equal(at_two_result.get("accuracy_count"), 2, "Both AT 2 claws must independently resolve ACC within the shared Act.")


func _test_hades_rage_activation_effect_and_expiry() -> void:
	var session := _ready_wave_session(32_303, true)
	var hades_id := _first_actor_with_prefix(session, "wave_3_hades_combat_follower_")
	var state := session.get_actor_state(hades_id)
	var position_before_rage: Vector2i = state.position_microfeet
	_expect_true(not state.current_action_instance_id.is_empty(), "Hades follower must cast verified Combat Rage before ordinary attacks.")
	if state.current_action_instance_id.is_empty():
		return
	var action := session.simulation.get_action(state.current_action_instance_id)
	_expect_equal(action.action_definition_id, HadesFixture.RAGE_ACTION_ID, "The first Hades action must be Combat Rage.")
	_expect_equal(action.final_effect_due_at_us - action.started_at_us, 5_000_000, "Two Rage Acts at AT 2 must complete in five seconds.")
	_expect_equal(state.resources.get("ap"), 9, "A free daily Rage use must not spend AP.")
	_expect_equal(state.ability_daily_remaining.get(String(HadesFixture.RAGE_ACTION_ID)), 1, "Starting Rage must commit exactly one of its two daily uses.")
	session.advance_by(5_000_000)
	_expect_true(state.timed_stat_effects.has(String(HadesFixture.RAGE_EFFECT_ID)), "Completed Rage must activate its two-minute timed effect.")
	_expect_true(state.position_microfeet != position_before_rage, "Rage must preserve legal concurrent movement while the follower approaches.")
	_expect_equal(session.simulation.get_effective_actor_combat_stat(hades_id, "sb"), 3, "Rage must add +2 to base SB 1.")
	_expect_equal(session.simulation.get_effective_actor_combat_stat(hades_id, "nal"), -1, "Rage must apply -2 to effective NAL 1 without inventing a floor.")
	_expect_equal(session.simulation.get_effective_actor_combat_stat(hades_id, "dt"), 7, "Rage must apply -1 DT.")
	_expect_equal(session.simulation.get_effective_actor_combat_stat(hades_id, "dp"), 7, "Rage must apply -1 DP.")
	session.advance_by(3_000_000)
	var hades_declarations := _events_for_source(session, &"physical_attack_declared", hades_id)
	_expect_true(not hades_declarations.is_empty(), "After Rage, the follower must pursue and declare its legal Short Sword attack.")
	if not hades_declarations.is_empty():
		_expect_equal(hades_declarations[0].payload.get("weapon_ref"), String(HadesFixture.WEAPON_REF), "Follower attack evidence must identify the equipped Short Sword.")
		_expect_equal(hades_declarations[0].payload.get("strikes_per_act"), 1, "The natural-attack ruling must not duplicate a held Short Sword strike.")

	var expiry_session := _ready_wave_session(32_307, false)
	var expiry_hades_id := _first_actor_with_prefix(expiry_session, "wave_3_hades_combat_follower_")
	var expiry_state := expiry_session.get_actor_state(expiry_hades_id)
	var rage_start := expiry_session.simulation.start_verified_timed_stat_effect_action(
		expiry_hades_id,
		HadesFixture.make_rage_action_definition(),
		"rage_expiry_fixture"
	)
	_expect_true(rage_start.get("success", false), "The verified Rage action must start through its resource-committing boundary.")
	var expiry_action := expiry_session.simulation.get_action(String(rage_start.get("action_instance_id", "")))
	expiry_session.simulation.advance_to(expiry_action.final_effect_due_at_us)
	var expires_at_us := int(expiry_state.timed_stat_effects.get(String(HadesFixture.RAGE_EFFECT_ID), {}).get("expires_at_us", -1))
	_expect_equal(expires_at_us, 125_000_000, "A five-second cast must produce an exact 120-second effect ending at 125 seconds.")
	expiry_session.simulation.advance_to(expires_at_us)
	_expect_true(not expiry_state.timed_stat_effects.has(String(HadesFixture.RAGE_EFFECT_ID)), "Rage must expire at its authoritative two-minute boundary.")
	_expect_equal(expiry_session.simulation.get_effective_actor_combat_stat(expiry_hades_id, "sb"), 1, "Expired Rage must restore baseline SB without cumulative mutation.")

	var interrupted_session := _ready_wave_session(32_308, false)
	var interrupted_id := _first_actor_with_prefix(interrupted_session, "wave_3_hades_combat_follower_")
	var interrupted_state := interrupted_session.get_actor_state(interrupted_id)
	var interrupted_start := interrupted_session.simulation.start_verified_timed_stat_effect_action(interrupted_id, HadesFixture.make_rage_action_definition(), "rage_interrupt_fixture")
	var interrupted_action_id := String(interrupted_start.get("action_instance_id", ""))
	_expect_true(interrupted_start.get("success", false), "Interrupt fixture Rage must begin legally.")
	_expect_true(interrupted_session.simulation.schedule_interruption(interrupted_action_id, 1_000_000, Fixture.PLAYER_ID, "test_interrupt").get("success", false), "Rage must remain interruptible.")
	interrupted_session.simulation.advance_to(5_000_000)
	_expect_equal(interrupted_state.resources.get("ap"), 9, "Interrupted Rage must not spend AP while a daily use was available.")
	_expect_equal(interrupted_state.ability_daily_remaining.get(String(HadesFixture.RAGE_ACTION_ID)), 1, "Interrupted Rage must retain its one committed daily-use payment.")
	_expect_true(not interrupted_state.timed_stat_effects.has(String(HadesFixture.RAGE_EFFECT_ID)), "Interrupted Rage must not apply its completion effect.")


func _test_hades_remaining_combat_specials() -> void:
	var called_session := _ready_wave_session(32_310, false)
	var called_id := _first_actor_with_prefix(called_session, "wave_3_hades_combat_follower_")
	called_session.simulation.apply_authoritative_position(called_id, PLAYER_POSITION + Vector2i(1_000_000, 0), 180_000)
	var called_state := called_session.get_actor_state(called_id)
	var called := called_session.simulation.start_verified_special_action(
		called_id, Fixture.PLAYER_ID, HadesFixture.make_called_shot_action_definition(),
		"called_shot_fixture", &"head"
	)
	_expect_true(called.get("success", false), "Called Shot preparation must start through the authoritative Special boundary.")
	called_session.simulation.advance_to(called_session.simulation.get_action(String(called.get("action_instance_id", ""))).final_effect_due_at_us)
	_expect_equal(called_state.resources.get("ap"), 9, "A free daily Called Shot must not spend AP.")
	_expect_equal(called_state.ability_daily_remaining.get(String(HadesFixture.CALLED_SHOT_ACTION_ID)), 1, "Called Shot must consume exactly one daily use.")
	_expect_equal(called_state.pending_called_shot.get("target_location"), "head", "Called Shot must lock its announced location after its first Act.")
	var attack_result := called_session.simulation.start_physical_attack(
		called_id, Fixture.PLAYER_ID, HadesFixture.make_attack_definition(HitLocations.get_same_size_attack_profile()),
		"called_shot_attack", &"head", true
	)
	_expect_true(attack_result.get("success", false), "The next legal Called Shot attack must declare normally.")
	var called_attack := called_session.simulation.get_attack(String(attack_result.get("attack_instance_id", "")))
	called_session.simulation.advance_to(called_session.simulation.get_action(String(attack_result.get("action_instance_id", ""))).final_effect_due_at_us)
	_expect_equal(called_attack.automatic_accuracy_reason, "called_shot", "Called Shot must mark automatic accuracy without changing final legality.")
	_expect_equal(called_attack.natural_roll, null, "Called Shot automatic accuracy must not consume an ACC d20.")
	_expect_equal(called_attack.accuracy_success, true, "A finally legal Called Shot must reach defenses as an accurate attack.")

	var mist_session := _ready_wave_session(32_311, false)
	var mist_id := _first_actor_with_prefix(mist_session, "wave_3_hades_combat_follower_")
	var mist_state := mist_session.get_actor_state(mist_id)
	mist_state.current_hpc = 30
	var mist := mist_session.simulation.start_verified_special_action(
		mist_id, mist_id, HadesFixture.make_rejuvenating_mist_action_definition(), "mist_fixture"
	)
	_expect_true(mist.get("success", false), "Rejuvenating Mist must allow its legal self target.")
	mist_session.simulation.advance_to(mist_session.simulation.get_action(String(mist.get("action_instance_id", ""))).final_effect_due_at_us)
	_expect_equal(mist_state.resources.get("ap"), 9, "A free daily Rejuvenating Mist must not spend AP.")
	_expect_equal(mist_state.ability_daily_remaining.get(String(HadesFixture.REJUVENATING_MIST_ACTION_ID)), 2, "Rejuvenating Mist must consume one of three daily uses.")
	_expect_true(int(mist_state.current_hpc) >= 34 and int(mist_state.current_hpc) <= 44, "Rejuvenating Mist must restore deterministic 2d6+2 HPC.")

	var buff_session := _ready_wave_session(32_312, false)
	var buff_id := _first_actor_with_prefix(buff_session, "wave_3_hades_combat_follower_")
	var missing_dirt := buff_session.simulation.start_verified_special_action(
		buff_id, buff_id, HadesFixture.make_defensive_buff_action_definition(), "buff_missing_dirt"
	)
	_expect_equal(missing_dirt.get("reason"), "special_required_material_missing", "Defensive Buff must fail closed without its source-required dirt.")
	var dirt_surface := buff_session._battlefield.get_gatherable_material_at(buff_session.get_actor_state(buff_id).position_microfeet, &"dirt")
	var gather_dirt := buff_session.simulation.start_gather_material_action(
		buff_id, &"dirt", String(dirt_surface.get("surface_id", "")), "buff_gather_dirt"
	)
	_expect_true(gather_dirt.get("success", false), "Defensive Buff fixture must gather actual dirt through its one-Act action.")
	buff_session.simulation.advance_to(buff_session.simulation.get_action(String(gather_dirt.get("action_instance_id", ""))).final_effect_due_at_us)
	var buff := buff_session.simulation.start_verified_special_action(
		buff_id, buff_id, HadesFixture.make_defensive_buff_action_definition(), "buff_fixture"
	)
	_expect_true(buff.get("success", false), "Defensive Buff must start when the dirt prerequisite is authoritatively supplied.")
	buff_session.simulation.advance_to(buff_session.simulation.get_action(String(buff.get("action_instance_id", ""))).final_effect_due_at_us)
	_expect_equal(buff_session.simulation.get_effective_actor_combat_stat(buff_id, "nal"), 3, "Defensive Buff must add +2 NAL after two Acts.")
	_expect_equal(buff_session.get_actor_state(buff_id).resources.get("ap"), 9, "A free daily Defensive Buff must not spend AP.")
	_expect_equal(buff_session.get_actor_state(buff_id).ability_daily_remaining.get(String(HadesFixture.DEFENSIVE_BUFF_ACTION_ID)), 1, "Defensive Buff must consume one of two daily uses.")
	var duplicate_buff := buff_session.simulation.start_verified_special_action(
		buff_id, buff_id, HadesFixture.make_defensive_buff_action_definition(), "buff_duplicate"
	)
	_expect_equal(duplicate_buff.get("reason"), "timed_stat_effect_already_active", "Defensive Buff must not stack.")


func _test_rage_knockback_and_collision() -> void:
	var session := _ready_wave_session(32_313, false)
	var hades_id := _first_actor_with_prefix(session, "wave_3_hades_combat_follower_")
	for actor_id: String in session.get_targetable_enemy_ids():
		if String(actor_id) != String(hades_id):
			session.get_actor_state(StringName(actor_id)).current_hpc = 0
	session.simulation.apply_authoritative_position(hades_id, PLAYER_POSITION - Vector2i(1_000_000, 0), 0)
	session.simulation.set_actor_defense_state(Fixture.PLAYER_ID, &"unaware", PackedStringArray())
	var rage := session.simulation.start_verified_timed_stat_effect_action(hades_id, HadesFixture.make_rage_action_definition(), "knockback_rage")
	session.simulation.advance_to(session.simulation.get_action(String(rage.get("action_instance_id", ""))).final_effect_due_at_us)
	var called := session.simulation.start_verified_special_action(hades_id, Fixture.PLAYER_ID, HadesFixture.make_called_shot_action_definition(), "knockback_called", &"torso")
	session.simulation.advance_to(session.simulation.get_action(String(called.get("action_instance_id", ""))).final_effect_due_at_us)
	var start_position := session.get_actor_state(Fixture.PLAYER_ID).position_microfeet
	var attack := session.simulation.start_physical_attack(hades_id, Fixture.PLAYER_ID, HadesFixture.make_attack_definition(HitLocations.get_same_size_attack_profile()), "knockback_attack", &"torso", true)
	session.simulation.advance_to(session.simulation.get_action(String(attack.get("action_instance_id", ""))).final_effect_due_at_us)
	var attack_id := String(attack.get("attack_instance_id", ""))
	var defense := session.simulation.resolve_pending_defense_automatically(attack_id, "knockback_defense", session._make_dodge_environment(session.simulation.get_attack(attack_id)))
	_expect_true(defense.get("success", false), "Unaware knockback fixture must deterministically exhaust active defenses.")
	var damage := session.simulation.resolve_physical_damage(attack_id, "knockback_damage")
	_expect_true(damage.get("success", false) and int(damage.get("final_damage", 0)) > 0, "A qualifying Rage hit must resolve actual physical damage.")
	var end_position := session.get_actor_state(Fixture.PLAYER_ID).position_microfeet
	_expect_equal(roundi(Vector2(end_position - start_position).length()), 2_000_000, "A clear qualifying Rage hit must displace the target exactly two feet.")
	var damage_events := _events_for_source(session, &"physical_damage_resolved", hades_id)
	_expect_true(not damage_events.is_empty(), "A Rage hit must retain its authoritative damage calculation evidence.")
	if not damage_events.is_empty():
		_expect_equal(damage_events[-1].payload.get("strength_bonus"), 3, "Rage must change the applied Short Sword SB from 1 to 3 in the actual damage calculation.")
		_expect_true(EventPresenter.format_event(damage_events[-1]).contains("+3"), "FULL LOG must expose the Rage-adjusted SB in the damage calculation.")
	var knockback_events := _events_for_source(session, &"rage_knockback_resolved", hades_id)
	_expect_equal(knockback_events.size(), 1, "A qualifying Rage hit must record exactly one authoritative knockback result.")
	if not knockback_events.is_empty():
		_expect_true(EventPresenter.format_event(knockback_events[0]).contains("2.0 ft"), "FULL LOG must expose the resolved Rage knockback distance.")
	# The same authoritative battlefield resolver must collision-limit the source
	# displacement rather than allowing a target through the east boundary.
	session.simulation.apply_authoritative_position(Fixture.PLAYER_ID, Vector2i(45_500_000, 12_000_000), 0)
	session.simulation.apply_authoritative_position(hades_id, Vector2i(44_500_000, 12_000_000), 0)
	var collision_limited: Dictionary = session._resolve_rage_knockback(hades_id, Fixture.PLAYER_ID, 2_000_000)
	_expect_true(collision_limited.get("success", false) and collision_limited.get("blocked", false), "Rage knockback must report collision-limited displacement at a solid battlefield boundary.")
	_expect_true(session._battlefield.is_position_legal(Fixture.PLAYER_ID, collision_limited.get("position_microfeet", Vector2i.ZERO), session._actor_occupancy()).get("legal", false), "Collision-limited Rage destination must remain authoritative and legal.")


func _test_skelly_light_and_faith_responses() -> void:
	var session := _ready_wave_session(32_314, false)
	var skelly_id := _first_actor_with_prefix(session, "wave_3_common_skelly_")
	var skelly_state := session.get_actor_state(skelly_id)
	var before := int(skelly_state.current_hpc)
	_expect_true(session.simulation.register_verified_special_damage_definition(&"task32c_light_final_damage_fixture", &"light", "ITank Prime V3 p. 314 Skelly Light weakness; inert final-damage test boundary").get("success", false), "Light final-damage fixture must be source-registered before use.")
	_expect_true(session.simulation.register_verified_special_damage_definition(&"prime_v3_faith_blast", &"faith", "ITank Prime V3 pp. 249-250 Faith Blast target eligibility").get("success", false), "Faith Blast must be source-registered before use.")
	var light := session.simulation.apply_verified_special_damage(Fixture.PLAYER_ID, skelly_id, &"task32c_light_final_damage_fixture", &"light", 2, "light_fixture")
	_expect_true(light.get("success", false), "A source-verified Light Special damage result must be legal against a Skelly.")
	_expect_equal(light.get("final_damage"), 8, "Skelly Light weakness must multiply otherwise applicable damage by four.")
	_expect_equal(skelly_state.current_hpc, before - 8, "Light weakness must mutate authoritative Skelly HPC exactly once.")
	var faith := session.simulation.apply_verified_special_damage(Fixture.PLAYER_ID, skelly_id, &"prime_v3_faith_blast", &"faith", 1, "faith_fixture")
	_expect_true(faith.get("success", false), "A source-verified Faith damage result must be eligible against an undead Skelly.")
	var ordinary := session.simulation.apply_verified_special_damage(skelly_id, Fixture.PLAYER_ID, &"prime_v3_faith_blast", &"faith", 1, "faith_ordinary_fixture")
	_expect_equal(ordinary.get("reason"), "target_not_eligible_for_special_field", "Ordinary creatures must not become Faith-damage eligible.")


func _test_victory_reset_replay_and_two_client_convergence() -> void:
	var session := _ready_wave_session(32_304, true)
	var ids := session.get_targetable_enemy_ids()
	for index in range(ids.size() - 1):
		session.get_actor_state(StringName(ids[index])).current_hpc = 0
		session.evaluate_current_wave_victory()
		_expect_equal(session.get_arena_wave_state().get("state"), ArenaWaveStateMachine.STATE_ACTIVE, "Wave 3 cannot end while any required enemy lives.")
	session.get_actor_state(StringName(ids[-1])).current_hpc = 0
	session.advance_by(1)
	_expect_equal(session.get_arena_wave_state().get("state"), ArenaWaveStateMachine.STATE_BETWEEN_WAVE_DOWNTIME, "Wave 3 victory requires every Skelly and the follower defeated before safe downtime.")
	_expect_equal(session.get_encounter_state(), ArenaCombatSession.ENCOUNTER_BETWEEN_WAVE_DOWNTIME, "Wave 3 victory must stop combat without automatically beginning Wave 4.")

	var replay := _ready_wave_session(32_305, false)
	var before_events := _event_signature(replay)
	var before_state := replay.get_arena_wave_state()
	_expect_true(replay.reset_encounter(false).get("success", false), "Wave 3 reset must rebuild from the same seed.")
	_expect_equal(_event_signature(replay), before_events, "Wave 3 reset must reproduce authoritative event history.")
	_expect_equal(replay.get_arena_wave_state(), before_state, "Wave 3 reset must reproduce roster and lifecycle state.")

	var harness := TwoClientSyncHarness.new(32_306)
	var authority_session := ArenaCombatSession.new(32_306, harness.authority.simulation, Fixture.ENCOUNTER_WAVE_THREE_SKELLY_HADES)
	authority_session.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
	authority_session.set_opponent_behavior_enabled(true)
	_expect_true(authority_session.initialize_wave_three_skelly_hades(PLAYER_POSITION, ENEMY_POSITION, false).get("success", false), "External authority must initialize Wave 3.")
	harness.deliver_in_order(harness.authority.publish_current_events())
	_expect_true(harness.compare_clients().get("success", false), "Wave 3 event delivery must converge on both simulated clients.")
	_expect_equal(harness.authority.get_state_digest(), harness.client_a.get_state_digest(), "Wave 3 client digest must match authority.")
	_expect_true(authority_session.start_encounter().get("success", false), "Wave 3 authority must start for timed-effect convergence coverage.")
	authority_session.advance_by(5_000_000)
	var post_rage_envelopes := harness.authority.publish_current_events()
	_expect_true(not post_rage_envelopes.is_empty(), "Wave 3 Rage/movement coverage must publish new authoritative events.")
	harness.deliver_in_order(post_rage_envelopes)
	_expect_true(harness.compare_clients().get("success", false), "Wave 3 Rage and movement events must preserve two-client convergence.")
	_expect_equal(harness.authority.get_state_digest(), harness.client_b.get_state_digest(), "Post-Rage client digest must match authority.")


func _test_maximum_wave_frame_partition_and_navigation() -> void:
	var seed := _find_seed_for_skelly_count(2)
	_expect_true(seed > 0, "A deterministic seed for two Skellys must be discoverable.")
	if seed <= 0:
		return
	print("METRIC: Task32B maximum Wave 3 seed=%d enemies=3" % seed)
	var coarse := _ready_wave_session(seed, true)
	var partitioned := _ready_wave_session(seed, true)
	coarse.advance_by(5_000_000)
	for unused in range(50):
		partitioned.advance_by(100_000)
	_expect_equal(_event_signature(partitioned), _event_signature(coarse), "Maximum Wave 3 behavior must be frame-partition invariant.")
	_expect_equal(partitioned.simulation.get_state_snapshot(), coarse.simulation.get_state_snapshot(), "Maximum Wave 3 authoritative state must be deterministic.")
	for rebuild_count: Variant in partitioned.get_goblin_path_rebuild_counts_for_testing().values():
		_expect_true(int(rebuild_count) < 100, "Three-enemy Wave 3 pursuit must avoid pathological path rebuilding.")


func _test_launcher_and_presentation() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		_failures.append("SceneTree unavailable for Wave 3 launcher verification.")
		return
	var packed: PackedScene = load("res://scenes/test_arena.tscn")
	var scene := packed.instantiate()
	tree.root.add_child(scene)
	var controller := scene.get_node("CombatController") as ArenaCombatController
	var selected := controller.select_encounter_fixture_for_testing(Fixture.ENCOUNTER_WAVE_THREE_SKELLY_HADES)
	_expect_true(selected.get("success", false), "Wave 3 must be selectable through the existing encounter control.")
	var session := controller.get_combat_session_for_testing()
	_expect_equal(session.get_arena_wave_state().get("current_wave_id"), "wave_3", "Launcher selection must instantiate Wave 3.")
	for actor_id: String in session.get_targetable_enemy_ids():
		var visual := controller._get_enemy_visual(StringName(actor_id))
		_expect_true(visual != null and visual.visible, "Every living Wave 3 enemy needs a visible selectable placeholder.")
		if visual != null:
			var glyph := visual.get_node_or_null("Glyph") as Label
			var expected := "H" if actor_id.begins_with("wave_3_hades_") else "K"
			_expect_equal(glyph.text if glyph != null else "", expected, "Wave 3 placeholders must distinguish Skellys from the Hades follower.")
	_expect_equal(ArenaCombatController.compact_actor_name(&"wave_3_common_skelly_02"), "SKELLY 2", "Wave 3 Skelly IDs need concise names.")
	_expect_equal(ArenaCombatController.compact_actor_name(&"wave_3_hades_combat_follower_01"), "HADES FOLLOWER", "The fixed follower needs a concise name.")
	tree.root.remove_child(scene)
	scene.free()


func _declare_skelly_attack_direct(session: ArenaCombatSession, skelly_id: StringName, expected_at: int) -> Dictionary:
	var target_position := PLAYER_POSITION
	session.simulation.apply_authoritative_position(skelly_id, target_position + Vector2i(1_000_000, 0), 180_000)
	var attack := CommonSkellyFixture.make_attack_definition(HitLocations.get_same_size_attack_profile())
	var result := session.simulation.start_physical_attack(skelly_id, Fixture.PLAYER_ID, attack, "natural_at_%d" % expected_at, &"torso", true)
	_expect_true(result.get("success", false), "Test-only Skelly attack must declare legally.")
	if not result.get("success", false):
		return {}
	var action_id := String(result.get("action_instance_id", ""))
	var action := session.simulation.get_action(action_id)
	var declarations := _events_for_source(session, &"physical_attack_declared", skelly_id)
	var declaration_action_ids := {}
	var attack_ids := {}
	for event: CombatEvent in declarations:
		declaration_action_ids[String(event.payload.get("action_instance_id", ""))] = true
		attack_ids[String(event.payload.get("attack_instance_id", ""))] = true
	session.simulation.advance_to(action.final_effect_due_at_us)
	var accuracy := _events_for_source(session, &"physical_attack_accuracy_resolved", skelly_id)
	_expect_equal(declaration_action_ids.size(), 1, "All natural strikes in one Act must share one action instance.")
	_expect_equal(attack_ids.size(), 2, "Each natural strike must retain an independent attack instance.")
	return {
		"declaration_count": declarations.size(),
		"duration_us": action.final_effect_due_at_us - action.started_at_us,
		"accuracy_count": accuracy.size(),
	}


func _ready_wave_session(seed: int, start_active: bool) -> ArenaCombatSession:
	var session := ArenaCombatSession.new(seed, null, Fixture.ENCOUNTER_WAVE_THREE_SKELLY_HADES)
	session.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
	session.set_opponent_behavior_enabled(true)
	_expect_true(session.initialize_wave_three_skelly_hades(PLAYER_POSITION, ENEMY_POSITION, start_active).get("success", false), "Wave 3 fixture must initialize.")
	return session


func _find_seed_for_skelly_count(expected_count: int) -> int:
	for seed in range(1, 256):
		var session := _ready_wave_session(seed, false)
		if session.get_targetable_enemy_ids().size() == expected_count + 1:
			return seed
	return -1


func _first_actor_with_prefix(session: ArenaCombatSession, prefix: String) -> StringName:
	for actor_id: String in session.get_targetable_enemy_ids():
		if actor_id.begins_with(prefix):
			return StringName(actor_id)
	return &""


func _roster_count(roster: Array, creature_id: String) -> int:
	return int(_roster_entry(roster, creature_id).get("resolved_count", 0))


func _roster_entry(roster: Array, creature_id: String) -> Dictionary:
	for entry: Dictionary in roster:
		if String(entry.get("creature_id", "")) == creature_id:
			return entry
	return {}


func _events_for_source(session: ArenaCombatSession, event_type: StringName, actor_id: StringName) -> Array[CombatEvent]:
	var result: Array[CombatEvent] = []
	for event: CombatEvent in session.get_resolved_events():
		if event.event_type == event_type and event.source_actor_id == actor_id:
			result.append(event)
	return result


func _event_signature(session: ArenaCombatSession) -> Array[Dictionary]:
	var signature: Array[Dictionary] = []
	for event: CombatEvent in session.get_resolved_events():
		signature.append(event.to_dictionary())
	return signature


func _expect_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s Expected %s, got %s." % [message, str(expected), str(actual)])
