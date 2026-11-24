#!/usr/bin/env python3
"""Fetch and verify the CC0 KinemIQ v1.0 archive; stage only bounded GLB files.

Never extracts arbitrary ZIP paths or persists a moving latest-release URL.
This is source acquisition, not an approval of a retargeted game animation.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import stat
import struct
import tempfile
import urllib.request
import zipfile

URL = "https://github.com/Kinemiq/free-game-animations/releases/download/v1.0/KinemIQ_Free_Animations_CC0_GLB.zip"
SHA256 = "64ca5ab4a92c9da079c5e88ca509391b0a58a24ccf2a1307b16e2f0fc6b23ffc"
MAX_ARCHIVE = 16 * 1024 * 1024
MAX_FILE = 12 * 1024 * 1024
MAX_TOTAL = 128 * 1024 * 1024


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def read_glb(data: bytes) -> dict:
    if len(data) < 20 or struct.unpack_from("<4sII", data) != (b"glTF", 2, len(data)):
        raise ValueError("Invalid GLB 2.0 header")
    size, kind = struct.unpack_from("<II", data, 12)
    if kind != 0x4E4F534A or size > len(data) - 20:
        raise ValueError("Invalid GLB JSON chunk")
    doc = json.loads(data[20:20+size].decode("utf-8"))
    if any(x.get("uri") and not x["uri"].startswith("data:")
           for x in doc.get("buffers", []) + doc.get("images", [])):
        raise ValueError("External GLB resource is not permitted")
    return doc


def binary_chunk(data: bytes) -> bytes:
    length = struct.unpack_from("<I", data, 12)[0]
    offset = 20 + length
    if offset + 8 > len(data):
        raise ValueError("GLB lacks BIN data")
    size, kind = struct.unpack_from("<II", data, offset)
    if kind != 0x004E4942 or offset + 8 + size != len(data):
        raise ValueError("Expected one bounded GLB binary chunk")
    return data[offset+8:]


def encode_glb(doc: dict, binary: bytes) -> bytes:
    text = json.dumps(doc, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    text += b" " * (-len(text) % 4)
    binary += b"\0" * (-len(binary) % 4)
    size = 12 + 8 + len(text) + 8 + len(binary)
    return (struct.pack("<4sII", b"glTF", 2, size)
            + struct.pack("<II", len(text), 0x4E4F534A) + text
            + struct.pack("<II", len(binary), 0x004E4942) + binary)


def attach_motion(reference: bytes, motion: bytes) -> bytes:
    """Bind animation-only glTF node tracks to the exact shared mannequin.

    Geometry, skin, inverse bind matrices and node hierarchy remain from the
    reference. The animation-only asset contributes only validated accessors,
    buffer views and channels whose named nodes exist on that reference.
    """
    import copy
    base, clip = read_glb(reference), read_glb(motion)
    if not base.get("skins") or not clip.get("animations") or clip.get("skins"):
        raise ValueError("Unexpected reference/animation-only asset")
    if len(base.get("buffers", [])) != 1 or len(clip.get("buffers", [])) != 1:
        raise ValueError("Expected one binary buffer per GLB")
    if any("uri" in d["buffers"][0] for d in (base, clip)):
        raise ValueError("Expected embedded binary buffers")
    a, b = binary_chunk(reference), binary_chunk(motion)
    a += b"\0" * (-len(a) % 4)
    output = copy.deepcopy(base)
    node_lookup = {}
    for i, node in enumerate(base.get("nodes", [])):
        name = node.get("name")
        if name:
            if name in node_lookup:
                raise ValueError("Ambiguous reference bone name: " + name)
            node_lookup[name] = i
    src_nodes = clip.get("nodes", [])
    offset_view = len(output.get("bufferViews", []))
    offset_accessor = len(output.get("accessors", []))
    for view in clip.get("bufferViews", []):
        value = copy.deepcopy(view)
        start, size = value.get("byteOffset", 0), value.get("byteLength", 0)
        if value.get("buffer", 0) != 0 or start < 0 or size < 0 or start + size > len(b):
            raise ValueError("Invalid source buffer view")
        value["byteOffset"] = len(a) + start
        output.setdefault("bufferViews", []).append(value)
    for source in clip.get("accessors", []):
        value = copy.deepcopy(source)
        if "bufferView" in value:
            value["bufferView"] += offset_view
        if "sparse" in value:
            for kind in ("indices", "values"):
                value["sparse"][kind]["bufferView"] += offset_view
        output.setdefault("accessors", []).append(value)
    output["animations"] = []
    for animation in clip["animations"]:
        value = copy.deepcopy(animation)
        for sampler in value.get("samplers", []):
            for kind in ("input", "output"):
                index = sampler[kind]
                if type(index) is not int or not 0 <= index < len(clip.get("accessors", [])):
                    raise ValueError("Invalid animation sampler")
                sampler[kind] += offset_accessor
        for channel in value.get("channels", []):
            target = channel["target"]
            index = target.get("node")
            if type(index) is not int or not 0 <= index < len(src_nodes):
                raise ValueError("Invalid animation target")
            name = src_nodes[index].get("name")
            if name not in node_lookup:
                raise ValueError("Animation targets an unknown reference node: " + str(name))
            if target.get("path") not in ("rotation", "translation", "scale"):
                raise ValueError("Unsupported motion channel")
            target["node"] = node_lookup[name]
        output["animations"].append(value)
    binary = a + b
    output["buffers"][0]["byteLength"] = len(binary)
    return encode_glb(output, binary)


def stage(archive: Path, output: Path) -> dict:
    raw = archive.read_bytes()
    if len(raw) > MAX_ARCHIVE or sha(raw) != SHA256:
        raise ValueError("Pinned archive checksum mismatch")
    output.mkdir(parents=True, exist_ok=True)
    if any(output.iterdir()):
        raise ValueError("Use an empty staging directory")
    entries = []
    total = 0
    used = set()
    with zipfile.ZipFile(archive) as z:
        if len(z.infolist()) > 256:
            raise ValueError("Archive member limit exceeded")
        for item in z.infolist():
            name = PurePosixPath(item.filename)
            if name.is_absolute() or ".." in name.parts or "\\" in item.filename:
                raise ValueError("Unsafe archive member")
            if stat.S_ISLNK(item.external_attr >> 16):
                raise ValueError("Archive symlink is not permitted")
            if item.is_dir() or name.suffix.lower() != ".glb":
                continue
            if not 0 < item.file_size <= MAX_FILE:
                raise ValueError("GLB size outside limits")
            total += item.file_size
            if total > MAX_TOTAL:
                raise ValueError("Expanded archive exceeds budget")
            data = z.read(item)
            doc = read_glb(data)
            safe = re.sub(r"[^A-Za-z0-9_-]", "_", name.stem)[:100] + ".glb"
            if safe.casefold() in used:
                safe = safe[:-4] + "_" + sha(data)[:12] + ".glb"
            if safe.casefold() in used:
                raise ValueError("Repeated GLB output name")
            used.add(safe.casefold())
            (output / safe).write_bytes(data)
            nodes = doc.get("nodes", [])
            joints = sorted({i for skin in doc.get("skins", []) for i in skin.get("joints", [])})
            entries.append({
                "file": safe, "archive_member": item.filename, "sha256": sha(data),
                "bytes": len(data), "animations": [a.get("name", "") for a in doc.get("animations", [])],
                "joint_names": [nodes[i].get("name", "") for i in joints],
            })
    if not entries or not any(x["animations"] for x in entries):
        raise ValueError("The archive contained no animated GLB")
    refs = [x for x in entries if x["joint_names"]]
    if len(refs) != 1 or refs[0]["file"] != "KinemIQ_Mannequin.glb":
        raise ValueError("Expected the single named upstream mannequin reference")
    reference = (output / refs[0]["file"]).read_bytes()
    reconstructed = 0
    for entry in entries:
        if entry["joint_names"]:
            entry["staged_sha256"] = entry["sha256"]
            continue
        path = output / entry["file"]
        derived = attach_motion(reference, path.read_bytes())
        path.write_bytes(derived)
        entry["staged_sha256"] = sha(derived)
        entry["staged_bytes"] = len(derived)
        entry["shared_reference"] = refs[0]["sha256"]
        reconstructed += 1
    if reconstructed != 35:
        raise ValueError("Unexpected motion-only clip inventory")
    return {"source_url": URL, "archive_sha256": SHA256, "license": "CC0-1.0",
            "reconstructed_motion_files": reconstructed,
            "upstream": "Quaternius Universal Animation Library; KinemIQ export v1.0",
            "glb_files": len(entries), "files": entries,
            "runtime_approved": False}


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--output", type=Path, required=True)
    p.add_argument("--report", type=Path, required=True)
    p.add_argument("--archive", type=Path)
    a = p.parse_args()
    with tempfile.TemporaryDirectory(prefix="cc0-motion-") as temp:
        archive = a.archive or Path(temp) / "source.zip"
        if not a.archive:
            request = urllib.request.Request(URL, headers={"User-Agent": "Imperathen-asset-validation"})
            with urllib.request.urlopen(request, timeout=90) as response:
                data = response.read(MAX_ARCHIVE + 1)
            if len(data) > MAX_ARCHIVE:
                raise ValueError("Download exceeded size limit")
            archive.write_bytes(data)
        report = stage(archive, a.output)
    a.report.parent.mkdir(parents=True, exist_ok=True)
    a.report.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(f"CC0_SOURCE_OK {report['glb_files']} GLBs; pinned archive verified")


if __name__ == "__main__":
    main()
