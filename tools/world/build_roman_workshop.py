"""Build the Valdora-era Roman street workshop and wine shop in Blender 4.3.2.

The plan uses (along the street, depth, elevation). Blender's glTF exporter
maps the module to Godot (depth, elevation, along the street). The floor is
Y=0 and both entrances face -X. All models and textures are generated here
or by the project's existing original Roman-material pipeline.
"""
from pathlib import Path
import math
import random
import sys
from tempfile import TemporaryDirectory

import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "art/architecture"))
from build_atrium import Domus, box_between, material

OUTPUT = ROOT / "prototype/assets/roman_quarter/workshop"
EAVE, RIDGE = 3.25, 4.65
SEED = 58119
WIDTH, DEPTH = 9.6, 6.4
DOORS = (-2.4, 2.4)


def position(u, depth, h):
    return Vector((depth, -u, h))


def box(mesh, u, d, h, width, depth, height, paint):
    mesh.box(d, -u, h, depth, width, height, paint)


def beam(mesh, start, end, width, depth, paint):
    box_between(mesh, position(*start), position(*end), width, depth, paint)


def span(mesh, low, high, d, h, depth, height, paint):
    box(mesh, (low + high) / 2, d, h, high - low, depth, height, paint)


def lathe(mesh, u, d, h, profile, paint, sides=16):
    """Profile follows the outside, rim, and hollow inside of a fired pot."""
    points = []
    for z, radius in profile:
        points.extend(position(u + radius * math.cos(i * math.tau / sides),
                               d + radius * math.sin(i * math.tau / sides), h + z)
                      for i in range(sides))
    faces = [tuple(reversed(range(sides)))]
    for row in range(len(profile) - 1):
        a = row * sides
        b = a + sides
        for i in range(sides):
            nxt = (i + 1) % sides
            faces.append((a+i, a+nxt, b+nxt, b+i))
    faces.append(tuple(range(len(points)-sides, len(points))))
    mesh.add(points, faces, paint, smooth=True)


def pot(mesh, u, d, h, radius, tall, paint):
    lathe(mesh, u, d, h, [(0, radius*.37), (.14*tall, radius*.71),
          (.42*tall, radius), (.72*tall, radius*.90), (.85*tall, radius*.49),
          (.97*tall, radius*.49), (tall, radius*.57), (tall, radius*.39),
          (.91*tall, radius*.36), (.73*tall, radius*.44), (.22*tall, radius*.60)],
          paint)
    for sign in (-1, 1):
        points = [(u + sign*radius*amount, d, h+tall*z)
                  for amount, z in ((.44,.87), (.81,.83), (1.02,.74), (.91,.61))]
        for a, b in zip(points, points[1:]):
            mesh.beam(position(*a), position(*b), .025, paint, 7)


def inscription(mesh, title, u):
    curve = bpy.data.curves.new(title, type="FONT")
    curve.body = title
    curve.size = 0.25
    curve.align_x = "CENTER"
    letter = bpy.data.objects.new(title, curve)
    bpy.context.collection.objects.link(letter)
    letter.matrix_world = Matrix(((0,0,-1,-.14), (-1,0,0,-u), (0,1,0,2.59), (0,0,0,1)))
    bpy.context.view_layer.update()
    evaluated = letter.evaluated_get(bpy.context.evaluated_depsgraph_get())
    source = evaluated.to_mesh()
    points = [letter.matrix_world @ vertex.co for vertex in source.vertices]
    mesh.add(points, [tuple(poly.vertices) for poly in source.polygons], "lime")
    evaluated.to_mesh_clear()
    bpy.data.objects.remove(letter, do_unlink=True)
    bpy.data.curves.remove(curve)


def facade(mesh):
    half = WIDTH / 2
    bands = [(-half,-3.15), (-1.65,1.65), (3.15,half)]
    for lo, hi in bands:
        span(mesh, lo, hi, .15, 0, .30, EAVE, "intonaco")
        span(mesh, lo, hi, -.005, .25, .022, .84, "oxide")
        span(mesh, lo, hi, -.021, 1.05, .026, .047, "ochre")
        for row in range(2):
            count = max(2, round((hi-lo)/.48) + row)
            pitch = (hi-lo)/count
            for index in range(count):
                centre = lo + (index+.5)*pitch
                paint = "traver" if (index+row)%4==0 else "tuff"
                box(mesh, centre, -.028, .017+row*.13, pitch-.022, .078, .104, paint)
    for u, title in zip(DOORS, ("FABER", "TABERNA")):
        box(mesh, u, .15, 2.25, 1.5, .30, EAVE-2.25, "intonaco")
        # Travertine jambs stay outside the opening. The stone sill is level.
        for sign in (-1, 1):
            jamb = u+sign*.822
            box(mesh, jamb, .016, .03, .145, .36, 2.26, "traver")
            box(mesh, jamb, -.03, .03, .184, .40, .195, "tuff")
            # Planked shutters are fastened back along the jambs in the room.
            for index in range(4):
                d = .32 + .19*index
                box(mesh, jamb, d, .053, .068, .175, 2.10,
                    "cedar" if index % 3 else "beam")
            for h in (.44,1.74):
                box(mesh, jamb, .60, h, .090, .72, .053, "iron")
                mesh.beam(position(jamb-sign*.065,.27,h+.034),
                          position(jamb-sign*.070,.27,h+.034), .031, "bronze", 8)
        box(mesh, u, -.017, 2.25, 1.75, .37, .137, "traver")
        box(mesh, u, -.112, 2.501, 1.55, .05, .35, "beam")
        inscription(mesh, title, u)
        box(mesh, u, .075, -.058, 1.50, .35, .058, "traver")
    # Timber cornice with painted square ends and a damp shadow line.
    box(mesh, 0, -.051, 3.10, WIDTH+.15, .23, .142, "beam")
    for index in range(22):
        u=-4.65+index*.442
        box(mesh, u, -.186, 3.107, .106, .224, .095, "cedar")
    for u in (-3.92, 0, 3.92):
        box(mesh, u, -.046, 1.24, .81, .07, .61, "fired")
        # A barred timber vent: broad inset, prominent frame, opaque rear.
        box(mesh, u, -.088, 1.35, .62, .013, .40, "beam")
        for du in (-.25,-.125,0,.125,.25):
            box(mesh, u+du, -.115, 1.34, .036, .065, .43, "cedar")
        box(mesh, u, -.11, 1.24, .84, .14, .10, "traver")
        box(mesh, u, -.11, 1.77, .79, .14, .1, "traver")


def walls(mesh):
    box(mesh, 0, DEPTH/2, -.185, WIDTH, DEPTH, .185, "paving")
    for u in (-4.67, 4.67):
        box(mesh, u, DEPTH/2, 0, .26, DEPTH, EAVE, "intonaco")
        box(mesh, u, DEPTH/2, 0, .303, DEPTH, .22, "tuff")
        mesh.prism([position(u,0,EAVE),position(u,DEPTH,EAVE),
                    position(u,DEPTH/2,RIDGE)], position(.26,0,0), "intonaco")
    box(mesh, 0, DEPTH-.13, 0, WIDTH, .26, EAVE, "intonaco")
    box(mesh, 0, 1.36, 0, .145, 2.2, EAVE, "intonaco")
    box(mesh, 0, 5.0, 0, .145, 2.35, EAVE, "intonaco")
    box(mesh, 0, 3.15, 2.29, .145, 1.41, EAVE-2.29, "intonaco")
    # Different floors distinguish the working area from the customers' side.
    box(mesh, 2.42, 3.11, -.009, 4.16, 5.67, .011, "mosaic")
    box(mesh, -2.42, 3.11, -.009, 4.16, 5.67, .011, "basalt")


def roofing(mesh):
    rng = random.Random(SEED)
    eaves = (-.46, DEPTH+.35)
    steps, columns = 9, 24
    hip = DEPTH / 2
    for edge in eaves:
        def surface(u, factor, extra=0.0):
            return position(u, edge+(hip-edge)*factor, EAVE+(RIDGE-EAVE)*factor+extra)
        mesh.prism([surface(-4.98,0),surface(4.98,0),
                    surface(4.98,1),surface(-4.98,1)], (0,0,-.105), "fired")
        for row in range(steps):
            t0 = row/steps
            t1 = min(1., (row+1.15)/steps)
            for col in range(columns):
                a = -4.96 + col*9.92/columns
                b = -4.96 + (col+1)*9.92/columns
                drop = rng.uniform(.002,.021)
                paint = "tegula" if rng.random() > .28 else "fired"
                mesh.prism([surface(a+.029,t0,.030+drop),surface(b-.029,t0,.032+drop),
                            surface(b-.029,t1,.023),surface(a+.029,t1,.023)],
                           (0,0,-.031), paint)
                mesh.cover_tile(surface(a,t1,.047), surface(a,t0,.055+drop), .079, paint)
        for u in (-4.81,-3.86,-2.90,-1.94,-.98,0,.98,1.94,2.90,3.86,4.81):
            beam(mesh, (u,edge,EAVE-.09), (u,hip,RIDGE-.09), .10, .136, "beam")
    for col in range(24):
        a = -5 + col*10/24
        b = -5 + (col+1.1)*10/24
        mesh.cover_tile(position(a,hip,RIDGE+.035), position(b,hip,RIDGE+.04), .15,
                        "fired" if col%4==0 else "tegula")


def blacksmith(mesh):
    # Masonry forge with dark hearth, hood, stack, charcoal bin and hand tools.
    u, d = -3.36, 5.18
    box(mesh,u,d,.001,1.46,1.29,.79,"tuff")
    box(mesh,u,d,.79,1.52,1.35,.092,"basalt")
    for side in (-1, 1):
        box(mesh,u+side*.54,d,.88,.37,1.29,.18,"fired")
    box(mesh,u,d+.46,.88,1.17,.36,.22,"fired")
    for index in range(10):
        x = u+.38*math.sin(index*2.119)
        y = d+.45*math.cos(index*3.78)
        lathe(mesh,x,y,.877,[(0,.078),(.066,.056),(.116,.034)],"basalt",6)
    box(mesh,u,d,2.32,1.29,.98,.19,"beam")
    mesh.prism([position(u-.56,d-.40,2.5),position(u+.56,d-.40,2.5),
                position(u+.43,d-.29,2.99),position(u-.43,d-.29,2.99)],
               (.61,0,0),"intonaco")
    box(mesh,u,d+.04,2.50,.76,.64,2.19,"fired")
    box(mesh,u,d+.04,4.59,.90,.78,.13,"tegula")
    # An anvil, its horn and face formed from a tapered extrusion.
    lathe(mesh,-1.33,4.73,.005,[(0,.29),(.56,.26)],"beam",12)
    mesh.prism([position(-1.70,4.52,.57),position(-1.0,4.52,.57),
                position(-1.23,4.52,.75),position(-1.40,4.52,.75)],
               (.28,0,0),"iron")
    box(mesh,-1.36,4.66,.75,.68,.31,.10,"iron")
    mesh.prism([position(-1.04,4.51,.75),position(-.81,4.66,.83),
                position(-1.04,4.81,.75)], (0,0,.06), "iron")
    bench(mesh,-3.82,2.86,.84,1.38,.84)
    for ix in range(3):
        y = 2.63+.16*ix
        mesh.beam(position(-4.12,y,.928),position(-3.65,y+.055,.928),.025,"cedar",7)
        box(mesh,-3.64,y+.065,.905,.15,.095,.071,"iron")
    # A compact rack avoids adding invisible obstacles next to the door.
    for z in (.44,.90,1.32):
        box(mesh,-4.34,1.47,z,.62,1.28,.092,"cedar")
    for d in (.90,2.03):
        box(mesh,-4.56,d,.03,.085,.09,1.51,"beam")
    for d in (.92,1.27,1.65):
        pot(mesh,-4.20,d,1.413,.115,.29,"tegula")
    oil_lamp(mesh, -3.76, 2.9)
    oil_lamp(mesh, -.70, 3.83)


def oil_lamp(mesh, u, d):
    box(mesh,u,d,1.93,.39,.34,.12,"cedar")
    lathe(mesh,u,d,2.039,[(0,.061),(.032,.104),(.070,.090),(.057,.043)],
          "bronze",12)


def taverna(mesh):
    # Keep the doorway and the middle of the shop clear for the player.
    bench(mesh,3.27,4.74,.93,2.21,1.03)
    box(mesh,3.27,4.23,.02,2.12,.14,.87,"intonaco")
    box(mesh,3.27,4.15,.22,2.14,.028,.60,"oxide")
    for ix in range(4):
        pot(mesh,2.52+ix*.48,4.67,1.029,.151,.47,("fired","tegula","ochre")[ix%3])
    for ix in range(3):
        pot(mesh,1.12+.50*ix,5.89,.002,.21,.90,"fired")
    bench(mesh,3.9,2.25,.70,1.11,1.00)
    bench(mesh,3.9,1.47,.45,1.08,.29)
    bench(mesh,3.9,3.03,.45,1.08,.29)
    for u in (3.68,4.07):
        lathe(mesh,u,2.20,.803,[(0,.082),(.10,.12),(.105,.095),(.043,.060)],
              "tegula",14)
    oil_lamp(mesh, 4.20, 5.8)


def bench(mesh,u,d,h,width,depth):
    box(mesh,u,d,h,width,depth,.093,"cedar")
    for shift_u in (-.5,.5):
        for shift_d in (-.5,.5):
            box(mesh,u+shift_u*(width-.16),d+shift_d*(depth-.13),.012,.112,.11,h,"beam")
    for shift_u in (-.5,.5):
        box(mesh,u+shift_u*(width-.21),d,h*.41,.077,max(.15,depth-.08),.069,"beam")


def export(path, objects):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=str(path), export_format="GLB", use_selection=True,
        export_extras=True, export_animations=False, export_cameras=False, export_lights=False
    )


def collision_boxes():
    # (name, centre along street, centre depth, base Y, along street,
    # depth, height). Keep furniture as authored blocking hulls. Door gaps
    # extend from the plot edge to the interior at u ± 2.4.
    return [
        ("Floor",0,3.2,-.18,9.62,6.40,.18),
        ("FrontLeft",-3.975,.15,0,1.65,.30,3.25),
        ("FrontCentre",0,.15,0,3.30,.30,3.25),
        ("FrontRight",3.975,.15,0,1.65,.30,3.25),
        ("JambTopForge",-2.4,.15,2.25,1.5,.30,1.0),
        ("JambTopShop",2.4,.15,2.25,1.5,.30,1.0),
        ("SideLeft",-4.67,3.20,0,.26,6.40,3.25),
        ("SideRight",4.67,3.20,0,.26,6.40,3.25),
        ("Back",0,6.27,0,9.60,.26,3.25),
        ("PartitionFront",0,1.36,0,.145,2.2,3.25),
        ("PartitionBack",0,5.0,0,.145,2.35,3.25),
        ("PartitionLintel",0,3.15,2.29,.145,1.41,.96),
        ("Forge",-3.36,5.18,.002,1.46,1.29,.91),
        ("Anvil",-1.33,4.73,.002,.61,.58,.83),
        ("Workbench",-3.82,2.86,.002,1.38,.84,.94),
        ("TavernCounter",3.27,4.74,.002,2.2,1.04,1.03),
        ("TableandSeats",3.90,2.25,.002,1.10,1.84,.78),
        ("Shelf",-4.34,1.47,.002,.62,1.28,1.51),
    ]


def build():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    source = OUTPUT / "source"
    source.mkdir(exist_ok=True)
    (source / ".gdignore").touch()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.unit_settings.system = "METRIC"
    bpy.context.scene["era_historical_year"] = -58
    bpy.context.scene["source"] = "Original modular tabernae based on Late Republican building and roofing forms"
    with TemporaryDirectory() as temp:
        paint = material(Path(temp))
        paint.name = "RomanTabernae_WornStoneWoodClay"
        meshes = []
        for label, draw in (("Workshop_Front",facade),("Workshop_Enclosure",walls),
                            ("Workshop_Tegulae",roofing),("Blacksmith",blacksmith),
                            ("Taverna",taverna)):
            geometry = Domus()
            draw(geometry)
            meshes.append(geometry.to_mesh(label, paint))
        for obj in meshes:
            obj["era_min_ce"] = -100
        export(OUTPUT/"roman_workshop.glb", meshes)
        collision_nodes = []
        for name, u, depth, h, w, dep, hsize in collision_boxes():
            bpy.ops.mesh.primitive_cube_add(size=1, location=position(u, depth, h+hsize/2))
            proxy = bpy.context.object
            proxy.name = "Workshop_"+name+"_collision"
            proxy.scale = (dep,w,hsize)
            proxy["collision_mesh_only"] = True
            collision_nodes.append(proxy)
        export(OUTPUT/"roman_workshop_collision.glb", collision_nodes)
        guides = bpy.data.collections.new("Physics guides · hidden by default")
        bpy.context.scene.collection.children.link(guides)
        for node in collision_nodes:
            for owner in list(node.users_collection):
                owner.objects.unlink(node)
            guides.objects.link(node)
            node.display_type = "WIRE"
        guides.hide_viewport = True
        guides.hide_render = True
        bpy.ops.object.select_all(action="DESELECT")
        meshes[0].select_set(True)
        bpy.context.view_layer.objects.active = meshes[0]
        bpy.context.preferences.filepaths.save_version = 0
        bpy.ops.wm.save_as_mainfile(filepath=str(source/"roman_workshop.blend"), compress=True)
    for node in meshes:
        node.data.calc_loop_triangles()
    print("ROMAN_WORKSHOP_BUILD triangles=%d colliders=%d" %
          (sum(len(o.data.loop_triangles) for o in meshes),len(collision_nodes)))


if __name__ == "__main__":
    build()
