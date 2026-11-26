#!/usr/bin/env python3
"""Validate the Meshy source ledger without pretending the binary GLBs exist."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys


ALLOWED_STATUS = {"ready_in_meshy", "geometry_ready_untextured"}
ALLOWED_CATEGORIES = {"weapon", "character", "equipment", "resource", "mount", "building"}


def fail(message: str) -> None:
    raise ValueError(message)


def validate(path: Path) -> dict:
    data = json.loads(path.read_text(encoding="utf-8"))
    if data.get("schema_version") != 1:
        fail("schema_version must be 1")
    if data.get("source_provider") != "Meshy 3D":
        fail("source_provider must be Meshy 3D")
    if data.get("binary_delivery_status") != "not_committed_from_this_session":
        fail("binary delivery state must remain explicit until GLBs are committed")

    assets = data.get("assets")
    if not isinstance(assets, list) or not assets:
        fail("assets must be a non-empty list")

    ids: set[str] = set()
    task_ids: set[str] = set()
    preview_ids: set[str] = set()
    counts = {key: 0 for key in ALLOWED_CATEGORIES}
    states = {key: 0 for key in ALLOWED_STATUS}

    for index, asset in enumerate(assets):
        label = f"assets[{index}]"
        stable_id = asset.get("stable_id")
        if not isinstance(stable_id, str) or not stable_id:
            fail(f"{label}: stable_id missing")
        if stable_id in ids:
            fail(f"{label}: duplicate stable_id {stable_id}")
        ids.add(stable_id)

        category = asset.get("category")
        if category not in ALLOWED_CATEGORIES:
            fail(f"{label}: invalid category {category!r}")
        counts[category] += 1

        status = asset.get("status")
        if status not in ALLOWED_STATUS:
            fail(f"{label}: invalid status {status!r}")
        states[status] += 1

        if asset.get("runtime_ready") is not False:
            fail(f"{label}: runtime_ready cannot be true before binary integration")

        source_path = asset.get("intended_source_path")
        if not isinstance(source_path, str) or not source_path.endswith(".glb"):
            fail(f"{label}: intended_source_path must end in .glb")
        if not source_path.startswith("prototype/assets/meshy/source/"):
            fail(f"{label}: source path outside Meshy asset root")

        task_id = asset.get("meshy_task_id")
        preview_id = asset.get("meshy_preview_task_id")
        if status == "ready_in_meshy":
            if not isinstance(task_id, str) or not task_id:
                fail(f"{label}: final Meshy task id required")
            if task_id in task_ids:
                fail(f"{label}: duplicate final Meshy task id {task_id}")
            task_ids.add(task_id)
        else:
            if task_id is not None:
                fail(f"{label}: untextured geometry must not claim a final task")
            if not isinstance(preview_id, str) or not preview_id:
                fail(f"{label}: preview task id required")
            if preview_id in preview_ids:
                fail(f"{label}: duplicate preview Meshy task id {preview_id}")
            preview_ids.add(preview_id)

        if asset.get("format") != "glb":
            fail(f"{label}: format must be glb")
        if category in {"character", "mount"} and asset.get("rigging_required") is not True:
            fail(f"{label}: {category} must require rigging")

    return {
        "assets": len(assets),
        "categories": counts,
        "states": states,
        "unique_final_tasks": len(task_ids),
        "unique_preview_tasks": len(preview_ids),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "manifest",
        nargs="?",
        default="prototype/assets/meshy/manifest.json",
    )
    args = parser.parse_args()
    try:
        report = validate(Path(args.manifest))
    except (OSError, json.JSONDecodeError, ValueError) as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return 1
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
