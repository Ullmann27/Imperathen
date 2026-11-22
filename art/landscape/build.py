"""Original Mediterranean tree generator for Blender 4.3.2."""
import json
import math
from pathlib import Path
import random
import sys
from tempfile import TemporaryDirectory

import bpy
from mathutils import Vector

SOURCE = Path(__file__).resolve().parent
sys.path.insert(0, str(SOURCE))
from textures import bark, foliage, SEEDS

OUTPUT = SOURCE.parents[1] / "prototype/assets/landscape"
UP = Vector((0,0,1))
TAU = math.tau
# Metres. Species differ in trunk height, main fork count, crown width and habit.
SPECIES = {
    "pine": {"height":8.5,"bare":.59,"radius":3.4,"arms":10,"girth":.27},
    "oak": {"height":7.0,"bare":.32,"radius":3.05,"arms":12,"girth":.37},
    "olive": {"height":4.35,"bare":.25,"radius":2.15,"arms":9,"girth":.36},
}


def material(name, path, cutout):
    mat=bpy.data.materials.new(name)
    mat.use_nodes=True
    shader=mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Roughness"].default_value=.88
    tex=mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image=bpy.data.images.load(str(path),check_existing=True)
    tex.image.pack()
    mat.node_tree.links.new(tex.outputs["Color"],shader.inputs["Base Color"])
    if cutout:
        # glTF exporter recognizes a round-to-binary alpha as MASK. A custom
        # threshold prevents black/transparent texels around the painted leaves.
        mask=mat.node_tree.nodes.new("ShaderNodeMath")
        mask.operation="GREATER_THAN"
        mask.inputs[1].default_value=.37
        mat.node_tree.links.new(tex.outputs["Alpha"],mask.inputs[0])
        mat.node_tree.links.new(mask.outputs[0],shader.inputs["Alpha"])
    return mat


class Tree:
    def __init__(self, kind, lod):
        self.kind,self.lod=kind,lod
        self.vertices,self.faces,self.uvs,self.mats,self.smooth=[],[],[],[],[]
        self.config=SPECIES[kind]
        self.stems,self.sprays=0,0

    def face(self,indices,uv,mat,smooth=False):
        self.faces.append(indices)
        self.uvs.append(uv)
        self.mats.append(mat)
        self.smooth.append(smooth)

    def vertex(self,p):
        self.vertices.append(tuple(p))
        return len(self.vertices)-1

    def stem(self, points, radii, seed, flutes=False):
        # Rings follow the spline tangent. Old wood has irregular, twisting ribs.
        self.stems+=1
        sides=(12,8,5)[self.lod] if flutes else (7,5,3)[self.lod]
        rows=[]
        travel=[0]
        for i,(point,radius) in enumerate(zip(points,radii)):
            tangent=(points[min(i+1,len(points)-1)]-points[max(0,i-1)]).normalized()
            a=tangent.cross(Vector((1,0,0))).normalized()
            if a.length<.01:
                a=tangent.cross(Vector((0,1,0))).normalized()
            b=tangent.cross(a).normalized()
            row=[]
            for j in range(sides):
                ang=TAU*j/sides+seed*.11
                ridges=(.11*math.sin(ang*5+i*.51)+.065*math.cos(ang*3-i*.52)) if flutes else .045*math.cos(3*ang)
                row.append(self.vertex(point+radius*(1+ridges)*(math.cos(ang)*a+math.sin(ang)*b)))
            rows.append(row)
            if i:
                travel.append(travel[-1]+(point-points[i-1]).length/1.8)
        for i,(lo,hi) in enumerate(zip(rows,rows[1:])):
            for j in range(sides):
                k=(j+1)%sides
                self.face((lo[j],lo[k],hi[k],hi[j]),((j/sides,travel[i]),((j+1)/sides,travel[i]),
                          ((j+1)/sides,travel[i+1]),(j/sides,travel[i+1])),0,True)
        self.face(tuple(reversed(rows[0])),tuple((.5+.4*math.cos(j*TAU/sides),.5+.4*math.sin(j*TAU/sides)) for j in reversed(range(sides))),0)
        self.face(tuple(rows[-1]),tuple((.5+.4*math.cos(j*TAU/sides),.5+.4*math.sin(j*TAU/sides)) for j in range(sides)),0)

    def spray(self, point, direction, span, rng):
        # An arched, three-dimensional shoot with painted individual leaves.
        self.sprays+=1
        direction=direction.normalized()
        side=direction.cross(UP).normalized()
        if side.length<.001:
            side=Vector((1,0,0))
        bend=rng.uniform(-.55,.55)
        side=(side+UP*bend).normalized()
        variant=rng.randrange(4)
        rows=[]
        strip_count=2 if self.lod==0 else 1
        for i in range(strip_count+1):
            t=i/strip_count
            center=point+direction*span*t+UP*span*.16*math.sin(t*math.pi)
            half=span*(.37+.11*math.sin(t*math.pi))
            row=[self.vertex(center+side*half*s) for s in (-1,1)]
            rows.append(row)
        def uv(u,v):
            return ((variant%2+.015+u*.97)/2,(variant//2+.015+v*.97)/2)
        for i,(a,b) in enumerate(zip(rows,rows[1:])):
            self.face((a[0],a[1],b[1],b[0]),(uv(0,i/strip_count),uv(1,i/strip_count),
                      uv(1,(i+1)/strip_count),uv(0,(i+1)/strip_count)),1)

    def branch(self,start,end,radius,rng,tilt=0):
        delta=end-start
        side=Vector((-delta.y,delta.x,0)).normalized()
        mid=start+delta*.53+side*delta.length*rng.uniform(-.12,.12)+UP*tilt
        self.stem([start,mid,end],[radius,radius*.71,radius*.32],rng.random()*4)
        return mid

    def grow(self):
        c=self.config
        rng=random.Random(SEEDS[self.kind])
        h,r=c["height"],c["radius"]
        olive=self.kind=="olive"
        pine=self.kind=="pine"
        turn=rng.uniform(0,TAU)
        direction=lambda a:Vector((math.cos(a),math.sin(a),0))
        tmax=.89 if not pine else .93
        lean=direction(turn)*(.42 if pine else .24)
        def trunk(z):
            point=lean*z+direction(turn+.4+z*3)*(.14 if olive else .07)*math.sin(z*math.pi)+UP*h*z
            if olive:
                point+=direction(turn+1.7)*.46*math.sin(z*7.1)*min(1,z*7)
            return point
        levels=[0,.055,.16,c["bare"],.58,.74,tmax]
        if olive:
            levels=[0,.075,.15,.28,.43,.61,.73]
        self.stem([trunk(t) for t in levels],
                  [c["girth"]*s for s in (1.55,1.09,.98,.86,.59,.34,.12)],3,True)
        if olive:
            # Two sinuous scaffold stems grow out of the split, buttressed base.
            for sign in (-1,1):
                vec=direction(turn+sign*1.48)
                points=[vec*.24,vec*.30+UP*.49,trunk(.26)+vec*.25,
                        trunk(.37)+vec*.51,trunk(.48)+vec*.86,trunk(.62)+vec*1.19]
                self.stem(points,[.225,.191,.17,.132,.105,.039],sign+3,True)
                self.crown(points[-2],points[-1],turn+sign*1.48,random.Random(210+sign))
        for k in range(7 if self.lod<2 else 4):
            a=k*TAU/7+turn
            root=direction(a)*c["girth"]*rng.uniform(1.7,2.8)
            self.stem([root,root*.49+UP*.14,trunk(.013)+UP*(.22 if olive else .31)],
                      [.025,c["girth"]*.34,c["girth"]*.57],k,True)
        for i in range(c["arms"]):
            # Golden-angle scaffold branches fill different crown sectors.
            branch_rng=random.Random(SEEDS[self.kind]*100+i)
            a=turn+i*2.39996+branch_rng.uniform(-.16,.16)
            rank=i/(c["arms"]-1)
            z=c["bare"]+rank*(.27 if pine else .46)
            start=trunk(z)
            reach=r*(.91-.47*rank)*branch_rng.uniform(.83,1.15)
            target_z=h*((.83+.09*rank) if pine else (.60+.29*rank))
            rim=start+direction(a)*reach
            rim.z=target_z+branch_rng.uniform(-.13,.13)*(.6 if pine else 1)
            mid=self.branch(start,rim,c["girth"]*(.54-.25*rank),branch_rng,
                            -.31 if pine else -.1)
            self.crown(mid,rim,a,branch_rng)
        # Upright leading shoot closes the center without a solid crown shell.
        self.crown(trunk(.73),trunk(tmax)+UP*.09,turn+.8,rng)

    def crown(self,mid,tip,a,rng):
        r=self.config["radius"]
        pine=self.kind=="pine"
        olive=self.kind=="olive"
        count=(7,5,3)[self.lod]
        # Stable sector endpoints preserve major silhouette across tree LODs.
        for j in range(count):
            sub=random.Random(rng.randrange(1<<30))
            fraction=(j+.35)/count
            parent=mid.lerp(tip,min(.99,fraction+.05))
            angle=a+(-1 if j%2 else 1)*sub.uniform(.58,1.59)
            vec=Vector((math.cos(angle),math.sin(angle),0))
            length=r*sub.uniform(.32,.60)*(1-.20*fraction)
            end=parent+vec*length+UP*length*sub.uniform(.32,.68)
            elbow=self.branch(parent,end,.038 if olive else .057,sub,-.09)
            lateral=Vector((-vec.y,vec.x,0))
            n=(6,4,3)[self.lod]
            for k in range(n):
                origin=elbow.lerp(end,(k+.4)/n)
                jitter=1 if k%2 else -1
                ray=(vec*sub.uniform(.32,.8)+lateral*jitter*sub.uniform(.45,1.12)
                     +UP*sub.uniform(-.12,.64)).normalized()
                length2=r*sub.uniform(.15,.28)
                outer=origin+ray*length2
                if self.lod<2:
                    self.stem([origin,origin.lerp(outer,.53)+UP*.045,outer],
                              [.021 if pine else .016,.011,.004],k)
                fan=(3,3,4)[self.lod] if olive else (5,4,5)[self.lod]
                for q in range(fan):
                    heading=angle+jitter*(.42+.47*q)+sub.uniform(-.4,.4)
                    slope=sub.uniform(-.48,.64) if not pine else sub.uniform(-.28,.62)
                    shoot=Vector((math.cos(heading),math.sin(heading),slope))
                    span=r*sub.uniform(.235,.355)*(1,.98,1.55)[self.lod]
                    self.spray(origin.lerp(outer,.46+sub.random()*.54),shoot,span,sub)

    def mesh(self,name,materials):
        data=bpy.data.meshes.new(name)
        data.from_pydata(self.vertices,[],self.faces)
        data.update()
        for mat in materials:
            data.materials.append(mat)
        uv=data.uv_layers.new(name="Bark_and_leaf_atlas")
        for polygon,indices,mat,smooth in zip(data.polygons,self.uvs,self.mats,self.smooth):
            polygon.material_index=mat
            polygon.use_smooth=smooth
            for loop,coordinate in zip(polygon.loop_indices,indices):
                uv.data[loop].uv=coordinate
        obj=bpy.data.objects.new(name,data)
        bpy.context.collection.objects.link(obj)
        return obj


def build(kind,level,directory):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    mats=[material(kind+"_Bark",directory/f"{kind}_bark.png",False),
          material(kind+"_Foliage",directory/f"{kind}_leaves.png",True)]
    tree=Tree(kind,level)
    tree.grow()
    suffix=("near","mid","far")[level]
    obj=tree.mesh(kind+"_"+suffix,mats)
    if level==0:
        bpy.context.preferences.filepaths.save_version=0
        bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/(kind+".blend")),compress=True)
    path=OUTPUT/f"{kind}_{suffix}.glb"
    bpy.ops.export_scene.gltf(filepath=str(path),export_format="GLB",export_animations=False)
    obj.data.calc_loop_triangles()
    return {"kind":kind,"lod":suffix,"triangles":len(obj.data.loop_triangles),"branches":tree.stems,
            "leaf_sprays":tree.sprays,"bytes":path.stat().st_size}


if __name__=="__main__":
    OUTPUT.mkdir(parents=True,exist_ok=True)
    result=[]
    with TemporaryDirectory() as folder:
        directory=Path(folder)
        for kind in SPECIES:
            bark(kind,directory/f"{kind}_bark.png")
            foliage(kind,directory/f"{kind}_leaves.png")
            for level in range(3):
                result.append(build(kind,level,directory))
    (SOURCE/"metrics.json").write_text(json.dumps(result,indent=2)+"\n")
