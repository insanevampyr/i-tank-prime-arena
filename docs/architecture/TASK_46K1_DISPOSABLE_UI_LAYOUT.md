# Task 46K-1 — Disposable v3 UI layout correction

## Status

Complete. UI-only correction in the existing isolated disposable scene. No persistence, codec, storage, combat, progression or production-controller changes.

## Exact changed files

- `scripts/ui/disposable_v3_arena.gd`
- `tests/disposable_v3_playable_probe.gd`
- `tests/browser/test_disposable_v3_playable_edge.js`
- `docs/architecture/TASK_46K1_DISPOSABLE_UI_LAYOUT.md` (this report)

No scene or UID change was necessary.

## Cause and layout/input changes

The disposable PanelContainer was added directly beneath the HUD UI Control in the existing CanvasLayer. It had fixed top-right offsets (top 90), outside ArenaResponsiveLayout's placement of status/log/toolbars. It remained visible after START, and its full rectangle was tested by the attack blocker without checking visibility. The expanded VBox could therefore cover combat/HUD content and the hidden rectangle could still veto attacks.

The same inherited production interface is retained; only its disposable subclass changes presentation:

- The toolbox now opens above a bottom-right `V3 SAVE TOOLS` toggle, using bottom anchors rather than an unmanaged top-right overlay.
- Successful admission, START and NEXT WAVE close the toolbox. Save, retry, load/resume and confirmed NEW RUN remain the same existing buttons/callbacks.
- Save status lives outside the collapsible panel in a separate bounded footer, beside rather than beneath the toggle. `NOT SAVED / RECOVERY REQUIRED` and pending acknowledgement messages remain visible when closed.
- Status uses MOUSE_FILTER_IGNORE; the visible toolbox uses STOP; buttons use FOCUS_NONE, including namespace selection. Closing releases any focus still inside the toolbox.
- Attack hit testing checks panel visibility before its rectangle. Escape closes the toolbox through the existing unhandled-input boundary.
- Inventory and the toolbox are mutually exclusive. Opening tools closes inventory; opening inventory closes tools.
- The inherited verbose combat-status label and event-log overlay are hidden in this scene only. FULL LOG and explicit DEV diagnostics remain available. Original production interface files and their responsive-layout rules are untouched. Standard movement/readiness/world labels remain.

The owner's screenshot bytes were not attached to this turn. Diagnosis used the reported context, actual scene/controller/layout source, and newly rendered screenshots rather than claiming inspection of that missing image.

## Focused verification

All final runs use the same unchanged persistence/combat assertions plus additional UI/input assertions:

| Actual runtime | Resolution | Final checks | Result |
|---|---|---:|---|
| Windows Godot 4.7.2 desktop window, debug | 1280×900 | 204 | PASS |
| Windows Godot 4.7.2 desktop window, debug | 1664×935 | 204 | PASS |
| Isolated Edge, Godot release-WASM | 1280×900 | 204 | PASS |
| Isolated Edge, same release-WASM export | 1664×935 | 204 | PASS |

Covered NORMAL and DEV creation, START, original WASD movement via physical-key Input events, keyboard attacks, original inventory equip/unequip/stow/potion use, irreversible zero-quantity ownership, earned XP, save failure and exact retry, exit/reload, NEXT WAVE, genuine earned-EXPC END purchase, NEW RUN retaining progression, visible/non-overlapping footer controls, actual CHARACTER MENU opening, mutually exclusive tools/inventory and focus release. Rendered control rectangles are allowed to settle before pointer input, preserving #46K's corrected browser test.

These remain disposable persistence fixtures: opponents are wounded/positioned by the established fixture, and a source-backed potion is acquired through original loot APIs. This is not an ordinary-difficulty playthrough or owner-data acceptance. The WASD step explicitly performs the normal movement-lock presentation update before manually stepping the player because the fixture disables autonomous controller stepping. No gameplay assertion was removed or weakened.

Final logs contain no accepted script/JS runtime errors. `node --check` and `git diff --check` pass (only existing unrelated CRLF notices). An initial controller field-name parse error was corrected (`_event_log` is the inherited field); an initial movement test failed because the manually stepped fixture had not refreshed the normal movement lock. Failed attempts are preserved and are not reported as successful runs.

## Visual evidence and commands

Evidence root: `C:/Users/mxz/AppData/Local/Temp/arena46k1-ui/`.

Final Windows results/logs/screenshots:
- `final1280.json`, `final1280.log`, `final1280.json.png`
- `final1664.json`, `final1664.log`, `final1664.json.png`

Final actual Edge results/logs/screenshots:
- `edge-final1280.json`, `edge-final1280.log`, `edge-final1280.png`
- `edge-final1664.json`, `edge-final1664.log`, `edge-final1664.png`

The screenshots at both sizes were visually inspected: creation controls are absent during combat; the combat field is clear of the disposable toolbox and verbose stats/log panels; status and toggle are readable and separate. World-space actor labels can still coincide when fixture actors cluster; their original placement was deliberately not changed. No such label prevents control use. Sub-desktop/mobile layouts and a fresh human owner playthrough remain unverified.

Native commands used the existing #46K driver with new disposable slots, `--resolution 1280x900` / `1664x935`, and the actual desktop renderer (not headless). Browser command:

```powershell
node tests/browser/test_disposable_v3_playable_edge.js
$env:ARENA_UI_WIDTH='1664'; $env:ARENA_UI_HEIGHT='935'
node tests/browser/test_disposable_v3_playable_edge.js --reuse
```

Only the OS-TEMP diagnostic project was exported. The second Edge run reused exactly the same release artifact; no production export, BUILD publication or deployment occurred. Each browser run used a new isolated user-data directory and loopback origin. Production IndexedDB was never opened.

## Preservation and owner checklist

Branch `main`, HEAD `f9bb0db0235b0003895c477a12346191d4714469`; staged index remains empty. Exact path-only final status is retained in the evidence root's `git-status.txt`. Existing dirty work remains intact.

Task-entry hashes confirm unchanged `project.godot`, `minimal_character_transactions.gd` and `character_persistence_coordinator.gd`. `project.godot` retains SHA-256 `8398f110f77d7712eb19c283eb9f745c7123feab9557187778da412639ba5692`. No owner profile, backup, production browser data, protected boss source, `character saves/` or repository `tmp/` was accessed. No Roadmap/Combat Specification edits, Git mutations, storage changes or #45U resumption.

Owner: launch the same alternate scene with a disposable slot, create/load the disposable character, START, verify WASD/attack; use CHARACTER MENU for inventory; use the bottom-right V3 SAVE TOOLS toggle for checkpoint/retry/NEW RUN. Close it with the toggle or Escape. Treat NOT SAVED/RECOVERY REQUIRED as an unacknowledged save and use its existing exact retry path.

**GO for resuming the owner's manual disposable-character test. STOP after #46K-1.**
