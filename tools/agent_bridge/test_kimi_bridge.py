import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import kimi_bridge as k
import nemotron_bridge as common


class KimiBridgeTests(unittest.TestCase):
    def test_manifest(self):
        manifest = k.load_tasks(Path(k.__file__).with_name("kimi_tasks.json"))
        self.assertEqual(set(manifest), set(k.TASK_IDS))
        self.assertEqual(sum(t["max_tokens"] for t in manifest.values()), 98_304)

    def test_image_allowlist(self):
        self.assertTrue(k.allowed_image("art/cinematic/i00/i00_vexillum_detail.png"))
        self.assertTrue(k.allowed_image("art/frontier_people/runtime_review/legionary-face.png"))
        for path in ("../art/review/x.png", "art/review/../x.png", "art/source/review/a.png",
                     "art/review/.key.png", ".github/review/x.png", "art/review/a.glb",
                     "https://example.com/art/review/x.png"):
            self.assertFalse(k.allowed_image(path), path)

    def test_image_is_pinned_and_encoded(self):
        task = {"revision": "a" * 40, "images": ["art/review/x.png"]}
        data = b"\x89PNG\r\n\x1a\n" + b"fake"
        class FakeOpener:
            def open(self, request, timeout):
                self.url = request.full_url
                return io.BytesIO(data)
        opener = FakeOpener()
        parts, hashes = k.collect_images(task, opener)
        self.assertIn("a" * 40, opener.url)
        self.assertTrue(parts[1]["image_url"]["url"].startswith("data:image/png;base64,"))
        self.assertEqual(len(hashes["art/review/x.png"]), 64)

    def test_reject_lfs_pointer(self):
        class FakeOpener:
            def open(self, request, timeout):
                return io.BytesIO(b"version https://git-lfs.github.com/spec/v1")
        with self.assertRaises(common.BridgeError):
            k.collect_images({"revision": "a" * 40, "images": ["art/review/x.png"]}, FakeOpener())

    def test_payload(self):
        parts = [{"type": "image_url", "image_url": {"url": "data:image/png;base64,AAAA"}}]
        payload = k.build_payload("task", parts, 16384)
        self.assertEqual(payload["model"], "moonshotai/kimi-k3.1-pro")
        self.assertEqual(payload["reasoning_effort"], "max")
        self.assertTrue(payload["stream"])
        self.assertEqual(payload["messages"][1]["content"][1], parts[0])
        self.assertNotIn("api_key", payload)

    def test_json_response(self):
        raw = json.dumps({"id": "test", "model": k.MODEL, "choices": [{
            "message": {"content": "patch", "reasoning_content": "not output"},
            "finish_reason": "stop"}]}).encode()
        answer, meta = k.parse_json(raw)
        self.assertEqual(answer, "patch")
        self.assertTrue(meta["complete"])
        self.assertNotIn("reasoning_content", meta)

    def test_incomplete_json(self):
        answer, meta = k.parse_json(b'{"choices":[{"message":{"content":"partial"},"finish_reason":"length"}]}')
        self.assertEqual(answer, "partial")
        self.assertFalse(meta["complete"])
        for raw in (b'{}', b'{"error":"unavailable"}', b'{"choices":[{"message":{"content":""},"finish_reason":"stop"}]}'):
            with self.assertRaises(common.BridgeError):
                k.parse_json(raw)


class AdaptiveTransportTests(unittest.TestCase):
    def test_adaptive_manifest_and_effort(self):
        manifest = k.load_tasks(Path(k.__file__).with_name("kimi_tasks.json"))
        task = dict(manifest["K01"], max_tokens=4096, reasoning_effort="high")
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / "manifest.json"
            path.write_text(json.dumps({"K07": task}), encoding="utf-8")
            self.assertEqual(list(k.load_tasks(path)), ["K07"])
            path.write_text(json.dumps({"invalid": task}), encoding="utf-8")
            with self.assertRaises(common.BridgeError):
                k.load_tasks(path)
            task["reasoning_effort"] = "invalid"
            with self.assertRaises(common.BridgeError):
                k.validate_task(task)
        self.assertEqual(k.build_payload("task", [], 4096, "high")["reasoning_effort"], "high")

    def test_failure_diagnostics_are_redacted(self):
        self.assertEqual(k.failure_kind(common.BridgeError("NVIDIA response deadline exceeded")), "response_deadline")
        self.assertEqual(k.failure_kind(common.BridgeError("API result pending (202)")), "pending_202")
        self.assertEqual(k.failure_kind(TimeoutError("secret")), "socket_timeout")
        self.assertEqual(k.failure_kind(common.BridgeError("untrusted provider text")), "bridge_validation")

    def test_pending_response_is_not_retried(self):
        class Pending:
            status = 202
            headers = {}
            def __enter__(self):
                return self
            def __exit__(self, *args):
                return False
        class Opener:
            calls = 0
            def open(self, request, timeout):
                self.calls += 1
                return Pending()
        opener = Opener()
        with self.assertRaisesRegex(common.BridgeError, "pending"):
            k.consult("task", [], 4096, "test-key", opener, "high")
        self.assertEqual(opener.calls, 1)


if __name__ == "__main__":
    unittest.main()
