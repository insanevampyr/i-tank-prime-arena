# Task 45M - disposable compact V6 storage, Pass C

2026-11-17. **Complete isolated prototype; no production activation.** Main remains `f9bb0db0235b0003895c477a12346191d4714469`. Existing 45B-45L work and owner data are preserved.

## Files

Added these five GDScript files and their five `.gd.uid` sidecars:

- `tests/compact_v6_disposable_store.gd`
- `tests/compact_v6_storage_fixtures.gd`
- `tests/compact_v6_storage_process.gd`
- `tests/test_compact_v6_storage.gd`
- `tests/browser/compact_v6_wasm_harness.gd`

Also added `tests/browser/compact_v6_store.js`, `tests/browser/test_compact_v6_storage_edge.js` and this report. Modified only `tests/test_runner.gd`, adding one preload and suite registration. No existing contract, converter, production adapter or gameplay implementation changed.

## Architecture and isolation

**Windows:** the test adapter accepts only absolute paths below the OS-cache `itank-storage-tests/compact45m_*` prefix, rechecking that boundary on operations. It has no default production-directory fallback. It reuses CharacterSaveStorage's directory-based exclusive writer lease and the dormant V6 semantic/continuity validators. It stages and flushes an immutable, SHA-256-named record, verifies its bytes, then replaces one checksummed head pointer. That pointer references current and previous records. Successful readback verifies exact bytes, profile, namespace, epoch and sequence. Unreferenced staged/older records are pruned after a verified publication/recovery, leaving two active full records and small metadata, not a generation archive.

Several file renames are **not** treated as one transaction. The head replacement is the publication boundary. Interrupted record/head staging leaves the old head authoritative; exact initial retry can reconcile its own matching orphan. A published head with lost acknowledgement remains authoritative. Process interruption can leave a lease; recovery removes it only with a matching owner marker and a PID no longer running. An active or unverifiable lease remains a blocker.

**Web:** `DisposableV6Store` permits only database names beginning `itank-arena-disposable-v6-45m-`, checked both at construction and opening. It opens test schema version 1, never the production character DB. Two object stores hold the head and at most two complete record strings. Each string includes all lifetime evidence/IDs, so head, record and evidence publish together in one IndexedDB read/write transaction. Expensive SHA/semantic validation runs before that transaction; it then compares the exact observed head and existing bytes again inside the transaction. No asynchronous crypto/replay is awaited inside an active transaction. Strict durability is requested, not represented as proven power-loss durability.

All imported/current/candidate states pass the actual Godot V6 validator; there is no JS-only substitute for progression rules. Competing independent IDB connections use expected-head compare-and-swap; exactly one same-parent update succeeds. Exact-current retries acknowledge the existing bytes rather than applying another effect. Stale or invalid candidates cannot replace newer progress.

The Web test copies only source/data and the one approved authored JSON into a **separate temporary Godot project**, with a temporary project configuration and test export preset. It exports that harness using 4.7.2's single-threaded release template. The real project.godot, export preset and builds/web artifacts are not modified. Edge uses a fresh temporary user-data directory, disabled extensions and a random localhost origin. Tests verify that the production database was not created/opened in this isolated origin. No existing browser debugging port, personal tab, profile or IndexedDB is used.

The harness initially polled requests in `_process`; two bounded waits stalled without a reported Godot error. It was replaced with direct JavaScriptBridge callbacks, eliminating the render-frame dependency. The final bridge also completes validation in a genuinely hidden tab; two complete final Web runs passed. This tests the harness bridge, not the playable game's background scheduling.

## Recovery outcomes

| Situation | Verified behavior |
|---|---|
| Before staging / partial record / complete unreferenced stage | Old acknowledged current remains exact; recovery removes uncommitted staging. Exact initial retry also works. |
| Partial head / staged head before rename | Old head remains current; repeated recovery is safe. |
| Head published, acknowledgement lost | Exact latest state loads; retry does not duplicate effects. |
| Process exits leaving writer lease | Separate process reload works; verified dead-owner recovery retains the published latest state. This is injected interruption, not power-loss testing. |
| Latest damaged/missing, previous sound | Current load fails closed. Previous is available only as `diagnostic_only`, explicitly `is_current:false`. |
| Previous damaged, latest sound | Latest remains loadable; previous diagnostic rejects. |
| Head missing/damaged | No record scan chooses an older character. Existing conflicting record files cannot become a fresh initial save. |
| Exact acknowledged current artifact supplied | Repair is permitted only when its digest equals the existing authoritative head and semantic/identity checks pass. No transaction or reward is reapplied. An older backup is rejected. |
| Browser transaction aborted after writes queued | Both head and record/evidence changes abort; no partial publication. |
| Same-parent conflict / stale expected revision / unsupported version | Reject before overwriting authoritative progress. |

There is no automatic rollback-to-previous or reconstruction of missing newer progress from a request journal. If the acknowledged latest cannot be proved/repaired, recovery reports failure. The previous record is not permission to refund XP, purchases, credits or equipment.

## Lifetime identity and fixtures

Lifetime IDs/evidence remain in each compact record, independent of the journal, which stays at 20. Tests persist 1,000 actual transport operation IDs, then a further operation: **1,001 operations and 1,446 total semantic/operation bindings** survive reload. An evicted old operation cannot be reused. A deliberately forged reward envelope submitted under a new operation ID is rejected by the real WASM validator (`invalid_receipts`, underlying `unrepresented_reward_settlement`), and current bytes remain unchanged.

Small and 168/221/233/400-generation fixtures reuse Pass B's real disposable progression, END/WIS, late credit, equipment, consumption and recovery evidence. The large semantic fixture includes distinct development commands, not whitespace padding. The 1,000-operation fixture adds source-identical checkpoint transactions with real encoded legacy document hashes; these add identities without invented XP/items or retaining hundreds of full snapshots. It is fixture construction, not a new legacy-conversion shortcut.

## Tests and commands

Godot: `C:/Users/mxz/Desktop/GoDot/Godot_v4.7.2-stable_win64_console.exe`.

```powershell
# Use a new cache-only compact45m_* directory for a fresh fixture set.
& $godot --headless --path . --script tests/compact_v6_storage_process.gd -- fixtures $fixtureRoot
$env:ARENA45M_FIXTURES = $fixtureRoot
& $godot --headless --path . --script tests/test_runner.gd -- '--suite=45M'
& $godot --headless --path . --script tests/test_runner.gd -- '--suite=45K'
node tests/browser/test_compact_v6_storage_edge.js $fixtureRoot
```

| Final check | Result |
|---|---|
| Windows native Godot debug filesystem suite | 62 assertions PASS |
| Existing V6 contract/proof control | 814 assertions PASS |
| Actual isolated Edge + release Godot WASM + IndexedDB | 28 assertions PASS, repeated twice |
| Exact byte readback, identity, stale writers, duplicate rewards/IDs | PASS |
| Separate-process reload / abandoned lease | PASS |
| Browser page/WASM reload and two competing connections | PASS |
| Invalid directory/database names, namespace, versions | PASS |
| Whitespace and prior-file integrity checks | PASS |

Final runs have no script/JS errors, resource-leak reports or unexpected warnings. Expected corruption is checked before parsing a mismatched blob; error assertions were not suppressed. No full regression was run. Windows exported-release was not tested. Browser results are from the actual release WASM harness, not JS-only tests or full Arena gameplay acceptance.

Native test roots are removed by the suite. Generated fixture packages, test-harness projects and logs remain outside the repository for diagnostics. They contain disposable data only. The test process/browser is closed afterward.

## Timings, sizes and memory

Single native debug sample and the second complete final Edge run below, milliseconds. Update timings include validation, publication and verified readback. One-record UTF-8 size is shown; steady storage holds current + previous plus small metadata. IDB physical compression/quota allocation and NTFS allocated cluster sizes are not measured.

| Fixture | Record bytes | Windows initial / update / load / readback ms | Edge initial / update / load / readback ms |
|---|---:|---|---|
| Small | 35,245 | 143.9 / 264.6 / 43.6 / 43.7 | 90.5 / 110.9 / 19.2 / 18.5 |
| 168 | 198,745 | 451.9 / 770.4 / 141.3 / 144.5 | 212.7 / 516.4 / 110.5 / 98.9 |
| 221 | 235,050 | 494.6 / 853.0 / 159.3 / 158.8 | 253.9 / 567.5 / 113.8 / 117.5 |
| 233 | 243,270 | 514.6 / 965.0 / 204.3 / 197.7 | 268.5 / 580.0 / 125.8 / 119.8 |
| 400 | 357,665 | 784.6 / 1329.0 / 226.0 / 247.5 | 600.0 / 828.7 / 164.3 / 166.3 |
| 1,000 operation baseline | 542,550 | update 1380.0 / load 272.4 / readback 262.9 | update 1120.2 / load 229.6 / readback 229.1 |

Windows interrupted-write recovery samples: 51.0-62.9 ms, including 54.4 ms for dead-process lease recovery. Browser recovery sample: 28.5 ms. These are small-fixture recovery measurements, not worst-case guarantees.

Native static allocator peak: **277,983,080 bytes**, including all preloaded test suites; not process RSS. In Edge, WASM capacity was 83,689,472 bytes during the five main cases and grew to **100,466,688 bytes** after the larger identity/recovery workload. JS used heap was 8,798,072 bytes before and 17,466,876 bytes afterward; these are samples with live test objects/temporary allocations, not GC-normalized leak measurements or a continuous JS peak. Renderer RSS and native release allocation were not measured.

The temporary harness renders a minimal surface and runs real source-rule validation; it does not include the playable Arena workload. No claim is made that the owner's existing 2 GB game issue is fixed. Flat evidence validation remains O(N); larger lifetimes need further measurements before activation.

Last test-only Web PCK SHA-256: `bb8b115b79879e7f831e07bf217b5488ff42608477042e2ea202b455a0af3104`. Temporary project: `%TEMP%/arena45m-wasm-fn3IFf/project`. This is not the production Web build or BUILD identifier.

## Remaining limits and safety

- Flush/readback/head replacement and IDB strict durability requests do not prove OS crash/power-loss durability. File fault injection and a process exiting without lease cleanup are simulations.
- Loss of the acknowledged current record without an exact artifact fails closed; the previous snapshot is not a delta log that can recreate newer progress. Damaged authority metadata needs explicit recovery review.
- Local unsigned storage cannot detect replacement/rollback of an entire storage image without an independent watermark. No anti-cheat, multiplayer or external authority is introduced.
- Browser DB version errors fail closed; production error presentation, writer fencing, migration/activation, streaming and real-game integration remain unimplemented.
- No source owner profile was converted/loaded, and no real character directory, backup or personal browser data was accessed. Test fixtures use canonical IDs only inside explicitly disposable storage.

Only the runner changed among previously existing audited files; all other prior work, including project.godot, remains byte-identical. Working tree: 28 modified tracked files, 52 untracked entries including prior work; index empty. No staging, commit, push, reset, rebase, Git cleanup, production Web export or production storage activation occurred.

**Stop after Pass C. Pass D, owner migration and production activation require separate approval.**
