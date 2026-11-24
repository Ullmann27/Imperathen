"""Exercise draft recovery without contacting GitHub or publishing test files."""
from __future__ import annotations

import copy
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
SPEC = importlib.util.spec_from_file_location("village_publisher", ROOT / "tools/publish_village_download.py")
PUBLISHER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PUBLISHER)


class DraftReleaseLookupTest(unittest.TestCase):
    def test_pending_tag_uses_confirmed_release_id(self):
        response = {"data": {"repository": {"release": {"databaseId": 123}}}}
        draft = {"id": 123, "draft": True, "tag_name": "village-test"}
        with mock.patch.object(PUBLISHER, "gh", return_value=json.dumps(response)) as gh, \
                mock.patch.object(PUBLISHER, "api", return_value=draft) as api:
            self.assertEqual(PUBLISHER.find_release("village-test"), draft)
        api.assert_called_once_with("releases/123")
        self.assertEqual(gh.call_args.args[:2], ("api", "graphql"))
        self.assertIn("tag=village-test", gh.call_args.args)

    def test_explicit_missing_release_allows_initial_creation(self):
        response = {"data": {"repository": {"release": None}}}
        with mock.patch.object(PUBLISHER, "gh", return_value=json.dumps(response)), \
                mock.patch.object(PUBLISHER, "api") as api:
            self.assertIsNone(PUBLISHER.find_release("village-test"))
        api.assert_not_called()

    def test_lookup_errors_never_look_like_an_absent_release(self):
        cases = ({"errors": [{"message": "not accessible"}]},
                 {"data": {"repository": None}},
                 {"data": {"repository": {}}},
                 {"data": {"repository": {"release": {"databaseId": None}}}})
        for response in cases:
            with self.subTest(response=response), \
                    mock.patch.object(PUBLISHER, "gh", return_value=json.dumps(response)), \
                    mock.patch.object(PUBLISHER, "api") as api:
                with self.assertRaises(RuntimeError):
                    PUBLISHER.find_release("village-test")
                api.assert_not_called()

    def test_existing_draft_for_another_source_is_never_modified(self):
        source = "a" * 40
        release = {"id": 123, "tag_name": "village-2026-11-23-" + source[:8],
                   "target_commitish": "b" * 40, "prerelease": True,
                   "draft": True, "assets": []}
        proof = {"apk": "unneeded.apk", "sha256": "c" * 64, "size_bytes": 1}
        with tempfile.TemporaryDirectory(prefix="village-draft-test-") as work:
            temporary = Path(work)
            with mock.patch.object(PUBLISHER, "find_release", return_value=release), \
                    mock.patch.object(PUBLISHER, "gh") as gh:
                with self.assertRaisesRegex(RuntimeError, "another purpose"):
                    PUBLISHER.publish(temporary / "public", temporary, source, "456", proof)
                gh.assert_not_called()

    def test_existing_draft_with_different_apk_bytes_is_never_modified(self):
        source = "a" * 40
        with tempfile.TemporaryDirectory(prefix="village-draft-test-") as work:
            temporary = Path(work)
            public = temporary / "public"
            public.mkdir()
            apk = public / ("IMPERATHEN-" + source[:8] + "-arm64.apk")
            apk.write_bytes(b"explicitly synthetic publication fixture")
            checksum = PUBLISHER.digest(apk)
            release = {"id": 123, "tag_name": "village-2026-11-23-" + source[:8],
                       "target_commitish": source, "prerelease": True, "draft": True,
                       "assets": [{"name": apk.name, "state": "uploaded",
                                   "size": apk.stat().st_size, "digest": "sha256:" + "0" * 64}]}
            proof = {"apk": apk.name, "sha256": checksum, "size_bytes": apk.stat().st_size}
            with mock.patch.object(PUBLISHER, "find_release", return_value=release), \
                    mock.patch.object(PUBLISHER, "gh") as gh:
                with self.assertRaisesRegex(RuntimeError, "asset hash differs"):
                    PUBLISHER.publish(public, temporary, source, "456", proof)
                gh.assert_not_called()

    def test_existing_draft_is_uploaded_and_published_without_another_post(self):
        source = "a" * 40
        tag = "village-2026-11-23-" + source[:8]
        release = {"id": 123, "tag_name": tag, "target_commitish": source,
                   "prerelease": True, "draft": True, "assets": []}
        with tempfile.TemporaryDirectory(prefix="village-draft-test-") as work:
            temporary = Path(work)
            public = temporary / "public"
            public.mkdir()
            apk = public / ("IMPERATHEN-" + source[:8] + "-arm64.apk")
            apk.write_bytes(b"explicitly synthetic publication fixture")
            checksum = PUBLISHER.digest(apk)

            def gh(*args, **kwargs):
                if args[:2] == ("api", "graphql"):
                    return json.dumps({"data": {"repository": {"release": {"databaseId": 123}}}})
                if args[:2] == ("release", "upload"):
                    self.assertEqual(args[2], tag)
                    release["assets"] = [{"name": apk.name, "state": "uploaded",
                                          "size": apk.stat().st_size, "digest": "sha256:" + checksum}]
                    return ""
                if args[:2] == ("api", "repos/" + PUBLISHER.REPO + "/releases/123"):
                    self.assertEqual(args[2:4], ("--method", "PATCH"))
                    request = json.loads(Path(args[-1]).read_text())
                    self.assertFalse(request["draft"])
                    release["draft"] = False
                    return json.dumps(release)
                self.fail("Unexpected GitHub operation: " + repr(args))

            def api(path, **kwargs):
                self.assertEqual(path, "releases/123")
                return copy.deepcopy(release)

            proof = {"apk": apk.name, "sha256": checksum, "size_bytes": apk.stat().st_size}
            with mock.patch.object(PUBLISHER, "gh", side_effect=gh), \
                    mock.patch.object(PUBLISHER, "api", side_effect=api):
                result = PUBLISHER.publish(public, temporary, source, "456", proof)
            self.assertEqual(result, "https://github.com/" + PUBLISHER.REPO + "/releases/tag/" + tag)
            self.assertFalse(release["draft"])


class StrictMotionPublicationTest(unittest.TestCase):
    def fixture(self, root):
        directory = root / "engine-checks"
        directory.mkdir()
        engine = {"source_commit": "a" * 40, "motion_source_fingerprint": "b" * 64}
        measured = {"schema_version": 1, "source_fingerprint": "b" * 64, "sample_hz": 60,
                    "fatal": [], "complete": True, "assets": {}, "family_metrics": {"hero": {}}}
        gate = {"schema_version": 1, "passed": True, "source_commit": "a" * 40,
                "source_fingerprint": "b" * 64, "sample_hz": 60, "failures": [], "measured_assets": 0,
                "families": [{"id": "hero", "status": "active", "passed": True, "failures": []}],
                "review_report_sha256": "c" * 64}
        build = {"motion_source_fingerprint": "b" * 64, "source_sha256": "d" * 64}

        def save():
            # These are only hash-chain fixtures; they are not game acceptance evidence.
            (directory / "validation_report.json").write_text(json.dumps(engine))
            (directory / "motion-measurements.json").write_text(json.dumps(measured))
            gate["engine_report_sha256"] = PUBLISHER.digest(directory / "validation_report.json")
            gate["measurement_report_sha256"] = PUBLISHER.digest(directory / "motion-measurements.json")
            (directory / "motion-gate.json").write_text(json.dumps(gate))
            build["motion_gate_sha256"] = PUBLISHER.digest(directory / "motion-gate.json")

        save()
        return engine, measured, gate, build, save

    def test_strict_publication_checks_full_evidence_hash_chain(self):
        with tempfile.TemporaryDirectory() as work:
            root = Path(work)
            engine, measured, gate, build, save = self.fixture(root)
            self.assertTrue(PUBLISHER.verify_motion_evidence(root, build, engine, "a" * 40)["passed"])
            (root / "engine-checks/motion-measurements.json").write_text("{}")
            with self.assertRaisesRegex(RuntimeError, "does not match"):
                PUBLISHER.verify_motion_evidence(root, build, engine, "a" * 40)

    def test_blank_matching_hashes_and_hidden_fatal_errors_are_rejected(self):
        with tempfile.TemporaryDirectory() as work:
            root = Path(work)
            engine, measured, gate, build, save = self.fixture(root)
            measured["fatal"] = ["actual runtime was not measured"]
            save()
            with self.assertRaisesRegex(RuntimeError, "Raw movement"):
                PUBLISHER.verify_motion_evidence(root, build, engine, "a" * 40)
            measured["fatal"] = []
            gate["source_fingerprint"] = engine["motion_source_fingerprint"] = build["motion_source_fingerprint"] = None
            save()
            with self.assertRaisesRegex(RuntimeError, "valid source fingerprint"):
                PUBLISHER.verify_motion_evidence(root, build, engine, "a" * 40)

    def test_failed_or_missing_family_cannot_publish_even_with_matching_hashes(self):
        with tempfile.TemporaryDirectory() as work:
            root = Path(work)
            engine, measured, gate, build, save = self.fixture(root)
            gate["families"][0]["passed"] = False
            save()
            with self.assertRaisesRegex(RuntimeError, "family did not pass"):
                PUBLISHER.verify_motion_evidence(root, build, engine, "a" * 40)
            gate["families"][0]["passed"] = True
            measured["family_metrics"] = {}
            save()
            with self.assertRaisesRegex(RuntimeError, "lack actual measurements"):
                PUBLISHER.verify_motion_evidence(root, build, engine, "a" * 40)

    def test_publisher_rejects_ambiguous_evidence_json(self):
        with tempfile.TemporaryDirectory() as work:
            path = Path(work) / "proof.json"
            for text in ('{"passed":false,"passed":true}', '[]', '{"metric":NaN}', '{"metric":1e999}'):
                path.write_text(text)
                with self.assertRaises(RuntimeError):
                    PUBLISHER.read_json(path)


if __name__ == "__main__":
    unittest.main()
