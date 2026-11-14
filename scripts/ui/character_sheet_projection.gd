class_name CharacterSheetProjection
extends RefCounted

# Read-only presentation adapter. Never applies a chart reference to an actor.
const Rules = preload("res://scripts/combat/prime_v3_attribute_engine.gd")
const References = preload("res://scripts/combat/character_attribute_projection.gd")
const EXTRA_FIELDS := {"MR/H":"mana_recovery_per_hour","S#":"skill_number","SCM":"scm","MIUR":"miur","MNS":"mns","MRF":"mrf","RCL":"rcl","AP":"ap_persuasion","KP":"kp","RR/G":"rerolls_per_game","ToF":"twists_of_fate"}

static func capture(session: ArenaCombatSession) -> Dictionary:
	if session == null: return {"success":false,"reason":"Character information is unavailable."}
	var actor := session.simulation.get_actor_definition(&"player")
	var state := session.get_actor_state(&"player")
	if actor == null or state == null: return {"success":false,"reason":"Character information is unavailable."}
	var source := actor.source_character_definition
	var mode: String = actor.progression_policy.get("resource_mode", "")
	var effective := {}
	for field: String in References.FIELDS.values() + ["sr","tb"]:
		var value: Variant = session.simulation.get_effective_actor_combat_stat(actor.actor_id,field)
		if typeof(value) == TYPE_INT: effective[field] = value
	var references := References.project_actor(actor,state,mode,effective) if mode in ["mana","regular"] else {}
	var recorded := _authored_record(source)
	var purchases: Array = session.get_reward_state().get("purchase_records",[])
	var balance := BalanceActorProfile.capture(source,actor,state,session.simulation.clock.get_elapsed_us(),purchases)
	var result := {"success":true,"name":actor.display_name,"mode":mode,"subtitle":"",
		"primaries":[],"derived":[],"resistances":[],"resources":[],"effects":[],
		"skills":[],"specials":[],"equipment":[],"profile":[],"purchases":purchases.duplicate(true),
		"combat_active":session.is_encounter_active(),"references_available":references.get("success",false)}
	var race: String = source.race_name if source != null else ""
	var level: Variant = _level(state.progression.get("level",actor.level))
	result.subtitle = "%s | %s | %s" % [race if not race.is_empty() else "Race not recorded", ", ".join(actor.class_names) if not actor.class_names.is_empty() else "Class not recorded","Level not available" if level == null else "Level %s" % level]
	for id: String in Rules.PRIMARY_NAMES:
		var key := id.to_lower()
		var permanent: Variant = _integer(actor.attributes.get(key))
		var current: Variant = permanent
		var modified := false
		for effect: Dictionary in state.timed_stat_effects.values():
			if effect.get("stat_modifiers",{}).has(key): modified = true
		if modified: current = balance.profile.effective_dex if id == "DEX" and balance.success else null
		result.primaries.append(_stat(id,Rules.PRIMARY_NAMES[id],_integer(source.attributes.get(key)) if source != null else null,permanent,current,id))
		var descriptors := Rules.derived_descriptors(id,mode if mode in ["mana","regular"] else "mana")
		for descriptor: Dictionary in descriptors.entries:
			var abbreviation: String = descriptor.abbreviation
			# Unknown resource mode must not pick a Mana/Ability-specific statistic.
			if mode not in ["mana","regular"] and abbreviation in ["MR/H","MNS","MRF"]: continue
			var field: String = References.FIELDS.get(abbreviation,EXTRA_FIELDS.get(abbreviation,""))
			var row := _stat(abbreviation,descriptor.name,_integer(source.combat_stats.get(field)) if source != null else null,_integer(actor.get_base_combat_stat(field)),_integer(session.simulation.get_effective_actor_combat_stat(actor.actor_id,field)),id)
			row["equipment"] = actor.equipment_stat_modifiers.get(field)
			result.derived.append(row)
	for id: String in ["SR","TB"]:
		var field := id.to_lower()
		result.resistances.append(_stat(id,Rules.resistance_descriptor(id).name,_integer(source.combat_stats.get(field)) if source != null else null,_integer(actor.get_base_combat_stat(field)),_integer(session.simulation.get_effective_actor_combat_stat(actor.actor_id,field)),"RESISTANCES"))
	result.resources.append({"id":"HPC","name":"Health (HPC / HPM)","current":state.current_hpc,"maximum":actor.get_combat_stat("hpm")})
	var keys: Array = actor.resource_maxima.keys()
	for key: String in state.resources:
		if not keys.has(key): keys.append(key)
	keys.sort()
	for key: String in keys:
		result.resources.append({"id":"AP_RESOURCE" if key == "ap" else key.to_upper(),"name":{"mana":"Mana","ap":"Ability Points","blood":"Blood"}.get(key,key.capitalize()),"current":_integer(state.resources.get(key)),"maximum":_integer(actor.resource_maxima.get(key))})
	for condition: String in state.conditions: result.effects.append({"title":condition.replace("_"," ").capitalize(),"status":"CURRENT CONDITION","details":[]})
	var effect_ids: Array = state.timed_stat_effects.keys()
	effect_ids.sort()
	for key: String in effect_ids:
		var effect: Dictionary = state.timed_stat_effects[key]
		var details: Array = []
		for stat: String in effect.get("stat_modifiers",{}): details.append("%s modifier: %s" % [stat.to_upper(),effect.stat_modifiers[stat]])
		if effect.has("expires_at_us"): details.append("Remaining encounter time: %.1f s" % (maxi(0,int(effect.expires_at_us)-session.simulation.clock.get_elapsed_us())/1000000.0))
		details.append("Source: "+String(effect.get("source_ref","Not recorded")))
		result.effects.append({"title":key.replace("_"," ").capitalize(),"status":"TEMPORARY EFFECT","details":details})
	for key: String in state.persistent_damage_shields:
		var shield: Dictionary = state.persistent_damage_shields[key]
		result.effects.append({"title":key.replace("_"," ").capitalize(),"status":"ACTIVE PROTECTION","details":["Protective points remaining: %s" % shield.get("capacity","Not available")]})
	_skills(result,source,recorded,balance)
	_specials(result,session,actor,state,source,recorded)
	_equipment(result,session,actor,state)
	_profile(result,session,actor,state,source,recorded)
	return result

static func _stat(id: String, title: String, original: Variant, permanent: Variant, effective: Variant, group: String) -> Dictionary:
	return {"id":id,"name":title,"original":original,"permanent":permanent,"effective":effective,"group":group}

static func _integer(value: Variant) -> Variant:
	return value if typeof(value) == TYPE_INT else null

static func _level(value: Variant) -> Variant:
	# Negative levels are internal unavailable sentinels, not character levels.
	return value if typeof(value) == TYPE_INT and value >= 0 else null

static func _authored_record(source: CombatCharacterDefinitionResource) -> Dictionary:
	if source == null: return {}
	# Only definition-linked structured project records; never follow save input,
	# arbitrary paths, binary owner documents or external character files.
	for reference: String in source.source_refs:
		if not reference.begins_with("assets/Character Choices/") or not reference.ends_with(".json") or reference.contains(".."): continue
		var path := "res://"+reference
		if not FileAccess.file_exists(path): continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary and parsed.get("schema") == "itank-prime-arena-character-v1" and parsed.get("character") is Dictionary and parsed.character.get("name") == source.display_name: return parsed
	return {}

static func _skills(result: Dictionary, source: CombatCharacterDefinitionResource, recorded: Dictionary, balance: Dictionary) -> void:
	var skills: Array = recorded.get("skills",[]).duplicate(true)
	var seen := {}
	for skill: Dictionary in skills: seen[String(skill.get("name","")).to_lower()] = true
	if source != null:
		for key: String in source.proficiencies:
			if not seen.has(key): skills.append({"name":key.capitalize(),"investment":source.proficiencies[key].get("investments"),"attribute":"DEX" if key == "balance" else null})
	for skill: Dictionary in skills:
		var title: String = skill.get("name","Unnamed skill")
		var details: Array = ["Governing attribute: "+_text(skill.get("attribute")),"Skill Investments: "+_text(skill.get("investment"))]
		var status := "RECORDED SKILL | CHECK UNAVAILABLE"
		if title.to_lower() == "balance":
			if balance.success:
				# Pure evaluator query for its target; never roll or publish a check.
				var reference := BalanceSkillCheck.resolve(balance.profile,1)
				status = "VERIFIED CHECK"
				details = ["Training: "+String(balance.profile.training),"Skill Investments: %s | SCM %s | RB %s" % [balance.profile.investments,balance.profile.scm,balance.profile.rb],"Current effective DEX: %s | Check target: %s" % [balance.profile.effective_dex,reference.target],"Balance is not automatic at three investments."]
			else:
				status = "KNOWN | CHECK CURRENTLY UNAVAILABLE"
				details.append("Current check unavailable; no roll was performed.")
		elif title.to_lower() == "running" and source != null and source.running_profile.get("running_skill_investment") == 3:
			status = "VERIFIED AUTOMATIC RUNNING"
		elif skill.has("modifier"): details.append("Recorded skill modifier: %s (current check unavailable)" % skill.modifier)
		result.skills.append({"title":title,"status":status,"details":details})
	for key: String in ["natural_abilities","automatic_skills","languages"]:
		result.skills.append({"title":key.replace("_"," ").capitalize(),"status":"RECORDED PROFICIENCY" if recorded.has(key) else "NOT AVAILABLE","details":_record_list(recorded.get(key))})

static func _specials(result: Dictionary, session: ArenaCombatSession, actor: CombatActorDefinition, state: CombatActorState, source: CombatCharacterDefinitionResource, recorded: Dictionary) -> void:
	if recorded.has("home_special_fields"):
		result.specials.append({"title":"Home Special Fields","status":"RECORDED FIELD ACCESS","details":_record_list(recorded.home_special_fields)+["A field does not grant unrecorded Specials."]})
	for special: Dictionary in recorded.get("learned_specials",[]):
		var title: String = special.get("name","Unnamed Special")
		var implemented: bool = source != null and source.definition_id == &"vaelis_thorn" and title in ["Force Bolt","Force Shield"]
		var status := "KNOWN | NOT IMPLEMENTED"
		var details: Array = ["Field: %s | Level: %s" % [special.get("field","Not recorded"),special.get("level","Not recorded")]]
		if implemented:
			var bolt := title == "Force Bolt"
			var cost: int = VaelisForceFixture.FORCE_BOLT_MANA_COST if bolt else VaelisForceFixture.FORCE_SHIELD_MANA_COST
			status = "KNOWN | TARGET AND TIMING REQUIRED"
			if not session.is_encounter_active(): status = "KNOWN | COMBAT USE UNAVAILABLE"
			elif state.current_hpc == null or state.current_hpc <= 0: status = "KNOWN | INCAPACITATED"
			elif state.resources.get("mana",0) < cost: status = "KNOWN | INSUFFICIENT MANA"
			details.append("Mana %s | %s | %s" % [cost,"NAC, zero ordinary Acts" if bolt else "One Act","10 ft" if bolt else "Self or touch"])
			details.append("One d6 Force damage; two-foot knockback. Requires SS then ACC and a legal target. Applicable critical damage factors are resolved by combat." if bolt else "20 protective points after applicable protection. Non-stacking; persists until depleted or canceled. Qualifying attacker contact can cause two-foot knockback.")
			details.append("Availability is checked again when used, including legal target, timing and resources.")
			details.append(VaelisForceFixture.SOURCE_REF)
		else:
			details.append("Recorded requirements: Mana %s; casting %s; range %s" % [special.get("mana_cost","Not recorded"),special.get("cast_time","Not recorded"),special.get("range","Not recorded")])
			details.append(String(special.get("description","Effect not verified for Arena.")))
		result.specials.append({"title":title,"status":status,"details":details})
	if source != null:
		for key: String in source.ability_access:
			result.specials.append({"title":key.replace("_"," ").capitalize()+" field","status":"SOURCE-RECORDED ACCESS","details":["Recorded access: "+_text(source.ability_access[key]),"Individual ability descriptions are not yet supplied to this view."]})
	for key: String in state.ability_daily_maxima:
		result.specials.append({"title":key.replace("_"," ").capitalize(),"status":"KNOWN DAILY ALLOWANCE","details":["Remaining %s / %s" % [state.ability_daily_remaining.get(key,"Not available"),state.ability_daily_maxima[key]],"Additional ability details are not available in this view."]})

static func _equipment(result: Dictionary, session: ArenaCombatSession, actor: CombatActorDefinition, state: CombatActorState) -> void:
	var catalog := CombatDefinitionCatalog.load_default_fixture_catalog()
	for item: Dictionary in session.get_player_inventory_entries():
		var id := StringName(item.definition_id)
		if id == &"prime_v3_gold":
			result.equipment.append({"entry_id":String(id),"title":"Gold","status":"BALANCE | %s GOLD" % item.quantity,"details":["Total carried Gold from character inventory; includes collected drops."],"category":"currency"})
			continue
		var details: Array = [String(item.get("requirements","Requirements not available"))]
		if not PrimeV3InventoryCatalog.get_verified_consumable(String(id)).is_empty(): details.append("Carried potion use: one Act to retrieve, then one Act to drink; a free hand is required.")
		var weapon := catalog.get_weapon(id)
		var armor := catalog.get_armor(id)
		var shield := catalog.get_shield(id)
		if weapon != null:
			if weapon.damage_dice_count > 0 and weapon.damage_die_sides > 0:
				details.append("Damage: %sd%s%+d%s | %s" % [weapon.damage_dice_count,weapon.damage_die_sides,weapon.fixed_damage_bonus," + SB" if weapon.strength_bonus_eligible else "",", ".join(weapon.damage_types)])
			else: details.append("Damage: not verified")
			details.append("Block target: %s | Strikes per Act: %s | Current handling: %s" % [show_value(weapon.block_target if weapon.block_target >= 0 else null),weapon.strikes_per_act,item.get("weapon_state","Not equipped")])
			if weapon.enchantment_bonus > 0: details.append("Recorded enchantment: +%s | Damage treatment: %s" % [weapon.enchantment_bonus,String(weapon.enchantment_damage_policy).replace("_"," ")])
			if not weapon.blocked_capabilities.is_empty(): details.append("Unavailable: "+", ".join(weapon.blocked_capabilities).replace("_"," "))
		if armor != null:
			details.append("Locations: "+", ".join(armor.covered_locations))
			details.append("TAL by damage type: "+_text(armor.tal_by_damage_type))
			details.append("Equipment modifiers: MR %s | DT %s | DP %s" % [armor.mr_penalty,armor.dt_penalty,armor.projectile_dodge_penalty])
		if shield != null:
			var defense := session.simulation.get_defense_profile(actor.actor_id)
			var remaining: Variant = defense.shield_block.current_shp if defense != null and defense.shield_block != null and defense.shield_block.equipment_ref == id else null
			details.append("SHP %s / %s | Block target %s" % [show_value(remaining),shield.maximum_shp,shield.block_target])
		if item.get("magical",false): details.append("Magical item | MIUR: %s. No item-use permission is inferred by this sheet." % show_value(actor.get_combat_stat("miur")))
		if not item.get("blocked_reason","").is_empty(): details.append("Capability: "+String(item.blocked_reason).replace("_"," "))
		# The existing inventory query returns one aggregate entry per definition.
		result.equipment.append({"entry_id":String(id),"title":item.display_name,"status":"%s | CARRIED %s" % ["EQUIPPED" if item.equipped else "INVENTORY",item.quantity],"details":details,"category":item.category})
	if result.equipment.is_empty(): result.equipment.append({"title":"Equipment records","status":"NOT AVAILABLE","details":["No verified belongings are supplied for this character."]})

static func _profile(result: Dictionary, session: ArenaCombatSession, actor: CombatActorDefinition, state: CombatActorState, source: CombatCharacterDefinitionResource, recorded: Dictionary) -> void:
	var person: Dictionary = recorded.get("character",{})
	var rewards := session.get_reward_state()
	result.profile.append({"title":"Character identity","rows":[["Name",actor.display_name],["Race",source.race_name if source != null and not source.race_name.is_empty() else null],["Class",", ".join(actor.class_names) if not actor.class_names.is_empty() else null],["Character type",{"mana":"Mana User","regular":"Ability User"}.get(result.mode,"Not available")],["Size",String(actor.size_category).capitalize()],["Religion",person.get("religion")],["Level",_level(state.progression.get("level",actor.level))],["EXP Type",actor.progression_policy.get("exp_type")],["EXPM",state.progression.get("expm")],["EXPC",state.progression.get("expc",rewards.get("unspent_xp"))]]})
	var rows: Array = []
	for key: String in ["player","campaign","age","sex","eyes","hair","height","weight_lb","outlook","home","job","title","description"]: rows.append([key.replace("_"," ").capitalize(),person.get(key)])
	result.profile.append({"title":"Personal details | authored record","rows":rows})
	for key: String in ["backgrounds","drawbacks","fears","languages"]: result.profile.append({"title":key.capitalize(),"rows":[["Recorded", "\n".join(_record_list(recorded.get(key)))]]})
	var service := session._playable_persistence
	result.profile.append({"title":"Character progress","rows":[["Profile",service.profile_id if service != null else "Nonpersistent fixture"],["Saved generation",service.generation if service != null else null],["Namespace", "Legacy DEV profile" if session.get_reward_mode() == "dev_normal" else ("TEST | no rewards" if session.get_reward_mode() == "test" else "NORMAL")],["Run XP policy",session.get_run_reward_policy().get("xp_multiplier")]]})

static func _record_list(value: Variant) -> Array:
	if not value is Array: return ["Not available"]
	if value.is_empty(): return ["None recorded"]
	var result: Array = []
	for entry: Variant in value: result.append(_text(entry))
	return result

static func _text(value: Variant) -> String:
	if value == null: return "Not recorded"
	if value is Dictionary:
		var parts := PackedStringArray()
		for key: Variant in value: parts.append("%s: %s" % [String(key).replace("_"," "),str(value[key])])
		return "; ".join(parts)
	return str(value)

static func show_value(value: Variant) -> String:
	return "--" if value == null else str(value)
