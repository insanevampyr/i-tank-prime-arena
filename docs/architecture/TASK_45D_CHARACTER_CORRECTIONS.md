# Task 45D - Character corrections

## Historical Vaelis Dodge

The owner-approved original split is DEX9 / DT6 / DP3. Earlier sources and
existing immutable histories use 3/6. Runtime derivation corrects only exact
allowlisted Vaelis lineage (pre-Balance fingerprint 3df0412b72ba5d966b2eb645887fedfbb591782cffc7bff41c192e52583c6d20;
verified Balance provenance can evolve separately). The saved source fingerprint,
raw development baseline, commands, purchase choices and receipts are unchanged.
The corrected baseline is replayed in memory before permanent/temporary allocation
and equipment/effect modifiers. Three original DT purchases therefore give 9/3
at DEX12. DP purchase choices are preserved, never reassigned. Other authored
characters or changed source statistics do not receive this correction.

## Arena Mana recovery

Printed V3 MR/H charts stay unchanged. Arena MR/Min is effective WIS / 2.
Only eligible active-wave simulation time recovers Mana. READY, downtime,
menus, focus suspension, stopped simulation and pending browser publication
cannot add eligible time. Combat may otherwise continue during inspection.
Integer remainder units use a denominator of 120,000,000: one microsecond at
WIS1 adds one unit. Only whole Mana is awarded, capped at maximum. Recovery
boundaries and WIS-effect expiration split elapsed simulation time; later WIS
changes never reprice earlier time. Saturation discards excess recovery.
There is no wall-clock recovery, RNG draw, HP/Blood regeneration or learning grant.
MSL is shown from the verified WIS chart when no explicit authored value exists;
it is a reference, not an implemented Special-learning permission.

Existing schema-12 progression dictionaries carry the bounded transient integer
mana_recovery_units. The existing version-1 checkpoint player dictionary accepts
the same OPTIONAL integer (0 through 119,999,999); absence means no prior fraction.
No envelope version or simulation schema version changes. Legacy V2/V4/V5
records without the field remain valid and are never rewritten on load. New
checkpoints capture the current remainder through the existing coordinator;
resume/reload restore it without ticking. RETRY restores the verified entry;
NEW RUN keeps committed history and does not replay discarded elapsed time.
Existing authorized wave/new-run resource restoration remains separate.

## Experience presentation

The Attributes tab shows level, cumulative EXPM, available EXPC, recorded purchase
spending and numeric/bar progress. For current level L, progress is EXPM minus
threshold(L), divided by threshold(L+1) minus threshold(L). EXPC and EXPC-only
credits never enter that calculation. The verified class/EXP Type catalog remains
authoritative. Missing or inconsistent evidence and unsupported thresholds display
unavailable; level20 has no invented next threshold. Projection/rendering is read-only.
