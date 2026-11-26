"""Original crossroads and four walk-in corner shops for the Roman quarter."""
from dataclasses import dataclass
from pathlib import Path
import math
import random
import sys
from tempfile import TemporaryDirectory

import bpy
from mathutils import Matrix

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_roman_workshop import (Domus, beam, bench, box, export, lathe,
                                  material, position, pot, span)
from atrium_materials import SWATCHES

OUTPUT = ROOT / "prototype/assets/roman_quarter/north_junction"
FLOOR = .159
ROAD_TOP = .071
WALK_WIDTH = .68


@dataclass(frozen=True)
class Parcel:
    name: str
    depth: float
    width: float
    x: float
    z: float
    eave: float
    plaster: str
    band: str
    wares: str


# The two north fronts and two south fronts never intrude into the cross street.
# All entrances face the original street, with a raised walk around each corner.
PARCELS = (
    Parcel("Figlina",5.55,5.26,-3.98,-5.31,3.60,"intonaco","ochre","ceramic"),
    Parcel("Lanificium",5.50,4.77,3.98,-5.20,4.80,"lime","oxide","linen"),
    Parcel("Apotheca",5.14,4.21,-3.98,5.12,4.25,"intonaco","fired","grain"),
    Parcel("TabernaSeptentrionalis",5.76,4.52,3.98,5.29,3.31,"traver","oxide","wine"),
)
ATLAS = {"lime": (195,174,141), "intonaco": (179,149,112), "ochre": (163,116,63),
         "paving": (121,101,84), "basalt": (74,71,63), "traver": (185,163,132)}


def road_tile(mesh, rng, u0, u1, x0, x1):
    width, depth = u1-u0, x1-x0
    if width <= .09 or depth <= .09:
        return
    centre, centre_x = (u1+u0)/2, (x1+x0)/2
    rise = rng.uniform(.066, .092)
    paint = "tuff" if rng.randrange(25)==0 else "basalt"
    corners = [position(u0+.022,x0+.031,rise), position(u1-.023,x0+.026,rise),
               position(u1-.038,x1-.021,rise), position(u0+.037,x1-.031,rise)]
    mesh.prism(corners,(0,0,-.044),paint)
    # Exposed crowns catch light on the worn stones. There is a smooth
    # physics bed independently of these individual pieces.
    if width>.30 and depth>.30 and rng.randrange(6)==0:
        corners=[point.lerp(position(centre,centre_x,rise+.006),.37) for point in corners]
        mesh.prism(corners,(0,0,-.009),paint)


def tile_rectangle(mesh, centre_x, centre_z, length, width, seed):
    rng=random.Random(seed)
    box(mesh,centre_z,centre_x,.001,length,width,.059,"paving")
    lo,hi=centre_z-length/2,centre_z+length/2
    left,right=centre_x-width/2,centre_x+width/2
    rows=math.ceil(length/.49)
    for row in range(rows):
        u0=lo+row*length/rows
        u1=lo+(row+1)*length/rows
        x=left-.31*(row%2)
        while x<right:
            x1=x+rng.uniform(.35,.69)
            road_tile(mesh,rng,u0,u1,max(left,x),min(right,x1))
            x=x1


def roads(mesh):
    # Main street from the existing northern edge at +4 to the open north.
    tile_rectangle(mesh,0,-2.08,12.16,6.70,58116)
    # East and west arms meet the central stretch without coplanar overlap.
    tile_rectangle(mesh,-8.22,0,4.56,9.74,58117)
    tile_rectangle(mesh,8.72,0,4.56,10.74,58118)
    for side in (-1,1):
        for bounds in ((-8.16,-2.28),(2.28,4.22)):
            u0,u1=bounds
            box(mesh,(u0+u1)/2,side*(3.35+WALK_WIDTH/2),.043,u1-u0,WALK_WIDTH,.116,"paving")
            for index in range(math.ceil((u1-u0)/.63)):
                z=u0+(index+.5)*(u1-u0)/math.ceil((u1-u0)/.63)
                box(mesh,z,side*3.40,.057,.60,.102,.103,"traver")
        for u in (-2.62,2.62):
            box(mesh,u,side*8.72,.043,WALK_WIDTH,10.7,.116,"paving")
            for index in range(17):
                x=side*(3.63+index*.61)
                box(mesh,u-.31*(1 if u>0 else -1),x,.057,.102,.59,.099,"tuff")
    # An irregular cover and narrow channel flush into the physical bed.
    for x in (-4.60,4.60):
        box(mesh,0,x,.066,.57,.52,.035,"traver")
        for index in range(5):
            box(mesh,0,x+(index-2)*.075,.100,.33,.014,.016,"basalt")


def wall_and_trim(mesh, parcel):
    w=parcel.width
    e=parcel.eave
    opening=.83
    for sign in (-1,1):
        low,high=sorted((sign*opening,sign*w/2))
        span(mesh,low,high,.14,0,.28,e,parcel.plaster)
        span(mesh,low,high,-.012,.29,.026,.63,parcel.band)
        span(mesh,low,high,-.027,.92,.034,.07,"traver")
        num=max(2,round((high-low)/.44))
        for index in range(num):
            u=low+(index+.5)*(high-low)/num
            box(mesh,u,-.021,.02,(high-low)/num-.019,.10,.253,
                "traver" if index%4==0 else "tuff")
        # Open-backed doors can be walked through. The metal strap and head
        # of each fastener are real small pieces on the timber.
        u=sign*.917
        box(mesh,u,.049,.005,.13,.30,2.24,"cedar")
        for index in range(4):
            d=.22+.147*index
            box(mesh,u,d,.036,.066,.138,2.12,"beam" if index%3==0 else "cedar")
        for h in (.34,1.73):
            box(mesh,u,.46,h,.085,.52,.064,"iron")
            mesh.beam(position(u-sign*.040,.218,h+.032),
                      position(u-sign*.061,.218,h+.032),.021,"bronze",7)
        for i in range(4):
            h=1.31+.20*i
            box(mesh,sign*(w/2-.16),-.038,h,.26 if i%2 else .36,.08,.17,"tuff")
    box(mesh,0,.14,2.22,1.66,.28,e-2.22,parcel.plaster)
    box(mesh,0,-.038,2.21,1.97,.32,.138,"traver")
    box(mesh,0,.115,-.08,1.72,.34,.08,"traver")
    box(mesh,0,-.033,e-.21,w+.17,.17,.163,"beam")
    for i in range(math.ceil(w/.51)):
        u=-w/2+(i+.45)*.48
        box(mesh,u,-.112,e-.17,.094,.17,.126,"cedar")
    if e>4:
        for u in (-w*.29,w*.29):
            box(mesh,u,-.033,e-.98,.75,.065,.62,"tuff")
            box(mesh,u,-.075,e-.91,.53,.03,.47,"beam")
            box(mesh,u,-.096,e-.97,.87,.15,.085,"traver")
            for col in range(4):
                box(mesh,u+(col-1.5)*.128,-.104,e-.907,.031,.071,.44,"cedar")


def side_walls(mesh, parcel):
    w, d, e=parcel.width,parcel.depth,parcel.eave
    box(mesh,0,d/2,-.17,w,d,.17,"paving")
    for side in (-1,1):
        u=side*(w/2-.13)
        box(mesh,u,d/2,0,.26,d,e,parcel.plaster)
        box(mesh,u,d/2,.01,.314,d,.249,"tuff")
        box(mesh,u,d/2,.31,.275,d,.47,parcel.band)
        for v in (1.32,3.44):
            if v>d-.65:
                continue
            box(mesh,u+side*.135,v,1.57,.061,.62,.55,"tuff")
            box(mesh,u+side*.179,v,1.65,.033,.46,.41,"beam")
            box(mesh,u+side*.196,v,1.55,.12,.73,.093,"traver")
            for j in (-1,0,1):
                box(mesh,u+side*.201,v+j*.11,1.64,.063,.028,.44,"cedar")
    box(mesh,0,d-.13,0,w,.26,e,parcel.plaster)


def roofs(mesh, parcel):
    w,d,e=parcel.width,parcel.depth,parcel.eave
    if parcel.wares in ("grain","linen"):
        for end in (.03,d-.26):
            mesh.prism([position(-w/2,end,e),position(w/2,end,e),
                        position(0,end,e+.79)],(.26,0,0),parcel.plaster)
        for sign in (-1,1):
            pitched_tiles(mesh,-.23,d+.23,sign*(w/2+.20),0,e,e+.79,8,12,reverse=True)
    else:
        for side in (-1,1):
            u=side*(w/2-.14)
            mesh.prism([position(u,.0,e),position(u,d,e),position(u,d/2,e+.92)],
                       (-side*.24,0,0),parcel.plaster)
        for edge in (-.27,d+.24):
            pitched_tiles(mesh,-w/2-.22,w/2+.22,edge,d/2,e,e+.92,8,13)
    # Exposed masonry vents hint at work inside, still below the highest roof.
    if parcel.wares=="ceramic":
        box(mesh,.85,d*.65,e+.36,.58,.63,.74,"fired")
        box(mesh,.85,d*.65,e+1.078,.67,.69,.094,"tegula")


def pitched_tiles(mesh, start, stop, edge, roof_centre, eave, ridge, steps, columns, reverse=False):
    def surface(u,t,extra=0):
        side=edge+(roof_centre-edge)*t
        height=eave+(ridge-eave)*t+extra
        return position(side,u,height) if reverse else position(u,side,height)

    mesh.prism([surface(start,0),surface(stop,0),surface(stop,1),surface(start,1)],
               (0,0,-.089),"fired")
    for row in range(steps):
        t0=row/steps
        t1=min(1.,(row+1.18)/steps)
        for index in range(columns):
            a=start+index*(stop-start)/columns
            b=start+(index+1)*(stop-start)/columns
            drop=.006*(index%3)
            pigment="tegula" if (row+index)%5 else "fired"
            mesh.prism([surface(a+.024,t0,.037+drop),surface(b-.021,t0,.038+drop),
                        surface(b-.021,t1,.022),surface(a+.024,t1,.022)],(0,0,-.024),pigment)
            mesh.cover_tile(surface(a,t1,.045),surface(a,t0,.053+drop),.065,pigment)


def merchandise(mesh, parcel):
    x, d = .97, parcel.depth-1.15
    bench(mesh,x,d,.91,1.36,.79)
    for shelf in (.46,.91,1.32):
        box(mesh,-parcel.width/2+.56,parcel.depth/2,shelf,.55,1.64,.076,"cedar")
    for depth in (parcel.depth/2-.78,parcel.depth/2+.78):
        box(mesh,-parcel.width/2+.34,depth,.015,.104,.12,1.46,"beam")
    for index in range(4):
        u=x-.44+index*.31
        if parcel.wares in ("ceramic","wine"):
            pot(mesh,u,d,1.01,.110,.33+.06*(index%3),"tegula" if index%2 else "fired")
        else:
            w=.22+.015*(index%2)
            for k in range(4):
                box(mesh,u,d,1.013+k*.043,w,.32,.036,"ochre" if k%2 or parcel.wares=="grain" else "lime")
    for i in range(3):
        u=-1.05+i*.51
        if parcel.wares in ("wine","ceramic"):
            pot(mesh,u,parcel.depth-.67,.01,.189,.69,"fired")
        else:
            lathe(mesh,u,parcel.depth-.67,.01,[(0,.161),(.53,.217),(.57,.199),(.491,.169)],"ochre",14)


def lettering(mesh, message, axes):
    curve = bpy.data.curves.new(message, "FONT")
    curve.body = message
    curve.size = .184
    curve.align_x = "CENTER"
    object_with_text = bpy.data.objects.new(message, curve)
    bpy.context.collection.objects.link(object_with_text)
    object_with_text.matrix_world = Matrix(axes)
    bpy.context.view_layer.update()
    evaluated = object_with_text.evaluated_get(bpy.context.evaluated_depsgraph_get())
    letters = evaluated.to_mesh()
    mesh.add([object_with_text.matrix_world @ p.co for p in letters.vertices],
             [tuple(face.vertices) for face in letters.polygons], "lime")
    evaluated.to_mesh_clear()
    bpy.data.objects.remove(object_with_text, do_unlink=True)
    bpy.data.curves.remove(curve)


def street_markers(mesh, parcel):
    sign_z = 2.87
    if parcel.name == "TabernaSeptentrionalis":
        u = -1.51
        box(mesh,u,-.109,sign_z-.060,1.49,.074,.264,"oxide")
        lettering(mesh,"VICVS FABRVM",((0,0,-1,-.147),(-1,0,0,-u),
                                       (0,1,0,sign_z),(0,0,0,1)))
    if parcel.name == "Figlina":
        corner = -parcel.width/2-.015
        d = 1.52
        box(mesh,corner,d,sign_z-.060,.078,1.94,.264,"oxide")
        lettering(mesh,"VICVS FIGVLORVM",((-1,0,0,d),(0,0,1,-corner+.040),
                                          (0,1,0,sign_z),(0,0,0,1)))


def assign_site(node, parcel):
    node.location=position(parcel.z,parcel.x,FLOOR)
    node.rotation_euler.z=math.pi if parcel.x<0 else 0.0


def proxy_box(name, u, d, h, w, depth, tall, parcel=None):
    bpy.ops.mesh.primitive_cube_add(size=1,location=position(u,d,h+tall/2))
    node=bpy.context.object
    node.name=name+"_collision"
    node.scale=(depth,w,tall)
    node["collision_mesh_only"]=True
    if parcel:
        angle=math.pi if parcel.x<0 else 0
        node.location.rotate(Matrix.Rotation(angle,3,"Z"))
        node.location+=position(parcel.z,parcel.x,FLOOR)
        node.rotation_euler.z=angle
    return node


def collision_nodes():
    boxes=[proxy_box("MainStreet",-2.08,0,-.085,12.16,6.70,ROAD_TOP+.085),
           proxy_box("EastLane",0,8.72,-.085,4.56,10.74,ROAD_TOP+.085),
           proxy_box("WestLane",0,-8.22,-.085,4.56,9.74,ROAD_TOP+.085)]
    for side in (-1,1):
        for z,length in ((-5.22,5.88),(3.24,1.92)):
            boxes.append(proxy_box(f"WalkMain{side}_{z}",z,side*3.69,.036,length,.68,.123))
        for u in (-2.62,2.62):
            boxes.append(proxy_box(f"WalkCross{side}_{u}",u,side*8.72,.036,.68,10.7,.123))
    for parcel in PARCELS:
        width,depth,height=parcel.width,parcel.depth,parcel.eave
        specs=[("Floor",0,depth/2,-.16,width,depth,.16),
               ("LeftSide",-width/2+.13,depth/2,0,.26,depth,height),
               ("RightSide",width/2-.13,depth/2,0,.26,depth,height),
               ("Rear",0,depth-.13,0,width,.26,height),
               ("Header",0,.14,2.20,1.66,.28,height-2.20),
               ("Workbench",.97,depth-1.15,0,1.36,.79,1.01)]
        span_width=width/2-.83
        specs.extend((f"Front{sign}",sign*(.83+span_width/2),.14,0,span_width,.28,height)
                     for sign in (-1,1))
        for name,*dims in specs:
            boxes.append(proxy_box(parcel.name+"_"+name,*dims,parcel=parcel))
    return boxes


def build():
    source=OUTPUT/"source"
    source.mkdir(parents=True,exist_ok=True)
    (source/".gdignore").touch()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.unit_settings.system="METRIC"
    bpy.context.scene["era_historical_year"]=-58
    with TemporaryDirectory() as temp:
        baseline={name:SWATCHES[name] for name in ATLAS}
        SWATCHES.update(ATLAS)
        try:
            atlas=material(Path(temp))
        finally:
            SWATCHES.update(baseline)
    atlas.name="Vicus_Nordkreuzung_PBR"
    pavement=Domus()
    roads(pavement)
    parts=[pavement.to_mesh("Kreuzung_Pflaster_und_Gehwege",atlas)]
    for parcel in PARCELS:
        block=Domus()
        wall_and_trim(block,parcel)
        side_walls(block,parcel)
        roofs(block,parcel)
        merchandise(block,parcel)
        street_markers(block,parcel)
        node=block.to_mesh(parcel.name,atlas)
        node["era_min_ce"]=-100
        assign_site(node,parcel)
        parts.append(node)
    export(OUTPUT/"roman_north_junction.glb",parts)
    physics=collision_nodes()
    export(OUTPUT/"roman_north_junction_collision.glb",physics)
    guide=bpy.data.collections.new("Physics guides · hidden by default")
    bpy.context.scene.collection.children.link(guide)
    for node in physics:
        for owner in list(node.users_collection):
            owner.objects.unlink(node)
        guide.objects.link(node)
        node.display_type="WIRE"
    guide.hide_render=True
    guide.hide_viewport=True
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(source/"roman_north_junction.blend"),compress=True)
    for part in parts:
        part.data.calc_loop_triangles()
    print(f"ROMAN_NORTH_JUNCTION_BUILD triangles={sum(len(part.data.loop_triangles) for part in parts)} colliders={len(physics)}")


if __name__=="__main__":
    build()
