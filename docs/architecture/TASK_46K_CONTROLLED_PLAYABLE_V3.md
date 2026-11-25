# Task 46K — Controlled playable compact v3 integration

## Status and scope

Completed the opt-in playable route and bounded native/actual Edge release-WASM control acceptance. This is a disposable development scene, not production activation. #45U remains paused.

## Exact task-relative manifest

Modified existing files:
- `scripts/rewards/character_persistence_coordinator.gd`: optional scene-player factory forwarded to the existing dormant aggregate admission.
- `scripts/rewards/minimal_character_transactions.gd`: optional fresh player construction before gate binding; attached-node teardown; retain the existing owner on an exactly bound pending Windows transport failure. Source authorization failures still close/fail safely.

Added:
- `scripts/rewards/disposable_v3_creation.gd` and `.uid`
- `scripts/ui/disposable_v3_arena.gd` and `.uid`
- `scenes/disposable_v3_arena.tscn`
- `tests/disposable_v3_playable_probe.gd` and `.uid`
- `tests/disposable_v3_playable_release.gd` and `.uid`
- `tests/browser/test_disposable_v3_playable_edge.js`
- This report.

## Isolation and authority

The default scene/project is unchanged. Opening the alternate scene requires an explicit lower-case test slot, plus a debug build or `arena_disposable_v3` custom feature. Without this opt-in the route remains disabled. Windows roots are fenced under OS-cache `itank-storage-tests/minimal46i1_46k_<slot>_<scope>`; aggregate roots use `minimal46c2_46k_…`. The unchanged native helper must exist at the reviewed TEMP location with SHA-256 `a6dac728d1bf305b3754461876eff7213d8bf3625aa52c21f8c4f46470d1ed1b`.

Browser databases use only `itank-arena-disposable-v3-46j-46k-<slot>-<scope>`. No production DB is opened or upgraded. CREATE requires an empty verified destination; LOAD requires a valid existing record. There is no automatic conversion, replacement or fresh-start fallback.

Genesis reuses original starter creation, original receipt/projection authorization, and the unchanged v3 cold codec. It prepares source-authorized starting facts without publishing a legacy generation. The existing coordinator owns all later effects, original issued temporary handles, shared capture gate, pending immutable bytes, CAS and exact readback. The actual visible player is readied before its movement model is restored and bound to the gate. NEW RUN creates a fresh scene player, never reopens retired contexts.

The route exposes CREATE, LOAD/RESUME, SAVE CHECKPOINT, RETRY SAME SAVE and confirmed NEW RUN. Original combat, inventory, weapon handling and advancement controls remain in use. Legacy backup/grant controls are excluded from this test scene. A fresh current character is ineligible for the historical-only fixed EXPC grant: the tested call rejects without changing balances; no new grant authorization was introduced. DEV starts under the existing namespace policy and may select an authorized next-run multiplier; NORMAL authorization remains enforced by the existing coordinator.

## Diagnoses and surgical corrections

1. Browser inventory: the test clicked using coordinates before deferred container layout had settled. Waiting two process frames before reading the real button rectangle fixes the test. The final browser trace confirms the hovered rendered expander and equipment controls. No inventory widget or source rule was changed. Namespace selection uses the actual OptionButton selection/signal; inventory/action buttons use viewport pointer input and attacks/confirmation use keyboard input.
2. Browser NEXT WAVE: pending capture revision 521 advanced to 629 while external movement continued. The test controller now freezes external player processing before initiating the original asynchronous transition and polls storage without inherited movement-lock mutation during an explicit pending transition. The unchanged coordinator comparison now passes. Encoding/publication does not hold the capture gate; this is an explicit transition pause, not a new lock across ordinary combat saving.
3. Windows automatic write failure: a genuine transport failure was incorrectly treated as unsupported gameplay, closing the valid owner. Only a failure bound to that owner's exact pending operation now retains it for exact retry. Invalid source evidence is not accepted.

## Acceptance and equivalence evidence

- Final native Windows Godot debug playable-control run: **166 assertions, zero failures** (`native-controls-final.json/log`). The earlier 166-pass run is also preserved (`native-controls9.json/log`).
- Actual isolated Edge release-WASM playable-control run: **166 assertions, zero failures** (`edge-playable-result.json`, `edge-playable5.log`). Node driver exits 0; no Godot/JS runtime errors accepted by the driver. Viewport 1280×900. Own user-data directory, random loopback origin and disposable DBs only.
- Focused original-source coordinator suite: **306 assertions PASS**; includes independent complete original gameplay/event/RNG/Running/progression comparisons, all five attributes, chronology, fixed-credit eligibility/once-only behavior and multi-run evidence.
- Shared capture gate: **310 assertions PASS**.
- Temporary requests: **140 assertions PASS**.
- Existing playable Vaelis persistence suite: returns an empty failure list. Its runner does not print an assertion total; none is invented.
- `git diff --check`: PASS (pre-existing line-ending notices only).

Actual UI coverage: fresh NORMAL and DEV creation; original START and keyboard combat; source-awarded XP and loot; exit/load with byte-semantic equality of the entire acknowledged body; unequip/equip, stow, genuine potion acquisition/use and terminal zero ownership; injected publication failure, visible NOT SAVED status, immutable pending candidate and retry; NEXT WAVE; DEV progression through Wave 4 to fund END using earned EXPC; confirmed NEW RUN with same epoch and unchanged permanent evidence; exact reload of the new run. No balance was patched to afford a purchase.

The combat fixtures deliberately wound NPCs to 1 HPC and place them in range, and add a catalog-backed disposable potion via original ground-loot APIs. Attack/defense/damage, consumption, XP, costs and persistence remain original APIs. This is persistence/control acceptance, not an ordinary-difficulty balance playthrough. Independent full original-control equivalence comes from the focused 306-assertion suite; the UI test additionally compares exact acknowledged/reloaded character bodies and gate participants. It does not introduce a separate full original UI client oracle.

Earlier failed runs remain preserved: premature inventory coordinates, incorrect OptionButton test signal, potion use without freeing its required hand, insufficient earned EXPC after only two waves, and the genuine browser transition failure. They are not counted as passing runs. No strict #46J oracle was modified.

## Performance and limitations

Final Edge asynchronous post-click wait samples: 37 samples; median 612.7 ms, maximum 930.7 ms. These begin after the input helper returns and are not complete click-to-save latency. Records range from 8,454 to 38,272 UTF-8 body bytes. Native waits mostly observe already completed synchronous writes and are not native publication timings. No routine-save performance claim is inferred from them.

The original v3 record keeps one current state, essential facts and a journal bounded to 20; full validator/coordinator tests cover omission of operation archives. Equipment changes do not create lifetime command transcripts. No format or transport semantics changed.

No new peak Edge/WASM memory experiment, heavy 1,005-item matrix, process-crash matrix, Windows release-export control run, compact/mobile layout certification or human owner acceptance was performed. Previous #46I/#46J crash/replica/CAS results remain prior evidence, not newly executed UI tests. The route uses their unchanged reader repair path; corrupt-copy recovery was not newly exercised through the rendered controls here. Windows stale-lock recovery remains unsupported/fail-closed. Defeat in this route requires exiting/reloading the exact saved checkpoint rather than pretending an unsupported in-place retry succeeded. Unsupported historical evidence remains excluded.

## Running the limited test

Use a new slot, never an owner profile or legacy path:

```powershell
& 'C:/Users/mxz/Desktop/GoDot/Godot_v4.7.2-stable_win64_console.exe' --path '<repository>' res://scenes/disposable_v3_arena.tscn -- --arena-disposable-v3=owner-test-01
```

The existing reviewed helper is a prerequisite on Windows. In an isolated diagnostic Web export with the explicit feature and alternate scene, use `?arena_disposable_v3=<new-slot>`. The automated release harness is `node tests/browser/test_disposable_v3_playable_edge.js`; it creates an OS-TEMP project/export/profile/origin. It does not export or serve production `builds/web`.

Owner checklist: CREATE disposable character; play and inspect saving status; inventory equip/stow/use; save and exit/reload; NEXT WAVE; earn a purchase; confirmed NEW RUN; check retained progression. Stop on NOT SAVED/RECOVERY REQUIRED and use exact retry, never clear storage or manually alter a head.

## Preservation

Entry baseline: 806 pre-existing files hashed. Only the two existing files named in the manifest changed; no baseline file disappeared. `project.godot` remains SHA-256 `8398f110f77d7712eb19c283eb9f745c7123feab9557187778da412639ba5692`. Branch main, HEAD `f9bb0db0235b0003895c477a12346191d4714469` unchanged; staged index empty. Full current path-only status is retained at `C:\Users\mxz\AppData\Local\Temp\arena46k-vgafzq7_\final-git-status.txt`. All prior dirty work remains.

Owner characters, backups, protected boss files, `character saves/`, repository `tmp/` and production IndexedDB were not opened or modified. Roadmap, Combat Specification, old codecs, storage implementations and Dodge correction remain unchanged. No Git mutation, production export/deployment, migration or #45U resumption.

**GO for a limited owner-supervised playable test of this explicit disposable desktop route only. Production activation, owner-character use, unsupported recovery/restore and broader acceptance remain NO-GO. STOP after #46K.**
