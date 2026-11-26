"""Negative acceptance tests: missing, stale, malformed and excessive motion evidence."""
import importlib.util
import copy
import json
from pathlib import Path
import shutil
import struct
import subprocess
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
                    for bad in (None, True, float("nan"), float("inf"), 10 ** 400, -.001, limit + .001):
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

    def test_support_scene_cannot_hide_clips_rigs_or_instances(self):
        with tempfile.TemporaryDirectory() as directory:
            scene = Path(directory) / "mode.tscn"
            scene.write_text('[gd_scene format=3]\n[ext_resource type="Script" path="res://m.gd" id="1"]\n'
                             '[node name="Mode" type="Node3D"]\nscript = ExtResource("1")\n')
            self.assertEqual(GATE.support_scene_errors(scene), [])
            for hidden in ('[sub_resource type="Animation" id="a"]\n', '[node name="P" type="AnimationPlayer" parent="."]\n',
                           '[node name="R" type="Skeleton3D" parent="."]\n', '[ext_resource type="PackedScene" path="res://x.glb" id="2"]\n',
                           '[node name="X" parent="." instance=ExtResource("2")]\n'):
                with self.subTest(hidden=hidden):
                    scene.write_text('[gd_scene format=3]\n' + hidden)
                    self.assertTrue(GATE.support_scene_errors(scene))
        for path in ("main.tscn", "scenes/city_support_district.tscn"):
            self.assertIn(path, GATE.SUPPORT)
            self.assertEqual(GATE.support_scene_errors(Path(__file__).resolve().parents[1] / "prototype" / path), [])

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
            # A correct SHA alone cannot turn arbitrary bytes into a video.
            self.assertTrue(GATE.review_errors(root,family,[review],"a"))
            with mock.patch.object(GATE, "capture_errors", return_value=[]):
                self.assertFalse(GATE.review_errors(root,family,[review],"a"))
                self.assertTrue(GATE.review_errors(root,family,[review],"b"))
            capture.write_bytes(b"changed" * 600)
            self.assertTrue(GATE.review_errors(root,family,[review],"a"))

    def test_traversal_not_allowed(self):
        for bad in ("../evidence.mp4","docs/../../bad.mp4","/tmp/a","docs\\file.mp4", ".",
                    "docs//file.mp4", "docs/./file.mp4", "C:/file.mp4", "docs/a\x00.mp4"):
            self.assertFalse(GATE.safe_relative(bad))

    def test_ambiguous_or_nonstandard_json_never_enters_gate(self):
        with tempfile.TemporaryDirectory() as work:
            path = Path(work) / "report.json"
            for value in ('{"passed":false,"passed":true}', '{"metric":NaN}',
                          '{"metric":Infinity}', '{"metric":1e999}'):
                with self.subTest(value=value):
                    path.write_text(value)
                    with self.assertRaises(ValueError):
                        GATE.json_read(path)

    def test_symlinked_runtime_directory_and_capture_parent_are_rejected(self):
        with tempfile.TemporaryDirectory() as work:
            root = Path(work)
            project, outside = root / "prototype", root / "outside"
            project.mkdir(); outside.mkdir()
            (outside / "unregistered.gd").write_text("extends Node\n")
            (project / "alias").symlink_to(outside, target_is_directory=True)
            with self.assertRaisesRegex(ValueError, "symlink"):
                GATE.inventory(project)
            (root / "docs").symlink_to(outside, target_is_directory=True)
            self.assertFalse(GATE.regular_file(root, root / "docs/unregistered.gd"))

    def test_nested_android_name_does_not_hide_runtime_scripts(self):
        with tempfile.TemporaryDirectory() as work:
            project = Path(work)
            path = project / "scripts/android/motion.gd"
            path.parent.mkdir(parents=True)
            path.write_text("extends Node\n")
            self.assertEqual(GATE.inventory(project), (set(), {"scripts/android/motion.gd"}))

    @unittest.skipUnless(shutil.which("ffmpeg") and shutil.which("ffprobe"), "video tools unavailable")
    def test_capture_requires_real_decodable_frames(self):
        with tempfile.TemporaryDirectory() as work:
            path = Path(work) / "synthetic-codec-fixture.mp4"
            # This is only a codec/container fixture, not a game-quality approval.
            subprocess.run([shutil.which("ffmpeg"), "-v", "error", "-f", "lavfi", "-i",
                            "testsrc2=size=64x64:rate=30:duration=1", "-c:v", "libx264", "-threads", "1", str(path)],
                           check=True, capture_output=True, timeout=30)
            self.assertFalse(GATE.capture_errors(path))
            path.write_bytes(path.read_bytes()[:80])
            self.assertTrue(GATE.capture_errors(path))

    @staticmethod
    def clip(subject="assets/hero.glb", name="march"):
        return {"subject": subject, "name": name, "sample_hz": 60, "sample_count": 43,
                "duration_s": .7, "finite": True, "metrics": {key: 0 for key in GATE.RIG_LIMITS}}

    def test_each_raw_clip_is_validated_even_when_aggregate_claims_pass(self):
        clips = [self.clip(name="idle"), self.clip(name="march")]
        record = {"finite": True, "sample_count": 86, "clips": clips,
                  "errors": [], "metrics": {key: 0 for key in GATE.RIG_LIMITS}}
        self.assertFalse(GATE.rig_asset_errors(record, "hero"))
        for key, bad in (("finite", False), ("sample_count", 2), ("duration_s", 0)):
            changed = copy.deepcopy(record)
            changed["clips"][0][key] = bad
            self.assertTrue(GATE.rig_asset_errors(changed, "hero"))
        changed = copy.deepcopy(record)
        changed["clips"][0]["metrics"]["max_loop_seam_m"] = 1
        errors = GATE.rig_asset_errors(changed, "hero")
        self.assertTrue(any("exceeds" in error for error in errors))
        self.assertTrue(any("aggregate" in error for error in errors))

    def family_fixture(self):
        subject = "assets/hero.glb"
        family = {"id": "hero", "profile": "human", "status": "active", "resources": [subject],
                  "review_scope": ["walk", "stop"], "required_checks": ["motion_measurement"],
                  "open_requirements": []}
        metrics = {key: 0 for key in GATE.FAMILY_LIMITS["human"]}
        measured = {"subjects": [subject], "sample_hz": 60, "sample_count": 122,
                    "scenarios": ["walk", "stop"], "metrics": metrics,
                    "scenario_samples": [{"subject": subject, "scenario": scenario, "sample_count": 61,
                                          "sample_hz": 60, "finite": True, "metrics": dict(metrics)}
                                         for scenario in ("walk", "stop")],
                    "actual_runtime_clips": [self.clip()],
                    "runtime_rig_metrics": {key: 0 for key in GATE.RIG_LIMITS}}
        return family, measured

    def test_family_requires_every_subject_scenario_and_actual_runtime_metric(self):
        family, measured = self.family_fixture()
        self.assertFalse(GATE.family_sample_errors(family, measured))
        missing = copy.deepcopy(measured)
        missing["scenario_samples"].pop()
        self.assertTrue(any("required subject/scenario" in error
                            for error in GATE.family_sample_errors(family, missing)))
        hidden = copy.deepcopy(measured)
        hidden["actual_runtime_clips"][0]["metrics"]["max_linear_speed_m_s"] = 30
        self.assertTrue(any("exceeds" in error for error in GATE.family_sample_errors(family, hidden)))
        hidden = copy.deepcopy(measured)
        hidden["scenario_samples"][0]["metrics"]["max_support_slip_m"] = .01
        self.assertTrue(any("aggregate" in error for error in GATE.family_sample_errors(family, hidden)))

    def test_evaluate_rejects_fatal_errors_failed_checks_and_evidence_changes(self):
        family, measured_family = self.family_fixture()
        with tempfile.TemporaryDirectory() as work:
            root = Path(work); evidence = root / "evidence"
            (root / "quality").mkdir(); evidence.mkdir()
            (root / "quality/motion_contract.json").write_text("{}")
            (root / "quality/motion_reviews.json").write_text('{"schema_version":1,"reviews":[]}')
            engine = {"passed": True, "motion_source_fingerprint": "a" * 64, "source_commit": "b" * 40,
                      "checks": [{"check": "motion_measurement", "passed": True, "exit_code": 0}]}
            clips = [self.clip(name="idle"), self.clip(name="march")]
            measured = {"schema_version": 1, "source_fingerprint": "a" * 64, "sample_hz": 60, "fatal": [], "complete": True,
                        "assets": {"assets/hero.glb": {"finite": True, "sample_count": 86, "clips": clips,
                                                      "errors": [], "metrics": {key: 0 for key in GATE.RIG_LIMITS}}},
                        "family_metrics": {"hero": measured_family}}
            def save():
                (evidence / "validation_report.json").write_text(json.dumps(engine))
                (evidence / "motion-measurements.json").write_text(json.dumps(measured))
            save()
            with mock.patch.object(GATE, "validate_inventory", return_value=({"hero": family}, [])), \
                 mock.patch.object(GATE, "source_fingerprint", return_value="a" * 64), \
                 mock.patch.object(GATE, "source_commit", return_value="b" * 40), \
                 mock.patch.object(GATE, "inventory", return_value=({"assets/hero.glb"}, set())), \
                 mock.patch.object(GATE, "review_errors", return_value=[]):
                self.assertTrue(GATE.evaluate(root, evidence)["passed"])
                measured["fatal"] = ["fixture aborted"]
                save()
                self.assertFalse(GATE.evaluate(root, evidence)["passed"])
                measured["fatal"] = []
                measured["complete"] = False
                save()
                self.assertFalse(GATE.evaluate(root, evidence)["passed"])
                measured["complete"] = True
                engine["checks"].append({"check": "extra_regression", "passed": False, "exit_code": 1})
                save()
                self.assertFalse(GATE.evaluate(root, evidence)["passed"])
                engine["checks"].pop(); save()
                with mock.patch.object(GATE, "source_fingerprint", side_effect=["a" * 64, "c" * 64]):
                    self.assertTrue(any("changed during" in item for item in GATE.evaluate(root, evidence)["failures"]))

    def test_malformed_review_entries_are_blockers_instead_of_attribute_errors(self):
        family = {"id": "hero", "review_scope": ["walk"]}
        self.assertTrue(GATE.review_errors(Path.cwd(), family, [None], "a"))
        self.assertTrue(GATE.review_errors(Path.cwd(), family, {}, "a"))

    def test_civilian_equipment_applicability_cannot_drop_core_motion(self):
        civilian = "assets/characters/frontier_civilian_man_0.glb"
        legionary = "assets/characters/frontier_legionary_0.glb"
        family = {"id": "frontier_people", "profile": "human", "resources": [civilian, legionary],
                  "review_scope": ["walk_run_stop", "military_equipment"],
                  "subject_scenarios": {civilian: ["walk_run_stop"],
                                        legionary: ["walk_run_stop", "military_equipment"]}}
        self.assertEqual(GATE.required_subject_scenarios(family)[civilian], {"walk_run_stop"})
        family["subject_scenarios"][civilian] = []
        with self.assertRaisesRegex(ValueError, "core motion"):
            GATE.required_subject_scenarios(family)
        family["subject_scenarios"][civilian] = ["walk_run_stop"]
        family["subject_scenarios"][legionary] = ["walk_run_stop"]
        with self.assertRaisesRegex(ValueError, "core motion"):
            GATE.required_subject_scenarios(family)

    def test_only_verified_derived_texture_uid_is_normalized(self):
        with tempfile.TemporaryDirectory() as work:
            project = Path(work)
            source = project / "assets/characters/frontier_fixture_0.glb"
            source.parent.mkdir(parents=True)
            # Synthetic byte-binding fixture, never a graphical acceptance asset.
            image = b"embedded synthetic texture bytes"
            binary = image + b"\0" * (-len(image) % 4)
            document = {"asset": {"version": "2.0"}, "buffers": [{"byteLength": len(binary)}],
                        "bufferViews": [{"buffer": 0, "byteOffset": 0, "byteLength": len(image)}],
                        "images": [{"bufferView": 0, "mimeType": "image/png", "name": "Embedded"}]}
            payload = json.dumps(document).encode()
            payload += b" " * (-len(payload) % 4)
            source.write_bytes(struct.pack("<4sIIII", b"glTF", 2, 28 + len(payload) + len(binary), len(payload), 0x4E4F534A)
                               + payload + struct.pack("<II", len(binary), 0x004E4942) + binary)
            texture = source.with_name("frontier_fixture_0_Embedded.png")
            settings = texture.with_name(texture.name + ".import")
            texture.write_bytes(image)
            settings.write_text('[remap]\nuid="uid://first"\n[params]\ncompress/mode=0\n')
            first = GATE.derived_texture_inputs(project, set())
            self.assertIsNone(first[texture])
            settings.write_text('[remap]\nuid="uid://second"\n[params]\ncompress/mode=0\n')
            self.assertEqual(first[settings], GATE.derived_texture_inputs(project, set())[settings])
            settings.write_text('[remap]\nuid="uid://second"\n[params]\ncompress/mode=2\n')
            self.assertNotEqual(first[settings], GATE.derived_texture_inputs(project, set())[settings])
            tracked = {texture.relative_to(project).as_posix()}
            self.assertNotIn(texture, GATE.derived_texture_inputs(project, tracked))
            texture.write_bytes(b"modified independently")
            with self.assertRaisesRegex(ValueError, "differs from its embedded"):
                GATE.derived_texture_inputs(project, set())


if __name__ == "__main__":
    unittest.main()
