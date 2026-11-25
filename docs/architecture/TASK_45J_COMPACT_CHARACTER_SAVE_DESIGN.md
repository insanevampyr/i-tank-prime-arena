# Task 45J — Compact character saves: architecture and migration design

**PROPOSAL ONLY. No implementation, activation, save migration or owner-data access.**

Prepared 2026-11-16 against `main` at `f9bb0db0235b0003895c477a12346191d4714469`, including preserved uncommitted 45B–45I. Current Web build: `f9bb0db+wip.5cfb3f6cf0cb`. All new versions, storage additions and budgets below require owner approval.

## 1. Recommendation and constraints

Keep one authoritative current snapshot, a previous committed snapshot for repair, current/previous wave-recovery checkpoints, and a bounded recent transaction journal. Replace repeated full-character generations with **one copy of necessary lifetime semantic evidence and an exact applied-ID index**, maintained through the existing coordinator. No second wallet or competing persistence authority.

A 20-entry journal is not a lifetime ledger. Unlimited arbitrary IDs cannot be remembered exactly in fixed bounded space. A digest alone cannot answer membership questions or reconstruct missing proof. This design has bounded hot state and **O(N) compact lifetime evidence**, N being unique semantic transactions, rather than O(G × cumulative state) full snapshots. Backups include the compact evidence once. No legitimate IDs, receipts or progression are silently discarded.

Targets apply to a declared supported workload/hardware configuration, not every possible infinite lifetime. Universal fixed file size, exact unlimited deduplication and constant-time standalone validation cannot all be promised without additional trusted authority or stronger issuer-sequence assumptions.

Simulation schema 12 and gameplay remain unchanged. Dormant DEAD/life-state mechanisms, temporary effects, networking and PvP are not activated. Cooperative PvE is the locked next multiplayer direction; PvP is deferred.

## 2. Current dependency inventory

Paths are repository-relative. Distinguish needing **all full snapshots** from needing **one copy of lifetime semantic facts**.

| Boundary | Historical dependency today | Compact disposition |
|---|---|---|
| `character_save_contract.gd`: validate/encode/decode/validate_replacement | V2 progression/source; V4 run-policy prefix; V5 credit binding; predecessor identity and immutable prefixes | Explicit new-version dispatch; retain legacy validators. Compact predecessor + typed delta + lifetime evidence replace prefix scans only after equivalence proof. |
| `character_save_storage.gd`: read_profile/inspect_profile/_write_locked/_read_restoration | Enumerates generations/bundles, detects gaps/conflicts and historical transaction IDs, stages/publishes exact bytes | Same storage authority and locks; head/previous references and exact ID lookup. Legacy enumeration only for conversion/legacy restore. |
| `character_browser_store.js`: Store.document/inspect/publish/restore/reconcile | Full generation and transaction-document getAll, checksums, current head, conditional write/readback | Versioned compact operations in the same adapter; point reads and bounded pages. Preserve original stores. |
| `character_browser_storage.gd`: poll/inspection | Complete serialized response, every decoded document, adjacent replacement checks | Bounded transport and compact head/index pages. Streamed legacy inspection remains for conversion. |
| `character_persistence_coordinator.gd`: prepare/_authorize/_find_transaction/_validate_receipts/_validate_continuity/_validate_new_items | Historical retry lookup; complete award/purchase/settlement arrays; source/ownership and consumed-item checks | Extend this coordinator, not another one. Exact IDs, semantic evidence and verified predecessor/delta replace scans. Imported verification flags never authorize. |
| `character_browser_persistence.gd`: begin_commit/poll | Full fresh inspection before publication/reconciliation and exact acknowledgements | Same single-flight pump; expected epoch/seq/digest, point membership and exact record/root readback. |
| `playable_character_persistence.gd`: open_verified_history/_ack/_verify/_capture/apply_player/restore_ledger | First-generation baseline, all predecessor checks, END generation proof, latest head, lifetime maps and recovery | Compact hydration adapter + verified extraction baseline. No ordinary legacy generation replay. Preserve runtime objects and resource behavior. |
| `character_profile_projection.gd`: project/hydrate/purchase_fields/validate_playable_xp_award/_ownership | All purchases/allocations, growth, award/settlement provenance, source, run policies, equipment condition | Store facts once. A new compact projection/hydration adapter is required; existing hydrate is not a drop-in compact loader. Reuse pure rule helpers. |
| `endurance_growth_history.gd`: resolve/extend | Consecutive verified generations, unchanged prefixes, END at each growth record and source binding | Extract verified event-time END/HPB witnesses. Final END/HPB or total HP alone cannot prove plateau timing. Existing transient head-bound proof cannot just be copied to a different format. |
| Projection WIS growth loop; `character_level_progression.gd`: growth_terms | Event-time wisdom, Mana maxima, WIS purchase sequence; HD sides/roll/flat/HPB/threshold and HP arithmetic | Preserve original growth and proven purchase-count relations. No rerolls, final-WIS replay or retroactive HPB changes. |
| `prime_v3_advancement_catalog.gd`; actor verified advancement; `character_development.gd`: inspect/validate_source/continuity | Prices, original attributes, ordered purchases, DT/DP commands and preferences | Same live rules/caps/explicit allocations. Keep permanent/development evidence once and current allocation separately. |
| `arena_reward_ledger.gd`: process_defeat/purchase_advancement/to_dictionary | Processed actors/defeats/items/requests, cumulative awards/drops/purchases and policy | Exact semantic-ID index plus existing runtime working sets. Initial bridge must not change live ledger/simulation snapshot fields. |
| `character_expc_credit.gd`: inspect/continuity/prepare; grant UI | Fixed ID, DEV identity/baseline, predecessor generation/head and EXPC-only record | Preserve complete original record and binding forever. No general credit API. New compact-head binding must be explicitly versioned/tested. |
| Coordinator receipt validator; item/equipment ownership projection | Unique receipt/effect/acquisition origins, quantity bounds, consumed-instance protection, shield state and handling | Original receipt content/provenance once; exact exhausted/consumed IDs and current instances. No item/gold merging. |
| `character_wave_checkpoint.gd`; persistence capture/application | Source-qualified player/resources/development, roster/positions/opening/loot, movement/fatigue, RNG, cumulative ledger | Preserve approved checkpoint semantics with versioned compact references. Old validator cannot accept a stripped ledger without an adapter. |
| Controller loaded-run choice/new-run/next-wave pump; `browser_wave_candidate.gd` | Head-bound decision, candidate isolation, post-wave then entry publications, lease transfer | Preserve both boundaries. New run ID/policy/first Wave 1 entry remain atomic; no erasure of committed rewards or purchases. |
| Save contract/projection run-policy checks | Legacy namespace multiplier plus V4 ordered run policies and award proof | Preserve original run IDs/policies once. Active policy immutable; DEV visibility never switches profile or policy. TEST remains nonpersistent/no rewards. |
| Backup contract/task/reader/files/restoration | Entire archive, nested JSON, full source replay; full destination comparison and exact readback | New compact stream, legacy decoder retained. Imported/changed facts always validated. Ancestry proof replaces raw-array equality; seq alone is insufficient. |
| `character_persistence_session.gd` foundation path | Older lineage/history gates | Keep isolated; no second active writer. |
| Character Sheet and management | Progression/current values, purchase history and equipment | Verified current projection; historical details paged from evidence. Display causes no writes. |
| Dormant Profile V3/life-state prototypes | Proposed contracts, not active admission | Do not activate or repurpose reserved V3. Keep multiplayer atomicity limitations explicit. |

### Observed scale and reducibility

45I confirmed that 33,554,432 raw history bytes pass manual export, one byte above fails, yet automatic admission remains valid. Destination preview masks that limit failure as an unverifiable current character. This does not demonstrate corruption or a new scanner limit.

The disposable 221-generation Level 8 fixture had an unpadded semantic head envelope of about 34,060 bytes and payload of 30,846 bytes: 16 settlements, 11 awards, 7 growth records, 5 items, one run. Recovery was about 16.7 KB, settlements 6.9 KB, permanent state 4.2 KB. Its stress backup was 41.3 MB. These are fixture measurements, not the unseen owner's actual semantic size.

After verified extraction, current values, cumulative accounting, immutable creation/source and active policy can be checkpointed. Totals alone cannot replace arbitrary lifetime IDs, consumed-item origins, original dice, purchase allocations, award/run provenance, END plateau chronology, ancestry or post-conversion rollback operations. Keep the necessary facts once.

## 3. Proposed versions and exact logical record schema

Current source uses foundation V1, permanent V2, run-policy V4 and credit V5; V3 is dormant. Searches of current scripts/tests/notes found no live compact V6 reservation. **Propose V6, recheck before implementation.** No reader/writer dispatch changes occur now. Foundation V1 lacking required history stays blocked; do not fabricate conversion evidence.

The following IDL defines a closed schema: required fields as shown, no unlisted keys. Nullable values use JSON null. Counters above JSON safe-integer range use unsigned-decimal strings. Original IDs retain exact bytes/case; no normalization, truncation or reassignment. Existing profile identity checks remain. Bounds that would reject an existing legitimate value block conversion for review, not silent shortening.

```typescript
type Digest = string; // 64 lower-case hex SHA-256 characters
type Seq = string;    // canonical uint64 decimal, no leading zero except "0"
type Id = string;     // original nonempty source-qualified UTF-8 identity
type Namespace = "normal" | "dev_normal";
type JSONValue = null | boolean | number | string | JSONValue[] |
                 { [key: string]: JSONValue };
type V6Envelope = {
  format: "itank_arena_character"; version: 6;
  payload_json: string; // canonical CompactRecord, one current record
  sha256: Digest;      // exact UTF-8 payload_json hash
};
type CompactRecord = {
  format: "itank_arena_compact_character"; compact_version: 1;
  identity: Identity; head: Head; state: CurrentState;
  accounting: Accounting; recovery: Recovery; evidence: EvidenceManifest;
  recent_journal: JournalEntry[]; // ordered, maximum 20 committed entries
  conversion: ConversionBaseline | null; integrity: Integrity;
};
type Identity = {
  profile_id: Id; namespace: Namespace; definition_id: Id;
  rules_revision: string; baseline_digest: Digest;
  original_lineage: JSONValue; // exact validated six-field legacy lineage
  authored_source: JSONValue; // exact verified source.to_dictionary()
};
type Head = {
  storage_epoch: Id; // technical lineage, NOT a new character identity
  seq: Seq; parent_commit_digest: Digest | null;
  operation_id: Id; request_digest: Digest;
  legacy_origin_generation: Seq | null; // actual provenance, not invented history
};
type PrimaryAttributes = {
  str: number; end: number; spd: number; dex: number; wis: number;
  int: number; wit: number; man: number; luk: number; app: number;
};
type CurrentState = {
  original_attributes: PrimaryAttributes; // all ten, immutable
  permanent_attributes: PrimaryAttributes;
  permanent_derived: { [stat: string]: JSONValue }; // before equipment
  level: number; progression_policy: JSONValue;
  resource_maxima: { [resource: string]: number };
  resources_current: { [resource: string]: number };
  ability_allowances: JSONValue; daily_use_state: JSONValue;
  development_current: JSONValue; // verified allocation/preferences
  items: JSONValue[]; // current complete instance records
  equipment_refs: Id[]; equipment_state: JSONValue;
  currency_totals: { [currency: string]: number }; // checked derivation of items
  conditions: JSONValue; // only already supported source-qualified state
};
type Accounting = {
  initial_expm: number; initial_expc: number;
  earned_award_xp: number; credit_expc: number; spent_expc: number;
  expm_total: number; expc_available: number;
};
type Recovery = {
  current: CompactWaveCheckpoint; previous: CompactWaveCheckpoint | null;
};
type CompactWaveCheckpoint = {
  checkpoint_version: 1; checkpoint_id: Id; captured_at_seq: Seq;
  phase: "entry" | "downtime" | "complete"; run_id: Id; wave_id: Id;
  seed: string; clock_us: number; rng: JSONValue;
  battlefield_digest: Digest; player_position: number[];
  opponent_spawn: number[]; player: JSONValue; roster: JSONValue;
  opening: JSONValue; enemy_positions: JSONValue; uncollected_loot: JSONValue;
  request_sequence: number; movement: JSONValue; movement_ledger: JSONValue;
  ledger_current: JSONValue; evidence_at_seq: Seq;
};
type EvidenceManifest = {
  applied_ids: PageDirectory; semantic_facts: PageDirectory;
  run_policies: PageDirectory; transitions: PageDirectory;
  rollback_deltas: PageDirectory;
};
type PageDirectory = {
  root_digest: Digest; count: Seq; page_count: number;
  directory_digest: Digest; // ordered range/count/hash directory, itself paged
};
type AppliedId = {
  scope: "operation" | "award" | "purchase" | "credit" | "growth" |
         "item_origin" | "consumed_item" | "development" | "run";
  id: Id; applied_at_seq: Seq;
  binding_kind: "legacy_document" | "semantic_record" | "compact_request";
  request_digest: Digest; effect_digest: Digest; legacy_generation: Seq | null;
};
type SemanticFact = {
  fact_id: Id;
  kind: "award" | "purchase" | "growth" | "credit" | "item" |
        "development" | "checkpoint";
  incorporated_at_seq: Seq; legacy_generation: Seq | null;
  original_record: JSONValue; // exact kind-specific existing validated field set
  record_digest: Digest; witness: OrderingWitness | null;
};
type OrderingWitness = {
  source_digest: Digest; original_record_digest: Digest;
  legacy_generation: Seq | null; compact_seq: Seq | null;
  end_purchase_count: number | null; wis_purchase_count: number | null;
  permanent_end: number | null; hpb: number | null; wisdom: number | null;
};
type RunPolicyRow = {
  run_id: Id; original_ordinal: Seq; multiplier: 1 | 10;
  origin: "legacy_namespace" | "recorded_run_policy";
  admitted_at_seq: Seq; legacy_generation: Seq | null;
};
type CommittedDelta = {
  seq: Seq; operation_id: Id; request_digest: Digest;
  kind: "checkpoint_batch" | "purchase" | "credit" | "inventory" |
        "development" | "run_admission" | "restore_fastforward";
  prior_commit_digest: Digest | null; prior_state_digest: Digest | null;
  state_after_digest: Digest;
  authorized_input: JSONValue; // typed original command/boundary, not JSON patch authority
  introduced_fact_ids: Id[]; introduced_applied_ids: Id[];
  state_changes: JSONValue; // lossless before/after delta, validated against operation rules
};
type DataPage = {
  format: "itank_compact_page"; version: 1;
  profile_id: Id; namespace: Namespace; storage_epoch: Id;
  kind: "applied_ids" | "semantic_facts" | "run_policies" |
        "transitions" | "rollback_deltas";
  first_key: Id; last_key: Id; row_count: number;
  rows: (AppliedId | SemanticFact | RunPolicyRow | TransitionHeader | CommittedDelta)[];
  digest: Digest;
};
type JournalEntry = {
  seq: Seq; operation_id: Id; request_digest: Digest;
  parent_commit_digest: Digest | null; effect_ids: Id[];
  delta_digest: Digest; state_after_digest: Digest;
};
type TransitionHeader = {
  seq: Seq; prior_transition_digest: Digest | null;
  prior_state_digest: Digest | null; state_after_digest: Digest;
  operation_id: Id; delta_digest: Digest;
  applied_ids_root: Digest; semantic_facts_root: Digest;
};
type ConversionBaseline = {
  conversion_id: Id; converter_version: string; rules_revision: string;
  original_envelope_versions: number[]; legacy_head_generation: Seq;
  legacy_head_transaction_id: Id; legacy_head_document_digest: Digest;
  original_archive_root: Digest; original_record_count: Seq;
  original_projection_digest: Digest; compact_projection_digest: Digest;
  semantic_extraction_root: Digest; original_source_digest: Digest;
  validation_report_digest: Digest;
};
type Integrity = {
  canonicalization: "itank-json-v1"; hash: "sha256";
  section_digests: { [section: string]: Digest }; record_digest: Digest;
  authority: { kind: "local_unsigned" };
};
```

For DataPage, all rows must match its kind (no mixed union); keys are uniquely ordered and match the declared range/count. Page digest excludes only its own digest and includes identity/kind. Directory nodes are separate closed records of child key ranges/counts/digests; empty datasets use a canonical domain-separated empty root rather than an invalid empty DataPage. OrderingWitness non-null fields depend on fact kind: actual proven relations only. Null never permits an inference that the existing validator requires.

`JSONValue` slots are not arbitrary pass-through acceptance. They must use the exact existing source/item/development/equipment/player/RNG/roster/opening/loot/movement field sets and validators, or an explicitly versioned compact projection of them. Missing mandatory source data fails closed. Unknown semantic fields block migration until mapped. Original archive bytes remain preserved. No guessed skills/effects or automatic authored-stat recalculation.

`ledger_current` has mode/player/current-wave counters, the admitted run policy, current-run earned/spent counters, current-wave processed actor/defeat/item/request sets and ownership references. Lifetime arrays live once in evidence pages. Initial integration may materialize the legacy runtime ledger from those facts once, preserving existing `ArenaRewardLedger.to_dictionary()` and schema-12 snapshots. Removing live lifetime arrays is a separate authority/digest change, not a serialization shortcut.

CurrentState means the latest **durably secured** authoritative profile at an already-approved save boundary, not permission to save arbitrary unfinished combat. The Character Sheet still reads live admitted runtime state without writing it.

Current authoritative snapshot, technical previous committed snapshot, and previous wave checkpoint serve different purposes. Storage metadata retains the previous committed record/root outside `Recovery`, with identity/seq/digest binding. The previous wave checkpoint does not authorize refunding committed progression.

At conversion, sequence 0 is the new technical baseline. Legacy IDs incorporated there have `applied_at_seq:"0"` and their actual `legacy_generation` where known; this does not claim they were newly awarded or all occurred together. Thereafter seq increments exactly once per committed batch.

For an old transport transaction, `binding_kind:legacy_document` uses the digest of its actual stored original document, not an invented UI-request digest. A semantic ID binds its preserved canonical record; a new operation binds its canonical compact request. Bindings are domain-separated. A legacy operation cannot be resubmitted as a fresh compact effect. Conversion is blocked until all uncertain legacy operations/acknowledgements are reconciled. Consumed-item tombstones may establish that an acquired instance is absent/depleted; they must not invent a missing use cause or timestamp.

### Canonicalization, roots and pages

- Specify sorted keys, exact UTF-8 and numeric normalization with independent Godot/JS/Desktop fixtures. Duplicate keys, invalid UTF-8/numbers and unsupported versions reject. Never route uint64 through a JS number.
- State digest covers `{state,accounting,recovery}` only. A typed delta has its own digest. Applied-ID rows bind that delta, not their containing root.
- Page hashes commit complete ordered rows. Directory/internal-node hashes include a domain tag, ranges, counts and child hashes. Lookups verify paths and full original IDs, not hash prefixes alone. Index order is bytewise UTF-8 tuple order with explicit scope/domain tags, never locale collation; independent Unicode/escaped-ID tests are required.
- Record digest covers the record with only `integrity.record_digest` omitted. Section digests exclude their integrity object. The envelope hashes the complete payload. No circular self-hash.
- TransitionHeader commits state/delta/index roots, not the containing record's own digest; it can be included in the current transition directory without a cycle. This supports consistency/ancestry, not genuine earning authentication.
- Proposed page target 64 KiB, max 256 KiB UTF-8; oversize semantic records use explicit hash-linked continuation pieces, never truncation. Directory nodes are bounded too. Final calibrated numeric safety limits require approval.
- Index algorithm/page packing and hashing are versioned and deterministic. Retain pages needed by current/previous roots and rollback guarantees; historical root hashes alone do not authorize garbage collection. Intermediate index overhead and retained delta space must be measured. Never collect original archive data automatically.
- Page storage wrappers bind profile ID, namespace and epoch. Matching data from another profile/epoch cannot be reused as authority.

### Semantic evidence rows, preserved once

| Kind | Required content |
|---|---|
| XP award | Original award ID/value, complete settlement and defeat provenance, original run/wave, base XP, verified multiplier/final amount and source references. |
| Purchase | Complete purchase and settlement fields, before/after/cost, allocation when present, development command and source rule. Preserve original order and IDs. |
| Growth | All 16 original HISTORY_FIELDS and growth ID: original HD sides/roll/flat, HPB, threshold and before/after HP/Mana/AP. Add proven WIS/END purchase-count relations. |
| END witness | Original growth-record/source digests, event-time permanent END/HPB, actual legacy boundary or new compact seq, END-purchase count and original ID. |
| WIS witness | Recorded wisdom, Mana maxima and WIS-purchase count established by existing replay; preserve relation to purchases. |
| Credit | Exact grant/profile/amount/after-generation/head-digest record and validated predecessor binding. Later compact-head bindings need explicit support. |
| Item/currency | Full original acquisition/collection provenance, instance/definition/quantity, condition and handling changes, permanent consumed/depleted-origin tombstones. |
| Development | Exact original baseline and command evidence; current allocation/preferences projected separately. |
| Run policy | Original run ID/namespace, legacy-prefix classification or recorded multiplier and admission binding, no reassignment. |
| Recovery/transition | Typed changes at approved persistence boundaries; preserved RNG state and existing recorded outcomes. No invented combat transcript. |

Checkpoint facts must not reintroduce the original cumulative recovery ledger/full character snapshot per transaction. They retain only boundary identity and the necessary verified transition/provenance witness; current/previous approved recovery states are stored in Recovery. A historical field required by a rule must be represented by a fact/witness or remain available through the retained original archive; if equivalence cannot be established, extraction is blocked. The post-conversion rollback log stores changed leaves/appended fact references with before/after bindings, not another full character/ledger on every save. These are typed operation-checked deltas, never permission to apply arbitrary imported patches.

Legacy generation labels record actual placement. Do not invent a total order for unrelated old events. Preserve the partial order proven by validators, such as purchase counts before a growth record. Original creation HPM is the verified source value; absent original creation-die receipts are not invented. Ambiguous coalesced END purchases/growth remain blocked. A digest asserting END/HPB timing is not independently sufficient evidence.

## 4. Lifetime accounting and exactly-once protocol

Let E0/C0 be verified starting EXPM/EXPC, A unique authorized XP awards, X approved EXPC-only credits, P unique authorized purchase costs:

- `expm_total = E0 + A`
- `expc_available = C0 + A + X - P`, nonnegative
- `spent_expc = P`
- Level uses the existing class/EXP-Type threshold lookup on EXPM.

The fixed credit never changes A, EXPM, level or growth. Gold totals derive from preserved item instances, not another wallet. Current/max resources must match the authoritative projection; no refill/clamp during hydration. Conversion stores verified totals and evidence roots; new deltas adjust them once. Cold/imported validation checks summaries against evidence, not trusted-looking totals.

Use an exact paged ordered index keyed `(profile,namespace,epoch,scope,original_id)` inside the same coordinator. Preserve transport operation IDs and semantic effect IDs. A reward rewrapped under a new request ID still collides with its original award/origin key.

1. Click locks the operation, captures expected epoch/seq/digest and immutable request; no parallel mutation for that character.
2. Existing operation ID + same request digest returns `already_applied` with applied seq/effect digest and current head; never reapply or return an old state as current. Changed request under same ID rejects.
3. Verify semantic IDs/origins unused and source rules/affordability/eligibility. Journal miss is not permission. Sequence is order/concurrency evidence, not lifetime deduplication.
4. Prepare snapshot, typed semantic delta, changed index/evidence pages and transition header. Delta kinds cover existing award/purchase/growth/credit, inventory/development, run admission and checkpoint operations only; imported arbitrary JSON patches cannot authorize effects.
5. Publish record/roots/index/journal/previous-reference atomically; acknowledge exact verified readback.
6. Lost acknowledgement reconciles by stable ID, immutable request/effect binding and publication state. Uncertainty blocks another mutation.
7. Evict journal entries beyond 20 only once lifetime IDs, facts and rollback/transition evidence are durable.

No authoritative Bloom filter (false positives lose valid work), bounded FIFO of lifetime IDs, counter-only retrofit for arbitrary legacy IDs, or opaque root without evidence. Future strictly monotone trusted issuer sequences could reduce storage, but present IDs do not prove that invariant. Do not assume it.

## 5. Trust and portability

Digests, roots and local conversion certificates detect corruption/internal inconsistency. They do not authenticate earning against a person able to replace local code/state/digests. A client-bundled secret or locally generated MAC is not independent anti-cheat authority.

Preserve the unsigned-local policy and source/rule/receipt checks explicitly. Host-owned validation results bind exact profile/epoch/head/root. File flags such as verified/confirmed/migrated never authorize anything. Changed/imported data get fresh validation.

Standalone compact import must validate the complete semantic package and reconstruct the authoritative projection without original generations. This is a new equivalence obligation: the conversion digest alone cannot prove event-time END or lifetime awards. If any current check cannot be represented and reverified, portability/conversion is blocked until the witness is included. Do not substitute user-confirmed totals. Original archives remain a recovery source. A portable compact backup cannot call itself self-contained while relying on an unpackaged archive to prove a necessary rule. Such a profile remains blocked from that portable path until the witness is included or a separately approved migration-assisted recovery policy applies.

An existing verified local watermark rejects older/conflicting imports. After complete storage replacement/erasure, an independently valid old backup cannot reliably be distinguished from the latest without an external trusted watermark. Offline anti-rollback protects observed continuity and mistakes, not adversarial rollback of all storage/disk images. Disclose that limit rather than adding another self-signed local checksum.

## 6. Storage publication and older-writer exclusion

### Browser: proposed additive database version 2

Reuse `itank-prime-arena.character-profiles`, Web Locks, coordinator states and exact readback. Keep legacy heads/generations/transactions unchanged. Proposed additions:

| Store/key | Content |
|---|---|
| profile_routes / profile | Legacy or compact route, activation/conversion ID, epoch and current/previous record references. |
| compact_records / [profile,epoch,seq] | Referenced current/previous technical snapshots, not another full-generation archive. |
| compact_pages / [profile,epoch,kind,digest] | Immutable ID/evidence/directory/transition/rollback pages. |
| compact_operations / [profile,epoch,operation_id] | Exact operation binding; no duplicate balance or separate wallet. |
| compact_migrations / [profile,conversion_id] | Staged report/archive references/activation intent. |

Semantic membership uses verified page paths; any accelerated secondary index cannot override committed roots. Publish pages, operation entries and head/route in one IDB transaction after asynchronous validation. Do not await long crypto/replay inside an auto-closing transaction. Request strict durability where supported; preserve existing limitations and do not equate oncomplete with proven power-loss safety.

Database version 2 is an approval gate. Existing clients explicitly open DB version 1 and must fail closed with VersionError after upgrade. New clients support unconverted V2/V4/V5 profiles and converted profiles concurrently. Upgrade affects both namespaces in that origin; minimum build, blocked/versionchange handling and tab ownership need explicit tests/owner acknowledgement. Never merge NORMAL and DEV.

### Desktop

Extend CharacterSaveStorage under the same profile root with immutable compact pages, staged record and a versioned head/activation manifest. Reuse writer ownership, pending files, flush, readback and rename; publish the head only after referenced data are staged/verified. Keep prior manifest and uncertain evidence. Multiple unrelated renames are not automatically an atomic multi-file transaction; inject interruption at each boundary.

**Old-writer fence is required.** An old executable that sees intact legacy generations but ignores a compact route could fork progression. At approved activation, append a clearly versioned unsupported-format technical fence recognized by old readers' fail-closed behavior, without changing any original generation bytes. New readers recognize the route/fence; it is not a fabricated gameplay generation. Prototype exact crash/cancel/rollback sequencing before approval. If an old writer can publish alongside compact authority, activation is blocked.

## 7. Reversible conversion, including progress earned afterward

### Preparation and activation

1. Owner selects one explicit profile/namespace and approves dry conversion. No automatic conversion on launch/load/DEV toggle.
2. Acquire existing writer lease and pause mutations. Reject or reconcile all pending/uncertain publications before conversion; do not assume a missing acknowledgement means uncommitted. Capture exact source generation/transaction/head/source/rules/build bindings. Keep original bytes untouched and build the ordered archive digest manifest.
3. Walk original generations with bounded cursor/file reads. Validate checksums, identities, continuity, receipts/items/policies, source growth and generation-backed END proof once. Reuse existing rule functions. A new approved streamed source validator must distinguish the manual 32 MiB transport budget from actual history validity; never ignore a size failure and trust the rest blindly.
4. Extract only newly introduced semantic facts and proven relations. Preserve all original rolls, prices, attributes/allocations, HPB, equipment/condition, gold, resources, Mana remainder, Running fatigue/timers, checkpoint/RNG, run IDs/policies and credit bindings. No rerolls, refunds, gifts or guessed missing data.
5. Build compact output separately. An independent verifier consumes the extracted facts and compares its canonical projection with the verified original: source/original/permanent/effective recipe, all HP/Mana, growth/dice, totals, IDs, ownership, equipment, checkpoint/RNG, movement and policy. Independent expected fixtures must not come from the converter itself. Apply equipment modifiers once.
6. Recheck locked source head/root unchanged; verify output from storage readback. Missing, ambiguous, changed or unsupported evidence blocks conversion. Unknown semantic fields cannot be silently dropped.
7. Present exact source/destination bindings, field equality and recovery report. Separate explicit owner confirmation activates; a staged artifact does not switch authority.
8. Publish the verified route/fences/references through the tested atomic/recovery protocol. Conversion activation itself has a stable operation ID bound to the source archive/head/converter version. Repeated confirmation of the same activation is a no-op; a different epoch/conversion cannot replace an already-converted newer route. Do not replay receipts as new awards. Preserve all original generations and backups unchanged.

One-time full legacy conversion may exceed ten seconds, with bounded work/progress/cancel; it is not a routine save/load benchmark. Cancellation before activation leaves legacy authority. Quota/space must be checked without clearing source data. Maintain a separately recoverable compact artifact and an accessible original archive reference. An archive root without the archive bytes is not a recovery backup.

### Required equality and behavior checks

- STR/DEX/SPD/WIS/END purchase IDs, source costs and allowed caps unchanged; no new attribute mechanics.
- Preserve original source DEX/DT/DP bytes and the separately approved legacy runtime DT/DP correction. Replay permanent allocation commands exactly once; no automatic redistribution.
- SPD MR/AT and equipment adjustments remain separate; hydration/action-scheduling bridges cannot grant stored/instant Acts or reset fatigue/cooldowns.
- END updates NAL/PS/HPB and Running duration while existing immediate HPM/HPC remain unchanged; future growth uses verified event-time HPB.
- WIS purchases contribute +1 Mana Max each, preserve current Mana, SS and old level-up gains; no final-WIS recalculation of earlier levels.
- Preserve the #45D fractional MR/Min remainder, active-wave-only timing and pause behavior; no wall-clock recovery.
- Preserve fixed one-time EXPC credit identity and exact record; EXPM/levels never change from the credit.
- Preserve XP ×1/×10 run bindings, immutable legacy prefix, RESUME/NEW RUN/RETURN/RETRY behavior and separate prod/dev identities; TEST gets no rewards.
- Existing equipment condition, acquired/consumed instances, gold and resource entitlements match exactly. No unknown effects or missing historical evidence are invented.

### Software rollback versus old-format downgrade

A rollback of software must use a known-good **compact-capable recovery build** reading the latest compact state. It cannot reopen the conversion baseline as current and discard subsequent spending/rewards. Technical previous snapshot plus verified committed tail must reconstruct the latest durable head.

Rollback to an unmodified V2/V4/V5 writer additionally needs the original archive and a durable lossless post-conversion semantic delta log outside the 20-entry hot journal. A reverse converter must reconstruct an append-only legacy-compatible chain while preserving semantic IDs, amounts, allocations, original growth/RNG and identity. It must pass existing legacy validators and match the latest compact projection before authority changes. Keep compact state/log recoverable throughout; never operate two active branches.

This is an activation gate if old-format reversibility is promised. Post-conversion credit head bindings, END/growth placement and run-policy generation constraints might not be representable by an unchanged legacy contract. Do not invent past generations, rewrite receipt digests or pretend compact sequence numbers were historical generations. If reverse equivalence is unproven, block activation/the unsupported operation pending a clear policy, or require owner-approved compact-capable recovery. **Universal downgrade compatibility is not promised.**

Browser database version 2 cannot be downgraded in place to version 1. Even after data is re-encoded as V2/V4/V5, an old browser build opening DB version 1 remains blocked. A compatible recovery client can read legacy-formatted data in DB v2; an unmodified old browser writer would require a separately approved fresh-storage export/import procedure, not deletion/recreation of the current database. If in-place use of the unmodified old browser build is mandatory, the proposed DB upgrade must be rejected/redesigned before activation. Desktop fence removal/replacement likewise needs explicit tested reversion sequencing and must not alter original archived bytes.

The rollback tail grows with post-conversion transactions. It must remain until the owner explicitly retires old-format reversibility and an alternative recovery guarantee is verified. This retains deltas, not full repeated snapshots, and does not require routine replay.

## 8. Backup, import and recovery protocol

### Streamable compact backup

Propose discriminator `itank_arena_compact_backup`, container version 1; extension chosen during implementation review. Avoid another giant JSON-in-JSON archive. Normative logical sequence:

1. Closed header: format/version, profile/namespace/epoch/seq/record digest and section counts.
2. Current V6 record, technical previous committed reference/record, current/previous wave checkpoints (shared evidence deduplicated).
3. Every referenced exact-ID, semantic-fact, run-policy and transition page once, with ordered ranges/counts/digests.
4. Required rollback deltas and conversion provenance. Original full archive remains separately preserved, not copied into every routine export.
5. Footer committing the exact ordered section bytes/counts/roots. Missing/truncated footer never yields a confirmed backup.

Specify length framing/canonical boundaries in the isolated contract pass. Decode UTF-8 across chunks and parse bounded pages with duplicate-key/depth/token checks. Compression, if later chosen, needs a versioned algorithm and decoded-size/ratio protections; it is not a validation bypass. Portable backup includes required evidence, not just roots pointing to files on another computer. Unsupported versions/sections fail closed.

### Operations

- **SAVE CHARACTER:** capture an acknowledged head under existing guards; stream one record and evidence pages, checking hashes as read. Recheck binding at finish. No legacy generation archive or repeat semantic replay for unchanged admitted state. Yield independent of RAF; keep existing combat-pause requirements.
- **SAVE FILE:** download the already-prepared artifact, no hidden second validation. Release transfer buffers/URLs safely; distinguish transfer status from source verification.
- **Preview:** bounded read-only parsing and full incoming semantic/integrity checks, then destination ancestry comparison. Early metadata display is explicitly unverified until completion. No writes or actor changes.
- **Restore:** separate exact-file/target confirmation, writer ownership, fresh expected-head check, page staging, atomic publication and readback. No merging another profile's proofs or receipts.
- **Same epoch/seq/root:** no-op. **Same seq/different root:** conflict. **Older:** reject while newer current progress is known. **Newer descendant:** require transition/index/evidence consistency from a verified common baseline; larger XP/seq is not enough. **Unrelated branch/epoch:** explicit conflict, no automatic merge.
- **Empty destination:** full compact semantic verification remains mandatory. Explain the offline limitation on identifying old independently valid backups. No legacy DEV starter creation through restore.
- **Interrupted operation:** stable-ID reconciliation against exact durable head/roots before retry. Unknown publication status blocks another mutation; queued work is not acknowledgement.
- **Damaged current record:** technical previous record is a repair base, not a refund. Replay committed evidence to the known durable head. If latest acknowledged state cannot be established, fail closed and offer recovery diagnostics, never silently resume old balances.

Game RETRY, RETURN, RESUME and NEW RUN keep their current approved behavior. Technical previous state or a previous wave checkpoint is not authority to erase committed purchases/credit/rewards. Preserve #45D fractional Mana remainder and #45B Running/fatigue state, not just visible totals. No wall-clock grants or arbitrary mid-combat resume is introduced.

## 9. Co-op-first compatibility

PvE co-op first; PvP, rankings and matchmaking are deferred. Nothing networked is implemented here.

Separate character ownership, session authority, outcome proof and local publication. Current local profile ID/namespace is not an authenticated global player account. A future owner/account binding is needed before an authority can authorize that character's progression.

Future outcomes bind issuer/session/run/wave/outcome/beneficiary, admitted character head, locked XP policy and verified amounts/items/provenance. Deduplicate both delivery operation ID and semantic award key. A character coordinator accepts only outcomes authorized for its owner; a peer cannot submit another player's purchase. Existing approved dead-player/reward/resurrection rules remain separate integration work, not mechanics added by this storage design.

Independent devices require durable per-recipient acknowledgements and idempotent redelivery from a durable outcome authority. Local Web Locks do not create a distributed transaction. Do not promise atomic publication across profiles/devices or roll back one player's acknowledged rewards because another disconnects.

A peer-host signature proves neither honesty nor correct combat. Stronger eligibility/anti-cheat needs an independently trusted issuer/service or an explicitly weaker trusted-host policy. Offline unsigned characters must not silently become trusted online progression. Accounts, keys, signature schemes and networking are future versioned decisions, not accepted V6 authority fields now.

## 10. Performance/memory budgets and benchmark gates

Let S be current state, N lifetime semantic IDs/facts, D new delta, P bounded page size and G legacy generations.

| Operation | Proposed work | Expensive pattern removed |
|---|---|---|
| Warm automatic save | O(S + D + log N page/index updates) | repeated full generation/receipt inspection |
| Cold load | O(S + compact evidence validation), worst case O(N) facts once | replaying cumulative state across G snapshots |
| Unchanged Character Sheet | verified projection; paged details | no save revalidation |
| Export | O(S + compact portable evidence bytes), streamed | all legacy generations and giant nested strings |
| Fresh import | O(S + N semantic evidence), bounded working buffers | repeated full-generation replay and whole-file representations |
| Restoration | verified package + ancestry/head check + atomic publication | revalidating identical complete histories repeatedly |

Goals on a declared reference machine: automatic save/load ideally 1–3 seconds; backup export/preview under 5 seconds; restoration under 10 seconds; all routine reference cases under 10 seconds. These are ship gates, not measurements of this unimplemented proposal.

### Estimates, not guarantees

- Initial snapshot engineering budget: 64–256 KiB typical, with complex inventory potentially larger. Current/previous records share evidence instead of duplicating it. Decoded UTF-32/WASM strings can require several times UTF-8 page bytes.
- An exact ID entry plus index overhead might average 100–300 bytes; 10,000 IDs about 1–3 MB. Full semantic provenance may exceed that. Budget the entire portable evidence, not only the visible snapshot.
- A Level 10-style package could plausibly be hundreds of KiB to a few MiB rather than ~40 MB of generations, but actual owner semantic evidence was not measured. No compression ratio or target latency is promised.
- Aim for a small fixed number of page representations (roughly 2–4 transient buffers) plus current projection; no all-history JS getAll or complete archive UTF-32 string. Prototype incremental allocation goals: <64 MiB routine and <128 MiB import/export above settled baseline. They are not total-browser-memory claims.
- At 100,000+ records, complete standalone proof validation/export may exceed targets. Infinite lifetime evidence is not constant-time. Signed external checkpoints or strict trusted issuer watermarks would require a new trust contract, not silent evidence pruning.

45H measured the 41.3 MB disposable SAVE ready by about 12.04 seconds, peak renderer RSS 1.41 GB/private 1.98 GB, and WASM capacity about 1.09 GB afterward. 45I measured a 32 MiB+1 export rejection, preview peak about 1.54 GB RSS, checkpoint activity around 1.94 GB RSS, and about 1.24 GB WASM capacity after cancel/background. These are instrumented headless software-WebGL results, not owner-hardware acceptance. GC reduced JS but did not shrink observed WASM capacity. Removing peak allocations matters; do not promise RSS immediately returns after freeing references.

### Required benchmark matrix

Use immutable disposable fixtures and exact RELEASE artifact/BUILD hashes:

- V2/V4/V5, NORMAL/Legacy DEV, small/168/221/232+ generations, old 32 MiB boundary and beyond. Include real semantic complexity, not only whitespace padding.
- Low/Level 10+ progression; interleaved WIS/END and HPB plateaus; creation HPM, original dice, exact Mana/current remainder, SPD/Running, DT/DP and equipment separation.
- 1,000 / 10,000 / 100,000 unique semantic effects, realistic inventory and long runs. These are test tiers, not newly invented gameplay caps.
- Foreground/background, READY/active/downtime, cold reload, repeated save/export/import/cancel, old backups, wrong identity/root, ID replay under new requests, stale writers, lost acknowledgements, corrupt pages, quota and previous-record damage.
- Record stage timing, p50/p95/max, event-loop stalls, renderer RSS/private, JS heap, actual WASM capacity and native live allocations when available. Diagnostic GC classifies retention only, never a production remedy.
- Actual Godot 4.7.2 RELEASE, not debug or a JS-only scheduler helper. Cover Desktop filesystem and real isolated Edge IndexedDB. Failure injection does not establish OS power-loss durability.
- Declare supported low/mid CPU/RAM/storage and hardware-WebGL reference configuration; software rendering is additional stress. Do not average away >10-second routine results or mix one-time legacy conversion into routine benchmarks.

If targets fail, do not activate. Revise from evidence. Supported workload/resource budgets and handling of legitimate lifetime growth require owner review, with a recoverable path and no silent deletion/rejection disguised as optimization.

## 11. Small independently approved implementation passes

| Pass | Scope and existing integration points | Exit evidence |
|---|---|---|
| A: dormant contract | V6 codec, pure compact semantic verifier and exact-ID prototype; contract/projection/receipt helpers, no storage dispatch | Independent accounting/ID/growth fixtures, malformed/changed/missing proof rejection, no live callers. |
| B: conversion extraction | Streamed source validator and isolated converter; reuse coordinator, authored admission, END/WIS replay | Full V2/V4/V5 validation once, independent equality, HPB plateau/timing and head-race/cancel tests; no real migration. |
| C: disposable atomic storage | Extend current coordinator/adapters with compact head/previous/journal and exact pages | IDs older than journal, rewrapped effects, consumed items, stale/conflicting heads, interrupted writes/readback, desktop fence and browser upgrade tests. No live upgrade. |
| D: compact backup/restore | Versioned streaming contract/task/reader/files/restoration, legacy reader retained | Portable full proof checks, ancestry/older-file rules, limits/corruption, read-only previews, cancellation and exact readback. |
| E: recovery/reversal | Original archive + post-conversion delta tail, compact-capable recovery and reverse converter | Preserve all post-conversion progress; prove credit/END/run-policy legacy representation or block activation. |
| F: runtime adapter | Playable/browser persistence, projection and ledger hydration, existing controller boundaries | Exact stats/resources/Running, RNG/events/digests, rewards/IDs/policy/namespace isolation; schema 12 unchanged. |
| G: release performance gate | Disposable Desktop/real Web matrix, appropriate integration checkpoint before activation | Actual targets and workload-bound memory; no extrapolation from debug-only tests. |
| H: controlled owner conversion | Separately authorized exact profile and safeguards, dry report then explicit activation | Independent equality/readback, safe cancellation/rollback, original archive retained. No automatic merge. |

Each pass needs its own reviewed scope and tests. These names are recommendations, not authorization to implement. Do not combine all persistence changes into one speculative rewrite.

## 12. Owner decisions and blockers before activation

1. Approve **bounded hot state plus growing exact lifetime evidence**, including original archives and the rollback tail while old-format reversion is promised. A 20-entry journal cannot replace those.
2. Approve V6/container versions and the database upgrade/minimum-compatible-build policy. Demonstrate desktop old-writer fencing and browser blocked/versionchange recovery first.
3. Choose rollback guarantee: compact-capable recovery is mandatory; unmodified legacy-format reversal requires proof for every enabled mutation. If receipt bindings cannot be preserved, decide explicitly; no false reversibility promise.
4. Approve semantic-proof equivalence for portable imports. Any existing rule unprovable from the compact facts/witnesses blocks that path. Local digests do not provide anti-cheat or reliable total-storage anti-rollback.
5. Define supported hardware/workload budgets and behavior as legitimate lifetime data grows beyond measured routine targets. Performance is not yet demonstrated.
6. For future co-op, choose authenticated ownership/session/outcome authority and eligibility for unsigned offline characters. PvE-first is locked; PvP remains deferred.

**Recommended next task: Pass A only.** Build an isolated compact contract, lifetime-ID/accounting prototype and independent WIS/END chronology fixtures. No production writes, new DB activation or migration. Resolve proof/reversal limits before adding live storage.

## 13. Work performed and safety

This task inspected current source and existing disposable fixture metadata and added this one design document. No production, test or configuration code changed. No actual character, owner IndexedDB, save or historical backup was accessed. No migration, Web export, full regression, staging, commit or push occurred. Prior 45B–45I work and project.godot remain intact. Stop for owner review before implementation.
