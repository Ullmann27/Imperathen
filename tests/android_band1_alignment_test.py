"""Static checks for the Band 1 screenplay alignment of the childhood chapter."""

from __future__ import annotations

import json
from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[1]
ARC = ROOT / "prototype/assets/story/campaign_arc.json"
CHILDHOOD = ROOT / "prototype/scripts/story/village_childhood.gd"


class Band1AlignmentTest(unittest.TestCase):
    def setUp(self) -> None:
        self.arc = json.loads(ARC.read_text(encoding="utf-8"))
        self.source = CHILDHOOD.read_text(encoding="utf-8")

    def test_band1_missions_carry_screenplay_metadata(self) -> None:
        missions = self.arc["bands"][0]["main_missions"]
        self.assertEqual(len(missions), 32)
        for mission in missions:
            with self.subTest(mission=mission["id"]):
                self.assertTrue(mission["location"].strip())
                self.assertTrue(mission["cast"] and all(name.strip() for name in mission["cast"]))
                self.assertTrue(mission["story_core"].strip())
                self.assertTrue(mission["source_section"].startswith(
                    f"Band 1 · Abschnitt „{mission['id']} · {mission['title']}“ · Tabelle "))

    def test_other_bands_stay_title_only(self) -> None:
        for band in self.arc["bands"][1:]:
            for mission in band["main_missions"]:
                self.assertEqual(set(mission), {"id", "title"})

    def test_mission_map_names_existing_steps(self) -> None:
        band1 = ROOT / "prototype/assets/story/missions/band1"
        order = json.loads((band1 / "index.json").read_text(encoding="utf-8"))["order"]
        mapped = {}
        for mission in order:
            data = json.loads((band1 / f"{mission}.json").read_text(encoding="utf-8"))
            for step in data["steps"]:
                if "source_mission" in step:
                    mapped[step["id"]] = step["source_mission"]
        self.assertTrue(mapped)
        self.assertEqual(mapped["rest_first"], "I-05")
        self.assertEqual(mapped["deliver_hinge"], "I-06")

if __name__ == "__main__":
    unittest.main()
