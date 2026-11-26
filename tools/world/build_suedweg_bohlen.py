"""Build the original drainage evidence and donated replacement timber in Blender."""
import math
from pathlib import Path
import random
import sys
from tempfile import TemporaryDirectory

import bpy

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_roman_workshop import Domus, box, export, material, position

DIR = ROOT / "prototype/assets/politics/suedweg"
PLANKS = (-.34, 0., .34)
END_HEIGHTS = {
    -0.34: (.169, .156),
    0.0: (.161, .051),
    0.34: (.167, .161),
}


def board(mesh, z, bottom, top, paint, start=-.685, finish=.685, width=.295):
    """Mark the slightly chamfered end grain of an individual timber."""
    rim = width/2
    shape = [
        position(z-rim+.019,start,bottom),
        position(z+rim-.024,start,bottom+.004),
        position(z+rim,start+.061,bottom+.009),
        position(z+rim,finish-.054,top+.001),
        position(z+rim-.023,finish,top),
        position(z-rim+.028,finish,top-.006),
        position(z-rim,finish-.045,top+.006),
        position(z-rim,start+.053,bottom+.003),
    ]
    mesh.prism(shape,(0,0,-.054),paint)
    for s in (-1,1):
        edge = z+s*(rim-.041)
        mesh.beam(position(edge,start+.074,bottom+.002),
                  position(edge,finish-.061,top+.001),.006,"beam",5)


def damaged_bed(mesh):
    # Bare local base follows existing terrain. Dim stone indicates the
    # narrow drain between raised banks and continues past the three planks.
    box(mesh,0,.106,.004,1.02,.441,.012,"basalt")
    for u in (-.46,-.29,-.07,.13,.34,.46):
        ridge = .20+.025*math.sin(u*20)
        box(mesh,u,ridge,.015,.16,.073,.011,"tuff")
    rng = random.Random(58174)
    for u in PLANKS:
        # Intact near footing across the width. The far centre footing
        # has eroded into small splayed stones below the dropped end.
        box(mesh,u,-.516,.001,.319,.193,.105,"tuff")
        if u != 0:
            box(mesh,u,.533,.001,.302,.211,.107,"traver")
            box(mesh,u,.534,.104,.282,.192,.027,"beam")
    for side, x in ((-1,-.53),(1,.53)):
        for i in range(19):
            u = rng.uniform(-.47,.47)
            local_x = x+rng.uniform(-.107,.123)
            radius = rng.uniform(.021,.061)
            if side > 0 and abs(u)<.20:
                local_x -= rng.uniform(.001,.105)
            mesh.beam(position(u,local_x,.011),position(u+.022,local_x,.044+radius*.49),
                      radius,"tuff" if i%3 else "traver",5,r2=radius*.58)
    wash = [position(-.151,.271,.024),position(.159,.28,.018),position(.234,.611,.012),
            position(.11,.687,.014),position(-.143,.645,.018)]
    mesh.prism(wash,(0,0,-.011),"paving")
    # A broken timber sill exposes the missing centre support.
    box(mesh,-.122,.570,.017,.10,.087,.053,"cedar")
    mesh.prism([position(.03,.609,.012),position(.158,.621,.011),position(.077,.70,.012)],
               (0,0,.030),"beam")


def worn_plank(mesh, z):
    start, end = END_HEIGHTS[z]
    board(mesh,z,start,end,"cedar" if z == 0 else "beam")
    for x,h in ((-.55,start),(.579,end)):
        # Iron pegs hold the two stable boards, with an exposed peg in
        # the fallen plank. The timber shape itself carries the evidence.
        mesh.beam(position(z+.028,x,h+.003),position(z+.028,x,h+.012),
                  .015,"iron",7)
        if z == 0:
            box(mesh,z-.062,x-.117,h+.004,.058,.045,.004,"tuff")


def replacement_stack(mesh):
    for d in (-.45,.45):
        box(mesh,0,d,.004,.60,.104,.098,"beam")
    for tier in range(3):
        for side in (-1,1):
            d = .034*side*(tier%2)
            board(mesh,side*.151,.150+tier*.064,.152+tier*.064,"cedar",
                  start=-.685+d,finish=.685+d,width=.272)
    # The rope can be read in silhouette. There are no moving parts.
    for x in (-.423,.429):
        outline = [position(-.306,x,.041),position(-.307,x,.287),position(-.267,x,.303),
                   position(.276,x,.302),position(.311,x,.263),position(.315,x,.043)]
        for first, second in zip(outline,outline[1:]):
            mesh.beam(first,second,.014,"ochre",7)
        mesh.beam(position(.241,x-.029,.309),position(.304,x+.027,.310),.020,"cedar",8)


def build():
    source=DIR/"source"
    source.mkdir(parents=True,exist_ok=True)
    (source/".gdignore").touch()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.unit_settings.system="METRIC"
    bpy.context.scene["asset_owner"]="IMPERATHEN"
    with TemporaryDirectory() as temp:
        paint=material(Path(temp))
    paint.name="Suedweg_Drain_WornWood_Original"
    ground=Domus()
    damaged_bed(ground)
    evidence=[ground.to_mesh("Suedweg_Ausgespueltes_Bett",paint)]
    for z,label in zip(PLANKS,("Bohle_Links","Bohle_Abgesackt","Bohle_Rechts")):
        mesh=Domus()
        worn_plank(mesh,z)
        evidence.append(mesh.to_mesh(label,paint))
    export(DIR/"suedweg_bohlen.glb",evidence)
    replacement=Domus()
    replacement_stack(replacement)
    stock=replacement.to_mesh("Suedweg_Ersatzbohlen",paint)
    export(DIR/"suedweg_ersatzbohlen.glb",[stock])
    stock.location=position(1.44,0,0)
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(source/"suedweg_bohlen.blend"),compress=True)
    for obj in evidence+[stock]:
        obj.data.calc_loop_triangles()
    print("SUEDWEG_BUILD evidence_triangles=%d replacement_triangles=%d" %
          (sum(len(obj.data.loop_triangles) for obj in evidence), len(stock.data.loop_triangles)))


if __name__=="__main__":
    build()
