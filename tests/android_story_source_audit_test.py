"""Story-source audit contracts, using synthetic DOCX files only."""

from __future__ import annotations

import contextlib
import copy
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
import xml.etree.ElementTree as ET
import zipfile


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("audit_screenplays", ROOT / "tools/story/audit_screenplays.py")
AUDITOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(AUDITOR)
W = AUDITOR.W


class StorySourceAuditTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root / "private_band_2.docx"
        self.campaign = self.root / "campaign.json"
        self.original = json.loads((ROOT / "prototype/assets/story/campaign_arc.json").read_text(encoding="utf-8"))
        self.data = copy.deepcopy(self.original)
        # Keep the actual registry's distinction between full Band-1 rows and
        # title-only Band-2 rows; trim only unrelated rows in the fixture.
        self.data["bands"][1]["main_missions"] = self.data["bands"][1]["main_missions"][:1]
        self.data["bands"][1]["side_quests"] = self.data["bands"][1]["side_quests"][:1]
        self.campaign.write_text(json.dumps(self.data), encoding="utf-8")

    def document(self, dialogue=None, time="51 v. Chr. · Spieler ca. 19", title=None, tracked=False):
        mission = self.data["bands"][1]["main_missions"][0]
        quest = self.data["bands"][1]["side_quests"][0]
        paragraphs = [
            f"II-00 · {title or mission['title']}",
            "Zeit / Alter", time,
            "Ort", "Gallisches Winterlager",
            "Besetzung", "Marcus, Spieler",
            "Status", "HISTORICAL FRAME",
            "Storykern", "Ein Bote braucht Hilfe.",
            "II-00 · Dialog-, Mimik- und Sprachregie",
            *(dialogue or ["01 · MARCUS: „Privater Beispielsatz nur für diesen Test.“"]),
            "Nebenquest-Bank des Bandes", f"{quest['id']} · {quest['title']}",
        ]
        root = ET.Element(f"{W}document")
        body = ET.SubElement(root, f"{W}body")
        # Metadata is nested in a table, as in the supplied production sources.
        for index, text in enumerate(paragraphs):
            parent = body
            if 1 <= index <= 10:
                parent = ET.SubElement(ET.SubElement(ET.SubElement(body, f"{W}tbl"), f"{W}tr"), f"{W}tc")
            paragraph = ET.SubElement(parent, f"{W}p")
            run_parent = ET.SubElement(paragraph, f"{W}ins") if tracked and index == 12 else paragraph
            run = ET.SubElement(run_parent, f"{W}r")
            ET.SubElement(run, f"{W}t").text = text
        with zipfile.ZipFile(self.source, "w") as docx:
            docx.writestr("word/document.xml", ET.tostring(root, encoding="utf-8", xml_declaration=True))
        return self.source

    def report(self, **kwargs):
        return AUDITOR.audit([self.source], self.campaign, **kwargs)

    def test_title_only_registry_is_valid_and_coverage_stays_partial(self):
        self.document()
        report = self.report()
        self.assertEqual(report["summary"]["blocking_findings"], 0)
        self.assertEqual(report["summary"]["main_missions"], 1)
        self.assertEqual(report["source_coverage"]["not_audited_bands"], [1, 3, 4])
        self.assertEqual(report["production_clearance"], "not_assessed")

    def test_full_registry_fields_are_compared_and_cast_mismatch_is_reported(self):
        self.document()
        full = {"location": "Gallisches Winterlager", "cast": ["Marcus", "Spieler"],
                "narrative_status": "HISTORICAL FRAME", "story_core": "Ein Bote braucht Hilfe."}
        self.data["bands"][1]["main_missions"][0].update(full)
        self.campaign.write_text(json.dumps(self.data), encoding="utf-8")
        self.assertEqual(self.report()["summary"]["blocking_findings"], 0)
        self.data["bands"][1]["main_missions"][0]["cast"] = ["Julia", "Spieler"]
        self.campaign.write_text(json.dumps(self.data), encoding="utf-8")
        findings = self.report()["sources"][0]["findings"]
        self.assertEqual([(item["code"], item.get("field")) for item in findings],
                         [("registry_metadata_mismatch", "cast")])

    def test_report_has_source_hashes_but_no_private_dialogue_text(self):
        self.document()
        before = self.source.read_bytes()
        report = self.report()
        self.assertNotIn("Privater Beispielsatz", json.dumps(report))
        self.assertEqual(report["sources"][0]["sha256"], AUDITOR.file_fingerprint(self.source))
        self.assertEqual(before, self.source.read_bytes())

    def test_production_language_is_blocking_and_repetition_is_only_review(self):
        self.document(dialogue=[
            "01 · SPIELER: „Wir brauchen einen persistenten Weltzustand.“",
            "02 · MARCUS: „Warte auf mich.“",
            "03 · MARCUS: „Warte auf mich.“",
        ])
        report = self.report()
        self.assertEqual(report["summary"]["spoken_production_language_lines"], 1)
        self.assertEqual(report["summary"]["blocking_findings"], 1)
        self.assertEqual(report["summary"]["within_scene_repeated_line_instances"], 1)
        repeated = [item for item in report["sources"][0]["findings"] if item["code"] == "repeated_line_within_scene"]
        self.assertEqual(repeated[0]["severity"], "review")
        self.assertEqual(repeated[0]["line_numbers"], [2, 3])
        self.assertNotIn("Warte auf mich", json.dumps(report))

    def test_repeated_words_by_different_speakers_are_not_duplicate_lines(self):
        self.document(dialogue=["01 · MARCUS: „Ja.“", "02 · SPIELER: „Ja.“"])
        self.assertEqual(self.report()["summary"]["within_scene_repeated_line_instances"], 0)

    def test_numbered_dialogue_must_not_be_silently_skipped(self):
        self.document(dialogue=['01 · MARCUS: "Unsupported quote style."'])
        report = self.report()
        self.assertEqual(report["summary"]["findings_by_code"]["unparsed_main_dialogue"], 1)
        self.assertGreater(report["summary"]["blocking_findings"], 0)

    def test_skipped_dialogue_number_is_blocking(self):
        self.document(dialogue=["01 · MARCUS: „Komm.“", "03 · SPIELER: „Gleich.“"])
        self.assertEqual(self.report()["summary"]["findings_by_code"]["dialogue_number_sequence"], 1)

    def test_explicit_age_range_conflict_is_reviewed_without_changing_source(self):
        self.document(time="34–32 v. Chr. · Spieler ca. 34–36")
        report = self.report()
        finding = next(item for item in report["sources"][0]["findings"] if item["code"] == "age_calendar_review")
        self.assertEqual(finding["campaign_age_range"], [36, 38])
        self.assertEqual(finding["declared_age_range"], [34, 36])
        self.assertEqual(report["summary"]["blocking_findings"], 0)

    def test_approximate_age_inside_multi_year_period_is_allowed(self):
        self.document(time="49/48 v. Chr. · Spieler ca. 22")
        self.assertNotIn("age_calendar_review", self.report()["summary"]["findings_by_code"])

    def test_missing_required_volumes_and_duplicate_inputs_fail(self):
        self.document()
        self.assertEqual(self.report(require_all_volumes=True)["summary"]["blocking_findings"], 3)
        with self.assertRaisesRegex(ValueError, "at most one DOCX"):
            AUDITOR.audit([self.source, self.source], self.campaign)

    def test_unresolved_tracked_changes_and_title_difference_are_reported(self):
        self.document(title="Ein anderer Titel", tracked=True)
        report = self.report()
        self.assertEqual(report["summary"]["findings_by_code"]["unresolved_tracked_changes"], 1)
        self.assertEqual(report["summary"]["findings_by_code"]["registry_metadata_mismatch"], 1)

    def test_cli_exit_codes_and_report_output(self):
        self.document(dialogue=["01 · SPIELER: „Das Event-Ledger fehlt.“"])
        target = self.root / "evidence" / "audit.json"
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            code = AUDITOR.main([str(self.source), "--campaign", str(self.campaign), "--report", str(target)])
            self.assertEqual(code, 1)
            self.assertEqual(json.loads(target.read_text())["summary"]["blocking_findings"], 1)
            self.source.write_bytes(b"not a DOCX")
            self.assertEqual(AUDITOR.main([str(self.source), "--campaign", str(self.campaign)]), 2)


if __name__ == "__main__":
    unittest.main()
