# Task 45L - isolated legacy-to-V6 conversion, Pass B

2026-11-17. **Complete, dormant prototype only.** Main remains at `f9bb0db0235b0003895c477a12346191d4714469`; existing 45B-45K work is preserved. No owner character, IndexedDB, production writer, save dispatch or database version is changed.

## Files

Added:

- `scripts/rewards/legacy_to_compact_v6_prototype.gd` and `.gd.uid`
- `scripts/rewards/compact_v6_equivalence.gd` and `.gd.uid`
- `tests/test_legacy_to_compact_v6.gd` and `.gd.uid`
- This report.

Modified only `scripts/rewards/compact_character_v6_prototype.gd` and `tests/test_runner.gd` from the previous work. The runner adds one preload and registration; previous registrations remain intact.

## Approach and supported input

The converter accepts an in-memory array of exact `{generation, transaction_id, document}` records, never a storage path. It supports the existing mapped Vaelis source baselines in NORMAL and legacy DEV namespaces, with V2/V4/V5 documents and valid mixed-version chains. It requires generation 1, source identity/lineage, complete playable checkpoints and all original evidence.

One ordered legacy validation walk decodes every generation, checking JSON complexity/duplicate keys, envelope checksums, generation numbers, unique transaction IDs, source identity, receipts, prices, progression, equipment/ownership, checkpoint geometry, immutable prefixes and generation-backed END history. It reuses CharacterSaveContract, CharacterProfileProjection, CharacterPersistenceCoordinator's pure validators, EnduranceGrowthHistory and the existing credit contract. Source resources are held warm for this operation, following the existing backup validator; validation results are not cached or trusted from files. Existing validators can internally recheck fields; this is not a claim that every primitive check executes exactly once.

The walk keeps one prior decoded head/actor and the compact evidence/order. Only newly introduced awards, purchases, growth and credits add chronology entries. Original award IDs associate growth with its causal award. Coalesced purchase/award boundaries and missing causal IDs return specific unsupported results instead of inventing order. Existing END rules still reject ambiguous END-purchase/growth generations.

Output uses the experimental 45K envelope/inner format, not an activated production V6 format. It retains one current projection plus lifetime evidence. Every original transport ID binds the SHA-256 of its actual original document with `binding_kind: legacy_document`, rather than an invented UI request. A conversion starts compact sequence 1, with a deterministic epoch and `legacy_operation_count`; it does not fabricate previous compact snapshots. The old generation number remains original provenance in the current projection.

Cancellation is terminal and releases staged output. Abandoning an in-memory job can be followed by a deterministic fresh conversion. Initial/per-row/final byte-and-metadata bindings detect a changed source, including an already validated row. Those extra hash checks are separate from the single semantic validation walk. This is not a writer lease or an atomic publication protocol.

Bounds are explicit: existing per-document 16 MiB and scanner depth/token limits; at most 4,096 generations; a separate 256 MiB prototype raw-archive budget; the unchanged 45K 16 MiB encoded-output cap. The production manual-backup aggregate limit remains 32 MiB. The 400-generation input exceeds that manual transport budget and converts through this distinct dormant API with all semantic checks intact. No production limit is raised or bypassed.

## Independent equivalence

`compact_v6_equivalence.gd` receives the original head, independently hydrated legacy actor, generation-derived END proof and original document records from the validation walk. It does not use the converter's packer to construct expectations.

It freshly validates V6, reconstructs and compares the **entire original head**, compares the complete permanent/equipment-adjusted actor, checks event-time END witnesses against the generation-derived proof, and independently enumerates required lifetime identity/provenance bindings from the original data. This includes:

- Original/permanent attributes, derived and equipment-adjusted statistics, level and XP.
- Purchases, credits, original HD rolls/bonuses, HPM, current HPC, resource maxima/current Mana/AP where present.
- Items, quantities, consumed origins, equipped slots, hands and condition.
- Run policies, wave/checkpoint, RNG, movement, fatigue, relevant timers and fractional Mana remainder.

All compared values must match exactly. Tests demonstrate that a different but individually valid HPC snapshot is rejected by comparison, not merely by schema validation. A changed equipment-adjusted actor is also rejected. The same immutable input yields identical record and encoded bytes on repeat conversion. Shared rule validators remain shared; independence concerns extraction/expectations, not a second implementation of game rules.

## Historical credits and ledger duplication

For a legitimate post-creation fixed EXPC grant, the converter captures the **actual fully validated predecessor**. It stores a stripped predecessor snapshot and exact evidence-prefix counts. Decode reconstructs that predecessor from lifetime evidence, independently replays its rules/chronology, and checks the existing grant's exact `after_generation` and `head_digest`. No predecessor digest, roll, purchase or award is invented. The existing fixed +10,000 EXPC amount/profile restrictions remain; EXPM is unchanged.

Tests cover V2-to-V5, V4-to-V5 and a first grant after already purchased END/WIS and recorded growth. Missing/wrong predecessors, changed prefix counts, altered balances, malformed references and duplicate grants reject. Credit publication combined with unrelated mutations is explicitly unsupported.

Only exact equal prefixes in the predecessor's `ledger.awards`, `purchase_records` and `drop_resolutions` use references into the current ledger. Reconstruction must reproduce the original predecessor digest. Savings were 5,986 bytes in the unchanged late-credit fixture and 7,925 bytes after the pre-credit END/WIS purchases. Reload-derived metadata differs in the dense fixture, so those arrays are retained and report zero savings. Current production checkpoints are not redesigned; richer runtime ledger data that cannot safely be reconstructed remains intact.

## Focused tests

Godot 4.7.2 native headless command, repeated with each filter:

```powershell
& 'C:/Users/mxz/Desktop/GoDot/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script tests/test_runner.gd -- '--suite=45L'
```

| Filter | Assertions reported | Result |
|---|---:|---|
| 45L | 912 | PASS |
| 45K | 814 | PASS |
| 45B HPB | 141 | PASS |
| 44B historical | 73 | PASS |
| Task 43E EXPC credit | 69 | PASS |
| Task 36L-Pass2 | Not reported by existing suite | PASS |
| 45E backup integrity | 84 | PASS |

**7/7 suites PASS, zero failures/script errors/warnings/leak reports in final runs.** Six suites report 2,093 assertions; the existing restoration suite does not print its count. Parsing is exercised by these headless runs; no full regression, import/export checkpoint or browser test was run.

Fixtures include small V2/V4/V5 chains in both namespaces, interleaved real END/WIS purchases and level gains, actual loot creation/collection, complete potion consumption, equipment changes, a buckler instance/condition, and distinct development transactions. Source arithmetic/RNG and effects use existing fixture infrastructure. Large histories add genuine source-valid preference commands, not whitespace padding or invented XP. They are representative proof workloads, not copies of an owner's history.

Rejection coverage includes missing generations, repeated transport/award/purchase IDs, conflicting receipts, truncation, checksum failures, unsupported versions, namespace crossover, missing credit predecessors and ambiguous coalesced evidence. Cancellation is exercised during validation, packing, comparison and final source checking. Interrupted restart, changed source bytes/length/metadata, immutable repeat conversion, and standalone late-credit decode are covered. All own filesystem fixtures reside under a unique OS-cache `itank-storage-tests/compact45l_*` directory and are removed after testing.

## Measurements

Single final native debug run; milliseconds are stage timings, not Windows exported-release or Edge/Web measurements. Construction includes compact encoding/validation. Independent verification includes original-operation hash comparison. Additional source bindings/overhead explain the difference from total time.

| Generations | Raw legacy bytes | Compact bytes | Legacy validation ms | Construct ms | Independent verify ms | Total ms |
|---:|---:|---:|---:|---:|---:|---:|
| 168 | 11,266,982 | 200,083 | 6,615.132 | 42.770 | 79.977 | 6,901.159 |
| 221 | 16,331,609 | 236,388 | 10,258.099 | 50.510 | 106.172 | 10,638.633 |
| 233 | 17,571,917 | 244,608 | 11,121.445 | 52.914 | 114.272 | 11,531.339 |
| 400 | 38,420,030 | 359,003 | 28,311.285 | 81.484 | 214.156 | 29,091.636 |

The 400-generation fixture has 11 awards, 3 END/WIS purchases, 7 original growth records, 378 development commands and 845 lifetime identity bindings. It is 99.07% smaller by these serialized byte totals. It emphasizes command/evidence growth; it does not represent every high-award/high-inventory workload. 45K's separate 200-award fixture still passes.

Largest recorded native static allocator peak: **499,937,636 bytes** (about 476.8 MiB). Static allocation at 400-generation completion: 391,735,953 bytes. These include the caller-retained original archive, generated fixtures and preloaded test suites, not just compact state. They are not process RSS, JS heap, WASM capacity or measured browser retention. The one-time legacy walk remains the dominant cost and exceeds routine save/load targets. No live-save latency improvement is claimed.

## Limitations and safety

Unsupported source baselines, missing creation/checkpoint/evidence, unverifiable causal IDs and ambiguous coalesced operations remain blocked. Caller-provided in-memory records must come from an acknowledged source; storage locks, pending publications and safe activation are future integration gates. Hashes establish unsigned-local consistency, not authentic earning or anti-rollback after replacing all storage. Converted files still require the mapped trusted source assets/rules.

No streaming filesystem/IndexedDB reader, production migration, storage integration, DB upgrade, old-writer fence, rollback activation, multiplayer/PvP authority or live gameplay change is implemented. The converter has no filesystem/browser access. Tests reuse the unmodified coordinator only in disposable storage. Original generations and owner data remain untouched.

All pre-existing audited files remain byte-identical except the intended dormant prototype and runner changes; project.godot's existing modification is unchanged. No staging, commit, push, reset, rebase, cleanup, Web export or owner-browser operation occurs. **Stop after Pass B. Pass C requires separate approval.**
