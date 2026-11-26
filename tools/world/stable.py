"""Original open Roman horse yard. Blender X = Godot X, +Y = depth into yard, Z = height."""
from pathlib import Path
from tempfile import TemporaryDirectory
import json
import math
import random
import struct
import sys

import bpy
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/"prototype/assets/roman_quarter/stable"
SHARED=ROOT/"prototype/assets/village"
sys.path[:0]=[str(ROOT/"art/village"),str(ROOT/"art/architecture")]
from build_props import attach_material, basket, revolved
from build_atrium import Domus, box_between


def wall(g,x,y,w,d,h):
    g.box(x,y,.02,w,d,h-.02,"intonaco")
    g.box(x,y,.07,w+.027,d+.027,min(h*.4,.53),"oxide")
    g.box(x,y,.527,w+.033,d+.033,.028,"ochre")
    g.box(x,y,.01,w+.050,d+.050,.13,"tuff")
    g.box(x,y,h-.04,w+.09,d+.09,.093,"traver")


def courtyard(g):
    # The two low street wings frame a clear 2.66 m entrance.
    for side in [-1,1]:
        wall(g,side*2.58,.13,2.23,.25,1.03)
        wall(g,side*3.64,1.84,.23,3.59,1.37)
        x=side*1.48
        g.box(x,.15,0,.36,.38,1.58,"tuff")
        for h in (.15,.49,.84,1.19):
            g.box(x,.15,h,.365,.386,.317,"traver")
        g.box(x,.15,1.54,.415,.425,.084,"traver")
        # Two vertically boarded gates fold back toward the small street wings.
        for j in range(8):
            g.box(side*(1.77+j*.151),.34,.13,.142,.077,1.21,"cedar" if j%3 else "beam")
        for h in (.29,1.15):
            g.box(side*2.28,.284,h,1.25,.061,.085,"beam")
            g.box(side*1.79,.248,h,.51,.023,.034,"iron")
            for dx in (0,.16):
                g.beam((side*(1.68+dx),.232,h+.018),(side*(1.68+dx),.246,h+.018),.022,"bronze",8)
        box_between(g,(side*1.75,.278,.34),(side*2.80,.278,1.15),.072,.063,"cedar")
    # A pair of limestone wear strips at the threshold; no raised sill.
    for j in range(5):
        g.box(-1.02+j*.51,.22,.0,.50,.50,.023,"traver" if j%3 else "tuff")
    # Simple painted stable sign with a horse head in profile.
    for x in (-3.36,-2.43):
        g.box(x,.15,.94,.085,.088,.87,"cedar")
    g.box(-2.895,.112,1.37,1.14,.091,.54,"beam")
    g.box(-2.895,.054,1.402,1.072,.034,.476,"oxide")
    contour=[(-.39,-.158),(-.21,-.047),(-.12,.082),(.022,.116),(.092,.221),
             (.128,.216),(.118,.117),(.177,.183),(.199,.161),(.176,.083),
             (.275,.029),(.337,-.041),(.320,-.077),(.259,-.100),(.115,-.034),
             (.037,-.057),(-.004,-.174)]
    g.prism([(-2.895+x,.031,1.65+h) for x,h in contour],(0,-.015,0),"lime")
    for dx in (-.48,.48):
        g.beam((-2.895+dx,.026,1.65),(-2.895+dx,.012,1.65),.022,"bronze",8)


def shed(g):
    for s in (-1,1):
        wall(g,s*3.65,5.34,.23,3.91,2.04)
        for row in range(2):
            for i in range(7):
                g.box(s*3.65,3.57+i*.566,.026+row*.156,.295,.548,.144,
                      "traver" if (row+i)%4==0 else "tuff")
    wall(g,0,7.16,7.52,.28,3.41)
    for x in (-3.54,0,3.54):
        for y,h in ((3.64,2.80),(7.03,3.57)):
            g.box(x,y,0,.295,.30,.25,"tuff")
            g.box(x,y,.239,.191,.19,h-.21,"cedar")
            for side in [-1,1]:
                if abs(x+side*.54)<3.55:
                    box_between(g,(x,y,h-.59),(x+side*.52,y,h-.10),.108,.093,"beam")
    g.box(0,3.64,2.77,7.40,.20,.18,"beam")
    g.box(0,7.03,3.52,7.40,.18,.17,"beam")
    for x in [-3.64,-3.06,-2.45,-1.84,-1.23,-.62,0,.62,1.23,1.84,2.45,3.06,3.64]:
        box_between(g,(x,3.26,2.87),(x,7.41,3.81),.105,.145,"cedar")
    # Dark underboards, separately overlapped pans and curved imbrices at the eaves.
    def level(y):
        return 2.918+(y-3.22)*.226
    g.prism([(-3.88,3.22,level(3.22)),(3.88,3.22,level(3.22)),
             (3.88,7.5,level(7.5)),(-3.88,7.5,level(7.5))],(0,0,-.072),"beam")
    rng=random.Random(5819)
    for row in range(7):
        low=3.21+row*.609
        high=min(7.51,low+.658)
        for col in range(18):
            x=-3.86+col*.428
            dz=rng.uniform(.008,.023)
            paint="tegula" if rng.random()<.76 else "fired"
            g.prism([(x+.021,low,level(low)+dz),(x+.407,low,level(low)+dz),
                     (x+.407,high,level(high)+.009),(x+.021,high,level(high)+.009)],
                    (0,0,-.038),paint)
            g.cover_tile((x,high,level(high)+.034),(x,low-.015,level(low)+.035+dz),.061,paint)
    # Individual roof slats visible from the open approach.
    for i in range(6):
        y=3.31+.74*i
        g.box(0,y,level(y)-.119,7.73,.11,.051,"cedar")


def partition(g):
    # Chest-high partition keeps the horses apart; both fronts remain wide open.
    for y in (3.80,5.42,6.95):
        g.box(0,y,0,.147,.15,1.46,"cedar")
        g.box(0,y,1.44,.159,.16,.054,"beam")
    for j in range(6):
        g.box(0,5.41,.10+j*.174,.096,3.21,.156,"cedar" if j%3 else "beam")
    g.box(0,5.41,1.22,.150,3.24,.13,"cedar")
    for s in (-1,1):
        # Low swing door parked along the outside wall.
        for j in range(6):
            g.box(s*3.39,3.80+j*.197,.14,.096,.185,1.06,"cedar")
        for h in (.28,1.01):
            g.box(s*3.33,4.31,h,.055,1.25,.083,"beam")
            g.box(s*3.292,3.86,h+.026,.018,.31,.037,"iron")
        for y in (4.37,5.64):
            g.ring((s*3.45,y,1.42),.083,.012,"iron",axis=(1,0,0),steps=14)
            g.beam((s*3.35,y,1.49),(s*3.59,y,1.49),.024,"iron",8)
        # Hinged wall rack above the manger, loaded with irregular loose hay.
        x=s*1.69
        for dx in (-.75,.75):
            box_between(g,(x+dx,6.83,.88),(x+dx,6.32,1.68),.074,.063,"cedar")
            box_between(g,(x+dx,6.31,1.65),(x+dx,6.94,1.65),.061,.065,"cedar")
        for j in range(9):
            dx=-.73+j*.181
            box_between(g,(x+dx,6.83,.82),(x+dx,6.34,1.62),.048,.049,"cedar")
        g.box(x,6.34,1.60,1.59,.095,.088,"beam")
        g.box(x,6.85,.83,1.59,.094,.10,"beam")
        hay(g,x,6.65,1.17,1.48,.53,.67,881+(1 if s>0 else 0))


def hay(g,cx,cy,bottom,w,d,h,seed):
    rng=random.Random(seed)
    rings=[]
    sides=18
    for z,r in ((.0,.57),(.48,.92),(.75,1.0),(.98,.77),(1.05,.37)):
        ring=[]
        for j in range(sides):
            a=j*math.tau/sides
            t=r*rng.uniform(.9,1.02)
            ring.append((cx+math.cos(a)*w*.49*t,cy+math.sin(a)*d*.49*t,bottom+h*z+rng.uniform(-.035,.034)))
        rings.append(ring)
    points=sum(rings,[])
    for row in range(len(rings)-1):
        for j in range(sides):
            a=row*sides+j
            b=row*sides+(j+1)%sides
            g.add(points,[(a,b,b+sides,a+sides)],"paving" if rng.random()<.8 else "ochre")
    g.add(points,[tuple(range(len(points)-sides,len(points)))],"paving")
    for j in range(155):
        dx=rng.uniform(-.47,.47)*w
        dy=rng.uniform(-.46,.46)*d
        edge=min(1,((dx/w)**2+(dy/d)**2)*3.0)
        top=bottom+h*(1.05-.31*edge)
        tip=(cx+dx+rng.uniform(-.075,.075),cy+dy+rng.uniform(-.15,.14),top+rng.uniform(.016,.11))
        mid=(cx+dx,cy+dy,top)
        end=(cx+dx+.048,cy+dy-.053,top-rng.uniform(.07,.15))
        g.add([tip,(mid[0]-.006,mid[1],mid[2]),end,(mid[0]+.006,mid[1],mid[2])],
              [(0,1,2),(0,2,3)],"ochre" if j%4 else "mosaic")


def yard_fittings(g):
    # Hollow water trough next to the western wall on two dressed stone sleepers.
    x,y=-3.02,2.31
    for off in (-.48,.48):
        g.box(x,y+off,0,.81,.25,.211,"tuff")
    g.box(x,y,.18,.75,1.49,.16,"tuff")
    for s in (-1,1):
        g.box(x+s*.329,y,.33,.095,1.50,.36,"traver")
        g.box(x+s*.331,y,.665,.115,1.54,.053,"traver")
        g.box(x,y+s*.704,.33,.59,.094,.36,"traver")
        g.box(x,y+s*.709,.665,.60,.115,.053,"traver")
    # Terra-cotta feed jars, woven grain basket and small transaction shelf.
    for x,y,size in ((3.09,2.61,.41),(3.15,1.83,.29)):
        revolved(g,x,y,0,[(0,size*.57),(.12,size*.82),(.41,size),(.59,size*.87),
                            (.68,size*.59),(.74,size*.59),(.76,size*.67),(.775,size*.61),(.71,size*.53)],"fired",18)
        for s in (-1,1):
            g.beam((x+s*size*.61,y,.68),(x+s*size*.92,y,.61),.026,"fired")
            g.beam((x+s*size*.92,y,.61),(x+s*size*.88,y,.49),.025,"fired")
    basket(g,2.96,3.23,.006,.34,"paving")
    for x in (2.30,3.41):
        for y in (.78,1.19):
            g.box(x,y,0,.095,.095,.85,"cedar")
    for j in range(4):
        g.box(2.85,.73+j*.164,.83,1.38,.154,.086,"cedar")
    g.box(2.85,.99,.915,.35,.22,.03,"beam")
    g.box(2.85,.99,.945,.315,.19,.006,"basalt")
    g.beam((3.06,.89,.937),(3.18,1.07,.937),.009,"bronze",8)
    # Two draped leather headstalls hang from the rear wall at the seller's side.
    for x in (2.84,3.12):
        g.beam((x,7.04,1.99),(x,6.91,2.03),.026,"cedar",8)
        loop=[(x,6.9,2.03),(x-.076,6.88,1.90),(x-.094,6.89,1.62),(x-.05,6.88,1.49),
              (x+.05,6.88,1.49),(x+.094,6.89,1.66),(x+.087,6.88,1.92),(x,6.9,2.03)]
        for a,b in zip(loop,loop[1:]):
            g.beam(a,b,.015,"beam",5)
        g.ring((x,6.85,1.49),.039,.008,"bronze",steps=10)


def floor_and_water():
    bpy.ops.mesh.primitive_plane_add(size=1)
    obj=bpy.context.object
    obj.name="Battuto del cortile"
    # Upward winding at Z=0; no rectangular pedestal on the street.
    for v in obj.data.vertices:
        v.co.x*=7.45
        v.co.y=v.co.y*7.22+3.69
        v.co.z=.006
    uv=obj.data.uv_layers.active
    uv.name="Local_material_atlas"
    for loop in obj.data.loops:
        p=obj.data.vertices[loop.vertex_index].co
        uv.data[loop.index].uv=(p.x/2.25,p.y/2.25)
    mat=bpy.data.materials.new("Terra battuta")
    mat.use_nodes=True
    nodes=mat.node_tree.nodes
    bsdf=nodes.get("Principled BSDF")
    tex=nodes.new("ShaderNodeTexImage")
    img=bpy.data.images.load(str(SHARED/"track_color.png"))
    img.pack()
    tex.image=img
    mat.node_tree.links.new(tex.outputs["Color"],bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value=.92
    obj.data.materials.append(mat)
    water=bpy.data.materials.new("Acqua del beveratoio")
    water.use_nodes=True
    bsdf=water.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value=(.070,.15,.133,1)
    bsdf.inputs["Roughness"].default_value=.20
    bsdf.inputs["IOR"].default_value=1.333
    bpy.ops.mesh.primitive_grid_add(x_subdivisions=10,y_subdivisions=17,size=1)
    obj=bpy.context.object
    obj.name="Acqua del beveratoio"
    obj.data.uv_layers.active.name="Local_material_atlas"
    for v in obj.data.vertices:
        v.co.x=v.co.x*.59-3.02
        v.co.y=v.co.y*1.335+2.31
        v.co.z=.584+.0027*math.sin(v.co.y*15+v.co.x*8)
    obj.data.materials.append(water)


def bedding(g):
    # Sparse loose reeds follow the direction of bedding instead of forming fresh hay bales.
    rng=random.Random(2858)
    for j in range(780):
        side=-1 if j%2 else 1
        x=side*rng.uniform(.15,3.45)
        y=rng.uniform(3.95,6.99)
        if j%9==0:
            x=side*rng.uniform(1.29,3.36)
            y=rng.uniform(.62,3.6)
        a=rng.gauss(.6,.81)
        l=rng.uniform(.06,.20)
        tip=Vector((x+l*math.cos(a),y+l*math.sin(a),.014))
        root=Vector((x,y,.015))
        mid=(tip+root)/2
        mid.z+=rng.uniform(.006,.027)
        cross=Vector((math.sin(a),-math.cos(a),0))*.006
        g.add([root,mid+cross,tip,mid-cross],[(0,1,2),(0,2,3)],"paving" if j%5 else "ochre")


def collision():
    # (name, x, depth, bottom, width, depth span, height). Reversed depth=Godot Z.
    boxes=[("YardFloor",0,3.69,-.13,7.45,7.22,.13),("Rear",0,7.16,0,7.52,.28,3.41),
           ("Divider",0,5.41,0,.155,3.23,1.35),("Trough",-3.02,2.31,0,.81,1.54,.72),
           ("AccountsTable",2.85,.975,0,1.39,.66,.92),("FeedBin",3.1,2.53,0,.75,1.86,.8)]
    for s,side in [(-1,"West"),(1,"East")]:
        boxes.extend([(side+"Street",s*2.58,.13,0,2.23,.28,1.08),
                      (side+"Pier",s*1.48,.15,0,.38,.39,1.62),
                      (side+"Wall",s*3.64,1.84,0,.26,3.59,1.42),
                      (side+"StableWall",s*3.65,5.34,0,.26,3.91,2.09),
                      (side+"OpenGate",s*3.39,4.31,0,.14,1.25,1.22),
                      (side+"Rack",s*1.69,6.65,.79,1.59,.61,1.12),
                      (side+"FrontPost",s*3.54,3.64,0,.25,.29,2.82)])
    boxes.append(("FrontPost",0,3.64,0,.25,.29,2.82))
    lines=['[gd_scene format=3]','']
    for name,x,d,b,w,length,h in boxes:
        lines.extend([f'[sub_resource type="BoxShape3D" id="{name}"]',f'size = Vector3({w}, {h}, {length})',''])
    lines.extend(['[node name="StableCollision" type="StaticBody3D"]','collision_mask = 0',''])
    for name,x,d,b,w,length,h in boxes:
        lines.extend([f'[node name="{name}" type="CollisionShape3D" parent="."]',
                      f'position = Vector3({x}, {b+h/2:.6f}, {-d})',f'shape = SubResource("{name}")',''])
    (OUT/"stable_collision.tscn").write_text("\n".join(lines))


def main():
    OUT.mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.unit_settings.system="METRIC"
    pbr=attach_material([SHARED/f"valdorf_{k}.png" for k in ("color","normal","orm")])
    for label,make in [("Ingresso alla corte",courtyard),("Scuderia a tettoia",shed),("Poste e rastrelliere",partition),
                       ("Abbeveratoio e banco",yard_fittings),("Strame",bedding)]:
        g=Domus()
        make(g)
        g.to_mesh(label,pbr)
    floor_and_water()
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(Path(__file__).with_name("stable.blend")),compress=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.context.view_layer.objects.active=next(iter(bpy.context.scene.objects))
    bpy.ops.object.join()
    bpy.context.object.name="Stabulum"
    with TemporaryDirectory() as tmp:
        folder=Path(tmp)
        bpy.ops.export_scene.gltf(filepath=str(folder/"stable.gltf"),export_format="GLTF_SEPARATE",export_animations=False)
        doc=json.loads((folder/"stable.gltf").read_text())
        geometry=(folder/doc["buffers"][0].pop("uri")).read_bytes()
        for image in doc["images"]:
            shared=SHARED/image["uri"]
            if not shared.is_file():
                raise ValueError("Missing shared image "+str(shared))
            image["uri"]="../../village/"+shared.name
        raw=json.dumps(doc,separators=(",",":")).encode()
        raw+=b" "*(-len(raw)%4)
        geometry+=b"\0"*(-len(geometry)%4)
        payload=struct.pack("<4sII",b"glTF",2,28+len(raw)+len(geometry))
        payload+=struct.pack("<I4s",len(raw),b"JSON")+raw
        payload+=struct.pack("<I4s",len(geometry),b"BIN\0")+geometry
        (OUT/"stable.glb").write_bytes(payload)
    collision()


if __name__=="__main__":
    main()
