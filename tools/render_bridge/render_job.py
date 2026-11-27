"""Render actual existing IMPERATHEN assets in Blender, never modify gameplay files."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import sys
import bpy
from mathutils import Vector

HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
from protocol import load_job, inspect_glb, digest
ROOT=HERE.parents[1]

def armature_signature():
    rigs=[o for o in bpy.context.scene.objects if o.type=="ARMATURE"]
    return sorted((o.name,tuple(sorted(b.name for b in o.data.bones))) for o in rigs)

def camera_at(cam, target, offset, scale, h):
    cam.location=target+Vector(offset)*h
    cam.rotation_euler=(target-cam.location).to_track_quat("-Z","Y").to_euler()
    cam.data.ortho_scale=scale

def render_asset(root,asset,out):
    src,raw,doc=inspect_glb(root,asset)
    target=out/asset["id"]
    target.mkdir(parents=True,exist_ok=False)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(src))
    scene=bpy.context.scene
    rigs=[o for o in scene.objects if o.type=="ARMATURE"]
    meshes=[o for o in scene.objects if o.type=="MESH"]
    if not rigs or not meshes or not bpy.data.actions:
        raise RuntimeError("Blender import lost rig or animation data")
    skeleton=armature_signature()
    actions=sorted(a.name for a in bpy.data.actions)
    # Review rest geometry without clearing animation tracks, weights or morphs.
    for rig in rigs: rig.data.pose_position="REST"
    for mesh in meshes:
        if mesh.name.split(".")[0]=="PracticeBlade":
            mesh.hide_render=True
    scene.frame_set(1)
    bpy.context.view_layer.update()
    deps=bpy.context.evaluated_depsgraph_get()
    points=[]
    for mesh in meshes:
        if mesh.hide_render: continue
        ev=mesh.evaluated_get(deps)
        points.extend(ev.matrix_world @ Vector(v) for v in ev.bound_box)
    if not points: raise RuntimeError("Empty visible character")
    lo=Vector(tuple(min(p[i] for p in points) for i in range(3)))
    hi=Vector(tuple(max(p[i] for p in points) for i in range(3)))
    h=hi.z-lo.z
    if not .2<h<3.5: raise RuntimeError("Unexpected character size")
    center=(lo+hi)*.5
    scene.world=bpy.data.worlds.new("IMPERATHEN Neutralstudio")
    scene.world.use_nodes=True
    background=scene.world.node_tree.nodes.get("Background")
    background.inputs[0].default_value=(.17,.19,.22,1)
    background.inputs[1].default_value=.55
    scene.render.engine="CYCLES"
    scene.cycles.device="CPU"
    scene.cycles.samples=12
    scene.cycles.use_denoising=True
    scene.render.threads_mode="FIXED"
    scene.render.threads=4
    scene.view_settings.view_transform="AgX"
    scene.render.image_settings.file_format="PNG"
    scene.render.image_settings.color_mode="RGB"
    scene.render.resolution_percentage=100
    scene.render.film_transparent=False
    for name,offset,power,size,color in [
        ("Studio Key",(-.9,-1.8,1.6),320,1.4,(1,.88,.76)),
        ("Studio Fill",(1.4,-.8,.6),150,1.5,(.77,.87,1)),
        ("Studio Rim",(.5,1.5,1.3),260,1.0,(1,.93,.8)),
    ]:
        data=bpy.data.lights.new(name,"AREA")
        light=bpy.data.objects.new(name,data);scene.collection.objects.link(light)
        light.location=center+Vector(offset)*h
        data.energy=power*h*h;data.shape="DISK";data.size=size*h;data.color=color
        light.rotation_euler=(center-light.location).to_track_quat("-Z","Y").to_euler()
    camera=bpy.data.objects.new("IMPERATHEN Figur",bpy.data.cameras.new("IMPERATHEN Figur"))
    scene.collection.objects.link(camera);scene.camera=camera
    camera.data.type="ORTHO"
    full=Vector((center.x,center.y,lo.z+h*.50))
    head=Vector((center.x,center.y,lo.z+h*.88))
    views=[
        ("Ganzfigur",full,(.26,-3,.10),h*1.18,600,840),
        ("Gesicht",head,(.24,-3,.025),h*.35,600,700),
        ("Rueckansicht",full,(-.26,3,.10),h*1.18,600,840),
    ]
    outputs={}
    for name,aim,offset,scale,w,hpix in views:
        camera_at(camera,aim,offset,scale,h)
        scene.render.resolution_x=w;scene.render.resolution_y=hpix
        dst=target/(name+".png");scene.render.filepath=str(dst)
        bpy.ops.render.render(write_still=True)
        if dst.stat().st_size<1000 or dst.read_bytes()[:8]!=b"\x89PNG\r\n\x1a\n":
            raise RuntimeError("Missing or invalid real PNG")
        outputs[dst.name]=digest(dst)
    # Save the editable review with packed material inputs and the full-body camera.
    camera_at(camera,full,(.26,-3,.10),h*1.18,h)
    scene.render.resolution_x=600;scene.render.resolution_y=840
    scene.render.filepath="//Ganzfigur.png"
    scene["render_only"]=True
    scene["source_asset"]=asset["path"]
    scene["source_git_blob"]=asset["git_blob"]
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type=="VIEW_3D":
                area.spaces.active.region_3d.view_perspective="CAMERA"
    bpy.ops.file.pack_all()
    bpy.context.preferences.filepaths.save_version=0
    blend=target/"Figur.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend),compress=True)
    # Reopen the actual saved .blend, proving rig and clip data survived.
    bpy.ops.wm.open_mainfile(filepath=str(blend),load_ui=False)
    if armature_signature()!=skeleton or sorted(a.name for a in bpy.data.actions)!=actions:
        raise RuntimeError("Saved review lost rig or animation data")
    outputs[blend.name]=digest(blend)
    # Reuse the exact original game GLB: a rendering job must not re-export or
    # risk changing its weights, clip names, texture packing or runtime contract.
    glb=target/"Original.glb";shutil.copyfile(src,glb)
    if src.read_bytes()!=raw or glb.read_bytes()!=raw:
        raise RuntimeError("Original asset modified")
    outputs[glb.name]=digest(glb)
    return {"id":asset["id"],"label":asset["label"],"source_path":asset["path"],"source_git_blob":asset["git_blob"],
            "source_sha256":hashlib.sha256(raw).hexdigest(),"armatures":len(skeleton),"actions":actions,"files":outputs}

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--job",type=Path,required=True)
    parser.add_argument("--output",type=Path,required=True)
    parser.add_argument("--checkout",required=True)
    args=parser.parse_args(sys.argv[sys.argv.index("--")+1:])
    job=load_job(args.job)
    out=args.output.resolve()/job["job_id"]
    out.mkdir(parents=True,exist_ok=False)
    rows=[render_asset(ROOT,a,out) for a in job["assets"]]
    report={"status":"rendered_and_reopened","project":"IMPERATHEN","job_id":job["job_id"],"source_revision":job["source_revision"],"checkout":args.checkout,"blender":bpy.app.version_string,"visual_acceptance":False,"physical_device_test":False,"assets":rows}
    (out/"receipt.json").write_text(json.dumps(report,indent=2,ensure_ascii=False)+"\n",encoding="utf-8")
    page=["# IMPERATHEN – Figurenatelier","", "Vorhandene Spielfiguren, tatsächlich in Blender gerendert. Keine neuen Charakterfreigaben.",""]
    for row in rows:
        ident=row["id"]
        page.extend(["## "+row["label"],"",f"![Ganzfigur]({ident}/Ganzfigur.png)","",f"![Gesicht]({ident}/Gesicht.png)","",f"![Rückansicht]({ident}/Rueckansicht.png)","",f"[Figur in Blender öffnen]({ident}/Figur.blend) · [Unverändertes Spielmodell](https://github.com/Ullmann27/Imperathen/blob/{job['source_revision']}/{row['source_path']})",""])
    (out/"README.md").write_text("\n".join(page)+"\n",encoding="utf-8")
    print("IMPERATHEN_RENDER_ATELIER_PASS",job["job_id"],len(rows),flush=True)

if __name__=="__main__":main()
