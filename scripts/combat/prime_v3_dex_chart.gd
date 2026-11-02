class_name PrimeV3DexChart
extends RefCounted

# PRIME-V3 pp. 53-56: DEX/ACC columns match in Mana and Regular charts.
# Lookup only: this does not authorize attribute caps, stacking or purchases.
const ACC := [0,5,5,6,6,7,7,8,8,9,9,10,10,11,12,13,14,15,16,17,18,18,19,19,20,20,21,22,23,24,25,26,27,28,29,30]

static func accuracy(effective_dex: int, chart: String) -> Variant:
	if chart not in ["mana","regular"] or effective_dex < 0 or effective_dex >= ACC.size(): return null
	return ACC[effective_dex]
