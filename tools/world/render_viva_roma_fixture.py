"""Real 3D Blender A/B fixture: same geometry, lighting, exposure and camera."""
import argparse, math, sys, json, hashlib
from pathlib import Path
import bpy
from mathutils import Vector

sys.path.insert(0,str(Path(__file__).resolve().parent))
import build_roman_test_city as city

parser=argparse.ArgumentParser()
parser.add_argument("--output",required=True)
args=parser.parse_args(sys.argv[sys.argv.index("--")+1:])
out=Path(args.output).resolve()
out.mkdir(parents=True,exist_ok=True)
records=[]
for style in ("legacy","viva"):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    city.MATS.clear(); city.SCALES.clear()
    city.SURFACE_STYLE=style;city.TEXTURE_SIZE=1024
    dest=out/style;dest.mkdir(exist_ok=True);(dest/"textures").mkdir(exist_ok=True)
    scene=bpy.context.scene
    city.CITY=bpy.data.collections.new("Review_geometry")
    city.PREVIEW=bpy.data.collections.new("Review_light")
    for collection in (city.CITY,city.PREVIEW): scene.collection.children.link(collection)
    city.STONE=city.material("Travertine",(.65,.57,.43),"stone",dest,2.4)
    city.PLASTER=city.material("Lime_Plaster",(.78,.71,.57),"plaster",dest)
    city.BRICK=city.material("Roman_Brick",(.43,.24,.14),"brick",dest)
    city.WOOD=city.material("Oak_Timber",(.23,.13,.065),"wood",dest)
    city.ROOF=city.material("Terracotta_Tiles",(.49,.22,.105),"roof",dest)
    city.PAVING=city.material("Basalt_Paving",(.30,.31,.29),"paving",dest,3)
    city.DARK=city.material("Window_Recess",(.035,.027,.02),None,dest)
    m=city.Mesh("Street_review",False)
    m.box((0,0,-.08),(16,14,.16),city.PAVING)
    m.box((-4.7,2.4,1.8),(2.6,.45,3.6),city.BRICK)
    m.doorway(0,2.4,6.8,3.7,0,.46,city.PLASTER,2.0,2.7)
    m.box((4.7,2.4,1.8),(2.6,.45,3.6),city.STONE)
    city.window(m,-2.05,2.12,1.35,.9,1.25)
    m.roof(0,3.8,12.3,3.5,3.72,1.1)
    for x in (-3.45,3.45):
        m.column(x,.5,0,3.18,.22,1)
    m.box((0,.5,3.29),(7.8,.45,.26),city.WOOD)
    for i in range(3):
        m.box((0,1.58+i*.30,.07+i*.07),(2.7,.42,.14+i*.14),city.STONE)
    data,_=m.finish()
    obj=bpy.data.objects.new("Roman_review_geometry",data);city.CITY.objects.link(obj)
    camera=city.preview_setup()
    scene.cycles.samples=48;scene.cycles.use_denoising=True
    scene.render.resolution_x=1280;scene.render.resolution_y=880
    city.set_camera(camera,(6.8,-8.7,2.25),(0,2.0,1.75),33)
    scene.render.filepath=str(out/(style+".png"))
    bpy.ops.render.render(write_still=True)
    # The same geometry is used for both material comparisons.
    mesh_fingerprint=hashlib.sha256(repr((m.v,m.f,m.mi,m.uv)).encode()).hexdigest()
    records.append({"style":style,"vertices":len(m.v),"faces":len(m.f),"geometry_sha256":mesh_fingerprint,"render_sha256":hashlib.sha256((out/(style+".png")).read_bytes()).hexdigest()})
    if style=="viva":
        bpy.ops.wm.save_as_mainfile(filepath=str(out/"viva_fixture.blend"),compress=True)
assert records[0]["geometry_sha256"]==records[1]["geometry_sha256"], records
assert records[0]["render_sha256"]!=records[1]["render_sha256"], records
(out/"comparison.json").write_text(json.dumps({"blender":bpy.app.version_string,"renders":records,"visual_review":"required"},indent=2))
