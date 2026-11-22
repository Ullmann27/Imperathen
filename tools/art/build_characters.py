"""Original static character art studies for IMPERATHEN.

Blender 4.3+: blender --background --python tools/art/build_characters.py --
    --output-dir art/visual_benchmark/assets/characters

Coordinates: metres, Z up, face toward -Y, sole at Z=0. These assets are
procedural modelling studies, with authored face and garment geometry. They
are not motion-capture characters or production-ready skinned game actors.
The civilian's apparent youth is an art proposal, not a canonical start age.
No third-party model, texture or paid provider is used.
"""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
import sys

import bpy
import bmesh
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import export_asset, material, mesh, reset_scene

TAU = math.tau


def _uv_cylinder(obj, rings, segments):
    uv = obj.data.uv_layers.active or obj.data.uv_layers.new(name="UVMap")
    for polygon in obj.data.polygons:
        coords = []
        for index in polygon.vertices:
            coords.append((index % segments / segments, index // segments / max(1, rings - 1)))
        if coords and max(c[0] for c in coords) - min(c[0] for c in coords) > 0.5:
            coords = [(u + 1 if u < 0.5 else u, v) for u, v in coords]
        for loop, co in zip(polygon.loop_indices, coords):
            uv.data[loop].uv = co


def _loft(name, rings, mat, segments=32, folds=0, cap=True):
    """Rings are (cx, cy, z, half_width, half_depth); shared smooth topology."""
    if rings[-1][2] < rings[0][2]:
        rings=list(reversed(rings))
    vertices = []
    for ring, (cx, cy, z, rx, ry) in enumerate(rings):
        for j in range(segments):
            a = TAU * j / segments
            wrinkle = folds * (0.62 * math.cos(9 * a + ring * 0.19) + 0.27 * math.sin(15 * a - ring * 0.31))
            vertices.append((cx + (rx + wrinkle) * math.cos(a), cy + (ry + wrinkle * 0.65) * math.sin(a), z + folds * .22 * math.sin(7 * a)))
    faces = []
    for i in range(len(rings) - 1):
        for j in range(segments):
            k = (j + 1) % segments
            faces.append((i * segments + j, i * segments + k, (i + 1) * segments + k, (i + 1) * segments + j))
    if cap:
        faces.append(tuple(reversed(range(segments))))
        faces.append(tuple((len(rings) - 1) * segments + j for j in range(segments)))
    obj = mesh(name, vertices, faces, mat, smooth=True)
    _uv_cylinder(obj, len(rings), segments)
    return obj


def _tube(name, points, radii, mat, sides=12, depth_ratio=1.0):
    """Organic limb or a thin detail along a non-collinear path."""
    vertices = []
    for i, point in enumerate(points):
        p = Vector(point)
        tangent = Vector(points[min(i + 1, len(points) - 1)]) - Vector(points[max(0, i - 1)])
        tangent.normalize()
        side = tangent.cross(Vector((0, 1, 0)))
        if side.length < .001:
            side = tangent.cross(Vector((1, 0, 0)))
        side.normalize()
        normal = tangent.cross(side).normalized()
        for j in range(sides):
            angle = TAU * j / sides
            vertices.append(p + radii[i] * (math.cos(angle) * side + depth_ratio * math.sin(angle) * normal))
    faces = []
    for i in range(len(points) - 1):
        for j in range(sides):
            k = (j + 1) % sides
            faces.append((i * sides + j, i * sides + k, (i + 1) * sides + k, (i + 1) * sides + j))
    faces.extend((tuple(reversed(range(sides))), tuple((len(points) - 1) * sides + j for j in range(sides))))
    obj = mesh(name, vertices, faces, mat, smooth=True)
    _uv_cylinder(obj, len(points), sides)
    return obj


def _ellipsoid(name, center, scale, mat, rings=14, segments=24):
    # Lofted ellipsoids are used only for small facial parts, never body joints.
    entries = []
    for i in range(rings + 1):
        p = -math.pi / 2 + math.pi * i / rings
        radius = max(.015, math.cos(p))
        entries.append((center[0], center[1], center[2] + scale[2] * math.sin(p), scale[0] * radius, scale[1] * radius))
    return _loft(name, entries, mat, segments=segments)


def _ring_detail(name, center, rx, ry, radius, mat, segments=48):
    points = []
    for j in range(segments + 1):
        a = TAU * j / segments
        points.append((center[0] + rx * math.cos(a), center[1] + ry * math.sin(a), center[2]))
    return _tube(name, points, [radius] * len(points), mat, sides=8)


def _face(prefix, zbase, scale, mats, adult=False):
    """Authored jaw, brow, sockets, eyelids, nose, lips, ears and hairline."""
    s = scale
    def p(x, y, z):
        return (x * s, y * s, zbase + z * s)
    head = [
        (0, .010, .000, .033, .035),
        (0, -.001, .020, .050, .046),
        (0, -.003, .040, .066, .059),
        (0, .002, .065, .076, .067),
        (0, .004, .092, .081, .072),
        (0, .007, .122, .083, .073),
        (0, .008, .149, .081, .074),
        (0, .010, .174, .076, .070),
        (0, .013, .195, .061, .059),
        (0, .014, .211, .037, .040),
        (0, .014, .216, .008, .009),
    ]
    if adult:
        head=[(x,y,z,rx*(1.20 if i<2 else 1.10 if i==2 else 1.0),ry) for i,(x,y,z,rx,ry) in enumerate(head)]
    head_obj=_loft(prefix + "_Head", [(x*s,y*s,zbase+z*s,rx*s,ry*s) for x,y,z,rx,ry in head], mats["skin"], segments=40)
    # Human cheeks and eye sockets occupy a flatter front plane than the
    # back of the cranium; leaving a pure ellipse makes attached eyes bulge.
    for ri, (_,cy,z,rx,ry) in enumerate(head):
        if not .040<=z<=.174:
            continue
        for j in range(40):
            angle=TAU*j/40
            frontal=max(0,-math.sin(angle))
            blend=max(0,min(1,(frontal-.42)/.38))
            if blend:
                target=(cy-ry*(1-.07*math.cos(angle)**2))*s
                vertex=head_obj.data.vertices[ri*40+j]
                vertex.co.y=vertex.co.y*(1-blend)+target*blend
    for side in (-1, 1):
        x = side * .036
        # The eye opening is a small almond surface; iris is held inside it.
        verts = [p(x, -.068, .119)]
        for i in range(32):
            a = TAU * i / 32
            verts.append(p(x + .017 * math.cos(a), -.067 - .002*math.sin(a)**2, .119 + .0053*math.sin(a)))
        mesh(prefix + f"_EyeWhite_{side}", verts, [(0,i+1,(i+1)%32+1) for i in range(32)], mats["eye"], smooth=True)
        _ellipsoid(prefix + f"_Iris_{side}", p(x, -.072, .119), (.005*s,.0013*s,.005*s), mats["iris"], rings=8, segments=20)
        _ellipsoid(prefix + f"_Pupil_{side}", p(x, -.0733, .119), (.0024*s,.0006*s,.0033*s), mats["dark"], rings=8, segments=16)
        for upper in (True, False):
            points=[]
            for j in range(17):
                a=(math.pi*j/16) if upper else (math.pi+math.pi*j/16)
                points.append(p(x + .0178*math.cos(a), -.069-.001*math.sin(a)**2, .119+.0065*math.sin(a)))
            _tube(prefix+f"_Lid_{side}_{upper}",points,[.0013*s]*len(points),mats["skin"],sides=8)
        brow=[p(x-.024,-.065,.138),p(x-.012,-.070,.144),p(x+.004,-.071,.145),p(x+.022,-.064,.139)]
        _tube(prefix+f"_BrowRidge_{side}",brow,[.002*s,.003*s,.0025*s,.001*s],mats["skin"],sides=10)
        _tube(prefix+f"_Eyebrow_{side}",[(v[0],v[1]-.004*s,v[2]+.001*s) for v in brow],[.0012*s,.002*s,.0016*s,.0006*s],mats["hair"],sides=8)
        # Ear has an outer helix and a recessed inner concha.
        _ellipsoid(prefix+f"_Ear_{side}",p(side*.084,.001,.106),(.014*s,.022*s,.031*s),mats["skin"],rings=12,segments=16)
        _ellipsoid(prefix+f"_EarInner_{side}",p(side*.094,-.013,.109),(.005*s,.005*s,.018*s),mats["lip"],rings=10,segments=12)
        helix=[p(side*(.087+.011*math.sin(math.pi*j/12)), -.009-.006*math.sin(math.pi*j/12), .083+.047*j/12) for j in range(13)]
        _tube(prefix+f"_EarHelix_{side}",helix,[.0028*s]*13,mats["skin"],sides=8)
    # Nose bridge narrows at its root; separate tip, alae and nostril shadows.
    nose_verts=[p(-.008,-.065,.140),p(.008,-.065,.140),p(-.010,-.082,.107),p(.010,-.082,.107),p(-.012,-.088,.088),p(.012,-.088,.088),p(0,-.095,.093),p(-.011,-.066,.082),p(.011,-.066,.082)]
    nose_faces=[(0,1,3,2),(2,3,6),(2,6,4),(3,5,6),(4,6,5,8,7),(0,2,4,7),(1,8,5,3),(0,7,8,1)]
    mesh(prefix+"_Nose",nose_verts,nose_faces,mats["skin"],smooth=True)
    for side in (-1,1):
        _ellipsoid(prefix+f"_NoseWing_{side}",p(side*.014,-.080,.088),(.007*s,.008*s,.006*s),mats["skin"],rings=8,segments=12)
        _ellipsoid(prefix+f"_Nostril_{side}",p(side*.012,-.085,.084),(.004*s,.0015*s,.002*s),mats["shadow"],rings=6,segments=12)
    upper=[p(-.026,-.061,.058),p(-.013,-.069,.062),p(-.005,-.072,.064),p(0,-.073,.062),p(.005,-.072,.064),p(.013,-.069,.062),p(.026,-.061,.058)]
    lower=[p(-.025,-.061,.057),p(-.012,-.070,.054),p(0,-.072,.053),p(.012,-.070,.054),p(.025,-.061,.057)]
    _tube(prefix+"_UpperLip",upper,[.0012*s,.002*s,.0025*s,.002*s,.0025*s,.002*s,.0012*s],mats["lip"],sides=8)
    _tube(prefix+"_LowerLip",lower,[.001*s,.0025*s,.003*s,.0025*s,.001*s],mats["lip"],sides=8)
    _tube(prefix+"_MouthLine",[p(-.022,-.064,.058),p(0,-.074,.058),p(.022,-.064,.058)],[.0007*s]*3,mats["shadow"],sides=6)
    # Scalp is one contiguous cap with a deliberately uneven, swept hairline.
    verts=[]
    seg=48
    def scalp_profile(z):
        for lower,upper in zip(head,head[1:]):
            if lower[2]<=z<=upper[2]:
                t=(z-lower[2])/(upper[2]-lower[2])
                return tuple(lower[k]*(1-t)+upper[k]*t for k in (1,3,4))
        return (.014,.003,.003)
    for ring in range(13):
        t=ring/12
        for j in range(seg):
            a=TAU*j/seg
            front=max(0,-math.sin(a))
            start=.087+.068*front
            z=start+(.221-start)*t
            cy,rx,ry=scalp_profile(min(z,.215))
            striation=(.0012 if adult else .0020)*(math.sin(13*a+3*t)+.4*math.sin(21*a-5*t))
            rx=rx+.005+striation
            ry=ry+.006+striation
            if ring==12:
                rx=ry=.001
            verts.append(p(rx*math.cos(a),cy+ry*math.sin(a),z+.0010*math.sin(7*a)))
    faces=[(i*seg+j,i*seg+(j+1)%seg,(i+1)*seg+(j+1)%seg,(i+1)*seg+j) for i in range(12) for j in range(seg)]
    faces.append(tuple(12*seg+j for j in range(seg)))
    hair=mesh(prefix+"_HairCap",verts,faces,mats["hair"],smooth=True)
    _uv_cylinder(hair,13,seg)
    # Low-profile swept locks follow the head rather than spherical clumps.
    for j in range(12 if adult else 18):
        a=TAU*j/(12 if adult else 18)
        front=max(0,-math.sin(a))
        low=.097+.061*front
        pts=[]
        for k in range(7):
            t=k/6
            angle=a-.30*t
            z=.215*(1-t)+low*t
            cy,rx,ry=scalp_profile(min(z,.215))
            pts.append(p((rx+.007)*math.cos(angle),cy+(ry+.008)*math.sin(angle),z))
        _tube(prefix+f"_HairLock_{j:02}",pts,[.003*s,.004*s,.0045*s,.004*s,.0035*s,.002*s,.0009*s],mats["hair_high"],sides=6,depth_ratio=.55)
    if adult:
        # A restrained jaw beard, with a visible mouth and natural skin cheek.
        for side in (-1,1):
            pts=[p(side*.073,-.024,.078),p(side*.065,-.043,.048),p(side*.046,-.051,.026),p(side*.025,-.048,.013),p(0,-.039,.010)]
            _tube(prefix+f"_BeardEdge_{side}",pts,[.004*s,.005*s,.006*s,.006*s,.004*s],mats["hair"],sides=8,depth_ratio=.35)


def _hand(prefix, wrist, side, scale, mats, closed=False):
    s=scale
    x,y,z=wrist
    _loft(prefix+"_Palm",[(x,y,z,.023*s,.019*s),(x+side*.003*s,y-.003*s,z-.028*s,.029*s,.015*s),(x+side*.004*s,y-.003*s,z-.060*s,.023*s,.012*s)],mats["skin"],segments=20)
    for finger in range(4):
        fx=x+(-.020+finger*.013)*s
        length=[.047,.057,.055,.042][finger]*s
        pts=[(fx,y-.004*s,z-.050*s),(fx+side*.001*s,y-.006*s,z-.070*s),(fx+side*.002*s,y-(.023 if closed else .012)*s,z-.050*s-length),(fx+side*.002*s,y-(.033 if closed else .015)*s,z-.048*s-length)]
        _tube(prefix+f"_Finger_{finger}",pts,[.0062*s,.006*s,.0048*s,.0022*s],mats["skin"],sides=10)
        if not closed:
            _ellipsoid(prefix+f"_Nail_{finger}",(pts[-2][0],pts[-2][1]-.003*s,pts[-2][2]+.005*s),(.0036*s,.0009*s,.0048*s),mats["nail"],rings=6,segments=10)
    _tube(prefix+"_Thumb",[(x-side*.022*s,y,z-.021*s),(x-side*.039*s,y-.005*s,z-.039*s),(x-side*.043*s,y-.014*s,z-.059*s)],[.010*s,.008*s,.004*s],mats["skin"],sides=12)


def _foot(prefix,x,y,scale,mats):
    s=scale
    # Closed sandals: a modest toe box in a leather sole with crossing straps.
    foot=[(x,y-.042*s,.012*s,.035*s,.105*s),(x,y-.045*s,.032*s,.040*s,.108*s),(x,y-.038*s,.060*s,.037*s,.095*s),(x,y-.005*s,.092*s,.028*s,.055*s)]
    _loft(prefix+"_Foot",foot,mats["skin"],segments=28)
    _loft(prefix+"_Sole",[(x,y-.042*s,0,.038*s,.110*s),(x,y-.042*s,.016*s,.039*s,.111*s),(x,y-.042*s,.022*s,.037*s,.109*s)],mats["leather_dark"],segments=28)
    for i,offset in enumerate((-.110,-.065,-.025)):
        pts=[(x-.039*s,y+offset*s,.027*s),(x-.025*s,y+(offset-.005)*s,.057*s),(x,y+(offset-.004)*s,.067*s),(x+.025*s,y+(offset+.005)*s,.057*s),(x+.039*s,y+(offset+.008)*s,.027*s)]
        _tube(prefix+f"_SandalStrap_{i}",pts,[.007*s]*5,mats["leather"],sides=8,depth_ratio=.55)
    for side in (-1,1):
        _tube(prefix+f"_AnkleLace_{side}",[(x+side*.034*s,y+.011*s,.030*s),(x+side*.028*s,y+.015*s,.078*s),(x+side*.019*s,y-.014*s,.102*s)],[.0035*s]*3,mats["leather"],sides=8)
    _ring_detail(prefix+"_AnkleTie",(x,y,.100*s),.027*s,.028*s,.003*s,mats["leather"],segments=28)


def _materials(prefix,guard=False):
    # Original palettes; linen/leather texture input is resolved by common.py.
    return {
        "skin":material(prefix+"_Skin",(.43,.255,.165,1),roughness=.72),
        "lip":material(prefix+"_Lip",(.31,.115,.09,1),roughness=.78),
        "shadow":material(prefix+"_FaceShadow",(.095,.036,.020,1),roughness=.85),
        "nail":material(prefix+"_Nail",(.49,.34,.25,1),roughness=.7),
        "eye":material(prefix+"_EyeWhite",(.56,.53,.44,1),roughness=.45),
        "iris":material(prefix+"_Iris",(.070,.082,.038,1),roughness=.4),
        "dark":material(prefix+"_Pupil",(.004,.006,.004,1),roughness=.32),
        "hair":material(prefix+"_Hair",(.035,.020,.011,1),roughness=.84),
        "hair_high":material(prefix+"_HairHighlight",(.061,.035,.019,1),roughness=.86),
        "linen":material(prefix+"_Linen",(.31,.095,.047,1) if guard else (.56,.48,.32,1),roughness=.93,texture=None if guard else "linen"),
        "seam":material(prefix+"_Seam",(.23,.061,.031,1) if guard else (.31,.25,.16,1),roughness=.94),
        "leather":material(prefix+"_Leather",(.105,.047,.022,1),roughness=.86,texture="leather"),
        "leather_dark":material(prefix+"_Sole",(.045,.027,.016,1),roughness=.93),
        "bronze":material(prefix+"_Bronze",(.27,.16,.063,1),roughness=.48,metallic=.72,texture="bronze"),
        "iron":material(prefix+"_Iron",(.13,.135,.123,1),roughness=.53,metallic=.78),
        "cape":material(prefix+"_Mantle",(.18,.023,.014,1),roughness=.92),
        "shield":material(prefix+"_ShieldPaint",(.24,.038,.021,1),roughness=.82),
    }


def _tunic(prefix,s,mats,guard=False):
    rings=[(0,0,.650,.187,.109),(0,0,.673,.189,.112),(0,0,.720,.178,.110),(0,.002,.800,.160,.101),(0,0,.880,.145,.088),(0,-.002,.922,.135,.084),(0,-.004,.944,.146,.091),(0,.002,1.010,.156,.094),(0,.005,1.080,.167,.101),(0,.006,1.150,.175,.104),(0,.007,1.205,.176,.098),(0,.008,1.237,.148,.088),(0,.008,1.263,.072,.054)]
    _loft(prefix+"_Tunic",[(x*s,y*s,z*s,rx*s,ry*s) for x,y,z,rx,ry in rings],mats["linen"],segments=64,folds=.008*s,cap=False)
    for z,rx,ry in ((.654,.189,.112),(.670,.190,.114),(1.262,.072,.054)):
        _ring_detail(prefix+f"_Hem_{z}",(0,0,z*s),rx*s,ry*s,.0028*s,mats["seam"])
    for side in (-1,1):
        _tube(prefix+f"_SideSeam_{side}",[(side*rx*s,.015*s,z*s) for _,_,z,rx,ry in rings[:-1]],[.0015*s]*(len(rings)-1),mats["seam"],sides=6)
    # Belt is elliptical and follows the actual waist instead of floating.
    _loft(prefix+"_Belt",[(0,0,.911*s,.142*s,.090*s),(0,0,.930*s,.142*s,.090*s)],mats["leather"],segments=48,cap=False)
    # Belt buckle has a real open rectangular centre.
    pts=[(-.024*s,-.094*s,.907*s),(.024*s,-.094*s,.907*s),(.024*s,-.094*s,.936*s),(-.024*s,-.094*s,.936*s),(-.024*s,-.094*s,.907*s)]
    _tube(prefix+"_Buckle",pts,[.0028*s]*5,mats["bronze"],sides=8)
    _tube(prefix+"_BucklePin",[(0,-.098*s,.908*s),(0,-.098*s,.936*s)],[.0017*s]*2,mats["bronze"],sides=8)
    _tube(prefix+"_BeltEnd",[(.022*s,-.094*s,.920*s),(.035*s,-.112*s,.878*s),(.029*s,-.120*s,.814*s)],[.012*s]*3,mats["leather"],sides=8,depth_ratio=.20)


def _body(prefix,scale,mats,guard=False):
    s=scale
    for side in (-1,1):
        # Lower legs have ankle, calf, knee and thigh transitions in one mesh.
        x=side*.085
        rings=[(x,.003,.085,.024,.029),(x,.004,.140,.027,.030),(x,.007,.225,.041,.039),(x,.010,.320,.048,.042),(x,.006,.410,.039,.037),(x,0,.465,.040,.038),(x,.002,.510,.052,.047),(x*.87,.004,.620,.061,.057),(x*.75,0,.760,.065,.064)]
        _loft(prefix+f"_Leg_{side}",[(a*s,b*s,c*s,d*s,e*s) for a,b,c,d,e in rings],mats["skin"],segments=28)
        _foot(prefix+f"_Foot_{side}",x*s,0,s,mats)
        shoulder=(side*.165*s,.002*s,1.180*s)
        elbow=(side*.237*s,-.007*s,1.015*s)
        wrist=(side*.260*s,-.040*s,.830*s)
        if guard and side==1:
            elbow=(side*.240*s,.001*s,1.015*s)
            wrist=(side*.285*s,-.095*s,.850*s)
        pts=[shoulder,(side*.208*s,0,1.115*s),elbow,(side*.252*s,-.022*s,.920*s),wrist]
        _tube(prefix+f"_Arm_{side}",pts,[.053*s,.047*s,.032*s,.036*s,.022*s],mats["skin"],sides=24,depth_ratio=.87)
        # Short loose sleeve flows from shoulder into the upper arm.
        sleeve=[(side*.137*s,.002*s,1.207*s),(side*.174*s,0,1.175*s),(side*.213*s,-.002*s,1.100*s)]
        _tube(prefix+f"_Sleeve_{side}",sleeve,[.043*s,.059*s,.054*s],mats["linen"],sides=28,depth_ratio=.90)
        _hand(prefix+f"_Hand_{side}",wrist,side,s,mats,closed=guard)
        if guard:
            for dz in (.872,.907,.942):
                _loft(prefix+f"_Bracer_{side}_{dz}",[(side*.253*s,-.022*s,(dz-.010)*s,.037*s,.033*s),(side*.253*s,-.022*s,(dz+.010)*s,.037*s,.033*s)],mats["leather"],segments=24,cap=False)
    neck=_loft(prefix+"_Neck",[(0,.008,1.210,.038,.037),(0,.008,1.255,.039,.038),(0,.009,1.305,.043,.040)],mats["skin"],segments=28)
    # Neck uses the same metre profile as the civilian and needs explicit scale.
    for v in neck.data.vertices:
        v.co*=s
    _tunic(prefix,s,mats,guard)
    _face(prefix,1.297*s,s,mats,adult=guard)


def _armour(prefix,s,mats):
    # Art study of overlapping curved bands, not an archaeological claim.
    for i in range(6):
        low=(.975+i*.044)*s
        rx=(.155+i*.0037)*s
        ry=(.105+i*.0010)*s
        _loft(prefix+f"_CuirassBand_{i}",[(0,.005*s,low,rx,ry),(0,.005*s,low+.032*s,rx+.003*s,ry+.001*s),(0,.005*s,low+.043*s,rx-.001*s,ry)],mats["iron"],segments=48,cap=False)
        _ring_detail(prefix+f"_BandTrim_{i}",(0,.005*s,low+.002*s),rx+.001*s,ry+.001*s,.0016*s,mats["bronze"])
        for side in (-1,1):
            _ellipsoid(prefix+f"_BandRivet_{i}_{side}",(side*.036*s,-ry-.001*s,low+.021*s),(.0035*s,.0017*s,.0035*s),mats["bronze"],rings=6,segments=10)
    # Two straps secure the chest to a broad shoulder shell.
    for side in (-1,1):
        pts=[(side*.115*s,-.103*s,1.130*s),(side*.125*s,-.097*s,1.215*s),(side*.132*s,-.047*s,1.265*s),(side*.141*s,.024*s,1.265*s),(side*.133*s,.103*s,1.195*s)]
        _tube(prefix+f"_ShoulderStrap_{side}",pts,[.018*s]*5,mats["leather"],sides=10,depth_ratio=.14)
        for j in range(3):
            x=side*(.165+j*.025)*s
            _tube(prefix+f"_ShoulderPlate_{side}_{j}",[(x,-.079*s,(1.249-.018*j)*s),(x,-.035*s,(1.278-.020*j)*s),(x,.028*s,(1.275-.020*j)*s),(x,.080*s,(1.237-.019*j)*s)],[.025*s]*4,mats["iron"],sides=10,depth_ratio=.17)
    # Narrow hanging leather protection reveals the tunic and legs.
    for j in range(13):
        a=-math.pi+math.pi*j/12
        x=.151*math.cos(a)*s
        y=.111*math.sin(a)*s
        _tube(prefix+f"_SkirtStrap_{j}",[(x,y,.968*s),(x*1.07,y*1.09,.865*s),(x*1.10,y*1.12,.772*s)],[.014*s,.016*s,.014*s],mats["leather"],sides=8,depth_ratio=.15)


def _mantle(prefix,s,mats):
    verts=[]
    rows=20
    cols=30
    for i in range(rows+1):
        t=i/rows
        width=(.169+.048*math.sin(t*math.pi/2))*s
        for j in range(cols+1):
            u=j/cols*2-1
            z=(1.258-.646*t+.018*math.cos(u*math.pi)+.013*math.sin(4*u+2*t)*t)*s
            y=(.104+.033*t+.010*math.cos(8*math.pi*u+.6*t)+.018*u*u)*s
            verts.append((u*width,y,z))
    faces=[(i*(cols+1)+j,i*(cols+1)+j+1,(i+1)*(cols+1)+j+1,(i+1)*(cols+1)+j) for i in range(rows) for j in range(cols)]
    obj=mesh(prefix+"_Mantle",verts,faces,mats["cape"],smooth=True)
    uv=obj.data.uv_layers.active or obj.data.uv_layers.new(name="UVMap")
    for poly in obj.data.polygons:
        for li in poly.loop_indices:
            vi=obj.data.loops[li].vertex_index
            uv.data[li].uv=(vi%(cols+1)/cols,vi//(cols+1)/rows)
    solid=obj.modifiers.new("ClothThickness","SOLIDIFY")
    solid.thickness=.002*s
    bpy.context.view_layer.objects.active=obj
    bpy.ops.object.modifier_apply(modifier=solid.name)
    _ellipsoid(prefix+"_MantleClasp",(.122*s,-.078*s,1.257*s),(.017*s,.006*s,.017*s),mats["bronze"],rings=12,segments=20)


def _shield(prefix,s,mats):
    cx=.345*s
    zc=.753*s
    halfw=.205*s
    halfh=.307*s
    basey=-.140*s
    segx=24
    segz=16
    verts=[]
    for back in (False,True):
        for iz in range(segz+1):
            v=iz/segz*2-1
            for ix in range(segx+1):
                u=ix/segx*2-1
                corner=1-.105*abs(v)**6
                verts.append((cx+u*halfw*corner,basey-.067*s*(1-u*u)+(.013*s if back else 0),zc+v*halfh))
    layer=(segx+1)*(segz+1)
    faces=[]
    for back in (0,1):
        for iz in range(segz):
            for ix in range(segx):
                k=back*layer+iz*(segx+1)+ix
                f=(k,k+1,k+segx+2,k+segx+1)
                faces.append(tuple(reversed(f)) if back else f)
    obj=mesh(prefix+"_Shield",verts,faces,mats["shield"],smooth=True)
    # UVs follow the shield's curved planks.
    uv=obj.data.uv_layers.active or obj.data.uv_layers.new(name="UVMap")
    for poly in obj.data.polygons:
        for li in poly.loop_indices:
            vi=obj.data.loops[li].vertex_index%layer
            uv.data[li].uv=(vi%(segx+1)/segx,vi//(segx+1)/segx)
    outline=[]
    for iz in range(segz+1):
        v=-1+2*iz/segz
        outline.append((cx-halfw*(1-.105*abs(v)**6),basey,zc+v*halfh))
    for ix in range(1,segx+1):
        u=-1+2*ix/segx
        outline.append((cx+u*halfw*.895,basey-.067*s*(1-u*u),zc+halfh))
    for iz in range(1,segz+1):
        v=1-2*iz/segz
        outline.append((cx+halfw*(1-.105*abs(v)**6),basey,zc+v*halfh))
    for ix in range(1,segx+1):
        u=1-2*ix/segx
        outline.append((cx+u*halfw*.895,basey-.067*s*(1-u*u),zc-halfh))
    outline.append(outline[0])
    _tube(prefix+"_ShieldRim",outline,[.007*s]*len(outline),mats["bronze"],sides=8)
    _ellipsoid(prefix+"_ShieldBoss",(cx,basey-.076*s,zc),(.050*s,.039*s,.052*s),mats["iron"],rings=16,segments=24)
    # Restrained original stripes; no copied faction insignia.
    for side in (-1,1):
        _tube(prefix+f"_ShieldStripe_{side}",[(cx+side*.054*s,basey-.071*s,zc+.250*s),(cx+side*.045*s,basey-.075*s,zc+.090*s),(cx+side*.084*s,basey-.065*s,zc-.090*s),(cx+side*.068*s,basey-.068*s,zc-.249*s)],[.008*s]*4,mats["bronze"],sides=8,depth_ratio=.12)


def _scabbard(prefix,s,mats):
    points=[(-.184*s,.010*s,.944*s),(-.217*s,.036*s,.735*s),(-.254*s,.055*s,.486*s)]
    _tube(prefix+"_Scabbard",points,[.025*s,.027*s,.015*s],mats["leather_dark"],sides=12,depth_ratio=.36)
    _tube(prefix+"_ScabbardChape",[points[-1],(-.251*s,.052*s,.525*s)],[.016*s,.021*s],mats["bronze"],sides=12,depth_ratio=.40)
    _tube(prefix+"_SwordGrip",[(-.182*s,.009*s,.940*s),(-.169*s,.001*s,1.023*s)],[.012*s,.011*s],mats["oak"] if "oak" in mats else mats["leather"],sides=12)
    _ellipsoid(prefix+"_SwordPommel",(-.169*s,.001*s,1.024*s),(.020*s,.013*s,.014*s),mats["bronze"],rings=10,segments=16)


def build_civilian():
    """Return all new objects for an approximately 1.52 m civilian art study."""
    before=set(bpy.data.objects)
    mats=_materials("Civilian")
    _body("Civilian",1.0,mats)
    # Small shoulder satchel gives a lived-in civilian silhouette.
    _tube("Civilian_SatchelStrap",[(-.121,-.065,1.248),(-.049,-.111,1.108),(.080,-.102,.941),(.158,-.041,.817)],[.012]*4,mats["leather"],sides=10,depth_ratio=.14)
    _loft("Civilian_Satchel",[(.158,.010,.729,.045,.028),(.158,.010,.746,.057,.037),(.158,.010,.829,.055,.034),(.158,.010,.853,.045,.029)],mats["leather"],segments=28)
    _ellipsoid("Civilian_SatchelClasp",(.158,-.028,.820),(.007,.002,.007),mats["bronze"],rings=8,segments=12)
    objects=[obj for obj in bpy.data.objects if obj not in before]
    for obj in objects:
        obj["asset_role"]="civilian_youth_art_proposal"
        obj["deformation_status"]="static_unrigged"
    _mobile_palette(objects,mats,"Civilian")
    _mobile_budget(objects)
    return objects


def build_guard():
    """Return all new objects for an approximately 1.78 m adult guard."""
    before=set(bpy.data.objects)
    scale=1.78/1.52
    mats=_materials("Guard",guard=True)
    _body("Guard",scale,mats,guard=True)
    _armour("Guard",scale,mats)
    _mantle("Guard",scale,mats)
    _shield("Guard",scale,mats)
    _scabbard("Guard",scale,mats)
    objects=[obj for obj in bpy.data.objects if obj not in before]
    for obj in objects:
        obj["asset_role"]="adult_frontier_guard_art_study"
        obj["deformation_status"]="static_unrigged"
    _mobile_palette(objects,mats,"Guard")
    _mobile_budget(objects)
    return objects


def _mobile_palette(objects,mats,prefix):
    """Keep distinct facial colours in COLOR_0 while batching to seven slots."""
    keys=("skin","lip","shadow","nail","eye","iris","dark","hair","hair_high","seam")
    colours={mats[k]:tuple(mats[k].diffuse_color) for k in keys}
    palette=material(prefix+"_CharacterPalette",(1,1,1,1),roughness=.76)
    nodes=palette.node_tree.nodes
    colour_node=nodes.get("CharacterTint") or nodes.new("ShaderNodeVertexColor")
    colour_node.name="CharacterTint"
    colour_node.layer_name="Tint"
    palette.node_tree.links.new(colour_node.outputs["Color"],nodes.get("Principled BSDF").inputs["Base Color"])
    for obj in objects:
        if obj.type!="MESH" or not obj.data.materials:
            continue
        old=obj.data.materials[0]
        if old in colours:
            colour=obj.data.color_attributes.new(name="Tint",type="FLOAT_COLOR",domain="CORNER")
            colour.data.foreach_set("color",list(colours[old])*len(colour.data))
            obj.data.color_attributes.active_color=colour
            obj.data.materials[0]=palette
        elif old==mats["leather_dark"]:
            obj.data.materials[0]=mats["leather"]


def _mobile_budget(objects,target_triangles=19000):
    """Bound LOD0 cost. Preserve tiny detail meshes; simplify large surfaces."""
    counts={o:sum(len(p.vertices)-2 for p in o.data.polygons) for o in objects if o.type=="MESH"}
    total=sum(counts.values())
    retained=sum(n for n in counts.values() if n<100)
    ratio=1 if total<=target_triangles else max(.10,min(1,(target_triangles-retained)/(total-retained)))
    bpy.ops.object.select_all(action="DESELECT")
    for obj,n in counts.items():
        if n>=100 and ratio<1:
            bpy.context.view_layer.objects.active=obj
            obj.select_set(True)
            mod=obj.modifiers.new("Mobile_LOD0_Simplification","DECIMATE")
            mod.ratio=ratio
            mod.use_collapse_triangulate=True
            bpy.ops.object.modifier_apply(modifier=mod.name)
            obj.select_set(False)
        # Explicitly triangulate end caps so glTF tangents remain available.
        bm=bmesh.new()
        bm.from_mesh(obj.data)
        bmesh.ops.triangulate(bm,faces=[f for f in bm.faces if len(f.verts)>3])
        tiny=[face for face in bm.faces if face.calc_area()<=5e-11]
        if tiny:
            bmesh.ops.delete(bm,geom=tiny,context="FACES")
        bm.to_mesh(obj.data)
        bm.free()


def _metrics(objects):
    pts=[o.matrix_world @ v.co for o in objects if o.type=="MESH" for v in o.data.vertices]
    return {
        "mesh_objects":sum(o.type=="MESH" for o in objects),
        "source_vertices":sum(len(o.data.vertices) for o in objects if o.type=="MESH"),
        "source_triangles":sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in objects if o.type=="MESH"),
        "dimensions_m":[round(max(v[i] for v in pts)-min(v[i] for v in pts),4) for i in range(3)],
        "bounds_min_m":[round(min(v[i] for v in pts),4) for i in range(3)],
        "rigged":False,
        "animations":[],
        "intended_use":"Static art reference and scene population; rigging, deformation and gameplay integration remain unverified.",
    }


def _export_lod1(asset_id,output_dir):
    """Create a real 8k triangle alternative with the same placement bounds."""
    reset_scene()
    bpy.ops.import_scene.gltf(filepath=str(output_dir/f"{asset_id}.glb"))
    objects=[obj for obj in bpy.context.scene.objects if obj.type=="MESH"]
    points=[obj.matrix_world@v.co for obj in objects for v in obj.data.vertices]
    original_min=Vector([min(v[i] for v in points) for i in range(3)])
    original_max=Vector([max(v[i] for v in points) for i in range(3)])
    _mobile_budget(objects,target_triangles=7900)
    points=[obj.matrix_world@v.co for obj in objects for v in obj.data.vertices]
    current_min=Vector([min(v[i] for v in points) for i in range(3)])
    current_max=Vector([max(v[i] for v in points) for i in range(3)])
    for obj in objects:
        inverse=obj.matrix_world.inverted()
        for vertex in obj.data.vertices:
            point=obj.matrix_world@vertex.co
            for axis in range(3):
                t=(point[axis]-current_min[axis])/(current_max[axis]-current_min[axis])
                point[axis]=original_min[axis]+t*(original_max[axis]-original_min[axis])
            vertex.co=inverse@point
        obj["lod_level"]=1
        obj["deformation_status"]="static_unrigged"
    stats=_metrics(objects)
    stats["lod_of"]=asset_id
    stats["intended_use"]="Reduced detail for distant/static scene population. The base asset remains the close-up source."
    export_asset(asset_id+"_lod1",objects,output_dir)
    return stats


def render_previews(output_dir,samples=48):
    """Review the exported GLBs after reimport, with reproducible CPU lighting."""
    output_dir=Path(output_dir)
    reset_scene()
    existing=[name for name in ("civilian_youth","frontier_guard") if (output_dir/f"{name}.glb").is_file()]
    if not existing:
        raise FileNotFoundError("Build at least one character before rendering previews")
    offsets={name:(-.62 if name=="civilian_youth" else .38) if len(existing)==2 else 0 for name in existing}
    for name in existing:
        before=set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=str(output_dir/f"{name}.glb"))
        for obj in set(bpy.data.objects)-before:
            if not obj.parent:
                obj.location.x+=offsets[name]
    bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.008))
    bpy.context.object.data.materials.append(material("CharacterStudioFloor",(.10,.12,.13,1),roughness=.86))
    scene=bpy.context.scene
    scene.world.color=(.14,.14,.14)
    for name,location,power,size in (("Key",(-3,-4,5),600,4),("Fill",(3,-1,3),380,3),("Rim",(0,3,4),650,3)):
        bpy.ops.object.light_add(type="AREA",location=location)
        light=bpy.context.object
        light.name=name
        light.data.energy=power
        light.data.shape="DISK"
        light.data.size=size
        light.rotation_euler=(Vector((0,0,1))-light.location).to_track_quat("-Z","Y").to_euler()
    bpy.ops.object.camera_add(location=(2.4,-6.2,2.5))
    camera=bpy.context.object
    camera.rotation_euler=(Vector((0,0,.88))-camera.location).to_track_quat("-Z","Y").to_euler()
    camera.data.type="ORTHO"
    camera.data.ortho_scale=2.66
    scene.camera=camera
    scene.render.engine="CYCLES"
    scene.cycles.samples=samples
    scene.cycles.use_denoising=False
    scene.render.resolution_x=1280
    scene.render.resolution_y=960
    scene.render.resolution_percentage=100
    scene.view_settings.view_transform="AgX"
    scene.render.image_settings.file_format="PNG"
    scene.render.filepath=str(output_dir/"characters_studio_preview.png")
    bpy.ops.render.render(write_still=True)
    if "civilian_youth" in existing:
        x=offsets["civilian_youth"]
        camera.location=(x,-1.15,1.45)
        camera.rotation_euler=(Vector((x,0,1.405))-camera.location).to_track_quat("-Z","Y").to_euler()
        camera.data.ortho_scale=.34
        scene.render.resolution_x=900
        scene.render.resolution_y=900
        scene.render.filepath=str(output_dir/"civilian_face_preview.png")
        bpy.ops.render.render(write_still=True)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir",type=Path,default=Path(__file__).resolve().parents[2]/"art/visual_benchmark/assets/characters")
    parser.add_argument("--asset",choices=("all","civilian","guard"),default="all")
    parser.add_argument("--skip-lod1",action="store_true",help="Only regenerate the detailed source assets.")
    parser.add_argument("--render-preview",action="store_true",help="Render the reimported GLBs with fixed CPU studio lighting.")
    argv=sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else []
    args=parser.parse_args(argv)
    args.output_dir.mkdir(parents=True,exist_ok=True)
    report={"blender_version":bpy.app.version_string,"source":"Original procedural geometry authored for IMPERATHEN; no external model provider.","status":"Static character modelling studies; no skeletal animation claim.","assets":{}}
    for key,builder in (("civilian",build_civilian),("guard",build_guard)):
        if args.asset not in ("all",key):
            continue
        reset_scene()
        objects=builder()
        metrics=_metrics(objects)
        asset_id="civilian_youth" if key=="civilian" else "frontier_guard"
        export_asset(asset_id,objects,args.output_dir)
        report["assets"][asset_id]=metrics
        print("CHARACTER_ASSET",asset_id,json.dumps(metrics,sort_keys=True))
        if not args.skip_lod1:
            report["assets"][asset_id+"_lod1"]=_export_lod1(asset_id,args.output_dir)
    (args.output_dir/"character_build_report.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
    if args.render_preview:
        render_previews(args.output_dir)


if __name__=="__main__":
    main()
