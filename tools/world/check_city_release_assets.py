#!/usr/bin/env python3
"""Fail-closed audit of actual city/temple/crowd assets before Android export.

A production claim is only possible with a matching signing key AND a
physical-device run; this audit never marks those completed on its own.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import struct


def glb_info(path: Path):
    if not path.is_file() or path.stat().st_size < 28:
        raise ValueError(f"Missing or incomplete genuine GLB: {path}")
    with path.open("rb") as f:
        header=f.read(20)
    magic, version, length=struct.unpack_from("<III",header,0)
    json_length, chunk_type=struct.unpack_from("<II",header,12)
    if (magic,version,length)!=(0x46546c67,2,path.stat().st_size) or chunk_type!=0x4e4f534a or json_length<=0:
        raise ValueError(f"Not a valid complete GLB v2: {path}")
    return {"bytes":length,"sha256":hashlib.file_digest(path.open("rb"),"sha256").hexdigest()}


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--prototype",type=Path,default=Path("prototype"))
    parser.add_argument("--output",type=Path,required=True)
    parser.add_argument("--require-private-temple",action="store_true")
    args=parser.parse_args()
    root=args.prototype
    world=root/"assets/world"
    city=glb_info(world/"roman_city_test.glb")
    collision=glb_info(world/"roman_city_collision.glb")
    manifest=json.loads((world/"roman_city_manifest.json").read_text())
    if manifest["residential_count"]!=240 or manifest["market_stall_count"]!=63:
        raise RuntimeError("Blender output has wrong actual city layout.")
    if manifest["verification"]["gltf_export"]!="completed":
        raise RuntimeError("City was not actually exported.")
    paths=json.loads((world/"city_crowd_layout.json").read_text())
    if paths.get("format")!="imperathen-city-idle-crowd" or len(paths.get("entries",[]))!=12:
        raise RuntimeError("No reproducible twelve-person authored crowd layout.")
    for person in paths["entries"]:
        asset=root/person["path"].removeprefix("res://")
        if not asset.is_file():
            raise RuntimeError("Missing source body for actual crowd: "+str(asset))
    status="not_supplied"
    report={"schema_version":1,
        "actual_city_glb":city,"actual_collision_glb":collision,
        "residential_meshes_expected":240,"market_stalls_expected":63,
        "forum_embedded_in_city":True,"additional_forum_glb_required":False,
        "crowd_layout_entries":12,"private_temple":"not_supplied",
        "private_temple_lod_count":0,
        "physical_fold7_20min_test":"not_performed",
        "matching_existing_android_signer":"not_proven",
        "release_approved":False}
    private=world/"roman_temple_review.json"
    if private.exists():
        reviewed=json.loads(private.read_text(encoding="utf-8"))
        lods=[glb_info(world/f"roman_meshy_temple_{level}.glb") for level in range(3)]
        if reviewed.get("source_task_id")!="629bd668-c5ed-4057-bd6d-c02322c80e4e":
            raise RuntimeError("Wrong private Meshy task ID for historical temple source.")
        width,depth,height=reviewed["scaled_size_m"]
        if width>44 or depth>46 or height>30 or min(width,depth,height)<1:
            raise RuntimeError("Original Meshy temple is outside authored RomanCity plot budget.")
        if any(lods[level]["sha256"]!=reviewed["lods"][level]["sha256"] for level in range(3)):
            raise RuntimeError("Temple GLBs differ from their private Blender build report.")
        status="privately_imported_needs_visual_review"
        report["private_temple_lod_count"]=3
        report["private_temple_source_task"]=reviewed["source_task_id"]
    elif args.require_private_temple:
        raise RuntimeError("Release requested, but the original private Meshy temple GLB is not available.")
    report["private_temple"]=status
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(report,indent=2,ensure_ascii=False)+"\n",encoding="utf-8")
    print("ROMAN_CITY_ASSET_AUDIT_PASS "+json.dumps(report,ensure_ascii=False))
    return 0


if __name__=="__main__":
    raise SystemExit(main())
