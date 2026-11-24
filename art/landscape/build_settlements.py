"""Build three settlement studies and a field worker. Blender 4.3.2, original meshes."""
import json
import math
from pathlib import Path
import random
import sys
from tempfile import TemporaryDirectory

import bpy
import numpy as np
from mathutils import Vector
from PIL import Image

SOURCE=Path(__file__).resolve().parent
OUTPUT=SOURCE.parents[1]/"prototype/assets/landscape"
sys.path.insert(0,str(SOURCE.parent/"soldiers"))
import build as soldier

COLORS={"daub":(209,188,150),"white":(220,210,185),"timber":(100,75,54),"oak":(129,93,63),
        "dark":(68,58,48),"slate":(81,89,92),"ridge":(108,114,113),"thatch":(164,138,91),
        "straw":(187,161,108),"earth":(124,100,78),"stone":(139,133,115),"rope":(143,112,75),
        "red":(139,71,52),"clay":(173,112,75),"join":(95,104,102),"wattle":(156,132,96)}
NAMES=list(COLORS)


def palette(folder):
    tile=128
    atlas=Image.new("RGB",(tile*4,tile*4))
    for i,(name,color) in enumerate(COLORS.items()):
        rng=np.random.default_rng(780+i)
        y,x=np.indices((tile,tile))
        noise=rng.normal(0,.025,(tile,tile))
        if name in ("timber","oak","dark","red","wattle"):
            factor=1+noise+.082*np.sin(x*.67+np.sin(y*.029)*1.6)+.045*np.sin(x*.14+np.sin(y*.05))
        elif name in ("thatch","straw","rope"):
            factor=.96+noise+.11*np.sin(x*2.2+.48*np.sin(y*.06))+.08*np.cos(x*.71+y*.018)
        else:
            factor=1+noise+.034*np.sin(x*.08+y*.08)*np.sin(x*.03-y*.05)
        texture=np.clip(np.array(color)[None,None,:]*factor[:,:,None],0,255).astype(np.uint8)
        # UV origin in Blender is at the bottom.
        atlas.paste(Image.fromarray(texture),((i%4)*tile,(3-i//4)*tile))
    path=folder/"settlement_surfaces.png"
    atlas.save(path)
    material=bpy.data.materials.new("Original_timber_earth_thatch_tile")
    material.use_nodes=True
    node=material.node_tree.nodes.new("ShaderNodeTexImage")
    node.image=bpy.data.images.load(str(path))
    node.image.pack()
    shader=material.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Roughness"].default_value=.83
    material.node_tree.links.new(node.outputs["Color"],shader.inputs["Base Color"])
    return material


class House:
    def __init__(self):
        self.vertices,self.faces,self.uvs,self.smoothing=[],[],[],[]

    def add(self,points,boundaries,mat,smooth=False):
        offset=len(self.vertices)
        self.vertices.extend(tuple(p) for p in points)
        index=NAMES.index(mat)
        for indices in boundaries:
            self.faces.append(tuple(i+offset for i in indices))
            if len(indices)==4:
                coords=[(0,0),(1,0),(1,1),(0,1)]
            else:
                coords=[(.5+.48*math.cos(i*math.tau/len(indices)),.5+.48*math.sin(i*math.tau/len(indices))) for i in range(len(indices))]
            self.uvs.append([((index%4+.02+.96*u)/4,(index//4+.02+.96*v)/4) for u,v in coords])
            self.smoothing.append(smooth)

    def prism(self,contour,shift,mat):
        n=len(contour)
        points=[Vector(p) for p in contour]
        normal=(points[1]-points[0]).cross(points[2]-points[0])
        if normal.dot(Vector(shift))>0:
            points.reverse()
        faces=[tuple(range(n)),tuple(reversed(range(n,2*n)))]
        faces.extend((j,j+n,(j+1)%n+n,(j+1)%n) for j in range(n))
        self.add(points+[v+Vector(shift) for v in points],faces,mat)

    def box(self,x,y,z,w,d,h,mat):
        self.prism([(x-w/2,y-d/2,z),(x+w/2,y-d/2,z),(x+w/2,y+d/2,z),(x-w/2,y+d/2,z)],(0,0,h),mat)

    def beam(self,start,end,radius,mat,sides=7,r2=None):
        a,b=Vector(start),Vector(end)
        axis=(b-a).normalized()
        ref=Vector((1,0,0)) if abs(axis.x)<.85 else Vector((0,1,0))
        u=axis.cross(ref).normalized()
        v=axis.cross(u).normalized()
        rings=[]
        for p,r in ((a,radius),(b,radius if r2 is None else r2)):
            rings.extend(p+(u*math.cos(i*math.tau/sides)+v*math.sin(i*math.tau/sides))*r for i in range(sides))
        faces=[tuple(reversed(range(sides))),tuple(range(sides,2*sides))]
        faces.extend((i,(i+1)%sides,(i+1)%sides+sides,i+sides) for i in range(sides))
        self.add(rings,faces,mat)

    def door(self,x,y,z,w,h,mat):
        for sign in (-1,1):
            self.box(x+sign*w*.52,y,z,.1,.13,h+.11,mat)
        self.box(x,y,z+h,w+.22,.14,.115,mat)

    def board_wall(self,axis,fixed,lo,hi,z,h,mat,gate=None):
        count=round((hi-lo)/.18)
        span=(hi-lo)/count
        for i in range(count):
            p=lo+(i+.5)*span
            if gate and abs(p)<gate:
                continue
            if axis=="x":
                self.box(p,fixed,z,span*.96,.11,h,mat if i%4 else "timber")
            else:
                self.box(fixed,p,z,.11,span*.96,h,mat if i%4 else "timber")

    def to_mesh(self,name,material):
        mesh=bpy.data.meshes.new(name)
        mesh.from_pydata(self.vertices,[],self.faces)
        mesh.update()
        mesh.materials.append(material)
        uv=mesh.uv_layers.new(name="Local_material_atlas")
        for poly,coords,smooth in zip(mesh.polygons,self.uvs,self.smoothing):
            poly.use_smooth=smooth
            for loop,coordinate in zip(poly.loop_indices,coords):
                uv.data[loop].uv=coordinate
        obj=bpy.data.objects.new(name,mesh)
        bpy.context.collection.objects.link(obj)
        return obj


def han(g):
    # Raised earth podium, three structural bays and a deep covered veranda.
    g.box(0,0,.015,7.35,5.65,.38,"earth")
    g.box(0,0,.395,7.43,5.72,.10,"stone")
    for k in range(3):
        g.box(0,-3.42+k*.25,.012,2.0,.38,.15*(k+1),"stone")
    g.box(0,1.93,.50,6.22,.18,2.38,"white")
    for sign in (-1,1):
        g.box(sign*3.04,0.12,.50,.18,3.72,2.38,"daub")
        g.box(sign*1.88,-1.64,.50,2.26,.16,2.38,"white")
    g.door(0,-1.725,.50,1.49,2.20,"red")
    # Sliding/slatted door drawn partly aside with a real opening.
    for i in range(4):
        g.box(-.642+i*.177,-1.72,.51,.163,.10,2.12,"dark")
    for s in (-1,1):
        cx=s*1.92
        g.box(cx,-1.749,1.40,1.42,.075,.97,"dark")
        for i in range(9):
            g.box(cx-.69+i*.172,-1.808,1.39,.043,.064,1.00,"oak")
        for z in (1.41,1.72,2.03,2.36):
            g.box(cx,-1.822,z,1.46,.06,.06,"oak")
    for y in (-2.53,2.16):
        for x in (-3.26,-1.12,1.12,3.26):
            g.box(x,y,.50,.36,.35,.17,"stone")
            g.beam((x,y,.65),(x,y,2.96),.125,"red",12)
            g.box(x,y,2.81,.39,.33,.17,"oak")
            g.box(x,y,2.96,.62,.41,.15,"red")
        g.box(0,y,3.04,7.12,.22,.21,"timber")
    # A single hipped tile roof, with shallow eaves and an unadorned ridge.
    e,half,depth,ridge=3.94,2.57,3.13,4.48
    for s in (-1,1):
        points=[(-e,s*depth,3.08),(e,s*depth,3.08),(half,0,ridge),(-half,0,ridge)]
        g.prism(points,(0,0,-.15),"slate")
        g.prism([(s*e,-depth,3.08),(s*e,depth,3.08),(s*half,0,ridge)],(0,0,-.15),"slate")
        for i in range(47):
            k=i/46
            a=(-e+2*e*k,s*depth,3.101)
            b=(-half+2*half*k,0,ridge+.015)
            g.beam(a,b,.055,"ridge",7)
        for i in range(1,27):
            k=i/27
            a=(s*e,(2*k-1)*depth,3.10)
            b=(s*half,0,ridge+.02)
            g.beam(a,b,.043,"ridge",6)
        for i in range(1,9):
            t=i/10
            ext=e+(half-e)*t
            y=s*depth*(1-t)
            z=3.10+(ridge-3.08)*t
            g.beam((-ext,y,z),(ext,y,z),.021,"join",5)
        g.beam((-e,s*depth,3.02),(e,s*depth,3.02),.10,"dark",8)
    g.beam((-half-.13,0,ridge+.05),(half+.13,0,ridge+.05),.12,"ridge",10)


def thatch(g,length,depth,eave,ridge,mat,rng):
    # Ridge runs along X. Mesh roof skins, projecting cut stalks and a bound ridge.
    for sign in (-1,1):
        g.prism([(-length,sign*depth,eave),(length,sign*depth,eave),
                 (length,0,ridge),(-length,0,ridge)],(0,0,-.18),mat)
        for i in range(int(length*23)):
            x=rng.uniform(-length,length)
            t=rng.uniform(0,.91)
            end=max(-.035,t-rng.uniform(.08,.28))
            y,z=sign*depth*(1-t),eave+(ridge-eave)*t+.027
            y2,z2=sign*depth*(1-end),eave+(ridge-eave)*end+.018
            g.beam((x,y,z),(x+rng.uniform(-.035,.035),y2,z2),
                   rng.uniform(.012,.025),rng.choice(("thatch","straw")),4)
        for i in range(int(length*20)):
            x=-length+2*length*i/(int(length*20)-1)
            noise=rng.uniform(-.07,.045)
            g.beam((x,sign*(depth-.10),eave+.06),(x+.015,sign*(depth+.035),eave-.11+noise),.023,"straw",4)
    g.beam((-length-.08,0,ridge+.03),(length+.08,0,ridge+.03),.125,"thatch",10)
    for i in range(round(length*3)):
        x=-length+.20+i*(2*length-.4)/max(1,round(length*3)-1)
        g.beam((x,-.22,ridge-.045),(x,0,ridge+.162),.019,"rope",5)
        g.beam((x,0,ridge+.162),(x,.22,ridge-.045),.019,"rope",5)


def wa(g):
    # Raised timber granary with flat rodent baffles, ladder access and thatch.
    rng=random.Random(24)
    for x in (-1.84,0,1.84):
        for y in (-1.30,1.30):
            g.beam((x,y,0),(x,y,1.55),.17,"timber",10)
            g.beam((x,y,1.00),(x,y,1.10),.36,"oak",16)
    for y in (-1.30,1.30):
        g.box(0,y,1.34,4.62,.21,.25,"timber")
    for i in range(22):
        g.box(-2.22+i*.21,-.16,1.54,.203,3.66,.115,"oak")
    for x in (-2.00,2.0):
        g.board_wall("y",x,-1.36,1.36,1.66,1.83,"oak")
    g.board_wall("x",1.34,-2,2,1.66,1.83,"oak")
    g.board_wall("x",-1.34,-2,2,1.66,1.83,"oak",gate=.49)
    for x in (-2,-.57,.57,2):
        g.box(x,-1.4,1.63,.12,.17,1.97,"timber")
    for y in (-1.38,1.38):
        g.box(0,y,3.44,4.36,.18,.18,"timber")
        g.box(0,y,2.05,4.03,.14,.11,"timber")
    g.door(0,-1.42,1.66,1.00,1.66,"dark")
    for x in (-2.02,2.02):
        g.prism([(x,-1.46,3.47),(x,1.46,3.47),(x,0,4.79)],(.075,0,0),"timber")
        for i in range(-5,6):
            y=i*.234
            h=max(.06,1.17*(1-abs(y)/1.40))
            g.box(x+.066,y,3.51,.085,.115,h,"oak")
    thatch(g,2.54,1.92,3.47,5.07,"straw",rng)
    for x in (-.38,.38):
        g.beam((x,-2.95,.035),(x,-1.78,1.77),.075,"timber",8)
    for step in range(6):
        u=.09+step*.16
        y=-2.95+1.17*u
        g.beam((-.39,y,.035+1.735*u),(.39,y,.035+1.735*u),.06,"oak",7)


def longhouse(g):
    # Three-aisled, timber-post longhouse with a low thatched eave and narrow wall bays.
    rng=random.Random(98)
    lx,dy=5.55,2.25
    g.box(0,0,0,11.28,4.55,.13,"earth")
    for y in (-dy,dy):
        for i in range(8):
            a,b=-lx+i*(2*lx/8),-lx+(i+1)*(2*lx/8)
            if y<0 and i==4:
                continue
            g.box((a+b)/2,y,.13,b-a-.07,.18,1.90,"daub")
        for x in [-lx+i*(2*lx/8) for i in range(9)]:
            g.beam((x,y,0),(x+rng.uniform(-.04,.04),y,2.19),.114,"timber",8)
        g.box(0,y,1.93,11.42,.18,.20,"timber")
    g.door(.694,-2.33,.12,1.13,1.76,"dark")
    # The entrance has a clear opening; its side jamb and lintel cast real shadows.
    for x in (-lx,lx):
        g.box(x,0,.13,.18,4.48,1.9,"daub")
        g.prism([(x,-dy,2.02),(x,dy,2.02),(x,0,3.93)],(.13,0,0),"wattle")
        for i in range(-7,8):
            y=i*.28
            height=max(.09,1.76*(1-abs(y)/dy))
            g.box(x+.15,y,2.07,.07,.059,height,"timber")
        g.beam((x,-dy,1.98),(x,0,4.04),.12,"timber",7)
        g.beam((x,dy,1.98),(x,0,4.04),.12,"timber",7)
    for x in (-4,-1.4,1.4,4):
        for y in (-1.10,1.10):
            g.beam((x,y,.05),(x,y,3.12),.13,"dark",8)
    # Garden-side wattle panel beside the entrance reveals the woven construction.
    for i in range(8):
        g.box(-1.26+i*.16,-2.365,.21,.043,.052,.75,"oak")
    for i in range(9):
        z=.24+i*.077
        for k in range(7):
            x=-1.26+k*.16
            g.beam((x,-2.39+(-1)**(k+i)*.035,z),(x+.16,-2.39-(-1)**(k+i)*.035,z+.012),
                   .021,"wattle",5)
    thatch(g,6.03,2.77,1.94,4.18,"thatch",rng)


def pit_house(g):
    """Low hipped dwelling with floor below its enclosing earth rim and entrance hood."""
    rng=random.Random(139)
    width,depth,ridge_x,ridge=2.74,2.30,.99,3.04
    # Positive-Z relief keeps the floor visible on a continuous game terrain.
    g.box(0,0,.012,4.71,3.89,.07,"earth")
    for x in (-2.39,2.39):
        g.box(x,0,.015,.37,4.07,.46,"earth")
    g.box(0,1.90,.015,4.63,.41,.46,"earth")
    for sign in (-1,1):
        g.box(sign*1.51,-1.89,.015,1.65,.39,.46,"earth")
    for x in (-1.18,1.18):
        for y in (-.94,.94):
            g.beam((x,y,.073),(x,y,1.82),.119,"timber",8)
    for y in (-.94,.94):
        g.beam((-1.4,y,1.83),(1.4,y,1.83),.114,"oak",8)
    # The south slope stops at the doorway, beneath a separate thatched hood.
    for side in (-1,1):
        split=(-1,-.23,.23,1) if side==-1 else (-1,1)
        for a,b in zip(split,split[1:]):
            t0=.38 if side==-1 and a<0<b else 0
            ext=width+(ridge_x-width)*t0
            y=side*depth*(1-t0)
            eave=.47+(ridge-.47)*t0
            g.prism([(a*ext,y,eave),(b*ext,y,eave),(b*ridge_x,0,ridge),
                     (a*ridge_x,0,ridge)],(0,0,-.14),"thatch")
        g.prism([(side*width,-depth,.47),(side*width,depth,.47),(side*ridge_x,0,ridge)],
                (0,0,-.14),"thatch")
        for i in range(155):
            k=rng.uniform(-.99,.99)
            t=rng.uniform(.02,.92)
            if side==-1 and abs(k)<.245 and t<.42:
                continue
            end=max(-.015,t-rng.uniform(.07,.20))
            if side==-1 and abs(k)<.245:
                end=max(.38,end)
            def point(v):
                return (k*(width+(ridge_x-width)*v),side*depth*(1-v),.492+(ridge-.47)*v)
            g.beam(point(t),point(end),rng.uniform(.012,.021),rng.choice(("straw","thatch")),4)
        for k in range(14):
            y=-depth+2*depth*k/13
            g.beam((side*width,y,.47),(side*ridge_x,0,ridge),.012,"straw",4)
    # Two low sidewalls frame the entrance rather than painting a dark opening on the roof.
    for sign in (-1,1):
        g.box(sign*.626,-1.87,.080,.12,1.58,1.1,"wattle")
        g.beam((sign*.62,-2.57,.065),(sign*.62,-2.57,1.31),.074,"timber",8)
        g.prism([(sign*.83,-2.74,1.22),(sign*.79,-1.12,1.47),(0,-1.04,2.17),(0,-2.77,1.88)],
                (0,0,-.14),"straw")
        for i in range(19):
            t=i/18
            y=-2.72+t*1.60
            g.beam((sign*.814,y,1.235+t*.23),(0,y,1.89+t*.28),.013,"thatch",4)
    g.beam((-.68,-2.56,1.31),(.68,-2.56,1.31),.083,"timber",8)
    g.beam((-ridge_x-.13,0,ridge+.05),(ridge_x+.13,0,ridge+.05),.115,"oak",9)
    for x in (-.83,-.46,0,.46,.83):
        for side in (-1,1):
            g.beam((x,side*.20,ridge-.07),(x,0,ridge+.16),.017,"rope",5)


def farmer(name):
    # The original adult body gets work clothes, a woven brim and a hand hoe.
    g=soldier.Geometry(0)
    soldier.body(g,"archer")
    # Recolour the existing tunic UVs in place so the cloth has a single surface.
    cells=list(soldier.PALETTE)
    tunic={"farmer":"linen","han_farmer":"pine","wa_farmer":"linen"}[name]
    old,new=cells.index("pine"),cells.index(tunic)
    for idx,coords in enumerate(g.uvs):
        u,v=coords[0]
        src=int(u*4)+4*int(v*4)
        dst=src
        influence=g.weights[g.faces[idx][0]]
        dominant=influence if isinstance(influence,str) else influence[0][0]
        if src==old:
            dst=new
        if name=="han_farmer" and dominant.startswith(("Shin","Thigh")) and src==cells.index("skin"):
            dst=cells.index("charcoal")
        if dst!=src:
            g.uvs[idx]=[(a+(dst%4-src%4)/4,b+(dst//4-src//4)/4) for a,b in coords]
    g.module="Work_clothes"
    if name=="farmer":
        g.tube([(0,.008,1.63,.218,.193),(0,.008,1.653,.205,.185),
                (0,.012,1.703,.119,.115),(0,.013,1.777,.057,.058)],"linen","Head",26,.015)
        g.tube([(0,.009,1.666,.175,.155),(0,.01,1.68,.159,.146)],"hide","Head",22)
    elif name=="han_farmer":
        # Wrapped headcloth, crossing jacket edges, a cloth sash and leg wraps.
        g.tube([(0,.014,1.637,.116,.108),(0,.016,1.69,.118,.105),
                (0,.02,1.746,.075,.072)],"charcoal","Head",19)
        g.tube([(-.01,.028,1.73,.045,.046),(-.01,.03,1.788,.043,.041),
                (-.015,.03,1.80,.025,.026)],"brow","Head",14)
        g.tube([(0,.012,1.632,.12,.111),(0,.013,1.656,.12,.112)],"linen","Head",20)
        g.panel([(-.09,-.10,1.445),(-.058,-.12,1.43),(.101,-.151,1.221),
                 (.066,-.148,1.212)],"linen","Spine")
        g.panel([(.077,-.106,1.44),(.103,-.104,1.43),(.026,-.144,1.326),
                 (.004,-.142,1.34)],"linen","Spine")
        for s,suffix in ((-1,"R"),(1,"L")):
            g.tube([(.12*s,.004,.107,.055,.064),(.12*s,.007,.32,.073,.078),
                    (.12*s,-.002,.40,.073,.076)],"charcoal","Shin_"+suffix,14)
            for z in (.159,.225,.288,.349):
                r=.061 if z<.23 else .074
                g.tube([(.12*s,.005,z,r,.08),(.12*s,.005,z+.011,r,.08)],"hide","Shin_"+suffix,14)
        g.tube([(0,0,1.002,.166,.127),(0,0,1.06,.161,.124)],"oxblood","Pelvis",22,.018)
    else:
        # A simple shoulder-wrap, long tied hair and woven fibre belt.
        g.tube([(0,.014,1.637,.115,.106),(0,.012,1.690,.119,.107),
                (0,.009,1.74,.085,.09),(0,.02,1.763,.041,.054)],"brow","Head",21)
        g.tube([(0,.100,1.503,.029,.030),(0,.102,1.574,.040,.038),
                (0,.09,1.641,.046,.045)],"brow","Head",13)
        g.tube([(0,.012,1.636,.118,.109),(0,.012,1.652,.118,.109)],"oxblood","Head",22)
        g.panel([(-.150,-.141,1.414),(-.066,-.152,1.432),(.14,-.163,1.107),
                 (.104,-.159,1.070)],"wood","Spine")
        g.tube([(0,0,1.006,.166,.126),(0,0,1.045,.161,.123)],"wood","Pelvis",20,.025)
    # Tied waist cloth and belt pouch hang forward of the neutral working tunic.
    g.panel([(.046,-.125,1.035),(.145,-.117,1.035),(.156,-.14,.933),
             (.123,-.152,.911),(.055,-.153,.930)],"hide","Pelvis",.033)
    g.module="Farm_tool"
    g.rod([(-.34,-.27,.02),(-.31,-.16,1.23)],[.021,.019],"wood","Hand_R",9)
    if name=="wa_farmer":
        g.panel([(-.414,-.29,.007),(-.267,-.29,.007),(-.274,-.279,.131),
                 (-.322,-.273,.185),(-.387,-.279,.128)],"wood","Hand_R",.020)
    else:
        g.panel([(-.39,-.42,.034),(-.289,-.42,.034),(-.298,-.269,.073),(-.377,-.269,.073)],
            "iron","Hand_R",.015)
    arm=soldier.skeleton("farmer")
    obj=g.object("Field_worker",soldier.atlas_material(),arm)
    # Export only the two civilian loops needed for a village background character.
    original=soldier.LENGTHS
    soldier.LENGTHS={k:original[k] for k in ("idle","march")}
    soldier.animate(arm,"farmer")
    soldier.LENGTHS=original
    return obj


def build(name,folder):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if name.endswith("farmer"):
        obj=farmer(name)
    else:
        model=House()
        {"han_house":han,"wa_store":wa,"wa_house":pit_house,"wood_longhouse":longhouse}[name](model)
        obj=model.to_mesh(name,palette(folder))
    obj.data.calc_loop_triangles()
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/(name+".blend")),compress=True)
    path=OUTPUT/(name+".glb")
    bpy.ops.export_scene.gltf(filepath=str(path),export_format="GLB",export_animations=name.endswith("farmer"),
                              export_animation_mode="NLA_TRACKS",export_frame_step=1,
                              export_frame_range=False)
    return {"name":name,"triangles":len(obj.data.loop_triangles),"bytes":path.stat().st_size}


if __name__=="__main__":
    with TemporaryDirectory() as folder:
        metrics=[build(name,Path(folder)) for name in ("han_house","wa_store","wa_house","wood_longhouse","farmer","han_farmer","wa_farmer")]
    (SOURCE/"settlement_metrics.json").write_text(json.dumps(metrics,indent=2)+"\n")
