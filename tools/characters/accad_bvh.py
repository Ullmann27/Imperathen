"""ACCAD BVH numerical parser (source motion, no geometry)."""
from pathlib import Path
from dataclasses import dataclass
import numpy as np
from scipy.spatial.transform import Rotation as R
import re

def unit(x):
    return x / max(np.linalg.norm(x), 1e-9)

def load_bvh(data):
    raw=data.decode('utf-8',errors='strict')
    h,m=raw.split('MOTION',1)
    tokens=iter(re.findall(r'[^\s{}]+|[{}]',h))
    assert next(tokens)=='HIERARCHY'
    names=[];parents=[];offsets=[];channels=[]
    def node(kind,parent):
        name=next(tokens) if kind!='End' else names[parent]+'_end'
        if kind=='End': assert next(tokens)=='Site'
        assert next(tokens)=='{'
        idx=len(names);names.append(name);parents.append(parent);offsets.append(None);channels.append([])
        while True:
            key=next(tokens)
            if key=='}':break
            if key=='OFFSET':offsets[idx]=[float(next(tokens)) for i in range(3)]
            elif key=='CHANNELS':channels[idx]=[next(tokens) for i in range(int(next(tokens)))]
            elif key in ('JOINT','End'):node(key,idx)
            else:raise ValueError(key)
    node(next(tokens),-1)
    lines=m.strip().splitlines()
    n=int(lines[0].split(':')[1]);dt=float(lines[1].split(':')[1])
    values=np.fromstring(' '.join(lines[2:]),sep=' ').reshape(n,sum(map(len,channels)))
    position=np.zeros((n,len(names),3));rot=np.zeros((n,len(names),3,3));k=0
    for i,ch in enumerate(channels):
        p=np.broadcast_to(np.array(offsets[i]),(n,3)).copy()
        angles=[];axes=''
        for c in ch:
            v=values[:,k];k+=1
            if c.endswith('position'):p[:,'XYZ'.index(c[0])]=v
            elif c.endswith('rotation'):axes+=c[0];angles.append(v)
            else:raise ValueError(c)
        r=R.from_euler(axes,np.stack(angles,axis=1),degrees=True).as_matrix() if angles else np.broadcast_to(np.eye(3),(n,3,3))
        parent=parents[i]
        if parent<0: position[:,i]=p;rot[:,i]=r
        else:
            position[:,i]=position[:,parent]+np.einsum('nij,nj->ni',rot[:,parent],p)
            rot[:,i]=rot[:,parent]@r
    return names,position*.01,rot,dt

