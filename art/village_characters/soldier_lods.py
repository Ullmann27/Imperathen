"""Derive the two distant animated village NPC tiers from the authored company rigs."""
import importlib.util
from pathlib import Path
import bpy

ROOT = Path(__file__).resolve().parents[2]
_death_spec = importlib.util.spec_from_file_location("company_death_ground", ROOT / "tools/characters/ground_death_clip.py")
death_ground = importlib.util.module_from_spec(_death_spec)
_death_spec.loader.exec_module(death_ground)
for role in ("officer", "spear", "heavy"):
    for level, ratio in ((2, .22), (3, .058)):
        bpy.ops.wm.open_mainfile(filepath=str(ROOT / f"art/soldiers/{role}.blend"))
        for body in [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]:
            bpy.context.view_layer.objects.active = body
            budget = body.modifiers.new("Village distance budget", "DECIMATE")
            budget.ratio = ratio
            bpy.ops.object.modifier_move_to_index(modifier=budget.name, index=0)
            bpy.ops.object.modifier_apply(modifier=budget.name)
        path = ROOT / f"prototype/assets/village_characters/{role}_{level}.glb"
        bpy.ops.export_scene.gltf(filepath=str(path),
                                  export_format="GLB", export_animation_mode="NLA_TRACKS",
                                  export_force_sampling=True, export_frame_step=1)
        death_ground.ground(path)
