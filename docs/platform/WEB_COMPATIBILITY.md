# Web Compatibility Baseline

## Phase 0 decision

Keep the existing Compatibility renderer. Godot 4 Web export targets WebGL 2.0 through the Compatibility rendering method; Forward Plus and Mobile rendering methods are not supported for Web export.

The `Web` export preset is single-threaded, without GDExtension support or Progressive Web App behavior. Single-threaded export is Godot's preferred default and avoids the cross-origin isolation headers required by `SharedArrayBuffer`. This is the broadest compatibility baseline for the current GDScript-only 2D project.

Desktop VRAM compression is enabled. Mobile VRAM compression remains disabled because the project has not enabled ETC2/ASTC texture imports and currently has no production raster textures that require that additional import target. Enabling mobile VRAM compression later must be paired with the corresponding project import setting and an actual mobile-browser asset test.

## Local export status

On 13 October 2026, the matching Godot `4.7.2.stable` templates were verified at:

- `%APPDATA%\Godot\export_templates\4.7.2.stable\web_nothreads_debug.zip`
- `%APPDATA%\Godot\export_templates\4.7.2.stable\web_nothreads_release.zip`

The Web Single-Threaded debug export completed successfully with exit code 0:

`Godot_v4.7.2-stable_win64_console.exe --headless --path <project> --export-debug Web <project>\builds\web\index.html`

The generated output included `index.html`, `index.js`, `index.wasm`, `index.pck`, icon images, and the audio worklet files. The preset writes these artifacts under `builds/web`, which is excluded from version control.

The exported `index.html` returned HTTP 200 from a local loopback HTTP server. Microsoft Edge loaded the Phase 0 test scene, rendered the placeholder, and moved it upward from a held `W` input. Browser diagnostics contained no project JavaScript or WebAssembly errors. Warnings observed during the run originated from an unrelated installed browser extension.

## Task 31K export hygiene

The `Web` preset retains `export_filter="all_resources"` so referenced scenes, scripts and data continue to be dependency-safe. It excludes `tmp/*`; Task 31O also excludes `tests/*`, `docs/*`, and `.github/*` so regression code, engineering documents, and workflow source are not published inside `index.pck`. Project-local PDF rendering artifacts and other temporary files remain untouched on disk and outside the package. The required `test_arena`, `arena_combat_session`, and `prime_v3_common_goblin` runtime resources remain present. Exported artifacts continue to be written under the ignored `builds/web` directory.

## Task 31O GitHub Pages preparation

`.github/workflows/deploy-pages.yml` prepares a release export on owner pushes to `main` or a manual workflow dispatch. It downloads the official Godot 4.7.2 Linux editor and export templates, verifies their published SHA-256 digests, imports the project, exports the existing single-threaded `Web` preset, validates the required static files and relative shell paths, and uploads only `builds/web` to the official GitHub Pages artifact/deployment actions. Every action is pinned to a reviewed commit. The build job has read-only repository and Pages-metadata access; only the deployment job receives `pages: write` and OIDC `id-token: write`.

Generated HTML, JavaScript, WebAssembly and PCK files remain ignored and are never pushed back to `main`. The static artifact contains neither `tmp/` nor Markdown, DOC, or DOCX development material. Single-threaded Web export continues to avoid `SharedArrayBuffer` and cross-origin-isolation header requirements. Asset URLs remain relative so the game can load under a repository project path. Owner activation and rollback steps are documented in `GITHUB_PAGES_DEPLOYMENT.md`.

## Verified platform limitations

- Browsers require WebAssembly and WebGL 2.0. Safari has additional WebGL 2 caveats; Chromium-based browsers and Firefox are the primary test targets.
- Web exports cannot use Godot 4 C# projects. This project currently uses GDScript only.
- Browser tabs pause processing while inactive, which can interrupt future network sessions.
- Browser persistence uses IndexedDB and may be unavailable or cleared depending on cookies, private browsing, iframe policy, or storage eviction.
- Fullscreen, cursor capture, and audio playback require user interaction in common browser configurations.
- Low-level networking is unavailable. Browser clients are limited to supported HTTP, WebSocket client, and WebRTC paths.
- If threading is enabled later, deployment requires HTTPS plus cross-origin isolation headers or the documented PWA workaround. That change requires a measured need and approval.

## Phase 1 Task 13 mobile input baseline

The temporary arena now uses one shared player-input boundary:

- Desktop: WASD movement and Shift Running remain unchanged.
- Touch: a fixed lower-left joystick provides movement direction and a separate lower-right RUN target supplies the same Running hold intent as Shift.
- Multitouch: joystick and RUN track independent touch indexes, so movement and Running can be held simultaneously.
- Safety: touch release, browser-canceled touches, viewport resize/rotation, application pause and application focus loss clear captured touch state. The following physics tick observes released intent and follows the existing Running stop behavior.
- Presentation: controls appear when a touchscreen is detected and on narrow Web viewports used for mobile-browser testing. The responsive layout keeps status text above the lower control zone and recommends landscape orientation when portrait is detected.

Only movement and Running are connected. Attack, defense, critical, Special and NAC buttons are intentionally not shown because the current test scene does not yet provide approved player targeting or action-declaration integration. The underlying deterministic combat tests remain headless and input-independent.

Android-sized layout tests cover `800 x 360`, `915 x 412`, `1280 x 720`, and portrait rotation at `360 x 800`. These are simulated viewport and input-state tests, not evidence from a physical Android device.

## Test the Web build on an Android phone

1. Export the existing `Web` preset from the project root:

   `Godot_v4.7.2-stable_win64_console.exe --headless --path . --export-release Web builds/web/index.html`

2. In PowerShell, serve the generated files on the local network:

   `Set-Location builds/web`

   `python -m http.server 8060 --bind 0.0.0.0`

3. Find the Windows computer's local IPv4 address with `ipconfig`. Keep the phone and computer on the same trusted Wi-Fi network and allow the Python process through Windows Firewall only for that trusted/private network if prompted.

4. In Chrome on Android, open `http://<computer-ipv4>:8060/`, rotate to landscape, and wait for the Godot canvas to load.

5. Verify the lower-left joystick moves the placeholder, RUN can be held with a second finger, releasing either finger clears only its control, rotating/resizing does not leave movement stuck, and returning after switching apps does not leave RUN or movement held.

6. Open Chrome remote debugging from a desktop Chrome instance (`chrome://inspect`) if console or WebAssembly diagnostics are needed. Do not treat a desktop emulated viewport as a physical-device pass.

## Official references

- https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_web.html
- https://docs.godotengine.org/en/4.7/tutorials/export/exporting_projects.html
- https://docs.godotengine.org/en/4.7/classes/class_editorexportplatformweb.html
