#!/usr/bin/env python3
"""Perform a real 20-minute IMPERATHEN Fold7 ADB soak on a connected phone.

This tool will NOT connect to an emulator or silently install an incompatible
APK. It requires the actual installed, foreground Android app and a USB/Wi-Fi
ADB session explicitly authorized by its owner. No fake FPS/thermal values.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
import subprocess
import time
from pathlib import Path
from statistics import median

PACKAGE = "at.heinz.imperathen"
MIN_SECONDS = 1200
SAMPLE_MARKER = "IMPERATHEN_DISPLAY_SAMPLE "
WANTED_PROFILES = ("high", "very_high")


def shell(adb: str, serial: str, *args: str, timeout: int = 35) -> str:
    result = subprocess.run([adb, "-s", serial, *args], capture_output=True, text=True,
                            timeout=timeout, check=False)
    if result.returncode != 0:
        raise RuntimeError("ADB failed: " + " ".join(args[:3]) + ": " +
                           result.stderr.strip()[:500])
    return result.stdout.strip()


def number(pattern: str, text: str):
    found = re.search(pattern, text, re.MULTILINE)
    return float(found.group(1)) if found else None


def percentile(values: list[float], p: int):
    usable = sorted(v for v in values if isinstance(v, (int,float)) and math.isfinite(v))
    return usable[math.ceil(len(usable)*p/100)-1] if usable else None


def collect_device(adb: str, serial: str):
    battery = shell(adb, serial, "shell", "dumpsys", "battery")
    thermal = shell(adb, serial, "shell", "dumpsys", "thermalservice")
    memory = shell(adb, serial, "shell", "dumpsys", "meminfo", PACKAGE)
    return {
        "time_monotonic_s": time.monotonic(),
        "battery_tenths_c": number(r"^\s*temperature:\s*(-?\d+)", battery),
        "battery_percent": number(r"^\s*level:\s*(\d+)", battery),
        "android_thermal_status": number(r"Thermal (?:Status|status):\s*(\d+)", thermal),
        "temperature_sensor_readings": re.findall(r"Temperature\{[^}]+\}", thermal) or None,
        "process_pss_kib": number(r"TOTAL PSS:\s*(\d+)", memory),
        "process_rss_kib": number(r"TOTAL RSS:\s*(\d+)", memory),
        "note": "Battery sensor is not GPU die temperature. Missing thermalservice values stay null.",
    }


def from_log(log: str) -> list[dict]:
    rows = []
    for line in log.splitlines():
        if SAMPLE_MARKER not in line:
            continue
        payload = line.split(SAMPLE_MARKER,1)[1].strip()
        try:
            data = json.loads(payload)
        except json.JSONDecodeError:
            continue
        if isinstance(data,dict) and all(field in data for field in
                                         ("quality","mean_frame_ms","fps","frame_p95_ms")):
            rows.append(data)
    return rows


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--adb",default="adb")
    parser.add_argument("--serial",required=True,help="Explicitly chosen physical Fold7 ADB serial")
    parser.add_argument("--profile",choices=WANTED_PROFILES,required=True)
    parser.add_argument("--output",type=Path,required=True)
    parser.add_argument("--seconds",type=int,default=MIN_SECONDS)
    args = parser.parse_args()
    if args.seconds < MIN_SECONDS:
        parser.error("A physical Fold7 acceptance requires at least 1200 real seconds.")
    args.output.mkdir(parents=True,exist_ok=True)
    report = {"status":"not_completed","physical_device":False,"required_duration_s":args.seconds,
              "expected_model":"SM-F966B","game_package":PACKAGE,"requested_profile":args.profile,
              "gpu_temp_claimed":False}
    (args.output/"README.txt").write_text(
        "Start IMPERATHEN, choose the requested graphics profile and walk through "
        "the real Roman city for 20 minutes. This script never installs/uninstalls "
        "an APK or changes saved user data. Android battery temperature is not "
        "equivalent to GPU die temperature.\n", encoding="utf-8")
    started = time.monotonic()
    frames = {}
    physical = []
    try:
        devices = shell(args.adb,args.serial,"devices","-l")
        if args.serial not in devices:
            raise RuntimeError("ADB selected serial is not connected/authorized.")
        if shell(args.adb,args.serial,"shell","getprop","ro.kernel.qemu") == "1":
            raise RuntimeError("Emulator is not a physical Fold7.")
        model = shell(args.adb,args.serial,"shell","getprop","ro.product.model")
        if "SM-F966" not in model.upper():
            raise RuntimeError("Android model is not the expected Fold7 model; received " + repr(model))
        report.update(physical_device=True,actual_model=model,
                      android_release=shell(args.adb,args.serial,"shell","getprop","ro.build.version.release"))
        initial_pid = shell(args.adb,args.serial,"shell","pidof",PACKAGE)
        if not initial_pid or " " in initial_pid:
            raise RuntimeError("Run exactly one foreground IMPERATHEN application process.")
        foreground = shell(args.adb,args.serial,"shell","dumpsys","window","windows")
        if PACKAGE not in foreground:
            raise RuntimeError("IMPERATHEN is not visible in the current Android windows.")
        # Do not clear the logcat history: this utility is strictly read-only
        # apart from its own local output files.
        deadline = started + args.seconds
        next_checkpoint = started
        while time.monotonic() < deadline:
            pid = shell(args.adb,args.serial,"shell","pidof",PACKAGE)
            if pid != initial_pid:
                raise RuntimeError("Game exited or changed process; duration is not continuous.")
            now = time.monotonic()
            if now >= next_checkpoint:
                sample = collect_device(args.adb,args.serial)
                physical.append(sample)
                (args.output/"android_system.json").write_text(json.dumps(physical,indent=2,ensure_ascii=False)+"\n")
                next_checkpoint = now + 12
            log = shell(args.adb,args.serial,"logcat","-d","-v","raw","--pid",initial_pid,timeout=55)
            for row in from_log(log):
                timestamp = row.get("device_monotonic_ms")
                if timestamp is None or not isinstance(timestamp,(int,float)):
                    continue
                frames[int(timestamp)] = row
            if len(frames)>2000:
                frames = dict(sorted(frames.items())[-1600:])
            (args.output/"frames.jsonl").write_text(
                "\n".join(json.dumps(v,ensure_ascii=False) for _,v in sorted(frames.items())) + "\n")
            time.sleep(min(7,max(0,deadline-time.monotonic())))
        elapsed = time.monotonic()-started
        valid = [v for v in frames.values() if v.get("quality")==args.profile
                 and isinstance(v.get("fps"),(int,float)) and v["fps"]>0]
        if elapsed<MIN_SECONDS or len(valid)<int(MIN_SECONDS*.65):
            raise RuntimeError("Not enough uninterrupted, real-foreground frame samples.")
        if any(v.get("renderer") != "gl_compatibility" for v in valid):
            raise RuntimeError("Unexpected renderer in physical Fold7 session.")
        p95 = [float(v["frame_p95_ms"]) for v in valid if isinstance(v.get("frame_p95_ms"),(int,float))]
        report.update(status="measured",duration_wall_s=elapsed,frame_samples=len(valid),
                      frames_per_second={"p50":percentile([float(v["fps"]) for v in valid],50),
                                         "p95":percentile([float(v["fps"]) for v in valid],95)},
                      frame_p95_ms={"p50":percentile(p95,50),"p95":percentile(p95,95),"p99":percentile(p95,99)},
                      dynamic_resolution_min=min(float(v.get("scale_3d",1)) for v in valid),
                      thermal_sample_count=len(physical),
                      battery_tenths_c={
                          "first":physical[0]["battery_tenths_c"] if physical else None,
                          "last":physical[-1]["battery_tenths_c"] if physical else None},
                      gpu_timing_samples=sum(v.get("render_gpu_ms") is not None for v in valid),
                      source_note="Read from explicitly connected physical Fold7 ADB session; no simulated timestamps")
        if report["frame_p95_ms"]["p95"] is None:
            raise RuntimeError("Missing P95 frame-time source values.")
    except Exception as exc:
        report.update(status="failed",error=str(exc),duration_wall_s=time.monotonic()-started)
    (args.output/"report.json").write_text(json.dumps(report,indent=2,ensure_ascii=False)+"\n")
    print("FOLD7_PHYSICAL_RESULT "+json.dumps(report,ensure_ascii=False))
    return 0 if report["status"]=="measured" else 1


if __name__=="__main__":
    raise SystemExit(main())
