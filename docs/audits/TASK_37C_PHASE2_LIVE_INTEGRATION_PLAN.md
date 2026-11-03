# #37C Phase 2 — live integration audit and staged plan

Baseline: main, `94b7343`. Audit/documentation only. No runtime integration authorized.

## Conclusion

Recommend a read-only character-stat projection first, without a new UI. Existing
admitted actor values remain authoritative. Universal chart results are separately
identified references, never replacement actor statistics or grants. Then shadow
the small set of comparable derived values before replacing any live calculation.

SAFE means demonstrated equivalence or a read-only representation, within the
stated range. It does not authorize a broader score range, purchase, modifier,
creation policy or NPC recalculation. SHADOW FIRST means compare without feeding
results into decisions. BLOCKED means missing implementation/history/source data
or separate approval, not that an already resolved owner ruling needs reopening.

## Authority and integration dependency map

Paths below are repository-relative; functions are the inspection anchors.

| Live consumer | Current authority and dependencies | Classification / compatibility risk |
| --- | --- | --- |
| Character creation/admission | `scripts/data/combat_character_definition_resource.gd::instantiate_actor`, `scripts/data/combat_definition_catalog.gd::instantiate_actor`, `scripts/combat/prime_v3_vertical_slice_fixture.gd::make_player_actor`; authored `data/characters/*.tres` supplies attributes, independent stats, maxima, capabilities and provenance. `scripts/rewards/playable_character_admission.gd::audit/prepare_starter` compares Vaelis against authored JSON, including the approved standard 6/3 DEX split and legacy 3/6 branch. | **SHADOW FIRST** for chart comparison; **BLOCKED** automatic creation/rebasing. A chart is not proof of racial contribution, authored exception, starting HPM, starter grants or resource policy. Guard remains a nonpersistent fixture. |
| Permanent STR purchasing | `scripts/rewards/prime_v3_advancement_catalog.gd::make_purchase_preview/build_actor_purchase_options` → `scripts/combat/arena_combat_session.gd::get_character_advancement_eligibility/request_character_advancement` → `scripts/rewards/arena_reward_ledger.gd::purchase_advancement` → `scripts/combat/combat_simulation.gd::apply_verified_character_advancement` → `CombatActorDefinition.apply_verified_strength_advancement`. Uses current permanent STR, EXPC receipts, STR-derived source matching and equipment validation. | **SAFE** STR lookup equivalence only, scores 1–20, both modes. Keep existing failure reasons, mortal purchase boundary, exactly-once spending and no-refill behavior. Do not infer purchase eligibility from engine scores 21–35. |
| DEX ACC | `PrimeV3DexChart.accuracy`, called by `DexAllocation.derived`, simulation development commands/effective stats and profile hydration. Mode comes from progression policy (`mana`, otherwise existing `regular` fallback). | **SAFE** ACC numeric lookup 0–35 in both modes. Adapter must retain null-on-invalid behavior and existing callers' explicit mode policy. Lookup equivalence does not establish that every actor's authored ACC should be replaced. |
| DEX allocations/preferences | `scripts/combat/dex_allocation.gd`, `character_development.gd`, simulation development command and `_sync_temporary_dex`; `DefensivePreferences.plan` via `_plan_defensive_sources`. Locked baseline, pending grants, command/source/activation identities; dt/dp additionally receive armor/direct effects. | **SHADOW FIRST** positive supported cases; **BLOCKED** negative pool integration, permanent-loss/recovery history and new purchase access. Do not reset legacy 3/6 to standard 6/3, reallocate confirmed points or expose hidden controls. |
| Level/HPM/Mana/AP growth | `scripts/rewards/character_level_progression.gd::apply_award/growth_terms`, `prime_v3_level_catalog.gd::validate`; actor HPB, permanent WIS, experience policy and recorded die draws. HPM delta stored separately; Mana gains floor(WIS/2)+5 or shared Ability Point +1. Current resources unchanged. | **SHADOW FIRST** comparison of existing HPB/WIS inputs; **BLOCKED** END/WIS purchasing/reduction integration. Chart HPB is not HPM; chart MR/H is not level-up Mana growth. Preserve recorded event-time terms/rolls and distinct daily allowances. |
| Base/effective stats | `CombatActorDefinition.get_base_combat_stat/get_combat_stat/apply_equipment_stat_modifiers`; `CombatSimulation.get_effective_actor_combat_stat`. Authored base → equipment MR/DT/DP → supported development → sorted timed effects. | **SHADOW FIRST**; never compare a chart base with a penalized/effective value as if equivalent. Effective getter handles positive DEX specially and direct stat modifiers, not a universal primary evaluator. Missing values remain unavailable. |
| Physical attacks/criticals/reactions | Simulation `start_physical_attack`, `_resolve_single_linked_attack_accuracy`, `_prepare_physical_damage`, `_execute_critical_reaction`. Ordinary ACC/SB/NAL can use effective getter; initiative/RB and reaction ACC include direct definition reads. Attack legality also depends on weapon, location, position, timing and hand readiness. | **SHADOW FIRST**. Replacing only the effective getter would miss direct consumers. Preserve already-resolved attack snapshots, RNG order and independently committed strikes. Racial NAL/location TAL must not become END NAL twice. |
| Dodge/Soak/Block/NAC | Simulation `_plan_defensive_sources`, `_evaluate_defense_eligibility`, `_validate_resolved_dodge_context`, `_resolve_defensive_nacs`; effective DT/DP/PS, definition MR, capabilities, profiles, positioning and source eligibility. | **SHADOW FIRST**. Keep signed effective DT/DP, natural critical semantics and existing #37A planner. An ineligible Dodge may yield to Soak; successful earlier Block costs no NAC Mana. Only the specific unresolved strike is interruptible. No projectile-object system is introduced here. |
| Action/initiative clocks and AI | Simulation `begin_combat`/wave arrival and `CombatActorState` movement-budget refresh consume authored INIT/AT/MR. `scripts/creatures/rare_human_warrior_boss_ai.gd` reads HPM/MR/AT; other creature fixtures and session enemy movement construct authored actors/profiles. | **SHADOW FIRST**. SPD/WIT-derived replacements could change all action durations, ordering and pursuit. Preserve 5/AT timing and authored NPC exceptions; do not regenerate creature statistics from player charts. |
| Walking/Running/prone | `scripts/player/placeholder_player.gd::configure_authoritative_actor_profile/refresh_equipped_movement_rate`; `scripts/movement/prime_movement_model.gd` uses MR, SPD, END, RB and separately authored Running SCM/SI. Session `_actor_definition_snapshot`/movement paths and `character_wave_checkpoint.gd::validate` also consume them. Running bonus floor(SPD/2), duration END × 5s, prone allowance quarter MR; ordinary Dodge uses half allowance rounded down. | **SHADOW FIRST**. Both simulation and separate Running/recovery model/checkpoint validators must agree. Do not substitute INT chart SCM for authored Running SCM without source-qualified skill integration. Keep MR zero floor and downtime/persistence-pending freezes. |
| Encumbrance/equipment/possession | Catalog `validate_actor_equipment/validate_equipment_strength/calculate_armor_stat_modifiers`, weapon `effective_hands_required`, shared `combat_weapon_handling.gd`, session inventory transactions and simulation throw/pickup/potion checks read permanent STR. Armor penalties accumulate by distinct slot; protection remains location-specific. | **SAFE** read-only display of existing requirements; **SHADOW FIRST** base STR/MWC comparison. **BLOCKED** universal temporary STR eligibility and general weight penalties: complete weight data/fractional rules are unavailable. MWC lookup alone is not an encumbrance implementation. Preserve spear identity, grip, potion hand legality and shield condition. |
| Magic/Specials/resources | Simulation `request_nac_attack` and `_resolve_special_skill_check` use definition SS/RB, registered Special permissions, independent Mana/AP/current resources, daily allowances and effect definitions. `CombatActorState` initializes resources; session carries them between waves. | **SHADOW FIRST** SS; **BLOCKED** general MSL/MNS/MRF/MIUR learning/access integration and MR/H recovery. A chart maximum cannot grant a Special, known spell, resource or elapsed recovery. Temporary WIS must have zero Mana effects. |
| Luck | Definition RB feeds attack/defense/Special rolls and Running checks. No general permanent/temporary ToF or RR/W ledger is implemented in these live paths. | **SHADOW FIRST** RB; **BLOCKED** ToF/RR/W grants/spending. Chart ToF is not a refill, RR/G source label is not implemented RR/W cadence. Requires durable source/spend/wave identity before activation. |
| Independent Resistances | Actor base `sr`/`tb`, `apply_verified_resistance_advancement` and advancement catalog/receipts. No universal primary formula or general toxin/SR check dispatcher follows from these fields. | **SAFE** descriptors/display: SR Special Resistance; TB Tolerance Bonus. Preserve `talent_bonus` wire/purchase identity. **BLOCKED** new resistance mechanics/pricing (including TB0→1), not authorized by descriptor support. |
| INT/WIT/MAN/APP derived values without general consumers | Engine can describe S#/SCM/MIUR, MNS or MRF/RCL, persuasion AP/KP and PAR/CHA. Live actor definitions do not constitute universal skill/field/persuasion systems; MAN AP is not shared Ability Points. | **SAFE** source-qualified read-only references; **BLOCKED** grants or new gameplay consumers. Keep Mana/Regular differences, PAR through 18 and separate ability-resource naming. |
| UI/status/advancement | `scripts/ui/arena_combat_controller.gd::_get_player_resource_presentation/_update_rewards_panel/_rebuild_advancement_options` reads session snapshots/actor state; STR preview directly uses the old chart. No general four-category Character Sheet is currently implemented. | **SAFE** descriptors/read-only projection; **SHADOW FIRST** any replacement preview. Current HPC/Mana/AP/Shield are authoritative resource values, not chart outputs. Never add Shield to HPC or display unavailable values as zero. |
| Profiles/checkpoints/backups | `scripts/rewards/character_profile_projection.gd::project/hydrate`, `character_wave_checkpoint.gd::validate`, playable desktop/browser persistence, coordinator, Save Contract V2, backup contract `validate_history` and restoration. Hydration replays approved STR/SR/TB purchases before validating growth; optional development record has strict DEX/preference fields. | **SAFE** zero-write inspection. **BLOCKED** new permanent history/entitlement records without separately approved compatibility work. Different baseline data changes definition fingerprint/admission: do not rewrite authored `.tres` files to match charts. Desktop/Web/backup must accept the same history and preserve receipts, equipment SHP and wave-entry resources. |

## Approved calculation boundaries

- Source tables: verified catalog and Phase 1 engine, V3 pp.19–24 and 53–56;
  advancement pp.99–102; event-time growth pp.51/72. Reuse consolidated
  `TASK_37C_TERMINOLOGY_AND_LUCK_RULINGS.md` and
  `TASK_37C_OWNER_RULINGS_PAR_AND_LIMITS.md`, not superseded audit questions.
- All ten primaries remain distinct from derived values, independent SR/TB and
  resources. No CON attribute; TB is Tolerance Bonus; ToF is Twists of Fate;
  PAR is Personal Appearance Rating; DT is Dodge Touch.
- DEX/MAN negative pool changes remove higher allocation first, ties DT/AP;
  allocation points stay nonnegative. Subsequent effective DT/DP may be signed;
  no extra die penalty and no zero clamp. MR alone has the approved zero floor.
- Permanent WIS increases grant +1 Mana Max per point, never current Mana;
  permanent losses and temporary changes change neither existing Mana value.
  Future growth uses applicable event-time WIS; do not recompute past growth.
  END/HPB history likewise cannot be replaced by final END at hydration.
- Encumbrance at whole-pound excess E>0: MR magnitude floor(E/10)+1,
  DT/DP floor(E/20)+1; E=0 has no penalty. Missing weights/fractional handling
  remain gated. Armor and direct Special modifiers remain independent sources.
- Temporary ToF requires source-qualified grant/spending tombstones across expiry
  and reload. RR/W uses first eligible critical failure, replacement without a
  reroll chain, distinct subsequent opportunities and no false reset on retry,
  reactivation or load. These are approved rules awaiting implementation.
- Scores above 20/25 require their approved eligibility; chart presence grants
  nothing. DEAD/* stay tagged outcomes, not automatic kills/numeric maxima.

## Smallest staged implementation proposal

Each stage requires separate approval. Proposed new filenames are not created by
this audit. No stage is a mandate to implement the following stages.

### A — Read-only admitted character projection (recommended first)

Scope: new `scripts/combat/character_attribute_projection.gd`, its UID;
new `tests/test_task_37c_attribute_projection.gd`, its UID;
suite registration in `tests/test_runner.gd` and the Phase 1 architecture note.
No controller, save, actor, definition or combat calculation changes.

Accept explicit admitted actor/state inputs and explicit verified chart mode.
Return four categories: Primaries, Derived Attributes, Resistances, Resources.
Separate authoritative permanent/base/equipment/effective/current values from
chart-reference values and their source pages. Require effective values supplied
by the existing authority rather than guessing them. A missing mode/stat is
unavailable; no silent Regular fallback in this new inspection API. Report
authored/racial/source exceptions as such, not an instruction to correct them.
No Character Sheet screen or unfinished controls in this stage.

Tests: Vaelis, legacy/new DEX histories, Guard, representative creature fixtures,
both modes, missing provenance/stats, signed DT/DP, independent SR/TB, damaged
shield, spent resources, tagged DEAD/*; compare complete actor/state/snapshot,
RNG draw count and event history before/after repeated calls. Mutating returned
data must not mutate inputs. Existing save/replay/convergence suites unchanged.
No save/schema fields. Rollback: remove projection/test registration only; no
player data or history to reverse. Main risk: presenting chart reference as live
authority or triggering initialization/refills during inspection.

### B — Non-authoritative shadow comparisons

Scope: projection plus proposed `scripts/combat/attribute_shadow_comparison.gd`,
focused tests/runner. Initially invoke from test fixtures, not per-frame gameplay.
Compare old STR/DEX helpers against engine results and authored base stats against
separate chart references. Classify source-qualified exceptions, unknowns and
actual numeric differences. Include equipment/direct-effect layers explicitly.
Do not emit simulation events or add diagnostics to authoritative snapshots.

Tests: exhaustive supported helper ranges; representative player/NPC admission,
leveling, STR purchase, armor, timed DEX, defense sequence, attack resolution and
movement snapshots, including expired effects. Zero state/RNG/event mutations.
No save changes. Rollback: remove diagnostic invocation. Risks: comparing unlike
layers, accidentally feeding the shadow result into live decisions, log overhead.

### C — Individually approved exact-equivalent lookup replacement

First C1 scope: only `scripts/combat/prime_v3_strength_chart.gd`, focused tests and
architecture documentation (plus runner only if needed). Delegate existing
1–20 helper to engine STR integers behind the same return shape/range/errors.
All actor, preview and hydration callers retain their present interfaces.
Do not broaden pricing, caps, source validation or equipment permissions.

Separate C2 approval: only `prime_v3_dex_chart.gd` plus tests/docs; delegate ACC
0–35 with identical mode validation and null failures. Do not alter allocation
or effective-stat policy. No need to replace all call sites separately.

Tests: 192 equality checks plus invalid/range/error contracts, STR purchase and
duplicate rejection, old saves, desktop/Web candidate hydration, backups/restore,
equipment hand thresholds, defense/reaction/NAC, replay and two-client digest
equality. Normal outputs and histories must be identical, not merely similar.
No migration or new saved values. Rollback: restore only helper implementation
from the preceding reviewed checkpoint; compatible saves require no rollback.
Risks: widening valid inputs, coercing DEAD/*, changing invalid return shapes.

### D — Source-aware effective attributes and allocations

BLOCKED as a broad change pending narrow approval. Reuse engine, DexAllocation,
CharacterDevelopment and existing timed-effect identities. Proposed eventual
scope: those modules, `combat_simulation.gd`, actor definitions/state only where
necessary, plus movement/player/session, equipment and UI consumers enumerated
above. Split each primary into its own reviewed replacement; start only after B
identifies exceptions. Do not make all authored stats chart-derived by default.

Implement approved signed modifiers/negative pool policy separately from permanent
allocation histories; MAN needs a distinct persuasion record, not resource `ap`.
Any durable record extension is BLOCKED until explicitly authorized. Tests need
overlapping/expired/reactivated sources, no double modifiers, historic allocations,
same player/NPC permissions, movement budgets/Running/crawl, equipment and final
attack legality, #37A Block/NAC/Soak order and exact strike interruption.
Rollback: keep previous authority per explicitly integrated consumer, with no
partial state application. A new durable record cannot be rolled back by code
alone; keep its publication disabled until compatibility approval/tests exist.

### E — Event-time growth and durable entitlements

BLOCKED pending explicit history/compatibility approval; do not bundle with C/D.
Scope likely includes `character_level_progression.gd`, `character_development.gd`,
`character_profile_projection.gd`, `character_save_contract.gd`, checkpoint,
coordinator/playable persistence, backup validation/restoration and relevant
simulation/reward boundaries. Storage/IndexedDB need not change for ordinary
validated document payloads; no file-I/O in combat resolution.

Design validated chronological END/HPB/WIS purchase/loss/growth history first,
then source-qualified ToF and RR/W grant/spend records with stable wave identity.
Current hydrate compares all growth against final actor HPB/WIS after purchases
(`character_profile_projection.gd::hydrate`, around lines139–169); it cannot prove
interleaved future END/WIS changes. Existing saved fields do not grant arbitrary
new record types. Preserve accepted STR-only histories; fail closed for missing
chronology instead of inferring old attributes or rerolling growth.

Tests: interleaved gains/losses/levels, no refills, no repeat grants on load,
expiry/toggle farming, retry vs next authorized wave, natural critical/replacement
lineage, receipts/checksums, atomic failure, namespace isolation, desktop/IndexedDB,
backup export/preview/restore and schema12 replay/convergence. Any optional V2
revision/new field needs owner-approved strict validation/migration behavior;
unprovable histories remain gated. Rollback must preserve newly written history;
disable new operations rather than drop fields or rewrite old profiles.

## Decisions and blockers

No additional rule ruling is required for A–C within the restrictions above;
owner authorization of each implementation scope is still required. Do not reopen
resolved allocation, WIS, PAR, critical or encumbrance rulings.

Before D/E: approve the precise persistent extension and legacy treatment; specify
only genuinely missing source rules (fractional carried weight/unknown weights,
undefined permanent recovery, additional interacting reroll sources when actually
introduced). Keep TB0→1 pricing blocked. Read-only display of unavailable mechanics
does not require inventing these rules. New learning/skills, purchasing other
attributes and a new Character Sheet UI are separate scope, not automatic engine
integration benefits.

## Validation of this audit

- HEAD and branch checked: `94b7343`, main. Initial tracked worktree clean;
  protected DOC, character saves directory and tmp directory untracked.
- Inspected live accessor/direct-stat callers across scripts, development,
  movement, authored Vaelis, admission, growth, equipment and persistence paths.
  No live `PrimeV3AttributeEngine` callers: only dormant engine and its tests.
- Fresh in-memory comparison: **192/192 scalar matches** between current old
  STR1–20 (3 components ×20×2) / DEX ACC0–35 (36×2) and dormant engine tables.
  This is current code-to-code equivalence evidence, not a new independent PDF
  transcription or proof that all authored actors match the universal charts.
- No gameplay tests, Godot import, Web export or full regression run for this
  documentation-only audit. Prior Phase 1 passes are historical evidence only.
- Only this document added. No production/test/definition/save/contract edits;
  no protected contents inspected, no Git mutations beyond this new document.
