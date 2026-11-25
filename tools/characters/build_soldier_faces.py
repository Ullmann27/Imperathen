"""Author twenty adult soldier identities from the vendored anatomical cast.

Run with Blender 4.3+: blender -b -t 4 -P tools/characters/build_soldier_faces.py
All modelling, portraits and glTF exports are generated locally. Source anatomy,
UVs, company skeleton and animation clips retain their existing provenance.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import math
import random
import sys
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / "art/soldier_faces"
OUT = ROOT / "prototype/assets/characters/soldier_face_variants"
SOURCE = ROOT / "art/frontier_people/legionary.blend"
HERO = ROOT / "art/hero_quality/hero.blend"


def load_module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


hero = load_module("soldier_face_hero", ROOT / "tools/characters/build_hero.py")

# Values describe bounded geometric edits in metres, except relative widths.
# Names identify fictional cast members, not portraits of historical people.
PROFILES = [
    ("Lucius", 21, "crop", "clean", "brown", "light", -.07, -.004, -.004, -.08, .002, -.001, -.05, .000),
    ("Marcus", 32, "part", "short", "black", "olive", .12, .003, .006, .06, -.002, .003, .03, .001),
    ("Titus", 28, "curl", "clean", "dark", "tan", -.04, .006, .003, .11, .004, .002, -.02, -.001),
    ("Gaius", 43, "receding", "moustache", "brown", "light", .08, -.003, .009, -.06, -.004, .004, .07, .002),
    ("Publius", 54, "bald", "full", "grey", "tan", .10, .005, .007, .09, -.005, .003, -.04, -.001),
    ("Quintus", 24, "sweep", "clean", "auburn", "warm", -.11, .002, -.003, -.08, .004, -.002, .05, .001),
    ("Decimus", 36, "crop", "stubble", "dark", "olive", .15, -.002, .002, .10, .003, .004, -.06, -.002),
    ("Aulus", 47, "temples", "goatee", "salt", "light", -.07, .007, .008, -.04, -.006, .002, .04, .001),
    ("Sextus", 30, "wave", "short", "brown", "warm", .02, -.006, -.003, .08, .004, -.001, .08, -.002),
    ("Servius", 39, "curl", "full", "black", "deep", .13, .003, .000, .14, .001, .004, -.03, .001),
    ("Flavius", 22, "part", "clean", "fair", "light", -.09, -.003, -.006, -.06, .003, -.002, .04, -.001),
    ("Cassius", 41, "bald", "stubble", "dark", "olive", .11, .006, .007, .07, -.006, .003, -.05, .002),
    ("Varus", 57, "receding", "short", "grey", "warm", -.03, .005, .009, -.02, -.007, .004, .03, -.002),
    ("Felix", 26, "sweep", "moustache", "black", "tan", -.06, -.002, .003, .05, .004, -.001, .06, .001),
    ("Rufus", 35, "wave", "full", "auburn", "warm", .10, -.005, -.002, .08, .001, .002, -.03, -.001),
    ("Sabinus", 45, "temples", "clean", "salt", "olive", -.10, .006, .008, -.07, -.005, .003, .02, .002),
    ("Valens", 29, "crop", "chin", "brown", "tan", .14, .002, -.003, .12, .005, .002, -.05, -.002),
    ("Nerva", 51, "part", "goatee", "salt", "light", -.08, .007, .006, -.05, -.006, .004, .07, .001),
    ("Faustus", 33, "curl", "stubble", "dark", "deep", .05, -.004, .004, .13, .003, .001, -.02, -.001),
    ("Longinus", 38, "sweep", "short", "black", "olive", -.12, .008, .009, -.06, -.002, .003, .03, .002),
]
FIELDS = ("name", "age", "hair", "beard", "hair_colour", "skin", "jaw_width", "chin_length", "nose_length", "nose_width", "cheeks", "brow", "mouth_width", "eye_spacing")
SKIN = {"light": (1.00, .98, .96), "warm": (.94, .86, .78), "olive": (.82, .72, .61), "tan": (.76, .63, .50), "deep": (.51, .40, .29)}
HAIR = {"brown": (.070, .037, .019), "black": (.014, .011, .009), "dark": (.026, .019, .014), "auburn": (.15, .047, .016), "fair": (.28, .19, .09), "grey": (.27, .27, .25), "salt": (.12, .115, .10)}


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def smooth(a, b, x):
    t = max(0.0, min(1.0, (x-a)/(b-a)))
    return t*t*(3-2*t)


def face_position(p, profile):
    """Localized anatomy edits; shoulders, rest joints and stature stay intact."""
    x, y, z = p
    if z < 1.445:
        return p.copy()
    front = 1-smooth(-.075, .025, y)
    jaw = math.exp(-((z-1.498)/.043)**2) * front
    mid = math.exp(-((z-1.561)/.034)**2) * front
    nose = math.exp(-(x/.024)**2-((z-1.554)/.029)**2) * front
    cheek = math.exp(-((abs(x)-.051)/.024)**2-((z-1.559)/.033)**2) * front
    brow = math.exp(-((abs(x)-.031)/.032)**2-((z-1.609)/.013)**2) * front
    mouth = math.exp(-(x/.043)**2-((z-1.520)/.020)**2) * front
    chin = math.exp(-(x/.046)**2-((z-1.484)/.027)**2) * front
    orbit = math.exp(-((abs(x)-.032)/.025)**2-((z-1.593)/.024)**2) * front
    age = max(0., (profile["age"]-28)/35)
    nx = x * (1+profile["jaw_width"]*jaw + profile["nose_width"]*nose + profile["mouth_width"]*mouth)
    nx += (1 if x >= 0 else -1)*profile["eye_spacing"]*orbit
    ny = y-profile["nose_length"]*nose-profile["cheeks"]*cheek-profile["brow"]*brow
    # Ageing includes cheek hollowing, a softer jaw and infraorbital relief.
    ny += age*.0028*math.exp(-((abs(x)-.045)/.021)**2-((z-1.540)/.019)**2)*front
    ny -= age*.0015*math.exp(-((abs(x)-.034)/.025)**2-((z-1.577)/.008)**2)*front
    nz = z-profile["chin_length"]*chin-age*.0022*jaw
    nz -= age*.0013*cheek
    return Vector((nx, ny, nz))


def deform(obj, profile):
    blocks = list(obj.data.shape_keys.key_blocks) if obj.data.shape_keys else []
    if blocks:
        # Apply the same smooth map to Basis and facial expressions, retaining
        # the original blink/jaw/smile deltas in the new facial proportions.
        for block in blocks:
            for v in block.data:
                v.co = face_position(v.co, profile)
        for i, v in enumerate(obj.data.vertices):
            v.co = blocks[0].data[i].co
    else:
        for v in obj.data.vertices:
            v.co = face_position(v.co, profile)
    obj.data.update()


def delete_kit_head_parts(kit):
    groups = {g.index for g in kit.vertex_groups if g.name in ("Kit.Helmet", "Kit.Face")}
    indices = {v.index for v in kit.data.vertices if any(g.group in groups and g.weight>.5 for g in v.groups)}
    bm = bmesh.new(); bm.from_mesh(kit.data); bm.verts.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[bm.verts[i] for i in indices], context="VERTS")
    bm.to_mesh(kit.data); bm.free(); kit.data.update()


def set_image(name, values):
    h, w, _ = values.shape
    image = bpy.data.images.new(name, width=w, height=h)
    image.pixels.foreach_set(values.astype(np.float32).ravel())
    image.pack()
    return image


def prepare_materials():
    base = bpy.data.materials["FrontierSkin"]
    shader = base.node_tree.nodes.get("Principled BSDF")
    image_node = next(link.from_node for link in base.node_tree.links if link.to_socket == shader.inputs["Base Color"])
    source = image_node.image
    source.scale(1024, 1024); source.pack()
    pixels = np.asarray(source.pixels[:]).reshape(1024,1024,4)
    skins = {}
    for name, tint in SKIN.items():
        material = base.copy(); material.name = "SoldierSkin_"+name
        image = set_image("SoldierSkin_"+name+"_albedo", np.concatenate((np.clip(pixels[:,:,:3]*np.array(tint),0,1),pixels[:,:,3:4]),axis=2))
        material.node_tree.nodes.get(image_node.name).image = image
        material.node_tree.nodes.get("Principled BSDF").inputs["Roughness"].default_value = .52
        skins[name] = material
    hairs = {}
    for name, color in HAIR.items():
        material = bpy.data.materials.new("SoldierHair_"+name); material.use_nodes=True
        shader = material.node_tree.nodes.get("Principled BSDF")
        shader.inputs["Base Color"].default_value = (*color,1)
        shader.inputs["Roughness"].default_value = .76
        # Fine surface detail remains secondary to actual cap and strand meshes.
        noise = material.node_tree.nodes.new("ShaderNodeTexNoise"); noise.inputs["Scale"].default_value=360
        bump = material.node_tree.nodes.new("ShaderNodeBump"); bump.inputs["Strength"].default_value=.20; bump.inputs["Distance"].default_value=.0013
        material.node_tree.links.new(noise.outputs["Fac"],bump.inputs["Height"])
        material.node_tree.links.new(bump.outputs["Normal"],shader.inputs["Normal"])
        hairs[name]=material
    for image in bpy.data.images:
        if image.size[0] and max(image.size)>1024:
            f=1024/max(image.size); image.scale(round(image.size[0]*f),round(image.size[1]*f)); image.pack()
    return skins, hairs


def append_hair_template():
    with bpy.data.libraries.load(str(HERO), link=False) as (_, target):
        target.objects=["HeroRig", "HeroHair"]
    arm, hair = target.objects
    head = arm.data.bones["Head"].head_local.copy()
    transform=Matrix.Translation((0,0,1.46)) @ Matrix.Scale(1.18,4) @ Matrix.Translation(-head)
    mature = hair.data.shape_keys.key_blocks["Mature"]
    values=[transform @ v.co for v in mature.data]
    hair.shape_key_clear()
    for vertex, p in zip(hair.data.vertices, values): vertex.co=p
    hair.parent=None
    for group in list(hair.vertex_groups): hair.vertex_groups.remove(group)
    for mod in list(hair.modifiers): hair.modifiers.remove(mod)
    hair.name="SoldierHairSource"
    bpy.data.objects.remove(arm, do_unlink=True)
    return hair


def patch_from_body(name, body, rig, material, predicate, offset, chin_drop=0.):
    """A fitted surface patch retaining every source face-expression delta."""
    chosen=[]
    for face in body.data.polygons:
        point=sum((body.data.vertices[i].co for i in face.vertices),Vector())/len(face.vertices)
        if predicate(point): chosen.append(tuple(face.vertices))
    indices=sorted({i for face in chosen for i in face})
    if not indices: return None
    remap={old:new for new,old in enumerate(indices)}
    points=[]
    for i in indices:
        v=body.data.vertices[i]
        point=v.co+v.normal*offset
        point.z-=chin_drop*math.exp(-((point.z-1.483)/.030)**2)
        points.append(point)
    obj=hero.mesh_object(name,points,[tuple(remap[i]for i in face)for face in chosen],material=material)
    hero.bind(obj,rig,[{"Head":1.0}for _ in points])
    if body.data.shape_keys:
        obj.shape_key_add(name="Basis")
        for source in list(body.data.shape_keys.key_blocks)[1:]:
            key=obj.shape_key_add(name=source.name)
            for i,original in enumerate(indices):
                key.data[i].co=points[i]+source.data[original].co-body.data.vertices[original].co
    return obj


def make_hair(profile, body, rig, template, material, seed):
    style=profile["hair"]
    if style=="bald": return []
    result=[]
    if style in ("part","sweep","wave"):
        hair=template.copy(); hair.data=template.data.copy()
        bpy.context.collection.objects.link(hair)
        hair.name="Hair_"+style
        for v in hair.data.vertices:
            p=face_position(v.co,profile)
            top=smooth(1.63,1.72,p.z)
            if style=="part":
                p.x+=.011*top; p.z+=.002*math.sin(p.x*80)*top
            elif style=="sweep":
                p.x-=.008*top; p.y+=.007*top; p.z+=.006*top
            else:
                p.z+=.0035*math.sin(p.x*130+p.y*60)*top
                p.y-=.003*top
            v.co=p
        hair.data.materials.clear(); hair.data.materials.append(material)
        hero.bind(hair,rig,[{"Head":1.}for _ in hair.data.vertices]); result.append(hair)
        return result
    def scalp(p):
        x,y,z=p
        if z<1.57: return False
        front=1-smooth(-.12,-.025,y)
        line=1.585+.062*front
        # Different front/temple lines expose actual forehead and scalp.
        if style=="receding": line+=.038*front+.010*math.exp(-((abs(x)-.058)/.020)**2)
        if style=="temples": line+=.026*front*math.exp(-((abs(x)-.047)/.028)**2)
        return z>line
    cap=patch_from_body("Hair_"+style,body,rig,material,scalp,.0015 if style=="crop" else .0025)
    result.append(cap)
    if style=="curl":
        # Small separate curls alter the silhouette and remain skinned to Head.
        rng=random.Random(seed)
        candidates=[v for v in cap.data.vertices if v.normal.z>.10 or v.co.y<-.02]
        rng.shuffle(candidates)
        samples=[]
        for v in candidates:
            if all((v.co-p).length>.010 for p in samples): samples.append(v.co.copy())
            if len(samples)>=110: break
        bm=bmesh.new()
        for p in samples:
            sphere=bmesh.ops.create_icosphere(bm,subdivisions=1,radius=1)
            radius=rng.uniform(.004,.0068)
            for v in sphere["verts"]:v.co=Vector((v.co.x*radius,v.co.y*radius,v.co.z*radius*.82))+p
        mesh=bpy.data.meshes.new("CurlClusters");bm.to_mesh(mesh);bm.free()
        curls=bpy.data.objects.new("Hair_curls",mesh);bpy.context.collection.objects.link(curls)
        mesh.materials.append(material)
        for face in mesh.polygons:face.use_smooth=True
        hero.bind(curls,rig,[{"Head":1.}for _ in mesh.vertices]);result.append(curls)
    return result


def make_beard(profile,body,rig,material):
    kind=profile["beard"]
    if kind=="clean":return []
    def area(p):
        x,y,z=p; ax=abs(x)
        if y>-.052 or ax>.083:return False
        moustache=1.527<z<1.539 and ax<.037
        chin=1.474<z<1.504 and ax<(.025 if kind in ("chin","goatee") else .065)
        sides=1.485<z<1.569 and ax>.032 and y<-.065
        sideburn=1.54<z<1.613 and .060<ax<.085 and y<-.045
        if kind=="moustache":return moustache
        if kind=="chin":return chin
        if kind=="goatee":return moustache or chin
        return moustache or chin or sides or sideburn
    thickness={"stubble":.0006,"short":.0025,"full":.005,"moustache":.0018,"chin":.0022,"goatee":.003}[kind]
    obj=patch_from_body("Beard_"+kind,body,rig,material,area,thickness,.009 if kind=="full" else 0.)
    return [obj] if obj else []


def clone_soldier(source_objects,source_arm,index,profile,skins,hairs,hair_template):
    collection=bpy.data.collections.new(f"{index:02d}_{profile['name']}")
    bpy.context.scene.collection.children.link(collection)
    rig=source_arm.copy();rig.data=source_arm.data.copy();rig.name=f"Soldier_{index:02d}_Rig"
    collection.objects.link(rig)
    meshes=[]
    for obj in source_objects:
        if obj.type!="MESH":continue
        clone=obj.copy();clone.name=f"S{index:02d}_"+obj.name
        if obj.name in ("HeroBody","HeroEyes"):
            clone.data=obj.data.copy();deform(clone,profile)
        collection.objects.link(clone);clone.parent=rig;clone.matrix_parent_inverse=Matrix.Identity(4)
        for modifier in clone.modifiers:
            if modifier.type=="ARMATURE":modifier.object=rig
        if obj.name=="HeroBody":
            body=clone;clone.data.materials.clear();clone.data.materials.append(skins[profile["skin"]])
        meshes.append(clone)
    additions=make_hair(profile,body,rig,hair_template,hairs[profile["hair_colour"]],index*1987)
    additions+=make_beard(profile,body,rig,hairs[profile["hair_colour"]])
    for obj in additions:
        for parent in list(obj.users_collection):parent.objects.unlink(obj)
        collection.objects.link(obj);obj.name=f"S{index:02d}_"+obj.name
    meshes+=additions
    rig["cast_name"]=profile["name"];rig["authored_age"]=profile["age"]
    rig["source_anatomy"]="art/frontier_people/legionary.blend"
    collection["profile_json"]=json.dumps(profile,ensure_ascii=False)
    return {"id":index,"profile":profile,"collection":collection,"rig":rig,"meshes":meshes,"body":body}


def scene_setup():
    camera=hero.setup_scene();scene=bpy.context.scene
    scene.render.threads_mode="FIXED";scene.render.threads=4
    scene.cycles.samples=32;scene.cycles.use_denoising=True
    scene.render.resolution_x=480;scene.render.resolution_y=600
    scene.render.image_settings.file_format="PNG"
    scene.render.film_transparent=False
    scene.world.node_tree.nodes.get("Background").inputs[0].default_value=(.055,.071,.085,1)
    scene.world.node_tree.nodes.get("Background").inputs[1].default_value=.38
    hero.camera_at(camera,(.19,-1.03,1.69),(0,-.04,1.59),92)
    return camera


def visible(cast,index):
    for member in cast:
        for obj in [member["rig"],*member["meshes"]]:
            obj.hide_render=member["id"]!=index
            obj.hide_set(False)


def export(member,path):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in [member["rig"],*member["meshes"]]:obj.select_set(True)
    bpy.context.view_layer.objects.active=member["rig"]
    bpy.ops.export_scene.gltf(filepath=str(path),export_format="GLB",use_selection=True,
        export_animation_mode="NLA_TRACKS",export_force_sampling=True,export_frame_step=1,
        export_animations=True,export_morph=True,export_morph_animation=False,export_def_bones=False)


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--ids",nargs="+",type=int,default=list(range(1,21)))
    parser.add_argument("--preview-dir",type=Path)
    parser.add_argument("--no-render",action="store_true")
    parser.add_argument("--no-export",action="store_true")
    args=parser.parse_args(sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else [])
    art=args.preview_dir or ART
    art.mkdir(parents=True,exist_ok=True);(art/"portraits").mkdir(exist_ok=True)
    OUT.mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    for obj in list(bpy.context.scene.objects):
        if obj.type not in ("MESH","ARMATURE"):bpy.data.objects.remove(obj,do_unlink=True)
    source_arm=bpy.data.objects["FrontierRig"]
    source=list(bpy.context.scene.objects)
    delete_kit_head_parts(bpy.data.objects["FrontierRomanKit"])
    skins,hairs=prepare_materials();hair_template=append_hair_template()
    cast=[]
    for index in args.ids:
        profile=dict(zip(FIELDS,PROFILES[index-1]))
        cast.append(clone_soldier(source,source_arm,index,profile,skins,hairs,hair_template))
        print("SOLDIER_AUTHORED",index,profile["name"],flush=True)
    for obj in source:bpy.data.objects.remove(obj,do_unlink=True)
    bpy.data.objects.remove(hair_template,do_unlink=True)
    bpy.context.scene.frame_set(0)
    camera=scene_setup()
    records=[]
    for member in cast:
        visible(cast,member["id"])
        if not args.no_render:
            bpy.context.scene.render.filepath=str(art/"portraits"/f"soldier_{member['id']:02d}.png")
            bpy.ops.render.render(write_still=True)
        path=OUT/f"soldier_face_{member['id']:02d}.glb"
        if not args.no_export:export(member,path)
        body=member["body"]
        face_vertices=[tuple(v.co) for v in body.data.vertices if v.co.z>1.45]
        count=0
        for obj in member["meshes"]:obj.data.calc_loop_triangles();count+=len(obj.data.loop_triangles)
        records.append({"id":member["id"],**member["profile"],"triangles":count,
            "head_geometry_sha256":hashlib.sha256(np.asarray(face_vertices,dtype=np.float32).tobytes()).hexdigest(),
            "body_morphs":[k.name for k in body.data.shape_keys.key_blocks][1:],
            "bones":len(member["rig"].data.bones),"animation_tracks":[t.name for t in member["rig"].animation_data.nla_tracks],
            "glb":str(path.relative_to(ROOT)) if not args.no_export else None,
            "bytes":path.stat().st_size if not args.no_export else 0})
        print("SOLDIER_FINISHED",member["id"],records[-1]["bytes"],flush=True)
    # The editable scene holds all identities in separate named collections.
    for n,member in enumerate(cast):
        member["rig"].location=((n%5-2)*1.05,(n//5)*1.0,0)
        for obj in [member["rig"],*member["meshes"]]:obj.hide_render=False;obj.hide_set(False)
    hero.camera_at(camera,(5.4,-8.6,5.1),(0,1.4,1.1),44)
    bpy.context.scene.render.resolution_x=1600;bpy.context.scene.render.resolution_y=1100
    bpy.context.preferences.filepaths.save_version=0
    # Purge unused source datablocks, retaining shared textures and animation.
    bpy.ops.outliner.orphans_purge(do_recursive=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(art/"soldier_faces_20.blend"),compress=True)
    report={"generator":str(Path(__file__).relative_to(ROOT)),"blender":bpy.app.version_string,
        "source":str(SOURCE.relative_to(ROOT)),"source_sha256":sha(SOURCE),
        "source_provenance":"art/hero_quality/source/provenance.json",
        "hair_source":"art/hero_quality/source/system_assets/hair/short02",
        "count":len(records),"unique_head_geometries":len({r["head_geometry_sha256"]for r in records}),
        "profiles":records,
        "limits":["Twenty authored variants of one anatomical source; not twenty independent scans.",
            "Ages are visual character design labels, not measured biological estimates.",
            "Helmets removed so faces and hair are visible; source armour is a stylised project study.",
            "Blender procedural hair micro-bump is a render detail; glTF retains hair geometry and base colour.",
            "No physical Android performance validation is claimed."]}
    (art/"build_report.json").write_text(json.dumps(report,indent=2,ensure_ascii=False)+"\n")
    print("SOLDIER_FACES_COMPLETE",len(records),flush=True)


if __name__=="__main__":main()
