"""Checks that QA APK export cannot overwrite the installed IMPERATHEN app."""
from __future__ import annotations

import json
from pathlib import Path
import tempfile
import unittest

from tools import build_android_prototype as export


class TestQAIdentifierIsolation(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.folder = Path(self.temp.name)
        self.folder.joinpath("export_presets.cfg").write_text(
            Path(export.__file__).resolve().parents[1].joinpath("prototype/export_presets.cfg")
            .read_text(encoding="utf-8"), encoding="utf-8")
        self.toolchain = {
            "preset_section": "preset.0",
            "template_dir": str(self.folder),
            "abi": "arm64-v8a",
        }
        (self.folder/"android_debug.apk").write_bytes(b"official template placeholder: writing settings only")

    def test_private_original_package_is_unchanged_in_source_preset(self):
        source = self.folder.joinpath("export_presets.cfg").read_text(encoding="utf-8")
        self.assertIn('package/unique_name="at.heinz.imperathen"', source)
        export.configure_copy(self.folder,self.toolchain,package_id=export.QA_PACKAGE)
        modified = export.read_config(self.folder/"export_presets.cfg")
        opts = "preset.0.options"
        self.assertEqual(json.loads(modified.get(opts,"package/unique_name")), export.QA_PACKAGE)
        self.assertEqual(json.loads(modified.get(opts,"package/name")), "IMPERATHEN QA")
        self.assertEqual(export.PACKAGE,"at.heinz.imperathen")
        self.assertNotEqual(export.PACKAGE,export.QA_PACKAGE)

    def test_default_keeps_installed_app_identifier(self):
        export.configure_copy(self.folder,self.toolchain)
        opts = export.read_config(self.folder/"export_presets.cfg")
        self.assertEqual(json.loads(opts.get("preset.0.options","package/unique_name")),export.PACKAGE)

    def test_unapproved_package_rejected(self):
        with self.assertRaises(export.BuildError):
            export.configure_copy(self.folder,self.toolchain,package_id="com.example.other")


if __name__ == "__main__":
    unittest.main()
