"""Compare two runtime_profile.py result files and print a markdown table.

Usage: python3 tools/perf/compare_profiles.py before.json after.json > table.md
Values are desktop/software-renderer measurements; only the relative change
between two source states measured with the same harness and seed matters.
"""

import json
import sys
from pathlib import Path


def frame(entry, key):
    return entry["cpu"]["summary"]["frame_ms"][key]


def script_total(entry, name):
    rows = entry.get("attributed", {}).get("process_attribution", []) + entry.get("attributed", {}).get("physics_attribution", [])
    return sum(r["ms_per_frame"] for r in rows if Path(r["script"]).name == name)


def pct(before, after):
    return f"{(after - before) / before * 100:+.0f} %" if before else "–"


def main():
    before = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    after = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
    print("| Szene/Profil | bester Ø vorher | nachher | Δ | bestes p95 vorher | nachher | Δ | Median-Ø vorher | nachher | p99 vorher | nachher |")
    print("| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |")
    for key in before["results"]:
        if key not in after["results"]:
            continue
        b, a = before["results"][key], after["results"][key]
        if b["cpu"].get("failed") or a["cpu"].get("failed"):
            print(f"| {key} | Lauf fehlgeschlagen | | | | | | | | | |")
            continue
        bm, am = b["cpu"]["best_frame_mean_ms"], a["cpu"]["best_frame_mean_ms"]
        bp, ap = b["cpu"]["best_frame_p95_ms"], a["cpu"]["best_frame_p95_ms"]
        print(f"| {key} | {bm:.2f} | {am:.2f} | {pct(bm, am)} | {bp:.2f} | {ap:.2f} | {pct(bp, ap)} | "
              f"{frame(b,'mean'):.2f} | {frame(a,'mean'):.2f} | {frame(b,'p99'):.2f} | {frame(a,'p99'):.2f} |")
    print()
    print("Attributierte Skriptzeit (ms je Frame, _process + _physics_process):")
    print()
    print("| Szene/Profil | Skript | vorher | nachher |")
    print("| --- | --- | ---: | ---: |")
    for key in before["results"]:
        if key not in after["results"]:
            continue
        names = set()
        for entry in (before["results"][key], after["results"][key]):
            rows = entry.get("attributed", {}).get("process_attribution", []) + entry.get("attributed", {}).get("physics_attribution", [])
            names.update(Path(r["script"]).name for r in rows if r["ms_per_frame"] >= 0.05)
        for name in sorted(names, key=lambda n: -script_total(before["results"][key], n)):
            print(f"| {key} | {name} | {script_total(before['results'][key], name):.3f} | {script_total(after['results'][key], name):.3f} |")
    micro_b = before["results"].get("village/balanced", {}).get("cpu", {}).get("census", {}).get("microbench", {})
    micro_a = after["results"].get("village/balanced", {}).get("cpu", {}).get("census", {}).get("microbench", {})
    if micro_b and micro_a:
        print()
        print("Domänenschritt (village/balanced, private Zustandskopie, ms je Aufruf):")
        print()
        print("| Messung | vorher | nachher |")
        print("| --- | ---: | ---: |")
        for name in ["validate_state_ms", "world_copy_ms", "advance_0_1s_ms", "advance_1_60s_ms"]:
            print(f"| {name} | {micro_b.get(name, 0):.3f} | {micro_a.get(name, 0):.3f} |")


if __name__ == "__main__":
    main()
