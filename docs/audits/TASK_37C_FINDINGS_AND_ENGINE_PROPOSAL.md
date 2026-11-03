# Task 37C findings and universal attribute engine proposal

Audit only. Baseline main at 22cbcd349bb78f89ca871858554b5c3e91faaec9.
Status: AUDIT READY FOR OWNER REVIEW; no live integration authorized.

Current ruling status: PAR/limits, negative DEX/MAN allocations, temporary ToF,
Arena RR/W, and permanent/temporary WIS Mana behavior are resolved by the owner.
Permanent WIS increases grant +1 Mana Max per +1; permanent losses and temporary
changes cause no immediate Mana Max/current Mana changes. Prior growth remains
authoritative; future growth uses applicable event-time WIS. All source snapshots
and checksums remain unchanged. The next required ruling is the treatment of
effective derived lower bounds after encumbrance/armor (now resolved: signed
DT/DP, zero MR floor). The owner has resolved
whole-pound encumbrance thresholds as floor(E/10)+1 for MR and floor(E/20)+1
for both dodges when E>0, zero at E=0. See the owner-rulings documents
and the 47-row terminology table for exact policy details and historical questions.

## Deliverables and verification

`TASK_37C_VERIFIED_SOURCE_CATALOG.json` is the new, separately hashed source
revision. The previous partial extraction and checksum are preserved unchanged.
Both modes cover scores 0-35 in all nine printed primary columns, with MAN's
separate approved allocation policy recorded explicitly. All four chart pages
(53-56) have been visually reviewed; wrapped Regular WIT 25 is 13-11-17.
`*` means unlimited; DEAD is a boundary outcome, not a numeric zero tuple.
Never extrapolate beyond 35 or grant immortality from a high numeric score.

The HTML comparison contains every source chart entry, component labels,
definition pages and per-primary implementation classification. It is a local,
self-contained owner review document, not game UI.

Independent automated comparison: 192 scalar comparisons passed. These comprise
60 STR component values against each of the two printed modes (120 total), and
36 DEX ACC values against each printed mode (72 total). Expected values came
from the book transcription, not from the code. No shared table exists to test
for the other primaries; authored examples are not universal formula proof.

## Confirmed erratum

Designer-confirmed manuscript erratum, V3 pp. 27 and 67: Time Sense modifiers at
SI 1,2,3,4,5 are -2,-1,0,+1,+2. Each additional investment adds exactly +1.
The p.67 worked jump to zero is not an exception. Preserve separate asterisk
automatic-skill rules and explicitly established exceptions. This resolves
SKILL-INVESTMENT-001; it changes documentation only in this pass.

## Existing implementation comparison

| Area | Classification | Exact implementation and consequence |
| --- | --- | --- |
| Primary storage | MATCH representation / MISSING universal derivation | `CombatCharacterDefinitionResource.attributes` and `CombatActorDefinition.attributes` store all ten primaries. `combat_stats` is predominantly authored separately, not computed from them. |
| STR | MATCH supported range | `PrimeV3StrengthChart.derived` matches all three printed fields at 1-20. `CombatActorDefinition.apply_verified_strength_advancement` validates prior values, applies +1 and SB/PPG/MWC without refilling resources. Higher chart rows are unavailable, not automatically incorrect. |
| END | MISSING shared lookup | Authored NAL/PS/HPB feed combat and growth. No general END recalculation or purchase exists. Racial NAL and location TAL must remain separate from the END lookup. |
| SPD | MISSING shared lookup | Authored MR/AT feed movement and Act scheduling; no general SPD chart lookup/purchase. Do not replace approved continuous 5/AT timing. |
| DEX | MATCH / PARTIAL integration | `PrimeV3DexChart.accuracy` matches all 0-35 entries. `DexAllocation` conserves points with confirmed/pending/source records. `CharacterDevelopment.starting` explicitly supports the approved pool9/DT6/DP3 starter policy; this is not a universal rule for every entity. DEX buying remains disabled. Negative temporary DEX is gated. |
| WIS | PARTIAL | SS/Mana are authored. `CharacterLevelProgression.growth_terms` computes floor(WIS/2)+5 for Mana level gains. Shared SS/MSL/MR/H derivation and WIS purchasing are missing. |
| INT | MISSING shared lookup and budget | S#/SCM/MIUR appear in supplied Vaelis JSON but are absent from her live combat statistic definition. Running has a separately authored SCM profile. Do not infer that SCM belongs to END because Running does. |
| WIT | PARTIAL | Authored INIT is used. General MNS/MRF/RCL calculation absent; MNS is a count of individual nonautomatic Specials while MRF counts fields. Never merge their meanings. |
| MAN | MISSING | MAN stored; persuasion AP/KP are not registered live combat stats. New owner-approved allocation design remains unimplemented. AP persuasion and Ability Points need distinct internal identifiers. |
| LUK | PARTIAL | Consumers use authored RB, but general lookup, RR/G and ToF entitlement accounting are absent. ToF is historical/consumable, not a scalar to overwrite on recalculation. |
| APP | MISSING implementation / source clarified | No shared PAR/CHA calculation; source excludes APP from ordinary EXPC purchasing. Owner confirms printed PAR through 18: values above 10 are supernatural attraction, without invented extra mechanics. |
| XP prices | MATCH existing accepted policy | `PrimeV3AdvancementCatalog.attribute_cost` implements all six p.102 brackets using current value. Zero is unavailable, APP excluded. STR and SR supported; other attribute purchases remain gated. Costs do not grant training, anatomy, cap or equipment permissions. |
| TB name | MISMATCH terminology | V3 p.24 says Tolerance Bonus. Catalog uses `talent_bonus` and ledger text repeats Talent Bonus. This does not establish a wrong current numeric award; rename/migration must be separately scoped because purchase identities may use that identifier. |
| Temporary values | PARTIAL | `CombatSimulation.get_effective_actor_combat_stat` applies supported direct modifiers and DEX lookup/allocation. It is not a universal primary-to-derived recalculation engine. Source-specific Rage SB/NAL/DT/DP modifiers must not be recast as a STR bonus. |
| Equipment eligibility | PARTIAL reusable foundation | `CombatDefinitionCatalog.validate_equipment_strength` checks weapons, shields and armor; hand occupancy and one-/two-hand thresholds are separate. Current checks read permanent actor STR; a future general effective-attribute interface must be validated before supporting temporary STR equipment eligibility. No gear is granted by advancement. |
| Saves and history | MATCH current scope / future blocker | Projection replays STR/SR purchases and validates growth with recorded rolls. It currently applies purchases before validating all growth against actor HPB/WIS. END/WIS purchases cannot be added by simple dispatch: historical growth must retain the attributes applicable at its original event. This is a future integration blocker, not evidence that accepted STR saves are corrupt. |

Authored creature/Guard statistics can be explicit source exceptions. They must
not be silently replaced by player character-creation charts. This audit does
not claim to revalidate every individual creature sheet; protected DOCs were
not opened. No new character-specific formulas were introduced.

## Vaelis

Permanent authored MAN 0; supplied base persuasion AP/KP 0/0; sum equals MAN.
Standard 50/50 would therefore produce the same numbers. Live effective AP/KP
are unavailable, not verified as a computed 1/0. Printed p.22 STR9 modifier is
+1 to the persuasion roll; INT5 modifier is zero. This modifier is separate
from allocation and from the Ability Point resource. Historical saves remain
uninspected and unchanged; no new baseline is imposed on old profiles.

## Proposed reusable engine

1. A frozen source-table resource, generated only after owner approval from the
   independently hashed catalog. Lookup keys include chart mode, primary,
   score and derived identity. Represent unlimited/dead/unsupported outcomes
   explicitly; never encode them as guessed integer maxima.
2. A pure evaluator accepts permanent primaries, independently identified
   temporary primary contributions, direct derived modifiers, mode and explicit
   source exceptions. It returns values plus provenance or an unsupported reason.
   No RNG, I/O, actor mutations, grants, resource restoration or UI decisions.
3. A reusable allocation ledger supports DEX and MAN with distinct semantic
   field identifiers. Preserve authored historical baselines; append only new,
   authorized grants/confirmations. No respec or duplicate receipts. MAN temporary
   points are automatically split, unlike permitted DEX-specific customization.
4. Proposed MAN tie-break for owner review: distribute equal halves, put an odd
   point on the otherwise lower side; if tied, use a stable SHA-256 parity of
   namespace/profile/pool/source/activation identity. Persist the chosen
   source-qualified contribution. No combat RNG or repeated reassignment.
   This proposal is not an implemented or additionally approved rule.
5. Advancement prepares a candidate, validates XP, source range, allocations,
   derived deltas and equipment, then atomically commits through the existing
   ledger/session authority and persistence checkpoint. Maxima changes never
   refill current HPC/Mana/AP. Historical HPM rolls are never repeated.
6. Equipment penalties, racial modifiers and direct Special effects retain
   independent provenance and location applicability. Do not bake torso TAL
   into universal NAL or repeatedly apply penalties after recomputation.
7. Save Contract V2 and schema12 remain unchanged now. Future extension requires
   explicit validation of any optional development/history revision across
   projection, hydration, checkpoint, backup preview/restoration and clients.
   Do not hide fields in unrelated properties or silently reinterpret old saves.

## Remaining rulings and gates

These are not resolved by choosing convenient formulas. Stop before integrating
the affected behavior.

- **RESOLVED PAR clarification:** p.23 defines the normal racial standard;
  printed PAR 11-18 represents supernatural attraction. Use every printed value
  without capping at 10 or granting extra mechanics. Owner also confirms the
  distinct 20/25/Immortality eligibility boundaries; chart presence is not permission.
- **RESOLVED negative allocated pools:** owner-approved Arena rule reduces the
  currently higher side point by point, breaking ties DT before DP / persuasion
  AP before KP, never below zero. Temporary effective reductions leave permanent
  history intact; permanent losses require validated event-time history. Runtime
  support remains missing, and undefined later recovery is not authorized.
- **RESOLVED temporary Luck policy:** owner authorizes separate temporary ToF
  grants with source-qualified spending history, expiry of unspent grants and
  no same-source regeneration of spent grants. Arena RR/W replaces the book's
  RR/G cadence only for its own allowance: automatic first eligible critical
  failure reroll, no replacement chain, no false refresh within a wave. See the
  terminology/Luck record for complete conditions. Runtime and durable ledger
  support remain missing; no spendable points are generated in this audit.
- **Changing growth attributes:** the historical event-time HPB/WIS ordering
  must be representable and validated before END/WIS advancement. Owner resolves
  permanent WIS10->11 as immediate +1 Mana Max, current Mana unchanged, with all
  earlier level gains unchanged. Owner further excludes temporary WIS from Mana
  Max/current Mana changes entirely, including expiry. Permanent WIS reductions
  also leave both existing Mana values unchanged and affect future growth only.
  Event-time history support remains a missing implementation, not a rule gap.
- **RESOLVED whole-pound encumbrance thresholds:** owner specifies zero at MWC;
  for E>0 use floor(E/10)+1 MR penalty magnitude and floor(E/20)+1 for DT/DP.
  Effective modifiers only, removable with excess weight. No item weights are
  invented. Owner separately resolves lower bounds: DT/DP remain signed,
  without an extra die penalty; effective MR has a zero floor. Confirmed
  allocations remain unchanged. Existing resolver/movement arithmetic matches
  those bounds; general encumbrance integration still remains missing.

## Smallest next passes after owner approval

First authorize only a dormant universal lookup module and exhaustive source
comparison tests: all 0-35 rows, both modes, dead/unlimited/out-of-range results,
and six price boundaries. Do not change fixtures or replace live calculations.
Then separately authorize allocation/temporary-effect integration once its
policies are settled, followed by one primary purchase at a time with event-time
history, no-refill, equipment, duplicate-command, save/backup and replay tests.
No broad combat refactor is required or authorized.

Proposed signed-value pipeline: validate permanent allocations and their
nonnegative point conservation separately; derive effective contributions, then
add legitimate direct derived modifiers exactly once. Preserve signed DT/DP
through later modifiers and ordinary/critical resolution. Clamp only effective
MR at zero under the approved rule. Do not extend that floor to unrelated stats.
Keep source-specific Immortality permissions and costs/conditions explicit; see
the terminology/rulings document for printed pp.64,141,146,253,258,269 evidence.

### WIS implementation planning boundary

Reuse recorded `wisdom`, `maximum_before`, `maximum_increase` and `maximum_after`
in growth records. The current hydrator applies purchases first, then checks all
growth against actor WIS/HPB. That is insufficient for interleaved WIS purchases
and older gains. A future pass must validate historical attribute applicability
against authoritative progression history, not merely trust an edited numeric
record or substitute the final actor WIS. Stable transaction identity must debit
EXPC and grant the permanent maximum delta exactly once through the existing
coordinator. Candidate reconstruction must separate starting maximum, historical
growth and purchase contributions, then compare the resulting saved maximum.
Do not partially hydrate on failure or migrate unprovable histories. Existing
source-locked legacy WIS histories must remain compatible where provable. No
save format or implementation change is selected or enabled here.

Temporary WIS must remain separate from the permanent Mana accounting inputs;
the generic temporary-primary-to-derived pipeline must not emit Mana Max or
current Mana deltas from it. A future implementation needs focused checks for
activation, overlapping sources, expiry, reload and replay proving zero Mana
mutation from temporary WIS alone. Historical level-gain validation remains a
separate required transaction/history change, not a reason to refill resources.

The permanent-loss ruling makes Mana accounting intentionally asymmetric.
Calculate validated positive permanent WIS contributions from their grant
history, never from net current WIS minus starting WIS. Retain loss events for
the WIS applicable at later level gains. Existing hydration cannot be extended
by simply using final WIS; it must validate event-time applicability and grants
without rerolling, duplicate maximum increases or invented historical values.

## Validation performed

Visual source review, row coverage, independent table comparisons and checksums.
No gameplay suites, Godot import/startup or Web export were run: runtime files
were not changed. Existing tests passing previously are not new evidence here.
Owner saves, downloaded backups and protected files remain untouched.

## Final independent audit review on 3 November 2026

PASS: the PDF was read afresh with pypdf layout text, independently from the
prior pdfplumber table extraction, and pp.53-56 were visually inspected again.
All 648 catalog cells match, including the wrapped Regular WIT25 cell. No chart
correction is required. Only WIS/WIT numeric columns differ by mode. There are
nine printed numeric primary columns; MAN is the tenth primary, governed by the
owner allocation rule rather than an invented tenth chart. Fresh source also
revalidated the 47 terminology names and regenerated all 192 STR/DEX scalar
comparisons. Frozen source/checksum files were not rewritten.

Resistances are a first-class independent category: SR and TB have no primary
formula. Sources, reactions, tolerance-check application, price gates, explicit
Arena SR automation and safe talent_bonus label correction are detailed in the
consolidated terminology/rulings document. Representation/advancement support
is not proof of implemented general SR or toxin-resolution gameplay.

FAIL (implementation completeness, not a failed regression): most universal
primary lookups, MAN mechanics, negative allocation integration, Luck ledgers and
general Resistances consumers are missing. TB terminology is wrong in the legacy
purchase identifier and ledger text. No identifier is renamed during this audit.

First proposed authorized phase: a dormant pure lookup/descriptor module covering
all printed primary charts plus an independent Resistances descriptor; exhaustive
fresh-source comparison tests, explicit DEAD/unlimited/out-of-range results and
no live call-site replacement. Character Sheet architecture reads authoritative
admitted state into four categories: Primaries, Derived Attributes, Resistances,
Resources, with source provenance and unavailable values represented honestly.
No UI mutation, XP purchase, RNG draw, save write or resource refill is permitted
from inspection. Read-only display alone requires no save migration.

Later live integration requires owner approval. Strict V2 development validators
currently accept the DEX record, not an arbitrary MAN/Luck record: adding durable
fields needs an explicitly supported, tested optional revision or migration
plan across projection, hydration, checkpoints and backup restoration. Schema12
must not be silently changed. Event-time HPB/WIS histories must be validated
against their original state, not final attributes. Legacy authored NPC exceptions
and independently owned equipment remain source-qualified overrides; a universal
engine must not regenerate them as new player characters.

Resolved questions are not reopened. Remaining unsupported TB zero-price,
fractional-weight, incomplete weight data, permanent recovery and future reroll
interactions are listed as gates, not guessed mechanics. All applicable approved
rulings take precedence over historical interpretive prose in the immutable source
snapshot. No new rule is needed merely to begin the proposed dormant phase.
