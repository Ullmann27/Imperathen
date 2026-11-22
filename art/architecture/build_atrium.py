"""Generate an original walk-in tetrastyle atrium house with a rain basin."""
from pathlib import Path
from tempfile import TemporaryDirectory
import sys
import bpy

SOURCE = Path(__file__).resolve().parent
ROOT = SOURCE.parents[1]
sys.path.insert(0, str(SOURCE.parent / "landscape"))
from build_settlements import House, palette


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    g = House()
    # Three street-facing bays and a central entrance corridor (fauces).
    for x0, x1 in [(-5.5,-.92),(.92,5.5)]:
        g.box((x0+x1)/2,-4.90,0,x1-x0,.32,3.45,"white")
        g.box((x0+x1)/2,-5.075,.20,x1-x0,.07,1.18,"red")
    for x in [-5.35,5.35]:
        g.box(x,0,0,.30,10.1,3.45,"white")
    g.box(0,4.93,0,10.8,.25,3.45,"daub")
    for x in [-1.03,1.03]:
        g.box(x,-3.7,0,.20,2.10,2.65,"daub")
    g.box(0,-4.9,2.65,2.15,.45,.8,"white")
    g.box(0,0,.0,10.8,9.9,.065,"stone")
    g.box(0,0,.07,2.8,3.3,.065,"slate")
    for x in [-1.52,1.52]:
        g.box(x,0,.06,.22,3.7,.22,"white")
    for y in [-1.75,1.75]:
        g.box(0,y,.06,3.22,.22,.22,"white")
    for x in [-2,2]:
        for y in [-2.15,2.15]:
            g.box(x,y,.06,.52,.52,.17,"stone")
            g.beam((x,y,.22),(x,y,2.89),.205,"white",16,.165)
            g.beam((x,y,2.88),(x,y,3.01),.24,"white",16)
            g.box(x,y,3,.54,.54,.18,"stone")
    # Individual rows, ribs and antefixes of the four tiled planes draining inwards.
    outer=[(-5.65,-5.15,3.55),(5.65,-5.15,3.55),(5.65,5.15,3.55),(-5.65,5.15,3.55)]
    inner=[(-1.83,-1.96,3.10),(1.83,-1.96,3.10),(1.83,1.96,3.10),(-1.83,1.96,3.10)]
    def mix(a,b,t):
        return tuple(x+(y-x)*t for x,y in zip(a,b))
    for i in range(4):
        j=(i+1)%4
        a,b,c,d=outer[i],outer[j],inner[j],inner[i]
        g.prism([a,b,c,d],(0,0,-.14),"clay")
        for k in range(34):
            t=k/33
            g.beam(mix(a,b,t),mix(d,c,t),.046,"red",7)
        for k in range(1,10):
            t=k/10
            g.beam(mix(a,d,t),mix(b,c,t),.027,"clay",6)
        g.beam(a,b,.10,"ridge",8)
    with TemporaryDirectory() as temp:
        g.to_mesh("Open_atrium_and_impluvium",palette(Path(temp)))
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/"atrium_house.blend"),compress=True)
    bpy.ops.export_scene.gltf(filepath=str(ROOT/"prototype/assets/architecture/atrium_house.glb"),
                              export_format="GLB",export_animations=False)

if __name__ == "__main__":
    build()
