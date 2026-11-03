# Task 37C source audit in progress

Historical interruption record retained. The owner has now confirmed
SKILL-INVESTMENT-001 as a manuscript erratum: Time Sense SI 1-5 is
-2,-1,0,+1,+2 (V3 pp.27/67); additional investments add exactly one, while
automatic-skill exceptions remain separate. See
`TASK_37C_FINDINGS_AND_ENGINE_PROPOSAL.md` and
`TASK_37C_BOOK_VERSUS_CODE.html` for the continued audit and remaining gates.
The original partial extraction/checksum below remain unchanged; the separately
hashed `TASK_37C_VERIFIED_SOURCE_CATALOG.json` resolves the wrapped cell.

Status: NEEDS RULING. This is a partial audit record, not an approved universal
attribute engine specification. No runtime calculation, definition, save, or
simulation schema was changed. Baseline: main at
22cbcd349bb78f89ca871858554b5c3e91faaec9.

## Source evidence preserved

The source PDF is `C:/Users/mxz/Desktop/Projects/ITank Prime/ITank Prime V3.pdf`.
SHA-256: `600140d4c7823d4c331cf20913622bb888093ab4bec8f9f052481344efc2c785`.
Definitions on printed pp. 19-24 and charts on pp. 53-56 were read independently
of runtime calculations. Character Sheet V9.0 page 1 was rendered to inspect its
headings; it is not used to supply mechanics missing from V3.

`TASK_37C_ATTRIBUTE_CHART_TRANSCRIPTION.partial.json` preserves the raw PDF
table matrices and 648 mapped chart slots: Mana and Regular modes, scores 0-35,
nine printed primary columns per row. One mapped cell is empty because PDF
extraction splits/merges printed cell spans; they are deliberately not filled
or treated as missing printed rules. MAN is absent from those printed charts.
The neighboring SHA-256 file fixes this partial extraction snapshot's exact
bytes. Complete span reconstruction, cell-by-cell visual verification and code
comparison remain incomplete. This snapshot must not be used as engine input.

## Approved MAN design recorded without implementation

Authority: owner's final Task 37C continuation ruling, not a printed V3 chart.

- AP here means Aggressive Persuasion; KP means Kindly Persuasion. Ability Points
  are a separate resource and must have a distinct semantic identity.
- Base AP plus base KP equals permanent MAN.
- New standard characters use a balanced 50/50 whole-point allocation. An odd
  point goes to the otherwise lower side. A tie requires a documented,
  deterministic tie-breaker without combat RNG; this audit has not implemented
  or finalized that tie-breaker.
- Preserve explicitly authored exceptions, NPC/creature definitions, and
  historical allocations. Do not migrate profiles or rewrite history.
- Legitimate permanent MAN growth grants only the corresponding new points.
  Safe-state assignment must be explicit, confirmed, locked and exactly once.
  Existing points cannot be freely redistributed.
- Temporary MAN bonuses are automatically split using the same balancing and
  deterministic tie-break principles. Keep source/activation contributions
  separate; no manual allocation, duplicate activation, or alteration of
  permanent confirmed assignments. Remove only the expired source contribution.
- Retain source-specific allocation exceptions where explicitly established.
- STR-related AP and INT-related KP modifiers remain separate from the base
  pool under printed p. 22. None of these MAN operations is activated here.

## Vaelis authored definition findings

These findings inspect authored source and runtime definitions, not an owner's
saved profile.

| Field | Finding | Evidence |
| --- | --- | --- |
| Permanent MAN | 0 | `data/characters/vaelis_thorn.tres`, `attributes.man` |
| Authored base AP / KP | 0 / 0 | Supplied Vaelis JSON, `derived.AP_persuasion` / `derived.KP` |
| Conservation | 0 + 0 = MAN 0 | Authored record |
| New standard 50/50 split | Also 0 / 0; no numerical change | Owner MAN rule |
| STR-related AP modifier | Printed +1 to the persuasion roll at STR 9: one complete group of six, cap +3 | V3 p. 22; this is not an Ability Point grant |
| INT-related KP modifier | 0 at INT 5 | V3 p. 22 |
| Live effective AP / KP | Not available as registered combat statistics | Runtime `.tres` omits persuasion fields; `CombatSimulation.get_effective_actor_combat_stat` first requires a registered base field |
| Historical preservation | Do not populate/rewrite old profiles merely because a new allocation model is proposed | Owner ruling; no saves inspected |

Source paths: `assets/Character Choices/Vaelis_Thorn_Elven_Fighter_Force_Mage_Arena_Character_Data.json`,
`data/characters/vaelis_thorn.tres`, and
`scripts/combat/combat_simulation.gd`.

The literal printed STR/INT persuasion modifiers have not been silently added
to the authored AP/KP targets. The live engine has no implemented effective
persuasion calculation to report as a verified gameplay value.

## Confirmed printed conflict requiring an owner ruling

Identifier: SKILL-INVESTMENT-001.

Printed p. 27 demonstrates Alertness at SI 1 with modifier -4, and SI 5 with
modifier 0: four additional investments add four points.

Printed p. 67 states that every additional S# invested in a skill increases its
modifier by one. However, its Time Sense example starts at modifier -2 and says
one additional investment changes it to 0, followed by +1 and +2. These two
instructions do not yield the same progression. The discrepancy was checked
against the rendered printed p. 67, not inferred from game code.

Owner question: should Time Sense follow modifiers -2, -1, 0, +1, +2 at SI 1-5,
with the p. 67 example treated as an erratum, or does another explicit rule
govern that jump? No interpretation has been selected.

Per Task 37C's mandatory stop condition for conflicting printed rules, the
audit pauses here. No existing skill behavior is changed.

## Work still pending

- Complete every-cell source verification and the full primary/derived catalog.
- Finish independent code-versus-book comparisons and classify every finding.
- Complete the universal engine proposal, including a reviewable deterministic
  MAN tie-break design and explicit handling of unsupported source operations.
- Produce the final owner-readable comparison document.
- Obtain owner approval before any live integration.

No gameplay tests or exports were run for this audit. Partial extraction checks
confirmed row ranges but found unresolved cell spans; no runtime table is
generated or consumed from this provisional snapshot.
