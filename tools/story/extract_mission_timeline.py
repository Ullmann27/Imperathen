#!/usr/bin/env python3
"""Extract the 113 mission dates, ages, places and canon kinds from the Masterhandbuch.

Source: "IMPERATHEN - Operation Aeterna 3.0 | Masterhandbuch" (311 pages). The
mission sheets of production version 2.0 are reproduced on PDF pages 125-237
(PDF page = version-2.0 page + 58); section G (PDF pages 49-56) is the
continuity register that cites every sheet as "S. NNN".

The script only reads. It never repairs a value: every sheet header is parsed
literally and mismatches abort the run. Findings are evaluated at runtime by
prototype/scripts/domain/campaign_timeline.gd.

Usage:
  python3 tools/story/extract_mission_timeline.py --pdf HANDBOOK.pdf \
      --output prototype/assets/story/mission_timeline.json
  python3 tools/story/extract_mission_timeline.py --pdf HANDBOOK.pdf --check
Requires pdftotext (poppler-utils).
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_OUTPUT = ROOT / "prototype/assets/story/mission_timeline.json"
PAGE_OFFSET = 58
SHEET_PAGES = range(125, 238)
REGISTER_PAGES = range(49, 57)
BANDS = {"I": 1, "II": 2, "III": 3, "IV": 4}
MONTHS = {"Januar": 1, "Februar": 2, "März": 3, "April": 4, "Mai": 5, "Juni": 6, "Juli": 7,
          "August": 8, "September": 9, "Oktober": 10, "November": 11, "Dezember": 12}
SHEET_HEADER = re.compile(r"VI / HAUPTMISSION · BAND (I|II|III|IV) / ((I|II|III|IV)-(\d{2}))")
FOOTER = re.compile(r"(?:Spezifikation|Produktionsvorgaben), keine Freigabebehauptung\s+(\d{3})\s*$")
REGISTER_LINE = re.compile(r"^\s*((?:I|II|III|IV)-\d{2}) · S\. (\d{3})\s+(.*)$")
OWNER_BANDS = [
    {"band": 1, "roman": "I", "from": -58, "to": -52, "sandbox_after": False},
    {"band": 2, "roman": "II", "from": -51, "to": -47, "sandbox_after": False},
    {"band": 3, "roman": "III", "from": -47, "to": -44, "sandbox_after": False},
    {"band": 4, "roman": "IV", "from": -44, "to": -27, "sandbox_after": True},
]


def page_text(pdf: Path, page: int) -> list[str]:
    result = subprocess.run(["pdftotext", "-f", str(page), "-l", str(page), "-layout", str(pdf), "-"],
                            check=True, capture_output=True, text=True, encoding="utf-8")
    return result.stdout.replace("\f", "").split("\n")


def parse_date(text: str) -> dict:
    """Literal parse of the sheet date field into historical signed years (no year 0)."""
    patterns = [
        (r"^(\d{1,2})\. (\w+) (\d+) v\. Chr\.$", "exact_date"),
        (r"^(\d+) v\. Chr\.$", "exact_year"),
        (r"^(\d+)/(\d+) v\. Chr\.$", "split_year"),
        (r"^(\d+)–(\d+) v\. Chr\.$", "year_range"),
        (r"^(\d+) v\. Chr\. und danach$", "open_after"),
        (r"^ab (\d+) v\. Chr\.$", "from_year"),
        (r"^alternativ$", "alternative"),
        (r"^Epilog$", "epilogue"),
    ]
    for pattern, kind in patterns:
        match = re.match(pattern, text)
        if not match:
            continue
        values = match.groups()
        if kind == "exact_date":
            year = -int(values[2])
            return {"date_kind": kind, "year_from": year, "year_to": year,
                    "date": {"year": year, "month": MONTHS[values[1]], "day": int(values[0])}}
        if kind == "exact_year":
            return {"date_kind": kind, "year_from": -int(values[0]), "year_to": -int(values[0]), "date": None}
        if kind in ("split_year", "year_range"):
            return {"date_kind": kind, "year_from": -int(values[0]), "year_to": -int(values[1]), "date": None}
        if kind in ("open_after", "from_year"):
            return {"date_kind": kind, "year_from": -int(values[0]), "year_to": None, "date": None}
        return {"date_kind": kind, "year_from": None, "year_to": None, "date": None}
    raise ValueError(f"unparsed date field: {text!r}")


def parse_age(text: str) -> dict:
    match = re.match(r"^Spieler ca\. (\d+)$", text)
    if match:
        return {"age_min": int(match[1]), "age_max": int(match[1]), "age_open": False, "age_variable": False}
    match = re.match(r"^Spieler ca\. (\d+)–(\d+)$", text)
    if match:
        return {"age_min": int(match[1]), "age_max": int(match[2]), "age_open": False, "age_variable": False}
    match = re.match(r"^Spieler ca\. (\d+)\+$", text)
    if match:
        return {"age_min": int(match[1]), "age_max": None, "age_open": True, "age_variable": False}
    if text == "Spieler ca. variabel":
        return {"age_min": None, "age_max": None, "age_open": False, "age_variable": True}
    raise ValueError(f"unparsed age field: {text!r}")


def read_sheets(pdf: Path) -> list[dict]:
    sheets = []
    for page in SHEET_PAGES:
        lines = page_text(pdf, page)
        header = next(((i, m) for i, line in enumerate(lines) if (m := SHEET_HEADER.search(line))), None)
        if header is None:
            raise ValueError(f"PDF page {page}: no mission sheet header")
        index, match = header
        band_roman, mission_id = match[1], match[2]
        footer = [int(m[1]) for line in lines if (m := FOOTER.search(line))]
        if len(footer) != 1 or footer[0] + PAGE_OFFSET != page:
            raise ValueError(f"PDF page {page}: footer page {footer} does not match offset {PAGE_OFFSET}")
        title_lines, field_line = [], None
        for line in lines[index + 1:]:
            text = line.strip()
            if not text:
                continue
            if " · Spieler " in text and text.count("|") == 2:
                field_line = text
                break
            title_lines.append(text)
            if len(title_lines) > 3:
                raise ValueError(f"PDF page {page}: title not terminated")
        title = " ".join(title_lines)
        if field_line is None or not title.startswith(mission_id + " · "):
            raise ValueError(f"PDF page {page}: unreadable header for {mission_id}")
        when_age, place, canon_kind = [part.strip() for part in field_line.split("|")]
        date_text, age_text = [part.strip() for part in when_age.split(" · ", 1)]
        record = {"id": mission_id, "band": BANDS[band_roman], "band_roman": band_roman,
                  "number": int(match[4]), "title": title[len(mission_id) + 3:],
                  "date_text": date_text}
        record.update(parse_date(date_text))
        record["age_text"] = age_text.replace("Spieler ", "")
        record.update(parse_age(age_text))
        record.update({"place": place, "canon_kind": canon_kind, "pdf_page": page,
                       "sheet_page": footer[0]})
        sheets.append(record)
    return sheets


def read_register(pdf: Path) -> dict[str, dict]:
    register: dict[str, dict] = {}
    for page in REGISTER_PAGES:
        last = None
        for line in page_text(pdf, page):
            match = REGISTER_LINE.match(line)
            if match:
                if match[1] in register:
                    raise ValueError(f"register lists {match[1]} twice")
                last = match[1]
                register[last] = {"register_ref": f"S. {match[2]}", "register_page": int(match[2]),
                                  "register_pdf_page": page, "continuity": match[3].strip()}
            elif last and line.startswith(" " * 20) and line.strip() and not line.strip().startswith("QA pro Zeile"):
                register[last]["continuity"] += " " + line.strip()
            elif not line.strip():
                last = None
    return register


def build(pdf: Path) -> dict:
    sheets = read_sheets(pdf)
    register = read_register(pdf)
    if sorted(register) != sorted(s["id"] for s in sheets) or len(sheets) != 113:
        raise ValueError("sheet and register mission IDs differ")
    missions = []
    for sheet in sheets:
        entry = register[sheet["id"]]
        if entry["register_page"] != sheet["sheet_page"]:
            raise ValueError(f"{sheet['id']}: register cites {entry['register_ref']}, sheet is on {sheet['sheet_page']}")
        record = dict(sheet)
        record.update({"register_ref": entry["register_ref"], "register_pdf_page": entry["register_pdf_page"],
                       "continuity": entry["continuity"]})
        missions.append(record)
    return {
        "format": "imperathen-mission-timeline",
        "schema": 1,
        "year_convention": "historical_signed: -58 = 58 v. Chr., -1 = 1 v. Chr., 1 = 1 n. Chr.; 0 is invalid (no year zero)",
        "source": {
            "document": "IMPERATHEN – Operation Aeterna 3.0 | Masterhandbuch (311 Seiten)",
            "sheets": "Missionsblätter der Produktionsfassung 2.0, PDF-Seiten 125–237; PDF-Seite = Blattseite + 58",
            "register": "Abschnitt G · Missionskontinuität, PDF-Seiten 49–56 (S.-Verweise auf Fassung 2.0)",
            "extraction": "tools/story/extract_mission_timeline.py (pdftotext -layout); Werte wörtlich, nichts korrigiert",
        },
        "page_offset": PAGE_OFFSET,
        "band_ranges": OWNER_BANDS,
        "band_ranges_source": "docs/00_governance/GAME_DIRECTION_2026-11-26_B.md, Nr. 6 (D-028)",
        "protagonist": {"start_year": -58, "start_age": 12,
                        "source": "GAME_DIRECTION_2026-11-26.md Nr. 1 (D-015); Blatt I-01, PDF S. 126"},
        "protected_story_events": [{"id": "I-10", "source": "GAME_DIRECTION_2026-11-26.md Nr. 6 (D-020)"}],
        "missions": missions,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    parser.add_argument("--pdf", type=Path, required=True)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--check", action="store_true", help="Compare the extraction with --output instead of writing.")
    args = parser.parse_args()
    data = build(args.pdf)
    existing = json.loads(args.output.read_text(encoding="utf-8")) if args.output.exists() else None
    if existing is not None:
        # Hand-reviewed notes and acknowledged findings are kept verbatim.
        for key in ("review_notes", "acknowledged_findings"):
            if key in existing:
                data[key] = existing[key]
    text = json.dumps(data, ensure_ascii=False, indent=2) + "\n"
    if args.check:
        if existing is None or json.dumps(existing, ensure_ascii=False, indent=2) + "\n" != text:
            print("mission timeline differs from the handbook extraction", file=sys.stderr)
            return 1
        print(f"mission timeline matches the handbook: {len(data['missions'])} missions")
        return 0
    args.output.write_text(text, encoding="utf-8")
    print(f"wrote {len(data['missions'])} missions to {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
