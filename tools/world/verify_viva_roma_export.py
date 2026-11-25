"""Verify actual city export, without implying visual or device approval."""
import json, pathlib, struct, sys, hashlib
directory=pathlib.Path(sys.argv[1])
manifest=json.loads((directory/"city_manifest.json").read_text())
assert manifest["residential_count"]==240 and manifest["market_stall_count"]==63
assert manifest["surface_pipeline"]["style"]=="viva" and manifest["surface_pipeline"]["texture_size"]==1024
def glb(path):
    with path.open("rb") as f:
        magic,version,length=struct.unpack("<4sII",f.read(12))
        assert magic==b"glTF" and version==2 and length==path.stat().st_size
        size,kind=struct.unpack("<I4s",f.read(8));assert kind==b"JSON"
        data=json.loads(f.read(size))
    return data
city=glb(directory/"imperathen_roman_test_city.glb")
collision=glb(directory/"roman_city_collision.glb")
materials=city.get("materials",[])
mapped=[m for m in materials if "normalTexture" in m and "baseColorTexture" in m.get("pbrMetallicRoughness",{}) and "metallicRoughnessTexture" in m.get("pbrMetallicRoughness",{})]
assert len(mapped)>=10, [m.get("name") for m in mapped]
assert len(collision.get("meshes",[]))>0
result={"status":"export_structure_pass","mapped_materials":[m.get("name") for m in mapped],"mesh_count":len(city.get("meshes",[])),"city_nodes":len(city.get("nodes",[])),"review":"visual and Godot import still required","sha256":{}}
for name in ("imperathen_roman_test_city.glb","roman_city_collision.glb"):
    with (directory/name).open("rb") as f:result["sha256"][name]=hashlib.file_digest(f,"sha256").hexdigest()
(directory/"export_validation.json").write_text(json.dumps(result,indent=2))
print(json.dumps(result,indent=2))
