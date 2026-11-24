"""Lossless packaging for existing Hero assets below the connector blob limit.

No model, weight, animation or image pixel is regenerated. The Blender stream
is recompressed verbatim; one original PNG is moved out of an oversized GLB.
The generator calls the same functions after every new build or refit.
"""
from __future__ import annotations

import argparse
from copy import deepcopy
import gzip
import hashlib
import json
from pathlib import Path
import shutil
import struct
import subprocess

ROOT = Path(__file__).resolve().parents[2]
MAX_BLOB_BYTES = 12 * 1024 * 1024
SKIN_IMAGE_NAME = "young_lightskinned_female_diffuse"
# This exact PNG and its lossless Godot import settings are already tracked.
# Reuse their existing path, rather than creating a duplicate texture source.
SKIN_URI = "hero_quality_0_young_lightskinned_female_diffuse.png"


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _replace(path: Path, data: bytes) -> None:
    temporary = path.with_name(path.name + ".tmp")
    temporary.write_bytes(data)
    temporary.replace(path)


def pack_blend_lossless(path: Path) -> dict:
    executable = shutil.which("zstd")
    if not executable:
        raise RuntimeError("Lossless Hero delivery requires the zstd command")
    original = path.read_bytes()
    if original.startswith(b"BLENDER"):
        stream = original
    elif original.startswith(b"\x1f\x8b"):
        stream = gzip.decompress(original)
    else:
        stream = subprocess.run([executable, "-d", "-q", "-c"], input=original,
                                stdout=subprocess.PIPE, check=True).stdout
    if not stream.startswith(b"BLENDER"):
        raise ValueError("The decompressed authoring file is not a Blender file")
    packed = subprocess.run([executable, "-19", "-T2", "-q", "-c"], input=stream,
                            stdout=subprocess.PIPE, check=True).stdout
    restored = subprocess.run([executable, "-d", "-q", "-c"], input=packed,
                              stdout=subprocess.PIPE, check=True).stdout
    if restored != stream:
        raise AssertionError("Blender packaging changed the decompressed stream")
    if len(packed) >= MAX_BLOB_BYTES:
        raise ValueError("Lossless Blender source still exceeds the delivery limit")
    _replace(path, packed)
    return {"method": "zstd -19 -T2", "before_bytes": len(original), "after_bytes": len(packed),
            "before_sha256": sha256(original), "after_sha256": sha256(packed),
            "decompressed_bytes": len(stream), "decompressed_sha256": sha256(stream),
            "decompressed_stream_byte_identical": True}


def read_glb(data: bytes) -> tuple[dict, bytes]:
    if len(data) < 28 or struct.unpack_from("<4sII", data) != (b"glTF", 2, len(data)):
        raise ValueError("Expected a complete glTF 2 binary")
    size, kind = struct.unpack_from("<II", data, 12)
    if kind != 0x4E4F534A:
        raise ValueError("Missing GLB JSON chunk")
    document = json.loads(data[20:20 + size])
    length, kind = struct.unpack_from("<II", data, 20 + size)
    if kind != 0x004E4942 or 28 + size + length != len(data):
        raise ValueError("Expected exactly one embedded GLB binary chunk")
    if len(document["buffers"]) != 1 or document["buffers"][0].get("uri"):
        raise ValueError("Expected one embedded Hero buffer")
    return document, data[28 + size:]


def _payload(binary: bytes, view: dict) -> bytes:
    start, length = view.get("byteOffset", 0), view["byteLength"]
    if view.get("buffer", 0) != 0 or start < 0 or length <= 0 or start + length > len(binary):
        raise ValueError("Invalid Hero buffer view")
    return binary[start:start + length]


def pack_hero_glb(path: Path) -> dict:
    original = path.read_bytes()
    document, binary = read_glb(original)
    if len(original) < MAX_BLOB_BYTES:
        external = [item["uri"] for item in document.get("images", []) if "uri" in item]
        for uri in external:
            if uri != SKIN_URI or not (path.parent / uri).is_file():
                raise ValueError("Hero image source is missing or unexpected")
        return {"already_within_limit": True, "external_image_uris": external,
                "bytes": len(original), "sha256": sha256(original)}
    changed = deepcopy(document)
    images = [item for item in changed["images"] if item.get("name") == SKIN_IMAGE_NAME]
    if len(images) != 1 or images[0].get("mimeType") != "image/png" or "bufferView" not in images[0]:
        raise ValueError("Expected the original embedded Hero skin PNG")
    image = images[0]
    removed = image.pop("bufferView")
    image["uri"] = SKIN_URI
    png = _payload(binary, document["bufferViews"][removed])
    if not png.startswith(b"\x89PNG\r\n\x1a\n"):
        raise ValueError("Hero skin source is not a PNG")
    external = path.parent / SKIN_URI
    external.parent.mkdir(parents=True, exist_ok=True)
    _replace(external, png)

    # Keep every remaining view's exact bytes and attributes. Only offsets and
    # view indices change when the image payload is removed from the buffer.
    packed = bytearray()
    views = []
    preserved = []
    for old_index, view in enumerate(document["bufferViews"]):
        if old_index == removed:
            continue
        payload = _payload(binary, view)
        packed.extend(b"\0" * (-len(packed) % 4))
        current = deepcopy(view)
        current["byteOffset"] = len(packed)
        views.append(current)
        packed.extend(payload)
        preserved.append((old_index, len(views) - 1, payload))

    def remap_views(value):
        if isinstance(value, dict):
            for key, child in value.items():
                if key == "bufferView":
                    if child == removed:
                        raise ValueError("Removed image view is referenced by non-image data")
                    value[key] = child - 1 if child > removed else child
                else:
                    remap_views(child)
        elif isinstance(value, list):
            for child in value:
                remap_views(child)

    changed["bufferViews"] = views
    remap_views(changed)
    changed["buffers"][0]["byteLength"] = len(packed)
    encoded = json.dumps(changed, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    encoded += b" " * (-len(encoded) % 4)
    packed.extend(b"\0" * (-len(packed) % 4))
    total = 28 + len(encoded) + len(packed)
    result = (struct.pack("<4sIIII", b"glTF", 2, total, len(encoded), 0x4E4F534A)
              + encoded + struct.pack("<II", len(packed), 0x004E4942) + packed)
    actual_document, actual_binary = read_glb(result)
    for _, new_index, payload in preserved:
        if _payload(actual_binary, actual_document["bufferViews"][new_index]) != payload:
            raise AssertionError("Hero geometry, skin, animation or embedded image bytes changed")
    if external.read_bytes() != png or len(result) >= MAX_BLOB_BYTES:
        raise AssertionError("External image identity or final delivery size is invalid")
    _replace(path, result)
    return {"method": "Move one original PNG to a tracked image URI; preserve all other view bytes",
            "before_bytes": len(original), "after_bytes": len(result),
            "before_sha256": sha256(original), "after_sha256": sha256(result),
            "external_image_uri": SKIN_URI, "external_image_bytes": len(png),
            "external_image_sha256": sha256(png), "external_image_byte_identical": True,
            "preserved_buffer_views": len(preserved), "other_buffer_view_payloads_byte_identical": True}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--evidence", type=Path)
    args = parser.parse_args()
    source = ROOT / "art/hero_quality/hero.blend"
    model = ROOT / "prototype/assets/characters/hero_quality_0.glb"
    evidence = {"blend": pack_blend_lossless(source), "glb": pack_hero_glb(model),
                "maximum_blob_bytes_exclusive": MAX_BLOB_BYTES}
    report_path = ROOT / "art/hero_quality/build_report.json"
    report = json.loads(report_path.read_text())
    report["lossless_source_packaging"] = evidence["blend"]
    for level in report["lods"]:
        if level["lod"] == 0:
            level.update(bytes=model.stat().st_size, sha256=sha256(model.read_bytes()),
                         lossless_delivery=evidence["glb"])
    report_path.write_text(json.dumps(report, indent=2) + "\n")
    if args.evidence:
        args.evidence.parent.mkdir(parents=True, exist_ok=True)
        args.evidence.write_text(json.dumps(evidence, indent=2) + "\n")
    print(json.dumps(evidence))


if __name__ == "__main__":
    main()
