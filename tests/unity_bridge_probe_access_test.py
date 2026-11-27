"""Offline regression: Unity Cloud diagnostics never echo raw credential-bearing data."""
import sys
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools" / "unity_bridge"))
from probe_access import _status_class, _find_named_project

class UnityReadOnlyDiagnosticTest(unittest.TestCase):
    def test_classifies_without_echoing_credentials(self):
        self.assertEqual(_status_class("", "HTTP 403: secret=dont_print", 6), "HTTP_403")
        self.assertEqual(_status_class("", "Choose an organization", 6), "ORGANIZATION_REQUIRED")
        self.assertEqual(_status_class("", "Please sign in", 3), "AUTH_REQUIRED")
        self.assertEqual(_status_class("", "Invalid command", 2), "CLI_ARGUMENT_ERROR")
        self.assertEqual(_status_class("", "", 6), "UNKNOWN_FAILURE")
        self.assertEqual(_status_class("", "", 0), "COMMAND_SUCCEEDED")

    def test_only_exact_project_name_is_accepted(self):
        sample = {"success": True, "data": [{"name": "Imperathen"}, {"name": "Other"}]}
        self.assertTrue(_find_named_project(sample, "Imperathen"))
        self.assertFalse(_find_named_project({"data": [{"name": "Imperathen-copy"}]}, "Imperathen"))
        self.assertFalse(_find_named_project({"success": True}, "Imperathen"))
