# Dormant Profile V3 compatibility prototype

Baseline: `main`, `bd2ef5b`. This is a controlled compatibility design and isolated
validator, not production saving, migration, hydration or gameplay integration.
`ProfileV3Compatibility` is called only by tests. Save Contract V2, simulation
schema12, storage adapters, progression, UI and live combat are unchanged.

## Reusable attachment points

- `CharacterSaveContract.encode/decode` supplies the existing canonical JSON,
  payload checksum and versioned envelope pattern. The new prototype uses the
  same format identity with explicit envelope version3; production decoding still
  rejects version3. It does not replace the current decoder.
- `CharacterProfileProjection` remains responsible for legal source identity,
  authored exceptions, immutable purchases, recorded growth, ownership and derived
  resource reconstruction. V3 does not guess those values or reroll them.
- `LifeStateHistoryContract` supplies deterministic event replay, receipt IDs,
  permanent/effective attributes, timed sources, explicit resurrection evidence,
  attempt cancellation and generation-bound heads. Candidate-only binding
  inspection is separate from acknowledged-generation verification.
- Existing version1 `CharacterSettlementReceipt` validation checks typed
  XP/purchase/item/currency receipts. The prototype links them to lifecycle events
  rather than introducing another wallet or inventing a reward split.
- Existing coordinator prepare/commit/reconcile, immutable generation history,
  expected-generation comparisons, writer ownership and exact readback are the
  future publication boundaries. No storage method or production coordinator is
  invoked by this prototype.

## Proposed body and compatibility envelope

The checksum covers the exact canonical body. It is integrity checking, not
authentication of an edited unsigned document.

```text
format: itank_arena_character
version: 3
payload_json: canonical JSON of:
  prototype_version: 3
  anchor_document: exact original verified V2 envelope text
  anchor_sha256: SHA256 of those exact original bytes
  generation: anchor generation + relative history-binding generation
  life_history: existing version1 dormant lifecycle record
  history_binding: identity, event count/head, history digest,
                   relative generation, publication IDs and parent-binding hash
  settlement_links: [event_id -> existing typed version1 receipt(s)]
  completion_links: [event_id -> verified CLOSED exchange / participant-head evidence]
  gate_links: [attempt-begin event_id -> next-wave or explicit new-run evidence]
sha256: SHA256 of payload_json
```

This is a compatibility body, not an activated playable profile. The exact anchor
preserves its level, purchases, growth rolls, legacy identity, items/provenance,
equipment condition and other original fields. No starter grants are replayed.
The source-qualified lifecycle extension carries death causes, changed attributes,
temporary sources/durations, restoration decisions/receipts, resurrection completion
and attempt disposition. A true playable V3 projection/hydration adapter is absent.

`inspect_legacy` accepts existing valid V1/V2 documents read-only and reports
`legacy_extension_absent`; it never creates a lifecycle record. Unsupported unknown
legacy fields cause a preserved/quarantined result containing the original text,
not a rewritten document with those fields removed. Allowed opaque metadata is
also preserved byte for byte. V1 lacking the required history cannot be a V3 anchor.
There is no silent ID relabeling, NORMAL/DEV cloning or baseline migration.

For V3, profile/definition/rules/namespace must match the anchor and trusted source
attestation. Origin EXPC must equal the existing spendable anchor balance; it is
not added to earned XP a second time. Life replay derives one EXPC projection from
that balance, observed awards and active recovery costs. Cancelled attempt receipts
remain in immutable history/links but do not debit the restored active projection.
No persisted second balance or independent reward authority is introduced.

The explicit generation offset maps an existing V2 generationG to the first V3
candidateG+1, even though the new lifecycle binding starts at relative1. Each later
publication increments the same global character generation. New runs cannot reset
the anchor, generation, historical IDs or audit prefix. New-run evidence names both
run IDs and the exact prior subject head; it is not a fabricated combat clock reset.

## Validation and trust boundary

All new arrays/fields are explicit. Validation rejects unsupported versions,
missing/conflicting heads, reordered events, duplicate event links, repeated receipt
or effect IDs, cloned acquisition provenance, unrepresented spending, orphan links,
unauthorized rollback and unverified resurrection completion.

Typed settlement links must cover every recovery and reward event, including
cancelled purchases. Recovery uses the owner's2,000-per-point rate while the
starting permanent score is below1; at1+ it calls the existing catalog. Each point
still has one player decision and one unique receipt. Temporary-only penalties
cannot be purchased away; recovery never revives. HPC death is a separate cause.

Real authority callbacks must attest existing legal source definitions/baselines,
attribute effects, inventory/equipment projections, ledger receipts, ordinary
XP/progression history, peer heads, closed exchanges and run transitions. They
receive copies of exact records and may not be client-provided booleans. A file,
effect name, checksum or speculative storage status is not an authority.

The tests use explicit synthetic registered fixtures to isolate contract invariants,
and separately inspect the actual authored Vaelis V2 starter in memory. Synthetic
fixture statistics/reward samples are not new gameplay definitions or formulas.
No live source/ownership/progression adapter is supplied. For real data, unavailable
or unrepresentable level/derived-stat/growth/item evidence must fail closed through
these ports; the validator does not claim complete playable character reconstruction.

## Closed-exchange party outcomes

The owner ruling is RESOLVED: **an all-party wipe is DEFEAT even if the final enemy
dies in the same exchange.** Both the lifecycle view and V3 validator reuse the
same completion classifier. No victory rewards or advancement may escape from
enemy-first event delivery before all player deaths in that exchange are resolved.

A completion link carries team/wave/exchange identity, closure evidence, final-wave
flag and an independently verified participant-head vector. It contains no full
copies of teammates' private profiles. Each row binds profile namespace/generation,
head, life and membership; the subject row must match its exact pre-outcome state.
Duplicate completion evidence, missing closure or a claimed victory with no living
member is rejected. Existing resolved purchases/progress are not mutated by a view.

With living survivors, a dead teammate remains excluded from that wave's rewards,
may spectate/choose recovery, and blocks the next wave. A next-wave gate needs
current verified party evidence: all remaining members must be alive. Legitimate
resurrection or personal departure can resolve the gate; an old victory snapshot
alone cannot. Final-wave dead-member rollback and survivor progress remain personal.

Only the named standard p.301 RESURRECT evidence is supported: four Acts,50 Mana,
touch, corpse dead within72 hours, distinct living caster and actual prerequisite
completion. Other abilities are not assigned those requirements. No free action,
extra turn, resurrection effect or resource restoration is implemented here.

## Coordinator simulation and atomicity limits

`prepare` validates the candidate, immutable anchor/history/link continuity, expected
global generation, new transaction identity and a trusted observation of the current
storage head. A structurally valid old prefix still cannot replace newer history.
An authorized rollback instead appends its checkpoint/cancellation event and keeps
all prior transaction IDs while restoring only that attempt's active state.

`acknowledge` requires transaction completion plus exact fresh readback of document,
generation and transaction identity, bound to the prepared CAS intent. The current
pointer must still match. Pending/failed writes and superseded acknowledgements
are not success. Repeated exact acknowledgement observes one completed transaction;
it never reexecutes a debit, reward or cancellation. The test harness stores only
in-memory observations. It does not write files, access IndexedDB or prove crash
durability on a real platform.

The eventual coordinator must publish the entire V3 profile/lifecycle/receipts/
checkpoint binding in one existing per-profile generation. Native filesystem
replacement retains its current documented limits; browser publication requires
the existing complete IndexedDB transaction, fresh readback and exclusive lease.
No missing-read result may initialize a blank character over uncertain data.

**Multi-profile atomic publication is not demonstrated.** `prepare_cohort` returns
`multi_profile_atomic_publication_unavailable`. Current per-profile Web Locks,
desktop generations and two-observer synchronization do not implement recoverable
cohort commit across independent players. Team-wide retry/advancement needs a
separately reviewed protocol for ownership, consistent expected heads, partial
completion and recovery. Personal departure may publish only that profile; it must
not roll back survivors' independent generations.

## Remaining gates and next step

1. Source-qualified real V3 projection/hydration, ordinary event-time growth and
   equipment/resource reconciliation must reuse existing validators. No migration
   of owner V2 profiles is authorized; incomplete histories cannot be invented.
2. Actual wave-entry references are available; a different multiplayer match-wide
   boundary is not. Cross-run combat-clock/effect rebasing and checkpoint capture
   still require a real source adapter, separate from the tested generation offset.
3. Existing production coordinator/receipts require monotonic spent XP. V3 attempt
   cancellation needs explicit net accounting and retained immutable audit records,
   not deleting receipts or crediting an extra refund. No production changes occur.
4. Multi-profile cohort atomicity/recovery remains blocked as described above.
5. Simulation schema12 has no independent life state. Live synchronized death,
   reward gates, source-specific resurrection and profile admission remain separate
   owner-authorized work. Existing backups/storage stay on their current contracts.

The later disposable-storage pass below exercises the per-profile disk seam. Keep
production admission, automatic migration, multiplayer cohort publication and live
death off until their required guarantees are implemented and tested.

## Compatibility-pass validation

- New Profile V3 suite: **208 assertions passed**, using isolated in-memory
  histories, registered evidence and simulated acknowledgements. No storage writes.
- Existing dormant evaluator/history/multiplayer suites: **326 / 704 / 224
  assertions passed**. Universal-engine coverage rechecked all **648 chart cells**.
- **27 selected suites passed**: those five suites plus guarded SS, authoritative
  STR/DEX, both STR advancement suites, legacy advancement, reward ledger, V1/V2
  contract/storage, projection, coordinator, playable desktop/browser persistence,
  NEXT WAVE/RETURN/new-run recovery, both backup suites, combat actor/actions,
  persistent waves/spear ownership, two-client synchronization and deterministic
  five-wave framework. Browser persistence here is its native focused harness;
  no new actual-browser durability claim is made.
- Godot 4.7.2 headless import: exit 0. Final successful test/import logs: zero
  errors, warnings, ObjectDB leak or retained-resource messages. An intermediate
  test-only type-inference error was corrected before the final focused run.
- Production contract, projection, coordinator, checkpoints, backup/restoration,
  simulation/actor/session/controller and STR/DEX source hashes match HEAD.
  `git diff --check` and explicit untracked-file whitespace checks passed.
- Full regression and Web export were not run; they remain owner checkpoints.

## Disposable filesystem validation — dormant, test-only

`tests/profile_v3_disposable_storage.gd` is a disk harness, not a new production
backend. It can select only fresh `v3_case_*` roots beneath the existing
`OS.get_cache_dir()/itank-storage-tests/` boundary. It reuses the production storage
identifier validation and ownership-marked writer guard, plus this prototype's
prepare/validate/acknowledgement logic. V2 desktop storage cannot accept V3 without
changing its contract decoder; that decoder and coordinator remain untouched.

The harness writes the exact source-attested V2 anchor once, then immutable
generation files containing the complete prepared V3 request and transport hash.
Each publication flushes/closes staging, verifies it, renames it within the same
directory to an unused generation filename, and freshly opens/verifies the complete
chain and current record before acknowledging. Standalone reconciliation also
holds the reused writer guard, so fresh head observation cannot race a cooperating
publisher; publication uses the same guarded path without nested acquisition.
There is no overwriting of old
generations or separately updated head pointer. This follows the existing desktop
immutable-generation publication pattern. The measured property is successful
filesystem rename/readback and preservation of old files; tests do not prove atomic
visibility on every filesystem, fsync of directory metadata or power-loss safety.

Fault injection stops before staging, during a partial write, after complete staging,
after rename, at lost acknowledgement and at readback mismatch. Fresh adapter objects
reopen real files. An unpublished staged file is retained and blocks writes; it is
never automatically promoted or deleted. A completely published exact transaction
can reconcile repeatedly without rewriting, repeating a purchase or refund, or
creating another generation. Superseded acknowledgements are rejected. These are
simulated interruption points with cooperative lock release, not process kills,
OS crashes or power cuts. Actual stale locks remain fail-closed in the reused guard.

Recovery validates every retained generation against its anchor, exact prepared
request, source evidence, receipt identities, expected predecessor and history
prefix. Missing/partial/corrupt/future records and chain gaps block publication;
a verified older prefix may be reported for inspection but is never silently
acknowledged as the new head. A supplied minimum acknowledged generation detects
a missing newest file. Like current local unsigned storage, a fully removed tail
or whole-directory rollback cannot be detected without an independently retained
trusted head. Checksums are not authentication; the harness assumes an
application-controlled cache directory and cooperative writers, not hostile OS
editing, symlink manipulation or a new cross-device authority.

The fixture source registry is reconstructed in memory and delegates rule checks
to the existing dormant validator. Disk bytes do not authorize themselves. These
tests prove binding to the supplied exact registered profile/generation, not a
complete production V3 projection/hydration or a new authentication system.

Independent multiplayer profiles are tested on real disk: survivor rewards remain
unchanged while a dead participant's write/acknowledgement is interrupted and their
personal departure restores only their own verified attempt entry. All-party wipe
records remain defeat despite final-enemy death. `publish_cohort` always rejects
before writing anything. Sequential independent writes are explicitly NOT an atomic
team transaction; no partial cohort success or automatic compensation is claimed.

Cleanup checks each newly created absolute cache root before removing only that
fixture's immediate files/directories. Tests never enumerate or access owner-save,
backup, protected DOC, `character saves/` or `tmp/` content. No production contract,
schema12 field, gameplay call site, spending or reward logic changes.

The owner-approved future lobby scope is recorded under **Future transport path**
in `MULTIPLAYER_FOUNDATION.md`; no lobby/network implementation is part of this pass.

Next checkpoint: owner full regression and Web export. Production V3 source adapters,
admission/migration, real platform crash qualification and multiplayer cohort
publication remain separately gated. No live integration is authorized here.

### Disposable-storage validation results

- **538 assertions passed** in the new disk suite, including ownership/cleanup
  checks for all **18 fresh disposable roots** under
  `C:/Users/mxz/AppData/Local/itank-storage-tests` on the tested Windows host.
  No fixture files or profile directories remained after cleanup.
- **32 unique selected suites passed**: all eleven current #37C suites, both
  #37B advancement suites, #36B advancement, #36A rewards, #36D contract, #36E
  storage, all five #36J persistence passes, all three #36J fixes, #36K-Pass2,
  both #36L backup suites, combat actor/actions, two-client synchronization,
  #35J persistent waves/spear continuity and the deterministic five-wave framework.
  The final disk-only rerun covers its subsequent test-harness guard/input checks.
- Evaluator/history/multiplayer/V3 compatibility retained their **326 / 704 /
  224 / 208** passing assertions. The universal-engine suite checked **648**
  printed chart cells. Guarded SS and STR/DEX retained their existing comparisons.
- Real reads verify exact canonical documents, immutable prior files, generation
  continuity and receipt accounting. A discarded later attempt restores EXPC
  without erasing recovery spending committed at an earlier checkpoint. Frozen
  duration survives disk reload, then only explicitly resumed encounter time ages
  the source; resources/life are not refilled or revived.
- Godot **4.7.2** headless import: exit0. Final successful logs: **zero errors,
  warnings, ObjectDB leaks or retained-resource messages**. `git diff --check`
  and explicit new/untracked-file whitespace checks passed. Sixteen checked
  production combat/persistence source files match HEAD, including Save Contract
  V2, schema12 simulation code, storage, coordinator and backup/restoration.
- Earlier test construction initially lacked the inherited fixture's head
  acknowledgement. It was corrected to observe real disk readback before preparing
  another generation. No production safeguard was relaxed.
- Full regression, Web export, OS/process crash and power-loss testing were
  **not run**. No new browser-durability or multi-profile atomicity claim is made.
