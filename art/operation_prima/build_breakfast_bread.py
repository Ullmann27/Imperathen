"""Blender 4.0.2: author the I-01 serving board and scored loaf (metres)."""
import argparse
import math
from pathlib import Path
import struct
import sys
import zlib

import bpy
import numpy as np
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[2]
BUILD = ROOT / "artifacts/viva-bread-bake"
CELLS = ((0, 0, 512, 512), (512, 0, 512, 256), (512, 256, 512, 256))
NAMES = ("prima_bread_board", "prima_bread_loaf", "prima_bread_cut")
WIDTH, HEIGHT = 1024, 512
CX, CY = .02655, -.0234


def png(path, pixels):
    h, w, channels = pixels.shape
    def chunk(tag, data):
        return (struct.pack(">I", len(data)) + tag + data
                + struct.pack(">I", zlib.crc32(tag + data)))
    scan = b"".join(b"\x00" + row.tobytes() for row in pixels)
    path.write_bytes(b"\x89PNG\r\n\x1a\n" +
                     chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, {3: 2, 1: 0}[channels], 0, 0, 0)) +
                     chunk(b"IDAT", zlib.compress(scan, 9)) + chunk(b"IEND", b""))


def noise(rng, u, v, nx, ny):
    grid = rng.uniform(-1, 1, (ny + 1, nx + 1))
    x, y = u * nx, v * ny
    ix, iy = x.astype(int), y.astype(int)
    fx, fy = x - ix, y - iy
    fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    return ((1-fy) * ((1-fx)*grid[iy, ix] + fx*grid[iy, ix+1]) +
            fy * ((1-fx)*grid[iy+1, ix] + fx*grid[iy+1, ix+1]))


def bake_maps():
    rng = np.random.default_rng(5801)
    out = {key: np.zeros((HEIGHT, WIDTH, channels), np.uint8)
           for key, channels in (("albedo", 3), ("normal", 3), ("roughness", 1))}
    for tile, (x0, y0, w, h) in enumerate(CELLS):
        v, u = np.mgrid[0:h, 0:w]
        u, v = (u+.5)/w, (v+.5)/h
        n = noise(rng, u, v, 7, 6)
        speckle = noise(rng, u, v, 86, 58)
        grit = rng.uniform(-1, 1, (h, w))
        if tile == 0:
            grain = np.sin(2*math.pi*(v*32 + 1.8*noise(rng,u,v,3,5) + .55*np.sin(u*7)))
            fibre = noise(rng,u,v,24,125)
            shade = 15*n + 9*grain + 16*fibre + 4*grit
            base, tint = (132,88,52), (1,.81,.55)
            relief = .65*grain + .9*fibre + .12*grit
            rough = 188 + 17*n + 13*fibre
        elif tile == 1:
            crust = noise(rng,u,v,31,21)
            flour = np.clip((n+.45*crust+.22*grit-.18)*1.2,0,1)
            pores = np.clip((-speckle-.40)*2.2,0,1)
            shade = 20*n + 15*crust + 8*grit + 37*flour - 26*pores
            base, tint = (156,87,37), (1,1.10,.99)
            relief = 1.5*crust + .8*speckle + .18*grit - 1.1*pores
            rough = 193 + 26*flour + 14*speckle
        else:
            pores = np.clip((-speckle-.30)*2.4,0,1)
            shade = 12*n + 22*speckle - 48*pores + 8*grit - 45*abs(2*u-1)**3
            base, tint = (189,136,77), (1,.92,.63)
            relief = 1.1*speckle + .2*grit - 2.2*pores
            rough = 224 + 13*n
        rgb = np.asarray(base) + shade[...,None]*np.asarray(tint)
        dy, dx = np.gradient(relief)
        normals = np.stack((-dx*.6, dy*.6, np.ones_like(dx)), axis=-1)
        normals /= np.linalg.norm(normals, axis=-1, keepdims=True)
        sl = np.s_[y0:y0+h, x0:x0+w]
        out["albedo"][sl] = np.clip(rgb,0,255).astype(np.uint8)
        out["normal"][sl] = np.round((normals+1)*127.5).astype(np.uint8)
        out["roughness"][sl] = np.clip(rough,0,255).astype(np.uint8)[...,None]
    images = {}
    for key, data in out.items():
        path = BUILD / ("Viva_Breakfast_" + key + ".png")
        png(path, data)
        image = bpy.data.images.load(str(path))
        image.name = path.stem
        if key != "albedo":
            image.colorspace_settings.name = "Non-Color"
        image.pack()
        image.filepath = "//maps/" + path.name
        images[key] = image
    return images


def surface(name, images):
    mat = bpy.data.materials.new("INT_" + name)
    mat.use_nodes = True
    tree = mat.node_tree
    bsdf = tree.nodes.get("Principled BSDF")
    bsdf.inputs["Specular IOR Level"].default_value = .32
    for key, socket in (("albedo","Base Color"), ("roughness","Roughness"), ("normal","Normal")):
        node = tree.nodes.new("ShaderNodeTexImage")
        node.image = images[key]
        if key == "normal":
            normal = tree.nodes.new("ShaderNodeNormalMap")
            tree.links.new(node.outputs["Color"], normal.inputs["Color"])
            tree.links.new(normal.outputs["Normal"], bsdf.inputs[socket])
        else:
            tree.links.new(node.outputs["Color"], bsdf.inputs[socket])
    return mat


def uv(tile, point):
    x, y, w, h = CELLS[tile]
    pad = 8
    return ((x + pad + point[0]*(w-2*pad))/WIDTH,
            1 - (y + h - pad - point[1]*(h-2*pad))/HEIGHT)


def part(name, vertices, faces, origin, collection, materials):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([tuple(Vector(p)-Vector(origin)) for p in vertices], [], [f[0] for f in faces])
    mesh.update()
    for mat in materials:
        mesh.materials.append(mat)
    layer = mesh.uv_layers.new(name="BreakfastAtlas")
    for poly, (_, tile, uvs, smooth) in zip(mesh.polygons, faces):
        poly.material_index = tile
        poly.use_smooth = smooth
        for loop, coord in zip(poly.loop_indices, uvs):
            layer.data[loop].uv = uv(tile, coord)
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    obj.location = origin
    return obj


def board(collection, materials):
    n = 32
    vertices, faces = [], []
    radii = ((.73,.012),(.88,.012),(.953,.0162),(.986,.017),(1,.0128),(.966,.0001))
    rx, ry = .232, .243
    for radius, z in radii:
        for j in range(n):
            a = math.tau * j/n
            irregular = 1+.0035*math.sin(3*a+.3)+.002*math.sin(9*a)
            vertices.append((CX+rx*radius*irregular*math.cos(a), CY+ry*radius*irregular*math.sin(a), z))
    def planar(i):
        x,y,_ = vertices[i]
        return (.5 + .49*(x-CX)/rx, .5 + .49*(y-CY)/ry)
    top = tuple(range(n))
    faces.append((top,0,[planar(i) for i in top],False))
    for k in range(len(radii)-1):
        for j in range(n):
            h = (j+1)%n
            ids = (k*n+j,(k+1)*n+j,(k+1)*n+h,k*n+h)
            coords = ([planar(i) for i in ids] if k<3 else
                      [(j/n, .1*k), (j/n,.1*(k+1)),((j+1)/n,.1*(k+1)),((j+1)/n,.1*k)])
            faces.append((ids,0,coords,True))
    bottom = tuple(reversed(range(len(vertices)-n,len(vertices))))
    faces.append((bottom,0,[planar(i) for i in bottom],False))
    return part("ServingBoard", vertices, faces, (CX,CY,0), collection, materials)


def loaf(collection, materials):
    n = 16
    scores = (-.54,-.025,.49)
    rings = sorted([-.981,-.92,-.79,.76,.91,.981] +
                   [c+ds for c in scores for ds in (-.13,-.058,-.027,.027,.058,.13)])
    vertices, faces = [], []
    for s in rings:
        r = (1-s*s)**.55
        for j in range(n):
            a = -math.pi + math.tau*j/n
            side, up = math.sin(a), math.cos(a)
            top = max(up,0)
            nearest = min(scores, key=lambda c: abs(s-c))
            dist = abs(s-nearest)
            length_factor = max(.08, 1 - (a/.83)**2)
            shaped = nearest + (s-nearest)*length_factor if dist < .03 else s
            groove = math.exp(-(dist/.047)**2)
            lip = math.exp(-((dist-.065)/.034)**2)
            x = CX + .172*shaped + .026*r*side
            y = CY + .077*r*side*(1+.045*math.sin(6*s+.7*a))
            z = (.021 + r*(.052*top + .008*min(up,0))
                 + r*top*(.0018*math.sin(8*s+1.7*a) + (.0032*lip-.0085*groove)*max(0,1-(a/.95)**2)))
            vertices.append((x,y,z))
    def coord(k,j): return ((rings[k]+1)*.5,j/n)
    for k in range(len(rings)-1):
        mid = (rings[k]+rings[k+1])*.5
        for j in range(n):
            h=(j+1)%n
            tile = 2 if min(abs(mid-c) for c in scores)<.015 and abs(-math.pi+math.tau*(j+.5)/n)<.79 else 1
            coords = (coord(k,j),coord(k+1,j),coord(k+1,j+1),coord(k,j+1))
            if tile == 2:
                v0, v1 = (j-6)/4, (j+1-6)/4
                coords = ((.01,v0),(.99,v0),(.99,v1),(.01,v1))
            faces.append(((k*n+j,(k+1)*n+j,(k+1)*n+h,k*n+h),tile,coords,True))
    for left in (True,False):
        x = -1 if left else 1
        tip=len(vertices)
        vertices.append((CX+.172*x,CY,.021))
        k = 0 if left else len(rings)-1
        for j in range(n):
            h=(j+1)%n
            tip_uv=(0 if left else 1,(j+.5)/n)
            ids=(tip,k*n+j,k*n+h) if left else (k*n+j,tip,k*n+h)
            coords=(tip_uv,coord(k,j),coord(k,j+1)) if left else (coord(k,j),tip_uv,coord(k,j+1))
            faces.append((ids,1,coords,True))
    return part("ScoredLoaf", vertices, faces, (CX,CY,.012), collection, materials)


def studio():
    scene = bpy.context.scene
    col = bpy.data.collections.new("Studio — not exported")
    scene.collection.children.link(col)
    floor_mat = bpy.data.materials.new("Studio charcoal linen")
    floor_mat.diffuse_color=(.065,.057,.048,1)
    mesh=bpy.data.meshes.new("Backdrop")
    mesh.from_pydata([(-20,-20,-.0003),(20,-20,-.0003),(20,20,-.0003),(-20,20,-.0003)],[],[(0,1,2,3)])
    floor=bpy.data.objects.new("Backdrop",mesh)
    mesh.materials.append(floor_mat)
    col.objects.link(floor)
    for name, pos, energy, size, color in (
            ("Window",(-.34,-.38,.62),13,.45,(1,.89,.73)),
            ("Linen bounce",(.47,.09,.35),6,.5,(.81,.87,1)),
            ("Rim",(-.16,.44,.42),8,.36,(1,.87,.69))):
        light=bpy.data.lights.new(name,'AREA')
        light.energy,light.shape,light.size,light.color=energy,'DISK',size,color
        ob=bpy.data.objects.new(name,light); col.objects.link(ob); ob.location=pos
        ob.rotation_euler=(Vector((CX,CY,.035))-ob.location).to_track_quat('-Z','Y').to_euler()
    cam=bpy.data.objects.new("Review camera",bpy.data.cameras.new("Review camera"))
    col.objects.link(cam); scene.camera=cam
    scene.render.engine='CYCLES'
    scene.cycles.samples=32
    scene.world.color=(.18,.18,.18)
    scene.render.resolution_x,scene.render.resolution_y,scene.render.resolution_percentage=760,510,100
    scene.render.image_settings.file_format='PNG'
    return cam


def look(camera, pos, target, scale):
    camera.location=pos
    camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler()
    camera.data.type='ORTHO'
    camera.data.ortho_scale=scale


def main():
    args=argparse.ArgumentParser()
    args.add_argument('--studio-dir',type=Path)
    args=args.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    bpy.ops.wm.read_factory_settings(use_empty=True)
    BUILD.mkdir(parents=True,exist_ok=True)
    scene=bpy.context.scene
    scene.world=bpy.data.worlds.new("Studio world")
    scene.unit_settings.system='METRIC'
    parts=bpy.data.collections.new("I-01 — household bread")
    scene.collection.children.link(parts)
    maps=bake_maps()
    materials=[surface(name,maps) for name in NAMES]
    originals=[board(parts,materials),loaf(parts,materials)]
    cam=studio()
    views=(('three-quarter',(.29,-.53,.39),(CX,CY,.029),.63),
           ('profile',(.12,-.60,.18),(CX,CY,.025),.59),
           ('scored-crust',(.19,-.32,.46),(CX+.012,CY,.055),.34))
    look(cam,*views[0][1:])
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/operation_prima/breakfast_bread.blend'),compress=True)
    copies=[]
    for source in originals:
        clone=source.copy(); clone.data=source.data.copy(); parts.objects.link(clone); copies.append(clone)
    bpy.ops.object.select_all(action='DESELECT')
    for clone in copies: clone.select_set(True)
    active=copies[0]; bpy.context.view_layer.objects.active=active
    bpy.ops.object.join()
    active.data.transform(active.matrix_world.copy())
    active.matrix_world=Matrix.Identity(4)
    active.name='TableBread'
    glb=ROOT/'prototype/assets/operation_prima/table_bread.glb'
    bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',use_selection=True,
                             export_animations=False,export_cameras=False,export_lights=False,export_extras=False)
    bpy.data.objects.remove(active,do_unlink=True)
    if args.studio_dir:
        args.studio_dir.mkdir(parents=True,exist_ok=True)
        for key,pos,target,scale in views:
            look(cam,pos,target,scale)
            scene.render.filepath=str(args.studio_dir/(key+'.png'))
            bpy.ops.render.render(write_still=True)
    print('VIVA_BREAKFAST_EXPORT',glb.name)


if __name__=='__main__':
    main()
