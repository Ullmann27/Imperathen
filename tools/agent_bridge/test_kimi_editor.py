import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import kimi_editor as e
import nemotron_bridge as common


class EditorTests(unittest.TestCase):
    def setUp(self):
        self.path = "prototype/scripts/world/village/demo.gd"
        self.new = "prototype/tests/demo_test.gd"
        self.workspace = e.Workspace({self.path: "extends Node\nvar light = 1.0\n"}, [self.new])

    def test_edit_and_create(self):
        self.workspace.perform("replace_text", {"path": self.path, "old": "light = 1.0", "new": "light = 2.0"})
        self.workspace.perform("create_file", {"path": self.new, "content": "extends Node\n"})
        changes, diff = self.workspace.candidate()
        self.assertEqual(len(changes), 2)
        edit = next(c for c in changes if c["path"] == self.path)
        self.assertEqual(edit["before_sha256"], e.digest("extends Node\nvar light = 1.0\n"))
        self.assertIn("+var light = 2.0", diff)
        self.assertIn(self.new, diff)
        self.assertEqual(self.workspace.originals[self.path], "extends Node\nvar light = 1.0\n")

    def test_read_and_scope(self):
        result = self.workspace.perform("read_file", {"path": self.path, "start": 2, "end": 2})
        self.assertEqual(result["content"], "var light = 1.0\n")
        for path in (".github/workflows/test.yml", "prototype/scripts/world/other.gd", "../secret.gd"):
            with self.assertRaises(common.BridgeError):
                self.workspace.perform("create_file", {"path": path, "content": "test\n"})

    def test_ambiguous_and_invalid_edits(self):
        for old in ("", "missing", " "):
            with self.assertRaises(common.BridgeError):
                self.workspace.perform("replace_text", {"path": self.path, "old": old, "new": "x"})
        with self.assertRaises(common.BridgeError):
            self.workspace.perform("read_file", {"path": self.path, "start": 1, "end": 201})
        with self.assertRaises(common.BridgeError):
            self.workspace.perform("shell", {"command": "echo x"})

    def test_fake_agent_tool_loop(self):
        task = {"revision": "a"*40, "task": "Improve light", "files": [self.path],
                "images": ["art/review/x.png"], "new_files": [self.new]}
        def call(name, args, index):
            return {"id": str(index), "type": "function", "function": {"name": name, "arguments": json.dumps(args)}}
        responses = [
            ({"content": None, "tool_calls": [call("read_file", {"path": self.path, "start": 1, "end": 2}, 1)]}, "tool_calls"),
            ({"content": None, "tool_calls": [call("replace_text", {"path": self.path, "old": "light = 1.0", "new": "light = 2.0"}, 2)]}, "tool_calls"),
            ({"content": "Candidate ready"}, "stop"),
        ]
        with patch.object(e, "load_sources", return_value=self.workspace.originals), patch.object(e.visual, "collect_images", return_value=([], {})), patch.object(e, "request_model", side_effect=responses):
            changes, diff, final, _, count = e.edit(task, "fake-key", None)
        self.assertEqual(count, 2)
        self.assertEqual(len(changes), 1)
        self.assertIn("light = 2.0", diff)
        self.assertEqual(final, "Candidate ready")

    def test_no_edits_is_failure(self):
        task = {"revision": "a"*40, "task": "Improve light", "files": [self.path],
                "images": ["art/review/x.png"], "new_files": []}
        with patch.object(e, "load_sources", return_value=self.workspace.originals), patch.object(e.visual, "collect_images", return_value=([], {})), patch.object(e, "request_model", return_value=({"content": "Only advice"}, "stop")):
            with self.assertRaises(common.BridgeError):
                e.edit(task, "fake-key", None)


if __name__ == "__main__":
    unittest.main()
