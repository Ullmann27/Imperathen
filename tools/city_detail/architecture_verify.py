"""Validate actual exported city meshes, maps and budgets without Blender/Godot."""
from __future__ import annotations

import hashlib
import json
import math
import struct
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/"prototype/assets/city_detail/architecture"


def validate() -> dict:
    manifest=json.loads((OUT/"architecture_manifest.json").read_text())
    raw=(OUT/"city_architecture_library.glb").read_bytes()
    magic,version,length=struct.unpack_from("<4sII",raw)
    assert magic==b"glTF" and version==2 and length==len(raw)
    size,kind=struct.unpack_from("<II",raw,12)
    assert kind==0x4E4F534A
    gltf=json.loads(raw[20:20+size])
    assert hashlib.sha256(raw).hexdigest()==manifest["sha256"]
    assert len(raw)<30*1024*1024, "Mesh library exceeds 30 MiB disk budget"
    nodes={n["name"]:n for n in gltf["nodes"] if "mesh" in n}
    count=0
    counts={}
    for module,info in manifest["modules"].items():
        levels=[]
        for lod in info["lods"]:
            node=nodes[lod["node"]]
            model=gltf["meshes"][node["mesh"]]
            triangles=0
            for primitive in model["primitives"]:
                attrs=primitive["attributes"]
                assert {"POSITION","NORMAL","TEXCOORD_0","TANGENT"} <= attrs.keys()
                assert primitive.get("mode",4)==4
                indices=gltf["accessors"][primitive["indices"]]
                assert indices["count"]%3==0
                triangles+=indices["count"]//3
                position=gltf["accessors"][attrs["POSITION"]]
                assert all(math.isfinite(v) for v in position["min"]+position["max"])
                material=gltf["materials"][primitive["material"]]
                assert "baseColorTexture" in material["pbrMetallicRoughness"]
                assert "metallicRoughnessTexture" in material["pbrMetallicRoughness"]
                assert "normalTexture" in material
            assert triangles==lod["triangles"],(lod["node"],triangles,lod["triangles"])
            levels.append(triangles);count+=1
        assert levels[0]>levels[1]>levels[2],(module,levels)
        counts[module]=levels
        for box in info["collision_boxes_godot"]:
            assert len(box["center"])==len(box["size"])==3
            assert all(math.isfinite(v) for v in box["center"]+box["size"])
            assert all(v>0 for v in box["size"])
    assert count==21
    assert len(gltf["images"])>0
    assert all("bufferView" in image for image in gltf["images"])
    # Actual doorway dimensions must retain room for a person.
    door_walls=manifest["modules"]["taberna_4m"]["collision_boxes_godot"]
    assert not any(abs(b["center"][0])<.1 and .1<b["center"][1]<2.3 and b["center"][2]>1 for b in door_walls)
    return {"passed":True,"module_count":len(counts),"lod_meshes":count,"bytes":len(raw),
            "embedded_images":len(gltf["images"]),"triangles_by_lod":counts,
            "scope":"GLB structure, actual geometry counts, embedded PBR maps, coarse collision contract; not Android FPS or visual acceptance."}


if __name__=="__main__":
    result=validate()
    path=ROOT/"docs/26_city_support/evidence/architecture/glb_validation.json"
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(result,indent=2)+"\n")
    print(json.dumps(result,indent=2))
