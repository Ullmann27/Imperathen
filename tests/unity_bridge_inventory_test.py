"""Unity Asset Manager inventory tests: GET-only and no private metadata."""
import io
from pathlib import Path
import sys
import unittest
from unittest.mock import Mock
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools" / "unity_bridge"))
from inventory_asset_manager import inventory

class FakeResponse:
    def __init__(self, value):
        self.data = value
        self.status = 200
    def __enter__(self):
        return self
    def __exit__(self, *args):
        return False
    def read(self, length):
        return self.data

class FakeOpener:
    def __init__(self, results):
        self.responses = iter(results)
        self.requests = []
    def open(self, request, timeout):
        self.requests.append(request)
        return FakeResponse(next(self.responses))

class InventoryTest(unittest.TestCase):
    def test_exact_imperathen_project_and_assets_count(self):
        opener = FakeOpener([
            b'{"projects":[{"name":"Imperathen","id":"11111111-2222-3333-4444-555555555555"}, {"name":"other","id":"11111111-2222-3333-4444-555555555556"}]}',
            b'{"count":0}'
        ])
        result = inventory("1234567890123", "key", "secret", opener)
        self.assertEqual(result["result"], "ASSET_INVENTORY_CONFIRMED")
        self.assertEqual(result["asset_count"], 0)
        self.assertTrue(result["project_visible"])
        self.assertEqual(len(opener.requests), 2)
        self.assertTrue(all(req.get_method() == "GET" for req in opener.requests))
        self.assertNotIn("11111111", str(result))
        self.assertNotIn("secret", str(result))

    def test_not_visible_stops_before_asset_list(self):
        opener = FakeOpener([b'{"projects":[]}'])
        result = inventory("1234567890123", "key", "secret", opener)
        self.assertEqual(result["result"], "PROJECT_NOT_VISIBLE")
        self.assertEqual(len(opener.requests), 1)
        self.assertNotIn("asset_count", result)

    def test_invalid_project_id_refused(self):
        opener = FakeOpener([b'{"projects":[{"name":"Imperathen","id":"../../other"}]}'])
        self.assertEqual(inventory("1234567890123", "key", "secret", opener)["result"], "INVALID_PROJECT_ID")
        self.assertEqual(len(opener.requests), 1)
