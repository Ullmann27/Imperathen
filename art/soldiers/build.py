"""Build the original IMPERATHEN field company with Blender 4.3.

blender -b -t 2 -P art/soldiers/build.py
"""
import json
import math
from pathlib import Path

import bpy
from mathutils import Quaternion, Vector

SOURCE = Path(__file__).resolve().parent
OUTPUT = SOURCE.parents[1] / "prototype/assets/soldiers"
ROLES = ("heavy", "spear", "archer", "officer")
TAU = math.tau

# Sixteen hand-authored swatches. Each cell has its own weave, grain or patina.
PALETTE = {
    "linen": "dec798", "oxblood": "963e31", "hide": "674335", "trim": "d8ad63",
    "iron": "869496", "steel": "b3bdba", "bronze": "aa8050", "shadow": "373732",
    "skin": "be8866", "cheek": "a76e54", "brow": "513d32", "wood": "976947",
    "pine": "385c56", "plume": "a34d3c", "offwhite": "ddd3ba", "charcoal": "465059",
}


def atlas_material():
    size, cell = 128, 32
    names = list(PALETTE)
    image = bpy.data.images.new("Field_company_pigments", size, size)
    pixels = []
    for y in range(size):
        for x in range(size):
            name = names[x // cell + 4 * (y // cell)]
            hex_color = PALETTE[name]
            grain = ((x * 73 + y * 131 + x * y * 37) % 19 - 9) / 430
            if name in ("linen", "oxblood", "pine", "plume"):
                grain += (0.027 if x % 4 == 0 else 0) - (0.035 if y % 3 == 0 else 0)
            if name in ("wood", "hide"):
                grain += .037 * math.sin(x * .8 + math.sin(y * .14))
            if name in ("iron", "steel", "bronze"):
                grain += .036 * math.cos(x * .2 + y * .27)
            for i in (0, 2, 4):
                value = max(.01, min(.99, int(hex_color[i:i + 2], 16) / 255 + grain))
                pixels.append(value)
            pixels.append(1)
    image.pixels.foreach_set(pixels)
    image.pack()
    mat = bpy.data.materials.new("Field_company_woven_atlas")
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Roughness"].default_value = .70
    tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = image
    mat.node_tree.links.new(tex.outputs["Color"], shader.inputs["Base Color"])
    finish = bpy.data.images.new("Field_company_finish", 4, 4, is_data=True)
    finish_pixels = []
    for name in names:
        metal = name in ("iron", "steel", "bronze", "trim")
        finish_pixels.extend((1, .43 if metal else .84, .71 if metal else .02, 1))
    finish.pixels.foreach_set(finish_pixels)
    finish.pack()
    properties = mat.node_tree.nodes.new("ShaderNodeTexImage")
    properties.image = finish
    properties.interpolation = "Closest"
    channels = mat.node_tree.nodes.new("ShaderNodeSeparateColor")
    mat.node_tree.links.new(properties.outputs["Color"], channels.inputs["Color"])
    mat.node_tree.links.new(channels.outputs["Green"], shader.inputs["Roughness"])
    mat.node_tree.links.new(channels.outputs["Blue"], shader.inputs["Metallic"])
    return mat


class Geometry:
    """Batches authored components into one atlas surface, preserving skin weights."""
    def __init__(self, detail):
        self.detail = detail
        self.module = "Body"
        self.modules = {}
        self.verts, self.faces, self.uvs, self.weights, self.smoothing = [], [], [], [], []

    def vertex(self, xyz, bone):
        self.modules.setdefault(self.module, []).append(len(self.verts))
        self.verts.append(tuple(xyz))
        self.weights.append(bone)
        return len(self.verts) - 1

    def face(self, indices, name, coords, smooth=False):
        index = list(PALETTE).index(name)
        self.faces.append(tuple(indices))
        self.uvs.append([((index % 4 + .09 + .82 * u) / 4,
                          (index // 4 + .09 + .82 * v) / 4) for u, v in coords])
        self.smoothing.append(smooth)

    def tube(self, rings, color, bone, sides=12, folds=0, smooth=True):
        # Each ring is (x, y, z, radius-x, radius-y [, weights]). Ground-parallel
        # contours are used for forms with a vertical principal axis.
        n = max(4, round(sides * (1, .64, .35)[self.detail]))
        if self.detail == 2 and len(rings) > 3:
            rings = [rings[0], rings[len(rings) // 2], rings[-1]]
        rows = []
        for k, (x, y, z, rx, ry, *weights) in enumerate(rings):
            row = []
            for j in range(n):
                a = j * TAU / n
                ease = 1 + folds * math.cos(a * 8 + k * .19)
                row.append(self.vertex((x + rx * ease * math.cos(a),
                                        y + ry * ease * math.sin(a), z), weights[0] if weights else bone))
            rows.append(row)
        for k, (lo, hi) in enumerate(zip(rows, rows[1:])):
            for j in range(n):
                h = (j + 1) % n
                self.face((lo[j], lo[h], hi[h], hi[j]), color,
                          ((j/n, k/(len(rows)-1)), ((j+1)/n, k/(len(rows)-1)),
                           ((j+1)/n, (k+1)/(len(rows)-1)), (j/n, (k+1)/(len(rows)-1))), smooth)
        caps = [(row, reverse) for row, reverse in ((rows[0], True), (rows[-1], False))]
        for row, reverse in caps:
            order = list(reversed(range(n))) if reverse else list(range(n))
            self.face([row[j] for j in order], color,
                      [(.5+.46*math.cos(j*TAU/n), .5+.46*math.sin(j*TAU/n)) for j in order])

    def rod(self, path, radii, color, bone, sides=7, ring_bones=None):
        n = max(3, round(sides * (1, .72, .52)[self.detail]))
        rows = []
        for k, (point, radius) in enumerate(zip(path, radii)):
            tangent = Vector(path[min(k+1, len(path)-1)]) - Vector(path[max(k-1, 0)])
            axis = tangent.normalized()
            a = Vector((1, 0, 0)) if abs(axis.x) < .9 else Vector((0, 1, 0))
            b = axis.cross(a).normalized()
            a = b.cross(axis).normalized()
            rows.append([self.vertex(Vector(point) + radius * (a*math.cos(j*TAU/n) + b*math.sin(j*TAU/n)), ring_bones[k] if ring_bones else bone)
                         for j in range(n)])
        for i, (r, s) in enumerate(zip(rows, rows[1:])):
            for j in range(n):
                k = (j+1) % n
                self.face((r[j], r[k], s[k], s[j]), color, ((j/n,0),((j+1)/n,0),((j+1)/n,1),(j/n,1)), True)
        for row in (list(reversed(rows[0])), rows[-1]):
            self.face(row, color, [(.5+.48*math.cos(i*TAU/n),.5+.48*math.sin(i*TAU/n)) for i in range(n)])

    def panel(self, front, color, bone, depth=.014):
        points = list(front)
        # Front normal should point towards -Y.
        cross = (Vector(points[1])-Vector(points[0])).cross(Vector(points[2])-Vector(points[0]))
        if cross.y > 0:
            points.reverse()
        a = [self.vertex(p, bone) for p in points]
        b = [self.vertex((x,y+depth,z), bone) for x,y,z in points]
        xs, zs = [p[0] for p in points], [p[2] for p in points]
        uv = [((x-min(xs))/max(.001,max(xs)-min(xs)), (z-min(zs))/max(.001,max(zs)-min(zs))) for x,y,z in points]
        self.face(a, color, uv)
        self.face(b[::-1], color, uv[::-1])
        for i in range(len(a)):
            j = (i+1) % len(a)
            self.face((a[i],b[i],b[j],a[j]),color,((0,0),(0,1),(1,1),(1,0)))

    def object(self, name, mat, arm=None):
        mesh = bpy.data.meshes.new(name)
        mesh.from_pydata(self.verts, [], self.faces)
        mesh.update()
        mesh.materials.append(mat)
        uv = mesh.uv_layers.new(name="Woven_atlas")
        for face, coords, smooth in zip(mesh.polygons, self.uvs, self.smoothing):
            face.use_smooth = smooth
            for idx, tex in zip(face.loop_indices, coords):
                uv.data[idx].uv = tex
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.collection.objects.link(obj)
        if arm:
            for module, indices in self.modules.items():
                obj.vertex_groups.new(name="Kit."+module).add(indices, 1.0, "REPLACE")
            obj.parent = arm
            skin = obj.modifiers.new("Field company skin", "ARMATURE")
            skin.object = arm
            for i, influence in enumerate(self.weights):
                for bone, weight in (influence if isinstance(influence, tuple) else [(influence, 1)]):
                    group = obj.vertex_groups.get(bone) or obj.vertex_groups.new(name=bone)
                    group.add([i], weight, "REPLACE")
        return obj


def skeleton(role):
    bones = {
        "Pelvis": ((0,0,.86),(0,0,1.08),None),
        "Spine": ((0,0,1.08),(0,0,1.46),"Pelvis"),
        "Head": ((0,0,1.46),(0,0,1.78),"Spine"),
    }
    for sign, suffix in ((-1, "R"), (1, "L")):
        x = sign
        for name, start, end, parent in (
            ("Thigh",(.105*x,0,.89),(.119*x,-.012,.49),"Pelvis"),
            ("Shin",(.119*x,-.012,.49),(.126*x,0,.12),"Thigh"),
            ("Foot",(.126*x,0,.12),(.126*x,-.16,.06),"Shin"),
            ("Arm",(.202*x,0,1.41),(.295*x,-.014,1.15),"Spine"),
            ("Forearm",(.295*x,-.014,1.15),(.31*x,-.145,.99),"Arm"),
            ("Hand",(.31*x,-.145,.99),(.31*x,-.166,.91),"Forearm"),
        ):
            p = parent if parent in ("Spine", "Pelvis") else parent+"_"+suffix
            bones[name+"_"+suffix] = (start, end, p)
    if role=="archer":
        bones["Nock"] = ((.313,-.054,.949),(.313,-.054,1.00),"Hand_L")
        bones["Arrow"] = ((.313,-.054,.949),(.313,-.154,.949),"Nock")
    skeleton_data = bpy.data.armatures.new("CompanySkeleton")
    arm = bpy.data.objects.new("CompanyRig", skeleton_data)
    bpy.context.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    for name, (a,b,parent) in bones.items():
        bone = skeleton_data.edit_bones.new(name)
        bone.head, bone.tail = a,b
        if parent:
            bone.parent = skeleton_data.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm


def body(g, role):
    tunic = "pine" if role in ("spear", "archer") else "oxblood"
    g.tube([(0,0,1.00,.152,.105),(0,.005,1.13,.153,.11),
            (0,0,1.32,.213,.134),(0,0,1.42,.199,.107),(0,0,1.455,.092,.078)],
           tunic, "Spine", 22, .022)
    g.tube([(0,0,.735,.239,.17),(0,0,.81,.23,.165),(0,0,1.04,.146,.109)],
           tunic, "Pelvis", 28, .038)
    g.tube([(0,0,1.004,.155,.116),(0,0,1.065,.154,.113)],"hide","Pelvis",20)
    g.panel([(-.028,-.116,1.012),(.028,-.116,1.012),(.028,-.116,1.05),(-.028,-.116,1.05)],"trim","Pelvis")
    for side, suffix in ((-1,"R"),(1,"L")):
        g.module = "Body"
        x = side * .12
        thigh, shin, foot = [name+"_"+suffix for name in ("Thigh","Shin","Foot")]
        knee = ((thigh,.44),(shin,.56))
        g.tube([(x,-.012,.435,.062,.064,shin),(x,-.014,.50,.068,.074,knee),
                (x,0,.63,.08,.087),(x*.91,0,.85,.092,.101)],"skin",thigh,14)
        g.tube([(x,0,.105,.042,.045),(x,.01,.22,.046,.051),
                (x,.011,.358,.066,.074),(x,-.01,.465,.063,.065)],"skin",shin,14)
        g.module = "Footwear"
        boot_color = "hide" if role == "archer" else "bronze"
        g.tube([(x,.003,.108,.052,.057),(x,.006,.247,.061,.072),
                (x,.005,.39,.073,.074),(x,-.002,.433,.065,.064)],boot_color,shin,13)
        g.tube([(x,-.052,.011,.067,.125),(x,-.063,.041,.071,.123),
                (x,-.054,.075,.068,.114),(x,-.003,.132,.049,.06)],"hide",foot,16)
        if g.detail == 0:
            for z in (.15,.347,.4):
                g.tube([(x,.005,z,.071 if z>.3 else .056,.076 if z>.3 else .063),
                        (x,.005,z+.014,.071 if z>.3 else .056,.076 if z>.3 else .063)],"hide",shin)
        g.module = "Body"
        arm, fore, hand = [name+"_"+suffix for name in ("Arm","Forearm","Hand")]
        sx = side
        g.tube([(.295*sx,-.014,1.13,.055,.056,((arm,.45),(fore,.55))),
                (.275*sx,0,1.23,.068,.069),(.231*sx,0,1.34,.083,.082),
                (.198*sx,0,1.414,.074,.079)],"skin",arm,14)
        g.tube([(.31*sx,-.144,.982,.038,.042),(.311*sx,-.104,1.039,.049,.059),
                (.302*sx,-.047,1.105,.059,.06),(.295*sx,-.014,1.15,.055,.058)],"skin",fore,14)
        g.tube([(.31*sx,-.133,.99,.045,.049),(.31*sx,-.077,1.066,.057,.059)],"hide",fore,12)
        g.tube([(.31*sx,-.157,.917,.038,.047),(.31*sx,-.161,.946,.050,.061),
                (.31*sx,-.145,.991,.042,.045)],"skin",hand,12)
        g.tube([(.255*sx,0,1.268,.088,.087),(.227*sx,0,1.372,.098,.101),
                (.197*sx,0,1.419,.085,.083)], tunic,arm,16)
    g.module = "Face"
    g.tube([(0,0,1.421,.067,.065),(0,0,1.54,.066,.064)],"skin","Head",14)
    # A tapered jaw and frontal features sit below the helmet or wool cap.
    g.tube([(0,-.022,1.488,.055,.063),(0,-.018,1.519,.079,.081),
            (0,-.008,1.57,.104,.096),(0,0,1.626,.111,.10),
            (0,.008,1.684,.101,.086),(0,.01,1.732,.084,.075)],"skin","Head",20)
    if g.detail < 2:
        g.tube([(0,-.104,1.563,.021,.017),(0,-.108,1.58,.027,.022),
                (0,-.096,1.627,.011,.013)],"cheek","Head",9)
        for s in (-1,1):
            g.rod([(.019*s,-.106,1.623),(.046*s,-.104,1.629),(.072*s,-.089,1.626)],
                  [.005,.008,.004],"brow","Head")
            g.rod([(.027*s,-.105,1.612),(.047*s,-.104,1.612),(.064*s,-.095,1.614)],
                  [.003,.005,.002],"shadow","Head")
        g.rod([(-.025,-.099,1.547),(0,-.104,1.544),(.024,-.099,1.547)],
              [.002,.0035,.002],"brow","Head")


def uniform(g, role):
    g.module = "Armor"
    if role == "archer":
        g.module = "Cap"
        g.tube([(0,0,1.635,.118,.103),(0,.005,1.68,.124,.115),
                (0,.011,1.735,.101,.091),(-.027,.045,1.773,.036,.038)],"pine","Head",20,.045)
        g.tube([(0,0,1.633,.119,.104),(0,0,1.66,.12,.106)],"hide","Head",16)
        g.module = "Quiver"
        g.panel([(-.174,-.128,1.391),(-.123,-.143,1.402),(.153,-.127,1.088),
                 (.11,-.137,1.071)],"hide","Spine")
        g.rod([(-.10,.13,1.07),(.105,.15,1.49)], [.068,.079],"hide","Spine",12)
        if g.detail < 2:
            for dx in (-.05,0,.045):
                g.rod([(.07+dx,.15,1.44),(.14+dx,.16,1.595)], [.009,.008],"wood","Spine")
                g.rod([(.128+dx,.159,1.56),(.15+dx,.161,1.604)], [.017,.008],"linen","Spine")
        return
    # Cuirass silhouette, overlapping articulated bands and shaped shoulder plates.
    g.tube([(0,0,1.067,.165,.122),(0,0,1.175,.18,.125),
            (0,0,1.318,.224,.144),(0,0,1.393,.213,.12),
            (0,0,1.427,.13,.091)],"iron" if role != "officer" else "bronze","Spine",20)
    if g.detail < 2:
        for z, width, depth in ((1.084,.166,.123),(1.135,.176,.128),(1.186,.19,.135),(1.237,.206,.14)):
            g.tube([(0,0,z,width+.006,depth+.005),(0,0,z+.034,width+.009,depth+.005),
                    (0,0,z+.048,width+.004,depth)], "steel" if role == "heavy" else "bronze", "Spine",20)
        for s, suffix in ((-1,"R"),(1,"L")):
            g.tube([(.238*s,0,1.317,.099,.107),(.227*s,0,1.366,.109,.119),
                    (.204*s,0,1.422,.105,.106),(.19*s,.003,1.443,.064,.073)],
                   "iron","Arm_"+suffix,18)
            g.panel([(.104*s,-.104,1.40),(.137*s,-.092,1.396),
                     (.088*s,-.138,1.306),(.063*s,-.14,1.314)],"hide","Spine")
        for i in range(7):
            angle = -1.31 + i*.437
            x,y=math.sin(angle)*.175,-math.cos(angle)*.134
            bx,by=math.sin(angle)*.226,-math.cos(angle)*.170
            w=.018
            g.panel([(x-w,y,1.017),(x+w,y,1.017),(bx+w,by,.843),
                     (bx,by-.002,.822),(bx-w,by,.843)],"hide","Pelvis")
    g.module = "Helmet"
    g.tube([(0,.008,1.637,.119,.114),(0,.011,1.665,.13,.123),
            (0,.017,1.731,.108,.102),(0,.017,1.773,.06,.059),(0,.016,1.781,.02,.02)],
           "iron" if role != "officer" else "bronze","Head",22)
    g.tube([(0,-.005,1.642,.133,.132),(0,-.004,1.659,.133,.131)],"trim","Head",22)
    for s in (-1,1):
        g.panel([(.079*s,-.082,1.641),(.12*s,-.024,1.64),(.111*s,-.014,1.543),
                 (.091*s,-.072,1.524)],"bronze","Head",.019)
    if role in ("heavy","officer") and g.detail==0:
        g.module = "Face"
        # Fine moustache across the top lip, with a short chin patch.
        for s in (-1,1):
            g.rod([(.002*s,-.104,1.553),(.021*s,-.106,1.554),(.034*s,-.096,1.55)],
                  [.003,.006,.002],"brow","Head",6)
        g.rod([(0,-.095,1.519),(0,-.096,1.533)],[.007,.011],"brow","Head",8)
    if role == "officer":
        g.module = "Command"
        # A transverse crest, split mantle and brooch distinguish rank at distance.
        g.panel([(-.144,.022,1.762),(-.172,.016,1.84),(-.126,.015,1.895),
                 (0,.014,1.92),(.126,.015,1.895),(.172,.016,1.84),(.144,.022,1.762),
                 (.078,.022,1.791),(-.078,.022,1.791)],"plume","Head",.05)
        if g.detail==0:
            for i in range(-5,6):
                dx=i*.026
                crown=1.905-.043*abs(i/5)**1.6
                g.rod([(dx,.013,1.797),(dx*1.14,.012,crown)],
                      [.003,.004],"oxblood","Head",5)
        g.panel([(-.184,.07,1.424),(.145,.077,1.414),(.205,.20,.87),
                 (.047,.245,.784),(-.149,.212,.835),(-.239,.169,1.19)],"plume","Spine",.035)
        g.rod([(-.18,-.035,1.417),(-.131,-.111,1.383),(-.098,-.12,1.356)],
              [.046,.042,.022],"plume","Spine",12)
        g.rod([(-.129,-.134,1.379),(-.129,-.146,1.379)], [.024,.022],"trim","Spine",12)


def equipment(g, role):
    if role in ("heavy","officer","spear"):
        g.module = "Shield"
        # Curved rectangular or oval shield, with face, separate rim, striped devices and boss.
        cx,cz=.321,1.125
        w,h=(.202,.371) if role=="heavy" else (.186,.282)
        outline=[]
        for i in range(20 if g.detail<2 else 10):
            angle = TAU*i/(20 if g.detail<2 else 10)
            a,b=math.cos(angle),math.sin(angle)
            power=.48 if role=="heavy" else 1
            outline.append((math.copysign(abs(a)**power,a),math.copysign(abs(b)**power,b)))
        def front_y(nx):
            return -.269 + .064*nx*nx
        # The curved face is a fan so the metal boss sits flush at the crown.
        for scale,offset,color in ((1,.004,"trim"),(.942,-.004,"pine" if role=="spear" else "oxblood")):
            center=g.vertex((cx,-.269+offset,cz),"Hand_L")
            edge=[g.vertex((cx+w*x*scale,front_y(x*scale)+offset,cz+h*z*scale),"Hand_L") for x,z in outline]
            for i,(x,z) in enumerate(outline):
                j=(i+1)%len(outline)
                g.face([center,edge[i],edge[j]],color,[(.5,.5),(.5+.49*x,.5+.49*z),
                                                         (.5+.49*outline[j][0],.5+.49*outline[j][1])])
            if scale == 1:
                back = [g.vertex((cx+w*x,front_y(x)+.033,cz+h*z),"Hand_L") for x,z in outline]
                for i in range(len(edge)):
                    j=(i+1)%len(edge)
                    g.face([edge[i],back[i],back[j],edge[j]],"bronze",[(0,0),(1,0),(1,1),(0,1)])
                g.face(back[::-1],"hide",[(.5+.48*x,.5+.48*z) for x,z in reversed(outline)])
        if g.detail<2:
            for s in (-1,1):
                pts=[(.13,.04),(.72,.44),(.55,.15),(.78,.19),(.27,-.06)]
                # Evaluated on the facets' chord, slightly above the painted hide.
                g.panel([(cx+s*w*x,-.284+.059*x,cz+h*z) for x,z in pts],"trim","Hand_L",.006)
            g.rod([(cx,-.27,cz),(cx,-.301,cz),(cx,-.32,cz)], [.067,.051,.018],"bronze","Hand_L",16)
    g.module = "Weapon"
    if role == "spear":
        x,y=-.31,-.17
        g.rod([(x,y,.21),(x,y,2.13)], [.016,.015],"wood","Hand_R",10)
        g.tube([(x,y,2.09,.018,.017),(x,y,2.14,.042,.017),(x,y,2.295,.002,.002)],
               "steel","Hand_R",8, smooth=False)
    elif role == "archer":
        x,y=.313,-.166
        path=[(x,y+.112,.495),(x,y+.063,.559),(x,y-.026,.74),(x,y-.057,.939),
              (x,y-.018,1.16),(x,y+.063,1.346),(x,y+.112,1.402)]
        g.rod(path,[.009,.014,.021,.023,.021,.014,.009],"wood","Hand_L",9)
        nock=(x,y+.112,.949)
        g.rod([path[0],nock,path[-1]],[.003,.003,.003],"linen","Hand_L",5,
              ring_bones=["Hand_L","Nock","Hand_L"])
        g.rod([nock,(x,y-.63,.949)],[.005,.005],"wood","Arrow",6)
        g.rod([(x,y-.61,.949),(x,y-.67,.949)],[.014,.002],"steel","Arrow",6)
        g.rod([nock,(x,y+.071,.949)],[.008,.016],"linen","Arrow",5)
    else:
        x,y=-.31,-.17
        g.rod([(x,y,.854),(x,y,1.018)], [.023,.021],"hide","Hand_R",8)
        g.rod([(x-.059,y,1.011),(x+.059,y,1.011)], [.015,.015],"trim","Hand_R",8)
        g.tube([(x,y,1.02,.033,.01),(x,y,1.09,.038,.012),
                (x,y,1.41,.029,.009),(x,y,1.499,.002,.002)],"steel","Hand_R",4,smooth=False)
        g.rod([(x,y,.852),(x,y,.876)], [.032,.027],"bronze","Hand_R",10)


# Pose angles are in model axes so mirrored limbs bend in the same anatomical direction.
LENGTHS={"idle":2,"march":1,"run":.72,"attack":.8,"shoot":1.28,"block":1.2,
         "wall":1.2,"testudo":1.3,"hit":.48,"retreat":.88,"death":1.20}
LOOPS={"idle","march","run","block","wall","testudo","retreat"}


# One full cycle advances this many metres. The presentation adapter uses the
# same distances for imported GLB playback, including a forward-facing retreat.
STRIDES = {"march": (1.30, .58, .106), "run": (1.75, .40, .19), "retreat": (1.48, .51, .134)}


def locomotion(clip, t, role):
    stride, stance, clearance = STRIDES[clip]
    phase = math.tau * t
    lift = -.088 - .035 * math.cos(phase * 2) if clip != "run" else -.068 - .062 * math.cos(phase * 2)
    angles = {}
    for offset, suffix in ((0.0, "R"), (.5, "L")):
        cycle = (t + offset) % 1
        foot_height = 0.0
        foot_pitch = 0.0
        if cycle <= stance:
            # Forward is -Y. A planted ankle travels backwards in model space
            # exactly as fast as the figure advances in world space.
            foot_y = stride * (cycle - stance / 2)
        else:
            u = (cycle - stance) / (1 - stance)
            smooth = u * u * (3 - 2 * u)
            foot_y = stride * (stance / 2 + (1 - stance) * u - smooth)
            foot_height = clearance * math.sin(math.pi * u) ** 2
            foot_pitch = 14 * math.sin(math.tau * u) * math.sin(math.pi * u)
        # Analytic two-link sagittal IK. The bend stays forward of the hip;
        # the foot compensates both joint angles to keep the sole flat in stance.
        vertical = .89 + lift - (.12 + foot_height)
        a, b = math.hypot(.4, .012), math.hypot(.37, .012)
        reach = min(math.hypot(foot_y, vertical), a + b - .00001)
        hip = math.atan2(foot_y, vertical) - math.acos((a*a + reach*reach - b*b)/(2*a*reach))
        bend = math.pi - math.acos((a*a + b*b - reach*reach)/(2*a*b))
        thigh = math.degrees(hip - math.atan2(-.012, .4))
        shin = math.degrees(bend - (math.atan2(.012,.37) - math.atan2(-.012,.4)))
        angles["Thigh_" + suffix] = (thigh, 0, 0)
        angles["Shin_" + suffix] = (shin, 0, 0)
        angles["Foot_" + suffix] = (foot_pitch - thigh - shin, 0, 0)
        counter = math.cos(math.tau * cycle)
        # Hands carry equipment. The shield stays near the torso, and the
        # spear hand counter-rotates to prevent its tip sweeping the rank.
        amplitude = 9 if suffix == "L" else (11 if role == "spear" else 18)
        upper = -6 + amplitude * counter
        elbow = -13 - (5 if clip != "run" else 14) * (1 - counter)
        angles["Arm_" + suffix] = (upper, 0, 0)
        angles["Forearm_" + suffix] = (elbow, 0, 0)
        angles["Hand_" + suffix] = (-.82 * (upper + elbow + 12), 0, 0)
    sway = math.sin(phase)
    angles["Spine"] = (5 if clip == "run" else 2, 2.2*sway, 4.2*math.cos(phase))
    angles["Head"] = (-2 if clip == "run" else -1, -1.6*sway, -3.4*math.cos(phase))
    return angles, lift


def pose(clip,t,role):
    angles={}
    lift=0
    wave=math.sin(TAU*t)
    if clip=="idle":
        angles={"Spine":(2*wave,0,0),"Head":(-wave,0,3*wave),"Forearm_R":(-3+2*wave,0,0)}
    elif clip in STRIDES:
        return locomotion(clip, t, role)
    elif clip=="attack":
        wind=max(0,1-abs(t-.28)/.28)
        swing=max(0,1-abs(t-.59)/.28)
        angles={"Spine":(8*swing,0,24*wind-31*swing),"Arm_R":(-65*wind-42*swing,-23*wind,14*swing),
                "Forearm_R":(-41*wind-18*swing,0,0),"Hand_R":(15*wind-63*swing,0,0),
                "Arm_L":(-21*swing,0,0),"Thigh_L":(-12*swing,0,0)}
        if role=="spear":
            angles["Hand_R"]=(-48*swing+25*wind,0,0)
            angles["Arm_R"]=(-57*swing+12*wind,0,0)
    elif clip=="shoot":
        draw=min(1,t/.46) if t<.72 else max(0,1-(t-.72)/.28)
        release=max(0,1-abs(t-.78)/.1)
        angles={"Spine":(0,0,26*draw),"Arm_L":(-84*draw,8*draw,0),
                "Hand_L":(84*draw,0,0),"Arm_R":(-64*draw,33*draw,0),
                "Forearm_R":(-62*draw,39*draw,-20*draw),"Head":(0,0,-23*draw),
                "Hand_R":(0,28*release,0)}
    elif clip in ("block","wall","testudo"):
        angle={"block":-26,"wall":-39,"testudo":-122}[clip]
        angles={"Spine":(9+wave,0,0),"Thigh_L":(-17,0,0),"Shin_L":(27,0,0),
                "Arm_L":(angle,0,-6),"Forearm_L":(-19 if clip!="testudo" else -32,0,0),
                "Hand_L":(-angle-17 if clip!="testudo" else 64,0,0),
                "Arm_R":(-18,0,0),"Head":(8,0,0)}
        lift=-.036
    elif clip=="hit":
        recoil=math.sin(math.pi*t)
        angles={"Spine":(-23*recoil,12*recoil,0),"Head":(-15*recoil,0,0),"Arm_R":(-22*recoil,0,0)}
    elif clip=="death":
        fall=t*t*(3-2*t)
        angles={"Pelvis":(-86*fall,7*fall,0),"Head":(14*fall,0,0),
                "Thigh_R":(-17*fall,0,0),"Shin_R":(38*fall,0,0),
                "Arm_L":(0,-28*fall,0),"Arm_R":(0,21*fall,0)}
        lift=-.715*fall
    return angles,lift


def archery_pose(arm, t):
    draw = min(1,t/.42) if t<.74 else max(0,1-(t-.74)/.26)
    # Draw the equipment along a single line between the two hands.
    aim = Vector((.986,-.165,0)).normalized()
    left = Vector((.606,-.194,1.512))
    right = left - aim*.651
    targets = {"L":(left,Vector((.12,-.12,-.4))),
               "R":(right,Vector((-.48,-.45,-.13)))}
    for suffix,(wrist,pole) in targets.items():
        upper = arm.pose.bones["Arm_"+suffix]
        lower = arm.pose.bones["Forearm_"+suffix]
        hand = arm.pose.bones["Hand_"+suffix]
        shoulder = upper.bone.head_local
        reach = wrist - shoulder
        axis = reach.normalized()
        length_a, length_b = upper.bone.length, lower.bone.length
        distance = min(reach.length,length_a+length_b-.0001)
        middle = (length_a**2-length_b**2+distance**2)/(2*distance)
        elbow = shoulder + middle*axis + (pole-axis*pole.dot(axis)).normalized()*math.sqrt(max(0,length_a**2-middle**2))
        pose_upper=(upper.bone.tail_local-shoulder).rotation_difference(elbow-shoulder)
        pose_lower=(lower.bone.tail_local-lower.bone.head_local).rotation_difference(wrist-elbow)
        pose_hand = Quaternion((0,0,1),math.atan2(aim.x,-aim.y))
        for bone, rotation in ((upper,pose_upper),(lower,pose_upper.inverted() @ pose_lower),
                               (hand,pose_lower.inverted() @ pose_hand)):
            local=bone.bone.matrix_local.to_quaternion()
            bone.rotation_quaternion=Quaternion().slerp(local.inverted() @ rotation @ local,draw)
    nock = arm.pose.bones["Nock"]
    tension = min(1,t/.60) if t<.68 else max(0,1-(t-.68)/.07)
    nock.location = nock.bone.matrix_local.to_quaternion().inverted() @ Vector((0,.56*tension,0))
    arrow = arm.pose.bones["Arrow"]
    arrow.scale=(1,1,1) if t<.70 or t>.96 else (.001,.001,.001)


def animate(arm, role):
    scene=bpy.context.scene
    scene.render.fps=25
    arm.animation_data_create()
    for clip,seconds in LENGTHS.items():
        action=bpy.data.actions.new(clip)
        arm.animation_data.action=action
        count=round(seconds*25)
        # Every clip includes the complete rest pose, allowing arbitrary transitions.
        samples = range(count + 1) if clip in STRIDES else sorted({round(i*count/12) for i in range(13)})
        for frame in samples:
            angles,lift=pose(clip,frame/count,role)
            for bone in arm.pose.bones:
                ax,ay,az=angles.get(bone.name,(0,0,0))
                world=(Quaternion((0,0,1),math.radians(az)) @ Quaternion((0,1,0),math.radians(ay))
                       @ Quaternion((1,0,0),math.radians(ax)))
                rest=bone.bone.matrix_local.to_quaternion()
                bone.rotation_quaternion=rest.inverted() @ world @ rest
                if bone.name=="Pelvis":
                    bone.location=rest.inverted() @ Vector((0,0,lift))
                    bone.keyframe_insert("location",frame=frame)
            if role=="archer":
                nock,arrow=arm.pose.bones["Nock"],arm.pose.bones["Arrow"]
                nock.location=(0,0,0)
                arrow.scale=(1,1,1)
                if clip=="shoot":
                    arm.pose.bones["Spine"].rotation_quaternion=Quaternion()
                    draw=min(1,frame/count/.42) if frame/count<.74 else max(0,1-(frame/count-.74)/.26)
                    head=arm.pose.bones["Head"]
                    rest=head.bone.matrix_local.to_quaternion()
                    head.rotation_quaternion=rest.inverted() @ Quaternion((0,0,1),.70*draw) @ rest
                    archery_pose(arm,frame/count)
                nock.keyframe_insert("location",frame=frame)
                arrow.keyframe_insert("scale",frame=frame)
            if clip in ("block","wall","testudo"):
                # Place the lower sole on the ground in each sample. Bone matrices
                # here are computed from the pose, independent of evaluation time.
                matrices={}
                for bone in arm.pose.bones:
                    base=bone.bone.matrix_local
                    if bone.parent:
                        parent=bone.parent
                        base=matrices[parent.name] @ parent.bone.matrix_local.inverted() @ base
                    matrices[bone.name]=base @ bone.matrix_basis
                soles=[]
                for sign,suffix in ((-1,"R"),(1,"L")):
                    foot=arm.pose.bones["Foot_"+suffix]
                    deform=matrices[foot.name] @ foot.bone.matrix_local.inverted()
                    for sample_y in (-.175,.065):
                        soles.append((deform @ Vector((sign*.126,sample_y,.011))).z)
                hip=arm.pose.bones["Pelvis"]
                hip.location += hip.bone.matrix_local.to_quaternion().inverted() @ Vector((0,0,.011-min(soles)))
                hip.keyframe_insert("location",frame=frame)
            for bone in arm.pose.bones:
                bone.keyframe_insert("rotation_quaternion",frame=frame)
        for curve in action.fcurves:
            for key in curve.keyframe_points:
                key.interpolation="LINEAR"
        track=arm.animation_data.nla_tracks.new()
        track.name=clip
        track.strips.new(clip,0,action)
        track.mute=True
        arm.animation_data.action=None
    for bone in arm.pose.bones:
        bone.rotation_quaternion=(1,0,0,0)
        bone.location=(0,0,0)
    scene.frame_set(0)


def distant(g,role):
    """Silhouette mesh for instancing at tactical distance. No skin or armature."""
    cloth = "pine" if role in ("spear","archer") else "oxblood"
    cx=0
    g.tube([(cx,0,.71,.20,.128),(cx,0,1.13,.153,.109),(cx,0,1.43,.224,.126)],
           cloth if role=="archer" else "iron","Spine",10,smooth=False)
    g.tube([(0,0,1.44,.083,.09),(0,0,1.635,.107,.098)],"skin","Head",10)
    g.tube([(0,0,1.635,.135,.121),(0,.01,1.713,.113,.1),(0,.015,1.78,.032,.033)],
           cloth if role=="archer" else "bronze","Head",14)
    for s in (-1,1):
        # The instanced sole uses the same heel/toe extent and ground height
        # as the rigged LOD. An ankle cylinder caused a visible foot jump.
        g.tube([(.126*s,-.055,.011,.063,.12),
                (.126*s,-.055,.055,.063,.12),
                (.126*s,0,.12,.05,.055)],"hide","Foot_"+("R" if s<0 else "L"),12,smooth=False)
        g.rod([(.126*s,0,.12),(.126*s,0,.40),(.113*s,0,.77)],
              [.05,.07,.073],"hide","Pelvis",6)
        g.rod([(.195*s,0,1.386),(.285*s,-.008,1.17),(.309*s,-.15,.947)],
              [.09,.067,.046],"skin","Spine",6)
    if role=="archer":
        x,y=.314,-.155
        g.rod([(x,y+.105,.49),(x,y-.051,.94),(x,y+.105,1.408)],
              [.011,.024,.011],"wood","Hand_L",5)
        g.rod([(-.08,.13,1.11),(.14,.15,1.53)],[.061,.082],"hide","Spine",5)
    else:
        cx,cy,cz=.315,-.252,1.102
        w,h=(.2,.374) if role=="heavy" else (.18,.29)
        corners=([(-.82,-1),(.82,-1),(1,-.8),(1,.8),(.82,1),(-.82,1),(-1,.8),(-1,-.8)]
                 if role=="heavy" else [(math.cos(i*TAU/8),math.sin(i*TAU/8)) for i in range(8)])
        g.panel([(cx+w*x,cy,cz+h*z) for x,z in corners],cloth,"Hand_L",.031)
        g.panel([(cx,cy-.006,cz-.14),(cx+.037,cy-.006,cz),(cx,cy-.006,cz+.14),
                 (cx-.037,cy-.006,cz)],"trim","Hand_L",.005)
        if role=="spear":
            g.rod([(-.31,-.16,.21),(-.31,-.16,2.13),(-.31,-.16,2.29)],
                  [.014,.022,.002],"wood","Hand_R",5)
        else:
            g.panel([(-.341,-.16,1.01),(-.279,-.16,1.01),(-.285,-.16,1.414),
                     (-.31,-.16,1.50),(-.335,-.16,1.414)],"steel","Hand_R",.015)
        if role=="officer":
            g.panel([(-.155,0,1.769),(-.166,0,1.855),(0,0,1.924),(.166,0,1.855),
                     (.155,0,1.769)],"plume","Head",.045)
            g.panel([(-.208,.09,1.413),(.132,.09,1.414),(.203,.19,.856),(-.17,.19,.813)],
                    "plume","Spine",.023)


def build(role,detail):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene=bpy.context.scene
    scene.unit_settings.system="METRIC"
    g=Geometry(detail)
    if detail==2:
        distant(g,role)
    else:
        body(g,role)
        uniform(g,role)
        equipment(g,role)
    arm=skeleton(role) if detail<2 else None
    obj=g.object(role.title()+"_field_kit",atlas_material(),arm)
    if arm:
        animate(arm,role)
    if detail==0:
        bpy.context.preferences.filepaths.save_version=0
        bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/(role+".blend")), compress=True)
    suffix=("near","mid","far")[detail]
    filename=OUTPUT/f"{role}_{suffix}.glb"
    bpy.ops.export_scene.gltf(filepath=str(filename),export_format="GLB",
                              export_animations=bool(arm),export_animation_mode="NLA_TRACKS",
                              export_force_sampling=True,export_frame_step=1,
                              export_optimize_animation_size=True,export_def_bones=False)
    obj.data.calc_loop_triangles()
    return {"role":role,"lod":suffix,"triangles":len(obj.data.loop_triangles),
            "bones":len(arm.data.bones) if arm else 0,"bytes":filename.stat().st_size}


if __name__=="__main__":
    OUTPUT.mkdir(parents=True,exist_ok=True)
    stats=[build(role,detail) for role in ROLES for detail in range(3)]
    (SOURCE/"metrics.json").write_text(json.dumps(stats,indent=2)+"\n")
