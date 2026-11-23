"""Install and exercise the actual APK on one disposable Android emulator.

This is an Android runtime check, not evidence about a physical ARM64 phone.
Physical devices and ambiguous ADB targets are refused. The verified emulator's
test-app data is cleared after installation so repeated runs start from one state.
It waits for the real menu geometry logged by a debug build and taps that actual
button. Screenshots and logcat remain inspectable; errors never become fake passes.
"""

import argparse
import base64
import hashlib
import json
import math
import os
from pathlib import Path, PurePosixPath
import re
import struct
import subprocess
import time
import xml.etree.ElementTree as ET
import zipfile


VILLAGE_RUNTIME_MARKER = "IMPERATHEN_VILLAGE_RUNTIME "


VILLAGE_CHUNK_MARKER = "IMPERATHEN_VILLAGE_RUNTIME_CHUNK "
VILLAGE_CHUNK_SIZE = 512
MAX_VILLAGE_CHUNKS = 64
MAX_VILLAGE_FRAMES = 256


def village_runtime_observations(text, *, retain_latest=False):
    """Validate the whole log, retaining a bounded current window when requested."""
    observations = []
    frames = {}
    observation_count = 0
    stream = None
    newest_sequence = 0
    legacy_sequence = 0
    envelope = re.compile(r"([1-9][0-9]{0,19})-([1-9][0-9]{0,19}) (0|[1-9][0-9]?) ([1-9][0-9]?) ([A-Za-z0-9+/]+={0,2})")

    def decode_snapshot(payload):
        def invalid_constant(value):
            raise ValueError("Non-finite JSON constant: " + value)
        try:
            value = json.loads(payload, parse_constant=invalid_constant)
        except (ValueError, UnicodeDecodeError) as error:
            raise RuntimeError("Invalid village runtime JSON: " + str(error)) from error
        if not isinstance(value, dict):
            raise RuntimeError("A village runtime snapshot must be an object")
        return value

    def append_observation(observation):
        nonlocal observation_count
        if len(observations) >= MAX_VILLAGE_FRAMES:
            if not retain_latest:
                raise RuntimeError("Village runtime diagnostics exceeded the bounded frame history")
            oldest = observations.pop(0)
            if oldest["kind"] == "chunk":
                del frames[oldest["sequence"]]
        observation_count += 1
        observation["ordinal"] = observation_count
        observations.append(observation)

    for line in text.splitlines():
        if VILLAGE_CHUNK_MARKER in line:
            payload = line.split(VILLAGE_CHUNK_MARKER, 1)[1]
            match = envelope.fullmatch(payload)
            if match is None:
                raise RuntimeError("Invalid or truncated village runtime chunk envelope")
            observer, sequence, part, total, data = match.groups()
            sequence, part, total = int(sequence), int(part), int(total)
            if (not 1 <= total <= MAX_VILLAGE_CHUNKS or not 0 <= part < total
                    or not 1 <= len(data) <= VILLAGE_CHUNK_SIZE
                    or (part < total - 1 and (len(data) != VILLAGE_CHUNK_SIZE or "=" in data))):
                raise RuntimeError("Invalid village runtime chunk bounds")
            if stream is None:
                stream = observer
            elif stream != observer:
                raise RuntimeError("Village runtime diagnostic producer changed within one process")
            if sequence not in frames:
                if sequence <= newest_sequence:
                    raise RuntimeError("Village runtime frames began out of sequence")
                newest_sequence = sequence
                record = {"kind": "chunk", "stream": observer, "sequence": sequence,
                          "snapshot": None}
                append_observation(record)
                frames[sequence] = {"total": total, "parts": {}, "record": record}
            frame = frames[sequence]
            if frame["total"] != total:
                raise RuntimeError("Conflicting village runtime chunk counts")
            if part in frame["parts"] and frame["parts"][part] != data:
                raise RuntimeError("Conflicting duplicate village runtime chunk")
            frame["parts"][part] = data
            if len(frame["parts"]) == total and frame["record"]["snapshot"] is None:
                encoded = "".join(frame["parts"][index] for index in range(total))
                try:
                    decoded = base64.b64decode(encoded, validate=True).decode("utf-8")
                except (ValueError, UnicodeDecodeError) as error:
                    raise RuntimeError("Invalid village runtime Base64 or UTF-8") from error
                frame["record"]["snapshot"] = decode_snapshot(decoded)
        elif VILLAGE_RUNTIME_MARKER in line:
            legacy_sequence += 1
            append_observation({"kind": "legacy", "stream": None, "sequence": legacy_sequence,
                                "snapshot": decode_snapshot(line.split(VILLAGE_RUNTIME_MARKER, 1)[1])})
    return observations


def village_runtime_cursor(text):
    """Capture the latest STARTED frame, even while some of its parts are absent."""
    observations = village_runtime_observations(text, retain_latest=True)
    if not observations:
        return -1
    latest = observations[-1]
    return (latest["kind"], latest["stream"], latest["sequence"])


def wait_for_village_snapshot(read_logs, screen=None, *, predicate=None,
                             required_control=None, after=-1, timeout=100):
    """Accept only the latest complete observation, newer than the input cursor."""
    deadline = time.monotonic() + timeout
    latest = None
    latest_frame = None
    while time.monotonic() < deadline:
        observations = village_runtime_observations(read_logs(), retain_latest=True)
        if observations:
            latest_frame = observations[-1]
            latest = latest_frame["snapshot"]
            if isinstance(after, tuple) and len(after) == 3:
                if (latest_frame["kind"], latest_frame["stream"]) != after[:2]:
                    raise RuntimeError("Village runtime diagnostic stream changed after input")
                fresh = latest_frame["sequence"] > after[2]
            elif type(after) is int:
                # Keep existing legacy log fixtures and already-published APKs readable.
                fresh = latest_frame["ordinal"] > after
            else:
                raise RuntimeError("Invalid village runtime observation cursor")
            if (latest is not None and fresh
                    and (screen is None or latest.get("screen") == screen)
                    and (required_control is None or required_control in latest.get("controls", {}))
                    and (predicate is None or predicate(latest))):
                return latest
        time.sleep(1)
    if latest_frame is not None and latest is None:
        observed = {"incomplete_frame": [latest_frame["stream"], latest_frame["sequence"]]}
    else:
        observed = {} if latest is None else {
            "screen": latest.get("screen"), "controls": sorted(latest.get("controls", {})),
            "feedback": latest.get("feedback", "")}
        if latest is not None and isinstance(latest.get("action_runtime"), dict):
            actual = latest["action_runtime"]
            observed["action_runtime"] = {name: actual.get(name) for name in
                                          ("position", "move_axis", "movement_touch", "world_active", "body_velocity")}
    raise RuntimeError("No matching village runtime state: " + str(screen)
                       + "; required control: " + str(required_control)
                       + "; last observed: " + json.dumps(observed, sort_keys=True))


def wait_for_stable_village_control(read_control, *, timeout=60, tolerance=1.0,
                                   max_observations=8, require_visible=True):
    """Use fresh, unchanged native geometry before tapping a scrolled control."""
    deadline = time.monotonic() + timeout
    previous_center = None
    previous_instance = None
    for _ in range(max_observations):
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            break
        control = read_control(remaining)
        if not isinstance(control, dict) or control.get("enabled") is not True:
            raise RuntimeError("The observed village control is absent or disabled")
        center = control.get("center")
        instance = control.get("instance_id")
        if (not isinstance(center, list) or len(center) != 2
                or not all(isinstance(value, (int, float)) and math.isfinite(value) for value in center)
                or not isinstance(instance, str) or not instance):
            raise RuntimeError("The observed village control has no valid native geometry or identity")
        if not require_visible or control.get("visible") is True:
            if (previous_center is not None and previous_instance == instance
                    and max(abs(center[index] - previous_center[index]) for index in range(2)) <= tolerance):
                return control
            previous_center = list(center)
            previous_instance = instance
        else:
            previous_center = None
            previous_instance = None
    raise RuntimeError("The actual village control did not remain visible at stable native coordinates")


def activate_observed_village_popup(observe_popup, press_key, target_text, *,
                                   timeout=120, max_moves=16, expected_control_instance=None):
    """Navigate the actual popup using its observed focus, then confirm that row.

    A touch-opened OptionButton may begin with no focused item. Never infer a
    row from a fixed number of DOWN presses, and never mutate the game state.
    observe_popup waits for visibility initially and changed focus after input.
    """
    deadline = time.monotonic() + timeout
    previous_focus = None
    identity = None
    inventory = None
    seen_focus = set()
    moves = 0
    while True:
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise RuntimeError("Timed out while observing the actual village assignment popup")
        control = observe_popup(previous_focus, remaining)
        popup = control.get("popup") if isinstance(control, dict) else None
        if (not isinstance(control, dict) or control.get("enabled") is not True
                or not isinstance(popup, dict) or popup.get("visible") is not True):
            raise RuntimeError("The actual village assignment popup closed or became unavailable")
        current_identity = (control.get("instance_id"), popup.get("instance_id"))
        if not all(isinstance(value, str) and value for value in current_identity):
            raise RuntimeError("The observed village assignment popup has no stable identity")
        if expected_control_instance is not None and current_identity[0] != expected_control_instance:
            raise RuntimeError("The actual village assignment control changed after the native tap")
        if identity is None:
            identity = current_identity
        elif current_identity != identity:
            raise RuntimeError("The actual village assignment popup was replaced during navigation")
        items = popup.get("items")
        if not isinstance(items, list) or not items:
            raise RuntimeError("The observed village assignment popup has no item inventory")
        normalized = []
        for index, item in enumerate(items):
            if (not isinstance(item, dict) or type(item.get("index")) is not int
                    or item["index"] != index or not isinstance(item.get("text"), str)
                    or type(item.get("enabled")) is not bool):
                raise RuntimeError("The observed village assignment popup item inventory is invalid")
            normalized.append((index, item["text"], item["enabled"]))
        current_inventory = tuple(normalized)
        if inventory is None:
            inventory = current_inventory
        elif current_inventory != inventory:
            raise RuntimeError("The actual village assignment popup items changed during navigation")
        matches = [item for item in items if item["text"] == target_text]
        if len(matches) != 1 or not matches[0]["enabled"]:
            raise RuntimeError("The actual assignment popup has no unique enabled target: " + target_text)
        target_index = matches[0]["index"]
        focused = popup.get("focused")
        if type(focused) is not int or not -1 <= focused < len(items):
            raise RuntimeError("The observed village assignment popup focus is invalid")
        if focused == target_index:
            press_key("KEYCODE_ENTER")
            return {"control_instance": identity[0], "popup_instance": identity[1],
                    "focused_index": focused, "text": target_text, "down_presses": moves}
        if focused in seen_focus:
            raise RuntimeError("The actual village assignment popup focus did not progress")
        if moves >= min(max_moves, len(items) + 1):
            raise RuntimeError("The actual village assignment popup exceeded bounded navigation")
        seen_focus.add(focused)
        press_key("KEYCODE_DPAD_DOWN")
        previous_focus = focused
        moves += 1


def observed_scroll_gesture(control, scroll):
    """Move a clipped control toward the observed viewport without a full-page fling."""
    if not isinstance(control, dict) or control.get("enabled") is not True or not isinstance(scroll, dict):
        raise RuntimeError("Missing usable control or observed scroll geometry")
    values = [control.get("center"), scroll.get("top"), scroll.get("bottom")]
    if any(not isinstance(point, list) or len(point) != 2
           or any(type(number) not in (int, float) or not math.isfinite(number) for number in point)
           for point in values):
        raise RuntimeError("Invalid observed scroll coordinates")
    center, top, bottom = values
    span = bottom[1] - top[1]
    if span <= 4 or abs(bottom[0] - top[0]) > 1:
        raise RuntimeError("Invalid observed vertical scroll area")
    middle = (top[1] + bottom[1]) * 0.5
    correction = middle - center[1]
    if abs(correction) < 1:
        raise RuntimeError("A centered hidden control cannot be revealed by vertical scrolling")
    # Keep both endpoints in the current visible band and reduce speed near the
    # target. CI27 exposed oscillation when every correction used a full swipe.
    distance = min(abs(correction) * 0.5, span * 0.35)
    distance = math.copysign(max(1.0, distance), correction)
    return (top[0], middle), (top[0], middle + distance)


def apk_runtime_features(entries):
    """Choose the story route from files actually present in the tested APK."""
    def contains(prefix):
        return any(name.startswith("assets/scripts/" + prefix + ".") for name in entries)
    village = contains("story/village_life")
    return {"village_life": village,
            "childhood": village and contains("story/village_childhood"),
            "action_controls": village and contains("ui/touch_look") and contains("domain/combat_actions")}


def childhood_runtime_state(snapshot):
    state = snapshot.get("childhood_runtime") if isinstance(snapshot, dict) else None
    if not isinstance(state, dict) or type(state.get("version")) is not int or state["version"] != 1:
        raise RuntimeError("Missing or unsupported actual childhood runtime state")
    for name in ("world_id", "stage", "target_npc", "target_point", "dialog_npc"):
        if not isinstance(state.get(name), str):
            raise RuntimeError("Invalid childhood field: " + name)
    if not state["world_id"] or not state["stage"]:
        raise RuntimeError("Childhood identity and stage must be observed")
    for name in ("age", "day"):
        if type(state.get(name)) is not int or state[name] < 1:
            raise RuntimeError("Invalid childhood integer: " + name)
    for name in ("completed", "carried"):
        items = state.get(name)
        if not isinstance(items, list) or any(not isinstance(item, str) or not item for item in items):
            raise RuntimeError("Invalid childhood items: " + name)
        if len(set(items)) != len(items):
            raise RuntimeError("Duplicated childhood items: " + name)
    for name in ("target_position", "family_entrance", "family_water"):
        values = state.get(name)
        if (not isinstance(values, list) or len(values) != 2
                or any(type(value) not in (int, float) or not math.isfinite(value) for value in values)):
            raise RuntimeError("Invalid childhood point: " + name)
    radius = state.get("target_radius")
    if type(radius) not in (int, float) or not math.isfinite(radius) or not 0 < radius <= 4:
        raise RuntimeError("Invalid childhood interaction radius")
    return state


def observed_walk_point(snapshot, target):
    """Native pad position toward a read-only world waypoint, relative to camera."""
    state = action_runtime_state(snapshot)
    yaw = state.get("camera_yaw")
    if type(yaw) not in (int, float) or not math.isfinite(yaw):
        raise RuntimeError("Camera orientation was not observed for native walking")
    if (not isinstance(target, (tuple, list)) or len(target) != 2
            or any(type(value) not in (int, float) or not math.isfinite(value) for value in target)):
        raise RuntimeError("Invalid observed world waypoint")
    pad = snapshot.get("controls", {}).get("move_pad")
    center, right = observed_movement_points(pad, "right")
    _, down = observed_movement_points(pad, "down")
    dx, dz = target[0] - state["position"][0], target[1] - state["position"][2]
    distance = math.hypot(dx, dz)
    if distance < 0.001:
        return center, distance
    # Godot rotates the local x/z pad direction around +Y by the camera yaw.
    strength = min(1.0, max(0.35, distance / 1.2))
    x = (math.cos(yaw) * dx - math.sin(yaw) * dz) / distance * strength
    y = (math.sin(yaw) * dx + math.cos(yaw) * dz) / distance * strength
    point = [center[0] + (right[0] - center[0]) * x + (down[0] - center[0]) * y,
             center[1] + (right[1] - center[1]) * x + (down[1] - center[1]) * y]
    left, top, width, height = pad["rect"]
    if not (left <= point[0] <= left + width and top <= point[1] <= top + height):
        raise RuntimeError("Native walking point falls outside the observed pad")
    return point, distance


def action_runtime_state(snapshot):
    """Validate the new read-only action observation; missing fields never pass."""
    state = snapshot.get("action_runtime") if isinstance(snapshot, dict) else None
    if not isinstance(state, dict) or type(state.get("version")) is not int or state.get("version") != 1:
        raise RuntimeError("Missing or unsupported actual action runtime observation")
    for name, length in (("position", 3), ("velocity", 3), ("body_velocity", 3), ("move_axis", 2)):
        values = state.get(name)
        if (not isinstance(values, list) or len(values) != length
                or not all(type(value) in (int, float) and math.isfinite(value) for value in values)):
            raise RuntimeError("Invalid observed action vector: " + name)
    for name in ("world_active", "running", "touch_camera_managed"):
        if type(state.get(name)) is not bool:
            raise RuntimeError("Invalid observed action flag: " + name)
    for name in ("movement_touch", "camera_touches", "action_touches", "world_camera_touches"):
        value = state.get(name)
        minimum = -1 if name == "movement_touch" else 0
        if type(value) is not int or not minimum <= value <= 32:
            raise RuntimeError("Invalid observed action contact count: " + name)
    if state.get("mode") not in ("person", "city", "map"):
        raise RuntimeError("Invalid observed action mode")
    if state.get("overlay") not in ("none", "techniques", "commands"):
        raise RuntimeError("Invalid observed action overlay")
    if not isinstance(state.get("selected_technique"), str):
        raise RuntimeError("Missing observed technique selection")
    return state


def action_input_is_neutral(snapshot):
    state = action_runtime_state(snapshot)
    return (state["movement_touch"] == -1
            and state["camera_touches"] == state["action_touches"] == state["world_camera_touches"] == 0
            and math.hypot(*state["move_axis"]) <= 0.001
            and math.hypot(state["body_velocity"][0], state["body_velocity"][2]) <= 0.05)


def action_position_distance(before, after):
    first = action_runtime_state(before)["position"]
    second = action_runtime_state(after)["position"]
    return math.hypot(first[0] - second[0], first[2] - second[2])


def graphics_runtime_profiles(snapshot):
    state = snapshot.get("graphics_runtime") if isinstance(snapshot, dict) else None
    profiles = {"low", "balanced", "high", "very_high"}
    if (not isinstance(state, dict) or not isinstance(state.get("ui_profile"), str)
            or not isinstance(state.get("world_profile"), str)
            or state["ui_profile"] not in profiles or state["world_profile"] not in profiles):
        raise RuntimeError("Missing or invalid observed graphics profiles")
    return state


def observed_movement_points(control, direction="right"):
    """Use points observed from the actual pad, never a screen-size guess."""
    if (not isinstance(control, dict) or control.get("visible") is not True
            or control.get("enabled") is not True):
        raise RuntimeError("The actual movement pad is not visible and enabled")
    rect = control.get("rect")
    if (not isinstance(rect, list) or len(rect) != 4
            or not all(type(value) in (int, float) and math.isfinite(value) for value in rect)
            or min(rect[2:]) <= 0):
        raise RuntimeError("The actual movement pad has invalid native bounds")
    points = control.get("axis_points")
    if not isinstance(points, dict) or direction not in ("left", "right", "up", "down"):
        raise RuntimeError("The actual movement pad has no requested native axis")
    selected = []
    for name in ("center", direction):
        point = points.get(name)
        if (not isinstance(point, list) or len(point) != 2
                or not all(type(value) in (int, float) and math.isfinite(value) for value in point)
                or not rect[0] <= point[0] <= rect[0] + rect[2]
                or not rect[1] <= point[1] <= rect[1] + rect[3]):
            raise RuntimeError("The observed movement point is outside the actual pad: " + name)
        selected.append(tuple(point))
    if math.dist(*selected) < 4:
        raise RuntimeError("The observed movement gesture has no usable displacement")
    return tuple(selected)


def drive_observed_native_pointer(read_logs, send_motion, before, *, target=None,
                                  radius=0.25, minimum_distance=0.10, timeout=180,
                                  evidence=None):
    """Hold one real native pointer until fresh observations prove movement.

    send_motion sends Android DOWN/MOVE/UP at the observed pad coordinates.
    No duration, input axis alone or injected position can satisfy the distance
    check. Every attempted DOWN is paired with UP, including failed ADB calls.
    """
    for value in (radius, minimum_distance, timeout):
        if type(value) not in (int, float) or not math.isfinite(value) or value <= 0:
            raise RuntimeError("Invalid native movement bound")
    initial = action_runtime_state(before)
    pad = before.get("controls", {}).get("move_pad")
    center, _right = observed_movement_points(pad)
    identity = pad.get("instance_id")
    if not isinstance(identity, str) or not identity:
        raise RuntimeError("The actual movement pad has no stable identity")
    if not action_input_is_neutral(before):
        raise RuntimeError("Native movement must begin with neutral observed inputs")
    if target is not None and observed_walk_point(before, target)[1] <= radius:
        raise RuntimeError("The native movement waypoint was already reached before input")
    evidence = {} if evidence is None else evidence
    evidence.update({"input": "adb input motionevent", "events": [], "observations": [],
                     "before": initial, "target": None if target is None else list(target)})
    deadline = time.monotonic() + timeout
    cursor = village_runtime_cursor(read_logs())
    point = tuple(round(value) for value in center)
    captured_contact = None
    saw_movement_axis = False

    def context(state):
        actual = action_runtime_state(state)
        current_pad = state.get("controls", {}).get("move_pad")
        observed_movement_points(current_pad)
        if (not actual["world_active"] or actual["mode"] != "person"
                or actual["overlay"] != "none" or state.get("screen") != "playing"
                or current_pad.get("instance_id") != identity
                or any(actual[name] for name in ("camera_touches", "action_touches", "world_camera_touches"))):
            raise RuntimeError("The actual native movement context changed while holding the pointer")
        return actual

    def motion(event):
        entry = {"event": event, "point": list(point), "command_returned": False}
        evidence["events"].append(entry)
        send_motion(event, point)
        entry["command_returned"] = True

    def observe(predicate=None):
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise RuntimeError("Native movement did not reach its observed goal before the deadline")
        return wait_for_village_snapshot(read_logs, "playing", required_control="move_pad",
                                          after=cursor, predicate=predicate, timeout=min(60, remaining))

    def note(state, phase):
        actual = context(state)
        evidence["observations"].append({"phase": phase, "position": actual["position"],
                                         "movement_touch": actual["movement_touch"],
                                         "move_axis": actual["move_axis"]})
        return actual

    context(before)
    try:
        motion("DOWN")
        held = observe(lambda state: context(state)["movement_touch"] >= 0)
        captured_contact = note(held, "DOWN")["movement_touch"]
        for _ in range(256):
            actual = context(held)
            if actual["movement_touch"] != captured_contact:
                raise RuntimeError("The actual native movement pointer was lost or replaced")
            if target is None:
                next_point = observed_movement_points(held["controls"]["move_pad"])[1]
                arrived = True
            else:
                next_point, distance = observed_walk_point(held, target)
                arrived = distance <= radius
            if (saw_movement_axis and arrived
                    and action_position_distance(before, held) >= minimum_distance):
                break
            cursor = village_runtime_cursor(read_logs())
            point = tuple(round(value) for value in next_point)
            motion("MOVE")
            held = observe()
            actual = note(held, "MOVE")
            saw_movement_axis |= math.hypot(*actual["move_axis"]) > 0.001
        else:
            raise RuntimeError("Native movement exceeded its bounded fresh observations")
        # A neutral frame that already existed before UP cannot prove release.
        # Keep this read inside try so even a transport failure still sends UP.
        release_cursor = village_runtime_cursor(read_logs())
    finally:
        # Do not read logs first: a diagnostic/ADB failure must not prevent UP.
        motion("UP")
    released = wait_for_village_snapshot(read_logs, "playing", required_control="move_pad",
                                         after=release_cursor, predicate=action_input_is_neutral, timeout=45)
    note(released, "UP")
    distance = action_position_distance(before, released)
    if distance < minimum_distance:
        raise RuntimeError("The native pointer did not produce the required actual player displacement")
    evidence["after"] = action_runtime_state(released)
    evidence["distance_m"] = distance
    return released


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
    with zipfile.ZipFile(args.apk) as archive:
        entries = archive.namelist()
        features = apk_runtime_features(entries)
        has_village_life = features["village_life"]
        has_childhood = features["childhood"]
        has_action_controls = features["action_controls"]
    package = "at.heinz.imperathen"
    report = {"platform": "Android emulator", "apk_sha256": hashlib.sha256(args.apk.read_bytes()).hexdigest(), "physical_device_test": False,
              "arm64_runtime_test": False, "status": "failed", "checks": [], "errors": []}
    report["source_commit"] = os.environ.get("IMPERATHEN_APK_COMMIT", os.environ.get("GITHUB_SHA"))
    report["test_harness_commit"] = os.environ.get("GITHUB_SHA")
    report["apk_file"] = args.apk.name
    report["action_controls_expected"] = has_action_controls
    report["story_route"] = "childhood_home" if has_childhood else "legacy_village"
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

    def finish_story_opening():
        # Older release APKs have no in-world prologue. New builds expose actual
        # laid-out buttons; this test never substitutes guessed screen positions.
        expected = "childhood_home" if has_childhood else "first_day"
        if has_childhood:
            started = wait_marker("IMPERATHEN_OPENING_STARTED ")
            record("family_opening_is_actual_new_game", started == expected, started)
        elif "IMPERATHEN_OPENING_STARTED first_day" not in checked_logs():
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
        if has_childhood:
            objective = resumed
            for _ in range(8):
                if objective["final"]:
                    break
                previous_index = objective["index"]
                previous = checked_logs().count(marker)
                tap(objective["buttons"]["OpeningAdvance"])
                objective = json.loads(wait_for_new_marker(marker, previous))
                record("native_family_intro_advance", objective.get("sequence") == "childhood_home"
                       and objective["index"] > previous_index and not objective["paused"], objective)
            record("family_intro_reaches_first_objective",
                   objective["final"] and not objective["companion_choice"], objective)
        else:
            previous = checked_logs().count(marker)
            tap(resumed["buttons"]["OpeningSkip"])
            objective = json.loads(wait_for_new_marker(marker, previous))
            record("skip_keeps_first_objective", objective["final"] and not objective["companion_choice"], objective)
        screenshot("11_android_opening_objective.png")
        tap(objective["buttons"]["OpeningAdvance"])
        wait_marker("IMPERATHEN_OPENING_COMPLETE")
        record("objective_hands_over_control", True, "Actual touch accepted the objective after the opening controls")

    def village_snapshot(screen=None, *, predicate=None, required_control=None, after=-1, timeout=100):
        return wait_for_village_snapshot(checked_logs, screen, predicate=predicate,
                                         required_control=required_control, after=after, timeout=timeout)

    def village_control(name, screen, *, after=-1):
        state = village_snapshot(screen, required_control=name, after=after)
        for _ in range(24):
            control = state.get("controls", {}).get(name)
            if control is None:
                raise RuntimeError("The current village UI has no control: " + name)
            if control.get("visible") and control.get("enabled"):
                return control
            if not control.get("enabled"):
                raise RuntimeError("The actual village control is disabled: " + name)
            scroll = state.get("scroll")
            if not scroll:
                raise RuntimeError("A clipped village control has no visible scroll area: " + name)
            start, end = observed_scroll_gesture(control, scroll)
            previous = village_runtime_cursor(checked_logs())
            adb("shell", "input", "swipe", *(str(round(v)) for v in (*start, *end)), "900")
            state = village_snapshot(screen, required_control=name, after=previous)
            # ScrollContainer may still coast after UP. Wait for unchanged actual
            # geometry, including clipped states, before calculating another swipe.
            def settled_control(timeout):
                nonlocal state
                cursor = village_runtime_cursor(checked_logs())
                state = village_snapshot(screen, required_control=name, after=cursor, timeout=timeout)
                return state["controls"][name]
            wait_for_stable_village_control(settled_control, require_visible=False)
        raise RuntimeError("Could not scroll the actual village control into view: " + name)

    def stable_village_control(name, screen):
        def fresh_control(timeout):
            previous = village_runtime_cursor(checked_logs())
            state = village_snapshot(screen, required_control=name, after=previous, timeout=timeout)
            return state["controls"][name]
        return wait_for_stable_village_control(fresh_control)

    def observe_assignment_popup(previous_focus, timeout):
        previous = village_runtime_cursor(checked_logs())
        def changed(state):
            popup = state.get("controls", {}).get("aelia_assignment", {}).get("popup", {})
            if previous_focus is None:
                return popup.get("visible") is True
            return popup.get("visible") is not True or popup.get("focused") != previous_focus
        state = village_snapshot("village_panel", required_control="aelia_assignment",
                                 predicate=changed, after=previous, timeout=timeout)
        return state["controls"]["aelia_assignment"]

    def select_light_graphics_via_settings():
        previous = village_runtime_cursor(checked_logs())
        adb("shell", "input", "keyevent", "4")
        paused = village_snapshot("paused", required_control="settings", after=previous,
                                  predicate=action_input_is_neutral)
        record("native_back_opens_quality_pause", not action_runtime_state(paused)["world_active"],
               graphics_runtime_profiles(paused))
        village_control("settings", "paused")
        settings = stable_village_control("settings", "paused")
        previous = village_runtime_cursor(checked_logs())
        tap(settings["center"])
        village_control("quality", "paused", after=previous)
        selector = stable_village_control("quality", "paused")
        previous = village_runtime_cursor(checked_logs())
        tap(selector["center"])

        def observe_quality_popup(previous_focus, timeout):
            cursor = village_runtime_cursor(checked_logs())
            def changed(state):
                popup = state.get("controls", {}).get("quality", {}).get("popup", {})
                return (popup.get("visible") is True if previous_focus is None
                        else popup.get("visible") is not True or popup.get("focused") != previous_focus)
            state = village_snapshot("paused", required_control="quality", predicate=changed,
                                     after=cursor, timeout=timeout)
            return state["controls"]["quality"]

        selected = activate_observed_village_popup(
            observe_quality_popup, lambda key: adb("shell", "input", "keyevent", key),
            "Leicht · Limit 30 FPS", expected_control_instance=selector["instance_id"])
        applied = village_snapshot("paused", required_control="quality", after=previous,
                                   predicate=lambda state: graphics_runtime_profiles(state)
                                   == {"ui_profile": "low", "world_profile": "low"}
                                   and not state["controls"]["quality"]["popup"]["visible"])
        record("native_settings_select_light_graphics", action_input_is_neutral(applied),
               {"popup": selected, "profiles": graphics_runtime_profiles(applied)})
        screenshot("18_android_light_settings.png")
        previous = village_runtime_cursor(checked_logs())
        adb("shell", "input", "keyevent", "4")
        village_snapshot("paused", required_control="resume", after=previous)
        previous = village_runtime_cursor(checked_logs())
        adb("shell", "input", "keyevent", "4")
        resumed = village_snapshot("playing", required_control="move_pad", after=previous,
                                   predicate=action_input_is_neutral)
        record("native_settings_resume_preserves_light_graphics", graphics_runtime_profiles(resumed)
               == {"ui_profile": "low", "world_profile": "low"}
               and action_runtime_state(resumed)["world_active"], graphics_runtime_profiles(resumed))

    def exercise_village_life():
        initial = village_snapshot("playing")
        record("village_actual_population", initial.get("people") == 14 and initial.get("actors") == 15
               and initial.get("workplaces") == 5 and initial.get("player_is_ruler") is False, initial)
        tap(village_control("interact", "playing")["center"])
        conversation = village_snapshot("village_dialog", predicate=lambda state: state.get("decimus_met") is True)
        record("village_touch_meets_decimus", True, conversation)
        tap(village_control("permit", "village_dialog")["center"])
        permission = village_snapshot("village_dialog", predicate=lambda state: state.get("work_permit") is True)
        record("village_touch_work_permission", permission.get("player_is_ruler") is False, permission)
        screenshot("12_android_decimus.png")
        adb("shell", "input", "keyevent", "4")
        village_snapshot("playing")
        record("village_back_closes_dialogue", True, "Android Back returned from the real steward conversation")
        tap(village_control("village", "playing")["center"])
        work_tab = village_control("work_tab", "village_panel")
        previous = village_runtime_cursor(checked_logs())
        tap(work_tab["center"])
        village_control("aelia_assignment", "village_panel", after=previous)
        selector = stable_village_control("aelia_assignment", "village_panel")
        record("village_unassigned_resident", selector.get("selected") == 0, selector)
        before_assignment = village_runtime_cursor(checked_logs())
        tap(selector["center"])
        selected = activate_observed_village_popup(
            observe_assignment_popup,
            lambda key: adb("shell", "input", "keyevent", key),
            "Holzfällerlager", expected_control_instance=selector["instance_id"])
        record("village_popup_target_observed", True, selected)
        assigned = village_snapshot("village_panel", after=before_assignment,
                                    predicate=lambda state: state.get("aelia_assignment") == "woodcamp")
        record("village_actual_worker_assignment", assigned.get("people") == 14, assigned)
        screenshot("13_android_work_assignment.png")
        adb("shell", "input", "keyevent", "4")
        village_snapshot("playing", predicate=lambda state: state.get("aelia_assignment") == "woodcamp")
        record("village_back_closes_work_panel", True, "The worker stays assigned when the work panel closes")

    def walk_to_childhood_point(target, label, radius=0.25):
        # These are short authored family-home routes, not general pathfinding.
        # The observer only reads the live world; every movement is an ADB touch.
        for attempt in range(24):
            previous = village_runtime_cursor(checked_logs())
            before = village_snapshot("playing", required_control="move_pad", after=previous,
                                      predicate=action_input_is_neutral)
            _point, distance = observed_walk_point(before, target)
            if distance <= radius:
                record(label + "_reached_by_native_walk", True,
                       {"target": target, "distance_m": distance, "position": before["action_runtime"]["position"]})
                return before
            evidence = {"route": label, "attempt": attempt + 1}
            report.setdefault("childhood_native_walks", []).append(evidence)
            drive_observed_native_pointer(checked_logs, send_native_motion, before,
                                           target=target, radius=radius, minimum_distance=0.02,
                                           evidence=evidence)
        raise RuntimeError("Native childhood waypoint was not reached: " + label)

    def send_native_motion(event, point):
        adb("shell", "input", "motionevent", event, *(str(value) for value in point))

    def exercise_childhood_start():
        initial = village_snapshot("playing", required_control="move_pad")
        child = childhood_runtime_state(initial)
        record("actual_family_start", child["stage"] == "mother_morning" and child["completed"] == []
               and child["carried"] == [] and child["age"] == 12 and child["day"] == 1
               and child["target_npc"] == "julia" and initial.get("player_is_ruler") is False, child)
        screenshot("15_android_family_home.png")
        entrance, water = child["family_entrance"], child["family_water"]
        # The continuous Main route verified these clear points inside/outside
        # the actual doorway. They remain native input goals, never assignments.
        inside = [entrance[0], water[1] + 0.4]
        outside = [entrance[0], entrance[1] + 0.5]
        walk_to_childhood_point(inside, "family_door_alignment", radius=0.20)
        walk_to_childhood_point(outside, "family_doorstep", radius=0.30)
        previous = village_runtime_cursor(checked_logs())
        tap(stable_village_control("interact", "playing")["center"])
        conversation = village_snapshot("village_dialog", required_control="childhood_mother_morning", after=previous,
                                        predicate=lambda item: childhood_runtime_state(item)["dialog_npc"] == "julia")
        record("native_interaction_reaches_mother", True, childhood_runtime_state(conversation))
        choice = village_control("childhood_mother_morning", "village_dialog")
        previous = village_runtime_cursor(checked_logs())
        tap(choice["center"])
        agreed = village_snapshot("village_dialog", after=previous,
                                  predicate=lambda item: childhood_runtime_state(item)["stage"] == "fill_water")
        agreed_child = childhood_runtime_state(agreed)
        record("native_mother_choice_carries_real_household_coin",
               agreed_child["completed"] == ["mother_morning"] and agreed_child["carried"] == ["household_coin"], agreed_child)
        screenshot("16_android_mother_conversation.png")
        previous = village_runtime_cursor(checked_logs())
        adb("shell", "input", "keyevent", "4")
        returned = village_snapshot("playing", required_control="move_pad", after=previous)
        task = childhood_runtime_state(returned)
        record("family_goal_moves_to_real_water_station", task["target_point"] == "family_water"
               and task["target_position"] == water, task)
        walk_to_childhood_point(inside, "return_inside_family_house", radius=0.25)
        walk_to_childhood_point(task["target_position"], "family_water_station", radius=task["target_radius"] * 0.7)
        previous = village_runtime_cursor(checked_logs())
        tap(stable_village_control("interact", "playing")["center"])
        filled = village_snapshot("playing", after=previous,
                                  predicate=lambda item: childhood_runtime_state(item)["stage"] == "father_morning")
        saved = childhood_runtime_state(filled)
        record("native_item_action_fills_family_jug",
               saved["completed"] == ["mother_morning", "fill_water"]
               and sorted(saved["carried"]) == ["household_coin", "water_jug"]
               and saved["world_id"] == child["world_id"] and saved["age"] == 12 and saved["day"] == 1, saved)
        screenshot("17_android_family_jug.png")
        report["childhood_scope"] = "First two actual actions only: mother conversation and filling the family jug; no quest, item or position injection."
        return {key: saved[key] for key in ("world_id", "stage", "completed", "carried", "age", "day")}

    def verify_action_rest(screen, stage):
        previous = village_runtime_cursor(checked_logs())
        first = village_snapshot(screen, after=previous, predicate=action_input_is_neutral)
        state = action_runtime_state(first)
        record(stage + "_neutral_inputs", state["mode"] == "person" and state["overlay"] == "none", state)
        previous = village_runtime_cursor(checked_logs())
        second = village_snapshot(screen, after=previous, predicate=action_input_is_neutral)
        distance = action_position_distance(first, second)
        record(stage + "_no_player_drift", distance <= 0.05,
               {"distance_m": distance, "first": first["action_runtime"], "second": second["action_runtime"]})
        return second

    def exercise_action_controls():
        initial = village_snapshot("playing", required_control="move_pad")
        state = action_runtime_state(initial)
        record("action_hud_from_new_game", initial.get("action_mode") == "unarmed"
               and state["mode"] == "person" and state["ui_view"] == "game"
               and state["touch_camera_managed"] and not state["running"], state)
        before = village_snapshot("playing", predicate=action_input_is_neutral)
        evidence = {}
        report["action_native_walk"] = evidence
        moved = drive_observed_native_pointer(checked_logs, send_native_motion, before,
                                               minimum_distance=0.10, evidence=evidence)
        distance = action_position_distance(before, moved)
        record("native_pad_moves_actual_player", distance >= 0.10, evidence)
        verify_action_rest("playing", "released_movement")
        for running in (True, False):
            pace = stable_village_control("pace", "playing")
            previous = village_runtime_cursor(checked_logs())
            tap(pace["center"])
            changed = village_snapshot("playing", after=previous,
                                       predicate=lambda item: action_runtime_state(item)["running"] is running)
            record("native_tap_selects_running" if running else "native_tap_restores_walking", True,
                   changed["action_runtime"])
        techniques = stable_village_control("techniques", "playing")
        previous = village_runtime_cursor(checked_logs())
        tap(techniques["center"])
        opened = village_snapshot("playing", required_control="technique_jab_right", after=previous,
                                  predicate=lambda item: action_runtime_state(item)["overlay"] == "techniques")
        record("native_tap_opens_techniques", action_input_is_neutral(opened), opened)
        screenshot("14_android_techniques.png")
        choice = stable_village_control("technique_jab_right", "playing")
        previous = village_runtime_cursor(checked_logs())
        tap(choice["center"])
        chosen = village_snapshot("playing", required_control="attack", after=previous,
                                 predicate=lambda item: action_runtime_state(item)["selected_technique"] == "jab_right"
                                 and action_runtime_state(item)["overlay"] == "none")
        record("native_tap_selects_right_straight", action_input_is_neutral(chosen), chosen)
        control = stable_village_control("move_pad", "playing")
        _, held_point = observed_movement_points(control)
        native_point = tuple(str(round(value)) for value in held_point)
        previous = village_runtime_cursor(checked_logs())
        pointer_down = False
        try:
            pointer_down = True
            adb("shell", "input", "motionevent", "DOWN", *native_point)
            held = village_snapshot("playing", after=previous,
                                    predicate=lambda item: action_runtime_state(item)["movement_touch"] >= 0
                                    and math.hypot(*action_runtime_state(item)["move_axis"]) > 0.3,
                                    timeout=60)
            record("native_pointer_is_held_before_pause", True, held["action_runtime"])
            previous = village_runtime_cursor(checked_logs())
            adb("shell", "input", "keyevent", "4")
            paused = village_snapshot("paused", after=previous, predicate=action_input_is_neutral)
            record("pause_cancels_held_native_pointer", not action_runtime_state(paused)["world_active"],
                   paused["action_runtime"])
        finally:
            if pointer_down:
                adb("shell", "input", "motionevent", "UP", *native_point)
        previous = village_runtime_cursor(checked_logs())
        adb("shell", "input", "keyevent", "4")
        village_snapshot("playing", after=previous, predicate=action_input_is_neutral)
        verify_action_rest("playing", "resume_after_held_pointer")

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
        finish_story_opening()
        if has_childhood or has_action_controls:
            help_text = adb("shell", "input", "help", checked=False)
            record("native_pointer_command_available", "motionevent" in help_text,
                   "The verified Android input command advertises native pointer DOWN/MOVE/UP support")
        if has_childhood:
            select_light_graphics_via_settings()
        childhood_checkpoint = exercise_childhood_start() if has_childhood else None
        if has_village_life and not has_childhood:
            exercise_village_life()
        if has_action_controls:
            exercise_action_controls()
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
        if has_childhood:
            restored = village_snapshot("playing")
            restored_child = childhood_runtime_state(restored)
            record("family_actions_and_items_survive_restart",
                   all(restored_child[key] == value for key, value in childhood_checkpoint.items()), restored_child)
        elif has_village_life:
            restored = village_snapshot("playing")
            record("village_decisions_survive_restart", restored.get("decimus_met") is True
                   and restored.get("work_permit") is True and restored.get("aelia_assignment") == "woodcamp"
                   and restored.get("people") == 14 and restored.get("player_is_ruler") is False, restored)
        if has_action_controls:
            verify_action_rest("playing", "restart_action_controls")
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
