# UI Scripts

Presentation and input controllers live here and must not decide authoritative combat outcomes. The current controllers provide responsive Arena layout, multitouch movement/Running, one-shot ordinary attack/stand intent, target/HPC status, mouse/touch START/RESET and event-log rendering. ACC, defense, critical, damage, opponent behavior legality and state mutation remain behind `ArenaCombatSession` in `CombatSimulation`; unsupported controls remain absent.
