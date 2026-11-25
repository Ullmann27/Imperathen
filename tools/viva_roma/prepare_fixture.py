"""Create an isolated renderer fixture from exact committed production asset bytes."""
import argparse, pathlib, shutil
p=argparse.ArgumentParser()
p.add_argument('output',type=pathlib.Path)
p.add_argument('--method',choices=['gl_compatibility','mobile'],default='gl_compatibility')
args=p.parse_args()
source=pathlib.Path(__file__).resolve().parents[2]/'prototype'
destination=args.output.resolve()
destination.mkdir(parents=True,exist_ok=True)
patterns=[
 'assets/viva_roma/props/*.glb','assets/world_expansion/manifest.json',
 'assets/world_expansion/architecture/*_lod0.glb','assets/world_expansion/vegetation/*.glb',
 'assets/characters/frontier_civilian_man_0.glb','assets/characters/frontier_civilian_woman_0.glb',
 'assets/characters/frontier_elder_0.glb','assets/characters/frontier_legionary_0.glb','assets/characters/hero_quality_0.glb',
 'assets/city_detail/characters/*.png','assets/roman_material_lab/iron_service_*.png',
 'assets/roman_material_lab/oak_worked_*.png','assets/weapons/gladius_lod0_bronze_*.png',
 'scripts/rendering/city_character_detail.gd','scripts/world_expansion/asset_library.gd',
 'scripts/world_expansion/environment_controller.gd','shaders/world_expansion/vegetation_wind.gdshader',
 'scripts/viva_roma/closeup_lab.gd','scenes/viva_roma/closeup_lab.tscn',
 'tests/viva_character_finish_test.gd','tests/city_character_detail_test.gd']
for pattern in patterns:
    files=list(source.glob(pattern))
    if not files:
        raise SystemExit('Missing source: '+pattern)
    for f in files:
        target=destination/f.relative_to(source)
        target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(f,target)
        settings=f.with_name(f.name+'.import')
        if settings.is_file(): shutil.copy2(settings,target.with_name(target.name+'.import'))
(destination/'project.godot').write_text('''config_version=5
[application]
config/name="VIVA ROMA visual QA"
run/main_scene="res://scenes/viva_roma/closeup_lab.tscn"
[display]
window/size/viewport_width=1280
window/size/viewport_height=720
window/size/window_width_override=1280
window/size/window_height_override=720
[rendering]
renderer/rendering_method="'''+args.method+'''"
renderer/rendering_method.mobile="'''+args.method+'''"
textures/vram_compression/import_etc2_astc=true
''')
