# Task 45K - dormant compact V6 proof, Pass A

Implemented against main `f9bb0db0235b0003895c477a12346191d4714469` with existing uncommitted 45B-45J preserved. No playable caller, storage adapter, migration, database upgrade, backup dispatch or Web export is included.

## Prototype contract

`compact_character_v6_prototype.gd` is a pure, explicitly invoked fixture contract. The outer envelope uses `itank_arena_character`, version 6, canonical `payload_json` and its exact UTF-8 SHA-256. Its inner format is deliberately `itank_arena_compact_character_pass_a`, compact version 1. The existing CharacterSaveContract still rejects V6. This experiment does not freeze a production V6 wire format.

The record contains:

- `current`: one complete existing permanent/checkpoint projection, with purchases, growth, award receipts, settlements and credits removed into evidence. Current items, equipment state, resource/checkpoint state, run policies, Mana remainder and movement state retain their existing validated representation when present. Permanent-only fixtures remain permanent-only; absent recovery is not invented.
- `evidence`: lifetime awards, purchases, original growth records, settlements, fixed credit evidence and explicit causal order. No full-generation archive. Original growth fields/rolls remain exact. The actual HISTORY_FIELDS constant has 15 fields, plus growth_id; the design's reference to 16 HISTORY_FIELDS was a counting error, not permission to add a field.
- `operations`: exact lifetime operation IDs and immutable request digests. `applied_ids` additionally binds award, purchase, growth, receipt, item-acquisition, credit, development and run identities to their exact records. All remain after journal eviction. Acquisitions remain tracked after items are consumed.
- `recent_journal`: exactly the latest 20 operations, derived from the lifetime registry, never the duplicate-prevention authority.
- `accounting`: independently recomputed initial balances, earned awards, EXPC-only credits, expenditure, EXPM and spendable EXPC.
- `head`: isolated epoch, bounded safe-integer sequence and previous-record digest. Pure extension validation checks the known predecessor and immutable evidence/operation prefixes; no publication occurs.

The caller supplies the trusted source resource. Its complete canonical fingerprint must match. An imported source assertion or verified flag cannot authorize itself. Decode performs bounded duplicate-key/depth/token scanning, JSON parsing, exact checksum verification, canonical-number verification and fresh semantic validation. The experimental encoded-file cap is 16 MiB, not a change to any production limit.

## Rule validation and chronology

The prototype reuses existing save-contract checks, receipt and continuity validators, source-valued award validation, purchase previews/application, growth_terms, projection hydration, ownership checks and the fixed EXPC credit contract. It introduces no prices, chart formulas, RNG draws or wallet authority.

The explicit order must reference every award/purchase/growth/credit exactly once and preserve each original sequence. Replay enforces affordability at purchase time, source prices/caps, HD sides/flat/original roll, class thresholds, event-time END/HPB, event-time WIS, HPM arithmetic and Mana/AP arithmetic. Missing growth cannot be hidden by later purchases. The END proof handed to existing hydration is constructed from that replay, never accepted as a caller-supplied success flag.

Independent cases cover END6/7's HPB1 plateau, END8's HPB2, purchases before/after growth, level-one WIS purchases and WIS11/12's distinct Mana growth. Compact END witnesses equal the existing consecutive-generation EnduranceGrowthHistory proof over the disposable 232-generation archive. Existing immutable creation HPM/attributes, prior dice and growth gains remain unchanged. Current Mana is not refilled.

Credit support is deliberately narrow: the existing fixed +10,000 EXPC grant, with its exact original predecessor binding, from an otherwise verified creation baseline. EXPM receives zero credit. A later legacy credit with substantial predecessor progression returns unsupported; no extraction or invented historical chronology is supplied in Pass A. Extension cannot add/change credits; future credit publication requires its own approved boundary.

## Simplifications and limits

- Flat arrays and complete standalone O(N) validation; no pages, database stores, incremental indexes, compression or cache trust.
- Existing current checkpoint shape is retained to reuse its validator. Its runtime ledger can still contain a second representation of some lifetime facts. Eliminating that bridge duplication needs a later explicit checkpoint adapter; this prototype does not claim the final minimum hot-state format.
- No previous-state repair store, rollback delta archive, conversion certificate, legacy converter, old-writer fence or filesystem publication. Test-only first-appearance extraction reads only histories generated by the disposable fixture helper, using causal award IDs for growth. It is not a general migration algorithm.
- Safe integer counters suffice for Pass A; no production uint64 sequence encoding is claimed. Unknown source resources, unsupported purchases and unprovable credit/chronology cases fail closed.
- Hashes establish local integrity and internal rule consistency, not authentic earning, network ownership or protection after replacing all local storage. Known-head continuity rejects stale/replayed candidates; standalone import cannot prove it is the newest copy in existence.
- No automatic save/load/export/restore latency or power-loss durability is measured. Storage, native release, actual Edge/WASM and cross-runtime canonicalization remain separate gates. No multiplayer/PvP authority is built.

## Focused verification

Godot 4.7.2 native headless, using:

```powershell
& 'C:/Users/mxz/Desktop/GoDot/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script tests/test_runner.gd -- '--suite=45K'
```

Same command with the other filters below:

| Filter | Assertions | Result |
|---|---:|---|
| 45K | 814 | PASS |
| 45B HPB | 141 | PASS |
| 44B historical | 73 | PASS |
| 45E backup integrity | 84 | PASS |
| 45D Mana | 104 | PASS |
| 45D DEX | 21 | PASS |
| 45D Experience | 37 | PASS |
| Total | 1,274 | 7/7 PASS |

No failed assertions, script errors, resource-leak reports or warnings in these completed runs. Early prototype fixture expectations were corrected for the actual Level 4 threshold at 500 EXPM; production rules and existing assertions were not weakened. Malformed-field and rehashed semantic-tamper tests also fail closed. All own filesystem fixtures are generated below a unique OS-cache `itank-storage-tests/compact45k_*` directory and removed afterward; owner data and repository tmp/ are never used.

## Measurements

One native debug run, five repetitions per compact operation, same immutable disposable workload: 232 cumulative complete generations, 200 distinct source-valued goblin awards, 3 END/WIS purchases, 7 original growth records, fixed EXPC credit, 656 lifetime IDs. No whitespace padding. This is not an owner character copy.

| Measurement | Result |
|---|---:|
| Sum of encoded legacy generation documents | 14,253,122 bytes |
| V6 encoded file | 276,022 bytes |
| V6 canonical inner payload | 254,900 bytes |
| Legacy encode all generations | 445.707 ms |
| Existing generation-backed END proof | 612.082 ms |
| V6 validate, min / median / max | 85.958 / 86.187 / 89.654 ms |
| V6 encode including validation, min / median / max | 92.735 / 93.048 / 93.663 ms |
| V6 decode including scanning and validation, min / median / max | 153.509 / 153.939 / 154.955 ms |

The size reduction is about 98.06%. Legacy document encoding/END proof and compact validation are different stages; these are not an end-to-end browser speedup comparison.

Native Godot static allocations with the disposable legacy archive and compact proof both held: 223,772,693 bytes. After releasing only that in-memory benchmark archive, while preserving compact lifetime evidence: 162,275,637 bytes (61,497,056 bytes released). After five full compact validation/encode/decode cycles and releasing their outputs: 162,277,585 bytes. The 1,948-byte difference includes measurement arrays/loop overhead; five iterations do not establish a general leak guarantee. Process-wide allocator peak: 275,605,429 bytes, including fixtures and every preloaded test suite. These are neither isolated compact-process RSS measurements nor Edge JS/WASM measurements; no browser-memory acceptance claim follows.

## Safety and next gate

Only the dormant prototype, its UID, focused test/UID, one test-runner registration and this note are introduced. All previous source hashes remain unchanged except that intended runner addition; removing the addition reconstructs the exact previous runner bytes. project.godot remains unchanged. No real profile, IndexedDB, save, backup or protected document is accessed. No Git mutation, full regression or Web export occurs.

Pass A stops here. Migration, compact checkpoint/storage integration, credit extraction/publication, recovery and any Pass B work require separate owner approval.
