"""Build the original, metre-scaled IMPERATHEN city detail kit with Blender.

Run: blender -b -t 4 --python tools/city_detail/architecture_generate.py
The GLB is a mesh library, not a world scene: use CityArchitectureDetail to
select one module and one LOD. Existing original project material maps are reused.
"""
from __future__ import annotations

import hashlib
import json
import math
import random
import sys
from pathlib import Path

import bpy
import bmesh
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "prototype/assets/city_detail/architecture"
EVIDENCE = ROOT / "docs/26_city_support/evidence/architecture"
sys.path.insert(0, str(ROOT / "tools/art"))
from common import box, cylinder, material, mesh, reset_scene, _project_uv

MATS = {}
MODULES = {}
COLLIDERS = {}
LIBRARY = []


def setup_materials():
    specs = {
        "basalt": ((.24, .245, .235), "limestone", .95, 0),
        "stone": ((.46, .45, .39), "limestone", .89, 0),
        "plaster": ((.73, .69, .57), "plaster", .92, 0),
        "red": ((.44, .16, .105), "plaster", .91, 0),
        "wood": ((.26, .17, .09), "oak", .83, 0),
        "clay": ((.48, .23, .13), "terracotta", .87, 0),
        "linen": ((.60, .51, .35), "linen", .94, 0),
        "linen_red": ((.39, .14, .09), "linen", .94, 0),
        "bronze": ((.27, .20, .095), "bronze", .56, .65),
        "earth": ((.22, .20, .15), "earth", .96, 0),
        "bread": ((.57, .39, .17), "plaster", .94, 0),
    }
    for key, (rgb, tex, rough, metal) in specs.items():
        mat = material("CITY_" + key, rgb, roughness=rough, metallic=metal, texture=tex)
        # Preserve exported normal maps, rather than Blender-only procedural bumps.
        for node in mat.node_tree.nodes:
            if node.type == "NORMAL_MAP":
                node.inputs["Strength"].default_value = .42 if key != "linen" else .55
        MATS[key] = mat


def cube(name, pos, size, mat="stone", bevel=.018):
    return box(name, pos, size, MATS[mat], bevel)


def tube(name, points, radius, mat="wood", sides=8):
    vertices, faces = [], []
    for index, point in enumerate(points):
        point = Vector(point)
        tangent = Vector(points[min(index+1, len(points)-1)]) - Vector(points[max(index-1, 0)])
        basis = tangent.to_track_quat("Z", "Y").to_matrix()
        for j in range(sides):
            a = j * math.tau / sides
            vertices.append(point + basis @ Vector((radius*math.cos(a), radius*math.sin(a), 0)))
    for row in range(len(points)-1):
        for j in range(sides):
            a = row*sides+j
            b = row*sides+(j+1)%sides
            faces.append((a, b, b+sides, a+sides))
    faces += [tuple(reversed(range(sides))), tuple((len(points)-1)*sides+j for j in range(sides))]
    return mesh(name, vertices, faces, MATS[mat], True)


def lathe(name, profile, location, mat="clay", sides=32):
    vertices, faces = [], []
    for radius, z in profile:
        for j in range(sides):
            a = math.tau*j/sides
            vertices.append((location[0]+radius*math.cos(a), location[1]+radius*math.sin(a), location[2]+z))
    for row in range(len(profile)-1):
        for j in range(sides):
            a = row*sides+j
            b = row*sides+(j+1)%sides
            faces.append((a, b, b+sides, a+sides))
    faces.append(tuple(reversed(range(sides))))
    faces.append(tuple((len(profile)-1)*sides+j for j in range(sides)))
    obj = mesh(name, vertices, faces, MATS[mat], True)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(obj.data)
    bm.free()
    return obj


def clip_polygon(poly, a, b, c):
    result = []
    for p, q in zip(poly, poly[1:] + poly[:1]):
        dp, dq = a*p[0]+b*p[1]-c, a*q[0]+b*q[1]-c
        inside_p, inside_q = dp <= 1e-9, dq <= 1e-9
        if inside_p:
            result.append(p)
        if inside_p != inside_q:
            t = dp/(dp-dq)
            result.append((p[0]+t*(q[0]-p[0]), p[1]+t*(q[1]-p[1])))
    return result


def build_basoli():
    rng = random.Random(2601125)
    seeds = [(-2+(x+.5+rng.uniform(-.23,.23))*4/6,
              -2+(y+.5+rng.uniform(-.23,.23))*4/6) for x in range(6) for y in range(6)]
    objects = [cube("Street_bedding", (0,0,-.075), (4,4,.07), "earth", .0)]
    for index, p in enumerate(seeds):
        poly = [(-2,-2),(2,-2),(2,2),(-2,2)]
        for q in seeds:
            if q == p:
                continue
            poly = clip_polygon(poly, q[0]-p[0], q[1]-p[1], (q[0]**2+q[1]**2-p[0]**2-p[1]**2)/2)
        # 7 mm joints, large polygonal slabs; walkable top is exactly z=0.
        cx, cy = sum(x for x,y in poly)/len(poly), sum(y for x,y in poly)/len(poly)
        poly = [(x+(cx-x)*.012,y+(cy-y)*.012) for x,y in poly]
        n = len(poly)
        verts = [(x,y,-.10) for x,y in poly] + [(x,y,0) for x,y in poly]
        faces = [tuple(reversed(range(n))), tuple(range(n,2*n))]
        faces += [(j,(j+1)%n,(j+1)%n+n,j+n) for j in range(n)]
        stone = mesh(f"Basolus_{index:02d}", verts, faces, MATS["basalt"])
        mod = stone.modifiers.new("Worn stone arris", "BEVEL")
        mod.width = .013
        mod.segments = 2
        objects.append(stone)
    COLLIDERS["basoli_4m"] = [{"center":[0,-.06,0],"size":[4,.12,4]}]
    return objects


def build_curb():
    objects = []
    for i in range(8):
        x = -1.75+i*.5
        objects.append(cube(f"Kerbstone_{i}", (x,0,.08), (.493,.55,.16), "stone", .021))
        objects.append(cube(f"Footway_{i}", (x,.57,.10), (.493,.55,.20), "stone", .017))
    # The shallow open gutter is outside the kerb, not a black painted stripe.
    objects.append(cube("Gutter_bed", (0,-.36,-.03), (4,.16,.05), "basalt", .005))
    COLLIDERS["curb_4m"] = [{"center":[0,.08,0],"size":[4,.16,.55]},
                                  {"center":[0,.10,-.57],"size":[4,.20,.55]}]
    return objects


def roof_tile(x, y, z, length=.55):
    # Tegula pan with two raised edges and curved imbrex covering the joint.
    objects = [cube("Tegula_pan", (x,y,z), (.365,length,.035), "clay", .007),
               cube("Tegula_lip", (x-.179,y,z+.025), (.025,length,.07), "clay", .004)]
    points = []
    for k in range(9):
        a = math.pi*k/8
        points.append((x+.19+.073*math.cos(a), y-length/2, z+.035+.073*math.sin(a)))
    verts = points + [(px,py+length,pz) for px,py,pz in points]
    faces = [(k,k+1,k+10,k+9) for k in range(8)]
    cap = mesh("Imbrex", verts, faces, MATS["clay"], True)
    sol = cap.modifiers.new("Clay thickness", "SOLIDIFY")
    sol.thickness = .012
    objects.append(cap)
    return objects


def build_taberna():
    objects = [cube("Lime_floor", (0,0,-.035), (4,2.8,.07), "stone", .012)]
    walls = [((-1.9,0,1.5),(.2,2.8,3.0)),((1.9,0,1.5),(.2,2.8,3.0)),
             ((0,1.3,1.5),(3.8,.2,3.0)), ((-1.625,-1.3,1.5),(.55,.2,3.0)),
             ((1.625,-1.3,1.5),(.55,.2,3.0)),((0,-1.3,2.79),(2.7,.2,.42))]
    for i,(pos,size) in enumerate(walls):
        objects.append(cube(f"Lime_wall_{i}",pos,size,"plaster",.018))
    # Real stone jambs and a low threshold; the 2.5 m opening remains unobstructed.
    for x in (-1.37,1.37):
        for course in range(7):
            objects.append(cube("Stone_jamb",(x,-1.44,.18+course*.36),(.20,.23,.348),"stone",.009))
    objects.append(cube("Threshold",(0,-1.34,.018),(2.54,.38,.036),"stone",.012))
    objects.append(cube("Lintel",(0,-1.45,2.62),(2.94,.24,.17),"stone",.012))
    for x in (-1.69,1.69):
        objects.append(cube("Red_ochre_dado",(x,-1.412,.49),(.40,.016,.91),"red",.003))
        objects.append(cube("Dado_border",(x,-1.428,.975),(.41,.022,.055),"stone",.002))
    objects.append(cube("Rear_dado",(0,1.185,.49),(3.6,.017,.95),"red",.003))
    # Folded timber shutters sit beside, rather than across, the doorway.
    for side in (-1,1):
        for j in range(3):
            objects.append(cube("Shutter_plank",(side*(1.42+j*.17),-1.49,1.36),(.16,.065,2.33),"wood",.008))
        for z in (.57,2.14):
            objects.append(cube("Shutter_rail",(side*1.60,-1.535,z),(.51,.045,.075),"wood",.006))
        for z in (.50,2.20):
            for j in range(2):
                objects.append(cylinder("Bronze_pivot",(side*1.38,-1.575,z+j*.035),.014,.025,MATS["bronze"],8,(math.pi/2,0,0)))
    # Shelves and exposed ceiling beams make the open interior usable.
    for z in (.83,1.63):
        objects.append(cube("Rear_shelf",(0,.98,z),(3.45,.45,.07),"wood",.012))
    for x in (-1.50,-.75,0,.75,1.50):
        objects.append(cube("Roof_beam",(x,0,3.03),(.12,3.15,.17),"wood",.008))
    objects.append(cube("Roof_deck",(0,0,3.16),(4.36,3.22,.09),"wood",.009))
    for row in range(6):
        for col in range(12):
            objects.extend(roof_tile(-2.01+col*.365,-1.36+row*.50,3.225+row*.045))
    objects.append(cube("Fascia",(0,-1.62,3.12),(4.46,.11,.19),"wood",.008))
    # Red painted fascia and limestone trim read from the child's eye height.
    objects.append(cube("Painted_frieze",(0,-1.416,2.96),(3.80,.026,.10),"red",.004))
    COLLIDERS["taberna_4m"] = [{"center":[p[0],p[2],-p[1]],"size":[s[0],s[2],s[1]]} for p,s in walls]
    COLLIDERS["taberna_4m"] += [{"center":[0,-.035,0],"size":[4,.07,2.8]},
                                      {"center":[0,.018,1.34],"size":[2.54,.036,.38]}]
    return objects


def counter_top_ring(x, y, z):
    vertices = []
    for inner in (False,True):
        for j in range(32):
            a = math.tau*j/32
            dx,dy = math.cos(a),math.sin(a)
            r = .208 if inner else .42/max(abs(dx),abs(dy))
            vertices.append((x+r*dx,y+r*dy,z))
    return mesh("Counter_with_true_opening",vertices,[(j,(j+1)%32,(j+1)%32+32,j+32) for j in range(32)],MATS["stone"])


def build_counter():
    objects = [cube("Counter_front",(0,-.37,.47),(2.52,.10,.94),"red",.014),
               cube("Counter_back",(0,.37,.47),(2.52,.10,.94),"plaster",.014),
               cube("Counter_left",(-1.21,0,.47),(.10,.70,.94),"plaster",.014),
               cube("Counter_right",(1.21,0,.47),(.10,.70,.94),"plaster",.014),
               cube("Counter_plinth",(0,0,.055),(2.60,.89,.11),"stone",.017)]
    for x in (-.84,0,.84):
        objects.append(counter_top_ring(x,0,.97))
        profile=[(.07,.12),(.20,.18),(.29,.37),(.29,.64),(.22,.83),(.19,.97),(.215,.99),(.215,1.015),(.18,1.015),(.17,.96),(.20,.82),(.25,.62),(.25,.35),(.17,.20),(.06,.18)]
        objects.append(lathe("Inset_dolium",profile,(x,0,0),sides=40))
    for x in (-1.12,-.39,.39,1.12):
        objects.append(cube("Counter_inlay_vertical",(x,-.427,.52),(.03,.012,.67),"stone",.002))
    for z in (.18,.85):
        objects.append(cube("Counter_inlay_horizontal",(0,-.427,z),(2.30,.012,.028),"stone",.002))
    COLLIDERS["dolia_counter"] = [{"center":[0,.50,0],"size":[2.60,1.0,.89]}]
    return objects


def build_canopy():
    objects=[]
    for x in (-1.4,1.4):
        for y in (-.95,.95):
            objects.append(cube("Canopy_post",(x,y,1.32),(.095,.095,2.64),"wood",.008))
        objects.append(cube("Canopy_side_rail",(x,0,2.65),(.10,2.15,.10),"wood",.008))
    for y in (-1.02,1.02):
        objects.append(cube("Canopy_crossrail",(0,y,2.68),(3.05,.09,.09),"wood",.008))
    for stripe in range(7):
        vertices=[]
        for row in range(13):
            y=-1.1+row*2.2/12
            for side in range(2):
                x=-1.5+(stripe+side)*3/7
                z=2.73-.12*(1-(y/1.1)**2)-.018*math.sin(x*6+y*2)
                vertices.append((x,y,z))
        faces=[(j*2,j*2+1,j*2+3,j*2+2) for j in range(12)]
        cloth=mesh("Awning_weave",vertices,faces,MATS["linen_red" if stripe%2 else "linen"],True)
        mod=cloth.modifiers.new("Canvas thickness","SOLIDIFY")
        mod.thickness=.006
        objects.append(cloth)
        # Scalloped valance is geometry and follows the front fabric edge.
        verts=[(-1.5+stripe*3/7,-1.1,2.73),(-1.5+(stripe+1)*3/7,-1.1,2.73)]
        verts += [(-1.5+(stripe+u/8)*3/7,-1.1,2.54-.04*math.sin(math.pi*u/8)) for u in range(8,-1,-1)]
        objects.append(mesh("Awning_valance",verts,[tuple(range(len(verts)))],MATS["linen_red" if stripe%2 else "linen"]))
    COLLIDERS["market_canopy"]=[{"center":[x,1.32,-y],"size":[.095,2.64,.095]} for x in (-1.4,1.4) for y in (-.95,.95)]
    return objects


def amphora(x,y,height):
    profile=[(.065,0),(.09,.05),(.20,.20),(.28,.45),(.27,.64),(.18,.80),(.09,.90),(.085,1.05),(.11,1.08),(.11,1.12),(.075,1.12),(.063,1.06),(.07,.91),(.15,.79),(.23,.62),(.24,.44),(.16,.22),(.05,.08)]
    objects=[lathe("Amphora_body",[(r*height,z*height) for r,z in profile],(x,y,0),sides=32)]
    for side in (-1,1):
        points=[(x+side*.09*height,y,.99*height),(x+side*.21*height,y,1.0*height),
                (x+side*.29*height,y,.92*height),(x+side*.29*height,y,.78*height),
                (x+side*.21*height,y,.73*height)]
        objects.append(tube("Amphora_handle",points,.026*height,"clay",8))
    return objects


def build_amphorae():
    COLLIDERS["amphora_pair"]=[{"center":[-.31,.49,0],"size":[.57,.98,.57]},
                                {"center":[.32,.36,-.12],"size":[.43,.72,.43]}]
    return amphora(-.31,0,.88)+amphora(.32,.12,.64)


def loaf(x,y,z):
    vertices,faces=[],[]
    sides=48
    for ring in range(15):
        t=.035+(math.pi-.070)*ring/14
        r=.22*math.sin(t)
        for j in range(sides):
            a=math.tau*j/sides
            score=math.exp(-(math.sin(4*a)/.10)**2)*.020*max(0,math.cos(t))
            vertices.append((x+r*math.cos(a),y+r*math.sin(a),z+.095*math.cos(t)-score))
    for ring in range(14):
        for j in range(sides):
            a=ring*sides+j;b=ring*sides+(j+1)%sides
            faces.append((a,b,b+sides,a+sides))
    faces.append(tuple(reversed(range(sides))))
    faces.append(tuple(14*sides+j for j in range(sides)))
    return mesh("Scored_bread",vertices,faces,MATS["bread"],True)


def build_bread():
    objects=[cube("Bread_board",(0,0,.04),(1.05,.65,.08),"wood",.018)]
    for x in (-.27,.27):
        objects.append(loaf(x,0,.18))
    COLLIDERS["bread_display"]=[]
    return objects


def finalize_module(name,objects,index):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
        bpy.context.view_layer.objects.active=obj
        for mod in list(obj.modifiers):
            bpy.ops.object.modifier_apply(modifier=mod.name)
        _project_uv(obj,overwrite=True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.object.join()
    base=bpy.context.object
    bpy.context.scene.cursor.location=(0,0,0)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
    levels=[]
    for lod,ratio in enumerate((1.0,.52,.22)):
        obj=base if lod==0 else base.copy()
        if lod:
            obj.data=base.data.copy()
            bpy.context.collection.objects.link(obj)
            bpy.context.view_layer.objects.active=obj
            dec=obj.modifiers.new("Measured far-distance reduction","DECIMATE")
            dec.ratio=ratio
            bpy.ops.object.modifier_apply(modifier=dec.name)
        obj.name=f"{name}_lod{lod}"
        bpy.context.view_layer.objects.active=obj
        tri=obj.modifiers.new("Portable triangles","TRIANGULATE")
        bpy.ops.object.modifier_apply(modifier=tri.name)
        obj.data.calc_loop_triangles()
        bounds=[list(min(v.co[a] for v in obj.data.vertices) for a in range(3)),
                list(max(v.co[a] for v in obj.data.vertices) for a in range(3))]
        levels.append({"node":obj.name,"triangles":len(obj.data.loop_triangles),"vertices":len(obj.data.vertices),
                       "surfaces":len(obj.data.materials),"bounds_blender_z_up":bounds})
        obj.location=(index*6,lod*5,0)
        LIBRARY.append(obj)
    MODULES[name]={"lods":levels,"collision_boxes_godot":COLLIDERS[name],
                   "origin":"ground centre; front +Z in Godot"}


def build_showcase():
    for obj in LIBRARY:
        obj.hide_render=True
    def instance(module,pos):
        source=next(o for o in LIBRARY if o.name==module+"_lod0")
        obj=source.copy();obj.data=source.data
        bpy.context.collection.objects.link(obj)
        obj.name="Review_"+module
        obj.location=pos;obj.hide_render=False
        return obj
    for x in (-4,0,4):
        for y in (-3,1):
            instance("basoli_4m",(x,y,0))
    instance("taberna_4m",(0,1,.0))
    instance("curb_4m",(0,-.62,0))
    instance("dolia_counter",(0,.55,.0))
    instance("amphora_pair",(-2.7,.5,.0))
    instance("market_canopy",(4.2,.8,.0))
    cube("Review_market_table",(4.2,.7,.8),(2.4,.85,.10),"wood",.015)
    instance("bread_display",(4.2,.7,.85))
    instance("amphora_pair",(5.2,.7,0))
    # Scale marker is clearly a measuring pole, not an alleged finished child.
    cube("Review_1_50m_measure",(-3.4,-1, .75),(.035,.035,1.50),"wood",.002)
    for h in (.5,1.0,1.5):
        cube("Review_measure_tick",(-3.4,-1,h),(.15,.045,.018),"red",.001)
    scene=bpy.context.scene
    scene.render.engine="CYCLES"
    scene.cycles.samples=64
    # The available Blender build has no OpenImageDenoise; use actual samples.
    scene.cycles.use_denoising=False
    scene.render.threads_mode="FIXED";scene.render.threads=4
    scene.render.resolution_x=1440;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
    scene.world.use_nodes=True
    scene.world.node_tree.nodes["Background"].inputs["Color"].default_value=(.49,.64,.80,1)
    scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value=.45
    bpy.ops.object.light_add(type="SUN",location=(3,-5,8))
    sun=bpy.context.object;sun.rotation_euler=(.45,-.50,-.35)
    sun.data.energy=2.4;sun.data.angle=math.radians(6)
    bpy.ops.object.light_add(type="AREA",location=(-2,-4,6))
    area=bpy.context.object;area.data.energy=450;area.data.shape="DISK";area.data.size=6
    area.rotation_euler=(Vector((0,0,1))-area.location).to_track_quat("-Z","Y").to_euler()
    bpy.ops.object.camera_add(location=(8.8,-10.2,7.0))
    camera=bpy.context.object;scene.camera=camera
    camera.data.lens=46
    camera.rotation_euler=(Vector((.7,.2,1.1))-camera.location).to_track_quat("-Z","Y").to_euler()
    scene.view_settings.view_transform="AgX"
    return camera


def main():
    OUT.mkdir(parents=True,exist_ok=True);EVIDENCE.mkdir(parents=True,exist_ok=True)
    reset_scene();setup_materials()
    builders={"basoli_4m":build_basoli,"curb_4m":build_curb,"taberna_4m":build_taberna,
              "dolia_counter":build_counter,"market_canopy":build_canopy,
              "amphora_pair":build_amphorae,"bread_display":build_bread}
    for index,(name,builder) in enumerate(builders.items()):
        finalize_module(name,builder(),index)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in LIBRARY: obj.select_set(True)
    library_path=OUT/"city_architecture_library.glb"
    bpy.ops.export_scene.gltf(filepath=str(library_path),export_format="GLB",use_selection=True,
                             export_yup=True,export_apply=True,export_texcoords=True,export_normals=True,
                             export_tangents=True,export_animations=False,export_extras=True)
    manifest={"version":1,"unit":"metre","front_godot":"+Z","up_godot":"+Y",
              "library":"res://assets/city_detail/architecture/city_architecture_library.glb",
              "source":"tools/city_detail/architecture_generate.py","blender":bpy.app.version_string,
              "historical_status":"Original, historically inspired review kit; not a surveyed reconstruction of Aquileia in 58 BC.",
              "material_source":"Original existing project maps: tools/art/generate_materials.py; 512px maps repeat per metre.",
              "normal_maps":"glTF tangent normals, +Y","sha256":hashlib.sha256(library_path.read_bytes()).hexdigest(),
              "bytes":library_path.stat().st_size,"modules":MODULES,
              "sources":["https://www.parcoarcheologicoappiaantica.it/luoghi/via-appia-antica/via-latina-parco-degli-acquedotti/",
                         "https://pompeiisites.org/en/press-releases/from-the-12th-august-the-thermopolium-of-regio-v-is-opening-to-the-public/"]}
    (OUT/"architecture_manifest.json").write_text(json.dumps(manifest,indent=2)+"\n",encoding="utf-8")
    camera=build_showcase()
    bpy.ops.file.pack_all();bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/"tools/city_detail/architecture_source.blend"),compress=True)
    views=[("architecture_overview",(8.8,-10.2,7.0),(.7,.2,1.1),46),
           ("architecture_eye_level",(4.9,-7.3,1.5),(.6,.6,1.25),42),
           ("architecture_counter_close",(2.65,-2.65,2.35),(0,.55,.75),48)]
    for name,position,target,lens in views:
        camera.location=position;camera.data.lens=lens
        camera.rotation_euler=(Vector(target)-camera.location).to_track_quat("-Z","Y").to_euler()
        bpy.context.scene.render.filepath=str(EVIDENCE/(name+".png"))
        bpy.ops.render.render(write_still=True)
    print("CITY_ARCHITECTURE_GENERATED "+json.dumps({"modules":len(MODULES),"lod_meshes":len(LIBRARY),"bytes":manifest["bytes"],"sha256":manifest["sha256"]}))


if __name__=="__main__": main()
