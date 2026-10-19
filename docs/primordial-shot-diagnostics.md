# Primordial per-shot fault log

Every result row of the dev build now carries `dx` (the named fault), `dxc` (`data` = shown by the logged values, `infer` = the most likely cause, NOT proven) and `dxd` (the detail), plus the fire-time facts `fa` (age of the newest record in seconds), `fr` (record was fresh), `jc` (jitter confidence), `fe` (eye yaw at fire) and `hl` (age of a held angle). Nothing is sent without the dev plan; the script prints one `dx` line per miss when the miss event logs are on.

Faults: `attr_lost`, `spread`, `low_hitchance`, `occlusion`, `death_race`, `server_reject`, `enemy_defensive`, `enemy_lagbreak`, `no_value`, `held_value`, `stale_record`, `target_turned`, `jitter_side`, `repeat_miss`, `old_record`, `high_latency`, `extrapolation`, `angle_wrong`, `diag_error`.

The real angle of an enemy is not readable, so `angle_wrong` and the other `infer` faults are the most likely cause, not a proof. Read the summary with `python3 tests/primordial_diagnosis.py dump.txt`.

The change is applied by `tools/apply_primordial_diagnostics.py` (uniquely matched fragments, the rest of the Lua stays as it is). The workflow checks it with LuaJIT tests and commits the Lua to the feature branch only after every check is green.
