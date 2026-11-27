"""Static contract tests for AI asset queue and absence of false production claims."""
import copy
import json
from pathlib import Path
import sys
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools" / "unity_bridge"))
from validate_production_queue import validate

FILE = Path(__file__).resolve().parents[1] / "tools" / "unity_bridge" / "production_queue.json"

class UnityQueueTests(unittest.TestCase):
    def setUp(self):
        self.catalog = json.loads(FILE.read_text(encoding="utf-8"))

    def test_correct_detailed_design_queue_but_no_false_asset_claims(self):
        result = validate(self.catalog)
        self.assertGreaterEqual(result["planned_assets"], 12)
        self.assertEqual(result["already_generated_in_this_queue"], 0)
        self.assertEqual(result["source_imported"], 0)

    def test_never_generate_without_user_cost_approval(self):
        catalog = copy.deepcopy(self.catalog)
        catalog["generate_without_user_credit_approval"] = True
        with self.assertRaisesRegex(ValueError, "unsafe_cost"):
            validate(catalog)

    def test_no_game_release_by_implicit_approval(self):
        catalog = copy.deepcopy(self.catalog)
        catalog["assets"][0]["fold7_accepted"] = True
        with self.assertRaisesRegex(ValueError, "must_not_claim_ready"):
            validate(catalog)

    def test_rejects_bad_asset_paths_and_duplicate_ids(self):
        catalog = copy.deepcopy(self.catalog)
        catalog["assets"][0]["destination"] = "../other.glb"
        with self.assertRaisesRegex(ValueError, "destination_mismatch"):
            validate(catalog)
        catalog = copy.deepcopy(self.catalog)
        catalog["assets"][1]["id"] = catalog["assets"][0]["id"]
        with self.assertRaisesRegex(ValueError, "duplicate_or_unsafe_id"):
            validate(catalog)
