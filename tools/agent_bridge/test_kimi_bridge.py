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
        self.assertTrue(1 <= len(manifest) <= k.MAX_TASKS)
        self.assertTrue(all(k.TASK_ID.fullmatch(name) for name in manifest))
        self.assertLessEqual(sum(t["max_tokens"] for t in manifest.values()), 98_304)
        for task in manifest.values():
            k.validate_task(task)

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
        task = dict(next(iter(manifest.values())), max_tokens=4096, reasoning_effort="high")
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
        self.assertEqual(k.failure_kind(common.BridgeError("API result pending (202)")), "pending_202_no_id")
        self.assertEqual(k.failure_kind(TimeoutError("secret")), "socket_timeout")
        self.assertEqual(k.failure_kind(common.BridgeError("untrusted provider text")), "bridge_validation")

    def test_pending_response_is_not_retried(self):
        class Pending(io.BytesIO):
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


class MaxEffortStageTests(unittest.TestCase):
    def test_text_only_json_max(self):
        manifest = k.load_tasks(Path(k.__file__).with_name("kimi_recovery_tasks.json"))
        first = manifest["K101"]
        self.assertEqual(first["reasoning_effort"], "max")
        self.assertEqual(first["images"], [])
        self.assertEqual(first["response_mode"], "json")
        payload = k.build_payload("bounded task", [], 16384, "max", "json")
        self.assertFalse(payload["stream"])
        self.assertNotIn("stream_options", payload)
        self.assertEqual(payload["reasoning_effort"], "max")
        self.assertEqual(payload["max_tokens"], 16384)

    def test_pending_polls_existing_id_not_new_post(self):
        ident = "12345678-1234-1234-1234-123456789abc"
        final = json.dumps({"model": k.MODEL, "choices": [{"message": {"content": "patch"}, "finish_reason": "stop"}]}).encode()
        class Response(io.BytesIO):
            def __init__(self, status, headers, body=b""):
                super().__init__(body)
                self.status, self.headers = status, headers
        class Opener:
            def __init__(self):
                self.calls = []
            def open(self, request, timeout):
                self.calls.append((request.get_method(), request.full_url))
                if len(self.calls) == 1:
                    return Response(202, {"NVCF-REQID": ident})
                if len(self.calls) == 2:
                    return Response(202, {})
                return Response(200, {"Content-Type": "application/json"}, final)
        opener = Opener()
        with patch.object(k.time, "sleep"):
            answer, meta = k.consult("task", [], 16384, "fake-key", opener, "max", "json")
        self.assertEqual(answer, "patch")
        self.assertTrue(meta["complete"])
        self.assertEqual(opener.calls, [("POST", common.ENDPOINT), ("GET", k.STATUS_URL + ident), ("GET", k.STATUS_URL + ident)])

    def test_malicious_pending_identifier_rejected(self):
        class Pending(io.BytesIO):
            status = 202
            headers = {"NVCF-REQID": "https://example.com/steal"}
        class Opener:
            calls = 0
            def open(self, request, timeout):
                self.calls += 1
                return Pending()
        opener = Opener()
        with self.assertRaisesRegex(common.BridgeError, "Invalid pending request ID"):
            k.consult("task", [], 16384, "fake-key", opener, "max", "json")
        self.assertEqual(opener.calls, 1)


if __name__ == "__main__":
    unittest.main()
