class_name ArenaWaveCatalog
extends RefCounted

const WAVE_COUNT := 5


static func definitions() -> Array[Dictionary]:
	return [
		_wave(&"wave_1", "Wave 1", [
			_entry(&"common_goblin", "Common Goblin", 4, 2),
		]),
		_wave(&"wave_2", "Wave 2", [
			_entry(&"common_spadoodle", "Common Spadoodle", 3),
		]),
		_wave(&"wave_3", "Wave 3", [
			_entry(&"common_skelly", "Common Skelly", 2),
			_fixed_entry(&"hades_combat_follower", "Hades Combat Follower", 1),
		]),
		_wave(&"wave_4", "Wave 4", [
			_entry(&"mini_gargoyle_swarmer", "Mini Gargoyle Swarmer", 4),
		]),
		_wave(&"wave_5", "Wave 5", [
			_fixed_entry(&"rare_human_warrior", "Rare Human Warrior", 1),
		]),
	]


static func future_extension_points() -> PackedStringArray:
	return PackedStringArray(["lighting", "stealth", "flight", "individual_creature_integration"])


static func _wave(wave_id: StringName, display_name: String, roster: Array[Dictionary]) -> Dictionary:
	return {
		"wave_id": String(wave_id),
		"display_name": display_name,
		"roster": roster,
	}


static func _entry(creature_id: StringName, display_name: String, dice_sides: int, dice_count: int = 1) -> Dictionary:
	return {
		"creature_id": String(creature_id),
		"display_name": display_name,
		"quantity": {"kind": "dice", "minimum": dice_count, "sides": dice_sides, "dice_count": dice_count},
		"creature_integration_status": "not_implemented",
	}


static func _fixed_entry(creature_id: StringName, display_name: String, count: int) -> Dictionary:
	return {
		"creature_id": String(creature_id),
		"display_name": display_name,
		"quantity": {"kind": "fixed", "count": count},
		"creature_integration_status": "not_implemented",
	}
