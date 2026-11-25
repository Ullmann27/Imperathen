"""Render actual committed GLBs under a consistent photographic studio rig."""
import argparse
import hashlib
import json
import math
import sys
from pathlib import Path
import bpy
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[2]
PROPS=ROOT/'prototype/assets/viva_roma/props'
ASSETS=ROOT/'prototype/assets'
parser=argparse.ArgumentParser()
parser.add_argument('--output',required=True,type=Path)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
out=args.output.resolve()
out.mkdir(parents=True,exist_ok=True)

def sha(path):
    with path.open('rb') as f:
        return hashlib.sha256(f.read()).hexdigest()

def connect_surface(mat,normal_path,rough_path,channel='R'):
    nodes=mat.node_tree.nodes
    links=mat.node_tree.links
    p=next(n for n in nodes if n.type=='BSDF_PRINCIPLED')
    def tex(path):
        img=bpy.data.images.load(str(path),check_existing=True)
        img.colorspace_settings.name='Non-Color'
        img.pack()
        node=nodes.new('ShaderNodeTexImage')
        node.image=img
        node.extension='REPEAT'
        return node
    normal=tex(normal_path)
    nm=nodes.new('ShaderNodeNormalMap')
    nm.inputs['Strength'].default_value=.62
    links.new(normal.outputs['Color'],nm.inputs['Color'])
    links.new(nm.outputs['Normal'],p.inputs['Normal'])
    rough=tex(rough_path)
    sep=nodes.new('ShaderNodeSeparateColor')
    links.new(rough.outputs['Color'],sep.inputs['Color'])
    links.new(sep.outputs[{'R':'Red','G':'Green'}[channel]],p.inputs['Roughness'])

def target(obj,point):
    obj.rotation_euler=(Vector(point)-obj.location).to_track_quat('-Z','Y').to_euler()

def light(scene,name,pos,aim,power,size,color):
    d=bpy.data.lights.new(name,'AREA')
    d.energy=power
    d.shape='DISK'
    d.size=size
    d.color=color
    o=bpy.data.objects.new(name,d)
    scene.collection.objects.link(o)
    o.location=pos
    target(o,aim)

reports=[]
for kind in ('helmet','portal'):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    path=PROPS/(kind+'_lod0.glb')
    bpy.ops.import_scene.gltf(filepath=str(path))
    scene=bpy.context.scene
    objects=[o for o in scene.objects if o.type=='MESH']
    if not objects:
        raise RuntimeError('Actual GLB mesh missing: '+str(path))
    points=[o.matrix_world@Vector(v) for o in objects for v in o.bound_box]
    lo=Vector(tuple(min(p[i] for p in points) for i in range(3)))
    hi=Vector(tuple(max(p[i] for p in points) for i in range(3)))
    center=(lo+hi)*.5
    radius=max(hi-lo)
    if radius<=0:
        raise RuntimeError('Invalid object extent')
    texture_sources={}
    for mat in bpy.data.materials:
        if not mat.use_nodes: continue
        m=mat.name.split('.')[0]
        if m in ('Hammered_Bronze','Burnished_Bronze','Interior_Bronze','Bronze_Stud'):
            normal=ASSETS/'weapons/gladius_lod0_bronze_normal.png'
            rough=ASSETS/'weapons/gladius_lod0_bronze_roughness.png'
            channel='R'
        elif m in ('Oak_Dark','Oak_Light'):
            normal=ASSETS/'roman_material_lab/oak_worked_normal.png'
            rough=ASSETS/'roman_material_lab/oak_worked_orm.png'
            channel='G'
        elif m=='Forged_Iron':
            normal=ASSETS/'roman_material_lab/iron_service_normal.png'
            rough=ASSETS/'roman_material_lab/iron_service_orm.png'
            channel='G'
        else:
            continue
        connect_surface(mat,normal,rough,channel)
        texture_sources[str(normal.relative_to(ROOT))]=sha(normal)
        texture_sources[str(rough.relative_to(ROOT))]=sha(rough)
    bpy.ops.mesh.primitive_plane_add(size=radius*200,location=(center.x,center.y,lo.z-radius*.016))
    ground=bpy.context.object
    ground.name='Neutral review support'
    mat=bpy.data.materials.new('Neutral review backdrop')
    mat.use_nodes=True
    p=mat.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value=(.105,.096,.083,1)
    p.inputs['Roughness'].default_value=.86
    ground.data.materials.append(mat)
    world=bpy.data.worlds.new('Neutral studio environment')
    world.use_nodes=True
    world.node_tree.nodes.get('Background').inputs['Color'].default_value=(.45,.53,.65,1)
    world.node_tree.nodes.get('Background').inputs['Strength'].default_value=.28
    scene.world=world
    pos=lambda x,y,z: center+radius*Vector((x,y,z))
    light(scene,'Key',pos(1.6,-2.2,2.4),center,520*radius**2,radius*1.4,(1,.90,.77))
    light(scene,'Fill',pos(-1.7,-1.0,1.2),center,190*radius**2,radius*1.8,(.73,.84,1))
    light(scene,'Rim',pos(.5,1.8,1.6),center,350*radius**2,radius*.9,(1,.93,.85))
    camdata=bpy.data.cameras.new('Metric close-up')
    camera=bpy.data.objects.new('Metric close-up',camdata)
    scene.collection.objects.link(camera)
    scene.camera=camera
    camdata.type='ORTHO'
    camdata.ortho_scale=radius*1.65
    camdata.clip_start=max(.001,radius*.01)
    camdata.clip_end=radius*300
    camera.location=pos(1.45,-2.6,.72)
    target(camera,center)
    scene.render.engine='CYCLES'
    scene.cycles.samples=64
    # Distribution Blender may be compiled without OpenImageDenoiser.
    # Preserve actual unfiltered render evidence and the visual review requirement.
    scene.cycles.use_denoising=False
    scene.render.resolution_x=1440
    scene.render.resolution_y=1200
    scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG'
    scene.render.threads_mode='FIXED'
    scene.render.threads=2
    scene.view_settings.view_transform='AgX'
    scene.render.filepath=str(out/(kind+'_front.png'))
    bpy.ops.render.render(write_still=True)
    camera.location=pos(-1.4,2.5,.85) if kind=='helmet' else pos(-1.3,-2.5,.4)
    target(camera,center)
    scene.render.filepath=str(out/(kind+'_alternate.png'))
    bpy.ops.render.render(write_still=True)
    # Blender 4.x exposes Pack All under bpy.ops.file, not bpy.ops.wm.
    # The imported PBR maps are also packed individually above.
    if not bpy.ops.file.pack_all.poll():
        raise RuntimeError("Blender cannot pack linked image data into the review project")
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(out/(kind+'_review.blend')),compress=True)
    reports.append({'kind':kind,'source_sha256':sha(path),'mesh_objects':len(objects),
        'triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in objects),
        'texture_sources':texture_sources,
        'renders':{name:sha(out/name) for name in (kind+'_front.png',kind+'_alternate.png')},
        'blend_sha256':sha(out/(kind+'_review.blend')),'visual_review':'required'})
(out/'blender_review.json').write_text(json.dumps({'blender':bpy.app.version_string,'props':reports},indent=2))
