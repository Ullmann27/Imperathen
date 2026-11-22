"""Run the exported graphics probe on a verified disposable Android emulator."""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
import time

from android_runtime_smoke import runtime_error_lines


PACKAGE = "at.heinz.imperathen"
PROFILES = ("low", "balanced", "high", "very_high")


def distribution(values):
    ordered = sorted(v for v in values if isinstance(v, (int, float)) and math.isfinite(v))
    if not ordered:
        return None
    return {"count": len(ordered), **{f"p{percent}": ordered[math.ceil(percent * len(ordered) / 100) - 1]
                                    for percent in (50, 95, 99)}, "max": ordered[-1]}


def match_number(pattern, text):
    match = re.search(pattern, text, re.MULTILINE)
    return float(match.group(1)) if match else None


def system_sample(adb):
    thermal = adb("shell", "dumpsys", "thermalservice")
    battery = adb("shell", "dumpsys", "battery")
    memory = adb("shell", "dumpsys", "meminfo", PACKAGE)
    return {"host_monotonic_s": time.monotonic(), "pss_kib": match_number(r"TOTAL PSS:\s*([0-9]+)", memory),
            "rss_kib": match_number(r"TOTAL RSS:\s*([0-9]+)", memory),
            "thermal_status": match_number(r"Thermal (?:Status|status):\s*(\d+)", thermal),
            "temperature_sensor_readings": re.findall(r"Temperature\{[^}]+}", thermal) or None,
            "battery_tenths_c": match_number(r"^\s*temperature:\s*(-?\d+)", battery),
            "battery_level": match_number(r"^\s*level:\s*(\d+)", battery),
            "battery_scale": match_number(r"^\s*scale:\s*(\d+)", battery),
            "raw": {"thermalservice": thermal, "battery": battery, "meminfo": memory}}


def summarize(rows, system, budgets):
    result = {}
    previous_steps = 0
    for profile in PROFILES:
        phase = [r for r in rows if r.get("quality") == profile]
        end, = [r for r in phase if r["event"] == "phase_end"]
        frames = [v for r in phase if r["event"] == "frames" for v in r["rows"]]
        samples = [r["metrics"] for r in phase if r["event"] == "sample"]
        system_rows = [r for r in system if r.get("quality") == profile]
        if (end["active_usec"] < 300_000_000 or end["wall_usec"] < end["active_usec"]
                or end["total_steps"] <= previous_steps or not frames or not samples or not system_rows):
            raise RuntimeError("Incomplete real-time gameplay phase " + profile)
        if abs(sum(f[0] for f in frames) * 1000 - end["active_usec"]) > 1000:
            raise RuntimeError("Frame timings do not account for active duration " + profile)
        graphics = {key: distribution(s[key] for s in samples) for key in samples[0]}
        graphics["process_pss_mib"] = distribution(r["pss_kib"] / 1024 for r in system_rows if r["pss_kib"] is not None)
        result[profile] = {"active_seconds": end["active_usec"] / 1e6, "wall_seconds": end["wall_usec"] / 1e6,
                           "advanced_steps": end["total_steps"] - previous_steps, "frames": len(frames),
                           "mean_fps": len(frames) * 1e6 / end["active_usec"],
                           "frame_ms": distribution(f[0] for f in frames),
                           "render_cpu_ms": distribution(f[1] for f in frames),
                           "render_gpu_ms": distribution(f[2] for f in frames), "counters": graphics,
                           "system": {k: distribution(r[k] for r in system_rows) for k in
                                      ("pss_kib", "rss_kib", "thermal_status", "battery_tenths_c", "battery_level")},
                           "review_limits": budgets[profile]["review_limits"],
                           "over_limit_at_peak": [key for key, cap in budgets[profile]["review_limits"].items()
                                                  if graphics.get(key) and graphics[key]["max"] > cap]}
        previous_steps = end["total_steps"]
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--adb", required=True)
    parser.add_argument("--apk", required=True, type=Path)
    parser.add_argument("--abi", choices=("x86_64", "arm64-v8a"), default="x86_64")
    parser.add_argument("--mode", choices=("soak", "renderer"), required=True)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    report = {"status": "failed", "source_commit": os.getenv("GITHUB_SHA"), "apk": args.apk.name,
              "sha256": hashlib.sha256(args.apk.read_bytes()).hexdigest(), "mode": args.mode,
              "physical_device": False, "limits": "Virtual sensors and software GPU; null means unavailable. "
              "Render timings are Godot viewport counters. Visible primitives include non-triangles. "
              "Buffer memory is graphics buffers, not only meshes. Per-frame percentiles use nearest rank."}
    serial = ""
    samples = []

    def adb(*parts, check=True, raw=False, input_bytes=None):
        result = subprocess.run([args.adb, "-s", serial, *parts], capture_output=True, input=input_bytes, timeout=100)
        if check and result.returncode:
            raise RuntimeError("adb " + " ".join(parts[:4]) + ": " + result.stderr.decode(errors="replace"))
        return result.stdout if raw else result.stdout.decode(errors="replace").strip()

    def write_json(name, obj):
        (args.output / name).write_text(json.dumps(obj, indent=2, ensure_ascii=False) + "\n")

    try:
        targets = subprocess.check_output([args.adb, "devices"], text=True).splitlines()[1:]
        valid = [line.split()[0] for line in targets if line.split()]
        if len(valid) != 1 or not valid[0].startswith("emulator-"):
            raise RuntimeError("Disposable emulator required")
        serial = valid[0]
        if adb("shell", "getprop", "ro.kernel.qemu") != "1":
            raise RuntimeError("Unexpected target")
        report["api"] = adb("shell", "getprop", "ro.build.version.sdk")
        report["device_abis"] = adb("shell", "getprop", "ro.product.cpu.abilist")
        report["vulkan_features"] = [line for line in adb("shell", "pm", "list", "features").splitlines() if "vulkan" in line]
        if args.abi not in report["device_abis"].split(","):
            if args.mode == "renderer" and args.abi == "arm64-v8a":
                report.update(status="unavailable", reason="Emulator does not advertise ARM64 translation")
                return
            raise RuntimeError("Requested ABI unavailable")
        adb("shell", "am", "force-stop", PACKAGE)
        if "Success" not in adb("install", "-r", "-t", "--abi", args.abi, str(args.apk)):
            raise RuntimeError("Installation failed")
        info = adb("shell", "dumpsys", "package", PACKAGE)
        report["selected_abi"] = args.abi
        report["translated"] = args.abi != adb("shell", "getprop", "ro.product.cpu.abi")
        if not re.search(r"primaryCpuAbi=" + re.escape(args.abi) + r"\b", info):
            raise RuntimeError("PackageManager selected the wrong ABI")
        paths = adb("shell", "run-as", PACKAGE, "find", "files", "-name", "imperathen_campaign.json").splitlines()
        if len(paths) != 1 or not paths[0].startswith("files/"):
            raise RuntimeError("Saved campaign from the preceding Android smoke is required")
        folder = PurePosixPath(paths[0]).parent
        flag = str(folder / "graphics-probe.txt")
        trace = str(folder / "graphics-frames.jsonl")
        adb("shell", "run-as", PACKAGE, "rm", "-f", trace)
        adb("shell", "run-as", PACKAGE, "tee", flag, input_bytes=(args.mode + "\n").encode())
        # Fixed native benchmark viewport. Fold-style resizing is covered separately by the smoke.
        adb("shell", "wm", "size", "540x960")
        adb("shell", "settings", "put", "system", "screen_off_timeout", "3600000")
        component = next(line for line in adb("shell", "cmd", "package", "resolve-activity", "--brief", PACKAGE).splitlines()
                         if line.startswith(PACKAGE + "/"))
        adb("logcat", "-c")
        start = time.monotonic()
        launched = adb("shell", "am", "start", "-W", "-n", component)
        if "Status: ok" not in launched:
            raise RuntimeError("Could not launch the installed APK")
        deadline = start + (1600 if args.mode == "soak" else 150)
        while time.monotonic() < deadline:
            # exec-out combines stdout and stderr on some platform-tools versions.
            # Wait for the engine to create its trace before parsing any bytes as JSON.
            raw = b""
            if adb("shell", "run-as", PACKAGE, "ls", trace, check=False) == trace:
                raw = adb("exec-out", "run-as", PACKAGE, "cat", trace, raw=True)
            complete = raw[:raw.rfind(b"\n") + 1]
            if complete:
                (args.output / "frames.jsonl").write_bytes(complete)
            rows = [json.loads(line) for line in complete.splitlines()]
            if any(r["event"] == "error" for r in rows):
                raise RuntimeError(str(rows[-1]))
            quality = next((r["quality"] for r in reversed(rows) if r["event"] == "sample"), None)
            item = system_sample(adb)
            item["quality"] = quality
            samples.append(item)
            write_json("system.json", samples)
            if rows and rows[-1]["event"] == "done":
                break
            if time.monotonic() - start > 75 and not adb("shell", "pidof", PACKAGE, check=False):
                raise RuntimeError("The game process exited")
            if args.mode == "soak":
                marker = next((r["elapsed_usec"] for r in reversed(rows) if r["event"] == "sample"), None)
                item["last_sample"] = marker
                if time.monotonic() - start > 180 and len(samples) >= 5:
                    if all(s.get("last_sample") == marker for s in samples[-5:]):
                        raise RuntimeError("No recent unpaused gameplay sample")
            time.sleep(12 if args.mode == "soak" else 3)
        else:
            raise RuntimeError("Graphics probe timed out")
        report["wall_seconds"] = time.monotonic() - start
        report["device"] = next(r for r in rows if r["event"] == "device")
        report["village_profiles"] = [r for r in rows if r["event"] == "village_profile"]
        if ([r["quality"] for r in report["village_profiles"]] != list(PROFILES)
                or any(not r["visible"] for r in report["village_profiles"])):
            raise RuntimeError("Village did not render all four profiles")
        if report["device"]["architecture"] != {"x86_64":"x86_64", "arm64-v8a":"arm64"}[args.abi]:
            raise RuntimeError("Unexpected Godot runtime architecture")
        if args.mode == "soak":
            budgets = json.loads((Path(__file__).resolve().parents[1] / "prototype/assets/quality_profiles.json").read_text())["profiles"]
            report["phases"] = summarize(rows, samples, budgets)
            if report["wall_seconds"] < 1200 or report["device"]["method"] != "gl_compatibility":
                raise RuntimeError("Compatibility gameplay duration or renderer mismatch")
        else:
            report["vulkan_mobile_verified"] = report["device"]["method"] == "mobile" and report["device"]["driver"].lower() == "vulkan"
            if not report["vulkan_mobile_verified"] and report["device"]["method"] != "gl_compatibility":
                raise RuntimeError("Unrecognized actual renderer")
        pid = adb("shell", "pidof", PACKAGE)
        log = adb("logcat", "-d", "--pid", pid)
        if runtime_error_lines(log):
            raise RuntimeError("Godot reported errors: " + str(runtime_error_lines(log)[:8]))
        png = adb("exec-out", "screencap", "-p", raw=True)
        if not png.startswith(b"\x89PNG"):
            raise RuntimeError("No rendered screenshot")
        (args.output / "screen.png").write_bytes(png)
        report["status"] = "passed"
    except Exception as exc:
        report["error"] = str(exc)
    finally:
        if serial:
            (args.output / "logcat.txt").write_text(adb("logcat", "-d", "-t", "2200", check=False))
            if "flag" in locals():
                adb("shell", "run-as", PACKAGE, "rm", "-f", flag, check=False)
        write_json("report.json", report)
    if report["status"] != "passed":
        raise SystemExit(report.get("error", "Benchmark failed"))
    print(args.mode, report["status"], report["device"], round(report["wall_seconds"], 2))


if __name__ == "__main__":
    main()
