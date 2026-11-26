"""Reproducible, offline anatomical hero build for IMPERATHEN.

Uses the vendored CC0 MakeHuman graphical data (not its program source).
Run: blender -b -t 4 -P tools/characters/build_hero.py -- --preview-only
Run: blender -b -t 4 -P tools/characters/build_hero.py -- --export
The preview and the GLB share the same geometry and image-based materials.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import math
import struct
import sys
from collections import defaultdict
from pathlib import Path

import bpy
import bmesh
import numpy as np
from mathutils import Vector, Matrix, Quaternion
from mathutils.kdtree import KDTree

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
from pack_hero_delivery import pack_blend_lossless, pack_hero_glb
import ground_death_clip

ART = ROOT / 'art/hero_quality'
SRC = ART / 'source'
OUT = ROOT / 'prototype/assets/characters'
REVIEW = ART / 'review'
MORPHS = ('Mature', 'Companion', 'Blink_L', 'Blink_R', 'JawOpen', 'Smile', 'BrowDown')
CLIPS = {'idle':2., 'march':1., 'run':.72, 'gather':1.15, 'talk':1.35,
         'train':.86, 'work':1.6, 'block':1.2, 'attack':.8, 'hit':.48, 'death':1.2}
# Imported LOD0/1 sandal vertex 20 still crossed the floor by 10.31 mm
# (11.75 mm at the runtime adult scale) during the middle of the fall.
# A 3 mm smooth transient in this clip absorbs the export interpolation error.
# Endpoint positions stay unchanged; the envelope has zero endpoint slope.
# The exported linear keys introduce no position jump or rest-pose offset.
DEATH_EXPORT_CLEARANCE_M = .003


def obj_data(path):
    vertices, texcoords, faces, groups, uvfaces = [], [], [], [], []
    group = 'body'
    for line in Path(path).read_text().splitlines():
        parts = line.split()
        if not parts: continue
        if parts[0]=='v': vertices.append(tuple(map(float,parts[1:4])))
        elif parts[0]=='vt': texcoords.append(tuple(map(float,parts[1:3])))
        elif parts[0]=='g': group=parts[1]
        elif parts[0]=='f':
            face=[];uv=[]
            for element in parts[1:]:
                indices=element.split('/')
                face.append(int(indices[0])-1)
                uv.append(int(indices[1])-1 if len(indices)>1 and indices[1] else 0)
            faces.append(face);uvfaces.append(uv);groups.append(group)
    return np.array(vertices,dtype=np.float64),texcoords,faces,groups,uvfaces


def target(path, count):
    delta=np.zeros((count,3), dtype=np.float64)
    for line in Path(path).read_text().splitlines():
        p=line.split()
        if len(p)==4 and p[0].isdigit(): delta[int(p[0])]=tuple(map(float,p[1:]))
    return delta


def reduced_joint(name):
    suffix='_'+name[-1] if name.endswith(('.L','.R')) else ''
    if name.startswith(('upperarm','shoulder')):return 'Arm'+suffix
    if name.startswith('lowerarm'):return 'Forearm'+suffix
    if name.startswith(('wrist','finger','metacarpal')):return 'Hand'+suffix
    if name.startswith('upperleg'):return 'Thigh'+suffix
    if name.startswith('lowerleg'):return 'Shin'+suffix
    if name.startswith(('foot','toe')):return 'Foot'+suffix
    if name.startswith(('root','pelvis','spine04','spine05')):return 'Pelvis'
    if name.startswith(('spine','breast','clavicle','neck01')):return 'Spine'
    return 'Head'


def normalize_weights(values):
    pairs=sorted(values.items(),key=lambda p:p[1],reverse=True)[:4]
    total=sum(w for _,w in pairs)
    return {name:w/total for name,w in pairs} if total>0 else {'Head':1.}


def load_anatomy():
    raw,uv,faces,groups,uvfaces=obj_data(SRC/'base.obj')
    child=target(SRC/'caucasian-male-child.target',len(raw))
    adult=target(SRC/'caucasian-male-young.target',len(raw))
    muscle=target(SRC/'universal-male-young-maxmuscle-averageweight.target',len(raw))
    variants=[raw+.78*child+.22*adult,raw+adult+.20*muscle]
    facegroups=defaultdict(set)
    for face,group in zip(faces,groups):facegroups[group].update(face)
    weights_json=json.loads((SRC/'default_weights.mhw').read_text())['weights']
    weights=[defaultdict(float) for _ in raw]
    for bone,entries in weights_json.items():
        for index,weight in entries:weights[index][reduced_joint(bone)]+=weight
    weights=[normalize_weights(w) for w in weights]
    transforms=[]
    bodyids=sorted(facegroups['body'])
    for data in variants:
        lo=data[bodyids,1].min();hi=data[bodyids,1].max();scale=1.50/(hi-lo)
        transforms.append((lo,scale))
    points=[];joints=[]
    for data,(floor,scale) in zip(variants,transforms):
        p=np.column_stack((data[:,0]*scale,-data[:,2]*scale,(data[:,1]-floor)*scale))
        def joint(group):return Vector(p[list(facegroups[group])].mean(axis=0))
        bone={
            'Pelvis':(joint('joint-pelvis'),joint('joint-spine-3'),None),
            'Spine':(joint('joint-spine-3'),joint('joint-neck'),'Pelvis'),
            'Head':(joint('joint-neck'),joint('joint-head-2'),'Spine'),
        }
        for s in ('l','r'):
            suffix='_'+s.upper()
            for name,start,end,parent in (
                ('Arm','shoulder','elbow','Spine'),('Forearm','elbow','hand','Arm'+suffix),
                ('Hand','hand','finger-3-2','Forearm'+suffix),
                ('Thigh','upper-leg','knee','Pelvis'),('Shin','knee','ankle','Thigh'+suffix),
                ('Foot','ankle','toe-3-2','Shin'+suffix)):
                bone[name+suffix]=(joint('joint-'+s+'-'+start),joint('joint-'+s+'-'+end),parent)
        # Rest pose: lower upper arms anatomically, with normalized original weights.
        transforms_arm={}
        for s in ('L','R'):
            pivot=bone['Arm_'+s][0]
            rotation=Matrix.Rotation(math.radians(18)*(1 if s=='L' else -1),4,'Y')
            transforms_arm[s]=Matrix.Translation(pivot) @ rotation @ Matrix.Translation(-pivot)
        for i,point in enumerate(p):
            current=Vector(point);q=current.copy()
            for side,m in transforms_arm.items():
                influence=sum(weights[i].get(n+'_'+side,0) for n in ('Arm','Forearm','Hand'))
                if influence:q+=(m @ current-current)*influence
            p[i]=q
        for side,m in transforms_arm.items():
            for name in ('Arm','Forearm','Hand'):
                a,b,parent=bone[name+'_'+side]
                bone[name+'_'+side]=(m @ a,m @ b,parent)
        points.append(p);joints.append(bone)
    # Adult body is fitted to the youth rest rig. Global height is supplied by
    # the runtime's existing 1.14 age scale; facial anatomy changes remain local.
    adult_fit=[]
    fit={}
    for name,(a,b,_) in joints[1].items():
        c,d,_=joints[0][name]
        rotation=(b-a).rotation_difference(d-c).to_matrix().to_4x4()
        fit[name]=Matrix.Translation(c) @ rotation @ Matrix.Translation(-a)
    for i,point in enumerate(points[1]):
        adult_fit.append(sum(((fit[n] @ Vector(point))*w for n,w in weights[i].items()),Vector()))
    points[1]=np.array(adult_fit)
    return {'raw':raw,'raw_variants':variants,'points':points,'uv':uv,'faces':faces,'groups':groups,
            'uvfaces':uvfaces,'facegroups':facegroups,'weights':weights,'joints':joints[0],
            'scales':transforms,'adult_fit':fit,'facial_weights':weights_json}


def texture_material(name, color=(1,1,1,1), texture=None, normal=None, roughness=.65, alpha=False):
    mat=bpy.data.materials.new(name);mat.use_nodes=True;mat.diffuse_color=color
    mat.use_backface_culling=False
    nodes=mat.node_tree.nodes;links=mat.node_tree.links;p=nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value=color;p.inputs['Roughness'].default_value=roughness
    p.inputs['Specular IOR Level'].default_value=.30
    if texture:
        image=bpy.data.images.load(str(texture),check_existing=True)
        node=nodes.new('ShaderNodeTexImage');node.image=image;image.pack()
        links.new(node.outputs['Color'],p.inputs['Base Color'])
        if alpha:
            links.new(node.outputs['Alpha'],p.inputs['Alpha'])
            mat.surface_render_method='DITHERED'
            mat.alpha_threshold=.42
    if normal:
        image=bpy.data.images.load(str(normal),check_existing=True);image.colorspace_settings.name='Non-Color';image.pack()
        tex=nodes.new('ShaderNodeTexImage');tex.image=image
        normal_node=nodes.new('ShaderNodeNormalMap');normal_node.inputs['Strength'].default_value=.42
        links.new(tex.outputs['Color'],normal_node.inputs['Color']);links.new(normal_node.outputs['Normal'],p.inputs['Normal'])
    return mat


def generated_maps():
    """Native material maps: microscopic relief and woven linen, no baked light."""
    size=512;y,x=np.mgrid[0:size,0:size]
    rng=np.random.default_rng(22112026)
    grain=rng.normal(0,.018,(size,size)).astype(np.float32)
    weave=.055*np.sin(x*1.8)+.045*np.sin(y*2.1)+.012*np.sin(x*.11)*np.sin(y*.17)
    def image(name,data,colorspace='sRGB'):
        img=bpy.data.images.new(name,width=size,height=size,is_data=colorspace=='Non-Color')
        rgba=np.ones((size,size,4),dtype=np.float32);rgba[:,:,:3]=data
        img.pixels.foreach_set(rgba.ravel());img.pack();return img
    linen=image('HeroLinen_woven_base',np.clip(np.array([.39,.35,.28])[None,None,:]*(1+weave[:,:,None]+grain[:,:,None]),0,1))
    rough=image('HeroLinen_roughness',np.repeat(np.clip(.83+grain,0,1)[:,:,None],3,axis=2),'Non-Color')
    normal=image('HeroSkin_micro_normal',np.stack((.5+grain,.5+np.roll(grain,1,0),np.ones_like(grain)),axis=2),'Non-Color')
    linen_normal=image('HeroLinen_weave_normal',np.stack((.5+.04*np.cos(x*1.7),.5+.04*np.cos(y*1.7),np.ones_like(grain)),axis=2),'Non-Color')
    skinrough=image('HeroSkin_roughness',np.repeat(np.clip(.63+grain,0,1)[:,:,None],3,axis=2),'Non-Color')
    return linen,rough,normal,linen_normal,skinrough


def attach_map(material,image,socket,normal=False):
    n=material.node_tree.nodes;l=material.node_tree.links;p=n.get('Principled BSDF')
    t=n.new('ShaderNodeTexImage');t.image=image
    if normal:
        m=n.new('ShaderNodeNormalMap');m.inputs['Strength'].default_value=.25
        l.new(t.outputs['Color'],m.inputs['Color']);l.new(m.outputs['Normal'],p.inputs[socket])
    else:l.new(t.outputs['Color'],p.inputs[socket])


def mesh_object(name,vertices,faces,uvfaces=None,uv=None,material=None):
    data=bpy.data.meshes.new(name);data.from_pydata(vertices,[],faces);data.update()
    if material:data.materials.append(material)
    if uvfaces and uv:
        layer=data.uv_layers.new(name='UVMap')
        for p,coords in zip(data.polygons,uvfaces):
            for li,tex in zip(p.loop_indices,coords):layer.data[li].uv=uv[tex]
    else:
        layer=data.uv_layers.new(name='UVMap')
        for p in data.polygons:
            for li in p.loop_indices:
                v=data.vertices[data.loops[li].vertex_index].co
                layer.data[li].uv=(math.atan2(v.y,v.x)/math.tau+.5,v.z*2)
    for p in data.polygons:p.use_smooth=True
    obj=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(obj)
    return obj


def make_rig(joints):
    armdata=bpy.data.armatures.new('HeroSkeleton15');arm=bpy.data.objects.new('HeroRig',armdata)
    bpy.context.collection.objects.link(arm);bpy.context.view_layer.objects.active=arm
    arm.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
    for name,(start,end,parent) in joints.items():
        b=armdata.edit_bones.new(name);b.head=start;b.tail=end
        if parent:b.parent=armdata.edit_bones[parent]
    bpy.ops.object.mode_set(mode='OBJECT');return arm


def bind(obj,arm,weights):
    for i,pairs in enumerate(weights):
        for name,weight in pairs.items():
            group=obj.vertex_groups.get(name) or obj.vertex_groups.new(name=name)
            if weight>0:group.add([i],float(weight),'REPLACE')
    obj.parent=arm;m=obj.modifiers.new('Hero skin','ARMATURE');m.object=arm


def simple_weights(point,joints):
    x,y,z=point;side='_L' if x>=0 else '_R'
    if z>joints['Head'][0].z:return {'Head':1.}
    if z<joints['Pelvis'][0].z:
        ankle=joints['Foot'+side][0].z;knee=joints['Shin'+side][0].z
        if z<ankle+.035:return {'Foot'+side:1.}
        t=max(0,min(1,(z-knee+.06)/.12))
        return {'Shin'+side:1-t,'Thigh'+side:t}
    if abs(x)>abs(joints['Arm'+side][0].x)+.025:
        elbow=joints['Forearm'+side][0].z;t=max(0,min(1,(z-elbow+.05)/.10))
        return {'Forearm'+side:1-t,'Arm'+side:t}
    t=max(0,min(1,(z-joints['Spine'][0].z+.09)/.20))
    return {'Pelvis':1-t,'Spine':t}


def fit_skirt_weights(skirt, joints):
    """Keep continuous cloth continuous across the left/right leg centreline.

    The previous generic point classifier attached neighbouring hem vertices
    entirely to opposite thighs. A high kick consequently pulled a 2 cm edge
    apart by more than 45 cm. The waistband stays on the pelvis; only the lower
    cloth gradually follows the two thighs, with a smooth shared centre seam.
    """
    waist = joints['Spine'][0].z
    hem = joints['Shin_L'][0].z + .11
    skirt.vertex_groups.clear()
    groups = {name: skirt.vertex_groups.new(name=name) for name in ('Pelvis', 'Thigh_L', 'Thigh_R')}
    for vertex in skirt.data.vertices:
        x, _, z = vertex.co
        lower = max(0., min(1., (waist - z) / max(.01, waist - hem)))
        lower = lower * lower * (3. - 2. * lower)
        left = max(0., min(1., (x + .12) / .24))
        left = left * left * (3. - 2. * left)
        leg = .45 * lower
        values = {'Pelvis': 1. - leg, 'Thigh_L': leg * left, 'Thigh_R': leg * (1. - left)}
        for name, amount in values.items():
            if amount > 0.:
                groups[name].add([vertex.index], amount, 'REPLACE')
    return {'vertices': len(skirt.data.vertices), 'maximum_total_thigh_weight': .45,
            'centre_blend_width_m': .24, 'waist_pelvis_weight': 1.0}


def fit_tunic_joint_weights(tunic):
    """Blend abrupt sleeve/torso assignments only along real cloth edges."""
    if tunic.get('hero_tunic_weight_fit_version', 0) == 1:
        return {'already_fitted': True, 'anatomical_body_weights_changed': False}
    names = [group.name for group in tunic.vertex_groups]
    count = len(tunic.data.vertices)
    values = np.zeros((count, len(names)))
    for vertex in tunic.data.vertices:
        for group in vertex.groups:
            values[vertex.index, group.group] = group.weight
    positions = np.array([tuple(vertex.co) for vertex in tunic.data.vertices])
    edges = np.array([tuple(edge.vertices) for edge in tunic.data.edges], dtype=np.int32)
    first, last = edges[:, 0], edges[:, 1]
    influence = 1. / np.maximum(.003, np.linalg.norm(positions[first] - positions[last], axis=1))
    totals = np.zeros(count)
    np.add.at(totals, first, influence)
    np.add.at(totals, last, influence)
    for _ in range(2):
        neighbours = np.zeros_like(values)
        np.add.at(neighbours, first, values[last] * influence[:, None])
        np.add.at(neighbours, last, values[first] * influence[:, None])
        active = totals > 0.
        values[active] = .65 * values[active] + .35 * neighbours[active] / totals[active, None]
    tunic.vertex_groups.clear()
    groups = {name: tunic.vertex_groups.new(name=name) for name in names}
    for index, row in enumerate(values):
        chosen = np.argsort(row)[-4:]
        total = row[chosen].sum()
        if total <= 0.:
            raise ValueError('Unbound tunic vertex after local seam smoothing')
        for group_index in chosen:
            weight = float(row[group_index] / total)
            if weight > 0.:
                groups[names[group_index]].add([index], weight, 'REPLACE')
    tunic['hero_tunic_weight_fit_version'] = 1
    return {'vertices': count, 'topology_local_passes': 2, 'blend_per_pass': .35,
            'maximum_influences': 4, 'anatomical_body_weights_changed': False}


def body(anatomy,arm,skin):
    selected=[]
    joints=anatomy['joints'];hem=joints['Shin_L'][0].z+.11
    for i,g in enumerate(anatomy['groups']):
        if g!='body':continue
        ids=anatomy['faces'][i];center=anatomy['points'][0][ids].mean(axis=0)
        influence=defaultdict(float)
        for v in ids:
            for bone,w in anatomy['weights'][v].items():influence[bone]+=w/len(ids)
        central=sum(influence.get(k,0) for k in ('Pelvis','Spine','Thigh_L','Thigh_R'))
        covered=hem+.008<center[2]<joints['Head'][0].z+.004 and central>.30
        for side in ('L','R'):
            start,end,_=joints['Arm_'+side];axis=(end-start).normalized()
            along=(Vector(center)-start).dot(axis)/(end-start).length
            covered=covered or (influence.get('Arm_'+side,0)>.25 and along<.54 and center[2]<joints['Head'][0].z+.004)
        if not covered:selected.append(i)
    used=sorted({v for i in selected for v in anatomy['faces'][i]});remap={v:i for i,v in enumerate(used)}
    obj=mesh_object('HeroBody',anatomy['points'][0][used],[[remap[v] for v in anatomy['faces'][i]] for i in selected],
                    [anatomy['uvfaces'][i] for i in selected],anatomy['uv'],skin)
    bind(obj,arm,[anatomy['weights'][i] for i in used]);obj.shape_key_add(name='Basis')
    key=obj.shape_key_add(name='Mature')
    for i,source in enumerate(used):key.data[i].co=anatomy['points'][1][source]
    key=obj.shape_key_add(name='Companion')
    for i,p in enumerate(obj.data.vertices):
        v=p.co.copy();head=max(0,min(1,(v.z-1.28)/.06))
        v.x*=1-.035*head;v.y*=1+.035*head;key.data[i].co=v
    # Face deformations are anatomical vertex displacements. The eyelid aperture
    # is collapsed around the actual eyeball centre, with a curved lid surface.
    p0=anatomy['points'][0]
    eye_centers={side:Vector(p0[list(anatomy['facegroups']['joint-'+side.lower()+'-eye'])].mean(axis=0)) for side in ('L','R')}
    facial=anatomy['facial_weights']
    jawmap=defaultdict(float)
    for bone in ('jaw','special04','oris01','oris07.L','oris07.R','tongue00','tongue01','tongue02','tongue03','tongue04','tongue05.L','tongue05.R','tongue06.L','tongue06.R','tongue07.L','tongue07.R'):
        for vertex,weight in facial.get(bone,[]):jawmap[vertex]+=weight
    jaw_pivot=Vector(p0[list(anatomy['facegroups']['joint-mouth'])].mean(axis=0))
    smilemap={s:dict(facial.get('risorius03.'+s,[])) for s in ('L','R')}
    lidmaps={s:{i:sum(dict(facial.get(n+'.'+s,[])).get(i,0) for n in ('orbicularis03','orbicularis04')) for i in used} for s in ('L','R')}
    for name in MORPHS[2:]:
        key=obj.shape_key_add(name=name)
        for i,source in enumerate(used):
            v=obj.data.vertices[i].co.copy();original=v.copy()
            if name.startswith('Blink'):
                side=name[-1];c=eye_centers[side]
                dx=abs(v.x-c.x);dz=v.z-c.z
                weight=min(1,lidmaps[side].get(source,0)*1.25)
                if weight>0 and v.y<c.y+.005:
                    # CC0 facial weights isolate the lids, leaving bridge and cheeks intact.
                    v.z+=(c.z-.0025-v.z)*weight
                    front=c.y-.023*math.sqrt(max(0,1-(dx/.026)**2))
                    v.y+=min(0,front-v.y)*weight
            elif name=='JawOpen':
                w=jawmap.get(source,0)
                if w>0:
                    pivot=jaw_pivot;r=Matrix.Rotation(math.radians(12),3,'X')
                    v+=(r @ (v-pivot)+pivot-v)*w
            elif name=='Smile':
                w=sum(m.get(source,0) for m in smilemap.values());v.z+=.006*w;v.x+=math.copysign(.004*w,v.x)
            elif name=='BrowDown':
                for c in eye_centers.values():
                    d=((v.x-c.x)/.033)**2+((v.z-c.z-.023)/.017)**2+((v.y-c.y+.015)/.045)**2
                    v.z-=.004*math.exp(-d*1.5)
            key.data[i].co=v
    return obj,eye_centers


def wrap_asset(obj_path,mhclo,anatomy,variant=0):
    raw,uv,faces,groups,uvfaces=obj_data(obj_path)
    scales=np.ones(3);mapping=[];reading=False
    source=anatomy['raw_variants'][variant]
    for line in Path(mhclo).read_text().splitlines():
        p=line.split()
        if not p or p[0].startswith('#'):continue
        if p[0] in ('x_scale','y_scale','z_scale'):
            axis={'x_scale':0,'y_scale':1,'z_scale':2}[p[0]]
            scales[axis]=abs(source[int(p[1]),axis]-source[int(p[2]),axis])/float(p[3])
        elif p[0]=='verts':reading=True
        elif reading:
            if len(p)==9:
                indices=list(map(int,p[:3]));w=np.array(list(map(float,p[3:6])));offset=np.array(list(map(float,p[6:9])))
                mapping.append(np.sum(source[indices]*w[:,None],axis=0)+offset*scales)
            elif len(p)==1 and p[0].isdigit():mapping.append(source[int(p[0])])
            else:reading=False
    if len(mapping)!=len(raw):raise ValueError(f'{obj_path.name}: mapping {len(mapping)} != {len(raw)}')
    data=np.array(mapping);floor,scale=anatomy['scales'][variant]
    points=np.column_stack((data[:,0]*scale,-data[:,2]*scale,(data[:,1]-floor)*scale))
    if variant:
        points=np.array([anatomy['adult_fit']['Head'] @ Vector(p) for p in points])
    return points,uv,faces,uvfaces


def accessory(name,obj_path,mhclo,anatomy,arm,material):
    p,uv,faces,uvfaces=wrap_asset(obj_path,mhclo,anatomy)
    adult,*_=wrap_asset(obj_path,mhclo,anatomy,1)
    obj=mesh_object(name,p,faces,uvfaces,uv,material);bind(obj,arm,[{'Head':1.} for _ in p])
    obj.shape_key_add(name='Basis');key=obj.shape_key_add(name='Mature')
    for i,v in enumerate(adult):key.data[i].co=v
    return obj


def loft(name,rings,mat,arm,joints,n=64,fold=.004):
    vertices=[];faces=[];uv=[];uvfaces=[]
    for k,(cx,cy,z,rx,ry) in enumerate(rings):
        for i in range(n):
            a=i*math.tau/n;f=fold*(.6*math.sin(a*13+.12*k)+.3*math.sin(a*23-.16*k))
            vertices.append((cx+(rx+f)*math.cos(a),cy+(ry+f)*math.sin(a),z+.0015*math.sin(a*7+k*.2)))
            uv.append((i/n,k/(len(rings)-1)))
    for k in range(len(rings)-1):
        for i in range(n):
            j=(i+1)%n;face=[k*n+i,k*n+j,(k+1)*n+j,(k+1)*n+i];faces.append(face);uvfaces.append(face)
    obj=mesh_object(name,vertices,faces,uvfaces,uv,mat)
    bind(obj,arm,[simple_weights(p,joints) for p in vertices])
    obj.shape_key_add(name='Basis');obj.shape_key_add(name='Mature')
    return obj


def tube(name,path,radii,mat,arm,bone,n=12):
    verts=[];faces=[]
    for k,point in enumerate(path):
        tangent=Vector(path[min(k+1,len(path)-1)])-Vector(path[max(0,k-1)])
        axis=tangent.normalized();helper=Vector((0,1,0)) if abs(axis.y)<.9 else Vector((1,0,0))
        a=axis.cross(helper).normalized();b=axis.cross(a).normalized()
        for i in range(n):verts.append(Vector(point)+radii[k]*(a*math.cos(i*math.tau/n)+b*math.sin(i*math.tau/n)))
    for k in range(len(path)-1):
        for i in range(n):j=(i+1)%n;faces.append([k*n+i,k*n+j,(k+1)*n+j,(k+1)*n+i])
    obj=mesh_object(name,verts,faces,material=mat);bind(obj,arm,[{bone:1.} for _ in verts]);return obj


def tailored_top(anatomy,arm,linen):
    """Connected tunic with planar cuts and convex, relaxed cloth sections."""
    j=anatomy['joints'];waist=j['Spine'][0].z;neck=j['Head'][0].z
    selected=[]
    for i,g in enumerate(anatomy['groups']):
        if g!='body':continue
        ids=anatomy['faces'][i];c=Vector(anatomy['points'][0][ids].mean(axis=0))
        if not waist-.10<c.z<neck+.10:continue
        influence=defaultdict(float)
        for v in ids:
            for bone,w in anatomy['weights'][v].items():influence[bone]+=w/len(ids)
        if any(influence.get('Hand_'+side,0)>.1 or influence.get('Forearm_'+side,0)>.45 for side in ('L','R')):continue
        covered=True
        for side in ('L','R'):
            if influence.get('Arm_'+side,0)>.4:
                start,end,_=j['Arm_'+side];axis=(end-start).normalized()
                if (c-start).dot(axis)>(end-start).length*.58:covered=False
        if covered:selected.append(i)
    used=sorted({v for i in selected for v in anatomy['faces'][i]});index={v:i for i,v in enumerate(used)}
    obj=mesh_object('HeroTunic',anatomy['points'][0][used],[[index[v] for v in anatomy['faces'][i]] for i in selected],material=linen)
    bm=bmesh.new();bm.from_mesh(obj.data)
    # Cut actual polygon edges. Centroid-only removal leaves saw teeth at the neck.
    for height,upper in ((neck+.012,True),(waist-.026,False)):
        bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),
            dist=.000001,plane_co=(0,0,height),plane_no=(0,0,1),
            clear_outer=upper,clear_inner=not upper)
    boundary={v for e in bm.edges if e.is_boundary for v in e.verts}
    inner=[v for v in bm.verts if v not in boundary]
    for _ in range(10):bmesh.ops.smooth_vert(bm,verts=inner,factor=.5,use_axis_x=True,use_axis_y=True,use_axis_z=True)
    bm.normal_update()
    source_tree=KDTree(len(used))
    for i,source in enumerate(used):source_tree.insert(Vector(anatomy['points'][0][source]),i)
    source_tree.balance()
    for v in bm.verts:
        v.co+=v.normal*.019
        x,y,z=v.co
        # Convex cloth sections remove breast/nipple detail without an X cutoff seam.
        if waist-.04<z<neck-.065:
            near=source_tree.find_n(v.co,3);den=sum(1/max(.003,d) for _,_,d in near)
            arm_amount=sum(sum(anatomy['weights'][used[i]].get('Arm_'+side,0) for side in ('L','R'))/max(.003,d) for _,i,d in near)/den
            t=max(0,min(1,(arm_amount-.10)/.65));blend=1-t*t*(3-2*t)
            blend*=max(0,min(1,(neck-.065-z)/.045))
            width=.174+.014*math.sin(max(0,min(1,(z-waist)/.26))*math.pi*.5)
            depth=.127-.003*max(0,min(1,(z-waist)/.26))
            angle=math.atan2((y+.026)/depth,x/width)
            v.co.x+=(width*math.cos(angle)-x)*blend
            v.co.y+=(-.026+depth*math.sin(angle)-y)*blend
        if z<waist+.080:
            t=max(0,min(1,(z-waist+.026)/.106))
            rx=.162+.013*t;ry=.122+.006*t
            angle=math.atan2((y+.026)/ry,x/rx)
            v.co.x=rx*math.cos(angle);v.co.y=-.026+ry*math.sin(angle)
        if v in boundary:
            if z>neck-.025:
                # Horizontal, softly oval opening at the actual neck base.
                angle=math.atan2(y+.019,x)
                v.co=(.062*math.cos(angle),-.019+.057*math.sin(angle),neck+.012)
            elif z<waist+.025:
                angle=math.atan2((y+.026)/.127,x/.164)
                v.co=(.164*math.cos(angle),-.026+.127*math.sin(angle),waist-.026)
            else:
                side='L' if x>0 else 'R';start,end,_=j['Arm_'+side];axis=(end-start).normalized()
                centre=start+(end-start)*.58
                v.co-=axis*(v.co-centre).dot(axis)
                # A little sleeve ease avoids a bare skin/cloth coincidence.
                radial=v.co-centre
                if radial.length<.060:v.co=centre+radial.normalized()*.060
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(obj.data);bm.free();obj.data.update()
    # New cut vertices get the closest original anatomical weight interpolation.
    tree=KDTree(len(used))
    for i,source in enumerate(used):tree.insert(Vector(anatomy['points'][0][source]),i)
    tree.balance();weights=[];adult_deltas=[]
    for v in obj.data.vertices:
        near=tree.find_n(v.co,4);normalizer=sum(1/max(.003,d) for _,_,d in near)
        merged=defaultdict(float);delta=Vector()
        for _,i,d in near:
            w=(1/max(.003,d))/normalizer;source=used[i]
            for bone,amount in anatomy['weights'][source].items():merged[bone]+=amount*w
            delta+=Vector(anatomy['points'][1][source]-anatomy['points'][0][source])*w
        weights.append(normalize_weights(merged));adult_deltas.append(delta)
    bind(obj,arm,weights);obj.shape_key_add(name='Basis');adult=obj.shape_key_add(name='Mature')
    for v,delta in zip(adult.data,adult_deltas):v.co+=delta*.40
    # Narrow sewn fabric binding follows the clean collar, not a floating ring.
    collar=[(.063*math.cos(i*math.tau/64),-.019+.058*math.sin(i*math.tau/64),neck+.012) for i in range(65)]
    tube('HeroCollarSeam',collar,[.0023]*65,linen,arm,'Spine',6)
    return obj


def fit_belt_clearance(belt, garments, clearance=.004):
    """Keep the entire low-cost belt outside the actual cloth at every LOD.

    Collapsing a 48-sided band to four sides puts its long chords inside the
    tunic. Preserve its topology separately, then fit the band against the
    clipped waist slab of both Basis and Mature garment geometry. All values
    here are object-space metres on the common authored rest rig.
    """
    vertices = [v.co.copy() for v in belt.data.vertices]
    if len(vertices) < 64:
        raise ValueError('HeroBelt circumference has already lost its protected topology')
    cx = (min(v.x for v in vertices) + max(v.x for v in vertices)) * .5
    cy = (min(v.y for v in vertices) + max(v.y for v in vertices)) * .5
    rx = max(abs(v.x-cx) for v in vertices)
    ry = max(abs(v.y-cy) for v in vertices)
    low, high = min(v.z for v in vertices), max(v.z for v in vertices)
    if min(rx, ry) <= 0:
        raise ValueError('HeroBelt has no measurable waist circumference')
    angles = sorted({round(math.atan2((v.y-cy)/ry, (v.x-cx)/rx) % math.tau, 7) for v in vertices})
    shapes = {}
    if belt.data.shape_keys:
        shapes = {key.name: [v.co.copy() for v in key.data] for key in belt.data.shape_keys.key_blocks}
    # Frontier carriers are fitted to a different rest skeleton. Measure their
    # actual band edges too: that fitting need not preserve a perfect ellipse.
    gap, minimum_radius = 0., float('inf')
    for points in [vertices, *shapes.values()]:
        directions = [math.atan2((v.y-cy)/ry, (v.x-cx)/rx) for v in points]
        minimum_radius = min(minimum_radius, *(math.hypot((v.x-cx)/rx, (v.y-cy)/ry) for v in points))
        for edge in belt.data.edges:
            first, last = edge.vertices
            gap = max(gap, abs((directions[last]-directions[first]+math.pi) % math.tau-math.pi))
    chord = minimum_radius*math.cos(gap*.5)
    if chord <= 0 or gap > math.tau/32+1e-5:
        raise ValueError('HeroBelt has an invalid closed circumference')
    maximum = 0.
    samples = 0
    for garment in garments:
        garment.data.calc_loop_triangles()
        variants = [list(v.co.copy() for v in garment.data.vertices)]
        if garment.data.shape_keys and garment.data.shape_keys.key_blocks.get('Mature'):
            variants.append([v.co.copy() for v in garment.data.shape_keys.key_blocks['Mature'].data])
        for points in variants:
            slab = [p for p in points if low <= p.z <= high]
            for triangle in garment.data.loop_triangles:
                ids = list(triangle.vertices)
                for a, b in zip(ids, ids[1:]+ids[:1]):
                    first, last = points[a], points[b]
                    if abs(last.z-first.z) < 1e-9:
                        continue
                    for height in (low, high):
                        fraction = (height-first.z)/(last.z-first.z)
                        if 0. <= fraction <= 1.:
                            slab.append(first.lerp(last, fraction))
            for point in slab:
                maximum = max(maximum, math.hypot((point.x-cx)/rx, (point.y-cy)/ry))
            samples += len(slab)
    if samples == 0:
        raise ValueError('No garment waist section was measured for HeroBelt')
    scale = max(1., (maximum + clearance/min(rx, ry))/chord)
    for vertex, original in zip(belt.data.vertices, vertices):
        vertex.co = (cx+(original.x-cx)*scale, cy+(original.y-cy)*scale, original.z)
    for name, points in shapes.items():
        for vertex, original in zip(belt.data.shape_keys.key_blocks[name].data, points):
            vertex.co = (cx+(original.x-cx)*scale, cy+(original.y-cy)*scale, original.z)
    belt.data.update()
    belt['protected_lod_topology'] = True
    return {'garment_slab_samples': samples, 'radial_scale': scale,
            'minimum_rest_clearance_m': clearance, 'circumference_samples': len(angles),
            'largest_circumferential_edge_degrees': math.degrees(gap),
            'scope': 'Actual Basis and Mature rest surfaces; animated clearance still requires runtime review'}


def clothing(anatomy,arm,linen,leather):
    j=anatomy['joints'];neck=j['Head'][0].z;waist=j['Spine'][0].z;hip=j['Pelvis'][0].z
    shoulder=abs(j['Arm_L'][0].x);knee=j['Shin_L'][0].z;hem=knee+.11
    tunic=tailored_top(anatomy,arm,linen)
    fit_tunic_joint_weights(tunic)
    rings=[(0,-.025,hem,.222,.148),(0,-.025,hem+.015,.221,.149),(0,-.025,hem+.085,.211,.150),
           (0,-.026,hip-.03,.194,.146),(0,-.027,hip+.04,.180,.134),
           (0,-.026,waist-.015,.164,.127),(0,-.026,waist+.018,.170,.131)]
    skirt=loft('HeroTunicSkirt',rings,linen,arm,j,fold=.0048)
    fit_skirt_weights(skirt, j)
    belt=loft('HeroBelt',[(0,-.026,waist-.030,.174,.139),(0,-.026,waist+.009,.174,.139)],leather,arm,j,48,0)
    fit_belt_clearance(belt, [tunic, skirt])

    # Simple practical sandals, intentionally modest for the childhood chapter.
    for side in ('L','R'):
        foot=j['Foot_'+side][0];x=foot.x
        shoe=loft('HeroSandal_'+side,[(x,-.07,.008,.055,.112),(x,-.07,.023,.057,.114)],leather,arm,j,40,0)
        for sy in (-.125,-.065):
            tube('HeroSandalStrap_'+side,[(x-.047,sy,.024),(x-.031,sy,.053),(x,sy,.067),(x+.031,sy,.053),(x+.047,sy,.024)],[.006]*5,leather,arm,'Foot_'+side,n=6)
    # Existing gameplay requires an independently toggled practice blade mesh.
    hand=j['Hand_R'][1];x,y,z=hand
    blade=tube('PracticeBlade',[hand+Vector((0,0,-.04)),hand+Vector((0,0,.44))],[.014,.010],leather,arm,'Hand_R',8)
    blade.hide_render=True
    return tunic


def animate(arm):
    """Original 15-joint poses, with gait lengths fitted to this actual skeleton."""
    sys.path.insert(0,str(ROOT/'art/soldiers'))
    import build as soldier
    original=soldier.pose
    def pose(clip,t,role):
        if clip in ('march','run'):
            angles={};stride=1.10 if clip=='march' else 1.49;stance=.58 if clip=='march' else .40
            pelvis=arm.data.bones['Pelvis'].head_local.z
            lift=-.035-.014*math.cos(4*math.pi*t)
            for off,side in ((0,'R'),(.5,'L')):
                u=(t+off)%1;fh=0
                if u<=stance:fy=stride*(u-stance/2)
                else:
                    v=(u-stance)/(1-stance);fy=stride*(stance/2+(1-stance)*v-v*v*(3-2*v));fh=(.07 if clip=='march' else .13)*math.sin(math.pi*v)**2
                a=arm.data.bones['Thigh_'+side].length;b=arm.data.bones['Shin_'+side].length
                height=arm.data.bones['Thigh_'+side].head_local.z+lift-arm.data.bones['Foot_'+side].head_local.z-fh
                reach=min(math.hypot(fy,height),a+b-.00001)
                hip=math.atan2(fy,height)-math.acos(max(-1,min(1,(a*a+reach*reach-b*b)/(2*a*reach))))
                knee=math.pi-math.acos(max(-1,min(1,(a*a+b*b-reach*reach)/(2*a*b))))
                ax,bx=math.degrees(hip),math.degrees(knee)
                angles['Thigh_'+side]=(ax,0,0);angles['Shin_'+side]=(bx,0,0);angles['Foot_'+side]=(-ax-bx,0,0)
                counter=math.cos(math.tau*u)
                angles['Arm_'+side]=(-3+14*counter,0,0);angles['Forearm_'+side]=(-8-5*(1-counter),0,0)
            angles['Spine']=(2 if clip=='march' else 5,0,2*math.cos(math.tau*t))
            angles['Head']=(-1,0,-1.5*math.cos(math.tau*t))
            return angles,lift
        if clip in ('talk','gather','work','train'):
            b=math.sin(math.pi*t)**2
            if clip=='talk':return {'Arm_L':(-12*b,0,-6*b),'Forearm_L':(-30*b,0,0),'Head':(3*math.sin(t*math.tau),0,6*b)},0
            if clip=='gather':return {'Thigh_L':(-40*b,0,0),'Thigh_R':(-40*b,0,0),'Shin_L':(75*b,0,0),'Shin_R':(75*b,0,0),'Foot_L':(-35*b,0,0),'Foot_R':(-35*b,0,0),'Spine':(20*b,0,0),'Arm_R':(-25*b,0,0)},-.11*b
            if clip=='work':return {'Spine':(12*b,0,0),'Arm_R':(-30*b,0,0),'Forearm_R':(-15*b,0,0),'Head':(5*b,0,0)},0
            return original('attack',t,role)
        return original(clip,t,role)
    soldier.pose=pose;soldier.LENGTHS=CLIPS
    soldier.animate(arm,'civilian')


def fit_death_ground_contact(arm):
    """Bake the actual skinned fall around its heel with a grounded lower hull.

    Geometry is sampled before changing any animation key. The previous fixed
    pelvis drop came from a different soldier rig and drove this smaller
    character's sandals through the floor. This is an authored clip correction,
    not a relaxed test or an invisible runtime teleport.
    """
    action = bpy.data.actions.get('death')
    if action is None or arm.pose.bones.get('Pelvis') is None:
        raise ValueError('The authored death action and pelvis are required')
    scene = bpy.context.scene
    arm.animation_data.action = action
    for track in arm.animation_data.nla_tracks:
        track.mute = True
    meshes = [obj for obj in scene.objects if obj.type == 'MESH' and not obj.hide_render and obj.find_armature() == arm]
    heel_mesh = bpy.data.objects.get('HeroSandal_L')
    if heel_mesh not in meshes:
        raise ValueError('The authored sandal is required for the fall pivot')
    first, last = action.frame_range
    samples = max(2, math.ceil((last - first) / scene.render.fps * 60))
    pelvis = arm.pose.bones['Pelvis']
    records = []
    anchor = None
    heel_index = None
    floor = None
    maximum_raise = 0.
    for index in range(samples + 1):
        frame = first + (last - first) * index / samples
        scene.frame_set(math.floor(frame), subframe=frame % 1.)
        depsgraph = bpy.context.evaluated_depsgraph_get()
        low = float('inf')
        heel_points = None
        for obj in meshes:
            evaluated = obj.evaluated_get(depsgraph)
            mesh = evaluated.to_mesh()
            try:
                coords = np.empty(len(mesh.vertices) * 3, dtype=np.float64)
                mesh.vertices.foreach_get('co', coords)
                matrix = np.array(evaluated.matrix_world)
                points = coords.reshape((-1, 3)) @ matrix[:3, :3].T + matrix[:3, 3]
                low = min(low, float(points[:, 2].min()))
                if obj == heel_mesh:
                    heel_points = points
            finally:
                evaluated.to_mesh_clear()
        if not math.isfinite(low) or heel_points is None:
            raise ValueError('Cannot measure the actual posed fall geometry')
        if anchor is None:
            floor = low
            sole = np.flatnonzero(heel_points[:, 2] <= heel_points[:, 2].min() + .002)
            heel_index = int(sole[np.argmax(heel_points[sole, 1])])
            anchor = heel_points[heel_index].copy()
        heel = heel_points[heel_index]
        correction = Vector((anchor[0] - heel[0], anchor[1] - heel[1], floor - low))
        maximum_raise = max(maximum_raise, correction.z)
        local = pelvis.bone.matrix_local.to_3x3().inverted() @ (arm.matrix_world.to_3x3().inverted() @ correction)
        records.append((frame, pelvis.location.copy() + local))
    path = 'pose.bones["Pelvis"].location'
    for curve in action.fcurves:
        if curve.data_path == path:
            curve.keyframe_points.clear()
    for frame, location in records:
        pelvis.location = location
        pelvis.keyframe_insert('location', frame=frame)
    for curve in action.fcurves:
        if curve.data_path == path:
            for key in curve.keyframe_points:
                key.interpolation = 'LINEAR'
    arm.animation_data.action = None
    for bone in arm.pose.bones:
        bone.rotation_quaternion = (1, 0, 0, 0)
        bone.location = (0, 0, 0)
    scene.frame_set(0)
    return {'samples': len(records), 'sample_hz': 60, 'maximum_floor_correction_m': maximum_raise,
            'heel_mesh': heel_mesh.name, 'heel_vertex': heel_index,
            'method': 'Actual deformed visible meshes; fixed initial heel in the ground plane; grounded lowest surface'}


def setup_scene():
    scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=32
    scene.cycles.use_denoising=False;scene.render.resolution_x=1000;scene.render.resolution_y=1200;scene.render.resolution_percentage=100
    scene.world=bpy.data.worlds.new('Hero studio');scene.world.use_nodes=True
    scene.world.node_tree.nodes.get('Background').inputs[0].default_value=(.15,.19,.24,1)
    scene.world.node_tree.nodes.get('Background').inputs[1].default_value=.30
    scene.view_settings.view_transform='AgX';scene.view_settings.look='AgX - Medium High Contrast'
    def light(name,pos,power,size,color):
        data=bpy.data.lights.new(name,'AREA');data.energy=power;data.shape='DISK';data.size=size;data.color=color
        obj=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(obj);obj.location=pos
        obj.rotation_euler=(Vector((0,0,1.1))-obj.location).to_track_quat('-Z','Y').to_euler()
    light('Warm key',(-2.4,-3.2,3.8),350,3.5,(1,.83,.67))
    light('Cool fill',(2.6,-1.2,2.4),120,3.,(.68,.79,1.))
    light('Edge light',(1.2,2.2,2.9),450,2.6,(1,.9,.72))
    data=bpy.data.cameras.new('Hero review');camera=bpy.data.objects.new('Hero review',data);bpy.context.collection.objects.link(camera);scene.camera=camera;data.lens=75
    return camera


def camera_at(camera,position,target,lens=75):
    camera.location=position;camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.lens=lens


def render_review(arm,camera):
    scene=bpy.context.scene
    scene.render.resolution_x=1000;scene.render.resolution_y=1200
    camera_at(camera,(.48,-1.04,1.47),(0,-.015,1.36),78)
    scene.render.filepath=str(REVIEW/'hero_child_face.png');bpy.ops.render.render(write_still=True)
    scene.render.resolution_x=1000;scene.render.resolution_y=1400
    camera_at(camera,(1.5,-3.9,1.9),(0,0,.8),75)
    scene.render.filepath=str(REVIEW/'hero_child_full.png');bpy.ops.render.render(write_still=True)
    for obj in bpy.context.scene.objects:
        if obj.type=='MESH' and obj.data.shape_keys:
            key=obj.data.shape_keys.key_blocks.get('Mature')
            if key:key.value=1
    camera_at(camera,(.48,-1.04,1.47),(0,-.015,1.36),78)
    scene.render.resolution_y=1200
    scene.render.filepath=str(REVIEW/'hero_adult_face.png');bpy.ops.render.render(write_still=True)
    for obj in bpy.context.scene.objects:
        if obj.type=='MESH' and obj.data.shape_keys:
            for k in obj.data.shape_keys.key_blocks:k.value=0


def render_deformations(arm,camera):
    scene=bpy.context.scene;body=bpy.data.objects['HeroBody'];keys=body.data.shape_keys.key_blocks
    scene.render.resolution_x=800;scene.render.resolution_y=1000
    camera_at(camera,(.42,-1.05,1.45),(0,-.015,1.36),78)
    keys['Blink_L'].value=1.;keys['Blink_R'].value=1.
    scene.render.filepath=str(REVIEW/'hero_blink.png');bpy.ops.render.render(write_still=True)
    keys['Blink_L'].value=0.;keys['Blink_R'].value=0.;keys['JawOpen'].value=1.
    scene.render.filepath=str(REVIEW/'hero_jaw.png');bpy.ops.render.render(write_still=True)
    keys['JawOpen'].value=0.
    camera_at(camera,(1.7,-4.0,1.7),(0,0,.8),75)
    scene.render.resolution_x=900;scene.render.resolution_y=1260
    arm.animation_data.action=bpy.data.actions['run'];scene.frame_set(5)
    scene.render.filepath=str(REVIEW/'hero_run.png');bpy.ops.render.render(write_still=True)
    arm.animation_data.action=None
    for bone in arm.pose.bones:bone.rotation_quaternion=(1,0,0,0);bone.location=(0,0,0)
    scene.frame_set(0)


def export_lods():
    report=[]
    for level,ratio,texsize in ((0,1.,2048),(1,.50,1024),(2,.22,512),(3,.085,256)):
        bpy.ops.wm.open_mainfile(filepath=str(ART/'hero.blend'))
        bpy.ops.object.select_all(action='DESELECT')
        for obj in list(bpy.context.scene.objects):
            if obj.type not in ('MESH','ARMATURE'):bpy.data.objects.remove(obj,do_unlink=True);continue
            # Ninety-six belt triangles are retained at every tier. Reducing
            # this small circumference destroys fit rather than hidden detail.
            if obj.type=='MESH' and level>0 and obj.name not in ('PracticeBlade', 'HeroBelt'):
                # Preserve morph deltas after decimation using the nearest source
                # surface vertices; topology is validated in the exported bytes.
                keys={};tree=KDTree(len(obj.data.vertices));base=[v.co.copy() for v in obj.data.vertices]
                for i,p in enumerate(base):tree.insert(p,i)
                tree.balance()
                if obj.data.shape_keys:
                    for key in obj.data.shape_keys.key_blocks:
                        if key.name!='Basis':keys[key.name]=[key.data[i].co-base[i] for i in range(len(base))]
                    obj.shape_key_clear()
                bpy.context.view_layer.objects.active=obj
                dec=obj.modifiers.new('Mobile LOD','DECIMATE');dec.ratio=ratio
                bpy.ops.object.modifier_move_to_index(modifier=dec.name,index=0);bpy.ops.object.modifier_apply(modifier=dec.name)
                if keys:
                    obj.shape_key_add(name='Basis')
                    for name,deltas in keys.items():
                        key=obj.shape_key_add(name=name)
                        for v in obj.data.vertices:
                            nearest=tree.find_n(v.co,3);total=sum(1/max(.00001,d) for _,_,d in nearest)
                            delta=sum((deltas[i]/max(.00001,d) for _,i,d in nearest),Vector())/total
                            key.data[v.index].co=v.co+delta
            obj.select_set(True)
        belt_fit=fit_belt_clearance(bpy.data.objects['HeroBelt'],
                                   [bpy.data.objects['HeroTunic'],bpy.data.objects['HeroTunicSkirt']])
        for image in bpy.data.images:
            if image.size[0]>texsize or image.size[1]>texsize:
                factor=texsize/max(image.size);image.scale(max(1,round(image.size[0]*factor)),max(1,round(image.size[1]*factor)));image.pack()
        path=OUT/f'hero_quality_{level}.glb'
        bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,
            export_animation_mode='NLA_TRACKS',export_force_sampling=True,export_frame_step=1,
            export_animations=True,export_morph=True,export_morph_animation=False,export_def_bones=False)
        death_keys=preserve_grounded_death_keys(path,bpy.data.objects['HeroRig'])
        delivery=pack_hero_glb(path) if level==0 else None
        # The Blender fall above pins the heel; the shared post-export step then
        # rolls the contacts with the least slip and grounds the crouch.
        death_ground=ground_death_clip.ground(path)
        gather_ground=ground_death_clip.ground(path,None,'gather')
        triangles=0;meshes=[]
        for obj in bpy.context.scene.objects:
            if obj.type=='MESH':
                obj.data.calc_loop_triangles();n=len(obj.data.loop_triangles);triangles+=n;meshes.append({'name':obj.name,'triangles':n})
        report.append({'lod':level,'triangles':triangles,'bytes':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'meshes':meshes,'texture_edge_max':texsize,'belt_fit':belt_fit,'grounded_death_translation_keys':death_keys,'lossless_delivery':delivery,'death_ground_contact':{key:death_ground[key] for key in ('before','after','maximum_floor_correction_m') if key in death_ground},
                       'gather_ground_contact':{key:gather_ground[key] for key in ('before','after','unchanged') if key in gather_ground},
                       'death_export_clearance':{'maximum_m':DEATH_EXPORT_CLEARANCE_M,'curve':'sin(pi * normalized_time)^2','channel':'death/Pelvis/translation/Y','endpoint_position_delta_m':0,'interpolation':'LINEAR'}})
    return report


def preserve_grounded_death_keys(path, arm):
    """Keep authored 60 Hz translation keys after Blender's 25 fps NLA bake.

    Only the death pelvis translation sampler is replaced. Mesh, materials,
    morphs, other channels and every other animation's duration are preserved.
    glTF uses the armature-local Y-up coordinates corresponding to Blender Z-up.
    """
    action=bpy.data.actions.get('death')
    curves={curve.array_index:curve for curve in action.fcurves if curve.data_path=='pose.bones["Pelvis"].location'}
    if set(curves)!={0,1,2} or arm.data.bones['Pelvis'].parent is not None:
        raise ValueError('Expected the authored root pelvis translation')
    frames=sorted({float(key.co.x) for curve in curves.values() for key in curve.keyframe_points})
    if len(frames)<60:
        raise ValueError('Grounded fall must be authored at 60 Hz before export')
    rest=arm.data.bones['Pelvis'].matrix_local
    positions=[]
    for frame in frames:
        point=rest.translation+rest.to_3x3() @ Vector(tuple(curves[axis].evaluate(frame) for axis in range(3)))
        phase=(frame-frames[0])/(frames[-1]-frames[0])
        clearance=DEATH_EXPORT_CLEARANCE_M*math.sin(math.pi*phase)**2
        positions.append([point.x,point.z+clearance,-point.y])
    times=[(frame-frames[0])/bpy.context.scene.render.fps for frame in frames]
    data=path.read_bytes()
    json_size,json_kind=struct.unpack_from('<II',data,12)
    if json_kind!=0x4E4F534A:
        raise ValueError('Exported glTF JSON chunk is missing')
    document=json.loads(data[20:20+json_size])
    bin_at=20+json_size
    bin_size,bin_kind=struct.unpack_from('<II',data,bin_at)
    if bin_kind!=0x004E4942 or len(document['buffers'])!=1 or document['buffers'][0].get('uri'):
        raise ValueError('Expected the embedded single-buffer hero GLB')
    binary=bytearray(data[bin_at+8:bin_at+8+bin_size])
    original_binary=bytes(binary)
    def append_accessor(values,kind):
        binary.extend(b'\0'*(-len(binary)%4))
        offset=len(binary)
        flattened=[float(value) for row in values for value in row]
        binary.extend(struct.pack('<'+'f'*len(flattened),*flattened))
        view=len(document['bufferViews'])
        document['bufferViews'].append({'buffer':0,'byteOffset':offset,'byteLength':len(flattened)*4})
        accessor=len(document['accessors'])
        document['accessors'].append({'bufferView':view,'componentType':5126,'count':len(values),'type':kind,
            'min':[min(row[axis] for row in values) for axis in range(len(values[0]))],
            'max':[max(row[axis] for row in values) for axis in range(len(values[0]))]})
        return accessor
    input_accessor=append_accessor([[time] for time in times],'SCALAR')
    output_accessor=append_accessor(positions,'VEC3')
    matches=[]
    for animation in document['animations']:
        if animation['name']!='death':continue
        for channel in animation['channels']:
            target=channel['target']
            if document['nodes'][target['node']].get('name')=='Pelvis' and target['path']=='translation':
                channel['sampler']=len(animation['samplers'])
                animation['samplers'].append({'input':input_accessor,'output':output_accessor,'interpolation':'LINEAR'})
                matches.append(channel)
    if len(matches)!=1:
        raise ValueError('Expected exactly one exported death pelvis channel')
    if bytes(binary[:len(original_binary)])!=original_binary:
        raise AssertionError('Original glTF mesh/morph/animation bytes changed')
    document['buffers'][0]['byteLength']=len(binary)
    encoded=json.dumps(document,separators=(',',':'),ensure_ascii=False).encode('utf-8')
    encoded+=b' '*(-len(encoded)%4)
    binary.extend(b'\0'*(-len(binary)%4))
    total=12+8+len(encoded)+8+len(binary)
    path.write_bytes(struct.pack('<4sIIII',b'glTF',2,total,len(encoded),0x4E4F534A)+encoded+struct.pack('<II',len(binary),0x004E4942)+binary)
    return len(frames)


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--preview-only',action='store_true');parser.add_argument('--export',action='store_true');parser.add_argument('--no-render',action='store_true');parser.add_argument('--clay',action='store_true')
    parser.add_argument('--refit-existing', action='store_true', help='Preserve the authored hero geometry/materials and correct its skirt weights and fall')
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    for d in (ART,OUT,REVIEW):d.mkdir(parents=True,exist_ok=True)
    if args.refit_existing:
        bpy.ops.wm.open_mainfile(filepath=str(ART/'hero.blend'))
        arm=bpy.data.objects.get('HeroRig')
        if arm is None:
            raise ValueError('Expected the existing authored HeroRig')
        joints={bone.name:(bone.head_local.copy(),bone.tail_local.copy(),bone.parent.name if bone.parent else None) for bone in arm.data.bones}
        meshes=[obj for obj in bpy.context.scene.objects if obj.type=='MESH']
        preserved={obj.name:([[tuple(v.co) for v in obj.data.vertices]],
                   [(key.name,[tuple(v.co) for v in key.data]) for key in obj.data.shape_keys.key_blocks] if obj.data.shape_keys else []) for obj in meshes}
        skirt_fit=fit_skirt_weights(bpy.data.objects['HeroTunicSkirt'],joints)
        tunic_fit=fit_tunic_joint_weights(bpy.data.objects['HeroTunic'])
        death_contact=fit_death_ground_contact(arm)
        for obj in meshes:
            current=([[tuple(v.co) for v in obj.data.vertices]],
                     [(key.name,[tuple(v.co) for v in key.data]) for key in obj.data.shape_keys.key_blocks] if obj.data.shape_keys else [])
            if current!=preserved[obj.name]:
                raise ValueError('Refit unexpectedly changed anatomical geometry or morphs: '+obj.name)
        bpy.context.preferences.filepaths.save_version=0
        bpy.ops.wm.save_as_mainfile(filepath=str(ART/'hero.blend'),compress=True)
        source_packaging=pack_blend_lossless(ART/'hero.blend')
        levels=export_lods()
        report_path=ART/'build_report.json'
        report=json.loads(report_path.read_text())
        report.update(lods=levels,skirt_weight_fit=skirt_fit,tunic_weight_fit=tunic_fit,death_contact_fit=death_contact,lossless_source_packaging=source_packaging,
                      anatomical_geometry_and_morphs_preserved=True)
        report_path.write_text(json.dumps(report,indent=2)+'\n')
        print('HERO_MOTION_REFIT_COMPLETE',json.dumps({'skirt':skirt_fit,'tunic':tunic_fit,'death':death_contact,'lods':len(levels)}))
        return
    bpy.ops.wm.read_factory_settings(use_empty=True)
    anatomy=load_anatomy();arm=make_rig(anatomy['joints'])
    maps=generated_maps()
    skin_path=SRC/'system_assets/skins/young_caucasian_female/young_lightskinned_female_diffuse.png'
    if not skin_path.is_file() and not args.clay:raise FileNotFoundError(skin_path)
    skin=texture_material('HeroSkin',texture=skin_path if skin_path.is_file() else None,color=(.55,.40,.30,1),roughness=.63)
    attach_map(skin,maps[2],'Normal',True);attach_map(skin,maps[4],'Roughness')
    linen=texture_material('HeroLinen',roughness=.84);attach_map(linen,maps[0],'Base Color');attach_map(linen,maps[1],'Roughness');attach_map(linen,maps[3],'Normal',True)
    leather=texture_material('HeroLeather',(.105,.055,.026,1),roughness=.82)
    body_obj,eyes=body(anatomy,arm,skin)
    eyemat=texture_material('HeroEye',texture=SRC/'brown_eye.png',roughness=.24,alpha=True)
    accessory('HeroEyes',SRC/'high-poly.obj',SRC/'high-poly.mhclo',anatomy,arm,eyemat)
    hairpath=SRC/'system_assets/hair/short02'
    if not args.clay:
        hairmat=texture_material('HeroHair',texture=hairpath/'short02_diffuse.png',normal=hairpath/'short02_normal.png',roughness=.71,alpha=True)
        accessory('HeroHair',hairpath/'short02.obj',hairpath/'short02.mhclo',anatomy,arm,hairmat)
    clothing(anatomy,arm,linen,leather)
    animate(arm)
    death_contact = fit_death_ground_contact(arm)
    camera=setup_scene()
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(ART/'hero.blend'),compress=True)
    source_packaging=pack_blend_lossless(ART/'hero.blend')
    if not args.no_render:
        render_review(arm,camera)
        render_deformations(arm,camera)
    levels=export_lods() if args.export else []
    report={'generator':str(Path(__file__).relative_to(ROOT)),'blender':bpy.app.version_string,'height_m':1.50,
            'runtime_adult_scale':1.14,'bones':list(anatomy['joints']),'animations':list(CLIPS),'morphs':list(MORPHS),'lods':levels,
            'source':'MakeHuman CC0 graphical data; see source/provenance.json','death_contact_fit':death_contact,'lossless_source_packaging':source_packaging,
            'limits':['No claim of AAA finished quality or Android GPU performance.','Age target fitted to one rest rig; separate adult rig remains a production task.','Micro normal is original procedural relief, not scanned skin.','Facial motion requires visual deformation acceptance.']}
    (ART/'build_report.json').write_text(json.dumps(report,indent=2)+'\n')
    print('HERO_BUILD_COMPLETE',json.dumps(report))

if __name__=='__main__':main()
