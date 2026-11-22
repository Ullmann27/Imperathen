"""Render transparent cutouts from the actual deliverable GLBs, then assemble contact sheets."""
from math import radians
from pathlib import Path
import sys

import bpy
from mathutils import Vector
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art/landscape/review"
OUT.mkdir(exist_ok=True)
GROUPS = {"soldiers":["heavy","spear","archer","officer"], "trees":["pine","olive","oak"],
          "settlements":["han_house","wa_store","wa_house","wood_longhouse","farmer"],
          "roman":["frontier_house","village_well","atrium_house"],
          "workers":["farmer","han_farmer","wa_farmer"]}
POSES = {"heavy":("wall",9), "spear":("idle",9), "archer":("shoot",19), "officer":("march",4)}


def point(obj, target):
    obj.rotation_euler=(target-obj.location).to_track_quat("-Z","Y").to_euler()


def studio_lights(scene, center):
    lights=[]
    world=bpy.data.worlds.new("Soft skylight")
    scene.world=world
    world.use_nodes=True
    world.node_tree.nodes["Background"].inputs[0].default_value=(.82,.89,.99,1)
    world.node_tree.nodes["Background"].inputs[1].default_value=.68
    for offset,power in (((-2,-3,4),2.9),((3,2,3),2.15)):
        bpy.ops.object.light_add(type="SUN",location=center+Vector(offset))
        sun=bpy.context.object
        sun.data.energy=power
        sun.data.angle=radians(18)
        point(sun,center)
        lights.append(sun)
    return lights


def configure_cycles(scene, pixels=784, samples=10):
    scene.render.engine="CYCLES"
    scene.cycles.samples=samples
    scene.cycles.use_denoising=False
    scene.cycles.transparent_max_bounces=16
    scene.render.film_transparent=True
    scene.render.resolution_x=pixels
    scene.render.resolution_y=pixels
    scene.render.resolution_percentage=100
    scene.render.image_settings.color_mode="RGBA"
    scene.render.image_settings.file_format="PNG"


def render(name):
    group = "soldiers" if name in GROUPS["soldiers"] else "landscape"
    if name in GROUPS["roman"]:
        group="architecture"
    suffix = "_near" if name in GROUPS["soldiers"]+GROUPS["trees"] else ""
    file=ROOT/f"prototype/assets/{group}/{name}{suffix}.glb"
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene=bpy.context.scene
    bpy.ops.import_scene.gltf(filepath=str(file))
    if name in POSES:
        arm=next(obj for obj in scene.objects if obj.type=="ARMATURE")
        clip,frame=POSES[name]
        animation=arm.animation_data
        action=next(track for track in animation.nla_tracks if track.name==clip).strips[0].action
        for track in animation.nla_tracks:
            track.mute=True
        animation.action=action
        scene.frame_set(frame)
    graph=bpy.context.evaluated_depsgraph_get()
    objects=[obj.evaluated_get(graph) for obj in scene.objects
             if obj.type=="MESH" and obj.name!="Icosphere" and not obj.hide_render]
    vertices=[obj.matrix_world @ Vector(corner) for obj in objects for corner in obj.bound_box]
    lo,hi=[Vector([fn(v[i] for v in vertices) for i in range(3)]) for fn in (min,max)]
    center=(hi+lo)/2
    distance=(hi-lo).length
    studio_lights(scene,center)
    viewpoint=(.20,-1,.11) if name in POSES else (1,-1.52,.55)
    bpy.ops.object.camera_add(location=center+Vector(viewpoint).normalized()*distance*2.3)
    camera=bpy.context.object
    point(camera,center)
    camera.data.type="ORTHO"
    inverse=camera.rotation_euler.to_matrix().inverted()
    coords=[inverse @ (v-center) for v in vertices]
    span=max(max(v[i] for v in coords)-min(v[i] for v in coords) for i in (0,1))
    camera.data.ortho_scale=span*1.07
    scene.camera=camera
    configure_cycles(scene)
    path=OUT/f"{name}.png"
    scene.render.filepath=str(path)
    bpy.ops.render.render(write_still=True)
    with Image.open(path) as img:
        assert img.mode=="RGBA" and img.getchannel("A").getextrema()==(0,255)
        crop=img.getchannel("A").getbbox()
        img.crop(crop).save(path)


def sheet(group, names):
    width,height=430,450
    plate=Image.new("RGBA",(width*len(names),height))
    for i,name in enumerate(names):
        with Image.open(OUT/f"{name}.png") as img:
            img.thumbnail((width-12,height-16),Image.Resampling.LANCZOS)
            plate.alpha_composite(img,(i*width+(width-img.width)//2,height-img.height-8))
    plate.save(OUT/f"{group}.png")


if __name__=="__main__":
    requested=sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else list(GROUPS)
    for group in requested:
        for name in GROUPS[group]:
            render(name)
        sheet(group,GROUPS[group])
