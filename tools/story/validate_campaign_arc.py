#!/usr/bin/env python3
"""Validate the source-derived IMPERATHEN four-volume campaign registry."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import sys


EXPECTED_MAIN = {1: 32, 2: 25, 3: 25, 4: 31}
EXPECTED_SIDE = {1: 24, 2: 24, 3: 24, 4: 24}
EXPECTED_PREFIX = {1: "I", 2: "II", 3: "III", 4: "IV"}
EXPECTED_CAST = {
    "mother": ("julia", "Julia"),
    "father": ("silvanus", "Silvanus"),
    "smith_mentor": ("sextus", "Sextus"),
    "friend": ("marcus", "Marcus"),
    "merchant": ("cassia", "Cassia"),
    "healer": ("aurelia", "Aurelia"),
    "steward": ("decimus", "Decimus"),
}


def fail(message: str) -> None:
    raise ValueError(message)


def validate(path: Path) -> dict:
    data = json.loads(path.read_text(encoding="utf-8"))
    if data.get("schema_version") != 1:
        fail("schema_version must be 1")
    if data.get("project") != "IMPERATHEN — RISE OF AN EMPIRE":
        fail("unexpected project title")

    cast = data.get("canonical_childhood_cast")
    if not isinstance(cast, dict):
        fail("canonical_childhood_cast missing")
    for role, (actor_id, name) in EXPECTED_CAST.items():
        row = cast.get(role)
        if not isinstance(row, dict) or row.get("actor_id") != actor_id or row.get("name") != name:
            fail(f"canonical cast mismatch for {role}")

    rules = data.get("campaign_rules")
    if not isinstance(rules, dict):
        fail("campaign_rules missing")
    if rules.get("start_year_bce") != 58 or rules.get("start_age") != 12:
        fail("campaign must start in 58 BCE at age 12")
    if rules.get("save_driven_cinematics") is not True:
        fail("save-driven cinematics rule missing")

    bands = data.get("bands")
    if not isinstance(bands, list) or len(bands) != 4:
        fail("exactly four bands required")

    mission_ids: set[str] = set()
    side_ids: set[str] = set()
    main_total = 0
    side_total = 0
    for expected_band, band in enumerate(bands, 1):
        if not isinstance(band, dict) or band.get("band") != expected_band:
            fail(f"band {expected_band} missing or out of order")
        prefix = EXPECTED_PREFIX[expected_band]
        if band.get("roman") != prefix:
            fail(f"band {expected_band}: roman prefix mismatch")
        main = band.get("main_missions")
        side = band.get("side_quests")
        if not isinstance(main, list) or len(main) != EXPECTED_MAIN[expected_band]:
            fail(f"band {expected_band}: main mission count mismatch")
        if not isinstance(side, list) or len(side) != EXPECTED_SIDE[expected_band]:
            fail(f"band {expected_band}: side quest count mismatch")
        for index, row in enumerate(main):
            if not isinstance(row, dict):
                fail(f"band {expected_band}: malformed main mission")
            mission_id = row.get("id")
            title = row.get("title")
            expected_id = f"{prefix}-{index:02d}"
            if mission_id != expected_id or not isinstance(title, str) or not title.strip():
                fail(f"band {expected_band}: expected {expected_id}")
            if mission_id in mission_ids:
                fail(f"duplicate mission id {mission_id}")
            mission_ids.add(mission_id)
        for index, row in enumerate(side, 1):
            if not isinstance(row, dict):
                fail(f"band {expected_band}: malformed side quest")
            quest_id = row.get("id")
            title = row.get("title")
            expected_id = f"NQ-{expected_band}-{index:02d}"
            if quest_id != expected_id or not isinstance(title, str) or not title.strip():
                fail(f"band {expected_band}: expected {expected_id}")
            if quest_id in side_ids:
                fail(f"duplicate side quest id {quest_id}")
            side_ids.add(quest_id)
        source_file = band.get("source_file")
        if not isinstance(source_file, str) or not source_file.endswith(".docx"):
            fail(f"band {expected_band}: source_file missing")
        main_total += len(main)
        side_total += len(side)

    if main_total != 113 or side_total != 96:
        fail("four-volume totals must be 113 main missions and 96 side quests")
    if "I-10" not in mission_ids or "I-14" not in mission_ids or "IV-30" not in mission_ids:
        fail("required campaign anchors missing")
    return {
        "bands": len(bands),
        "main_missions": main_total,
        "side_quests": side_total,
        "canonical_cast": len(EXPECTED_CAST),
        "start_year_bce": rules["start_year_bce"],
        "start_age": rules["start_age"],
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "path",
        nargs="?",
        type=Path,
        default=Path("prototype/assets/story/campaign_arc.json"),
    )
    args = parser.parse_args()
    try:
        report = validate(args.path)
    except (OSError, json.JSONDecodeError, ValueError) as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return 1
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
