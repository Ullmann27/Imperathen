#!/usr/bin/env python3
"""Original, dimensioned frontier architecture for IMPERATHEN's art benchmark.

Run with Blender 4.3+:
    blender --background --factory-startup --python tools/art/build_architecture.py -- --output-dir art/visual_benchmark/assets/architecture

All geometry is authored here, in metres, Z up, entrance toward -Y. These are
art review assets; engine collision, navigation and performance need a separate
engine import. Functions return new objects so the benchmark can place them.
"""
from __future__ import annotations

import argparse
import json
import math
import random
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import box, cylinder, export_asset, material, mesh, reset_scene

SEED = 73122
HOUSE_WIDTH = 6.0
HOUSE_DEPTH = 5.0
FLOOR_Z = 0.38
WALL_TOP = 3.26
RIDGE_Z = 4.86
EAVE_Z = 3.18
ROOF_HALF_WIDTH = 3.42
ROOF_HALF_DEPTH = 2.86


class Geometry:
    """Accumulate repeated detail without one Blender object per tile or board."""

    def __init__(self, name, mat):
        self.name = name
        self.mat = mat
        self.vertices = []
        self.faces = []

    def add(self, vertices, faces):
        start = len(self.vertices)
        self.vertices.extend(tuple(v) for v in vertices)
        self.faces.extend(tuple(start + i for i in f) for f in faces)

    def cuboid(self, centre, dimensions, transform=None, chamfer=0):
        c = Vector(centre)
        dx, dy, dz = (v / 2 for v in dimensions)
        vertices = [Vector((x, y, z)) for x, y, z in (
            (-dx, -dy, -dz), (dx, -dy, -dz), (dx, dy, -dz), (-dx, dy, -dz),
            (-dx, -dy, dz), (dx, -dy, dz), (dx, dy, dz), (-dx, dy, dz),
        )]
        if transform is not None:
            vertices = [transform @ v for v in vertices]
        faces = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4),
                 (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
        # A reflected roof basis changes handedness; keep physical outward normals.
        if transform is not None and transform.determinant() < 0:
            faces = [tuple(reversed(face)) for face in faces]
        self.add([v + c for v in vertices], faces)

    def beam(self, p1, p2, width, depth=None):
        p1, p2 = Vector(p1), Vector(p2)
        direction = p2 - p1
        rotation = direction.to_track_quat('Z', 'Y').to_matrix()
        self.cuboid((p1 + p2) / 2, (width, depth or width, direction.length), rotation)

    def finish(self, bevel=0.0):
        if not self.vertices:
            return None
        obj = mesh(self.name, self.vertices, self.faces, self.mat)
        if bevel:
            modifier = obj.modifiers.new('Softened hand worked edges', 'BEVEL')
            modifier.width = bevel
            modifier.segments = 1
            modifier.affect = 'EDGES'
            modifier.limit_method = 'ANGLE'
        return obj


def materials():
    return {
        'plaster': material('ARCH_Lime_Plaster', (0.72, 0.66, 0.51), roughness=0.91, texture='plaster'),
        'stone': material('ARCH_Limestone', (0.50, 0.49, 0.43), roughness=0.92, texture='limestone'),
        'stone_dark': material('ARCH_Limestone_Damp', (0.39, 0.40, 0.35), roughness=0.96, texture='limestone'),
        'wood': material('ARCH_Oak', (0.25, 0.14, 0.065), roughness=0.84, texture='oak'),
        'wood_light': material('ARCH_Oak_Cut', (0.38, 0.26, 0.14), roughness=0.88, texture='oak'),
        'roof': material('ARCH_Terracotta', (0.55, 0.23, 0.11), roughness=0.88, texture='terracotta'),
        'roof_light': material('ARCH_Terracotta_Light', (0.66, 0.31, 0.17), roughness=0.9, texture='terracotta'),
        'roof_dark': material('ARCH_Terracotta_Dark', (0.42, 0.16, 0.075), roughness=0.9, texture='terracotta'),
        'metal': material('ARCH_Aged_Bronze', (0.23, 0.18, 0.10), roughness=0.54, metallic=0.72, texture='bronze'),
        'rope': material('ARCH_Hemp', (0.46, 0.38, 0.25), roughness=0.96, texture='linen'),
        'water': material('ARCH_Well_Water', (0.028, 0.065, 0.065), roughness=0.24, metallic=0.05),
    }


def objects_since(before):
    return [obj for obj in bpy.context.scene.objects if obj.name not in before]


def ring_segment(geo, inner, outer, z0, z1, a0, a1, segments=3):
    points = []
    for z in (z0, z1):
        for radius in (inner, outer):
            for i in range(segments + 1):
                angle = a0 + (a1 - a0) * i / segments
                points.append((math.cos(angle) * radius, math.sin(angle) * radius, z))
    count = segments + 1
    faces = []
    for i in range(segments):
        faces += [
            (i, i + 1, count + i + 1, count + i),
            (2 * count + i, 3 * count + i, 3 * count + i + 1, 2 * count + i + 1),
            (i, 2 * count + i, 2 * count + i + 1, i + 1),
            (count + i, count + i + 1, 3 * count + i + 1, 3 * count + i),
        ]
    faces += [(0, count, 3 * count, 2 * count),
              (count - 1, 3 * count - 1, 4 * count - 1, 2 * count - 1)]
    geo.add(points, faces)


def stone_box(geo, centre, dimensions, rng, jitter=0.018):
    dx, dy, dz = (v / 2 for v in dimensions)
    cx, cy, cz = centre
    vertices = [(cx+x+rng.uniform(-jitter, jitter),
                 cy+y+rng.uniform(-jitter, jitter),
                 cz+z+rng.uniform(-jitter/2, jitter/2))
                for x, y, z in ((-dx,-dy,-dz),(dx,-dy,-dz),(dx,dy,-dz),(-dx,dy,-dz),
                               (-dx,-dy,dz),(dx,-dy,dz),(dx,dy,dz),(-dx,dy,dz))]
    geo.add(vertices, [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)])


def stone_course(geo, a, b, z, height, thickness, rng, nominal=0.55):
    a, b = Vector(a), Vector(b)
    length = (b-a).length
    axis = (b-a).normalized()
    count = max(1, round(length / nominal))
    step = length / count
    for i in range(count):
        point = a + axis * step * (i + 0.5)
        size = (step-0.018, thickness, height-0.018) if abs(axis.x) > 0.5 else (thickness, step-0.018, height-0.018)
        stone_box(geo, (point.x, point.y, z), size, rng)


def foundation_stones(mats, prefix='House'):
    rng = random.Random(SEED)
    stones = Geometry(prefix+'_Foundation_Masonry', mats['stone'])
    damp = Geometry(prefix+'_Foundation_Damp_Stones', mats['stone_dark'])
    for row in range(2):
        target = damp if row == 0 else stones
        z = 0.095 + row * 0.19
        for a,b in [((-3.0,-2.34),(3.0,-2.34)), ((-3.0,2.34),(3.0,2.34)),
                    ((-2.80,-2.08),(-2.80,2.08)), ((2.80,-2.08),(2.80,2.08))]:
            stone_course(target, a, b, z, 0.19, 0.43, rng, nominal=0.54+0.12*row)
    stones.finish(bevel=0.015)
    damp.finish(bevel=0.012)


def wall_with_openings(name, x0, x1, y0, y1, z0, z1, openings, mat):
    """Build a thick panel with real rectangular through openings, no false black panes."""
    xs = sorted(set([x0,x1]+[v for op in openings for v in op[:2]]))
    zs = sorted(set([z0,z1]+[v for op in openings for v in op[2:]]))
    geo = Geometry(name, mat)
    for left,right in zip(xs,xs[1:]):
        for low,high in zip(zs,zs[1:]):
            if any(a <= (left+right)/2 <= b and c <= (low+high)/2 <= d for a,b,c,d in openings):
                continue
            geo.cuboid(((left+right)/2,(y0+y1)/2,(low+high)/2), (right-left,y1-y0,high-low))
    return geo.finish()


def gable(name, y, thickness, mat):
    # Roof underside above the wall is a triangular infill; front and rear have thickness.
    vertices = []
    for yy in (y-thickness/2, y+thickness/2):
        vertices.extend([(-3,yy,WALL_TOP),(3,yy,WALL_TOP),(0,yy,RIDGE_Z-0.14)])
    return mesh(name, vertices, [(0,1,2),(3,5,4),(0,3,4,1),(1,4,5,2),(2,5,3,0)], mat)


def roof_tile_geometry(prefix, mats, half_width, half_depth, eave, ridge, offset=(0,0,0), rows=7, columns=13):
    """Individual overlapping tegula plates and curved cover tiles, in compact meshes."""
    rng = random.Random(SEED+19)
    groups = [Geometry(prefix+'_Tiles_'+str(i), mats[k]) for i,k in enumerate(('roof','roof_light','roof_dark'))]
    ox,oy,oz = offset
    slope = math.hypot(half_width, ridge-eave)
    angle = math.atan2(ridge-eave, half_width)
    row_step = slope / rows
    column_step = 2 * half_depth / columns
    for side in (-1,1):
        # Local u runs uphill from the eave, v runs along the ridge.
        u = Vector((-side*math.cos(angle),0,math.sin(angle)))
        v = Vector((0,1,0))
        normal = Vector((side*math.sin(angle),0,math.cos(angle)))
        origin = Vector((ox+side*half_width,oy-half_depth,oz+eave))
        for row in range(rows):
            start = row * row_step
            length = row_step + (0.075 if row < rows-1 else 0.015)
            for col in range(columns):
                group = groups[rng.choices((0,1,2),(0.68,0.19,0.13))[0]]
                centre = origin + u*(start+length/2) + v*((col+0.5)*column_step)
                centre += normal * (0.014 + 0.004*row)
                width = column_step - 0.015
                transform = Matrix((u,v,normal)).transposed()
                # A flat pan with a slightly lifted top lip, each one a real mesh tile.
                group.cuboid(centre, (length,width,0.038), transform)
                # Narrow raised borders support a curved cover seam.
                for sign in (-1,1):
                    edge = centre + v*(sign*(width/2-0.018)) + normal*0.028
                    group.cuboid(edge,(length,0.032,0.045),transform)
            # Cover-tile arcs bridge adjacent plates and catch grazing light.
            for col in range(columns+1):
                group = groups[(row+col)%3]
                centre = origin + u*start + v*(col*column_step) + normal*(0.045+0.004*row)
                arc_radius = 0.068 if half_width > 2 else 0.045
                verts=[]
                arc_segments=6
                for end in (0,length):
                    for radius in (arc_radius,arc_radius-0.014):
                        for k in range(arc_segments+1):
                            theta=math.pi*k/arc_segments
                            point=centre+u*end+v*(math.cos(theta)*radius)+normal*(math.sin(theta)*radius)
                            verts.append(point)
                n=arc_segments+1
                faces=[]
                for k in range(arc_segments):
                    faces.extend([(k,k+1,2*n+k+1,2*n+k),
                                  (n+k,3*n+k,3*n+k+1,n+k+1),
                                  (k,n+k,n+k+1,k+1),
                                  (2*n+k,2*n+k+1,3*n+k+1,3*n+k)])
                faces.extend([(0,2*n,3*n,n),(n-1,2*n-1,4*n-1,3*n-1)])
                if side > 0:
                    faces = [tuple(reversed(face)) for face in faces]
                group.add(verts,faces)
    # Ridge caps: hollow half cylinders, split into short overlapping courses.
    cap_geo = Geometry(prefix+'_Ridge_Caps',mats['roof_dark'])
    cap_count=max(4,round(2*half_depth/0.42))
    step=2*half_depth/cap_count
    for i in range(cap_count):
        y0=oy-half_depth+i*step-0.022
        y1=y0+step+0.05
        verts=[]
        n=9
        for yy in (y0,y1):
            for r in (0.15,0.12):
                for k in range(n):
                    theta=math.pi*k/(n-1)
                    verts.append((ox+math.cos(theta)*r,yy,oz+ridge+math.sin(theta)*r+0.015))
        faces=[]
        for k in range(n-1):
            faces += [(k,k+1,2*n+k+1,2*n+k),(n+k,3*n+k,3*n+k+1,n+k+1),
                      (k,n+k,n+k+1,k+1),(2*n+k,2*n+k+1,3*n+k+1,3*n+k)]
        faces += [(0,2*n,3*n,n),(n-1,2*n-1,4*n-1,3*n-1)]
        cap_geo.add(verts,[tuple(reversed(face)) for face in faces])
    for group in groups:
        group.finish()
    cap_geo.finish()


def opening_frame(geo, cx, y, low, high, width):
    geo.cuboid((cx-width/2-0.055,y,(low+high)/2),(.11,.24,high-low+.16))
    geo.cuboid((cx+width/2+0.055,y,(low+high)/2),(.11,.24,high-low+.16))
    geo.cuboid((cx,y,high+.055),(width+.24,.26,.11))
    geo.cuboid((cx,y,low-.065),(width+.28,.34,.13))


def plank_door(mats):
    # Hinge along left jamb; beyond 90 degrees preserves the full 1.12 m passage.
    angle=math.radians(100)
    basis=Matrix.Rotation(angle,3,'Z')
    hinge=Vector((-.575,-2.15,FLOOR_Z+.035))
    boards=Geometry('House_Open_Door_Planks',mats['wood'])
    metal=Geometry('House_Door_Bronze_Straps',mats['metal'])
    for i in range(6):
        local=Vector(((i+.5)*1.12/6,0,1.04))
        boards.cuboid(hinge+basis@local,(1.12/6-.008,.064,2.08),basis)
    for z in (.27,1.73):
        metal.cuboid(hinge+basis@Vector((.52,-.041,z)),(1.10,.022,.055),basis)
        for x in (.09,.32,.65,.94):
            metal.cuboid(hinge+basis@Vector((x,-.059,z)),(.025,.018,.025),basis)
    boards.beam(hinge+basis@Vector((.08,.04,.2)),hinge+basis@Vector((1.0,.04,1.8)),.075,.042)
    boards.finish(bevel=.008)
    metal.finish(bevel=.004)


def shutter(mats, cx, hinge_side, width=.46):
    # Real panels swung toward the facade, separate from the open window recess.
    hinge=Vector((cx+hinge_side*.51,-2.535,1.53))
    angle=math.radians(hinge_side*145)
    transform=Matrix.Rotation(angle,3,'Z')
    wood=Geometry('House_Shutter_'+str(cx)+'_'+str(hinge_side),mats['wood_light'])
    direction=-hinge_side
    for i in range(3):
        centre=Vector((direction*width*(i+.5)/3,0,.46))
        wood.cuboid(hinge+transform@centre,(width/3-.01,.055,.92),transform)
    for z in (.17,.74):
        wood.cuboid(hinge+transform@Vector((direction*width/2,.039,z)),(width,.055,.06),transform)
    wood.finish(bevel=.006)


def build_house():
    before=set(bpy.context.scene.objects.keys())
    mats=materials()
    rng=random.Random(SEED+10)
    foundation_stones(mats)
    front_openings=[(-.69,.69,FLOOR_Z,2.56),(-2.32,-1.28,1.52,2.48),(1.28,2.32,1.52,2.48)]
    wall_with_openings('House_Front_Lime_Wall',-3,3,-2.50,-2.17,FLOOR_Z,WALL_TOP,front_openings,mats['plaster'])
    wall_with_openings('House_Rear_Lime_Wall',-3,3,2.17,2.50,FLOOR_Z,WALL_TOP,[(-.48,.48,1.7,2.5)],mats['plaster'])
    box('House_West_Wall',(-2.84,0,(FLOOR_Z+WALL_TOP)/2),(.32,4.34,WALL_TOP-FLOOR_Z),mats['plaster'],bevel=.012)
    east=wall_with_openings('House_East_Wall',-2.17,2.17,-.16,.16,FLOOR_Z,WALL_TOP,[(-.52,.52,1.52,2.48)],mats['plaster'])
    east.rotation_euler[2]=math.pi/2
    east.location.x=2.84
    east_frame=Geometry('House_East_Window_Frame',mats['wood'])
    opening_frame(east_frame,0,0,1.56,2.43,.90)
    east_frame.cuboid((0,0,1.99),(.045,.08,.89))
    east_frame.cuboid((0,0,2.04),(.90,.08,.045))
    east_frame_obj=east_frame.finish(bevel=.012)
    east_frame_obj.rotation_euler[2]=math.pi/2
    east_frame_obj.location.x=3.02
    gable('House_Front_Gable',-2.335,.33,mats['plaster'])
    gable('House_Rear_Gable',2.335,.33,mats['plaster'])
    timber=Geometry('House_Structural_Timber',mats['wood'])
    # Corner posts, wall plates and the visible pegged front gable truss.
    for x in (-2.94,2.94):
        for y in (-2.47,2.47):
            timber.cuboid((x,y,(FLOOR_Z+WALL_TOP)/2),(.18,.18,WALL_TOP-FLOOR_Z+.12))
        timber.cuboid((x,0,WALL_TOP),(.22,5.35,.23))
    for y in (-2.56,2.56):
        timber.cuboid((0,y,WALL_TOP),(6.10,.18,.22))
        timber.beam((-3.07,y,WALL_TOP+.02),(0,y,RIDGE_Z-.12),.16,.17)
        timber.beam((0,y,RIDGE_Z-.12),(3.07,y,WALL_TOP+.02),.16,.17)
        timber.beam((0,y,WALL_TOP),(0,y,RIDGE_Z-.17),.17,.17)
        timber.beam((-1.7,y,WALL_TOP+.01),(0,y,RIDGE_Z-.35),.11,.13)
        timber.beam((1.7,y,WALL_TOP+.01),(0,y,RIDGE_Z-.35),.11,.13)
    timber.cuboid((0,0,RIDGE_Z-.17),(.21,5.72,.24))
    # Exposed rafters extend under the eaves, consistently pitched with the tiles.
    for i in range(11):
        y=-2.68+i*.536
        for side in (-1,1):
            timber.beam((0,y,RIDGE_Z-.15),(side*3.42,y,EAVE_Z-.10),.115,.15)
    opening_frame(timber,0,-2.40,FLOOR_Z+.02,2.49,1.12)
    for cx in (-1.8,1.8):
        opening_frame(timber,cx,-2.48,1.56,2.43,.90)
        timber.cuboid((cx,-2.36,1.99),(.045,.08,.89))
        timber.cuboid((cx,-2.36,2.04),(.90,.08,.045))
    opening_frame(timber,0,2.42,1.73,2.46,.86)
    timber.finish(bevel=.012)
    # Wood roof boards remain visible beneath the tile edges and inside the house.
    underlay=Geometry('House_Roof_Underboards',mats['wood_light'])
    pitch=math.atan2(RIDGE_Z-EAVE_Z,ROOF_HALF_WIDTH)
    for side in (-1,1):
        u=Vector((-side*math.cos(pitch),0,math.sin(pitch)))
        n=Vector((side*math.sin(pitch),0,math.cos(pitch)))
        basis=Matrix((u,Vector((0,1,0)),n)).transposed()
        slope=math.hypot(ROOF_HALF_WIDTH,RIDGE_Z-EAVE_Z)
        for i in range(17):
            position=Vector((side*ROOF_HALF_WIDTH,0,EAVE_Z-.07))+u*((i+.5)*slope/17)
            underlay.cuboid(position,(slope/17-.008,2*ROOF_HALF_DEPTH-.03,.065),basis)
    underlay.finish()
    roof_tile_geometry('House_Roof',mats,ROOF_HALF_WIDTH,ROOF_HALF_DEPTH,EAVE_Z,RIDGE_Z)
    # Two varied quoin courses at each lower corner and a full paved interior.
    quoins=Geometry('House_Exposed_Quoins',mats['stone'])
    for row in range(5):
        for side in (-1,1):
            for y in (-2.51,2.51):
                length=.54 if row%2==0 else .36
                stone_box(quoins,(side*(3.02-length/2),y,FLOOR_Z+.13+row*.25),(length,.12,.23),rng,.012)
    quoins.finish(bevel=.018)
    floor=Geometry('House_Interior_Flagstones',mats['stone_dark'])
    for xi in range(8):
        for yi in range(6):
            x=-2.64+(xi+.5)*5.28/8
            y=-2.13+(yi+.5)*4.26/6
            floor.cuboid((x,y,FLOOR_Z-.025),(5.28/8-.018,4.26/6-.018,.075))
    floor.finish(bevel=.009)
    box('House_Threshold',(0,-2.38,FLOOR_Z+.015),(1.43,.53,.10),mats['stone'],bevel=.025)
    box('House_Entry_Step_Upper',(0,-2.79,.275),(1.65,.53,.20),mats['stone'],bevel=.035)
    box('House_Entry_Step_Lower',(0,-3.13,.12),(1.92,.51,.24),mats['stone_dark'],bevel=.035)
    plank_door(mats)
    for cx in (-1.8,1.8):
        shutter(mats,cx,-1)
        shutter(mats,cx,1)
    # Small bench and table are visibly inside the opening, not painted darkness.
    interior=Geometry('House_Interior_Furniture',mats['wood_light'])
    for x in (-1.7,-.5):
        for y in (.25,1.05):
            interior.cuboid((x,y,FLOOR_Z+.4),(.09,.09,.8))
    for i in range(5):
        interior.cuboid((-1.1,.17+i*.22,FLOOR_Z+.83),(1.45,.205,.065))
    interior.cuboid((1.93,0,FLOOR_Z+.47),(.5,1.9,.085))
    for y in (-.72,.72):
        interior.cuboid((1.93,y,FLOOR_Z+.23),(.34,.16,.46))
    interior.finish(bevel=.01)
    # Terracotta storage jars use lathed profiles with real neck openings.
    jar(mats,(-2.23,-1.47,FLOOR_Z),.27,.62,'House_Storage_Jar')
    for obj in objects_since(before):
        obj['asset_role']='frontier_house'
        obj['units']='metres'
    return objects_since(before)


def jar(mats, position, radius, height, name):
    profile=[(.0,.44),(.08,.72),(.31,1.0),(.58,.9),(.79,.50),(.94,.37),(1.0,.42)]
    n=16
    vertices=[]
    for z,r in profile:
        for i in range(n):
            a=2*math.pi*i/n
            vertices.append((position[0]+math.cos(a)*radius*r,position[1]+math.sin(a)*radius*r,position[2]+height*z))
    faces=[]
    for row in range(len(profile)-1):
        for i in range(n):
            a=row*n+i; b=row*n+(i+1)%n
            faces.append((a,b,b+n,a+n))
    faces.append(tuple(reversed(range(n))))
    obj=mesh(name,vertices,faces,mats['roof'],smooth=True)
    solid=obj.modifiers.new('Ceramic wall thickness','SOLIDIFY'); solid.thickness=.014
    bevel=obj.modifiers.new('Soft ceramic lip','BEVEL'); bevel.width=.006; bevel.segments=2
    return obj


def build_well():
    before=set(bpy.context.scene.objects.keys())
    mats=materials()
    light=Geometry('Well_Cut_Stone',mats['stone'])
    dark=Geometry('Well_Damp_Stone',mats['stone_dark'])
    for row in range(4):
        for i in range(14):
            angle=2*math.pi*(i+(row%2)*.5)/14
            ring_segment(dark if row==0 else light,.65,1.02,row*.225+.015,(row+1)*.225-.01,
                         angle+.009,angle+2*math.pi/14-.009,segments=2)
    for i in range(12):
        angle=2*math.pi*i/12
        ring_segment(light,.60,1.08,.90,1.05,angle+.01,angle+2*math.pi/12-.01,segments=3)
    light.finish(bevel=.017); dark.finish(bevel=.01)
    cylinder('Well_Still_Water',(0,0,.085),.64,.035,mats['water'],vertices=48)
    timber=Geometry('Well_Oak_Structure',mats['wood'])
    for side in (-1,1):
        timber.cuboid((side*1.18,0,1.20),(.18,.21,2.40))
        timber.beam((side*1.18,0,1.85),(side*.72,0,2.5),.11)
        timber.cuboid((side*1.15,0,.20),(.26,.29,.40))
    timber.cuboid((0,0,2.42),(2.65,.19,.16))
    for y in (-.77,.77):
        timber.cuboid((0,y,2.42),(2.78,.12,.12))
        timber.beam((-1.42,y,2.4),(0,y,3.08),.1)
        timber.beam((0,y,3.08),(1.42,y,2.4),.1)
    timber.cuboid((0,0,3.04),(.14,1.91,.14))
    timber.finish(bevel=.012)
    roof_tile_geometry('Well_Roof',mats,1.45,.94,2.42,3.10,rows=3,columns=7)
    cylinder('Well_Winding_Axle',(0,0,1.74),.092,2.76,mats['wood_light'],vertices=16,rotation=(0,math.pi/2,0))
    for x in (-.24,.24):
        cylinder('Well_Axle_Rope_Stop_'+str(x),(x,0,1.74),.135,.045,mats['wood'],vertices=16,rotation=(0,math.pi/2,0))
    # Close winding turns suggest rope wrapped around the axle; four-sided section is adequate here.
    winding=Geometry('Well_Wound_Rope',mats['rope'])
    turns=11; points=turns*14
    for i in range(points):
        a0=2*math.pi*turns*i/points; a1=2*math.pi*turns*(i+1)/points
        p0=(-.21+.42*i/points,math.cos(a0)*.105,1.74+math.sin(a0)*.105)
        p1=(-.21+.42*(i+1)/points,math.cos(a1)*.105,1.74+math.sin(a1)*.105)
        winding.beam(p0,p1,.018)
    winding.finish()
    cylinder('Well_Hanging_Rope',(.13,-.103,1.18),.012,1.0,mats['rope'],vertices=8)
    crank=Geometry('Well_Crank',mats['wood_light'])
    crank.cuboid((1.43,0,1.56),(.075,.075,.40))
    crank.cuboid((1.56,0,1.36),(.30,.09,.09)); crank.finish(bevel=.012)
    bucket_body=Geometry('Well_Bucket_Staves',mats['wood_light'])
    for i in range(12):
        a=2*math.pi*i/12
        r=.165
        rotation=Matrix.Rotation(a,3,'Z')
        bucket_body.cuboid((.13+math.cos(a)*r,-.10+math.sin(a)*r,.53),(.052,.073,.30),rotation)
    bucket_body.finish(bevel=.004)
    bottom=cylinder('Well_Bucket_Base',(.13,-.10,.385),.17,.025,mats['wood'],vertices=16)
    hoops=Geometry('Well_Bucket_Hoops',mats['metal'])
    for zz in (.43,.64):
        # ring is authored at origin, then translated with its final object.
        ring_segment(hoops,.177,.19,zz-.017,zz+.017,0,2*math.pi,segments=32)
    obj=hoops.finish(); obj.location=(.13,-.10,0)
    handle=Geometry('Well_Bucket_Handle',mats['metal'])
    for side in (-1,1):
        handle.beam((.13+side*.18,-.10,.65),(.13+side*.12,-.10,.80),.018)
    handle.beam((.01,-.10,.80),(.25,-.10,.80),.018); handle.finish()
    for obj in objects_since(before):
        obj['asset_role']='village_well'; obj['units']='metres'
    return objects_since(before)


def build_foundation():
    before=set(bpy.context.scene.objects.keys())
    mats=materials()
    foundation_stones(mats,'Construction')
    frame=Geometry('Construction_Standing_Frame',mats['wood_light'])
    for x,y in [(-2.9,-2.4),(2.9,-2.4),(-2.9,2.4),(2.9,2.4),(-.68,-2.4),(.68,-2.4)]:
        height=2.85 if abs(x)>2 else 2.2
        frame.cuboid((x,y,FLOOR_Z+height/2),(.16,.16,height))
    frame.cuboid((0,2.4,3.23),(5.94,.18,.18))
    frame.cuboid((2.9,0,3.23),(.18,4.9,.18))
    frame.beam((-2.9,2.4,1.60),(-1.7,2.4,3.23),.10)
    frame.beam((2.9,2.4,1.60),(2.9,1.2,3.23),.10)
    frame.cuboid((0,-2.4,2.61),(1.58,.20,.18))
    frame.finish(bevel=.009)
    partial=Geometry('Construction_Partial_Masonry',mats['stone'])
    rng=random.Random(SEED+32)
    for row in range(3):
        for a,b in [((-2.8,2.34),(2.8,2.34)),((2.80,.2),(2.80,2.0))]:
            stone_course(partial,a,b,.50+row*.24,.24,.37,rng,nominal=.54)
    partial.finish(bevel=.017)
    scaffold=Geometry('Construction_Scaffold',mats['wood'])
    for x in (3.33,4.18):
        for y in (-2.1,0,2.1):
            scaffold.cuboid((x,y,1.36),(.11,.11,2.72))
        scaffold.cuboid((x,0,2.60),(.10,4.40,.10))
        scaffold.cuboid((x,0,1.76),(.13,4.50,.13))
    for y in (-2.1,0,2.1):
        scaffold.cuboid((3.75,y,1.76),(1.12,.13,.13))
    for i in range(6):
        scaffold.cuboid((3.29+i*.18,0,1.86),(.17,4.5,.07))
    scaffold.beam((4.18,-2.1,.15),(4.18,0,2.56),.075)
    scaffold.beam((4.18,0,.15),(4.18,2.1,2.56),.075)
    scaffold.beam((3.33,-2.1,.15),(4.18,-2.1,1.7),.075)
    scaffold.finish(bevel=.009)
    supplies=Geometry('Construction_Stacked_Timber',mats['wood_light'])
    for row in range(3):
        for i in range(5):
            supplies.cuboid((-1.4+i*.20,.6,.48+row*.14),(.18,2.5,.12))
    for side in (-1,1):
        supplies.beam((3.75+side*.24,-3.10,.014),(3.75+side*.24,-2.18,2.04),.065)
    for i in range(7):
        t=(i+.5)/7
        y=-3.10+t*.92; z=.014+t*2.026
        supplies.cuboid((3.75,y,z),(.57,.07,.07))
    supplies.finish(bevel=.007)
    # Loose dressed blocks show an active construction site without debris sprites.
    blocks=Geometry('Construction_Spare_Stone',mats['stone'])
    for i in range(9):
        x=-2.0+(i%3)*.48; y=-1.2+(i//3)*.38
        stone_box(blocks,(x,y,.48),(.42,.31,.21),rng,.013)
    blocks.finish(bevel=.012)
    for obj in objects_since(before):
        obj['asset_role']='house_foundation'; obj['units']='metres'
    return objects_since(before)


def verify_house_openings():
    """Geometry-only clearance rays; this does not substitute for engine collision QA."""
    bpy.context.view_layer.update()
    graph = bpy.context.evaluated_depsgraph_get()
    samples = [('door', x, z) for x in (-.53, 0.0, .53) for z in (.52, 1.4, 2.36)]
    samples += [('window', cx + dx, z) for cx in (-1.8, 1.8) for dx in (-.22, .22) for z in (1.8, 2.22)]
    failures = []
    for label, x, z in samples:
        hit, location, normal, face, obj, matrix = bpy.context.scene.ray_cast(
            graph, Vector((x, -3.1, z)), Vector((0, 1, 0)), distance=1.15)
        if hit:
            failures.append({'opening': label, 'x': x, 'z': z, 'hit': obj.name})
    if failures:
        raise RuntimeError('Architectural passage rays blocked: ' + json.dumps(failures))
    return {'geometry_rays_clear': len(samples), 'door_frame_clear_width_m': 1.12,
            'door_frame_clear_height_m': 2.09, 'engine_collision_tested': False}


def metric(objects):
    vertices=triangles=0
    components=0
    mesh_objects=[obj for obj in objects if obj.type=='MESH']
    dependency_graph=bpy.context.evaluated_depsgraph_get()
    low=Vector((math.inf,math.inf,math.inf)); high=Vector((-math.inf,-math.inf,-math.inf))
    for obj in mesh_objects:
        evaluated=obj.evaluated_get(dependency_graph)
        data=evaluated.to_mesh()
        data.calc_loop_triangles(); vertices+=len(data.vertices); triangles+=len(data.loop_triangles)
        parents=list(range(len(data.vertices)))
        def find_component(index):
            while parents[index] != index:
                parents[index] = parents[parents[index]]
                index = parents[index]
            return index
        for edge in data.edges:
            first,second=(find_component(index) for index in edge.vertices)
            parents[first]=second
        volumes={}
        for triangle in data.loop_triangles:
            a,b,c=(data.vertices[index].co for index in triangle.vertices)
            component=find_component(triangle.vertices[0])
            volumes[component]=volumes.get(component,0.0)+a.dot(b.cross(c))/6
        components+=len(volumes)
        if any(volume < -1e-8 for volume in volumes.values()):
            evaluated.to_mesh_clear()
            raise RuntimeError('Inward-facing closed mesh component: '+obj.name)
        for corner in obj.bound_box:
            world=obj.matrix_world@Vector(corner)
            for i in range(3):
                low[i]=min(low[i],world[i]); high[i]=max(high[i],world[i])
        evaluated.to_mesh_clear()
    return {'source_mesh_objects':len(mesh_objects),'evaluated_vertices':vertices,'evaluated_triangles':triangles,
            'closed_component_orientation_checks':components,'negative_volume_components':0,
            'bounds_min_m':list(low),'bounds_max_m':list(high),'dimensions_m':list(high-low),
            'material_names':sorted({slot.material.name for o in mesh_objects for slot in o.material_slots if slot.material})}


def render_review(asset_id, output_dir):
    """Neutral, reproducible CPU art-review image, explicitly not a game capture."""
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.device = 'CPU'
    scene.cycles.samples = 48
    scene.cycles.use_denoising = False
    scene.cycles.use_preview_denoising = False
    scene.render.threads_mode = 'FIXED'
    scene.render.threads = 4
    scene.render.resolution_x = 1280
    scene.render.resolution_y = 960
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = 'PNG'
    scene.view_settings.view_transform = 'AgX'
    world = bpy.data.worlds.new('Architecture review neutral sky')
    world.use_nodes = True
    world.node_tree.nodes['Background'].inputs['Color'].default_value = (.45, .56, .68, 1)
    world.node_tree.nodes['Background'].inputs['Strength'].default_value = .45
    scene.world = world
    bpy.ops.object.light_add(type='AREA', location=(-3, -4, 10))
    light = bpy.context.object
    light.data.energy = 1700
    light.data.shape = 'DISK'
    light.data.size = 6
    light.rotation_euler = (Vector((0, 0, 1.7)) - light.location).to_track_quat('-Z', 'Y').to_euler()
    bpy.ops.object.light_add(type='SUN', location=(6, 4, 9))
    bpy.context.object.data.energy = 1.5
    bpy.context.object.data.angle = .16
    bpy.context.object.rotation_euler = (math.radians(30), math.radians(-25), math.radians(-20))
    bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -.04))
    ground = material('Architecture review ground', (.32, .30, .24), roughness=.9)
    bpy.context.object.data.materials.append(ground)
    well = asset_id == 'village_well'
    bpy.ops.object.camera_add(location=(5, -7, 5) if well else (9, -12, 8))
    camera = bpy.context.object
    camera.rotation_euler = (Vector((0, 0, 1.5 if well else 2)) - camera.location).to_track_quat('-Z', 'Y').to_euler()
    camera.data.type = 'ORTHO'
    camera.data.ortho_scale = 6.2 if well else 11.5
    scene.camera = camera
    path = Path(output_dir) / f'{asset_id}_review.png'
    scene.render.filepath = str(path.resolve())
    bpy.ops.render.render(write_still=True)
    return {'file': path.name, 'renderer': 'Blender Cycles CPU', 'samples': 48,
            'width': 1280, 'height': 960, 'game_runtime_capture': False}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir',type=Path,default=Path(__file__).resolve().parents[2]/'art/visual_benchmark/assets/architecture')
    parser.add_argument('--asset',choices=('all','house','well','foundation'),default='all')
    parser.add_argument('--render-previews',action='store_true',help='Render neutral Blender review PNGs; no engine capture implied.')
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    args.output_dir.mkdir(parents=True,exist_ok=True)
    builds={'house':('frontier_house',build_house),'well':('village_well',build_well),
            'foundation':('house_foundation',build_foundation)}
    report={'authorship':'Original procedural geometry authored for IMPERATHEN; no third-party model or texture downloads.',
            'seed':SEED,'coordinate_system':'metres, Z-up, entrance -Y, ground pivot at origin',
            'validation_boundary':'Blender geometry/export only; Unreal import, navigation, collision and hardware performance unverified.',
            'assets':{}}
    for key,(asset_id,builder) in builds.items():
        if args.asset not in ('all',key):
            continue
        reset_scene()
        objects=builder()
        report['assets'][asset_id]=metric(objects)
        if key == 'house':
            report['assets'][asset_id]['openings'] = verify_house_openings()
        export_asset(asset_id,objects,args.output_dir)
        if args.render_previews:
            report['assets'][asset_id]['review_image'] = render_review(asset_id,args.output_dir)
        print('ARCHITECTURE_ASSET',json.dumps({'asset_id':asset_id,**report['assets'][asset_id]}))
    path=args.output_dir/'architecture_metrics.json'
    path.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print('ARCHITECTURE_REPORT',str(path.resolve()))


if __name__=='__main__':
    main()
