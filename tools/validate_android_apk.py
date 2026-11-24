#!/usr/bin/env python3
"""Read-only static validation of an actual IMPERATHEN Android APK.

Uses Python's standard library and existing Android SDK tools. Does not install,
sign, modify, launch, or upload the APK. A static PASS is not a device-test PASS.
Exit codes: 0 = required static checks passed, 1 = failed, 2 = incomplete.
"""

from __future__ import annotations

import argparse
from collections import Counter
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import stat
import struct
import subprocess
import sys
import xml.etree.ElementTree as ET
import zipfile
import zlib


ROOT = Path(__file__).resolve().parents[1]
ANDROID_NS = "{http://schemas.android.com/apk/res/android}"
MAX_ENTRIES = 50000
MAX_EXPANDED_BYTES = 2 * 1024**3
EXPECTED_RESOURCES = (
    "main.tscn",
    "scripts/main.gd",
    "scripts/domain/world_model.gd",
    "scripts/world/game_world.gd",
    "scripts/world/village_art.gd",
    "scripts/ui/game_ui.gd",
    "scripts/ui/touch_pad.gd",
    "scripts/ui/touch_action.gd",
)
CAMPAIGN_RESOURCES = (
    "scripts/ui/runtime_display.gd",
    "scripts/battle/battle_model.gd",
    "scripts/battle/formation_slots.gd",
    "scripts/tactics/valley_scene.gd",
    "scripts/tactics/valley_hud.gd",
    "scripts/strategy/atlas_screen.gd",
    "scripts/strategy/globe.gd",
    "scripts/strategy/origins.gd",
    "scripts/strategy/season_campaign.gd",
    "assets/atlas/earth.jpg",
    "scripts/visuals/soldier_visual.gd",
    "assets/quality_profiles.json",
    *(f"assets/soldiers/{role}_{level}.glb"
      for role in ("heavy", "spear", "archer", "officer") for level in ("near", "mid", "far")),
)
POPULATION_SCRIPT = "scripts/visuals/village_person.gd"
VILLAGE_RESOURCES = (
    POPULATION_SCRIPT,
    *(f"assets/village_characters/villager_{level}.glb" for level in range(4)),
    *(f"assets/village_characters/{role}_{level}.glb"
      for role in ("officer", "heavy", "spear") for level in (2, 3)),
    *(f"assets/village/{asset}.glb" for asset in
      ("market", "workshop", "storehouse", "palisade_bay", "palisade_silhouette", "training_dummy", "timber_billet")),
    *(f"assets/village/{name}.png" for name in ("valdorf_color", "valdorf_normal", "valdorf_orm",
      "track_color", "track_relief", "verge_color", "verge_relief", "sky_clouds")),
)
HERO_FACE_SCRIPT = "scripts/visuals/facial_motion.gd"
HERO_RESOURCES = (
    HERO_FACE_SCRIPT,
    *(f"assets/characters/hero_quality_{level}.glb" for level in range(4)),
)
FRONTIER_SCRIPT = "scripts/story/frontier_chapter.gd"
FRONTIER_RESOURCES = (
    FRONTIER_SCRIPT,
    "scripts/world/village/village_layout.gd",
    "scripts/world/village/village_population.gd",
    "scripts/world/village/frontier_dressing.gd",
    *(f"assets/characters/frontier_{role}_{level}.glb"
      for role in ("civilian_man", "civilian_woman", "elder", "legionary", "officer", "spearman", "archer")
      for level in range(4)),
)
OPENING_SCRIPT = "scripts/story/opening_story.gd"
OPENING_RESOURCES = (
    OPENING_SCRIPT,
    "scripts/cinematic/opening_director.gd",
    "scripts/cinematic/opening_checkpoint.gd",
    "scripts/ui/opening_overlay.gd",
)
VILLAGE_LIFE_SCRIPT = "scripts/story/village_life.gd"
VILLAGE_LIFE_RESOURCES = (
    VILLAGE_LIFE_SCRIPT,
    "scripts/domain/village_economy.gd",
    "scripts/ui/village_life_panel.gd",
    "scripts/ui/android_village_diagnostics.gd",
    "scripts/world/village_life_world.gd",
    "scripts/world/regional_terrain.gd",
    "scripts/world/world_stream_plan.gd",
)
ACTION_COMBAT_RESOURCES = (
    "scripts/domain/combat_actions.gd",
    "scripts/world/player_action_world.gd",
    "scripts/visuals/character_motion.gd",
    "scripts/visuals/hand_pose.gd",
    "scripts/ui/touch_look.gd",
    "scripts/ui/touch_modal.gd",
    *(f"assets/characters/hero_hand_grip_{lod}.res" for lod in range(4)),
)
CHILDHOOD_RESOURCES = (
    "scripts/story/village_childhood.gd",
    "scripts/domain/unarmed_combat.gd",
    "scripts/visuals/practice_gear.gd",
    "scripts/ui/village_navigation.gd",
    "scripts/world/village/settlement_dressing.gd",
    "scripts/world/regional_village.gd",
)
CAMPAIGN_BIBLE_RESOURCES = (
    "scripts/story/campaign_bible.gd",
    "assets/story/campaign_arc.json",
)
MESHY_REGISTRY_RESOURCES = (
    "scripts/visuals/meshy_asset_registry.gd",
    "scripts/visuals/meshy_loadout_registry.gd",
    "assets/meshy/manifest.json",
    "assets/meshy/loadouts.json",
)
CHAPTER_STORY_RESOURCES = (
    "scripts/story/chapter_abilities.gd",
    "assets/story/chapter1_abilities.json",
    "scripts/story/mission_data.gd",
    "assets/story/missions/band1/index.json",
    *(f"assets/story/missions/band1/I-{number:02d}.json" for number in range(1, 15)),
)
COMPANION_STORY_RESOURCES = (
    "scripts/story/companion_story.gd",
    "scripts/story/companion_follow.gd",
    "scripts/world/companion_world.gd",
)
NPC_BEHAVIOR_RESOURCES = (
    "scripts/domain/npc_behavior.gd",
)
MESHY_CHARACTER_RESOURCES = (
    "scripts/visuals/meshy_character_registry.gd",
    *(f"assets/meshy/characters/{character}_{level}.glb"
      for character in ("unit_roman_signifer", "unit_germanic_axe_fighter")
      for level in range(4)),
)
MESHY_EQUIPMENT_RESOURCES = (
    "scripts/visuals/meshy_equipment.gd",
    *(f"assets/meshy/equipment/{equipment}_{level}.glb"
      for equipment in ("weap_germanic_hand_axe", "gear_germanic_round_shield", "gear_roman_signum")
      for level in range(2)),
)
SERVICE_GEAR_RESOURCES = (
    "scripts/visuals/service_gear.gd",
    "assets/weapons/gladius_lod0.glb",
    "assets/weapons/scutum_lod0.glb",
)
CC0_MOTION_RESOURCES = (
    "scripts/visuals/cc0_gestures.gd",
    "assets/animations/hero_cc0_library.tres",
)
FEATURE_RESOURCE_GROUPS = (
    ("living_frontier_content", FRONTIER_RESOURCES),
    ("cinematic_opening_content", OPENING_RESOURCES),
    ("village_life_content", VILLAGE_LIFE_RESOURCES),
    ("action_combat_content", ACTION_COMBAT_RESOURCES),
    ("childhood_content", CHILDHOOD_RESOURCES),
    ("campaign_bible_content", CAMPAIGN_BIBLE_RESOURCES),
    ("chapter_story_content", CHAPTER_STORY_RESOURCES),
    ("companion_story_content", COMPANION_STORY_RESOURCES),
    ("meshy_registry_content", MESHY_REGISTRY_RESOURCES),
    ("npc_behavior_content", NPC_BEHAVIOR_RESOURCES),
    ("meshy_character_content", MESHY_CHARACTER_RESOURCES),
    ("meshy_equipment_content", MESHY_EQUIPMENT_RESOURCES),
    ("service_gear_content", SERVICE_GEAR_RESOURCES),
    ("cc0_motion_content", CC0_MOTION_RESOURCES),
)
GALLERY_SCRIPT = "scripts/ui/figure_gallery.gd"
PORTRAIT_IDS = (
    "legionary", "auxiliary_spear", "archer", "centurion", "signifer", "emperor",
    "hero_italia", "hero_germania", "hero_han", "hero_wa", "hero_vistula",
    "marcus", "albrun", "lin", "aki", "mira", "adult_italia", "adult_marcus",
)
GALLERY_RESOURCES = (GALLERY_SCRIPT, *(f"assets/portraits/{name}.webp" for name in PORTRAIT_IDS))
ARCHITECTURES = {"arm64-v8a": 183, "x86_64": 62}
TOOL_NAMES = ("aapt", "aapt2", "apkanalyzer", "apksigner", "zipalign", "adb", "emulator", "sdkmanager")


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def add_check(report: dict, identifier: str, status: str, detail: str, *, required: bool = True, **evidence) -> None:
    report["checks"].append({"id": identifier, "status": status, "required": required,
                             "detail": detail, "evidence": evidence})


def version_key(path: Path) -> tuple:
    return tuple(int(value) for value in re.findall(r"\d+", path.name))


def sdk_roots(explicit: list[Path]) -> list[Path]:
    candidates = list(explicit)
    for name in ("ANDROID_HOME", "ANDROID_SDK_ROOT"):
        if os.environ.get(name):
            candidates.append(Path(os.environ[name]))
    candidates += [Path("/opt/android-sdk"), Path("/usr/local/lib/android/sdk"),
                   Path.home() / "Android/Sdk", Path.home() / "Library/Android/sdk"]
    result = []
    for candidate in candidates:
        resolved = candidate.expanduser().resolve()
        if resolved.is_dir() and resolved not in result:
            result.append(resolved)
    return result


def find_tool(name: str, roots: list[Path], explicit: str | None) -> str | None:
    if explicit:
        found = shutil.which(explicit)
        return str(Path(found).resolve()) if found else None
    for sdk in roots:
        candidates = []
        if name in ("aapt", "aapt2", "apksigner", "zipalign"):
            candidates += [folder / name for folder in sorted((sdk / "build-tools").glob("*"), key=version_key, reverse=True)]
        if name in ("apkanalyzer", "sdkmanager"):
            command_dirs = sorted((sdk / "cmdline-tools").glob("*"), key=version_key, reverse=True)
            candidates += [sdk / "cmdline-tools/latest/bin" / name]
            candidates += [folder / "bin" / name for folder in command_dirs]
            candidates += [sdk / "tools/bin" / name]
        if name == "adb":
            candidates.append(sdk / "platform-tools/adb")
        if name == "emulator":
            candidates.append(sdk / "emulator/emulator")
        for candidate in candidates:
            if candidate.is_file() and os.access(candidate, os.X_OK):
                return str(candidate.resolve())
    found = shutil.which(name)
    return str(Path(found).resolve()) if found else None


def run_tool(command: list[str], timeout: int) -> dict:
    try:
        result = subprocess.run(command, capture_output=True, text=True, encoding="utf-8",
                                errors="replace", timeout=timeout, check=False, stdin=subprocess.DEVNULL)
        stdout, stderr = result.stdout, result.stderr
        return {"command": command, "exit_code": result.returncode, "error": None,
                "stdout": stdout, "stderr": stderr}
    except (OSError, subprocess.TimeoutExpired) as error:
        return {"command": command, "exit_code": None, "error": str(error), "stdout": "", "stderr": ""}


def command_evidence(result: dict) -> dict:
    return {"command": result["command"], "exit_code": result["exit_code"], "error": result["error"],
            "stdout_tail": result["stdout"][-12000:], "stderr_tail": result["stderr"][-12000:],
            "output_truncated": len(result["stdout"]) > 12000 or len(result["stderr"]) > 12000}


def read_header(archive: zipfile.ZipFile, name: str, length: int) -> bytes:
    with archive.open(name) as stream:
        return stream.read(length)


def resolve_resource(archive: zipfile.ZipFile, names: set[str], source: str) -> dict:
    raw = "assets/" + source
    if raw in names and archive.getinfo(raw).file_size > 0:
        return {"source": source, "entry": raw, "mode": "direct"}
    remap = raw + (".import" if source.endswith((".glb", ".jpg", ".png", ".webp")) else ".remap")
    if remap in names and archive.getinfo(remap).file_size <= 65536:
        text = archive.read(remap).decode("utf-8", errors="replace")
        for match in re.finditer(r'^\s*path(?:\.[\w.-]+)?\s*=\s*"res://([^"\r\n]+)"', text, re.MULTILINE):
            target = "assets/" + match.group(1)
            if target in names and archive.getinfo(target).file_size > 0:
                return {"source": source, "entry": target, "remap": remap, "mode": "remapped"}
    extensions = {".gd": (".gdc", ".gde"), ".tscn": (".scn",)}
    path = PurePosixPath(raw)
    for extension in extensions.get(path.suffix, ()):
        candidate = str(path.with_suffix(extension))
        if candidate in names and archive.getinfo(candidate).file_size > 0:
            return {"source": source, "entry": candidate, "mode": "converted"}
    return {"source": source, "entry": None, "mode": "missing"}


def record_payload_hash(archive: zipfile.ZipFile, resource: dict) -> None:
    """Record the actual exported payload, which may differ from source bytes."""
    if resource["entry"] is None:
        return
    digest = hashlib.sha256()
    with archive.open(resource["entry"]) as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    resource["size_bytes"] = archive.getinfo(resource["entry"]).file_size
    resource["sha256"] = digest.hexdigest()
    if resource.get("remap"):
        resource["remap_sha256"] = hashlib.sha256(archive.read(resource["remap"])).hexdigest()


def inspect_zip(apk: Path, report: dict, expected_abi: str, source_root: Path) -> bool:
    try:
        with zipfile.ZipFile(apk) as archive:
            entries = archive.infolist()
            files = [item for item in entries if not item.is_dir()]
            names = {item.filename for item in files}
            duplicates = [name for name, count in Counter(item.filename for item in entries).items() if count > 1]
            unsafe = []
            for item in entries:
                path = PurePosixPath(item.filename)
                if (path.is_absolute() or ".." in path.parts or "\\" in item.filename
                        or "\x00" in item.filename or item.flag_bits & 1
                        or stat.S_ISLNK(item.external_attr >> 16)):
                    unsafe.append(item.filename)
            expanded = sum(item.file_size for item in files)
            bounded = len(entries) <= MAX_ENTRIES and expanded <= MAX_EXPANDED_BYTES
            add_check(report, "zip_structure", "pass" if not duplicates and not unsafe and bounded else "fail",
                      "ZIP directory inspected before reading payloads; no extraction is performed.",
                      entries=len(entries), expanded_bytes=expanded, duplicate_entries=duplicates[:30],
                      unsafe_entries=unsafe[:30], within_limits=bounded)
            if duplicates or unsafe or not bounded:
                return False
            bad_crc = archive.testzip()
            add_check(report, "zip_crc", "pass" if bad_crc is None else "fail",
                      "All ZIP member payloads were decompressed and CRC checked.", damaged_entry=bad_crc)
            if bad_crc is not None:
                return False
            required = ("AndroidManifest.xml", "resources.arsc", "classes.dex")
            missing = [name for name in required if name not in names or archive.getinfo(name).file_size == 0]
            add_check(report, "apk_core_entries", "pass" if not missing else "fail",
                      "A renamed project ZIP is not accepted as an Android application.", missing=missing)
            if "AndroidManifest.xml" in names:
                size = archive.getinfo("AndroidManifest.xml").file_size
                header = read_header(archive, "AndroidManifest.xml", 8)
                valid = len(header) == 8 and struct.unpack("<HHI", header) == (3, 8, size)
                add_check(report, "binary_manifest_header", "pass" if valid else "fail",
                          "Compiled Android binary XML container checked; semantic decoding is separate.", bytes=size)
            if "resources.arsc" in names:
                header = read_header(archive, "resources.arsc", 8)
                valid = len(header) == 8 and struct.unpack_from("<H", header)[0] == 2
                add_check(report, "resource_table_header", "pass" if valid else "fail",
                          "Compiled Android resource table header checked.")
            if "classes.dex" in names:
                header = read_header(archive, "classes.dex", 112)
                valid = (len(header) == 112 and header[:4] == b"dex\n" and header[4:7].isdigit()
                         and header[7] == 0 and struct.unpack_from("<I", header, 32)[0] == archive.getinfo("classes.dex").file_size)
                add_check(report, "dex_header", "pass" if valid else "fail",
                          "DEX magic and declared file length checked; no bytecode correctness claim.")
            library = f"lib/{expected_abi}/libgodot_android.so"
            available_abis = sorted({name.split("/")[1] for name in names if name.startswith("lib/") and name.endswith(".so") and len(name.split("/")) == 3})
            native_valid = False
            machine = None
            if library in names:
                header = read_header(archive, library, 64)
                if len(header) == 64 and header[:4] == b"\x7fELF" and header[4] == 2 and header[5] == 1:
                    machine = struct.unpack_from("<H", header, 18)[0]
                    native_valid = machine == ARCHITECTURES[expected_abi] and struct.unpack_from("<H", header, 16)[0] == 3
            add_check(report, "godot_native_library", "pass" if native_valid else "fail",
                      "Expected Godot shared library must be a 64-bit little-endian ELF for the requested architecture.",
                      expected_abi=expected_abi, entry=library, elf_machine=machine, available_abis=available_abis)
            report["available_abis"] = available_abis
            config = "assets/project.binary" if "assets/project.binary" in names else "assets/project.godot"
            valid_config = False
            if config in names:
                prefix = read_header(archive, config, 4096)
                valid_config = prefix.startswith(b"ECFG") if config.endswith(".binary") else b"config_version=" in prefix
            # Older village snapshots predate the campaign and portrait gallery. The
            # source requirement also detects a new APK that omitted the entire feature.
            required_resources = EXPECTED_RESOURCES
            campaign_script = "scripts/battle/battle_model.gd"
            if (source_root / campaign_script).is_file() or resolve_resource(archive, names, campaign_script)["entry"]:
                required_resources += CAMPAIGN_RESOURCES
            if (source_root / POPULATION_SCRIPT).is_file() or resolve_resource(archive, names, POPULATION_SCRIPT)["entry"]:
                required_resources += VILLAGE_RESOURCES
            if (source_root / GALLERY_SCRIPT).is_file() or resolve_resource(archive, names, GALLERY_SCRIPT)["entry"]:
                required_resources += GALLERY_RESOURCES
            hero_in_source = (source_root / HERO_FACE_SCRIPT).is_file()
            hero_in_archive = any(resolve_resource(archive, names, source)["entry"] for source in HERO_RESOURCES)
            require_hero = hero_in_source or hero_in_archive
            if require_hero:
                required_resources += HERO_RESOURCES
            features = []
            for identifier, resources in FEATURE_RESOURCE_GROUPS:
                required_by_source = any((source_root / source).is_file() for source in resources)
                detected_in_archive = any(resolve_resource(archive, names, source)["entry"] for source in resources)
                if required_by_source or detected_in_archive:
                    required_resources += resources
                    features.append((identifier, resources, required_by_source, detected_in_archive))
            resolved = [resolve_resource(archive, names, source) for source in required_resources]
            missing_resources = [item["source"] for item in resolved if item["entry"] is None]
            packs = sorted(name for name in names if name.startswith("assets/") and name.endswith(".pck"))
            if require_hero:
                hero_payloads = [item for item in resolved if item["source"] in HERO_RESOURCES]
                for item in hero_payloads:
                    record_payload_hash(archive, item)
                missing_hero = [item["source"] for item in hero_payloads if item["entry"] is None]
                status = "incomplete" if not valid_config and packs else "fail" if missing_hero else "pass"
                add_check(report, "hero_character_content", status,
                          "The anatomical hero requires all four LOD resources and the facial-motion script in the actual APK, including resolved remaps.",
                          required_by_source=hero_in_source, detected_in_archive=hero_in_archive,
                          resources=hero_payloads, missing_resources=missing_hero,
                          hash_scope="SHA-256 of exported APK payloads and remaps; not an assertion that transformed bytes equal the local sources.")
            for identifier, resources, required_by_source, detected_in_archive in features:
                payloads = [item for item in resolved if item["source"] in resources]
                for item in payloads:
                    record_payload_hash(archive, item)
                missing_payloads = [item["source"] for item in payloads if item["entry"] is None]
                status = "incomplete" if not valid_config and packs else "fail" if missing_payloads else "pass"
                add_check(report, identifier, status,
                          "Every required feature script and model must resolve to nonempty bytes inside this APK.",
                          required_by_source=required_by_source, detected_in_archive=detected_in_archive,
                          resources=payloads, missing_resources=missing_payloads,
                          hash_scope="SHA-256 of actual exported APK payloads and import remaps; not a device runtime claim.")
            if not valid_config and packs:
                add_check(report, "godot_project_content", "incomplete",
                          "A packed Godot project was found, but this checker does not inspect PCK indexes. Project contents are not confirmed.", packs=packs)
            else:
                add_check(report, "godot_project_content", "pass" if valid_config and not missing_resources else "fail",
                          "Godot project configuration and the prototype's required scene/scripts must be present, including resolved remaps.",
                          config=config if config in names else None, config_header_valid=valid_config,
                          resources=resolved, missing_resources=missing_resources)
            signature_indicators = {"v1_certificate_entries": sorted(name for name in names if re.match(r"^META-INF/[^/]+\.(RSA|DSA|EC)$", name, re.I))}
            with apk.open("rb") as stream:
                stream.seek(max(0, archive.start_dir - 16))
                signature_indicators["apk_signing_block_marker"] = stream.read(16) == b"APK Sig Block 42"
            report["signature_indicators"] = signature_indicators
            return not missing
    except (zipfile.BadZipFile, zipfile.LargeZipFile, OSError, RuntimeError, NotImplementedError, ValueError, struct.error, EOFError, zlib.error) as error:
        add_check(report, "zip_read", "fail", "APK ZIP parsing or payload validation failed.", error=str(error))
        return False


def parse_badging(text: str) -> dict:
    package_line = next((line for line in text.splitlines() if line.startswith("package:")), "")
    fields = dict(re.findall(r"([A-Za-z][A-Za-z0-9_-]*)='([^']*)'", package_line))
    result = {"package": fields.get("name"), "version_code": fields.get("versionCode"),
              "version_name": fields.get("versionName"), "debuggable": "application-debuggable" in text}
    for label, key in (("sdkVersion", "min_sdk"), ("targetSdkVersion", "target_sdk")):
        match = re.search(r"^" + label + r":'([^']*)'", text, re.MULTILINE)
        result[key] = match.group(1) if match else None
    launch = re.search(r"^launchable-activity: name='([^']+)'", text, re.MULTILINE)
    result["launchable_activity"] = launch.group(1) if launch else None
    result["permissions"] = sorted(set(re.findall(r"^uses-permission[^:]*: name='([^']+)'", text, re.MULTILINE)))
    return result


def manifest_boolean(value: str | None, default: bool | None) -> bool | None:
    if value is None:
        return default
    return {"true": True, "false": False, "1": True, "0": False}.get(value.lower())


def component_name(package: str, name: str | None) -> str | None:
    if not name:
        return None
    if name.startswith("."):
        return package + name
    return name if "." in name else package + "." + name


def parse_xml_manifest(text: str) -> dict:
    manifest = ET.fromstring(text)
    if manifest.tag != "manifest":
        raise ValueError("Decoded XML root is not an Android manifest.")
    sdk = manifest.find("uses-sdk")
    application = manifest.find("application")
    result = {"package": manifest.get("package"), "version_code": manifest.get(ANDROID_NS + "versionCode"),
              "version_name": manifest.get(ANDROID_NS + "versionName"),
              "min_sdk": sdk.get(ANDROID_NS + "minSdkVersion") if sdk is not None else None,
              "target_sdk": sdk.get(ANDROID_NS + "targetSdkVersion") if sdk is not None else None,
              "debuggable": application.get(ANDROID_NS + "debuggable", "false") == "true" if application is not None else None,
              "launchable_activity": None,
              "permissions": sorted({node.get(ANDROID_NS + "name", "") for node in manifest.findall("uses-permission")})}
    diagnostics = {"application_present": application is not None, "application_enabled": None,
                   "components": [], "unresolved_candidate": False}
    result["launcher_diagnostics"] = diagnostics
    if application is not None:
        application_enabled = manifest_boolean(application.get(ANDROID_NS + "enabled"), True)
        diagnostics["application_enabled"] = application_enabled
        target_sdk = result["target_sdk"] or result["min_sdk"] or "1"
        target_sdk_number = int(target_sdk) if target_sdk.isdigit() else None
        preceding_activities = {}
        for activity in application:
            if activity.tag not in ("activity", "activity-alias"):
                continue
            name = component_name(result["package"] or "", activity.get(ANDROID_NS + "name"))
            filters = [{"actions": sorted({item.get(ANDROID_NS + "name", "") for item in intent.findall("action")}),
                        "categories": sorted({item.get(ANDROID_NS + "name", "") for item in intent.findall("category")})}
                       for intent in activity.findall("intent-filter")]
            matching_filter = any("android.intent.action.MAIN" in item["actions"] and
                                  "android.intent.category.LAUNCHER" in item["categories"] for item in filters)
            enabled = manifest_boolean(activity.get(ANDROID_NS + "enabled"), True)
            exported_raw = activity.get(ANDROID_NS + "exported")
            exported = manifest_boolean(exported_raw, bool(filters) if target_sdk_number is not None and target_sdk_number < 31 else None)
            reasons = []
            unknown = []
            if not name:
                reasons.append("missing_component_name")
            if not matching_filter:
                reasons.append("no_MAIN_and_LAUNCHER_in_same_intent_filter")
            for label, value in (("application_enabled", application_enabled), ("component_enabled", enabled), ("component_exported", exported)):
                if value is False:
                    reasons.append(label + "_false")
                elif value is None:
                    unknown.append(label + "_unresolved")
            if exported_raw is None and target_sdk_number is not None and target_sdk_number >= 31 and filters:
                reasons.append("explicit_exported_required_for_target_sdk_31_or_newer")
            component = {"type": activity.tag, "name": name, "enabled": enabled, "exported": exported,
                         "exported_attribute": exported_raw, "intent_filters": filters,
                         "has_launcher_filter": matching_filter}
            if activity.tag == "activity-alias":
                target_name = component_name(result["package"] or "", activity.get(ANDROID_NS + "targetActivity"))
                target = preceding_activities.get(target_name)
                component["target_activity"] = target_name
                component["target_declared_before_alias"] = target is not None
                component["target_enabled"] = target["enabled"] if target is not None else None
                # The alias owns its exported attribute; its target may correctly be private.
                component["target_exported"] = target["exported"] if target is not None else None
                if target is None:
                    reasons.append("alias_target_not_declared_before_alias")
                elif target["enabled"] is False:
                    reasons.append("alias_target_disabled")
                elif target["enabled"] is None:
                    unknown.append("alias_target_enabled_unresolved")
            else:
                preceding_activities[name] = component
            component["rejection_reasons"] = reasons
            component["unresolved_attributes"] = unknown
            component["usable_launcher"] = not reasons and not unknown
            diagnostics["components"].append(component)
            if component["usable_launcher"] and result["launchable_activity"] is None:
                result["launchable_activity"] = name
            if matching_filter and not reasons and unknown:
                diagnostics["unresolved_candidate"] = True
    return result


def inspect_manifest(apk: Path, report: dict, tools: dict, expected_package: str, timeout: int) -> None:
    attempts = []
    metadata = None
    for name in ("aapt", "aapt2", "apkanalyzer"):
        if not tools.get(name):
            continue
        command = [tools[name], "manifest", "print", str(apk)] if name == "apkanalyzer" else [tools[name], "dump", "badging", str(apk)]
        attempt = run_tool(command, timeout)
        evidence = command_evidence(attempt)
        attempts.append(evidence)
        if attempt["exit_code"] != 0:
            continue
        try:
            candidate = parse_xml_manifest(attempt["stdout"]) if name == "apkanalyzer" else parse_badging(attempt["stdout"])
        except (ET.ParseError, ValueError) as error:
            evidence["parse_error"] = str(error)
            continue
        if candidate.get("package"):
            candidate["decoded_with"] = name
            evidence["decoded_package"] = candidate["package"]
            evidence["decoded_launcher"] = candidate.get("launchable_activity")
            # AAPT can omit activity-alias launchers. A package-only result is not
            # a reason to stop before decoding the actual manifest XML.
            if name == "apkanalyzer":
                metadata = candidate
                break
            if metadata is None or (not metadata.get("launchable_activity") and candidate.get("launchable_activity")):
                metadata = candidate
    if metadata is None:
        status = "not_run" if not attempts else "incomplete"
        add_check(report, "manifest_metadata", status,
                  "No successful SDK-tool decoding of the compiled manifest; package identity and launcher are not confirmed.", attempts=attempts)
        return
    report["manifest"] = metadata
    add_check(report, "manifest_metadata", "pass", "Compiled manifest decoded by an existing Android SDK tool.", attempts=attempts)
    add_check(report, "package_identity", "pass" if metadata["package"] == expected_package else "fail",
              "Decoded package must equal the intended application ID.", expected=expected_package, actual=metadata["package"])
    diagnostics = metadata.get("launcher_diagnostics")
    launcher_status = "pass" if metadata.get("launchable_activity") else "fail"
    if not metadata.get("launchable_activity") and (diagnostics is None or diagnostics["unresolved_candidate"]):
        launcher_status = "incomplete"
    add_check(report, "launcher_activity", launcher_status,
              "A launcher activity or alias must be enabled and exported, with MAIN and LAUNCHER in the same intent filter. A private alias target is permitted. Missing XML evidence never creates a PASS.",
              activity=metadata.get("launchable_activity"), decoded_with=metadata["decoded_with"], diagnostics=diagnostics)


def normalize_signer_sha256(value: str) -> str:
    if not isinstance(value, str) or re.fullmatch(r"[0-9a-fA-F]{64}", value) is None:
        raise argparse.ArgumentTypeError("Expected one SHA-256 certificate digest: exactly 64 hexadecimal characters, without separators.")
    return value.lower()


def parse_signer_certificates(output: str, schemes: dict) -> dict:
    """Read APK certificate digests, excluding public-key and Source Stamp hashes."""
    counts = []
    certificates = []
    errors = []
    numbered = []
    sdk_specific = False
    labels = set()
    for line in output.splitlines():
        if line.startswith("Number of signers:"):
            value = line.partition(":")[2].strip()
            counts.append(int(value) if re.fullmatch(r"[0-9]+", value) else None)
        match = re.fullmatch(r"(Signer .+) certificate SHA-256 digest:\s*(.*)", line)
        if not match:
            continue
        label, digest = match.groups()
        number = re.fullmatch(r"Signer #([1-9][0-9]*)", label)
        sdk_range = re.fullmatch(r"Signer \(minSdkVersion=([0-9]+)(?: \(dev release=true\))?, maxSdkVersion=([0-9]+)\)", label)
        if number:
            numbered.append(int(number[1]))
        elif sdk_range and 0 < int(sdk_range[1]) <= int(sdk_range[2]):
            sdk_specific = True
        else:
            errors.append("Unsupported APK signer label: " + label)
        if label in labels:
            errors.append("Duplicate APK signer certificate entry: " + label)
        labels.add(label)
        try:
            certificates.append({"signer": label, "sha256": normalize_signer_sha256(digest.strip())})
        except argparse.ArgumentTypeError:
            errors.append("Missing or malformed SHA-256 certificate digest: " + label)
    count = counts[0] if len(counts) == 1 and counts[0] is not None and counts[0] > 0 else None
    if count is None:
        errors.append("Missing or ambiguous positive APK signer count.")
    if not certificates:
        errors.append("No APK signer certificate SHA-256 digest was reported.")
    if sdk_specific:
        # apksigner prints SDK-specific certificates for v3.1 rotation instead
        # of numbered signers. Preserve every certificate; an identity pin
        # still requires exactly one certificate and one reported signer.
        if numbered or not schemes.get("v3.1") or count is not None and len(certificates) < count:
            errors.append("SDK-specific certificate entries do not match the verified signing scheme/count.")
    elif count is not None and (len(certificates) != count or sorted(numbered) != list(range(1, len(certificates) + 1))):
        errors.append("APK signer count and numbered certificate entries do not agree.")
    return {"reported_signer_count": count, "signer_certificates": certificates,
            "signer_sha256": [item["sha256"] for item in certificates], "certificate_parse_errors": errors}


def inspect_signing(apk: Path, report: dict, tools: dict, timeout: int,
                    expected_signer_sha256: str | None = None) -> None:
    if expected_signer_sha256 is not None:
        expected_signer_sha256 = normalize_signer_sha256(expected_signer_sha256)
    if not tools.get("apksigner"):
        add_check(report, "signature_verification", "not_run",
                  "apksigner is unavailable. Signature-looking ZIP files or a signing-block marker do not verify a signature.")
        if expected_signer_sha256 is not None:
            add_check(report, "signer_identity", "not_run", "The expected signer cannot be checked without apksigner.",
                      expected=expected_signer_sha256, actual=[])
        return
    attempt = run_tool([tools["apksigner"], "verify", "--verbose", "--print-certs", str(apk)], timeout)
    status = "incomplete" if attempt["error"] else "pass" if attempt["exit_code"] == 0 else "fail"
    if re.search(r"DOES NOT VERIFY|^ERROR:", attempt["stdout"] + attempt["stderr"], re.MULTILINE):
        status = "fail"
    schemes = {name: value == "true" for name, value in re.findall(r"Verified using (v\d(?:\.\d)?) scheme[^\n]*:\s*(true|false)", attempt["stdout"])}
    if status == "pass" and not any(schemes.values()):
        status = "incomplete"
        attempt["error"] = "Verifier returned zero without an affirmative signature-scheme result; no signature PASS is inferred."
    certificates = parse_signer_certificates(attempt["stdout"], schemes)
    if status == "pass" and certificates["certificate_parse_errors"]:
        status = "incomplete"
    add_check(report, "signature_verification", status,
              "apksigner verifies this APK and reports its signing-certificate SHA-256 digests. It does not establish publisher ownership.",
              schemes=schemes, **certificates, **command_evidence(attempt))
    if expected_signer_sha256 is not None:
        identity_status = "incomplete"
        if status == "pass":
            identity_status = "pass" if certificates["reported_signer_count"] == 1 and certificates["signer_sha256"] == [expected_signer_sha256] else "fail"
        add_check(report, "signer_identity", identity_status,
                  "A pinned identity requires a verified APK with exactly one reported signer and one matching certificate; multiple signers or SDK-specific rotation certificates do not satisfy this single-certificate contract.",
                  expected=expected_signer_sha256, actual=certificates["signer_sha256"],
                  reported_signer_count=certificates["reported_signer_count"], signature_status=status)


def snapshot_sources(project: Path) -> dict:
    hashes = {}
    if not project.is_dir():
        return {"status": "not_run", "reason": "Source project directory not available."}
    for path in sorted(project.rglob("*")):
        if path.is_file() and ".godot" not in path.relative_to(project).parts and path.suffix in {".gd", ".gdshader", ".gdshaderinc", ".tscn", ".godot", ".json", ".glb", ".res", ".wav", ".webp", ".png", ".jpg"}:
            hashes[str(path.relative_to(project))] = sha256_file(path)
    return {"status": "recorded", "sha256": hashes,
            "scope": "Local source snapshot only; not proof that transformed APK bytes were produced from these exact sources."}


def validate(args: argparse.Namespace) -> dict:
    apk = args.apk.resolve()
    expected_signer = getattr(args, "expected_signer_sha256", None)
    if expected_signer is not None:
        expected_signer = normalize_signer_sha256(expected_signer)
    roots = sdk_roots(args.sdk_root)
    tools = {name: find_tool(name, roots, getattr(args, name, None)) for name in TOOL_NAMES}
    report = {"schema_version": 1, "checked_at_utc": datetime.now(timezone.utc).isoformat(),
              "apk": {"path": str(apk), "size_bytes": None, "sha256": None},
              "expected_package": args.expected_package, "expected_abi": args.expected_abi,
              "expected_signer_sha256": expected_signer,
              "tool_paths": tools, "sdk_roots": [str(root) for root in roots],
              "sdk_platforms": sorted({folder.name for sdk in roots for folder in (sdk / "platforms").glob("*") if folder.is_dir()}),
              "emulator_inventory": {"emulator_binary": tools["emulator"], "adb_binary": tools["adb"],
                                     "kvm_device_present": Path("/dev/kvm").exists(),
                                     "avd_config_count": len(list(Path(os.environ.get("ANDROID_AVD_HOME", str(Path.home() / ".android/avd"))).glob("*.ini"))),
                                     "devices_queried": False, "device_or_emulator_started": False},
              "manifest": None, "checks": [],
              "device_tests": {"status": "not_run", "reason": "Static validator never installs or launches an APK or queries a connected device."},
              "installability": "not_demonstrated_on_a_device",
              "source_snapshot": snapshot_sources(args.source_root)}
    if not apk.is_file():
        add_check(report, "apk_file", "fail", "APK file does not exist or is not a regular file.")
        return finish(report)
    report["apk"].update(size_bytes=apk.stat().st_size, sha256=sha256_file(apk))
    add_check(report, "apk_file", "pass" if apk.suffix.lower() == ".apk" else "fail",
              "APK file found; its extension alone is not accepted as proof of format.")
    if inspect_zip(apk, report, args.expected_abi, args.source_root):
        inspect_manifest(apk, report, tools, args.expected_package, args.tool_timeout)
        inspect_signing(apk, report, tools, args.tool_timeout, expected_signer)
        if tools.get("zipalign"):
            attempt = run_tool([tools["zipalign"], "-c", "-v", "4", str(apk)], args.tool_timeout)
            status = "incomplete" if attempt["error"] else "pass" if attempt["exit_code"] == 0 else "fail"
            add_check(report, "zip_alignment", status, "Existing zipalign checks ordinary 4-byte ZIP alignment; this does not establish 16-KB native page compatibility.", **command_evidence(attempt))
        else:
            add_check(report, "zip_alignment", "not_run", "zipalign is unavailable; no alignment result is claimed.", required=False)
    else:
        add_check(report, "manifest_metadata", "not_run", "Core APK structure failed; external inspection was not run.")
        add_check(report, "signature_verification", "not_run", "Core APK structure failed; external inspection was not run.")
        if expected_signer is not None:
            add_check(report, "signer_identity", "not_run", "Core APK structure failed; signer identity was not checked.",
                      expected=expected_signer, actual=[])
    unchanged = apk.stat().st_size == report["apk"]["size_bytes"] and sha256_file(apk) == report["apk"]["sha256"]
    add_check(report, "apk_unchanged", "pass" if unchanged else "fail",
              "The inspected APK must retain the same size and SHA-256 throughout validation.")
    return finish(report)


def finish(report: dict) -> dict:
    required = [item for item in report["checks"] if item["required"]]
    if any(item["status"] == "fail" for item in required):
        report["overall_status"] = "fail"
    elif any(item["status"] != "pass" for item in required):
        report["overall_status"] = "incomplete"
    else:
        report["overall_status"] = "pass"
    report["passed"] = report["overall_status"] == "pass"
    report["scope"] = "Static APK/package/signature evidence only. No graphics, touch, audio, FPS, thermal, installation, launch, or real-device success is claimed."
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("apk_positional", type=Path, nargs="?")
    parser.add_argument("--apk", type=Path)
    parser.add_argument("--sdk-root", type=Path, action="append", default=[])
    parser.add_argument("--expected-package", default="at.heinz.imperathen")
    parser.add_argument("--expected-abi", choices=sorted(ARCHITECTURES), default="arm64-v8a")
    parser.add_argument("--expected-signer-sha256", type=normalize_signer_sha256, action="append",
                        help="Require exactly one APK signer with this 64-character certificate SHA-256 digest; specify once.")
    parser.add_argument("--report", type=Path)
    parser.add_argument("--source-root", type=Path, default=ROOT / "prototype")
    parser.add_argument("--tool-timeout", type=int, default=45)
    for name in ("aapt", "aapt2", "apkanalyzer", "apksigner", "zipalign"):
        parser.add_argument("--" + name, help="Use an already installed tool at this executable path.")
    args = parser.parse_args()
    expected_signers = args.expected_signer_sha256 or []
    if len(expected_signers) > 1:
        parser.error("--expected-signer-sha256 must be supplied exactly once when used.")
    args.expected_signer_sha256 = expected_signers[0] if expected_signers else None
    if bool(args.apk) == bool(args.apk_positional):
        parser.error("Supply exactly one APK, either --apk FILE or positional FILE.")
    args.apk = args.apk or args.apk_positional
    if not 1 <= args.tool_timeout <= 60:
        parser.error("--tool-timeout must be between 1 and 60 seconds.")
    if args.report and args.report.resolve() == args.apk.resolve():
        parser.error("The JSON report must not overwrite the APK.")
    try:
        report = validate(args)
    except (OSError, ValueError) as error:
        report = {"schema_version": 1, "overall_status": "incomplete", "passed": False,
                  "error": str(error), "device_tests": {"status": "not_run"}}
    encoded = json.dumps(report, indent=2, ensure_ascii=False) + "\n"
    if args.report:
        try:
            args.report.parent.mkdir(parents=True, exist_ok=True)
            temporary = args.report.with_name(args.report.name + ".tmp")
            temporary.write_text(encoded, encoding="utf-8")
            temporary.replace(args.report)
        except OSError as error:
            print(f"Cannot save validation report: {error}", file=sys.stderr)
            print(encoded, end="")
            return 2
    print(encoded, end="")
    return {"pass": 0, "fail": 1, "incomplete": 2}[report["overall_status"]]


if __name__ == "__main__":
    raise SystemExit(main())
