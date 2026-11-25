"""Original metric Roman architecture for IMPERATHEN.
Run: blender -b -t 2 --python generate_roman_test_city.py -- --output DIR --render
Fictional free-exploration city; not an archaeological survey. All geometry and
textures are authored here. Five residential archetypes, 240 house instances,
seven market types with three constructions and three sizes. Shared meshes and
separate simplified collision exports support mobile integration.
"""
import argparse
import json
import math
import random
import sys
from pathlib import Path
import bpy
import numpy as np
from mathutils import Vector
sys.path.insert(0, str(Path(__file__).resolve().parent))
from viva_roma_surfaces import build_blender_material

SEED=20261125
RNG=random.Random(SEED)
TAU=math.tau
MATS=[]
SCALES=[]
PROTO={}
ENTRIES=[]
SURFACE_STYLE='viva'
TEXTURE_SIZE=1024
RENDER_SAMPLES=48
SOURCES=[
    {"url":"https://turismoroma.it/en/node/1155","publisher":"Roma Capitale tourism",
     "used_for":"Colosseum 189 x 156 m envelope, over 48 m high, completed 80 CE; arena 76 x 46 m"},
    {"url":"https://www.turismoroma.it/en/places/baths-caracalla","publisher":"Roma Capitale tourism",
     "used_for":"Caracalla baths 212-216 CE. Our smaller fictional baths are not a measured reconstruction"}]


def legacy_material(name,color,kind,out,scale=2,rough=.86,metal=0):
    mat=bpy.data.materials.new(name)
    mat.use_nodes=True
    mat.diffuse_color=(*color,1)
    shader=mat.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Roughness'].default_value=rough
    shader.inputs['Metallic'].default_value=metal
    shader.inputs['Base Color'].default_value=(*color,1)
    if kind:
        size=512
        rng=np.random.default_rng(SEED+sum(map(ord,name)))
        y,x=np.mgrid[0:size,0:size].astype(np.float32)/size
        variation=rng.normal(0,.018,(size,size))+.025*np.sin(x*53+np.sin(y*17))
        rgb=np.ones((size,size,3),np.float32)*np.array(color)+variation[:,:,None]
        if kind in ('stone','brick','paving'):
            rows,cols={'stone':(4,3),'brick':(8,5),'paving':(4,3)}[kind]
            row=np.floor(y*rows)
            u=(x*cols+(row%2)*.5+(.035*np.sin(y*33) if kind=='paving' else 0))%1
            v=(y*rows+(.035*np.sin(x*29) if kind=='paving' else 0))%1
            rgb+= (.045*np.sin(np.floor(x*cols+(row%2)*.5)*12.93+row*7.18))[:,:,None]
            rgb[(u<.018)|(v<.035)]*=.52
            rgb[((u>.018)&(u<.033))|((v>.035)&(v<.050))]+=.04
        elif kind=='roof':
            u=(x*8)%1; v=(y*5)%1
            rgb+=(.12*np.cos(u*TAU))[:,:,None]
            rgb[(u<.05)|(v<.033)]*=.58
        elif kind=='wood':
            rgb+=(.07*np.sin(y*230+np.sin(x*5)*3))[:,:,None]
            rgb[((y*7)%1)<.025]*=.55
        elif kind=='plaster':
            rgb+=(.025*np.sin(x*47)*np.sin(y*39))[:,:,None]
            crack=np.abs(x-.63-.022*np.sin(y*37)-.06*np.sin(y*11))<.0018
            rgb[crack&(y>.22)&(y<.79)]*=.50
            rgb[(np.sin(x*91)*np.sin(y*63)>.91)&(y<.12)]*=.67
        elif kind=='marble':
            rgb[np.abs(np.sin(x*35+np.sin(y*17)*4+np.sin(y*41)))>.96]*=.84
        elif kind=='ground':
            rgb+=(.04*np.sin(x*18+np.sin(y*32))+.04*np.sin(y*31))[:,:,None]
        rgba=np.ones((size,size,4),np.float32)
        rgba[:,:,:3]=np.clip(rgb,.025,.95)
        image=bpy.data.images.new(name+'_basecolor',size,size)
        image.pixels.foreach_set(rgba.ravel())
        image.filepath_raw=str(out/'textures'/(name+'.png'))
        image.file_format='PNG'; image.save(); image.pack()
        tex=mat.node_tree.nodes.new('ShaderNodeTexImage')
        tex.image=image; tex.extension='REPEAT'
        mat.node_tree.links.new(tex.outputs['Color'],shader.inputs['Base Color'])
        gy,gx=np.gradient(np.mean(rgba[:,:,:3],axis=2))
        normal=np.dstack((-gx*7.5,-gy*7.5,np.ones_like(gx)))
        normal/=np.linalg.norm(normal,axis=2)[:,:,None]
        rgba[:,:,:3]=normal*.5+.5
        image=bpy.data.images.new(name+'_normal',size,size)
        image.colorspace_settings.name='Non-Color'
        image.pixels.foreach_set(rgba.ravel())
        image.filepath_raw=str(out/'textures'/(name+'_normal.png'))
        image.file_format='PNG'; image.save(); image.pack()
        tex=mat.node_tree.nodes.new('ShaderNodeTexImage'); tex.image=image
        nm=mat.node_tree.nodes.new('ShaderNodeNormalMap')
        nm.inputs['Strength'].default_value=.50
        mat.node_tree.links.new(tex.outputs['Color'],nm.inputs['Color'])
        mat.node_tree.links.new(nm.outputs['Normal'],shader.inputs['Normal'])
    MATS.append(mat); SCALES.append(scale)
    return len(MATS)-1


def material(name,color,kind,out,scale=2,rough=.86,metal=0):
    if SURFACE_STYLE=='legacy':
        return legacy_material(name,color,kind,out,scale,rough,metal)
    family={'Amphora_Clay':'clay','Linen_Canopy':'linen'}.get(name,kind)
    mat=build_blender_material(name,color,family,out,scale,rough,metal,TEXTURE_SIZE,SEED+sum(map(ord,name)))
    MATS.append(mat); SCALES.append(scale)
    return len(MATS)-1


class Mesh:
    """Triangle-ready geometry and a separately collected structural collider."""
    def __init__(self,name,collect_collision=True):
        self.name=name; self.v=[]; self.f=[]; self.mi=[]; self.uv=[]; self.sm=[]
        self.physical=collect_collision
        self.cv=[]; self.cf=[]

    def face(self,vertices,mat,smooth=False):
        offset=len(self.v); self.v.extend(vertices)
        self.f.append(tuple(range(offset,offset+len(vertices))))
        self.mi.append(mat); self.sm.append(smooth)
        n=(Vector(vertices[1])-Vector(vertices[0])).cross(Vector(vertices[2])-Vector(vertices[0]))
        axis=max(range(3),key=lambda a:abs(n[a]))
        a,b=[i for i in range(3) if i!=axis]
        self.uv.append([(v[a]/SCALES[mat],v[b]/SCALES[mat]) for v in vertices])
        if self.physical:
            offset=len(self.cv); self.cv.extend(vertices)
            self.cf.append(tuple(range(offset,offset+len(vertices))))

    def box(self,center,size,mat,angle=0):
        cx,cy,cz=center; sx,sy,sz=[v*.5 for v in size]
        c,s=math.cos(angle),math.sin(angle)
        p=[(cx+x*c-y*s,cy+x*s+y*c,cz+z) for x,y,z in
           [(-sx,-sy,-sz),(sx,-sy,-sz),(sx,sy,-sz),(-sx,sy,-sz),
            (-sx,-sy,sz),(sx,-sy,sz),(sx,sy,sz),(-sx,sy,sz)]]
        for f in [(0,3,2,1),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7),(4,5,6,7)]:
            self.face([p[i] for i in f],mat)

    def cylinder(self,center,radius,depth,mat,sides=12,r_top=None):
        cx,cy,cz=center
        rt=radius if r_top is None else r_top
        bottom=[(cx+radius*math.cos(i*TAU/sides),cy+radius*math.sin(i*TAU/sides),cz-depth*.5) for i in range(sides)]
        top=[(cx+rt*math.cos(i*TAU/sides),cy+rt*math.sin(i*TAU/sides),cz+depth*.5) for i in range(sides)]
        self.face(list(reversed(bottom)),mat); self.face(top,mat)
        for i in range(sides):
            j=(i+1)%sides
            self.face([bottom[i],bottom[j],top[j],top[i]],mat,True)

    def beam(self,a,b,r,mat,sides=6):
        axis=(Vector(b)-Vector(a)).normalized()
        tangent=axis.cross(Vector((0,0,1)))
        if tangent.length<.01: tangent=Vector((1,0,0))
        tangent.normalize(); other=axis.cross(tangent).normalized()
        rings=[[tuple(Vector(p)+r*(math.cos(i*TAU/sides)*tangent+math.sin(i*TAU/sides)*other))
                for i in range(sides)] for p in (a,b)]
        self.face(list(reversed(rings[0])),mat); self.face(rings[1],mat)
        for i in range(sides):
            j=(i+1)%sides
            self.face([rings[0][i],rings[0][j],rings[1][j],rings[1][i]],mat,True)

    def column(self,x,y,base,h,r=.3,order=0):
        saved=self.physical
        self.cylinder((x,y,base+h*.5),r,h,STONE,12,r_top=r*.86)
        self.physical=False
        self.box((x,y,base+.12),(r*2.9,r*2.9,.24),STONE)
        self.cylinder((x,y,base+.35),r*1.24,.22,STONE)
        self.cylinder((x,y,base+h-.34),r*1.24,.22,STONE)
        self.box((x,y,base+h-.12),(r*3,r*3,.24),STONE)
        if order==1:
            for side in (-1,1): self.cylinder((x+side*r,y,base+h-.3),r*.4,.3,STONE,8)
        if order==2:
            for i in range(6):
                a=i*TAU/6
                self.cylinder((x+r*.73*math.cos(a),y+r*.73*math.sin(a),base+h-.5),r*.28,.4,STONE,5,r_top=.02)
        self.physical=saved

    def doorway(self,cx,cy,w,h,base,depth,mat,dw=1.6,dh=2.55,angle=0):
        c,s=math.cos(angle),math.sin(angle)
        def p(x,z): return (cx+x*c,cy+x*s,base+z)
        side=(w-dw)*.5
        for sign in (-1,1):
            self.box(p(sign*(dw+side)*.5,h*.5),(side,depth,h),mat,angle)
        if h>dh: self.box(p(0,dh+(h-dh)*.5),(dw,depth,h-dh),mat,angle)
        saved=self.physical; self.physical=False
        for sign in (-1,1): self.box(p(sign*(dw*.5+.08),dh*.5),(.16,depth+.12,dh),STONE,angle)
        self.box(p(0,dh+.11),(dw+.4,depth+.14,.22),STONE,angle)
        self.physical=saved

    def arch(self,cx,cy,base,width,height,depth,pier=.8,angle=0,mat=None,segments=10):
        mat=STONE if mat is None else mat
        radius=width*.5; outer=radius+pier; spring=height-radius-.4
        c,s=math.cos(angle),math.sin(angle)
        def p(x,y,z): return (cx+x*c-y*s,cy+x*s+y*c,base+z)
        for side in (-1,1):
            self.box(p(side*(radius+pier*.5),0,spring*.5),(pier,depth,spring),mat,angle)
        for i in range(segments):
            a=i*math.pi/segments+.005; b=(i+1)*math.pi/segments-.005
            rings=[[p(r*math.cos(t),yy,spring+r*math.sin(t)) for r,t in
                    [(radius,a),(outer,a),(outer,b),(radius,b)]]
                   for yy in (-depth*.5,depth*.5)]
            self.face(list(reversed(rings[0])),mat); self.face(rings[1],mat)
            for j in range(4):
                k=(j+1)%4
                self.face([rings[0][j],rings[0][k],rings[1][k],rings[1][j]],mat)
            for yy in (-depth*.5,depth*.5):
                points=[p(outer*math.cos(a),yy,spring+outer*math.sin(a)),
                        p(outer*math.cos(b),yy,spring+outer*math.sin(b)),
                        p(outer*math.cos(b),yy,height+.15),p(outer*math.cos(a),yy,height+.15)]
                self.face(points if yy>0 else list(reversed(points)),mat)
        self.box(p(0,0,height+.3),(outer*2,depth+.16,.30),mat,angle)

    def roof(self,cx,cy,w,d,eave,rise,hip=False):
        saved=self.physical; self.physical=False
        x0,x1,y0,y1=cx-w*.5,cx+w*.5,cy-d*.5,cy+d*.5
        if hip:
            ridge=max(0,(d-w)*.5)
            a,b=(cx,cy-ridge,eave+rise),(cx,cy+ridge,eave+rise)
            self.face([(x0,y0,eave),(x1,y0,eave),a],ROOF)
            self.face([(x1,y0,eave),(x1,y1,eave),b,a],ROOF)
            self.face([(x1,y1,eave),(x0,y1,eave),b],ROOF)
            self.face([(x0,y1,eave),(x0,y0,eave),a,b],ROOF)
            self.beam(a,b,.13,ROOF)
            for p in [(x0,y0,eave),(x1,y0,eave)]: self.beam(p,a,.11,ROOF)
            for p in [(x0,y1,eave),(x1,y1,eave)]: self.beam(p,b,.11,ROOF)
        else:
            self.face([(x0,y0,eave),(x1,y0,eave),(x1,cy,eave+rise),(x0,cy,eave+rise)],ROOF)
            self.face([(x1,y1,eave),(x0,y1,eave),(x0,cy,eave+rise),(x1,cy,eave+rise)],ROOF)
            self.face([(x0,y0,eave),(x0,cy,eave+rise),(x0,y1,eave)],PLASTER)
            self.face([(x1,y1,eave),(x1,cy,eave+rise),(x1,y0,eave)],PLASTER)
            self.beam((x0,cy,eave+rise),(x1,cy,eave+rise),.14,ROOF)
            for i in range(int(w/.8)+1):
                x=x0+i*w/max(1,int(w/.8))
                self.beam((x,y0,eave+.03),(x,cy,eave+rise+.03),.05,ROOF,5)
                self.beam((x,y1,eave+.03),(x,cy,eave+rise+.03),.05,ROOF,5)
        for yy in (y0,y1): self.box((cx,yy,eave-.10),(w,.18,.20),WOOD)
        self.physical=saved

    def finish(self):
        data=bpy.data.meshes.new(self.name)
        data.from_pydata(self.v,[],self.f); data.update()
        used=sorted(set(self.mi)); lookup={v:i for i,v in enumerate(used)}
        for i in used: data.materials.append(MATS[i])
        uv=data.uv_layers.new(name='UVMap')
        for p,mi,coords,smooth in zip(data.polygons,self.mi,self.uv,self.sm):
            p.material_index=lookup[mi]; p.use_smooth=smooth
            for li,co in zip(p.loop_indices,coords): uv.data[li].uv=co
        collider=None
        if self.cf:
            collider=bpy.data.meshes.new(self.name+'_physics')
            collider.from_pydata(self.cv,[],self.cf); collider.update()
        return data,collider


def install(key,mesh):
    PROTO[key]=mesh.finish()


def put(key,name,x,y,z=0,angle=0,scale=1,category='architecture',era=-100):
    mesh,col=PROTO[key]
    obj=bpy.data.objects.new(name,mesh); CITY.objects.link(obj)
    obj.location=(x,y,z); obj.rotation_euler[2]=angle; obj.scale=(scale,scale,scale)
    obj['module_key']=key; obj['category']=category; obj['era_min_ce']=era
    obj['imperathen_asset']='roman_test_city'
    if col:
        physics=bpy.data.objects.new(name+'_collision',col); COLLISION.objects.link(physics)
        physics.location=obj.location; physics.rotation_euler=obj.rotation_euler; physics.scale=obj.scale
        physics['era_min_ce']=era; physics['collision_mesh_only']=True
    ENTRIES.append({'name':name,'module':key,'category':category,'position_blender_m':[x,y,z],'rotation_z':angle,'scale':scale,'era_min_ce':era})
    return obj


def window(m,x,y,z,w=1.0,h=1.5,angle=0,shutters=True):
    saved=m.physical; m.physical=False
    c,s=math.cos(angle),math.sin(angle)
    def p(xx,yy,zz):return (x+xx*c-yy*s,y+xx*s+yy*c,z+zz)
    m.box(p(0,0,h*.5),(w,.06,h),DARK,angle)
    m.box(p(0,-.10,-.08),(w+.30,.30,.16),STONE,angle)
    m.box(p(0,-.05,h+.08),(w+.25,.22,.17),STONE,angle)
    for side in (-1,1):
        m.box(p(side*(w*.5+.07),-.04,h*.5),(.14,.16,h),STONE,angle)
        if shutters: m.box(p(side*(w*.5+.25),-.1,h*.5),(.32,.08,h*.95),WOOD,angle+side*.22)
    m.physical=saved


def outer_walls(m,w,d,h,wall,dw=1.8,dh=2.6):
    m.box((0,0,.1),(w,d,.2),PAVING)
    m.doorway(0,-d*.5,w,h,0,.4,wall,dw,dh)
    m.box((0,d*.5,h*.5),(w,.4,h),wall)
    for x in (-w*.5,w*.5): m.box((x,0,h*.5),(.4,d,h),wall)


def house(kind,variant):
    m=Mesh(kind+str(variant))
    wall=[PLASTER,OCHRE,RED][variant%3]
    if kind=='insula':
        w,d=18+(variant%2)*2,18
        floors=2+(variant%3>0); top=3.6+floors*3.0
        m.box((0,0,.1),(w,d,.2),PAVING)
        for i in range(4): m.doorway(-w*.5+(i+.5)*w/4,-d*.5,w/4,3.6,0,.4,wall,2.1,2.65)
        m.box((0,d*.5,top*.5),(w,.4,top),wall)
        for x in (-w*.5,w*.5):m.box((x,0,top*.5),(.4,d,top),wall)
        m.box((0,0,3.6),(w,d,.22),STONE)
        m.physical=False
        m.box((0,-d*.5,(top+3.6)*.5),(w,.4,top-3.6),wall)
        for level in range(floors):
            z=3.6+level*3.0
            m.box((0,-d*.5-.05,z),(w+.4,.30,.26),BRICK)
            for i in range(5):
                x=-w*.5+(i+.5)*w/5
                window(m,x,-d*.5-.23,z+.7)
                window(m,x,d*.5+.23,z+.7,angle=math.pi)
            for i in range(4):
                y=-d*.5+(i+.5)*d/4
                window(m,-w*.5-.23,y,z+.7,angle=-math.pi*.5)
                window(m,w*.5+.23,y,z+.7,angle=math.pi*.5)
        m.physical=True
        for i in range(5):m.column(-w*.5+i*w/4,-d*.5-2.4,0,3.2,.24)
        m.physical=False
        m.box((0,-d*.5-1.2,3.3),(w+.5,2.8,.23),STONE)
        m.roof(0,-d*.5-1.1,w+.8,3.1,3.5,.55)
        m.roof(0,0,w+1.1,d+1.1,top+.2,2.6,True)
        m.box((w*.25,d*.13,top+1.8),(1.0,1.0,3.1),BRICK)
    elif kind=='domus':
        w,d,h=26,30,4.5; outer_walls(m,w,d,h,wall,2.2,2.9)
        for x in (-5.6,5.6):
            for y in (-10,-4,4,10):m.doorway(x,y,5.5,h,0,.3,PLASTER,1.5,2.5,math.pi*.5)
        for x in (-5.2,5.2):
            for y in (-8,-4,0,4,8):m.column(x,y,.1,3.5,.22,1)
        for y in (-8.8,8.8):
            for x in (-2.5,0,2.5):m.column(x,y,.1,3.5,.22,1)
        m.box((0,0,.25),(6,8,.26),MARBLE)
        m.physical=False;m.box((0,0,.4),(5.4,7.4,.04),WATER)
        for x in (-9.3,9.3):m.roof(x,0,8.0,31,4.7,2,True)
        for y in (-11.9,11.9):m.roof(0,y,12,7.5,4.7,1.8)
        for x in (-5.2,5.2):m.box((x,0,3.7),(.55,19,.24),STONE)
        for y in (-6.4,6.4):m.box((0,y,.35),(5.4,2,.35),GARDEN)
    elif kind=='artisan':
        w,d,h=13.5,16,6.8; outer_walls(m,w,d,h,wall,2,2.6)
        m.box((0,0,3.35),(w,d,.22),WOOD)
        m.physical=False
        for x in (-4.4,0,4.4):
            window(m,x,-8.23,4.2,1.1,1.6)
            window(m,x,8.23,4.2,1.1,1.6,math.pi)
        m.box((0,-9,3.5),(6.3,2,.22),WOOD)
        for x in np.linspace(-3,3,9):m.box((float(x),-10,4.1),(.11,.11,1),WOOD)
        m.box((0,-10,4.65),(6.4,.15,.15),WOOD)
        for x in (-3,3):
            m.beam((x,-8,2.3),(x,-9.9,3.4),.1,WOOD)
            m.box((x,-9,4.65),(.15,2,.15),WOOD)
        m.roof(0,0,14.5,17,6.9,3.1)
        m.box((4.5,3.7,8.4),(1.2,1.1,3.9),BRICK)
        for x in (-4.3,4.3):
            m.box((x,-6.8,.95),(3.3,1.3,.18),WOOD)
            for dx in (-1.2,1.2):m.box((x+dx,-6.8,.45),(.15,1,.9),WOOD)
    elif kind=='atrium':
        outer_walls(m,20,24,4.5,wall,1.8,2.7)
        for x in (-3,3):
            for y in (-7,0,7):m.column(x,y,.1,3.9,.22)
        m.box((0,0,.23),(4.8,6.6,.26),STONE)
        m.physical=False;m.box((0,0,.39),(4.15,5.95,.05),WATER)
        for x in (-6.7,6.7):m.roof(x,0,7.2,25,4.65,2.2,True)
        for y in (-9.3,9.3):m.roof(0,y,6.2,6.5,4.65,1.6)
        for x in (-2.9,2.9):m.column(x,-14,0,3.25,.25)
        m.roof(0,-13,6.8,3.6,3.4,.9)
    elif kind=='villa':
        m.box((0,0,.12),(27,30,.24),PAVING)
        for cx,cy,w,d,h in [(-9.2,0,8,29,5),(1.5,10,18,9,5),(-9.2,-10,8,8.5,9.4)]:
            m.doorway(cx,cy-d*.5,w,h,0,.4,wall,1.55,2.6)
            m.box((cx,cy+d*.5,h*.5),(w,.4,h),wall)
            for x in (cx-w*.5,cx+w*.5):m.box((x,cy,h*.5),(.4,d,h),wall)
            m.roof(cx,cy,w+.8,d+.8,h+.15,2.5,True)
            if h>8:
                for x in (cx-2,cx+2):window(m,x,cy-d*.5-.24,6.3)
        m.doorway(2,-15,21,2.2,0,.4,STONE,2.1,2.1)
        m.box((13.5,0,1.1),(.45,30,2.2),STONE)
        for y in (-10,-5,0,5):m.column(-4.6,y,.12,4,.24,1)
        m.physical=False
        m.box((-4.6,-2.5,4.22),(.6,20,.26),STONE)
        m.box((4,-2,.28),(11.5,15,.3),GARDEN)
        m.box((4,-2,.48),(4,7,.23),MARBLE)
        m.box((4,-2,.61),(3.5,6.5,.04),WATER)
        for x in (0,8):
            for y in (-7,3):m.cylinder((x,y,.65),.8,1.1,CLAY,10,r_top=.9)
    return m


def stall(kind,construction):
    m=Mesh('stall_%d_%d'%(kind,construction),False)
    for x in (-1.85,1.85):
        for y in (-1.45,1.45):m.box((x,y,1.45),(.15,.15,2.9),WOOD)
    for y in (-1.45,1.45):m.box((0,y,2.85),(4,.16,.2),WOOD)
    if construction==0:
        m.face([(-2.3,-1.8,2.65),(2.3,-1.8,2.65),(2.3,0,3.25),(-2.3,0,3.25)],CLOTH)
        m.face([(-2.3,0,3.25),(2.3,0,3.25),(2.3,1.8,2.65),(-2.3,1.8,2.65)],RED if kind%2 else OCHRE)
    elif construction==1:
        m.roof(0,0,4.6,3.8,2.9,.8)
        m.box((0,1.48,1),(4,.12,2),WOOD)
    else:
        for i in range(15):m.beam((-2.1+i*.3,-1.8,2.85),(-2.1+i*.3,1.8,3.15),.11,WOOD,5)
        for x in (-1.3,1.3):
            for y in (-1.25,1.25):m.cylinder((x,y,.5),.47,.22,WOOD,12)
    m.box((0,-.45,1),(3.6,1.4,.18),WOOD)
    for x in (-1.5,1.5):
        for y in (-1,.1):m.box((x,y,.49),(.13,.13,.98),WOOD)
    if kind==0:
        for n in range(24):m.cylinder((-1.5+(n%8)*.43,-.8+(n//8)*.42,1.22),.16,.25,OCHRE if n%3 else RED,7,r_top=.11)
    elif kind==1:
        for n in range(7):
            x=-1.3+n*.43
            m.box((x,-.4,1.15),(.16,.7,.12),MARBLE,.25)
            m.face([(x-.13,-.04,1.2),(x+.13,-.04,1.2),(x,.2,1.2)],MARBLE)
    elif kind==2:
        for n in range(12):m.cylinder((-1.3+(n%4)*.85,-.8+(n//4)*.5,1.23),.27,.2,OCHRE,10,r_top=.20)
    elif kind==3:
        for n in range(8):
            x=-1.4+(n%4)*.92;y=-.6+(n//4)*.9
            m.cylinder((x,y,1.39),.24,.6,CLAY,10,r_top=.18)
            m.cylinder((x,y,1.74),.1,.2,CLAY,10)
            for side in (-1,1):m.beam((x+side*.14,y,1.7),(x+side*.32,y,1.48),.035,CLAY)
    elif kind==4:
        for n in range(5):m.box((-1.45+n*.7,-.6,1.3),(.6,1.3,.22),[CLOTH,RED,OCHRE,LEAF,PLASTER][n])
        for x in (-1.3,0,1.3):m.box((x,1.35,1.9),(.75,.05,1.6),RED if x else CLOTH)
    elif kind==5:
        for n in range(6):
            x=-1.4+n*.55
            m.beam((x,-.85,1.17),(x,.05,1.17),.035,BRONZE)
            m.box((x,-.72,1.21),(.3,.1,.06),BRONZE)
        m.box((1.25,.7,.8),(.6,.55,1.5),STONE)
        m.box((1.25,.7,1.62),(.9,.42,.2),BRONZE)
    else:
        for n in range(10):
            x=-1.45+(n%5)*.72;y=-.8+(n//5)*.6
            m.cylinder((x,y,1.22),.25,.18,WOOD,10,r_top=.3)
            m.cylinder((x,y,1.35),.23,.12,[RED,OCHRE,GARDEN,CLOTH][n%4],10,r_top=0)
    return m


def dome(m,cx,cy,base,radius,h,mat,segments=32,rings=8):
    saved=m.physical;m.physical=False
    for j in range(rings):
        a=j*math.pi*.5/rings;b=(j+1)*math.pi*.5/rings
        for i in range(segments):
            aa=i*TAU/segments;bb=(i+1)*TAU/segments
            def p(t,f):return (cx+radius*math.cos(f)*math.cos(t),cy+radius*math.cos(f)*math.sin(t),base+h*math.sin(f))
            m.face([p(aa,a),p(bb,a),p(bb,b),p(aa,b)],mat,True)
    m.physical=saved


def basilica():
    m=Mesh('basilica');w,d=62,32
    m.box((0,0,.3),(65,35,.6),STONE)
    for step in range(4):m.box((0,-19.4+step*.55,(step+1)*.075),(65,.60,(step+1)*.15),STONE)
    for y in (-16,16):
        for i in range(9):m.arch(-28+i*7,y,.6,4.6,7.2,1,pier=1.1)
    for x in (-31,31):
        for y in (-10,0,10):m.arch(x,y,.6,6.5,8.8,1.1,pier=1.3,angle=math.pi*.5)
    for y in (-8,8):
        for x in range(-26,29,7):m.column(x,y,.6,7.65,.55,2)
    m.box((0,0,8.5),(w,d,.28),STONE)
    m.physical=False
    for y in (-8,8):
        m.box((0,y,11.8),(w,1,6.6),OCHRE)
        for x in range(-27,29,6):window(m,x,y+math.copysign(.56,y),11,1.8,2.5,math.pi if y>0 else 0,False)
        m.roof(0,y*1.5,63,9,8.9,2.2)
    m.roof(0,0,63.6,18.4,15.2,4.4)
    return m


def baths():
    m=Mesh('thermae')
    m.box((0,-2,.25),(78,80,.5),PAVING)
    for step in range(3):m.box((0,39.6-step*.6,(step+1)/12),(76,.65,(step+1)/6),STONE)
    for y in (-12,12):
        for x in (-18,-6,6,18):m.arch(x,y,.5,8,14.5,1.5,pier=2,mat=BRICK)
    for x in (-24,24):
        for y in (-7,7):m.arch(x,y,.5,9.5,13,1.5,pier=2,angle=math.pi*.5,mat=BRICK)
    for i in range(12):
        a=i*TAU/12
        m.arch(math.cos(a)*13,-25+math.sin(a)*13,.5,4,11,1.6,pier=1.2,angle=a+math.pi*.5)
    for x in (-33,33):
        for y in (-18,0,18):m.column(x,y,.5,6.3,.5,1)
    m.box((0,25,.52),(37,17,.3),MARBLE)
    m.physical=False
    m.box((0,25,.7),(34,14,.05),WATER)
    for i in range(12):
        a=i*math.pi/12;b=(i+1)*math.pi/12
        m.face([(-25,12*math.cos(a),14.9+7*math.sin(a)),(25,12*math.cos(a),14.9+7*math.sin(a)),
                (25,12*math.cos(b),14.9+7*math.sin(b)),(-25,12*math.cos(b),14.9+7*math.sin(b))],ROOF)
    dome(m,0,-25,12.3,14,9.8,ROOF,32,10)
    for x in (-33,33):
        m.box((x,0,7),(8,58,.35),STONE);m.roof(x,0,9,59,7.3,2.4,True)
    for y in (18,32):
        for x in range(-20,21,5):m.column(x,y,.5,6.5,.38,2)
        m.box((0,y,7.1),(44,.8,.35),STONE)
    return m


def portico():
    m=Mesh('portico');m.box((0,0,.18),(70,6,.36),MARBLE)
    for x in np.linspace(-34,34,17):
        for y in (-2,2):m.column(float(x),y,.36,5.2,.32,1)
    m.physical=False
    m.box((0,0,5.72),(70.6,6.4,.35),STONE)
    m.roof(0,0,71.2,7,5.9,1.7)
    return m


def craft_shop(kind):
    m=Mesh('craft_shop_'+str(kind));outer_walls(m,11.5,10,3.7,[OCHRE,RED,PLASTER][kind],3.4,2.7)
    m.roof(0,0,12.5,11,3.8,2)
    m.physical=False
    for x in (-4.8,4.8):m.box((x,-7.6,1.55),(.14,.14,3.1),WOOD)
    m.face([(-5,-5.3,3.35),(5,-5.3,3.35),(5,-7.9,2.9),(-5,-7.9,2.9)],CLOTH)
    m.box((3.5,-3.8,.95),(3,1.3,.2),WOOD)
    if kind==0:
        m.cylinder((0,2,.65),1.65,1.3,BRICK,18)
        dome(m,0,2,1.3,1.65,1.55,BRICK,24,8)
        m.arch(0,.48,.85,.85,1.15,.3,pier=.18,segments=8)
        m.box((0,.43,1.25),(.7,.08,.7),DARK)
        m.box((.4,2.4,3.4),(.7,.7,2.7),BRICK)
        for x in (-3,3):
            m.cylinder((x,2,.5),.65,1,STONE)
            m.cylinder((x,2,1.2),.76,.4,STONE,r_top=.58)
            m.beam((x,2,1.5),(x+1.1,2,1.5),.065,WOOD)
        for n in range(8):m.cylinder((2.3+(n%4)*.7,-4+(n//4)*.5,1.17),.25,.2,OCHRE,10,r_top=.2)
    elif kind==1:
        m.box((0,3.5,.7),(2.9,2,1.4),BRICK);m.box((0,3.5,1.47),(2.4,1.5,.18),DARK)
        m.box((0,3.8,2.6),(2.2,1.5,.45),BRONZE);m.box((0,4.1,4.2),(.85,.85,3.1),BRICK)
        m.cylinder((-2,-1,.5),.48,1,WOOD,9)
        m.box((-2,-1,1.2),(1.15,.5,.35),BRONZE)
        m.beam((-2,-1,1.2),(-.9,-1,1.2),.14,BRONZE)
        for n in range(5):m.beam((3.3+n*.2,2,0),(3.3+n*.2,2,2.1),.045,BRONZE)
    else:
        for x in (-4.8,4.8):
            for z in (.65,1.5,2.35):
                m.box((x,1.5,z),(1.1,5.5,.15),WOOD)
                for n in range(5):m.cylinder((x,-.5+n,z+.34),.22,.5,CLAY,9,r_top=.15)
    return m


def canopy(m,cx,cy,cz,rx,ry,rz,phase=0):
    saved=m.physical;m.physical=False
    rings=6;segments=12
    def point(j,i):
        phi=-math.pi*.5+j*math.pi/rings;theta=i*TAU/segments
        ripple=1+.09*math.sin(theta*3+phi*5+phase)+.055*math.sin(theta*7-phi*3)
        return (cx+rx*max(.001,math.cos(phi))*math.cos(theta)*ripple,
                cy+ry*max(.001,math.cos(phi))*math.sin(theta)*ripple,
                cz+rz*math.sin(phi)*ripple)
    for j in range(rings):
        for i in range(segments):
            m.face([point(j,i),point(j,i+1),point(j+1,i+1),point(j+1,i)],LEAF,True)
    m.physical=saved


def clutter(kind):
    m=Mesh('street_clutter_'+str(kind),False)
    if kind==0:
        for i in range(3):
            x=-1.0+i*.65
            m.cylinder((x,0,.44),.25,.72,CLAY,10,r_top=.15)
            m.cylinder((x,0,.87),.09,.16,CLAY,10)
            m.beam((x+.12,0,.8),(x+.29,0,.58),.035,CLAY)
        m.box((.85,.2,.35),(.8,.7,.7),WOOD)
        for z in (.12,.55):m.box((.85,-.16,z),(.9,.08,.08),BRONZE)
    elif kind==1:
        m.cylinder((0,0,.4),.65,.8,CLAY,12,r_top=.78)
        m.cylinder((0,0,.83),.69,.08,GARDEN,12)
        m.beam((0,0,.8),(.1,0,2.5),.10,WOOD,7)
        canopy(m,.1,0,2.6,1.0,.8,1.15,.4)
        for x in (-1.4,1.35):
            m.cylinder((x,.1,.48),.35,.9,WOOD,12,r_top=.32)
            for z in (.15,.78):m.cylinder((x,.1,z),.36,.055,BRONZE,12)
    else:
        for x in (-1,1):m.box((x,0,.35),(.25,.55,.7),STONE)
        m.box((0,0,.77),(2.7,.7,.2),MARBLE)
        m.box((1.8,.1,.38),(.6,.6,.75),WOOD)
        for i in range(4):m.cylinder((1.8,.1,.86+i*.14),.28,.12,OCHRE,10,r_top=.24)
    return m


def tree(pine=False):
    m=Mesh('pine' if pine else 'cypress',False)
    if not pine:
        m.cylinder((0,0,2.2),.21,4.4,WOOD,7,r_top=.12)
        for z,r,h in [(3.6,1.45,4.5),(5,1.2,4.7),(6.5,.85,4.2),(7.8,.5,3.1)]:
            m.cylinder((0,0,z),r,h,LEAF,10,r_top=.06)
    else:
        m.beam((0,0,0),(.45,0,7.5),.35,WOOD,8)
        for i in range(7):
            a=i*TAU/7;end=(math.cos(a)*3.5,math.sin(a)*3.5,9+(i%2)*.8)
            m.beam((.3,0,5.2),end,.17,WOOD)
            canopy(m,end[0],end[1],end[2]+.1,2.8,2.6,1.45,i*.7)
        canopy(m,0,0,10,3.6,3.4,1.5,.3)
    return m


def fountain():
    m=Mesh('fountain')
    m.cylinder((0,0,.25),3.4,.5,STONE,24)
    m.cylinder((0,0,.58),2.9,.4,MARBLE,24)
    m.cylinder((0,0,1.5),.5,2,STONE,r_top=.34)
    m.physical=False
    m.cylinder((0,0,.82),2.6,.05,WATER,24)
    m.cylinder((0,0,2.55),1.3,.24,MARBLE,20,r_top=1.5)
    m.cylinder((0,0,2.72),1.33,.05,WATER,20)
    m.cylinder((0,0,3.05),.15,.7,BRONZE,10,r_top=.08)
    return m


def amphitheatre():
    rx,ry=94.5,78
    for quadrant in range(4):
        m=Mesh('Colosseum_Facade_'+str(quadrant))
        for tier in range(3):
            m.physical=(tier==0)
            base=tier*12.15
            for n in range(quadrant*20,(quadrant+1)*20):
                a=(n+.5)*TAU/80
                tangent=math.atan2(ry*math.cos(a),-rx*math.sin(a))
                seg=math.hypot(rx*math.sin(a),ry*math.cos(a))*TAU/80
                m.arch(rx*math.cos(a),ry*math.sin(a),base,seg-1.65,10.5,2.4,pier=.8,angle=tangent)
                m.physical=False
                edge=n*TAU/80
                m.column((rx+.9)*math.cos(edge),(ry+.9)*math.sin(edge),base+.25,10.1,.52,tier)
                m.box((rx*math.cos(a),ry*math.sin(a),base+11.8),(seg+.1,3.1,.7),STONE,tangent)
                m.physical=(tier==0)
        m.physical=False
        for n in range(quadrant*20,(quadrant+1)*20):
            a=(n+.5)*TAU/80
            tangent=math.atan2(ry*math.cos(a),-rx*math.sin(a))
            seg=math.hypot(rx*math.sin(a),ry*math.cos(a))*TAU/80
            x,y=rx*math.cos(a),ry*math.sin(a)
            m.box((x,y,38.3),(seg+.1,2.35,3.1),STONE,tangent)
            m.doorway(x,y,seg+.05,5,39.85,2.35,STONE,1.35,2.6,tangent)
            m.box((x,y,46.35),(seg+.15,2.7,3),STONE,tangent)
            m.box((x,y,48),(seg+.3,3.5,.4),MARBLE,tangent)
            edge=n*TAU/80
            m.box(((rx+1.5)*math.cos(edge),(ry+1.5)*math.sin(edge),42.1),(.75,1,10.9),STONE,tangent)
            if n%2==0:m.beam(((rx-2)*math.cos(a),(ry-2)*math.sin(a),46.6),((rx-2)*math.cos(a),(ry-2)*math.sin(a),54),.18,WOOD)
        key='amphi_facade_'+str(quadrant);install(key,m)
        put(key,m.name,181,42,category='amphitheatre',era=80)
    for sector in range(8):
        m=Mesh('Colosseum_Cavea_'+str(sector))
        for j in range(36):
            q0,q1=j/36,(j+1)/36
            x0,y0=39+q0*45,24+q0*44
            x1,y1=39+q1*45,24+q1*44
            z0,z1=2+j*.92,2+(j+1)*.92
            for i in range(12):
                a=(sector+i/12)*TAU/8+(.010 if i==0 else 0);b=(sector+(i+1)/12)*TAU/8-(.010 if i==11 else 0)
                p0=(x0*math.cos(a),y0*math.sin(a),z0);p1=(x0*math.cos(b),y0*math.sin(b),z0)
                p2=(x1*math.cos(b),y1*math.sin(b),z0);p3=(x1*math.cos(a),y1*math.sin(a),z0)
                m.face([p0,p1,p2,p3],MARBLE)
                m.face([p3,p2,(p2[0],p2[1],z1),(p3[0],p3[1],z1)],STONE)
        a=sector*TAU/8
        rise=35.12/170
        for j in range(170):
            q=(j-10)/160
            m.box(((39+q*45)*math.cos(a),(24+q*44)*math.sin(a),(j+.5)*rise),(.65,.95,rise),STONE,a)
        key='cavea_'+str(sector);install(key,m);put(key,m.name,181,42,category='amphitheatre',era=80)
    m=Mesh('Colosseum_Arena')
    m.face([(38*math.cos(i*TAU/96),23*math.sin(i*TAU/96),.08) for i in range(96)],SAND)
    install('arena',m);put('arena','Colosseum_Arena',181,42,category='amphitheatre',era=80)


def aqueduct():
    for part in range(4):
        m=Mesh('Aqueduct_Sector_'+str(part))
        for i in range(9):
            x=(part*9+i)*9
            m.arch(x,0,0,6.7,16.8,3.2,pier=1.15)
            m.box((x,0,18.1),(9.1,4.1,1.6),STONE)
            m.physical=False
            for y in (-1.8,1.8):m.box((x,y,19.4),(9.1,.5,1),BRICK)
            m.box((x,0,18.7),(9.1,3,.25),WATER)
            m.physical=True
        key='aqueduct_'+str(part);install(key,m);put(key,m.name,-5,211,category='aqueduct',era=52)


def walls():
    m=Mesh('Wall_Module')
    m.box((0,0,4.4),(27.4,2.5,8.8),STONE)
    m.physical=False;m.box((0,0,8.85),(27.4,3.1,.42),STONE)
    for i in range(14):m.box((-12.7+i*1.96,0,9.5),(1.05,2.65,1),STONE)
    install('wall',m)
    for side,x,y,length,angle in [('north',0,320,820,0),('south',0,-320,820,0),('west',-410,0,640,math.pi*.5),('east',410,0,640,math.pi*.5)]:
        count=round(length/27.3)
        for n in range(count):
            local=-length*.5+(n+.5)*length/count
            if (side in ('west','east') and abs(local+65)<22) or (side in ('north','south') and abs(local+100)<22):continue
            put('wall','Wall_%s_%02d'%(side,n),x+local*math.cos(angle),y+local*math.sin(angle),angle=angle,era=271,category='city_wall')
    m=Mesh('Gate')
    m.arch(0,0,0,10.5,13,5,pier=3,segments=15)
    for x in (-11.5,11.5):
        m.cylinder((x,0,7.5),4.8,15,STONE,12)
        m.physical=False
        m.cylinder((x,0,15.1),5,.6,STONE,12)
        for i in range(12):
            a=i*TAU/12;m.box((x+4.3*math.cos(a),4.3*math.sin(a),16),(1.3,1.3,1.5),STONE,a)
        m.physical=True
    m.box((0,0,14.2),(18,5.5,1.8),BRICK)
    install('gate',m)
    for side,x,y,angle in [('west',-410,-65,math.pi*.5),('east',410,-65,math.pi*.5),('north',-100,320,0),('south',-100,-320,0)]:
        put('gate','Porta_'+side,x,y,angle=angle,era=271,category='gate')


def ground():
    m=Mesh('Ground');m.box((0,0,-.35),(920,740,.7),GROUND)
    install('ground',m);put('ground','City_Ground',0,0,category='ground',era=-1000)
    m=Mesh('Forum_Piazza');m.box((-13,10,.045),(140,108,.09),MARBLE)
    install('forum',m);put('forum','Forum_Piazza',0,0,category='public_space')
    m=Mesh('Main_Streets')
    m.box((0,-65,.055),(835,14,.11),PAVING)
    m.box((-100,0,.055),(13,655,.11),PAVING)
    m.physical=False
    for y in (-72.4,-57.6):m.box((0,y,.16),(815,.65,.32),STONE)
    install('streets',m);put('streets','Main_Streets',0,0,category='road')
    m=Mesh('Worn_Cobbles',False)
    # The 23x32 individually modeled basalt slabs need a physical-looking
    # mortar bed. Previously a bright marble plaza showed through every open
    # seam, producing implausible white stripes in actual Godot screenshots.
    # A single dark, slightly recessed non-colliding box occupies the authored
    # patch under the slabs; the original plaza/road collider stays unchanged.
    m.box((-.40,-25.9,.101),(28.2,18.8,.012),STONE)
    for row in range(23):
        for col in range(32):
            x=-13.8+col*.85+(row%2)*.425;y=-34.5+row*.78
            sx=.39+RNG.uniform(-.035,.025);sy=.35+RNG.uniform(-.025,.025)
            z=.13+RNG.uniform(-.012,.012);c=.07
            shape=[(-sx+c,-sy),(sx-c,-sy),(sx,-sy+c),(sx,sy-c),(sx-c,sy),(-sx+c,sy),(-sx,sy-c),(-sx,-sy+c)]
            top=[(x+a,y+b,z) for a,b in shape];bottom=[(x+a,y+b,.075) for a,b in shape]
            m.face(top,PAVING)
            for i in range(8):m.face([bottom[i],bottom[(i+1)%8],top[(i+1)%8],top[i]],PAVING)
    install('cobbles',m);put('cobbles','Forum_Worn_Stonework',0,0,category='detail')


def populate():
    for kind in ('insula','domus','artisan','atrium','villa'):
        for v in range(3):install(kind+str(v),house(kind,v))
    for kind in range(7):
        for build in range(3):install('stall%d%d'%(kind,build),stall(kind,build))
    for key,fn in [('basilica',basilica),('baths',baths),('portico',portico),('fountain',fountain),
                   ('cypress',lambda:tree(False)),('pine',lambda:tree(True))]:install(key,fn())
    for kind in range(3):
        install('craft'+str(kind),craft_shop(kind))
        install('clutter'+str(kind),clutter(kind))
    excluded=[(-91,-52,72,145),(75,-47,288,132),(-260,80,-165,171),(-20,196,327,225),(-420,-80,420,-50),(-113,-330,-88,330)]
    candidates=[]
    for row in range(16):
        for col in range(24):
            x=-391+34*col;y=-292+39*row
            if any(x+15>a and x-15<c and y+17>b and y-17<d for a,b,c,d in excluded):continue
            candidates.append((x,y,row,col))
    candidates.sort(key=lambda p:(p[0]**2+p[1]**2,p[1],p[0]))
    if len(candidates)<243:raise RuntimeError('Not enough non-overlapping plots')
    m=Mesh('Residential_Roads')
    kinds=['insula','domus','artisan','atrium','villa']
    for index,(x,y,row,col) in enumerate(candidates[:240]):
        kind=kinds[(index*3+row)%5];key=kind+str((row*7+col)%3)
        front_extent={'insula':12,'domus':15.5,'artisan':10,'atrium':14,'villa':15.5}[kind]
        sign=1 if row%2 else -1
        offset=sign*(16.5-front_extent)
        put(key,'Residential_%03d_%s'%(index+1,kind),x+RNG.uniform(-.35,.35),y+offset+RNG.uniform(-.15,.15),
            angle=math.pi if row%2 else 0,category='residential')
        m.box((x,y,.035),(34,39,.07),PAVING)
        m.physical=False
        m.box((x,y,.079),(29.8,32.8,.028),GROUND)
        m.physical=True
        for side in (-1,1):m.box((x+side*14.8,y,.43),(.3,31.8,.75),STONE)
        m.box((x,y-sign*15.9,.43),(29.9,.3,.75),STONE)
        m.physical=True
        if index%2==0:put('clutter'+str(index%3),'Street_Detail_%03d'%index,x+9,y+sign*15.2,angle=math.pi if row%2 else 0,category='street_detail')
        if index%11==0:put('cypress','Courtyard_Tree_'+str(index),x+14.5,y+12,scale=.55,category='vegetation')
    install('residential_roads',m);put('residential_roads','Residential_Roads',0,0,category='road')
    for n in range(63):
        kind=n%7;construction=(n//7)%3;size=n//21
        put('stall%d%d'%(kind,construction),'Market_%02d_Type%d_Build%d_Size%d'%(n+1,kind,construction,size),
            -385+n*770/62,-47,scale=[.85,1,1.2][size],category='market_stall')
    for n,(x,y,row,col) in enumerate(candidates[240:243]):
        put('craft'+str(n),['Pistrinum_Bakery','Fabrica_Blacksmith','Mercator_Store'][n],x,y,angle=math.pi if row%2 else 0,category='craft_shop')
    put('basilica','Basilica_Civica',-42,108,era=-46,category='civic')
    put('baths','Thermae_Imperiales',-213,128,era=216,category='baths')
    put('portico','Forum_Portico_West',-80,15,angle=math.pi*.5,category='portico')
    put('portico','Forum_Portico_East',59,15,angle=math.pi*.5,category='portico')
    put('fountain','Forum_Fountain',-17,-14,category='fountain')
    put('fountain','Northern_Fountain',-103,154,category='fountain')
    for n in range(52):
        x=-388+(n%26)*31;y=308 if n<26 else -308
        if abs(x+100)<12:continue
        put('cypress' if n%3 else 'pine','Avenue_Tree_'+str(n),x,y,scale=.62+RNG.random()*.22,category='vegetation')
    for n,(x,y) in enumerate([(-64,-31),(-64,53),(42,-31),(42,53),(-155,126),(-270,135),(71,129),
                              (294,10),(292,85),(78,-13),(82,123),(-15,143),(45,144),(104,145)]):
        put('pine','Garden_Pine_'+str(n),x,y,scale=.8,category='vegetation')


def set_camera(camera,position,target,lens=40):
    camera.location=position
    camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler()
    camera.data.lens=lens


def preview_setup():
    scene=bpy.context.scene
    scene.render.engine='CYCLES';scene.cycles.samples=20 if SURFACE_STYLE=='legacy' else RENDER_SAMPLES;scene.cycles.use_denoising=SURFACE_STYLE!='legacy'
    scene.render.threads_mode='FIXED';scene.render.threads=2
    scene.render.resolution_x=1600;scene.render.resolution_y=1100
    scene.render.resolution_percentage=100;scene.render.image_settings.file_format='PNG'
    world=bpy.data.worlds.new('Mediterranean_Sky');scene.world=world;world.use_nodes=True
    world.node_tree.nodes['Background'].inputs[0].default_value=(.55,.68,.86,1)
    world.node_tree.nodes['Background'].inputs[1].default_value=.42
    light=bpy.data.lights.new('Mediterranean_Sun','SUN');light.energy=3.4;light.angle=.12
    sun=bpy.data.objects.new('Mediterranean_Sun',light);PREVIEW.objects.link(sun)
    sun.rotation_euler=(math.radians(28),math.radians(-20),math.radians(-32))
    data=bpy.data.cameras.new('City_Preview_Camera');data.clip_end=3000
    camera=bpy.data.objects.new('City_Preview_Camera',data);PREVIEW.objects.link(camera)
    scene.camera=camera;scene.view_settings.view_transform='AgX'
    set_camera(camera,(700,-900,650),(0,15,0),43)
    return camera


def selected_export(collection,path,with_materials=True):
    for obj in bpy.context.selected_objects:obj.select_set(False)
    for obj in collection.objects:obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,
        export_extras=True,export_cameras=False,export_lights=False,export_animations=False,
        export_apply=False,export_materials='EXPORT' if with_materials else 'NONE')


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--output',required=True);parser.add_argument('--render',action='store_true')
    parser.add_argument('--surface-style',choices=['legacy','viva'],default='viva')
    parser.add_argument('--texture-size',type=int,choices=[512,1024,2048],default=1024)
    parser.add_argument('--render-samples',type=int,choices=[32,48,64,96],default=48)
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    global SURFACE_STYLE,TEXTURE_SIZE,RENDER_SAMPLES
    SURFACE_STYLE=args.surface_style;TEXTURE_SIZE=args.texture_size;RENDER_SAMPLES=args.render_samples
    out=Path(args.output).resolve();out.mkdir(parents=True,exist_ok=True);(out/'textures').mkdir(exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    global CITY,COLLISION,PREVIEW
    CITY=bpy.data.collections.new('IMPERATHEN_ROMAN_TEST_CITY')
    COLLISION=bpy.data.collections.new('SIMPLIFIED_COLLISION_NOT_RENDERED')
    PREVIEW=bpy.data.collections.new('PREVIEW_CAMERAS_AND_LIGHTS')
    for coll in (CITY,COLLISION,PREVIEW):bpy.context.scene.collection.children.link(coll)
    COLLISION.hide_render=True
    scene=bpy.context.scene;scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1
    scene['player_reference_height_m']=1.5;scene['city_mode']='free_exploration_test'
    global STONE,PLASTER,OCHRE,RED,BRICK,ROOF,WOOD,PAVING,MARBLE,DARK,BRONZE,WATER,CLAY,CLOTH,LEAF,GARDEN,GROUND,SAND
    STONE=material('Travertine',(.65,.57,.43),'stone',out,2.4)
    PLASTER=material('Lime_Plaster',(.78,.71,.57),'plaster',out)
    OCHRE=material('Ochre_Plaster',(.66,.43,.20),'plaster',out)
    RED=material('Pompeian_Red',(.42,.12,.075),'plaster',out)
    BRICK=material('Roman_Brick',(.43,.24,.14),'brick',out)
    ROOF=material('Terracotta_Tiles',(.49,.22,.105),'roof',out)
    WOOD=material('Oak_Timber',(.23,.13,.065),'wood',out)
    PAVING=material('Basalt_Paving',(.30,.31,.29),'paving',out,3)
    MARBLE=material('Warm_Marble',(.70,.64,.55),'marble',out,3,.83)
    DARK=material('Window_Recess',(.035,.027,.02),None,out)
    BRONZE=material('Aged_Bronze',(.23,.24,.12),None,out,rough=.5,metal=.65)
    WATER=material('Water_Surface',(.035,.3,.3),None,out,rough=.2,metal=.1)
    CLAY=material('Amphora_Clay',(.57,.33,.17),'plaster',out,1)
    CLOTH=material('Linen_Canopy',(.70,.61,.43),'plaster',out)
    LEAF=material('Mediterranean_Foliage',(.10,.20,.075),'ground',out)
    GARDEN=material('Garden_Soil',(.19,.14,.075),'ground',out,3)
    GROUND=material('Dry_Earth',(.39,.36,.23),'ground',out,5)
    SAND=material('Arena_Sand',(.62,.51,.32),'ground',out,4)
    ground();populate();amphitheatre();aqueduct();walls()
    for name,position in [('MESHY_TEMPLE_INSERTION_POINT',(0,55,0)),('FREE_EXPLORE_SPAWN',(0,-24,.15))]:
        obj=bpy.data.objects.new(name,None);CITY.objects.link(obj);obj.location=position
        obj['description']='Original Meshy temple anchor; 44 x 46 m reservation' if name.startswith('MESHY') else 'No forced mission; face north toward forum'
    camera=preview_setup();bpy.context.view_layer.update()
    triangles=lambda coll:sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in coll.objects if o.type=='MESH')
    manifest={'schema_version':1,'name':'IMPERATHEN Roman Free Exploration Test City','seed':SEED,
        'units':'metres','blender_up':'Z','gltf_godot_up':'Y','player_reference_height_m':1.5,
        'city_bounds_blender_m':[-410,-320,410,320],'spawn_blender_m':[0,-24,.15],'spawn_godot_m':[0,.15,24],
        'temple_anchor_blender_m':[0,55,0],'temple_anchor_godot_m':[0,0,-55],'temple_reserved_footprint_m':[44,46],
        'gallery_safe_origin_godot_m':[455,0,0],
        'mode':'free exploration test; no forced mission','accuracy':'Original fictional city. Colosseum envelope inspired by official dimensions; not archaeological survey.',
        'sources':SOURCES,'license':'Original project geometry/textures generated locally. No external artwork copied.',
        'era_gate':'Test displays all epochs. Story runtime must hide objects whose era_min_ce exceeds story year.',
        'era_note':'80 CE amphitheatre and 216 CE baths supported by sources; remaining dates are authored content-gate defaults.',
        'residential_count':sum(e['category']=='residential' for e in ENTRIES),
        'residential_archetypes':['insula','domus','artisan','atrium','villa'],
        'market_stall_count':sum(e['category']=='market_stall' for e in ENTRIES),
        'market_variety':{'goods_categories':7,'construction_forms':3,'sizes':3},
        'mesh_objects':sum(o.type=='MESH' for o in CITY.objects),
        'unique_meshes':len({o.data for o in CITY.objects if o.type=='MESH'}),
        'triangles_instanced':triangles(CITY),'collision_triangles_instanced':triangles(COLLISION),
        'entries':ENTRIES,'surface_pipeline':{'style':SURFACE_STYLE,'texture_size':512 if SURFACE_STYLE=='legacy' else TEXTURE_SIZE,'render_samples':20 if SURFACE_STYLE=='legacy' else RENDER_SAMPLES,'review_required':True},'verification':{'gltf_export':'pending','real_blender_renders':'pending','android_device':'not run','runtime_walkthrough':'not run'}}
    (out/'city_manifest.json').write_text(json.dumps(manifest,indent=2,ensure_ascii=False))
    bpy.ops.wm.save_as_mainfile(filepath=str(out/'imperathen_roman_test_city.blend'),compress=True)
    selected_export(CITY,out/'imperathen_roman_test_city.glb')
    selected_export(COLLISION,out/'roman_city_collision.glb',False)
    COLLISION.hide_viewport=True
    bpy.ops.wm.save_as_mainfile(filepath=str(out/'imperathen_roman_test_city.blend'),compress=True)
    manifest['verification']['gltf_export']='completed'
    if args.render:
        views=[('city_overview',(700,-900,650),(0,15,0),43),
               ('forum_street',(0,-24,1.45),(0,55,7),24),
               ('colosseum_close',(330,-113,65),(181,42,21),38),
               ('residential_street',(-340,-155.5,1.45),(-280,-155.5,3),28)]
        for name,pos,target,lens in views:
            set_camera(camera,pos,target,lens);scene.render.filepath=str(out/(name+'.png'))
            bpy.ops.render.render(write_still=True)
        manifest['verification']['real_blender_renders']='four Cycles renders completed; visual review required'
    (out/'city_manifest.json').write_text(json.dumps(manifest,indent=2,ensure_ascii=False))
    print('CITY_BUILD_COMPLETE',json.dumps({k:manifest[k] for k in ['mesh_objects','unique_meshes','triangles_instanced','collision_triangles_instanced','residential_count','market_stall_count']}))


if __name__=='__main__':
    main()
