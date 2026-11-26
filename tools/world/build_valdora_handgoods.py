"""Build the physical Valdora errand items from the dimensions used by I-01/I-03.
blender -b -t 2 -P tools/world/build_valdora_handgoods.py
"""
import math
import random
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector

sys.path.insert(0,str(Path(__file__).resolve().parent))
from build_legio_artifacts import OUT, block, clear_scene, cord, finish, lathe

TAU = math.tau


def textile_and_clay(obj):
    """Bake surface colour into packed, tileable images on the existing materials."""
    mesh = obj.data
    uv = mesh.uv_layers.new(name='Surface')
    mesh.uv_layers.active = uv
    uv.active_render = True
    for polygon in mesh.polygons:
        axis = max(range(3),key=lambda a:abs(polygon.normal[a]))
        for idx in polygon.loop_indices:
            point = obj.matrix_world @ mesh.vertices[mesh.loops[idx].vertex_index].co
            pairs = ((point.y,point.z),(point.x,point.z),(point.x,point.y))
            uv.data[idx].uv = tuple(v/.072 for v in pairs[axis])
    side = 192
    y,x = np.mgrid[0:side,0:side]/side
    rng = np.random.default_rng(6182)
    grain = rng.random((side,side))
    for slot in obj.material_slots:
        mat = slot.material
        if mat.name not in ('Undyed dressing linen','Kitchen cloth','Burnished slip','Fired clay break'):
            continue
        if 'linen' in mat.name or 'cloth' in mat.name:
            across = np.cos(TAU*x*32+ .19*np.sin(TAU*y*2))
            up = np.cos(TAU*y*28+ .22*np.sin(TAU*x*3))
            check = np.cos(TAU*x*16)*np.cos(TAU*y*14)
            pattern = .85+.09*(across+up)+.11*check*(across-up)+.06*grain
        else:
            mottling = np.cos(TAU*x*3+np.sin(TAU*y*5))*np.sin(TAU*y*2+np.sin(TAU*x))
            pattern = .80+.12*mottling+.17*grain
            pattern += np.where(grain>.975,.24,0) - np.where(grain<.05,.18,0)
        bsdf = mat.node_tree.nodes.get('Principled BSDF')
        rgba = np.ones((side,side,4),dtype='f4')
        for axis in range(3):
            rgba[:,:,axis] = np.clip(float(bsdf.inputs['Base Color'].default_value[axis]) * pattern,0,1)
        image = bpy.data.images.new(mat.name,width=side,height=side,alpha=False)
        image.pixels.foreach_set(rgba.ravel())
        image.pack()
        texture = mat.node_tree.nodes.new('ShaderNodeTexImage')
        texture.image = image
        # Keep UV selection explicit on meshes imported from Blender primitives.
        uvnode = mat.node_tree.nodes.new('ShaderNodeUVMap')
        uvnode.uv_map = uv.name
        mat.node_tree.links.new(uvnode.outputs['UV'],texture.inputs['Vector'])
        mat.node_tree.links.new(texture.outputs['Color'],bsdf.inputs['Base Color'])


def save(id):
    """Join the evaluated parts by material so the weave and twine batch together."""
    bpy.ops.object.select_all(action='SELECT')
    parts = list(bpy.context.selected_objects)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.convert(target='MESH')
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.join()
    if id == 'neighbour_basket':
        trim=bpy.context.object.modifiers.new('Reduce hidden weave facets','DECIMATE')
        trim.ratio=.70
        bpy.ops.object.modifier_apply(modifier=trim.name)
    if id in ('valdora_keepsake','kitchen_parcel','healer_parcel'):
        textile_and_clay(bpy.context.object)
    bpy.context.object.name = id
    bpy.context.scene.cursor.location = (0,0,0)
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    path = OUT / (id+'.glb')
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',export_animations=False,
                              export_skins=False,export_morph=False,export_apply=True)
    print('VALDORA_ITEM',id,path.stat().st_size)


def tube(name,points,radius,mat):
    curve=bpy.data.curves.new(name,'CURVE')
    curve.dimensions='3D'
    curve.resolution_u=1
    curve.bevel_resolution=0
    curve.bevel_depth=radius
    curve.use_fill_caps=True
    line=curve.splines.new('POLY')
    line.points.add(len(points)-1)
    for point,xyz in zip(line.points,points):
        point.co=(*xyz,1)
    obj=bpy.data.objects.new(name,curve)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    return obj


def oval_point(angle,rx,ry,z):
    return (rx*math.cos(angle),ry*math.sin(angle),z)


def coin():
    clear_scene()
    silver=finish('Struck silver',(.47,.45,.405),.44,.78)
    high=finish('Raised device',(.64,.60,.52),.46,.73)
    flan=lathe('Hand struck flan',[(0,.0084),(.0003,.0091),(.0016,.0092),(.0020,.00865)],silver)
    for v in flan.data.vertices:
        a=math.atan2(v.co.y,v.co.x)
        fac=1 + .026*math.sin(3*a)+.012*math.cos(7*a)
        v.co.x *= fac
        v.co.y *= fac
    tube('Pellet border',[oval_point(TAU*i/60,.0082,.00815,.00199) for i in range(61)],.00014,high)
    tube('Grain stem',[(0,-.005,.00201),(-.001,.001,.00205),(.0002,.0058,.00206)],.00034,high)
    for i in range(4):
        y=-.0038+i*.00175
        for side in (-1,1):
            cord('Raised ear',[(0,y,.002),(.0018*side,y+.00065,.0022),
                                 (.0031*side,y+.00235,.0020)],.00036,high)
    save('household_denar')


def basket():
    clear_scene()
    rods=[finish('Oiled willow',(.31,.166,.069),.87),finish('Light willow',(.42,.26,.125),.87)]
    for level in range(15):
        z=.013+level*.0093
        scale=.84+.17*level/14
        pts=[]
        for i in range(73):
            a=TAU*i/72
            weave=1+.024*math.cos(a*12+level*math.pi)
            pts.append(oval_point(a,.160*scale*weave,.113*scale*weave,z))
        tube('Weft',pts,.0051,rods[level%2])
    for j in range(24):
        a=j*TAU/24
        pts=[]
        for k in range(15):
            scale=.84+.17*k/14 + .017*math.cos(k*math.pi/2+j*math.pi)
            pts.append(oval_point(a,.160*scale,.113*scale,.008+.147*k/14))
        tube('Upright',pts,.0043,rods[j%2])
    for z in [.004,.153,.158]:
        sc=.84 if z<.01 else 1.01
        tube('Bound rim',[oval_point(TAU*k/96,.161*sc,.114*sc,z) for k in range(97)],.005,rods[0])
    floor=lathe('Woven bottom',[(.002,.12),(.008,.12)],rods[0],32)
    floor.scale.y=.76
    for i in range(3):
        pts=[]
        for k in range(61):
            a=math.pi*k/60
            twist=i*TAU/3+a*15
            pts.append((.162*math.cos(a)+.0027*math.cos(twist),.004*math.sin(twist),
                        .148+.155*math.sin(a)+.0027*math.cos(twist)))
        tube('Braided handle',pts,.0036,rods[i%2])
    save('neighbour_basket')


def crockery(id,owner=None):
    clear_scene()
    if owner is None:
        clay=finish('Fired water jug',(.54,.281,.137),.81)
        profile=[(0,.072),(.058,.12),(.173,.149),(.274,.115),(.312,.058),(.365,.055),(.370,.067),
                 (.389,.067),(.389,.046),(.346,.046),(.317,.038)]
        lathe('Family water jug',profile,clay,36)
        cord('Pulled clay handle',[(.057,0,.356),(.122,0,.354),(.164,0,.301),(.157,0,.232),
                                  (.133,0,.205)],.011,clay)
    else:
        colors={'julia':(.38,.17,.082),'silvanus':(.26,.123,.072),'player':(.54,.28,.14)}
        clay=finish('Family earthenware',colors[owner],.86)
        # The same bent rim as the original family cup in i01_props.gd.
        cup=lathe('Family cup',[(0,.07),(.02,.075),(.13,.095),(.15,.105),(.15,.083),(.035,.071)],clay,32)
        if owner=='player':
            for v in cup.data.vertices:
                v.co.x += .252*v.co.z
        for z in (.108,.116):
            shift=.252*z if owner=='player' else 0
            tube('Wheel line',[(.094*math.cos(TAU*k/40)+shift,.094*math.sin(TAU*k/40),z)
                               for k in range(41)],.0018,clay)
    save(id)


def parcel(id,healer=False):
    clear_scene()
    linen=finish('Undyed dressing linen' if healer else 'Kitchen cloth',
                 (.61,.55,.41) if healer else (.37,.276,.153),.96)
    binding=finish('Woven cord',(.25,.134,.055),.9)
    x,y,z=(.066,.057,.036) if healer else (.116,.087,.065)
    # Rounded, asymmetric cloth wrapping. Fluting and clipped corners make
    # the two tie paths compress the textile at their crossings.
    vertices, faces = [], []
    rings, steps = 16, 72
    for j in range(rings+1):
        phi = -.5*math.pi + math.pi*(j+.002)/(rings+.004)
        for i in range(steps):
            a = TAU*i/steps
            def power(v,e):
                return math.copysign(abs(v)**e,v)
            dx = power(math.cos(a),.56)
            dy = power(math.sin(a),.60)
            radius = math.cos(phi)**.42
            fold = 1+.053*math.sin(13*a+2.5*phi)+.02*math.cos(7*a-4*phi)
            pinch = .08*math.exp(-((abs(dx)-.04)/.19)**2) + .075*math.exp(-((abs(dy)-.08)/.18)**2)
            height = z*(1+power(math.sin(phi),.56)*(1-pinch))+.005*math.cos(13*a+phi)*radius
            vertices.append((x*dx*radius*fold,y*dy*radius*fold,height))
    for j in range(rings):
        for i in range(steps):
            n=(i+1)%steps
            faces.append((j*steps+i,j*steps+n,(j+1)*steps+n,(j+1)*steps+i))
    faces.extend([tuple(reversed(range(steps))),tuple(range(rings*steps,(rings+1)*steps))])
    mesh=bpy.data.meshes.new('Tied linen')
    mesh.from_pydata(vertices,[],faces)
    bag=bpy.data.objects.new('Soft wrapped parcel',mesh)
    bpy.context.collection.objects.link(bag)
    mesh.materials.append(linen)
    for polygon in mesh.polygons:
        polygon.use_smooth=True
    # Folded hems draw the wrapping closed across the top and sides.
    for side in (-1,1):
        cord('Fold in linen',[(side*x*.92,-y*.9,z*.6),(side*x*.90,-y*.70,z*1.76),
                              (side*x*.38,-y*.27,z*2.02),(side*x*.12,y*.2,z*2.02)],.0028,linen)
    for along in (False,True):
        h=y if along else x
        pts=[(-h*.8,.002),(-h*.99,z*.30),(-h*.99,z*1.67),(-h*.8,z*1.98),
             (0,z*2.03),(h*.8,z*1.98),(h*.99,z*1.67),(h*.99,z*.30),(h*.8,.002),(-h*.8,.002)]
        tube('Cord around parcel',[(0,t,b) if along else (t,0,b) for t,b in pts],.0024,binding)
    for s in (-1,1):
        cord('Cord knot',[(0,0,2*z+.004),(s*x*.13,s*y*.20,2*z+.012),(s*x*.28,s*y*.26,2*z+.007),
                          (s*x*.17,-s*y*.03,2*z+.005),(0,0,2*z+.004)],.0021,binding)
    save(id)


def bundle():
    clear_scene()
    bark=finish('Split bark',(.20,.106,.045),.9)
    wood=finish('Split grain',(.50,.331,.170),.92)
    twine=finish('Bast rope',(.43,.32,.17),.94)
    r=random.Random(9021)
    for i in range(7):
        radius=r.uniform(.014,.021)
        length=r.uniform(.35,.42)
        side=(i%4-1.5)*.032+(.016 if i>3 else 0)
        z=.021+.03*(i//4)
        stick=lathe('Split stick',[(0,radius*.85),(.02,radius),(length*.75,radius*.96),(length,radius*.79)],bark,7)
        stick.data.materials.append(wood)
        for p in stick.data.polygons:
            if p.index%7 in (1,2) or abs(p.normal.z)>.8:
                p.material_index=1
        stick.rotation_euler=(math.pi/2,r.uniform(-.04,.04),r.uniform(-.035,.035))
        stick.location=(side,length/2,z)
    for y in (-.091,.09):
        tube('Twine',[(.071*math.cos(TAU*i/48),y,.035+.034*math.sin(TAU*i/48))
                      for i in range(49)],.0024,twine)
    save('split_kindling')


def fitting():
    clear_scene()
    iron=finish('Blackened forged iron',(.115,.103,.088),.56,.71)
    polished=finish('Burnished iron',(.262,.238,.199),.39,.78)
    for side in (-1,1):
        foot=lathe('Mounting stud',[(0,.014),(.002,.015),(.005,.010),(.009,.006)],iron,24)
        foot.location.x=side*.054
        cord('Pivot eye',[(side*.054,-.005,.004),(side*.054,-.012,.021),
                          (side*.054,.005,.023),(side*.054,.010,.005)],.0032,polished)
    cord('Forged pull', [(-.054,.002,.019),(-.057,-.021,.017),(-.046,-.043,.017),
                         (0,-.049,.017),(.046,-.043,.017),(.057,-.021,.017),(.054,.002,.019)],.004,iron)
    save('chest_handle')


def keepsake():
    clear_scene()
    earth=finish('Fired clay break',(.40,.195,.109),.90)
    slip=finish('Burnished slip',(.26,.094,.05),.71)
    pts=[(-.031,-.019),(-.019,-.025),(.006,-.023),(.028,-.013),(.024,.002),(.014,.006),
         (.012,.018),(-.002,.024),(-.012,.013),(-.027,.008)]
    pts=[(x,y) for x,y in pts]
    rng=random.Random(14)
    outline=[]
    for i,(x,y) in enumerate(pts):
        bx,by=pts[(i+1)%len(pts)]
        for k in range(4):
            t=k/4
            outline.append((x+(bx-x)*t+rng.uniform(-.0014,.0014),y+(by-y)*t+rng.uniform(-.001,.001)))
    n=len(outline)
    verts=[]
    for level in range(2):
        for ring in range(1,8):
            for x,y in outline:
                xx,yy=x*ring/7,y*ring/7
                h=.0002*math.sin(xx*271+yy*96)+.00022*math.cos(yy*339)+.007*(xx/.031)**2
                verts.append((xx,yy,h + level*(.0039+.0009*math.cos(y*133))))
    faces=[];indices=[]
    for level in range(2):
        faces.append(tuple(level*7*n+k for k in (range(n) if level else reversed(range(n)))))
        indices.append(level)
        for j in range(6):
            for i in range(n):
                k=(i+1)%n
                face=[level*7*n+j*n+i,level*7*n+j*n+k,level*7*n+(j+1)*n+k,level*7*n+(j+1)*n+i]
                faces.append(tuple(reversed(face)) if level else tuple(face));indices.append(level)
    for i in range(n):
        k=(i+1)%n
        faces.append((6*n+i,6*n+k,13*n+k,13*n+i));indices.append(0)
    mesh=bpy.data.meshes.new('Fractured earthenware')
    mesh.from_pydata(verts,[],faces)
    piece=bpy.data.objects.new('Uninscribed potsherd',mesh)
    bpy.context.collection.objects.link(piece)
    piece.data.materials.append(earth)
    piece.data.materials.append(slip)
    for poly,slot in zip(mesh.polygons,indices):
        poly.material_index=slot
        poly.use_smooth=poly.index<len(faces)-n
    save('valdora_keepsake')


def shield():
    clear_scene()
    wood=finish('Timber boards',(.31,.20,.11),.85)
    dark=finish('Alternate board',(.25,.15,.073),.88)
    hide=finish('Leather binding',(.16,.086,.044),.83)
    # A light local wooden loan shield with a handgrip and a hide edge.
    rx,ry=.228,.308
    count=9
    for i in range(count):
        xlo=-rx+2*rx*i/count+.0008
        xhi=-rx+2*rx*(i+1)/count-.0008
        xs=[xlo+(xhi-xlo)*k/5 for k in range(6)]
        ring=[(x,ry*math.sqrt(max(0,1-(x/rx)**2))) for x in xs]
        ring+=[(x,-ry*math.sqrt(max(0,1-(x/rx)**2))) for x in reversed(xs)]
        n=len(ring)
        mesh=bpy.data.meshes.new('Wood plank')
        mesh.from_pydata([(x,y,z+.025*(1-(x/rx)**2)) for z in (.0,.009) for x,y in ring],[],
                         [tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]+[(k,(k+1)%n,(k+1)%n+n,k+n) for k in range(n)])
        plank=bpy.data.objects.new('Curved plank',mesh)
        bpy.context.collection.objects.link(plank)
        mesh.materials.append(wood if i%3 else dark)
    tube('Rawhide rim',[(rx*math.cos(TAU*k/96),ry*math.sin(TAU*k/96),.005+.025*math.sin(TAU*k/96)**2)
                        for k in range(97)],.007,hide)
    cord('Handgrip',[(-.083,0,.020),(-.05,0,-.035),(.05,0,-.035),(.083,0,.020)],.011,wood)
    save('watch_wood_shield')


OUT.mkdir(parents=True,exist_ok=True)
if '--surfaces' in sys.argv:
    parcel('kitchen_parcel')
    parcel('healer_parcel',True)
    keepsake()
else:
    coin()
    basket()
    crockery('water_pitcher')
    for member in ('julia','silvanus','player'):
        crockery('cup_'+member,member)
    parcel('kitchen_parcel')
    parcel('healer_parcel',True)
    bundle()
    fitting()
    keepsake()
    shield()
