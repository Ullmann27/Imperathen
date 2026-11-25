#!/usr/bin/env python3
"""Inspect actual world-kit GLB bytes using the existing strict asset inspector."""
from __future__ import annotations
import argparse
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("world_glb_inspection", ROOT / "tools/art/validate_visual_assets.py")
inspector = importlib.util.module_from_spec(spec)
spec.loader.exec_module(inspector)

def resource_path(value):
    prefix = "res://assets/world_expansion/"
    if not isinstance(value, str) or not value.startswith(prefix):
        raise ValueError("Asset must live under " + prefix)
    suffix = value.removeprefix("res://")
    if ".." in Path(suffix).parts:
        raise ValueError("Parent path forbidden")
    path = (ROOT / "prototype" / suffix).resolve()
    if not path.is_relative_to((ROOT / "prototype/assets/world_expansion").resolve()):
        raise ValueError("Asset escapes world expansion")
    return path

def check_wind(path):
    document, binary, warnings = inspector.read_glb(path.read_bytes())
    inspection = inspector.Inspection(document, binary, warnings)
    inspection.inspect_buffers()
    count = 0
    flexible, flutter, fixed_bark = False, False, False
    for mesh in document["meshes"]:
        for primitive in mesh["primitives"]:
            colors = primitive["attributes"].get("COLOR_0")
            if colors is None:
                raise ValueError("Missing COLOR_0 wind payload")
            values = inspection.decode(colors)
            accessor = document["accessors"][colors]
            component_type = accessor["componentType"]
            # The existing structural inspector intentionally returns raw
            # integer components. glTF COLOR_0 is commonly normalized uint16.
            if component_type in (5121, 5123):
                if accessor.get("normalized") is not True:
                    raise ValueError("Integer wind colors must be normalized")
                scale = 255.0 if component_type == 5121 else 65535.0
                values = [tuple(value / scale for value in row) for row in values]
            elif component_type != 5126:
                raise ValueError("Unsupported wind color component type")
            if len(values) != document["accessors"][primitive["attributes"]["POSITION"]]["count"]:
                raise ValueError("Wind payload/vertex count mismatch")
            material = document["materials"][primitive["material"]].get("name", "").lower()
            for rgba in values:
                if len(rgba) != 4 or not all(math.isfinite(v) and 0 <= v <= 1 for v in rgba):
                    raise ValueError("Non-finite or out-of-range wind channel")
                if abs(rgba[3]-1) > 0.001:
                    raise ValueError("Wind alpha must remain opaque")
                flexible |= rgba[0] > 0.2
                flutter |= rgba[1] > 0.2
                if "bark" in material:
                    if rgba[1] > 0.001:
                        raise ValueError("Bark must not flutter")
                    fixed_bark |= rgba[0] < 0.001
            count += len(values)
    if not (count and flexible and flutter and fixed_bark):
        raise ValueError("Wind coverage needs flexible branches, leaves and fixed roots")
    return {"color_vertices":count,"flexible_branches":flexible,"leaf_flutter":flutter,"rooted_bark":fixed_bark}

def validate(category, manifest):
    assets = ((manifest.get("building_assets", []) + manifest.get("road_assets", []))
              if category == "architecture" else manifest.get("vegetation_assets", []))
    expected = 4 if category == "architecture" else 3
    errors, rows = [], []
    if len(assets) != expected:
        errors.append(f"Expected {expected} {category} assets, found {len(assets)}")
    seen = set()
    for asset in assets:
        identity = asset.get("id", "")
        if not identity or identity in seen:
            errors.append(f"Empty/duplicate asset id: {identity}")
        seen.add(identity)
        source = ROOT / "art/world_expansion" / category / (identity + ".blend")
        if not source.is_file() or source.stat().st_size < 1024:
            errors.append(f"Missing editable Blender source: {source.relative_to(ROOT)}")
        if len(asset.get("lods", [])) != 3:
            errors.append(f"{identity}: exactly three independent LOD resources required")
        levels = []
        for level, value in enumerate(asset.get("lods", [])):
            try:
                path = resource_path(value)
                result = inspector.validate_asset(path, ROOT)
                result["id"], result["lod"] = identity, level
                if result["status"] != "passed":
                    errors.extend(f"{identity} LOD{level}: {message}" for message in result["errors"])
                else:
                    if result["animations"] or result["skins"]:
                        errors.append(f"{identity}: unexpected animated/skeletal static asset")
                    if result["textured_materials"] == 0:
                        errors.append(f"{identity}: exported PBR textures missing")
                    bounds = result["dimensions_m_xyz"]
                    limits = asset["footprint"]
                    if bounds[0] > limits[0] + .01 or bounds[2] > limits[1] + .01:
                        errors.append(f"{identity} LOD{level}: actual bounds exceed reserved footprint")
                    if bounds[1] > asset["height"] + .01:
                        errors.append(f"{identity}: actual height exceeds manifest")
                    if category == "vegetation":
                        result["wind"] = check_wind(path)
                rows.append(result)
                levels.append(result.get("triangles_unique_meshes", 0))
            except (ValueError, OSError, KeyError, IndexError) as error:
                errors.append(f"{identity} LOD{level}: {error}")
        if len(levels) == 3 and not (levels[0] > levels[1] >= levels[2] > 0):
            errors.append(f"{identity}: LOD triangles must decrease; found {levels}")
    return {"schema_version":1,"category":category,"status":"passed" if not errors else "failed",
            "generated_at_utc":datetime.now(timezone.utc).isoformat(timespec="seconds"),
            "assets_checked":len(rows),"errors":errors,"assets":rows,
            "not_verified":["visual acceptance","collisions","Android FPS / thermal behaviour"]}

def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--category", choices=["architecture","vegetation","all"], default="all")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args(argv)
    try:
        manifest = json.loads((ROOT / "prototype/assets/world_expansion/manifest.json").read_text())
        categories = ["architecture","vegetation"] if args.category == "all" else [args.category]
        reports = [validate(category, manifest) for category in categories]
        report = {"status":"passed" if all(r["status"]=="passed" for r in reports) else "failed",
                  "reports":reports}
    except (ValueError,OSError,KeyError) as error:
        report = {"status":"failed","errors":[str(error)],"reports":[]}
    if args.output:
        args.output.parent.mkdir(parents=True,exist_ok=True)
        args.output.write_text(json.dumps(report,indent=2,ensure_ascii=False,allow_nan=False)+"\n")
    print(json.dumps({"status":report["status"],"categories":[
        {"category":r["category"],"checked":r["assets_checked"],"errors":r["errors"]}
        for r in report["reports"]],"errors":report.get("errors",[])},ensure_ascii=False))
    return 0 if report["status"] == "passed" else 1

if __name__ == "__main__":
    raise SystemExit(main())
