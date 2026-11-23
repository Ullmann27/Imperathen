"""Synthetic childhood input/observer regressions, never Android device evidence."""
from __future__ import annotations

import copy
import importlib.util
import json
import math
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("childhood_runtime_smoke", ROOT / "tools/android_runtime_smoke.py")
SMOKE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(SMOKE)


def snapshot(*, scene="family_morning", screen="playing", seconds=10.0, grain=16, position=None):
    return {
        "screen":screen, "world_seconds":seconds, "player_is_ruler":False,
        "controls":{
            "movement":{"center":[110.0,430.0], "radius":68.0, "visible":True, "enabled":True},
            "interact":{"center":[890.0,450.0], "visible":True, "enabled":True, "instance_id":"interact-1"},
            "choice_promise":{"center":[480.0,275.0], "visible":True, "enabled":True, "instance_id":"promise-1"}},
        "childhood":{
            "enabled":True, "day":1, "age":12, "world_id":"synthetic-world-1",
            "objective":{"id":scene, "npc_id":"julia" if scene == "family_morning" else "silvanus"},
            "position":[-5.0,0.12,25.4] if position is None else list(position),
            "navigation":{"available":True, "target":[-4.0,0.0,24.9]}, "camera_yaw":0.62,
            "nearby":{"available":True, "npc_id":"julia"}, "denarii":0, "grain":grain,
            "night":{"phase":"dormant", "elapsed":0.0, "seed":1731, "decision":"pending",
                     "support_confirmed":False, "support_kind":"", "consequences_applied":False, "outcome":""}}}


class SyntheticTouchFlow:
    def __init__(self):
        at = [-5.0,0.12,25.9]
        self.states = [
            snapshot(),
            snapshot(seconds=10.6, grain=17, position=at),
            snapshot(screen="childhood_dialog", seconds=12.0, grain=17, position=at),
            snapshot(screen="childhood_dialog", seconds=12.0, grain=17, position=at),
            snapshot(scene="father_lunch", screen="childhood_dialog", seconds=12.0, grain=15, position=at),
            snapshot(scene="father_lunch", seconds=12.8, grain=18, position=at)]
        self.observed = []
        self.inputs = []
        self.checks = []
        self.captures = []
        self.waits = []

    def read_snapshot(self, screen, **kwargs):
        state = copy.deepcopy(self.states[len(self.observed)])
        if state["screen"] != screen or (kwargs.get("predicate") and not kwargs["predicate"](state)):
            raise RuntimeError("No matching village runtime state")
        if kwargs.get("required_control") and kwargs["required_control"] not in state["controls"]:
            raise RuntimeError("The required actual control was not observed")
        if self.observed:
            assert kwargs["after"] == ("legacy", None, len(self.observed))
        self.observed.append(state)
        return state

    def read_logs(self):
        return "\n".join(SMOKE.VILLAGE_RUNTIME_MARKER + json.dumps(state) for state in self.observed)

    def read_control(self, name, screen):
        assert self.observed[-1]["screen"] == screen
        control = self.observed[-1]["controls"][name]
        if not control["visible"] or not control["enabled"]:
            raise RuntimeError("The actual village control is disabled")
        return control

    def record(self, name, passed, detail):
        self.checks.append({"name":name, "passed":passed, "detail":detail})
        if not passed:
            raise RuntimeError(name)

    def run(self):
        return SMOKE.execute_childhood(
            read_snapshot=self.read_snapshot, read_logs=self.read_logs, read_control=self.read_control,
            tap=lambda point:self.inputs.append(("tap",list(point))),
            swipe=lambda gesture:self.inputs.append(("swipe",gesture)),
            press_back=lambda:self.inputs.append(("back",)),
            screenshot=self.captures.append, record=self.record, wait=self.waits.append)


class ChildhoodRuntimeRouteTest(unittest.TestCase):
    def test_new_exports_use_childhood_without_weakening_previous_routes(self):
        for suffix in (".gd", ".gdc", ".gde", ".gd.remap"):
            with self.subTest(suffix=suffix):
                self.assertEqual(SMOKE.apk_runtime_profile([
                    "assets/scripts/story/village_life.gd",
                    "assets/scripts/story/childhood_story" + suffix]), "childhood")
        self.assertEqual(SMOKE.apk_runtime_profile(["assets/scripts/story/village_life.gd.remap"]), "village_life")
        self.assertEqual(SMOKE.apk_runtime_profile(["assets/scripts/main.gd"]), "legacy")
        self.assertEqual(SMOKE.apk_runtime_profile(["assets/scripts/story/childhood_story.gd.uid"]), "legacy")

    def test_both_real_first_day_markers_are_recognized(self):
        for sequence in ("first_day", "childhood_first_day"):
            self.assertEqual(SMOKE.first_day_opening_id("I godot: IMPERATHEN_OPENING_STARTED " + sequence + "\n"), sequence)
        for sequence in ("adulthood", "first_day_copy", "not_first_day", "childhood_first_day_extra"):
            self.assertIsNone(SMOKE.first_day_opening_id("IMPERATHEN_OPENING_STARTED " + sequence))

    def test_native_pad_gesture_uses_observed_camera_rotation(self):
        for yaw in (0.0, math.pi / 2, math.pi, -math.pi / 2, 0.62):
            with self.subTest(yaw=yaw):
                state = snapshot()
                state["childhood"]["camera_yaw"] = yaw
                gesture = SMOKE.childhood_touch_gesture(state)
                x, z = (gesture["end"][index] - gesture["start"][index] for index in range(2))
                world_x = math.cos(yaw) * x + math.sin(yaw) * z
                world_z = -math.sin(yaw) * x + math.cos(yaw) * z
                self.assertAlmostEqual(world_x, 0.0)
                self.assertGreater(world_z, 0)
                self.assertLess(math.hypot(x,z), state["controls"]["movement"]["radius"])
                self.assertEqual(gesture["start"], [110.0,430.0])
                self.assertLessEqual(gesture["duration_ms"], 500)

    def test_unobserved_hidden_or_nonfinite_geometry_never_generates_input(self):
        for key, value in (("visible",False), ("enabled",False), ("radius",0),
                           ("radius",float("nan")), ("center",[True,430.0]), ("center",[110.0,float("inf")])):
            state = snapshot()
            state["controls"]["movement"][key] = value
            with self.subTest(key=key,value=value), self.assertRaises(RuntimeError):
                SMOKE.childhood_touch_gesture(state)
        with self.assertRaises(RuntimeError):
            SMOKE.childhood_touch_gesture(snapshot(), (0.0,0.0))

    def test_native_flow_observes_movement_dialogue_choice_and_back(self):
        flow = SyntheticTouchFlow()
        original = copy.deepcopy(flow.states)
        saved = flow.run()
        self.assertEqual(saved["childhood"]["objective"]["id"], "father_lunch")
        self.assertEqual([item[0] for item in flow.inputs], ["swipe","tap","tap","back"])
        self.assertEqual(flow.inputs[1][1], [890.0,450.0])
        self.assertEqual(flow.inputs[2][1], [480.0,275.0])
        self.assertEqual(flow.waits, [2])
        self.assertEqual(len(flow.captures), 2)
        self.assertTrue(all(check["passed"] for check in flow.checks))
        self.assertEqual(flow.states, original, "The read-only harness must never inject game state")

    def test_wrong_start_or_unreachable_mother_fails_before_touch(self):
        for wrong in ("age", "scene", "nearby"):
            flow = SyntheticTouchFlow()
            child = flow.states[0]["childhood"]
            if wrong == "age": child["age"] = 18
            elif wrong == "scene": child["objective"]["id"] = "father_lunch"
            else: child["nearby"]["available"] = False
            with self.subTest(wrong=wrong), self.assertRaisesRegex(RuntimeError, "childhood_starts_at_home"):
                flow.run()
            self.assertEqual(flow.inputs, [])

    def test_touch_that_did_not_move_player_cannot_pass(self):
        flow = SyntheticTouchFlow()
        flow.states[1]["childhood"]["position"] = list(flow.states[0]["childhood"]["position"])
        with self.assertRaisesRegex(RuntimeError, "No matching village runtime state"):
            flow.run()
        self.assertEqual([item[0] for item in flow.inputs], ["swipe"])

    def test_teleport_sized_motion_is_rejected(self):
        flow = SyntheticTouchFlow()
        flow.states[1]["childhood"]["position"][2] += 20.0
        with self.assertRaisesRegex(RuntimeError, "childhood_native_touch_moves_player"):
            flow.run()

    def test_motion_opposite_the_actual_stick_input_is_not_touch_evidence(self):
        flow = SyntheticTouchFlow()
        flow.states[1]["childhood"]["position"][2] = 24.9
        with self.assertRaisesRegex(RuntimeError, "childhood_native_touch_moves_player"):
            flow.run()

    def test_world_or_economy_running_in_dialogue_fails_before_choice(self):
        for changed in ("world_seconds", "grain", "denarii", "night"):
            flow = SyntheticTouchFlow()
            held = flow.states[3]
            if changed == "world_seconds": held[changed] += 0.25
            elif changed == "night": held["childhood"][changed]["elapsed"] = 1.0
            else: held["childhood"][changed] += 1
            with self.subTest(changed=changed), self.assertRaisesRegex(RuntimeError, "childhood_dialogue_freezes_world"):
                flow.run()
            self.assertEqual([item[0] for item in flow.inputs], ["swipe","tap"])

    def test_choice_must_transfer_exactly_two_actual_grain(self):
        for grain in (17,16,14):
            flow = SyntheticTouchFlow()
            flow.states[4]["childhood"]["grain"] = grain
            with self.subTest(grain=grain), self.assertRaisesRegex(RuntimeError, "childhood_touch_promise_transfers_actual_grain"):
                flow.run()

    def test_unaccepted_choice_cannot_be_counted_from_a_tap_alone(self):
        flow = SyntheticTouchFlow()
        flow.states[4]["childhood"]["objective"]["id"] = "family_morning"
        with self.assertRaisesRegex(RuntimeError, "No matching village runtime state"):
            flow.run()

    def test_disabled_choice_is_not_retried_into_an_invented_success(self):
        flow = SyntheticTouchFlow()
        flow.states[3]["controls"]["choice_promise"]["enabled"] = False
        with self.assertRaisesRegex(RuntimeError, "disabled"):
            flow.run()
        self.assertEqual([item[0] for item in flow.inputs], ["swipe","tap"])

    def test_restart_compares_story_identity_but_allows_recorded_live_economy(self):
        flow = SyntheticTouchFlow()
        saved = flow.run()
        restored = snapshot(scene="father_lunch", seconds=20.0, grain=18, position=[-5.0,0.12,25.9])
        restored["childhood"]["denarii"] = 1
        SMOKE.confirm_childhood_restart(saved, restored, flow.record)
        detail = flow.checks[-1]["detail"]
        self.assertTrue(flow.checks[-1]["passed"])
        self.assertEqual(detail["resource_delta_while_playing"], {"denarii":1,"grain":3})

    def test_restart_rejects_reset_world_day_age_scene_or_position(self):
        for field in ("world_id", "day", "age", "scene", "position", "night", "clock"):
            flow = SyntheticTouchFlow()
            saved = flow.run()
            restored = copy.deepcopy(saved)
            restored["screen"] = "playing"
            child = restored["childhood"]
            if field == "world_id": child[field] = "another-world"
            elif field == "scene": child["objective"]["id"] = "family_morning"
            elif field == "position": child[field][0] += 5
            elif field == "night": child[field]["phase"] = "attack"
            elif field == "clock": restored["world_seconds"] = 0
            else: child[field] += 1
            with self.subTest(field=field), self.assertRaisesRegex(RuntimeError, "childhood_decision_survives_restart"):
                SMOKE.confirm_childhood_restart(saved, restored, flow.record)

    def test_missing_or_invalid_observations_never_produce_a_pass(self):
        for field, value in (("day",True), ("age",12.5), ("grain",-1), ("denarii",float("nan")),
                             ("world_id",""), ("position",[0,0,float("inf")]), ("objective",{}), ("night",{}),
                             ("navigation",{"available":True,"target":[1,2]}), ("nearby",None)):
            state = snapshot()
            state["childhood"][field] = value
            with self.subTest(field=field), self.assertRaises(RuntimeError):
                SMOKE.observed_childhood(state)
        with self.assertRaises(RuntimeError):
            SMOKE.observed_childhood({"screen":"playing"})


if __name__ == "__main__":
    unittest.main()
