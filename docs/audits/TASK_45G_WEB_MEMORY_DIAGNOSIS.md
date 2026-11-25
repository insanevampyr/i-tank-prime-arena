# Task 45G — actual Web memory diagnosis and release scanner correction

2026-11-16, main `f9bb0db0235b0003895c477a12346191d4714469`. Existing uncommitted 45B/45D/45E work preserved. This report supersedes any implication that the 45E native measurements certified Web performance. Owner acceptance failed. **Status: needs follow-up; a confirmed release defect is corrected in source, but the corrected application has not been exported or browser-certified.**

## Confirmed release-only root cause

The actual existing `f9bb0db+wip.93be50bf83a5` PCK was served unchanged to an isolated Edge context. Invoking real SAVE on the large disposable profile produced repeated:

```
ERROR: Condition "!is_valid()" is true. Returning: nullptr
   at: search (modules/regex/regex.cpp:209)
```

`CharacterBackupContract.JsonScan._init()` compiled both regexes inside `assert(regex.compile(...) == OK)`. In a release runtime those expressions are removed, so neither regex was compiled. The native/debug tests and the 45E JS-only scheduler microbenchmark did not exercise this release initialization. That gap was missed during 45E.

When an escaped string or whitespace run is encountered, the scanner then searches an invalid regex repeatedly. The failed match advances only one character, recreates bounded substring work and logs errors on each attempted search. With a 1 MiB lexical step, this can monopolize the browser thread and flood diagnostics. Thus the previously improved debug scanner path was not operating correctly in the shipped release. This is a demonstrated cause of severe save/validation slowdown and allocation churn. It does NOT establish that every part of the owner's 2.3 GB idle reading has this cause.

The failing SAVE did not reach a verified completion during observation. The main thread became sufficiently busy that the pending memory evaluation did not complete. Only the disposable test context was disposed to stop the failure. This was not a successful UI-cancellation test. No file download or restoration confirmation was performed.

## Surgical correction

Only production change: `scripts/rewards/character_backup_contract.gd`, `JsonScan._init()`.

- Execute both `compile()` calls outside assertions.
- Verify both regexes are valid before any search.
- Fail closed with `backup_scanner_unavailable` if initialization is invalid.

Patterns, lexical budgets, byte/depth/token limits, JSON parsing, canonical checks, checksums and complete generation/receipt/source validation remain unchanged. No history retention policy, profile schema, persistence architecture, combat or progression behavior was changed.

## Actual Edge measurement method

A new headless Edge used a unique system-TEMP user-data directory. Each case used a fresh isolated BrowserContext. The existing PCK, JS and WASM files were served from `builds/web` by an ephemeral loopback harness. The HTML was instrumented in memory to expose the engine instance and seed only disposable IDB fixtures before admission. No exported file was altered.

- Browser: Edge 157 headless, software WebGL/SwiftShader. This is not the owner's GPU/driver environment.
- JS heap: CDP `Runtime.getHeapUsage.usedSize`.
- WASM capacity: the actual `engine.rtenv.HEAPU8.buffer.byteLength`, not JS-heap inference. This includes used and reusable capacity; a live native-allocation counter was not available from the unmodified release.
- Renderer RSS/private memory: psutil against the test renderer, identified by its CDP Performance ProcessTime matching the browser's process CPU record. Whole-browser sums were avoided because isolated Edge also started internal/extension processes.
- Diagnostic GC was used only to distinguish collectible JS values from retained references. It is not a production fix or performance mitigation.
- No personal Edge tab, owner DB, save or backup was inspected. The production DB name existed only inside isolated contexts populated with test fixtures. No clear-site-data/deleteDatabase operation was used.

Fixtures:

1. Fresh Guard launch: no persistent character admission.
2. Existing small historical Legacy DEV fixture, 10 generations, Level 8.
3. Existing 221-generation Level 8 padded fixture from 45E (23,867,324 raw generation bytes, 41.3 MB encoded backup).
4. Independent 232-generation Wave 1 entry fixture, Level 1, based on a legitimate verified historical starter; unchanged valid payload snapshots with incrementing generation/transaction identities and legal whitespace padding. Raw generation text: 25,843,300 bytes. It is not a copy or full semantic reconstruction of the owner's Level 9 profile.

## Baseline results on the UNCORRECTED application

Decimal MB. Measurements are observations, not owner-browser reproduction claims.

| State | WASM capacity MB | JS used MB | Renderer RSS MB | Renderer private MB |
|---|---:|---:|---:|---:|
| Fresh control launch, no persistent character | 161.8 | 10.2 | 328.0 | 344.6 |
| Small historical character admitted | 161.8 | 8.4 | not identified at sample | not identified at sample |
| 221-generation historical character admitted, no backup | 425.6 | 10.3 | 696.6 | 758.4 |
| 232-generation Wave 1 entry admitted, no backup | 384.6 | 8.6 | 757.7 | 787.4 |
| Same 232 profile idle about 32 seconds later | 384.6 | 9.6 | 616.0 | 636.6 |
| After Wave 1 combat ended in player defeat | 384.6 | 17.9 | 604.7 | 623.3 |
| After RETRY at READY | 384.6 | transient 96.3 | 797.0 | 748.7 |
| Character Sheet visibly open | 384.6 | diagnostic-contaminated; see below | 630.0 | 636.7 |
| Character Sheet closed, idle | 384.6 | diagnostic-contaminated; see below | 642.2 | 648.7 |

Fresh WASM capacity was also unchanged across approximately 48 seconds of idle observation. The 232-generation case remained at exactly 384,565,248 bytes across about five minutes including combat, retry and sheet operations. This does not prove absence of all leaks, but it does not reproduce continuous idle WASM growth to 2.3 GB.

A diagnostic 32 MiB `_malloc`/write/`_free` in the disposable runtime reused existing memory: WASM capacity remained 384,565,248 before, during and after. At least that capacity was reusable rather than all being occupied by live character objects. WASM capacity does not itself measure live history retention.

During the failing 221-generation SAVE, a renderer sample showed 876 MB RSS, peak working set 892 MB, private bytes 893 MB and peak private allocation 1,318 MB. Because the browser thread was busy in erroneous scanning, no reliable simultaneous JS/WASM peak or completed-operation latency was obtained. Do not replace those missing measurements with native benchmark numbers.

A temporary diagnostic request-label collector accidentally retained a slice of one 26 MB response string. That is a harness artifact, not production evidence. After detaching those labels and diagnostic collection, JS used memory was 14.66 MB; WASM capacity remained 384.6 MB. The contaminated sheet/retry JS samples must not be interpreted as an application leak. Renderer process figures include other transient allocations and are not sums of JS + WASM.

## Loading/wave work and ownership audit

The source still performs substantial bulk work without backup:

- `character_browser_store.js: Store.inspect()` reads full generation and transaction receipt records, validates all document checksums and continuity, and returns the complete history.
- The bridge `poll()` serializes the complete response. `CharacterBrowserStorage.poll()` converts/parses it in Godot, then `inspection()` decodes every generation with the save contract.
- `PlayableBrowserPersistence.poll_browser()` hydrates the authorized head. It replaces the terminal `_browser_result` with a small loaded status; bridge terminal jobs are removed. The ordinary admission path does not intentionally retain the entire transport response.
- Atomic publication/reconciliation repeats fresh inspections to preserve existing anti-rollback and exactly-once guarantees.
- In the actual 232-generation RETRY, an instrumented transport inspection returned 26,393,320 characters in 255.5 ms, followed by lease transfer in 14.4 ms. This excludes subsequent JS→Godot conversion and GDScript validation and is NOT total wave-load time.

These copies/validations explain significant transient demand and higher capacity at admission. They are not proof of an unbounded reachable-history leak. Redesigning transport, cross-operation verification caching or durable receipt/history retention would affect persistence authority or architecture. No such redesign was implemented in this task; it requires owner review. No event-history truncation or retention-policy change was made. No sustained idle collection growth or repeated scene leak was established in the observed intervals.

## Release and integrity verification

`tests/test_task_45g_release_scanner.py` extracts the actual production JsonScan at test time into a disposable native scene and runs Godot 4.7.2's Windows RELEASE template. Only an error/limit shim is supplied; the scanner implementation is not reimplemented. The fixture PCK is a temporary native test package, not an application or Web export. It proves:

- `OS.is_debug_build() == false`.
- The old assert-contained initialization does not execute in release.
- Production regex initialization now executes and is valid.
- Escaped/whitespace input succeeds.
- Duplicate escaped keys, excessive nesting and truncation remain rejected.
- Invalid scanner initialization fails closed without entering search.

Result: **8/8 release checks PASS**, exit 0, no reported runtime errors.

The existing integrity suite now adds 10 compilation checks across slice sizes and one initialization-failure check: **84 assertions PASS** (previous 73 retained).

Focused Godot filters and results: 45E backup integrity; backup responsiveness; safe character backup restoration; 45B (HPB + END); 45D (DEX + Mana remainder + Experience); 44B (WIS + event-time Mana); EXPC credit; run reward save contract; two-client synchronization. **13/13 selected suites PASS**, no failed assertions or reported warnings/leaks. Existing Web file bridge: **22 assertions PASS**. These tests cover V2/V4/V5 compatibility, credits, receipts, stale/duplicate/interrupted restoration, progression and simulation invariants. No full regression was run.

Commands:

```powershell
python tests/test_task_45g_release_scanner.py
# Optional --godot and --templates arguments override Windows installation paths.
& 'C:/Users/mxz/Desktop/GoDot/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script tests/test_runner.gd -- '--suite=<filter above>'
node tests/browser/test_backup_file_limits.js
git diff --check
```

Raw measurements/screenshots are system-TEMP `arena45g-*`; reusable release fixtures are under OS cache `itank-storage-tests/45g-release-*`. None are owner data or project `tmp/`.

## Exact task file scope

- Modified `scripts/rewards/character_backup_contract.gd` — release initialization and fail-closed guard only, on top of preserved 45B/45E work.
- Modified `tests/test_task_45e_backup_integrity.gd` — additive checks only.
- New `tests/test_task_45g_release_scanner.py` — real native release regression.
- New `docs/audits/TASK_45G_WEB_MEMORY_DIAGNOSIS.md` — this report.

## Remaining acceptance/blockers

- **No corrected Web export was authorized.** The served application remains the old known-defective `f9bb0db+wip.93be50bf83a5`, PCK SHA-256 `fecbad7c3b0ac20d0cc974f9138e961c09d4eed1d69d4907f7acbf112a196571`.
- Complete post-fix browser export/preview/cancellation/restore timings and memory are therefore unavailable. The native release regression proves the specific initialization fix, not whole-app Edge acceptance.
- Large SAVE was aborted by disposing its disposable context. A successful SAVE, responsive UI cancellation and post-cancel idle memory on the corrected Web application remain required.
- Multiple full wave transitions, sustained long-idle behavior, owner-equivalent semantic history and the owner's hardware GPU memory remain unverified. One actual Wave 1 ended in defeat and RETRY was exercised; no claim of repeated successful waves is made.
- The exact owner's 2.3 GB reading remains unexplained in full. It must not be called a proven leak, or declared resolved, on these results.
- Smallest next checkpoint is an owner-authorized fresh Web export followed by the same isolated browser matrix before broader persistence changes. No public deployment or owner-data experiment is implied.

Project.godot remains byte-identical. All other pre-existing development is preserved. No staging, commit, push, real profile mutation, Web export or full regression was performed. Stop for owner review.
