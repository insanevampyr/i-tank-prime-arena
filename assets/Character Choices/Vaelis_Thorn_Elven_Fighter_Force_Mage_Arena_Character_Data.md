# Vaelis Thorn — ITank Prime Arena Character Data
This is the complete **recorded build** from the prior character/special sheets, intended for GPT/Codex input. It is **not** a new rules audit.
## Identity
- **name:** Vaelis Thorn
- **player:** Lee
- **campaign:** ITank Prime Arena
- **race:** Elf
- **classes:** ['Fighter', 'Mage']
- **level:** 1
- **type:** Mana User
- **experience_type:** 8
- **hit_dice:** 1d6
- **size_category:** M
- **age:** 122
- **sex:** Female
- **eyes:** Silver
- **hair:** Black
- **height:** 5 ft 7 in
- **weight_lb:** 125
- **outlook:** Cocky
- **home:** Arena entrant
- **job:** Competitor
- **title:** The Thorn
- **religion:** None
- **description:** Smirking, quick-footed Elven duelist; dark hair, silver eyes. Loves the crowd.
## Progression
- **EXPM:** 0
- **EXPC:** 0
- **unused_skills:** 0
- **creation_method:** 2
- **creation_attribute_points:** 41
- **starting_FP:** 25
- **drawback_FP:** 11
- **total_FP:** 36
- **FP_spent_on_attributes:** 25
- **FP_spent_on_force_HSF:** 10
- **FP_unspent:** 1
## Attributes
- **STR:** 9
- **END:** 6
- **SPD:** 11
- **DEX:** 9
- **WIS:** 10
- **INT:** 5
- **WIT:** 3
- **MAN:** 0
- **LUK:** 0
- **APP:** 14
- **SR:** 1
- **TB:** 0
## Derived attributes
- **SB:** 2
- **PPG:** 8
- **MWC_lb:** 250
- **NAL:** 1
- **PS:** 3
- **HPB:** 1
- **MR_ft:** 10
- **AT:** 1
- **DT:** 3
- **DP:** 6
- **ACC:** 9
- **SS:** 9
- **MSL:** 3
- **MR_per_hour:** 6
- **skill_number:** 30
- **SCM:** 0
- **MIUR:** 1
- **INIT:** 2
- **MNS:** 4
- **RCL:** 2
- **AP_persuasion:** 0
- **KP:** 0
- **RB:** 0
- **rerolls_per_game:** 0
- **twists_of_fate:** 0
- **PAR:** 7
- **CHA:** 4
## Current resources
- **HPM:** 9
- **HPC:** 9
- **BM:** 10
- **BC:** 10
- **mana_max:** 20
- **mana_current:** 20
- **ability_points:** None
- **abilities_used:** None
- **gold_gp:** 75

## Skills (30 invested)
| Skill | Investment | Attribute | Modifier |
|---|---:|---|---|
| Running | 3 | END | Automatic |
| Ambidextrous | 1 | DEX | -2 |
| Alertness | 4 | WIT | 1 |
| Special Recognition | 4 | WIS | -1 |
| Meditation | 4 | WIS | -1 |
| Magic Item Identify | 3 | WIS | -3 |
| Mana Burn | 2 | WIS | -3 |
| Leaping | 2 | STR/SPD | -1 |
| Blind Fighting | 2 | WIT/INT | -3/-1 |
| Balance | 2 | DEX | 0 |
| Creature Knowledge | 2 | INT | -2 |
| Quick to Act | 1 | WIT | -4 |

## Natural abilities
- Elf: Dark Sight 60 ft
- Elf: Hidden Passage +2 (10 ft)
- Elf: Local History
- Elf: Elven Wine Tolerance
- Elf: Bows; Alertness +2
- Elf: Literacy
- Fighter: All shields
- Fighter: Weapons except sling/wands/staffs/rods
- Mage: Wand, staff, rod, dagger, sling
- Mage: Bucklers; Item Identify
- Fighter: Camping
- Mage: Arcane Speech

## Automatic skills
- Ambidextrous (1 investment)
- Running (3 investments; Arena automatic)
- Elf: Bows; Literacy
- Mage: Item Identify
- Fighter: Camping

## Languages
- Elven
- Common
- Arcane Speech

## Backgrounds
- Arena challenger (unranked)

## Drawbacks and fears
- Deep Sleeper: +6 FP
- Infamous: +5 FP
- Fears: none

## Equipment
- Short Sword: Right hand, 2 ft, 1d6+1+SB (S/P); Right hip
- Short Wand: Left hand, 1 ft, 1d4+SB (B); Left hand
- Armor: no armor; light clothing, torso LTAL 0. Shield: none.
- Short sword sheath ×1 — With sword
- Short wand ×1 — Left hand; may cast
- Basic clothing ×1 — No purchased armor
- Gold pieces ×75 — 200 start - 100 sword - 25 wand

## Special fields and learned Specials
- Home fields: Combat, Force
- **Force Bolt** — Force HSF level 1; Mana 2; cast NAC; range 10 ft. 1d6 damage; 2 ft knockback. Magic projectile, NAC. SS then ACC.
- **Force Shield** — Force HSF level 2; Mana 4; cast 1 Act; range Touch. 20 damage shield after NAL; absorbs hits. Attacker knocked back 2 ft on hit. Non-stackable.

## Arena behavior
- **wave_state_persists:** True
- **no_automatic_between_wave_resource_recovery:** True
- **between_wave_downtime:** Safe, unlimited until player continues; no camping/sleeping or passive time-based HPC, Mana or Ability restoration.
- **active_recovery:** Only rules-legal potions, Specials, skills such as Meditation, items, etc.
- **running_three_investments:** Automatic successful Running (existing Arena behavior).
- **special_recognition:** Check automatically for eligible visible Specials; success popup "Casting <Special Name>", otherwise "Casting Special".
- **magic_item_identification:** Can be used between waves according to skill requirements.
- **preferred_tactics:** Right-hand sword damage; left-hand wand for Force defenses, knockback, disruption, control.

## Data verification cautions
- This is faithful structured transcription of the previously generated Vaelis packet, NOT a fresh independent verification of all Prime mechanics.
- Previous PDF contained some overlapping entries in the derived-attribute section; values above reflect intended final overlay and should be source-verified prior to game import.
- The character creation used assumed dice and FP choices recorded in the earlier packet.
- Religion is intentionally unselected; no religious Specials.
- The print sheet included both natural Mage Item Identify and 3 invested Magic Item Identify; preserve separately until the intended relationship is reviewed.
- No Combat Specials were recorded as learned, despite Combat HSF belonging to the character.
