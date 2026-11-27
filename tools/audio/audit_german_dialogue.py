#!/usr/bin/env python3
"""Audit exact authored dialogue against the German manifest and actual files."""
import argparse
import hashlib
import json
from pathlib import Path
from collections import Counter

def digest(data):
    return hashlib.sha256(data).hexdigest()

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("authored", type=Path)
    parser.add_argument("--audio", type=Path, default=Path("prototype/assets/audio/voice"))
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("--strict", action="store_true")
    args = parser.parse_args()
    manifest = json.loads((args.audio / "manifest.json").read_text(encoding="utf-8"))
    authored = json.loads(args.authored.read_text(encoding="utf-8"))["lines"]
    by_key = {}
    for row in manifest["lines"]:
        if row.get("kind", "story") == "story":
            by_key.setdefault((row["speaker_id"], row["text_key"]), []).append(row)
    issues = []
    accepted = 0
    counts = {}
    for line in authored:
        scope = line["scope"]
        counts.setdefault(scope, Counter())
        counts[scope]["authored"] += 1
        actual_key = digest(line["text"].encode("utf-8"))[:16]
        rows = by_key.get((line["speaker_id"], actual_key), [])
        reasons = []
        if manifest.get("language") != "de":
            reasons.append("manifest_not_german")
        if line["text_key"] != actual_key:
            reasons.append("authored_hash_mismatch")
        if len(rows) != 1:
            reasons.append("missing_recording" if not rows else "ambiguous_recording")
        else:
            row = rows[0]
            if row["text"] != line["text"]:
                reasons.append("subtitle_mismatch")
            if not isinstance(row.get("asr_wer"), (int, float)) or row["asr_wer"] > 0.12 or not row.get("asr_text"):
                reasons.append("unaccepted_transcription")
            for field, checksum in (("file", "sha256"), ("visemes", "visemes_sha256")):
                relative = row.get(field, "")
                path = args.audio / relative
                if not relative or not path.is_file() or digest(path.read_bytes()) != row.get(checksum):
                    reasons.append(field + "_missing_or_checksum")
            if not any(reason.startswith("visemes") for reason in reasons):
                try:
                    track = json.loads((args.audio / row["visemes"]).read_text(encoding="utf-8"))
                    if track.get("speaker_id") != line["speaker_id"] or track.get("text_key") != actual_key or not track.get("keys"):
                        reasons.append("viseme_identity_mismatch")
                except (OSError, ValueError):
                    reasons.append("viseme_invalid")
        if reasons:
            issues.append({**line, "reasons": reasons})
            counts[scope]["missing_or_invalid"] += 1
        else:
            accepted += 1
            counts[scope]["accepted"] += 1
    report = {"language": manifest.get("language"), "authored": len(authored), "accepted": accepted,
              "missing_or_invalid": len(issues), "scopes": counts, "issues": issues,
              "limits": "Manifest, exact text, checksums, stored ASR and viseme metadata; not a new audio transcription or a device lip-sync measurement."}
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"GERMAN_DIALOGUE_COVERAGE {accepted}/{len(authored)}, missing_or_invalid={len(issues)}")
    if not authored or (args.strict and issues):
        raise SystemExit(1)

if __name__ == "__main__":
    main()
