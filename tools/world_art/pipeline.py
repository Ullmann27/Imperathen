#!/usr/bin/env python3
"""Reuse the existing three-agent pipeline with isolated world-art state.

No model calls, new daemons or shell commands. Claims remain local; issue #16
and the versioned handoff connect separate chats/checkouts.
"""
from __future__ import annotations
import importlib.util
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("imperathen_agent_pipeline", ROOT / "tools/agent_pipeline.py")
pipeline = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pipeline)
pipeline.ROOT = ROOT
pipeline.MANIFEST = "coordination/world_expansion.json"
pipeline.LOCAL = "coordination/.local/world_expansion"
pipeline.CHECKS = {
    "architecture-export": ([sys.executable, "tools/world_art/validate.py", "--category", "architecture"], ["tools/world_art/validate.py", "prototype/assets/world_expansion/manifest.json"]),
    "vegetation-export": ([sys.executable, "tools/world_art/validate.py", "--category", "vegetation"], ["tools/world_art/validate.py", "prototype/assets/world_expansion/manifest.json"]),
    "environment-runtime": ([sys.executable, "tools/world_art/verify_environment.py"], ["tools/world_art/verify_environment.py", "prototype/tests/world_expansion_environment_test.gd"]),
}

def main(argv=None):
    arguments = list(sys.argv[1:] if argv is None else argv)
    # The foundation pipeline's unqualified run appends its Unreal-only gate.
    # Call each named world task instead, keeping the original runner unchanged.
    if arguments == ["run"]:
        results = [pipeline.main(["run", "--task", task])
                   for task in ("architecture", "vegetation", "environment")]
        return 1 if 1 in results else (2 if 2 in results else 0)
    return pipeline.main(arguments)

if __name__ == "__main__":
    raise SystemExit(main())
