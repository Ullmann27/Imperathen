"""Paint bark and four alpha-cutout shoot variations per species. No source images."""
import math
import random

import numpy as np
from PIL import Image, ImageDraw

BASE = {"oak": (79, 100, 45), "olive": (93, 113, 78), "pine": (44, 78, 60)}
BARK = {"oak": (102, 88, 70), "olive": (140, 132, 105), "pine": (139, 101, 78)}
SEEDS = {"oak": 21, "olive": 69, "pine": 45}


def tint(rgb, amount):
    return tuple(max(0, min(255, int(component * amount))) for component in rgb)


def leaf(draw, base, tip, width, color, kind):
    dx, dy = tip[0] - base[0], tip[1] - base[1]
    length = math.hypot(dx, dy)
    nx, ny = -dy / length, dx / length
    def edge(t, w):
        return (base[0] + dx*t + nx*w, base[1] + dy*t + ny*w)
    if kind == "oak":
        contour = [(0, 0), (.17, .34), (.29, .86), (.37, .65), (.48, 1.0),
                   (.56, .71), (.69, .96), (.77, .61), (.88, .71), (1, 0)]
    else:
        contour = [(0, 0), (.22, .66), (.52, 1), (.79, .64), (1, 0)]
    left = [edge(t, width*w) for t,w in contour]
    right = [edge(t, -width*w) for t,w in contour]
    draw.polygon(left + right[::-1], fill=color)
    draw.polygon([base] + right + [tip], fill=tint(color, 1.15))
    draw.line((base,tip), fill=tint(color,1.42), width=1)


def foliage(kind, path):
    rng = random.Random(SEEDS[kind])
    # Two-by-two atlas. Each half-meter spray gets an independently bent twig.
    cell = 256
    atlas = Image.new("RGBA",(2*cell,2*cell),(57,80,46,0))
    for variant in range(4):
        tile = Image.new("RGBA",(cell,cell),(57,80,46,0))
        pen = ImageDraw.Draw(tile)
        stem = [(127,247),(126,212),(119,174),(129,125),(131,86),(144,44),(146,17)]
        stem = [(x+rng.randint(-8,8),y) for x,y in stem]
        for k in range(len(stem)-1):
            pen.line((stem[k],stem[k+1]), fill=(101,90,62), width=max(1,5-k))
        for row in range(9):
            cx = 127 + 7*math.sin(row*.8)
            cy = 216-row*22
            for sign in (-1,1):
                length = (64+29*math.sin(row*.38))*(1-.045*row)*rng.uniform(.87,1.13)
                end = (cx+sign*length,cy-length*rng.uniform(.40,.68))
                if kind == "pine":
                    # Each fan is made of separate needles with overlapping dark bases.
                    center = (cx+sign*length*.45,cy-length*.28)
                    pen.line(((cx,cy),center), fill=(104,91,63), width=3)
                    for i in range(31):
                        angle = -math.pi*.43+sign*(i-15)*.047 + sign*.39
                        start=(center[0]+sign*rng.uniform(-5,6),center[1]+rng.uniform(-4,5))
                        radius=rng.uniform(25,51)
                        tip=(start[0]+math.cos(angle)*radius*sign,start[1]+math.sin(angle)*radius)
                        color=tint(BASE[kind],rng.uniform(.76,1.56))
                        pen.line((start,tip),fill=color,width=rng.choice((1,2,2,3)))
                    continue
                bx,by=end[0]-cx,end[1]-cy
                pen.line(((cx,cy),end),fill=(109,101,68),width=2)
                for j in range(4):
                    t=.17+j*.21
                    x,y=cx+bx*t,cy+by*t
                    for side in (-1,1):
                        tip=(x+sign*rng.uniform(11,24),y+side*rng.uniform(12,25)-6)
                        color=tint(BASE[kind],rng.uniform(.75,1.40))
                        if kind=="olive" and rng.random()<.21:
                            color=(145,158,126)
                        leaf(pen,(x,y),tip,rng.uniform(4.3,6.2) if kind=="olive" else rng.uniform(6.5,10),color,kind)
                leaf(pen,end,(end[0]+sign*14,end[1]-11),5,BASE[kind],kind)
        atlas.paste(tile,((variant%2)*cell,(variant//2)*cell))
    atlas.save(path)


def bark(kind, path):
    rng=np.random.default_rng(SEEDS[kind])
    width,height=256,512
    y,x=np.indices((height,width))
    # Periodic cross-trunk coordinate allows a complete circumference to tile.
    a=x*2*math.pi/width
    skew=np.sin(y/58+a*3)*.12+np.sin(y/29-a*2)*.048
    furrow=np.abs(np.sin((a+skew)*(14 if kind=="pine" else 20)))
    fine=np.cos(a*67+y*.018+np.sin(y*.043))*.043
    grain=rng.normal(0,.039,(height,width))
    value=.84+.20*furrow-.26*np.exp(-furrow*7)+fine+grain
    if kind=="pine":
        value-=.19*np.exp(-np.abs(np.sin(y*.038+1.9*np.sin(a*4)))*11)
    if kind=="olive":
        value+=.15*np.sin(5*a+.8*np.sin(y/73))
    arr=np.clip(np.array(BARK[kind])[None,None,:]*value[:,:,None],0,255).astype(np.uint8)
    Image.fromarray(arr).save(path)
