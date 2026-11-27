#!/usr/bin/env python3
"""Verify a Unity AI-exported GLB and optionally stage it for Godot review.

Never marks an asset runtime-ready and never edits gameplay or releases.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import shutil
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "art"))
from inspect_meshy_glb import inspect_glb, GlbError

KINDS = ("character", "prop", "architecture")
MAX_BYTES = 200 * 1024 * 1024
SAFE_ID = re.compile(r"[a-z][a-z0-9_]{2,63}")

def inspect_for_godot(source: Path, kind: str, expected_sha256: str = "") -> dict:
    if kind not in KINDS:
        raise ValueError("unsupported_asset_kind")
    if not source.is_file() or source.suffix.lower() != ".glb" or not 0 < source.stat().st_size <= MAX_BYTES:
        raise ValueError("missing_invalid_or_unbounded_glb")
    metrics = inspect_glb(source)
    if expected_sha256:
        if not re.fullmatch(r"[0-9a-f]{64}", expected_sha256) or metrics["sha256"] != expected_sha256:
            raise ValueError("source_sha256_mismatch")
    if not metrics["self_contained"] or not metrics["static_binary_gate"] or metrics["triangles"] <= 0:
        raise ValueError("geometry_pbr_or_embedded_textures_missing")
    if metrics["primitives_with_uv0"] != metrics["primitives"]:
        raise ValueError("missing_texture_uv")
    if kind == "character" and not metrics["character_rig_gate"]:
        raise ValueError("character_requires_skin_and_animations")
    return {
        "schema": 1, "source": "unity_ai_export", "kind": kind,
        "status": "binary_verified_pending_godot_visual_and_device_qa",
        "sha256": metrics["sha256"], "bytes": metrics["size_bytes"],
        "triangles": metrics["triangles"], "skins": metrics["skins"],
        "animations": metrics["animations"], "materials": metrics["materials"],
        "pbr_materials": metrics["pbr_materials"], "images": len(metrics["images"]),
        "runtime_ready": False, "visual_acceptance": False, "fold7_device_test": False,
    }

def stage_for_review(source: Path, repo_root: Path, asset_id: str, info: dict) -> Path:
    if SAFE_ID.fullmatch(asset_id) is None:
        raise ValueError("invalid_asset_id")
    destination = (repo_root / "prototype/assets/unity/review" / (asset_id + ".glb")).resolve()
    if not destination.is_relative_to(repo_root.resolve()):
        raise ValueError("invalid_review_destination")
    if destination.exists():
        existing = inspect_glb(destination)
        if existing["sha256"] != info["sha256"]:
            raise FileExistsError("existing_review_asset_has_different_hash")
    else:
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, destination)
    return destination

def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--input", required=True, type=Path)
    p.add_argument("--kind", required=True, choices=KINDS)
    p.add_argument("--expected-sha256", default="")
    p.add_argument("--report", required=True, type=Path)
    p.add_argument("--review-id", default="")
    p.add_argument("--repo-root", default=ROOT, type=Path)
    args = p.parse_args()
    try:
        info = inspect_for_godot(args.input, args.kind, args.expected_sha256)
        if args.review_id:
            staged = stage_for_review(args.input, args.repo_root, args.review_id, info)
            info["godot_review_path"] = str(staged.relative_to(args.repo_root.resolve()))
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(info, indent=2) + "\n", encoding="utf-8")
        print("UNITY_ASSET_BINARY_GATE_PASS", info["kind"], info["sha256"])
        return 0
    except (OSError, ValueError, GlbError, json.JSONDecodeError):
        print("UNITY_ASSET_BINARY_GATE_FAIL", file=sys.stderr)
        return 1

if __name__ == "__main__":
    raise SystemExit(main())
