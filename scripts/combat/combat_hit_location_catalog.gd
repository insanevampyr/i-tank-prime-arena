class_name CombatHitLocationCatalog
extends RefCounted

const SAME_SIZE_RELATIONSHIP := &"same_size"
const LOCATION_8_KNEE := &"knee"
const LOCATION_8_LOWER_LEG := &"lower_leg"

const _LOCATIONS := [
	{"number": 1, "id": &"head", "display_name": "HEAD", "same_size_acc_modifier": -3, "armor_slots": [&"head"], "damage_multiplier": {"numerator": 3, "denominator": 2, "source_ref": "PRIME-V3 pp. 95-98, Head location 1"}},
	{"number": 2, "id": &"neck", "display_name": "NECK", "same_size_acc_modifier": -5, "armor_slots": [&"head"], "damage_multiplier": {"numerator": 3, "denominator": 2, "source_ref": "PRIME-V3 pp. 95-98, Neck location 2"}},
	{"number": 3, "id": &"torso", "display_name": "TORSO", "same_size_acc_modifier": 0, "armor_slots": [&"torso"], "damage_multiplier": {"numerator": 1, "denominator": 1, "source_ref": "PRIME-V3 pp. 95-98, Torso location 3"}},
	{"number": 4, "id": &"shoulders_upper_arms", "display_name": "SHOULDERS/UPPER ARMS", "same_size_acc_modifier": -1, "armor_slots": [&"arms"], "damage_multiplier": {"numerator": 1, "denominator": 1, "source_ref": "PRIME-V3 pp. 95-98, Shoulders/Upper Arms location 4"}},
	{"number": 5, "id": &"elbows", "display_name": "ELBOWS", "same_size_acc_modifier": -2, "armor_slots": [&"elbows"], "damage_multiplier": {"numerator": 1, "denominator": 1, "source_ref": "PRIME-V3 pp. 95-98, Elbows location 5"}},
	{"number": 6, "id": &"hands", "display_name": "HANDS", "same_size_acc_modifier": -3, "armor_slots": [&"hands"], "damage_multiplier": {"numerator": 1, "denominator": 1, "source_ref": "PRIME-V3 pp. 95-98, Hands location 6"}},
	{"number": 7, "id": &"groin_upper_legs", "display_name": "GROIN/UPPER LEGS", "same_size_acc_modifier": -2, "armor_slots": [&"legs"], "damage_multiplier": {"numerator": 1, "denominator": 1, "source_ref": "PRIME-V3 pp. 95-98, Groin/Upper Legs location 7"}},
	{"number": 8, "id": LOCATION_8_KNEE, "display_name": "KNEE", "same_size_acc_modifier": -3, "armor_slots": [&"knees"], "damage_multiplier": {"numerator": 1, "denominator": 1, "source_ref": "PRIME-V3 pp. 95-98, Knees/Lower Legs location 8; Task 27 Arena knee subdivision"}},
	{"number": 8, "id": LOCATION_8_LOWER_LEG, "display_name": "LOWER LEG", "same_size_acc_modifier": -3, "armor_slots": [&"legs"], "damage_multiplier": {"numerator": 1, "denominator": 1, "source_ref": "PRIME-V3 pp. 95-98, Knees/Lower Legs location 8; Task 27 Arena lower-leg subdivision"}},
	{"number": 9, "id": &"feet", "display_name": "FEET", "same_size_acc_modifier": -4, "armor_slots": [&"legs"], "damage_multiplier": {"numerator": 1, "denominator": 1, "source_ref": "PRIME-V3 pp. 95-98, Feet location 9"}},
]


static func get_by_number(number: int) -> Dictionary:
	for location: Dictionary in _LOCATIONS:
		if int(location["number"]) == number:
			return location.duplicate(true)
	return {}


static func get_by_id(location_id: StringName) -> Dictionary:
	for location: Dictionary in _LOCATIONS:
		if StringName(location["id"]) == location_id:
			return location.duplicate(true)
	return {}


static func get_selectable_location_ids() -> PackedStringArray:
	var result := PackedStringArray()
	for location: Dictionary in _LOCATIONS:
		result.append(String(location["id"]))
	return result


static func get_same_size_attack_profile() -> Dictionary:
	var modifiers := {}
	var multipliers := {}
	var allowed := PackedStringArray()
	for location: Dictionary in _LOCATIONS:
		var location_id := String(location["id"])
		allowed.append(location_id)
		modifiers[location_id] = int(location["same_size_acc_modifier"])
		multipliers[location_id] = (location["damage_multiplier"] as Dictionary).duplicate(true)
	return {
		"size_relationship": String(SAME_SIZE_RELATIONSHIP),
		"acc_modifiers_by_location": modifiers,
		"allowed_target_locations": allowed,
		"location_multipliers": multipliers,
		"source_refs": PackedStringArray(["PRIME-V3 pp. 95-98, same-size hit-location ACC chart", "Task 27 owner-confirmed armor coverage"]),
	}


static func is_location_8_subdivision(location_id: StringName) -> bool:
	return location_id == LOCATION_8_KNEE or location_id == LOCATION_8_LOWER_LEG


static func get_display_name(location_id: StringName) -> String:
	var location := get_by_id(location_id)
	return String(location.get("display_name", String(location_id).replace("_", " ").to_upper()))
