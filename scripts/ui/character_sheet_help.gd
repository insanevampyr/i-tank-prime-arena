class_name CharacterSheetHelp
extends RefCounted

const Rules = preload("res://scripts/combat/prime_v3_attribute_engine.gd")
const QUICK := {
	"STR":"Strength affects source-defined strength, force and carrying statistics.",
	"END":"Endurance governs its verified protection, soak and level-growth references.",
	"SPD":"Speed governs Movement Rate and Action Total in its applicable chart.",
	"WIS":"Wisdom governs magic-related statistics. Resource history remains event-time based.",
	"INT":"Intelligence governs its skill and magic-item statistics.",
	"WIT":"Wits governs Initiative and its mode-specific derived statistics.",
	"MAN":"Mannerisms supplies Aggressive and Kindly Persuasion allocations.",
	"LUK":"Luck governs its chart references; spendable entitlements require separate verified history.",
	"APP":"Appearance governs Personal Appearance Rating and Charisma.",
	"SB":"Strength Bonus applies only where the attack or effect permits it.",
	"PPG":"Push, Pull & Grip is a Strength-derived reference.",
	"MWC":"Max Weight Capacity is distinct from actual carried weight and effective encumbrance penalties.",
	"PS":"Physical Soak is an eligible defense, not an automatic damage reduction.",
	"HPB":"Hit Point Bonus contributes to source-legal level growth; it does not refill current health.",
	"SS":"Special Success governs eligible casting and learning checks.",
	"MSL":"Max Special Level limits eligible learning; it does not grant a Special.",
	"MR/H":"Mana Recovery per Hour is a printed Mana-user statistic. Arena does not grant automatic downtime recovery.",
	"S#":"Skill Number describes the source-defined skill limit.",
	"SCM":"Skill Check Modifier applies to eligible skill checks.",
	"INIT":"Initiative contributes to authoritative combat order.",
	"MNS":"Max Number of Specials is a Mana-user limit, not a list of learned Specials.",
	"MRF":"Max Regular Fields is an Ability-user limit, not a list of learned fields.",
	"RCL":"Resist Control Loss is separate from Special Resistance.",
	"RB":"Roll Bonus applies under the check's existing rules without changing the natural die result.",
	"PAR":"Personal Appearance Rating uses its exact chart; supernatural values are not capped at 10.",
	"CHA":"Charisma is an Appearance-derived statistic. No new social mechanics are inferred here.",
	"DEX":"Dexterity supplies your Dodge allocation pool and chart-based Accuracy.",
	"DT":"Dodge Touch applies to eligible hand-held physical attacks.",
	"DP":"Dodge Projectile applies to eligible thrown weapons and magical projectiles.",
	"ACC":"Accuracy is used when attempting to hit a legal target.",
	"EXPM":"Lifetime experience used for level progression; spending EXPC does not reduce it.",
	"EXPC":"Available experience that can be spent on legally supported advancement.",
	"NAL":"Natural Armor Level is separate from location-specific armor protection.",
	"MR":"Movement Rate. Legal Dodge displacement also uses movement.",
	"AT":"Action Total determines ordinary action timing. Inspection grants no actions.",
	"MIUR":"Magic Item Use Rating. A displayed item does not itself establish permission to use it.",
	"SR":"Special Resistance is an independent resistance, not a primary-derived statistic.",
	"TB":"Tolerance Bonus applies to relevant tolerance checks. It is not Talent Bonus.",
	"AP":"Aggressive Persuasion is allocated from MAN. It is separate from Ability Points.",
	"KP":"Kindly Persuasion is allocated from MAN.",
	"AP_RESOURCE":"Ability Points are a resource, distinct from MAN persuasion allocations.",
	"ToF":"Twists of Fate. A chart reference is not proof of a spendable entitlement.",
	"RR/G":"The book names Re-Rolls per Game. Arena's approved future RR/W adaptation is not granted by this sheet.",
	"HPC":"Hit Points Current are shown alongside the existing Hit Points Max.",
	"BLOOD":"Current blood and maximum blood are distinct from health.",
	"STATS":"Original is the authored value; permanent includes verified progression; effective is the current combat value.",
	"SKILLS":"Source-recorded proficiency is distinguished from a verified live check. Missing records do not mean untrained.",
	"SPECIALS":"Only recorded knowledge or access appears here. Catalog membership alone does not mean a character knows a Special.",
	"EQUIPMENT":"Equipped gear, carried quantities, armor protection and requirements are read from existing character systems.",
	"RESOURCES":"Current values and maximum values are separate. Inspecting them never restores resources.",
}
const DETAILS := {
	"DEX":"Prime V3 p. 20: DEX is the allocation pool shared by DT and DP; ACC follows its chart. DEX 9 and 10 both have ACC 9; DEX 11 has ACC 10. A DEX purchase can improve Dodge without changing ACC. Permanent purchases explicitly assign the new point to DT or DP. Previously confirmed allocations remain locked under the approved Arena development rules. Temporary effects and equipment remain separate.",
	"DT":"Prime V3 p. 20 distinguishes Dodge Touch from Dodge Projectile. Dodge requires legal circumstances and geometry. A successful Dodge may move up to half the applicable MR, rounded down, and must evade the attack. This window does not perform or queue a Dodge. Approved Arena rules preserve signed effective Dodge values and natural critical behavior.",
	"DP":"Prime V3 p. 20 assigns thrown weapons and magical projectiles to Dodge Projectile. Eligibility, movement geometry and remaining movement are checked by combat. The permanent allocation is separate from armor penalties and temporary modifiers. No Dodge roll is performed by inspection.",
	"STATS":"Original values come from the character's immutable authored definition. Permanent values come from the admitted actor and validated progression. Effective derived values come from existing combat getters. Equipment and temporary effects do not rewrite the permanent allocation. '--' means no verified value is available; it does not mean zero. Chart-only references are never substituted for missing live statistics.",
	"RESOURCES":"HPC/HPM, Mana and Ability Points retain their existing current/max distinctions. Purchased attributes and level growth follow their approved event-time rules. This read-only sheet does not refill, clamp, spend or recalculate resources. Active combat continues while this window is open.",
	"SKILLS":"Balance uses the existing verified evaluator, effective DEX, sourced training, SI, SCM and RB. Its displayed target is a pure reference query; no die is rolled. Other authored skills may have no integrated check yet. Explicitly untrained, unknown and source-recorded automatic proficiency are different states. No new skill progression or automatic checks are created here.",
	"SPECIALS":"Mana costs, ordinary Acts versus NAC timing, range, known daily allowances and active protection are displayed only where verified. Target, line of sight, timing, defenses and resources are still checked by the normal combat pipeline when a Special is actually used. No cast, assignment, learning or purchase controls exist in this window.",
	"EQUIPMENT":"TAL is location- and damage-type-specific. NAL remains separate. Weapon requirements, hand handling and armor penalties come from existing catalogs and actor state. An equipped item can correctly have zero loose carried copies. Unresolved properties remain unavailable; viewing an item does not equip, repair, identify or activate it.",
	"EXPC":"Prime V3 p. 102 provides advancement prices. Arena purchases remain confined to eligible READY or between-wave character management, with verified storage and exactly-once receipts. The character sheet contains no purchase controls. Use Character Advancement from CHARACTER MENU.",
}

static func entry(id: String) -> Dictionary:
	var name: String = Rules.PRIMARY_NAMES.get(id,Rules.DERIVED_NAMES.get(id,{"HPC":"Health","BLOOD":"Blood","EXPM":"Experience Total","EXPC":"Spendable Experience","AP_RESOURCE":"Ability Points","STATS":"Original, Permanent and Effective","SKILLS":"Skills and Proficiencies","SPECIALS":"Known Specials","EQUIPMENT":"Equipment and Protection","RESOURCES":"Current and Maximum Resources","SR":"Special Resistance","TB":"Tolerance Bonus"}.get(id,id.capitalize())))
	var quick: String = QUICK.get(id,"A character statistic shown only when a verified value is available.")
	var detail: String = DETAILS.get(id,DETAILS.get("DEX") if id == "ACC" else DETAILS.get("STATS"))
	return {"title":name,"quick":quick,"details":detail}
