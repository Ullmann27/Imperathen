"""Derive the two distant animated village NPC tiers from the authored company rigs."""
from pathlib import Path
import bpy

ROOT = Path(__file__).resolve().parents[2]
for role in ("officer", "spear", "heavy"):
    for level, ratio in ((2, .22), (3, .058)):
        bpy.ops.wm.open_mainfile(filepath=str(ROOT / f"art/soldiers/{role}.blend"))
        for body in [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]:
            bpy.context.view_layer.objects.active = body
            budget = body.modifiers.new("Village distance budget", "DECIMATE")
            budget.ratio = ratio
            bpy.ops.object.modifier_move_to_index(modifier=budget.name, index=0)
            bpy.ops.object.modifier_apply(modifier=budget.name)
        bpy.ops.export_scene.gltf(filepath=str(ROOT / f"prototype/assets/village_characters/{role}_{level}.glb"),
                                  export_format="GLB", export_animation_mode="NLA_TRACKS",
                                  export_force_sampling=True, export_frame_step=1)
