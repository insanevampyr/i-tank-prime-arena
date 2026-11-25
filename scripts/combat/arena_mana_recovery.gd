class_name ArenaManaRecovery
extends RefCounted
# Arena override only; printed Prime V3 MR/H tables remain unchanged.
const UNITS_PER_MANA := 120000000
static func step(current: int, maximum: int, wisdom: int, units: int, elapsed_us: int) -> Dictionary:
	if current < 0 or maximum < current or units < 0 or units >= UNITS_PER_MANA or elapsed_us < 0: return {"success":false,"reason":"invalid_mana_recovery_state"}
	if current == maximum: return {"success":true,"current":current,"units":0,"recovered":0}
	if wisdom <= 0: return {"success":true,"current":current,"units":units,"recovered":0}
	var total := units+elapsed_us*wisdom
	@warning_ignore("integer_division")
	var recovered := mini(maximum-current,total/UNITS_PER_MANA)
	var after := current+recovered
	return {"success":true,"current":after,"units":0 if after == maximum else total%UNITS_PER_MANA,"recovered":recovered}
static func delay(wisdom: int, units: int) -> int:
	if wisdom <= 0: return -1
	@warning_ignore("integer_division")
	return (UNITS_PER_MANA-units+wisdom-1)/wisdom
