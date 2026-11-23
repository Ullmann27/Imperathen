"""Synthetic log timing regressions; these are not Android device evidence."""

import importlib.util
import json
from pathlib import Path
import unittest
from unittest.mock import Mock, patch


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("android_runtime_smoke", ROOT / "tools/android_runtime_smoke.py")
SMOKE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(SMOKE)


def snapshot(*, screen="village_panel", assignment=None, assigned="idle", permitted=True):
    state = {"screen": screen, "controls": {"work_tab": {"visible": True, "enabled": True}},
             "aelia_assignment": assigned, "work_permit": permitted}
    if assignment is not None:
        state["controls"]["aelia_assignment"] = assignment
    return state


def log(*states):
    return "\n".join("11-23 06:29:24.039 3015 3078 I godot: "
                     + SMOKE.VILLAGE_RUNTIME_MARKER + json.dumps(state) for state in states)


class VillageRuntimeWaitTest(unittest.TestCase):
    def setUp(self):
        self.now = 0.0
        self.clock = patch.object(SMOKE.time, "monotonic", lambda: self.now)
        self.sleep = patch.object(SMOKE.time, "sleep", self.advance)
        self.clock.start()
        self.sleep.start()
        self.addCleanup(self.clock.stop)
        self.addCleanup(self.sleep.stop)

    def advance(self, seconds):
        self.now += seconds

    def test_delayed_tab_switch_waits_for_control_in_a_new_snapshot(self):
        overview = snapshot()
        selector = {"visible": False, "enabled": True, "center": [470, 1500], "selected": 0}
        work = snapshot(assignment=selector)
        # adb input returned, but Godot and then its periodic observer have not
        # yet processed the new tab. Another overview sample is not sufficient.
        logs = Mock(side_effect=[log(overview), log(overview, overview), log(overview, overview, work)])
        result = SMOKE.wait_for_village_snapshot(logs, "village_panel", after=1,
                                                 required_control="aelia_assignment", timeout=5)
        self.assertEqual(result, work)
        self.assertEqual(logs.call_count, 3)
        self.assertFalse(result["controls"]["aelia_assignment"]["visible"])

    def test_matching_snapshot_from_before_input_cannot_satisfy_freshness(self):
        work = snapshot(assignment={"visible": True, "enabled": True, "selected": 0})
        fresh = snapshot(assignment={"visible": True, "enabled": True, "selected": 2}, assigned="woodcamp")
        logs = Mock(side_effect=[log(work), log(work), log(work, fresh)])
        result = SMOKE.wait_for_village_snapshot(logs, "village_panel", after=1,
                                                 required_control="aelia_assignment", timeout=5)
        self.assertEqual(result, fresh)
        self.assertEqual(logs.call_count, 3)

    def test_only_latest_state_can_prove_worker_assignment(self):
        assigned = snapshot(assigned="woodcamp")
        idle = snapshot(assigned="idle")
        logs = Mock(side_effect=[log(assigned, idle), log(assigned, idle, assigned)])
        result = SMOKE.wait_for_village_snapshot(logs, "village_panel", after=0,
                                                 predicate=lambda state: state["aelia_assignment"] == "woodcamp",
                                                 timeout=5)
        self.assertEqual(result, assigned)
        self.assertEqual(logs.call_count, 2)

    def test_missing_control_remains_a_bounded_failure(self):
        logs = Mock(return_value=log(snapshot()))
        with self.assertRaisesRegex(RuntimeError, r"required control: aelia_assignment.*work_tab"):
            SMOKE.wait_for_village_snapshot(logs, "village_panel", required_control="aelia_assignment", timeout=3)
        self.assertEqual(logs.call_count, 3)
        self.assertEqual(self.now, 3)

    def test_same_screen_name_never_replaces_required_control(self):
        unrelated = snapshot(screen="village_dialog", assignment={"visible": True, "enabled": True})
        logs = Mock(return_value=log(unrelated))
        with self.assertRaisesRegex(RuntimeError, "No matching village runtime state: village_panel"):
            SMOKE.wait_for_village_snapshot(logs, "village_panel", required_control="aelia_assignment", timeout=2)

    def test_disabled_control_is_not_hidden_by_retrying_until_enabled(self):
        disabled = snapshot(assignment={"visible": True, "enabled": False})
        logs = Mock(return_value=log(disabled))
        result = SMOKE.wait_for_village_snapshot(logs, "village_panel", required_control="aelia_assignment", timeout=5)
        self.assertFalse(result["controls"]["aelia_assignment"]["enabled"])
        self.assertEqual(logs.call_count, 1)
        self.assertEqual(self.now, 0)

    def test_game_errors_abort_without_a_timeout_retry(self):
        logs = Mock(side_effect=RuntimeError("SCRIPT ERROR: invalid worker state"))
        with self.assertRaisesRegex(RuntimeError, "SCRIPT ERROR"):
            SMOKE.wait_for_village_snapshot(logs, "village_panel", required_control="aelia_assignment", timeout=5)
        self.assertEqual(logs.call_count, 1)
        self.assertEqual(self.now, 0)

    def test_absent_diagnostics_cannot_produce_success(self):
        logs = Mock(return_value="11-23 06:29:24 I godot: rendering frame")
        with self.assertRaisesRegex(RuntimeError, r"last observed: \{\}"):
            SMOKE.wait_for_village_snapshot(logs, "village_panel", timeout=2)
        self.assertEqual(logs.call_count, 2)


if __name__ == "__main__":
    unittest.main()
