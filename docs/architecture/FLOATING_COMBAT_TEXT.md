# Floating Combat Text

## Authority boundary

Floating combat text is a local presentation projection of committed `CombatEvent` records. `ArenaFloatingCombatText` receives each event once from `ArenaCombatController`; it cannot call `CombatSimulation`, schedule actions, consume RNG, or modify actor state. Reset clears visual messages and delivery deduplication state. The compact results panel and FULL LOG remain the accessibility-friendly textual records.

## Event mapping and ownership

| Authoritative event | Floating text | Owner | Notes |
| --- | --- | --- | --- |
| `physical_attack_accuracy_resolved` | `HIT!` or `MISS!` | Attacker | Ordinary ACC only. Critical rolls wait for their committed critical record. |
| `physical_defense_attempted` | `<DEFENSE> FAILED` | Defender | Only a failed attempt. It never claims a successful defense. |
| `physical_defense_resolved` | `DODGE!`, `WEAPON BLOCK!`, `SHIELD BLOCK!`, or `SOAK!` | Defender | Only when the authoritative resolution selected a successful defense. |
| `critical_trigger_recorded` | `CRIT HIT! <Recorded Outcome>` or `CRIT FAIL! <Recorded Outcome>` | Roll source | Uses the authoritative `outcome_id`; it does not infer a consequence. |
| `critical_perfect_evasion_applied` | `PERFECT EVASION!` | Defender | Appears only after the approved effect is committed. |
| `critical_stagger_applied` | `STAGGER!` | `affected_actor_id` | The effect event carries explicit presentation ownership. |
| `critical_prone_applied` | `PRONE!` | `affected_actor_id` | The effect event carries explicit presentation ownership. |
| `critical_reaction_started` | `CRITICAL REACTION!` | Reactor | This remains separate from ordinary Acts. |
| `physical_attack_interrupted` or `action_interrupted` | `INTERRUPTED!` | Interrupted actor | Uses the action relationship, not formatted log text. |
| `physical_damage_resolved` | `-<N> HPC`, plus `DEFEATED!` at zero HPC | Damaged target | Only committed final damage produces this text. |

Unavailable or blocked effects remain in the transcript rather than generating speculative combat text.

## Visual behavior

Messages use a restrained semantic palette: green defenses, gold critical successes, red critical failures and harmful conditions, orange damage, and light neutral ordinary outcomes. Labels have a dark outline, rise slightly, fade after 0.9 seconds (1.15 seconds for important outcomes), ignore pointer input, and do not change gameplay timing.

Each actor has three stable vertical lanes. The layer permits up to four active labels per actor and ten overall. A higher-priority outcome may replace a lower-priority local visual when necessary; this never deletes the authoritative event or transcript record. Event delivery is deduplicated by authoritative event ID only after the event type can produce floating feedback and the mapped result is nonempty. Movement and other non-presentable records are therefore not retained in local duplicate bookkeeping. Distinct out-of-order committed combat events remain distinct.

Labels follow their actor each rendered frame, including walking, Running, Dodge displacement, prone, and Stagger. Their position is clamped to the visible canvas with a top safe region so they do not cover the toolbar. Actor/HPC label separation from Task 20 is unchanged.

## Scope limits

This layer does not animate attacks, invent effects, or display raw event IDs/RNG/payloads. It is tested against desktop and mobile-sized landscape layouts; physical Android validation remains deferred.
