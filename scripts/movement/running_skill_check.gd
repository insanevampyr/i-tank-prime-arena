class_name RunningSkillCheck
extends RefCounted

const BASE_MODIFIER: int = -2
const UNTRAINED_PENALTY: int = -4
const AUTOMATIC_SKILL_INVESTMENT: int = 3


static func is_automatic(skill_investment: int) -> bool:
	assert(skill_investment >= 0, "Running Skill investment cannot be negative.")
	return skill_investment >= AUTOMATIC_SKILL_INVESTMENT


static func get_skill_modifier(skill_investment: int) -> int:
	assert(skill_investment >= 0, "Running Skill investment cannot be negative.")
	if skill_investment == 0:
		return BASE_MODIFIER + UNTRAINED_PENALTY
	return BASE_MODIFIER + skill_investment - 1


static func get_target(effective_end: int, skill_check_modifier: int, skill_investment: int) -> int:
	assert(effective_end >= 0, "Effective END cannot be negative.")
	return effective_end + get_skill_modifier(skill_investment) + skill_check_modifier


static func resolve(
	raw_roll: int,
	effective_end: int,
	skill_check_modifier: int,
	skill_investment: int,
	roll_bonus: int,
	check_kind: String,
	check_sequence: int
) -> Dictionary:
	assert(raw_roll >= 1 and raw_roll <= 20, "Running checks require a natural d20 result from 1 through 20.")
	assert(roll_bonus >= 0, "Roll Bonus cannot be negative.")
	assert(not check_kind.is_empty(), "Running checks require an evidence kind.")
	assert(check_sequence >= 0, "Running check sequence cannot be negative.")

	var target := get_target(effective_end, skill_check_modifier, skill_investment)
	var adjusted_roll := raw_roll - roll_bonus
	var critical_success := raw_roll == 1
	var critical_failure := raw_roll == 20
	var success := critical_success or (not critical_failure and adjusted_roll <= target)
	var result := "success" if success else "failure"
	if critical_success:
		result = "critical_success"
	elif critical_failure:
		result = "critical_failure"

	return {
		"check_kind": check_kind,
		"check_sequence": check_sequence,
		"raw_roll": raw_roll,
		"roll_bonus": roll_bonus,
		"adjusted_roll": adjusted_roll,
		"effective_end": effective_end,
		"base_modifier": BASE_MODIFIER,
		"skill_investment": skill_investment,
		"skill_modifier": get_skill_modifier(skill_investment),
		"skill_check_modifier": skill_check_modifier,
		"target": target,
		"critical_success": critical_success,
		"critical_failure": critical_failure,
		"success": success,
		"result": result,
		"source": "PRIME-V3 pp. 23, 67, 69, 105-106",
	}
