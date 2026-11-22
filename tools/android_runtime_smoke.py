"""Install and exercise the actual APK on one disposable Android emulator.

This is an Android runtime check, not evidence about a physical ARM64 phone.
Physical devices and ambiguous ADB targets are refused. The verified emulator's
test-app data is cleared after installation so repeated runs start from one state.
It waits for the real menu geometry logged by a debug build and taps that actual
button. Screenshots and logcat remain inspectable; errors never become fake passes.
"""

import argparse
import hashlib
import os
import json
from pathlib import Path
import re
import subprocess
import time
import xml.etree.ElementTree as ET


def runtime_error_lines(text):
    pattern = re.compile(
        r"SCRIPT ERROR:|Parse Error:|FATAL EXCEPTION|Fatal signal|"
        r"\bgodot(?:\(\s*\d+\))?\s*:\s*ERROR:|ERROR:.*res://", re.IGNORECASE)
    return [line for line in text.splitlines() if pattern.search(line)]


def fullscreen_hint_nodes(hierarchy):
    nodes = [node for node in hierarchy.iter("node")
             if node.get("package") == "com.android.systemui"]
    hint = any(node.get("text", "").strip().casefold() == "viewing full screen" for node in nodes)
    buttons = [node for node in nodes if node.get("text", "").strip().casefold() == "got it"
               and node.get("clickable") == "true" and node.get("enabled") == "true"]
    return hint, buttons


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--adb", required=True)
    parser.add_argument("--apk", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    with args.apk.open("rb") as source:
        apk_sha256 = hashlib.file_digest(source, "sha256").hexdigest()
    package = "at.heinz.imperathen"
    report = {"platform": "Android API 35 x86_64 emulator", "physical_device_test": False,
              "arm64_runtime_test": False, "apk_file": args.apk.name, "apk_sha256": apk_sha256,
              "source_commit": os.environ.get("GITHUB_SHA"),
              "status": "failed", "checks": [], "errors": []}
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

    def checked_logs():
        text = logs()
        errors = runtime_error_lines(text)
        if errors:
            record("no_runtime_errors", False, errors)
        return text

    def screenshot(name):
        data = adb("exec-out", "screencap", "-p", binary=True)
        if not data.startswith(b"\x89PNG\r\n\x1a\n"):
            raise RuntimeError("Invalid screenshot bytes")
        (args.output / name).write_bytes(data)

    def ui_hierarchy(stage):
        if not verified_emulator:
            raise RuntimeError("System UI inspection requires a verified disposable emulator")
        remote = "/sdcard/imperathen-runtime-ui.xml"
        adb("shell", "rm", "-f", remote)
        dumped = adb("shell", "uiautomator", "dump", "--compressed", remote, timeout=30)
        xml = adb("shell", "cat", remote)
        (args.output / (stage + "_ui.xml")).write_text(xml + "\n", encoding="utf-8")
        hierarchy = ET.fromstring(xml)
        if hierarchy.tag != "hierarchy":
            raise RuntimeError("UIAutomator did not return a window hierarchy: " + dumped)
        return hierarchy

    def dismiss_fullscreen_hint(stage):
        hierarchy = ui_hierarchy(stage + "_before")
        hint, buttons = fullscreen_hint_nodes(hierarchy)
        if not hint:
            report["checks"].append({"name": stage + "_system_fullscreen_hint_absent", "passed": True,
                                     "detail": {"xml": stage + "_before_ui.xml", "clicked": False}})
            return
        record(stage + "_system_fullscreen_button", len(buttons) == 1,
               {"matching_enabled_buttons": len(buttons), "xml": stage + "_before_ui.xml"})
        button = buttons[0]
        bounds = re.fullmatch(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", button.get("bounds", ""))
        if not bounds:
            raise RuntimeError("Observed SystemUI button has no usable bounds")
        left, top, right, bottom = map(int, bounds.groups())
        record(stage + "_system_fullscreen_bounds", right > left and bottom > top,
               {"package": button.get("package"), "text": button.get("text"),
                "resource_id": button.get("resource-id"), "bounds": button.get("bounds")})
        # Coordinates come only from the current, verified SystemUI hierarchy.
        adb("shell", "input", "tap", str((left + right) // 2), str((top + bottom) // 2))
        time.sleep(1)
        still_present, _ = fullscreen_hint_nodes(ui_hierarchy(stage + "_after"))
        record(stage + "_system_fullscreen_hint_dismissed", not still_present,
               {"before_xml": stage + "_before_ui.xml", "after_xml": stage + "_after_ui.xml"})

    try:
        inventory_deadline = time.monotonic() + 60
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
        adb("shell", "wm", "size", "1280x720")
        adb("shell", "wm", "density", "160")
        adb("shell", "input", "keyevent", "82")
        installed = adb("install", "-r", "-t", str(args.apk.resolve()), timeout=90)
        record("apk_install", "Success" in installed, installed)
        cleared = adb("shell", "pm", "clear", package)
        record("clean_test_app_data", cleared == "Success", cleared)
        activity = adb("shell", "cmd", "package", "resolve-activity", "--brief",
                       "-a", "android.intent.action.MAIN", "-c", "android.intent.category.LAUNCHER", package)
        component = next((line.strip() for line in activity.splitlines() if line.startswith(package + "/")), "")
        record("launcher", bool(component), component)
        adb("logcat", "-c")
        launched = adb("shell", "am", "start", "-W", "-n", component, timeout=40)
        record("activity_launch", "Status: ok" in launched, launched)
        time.sleep(2)
        pid = adb("shell", "pidof", package)
        record("process_started", pid.isdigit(), pid)
        report["pid"] = pid
        ready_started = time.monotonic()
        deadline = ready_started + 120
        ready = False
        while time.monotonic() < deadline:
            if "IMPERATHEN_READY:" in checked_logs():
                ready = True
                break
            time.sleep(2)
        record("godot_ready", ready, {"marker": "IMPERATHEN_READY", "deadline_seconds": 120,
                                       "elapsed_seconds": round(time.monotonic() - ready_started, 2)})
        # Dismiss Android's first-fullscreen overlay as soon as Godot has reached
        # the intro. Do not send Enter: the menu marker is logged after layout,
        # so a key intended for Skip could otherwise activate the new-game button.
        dismiss_fullscreen_hint("startup")
        menu = None
        menu_started = time.monotonic()
        deadline = menu_started + 120
        while time.monotonic() < deadline:
            text = checked_logs()
            for line in text.splitlines():
                if "IMPERATHEN_MENU_READY " in line:
                    menu = json.loads(line.split("IMPERATHEN_MENU_READY ", 1)[1])
            if menu:
                break
            time.sleep(2)
        record("real_menu", menu is not None,
               {"geometry": menu, "deadline_seconds": 120,
                "elapsed_seconds": round(time.monotonic() - menu_started, 2),
                "intro_transition": "automatic; no Enter key sent"})
        dismiss_fullscreen_hint("menu")
        screenshot("01_android_menu.png")
        point = menu["new_game"]
        adb("shell", "input", "tap", str(round(point[0])), str(round(point[1])))
        deadline = time.monotonic() + 30
        while time.monotonic() < deadline and "IMPERATHEN_SESSION_STARTED" not in checked_logs():
            time.sleep(2)
        record("touch_starts_saved_game", "IMPERATHEN_SESSION_STARTED" in checked_logs(), "Tapped real menu button; main confirmed the new saved world")
        time.sleep(3)
        dismiss_fullscreen_hint("world")
        screenshot("02_android_world.png")
        previous_pauses = checked_logs().count("IMPERATHEN_PAUSED")
        adb("shell", "input", "keyevent", "4")
        deadline = time.monotonic() + 20
        pause_observed = False
        while time.monotonic() < deadline:
            if checked_logs().count("IMPERATHEN_PAUSED") > previous_pauses:
                pause_observed = True
                break
            time.sleep(1)
        record("android_back_pauses", pause_observed and adb("shell", "pidof", package) == pid,
               {"new_pause_marker_after_Back": pause_observed, "deadline_seconds": 20,
                "detail": "Back must open a new pause without terminating the app"})
        screenshot("03_android_pause.png")
        adb("shell", "input", "keyevent", "3")
        time.sleep(1)
        adb("shell", "am", "start", "-W", "-n", component)
        time.sleep(2)
        record("background_resume", adb("shell", "pidof", package) == pid, "Process survived Home and return")
        final_log = logs()
        errors = runtime_error_lines(final_log)
        record("no_runtime_errors", not errors, errors)
        report["status"] = "passed"
    except (RuntimeError, subprocess.TimeoutExpired, json.JSONDecodeError, ET.ParseError, OSError) as error:
        report["errors"].append(str(error))
    finally:
        try:
            if verified_emulator:
                final_log = logs() if "pid" in report else adb("logcat", "-d", checked=False)
                (args.output / "logcat.txt").write_text(final_log, encoding="utf-8")
                errors = runtime_error_lines(final_log)
                if "pid" in report and not any(check["name"] == "no_runtime_errors" for check in report["checks"]):
                    report["checks"].append({"name": "no_runtime_errors", "passed": not errors, "detail": errors})
                if errors:
                    report["status"] = "failed"
                    report["errors"].append("Runtime error lines are present in logcat.txt; shader errors also block a PASS.")
        except (OSError, subprocess.TimeoutExpired, RuntimeError) as error:
            report.setdefault("diagnostic_errors", []).append("Log capture: " + str(error))
        if verified_emulator and report["status"] != "passed":
            try:
                screenshot("99_android_failure.png")
                report["failure_screenshot"] = "99_android_failure.png"
            except (OSError, subprocess.TimeoutExpired, RuntimeError) as error:
                report.setdefault("diagnostic_errors", []).append("Failure screenshot: " + str(error))
        (args.output / "runtime-report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    raise SystemExit(0 if report["status"] == "passed" else 1)


if __name__ == "__main__":
    main()
