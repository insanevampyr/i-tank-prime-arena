# Task #46J — Compact v3 Edge/IndexedDB Publication Completion

## Status and boundary

**Complete for the authorized dormant, disposable browser acceptance scope. GO for controlled playable integration under a separately authorized task.**

Final actual isolated Edge release-WASM run: **213/213 assertions PASS, zero final failures**. The original strict native/source-oracle comparisons pass for both NORMAL and eligible DEV, including the entire current/evidence body, simulation, movement revisions, events/RNG and exact checkpoint bindings. Nothing is normalized or excluded to obtain parity.

No production implementation correction was needed in this continuation. The changes are test-harness/acceptance corrections and coverage, plus this report. The earlier #46J implementation and the #46J-1 Dodge correction remain byte-identical. No playable saving, owner conversion, production IndexedDB access, production export or Git mutation occurred. #45U remains paused.

The original #46J partial report and #46J-1 report are preserved as historical evidence; this document records the later completion.

## Exact continuation manifest

| Change | File | Purpose |
|---|---|---|
| Modified | `tests/browser/minimal_v3_wasm_harness.gd` | Expose session encounter state separately from the unchanged simulation snapshot; report the actual original checkpoint result from the NAC test command. |
| Modified | `tests/browser/minimal_v3_edge_cases.js` | Correct legal fixture boundaries/credit field access; cold duplicate checks, journal eviction, explicit lost-response retry, checksum-valid conflicting heads, repeated-operation and bounded-layout checks, labelled latency/memory collection. |
| Modified | `tests/browser/minimal_v3_lifecycle_cases.js` | Assert a real pending candidate before fault barriers, test unchanged checkpoints as no-ops, choose a genuine changed profile and measure heartbeat progress with page visibility recorded. |
| Modified | `tests/browser/test_minimal_v3_edge.js` | Append assertion-by-assertion diagnostic results to the disposable run directory. |
| Added | `docs/architecture/TASK_46J_V3_EDGE_PUBLICATION_COMPLETION.md` | This completion report. |

Original LF endings preserved. No coordinator, codec, Windows/native helper, browser transport, save format, combat, reward or progression source changed in this continuation. No existing fixture/oracle bytes changed.

## Recovered implementation and unchanged protocol

The same #46H coordinator-owned pending record and #46J adapter are used. There is no second coordinator or wallet.

- All application database names are gated by `itank-arena-disposable-v3-46j-`. Version 1 has one `characters` store. A profile row contains only `profile`, `head`, `current`, `replica`.
- One actual IndexedDB readwrite transaction writes head/current/replica together. Cooperating writers use the existing Web Locks mechanism; the transaction independently compares the exact expected head. Hashing happens before that transaction.
- A transaction-complete notification is insufficient for acknowledgement. The original coordinator independently rereads the exact selected row, full-cold-validates v3 against trusted source, verifies exact head and both intended copies, then performs another exact-row comparison under owned writer access before adopting its immutable pending bytes.
- The head binds identity, namespace, trusted source, epoch, sequence, commit ID, record hash and UTF-8 size. Snapshot v3 semantics, checksum and full cold validation remain unchanged.
- A retry of exact installed bytes reconciles the original commit without replaying gameplay or adding a generation. Unknown acknowledgement retains the original pending candidate. A late acknowledgement does not reinstall an earlier session or Running model.
- Recovery uses only the exact current/replica matching the authoritative head. A damaged latest copy cannot select an older state. Missing/conflicting head or two damaged latest copies fail closed.

Actual transaction completion/readback is not a guarantee against every browser, OS, disk or hardware-power failure.

## Original blocker: resolved without changing the oracle

#46J-1 moved exactly one successful-Dodge movement spend outside `assert()`. This continuation rebuilt the isolated runtime with that corrected combat source and reran the original comparison **unchanged**. Byte-level comparison of the strict oracle block against this task's entry copy also passed.

Both complete NORMAL and DEV character/evidence projections and full simulation snapshots match the independently validated, frozen native-original controls. These comparisons include actor revisions, timing, event causality, RNG and recent checkpoint request digests, rather than checking a few totals.

The formerly mismatching NORMAL request digest now equals:

`e8a9e284a0ac114a107a29ed7212887de8d2edb91729a193bc655923aa72a6ec`

The corresponding DEV digest equals:

`6e5803b742534e7608beb530063984c1f08b7761cbcad3a4f7f87e3c6d8bc9fa`

Frozen source-oracle SHA-256 values remain:

- NORMAL: `5b94fd69df508133f66ea8d79d9483755b12246fa237368f3c44a85cd90ccee6`.
- DEV: `2c30c0ee9dbdd503d6d0a8fd3d6492919e578d39304162322661cc1472c82299`.

## Actual acceptance / failure-recovery matrix

All rows below executed in actual Edge running Godot release WASM and actual IndexedDB/Web Locks. Faults are explicitly identified as injected. No mocked IndexedDB library substitutes for the browser engine.

| Case | Final result / evidence |
|---|---|
| NORMAL and eligible DEV initial admission, XP/loot and exact source equivalence | PASS; strict whole-body and full-simulation comparisons in both namespaces. |
| Real item acquisition, equip/unequip, handling, potion use | PASS through original gameplay/request APIs and independent cold validation. |
| Terminal zero ownership / irreversible consumption IDs | PASS; quantity zero retained; original consumed ID rejected before any second use/RNG. NORMAL performs 21 subsequent checkpoints to evict the temporary journal summary before cold duplicate rejection. |
| Cold admission of both NORMAL and DEV | PASS; complete saved character/checkpoint body equals the pre-close record; duplicate consumption leaves full simulation unchanged. |
| All five attributes and chronological growth | PASS; genuine STR/DEX/SPD/WIS/END purchases captured, source-backed future END/HPB 2 and WIS 11 growth validated. |
| Fixed +10,000 EXPC credit | PASS; zero EXPM increase; abort and repeated confirmation do not duplicate it; exact proof binding preserved through later purchases, runs, saves and reload. |
| Genuine NEW RUN | PASS; unique additional run, same epoch/namespace, locked new ×1 policy, all prior permanent evidence preserved exactly. Subsequent original defeat/loot resolves a legal downtime checkpoint. |
| NEXT WAVE | PASS in NORMAL, DEV and history scenarios; original entry must be committed/read back before the original session continues. |
| RESUME / actual Page.reload | PASS; complete character/evidence/checkpoint body unchanged after real document reload and cold admission; run multiplier recovered from verified evidence. |
| Consecutive saves / no-op | PASS; unchanged checkpoint produces `simulated_checkpoint_unchanged`, no pending request and no selected-head change. |
| Transaction abort after put | PASS; an actual readwrite transaction is deliberately aborted after staging the row. Previous saved progression remains selected; pending credit is retained and exact retry publishes/acknowledges it once. |
| Injected quota failure | PASS; actual transaction abort reports `QuotaExceededError`; previous head is unchanged, no false acknowledgement; exact pending retry succeeds. This is not physical quota exhaustion. |
| Lost response after transaction completion | PASS; stored head/current/replica contain the exact candidate while the original request remains uncertain. Retry acknowledges that same head without another generation, gameplay replay, reward or RNG mutation. |
| Cancellation before publication | PASS; pending identity retained, no fake retirement; exact retry succeeds. |
| Corrupt current | PASS; exact head-bound replica repaired current through actual CAS transaction and independent cold readback. |
| Corrupt replica | PASS; exact current repaired replica; both copies byte-identical afterward. |
| Both latest copies damaged | PASS, fail closed: `both_latest_copies_damaged`. |
| Missing head | PASS, fail closed: `missing_or_conflicting_head`. |
| Bad head checksum | PASS, fail closed: `invalid_head_checksum`. |
| Checksum-valid conflicting sequence/head | PASS, fail closed: `head_record_conflict`. No “higher sequence wins” shortcut. |
| Checksum-valid unsupported reader version | PASS, fail closed: `unsupported_or_conflicting_head`. |
| Two real tabs | PASS; second writer rejected `profile_in_use` while first owns Web Lock. Its stale candidate is rejected `stale_expected_head` after the first commits. |
| Gameplay after capture | PASS; external Running changes while publication awaits a barrier; earlier readback does not restore the earlier live movement state. |
| Interrupted before transaction | PASS; actual `Page.reload` tears down the document at a controlled pre-transaction barrier; the prior acknowledged head remains selected and cold-admits. |
| Interrupted after commit, before response | PASS; real reload at the post-commit barrier; fresh runtime recovers the exact new bytes and both copies, without duplicate credit. |
| Repeated operations / no generation archive | PASS; 24 additional genuine history checkpoints keep recent journal at 20 and immutable credit proof at one record. Store inspection finds exactly one profile row and one store, with only head/current/replica fields. |
| Separate 1,005-item source fixture | PASS; complete inventory preserved through real source checkpoint/publication/readback; full cold validation remains enabled. |
| Disposal / browser operation isolation | PASS; after close and collection, current document bridge reports zero stores and zero jobs; production database is absent from the isolated origin. |

No occupied-profile restore, portable backup, production data migration, real process kill or hardware power-loss test was added. Controlled document teardown is actual browser lifecycle evidence, not an OS-crash claim.

## Necessary test corrections and preliminary failures

The first complete basic matrix passed **133 checks**. Expanded coverage then revealed fixture/assertion mistakes, not production adapter defects:

1. Encounter state was looked up on a simulation snapshot, where it does not exist. The harness now exposes the original session's `get_encounter_state()` separately. The strict simulation oracle is untouched.
2. The quota setup tried to persist an arbitrary `entry` after NEW RUN. Original source correctly rejects writes outside the authorized entry boundary. The fixture now completes genuine combat/loot and checkpoints at legal downtime, and explicitly requires a pending candidate before fault injection.
3. The new repeated-credit assertion initially treated credit evidence as an array. Its original schema is a dictionary containing `records`; the test checks one record and exact unchanged binding.
4. After repeated saves the lifecycle fixture requested the already selected NAC profile. The original helper correctly recognized unchanged persistable state, so no transaction/barrier occurred. The test explicitly verifies that no-op, then chooses a genuinely different legal profile for the competing-writer case.
5. A 100 ms heartbeat expectation failed when creation of the competing tab backgrounded the first page. The test records visibility and requires bounded progress within 3 seconds instead. Final sample: hidden page, heartbeat observed after 107 ms. Timer throttling is not treated as a gameplay or storage-rule defect.

The final 213-check run exits 0. Earlier failed diagnostic logs are preserved; they are not represented as passing runs. No assertion in the original strict source comparison was weakened, suppressed or normalized.

## Latency results

Actual final Edge run, single sequential matrix with the sample counts below. Percentiles use median and nearest-rank p95. Source-command wall time includes original gameplay dispatch as well as persistence. Capture-to-ack and browser-protocol timing have different start points; IDB transaction time excludes pre-transaction hashing/authorization. These are diagnostic-harness results, not production UI latency guarantees.

| Workload | Checkpoints | Source-command wall p50 / p95 / max (ms) | Capture-to-ack p50 / p95 / max (ms) | IDB transaction p50 / p95 / max (ms) |
|---|---:|---:|---:|---:|
| NORMAL | 29 | 234.9 / 269.6 / 368.0 | 207.8 / 241.5 / 307.6 | 11.5 / 14.4 / 16.4 |
| DEV | 8 | 278.4 / 316.0 / 316.0 | 233.1 / 265.3 / 265.3 | 11.4 / 12.3 / 12.3 |
| Historical-source / purchased / credited multi-run character | 39 | 347.6 / 610.5 / 701.7 | 319.9 / 492.0 / 545.5 | 12.9 / 14.4 / 14.6 |
| Separate 1,005-item stress | 1 | 4,188.8 single sample | 4,141.0 single sample | 27.2 single sample |

- Committed cold-readback validation: NORMAL median 17.3 ms, max 25.5 ms; DEV median 24.4 ms, max 26.5 ms; history median 36.6 ms, max 66.9 ms; stress 643.2 ms.
- Full read/lock/validation/release during cold reader admission: NORMAL 118.5 ms; DEV 118.6 ms; history reload samples 124.4–132.9 ms. Current/replica repair: 179.2 and 203.0 ms.
- Source fixture/coordinator admission: NORMAL 65.3–104.9 ms, DEV 81.9–91.7 ms, history 69.3–188.6 ms. These initial fixture admission measurements are separate from the actual stored-record cold-reader/hydration workflow.
- Stress initial full admission: 994.1 ms. Stress preparation 495.3 ms, including authorization/capture 142.4 ms, construction 54.0 ms and codec encode 298.9 ms; browser protocol 3,572.9 ms. Full independent persisted readback is retained.
- History record after repeated saves: **46,358 UTF-8 bytes**, with 20 summaries. Stress record: **1,107,597 bytes**, plus its identical replica and small head. Physical IndexedDB file size/engine overhead was not measured.

Representative workloads met the desired 1–3 second range comfortably. The labelled 1,005-item stress save took about 4.14 seconds, outside that range; it is not advertised as a subsecond or fully optimized save. No further optimization, worker, cache, full-validation removal or architecture change was attempted.

No new native benchmark or full native regression was needed for this continuation because no production/source implementation changed. Prior native results in #46J/#46J-1 are retained evidence, not relabelled as new runs or directly compared to these end-to-end browser timings. The original independently validated native fixtures remain the strict comparison oracle.

## Browser memory and responsiveness observations

Bytes below are direct final-run samples. WASM figures are linear-memory **capacity**, not live character allocations; retained capacity need not shrink after free. JS heap figures and renderer working sets measure different allocations and must not be added as independent physical memory.

| Point | JS used heap (bytes) | WASM capacity (bytes) | Largest CDP-reported renderer working set (bytes) |
|---|---:|---:|---:|
| Fresh release | 10,919,580 | 120,586,240 | 340,480,000 |
| Before 24 repeated history saves | 22,003,348 | 120,586,240 | 373,547,008 |
| After those saves | 19,132,204 | 120,586,240 | 368,005,120 |
| After explicit JS GC | 8,155,232 | 120,586,240 | 330,067,968 |
| Before stress, following lifecycle reloads | 25,342,872 | 120,586,240 | 518,234,112 |
| After stress checkpoint | 17,704,480 | 208,404,480 | 461,848,576 |
| All current-document contexts closed + JS GC | 7,769,392 | 208,404,480 | 423,419,904 |

Largest reported renderer process peak: **638,787,584 bytes**. Raw renderer-set working-set sums are retained in `results.json` (roughly 0.74–0.91 GB across six to eleven reported renderers); those sums can double-count shared pages and are not one target's private memory. Exact target-to-renderer mapping was not established, so this report does not claim a particular single-tab RSS total. Lifecycle reloads also change document/heap ownership; cross-reload samples are not a same-heap leak experiment.

Across 24 same-document saves, WASM capacity stayed constant and used JS heap fell after collection. After the large stress record, WASM retained its higher capacity even though bridge stores/jobs returned to zero and JS used heap fell. This bounded experiment does not demonstrate an unbounded leak or prove one impossible. It does not explain or certify the owner's legacy 2 GB browser case.

The JS event loop continued at the asynchronous barrier even while its page was hidden. Maximum final-document 20 ms heartbeat overrun was **2,258.4 ms**, including the stress workload. The earlier competing-tab sample observed a 984.5 ms maximum while backgrounded. Background timer clamping and synchronous Godot validation both affect these counters; they are not a pure foreground-input latency measurement. There are no visual production UI/click tests here. The stress case has a real responsiveness limitation requiring acceptance in a later controlled integration, not a claim of smooth controls throughout every heavy cold validation.

## Environment, artifact and repeatability

- Actual isolated headless **Edge 158.0.4370.33**, V8 **15.8.13.3**, Windows.
- Godot **4.7.2 stable official ed1daf0bf**, Emscripten **4.0.20**, single-threaded release WASM, no GDExtension, WebGL2 software rendering.
- Existing runner imports/exports an OS-TEMP diagnostic project, creates its own browser user-data directory, and serves a random loopback origin with no-store caching. It never attaches owner Edge or serves/deploys a production build.
- Final exported runtime, coordinator helper, browser transport/reader and GDScript harness copies match the working-tree bytes. Node acceptance modules execute directly from the current test sources; they are not Web game code.
- Final import/export logs contain no script/parser error or warning match. Three modified JS files pass `node --check`; `git diff --check` passes, with only pre-existing LF/CRLF notices for unrelated files.

Isolated PCK SHA-256: `5cbf741574404dbe3eb1f58c0f68c30e9b789ec4ad47cdd1cda3873d9c8b2536`. No production BUILD identifier was issued.

Focused commands used:

```powershell
node tests/browser/test_minimal_v3_edge.js
# After Node-only test changes, reuse the exact same already exported runtime:
node tests/browser/test_minimal_v3_edge.js --reuse
node --check tests/browser/test_minimal_v3_edge.js
node --check tests/browser/minimal_v3_edge_cases.js
node --check tests/browser/minimal_v3_lifecycle_cases.js
git diff --check
```

Disposable evidence root: `C:\Users\mxz\AppData\Local\Temp\arena46j-completion-b0qqgm8p`. The diagnostic pointer is `%TEMP%/arena46j-current-root.txt`.

Definitive final evidence: `results.json` (`success:true`, `assertions:213`), `final-checks.json` (exactly 213 passing entries), `partial-results.json`, `checks.log`, import/export logs and `project/web/`. `checks.log` retains multiple attempts; only its final assertion-1 through assertion-213 segment is extracted into `final-checks.json`. The final console is `%TEMP%/arena46j-completion-accepted-final.log`.

The earlier successful 133-check run is saved under `run-133/`. Earlier failures remain in the named diagnostic logs. Original prior-task evidence directory and all its fixtures were preserved; copied frozen fixture/oracle SHA-256 values are in `baseline.json` and were rechecked unchanged.

## Preservation and remaining integration boundary

- Branch `main`, HEAD `f9bb0db0235b0003895c477a12346191d4714469` unchanged; staged index empty. No commit, push, reset, rebase, stash or cleanup.
- Of **805** entry-hashed existing project source/test/docs/config/tool files, only the four test files in the manifest changed; no entry file disappeared. All production code, codecs, Windows storage/native helper, #46J implementation, #46J-1 correction, prior reports, Roadmap and Combat Specification remain byte-identical.
- `project.godot` retains its prior modification and exact SHA-256 `8398f110f77d7712eb19c283eb9f745c7123feab9557187778da412639ba5692`.
- Owner saves, backups, protected boss documents, `character saves/`, repository `tmp/` and production browser storage were not opened or modified. Source-backed disposable fixtures may use the same catalog identity names; they are not owner progression data.
- Existing #45U work remains paused. No production export, database upgrade, profile migration, portable backup/restore, networking or additional feature work.
- Controlled playable integration remains a separately approved task. It must retain full cold validation/readback, writer/CAS authority, feature isolation and fail-closed handling of unsupported legacy evidence. Missing historical irreversible facts must not be fabricated merely to admit an owner profile.
- Real production UI/owner acceptance, production storage routing, legacy-character policy and stress responsiveness acceptance remain outside this completion. No storage activation is authorized or performed by this report.

Final Git status: **35 modified tracked files; 226 collapsed untracked entries**, including the preserved earlier work and protected-path names. The task-relative five-file manifest is above; full path-only status is retained in `C:\Users\mxz\AppData\Local\Temp\arena46j-completion-b0qqgm8p\final-git-status.txt`.

**GO for controlled playable integration under separate owner authorization. STOP after #46J; no automatic activation or continuation.**
