class_name PrimeV3StrengthChart
extends RefCounted

const Rules = preload("res://scripts/combat/prime_v3_attribute_engine.gd")

# Printed pp. 19, 52-53 and 55. Mana/Regular STR columns agree.
# Mortal purchases stop at 20; no immortality or magic-item permission inferred.
# Frozen previous table retained for compatibility tests and one-function rollback.
const ROWS := [
	[0,5,25],[0,5,50],[1,5,75],[1,6,100],[1,6,150],
	[1,7,175],[1,7,200],[2,8,225],[2,8,250],[2,9,300],
	[2,9,325],[3,10,350],[3,10,375],[3,11,400],[3,11,450],
	[4,12,475],[4,12,500],[4,13,525],[4,13,550],[5,14,600],
]

static func derived(strength: int) -> Dictionary:
	if strength < 1 or strength > ROWS.size(): return {"success":false,"reason":"strength_chart_or_mortal_limit_unverified"}
	# Both printed STR columns agree. Keep this helper's narrower interface/range.
	var values: Dictionary = Rules.lookup("STR", strength, "mana").values
	return {"success":true,"sb":values.SB.value,"ppg":values.PPG.value,"mwc":values.MWC.value}
