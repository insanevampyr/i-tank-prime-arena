class_name PrimeV3AttributeEngine
extends RefCounted

# Dormant rules queries only. No actor, session, RNG, storage or purchase calls.
const Tables = preload("res://scripts/combat/prime_v3_attribute_tables.gd")
const PRIMARY_NAMES := {
	"STR":"Strength", "END":"Endurance", "SPD":"Speed", "DEX":"Dexterity",
	"WIS":"Wisdom", "INT":"Intelligence", "WIT":"Wits", "MAN":"Mannerisms",
	"LUK":"Luck", "APP":"Appearance",
}
const DERIVED_NAMES := {
	"SB":"Strength Bonus", "PPG":"Push, Pull & Grip", "MWC":"Max Weight Capacity",
	"NAL":"Natural Armor Level", "PS":"Physical Soak", "HPB":"Hit Point Bonus",
	"MR":"Movement Rate", "AT":"Action Total", "DT":"Dodge Touch",
	"DP":"Dodge Projectile", "ACC":"Accuracy", "SS":"Special Success",
	"MSL":"Max Special Level", "MR/H":"Mana Recovery per Hour", "S#":"Skill Number",
	"SCM":"Skill Check Modifier", "MIUR":"Magic Item Use Rating", "INIT":"Initiative",
	"MNS":"Max Number of Specials", "MRF":"Max Regular Fields", "RCL":"Resist Control Loss",
	"AP":"Aggressive Persuasion", "KP":"Kindly Persuasion", "RB":"Roll Bonus",
	"RR/G":"Re-Rolls per Game", "ToF":"Twists of Fate", "PAR":"Personal Appearance Rating",
	"CHA":"Charisma",
}
const COMPONENTS := {
	"STR":["SB","PPG","MWC"], "END":["NAL","PS","HPB"], "SPD":["MR","AT"],
	"DEX":["ACC"], "INT":["S#","SCM","MIUR"], "LUK":["RB","RR/G","ToF"],
	"APP":["PAR","CHA"], "MAN":["AP","KP"],
}
const DEFINITION_PAGES := {"STR":19,"END":19,"SPD":19,"DEX":20,"WIS":20,"INT":21,"WIT":21,"MAN":22,"LUK":23,"APP":24}

static func primary_descriptor(primary: String) -> Dictionary:
	if not PRIMARY_NAMES.has(primary): return _fail("unknown_primary_attribute")
	return {"success":true,"abbreviation":primary,"name":PRIMARY_NAMES[primary],
		"category":"primary","definition_page":DEFINITION_PAGES[primary],
		"minimum_chart_score":0,"maximum_chart_score":35,"grants_eligibility":false}

static func derived_descriptors(primary: String, mode: String) -> Dictionary:
	if not PRIMARY_NAMES.has(primary): return _fail("unknown_primary_attribute")
	if mode not in ["mana","regular"]: return _fail("unknown_chart_mode")
	var ids: Array = _components(primary,mode).duplicate()
	if primary == "DEX": ids = ["DT","DP","ACC"]
	var entries: Array[Dictionary] = []
	for id: String in ids:
		entries.append({"abbreviation":id,"name":DERIVED_NAMES[id],"governing_primary":primary,
			"definition_page":_derived_page(id,primary),"category":"derived"})
	return {"success":true,"entries":entries}

static func lookup(primary: String, score: Variant, mode: String) -> Dictionary:
	if not PRIMARY_NAMES.has(primary): return _fail("unknown_primary_attribute")
	if mode not in ["mana","regular"]: return _fail("unknown_chart_mode")
	if typeof(score) != TYPE_INT or score < 0 or score > 35: return _fail("score_outside_verified_chart")
	if primary == "MAN":
		return {"success":true,"outcome":"allocation_required","primary":primary,"score":score,
			"mode":mode,"values":{"AP":{"kind":"allocation_required"},"KP":{"kind":"allocation_required"}},
			"allocation":allocation_descriptor(primary),"grants_eligibility":false,
			"eligibility":_eligibility(score),"entitlements_granted":false}
	var rows: Array = Tables.MANA if mode == "mana" else Tables.REGULAR
	var raw: String = rows[score].split("|")[Tables.COLUMNS.find(primary)]
	var components := _components(primary,mode)
	var values := {}
	var parts := raw.replace("ACC=", "").replace("+", "-").split("-")
	for index in range(components.size()):
		var id: String = components[index]
		values[id] = {"kind":"dead"} if raw == "DEAD" else (
			{"kind":"unlimited"} if parts[index] == "*" else {"kind":"integer","value":int(parts[index])})
	if primary == "DEX":
		values["DT"] = {"kind":"allocation_required"}
		values["DP"] = {"kind":"allocation_required"}
	return {"success":true,"primary":primary,"score":score,"mode":mode,"printed_cell":raw,
		"printed_page":(51 if score <= 20 else 52) if mode == "mana" else (53 if score <= 20 else 54),
		"outcome":"dead" if raw == "DEAD" else "values","values":values,
		"grants_eligibility":false,"eligibility":_eligibility(score),
		"entitlements_granted":false}

static func allocation_descriptor(primary: String) -> Dictionary:
	if primary not in ["DEX","MAN"]: return _fail("not_an_allocation_pool")
	return {"success":true,"authority":"printed_v3_p20" if primary == "DEX" else "owner_approved_arena_37c",
		"primary":primary,"fields":["DT","DP"] if primary == "DEX" else ["AP","KP"],
		"pool":"permanent_attribute","confirmed_allocations_locked":true,
		"preserve_authored_and_historical_allocations":true,
		"new_standard_policy":"authored_or_approved_policy" if primary == "DEX" else "balanced_50_50_whole_points",
		"odd_positive_point":"lower_side_then_documented_deterministic_tie_break",
		"negative_policy":"higher_first","negative_tie_first":"DT" if primary == "DEX" else "AP",
		"allocation_point_minimum":0,"temporary_separate":true,
		"temporary_manual_redistribution":false if primary == "MAN" else "source_specific_policy",
		"calculates_or_grants_points":false}

static func resistance_descriptor(id: String) -> Dictionary:
	if id not in ["SR","TB"]: return _fail("unknown_resistance")
	return {"success":true,"category":"resistance","abbreviation":id,
		"name":"Special Resistance" if id == "SR" else "Tolerance Bonus",
		"storage_field":id.to_lower(),"legacy_purchase_kind":"special_resistance" if id == "SR" else "talent_bonus",
		"governing_primary":null,"definition_page":24,"starting_values_page":43,"advancement_page":102,
		"mechanic":"eligible_special_resistance_check" if id == "SR" else "add_to_applicable_tolerance_skill_target",
		"generates_value":false,"purchase_authorized":false}

static func purchase_label(storage_kind: String) -> Dictionary:
	if storage_kind == "talent_bonus": return {"success":true,"storage_kind":storage_kind,"label":"Tolerance Bonus"}
	if storage_kind == "special_resistance": return {"success":true,"storage_kind":storage_kind,"label":"Special Resistance"}
	return _fail("unknown_resistance_purchase_kind")

static func _components(primary: String, mode: String) -> Array:
	if primary == "WIS": return ["SS","MSL","MR/H"] if mode == "mana" else ["SS","MSL"]
	if primary == "WIT": return ["INIT","MNS","RCL"] if mode == "mana" else ["INIT","MRF","RCL"]
	return COMPONENTS[primary]

static func _eligibility(score: int) -> String:
	if score >= 26: return "verified_immortality_required"
	if score >= 21: return "qualifying_special_or_special_imbued_equipment_required"
	return "normal_source_eligibility_still_required"

static func _derived_page(id: String, primary: String) -> int:
	if id == "RCL": return 22
	if id in ["MSL","MR/H"]: return 21
	if id == "AT": return 20
	return DEFINITION_PAGES[primary]

static func _fail(reason: String) -> Dictionary:
	return {"success":false,"reason":reason}
