"""AP-1/AP-2 packaging gates exercise the bytes of synthetic APK ZIPs.

These archives isolate content validation and are not installable Android apps.
The mission-index check also detects future files missing from the APK contract.
"""
from __future__ import annotations

import hashlib
import importlib.util
import json
from pathlib import Path, PurePosixPath
import tempfile
import unittest
import zipfile


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("companion_apk_validation", ROOT / "tools/validate_android_apk.py")
VALIDATOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VALIDATOR)
COMPANION_SCRIPTS = (
    "scripts/story/companion_story.gd",
    "scripts/story/companion_follow.gd",
    "scripts/world/companion_world.gd",
)
BRIDGE_MISSIONS = ("I-02", "I-08", "I-10", "I-11", "I-12", "I-13", "I-14")


def inspect_payload(resources, *, source_marker=None, omitted=(), empty=(),
                    broken_remaps=(), script_mode="remapped"):
    with tempfile.TemporaryDirectory(prefix="imperathen-companion-payload-") as temporary:
        root = Path(temporary)
        source = root / "source"
        source.mkdir()
        if source_marker:
            marker = source / source_marker
            marker.parent.mkdir(parents=True, exist_ok=True)
            marker.write_text("source fixture", encoding="utf-8")
        package = root / "synthetic.apk"
        expected = {}
        with zipfile.ZipFile(package, "w") as archive:
            archive.writestr("assets/project.binary", b"ECFG")
            for resource in VALIDATOR.EXPECTED_RESOURCES:
                archive.writestr("assets/" + resource, "fixture: " + resource)
            for index, resource in enumerate(resources):
                if resource in omitted:
                    continue
                raw = "assets/" + resource
                entry = raw
                payload = json.dumps({"exported_fixture": resource}).encode("utf-8")
                record = {"size_bytes": len(payload), "sha256": hashlib.sha256(payload).hexdigest()}
                if resource.endswith(".gd") and script_mode == "remapped":
                    entry = f"assets/.godot/exported/ap12-{index}.gdc"
                    target = entry.removeprefix("assets/")
                    if resource in broken_remaps:
                        target = ".godot/exported/missing-target.gdc"
                    remap = f'[remap]\npath="res://{target}"\n'.encode("utf-8")
                    archive.writestr(raw + ".remap", remap)
                    record["remap_sha256"] = hashlib.sha256(remap).hexdigest()
                elif resource.endswith(".gd") and script_mode == "converted":
                    entry = str(PurePosixPath(raw).with_suffix(".gdc"))
                archive.writestr(entry, b"" if resource in empty else payload)
                record["entry"] = entry
                expected[resource] = record
        report = {"checks": []}
        VALIDATOR.inspect_zip(package, report, "arm64-v8a", source)
        return {item["id"]: item for item in report["checks"]}, expected


class CompanionPayloadGateTest(unittest.TestCase):
    def assert_missing(self, checks, missing):
        self.assertEqual(checks["companion_story_content"]["status"], "fail")
        self.assertEqual(checks["godot_project_content"]["status"], "fail")
        self.assertEqual(set(checks["companion_story_content"]["evidence"]["missing_resources"]), set(missing))

    def test_required_scripts_are_the_production_companion_modules(self):
        self.assertEqual(VALIDATOR.COMPANION_STORY_RESOURCES, COMPANION_SCRIPTS)
        for resource in COMPANION_SCRIPTS:
            self.assertTrue((ROOT / "prototype" / resource).is_file(), resource)

    def test_each_source_module_requires_the_complete_feature(self):
        for marker in COMPANION_SCRIPTS:
            with self.subTest(marker=marker):
                checks, _ = inspect_payload((), source_marker=marker)
                self.assert_missing(checks, COMPANION_SCRIPTS)
                self.assertTrue(checks["companion_story_content"]["evidence"]["required_by_source"])

    def test_present_scripts_are_resolved_and_hashed_in_each_export_form(self):
        for mode in ("direct", "converted", "remapped"):
            with self.subTest(mode=mode):
                checks, expected = inspect_payload(COMPANION_SCRIPTS, script_mode=mode)
                feature = checks["companion_story_content"]
                self.assertEqual(feature["status"], "pass")
                self.assertEqual(checks["godot_project_content"]["status"], "pass")
                self.assertEqual(len(feature["evidence"]["resources"]), len(COMPANION_SCRIPTS))
                for item in feature["evidence"]["resources"]:
                    self.assertEqual(item["mode"], mode)
                    for key, value in expected[item["source"]].items():
                        self.assertEqual(item[key], value)

    def test_each_missing_companion_script_fails(self):
        for missing in COMPANION_SCRIPTS:
            with self.subTest(missing=missing):
                checks, _ = inspect_payload(COMPANION_SCRIPTS, source_marker=COMPANION_SCRIPTS[0], omitted=(missing,))
                self.assert_missing(checks, (missing,))

    def test_empty_remap_targets_fail(self):
        for empty in COMPANION_SCRIPTS:
            with self.subTest(empty=empty):
                checks, _ = inspect_payload(COMPANION_SCRIPTS, source_marker=COMPANION_SCRIPTS[0], empty=(empty,))
                self.assert_missing(checks, (empty,))

    def test_unlinked_exported_bytes_do_not_satisfy_a_broken_remap(self):
        for broken in COMPANION_SCRIPTS:
            with self.subTest(broken=broken):
                checks, _ = inspect_payload(COMPANION_SCRIPTS, source_marker=COMPANION_SCRIPTS[0], broken_remaps=(broken,))
                self.assert_missing(checks, (broken,))

    def test_partial_feature_fails_without_local_sources(self):
        checks, _ = inspect_payload((COMPANION_SCRIPTS[2],))
        self.assert_missing(checks, COMPANION_SCRIPTS[:2])
        evidence = checks["companion_story_content"]["evidence"]
        self.assertFalse(evidence["required_by_source"])
        self.assertTrue(evidence["detected_in_archive"])

    def test_unrelated_older_source_and_archive_do_not_require_companions(self):
        checks, _ = inspect_payload(())
        self.assertNotIn("companion_story_content", checks)
        self.assertEqual(checks["godot_project_content"]["status"], "pass")


class ChapterStoryPayloadGateTest(unittest.TestCase):
    def assert_missing(self, checks, missing):
        self.assertEqual(checks["chapter_story_content"]["status"], "fail")
        self.assertEqual(checks["godot_project_content"]["status"], "fail")
        self.assertEqual(set(checks["chapter_story_content"]["evidence"]["missing_resources"]), set(missing))

    def test_required_missions_cover_the_actual_runtime_index(self):
        prefix = "assets/story/missions/band1/"
        index = json.loads((ROOT / "prototype" / prefix / "index.json").read_text(encoding="utf-8"))
        expected = {prefix + mission + ".json" for mission in index["order"]}
        required = {resource for resource in VALIDATOR.CHAPTER_STORY_RESOURCES
                    if resource.startswith(prefix) and resource != prefix + "index.json"}
        self.assertEqual(required, expected)
        self.assertEqual(len(required), 14)

    def test_source_loader_requires_all_chapter_payloads(self):
        checks, _ = inspect_payload((), source_marker="scripts/story/mission_data.gd")
        self.assert_missing(checks, VALIDATOR.CHAPTER_STORY_RESOURCES)

    def test_each_missing_mission_fails_including_all_new_bridges(self):
        missions = [resource for resource in VALIDATOR.CHAPTER_STORY_RESOURCES
                    if "/missions/band1/I-" in resource]
        for missing in missions:
            with self.subTest(missing=missing):
                checks, _ = inspect_payload(VALIDATOR.CHAPTER_STORY_RESOURCES,
                                            source_marker="scripts/story/mission_data.gd", omitted=(missing,))
                self.assert_missing(checks, (missing,))

    def test_empty_bridge_json_fails(self):
        for mission in BRIDGE_MISSIONS:
            resource = f"assets/story/missions/band1/{mission}.json"
            with self.subTest(mission=mission):
                checks, _ = inspect_payload(VALIDATOR.CHAPTER_STORY_RESOURCES,
                                            source_marker="scripts/story/mission_data.gd", empty=(resource,))
                self.assert_missing(checks, (resource,))

    def test_raw_mission_json_and_compiled_loaders_are_hashed_from_the_apk(self):
        checks, expected = inspect_payload(VALIDATOR.CHAPTER_STORY_RESOURCES,
                                           source_marker="scripts/story/mission_data.gd")
        feature = checks["chapter_story_content"]
        self.assertEqual(feature["status"], "pass")
        self.assertEqual(checks["godot_project_content"]["status"], "pass")
        self.assertEqual(len(feature["evidence"]["resources"]), len(expected))
        for item in feature["evidence"]["resources"]:
            self.assertEqual(item["mode"], "direct" if item["source"].endswith(".json") else "remapped")
            for key, value in expected[item["source"]].items():
                self.assertEqual(item[key], value)

    def test_a_bridge_in_the_archive_requires_the_rest_without_local_sources(self):
        resource = "assets/story/missions/band1/I-02.json"
        checks, _ = inspect_payload((resource,))
        self.assert_missing(checks, set(VALIDATOR.CHAPTER_STORY_RESOURCES) - {resource})
        self.assertFalse(checks["chapter_story_content"]["evidence"]["required_by_source"])


if __name__ == "__main__":
    unittest.main()
