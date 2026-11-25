"""Copy only the actual country-road fixture and its dependencies for engine CI."""
import pathlib,shutil,sys
root=pathlib.Path(__file__).resolve().parents[2]/'prototype'
out=pathlib.Path(sys.argv[1]).resolve()
out.mkdir(parents=True,exist_ok=True)
for pattern in ('assets/viva_country/*','scripts/viva_country/*.gd','shaders/viva_country/*.gdshader','scenes/viva_country/*.tscn','tests/viva_country_test.gd','scripts/ui/touch_pad.gd','scripts/ui/touch_look.gd'):
    files=[p for p in root.glob(pattern) if p.is_file()]
    if not files: raise SystemExit('Missing source '+pattern)
    for path in files:
        target=out/path.relative_to(root)
        target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(path,target)
(out/'project.godot').write_text('''config_version=5
[application]
config/name="VIVA ROMA · Country road"
run/main_scene="res://scenes/viva_country/country_walk.tscn"
[display]
window/size/viewport_width=1280
window/size/viewport_height=720
window/handheld/orientation=4
[input_devices]
pointing/emulate_mouse_from_touch=true
[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
''',encoding='utf-8')
