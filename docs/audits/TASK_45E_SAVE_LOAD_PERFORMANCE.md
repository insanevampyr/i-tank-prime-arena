# Task 45E — save/load performance and retention

Audit and surgical optimization, completed 2026-11-16 against main `f9bb0db0235b0003895c477a12346191d4714469`, preserving uncommitted 45B/45D. No owner storage, backup or protected file was read. No Web export, full regression or Git mutation was performed.

## Recovered state and measured causes

The interrupted work already contained the resource pin, bounded scanner, terminal buffer release, typed preview handoff and browser work pump. The recovered integrity log passed 65 assertions. Continued work added preview-mutation coverage, repeated-operation cleanup coverage, actual isolated Edge scheduler checks and repeat-memory measurements. The final integrity suite passes 73 assertions.

1. Each historical hydration reconstructs a catalog. Releasing the resources between generations repeatedly reloads unrelated actor resources. A strong catalog reference for one validation job reduced the sampled hydration from approximately 36 ms to 2.6 ms per generation. Each generation still constructs its validator and runs all source/receipt/progression checks. No persistent trust cache was introduced.
2. GDScript character-by-character JSON scanning and 32 KiB/frame work scheduling amplified latency. The scanner now uses bounded native runs while retaining duplicate-key, depth, token, truncation and UTF-8 size checks. Imported data still undergo native JSON grammar parsing, canonical comparison and checksum verification.
3. Synchronous export validated history and then decoded its own generated container again. Incremental export also rescanned its own generated container. The native JSON encoder now constructs the fixed canonical container directly from operation-private verified rows. All limits/head checks remain; tests independently run the complete untrusted decoder on output.
4. Restoration decoded an already-previewed input again at confirmation and revalidated identical readback bytes. A typed completed Reader can now hand off its exact snapshot; confirmation verifies unchanged text/metadata/records, and publication still requires fresh destination inspection, writer authority and exact full readback.
5. Completed/canceled tasks and completed restoration coordinators retained large working values while UI references survived. They now release those references. Starting another SAVE/preview releases the previous completed output first.
6. One CPU step per animation frame cannot progress in a hidden Edge tab whose RAF is suspended. The backup-only work pump uses MessageChannel tasks for ready CPU work, a timer while awaiting I/O, and stops when idle/canceled. It does not advance combat or Running time.

## Identical disposable fixtures and timing

Godot 4.7.2 native headless measurements; seconds, single baseline/after runs. Same saved fixture bytes were used. The fixtures are legitimate historical V2 Vaelis histories extended with unchanged valid generations and legal JSON whitespace to stress nested escaping and byte volume. They are NOT copies of the owner's unseen Level 9 data: the seed is Level 8. Thus these measurements do not establish the owner's actual admission or semantic-history validation time.

| Operation | Small, 10 generations | 168 generations, 20 MB file | 221 generations, 41,342,410-byte file |
|---|---:|---:|---:|
| Verified Character Sheet | .052 → .051 | .059 → .057 | .061 → .056 |
| Admission approximation | .046 → .041 | .956 → .958 | 1.485 → 1.706 |
| Complete export | .231 → .119 | 19.122 → 3.575 | 32.842 → 5.308 |
| Imported preview validation | .234 → .167 | 18.613 → 6.342 | 32.005 → 10.236 |
| Fresh restoration, begin + confirm | 1.276 → .579 | 108.817 → 23.321 | 189.374 → 38.943 |

Admission approximation includes native serialization/parse of a simulated JS response, browser-contract inspection and authorized hydration, NOT real IndexedDB latency or Godot WASM. This path was not changed; observed variation is not a claimed improvement. Already-verified Sheet opening did not need a cache or production change. With 5,001 transcript events it remained 69 ms on the largest fixture.

The restoration comparison deliberately requests fresh validation instead of using the preview handoff, making it a conservative standalone comparison. UI handoff and actual filesystem publication are separately exercised by focused tests. Preview timing is for an empty destination; validating an existing large destination adds necessary work.

On 221 generations: history validation fell from 20.219 s to 4.268 s. Export steps fell from 2,461 to 223; preview steps from 2,460 to 294. These probes poll tightly and exclude frame waits. They are not browser end-to-end timings. Raw generation bytes: 23,867,324; canonical body: 31,943,753; encoded file: 41,342,410. Complete original bytes, receipts and history remain present.

## Memory evidence

Decimal MB, native process. Static figures come from Godot MEMORY_STATIC/MAX; RSS is sampled externally every 10 ms. Stage peaks below are cumulative up to that point, not independent isolated-operation peaks.

| 221-generation measurement | Before MB | After MB |
|---|---:|---:|
| Static peak through export | 1,106.3 | 937.4 |
| Static peak through preview | 1,106.3 | 1,106.4 |
| Entire restoration static peak | 1,886.3 | 1,768.2 |
| Entire-process sampled RSS peak | 1,728.9 | 1,628.1 |
| Live static after restoration confirmation | 667.5 | 546.0 |
| Static after cancel/release | 152.1 | 153.1 |
| Sampled RSS during cancel/release | 585.5 | 614.3 |

No claim that every metric improved: preview peak is effectively unchanged and post-release RSS remains high. Native static allocation falls when references are released; process/runtime memory does not necessarily return to the OS at once. This does not prove an Edge leak or explain all 2.2 GB of the owner's tab.

A separate four-cycle 41.3 MB export/import/cancel probe yielded exactly 190,571,390 live static bytes after settling each subsequent cycle, with source input still held. Releasing that input reduced live static allocation to 68,487,618 bytes. There was no progressive growth in this probe. First-cycle temporaries required additional frame boundaries to settle. This is native Godot retention evidence, not a measurement of the browser's WASM heap.

## Actual isolated Edge evidence

`node tests/browser/test_task_45e_edge.js` launches its own headless Edge with a unique disposable user-data directory and ephemeral local server. It never attaches to the owner's tab and uses NO storage APIs.

The production embedded JS bridge is executed unchanged. A second disposable tab makes the test page `document.hidden === true`. Its RAF callback remains at zero over 800 ms. The production MessageChannel pump completes all 221 small JSON work units while hidden (2.9 ms); the foreground RAF control requires 3.66 s, versus 3.1 ms for the pump. These are scheduler microbenchmarks, NOT 41 MB file processing times.

Eight assertions pass, including real hidden state, completion, stop, immediate cancellation and bounded retained JS heap. Five repeated scheduler jobs increase post-GC JS heap from 487,612 to 494,144 bytes (6,532 bytes). GC is used only for diagnostic comparison, never as a production remedy. Full Godot-WASM UI integration and large WASM heap measurements remain unverified because exporting was prohibited. OS-frozen/suspended pages cannot execute any scheduler; work can only resume when the browser permits execution.

## Integrity and compatibility argument

- New/changed imports always receive the complete scanner, parser, canonical/checksum, source, generation, transaction, receipt, purchase, checkpoint and namespace checks.
- Export uses frozen verified string records. Its outer container has fixed keys; the manifest has at most 4,096 fixed-shape rows, below existing depth/token limits. Native JSON construction cannot introduce duplicate keys. Generation-document limits and scans are still checked independently. No limit was raised.
- Preview reuse is typed host state, never an imported JSON flag. It requires a completed preview, identical source text and namespace, and a digest over every original document's bytes, ordered transaction/generation identities, manifest header, validated payload, preview and body digest. Mutating any bound part rejects reuse before writes.
- Destination continuity is freshly inspected under the existing writer rules. Exact published readback is compared against all verified input records. Uncertain writes retain evidence until reconciliation; cancellation cannot undo or conceal a possibly published write.
- No character authority, save contract, schema, XP accounting, live resource recovery, advancement, history record or owner data is modified by these optimizations.

## Reproduction and focused verification

Commands, from the primary repository:

```powershell
& 'C:/Users/mxz/Desktop/GoDot/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script tests/test_runner.gd -- '--suite=<registered filter>'
& 'C:/Users/mxz/Desktop/GoDot/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script tests/benchmark_task_45e.gd -- setup
# Reuse those exact fixture bytes for comparisons:
# -- small; -- 168; -- 221; -- retention
node tests/browser/test_backup_file_limits.js
node tests/browser/test_task_45e_edge.js
git diff --check
```

Final focused result: 25/25 selected registered suites passed; zero failed suites. The three affected backup UI suites were rerun after final output-release changes and passed. The final new integrity suite passed 73 assertions, the existing Web file bridge passed 22, the isolated Edge scheduler passed 8, and final headless import passed without reported errors/warnings.

Focused coverage includes backup integrity/responsiveness/export/restoration; historical admission; V2/V4 run-policy contract; V5 EXPC-only credit and grant; saved-run selection; browser storage/persistence; coordinator/save contract; END/HPB replay; 45D DEX/Mana remainder/Experience; WIS/Mana history; STR/DEX/SPD; Character Sheet; simulated-client synchronization. No routine full regression was run. New integrity assertions also verify changed text, namespace, payload, manifest, transaction IDs, record bytes, reader proof, corruption, canceled previews, exact readback and old-output release. Existing restoration tests cover interrupted writes, lost acknowledgements, stale destinations and anti-rollback.

Raw timing/RSS reports and focused logs are `arena45e-before-*`, `arena45e-after-*`, `arena45e-focused-*`, `arena45e-integrity-final.log`, `arena45e-retention.log` and `arena45e-edge-final.log` under system TEMP. Test fixtures are under OS cache `itank-storage-tests/45e_performance`, not project `tmp/` or character storage.

## Exact 45E file scope

Modified production:
- `scripts/rewards/character_backup_contract.gd`
- `scripts/rewards/character_backup_task.gd`
- `scripts/rewards/character_backup_reader.gd`
- `scripts/rewards/character_backup_restoration.gd`
- `scripts/ui/character_backup_actions.gd`
- `scripts/ui/character_backup_files.gd`

Modified registration: `tests/test_runner.gd` (one new 45E suite; pre-existing 45B/45D registrations retained).

New:
- `tests/test_task_45e_backup_integrity.gd` and `.gd.uid`
- `tests/benchmark_task_45e.gd` and `.gd.uid`
- `tests/browser/test_task_45e_edge.js`
- `docs/audits/TASK_45E_SAVE_LOAD_PERFORMANCE.md`

The only prior tracked diffs extended by 45E are the backup contract and test runner. Other current changes belong to preserved prior work. Final Git inventory: 28 modified tracked files, 24 untracked entries (including the three protected entries); index empty, HEAD/branch unchanged. No protected content was inspected.

## Remaining limitations and owner acceptance

- Large standalone restoration still takes about 39 seconds in this native fixture; it does not meet a 10-second goal. Publication retains the existing defense-in-depth storage checks, bundle staging and readback. No competing storage infrastructure was introduced.
- Native JSON encoding/parsing/hashing are synchronous. Maximum measured export step was 996 ms; preview 693 ms on 41 MB. Chunk scheduling improves progress between calls but cannot preempt one native call. A worker/streaming redesign would require a separate compatibility review.
- Real current-owner admission latency, full browser/WASM memory, browser file-dialog/large-download latency, and foreground/background interaction acceptance still require a future approved build and isolated acceptance. No owner's IndexedDB was accessed.
- Existing 45B/45D tracked diffs were compared to the pre-45E snapshot. Only the intentionally shared backup-contract and test-runner diffs changed; all other prior tracked work stayed identical. `project.godot` SHA-256 remains `8398f110f77d7712eb19c283eb9f745c7123feab9557187778da412639ba5692`.
- Stop for owner review. No export, commit, push or live-data testing.
