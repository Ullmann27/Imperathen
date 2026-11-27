import importlib.util
import json
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools/art"))
import recover_meshy_sources as recovery

class MeshyRecoveryTest(unittest.TestCase):
    def test_existing_tasks_only_and_no_duplicate_families(self):
        rows = json.loads(recovery.AUDIT.read_text())["rows"]
        selected = recovery.candidates(rows)
        self.assertGreaterEqual(len(selected), 15)
        self.assertEqual(len(selected), len({r["stable_id"] for r in selected}))
        self.assertTrue(all(r["source_sha256"] and r["source_bytes"] for r in selected))
        self.assertTrue(all(r["state"] == "needs_source_or_derivative_review" for r in selected))
        caesar = next(r for r in selected if r["stable_id"] == "historical_caesar_image")
        self.assertTrue(caesar["textured"])
        self.assertNotIn("PRIVATE_YOUTH_NOT_TOUCHED", [r["stable_id"] for r in selected])

if __name__ == "__main__":
    unittest.main()
