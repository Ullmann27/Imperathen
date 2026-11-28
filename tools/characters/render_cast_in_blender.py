#!/usr/bin/env python3
"""Blender art review of the actual installed named cast, not concept art.

Source catalog parameters are projected onto the available GLB morphs and
materials; Godot shaders and runtime pose overlays require separate engine
review. All missing files/unsupported morphs are explicitly reported.
"""
import argparse, hashlib, json, math, re, sys
from pathlib import Path
import bpy
from mathutils import Vector

def literal(text,name):
    m=re.search(r"^const "+re.escape(name)+r"\s*:=\s*",text,re.M)
    if not m: raise ValueError("Missing literal "+name)
    cleaned=re.sub(r"(?m)^\s*#.*$", "", text[m.end():])
    cleaned=re.sub(r",\s*([}\]])",r"\1",cleaned)
    return json.JSONDecoder().raw_decode(cleaned.lstrip())[0]

def colour(s):
    if len(s)!=6 or not re.fullmatch("[a-fA-F0-9]+",s):return (1,1,1,1)
    def linear(x):
        x=int(x,16)/255
        return x/12.92 if x<=.04045 else ((x+.055)/1.055)**2.4
    return tuple(linear(s[i:i+2]) for i in (0,2,4))+(1,)

def tint(mat,c):
    if not mat or not mat.use_nodes:return
    nodes=mat.node_tree.nodes;links=mat.node_tree.links
    shader=next((n for n in nodes if n.type=="BSDF_PRINCIPLED"),None)
    if shader is None:return
    socket=shader.inputs["Base Color"]
    if socket.is_linked:
        old=socket.links[0].from_socket
        mix=nodes.new("ShaderNodeMixRGB");mix.blend_type="MULTIPLY"
        mix.inputs[0].default_value=1
        mix.inputs[2].default_value=c
        links.new(old,mix.inputs[1]);links.new(mix.outputs[0],socket)
    else:socket.default_value=tuple(socket.default_value[i]*c[i] for i in range(4))

def setup_studio(center,height):
    scene=bpy.context.scene
    scene.world=bpy.data.worlds.new("Neutral review world");scene.world.use_nodes=True
    bg=scene.world.node_tree.nodes.get("Background")
    bg.inputs[0].default_value=(.17,.19,.22,1);bg.inputs[1].default_value=.6
    scene.render.engine="CYCLES";scene.cycles.samples=5;scene.cycles.use_denoising=getattr(bpy.app.build_options,"openimagedenoise",False)
    scene.render.threads_mode="FIXED";scene.render.threads=2
    scene.view_settings.view_transform="AgX"
    scene.render.image_settings.file_format="JPEG";scene.render.image_settings.quality=88
    scene.render.resolution_percentage=100
    for off,power,size in [((-.9,-1.8,1.6),300,1.4),((1.4,-.8,.6),130,1.5),((.5,1.5,1.3),260,1.0)]:
        bpy.ops.object.light_add(type="AREA",location=center+Vector(off)*height)
        light=bpy.context.object;light.data.energy=power*height*height;light.data.shape="DISK";light.data.size=size*height
        light.rotation_euler=(center-light.location).to_track_quat("-Z","Y").to_euler()
    bpy.ops.object.camera_add()
    camera=bpy.context.object;scene.camera=camera;camera.data.type="ORTHO"
    return scene,camera

def render_one(entry,source,out,dyes,hairs):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(source))
    meshes=[o for o in bpy.context.scene.objects if o.type=="MESH"]
    if not meshes:raise ValueError("no mesh")
    external=entry.get("original_owner_asset",False)
    face=entry.get("face",{})
    wanted={**face,**entry.get("build",{}),**entry.get("hair",{}).get("keys",{})}
    wanted.update({"ID_Age":entry.get("face_age",max(0,min(1,(entry.get("look_age",35)-28)/34))),
                   "ID_Hem":entry.get("hem",0),"BEARD_Full":entry.get("beard",{}).get("full",0),
                   "VEIL_Long":entry.get("veil_long",0),"ID_Show":1.0})
    aliases={"CastJaw":"ID_JawWidth","CastBridge":"ID_NoseBridge","CastCheeks":"ID_Cheeks","CastHair":"HAIR_Volume"}
    applied=set();parts=[]
    has_bound=any(o.name.split(".")[0]=="IdentityHairBound" for o in meshes)
    bound=has_bound and entry.get("hair",{}).get("style")=="bound"
    coloured=set()
    for o in meshes:
        part=o.name.split(".")[0]
        if part=="PracticeBlade" or ("sword" in part.lower() and entry["id"]=="player"):o.hide_render=True
        if not external and part.startswith("Identity"):
            shown=part in entry.get("wear",{}) or (part=="IdentityBeard" and bool(entry.get("beard"))) or (part=="IdentityHairBound" and bound)
            o.hide_render=not shown
        if bound and (part=="HeroHair" or part=="FrontierBoundLocks"):o.hide_render=True
        if part=="FrontierBeard" and any(m.name.split(".")[0]=="IdentityBeard" for m in meshes):o.hide_render=True
        if not external and o.data.shape_keys:
            for k in o.data.shape_keys.key_blocks:
                key=aliases.get(k.name,k.name)
                if key in wanted:
                    k.value=max(k.slider_min,min(k.slider_max,float(wanted[key])));applied.add(key)
        if o.hide_render:continue
        parts.append(part)
        if external:continue
        for slot in o.material_slots:
            mat=slot.material
            if mat is None or mat.name in coloured:continue
            n=mat.name.split(".")[0];c=None
            if n in ("FrontierCloth","HeroLinen"):c=colour(dyes.get(entry.get("wear",{}).get("tunic","undyed"),"e6ddca"))
            elif n in ("HeroHair","FrontierGreyHair","IdentityBeard"):c=colour(hairs.get(entry.get("hair",{}).get("color","brown"),"47301e"))
            if c is not None:
                # Existing strand/linen texture is preserved, not replaced by flat paint.
                if n in ("HeroHair","FrontierGreyHair","IdentityBeard"):c=tuple(.50+.50*x for x in c[:3])+(1,)
                tint(mat,c);coloured.add(mat.name)
    # Freeze imported rest pose. No arbitrary action track is allowed to
    # replace the source's rest pose during this morphology review.
    rigs=[o for o in bpy.context.scene.objects if o.type=="ARMATURE"]
    for arm in rigs:
        if arm.animation_data:arm.animation_data_clear()
        for bone in arm.pose.bones:bone.matrix_basis.identity()
    bpy.context.view_layer.update()
    points=[o.matrix_world@Vector(c) for o in meshes if not o.hide_render and not any(x in o.name.lower() for x in ("signum","shield","weapon","spear","blade")) for c in o.bound_box]
    if not points:raise ValueError("no visible anatomy")
    lo=Vector(tuple(min(p[i] for p in points) for i in range(3)));hi=Vector(tuple(max(p[i] for p in points) for i in range(3)))
    height=hi.z-lo.z
    if not .2<height<3.5:raise ValueError("unexpected source bounds")
    center=(lo+hi)/2
    scene,cam=setup_studio(center,height)
    target=Vector((center.x,center.y,lo.z+height*.55))
    head=Vector((center.x,center.y,lo.z+height*.88))
    for arm in rigs:
        b=arm.pose.bones.get("Head")
        if b:head=arm.matrix_world@b.head+Vector((0,0,height*.055));break
    captures={}
    for kind,target,scale,res,offset in [
        ("full",target,height*1.13,(300,430),Vector((.14,-3,.09))),
        ("face",head,height*.35,(330,380),Vector((.16,-3,.04))),
        ("profile",head,height*.35,(330,380),Vector((2.8,-.85,.04)))]:
        cam.location=target+offset*height;cam.rotation_euler=(target-cam.location).to_track_quat("-Z","Y").to_euler();cam.data.ortho_scale=scale
        scene.render.resolution_x,scene.render.resolution_y=res
        dst=out/(entry["id"]+"-"+kind+".jpg");scene.render.filepath=str(dst);bpy.ops.render.render(write_still=True)
        if not dst.exists() or dst.stat().st_size<1000:raise ValueError("missing rendered frame")
        captures[kind]={"file":dst.name,"sha256":hashlib.sha256(dst.read_bytes()).hexdigest()}
    return {"id":entry["id"],"role":entry.get("role",""),"look_age":entry.get("look_age"),"source":source.name,"model_family":entry.get("model_family"),
            "source_sha256":hashlib.sha256(source.read_bytes()).hexdigest(),"armatures":len(rigs),
            "triangles":sum(len(o.data.loop_triangles) for o in meshes),"visible_parts":parts,
            "applied_shape_controls":sorted(applied),"unsupported_authored_face_controls":sorted(set(face)-applied),
            "captures":captures}

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--catalog",type=Path,required=True);ap.add_argument("--models",type=Path,required=True)
    ap.add_argument("--output",type=Path,required=True);ap.add_argument("--only",nargs="*")
    a=ap.parse_args(sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else [])
    text=a.catalog.read_text(encoding="utf-8")
    people=literal(text,"PEOPLE");dyes=literal(text,"DYES");hairs=literal(text,"HAIR")
    roster=[]
    for id,entry in people.items():
        data={**entry,"id":id,"file":f'frontier_{entry["kind"]}_0.glb'}
        if id in ("julia","silvanus"):
            # VillagePerson selects a dedicated parent only if all four tiers are installed.
            dedicated=all((a.models/f"frontier_parent_{id}_{tier}.glb").is_file() for tier in range(4))
            family=f"parent_{id}" if dedicated else entry["kind"]
            if not all((a.models/f"frontier_{family}_{tier}.glb").is_file() for tier in range(4)):
                raise ValueError(f"{id}: no complete parent or civilian LOD family")
            data.update(file=f"frontier_{family}_0.glb",model_family=family)
        if id=="sextus":data.update(file="unit_legacy_blacksmith_0.glb",original_owner_asset=True)
        if id=="vibius":data.update(file="unit_legacy_tunic_villager_0.glb",original_owner_asset=True)
        roster.append(data)
    roster.extend([{"id":"severus","role":"Wachausbilder","file":"unit_roman_signifer_0.glb","original_owner_asset":True},
                   {"id":"player","role":"Originaljunge – geriggte Quelle","look_age":12,"file":"hero_meshy_italia_0.glb","original_owner_asset":True},
                   {"id":"marcus","role":"Jugendfreund","look_age":12,"file":"marcus_quality_0.glb","original_owner_asset":True}])
    a.output.mkdir(parents=True,exist_ok=True)
    report={"scope":"Blender source anatomy and material review; not Godot shaders or actual runtime pose","blender":bpy.app.version_string,
            "roster_count":len(roster),"rows":[]}
    for entry in roster:
        if a.only and entry["id"] not in a.only:continue
        p=a.models/entry["file"]
        try:r=render_one(entry,p,a.output,dyes,hairs)
        except Exception as e:r={"id":entry["id"],"source":entry["file"],"error":str(e)}
        report["rows"].append(r);(a.output/"review.json").write_text(json.dumps(report,indent=2,ensure_ascii=False))
        print("CAST_REVIEW",entry["id"],"ERROR "+r["error"] if "error" in r else "RENDERED",flush=True)
    print("CAST_REVIEW_DONE",sum("captures" in r for r in report["rows"]),"/",len(report["rows"]),flush=True)
    if any("error" in r for r in report["rows"]):raise SystemExit(1)

if __name__=="__main__":main()

