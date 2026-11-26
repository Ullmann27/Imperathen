#!/usr/bin/env python3
"""Write prototype/assets/audio/voice/manifest.json from the generation and
alignment metadata (work/lines_meta.json, work/refs.json) and the cast."""
import argparse, json
from pathlib import Path


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--work", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--cast", default=str(Path(__file__).with_name("voice_cast.json")))
    a = ap.parse_args()
    work, out = Path(a.work), Path(a.out)
    meta = json.loads((work / "lines_meta.json").read_text(encoding="utf-8"))
    refs = json.loads((work / "refs.json").read_text(encoding="utf-8"))
    cast = json.loads(Path(a.cast).read_text(encoding="utf-8"))
    lines = []
    for line_id in sorted(meta):
        m = meta[line_id]
        if "visemes" not in m:
            raise SystemExit(f"line {line_id} has no viseme track; run align_visemes.py first")
        keep = ["line_id", "kind", "speaker_id", "text", "text_key", "file", "sha256", "visemes", "visemes_sha256", "duration_s",
                "model", "voice_design_model", "reference_seed", "seed", "post", "asr_wer", "asr_text", "lufs_integrated", "alignment"]
        entry = {k: m[k] for k in keep if k in m}
        mt = m.get("metrics", {})
        entry["f0_median_hz"] = mt.get("f0_median_hz")
        entry["formants_hz"] = [mt.get("F1"), mt.get("F2"), mt.get("F3")]
        lines.append(entry)
    speakers = {}
    line_f0 = {}
    for e in lines:
        if e.get("f0_median_hz"):
            line_f0.setdefault(e["speaker_id"], []).append(e["f0_median_hz"])
    for sid, spec in cast["speakers"].items():
        if sid not in refs:
            continue
        r = refs[sid]
        f0s = sorted(line_f0.get(sid, []))
        speakers[sid] = {"name": spec["name"], "age": spec["age"], "class": spec["class"],
                         "instruct": spec.get("instruct"), "derived_from": r.get("derived_from"), "transform": r.get("transform"),
                         "model_design": "Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign@5ecdb6732", "model_speech": "Qwen/Qwen3-TTS-12Hz-1.7B-Base@fd4b25438",
                         "f0_target_hz": spec["f0_target"], "reference_seed": r["seed"], "reference_sha256": r["sha256"],
                         "reference_f0_median_hz": r["metrics"].get("f0_median_hz"),
                         "reference_formants_hz": [r["metrics"].get("F1"), r["metrics"].get("F2"), r["metrics"].get("F3")],
                         "lines": len(f0s), "lines_f0_median_hz": f0s[len(f0s) // 2] if f0s else None,
                         "tempo": (r.get("transform") or {}).get("duration_factor", 1.0), "post": spec.get("post")}
    manifest = {"schema_version": 1, "language": "de", "loudness_target_lufs": -20.0,
                "generator": "tools/audio/generate_voices.py + tools/audio/align_visemes.py",
                "speakers": speakers, "lines": lines}
    (out / "manifest.json").write_text(json.dumps(manifest, indent=1, ensure_ascii=False), encoding="utf-8")
    registry = {"schema_version": 1, "note": "speaker_id -> fixed voice profile. Named characters, hero age stages (derived from hero_base) and NPC pool voices.",
                "speakers": speakers}
    (out / "voice_registry.json").write_text(json.dumps(registry, indent=1, ensure_ascii=False), encoding="utf-8")
    print("MANIFEST", len(lines), "lines,", len(speakers), "speakers")


if __name__ == "__main__":
    main()
