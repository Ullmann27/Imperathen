"""Keep the editable Blender review and complete, lossless relative textures.

Run inside Blender: blender -b -t 2 -P tools/city_detail/characters_package.py
The image files retain their original encoded bytes; no resizing or rebaking.
"""
from __future__ import annotations
import hashlib
import json
import re
import sys
from pathlib import Path

import bpy

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "tools/city_detail/characters_review"


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def externalize_images(output: Path) -> list[dict]:
    directory = output / "textures"
    directory.mkdir(parents=True, exist_ok=True)
    prepared = []
    by_hash = {}
    for image in bpy.data.images:
        if image.source != "FILE":
            continue
        if image.packed_file is not None:
            data = bytes(image.packed_file.data)
        else:
            data = Path(bpy.path.abspath(image.filepath)).read_bytes()
        if data.startswith(b"\x89PNG\r\n\x1a\n"):
            extension = ".png"
        elif data.startswith(b"\xff\xd8"):
            extension = ".jpg"
        else:
            raise ValueError("Unsupported encoded image; refusing conversion: " + image.name)
        checksum = hashlib.sha256(data).hexdigest()
        if checksum not in by_hash:
            stem = re.sub(r"[^A-Za-z0-9_-]+", "_", Path(image.name).stem).strip("_")
            name = stem + "_" + checksum[:12] + extension
            by_hash[checksum] = name
            target = directory / name
            target.write_bytes(data)
            if digest(target) != checksum:
                raise RuntimeError("Encoded image changed while externalizing: " + image.name)
        name = by_hash[checksum]
        prepared.append((image, name, checksum, len(data), list(image.size), image.colorspace_settings.name))
    result = []
    for image, name, checksum, size, dimensions, color_space in prepared:
        if image.packed_file is not None:
            image.unpack(method="REMOVE")
        image.filepath = "//textures/" + name
        result.append({"image": image.name, "relative_path": "textures/" + name,
                       "bytes": size, "sha256": checksum, "dimensions": dimensions,
                       "color_space": color_space})
    return result


def _value(value):
    if value is None or isinstance(value, (bool, int, float, str)):
        return value
    if isinstance(value, bpy.types.ID):
        return value.name
    try:
        return list(value)
    except TypeError:
        return type(value).__name__


def material_signature() -> dict:
    result = {}
    for material in bpy.data.materials:
        nodes = []
        links = []
        if material.use_nodes:
            for node in material.node_tree.nodes:
                entry = {"name": node.name, "type": node.bl_idname,
                         "inputs": [(socket.name, _value(socket.default_value))
                                    for socket in node.inputs if hasattr(socket, "default_value")]}
                for property_name in ["operation", "blend_type", "distribution", "projection",
                                      "extension", "interpolation", "space", "uv_map", "attribute_name"]:
                    if hasattr(node, property_name):
                        entry[property_name] = _value(getattr(node, property_name))
                if hasattr(node, "image") and node.image is not None:
                    entry["image"] = node.image.name
                    entry["color_space"] = node.image.colorspace_settings.name
                nodes.append(entry)
            links = sorted((link.from_node.name, link.from_socket.name,
                            link.to_node.name, link.to_socket.name) for link in material.node_tree.links)
        result[material.name] = {"color": list(material.diffuse_color),
                                 "roughness": material.roughness, "metallic": material.metallic,
                                 "backface_culling": material.use_backface_culling,
                                 "nodes": sorted(nodes, key=lambda node: node["name"]), "links": links}
    result["mesh_assignments"] = {
        obj.name: [slot.material.name if slot.material else None for slot in obj.material_slots]
        for obj in bpy.data.objects if obj.type == "MESH"}
    return result


def validate_external_images(output: Path, textures: list[dict]) -> None:
    for item in textures:
        image = bpy.data.images.get(item["image"])
        if image is None or image.packed_file is not None:
            raise RuntimeError("Image missing or unexpectedly packed after reopen: " + item["image"])
        if image.filepath != "//" + item["relative_path"]:
            raise RuntimeError("Non-relative texture reference: " + image.filepath)
        image.reload()
        if list(image.size) != item["dimensions"] or image.colorspace_settings.name != item["color_space"]:
            raise RuntimeError("Image size or color space changed: " + item["image"])
        if digest(output / item["relative_path"]) != item["sha256"]:
            raise RuntimeError("Encoded texture bytes changed: " + item["image"])


def main() -> None:
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import characters_blender as character
    path = OUT / "hero_city_detail.blend"
    report_path = OUT / "character_detail_review.json"
    report = json.loads(report_path.read_text())
    before_file_hash = digest(path)
    bpy.ops.wm.open_mainfile(filepath=str(path))
    imported_names = list(report["objects"])
    geometry = character.geometry_record([bpy.data.objects[name] for name in imported_names])
    animations = character.action_record()
    materials = material_signature()
    textures = externalize_images(OUT)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(path), compress=True)
    bpy.ops.wm.open_mainfile(filepath=str(path))
    validate_external_images(OUT, textures)
    if geometry != character.geometry_record([bpy.data.objects[name] for name in imported_names]):
        raise RuntimeError("Geometry, rig, UV, weights or morphs changed during packaging.")
    if animations != character.action_record():
        raise RuntimeError("Animation curves changed during packaging.")
    if materials != material_signature():
        raise RuntimeError("Material graph or assignments changed during packaging.")
    if digest(character.SOURCE) != report["source_sha256"]:
        raise RuntimeError("Original source GLB changed.")
    report["blend_sha256"] = digest(path)
    report["blend_packaging"] = "Editable Blender file with complete original encoded images under relative //textures/ paths"
    report["textures"] = textures
    report["packaging_validation"] = {
        "opened_in_blender": bpy.app.version_string,
        "original_blend_sha256": before_file_hash,
        "geometry_weights_uv_morphs_rig_unchanged": True,
        "animation_curves_unchanged": True,
        "material_graphs_and_assignments_unchanged": True,
        "original_encoded_image_bytes_preserved": True,
        "original_source_glb_unchanged": True,
    }
    report_path.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"blend_bytes": path.stat().st_size, "blend_sha256": report["blend_sha256"],
                      "image_count": len(textures), "largest_image_bytes": max(item["bytes"] for item in textures),
                      "reopen_and_identity_checks_passed": True}, indent=2))


if __name__ == "__main__":
    main()
