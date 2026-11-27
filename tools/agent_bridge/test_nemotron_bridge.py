import io
import json
import time
import unittest
from nemotron_bridge import allowed_path, validate_request, parse_stream, BridgeError

def sse(*events):
    return io.BytesIO(b"".join(b"data: " + json.dumps(e).encode() + b"\n\n" for e in events) + b"data: [DONE]\n\n")

class BridgeTests(unittest.TestCase):
    def test_paths(self):
        self.assertTrue(allowed_path("prototype/scripts/rendering/fold7_quality_policy.gd"))
        for path in (".github/workflows/a.yml", "prototype/scripts/../keys.json", "https://example.com/a.py",
                     "/etc/passwd", "prototype/scripts/.env", "prototype/assets/a.glb", "tools/agent_bridge/request.json"):
            self.assertFalse(allowed_path(path), path)
    def test_request(self):
        valid = {"revision": "a"*40, "task": "Review", "files": ["prototype/project.godot"], "max_tokens": 4096}
        validate_request(valid)
        for bad in ({"revision": "main"}, {"max_tokens": 1000000}, {"files": ["../secret"]},
                    {"task": "nvapi-" + "a"*24}, {"files": ["prototype/project.godot"]*2}):
            with self.assertRaises(BridgeError):
                validate_request({**valid, **bad})
    def test_stream(self):
        stream = sse({"choices":[{"delta":{"reasoning_content":"hidden"},"finish_reason":None}]},
                     {"model":"nemotron","id":"1","choices":[{"delta":{"content":"Patch"},"finish_reason":None}]},
                     {"choices":[{"delta":{},"finish_reason":"stop"}],"usage":{"total_tokens":32}})
        answer, meta = parse_stream(stream, time.monotonic()+10)
        self.assertEqual(answer, "Patch")
        self.assertTrue(meta["complete"])
        self.assertEqual(meta["usage"]["total_tokens"], 32)
    def test_truncated(self):
        answer, meta = parse_stream(sse({"choices":[{"delta":{"content":"Partial"},"finish_reason":"length"}]}),
                                    time.monotonic()+10)
        self.assertEqual(answer, "Partial")
        self.assertFalse(meta["complete"])
    def test_no_final(self):
        with self.assertRaises(BridgeError):
            parse_stream(sse({"choices":[{"delta":{"reasoning_content":"hidden"},"finish_reason":"stop"}]}), time.monotonic()+10)
    def test_missing_done(self):
        with self.assertRaises(BridgeError):
            parse_stream(io.BytesIO(b'data: {"choices":[{"delta":{"content":"partial"},"finish_reason":"stop"}]}\n'), time.monotonic()+10)

if __name__ == "__main__":
    unittest.main()
