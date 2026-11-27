#!/usr/bin/env python3
"""Validate the four anatomical hero GLBs from their decoded exported bytes.

This is a static production gate. It does not approve facial appearance, animation
quality, Godot integration, Android frame rate, or thermal behavior.

Run from any working directory:
    python tools/characters/validate_hero.py --report art/hero_quality/validation.json
"""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import struct
import sys


ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    "imperathen_asset_gate", ROOT / "tools/art/validate_visual_assets.py"
)
assert SPEC is not None and SPEC.loader is not None
GATE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(GATE)

BONES = frozenset((
    "Pelvis", "Spine", "Head", "Arm_L", "Arm_R", "Forearm_L", "Forearm_R",
    "Hand_L", "Hand_R", "Thigh_L", "Thigh_R", "Shin_L", "Shin_R", "Foot_L", "Foot_R",
))
CLIPS = frozenset((
    "idle", "march", "run", "gather", "talk", "train", "work", "block", "attack", "hit", "death",
))
MORPHS = frozenset((
    "Mature", "Companion", "Blink_L", "Blink_R", "JawOpen", "Smile", "BrowDown",
))
TEXTURE_LIMITS = (2048, 1024, 512, 256)
EXPECTED_EXCEPTIONS = (
    ValueError, OSError, struct.error, OverflowError, RecursionError,
    TypeError, KeyError, IndexError, AttributeError,
)


def display_path(path: Path) -> str:
    try:
        return path.resolve().relative_to(ROOT.resolve()).as_posix()
    except ValueError:
        return str(path.resolve())


def skin_weights(document: dict, inspection, mesh_skins: dict) -> dict:
    """Check joint indices and the combined normalized influence sum per vertex."""
    rows_checked, invalid_indices, invalid_weights = 0, 0, 0
    largest_sum_error = 0.0
    for mesh_index, skins in mesh_skins.items():
        mesh = document["meshes"][mesh_index]
        joint_counts = {len(document["skins"][skin]["joints"]) for skin in skins}
        for primitive in mesh["primitives"]:
            attrs = primitive["attributes"]
            weight_sets = sorted(key for key in attrs if key.startswith("WEIGHTS_"))
            GATE.require("WEIGHTS_0" in weight_sets, "Skinned primitive lacks WEIGHTS_0")
            vertex_count = len(inspection.decode(attrs["POSITION"]))
            totals = [0.0] * vertex_count
            for weight_name in weight_sets:
                joint_name = "JOINTS_" + weight_name.split("_", 1)[1]
                GATE.require(joint_name in attrs, f"{weight_name} lacks matching {joint_name}")
                accessor = document["accessors"][attrs[weight_name]]
                joint_accessor = document["accessors"][attrs[joint_name]]
                component = accessor["componentType"]
                GATE.require(accessor["type"] == "VEC4", f"{weight_name} must be VEC4")
                GATE.require(component == 5126 or (
                    component in (5121, 5123) and accessor.get("normalized") is True
                ), f"{weight_name} must be FLOAT or normalized unsigned bytes/shorts")
                GATE.require(joint_accessor["type"] == "VEC4"
                             and joint_accessor["componentType"] in (5121, 5123)
                             and not joint_accessor.get("normalized", False),
                             f"{joint_name} must contain unnormalized unsigned integer indices")
                scale = {5121: 255.0, 5123: 65535.0}.get(component, 1.0)
                weights = inspection.decode(attrs[weight_name])
                joints = inspection.decode(attrs[joint_name])
                GATE.require(len(weights) == len(joints) == vertex_count,
                             "Skin attribute count differs from position count")
                for row_index, (weight_row, joint_row) in enumerate(zip(weights, joints)):
                    values = [weight / scale for weight in weight_row]
                    totals[row_index] += sum(values)
                    invalid_weights += sum(weight < 0 or weight > 1 for weight in values)
                    invalid_indices += sum(
                        any(joint < 0 or joint >= count for count in joint_counts)
                        for joint in joint_row
                    )
            rows_checked += vertex_count
            largest_sum_error = max(largest_sum_error, max(abs(total - 1) for total in totals))
    GATE.require(rows_checked > 0, "No actual skin weight rows inspected")
    GATE.require(invalid_indices == 0, f"{invalid_indices} joint indices outside their skin")
    GATE.require(invalid_weights == 0, f"{invalid_weights} weights outside [0, 1]")
    GATE.require(largest_sum_error <= 1e-4,
                 f"Skin weights do not sum to one; largest error {largest_sum_error}")
    return {"vertex_rows": rows_checked, "maximum_sum_error": largest_sum_error,
            "invalid_joint_indices": invalid_indices, "invalid_weights": invalid_weights}


def body_morphs(document: dict, inspection, mesh_skins: dict) -> dict:
    body_meshes = {node["mesh"] for node in document.get("nodes", [])
                   if node.get("name") == "HeroBody" and "mesh" in node}
    GATE.require(len(body_meshes) == 1, "Expected exactly one mesh used by a HeroBody node")
    body_index = next(iter(body_meshes))
    GATE.require(body_index in mesh_skins, "HeroBody must be skinned")
    mesh = document["meshes"][body_index]
    names = mesh.get("extras", {}).get("targetNames", [])
    GATE.require(len(names) == len(MORPHS) and set(names) == MORPHS,
                 f"HeroBody must carry exactly the seven required morph names; got {names}")
    results = {name: {"nonzero_position_rows": 0, "maximum_displacement_m": 0.0}
               for name in names}
    fingerprints = {name: hashlib.sha256() for name in names}
    blink_difference = 0.0
    for primitive in mesh["primitives"]:
        attrs = primitive["attributes"]
        GATE.require("TEXCOORD_0" in attrs, "HeroBody primitive lacks TEXCOORD_0")
        positions = inspection.decode(attrs["POSITION"])
        GATE.require(len(inspection.decode(attrs["TEXCOORD_0"])) == len(positions),
                     "HeroBody UV count differs from position count")
        targets = primitive.get("targets", [])
        GATE.require(len(targets) == len(names), "HeroBody primitive morph count differs from names")
        for name, target in zip(names, targets):
            GATE.require("POSITION" in target, f"{name} lacks actual position deltas")
            deltas = inspection.decode(target["POSITION"])
            GATE.require(len(deltas) == len(positions), f"{name} position delta count differs from body")
            for row in deltas:
                distance = math.sqrt(sum(float(value) ** 2 for value in row))
                results[name]["nonzero_position_rows"] += int(distance > 1e-8)
                results[name]["maximum_displacement_m"] = max(
                    results[name]["maximum_displacement_m"], distance
                )
                fingerprints[name].update(struct.pack("<3f", *row))
        left = inspection.decode(targets[names.index("Blink_L")]["POSITION"])
        right = inspection.decode(targets[names.index("Blink_R")]["POSITION"])
        blink_difference = max(blink_difference, max(
            math.sqrt(sum((a - b) ** 2 for a, b in zip(left_row, right_row)))
            for left_row, right_row in zip(left, right)
        ))
    for name, result in results.items():
        GATE.require(result["nonzero_position_rows"] > 0, f"{name} has no actual body deformation")
        result["position_delta_sha256"] = fingerprints[name].hexdigest()
    GATE.require(blink_difference > 1e-7,
                 "Left and right blink use identical or negligible body deformations")
    for name in ("Blink_L", "Blink_R"):
        results[name]["maximum_difference_from_other_blink_m"] = blink_difference
    return results


def animations(document: dict, inspection) -> dict:
    records = {}
    for clip in document.get("animations", []):
        name = clip.get("name", "")
        GATE.require(name not in records, f"Duplicate animation name: {name}")
        varying_channels, duration = 0, 0.0
        for sampler in clip["samplers"]:
            values = inspection.decode(sampler["output"])
            varying_channels += int(any(row != values[0] for row in values[1:]))
            duration = max(duration, max(row[0] for row in inspection.decode(sampler["input"])))
        GATE.require(duration > 0 and varying_channels > 0, f"Animation {name} is empty or constant")
        records[name] = {"duration_seconds": duration, "varying_sampled_channels": varying_channels}
    GATE.require(set(records) == CLIPS,
                 f"Expected the eleven runtime clips; got {sorted(records)}")
    return records


def belt_topology(document: dict, inspection) -> dict:
    """Protect the fitted band from long LOD chords that cut into the tunic."""
    meshes = [mesh for mesh in document.get("meshes", []) if mesh.get("name") == "HeroBelt"]
    GATE.require(len(meshes) == 1, "Exactly one fitted HeroBelt mesh is required")
    primitives = meshes[0]["primitives"]
    GATE.require(len(primitives) == 1, "HeroBelt must keep its complete single band")
    primitive = primitives[0]
    points = inspection.decode(primitive["attributes"]["POSITION"])
    indices = [row[0] for row in inspection.decode(primitive["indices"])]
    GATE.require(len(points) >= 64 and len(indices) >= 64 * 3,
                 "HeroBelt was over-decimated; its fitted circumference is no longer preserved")
    cx = (min(point[0] for point in points) + max(point[0] for point in points)) * .5
    cz = (min(point[2] for point in points) + max(point[2] for point in points)) * .5
    rx = max(abs(point[0] - cx) for point in points)
    rz = max(abs(point[2] - cz) for point in points)
    GATE.require(min(rx, rz) > 0, "HeroBelt lacks a positive circumference")
    angles = [math.atan2((point[2] - cz) / rz, (point[0] - cx) / rx) for point in points]
    maximum_edge = 0.
    for index in range(0, len(indices), 3):
        triangle = indices[index:index + 3]
        for first, last in zip(triangle, triangle[1:] + triangle[:1]):
            difference = abs((angles[last] - angles[first] + math.pi) % math.tau - math.pi)
            maximum_edge = max(maximum_edge, difference)
    GATE.require(maximum_edge <= math.tau / 32 + 1e-5,
                 "HeroBelt has a long simplified chord through the fitted waist")
    return {"vertices": len(points), "triangles": len(indices) // 3,
            "largest_circumferential_edge_degrees": math.degrees(maximum_edge),
            "scope": "Rest topology only; animated garment clearance is checked separately"}


def validate_marcus_eyes(document, inspection, mesh_skins):
    """Verify actual eye-only weights, not merely extra named nodes."""
    eye_names = {"Eye_L", "Eye_R"}
    parent = {c: i for i, n in enumerate(document["nodes"]) for c in n.get("children", [])}
    eyes = [i for i, n in enumerate(document["nodes"]) if n.get("name") in eye_names]
    GATE.require(len(eyes) == 2 and all(document["nodes"][parent[i]].get("name") == "Head" for i in eyes),
                 "Marcus eye bones must be independent children of Head")
    eye_meshes = {n["mesh"] for n in document["nodes"] if n.get("name") == "HeroEyes" and "mesh" in n}
    GATE.require(len(eye_meshes) == 1, "Marcus must have the original separate eye mesh")
    counts = {"Eye_L": 0, "Eye_R": 0}
    for mesh_id, skins in mesh_skins.items():
        GATE.require(len(skins) == 1, "Ambiguous Marcus skin")
        skin = document["skins"][next(iter(skins))]
        names = [document["nodes"][i]["name"] for i in skin["joints"]]
        for primitive in document["meshes"][mesh_id]["primitives"]:
            attrs = primitive["attributes"]
            for joint_key in sorted(k for k in attrs if k.startswith("JOINTS_")):
                weight_key = joint_key.replace("JOINTS_", "WEIGHTS_")
                weights = inspection.decode(attrs[weight_key])
                component = document["accessors"][attrs[weight_key]]["componentType"]
                scale = {5121: 255., 5123: 65535.}.get(component, 1.)
                joints = inspection.decode(attrs[joint_key])
                for joint_row, weight_row in zip(joints, weights):
                    for joint, weight in zip(joint_row, weight_row):
                        if weight <= 1e-6:
                            continue
                        name = names[joint]
                        if mesh_id in eye_meshes:
                            GATE.require(name in eye_names and abs(weight / scale - 1.) < 1e-4,
                                         "Eye vertices must be rigidly attached to one actual eye")
                            counts[name] += 1
                        else:
                            GATE.require(name not in eye_names, "Eye bone deforms eyelid/body mesh")
    GATE.require(all(n >= 12 for n in counts.values()), "Missing weighted eyeball surface")
    return counts


def inspect_asset(path: Path, level: int) -> dict:
    result = {"path": display_path(path), "lod": level, "status": "failed",
              "errors": [], "warnings": []}
    try:
        raw = path.read_bytes()
        result.update(bytes=len(raw), sha256=hashlib.sha256(raw).hexdigest())
        document, binary, warnings = GATE.read_glb(raw)
        inspection = GATE.Inspection(document, binary, warnings)
        result["warnings"] = warnings
        metrics = inspection.run()
        result["geometry"] = {key: metrics[key] for key in (
            "triangles_unique_meshes", "meshes", "primitives", "materials", "textured_materials"
        )}
        GATE.require(metrics["images"], "Hero GLB contains no embedded images")
        max_edge = max(max(image["width"], image["height"]) for image in metrics["images"])
        GATE.require(max_edge <= TEXTURE_LIMITS[level],
                     f"LOD {level}: texture edge {max_edge} exceeds {TEXTURE_LIMITS[level]}")
        result["textures"] = {
            "maximum_edge": max_edge, "allowed_maximum_edge": TEXTURE_LIMITS[level],
            "unique_embedded_images": metrics["unique_embedded_image_count"],
            "rgba8_top_level_bytes_estimate": metrics["rgba8_top_level_texture_bytes_estimate"],
            "memory_note": metrics["texture_memory_note"], "images": metrics["images"],
        }
        skins = []
        for skin in document.get("skins", []):
            names = [document["nodes"][index].get("name") for index in skin["joints"]]
            expected = BONES | {"Eye_L", "Eye_R"} if path.name.startswith("marcus_quality_") else BONES
            GATE.require(len(names) == len(expected) and set(names) == expected,
                         f"Skin must contain the exact character runtime bones; got {names}")
            skins.append(names)
        GATE.require(skins, "Hero GLB contains no skin")
        mesh_skins = {}
        for node in document.get("nodes", []):
            if "skin" in node and "mesh" in node:
                mesh_skins.setdefault(node["mesh"], set()).add(node["skin"])
        result["skin_bones"] = skins
        result["skin_weights"] = skin_weights(document, inspection, mesh_skins)
        if path.name.startswith("marcus_quality_"):
            result["independent_eye_vertices"] = validate_marcus_eyes(document, inspection, mesh_skins)
        result["body_morphs"] = body_morphs(document, inspection, mesh_skins)
        result["clips"] = animations(document, inspection)
        result["belt_topology"] = belt_topology(document, inspection)
        result["status"] = "passed"
    except EXPECTED_EXCEPTIONS as exc:
        result["errors"].append(f"{type(exc).__name__}: {exc}")
    return result


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("files", type=Path, nargs="*", help="Exactly four GLBs in LOD 0..3 order")
    parser.add_argument("--report", type=Path, help="Write the complete JSON receipt")
    args = parser.parse_args(argv)
    paths = args.files or [ROOT / f"prototype/assets/characters/hero_quality_{level}.glb" for level in range(4)]
    if len(paths) != 4:
        parser.error("Pass exactly four GLBs in LOD 0..3 order, or omit all paths")
    assets = [inspect_asset(path, level) for level, path in enumerate(paths)]
    triangles = [asset.get("geometry", {}).get("triangles_unique_meshes") for asset in assets]
    decreasing = all(isinstance(count, int) and count > 0 for count in triangles) and all(
        high > low for high, low in zip(triangles, triangles[1:])
    )
    passed = decreasing and all(asset["status"] == "passed" for asset in assets)
    report = {
        "schema_version": 1, "validator": "tools/characters/validate_hero.py",
        "checked_at_utc": datetime.now(timezone.utc).isoformat(),
        "scope": "Static decoded export bytes only; no visual, engine, or Android device approval.",
        "status": "passed" if passed else "failed", "triangles_strictly_decrease": decreasing,
        "errors": [] if decreasing else ["Actual triangle counts must strictly decrease from LOD 0 to LOD 3"],
        "assets": assets,
    }
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, indent=2) + "\n")
    for asset in assets:
        count = asset.get("geometry", {}).get("triangles_unique_meshes", "unknown")
        print(f"{asset['status'].upper()} {asset['path']} — {count} triangles")
        for error in asset["errors"]:
            print(f"  {error}")
    for error in report["errors"]:
        print(error)
    if args.report:
        print(f"JSON receipt: {args.report}")
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
