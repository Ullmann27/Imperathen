#!/usr/bin/env python3
"""Validate modular Meshy loadouts against the canonical asset manifest."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys


COMPONENT_RULES = {
    "body": {"character"},
    "mount": {"mount"},
    "saddle": {"equipment"},
    "primary": {"weapon", "equipment"},
    "sidearm": {"weapon", "equipment"},
    "shield": {"equipment"},
}


def validate(manifest_path: Path, loadouts_path: Path) -> dict:
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    data = json.loads(loadouts_path.read_text(encoding="utf-8"))
    if data.get("schema_version") != 1:
        raise ValueError("loadouts schema_version must be 1")

    assets = {}
    for entry in manifest.get("assets", []):
        if not isinstance(entry, dict):
            continue
        stable_id = entry.get("stable_id")
        if isinstance(stable_id, str) and stable_id:
            if stable_id in assets:
                raise ValueError(f"duplicate manifest asset {stable_id}")
            assets[stable_id] = entry

    loadouts = data.get("loadouts")
    if not isinstance(loadouts, list) or not loadouts:
        raise ValueError("loadouts must be a non-empty list")

    seen_ids = set()
    references = 0
    for index, loadout in enumerate(loadouts):
        if not isinstance(loadout, dict):
            raise ValueError(f"loadouts[{index}] must be an object")
        loadout_id = loadout.get("id")
        if not isinstance(loadout_id, str) or not loadout_id or loadout_id in seen_ids:
            raise ValueError(f"loadouts[{index}] has invalid/duplicate id")
        seen_ids.add(loadout_id)
        if loadout.get("runtime_enabled") is not False:
            raise ValueError(f"{loadout_id}: runtime_enabled must remain false before integration")
        for key, allowed_categories in COMPONENT_RULES.items():
            asset_id = loadout.get(key)
            if asset_id is None:
                continue
            if not isinstance(asset_id, str) or asset_id not in assets:
                raise ValueError(f"{loadout_id}: unknown {key} asset {asset_id!r}")
            category = assets[asset_id].get("category")
            if category not in allowed_categories:
                raise ValueError(f"{loadout_id}: {key} uses category {category!r}, expected {sorted(allowed_categories)}")
            references += 1

    bindings = data.get("resource_bindings")
    if not isinstance(bindings, list):
        raise ValueError("resource_bindings must be a list")
    seen_assets = set()
    seen_keys = set()
    for index, binding in enumerate(bindings):
        if not isinstance(binding, dict):
            raise ValueError(f"resource_bindings[{index}] must be an object")
        asset_id = binding.get("asset_id")
        economy_key = binding.get("economy_key")
        if asset_id not in assets or assets[asset_id].get("category") != "resource":
            raise ValueError(f"resource binding uses non-resource asset {asset_id!r}")
        if not isinstance(economy_key, str) or not economy_key:
            raise ValueError(f"resource binding {asset_id!r} has invalid economy_key")
        if asset_id in seen_assets or economy_key in seen_keys:
            raise ValueError("resource bindings must be one-to-one")
        seen_assets.add(asset_id)
        seen_keys.add(economy_key)

    return {
        "loadouts": len(loadouts),
        "component_references": references,
        "resource_bindings": len(bindings),
        "manifest_assets": len(assets),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=Path, default=Path("prototype/assets/meshy/manifest.json"))
    parser.add_argument("--loadouts", type=Path, default=Path("prototype/assets/meshy/loadouts.json"))
    args = parser.parse_args()
    try:
        report = validate(args.manifest, args.loadouts)
    except (OSError, json.JSONDecodeError, ValueError) as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return 1
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
