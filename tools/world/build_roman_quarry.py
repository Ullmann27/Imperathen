"""Build the original Old Quarry landmark with compact Godot collision proxies."""
from pathlib import Path
import math
import random
import sys
from tempfile import TemporaryDirectory

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_roman_workshop import Domus, beam, bench, box, export, material, position
from atrium_materials import SWATCHES

OUT = ROOT / "prototype/assets/world/road_landmarks"
SLOPE_DEPTH = .029
SLOPE_ACROSS = .057
# Terraces are set back into the native hill, beyond the five-metre approach.
BENCHES = ((13.9, 3.45, 20.3, 1.49), (15.46, 2.84, 18.12, 2.85),
           (17.12, 2.17, 15.71, 4.25))
# Across street, depth, width, depth extent, height, rotation angle.
STOCK = ((-5.54, 3.72, 1.45, 1.39, .79, -.06), (-7.53, 4.84, 1.31, 1.54, .69, .18),
         (-6.14, 6.01, 1.74, 1.32, .87, -.12), (-9.34, 6.60, 1.37, 1.75, .69, .04),
         (-4.84, 8.76, 1.55, 1.88, .91, .08), (-7.47, 9.11, 1.59, 1.40, .83, -.27))
POSTS = tuple((u, x) for u in (4.97, 9.78) for x in (5.87, 9.94))
PALETTE = {"lime": (168,158,143), "tuff": (125,114,97), "traver": (143,132,113),
           "paving": (124,103,73), "basalt": (78,77,65), "beam": (82,62,42),
           "oxide": (123,68,49), "tegula": (152,104,74)}


def ground(depth, across):
    return SLOPE_DEPTH*depth + SLOPE_ACROSS*across


def ground_point(u, d, above):
    return position(u, d, ground(d, u)+above)


def angular_stone(mesh, centre, width, depth, height, turn, paint, chamfer=.10):
    """Chipped limestone with eight corners and a slightly tilted working face."""
    u, d, h = centre
    bevel = min(width, depth)*chamfer
    half_w, half_d = width/2, depth/2
    plane = (
        (-half_w+bevel,-half_d),(half_w-bevel,-half_d),
        (half_w,-half_d+bevel),(half_w,half_d-bevel),
        (half_w-bevel,half_d),(-half_w+bevel,half_d),
        (-half_w,half_d-bevel),(-half_w,-half_d+bevel),
    )
    co, si = math.cos(turn), math.sin(turn)
    points = []
    for row, lift in enumerate((0, height*.18, height*.88, height)):
        ratio = (.87,1.0,.98,.87)[row]
        for i,(x,y) in enumerate(plane):
            xx = u + ratio*(co*x-si*y)
            yy = d + ratio*(si*x+co*y)
            variation = math.sin((i+1)*2.2+u*5)*height*.065
            points.append(ground_point(xx, yy, h+lift+variation))
    faces=[tuple(reversed(range(8)))]
    for row in range(3):
        for index in range(8):
            nxt=(index+1)%8
            face = (8*row+index,8*row+nxt,8*(row+1)+nxt,8*(row+1)+index)
            mesh.add(points,[face],paint if (index+row)%5 else "tuff")
    faces.append(tuple(range(24,32)))
    mesh.add(points,faces,paint)


def terraces(mesh):
    rng = random.Random(58137)
    for step,(x,depth,width,elevation) in enumerate(BENCHES):
        front, back = x-depth/2+.20, x+depth/2-.18
        # One continuous limestone bed behind the cut face. The gaps between
        # worked outcrops read as fissures rather than freestanding piles.
        rim = width/2-.105
        mesh.prism([ground_point(-rim,front,-.31),ground_point(rim,front,-.31),
                    ground_point(rim,back,-.31),ground_point(-rim,back,-.31)],
                   (0,0,elevation+.17),"tuff")
        cuts = [-width/2]
        while cuts[-1] < width/2-2.3:
            cuts.append(cuts[-1]+rng.uniform(1.45,2.10))
        cuts.append(width/2)
        for i,(low,high) in enumerate(zip(cuts,cuts[1:])):
            u = (low+high)/2
            colour = "traver" if i%4 else "lime"
            # Shared depth keeps individual rock projections inside each bench.
            angular_stone(mesh,(u,x+rng.uniform(-.17,.16),-.22),
                          high-low+.15,depth+.14,elevation+rng.uniform(.1,.31),
                          .016*(i%3-1),colour,.05)
            front = x-depth/2-.11
            visible_bottom = BENCHES[step-1][3]-.13 if step else .05
            for layer in (.32,.74,1.08):
                top = visible_bottom+layer
                if top >= elevation-.11:
                    continue
                tilt = rng.uniform(-.12,.11)
                start = ground_point(low+.07,front,top)
                end = ground_point(high-.03,front+rng.uniform(-.04,.08),top+tilt)
                middle=start.lerp(end,.46)+Vector((-.035,.0,.052))
                mesh.prism([start,middle,end,end+Vector((0,0,.079)),
                            middle+Vector((0,0,.052)),start+Vector((0,0,.076))],
                           (.110,0,0),"tuff" if (i+step)%3 else "paving")
            # Chisel channels on a fresh lower bench, narrower than the block
            # faces. They follow the face and remain part of its surface batch.
            for cut in range(1,4 if step == 0 else 2):
                z = low+(high-low)*cut/4
                lift = visible_bottom+rng.uniform(.2,.46)
                shape=[ground_point(z-.031,front-.016,lift),
                       ground_point(z+.045,front-.008,lift+.037),
                       ground_point(z+.051,front-.009, min(elevation-.08,lift+.31)),
                       ground_point(z-.014,front-.020,min(elevation-.07,lift+.35))]
                mesh.prism(shape,(.043,0,0),"basalt")
    for side in (-1,1):
        for i in range(6):
            u=side*(8.435+rng.uniform(-.8,.69))
            depth=9.25+i*.97
            size=rng.uniform(.70,1.55)*(1.0+i*.058)
            angular_stone(mesh,(u,depth,-.17), size, size*.89,size*.68,
                          rng.uniform(-.8,.8),"traver",.21)


def stone_works(mesh):
    for index,(u,d,w,depth,h,turn) in enumerate(STOCK):
        angular_stone(mesh,(u,d,-.16),w,depth,h,turn,"lime" if index%3==0 else "traver",.055)
        top=h-.147
        for mark in [-.32,-.14,.06,.26]:
            x=u+mark*w
            y=d+.21*depth+math.sin(turn)*mark
            box(mesh,x,y,ground(y,x)+top,.046,.142,.037,"basalt")
        if index in (1,3):
            # Two timber blocks keep a second cut slab clear of the ground.
            for x in (u-w*.26,u+w*.26):
                box(mesh,x,d,ground(d,x)+top,.109,depth*.81,.095,"beam")
            angular_stone(mesh,(u,d,top+.084),w*.82,depth*.73,.34,turn+.042,"traver",.065)
    # Tool bench and split wooden wedges by the work side. Two empty long
    # rails and their transverse runners form a low timber loading skid.
    for u in (-6.84,-5.10):
        beam(mesh,(u,8.52,ground(8.52,u)+.17),(u,11.47,ground(11.47,u)+.17),
             .161,.212,"beam")
    for d in (8.78,9.86,10.95):
        h=ground(d,-6)+.218
        beam(mesh,(-7.0,d,h),(-4.89,d,h+.11),.127,.122,"cedar")


def shelter(mesh):
    centre_u, centre_d = 7.38, 7.9
    roof_width = 5.47
    eaves = [(5.44,2.33),(10.39,2.86)]
    for u,d in POSTS:
        h=ground(d,u)
        angular_stone(mesh,(u,d,-.18),.49,.48,.35,.12,"tuff")
        box(mesh,u,d,h+.124,.233,.24,2.37+.105*(d-5.8),"beam")
        for shift in (-1,1):
            side=u+shift*.37
            if abs(side-centre_u)<2.6:
                beam(mesh,(u,d,h+1.89),(side,d,h+2.23),.123,.131,"cedar")
    for depth,eave in eaves:
        low,high=centre_u-roof_width/2,centre_u+roof_width/2
        beam(mesh,(low,depth,ground(depth,low)+eave),(high,depth,ground(depth,high)+eave),
             .196,.205,"beam")

    def at(u, t, extra=0.0):
        d=eaves[0][0]+(eaves[1][0]-eaves[0][0])*t
        h=eaves[0][1]+(eaves[1][1]-eaves[0][1])*t+extra
        return ground_point(u,d,h)

    lo,hi=centre_u-roof_width/2,centre_u+roof_width/2
    mesh.prism([at(lo,0),at(hi,0),at(hi,1),at(lo,1)],(0,0,-.075),"cedar")
    for row in range(10):
        a,b=row/10,min(1.0,(row+1.17)/10)
        for column in range(13):
            p=lo+roof_width*column/13
            q=lo+roof_width*(column+1)/13
            paint="tegula" if (row+column)%4 else "fired"
            mesh.prism([at(p+.025,a,.041),at(q-.025,a,.042),at(q-.024,b,.021),at(p+.022,b,.021)],
                       (0,0,-.028),paint)
            mesh.cover_tile(at(p,b,.041),at(p,a,.052),.070,paint)
    for y in range(11):
        u=lo+(y+.5)*(hi-lo)/11
        beam(mesh,(u,5.45,ground(5.45,u)+2.249),(u,10.38,ground(10.38,u)+2.76),
             .109,.122,"beam")
    # Rear retaining planks leave both side bays and the whole front open.
    for i in range(15):
        u=5.05+i*.328
        d=10.04
        box(mesh,u,d,ground(d,u)-.075,.306,.12,1.32,"cedar" if i%4 else "beam")
    h=ground(8.9,8.43)
    # Reuse the original timber-prop geometry at the local terrain height.
    bench_mesh=Domus()
    bench(bench_mesh,8.43,8.90,.86,1.52,.69)
    for i,vertex in enumerate(bench_mesh.vertices):
        bench_mesh.vertices[i]=(vertex[0],vertex[1],vertex[2]+h)
    offset=len(mesh.vertices)
    mesh.vertices.extend(bench_mesh.vertices)
    mesh.faces.extend(tuple(index+offset for index in face) for face in bench_mesh.faces)
    mesh.uvs.extend(bench_mesh.uvs)
    mesh.smoothing.extend(bench_mesh.smoothing)
    for i in range(3):
        d=8.67+i*.21
        mesh.beam(position(7.96,d,h+.983),position(8.44,d+.035,h+.984),.044,"cedar",7)
        box(mesh,8.506,d+.036,h+.943,.163,.122,.101,"iron")


def spoil(mesh):
    rng=random.Random(58141)
    for index in range(100):
        if index < 46:
            u=rng.choice([-1,1])*rng.uniform(7.6,10.4)
            d=rng.uniform(1.4,13.5)
        else:
            u=rng.uniform(-9.3,9.3)
            d=rng.uniform(10.7,13.0)
        size=rng.uniform(.12,.57)
        angular_stone(mesh,(u,d,-.045),size,size*rng.uniform(.64,.91),
                      size*rng.uniform(.39,.60),rng.uniform(-math.pi,math.pi),
                      "basalt" if index%6==0 else "tuff" if index%4==0 else "traver",.21)


def cube_proxy(name, u, d, w, depth, low, high, yaw=0.0):
    min_y=ground(d,u)-low
    bpy.ops.mesh.primitive_cube_add(size=1,location=position(u,d,min_y+high/2))
    part=bpy.context.object
    part.name=name+"_collision"
    part.scale=(depth,w,high)
    part.rotation_euler.z=yaw
    part["collision_mesh_only"]=True
    return part


def colliders():
    shapes=[]
    for index,(d,depth,w,h) in enumerate(BENCHES):
        shapes.append(cube_proxy(f"Terrace{index+1}",0,d,w-.18,depth-.27,.28,h+.08))
    for index,(u,d,w,depth,h,turn) in enumerate(STOCK):
        top=h+.34 if index in (1,3) else h-.075
        shapes.append(cube_proxy(f"CutBlock{index+1}",u,d,w*.90,depth*.92,.24,top+.27,turn))
    for index,(u,d) in enumerate(POSTS):
        shapes.append(cube_proxy(f"ShelterPost{index+1}",u,d,.29,.30,.15,2.91))
    shapes.append(cube_proxy("ShelterRear",7.38,10.04,4.57,.16,.16,1.62))
    shapes.append(cube_proxy("ShelterBench",8.43,8.90,1.52,.72,.14,1.08))
    return shapes


def build():
    source=OUT/"old_quarry_source"
    source.mkdir(parents=True,exist_ok=True)
    (source/".gdignore").touch()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.unit_settings.system="METRIC"
    bpy.context.scene["era_historical_year"]=-58
    bpy.context.scene["terrain_slope"]="positive depth=.029 and local Z=.057"
    with TemporaryDirectory() as temp:
        baseline={name:SWATCHES[name] for name in PALETTE}
        SWATCHES.update(PALETTE)
        try:
            paint=material(Path(temp))
        finally:
            SWATCHES.update(baseline)
    paint.name="Quarry_Limestone_Timber_Atlas"
    pieces=[]
    for label,draw in (("Quarry_RockBenches",terraces),("Quarry_DressedStone",stone_works),
                       ("Quarry_Shelter",shelter),("Quarry_Rubble",spoil)):
        model=Domus()
        draw(model)
        item=model.to_mesh(label,paint)
        item["era_min_ce"]=-100
        pieces.append(item)
    export(OUT/"old_quarry.glb",pieces)
    physics=colliders()
    export(OUT/"old_quarry_collision.glb",physics)
    guides=bpy.data.collections.new("Physics guides · hidden by default")
    bpy.context.scene.collection.children.link(guides)
    for item in physics:
        for collection in list(item.users_collection):
            collection.objects.unlink(item)
        guides.objects.link(item)
        item.display_type="WIRE"
    guides.hide_render=True
    guides.hide_viewport=True
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(source/"old_quarry.blend"),compress=True)
    for item in pieces:
        item.data.calc_loop_triangles()
    print("ROMAN_QUARRY_BUILD triangles=%d colliders=%d" %
          (sum(len(obj.data.loop_triangles) for obj in pieces),len(physics)))


if __name__=="__main__":
    build()
