#!/usr/bin/env python3
"""Fail-closed validation of IMPERATHEN's Unity AI asset production queue."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import re

SAFE_ID = re.compile(r"[a-z][a-z0-9_]{2,63}\Z")
ALLOWED_KINDS = {"character", "prop", "architecture"}
REQUIRED_ACCEPTANCE = {
    "real_glb_source", "sha256", "embedded_textures", "pbr_materials",
    "uv0", "godot_import", "real_scene_review", "fold7_profile_qa"
}
REQUIRED_CHARACTER = {"skin", "animation_clips", "human_anatomy_review", "foot_contact"}

def validate(data: dict) -> dict:
    if data.get("schema_version") != 1 or data.get("project") != "IMPERATHEN":
        raise ValueError("invalid_catalog_identity")
    if data.get("game_engine") != "Godot" or data.get("first_play_year_bce") != 58:
        raise ValueError("invalid_engine_or_historical_start")
    if (data.get("generate_without_user_credit_approval") is not False or
        data.get("automatic_merge_to_main") is not False or
        data.get("assets_are_private_until_licensing_review") is not True):
        raise ValueError("unsafe_cost_publication_or_release_settings")
    if data.get("status") != "DESIGN_CATALOG_ONLY_NO_GENERATION_EXECUTED":
        raise ValueError("unverified_generation_claim")
    assets = data.get("assets")
    if not isinstance(assets, list) or not assets:
        raise ValueError("asset_queue_missing")
    seen = set()
    for entry in assets:
        if not isinstance(entry, dict):
            raise ValueError("invalid_asset_entry")
        stable_id = entry.get("id")
        if not isinstance(stable_id, str) or not SAFE_ID.fullmatch(stable_id) or stable_id in seen:
            raise ValueError("duplicate_or_unsafe_id")
        seen.add(stable_id)
        if entry.get("kind") not in ALLOWED_KINDS or entry.get("priority") not in (1, 2, 3):
            raise ValueError("invalid_kind_or_priority")
        if entry.get("period") != "58 BCE late Roman Republic":
            raise ValueError("unreviewed_non_republican_period")
        if len(entry.get("prompt_en", "")) < 50 or not entry.get("history_notes"):
            raise ValueError("incomplete_asset_brief")
        if entry.get("destination") != f"prototype/assets/unity/review/{stable_id}.glb":
            raise ValueError("review_destination_mismatch")
        checks = entry.get("acceptance", [])
        if not isinstance(checks, list) or not REQUIRED_ACCEPTANCE.issubset(set(checks)):
            raise ValueError("missing_source_and_device_review_gates")
        if entry["kind"] == "character" and not REQUIRED_CHARACTER.issubset(set(checks)):
            raise ValueError("missing_character_rigging_and_contact_gates")
        if (entry.get("generated") is not False or
            entry.get("source_imported_to_godot") is not False or
            entry.get("godot_visual_accepted") is not False or
            entry.get("fold7_accepted") is not False):
            raise ValueError("asset_without_test_must_not_claim_ready")
        if entry.get("state") != "DESIGN_READY_GENERATION_BLOCKED_UNTIL_AI_ACCESS_AND_COST_APPROVAL":
            raise ValueError("asset_status_misrepresented")
    existing = data.get("existing_model_priority", [])
    if not isinstance(existing, list) or not existing:
        raise ValueError("missing_existing_meshy_reuse_policy")
    return {"schema": 1, "catalog_valid": True, "planned_assets": len(assets),
            "already_generated_in_this_queue": 0, "source_imported": 0,
            "model_claims": "design_ready_not_generated", "cost_cap_enabled": True}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--queue", type=Path, default=Path("tools/unity_bridge/production_queue.json"))
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    result = validate(json.loads(args.queue.read_text(encoding="utf-8")))
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print("IMPERATHEN_UNITY_PRODUCTION_QUEUE_VALID", result["planned_assets"])

if __name__ == "__main__":
    main()
