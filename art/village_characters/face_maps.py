"""Rectify project-owned portrait details into UV maps for sculpted heads."""
from pathlib import Path
import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "prototype/assets/village_characters/faces"
# Eye centres in the locally rendered reference images, uniformly fitted to a
# 512x768 frame. Values are in source pixels; the face is not a billboard.
EYES = {
 "hero_italia":(132,60,162,68), "marcus":(122,72,151,82),
 "hero_han":(116,79,146,73), "lin":(147,71,177,73),
 "hero_wa":(198,67,230,73), "aki":(137,71,166,68),
 "hero_germania":(151,64,185,62), "albrun":(145,69,176,68),
 "hero_vistula":(147,70,177,72), "mira":(165,64,193,65),
 "adult_italia":(131,53,161,55), "adult_marcus":(127,58,161,66),
}
OUT.mkdir(exist_ok=True,parents=True)
for name,(x1,y1,x2,y2) in EYES.items():
    im=Image.open(ROOT/"prototype/assets/portraits"/(name+".webp")).convert("RGB")
    im.thumbnail((512,768))
    # The UV map spans x [-.105,.105] and facial height [0,.22] metres.
    # Authored eye landmarks in the three-dimensional head are (+/-.036,.119).
    scale=256
    ex,ey=(x2-x1)/.072,(y2-y1)/.072
    u=.21/scale
    v=.22/scale
    x0,y0=(x1+x2)/2,(y1+y2)/2
    src=im.transform((scale,scale), Image.Transform.AFFINE,
                     (ex*u,-ey*v,x0-.105*ex+.101*ey,
                      ey*u,ex*v,y0-.105*ey-.101*ex),Image.Resampling.BICUBIC)
    rgb=np.asarray(src,dtype=float)
    yy,xx=np.mgrid[0:scale,0:scale]
    edge=np.sqrt(((xx-128)/108)**2+((yy-132)/134)**2)
    fade=np.clip((1.15-edge)*4.2,0,1)[:,:,None]
    cheek=np.median(rgb[157:171,152:172,:],axis=(0,1))
    # Side/back skin remains neutral; the textured frontal plane is smoothly
    # joined to the authored cheek, ear and jaw geometry.
    tex=rgb*fade+cheek*(1-fade)
    Image.fromarray(np.uint8(np.clip(tex,0,255))).save(OUT/(name+".webp"),quality=92)
