import numpy as np,json,hashlib
from viva_roma_surfaces import KINDS,bake
result=[]
for k in KINDS:
    a,n,r=bake(k,(.5,.4,.3),512,42,2,.8)
    b,m,s=bake(k,(.5,.4,.3),512,42,2,.8)
    assert all(np.array_equal(x,y) for x,y in [(a,b),(n,m),(r,s)])
    shifted=bake(k,(.5,.4,.3),512,42,2,.8,offset=(13,17)); assert all(np.array_equal(x,np.roll(y,(-17,-13),axis=(0,1))) for x,y in zip(shifted,(a,n,r)))
    err=float(abs(np.linalg.norm(n*2-1,axis=2)-1).max());assert err<2e-6
    assert (n[:,:,2]>=.5).all() and np.isfinite(a).all() and np.isfinite(r).all()
    assert a.min()>0 and a.max()<1 and .15<=r.min()<=r.max()<=.99 and float(np.std(r))>.005
    sx=float(np.mean(abs(a[:,0]-a[:,-1]))); sy=float(np.mean(abs(a[0]-a[-1]))); assert sx<.075 and sy<.075, (k,sx,sy)
    result.append({'kind':k,'resolution':512,'normal_error':err,'seam_x':sx,'seam_y':sy,'roughness_std':float(np.std(r))})
for k,nx in [('paving',1024),('stone',2048)]:
    a,n,r=bake(k,(.5,.4,.3),nx,42,3,.8);assert a.shape==(nx,nx,3);assert np.max(abs(np.linalg.norm(n*2-1,axis=2)-1))<2e-6
    result.append({'kind':k,'resolution':nx,'normal_error':float(np.max(abs(np.linalg.norm(n*2-1,axis=2)-1)))})
print(json.dumps(result,indent=2))
print('SOURCE_SHA256',hashlib.sha256(open(__import__('pathlib').Path(__file__).with_name('viva_roma_surfaces.py'),'rb').read()).hexdigest())
