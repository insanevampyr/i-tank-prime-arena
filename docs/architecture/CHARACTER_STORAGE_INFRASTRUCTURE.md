# Task 36E: isolated local character-document storage

No gameplay integration is enabled. `CharacterSaveStorage` is called only by isolated tests. NORMAL/TEST MODE, rewards, RESET, encounters and schema-12 snapshots have no new storage callers. Task 36D retention-policy gates remain controlling.

## Interface and publication

- `get_storage_status()` reports desktop readiness or an explicit Web/unconfigured-root gate.
- `write_profile(profile_id, payload, transaction_id)` validates v1 through `CharacterSaveContract`, serializes canonical JSON, acquires a profile writer directory, checks durable transaction receipts and current generation, writes `write.pending`, flushes/closes, rereads/validates, renames to an immutable generation file, and rereads the result.
- `read_profile(profile_id)` returns the highest valid generation with exact character document text, payload and transaction ID. Corrupt generations are listed explicitly when an earlier valid generation is returned. It never creates empty progression on failure. Unknown future versions fail closed instead of downgrading.

The application root is `user://character_documents`. Profile and transaction IDs accept only lowercase ASCII letters, digits, underscore and hyphen, maximum 64 characters. Profile identity must equal the character ID. Test roots are restricted to unique subdirectories of `OS.get_cache_dir()/itank-storage-tests/`; tests never write live `user://` saves. No arbitrary caller-selected production paths or path separators are accepted. This protects application path construction, not hostile OS-level modification/symlinks of the save directory.

Generation files retain transaction IDs as durable receipts. All previous generations are retained in this bounded infrastructure pass; pruning is deferred because it would require an approved durable receipt-compaction policy. Initial generation must be one; later writes must pass the contract's identity, next-generation and secured-checkpoint checks. Loading returns a whole document; it does not merge XP/items or re-execute purchases. The layer validates structural data only and does not authorize rewards or validate Prime purchase legality.

## Safety and limits

The active document is selected from complete generation files rather than overwriting one pointer file. Same-directory rename publishes the candidate while all previous valid files remain untouched. This is a deliberate implementation of replacement through generation selection, without changing the character v1 format. The outer storage wrapper v1 contains transaction ID and the exact character document; the character checksum detects document corruption, not malicious editing or authenticated receipts.

Failed temporary writes, verification failures, existing pending files, corrupt generation history and writer-lock contention return meaningful failure codes. A pending file is ignored by reads and blocks writes until explicit future recovery review; it is not automatically promoted or deleted. Corrupt current/backup files remain intact for inspection. A returned older valid generation is marked recovery and cannot be silently written over the damaged history. A stale writer lock also requires review; no time-based lock stealing exists.

Exclusive directory creation guards cooperative desktop writers using this coordinator. It is not a guarantee against another program editing files, copied rollback saves, symlinks or a filesystem with different semantics. Errors after publication may leave a committed generation despite an unsuccessful acknowledgement; the caller must reread and inspect its transaction ID, never invent a new reward or blindly retry under a new transaction. Flush/close/rename checks are tested normal filesystem operations, not a proven power-loss transaction or fsync guarantee. No automatic backup rewrite occurs.

Web reads can inspect available virtual `user://` data. Writes return `web_write_coordination_unverified` with `state=unverified` and the official `OS.is_userfs_persistent()` availability flag. That flag does not confirm an asynchronous IndexedDB commit. No Web save success/durability is claimed, and cross-tab races are blocked by disabling Web writes. A future browser adapter requires tested synchronization completion and an enforceable per-profile writer policy before activation. Private mode, quota, eviction, cleared browser data and origin/device changes remain storage-loss risks. No cloud backup exists.

References: [Godot FileAccess](https://docs.godotengine.org/en/stable/classes/class_fileaccess.html), [Godot Web persistence](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html#using-persistent-user-data). Installed Godot 4.7.2 runs the automated desktop checks.

## Validation and home checklist

Disposable cache fixtures cover canonical write/read equality, profile isolation, sequential/stale/duplicate writes, invalid IDs, malformed candidates, lock contention, interrupted pending files, preservation of prior generations, corrupt-current recovery, corrupt-backup rejection, future-version rejection and unchanged XP/item provenance. Tests remove only their own explicitly created cache files/directories. They have no reference to live saves or gameplay authority.

Owner checks later: inspect fresh local Web behavior and explicit write-unverified status; verify storage denial/private mode/quota and two-tab behavior before implementing a browser writer. Desktop crash/power-loss tests, stale-lock recovery UI, rollback policy, receipt compaction and deployment storage acceptance remain unverified/deferred. No player save/load controls exist. Task 36D's failure, consumption, item loss, abandonment and daily-effect retention decisions remain pending. Do not connect this infrastructure to gameplay until those policies and browser acceptance are approved.
