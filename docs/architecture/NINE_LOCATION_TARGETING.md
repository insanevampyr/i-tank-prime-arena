# Nine-Location Targeting

## Authority and scope

Phase 1 Task 27 adds a data-driven location profile to the existing physical-attack definition. Task 28 extends that profile with the source-verified directional attacker-to-target size catalog. Same-size values are retained only for same-sized non-Tiny combatants; they are never installed as universal defaults.

The selected enemy and selected location are input state until an attack is declared. Declaration copies both identifiers into the authoritative attack instance. Changing either selection afterward cannot redirect an executing attack. Selection alone schedules no action, spends no Act, consumes no RNG and does not interrupt movement.

## Prime size profiles

`CombatHitLocationCatalog` stores the six ordinary Prime size categories: Small, Medium, Large, Extra Large, Gigantic, and Enormous. It resolves an explicit `attacker_size_to_target_size` relationship before a size-aware attack can be declared. Missing or unsupported actor sizes fail closed; the resulting relationship, attacker size, target size, and modifier are copied into the authoritative attack instance. This preserves replay even if later data selection changes.

The matrices are directional. For example, `Small to Medium` and `Medium to Small` are independent rows. The six same-size combinations use the printed `SAME SIZE` column. Both Task 27 location-8 subdivisions use the one printed location-8 value for their resolved relationship.

Tiny is deliberately not represented as an ordinary seventh matrix category. Prime states that Tiny attacks have no hit-location ACC change, and that attacks against Tiny also have no hit-location ACC change; it separately grants Tiny `+2` Dodge against Small, with `+1` for each attacker size category larger. The catalog records that Dodge bonus on the declared attack so the established Dodge path—not a cosmetic client—uses it.

The Extra Large attacker table's final printed header says `L to E`. Its matrix position and every surrounding header make this a printing error; it is transcribed as `XL to E`. No values were extrapolated.

### Same-size profile

| Key | Prime location | ACC modifier | Owner-confirmed armor slot | Damage status |
| --- | --- | ---: | --- | --- |
| 1 | Head | -3 | Head | Supported; x1.5 location multiplier |
| 2 | Neck | -5 | Head | Supported; x1.5 location multiplier |
| 3 | Torso | 0 | Torso | Supported |
| 4 | Shoulders / Upper Arms | -1 | Arms | Supported |
| 5 | Elbows | -2 | Elbows | Supported |
| 6 | Hands | -3 | Hands | Supported |
| 7 | Groin / Upper Legs | -2 | Legs | Supported |
| 8a | Knee | -3 | Knees | Supported; approved Arena subdivision |
| 8b | Lower Leg | -3 | Legs | Supported; approved Arena subdivision |
| 9 | Feet | -4 | Legs | Supported |

The ACC chart and head/neck multipliers come from Prime V3's physical attack and hit-location rules (pp. 95-98). Directional size matrices and the Tiny exception are on pp. 95-97. Armor coverage comes from the owner's Task 27 clarification grounded in the Prime V3 Armor Chart (p. 135) and anatomical diagram.

Elbows, knees and hands are distinct equipment slots. The shared Armor Chart section supplies their statistics; it does not define one combined worn item. Head armor covers Head and Neck. Leg armor covers Groin/Upper Legs, lower-leg portions and Feet. Knee and leg TAL must never stack for one hit.

## Approved location 8 subdivision

Prime V3 inspection found no rule that subdivides the combined Knees/Lower Legs ACC result between knee armor and leg armor. The owner therefore approved an Arena input adaptation: the first 8 press selects Knee, the second selects Lower Leg, and further presses alternate. Top-row and keypad 8 share one sequence. Selecting any other numbered location resets the next 8 press to Knee.

Both subdivisions retain Prime's same-size location 8 ACC modifier of -3. Knee attacks use only armor explicitly covering `knee`; Lower Leg attacks use only armor explicitly covering `lower_leg`. Missing matching armor contributes zero TAL, while NAL and existing damage-type protection continue normally. The two armor slots never stack. No random subdivision roll exists.

## Controls and presentation

- Tab cycles forward through living targetable enemies; Shift+Tab cycles backward using stable actor-identifier ordering.
- Top-row 1-9 and numeric-keypad 1-9 select the matching location. Physical keypad identity is honored when Num Lock reports a navigation key. Both 8 keys operate the same Knee/Lower Leg cycle.
- Mouse selection and click-to-attack remain unchanged.
- Selection changes produce brief local floating confirmations. They are not authoritative combat events and there is no persistent target-location HUD.
- Approach-capable declaration and final range/line-of-sight validation remain unchanged.

## Determinism

Location identifiers, source-resolved size relationship, ACC modifiers and rational location multipliers live in the attack definition and instance used by the authority. The declared event carries the locked location and size context. Replay and simulated clients consume that event stream; UI selection notifications are deliberately excluded from authoritative logs and digests.

Task 29 exposes this same authority path through an opt-in `MEDIUM vs SYNTHETIC SMALL` development encounter. The synthetic fixture and launch controls are documented in `PLAYABLE_DIFFERENT_SIZE_COMBAT.md`; it does not change this targeting model or claim a printed Prime creature identity.
