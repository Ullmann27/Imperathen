import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BAND1 = ROOT / "prototype/assets/story/missions/band1"
ARC = ROOT / "prototype/assets/story/campaign_arc.json"


class MissionDataTest(unittest.TestCase):
    def setUp(self):
        self.index = json.loads((BAND1 / "index.json").read_text(encoding="utf-8"))
        self.arc = {m["id"]: m for m in json.loads(ARC.read_text(encoding="utf-8"))["bands"][0]["main_missions"]}

    def files(self):
        return [json.loads((BAND1 / f"{mission}.json").read_text(encoding="utf-8")) for mission in self.index["order"]]

    def test_index_lists_one_file_per_mission_in_screenplay_order(self):
        order = self.index["order"]
        self.assertEqual(order, sorted(order))
        self.assertEqual(len(order), len(set(order)))
        listed = {path.stem for path in BAND1.glob("I-*.json")}
        self.assertEqual(listed, set(order))

    def test_files_are_versioned_and_cite_band1(self):
        for data in self.files():
            self.assertEqual(data["schema_version"], 1)
            self.assertEqual(data["title"], self.arc[data["mission"]]["title"])
            self.assertEqual(data["source_section"], self.arc[data["mission"]]["source_section"])

    def test_step_ids_are_unique_and_source_missions_match_files(self):
        ids = []
        for data in self.files():
            for step in data["steps"]:
                ids.append(step["id"])
                self.assertIn(step.get("source_mission", data["mission"]), (data["mission"],))
                for key in ("id", "chapter", "label", "objective", "text", "result"):
                    self.assertIn(key, step)
        self.assertEqual(len(ids), len(set(ids)))
        # Save-relevant prefix: these indices are stored in childhood.completed.
        self.assertEqual(ids[:3], ["mother_morning", "fill_water", "father_morning"])
        self.assertEqual(ids[-2:], ["family_evening", "night_rest"])


if __name__ == "__main__":
    unittest.main()
