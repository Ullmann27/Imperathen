#!/usr/bin/env python3
"""Fail closed if the original I-01 well has been flattened into material batches."""
import argparse
import json
from pathlib import Path
from validate_visual_assets import read_glb, validate_asset

REQUIRED = (
    "Well_Bucket_Staves", "Well_Bucket_Base", "Well_Bucket_Hoops",
    "Well_Bucket_Handle", "Well_Hanging_Rope", "Well_Winding_Axle",
    "Well_Axle_Rope_Stop_", "Well_Wound_Rope", "Well_Crank",
)

def validate(path: Path) -> dict:
    report = validate_asset(path, path.parent)
    if report["status"] != "passed":
        raise ValueError(report["errors"])
    document, _, _ = read_glb(path.read_bytes())
    nodes = document.get("nodes", [])
    for prefix in REQUIRED:
        matches = [node for node in nodes if node.get("name", "").startswith(prefix)
                   and isinstance(node.get("mesh"), int)]
        expected = 2 if prefix == "Well_Axle_Rope_Stop_" else 1
        if len(matches) != expected:
            raise ValueError(f"{prefix}: expected {expected} separate mesh nodes, found {len(matches)}")
    report["moving_mesh_nodes"] = [n["name"] for n in nodes
                                  if any(n.get("name", "").startswith(p) for p in REQUIRED)]
    return report

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("glb", type=Path)
    args = parser.parse_args()
    print(json.dumps(validate(args.glb.resolve()), indent=2, ensure_ascii=False))
