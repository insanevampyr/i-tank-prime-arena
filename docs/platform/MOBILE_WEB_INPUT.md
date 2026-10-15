# Mobile Web Input and Responsive Presentation

## Scope

Phase 1 Task 13 established touchscreen movement. Phase 1 Task 14 adds the first controlled physical-attack interface, and Task 15 adds mouse/touch encounter start/reset plus the two-way controlled encounter without creating a second rules implementation.

The authoritative movement and Running model remains `PrimeMovementModel`. Desktop and touch presentation are reduced to the same two intents before the model advances:

- movement direction;
- Running held or released;
- one-shot ordinary physical-attack request.

No touch handler rolls dice, spends resources, schedules combat events, resolves criticals, or mutates combat actors.

## Working controls

| Control | Desktop | Touch/Web | Integration |
| --- | --- | --- | --- |
| Movement | WASD | Lower-left virtual joystick | Existing deterministic movement request |
| Running | Hold Shift while moving | Hold lower-right RUN while moving | Existing Running activation, maintenance, cap, recovery and stop path |
| Select opponent | Click opponent or press Tab | Tap opponent | Presentation selection only; authority validates the actor at attack request |
| Ordinary attack | Space or Enter | Tap lower-right ATTACK | Shared `ArenaCombatSession.request_player_attack` path |
| Start/reset encounter | Click START/RESET or press R to reset | Tap START/RESET | Rebuilds the owned simulation with the original fixture positions and seed |

Joystick, RUN, and ATTACK use independent touch indexes. ATTACK emits one request per press and cannot become a held duplicate stream. Releasing one finger does not release the others. A browser-canceled touch, viewport resize/rotation, application pause, or focus loss clears all captured touch state to prevent stuck movement or stale attacks.

## Deliberately unavailable controls

Only the source-verified fixture's ordinary Battle Axe torso attack is exposed. If the player is prone, the existing ATTACK action input requests the verified one-Act stand instead of submitting an illegal attack. Aiming at other body locations, manual defense choices, Specials, NACs, inventory, loot, EXP, progression and general opponent commands remain unavailable. Defenses and eligible Critical Reactions run through the configured authoritative automation; the UI does not offer buttons that would imply unsupported player choices.

## Responsive layout contract

- Landscape phone screens are preferred.
- Control circles stay inside the viewport and use a minimum 96 logical-pixel diameter.
- Status text occupies the upper-left safe area and ends before the lower touch-control zone.
- The joystick remains lower-left; RUN and ATTACK remain in the lower-right action area with deterministic positions derived from viewport size.
- Portrait remains safe and shows a landscape recommendation; rotating clears active touches before recomputing layout.
- The Web fallback displays touch controls on narrow canvases even when desktop browser emulation does not report touchscreen capability. Native desktop and wide non-touch Web presentation stay uncluttered.

## Validation boundary

Automated tests synthesize independent touch indexes, one-shot ATTACK behavior, release/cancel behavior, focus-reset behavior, resize/rotation reset, desktop intent preservation, and Android-sized layout calculations. Browser viewport automation can verify rendering, resizing, selection, and attack presentation but does not prove physical touchscreen behavior, Chrome Android GPU/driver behavior, OS gesture interference, thermal performance, or device-specific safe areas.

Use the LAN procedure in `WEB_COMPATIBILITY.md` for the required physical Android check. A physical-device pass must explicitly record device model, Android/Chrome versions, orientation, console errors, simultaneous joystick/RUN behavior, app-switch recovery and observed frame rate.
