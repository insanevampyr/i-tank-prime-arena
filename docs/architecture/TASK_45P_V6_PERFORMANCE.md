# Task 45P - Compact V6 performance instrumentation and exact-ID optimization

2026-11-17. Stage S1 only. V6 remains dormant. No production activation, migration, owner-data access, persistent index/format change or production Web export.

## Scope and files

Baseline: main, HEAD `f9bb0db0235b0003895c477a12346191d4714469` plus preserved 45B-45O work. The requested 45O/45K/45L/45M/45N documents and implementation were inspected before changes. Measurements below are disposable proof workloads, not owner-profile or playable-game acceptance.

Modified existing files in this pass:

- `scripts/rewards/compact_character_v6_prototype.gd` - operation-local exact lifetime binding lookup in validate_extension (this file was already untracked before S1).
- `scripts/rewards/character_persistence_coordinator.gd` - exact receipt-ID buckets in _validate_continuity; original whole-receipt equality retained.
- `tests/test_runner.gd` - adds only the 45P suite preload/registration to its pre-S1 state; all previous registrations retained.
- `tests/browser/test_compact_v6_storage_edge.js` - optional --perf-before/--perf-after test modes, TEMP-project instrumentation and profiling result output. Ordinary production storage/browser code unchanged.

Added files:

- `tests/compact_v6_perf_trace.gd` and `.gd.uid` - test-only timed frames, calls, exclusive/inclusive time and live allocation deltas.
- `tests/compact_v6_performance.gd` and `.gd.uid` - deterministic disposable workloads, measurements and frozen-oracle comparisons.
- `tests/compact_v6_performance_process.gd` and `.gd.uid` - native test process and repeated filesystem backup/recovery workflow.
- `tests/test_compact_v6_performance.gd` and `.gd.uid` - targeted oracle, authorization, canonical-byte and unchanged-simulation assertions.
- `tests/oracles/compact_v6_linear_45p.gd` and `.gd.uid` - frozen full pre-optimization V6 validator, with its coordinator dependency redirected to the frozen coordinator.
- `tests/oracles/character_coordinator_linear_45p.gd` and `.gd.uid` - frozen full pre-optimization coordinator; global class_name removed only to prevent a class-name collision.
- `tests/profile_compact_v6.py` - TEMP-project instrumenter and bounded native-process runner, with own-process memory sampling.
- `tests/browser/compact_v6_performance_edge_cases.js` - actual release-WASM/IndexedDB benchmark and oracle cases.
- This report.

There are 19 intentional added/modified files including six UID sidecars. The additional file `tests/__pycache__/profile_compact_v6.cpython-314.pyc` generated during syntax checking is a disposable, untracked bytecode artifact, not source or an intended checkpoint file. No cleanup or Git mutation was performed.

## Instrumentation and fixture method

All fine-grained hooks are injected into **TEMP copies** of the project. No instrumentation, trusted-result cache or new verification flag is installed in gameplay logic. Native runs use Godot 4.7.2 Windows headless debug/editor; Edge runs use a separately exported Godot 4.7.2 release WASM test project, a new Edge user-data directory, random localhost origin and only the separate disposable IndexedDB names. Neither the production export nor the owner's browser is used.

The original algorithms were measured before changing either production lookup. Frozen original validators remain the full semantic oracle afterward; shared rule validators are unchanged. Sample counts are five for core stages, three for ancestry and complete workflow cycles. p50/p95 use nearest rank, so p95 equals maximum with these small sample counts. These are samples, not latency guarantees. No competing heavy benchmarks were intentionally run during timed samples.

Fixtures:

| Fixture | Operations / exact scoped IDs | Encoded V6 bytes | Evidence |
|---|---:|---:|---|
| ops1000 | 1000 / 1445 | 542550 | Existing independently validated 45M lifetime fixture |
| ops10000 | 10000 / 10445 | 2872757 | Core endpoint stress; 9000 extra source-valid no-op transport identities |
| awards | 204 / 628 | 268882 | 200 source-valued awards, original seeded growth, interleaved END/WIS purchases and existing fixed EXPC credit |
| inventory | 5 / 2032 | 1349477 | 1000 additional unique, fully bound synthetic gold acquisition instances/receipts; not a claim of gameplay-earned loot |
| chain100 | 105 / 132 | 61478 | 100 genuine complete reversible compact transitions |
| chain501 | 506 / 533 | 161347 | 501 genuine complete reversible compact transitions |

The 10,000-operation endpoint intentionally does **not** claim a complete portable ancestry or a legacy conversion of 10,000 generations. Its sequence exceeds the existing portable 4096 transition cap; that guard was not raised. Full ancestry uses the separate 100/501 histories. Their history files contain deltas, not repeated complete snapshots. No whitespace padding substitutes for semantic workload.

Measured stages: candidate assembly, canonical encode, decode, semantic validation/historical hydration, full extension validation, scoped ID lookup, settlement continuity, portable ancestry/export/preview, storage publication/write/readback/load/restore/recovery. JSON.stringify and simple receiver SHA-256 sites are timed. Chained serialize-then-hash expressions remain in V6.digest/outer exclusive time: the hash.sha256 category is **not all hash work**. Inclusive timers overlap; attribution below uses exclusive timers. Allocation deltas are live-byte deltas, not total allocation traffic or retained-object proofs.

## Evidence-backed bottlenecks

The matched fine native baseline measured 10,000-ID extension median 4106.462 ms. Its original lifetime scan consumed 16783.879 ms across five checks, about 3356.776 ms per check and 80.4% of total measured extension time. Both endpoints were still fully validated.

For the high-inventory extension, the original lifetime scan cost 511.079 ms across five checks; receipt membership cost another 114.561 ms. Both were repeated linear membership scans.

The complete 1000-operation native workflow is different. Across three cycles its baseline exclusive totals included Profiles.hydrate 16459.317 ms / 366 calls, V6.decode 12169.258 ms / 90 calls, JSON.stringify 7777.609 ms / 570033 calls and V6.validate 4079.956 ms / 366 calls. Lifetime membership was only 1483.638 ms / 42 calls; filesystem write work was 343.629 ms / 45 calls. The lookup is a dominant **large-ID extension** bottleneck, not the dominant end-to-end save bottleneck. Repeated full decode, semantic/historical proof and canonical serialization remain expensive. These counts cover the entire workflow, not one save.

Canonical serialization is demonstrably frequent; the measurements do not establish that its verification passes can safely be removed. Browser bridge totals include JSON payloads crossing the harness, not network/IDB disk bytes. Native filesystem timing does not prove browser IDB overhead dominates. No caches, incremental proof trust, ancestry redesign or full-validation removal were introduced.

## Exact algorithmic changes

1. V6.validate_extension still fully validates previous and candidate first, including canonical ID reconstruction and duplicate rejection. Its old array-membership fallback is replaced by a local dictionary keyed by the complete JSON tuple `[scope, id]`. Every original row must equal the candidate's complete immutable binding row. Canonical array order is unchanged; the registry/prefix and evidence-order validators remain authoritative. Expected fallback lookup cost changes from repeated O(P*C) comparisons to O(C+P) dictionary work, with O(C) transient memory.
2. Coordinator._validate_continuity builds local buckets keyed by the exact `['settlement', receipt_id]` tuple. It still requires full Dictionary equality within the matching bucket. Buckets deliberately preserve the original helper's behavior for invalid raw duplicate/missing-ID input; the unchanged complete receipt validator rejects invalid receipts. On valid unique IDs, continuity changes from repeated O(P*C) comparisons to O(C+P). Duplicate-key buckets are not a new duplicate authorization rule.
Matched fine lookup-inclusive totals (including newly timed full-key JSON work) confirm the improvement inside the algorithm itself:

| Lookup | Before mean ms/check | After mean ms/check |
|---|---:|---:|
| 10k lifetime membership | 3356.776 | 131.949 |
| High-inventory lifetime membership | 102.216 | 26.936 |
| High-inventory settlement membership | 22.912 | 14.829 |

3. `_find_transaction` was inspected and remains unchanged. It performs two bounded linear scans for one reconciliation request; constructing an index there would not remove an established quadratic workload. Authorization, trusted verifier, purchase/growth/award validation, item ownership, source checks, exact readback and cold validation are unchanged.

No probabilistic/truncated identity, persistent secondary index, journal-only duplicate protection, new format or balance-only validation. IDs older than the 20-entry recent journal remain in the full registry and are tested for reuse. No map is encoded and no chronology is sorted or rewritten.

## Native before/after results

All numbers are instrumented milliseconds. The 10k, inventory and workflow rows use matching fine hooks before/after. Other rows use coarse method hooks (the initial TEMP wrapper method-name collision was corrected before the successful workflow run; it was a profiler defect, not a storage defect). Completed fine baseline and final runs have no script failures.

| Workload/stage | Before p50 / p95 / max ms | After p50 / p95 / max ms |
|---|---:|---:|
| ops1000 / construct | 42.650 / 43.119 / 43.119 | 42.851 / 43.703 / 43.703 |
| ops1000 / encode | 169.774 / 171.615 / 171.615 | 174.191 / 177.397 / 177.397 |
| ops1000 / decode | 303.157 / 318.300 / 318.300 | 303.341 / 309.497 / 309.497 |
| ops1000 / validate | 154.081 / 174.729 / 174.729 | 159.185 / 161.821 / 161.821 |
| ops1000 / extension | 391.744 / 408.269 / 408.269 | 381.544 / 385.453 / 385.453 |
| ops10000 / construct | 242.106 / 242.600 / 242.600 | 236.741 / 243.544 / 243.544 |
| ops10000 / encode | 430.824 / 432.244 / 432.244 | 427.563 / 430.996 / 430.996 |
| ops10000 / decode | 1105.217 / 1114.119 / 1114.119 | 1109.265 / 1118.999 / 1118.999 |
| ops10000 / validate | 347.030 / 350.586 / 350.586 | 349.540 / 350.282 / 350.282 |
| ops10000 / extension | 4106.462 / 4399.251 / 4399.251 | 934.942 / 964.635 / 964.635 |
| awards / construct | 17.885 / 18.048 / 18.048 | 19.379 / 20.725 / 20.725 |
| awards / encode | 111.198 / 121.222 / 121.222 | 121.281 / 144.429 / 144.429 |
| awards / decode | 186.159 / 227.717 / 227.717 | 168.758 / 170.638 / 170.638 |
| awards / validate | 115.643 / 130.755 / 130.755 | 102.457 / 104.869 / 104.869 |
| awards / extension | 222.533 / 272.197 / 272.197 | 231.109 / 232.138 / 232.138 |
| inventory / construct | 88.966 / 92.074 / 92.074 | 112.895 / 121.901 / 121.901 |
| inventory / encode | 244.647 / 246.789 / 246.789 | 289.048 / 310.766 / 310.766 |
| inventory / decode | 544.471 / 551.310 / 551.310 | 558.799 / 583.932 / 583.932 |
| inventory / validate | 219.957 / 237.962 / 237.962 | 210.078 / 211.692 / 211.692 |
| inventory / extension | 643.413 / 670.768 / 670.768 | 562.028 / 601.032 / 601.032 |
| chain100 / history | 8257.956 / 8273.896 / 8273.896 | 8489.676 / 8528.640 / 8528.640 |
| chain501 / history | 48270.912 / 49189.423 / 49189.423 | 50344.079 / 50375.979 / 50375.979 |
| 1000 workflow / construct | 44.503 / 46.032 / 46.032 | 45.317 / 48.606 / 48.606 |
| 1000 workflow / encode | 176.708 / 179.569 / 179.569 | 175.555 / 179.388 / 179.388 |
| 1000 workflow / export | 2772.339 / 2806.542 / 2806.542 | 2721.638 / 2728.904 / 2728.904 |
| 1000 workflow / load | 1125.758 / 1156.838 / 1156.838 | 1108.345 / 1124.560 / 1124.560 |
| 1000 workflow / preview | 806.659 / 810.881 / 810.881 | 790.262 / 803.312 / 803.312 |
| 1000 workflow / recovery | 2281.870 / 2298.657 / 2298.657 | 2258.880 / 2281.740 / 2281.740 |
| 1000 workflow / restore | 4530.607 / 4534.242 / 4534.242 | 4465.749 / 4470.408 / 4470.408 |
| 1000 workflow / save | 3678.367 / 3696.349 / 3696.349 | 3626.006 / 3697.927 / 3697.927 |

10k extension median improved 77.2%; 1000-operation workflow save improved only 1.4%. Small/long-proof workloads show noise or slower samples; this is not a universal speedup. Native 501-transition full-proof median is still about 50 seconds and did not improve. Routine native save still exceeds the 1-3 second target. Scope was not broadened to remove proof passes.

## Edge release results

Actual isolated headless Edge, Godot 4.7.2 **release WASM**, real disposable IndexedDB. Baseline completed before the optimization; fresh browser/profile/project for the final run. Instrumentation enabled in both. Same fixture record/candidate hashes and accounting in both runs.

| Workload/stage | Before p50 / p95 / max ms | After p50 / p95 / max ms |
|---|---:|---:|
| ops1000 / construct | 40.200 / 45.500 / 45.500 | 62.200 / 74.700 / 74.700 |
| ops1000 / encode | 104.300 / 105.900 / 105.900 | 147.600 / 208.300 / 208.300 |
| ops1000 / decode | 207.900 / 208.400 / 208.400 | 277.000 / 286.900 / 286.900 |
| ops1000 / validate | 87.800 / 89.300 / 89.300 | 155.100 / 167.500 / 167.500 |
| ops1000 / extension | 290.200 / 304.500 / 304.500 | 380.600 / 477.600 / 477.600 |
| ops10000 / construct | 221.300 / 221.900 / 221.900 | 223.900 / 243.500 / 243.500 |
| ops10000 / encode | 381.700 / 389.600 / 389.600 | 414.300 / 502.500 / 502.500 |
| ops10000 / decode | 963.300 / 989.500 / 989.500 | 964.000 / 968.500 / 968.500 |
| ops10000 / validate | 311.600 / 316.900 / 316.900 | 321.200 / 345.000 / 345.000 |
| ops10000 / extension | 6282.800 / 10082.500 / 10082.500 | 1185.200 / 1260.200 / 1260.200 |
| awards / construct | 16.100 / 17.000 / 17.000 | 18.500 / 20.800 / 20.800 |
| awards / encode | 44.500 / 51.100 / 51.100 | 51.200 / 65.300 / 65.300 |
| awards / decode | 88.800 / 107.800 / 107.800 | 100.100 / 102.200 / 102.200 |
| awards / validate | 36.700 / 37.100 / 37.100 | 42.700 / 42.800 / 42.800 |
| awards / extension | 98.100 / 104.400 / 104.400 | 107.900 / 110.500 / 110.500 |
| inventory / construct | 85.200 / 91.500 / 91.500 | 87.000 / 88.200 / 88.200 |
| inventory / encode | 207.900 / 220.500 / 220.500 | 230.500 / 290.300 / 290.300 |
| inventory / decode | 428.900 / 446.400 / 446.400 | 457.500 / 476.700 / 476.700 |
| inventory / validate | 171.100 / 177.100 / 177.100 | 170.900 / 173.100 / 173.100 |
| inventory / extension | 613.500 / 626.200 / 626.200 | 471.100 / 513.600 / 513.600 |
| chain100 / history | 1783.800 / 1787.400 / 1787.400 | 1909.100 / 1933.900 / 1933.900 |
| chain501 / history | 15895.900 / 16412.100 / 16412.100 | 16685.100 / 16853.500 / 16853.500 |
| 1000 IndexedDB workflow / construct_encode_bridge | 388.300 / 393.100 / 393.100 | 395.100 / 533.200 / 533.200 |
| 1000 IndexedDB workflow / save | 3772.300 / 3779.500 / 3779.500 | 3571.500 / 3576.900 / 3576.900 |
| 1000 IndexedDB workflow / load | 1039.800 / 1119.200 / 1119.200 | 957.000 / 968.400 / 968.400 |
| 1000 IndexedDB workflow / export | 1760.000 / 1801.100 / 1801.100 | 1689.700 / 1853.100 / 1853.100 |
| 1000 IndexedDB workflow / preview | 737.000 / 792.300 / 792.300 | 691.600 / 703.400 / 703.400 |
| 1000 IndexedDB workflow / restore | 2613.700 / 2723.400 / 2723.400 | 2490.300 / 2539.900 / 2539.900 |
| 1000 IndexedDB workflow / recovery | 2039.100 / 2065.400 / 2065.400 | 1934.600 / 1997.300 / 1997.300 |

10k extension median improved 81.1%; complete 1000-operation save median improved 5.3%. The 1000-ID core extension and 100/501-transition proof samples were slower, not improved. Extra full-key serialization/instrumentation overhead and fresh-browser warmup/variation limit smaller-workload conclusions. The optimization is justified by the large-ID case; it does not solve long ancestry replay. Cold load is exercised, but repeated benchmark loops include warm allocator/JIT effects.

Bridge measurements (comparable performance phase, before extra after-only oracle calls):

| Metric | Before | After |
|---|---:|---:|
| calls | 93.000 | 93.000 |
| sent | 65869759.000 | 65869759.000 |
| received | 93523902.000 | 93523952.000 |
| max_sync_ms | 73791.400 | 50423.600 |
| total_ms | 185207.300 | 158858.500 |

Sent/received are UTF-8 JSON argument/result bytes, not protocol overhead or physical storage traffic. The 50.4/73.8-second maximum synchronous callbacks batch several benchmark repetitions; they are **not single-save durations**, but they expose remaining synchronous work. No responsive gameplay UI acceptance is inferred.

Disposable test PCK SHA-256 before: `dea530cd593058be40297443c0d76e19dfdfea201264a5d0f70d136a95853f84`.
Disposable test PCK SHA-256 after: `fb3a591cd13b3945f06092a05267f5ec82e521604476acf0fdd44b7c8b455874`.
These are isolated harness artifacts under TEMP, not production builds or a new production BUILD identifier.

## Oracle, rejection and integrity tests

Native 45P: 278 assertions PASS in the targeted full-oracle run. Each fixture tests complete original-versus-optimized acceptance/reason/result equality for valid inputs, missing/duplicate/reordered/conflicting lifetime IDs, reused old operation, altered request binding, duplicate old award/purchase wrapped in a fresh operation, changed/missing growth, changed chronology, stale head and changed current accounting bytes. Rehashed envelopes do not substitute for valid semantic evidence. The comparison also checks canonical encoded bytes, changed source, coordinator continuity and unchanged receipt validation with missing/duplicate/reordered/altered receipts. Inputs and authored source stay unchanged.

Additional native assertions compare authorization refusal, forged prepared bytes and the unchanged transaction reconciliation against the frozen coordinator. A real interleaved END/WIS/award fixture verifies source-correct original growth and unchanged complete simulation snapshot, including RNG/events/resources. Exact canonical output matches the oracle and before/after benchmark artifacts for all six fixtures. The deterministic transport candidate used by performance samples (`perf_next`) intentionally has a different request ID/hash from the oracle candidate (`equivalence_next`).

Actual Edge final harness: **41/41 outer checks PASS**, including six full-oracle fixture checks containing **264 nested assertions** (not 264 additional independent harness operations). Baseline harness: 35/35 checks. The final run includes real WASM semantic proof, IndexedDB interruption/abort/lost acknowledgement, competing writers, version/profile isolation, old operation and reward wrapped in a new operation rejection, exact repair, repeated portable workflow and page/WASM reload. No Godot/JS errors. The production database name is rejected before open; its absence is explicitly asserted.

Native final focused results: **6/6 suites PASS**, zero failing assertions. Five suites print **2202 total assertions**; the unchanged coordinator suite does not report its count. This is a focused checkpoint, not full regression certification.

| Focused filter | Reported assertions | Result |
|---|---:|---|
| 45P | 278 | PASS |
| 45K | 814 | PASS |
| 45L | 912 | PASS |
| 45M | 62 | PASS |
| 45N | 136 | PASS |
| Task 36J-Pass2 | Not printed | PASS |

45L rechecks disposable V2/V4/V5 conversion, credit predecessors, original END/HPB/WIS growth, independent character equivalence, damage/ambiguity rejection and changing source bytes. 45M rechecks publication/readback, lost acknowledgements, stale writers, 1000+ operation deduplication and exact repair. 45N rechecks malformed/rehashed files, immutable export, explicit restore authorization, older/unrelated backups, cancellation, interruption, exact recovery and repeated restore across small/168/221/233/400/1000 workloads. Parallel focused-suite timings are not used as performance benchmarks.

Final completed runs contain no script errors, warnings or resource-leak reports. Node syntax checks, Python AST parsing (without bytecode output), `git diff --check` and whitespace/final-newline checks of all 19 intended files pass. Six new UID sidecars are unique and syntactically valid. No full regression or production import/export was run.

Exact focused commands after setting fixture paths as shown below:

```powershell
& $godot --headless --path . --script tests/test_runner.gd -- '--suite=45P'
& $godot --headless --path . --script tests/test_runner.gd -- '--suite=45K'
& $godot --headless --path . --script tests/test_runner.gd -- '--suite=45L'
& $godot --headless --path . --script tests/test_runner.gd -- '--suite=45M'
& $godot --headless --path . --script tests/test_runner.gd -- '--suite=45N'
& $godot --headless --path . --script tests/test_runner.gd -- '--suite=Task 36J-Pass2'
node --check tests/browser/compact_v6_performance_edge_cases.js
node --check tests/browser/test_compact_v6_storage_edge.js
git diff --check
```

45P requires its explicit disposable fixture root; 45N retains its existing explicit 45M-fixture prerequisite. Fixture generation, if reproducing in a fresh disposable root, uses `python tests/profile_compact_v6.py build <returned-temp-project> <new-compact45m_45p-root> <existing-45M-fixture-root>` before the suite/benchmark commands. All roots must pass the existing cache-only guards. Do not point them at profile storage.


## Memory, limitations and activation gates

Native fine workflow largest sampled engine-process peak working set: 358912000 bytes before, 353660928 after. Native Godot allocator peak: 220997539 before, 221033898 after. 10k endpoint process peak: 352423936 before, 354852864 after. These do not establish a retained-memory improvement. The sampler records the maximum individual own-process working set, not a simultaneous process-tree sum. Shutdown last-RSS values are not used to infer leaks or reclamation.

| Release Edge performance-phase memory | Before bytes | After bytes |
|---|---:|---:|
| JS used before requested GC | 63335604 | 65800244 |
| JS used after requested GC | 8056808 | 8117520 |
| WASM capacity | 250085376 | 250085376 |

Memory was captured before the after-only oracle matrix to keep phases comparable. Requested JavaScript GC reduced used JS heap in each run; WASM capacity did not shrink. These are sampled endpoints, not renderer RSS/peak or proof of native object retention. Edge renderer RSS/peak and total allocation counts were **not measured** in this pass; they must not be inferred from JS heap or WASM capacity. No conclusion about the owner's previously reported 2 GB tab can be drawn from these disposable cases.

Full proof/replay/serialization remains the primary macro bottleneck; routine save performance is not solved by this pass. The local maps add transient memory and stringify full keys; tiny workloads can pay overhead. Large batches still block WASM synchronously; no responsive playable-UI claim is made. No allocation stack profiler or complete SHA attribution was collected. Native debug/editor, instrumented release WASM and owner gameplay are separate environments. No Windows exported-release or owner-browser acceptance is claimed.

45O activation blockers remain: a live candidate builder with authoritative event ordering, and a source-backed post-conversion EXPC-credit extension. Neither is implemented here. No S2, production coordinator activation or schema change was attempted.

## Commands and retained evidence

From the primary repository (not the older export worktree):

```powershell
$godot = 'C:/Users/mxz/Desktop/GoDot/Godot_v4.7.2-stable_win64_console.exe'
$root = "$env:LOCALAPPDATA/itank-storage-tests/compact45m_45p_session_20261117"
$env:ARENA45P_FIXTURES = $root
$env:ARENA45M_FIXTURES = "$env:LOCALAPPDATA/itank-storage-tests/compact45m_session_20261117b"
& $godot --headless --path . --script tests/test_runner.gd -- '--suite=45P'
# Performance commands were run before changing either lookup, then repeated afterward:
python tests/profile_compact_v6.py prepare before-final-fine
python tests/profile_compact_v6.py run <returned-temp-project> $root before-fine ops10000 inventory workflow
python tests/profile_compact_v6.py prepare after-fine
python tests/profile_compact_v6.py run <returned-temp-project> $root after-fine ops10000 inventory workflow
# Coarse before/after projects measured ops1000, awards and full chain100/chain501 proof.
node tests/browser/test_compact_v6_storage_edge.js $root --perf-before
node tests/browser/test_compact_v6_storage_edge.js $root --perf-after
```

`prepare before...` measured the source then present; the name is a result label, not a switch that restores old code. For later baseline reproduction, use the frozen originals in a new disposable project; never revert the checkout. Fine baseline lookup blocks were profiled without changing their decisions.

Native result artifacts: native-before.json, native-before-fine.json, native-after.json, native-after-fine.json in the disposable root. Edge artifacts: edge-results-before.json, edge-performance-before.json, edge-results-after.json, edge-performance-after.json. Logs: `%TEMP%/arena45p-*`. No fixture/result file is part of the intended source manifest.

## Git and protected data

Branch main; HEAD `f9bb0db0235b0003895c477a12346191d4714469`; index empty. 29 modified tracked paths and 75 collapsed untracked status entries. No staging, commit, push, reset, stash, rebase, clean or other Git mutation.

An 88-file SHA-256 preservation snapshot includes the prior pending nonprotected files and the previously clean coordinator. Exactly the four intended existing files listed above differ; all other 84 snapshot entries match byte-for-byte. In particular, project.godot remains the owner's existing modification with SHA-256 `8398f110f77d7712eb19c283eb9f745c7123feab9557187778da412639ba5692`. Older 45B-45O documents/source/test changes remain intact.

Protected `assets/Rare Human Warrior (Boss).doc`, `character saves/`, repository `tmp/`, owner backups and browser storage were not opened or changed. The following Git output names protected paths only; no protected content was inspected. Disposable test directories/DBs and TEMP harness artifacts remain separate. No production Web files or production export settings were changed. No new credit authorization, database upgrade or combat/simulation-schema change.

Exact `git status --short` at report completion (directories collapsed as Git reports them):

```text
 M project.godot
 M scripts/combat/arena_combat_session.gd
 M scripts/combat/character_development.gd
 M scripts/combat/combat_actor_definition.gd
 M scripts/combat/combat_simulation.gd
 M scripts/movement/prime_movement_model.gd
 M scripts/player/placeholder_player.gd
 M scripts/rewards/arena_reward_ledger.gd
 M scripts/rewards/character_backup_contract.gd
 M scripts/rewards/character_backup_reader.gd
 M scripts/rewards/character_backup_restoration.gd
 M scripts/rewards/character_backup_task.gd
 M scripts/rewards/character_level_progression.gd
 M scripts/rewards/character_persistence_coordinator.gd
 M scripts/rewards/character_profile_projection.gd
 M scripts/rewards/character_wave_checkpoint.gd
 M scripts/rewards/playable_character_admission.gd
 M scripts/rewards/playable_character_persistence.gd
 M scripts/rewards/prime_v3_advancement_catalog.gd
 M scripts/ui/arena_combat_controller.gd
 M scripts/ui/character_backup_actions.gd
 M scripts/ui/character_backup_files.gd
 M scripts/ui/character_sheet_help.gd
 M scripts/ui/character_sheet_projection.gd
 M scripts/ui/character_sheet_window.gd
 M tests/test_character_sheet.gd
 M tests/test_historical_vaelis_admission.gd
 M tests/test_runner.gd
 M tests/test_task_37a_foundation.gd
?? "assets/Rare Human Warrior (Boss).doc"
?? "character saves/"
?? docs/architecture/TASK_45D_CHARACTER_CORRECTIONS.md
?? docs/architecture/TASK_45J_COMPACT_CHARACTER_SAVE_DESIGN.md
?? docs/architecture/TASK_45K_COMPACT_V6_PROTOTYPE.md
?? docs/architecture/TASK_45L_LEGACY_TO_V6_CONVERSION.md
?? docs/architecture/TASK_45M_COMPACT_V6_STORAGE.md
?? docs/architecture/TASK_45N_COMPACT_V6_BACKUP_RESTORE.md
?? docs/architecture/TASK_45O_V6_PRODUCTION_INTEGRATION_PLAN.md
?? docs/architecture/TASK_45P_V6_PERFORMANCE.md
?? docs/audits/TASK_45E_SAVE_LOAD_PERFORMANCE.md
?? docs/audits/TASK_45G_WEB_MEMORY_DIAGNOSIS.md
?? scripts/combat/arena_mana_recovery.gd
?? scripts/combat/arena_mana_recovery.gd.uid
?? scripts/rewards/compact_character_v6_prototype.gd
?? scripts/rewards/compact_character_v6_prototype.gd.uid
?? scripts/rewards/compact_v6_equivalence.gd
?? scripts/rewards/compact_v6_equivalence.gd.uid
?? scripts/rewards/endurance_growth_history.gd
?? scripts/rewards/endurance_growth_history.gd.uid
?? scripts/rewards/legacy_to_compact_v6_prototype.gd
?? scripts/rewards/legacy_to_compact_v6_prototype.gd.uid
?? tests/__pycache__/
?? tests/benchmark_task_45e.gd
?? tests/benchmark_task_45e.gd.uid
?? tests/browser/compact_v6_backup_edge_cases.js
?? tests/browser/compact_v6_backup_store.js
?? tests/browser/compact_v6_performance_edge_cases.js
?? tests/browser/compact_v6_store.js
?? tests/browser/compact_v6_wasm_harness.gd
?? tests/browser/compact_v6_wasm_harness.gd.uid
?? tests/browser/test_compact_v6_storage_edge.js
?? tests/browser/test_task_45e_edge.js
?? tests/compact_v6_backup_store.gd
?? tests/compact_v6_backup_store.gd.uid
?? tests/compact_v6_disposable_store.gd
?? tests/compact_v6_disposable_store.gd.uid
?? tests/compact_v6_perf_trace.gd
?? tests/compact_v6_perf_trace.gd.uid
?? tests/compact_v6_performance.gd
?? tests/compact_v6_performance.gd.uid
?? tests/compact_v6_performance_process.gd
?? tests/compact_v6_performance_process.gd.uid
?? tests/compact_v6_portable_backup.gd
?? tests/compact_v6_portable_backup.gd.uid
?? tests/compact_v6_storage_fixtures.gd
?? tests/compact_v6_storage_fixtures.gd.uid
?? tests/compact_v6_storage_process.gd
?? tests/compact_v6_storage_process.gd.uid
?? tests/oracles/
?? tests/profile_compact_v6.py
?? tests/test_compact_character_v6.gd
?? tests/test_compact_character_v6.gd.uid
?? tests/test_compact_v6_backup.gd
?? tests/test_compact_v6_backup.gd.uid
?? tests/test_compact_v6_performance.gd
?? tests/test_compact_v6_performance.gd.uid
?? tests/test_compact_v6_storage.gd
?? tests/test_compact_v6_storage.gd.uid
?? tests/test_end_hpm_replay.gd
?? tests/test_end_hpm_replay.gd.uid
?? tests/test_legacy_to_compact_v6.gd
?? tests/test_legacy_to_compact_v6.gd.uid
?? tests/test_permanent_end_advancement.gd
?? tests/test_permanent_end_advancement.gd.uid
?? tests/test_task_45d_dex_correction.gd
?? tests/test_task_45d_dex_correction.gd.uid
?? tests/test_task_45d_experience.gd
?? tests/test_task_45d_experience.gd.uid
?? tests/test_task_45d_mana_recovery.gd
?? tests/test_task_45d_mana_recovery.gd.uid
?? tests/test_task_45e_backup_integrity.gd
?? tests/test_task_45e_backup_integrity.gd.uid
?? tests/test_task_45g_release_scanner.py
?? tmp/
```

`git diff --check`, syntax checks and scoped untracked-file whitespace checks are recorded with the test results. S1 ends here; activation/S2 needs separate owner approval.

