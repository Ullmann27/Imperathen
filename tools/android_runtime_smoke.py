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
import os
from pathlib import Path, PurePosixPath
import re
import struct
import subprocess
import time
import xml.etree.ElementTree as ET
import zipfile


def runtime_error_lines(text):
    pattern = re.compile(
        r"SCRIPT ERROR:|Parse Error:|FATAL EXCEPTION|Fatal signal|"
        r"\bgodot(?:\(\s*\d+\))?\s*:\s*ERROR:|ERROR:.*res://", re.IGNORECASE)
    return [line for line in text.splitlines() if pattern.search(line)]


def fullscreen_hint_nodes(hierarchy):
    nodes = list(hierarchy.iter("node"))
    # API 35's observed immersive-cling window belongs to package "android".
    # A visible title must never be reported absent merely because its package
    # differs; an unrecognized button then fails explicitly instead of clicking.
    hint = any(node.get("resource-id") == "android:id/immersive_cling_title"
               or node.get("text", "").strip().casefold() == "viewing full screen" for node in nodes)
    buttons = [node for node in nodes if node.get("package") == "android"
               and node.get("resource-id") == "android:id/ok"
               and node.get("class") == "android.widget.Button"
               and node.get("text", "").strip().casefold() == "got it"
               and node.get("clickable") == "true" and node.get("enabled") == "true"]
    return hint, buttons


def launcher_anr_close_button(hierarchy):
    nodes = [node for node in hierarchy.iter("node") if node.get("package") == "android"]
    title = any(node.get("resource-id") == "android:id/alertTitle" and
                node.get("text", "").replace("’", "'") == "Pixel Launcher isn't responding" for node in nodes)
    buttons = [node for node in nodes if node.get("resource-id") == "android:id/aerr_close"
               and node.get("clickable") == "true" and node.get("enabled") == "true"]
    return buttons[0] if title and len(buttons) == 1 else None


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--adb", required=True)
    parser.add_argument("--apk", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--device-apk", type=Path, help="Also run the actual ARM64 download if the emulator supports translation")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    package = "at.heinz.imperathen"
    report = {"platform": "Android emulator", "apk_sha256": hashlib.sha256(args.apk.read_bytes()).hexdigest(), "physical_device_test": False,
              "arm64_runtime_test": False, "status": "failed", "checks": [], "errors": []}
    report["source_commit"] = os.environ.get("IMPERATHEN_APK_COMMIT", os.environ.get("GITHUB_SHA"))
    report["test_harness_commit"] = os.environ.get("GITHUB_SHA")
    report["apk_file"] = args.apk.name
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
        digest = hashlib.sha256(data).hexdigest()
        previous = report.setdefault("screenshots", {})
        # A system immersive-mode tutorial can cover every view with identical pixels.
        if name not in {"failure.png", "07_android_arm64_translated_intro.png"} and any(image["sha256"] == digest for image in previous.values()):
            raise RuntimeError("Screenshot repeats a previous screen: " + name)
        width, height = struct.unpack(">II", data[16:24])
        previous[name] = {"sha256": digest, "width": width, "height": height}

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
        launcher_button = launcher_anr_close_button(hierarchy)
        if launcher_button is not None:
            focus = adb("shell", "dumpsys", "window", "displays")
            launcher_focus = any("mCurrentFocus=" in line and "Application Not Responding: com.google.android.apps.nexuslauncher" in line for line in focus.splitlines())
            record(stage + "_stock_launcher_anr", launcher_focus, "Verified the system dialog belongs to the stock Pixel Launcher")
            coords = re.fullmatch(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", launcher_button.get("bounds", ""))
            if not coords:
                raise RuntimeError("Stock launcher dialog button has no screen bounds")
            x1, y1, x2, y2 = map(int, coords.groups())
            tap(((x1 + x2) / 2, (y1 + y2) / 2))
            time.sleep(1)
            hierarchy = ui_hierarchy(stage + "_launcher_closed")
            record(stage + "_stock_launcher_dialog_closed", launcher_anr_close_button(hierarchy) is None,
                   "Pressed Close app on the verified launcher ANR; the game process remains under test")
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

    def wait_marker(marker, timeout=80):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            for line in reversed(checked_logs().splitlines()):
                if marker in line:
                    return line.split(marker, 1)[1].strip()
            time.sleep(1)
        raise RuntimeError("Missing Android runtime marker " + marker)

    def wait_for_new_marker(marker, previous, timeout=60):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            text = checked_logs()
            if text.count(marker) > previous:
                return text.rsplit(marker, 1)[1].splitlines()[0].strip()
            time.sleep(1)
        raise RuntimeError("No new Android runtime marker " + marker)

    def tap(point):
        adb("shell", "input", "tap", str(round(point[0])), str(round(point[1])))

    def enable_diagnostics_for_emulator():
        # The clean test account has just saved via the real game. Locate its
        # actual data directory before enabling the same persisted UI preference.
        paths = adb("shell", "run-as", package, "find", "files", "-name", "imperathen_campaign.json").splitlines()
        paths = [PurePosixPath(value.strip()) for value in paths if value.strip().startswith("files/")]
        if len(paths) != 1:
            raise RuntimeError("Expected one campaign file in the disposable emulator app")
        settings_path = paths[0].with_name("imperathen_ui.cfg")
        written = subprocess.run([args.adb, "-s", serial, "shell", "run-as", package, "tee", str(settings_path)],
                                 input=b"[graphics]\ndiagnostics=true\n", capture_output=True, timeout=15)
        if written.returncode:
            raise RuntimeError("Unable to enable frame counters in emulator test preferences")

    def skip_intro(stage):
        wait_marker("IMPERATHEN_READY:", timeout=120)
        dismiss_fullscreen_hint(stage)
        point = json.loads(wait_marker("IMPERATHEN_INTRO_READY ", timeout=120))["skip"]
        if stage == "first_launch":
            screenshot("00_android_intro.png")
        if "IMPERATHEN_MENU_READY " not in logs():
            tap(point)

    def finish_first_day_opening():
        # Older release APKs have no in-world prologue. New builds expose actual
        # laid-out buttons; this test never substitutes guessed screen positions.
        if "IMPERATHEN_OPENING_STARTED first_day" not in checked_logs():
            return
        marker = "IMPERATHEN_OPENING_READY "
        opening = json.loads(wait_marker(marker))
        record("opening_before_gameplay", not opening["final"] and not opening["companion_choice"], opening)
        screenshot("10_android_opening.png")
        previous = checked_logs().count(marker)
        adb("shell", "input", "keyevent", "4")
        paused = json.loads(wait_for_new_marker(marker, previous))
        record("android_back_pauses_opening", paused["paused"] and paused["world_seconds"] == opening["world_seconds"], paused)
        previous = checked_logs().count(marker)
        adb("shell", "input", "keyevent", "4")
        resumed = json.loads(wait_for_new_marker(marker, previous))
        record("android_back_resumes_opening", not resumed["paused"], resumed)
        previous = checked_logs().count(marker)
        tap(resumed["buttons"]["OpeningSkip"])
        objective = json.loads(wait_for_new_marker(marker, previous))
        record("skip_keeps_first_objective", objective["final"] and not objective["companion_choice"], objective)
        screenshot("11_android_opening_objective.png")
        tap(objective["buttons"]["OpeningAdvance"])
        wait_marker("IMPERATHEN_OPENING_COMPLETE")
        record("objective_hands_over_control", True, "Actual touch accepted the objective after a separate skip action")

    def relaunch(diagnostics=False):
        previous = report["pid"]
        (args.output / ("logcat-" + previous + ".txt")).write_text(logs(), encoding="utf-8")
        adb("shell", "am", "force-stop", package)
        if diagnostics:
            enable_diagnostics_for_emulator()
        started = adb("shell", "am", "start", "-W", "-n", component, timeout=60)
        if "Status: ok" not in started:
            raise RuntimeError("Relaunch failed: " + started)
        deadline = time.monotonic() + 40
        while time.monotonic() < deadline:
            new_pid = adb("shell", "pidof", package, checked=False)
            if new_pid.isdigit() and new_pid != previous:
                report["pid"] = new_pid
                skip_intro("launch_" + new_pid)
                return json.loads(wait_marker("IMPERATHEN_MENU_TOUCH "))
            time.sleep(1)
        raise RuntimeError("Relaunch did not produce a new game process")

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
        record("expected_android_emulator", report["api_level"] == "35" and report["abi"] == "x86_64", {
            "api_level": report["api_level"], "abi": report["abi"], "model": report["model"]})
        adb("shell", "wm", "size", "540x960")
        adb("shell", "wm", "density", "160")
        adb("shell", "wm", "dismiss-keyguard")
        adb("shell", "settings", "put", "secure", "immersive_mode_confirmations", "confirmed")
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
        skip_intro("first_launch")
        menu = json.loads(wait_marker("IMPERATHEN_MENU_READY "))
        record("real_menu", "new_game" in menu, menu)
        dismiss_fullscreen_hint("menu")
        screenshot("01_android_menu.png")
        tap(menu["new_game"])
        wait_marker("IMPERATHEN_SESSION_STARTED")
        record("touch_starts_saved_game", True, "New game button produced a saved village")
        finish_first_day_opening()
        time.sleep(3)
        dismiss_fullscreen_hint("world")
        screenshot("02_android_world.png")
        previous_pauses = checked_logs().count("IMPERATHEN_PAUSED")
        adb("shell", "input", "keyevent", "4")
        deadline = time.monotonic() + 40
        while time.monotonic() < deadline and checked_logs().count("IMPERATHEN_PAUSED") <= previous_pauses:
            time.sleep(1)
        record("android_back_pauses", checked_logs().count("IMPERATHEN_PAUSED") > previous_pauses
               and adb("shell", "pidof", package) == pid, "Back opened a new pause without terminating the app")
        time.sleep(2)
        screenshot("03_android_pause.png")
        adb("shell", "input", "keyevent", "3")
        time.sleep(1)
        adb("shell", "am", "start", "-W", "-n", component)
        time.sleep(2)
        record("background_resume", adb("shell", "pidof", package) == pid, "Process survived Home and return")
        resumed_menu = relaunch()
        record("persistent_save_after_restart", resumed_menu["can_continue"], resumed_menu)
        tap(resumed_menu["continue"])
        wait_marker("IMPERATHEN_CONTINUED")
        record("continue_after_process_death", True, "Loaded the village in a new process")
        practice_menu = relaunch(diagnostics=True)
        tap(practice_menu["demo"])
        valley_ready = wait_marker("IMPERATHEN_VALLEY_READY")
        record("formation_valley", True, "Actual practice menu touch opened the valley scene")
        time.sleep(4)
        screenshot("04_android_valley.png")
        (args.output / "valley-meminfo.txt").write_text(adb("shell", "dumpsys", "meminfo", package), encoding="utf-8")
        # Older packages log only the ready marker. New debug packages also expose
        # the native screen position of Fortsetzen and the paused simulation step.
        if valley_ready:
            controls = json.loads(valley_ready)
            stride_marker = "IMPERATHEN_VALLEY_STRIDE "
            previous = checked_logs().count(stride_marker)
            tap(controls["resume"])
            stride = json.loads(wait_for_new_marker(stride_marker, previous))
            record("touch_advances_marching_soldier", stride["step"] > controls["step"] and
                   stride["meters"] > 0 and stride["pose"] in {"march", "run", "retreat"},
                   {"paused_step": controls["step"], **stride})
            time.sleep(2)
            screenshot("09_android_marching.png")
        # A square logical display exercises live fold-style resizing. The virtual
        # hardware remains an emulator and this does not measure a physical hinge.
        adb("shell", "wm", "size", "900x920")
        time.sleep(4)
        record("square_display_alive", adb("shell", "pidof", package) == report["pid"], adb("shell", "wm", "size"))
        screenshot("05_android_valley_square.png")
        scene_log = logs().split("IMPERATHEN_VALLEY_READY", 1)[-1]
        samples = [json.loads(line.split("IMPERATHEN_DISPLAY_SAMPLE ", 1)[1])
                   for line in scene_log.splitlines() if "IMPERATHEN_DISPLAY_SAMPLE " in line]
        report["valley_render_samples"] = samples
        record("measured_valley_frames", bool(samples), {"intervals": len(samples),
               "scope": "Software-rendered emulator; CPU/GPU values are latest renderer timings, frame time is an interval mean"})

        atlas_menu = relaunch()
        tap(atlas_menu["atlas"])
        wait_marker("IMPERATHEN_ATLAS_READY")
        time.sleep(2)
        screenshot("06_android_globe.png")
        record("world_globe", True, "Opened the playable globe through the main menu on a square display")
        with zipfile.ZipFile(args.apk) as package_zip:
            has_portraits = any(name.startswith("assets/assets/portraits/") for name in package_zip.namelist())
        if has_portraits:
            menu_marker = "IMPERATHEN_MENU_TOUCH "
            before_menu = checked_logs().count(menu_marker)
            adb("shell", "input", "keyevent", "4")
            gallery_menu = json.loads(wait_for_new_marker(menu_marker, before_menu))
            record("gallery_menu_action", "gallery" in gallery_menu, gallery_menu)
            dismiss_fullscreen_hint("gallery_menu")
            center = gallery_menu["gallery"]
            visible = gallery_menu.get("gallery_visible", False)
            extent = report["screenshots"]["06_android_globe.png"]
            scroll_marker = "IMPERATHEN_GALLERY_MENU_BUTTON "
            for _ in range(3):
                if visible:
                    break
                before_scroll = checked_logs().count(scroll_marker)
                x = str(round(extent["width"] * 0.25))
                adb("shell", "input", "swipe", x, str(round(extent["height"] * 0.8)),
                    x, str(round(extent["height"] * 0.3)), "400")
                button = json.loads(wait_for_new_marker(scroll_marker, before_scroll, timeout=15))
                center, visible = button["center"], button["visible"]
            record("gallery_button_visible", visible, center)
            tap(center)
            wait_marker("IMPERATHEN_GALLERY_OPEN menu")
            wait_marker("IMPERATHEN_GALLERY_PORTRAIT legionary")
            screenshot("08_android_figuren.png")
            record("real_portrait_loaded", True, "Tapped Figuren and rendered the legionary portrait from the exported game")
            before_menu = checked_logs().count(menu_marker)
            adb("shell", "input", "keyevent", "4")
            wait_marker("IMPERATHEN_GALLERY_CLOSED menu")
            wait_for_new_marker(menu_marker, before_menu)
            record("gallery_back_to_menu", True, "Android Back restored the menu")

        final_log = logs() + "\n" + "\n".join(path.read_text(encoding="utf-8") for path in args.output.glob("logcat-*.txt"))
        errors = runtime_error_lines(final_log)
        record("no_runtime_errors", not errors, errors)
        if args.device_apk:
            supported = adb("shell", "getprop", "ro.product.cpu.abilist").split(",")
            device_report = {"available_abis": supported, "sha256": hashlib.sha256(args.device_apk.read_bytes()).hexdigest(),
                             "name": args.device_apk.name, "status": "no_arm64_translation"}
            report["arm64_package"] = device_report
            if "arm64-v8a" in supported:
                # Only the verified disposable emulator is modified. Both ABI-specific
                # CI builds use the same private prototype key, so data survives.
                device_report["status"] = "attempted"
                (args.output / ("logcat-" + report["pid"] + ".txt")).write_text(logs(), encoding="utf-8")
                adb("shell", "am", "force-stop", package)
                install = adb("install", "-r", "-t", "--abi", "arm64-v8a", str(args.device_apk.resolve()), timeout=120)
                record("arm64_download_install", "Success" in install, install)
                info = adb("shell", "dumpsys", "package", package)
                record("arm64_selected", bool(re.search(r"primaryCpuAbi=arm64-v8a\b", info)), "PackageManager primaryCpuAbi")
                opened = adb("shell", "am", "start", "-W", "-n", component, timeout=90)
                record("arm64_activity_launch", "Status: ok" in opened, opened)
                report["pid"] = adb("shell", "pidof", package)
                wait_marker("IMPERATHEN_INTRO_READY ", timeout=140)
                screenshot("07_android_arm64_translated_intro.png")
                record("arm64_engine_running", True, "Godot rendered the new ARM64 process's intro control")
                record("arm64_no_runtime_errors", not runtime_error_lines(logs()), runtime_error_lines(logs()))
                device_report["status"] = "started_under_translation"
                report["arm64_runtime_test"] = True
        report["status"] = "passed"
    except (RuntimeError, subprocess.TimeoutExpired, json.JSONDecodeError, ET.ParseError, OSError) as error:
        report["errors"].append(str(error))
        if verified_emulator:
            try:
                focus = adb("shell", "dumpsys", "window", "displays", checked=False)
                report["focused_windows"] = [line.strip() for line in focus.splitlines() if "Focus" in line][:10]
                if "pid" in report:
                    diagnostics = [line for line in logs().splitlines() if any(tag in line for tag in (
                        "IMPERATHEN", "SCRIPT ERROR", "FATAL", "Godot", "BackInvoked", "BackDispatcher"))]
                    report["last_game_messages"] = diagnostics[-18:]
                screenshot("failure.png")
            except (RuntimeError, subprocess.TimeoutExpired, OSError):
                pass
    finally:
        try:
            if verified_emulator:
                (args.output / "logcat.txt").write_text(logs() if "pid" in report else adb("logcat", "-d", checked=False), encoding="utf-8")
        except (OSError, subprocess.TimeoutExpired, RuntimeError):
            report.setdefault("diagnostic_errors", []).append("Unable to capture final logcat")
        (args.output / "runtime-report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    raise SystemExit(0 if report["status"] == "passed" else 1)


if __name__ == "__main__":
    main()
