#!/usr/bin/env python3
"""Expand voice_pool.json (hero age family + NPC pool) into a cast file and a
line list that generate_voices.py consumes alongside voice_cast.json.

Outputs (work dir): cast_all.json, lines_pool.json
"""
import argparse, hashlib, json
from pathlib import Path

HERE = Path(__file__).resolve().parent


def text_key(text):
    # Must match scripts/audio/voice_lines.gd: sha256 hex, first 16 chars.
    return hashlib.sha256(text.encode("utf-8")).hexdigest()[:16]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--work", required=True)
    a = ap.parse_args()
    work = Path(a.work)
    cast = json.loads((HERE / "voice_cast.json").read_text(encoding="utf-8"))
    pool = json.loads((HERE / "voice_pool.json").read_text(encoding="utf-8"))
    speakers = dict(cast["speakers"])
    lines = []
    fam = pool["hero_family"]
    base = fam["base"]
    speakers[base["id"]] = {k: base[k] for k in ("name", "age", "class", "seed", "f0_target", "instruct")}
    for stage in fam["stages"]:
        speakers[stage["id"]] = {"name": stage["name"], "age": stage["age"], "class": stage["class"], "f0_target": stage["f0_target"],
                                 "derive_from": base["id"], "transform": stage["transform"], "seed": base["seed"]}
        for bark, text in fam["barks"].items():
            lines.append({"line_id": f"hero.{stage['id']}.{bark}", "scope": "hero_barks", "kind": "bark", "speaker_id": stage["id"],
                          "speaker_label": stage["name"], "text": text, "text_key": text_key(text), "source": "tools/audio/voice_pool.json:hero_family.barks"})
    npc = pool["npc_pool"]
    for cat, spec in npc["categories"].items():
        for i in range(spec["count"]):
            vid = f"npc_{cat}_{i}"
            seed = int(hashlib.sha256(vid.encode()).hexdigest()[:6], 16) % 90000 + 10000
            speakers[vid] = {"name": f"NPC {cat} {i}", "age": spec["age"], "class": spec["class"], "seed": seed,
                             "f0_target": spec["f0_target"], "attempts": 3,
                             "instruct": f"{spec['base']}, {spec['timbres'][i % len(spec['timbres'])]}, natürlich gesprochen."}
            for bark, options in npc["barks"].items():
                text = options[i % len(options)]
                lines.append({"line_id": f"pool.{vid}.{bark}", "scope": "npc_barks", "kind": "bark", "speaker_id": vid,
                              "speaker_label": vid, "text": text, "text_key": text_key(text), "source": "tools/audio/voice_pool.json:npc_pool.barks"})
    out_cast = dict(cast)
    out_cast["speakers"] = speakers
    (work / "cast_all.json").write_text(json.dumps(out_cast, indent=1, ensure_ascii=False), encoding="utf-8")
    (work / "lines_pool.json").write_text(json.dumps({"schema_version": 1, "lines": lines}, indent=1, ensure_ascii=False), encoding="utf-8")
    print("POOL_CAST", len(speakers), "speakers,", len(lines), "bark lines")


if __name__ == "__main__":
    main()
