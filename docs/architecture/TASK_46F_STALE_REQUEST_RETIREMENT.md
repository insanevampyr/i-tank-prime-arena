# Task #46F — Minimal stale-request rejection

2026-11-19. **Complete: dormant prerequisite and focused tests only.** No history deletion, successor format, routine aggregate, storage implementation or playable activation. #45U remains paused.

## 1. Exact task manifest

Modified existing working-tree files:

1. `scripts/rewards/character_persistence_coordinator.gd` — private request owner and explicit dormant request/capture/simulated-ack APIs. Existing writer/authorization bodies unchanged.
2. `scripts/rewards/character_capture_gate.gd` — opt-in item entry/completion checks and a persistent fail-closed marker on the old runtime.
3. `scripts/combat/arena_combat_session.gd` — three-line pre-entry guards on the four original player equipment, unequipment, handling and use commands.
4. `scripts/combat/combat_simulation.gd` — pre-entry guards on six item-action paths; completion checks before original handling, hand-equipment and consumable effects.
5. `tests/test_runner.gd` — exactly one preload and one suite registration, preserving prior registrations and line endings.

Added:

6. `scripts/rewards/temporary_character_requests.gd`
7. `scripts/rewards/temporary_character_requests.gd.uid`
8. `tests/test_temporary_character_requests.gd`
9. `tests/test_temporary_character_requests.gd.uid`
10. `tests/temporary_requests_cold_process.gd`
11. `tests/temporary_requests_cold_process.gd.uid`
12. `docs/architecture/TASK_46F_STALE_REQUEST_RETIREMENT.md`

This is the delta from task entry, not the much larger accumulated diff from HEAD. No original rule-body statements were removed, reordered or rewritten. In-memory removal of only the new blocks/lines reproduces the entry SHA-256 of all five existing files, including the runner's original bytes. No files were reverted on disk.

## 2. Audit and implementation target

Read #46C-1, #46C2, #46D and #46E and inspected actual source, not only reports. Original commands accept raw request strings and depend on simulator acceptance maps. Raw string membership alone cannot safely distinguish a retired admission after individual IDs are forgotten. #46D v2 retains original command facts but does not solve expiry of delayed live requests. Both snapshot codecs and that evidence model remain unchanged.

Audited original paths:

| Boundary | Actual source path and disposition |
| --- | --- |
| UI issuance | `arena_combat_controller.gd:_on_inventory_equip_pressed()`, `_on_inventory_weapon_handling()`, `_on_inventory_use_pressed()` currently call synchronous session commands with generated/default raw IDs. They are unchanged and do not opt into this prototype. |
| Equipment | Session equip/unequip → original equipment transaction → simulator `apply_downtime_equipment_transaction()`. Original ownership selection, armor, timing, eligibility and events remain authoritative. |
| Weapon handling | Session → `request_weapon_handling()` → immediate or original timed action → `_commit_weapon_handling()`. The completion guard runs before hands/posture changes. |
| Consumables | Session → original downtime use or active verified-consumable action → `_apply_verified_consumable_healing()`. Entry and completion checks precede original item selection, quantity/resource changes and dice. |
| Auxiliary item routes | `start_equip_hand_item_action()`, generic `start_action()` item metadata and `_apply_equipped_hand_item()` cannot reopen a raw player bypass in an opted-in runtime. This prototype does not issue the separate auxiliary hand-equip command; it fails closed there. NPC/unbound paths retain original behavior. |
| Admission/callbacks | Controller `_open_legacy_profile()`, `_admit_existing_profile()`, run-choice callbacks, browser load/lease/cancel/retry and `_poll_browser_persistence()` were inspected. No browser callback or playable control is wired to the new mechanism. Future wiring must capture the issued object before an await/delay and carry it unchanged. |
| Reload/NEW RUN | Original service admission, `_open_existing_verified()`, `restore_ledger()`, original abandon-run authorization and new-run identity allocation are reused in disposable tests. No new run or profile authority is introduced. |
| Checkpoint | Existing shared gate checks actual session, simulator and external player/Running participants. Actual source `_capture()` validates the current schema-12 boundary. No persistence formats or writers are changed. |

## 3. Ownership and issued request contract

The existing coordinator owns one `temporary_character_requests` helper. It is neither a wallet nor a second rules engine. Admission is explicitly restricted to original disposable storage roots beneath the OS cache prefix `itank-storage-tests/temporary46f_`; it rejects the separate #46C2 aggregate route. No production caller selects it.

Admission requires main thread, full existing snapshot-v1 decode against the actual trusted source/profile/namespace, exact validated saved-view equivalence, original mutation eligibility, actual profile-applied admission event, completed bootstrap, real external-player provider and legal idle gate acquisition. The character epoch comes from that cold-validated record; there is no newly persisted epoch/admission schema.

Each context binds actual profile, namespace, epoch, run, immutable admitted reward policy, source/rules/lineage identity and the actual admission owner. Its printed instance ID is diagnostic only: the authority is the exact privately registered object reference. Each request captures that context, original ID, immutable kind/definition/operation and the gate revision **at issuance**. Equal-looking JSON or a newly constructed Request object is not issued authority. Returned result dictionaries are copies.

Dispatch invokes only the original four source commands through a fixed switch. Original source legality, items, costs, Act timing, dice, rewards and progression remain authoritative. Expired, foreign, canceled, sealed-unexecuted or stale-revision requests reject before entering those commands or incrementing the mutation revision. Retrying an already accepted request in a still-valid window returns its copied original result without rerunning the command. Reissuing the same intent returns the same original ticket/revision; conflicting bindings reject.

Source/session/player/provider/policy replacement invalidates the admission terminally. Restoring the old field values does not resurrect it. Closing an admission leaves the gate's required-context marker on its old session. A disposed owner or attempted unbind cannot turn old raw-ID callbacks back into an ordinary accepted path.

Original asynchronous completions are bound to the issued result's actual action instance, player actor, original request, completed status, actual final causal event and effect kind. They are one-shot. Interrupted/no-effect requests cannot later consume a potion through an old completion callback. Existing action interruption remains the only way to interrupt an accepted action; this helper does not invent refunds/cancellation rules.

This is the established **trusted internal main-thread API** boundary. It is not an anti-cheat sandbox against private-field reflection, arbitrary direct dictionary writes or malicious code. New user intents must be deliberately issued in their current context; a delayed callback must not ask for a new context and recreate its old request. The raw source guard enforces that callbacks cannot bypass issuance by replaying their old string.

## 4. Capture, retirement, uncertainty and cancellation

1. At an actual legal idle READY/entry, downtime or completion boundary, acquire the original gate before collecting state. Pending player actions and concurrent mutations reject capture.
2. Validate the original current checkpoint and collect session, ledger and actual external movement as one immutable capture. Release the lease immediately.
3. Seal the old window and retain exactly one pending capture with exact object/text, local parent ordinal and operation ID. Open a fresh window immediately so original gameplay can continue. No file encoding/publication freeze is held.
4. A simulated attempted/unknown outcome may be recorded only while that exact owned capture is current. It then remains pending until exact reconciliation. Uncertain work cannot be canceled or closed away.
5. An exact simulated acknowledgement retires only the captured window. A stale capture with no earlier fresh simulated attempt cannot claim acknowledgement. Wrong bytes, old objects, duplicate acknowledgement and wrong local parent reject.
6. Retirement releases only the **new volatile** ticket/reply maps. Requests holding that old Context object still reject with those maps empty. No retired-window list is accumulated. At most one current and one pending window are owned; per-window cache size follows commands issued until safe closure, not a newly invented fixed 20-entry limit.
7. Known-unpublished capture cancellation retires its sealed window without adopting any state. Unexecuted request cancellation records a canceled result; accepted actions use original interruption rules.

The returned `head` is a **local simulated acknowledgement ordinal**, not a durable generation, CAS token or cross-process writer claim. All these APIs report `durable:false`. Acknowledgement never installs a session, actor, source profile, ledger, movement or old checkpoint. Thus reconciling an earlier capture cannot replace newer gameplay or the original service's newer committed profile. New-window actions can begin before reconciliation and complete after earlier-window retirement.

No existing command history, simulator `_accepted_request_ids`, permanent ID, snapshot evidence or receipt is deleted. Successful consumption still requires permanent irreversible debit/identity evidence in any future successor. Only temporary/no-effect request memo expiration is demonstrated here. Reload creates a fresh admission; old serialized requests are rejected, rather than being decoded as authority. Actual NEW RUN gets its own run/context while keeping the character epoch/profile.

## 5. Verified original-loader behavior and fixture corrections

The original `restore_ledger()` intentionally rebuilds selected ledger state on reload. Archived volatile maps `awards`, `drop_resolutions` and `processed_defeat_event_ids` do not necessarily byte-match the restored live maps, while original durable receipts, totals and processed actor bindings remain validated. An initially added redundant admission equality against that entire archived volatile ledger was removed from **this new helper**. No old validator was weakened. Admission retains full cold decode, exact original saved-view validation and genuine profile-applied event checks; capture validates the actual live boundary.

A preliminary NEW RUN test tried to use an abandon authorization from a just-mutated flat live view and the original service rejected `abandoned_checkpoint_changed_or_unverified`. The final test obtains authorization from the original independently verified reload boundary and succeeds. The original rejection rule is unchanged. This task does not claim every live UI/browser NEW RUN path is accepted or repaired.

Development-only parse/type diagnostics were corrected before final runs. No existing assertion was removed or weakened, and no invalid operation is counted as an expected success.

## 6. Focused verification

Godot **4.7.2 native Windows debug/headless**. Final results:

| Suite filter | Result | Explicit assertion count | Own TEMP log |
| --- | --- | ---: | --- |
| `46F temporary requests` | PASS | 140 | `arena46f-final.log` |
| `46C1 shared capture gate` | PASS | 310 | `arena46f-gate-final.log` |
| `46C2 routine transactions` | PASS | 95 | `arena46f-routine.log` |
| `46D command evidence` | PASS | 174 | `arena46f-evidence-final.log` |
| `46B minimal snapshot` | PASS | 227 | `arena46f-codec.log` |
| `Task 36C source-verified inventory and equipment` | PASS | Not emitted by existing suite | `arena46f-inventory.log` |
| `Task 36G-Fix2 shared weapon handling` | PASS | Not emitted by existing suite | `arena46f-handling.log` |

**7/7 focused suites PASS; 946 explicitly counted assertions, zero final failures.** The two older suites' assertions are additional and not guessed. The new suite also launches an actual fresh Godot subprocess against its disposable original source records; it requires `46F_COLD_PASS` and zero exit status.

Exact runner command template, executed once per listed filter:

```powershell
& 'C:/Users/mxz/Desktop/GoDot/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/test_runner.gd -- '--suite=<filter from table>'
```

Additional final checks:

```powershell
& 'C:/Users/mxz/Desktop/GoDot/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://scripts/rewards/temporary_character_requests.gd --check-only
git diff --check
```

Both pass. Separate direct whitespace checks of all six new source/test/UID files pass; each new UID occurs exactly once in scripts/tests/addons. Git prints existing CRLF-conversion advisories for the pre-existing playable persistence file and runner, without whitespace errors. No line-ending normalization was performed.

New tests cover genuine original equip/unequip, active/downtime stow/draw, real acquired potion resolution, interrupted accepted potion, no late completion effects, exact/conflicting retries, unissued/serialized objects, session/simulator/generic/auxiliary raw bypasses, gate-unbind rejection, pending/uncertain captures, cancellation, source identity invalidation, fresh reload and NEW RUN, same raw ID deliberately issued in a different run, namespace isolation and cold restart.

Whole original snapshots (including authoritative events, causal history, resources, loot/growth, source profile/generation, clock, RNG and external movement) match an unobserved original control. A second independently seeded guarded client matches as well. Rejected requests leave snapshots, original acceptance maps, source dispatch count and mutation revision unchanged. Actual NEXT WAVE and timed new-window action completion continue during earlier simulated uncertainty. This proves immediate lease release and ordering, not a browser latency benchmark.

No full regression, release export, Edge/browser storage test, actual persisted acknowledgement or live-character acceptance was run or claimed.

## 7. Preservation and remaining limits

Entry/final branch `main`; HEAD unchanged at `f9bb0db0235b0003895c477a12346191d4714469`; index empty. Task entry had **35 modified tracked files and 176 collapsed untracked status entries**. Final task state has **35 modified tracked files and 183 collapsed untracked entries**, reflecting the seven newly added files in this manifest. The capture-gate file was already untracked at entry but is an existing file modified by this task.

Scoped SHA-256 baseline covered 756 existing project files. Exactly the five existing files listed above differ; the other **751 remain byte-identical**. The new files account for the rest of this task's manifest. `project.godot` retains its pre-existing modification and exact entry SHA-256 `8398f110f77d7712eb19c283eb9f745c7123feab9557187778da412639ba5692`. Earlier codecs, #46C2 aggregate, #46D evidence, #45U instrumentation/benchmark files, UI, storage and routing are unchanged.

Protected boss DOC, `character saves/` and repository `tmp/` appear only as unchanged status names; their contents were not inspected, hashed or modified. No owner profile, backup or browser storage was accessed. Disposable source persistence and child-process fixtures use only the explicit OS-cache test roots. No Git staging, commit, push, reset, stash, rebase or cleanup occurred.

Before any later activation, real callers must preserve issued handles across all delayed callbacks, explicitly close/rebind on supported lifecycle changes, and supply separately authorized durable publication/readback/CAS integration. A pending uncertain operation must not be discarded on reload; this task demonstrates simulated ownership/reconciliation only, not crash-persistent pending records. Existing single-process trusted-API assumptions and source gate coverage continue to apply. No production UI can yet use this dormant helper, and no existing IDs may be pruned on this task's authority.

**GO for designing the compact successor format without lifetime temporary-command history.** The narrowly tested prerequisite is satisfied for the supported trusted API and simulated checkpoint contract. This is **not** approval for history deletion, successor implementation, #46C2 resumption, storage routing, migration or production activation.
