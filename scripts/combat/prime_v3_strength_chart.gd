class_name PrimeV3StrengthChart
extends RefCounted

# Printed pp. 19, 52-53 and 55. Mana/Regular STR columns agree.
# Mortal purchases stop at 20; no immortality or magic-item permission inferred.
const ROWS := [
	[0,5,25],[0,5,50],[1,5,75],[1,6,100],[1,6,150],
	[1,7,175],[1,7,200],[2,8,225],[2,8,250],[2,9,300],
	[2,9,325],[3,10,350],[3,10,375],[3,11,400],[3,11,450],
	[4,12,475],[4,12,500],[4,13,525],[4,13,550],[5,14,600],
]

static func derived(strength: int) -> Dictionary:
	if strength < 1 or strength > ROWS.size(): return {"success":false,"reason":"strength_chart_or_mortal_limit_unverified"}
	var row: Array = ROWS[strength-1]
	return {"success":true,"sb":row[0],"ppg":row[1],"mwc":row[2]}
