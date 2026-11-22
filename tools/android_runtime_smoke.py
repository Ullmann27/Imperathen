"""Install and exercise the actual APK on one disposable Android emulator.

This is an Android runtime check, not evidence about a physical ARM64 phone.
Physical devices and ambiguous ADB targets are refused. The verified emulator's
test-app data is cleared after installation so repeated runs start from one state.
It waits for the real menu geometry logged by a debug build and taps that actual
button. Screenshots and logcat remain inspectable; errors never become fake passes.
"""

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import time


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--adb", required=True)
    parser.add_argument("--apk", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    package = "at.heinz.imperathen"
    report = {"platform": "Android emulator", "apk_sha256": hashlib.sha256(args.apk.read_bytes()).hexdigest(), "physical_device_test": False,
              "arm64_runtime_test": False, "status": "failed", "checks": [], "errors": []}
    serial = ""
    verified_emulator = False

    def adb(*parts, binary=False, timeout=30, checked=True):
        if not serial:
            raise RuntimeError("No unambiguous emulator target selected")
        result = subprocess.run([args.adb, "-s", serial, *parts], capture_output=True, timeout=timeout)
        if checked and result.returncode:
            raise RuntimeError("adb command failed: " + " ".join(parts[:3]) + ": " + result.stderr.decode(errors="replace"))
        return result.stdout if binary else result.stdout.decode(errors="replace").strip()

    def record(name, passed, detail):
        report["checks"].append({"name": name, "passed": bool(passed), "detail": detail})
        if not passed:
            raise RuntimeError(name + ": " + str(detail))

    def logs():
        return adb("logcat", "-d", "--pid", report["pid"], timeout=20)

    def screenshot(name):
        data = adb("exec-out", "screencap", "-p", binary=True)
        if not data.startswith(b"\x89PNG\r\n\x1a\n"):
            raise RuntimeError("Invalid screenshot bytes")
        (args.output / name).write_bytes(data)

    try:
        inventory_deadline = time.monotonic() + 110
        targets = []
        while time.monotonic() < inventory_deadline:
            inventory = subprocess.run([args.adb, "devices"], capture_output=True, timeout=15)
            if inventory.returncode:
                raise RuntimeError("adb devices failed: " + inventory.stderr.decode(errors="replace"))
            targets = []
            for line in inventory.stdout.decode(errors="replace").splitlines():
                fields = line.split()
                if len(fields) >= 2 and fields[0] != "List":
                    targets.append({"serial": fields[0], "state": fields[1]})
            if targets:
                break
            time.sleep(2)
        record("single_emulator_target", len(targets) == 1
               and targets[0]["serial"].startswith("emulator-")
               and targets[0]["state"] in {"device", "offline"}, targets)
        serial = targets[0]["serial"]
        report["serial"] = serial
        adb("wait-for-device", timeout=60)
        emulator_flag = adb("shell", "getprop", "ro.kernel.qemu")
        record("emulator_verified", emulator_flag == "1", {"serial": serial, "ro.kernel.qemu": emulator_flag})
        verified_emulator = True
        deadline = time.monotonic() + 300
        while time.monotonic() < deadline:
            if adb("shell", "getprop", "sys.boot_completed", checked=False, timeout=10) == "1":
                break
            time.sleep(3)
        else:
            raise RuntimeError("Android emulator did not complete boot within 300 seconds")
        report["android_version"] = adb("shell", "getprop", "ro.build.version.release")
        report["api_level"] = adb("shell", "getprop", "ro.build.version.sdk")
        report["abi"] = adb("shell", "getprop", "ro.product.cpu.abi")
        report["model"] = adb("shell", "getprop", "ro.product.model")
        record("android_17_emulator", report["api_level"] == "37" and report["abi"] == "x86_64", {
            "api_level": report["api_level"], "abi": report["abi"], "model": report["model"]})
        adb("shell", "wm", "size", "720x1280")
        adb("shell", "wm", "density", "160")
        adb("shell", "input", "keyevent", "82")
        installed = adb("install", "-r", "-t", str(args.apk.resolve()), timeout=90)
        record("apk_install", "Success" in installed, installed)
        cleared = adb("shell", "pm", "clear", package)
        record("clean_test_app_data", cleared == "Success", cleared)
        activity = adb("shell", "cmd", "package", "resolve-activity", "--brief", package)
        component = next((line.strip() for line in activity.splitlines() if line.startswith(package + "/")), "")
        record("launcher", bool(component), component)
        adb("logcat", "-c")
        launched = adb("shell", "am", "start", "-W", "-n", component, timeout=40)
        record("activity_launch", "Status: ok" in launched, launched)
        time.sleep(2)
        pid = adb("shell", "pidof", package)
        record("process_started", pid.isdigit(), pid)
        report["pid"] = pid
        menu = None
        deadline = time.monotonic() + 45
        while time.monotonic() < deadline:
            text = logs()
            for line in text.splitlines():
                if "IMPERATHEN_MENU_READY " in line:
                    menu = json.loads(line.split("IMPERATHEN_MENU_READY ", 1)[1])
            if menu:
                break
            time.sleep(2)
        record("real_menu", menu is not None, menu)
        screenshot("01_android_menu.png")
        point = menu["new_game"]
        adb("shell", "input", "tap", str(round(point[0])), str(round(point[1])))
        deadline = time.monotonic() + 30
        while time.monotonic() < deadline and "IMPERATHEN_SESSION_STARTED" not in logs():
            time.sleep(2)
        record("touch_starts_saved_game", "IMPERATHEN_SESSION_STARTED" in logs(), "Tapped real menu button; main confirmed the new saved world")
        time.sleep(3)
        screenshot("02_android_world.png")
        adb("shell", "input", "keyevent", "4")
        time.sleep(1)
        record("android_back_pauses", "IMPERATHEN_PAUSED" in logs() and adb("shell", "pidof", package) == pid, "Back opened pause without terminating the app")
        screenshot("03_android_pause.png")
        adb("shell", "input", "keyevent", "3")
        time.sleep(1)
        adb("shell", "am", "start", "-W", "-n", component)
        time.sleep(2)
        record("background_resume", adb("shell", "pidof", package) == pid, "Process survived Home and return")
        final_log = logs()
        errors = [line for line in final_log.splitlines() if re.search(r"SCRIPT ERROR:|Parse Error:|FATAL EXCEPTION|Fatal signal|ERROR:.*res://", line)]
        record("no_runtime_script_crash", not errors, errors)
        report["status"] = "passed"
    except (RuntimeError, subprocess.TimeoutExpired, json.JSONDecodeError, OSError) as error:
        report["errors"].append(str(error))
    finally:
        try:
            if verified_emulator:
                (args.output / "logcat.txt").write_text(logs() if "pid" in report else adb("logcat", "-d", checked=False), encoding="utf-8")
        except (OSError, subprocess.TimeoutExpired, RuntimeError):
            pass
        (args.output / "runtime-report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    raise SystemExit(0 if report["status"] == "passed" else 1)


if __name__ == "__main__":
    main()
