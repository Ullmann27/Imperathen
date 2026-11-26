"""Original bread-counter dressing in metres. Run with blender -b -P this_file."""
import math
import sys
from pathlib import Path

import bpy
import bmesh

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/city_detail"))
import architecture_generate as kit

sys.path.insert(0, str(ROOT / "tools/art"))
from common import box, material, mesh, reset_scene

OUT = ROOT / "prototype/assets/city/bakery/market_bakery.glb"


def make_awning():
    # Four load points above head height. The panel sags between the two
    # wooden rails; the drop edge follows the same hem at the forward rail.
    linen = material("Naturleinen", (.65, .49, .31), roughness=.94)
    stripe = material("Krappstreifen", (.33, .072, .046), roughness=.94)
    for mat in [linen, stripe]:
        mat.use_backface_culling = False
    verts, faces, colors = [], [], []
    columns, rows = 48, 10
    for j in range(rows + 2):
        along = min(j, rows) / rows
        for i in range(columns + 1):
            width = i / columns
            x = (width - .5) * 4.18
            y = -1.52 - along * 1.18
            drape = math.sin(math.pi * width) ** 1.5
            z = 2.87 - .30 * along - .11 * math.sin(math.pi * along) - .06 * drape
            z += .013 * math.sin(x * 11 + along) * drape
            if j > rows:
                z -= .15 + .018 * (1 - math.cos(x * 14))
                y += .034
            verts.append((x, y, z))
            if j and i:
                p = j * (columns + 1) + i
                faces.append((p - columns - 2, p - 1, p, p - columns - 1))
                colors.append(int((i - 1) % 12 in [1, 2, 4]))
    canopy = mesh("Leinensegel", verts, faces, linen, True)
    canopy.data.materials.append(stripe)
    for face, index in zip(canopy.data.polygons, colors):
        face.material_index = index
    for x in [-1.85, 1.85]:
        kit.tube("Vordachstrebe", [(x, -1.46, 2.20), (x, -2.66, 2.48)], .034, "wood", 9)
    kit.tube("Vordachstange", [(-2.11, -2.69, 2.49), (2.11, -2.69, 2.49)], .032, "wood", 10)


def make_bread():
    # Reuse the project's scored loaf geometry. The original board module
    # combines loaves; here each can disappear as stock sells out.
    crust = material("Ofenkruste", (.55, .264, .092), roughness=.92)
    kit.MATS["bread"] = crust
    for tray in range(3):
        x = (tray - 1) * 1.13
        box("Brett_%d" % tray, (x, -.46, 1.119), (1.08, .76, .058), kit.MATS["wood"], .018)
        for k in range(2):
            bread = kit.loaf(x + (k - .5) * .49, -.48 + .034 * (tray % 2), 1.234)
            bread.name = "Panis_%02d" % (tray * 2 + k)
            # Give the baked grooves a paler exposed crumb. Shared shader
            # reads the exported vertex colours, also on the mobile renderer.
            colors = bread.data.color_attributes.new(name="Kruste", type="FLOAT_COLOR", domain="POINT")
            for v in bread.data.vertices:
                p = v.co
                angle = math.atan2(p.y + .48 - .034 * (tray % 2), p.x - x - (k - .5) * .49)
                groove = max(0, 1 - abs(math.sin(4 * angle)) * 2.7) * max(0, min(1, (p.z - 1.235) * 14))
                speckle = .038 * math.sin(v.index * 23.41 + tray * 1.3)
                colors.data[v.index].color = (.47 + .25 * groove + speckle, .21 + .2 * groove + speckle, .072 + .12 * groove, 1)
            bm = bmesh.new()
            bm.from_mesh(bread.data)
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
            bm.to_mesh(bread.data)
            bm.free()
    color = crust.node_tree.nodes.new("ShaderNodeVertexColor")
    color.layer_name = "Kruste"
    crust.node_tree.links.new(color.outputs["Color"], crust.node_tree.nodes.get("Principled BSDF").inputs["Base Color"])


def main():
    reset_scene()
    kit.MATS["wood"] = material("Marktholz", (.22, .12, .06), roughness=.89)
    make_awning()
    make_bread()
    bpy.ops.export_scene.gltf(filepath=str(OUT), export_format="GLB", export_yup=True,
                              export_apply=True, export_animations=False, export_vertex_color="ACTIVE")
    print("BAKERY_GLB", OUT.stat().st_size)


if __name__ == "__main__":
    main()
