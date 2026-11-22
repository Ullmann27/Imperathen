"""Original market, joinery shed, store, stake bay, practice target and timber billet.

Run Blender 4.3.2 in background with this script. Runtime GLBs reference the
same three PBR atlases; the editable Blender sources have packed images.
"""
import json
import math
from pathlib import Path
import random
import shutil
import struct
import sys
from tempfile import TemporaryDirectory

import bpy
import numpy as np
from mathutils import Vector
from PIL import Image

SOURCE=Path(__file__).resolve().parent
DEST=SOURCE.parents[1]/"prototype/assets/village"
sys.path.insert(0,str(SOURCE.parent/"architecture"))
from build_atrium import Domus, box_between
from atrium_materials import SWATCHES, swatch


def bake_atlas(folder):
    size=160
    atlases=[Image.new("RGB",(size*4,size*4)) for _ in range(3)]
    y,x=np.mgrid[0:size,0:size]/size
    for i,(name,color) in enumerate(SWATCHES.items()):
        albedo,normal,packed=swatch(name,color,i,size)
        if name in ("paving","mosaic","basalt","water"):
            rgb={"paving":(169,139,84),"mosaic":(222,203,160),"basalt":(131,108,74),"water":(95,111,57)}[name]
            fiber=np.sin(x*565+1.9*np.sin(y*20))*.073+np.sin(y*370)*.035
            rng=np.random.default_rng(430+i)
            shade=1+fiber+rng.normal(0,.024,x.shape)
            col=np.array(rgb)[None,None,:]*shade[:,:,None]
            if name=="mosaic":
                # A dyed edge woven into the flax awning.
                stripe=(x>.760)&(x<.830)|(x>.867)&(x<.887)
                col[stripe]*=np.array([.66,.35,.32])
            albedo=np.clip(col,0,255).astype(np.uint8)
            normal=np.stack((128+fiber*105,128+fiber*32,np.full_like(x,254)),axis=2).astype(np.uint8)
            packed=np.full_like(albedo,(255,217,0))
        for atlas,pixels in zip(atlases,(albedo,normal,packed)):
            atlas.paste(Image.fromarray(pixels),((i%4)*size,(3-i//4)*size))
    paths=[]
    for i,(kind,atlas) in enumerate(zip(("color","normal","orm"),atlases)):
        path=folder/f"valdorf_{kind}.png"
        if i==2:
            atlas=atlas.resize((160,160),Image.Resampling.BILINEAR)
        atlas.save(path)
        paths.append(path)
    return paths


def attach_material(paths):
    mat=bpy.data.materials.new("Joinery_stone_textile_PBR")
    mat.use_nodes=True
    nodes,links=mat.node_tree.nodes,mat.node_tree.links
    p=nodes.get("Principled BSDF")
    tex=[]
    for i,path in enumerate(paths):
        image=bpy.data.images.load(str(path))
        image.name=path.stem
        if i:
            image.colorspace_settings.name="Non-Color"
        image.pack()
        node=nodes.new("ShaderNodeTexImage")
        node.image=image
        tex.append(node)
    links.new(tex[0].outputs["Color"],p.inputs["Base Color"])
    normal=nodes.new("ShaderNodeNormalMap")
    normal.inputs["Strength"].default_value=.43
    links.new(tex[1].outputs["Color"],normal.inputs["Color"])
    links.new(normal.outputs[0],p.inputs["Normal"])
    channels=nodes.new("ShaderNodeSeparateColor")
    links.new(tex[2].outputs["Color"],channels.inputs[0])
    links.new(channels.outputs["Green"],p.inputs["Roughness"])
    links.new(channels.outputs["Blue"],p.inputs["Metallic"])
    return mat


def revolved(g,x,y,z,rings,mat,n=14,phase=0):
    points=[]
    for h,radius in rings:
        for i in range(n):
            a=i*math.tau/n+phase
            points.append((x+radius*math.cos(a),y+radius*math.sin(a),z+h))
    faces=[tuple(reversed(range(n)))]
    for j in range(len(rings)-1):
        for i in range(n):
            k=(i+1)%n
            faces.append((j*n+i,j*n+k,(j+1)*n+k,(j+1)*n+i))
    faces.append(tuple(range((len(rings)-1)*n,len(rings)*n)))
    g.add(points,faces,mat)


def basket(g,x,y,z,r,fill="ochre"):
    revolved(g,x,y,z,[(0,.72*r),(.07,.83*r),(.33,r),(.35,.94*r),(.30,.89*r)],"basalt",16)
    for j in range(5):
        h=.06+j*.064
        rr=r*(.82+.17*j/4)
        revolved(g,x,y,z+h,[(0,rr),(.013,rr)],"paving",16)
    rng=random.Random(round((x+5)*547))
    for i in range(18):
        a=rng.random()*math.tau;d=r*math.sqrt(rng.random())*.78
        height=.29+.105*(1-d/r)
        radius=rng.uniform(.042,.068)
        revolved(g,x+math.cos(a)*d,y+math.sin(a)*d,z+height,[(0,radius*.55),(.045,radius),(.082,radius*.66)],fill,6)


def shingle_roof(g,lx,dy,eave,peak):
    for s in (-1,1):
        g.prism([(-lx,s*dy,eave),(lx,s*dy,eave),(lx,0,peak),(-lx,0,peak)],(0,0,-.10),"beam")
        for row in range(5):
            t0,t1=row/5,(row+1)/5
            n=round(lx*5.4)
            for i in range(n):
                x=-lx+i*2*lx/n
                x1=x+2*lx/n-.014
                dz=.028+.009*math.sin(i*17+row*37)
                g.prism([(x,s*dy*(1-t0),eave+(peak-eave)*t0+dz),(x1,s*dy*(1-t0),eave+(peak-eave)*t0+dz),
                         (x1,s*dy*(1-t1),eave+(peak-eave)*t1+.013),(x,s*dy*(1-t1),eave+(peak-eave)*t1+.013)],
                        (0,0,-.041),"cedar" if (row+i)%6 else "beam")
        g.beam((-lx,s*dy,eave-.11),(lx,s*dy,eave-.11),.081,"beam",7)
    g.beam((-lx-.08,0,peak+.05),(lx+.08,0,peak+.05),.106,"cedar",8)


def timber_frame(g,lx,dy,height,front_door=False):
    for x in (-lx,0,lx):
        for y in (-dy,dy):
            if front_door and x == 0 and y < 0:
                continue
            g.box(x,y,0,.31,.31,.18,"tuff")
            g.box(x,y,.16,.171,.172,height-.12,"cedar")
            for s in (-1,1):
                if abs(x+s*.45)<=lx+.05:
                    box_between(g,(x,y,height-.54),(x+s*.45,y,height-.12),.101,.107,"beam")
        box_between(g,(x,-dy-.15,height),(x,dy+.15,height),.17,.18,"beam")
    for y in (-dy,dy):
        g.box(0,y,height-.08,lx*2+.46,.19,.19,"beam")


def workshop(g):
    # Open southern bay, glazed-free shutter opening, pegs and wedged bench.
    lx,dy=2.32,1.48
    timber_frame(g,lx,dy,2.43)
    g.box(0,dy,.10,4.62,.17,2.23,"intonaco")
    g.box(0,dy-.10,.07,4.59,.04,.65,"oxide")
    g.box(-lx,0,.10,.16,2.97,2.22,"intonaco")
    g.box(lx,.54,.07,.15,1.84,1.12,"tuff")
    for x in (-lx,0,lx):
        box_between(g,(x,-1.67,2.40),(x,0,3.52),.108,.13,"cedar")
        box_between(g,(x,1.67,2.40),(x,0,3.52),.108,.13,"cedar")
    shingle_roof(g,2.7,1.91,2.48,3.61)
    # Split plank work surface, trestles, wooden vise, shavings and tool rail.
    for x in (-1.62,.13):
        for y in (-.50,.24):
            box_between(g,(x,y,.04),(x*.98,y*.79,.91),.103,.123,"beam")
    for i in range(4):
        g.box(-.73,-.53+i*.209,.88,2.24,.199,.12,"cedar")
    g.box(.24,-.69,.68,.37,.118,.37,"beam")
    g.beam((.24,-.69,.82),(.24,-.91,.82),.046,"iron",7)
    g.beam((.24,-.91,.65),(.24,-.91,.99),.025,"cedar",8)
    g.box(-.74,1.35,1.69,2.57,.12,.16,"cedar")
    for i in range(7):
        x=-1.79+i*.31
        g.beam((x,1.24,1.19),(x,1.24,1.84),.022,"cedar")
        g.box(x,1.238,1.17,.064,.04,.16,"iron")
        g.beam((x,1.27,1.76),(x,1.17,1.76),.022,"bronze",6)
    for row in range(3):
        for i in range(4-row):
            x=.78+i*.25+row*.125
            g.beam((x,-.38,.13+row*.214),(x,1.16,.13+row*.214),.125,"cedar",9)
    basket(g,-1.81,.85,.015,.33,"water")


def store(g):
    timber_frame(g,1.87,1.19,2.19,front_door=True)
    for s in (-1,1):
        g.box(s*1.87,0,.03,.19,2.42,1.97,"intonaco")
        g.box(s*1.19,-1.19,.02,1.35,.17,2.08,"intonaco")
        g.box(s*1.19,-1.30,.22,1.35,.046,.47,"oxide")
    g.box(0,1.20,.035,3.76,.18,2.07,"intonaco")
    for x in (-1.82,-.53,.53,1.82):
        g.box(x,-1.29,.09,.102,.18,2.11,"cedar")
    g.box(0,-1.30,1.96,1.27,.19,.17,"beam")
    # Open boarded half-door against the left reveal.
    for i in range(4):
        g.box(-.52,-1.18+i*.152,.08,.071,.143,1.83,"cedar")
    for z in (.44,1.43):
        g.box(-.465,-.96,z,.031,.57,.061,"iron")
    shingle_roof(g,2.20,1.58,2.23,3.29)
    for x in (-1.30,1.25):
        for i in range(2):
            r=.33-i*.05
            revolved(g,x,.18+i*.57,.05,[(0,.65*r),(.13,r),(.48,r*.93),(.69,r*.49),(.75,r*.54)],"paving",12)
            revolved(g,x,.18+i*.57,.74,[(0,r*.53),(.035,r*.54)],"basalt",12)
    for s in (-1,1):
        g.box(s*1.5,-1.40,.07,.5,.30,.19,"traver")


def awning(g):
    for x in (-1.64,1.64):
        for y in (-.83,.79):
            g.beam((x,y,0),(x,y,2.35 if y<0 else 2.68),.066,"cedar",8)
            g.box(x,y,.01,.17,.17,.11,"tuff")
    # Rectangular woven cloth panels sag between the lifted centre and their tied corners.
    for col in range(5):
        for row in range(4):
            def point(i,j):
                x=-1.81+i*.724
                y=-1.02+j*.50
                return (x,y,2.32+.18*(y+1)+.19*math.sin((y+1.02)*math.pi/2)-.105*math.sin(i*math.pi/5))
            a,b,c,d=point(col,row),point(col+1,row),point(col+1,row+1),point(col,row+1)
            g.prism([a,b,c,d],(0,0,-.021),"mosaic")
        a,b=point(col,0),point(col+1,0)
        g.prism([a,b,(b[0],b[1],b[2]-.166),(a[0],a[1],a[2]-.146)],(0,.023,0),"oxide" if col%2==0 else "mosaic")
    for s in (-1,1):
        box_between(g,(s*1.63,-.82,2.30),(s*1.63,.82,2.62),.08,.095,"beam")
    for x in (-1.22,1.22):
        for y in (-.42,.42):
            g.box(x,y,0,.11,.11,.86,"cedar")
    for i in range(6):
        g.box(0,-.525+i*.210,.84,3.04,.201,.104,"cedar")
    for i,mat in enumerate(("water","ochre","fired")):
        basket(g,-1.02+i*1.02,0,.94,.37,mat)


def palisade(g,coarse=False):
    rng=random.Random(3092)
    for j in range(4):
        x=-.518+j*.346
        h=2.21+rng.uniform(-.13,.17)
        r=.164+rng.uniform(-.01,.013)
        rings=[(0,r),(.47,r*1.02),(h-.39,r*.91),(h-.23,r*.73),(h,.018)]
        if coarse:
            rings=[(0,r),(h-.34,r*.92),(h,.014)]
        revolved(g,x,rng.uniform(-.027,.027),0,rings,"cedar" if j!=1 else "beam",4 if coarse else 7,j*.21)
    for z in (.76,1.57):
        g.box(0,.150,z,1.401,.084,.105,"beam")
        if coarse:
            continue
        for x in (-.53,.52):
            g.beam((x-.071,.205,z-.04),(x+.071,.205,z+.16),.016,"basalt",5)
            g.beam((x+.071,.206,z-.04),(x-.071,.206,z+.16),.016,"basalt",5)


def dummy(g):
    rng=random.Random(283)
    g.beam((0,0,0),(0,0,2.46),.072,"cedar",9)
    g.beam((-.75,0,1.57),(.75,0,1.57),.072,"cedar",9)
    revolved(g,0,0,.72,[(0,.18),(.26,.30),(.73,.37),(.97,.28),(1.07,.13)],"paving",16)
    revolved(g,0,0,1.75,[(0,.115),(.12,.205),(.29,.206),(.42,.141),(.47,.071)],"paving",14)
    for z,r in ((.90,.255),(1.05,.32),(1.50,.367)):
        revolved(g,0,0,z,[(0,r),(.031,r)],"basalt",16)
    for i in range(43):
        a=rng.random()*math.tau
        r=rng.uniform(.16,.26)
        g.beam((r*math.cos(a),r*math.sin(a),.96),((r+.055)*math.cos(a),(r+.055)*math.sin(a),rng.uniform(.56,.79)),.011,"paving",4)
    for s in (-1,1):
        box_between(g,(0,0,.52),(s*.42,0,.04),.09,.09,"cedar")


def timber(g):
    # One unit replaces one previous visual log. The four visibility stages remain independent.
    g.beam((0,-.95,0),(0,.95,0),.195,"cedar",11,.178)
    for s in (-1,1):
        g.beam((0,s*.95,0),(0,s*.957,0),.150,"paving",11)
        g.beam((0,s*.957,0),(0,s*.960,0),.082,"cedar",9)
    g.beam((.144,.22,.032),(.25,.29,.105),.061,"cedar",7,.035)


def write_glb_with_shared_textures(folder,name,shared):
    path=folder/(name+".gltf")
    bpy.ops.export_scene.gltf(filepath=str(path),export_format="GLTF_SEPARATE",export_animations=False)
    gltf=json.loads(path.read_text())
    binary=(folder/gltf["buffers"][0].pop("uri")).read_bytes()
    for image in gltf["images"]:
        source=folder/image["uri"]
        target=DEST/source.name
        if target in shared and target.read_bytes()!=source.read_bytes():
            raise ValueError(f"Inconsistent shared texture: {target}")
        if target not in shared:
            shutil.copyfile(source,target)
            shared.add(target)
        image["uri"]=source.name
    meta=json.dumps(gltf,separators=(",",":")).encode()
    meta+=b" "*(-len(meta)%4)
    binary+=b"\0"*(-len(binary)%4)
    total=28+len(meta)+len(binary)
    glb=struct.pack("<4sII",b"glTF",2,total)+struct.pack("<I4s",len(meta),b"JSON")+meta
    glb+=struct.pack("<I4s",len(binary),b"BIN\0")+binary
    (DEST/(name+".glb")).write_bytes(glb)


if __name__=="__main__":
    DEST.mkdir(parents=True,exist_ok=True)
    with TemporaryDirectory() as temp:
        temp=Path(temp)
        sources=temp/"atlas"
        sources.mkdir()
        paths=bake_atlas(sources)
        shared=set()
        for name,builder in (("workshop",workshop),("storehouse",store),("market",awning),
                             ("palisade_bay",palisade),("palisade_silhouette",lambda g:palisade(g,True)),("training_dummy",dummy),("timber_billet",timber)):
            bpy.ops.wm.read_factory_settings(use_empty=True)
            g=Domus()
            builder(g)
            g.to_mesh(name,attach_material(paths))
            bpy.context.preferences.filepaths.save_version=0
            bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/(name+".blend")),compress=True)
            dest=temp/name
            dest.mkdir()
            write_glb_with_shared_textures(dest,name,shared)
