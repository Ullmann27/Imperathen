#!/usr/bin/env python3
"""Recover the user's Meshy temple as a metric, editable mobile asset."""
import argparse,hashlib,json,sys
from pathlib import Path
import bpy,numpy as np
from mathutils import Matrix,Vector
ROOT=Path(__file__).resolve().parents[2]
TASK='629bd668-c5ed-4057-bd6d-c02322c80e4e'
def digest(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--source',required=True);args=ap.parse_args(sys.argv[sys.argv.index('--')+1:])
    out=ROOT/'prototype/assets/world';art=ROOT/'art/meshy_temple';doc=ROOT/'docs/28_city_sandbox'
    for p in (out,art,doc):p.mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=args.source,merge_vertices=True)
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH'];coords=np.concatenate([np.array([(o.matrix_world@v.co)[:] for v in o.data.vertices]) for o in meshes])
    lo,hi=coords.min(0),coords.max(0);scale=14.0/(hi[2]-lo[2]);center=Vector(((lo[0]+hi[0])/2,(lo[1]+hi[1])/2,lo[2]))
    original_triangles=sum(len(o.data.polygons) for o in meshes)
    for o in meshes:
        matrix=o.matrix_world.copy();o.parent=None;o.matrix_world=Matrix.Identity(4)
        for v in o.data.vertices:v.co=(matrix@v.co-center)*scale
    bpy.ops.object.select_all(action='DESELECT')
    for o in meshes:o.select_set(True)
    bpy.context.view_layer.objects.active=meshes[0]
    if len(meshes)>1:bpy.ops.object.join()
    temple=bpy.context.object;temple.name='RomanMeshyTemple';temple.data.calc_loop_triangles()
    initial=len(temple.data.loop_triangles)
    dec=temple.modifiers.new('Architectural mobile detail','DECIMATE');dec.ratio=min(1,110000/initial);dec.use_collapse_triangulate=True;bpy.ops.object.modifier_apply(modifier=dec.name)
    for f in temple.data.polygons:f.use_smooth=True
    source=temple.data.copy();records=[]
    for level,target,edge in [(0,110000,2048),(1,50000,1024),(2,16000,512),(3,5000,256)]:
        temple.data=source.copy();temple.data.calc_loop_triangles();tri=len(temple.data.loop_triangles)
        if tri>target:
            dec=temple.modifiers.new('Distance detail','DECIMATE');dec.ratio=target/tri;dec.use_collapse_triangulate=True;bpy.ops.object.modifier_apply(modifier=dec.name)
        for image in bpy.data.images:
            if image.size[0] and max(image.size)>edge:
                fac=edge/max(image.size);image.scale(max(1,round(image.size[0]*fac)),max(1,round(image.size[1]*fac)));image.pack()
        path=out/('roman_meshy_temple_%d.glb'%level)
        bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_animations=False,export_image_format='JPEG',export_jpeg_quality=94)
        temple.data.calc_loop_triangles();records.append({'level':level,'path':str(path.relative_to(ROOT)),'triangles':len(temple.data.loop_triangles),'bytes':path.stat().st_size,'sha256':digest(path)})
        if level==0:bpy.ops.wm.save_as_mainfile(filepath=str(art/'roman_temple.blend'),compress=True)
    report={'task_id':TASK,'source_sha256':digest(args.source),'source_bytes':Path(args.source).stat().st_size,'source_triangles':original_triangles,'height_m':14.0,'width_m':float((hi[0]-lo[0])*scale),'depth_m':float((hi[1]-lo[1])*scale),'boy_reference_m':1.5,'scale_factor':scale,'ground_y_m':0,'temple_world_position_godot':[0,0,-55],'lods':records,'source_license':'private user-owned Meshy output','historical_status':'User-provided Roman-inspired temple; not claimed as an exact archaeological survey','interior_status':'Source doors closed; no fabricated navigable interior'}
    (doc/'temple-build.json').write_text(json.dumps(report,indent=2)+'\n');print('TEMPLE_BUILT',json.dumps(report),flush=True)
if __name__=='__main__':main()
