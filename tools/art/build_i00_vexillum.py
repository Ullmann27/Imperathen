#!/usr/bin/env python3
"""Original I-00 woven standard: real Blender mesh, GLB and transparent Cycles render.
Run with Blender 4.3.2 --background --python-exit-code 1 --python this.py -- --output DIR.
The visual design is a reconstruction, not an authenticated surviving flag.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys
import bpy
import numpy as np
from mathutils import Vector

args=argparse.ArgumentParser()
args.add_argument("--output",required=True)
out=Path(args.parse_args(sys.argv[sys.argv.index("--")+1:]).output).resolve()
out.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
WIDTH=HEIGHT=.68
TOP=2.82
FRONT=.082
GRID=24
FRINGE=24

def material(name,color,roughness,metal=0):
    m=bpy.data.materials.new(name)
    m.use_nodes=True
    p=m.node_tree.nodes.get("Principled BSDF")
    p.inputs["Base Color"].default_value=(*color,1)
    p.inputs["Roughness"].default_value=roughness
    p.inputs["Metallic"].default_value=metal
    return m

wood=material("Dark stained ash",(.14,.075,.037),.81)
bronze=material("Weathered bronze",(.37,.26,.12),.52,.68)
cord=material("Dark binding",(.12,.07,.042),.92)
cloth_mat=material("Woven madder textile",(.32,.055,.033),.8)
# Baked original colour atlas: double stitched border, rosette and subdued
# pigment variation. No borrowed design or archaeological attribution.
n=768
x,y=np.meshgrid((np.arange(n,dtype=np.float32)+.5)/n,1-(np.arange(n,dtype=np.float32)+.5)/n)
edge=np.minimum(np.minimum(x,1-x),np.minimum(y,1-y))
q=np.sqrt((x-.5)**2+(y-.49)**2)
angle=np.arctan2(y-.49,x-.5)
gold=((edge>.014)&(edge<.027))|((edge>.050)&(edge<.069))|((np.abs(q-.17)<.011))|((np.abs(q-(.076+.035*np.cos(8*angle)))<.009)&(q<.20))
# Roman-inspired geometric medallion. Colours are deliberately muted.
rgb=np.where(gold[...,None],np.array([.67,.49,.26],np.float32),np.array([.52,.105,.085],np.float32))
weave=np.sin(x*math.tau*125)*np.sin(y*math.tau*125)
rgb*= (0.93+.055*weave+.035*np.sin(x*46+y*26)*np.sin(x*28-y*37))[...,None]
pixels=np.ones((n,n,4),np.float32)
pixels[:,:,:3]=np.clip(rgb,0,1)
atlas=bpy.data.images.new("Original textile atlas",width=n,height=n,alpha=False)
atlas.pixels.foreach_set(pixels.reshape(-1))
atlas.filepath_raw=str(out/"i00_vexillum_textile.png")
atlas.file_format="PNG"
atlas.save()
atlas.pack()
nodes=cloth_mat.node_tree.nodes
tex=nodes.new("ShaderNodeTexImage")
tex.image=atlas
tex.extension="EXTEND"
cloth_mat.node_tree.links.new(tex.outputs["Color"],nodes.get("Principled BSDF").inputs["Base Color"])

def xyz(x,y,z):
    return (x,-z,y)

def cylinder(name,radius,depth,at,mat,horizontal=False,tip=None):
    if tip is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=24,radius=radius,depth=depth,location=xyz(*at))
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=24,radius1=radius,radius2=tip,depth=depth,location=xyz(*at))
    obj=bpy.context.object
    obj.name=name
    if horizontal:
        obj.rotation_euler.y=math.pi/2
    obj.data.materials.append(mat)
    bevel=obj.modifiers.new("Soft worn edges","BEVEL")
    bevel.width=.002
    bevel.segments=2
    obj.modifiers.new("Weighted normals","WEIGHTED_NORMAL")
    return obj

cylinder("Mast",.035,3.04,(0,1.52,0),wood)
cylinder("Crossbar",.018,WIDTH+.16,(0,TOP+.018,FRONT),wood,True)
cylinder("CrossbarFitting",.045,.12,(0,TOP+.018,0),bronze)
cylinder("Finial",.042,.21,(0,3.105,0),bronze,tip=.002)
for side in [-1,1]:
    cylinder("CrossbarCap",.027,.048,(side*(WIDTH/2+.056),TOP+.018,FRONT),bronze,True)
for x0 in [-.30,-.20,-.10,.10,.20,.30]:
    cylinder("SewnBinding",.024,.026,(x0,TOP+.018,FRONT),cord,True)
verts,uvs,faces=[],[],[]
def vertex(u,v):
    verts.append(xyz((u-.5)*WIDTH,TOP-v*HEIGHT,FRONT))
    uvs.append((u,v))
for row in range(GRID+1):
    for col in range(GRID+1):
        vertex(col/GRID,row/GRID)
for row in range(GRID):
    for col in range(GRID):
        a=row*(GRID+1)+col
        b,c=a+1,a+GRID+1
        faces.extend(((a,c,b),(b,c,c+1)))
for i in range(FRINGE):
    u0,u1=(i+.18)/FRINGE,(i+.82)/FRINGE
    v1=1+.055/HEIGHT*(.85+.15*math.cos(i*1.7))
    j=len(verts)
    for u,v in [(u0,1),(u1,1),(u0,v1),(u1,v1)]:
        vertex(u,v)
    faces.extend(((j,j+2,j+1),(j+1,j+2,j+3)))
mesh=bpy.data.meshes.new("Pinned cloth lattice and fringe")
mesh.from_pydata(verts,[],faces)
mesh.update()
obj=bpy.data.objects.new("VexillumCloth",mesh)
bpy.context.collection.objects.link(obj)
mesh.materials.append(cloth_mat)
uv=mesh.uv_layers.new(name="ClothUV")
for p in mesh.polygons:
    p.use_smooth=True
    for loop in p.loop_indices:
        u,v=uvs[mesh.loops[loop].vertex_index]
        uv.data[loop].uv=(u,1-v)
# Export the rest mesh; the exact same bounded fold drives the runtime shader.
bpy.ops.object.select_all(action="SELECT")
glb=out/"i00_vexillum.glb"
bpy.ops.export_scene.gltf(filepath=str(glb),export_format="GLB",use_selection=True)
# Editable Blender preview pose: same wind equation, no world-space transform.
obj.shape_key_add(name="Basis")
fold=obj.shape_key_add(name="WindFold")
seconds=.78
for i,(u,v) in enumerate(uvs):
    a=math.tau*(.60*seconds+1.10*u)+3.6*v
    b=math.tau*(1.25*seconds-.80*u)+5*v
    dz=v*v*(.09+.075*math.sin(a)+.028*math.sin(b))
    fold.data[i].co.y-=dz
fold.value=1.0
scene=bpy.context.scene
scene.render.engine="CYCLES"
scene.cycles.device="CPU"
scene.cycles.samples=48
scene.cycles.use_denoising=True
scene.render.film_transparent=True
scene.render.image_settings.file_format="PNG"
scene.render.image_settings.color_mode="RGBA"
scene.render.image_settings.color_depth="8"
scene.render.resolution_percentage=100
scene.render.resolution_x=768
scene.render.resolution_y=1152
scene.world.color=(.22,.22,.22)
def point_at(o,at):
    o.rotation_euler=(Vector(at)-o.location).to_track_quat("-Z","Y").to_euler()
def area(name,location,at,energy,size,color):
    bpy.ops.object.light_add(type="AREA",location=location)
    light=bpy.context.object
    light.name=name
    light.data.energy=energy
    light.data.shape="DISK"
    light.data.size=size
    light.data.color=color
    point_at(light,at)
area("Overcast key",(2.3,-3.0,4.6),(0,0,2.2),480,4.0,(.82,.9,1.0))
area("Warm bounce",(-2,-2.4,2.3),(0,0,1.8),140,3.0,(1.0,.83,.68))
area("Rim",(1,1.6,3.8),(0,0,2.6),220,2.5,(.90,.94,1.0))
bpy.ops.object.camera_add(location=(2.7,-6.8,2.7))
camera=bpy.context.object
camera.data.type="ORTHO"
camera.data.ortho_scale=3.65
point_at(camera,(0,0,1.60))
scene.camera=camera
scene.render.filepath=str(out/"i00_vexillum_transparent.png")
bpy.ops.wm.save_as_mainfile(filepath=str(out/"i00_vexillum.blend"))
bpy.ops.render.render(write_still=True)
image=bpy.data.images.load(scene.render.filepath,check_existing=False)
px=np.empty(image.size[0]*image.size[1]*4,dtype=np.float32)
image.pixels.foreach_get(px)
alpha=px[3::4]
assert float(alpha.min())<.01 and float(alpha.max())>.99
# Detail proof from same mesh, light and fold, not an image-generation stand-in.
camera.location=(.65,-2.5,2.75)
camera.data.ortho_scale=1.05
point_at(camera,(0,-.08,2.48))
scene.render.resolution_x=960
scene.render.resolution_y=960
scene.render.filepath=str(out/"i00_vexillum_detail.png")
bpy.ops.render.render(write_still=True)
manifest={"design":"Original Roman-inspired reconstruction, not a surviving historically authenticated flag","blender":bpy.app.version_string,"cloth_vertices":len(verts),"cloth_triangles":len(faces),"alpha_min":float(alpha.min()),"alpha_max":float(alpha.max()),"files":{}}
for name in ["i00_vexillum.glb","i00_vexillum.blend","i00_vexillum_transparent.png","i00_vexillum_detail.png","i00_vexillum_textile.png"]:
    p=out/name
    manifest["files"][name]={"sha256":hashlib.sha256(p.read_bytes()).hexdigest(),"bytes":p.stat().st_size}
(out/"i00_vexillum.json").write_text(json.dumps(manifest,indent=2)+"\n")
print("I00_BLENDER_ASSET_PASS",json.dumps(manifest))
