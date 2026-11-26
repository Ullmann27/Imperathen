#!/usr/bin/env python3
"""Check four Android graphics QA targets; does not claim measured performance."""
import json
from pathlib import Path

p = Path(__file__).resolve().parents[1] / "prototype/data/graphics/android_qa_targets.v1.json"
d = json.loads(p.read_text(encoding="utf-8"))
assert d["schema_version"] == 1 and d["platform"] == "Android"
tiers = d["presets"]
assert [x["id"] for x in tiers] == ["leicht", "ausgewogen", "hoch", "sehr_hoch"]
assert len({x["id"] for x in tiers}) == 4
for t in tiers:
    assert t["target_fps"] > 0 and abs(t["frame_budget_ms"] - 1000/t["target_fps"]) < .02
assert [x["character_lod"] for x in tiers] == [3, 2, 1, 0]
assert [x["shadow_tier"] for x in tiers] == [0, 1, 2, 3]
print("ANDROID_GRAPHICS_TARGETS_PASS: 4 profile targets (not FPS measurements)")
