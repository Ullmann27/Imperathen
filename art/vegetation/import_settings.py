"""Write Godot import settings for the vegetation assets before (re)import.

Textures are sampled only from shaders, so Godot's automatic 3D detection
never sees them: VRAM compression, mipmaps and normal-map compression are set
here explicitly. GLBs carry hand-made LODs, so automatic LOD generation is off.
Existing uid/dest lines are kept; only [params] are replaced.

    python3 art/vegetation/import_settings.py
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "prototype/assets/vegetation"

TEXTURE = """compress/mode=2
compress/high_quality=false
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map={normal}
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=0
"""

SCENE = """nodes/root_type=""
nodes/root_name=""
nodes/root_script=null
mesh_library/use_node_names_as_mesh_names=true
array_mesh/deduplicate_surfaces=true
nodes/apply_root_scale=true
nodes/root_scale=1.0
nodes/import_as_skeleton_bones=false
nodes/use_name_suffixes=true
nodes/use_node_type_suffixes=true
meshes/ensure_tangents=true
meshes/generate_lods=false
meshes/create_shadow_meshes=false
meshes/light_baking=0
meshes/lightmap_texel_size=0.2
meshes/force_disable_compression=false
skins/use_named_skins=true
animation/import=false
animation/fps=30
animation/trimming=false
animation/remove_immutable_tracks=true
animation/import_rest_as_RESET=false
import_script/path=""
materials/extract=0
materials/extract_format=0
"""


def write(path, importer, kind, params):
    target = Path(str(path) + ".import")
    head = f'[remap]\n\nimporter="{importer}"\ntype="{kind}"\n'
    if target.exists():
        text = target.read_text()
        head = text.split("[params]")[0]
    target.write_text(head.rstrip() + "\n\n[params]\n\n" + params)


def main():
    for png in sorted((ASSETS / "textures").glob("*.png")):
        write(png, "texture", "CompressedTexture2D", TEXTURE.format(normal=1 if png.stem.endswith("_normal") else 0))
    for glb in sorted(ASSETS.glob("*.glb")):
        write(glb, "scene", "PackedScene", SCENE)


if __name__ == "__main__":
    main()
