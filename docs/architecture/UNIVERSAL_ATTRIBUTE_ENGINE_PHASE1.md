# Universal attribute engine Phase 1

Implemented as dormant rules queries only. No live calculation or UI call site
is redirected; Save Contract V2, schema12, progression and gameplay are unchanged.

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
