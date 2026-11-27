import json
from pathlib import Path
import tempfile
import unittest
from plan_batch import load_batch

class BatchTests(unittest.TestCase):
    def make_request(self, root, name, tokens=16384):
        path = root / ("request.json" if name == "single" else f"requests/{name}.json")
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps({"revision": "a"*40, "task": "Review", "files": ["prototype/project.godot"], "max_tokens": tokens}), encoding="utf-8")

    def manifest(self, root, names):
        (root / "batch.json").write_text(json.dumps({"requests": names}), encoding="utf-8")

    def test_single_and_named(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            self.manifest(root, ["single", "render"])
            self.make_request(root, "single")
            self.make_request(root, "render")
            self.assertEqual(load_batch(root)["include"], [
                {"task": "single", "request_path": "tools/agent_bridge/request.json"},
                {"task": "render", "request_path": "tools/agent_bridge/requests/render.json"}])

    def test_reject_invalid_names(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            for names in (["../secret"], ["a", "a"], [], ["a"]*9):
                self.manifest(root, names)
                with self.assertRaises(ValueError):
                    load_batch(root)

    def test_reject_excess_tokens(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            names = [f"task-{i}" for i in range(8)]
            self.manifest(root, names)
            for name in names:
                self.make_request(root, name)
            with self.assertRaises(ValueError):
                load_batch(root)

    def test_repo_batch_contract(self):
        root = Path(__file__).resolve().parent
        matrix = load_batch(root)
        self.assertTrue(matrix["include"])

if __name__ == "__main__":
    unittest.main()
