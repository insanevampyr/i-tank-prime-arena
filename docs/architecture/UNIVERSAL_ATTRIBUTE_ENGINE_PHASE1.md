# Universal attribute engine Phase 1

Phase 1 introduced dormant rules queries; Phase 2A/B added isolated inspection.
Phase 2C now delegates only the existing STR helper to the engine, preserving
exact results and contracts. Earlier phase boundaries below describe their
historical scope. Save Contract V2 and simulation schema12 remain unchanged.

## Interfaces

`PrimeV3AttributeEngine.lookup(primary, score, mode)` accepts the exact primary
abbreviations and `mana`/`regular`, with integer scores 0-35. Unknown modes,
attributes (including CON), types and scores fail closed. It returns fresh data
with printed page/cell and tagged derived values: integer, unlimited, dead or
allocation_required. DEAD is a source boundary, not an executed actor-death
operation. Unlimited is never replaced with a numeric sentinel. Eligibility
metadata at 21/26 does not grant a Special, item, Immortality or purchase.

STR/END/SPD/DEX/WIS/INT/WIT/LUK/APP use exact printed columns. DEX only prints
ACC; DT/DP remain allocation-required. MAN has no fabricated numeric table:
its AP/KP allocation descriptor preserves the owner-approved model, locked
history, balanced standard starting policy, separate temporary contributions
and higher-first negative-allocation policy. No points are assigned or granted.
The positive odd-point tie-break remains a documented policy requirement, not
an unapproved automatic selection. Existing authored exceptions are not replaced.

`primary_descriptor`, `derived_descriptors` and `allocation_descriptor` expose
names, relationships and applicability. Mana WIS includes MR/H, Regular does
not. Mana WIT uses MNS; Regular uses MRF. Printed RR/G remains RR/G in source
queries; Arena RR/W automation is not implemented. ToF table entries do not
grant, replenish or spend entitlement. These queries do not perform event-time
resource growth or temporary-effect integration.

`resistance_descriptor(SR/TB)` exposes independent Resistances, with no governing
primary, generated value or purchase permission. The dormant `purchase_label`
mapping labels `talent_bonus` as Tolerance Bonus while preserving the original
storage identifier. No existing live label or saved receipt is rewritten.

## Independent verification

Runtime table literals were transcribed from the fresh pypdf text extraction of
the actual PDF pp.53-56 used during final audit verification. The exhaustive
test reads the separately frozen pdfplumber-based source catalog under
`docs/audits/TASK_37C_VERIFIED_SOURCE_CATALOG.json`, verifies its original SHA-256,
and obtains expected cells, component ordering and derived names from that audit
fixture. It does not generate expectations from the runtime constants. The
wrapped Regular WIT25 cell is explicitly 13-11-17 in the verified reference.

The registered `Task 37C dormant universal attributes` suite compares all 648
printed cells and 1,620 components, plus all ten primary descriptors, complete
mode-specific derived lists, allocation policies, Resistances, source boundaries,
invalid inputs, fresh-result isolation and simulation/RNG purity. Existing STR,
DEX and purchasing code remains intact during this transition phase.

## Scope boundary

No actor mutation, costs/pricing, history application, persistent state, resource
restoration, entitlement activation, live integration, save migration or Character
Sheet interface is added. A caller receives rules data, not authorization to
change a character. Phase 2 requires explicit owner authorization.

## Phase 1 validation

Nine focused suites passed: Task 37C, both Task 37B suites, both Task 37A suites,
Task 36B, character projection (Task 36J-Pass1), physical defense and two-client
synchronization. Final headless import and `git diff --check` passed. No full
regression or Web export was run. Keep the independent audit JSON and its
checksum with the tests when the owner eventually checkpoints these files.

## Phase 2A — isolated character attribute projection

`CharacterAttributeProjection.project(actor_dictionary, mode, state_dictionary,
effective_stats, authored_exceptions)` accepts existing actor/state snapshots and
an explicit `mana` or `regular` reference mode. `project_actor` provides the same
read-only operation for CombatActorDefinition/CombatActorState. Neither entry
point reads a simulation, initializes a character or calls a live stat resolver.
The caller must supply any effective values from the existing authority.

Output separates identity, Primaries, Derived Attributes, Resistances and
Resources. For each derived field, authored base, stored calculated value,
equipment modifier, supplied effective value, recorded permanent allocation and
V3 reference remain distinct. Numeric comparisons use **base versus reference**,
never equipment-adjusted/current values. `different` is evidence of a numeric
difference, not a diagnosis that authored character data is wrong. Optional
exception annotations are explicitly caller-supplied descriptions, not proof of
permission or correction instructions. Field-source provenance is copied intact.

All ten primary scores and all mode-specific derived descriptors are covered.
Only explicit existing field mappings are read as authoritative derived stats;
unmapped skill/field/persuasion/entitlement values remain unavailable. In
particular MAN AP is never read from the Ability Point resource `ap`. The API
does not compute temporary primary values. Positive, negative or absent effective
derived values are reported only as supplied; signed DT/DP are not clamped.

Absent primary/derived values produce tagged unavailable entries and
`complete=false` (coverage of stored primaries/base derived stats/resistances,
not permission to use the character). Missing state/resources/effective inputs
are separately tagged unavailable and never refilled. Malformed data, unsupported
scores/types/modes, mismatched actor/state identity, inconsistent development
records and object-bearing/non-data inputs fail closed without partial output.
Validated DEX records can describe their recorded split; no missing DEX/MAN
allocation or Luck allowance is invented. DEAD/unlimited remain reference tags.
HPC/current resources, daily allowances and damage shields are copied separately;
neither Shield protection nor historic HPM growth is treated as chart-derived HPC.

The focused projection suite compares 648 cells and all their components against
the independently frozen/hash-verified audit fixture. It covers Vaelis, Guard,
authored Goblin, both chart modes, legacy/current DEX records, missing/invalid data,
explicit differences, spent resources, independent SR/TB and output isolation.
Repeated inspection preserves complete simulation snapshots/events/RNG draws;
inspection of only one same-seed client leaves the two snapshots equal.

Observed base/reference differences in the current fixtures: Guard NAL1 versus
END-chart NAL2, Goblin SB0 versus STR-chart SB1; Vaelis has no differences among
the mapped numeric base fields. These authored values remain authoritative and
unchanged; no source exception was silently converted into a chart calculation.

No UI, live caller, purchase, recalculation, save field, migration or authoritative
redirect is added. Save Contract V2 and simulation schema12 remain unchanged.
Further shadow/live integration requires separate owner authorization.

## Phase 2B — explicit combat boundary diagnostics

`AttributeShadowComparison.capture(simulation, modes, exceptions)` is an opt-in
development/test entry point. Modes explicitly map existing actor IDs to `mana`
or `regular`; exception annotations are source descriptions supplied by the
diagnostic caller, never inferred from character names. The registered shadow
test calls it after real ArenaCombatSession initialization and after completed
combat test steps. No session, action, tick, movement, UI, event or persistence
hook calls it automatically. There is no production logging or report storage.

The boundary reads each requested actor/state and the existing read-only
`get_effective_actor_combat_stat`, then reuses the Phase 2A projection. It never
uses chart references as effective inputs. Reports distinguish exact base/chart
matches, numeric mismatches, explicitly annotated authored exceptions, missing
comparisons and nonnumeric/allocation-dependent references. An annotation does
not hide the numeric difference and a mismatch never labels gameplay defective.
Guard NAL1/chart2 and Goblin SB0/chart1 remain approved authored data.

Stored base, stored calculated, equipment, source-qualified temporary effects,
recorded allocations and supplied runtime effective values remain separate.
Registered defense/protection profiles are copied for inspection; location TAL,
racial NAL and damage-type responses are not collapsed into END-chart NAL. SR/TB
remain independent, without a derived-chart comparison. Encumbrance is explicitly
unavailable as a separate verified weight ledger; no zero-weight assumption or
new penalties are created. The report does not recompute final ACC, SS, initiative,
damage, Dodge geometry, Running, resource history, or entitlements.

Missing actor/mode/primary/provenance stops capture with a diagnostic failure;
missing derived values remain unavailable. This failure affects only the caller's
report, never combat permission. Capture requires existing `attributes` and
`combat_stats` source descriptions and does not grant unverified provenance.
Work is bounded to 32 explicitly requested actors, 64 effects per actor and 512
inventory/history/development records per inspected collection. These limits are
diagnostic budgets, not gameplay capacities. Capture does not copy full encounter
logs or attach to recurring callbacks. Long histories outside the budget require
a separately scoped diagnostic, not arbitrary truncation.

`compare_legacy_lookups()` is a separate fixed 192-comparison query over old STR
1–20 and DEX ACC0–35 helpers in both modes. It records both values and comparison
classification, without actors or combat calls. Independent chart correctness
remains covered by the hash-verified Phase 1/2A source-fixture tests.

Integration audit anchors: `CombatActorDefinition.apply_equipment_stat_modifiers`
separates authored base from equipment; simulation `get_effective_actor_combat_stat`
adds development/timed effects, while initiative, SS, some reaction ACC and MR
consumers also read definitions directly. Therefore no getter replacement is
safe as a global integration shortcut. Existing defense planner, final legality,
damage pipeline and separate Running model remain authoritative and untouched.
The test-only boundary observes these existing results without changing any of
their inputs, event timing or source-qualified exceptions.

No persistent fields, save/backup changes, network messages or snapshot fields
are added. Save Contract V2 and schema12 remain unchanged. Read-only capture has
no reference to storage services. Future authoritative replacements still require
individual owner approval and the compatibility/history work in the Phase 2 plan.

Phase 2B validation: eight focused suites passed (shadow, projection, dormant
engine, both #37A suites, physical defenses, prone combat and two-client sync).
Enabled/disabled real Guard/Vaelis duel sessions produced identical complete
snapshots and synchronization digests; repeated same-seed runs matched. The
isolated existing leveled/purchased profile produced the exact same canonical
save envelope before/after capture, with damaged Shield SHP retained. No storage
operations were invoked. Headless Godot 4.7.2 import and whitespace checks passed;
final logs reported no ObjectDB leaks or retained-resource warnings. A native
headless sample of ten explicit three-actor captures took 24,166 microseconds
total (about 2.42ms per capture). This is not browser frame-time evidence or a
claim of gameplay performance improvement. Full regression/Web export remain
owner-run checkpoints; no live automatic diagnostic invocation is enabled.

## Phase 2C — one authoritative STR lookup boundary

Baseline main `19ac972`. Selected `PrimeV3StrengthChart.derived(strength: int)`;
DEX ACC remains unchanged. The STR helper is called for approved permanent STR
purchases, previews and hydration, not for general combat-time recalculation.
DEX has additional active temporary-ACC/allocation consumers, so STR is the
narrower first boundary. Neither helper should regenerate authored creature stats.

Pre-change comparison proved 120 scalar matches: STR1–20, SB/PPG/MWC, both printed
Mana/Regular columns. Only the value source is replaced: the helper delegates
to `PrimeV3AttributeEngine.lookup("STR", strength, "mana")` and adapts integer
components back to the same `success/sb/ppg/mwc` dictionary. Both printed STR
columns agree; this fixed reference mode does not reclassify the character.
The same typed int argument, 1–20 guard and exact failure dictionary remain.
Chart scores0/21–35, magic/Immortality permissions, prices, source-mismatch gates,
equipment requirements and resource state are not newly admitted or changed.

The original `ROWS` constant is frozen in place. The previous three-statement
implementation is preserved in `tests/test_task_37c_authoritative_strength.gd`
as `legacy_derived`, with exhaustive complete-return/source comparisons. Rollback
requires only restoring `derived()` to that body and removing its unused Rules
preload; no saves, receipts, authored definitions or source snapshots need changes.
The Phase 2B STR diagnostic now compares the current helper against the universal
reference; independent old-versus-new evidence comes from this frozen legacy
implementation and the independent source catalog, not from that diagnostic alone.

New focused coverage checks 120 source components, identical whole dictionaries,
invalid integer boundaries, unchanged public argument/return types, output
isolation, the STR11→12 SB threshold, independent temporary SB, spent resources,
RNG/events and authored Guard/Goblin exceptions. Both source-catalog files and all
attribute-engine/table files remain untouched.

A separate isolated native replay was captured before editing the helper and
repeated after replacement. It exercised existing #37B purchase transactions
and actual Guard/Vaelis ArenaCombatSession movement/attack/defense pipelines,
including two-client digest assertions. Canonical outputs matched exactly:
SHA-256 `91007a3d981502a7f032528ff0f682e96ea02a22899050f803c35c79f959f9f0`.
The temporary diagnostic outputs were written outside the repository and player
save directories. No legacy-provider switch was added to production gameplay.

Further DEX integration remains separately gated. END/WIS history, MAN/Luck
entitlements, general encumbrance and new character-development operations retain
their prior approval/compatibility boundaries; this change enables none of them.

Phase 2C validation: fifteen focused suites passed: the new authoritative STR
suite; projection/dormant engine; both #37B and both #37A suites; character profile
projection; backup export/preview and restoration; native playable-browser
persistence tests; inventory/equipment; physical damage; two-client sync; equipment
foundation. Headless Godot 4.7.2 import and whitespace checks passed, with no
ObjectDB/retained-resource warnings in these runs. Desktop playable persistence
is exercised by #37B; native browser-adapter coverage does not establish new real
browser acceptance. Full regression and Web export remain owner checkpoints.

Owner-confirmed Phase 2C metadata correction: chart references use manuscript
printed pages 51/52 for Mana scores 0–20/21–35, and 53/54 for Regular scores
0–20/21–35. APP, PAR and CHA definitions use printed p.24. Exact terminology and
all chart values are unchanged. Frozen audit catalogs/checksums retain their
historical page metadata; tests continue using their independent numerical
evidence while asserting corrected printed references separately. These
corrections supersede the old page-number descriptions above without rewriting
source snapshots.

Metadata correction checks passed: authoritative STR, dormant chart/terminology,
read-only projection and both #37B suites (five focused suites, exit 0). All 648
cells/1,620 components and 120 STR mode comparisons still match; corrected page
metadata and APP/PAR/CHA names/pages are asserted explicitly. Whitespace checks
passed. The existing Phase 2C validation above remains applicable to unchanged
gameplay and persistence behavior; no separate full regression/export was run.
