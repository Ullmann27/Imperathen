"""Synthetic log timing regressions; these are not Android device evidence."""

import base64
import copy
import hashlib
import importlib.util
import io
import json
import math
from pathlib import Path
import sys
import unittest
from unittest.mock import Mock, patch
import zipfile


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
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


class OpeningMarkerTest(unittest.TestCase):
    def test_new_bare_completion_marker_at_end_of_log(self):
        marker = "IMPERATHEN_OPENING_COMPLETE"
        self.assertEqual(SMOKE.newest_marker_payload("I godot: " + marker, marker, 0), "")
        self.assertEqual(SMOKE.newest_marker_payload("I godot: " + marker + "\n", marker, 0), "")

    def test_bare_completion_never_consumes_next_log_line(self):
        marker = "IMPERATHEN_OPENING_COMPLETE"
        self.assertEqual(SMOKE.newest_marker_payload(marker + "\nI godot: unrelated", marker, 0), "")

    def test_existing_marker_does_not_prove_new_event(self):
        marker = "IMPERATHEN_OPENING_COMPLETE"
        self.assertIsNone(SMOKE.newest_marker_payload(marker, marker, 1))
        self.assertIsNone(SMOKE.newest_marker_payload("", marker, 0))

    def test_payload_and_latest_event_preserved(self):
        marker = "IMPERATHEN_OPENING_STARTED "
        logs = marker + "i00_aquileia\n" + marker + "childhood_home\r\nI godot: next"
        self.assertEqual(SMOKE.newest_marker_payload(logs, marker, 1), "childhood_home")


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

    def test_long_runtime_keeps_bounded_latest_frames_and_full_sequence_cursor(self):
        lines = [line for sequence in range(1, SMOKE.MAX_VILLAGE_FRAMES + 12)
                 for line in chunk_lines(snapshot(), sequence=sequence)]
        text = "\n".join(lines)
        records = SMOKE.village_runtime_observations(text, retain_latest=True)
        self.assertEqual(len(records), SMOKE.MAX_VILLAGE_FRAMES)
        self.assertEqual(records[0]["sequence"], 12)
        self.assertEqual(records[-1]["ordinal"], SMOKE.MAX_VILLAGE_FRAMES + 11)
        cursor = SMOKE.village_runtime_cursor(text)
        self.assertEqual(cursor, ("chunk", "12345", SMOKE.MAX_VILLAGE_FRAMES + 11))
        updated = snapshot(assigned="woodcamp")
        next_log = "\n".join(lines + chunk_lines(updated, sequence=cursor[2] + 1))
        read = Mock(side_effect=[text, next_log])
        self.assertEqual(SMOKE.wait_for_village_snapshot(read, after=cursor, timeout=3), updated)
        self.assertEqual(read.call_count, 2)

    def test_current_window_does_not_hide_invalid_older_logs(self):
        tail = [line for sequence in range(2, SMOKE.MAX_VILLAGE_FRAMES + 4)
                for line in chunk_lines(snapshot(), sequence=sequence)]
        for prefix in ([SMOKE.VILLAGE_CHUNK_MARKER + "broken envelope"],
                       chunk_lines(snapshot(), observer="67890")):
            with self.subTest(prefix=prefix):
                with self.assertRaises(RuntimeError):
                    SMOKE.village_runtime_observations("\n".join(prefix + tail), retain_latest=True)

    def test_evicted_frame_cannot_be_reintroduced_as_new_evidence(self):
        lines = [line for sequence in range(1, SMOKE.MAX_VILLAGE_FRAMES + 2)
                 for line in chunk_lines(snapshot(), sequence=sequence)]
        with self.assertRaisesRegex(RuntimeError, "out of sequence"):
            SMOKE.village_runtime_observations("\n".join(lines + chunk_lines(snapshot())),
                                               retain_latest=True)

    def test_legacy_count_cursor_survives_current_window_eviction(self):
        count = SMOKE.MAX_VILLAGE_FRAMES + 5
        initial = snapshot()
        updated = snapshot(assigned="woodcamp")
        old = log(*([initial] * count))
        read = Mock(side_effect=[old, old + "\n" + log(updated)])
        result = SMOKE.wait_for_village_snapshot(read, after=count, timeout=3)
        self.assertEqual(result, updated)
        self.assertEqual(read.call_count, 2)

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
             "camera_touches": 0, "action_touches": 0, "world_camera_touches": 0,
             "figure_clip": "idle", "figure_speed": 0.0}
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



def childhood_snapshot(**changes):
    result = action_snapshot(camera_yaw=0.0)
    result["controls"]["move_pad"] = movement_pad()
    result["controls"]["move_pad"]["axis_points"]["down"] = [210.0, 434.0]
    child = {"version": 1, "world_id": "observed-family-world", "age": 12, "day": 1,
             "stage": "mother_morning", "completed": [], "carried": [],
             "target_npc": "julia", "target_point": "", "target_position": [-15.3, 14.8],
             "target_radius": 3.2, "family_entrance": [-13.0, 14.7], "family_water": [-12.0, 11.7],
             "dialog_npc": ""}
    child.update(changes)
    result["childhood_runtime"] = child
    return result


class ChildhoodRuntimeObservationTest(unittest.TestCase):
    def test_exported_childhood_detects_i00_and_existing_action_controls(self):
        entries = ["assets/scripts/story/village_life.gdc",
                   "assets/scripts/story/village_childhood.gd.remap",
                   "assets/scripts/cinematic/i00_stage.gdc",
                   "assets/scripts/ui/touch_look.gdc",
                   "assets/scripts/domain/combat_actions.gdc"]
        self.assertEqual(
            SMOKE.apk_runtime_features(entries),
            {"village_life": True, "childhood": True,
             "historical_prologue": True, "action_controls": True,
             "npc_behavior": False, "meshy_characters": False})

    def test_pre_i00_childhood_and_legacy_village_remain_distinct_routes(self):
        childhood = SMOKE.apk_runtime_features(
            ["assets/scripts/story/village_life.gdc",
             "assets/scripts/story/village_childhood.gdc"])
        self.assertTrue(childhood["childhood"])
        self.assertFalse(childhood["historical_prologue"])

        legacy = SMOKE.apk_runtime_features(
            ["assets/scripts/story/village_life.gdc",
             "assets/scripts/story/village_childhood_backup.gdc"])
        self.assertTrue(legacy["village_life"])
        self.assertFalse(legacy["childhood"])
        self.assertFalse(legacy["historical_prologue"])
        self.assertFalse(legacy["action_controls"])

    def test_missing_or_invalid_family_contract_cannot_be_reported_as_a_fresh_start(self):
        for value in ({}, {"childhood_runtime": {}}, childhood_snapshot(version=True),
                      childhood_snapshot(version=2), childhood_snapshot(world_id="")):
            with self.subTest(value=value):
                with self.assertRaises(RuntimeError):
                    SMOKE.childhood_runtime_state(value)

    def test_family_observation_keeps_real_item_ids_and_completed_order(self):
        state = childhood_snapshot(stage="father_morning",
                                   completed=["mother_morning", "fill_water"],
                                   carried=["household_coin", "water_jug"])
        actual = SMOKE.childhood_runtime_state(state)
        self.assertEqual(actual["completed"], ["mother_morning", "fill_water"])
        self.assertEqual(actual["carried"], ["household_coin", "water_jug"])
        self.assertEqual(actual["age"], 12)

    def test_inconsistent_family_geometry_and_duplicates_are_rejected(self):
        changes = [{"age": True}, {"day": 0}, {"target_position": [True, 1]},
                   {"target_position": [float("nan"), 1]}, {"family_water": [1]},
                   {"target_radius": float("inf")}, {"target_radius": 0},
                   {"completed": ["mother_morning", "mother_morning"]},
                   {"carried": ["water_jug", "water_jug"]}, {"dialog_npc": None}]
        for change in changes:
            with self.subTest(change=change):
                with self.assertRaises(RuntimeError):
                    SMOKE.childhood_runtime_state(childhood_snapshot(**change))

    def test_native_walk_point_uses_live_pad_translation_and_world_direction(self):
        point, distance = SMOKE.observed_walk_point(childhood_snapshot(), [5.0, 9.0])
        self.assertEqual(point, [274.0, 370.0])
        self.assertEqual(distance, 3.0)

    def test_native_walk_direction_is_relative_to_actual_camera_yaw(self):
        state = childhood_snapshot()
        state["action_runtime"]["camera_yaw"] = math.pi / 2
        point, distance = SMOKE.observed_walk_point(state, [5.0, 9.0])
        self.assertAlmostEqual(point[0], 210.0)
        self.assertAlmostEqual(point[1], 434.0)
        self.assertEqual(distance, 3.0)

    def test_native_walk_has_no_guessed_camera_or_axis_fallback(self):
        for invalid_yaw in (None, True, float("nan")):
            state = childhood_snapshot()
            state["action_runtime"]["camera_yaw"] = invalid_yaw
            with self.assertRaises(RuntimeError):
                SMOKE.observed_walk_point(state, [5.0, 9.0])
        state = childhood_snapshot()
        del state["controls"]["move_pad"]["axis_points"]["down"]
        with self.assertRaises(RuntimeError):
            SMOKE.observed_walk_point(state, [5.0, 9.0])

    def test_native_walk_rejects_invalid_waypoints_and_centers_at_destination(self):
        for target in ([True, 9], [float("inf"), 9], [2]):
            with self.subTest(target=target):
                with self.assertRaises(RuntimeError):
                    SMOKE.observed_walk_point(childhood_snapshot(), target)
        point, distance = SMOKE.observed_walk_point(childhood_snapshot(), [2.0, 9.0])
        self.assertEqual(point, (210.0, 370.0))
        self.assertEqual(distance, 0.0)


class NativePointerDrivingTest(unittest.TestCase):
    """Synthetic native-command/log ordering, not an Android execution claim."""

    def setUp(self):
        self.now = 0.0
        self.before = childhood_snapshot()
        self.snapshots = [self.before]
        self.pending = []
        self.events = []
        self.down_states = [self.before, self.held()]
        self.move_states = [self.held(position=[2.15, 1.0, 9.0], move_axis=[0.6, 0.0])]
        self.fail_event = None
        self.fail_read_after_down = False
        self.release_is_stuck = False
        self.release_position = None
        self.neutral_arrives_before_up = False
        clock = patch.object(SMOKE.time, "monotonic", lambda: self.now)
        sleeper = patch.object(SMOKE.time, "sleep", self.advance)
        clock.start()
        sleeper.start()
        self.addCleanup(clock.stop)
        self.addCleanup(sleeper.stop)

    def held(self, **changes):
        state = copy.deepcopy(self.before)
        state["action_runtime"]["movement_touch"] = 0
        state["action_runtime"].update(changes)
        return state

    def advance(self, seconds):
        self.now += seconds
        if self.pending:
            self.snapshots.append(self.pending.pop(0))

    def logs(self):
        if self.fail_read_after_down and self.events:
            raise RuntimeError("Actual diagnostic transport failed")
        text = "\n".join(line for sequence, state in enumerate(self.snapshots, 1)
                         for line in chunk_lines(state, sequence=sequence))
        if (self.neutral_arrives_before_up and self.events and self.events[-1][0] == "MOVE"
                and SMOKE.action_position_distance(self.before, self.snapshots[-1]) >= 0.10):
            # A newer frame arrives after this log read, before the host sends
            # UP. Reusing the last MOVE cursor would falsely accept that frame.
            self.neutral_arrives_before_up = False
            neutral = copy.deepcopy(self.snapshots[-1])
            neutral["action_runtime"].update(movement_touch=-1, move_axis=[0.0, 0.0],
                                             body_velocity=[0.0, 0.0, 0.0])
            self.snapshots.append(neutral)
        return text

    def motion(self, event, point):
        self.events.append((event, point, self.now))
        if event == self.fail_event:
            raise RuntimeError("Actual ADB " + event + " command failed")
        if event == "DOWN":
            self.pending.extend(self.down_states)
        elif event == "MOVE":
            self.assertGreaterEqual(self.snapshots[-1]["action_runtime"]["movement_touch"], 0)
            if self.move_states:
                self.pending.append(self.move_states.pop(0))
            else:
                self.pending.append(copy.deepcopy(self.snapshots[-1]))
        elif event == "UP" and not self.release_is_stuck:
            released = copy.deepcopy(self.snapshots[-1])
            released["action_runtime"].update(movement_touch=-1, move_axis=[0.0, 0.0],
                                              body_velocity=[0.0, 0.0, 0.0])
            if self.release_position is not None:
                released["action_runtime"]["position"] = self.release_position
            self.pending = [released]

    def drive(self, **kwargs):
        return SMOKE.drive_observed_native_pointer(self.logs, self.motion, self.before, **kwargs)

    def assert_released(self):
        self.assertEqual(self.events[0][0], "DOWN")
        self.assertEqual(self.events[-1][0], "UP")
        self.assertEqual(sum(event == "UP" for event, _point, _time in self.events), 1)

    def test_contact_handshake_precedes_move_and_position_precedes_release(self):
        self.move_states = [self.held(move_axis=[0.6, 0.0]),
                            self.held(position=[2.04, 1.0, 9.0], move_axis=[0.6, 0.0]),
                            self.held(position=[2.15, 1.0, 9.0], move_axis=[0.6, 0.0])]
        evidence = {}
        released = self.drive(evidence=evidence)
        self.assertEqual([event[0] for event in self.events], ["DOWN", "MOVE", "MOVE", "MOVE", "UP"])
        self.assertGreaterEqual(self.events[1][2], 2.0)
        self.assertEqual(self.events[0][1], (210, 370))
        self.assertEqual(self.events[1][1], (274, 370))
        self.assertTrue(SMOKE.action_input_is_neutral(released))
        self.assertGreaterEqual(evidence["distance_m"], 0.10)
        self.assertTrue(all(event["command_returned"] for event in evidence["events"]))

    def test_waypoint_steering_uses_new_observed_positions(self):
        self.move_states = [self.held(position=[2.25, 1.0, 9.0], move_axis=[0.5, 0.0]),
                            self.held(position=[2.55, 1.0, 9.0], move_axis=[0.35, 0.0])]
        released = self.drive(target=[2.6, 9.0], radius=0.1, minimum_distance=0.02)
        moves = [event[1] for event in self.events if event[0] == "MOVE"]
        self.assertLess(moves[1][0], moves[0][0])
        self.assertLessEqual(SMOKE.observed_walk_point(released, [2.6, 9.0])[1], 0.1)
        self.assert_released()

    def test_axis_and_vertical_settling_without_walking_cannot_pass(self):
        self.move_states = [self.held(position=[2.0, 0.7, 9.0], move_axis=[1.0, 0.0])] * 6
        with self.assertRaises(RuntimeError):
            self.drive(timeout=5)
        self.assertEqual(self.now, 5)
        self.assert_released()

    def test_unobserved_down_times_out_and_still_sends_up_without_move(self):
        self.down_states = []
        with self.assertRaisesRegex(RuntimeError, "No matching village runtime state"):
            self.drive(timeout=3)
        self.assertEqual([event[0] for event in self.events], ["DOWN", "UP"])

    def test_failed_down_or_move_still_attempts_native_up(self):
        for event in ("DOWN", "MOVE"):
            with self.subTest(event=event):
                self.events = []
                self.pending = []
                self.snapshots = [self.before]
                self.fail_event = event
                with self.assertRaisesRegex(RuntimeError, "Actual ADB " + event):
                    self.drive()
                self.assert_released()

    def test_diagnostic_failure_cannot_prevent_native_up(self):
        self.fail_read_after_down = True
        with self.assertRaisesRegex(RuntimeError, "diagnostic transport failed"):
            self.drive()
        self.assertEqual([event[0] for event in self.events], ["DOWN", "UP"])

    def test_lost_or_replaced_contact_cannot_satisfy_distance(self):
        for touch in (-1, 1):
            with self.subTest(touch=touch):
                self.events = []
                self.pending = []
                self.snapshots = [self.before]
                self.move_states = [self.held(position=[2.3, 1.0, 9.0], move_axis=[0.6, 0.0],
                                              movement_touch=touch)]
                with self.assertRaisesRegex(RuntimeError, "pointer was lost or replaced"):
                    self.drive()
                self.assert_released()

    def test_rebuilt_pad_aborts_and_releases_the_existing_pointer(self):
        self.move_states[0]["controls"]["move_pad"]["instance_id"] = "replacement-pad"
        with self.assertRaisesRegex(RuntimeError, "context changed"):
            self.drive()
        self.assert_released()

    def test_up_must_be_observed_as_neutral_after_actual_movement(self):
        self.release_is_stuck = True
        with self.assertRaisesRegex(RuntimeError, "No matching village runtime state"):
            self.drive()
        self.assert_released()

    def test_neutral_observation_created_before_up_does_not_prove_release(self):
        self.neutral_arrives_before_up = True
        self.release_is_stuck = True
        with self.assertRaisesRegex(RuntimeError, "No matching village runtime state"):
            self.drive()
        self.assert_released()
        self.assertTrue(SMOKE.action_input_is_neutral(self.snapshots[-1]))

    def test_final_displacement_requirement_survives_release(self):
        self.release_position = list(self.before["action_runtime"]["position"])
        with self.assertRaisesRegex(RuntimeError, "required actual player displacement"):
            self.drive()
        self.assert_released()

    def test_missing_pad_identity_fails_before_any_native_input(self):
        self.before["controls"]["move_pad"].pop("instance_id")
        with self.assertRaisesRegex(RuntimeError, "stable identity"):
            self.drive()
        self.assertEqual(self.events, [])


class GraphicsRuntimeObservationTest(unittest.TestCase):
    def test_low_profile_requires_observed_ui_and_world_values(self):
        for profiles in ({"ui_profile": "low", "world_profile": "low"},
                         {"ui_profile": "low", "world_profile": "balanced"}):
            state = {"graphics_runtime": profiles}
            self.assertEqual(SMOKE.graphics_runtime_profiles(state), profiles)
        with self.assertRaisesRegex(RuntimeError, "observed graphics profiles"):
            SMOKE.graphics_runtime_profiles({"graphics_runtime": {"ui_profile": "low"}})

    def test_unknown_or_untyped_quality_cannot_be_used_as_observation(self):
        for profiles in ({"ui_profile": True, "world_profile": "low"},
                         {"ui_profile": [], "world_profile": "low"},
                         {"ui_profile": "low", "world_profile": "automatic"}, None):
            with self.subTest(profiles=profiles):
                with self.assertRaises(RuntimeError):
                    SMOKE.graphics_runtime_profiles({"graphics_runtime": profiles})


class ObservedVillageScrollTest(unittest.TestCase):
    def test_ci27_aelia_above_viewport_gets_a_bounded_downward_correction(self):
        # Coordinates from the failed real Android run, not a claimed device test.
        control = {"enabled": True, "visible": False, "center": [728.625, -276.75]}
        scroll = {"top": [682.56, 162.0], "bottom": [682.56, 399.6], "offset": 1497}
        start, end = SMOKE.observed_scroll_gesture(control, scroll)
        self.assertEqual(start[0], 682.56)
        self.assertEqual(end[0], 682.56)
        self.assertGreater(end[1], start[1])
        self.assertLessEqual(end[1] - start[1], (399.6 - 162.0) * 0.35 + 1e-9)
        self.assertGreaterEqual(start[1], 162.0)
        self.assertLessEqual(end[1], 399.6)

    def test_below_viewport_reverses_direction_without_leaving_visible_scroll_band(self):
        scroll = {"top": [100.0, 200.0], "bottom": [100.0, 400.0]}
        start, end = SMOKE.observed_scroll_gesture({"enabled": True, "center": [200.0, 900.0]}, scroll)
        self.assertLess(end[1], start[1])
        self.assertGreaterEqual(end[1], 200.0)
        self.assertLessEqual(start[1], 400.0)

    def test_missing_or_nonfinite_scroll_geometry_cannot_generate_a_gesture(self):
        control = {"enabled": True, "center": [200.0, -20.0]}
        for scroll in ({}, {"top": [100, 200], "bottom": [100, 200]},
                       {"top": [100, float("nan")], "bottom": [100, 400]}):
            with self.subTest(scroll=scroll):
                with self.assertRaises(RuntimeError):
                    SMOKE.observed_scroll_gesture(control, scroll)

    def test_scrolling_waits_for_settled_coordinates_even_while_target_is_clipped(self):
        first = {"enabled": True, "visible": False, "center": [728.625, -276.75], "instance_id": "aelia"}
        moving = {**first, "center": [728.625, -200.0]}
        read = Mock(side_effect=[first, moving, moving])
        result = SMOKE.wait_for_stable_village_control(read, require_visible=False, max_observations=3)
        self.assertEqual(result, moving)
        self.assertEqual(read.call_count, 3)


def behavior_snapshot():
    snapshot = action_snapshot(world_active=False)
    snapshot.update(screen="paused", world_seconds=40.25)
    samples = {}
    for identity, interest in SMOKE.BEHAVIOR_SAMPLE_INTERESTS.items():
        samples[identity] = {"interest": interest, "fatigue": 23.5, "social_need": 46.5,
                             "stress": 2.0, "activity": "work", "reason": "daily_work",
                             "since": 32.0, "next_decision": 42.0, "last_greet": 28.5,
                             "last_trust": 15, "partner": "", "position": [4.2, 0.9, 1.1],
                             "route_distance": 12.0, "route_direction": 1, "observed": True,
                             "memories": [{"kind": "trust_gained", "at": 30.5}]}
    state = {"version": 1, "behavior_version": 1, "world_id": "real-observed-world",
             "seconds": 40.0, "accumulator": 0.25, "people_count": 42, "observed_count": 42,
             "decision_due_count": 2, "activity_counts": {"work": 35, "patrol": 5, "greet": 2},
             "roster_sha256": "a" * 64, "state_sha256": "b" * 64, "samples": samples}
    snapshot["behavior_runtime"] = state
    snapshot["saved_behavior_runtime"] = {**copy.deepcopy(state), "envelope_sha256": "c" * 64,
                                            "payload_sha256": "d" * 64}
    return snapshot


class NpcBehaviorRuntimeObservationTest(unittest.TestCase):
    def test_missing_or_old_behavior_cannot_be_a_connected_simulation(self):
        for value in ({}, {"behavior_runtime": {}}, {"behavior_runtime": {"version": True}},
                      {"behavior_runtime": {"version": 1, "behavior_version": 2}}):
            with self.subTest(value=value), self.assertRaisesRegex(RuntimeError, "unsupported"):
                SMOKE.behavior_runtime_state(value)

    def test_missing_roster_physics_or_decision_counts_are_rejected(self):
        for change in ({"people_count": 41}, {"observed_count": True}, {"decision_due_count": -1},
                       {"activity_counts": {"work": 41}}, {"activity_counts": {"invented": 42}}):
            snapshot = behavior_snapshot()
            snapshot["behavior_runtime"].update(change)
            with self.subTest(change=change), self.assertRaises(RuntimeError):
                SMOKE.behavior_runtime_state(snapshot)

    def test_behavior_clock_must_follow_world_and_finite_numeric_types(self):
        for change in ({"seconds": 39.0}, {"seconds": float("nan")}, {"accumulator": 0.6},
                       {"accumulator": True}):
            snapshot = behavior_snapshot()
            snapshot["behavior_runtime"].update(change)
            with self.subTest(change=change), self.assertRaisesRegex(RuntimeError, "clock"):
                SMOKE.behavior_runtime_state(snapshot)

    def test_invalid_need_memory_or_stable_interest_is_not_silently_accepted(self):
        for change in ({"fatigue": float("inf")}, {"stress": True}, {"social_need": 101},
                       {"interest": "security"}, {"memories": [{"kind": "greeted", "at": 99}]},
                       {"route_direction": 0}, {"observed": 1}, {"last_trust": 2.5}):
            snapshot = behavior_snapshot()
            snapshot["behavior_runtime"]["samples"]["julia"].update(change)
            with self.subTest(change=change), self.assertRaises(RuntimeError):
                SMOKE.behavior_runtime_state(snapshot)

    def test_paused_save_requires_exact_normalized_behavior_digest(self):
        snapshot = behavior_snapshot()
        checkpoint = SMOKE.saved_behavior_checkpoint(snapshot)
        self.assertEqual(checkpoint["state_sha256"], "b" * 64)
        for key in ("world_id", "roster_sha256", "state_sha256"):
            changed = copy.deepcopy(snapshot)
            changed["saved_behavior_runtime"][key] = "e" * 64
            with self.subTest(key=key), self.assertRaisesRegex(RuntimeError, "does not match"):
                SMOKE.saved_behavior_checkpoint(changed)

    def test_save_evidence_cannot_be_taken_from_active_world_or_unverified_envelope(self):
        for change in ("active", "missing_save", "missing_checksum", "false_checksum"):
            snapshot = behavior_snapshot()
            if change == "active":
                snapshot["action_runtime"]["world_active"] = True
            elif change == "missing_save":
                snapshot.pop("saved_behavior_runtime")
            elif change == "missing_checksum":
                snapshot["saved_behavior_runtime"].pop("payload_sha256")
            else:
                snapshot["saved_behavior_runtime"]["envelope_sha256"] = True
            with self.subTest(change=change), self.assertRaises(RuntimeError):
                SMOKE.saved_behavior_checkpoint(snapshot)

    def test_restart_accepts_elapsed_time_new_decisions_and_rate_bounded_needs(self):
        snapshot = behavior_snapshot()
        checkpoint = copy.deepcopy(SMOKE.saved_behavior_checkpoint(snapshot))
        live = snapshot["behavior_runtime"]
        live["seconds"] += 2.0
        snapshot["world_seconds"] += 2.0
        live["state_sha256"] = "e" * 64
        julia = live["samples"]["julia"]
        julia.update(fatigue=24.0, social_need=45.0, activity="greet", reason="friendly",
                     since=41.0, next_decision=43.5, last_greet=41.0, partner="player")
        julia["memories"].append({"kind": "danger_seen", "at": 41.0})
        result = SMOKE.verify_behavior_restart(checkpoint, snapshot)
        self.assertEqual(result["elapsed_simulation_seconds"], 2.0)
        self.assertEqual(result["observed_count"], 42)

    def test_restart_rejects_changed_file_world_reset_needs_and_lost_memories(self):
        for change in ("file", "world", "time", "need", "memory", "memory_rewrite", "trust", "observed"):
            snapshot = behavior_snapshot()
            checkpoint = copy.deepcopy(SMOKE.saved_behavior_checkpoint(snapshot))
            live = snapshot["behavior_runtime"]
            if change == "file":
                snapshot["saved_behavior_runtime"]["envelope_sha256"] = "e" * 64
            elif change == "world":
                live["world_id"] = "new-unrelated-world"
            elif change == "time":
                live["seconds"] -= 0.5
                snapshot["world_seconds"] -= 0.5
            elif change == "need":
                live["samples"]["julia"]["fatigue"] = 1.0
            elif change == "memory":
                live["samples"]["julia"]["memories"] = []
            elif change == "memory_rewrite":
                live["samples"]["julia"]["memories"][0]["kind"] = "replaced"
            elif change == "trust":
                live["samples"]["julia"]["last_trust"] = 0
            else:
                live["observed_count"] = 0
            with self.subTest(change=change), self.assertRaises(RuntimeError):
                SMOKE.verify_behavior_restart(checkpoint, snapshot)

    def test_full_memory_can_roll_forward_but_cannot_silently_drop_old_items(self):
        snapshot = behavior_snapshot()
        memories = [{"kind": "danger_seen" if index % 2 else "trust_gained", "at": 20.0 + index} for index in range(4)]
        snapshot["behavior_runtime"]["samples"]["julia"]["memories"] = copy.deepcopy(memories)
        snapshot["saved_behavior_runtime"]["samples"]["julia"]["memories"] = copy.deepcopy(memories)
        checkpoint = copy.deepcopy(SMOKE.saved_behavior_checkpoint(snapshot))
        snapshot["behavior_runtime"]["seconds"] = 41.0
        snapshot["world_seconds"] = 41.25
        current = snapshot["behavior_runtime"]["samples"]["julia"]
        current["memories"] = memories[1:] + [{"kind": "danger_seen", "at": 40.5}]
        SMOKE.verify_behavior_restart(checkpoint, snapshot)
        current["memories"] = current["memories"][1:]
        with self.assertRaisesRegex(RuntimeError, "disappeared"):
            SMOKE.verify_behavior_restart(checkpoint, snapshot)

    def test_new_apk_features_depend_on_actual_script_entries(self):
        entries = ["assets/scripts/story/village_life.gdc", "assets/scripts/domain/npc_behavior.gd.remap",
                   "assets/scripts/visuals/meshy_character_registry.gdc"]
        features = SMOKE.apk_runtime_features(entries)
        self.assertTrue(features["npc_behavior"])
        self.assertTrue(features["meshy_characters"])
        backups = [entry.replace("npc_behavior.", "npc_behavior_backup.")
                   .replace("meshy_character_registry.", "meshy_character_registry_backup.") for entry in entries]
        self.assertFalse(SMOKE.apk_runtime_features(backups)["npc_behavior"])
        self.assertFalse(SMOKE.apk_runtime_features(backups)["meshy_characters"])


def meshy_snapshot():
    return {"meshy_runtime": {"version": 1, "loaded_count": 1, "severus": {
        "asset_id": "unit_roman_signifer", "model_path": "res://assets/meshy/characters/unit_roman_signifer_3.glb",
        "loaded": True, "mesh_count": 2, "bone_count": 15, "clip": "idle", "has_march": True, "has_run": True,
        "equipment": [{"asset_id": "gear_roman_signum", "model_path": "res://assets/meshy/equipment/gear_roman_signum_1.glb",
                        "bone": "Hand_R", "bound": True, "mesh_count": 1}]}}}


class MeshyRuntimeObservationTest(unittest.TestCase):
    def test_loaded_signifer_requires_actual_model_rig_and_gaits(self):
        self.assertEqual(SMOKE.meshy_runtime_state(meshy_snapshot())["loaded_count"], 1)
        for change in ({"model_path": "res://assets/meshy/source/unit_roman_signifer.glb"},
                       {"model_path": "res://assets/characters/frontier_legionary_3.glb"},
                       {"asset_id": "unit_germanic_axe_fighter"}, {"loaded": False},
                       {"mesh_count": 0}, {"bone_count": True}, {"has_run": False}):
            snapshot = meshy_snapshot()
            snapshot["meshy_runtime"]["severus"].update(change)
            with self.subTest(change=change), self.assertRaises(RuntimeError):
                SMOKE.meshy_runtime_state(snapshot)

    def test_registry_presence_alone_never_proves_loaded_model(self):
        for value in ({}, {"meshy_runtime": {"version": 1, "loaded_count": 0, "severus": {}}},
                      {"meshy_runtime": {"version": True}}):
            with self.subTest(value=value), self.assertRaises(RuntimeError):
                SMOKE.meshy_runtime_state(value)

    def test_missing_or_unbound_standard_cannot_pass_body_only_observation(self):
        snapshot = meshy_snapshot()
        snapshot["meshy_runtime"]["severus"]["equipment"] = []
        with self.assertRaisesRegex(RuntimeError, "lost its held standard"):
            SMOKE.meshy_runtime_state(snapshot)
        for change in ({"bone": "Hand_L"}, {"bound": False}, {"mesh_count": 0},
                       {"model_path": "res://assets/meshy/source/equipment/gear_roman_signum.glb"}):
            snapshot = meshy_snapshot()
            snapshot["meshy_runtime"]["severus"]["equipment"][0].update(change)
            with self.subTest(change=change), self.assertRaisesRegex(RuntimeError, "not loaded"):
                SMOKE.meshy_runtime_state(snapshot)


class MeshyRuntimePackageTest(unittest.TestCase):
    # These ZIP fixtures model Godot's real .glb.import -> .scn export layout;
    # their small payloads are synthetic and are not Android execution evidence.
    SOURCES = ("assets/meshy/characters/unit_roman_signifer_3.glb",
               "assets/meshy/equipment/gear_roman_signum_1.glb")
    TARGETS = (".godot/imported/unit_roman_signifer_3.glb-3f9de47102dce13d8dac1fbd15439a0b.scn",
               ".godot/imported/gear_roman_signum_1.glb-ed3f3f24147c65525ffd258d4e901e2e.scn")

    def exported_entries(self):
        entries = {}
        for index, (source, target) in enumerate(zip(self.SOURCES, self.TARGETS)):
            entries["assets/" + source + ".import"] = (
                '[remap]\nimporter="scene"\nimporter_version=1\ntype="PackedScene"\n'
                f'path="res://{target}"\n\n[deps]\nsource_file="res://{source}"\n'
                f'dest_files=["res://{target}"]\n').encode()
            entries["assets/" + target] = b"RSCC" + ("synthetic exported scene " + str(index)).encode()
        return entries

    def inspect(self, entries, snapshot=None):
        data = io.BytesIO()
        with zipfile.ZipFile(data, "w") as archive:
            for path, payload in entries.items():
                archive.writestr(path, payload)
        with zipfile.ZipFile(data) as archive:
            return SMOKE.meshy_runtime_package_check(meshy_snapshot() if snapshot is None else snapshot, archive)

    def test_imports_resolve_body_and_standard_and_record_exact_payload_hashes(self):
        entries = self.exported_entries()
        passed, evidence = self.inspect(entries)
        self.assertTrue(passed)
        self.assertEqual(evidence["severus"], meshy_snapshot()["meshy_runtime"]["severus"])
        self.assertEqual(evidence["packaged_models"], ["assets/" + source for source in self.SOURCES])
        self.assertEqual(len(evidence["packaged_resources"]), 2)
        for source, target, resource in zip(self.SOURCES, self.TARGETS, evidence["packaged_resources"]):
            remap = "assets/" + source + ".import"
            entry = "assets/" + target
            self.assertEqual(resource, {"source": source, "entry": entry, "remap": remap, "mode": "remapped",
                                       "size_bytes": len(entries[entry]), "sha256": hashlib.sha256(entries[entry]).hexdigest(),
                                       "remap_sha256": hashlib.sha256(entries[remap]).hexdigest()})

    def test_nonempty_direct_models_remain_supported(self):
        entries = {"assets/" + source: b"glTF" + source.encode() for source in self.SOURCES}
        passed, evidence = self.inspect(entries)
        self.assertTrue(passed)
        for resource in evidence["packaged_resources"]:
            self.assertEqual(resource["mode"], "direct")
            self.assertEqual(resource["sha256"], hashlib.sha256(entries[resource["entry"]]).hexdigest())

    def test_missing_body_or_standard_cannot_pass_the_other_model(self):
        for missing in self.SOURCES:
            entries = self.exported_entries()
            del entries["assets/" + missing + ".import"]
            with self.subTest(missing=missing):
                passed, evidence = self.inspect(entries)
                self.assertFalse(passed)
                self.assertEqual([item["source"] for item in evidence["packaged_resources"] if item["entry"] is None], [missing])

    def test_import_without_its_target_scene_fails(self):
        for target in self.TARGETS:
            entries = self.exported_entries()
            del entries["assets/" + target]
            with self.subTest(target=target):
                self.assertFalse(self.inspect(entries)[0])

    def test_empty_import_target_scene_fails(self):
        for target in self.TARGETS:
            entries = self.exported_entries()
            entries["assets/" + target] = b""
            with self.subTest(target=target):
                self.assertFalse(self.inspect(entries)[0])

    def test_loose_import_cannot_be_satisfied_by_an_unreferenced_scene(self):
        for source in self.SOURCES:
            entries = self.exported_entries()
            entries["assets/" + source + ".import"] = b'[remap]\nimporter="scene"\ntype="PackedScene"\n'
            with self.subTest(source=source):
                self.assertFalse(self.inspect(entries)[0])

    def test_empty_direct_model_is_not_a_payload(self):
        for missing in self.SOURCES:
            entries = {"assets/" + source: b"glTF" for source in self.SOURCES}
            entries["assets/" + missing] = b""
            with self.subTest(missing=missing):
                self.assertFalse(self.inspect(entries)[0])

    def test_valid_package_cannot_replace_actual_rig_and_hand_observation(self):
        for field, value in (("loaded", False), ("bone_count", 0), ("has_march", False)):
            snapshot = meshy_snapshot()
            snapshot["meshy_runtime"]["severus"][field] = value
            with self.subTest(field=field), self.assertRaises(RuntimeError):
                self.inspect(self.exported_entries(), snapshot)
        snapshot = meshy_snapshot()
        snapshot["meshy_runtime"]["severus"]["equipment"][0]["bound"] = False
        with self.assertRaisesRegex(RuntimeError, "not loaded"):
            self.inspect(self.exported_entries(), snapshot)


class NativeGaitObservationTest(unittest.TestCase):
    def test_gait_requires_actual_moving_pointer_sample(self):
        observations = [{"phase": "DOWN", "velocity": [0, 0, 0], "figure_clip": "idle"},
                        {"phase": "MOVE", "velocity": [1.45, 0, 0], "figure_clip": "march"},
                        {"phase": "UP", "velocity": [0, 0, 0], "figure_clip": "idle"}]
        self.assertEqual(SMOKE.verify_native_gait({"observations": observations}),
                         [{"clip": "march", "speed_m_s": 1.45}])
        observations[1]["figure_clip"] = "work"
        with self.assertRaisesRegex(RuntimeError, "locomotion clip"):
            SMOKE.verify_native_gait({"observations": observations})

    def test_selected_walk_or_gravity_without_horizontal_motion_is_insufficient(self):
        for observations in ([], [{"phase": "MOVE", "velocity": [0, -4, 0], "figure_clip": "march"}],
                             [{"phase": "MOVE", "figure_clip": "run"}],
                             [{"phase": "MOVE", "velocity": [True, 0, 0], "figure_clip": "march"}]):
            with self.subTest(observations=observations), self.assertRaises(RuntimeError):
                SMOKE.verify_native_gait({"observations": observations})


if __name__ == "__main__":
    unittest.main()
