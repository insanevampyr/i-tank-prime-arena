# Nine-Location Targeting

## Authority and scope

Phase 1 Task 27 adds a data-driven location profile to the existing physical-attack definition. The current profile is explicitly valid only for same-sized combatants. Other size relationships require their own verified profile; the same-size ACC values are never installed as universal defaults.

The selected enemy and selected location are input state until an attack is declared. Declaration copies both identifiers into the authoritative attack instance. Changing either selection afterward cannot redirect an executing attack. Selection alone schedules no action, spends no Act, consumes no RNG and does not interrupt movement.

## Same-size Prime profile

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

The ACC chart and head/neck multipliers come from Prime V3's physical attack and hit-location rules (pp. 95-98). Armor coverage comes from the owner's Task 27 clarification grounded in the Prime V3 Armor Chart (p. 135) and anatomical diagram.

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

Location identifiers, ACC modifiers and rational location multipliers live in the attack definition used by the authority. The declared event carries the locked location. Replay and simulated clients consume that event stream; UI selection notifications are deliberately excluded from authoritative logs and digests.
