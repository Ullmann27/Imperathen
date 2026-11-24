"""Check that the Android exporter cannot substitute unapproved source bytes."""
from argparse import Namespace
import importlib.util
from pathlib import Path
import shutil
import sys
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
SPEC = importlib.util.spec_from_file_location("motion_android_builder", ROOT / "tools/build_android_prototype.py")
BUILD = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BUILD)


class ApprovedMotionBuildTest(unittest.TestCase):
    def fixture(self, root):
        project = root / "prototype"
        project.mkdir()
        (project / "project.godot").write_text("config_version=5\n")
        toolchain = {"project": str(project), "source_sha256": BUILD.source_fingerprint(project)}
        proof = {"source_commit": "a" * 40, "source_fingerprint": "b" * 64}
        return toolchain, proof

    def test_actual_source_revision_is_required_and_environment_cannot_replace_it(self):
        with tempfile.TemporaryDirectory() as work:
            toolchain, proof = self.fixture(Path(work))
            BUILD.verify_build_source(toolchain, proof, {}, "compatibility")
            with self.assertRaisesRegex(BUILD.BuildError, "GITHUB_SHA"):
                BUILD.verify_build_source(toolchain, proof, {"GITHUB_SHA": "c" * 40}, "compatibility")
            with self.assertRaisesRegex(BUILD.BuildError, "exact source revision"):
                BUILD.verify_build_source(toolchain, {}, {}, "compatibility")

    def test_post_preflight_edits_and_unreviewed_renderer_are_refused(self):
        with tempfile.TemporaryDirectory() as work:
            root = Path(work)
            toolchain, proof = self.fixture(root)
            with self.assertRaisesRegex(BUILD.BuildError, "renderer"):
                BUILD.verify_build_source(toolchain, proof, {}, "mobile")
            (root / "prototype/project.godot").write_text("unapproved change\n")
            with self.assertRaisesRegex(BUILD.BuildError, "changed after"):
                BUILD.verify_build_source(toolchain, proof, {}, "compatibility")

    def test_missing_gate_never_invokes_export_engine(self):
        with tempfile.TemporaryDirectory() as work:
            root = Path(work)
            toolchain, _ = self.fixture(root)
            args = Namespace(motion_evidence=root / "missing", renderer="compatibility")
            with mock.patch.object(BUILD, "REPOSITORY", root), mock.patch.object(BUILD, "run") as run:
                with self.assertRaisesRegex(ValueError, "missing"):
                    BUILD.build(args, toolchain, {})
                run.assert_not_called()

    def test_isolated_copy_must_match_approved_snapshot_before_export(self):
        with tempfile.TemporaryDirectory() as work:
            root = Path(work)
            toolchain, proof = self.fixture(root)
            args = Namespace(motion_evidence=root / "evidence", renderer="compatibility",
                             output=root / "result.apk", abi="arm64-v8a")
            copytree = shutil.copytree

            def corrupt_copy(source, destination, **kwargs):
                copytree(source, destination, **kwargs)
                (destination / "project.godot").write_text("copy changed\n")

            with mock.patch.object(BUILD, "REPOSITORY", root), \
                 mock.patch.object(BUILD, "require_export", return_value=proof), \
                 mock.patch.object(BUILD, "gate_digest", return_value="d" * 64), \
                 mock.patch.object(BUILD.shutil, "copytree", side_effect=corrupt_copy), \
                 mock.patch.object(BUILD, "run") as run:
                with self.assertRaisesRegex(BUILD.BuildError, "isolated export copy"):
                    BUILD.build(args, toolchain, {})
                run.assert_not_called()
            self.assertFalse((root / "result.apk").exists())


if __name__ == "__main__":
    unittest.main()
