"""Original Late Republican council room for fictional Valdora, Blender 4.3.2."""
from pathlib import Path
import math
import random
import sys
from tempfile import TemporaryDirectory

import bpy
from mathutils import Matrix

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_roman_workshop import Domus, beam, bench, box, export, lathe, material, position
from atrium_materials import SWATCHES

OUTPUT = ROOT / "prototype/assets/politics/council"
WIDTH = 7.2
LENGTH = 6.1
TRAUFE = 3.28
FIRST = 4.24
WALL = .28
HINGE = (-.818, .19, .032)
PALETTE = {"lime": (183,163,135), "intonaco": (172,146,113), "oxide": (125,62,41),
           "traver": (163,143,111), "paving": (133,109,78), "basalt": (74,72,62)}
WINDOW = (2.0, 3.65, 1.47, 2.57)


def frontage(mesh):
    for lo, hi in ((-WIDTH/2,-.76),(.76,WIDTH/2)):
        centre=(lo+hi)/2
        box(mesh,centre,.14,0,hi-lo,WALL,TRAUFE,"intonaco")
        box(mesh,centre,-.015,.24,hi-lo,.035,.938,"oxide")
        box(mesh,centre,-.037,1.18,hi-lo,.028,.065,"ochre")
        for row in range(2):
            count=math.ceil((hi-lo)/.55)+row
            for index in range(count):
                pitch=(hi-lo)/count
                paint="traver" if (index+row)%3 else "tuff"
                box(mesh,lo+(index+.5)*pitch,-.035,row*.121+.006,
                    pitch-.024,.077,.107,paint)
    box(mesh,0,.14,2.30,1.52,WALL,TRAUFE-2.30,"intonaco")
    for sign in (-1,1):
        box(mesh,sign*.883,-.021,.026,.197,.41,2.214,"traver")
        box(mesh,sign*.888,-.037,.02,.25,.42,.164,"tuff")
        for seam in (.56,1.15,1.69):
            box(mesh,sign*.887,-.241,seam,.20,.017,.022,"tuff")
    box(mesh,0,-.054,2.259,1.91,.37,.173,"traver")
    box(mesh,0,.115,-.058,1.55,.37,.058,"traver")
    box(mesh,0,-.108,2.580,1.47,.080,.267,"beam")
    inscription(mesh,"TABVLAE")
    box(mesh,0,-.060,3.108,7.28,.185,.159,"beam")
    for index in range(14):
        box(mesh,-3.39+index*.522,-.176,3.126,.107,.185,.101,"cedar")


def inscription(mesh, text):
    lettering=bpy.data.curves.new("CouncilLettering","FONT")
    lettering.body=text
    lettering.align_x="CENTER"
    lettering.size=.199
    letters=bpy.data.objects.new("Tabulae",lettering)
    bpy.context.collection.objects.link(letters)
    letters.matrix_world=Matrix(((0,0,-1,-.149),(-1,0,0,0),(0,1,0,2.662),(0,0,0,1)))
    bpy.context.view_layer.update()
    evaluated=letters.evaluated_get(bpy.context.evaluated_depsgraph_get())
    glyphs=evaluated.to_mesh()
    mesh.add([letters.matrix_world @ v.co for v in glyphs.vertices],
             [tuple(p.vertices) for p in glyphs.polygons],"lime")
    evaluated.to_mesh_clear()
    bpy.data.objects.remove(letters,do_unlink=True)
    bpy.data.curves.remove(lettering)


def room(mesh):
    box(mesh,0,LENGTH/2,-.167,WIDTH,LENGTH,.167,"paving")
    # A narrow mosaic border and terracotta paving are flush with the threshold.
    box(mesh,0,LENGTH/2,-.012,6.6,5.51,.014,"mosaic")
    box(mesh,0,LENGTH/2,-.009,3.87,4.86,.013,"paving")
    box(mesh,0,LENGTH-.145,0,WIDTH,.29,TRAUFE,"intonaco")
    box(mesh,0,LENGTH-.302,.243,6.6,.028,.68,"oxide")
    low,high,sill,top=WINDOW
    for side in (-1,1):
        u=side*(WIDTH/2-WALL/2)
        for z0,z1,base,upper in ((0,low,0,TRAUFE),(high,LENGTH,0,TRAUFE),
                                 (low,high,0,sill),(low,high,top,TRAUFE)):
            box(mesh,u,(z0+z1)/2,base,WALL,z1-z0,upper-base,"intonaco")
        box(mesh,u-side*.141,LENGTH*.49,.24,.038,5.40,.678,"oxide")
        box(mesh,u+side*.139,LENGTH*.49,.014,.056,5.64,.222,"tuff")
        box(mesh,u,(low+high)/2,sill-.075,.41,high-low+.26,.120,"traver")
        box(mesh,u,(low+high)/2,top-.05,.39,high-low+.22,.131,"traver")
        for d in (low-.038,high+.042):
            box(mesh,u,d,sill,.38,.126,top-sill,"traver")
            # Open board shutter follows the exterior wall. The true aperture
            # between jambs remains free except for one timber mullion.
            for slot in range(4):
                z=d+(-1 if d<low else 1)*(.055+slot*.123)
                box(mesh,u+side*.167,z,sill+.05,.064,.116,.96,"cedar")
            for h in (sill+.26,sill+.72):
                box(mesh,u+side*.207,d+(-.29 if d<low else .29),h,.036,.46,.046,"iron")
        box(mesh,u,(low+high)/2,sill+.024,.105,.081,top-sill-.078,"cedar")
        # Small triangular gable extensions sit over the side windows.
        left=side*(WIDTH/2-.13)
        mesh.prism([position(left,0,TRAUFE),position(left,LENGTH,TRAUFE),
                    position(left,LENGTH/2,FIRST)],(0,-side*.226,0),"intonaco")


def door_leaf(mesh):
    # Build in closed-door space. The object transform opens it inward around
    # the left hinge. A later interaction can animate this existing pivot.
    for index in range(8):
        u=.089+index*.176
        box(mesh,u,0,0,.164,.096,2.155,"cedar" if index%3 else "beam")
    for h in (.26,1.24,1.89):
        box(mesh,.682,0,h,1.385,.141,.116,"beam")
    for h in (.32,1.90):
        box(mesh,.187,-.077,h,.366,.029,.089,"iron")
        for u in (.073,.308):
            mesh.beam(position(u,-.089,h+.046),position(u,-.106,h+.046),.022,"bronze",8)
    box(mesh,1.173,-.058,1.052,.153,.036,.127,"iron")
    mesh.beam(position(1.12,-.091,1.115),position(1.28,-.091,1.115),.034,"bronze",8)
    for sign in (-1,1):
        box(mesh,1.12+sign*.077,-.099,1.081,.043,.044,.079,"bronze")


def pitched_roof(mesh):
    rng=random.Random(58166)
    for edge in (-.34,LENGTH+.30):
        def surface(u,t,extra=0):
            return position(u,edge+(LENGTH/2-edge)*t,TRAUFE+(FIRST-TRAUFE)*t+extra)
        mesh.prism([surface(-3.83,0),surface(3.83,0),surface(3.83,1),surface(-3.83,1)],
                   (0,0,-.099),"fired")
        for row in range(8):
            start=row/8
            finish=min(1.,(row+1.14)/8)
            for index in range(19):
                a=-3.82+index*7.64/19
                b=-3.82+(index+1)*7.64/19
                drop=rng.uniform(0,.018)
                paint="tegula" if rng.random()>.29 else "fired"
                mesh.prism([surface(a+.021,start,.034+drop),surface(b-.021,start,.035+drop),
                            surface(b-.021,finish,.023),surface(a+.021,finish,.023)],
                           (0,0,-.028),paint)
                mesh.cover_tile(surface(a,finish,.042),surface(a,start,.052+drop),.077,paint)
        for index in range(14):
            u=-3.63+index*7.26/13
            beam(mesh,(u,edge,TRAUFE-.075),(u,LENGTH/2,FIRST-.075),.109,.156,"beam")
    beam(mesh,(-3.82,LENGTH/2,FIRST+.021),(3.82,LENGTH/2,FIRST+.021),
         .166,.111,"fired")
    for row in range(19):
        low=-3.83+row*7.66/19
        high=-3.83+(row+1.14)*7.66/19
        mesh.cover_tile(position(low,LENGTH/2,FIRST+.062),position(high,LENGTH/2,FIRST+.068),
                        .126,"tegula" if row%4 else "fired")


def tablet(mesh, u, d, h, pigment="cedar"):
    box(mesh,u,d,h,.237,.173,.027,pigment)
    box(mesh,u,d,h+.027,.199,.136,.007,"beam")
    # Shallow stylus marks on the wax surface, kept subtle at a distance.
    for row,width in enumerate((.12,.15,.09,.118)):
        box(mesh,u-.017,d-.042+row*.023,h+.034,width,.005,.0015,"ochre")


def interior(mesh):
    # Archival table and stacked tablets on the right leave the middle clear.
    bench(mesh,1.94,4.34,.844,2.03,.822)
    tablet(mesh,1.48,4.25,.941)
    tablet(mesh,1.74,4.39,.941)
    tablet(mesh,2.14,4.39,.938,"beam")
    tablet(mesh,2.14,4.39,.99)
    tablet(mesh,2.43,4.42,.94)
    mesh.beam(position(1.22,4.64,.983),position(1.51,4.61,.978),.014,"bronze",8)
    box(mesh,2.57,4.07,.936,.176,.17,.013,"traver")
    lathe(mesh,2.57,4.07,.947,[(0,.052),(.027,.087),(.052,.072),(.049,.038)],
          "bronze",14)
    # Storage chest beneath the back wall.
    box(mesh,2.47,5.566,.024,1.12,.53,.51,"cedar")
    box(mesh,2.47,5.566,.521,1.18,.60,.082,"beam")
    for u in (2.02,2.88):
        box(mesh,u,5.278,.142,.071,.033,.35,"iron")
    # The waiting bench is long enough for customers at the side wall.
    bench(mesh,-2.99,3.31,.455,.63,2.64)
    for index in range(5):
        d=2.15+index*.53
        box(mesh,-3.245,d,.426,.105,.092,.433,"beam")
    box(mesh,-3.285,3.31,.794,.105,2.57,.096,"cedar")
    # Wooden slats protect the ledger recess and match the rest of the room.
    for height in (.638,1.221,1.738):
        box(mesh,0,5.66,height,1.85,.32,.089,"cedar")
    for u in (-.878,.878):
        box(mesh,u,5.66,.564,.11,.32,1.28,"beam")
    for u,height in ((-.44,.735),(-.23,.735),(.36,1.31),(.58,1.31),(0,1.83)):
        tablet(mesh,u,5.66,height)
    for u in (-1.7,1.7):
        box(mesh,u,5.584,1.985,.44,.36,.092,"cedar")
        lathe(mesh,u,5.578,2.081,[(0,.047),(.036,.081),(.065,.072),(.054,.04)],
              "bronze",12)


def proxy(name, at, pads):
    across, depth, bottom=at
    width, extent, height=pads
    bpy.ops.mesh.primitive_cube_add(size=1,location=position(across,depth,bottom+height/2))
    obj=bpy.context.object
    obj.name=f"Council_{name}_collision"
    obj.scale=(extent,width,height)
    obj["collision_mesh_only"]=True
    return obj


def collision_models():
    pieces=[
        ("Floor",(0,3.05,-.167),(7.2,6.1,.167)),
        ("Front_L",(-2.18,.14,0),(2.84,.28,3.28)),
        ("Front_R",(2.18,.14,0),(2.84,.28,3.28)),
        ("Header",(0,.14,2.30),(1.52,.28,.98)),
        ("Back",(0,5.96,0),(7.2,.28,3.28)),
        ("OpenDoor",(-.815,.886,.031),(.112,1.39,2.15)),
        ("RecordDesk",(1.94,4.34,.01),(2.03,.822,.94)),
        ("WaitingBench",(-2.99,3.31,.01),(.63,2.64,.55)),
        ("Chest",(2.47,5.57,.01),(1.17,.59,.60)),
    ]
    low, high, sill, top = WINDOW
    for side in (-1,1):
        for section,start,end,bottom,roof in (
                ("Corner",0,low,0,TRAUFE),("Rear",high,LENGTH,0,TRAUFE),
                ("Sill",low,high,0,sill),("Lintel",low,high,top,TRAUFE)):
            pieces.append((f"Side_{side}_{section}",(side*3.46,(start+end)/2,bottom),
                           (WALL,end-start,roof-bottom)))
    return [proxy(tag,location,size) for tag,location,size in pieces]


def build():
    source=OUTPUT/"source"
    source.mkdir(parents=True,exist_ok=True)
    (source/".gdignore").touch()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.unit_settings.system="METRIC"
    bpy.context.scene["era_historical_year"]=-58
    with TemporaryDirectory() as temp:
        original={name:SWATCHES[name] for name in PALETTE}
        SWATCHES.update(PALETTE)
        try:
            paint=material(Path(temp))
        finally:
            SWATCHES.update(original)
    paint.name="Valdora_RecordRoom_PBR"
    visible=[]
    for label,draw in (("CouncilFacade",frontage),("CouncilRoom",room),
                       ("CouncilTileRoof",pitched_roof),("CouncilFurnishings",interior),
                       ("CouncilDoorLeaf_Open",door_leaf)):
        geometry=Domus()
        draw(geometry)
        model=geometry.to_mesh(label,paint)
        model["era_min_ce"]=-100
        if label=="CouncilDoorLeaf_Open":
            model.location=position(*HINGE)
            model.rotation_euler.z=math.pi/2
            model["hinge_pivot"]=True
        visible.append(model)
    export(OUTPUT/"valdora_council.glb",visible)
    collision=collision_models()
    export(OUTPUT/"valdora_council_collision.glb",collision)
    draft=bpy.data.collections.new("Physics guides · hidden by default")
    bpy.context.scene.collection.children.link(draft)
    for obj in collision:
        for existing in list(obj.users_collection):
            existing.objects.unlink(obj)
        draft.objects.link(obj)
        obj.display_type="WIRE"
    draft.hide_render=True
    draft.hide_viewport=True
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(source/"valdora_council.blend"),compress=True)
    for obj in visible:
        obj.data.calc_loop_triangles()
    print("VALDORA_COUNCIL_BUILD triangles=%d colliders=%d" %
          (sum(len(obj.data.loop_triangles) for obj in visible),len(collision)))


if __name__=="__main__":
    build()
