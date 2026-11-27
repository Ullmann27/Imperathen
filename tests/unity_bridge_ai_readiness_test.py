"""Offline tests for Unity AI diagnostics: read-only, no generation calls or leaks."""
from pathlib import Path
import sys
import unittest
from unittest.mock import patch
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools" / "unity_bridge"))
import probe_ai_readiness as probe

class ProbeAiReadinessTest(unittest.TestCase):
    def test_sanitized_topics_do_not_echo_secret_or_values(self):
        message = "Subscription seat inactive, organization login required. SECRET=highly_sensitive"
        topics = probe.indicators(message)
        self.assertIn("subscription_or_seat", topics)
        self.assertIn("sign_in", topics)
        self.assertIn("organization", topics)
        self.assertNotIn("highly_sensitive", str(topics))

    def test_report_never_grants_generation_authorization(self):
        commands = []
        def fake_run(unity, *args):
            commands.append(args)
            if args[:2] == ("cloud", "org"):
                return (3, "Login required")
            if args == ("ai", "help"):
                return (0, "models -- 3D, rigging")
            if args == ("ai", "doctor"):
                return (3, "Unity AI subscription seat and terms of service required: PRIVATE")
            if args == ("ai", "consent", "show"):
                return (3, "No consent")
            raise AssertionError(args)
        with patch.object(probe, "run", side_effect=fake_run):
            report = probe.inspect("unity", "1234567890123")
        self.assertFalse(report["doctor_passed"])
        self.assertFalse(report["production_authorized"])
        self.assertFalse(report["new_generation_started"])
        self.assertEqual(report["credits_spent_by_probe"], 0)
        self.assertEqual(report["doctor_result"], "REQUIRES_SETUP")
        self.assertNotIn("PRIVATE", str(report))
        self.assertEqual(commands[-1], ("ai", "consent", "show"))
        self.assertNotIn("generate", str(commands))

    def test_no_org_selection_for_invalid_id(self):
        def fake_run(unity, *args):
            self.assertNotEqual(args[:2], ("cloud", "org"))
            return (3, "")
        with patch.object(probe, "run", side_effect=fake_run):
            report = probe.inspect("unity", "hello-world")
        self.assertEqual(report["ephemeral_org_selection"], "ORG_GENESIS_ID_NOT_CONFIRMED")
