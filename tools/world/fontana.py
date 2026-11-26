"""Build the original late-Republic street trough. Blender units are metres, front -Y."""
from pathlib import Path
from tempfile import TemporaryDirectory
import json
import math
import shutil
import struct

import bpy
import numpy as np
from mathutils import Vector
from PIL import Image, ImageDraw, ImageFilter

HERE = Path(__file__).resolve().parent
OUT = HERE.parents[1] / "prototype/assets/roman_quarter/fountain"
TAU = math.tau


def field(size, nx, ny, rng):
    y, x = np.mgrid[:size, :size]
    x, y = x * nx / size, y * ny / size
    ix, iy = x.astype(int), y.astype(int)
    fx, fy = x-ix, y-iy
    fx, fy = fx*fx*(3-2*fx), fy*fy*(3-2*fy)
    grid = rng.random((ny, nx))
    return ((1-fy)*((1-fx)*grid[iy%ny,ix%nx]+fx*grid[iy%ny,(ix+1)%nx])
            + fy*((1-fx)*grid[(iy+1)%ny,ix%nx]+fx*grid[(iy+1)%ny,(ix+1)%nx]))


def stone_maps(folder):
    n = 768
    rng = np.random.default_rng(5801)
    y, x = np.mgrid[:n,:n] / n
    large, fine = field(n,5,7,rng), field(n,87,130,rng)
    band = np.sin(TAU*(y*11+.43*np.sin(TAU*x)+.80*field(n,4,6,rng)))
    seam = np.clip((band-.78)*3,0,1)*(.3+.7*field(n,17,16,rng))
    layer = field(n,11,83,rng)
    cavities = Image.new("L",(n,n))
    draw = ImageDraw.Draw(cavities)
    for i in range(8700):
        a,b = rng.uniform(0,n,2)
        # Deposition beds concentrate lenticular cavities. Micro-pits remain between beds.
        pocket = layer[int(b)%n,int(a)%n]
        r = rng.uniform(.4,2.6) * (1.0 if pocket > .51 else .52)
        w,h = r*rng.uniform(1.05,3.6),r*rng.uniform(.31,.91)
        v = int(rng.uniform(75,230))
        box = (a-w,b-h,a+w,b+h)
        for ox in ([0,n] if a<w else [0,-n] if a+w>=n else [0]):
            for oy in ([0,n] if b<h else [0,-n] if b+h>=n else [0]):
                draw.ellipse((box[0]+ox,box[1]+oy,box[2]+ox,box[3]+oy),fill=v)
    pore = np.asarray(cavities.filter(ImageFilter.GaussianBlur(.48)),dtype=float)/255
    grain = rng.normal(0,.016,(n,n))
    variation = 1+(large-.5)*.17+(layer-.5)*.17+(fine-.5)*.13+grain
    color = np.array([184,174,148])*variation[:,:,None]
    color += (seam*.7)[:,:,None]*np.array([16,15,12])
    color -= pore[:,:,None]*np.array([53,50,43])
    height = .12*large+.26*layer+.19*fine+.075*seam-.24*pore+grain*.48
    return maps(folder,"Travertino",color,height,.8+.12*pore+.055*(fine-.5),0,1.9)


def bronze_maps(folder):
    n=192
    rng=np.random.default_rng(1382)
    broad, fleck=field(n,7,8,rng), field(n,29,32,rng)
    patina=np.clip((broad*.68+fleck*.32-.48)*4,0,1)
    color = np.array([96,73,43])*(.8+.4*fleck[:,:,None])
    color += patina[:,:,None]*np.array([-45,-2,13])
    h=.16*fleck+.08*patina+rng.normal(0,.019,(n,n))
    return maps(folder,"Bronzo",color,h,.42+.33*patina,.88-.47*patina,1.5)


def maps(folder,name,color,height,rough,metal,strength):
    dx=(np.roll(height,-1,1)-np.roll(height,1,1))*strength
    dy=(np.roll(height,-1,0)-np.roll(height,1,0))*strength
    norm=np.stack((-dx,dy,np.ones_like(dx)),axis=2)
    norm/=np.linalg.norm(norm,axis=2)[:,:,None]
    orm=np.stack((np.ones_like(height),rough,np.ones_like(height)*metal),axis=2)
    paths=[]
    for key,data in [("color",color/255),("normal",norm*.5+.5),("orm",orm)]:
        path=folder/(name+"_"+key+".png")
        Image.fromarray(np.uint8(np.clip(data,0,1)*255)).save(path)
        paths.append(path)
    return paths


def material(name,paths=None):
    mat=bpy.data.materials.new(name)
    mat.use_nodes=True
    nodes,links=mat.node_tree.nodes,mat.node_tree.links
    shader=nodes.get("Principled BSDF")
    color=nodes.new("ShaderNodeVertexColor")
    color.layer_name="Finish"
    if paths:
        textures=[]
        for i,path in enumerate(paths):
            img=bpy.data.images.load(str(path))
            img.pack()
            if i:
                img.colorspace_settings.name="Non-Color"
            tex=nodes.new("ShaderNodeTexImage")
            tex.image=img
            textures.append(tex)
        mul=nodes.new("ShaderNodeMixRGB")
        mul.blend_type="MULTIPLY"
        mul.inputs[0].default_value=1
        links.new(textures[0].outputs["Color"],mul.inputs[1])
        links.new(color.outputs["Color"],mul.inputs[2])
        links.new(mul.outputs[0],shader.inputs["Base Color"])
        normal=nodes.new("ShaderNodeNormalMap")
        normal.inputs["Strength"].default_value=.39
        links.new(textures[1].outputs["Color"],normal.inputs["Color"])
        links.new(normal.outputs[0],shader.inputs["Normal"])
        split=nodes.new("ShaderNodeSeparateColor")
        links.new(textures[2].outputs["Color"],split.inputs[0])
        links.new(split.outputs["Green"],shader.inputs["Roughness"])
        links.new(split.outputs["Blue"],shader.inputs["Metallic"])
    else:
        links.new(color.outputs["Color"],shader.inputs["Base Color"])
        shader.inputs["Roughness"].default_value=.24
        shader.inputs["IOR"].default_value=1.333
    return mat


def mesh(name,vertices,faces,mat,tint=(1,1,1),water=False,uv_shift=0,smooth=False):
    data=bpy.data.meshes.new(name)
    data.from_pydata(vertices,[],faces)
    data.materials.append(mat)
    data.update()
    data.uv_layers.new(name="Metres")
    colors=data.color_attributes.new(name="Finish",type="BYTE_COLOR",domain="CORNER")
    uv=data.uv_layers["Metres"]
    for poly in data.polygons:
        poly.use_smooth=smooth
        axis=max(range(3),key=lambda i:abs(poly.normal[i]))
        for idx in poly.loop_indices:
            p=data.vertices[data.loops[idx].vertex_index].co
            u,v=(p.y,p.z) if axis==0 else (p.x,p.z) if axis==1 else (p.x,p.y)
            uv.data[idx].uv=(u/.83+uv_shift,v/.83+.17*uv_shift)
            col=tint(*p) if callable(tint) else tint
            colors.data[idx].color=(*col,1)
    if data.validate(verbose=True):
        raise ValueError("Invalid mesh "+name)
    obj=bpy.data.objects.new(name,data)
    bpy.context.collection.objects.link(obj)
    return obj


def skin(name,rings,mat,tint,cap_bottom=False,cap_top=False,shift=0,smooth=False):
    n=len(rings[0])
    faces=[]
    for j in range(len(rings)-1):
        for i in range(n):
            k=(i+1)%n
            faces.append((j*n+i,j*n+k,(j+1)*n+k,(j+1)*n+i))
    if cap_bottom:
        faces.append(tuple(reversed(range(n))))
    if cap_top:
        faces.append(tuple(range((len(rings)-1)*n,len(rings)*n)))
    return mesh(name,[p for ring in rings for p in ring],faces,mat,tint,uv_shift=shift,smooth=smooth)


def perimeter(w,d,r,nside=8):
    points=[]
    for side in range(4):
        sx,sy=((1,1),(-1,1),(-1,-1),(1,-1))[side]
        cx,cy=sx*(w/2-r),sy*(d/2-r)
        for k in range(7):
            a=(side+k/6)*math.pi/2
            points.append((cx+r*math.cos(a),cy+r*math.sin(a)))
        nx,ny=((-1,1),(-1,-1),(1,-1),(1,1))[side]
        a=(side+1)*math.pi/2
        x2,y2=nx*(w/2-r)+r*math.cos(a),ny*(d/2-r)+r*math.sin(a)
        x1,y1=points[-1]
        for k in range(1,nside):
            f=k/nside
            points.append((x1+(x2-x1)*f,y1+(y2-y1)*f))
    return points


def block(name,cx,cy,profile,mat,tint,shift=0,wear=False):
    rings=[]
    for w,d,r,z in profile:
        ring=[]
        for x,y in perimeter(w,d,r,18 if wear else 2):
            dz=0
            if wear and z>.68:
                # Depressions made by buckets on the public-facing lip.
                for pos,depth in [(-.68,.024),(-.56,.015),(.29,.028),(.38,.016)]:
                    dz-=depth*math.exp(-((x-pos)/.073)**2-((y+.67)/.14)**2)
                dz+=.0021*math.sin(x*22+3*y)*math.cos(24*y)
            ring.append((cx+x,cy+y,z+dz))
        rings.append(ring)
    return skin(name,rings,mat,tint,True,True,shift)


def piping(name,start,end,profiles,mat,tint,n=24):
    a,b=Vector(start),Vector(end)
    axis=(b-a).normalized()
    basis=axis.cross(Vector((1,0,0)) if abs(axis.x)<.9 else Vector((0,0,1))).normalized()
    perp=axis.cross(basis)
    rings=[]
    for f,r in profiles:
        center=a.lerp(b,f)
        rings.append([center+r*(basis*math.cos(i*TAU/n)+perp*math.sin(i*TAU/n)) for i in range(n)])
    return skin(name,rings,mat,tint,True,True,smooth=True)


def stele(mat):
    rings=[]
    for y,expand in [(.72,-.021),(.705,0),(.46,0),(.443,-.016)]:
        r=.44+expand
        outline=[(-r,.76),(r,.76),(r,1.23)]
        for i in range(1,41):
            a=i*math.pi/40
            outline.append((r*math.cos(a),1.23+r*math.sin(a)))
        rings.append([(x,y,z) for x,z in outline])
    # Successive rings travel toward -Y, which is the face normal of this X/Z contour.
    return skin("Pietra di testata arcuata",rings,mat,(.94,.965,.98),True,True,.31)


def scallop(mat):
    rows=19
    cols=75
    verts=[]
    faces=[]
    for i in range(rows):
        r=.018+.982*i/(rows-1)
        for j in range(cols):
            angle=(-.48+j/(cols-1)*.96)*math.pi
            ridge=(.5+.5*math.cos(angle*28))**1.7
            edge=.96+.04*math.cos(angle*28)
            x=.346*r*edge*math.sin(angle)
            z=1.13+.435*r*edge*math.cos(angle)
            y=.439-(math.sin(r*math.pi*.82)*.049+.036*r*ridge+.011)
            verts.append((x,y,z))
        if i:
            for j in range(cols-1):
                p=(i-1)*cols+j
                faces.append((p,p+1,p+cols+1,p+cols))
    mesh("Conchiglia incisa a ventaglio",verts,faces,mat,(1.03,1.013,.99),smooth=True)
    # Closed rim around the carved shell edge.
    for j in range(cols-1):
        p=(rows-1)*cols+j
        v=list(verts[p:p+2])
        v += [(v[1][0],.45,v[1][2]),(v[0][0],.45,v[0][2])]
        mesh("Costa conchiglia",v,[(0,3,2,1)],mat,(.88,.91,.95))


def surface_water(mat):
    # Use concentric rounded rectangles for a filled mesh, with modeled ripples
    # displaced around the stream landing point. Worn stone walls hide its edge.
    rings=[]
    for j in range(20,0,-1):
        f=j/20
        ring=[]
        for x,y in perimeter(2.09*f,1.17*f,.114*f,13):
            y+=.095*(1-f)
            rho=math.hypot(x,y-.095)
            h=.611+.0065*math.cos(48*rho)*math.exp(-rho*3.8)+.0018*math.sin(x*8+y*11)
            ring.append((x,y,h))
        rings.append(ring)
    def color(x,y,z):
        dist=math.hypot(x,y-.095)
        highlight=math.cos(dist*48)*math.exp(-dist*3.8)
        rim=max(abs(x)/1.045,abs(y)/.585)**4
        shallow=.5+.5*math.sin(9*x+3*y)*math.cos(6*y-2*x)
        return (.072+.027*highlight+.030*rim+.014*shallow,
                .149+.055*highlight+.046*rim+.023*shallow,
                .142+.049*highlight+.036*rim+.018*shallow)
    skin("Acqua increspata",rings,mat,color,cap_top=True,smooth=True)
    # A narrow continuous bief bends away from the mouth under gravity.
    stream=[]
    for i in range(29):
        t=i/28
        y=.207-.118*t
        z=1.081-.048*t-.428*t*t
        r=.012-.0035*t
        stream.append([(r*math.cos(k*TAU/9),y+r*math.sin(k*TAU/9),z) for k in reversed(range(9))])
    skin("Filo d'acqua",stream,mat,(.30,.46,.45),smooth=True)


def build(folder):
    stone=material("Travertino con pori e venature",stone_maps(folder))
    bronze=material("Bronzo brunito e patinato",bronze_maps(folder))
    water=material("Acqua della vasca")
    widths=[.81,.89,.95]
    for row in range(2):
        x=-1.325
        for i,w in enumerate(widths if not row else list(reversed(widths))):
            y=(-.425 if not row else .425)
            gray=.65+.026*((i+row*3)%4)
            block("Lastra basale",x+w/2,y,[(w-.033,.825,.035,0),(w-.006,.845,.036,.027),(w-.012,.84,.032,.106),(w-.052,.803,.03,.133)],stone,(gray,gray*.98,gray*.93),.81*i+.13*row)
            x+=w
    def finish(x,y,z):
        # Rust and mineral deposition along the inner waterline and base.
        interior = abs(x)<1.067 and abs(y)<.612
        band=math.exp(-((z-.614)/.088)**2) if interior else 0
        foot=math.exp(-((z-.177)/.09)**2)
        return (.98-.39*band-.18*foot,.98-.27*band-.17*foot,.94-.32*band-.14*foot)
    block("Vasca monolitica con bordo consumato",0,0,[
        (2.21,1.25,.14,.117),(2.29,1.33,.15,.162),(2.27,1.31,.14,.208),
        (2.21,1.25,.135,.237),(2.21,1.25,.135,.258),(2.30,1.34,.15,.327),
        (2.33,1.37,.156,.599),(2.35,1.39,.158,.645),(2.315,1.355,.15,.666),
        (2.37,1.410,.16,.69),(2.40,1.435,.16,.728),(2.395,1.43,.157,.759),
        (2.36,1.397,.16,.779),(2.141,1.187,.12,.783),(2.097,1.153,.112,.762),
        (2.067,1.131,.11,.694),(2.04,1.104,.105,.622),(2.022,1.094,.102,.604),
        (1.94,1.02,.099,.437),(1.83,.91,.125,.392)],stone,finish,.41,True)
    stele(stone)
    scallop(stone)
    for s in [-1,1]:
        # Leaded anticlastic clamps bind the upright to its seat.
        for x in [s*.47]:
            piping("Perno di fissaggio",(x,.59,.788),(x,.59,.804),
                   [(0,.037),(.74,.037),(1,.03)],bronze,(.66,.68,.64),12)
    # Cast flanged nozzle with concentric collars and an open dark bore.
    piping("Rosetta del cannello",(0,.455,1.12),(0,.36,1.12),
           [(0,.095),(.23,.108),(.53,.106),(.83,.091),(1,.080)],bronze,(.99,.98,.98),40)
    piping("Cannello cavo",(0,.38,1.12),(0,.20,1.08),
           [(0,.055),(.18,.051),(.69,.039),(.77,.046),(.96,.045),(1,.041),(1,.027),(.80,.026)],bronze,(.90,.94,.94),32)
    for i in range(4):
        a=(i+.5)*math.pi/2
        x=.077*math.cos(a);z=1.12+.077*math.sin(a)
        piping("Chiodo",(x,.368,z),(x,.344,z),[(0,.012),(.6,.014),(1,.008)],bronze,(1,.97,.91),9)
    surface_water(water)


def main():
    OUT.mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.unit_settings.system="METRIC"
    with TemporaryDirectory() as folder:
        build(Path(folder))
        # Shell returns are one continuous edge. Join the editable strips.
        rims=[o for o in bpy.context.scene.objects if o.name.startswith("Costa conchiglia")]
        for o in rims:
            o.select_set(True)
        bpy.context.view_layer.objects.active=rims[0]
        bpy.ops.object.join()
        bpy.ops.object.select_all(action="DESELECT")
        bpy.context.preferences.filepaths.save_version=0
        bpy.ops.wm.save_as_mainfile(filepath=str(HERE/"fontana.blend"),compress=True)
        # Export a single static mesh while retaining grouped parts in the source .blend.
        bpy.ops.object.select_all(action="SELECT")
        bpy.context.view_layer.objects.active=next(iter(bpy.context.scene.objects))
        bpy.ops.object.join()
        bpy.context.object.name="Fontana"
        triangles=bpy.context.object.modifiers.new("Triangolate","TRIANGULATE")
        bpy.ops.object.modifier_apply(modifier=triangles.name)
        if bpy.context.object.data.validate(verbose=True):
            raise ValueError("Invalid joined mesh")
        export=Path(folder)/"export"
        export.mkdir()
        bpy.ops.export_scene.gltf(filepath=str(export/"fontana.gltf"),export_format="GLTF_SEPARATE",
                                  export_animations=False,export_vertex_color="ACTIVE",export_yup=True,export_tangents=True)
        # Reference single copies of editable PNGs so Godot can mipmap and VRAM-compress them.
        document=json.loads((export/"fontana.gltf").read_text())
        binary=(export/document["buffers"][0].pop("uri")).read_bytes()
        for image in document["images"]:
            shutil.copyfile(export/image["uri"],OUT/image["uri"])
        metadata=json.dumps(document,separators=(",",":")).encode()
        metadata+=b" "*(-len(metadata)%4)
        binary+=b"\0"*(-len(binary)%4)
        output=struct.pack("<4sII",b"glTF",2,28+len(metadata)+len(binary))
        output+=struct.pack("<I4s",len(metadata),b"JSON")+metadata
        output+=struct.pack("<I4s",len(binary),b"BIN\0")+binary
        (OUT/"fontana.glb").write_bytes(output)


if __name__=="__main__":
    main()
