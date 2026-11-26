"""Original Roman rural trading stop. Blender -b -P tools/world/build_willow_waystation.py.
Metric authored meshes; each export is a reusable placement anchored at ground level.
Earth-sunk foundations allow individual buildings to follow the streamed hill.
"""
import math
import random
from pathlib import Path
import bpy
from mathutils import Vector

OUT = Path(__file__).resolve().parents[2] / "prototype/assets/world/waystation"
rng = random.Random(12758)
palette = {
    "lime": (0.78, 0.67, 0.49), "wash": (0.57, 0.36, 0.21),
    "clay": (0.49, 0.19, 0.10), "clay_light": (0.62, 0.28, 0.13),
    "clay_dark": (0.36, 0.13, 0.07), "oak": (0.24, 0.14, 0.07),
    "plank": (0.40, 0.26, 0.13), "iron": (0.15, 0.14, 0.12),
    "stone": (0.43, 0.42, 0.34), "linen": (0.78, 0.70, 0.48),
    "olive": (0.19, 0.31, 0.12), "leaf": (0.32, 0.43, 0.16),
    "shade": (0.10, 0.18, 0.07), "water": (0.17, 0.37, 0.39)
}
materials = {}


class Mesh:
    def __init__(self, name):
        self.name, self.vertices, self.faces, self.slots = name, [], [], []

    def shape(self, vertices, polygons, color):
        start = len(self.vertices)
        self.vertices.extend(vertices)
        for polygon in polygons:
            self.faces.append(tuple(start + idx for idx in polygon))
            self.slots.append(color)

    def box(self, x, y, z, w, d, h, color):
        self.shape([(x+dx*w/2,y+dy*d/2,z+dz*h/2)
                    for dz in [-1,1] for dy in [-1,1] for dx in [-1,1]],
                   [(0,2,3,1),(4,5,7,6),(0,1,5,4),(1,3,7,5),(3,2,6,7),(2,0,4,6)], color)

    def rod(self, a, b, r, end_r, color, sides=8):
        a, b = Vector(a), Vector(b)
        axis = (b-a).normalized()
        ref = Vector((1,0,0)) if abs(axis.x)<0.85 else Vector((0,1,0))
        u, v = axis.cross(ref).normalized(), axis.cross(axis.cross(ref)).normalized()
        pts = [tuple(c+radius*(u*math.cos(i*math.tau/sides)+v*math.sin(i*math.tau/sides)))
               for c,radius in [(a,r),(b,end_r)] for i in range(sides)]
        faces = [(i,(i+1)%sides,(i+1)%sides+sides,i+sides) for i in range(sides)]
        self.shape(pts, faces+[tuple(reversed(range(sides))),tuple(range(sides,2*sides))],color)

    def pot(self,x,y,z,scale):
        profile=[(0,.105),(.07,.15),(.24,.26),(.41,.235),(.50,.15),(.61,.11),(.65,.14),(.67,.14),(.67,.095),(.60,.094)]
        pts=[(x+r*scale*math.cos(i*math.tau/14),y+r*scale*math.sin(i*math.tau/14),z+h*scale)
             for h,r in profile for i in range(14)]
        faces=[(j*14+i,j*14+(i+1)%14,(j+1)*14+(i+1)%14,(j+1)*14+i)
               for j in range(len(profile)-1) for i in range(14)]
        self.shape(pts,faces,"clay_light")
        for side in [-1,1]:
            path=[(.12,.59),(.255,.57),(.28,.46),(.23,.39)]
            for (r,h),(s,k) in zip(path,path[1:]):
                self.rod((x+side*r*scale,y,z+h*scale),(x+side*s*scale,y,z+k*scale),.018*scale,.023*scale,"clay",6)

    def object(self):
        mesh=bpy.data.meshes.new(self.name)
        mesh.from_pydata(self.vertices,[],self.faces)
        colors=sorted(set(self.slots))
        for key in colors:
            mesh.materials.append(materials[key])
        indexes={key:i for i,key in enumerate(colors)}
        for face,key in zip(mesh.polygons,self.slots):
            face.material_index=indexes[key]
        mesh.update()
        obj=bpy.data.objects.new(self.name,mesh)
        bpy.context.collection.objects.link(obj)
        return obj


def export(name, models):
    bpy.ops.object.select_all(action="DESELECT")
    for model in models:
        model.object().select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+".glb")),export_format="GLB",
                              use_selection=True,export_yup=True,export_extras=False)
    bpy.ops.object.delete()


def roof(m,w,d,z,rise):
    # Interleaved raised covers over long, gently projecting tegula courses.
    for sign in [-1,1]:
        end=sign*(d/2+.4)
        seq=range(5)
        cols=math.ceil((w+.84)/.43)
        tile_width=(w+.84)/cols
        for j in seq:
            y0=end*j/5
            y1=end*(j+1.06)/5
            h0=z+rise*(1-j/5)
            h1=z+rise*(1-(j+1.06)/5)
            for i in range(cols):
                a=-(w+.84)/2+i*tile_width
                b=a+tile_width-.007
                quad=[(a,y0,h0),(b,y0,h0),(b,y1,h1),(a,y1,h1)]
                faces=[(0,1,2,3)] if sign>0 else [(3,2,1,0)]
                m.shape(quad,faces,rng.choice(["clay","clay_light","clay_dark","clay"]))
            for i in range(cols+1):
                x=-(w+.84)/2+i*tile_width
                m.rod((x,y0,h0+.026),(x,y1,h1+.026),.046,.043,"clay_light",6)
    m.rod((-w/2-.45,0,z+rise),(w/2+.45,0,z+rise),.105,.105,"clay_light")


def building(name,w,d,h,paint):
    m=Mesh(name)
    m.box(0,0,-.26,w,d,1,"stone")
    # Front is open at the actual entrance; no false full-width invisible wall.
    for x in [-w/2,w/2]:
        m.box(x,0,h/2,.25,d,h,"lime")
    m.box(0,d/2,h/2,w,.24,h,"lime")
    for side in [-1,1]:
        span=(w-1.55)*.5
        x=side*(.775+span/2)
        m.box(x,-d/2,h/2,span,.24,h,"lime")
        m.box(x,-d/2-.125,.46,span,.02,.55,paint)
    m.box(0,-d/2,h-.32,1.58,.27,.64,"lime")
    m.box(0,-d/2-.055,h-.62,1.90,.33,.21,"oak")
    for x in [-.79,.79]:
        m.box(x,-d/2,1,.18,.35,2.15,"oak")
    for x in [-w/2,w/2]:
        m.shape([(x,-d/2,h),(x,d/2,h),(x,0,h+1.2)],[(0,1,2) if x>0 else (2,1,0)],"wash")
    for x in [-w*.32,w*.32]:
        m.box(x,-d/2-.14,1.72,.93,.08,.83,"oak")
        for k in range(5):
            m.box(x-.34+k*.17,-d/2-.19,1.74,.13,.08,.67,"plank")
        m.box(x,-d/2-.2,1.24,1.16,.23,.13,"stone")
    roof(m,w,d,h,1.2)
    return m


def market():
    m=Mesh("CantileveredProduceStall")
    for x in [-1.7,1.7]:
        for y in [-.8,.85]:
            m.box(x,y,1.14,.13,.13,2.55,"oak")
    for i in range(12):
        x=-1.9+.32*i
        m.shape([(x,-1.25,2),(x+.32,-1.25,2),(x+.32,1.1,2.58),(x,1.1,2.58)],
                [(0,1,2,3),(3,2,1,0)],"linen" if i%4 else "clay_dark")
    for j in range(5):
        m.box(0,-.40+.20*j,.86,3.25,.19,.12,"plank")
    for x in [-1.3,1.3]:
        m.box(x,0,.4,.14,.65,.82,"oak")
    for x,y,s in [(-1,-.16,.95),(-.5,.15,1.13),(1,0,.86),(.6,-.26,.72)]:
        m.pot(x,y,.94,s)
    for i in range(3):
        m.pot(-1.7+i*.49,-1.14,.02,1.2)
    return m


def wheel(name):
    m=Mesh(name)
    for i in range(16):
        a,b=math.tau*i/16,math.tau*(i+1)/16
        point=lambda t:(0,.52*math.cos(t),.52*math.sin(t))
        m.rod(point(a),point(b),.055,.055,"iron",8)
        if i%2==0:
            m.rod((0,0,0),point(a),.048,.039,"plank",6)
    m.rod((-.13,0,0),(.13,0,0),.11,.11,"oak")
    return m


def cart():
    m=Mesh("AmphoraCart")
    for i in range(8):
        m.box(-.52+i*.15,0,.70,.14,1.82,.095,"plank")
    for s in [-1,1]:
        for i in range(3):
            m.box(s*.63,0,.81+i*.14,.085,1.86,.12,"oak" if i==2 else "plank")
        m.rod((s*.49,-.85,.64),(s*.4,-3.5,.86),.065,.045,"oak")
    m.rod((-.88,.16,.53),(.88,.16,.53),.1,.1,"iron")
    for x in [-.31,.30]:
        for y in [-.5,.0,.5]:
            m.pot(x,y,.76,.88)
    return m


def tree():
    m=Mesh("FieldWillow")
    m.rod((0,0,-.15),(.21,.06,2.15),.31,.21,"oak",10)
    for i in range(11):
        a=i*math.tau/11+rng.uniform(-.2,.2)
        r=rng.uniform(1.1,1.9)
        x,y=r*math.cos(a),r*math.sin(a)
        z=rng.uniform(2.45,3.7)
        m.rod((.15,.07,1.55),(x,y,z),.12,.045,"oak",7)
        for j in range(5):
            p=x+rng.uniform(-.55,.55)
            q=y+rng.uniform(-.55,.55)
            h=z+rng.uniform(-.25,.6)
            w=rng.uniform(.60,1.08)
            top=(p,q,h+.63)
            bottom=(p+.13,q,h-.95)
            ring=[(p+w*math.cos(k*math.tau/7),q+w*.72*math.sin(k*math.tau/7),h+rng.uniform(-.12,.12)) for k in range(7)]
            m.shape([top,bottom]+ring,[(0,2+k,2+(k+1)%7) for k in range(7)]+[(1,2+(k+1)%7,2+k) for k in range(7)],rng.choice(["shade","olive","olive","leaf"]))
    return m


def main():
    OUT.mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for name,color in palette.items():
        mat=bpy.data.materials.new(name)
        mat.diffuse_color=tuple(color)+(1,)
        mat.use_nodes=True
        bsdf=mat.node_tree.nodes.get("Principled BSDF")
        bsdf.inputs["Base Color"].default_value=(*color,1)
        bsdf.inputs["Roughness"].default_value=.34 if name=="water" else .85
        materials[name]=mat
    export("road_inn",[building("StreetInn",6.4,4.8,2.8,"clay_dark")])
    export("storehouse",[building("OliveStore",4.4,4.3,2.45,"wash")])
    export("stall",[market()])
    export("cart",[cart()])
    export("cart_wheel",[wheel("IronTyredWheel")])
    export("willow",[tree()])
    m=Mesh("StoneWateringTrough")
    m.box(0,0,-.12,2.8,1.15,.75,"stone")
    for x in [-1.3,1.3]:
        m.box(x,0,.42,.2,1.12,.52,"stone")
    for y in [-.49,.49]:
        m.box(0,y,.42,2.5,.16,.52,"stone")
    m.box(0,0,.44,2.45,.83,.03,"water")
    export("trough",[m])


if __name__=="__main__":
    main()
