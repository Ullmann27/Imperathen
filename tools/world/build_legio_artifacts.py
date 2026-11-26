"""Build IMPERATHEN's hand and roadside props. Run with Blender 4.3+ in background."""
import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'prototype/assets/legio'


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def finish(name, colour, roughness, metallic=0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*colour, 1)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes['Principled BSDF']
    bsdf.inputs['Base Color'].default_value = mat.diffuse_color
    bsdf.inputs['Roughness'].default_value = roughness
    bsdf.inputs['Metallic'].default_value = metallic
    return mat


def materialize(obj, name, mat):
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def block(name, size, at, mat, bevel=.003):
    bpy.ops.mesh.primitive_cube_add(size=1, location=at)
    obj = materialize(bpy.context.object,name,mat)
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    mod = obj.modifiers.new('Rounded carved edges','BEVEL')
    mod.width = bevel
    mod.segments = 2
    obj.modifiers.new('Weighted flat faces','WEIGHTED_NORMAL')
    return obj


def lathe(name, profile, mat, sides=40):
    vertices = [(r*math.cos(2*math.pi*k/sides), r*math.sin(2*math.pi*k/sides), z)
                for z,r in profile for k in range(sides)]
    faces = [(j*sides+k,j*sides+(k+1)%sides,(j+1)*sides+(k+1)%sides,(j+1)*sides+k)
             for j in range(len(profile)-1) for k in range(sides)]
    faces.extend([tuple(reversed(range(sides))),tuple(range(len(vertices)-sides,len(vertices)))])
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices,[],faces)
    mesh.update()
    obj = materialize(bpy.data.objects.new(name,mesh),name,mat)
    bpy.context.collection.objects.link(obj)
    for p in mesh.polygons[:-2]:
        p.use_smooth = True
    return obj


def cord(name, points, radius, mat):
    curve = bpy.data.curves.new(name,'CURVE')
    curve.dimensions = '3D'
    curve.resolution_u = 6
    curve.bevel_depth = radius
    curve.bevel_resolution = 2
    spline = curve.splines.new('BEZIER')
    spline.bezier_points.add(len(points)-1)
    for p,co in zip(spline.bezier_points,points):
        p.co = co
        p.handle_left_type = 'AUTO'
        p.handle_right_type = 'AUTO'
    obj = materialize(bpy.data.objects.new(name,curve),name,mat)
    bpy.context.collection.objects.link(obj)
    return obj


def inscription(name, text, at, size, mat):
    curve = bpy.data.curves.new(name,'FONT')
    curve.body = text
    curve.align_x = 'CENTER'
    curve.align_y = 'CENTER'
    curve.size = size
    curve.space_line = 1.20
    curve.resolution_u = 3
    obj = materialize(bpy.data.objects.new(name,curve),name,mat)
    obj.location = at
    bpy.context.collection.objects.link(obj)


def export(name):
    bpy.ops.object.select_all(action='SELECT')
    for obj in list(bpy.context.selected_objects):
        if obj.type in ('CURVE','FONT'):
            bpy.context.view_layer.objects.active = obj
            with bpy.context.temp_override(selected_editable_objects=[obj]):
                bpy.ops.object.convert(target='MESH')
    namepath = OUT/(name+'.glb')
    bpy.ops.export_scene.gltf(filepath=str(namepath),export_format='GLB',export_animations=False,
                              export_skins=False,export_morph=False,export_extras=False,export_apply=True)
    print('LEGIO_PROP',name,namepath.stat().st_size)


def tablet():
    clear_scene()
    wood = finish('Oiled maple',(.24,.116,.047),.63)
    wax = finish('Smoked beeswax',(.085,.046,.031),.48)
    groove = finish('Stylus marks',(.55,.31,.133),.66)
    bronze = finish('Worn bronze',(.36,.20,.072),.41,.48)
    length = .166
    for x in [-.054,.054]:
        block('Maple leaf',(.105,length,.009),(x,0,.0045),wood)
        block('Recessed wax',(.088,length-.019,.0014),(x,0,.009),wax,.001)
        for side in [-1,1]:
            block('Carved rim',(.005,length-.006,.003),(x+side*.048,0,.01),wood,.0011)
    for y in [-.052,.052]:
        cord('Binding thong',[(-.006,y,.012),(0,y,.016),(.007,y,.011)],.0018,bronze)
    inscription('Recipient','FABIO',(-.054,.041,.0101),.015,groove)
    inscription('Quantity','II',(-.054,.008,.0101),.025,groove)
    inscription('Author','SEXTVS',(.054,-.040,.0101),.012,groove)
    inscription('Order','AD NVNDINAS\nII CORBES\nCARBONIS',(.054,.018,.0101),.010,groove)
    cord('Bronze stylus',[(-.098,-.071,.012),(-.059,-.068,.013),(-.011,-.065,.012)],.0015,bronze)
    export('sextus_tablet')


def gate_letter():
    clear_scene()
    paper = finish('Papyrus',(.68,.47,.25),.94)
    ink = finish('Carbon ink',(.042,.025,.012),.91)
    block('Message sheet',(.184,.22,.0014),(0,0,.0007),paper,.0005)
    # Rolled ends have visible spiral sections from either end of the sheet.
    for side in (-1,1):
        start = side*.109
        verts,faces = [],[]
        for i in range(61):
            t=i/60
            a=t*math.pi*3.2
            r=.015-.009*t
            for x in (-.093,.093):
                verts.append((x,start+side*r*math.sin(a),.015-r*math.cos(a)))
            if i: faces.append((2*i-2,2*i-1,2*i+1,2*i))
        mesh=bpy.data.meshes.new('Rolled fibre')
        mesh.from_pydata(verts,[],faces)
        obj=materialize(bpy.data.objects.new('Rolled edge',mesh),'Rolled edge',paper)
        bpy.context.collection.objects.link(obj)
        mod=obj.modifiers.new('Papyrus thickness','SOLIDIFY')
        mod.thickness=.0008
    inscription('Addressee','CASSIAE',(0,.06,.0016),.019,ink)
    inscription('Notice','VIA   LIBERA\nAD   PORTAM',(0,0,.0016),.014,ink)
    inscription('Instructions','PLAVSTRVM MITTE',(0,-.049,.0016),.012,ink)
    export('gate_letter')


def amphora():
    clear_scene()
    clay = finish('Iron-rich fired terracotta',(.51,.19,.085),.93)
    pigment = finish('Red slip',(.27,.064,.027),.83)
    cork = finish('Fibre stopper',(.29,.19,.10),.96)
    profile = [(0,.035),(.03,.045),(.075,.051),(.14,.086),(.26,.132),(.35,.16),(.43,.169),
               (.5,.154),(.54,.119),(.568,.076),(.6,.056),(.65,.055),(.658,.068),(.672,.071),
               (.682,.06),(.682,.043),(.656,.044),(.615,.045)]
    jar = lathe('Storage amphora',profile,clay,48)
    jar.data.materials.append(pigment)
    for p in jar.data.polygons:
        if .50 < p.center.z < .54 or .654 < p.center.z < .673:
            p.material_index = 1
    for side in (-1,1):
        cord('Pulled clay handle',[(side*.058,0,.642),(side*.119,0,.627),(side*.135,0,.58),
                                  (side*.134,0,.542),(side*.125,0,.528)],.016,clay)
    lathe('Stopper',[(.665,.046),(.685,.048),(.691,.045)],cork,24)
    export('transport_amphora')


def bust():
    clear_scene()
    file=ROOT/'art/frontier_people/elder.blend'
    with bpy.data.libraries.load(str(file),link=False) as (_,selection):
        selection.objects=['HeroBody','HeroEyes','HeroTunic','FrontierBeard']
    stone=finish('Weathered limestone',(.62,.55,.445),.87)
    base=finish('Grey plinth',(.33,.30,.26),.91)
    for source in selection.objects:
        mesh=source.data.copy()
        obj=bpy.data.objects.new(source.name+' carving',mesh)
        bpy.context.collection.objects.link(obj)
        obj.shape_key_clear()
        bm=bmesh.new()
        bm.from_mesh(mesh)
        cut=bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),
                                   plane_co=(0,0,1.12),plane_no=(0,0,1),clear_inner=True)
        edges=[e for e in cut['geom_cut'] if isinstance(e,bmesh.types.BMEdge) and e.is_valid]
        if edges: bmesh.ops.holes_fill(bm,edges=edges,sides=0)
        bm.to_mesh(mesh)
        bm.free()
        mesh.materials.clear()
        mesh.materials.append(stone)
        for poly in mesh.polygons: poly.material_index=0
        obj.location=(0,.065,.75-1.12*1.34)
        obj.scale=(1.34,1.34,1.34)
        mod=obj.modifiers.new('Chisel silhouette','DECIMATE')
        mod.ratio=.48
    block('Foot',(.47,.41,.074),(0,0,.037),base,.012)
    block('Middle fillet',(.42,.36,.058),(0,0,.096),base,.008)
    block('Pedestal die',(.35,.30,.546),(0,0,.392),base,.012)
    block('Capital',(.40,.36,.05),(0,0,.688),base,.007)
    block('Upper stone',(.46,.39,.06),(0,0,.738),stone,.012)
    export('ancestor_bust')


def render_letters(destination):
    """Raking light reveals the raised stylus, incisions, bindings and rolled edges."""
    clear_scene()

    def place(name, position, angle):
        bpy.ops.import_scene.gltf(filepath=str(OUT / (name + '.glb')))
        parents = [obj for obj in bpy.context.selected_objects if obj.parent is None]
        root = bpy.data.objects.new(name,None)
        bpy.context.collection.objects.link(root)
        for obj in parents:
            obj.parent = root
        root.rotation_euler.z = math.radians(angle)
        root.location = position

    place('sextus_tablet',(-.102,-.027,0),-12)
    place('gate_letter',(.129,.037,0),10)
    place('transport_amphora',(-.31,.28,0),36)
    board = finish('Dark workshop timber',(.071,.039,.020),.85)
    block('Display surface',(8,8,.08),(0,0,-.041),board,.002)

    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 64
    scene.cycles.use_denoising = False
    scene.render.resolution_x = 900
    scene.render.resolution_y = 560
    scene.render.resolution_percentage = 100
    scene.world = bpy.data.worlds.new('Soft studio ambience')
    scene.world.use_nodes = True
    scene.world.node_tree.nodes['Background'].inputs['Color'].default_value = (.28,.34,.44,1)
    scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value = .36

    def point(obj,target):
        obj.rotation_euler = (Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()

    for location,energy,size,colour in [((-.32,.12,.45),7,.32,(1,.84,.65)),
                                        ((.29,-.26,.53),4,.35,(.84,.89,1))]:
        bpy.ops.object.light_add(type='AREA',location=location)
        lamp = bpy.context.object
        lamp.data.energy, lamp.data.size, lamp.data.color = energy, size, colour
        point(lamp,(0,0,0))
    bpy.ops.object.camera_add(location=(.04,-.49,.57))
    scene.camera = bpy.context.object
    point(scene.camera,(.004,.008,0))
    scene.camera.data.type = 'ORTHO'
    scene.camera.data.ortho_scale = .54
    scene.render.image_settings.file_format = 'WEBP'
    scene.render.image_settings.quality = 94
    scene.render.filepath = str(Path(destination).resolve())
    bpy.ops.render.render(write_still=True)


if __name__ == '__main__':
    if '--letters' in sys.argv:
        tablet()
        gate_letter()
    elif '--review' in sys.argv:
        render_letters(sys.argv[sys.argv.index('--review')+1])
    else:
        OUT.mkdir(parents=True,exist_ok=True)
        tablet()
        gate_letter()
        amphora()
        bust()
