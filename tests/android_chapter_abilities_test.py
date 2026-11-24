import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "prototype/assets/story/chapter1_abilities.json"
ARC = ROOT / "prototype/assets/story/campaign_arc.json"
CHILDHOOD = ROOT / "prototype/scripts/story/village_childhood.gd"
STABLE_IDS = ["ch1_look_before_force", "ch1_price_is_promise", "ch1_read_tracks"]


class ChapterAbilitiesCatalogTest(unittest.TestCase):
    def setUp(self):
        self.catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
        self.arc = json.loads(ARC.read_text(encoding="utf-8"))

    def test_ids_are_stable_and_unique(self):
        ids = [item["id"] for item in self.catalog["abilities"]]
        self.assertEqual(ids, STABLE_IDS)
        self.assertEqual(self.catalog["save_key"], "village.abilities")

    def test_every_ability_cites_band1_and_marks_additions(self):
        titles = {m["id"]: m["title"] for m in self.arc["bands"][0]["main_missions"]}
        for item in self.catalog["abilities"]:
            self.assertIn(item["mission"], titles)
            self.assertTrue(item["source"].startswith(f"Band 1 · Abschnitt „{item['mission']} · {titles[item['mission']]}“ · Tabelle"))
            self.assertTrue(item["effect_status"].startswith("Ergänzung"))
            self.assertIn(item["effect"]["type"], {"block_window_bonus_seconds", "emergency_food_discount_denarii", "scout_insight_bonus"})

    def test_granting_steps_exist_in_childhood_flow(self):
        band1 = ROOT / "prototype/assets/story/missions/band1"
        steps = {}
        for mission in json.loads((band1 / "index.json").read_text(encoding="utf-8"))["order"]:
            for step in json.loads((band1 / f"{mission}.json").read_text(encoding="utf-8"))["steps"]:
                steps[step["id"]] = step.get("source_mission")
        source = CHILDHOOD.read_text(encoding="utf-8")
        for item in self.catalog["abilities"]:
            grant = item["grant"]
            if "completed" in grant:
                self.assertEqual(steps.get(grant["completed"]), item["mission"])
            else:
                self.assertIn('"%s":false' % grant["screenplay_flag"], source)

    def test_catalog_is_required_in_the_apk(self):
        validator = (ROOT / "tools/validate_android_apk.py").read_text(encoding="utf-8")
        self.assertIn('("chapter_story_content", CHAPTER_STORY_RESOURCES)', validator)
        self.assertIn('"assets/story/chapter1_abilities.json"', validator)

if __name__ == "__main__":
    unittest.main()
