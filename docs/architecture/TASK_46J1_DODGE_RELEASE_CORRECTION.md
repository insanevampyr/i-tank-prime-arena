# Task #46J-1 — Surgical Dodge Release-Build Correction

## Status

**Complete. GO for resuming the unchanged #46J browser acceptance matrix under separate owner authorization.**

This task fixes only the release-only Dodge side effect and runs bounded Dodge/source-equivalence checks. It does not accept or resume the broader #46J publication/recovery matrix, activate saving, change storage, or issue a production build.

## Recovery of interrupted work

The interrupted session had created `tests/test_dodge_release_correction.gd`. The production correction had **not** been applied. No completed native or release-WASM result existed in its disposable test directory. The existing #46J report, strict oracle, browser implementation and earlier work were preserved.

The recovered test's failed-roll fixture originally passed an incomplete defense priority, rejected by the original `CombatDefenseProfile` invariant. Its first diagnostic run therefore failed. That new test fixture was corrected to use the existing complete legal priority and deterministic failed Dodge/Block rolls; its expected RNG draws include those original fallback attempts. No validator, priority rule or original test was changed. The resulting original-debug baseline passed before the production correction was applied.

## Exact file manifest across both #46J-1 sessions

| Change | File | Scope |
|---|---|---|
| Modified | `scripts/combat/combat_simulation.gd` | One call moved out of `assert` in `_apply_successful_dodge()`; Boolean asserted instead. |
| Added, continued from interruption | `tests/test_dodge_release_correction.gd` | 49 source-API assertions, full debug/release state/event samples and a bounded checkpoint source-oracle probe. |
| Added | `tests/test_dodge_release_correction.gd.uid` | Regression script UID. |
| Added | `tests/browser/test_dodge_release_edge.js` | Isolated release-WASM export/Edge runner and exact comparisons. No #46J storage matrix invoked. |
| Added | `docs/architecture/TASK_46J1_DODGE_RELEASE_CORRECTION.md` | This report. |

No existing test, #46J oracle, coordinator, codec, browser bridge or persistence implementation was changed.

## Exact correction and call-path audit

The two callers remain unchanged:

1. `resolve_pending_defense()` applies a successful, validated, resolved Dodge at line 2499.
2. `complete_pending_dodge_displacement()` applies the already successful Dodge after its original destination validation at line 2810. It does not reroll the defense.

Original `_apply_successful_dodge()` at line 5746 executed the mutation only as an assertion expression. The corrected code is:

```gdscript
var movement_cost := int(dodge_context.movement_cost_microfeet)
var movement_spent: bool = defender_state.spend_movement(movement_cost)
assert(movement_spent, "Validated Dodge movement must remain spendable in the same transaction.")
```

The rest of the function is byte-identical. The original LF line endings are retained. `spend_movement()` is called exactly once, including the original zero-cost duck case; the assertion reads the Boolean without invoking any mutation. Movement validation, costs, destinations, revision increments, attempt-resource bindings, defense ordering, critical consequences, timing and RNG are unchanged from authoritative debug behavior.

A byte-level reconstruction from the saved task-entry combat source proves that the one-expression replacement is the entire production delta. All earlier modifications to that file remain intact.

## Independent baseline and comparison protocol

Before touching production code, the corrected **test fixture** was run against the still-original combat function in native Godot debug. It produced a frozen, sorted JSON oracle with complete before/after simulation snapshots, all serialized resolved events, result dictionaries, and NORMAL/DEV checkpoint projections. The original-debug probe passed **49 assertions**.

The same probe then ran after the production correction. Its output is **byte-identical** to the original debug output: **422,093 bytes**. The original baseline is not regenerated from release results.

The standalone Edge harness imports and exports an OS-TEMP project containing the current combat source, loads it in an independently spawned disposable headless Edge profile at a random loopback origin, and confirms `web == true` and `OS.is_debug_build() == false`. It executes the same 49 checks in actual release WASM, then deep-compares the entire result with the frozen original-debug JSON. No differing fields, revisions, events or digests are removed, normalized or ignored.

Both NORMAL and DEV source-backed checkpoint probes also compare the **complete current/evidence body and full simulation** directly against the existing, unchanged #46J oracle files. This is a bounded no-publication source probe using the existing simulated-checkpoint test API. No IndexedDB character publication, recovery, corruption, two-tab or lifecycle matrix is run.

## Measured behavior

Values below are identical in original debug, corrected debug and corrected actual release WASM.

| Case | MR before → after (microfeet) | Actor revision | Verified result |
|---|---:|---:|---|
| Resolved successful 2-foot Dodge | 10,000,000 → 8,000,000 | 1 → 3 | One spend revision plus original position revision; one defense RNG draw. |
| Automatic successful 2-foot Dodge | 10,000,000 → 8,000,000 | 1 → 3 | Same original selection, cost, event bindings and roll. |
| Pending success, then 3-foot completion | 10,000,000 → 7,000,000 | 1 → 3 | No spend while ambiguous; one spend on completion; no completion reroll. |
| Legal zero-cost duck | 10,000,000 → 10,000,000 | 1 → 2 | Original zero-cost spend revision once; no displacement. |
| Failed Dodge and legal Block fallbacks | 10,000,000 → 10,000,000 | 1 → 1 | No Dodge spend/move; original three defense draws retained. |
| Invalid/missing requests | 10,000,000 → 10,000,000 | 1 → 1 | Missing ID, unknown attack and missing context rejected without state, events or RNG changes. |

Duplicate successful requests, fresh IDs against completed attacks, duplicate pending completions and invalid pending movement costs are also rejected without a second spend or RNG draw. Full state/event equality covers action clocks/history in addition to the explicit resource assertions.

The previously failing NORMAL checkpoint binding now exactly matches its original debug value:

`e8a9e284a0ac114a107a29ed7212887de8d2edb91729a193bc655923aa72a6ec`

Corresponding DEV binding:

`6e5803b742534e7608beb530063984c1f08b7761cbcad3a4f7f87e3c6d8bc9fa`

All checkpoint fields and journal entries are compared, not only these digest strings. The two actor revisions identified by #46J now match the original native source because the complete simulation comparison passes.

## Final focused results

| Check | Result |
|---|---|
| Original native debug, before production edit | 49 assertions PASS |
| Corrected native debug | 49 assertions PASS; frozen output byte-identical |
| Actual corrected release-WASM GDScript checks | 49 assertions PASS |
| Edge runner exact comparisons/environment/isolation | 12 assertions PASS |
| Existing native `physical defense` suite | PASS; includes Dodge failure, pending, duplicate, automatic selection, replay and simulated-client convergence |
| Existing native `opening initiative and physical attack` suite | PASS |
| Existing native `approved critical consequences` suite | 746 assertions PASS |
| Isolated Godot import/release export | PASS, no script/parser errors |
| New JS syntax and `git diff --check` | PASS |

Counts for the first two existing suites are not exposed by their existing test interfaces and were not fabricated or added by editing those suites. Original/corrected runs overlap; the table is not a count of distinct unique scenarios. No full regression was run.

An initial Edge-runner isolation check expected zero IndexedDB databases. Godot itself creates its own `/userfs` filesystem database on startup in the disposable profile. All Dodge/oracle comparisons had already passed; only that overly broad test assertion failed. The runner now records the database list immediately after engine readiness and requires the list to remain exactly unchanged after the probe. Actual lists were `['/userfs']` before and after. No character database, production browser profile, character-storage bridge or #46J publication path was opened. This runner-fixture correction does not change the strict #46J source oracle or any gameplay comparison.

## Environment, artifact and evidence

- Godot 4.7.2 stable official `ed1daf0bf001b61586d9930840f2f1394092c079` on Windows.
- Actual isolated headless Edge **158.0.4370.33**, V8 **15.8.13.3**.
- Godot release WASM: Emscripten 4.0.20, single-threaded, no GDExtension, WebGL2 software rendering. No Godot/JS runtime errors in final acceptance.
- This is an isolated diagnostic export, not `builds/web` or a production BUILD. The exported copy of `combat_simulation.gd` matches final working-tree bytes exactly.

- Frozen original debug SHA-256: `c0845a33eab55c065cf01a0959054513e6df2f5cbae2ab840df875cd7569b56f`.
- Isolated PCK SHA-256: `1f997a39c3842932bc70f68ca139cbb511c78fbe489665957501010cd4acb8e7`.
- Final combat source SHA-256: `5b0f65eb8611ebeb247021863691ab7b171f1cd835224620b8104af85bc724b6`.
- Unchanged external #46J oracle SHA-256 values:
  - `normal`: `5b94fd69df508133f66ea8d79d9483755b12246fa237368f3c44a85cd90ccee6`.
  - `dev_normal`: `2c30c0ee9dbdd503d6d0a8fd3d6492919e578d39304162322661cc1472c82299`.

Evidence directory: `C:\Users\mxz\AppData\Local\Temp\arena46j1-3sp8nkx_`.

Files include `baseline.json`, `original_combat_simulation.gd`, `native_probe.gd`, `native-before.json`, `native-after.json`, native logs, `release-result.json`, `edge-results.json`, `edge-console.json`, `import.log`, `export.log` and `release-project/web/`. The frozen #46J fixture directory is recorded in `fixture_directory.txt` and was only read. Final Edge console: `%TEMP%/arena46j1-edge-final.log`. Native existing-suite logs: `%TEMP%/arena46j1-regression-0.log` through `-2.log`.

Focused reproduction commands:

```powershell
# Uses the existing disposable frozen baseline recorded by the 46J1 TEMP pointer:
node tests/browser/test_dodge_release_edge.js
# Existing registered suites, each filtered:
& 'C:/Users/mxz/Desktop/GoDot/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/test_runner.gd -- '--suite=physical defense'
# Other filters: opening initiative and physical attack; approved critical consequences
```

The standalone test remains separate from `test_runner.gd`; that existing file was not modified. Native probe invocation and immutable evidence are retained in the disposable directory.

## Preservation and remaining scope

- Branch `main`, HEAD `f9bb0db0235b0003895c477a12346191d4714469` unchanged. Index remains empty. No Git staging, commit, push, reset, rebase, stash or cleanup.
- Across **801 previously existing entry-hashed source/test/docs/config/tool files**, only `scripts/combat/combat_simulation.gd` changed; its exact production delta is shown above. No entry file disappeared. This preserves all earlier #45/#46 work, including the paused #45U work and unchanged #46J implementation/oracle.
- `project.godot` retains its existing modification, SHA-256 `8398f110f77d7712eb19c283eb9f745c7123feab9557187778da412639ba5692`.
- Owner saves, backups, production browser storage, protected boss documents, `character saves/` and repository `tmp/` were not opened or modified. Only existing disposable fixtures and newly isolated OS-cache/profile paths were used.
- No save codec, coordinator, persistence behavior, format, combat rule, Roadmap or Combat Specification change. No production export or playable activation.
- The larger #46J crash/repair/competing-tab/quota/cancellation/progression/stress/memory acceptance is still outstanding. This task clears the specific release-Dodge equivalence blocker; it does not certify those unexecuted storage cases or owner gameplay.

Final status: 35 modified tracked files and 225 collapsed untracked entries, including prior work and protected-path names. The five-file task-relative manifest above is the only #46J-1 change set. Full final path-only status is retained in `C:\Users\mxz\AppData\Local\Temp\arena46j1-3sp8nkx_\final-git-status.txt`.

**GO for resuming the unchanged #46J browser acceptance matrix under separate owner authorization. STOP after #46J-1; no automatic continuation.**
