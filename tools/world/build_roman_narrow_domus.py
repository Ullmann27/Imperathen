"""Original two-storey Roman street house with a shop and a separate vestibule."""
from pathlib import Path
import math
import random
import sys
from tempfile import TemporaryDirectory

import bpy

sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_roman_workshop import (OUTPUT, Domus, beam, bench, box, export,
                                  lathe, material, position, pot, span)
from atrium_materials import SWATCHES

LENGTH = 9.0
DEPTH = 5.0
EAVES = 5.54
RIDGE = 6.72
OPENINGS = [(-2., 1.88), (2.1, 1.34)]
WINDOWS = [-3.36, -1.37, 1.45, 3.48]
# A warm, weathered lime wash. Keep the courtyard material atlas coordinates
# and physically based maps, with a different colour palette for this house.
DOMUS_SWATCHES = {
    "lime": (183, 155, 119),
    "intonaco": (174, 144, 107),
    "ochre": (162, 114, 66),
    "oxide": (129, 58, 41),
    "traver": (174, 153, 118),
    "tuff": (116, 105, 86),
}


def segments(width, gaps):
    """Solid stretches between ordered openings along the street."""
    edge = -width / 2
    for centre, opening in gaps:
        yield edge, centre-opening/2
        edge = centre+opening/2
    yield edge, width/2


def ground_facade(mesh):
    for low, high in segments(LENGTH, OPENINGS):
        span(mesh,low,high,.16,0,.32,2.58,"intonaco")
        span(mesh,low,high,-.006,.42,.032,.88,"ochre")
        span(mesh,low,high,-.024,1.26,.025,.073,"oxide")
        for row in range(3):
            count=max(2,round((high-low)/.47)+(row%2))
            for col in range(count):
                pitch=(high-low)/count
                paint="tuff" if (row+col)%5 else "traver"
                box(mesh,low+(col+.5)*pitch,-.01,row*.12,
                    pitch-.018,.089,.106,paint)
    for (centre,w), paint in zip(OPENINGS,("cedar","traver")):
        for side in (-1,1):
            x=centre+side*(w/2+.105)
            box(mesh,x,-.012,.025,.179,.347,2.25,paint)
            box(mesh,x,-.05,.02,.213,.392,.19,"tuff")
            if paint=="cedar":
                for h in (.49,1.66):
                    box(mesh,x,-.224,h,.095,.031,.16,"iron")
                    mesh.beam(position(x,.025,h+.04),position(x,-.248,h+.04),.024,"bronze",7)
            else:
                for sep in (.54,1.01,1.47,1.98):
                    box(mesh,x,-.056,sep,.217,.015,.018,"tuff")
        box(mesh,centre,.16,2.28,w,.32,.30,"lime")
        box(mesh,centre,-.034,2.24,w+.32,.32,.135,paint)
        box(mesh,centre, .10, -.08, w, .45, .08, "traver")
    # A shallow, laterally offset awning distinguishes the shop from the home.
    canopy_low, canopy_high = -3.76, -.43
    for u in (canopy_low, -2.1, canopy_high):
        beam(mesh,(u,-.12,2.95),(u,-.83,2.65),.094,.098,"beam")
    beam(mesh,(canopy_low,-.80,2.66),(canopy_high,-.80,2.66),.11,.11,"cedar")
    for col in range(10):
        low = -3.79 + .34*col
        high = low+.318
        mesh.prism([position(low,-.86,2.71), position(high,-.86,2.71),
                    position(high,-.11,3.02), position(low,-.11,3.02)],
                    (0,0,-.034), "tegula" if col%3 else "fired")
        mesh.cover_tile(position(low,-.11,3.055),position(low,-.86,2.746),.06,"tegula")
    # Recessed decorative panel over the narrower home entrance.
    box(mesh,2.1,-.016,2.44,1.63,.10,.12,"traver")
    for column in range(6):
        x=1.42+column*.27
        box(mesh,x,-.075,2.48,.083,.023,.054,"oxide")


def upper_facade(mesh):
    gap_width = .73
    bottom, lower_sill, upper_lintel = 2.58, 3.77, 4.79
    span(mesh,-4.5,4.5,.16,bottom,.32,lower_sill-bottom,"lime")
    span(mesh,-4.5,4.5,.16,upper_lintel,.32,EAVES-upper_lintel,"lime")
    for low, high in segments(LENGTH, [(w,gap_width) for w in WINDOWS]):
        span(mesh,low,high,.16,lower_sill,.32,upper_lintel-lower_sill,"lime")
    for u in WINDOWS:
        box(mesh,u,-.025,3.72,.94,.35,.112,"traver")
        box(mesh,u,-.031,4.77,.95,.32,.13,"traver")
        for direction in (-1,1):
            x=u+direction*.404
            box(mesh,x,-.025,3.81,.102,.29,.976,"traver")
            for i in range(3):
                box(mesh,u+direction*(.47+.116*i),-.064,3.85,
                    .104,.054,.88,"cedar")
            box(mesh,u+direction*.58,-.096,4.07,.36,.036,.065,"iron")
            box(mesh,u+direction*.58,-.096,4.54,.36,.036,.065,"iron")
        for k in range(4):
            box(mesh,u+(k-1.5)*.132,.063,3.83,.040,.052,.93,"beam")
        box(mesh,u,.066,4.38,.65,.060,.072,"cedar")
    for h, height, paint in ((2.56,.16,"traver"),(3.06,.125,"oxide"),(5.19,.114,"ochre")):
        box(mesh,0,-.014,h,9.07,.099,height,paint)
    for corner in (-4.35,4.35):
        for row in range(6):
            box(mesh,corner,-.049,2.89+row*.397,.295 if row%2 else .51,
                .086,.358,"traver" if row%2 else "tuff")
    for depth in (.0,4.69):
        mesh.prism([position(-4.50,depth,EAVES-.02),position(4.50,depth,EAVES-.02),
                    position(0,depth,RIDGE)],(.31,0,0),"intonaco")
    for side in (-1,1):
        beam(mesh,(0,-.017,RIDGE-.08),(side*4.63,-.017,EAVES-.08),.216,.179,"beam")


def house_enclosure(mesh):
    box(mesh,0,2.5,-.181,LENGTH,DEPTH,.181,"paving")
    for u in (-4.35,4.35):
        box(mesh,u,2.5,0,.30,5.0,EAVES,"intonaco")
        box(mesh,u,2.5,.012,.339,5.0,.255,"tuff")
    box(mesh,0,4.844,0,9.0,.312,EAVES,"intonaco")
    box(mesh,0,2.53,0,.21,4.37,2.44,"intonaco")
    box(mesh,0,2.5,2.46,8.69,4.50,.246,"cedar")
    box(mesh,-2.25,2.45,-.01,4.14,4.65,.013,"paving")
    box(mesh,2.23,2.45,-.01,4.16,4.65,.013,"mosaic")
    for index in range(8):
        depth=.48+index*.56
        beam(mesh,(-4.35,depth,2.40),(4.35,depth,2.40),.131,.178,"beam")
    # Interior olive-bordered dado to separate the darker workrooms.
    for side in (-1,1):
        box(mesh,side*4.182,2.5,.29,.033,4.52,.69,"ochre")
    box(mesh,0,4.674,.29,8.33,.027,.69,"oxide")


def roof_tiles(mesh):
    rng=random.Random(58123)
    for side in (-1,1):
        def at(depth,t,raise_by=0):
            return position(side*4.69*(1-t),depth,EAVES+(RIDGE-EAVES)*t+raise_by)
        mesh.prism([at(-.34,0),at(5.33,0),at(5.33,1),at(-.34,1)],
                    (0,0,-.109),"fired")
        for row in range(12):
            t0=row/12
            t1=min(1.,(row+1.18)/12)
            for index in range(15):
                a=-.33+index*5.65/15
                b=-.33+(index+1)*5.65/15
                dz=rng.uniform(.0,.018)
                paint="tegula" if rng.random()>.37 else "fired"
                mesh.prism([at(a+.015,t0,.04+dz),at(b-.019,t0,.04+dz),
                            at(b-.019,t1,.023),at(a+.015,t1,.023)],
                            (0,0,-.027),paint)
                mesh.cover_tile(at(a,t1,.055),at(a,t0,.063+dz),.067,paint)
    for index in range(15):
        a=-.33+index*5.65/15
        b=-.33+(index+1.12)*5.65/15
        mesh.cover_tile(position(0,a,RIDGE+.062),position(0,b,RIDGE+.066),.121,
                        "fired" if index%3 else "tegula")


def interiors(mesh):
    # Open shop fronts the street. Its display cabinet sits to one side.
    box(mesh,-3.56,2.85,.02,1.47,.95,.89,"intonaco")
    box(mesh,-3.56,2.85,.903,1.49,.99,.109,"cedar")
    box(mesh,-3.56,2.351,.28,1.48,.031,.57,"oxide")
    for i in range(3):
        pot(mesh,-4.03+.38*i,2.72,1.015,.124,.357,"fired" if i%2 else "tegula")
    for u in (-3.82,-3.42,-3.02):
        lathe(mesh,u,4.30,.004,[(0,.175),(.38,.224),(.55,.221),(.57,.182),(.495,.148)],
              "ochre",14)
    for h in (.64,1.14,1.67):
        box(mesh,-2.39,4.53,h,1.95,.32,.087,"cedar")
        for u in (-3.12,-2.54,-1.99,-1.71):
            pot(mesh,u,4.53,h+.091,.096,.284,"tegula")
    for u in (-3.36,-1.4):
        box(mesh,u,4.56,.016,.12,.15,1.83,"beam")
    # Private vestibule opens onto a hallway with storage and seating.
    bench(mesh,3.43,2.83,.47,1.26,.39)
    for u in (1.08,1.65):
        pot(mesh,u,4.32,.001,.235,.83,"tegula")
    box(mesh,3.47,4.31,.017,1.12,.61,.63,"cedar")
    box(mesh,3.47,4.31,.646,1.18,.69,.084,"beam")
    for u in (3.0,3.54,3.92):
        box(mesh,u,3.987,.19,.059,.027,.46,"iron")
    box(mesh,3.22,3.04,1.85,.65,.34,.095,"cedar")
    lathe(mesh,3.23,3.00,1.95,[(0,.064),(.04,.103),(.071,.072),(.064,.04)],
          "bronze",14)


def collisions():
    regions=[("Floor",0,2.5,-.18,9.0,5.0,.18),
             ("LeftWall",-4.35,2.5,0,.30,5.0,5.54),
             ("RightWall",4.35,2.5,0,.30,5.0,5.54),
             ("RearWall",0,4.844,0,9.0,.312,5.54),
             ("Partition",0,2.53,0,.21,4.37,2.44),
             ("ShopCounter",-3.56,2.85,0,1.49,.99,1.012),
             ("HallChest",3.47,4.31,0,1.18,.69,.73)]
    regions.extend(("FrontWall%d"%index,(lo+hi)/2,.16,0,hi-lo,.32,5.54)
                   for index,(lo,hi) in enumerate(segments(LENGTH,OPENINGS)))
    regions.extend(("Lintel%d"%index,u,.16,2.25,w,.32,3.29)
                   for index,(u,w) in enumerate(OPENINGS))
    nodes=[]
    for label,u,d,h,w,dep,height in regions:
        bpy.ops.mesh.primitive_cube_add(size=1,location=position(u,d,h+height/2))
        proxy=bpy.context.object
        proxy.name="NarrowDomus_"+label+"_collision"
        proxy.scale=(dep,w,height)
        proxy["collision_mesh_only"]=True
        nodes.append(proxy)
    return nodes


def build():
    source=OUTPUT/"source"
    source.mkdir(parents=True,exist_ok=True)
    (source/".gdignore").touch()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.unit_settings.system="METRIC"
    bpy.context.scene["era_historical_year"]=-58
    meshes=[]
    with TemporaryDirectory() as temp:
        baseline = {name: SWATCHES[name] for name in DOMUS_SWATCHES}
        SWATCHES.update(DOMUS_SWATCHES)
        try:
            paint = material(Path(temp))
        finally:
            SWATCHES.update(baseline)
        paint.name="NarrowDomus_WornStoneWoodClay"
        for name,draw in (("Domus_StreetFront",ground_facade),("Domus_UpperFloor",upper_facade),
                          ("Domus_Enclosure",house_enclosure),("Domus_Roof",roof_tiles),
                          ("Domus_ShopandVestibule",interiors)):
            mesh=Domus()
            draw(mesh)
            obj=mesh.to_mesh(name,paint)
            obj["era_min_ce"]=-100
            meshes.append(obj)
    export(OUTPUT/"roman_narrow_domus.glb",meshes)
    proxies=collisions()
    export(OUTPUT/"roman_narrow_domus_collision.glb",proxies)
    guides=bpy.data.collections.new("Physics guides · hidden by default")
    bpy.context.scene.collection.children.link(guides)
    for node in proxies:
        for collection in list(node.users_collection):
            collection.objects.unlink(node)
        guides.objects.link(node)
        node.display_type="WIRE"
    guides.hide_render=True
    guides.hide_viewport=True
    bpy.ops.object.select_all(action="DESELECT")
    meshes[0].select_set(True)
    bpy.context.view_layer.objects.active=meshes[0]
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(source/"roman_narrow_domus.blend"),compress=True)
    for obj in meshes:
        obj.data.calc_loop_triangles()
    print("ROMAN_NARROW_DOMUS_BUILD triangles=%d colliders=%d" %
          (sum(len(obj.data.loop_triangles) for obj in meshes),len(proxies)))


if __name__=="__main__":
    build()
