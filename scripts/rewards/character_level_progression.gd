class_name CharacterLevelProgression
extends RefCounted

static func apply_award(sim: CombatSimulation, actor_id: StringName, award_id: String, xp: int, earned: int, spent: int) -> Dictionary:
	var actor := sim.get_actor_definition(actor_id)
	var state := sim.get_actor_state(actor_id)
	if actor == null or state == null: return _failure("unknown_actor")
	var policy := actor.progression_policy
	var reason := PrimeV3LevelCatalog.validate(policy, actor)
	if not reason.is_empty(): return _failure(reason)
	var previous := state.progression
	if award_id.is_empty() or xp < 0 or earned < 0 or spent < 0 or spent > earned: return _failure("invalid_progression_award")
	if (previous.get("award_ids",[]) as Array).has(award_id): return _failure("duplicate_progression_award")
	if earned != int(previous.get("run_earned_xp",0)) + xp: return _failure("progression_ledger_discontinuity")
	if spent != int(previous.get("run_spent_xp",0)): return _failure("progression_purchase_discontinuity")
	var exp_type := int(policy.exp_type)
	var before_expm := int(policy.initial_expm) + int(previous.get("run_earned_xp",0))
	var expm := int(policy.initial_expm) + earned
	var level := int(previous.get("level",actor.level))
	var target_level := PrimeV3LevelCatalog.level_for(exp_type,expm)
	if level > target_level: return _failure("progression_level_discontinuity")
	var next := previous.duplicate(true)
	if next.is_empty():
		next = {"exp_type":exp_type,"level":level,"award_ids":[],"history":[],"base_hpm":actor.get_combat_stat("hpm"),"base_resource_maxima":actor.resource_maxima.duplicate(true)}
	next["expm"] = expm
	next["expc"] = int(policy.initial_expc) + earned - spent
	next["run_earned_xp"] = earned
	next["run_spent_xp"] = spent
	next.award_ids.append(award_id)
	for gained_level in range(level+1,target_level+1):
		var die := int(PrimeV3LevelCatalog.HIT_DICE[exp_type-1][0])
		var flat := int(PrimeV3LevelCatalog.HIT_DICE[exp_type-1][1])
		var roll := sim.roll_int(1,die)
		var hpb := int(actor.combat_stats.hpb)
		var increase := roll + flat + hpb
		var hpm_before := int(actor.get_combat_stat("hpm"))
		actor.progression_hpm_increase += increase
		actor.apply_equipment_stat_modifiers(actor.equipment_stat_modifiers)
		var resource := "mana" if policy.resource_mode == "mana" else "ap"
		var maximum_before := int(actor.resource_maxima.get(resource,0))
		var wisdom := int(actor.attributes.get("wis",0))
		var resource_gain := int(wisdom / 2) + 5 if resource == "mana" else 1
		actor.resource_maxima[resource] = maximum_before + resource_gain
		if not state.resources.has(resource): state.resources[resource] = 0
		var record := {"actor_id":String(actor_id),"award_id":award_id,"exp_type":exp_type,
			"prior_expm":before_expm,"expm":expm,"expc":next.expc,"spent_xp":spent,
			"prior_level":gained_level-1,"level":gained_level,"threshold":PrimeV3LevelCatalog.threshold(exp_type,gained_level),
			"hit_die_sides":die,"die_flat_bonus":flat,"roll":roll,"rng_draw_index":sim.random.get_draw_count(),"hpb":hpb,"hpm_increase":increase,
			"hpm_before":hpm_before,"hpm_after":actor.get_combat_stat("hpm"),"hpc_before":state.current_hpc,"hpc_after":state.current_hpc,
			"resource":resource,"wisdom":wisdom,"maximum_before":maximum_before,"maximum_increase":resource_gain,"maximum_after":actor.resource_maxima[resource],
			"current_resource_before":state.resources[resource],"current_resource_after":state.resources[resource],
			"ability_points_granted":1 if resource == "ap" else 0,"separate_flexible_uses_granted":0}
		next.level = gained_level
		next.history.append(record.duplicate(true))
		state.progression = next.duplicate(true)
		state.revision += 1
		sim.record_reward_event(&"reward_character_level_gained",actor_id,actor_id,record,award_id)
	state.progression = next
	state.revision += 1
	return {"success":true,"level":next.level,"levels_gained":target_level-level}

static func _failure(reason: String) -> Dictionary:
	return {"success":false,"reason":reason}
