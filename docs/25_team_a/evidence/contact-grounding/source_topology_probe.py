from collections import defaultdict, Counter
import hashlib
import importlib.util
import itertools
import json
import math
from pathlib import Path

ROOT=Path(__file__).resolve().parents[4]
spec=importlib.util.spec_from_file_location("asset_reader",ROOT/"tools/art/validate_visual_assets.py")
reader=importlib.util.module_from_spec(spec)
spec.loader.exec_module(reader)
path=ROOT/"prototype/assets/characters/hero_quality_0.glb"
raw=path.read_bytes()
document,binary,warnings=reader.read_glb(raw)
inspection=reader.Inspection(document,binary,warnings)
inspection.inspect_buffers()
EPSILON=0.00001

def topology(vertices,indices):
    buckets=defaultdict(list)
    groups={}
    ids=[]
    def d2(a,b): return sum((x-y)**2 for x,y in zip(a,b))
    for index,point in enumerate(vertices):
        cell=tuple(math.floor(x/EPSILON) for x in point)
        representative=None
        for delta in itertools.product((-1,0,1),repeat=3):
            for candidate in buckets[tuple(x+y for x,y in zip(cell,delta))]:
                if d2(point,vertices[candidate])<=EPSILON**2 and all(d2(point,vertices[member])<=EPSILON**2 for member in groups[candidate]):
                    if representative is None or candidate<representative:
                        representative=candidate
        if representative is None:
            representative=index
            buckets[cell].append(index)
            groups[representative]=[]
        groups[representative].append(index)
        ids.append(representative)
    balances=defaultdict(int)
    incidence=Counter()
    for offset in range(0,len(indices),3):
        triangle=[ids[x] for x in indices[offset:offset+3]]
        for a,b in zip(triangle,triangle[1:]+triangle[:1]):
            if a==b: continue
            edge=tuple(sorted((a,b)))
            balances[edge]+=1 if a<b else -1
            incidence[edge]+=1
    return {"vertices":len(vertices),"triangles":len(indices)//3,
            "closed":all(x==0 for x in balances.values()),
            "boundary_edges":sum(x==1 for x in incidence.values()),
            "unbalanced_edges":sum(x!=0 for x in balances.values()),
            "nonmanifold_edges":sum(x>2 for x in incidence.values())}

rows=[]
for mesh in document["meshes"]:
    if not mesh.get("name","").startswith("Hero"): continue
    vertices,indices=[],[]
    for primitive in mesh["primitives"]:
        offset=len(vertices)
        current=inspection.decode(primitive["attributes"]["POSITION"])
        vertices.extend(current)
        indices.extend(offset+row[0] for row in inspection.decode(primitive["indices"]))
    rows.append({"mesh":mesh["name"],**topology(vertices,indices)})
report={"source":str(path.relative_to(ROOT)),"sha256":hashlib.sha256(raw).hexdigest(),"scope":"Original authored POSITION and index accessors before skinning, animation, or morphs; same complete-link EPS closure criterion","epsilon_m":EPSILON,"meshes":rows}
output=Path(__file__).with_name("source-topology.json")
output.write_text(json.dumps(report,indent=2)+"\n")
print(json.dumps(report,indent=2))
