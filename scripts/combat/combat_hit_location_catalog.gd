class_name CombatHitLocationCatalog
extends RefCounted

const SAME_SIZE_RELATIONSHIP := &"same_size"
const TINY_TARGET_RELATIONSHIP := &"target_tiny"
const TINY_ATTACKER_RELATIONSHIP := &"tiny_attacker"
const SIZE_TINY := &"tiny"
const SIZE_SMALL := &"small"
const SIZE_MEDIUM := &"medium"
const SIZE_LARGE := &"large"
const SIZE_EXTRA_LARGE := &"extra_large"
const SIZE_GIGANTIC := &"gigantic"
const SIZE_ENORMOUS := &"enormous"
const LOCATION_8_KNEE := &"knee"
const LOCATION_8_LOWER_LEG := &"lower_leg"

static var _NON_TINY_SIZE_CATEGORIES := PackedStringArray([
	SIZE_SMALL, SIZE_MEDIUM, SIZE_LARGE, SIZE_EXTRA_LARGE, SIZE_GIGANTIC, SIZE_ENORMOUS,
])
static var _SIZE_CATEGORIES := PackedStringArray([
	SIZE_TINY, SIZE_SMALL, SIZE_MEDIUM, SIZE_LARGE, SIZE_EXTRA_LARGE, SIZE_GIGANTIC, SIZE_ENORMOUS,
])
static var _SIZE_CATEGORY_HEIGHT_RANGES := {
	SIZE_TINY: "1in-1ft6in",
	SIZE_SMALL: "1ft7in-3ft",
	SIZE_MEDIUM: "3ft1in-6ft4in",
	SIZE_LARGE: "6ft5in-9ft",
	SIZE_EXTRA_LARGE: "9ft1in-12ft",
	SIZE_GIGANTIC: "12ft1in-15ft",
	SIZE_ENORMOUS: "15ft1in-25ft",
}

# Ordered by Prime locations 1 through 9. The approved Arena Knee / Lower Leg
# subdivision intentionally shares the printed location 8 modifier.
static var _NON_TINY_ACC_BY_RELATIONSHIP := {
	"small_to_medium": PackedInt32Array([-4, -6, -1, -2, -3, -2, 0, 0, 0]),
	"small_to_large": PackedInt32Array([-5, -7, -2, -3, -4, -3, -1, 0, 0]),
	"small_to_extra_large": PackedInt32Array([-6, -8, -3, -4, -5, -4, -2, -1, 0]),
	"small_to_gigantic": PackedInt32Array([-7, -9, -4, -5, -6, -5, -3, -2, -1]),
	"small_to_enormous": PackedInt32Array([-8, -10, -5, -6, -7, -6, -4, -3, -2]),
	"medium_to_small": PackedInt32Array([0, -1, -3, -2, -3, -4, -5, -6, -7]),
	"medium_to_large": PackedInt32Array([-4, -6, -1, -2, -3, -2, 0, 0, 0]),
	"medium_to_extra_large": PackedInt32Array([-5, -7, -2, -3, -4, -2, -1, 0, 0]),
	"medium_to_gigantic": PackedInt32Array([-6, -8, -3, -4, -5, -3, -2, -1, 0]),
	"medium_to_enormous": PackedInt32Array([-7, -9, -4, -5, -6, -4, -3, -2, -1]),
	"large_to_small": PackedInt32Array([-1, -2, -4, -3, -4, -5, -6, -7, -8]),
	"large_to_medium": PackedInt32Array([0, -1, -3, -2, -3, -4, -5, -6, -7]),
	"large_to_extra_large": PackedInt32Array([-4, -6, -1, -2, -3, -2, 0, 0, 0]),
	"large_to_gigantic": PackedInt32Array([-5, -7, -2, -3, -4, -3, -1, 0, 0]),
	"large_to_enormous": PackedInt32Array([-6, -8, -3, -4, -5, -4, -2, -1, 0]),
	"extra_large_to_small": PackedInt32Array([-2, -3, -5, -4, -5, -6, -7, -8, -9]),
	"extra_large_to_medium": PackedInt32Array([-1, -2, -4, -3, -4, -5, -6, -7, -8]),
	"extra_large_to_large": PackedInt32Array([0, -1, -3, -2, -3, -4, -5, -6, -7]),
	"extra_large_to_gigantic": PackedInt32Array([-4, -6, -1, -2, -3, -2, 0, 0, 0]),
	"extra_large_to_enormous": PackedInt32Array([-5, -7, -2, -3, -4, -3, -1, 0, 0]),
	"gigantic_to_small": PackedInt32Array([-3, -4, -6, -5, -6, -7, -8, -9, -10]),
	"gigantic_to_medium": PackedInt32Array([-2, -3, -5, -4, -5, -6, -7, -8, -9]),
	"gigantic_to_large": PackedInt32Array([-1, -2, -4, -3, -4, -5, -5, -6, -7]),
	"gigantic_to_extra_large": PackedInt32Array([0, -1, -3, -2, -3, -4, -4, -5, -6]),
	"gigantic_to_enormous": PackedInt32Array([-4, -6, -1, -2, -3, -2, 0, 0, 0]),
	"enormous_to_small": PackedInt32Array([-4, -5, -7, -6, -7, -8, -9, -10, -11]),
	"enormous_to_medium": PackedInt32Array([-3, -4, -6, -5, -6, -7, -8, -9, -10]),
	"enormous_to_large": PackedInt32Array([-2, -3, -5, -4, -5, -6, -7, -8, -9]),
	"enormous_to_extra_large": PackedInt32Array([-1, -2, -4, -3, -4, -5, -6, -7, -8]),
	"enormous_to_gigantic": PackedInt32Array([0, -1, -3, -2, -3, -4, -5, -6, -7]),
}

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
	return _build_profile(
		SAME_SIZE_RELATIONSHIP,
		PackedInt32Array([-3, -5, 0, -1, -2, -3, -2, -3, -4]),
		0,
		PackedStringArray(["PRIME-V3 pp. 95-97, SAME SIZE hit-location ACC chart", "Task 27 owner-confirmed armor coverage"])
	)


static func is_supported_size_category(size_category: StringName) -> bool:
	return _SIZE_CATEGORIES.has(String(size_category))


static func get_size_category_height_range(size_category: StringName) -> String:
	return String(_SIZE_CATEGORY_HEIGHT_RANGES.get(size_category, ""))


static func resolve_attack_profile(attacker_size: StringName, target_size: StringName) -> Dictionary:
	if not is_supported_size_category(attacker_size):
		return {"success": false, "reason": "unsupported_attacker_size_category", "size_category": String(attacker_size)}
	if not is_supported_size_category(target_size):
		return {"success": false, "reason": "unsupported_target_size_category", "size_category": String(target_size)}
	if attacker_size == SIZE_TINY:
		return _successful_profile(
			_build_profile(
				TINY_ATTACKER_RELATIONSHIP,
				PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0, 0]),
				0,
				PackedStringArray(["PRIME-V3 p. 95, Tiny exception: no hit-location ACC change for Tiny attackers"])
			), attacker_size, target_size
		)
	if target_size == SIZE_TINY:
		var tiny_dodge_bonus := _get_tiny_target_dodge_bonus(attacker_size)
		return _successful_profile(
			_build_profile(
				TINY_TARGET_RELATIONSHIP,
				PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0, 0]),
				tiny_dodge_bonus,
				PackedStringArray(["PRIME-V3 p. 95, Tiny exception: no hit-location ACC change; Tiny target Dodge bonus by attacker size"])
			), attacker_size, target_size
		)
	if attacker_size == target_size:
		return _successful_profile(get_same_size_attack_profile(), attacker_size, target_size)
	var relationship_key := "%s_to_%s" % [String(attacker_size), String(target_size)]
	if not _NON_TINY_ACC_BY_RELATIONSHIP.has(relationship_key):
		return {"success": false, "reason": "unsupported_size_relationship", "relationship": relationship_key}
	return _successful_profile(
		_build_profile(
			StringName(relationship_key),
			_NON_TINY_ACC_BY_RELATIONSHIP[relationship_key],
			0,
			PackedStringArray(["PRIME-V3 pp. 95-97, directional Hit Locations Chart and Size Categories"])
		), attacker_size, target_size
	)


static func _successful_profile(profile: Dictionary, attacker_size: StringName, target_size: StringName) -> Dictionary:
	var result := profile.duplicate(true)
	result["success"] = true
	result["attacker_size"] = String(attacker_size)
	result["target_size"] = String(target_size)
	return result


static func _get_tiny_target_dodge_bonus(attacker_size: StringName) -> int:
	match attacker_size:
		SIZE_SMALL:
			return 2
		SIZE_MEDIUM:
			return 3
		SIZE_LARGE:
			return 4
		SIZE_EXTRA_LARGE:
			return 5
		SIZE_GIGANTIC:
			return 6
		SIZE_ENORMOUS:
			return 7
		_:
			return 0


static func _build_profile(
	relationship: StringName,
	location_values: PackedInt32Array,
	tiny_target_dodge_bonus: int,
	source_refs: PackedStringArray
) -> Dictionary:
	assert(location_values.size() == 9, "Each Prime size profile requires locations 1 through 9.")
	var modifiers := {}
	var multipliers := {}
	var allowed := PackedStringArray()
	for location: Dictionary in _LOCATIONS:
		var location_id := String(location["id"])
		var location_number := int(location["number"])
		allowed.append(location_id)
		modifiers[location_id] = int(location_values[location_number - 1])
		multipliers[location_id] = (location["damage_multiplier"] as Dictionary).duplicate(true)
	return {
		"size_relationship": String(relationship),
		"acc_modifiers_by_location": modifiers,
		"allowed_target_locations": allowed,
		"location_multipliers": multipliers,
		"tiny_target_dodge_bonus": tiny_target_dodge_bonus,
		"uses_size_based_location_acc": true,
		"source_refs": source_refs.duplicate(),
	}


static func is_location_8_subdivision(location_id: StringName) -> bool:
	return location_id == LOCATION_8_KNEE or location_id == LOCATION_8_LOWER_LEG


static func get_display_name(location_id: StringName) -> String:
	var location := get_by_id(location_id)
	return String(location.get("display_name", String(location_id).replace("_", " ").to_upper()))
