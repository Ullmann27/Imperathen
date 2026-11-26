"""Rig and bake the existing textured IMPERATHEN bay horse in Blender 4.3.

Run in Blender:
    blender -b -t 4 --python-exit-code 1 -P rig_imperathen_horse.py -- SOURCE.glb OUT
"""
from argparse import ArgumentParser
from hashlib import sha256
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Matrix, Quaternion, Vector
import numpy as np

parser = ArgumentParser()
parser.add_argument("source", type=Path)
parser.add_argument("output", type=Path)
parser.add_argument("--preview", action="store_true")
args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
folder = args.output.resolve()
folder.mkdir(parents=True, exist_ok=True)
FPS = 60
ROOT = "Root"
TORSO = "Rumpf"
TAU = 2 * math.pi
identity = Quaternion()
rest = {}
parents = {}
leg_specs = {}
frames_by_action = {}

# Source landmarks in metres, before the final facing rotation.
def define(name, head, tail, parent=None, deform=True):
    rest[name] = (Vector(head), Vector(tail), deform)
    parents[name] = parent

def difference(a, b):
    return rest[b][0] - rest[a][0]

define(ROOT, (0, 0, 0), (0, 0, .28), deform=False)
define(TORSO, (0, .065, .975), (0, -.330, 1.055), ROOT)
define("Halsansatz", (0, -.33, 1.055), (.041, -.548, 1.313), TORSO)
define("Hals", (.041, -.548, 1.313), (.104, -.688, 1.505), "Halsansatz")
define("Kopf", (.104, -.688, 1.505), (.152, -.955, 1.208), "Hals")
define("Schweif_01", (0, .765, 1.163), (0, .917, .895), TORSO)
define("Schweif_02", (0, .917, .895), (0, .980, .555), "Schweif_01")
define("Schweif_03", (0, .980, .555), (0, .954, .229), "Schweif_02")
define("SOCKET_SADDLE", (0, .080781, 1.255353), (0, .080781, 1.355353), TORSO, False)
define("SOCKET_RIDER", (0, .080781, 1.305353), (0, .080781, 1.405353), TORSO, False)
define("SOCKET_REIN_L", (.091, -.922, 1.225), (.091, -.922, 1.285), "Kopf", False)
define("SOCKET_REIN_R", (.205, -.927, 1.241), (.205, -.927, 1.301), "Kopf", False)
define("SOCKET_HEAD", (.147359, -.956936, 1.213611), (.147359, -.956936, 1.313611), "Kopf", False)

for side in ("L", "R"):
    sign = 1 if side == "L" else -1
    for end in ("F", "H"):
        key = end + side
        hind = end == "H"
        if hind:
            points = [(.165 * sign, .637, 1.105), (.173 * sign, .475, .782),
                (.118 * sign, .790, .416), (.159 * sign, .786, .111),
                (.167 * sign, .745, .050), (.167 * sign, .679, .021)]
            labels = ["Oberschenkel", "Unterschenkel", "Roehrbein", "Fessel", "Huf"]
        else:
            points = [(.166 * sign, -.306, 1.032), (.145 * sign, -.340, .769),
                (.128 * sign, -.263, .438), (.142 * sign, -.231, .113),
                (.146 * sign, -.260, .049), (.146 * sign, -.335, .021)]
            labels = ["Oberarm", "Unterarm", "Roehrbein", "Fessel", "Huf"]
        names = [f"{key}_{label}" for label in labels]
        for i, name in enumerate(names):
            define(name, points[i], points[i + 1], names[i-1] if i else TORSO)
        contact = f"SOCKET_HOOF_{key}"
        xyz = (points[4][0], points[4][1], 0)
        define(contact, xyz, (xyz[0], xyz[1], .06), names[-1], False)
        leg_specs[key] = {"names": names, "lengths": [(Vector(a)-Vector(b)).length
            for a,b in zip(points,points[1:])], "hind": hind, "contact": contact}

def ease(lo, hi, n):
    t = min(1.0, max(0.0, (n - lo) / (hi - lo)))
    return t*t*(3 - 2*t)

def smoothpos(n, a, b):
    return a + (b-a) * ease(0, 1, n)

def rotate_x(rads):
    return Quaternion((1, 0, 0), rads)

def min_distance(point, a, b):
    a, b = np.asarray(a), np.asarray(b)
    pos = point-a
    unit = b-a
    u = np.clip((pos @ unit) / (unit @ unit),0,1)
    return np.linalg.norm(pos - u[:,None]*unit,axis=1)

def create_armature():
    data = bpy.data.armatures.new("IMPERATHEN Vierbeinskelett")
    rig = bpy.data.objects.new("EquineRig", data)
    bpy.context.collection.objects.link(rig)
    rig.show_in_front = True
    data.display_type = "STICK"
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    for name, (head, tail, deform) in rest.items():
        bone = data.edit_bones.new(name)
        bone.head, bone.tail, bone.use_deform = head, tail, deform
        if name.startswith("SOCKET_"):
            bone.roll = math.pi
        parent = parents[name]
        if parent:
            bone.parent = data.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    for bone in rig.pose.bones:
        bone.rotation_mode = "QUATERNION"
    rig.rotation_euler.z = math.pi  # exports with forward -Z in Godot
    return rig

def bind_mesh(model, rig):
    # UV-seam duplicates receive identical weights because assignment uses only
    # source-space position. Regions keep hoof, neck and tail out of leg weights.
    xyz = np.asarray([v.co[:] for v in model.data.vertices])
    weights = {name:model.vertex_groups.new(name=name) for name,t in rest.items() if t[2]}
    near = {}
    for key, spec in leg_specs.items():
        a,b,c,d,e = spec["names"]
        near[key]=np.min([min_distance(xyz, rest[k][0], rest[k][1]) for k in (a,b,c,d,e)],axis=0)
    sole_indices = {key:[] for key in leg_specs}
    for i,(x,y,z) in enumerate(xyz):
        result = {}
        k = ("F" if y < .18 else "H") + ("L" if x >= 0 else "R")
        a,b,c,d,e = leg_specs[k]["names"]
        tail = ease(.740,.904,y) * (1-ease(.067,.181,abs(x))) * (1-ease(1.10,1.21,z))
        if z < .20: tail=0
        if y > .87 and z < .91 and abs(x) < .09: tail = max(tail, .95)
        head = (1-ease(-.743,-.646,y)) * ease(1.125,1.395,z)
        muzzle = (1-ease(-.875,-.726,y)) * ease(1.03,1.16,z)
        head = max(head,muzzle)
        neck = (1-ease(-.46,-.221,y)) * ease(.91,1.175,z) * (1-head)
        # The belly reaches the height of the knees in this source. A height
        # cutoff alone weights belly vertices to legs and pulls out skin spikes.
        if k.startswith("F"):
            limb_band=ease(-.56,-.40,y)*(1-ease(-.183,-.056,y))
        else:
            limb_band=ease(.335,.507,y)*(1-ease(.855,.941,y))
        leg = (1-ease(.73,1.105,z)) * (1-ease(.086,.19,near[k][i]))
        leg *= limb_band * (1-tail)
        leg *= 1-ease(.54,.79,z)*(1-ease(.076,.161,abs(x)))
        if z<.56 and near[k][i]<.145 and tail<.4:
            maximum_lower=(1-ease(.075,.127,near[k][i])) * (1-ease(.47,.56,z))
            leg=max(leg,maximum_lower*(1-tail))
        if z<.175 and abs(x)>.047:
            leg=1.0
        leg *= 1-max(head,neck)
        if leg>0:
            upper_end=rest[b][0].z
            middle_end=rest[c][0].z
            lower_end=rest[d][0].z
            ax=ease(upper_end-.062,upper_end+.085,z)
            bx=ease(middle_end-.047,middle_end+.050,z)
            cx=ease(lower_end-.026,lower_end+.047,z)
            dx=ease(.074,.112,z)
            for name,v in zip((a,b,c,d,e),(ax,(1-ax)*bx,(1-bx)*cx,(1-cx)*dx,(1-cx)*(1-dx))):
                result[name]=leg*v
        if tail>0:
            top=ease(.835,.995,z)
            mid=ease(.51,.64,z)
            result.update(Schweif_01=tail*top,Schweif_02=tail*(1-top)*mid,Schweif_03=tail*(1-mid))
        lower_neck = ease(1.23,1.47,z)*neck
        result.update(Kopf=head,Hals=lower_neck,Halsansatz=neck-lower_neck)
        result[TORSO]=max(0,1-sum(result.values()))
        influences=sorted(result.items(),key=lambda item:item[1],reverse=True)[:4]
        total=sum(v for _,v in influences if v>0.00015)
        if total<=0:
            raise RuntimeError(f"No skin weight for vertex {i}")
        for name,value in influences:
            if value>0.00015:
                weights[name].add((i,),value/total,"REPLACE")
        if z < .022 and abs(x)>.05:
            sole_indices[k].append(i)
    for k, ids in sole_indices.items():
        assert len(ids)>20,(k,len(ids))
    model.parent=rig
    modifier=model.modifiers.new("Vierbein-Deformation", "ARMATURE")
    modifier.object=rig
    modifier.use_deform_preserve_volume=True
    return sole_indices

def squared_sine(t):
    return math.sin(math.pi*t) ** 2

# Independent planted phases. Each clip stores an in-place stride contract in
# metres per cycle so the character body can drive the exact compensation.
GAITS = {
    "idle": dict(frames=120, distance=0.0, duty=1.0, lift=0.0,
        phases=dict.fromkeys(leg_specs,0.0)),
    "walk": dict(frames=62, distance=1.045,duty=.66,lift=.142,
        phases={"HL":0.0,"FL":.24,"HR":.50,"FR":.74}),
    "trot": dict(frames=44, distance=1.540,duty=.445,lift=.238,
        phases={"HL":0.0,"FR":0.0,"HR":.50,"FL":.50}),
    "canter": dict(frames=38, distance=2.105,duty=.317,lift=.348,
        phases={"HL":.0,"HR":.165,"FL":.165,"FR":.336}),
}

def hoof_target(phase, leg, gait):
    u = (phase - gait["phases"][leg]) % 1
    width = gait["distance"]
    duty = gait["duty"]
    if u < duty or duty == 1:
        return width*(u-duty*.5),0.0,0.0,0.0,True
    v = (u-duty)/(1-duty)
    span = width*duty
    # Hermite swing with stance velocity at lift-off and touchdown. It gives
    # controlled toe breakover and avoids a sharp horizontal speed discontinuity.
    v2, v3 = v*v, v*v*v
    tang = width*(1-duty)
    y = (2*v3-3*v2+1)*(.5*span)+(v3-2*v2+v)*tang
    y += (-2*v3+3*v2)*(-.5*span)+(v3-v2)*tang
    z = gait["lift"] * squared_sine(v) ** .76
    pitch = .39*math.sin(2*math.pi*v)*math.sin(math.pi*v)
    return y,z,pitch,math.sin(math.pi*v),False

def matrix_at(point, quat):
    return Matrix.Translation(point) @ quat.to_matrix().to_4x4()

def mapping(name, prev, point, angle):
    # Apply a rotation about the bone head after inherited displacement.
    return matrix_at(point, angle @ (prev.to_quaternion() @ rest_quat[name]))

def place_by_axis(name, a, b):
    local = rest[name][1]-rest[name][0]
    return matrix_at(a, local.rotation_difference(b-a) @ rest_quat[name])

def two_bone(a, b, l0, l1, pole):
    axis = b-a
    d = min(max(axis.length, abs(l0-l1)+.0001),l0+l1-.000001)
    d0 = (l0*l0-l1*l1+d*d)/(2*d)
    height = math.sqrt(max(0,l0*l0-d0*d0))
    axis.normalize()
    along = pole-axis*pole.dot(axis)
    along.normalize()
    return a + d0*axis + height*along, a+d*axis

def torso_pose(name, t):
    sin,cos=math.sin,math.cos
    if name=="idle":
        return Vector((0, 0, -.004+.003*cos(TAU*t))),rotate_x(.004*sin(TAU*t))
    if name=="walk":
        return Vector((.009*sin(TAU*t),.011*sin(2*TAU*t),-.038+.009*sin(2*TAU*t))),(
            Quaternion((0,1,0),.019*sin(TAU*t)) @ rotate_x(.023*cos(TAU*t+.35)))
    if name=="trot":
        return Vector((.006*sin(TAU*t),.008*cos(2*TAU*t),-.052+.029*cos(2*TAU*(t-.485)))),(
            Quaternion((0,1,0),.019*sin(TAU*t)) @ rotate_x(.029*cos(2*TAU*t)))
    return Vector((.013*sin(TAU*t),.024*cos(TAU*t+.8),-.043+.070*cos(TAU*(t-.82)))),(
        Quaternion((0,1,0),.026*sin(TAU*t)) @ rotate_x(.109*cos(TAU*(t-.22))))

def cannon_pitch(upper, ankle, cannon, preferred, reach_limit):
    # Rotating about X traces a circle around the ankle. On its arc, choose
    # the feasible angle nearest the authored stance/swing preference.
    direction=upper-ankle
    target=math.hypot(direction.y,direction.z)
    radius=math.hypot(cannon.y,cannon.z)
    closest=math.atan2(direction.z,direction.y)-math.atan2(cannon.z,cannon.y)
    cosine=(target*target+radius*radius+(direction.x-cannon.x)**2-reach_limit**2)/(2*target*radius)
    opening=math.acos(max(-1,min(1,cosine)))
    wrapped=(preferred-closest+math.pi)%TAU-math.pi
    return closest+max(-opening,min(opening,wrapped))

def compose_pose(name, t):
    gait=GAITS[name]
    delta,q=torso_pose(name,t)
    torso_h=rest[TORSO][0]
    targets={}
    lowering=0.0
    preliminary=matrix_at(torso_h+delta,q) @ Matrix.Translation(-torso_h)
    for leg,spec in leg_specs.items():
        a,b,c,d,e=spec["names"]
        off,lift,pitch,fold,planted=hoof_target(t,leg,gait)
        foot=rest[e][0]+Vector((0,off,lift))
        orientation=rotate_x(pitch)
        ankle=foot+orientation@(rest[d][0]-rest[e][0])
        upper=preliminary @ rest[a][0]
        distance=upper-ankle
        usable=sum(spec["lengths"][:3])-.010
        lowering=max(lowering,(distance.length-usable)/max(.57,distance.z/distance.length))
        targets[leg]=(off,lift,fold,planted,foot,orientation,ankle)
    relative=matrix_at(torso_h+delta-Vector((0,0,lowering)),q) @ Matrix.Translation(-torso_h)
    solved={ROOT:rest_matrix[ROOT],TORSO:relative @ rest_matrix[TORSO]}
    for n, rads, yaw in [
        ("Halsansatz",.034*math.sin(TAU*t+.25),.008*math.sin(TAU*t)),
        ("Hals",.040*math.sin(TAU*t+.81),.009*math.sin(TAU*t+.1)),
        ("Kopf",-.032*math.sin(TAU*t+.42),.015*math.sin(TAU*t+.35)),
        ("Schweif_01",.040*math.sin(TAU*t+.9),.046*math.sin(TAU*t)),
        ("Schweif_02",.028*math.sin(TAU*t+.5),.066*math.sin(TAU*t-.64)),
        ("Schweif_03",.026*math.sin(TAU*t+.2),.077*math.sin(TAU*t-.88)),
    ]:
        rel=solved[parents[n]] @ rest_inv[parents[n]]
        amount = 0.45 if name=="idle" else (1.45 if name=="canter" else 1.0)
        carriage=0
        if name=="canter":
            carriage={"Schweif_01":.34,"Schweif_02":.11}.get(n,0)
        solved[n]=mapping(n,rel,rel @ rest[n][0],
            Quaternion((0,0,1),yaw*amount) @ rotate_x(rads*amount+carriage))
    hooves={}
    reach_error={}
    for leg,spec in leg_specs.items():
        a,b,c,d,e=spec["names"]
        off,lift,fold,planted,foot,hoof_quaternion,ankle=targets[leg]
        upper=relative @ rest[a][0]
        cannon=rest[c][0]-rest[d][0]
        preferred=1.65*off+(-.46 if spec["hind"] else .62)*fold
        cap=spec["lengths"][0]+spec["lengths"][1]-.0015
        angle=cannon_pitch(upper,ankle,cannon,preferred,cap)
        wrist=ankle+rotate_x(angle)@cannon
        pole=Vector((0,-1,0))
        bend,actual_wrist=two_bone(upper,wrist,*spec["lengths"][:2],pole)
        reach_error[leg]=(actual_wrist-wrist).length
        solved[a]=place_by_axis(a,upper,bend)
        solved[b]=place_by_axis(b,bend,actual_wrist)
        solved[c]=place_by_axis(c,actual_wrist,ankle)
        solved[d]=place_by_axis(d,ankle,foot)
        solved[e]=matrix_at(foot,hoof_quaternion @ rest_quat[e])
        hooves[leg]={"planted":planted,"reach_error":reach_error[leg],
            "lift":lift,"socket":spec["contact"]}
    for n,(head,tail,deform) in rest.items():
        if n not in solved:
            parent=parents[n]
            solved[n]=solved[parent] @ rest_inv[parent] @ rest_matrix[n]
    return solved,hooves

def apply_pose(rig, pose):
    for name, mat in pose.items():
        p=parents[name]
        basis=rest_inv[name] @ mat
        if p:
            basis=rest_inv[name] @ rest_matrix[p] @ pose[p].inverted() @ mat
        bone=rig.pose.bones[name]
        bone.matrix_basis=basis
    bpy.context.view_layer.update()

def bake(rig,scene):
    made = {}
    previous_quats={}
    for name,gait in GAITS.items():
        frames=gait["frames"]
        action=bpy.data.actions.new(name)
        action.use_fake_user=True
        action["stride_length_m"]=gait["distance"]
        action["nominal_speed_m_s"]=gait["distance"] * FPS / frames
        action["export_fps"]=FPS
        action["duration_seconds"]=frames/FPS
        rig.animation_data_create().action=action
        samples=[]
        for i in range(frames+1):
            t=i/frames
            pose, feet=compose_pose(name,t%1)
            apply_pose(rig,pose)
            for b in rig.pose.bones:
                # Avoid opposite quaternion signs across neighbouring keys.
                old=previous_quats.get(b.name)
                if old and old.dot(b.rotation_quaternion)<0:
                    b.rotation_quaternion.negate()
                previous_quats[b.name]=b.rotation_quaternion.copy()
                b.keyframe_insert(data_path="location", frame=i, group=b.name)
                b.keyframe_insert(data_path="rotation_quaternion", frame=i, group=b.name)
            samples.append(feet)
        for curve in action.fcurves:
            for k in curve.keyframe_points:
                k.interpolation="LINEAR"
        made[name]=action
        frames_by_action[name]=samples
    rig.animation_data.action=None
    for name,action in made.items():
        track=rig.animation_data.nla_tracks.new()
        track.name=name
        strip=track.strips.new(name,0,action)
        strip.name=name
        track.mute=True
    return made

def validate(rig,model,scene,actions,soles):
    baseline=np.asarray([v.co[:] for v in model.data.vertices])
    checks={}
    dg=bpy.context.evaluated_depsgraph_get()
    for name,action in actions.items():
        gait=GAITS[name]
        rig.animation_data.action=action
        planted_count=0
        min_ground=0.0
        sole_error=0.0
        max_drift=0.0
        residual=0.0
        max_lift=0.0
        previous={}
        empty=0
        for i, feet in enumerate(frames_by_action[name]):
            scene.frame_set(i)
            mesh=model.evaluated_get(dg)
            xyz=np.asarray([v.co[:] for v in mesh.data.vertices])
            displacement=gait["distance"]*i/gait["frames"]
            min_ground=min(min_ground, float(np.min(xyz[:,2])))
            support=0
            for leg, info in feet.items():
                residual=max(residual,info["reach_error"])
                pts=xyz[soles[leg]]
                max_lift=max(max_lift,float(pts[:,2].min()))
                if info["planted"]:
                    support+=1
                    planted_count+=1
                    original=baseline[soles[leg]]
                    mean=pts[:,:2].mean(axis=0)-[0,displacement]
                    sole_error=max(sole_error,abs(float(pts[:,2].min()-original[:,2].min())))
                    if leg in previous:
                        max_drift=max(max_drift,float(np.linalg.norm(mean-previous[leg])))
                    previous[leg]=mean
                else:
                    previous.pop(leg,None)
            if not support:
                empty+=1
        checks[name]={"frames":gait["frames"]+1,"stance_samples":planted_count,"aerial_frames":empty,
            "max_floor_penetration_m":-min_ground,"max_planted_sole_error_m":sole_error,
            "max_planted_frame_drift_m":max_drift,"maximum_ik_residual_m":residual,
            "maximum_rendered_hoof_lift_m":max_lift, "cycle_distance_m":gait["distance"],
            "nominal_speed_m_s":gait["distance"]*FPS/gait["frames"],
            "touchdown_phase":gait["phases"], "support_ratio":gait["duty"],
            "passed":min_ground>-.007 and sole_error<.002 and max_drift<.004 and residual<.030}
    rig.animation_data.action=None
    return checks

def select_rig(rig,model):
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    model.select_set(True)
    bpy.context.view_layer.objects.active=rig

def create_studio(scene,rig,actions):
    from mathutils import Vector as Vec
    scene.world=bpy.data.worlds.new("Studioset")
    scene.world.use_nodes=True
    scene.world.node_tree.nodes["Background"].inputs["Color"].default_value=(.22,.27,.32,1)
    scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value=.44
    bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.002))
    ground=bpy.context.object
    mat=bpy.data.materials.new("Studio Kalkgrau")
    mat.diffuse_color=(.17,.22,.25,1)
    ground.data.materials.append(mat)
    def light(name,pos,power,color,size):
        data=bpy.data.lights.new(name,"AREA")
        data.energy=power
        data.color=color
        data.shape="DISK"
        data.size=size
        o=bpy.data.objects.new(name,data)
        bpy.context.collection.objects.link(o)
        o.location=pos
        o.rotation_euler=(Vec((0,0,.8))-o.location).to_track_quat("-Z","Y").to_euler()
    light("Hauptlicht",(-3,2.8,5.3),620,(1,.9,.76),4.2)
    light("Himmel",(-1,-3.3,3.7),360,(.72,.85,1),3.0)
    light("Kante",(2.8,1.8,3.9),290,(1,.82,.67),2.5)
    cam_data=bpy.data.cameras.new("Pruefkamera")
    cam_data.type="ORTHO"
    cam_data.ortho_scale=2.78
    camera=bpy.data.objects.new(cam_data.name,cam_data)
    bpy.context.collection.objects.link(camera)
    camera.location=(-4,1.45,1.67)
    camera.rotation_euler=(Vec((0,0,.84))-camera.location).to_track_quat("-Z","Y").to_euler()
    scene.camera=camera
    scene.render.engine="CYCLES"
    scene.cycles.samples=18
    scene.cycles.use_denoising=False
    scene.render.resolution_x,scene.render.resolution_y=760,530
    scene.render.threads_mode="FIXED"
    scene.render.threads=4
    scene.frame_start=0
    scene.frame_end=GAITS["walk"]["frames"]
    rig.animation_data.action=actions["walk"]
    scene.frame_set(19)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(args.source.resolve()))
model=next(o for o in bpy.context.scene.objects if o.type=="MESH" and o.name.startswith("MeshyGear_"))
for obj in list(bpy.context.scene.objects):
    if obj != model:
        bpy.data.objects.remove(obj,do_unlink=True)
model.name="IMPERATHEN Brauner"
assert len(model.data.vertices)==13873,len(model.data.vertices)
rig=create_armature()
rest_matrix={b.name:b.matrix_local.copy() for b in rig.data.bones}
rest_quat={name:mat.to_quaternion() for name,mat in rest_matrix.items()}
rest_inv={name:mat.inverted() for name,mat in rest_matrix.items()}
soles=bind_mesh(model,rig)
scene=bpy.context.scene
scene.render.fps=FPS
scene.frame_start=0
actions=bake(rig,scene)
checks=validate(rig,model,scene,actions,soles)
rig["gaits"]=str(list(GAITS))
rig["source"]="IMPERATHEN f1e2a3d, mount_legacy_bay_horse original textured LOD0"
rig["facing_godot"]="-Z"
rig["stride_units"]="metres per in-place cycle"
print("HORSE_MOTION_CHECK",json.dumps(checks),flush=True)

# NLA tracks give four independent Godot animation clips.
rig.animation_data.action=None
for track in rig.animation_data.nla_tracks:
    track.mute=False
select_rig(rig,model)
scene.frame_end=max(g["frames"] for g in GAITS.values())
scene.frame_set(0)
file=folder/"IMPERATHEN-Brauner-animiert.glb"
bpy.ops.export_scene.gltf(filepath=str(file),use_selection=True,
    export_skins=True,export_animations=True,export_animation_mode="NLA_TRACKS",
    export_force_sampling=True,export_extras=True,export_optimize_animation_size=False)
for track in rig.animation_data.nla_tracks:
    track.mute=True
create_studio(scene,rig,actions)
select_rig(rig,model)
bpy.ops.file.pack_all()
bpy.context.preferences.filepaths.save_version=0
blend=folder/"IMPERATHEN-Brauner-animiert.blend"
bpy.ops.wm.save_as_mainfile(filepath=str(blend),compress=True)
if args.preview:
    for label,name,phase in [("01-Halt","idle",.0),("02-Schritt","walk",.30),("03-Trab","trot",.226),("04-Rechtsgalopp","canter",.82)]:
        rig.animation_data.action=actions[name]
        scene.frame_set(round(GAITS[name]["frames"]*phase))
        scene.render.filepath=str(folder/f"{label}.png")
        bpy.ops.render.render(write_still=True)
report={"blender":bpy.app.version_string,"forward_axis_godot":"-Z",
    "source_sha256":sha256(args.source.read_bytes()).hexdigest(),
    "blend_sha256":sha256(blend.read_bytes()).hexdigest(),
    "glb_sha256":sha256(file.read_bytes()).hexdigest(),
    "skeleton_bones":len(rest),"skin_bones":len(model.vertex_groups),
    "source_vertices":len(model.data.vertices),"sole_vertices":{k:len(xs) for k,xs in soles.items()},
    "render_fps":FPS,"clips":checks}
(folder/"Kontaktabnahme.json").write_text(json.dumps(report,indent=2)+"\n")
print("HORSE_RIG_COMPLETE",json.dumps(report),flush=True)
