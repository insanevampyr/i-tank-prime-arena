class_name PrimeV3RandomDropResolver
extends RefCounted

const SOURCE_REF := "Random Drops Complete.docx; ITank Prime V3 printed pp. 361-373"

const POTIONS := [
	"Invisibility Potion", "Sleep Potion", "Spider Climb Potion", "Truth Potion",
	"Explosion Potion", "Healing Potion", "Temporary Attributes Potion", "Mass Blackness Potion",
	"Feather Fall Potion", "Permanent Attributes Potion", "See in Magical Darkness Potion",
	"Mana Potion", "Sober Potion", "Quick Sober Potion", "Sight Potion", "Nerves Potion",
	"Charisma Potion", "Healing Potion", "Mana Potion", "Healing Potion",
]
const SCROLLS := [
	"Immune Elements", "Resurrection", "Magic Shield", "Regeneration", "Freeze Person",
	"Identify Magic Item", "Dodge", "Heal Self/Other", "Lightning Strike", "Strength Burst",
	"Steal Life", "Spiked Magic Shield", "Fire Strike", "Summon Skeleton",
	"Permanent Feather Weight Item", "Haste", "Wind Blast", "Appearance", "Reincarnation",
	"Teleport",
]
const BOOTS := [
	"+3 Specific Attribute Boots", "Teleport Boots", "Rabbit Boots (+4 MR)", "Feather Fall Boots",
	"Haste Boots (+2 MR)", "Stealth Boots", "+1 Specific Attribute Boots", "Special Resistance Boots",
]
const RANDOM_ITEM_CATEGORIES := [
	"armor", "weapon", "ring_or_clothing", "clothing", "storyteller_created_item", "boots", "shield", "cursed_item",
]
const WEAPON_CATEGORIES := [
	"Javelin & Spears", "Ball & Chain", "Clubs", "Swords", "Daggers & Knives", "Mace",
	"Axes", "Bows", "Gloves", "Staffs/Rods/Wands",
]
const ARMOR_CATEGORIES := [
	"Rare/Special Armor", "Plate", "Chain", "Hard Studded/Scale", "Leather",
	"Leather", "Hard Studded/Scale", "Chain", "Plate", "Rare/Special Armor",
]
const RING_CLOTHING_CATEGORIES := [
	"Attribute Bonus", "Defense", "Movement", "Perception/Senses", "Resistance", "Utility",
	"Social/Quality of Life", "Storyteller Choice",
]
const SHIELDS := [
	"Buckler", "Small Shield", "Medium Shield", "Large Shield", "Tower Shield", "Spiked Shield",
	"Magic Shield", "Rare/Special Shield",
]
const POISONS := ["Ignis", "Boils", "Oil", "TTT", "Melvin", "Gestion"]

var _roll_source: Callable
var _rolls: Array[Dictionary] = []


func _init(roll_source: Callable) -> void:
	_roll_source = roll_source


func resolve(code: String, player_level: int = -1) -> Dictionary:
	_rolls.clear()
	var normalized := code.to_upper()
	var result := _resolve_drop_code(normalized, player_level)
	result["drop_code"] = normalized
	result["rolls"] = _rolls.duplicate(true)
	result["source_ref"] = SOURCE_REF
	return result


func _roll(label: String, sides: int) -> int:
	assert(_roll_source.is_valid(), "Random Drop resolution requires an authoritative roll source.")
	var raw: Variant = _roll_source.call(1, sides)
	var value := int(raw.get("value", 0)) if raw is Dictionary else int(raw)
	var draw_index: Variant = raw.get("rng_draw_index") if raw is Dictionary else null
	assert(value >= 1 and value <= sides, "Random Drop roll source returned an out-of-range value.")
	_rolls.append({"label": label, "die": "d%d" % sides, "value": value, "rng_draw_index": draw_index})
	return value


func _dice_total(label: String, count: int, sides: int, multiplier: int = 1) -> int:
	var total := 0
	for index in range(count):
		total += _roll("%s_%d" % [label, index + 1], sides)
	return total * multiplier


func _none(reason: String = "X") -> Dictionary:
	return {"status": "no_drop", "result_kind": "none", "reason": reason, "items": []}


func _item(definition_id: String, display_name: String, item_kind: String, quantity: int = 1, details: Dictionary = {}) -> Dictionary:
	var item := {
		"definition_id": definition_id,
		"display_name": display_name,
		"item_kind": item_kind,
		"quantity": quantity,
	}
	item.merge(details, true)
	return {"status": "resolved", "result_kind": item_kind, "items": [item]}


func _blocked(kind: String, reason: String, details: Dictionary = {}) -> Dictionary:
	return {
		"status": "intermediate_blocked",
		"result_kind": kind,
		"reason": reason,
		"intermediate": details.duplicate(true),
		"items": [],
	}


func _gold(quantity: int) -> Dictionary:
	return _item("prime_v3_gold", "%d Gold" % quantity, "currency", quantity)


func _resolve_drop_code(code: String, player_level: int) -> Dictionary:
	match code:
		"A":
			var roll := _roll("A", 20)
			if roll in [2, 5, 9, 10, 12, 14, 15]: return _none()
			if roll in [1, 20]: return _resolve_book(player_level)
			if roll in [3, 11, 16]: return _gold(_dice_total("A_gold_d10", 1, 10, 10))
			if roll == 4: return _resolve_poison()
			if roll in [6, 17]: return _resolve_random_item()
			if roll == 7: return _resolve_potion()
			if roll == 8: return _gold(_dice_total("A_gold_d20", 1, 20, 10))
			if roll == 13 or roll == 19: return _resolve_scroll()
			return _gold(_dice_total("A_gold_2d6", 2, 6, 10))
		"B":
			var roll := _roll("B", 20)
			return _gold(_dice_total("B_gold_d10", 1, 10)) if roll in [7, 13] else _none()
		"BM":
			var roll := _roll("BM", 20)
			if roll in [1, 20]: return _gold(2_000)
			return _gold(1_000) if roll in [2, 5, 6, 10, 11, 12, 13, 15, 18, 19] else _none()
		"BK":
			return _resolve_book(player_level) if _roll("BK", 20) in [1, 2, 7, 8, 14, 18, 19, 20] else _none()
		"C":
			var roll := _roll("C", 20)
			if roll in [3, 4, 9, 10, 13, 15, 16, 18]: return _none()
			if roll in [1, 17, 19, 20]: return _gold(_dice_total("C_gold_d10", 1, 10, 10))
			if roll == 2: return _gold(_dice_total("C_gold_d10", 1, 10))
			if roll in [5, 6]: return _gold(_dice_total("C_gold_d20", 1, 20))
			if roll in [7, 8]: return _gold(_dice_total("C_gold_2d10", 2, 10, 10))
			if roll in [11, 12]: return _gold(_dice_total("C_gold_d6", 1, 6, 10))
			return _gold(_dice_total("C_gold_2d20", 2, 20, 10))
		"M":
			var roll := _roll("M", 20)
			if roll in [3, 4, 7, 8, 9, 14, 16, 17]: return _none()
			return _gold(_dice_total("M_gold_5d20", 5, 20)) if roll in [1, 10, 13, 18, 20] else _gold(_dice_total("M_gold_2d10", 2, 10))
		"PS":
			var roll := _roll("PS", 20)
			if roll in [1, 4, 11, 12, 13, 20]: return _resolve_potion()
			if roll in [2, 5, 7, 9, 10, 17, 18, 19]: return _resolve_scroll()
			return _none()
		"RI":
			return _resolve_random_item() if _roll("RI", 20) in [4, 6, 7, 10, 14, 15, 18] else _none()
		_:
			return _blocked("drop_code", "unsupported_drop_code", {"code": code})


func _resolve_potion() -> Dictionary:
	var roll := _roll("potion", 20)
	var name: String = POTIONS[roll - 1]
	return _item("prime_v3_potion_%02d" % roll, name, "potion")


func _resolve_scroll() -> Dictionary:
	var roll := _roll("scroll", 20)
	var name: String = SCROLLS[roll - 1]
	if roll == 19:
		return _blocked("scroll", "reincarnation_scroll_chart_unfinished", {"chart_roll": roll, "display_name": name})
	return _item("prime_v3_scroll_%02d" % roll, "%s Scroll" % name, "scroll")


func _resolve_poison() -> Dictionary:
	var roll := _roll("poison", 6)
	return _item("prime_v3_poison_%02d" % roll, "%s Poison" % POISONS[roll - 1], "poison", 1, {"chart_roll": roll})


func _resolve_random_item() -> Dictionary:
	var roll := _roll("random_item", 8)
	var category: String = RANDOM_ITEM_CATEGORIES[roll - 1]
	match category:
		"armor":
			var armor_roll := _roll("armor_type", 10)
			var enchantment := _roll("armor_enchantment_level", 4)
			return _item("prime_v3_random_armor_%02d_e%d" % [armor_roll, enchantment], "%s +%d" % [ARMOR_CATEGORIES[armor_roll - 1], enchantment], "armor", 1, {"armor_chart_die": "d10", "chart_roll": armor_roll, "enchantment_level": enchantment})
		"weapon":
			var weapon_roll := _roll("weapon_type", 10)
			var enchantment := _roll("weapon_enchantment_level", 5)
			return _item("prime_v3_random_weapon_%02d_e%d" % [weapon_roll, enchantment], "%s +%d" % [WEAPON_CATEGORIES[weapon_roll - 1], enchantment], "weapon", 1, {"chart_roll": weapon_roll, "enchantment_level": enchantment})
		"ring_or_clothing", "clothing":
			return _resolve_ring_or_clothing(category)
		"boots":
			var boots_roll := _roll("boots", 8)
			return _item("prime_v3_boots_%02d" % boots_roll, BOOTS[boots_roll - 1], "boots", 1, {"chart_roll": boots_roll})
		"shield":
			var shield_roll := _roll("shield", 8)
			return _item("prime_v3_shield_%02d" % shield_roll, SHIELDS[shield_roll - 1], "shield", 1, {"chart_roll": shield_roll})
		"storyteller_created_item", "cursed_item":
			return _blocked(category, "storyteller_created_result_requires_authoring", {"random_item_roll": roll})
	return _blocked("random_item", "random_item_result_unresolved", {"random_item_roll": roll})


func _resolve_ring_or_clothing(item_kind: String) -> Dictionary:
	var miur_roll := _roll("ring_clothing_miur", 4)
	var miur := miur_roll
	if miur_roll == 4:
		miur = 4 if _roll("ring_clothing_miur_natural_4", 6) >= 5 else 3
	var category_roll := _roll("ring_clothing_category", 8)
	return _blocked(item_kind, "imbuer_effect_selection_requires_verified_imbuer_catalog", {
		"miur": miur,
		"category_roll": category_roll,
		"category": RING_CLOTHING_CATEGORIES[category_roll - 1],
	})


func _resolve_book(player_level: int) -> Dictionary:
	if player_level < 1:
		return _blocked("book", "player_level_required_before_book_rarity_roll", {"player_level": player_level})
	var rarity_roll := 0
	var rarity := ""
	var rarity_attempt := 0
	while rarity.is_empty():
		rarity_attempt += 1
		rarity_roll = _roll("book_rarity_%d" % rarity_attempt, 20)
		if rarity_roll <= 12:
			rarity = "common"
		elif rarity_roll <= 15 and player_level >= 4:
			rarity = "uncommon"
		elif rarity_roll <= 18 and player_level >= 8:
			rarity = "rare"
		elif rarity_roll <= 20 and player_level >= 11:
			rarity = "extremely_rare"
	var entries := _book_entries(rarity)
	var type_roll := _roll("book_%s_type" % rarity, entries.size())
	var entry: Dictionary = entries[type_roll - 1]
	var level := _dice_total("book_level", int(entry["dice_count"]), int(entry["die_sides"])) + int(entry.get("flat_bonus", 0))
	return _item(
		"prime_v3_book_%s_%02d_l%d" % [rarity, type_roll, level],
		"%s Level %d Book" % [entry["name"], level],
		"book", 1,
		{"rarity": rarity, "rarity_roll": rarity_roll, "type_roll": type_roll, "field_level": level, "player_level": player_level}
	)


func _book_entries(rarity: String) -> Array[Dictionary]:
	var names: Array[String] = []
	var default_die := 4
	var default_bonus := 1
	match rarity:
		"common":
			names = ["Illusionary", "Water", "Wind", "Life", "Light", "Earth", "Spirit Dexterity", "Spirit Endurance", "Charisma", "Shadow"]
		"uncommon":
			names = ["Spirit Appearance", "Fire", "Spirit Strength", "Ice", "Spirit Speed", "Lava", "Cleric", "Smoke", "Combat", "Plant Druid", "Animal Druid", "Earth Druid"]
		"rare":
			names = ["Lightning", "Enchanter", "Conjurer/Summoner", "Monk", "Shaman", "Necromancy", "Magic of Smith", "Stone", "Enhance", "Darkness", "Water 2", "Mass Blackness"]
		"extremely_rare":
			names = ["Teleport", "Larceny", "Enhance", "Telepathy", "Spirit of Mind", "Death", "Transformation", "Force"]
	var entries: Array[Dictionary] = []
	for index in range(names.size()):
		var die := default_die
		var bonus := default_bonus
		if rarity == "common" and index <= 4:
			die = 6
			bonus = 0
		elif rarity == "rare" and index == 10:
			die = 6
			bonus = 0
		elif rarity == "extremely_rare" and index in [3, 5, 6, 7]:
			die = 6
			bonus = 0
		entries.append({"name": names[index], "dice_count": 1, "die_sides": die, "flat_bonus": bonus})
	return entries
