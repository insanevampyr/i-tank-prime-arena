class_name PrimeV3LevelCatalog
extends RefCounted

# Printed pp. 99-101, rows LVL 2..20. Preserve irregular printed values verbatim.
const TABLES := [
[[82,84,86,88,91],[180,185,189,194,200],[396,407,416,427,440],[871,895,915,939,968],[1916,1969,2013,2066,2130],[4215,4332,4429,4545,4686],[9273,9530,9744,9999,10309],[20401,20966,21437,21998,22680],[44882,46125,47161,48396,49896],[60591,62269,63667,65335,67360],[81798,84063,85950,88202,90936],[110427,113485,116032,119073,122764],[149079,153205,156643,160749,165731],[201253,206827,211468,217011,223737],[241504,248192,253762,260413,268484],[289805,297830,304514,312496,322181],[347766,357396,365417,374995,386617],[417319,428875,438500,449994,463940],[500783,514650,526200,539993,556728]],
[[93,95,97,99,102],[205,209,213,218,224],[451,460,469,480,493],[992,1012,1032,1056,1085],[2182,2226,2270,2323,2387],[4800,4897,4994,5111,5251],[10560,10773,10987,11244,11552],[23232,23701,24171,24737,25414],[51110,52142,53176,54421,55911],[68998,70392,71788,73468,75480],[93147,95092,96914,99182,101898],[125748,128289,130834,133896,137562],[169760,173190,176626,180760,185709],[229176,233806,238445,244026,250707],[275011,280567,286134,292831,300848],[330013,336680,343361,351397,361018],[396016,404016,412033,421676,433222],[475219,484819,494440,506011,519866],[570263,581783,593328,607213,623839]],
[[105,109,112],[231,240,246],[508,528,541],[1118,1162,1190],[2460,2556,2618],[5412,5623,5760],[11906,12371,12672],[26193,21216,27878],[57625,59875,61332],[77794,80831,82798],[105022,109122,111777],[141780,147315,150899],[191403,198875,203714],[258394,268481,275014],[310073,322177,330017],[372088,386612,393020],[446506,463934,475224],[535807,556721,570269],[642968,668065,684323]]]
const HIT_DICE := [[8,0],[6,0],[4,0],[4,0],[8,0],[6,1],[6,0],[6,0],[4,1],[4,1],[4,0],[4,0],[4,0]]
const BASE_TYPES := {"Barbarian":1,"Fighter":1,"Monk":1,"Assassin":2,"Archer":2,"Cleric":2,"Ranger":2,"Rogue":2,"Conjurer":3,"Sorcerer":3,"Druid":4,"Mage":4,"Shaman":4}
const DUAL_TYPES := {"1:1":5,"1:2":6,"1:3":7,"1:4":8,"2:2":8,"2:3":9,"2:4":10,"3:3":11,"3:4":12,"4:4":13}

static func threshold(exp_type: int, level: int) -> Variant:
	if exp_type < 1 or exp_type > 13 or level < 1 or level > 20: return null
	if level == 1: return 0
	var group := 0 if exp_type <= 5 else (1 if exp_type <= 10 else 2)
	return TABLES[group][level-2][exp_type - [1,6,11][group]]

static func type_for_classes(classes: Array) -> int:
	if classes.is_empty() or classes.size() > 2: return 0
	var types: Array[int] = []
	for name: String in classes:
		if not BASE_TYPES.has(name): return 0
		types.append(BASE_TYPES[name])
	types.sort()
	return types[0] if types.size() == 1 else int(DUAL_TYPES.get("%d:%d" % [types[0],types[1]],0))

static func level_for(exp_type: int, expm: int) -> int:
	if threshold(exp_type, 1) == null or expm < 0: return 0
	var level := 1
	while level < 20 and expm >= int(threshold(exp_type, level+1)): level += 1
	return level

static func validate(policy: Dictionary, actor: CombatActorDefinition) -> String:
	var exp_type := int(policy.get("exp_type",0))
	var declared: Array = []
	for name: String in actor.class_names:
		declared.append((policy.get("class_families",{}) as Dictionary).get(name,name))
	if declared != policy.get("classes",[]): return "progression_class_identity_unverified"
	if type_for_classes(policy.get("classes",[])) != exp_type or exp_type == 0: return "progression_class_type_unverified"
	if String(policy.get("resource_mode","")) not in ["mana","ability"]: return "progression_resource_policy_unverified"
	if not actor.combat_stats.has("hpb"): return "progression_hpb_unverified"
	# No invented floor for a potentially nonpositive HD+HPB result.
	if 1 + int(HIT_DICE[exp_type-1][1]) + int(actor.combat_stats.hpb) <= 0: return "progression_nonpositive_growth_rule_unverified"
	if actor.level != level_for(exp_type,int(policy.get("initial_expm",-1))): return "progression_initial_level_unverified"
	if int(policy.get("initial_expc",-1)) < 0 or int(policy.initial_expc) > int(policy.initial_expm): return "progression_initial_xp_unverified"
	if policy.resource_mode == "mana" and (not actor.resource_maxima.has("mana") or not actor.attributes.has("wis")): return "progression_mana_unverified"
	if actor.level == 1 and actor.progression_hpm_increase == 0:
		if policy.resource_mode == "mana" and (not policy.has("initial_wis") or int(actor.resource_maxima.mana) != int(policy.initial_wis)+10): return "progression_initial_mana_or_exception_unverified"
		if policy.resource_mode == "ability" and int(actor.resource_maxima.get("ap",0)) != 0: return "progression_initial_ap_or_exception_unverified"
	return ""
