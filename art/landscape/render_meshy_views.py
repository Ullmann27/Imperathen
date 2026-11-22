"""Render seven native IMPERATHEN game characters as true-scale, four-view RGBA references."""
import hashlib
import json
import math
from pathlib import Path
import shutil
import sys
from tempfile import TemporaryDirectory
from zipfile import ZIP_STORED, ZipFile, ZipInfo

import bpy
from mathutils import Matrix, Vector
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from render_cutouts import ROOT, configure_cycles, point, studio_lights

OUTPUT = HERE / "meshy"
ARCHIVE = "IMPERATHEN-Meshy-Figurenreferenzen.zip"
PIXELS = 1024
SPAN = 2.52
TARGET = Vector((0, 0, 1.15))
VIEWS = (("01_front", 0), ("02_dreiviertel", 45), ("03_seite", 90), ("04_rueckseite", 180))
ROLES = {
    "heavy": "Schweres Fußvolk", "spear": "Speerträger", "archer": "Bogenschütze", "officer": "Offizier",
    "farmer": "Feldarbeiter", "han_farmer": "Han-Feldarbeiter", "wa_farmer": "Wa-Feldarbeiter",
}
SOLDIERS = ("heavy", "spear", "archer", "officer")
WORKERS = ("farmer", "han_farmer", "wa_farmer")


def strip_render_metadata(path):
    # Preserve every RGBA pixel. Blender's PNG text and EXIF chunks also store
    # wall-clock timestamps and render duration, which vary between runs.
    with Image.open(path) as image:
        pixels = Image.frombytes("RGBA", image.size, image.tobytes())
    pixels.save(path, compress_level=6)


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def prepare(role):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    source = ROOT / "prototype/assets"
    if role in SOLDIERS:
        source = source / f"soldiers/{role}_near.glb"
    else:
        source = source / f"landscape/{role}.glb"
    bpy.ops.import_scene.gltf(filepath=str(source))
    armature = next(obj for obj in scene.objects if obj.type == "ARMATURE")
    armature.animation_data_clear()
    armature.data.pose_position = "REST"
    graph = bpy.context.evaluated_depsgraph_get()
    meshes = [obj.evaluated_get(graph) for obj in scene.objects if obj.type == "MESH" and obj.parent == armature]
    if not meshes:
        raise ValueError(f"No rigged game geometry in {source}")
    vertices = [obj.matrix_world @ vertex.co for obj in meshes for vertex in obj.data.vertices]
    configure_cycles(scene, pixels=PIXELS, samples=24)
    scene.cycles.seed = 27
    lights = studio_lights(scene, TARGET)
    light_offsets = [light.location - TARGET for light in lights]
    bpy.ops.object.camera_add()
    camera = bpy.context.object
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = SPAN
    scene.camera = camera
    return source, scene, vertices, camera, list(zip(lights, light_offsets))


def check_bounds(path, vertices, camera):
    inverse = camera.rotation_euler.to_matrix().inverted()
    coordinates = [inverse @ (vertex - TARGET) for vertex in vertices]
    scale = PIXELS / SPAN
    projected = [
        PIXELS / 2 + min(p.x for p in coordinates) * scale,
        PIXELS / 2 - max(p.y for p in coordinates) * scale,
        PIXELS / 2 + max(p.x for p in coordinates) * scale,
        PIXELS / 2 - min(p.y for p in coordinates) * scale,
    ]
    with Image.open(path) as image:
        if image.mode != "RGBA" or image.size != (PIXELS, PIXELS):
            raise ValueError(f"Unexpected raster format in {path}")
        alpha = image.getchannel("A")
        bounds = alpha.getbbox()
        if alpha.getextrema() != (0, 255) or not bounds:
            raise ValueError(f"Missing alpha or foreground in {path}")
        if min(bounds[0], bounds[1], PIXELS-bounds[2], PIXELS-bounds[3]) < 16:
            raise ValueError(f"Insufficient transparent margin in {path}: {bounds}")
        # Thin props must reach the silhouette even when only a few pixels across.
        if max(abs(a-b) for a,b in zip(projected, bounds)) > 3:
            raise ValueError(f"Rendered outline differs from geometry in {path}: {bounds} / {projected}")
    return {"alpha_bbox_px": list(bounds), "projected_bbox_px": [round(v, 2) for v in projected],
            "alpha_min_max": [0,255], "sha256": sha256(path)}


def render_role(role, folder):
    source, scene, vertices, camera, lights = prepare(role)
    destination = folder / role
    destination.mkdir()
    record = {"source_glb": source.relative_to(ROOT).as_posix(), "source_sha256": sha256(source),
              "source_blend": f"art/{'soldiers' if role in SOLDIERS else 'landscape'}/{role}.blend", "views": {}}
    for view, degrees in VIEWS:
        rotation = Matrix.Rotation(math.radians(degrees), 3, "Z")
        camera.location = TARGET + rotation @ Vector((0, -6, 0))
        point(camera, TARGET)
        for light, offset in lights:
            light.location = TARGET + rotation @ offset
            point(light, TARGET)
        path = destination / f"{view}.png"
        scene.render.filepath = str(path)
        bpy.ops.render.render(write_still=True)
        strip_render_metadata(path)
        record["views"][view] = check_bounds(path, vertices, camera)
    return record


def sheet(roles, title, destination, folder):
    # The source PNGs remain untouched. Only these overview images have captions.
    width, header, cell = 1084, 90, 216
    page = Image.new("RGB", (width, header + cell*len(roles) + 16), "#e8e6dc")
    draw = ImageDraw.Draw(page)
    # DejaVu Sans includes the German role names and accented view labels.
    heading = ImageFont.truetype("DejaVuSans.ttf", size=28)
    label = ImageFont.truetype("DejaVuSans.ttf", size=17)
    draw.text((20,14), title, font=heading, fill="#273530")
    for i, name in enumerate(("Front", "Dreiviertel", "Seite", "Rückseite")):
        draw.text((177 + cell*i + cell/2, 63), name, font=label, fill="#354743", anchor="mm")
    for row, role in enumerate(roles):
        y = header + row*cell
        draw.line([(16,y), (width-16,y)], fill="#c4c0b3")
        draw.text((20, y+cell/2), ROLES[role], font=label, fill="#273530", anchor="lm")
        for col,(name,_) in enumerate(VIEWS):
            with Image.open(folder / role / f"{name}.png") as image:
                thumb = image.resize((cell, cell), Image.Resampling.LANCZOS)
                page.paste(thumb, (177+col*cell, y), thumb)
    page.save(destination)


def main():
    guide = OUTPUT / "README.md"
    with TemporaryDirectory() as temporary:
        folder = Path(temporary)
        records = {role: render_role(role, folder) for role in ROLES}
        manifest = {"generator": "art/landscape/render_meshy_views.py", "blender": bpy.app.version_string,
                    "renderer": "Cycles", "pose": "native skin bind pose", "size_px": [PIXELS, PIXELS],
                    "metres_per_pixel": SPAN/PIXELS, "camera_target_m_blender": list(TARGET),
                    "orthographic_height_m": SPAN, "camera_elevation_deg": 0,
                    "orbit_deg_from_front": dict(VIEWS), "roles": records}
        (folder / "manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False)+"\n")
        shutil.copyfile(guide, folder / "README.md")
        images = sorted(folder.glob("*/*.png"))
        if len(images) != 28:
            raise ValueError(f"Expected 28 source images, found {len(images)}")
        # Fixed zip timestamps allow checksums to be compared across local runs.
        with ZipFile(folder / ARCHIVE, "w", compression=ZIP_STORED) as archive:
            for path in [*images, folder / "manifest.json", folder / "README.md"]:
                info = ZipInfo(path.relative_to(folder).as_posix(), date_time=(2026,1,1,0,0,0))
                archive.writestr(info, path.read_bytes())
        with ZipFile(folder / ARCHIVE) as archive:
            if archive.testzip() is not None:
                raise IOError("ZIP verification failed")
        sheet(SOLDIERS, "IMPERATHEN · Soldaten", folder / "soldaten.png", folder)
        sheet(WORKERS, "IMPERATHEN · Feldarbeiter", folder / "feldarbeiter.png", folder)
        for name in (ARCHIVE, "soldaten.png", "feldarbeiter.png"):
            shutil.copyfile(folder / name, OUTPUT / name)
        print(f"Verified 28 full-body RGBA views: {OUTPUT/ARCHIVE} ({sha256(OUTPUT/ARCHIVE)})")


if __name__ == "__main__":
    main()
