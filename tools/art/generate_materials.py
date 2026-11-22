"""Generate original seamless PBR maps using deterministic periodic fields.

No downloaded imagery. Each 1 m tile has base colour, roughness and tangent normal.
The files are source maps; engine import chooses device texture compression.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]


def field(rng, size, scales):
    result = np.zeros((size, size), dtype=np.float64)
    y, x = np.mgrid[0:size, 0:size] / size * np.pi * 2
    for frequency, amplitude in scales:
        for _ in range(6):
            a, b = rng.integers(-frequency, frequency + 1, 2)
            if a == 0 and b == 0:
                a = frequency
            result += np.sin(x * a + y * b + rng.random() * 6.28) * amplitude / 6
    return result


def make_maps(name, size, seed):
    rng = np.random.default_rng(seed)
    y, x = np.mgrid[0:size, 0:size] / size
    coarse = field(rng, size, [(2, .9), (6, .5), (17, .2), (53, .12)])
    fine = field(rng, size, [(37, .5), (89, .25), (157, .12)])
    bases = {
        "plaster": ([.73, .69, .57], .86),
        "limestone": ([.46, .45, .39], .89),
        "oak": ([.26, .17, .09], .81),
        "terracotta": ([.48, .23, .13], .84),
        "linen": ([.60, .51, .35], .92),
        "leather": ([.20, .105, .054], .74),
        "bronze": ([.48, .32, .12], .48),
        "earth": ([.29, .26, .19], .95),
    }
    color, roughness = bases[name]
    height = coarse * .35 + fine * .15
    variation = coarse * .19 + fine * .055
    if name == "oak":
        grain = np.sin(2*np.pi*(x*38 + .15*np.sin(y*2*np.pi*3) + coarse*.7))
        growth = np.sin(2*np.pi*(x*9 + .13*np.sin(y*2*np.pi)))
        height += grain*.2 + growth*.1
        variation += grain*.11 + growth*.08
    elif name == "linen":
        weave = np.sin(x*2*np.pi*128)*np.sin(y*2*np.pi*128)
        height = weave*.14 + coarse*.14 + fine*.035
        variation += weave*.055
    elif name == "leather":
        pores = np.maximum(fine-.16, 0)
        height -= pores*.7
        variation -= pores*.2
    elif name == "terracotta":
        variation += np.sin(y*2*np.pi*73 + coarse*7)*.025
    elif name == "earth":
        grit = (fine > .25).astype(float)
        height += grit*.14
        variation += grit*.09
    elif name == "bronze":
        patina = np.clip((coarse+.16)*1.7, 0, .6)
        variation -= patina*.3
    rgb = np.clip(np.asarray(color)[None,None,:]*(1+variation[:,:,None]), 0, 1)
    dx = (np.roll(height,-1,axis=1)-np.roll(height,1,axis=1))*2.4
    dy = (np.roll(height,-1,axis=0)-np.roll(height,1,axis=0))*2.4
    normal = np.stack([-dx, dy, np.ones_like(dx)],axis=2)
    normal /= np.linalg.norm(normal,axis=2)[:,:,None]
    normal = normal*.5+.5
    rough = np.clip(roughness + coarse*.06 + fine*.06, .15, 1)
    return {"basecolor": rgb, "normal": normal, "roughness": rough}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--size", type=int, choices=[256,512,1024], default=512)
    parser.add_argument("--output",type=Path,default=ROOT / "art/visual_benchmark/materials")
    args=parser.parse_args()
    args.output.mkdir(parents=True,exist_ok=True)
    files=[]
    for index,name in enumerate(["plaster","limestone","oak","terracotta","linen","leather","bronze","earth"]):
        for channel,array in make_maps(name,args.size,8421+index).items():
            path=args.output / f"{name}_{channel}.png"
            Image.fromarray(np.round(array*255).astype(np.uint8)).save(path,optimize=True)
            files.append({"path":path.name,"sha256":hashlib.sha256(path.read_bytes()).hexdigest(),"bytes":path.stat().st_size})
    (args.output / "provenance.json").write_text(json.dumps({
        "generator":"tools/art/generate_materials.py", "seed_base":8421,
        "resolution":[args.size,args.size], "tile_size_metres":1,
        "source":"Original periodic procedural fields; no source photos or external material packs.",
        "normal_convention":"OpenGL tangent normal (+Y); Blender glTF export",
        "files":files},indent=2)+"\n",encoding="utf-8")
    print(json.dumps({"maps":len(files),"resolution":args.size,"total_bytes":sum(f['bytes'] for f in files)}))


if __name__ == "__main__":
    main()
