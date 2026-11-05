# Dormant DEAD-attribute evaluator

`DeadAttributeEvaluator.evaluate(context)` is an isolated deterministic query.
There are no live combat, loading, purchasing, resurrection or persistence calls.
Its conclusions are findings, never actions or an authorization to spend EXPC.

## Rules and sources

V3's independently verified Mana and Regular zero rows mark STR, END, WIS, INT
and WIT DEAD. SPD/DEX/LUK/APP have numeric zero rows; MAN is not charted. The
frozen source catalog and checksum remain unchanged. No SS/derived lookup is
treated as a primary transition or permission to kill an actor.

Owner-approved ruling: a living character crossing to effective zero or below after creation
dies, including permanent and temporary reductions. Attribute recovery does not
revive. Resurrection barriers use effective values: permanent WIS0/effective WIS2
has no WIS barrier while the valid modifier remains active. A legitimate separate
resurrection effect is still required. The owner-approved recovery price is
2,000 EXPC per permanent point whose starting score is below1, including every
negative step and0→1. At1 and above use the existing verified advancement pricing.
This is a dormant recovery adaptation, not a change to the live purchase catalog.
Existing authored initial undead zeros remain valid; this is not blanket immunity
to subsequent positive-to-zero changes. No runtime rule is enabled in this pass.

### Owner-confirmed recovery pricing correction

| Permanent recovery | EXPC | Receipt requirement |
| --- | --- | --- |
| -3→-2 | 2,000 | One distinct point receipt |
| -2→-1 | 2,000 | One distinct point receipt |
| -1→0 | 2,000 | One distinct point receipt |
| 0→1 | 2,000 | One distinct point receipt |
| -3→1 total | 8,000 | FOUR separately affordable receipts |
| -5→1 total | 12,000 | SIX separately affordable receipts |

This supersedes the prior negative-price restriction. The below1 rate is an
explicit owner-approved permanent-recovery rule. It does not change the ordinary
Prime V3 p.102 catalog or unlock live advancement. Starting at1, that catalog
continues to govern:1–5 costs2,000,6–10 costs3,000,11–15 costs5,000 and the remaining
verified bands stay unchanged. A quote or multi-point total cannot spend EXPC.

Each actual prototype receipt records exactly one permanent +1 and the same
effective +1, preserving temporary modifiers. Insufficient funds, negative
balances, skipped/multi-point jumps, duplicate receipts and stale/conflicting
heads are rejected. Removing an attribute barrier does not restore life.

## Explicit input contract

All keys are required; unknown keys/attributes, noninteger scores, incomplete
snapshots, missing source descriptions and unsupported classifications fail closed.
Primary dictionaries use all ten existing lowercase identifiers. Authored baseline
scores remain 0–35; before/after snapshots may contain signed negative values up
to the existing upper limit 35. Negative values are observed without clamping or
looking up/extrapolating chart-derived values below zero.

```
phase: "creation" | "transition"
life_before: "living" | "dead"
change_kind: "initial" | "permanent" | "temporary" | "recovery" | "effect_expiration"
classification:
  kind: "living" | "authored_undead"
  source_ref: nonempty source description
  authored_attributes: complete authored primary dictionary
  initial_zero_exceptions: explicit primary identifiers, initially zero in source
before: { permanent: complete primary dictionary, effective: complete primary dictionary }
after:  { permanent: complete primary dictionary, effective: complete primary dictionary }
available_expc: nonnegative integer
```

Creation must explicitly supply identical authored before/after snapshots. An
initial zero in a nonqualified living baseline remains an unresolved creation
policy, not an inferred death event. Skelly fixtures provide their actual authored
WIS0/INT0 data and exception list. Undead classification is supplied by the caller
from verified data; this pure function validates consistency, not authenticity of
a source string. Future admission must authenticate the source independently.
Here `living` means not already in the evaluated death state; it does not change
an authored undead creature's biological classification.

For unchanged authored zeros the evaluator emits `initial_authored_undead_zero`.
A later positive→zero transition is not exempted merely by the baseline. An
already-dead actor with ambiguous authored-zero history requires explicit history
before a resurrection barrier can be resolved. Permanent and effective inputs
stay distinct; temporary/expiry snapshots cannot rewrite permanent attributes.
`effect_expiration` describes explicit already-supplied snapshots only. It is not
a timer, time-advance command or authority to expire any effect.

## Results and boundaries

Valid inputs return `success=true`, typed findings, `death_transition`, `life_after`,
attribute-zero barriers and individual emergency quotes. Each below1 permanent
quote contains signed from/to values, cost2,000 and affordability against the
supplied EXPC balance. Quotes are
individual, not batch funding or transaction authorization; no EXPC is reserved
or spent. Multiple zero attributes create multiple findings/barriers but no
duplicate actions. All outputs are fresh data and input dictionaries are untouched.

`life_after` remains dead when `life_before` is dead, even after recovery or an
explicitly supplied later temporary-value increase. Positive effective values remove the
zero barrier only; no resurrection occurs and other resurrection prerequisites
are not assumed satisfied. Effective nonpositive values are reported in
`resurrection_barriers` and `attribute_nonpositive_barrier_present`, irrespective
of permanent base. Negative overshoot establishes death just like zero. Its
permanent recovery price is now explicitly owner-approved, not unresolved.
Quotes target the PERMANENT score, never the temporary penalty. A temporary-only
zero/negative value with no permanent loss creates no emergency quote. A valid
positive temporary modifier may lift the barrier without altering permanent
recovery pricing. The history prototype validates completed point receipts;
temporary modifiers are never removed by buying a point. Quotes remain nonbinding.

Malformed/unsupported inputs return `success=false,status=invalid`. Unexplained
already-nonpositive living history or ambiguous dead-undead zero history returns
an explicit unresolved result without inventing a past transition. Overshoot,
effective resurrection eligibility and temporary recovery are RESOLVED by the
Pass2 owner rulings; earlier contrary gates are superseded.
No HPC, resources, conditions, source histories, actions or schemas are mutated.

Still outside scope: live death commit/event ordering, permanent-loss history,
source expiry scheduling, automatic resurrection ordering, crash/RETRY/RETURN
policy, durable death state, transaction execution and WIS/END recovery effects
on resource history. The 2,000 quote does not unlock any existing purchase catalog.

## Validation

The registered focused suite checks both frozen zero-chart rows, each lethal
attribute under permanent and temporary changes, all five nonlethal/unlisted
primaries, actual Skelly data, recovery without revival, prices/funds, multiple
barriers, invalid/incomplete inputs, unresolved cases, repeated determinism,
input isolation and an unchanged schema12 simulation snapshot/RNG/event state.
Only tests and the dormant life-state/history prototype call the evaluator;
no gameplay call sites or persistent fields exist.

Historical Pass1 validation: 138 evaluator assertions passed. Six focused suites passed: evaluator,
guarded SS, authoritative STR, authoritative DEX ACC, dormant universal attributes
and two-client synchronization. Final headless Godot 4.7.2 import and whitespace
checks passed. Logs reported no ObjectDB leaks or retained-resource warnings.
Full regression and Web export were not run for this dormant implementation.

Pass2 validation: 205 evaluator assertions passed (67 added over Pass1). All 13
selected suites passed: evaluator, guarded SS, authoritative STR and DEX ACC,
both #37A suites, combat actor/action, both #37B suites, #36J-Pass1 projection,
both #36L backup suites and two-client synchronization. These cover unchanged
replay/RNG/events, advancement, character projection, backup and restoration.
Headless Godot 4.7.2 import and whitespace checks passed. The focused/import logs
reported zero ObjectDB leak warnings and zero retained-resource warnings.
Full regression and Web export remain owner-run checkpoints and were not run.

## Pass2 lifecycle / persistence / transaction audit

No live code in the following systems is changed. Existing approved rules govern
threshold <=0, the five lethal primaries, effective-value resurrection barriers,
death persisting after recovery, authored initial-zero exceptions and 2,000 EXPC
for EACH permanent recovery step starting below1. These are not pending rulings.
A barrier-free result means only that
this evaluator found no attribute barrier, never permission to execute resurrection.

| Boundary | Reuse / exact location | Remaining work or policy |
| --- | --- | --- |
| Authoritative death independent of HPC | `CombatSimulation` mutation completion; `CombatActorState`; session `_update_encounter_outcome` | Introduce an approved separate life-state/cause contract before live activation. Current action/defense/target/wave checks and `ArenaRewardLedger.process_defeat` largely gate on HPC. Never manufacture HPC damage for primary death or allow positive-HPC dead actors to act. |
| Effect application/expiration | Simulation `_apply_timed_stat_effect`, `_resolve_timed_stat_effect_expire_due` and shared authoritative clock | Existing effect IDs and expected-expiry checks prevent stale expiry. Current session `advance_by` stops when encounter is inactive. Owner ruling now requires duration retention during frozen encounter time and aging only when it resumes. No wall-clock aging. |
| Simultaneous changes | Existing scheduler timestamp/initiative/stable-sequence ordering; complete modifier dictionary commit | Reuse established event order, evaluate after each complete authoritative mutation before another action. One atomic mutation can yield several barriers and one death-transition result. Do not batch independent resolved events to hide an intermediate lethal state; do not invent new event priority. Preserve existing committed strikes, resolved defenses/damage and spent Acts. |
| Emergency recovery | Session `get_character_advancement_eligibility`, simulation `apply_verified_character_advancement`, ledger `purchase_advancement` | Current live gates/catalog remain unchanged. Owner-approved dormant recovery uses2,000 per permanent point starting below1; at1 and above reuse the verified catalog. Every point needs a separate authorized receipt. No purchase can remove a temporary penalty or revive the character. |
| Exactly once / affordability | Ledger processed request IDs; namespaced permanent purchase/settlement receipts; coordinator expected generation and verified acknowledgements | Reuse one balance and atomic debit/history application. Future request binds profile/namespace, death and source IDs, affected primary, expected values/revision/generation; duplicate/stale requests spend nothing. Individual affordable quotes cannot authorize a simultaneously affordable bundle. No extra Acts, unrelated purchases, RNG or resource refills. |
| Crash / RETRY / RETURN | `PlayableCharacterPersistence.open_verified_history/checkpoint/_ack`, coordinator, browser publication, `CharacterWaveCheckpoint.validate`, `CharacterProfileProjection.hydrate` | Unconditional retention is superseded: an authorized discarded attempt restores its actual pre-attempt checkpoint, including suffered permanent losses, death, equipment and spending. Pre-checkpoint progress and historical transaction identities remain. Rollback appends a cancellation event in a new generation; it never truncates audit history or refunds twice. Uncertain writes require reconciliation. |
| Authored undead | Verified definition catalog / source admission; explicit authored baseline and initial-zero exceptions | Skelly WIS0/INT0 stays valid. Caller must authenticate classification and track whether an exception remains an initial baseline or has a subsequent positive→nonpositive history. The evaluator does not authenticate a source string or grant blanket undead immunity. Missing historical evidence must fail closed. |
| Resurrection | Separate source-backed action definition, target eligibility and completion handler | V3 resurrection variants have different corpse/body, cost, timing and resource rules. Merely listing Resurrection in drops is not an implemented effect. No generic revival is authorized. Effective barriers must be checked again at actual completion; expiry/recovery cannot reverse or grant a resurrection result. |

### Owner decisions resolved by durable-retention pass

1. Recovery-pricing correction supersedes the earlier lower-score gap: every
   permanent recovery step starting below1 costs2,000, so -3→1 costs8,000 across
   FOUR distinct purchases. At1 and above use existing verified advancement prices.
   Temporary penalties cannot be bought away. A permanent point purchase preserves
   the modifier and may leave the effective score nonpositive.
2. Encounter freeze preserves remaining durations; aging resumes only with the
   encounter clock. No expiration, wall-clock catch-up or automatic effect removal.
3. An explicitly authorized emergency purchase may precede the separate resurrection
   eligibility check. Recovery never revives. No automatic debit or resurrection.
4. **Superseded retention assumption:** unconditional retention of attempt losses,
   death and emergency spending across RETRY/failed attempts is no longer approved.
   A discarded attempt restores its verified pre-match checkpoint projection.
   Transactions committed BEFORE that checkpoint survive. Attempt purchases can be
   cancelled exactly once; their identities/audit events remain permanently known.
   One participant's failure cannot roll back another's independently secured rewards.

These replace the earlier open questions, not the underlying approved V3 rules.
Actual source-specific resurrection effects/costs remain outside this prototype;
none is invented. The remaining gaps below are source-data and technical integration
gates, not permission to reopen the retention or frozen-time rulings.

WIS/Mana and END historical growth rules remain approved and unchanged; if a
future recovery becomes a permanent attribute grant, its history must satisfy
those rules without rerolling or refilling resources. Authored-zero history and
schema design are missing implementation/data contracts, not new blanket-immunity
or chart rules requiring reinterpretation.

### Previous next step (implemented dormantly below)

Authorize only a dormant life-state transition/history contract with isolated
serialization and replay tests. Reuse this evaluator, keep positive-HPC death,
death cause and resurrection eligibility separate, and specify how a validated
caller supplies authored-exception/source history. Do not add live gates or save
fields until versioned compatibility is separately approved. Then scope one authoritative
mutation boundary; emergency transactions and one verified resurrection effect
remain separate later passes. There is no need to repeat threshold/effective-value
rulings or introduce WIT/INIT/SPD calculations.

## Dormant life-state / history contract

`scripts/combat/life_state_history_contract.gd` implements a pure in-memory
prototype. Only its registered tests call it. It does not load or save a profile,
run a timer, access an actor, authorize an EXPC debit or execute a resurrection
effect. Existing evaluator behavior and all live code remain unchanged.

### Interfaces and trust boundary

- `create(identity, origin, authority)` validates an explicitly supplied authored
  origin. It does not infer missing attributes, historical causes or classification.
- `append(history, event, authority)` returns a new validated candidate history;
  failure returns no partial history/state. It does not publish anything.
- `replay(history, authority)` reconstructs state and causal findings from the
  complete supplied sequence, without RNG or external writes.
- `encode/decode` roundtrip isolated canonical JSON with SHA-256 integrity.
- `reconcile(history, event, authority)` distinguishes an exactly recorded event,
  an absent valid candidate and an identity conflict; it never retries a debit.
- `compare_recovery(current, candidate, authority)` reports exact, extension,
  explicit-attempt-rollback-required or conflict. It never truncates history.
- `prepare_generation`, `verify_generation`, `acknowledge_generation` validate
  generation/head/transaction binding and exact external readback; they do not write.
- `retain_for_boundary` reads acknowledged history for reconciliation. It cannot
  apply an older entry for RETRY/RETURN/interruption without a new authorized
  attempt-discard event. It is not an unconditional retention policy.

The required deterministic authority callback receives deep copies of the record
and identity and must return exactly `true` for a verified origin/event. Future
integration must bind these to the trusted authored catalog, actual resolved
mutation, source identity, committed ledger receipt or authorized resurrection
completion. Supplying an effect name or a checksum is not authorization. Tests
use an isolated exact-content approval registry, never a production ledger.
The callback itself must remain read-only and deterministic. It cannot establish
genuine V3 resurrection eligibility merely by trusting data from a save file.

### Prototype record and replay

Format `itank_life_history_prototype`, version1, is deliberately **not** a
Character Save Contract V2 document, simulation snapshot or sidecar save system.
It is used in memory only and is rejected by existing production save validation.
The 4,096-event / 8MiB bounds are diagnostic prototype limits, not character or
gameplay limits. No production history truncation/compaction policy is approved.

Identity includes profile, NORMAL/DEV NORMAL namespace, character, rules revision
and a caller-supplied stable history ID. TEST cannot become a profile namespace.
The origin includes verified authored classification, complete permanent/effective
primary snapshots and an explicit EXPC baseline. Life begins alive only when the
existing evaluator accepts that creation state. No unknown prior death is invented.

Events are append-only and have stable namespaced IDs, contiguous sequence,
parent hash, explicitly supplied authoritative timestamp/resolution index, kind
and data. They must already be in authoritative resolved order; replay does not
sort them or invent initiative priority. Parent/sequence/order conflicts fail.
The prototype models one ordered stream; live cross-run integration must bind
clock epochs and resolved-order identity to existing run/wave identities rather
than blindly reusing a reset encounter clock or within-run event counter.
Source records identify permanent or temporary changes, their governing source
reference and affected primaries. Every changed primary/layer needs coverage.
Explicit expiration must name the exact previously recorded active temporary
source. Duplicate active application, missing source and mismatched expiry fail.
No duration, wall clock or automatic effect update is inferred.

Event kinds:

| Kind | Requirements and result |
| --- | --- |
| `attributes` | Exact previous snapshots, validated after snapshots, qualified sources and externally authorized change. Uses the evaluator for alive-to-dead transitions. One atomic mutation can produce several lethal causes and only one death record. Already-dead actors remain dead; no new death action is generated. |
| `emergency_receipt` | Observes a separate externally committed receipt; never requests a purchase. Checks unique namespaced transaction/debit IDs, exact before balance, sufficient funds and the price for ONE permanent lost point. Starting below1 costs2,000 per point; at1 and above use the unchanged catalog. Effective value increases by the same1, preserving every temporary modifier/source. A temporary-only loss cannot authorize a purchase. A recorded permanent high-water mark prevents unrelated advancement through this emergency path. No ledger is called. |
| `resurrection` | Requires dead state, no effective attribute barrier, the current causal death ID and a unique externally verified effect authorization. Changes only prototype life state. It defines no resurrection spell, timing, cost, HPC restoration or other resource policy. |
| `effect_time` | Records explicitly supplied encounter elapsed time and frozen state. Frozen time retains duration exactly. Resumed time ages known durations; unknown duration fails closed. Reaching expiry requires an atomic, source-qualified expiration snapshot, so a stale positive modifier cannot slip through an intervening resurrection check. |

Replayed state distinguishes `life`, causal deaths, current attribute barriers,
attribute-only eligibility, explicit resurrections, observed emergency receipts,
current source records and their ordered history. Recovery never changes life.
Permanent0/effective-positive lifts the barrier only while that positive value
remains established. Expiration after resurrection can cause a new lethal crossing.

Full history also resolves a limitation of snapshot-only evaluation: unchanged
Skelly WIS0/INT0 exceptions remain identifiable after an unrelated death. Each
exception is retired when that primary departs its authored zero baseline. It
cannot be reclaimed by returning to zero or reloading. Source/classification
authenticity still belongs to admission; the prototype cannot authenticate strings.

### Serialization, transactions and recovery limits

Serialization reuses the existing canonical JSON/SHA-256 pattern rather than
changing `CharacterSaveContract.encode/decode`. Signed integers are normalized
only when exactly representable; unsupported numbers fail rather than round or
clamp. Checksums detect corruption, not deliberate forgery or current-generation
authority. Exact prefix histories are valid historical records: recognizing the
latest durable head additionally requires the existing storage generation/head
acknowledgement. No missing suffix is silently reconstructed.

Tests model interruption before recording, exact replay after recording/lost
acknowledgement, conflicting retries, stale recovery boundaries and corruption.
They use dictionaries/strings only. They prove prototype validation and replay,
not filesystem/IndexedDB crash durability or an approved RETRY/RETURN policy.

Reusable existing mechanisms and the required future boundary:

| Existing component | Reuse / compatibility finding |
| --- | --- |
| `ArenaRewardLedger.purchase_advancement` | Single authoritative affordability/application/debit path and processed request IDs. Do not call it from replay or add a second wallet. Current purchase catalog/gates do not authorize emergency recovery. |
| `CharacterPersistenceCoordinator.prepare/commit/reconcile` | Expected-generation compare, receipt validation, immutable continuity, exact readback and lost-ack reconciliation. A future life-history head must be committed with the same profile generation, not a separately written sidecar. |
| `CharacterProfileProjection.hydrate` | Authored baseline, approved purchase and event-time growth replay are already checked. Arbitrary permanent losses, emergency recovery and independent death history are unsupported, so hiding them in purchases/development is invalid. |
| `CharacterSaveContract` V2 / `CharacterWaveCheckpoint.validate` | Strict permanent/player fields, known timed effects and supported purchase replay cannot encode the proposed new history. Any durable integration requires a separately approved versioned extension/migration and old-save policy. None is implemented here. |
| `CharacterBackupRestoration` | Preserve full generation validation, destination comparison and explicit publication acknowledgement. A future history extension must be validated through export/preview/restoration as part of the same generation. |
| Session RETRY / RETURN | Existing live behavior is untouched. Future discarded attempts restore the verified checkpoint projection through an audited rollback. Ordinary attribute recovery cannot revive; restoring a discarded attempt's prior life state is a distinct rollback policy. No match-wide checkpoint is inferred from the wave-entry implementation. |

### Temporary-effect lifecycle audit

`CombatSimulation._apply_timed_stat_effect` records effect/source action identity,
applied/expiry combat timestamps and schedules an expiry event. The resolver
`_resolve_timed_stat_effect_expire_due` validates the expected expiry, removes the
effect/condition, updates effective DEX/revisions and emits its event. It has no
independent death-state test: if the simulation clock continues while other
combatants act, the existing scheduled expiry may still run for an HPC-defeated
actor. No universal DEAD-attribute effect lifecycle is integrated today.

`ArenaCombatSession.advance_by` returns while encounter activity is false, or
while browser persistence is pending/unsecured. Player defeat sets encounter
activity false. Consequently no new elapsed combat time or corpse aging is
introduced there. Merely recovering an attribute cannot resume the encounter.
Resuming a clock would need an authorized lifecycle transition, not a wall-clock
catch-up guess. No live generic resurrection action currently provides that path.

Entry recovery retains only currently supported checkpoint effects. Existing
`PlayableCharacterPersistence.validate_new_run_conditions` clears approved
combat-only state for a NEW RUN and rejects unknown lasting conditions; that is
not authorization to clear a new lethal attribute effect or durable death.
Duration during frozen time is now RESOLVED: retain exactly, then resume aging
with encounter time. The prototype records explicit apply/time/expire inputs only.
It still cannot invent an actual resurrection action, duration or cost.

### Next approval boundary

The retention, freeze, purchase-before-resurrection and below1 recovery pricing
policies above are resolved. Production versioning/migration and live activation require separate
approval. No fake HPC damage or replaying a transaction as a fresh purchase is
acceptable. Checkpoint restoration requires a verified discarded attempt.

### Previous life-state/history validation results

- New history suite: **277 assertions passed**, including each lethal primary at
  zero/below zero, permanent/temporary and mixed simultaneous sources, exact
  source expiration, preserved authored exceptions, recovery without revival,
  externally authorized resurrection, receipt affordability/identity checks,
  canonical signed roundtrips, tampering/malformed histories, read-only recovery
  comparison, lost acknowledgements, deterministic replay and input isolation.
- Existing DEAD evaluator: **205 assertions passed** unchanged.
- **18 selected suites passed** in total: new history, DEAD evaluator, guarded SS,
  authoritative STR/DEX ACC, both #37B suites, #36J-Pass1 projection, #36J-Pass2
  coordinator, #36J-Pass5 desktop persistence, all three #36J fixes, #36K-Pass2
  browser persistence, both #36L backup suites, combat actor/action and two-client
  synchronization. Browser persistence coverage here is the existing automated
  suite, not a fresh real-browser acceptance or a new Web export.
- Godot4.7.2 headless import and `git diff --check` passed. New untracked files
  were separately checked for trailing whitespace. Final logs reported no
  ObjectDB leak or retained-resource warnings. Production Save Contract V2,
  schema12, guarded SS, STR/DEX, combat/advancement and recovery code are unchanged.
- No full regression, Web export, production save write or gameplay activation
  was performed. Existing owner saves and protected files were not accessed.

## Durable retention design (no production migration)

### Generation-bound prototype

The same dormant contract now prepares a generation proposal containing complete
history plus a binding: identity, generation, transaction ID, ordered publication
IDs, previous-binding hash, event count, event-head hash and full-history digest.
All mutation events still require trusted exact-content authorization. A new
generation requires the current acknowledged history as an exact prefix, an exact
expected generation and a new namespaced publication identity. No loss/death or
completed receipt can be deleted to make a new generation.

`head` authority means exact durable readback; `current_head` additionally means
the latest observed pointer, not merely a historically committed generation.
`empty_head` requires verified absence, not a read error. Missing authority, stale
generations, conflicting heads and false-empty initialization fail closed.
Acknowledgement compares the exact prepared history/binding to readback; queuing
a proposal is never successful saving. Lost acknowledgement can be reconciled
without another event/debit. This is pure validation; the existing coordinator
and storage adapters must enforce the final compare-and-publish inside their
existing single-writer/IndexedDB transaction boundary. No new storage is created.

`retain_for_boundary` requires the latest acknowledged head for reconciliation.
A discarded attempt needs an explicit `attempt_rollback`, not unconditional
retention or an old truncated history. An entry ahead of the head or a divergent
history is rejected. Classification alone changes nothing; an authorized rollback
restores its captured checkpoint projection once while retaining all discarded
event/transaction identities for replay checks.

### Frozen durations and restoration boundaries

New source records may carry a positive `remaining_duration_us`. Legacy isolated
records without it remain readable, but an active unknown-duration source cannot
be published as a trusted durable head or aged by guessing. A source's original
metadata remains immutable; replay keeps its current remaining duration separately.

Explicit `effect_time` records preserve duration while frozen and decrement it
only for authorized resumed encounter time. There is no wall-clock query. When
the next source is due, a plain time record is rejected: the caller must supply
the atomic expiration snapshot and `effect_elapsed_us`, including every source
that reaches zero at that boundary. Source identity, effective-score change,
barriers and death findings are then evaluated together. No zero-duration active
bonus can remain available for a resurrection between aging and expiration.

The prototype observes purchases only for recorded permanently lost points.
Each step uses the current permanent score's verified cost. It will not spend on
a temporary-only penalty or erase/change a modifier to make the character eligible.
Restoring a permanent point under an active penalty preserves the penalty's full
delta/source and may leave the character dead and attribute-ineligible. The
evaluator's quote is not transaction authorization. The live price catalog is
unchanged. Dormant recovery applies the owner-confirmed2,000 price separately to
every permanent step starting below1, including negative-to-negative and
negative-to-zero. At1 and above it uses the catalog. -3→1 totals8,000 and -5→1
totals12,000; each requires its own sequence of individually funded receipts.

`recovery_total` is a read-only estimate: exact total, point count, affordability,
consecutive affordable-point prefix, target reached and unspent remainder. It
cannot authorize a batch purchase, reserve funds, skip an unaffordable point or
apply a discount. The constant below1 band is aggregated arithmetically to avoid
unbounded iteration, with explicit integer/serialization overflow rejection.

### Minimum proposed production extension

This is a proposal only; none of these fields or versions are implemented in a
production contract, save file, simulation snapshot, backup or migration.

1. **Character Save Contract profile V3** under the existing character format and
   canonical/checksum/storage envelope. Add one explicit top-level `life_history`
   contract containing its origin, ordered events and generation-bound head.
   Do not hide it in purchases, conditions, development or arbitrary metadata.
   Retain V2 decoding/admission unchanged until an explicit migration is approved.
   Source base attributes remain immutable; permanent loss/recovery is replayed
   through validated history alongside existing purchases and event-time growth.
2. **Settlement receipt extension with its own reviewed version** for emergency
   restoration and lifecycle authorization references. Reuse the existing EXPC
   balance, transaction IDs, processed-request protection and immutable receipts.
   Join every life-history debit to exactly one authoritative ledger receipt and
   include its cost exactly once in spent/unspent EXPC. EXPM is not reduced or
   granted by recovery. Do not treat prototype `available_expc` as a second wallet.
3. **Wave checkpoint V2 proposal** binding each entry to the character generation
   and life-history head. Keep wave-entry resources/enemies separate from durable
   life state. RETRY/RESTART restore the discarded attempt's checkpoint projection,
   reversing attempt losses/death/spending but retaining the immutable audit and
   cancellation identities. RETURN remains the separate approved NEW RUN operation;
   its discard uses an explicitly authorized checkpoint, not an inferred full-run
   reset. Known combat-only cleanup is not
   permission to delete a new lethal source; unknown source removal fails closed.
4. **One profile generation / one publication transaction.** The coordinator
   prepares profile, lifecycle suffix, receipt set and checkpoint reference as a
   single candidate. Existing filesystem/IndexedDB publication, writer exclusion,
   expected generation and exact readback remain authoritative. Head continuity
   must be checked with profile continuity; never write a separate life sidecar.
   Backups export/preview/restore that complete generation, using their existing
   strict history/destination validation. Old backups cannot roll back the suffix.
5. **Simulation compatibility is separately gated.** Schema12 has no independent
   life state. This pass does not extend it. Before live activation, approve a
   tested additive contract or new version that includes independent life/cause
   state in authoritative snapshots/replay/digests. Never use an unsynchronized
   controller flag, fake HPC damage or a hidden condition as a workaround.

V2 records cannot establish unrecorded historical deaths or losses. A future
migration must bind a verified V2 generation digest and an explicitly validated
baseline, using only history actually present. It may not manufacture old causes,
receipts or timed-effect durations, or simply assume the character was alive.
When evidence is insufficient, leave V2 intact and block that upgrade pending
review. No destructive rewrite or automatic character reset is acceptable.

### Completion / crash and timing boundaries

An irreversible life-changing transaction must be durably published and verified
before it is acknowledged as completed. Future live integration must stage the
deterministic mutation/history/ledger result and pause subsequent actions while
publication is pending or uncertain. Reconciliation examines the exact prepared
transaction; it must not replay a purchase under a new ID or silently replace
history without an authorized attempt-discard event. Uncollected loot, unrelated encounter
changes and unearned rewards are not secured by a lifecycle-only publication.

No software can reconstruct an event lost before any storage commit. The design
must distinguish a pending candidate from a completed acknowledged transaction,
not promise recovery of unwritten memory. Existing adapters also do not guarantee
hardware power-loss survival or protection against browser eviction/deletion.
These are storage limits, not permission to roll back verified progression.

Ordered replay must bind existing run/wave identity and clock epoch, because
RETRY/RETURN reset encounter clocks. The current prototype models an ordered
stream, not a live cross-run clock adapter. Exact frozen remaining durations must
be rebased to the new authorized encounter clock without subtracting wall time,
rerolling history or resetting resource expenditure. Any entry/resource/source
combination that cannot be reconciled under existing END/WIS and NEW RUN policies
must fail closed instead of clamping, refilling or silently expiring a modifier.

### Remaining technical/source gates and next step

- Recovery pricing is resolved by the owner; no negative-price gate remains.
- Approve the V3 / checkpoint / receipt / simulation compatibility changes and
  explicit baseline evidence required for old profiles. No migration is performed.
- Implement trusted live mutation/source/receipt attestation and one-generation
  publication before marking irreversible transactions completed. The prototype's
  isolated approval fixtures are not production authentication or crash testing.
- Specify and test exact cross-run resource/effect rebasing using existing approved
  policies. Source-specific resurrection costs, durations and effects still need
  actual verified definitions; no generic resurrection is provided.

Smallest safe next implementation is a separately approved V3 validation and
coordinator extension tested with disposable records, still without auto-migration
or live death. The first live step should follow that approval: one deterministic
mutation-completion boundary with independent life state and durable acknowledgement,
then all action/defeat/target/reward gates. This pass authorizes none of that work.

### Durable-retention validation

- Historical durable-retention validation: **388 assertions passed**,111 added
  over the previous277. That pass's lower-score pricing gate is superseded by the
  recovery-pricing correction below. Existing p.102 ordinary bands are unchanged.
  Tests also cover multiple lethal primaries, modifier preservation, affordability,
  duplicate receipts, stale/false-empty/superseded heads, exact readback, lost
  acknowledgement, frozen/resumed durations, atomic expiry, all five retention
  boundaries and deterministic serialization. No fixture writes a player save.
- Existing evaluator: **205 assertions passed**, unchanged.
- **19 selected suites passed**: new history, evaluator, guarded SS, authoritative
  STR/DEX, both #37B suites, #36A ledger/rewards, #36J-Pass1/Pass2/Pass5, all three
  #36J fixes, #36K-Pass2, both #36L suites, combat actor/action and two-client sync.
- Godot4.7.2 headless import: exit0. `git diff --check` and explicit whitespace
  checks for the untracked implementation/test/document passed. Final logs contain
  no ObjectDB leak or retained-resource warnings. Existing schema12 fixture snapshots
  remain unchanged; production contracts/calculations are unchanged against HEAD.
- No full regression, Web export, real EXPC debit, migration or live lifecycle
  integration was run. The owner retains the full-regression/export checkpoints.

### Recovery-pricing correction verification

The corrected evaluator quotes the permanent layer, with signed from/to values,
rather than pricing an effective temporary penalty. The previous unresolved
negative-price result has been removed. Independent literal fixtures cover every
step from-5 through1 for each of the five lethal primaries, exact multi-point
totals, partial affordability and ordinary price-band crossings. Recovery history
retains source-qualified modifiers and every receipt/death audit identity in its
bound generation. The later lifecycle ruling permits the active character
projection to return to its verified checkpoint upon an authorized attempt discard.

The prototype history format remains version1. Existing isolated records and
positive/zero recovery receipts remain valid; no production profile, Save Contract
V2 or schema12 fixture is changed. Generation proposal/publication/acknowledgement
and external resurrection authorization requirements are unchanged. Profile V3
work remains a proposal requiring separate owner authorization.

Final pricing-correction validation:

- Evaluator: **326 assertions passed** (121 added over205).
- History: **704 assertions passed** (316 added over388).
- **20 selected suites passed**: both dormant lifecycle suites and dormant
  universal attributes; guarded SS; authoritative STR/DEX; both #37B suites;
  #36A ledger/rewards; #36J-Pass1/Pass2/Pass5; all three #36J fixes; #36K-Pass2;
  both #36L suites; combat actor/action; two-client synchronization.
- Headless Godot4.7.2 import: exit0. `git diff --check` and explicit checks of
  untracked implementation/test/document whitespace passed. Final logs contain
  no ObjectDB leak or retained-resource warnings.
- Live catalog, combat, persistence/backup/restoration, Save Contract V2 and
  schema12 code remain unchanged against HEAD. No real EXPC spending, resurrection
  effect, profile migration, full regression or Web export was performed.

## Current death / multiplayer / discarded-attempt contract

This section and the corrected retention text above supersede the earlier
unconditional-retention assumption. The owner-approved pricing, effective-value
barriers, frozen-duration rule and no-automatic-resurrection rules are unchanged.
Everything remains dormant: no scene/controller, live death, reward distribution,
ledger, checkpoint, schema or persistence call is redirected.

### Actual existing boundaries (audit)

- `scripts/ui/arena_combat_controller.gd::_on_encounter_button_pressed` reloads a
  persistent defeated character through `_prepare_encounter_fixture(false)`.
  `PlayableCharacterPersistence.open_verified_history` restores its saved recovery
  entry. This is the current RETRY WAVE path, not an invented match-wide snapshot.
- RETURN uses `_on_return_to_wave_one_pressed`, session
  `get_return_to_wave_one_authorization`, and the verified defeated wave-entry
  reference before `_prepare_encounter_fixture(true, checkpoint)`. It creates a
  new circuit with approved NEW RUN restoration. It is distinct from fixture RESET.
  There is no separately implemented production RESTART/match checkpoint operation.
- `CharacterWaveCheckpoint` v1 binds run/wave/seed, player resources/conditions,
  movement/RNG, roster and ledger; associated profile ownership/equipment state is
  separately validated by the existing projection/persistence code. The prototype
  accepts only an explicitly attested `CharacterWaveCheckpoint/v1`, phase `entry`
  reference. Another meaning of pre-match, or a circuit-wide checkpoint, is NOT inferred.
- `ArenaCombatSession._update_encounter_outcome` remains single-player/HPC-based.
  Its multiplayer mode currently provides an authoritative downtime deadline;
  it is not a complete multi-profile death/party/reward lifecycle. The deadline
  must eventually honor the new dead-member progression gate; it is unchanged here.
- `ArenaRewardLedger` owns one configured player wallet and existing creature/drop
  transactions. No multiplayer reward split is defined here. The prototype observes
  already-authorized per-profile reward receipts; it calculates no new XP/drop formula.
- `TwoClientSyncHarness` verifies two observers of an authoritative simulation.
  Passing those tests is not proof of playable multi-character party persistence.

### Rulebook-confirmed death/resurrection evidence

Actual source: `C:/Users/mxz/Desktop/Projects/ITank Prime/ITank Prime V3.pdf`.
Printed page numbers were checked in the document; p.16 and p.301 were rendered
and visually inspected using disposable files outside the project.

| Printed source | Confirmed requirements / boundary |
| --- | --- |
| p.16, character sheet / Pains of Death | HPC reaching0 normally invokes Pains of Death: permanent STR-1 and END-1. A final B-damage blow causes unconsciousness instead; at HPC-10 or lower Pains of Death still applies. B-unconscious recovery is separately described. Thus HPC<=0 is not sufficient evidence of universal character death. No new HPC/Pains/B-recovery calculation is implemented in this pass. |
| p.301, named RESURRECT | Four described Acts, touch range, corpse dead within72 hours,50 Mana. The printed result is1 HPC,0 Mana/regular daily uses, and the existing blood amount or minimum needed to survive. The listed15,000 EXP is NOT charged as a casting cost by this prototype. Actual entitlement, SS/ability resolution, hands, range, action timing, interruption and resource application still belong to a legitimate source-backed engine action. |
| p.235 and p.257, named variants | The ordinary RESURRECT descriptions also specify four Acts and50 Mana. p.257 expressly retains four Acts for its permitted scroll version. This does NOT establish four Acts for every resurrection effect. |
| p.257, GREAT / GREATER RESURRECT | Their corpse-age and END-cost rules differ; GREAT describes a one-year corpse limit and END-6, whereas GREATER omits that injury. They are not silently treated as p.301 or implemented here. |
| p.300, PHOENIX SPECIAL | Distinct pre-cast self-resurrection: one uninterrupted hour of preparation, active until midnight, a later SS opportunity within its stated window, and source-specific failure/return effects. This is not the ordinary other-character RESURRECT path; it remains explicitly unsupported by the new named-source validator, rather than banned or converted into an automatic resurrection. |

The owner's DEAD-primary <=0 / restoration / effective-eligibility ruling
supersedes p.16's unqualified permanent-death wording for those attributes. Do not
reopen that resolved ruling. The absence of a live Pains-of-Death handler is an
integration gap, not permission to invent extra HPC penalties or assume every
HPC defeat needs2,000 EXPC. A charge applies only to a requested permanent recovery
point; positive-attribute HPC death has no required attribute-recovery charge.

`hpc_death` therefore requires an externally verified, unique causal source record.
It never reads HPC or decides unconsciousness versus death. Future attestation
must resolve the real damage type/Pains/attribute history correctly before emitting
such evidence. Source-specific resurrection completion similarly requires external
exact-content authorization. The new p.301 validator checks named definition,
distinct living caster/target, combat versus between-wave context, completed4 Acts,
50 Mana with exact before/after evidence, corpse age, touch and prerequisite proof.
Unknown variants fail closed. A completed cast action cannot be replayed under a
new authorization ID. No free action, extra turn or resource refill is generated.
This is completion evidence only, not a new resurrection engine or resource resolver.

### Notification and explicit decisions

`death_notification(history, authority)` is a deterministic read-only presentation
record: cause class/event, lethal attributes, current barriers, permanent/effective
scores, one-point costs, exact total/partial affordability, and personal EXPC.
It states that spending does not resurrect and that the ordinary party path needs
another character's legitimate effect. HPC death with no attribute loss has no
recovery option/fee. The record offers Not Now, revisiting, spectating and no forced
countdown. It creates no live controls.

`restoration_decision` records an explicit owner-profile request. Not Now changes
no balance. Restore One checks affordability and pins attribute/value, own balance
and causal death ID. In a modeled attempt, a receipt requires that exact pending
decision, then consumes it once. A teammate cannot authorize spending this wallet.
Legacy isolated receipts remain already-completed externally authorized records;
they are not a new command path or permission to bypass player consent in gameplay.

### Attempts, discard and exactly-once accounting

| Event | Isolated contract behavior |
| --- | --- |
| `attempt_begin` | Requires alive membership, a unique attempt ID and a separately authorized actual entry reference matching profile/run/wave/generation/digest and current history head. Captures the current lifecycle projection and an externally validated ownership/resource snapshot. No new interpretation of match versus wave is supplied. |
| `owned_state` | Observes an exact-before / externally authorized-after equipment/inventory/resource projection. It does not define new item stats, create instances or implement consumption/damage rules. |
| `wave_outcome` | Records one verified team victory and freezes whether THIS participant was alive at completion. Later between-wave resurrection cannot retroactively qualify a dead-at-completion player for rewards. |
| `reward_receipt` | Requires that recorded eligibility and current life; observes a unique already-authorized personal ledger/ownership result. Dead participants cannot receive XP/EXPC, currency, drops, loot or other completion rewards through this path. No payout amount or split is invented. |
| `attempt_commit` | Secures a living successful participant's projection. Subsequent personal failure of someone else cannot reach it. A successful living attempt also cannot be discarded through a teammate's retry request. |
| `attempt_rollback` | An authorized RETRY/RESTART/failed RETURN, dead departure after victory, or final-wave dead outcome restores that exact attempt baseline: attributes (including losses classified permanent), life, EXPC, inventory, equipment condition, resources and temporary state. It does NOT resurrect through an effect; it discards a failed attempt. Pre-checkpoint purchases/progress remain. |

Rollback APPENDS an event and identifies cancelled purchase IDs; it does not delete
old events, receipt IDs, decisions, action evidence or processed identities. The
active wallet/life/ownership projection is restored, but those spent IDs remain
unusable even in a later attempt. A second rollback fails because the attempt is
closed. Reconciliation recognizes the exact recorded cancellation rather than
issuing another credit. A genuinely new attempt requires new authorized requests.

Generation/head publication stays monotonic. A lower NET spent projection from a
discard is authorized by its checkpoint/cancellation event, not by replacing history
with an older generation. Interrupted acknowledgement retains the preceding verified
head until exact readback; lost acknowledgements reconcile the same transaction.
The prototype never calls a wallet, storage adapter or live character.

### Party policy and mixed outcomes

`party_view` reads independently authorized profile histories and checks matching
party/wave/outcome/namespace context. Living teammates continue while a dead member
spectates with restoration access. On verified victory, dead members remain dead
between waves. NEXT WAVE is blocked until they are legitimately resurrected or
leave. Their recorded reward exclusion survives a later resurrection.
The separate current reward-participation flag excludes dead players from kill,
drop and collection participation during combat too. These are policy predicates,
not complete action permission: existing timing, phase and item rules still apply.

A dead departure after victory stages that profile's checkpoint rollback and marks
them left; teammates' histories/generations are untouched. For final-wave victory,
the dead member instead requires personal rollback and receives no completion
reward. A post-final resurrection window is not invented. Candidate departure must
not alter a playable party until publication acknowledgement; this pass returns
only candidate/view data. No countdown forces recovery, spending or resurrection.

### Persistence compatibility and remaining gates

Current coordinator continuity requires immutable purchases/receipts and monotonic
spent XP. It cannot accept the new cancellation semantics as an ordinary V2 save.
The proposed future version must retain all immutable transaction records and add
explicit attempt/checkpoint scope plus cancellation references, deriving net EXPC
and ownership from active versus discarded transactions. Never erase processed IDs,
subtract a second refund, or cancel anything before the referenced checkpoint.

Reuse existing compare-generation, Web Lock/single-writer protection, atomic browser
publication, exact readback and reconciliation. A profile generation must bind its
attempt disposition, life history, ownership and net ledger together. Existing
backup/restore comparisons must reject stale/divergent histories containing different
dispositions; preview/import cannot replay a cancellation as new money.

Personal departure publishes only that profile. A team-wide RETRY/RESTART needs
per-participant checkpoint/expected-head evidence and recoverable cohort completion;
current storage does not provide a production multi-profile atomic retry. Do not
pretend two-client observer convergence supplies that facility. Actual multi-party
admission, roster changes and cross-profile action-cost attestation remain absent.

Save Contract V2 and simulation schema12 are UNCHANGED. No production migration,
new save field, live UI, live reward gate or resurrection action is introduced.

Final owner ruling: an all-party wipe is DEFEAT, including the final enemy dying
in the same exchange. Enemy defeat cannot authorize victory rewards or advancement
before that exchange closes. Authorized RETRY/RESTART restores the explicit
checkpoint through an audited cancellation; pre-checkpoint progress remains intact.
This supersedes the earlier unsupported mutual-wipe result. The prototype still
cannot reinterpret an undefined future match-wide checkpoint; current
evidence identifies only the established wave-entry boundary. Phoenix and other
resurrection definitions need separate source-qualified integrations, not a new
universal action count.

Smallest next safe step: owner review of this checkpoint/disposition design.
The all-dead outcome is resolved. Then separately authorize validation/coordinator
support with disposable records and explicit cancellation accounting. Live death,
multiplayer gating and production Profile V3 remain outside this pass.

### Death/multiplayer lifecycle validation

- New suite: **224 assertions passed**. Covers notices/costs, explicit personal
  decisions, Not Now/revisit, insufficient funds, multiple lethal primaries, dead
  participation/reward exclusion, combat and downtime source-specific completion,
  incomplete Acts/Mana/touch/age/prerequisite rejection, no repeated cast action,
  no retroactive rewards, survivor isolation, RETRY/RESTART/failed RETURN rollback,
  owned-item/resource restoration, pre-checkpoint progress, personal departure,
  final-wave failure, HPC classification, stale heads, uncertain publication,
  exactly-once cancellation and replay/serialization. The later Profile V3 pass
  replaces the old mutual-wipe gate with the owner's defeat ruling.
- Existing evaluator: **326 assertions passed** without changing its implementation.
  Existing history suite: **704 assertions passed**; superseded unconditional-retention
  expectations now require an explicit discard instead. Dormant universal engine
  coverage passed. All other live systems remain untouched.
- The affected ledger/advancement, persistence/backup, combat, guarded SS, STR/DEX,
  synchronization and five-wave framework suites passed. One initial suite-filter
  typo matched no suite; the corrected five-wave filter ran successfully. No full
  regression or Web export was run.
- Final selection: **22 suites passed**. Godot4.7.2 headless import returned0;
  `git diff --check` and explicit untracked-file whitespace checks passed. Final
  successful validation logs contain no ObjectDB leak or retained-resource warnings.
- Rulebook p.16 and p.301 were visually checked; variant p.235/257/300 text was
  independently read. No manuscript or owner save was written. Full regression
  and Web export remain owner-run checkpoints; no live multiplayer acceptance is
  claimed for these isolated contracts.

## Profile V3 compatibility pass

The separately callable `ProfileV3Compatibility` prototype validates immutable V2
anchors, the lifecycle extension, typed receipt links, closed party exchanges,
progression/run gates and simulated exact publication acknowledgements. It does
not replace production Save Contract V2 or register a gameplay storage route.
See [PROFILE_V3_COMPATIBILITY_PROTOTYPE.md](PROFILE_V3_COMPATIBILITY_PROTOTYPE.md)
for the exact body, trust boundary, generation offset, legacy preservation and
explicit multi-profile atomicity blocker. No production migration is implemented.
