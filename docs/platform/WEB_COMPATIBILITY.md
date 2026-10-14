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

## Verified platform limitations

- Browsers require WebAssembly and WebGL 2.0. Safari has additional WebGL 2 caveats; Chromium-based browsers and Firefox are the primary test targets.
- Web exports cannot use Godot 4 C# projects. This project currently uses GDScript only.
- Browser tabs pause processing while inactive, which can interrupt future network sessions.
- Browser persistence uses IndexedDB and may be unavailable or cleared depending on cookies, private browsing, iframe policy, or storage eviction.
- Fullscreen, cursor capture, and audio playback require user interaction in common browser configurations.
- Low-level networking is unavailable. Browser clients are limited to supported HTTP, WebSocket client, and WebRTC paths.
- If threading is enabled later, deployment requires HTTPS plus cross-origin isolation headers or the documented PWA workaround. That change requires a measured need and approval.

## Official references

- https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_web.html
- https://docs.godotengine.org/en/4.7/tutorials/export/exporting_projects.html
- https://docs.godotengine.org/en/4.7/classes/class_editorexportplatformweb.html
