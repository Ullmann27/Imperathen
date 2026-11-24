"""Negative acceptance tests: missing, stale, malformed and excessive motion evidence."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock

SPEC = importlib.util.spec_from_file_location("motion_quality_gate", Path(__file__).resolve().parents[1] / "tools/motion_quality_gate.py")
GATE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(GATE)


class MotionGateTests(unittest.TestCase):
    def test_every_profile_rejects_missing_nonfinite_boolean_and_excess(self):
        for profile, limits in {"rig": GATE.RIG_LIMITS, **GATE.FAMILY_LIMITS}.items():
            with self.subTest(profile=profile):
                self.assertFalse(GATE.metric_errors(dict(limits), limits, profile))
                for key, limit in limits.items():
                    for bad in (None, True, float("nan"), float("inf"), -.001, limit + .001):
                        values = dict(limits)
                        values[key] = bad
                        self.assertTrue(GATE.metric_errors(values, limits, profile), (key,bad))

    def test_future_classes_have_required_real_contact_metrics(self):
        self.assertIn("max_hoof_paw_slip_m", GATE.FAMILY_LIMITS["animal"])
        self.assertIn("max_seat_drift_m", GATE.FAMILY_LIMITS["rider"])
        self.assertIn("max_rolling_distance_error_ratio", GATE.FAMILY_LIMITS["wheeled"])
        self.assertIn("max_joint_limit_error_deg", GATE.FAMILY_LIMITS["articulated"])
        self.assertIn("max_socket_drift_m", GATE.FAMILY_LIMITS["attached"])

    def test_inventory_detects_new_animal_and_script_but_excludes_source_staging(self):
        with tempfile.TemporaryDirectory() as directory:
            p = Path(directory)
            for name in ("assets/new_horse.glb", "scripts/new_motion.gd", "assets/meshy/source/horse.glb",
                         ".godot/cache.res", "tests/test_motion.gd"):
                file = p / name
                file.parent.mkdir(parents=True, exist_ok=True)
                file.write_bytes(b"x")
            self.assertEqual(GATE.inventory(p), ({"assets/new_horse.glb"}, {"scripts/new_motion.gd"}))

    def test_missing_or_stale_or_failed_proof_stops_export(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            with self.assertRaisesRegex(ValueError,"missing"):
                GATE.require_export(path,path)
            proof = path / "motion-gate.json"
            proof.write_text(json.dumps({"passed":True,"source_fingerprint":"old"}))
            with mock.patch.object(GATE,"evaluate",return_value={"passed":True,"source_fingerprint":"new"}):
                with self.assertRaisesRegex(ValueError,"did not pass"):
                    GATE.require_export(path,path)
            proof.write_text(json.dumps({"passed":False}))
            with mock.patch.object(GATE,"evaluate",return_value={"passed":False}):
                with self.assertRaisesRegex(ValueError,"did not pass"):
                    GATE.require_export(path,path)
            proof.write_text(json.dumps({"passed":True,"source_fingerprint":"new"}))
            with mock.patch.object(GATE,"evaluate",return_value={"passed":True,"source_fingerprint":"new"}):
                self.assertTrue(GATE.require_export(path,path)["passed"])

    def test_no_visual_review_without_actual_capture(self):
        family = {"id":"horse","review_scope":["walk","trot"]}
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.assertTrue(GATE.review_errors(root,family,[],"a"))
            review = {"family":"horse","status":"approved","reviewer":"tester","source_fingerprint":"a",
                      "scenarios":["walk","trot"],"captures":[]}
            self.assertTrue(GATE.review_errors(root,family,[review],"a"))
            capture = root / "docs/test.mp4"
            capture.parent.mkdir()
            # Test the byte-binding only; fixture is explicitly not video evidence.
            capture.write_bytes(b"test" * 600)
            review["captures"] = [{"path":"docs/test.mp4","sha256":GATE.digest(capture),"scenarios":["walk","trot"]}]
            self.assertFalse(GATE.review_errors(root,family,[review],"a"))
            self.assertTrue(GATE.review_errors(root,family,[review],"b"))
            capture.write_bytes(b"changed" * 600)
            self.assertTrue(GATE.review_errors(root,family,[review],"a"))

    def test_traversal_not_allowed(self):
        for bad in ("../evidence.mp4","docs/../../bad.mp4","/tmp/a","docs\\file.mp4"):
            self.assertFalse(GATE.safe_relative(bad))


if __name__ == "__main__":
    unittest.main()
