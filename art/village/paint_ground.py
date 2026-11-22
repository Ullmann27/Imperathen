"""Tileable, original earth, verge and cloud maps painted from seeded height fields."""
from pathlib import Path
import math
import numpy as np
from PIL import Image, ImageDraw

OUT=Path(__file__).resolve().parents[2]/"prototype/assets/village"


def noise(shape, nx, ny, rng):
    h,w=shape
    y,x=np.mgrid[0:h,0:w]
    px=x*nx/w; py=y*ny/h
    i=px.astype(int);j=py.astype(int)
    a=px-i;b=py-j
    a=a*a*(3-2*a);b=b*b*(3-2*b)
    grid=rng.random((ny,nx))
    return ((1-a)*(1-b)*grid[j%ny,i%nx]+a*(1-b)*grid[j%ny,(i+1)%nx]+
            (1-a)*b*grid[(j+1)%ny,i%nx]+a*b*grid[(j+1)%ny,(i+1)%nx])


def ground(name, seed):
    n=512; shape=(n,n)
    rng=np.random.default_rng(seed)
    large=noise(shape,4,4,rng)
    mid=noise(shape,25,25,rng)
    fine=noise(shape,128,128,rng)
    grain=rng.random(shape)
    turf=name=="verge"
    mix=np.clip((large-.28)*1.04+(mid-.5)*.62+(fine-.5)*.34,0,1)[:,:,None]
    low=np.array([85,81,54] if turf else [132,105,74])
    high=np.array([121,126,72] if turf else [204,169,117])
    base=low+(high-low)*mix+((grain-.5)*(17 if turf else 13))[:,:,None]
    height=(large*.10+mid*.28+fine*.11+grain*.04)
    color=Image.fromarray(np.clip(base,0,255).astype(np.uint8))
    relief=Image.fromarray(np.uint8(np.clip(height,0,1)*255))
    paint=ImageDraw.Draw(color);bump=ImageDraw.Draw(relief)
    for i in range(1800 if turf else 1020):
        x,y=rng.integers(0,n,2)
        if turf and i%4:
            dx=int(rng.integers(-5,6));dy=int(rng.integers(2,9))
            coords=[(x,y),(x+dx,y+dy)]
            tint=int(rng.integers(-12,18))
            rgb=(107+tint,108+tint,64+tint)
            for ox in (-n,0,n):
                for oy in (-n,0,n):
                    points=[(int(px+ox),int(py+oy)) for px,py in coords]
                    paint.line(points,fill=rgb,width=1);bump.line(points,fill=111,width=1)
        else:
            radius=rng.uniform(.6,4.4) if i%19 else rng.uniform(4,8)
            angles=np.arange(6)*math.tau/6
            stretch=rng.uniform(.48,.95)
            coords=[(x+radius*math.cos(a)*rng.uniform(.7,1.2),y+radius*math.sin(a)*stretch) for a in angles]
            tint=int(rng.integers(-27,25))
            rgb=np.array([131,123,99] if turf else [166,143,112])+tint
            for ox in (-n,0,n):
                for oy in (-n,0,n):
                    points=[(round(px+ox),round(py+oy)) for px,py in coords]
                    paint.polygon(points,fill=tuple(rgb));bump.polygon(points,fill=int(99+radius*10))
                    if radius>2:
                        paint.line(points[3:6],fill=tuple(rgb+11),width=1)
    h=np.asarray(relief,dtype=float)/255
    dx=(np.roll(h,-1,1)-np.roll(h,1,1))*.5;dy=(np.roll(h,-1,0)-np.roll(h,1,0))*.5
    norm=np.stack((-dx*1.8,dy*1.8,np.ones_like(dx)),axis=2)
    norm/=np.linalg.norm(norm,axis=2)[:,:,None]
    packed=np.stack((norm[:,:,0]*.5+.5,norm[:,:,1]*.5+.5,np.clip(.88+mid*.10-(h*.17),0,1)),axis=2)
    color.save(OUT/(name+"_color.png"))
    Image.fromarray(np.uint8(packed*255)).save(OUT/(name+"_relief.png"))


if __name__=="__main__":
    OUT.mkdir(parents=True,exist_ok=True)
    ground("track",1351)
    ground("verge",550)
    rng=np.random.default_rng(2194)
    shape=(384,1024)
    cloud=sum(noise(shape,ax,ay,rng)*weight for ax,ay,weight in
              [(6,3,.42),(16,8,.27),(39,17,.16),(95,39,.095),(180,71,.055)])
    Image.fromarray(np.uint8(np.clip(cloud,0,1)*255)).save(OUT/"sky_clouds.png")
