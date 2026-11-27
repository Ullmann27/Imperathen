"""Measured, pose-driven long-dress candidate for Julia only.

Adds a continuous pelvis-attached shell and five pose-driven corrective
targets, plus small static clearance. No other mesh, identity control,
texture or animation is removed. Never overwrites its input or installs
a release asset. The radial test is a sampled lower-leg check, not cloth
physics, a closed-solid collision guarantee, or an Android frame-rate claim.
"""
from __future__ import annotations
import argparse
import copy
import hashlib
import json
import math
from pathlib import Path

import numpy as np

from ground_death_clip import Glb, Rig
from smooth_frontier_skirt_seam import _triangles, _edges

NAMES = ("ClothRestClearance", "ClothKneeFront", "ClothKneeBack",
         "ClothHemFront", "ClothHemBack", "ClothSideClearance")
FLOOR_NAMES = tuple("ClothFloor"+axis+sign for axis in "XYZ" for sign in ("Pos","Neg"))
MARKER = "imperathen_julia_pose_dress_v2"
MAX_LIFT = .16
DRIVE = 2.8
AMPLITUDE = .42
SIDE = .09
STATIC_CLEARANCE = .040
BODY_LOOK = {"ID_Heavy": .05, "ID_Hem": .15}

def morph_accessor(glb, index):
    a = glb.document["accessors"][index]
    if "sparse" not in a:
        return glb.accessor(index)
    if a["type"] != "VEC3" or a["componentType"] != 5126:
        raise ValueError("Unexpected sparse morph accessor")
    sparse = a["sparse"]
    def data(row, dtype, count):
        view = glb.document["bufferViews"][row["bufferView"]]
        offset = view.get("byteOffset", 0) + row.get("byteOffset", 0)
        return np.frombuffer(glb.binary, dtype=dtype, count=count, offset=offset).copy()
    base = np.zeros((a["count"], 3), dtype=float)
    if "bufferView" in a:
        view = glb.document["bufferViews"][a["bufferView"]]
        if view.get("byteStride", 12) != 12:
            raise ValueError("Unsupported sparse base stride")
        base[:] = data(a, "<f4", a["count"] * 3).reshape(-1, 3)
    code = sparse["indices"]["componentType"]
    indices = data(sparse["indices"], {5121: "u1", 5123: "<u2", 5125: "<u4"}[code], sparse["count"])
    base[indices] = data(sparse["values"], "<f4", sparse["count"] * 3).reshape(-1, 3)
    return base

def smooth(x):
    x = np.clip(x, 0., 1.)
    return x*x*(3.-2.*x)

def mesh_of(glb, rig, part):
    return glb.document["meshes"][rig.nodes[part["node"]]["mesh"]]

def shape_positions(glb, rig, part, values):
    mesh = mesh_of(glb, rig, part)
    if len(mesh["primitives"]) != 1:
        raise ValueError("This candidate requires one primitive per body/garment")
    out = part["position"].copy()
    for i, name in enumerate(mesh.get("extras", {}).get("targetNames", [])):
        v = float(values.get(name, 0.))
        if v:
            target = mesh["primitives"][0]["targets"][i]
            out += v * morph_accessor(glb, target["POSITION"])
    return out

def parts(rig):
    body = [p for p in rig.primitives if p["name"] == "HeroBody"]
    skirt = [p for p in rig.primitives if p["name"] == "HeroTunicSkirt"]
    if len(body) != 1 or len(skirt) != 1:
        raise ValueError("Missing unique parent skin/dress primitive")
    return body[0], skirt[0]

def center_of(p):
    return np.array([np.median(p[:,0]), .5*(p[:,2].min()+p[:,2].max())])

def corrections(p, center):
    x=p[:,0]-center[0]; y=p[:,1]; z=p[:,2]-center[1]
    radial=p[:,[0,2]]-center
    base=np.zeros_like(p)
    base[:,[0,2]]=STATIC_CLEARANCE*smooth((.83-y)/.3)[:,None]*radial/np.maximum(np.linalg.norm(radial,axis=1)[:,None],.001)
    knee=smooth((.86-y)/.25)*(1.-smooth((.35-y)/.25))
    hem=smooth((.58-y)/.38)
    angle=z/np.maximum(np.sqrt((x*.62)**2+z*z),.001)
    result=[base]
    for v in (knee,hem):
        for sign in (1.,-1.):
            d=np.zeros_like(p)
            d[:,2]=sign*AMPLITUDE*v*smooth((angle*sign+.12)/.8)
            result.append(d)
    d=np.zeros_like(p)
    d[:,0]=np.sign(x)*SIDE*smooth((.85-y)/.28)*smooth(np.abs(x)/np.maximum(np.sqrt(x*x+(z*1.5)**2),.001))
    result.append(d)
    return np.asarray(result)

def floor_shapes(p):
    mask=smooth((.85-p[:,1])/.30)
    out=[]
    for axis in range(3):
        for sign in (1.,-1.):
            d=np.zeros_like(p)
            d[:,axis]=sign*MAX_LIFT*mask
            out.append(d)
    return np.asarray(out)

def transplant_skirt(destination, drig, skirt, donor, srig, source):
    # Reuse only LOD1's continuous garment topology in the far family.
    # Copy raw accessor views including sparse data and keep the far material.
    dmesh=mesh_of(destination,drig,skirt)
    smesh=mesh_of(donor,srig,source)
    old=dmesh["primitives"][0];src=smesh["primitives"][0]
    if dmesh["extras"]["targetNames"]!=smesh["extras"]["targetNames"]:
        raise ValueError("Far/donor morph layout mismatch")
    if [drig.nodes[j]["name"] for j in skirt["joints"]]!=[srig.nodes[j]["name"] for j in source["joints"]] or not np.allclose(skirt["ibm"],source["ibm"],atol=1e-6,rtol=0):
        raise ValueError("Far/donor rest skin mismatch")
    for i,j in zip(skirt["joints"],source["joints"]):
        if not all(np.allclose(a,b,atol=1e-6,rtol=0) for a,b in zip(drig.rest[i],srig.rest[j])):
            raise ValueError("Far/donor joint transforms differ")
    if src.get("extensions") or old.get("extensions"):
        raise ValueError("Compressed/extended primitive cannot be transplanted")
    view_map={};acc_map={}
    def view(idx):
        if idx in view_map:return view_map[idx]
        v=copy.deepcopy(donor.document["bufferViews"][idx])
        if v.get("buffer",0)!=0 or v.get("extensions"):
            raise ValueError("Unsupported source view")
        start=v.get("byteOffset",0);length=v["byteLength"]
        destination.binary.extend(b"\0"*(-len(destination.binary)%4))
        v["byteOffset"]=len(destination.binary)
        destination.binary.extend(donor.binary[start:start+length])
        view_map[idx]=len(destination.document["bufferViews"])
        destination.document["bufferViews"].append(v)
        return view_map[idx]
    def acc(idx):
        if idx in acc_map:return acc_map[idx]
        a=copy.deepcopy(donor.document["accessors"][idx])
        if "bufferView" in a:a["bufferView"]=view(a["bufferView"])
        if "sparse" in a:
            for key in ("indices","values"):
                x=a["sparse"][key];x["bufferView"]=view(x["bufferView"])
        acc_map[idx]=len(destination.document["accessors"])
        destination.document["accessors"].append(a)
        return acc_map[idx]
    new=copy.deepcopy(src)
    new["attributes"]={k:acc(i) for k,i in src["attributes"].items()}
    new["indices"]=acc(src["indices"])
    new["targets"]=[{k:acc(i) for k,i in t.items()} for t in src.get("targets",[])]
    if "material" in old:new["material"]=old["material"]
    else:new.pop("material",None)
    dmesh["primitives"]=[new]
    dmesh["extras"]["preserved_dress_topology"]="LOD1"
    dmesh["weights"]=list(smesh["weights"])
    return len(donor.accessor(src["indices"]))//3, len(destination.accessor(old["indices"]))//3

def normal_field(positions,tri,weld):
    t=positions[tri]
    face=np.cross(t[:,1]-t[:,0],t[:,2]-t[:,0])
    n=np.zeros((int(weld.max())+1,3))
    for corner in range(3):
        np.add.at(n,weld[tri[:,corner]],face)
    n=n[weld]
    return n/np.maximum(np.linalg.norm(n,axis=1)[:,None],1e-12)

def install(source:Path, target:Path, donor_path:Path|None=None):
    if source.resolve()==target.resolve() or target.exists():
        raise ValueError("Use a new candidate path; preserve original GLB")
    if not source.name.startswith("frontier_parent_julia_"):
        raise ValueError("Only the dedicated Julia family has calibrated geometry")
    glb=Glb(source);rig=Rig(glb);_,skirt=parts(rig)
    topology=None
    if donor_path is not None:
        donor=Glb(donor_path);srig=Rig(donor);_,sp=parts(srig)
        topology=transplant_skirt(glb,rig,skirt,donor,srig,sp)
        rig=Rig(glb);_,skirt=parts(rig)
    mesh=mesh_of(glb,rig,skirt);prim=mesh["primitives"][0]
    if MARKER in mesh.get("extras",{}):
        raise ValueError("Already fitted")
    names=mesh.get("extras",{}).get("targetNames",[])
    if not {"ID_Heavy","ID_Hem"}<=set(names) or any(n in names for n in NAMES):
        raise ValueError("Unexpected authored garment morph contract")
    if any(c["target"]["path"]=="weights" and c["target"].get("node")==skirt["node"]
           for a in glb.document["animations"] for c in a["channels"]):
        raise ValueError("Existing garment morph animation must not be replaced")
    pos=shape_positions(glb,rig,skirt,BODY_LOOK)
    center=center_of(pos)
    deltas=np.concatenate([corrections(pos,center),floor_shapes(pos)])
    tri=_triangles(glb,skirt["node"])[0].reshape(-1,3)
    _,weld=np.unique(np.round(skirt["position"]/1e-5).astype(np.int64),axis=0,return_inverse=True)
    weld=weld.reshape(-1)
    base_normal=normal_field(pos,tri,weld)
    indices=np.zeros_like(skirt["joint_index"])
    pelvis=skirt["joints"].index(rig.pelvis)
    indices[:]=pelvis
    weights=np.zeros_like(skirt["weight"]);weights[:,0]=1.
    glb.overwrite_accessor(prim["attributes"]["JOINTS_0"],indices)
    glb.overwrite_accessor(prim["attributes"]["WEIGHTS_0"],weights)
    for d in deltas:
        normal=normal_field(pos+d,tri,weld)-base_normal
        prim.setdefault("targets",[]).append({"POSITION":glb.append_accessor(d,"VEC3"),
                                               "NORMAL":glb.append_accessor(normal,"VEC3")})
    mesh["extras"]["targetNames"]=list(names)+list(NAMES)+list(FLOOR_NAMES)
    mesh["extras"][MARKER]={"source_sha256":hashlib.sha256(source.read_bytes()).hexdigest(),
                            "scale":DRIVE,"amplitude_m":AMPLITUDE,"side_m":SIDE,
                            "static_m":STATIC_CLEARANCE,"identity":BODY_LOOK,"floor_lift_cap_m":MAX_LIFT,
                            "topology_triangles":topology}
    mesh["weights"]=list(mesh.get("weights",[0.]*len(names)))+[1.]+[0.]*(len(NAMES)+len(FLOOR_NAMES)-1)
    target.parent.mkdir(parents=True,exist_ok=True)
    # Rewrites to newly appended donor views are not original-byte edits.
    # Keep the original-buffer proof exact; reject any crossing its boundary.
    boundary=len(glb.original_binary)
    if any(a<boundary<b for a,b in glb.rewritten):
        raise AssertionError("Accessor crosses original buffer boundary")
    glb.rewritten=[(a,b) for a,b in glb.rewritten if b<=boundary]
    glb.write(target)

def blend(part,world):
    m=np.stack([world[j]@part["ibm"][k] for k,j in enumerate(part["joints"])])
    return np.sum(m[part["joint_index"]]*part["weight"][:,:,None,None],axis=1)

def pose(mat,transform,verts):
    return (np.einsum("nij,nj->ni",mat,np.c_[verts,np.ones(len(verts))])@transform.T)[:,:3]

def drive_values(dz):
    k=[dz["Shin_L"],dz["Shin_R"]];a=[dz["Foot_L"],dz["Foot_R"]]
    return np.clip(np.array([1.,max(k)*DRIVE,-min(k)*DRIVE,max(a)*DRIVE,-min(a)*DRIVE,
                            max(abs(v) for v in dz.values())*3.]),0.,1.)

def floor_values(pos, matrix, mask, ground=0.):
    # Skin is a single pelvis transform. Solve the maximum required shift
    # along world up, weighted by lower-cloth mask; never move waistband.
    ys=(np.c_[pos,np.ones(len(pos))]@matrix.T)[:,1]
    needed=np.maximum(ground-ys,0.)
    active=mask>1e-5
    lift=float((needed[active]/mask[active]).max(initial=0.))
    unresolved=float(needed[~active].max(initial=0.))
    local=np.linalg.solve(matrix[:3,:3],np.array([0.,1.,0.]))
    values=np.clip(np.column_stack((local,-local)).ravel()*lift/MAX_LIFT,0.,1.)
    return values,lift,unresolved

def radial_penetration(skirt,tri,body,center):
    v=skirt[tri];a=v[:,0];e1=v[:,1]-a;e2=v[:,2]-a
    n=np.cross(e1,e2)
    d00=(e1*e1).sum(1);d01=(e1*e2).sum(1);d11=(e2*e2).sum(1)
    det=d00*d11-d01*d01;good=det>1e-13
    # Interior height interval, excluding open garment edges by 25 mm.
    body=body[(body[:,1]>skirt[:,1].min()+.025)&(body[:,1]<skirt[:,1].max()-.025)]
    if not len(body):
        return np.zeros(0),0
    radial=body[:,[0,2]]-center;distance=np.linalg.norm(radial,axis=1)
    dirs=np.c_[radial[:,0],np.zeros(len(body)),radial[:,1]]/np.maximum(distance[:,None],1e-8)
    origin=np.c_[np.full(len(body),center[0]),body[:,1],np.full(len(body),center[1])]
    depths=[];miss=0
    for i in range(0,len(body),128):
        o=origin[i:i+128];d=dirs[i:i+128]
        den=d@n.T
        num=(a*n).sum(1)[None,:]-o@n.T
        t=num/np.where(np.abs(den)>1e-9,den,1.)
        hit=o[:,None,:]+t[:,:,None]*d[:,None,:]-a[None,:,:]
        u=np.einsum("btj,tj->bt",hit,e1);v=np.einsum("btj,tj->bt",hit,e2)
        alpha=(u*d11-v*d01)/np.maximum(det,1e-13)
        beta=(v*d00-u*d01)/np.maximum(det,1e-13)
        valid=(np.abs(den)>1e-9)&good&(t>0)&(alpha>=-1e-5)&(beta>=-1e-5)&(alpha+beta<=1.00001)
        r=np.where(valid,t,-np.inf).max(1)
        ok=np.isfinite(r);miss+=int((~ok).sum())
        depths.extend((distance[i:i+len(o)][ok]-r[ok]).tolist())
    return np.asarray(depths),miss

def measure(path:Path,hz:int):
    glb=Glb(path);rig=Rig(glb);body,skirt=parts(rig)
    smesh=mesh_of(glb,rig,skirt)
    fitted=MARKER in smesh.get("extras",{})
    sp=shape_positions(glb,rig,skirt,BODY_LOOK)
    bp=shape_positions(glb,rig,body,BODY_LOOK)
    center=center_of(sp)
    tri=_triangles(glb,skirt["node"])[0].reshape(-1,3)
    edges=_edges(tri.ravel())
    pos0=shape_positions(glb,rig,skirt,{**BODY_LOOK,"ClothRestClearance":1.}) if fitted else sp
    rest_len=np.linalg.norm(skirt["position"][edges[:,0]]-skirt["position"][edges[:,1]],axis=1)
    shapes=[]
    if fitted:
        if not all(n in smesh["extras"]["targetNames"] for n in (*NAMES,*FLOOR_NAMES)):
            raise ValueError("Incomplete corrective shape family")
        if not np.allclose(skirt["weight"][:,0],1.) or np.any(skirt["joint_index"][:,0]!=skirt["joints"].index(rig.pelvis)):
            raise ValueError("Fitted skirt must be continuously pelvis-bound")
        for name in (*NAMES,*FLOOR_NAMES):
            i=smesh["extras"]["targetNames"].index(name)
            shapes.append(morph_accessor(glb,smesh["primitives"][0]["targets"][i]["POSITION"]))
    names={n.get("name"):i for i,n in enumerate(rig.nodes)}
    rest=rig.globals({"tracks":{}},0.);rp=rest[rig.pelvis]
    inv=np.linalg.inv(rp)
    ref={n:(inv@rest[names[n]])[:3,3] for n in ["Shin_L","Shin_R","Foot_L","Foot_R"]}
    jnames=[rig.nodes[j]["name"] for j in body["joints"]]
    legs=np.isin(body["joint_index"],[i for i,n in enumerate(jnames) if n.startswith(("Thigh_","Shin_","Foot_","Toe_"))])
    select=(np.sum(body["weight"]*legs,axis=1)>.6)&(body["position"][:,1]>.055)&(body["position"][:,1]<.85)
    clips={}
    for a in glb.document["animations"]:
        clip=a["name"];anim=rig.animation(clip)
        count=max(2,math.ceil(anim["duration"]*hz))
        row={"peak_m":0.,"samples":0,"outside_gt_10mm":0,"uncovered_rays":0,"frames":0,
             "tear_events":0,"minimum_world_y":1e9,"max_width_m":0.,
             "max_floor_lift_m":0.,"unresolved_floor_m":0.}
        for i in range(count+1):
            w=rig.globals(anim,anim["duration"]*i/count);ip=np.linalg.inv(w[rig.pelvis])
            tf=rp@ip
            dz={n:float(((ip@w[names[n]])[:3,3]-ref[n])[2]) for n in ref}
            mat=blend(skirt,w)
            pos=sp
            if fitted:
                pos=sp+np.einsum("k,kij->ij",drive_values(dz),np.asarray(shapes[:len(NAMES)]))
                mask=np.asarray(shapes[len(NAMES)+2])[:,1]/MAX_LIFT
                fv,lift,unresolved=floor_values(pos,mat[0],mask)
                row["max_floor_lift_m"]=max(row["max_floor_lift_m"],lift)
                row["unresolved_floor_m"]=max(row["unresolved_floor_m"],unresolved)
                pos=pos+np.einsum("k,kij->ij",fv,np.asarray(shapes[len(NAMES):]))
            sk_world=pose(mat,np.eye(4),pos)
            sk=pose(mat,tf,pos)
            leg=pose(blend(body,w)[select],tf,bp[select])
            depth,miss=radial_penetration(sk,tri,leg,center)
            length=np.linalg.norm(sk[edges[:,0]]-sk[edges[:,1]],axis=1)
            row["peak_m"]=max(row["peak_m"],float(max(0.,depth.max(initial=0))))
            row["samples"]+=len(depth);row["outside_gt_10mm"]+=int((depth>.01).sum())
            row["uncovered_rays"]+=miss;row["frames"]+=1
            row["tear_events"]+=int((length>rest_len*7.+.03).sum())
            row["minimum_world_y"]=min(row["minimum_world_y"],float(sk_world[:,1].min()))
            row["max_width_m"]=max(row["max_width_m"],float(np.ptp(sk[:,0])))
        clips[clip]=row
    return {"file":path.name,"sha256":hashlib.sha256(path.read_bytes()).hexdigest(),
            "fitted":fitted,"sample_hz":hz,"clips":clips}

def main():
    p=argparse.ArgumentParser()
    p.add_argument("--source-dir",required=True,type=Path)
    p.add_argument("--output",required=True,type=Path)
    p.add_argument("--hz",type=int,default=60)
    a=p.parse_args()
    if not 12<=a.hz<=120:raise ValueError("Use 12–120 Hz")
    a.output.mkdir(parents=True,exist_ok=True)
    results=[]
    for level in range(4):
        name=f"frontier_parent_julia_{level}.glb"
        source=a.source_dir/name;target=a.output/name
        install(source,target,a.source_dir/"frontier_parent_julia_1.glb" if level>=2 else None)
        old=measure(source,a.hz);new=measure(target,a.hz)
        results.append({"lod":level,"original":old,"candidate":new})
        print("DRESS_SAMPLE",level,json.dumps({k:{"before_mm":round(old["clips"][k]["peak_m"]*1000,1),
                                                 "after_mm":round(v["peak_m"]*1000,1),
                                                 "outside":v["outside_gt_10mm"],"rays_missing":v["uncovered_rays"],
                                                 "tears":v["tear_events"],"floor_y":round(v["minimum_world_y"],3),"lift":round(v["max_floor_lift_m"],3)}
                                                 for k,v in new["clips"].items()}),flush=True)
        (a.output/"dress-validation.json").write_text(json.dumps({
            "scope":"GLB exported clip samples, pelvis-relative radial lower-leg clearance; excludes open hem/top by 25mm, not all collisions or runtime procedural poses.",
            "results":results},indent=2)+"\n")
    problems=[]
    for r in results:
        for clip,v in r["candidate"]["clips"].items():
            if v["peak_m"]>.01 or v["tear_events"] or v["uncovered_rays"] or v["minimum_world_y"]<-.002 or v["unresolved_floor_m"]>.002 or v["max_floor_lift_m"]>MAX_LIFT:
                problems.append({"lod":r["lod"],"clip":clip,"result":v})
    print("DRESS_CANDIDATES_EXPORTED",len(results),"UNACCEPTED_ROWS",len(problems),flush=True)
    if problems:
        (a.output/"unaccepted.json").write_text(json.dumps(problems,indent=2)+"\n")
        raise SystemExit(1)
if __name__=="__main__":
    main()
