#!/usr/bin/env python3
"""Fit the user's original Meshy youth to a metric, editable biped.

Inputs are never modified. Run in Blender 4.3+ with --source ORIGINAL.glb.
The optional inspection blend avoids repeating the expensive initial reduction.
Skinning and sword separation are authored locally, not supplied by Meshy.
"""
from __future__ import annotations
import argparse, hashlib, importlib.util, json, math, sys
from pathlib import Path
import bpy, bmesh, numpy as np
from mathutils import Matrix, Quaternion, Vector

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'prototype/assets/characters'
ART=ROOT/'art/meshy_youth'
DOC=ROOT/'docs/28_city_sandbox'
TASK='b6856033-bc9f-44fe-af12-e9843f161aed'
HEIGHT=1.50
TIERS=((0,32000,2048),(1,16000,1024),(2,6000,512),(3,2000,256))
CLIPS={'idle':2.0,'march':1.0,'run':.72,'talk':1.35,'work':1.6,'gather':1.15,'train':.86,'attack':.8,'block':1.2,'hit':.48,'death':1.2}

def module(name,path):
    spec=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m

def digest(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def smooth(a,b,v):
    t=max(0,min(1,(v-a)/(b-a)));return t*t*(3-2*t)

def bounds(o):
    v=np.array([x.co[:] for x in o.data.vertices]);return [v.min(0).tolist(),v.max(0).tolist()]

def prepare(args):
    if args.inspection_blend:
        bpy.ops.wm.open_mainfile(filepath=args.inspection_blend);body=bpy.data.objects.get('SourceBoy')
        if not body:raise ValueError('Inspection scene lacks SourceBoy')
    else:
        bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=args.source,merge_vertices=True)
        meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
        if any(o.find_armature() for o in meshes):raise ValueError('Refusing to overwrite an existing source rig')
        p=np.array([(o.matrix_world@v.co)[:] for o in meshes for v in o.data.vertices]);lo,hi=p.min(0),p.max(0)
        center=Vector(((lo[0]+hi[0])/2,(lo[1]+hi[1])/2,lo[2]));scale=HEIGHT/(hi[2]-lo[2])
        for o in meshes:
            transform=o.matrix_world.copy();o.parent=None;o.matrix_world=Matrix.Identity(4)
            for v in o.data.vertices:v.co=(transform@v.co-center)*scale
        bpy.ops.object.select_all(action='DESELECT')
        for o in meshes:o.select_set(True)
        bpy.context.view_layer.objects.active=meshes[0]
        if len(meshes)>1:bpy.ops.object.join()
        body=bpy.context.object
        mod=body.modifiers.new('Authored working topology','DECIMATE');mod.ratio=min(1,100000/len(body.data.polygons));mod.use_collapse_triangulate=True
        bpy.ops.object.modifier_apply(modifier=mod.name)
    for o in list(bpy.context.scene.objects):
        if o!=body:bpy.data.objects.remove(o,do_unlink=True)
    body.name='MeshyYouthBody';body.data.update()
    return body

def split_sword(body):
    """Bounded source-specific separation; retain flesh, cap new hand holes."""
    mesh=body.data;mesh.calc_loop_triangles()
    p=np.array([v.co[:] for v in mesh.vertices]);f=np.array([t.vertices[:] for t in mesh.loop_triangles]);c=p[f].mean(1)
    mat=mesh.materials[0];bsdf=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    image=next(l.from_node.image for l in mat.node_tree.links if l.to_socket==bsdf.inputs['Base Color']);w,h=image.size
    pix=np.empty(w*h*4,dtype=np.float32);image.pixels.foreach_get(pix);pix=pix.reshape(h,w,4)
    uvs=np.array([np.mean([mesh.uv_layers.active.data[j].uv[:] for j in t.loops],axis=0) for t in mesh.loop_triangles])%1
    rgb=pix[np.minimum(h-1,(uvs[:,1]*h).astype(int)),np.minimum(w-1,(uvs[:,0]*w).astype(int)),:3];r,g,b=rgb.T
    axis_origin=np.array([-.1339746664,-.1125847307,.4109519571]);axis=np.array([-.1352814684,.7483256656,.6493901929])
    t=(c-axis_origin)@axis;distance=np.linalg.norm(c-axis_origin-t[:,None]*axis,axis=1)
    skin=(g>.16)&(r>g*1.15)&(r<g*1.9)&(b>g*.72)
    selection=(distance<.063)&(c[:,0]<-.12)&(c[:,2]<.80)&((c[:,2]<.622)|~skin)
    # Lower blade tip lies outside the hand's narrow x range.
    selection|=(distance<.04)&(c[:,2]<.60)&(c[:,1]<.10)&(c[:,0]<-.035)
    ids={mesh.loop_triangles[i].polygon_index for i in np.flatnonzero(selection)}
    if not 500<len(ids)<len(mesh.polygons)*.18:raise ValueError('Sword selection outside reviewed limits: '+str(len(ids)))
    sword=body.copy();sword.data=body.data.copy();sword.name='MeshyYouthSword';bpy.context.collection.objects.link(sword)
    def retain(obj,wanted):
        bm=bmesh.new();bm.from_mesh(obj.data);bm.faces.ensure_lookup_table()
        remove=[face for face in bm.faces if (face.index in ids)!=wanted]
        bmesh.ops.delete(bm,geom=remove,context='FACES');bm.to_mesh(obj.data);bm.free();obj.data.update()
    retain(sword,True);retain(body,False)
    bm=bmesh.new();bm.from_mesh(body.data)
    # Fill only the bounded newly exposed hand/handle intersection, not hems.
    edges=[e for e in bm.edges if e.is_boundary and all(-.30<v.co.x<-.11 and .06<v.co.y<.32 and .58<v.co.z<.81 for v in e.verts)]
    capmat=bpy.data.materials.new('Youth hand cut repair');capmat.diffuse_color=(.55,.325,.245,1);capmat.use_nodes=True
    capmat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.55,.325,.245,1)
    capmat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.63
    body.data.materials.append(capmat);capindex=len(body.data.materials)-1
    fill=bmesh.ops.holes_fill(bm,edges=edges,sides=0)
    for face in fill.get('faces',[]):face.material_index=capindex;face.smooth=True
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));remaining=sum(e.is_boundary for e in bm.edges if all(-.30<v.co.x<-.11 and .06<v.co.y<.32 and .58<v.co.z<.81 for v in e.verts))
    bm.to_mesh(body.data);bm.free();body.data.update()
    return sword,{'separated_faces':len(ids),'hand_boundary_edges_before':len(edges),'new_hand_cap_faces':len(fill.get('faces',[])),'hand_boundary_edges_after':remaining}

def create_rig():
    # Landmarks fitted in the original reviewed standing pose, in metres.
    source={'Pelvis':((.025,.12,.79),(.025,.12,.89),None),'Spine':((.025,.12,.89),(.035,.10,1.265),'Pelvis'),'Head':((.035,.10,1.265),(.035,.10,1.45),'Spine')}
    for side,points in {
        'R':[(-.12,.18,1.16),(-.21,.17,.94),(-.234,.182,.735),(-.224,.158,.64),(-.045,.14,.78),(-.055,.19,.435),(-.065,.215,.09),(-.17,.12,.025)],
        'L':[(.19,.035,1.16),(.24,-.02,.94),(.244,-.036,.725),(.23,-.03,.63),(.105,.06,.78),(.16,-.005,.44),(.205,-.035,.09),(.215,-.17,.025)]}.items():
        a,b,c,d,e,f,g,h=points
        source.update({'Arm_'+side:(a,b,'Spine'),'Forearm_'+side:(b,c,'Arm_'+side),'Hand_'+side:(c,d,'Forearm_'+side),'Thigh_'+side:(e,f,'Pelvis'),'Shin_'+side:(f,g,'Thigh_'+side),'Foot_'+side:(g,h,'Shin_'+side)})
    rotation=Matrix.Rotation(math.radians(23),4,'Z');center=Vector((.025,.12,0))
    source={n:((rotation@(Vector(a)-center)),(rotation@(Vector(b)-center)),parent) for n,(a,b,parent) in source.items()}
    target={name:(a.copy(),b.copy(),parent) for name,(a,b,parent) in source.items()}
    for side,sign in [('L',1),('R',-1)]:
        hip=Vector((sign*.070,0,.79));knee=Vector((sign*.075,-.008,.435));ankle=Vector((sign*.078,.012,.075));toe=Vector((sign*.078,-.105,.025))
        target['Thigh_'+side]=(hip,knee,'Pelvis');target['Shin_'+side]=(knee,ankle,'Thigh_'+side);target['Foot_'+side]=(ankle,toe,'Shin_'+side)
    def make(name,joints):
        data=bpy.data.armatures.new(name+'Skeleton');arm=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(arm)
        bpy.ops.object.select_all(action='DESELECT');arm.select_set(True);bpy.context.view_layer.objects.active=arm;bpy.ops.object.mode_set(mode='EDIT')
        for key,(a,b,parent) in joints.items():
            bone=data.edit_bones.new(key);bone.head=a;bone.tail=b
            if parent:bone.parent=data.edit_bones[parent]
        bpy.ops.object.mode_set(mode='OBJECT');return arm
    old=make('SourcePoseRig',source);arm=make('MeshyYouthRig',target)
    return old,arm,rotation,center

def dist_segment(p,a,b):
    v=b-a;t=max(0,min(1,(p-a).dot(v)/v.length_squared));return (p-(a+v*t)).length

def weight_for(p,source):
    z=p.z;core={'Pelvis':1-smooth(.79,1.00,z),'Spine':smooth(.79,1.00,z)}
    if z>1.23:
        h=smooth(1.22,1.30,z);return {'Spine':1-h,'Head':h}
    side='L' if p.x>=0 else 'R'
    arm_names=['Arm_'+side,'Forearm_'+side,'Hand_'+side]
    ds={n:dist_segment(p,source.data.bones[n].head_local,source.data.bones[n].tail_local) for n in arm_names}
    nearest=min(ds.values());torso=dist_segment(p,source.data.bones['Spine'].head_local,source.data.bones['Spine'].tail_local)
    strength=smooth(.025,.105,torso-nearest)*smooth(.54,.61,z)*(1-smooth(1.18,1.24,z))
    if strength>0:
        # Gaussian overlap gives smooth elbows; a hand remains rigid below wrist.
        vals={n:1/max(.018,d)**4 for n,d in ds.items()};total=sum(vals.values());vals={n:v/total for n,v in vals.items()}
        if z<.72 and ds['Hand_'+side]<.065:vals={'Hand_'+side:1.0};strength=1.0
        core={n:v*(1-strength) for n,v in core.items()}
        core.update({n:v*strength for n,v in vals.items()})
    leg_strength=(1-smooth(.53,.67,z))*(1-strength)
    if leg_strength>0:
        names=['Thigh_'+s for s in ['L','R']]+['Shin_'+s for s in ['L','R']]+['Foot_'+s for s in ['L','R']]
        ds={n:dist_segment(p,source.data.bones[n].head_local,source.data.bones[n].tail_local) for n in names}
        vals={n:1/max(.018,d)**5 for n,d in ds.items()};total=sum(vals.values());vals={n:v/total for n,v in vals.items()}
        core={n:v*(1-leg_strength) for n,v in core.items()}
        for n,v in vals.items():core[n]=core.get(n,0)+v*leg_strength
    chosen=sorted([(n,v) for n,v in core.items() if v>1e-7],key=lambda x:x[1],reverse=True)[:4];total=sum(v for _,v in chosen)
    return {n:v/total for n,v in chosen}

def bind_refit(body,sword,old,arm,rotation,center):
    transforms={}
    for bone in arm.data.bones:
        src=old.data.bones[bone.name];scale=Matrix.Diagonal((1,bone.length/src.length,1,1))
        transforms[bone.name]=bone.matrix_local@scale@src.matrix_local.inverted()
    for obj in (body,sword):
        obj.vertex_groups.clear()
        groups={n:obj.vertex_groups.new(name=n) for n in arm.data.bones.keys()}
        for vertex in obj.data.vertices:
            point=rotation@(vertex.co-center);weights={'Hand_R':1.0} if obj==sword else weight_for(point,old)
            vertex.co=sum(((transforms[n]@point)*v for n,v in weights.items()),Vector((0,0,0)))
            for n,value in weights.items():groups[n].add([vertex.index],value,'REPLACE')
        obj.data.update();obj.parent=arm
        modifier=obj.modifiers.new('Fitted original Meshy skin','ARMATURE');modifier.object=arm
        for face in obj.data.polygons:face.use_smooth=True
    bpy.data.objects.remove(old,do_unlink=True)
    # Keep the soles exactly at the scene ground after refitting.
    foot_min=min(v.co.z for v in body.data.vertices);lift=-foot_min
    final_scale=HEIGHT/(max(v.co.z for v in body.data.vertices)+lift)
    for obj in (body,sword):
        for v in obj.data.vertices:v.co.z+=lift;v.co*=final_scale
    bpy.context.view_layer.objects.active=arm;bpy.ops.object.mode_set(mode='EDIT')
    for bone in arm.data.edit_bones:bone.head.z+=lift;bone.tail.z+=lift;bone.head*=final_scale;bone.tail*=final_scale
    bpy.ops.object.mode_set(mode='OBJECT')
    return {'ground_correction_m':lift,'height_m':max(v.co.z for v in body.data.vertices),'bones':len(arm.data.bones)}

def animate(arm):
    shared=module('youth_shared_motion',ROOT/'tools/characters/build_meshy_people.py')
    for bone in arm.pose.bones:bone.rotation_mode='QUATERNION'
    shared.animate(arm)

def export_assets(body,sword,arm):
    mesh=body.data.copy();weapon=sword.data.copy();outputs=[]
    for level,target,texture in TIERS:
        body.data=mesh.copy();sword.data=weapon.copy()
        for obj,budget in ((body,target),(sword,max(350,target//12))):
            bpy.context.view_layer.objects.active=obj;obj.select_set(True)
            obj.data.calc_loop_triangles();tri=len(obj.data.loop_triangles)
            if tri>budget:
                skin=obj.modifiers[0];skin.show_viewport=False
                dec=obj.modifiers.new('Distance detail','DECIMATE');dec.ratio=budget/tri;dec.use_collapse_triangulate=True;bpy.ops.object.modifier_apply(modifier=dec.name);skin.show_viewport=True
            obj.data.validate(clean_customdata=True);obj.data.update()
        for image in bpy.data.images:
            if image.size[0] and max(image.size)>texture:
                scale=texture/max(image.size);image.scale(max(1,round(image.size[0]*scale)),max(1,round(image.size[1]*scale)));image.pack()
        bpy.ops.object.select_all(action='DESELECT')
        for o in (body,sword,arm):o.select_set(True)
        bpy.context.view_layer.objects.active=arm
        path=OUT/('hero_meshy_italia_%d.glb'%level)
        bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_animation_mode='NLA_TRACKS',export_force_sampling=True,export_frame_step=1,export_animations=True,export_morph=False,export_def_bones=False,export_image_format='JPEG',export_jpeg_quality=92)
        body.data.calc_loop_triangles();sword.data.calc_loop_triangles()
        outputs.append({'level':level,'path':str(path.relative_to(ROOT)),'triangles':len(body.data.loop_triangles)+len(sword.data.loop_triangles),'bytes':path.stat().st_size,'sha256':digest(path),'texture_max':texture})
        if level==0:
            bpy.ops.wm.save_as_mainfile(filepath=str(ART/'roman_youth_rigged.blend'),compress=True)
    return outputs

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--source',required=True);parser.add_argument('--inspection-blend');args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
    for path in (OUT,ART,DOC):path.mkdir(parents=True,exist_ok=True)
    body=prepare(args);sword,repair=split_sword(body);old,arm,rotation,center=create_rig();rig=bind_refit(body,sword,old,arm,rotation,center);animate(arm)
    report={'task_id':TASK,'source_sha256':digest(args.source),'source_bytes':Path(args.source).stat().st_size,'source_license':'private user-owned Meshy output','blender':bpy.app.version_string,'repair':repair,'rig':rig,'clips':list(CLIPS),'lods':export_assets(body,sword,arm),'limits':['Fitted authored biped, no individual finger bones or facial blend shapes.','Source depicts an adolescent in armor; height is a design reference, not measured age anatomy.','Visual acceptance and Android frame/heat measurements are separate.']}
    (DOC/'youth-build.json').write_text(json.dumps(report,indent=2)+'\n');print('YOUTH_BUILT',json.dumps(report),flush=True)

if __name__=='__main__':main()
