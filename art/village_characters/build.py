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
                "train":.86,"work":1.6,"block":1.2,"attack":.8,"hit":.48,"death":1.2}


def add_costumes():
    cloth = art.material("Overgarment", (.42,.34,.23,1), roughness=.86, texture="linen")
    thread = art.material("WovenBorder", (.34,.18,.078,1), roughness=.8)
    metal = art.material("CopperBrooch", (.53,.31,.12,1),roughness=.38,metallic=.6)
    hair = art.material("HairBraid", (.073,.041,.022,1),roughness=.77)
    for side in (-1,1):
        art._tube("Garment_italia_WovenBand",[(side*.105,-.063,1.216),(side*.099,-.102,1.13),
                  (side*.087,-.111,1.036),(side*.084,-.094,.94)],[.006]*4,thread,sides=8,depth_ratio=.32)
    for home in ("germania","vistula"):
        name="Garment_"+home
        art._loft(name+"_Mantle",[(0,.007,1.052,.151,.100),(0,.006,1.095,.172,.114),
                  (0,.006,1.154,.194,.115),(0,.008,1.207,.160,.089),(0,.007,1.228,.078,.061)],cloth,40,.008,cap=False)
        art._ellipsoid(name+"_Brooch",(.112,-.087,1.151),(.017,.008,.018),metal)
        art._tube(name+"_Trim",[(-.145,-.079,1.106),(-.066,-.111,1.067),
                  (.005,-.115,1.064),(.082,-.104,1.090),(.12,-.082,1.14)],[.004]*5,thread,sides=8)
    for home in ("han","wa"):
        name="Garment_"+home
        art._loft(name+"_Wrap",[(0,.001,.729,.174,.117),(0,0,.792,.161,.106),
                  (0,0,.936,.145,.103),(0,0,1.076,.152,.107),(0,0,1.18,.171,.103),
                  (0,.007,1.223,.135,.084),(0,.005,1.25,.071,.059)],cloth,44,.006,cap=False)
        for side in (-1,1):
            art._tube(name+"_Lapel_"+str(side),[(.045*side,-.048,1.246),(.019*side,-.096,1.177),
                      (-.040*side,-.106,1.108),(-.088*side,-.098,1.026)],[.009]*4,thread,sides=10,depth_ratio=.49)
        art._loft(name+"_Sash",[(0,0,.909,.148,.103),(0,0,.944,.148,.104)],thread,40,cap=False)
    for style in ("braid","knot","tie"):
        name="Hair_"+style
        if style=="knot":
            art._ellipsoid(name+"_Bun",(0,.032,1.519),(.052,.041,.043),hair)
        else:
            length=.23 if style=="braid" else .14
            for side in (-1,1) if style=="braid" else (0,):
                for k in range(6):
                    z=1.426-length*k/6
                    x=side*(.072+.012*k/6)+(.008 if k%2 else -.008)
                    art._ellipsoid(name+"_Lock",(x,.065-k*.004,z),(.020,.023,.029),hair,8,12)
    wood=art.material("TrainingWood",(.31,.16,.071,1),roughness=.78)
    art._tube("PracticeBlade_Grip",[(-.259,-.046,.734),(-.259,-.046,.849)],[.012,.013],wood,10)
    art._tube("PracticeBlade_Guard",[(-.315,-.046,.839),(-.203,-.046,.839)],[.012,.012],wood,8)
    art._tube("PracticeBlade_Blade",[(-.259,-.046,.848),(-.259,-.046,1.184),(-.259,-.046,1.239)],[.021,.017,.002],wood,sides=6,depth_ratio=.48)


def mesh_set(name):
    if name.startswith(("Garment_","Hair_")): return "_".join(name.split("_")[:2])
    if name.startswith("PracticeBlade"): return "PracticeBlade"
    return "Civilian"


def face_uv(obj, mat):
    name=obj.name
    if not any(marker in name for marker in ("_Head","_Nose","_Nostril","_Lip","_Mouth","_Iris","_Pupil","_Lid","_Eye","_Brow","_UpperLip","_LowerLip")): return
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    uv=obj.data.uv_layers.active or obj.data.uv_layers.new(name="FaceUV")
    for loop in obj.data.loops:
        x,y,z=obj.matrix_world @ obj.data.vertices[loop.vertex_index].co
        # Collapse the back to the map's neutral border.
        u=(x+.105)/.21 if y < .005 else (.004 if x<0 else .996)
        uv.data[loop.index].uv=(max(.004,min(.996,u)),max(.004,min(.996,(z-1.297)/.22)))


def build_source():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    art.build_civilian()
    add_costumes()
    facemat=art.material("PortraitSkin",(1,1,1,1),roughness=.72)
    objects=[o for o in bpy.context.scene.objects if o.type=="MESH"]
    arm=tailored_rig()
    bundles={}
    for obj in objects:
        face_uv(obj,facemat)
        key=mesh_set(obj.name)
        bundles.setdefault(key,[]).append(obj)
        for vert in obj.data.vertices:
            if key.startswith("Hair_"): influences=[("Head",1)]
            elif key=="PracticeBlade": influences=[("Hand_R",1)]
            elif key.startswith("Garment_"): influences=weights("Civilian_Tunic",obj.matrix_world @ vert.co)
            else: influences=weights(obj.name,obj.matrix_world @ vert.co)
            for joint, value in influences:
                if value > 0:
                    group=obj.vertex_groups.get(joint) or obj.vertex_groups.new(name=joint)
                    group.add([vert.index], value, "REPLACE")
    for name,parts in bundles.items():
        bpy.ops.object.select_all(action="DESELECT")
        for obj in parts: obj.select_set(True)
        bpy.context.view_layer.objects.active=parts[0]
        bpy.ops.object.join()
        mesh=bpy.context.object
        mesh.name=name
        mesh.parent=arm
        deform=mesh.modifiers.new("Village skin","ARMATURE")
        deform.object=arm
    for mesh in bpy.context.scene.objects:
        if mesh.type=="MESH": age_and_identity(mesh)
    company.animate(arm,"civilian")
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(HERE/"villager.blend"),compress=True)


def age_and_identity(mesh):
    # Delta shapes alter proportions independently from the actor's final height.
    mesh.shape_key_add(name="Basis")
    adult=mesh.shape_key_add(name="Mature")
    companion=mesh.shape_key_add(name="Companion")
    matrix=mesh.matrix_world
    inv=matrix.inverted()
    for i,vertex in enumerate(mesh.data.vertices):
        x,y,z=matrix @ vertex.co
        if z >= 1.275:
            jaw=max(0,min(1,(1.425-z)/.12))
            adult_point=(x*(1.02+.18*jaw),y*(1+.13*jaw),1.275+(z-1.275)*.94)
            companion_point=(x*(.95+.06*jaw),y*.97,1.275+(z-1.275)*1.025)
        else:
            shoulders=max(0,1-abs(z-1.15)/.30)
            adult_point=(x*(1+.16*shoulders),y*(1+.16*shoulders),z)
            companion_point=(x*(1-.045*shoulders),y,z)
        adult.data[i].co=inv @ Vector(adult_point)
        companion.data[i].co=inv @ Vector(companion_point)


def export():
    for lod, ratio in enumerate([1,.48,.19,.045]):
        bpy.ops.wm.open_mainfile(filepath=str(HERE/"villager.blend"))
        for mesh in list(bpy.context.scene.objects):
            if ratio == 1 or mesh.type != "MESH": continue
            mesh.shape_key_clear()
            bpy.context.view_layer.objects.active=mesh
            dec=mesh.modifiers.new("Distance budget","DECIMATE")
            dec.ratio=ratio
            bpy.ops.object.modifier_move_to_index(modifier=dec.name,index=0)
            bpy.ops.object.modifier_apply(modifier=dec.name)
        for mesh in bpy.context.scene.objects:
            if mesh.type=="MESH" and mesh.data.shape_keys is None: age_and_identity(mesh)
        bpy.ops.export_scene.gltf(filepath=str(OUT/f"villager_{lod}.glb"),export_format="GLB",
                                  export_animation_mode="NLA_TRACKS", export_force_sampling=True,
                                  export_frame_step=1,export_animations=True,export_morph_animation=False,export_all_vertex_colors=True)


if __name__=="__main__":
    build_source()
    export()
