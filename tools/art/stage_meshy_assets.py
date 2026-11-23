#!/usr/bin/env python3
"""Validate and stage downloaded Meshy GLBs into the Godot source tree.

The tool never marks an asset runtime-ready. It only proves that the exact
binary is structurally acceptable and records reproducible hashes/metrics.
"""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import shutil
import sys

from inspect_meshy_glb import GlbError, inspect_glb


def _load_manifest(path: Path) -> dict:
    data = json.loads(path.read_text(encoding="utf-8"))
    assets = data.get("assets")
    if not isinstance(assets, list):
        raise ValueError("manifest assets must be a list")
    return data


def _asset_map(manifest: dict) -> dict[str, dict]:
    result: dict[str, dict] = {}
    for value in manifest["assets"]:
        if not isinstance(value, dict):
            continue
        stable_id = value.get("stable_id")
        if isinstance(stable_id, str) and stable_id:
            if stable_id in result:
                raise ValueError(f"duplicate stable_id in manifest: {stable_id}")
            result[stable_id] = value
    return result


def _parse_assignments(values: list[str]) -> dict[str, Path]:
    result: dict[str, Path] = {}
    for value in values:
        if "=" not in value:
            raise ValueError(f"--asset expects STABLE_ID=FILE, got {value!r}")
        stable_id, raw_path = value.split("=", 1)
        stable_id = stable_id.strip()
        if not stable_id or stable_id in result:
            raise ValueError(f"invalid or duplicate stable id: {stable_id!r}")
        result[stable_id] = Path(raw_path).expanduser()
    return result


def _load_lock(path: Path) -> dict:
    if not path.exists():
        return {"schema_version": 1, "assets": {}}
    data = json.loads(path.read_text(encoding="utf-8"))
    if data.get("schema_version") != 1 or not isinstance(data.get("assets"), dict):
        raise ValueError("unsupported Meshy lock format")
    return data


def stage(
    manifest_path: Path,
    repo_root: Path,
    assignments: dict[str, Path],
    lock_path: Path,
    *,
    replace: bool = False,
    allow_untextured: bool = False,
    dry_run: bool = False,
) -> dict:
    manifest = _load_manifest(manifest_path)
    known = _asset_map(manifest)
    lock = _load_lock(lock_path)
    results = []

    for stable_id, source in assignments.items():
        if stable_id not in known:
            raise ValueError(f"unknown stable id: {stable_id}")
        entry = known[stable_id]
        if entry.get("status") != "ready_in_meshy" and not allow_untextured:
            raise ValueError(f"{stable_id} is not a final textured Meshy asset")
        source = source.resolve()
        if not source.is_file():
            raise FileNotFoundError(source)
        if source.suffix.lower() != ".glb":
            raise ValueError(f"{stable_id}: source must be .glb")

        metrics = inspect_glb(source)
        if not metrics["self_contained"]:
            raise ValueError(f"{stable_id}: GLB has external URIs")
        if entry.get("status") == "ready_in_meshy" and not metrics["static_binary_gate"]:
            raise ValueError(f"{stable_id}: final GLB failed the static geometry/material/texture gate")

        destination = repo_root / str(entry["intended_source_path"])
        destination = destination.resolve()
        root_resolved = repo_root.resolve()
        try:
            destination.relative_to(root_resolved)
        except ValueError as exc:
            raise ValueError(f"{stable_id}: destination escapes repository root") from exc

        existing_same = False
        if destination.exists():
            existing = inspect_glb(destination)
            existing_same = existing["sha256"] == metrics["sha256"]
            if not existing_same and not replace:
                raise FileExistsError(f"{stable_id}: destination exists with another hash; use --replace")

        if not dry_run and not existing_same:
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, destination)

        lock_entry = {
            "meshy_task_id": entry.get("meshy_task_id"),
            "meshy_preview_task_id": entry.get("meshy_preview_task_id"),
            "path": str(destination.relative_to(root_resolved)).replace("\\", "/"),
            "sha256": metrics["sha256"],
            "size_bytes": metrics["size_bytes"],
            "triangles": metrics["triangles"],
            "vertices_sum": metrics["vertices_sum"],
            "materials": metrics["materials"],
            "textures": metrics["textures"],
            "skins": metrics["skins"],
            "animations": metrics["animations"],
            "static_binary_gate": metrics["static_binary_gate"],
            "character_rig_gate": metrics["character_rig_gate"],
            "runtime_ready": False,
        }
        lock["assets"][stable_id] = lock_entry
        results.append({
            "stable_id": stable_id,
            "source": str(source),
            "destination": lock_entry["path"],
            "already_identical": existing_same,
            "metrics": lock_entry,
        })

    lock["generated_utc"] = datetime.now(timezone.utc).isoformat()
    lock["manifest"] = str(manifest_path)
    lock["note"] = "Binary staging only. Godot/visual/socket/collision/Android acceptance remains separate."
    if not dry_run:
        lock_path.parent.mkdir(parents=True, exist_ok=True)
        lock_path.write_text(json.dumps(lock, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    return {
        "staged": len(results),
        "dry_run": dry_run,
        "lock_path": str(lock_path),
        "assets": results,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=Path, default=Path("prototype/assets/meshy/manifest.json"))
    parser.add_argument("--repo-root", type=Path, default=Path("."))
    parser.add_argument("--lock", type=Path, default=Path("prototype/assets/meshy/lock.json"))
    parser.add_argument("--asset", action="append", default=[], metavar="STABLE_ID=FILE")
    parser.add_argument("--replace", action="store_true")
    parser.add_argument("--allow-untextured", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    try:
        assignments = _parse_assignments(args.asset)
        if not assignments:
            raise ValueError("at least one --asset STABLE_ID=FILE is required")
        report = stage(
            args.manifest,
            args.repo_root,
            assignments,
            args.lock,
            replace=args.replace,
            allow_untextured=args.allow_untextured,
            dry_run=args.dry_run,
        )
    except (OSError, ValueError, GlbError, json.JSONDecodeError) as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return 1
    payload = json.dumps(report, indent=2, ensure_ascii=False) + "\n"
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(payload, encoding="utf-8")
    print(payload, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
