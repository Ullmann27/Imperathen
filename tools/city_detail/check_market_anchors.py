#!/usr/bin/env python3
"""Check city shop anchors against the exact version of the Blender generator.

Read-only validation; does not require Blender or Godot or touch save data.
"""
from __future__ import annotations

import hashlib
import json
from math import isclose
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "tools/world/build_roman_test_city.py"
MANIFEST = ROOT / "prototype/assets/city_detail/shops/city_market_anchors.json"

SHOP_KINDS = {
    "foodstall": 0,
    "bakery": 2,
    "pottery": 3,
    "clothier": 4,
    "armorer": 5,
    "thermopolium": 6,
}
KIND_LABELS = {
    "foodstall": "Lebensmittel",
    "bakery": "Bäckerei",
    "pottery": "Töpferei",
    "clothier": "Tuchwaren",
    "armorer": "Ausrüster",
    "thermopolium": "Garküche",
}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> None:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    original = SOURCE.read_bytes()
    actual_blob = hashlib.sha1(
        b"blob " + str(len(original)).encode("ascii") + b"\0" + original
    ).hexdigest()
    require(actual_blob == manifest["source_blob_sha"], "City generator changed; remap stalls explicitly")
    source = original.decode("utf-8")
    for definition in (
        "for n in range(63):",
        "kind=n%7;construction=(n//7)%3;size=n//21",
        "'Market_%02d_Type%d_Build%d_Size%d'%(n+1,kind,construction,size)",
        "-385+n*770/62,-47",
    ):
        require(definition in source, f"City generator layout formula changed: {definition}")
    require(manifest["format"] == "imperathen-city-market-anchors", "Unexpected manifest type")
    require(manifest["version"] == 1, "Unsupported site contract")
    require(manifest["authoritative_commerce_enabled"] is False, "This is only a site survey, not a trade implementation")
    items = manifest["shops"]
    require(isinstance(items, list) and len(items) == len(SHOP_KINDS), "Exactly six shop nodes required")
    seen_names, seen_ids, seen_indices = set(), set(), set()
    for shop in items:
        key = shop["shop_id"]
        require(key in SHOP_KINDS and key not in seen_ids, f"Unknown or duplicate shop ID: {key}")
        seen_ids.add(key)
        index = shop["stall_index_zero"]
        require(isinstance(index, int) and index not in seen_indices and 0 <= index < 63,
                f"Out-of-range or duplicate stall: {index}")
        seen_indices.add(index)
        kind = SHOP_KINDS[key]
        require(index % 7 == kind == shop["authored_kind"], f"Stock category does not match visible goods: {key}")
        name = f"Market_{index+1:02d}_Type{kind}_Build{(index//7)%3}_Size{index//21}"
        require(shop["stand_node"] == name and name not in seen_names, f"Unexpected GLB node: {key}")
        seen_names.add(name)
        require(shop["display_label"] == KIND_LABELS[key], f"Unknown signage label: {key}")
        coordinate = shop["center_godot_m"]
        require(len(coordinate) == 3 and all(isinstance(n,(int,float)) for n in coordinate),
                f"Invalid metric coordinate: {key}")
        expected = -385 + index * 770 / 62
        require(isclose(coordinate[0], expected, abs_tol=1e-7) and
                isclose(coordinate[1], 0, abs_tol=1e-7) and
                isclose(coordinate[2], 47, abs_tol=1e-7),
                f"Node centre does not match authored Blender placement and Godot axis mapping: {key}")
    require(seen_ids == set(SHOP_KINDS), "Incomplete shops")
    require(len(seen_names) == 6, "Shops overlap")
    print(f"CITY_MARKET_COORDS_PASS shops={len(items)} source_blob={actual_blob[:12]}")


if __name__ == "__main__":
    main()
