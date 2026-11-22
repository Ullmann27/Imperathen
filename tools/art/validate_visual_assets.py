#!/usr/bin/env python3
"""Inspect the project's self-contained GLB assets without third-party packages.

This is a deliberately scoped export gate, not a complete Khronos validator or
an engine/visual/performance test. It reads the actual vertex/index/image bytes.
See https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html .
"""

from __future__ import annotations

import argparse
import base64
import binascii
import hashlib
import json
import math
from pathlib import Path
import struct
import sys
from datetime import datetime, timezone
import zlib


COMPONENTS = {
    5120: ("b", 1), 5121: ("B", 1), 5122: ("h", 2),
    5123: ("H", 2), 5125: ("I", 4), 5126: ("f", 4),
}
SHAPES = {"SCALAR": (1, 1), "VEC2": (1, 2), "VEC3": (1, 3),
          "VEC4": (1, 4), "MAT2": (2, 2), "MAT3": (3, 3), "MAT4": (4, 4)}
TEXTURE_SLOTS = ("normalTexture", "occlusionTexture", "emissiveTexture")
MAX_ACCESSOR_COUNT = 2_000_000
IDENTITY = (1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
SUPPORTED_REQUIRED_EXTENSIONS = {
    "KHR_materials_unlit", "KHR_materials_emissive_strength",
    "KHR_texture_transform", "KHR_materials_ior", "KHR_materials_specular",
}


class InvalidAsset(ValueError):
    """A failed structural/export-policy requirement with a useful location."""


def require(condition: bool, message: str) -> None:
    if not condition:
        raise InvalidAsset(message)


def integer(value: object, label: str, minimum: int = 0) -> int:
    require(type(value) is int and value >= minimum,
            f"{label}: expected integer >= {minimum}, got {value!r}")
    return value


def index(value: object, values: list, label: str) -> int:
    number = integer(value, label)
    require(number < len(values), f"{label}: index {number} outside 0..{len(values)-1}")
    return number


def vector(value: object, size: int, label: str) -> list:
    require(isinstance(value, list) and len(value) == size,
            f"{label}: expected {size} finite numeric components")
    require(all(type(v) in (float, int) and math.isfinite(v) for v in value),
            f"{label}: non-finite or non-numeric component")
    return value


def objects(document: dict, name: str) -> list:
    value = document.get(name, [])
    require(isinstance(value, list) and all(isinstance(v, dict) for v in value),
            f"{name}: expected an array of objects")
    return value


def embedded_uri(uri: object, label: str) -> tuple[str, bytes]:
    require(isinstance(uri, str) and uri.startswith("data:"),
            f"{label}: external URI/path is forbidden; embed the bytes in the GLB")
    header, separator, payload = uri.partition(",")
    require(separator == "," and header.endswith(";base64"),
            f"{label}: only base64 data URIs are supported")
    try:
        data = base64.b64decode(payload, validate=True)
    except (ValueError, binascii.Error) as exc:
        raise InvalidAsset(f"{label}: malformed base64 data") from exc
    return header[5:-7], data


def reject_constant(value: str) -> None:
    raise InvalidAsset(f"JSON contains a non-finite number: {value}")


def read_glb(data: bytes) -> tuple[dict, bytes, list[str]]:
    require(len(data) >= 20, "GLB header/chunk header is truncated")
    magic, version, declared_length = struct.unpack_from("<4sII", data)
    require(magic == b"glTF", "GLB magic must be glTF")
    require(version == 2, f"Unsupported GLB version {version}; expected 2")
    require(declared_length == len(data),
            f"GLB length mismatch: header {declared_length}, actual {len(data)}")
    cursor, chunks = 12, []
    while cursor < len(data):
        require(cursor + 8 <= len(data), "Truncated GLB chunk header")
        length, kind = struct.unpack_from("<I4s", data, cursor)
        cursor += 8
        require(length % 4 == 0, "GLB chunk length must be aligned to four bytes")
        require(cursor + length <= len(data), "GLB chunk exceeds declared file length")
        chunks.append((kind, data[cursor:cursor+length]))
        cursor += length
    require(chunks and chunks[0][0] == b"JSON", "First GLB chunk must be JSON")
    require(sum(kind == b"JSON" for kind, _ in chunks) == 1, "Duplicate JSON chunk")
    require(sum(kind == b"BIN\x00" for kind, _ in chunks) <= 1, "Duplicate BIN chunk")
    require(not any(kind == b"BIN\x00" for kind, _ in chunks[2:]),
            "BIN chunk must immediately follow JSON")
    try:
        document = json.loads(chunks[0][1].decode("utf-8"), parse_constant=reject_constant)
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise InvalidAsset(f"Malformed GLB JSON: {exc}") from exc
    require(isinstance(document, dict), "glTF JSON root must be an object")
    require(isinstance(document.get("asset"), dict)
            and document["asset"].get("version") == "2.0", "asset.version must be 2.0")
    binary = next((payload for kind, payload in chunks if kind == b"BIN\x00"), b"")
    unknown = [f"Unknown optional chunk {kind!r} skipped" for kind, _ in chunks
               if kind not in (b"JSON", b"BIN\x00")]
    return document, binary, unknown


def image_info(data: bytes, mime: str, label: str) -> dict:
    """Verify PNG chunk integrity or JPEG structure; do not claim pixel decoding."""
    if mime == "image/png":
        require(data.startswith(b"\x89PNG\r\n\x1a\n"), f"{label}: invalid PNG signature")
        cursor, width, height, seen_end, seen_pixels = 8, 0, 0, False, False
        while cursor < len(data):
            require(cursor + 12 <= len(data), f"{label}: truncated PNG chunk")
            length = struct.unpack_from(">I", data, cursor)[0]
            kind = data[cursor+4:cursor+8]
            end = cursor + 12 + length
            require(end <= len(data), f"{label}: PNG chunk exceeds image length")
            payload = data[cursor+8:cursor+8+length]
            crc = struct.unpack_from(">I", data, cursor+8+length)[0]
            require(zlib.crc32(kind + payload) & 0xFFFFFFFF == crc,
                    f"{label}: PNG {kind!r} CRC mismatch")
            if cursor == 8:
                require(kind == b"IHDR" and length == 13, f"{label}: missing PNG IHDR")
                width, height = struct.unpack_from(">II", payload)
            if kind == b"IDAT":
                seen_pixels = True
            if kind == b"IEND":
                require(length == 0 and end == len(data), f"{label}: malformed PNG IEND")
                seen_end = True
            cursor = end
        require(seen_end and seen_pixels, f"{label}: PNG lacks IDAT or IEND")
    elif mime == "image/jpeg":
        require(data.startswith(b"\xff\xd8") and data.endswith(b"\xff\xd9"),
                f"{label}: incomplete JPEG signature/EOI")
        cursor, width, height = 2, 0, 0
        while cursor + 3 < len(data):
            require(data[cursor] == 0xFF, f"{label}: invalid JPEG marker")
            while cursor < len(data) and data[cursor] == 0xFF:
                cursor += 1
            require(cursor < len(data), f"{label}: truncated JPEG marker")
            marker = data[cursor]
            cursor += 1
            if marker in (0xDA, 0xD9):
                break
            if marker in (0x01, *range(0xD0, 0xD9)):
                continue
            require(cursor + 2 <= len(data), f"{label}: truncated JPEG segment")
            length = struct.unpack_from(">H", data, cursor)[0]
            require(length >= 2 and cursor + length <= len(data),
                    f"{label}: JPEG segment exceeds image length")
            if marker in (0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7,
                          0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF):
                require(length >= 8, f"{label}: truncated JPEG frame")
                height, width = struct.unpack_from(">HH", data, cursor+3)
            cursor += length
    else:
        raise InvalidAsset(f"{label}: unsupported image MIME {mime!r}; use PNG or JPEG")
    require(0 < width <= 16384 and 0 < height <= 16384,
            f"{label}: implausible image dimensions {width}x{height}")
    return {"mime_type": mime, "width": width, "height": height,
            "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def multiply(a: tuple, b: tuple) -> tuple:
    return tuple(sum(a[k*4+row] * b[col*4+k] for k in range(4))
                 for col in range(4) for row in range(4))


def node_matrix(node: dict, label: str) -> tuple:
    if "matrix" in node:
        require(not any(key in node for key in ("translation", "rotation", "scale")),
                f"{label}: matrix and TRS cannot coexist")
        values = vector(node["matrix"], 16, f"{label}.matrix")
        require(all(abs(values[i]) < 1e-6 for i in (3, 7, 11))
                and abs(values[15]-1) < 1e-6, f"{label}: matrix must be affine")
        return tuple(values)
    t = vector(node.get("translation", [0, 0, 0]), 3, f"{label}.translation")
    s = vector(node.get("scale", [1, 1, 1]), 3, f"{label}.scale")
    q = vector(node.get("rotation", [0, 0, 0, 1]), 4, f"{label}.rotation")
    require(all(abs(v) > 1e-12 for v in s), f"{label}: zero scale collapses geometry")
    require(abs(sum(v*v for v in q)-1) < .002, f"{label}: quaternion is not unit length")
    x, y, z, w = q
    return ((1-2*y*y-2*z*z)*s[0], (2*x*y+2*z*w)*s[0], (2*x*z-2*y*w)*s[0], 0,
            (2*x*y-2*z*w)*s[1], (1-2*x*x-2*z*z)*s[1], (2*y*z+2*x*w)*s[1], 0,
            (2*x*z+2*y*w)*s[2], (2*y*z-2*x*w)*s[2], (1-2*x*x-2*y*y)*s[2], 0,
            *t, 1)


class Inspection:
    def __init__(self, document: dict, binary: bytes, warnings: list[str]):
        self.doc, self.binary, self.warnings = document, binary, warnings
        self.arrays = {name: objects(document, name) for name in (
            "buffers", "bufferViews", "accessors", "meshes", "materials", "images",
            "textures", "samplers", "nodes", "scenes", "skins", "animations", "cameras")}
        self.buffers: list[bytes] = []
        self.decoded: dict[int, list[tuple]] = {}
        self.material_uvs: dict[int, set[int]] = {}
        self.material_details: list[dict] = []

    def at(self, name: str, value: object, label: str) -> dict:
        return self.arrays[name][index(value, self.arrays[name], label)]

    def view_data(self, value: object, label: str) -> tuple[dict, bytes]:
        view = self.at("bufferViews", value, label)
        start = view.get("byteOffset", 0)
        return view, self.buffers[view["buffer"]][start:start+view["byteLength"]]

    def inspect_buffers(self) -> None:
        require(self.arrays["buffers"], "No buffers found")
        for i, buffer in enumerate(self.arrays["buffers"]):
            size = integer(buffer.get("byteLength"), f"buffers[{i}].byteLength", 1)
            if "uri" in buffer:
                _, data = embedded_uri(buffer["uri"], f"buffers[{i}].uri")
                require(len(data) == size, f"buffers[{i}]: embedded size mismatch")
            else:
                require(i == 0 and self.binary, f"buffers[{i}]: no accessible embedded bytes")
                data = self.binary
                require(size <= len(data) <= size+3,
                        f"buffers[{i}]: BIN length differs from byteLength plus padding")
                require(all(v == 0 for v in data[size:]), "BIN padding must contain zero bytes")
            self.buffers.append(data[:size])
        for i, view in enumerate(self.arrays["bufferViews"]):
            bi = index(view.get("buffer"), self.buffers, f"bufferViews[{i}].buffer")
            start = integer(view.get("byteOffset", 0), f"bufferViews[{i}].byteOffset")
            size = integer(view.get("byteLength"), f"bufferViews[{i}].byteLength", 1)
            require(start+size <= len(self.buffers[bi]), f"bufferViews[{i}]: exceeds buffer")
            if "byteStride" in view:
                stride = integer(view["byteStride"], f"bufferViews[{i}].byteStride", 4)
                require(stride <= 252 and stride % 4 == 0,
                        f"bufferViews[{i}]: byteStride must be 4..252, multiple of 4")
            if "target" in view:
                require(view["target"] in (34962, 34963), f"bufferViews[{i}]: invalid target")

    @staticmethod
    def layout(accessor: dict, label: str) -> tuple[str, int, list[int], int]:
        component = accessor.get("componentType")
        require(component in COMPONENTS, f"{label}: unsupported componentType {component!r}")
        kind = accessor.get("type")
        require(kind in SHAPES, f"{label}: invalid accessor type {kind!r}")
        fmt, size = COMPONENTS[component]
        columns, rows = SHAPES[kind]
        column_stride = ((rows*size+3)//4)*4 if columns > 1 else rows*size
        offsets = [col*column_stride+row*size for col in range(columns) for row in range(rows)]
        return fmt, size, offsets, columns*column_stride

    def decode(self, ai: int) -> list[tuple]:
        if ai in self.decoded:
            return self.decoded[ai]
        accessor = self.at("accessors", ai, f"accessor {ai}")
        label = f"accessors[{ai}]"
        count = integer(accessor.get("count"), f"{label}.count", 1)
        require(count <= MAX_ACCESSOR_COUNT, f"{label}: exceeds inspection budget of {MAX_ACCESSOR_COUNT}")
        fmt, size, offsets, packed_stride = self.layout(accessor, label)
        start = integer(accessor.get("byteOffset", 0), f"{label}.byteOffset")
        require(start % size == 0, f"{label}: component alignment error")
        if "bufferView" in accessor:
            view, data = self.view_data(accessor["bufferView"], f"{label}.bufferView")
            stride = view.get("byteStride", packed_stride)
            require(stride >= packed_stride and stride % size == 0,
                    f"{label}: incompatible byteStride")
            require((view.get("byteOffset", 0)+start) % size == 0,
                    f"{label}: absolute component alignment error")
            if accessor["type"].startswith("MAT"):
                require((view.get("byteOffset", 0)+start) % 4 == 0,
                        f"{label}: matrix column alignment error")
            end = start+(count-1)*stride+offsets[-1]+size
            require(end <= len(data), f"{label}: data exceeds bufferView ({end} > {len(data)})")
            values = [tuple(struct.unpack_from("<"+fmt, data, start+n*stride+off)[0]
                            for off in offsets) for n in range(count)]
        else:
            require(start == 0, f"{label}: byteOffset without bufferView")
            values = [tuple(0 for _ in offsets) for _ in range(count)]
        if "sparse" in accessor:
            sparse = accessor["sparse"]
            require(isinstance(sparse, dict), f"{label}.sparse must be an object")
            scount = integer(sparse.get("count"), f"{label}.sparse.count", 1)
            require(scount <= count, f"{label}: sparse count exceeds accessor count")
            indices, replacement = sparse.get("indices"), sparse.get("values")
            require(isinstance(indices, dict) and isinstance(replacement, dict),
                    f"{label}: malformed sparse data")
            component = indices.get("componentType")
            require(component in (5121, 5123, 5125), f"{label}: invalid sparse index type")
            ifmt, isize = COMPONENTS[component]
            iview, idata = self.view_data(indices.get("bufferView"), f"{label}.sparse.indices")
            vview, vdata = self.view_data(replacement.get("bufferView"), f"{label}.sparse.values")
            require("byteStride" not in iview and "byteStride" not in vview,
                    f"{label}: sparse views cannot be interleaved")
            istart = integer(indices.get("byteOffset", 0), f"{label}.sparse.indices.byteOffset")
            vstart = integer(replacement.get("byteOffset", 0), f"{label}.sparse.values.byteOffset")
            require((iview.get("byteOffset", 0)+istart) % isize == 0
                    and (vview.get("byteOffset", 0)+vstart) % size == 0,
                    f"{label}: sparse component alignment error")
            require(istart+scount*isize <= len(idata)
                    and vstart+(scount-1)*packed_stride+offsets[-1]+size <= len(vdata),
                    f"{label}: sparse data exceeds bufferView")
            previous = -1
            for n in range(scount):
                target = struct.unpack_from("<"+ifmt, idata, istart+n*isize)[0]
                require(previous < target < count, f"{label}: sparse indices must be ascending and in range")
                values[target] = tuple(struct.unpack_from("<"+fmt, vdata,
                                      vstart+n*packed_stride+off)[0] for off in offsets)
                previous = target
        require(all(all(math.isfinite(v) for v in row) for row in values),
                f"{label}: non-finite actual accessor data")
        for key, reducer in (("min", min), ("max", max)):
            if key in accessor:
                declared = vector(accessor[key], len(offsets), f"{label}.{key}")
                actual = [reducer(row[c] for row in values) for c in range(len(offsets))]
                require(all(math.isclose(a, b, rel_tol=1e-5, abs_tol=1e-6)
                            for a, b in zip(declared, actual)),
                        f"{label}.{key}: declared bounds do not match decoded bytes")
        self.decoded[ai] = values
        return values

    def inspect_images_materials(self) -> list[dict]:
        image_results = []
        for i, image in enumerate(self.arrays["images"]):
            label = f"images[{i}]"
            require(("uri" in image) != ("bufferView" in image),
                    f"{label}: exactly one embedded image source required")
            if "uri" in image:
                mime, data = embedded_uri(image["uri"], f"{label}.uri")
                require(image.get("mimeType", mime) == mime, f"{label}: MIME mismatch")
            else:
                view, data = self.view_data(image["bufferView"], f"{label}.bufferView")
                require("byteStride" not in view, f"{label}: image view cannot be interleaved")
                mime = image.get("mimeType")
            info = image_info(data, mime, label)
            info.update({"index": i, "name": image.get("name", f"image_{i}"), "embedded": True})
            image_results.append(info)
            if max(info["width"], info["height"]) > 4096:
                self.warnings.append(f"{label}: texture exceeds the 4096-pixel review budget")
        for i, texture in enumerate(self.arrays["textures"]):
            self.at("images", texture.get("source"), f"textures[{i}].source")
            if "sampler" in texture:
                self.at("samplers", texture["sampler"], f"textures[{i}].sampler")
        for i, material in enumerate(self.arrays["materials"]):
            label = f"materials[{i}]"
            pbr = material.get("pbrMetallicRoughness", {})
            require(isinstance(pbr, dict), f"{label}.pbrMetallicRoughness must be object")
            factors = vector(pbr.get("baseColorFactor", [1, 1, 1, 1]), 4, f"{label}.baseColorFactor")
            require(all(0 <= v <= 1 for v in factors), f"{label}: base color out of range")
            for name in ("metallicFactor", "roughnessFactor"):
                value = pbr.get(name, 1)
                require(type(value) in (int, float) and math.isfinite(value) and 0 <= value <= 1,
                        f"{label}.{name}: expected finite number in [0, 1]")
            slots = [(name, pbr[name]) for name in ("baseColorTexture", "metallicRoughnessTexture")
                     if name in pbr]
            slots += [(name, material[name]) for name in TEXTURE_SLOTS if name in material]
            specular = material.get("extensions", {}).get("KHR_materials_specular", {})
            slots += [(name, specular[name]) for name in ("specularTexture", "specularColorTexture")
                      if name in specular]
            uvs = set()
            for name, info in slots:
                require(isinstance(info, dict), f"{label}.{name}: invalid texture info")
                self.at("textures", info.get("index"), f"{label}.{name}.index")
                uv = info.get("extensions", {}).get("KHR_texture_transform", {}).get(
                    "texCoord", info.get("texCoord", 0))
                uvs.add(integer(uv, f"{label}.{name}.texCoord"))
            self.material_uvs[i] = uvs
            self.material_details.append({
                "index": i, "name": material.get("name", f"material_{i}"),
                "texture_slots": [name for name, _ in slots],
                "required_uv_channels": sorted(uvs),
                "has_basecolor_texture": "baseColorTexture" in pbr,
                "has_normal_texture": "normalTexture" in material,
                "has_metallic_roughness_texture": "metallicRoughnessTexture" in pbr,
                "metallic_factor": pbr.get("metallicFactor", 1),
                "roughness_factor": pbr.get("roughnessFactor", 1),
            })
        if not any(self.material_uvs.values()):
            self.warnings.append("No material uses embedded textures; material-detail visual review is still needed")
        return image_results

    def inspect_meshes(self) -> tuple[list[list[tuple]], int, int]:
        mesh_points, triangles, primitives = [], 0, 0
        for mi, mesh in enumerate(self.arrays["meshes"]):
            plist = mesh.get("primitives")
            require(isinstance(plist, list) and plist, f"meshes[{mi}]: missing primitives")
            points = []
            for pi, primitive in enumerate(plist):
                label = f"meshes[{mi}].primitives[{pi}]"
                require(isinstance(primitive, dict), f"{label}: expected object")
                require(primitive.get("mode", 4) == 4, f"{label}: this export gate requires TRIANGLES mode")
                attributes = primitive.get("attributes")
                require(isinstance(attributes, dict), f"{label}: missing attributes")
                position = self.at("accessors", attributes.get("POSITION"), f"{label}.POSITION")
                require(position.get("type") == "VEC3" and position.get("componentType") == 5126,
                        f"{label}: POSITION must be FLOAT VEC3")
                require("min" in position and "max" in position, f"{label}: POSITION requires min and max")
                positions = self.decode(attributes["POSITION"])
                count = len(positions)
                for semantic, ai in attributes.items():
                    acc = self.at("accessors", ai, f"{label}.{semantic}")
                    require(len(self.decode(ai)) == count, f"{label}.{semantic}: vertex count mismatch")
                    if "bufferView" in acc:
                        require(acc.get("byteOffset", 0) % 4 == 0,
                                f"{label}.{semantic}: vertex offset must be aligned to 4 bytes")
                targets = primitive.get("targets", [])
                require(isinstance(targets, list) and all(isinstance(v, dict) for v in targets),
                        f"{label}.targets: expected array of attribute objects")
                for ti, target in enumerate(targets):
                    for semantic, ai in target.items():
                        self.at("accessors", ai, f"{label}.targets[{ti}].{semantic}")
                        require(len(self.decode(ai)) == count,
                                f"{label}.targets[{ti}].{semantic}: vertex count mismatch")
                normal = self.at("accessors", attributes.get("NORMAL"), f"{label}.NORMAL")
                require(normal.get("type") == "VEC3" and normal.get("componentType") == 5126,
                        f"{label}: NORMAL must be FLOAT VEC3")
                require(all(abs(sum(v*v for v in n)-1) <= .02 for n in self.decode(attributes["NORMAL"])),
                        f"{label}: normal vectors must have unit length")
                if "indices" in primitive:
                    ia = self.at("accessors", primitive["indices"], f"{label}.indices")
                    require(ia.get("type") == "SCALAR" and ia.get("componentType") in (5121, 5123, 5125)
                            and not ia.get("normalized", False), f"{label}: invalid triangle indices")
                    indices = [row[0] for row in self.decode(primitive["indices"])]
                    require(all(i < count for i in indices), f"{label}: triangle index exceeds POSITION count")
                else:
                    indices = list(range(count))
                require(len(indices) >= 3 and len(indices) % 3 == 0,
                        f"{label}: triangle index/vertex count must be a positive multiple of 3")
                valid_triangles = 0
                for offset in range(0, len(indices), 3):
                    a, b, c = (positions[indices[offset+j]] for j in range(3))
                    u, v = [b[k]-a[k] for k in range(3)], [c[k]-a[k] for k in range(3)]
                    cross = (u[1]*v[2]-u[2]*v[1], u[2]*v[0]-u[0]*v[2], u[0]*v[1]-u[1]*v[0])
                    valid_triangles += sum(x*x for x in cross) > 1e-20
                require(valid_triangles > 0, f"{label}: all triangles are degenerate")
                if valid_triangles < len(indices)//3:
                    self.warnings.append(f"{label}: {len(indices)//3-valid_triangles} degenerate triangles")
                if "material" in primitive:
                    material = index(primitive["material"], self.arrays["materials"], f"{label}.material")
                    for uv in self.material_uvs[material]:
                        semantic = f"TEXCOORD_{uv}"
                        acc = self.at("accessors", attributes.get(semantic), f"{label}.{semantic}")
                        require(acc.get("type") == "VEC2", f"{label}.{semantic}: must be VEC2")
                        require(acc.get("componentType") == 5126 or (
                            acc.get("componentType") in (5121, 5123) and acc.get("normalized") is True),
                            f"{label}.{semantic}: invalid UV component type")
                points.extend(positions)
                triangles += len(indices)//3
                primitives += 1
            mesh_points.append(points)
        require(triangles > 0, "No renderable triangles found")
        return mesh_points, triangles, primitives

    def inspect_animation_references(self) -> None:
        """Check data references, not whether the character moves correctly."""
        for si, skin in enumerate(self.arrays["skins"]):
            label = f"skins[{si}]"
            joints = skin.get("joints")
            require(isinstance(joints, list) and joints, f"{label}: joints required")
            for ji in joints:
                self.at("nodes", ji, f"{label}.joints")
            require(len(set(joints)) == len(joints), f"{label}: duplicate joint")
            if "skeleton" in skin:
                self.at("nodes", skin["skeleton"], f"{label}.skeleton")
            if "inverseBindMatrices" in skin:
                accessor = self.at("accessors", skin["inverseBindMatrices"], f"{label}.inverseBindMatrices")
                require(accessor.get("type") == "MAT4" and accessor.get("componentType") == 5126
                        and accessor.get("count", 0) >= len(joints),
                        f"{label}: inverse bind data must provide FLOAT MAT4 per joint")
        for ai, animation in enumerate(self.arrays["animations"]):
            label = f"animations[{ai}]"
            samplers, channels = animation.get("samplers"), animation.get("channels")
            require(isinstance(samplers, list) and samplers and all(isinstance(v, dict) for v in samplers),
                    f"{label}: samplers required")
            require(isinstance(channels, list) and channels and all(isinstance(v, dict) for v in channels),
                    f"{label}: channels required")
            for si, sampler in enumerate(samplers):
                input_acc = self.at("accessors", sampler.get("input"), f"{label}.samplers[{si}].input")
                self.at("accessors", sampler.get("output"), f"{label}.samplers[{si}].output")
                require(input_acc.get("type") == "SCALAR" and input_acc.get("componentType") == 5126,
                        f"{label}.samplers[{si}]: input must be FLOAT SCALAR")
                times = self.decode(sampler["input"])
                require(times[0][0] >= 0 and all(a[0] < b[0] for a, b in zip(times, times[1:])),
                        f"{label}.samplers[{si}]: input times must strictly increase from >=0")
                require(sampler.get("interpolation", "LINEAR") in ("LINEAR", "STEP", "CUBICSPLINE"),
                        f"{label}.samplers[{si}]: unsupported interpolation")
            for ci, channel in enumerate(channels):
                index(channel.get("sampler"), samplers, f"{label}.channels[{ci}].sampler")
                target = channel.get("target")
                require(isinstance(target, dict), f"{label}.channels[{ci}]: target required")
                if "node" in target:
                    self.at("nodes", target["node"], f"{label}.channels[{ci}].target.node")
                require(target.get("path") in ("translation", "rotation", "scale", "weights"),
                        f"{label}.channels[{ci}]: unsupported target path")

    def inspect_scene(self, mesh_points: list[list[tuple]]) -> dict:
        nodes, scenes = self.arrays["nodes"], self.arrays["scenes"]
        require(nodes and scenes, "A scene with mesh instances is required")
        parents, matrices = {}, []
        for ni, node in enumerate(nodes):
            matrices.append(node_matrix(node, f"nodes[{ni}]"))
            for field, array in (("mesh", "meshes"), ("skin", "skins"), ("camera", "cameras")):
                if field in node:
                    self.at(array, node[field], f"nodes[{ni}].{field}")
            children = node.get("children", [])
            require(isinstance(children, list), f"nodes[{ni}].children must be array")
            for child in children:
                ci = index(child, nodes, f"nodes[{ni}].children")
                require(ci not in parents, f"nodes[{ci}]: multiple parent references")
                parents[ci] = ni
        visited, active = set(), set()
        def detect_cycle(ni: int) -> None:
            require(ni not in active, f"nodes[{ni}]: cycle in scene hierarchy")
            if ni in visited:
                return
            active.add(ni)
            for child in nodes[ni].get("children", []):
                detect_cycle(child)
            active.remove(ni)
            visited.add(ni)
        for ni in range(len(nodes)):
            detect_cycle(ni)
        for si, scene in enumerate(scenes):
            roots = scene.get("nodes", [])
            require(isinstance(roots, list), f"scenes[{si}].nodes must be array")
            require(len(set(roots)) == len(roots), f"scenes[{si}]: duplicate root node")
            for ni in roots:
                index(ni, nodes, f"scenes[{si}].nodes")
                require(ni not in parents, f"scenes[{si}]: root node has a parent")
        selected = index(self.doc.get("scene", 0), scenes, "scene")
        minimum, maximum, instances = [math.inf]*3, [-math.inf]*3, 0
        primitive_instances, instanced_triangles = 0, 0
        def walk(ni: int, parent: tuple) -> None:
            nonlocal instances, primitive_instances, instanced_triangles
            node = nodes[ni]
            transform = multiply(parent, matrices[ni])
            if "mesh" in node:
                instances += 1
                for primitive in self.arrays["meshes"][node["mesh"]]["primitives"]:
                    primitive_instances += 1
                    accessor_index = primitive.get("indices", primitive["attributes"]["POSITION"])
                    instanced_triangles += self.arrays["accessors"][accessor_index]["count"]//3
                for point in mesh_points[node["mesh"]]:
                    for row in range(3):
                        value = sum(transform[col*4+row]*point[col] for col in range(3)) + transform[12+row]
                        require(math.isfinite(value), f"nodes[{ni}]: non-finite transformed vertex")
                        minimum[row] = min(minimum[row], value)
                        maximum[row] = max(maximum[row], value)
            for child in node.get("children", []):
                walk(child, transform)
        for ni in scenes[selected].get("nodes", []):
            walk(ni, IDENTITY)
        require(instances > 0, "Default scene contains no mesh instances")
        dimensions = [maximum[i]-minimum[i] for i in range(3)]
        require(all(.0001 < value <= 100 for value in dimensions) and max(dimensions) >= .05,
                f"Implausible asset dimensions in meters: {dimensions}; check export scale")
        if abs(minimum[1]) > .03:
            self.warnings.append(f"Ground pivot review: minimum glTF Y is {minimum[1]:.6f} m, expected near 0")
        return {"default_scene": selected, "mesh_instances": instances,
                "triangles_with_scene_instances": instanced_triangles,
                "primitive_instances_before_renderer_batching": primitive_instances,
                "submission_note": "Primitive instances are a planning count, not measured draw calls; batching and render passes change submissions",
                "bounds_m": {"min": minimum, "max": maximum}, "dimensions_m_xyz": dimensions,
                "coordinate_system": "glTF right-handed, Y up; project front +Z"}

    def run(self) -> dict:
        required = self.doc.get("extensionsRequired", [])
        require(isinstance(required, list) and all(isinstance(v, str) for v in required),
                "extensionsRequired must be an array of strings")
        require(not set(required)-SUPPORTED_REQUIRED_EXTENSIONS,
                f"Unsupported required extensions: {sorted(set(required)-SUPPORTED_REQUIRED_EXTENSIONS)}")
        self.inspect_buffers()
        for i in range(len(self.arrays["accessors"])):
            self.decode(i)
        images = self.inspect_images_materials()
        points, triangles, primitives = self.inspect_meshes()
        scene = self.inspect_scene(points)
        self.inspect_animation_references()
        if self.arrays["skins"] or self.arrays["animations"]:
            self.warnings.append("Skin/animation runtime behavior is outside this static export gate")
        unique_images = {image["sha256"]: image for image in images}.values()
        rgba_bytes = sum(image["width"]*image["height"]*4 for image in unique_images)
        return {"triangles_unique_meshes": triangles, "primitives": primitives,
                "meshes": len(points), "materials": len(self.arrays["materials"]),
                "material_details": self.material_details,
                "textured_materials": sum(bool(uvs) for uvs in self.material_uvs.values()),
                "accessors": len(self.decoded), "images": images,
                "unique_embedded_image_count": len({image["sha256"] for image in images}),
                "rgba8_top_level_texture_bytes_estimate": rgba_bytes,
                "texture_memory_note": "Unique source images at 4 bytes/pixel, without mipmaps; not measured Android VRAM or compressed GPU allocation",
                "skins": len(self.arrays["skins"]), "animations": len(self.arrays["animations"]),
                **scene}


def validate_asset(path: Path, root: Path) -> dict:
    result = {"path": path.relative_to(root).as_posix(), "status": "failed", "errors": [], "warnings": []}
    try:
        data = path.read_bytes()
        result.update({"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()})
        document, binary, warnings = read_glb(data)
        result["warnings"] = warnings
        result.update(Inspection(document, binary, warnings).run())
        result["status"] = "passed"
    except (ValueError, OSError, struct.error, OverflowError, RecursionError,
            TypeError, KeyError, IndexError, AttributeError) as exc:
        result["errors"].append(f"{type(exc).__name__}: {exc}")
    return result


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2],
                        help="Repository root containing art/visual_benchmark/assets")
    parser.add_argument("--output", type=Path, help="Write a JSON report (otherwise stdout)")
    args = parser.parse_args(argv)
    root = args.root.resolve()
    paths = sorted((root / "art/visual_benchmark/assets").rglob("*.glb"))
    results = [validate_asset(path, root) for path in paths]
    failures = sum(result["status"] == "failed" for result in results)
    report = {
        "schema_version": 1,
        "generated_at_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "validator": "imperathen-visual-assets-stdlib-v1",
        "scope": "Static GLB export gate: container, embedded data, accessor bytes, meshes, materials and default-scene bounds",
        "not_verified": ["complete glTF schema/extension conformance", "pixel decoding or visual quality",
                         "rig/animation quality", "engine integration", "FPS or GPU memory", "legal rights"],
        "specification": "https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html",
        "status": "passed" if results and failures == 0 else "failed",
        "assets_checked": len(results), "assets_failed": failures,
        "errors": [] if results else ["No .glb files found under art/visual_benchmark/assets"],
        "assets": results,
    }
    rendered = json.dumps(report, ensure_ascii=False, indent=2, allow_nan=False) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered, encoding="utf-8")
        print(f"{report['status']}: {len(results)} assets, {failures} failed; report: {args.output}")
    else:
        sys.stdout.write(rendered)
    return 0 if report["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
