"""Regression tests for the playable first morning and its historical context."""
from __future__ import annotations

import hashlib
import importlib.util
from pathlib import Path
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("reference_apk_validation", ROOT / "tools/validate_android_apk.py")
VALIDATOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VALIDATOR)

GROUPS = {
    "first_morning_content": VALIDATOR.FIRST_MORNING_RESOURCES,
    "world_history_content": VALIDATOR.WORLD_HISTORY_RESOURCES,
    "tribal_world_content": VALIDATOR.TRIBAL_WORLD_RESOURCES,
    "world_state_content": VALIDATOR.WORLD_STATE_RESOURCES,
}
RESOURCES = {item for group in GROUPS.values() for item in group}


def inspect_fixture(*, current_source=True, exported=RESOURCES):
    with tempfile.TemporaryDirectory(prefix="imperathen-reference-apk-") as temporary:
        root = Path(temporary)
        source = root / "source"
        if current_source:
            for path in RESOURCES:
                resource = source / path
                resource.parent.mkdir(parents=True, exist_ok=True)
                resource.write_bytes(path.encode())

        package = root / "synthetic.apk"
        with zipfile.ZipFile(package, "w") as archive:
            archive.writestr("assets/project.binary", b"ECFG")
            for resource in set(VALIDATOR.EXPECTED_RESOURCES) | exported:
                archive.writestr("assets/" + resource, resource.encode())

        report = {"checks": []}
        VALIDATOR.inspect_zip(package, report, "arm64-v8a", source)
        return {item["id"]: item for item in report["checks"]}


class ReferencePayloadGateTest(unittest.TestCase):
    def test_complete_payload_records_content_hashes(self):
        checks = inspect_fixture()
        self.assertEqual(checks["godot_project_content"]["status"], "pass")
        for feature, resources in GROUPS.items():
            result = checks[feature]
            self.assertEqual(result["status"], "pass")
            self.assertEqual(
                {item["source"]: item["sha256"] for item in result["evidence"]["resources"]},
                {resource: hashlib.sha256(resource.encode()).hexdigest() for resource in resources},
            )

    def test_missing_runtime_resource_fails_against_current_or_unknown_source(self):
        for identifier, resources in GROUPS.items():
            for missing in resources:
                for current_source in (True, False):
                    with self.subTest(resource=missing, current_source=current_source):
                        checks = inspect_fixture(current_source=current_source, exported=RESOURCES - {missing})
                        self.assertEqual(checks[identifier]["status"], "fail")
                        self.assertEqual(checks[identifier]["evidence"]["missing_resources"], [missing])
                        self.assertEqual(checks["godot_project_content"]["status"], "fail")

    def test_older_checkout_does_not_require_new_features(self):
        checks = inspect_fixture(current_source=False, exported=set())
        self.assertEqual(checks["godot_project_content"]["status"], "pass")
        self.assertFalse(GROUPS.keys() & checks.keys())

    def test_calendar_and_tribes_do_not_activate_the_later_shared_state(self):
        payload = RESOURCES - set(VALIDATOR.WORLD_STATE_SCRIPTS)
        checks = inspect_fixture(current_source=False, exported=payload)
        self.assertEqual(checks["world_history_content"]["status"], "pass")
        self.assertEqual(checks["tribal_world_content"]["status"], "pass")
        self.assertNotIn("world_state_content", checks)
        self.assertEqual(checks["godot_project_content"]["status"], "pass")


if __name__ == "__main__":
    unittest.main()
