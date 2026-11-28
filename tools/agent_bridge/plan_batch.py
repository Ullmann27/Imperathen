#!/usr/bin/env python3
"""Validate a bounded batch before any secret-bearing model job runs."""
import json
import re
from pathlib import Path
import sys
from nemotron_bridge import validate_request

ROOT = Path(__file__).resolve().parent
MAX_TASKS = 8
MAX_BATCH_TOKENS = 110592
TASK_ID = re.compile(r"[a-z0-9][a-z0-9-]{0,62}")

def load_batch(root):
    manifest = json.loads((root / "batch.json").read_text(encoding="utf-8"))
    if not isinstance(manifest, dict) or set(manifest) != {"requests"}:
        raise ValueError("Invalid batch manifest")
    names = manifest["requests"]
    if not isinstance(names, list) or not 1 <= len(names) <= MAX_TASKS:
        raise ValueError("Invalid batch size")
    if any(not isinstance(n, str) or not TASK_ID.fullmatch(n) for n in names) or len(set(names)) != len(names):
        raise ValueError("Invalid or duplicate task id")
    jobs = []
    total = 0
    for name in names:
        relative = "request.json" if name == "single" else f"requests/{name}.json"
        request = json.loads((root / relative).read_text(encoding="utf-8"))
        validate_request(request)
        total += request["max_tokens"]
        jobs.append({"task": name, "request_path": "tools/agent_bridge/" + relative})
    if total > MAX_BATCH_TOKENS:
        raise ValueError("Batch output token cap exceeded")
    return {"include": jobs}

if __name__ == "__main__":
    try:
        print(json.dumps(load_batch(ROOT), separators=(",", ":")))
    except (ValueError, OSError, TypeError, KeyError) as exc:
        print("Invalid NVIDIA batch configuration", file=sys.stderr)
        sys.exit(1)
