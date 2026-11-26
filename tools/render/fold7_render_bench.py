#!/usr/bin/env python3
"""Run the renderer/profile bench views on a physically connected Galaxy Z Fold7.

Same views, cameras, harness night and counters as tests/render_comparison.gd
(scripts/rendering/render_bench.gd), driven by the debug graphics probe in its
"views" mode (scripts/ui/android_graphics_probe.gd). One run measures all four
profiles with the renderer the installed APK was exported with; for a renderer
comparison install one QA APK per renderer and run this once per APK.

Requirements: a debug QA build (the probe only exists in debug builds), an
explicitly chosen ADB serial of an SM-F966* device authorised by its owner.
This tool never targets an emulator and never invents FPS or thermal values;
fields the device does not report stay null.

Usage:
  python3 tools/render/fold7_render_bench.py --serial SERIAL --output DIR
      [--package at.heinz.imperathen.qa] [--settle 30] [--measure 240]
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path, PurePosixPath
import re
import subprocess
import time

PACKAGES = ("at.heinz.imperathen.qa", "at.heinz.imperathen")


def adb(args, serial: str, *command: str, data: bytes | None = None, check: bool = True, raw: bool = False):
    result = subprocess.run([args.adb, "-s", serial, *command], input=data, capture_output=True, timeout=60)
    if check and result.returncode != 0:
        raise RuntimeError("adb " + " ".join(command[:3]) + ": " + result.stderr.decode(errors="replace")[:400])
    return result.stdout if raw else result.stdout.decode(errors="replace").strip()


def number(pattern: str, text: str):
    found = re.search(pattern, text, re.MULTILINE)
    return float(found.group(1)) if found else None


def system(args, serial: str, package: str) -> dict:
    thermal = adb(args, serial, "shell", "dumpsys", "thermalservice", check=False)
    battery = adb(args, serial, "shell", "dumpsys", "battery", check=False)
    memory = adb(args, serial, "shell", "dumpsys", "meminfo", package, check=False)
    return {"host_time": time.time(), "thermal_status": number(r"Thermal (?:Status|status):\s*(\d+)", thermal),
            "battery_tenths_c": number(r"^\s*temperature:\s*(-?\d+)", battery),
            "pss_kib": number(r"TOTAL PSS:\s*([0-9]+)", memory)}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--adb", default="adb")
    parser.add_argument("--serial", required=True)
    parser.add_argument("--package", choices=PACKAGES, default=PACKAGES[0])
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--settle", type=int, default=30)
    parser.add_argument("--measure", type=int, default=240)
    parser.add_argument("--timeout", type=int, default=1200)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    serial = args.serial
    report = {"schema": "imperathen-fold7-render-bench-1", "serial_given": True, "package": args.package, "status": "failed"}
    try:
        model = adb(args, serial, "shell", "getprop", "ro.product.model")
        if "SM-F966" not in model.upper():
            raise RuntimeError("Not a Galaxy Z Fold7 (SM-F966*): " + repr(model))
        if adb(args, serial, "shell", "getprop", "ro.kernel.qemu", check=False) == "1":
            raise RuntimeError("Emulator refused")
        report.update(model=model, android=adb(args, serial, "shell", "getprop", "ro.build.version.release"),
                      gpu=adb(args, serial, "shell", "dumpsys", "SurfaceFlinger", check=False).split("GLES:")[-1].splitlines()[0].strip()[:200])
        files = adb(args, serial, "shell", "run-as", args.package, "pwd")
        folder = PurePosixPath(files) / "files"
        flag, trace = str(folder / "graphics-probe.txt"), str(folder / "graphics-frames.jsonl")
        adb(args, serial, "shell", "run-as", args.package, "rm", "-f", trace)
        adb(args, serial, "shell", "run-as", args.package, "tee", flag, data=f"views {args.settle} {args.measure}\n".encode())
        adb(args, serial, "shell", "am", "force-stop", args.package)
        adb(args, serial, "logcat", "-c")
        component = next(line for line in adb(args, serial, "shell", "cmd", "package", "resolve-activity", "--brief", args.package).splitlines()
                         if line.startswith(args.package + "/"))
        report["system_before"] = system(args, serial, args.package)
        started = time.monotonic()
        adb(args, serial, "shell", "am", "start", "-W", "-n", component)
        samples, rows = [], []
        while time.monotonic() - started < args.timeout:
            time.sleep(5)
            raw = adb(args, serial, "exec-out", "run-as", args.package, "cat", trace, raw=True, check=False)
            complete = raw[:raw.rfind(b"\n") + 1]
            rows = [json.loads(line) for line in complete.splitlines() if line.strip().startswith(b"{")]
            samples.append(system(args, serial, args.package))
            if rows and rows[-1].get("event") in ("done", "error"):
                break
        report["wall_seconds"] = round(time.monotonic() - started, 1)
        (args.output / "frames.jsonl").write_bytes(b"\n".join(json.dumps(r).encode() for r in rows) + b"\n")
        report["system_samples"] = samples
        report["logcat_bench"] = [line for line in adb(args, serial, "logcat", "-d", check=False).splitlines() if "IMPERATHEN_RENDER_BENCH" in line]
        views = [r for r in rows if r.get("event") == "view"]
        report["views"] = [{"quality": r["quality"], "view": r["view"], **{k: r["metrics"].get(k) for k in (
            "wall_ms_p50", "wall_ms_p95", "render_gpu_ms_p50", "render_cpu_ms_p50", "draw_calls", "primitives",
            "video_mib", "texture_mib", "rss_mib", "render_scale")}, "renderer": r["metrics"]["engine"]["renderer"]} for r in views]
        report["status"] = "passed" if rows and rows[-1].get("event") == "done" and len(views) == 16 else "incomplete"
        adb(args, serial, "shell", "run-as", args.package, "rm", "-f", flag, check=False)
    except Exception as exc:  # report what failed instead of partial claims
        report["error"] = str(exc)
    (args.output / "report.json").write_text(json.dumps(report, indent=1) + "\n")
    print("FOLD7_RENDER_BENCH", report["status"], report.get("error", ""))
    return 0 if report["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
