# Mobile Web Input and Responsive Presentation

## Scope

Phase 1 Task 13 established touchscreen movement. Phase 1 Task 14 adds the first controlled physical-attack interface, and Task 15 adds mouse/touch encounter start/reset plus the two-way controlled encounter without creating a second rules implementation.

The authoritative movement and Running model remains `PrimeMovementModel`. Desktop and touch presentation are reduced to the same two intents before the model advances:

- movement direction;
- Running held or released;
- ordinary physical-attack intent, either one-shot or locally held.

No touch handler rolls dice, spends resources, schedules combat events, resolves criticals, or mutates combat actors.

## Working controls

| Control | Desktop | Touch/Web | Integration |
| --- | --- | --- | --- |
| Movement | WASD | Lower-left virtual joystick | Existing deterministic movement request |
| Running | Hold Shift while moving | Hold lower-right RUN while moving | Existing Running activation, maintenance, cap, recovery and stop path |
| Select opponent | Tab / Shift+Tab cycle living targetable enemies; click empty terrain to clear | Tap opponent | Touch selection remains separate from ATTACK; authority validates the actor at attack request |
| Select aim location | Top-row or numeric-keypad 1-9 | Not yet exposed as a touch control | Selection is presentation/input state only; it consumes no Act, does not attack, and is locked into the attack record at declaration |
| Ordinary attack | Left-click opponent once, or press/hold Space or Enter | Press/hold lower-right ATTACK | Every accepted declaration uses `ArenaCombatSession.request_player_attack`; desktop click remains exactly one request |
| Start/reset encounter | Click START/RESET or press R to reset | Tap START/RESET | Rebuilds the owned simulation with the original fixture positions and seed |

Joystick, RUN, and ATTACK use independent touch indexes. ATTACK emits its initial request on press and retains local intent while that same touch remains held; it can request another attack only when authority reports a new declaration legal. Releasing one finger does not release the others. A browser-canceled touch, viewport resize/rotation, application pause, focus loss, FULL LOG, RESET, or encounter change clears held attack state to prevent stale repetition.

The default HUD contains concise movement/Running status, HPC, target, legality, conditions and important combat results. Detailed timestamps, event IDs, path diagnostics and complete formatted event history remain available through the DEBUG button or desktop F3 key and are hidden by default. This presentation split does not delete or filter the authoritative event source.

Task 19 adds passive ATTACK and RUN readiness rings above the combat-results region. They are not touch targets and do not replace ATTACK or RUN. ATTACK reads the ordinary action's scheduled timestamps and current legality. RUN reads the existing movement model's automatic-skill, endurance, recovery and retry state. Focus loss clears captured touches and prevents a stale READY presentation; returning focus recalculates from current state.

## Deliberately unavailable controls

The source-verified same-size Guard fixture exposes Prime locations 1-9 through desktop number keys. Location 8 uses the approved Arena subdivision: the first 8 press selects Knee, the next selects Lower Leg, and subsequent top-row or keypad presses alternate. Selecting another number resets the next 8 press to Knee. Knee and Lower Leg enter the same ordinary Battle Axe pipeline as the other locations; the declared subdivision determines exclusive knee-armor or leg-armor TAL. No location selector is currently exposed on touch. If the player is prone, the existing ATTACK action input requests the verified one-Act stand instead of submitting an illegal attack. Manual defense choices, Specials, NACs, inventory, loot, EXP, progression and general opponent commands remain unavailable. Defenses and eligible Critical Reactions run through the configured authoritative automation; the UI does not offer buttons that would imply unsupported player choices.

## Responsive layout contract

- Landscape phone screens are preferred.
- Control circles stay inside the viewport and use a minimum 96 logical-pixel diameter.
- Status text occupies the upper-left safe area and ends before the lower touch-control zone.
- Passive ATTACK and RUN readiness rings occupy a responsive status region above combat results and never intercept touch input.
- The joystick remains lower-left; RUN and ATTACK remain in the lower-right action area with deterministic positions derived from viewport size.
- Portrait remains safe and shows a landscape recommendation; rotating clears active touches before recomputing layout.
- The Web fallback displays touch controls on narrow canvases even when desktop browser emulation does not report touchscreen capability. Native desktop and wide non-touch Web presentation stay uncluttered.

## Validation boundary

Automated tests synthesize independent touch indexes, held ATTACK cadence, release/cancel behavior, focus/reset behavior, resize/rotation reset, desktop click's one-shot boundary, and Android-sized layout calculations. Browser viewport automation can verify rendering, resizing, selection, and attack presentation but does not prove physical touchscreen behavior, Chrome Android GPU/driver behavior, OS gesture interference, thermal performance, or device-specific safe areas.

Use the LAN procedure in `WEB_COMPATIBILITY.md` for the required physical Android check. A physical-device pass must explicitly record device model, Android/Chrome versions, orientation, console errors, simultaneous joystick/RUN behavior, app-switch recovery and observed frame rate.

## Task 20 encounter log controls

`FULL LOG` opens the complete scrollable encounter transcript on desktop and landscape mobile-sized Web viewports; F4 is the desktop shortcut. `COPY LOG` requests the browser clipboard from that explicit button gesture. If permission is denied, the panel reports the denial and `SAVE LOG` remains available as a UTF-8 browser download. The recent-results panel remains intentionally compact. Physical Android verification remains deferred.

## Task 21 floating combat text

Committed combat outcomes also appear as short noninteractive labels above the affected combatant. They follow authoritative actor presentation positions, use bounded visual lanes, stay inside the visible canvas where practical, and do not replace the compact results panel or FULL LOG. The labels are presentation-only: touch, mouse, keyboard, Running, ATTACK, and RUN continue using their existing authoritative paths. Physical Android readability remains deferred.
