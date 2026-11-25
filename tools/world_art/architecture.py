#!/usr/bin/env python3
"""Original modular Roman-inspired architecture for IMPERATHEN.

Blender 4.3+: blender -b -t 2 --python tools/world_art/architecture.py -- --render
Metric source: Z up, facade -Y. GLB: Y up, facade +Z.
Fictional art modules, not an archaeological reconstruction. No runtime FPS or
interior/collision acceptance is implied by a successful asset export.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import math
import random
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "art"))
from common import material, mesh, reset_scene, _bake_modifiers
from build_architecture import Geometry, roof_tile_geometry

ART = ROOT / "art/world_expansion/architecture"
RUNTIME = ROOT / "prototype/assets/world_expansion/architecture"
SEED = 20261125
FLOOR = .12
ASSET_IDS = ("taberna", "insula", "basilica", "basalt_road")


def palette(lod):
    mats = {
        "plaster": material("WX_Lime_Plaster", (.70,.64,.50), .91, texture="plaster"),
        "red": material("WX_Ochre_Painted_Plaster", (.43,.15,.075), .92, texture="plaster"),
        "stone": material("WX_Limestone", (.46,.44,.36), .91, texture="limestone"),
        "dark_stone": material("WX_Basalt", (.18,.20,.19), .93, texture="limestone"),
        "wood": material("WX_Oak", (.26,.16,.075), .86, texture="oak"),
        "roof": material("WX_Terracotta", (.48,.22,.12), .88, texture="terracotta"),
        "roof_light": material("WX_Terracotta_Light", (.60,.29,.16), .89, texture="terracotta"),
        "roof_dark": material("WX_Terracotta_Dark", (.35,.13,.06), .91, texture="terracotta"),
        "canvas": material("WX_Linen", (.57,.42,.24), .95, texture="linen"),
        "bronze": material("WX_Bronze", (.32,.22,.09), .54, .70, texture="bronze"),
    }
    if lod == 2:
        mats["roof_light"] = mats["roof"]
        mats["roof_dark"] = mats["roof"]
        mats["red"] = mats["plaster"]
        mats["bronze"] = mats["wood"]
    return mats


class Builder:
    def __init__(self, prefix, lod):
        self.prefix = prefix
        self.lod = lod
        self.mats = palette(lod)
        self.geo = {}
        self.collision_boxes = []

    def group(self, name):
        if name not in self.geo:
            self.geo[name] = Geometry(self.prefix + "_" + name, self.mats[name])
        return self.geo[name]

    def box(self, mat, centre, dimensions, rotation=0, structural=False):
        if min(dimensions) <= 0:
            raise ValueError("Nonpositive box")
        basis = Matrix.Rotation(rotation,3,"Z") if rotation else None
        self.group(mat).cuboid(centre, dimensions, basis)
        if structural:
            # Only unrotated axis-aligned structural boxes are exported here.
            if rotation:
                raise ValueError("Rotated collision box requires explicit shape")
            x,y,z = centre
            dx,dy,dz = dimensions
            self.collision_boxes.append({
                "center": [round(x,5),round(z,5),round(-y,5)],
                "size": [round(dx,5),round(dz,5),round(dy,5)]
            })

    def beam(self, mat, a, b, width, depth=None):
        self.group(mat).beam(a,b,width,depth)

    def prism(self, mat, polygon, z0, z1):
        n=len(polygon)
        verts=[(x,y,z) for z in (z0,z1) for x,y in polygon]
        faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]
        faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
        self.group(mat).add(verts,faces)

    def lathe(self, mat, center, profile, segments=None):
        segments=segments or (16,10,7)[self.lod]
        cx,cy,cz=center
        verts=[(cx+r*math.cos(i*math.tau/segments),
                cy+r*math.sin(i*math.tau/segments),cz+z)
               for z,r in profile for i in range(segments)]
        faces=[]
        for j in range(len(profile)-1):
            for i in range(segments):
                nxt=(i+1)%segments
                faces.append((j*segments+i,j*segments+nxt,
                              (j+1)*segments+nxt,(j+1)*segments+i))
        faces.extend([tuple(reversed(range(segments))),
                      tuple((len(profile)-1)*segments+i for i in range(segments))])
        self.group(mat).add(verts,faces)

    def wall(self, axis, start, end, fixed, z0, z1, openings, thickness=.32,
             mat="plaster", structural=True):
        aa=sorted(set([start,end]+[v for o in openings for v in o[:2] if start<v<end]))
        zz=sorted(set([z0,z1]+[v for o in openings for v in o[2:] if z0<v<z1]))
        for a,b in zip(aa,aa[1:]):
            for c,d in zip(zz,zz[1:]):
                mid=((a+b)/2,(c+d)/2)
                if any(l <= mid[0] <= r and lo <= mid[1] <= hi
                       for l,r,lo,hi in openings):
                    continue
                centre=((a+b)/2,fixed,(c+d)/2) if axis=="X" else (fixed,(a+b)/2,(c+d)/2)
                size=(b-a,thickness,d-c) if axis=="X" else (thickness,b-a,d-c)
                self.box(mat,centre,size,structural=structural)

    def frame(self, axis, center, fixed, lo, hi, width, shutters=False):
        for a,z,du,dz in ((center-width/2-.06,(lo+hi)/2,.12,hi-lo+.24),
                          (center+width/2+.06,(lo+hi)/2,.12,hi-lo+.24),
                          (center,lo-.06,width+.24,.12),
                          (center,hi+.06,width+.24,.12)):
            pos=(a,fixed,z) if axis=="X" else (fixed,a,z)
            dim=(du,.16,dz) if axis=="X" else (.16,du,dz)
            self.box("stone",pos,dim)
        if shutters and self.lod<2:
            for sign in (-1,1):
                a=center+sign*(width/2+.24)
                pos=(a,fixed+.035,(lo+hi)/2) if axis=="X" else (fixed-.035,a,(lo+hi)/2)
                dim=(.38,.07,hi-lo) if axis=="X" else (.07,.38,hi-lo)
                self.box("wood",pos,dim)

    def finish(self, bevel_override=None):
        for name,geo in self.geo.items():
            # Small bevels catch grazing light without softening every silhouette.
            bevel = .012 if self.lod == 0 and name in ("stone","wood","dark_stone") else 0
            if bevel_override is not None:
                bevel = bevel_override
            geo.finish(bevel=bevel)


def gable(b,halfwidth,depth,eave,ridge):
    for y in (-depth/2,depth/2):
        verts=[(-halfwidth,y-.14,eave),(halfwidth,y-.14,eave),(0,y-.14,ridge),
               (-halfwidth,y+.14,eave),(halfwidth,y+.14,eave),(0,y+.14,ridge)]
        b.group("plaster").add(verts,[(0,1,2),(3,5,4),(0,3,4,1),(1,4,5,2),(2,5,3,0)])


def roof(b,width,depth,eave,ridge):
    half=width/2
    slope=math.hypot(half,ridge-eave)
    angle=math.atan2(ridge-eave,half)
    for sign in (-1,1):
        u=Vector((-sign*math.cos(angle),0,math.sin(angle)))
        v=Vector((0,1,0))
        n=Vector((sign*math.sin(angle),0,math.cos(angle)))
        basis=Matrix((u,v,n)).transposed()
        center=Vector((sign*half/2,0,(eave+ridge)/2))
        b.group("roof_dark").cuboid(center,(slope,depth,.10),basis)
    if b.lod==0:
        roof_tile_geometry(b.prefix,b.mats,half,depth/2,eave+.06,ridge+.06,
                           rows=max(5,round(slope/.52)),columns=max(8,round(depth/.48)))
    elif b.lod==1:
        # Fewer real raised joints, with full roof support underneath.
        for sign in (-1,1):
            for i in range(max(6,round(depth/.9))+1):
                y=-depth/2+i*depth/max(6,round(depth/.9))
                b.beam("roof",(sign*half,y,eave+.08),(0,y,ridge+.08),.065,.065)
        b.box("roof",(0,0,ridge+.09),(.20,depth,.16))
    else:
        b.box("roof",(0,0,ridge+.075),(.18,depth,.13))


def stone_plinth(b,width,depth,z=.42):
    # The structural floor is separate from facade masonry and door openings.
    b.box("stone",(0,0,FLOOR/2),(width,depth,FLOOR),structural=True)
    if b.lod==0:
        for side in (-1,1):
            for i in range(round(depth/.55)):
                step=depth/round(depth/.55)
                b.box("stone",(side*(width/2+.018),-depth/2+(i+.5)*step,z/2),
                      (.15,step-.025,z-.02))
        for i in range(round(width/.58)):
            step=width/round(width/.58)
            for side in (-1,1):
                if side==-1 and abs(-width/2+(i+.5)*step)<1.3:
                    continue
                b.box("stone",(-width/2+(i+.5)*step,side*(depth/2+.018),z/2),
                      (step-.025,.15,z-.02))


def amphora(b,x,y,z,scale=1):
    profile=[(0,.10),(.08,.16),(.18,.24),(.50,.29),(.72,.19),
             (.81,.10),(.92,.09),(.97,.14),(1.02,.14)]
    b.lathe("roof_light",(x,y,z),[(h*scale,r*scale) for h,r in profile])
    if b.lod==0:
        for sign in (-1,1):
            p1=(x+sign*.11*scale,y,z+.88*scale)
            p2=(x+sign*.25*scale,y,z+.69*scale)
            p3=(x+sign*.22*scale,y,z+.56*scale)
            b.beam("roof_light",p1,p2,.045*scale)
            b.beam("roof_light",p2,p3,.045*scale)


def taberna(lod):
    b=Builder("taberna",lod)
    w,d=7.0,7.5
    stone_plinth(b,w,d)
    b.wall("X",-w/2,w/2,-d/2,FLOOR,3.35,[(-2.0,2.0,FLOOR,2.75)])
    b.wall("X",-w/2,w/2,d/2,FLOOR,3.35,[(-.55,.55,1.55,2.45)])
    for side in (-1,1):
        b.wall("Y",-d/2,d/2,side*w/2,FLOOR,3.35,[(-.6,.6,1.55,2.45)])
    b.frame("X",0,-d/2-.18,FLOOR,2.75,4.0)
    b.frame("X",0,d/2+.18,1.55,2.45,1.1,True)
    for side in (-1,1):
        b.frame("Y",0,side*(w/2+.18),1.55,2.45,1.2,True)
    for y in (-d/2-.18,d/2+.18):
        b.wall("X",-w/2,w/2,y,.47,1.09,
               [(-2.0,2.0,FLOOR,2.75)] if y<0 else [],.035,"red",False)
    gable(b,w/2,d,3.35,4.75)
    roof(b,7.7,8.1,3.29,4.82)
    # Rolled timber shutters to either side leave the central opening real.
    if lod<2:
        for x in (-2.65,2.65):
            for i in range(6):
                b.box("wood",(x-.43+i*.17,-3.98,1.48),(.16,.10,2.45))
        b.box("wood",(.82,-2.82,.65),(2.05,.66,1.06),structural=True)
        b.box("stone",(.82,-2.82,1.21),(2.22,.78,.13))
        for y in (1.15,2.45):
            b.box("wood",(2.75,y,.68),(.85,1.0,1.13))
            for x in (2.48,2.85):
                amphora(b,x,y,1.24,.52)
        for z in (.70,1.53,2.32):
            b.box("wood",(0,3.33,z),(5.7,.6,.095))
        if lod==0:
            for x in (-2.3,-1.25,-.2,.85,1.9):
                amphora(b,x,3.25,.75,.6)
                amphora(b,x,3.25,1.58,.62)
    # Sewn linen canopy with actual sag; no alpha cards.
    if lod<2:
        v=[]; f=[]
        segments=18 if lod==0 else 6
        for row in range(2):
            for i in range(segments+1):
                x=-3.65+7.3*i/segments
                y=-3.92-row*1.85
                z=3.03-row*.49-.045*math.sin(i*math.pi*2/(segments/3))
                v.append((x,y,z))
        for i in range(segments):
            f.append((i,segments+i+1,segments+i+2,i+1))
        canvas=b.group("canvas")
        canvas.add(v,f)
        # Duplicate with reversed winding for a physically thin double-sided canopy.
        canvas.add([(x,y,z-.013) for x,y,z in v],[tuple(reversed(q)) for q in f])
        for x in (-3.63,3.63):
            b.box("wood",(x,-5.72,1.30),(.10,.10,2.60))
            b.beam("wood",(x,-3.92,3.03),(x,-5.72,2.57),.065)
        b.box("wood",(0,-5.72,2.57),(7.35,.07,.07))
    else:
        basis=Matrix.Rotation(math.atan2(.49,1.85),3,"X")
        b.group("canvas").cuboid((0,-4.84,2.785),(7.30,1.91,.035),basis)
    b.finish()
    return b,{"category":"commerce","role":"taberna",
              "door_clearance":[4.0,2.63],"interior_review":"art geometry only",
              "floor_height":FLOOR}


def insula(lod):
    b=Builder("insula",lod)
    w,d=10.0,9.0
    stone_plinth(b,w,d)
    # Ground shop + two upper residential levels; openings survive every LOD.
    for floor in range(3):
        z0=FLOOR+floor*2.86
        z1=z0+2.86
        openings=[]
        for x in (-3.3,0,3.3):
            lo=z0+.83 if floor else FLOOR
            hi=z0+2.15 if floor else 2.53
            width=1.15 if floor else 2.1
            openings.append((x-width/2,x+width/2,lo,hi))
        front_openings=list(openings)
        if floor==2:
            # The balcony walking surface is at 5.875 m: a 35 mm threshold
            # above the interior floor. Keep the rear facade a normal window.
            front_openings[1]=(-.675,.675,5.875,z0+2.15)
        for y in (-d/2,d/2):
            ops=front_openings if y<0 else (openings if floor else [(-.65,.65,1.1,2.4)])
            b.wall("X",-w/2,w/2,y,z0,z1,ops)
            for l,r,lo,hi in ops:
                b.frame("X",(l+r)/2,y+math.copysign(.18,y),lo,hi,r-l,lod<2 and floor>0)
        for x in (-w/2,w/2):
            ops=[(y-.55,y+.55,z0+.85,z0+2.13) for y in (-2.6,0,2.6)]
            b.wall("Y",-d/2,d/2,x,z0,z1,ops)
            for l,r,lo,hi in ops:
                b.frame("Y",(l+r)/2,x+math.copysign(.18,x),lo,hi,r-l,lod==0)
        if floor>0:
            b.box("wood",(0,0,z0-.08),(9.6,8.6,.16),structural=True)
        for y in (-d/2-.19,d/2+.19):
            b.wall("X",-w/2,w/2,y,z0+.125,z0+.375,
                   front_openings if y<0 else [],.08,"red",False)
            b.box("stone",(0,y,z1-.05),(w+.42,.34,.17))
        for x in (-w/2-.19,w/2+.19):
            b.box("stone",(x,0,z1-.05),(.34,d+.1,.17))
    if lod<2:
        # Small upper balcony and supported beams; no floating slab.
        b.box("wood",(0,-5.12,5.79),(3.25,1.25,.17))
        for x in (-1.52,1.52):
            b.beam("wood",(x,-4.65,4.8),(x,-5.52,5.69),.14)
            b.box("wood",(x,-5.66,6.24),(.09,.09,.9))
        for z in (5.90,6.64):
            b.box("wood",(0,-5.66,z),(3.25,.10,.095))
        for x in (-1.08,-.54,0,.54,1.08):
            b.box("wood",(x,-5.66,6.24),(.055,.065,.75))
    else:
        b.box("wood",(0,-5.12,5.79),(3.25,1.25,.17))
        b.box("wood",(0,-5.66,6.24),(3.25,.10,.90))
    eave=FLOOR+3*2.86
    gable(b,w/2,d,eave,10.33)
    roof(b,10.8,9.8,eave-.02,10.40)
    b.finish()
    return b,{"category":"residential","role":"insula",
              "storeys":3,"door_clearance":[2.1,2.41],
              "balcony_door_clearance":[1.35,2.115],"balcony_threshold_height":5.875,
              "balcony_step_from_interior":.035,
              "interior_review":"upper levels have floors; no stair/navigation acceptance",
              "floor_height":FLOOR}


def basilica(lod):
    b=Builder("basilica",lod)
    w,d=12.0,16.0
    stone_plinth(b,w,d)
    walltop=7.52
    for side in (-1,1):
        openings=[(y-.7,y+.7,4.6,6.45) for y in (-5.2,-2.6,0,2.6,5.2)]
        b.wall("Y",-d/2,d/2,side*w/2,FLOOR,walltop,openings,.42)
        for l,r,lo,hi in openings:
            b.frame("Y",(l+r)/2,side*(w/2+.23),lo,hi,r-l)
    b.wall("X",-w/2,w/2,-d/2,FLOOR,walltop,[(-1.8,1.8,FLOOR,4.4)],.42)
    b.wall("X",-w/2,w/2,d/2,FLOOR,walltop,[(-1.2,1.2,4.6,6.5)],.42)
    b.frame("X",0,-8.25,FLOOR,4.4,3.6)
    # The 18 mm fluting ribs need their own un-beveled group: a 12 mm stone
    # bevel exceeds their 9 mm half-width and collapses faces and inherited UVs.
    fluting = Builder("basilica_fluting", lod) if lod == 0 else None
    # Portico, four tapered columns, visible torus/abacus silhouettes.
    for x in (-4.85,-1.65,1.65,4.85):
        y=-10.10
        b.box("stone",(x,y,.20),(.92,.92,.40),structural=True)
        b.lathe("stone",(x,y,.40),[(0,.44),(.12,.44),(.18,.37),(.24,.37),
                                   (.35,.32),(5.52,.27),(5.62,.34),
                                   (5.76,.34),(5.84,.44)],(20,12,8)[lod])
        b.box("stone",(x,y,6.37),(.95,.95,.26))
        if lod==0:
            # Fine vertical fluting is represented by alternating profile facets;
            # genuine base/capital profiles remain at every level.
            for i in range(12):
                ang=i*math.tau/12
                fluting.beam("stone",(x+.323*math.cos(ang),y+.323*math.sin(ang),.83),
                            (x+.275*math.cos(ang),y+.275*math.sin(ang),5.86),.018)
    if fluting is not None:
        fluting.finish(bevel_override=0.0)
    for i in range(3):
        b.box("stone",(0,-9.55-i*.44,.04+i*.035),
              (12.6,2.9-i*.65,.08+i*.07),structural=True)
    b.box("stone",(0,-10.10,6.66),(12.7,.85,.34))
    b.box("stone",(0,-10.10,6.91),(13.00,1.04,.19))
    for y in (-8.25,8.25):
        b.box("stone",(0,y,7.26),(12.6,.50,.30))
        b.box("red",(0,y,6.90),(12.2,.08,.25))
    # Main gabled hall and small pediment over portico.
    gable(b,6,d,walltop,10.02)
    roof(b,13,17,walltop-.02,10.10)
    pediment=b.group("plaster")
    v=[(-6.15,-10.55,7.01),(6.15,-10.55,7.01),(0,-10.55,8.48),
       (-6.15,-9.8,7.01),(6.15,-9.8,7.01),(0,-9.8,8.48)]
    pediment.add(v,[(0,1,2),(3,5,4),(0,3,4,1),(1,4,5,2),(2,5,3,0)])
    for side in (-1,1):
        b.beam("stone",(side*6.3,-10.59,7.04),(0,-10.59,8.55),.19,.28)
    # A complete roof spans the formerly open portico. The back reaches inside
    # the front wall; the front overhang covers the pediment. Every LOD retains
    # continuous roof undersides; LOD0 additionally has individual tegulae.
    before=set(bpy.context.scene.objects.keys())
    porch=Builder("basilica_portico",lod)
    roof(porch,13.0,3.0,7.10,8.60)
    porch.finish()
    for obj in bpy.context.scene.objects:
        if obj.name not in before:
            obj.location.y-=9.20
    if lod<2:
        b.box("red",(0,-10.60,7.41),(2.70,.04,.30))
        # Interior bench and central dais are artwork; no emperor/quest is invented.
        b.box("stone",(0,6.0,.28),(5.5,2.4,.32),structural=True)
        for x in (-5.2,5.2):
            b.box("wood",(x,1.6,.52),(.6,8.0,.14))
            for y in (-1.5,1.0,4.5):
                b.box("stone",(x,y,.28),(.44,.44,.43))
    b.finish()
    return b,{"category":"civic","role":"administration_basilica",
              "door_clearance":[3.6,4.28],"interior_review":"art geometry only",
              "portico_roof_plan_bounds_blender":[[-6.5,-10.7],[6.5,-7.7]],
              "floor_height":FLOOR,"historical_status":"fictional Roman-inspired civic module"}


def basalt_road(lod):
    b=Builder("basalt_road",lod)
    b.box("dark_stone",(0,0,.025),(8,8,.05),structural=True)
    rng=random.Random(SEED+83)
    # Shared jittered lattice with contracted polygons: visible real stone joints,
    # no modern asphalt. LODs preserve the full 8 m envelope and gutter corridor.
    count=(13,8,4)[lod]
    width=6.7
    points={}
    for j in range(count+1):
        for i in range(count+1):
            x=-width/2+width*i/count
            y=-4+8*j/count
            if 0<i<count: x+=rng.uniform(-.09,.09)
            if 0<j<count: y+=rng.uniform(-.10,.10)
            points[i,j]=(x,y)
    for j in range(count):
        for i in range(count):
            raw=[points[i,j],points[i+1,j],points[i+1,j+1],points[i,j+1]]
            cx=sum(p[0] for p in raw)/4
            cy=sum(p[1] for p in raw)/4
            poly=[(cx+(x-cx)*.96,cy+(y-cy)*.96) for x,y in raw]
            crown=.025*(1-abs(cx)/(width/2))
            b.prism("dark_stone",poly,.035,.085+crown)
    for sign in (-1,1):
        # Narrow continuous open drainage channel separates carriageway/footway.
        b.box("dark_stone",(sign*3.43,0,.045),(.16,8,.04))
        if lod==0:
            for j in range(10):
                b.box("stone",(sign*3.77,-3.6+j*.8,.12),(.46,.78,.08))
            for j in range(16):
                b.box("stone",(sign*3.50,-3.75+j*.5,.10),(.12,.48,.12))
        else:
            b.box("stone",(sign*3.77,0,.12),(.46,8,.08))
            b.box("stone",(sign*3.50,0,.10),(.12,8,.12))
    b.finish()
    return b,{"category":"road","role":"basalt_paving","tile_size":[8,8],
              "road_width":6.7,"gutter_width":.16,"surface_review":"road art, collision simplified"}


def compact_tangent_storage(path):
    """Remove explicit tangents without re-exporting or changing other GLB data.

    Godot's default meshes/ensure_tangents import setting regenerates tangents.
    This deliberately supports only this package's static, uncompressed GLBs.
    Every retained accessor and embedded image is byte-checked before writing.
    """
    import copy
    import struct

    raw = path.read_bytes()
    if struct.unpack_from("<III", raw) != (0x46546C67, 2, len(raw)):
        raise ValueError("Invalid GLB header")
    json_size, json_kind = struct.unpack_from("<II", raw, 12)
    if json_kind != 0x4E4F534A:
        raise ValueError("Expected GLB JSON chunk")
    source = json.loads(raw[20:20 + json_size])
    binary_size, binary_kind = struct.unpack_from("<II", raw, 20 + json_size)
    binary = raw[28 + json_size:]
    if binary_kind != 0x004E4942 or binary_size != len(binary):
        raise ValueError("Expected one GLB binary chunk")
    if (len(source.get("buffers", [])) != 1 or "uri" in source["buffers"][0]
            or source.get("skins") or source.get("animations")):
        raise ValueError("Only self-contained static GLBs are supported")

    tangent_ids, other_ids = set(), set()
    for model in source["meshes"]:
        for primitive in model["primitives"]:
            if primitive.get("mode", 4) != 4 or primitive.get("targets") or primitive.get("extensions"):
                raise ValueError("Only plain triangle primitives are supported")
            attrs = primitive["attributes"]
            if not {"NORMAL", "TEXCOORD_0"} <= set(attrs):
                raise ValueError("Normal and UV data are required for imported tangents")
            tangent_ids.update([attrs["TANGENT"]] if "TANGENT" in attrs else [])
            other_ids.update(value for key, value in attrs.items() if key != "TANGENT")
            other_ids.add(primitive["indices"])
    if not tangent_ids or tangent_ids & other_ids:
        raise ValueError("Expected exclusively referenced explicit tangent accessors")

    def float_rows(index, width):
        accessor = source["accessors"][index]
        if accessor["componentType"] != 5126 or accessor["type"] != "VEC" + str(width):
            raise ValueError("Expected floating-point normal/tangent vectors")
        view = source["bufferViews"][accessor["bufferView"]]
        start = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
        stride = view.get("byteStride", width * 4)
        return (struct.unpack_from("<" + "f" * width, binary, start + i * stride)
                for i in range(accessor["count"]))

    # Reject bad authored tangent frames before removing their storage. Keeping
    # this check makes the thin-column-rib repair reproducible and prevents the
    # transport step from concealing a geometry/UV regression.
    source_tangent_checks = []
    for model in source["meshes"]:
        for primitive in model["primitives"]:
            attrs = primitive["attributes"]
            if "TANGENT" not in attrs:
                continue
            count = source["accessors"][attrs["NORMAL"]]["count"]
            if source["accessors"][attrs["TANGENT"]]["count"] != count:
                raise ValueError("Incomplete source tangent frames")
            minimum_length, minimum_cross, bad = float("inf"), float("inf"), 0
            for normal, tangent in zip(float_rows(attrs["NORMAL"], 3), float_rows(attrs["TANGENT"], 4)):
                nx, ny, nz = normal
                tx, ty, tz, handedness = tangent
                length_squared = tx * tx + ty * ty + tz * tz
                cx, cy, cz = ny * tz - nz * ty, nz * tx - nx * tz, nx * ty - ny * tx
                cross_squared = cx * cx + cy * cy + cz * cz
                minimum_length = min(minimum_length, length_squared)
                minimum_cross = min(minimum_cross, cross_squared)
                if (not all(math.isfinite(value) for value in normal + tangent)
                        or length_squared <= 1e-8 or cross_squared <= 1e-8
                        or abs(abs(handedness) - 1.0) >= 1e-4):
                    bad += 1
            source_tangent_checks.append({
                "material": source["materials"][primitive["material"]].get("name", ""),
                "vertices": count, "invalid_frames": bad,
                "minimum_tangent_length_squared": minimum_length,
                "minimum_normal_tangent_cross_squared": minimum_cross})
    if any(row["invalid_frames"] for row in source_tangent_checks):
        raise ValueError("Invalid source tangents before packing: " + json.dumps(source_tangent_checks))

    def accessor_digest(document, payload, index):
        accessor = document["accessors"][index]
        if accessor.get("sparse") or "bufferView" not in accessor:
            raise ValueError("Sparse or unbuffered accessors are unsupported")
        view = document["bufferViews"][accessor["bufferView"]]
        components = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[accessor["type"]]
        size = {5120: 1, 5121: 1, 5122: 2, 5123: 2, 5125: 4, 5126: 4}[accessor["componentType"]]
        width = components * size
        stride = view.get("byteStride", width)
        start = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
        end = start + max(0, accessor["count"] - 1) * stride + width
        if (view.get("buffer", 0) != 0 or stride < width or accessor["count"] < 1
                or end > view.get("byteOffset", 0) + view["byteLength"] or end > len(payload)):
            raise ValueError("Accessor exceeds its buffer view")
        canonical = {key: accessor[key] for key in ("componentType", "count", "type")}
        canonical["normalized"] = accessor.get("normalized", False)
        digest = hashlib.sha256(json.dumps(canonical, sort_keys=True).encode())
        for index in range(accessor["count"]):
            offset = start + index * stride
            digest.update(payload[offset:offset + width])
        return digest.hexdigest()

    def view_bytes(document, payload, index):
        view = document["bufferViews"][index]
        start = view.get("byteOffset", 0)
        result = payload[start:start + view["byteLength"]]
        if view.get("buffer", 0) != 0 or len(result) != view["byteLength"]:
            raise ValueError("Invalid embedded buffer view")
        return result

    packed = copy.deepcopy(source)
    keep_accessors = [i for i in range(len(source["accessors"])) if i not in tangent_ids]
    accessor_map = {old: new for new, old in enumerate(keep_accessors)}
    tangent_views = {source["accessors"][i]["bufferView"] for i in tangent_ids}
    keep_views = {source["accessors"][i]["bufferView"] for i in keep_accessors}
    keep_views.update(image["bufferView"] for image in source.get("images", []))
    remove_views = tangent_views - keep_views
    if remove_views != tangent_views:
        raise ValueError("Tangent buffer views are interleaved with retained data")
    view_ids = [i for i in range(len(source["bufferViews"])) if i not in remove_views]
    view_map = {old: new for new, old in enumerate(view_ids)}
    packed_binary = bytearray()
    packed_views = []
    for old in view_ids:
        packed_binary.extend(b"\0" * (-len(packed_binary) % 4))
        view = copy.deepcopy(source["bufferViews"][old])
        view["byteOffset"] = len(packed_binary)
        packed_binary.extend(view_bytes(source, binary, old))
        packed_views.append(view)
    packed_binary.extend(b"\0" * (-len(packed_binary) % 4))
    packed["bufferViews"] = packed_views
    packed["buffers"][0]["byteLength"] = len(packed_binary)
    packed["accessors"] = [copy.deepcopy(source["accessors"][i]) for i in keep_accessors]
    for accessor in packed["accessors"]:
        accessor["bufferView"] = view_map[accessor["bufferView"]]
    for model in packed["meshes"]:
        for primitive in model["primitives"]:
            primitive["attributes"].pop("TANGENT", None)
            primitive["attributes"] = {key: accessor_map[value] for key, value in primitive["attributes"].items()}
            primitive["indices"] = accessor_map[primitive["indices"]]
    for embedded in packed.get("images", []):
        embedded["bufferView"] = view_map[embedded["bufferView"]]

    accessor_checks = []
    for old, new in accessor_map.items():
        before = accessor_digest(source, binary, old)
        after = accessor_digest(packed, packed_binary, new)
        if before != after:
            raise ValueError("Retained accessor data changed")
        accessor_checks.append({"source_accessor": old, "packed_accessor": new,
                                "sha256_before": before, "sha256_after": after})
    image_checks = []
    for index, embedded in enumerate(source.get("images", [])):
        before = hashlib.sha256(view_bytes(source, binary, embedded["bufferView"])).hexdigest()
        after = hashlib.sha256(view_bytes(packed, packed_binary, packed["images"][index]["bufferView"])).hexdigest()
        if before != after:
            raise ValueError("Embedded image bytes changed")
        image_checks.append({"image": index, "sha256_before": before, "sha256_after": after})
    for field in ("materials", "textures", "samplers", "nodes", "scenes", "scene", "extensions", "extensionsUsed", "extensionsRequired"):
        if source.get(field) != packed.get(field):
            raise ValueError("Non-buffer declarations changed: " + field)
    json_bytes = json.dumps(packed, separators=(",", ":"), ensure_ascii=False).encode()
    json_bytes += b" " * (-len(json_bytes) % 4)
    output_size = 12 + 8 + len(json_bytes) + 8 + len(packed_binary)
    output = (struct.pack("<III", 0x46546C67, 2, output_size)
              + struct.pack("<II", len(json_bytes), 0x4E4F534A) + json_bytes
              + struct.pack("<II", len(packed_binary), 0x004E4942) + packed_binary)
    if len(output) >= len(raw):
        raise ValueError("Tangent packing did not reduce file size")
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_bytes(output)
    temporary.replace(path)
    return {"operation": "remove explicit TANGENT attributes and exclusively referenced buffers",
            "runtime_tangents": "regenerated by Godot import with meshes/ensure_tangents enabled (default)",
            "tangent_bit_identity": "not asserted", "bytes_before": len(raw), "bytes_after": len(output),
            "sha256_before": hashlib.sha256(raw).hexdigest(), "sha256_after": hashlib.sha256(output).hexdigest(),
            "removed_tangent_accessors": len(tangent_ids), "removed_buffer_views": len(remove_views),
            "source_tangent_checks": source_tangent_checks,
            "retained_accessor_checks": accessor_checks, "embedded_image_checks": image_checks,
            "unchanged_material_texture_scene_declarations": True}


def finalize(asset_id,lod,builder,metadata):
    objects=[o for o in bpy.context.scene.objects if o.type=="MESH"]
    if not objects:
        raise RuntimeError("No geometry")
    for obj in objects:
        _bake_modifiers(obj)
    # Editable source keeps component meshes; export is one ArrayMesh with
    # material surfaces, suitable for engine MultiMesh construction.
    if lod==0:
        bpy.ops.file.pack_all()
        bpy.context.preferences.filepaths.save_version=0
        bpy.ops.wm.save_as_mainfile(filepath=str(ART/(asset_id+".blend")),compress=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objects: o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.object.join()
    obj=bpy.context.object
    obj.name=asset_id+"_lod"+str(lod)
    bpy.context.scene.cursor.location=(0,0,0)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    # Strip duplicate slots left by joining independently authored roof pieces.
    slots=list(obj.data.materials)
    unique=[]; remap={}
    for i,m in enumerate(slots):
        if m not in unique: unique.append(m)
        remap[i]=unique.index(m)
    indices=[remap[p.material_index] for p in obj.data.polygons]
    obj.data.materials.clear()
    for m in unique: obj.data.materials.append(m)
    for p,idx in zip(obj.data.polygons,indices): p.material_index=idx
    obj.data.calc_loop_triangles()
    points=[obj.matrix_world @ Vector(c) for c in obj.bound_box]
    low=[min(p[i] for p in points) for i in range(3)]
    high=[max(p[i] for p in points) for i in range(3)]
    dims=[high[i]-low[i] for i in range(3)]
    path=RUNTIME/(asset_id+"_lod"+str(lod)+".glb")
    bpy.ops.export_scene.gltf(filepath=str(path),export_format="GLB",
        use_selection=True,export_yup=True,export_apply=True,export_texcoords=True,
        export_normals=True,export_tangents=True,export_animations=False,
        export_draco_mesh_compression_enable=False)
    if asset_id == "basilica" and lod == 0:
        storage_report = compact_tangent_storage(path)
        (ART / "basilica_tangent_pack.json").write_text(json.dumps(storage_report, indent=2) + "\n")
    return {
        "asset_id":asset_id,"lod":lod,"path":str(path.relative_to(ROOT)),
        "res_path":"res://"+str(path.relative_to(ROOT/"prototype")),
        "sha256":hashlib.sha256(path.read_bytes()).hexdigest(),"bytes":path.stat().st_size,
        "triangles":len(obj.data.loop_triangles),"mesh_nodes":1,
        "material_surfaces":len(unique),"bounds_blender_z_up":[low,high],
        "footprint":[round(dims[0],4),round(dims[1],4)],
        "height":round(dims[2],4),"metadata":metadata,
        "collision_boxes":builder.collision_boxes if lod==0 else []
    }


def render(asset_id):
    scene=bpy.context.scene
    scene.render.engine="CYCLES"
    scene.cycles.device="CPU"
    scene.cycles.samples=24
    scene.cycles.use_denoising=False
    scene.render.threads_mode="FIXED"; scene.render.threads=2
    scene.render.resolution_x=1280; scene.render.resolution_y=960
    scene.render.resolution_percentage=100
    scene.world.use_nodes=True
    scene.world.node_tree.nodes["Background"].inputs[0].default_value=(.47,.56,.68,1)
    scene.world.node_tree.nodes["Background"].inputs[1].default_value=.65
    ground=material("WX_Review_Ground",(.17,.15,.115),.98)
    bpy.ops.mesh.primitive_plane_add(size=180,location=(0,0,-.035))
    bpy.context.object.data.materials.append(ground)
    data=bpy.data.lights.new("Review_Sun","SUN")
    data.energy=3.0; data.angle=.12
    light=bpy.data.objects.new("Review_Sun",data); scene.collection.objects.link(light)
    light.rotation_euler=(math.radians(26),math.radians(-22),math.radians(-35))
    camdata=bpy.data.cameras.new("ReviewCamera")
    camera=bpy.data.objects.new("ReviewCamera",camdata); scene.collection.objects.link(camera)
    if asset_id=="taberna":
        camera.location=(11.8,-15.8,9.4); target=Vector((0,-.7,2.0)); lens=40
    elif asset_id=="insula":
        camera.location=(17.2,-22.3,15.3); target=Vector((0,0,4.5)); lens=42
    elif asset_id=="basilica":
        camera.location=(23,-31,20); target=Vector((0,-1.4,4.1)); lens=43
    else:
        camera.location=(8.4,-10.3,8.6); target=Vector((0,0,0)); lens=45
    camera.rotation_euler=(target-camera.location).to_track_quat("-Z","Y").to_euler()
    camera.data.lens=lens
    scene.camera=camera
    scene.view_settings.view_transform="AgX"
    scene.render.filepath=str(ART/(asset_id+"_review.png"))
    bpy.ops.render.render(write_still=True)


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--asset",choices=ASSET_IDS)
    parser.add_argument("--render",action="store_true")
    args=parser.parse_args(sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else [])
    ART.mkdir(parents=True,exist_ok=True); RUNTIME.mkdir(parents=True,exist_ok=True)
    reports=[]
    ids=(args.asset,) if args.asset else ASSET_IDS
    for asset_id in ids:
        for lod in range(3):
            reset_scene()
            b,meta=globals()[asset_id](lod)
            report=finalize(asset_id,lod,b,meta)
            reports.append(report)
            print("WORLD_ARCHITECTURE_ASSET "+json.dumps(report),flush=True)
            if args.render and lod==0:
                render(asset_id)
    previous={}
    manifest_path=ART/"architecture_manifest.json"
    if args.asset and manifest_path.exists():
        previous=json.loads(manifest_path.read_text())
        reports=[r for r in previous.get("assets",[]) if r["asset_id"]!=args.asset]+reports
    manifest={
        "schema_version":1,"generator":"tools/world_art/architecture.py",
        "blender_version":bpy.app.version_string,"unit":"metre","seed":SEED,
        "source_axis":"Z up, front -Y","runtime_axis":"Y up, front +Z",
        "material_source":"Existing original IMPERATHEN procedural PBR maps, tools/art/generate_materials.py",
        "source_model_rights":"Original procedural project geometry; no third-party models",
        "historical_status":"Fictional Roman-inspired modules; not a reconstruction of a documented site",
        "acceptance":{"exported":True,"runtime_import":False,"collision_review":False,
                      "android_performance":False,"visually_reviewed":False},
        "assets":reports
    }
    manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n")
    print("WORLD_ARCHITECTURE_COMPLETE "+str(manifest_path),flush=True)


if __name__=="__main__":
    main()


