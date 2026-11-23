from __future__ import annotations

import importlib.util
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "validate_campaign_arc",
    ROOT / "tools/story/validate_campaign_arc.py",
)
VALIDATOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VALIDATOR)


class CampaignBibleContractTest(unittest.TestCase):
    def test_four_volume_registry_matches_authored_counts_and_cast(self):
        report = VALIDATOR.validate(ROOT / "prototype/assets/story/campaign_arc.json")
        self.assertEqual(report["bands"], 4)
        self.assertEqual(report["main_missions"], 113)
        self.assertEqual(report["side_quests"], 96)
        self.assertEqual(report["canonical_cast"], 7)
        self.assertEqual(report["start_year_bce"], 58)
        self.assertEqual(report["start_age"], 12)


if __name__ == "__main__":
    unittest.main()
