"""Synthetic log timing regressions; these are not Android device evidence."""

import base64
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



def chunk_lines(state, sequence=1, observer="12345"):
    encoded = base64.b64encode(json.dumps(state, ensure_ascii=False,
                                          separators=(",", ":")).encode("utf-8")).decode("ascii")
    parts = [encoded[index:index + SMOKE.VILLAGE_CHUNK_SIZE]
             for index in range(0, len(encoded), SMOKE.VILLAGE_CHUNK_SIZE)]
    return ["11-23 12:41:59.122 2971 3036 I godot: " + SMOKE.VILLAGE_CHUNK_MARKER
            + f"{observer}-{sequence} {index} {len(parts)} {part}"
            for index, part in enumerate(parts)]


class VillageChunkTransportTest(unittest.TestCase):
    def setUp(self):
        self.now = 0.0
        clock = patch.object(SMOKE.time, "monotonic", lambda: self.now)
        sleeper = patch.object(SMOKE.time, "sleep", self.advance)
        clock.start()
        sleeper.start()
        self.addCleanup(clock.stop)
        self.addCleanup(sleeper.stop)

    def advance(self, seconds):
        self.now += seconds

    def large_snapshot(self, **kwargs):
        value = snapshot(**kwargs)
        value["feedback"] = "Holzfällerlager · Grüße · 森林 · 🏛\n" * 50
        return value

    def test_large_unicode_snapshot_round_trips_with_short_ascii_log_lines(self):
        value = self.large_snapshot(assigned="woodcamp")
        lines = chunk_lines(value)
        self.assertGreater(len(lines), 1)
        self.assertTrue(all(len(line.encode("ascii")) < 1024 for line in lines))
        result = SMOKE.wait_for_village_snapshot(
            Mock(return_value="\n".join(lines)), "village_panel",
            predicate=lambda state: state["aelia_assignment"] == "woodcamp")
        self.assertEqual(result, value)

    def test_newest_partial_frame_blocks_older_complete_matching_state(self):
        older = chunk_lines(self.large_snapshot(assigned="woodcamp"), sequence=1)
        newer = chunk_lines(self.large_snapshot(assigned="idle"), sequence=2)
        logs = Mock(return_value="\n".join(older + newer[:1]))
        with self.assertRaisesRegex(RuntimeError, "incomplete_frame"):
            SMOKE.wait_for_village_snapshot(
                logs, "village_panel", predicate=lambda state: state["aelia_assignment"] == "woodcamp",
                timeout=2)
        self.assertEqual(logs.call_count, 2)

    def test_action_cursor_includes_started_partial_frame_and_requires_a_new_one(self):
        before = chunk_lines(self.large_snapshot(assigned="idle"), sequence=9)
        next_frame = chunk_lines(self.large_snapshot(assigned="woodcamp"), sequence=10)
        cursor = SMOKE.village_runtime_cursor("\n".join(before[:1]))
        self.assertEqual(cursor, ("chunk", "12345", 9))
        logs = Mock(side_effect=["\n".join(before), "\n".join(before + next_frame)])
        result = SMOKE.wait_for_village_snapshot(logs, "village_panel", after=cursor, timeout=3)
        self.assertEqual(result["aelia_assignment"], "woodcamp")
        self.assertEqual(logs.call_count, 2)

    def test_partial_latest_frame_completes_without_falling_back(self):
        first = chunk_lines(self.large_snapshot(assigned="idle"), sequence=1)
        second = chunk_lines(self.large_snapshot(assigned="woodcamp"), sequence=2)
        logs = Mock(side_effect=["\n".join(first + second[:1]), "\n".join(first + second)])
        result = SMOKE.wait_for_village_snapshot(logs, "village_panel", after=("chunk", "12345", 1),
                                                 timeout=3)
        self.assertEqual(result["aelia_assignment"], "woodcamp")
        self.assertEqual(logs.call_count, 2)

    def test_interleaved_frames_never_mix_chunks_or_replace_the_latest_frame(self):
        first_value = self.large_snapshot(assigned="idle")
        second_value = self.large_snapshot(assigned="woodcamp")
        first = chunk_lines(first_value, sequence=1)
        second = chunk_lines(second_value, sequence=2)
        interleaved = first[:1] + second[:1] + first[1:] + second[1:]
        records = SMOKE.village_runtime_observations("\n".join(interleaved))
        self.assertEqual([record["snapshot"] for record in records], [first_value, second_value])
        self.assertEqual(SMOKE.village_runtime_cursor("\n".join(interleaved)), ("chunk", "12345", 2))

    def test_missing_old_fragment_does_not_poison_a_newer_complete_frame(self):
        old = chunk_lines(self.large_snapshot(assigned="idle"), sequence=1)
        new = chunk_lines(self.large_snapshot(assigned="woodcamp"), sequence=2)
        result = SMOKE.wait_for_village_snapshot(Mock(return_value="\n".join(old[:1] + new)),
                                                 "village_panel", after=("chunk", "12345", 1))
        self.assertEqual(result["aelia_assignment"], "woodcamp")

    def test_duplicate_conflicts_and_changed_counts_are_rejected(self):
        parts = chunk_lines(self.large_snapshot())
        prefix, payload = parts[0].split(SMOKE.VILLAGE_CHUNK_MARKER, 1)
        fields = payload.split(" ")
        conflicting_data = fields.copy()
        conflicting_data[-1] = ("A" if fields[-1][0] != "A" else "B") + fields[-1][1:]
        conflicting_total = fields.copy()
        conflicting_total[2] = str(int(fields[2]) + 1)
        for replacement in [conflicting_data, conflicting_total]:
            with self.subTest(replacement=replacement[:3]):
                duplicate = prefix + SMOKE.VILLAGE_CHUNK_MARKER + " ".join(replacement)
                with self.assertRaisesRegex(RuntimeError, "Conflicting"):
                    SMOKE.village_runtime_observations("\n".join([parts[0], duplicate]))

    def test_malformed_truncated_and_oversized_chunks_are_rejected(self):
        marker = SMOKE.VILLAGE_CHUNK_MARKER
        cases = [
            marker + "12345-1 0 65 " + "A" * 512,
            marker + "12345-1 1 1 e30=",
            marker + "12345-1 0 2 " + "A" * 511,
            marker + "12345-1 0 1 " + "A" * 513,
            marker + "12345-1 0 1 not%base64",
            marker + "12345-1 0",
            marker + "12345-1 0 1 A",
        ]
        for text in cases:
            with self.subTest(text=text[:80]):
                with self.assertRaises(RuntimeError):
                    SMOKE.village_runtime_observations(text)

    def test_invalid_utf8_json_or_nonfinite_values_cannot_be_accepted(self):
        for payload in [b"\xff", b'{"screen":', b"[]", b'{"value":NaN}']:
            with self.subTest(payload=payload):
                encoded = base64.b64encode(payload).decode("ascii")
                text = SMOKE.VILLAGE_CHUNK_MARKER + "12345-1 0 1 " + encoded
                with self.assertRaises(RuntimeError):
                    SMOKE.village_runtime_observations(text)

    def test_producer_replacement_or_sequence_reversal_fails(self):
        one = chunk_lines(snapshot(), sequence=9)
        other = chunk_lines(snapshot(), sequence=10, observer="67890")
        reversed_sequence = chunk_lines(snapshot(), sequence=8)
        for tail in [other, reversed_sequence]:
            with self.subTest(tail=tail[0][:90]):
                with self.assertRaises(RuntimeError):
                    SMOKE.village_runtime_observations("\n".join(one + tail))
        with self.assertRaisesRegex(RuntimeError, "stream changed after input"):
            SMOKE.wait_for_village_snapshot(
                Mock(return_value="\n".join(other)), "village_panel", after=("chunk", "12345", 9))

    def test_frame_history_is_bounded(self):
        lines = []
        for sequence in range(1, SMOKE.MAX_VILLAGE_FRAMES + 2):
            lines.extend(chunk_lines(snapshot(), sequence=sequence))
        with self.assertRaisesRegex(RuntimeError, "bounded frame history"):
            SMOKE.village_runtime_observations("\n".join(lines))

    def test_legacy_frames_keep_freshness_and_missing_diagnostics_do_not_pass(self):
        initial = snapshot(assigned="idle")
        updated = snapshot(assigned="woodcamp")
        cursor = SMOKE.village_runtime_cursor(log(initial))
        self.assertEqual(cursor, ("legacy", None, 1))
        logs = Mock(side_effect=[log(initial), log(initial, updated)])
        result = SMOKE.wait_for_village_snapshot(logs, "village_panel", after=cursor, timeout=3)
        self.assertEqual(result, updated)
        self.assertEqual(SMOKE.village_runtime_cursor("unrelated log output"), -1)


def action_snapshot(**changes):
    state = {"version": 1, "mode": "person", "ui_view": "game", "world_active": True,
             "running": False, "touch_camera_managed": True, "selected_technique": "jab_left",
             "overlay": "none", "position": [2.0, 1.0, 9.0], "velocity": [0.0, 0.0, 0.0],
             "body_velocity": [0.0, 0.0, 0.0], "move_axis": [0.0, 0.0], "movement_touch": -1,
             "camera_touches": 0, "action_touches": 0, "world_camera_touches": 0}
    state.update(changes)
    return {"screen": "playing", "action_mode": "unarmed", "action_runtime": state, "controls": {}}


def movement_pad():
    return {"center": [210.0, 370.0], "rect": [110.0, 270.0, 200.0, 200.0],
            "visible": True, "enabled": True, "instance_id": "movement-1",
            "axis_points": {"center": [210.0, 370.0], "right": [274.0, 370.0]}}


class ActionRuntimeObservationTest(unittest.TestCase):
    def test_missing_or_incompatible_action_diagnostics_cannot_pass(self):
        for value in ({}, {"action_runtime": {}}, action_snapshot(version=2), action_snapshot(version=True)):
            with self.subTest(value=value):
                with self.assertRaisesRegex(RuntimeError, "Missing or unsupported"):
                    SMOKE.action_input_is_neutral(value)

    def test_active_contact_or_nonzero_world_input_is_never_neutral(self):
        changes = [{"movement_touch": 0}, {"camera_touches": 1}, {"action_touches": 1},
                   {"world_camera_touches": 1}, {"move_axis": [0.2, 0]},
                   {"body_velocity": [0.0, 0.0, 0.4]}]
        self.assertTrue(SMOKE.action_input_is_neutral(action_snapshot()))
        for change in changes:
            with self.subTest(change=change):
                self.assertFalse(SMOKE.action_input_is_neutral(action_snapshot(**change)))

    def test_invalid_coordinates_or_boolean_numbers_abort_the_observation(self):
        for values in ([float("nan"), 1, 9], [2, float("inf"), 9], [True, 1, 9], [2, 9], "2,1,9"):
            with self.subTest(values=values):
                with self.assertRaisesRegex(RuntimeError, "Invalid observed action vector"):
                    SMOKE.action_position_distance(action_snapshot(position=values), action_snapshot())

    def test_invalid_contact_counts_and_flag_types_are_rejected(self):
        for change in ({"movement_touch": False}, {"camera_touches": -1},
                       {"action_touches": 33}, {"running": 1}, {"world_active": None}):
            with self.subTest(change=change):
                with self.assertRaisesRegex(RuntimeError, "Invalid observed action"):
                    SMOKE.action_input_is_neutral(action_snapshot(**change))

    def test_gravity_and_vertical_settling_do_not_prove_walking(self):
        before = action_snapshot()
        after = action_snapshot(position=[2, 0.7, 9])
        self.assertEqual(SMOKE.action_position_distance(before, after), 0)
        after = action_snapshot(position=[2.3, 0.7, 9.4])
        self.assertAlmostEqual(SMOKE.action_position_distance(before, after), 0.5)

    def test_delayed_native_motion_must_change_position_before_passing(self):
        before = action_snapshot()
        held = action_snapshot(movement_touch=0, move_axis=[1, 0], body_velocity=[1.2, 0, 0],
                               position=[2.2, 1, 9])
        released = action_snapshot(position=[2.4, 1, 9])
        cursor = SMOKE.village_runtime_cursor(log(before))
        logs = Mock(side_effect=[log(before, before), log(before, before, held), log(before, before, held, released)])
        with patch.object(SMOKE.time, "sleep", lambda _seconds: None):
            result = SMOKE.wait_for_village_snapshot(
                logs, "playing", after=cursor,
                predicate=lambda item: SMOKE.action_input_is_neutral(item)
                and SMOKE.action_position_distance(before, item) >= 0.10)
        self.assertEqual(result, released)
        self.assertEqual(logs.call_count, 3)

    def test_movement_gesture_uses_observed_translated_native_coordinates(self):
        self.assertEqual(SMOKE.observed_movement_points(movement_pad()),
                         ((210.0, 370.0), (274.0, 370.0)))

    def test_hidden_disabled_or_invalid_pad_fails_before_any_native_input(self):
        for change in ({"visible": False}, {"enabled": False}, {"rect": [0, 0, 0, 100]},
                       {"rect": [0, 0, float("nan"), 100]}, {"axis_points": {}}):
            with self.subTest(change=change):
                control = movement_pad()
                control.update(change)
                with self.assertRaises(RuntimeError):
                    SMOKE.observed_movement_points(control)

    def test_out_of_pad_or_degenerate_axis_cannot_fall_back_to_guessed_coordinates(self):
        for point in ([1000, 370], [210, 370], [True, 370], [274, float("inf")]):
            with self.subTest(point=point):
                control = movement_pad()
                control["axis_points"]["right"] = point
                with self.assertRaises(RuntimeError):
                    SMOKE.observed_movement_points(control)



if __name__ == "__main__":
    unittest.main()
