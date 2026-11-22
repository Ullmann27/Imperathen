#!/usr/bin/env python3
"""Validate the IMPERATHEN weapon catalog; stdlib only."""
from __future__ import annotations
import json
import math
from pathlib import Path

CATALOG = Path(__file__).resolve().parents[1] / "prototype/data/weapons/weapon_catalog.v1.json"
REQUIRED = {"gladius", "spatha", "spear", "lance", "axe", "bow", "scutum"}
ANIMATIONS = {"sword_slash", "spear_thrust", "lance_thrust", "axe_swing", "bow_release", "shield_guard"}
SOCKETS = {"left_hand", "right_hand"}

def validate(document: dict) -> None:
    assert document["schema_version"] == 1
    assert document["unit"] == "meter"
    assert document["coordinate_system"] == "godot_y_up"
    weapons = document["weapons"]
    ids = [w["id"] for w in weapons]
    assert len(ids) == len(set(ids)), "duplicate weapon IDs"
    assert set(ids) == REQUIRED, "unexpected or missing weapons"
    for weapon in weapons:
        assert weapon["grip_socket"] in SOCKETS
        assert weapon["animation"] in ANIMATIONS
        assert weapon["asset"].startswith("weapons/") and weapon["asset"].endswith(".glb")
        for key in ("reach_m", "damage", "stamina_cost", "cooldown_s"):
            value = weapon[key]
            assert type(value) in (int, float) and math.isfinite(value), (weapon["id"], key)
            assert value >= 0, (weapon["id"], key)
        assert weapon["cooldown_s"] > 0
    assert next(w for w in weapons if w["id"] == "bow")["projectile"] == "arrow"
    assert next(w for w in weapons if w["id"] == "scutum")["damage"] == 0

if __name__ == "__main__":
    validate(json.loads(CATALOG.read_text(encoding="utf-8")))
    print("Weapon catalog validation: PASS (7 definitions)")
