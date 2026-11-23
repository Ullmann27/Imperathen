#!/usr/bin/env python3
"""Inspect staged Meshy GLB files using only the Python standard library.

This is a binary/import gate. It does not claim Godot visual quality, rig
quality, animation retargeting, gameplay correctness, Android FPS or thermals.
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
from pathlib import Path
import struct
import sys
from typing import Any


GLB_MAGIC = b"glTF"
JSON_CHUNK = 0x4E4F534A
BIN_CHUNK = 0x004E4942
TRIANGLE_MODES = {4, 5, 6}


class GlbError(ValueError):
    pass


def _require(ok: bool, message: str) -> None:
    if not ok:
        raise GlbError(message)


def _parse_glb(path: Path) -> tuple[dict[str, Any], bytes]:
    data = path.read_bytes()
    _require(len(data) >= 20, "file is too short for GLB 2.0")
    magic, version, declared = struct.unpack_from("<4sII", data, 0)
    _require(magic == GLB_MAGIC, "invalid GLB magic")
    _require(version == 2, f"unsupported GLB version {version}")
    _require(declared == len(data), f"declared length {declared} != actual {len(data)}")
    offset = 12
    document: dict[str, Any] | None = None
    binary = b""
    while offset < len(data):
        _require(offset + 8 <= len(data), "truncated chunk header")
        length, kind = struct.unpack_from("<II", data, offset)
        offset += 8
        _require(offset + length <= len(data), "chunk exceeds file length")
        payload = data[offset:offset + length]
        offset += length
        if kind == JSON_CHUNK:
            _require(document is None, "multiple JSON chunks")
            document = json.loads(payload.rstrip(b" \t\r\n\0").decode("utf-8"))
        elif kind == BIN_CHUNK:
            _require(not binary, "multiple BIN chunks")
            binary = payload
    _require(document is not None, "missing JSON chunk")
    _require(str(document.get("asset", {}).get("version", "")).startswith("2"), "not glTF 2.x")
    return document, binary


def _accessor_count(doc: dict[str, Any], index: int) -> int:
    accessors = doc.get("accessors", [])
    _require(isinstance(index, int) and 0 <= index < len(accessors), f"bad accessor index {index}")
    value = accessors[index].get("count")
    _require(isinstance(value, int) and value >= 0, f"accessor {index} has invalid count")
    return value


def _triangles(doc: dict[str, Any], primitive: dict[str, Any]) -> int:
    mode = int(primitive.get("mode", 4))
    if mode not in TRIANGLE_MODES:
        return 0
    count = _accessor_count(doc, primitive["indices"]) if "indices" in primitive else _accessor_count(doc, primitive["attributes"]["POSITION"])
    if mode == 4:
        return count // 3
    return max(0, count - 2)


def _data_uri(uri: str) -> bytes | None:
    if not uri.startswith("data:") or "," not in uri:
        return None
    header, encoded = uri.split(",", 1)
    if ";base64" not in header:
        return None
    return base64.b64decode(encoded)


def _image_bytes(doc: dict[str, Any], binary: bytes, image: dict[str, Any]) -> bytes | None:
    if "bufferView" in image:
        views = doc.get("bufferViews", [])
        index = image["bufferView"]
        _require(isinstance(index, int) and 0 <= index < len(views), "bad image bufferView")
        view = views[index]
        _require(int(view.get("buffer", 0)) == 0, "GLB image references non-zero buffer")
        start = int(view.get("byteOffset", 0))
        length = int(view.get("byteLength", 0))
        _require(start >= 0 and length >= 0 and start + length <= len(binary), "image bufferView exceeds BIN")
        return binary[start:start + length]
    uri = image.get("uri")
    if isinstance(uri, str):
        return _data_uri(uri)
    return None


def _png_size(data: bytes) -> tuple[int, int] | None:
    if len(data) >= 24 and data.startswith(b"\x89PNG\r\n\x1a\n"):
        return struct.unpack(">II", data[16:24])
    return None


def _jpeg_size(data: bytes) -> tuple[int, int] | None:
    if len(data) < 4 or data[:2] != b"\xff\xd8":
        return None
    pos = 2
    while pos + 4 <= len(data):
        if data[pos] != 0xFF:
            pos += 1
            continue
        marker = data[pos + 1]
        pos += 2
        if marker in (0xD8, 0xD9) or 0xD0 <= marker <= 0xD7:
            continue
        if pos + 2 > len(data):
            return None
        length = int.from_bytes(data[pos:pos + 2], "big")
        if length < 2 or pos + length > len(data):
            return None
        if marker in {0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF} and length >= 7:
            height = int.from_bytes(data[pos + 3:pos + 5], "big")
            width = int.from_bytes(data[pos + 5:pos + 7], "big")
            return width, height
        pos += length
    return None


def _webp_size(data: bytes) -> tuple[int, int] | None:
    if len(data) < 30 or data[:4] != b"RIFF" or data[8:12] != b"WEBP":
        return None
    kind = data[12:16]
    if kind == b"VP8X" and len(data) >= 30:
        width = 1 + int.from_bytes(data[24:27], "little")
        height = 1 + int.from_bytes(data[27:30], "little")
        return width, height
    return None


def _image_size(data: bytes | None) -> tuple[int, int] | None:
    if not data:
        return None
    return _png_size(data) or _jpeg_size(data) or _webp_size(data)


def inspect_glb(path: Path) -> dict[str, Any]:
    doc, binary = _parse_glb(path)
    meshes = doc.get("meshes", [])
    primitive_count = 0
    triangle_count = 0
    vertex_count = 0
    primitives_with_normals = 0
    primitives_with_uv0 = 0
    primitives_with_tangents = 0
    for mesh in meshes:
        for primitive in mesh.get("primitives", []):
            primitive_count += 1
            attrs = primitive.get("attributes", {})
            _require("POSITION" in attrs, "primitive without POSITION")
            vertex_count += _accessor_count(doc, attrs["POSITION"])
            triangle_count += _triangles(doc, primitive)
            primitives_with_normals += int("NORMAL" in attrs)
            primitives_with_uv0 += int("TEXCOORD_0" in attrs)
            primitives_with_tangents += int("TANGENT" in attrs)

    images = doc.get("images", [])
    image_records = []
    external_uris = []
    for image in images:
        uri = image.get("uri")
        if isinstance(uri, str) and not uri.startswith("data:"):
            external_uris.append(uri)
        raw = _image_bytes(doc, binary, image)
        size = _image_size(raw)
        image_records.append({
            "mime_type": image.get("mimeType"),
            "embedded": raw is not None,
            "size": list(size) if size else None,
            "bytes": len(raw) if raw else None,
        })
    for buffer in doc.get("buffers", []):
        uri = buffer.get("uri")
        if isinstance(uri, str) and not uri.startswith("data:"):
            external_uris.append(uri)

    materials = doc.get("materials", [])
    pbr_count = sum(isinstance(item.get("pbrMetallicRoughness"), dict) for item in materials)
    textures = doc.get("textures", [])
    skins = doc.get("skins", [])
    animations = doc.get("animations", [])

    bounds_min = [float("inf")] * 3
    bounds_max = [float("-inf")] * 3
    bounded = False
    for mesh in meshes:
        for primitive in mesh.get("primitives", []):
            accessor = doc.get("accessors", [])[primitive["attributes"]["POSITION"]]
            lower, upper = accessor.get("min"), accessor.get("max")
            if isinstance(lower, list) and isinstance(upper, list) and len(lower) >= 3 and len(upper) >= 3:
                for axis in range(3):
                    bounds_min[axis] = min(bounds_min[axis], float(lower[axis]))
                    bounds_max[axis] = max(bounds_max[axis], float(upper[axis]))
                bounded = True

    geometry_gate = primitive_count > 0 and triangle_count > 0 and primitives_with_normals == primitive_count
    material_gate = len(materials) > 0 and pbr_count > 0
    texture_gate = len(images) > 0 and all(item["embedded"] for item in image_records) and not external_uris
    static_binary_gate = geometry_gate and material_gate and texture_gate
    character_rig_gate = static_binary_gate and len(skins) > 0 and len(animations) > 0

    return {
        "path": str(path),
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        "size_bytes": path.stat().st_size,
        "meshes": len(meshes),
        "primitives": primitive_count,
        "vertices_sum": vertex_count,
        "triangles": triangle_count,
        "materials": len(materials),
        "pbr_materials": pbr_count,
        "textures": len(textures),
        "images": image_records,
        "skins": len(skins),
        "animations": len(animations),
        "nodes": len(doc.get("nodes", [])),
        "scenes": len(doc.get("scenes", [])),
        "primitives_with_normals": primitives_with_normals,
        "primitives_with_uv0": primitives_with_uv0,
        "primitives_with_tangents": primitives_with_tangents,
        "self_contained": not external_uris,
        "external_uris": external_uris,
        "local_bounds_min": bounds_min if bounded else None,
        "local_bounds_max": bounds_max if bounded else None,
        "static_binary_gate": static_binary_gate,
        "character_rig_gate": character_rig_gate,
    }


def inspect_manifest(manifest_path: Path, repo_root: Path, require_all: bool = False) -> tuple[dict[str, Any], bool]:
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    results = []
    ok = True
    for entry in manifest.get("assets", []):
        rel = Path(str(entry.get("intended_source_path", ""))).as_posix()
        source = repo_root / rel
        record: dict[str, Any] = {
            "stable_id": entry.get("stable_id"),
            "category": entry.get("category"),
            "expected_path": rel,
            "present": source.is_file(),
        }
        if source.is_file():
            try:
                record["inspection"] = inspect_glb(source)
            except (OSError, GlbError, json.JSONDecodeError, UnicodeDecodeError, ValueError) as exc:
                record["error"] = str(exc)
                ok = False
        elif require_all and entry.get("status") == "ready_in_meshy":
            record["error"] = "required final GLB is missing"
            ok = False
        results.append(record)
    return {
        "manifest": str(manifest_path),
        "assets": len(results),
        "present": sum(item["present"] for item in results),
        "missing": sum(not item["present"] for item in results),
        "results": results,
    }, ok


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=Path, default=Path("prototype/assets/meshy/manifest.json"))
    parser.add_argument("--repo-root", type=Path, default=Path("."))
    parser.add_argument("--report", type=Path)
    parser.add_argument("--require-all", action="store_true")
    args = parser.parse_args()
    try:
        report, ok = inspect_manifest(args.manifest, args.repo_root, args.require_all)
    except (OSError, json.JSONDecodeError, GlbError, ValueError) as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return 1
    payload = json.dumps(report, indent=2, ensure_ascii=False) + "\n"
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(payload, encoding="utf-8")
    print(payload, end="")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
