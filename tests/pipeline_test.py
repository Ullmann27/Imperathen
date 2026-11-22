"""Regression coverage for coordination, evidence freshness and command boundaries."""
from contextlib import redirect_stdout
import copy
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch


REPO = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("agent_pipeline", REPO / "tools/agent_pipeline.py")
pipeline = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(pipeline)


class PipelineTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.manifest = json.loads((REPO / "coordination/tasks.json").read_text(encoding="utf-8"))
        self.write_manifest()
        for name in ("preview/core/game.mjs", "tests/core.test.mjs", "preview/app.mjs", "tools/agent_pipeline.py", "tests/pipeline_test.py"):
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("// fixture\n", encoding="utf-8")
        self.output = io.StringIO()
        self.redirect = redirect_stdout(self.output)
        self.redirect.__enter__()
        self.addCleanup(self.redirect.__exit__, None, None, None)

    def write_manifest(self):
        path = self.root / pipeline.MANIFEST
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(self.manifest), encoding="utf-8")

    def run_pass(self, task_id):
        with patch.object(pipeline.subprocess, "run", return_value=subprocess.CompletedProcess([], 0)), patch.object(pipeline.shutil, "which", return_value="/runtime/tool"):
            self.assertEqual(pipeline.run(self.root, self.manifest, task_id), 0)

    def complete_foundation(self):
        pipeline.claim(self.root, self.manifest, "foundation_qa", "foundation_qa")
        self.run_pass("foundation_qa")
        pipeline.handoff(self.root, self.manifest, "foundation_qa", "foundation_qa", "Fixture checked", ["tests/core.test.mjs"])

    def test_valid_manifest_and_existing_disjoint_files(self):
        pipeline.validate_manifest(self.root, self.manifest)
        pipeline.check(self.root, self.manifest, pipeline.load_state(self.root))

    def test_future_subtree_overlap_is_rejected_before_files_exist(self):
        self.manifest["tasks"][0]["allowed_paths"].append("future/tree/**")
        self.manifest["tasks"][1]["allowed_paths"].append("future/tree/child.mjs")
        with self.assertRaisesRegex(pipeline.PipelineError, "Dateikonflikt"):
            pipeline.validate_manifest(self.root, self.manifest)

    def test_dependency_cycle_and_unknown_dependency_are_rejected(self):
        self.manifest["tasks"][0]["depends_on"] = ["frontend_intro"]
        with self.assertRaisesRegex(pipeline.PipelineError, "Zyklische"):
            pipeline.validate_manifest(self.root, self.manifest)
        self.manifest["tasks"][0]["depends_on"] = ["missing"]
        with self.assertRaisesRegex(pipeline.PipelineError, "Unbekannte Abhängigkeit"):
            pipeline.validate_manifest(self.root, self.manifest)

    def test_arbitrary_command_strings_and_outside_paths_are_rejected(self):
        bad = copy.deepcopy(self.manifest)
        bad["tasks"][0]["checks"] = ["sh -c arbitrary-command"]
        with self.assertRaisesRegex(pipeline.PipelineError, "freie Befehle"):
            pipeline.validate_manifest(self.root, bad)
        for name in ("../outside", "/tmp/outside", "preview/../escape", "preview\\escape", "preview/*.mjs"):
            with self.subTest(path=name), self.assertRaises(pipeline.PipelineError):
                pipeline.safe_path(self.root, name, pattern=True)

    def test_symlink_outside_repository_is_rejected(self):
        outside = tempfile.TemporaryDirectory()
        self.addCleanup(outside.cleanup)
        link = self.root / "external"
        try:
            link.symlink_to(outside.name, target_is_directory=True)
        except OSError:
            self.skipTest("Symlink privilege unavailable on this system")
        with self.assertRaisesRegex(pipeline.PipelineError, "verlässt"):
            pipeline.safe_path(self.root, "external/evidence.txt")

    def test_owned_symlink_cannot_hide_source_changes_from_fingerprint(self):
        link = self.root / "preview/core/linked.mjs"
        try:
            link.symlink_to(self.root / "preview/app.mjs")
        except OSError:
            self.skipTest("Symlink privilege unavailable on this system")
        with self.assertRaisesRegex(pipeline.PipelineError, "Symlink im Aufgabenbereich"):
            pipeline.scope_digest(self.root, self.manifest["tasks"][0])

    def test_lock_prevents_concurrent_writers_and_is_released_after_error(self):
        with pipeline.locked_state(self.root):
            with self.assertRaisesRegex(pipeline.PipelineError, "gesperrt"):
                with pipeline.locked_state(self.root):
                    self.fail("Second writer entered the lock")
        original = (self.root / pipeline.LOCAL / "state.json").read_bytes()
        with self.assertRaisesRegex(RuntimeError, "interrupted"):
            with pipeline.locked_state(self.root) as state:
                state["tasks"]["partial"] = {}
                raise RuntimeError("interrupted")
        self.assertEqual((self.root / pipeline.LOCAL / "state.json").read_bytes(), original)
        self.assertFalse((self.root / pipeline.LOCAL / "state.lock").exists())

    def test_wrong_owner_claim_and_handoff_without_run_fail(self):
        with self.assertRaises(pipeline.PipelineError):
            pipeline.claim(self.root, self.manifest, "foundation_qa", "frontend_intro")
        pipeline.claim(self.root, self.manifest, "foundation_qa", "foundation_qa")
        with self.assertRaisesRegex(pipeline.PipelineError, "Prüflauf"):
            pipeline.handoff(self.root, self.manifest, "foundation_qa", "foundation_qa", "No test yet", ["tests/core.test.mjs"])
        self.assertEqual(pipeline.load_state(self.root)["tasks"]["foundation_qa"]["status"], "claimed")

    def test_source_change_after_check_requires_new_run(self):
        pipeline.claim(self.root, self.manifest, "foundation_qa", "foundation_qa")
        self.run_pass("foundation_qa")
        (self.root / "preview/core/game.mjs").write_text("changed\n", encoding="utf-8")
        with self.assertRaisesRegex(pipeline.PipelineError, "Prüflauf"):
            pipeline.handoff(self.root, self.manifest, "foundation_qa", "foundation_qa", "Stale test", ["tests/core.test.mjs"])

    def test_missing_evidence_or_dependency_does_not_partially_handoff(self):
        pipeline.claim(self.root, self.manifest, "frontend_intro", "frontend_intro")
        self.run_pass("frontend_intro")
        with self.assertRaisesRegex(pipeline.PipelineError, "Nachweisdatei"):
            pipeline.handoff(self.root, self.manifest, "frontend_intro", "frontend_intro", "Missing proof", ["missing.txt"])
        with self.assertRaisesRegex(pipeline.PipelineError, "Abhängigkeiten"):
            pipeline.handoff(self.root, self.manifest, "frontend_intro", "frontend_intro", "Pending dependency", ["preview/app.mjs"])
        self.assertEqual(pipeline.load_state(self.root)["tasks"]["frontend_intro"]["status"], "claimed")

    def test_handoff_detects_changed_evidence_and_reopen_requires_new_handoff(self):
        self.complete_foundation()
        pipeline.check(self.root, self.manifest, pipeline.load_state(self.root))
        (self.root / "tests/core.test.mjs").write_text("changed", encoding="utf-8")
        with self.assertRaisesRegex(pipeline.PipelineError, "veränderter Nachweis"):
            pipeline.check(self.root, self.manifest, pipeline.load_state(self.root))
        with self.assertRaisesRegex(pipeline.PipelineError, "bereits übergeben"):
            pipeline.claim(self.root, self.manifest, "foundation_qa", "foundation_qa")
        pipeline.claim(self.root, self.manifest, "foundation_qa", "foundation_qa", reopen=True)
        state = pipeline.load_state(self.root)
        self.assertEqual(state["tasks"]["foundation_qa"]["status"], "claimed")
        self.assertIsNone(state["tasks"]["foundation_qa"]["handoff"])

    def test_manifest_change_cannot_silently_reuse_existing_claims(self):
        pipeline.claim(self.root, self.manifest, "foundation_qa", "foundation_qa")
        self.manifest["project"] += " changed"
        self.write_manifest()
        with self.assertRaisesRegex(pipeline.PipelineError, "Manifest geändert"):
            pipeline.load_state(self.root)

    def test_missing_checker_is_not_reported_as_passed_and_commands_use_no_shell(self):
        with patch.object(pipeline.subprocess, "run", return_value=subprocess.CompletedProcess([], 0)) as execute, patch.object(pipeline.shutil, "which", return_value="/runtime/tool"):
            result = pipeline.run(self.root, self.manifest)
        self.assertEqual(result, 2)
        self.assertEqual(pipeline.load_state(self.root)["checks"]["unreal-static"]["status"], "not_checked")
        self.assertEqual(execute.call_count, 3)
        for call in execute.call_args_list:
            self.assertIsInstance(call.args[0], list)
            self.assertFalse(call.kwargs["shell"])
        self.assertIn("NICHT GEPRÜFT unreal-static", self.output.getvalue())

    def test_failed_test_cannot_enable_handoff(self):
        pipeline.claim(self.root, self.manifest, "foundation_qa", "foundation_qa")
        with patch.object(pipeline.subprocess, "run", return_value=subprocess.CompletedProcess([], 1)), patch.object(pipeline.shutil, "which", return_value="/runtime/tool"):
            self.assertEqual(pipeline.run(self.root, self.manifest, "foundation_qa"), 1)
        with self.assertRaisesRegex(pipeline.PipelineError, "Prüflauf"):
            pipeline.handoff(self.root, self.manifest, "foundation_qa", "foundation_qa", "Failed tests", ["tests/core.test.mjs"])


if __name__ == "__main__":
    unittest.main()
