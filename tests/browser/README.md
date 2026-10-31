# Task 36K browser storage and playable persistence verification

## Pass2 actual playable Edge procedure

The game now enables verified Vaelis Web saving. **Do not use production profiles for destructive tests.** The separate acceptance export injects a disposable database factory before instantiating the real game scene. It uses the actual controller, buttons, session, source admission, projection, coordinator and JavaScriptBridge/IndexedDB; only test scenario defeat/resource fixtures are synthetic. Simulation time is explicitly driven in the fixture, so this is automated integration evidence, not a manual combat playtest or long-session performance test. The ordinary export does not contain these test controls or read a test database name from its URL.

From the repository in PowerShell:

```powershell
$godot = 'C:\Users\mxz\Desktop\GoDot\Godot_v4.7.2-stable_win64_console.exe'
& $godot --headless --path . --script res://tests/test_runner.gd -- '--suite=Task 36K-Pass2'
& ./tests/browser/prepare_playable_web.ps1 -Godot $godot
python -m http.server 8767 --bind 127.0.0.1 --directory (Join-Path $env:TEMP 'itank-arena-36k-playable-web/out')
```

1. Open `http://127.0.0.1:8767/index.html?test=YOUR-FRESH-TOKEN` in Edge. Use a new identifier-like lowercase token for a fresh lifecycle. Only `itank-arena-test-36k-playable-TOKEN` is used; the application production database is untouched.
2. Click **Run DEV lifecycle**. Expect 21 passing checks: explicit admission, exact acknowledged generation, actual Force Shield casting, completed-wave save/collection, real IDB abort retaining the old downtime snapshot, exact retry, Waves 2/3, resource/Shield continuity, visible Wave-3 defeat buttons, and RETRY/RETURN retaining secured progression with approved new-run restoration. Loading/publication checks keep the real player movement/recovery physics enabled and verify its pause alongside combat time and status feedback. Open the same URL/token in another tab and click **Run NORMAL lifecycle**; expect another 21 checks and byte-for-byte preservation of the other namespace's saved document. NORMAL and DEV may hold their separate profile locks simultaneously.
3. Reload the actual page and click **Load saved DEV character**. Expect exact saved entry resources, XP, inventory, growth, generation/run identity, schema-12 convergence and intact event history. Expected-value metadata in `sessionStorage` is test evidence only, not the character store. A fresh tab has no such metadata but still checks application against its validated stored boundary.
4. With A loaded, open the same URL/token in tab B and click **Load saved DEV character**. Expect contention rejection and no replacement starter. Close A; click **Retry blocked storage** in B. Expect successful load and convergence after native lock release.
5. With a saved entry loaded, click **Test ambiguous acknowledgement**. Expect two checks: a real committed write with injected lost acknowledgement reports **Recovery required**, then the actual retry reconciles the exact saved generation without a second publication or duplicate XP/items. Reload and load again; exact downtime resources/progression must return. Click **Advance loaded downtime** to verify NEXT WAVE after hydration, then reload/load the new entry.
6. With a saved entry loaded, click **Prepare pending reload**. It deliberately holds a disposable publication before its transaction begins. Wait for **READY FOR RELOAD OR TAB CLOSE**. Reload the actual page, then load again: the prior generation/entry and secured progression must return, discarding the test's unsecured resource/reward changes. Repeat with actual tab closure and a fresh tab. This is a controlled interruption test, not proof of all OS/crash commit timings; raw transport tests independently cover actual transaction abort and committed-but-lost acknowledgement. **Load saved NORMAL character** provides the corresponding NORMAL reload checks. Per-mode `sessionStorage` expectations are test evidence, never the save implementation.
7. Stop only your own test server and close disposable tabs. Leave test generations as evidence; never clear unrelated browser data.

Pass2 native tests also cover NORMAL/DEV/TEST/Guard through actual controls, repeated run identities, corruption refusal/cancel, lost acknowledgement reconciliation without a second publication, frozen transition clocks and source snapshot equality. The browser transport suite now expects **37 checks** (the original 33 plus shutdown drain/release checks). Desktop suites and replay/sync commands from Pass1 below remain applicable. No full regression is claimed by these focused commands.

Home checks still required: a fresh ordinary Web export and manual NORMAL/DEV selection/play on the intended origin; ordinary mouse/touch/UI readability; full browser shutdown/restart; private mode/site-storage denial; realistic quota/eviction; long-session play; five-wave completion and post-completion NEW RUN. Do not interpret a site on another port/host or the previously deployed GitHub Pages build as the same storage origin or current code. Browser saves can be deleted/evicted and are not off-device backups. Unsupported/corrupt data never authorizes silent starter replacement.

### Final continuation verification, 2026-10-30

Actual Edge, final isolated Godot export: **20/20 DEV + 20/20 NORMAL lifecycle checks passed** in the same disposable database. Both namespaces reloaded exactly. Competing DEV tab rejection, writer-close/reacquisition, committed-but-lost acknowledgement reconciliation, reload of settled downtime, NEXT after hydration, Wave-2 entry reload, and reload/close while an uncommitted write was pending passed. No owner production profiles were used. Earlier successful current-transport evidence remains **37 core + 9 multi-tab/reopen assertions**, plus the exported Godot JavaScriptBridge smoke; those unchanged checks were not unnecessarily rerun in this continuation.

Native Pass1/Pass2, desktop Pass5 and synchronization rechecks passed, with no ObjectDB/retained-resource warnings. The previously completed affected persistence/contract/storage/wave suites remain recorded separately; no full regression is claimed. Final Godot import and headless startup passed. Browser tests use real IndexedDB/Web Locks and real controller callbacks, but synthetic combat/resource setup; human gameplay acceptance and the home checks above remain pending.

### Pass2 file inventory (in addition to preserved Pass1)

Changed existing runtime files: `scripts/combat/arena_combat_session.gd`, `scripts/ui/arena_combat_controller.gd`, `scripts/rewards/playable_character_persistence.gd`, `scripts/rewards/character_browser_storage.gd`, `scripts/rewards/character_browser_store.js`, `export_presets.cfg`.

New: `scripts/rewards/playable_browser_persistence.gd` and `.gd.uid`; `scripts/rewards/browser_wave_candidate.gd` and `.gd.uid`; `tests/test_playable_browser_persistence.gd` and `.gd.uid`; `tests/browser/playable_persistence_acceptance.gd` and `.gd.uid`; `tests/browser/prepare_playable_web.ps1`.

Test/docs: `tests/test_runner.gd`, `tests/browser/character_storage_harness.js`, this `README.md`, `docs/architecture/CHARACTER_PERSISTENCE_CONTRACT.md`, `docs/architecture/CHARACTER_STORAGE_INFRASTRUCTURE.md`, `docs/rules/RULES_LEDGER.md`. Save-contract and desktop-storage implementations, combat formulas, creature definitions, manuscript/protected files and deployment workflow are unchanged. Existing uncommitted Pass1 files remain preserved.

## Fix1: verify the ordinary exported game before acceptance

2026-10-30 owner failure: the `builds/web/index.pck` served on `localhost:8000` was timestamped 14:12, before the later playable Web integration. Mounting that actual PCK with Godot found the browser JS/service, but its exported controller lacked `_begin_browser_load`. It therefore ran the earlier nonpersistent Web path: reaching Wave 3 did not establish a saved character, and defeat correctly had no verified entry from which RETRY/RETURN could be authorized. Source/isolated-fixture success had not established that the ordinary game export was current. Rebuilding the ordinary preset fixes the missing integration; no recovery authorization bypass is warranted. Unsaved progression in the obsolete game cannot be silently converted into a verified checkpoint.

The fresh ordinary Edge game on isolated origin `127.0.0.1:8771` created a DEV profile, completed Wave 1 with real input/combat, collected loot, used the authorized DEV refresh and entered Wave 2. Real Wave-2 defeats displayed both buttons; RETRY restored 20 HPC / 40 Mana and RETURN restored Wave 1 with the secured progressed character. A competing ordinary tab reported **Character currently open in another tab** and **RETRY STORAGE** rather than starting Vaelis. Independent NORMAL admission asked to create its own profile. These tests used the ordinary export's storage on a separate disposable origin, never the owner's `localhost:8000` data. Full human Wave-3 combat acceptance remains an owner check; the actual-browser automated fixture separately passed the complete two-wave/defeat/RETRY/RETURN path with synthetic enemy defeat and exact resource assertions.

Fix1 also corrects a real feedback issue: `CombatStatus` displayed at most four lines although persistence feedback occupied line five. It now allows five and puts the storage acknowledgement/error before long messages; the tooltip includes the exact storage reason. Focused tests first reproduced this clipping failure, then passed after correction. Native/button tests and the browser lifecycle assert actual recovery-control visibility, not only callback effects.

Always rebuild and inspect the **ordinary** pack, in addition to fixture tests:

```powershell
& $godot --headless --path . --export-release Web builds/web/index.html
& $godot --headless --path . --script res://tests/browser/verify_playable_web_export.gd
```

The verifier mounts the exported PCK in a disposable process, checks required browser/authored resources, compiled async/recovery callbacks and the scene's visible storage-status line. It reads no profiles and changes no save state. It is an integration-content guard, not a generic source/build freshness guarantee or replacement for Edge testing. After export, reload the complete page (Ctrl+F5 if needed); do not clear browser storage or delete profiles. Confirm **Progress saved** before play, and explicit **RETRY STORAGE** on unavailable admission. On persistent defeat confirm **RETRY WAVE** and **RETURN TO WAVE 1**. Guard/TEST remain nonpersistent. Site/port changes select separate storage origins.

Fix1-specific source files: `scenes/test_arena.tscn`, `scripts/ui/arena_combat_controller.gd`, `tests/test_playable_browser_persistence.gd`, `tests/browser/playable_persistence_acceptance.gd`, this README, and new `tests/browser/verify_playable_web_export.gd` / `.gd.uid`. Generated `builds/web` artifacts are rebuilt locally and remain untracked/ignored; do not stage them.

Final Fix1 checks: 12 focused native suites passed (36K Pass1/2, desktop 36J Pass5 and Fix1/2/3, 35J waves/spear, synchronization, mobile, readiness, 36I UI/NAC); zero ObjectDB/retained-resource warnings. Import/startup, ordinary release export/PCK verification and whitespace checks passed. Actual Edge automated DEV lifecycle: 21/21, followed by five exact reload/history/schema-12 checks. The ordinary export also verified independent NORMAL creation, close/reacquire of the DEV writer, and a real TEST Wave-3 defeat retaining RESET with **Progress not saved** and no permanent recovery controls. Full regression and full human persistent Wave-3 combat acceptance are not claimed.

## Historical Pass1 validation

These tests use the actual `scripts/rewards/character_browser_store.js`, native IndexedDB and Web Locks. They do not enable gameplay saving or use production profiles. Only databases beginning `itank-arena-test-36k-` can accept test configuration/faults. Native tests validate full character authority/receipts and the asynchronous coordinator; the browser harness validates actual storage and cross-tab behavior. Desktop filesystem mocks are not browser evidence.

## Focused native commands (PowerShell, repository root)

```powershell
$godot = 'C:\Users\mxz\Desktop\GoDot\Godot_v4.7.2-stable_win64_console.exe'
& $godot --headless --path . --script res://tests/test_runner.gd -- '--suite=Task 36K-Pass1'
& $godot --headless --path . --script res://tests/test_runner.gd -- '--suite=Task 36J-Pass1'
& $godot --headless --path . --script res://tests/test_runner.gd -- '--suite=Task 36J-Pass2'
& $godot --headless --path . --script res://tests/test_runner.gd -- '--suite=Task 36J-Pass3'
& $godot --headless --path . --script res://tests/test_runner.gd -- '--suite=Task 36J-Pass4'
& $godot --headless --path . --script res://tests/test_runner.gd -- '--suite=Task 36J-Pass5'
& $godot --headless --path . --script res://tests/test_runner.gd -- '--suite=Task 36J-Fix'
& $godot --headless --path . --script res://tests/test_runner.gd -- '--suite=Task 36D'
& $godot --headless --path . --script res://tests/test_runner.gd -- '--suite=Task 36E'
& $godot --headless --path . --script res://tests/test_runner.gd -- '--suite=synchronization'
& $godot --headless --editor --path . --quit
& $godot --headless --path . --quit-after 3
git diff --check
```

The checked-in browser fixture consists of canonical V2 documents generated from the isolated source-backed projection/coordinator fixtures. To explicitly regenerate it after a contract/fixture change:

```powershell
& $godot --headless --path . --script res://tests/browser/export_character_storage_fixture.gd
```

## Actual Edge/Chromium browser procedure

1. From the repository, run `python -m http.server 8765 --bind 127.0.0.1`. Use a different free port if necessary. Do not replace a running owner game server.
2. Open `http://127.0.0.1:8765/tests/browser/character_storage_harness.html?test=YOUR-FRESH-TOKEN` in Edge. Use a new lowercase alphanumeric/hyphen token for each full core run. HTTPS or trusted loopback is required for Web Locks/crypto.
3. Click **Run core browser tests**. Current Pass2 expectation: **37 passed, 0 failed** (historical Pass1: 33). Actual IDB transaction abort occurs after write requests are queued; the prior generation/head/receipt remain intact. Lost acknowledgement occurs after a real commit and is reconciled by a fresh read. Quota/denial/missing-capability/readback mismatch are marked injected; these do not change browser permissions or fill real disk space.
4. In tab A click **Tab A: hold writer and save generation 1**. Keep it open.
5. Open the exact same URL/token in a separate tab B. Click **Tab B: verify competing writer rejection**. Expect acquisition and publication rejection with generation 1 unchanged.
6. Close tab A. In B click **After A closes: verify readback and acquire writer**. Expect exact generation-1 bytes, automatic native-lock release, then generation-2 publication.
7. Click **Release writer** in B, then close B. Reopen the URL and click **Reopened tab: verify generation 2**. Expect exact saved bytes, transaction and immutable history. These steps contain **9 additional assertions**.
8. Close only the disposable test tabs and stop your test server. Test databases are deliberately left as evidence; no production database is accessed or deleted. A fresh token avoids reuse. Do not clear unrelated browser data.

## Isolated Godot JavaScriptBridge smoke export

This project contains no gameplay or live save bridge. Prepare it outside the checkout using the same transport JS and canonical fixture:

```powershell
$smoke = Join-Path $env:TEMP 'itank-arena-36k-bridge-smoke'
New-Item -ItemType Directory -Path (Join-Path $smoke 'out') -Force | Out-Null
Copy-Item -LiteralPath 'scripts/rewards/character_browser_store.js' -Destination $smoke
Copy-Item -LiteralPath 'tests/browser/godot_bridge_smoke.gd' -Destination $smoke
Copy-Item -LiteralPath 'tests/browser/character_storage_fixture.json' -Destination $smoke
@'
config_version=5
[application]
config/name="Arena 36K Isolated Bridge Smoke"
run/main_scene="res://main.tscn"
[rendering]
renderer/rendering_method="gl_compatibility"
'@ | Set-Content -LiteralPath (Join-Path $smoke 'project.godot')
@'
[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://godot_bridge_smoke.gd" id="1"]
[node name="BridgeSmoke" type="Control"]
script = ExtResource("1")
'@ | Set-Content -LiteralPath (Join-Path $smoke 'main.tscn')
@'
[preset.0]
name="Web"
platform="Web"
runnable=true
export_filter="all_resources"
include_filter="*.js,*.json"
exclude_filter="out/*,index.*"
export_path="out/index.html"
[preset.0.options]
variant/thread_support=false
vram_texture_compression/for_desktop=true
html/canvas_resize_policy=2
'@ | Set-Content -LiteralPath (Join-Path $smoke 'export_presets.cfg')
& $godot --headless --editor --path $smoke --quit
& $godot --headless --path $smoke --export-release Web (Join-Path $smoke 'out/index.html')
python -m http.server 8766 --bind 127.0.0.1 --directory (Join-Path $smoke 'out')
```

Open `http://127.0.0.1:8766/index.html`. Expect the visible `PASS: Godot 4.7.2 JavaScriptBridge pending / IndexedDB publication / exact readback / lock release`. It uses only `itank-arena-test-36k-godot-smoke`, with an exact idempotent transaction on repeats. The test exercises real Godot-to-JSObject request/poll calls and the exported JS resource. It is not playable Web save/load acceptance.

## Recorded result and remaining home checks

2026-10-30, actual Edge: 33 core + 9 multi-tab/reopen assertions passed; isolated Godot 4.7.2 Single-Threaded bridge smoke passed. Native focused suites verify full contract/coordinator authorization, desktop regression, deterministic replay and client convergence. No production browser profile was created. Native checks emitted no ObjectDB/retained-resource warnings.

Not tested: complete browser shutdown/restart, private browsing, actual quota exhaustion, denied browser site-storage settings, OS crash/power loss, eviction, other browser engines, and playable Vaelis Web RETRY/RETURN flows. The owner may perform these in disposable browser environments. A local verified transaction is not a guarantee against eviction or user data deletion. Pass2 must wire host-owned asynchronous session lifetime, acknowledgement/failure UI, safe candidate transfer and playable acceptance while preserving desktop behavior.

## Pass1 changed-file inventory

Existing files: `export_presets.cfg`, `tests/test_runner.gd`, `docs/architecture/CHARACTER_STORAGE_INFRASTRUCTURE.md`, `docs/architecture/CHARACTER_PERSISTENCE_CONTRACT.md`, `docs/rules/RULES_LEDGER.md`.

New files:

- `scripts/rewards/character_browser_store.js`
- `scripts/rewards/character_browser_storage.gd` and `character_browser_storage.gd.uid`
- `scripts/rewards/character_browser_persistence.gd` and `character_browser_persistence.gd.uid`
- `tests/test_character_browser_storage.gd` and `test_character_browser_storage.gd.uid`
- `tests/browser/README.md`
- `tests/browser/character_storage_fixture.json`
- `tests/browser/character_storage_harness.html`
- `tests/browser/character_storage_harness.js`
- `tests/browser/export_character_storage_fixture.gd` and `export_character_storage_fixture.gd.uid`
- `tests/browser/godot_bridge_smoke.gd` and `godot_bridge_smoke.gd.uid`

No desktop storage/coordinator, playable session/controller, combat, simulation, source character, save-contract or deployment workflow file changed. The pre-existing protected untracked DOC and `tmp/` remain untouched.
