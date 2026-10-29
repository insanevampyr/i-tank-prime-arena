# Rewards and Advancement Foundation

## Task 36H-Fix1: focused browser corrections

Vaelis's Short Sword/Wand definitions now explicitly permit the already-approved approach declaration policy. Previously the combined action inherited a false Sword flag, so the core correctly enforced the incorrect definition policy at declaration; this was not a broken final-effect range rule. Mouse, held input, Space/Enter and readiness reuse the existing pathways. Final strike-specific reach/LOS and ACC timing remain authoritative and unchanged. Messages use the actual declared reach rather than the old Battle Axe/three-foot wording.

The inventory detail no longer calls equipped zero-stack equipment unavailable. It still does not make weapons USE-able consumables. The compact history label is `Purchase History`, accurately describing the existing EXPC purchase list; no second progression history is introduced.

The owner-approved `REFRESH CHARACTER — DEV ONLY` button is shown only in DEV NORMAL safe downtime. UI submits to `ArenaCombatSession.request_developer_character_refresh`; `CombatSimulation.refresh_developer_character` independently checks the authoritative reward mode, wave phase, player identity, living state, ordinary-action availability and unique request ID. It restores only current HPC/Mana/AP and listed daily-use counters to their existing applicable maxima and emits a developer-only causal event. The normal reward ledger, maxima, level/EXPM/EXPC/purchases, conditions, active effects/durations, Force Shield, inventory/equipment/hand state, world loot, clock and RNG are unchanged. Distinct repeated requests at full resources are safe; replayed IDs reject. Existing effective HPM constraints remain applied. It is not Prime recovery, midnight, resurrection, automatic inter-wave restoration or permanent saving.

Home checks (fresh local export): select Vaelis; click/hold an enemy beyond reach, then approach during the five-second Act; confirm ACC only at legal final reach/LOS and no early roll. Check equipped Sword details and Purchase History. Finish a wave in DEV NORMAL with spent resources; verify the refresh button and exact restoration, unchanged Shield/effects/XP/items, then NEXT WAVE and RESET. Verify the utility cannot be used in NORMAL, TEST, combat or after defeat. Owner performs full regression/export/browser acceptance.

Presentation backlog only: overlapping top controls and the SR arrow rendering issue. New reference copies remain to be synchronized: checked local headers are specification v1.25 / roadmap v1.26, not the requested v1.26 / v1.27. No external master document is changed here.

## Task 36H: level progression (temporary run, not permanent saving)

`PrimeV3LevelCatalog` transcribes all 247 printed thresholds from pp. 99-101, validates all thirteen EXP Types using p. 51 class combinations, and keeps their exact Hit Dice. No interpolated thresholds or LVL 21 values exist. Test checksum is derived independently from the extracted, visually checked PDF cells, including irregular printed values.

Source character resources opt in through `progression_policy`: canonical classes, explicit source-backed specialty mapping, EXP Type, Mana/Ability resource mode, initial EXPM and EXPC. Runtime actors also carry the actual class identity for validation. Unknown policy, class, HPB or initial level fails closed before RNG. Vaelis alone currently opts in: source Fighter/Mage, Type Eight, LVL 1, zero starting EXPM/EXPC, HPB 1, Mana User. Guard and fixed encounter creatures remain ineligible pending complete starting progression records.

The existing reward ledger remains the single run-earned/spent XP ledger. After each qualifying authoritative reward transaction, shared simulation code processes all newly crossed levels immediately, not during downtime. Mutable actor progression retains lifetime EXPM, EXPC, level, award IDs and immutable historical records; purchases spend EXPC without reducing EXPM or level. Each gained level rolls its printed HD and adds current HPB to HPM, **never current HPC**. Live equipment recalculation retains that accumulated HPM growth. Mana Users receive floor(WIS/2)+5 Mana maximum; Ability Users receive exactly one shared AP maximum, with **no separate flexible-use award**. Neither current Mana nor current AP refills. No extra strikes, AT changes, action-time advancement, equipment mutations or conditions are introduced.

Current XP/drop operations finish their existing deterministic draws before the new level HD draws; future draws may therefore differ legitimately when more levels are earned. Same-seed histories and two-client digests remain authoritative. The old multiplier/drop isolation test deliberately omits a progression policy to compare reward generation alone; Task 36H tests exercise real accelerated leveling separately.

Optional schema-12 fields carry policy, accumulated HPM increase and actor progression. Definitions retain their original level/baseline combat attributes; current level is read from actor progression. Live resource maxima are projections, with original maxima retained in progression state. NEXT WAVE preserves the live actor; RESET reconstructs source defaults. No storage coordinator, cross-run saving, profile rehydration, XP purchase category or new character is enabled.

The existing panel shows LVL, EXP Type, EXPM, EXPC, next known threshold and latest HPM/Mana/AP maximum increases, explicitly noting unchanged current resources. Authoritative level events trigger refresh. Generic tests cover Ability Users; no automatic new AP is granted to Mana Users or existing fixed NPCs. Listed ability allowances and existing midnight refresh remain separate from the shared AP pool. Unsupported nonpositive growth remains blocked, without a fabricated floor.

Home acceptance (fresh local export): select Vaelis in DEV NORMAL, earn enough XP during combat, observe immediate level/maxima increases without healing or Mana refill; inspect history/next threshold; buy a verified SR increase without level loss; verify NEXT WAVE continuity, RESET restoration and TEST suppression. Browser acceptance is pending. The 28-October controlling DOCX copies still need local synchronization (checked local headers: specification v1.25, roadmap v1.26).

## Task 36G: Arena rewards and developer progression testing

Original creature-sheet EXP stays in `CREATURE_REWARDS`; `ARENA_XP_OVERRIDES` separately supplies 10/30/50/100/500 for Goblin/Spadoodle/Skelly/Hades/Gargoyle. Rare Human Warrior EXP remains source-blocked. Each award records source EXP, Arena base XP and multiplier; only NORMAL qualifies for base Arena XP and DEV NORMAL qualifies for ×10. TEST MODE suppresses XP/drop generation before reward RNG. Drop procedures, quantities and draw order are unchanged. NORMAL and DEV NORMAL both permit the same existing advancement and downtime inventory operations.

The existing setup selector cycles NORMAL, TEST Waves 1-5, Guard/Small fixtures, then `DEV NORMAL — XP ×10`. Developer NORMAL starts Wave 1 and follows the full circuit, keeps temporary XP/items/advancement through NEXT WAVE and clears them on RESET. This is unrelated to permanent saving; no storage caller is introduced.

## Task 36G: player potion access

Use the INVENTORY button during combat, expand INVENTORY / EQUIPMENT, select an identified Health/Mana Potion and press USE. The existing authoritative consumable scheduler handles a two-Act retrieve+drink action for stored player items (Prime printed p. 20); the existing resolver rolls 1d10+2 HPC or 3d6+2 Mana (p. 120), caps the appropriate maximum and decrements once at final completion. Vaelis is AT 1, so this composite action takes 10 seconds. An AT-2 actor would take five seconds; no hardcoded cooldown is added. Movement stays compatible under ordinary movement restrictions.

Both hands occupied is an explicit rejection. A character must already have a legal free hand; no weapon disappears automatically. Combat stowing/unequipping is not implemented without its verified transition. A player may prepare a legal one-handed loadout/free hand during downtime, then use potions in the next wave. Task 36G-Fix1 replaces the boss's old one-Act shortcut with the exact same carried-potion factory: retrieval plus drinking takes five seconds at his AT 2. Shared validation rejects one-Act carried-potion definitions and rechecks legal hands at completion, including rejecting a partially released two-handed weapon below its one-hand STR threshold. Separately retaining an interrupted retrieval as a held bottle is not implemented; interruption retains the unconsumed inventory item under the established completion-only consumption policy. UI messages/events show completed HPC/Mana values and remaining quantity; an action-start message does not claim the potion has resolved.

Prime p. 20 confirms equipping also costs an Act; pp. 127-128 require two hands for the Boar Spear below STR 30. Temporary one-hand carrying at the boss's STR 18 and combat stow/re-grip transitions are not established by these passages and remain unavailable, equally for players and NPCs. The AI never silently removes his spear: while wielding it he cannot drink, and after a legal throw/drop his real free hands can permit drinking. Existing movement-funded, one-Act spear retrieval/re-equipping and tactical decisions are unchanged.

Home checklist: cycle to DEV NORMAL and verify its visible label, Goblin XP 100 versus NORMAL 10, identical same-seed drops, purchase Vaelis SR only when affordable, verify no resource refill, NEXT WAVE continuity and RESET. Open combat inventory; confirm occupied-hand rejection, then test a legally prepared free hand across NEXT WAVE. Verify retrieval+drink countdown, interruption without consumption, Health versus Mana changes and quantity decrement. Space/Enter remain attacks. Combat ground-loot clicks remain gated. All Web checks require a fresh local export; no deployment or permanent saves occur in this task.

## Scope and authority

### Task 36G-Fix2 shared handling foundation

The owner now explicitly authorizes free stowing, one-hand holding of a two-handed weapon, and legal free re-gripping. These Arena adaptations supersede the preceding Fix1 unsupported-transition gate. The printed retrieval/drinking/equipping costs remain unchanged. `CombatWeaponHandling` is a pure generic planner; `CombatSimulation.request_weapon_handling` validates and commits free transitions or schedules a one-Act draw, including interruption and completion legality. Existing inventory buttons submit requests; the boss submits the same requests before/after justified potion use. No AI hand mutation or character-specific core permission is added.

Actor `weapon_handling` is an optional sparse schema-12 extension keyed by existing equipment reference: `stowed` and `one_hand_hold` are not attack-ready. Removing an override via a legal re-grip/draw restores readiness. Hand assignments remain authoritative, arm-mounted zero-hand bucklers remain zero-hand, and unknown anatomy remains unavailable. Stowed possessions remain in the assigned loadout, with their visible STOWED inventory entry; stack quantities and dropped world items are not duplicated. Unavailable weapon strikes and weapon Block/reactions are gated; other ready strikes retain ordinary timing and final reach/LOS checks.

Combat controls: open INVENTORY / EQUIPMENT, select the weapon, then STOW, HOLD ONE HAND, RE-GRIP or DRAW / EQUIP. Read labels READY — TWO-HANDED, HELD — ONE HAND, STOWED (or the one-handed equivalent). USE on a supported potion still performs two Acts. Free handling is rejected during a conflicting action. Combat draw is one Act; safe downtime retains the previously approved paused-clock equipment transaction with its required Act recorded. Space/Enter are unchanged.

Home checks: use a fresh local export; exercise Vaelis stow/draw and Guard/boss two-handed holding, potion completion/interruption, Block loss/restoration, no dropped marker on stow, preserved ground spear retrieval, NEXT WAVE continuity and RESET. No permanent storage is connected. Automated checks do not constitute browser acceptance.

Task 36A adds event-driven, within-run reward accounting to the existing authoritative `CombatSimulation`. Task 36B adds a bounded, source-verified spending transaction during safe downtime. Task 36C adds exact-definition equipment and consumable management during that downtime. Saved profiles, automatic leveling, account services and multiplayer reward allocation remain deferred.

Sources audited:

- ITank Prime V3 printed pp. 18-21 for EXPM/EXPC, derived-stat boundaries, field learning, failures and training time.
- ITank Prime V3 printed pp. 27, 46, 67 and 72 for S-number skill investment and Combat-ability repurchase examples.
- ITank Prime V3 printed pp. 87-89 and 99-102 for advancement boundaries, level thresholds, immediate spending and exact attribute/SR/TB/HSF/OSF costs.
- ITank Prime V3 printed p. 229 for ordered field levels, access restrictions and Special prerequisites.
- ITank Prime V3 printed pp. 361-373 and `Random Drops Complete.docx` for Random Drops and all verified nested charts.
- The supplied Common Goblin, Common Spadoodle, Common Skelly, Uncommon Hades Combat Follower and Uncommon Mini Gargoyle Swarmer records for creature-specific EXP, drop codes and carried equipment.

The protected Rare Human Warrior source is not read by Task 36A. Its XP and Random Drops remain blocked. Accepted pre-existing boss equipment and inventory resources may become physical possessions on defeat, including reuse of an already dropped Boar Spear, but they do not authorize a boss XP or generated-treasure value.

## Creature reward catalog

| Creature | Printed XP | Printed Random Drops | Other verified possession |
| --- | ---: | --- | --- |
| Common Goblin | 1 | B x2 | Natural fists; no retrievable held weapon |
| Common Spadoodle | 3 | C x1 | Natural claws; no retrievable held weapon |
| Common Skelly | 10 | C x1 | Natural claws; no retrievable held weapon |
| Uncommon Hades Combat Follower | 100 | C x1 | Short Sword |
| Uncommon Mini Gargoyle Swarmer | 500 | C x3 and A x1 | Natural attacks; no retrievable held weapon |
| Rare Human Warrior | blocked | blocked | Accepted existing equipment/inventory records only |

One qualifying defeat event produces one award. The ledger records the creature actor, wave, causal defeat event and cumulative earned/spent/unspent XP. Prime's printed default is a full XP award to each eligible participant unless an entry says `Split`; Task 36A has one player and does not invent co-op participation or allocation rules.

The supplied `Common Skelly.doc` is the authority for the Wave 3 creature and prints EXP 10/C x1. The Prime V3 PDF's Chapter Twelve summoned-skeleton entry is a different creature and must not silently replace the accepted Wave 3 sheet or its reward value.

## Random Drops implementation

`PrimeV3RandomDropResolver` implements the verified A, B, BM, BK, C, M, PS and RI entry charts. Follow-up results use the verified Potion, Scroll, Poison, Random Item, Armor, Weapon, Boots, Shield, ring/clothing MIUR and Book tables. Every die uses the continuing simulation RNG and records its chart label, die, value and RNG draw index.

Book results roll rarity with the V3 player-level gates and reroll an ineligible rarity until an eligible result is obtained. They then resolve the rarity-specific field table and printed level die. Because the Guard definition has no verified level, a Guard Book result stops at `player_level_required_before_book_rarity_roll` without consuming an invented rarity result. Vaelis has verified level 1.

The audited material does not define a separately named `Dice Drop` procedure or drop code. Task 36A therefore does not invent one: an unsupported `DICE` code fails before consuming RNG. This is distinct from the ordinary dice used to resolve every verified chart.

The following results intentionally stop at an authoritative intermediate record:

- Reincarnation Scroll, because its required follow-up chart is unfinished.
- Storyteller-created and cursed random items, because authored item facts are required.
- Ring/clothing Imbuer outcomes after verified MIUR/category rolls, because the complete legal Imbuer effect selection is not yet integrated.

## Ground items and collection

Random treasure and creature possessions use separate provenance. Ground records retain a stable ID, item definition, quantity, source actor, causal event, authoritative microfeet position, allocation/collection state and provenance. Collected records remain in history as `collected` rather than being recreated or silently deleted.

Collection is available only during safe between-wave downtime. The player must be alive and within one foot, and collision-resolved contact must be reachable through the authoritative battlefield; remote and through-wall pickup fails. Collection does not make an item automatically usable or equipped. Uncollected records and collected inventory quantities remain in the same simulation across NEXT WAVE. RESET reconstructs the selected fixture and clears the temporary run ledger and world items.

Prime V3 does not provide a verified generic ground-pickup Act cost in the audited passages. Task 36A therefore authorizes collection only in untimed safe downtime and does not introduce a combat-time pickup action. The existing one-Act Boar Spear retrieval is a separate previously approved Arena rule and remains unchanged.

## Modes, snapshots and presentation

NORMAL mode resolves verified XP and Random Drops and retains them through the five-wave circuit. Developer TEST MODE records reward suppression without consuming reward RNG or creating permanent treasure. The default Normal launcher and all developer selectors remain separate.

Reward state is an additive `reward_state` field in schema-12 snapshots; the schema number and all existing fields remain unchanged. Reward and ground-item events use the existing stable event-ID, causal-parent and ordered publication paths. The between-wave panel reads this state and lists wave/cumulative XP plus collected and uncollected ground items. `COLLECT NEAREST LOOT` submits one authoritative collection request; it does not move the player or bypass reach.

## Advancement transactions

Prime separates total earned EXPM from currently spendable EXPC. Arena therefore keeps `earned_xp` unchanged, appends immutable successful purchase records, increases `spent_xp`, and derives available XP as earned minus spent. Each request has a stable identifier. A duplicate accepted identifier, stale value, invalid target, failed prerequisite or insufficient balance changes no XP, actor state, RNG or history.

Prime printed p. 102 permits accumulated XP to be spent immediately or later. A one-point Attribute, SR or TB increase uses the bracket containing the current value: 1-5 costs 2,000; 6-10 costs 3,000; 11-15 costs 5,000; 16-20 costs 7,000; 21-30 costs 8,000; and 31+ costs 10,000. APP is excluded. The same page's complete HSF and OSF target-level tables remain in the catalog.

Task 36B activates only Vaelis Thorn's SR 1 to SR 2 transaction. Her supplied source record explicitly contains SR 1, and this resistance increment changes no derived combat statistic or renewable maximum. The transaction consequently preserves current HPC, Mana, conditions, active effects, equipment, inventory and actions without refilling anything. It consumes no RNG. RESET reloads the immutable SR 1 fixture because permanent profiles are not implemented.

All other categories fail closed while retaining known costs and requirements:

- TB 0 has no printed current-value cost because the p. 102 chart begins at 1.
- Core Attributes require complete source-backed recalculation; DEX additionally needs an explicit DT/DP allocation, and WIS needs an authoritative Mana/magic recalculation policy. APP is excluded from the generic chart.
- Skills consume S-number investments in the printed rules; no general EXPC price was verified.
- HSF/OSF require ordered field progress, study/instruction clocks, character field records, and for OSF the spend-before-SS-check failure and one-character-week retry lockout.
- Special/ability repurchases require a verified field level, daily cadence, legal access and per-character allowance record.

The safe-downtime panel lists earned, spent and available XP, current/proposed values, exact known costs, disabled reasons and successful history. The player must select an option and press `CONFIRM XP PURCHASE`. NORMAL mode alone can submit the request. TEST MODE cannot advance a character, and no purchase occurs automatically after a defeat or wave.

## Inventory and equipment transactions

Damaged or destroyed shields cannot currently be moved into quantity-only storage: the request fails closed to prevent SHP restoration on re-equip. An unchanged equipped shield retains its current SHP. Equipping an already equipped definition is rejected without consuming a spare.

Home testing checklist: use a fresh local Web export; complete a NORMAL wave, inspect loot names/quantities/origins, collect within one foot, equip an exact item, verify replacement and resource preservation, use an identified Health/Mana Potion with a free hand, advance once and verify persistence, then RESET. Check panel readability and keyboard focus at desktop and landscape mobile sizes. Abstract drops must show a blocked reason. TEST MODE remains isolated. Public Pages currently runs the previously deployed build and does not establish acceptance of Tasks 36A-C.

Task 36C adds collected and equipped item identities, quantities, category, verified magical status, source references, requirements and source gates to that same NORMAL-mode downtime panel. `EQUIP / UNEQUIP` and `USE` submit authoritative requests; presentation never mutates inventory locally. TEST MODE rejects them and RESET reconstructs the selected immutable fixture.

An exact registered weapon, armor or shield uses one atomic transaction. The proposed set is validated for STR, equipment slot overlap and hand occupancy before any quantity changes. Success moves quantities exactly once, rebuilds the player's attack, Block and location-protection profiles, recalculates armor MR/DT/projectile-Dodge from immutable base values, and preserves HPC, Mana/AP, conditions and effects. Failure changes nothing. Removing the last player weapon remains blocked because a general playable-character unarmed sequence is not source-integrated.

Only identified Health Potions (`1d10+2 HPC`) and Mana Potions (`3d6+2 Mana`) are usable. Their rolls use the continuing combat RNG and ordered events record draws, quantity and capped resource values. Other potion IDs, abstract Random Drop item categories, battlefield dropping and encumbrance remain visible but unavailable. Thrown/dropped Boar Spear state remains exclusively under its existing world-item and retrieval transaction.
