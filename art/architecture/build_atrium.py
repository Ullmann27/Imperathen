"""Build the original walk-in tetrastyle courtyard house for the Italia village."""
import math
from pathlib import Path
import random
import sys
from tempfile import TemporaryDirectory

import bpy
from mathutils import Vector

SOURCE = Path(__file__).resolve().parent
ROOT = SOURCE.parents[1]
sys.path[:0] = [str(SOURCE), str(SOURCE.parent / "landscape")]
from atrium_materials import SWATCHES, material
from build_settlements import House


class Domus(House):
    def add(self, points, boundaries, mat, smooth=False):
        slot=list(SWATCHES).index(mat)
        for polygon in boundaries:
            face=[Vector(points[i]) for i in polygon]
            if len(face)==4 and mat in ("intonaco","lime","oxide","paving","mosaic"):
                # Limit texture stretch over broad walls and the floor without
                # introducing material changes. Preserve quads across shared edges.
                steps_a=math.ceil(max((face[1]-face[0]).length,(face[2]-face[3]).length)/1.85)
                steps_b=math.ceil(max((face[3]-face[0]).length,(face[2]-face[1]).length)/1.85)
                if steps_a>1 or steps_b>1:
                    def at(u,v):
                        return face[0].lerp(face[1],u).lerp(face[3].lerp(face[2],u),v)
                    for i in range(steps_a):
                        for j in range(steps_b):
                            patch=[at(i/steps_a,j/steps_b),at((i+1)/steps_a,j/steps_b),
                                   at((i+1)/steps_a,(j+1)/steps_b),at(i/steps_a,(j+1)/steps_b)]
                            self.patch(patch,slot,mat,smooth)
                    continue
            self.patch(face,slot,mat,smooth)

    def patch(self,face,slot,mat,smooth):
        normal=(face[1]-face[0]).cross(face[2]-face[0]).normalized()
        if normal.length_squared<.95:
            return
        up=Vector((0,0,1)) if abs(normal.z)<.96 else Vector((0,1,0))
        if mat in ("beam","cedar"):
            up=max((face[(i+1)%len(face)]-p for i,p in enumerate(face)),key=lambda edge:edge.length_squared).normalized()
        v=(up-normal*up.dot(normal)).normalized()
        u=v.cross(normal)
        projection=[(p.dot(u),p.dot(v)) for p in face]
        xs,ys=zip(*projection)
        dx,dy=max(xs)-min(xs),max(ys)-min(ys)
        density=max(.62,dx,dy)
        if mat in ("intonaco","oxide","lime"):
            density=max(density,1.30)
        # A material's grain stays in the same physical proportion on narrow
        # lintels and thick walls. Offset repeated samples inside their swatch.
        x0,y0=min(xs),min(ys)
        center=sum(face,Vector())/len(face)
        phase=.5+.46*math.sin(center.x*3.1+center.y*5.7+center.z*2.7)
        u0=(1-dx/density)*phase
        v0=(1-dy/density)*(1-phase)
        tex=[((slot%4+.025+.95*(u0+(a-x0)/density))/4,
              (slot//4+.025+.95*(v0+(b-y0)/density))/4) for a,b in projection]
        offset=len(self.vertices)
        self.vertices.extend(tuple(p) for p in face)
        self.faces.append(tuple(range(offset,offset+len(face))))
        self.uvs.append(tex)
        self.smoothing.append(smooth)

    def ring(self, center, radius, wire, mat, axis=(0,1,0), steps=12):
        axis=Vector(axis).normalized()
        horizontal=axis.cross(Vector((0,0,1))).normalized()
        center=Vector(center)
        points=[center+radius*(horizontal*math.cos(i*math.tau/steps)+Vector((0,0,1))*math.sin(i*math.tau/steps))
                for i in range(steps)]
        for i in range(steps):
            self.beam(points[i],points[(i+1)%steps],wire,mat,5)

    def cover_tile(self, start, end, width, mat):
        """Overlapping hollow imbrex with a thick, visible semicircular lip."""
        start,end=Vector(start),Vector(end)
        axis=(end-start).normalized()
        side=Vector((axis.y,-axis.x,0)).normalized()
        vertical=side.cross(axis).normalized()
        if vertical.z<0:
            vertical=-vertical
            side=-side
        section=[side*math.cos(i*math.pi/4)+vertical*math.sin(i*math.pi/4) for i in range(5)]
        points=[center+direction*r for center,r in ((start,width*.87),(end,width),(end,width*.72)) for direction in section]
        faces=[(i,i+5,i+6,i+1) for i in range(4)] + [(5+i,10+i,11+i,6+i) for i in range(4)]
        self.add(points,faces,mat)


def box_between(g, start, end, width, depth, mat):
    """Rectangular rafter along a sloping line, kept in one batched mesh."""
    a,b=Vector(start),Vector(end)
    axis=(b-a).normalized()
    side=Vector((-axis.y,axis.x,0)).normalized()*width/2
    up=axis.cross(side).normalized()*depth/2
    corners=[a-side-up,a+side-up,a+side+up,a-side+up]
    g.prism(corners,b-a,mat)


def facade(g):
    # Original front wall and its collider keep the same center opening.
    for s in (-1,1):
        left,right=(.92,5.5)
        window=3.46
        for a,b,bottom,top in ((left,window-.59,0,3.45),(window+.59,right,0,3.45),
                               (window-.59,window+.59,0,1.67),(window-.59,window+.59,2.53,3.45)):
            g.box(s*(a+b)/2,-4.90,bottom,b-a,.32,top-bottom,"intonaco")
        g.box(s*3.21,-5.065,.34,4.58,.034,.80,"oxide")
        for z,thick,mat in ((1.12,.036,"lime"),(1.195,.046,"ochre"),(1.26,.026,"oxide")):
            g.box(s*3.21,-5.089,z,4.58,.028,thick,mat)
        # Alternating travertine blocks and chipped dark footings in a shallow mortar bed.
        for row in range(2):
            n=6 if row==0 else 7
            width=(5.5-.92)/n
            for i in range(n):
                x=s*(.92+(i+.5)*width)
                g.box(x,-5.081,.012+row*.17,width-.023,.094,.158,
                      "tuff" if (i+row)%3 else "traver")
        win_x=s*window
        g.box(win_x,-5.09,1.57,1.40,.29,.105,"traver")
        g.box(win_x,-5.075,2.525,1.46,.24,.135,"traver")
        for sign in (-1,1):
            g.box(win_x+sign*.57,-4.98,1.65,.072,.18,.89,"cedar")
        for i in range(5):
            x=win_x+(i-2)*.208
            g.beam((x,-4.945,1.67),(x,-4.945,2.53),.020,"iron",6)
        for z in (1.94,2.28):
            g.beam((win_x-.59,-4.95,z),(win_x+.59,-4.95,z),.018,"iron",6)
        # Boarded shutter swung flat against the plaster, with strap hinges and pintles.
        shutter_x=win_x+s*.92
        for i in range(4):
            g.box(shutter_x+(i-1.5)*.145,-5.125,1.69,.138,.064,.81,"cedar")
        for z in (1.83,2.31):
            g.box(shutter_x,-5.168,z,.58,.033,.056,"iron")
            for i in (-1,1):
                x=shutter_x+i*.20
                g.beam((x,-5.18,z+.027),(x,-5.204,z+.027),.019,"bronze",7)
        # Entrance jambs and stepped lintel, bound into the street facade.
        for course in range(6):
            g.box(s*1.075,-5.088,.11+course*.411,.307,.25,.40,"traver" if course%3 else "tuff")
        for z,w,h in ((.02,.39,.16),(2.52,.37,.12),(2.64,.42,.11)):
            g.box(s*1.07,-5.09,z,w,.34,h,"traver")
        # Door halves stand open along the inner fauces walls. No panel crosses the path.
        for i in range(6):
            g.box(s*.922,-4.86+i*.145,.10,.082,.140,2.46,"cedar")
        for z in (.30,1.16,2.25):
            g.box(s*.87,-4.50,z,.044,.83,.09,"iron")
            for y in (-4.76,-4.50,-4.24):
                g.beam((s*.86,y,z+.04),(s*.832,y,z+.04),.022,"bronze",7)
        g.beam((s*.87,-4.20,1.46),(s*.824,-4.20,1.46),.043,"bronze",9)
        g.ring((s*.814,-4.20,1.399),.058,.012,"bronze",axis=(1,0,0))
        g.box(s*1.03,-3.70,0,.20,2.10,2.65,"intonaco")
    g.box(0,-4.90,2.65,2.15,.45,.80,"intonaco")
    for z,width,h,mat in ((2.72,2.42,.15,"traver"),(2.866,2.54,.075,"ochre"),(2.942,2.63,.11,"traver")):
        g.box(0,-5.105,z,width,.37,h,mat)
    # Flush worn threshold, dark contrasting stone border and a narrow rain groove.
    g.box(0,-4.98,.066,1.83,.60,.047,"traver")
    for x in (-.65,0,.65):
        g.box(x,-5.186,.111,.018,.179,.003,"basalt")
    g.box(0,-5.112,3.295,11.05,.13,.115,"traver")
    g.box(0,-5.12,3.406,11.20,.22,.090,"lime")


def jar(g,x,y,z,scale):
    rings=[(.13,0),(.14,.09),(.28,.34),(.31,.53),(.24,.66),(.111,.76),(.105,.88),(.15,.90),(.148,.95),(.098,.95),(.093,.85)]
    points=[]
    segments=12
    for radius,height in rings:
        for i in range(segments):
            a=i*math.tau/segments
            points.append((x+scale*radius*math.cos(a),y+scale*radius*math.sin(a),z+scale*height))
    faces=[]
    for k in range(len(rings)-1):
        for j in range(segments):
            nxt=(j+1)%segments
            faces.append((k*segments+j,k*segments+nxt,(k+1)*segments+nxt,(k+1)*segments+j))
    g.add(points,faces,"tegula")
    for sign in (-1,1):
        path=[(.105,.83),(.22,.83),(.29,.74),(.26,.63)]
        for (a,b),(c,d) in zip(path,path[1:]):
            g.beam((x+sign*a*scale,y,z+b*scale),(x+sign*c*scale,y,z+d*scale),.032*scale,"fired",6)


def court(g):
    for x in (-5.35,5.35):
        g.box(x,0,0,.30,10.10,3.45,"intonaco")
        g.box(x*.98,0,.11,.24,9.76,.95,"oxide")
    g.box(0,4.93,0,10.8,.25,3.45,"intonaco")
    g.box(0,4.78,.07,10.5,.09,.97,"oxide")
    # Red-and-ochre field panels divide the garden-side wall into human-scale bays.
    for x in (-3.87,-1.95,0,1.95,3.87):
        g.box(x,4.755,1.21,1.57,.071,1.71,"oxide")
        # Contrasting lime fillets and a hand-modelled palmette panel painted on each bay.
        for z in (1.58,2.51):
            g.box(x,4.706,z,1.26,.014,.014,"ochre")
        for sign in (-1,1):
            for j in range(3):
                leaf=[(x,4.695,1.87),(x+sign*(.13+.11*j),4.695,1.94+.15*j),
                      (x+sign*(.09+.07*j),4.695,2.08+.14*j)]
                g.prism(leaf,(0,.009,0),"ochre")
            g.box(x+sign*.69,4.709,1.29,.026,.018,1.54,"ochre")
        for z in (1.292,2.806):
            g.box(x,4.707,z,1.41,.020,.027,"ochre")
    g.box(0,0,.0,10.8,9.9,.065,"paving")
    g.box(0,-3.47,.065,1.70,2.47,.018,"mosaic")
    # Walkable polished pavement surrounds the shallow catch basin.
    for x in (-1.72,1.72):
        g.box(x,0,.065,.37,4.10,.020,"mosaic")
    for y in (-1.92,1.92):
        g.box(0,y,.065,3.09,.32,.020,"mosaic")
    g.box(0,0,.075,2.81,3.30,.042,"water")
    for s in (-1,1):
        for i in range(6):
            g.box(s*1.52,-1.51+i*.606,.065,.22,.595,.182,"traver")
        for i in range(5):
            g.box(-1.29+i*.645,s*1.75,.065,.636,.23,.182,"traver")
    for x in (-2,2):
        for y in (-2.15,2.15):
            g.box(x,y,.066,.55,.55,.151,"tuff")
            for z,h,r0,r1,mat in ((.21,.10,.26,.24,"traver"),(.304,.11,.228,.216,"traver"),
                                   (.41,2.31,.203,.166,"lime"),(2.715,.075,.176,.188,"ochre"),
                                   (2.785,.10,.18,.222,"traver"),(2.884,.083,.224,.254,"lime")):
                g.beam((x,y,z),(x,y,z+h),r0,mat,16,r1)
            g.box(x,y,2.961,.52,.52,.13,"traver")
    # Wall bench and two storage jars sit against the rear wall outside the passage.
    for x in (-3.86,-2.41):
        g.box(x,4.08,.066,.23,.53,.39,"tuff")
    g.box(-3.13,4.09,.449,1.94,.56,.105,"traver")
    jar(g,2.91,4.18,.066,.97)
    jar(g,3.45,4.15,.066,.76)
    # Architraves sit on all four column capitals; rafters bear on this ring.
    for y in (-2.15,2.15):
        g.box(0,y,3.077,4.53,.24,.214,"beam")
    for x in (-2,2):
        g.box(x,0,3.081,.23,4.53,.202,"beam")


def clip_width(polygon, limit, keep_left):
    result=[]
    previous=polygon[-1]
    def inside(p):
        return p[0]<=limit if keep_left else p[0]>=limit
    for current in polygon:
        if inside(current)!=inside(previous):
            t=(limit-previous[0])/(current[0]-previous[0])
            result.append((limit,previous[1]+(current[1]-previous[1])*t))
        if inside(current):
            result.append(current)
        previous=current
    return result


def roof(g):
    outer=[(-5.65,-5.15,3.72),(5.65,-5.15,3.72),(5.65,5.15,3.72),(-5.65,5.15,3.72)]
    inner=[(-1.83,-1.96,3.19),(1.83,-1.96,3.19),(1.83,1.96,3.19),(-1.83,1.96,3.19)]
    rng=random.Random(419)
    for i in range(4):
        j=(i+1)%4
        a,b,c,d=map(Vector,(outer[i],outer[j],inner[j],inner[i]))
        direction=(b-a).normalized()
        start,end=(a+b)/2,(c+d)/2
        outer_width,inner_width=(b-a).length/2,(c-d).length/2
        def extent(t):
            return (1-t)*outer_width+t*inner_width
        def surface(x,t):
            return start.lerp(end,t)+direction*x
        g.prism([a,b,c,d],(0,0,-.101),"cedar")
        # Separate tegula pans, clipped at the diagonal hips. Long axes keep a
        # consistent spacing from the outer roof edge to the compluvium opening.
        n=math.ceil(outer_width/.51)
        pitch=outer_width/n
        for row in range(7):
            t0,t1=row/7,(row+1)/7
            for k in range(-n,n):
                left,right=k*pitch,(k+1)*pitch
                contour=[(-extent(t0),t0),(extent(t0),t0),(extent(t1),t1),(-extent(t1),t1)]
                contour=clip_width(contour,left+.007,False)
                if len(contour)>=3:
                    contour=clip_width(contour,right-.007,True)
                if len(contour)>=3:
                    points=[surface(x,t)+Vector((0,0,.037+.032*(t-t0)/(t1-t0))) for x,t in contour]
                    g.prism(points,(0,0,-.035),rng.choice(("tegula","tegula","fired")))
                stop=min(t1,(outer_width-abs(left))/(outer_width-inner_width))
                if stop>t0+.008:
                    g.cover_tile(surface(left,t0)+Vector((0,0,.053)),
                                 surface(left,stop)+Vector((0,0,.072)),.069,"fired")
        # The timber underside is readable from the entrance passage and court.
        for k in range(-n+1,n,2):
            x=k*pitch
            stop=min(1.0,(outer_width-abs(x))/(outer_width-inner_width))
            if stop>.08:
                box_between(g,surface(x,0)-Vector((0,0,.11)),surface(x,stop)-Vector((0,0,.11)),.13,.19,"beam")
        box_between(g,a-Vector((0,0,.136)),b-Vector((0,0,.136)),.23,.207,"beam")
        box_between(g,c-Vector((0,0,.085)),d-Vector((0,0,.085)),.18,.17,"cedar")
        # Cap the four outer edges and central diagonal junctions with terracotta.
        for p in range(9):
            g.cover_tile(a.lerp(b,p/9)+Vector((0,0,.043)),
                         a.lerp(b,(p+1)/9)+Vector((0,0,.058)),.105,"tegula")
        g.cover_tile(a+Vector((0,0,.08)),d+Vector((0,0,.08)),.12,"fired")


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    g=Domus()
    facade(g)
    court(g)
    roof(g)
    with TemporaryDirectory() as temp:
        g.to_mesh("Domus_tetrastyle",material(Path(temp)))
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/"atrium_house.blend"),compress=True)
    bpy.ops.export_scene.gltf(filepath=str(ROOT/"prototype/assets/architecture/atrium_house.glb"),
                              export_format="GLB",export_animations=False)

if __name__=="__main__":
    build()
