"""Original periodic PBR surface baker for Roman city geometry, no external art."""
import math
import numpy as np

KINDS = ('stone', 'brick', 'paving', 'roof', 'wood', 'plaster', 'marble', 'ground', 'linen', 'clay', 'basalt', 'limestone')

def bake(kind, color, size, seed, metres, roughness, offset=(0,0)):
    if kind not in KINDS or size not in (256, 512, 1024, 2048) or not math.isfinite(metres) or metres <= 0:
        raise ValueError('invalid surface parameters')
    if len(color) != 3 or not all(math.isfinite(c) and 0 <= c <= 1 for c in color) or not 0 <= roughness <= 1:
        raise ValueError('invalid surface colour or roughness')
    rng = np.random.default_rng(seed)
    u, v = np.meshgrid(((np.arange(size, dtype=np.float32)+offset[0])%size)/size, ((np.arange(size, dtype=np.float32)+offset[1])%size)/size)
    def noise(gx, gy):
        grid = rng.random((gy, gx), dtype=np.float32)
        x, y = u*gx, v*gy
        ix, iy = np.floor(x).astype(np.int32), np.floor(y).astype(np.int32)
        a, b = x-ix, y-iy
        a, b = a*a*(3-2*a), b*b*(3-2*b)
        ix, iy = ix%gx, iy%gy
        jx, jy = (ix+1)%gx, (iy+1)%gy
        return ((1-b)*((1-a)*grid[iy,ix]+a*grid[iy,jx])+b*((1-a)*grid[jy,ix]+a*grid[jy,jx])).astype(np.float32)
    def smooth(lo, hi, value):
        t = np.clip((value-lo)/(hi-lo),0,1)
        return t*t*(3-2*t)
    macro, mid, fine, grain = noise(4,4), noise(17,17), noise(73,73), noise(211,211)
    tone = .14*(macro-.5)+.11*(mid-.5)+.065*(fine-.5)+.035*(grain-.5)
    height = .002*(mid-.5)+.0007*(fine-.5)+.00025*(grain-.5)
    rough = np.full_like(u, roughness)+.12*(mid-.5)+.08*(fine-.5)
    if kind in ('stone','brick','paving'):
        if kind=='paving':
            # Irregular periodic Voronoi setts; each stone has its own weathering.
            cols, rows = 10, 9
            gx, gy = u*cols, v*rows
            ix, iy = np.floor(gx).astype(np.int32), np.floor(gy).astype(np.int32)
            jitter = rng.random((rows,cols,3), dtype=np.float32)
            first, second = np.full_like(u,100), np.full_like(u,100)
            variation = np.zeros_like(u)
            for dy in (-1,0,1):
                for dx in (-1,0,1):
                    cx,cy = ix+dx,iy+dy
                    cell=jitter[cy%rows,cx%cols]
                    dist=(gx-cx-.18-.64*cell[:,:,0])**2+(gy-cy-.18-.64*cell[:,:,1])**2
                    closer=dist<first
                    second=np.where(closer,first,np.minimum(second,dist))
                    first=np.minimum(first,dist)
                    variation=np.where(closer,cell[:,:,2],variation)
            edge=(np.sqrt(second)-np.sqrt(first))*.65
        else:
            cols, rows = (4,6) if kind=='stone' else (7,16)
            vy=v*rows+.065*(mid-.5)
            row=np.floor(vy).astype(np.int32)
            ux=u*cols+.5*(row%2)+.055*(fine-.5)
            col=np.floor(ux).astype(np.int32)
            fx,fy=ux-np.floor(ux),vy-np.floor(vy)
            edge=np.minimum(np.minimum(fx,1-fx),np.minimum(fy,1-fy))
            variation=rng.random((rows,cols),dtype=np.float32)[row%rows,col%cols]
        face=smooth(.012,.075,edge+.025*(fine-.5))
        pitting=smooth(.67,.94,fine*.65+grain*.35)
        relief=.005 if kind=='brick' else .008
        height+=relief*face-.0025*pitting*face
        tone+=.18*(variation-.5)*face-.30*(1-face)-.055*pitting
        rough+=.09*(1-face)+.07*pitting
    elif kind in ('basalt', 'limestone'):
        # Individual blocks already have modeled joints and edges. Bake only
        # mineral variation, pits and tool marks within their exposed faces.
        pores = smooth(.70,.94,fine*.64+grain*.36)
        tracks = np.sin(2*np.pi*(u*54+v*2+.28*(mid-.5)))
        tooling = smooth(.75,.98,tracks)*smooth(.39,.67,macro)
        deposits = smooth(.54,.83,macro*.62+mid*.38)
        tone += .095*deposits-.22*pores-.038*tooling
        height -= .0025*pores+.00045*tooling
        rough += .105*pores+.065*deposits
    elif kind=='roof':
        x=u*10; y=v*8
        fx,fy=x-np.floor(x),y-np.floor(y)
        arch=np.sin(np.pi*fx)**1.7
        tile=smooth(.018,.07,np.minimum(fy,1-fy))
        height+=.018*arch*tile+.004*tile
        tone+=.07*(arch-.5)-.23*(1-tile)+.09*(noise(10,8)-.5)
        rough+=.1*(1-tile)
    elif kind=='wood':
        fibres=noise(113,5); warp=noise(4,5)
        rings=np.sin(2*np.pi*(u*34+.78*(warp-.5)+.18*(mid-.5)))
        dark=np.clip(-rings,0,1)**5
        tone+=.14*(fibres-.5)+.08*rings-.09*dark
        height+=.0017*rings+.0012*(fibres-.5)-.001*dark
        rough+=.08*dark
    elif kind=='plaster':
        crack=(1-smooth(.007,.031,np.abs(mid-.52)))*smooth(.58,.81,macro)
        worn=smooth(.65,.9,macro*.6+fine*.4)
        tone-=.16*crack+.06*worn
        height-=.0016*crack+.001*worn
        rough+=.09*worn
    elif kind=='marble':
        vein=np.exp(-((np.sin(2*np.pi*(u*3+v*2+.7*(macro-.5)+.17*(mid-.5))))/.13)**2)
        tone-=.17*vein
        height+=.00015*vein
        rough-=.09*vein
    elif kind=='linen':
        warp=np.cos(2*np.pi*u*128); weft=np.cos(2*np.pi*v*128)
        weave=warp*weft
        tone+=.065*weave+.035*(warp+weft)
        height+=.00032*weave
        rough+=.035*weave
    elif kind=='clay':
        rings=np.sin(2*np.pi*(v*67+.13*(macro-.5)))
        tone+=.047*rings; height+=.00055*rings
    else:
        gravel=smooth(.62,.91,fine*.6+grain*.4)
        height+=.004*gravel; tone+=.10*gravel-.055*(1-gravel)
        rough+=.05*gravel
    # All colour values are scene-linear. Normals use tangent-space +Y.
    rgb=np.clip(np.asarray(color,dtype=np.float32)[None,None,:]*(1+tone[:,:,None]),.006,.97).astype(np.float32)
    dhdu=(np.roll(height,-1,axis=1)-np.roll(height,1,axis=1))*size/(2*metres)
    dhdv=(np.roll(height,-1,axis=0)-np.roll(height,1,axis=0))*size/(2*metres)
    normal=np.stack((-dhdu,-dhdv,np.ones_like(height)),axis=2)
    normal/=np.linalg.norm(normal,axis=2,keepdims=True)
    return rgb, (normal*.5+.5).astype(np.float32), np.clip(rough,.16,.98).astype(np.float32)

def build_blender_material(name,color,kind,out,scale,rough,metal,size,seed):
    import bpy
    mat=bpy.data.materials.new(name); mat.use_nodes=True; mat.diffuse_color=(*color,1)
    nodes,links=mat.node_tree.nodes,mat.node_tree.links
    bsdf=nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value=(*color,1)
    bsdf.inputs['Roughness'].default_value=rough; bsdf.inputs['Metallic'].default_value=metal
    if kind is None: return mat
    rgb,normal,roughmap=bake(kind,color,size,seed,scale,rough)
    def texture(suffix,data,linear):
        image=bpy.data.images.new(name+'_'+suffix,size,size,alpha=False)
        if linear: image.colorspace_settings.name='Non-Color'
        rgba=np.ones((size,size,4),dtype=np.float32)
        rgba[:,:,:3]=data if data.ndim==3 else data[:,:,None]
        image.pixels.foreach_set(rgba.ravel());image.update()
        image.filepath_raw=str(out/'textures'/(name+'_'+suffix+'.png'))
        image.file_format='PNG';image.save();image.pack()
        node=nodes.new('ShaderNodeTexImage');node.image=image;node.extension='REPEAT'
        return node
    base=texture('basecolor',rgb,False); norm=texture('normal',normal,True); rm=texture('roughness',roughmap,True)
    links.new(base.outputs['Color'],bsdf.inputs['Base Color'])
    nm=nodes.new('ShaderNodeNormalMap'); nm.inputs['Strength'].default_value=1.0
    links.new(norm.outputs['Color'],nm.inputs['Color']);links.new(nm.outputs['Normal'],bsdf.inputs['Normal'])
    links.new(rm.outputs['Color'],bsdf.inputs['Roughness'])
    return mat
