"""Render side-view march-cycle silhouettes of the project's own field company rigs.

Run from the repository root:
    blender -b -P tools/ui/render_legion_silhouettes.py

Sources are the original Blender rigs in art/soldiers (heavy, spear, officer; own
work of this project, see art/soldiers/README.md). The output is one RGBA atlas
(white, alpha = coverage): one row per role, FRAMES columns across one march
cycle. The title sequence and the main menu tint it and add a rim light in a
shader, so no lighting is baked in.
"""
from pathlib import Path
import math
import sys
import bpy

ROOT = Path(__file__).resolve().parents[2]
ROLES = ("heavy", "spear", "officer")
FRAMES = 12
CELL = (192, 288)
ORTHO = 2.6
VIEW_ANGLE = math.radians(32)
OUT = ROOT / "prototype/assets/ui/legion_march.png"
TMP = Path("/tmp/legion_frames")


def render_role(role: str) -> list[Path]:
    bpy.ops.wm.open_mainfile(filepath=str(ROOT / f"art/soldiers/{role}.blend"))
    scene = bpy.context.scene
    rig = next(obj for obj in scene.objects if obj.type == "ARMATURE")
    action = bpy.data.actions["march"]
    rig.animation_data_create()
    for track in rig.animation_data.nla_tracks:
        track.mute = True
    rig.animation_data.action = action
    if hasattr(rig.animation_data, "action_slot") and action.slots:
        rig.animation_data.action_slot = action.slots[0]
    start, end = action.frame_range
    camera_data = bpy.data.cameras.new("SilhouetteCam")
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = ORTHO
    camera = bpy.data.objects.new("SilhouetteCam", camera_data)
    scene.collection.objects.link(camera)
    # Rigs look along glTF +Z (Blender -Y). A camera on -X, turned a little
    # toward their front, sees them march to screen right in three-quarter view.
    from mathutils import Vector
    camera.location = (-12.0 * math.cos(VIEW_ANGLE), -12.0 * math.sin(VIEW_ANGLE), ORTHO * 0.5 - 0.05)
    look = Vector((0.0, 0.0, ORTHO * 0.5 - 0.05)) - Vector(camera.location)
    camera.rotation_euler = look.to_track_quat("-Z", "Y").to_euler()
    scene.camera = camera
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "FLAT"
    scene.display.shading.color_type = "SINGLE"
    scene.display.shading.single_color = (1.0, 1.0, 1.0)
    scene.display.shading.show_object_outline = False
    scene.render.film_transparent = True
    scene.render.resolution_x, scene.render.resolution_y = CELL
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "Standard"
    scene.render.filter_size = 1.2
    paths = []
    for index in range(FRAMES):
        frame = start + (end - start) * index / FRAMES
        scene.frame_set(int(math.floor(frame)), subframe=frame - math.floor(frame))
        path = TMP / f"{role}_{index:02d}.png"
        scene.render.filepath = str(path)
        bpy.ops.render.render(write_still=True)
        paths.append(path)
    return paths


def main() -> None:
    TMP.mkdir(parents=True, exist_ok=True)
    rows = [render_role(role) for role in ROLES]
    atlas = bpy.data.images.new("legion_march", CELL[0] * FRAMES, CELL[1] * len(ROLES), alpha=True)
    width = CELL[0] * FRAMES
    pixels = [0.0] * (width * CELL[1] * len(ROLES) * 4)
    for row, paths in enumerate(rows):
        # Image rows start at the bottom in Blender; put the first role on top.
        y0 = (len(ROLES) - 1 - row) * CELL[1]
        for column, path in enumerate(paths):
            image = bpy.data.images.load(str(path))
            source = list(image.pixels)
            for y in range(CELL[1]):
                for x in range(CELL[0]):
                    s = (y * CELL[0] + x) * 4
                    d = ((y0 + y) * width + column * CELL[0] + x) * 4
                    alpha = source[s + 3]
                    pixels[d:d + 4] = [1.0, 1.0, 1.0, alpha]
            bpy.data.images.remove(image)
    atlas.pixels = pixels
    atlas.filepath_raw = str(OUT)
    atlas.file_format = "PNG"
    atlas.save()
    print("LEGION_ATLAS", OUT, atlas.size[0], atlas.size[1])


main()
