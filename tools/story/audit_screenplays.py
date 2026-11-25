#!/usr/bin/env python3
"""Audit local screenplay DOCX sources without publishing their dialogue text.

Exit 0: no automated blockers in the supplied subset; 1: findings need revision;
2: unreadable/unsupported input. A clean result is not a voice or runtime approval.
Only word/document.xml is inspected. Original DOCX files are never modified.
"""

from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import re
import sys
import unicodedata
import xml.etree.ElementTree as ET
import zipfile


ROOT = Path(__file__).resolve().parents[2]
W = "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}"
MAX_DOCUMENT_XML_BYTES = 16 * 1024 * 1024
VOLUMES = {"I": 1, "II": 2, "III": 3, "IV": 4}
MAIN_HEADING = re.compile(r"^(I|II|III|IV)-(\d{2})\s*·\s*(.+)$")
SIDE_HEADING = re.compile(r"^(NQ-([1-4])-\d{2})\s*·\s*(.+)$")
SPOKEN_LINE = re.compile(r"^(\d{2})\s*·\s*([^:]+):\s*„(.*)“$")
SUBSECTIONS = {
    "Gameplay, Questlogik und Freiheit",
    "Dialog-, Mimik- und Sprachregie",
    "VID-B/VID-C und Produktionsblatt",
}
FIELDS = {
    "Zeit / Alter": "time_and_age",
    "Ort": "location",
    "Besetzung": "cast",
    "Status": "narrative_status",
    "Storykern": "story_core",
}
PRODUCTION_LANGUAGE = {
    "world_state": re.compile(r"\bWeltzust[aä]nd\w*", re.I),
    "relationship_meter": re.compile(r"\bSympathieleist\w*", re.I),
    "event_ledger": re.compile(r"\bEvent[-\s]?Ledger\b", re.I),
    "save_or_reload": re.compile(r"\b(?:Save|Load|Savegame|Checkpoint|Reload)\b", re.I),
    "game_system": re.compile(r"\b(?:Gameplay|Questmarker|NPC|actor_id|event_id)\b", re.I),
    "render_system": re.compile(r"\b(?:Third[- ]Person|Runtime|LOD|Navmesh)\b", re.I),
}
TIME_AND_AGE = re.compile(
    r"^(\d+)\s*(?:[–/\-]\s*(\d+))?\s*v\.\s*Chr\.\s*·\s*"
    r"Spieler\s+ca\.\s*(\d+)\s*(?:[–/\-]\s*(\d+))?$"
)


def normalized(value: str) -> str:
    return " ".join(unicodedata.normalize("NFC", value).split())


def fingerprint(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def file_fingerprint(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def read_paragraphs(path: Path) -> tuple[list[dict], bool]:
    with zipfile.ZipFile(path) as document:
        info = document.getinfo("word/document.xml")
        if info.file_size > MAX_DOCUMENT_XML_BYTES:
            raise ValueError(f"{path.name}: document.xml exceeds the 16 MiB audit limit")
        xml = document.read(info)
    if b"<!DOCTYPE" in xml or b"<!ENTITY" in xml:
        raise ValueError(f"{path.name}: DTD/entity declarations are not supported")
    root = ET.fromstring(xml)
    body = root.find(f"{W}body")
    if body is None:
        raise ValueError(f"{path.name}: document body missing")
    paragraphs = []
    for number, element in enumerate(body.iter(f"{W}p"), 1):
        text = "".join(part.text or "" for part in element.iter(f"{W}t"))
        paragraphs.append({"paragraph": number, "text": normalized(text)})
    revisions = any(element.tag in {f"{W}ins", f"{W}del"} for element in body.iter())
    return paragraphs, revisions


def parse_source(path: Path) -> dict:
    paragraphs, revisions = read_paragraphs(path)
    missions = []
    side_quests = []
    current = None
    for index, paragraph in enumerate(paragraphs):
        text = paragraph["text"]
        main = MAIN_HEADING.fullmatch(text)
        side = SIDE_HEADING.fullmatch(text)
        if main and main.group(3) not in SUBSECTIONS:
            current = {
                "id": f"{main.group(1)}-{main.group(2)}",
                "title": main.group(3),
                "band": VOLUMES[main.group(1)],
                "paragraph": paragraph["paragraph"],
                "dialogue": [],
                "unparsed_dialogue_paragraphs": [],
                "field_paragraphs": {},
            }
            missions.append(current)
        elif side:
            side_quests.append({"id": side.group(1), "band": int(side.group(2)),
                                "title": side.group(3), "paragraph": paragraph["paragraph"]})
            current = None
        elif text in {"Nebenquest-Bank des Bandes", "Quellen-, Wahrheits- und Rekonstruktionsregeln"}:
            current = None
        elif current is not None:
            if text in FIELDS and FIELDS[text] not in current:
                field = FIELDS[text]
                if index + 1 >= len(paragraphs):
                    raise ValueError(f"{path.name}: missing field value at paragraph {paragraph['paragraph']}")
                value = paragraphs[index + 1]
                current[field] = value["text"]
                current["field_paragraphs"][field] = value["paragraph"]
            spoken = SPOKEN_LINE.fullmatch(text)
            if spoken:
                current["dialogue"].append({"number": int(spoken.group(1)),
                    "speaker": spoken.group(2), "text": spoken.group(3),
                    "paragraph": paragraph["paragraph"]})
            elif re.match(r"^\d{2}\s*·\s*[^:]+:", text):
                current["unparsed_dialogue_paragraphs"].append(paragraph["paragraph"])
    bands = {mission["band"] for mission in missions}
    if len(bands) != 1:
        raise ValueError(f"{path.name}: expected main mission headings from exactly one volume")
    band = bands.pop()
    if any(quest["band"] != band for quest in side_quests):
        raise ValueError(f"{path.name}: side quest volume does not match main missions")
    return {"file_name": path.name, "sha256": file_fingerprint(path), "band": band,
            "paragraphs": len(paragraphs), "words": sum(len(p["text"].split()) for p in paragraphs),
            "tracked_changes": revisions, "missions": missions, "side_quests": side_quests}


def audit_source(source: dict, band: dict, birth_year_bce: int) -> dict:
    findings = []
    mission_reports = []
    dialogue_fingerprints = []
    def finding(code: str, severity: str, **details) -> None:
        findings.append({"code": code, "severity": severity, **details})

    if source["tracked_changes"]:
        finding("unresolved_tracked_changes", "error")
    for source_key, registry_key in (("missions", "main_missions"), ("side_quests", "side_quests")):
        actual_ids = [row["id"] for row in source[source_key]]
        expected_ids = [row["id"] for row in band[registry_key]]
        if actual_ids != expected_ids:
            finding("registry_mission_sequence", "error", collection=registry_key,
                    expected_ids=expected_ids, actual_ids=actual_ids)
        expected = {row["id"]: row for row in band[registry_key]}
        for row in source[source_key]:
            if row["id"] not in expected:
                continue
            fields = ("title", "location", "cast", "narrative_status", "story_core") if source_key == "missions" else ("title",)
            for field in fields:
                # Volumes 2-4 currently catalogue IDs/titles only. The absence of
                # richer fields is not a contradictory source value.
                if field != "title" and field not in expected[row["id"]]:
                    continue
                value = row.get(field, "")
                reference = expected[row["id"]].get(field, "")
                if field == "cast":
                    value = [normalized(name) for name in value.split(",")]
                    equal = value == reference
                else:
                    equal = normalized(value) == normalized(reference)
                if not equal:
                    finding("registry_metadata_mismatch", "error", mission_id=row["id"],
                            field=field, paragraph=row.get("field_paragraphs", {}).get(field, row["paragraph"]))
    for mission in source["missions"]:
        groups = {}
        dialogue = mission["dialogue"]
        if not dialogue:
            finding("missing_main_dialogue", "error", mission_id=mission["id"], paragraph=mission["paragraph"])
        if mission["unparsed_dialogue_paragraphs"]:
            finding("unparsed_main_dialogue", "error", mission_id=mission["id"],
                    paragraphs=mission["unparsed_dialogue_paragraphs"])
        line_numbers = [line["number"] for line in dialogue]
        if line_numbers and line_numbers != list(range(1, len(dialogue) + 1)):
            finding("dialogue_number_sequence", "error", mission_id=mission["id"], line_numbers=line_numbers)
        if "time_and_age" not in mission:
            finding("missing_time_and_age", "error", mission_id=mission["id"], paragraph=mission["paragraph"])
        for line in dialogue:
            key = (line["speaker"], normalized(line["text"]))
            groups.setdefault(key, []).append(line)
            dialogue_fingerprints.append(fingerprint("\0".join(key)))
            markers = [name for name, pattern in PRODUCTION_LANGUAGE.items() if pattern.search(line["text"])]
            if markers:
                finding("spoken_production_language", "error", mission_id=mission["id"],
                        paragraph=line["paragraph"], line_number=line["number"], markers=markers)
        for (speaker, text), lines in groups.items():
            if len(lines) > 1:
                finding("repeated_line_within_scene", "review", mission_id=mission["id"],
                        speaker=speaker, text_sha256=fingerprint(text),
                        paragraphs=[line["paragraph"] for line in lines],
                        line_numbers=[line["number"] for line in lines])
        time = TIME_AND_AGE.fullmatch(mission.get("time_and_age", ""))
        if time:
            years = sorted((int(time.group(1)), int(time.group(2) or time.group(1))), reverse=True)
            declared = sorted((int(time.group(3)), int(time.group(4) or time.group(3))))
            expected = [birth_year_bce - year for year in years]
            approximate_age_in_period = declared[0] == declared[1] and expected[0] <= declared[0] <= expected[1]
            if declared != expected and not approximate_age_in_period:
                finding("age_calendar_review", "review", mission_id=mission["id"],
                        paragraph=mission["field_paragraphs"]["time_and_age"],
                        year_bce_range=years, declared_age_range=declared,
                        campaign_age_range=expected)
        mission_reports.append({"id": mission["id"], "paragraph": mission["paragraph"],
                                "dialogue_lines": len(dialogue), "distinct_speaker_lines": len(groups),
                                "repeated_line_instances": len(dialogue) - len(groups)})
    return {"band": source["band"], "file_name": source["file_name"],
            "registry_source_file": band["source_file"], "sha256": source["sha256"],
            "paragraphs": source["paragraphs"], "words": source["words"],
            "main_missions": mission_reports,
            "side_quests": [{"id": row["id"], "paragraph": row["paragraph"]} for row in source["side_quests"]],
            "findings": findings, "_dialogue_fingerprints": dialogue_fingerprints}


def audit(paths: list[Path], campaign_path: Path, require_all_volumes: bool = False) -> dict:
    campaign = json.loads(campaign_path.read_text(encoding="utf-8"))
    if campaign.get("schema_version") != 1:
        raise ValueError("campaign schema_version must be 1")
    bands = {band["band"]: band for band in campaign["bands"]}
    if set(bands) != {1, 2, 3, 4}:
        raise ValueError("campaign must contain volumes 1 through 4")
    rules = campaign["campaign_rules"]
    birth_year_bce = int(rules["start_year_bce"]) + int(rules["start_age"])
    sources = [parse_source(path) for path in paths]
    provided = [source["band"] for source in sources]
    if not provided or len(provided) != len(set(provided)):
        raise ValueError("supply at most one DOCX per volume and at least one volume")
    reports = [audit_source(source, bands[source["band"]], birth_year_bce)
               for source in sorted(sources, key=lambda source: source["band"])]
    distinct_dialogue = set()
    for report in reports:
        distinct_dialogue.update(report.pop("_dialogue_fingerprints"))
    findings = [finding for report in reports for finding in report["findings"]]
    counts = Counter(finding["code"] for finding in findings)
    errors = sum(finding["severity"] == "error" for finding in findings)
    missing = sorted(set(bands) - set(provided))
    if require_all_volumes and missing:
        errors += len(missing)
        counts["missing_required_volume"] = len(missing)
    all_missions = [mission for report in reports for mission in report["main_missions"]]
    return {"schema_version": 1, "auditor_version": 1,
            "campaign_sha256": file_fingerprint(campaign_path),
            "source_coverage": {"audited_bands": sorted(provided), "not_audited_bands": missing,
                                "require_all_volumes": require_all_volumes},
            "scope": {"text": "word/document.xml paragraphs, including table cells; notes, comments and layout excluded",
                      "dialogue": "numbered main-mission dialogue only; side-quest and unnumbered dialogue excluded",
                      "repetition": "identical normalized speaker/text within one mission; editorial review, not an automatic defect",
                      "age": "calendar-year comparison to campaign start; exact birthdays and open-ended dates are not inferred",
                      "privacy": "no dialogue/full-text export; only hashes, IDs, markers and paragraph locations",
                      "historical_accuracy": "not automatically verified"},
            "summary": {"main_missions": len(all_missions),
                        "side_quests": sum(len(report["side_quests"]) for report in reports),
                        "main_dialogue_lines": sum(mission["dialogue_lines"] for mission in all_missions),
                        "distinct_speaker_lines": len(distinct_dialogue),
                        "scenes_with_repeated_lines": sum(mission["repeated_line_instances"] > 0 for mission in all_missions),
                        "within_scene_repeated_line_instances": sum(mission["repeated_line_instances"] for mission in all_missions),
                        "spoken_production_language_lines": counts["spoken_production_language"],
                        "blocking_findings": errors,
                        "findings_by_code": dict(sorted(counts.items()))},
            "automated_status": "needs_revision" if errors else "no_automated_blockers_in_audited_subset",
            "production_clearance": "not_assessed",
            "sources": reports}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("sources", nargs="+", type=Path, help="Local private DOCX source files")
    parser.add_argument("--campaign", type=Path, default=ROOT / "prototype/assets/story/campaign_arc.json")
    parser.add_argument("--report", type=Path, help="Write a text-free JSON audit; stdout still shows the summary")
    parser.add_argument("--require-all-volumes", action="store_true", help="Fail if any of the four volumes is not supplied")
    args = parser.parse_args(argv)
    try:
        report = audit(args.sources, args.campaign, args.require_all_volumes)
        if args.report:
            args.report.parent.mkdir(parents=True, exist_ok=True)
            args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(json.dumps({"automated_status": report["automated_status"],
                          "source_coverage": report["source_coverage"],
                          "summary": report["summary"]} if args.report else report,
                         ensure_ascii=False, indent=2))
        return 1 if report["summary"]["blocking_findings"] else 0
    except (OSError, KeyError, TypeError, ValueError, zipfile.BadZipFile, ET.ParseError) as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
