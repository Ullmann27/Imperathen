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



def assignment_control(focused=-1, *, visible=True, center=None, enabled=True,
                       control_id="control-1", popup_id="popup-1"):
    labels = ["Frei / Erholen", "Dorffelder", "Holzfällerlager", "Steinbruch",
              "Handelsplatz", "Stadtposten", "Verteidigung"]
    return {"center": [728.625, 376.5] if center is None else center,
            "visible": visible, "enabled": enabled, "selected": 0,
            "instance_id": control_id,
            "popup": {"visible": True, "focused": focused, "instance_id": popup_id,
                      "items": [{"index": index, "text": text, "enabled": True}
                                for index, text in enumerate(labels)]}}


class VillageStableControlTest(unittest.TestCase):
    def test_inertial_movement_requires_two_fresh_unchanged_positions(self):
        controls = [assignment_control(center=[728.625, value])
                    for value in [376.5, 402.75, 402.75]]
        read = Mock(side_effect=controls)
        result = SMOKE.wait_for_stable_village_control(read)
        self.assertIs(result, controls[-1])
        self.assertEqual(read.call_count, 3)

    def test_rebuilt_control_must_establish_its_own_stable_position(self):
        controls = [assignment_control(control_id=value)
                    for value in ["control-1", "control-2", "control-2"]]
        read = Mock(side_effect=controls)
        result = SMOKE.wait_for_stable_village_control(read)
        self.assertEqual(result["instance_id"], "control-2")
        self.assertEqual(read.call_count, 3)

    def test_invisible_or_disabled_control_cannot_be_used_for_a_tap(self):
        controls = [assignment_control(), assignment_control(visible=False),
                    assignment_control(), assignment_control()]
        read = Mock(side_effect=controls)
        SMOKE.wait_for_stable_village_control(read)
        self.assertEqual(read.call_count, 4)
        with self.assertRaisesRegex(RuntimeError, "absent or disabled"):
            SMOKE.wait_for_stable_village_control(Mock(return_value=assignment_control(enabled=False)))

    def test_unsettled_geometry_is_a_bounded_failure(self):
        read = Mock(side_effect=[assignment_control(center=[728.625, value])
                                 for value in [100, 120, 150]])
        with self.assertRaisesRegex(RuntimeError, "stable native coordinates"):
            SMOKE.wait_for_stable_village_control(read, max_observations=3)
        self.assertEqual(read.call_count, 3)


class VillagePopupNavigationTest(unittest.TestCase):
    def test_touch_keyboard_and_already_focused_popups_use_observed_rows(self):
        for focuses, expected_downs in [([-1, 0, 1, 2], 3), ([0, 1, 2], 2), ([2], 0)]:
            with self.subTest(focuses=focuses):
                observe = Mock(side_effect=[assignment_control(value) for value in focuses])
                press = Mock()
                result = SMOKE.activate_observed_village_popup(observe, press, "Holzfällerlager")
                self.assertEqual([call.args[0] for call in press.call_args_list],
                                 ["KEYCODE_DPAD_DOWN"] * expected_downs + ["KEYCODE_ENTER"])
                self.assertEqual([call.args[0] for call in observe.call_args_list],
                                 [None] + focuses[:-1])
                self.assertEqual(result["focused_index"], 2)
                self.assertEqual(result["down_presses"], expected_downs)

    def test_unobserved_focus_progress_cannot_confirm_the_wrong_row(self):
        observe = Mock(side_effect=[assignment_control(0), assignment_control(0)])
        press = Mock()
        with self.assertRaisesRegex(RuntimeError, "focus did not progress"):
            SMOKE.activate_observed_village_popup(observe, press, "Holzfällerlager")
        self.assertEqual([call.args[0] for call in press.call_args_list], ["KEYCODE_DPAD_DOWN"])

    def test_popup_must_belong_to_the_control_actually_tapped(self):
        observe = Mock(return_value=assignment_control(2, control_id="replacement"))
        press = Mock()
        with self.assertRaisesRegex(RuntimeError, "control changed after the native tap"):
            SMOKE.activate_observed_village_popup(
                observe, press, "Holzfällerlager", expected_control_instance="original")
        press.assert_not_called()

    def test_closed_popup_never_receives_confirmation(self):
        closed = assignment_control(1)
        closed["popup"]["visible"] = False
        observe = Mock(side_effect=[assignment_control(0), closed])
        press = Mock()
        with self.assertRaisesRegex(RuntimeError, "closed or became unavailable"):
            SMOKE.activate_observed_village_popup(observe, press, "Holzfällerlager")
        self.assertEqual([call.args[0] for call in press.call_args_list], ["KEYCODE_DPAD_DOWN"])

    def test_replaced_popup_never_reuses_previous_focus_assumptions(self):
        observe = Mock(side_effect=[assignment_control(0), assignment_control(2, popup_id="new-popup")])
        press = Mock()
        with self.assertRaisesRegex(RuntimeError, "replaced during navigation"):
            SMOKE.activate_observed_village_popup(observe, press, "Holzfällerlager")
        self.assertEqual([call.args[0] for call in press.call_args_list], ["KEYCODE_DPAD_DOWN"])

    def test_missing_duplicate_or_disabled_target_stops_before_any_input(self):
        disabled = assignment_control(2)
        disabled["popup"]["items"][2]["enabled"] = False
        duplicate = assignment_control(2)
        duplicate["popup"]["items"][1]["text"] = "Holzfällerlager"
        missing = assignment_control(2)
        missing["popup"]["items"][2]["text"] = "Anderer Ort"
        for control in [disabled, duplicate, missing]:
            with self.subTest(control=control):
                press = Mock()
                with self.assertRaisesRegex(RuntimeError, "unique enabled target"):
                    SMOKE.activate_observed_village_popup(Mock(return_value=control), press, "Holzfällerlager")
                press.assert_not_called()

    def test_catalog_change_before_confirmation_is_rejected(self):
        changed = assignment_control(2)
        changed["popup"]["items"][0]["text"] = "Anderer Auftrag"
        observe = Mock(side_effect=[assignment_control(0), changed])
        press = Mock()
        with self.assertRaisesRegex(RuntimeError, "items changed"):
            SMOKE.activate_observed_village_popup(observe, press, "Holzfällerlager")
        self.assertEqual([call.args[0] for call in press.call_args_list], ["KEYCODE_DPAD_DOWN"])

    def test_navigation_limit_still_fails_without_enter(self):
        observe = Mock(side_effect=[assignment_control(-1), assignment_control(0)])
        press = Mock()
        with self.assertRaisesRegex(RuntimeError, "bounded navigation"):
            SMOKE.activate_observed_village_popup(observe, press, "Holzfällerlager", max_moves=1)
        self.assertEqual([call.args[0] for call in press.call_args_list], ["KEYCODE_DPAD_DOWN"])

    def test_navigation_deadline_still_fails_without_enter(self):
        observe = Mock(return_value=assignment_control(-1))
        press = Mock()
        with patch.object(SMOKE.time, "monotonic", side_effect=[0, 0, 121]):
            with self.assertRaisesRegex(RuntimeError, "Timed out"):
                SMOKE.activate_observed_village_popup(observe, press, "Holzfällerlager", timeout=120)
        self.assertEqual([call.args[0] for call in press.call_args_list], ["KEYCODE_DPAD_DOWN"])


if __name__ == "__main__":
    unittest.main()
