"""Bind the project's original civilian study to a tailored 15-joint rig."""
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(ROOT / "tools/art"))
import build_characters as art
sys.path.insert(0, str(ROOT / "art/soldiers"))
import build as company

OUT = ROOT / "prototype/assets/village_characters"
OUT.mkdir(parents=True, exist_ok=True)


def tailored_rig():
    arm = company.skeleton("civilian")
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    joints = {"Pelvis":((0,0,.735),(0,0,.922)), "Spine":((0,0,.922),(0,0,1.255)),
              "Head":((0,0,1.255),(0,0,1.52))}
    for side, suffix in ((-1,"R"),(1,"L")):
        hip=(side*.073,0,.756)
        knee=(side*.085,0,.461)
        ankle=(side*.085,0,.094)
        shoulder=(side*.165,.002,1.18)
        elbow=(side*.237,-.007,1.015)
        wrist=(side*.260,-.040,.83)
        for name, pair in (("Thigh",(hip,knee)),("Shin",(knee,ankle)),("Foot",(ankle,(side*.085,-.125,.037))),
                           ("Arm",(shoulder,elbow)),("Forearm",(elbow,wrist)),("Hand",(wrist,(side*.26,-.05,.734)))):
            joints[name+"_"+suffix]=pair
    for bone in arm.data.edit_bones:
        bone.head,bone.tail=joints[bone.name]
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm


def weights(name, pos):
    x, _, z = pos
    side = "_R" if x < 0 else "_L"
    def blend(low, high, a, b):
        factor=max(0,min(1,(z-a)/(b-a)))
        return [(low,1-factor),(high,factor)]
    if "_Foot_" in name: return [("Foot"+side,1)]
    if "_Leg_" in name: return blend("Shin"+side,"Thigh"+side,.427,.49)
    if "_Hand_" in name: return [("Hand"+side,1)]
    if "_Arm_" in name: return blend("Forearm"+side,"Arm"+side,.975,1.05)
    if "_Sleeve_" in name: return [("Arm"+side,.85),("Spine",.15)]
    if any(key in name for key in ("Mantle","Wrap","Strap")): return [("Spine",1)]
    if z > 1.285 and not "Hem" in name: return [("Head",1)]
    if "_Neck" in name: return blend("Spine","Head",1.22,1.29)
    if "_Tunic" in name or "_SideSeam" in name or "_Hem" in name:
        if z < .79: return [("Pelvis",.72),("Thigh"+side,.28)]
        return blend("Pelvis","Spine",.88,1.08)
    return [("Pelvis",1)]


def village_pose(clip, t, role):
    if clip not in ("gather","talk","train","work"):
        return original_pose(clip,t,role)
    bend=math.sin(math.pi*t)**2
    if clip=="gather":
        return {"Thigh_R":(-46*bend,0,0),"Thigh_L":(-46*bend,0,0),
                "Shin_R":(86*bend,0,0),"Shin_L":(86*bend,0,0),
                "Foot_R":(-40*bend,0,0),"Foot_L":(-40*bend,0,0),"Spine":(27*bend,0,0),
                "Arm_R":(-38*bend,0,0),"Forearm_R":(-22*bend,0,0),"Head":(12*bend,0,0)}, -.152*bend
    if clip=="talk":
        return {"Arm_L":(-18*bend,0,-8*bend),"Forearm_L":(-43*bend,0,0),"Head":(5*math.sin(t*math.tau),0,8*bend),
                "Spine":(0,0,-4*bend)},0
    if clip=="work":
        return {"Spine":(16*bend,0,0),"Arm_R":(-40*bend,0,0),"Arm_L":(-31*bend,0,0),
                "Forearm_L":(-20*bend,0,0),"Head":(9*bend,0,0)},0
    return {"Spine":(5*bend,0,-13*bend),"Arm_R":(-60*bend,0,0),"Forearm_R":(-26*bend,0,0),
            "Arm_L":(-20*bend,0,0),"Head":(0,0,9*bend)},0


original_pose=company.pose
company.pose=village_pose
company.LENGTHS={"idle":2,"march":1,"run":.72,"gather":1.15,"talk":1.35,
                "train":.86,"work":1.6,"attack":.8,"hit":.48,"death":1.2}


def build_source():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    objects=art.build_civilian()
    arm=tailored_rig()
    for obj in objects:
        for vert in obj.data.vertices:
            for joint, value in weights(obj.name,obj.matrix_world @ vert.co):
                if value > 0:
                    group=obj.vertex_groups.get(joint) or obj.vertex_groups.new(name=joint)
                    group.add([vert.index], value, "REPLACE")
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects: obj.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.object.join()
    mesh=bpy.context.object
    mesh.name="Civilian"
    mesh.parent=arm
    deform=mesh.modifiers.new("Village skin","ARMATURE")
    deform.object=arm
    company.animate(arm,"civilian")
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(HERE/"villager.blend"),compress=True)


def export():
    for lod, ratio in enumerate([1,.48,.19,.045]):
        bpy.ops.wm.open_mainfile(filepath=str(HERE/"villager.blend"))
        mesh=bpy.data.objects["Civilian"]
        if ratio < 1:
            bpy.context.view_layer.objects.active=mesh
            dec=mesh.modifiers.new("Distance budget","DECIMATE")
            dec.ratio=ratio
            bpy.ops.object.modifier_move_to_index(modifier=dec.name,index=0)
            bpy.ops.object.modifier_apply(modifier=dec.name)
        bpy.ops.export_scene.gltf(filepath=str(OUT/f"villager_{lod}.glb"),export_format="GLB",
                                  export_animation_mode="NLA_TRACKS", export_force_sampling=True,
                                  export_frame_step=1,export_animations=True,export_all_vertex_colors=True)


if __name__=="__main__":
    build_source()
    export()
