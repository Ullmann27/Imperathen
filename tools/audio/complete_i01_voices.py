#!/usr/bin/env python3
"""Produce only missing I-01 speech from the existing synthetic cast.

No paid API, no real-person reference. Reuses a checksum-verified recording
of each fictional character, pinned Qwen/Whisper/alignment pipeline, existing
WER threshold, and the canonical authored text. Existing audio bytes are
never overwritten. Run in a disposable checkout; commit only after Godot QA.
"""
import argparse
import hashlib
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
AUDIO = ROOT / "prototype/assets/audio/voice"
MISSION = ROOT / "prototype/assets/story/missions/band1/I-01.json"
TOOLS = ROOT / "tools/audio"
ALIASES = {"chronik": "narrator", "wachmann": "severus"}

def read(path):
    return json.loads(path.read_text(encoding="utf-8"))

def write(path, obj):
    path.write_text(json.dumps(obj, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def key(text):
    return hashlib.sha256(text.encode("utf-8")).hexdigest()[:16]

def speaker(label):
    label = label.strip().lower()
    return ALIASES.get(label, label)

def authored_lines():
    mission = read(MISSION)
    result = []
    for line_id, entry in mission["slice"]["lines"].items():
        result.append((line_id, speaker(entry["speaker_id"]), entry["text"]))
    for step in mission["steps"]:
        if step.get("text"):
            result.append(("I-01." + step["id"], speaker(step["npc"]), step["text"]))
        if step.get("result"):
            result.append(("I-01." + step["id"] + ".result", "narrator", step["result"]))
    return result

def verify_file(entry, file_field, sha_field):
    path = AUDIO / entry[file_field]
    if not path.is_file() or digest(path) != entry[sha_field]:
        raise SystemExit(f"Audio catalogue mismatch: {path}")
    return path

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--work", type=Path, required=True)
    args = parser.parse_args()
    work = args.work.resolve()
    work.mkdir(parents=True, exist_ok=False)
    stage = work / "staged"
    stage.mkdir()
    (work / "refs").mkdir()
    manifest = read(AUDIO / "manifest.json")
    by_key = {row["text_key"]: row for row in manifest["lines"] if row.get("kind", "story") == "story"}
    by_id = {row["line_id"] for row in manifest["lines"]}
    wanted = []
    for lid, sid, text in authored_lines():
        k = key(text)
        if k in by_key:
            row = by_key[k]
            if row["text"] != text or row["speaker_id"] != sid:
                raise SystemExit(f"Ambiguous text/speaker hash: {lid}")
            verify_file(row, "file", "sha256")
            verify_file(row, "visemes", "visemes_sha256")
            continue
        if any(row["text_key"] == k for row in wanted):
            if any(row["text_key"] == k and row["speaker_id"] != sid for row in wanted):
                raise SystemExit(f"Conflicting new voice: {lid}")
            continue
        # Preserve historical dialogue already stored with the former ID.
        new_id = lid if lid not in by_id else f"{lid}.{k}"
        by_id.add(new_id)
        wanted.append({"line_id": new_id, "scope": "I-01", "speaker_id": sid,
                       "text": text, "text_key": k, "source": str(MISSION.relative_to(ROOT))})
    if not wanted:
        print("I01_VOICE_COVERAGE_COMPLETE")
        return
    refs = {}
    for sid in sorted({row["speaker_id"] for row in wanted}):
        candidates = [row for row in manifest["lines"] if row["speaker_id"] == sid
                      and row.get("model", "").startswith("Qwen/")
                      and 3 <= row.get("duration_s", 0) <= 20
                      and row.get("asr_wer", 1) <= 0.12 and row.get("asr_text")]
        if not candidates:
            raise SystemExit(f"No verified synthetic reference for {sid}")
        row = min(candidates, key=lambda r: (r["asr_wer"], abs(r["duration_s"] - 9)))
        src = verify_file(row, "file", "sha256")
        wav = work / "refs" / (sid + ".wav")
        subprocess.run(["ffmpeg", "-nostdin", "-loglevel", "error", "-i", str(src),
                        "-ac", "1", "-c:a", "pcm_s16le", str(wav)], check=True)
        refs[sid] = {"seed": row["reference_seed"], "file": str(wav), "sha256": digest(wav),
                     "ref_text": row["asr_text"], "line_id": row["line_id"]}
    write(work / "refs.json", refs)
    write(work / "missing.json", {"lines": wanted})
    py = sys.executable
    # A deterministic retry must try additional seeds, not repeat the four
    # rejected samples forever. Keep the existing WER and alignment gates.
    subprocess.run([py, "-I", str(TOOLS / "generate_voices.py"), "--strict", "--attempts", "16", "--lines",
                    str(work / "missing.json"), "--work", str(work), "--out", str(stage),
                    "--only", *refs.keys()], check=True)
    subprocess.run([py, "-I", str(TOOLS / "align_visemes.py"), "--work", str(work), "--out", str(stage)], check=True)
    meta = read(work / "lines_meta.json")
    fields = ("line_id", "kind", "speaker_id", "text", "text_key", "file", "sha256", "visemes",
              "visemes_sha256", "duration_s", "model", "voice_design_model", "reference_seed",
              "reference_audio_sha256", "reference_line_id", "seed", "post", "asr_wer", "asr_text",
              "lufs_integrated", "alignment")
    entries = []
    for request in wanted:
        row = meta[request["line_id"]]
        if any(row[field] != request[field] for field in ("text", "text_key", "speaker_id")):
            raise SystemExit("Generated line does not match request")
        if row["asr_wer"] > 0.12 or not row["alignment"]["phonemes"]:
            raise SystemExit("Generated line did not pass the existing acceptance thresholds")
        if abs(row["alignment"]["onset_delta_ms"]) > 16.7:
            raise SystemExit("Generated line alignment exceeds one 60 Hz frame")
        for filename, checksum in (("file", "sha256"), ("visemes", "visemes_sha256")):
            src = stage / row[filename]
            dst = AUDIO / row[filename]
            if not src.is_file() or digest(src) != row[checksum] or dst.exists():
                raise SystemExit(f"Unaccepted output or overwrite: {dst}")
        entry = {name: row[name] for name in fields if name in row}
        metrics = row.get("metrics", {})
        entry["f0_median_hz"] = metrics.get("f0_median_hz")
        entry["formants_hz"] = [metrics.get("F1"), metrics.get("F2"), metrics.get("F3")]
        entries.append(entry)
    # All generated bytes have passed integrity, transcription and alignment.
    # Godot runtime acceptance remains mandatory before committing the checkout.
    for entry in entries:
        for name in ("file", "visemes"):
            dst = AUDIO / entry[name]
            dst.parent.mkdir(parents=True, exist_ok=True)
            dst.write_bytes((stage / entry[name]).read_bytes())
    manifest["lines"].extend(entries)
    manifest["lines"].sort(key=lambda row: row["line_id"])
    write(AUDIO / "manifest.json", manifest)
    print(f"I01_VOICE_GENERATED {len(entries)} exact lines; Godot acceptance still required")

if __name__ == "__main__":
    main()
