"""Paint the domus material atlas and derive tangent-space relief from original height fields."""
from pathlib import Path
import math

import bpy
import numpy as np
from PIL import Image

SWATCHES = {
    "intonaco": (207,187,151), "lime": (226,210,177), "oxide": (145,65,45), "ochre": (192,148,76),
    "tuff": (134,124,102), "traver": (195,170,135), "basalt": (76,74,66), "cedar": (114,74,45),
    "beam": (74,55,40), "iron": (62,61,54), "bronze": (151,116,65), "tegula": (177,108,73),
    "fired": (147,84,59), "paving": (155,126,102), "mosaic": (198,179,148), "water": (83,120,115),
}


def field(rng, size, frequency):
    source = (rng.random((frequency,frequency))*255).astype(np.uint8)
    img = Image.fromarray(source).resize((size,size),Image.Resampling.BICUBIC)
    return np.asarray(img).astype(float)/255-.5


def swatch(name, rgb, index, size):
    rng = np.random.default_rng(733+index)
    y,x = np.mgrid[0:size,0:size]/size
    cloud = field(rng,size,9)
    fine = rng.random((size,size))-.5
    grain = field(rng,size,49)
    relief = fine*.07+grain*.14+cloud*.18
    value = 1+cloud*.090+grain*.046+fine*.026
    rough, metal = .84, 0.
    if name in ("intonaco","oxide","lime","ochre"):
        # Burnished lime with mineral flecks, small spalls and an uneven weathered foot.
        chips = np.maximum(0,grain*.58+fine*.36-.294)
        salt = np.clip((.19-y+cloud*.16)*4,0,1)
        value += chips*1.4-salt*.115
        if name=="oxide":
            value+=np.clip(cloud*.44+grain*.20+salt*.15-.12,0,.14)*.80
        relief-=chips*.80
    elif name in ("tuff","traver","basalt"):
        bedding=np.sin(y*88+3.1*np.sin(x*3)+cloud*2.2)
        pores=np.maximum(0,grain*.69+fine*.33-.25)
        value+=.060*bedding+cloud*.16-pores*.75
        relief+=.11*bedding-pores*1.25
    elif name in ("cedar","beam"):
        curve=x*61+np.sin(y*4+.8)+2*np.sin(x*11+y*2)
        ring=np.sin(curve*2.1)+.36*np.sin(curve*5)
        knot=np.sin(np.hypot((x-.36)*3,(y-.62)*1.04)*66)*np.exp(-((x-.36)**2*120+(y-.62)**2*20))
        value+=ring*.064+knot*.11
        relief+=ring*.2+knot*.22
    elif name in ("iron","bronze"):
        metal,rough=(.72,.57) if name=="iron" else (.82,.44)
        value+=cloud*.21+grain*.14
    elif name in ("tegula","fired"):
        value+=cloud*.085+grain*.04+fine*.018
        relief+=.10*np.sin(y*31+x*2)+grain*.11
    elif name=="paving":
        # Offset rectangular earthen pavers, modelled in surface relief.
        row=np.floor(y*11)
        a=(x*7+(row%2)*.5)%1
        b=(y*11)%1
        joints=np.minimum.reduce([a,1-a,b,1-b])<.034
        value+=np.sin(np.floor(x*7+(row%2)*.5)*91+row*11)*.064
        relief-=joints*.59
        value-=joints*.20
    elif name=="mosaic":
        a,b=(x*32)%1,(y*32)%1
        joints=np.minimum.reduce([a,1-a,b,1-b])<.075
        px,py=np.floor(x*32),np.floor(y*32)
        diamond=(abs((px%16)-7.5)+abs((py%16)-7.5))
        value*=np.where((diamond>5.8)&(diamond<8.3),.45,1.)
        value+=np.sin(px*77+py*53)*.038-joints*.19
        relief-=joints*.36
        rough=.70
    elif name=="water":
        ripple=np.sin(x*73+np.sin(y*18)*2.6)+.6*np.sin(y*87+x*36)
        value=1+cloud*.13+ripple*.035
        relief=ripple*.23
        rough=.20
    albedo=np.clip(np.array(rgb)[None,None,:]*value[:,:,None],0,255).astype(np.uint8)
    dy,dx=np.gradient(relief)
    normal=np.stack((-dx*1.75,-dy*1.75,np.ones_like(dx)),axis=2)
    normal/=np.linalg.norm(normal,axis=2)[:,:,None]
    normal=np.clip((normal*.5+.5)*255,0,255).astype(np.uint8)
    orm=np.stack((np.ones_like(x),np.clip(rough+cloud*.09,.08,1),np.ones_like(x)*metal),axis=2)
    return albedo,normal,(orm*255).astype(np.uint8)


def material(folder: Path):
    size=192
    atlases=[Image.new("RGB",(size*4,size*4)) for _ in range(3)]
    for i,(name,rgb) in enumerate(SWATCHES.items()):
        for atlas,item in zip(atlases,swatch(name,rgb,i,size)):
            atlas.paste(Image.fromarray(item),((i%4)*size,(3-i//4)*size))
    mat=bpy.data.materials.new("Domus_courtyard_PBR")
    mat.use_nodes=True
    mat.use_backface_culling=True
    nodes,links=mat.node_tree.nodes,mat.node_tree.links
    bsdf=nodes.get("Principled BSDF")
    texture_nodes=[]
    for i,(name,pixels) in enumerate(zip(("albedo","normal","orm"),atlases)):
        path=folder/("domus_"+name+".png")
        if i==2:
            pixels=pixels.resize((192,192),Image.Resampling.BILINEAR)
        pixels.save(path)
        image=bpy.data.images.load(str(path))
        if i:
            image.colorspace_settings.name="Non-Color"
        image.pack()
        tex=nodes.new("ShaderNodeTexImage")
        tex.image=image
        texture_nodes.append(tex)
    links.new(texture_nodes[0].outputs["Color"],bsdf.inputs["Base Color"])
    normal=nodes.new("ShaderNodeNormalMap")
    normal.inputs["Strength"].default_value=.41
    links.new(texture_nodes[1].outputs["Color"],normal.inputs["Color"])
    links.new(normal.outputs["Normal"],bsdf.inputs["Normal"])
    channels=nodes.new("ShaderNodeSeparateColor")
    links.new(texture_nodes[2].outputs["Color"],channels.inputs["Color"])
    links.new(channels.outputs["Green"],bsdf.inputs["Roughness"])
    links.new(channels.outputs["Blue"],bsdf.inputs["Metallic"])
    return mat
