#!/usr/bin/env python3
"""Fail-closed motion acceptance for the supported Android export path.

A headless animation test cannot establish naturalness, weight or visual
quality on its own. Require measured limits, coverage, source-bound engine
proof and an actual reviewed capture for every active motion family.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path, PurePosixPath
import re
import shutil
import struct
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
MODEL_EXT = {".glb", ".gltf", ".fbx", ".obj", ".dae", ".blend", ".bvh", ".mesh", ".tscn", ".scn", ".tres", ".res"}
SCRIPT_EXT = {".gd", ".gdshader", ".gdshaderinc"}
RIG_LIMITS = {
    "max_segment_error_m": .005,
    "max_linear_speed_m_s": 12.0,
    "max_angular_speed_deg_s": 2400.0,
    "max_loop_seam_m": .03,
    "max_loop_seam_deg": 12.0,
    "frozen_required_clips": 0,
}
# Engineering acceptance bounds, not claims of universal biological constants.
# Contact errors are measured on actual support surfaces, not inferred from
# an animation name. Every metric is a worst-case value, never a mean.
FAMILY_LIMITS = {
    "human": {"max_support_slip_m": .015, "max_sole_penetration_m": .01,
              "max_transition_position_jump_m": .06, "max_transition_rotation_jump_deg": 20,
              "skin_edge_violations": 0},
    "human_world": {"max_root_step_m": .12, "max_collision_overlap_m": .01,
                    "max_support_slip_m": .015, "max_transition_position_jump_m": .06,
                    "max_transition_rotation_jump_deg": 20},
    "animal": {"max_segment_error_m": .005, "max_hoof_paw_slip_m": .02,
               "max_hoof_paw_penetration_m": .01, "max_transition_position_jump_m": .06,
               "max_transition_rotation_jump_deg": 20, "skin_edge_violations": 0},
    "rider": {"max_seat_drift_m": .025, "max_rein_grip_drift_m": .02,
              "max_stirrup_or_leg_anchor_drift_m": .025, "max_gait_phase_error_cycles": .08,
              "max_collision_overlap_m": .01, "max_transition_position_jump_m": .06},
    "attached": {"max_socket_drift_m": .002, "max_socket_orientation_error_deg": 2.0,
                 "max_unintended_penetration_m": .01, "max_transition_position_jump_m": .06},
    "crowd": {"max_visible_contact_slip_m": .04, "max_lod_pose_jump_m": .04,
              "max_root_step_m": .12, "max_transition_rotation_jump_deg": 20},
    "wheeled": {"max_rolling_distance_error_ratio": .03, "max_ground_slip_m": .015,
                "max_ground_penetration_m": .01, "max_axle_separation_m": .005,
                "max_root_step_m": .12, "max_uncommanded_speed_jump_m_s": .2},
    "articulated": {"max_joint_anchor_error_m": .005, "max_joint_limit_error_deg": 1.0,
                    "max_unintended_penetration_m": .01, "max_operator_grip_drift_m": .02,
                    "max_uncommanded_speed_jump_m_s": .2},
}
RIG_PROFILES = {"human", "animal"}
REQUIRED_ACTIVE = {"hero", "frontier_people", "legacy_people", "meshy_people", "battle_rigs",
                   "distant_ranks", "regional_workers", "service_gear", "meshy_gear",
                   "village_navigation", "raid_motion", "cinematic_people"}
REQUIRED_PROFILES = {
    **dict.fromkeys(("hero", "frontier_people", "legacy_people", "meshy_people",
                     "battle_rigs", "regional_workers"), "human"),
    **dict.fromkeys(("village_navigation", "raid_motion", "cinematic_people"), "human_world"),
    "service_gear": "attached", "meshy_gear": "attached", "distant_ranks": "crowd",
}
REQUIRED_PLANNED = {"horse_and_other_animals": "animal", "mounted_units": "rider",
                    "rolling_machines": "wheeled", "articulated_equipment": "articulated"}
SUPPORT = {"assets/animations/hero_cc0_library.tres", "main.tscn",
           *(f"assets/characters/hero_hand_grip_{i}.res" for i in range(4)),
           # Mode entry scenes: one root node with its classified script, no motion data.
           "scenes/city_support_district.tscn", "scenes/roman_material_lab/material_preview.tscn",
           "scenes/viva_country/country_walk.tscn", "scenes/viva_roma/closeup_lab.tscn",
           "scenes/world_expansion/preview.tscn"}
# A support scene may only reference scripts and static presentation settings.
# Embedded clips, rigs, attachments or instanced scenes need a motion family.
SCENE_MOTION_RE = re.compile(r'type="(?:Animation\w*|Skeleton3D|BoneAttachment3D|PackedScene|MultiMesh\w*|GPUParticles3D|CPUParticles3D)"'
                             r'|\binstance\s*=|\binstance_placeholder\s*=')
HASH_RE = re.compile(r"^[0-9a-f]{64}$")


def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def json_read(path: Path):
    """Reject ambiguous JSON, including duplicate fields and non-finite numbers."""
    def pairs(items):
        result = {}
        for key, value in items:
            if key in result:
                raise ValueError(f"{path.name}: duplicate JSON field {key}")
            result[key] = value
        return result

    def invalid_constant(value):
        raise ValueError(f"{path.name}: invalid JSON number {value}")

    def finite_float(value):
        number = float(value)
        if not math.isfinite(number):
            raise ValueError(f"{path.name}: non-finite JSON number")
        return number

    return json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=pairs,
                      parse_constant=invalid_constant, parse_float=finite_float)


def finite_number(value) -> bool:
    if type(value) not in (int, float):
        return False
    try:
        return math.isfinite(value)
    except OverflowError:
        return False


def object_value(value, label: str) -> dict:
    if not isinstance(value, dict):
        raise ValueError(label + " must be an object")
    return value


def list_value(value, label: str) -> list:
    if not isinstance(value, list):
        raise ValueError(label + " must be an array")
    return value


def strings(value, label: str) -> list[str]:
    values = list_value(value, label)
    if any(not isinstance(item, str) or not item.strip() for item in values):
        raise ValueError(label + " must contain nonempty strings")
    if len(values) != len(set(values)):
        raise ValueError(label + " contains duplicates")
    return values


def regular_file(root: Path, path: Path) -> bool:
    """A symlink in a parent is as untrustworthy as a symlink at the leaf."""
    root = root.resolve()
    try:
        relative = path.absolute().relative_to(root)
    except ValueError:
        return False
    cursor = root
    for part in relative.parts:
        cursor /= part
        if cursor.is_symlink():
            return False
    return path.is_file()


def excluded(relative: Path) -> bool:
    return (relative.parts[0] in {".godot", ".git", "android"}
            or relative.as_posix().startswith("assets/meshy/source/"))


def inventory(project: Path) -> tuple[set[str], set[str]]:
    models, scripts = set(), set()
    for path in project.rglob("*"):
        rel = path.relative_to(project)
        if excluded(rel) or rel.parts[0] == "tests":
            continue
        if path.is_symlink():
            raise ValueError("Runtime source contains a symlink: " + rel.as_posix())
        if not path.is_file():
            continue
        if path.suffix.lower() in MODEL_EXT:
            models.add(rel.as_posix())
        if path.suffix.lower() in SCRIPT_EXT:
            scripts.add(rel.as_posix())
    return models, scripts


def source_commit(root: Path) -> str:
    value = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip()
    if not re.fullmatch(r"[0-9a-f]{40}", value):
        raise ValueError("Missing exact source revision")
    return value


def derived_texture_inputs(project: Path, tracked: set[str]) -> dict[Path, bytes | None]:
    """Identify only proven GLB extraction outputs, preserving import settings.

    Godot writes a fresh UID for each untracked extracted image on a clean
    machine. Its image bytes are already in the source GLB. Both identities
    are derived; independently authored textures and every importer setting
    remain part of the acceptance fingerprint.
    """
    result = {}
    candidates = [*(project / "assets/characters").glob("frontier_*.glb"),
                  *(project / "assets/meshy/characters").glob("*.glb"),
                  *(project / "assets/meshy/equipment").glob("*.glb")]
    for source in candidates:
        data = source.read_bytes()
        if len(data) < 28:
            continue
        magic, version, total, size, kind = struct.unpack_from("<4sIIII", data)
        if magic != b"glTF" or version != 2 or total != len(data) or kind != 0x4E4F534A or size > len(data) - 28:
            continue
        document = json.loads(data[20:20 + size])
        if not isinstance(document, dict):
            continue
        buffers = document.get("buffers", [])
        if len(buffers) != 1 or "uri" in buffers[0]:
            continue
        bin_size, bin_kind = struct.unpack_from("<II", data, 20 + size)
        start = 28 + size
        if bin_kind != 0x004E4942 or start + bin_size > len(data):
            continue
        for index, image in enumerate(document.get("images", [])):
            if not isinstance(image, dict) or type(image.get("bufferView")) is not int:
                continue
            view_index = image["bufferView"]
            views = document.get("bufferViews", [])
            if not 0 <= view_index < len(views):
                continue
            view = views[view_index]
            extension = {"image/png": ".png", "image/jpeg": ".jpg"}.get(image.get("mimeType"))
            name = image.get("name", "Image_" + str(index))
            if not extension or not isinstance(name, str) or not safe_relative(name) or "/" in name:
                continue
            texture = source.with_name(source.stem + "_" + name + extension)
            if texture.relative_to(project).as_posix() in tracked or not texture.is_file():
                continue
            offset, length = view.get("byteOffset", 0), view.get("byteLength")
            if (view.get("buffer", 0) != 0 or type(offset) is not int or type(length) is not int
                    or offset < 0 or length < 0 or offset + length > bin_size):
                continue
            if not regular_file(project, texture) or texture.read_bytes() != data[start + offset:start + offset + length]:
                raise ValueError("Extracted texture differs from its embedded GLB source: " + str(texture))
            result[texture] = None
            settings = texture.with_name(texture.name + ".import")
            if settings.is_file() and settings.relative_to(project).as_posix() not in tracked:
                if not regular_file(project, settings):
                    raise ValueError("Extracted texture import settings are not a regular file")
                normalized = re.sub(r'^uid="uid://[^"\r\n]+"\r?\n', "", settings.read_text(encoding="utf-8"), flags=re.M)
                result[settings] = normalized.encode("utf-8")
    return result


def source_fingerprint(root: Path) -> str:
    """Bind evidence to actual project bytes, including textures and tests.

    Ignore only generated editor cache/UID files and unexported source staging.
    Tracked import settings are deliberately included.
    Review records are separate, so approving evidence does not change the
    production fingerprint. New untracked files are not silently ignored.
    """
    root = root.resolve()
    paths = []
    project = root / "prototype"
    tracked = subprocess.check_output(["git", "ls-files", "-z", "--", "prototype"], cwd=root).decode("utf-8").split("\0")
    tracked = {path.removeprefix("prototype/") for path in tracked if path.startswith("prototype/")}
    derived = derived_texture_inputs(project, tracked)
    for path in project.rglob("*"):
        rel = path.relative_to(project)
        if excluded(rel):
            continue
        if path.is_symlink():
            raise ValueError("Source contains a symlink: " + rel.as_posix())
        if path.is_file() and path.suffix not in {".uid", ".tmp", ".bak"} and not (path in derived and derived[path] is None):
            paths.append(path)
    for name in ("quality/motion_contract.json", "tools/motion_quality_gate.py",
                 "tools/check_prototype.py", "tools/build_android_prototype.py",
                 "tools/publish_village_download.py", "tools/characters/capture_motion_quality.py",
                 ".github/workflows/android-prototype.yml"):
        paths.append(root / name)
    h = hashlib.sha256()
    for path in sorted(paths):
        if not regular_file(root.resolve(), path.absolute()):
            raise ValueError("Unverifiable source file: " + str(path))
        h.update(path.relative_to(root).as_posix().encode() + b"\0")
        h.update(hashlib.sha256(derived[path]).digest() if path in derived else bytes.fromhex(digest(path)))
    return h.hexdigest()


def metric_errors(values: dict, limits: dict, label: str) -> list[str]:
    errors = []
    if not isinstance(values, dict):
        return [label + ": metrics must be an object"]
    for key, limit in limits.items():
        v = values.get(key)
        if not finite_number(v) or v < 0:
            errors.append(f"{label}: missing/non-finite/negative metric {key}")
        elif v > limit + 1e-9:
            errors.append(f"{label}: {key}={v:.6g} exceeds {limit:.6g}")
    return errors


def safe_relative(name: str) -> bool:
    return (isinstance(name, str) and bool(name) and "\\" not in name
            and ":" not in name and not any(ord(char) < 32 for char in name)
            and not PurePosixPath(name).is_absolute()
            and ".." not in PurePosixPath(name).parts
            and name == PurePosixPath(name).as_posix() and name != ".")


def support_scene_errors(path: Path) -> list[str]:
    """Reject a text scene that would hide motion behind a support classification."""
    if path.suffix.lower() != ".tscn":
        return []
    text = path.read_text(encoding="utf-8")
    if SCENE_MOTION_RE.search(text):
        return [f"{path.name}: support scene embeds animation, a rig, an attachment or an instanced scene"]
    return []


def inspect_static_glb(path: Path) -> bool:
    with path.open("rb") as f:
        header = f.read(20)
        if len(header) != 20:
            return False
        magic, version, length, chunk, kind = struct.unpack("<4sIIII", header)
        if magic != b"glTF" or version != 2 or length != path.stat().st_size or kind != 0x4E4F534A:
            return False
        if chunk > min(length - 20, 32 * 1024 * 1024):
            return False
        doc = json.loads(f.read(chunk))
    return isinstance(doc, dict) and not doc.get("animations") and not doc.get("skins")


def required_subject_scenarios(family: dict) -> dict[str, set[str]]:
    """Keep core checks mandatory; civilian rigs do not carry military gear."""
    subjects = set(family.get("resources", [])) or {"family:" + family["id"]}
    required = set(family.get("review_scope", []))
    explicit = family.get("subject_scenarios")
    if explicit is None:
        return {subject: set(required) for subject in subjects}
    explicit = object_value(explicit, family["id"] + ".subject_scenarios")
    if set(explicit) != subjects:
        raise ValueError(f"{family['id']}: scenario applicability must name every registered subject")
    result = {}
    for subject in sorted(subjects):
        scenarios = set(strings(explicit[subject], f"{subject}.scenarios"))
        civilian = re.fullmatch(r"assets/characters/frontier_(civilian_man|civilian_woman|elder)_[0-3]\.glb", subject)
        optional = {"military_equipment"} if family.get("profile") == "human" and civilian else set()
        if not scenarios <= required or not required - optional <= scenarios:
            raise ValueError(f"{subject}: applicability cannot remove core motion scenarios")
        result[subject] = scenarios
    if set().union(*result.values()) != required:
        raise ValueError(f"{family['id']}: applicability dropped a family-wide scenario")
    return result


def validate_inventory(root: Path, contract: dict) -> tuple[dict, list[str]]:
    contract = object_value(contract, "Motion contract")
    failures = []
    project = root.resolve() / "prototype"
    models, scripts = inventory(project)
    families = {}
    registered = {}
    if type(contract.get("schema_version")) is not int or contract["schema_version"] != 1 or contract.get("sample_hz") != 60:
        failures.append("Invalid contract schema or sampling frequency")
    for family in list_value(contract.get("families"), "Contract families"):
        family = object_value(family, "Movement family")
        key = family.get("id")
        status, profile = family.get("status"), family.get("profile")
        if not isinstance(key, str) or not key or key in families:
            failures.append("Missing/duplicate movement family")
            continue
        families[key] = family
        if status not in {"active", "inactive", "static", "support"}:
            failures.append(f"{key}: unknown status")
        if status in {"active", "inactive"} and profile not in FAMILY_LIMITS:
            failures.append(f"{key}: missing motion profile")
        for name in ("resources", "required_checks", "review_scope", "open_requirements"):
            strings(family.get(name, []), f"{key}.{name}")
        if status == "active":
            required_subject_scenarios(family)
        if status == "active" and (not family.get("required_checks") or not family.get("review_scope")):
            failures.append(f"{key}: active motion requires tests and visual scenarios")
        if status == "inactive" and family.get("resources"):
            failures.append(f"{key}: inactive movement cannot ship a runtime model")
        for path in family.get("resources", []):
            if not safe_relative(path) or path in registered:
                failures.append(f"{key}: invalid/duplicate resource {path}")
                continue
            registered[path] = key
            if status == "static" and path in models:
                try:
                    if not path.endswith(".glb") or not inspect_static_glb(project / path):
                        failures.append(f"{path}: animated or unknown resource cannot be declared static")
                except (OSError, ValueError, struct.error) as e:
                    failures.append(f"{path}: static inspection failed: {e}")
            if status == "support" and path not in SUPPORT:
                failures.append(f"{path}: new support resource needs an explicit motion classification")
            elif status == "support" and path in models:
                failures.extend(support_scene_errors(project / path))
    for key in sorted(REQUIRED_ACTIVE):
        if families.get(key, {}).get("status") != "active":
            failures.append(f"{key}: existing live movement family was removed/disabled without a new contract review")
        if families.get(key, {}).get("profile") != REQUIRED_PROFILES[key]:
            failures.append(f"{key}: existing motion profile was changed without a new contract review")
    for key, profile in REQUIRED_PLANNED.items():
        if (families.get(key, {}).get("profile") != profile
                or families.get(key, {}).get("status") not in {"active", "inactive"}):
            failures.append(f"{key}: mandatory future motion profile is absent")
    for path in sorted(models - set(registered)):
        failures.append("Unclassified runtime 3D resource: " + path)
    for path in sorted(set(registered) - models):
        failures.append("Registered runtime resource missing: " + path)
    listed_scripts = strings(contract.get("runtime_scripts"), "Runtime scripts")
    if any(not safe_relative(path) for path in listed_scripts):
        failures.append("Invalid runtime script path")
    for path in sorted(scripts - set(listed_scripts)):
        failures.append("Unclassified runtime script: " + path)
    for path in sorted(set(listed_scripts) - scripts):
        failures.append("Registered runtime script missing: " + path)
    for path, owners in object_value(contract.get("procedural_owners"), "Procedural owners").items():
        owners = strings(owners, "Procedural owner families")
        if path not in scripts or not owners or any(owner not in families for owner in owners):
            failures.append("Invalid procedural motion owner: " + path)
    # Staged Meshy source geometry must never slip into any export preset.
    presets = (project / "export_presets.cfg").read_text(encoding="utf-8")
    filters = re.findall(r'^exclude_filter="([^"]*)"', presets, re.M)
    if not filters or any("assets/meshy/source/*" not in f.split(",") for f in filters):
        failures.append("One or more export presets fail to quarantine raw Meshy sources")
    loadouts = object_value(json_read(project / "assets/meshy/loadouts.json"), "Meshy loadouts")
    mounted = False
    for entry in list_value(loadouts.get("loadouts"), "Meshy loadout entries"):
        entry = object_value(entry, "Meshy loadout entry")
        if type(entry.get("runtime_enabled")) is not bool:
            failures.append("Meshy loadout runtime_enabled must be boolean")
        mounted = mounted or entry.get("runtime_enabled") is True and bool(entry.get("mount"))
    if mounted:
        if any(families.get(x, {}).get("status") != "active" for x in ("horse_and_other_animals", "mounted_units")):
            failures.append("Mounted loadout enabled before animal and rider contracts")
    return families, failures


def capture_errors(path: Path) -> list[str]:
    """Decode the video stream; a renamed text file is not movement evidence."""
    probe = shutil.which("ffprobe")
    if not probe:
        return ["ffprobe is required to verify movement capture frames"]
    demuxer = {".mp4": "mov", ".webm": "matroska", ".gif": "gif"}[path.suffix.lower()]
    try:
        result = subprocess.run(
            [probe, "-v", "error", "-protocol_whitelist", "file,pipe", "-f", demuxer,
             "-select_streams", "v:0", "-count_frames", "-show_entries",
             "stream=width,height,nb_read_frames,duration:format=duration", "-of", "json", str(path)],
            capture_output=True, text=True, check=False, timeout=60)
        if result.returncode or result.stderr.strip():
            return ["capture does not decode without errors"]
        data = object_value(json.loads(result.stdout), "Capture metadata")
        streams = list_value(data.get("streams"), "Capture streams")
        if len(streams) != 1:
            return ["capture lacks a video stream"]
        stream = object_value(streams[0], "Video stream")
        duration = float(stream.get("duration", data.get("format", {}).get("duration", 0)))
        frames = int(stream.get("nb_read_frames", 0))
        if (not math.isfinite(duration) or duration < .5 or frames < 2
                or type(stream.get("width")) is not int or stream["width"] < 32
                or type(stream.get("height")) is not int or stream["height"] < 32):
            return ["capture lacks a usable sequence of movement frames"]
    except (OSError, ValueError, TypeError, subprocess.SubprocessError):
        return ["capture frame decoding failed"]
    return []


def review_errors(root: Path, family: dict, reviews: list, fingerprint: str,
                  capture_cache: dict | None = None) -> list[str]:
    key = family["id"]
    if not isinstance(reviews, list) or any(not isinstance(x, dict) for x in reviews):
        return [f"{key}: visual reviews must be an array of objects"]
    records = [x for x in reviews if x.get("family") == key]
    if len(records) != 1:
        return [f"{key}: exact-source visual review missing or duplicated"]
    review = records[0]
    errors = []
    if (review.get("status") != "approved" or review.get("source_fingerprint") != fingerprint
            or not isinstance(review.get("reviewer"), str) or not review["reviewer"].strip()):
        errors.append(f"{key}: visual review is not approved for these actual bytes")
    try:
        scenarios = strings(review.get("scenarios"), "Review scenarios")
        captures = list_value(review.get("captures"), "Review captures")
    except ValueError as error:
        return errors + [f"{key}: {error}"]
    if set(scenarios) != set(family.get("review_scope", [])):
        errors.append(f"{key}: visual review does not cover every required scenario")
    covered = set()
    seen_paths = set()
    for capture in captures:
        if not isinstance(capture, dict):
            errors.append(f"{key}: capture must be an object")
            continue
        name = capture.get("path", "")
        if not safe_relative(name) or not name.startswith("docs/") or Path(name).suffix.lower() not in {".mp4", ".webm", ".gif"}:
            errors.append(f"{key}: missing valid visual capture path")
            continue
        path = root.resolve() / name
        if (name in seen_paths or not regular_file(root, path) or path.stat().st_size <= 1024
                or not HASH_RE.fullmatch(str(capture.get("sha256", ""))) or digest(path) != capture["sha256"]):
            errors.append(f"{key}: capture bytes do not match reviewed evidence: {name}")
            continue
        seen_paths.add(name)
        cache_key = (str(path), capture["sha256"])
        if capture_cache is None or cache_key not in capture_cache:
            decoded_errors = capture_errors(path)
            if capture_cache is not None:
                capture_cache[cache_key] = decoded_errors
        else:
            decoded_errors = capture_cache[cache_key]
        errors.extend(f"{key}: {name}: {error}" for error in decoded_errors)
        if digest(path) != capture["sha256"]:
            errors.append(f"{key}: capture changed during frame verification: {name}")
        try:
            capture_scenarios = strings(capture.get("scenarios"), "Capture scenarios")
            if not set(capture_scenarios) <= set(scenarios):
                errors.append(f"{key}: capture claims an unknown scenario")
            covered.update(capture_scenarios)
        except ValueError as error:
            errors.append(f"{key}: {error}")
    if not set(family["review_scope"]) <= covered:
        errors.append(f"{key}: reviewed captures do not cover all scenarios")
    return errors


def aggregate_metrics(records: list[dict], keys: set[str]) -> dict:
    """Reconstruct reported worst cases from samples, with no missing-as-zero."""
    result = {}
    for record in records:
        values = record.get("metrics", {})
        if not isinstance(values, dict):
            continue
        for key in keys & values.keys():
            value = values[key]
            if not finite_number(value) or value < 0:
                continue
            if key in {"frozen_required_clips", "skin_edge_violations"}:
                result[key] = result.get(key, 0) + value
            else:
                result[key] = max(result.get(key, value), value)
    return result


def aggregate_errors(reported: dict, actual: dict, keys: set[str], label: str) -> list[str]:
    errors = []
    if not isinstance(reported, dict):
        return [f"{label}: aggregate metrics must be an object"]
    for key in sorted(keys):
        value, observed = reported.get(key), actual.get(key)
        if (not finite_number(value) or not finite_number(observed)
                or not math.isclose(value, observed, rel_tol=1e-6, abs_tol=1e-9)):
            errors.append(f"{label}: aggregate {key} does not match actual samples")
    return errors


def rig_clip_errors(clip: dict, label: str) -> list[str]:
    if not isinstance(clip, dict):
        return [f"{label}: skeletal clip must be an object"]
    errors = metric_errors(clip.get("metrics"), RIG_LIMITS, label)
    duration, count = clip.get("duration_s"), clip.get("sample_count")
    if (not isinstance(clip.get("name"), str) or not clip["name"].strip()
            or clip.get("finite") is not True or clip.get("sample_hz") != 60
            or type(count) is not int or count < 2
            or not finite_number(duration) or not 0 < duration <= 30):
        errors.append(f"{label}: missing/invalid finite 60 Hz skeletal samples")
    elif not math.ceil(duration * 60) <= count <= math.ceil(duration * 60) + 2:
        errors.append(f"{label}: frame count does not cover the full clip at 60 Hz")
    if clip.get("errors", []) != []:
        errors.append(f"{label}: skeletal sampling reported errors")
    return errors


def rig_asset_errors(record: dict, label: str) -> list[str]:
    if not isinstance(record, dict):
        return [f"{label}: skeletal asset must be an object"]
    errors = []
    clips = record.get("clips")
    if (record.get("finite") is not True or type(record.get("sample_count")) is not int
            or record["sample_count"] < 60 or not isinstance(clips, list) or not clips):
        return [f"{label}: missing/invalid actual skeletal sampling"]
    names, count = set(), 0
    valid = []
    for clip in clips:
        errors.extend(rig_clip_errors(clip, label))
        if not isinstance(clip, dict):
            continue
        name = clip.get("name")
        if isinstance(name, str):
            if name in names:
                errors.append(f"{label}: duplicate sampled clip {name}")
            names.add(name)
        if type(clip.get("sample_count")) is int:
            count += clip["sample_count"]
        valid.append(clip)
    if count != record["sample_count"]:
        errors.append(f"{label}: asset frame count differs from sampled clips")
    if record.get("errors", []) != []:
        errors.append(f"{label}: skeletal sampling reported errors: {record.get('errors')}")
    errors.extend(metric_errors(record.get("metrics"), RIG_LIMITS, label))
    errors.extend(aggregate_errors(record.get("metrics"), aggregate_metrics(valid, set(RIG_LIMITS)),
                                   set(RIG_LIMITS), label))
    return errors


def family_sample_errors(family: dict, observed: dict) -> list[str]:
    key, profile = family["id"], family["profile"]
    if not isinstance(observed, dict):
        return [f"{key}: measured family must be an object"]
    errors = []
    subjects = set(family.get("resources", [])) or {"family:" + key}
    try:
        actual_subjects = set(strings(observed.get("subjects"), key + ".subjects"))
        scenarios = set(strings(observed.get("scenarios"), key + ".scenarios"))
    except ValueError as error:
        return [str(error)]
    required = set(family["review_scope"])
    if (actual_subjects != subjects or observed.get("sample_hz") != 60
            or type(observed.get("sample_count")) is not int or observed["sample_count"] < 60
            or not required <= scenarios):
        errors.append(f"{key}: incomplete measured subjects, frames or required motion scenarios")
    if observed.get("errors", []) != [] or observed.get("fatal", []) != []:
        errors.append(f"{key}: runtime sampling reported errors")
    limits = FAMILY_LIMITS[profile]
    errors.extend(metric_errors(observed.get("metrics"), limits, key))
    samples = observed.get("scenario_samples")
    if not isinstance(samples, list) or not samples:
        errors.append(f"{key}: actual subject/scenario samples are missing")
        samples = []
    coverage, metric_coverage, valid_samples = set(), {subject: set() for subject in subjects}, []
    for sample in samples:
        if not isinstance(sample, dict):
            errors.append(f"{key}: scenario sample must be an object")
            continue
        subject, scenario = sample.get("subject"), sample.get("scenario")
        if (not isinstance(subject, str) or subject not in subjects
                or not isinstance(scenario, str) or scenario not in scenarios):
            errors.append(f"{key}: scenario sample names an unregistered subject/scenario")
            continue
        if (sample.get("finite") is not True or sample.get("sample_hz") != 60
                or type(sample.get("sample_count")) is not int or sample["sample_count"] < 2
                or sample.get("errors", []) != []):
            errors.append(f"{key}: invalid 60 Hz sample for {subject}/{scenario}")
        values = sample.get("metrics")
        if not isinstance(values, dict) or not values:
            errors.append(f"{key}: actual scenario has no measured metrics: {subject}/{scenario}")
            continue
        unknown = values.keys() - limits.keys()
        if unknown:
            errors.append(f"{key}: unknown scenario metrics: {sorted(unknown)}")
        errors.extend(metric_errors(values, {name: limits[name] for name in values.keys() & limits.keys()},
                                    f"{key}/{subject}/{scenario}"))
        coverage.add((subject, scenario))
        metric_coverage[subject].update(values.keys() & limits.keys())
        valid_samples.append(sample)
    applicability = required_subject_scenarios(family)
    missing = {(subject, scenario) for subject in subjects for scenario in applicability[subject]} - coverage
    if missing:
        errors.append(f"{key}: missing actual samples for {len(missing)} required subject/scenario pairs")
    for subject, covered in metric_coverage.items():
        if set(limits) - covered:
            errors.append(f"{key}/{subject}: profile metrics were not all measured for this subject")
    errors.extend(aggregate_errors(observed.get("metrics"), aggregate_metrics(valid_samples, set(limits)),
                                   set(limits), key))
    if profile in RIG_PROFILES:
        clips = observed.get("actual_runtime_clips")
        if not isinstance(clips, list) or not clips:
            errors.append(f"{key}: actual production rig samples are missing")
            clips = []
        runtime_subjects, seen, valid_clips = set(), set(), []
        for clip in clips:
            errors.extend(rig_clip_errors(clip, key + " runtime"))
            if not isinstance(clip, dict):
                continue
            subject, name = clip.get("subject"), clip.get("name")
            if not isinstance(subject, str) or subject not in subjects or not isinstance(name, str):
                errors.append(f"{key}: runtime rig sample lacks a registered subject/name")
                continue
            if (subject, name) in seen:
                errors.append(f"{key}: duplicate runtime clip {subject}/{name}")
            seen.add((subject, name))
            runtime_subjects.add(subject)
            valid_clips.append(clip)
        if runtime_subjects != subjects:
            errors.append(f"{key}: production rig samples do not cover every registered subject")
        errors.extend(metric_errors(observed.get("runtime_rig_metrics"), RIG_LIMITS, key + " runtime"))
        errors.extend(aggregate_errors(observed.get("runtime_rig_metrics"), aggregate_metrics(valid_clips, set(RIG_LIMITS)),
                                       set(RIG_LIMITS), key + " runtime"))
    return errors


def evaluate(root: Path, evidence: Path) -> dict:
    root, evidence = root.resolve(), evidence.resolve()
    contract = json_read(root / "quality/motion_contract.json")
    families, failures = validate_inventory(root, contract)
    fingerprint = source_fingerprint(root)
    commit = source_commit(root)
    engine_path, measured_path = evidence / "validation_report.json", evidence / "motion-measurements.json"
    reviews_path = root / "quality/motion_reviews.json"
    tracked_paths = (engine_path, measured_path, reviews_path)
    before = {}
    for path in tracked_paths:
        if path.exists() and not regular_file(root if path == reviews_path else evidence, path):
            raise ValueError("Evidence is not a regular file: " + path.name)
        before[path] = digest(path) if path.is_file() else None
    engine = object_value(json_read(engine_path), "Engine report") if engine_path.is_file() else {}
    measured = object_value(json_read(measured_path), "Motion measurements") if measured_path.is_file() else {}
    if engine.get("passed") is not True or engine.get("motion_source_fingerprint") != fingerprint or engine.get("source_commit") != commit:
        failures.append("Engine evidence is missing, failed or belongs to different source bytes/revision")
    if (measured.get("source_fingerprint") != fingerprint or measured.get("sample_hz") != 60
            or type(measured.get("schema_version")) is not int or measured["schema_version"] != 1):
        failures.append("Motion measurement evidence missing or stale")
    if measured.get("fatal") != []:
        failures.append("Motion sampling has missing or nonempty fatal-error evidence")
    if measured.get("complete") is not True:
        failures.append("Motion sampling is an incomplete checkpoint or diagnostic subset")
    checks = {}
    for check in list_value(engine.get("checks", []), "Engine checks"):
        check = object_value(check, "Engine check")
        name = check.get("check")
        if not isinstance(name, str) or not name or name in checks:
            raise ValueError("Missing/duplicate engine evidence identifier")
        checks[name] = check
        if check.get("passed") is not True or type(check.get("exit_code")) is not int or check["exit_code"] != 0:
            failures.append("An engine check did not pass: " + name)
    if checks.get("motion_measurement", {}).get("passed") is not True:
        failures.append("Actual Godot movement measurement did not complete")
    assets = object_value(measured.get("assets", {}), "Measured assets")
    expected_assets = {path for family in families.values() if family.get("status") == "active"
                       and family.get("profile") in RIG_PROFILES for path in family.get("resources", [])}
    if set(assets) != expected_assets:
        failures.append("Skeletal measurement inventory differs from the active runtime resources")
    family_metrics = object_value(measured.get("family_metrics", {}), "Measured families")
    if set(family_metrics) - families.keys():
        failures.append("Measurement contains an unregistered movement family")
    review_document = object_value(json_read(reviews_path), "Visual review document")
    if type(review_document.get("schema_version")) is not int or review_document["schema_version"] != 1:
        failures.append("Invalid visual review schema")
    reviews = list_value(review_document.get("reviews"), "Visual reviews")
    for review in reviews:
        review = object_value(review, "Visual review")
        if not isinstance(review.get("family"), str) or review["family"] not in families:
            failures.append("Visual review names an unregistered movement family")
    capture_cache = {}
    results = []
    for key, family in families.items():
        status = family.get("status")
        errors = []
        if status in {"active", "support"}:
            for name in family.get("required_checks", []):
                if checks.get(name, {}).get("passed") is not True:
                    errors.append(f"{key}: required engine scenario not passed: {name}")
        if status == "active":
            profile = family["profile"]
            if profile in RIG_PROFILES:
                for path in family["resources"]:
                    if not path.endswith(".glb"):
                        errors.append(f"{key}: skeletal resource requires actual GLB motion measurement: {path}")
                        continue
                    errors.extend(rig_asset_errors(assets.get(path, {}), path))
            if profile in FAMILY_LIMITS:
                errors.extend(family_sample_errors(family, family_metrics.get(key, {})))
            else:
                errors.append(f"{key}: no valid metric profile")
            for reason in family.get("open_requirements", []):
                errors.append(f"{key}: unresolved: {reason}")
            errors.extend(review_errors(root, family, reviews, fingerprint, capture_cache))
        failures.extend(errors)
        results.append({"id": key, "profile": family["profile"], "status": status,
                        "passed": not errors, "failures": errors})
    models, scripts = inventory(root / "prototype")
    for path, previous in before.items():
        if previous != (digest(path) if path.is_file() else None):
            failures.append("Evidence changed during verification: " + path.name)
    if source_fingerprint(root) != fingerprint or source_commit(root) != commit:
        failures.append("Project source changed during movement verification")
    return {"schema_version": 1, "passed": not failures, "source_commit": commit,
            "source_fingerprint": fingerprint, "sample_hz": 60, "resource_count": len(models),
            "script_count": len(scripts), "measured_assets": len(assets),
            "engine_report_sha256": before[engine_path],
            "measurement_report_sha256": before[measured_path],
            "review_report_sha256": before[reviews_path],
            "rig_limits": RIG_LIMITS, "family_limits": FAMILY_LIMITS,
            "families": results, "failures": failures}


def require_export(root: Path, evidence: Path) -> dict:
    root, evidence = root.resolve(), evidence.resolve()
    proof_path = evidence / "motion-gate.json"
    if not regular_file(evidence, proof_path):
        raise ValueError("Motion Quality Gate proof is missing; APK export refused")
    proof_hash = digest(proof_path)
    previous = object_value(json_read(proof_path), "Motion Quality Gate proof")
    current = evaluate(root, evidence)
    if previous != current or current.get("passed") is not True or digest(proof_path) != proof_hash:
        raise ValueError("Motion Quality Gate did not pass for these source bytes; APK export refused")
    return current


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--evidence", type=Path, required=True)
    a = p.parse_args()
    a.evidence.mkdir(parents=True, exist_ok=True)
    try:
        report = evaluate(ROOT, a.evidence)
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as error:
        report = {"schema_version": 1, "passed": False, "failures": [str(error)]}
    temporary = a.evidence / ".motion-gate.json.tmp"
    if temporary.is_symlink():
        raise ValueError("Motion gate temporary output must not be a symlink")
    temporary.write_text(json.dumps(report, ensure_ascii=False, allow_nan=False, indent=2) + "\n")
    temporary.replace(a.evidence / "motion-gate.json")
    for failure in report["failures"]:
        print("MOTION_GATE_BLOCKER", failure)
    print("MOTION_QUALITY_GATE_PASS" if report["passed"] else "MOTION_QUALITY_GATE_BLOCKED",
          "blockers=", len(report["failures"]), "measured_assets=", report.get("measured_assets", 0))
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
