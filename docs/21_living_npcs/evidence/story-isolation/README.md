# Story workflow save isolation

The story workflow previously ran its Godot scenarios with a shared `user://`
directory. `childhood_integration_test.gd` leaves a real campaign, backup and
opening checkpoint. The following `opening_flow_test.gd` then reaches the valid
overwrite-confirmation dialog instead of creating a new life. Its assumption
that a cinematic director already exists causes a null-camera script error;
the interrupted test coroutine never reaches `quit()`.

The workflow now creates fresh data, config and cache directories for each of
its seven existing Godot checks. Every invocation sets
`IMPERATHEN_ISOLATED_TEST=1` and runs under a 120-second timeout, followed by a
forced termination after a further 10 seconds if necessary. Test arguments and
the production confirmation dialog are unchanged.

## Targeted verification

Only the previously colliding pair was rerun, in that order. No import or broad
test suite was executed. `run-targeted.sh` contains the exact isolation function
extracted from the changed workflow; both workflow copies were verified to be
identical. The helper passed `bash -n`. The original seven test calls and their
order were checked against the workflow.

| Check | Exit | Marker | Assertions | Seconds |
| --- | --- | --- | --- | --- |
| Childhood integration | 0 | `CHILDHOOD_INTEGRATION_PASS` | 96, zero failures | 4.411 |
| Opening flow | 0 | `OPENING_FLOW_PASS` | 45, zero failures | 4.557 |

Both checks used Godot `4.7.2.stable.official.ed1daf0bf`, produced no engine script
errors and received different temporary state roots. `verification.json`
records the exact commands, workflow SHA-256, isolated paths, exit codes and
markers. The full outputs are `childhood_integration.log` and `opening_flow.log`.

From the repository root, the targeted sequence can be repeated with:

```bash
export GODOT_BIN="$(command -v godot)"
export RUNNER_TEMP="$(mktemp -d)"
export GODOT_SILENCE_ROOT_WARNING=1
bash docs/21_living_npcs/evidence/story-isolation/run-targeted.sh --fixed-fps 60 --script res://tests/childhood_integration_test.gd
bash docs/21_living_npcs/evidence/story-isolation/run-targeted.sh --fixed-fps 60 --script res://tests/opening_flow_test.gd
```

This is a local targeted verification of the CI isolation change, not a claim
that a new remote workflow run or the whole engine suite has completed.
