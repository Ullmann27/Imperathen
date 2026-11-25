"""Blender material helper. No files or existing materials overwritten."""
from pathlib import Path
import json
import bpy

def build_material(root, material_id, assign_selected=False):
    directory = Path(root) / "prototype/assets/roman_material_lab"
    manifest = json.loads((directory / "manifest.json").read_text(encoding="utf-8"))
    spec = next((m for m in manifest["materials"] if m["id"] == material_id), None)
    if spec is None:
        raise ValueError(f"Unknown material: {material_id}")
    images = {}
    for kind, name in spec["files"].items():
        image = bpy.data.images.load(str(directory / name), check_existing=True)
        image.colorspace_settings.name = "sRGB" if kind == "basecolor" else "Non-Color"
        images[kind] = image
    mat = bpy.data.materials.new("IMPERATHEN_LAB_" + material_id)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = next(node for node in nodes if node.type == "BSDF_PRINCIPLED")
    uv = nodes.new("ShaderNodeTexCoord")
    textures = {}
    for kind, image in images.items():
        node = nodes.new("ShaderNodeTexImage")
        node.image = image
        node.extension = "REPEAT"
        links.new(uv.outputs["UV"], node.inputs["Vector"])
        textures[kind] = node
    links.new(textures["basecolor"].outputs["Color"], bsdf.inputs["Base Color"])
    normal = nodes.new("ShaderNodeNormalMap")
    links.new(textures["normal"].outputs["Color"], normal.inputs["Color"])
    links.new(normal.outputs["Normal"], bsdf.inputs["Normal"])
    separate = nodes.new("ShaderNodeSeparateColor")
    links.new(textures["orm"].outputs["Color"], separate.inputs["Color"])
    links.new(separate.outputs["Green"], bsdf.inputs["Roughness"])
    links.new(separate.outputs["Blue"], bsdf.inputs["Metallic"])
    if assign_selected:
        for obj in bpy.context.selected_objects:
            if obj.type == "MESH":
                obj.data.materials.append(mat)
    return mat
