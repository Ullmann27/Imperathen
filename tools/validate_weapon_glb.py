#!/usr/bin/env python3
"""Validate generated Blender GLBs without third-party dependencies."""
import argparse
import json
import struct
from pathlib import Path

MAGIC = b"glTF"

def inspect(path):
    data = path.read_bytes()
    if len(data) < 20:
        raise ValueError("GLB too short")
    magic, version, length = struct.unpack_from("<4sII", data, 0)
    if magic != MAGIC or version != 2 or length != len(data):
        raise ValueError("invalid GLB header")
    size, chunk_type = struct.unpack_from("<II", data, 12)
    if chunk_type != 0x4E4F534A:
        raise ValueError("missing JSON chunk")
    doc = json.loads(data[20:20 + size].decode("utf-8").rstrip(" \x00"))
    meshes = doc.get("meshes", [])
    if not meshes or not doc.get("materials"):
        raise ValueError("GLB missing geometry or materials")
    if not doc.get("nodes"):
        raise ValueError("GLB missing nodes")
    return {"file": str(path), "bytes": len(data), "meshes": len(meshes), "materials": len(doc["materials"]), "nodes": len(doc["nodes"])}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("paths", nargs="+", type=Path)
    args = parser.parse_args()
    for path in args.paths:
        print(json.dumps(inspect(path), ensure_ascii=False))

if __name__ == "__main__":
    main()
