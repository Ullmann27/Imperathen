#!/usr/bin/env python3
"""Retarget measured ACCAD human motion to the unchanged 35-joint Meshy youth.

Append motion and, only when actual sampled edge deformation improves,
corrected garment weight accessors. Positions, topology, materials, inverse
bind matrices and node rest transforms remain unchanged. CharacterBody owns travel.
"""
from __future__ import annotations
import argparse, hashlib, json, math, struct, urllib.request, zipfile
from pathlib import Path
import numpy as np
from scipy.spatial.transform import Rotation as R
from accad_bvh import load_bvh, unit
from youth_skin_polish import repair
from youth_anatomy import calibrate_soles,source_foot_angles,foot_global,toe_global,neutral_idle,original_structure,remove_start_weapon

SOURCE_URL="https://accad.ohio-state.edu/sites/accad.osu.edu/files/Male2_bvh.zip"
SOURCE_SHA="f30dc56f8557d4b9f1bd6b8b0c4218c076471de0a9c1a20f3bc4a8b776cc14b1"
SOURCE_CREDIT="Open Motion Project by ACCAD/The Ohio State University, CC BY 3.0; adapted, trimmed, retargeted and grounded by IMPERATHEN. https://accad.ohio-state.edu/research/motion-lab/mocap-system-and-data ; https://creativecommons.org/licenses/by/3.0/"
GAITS={"march":("Male2_B3_Walk.bvh",249,369,0.56),"run":("Male2_C3_Run.bvh",16,39,0.35)}
# Peak timing matches the existing domain's active contact window. No gameplay
# damage, reach, stamina or entitlement is changed by these tracks.
FIGHT={
 "jab_left":("Male2_E1_JabLeft.bvh","Left","hand",.62,.25),
 "jab_right":("Male2_E2_JabRight.bvh","Right","hand",.68,.28),
 "hook_left":("Male2_E5_HookLeft.bvh","Left","hand",.82,.35),
 "hook_right":("Male2_E6_HookRight.bvh","Right","hand",.82,.35),
 "uppercut_left":("Male2_E7_UppercutLeft.bvh","Left","hand",.9,.385),
 "uppercut_right":("Male2_E8_UppercutRight.bvh","Right","hand",.9,.385),
 "front_kick":("Male2_G2_FrontKick.bvh","Right","foot",1.05,.44),
 "side_kick":("Male2_G3_SidekickLeadingRight.bvh","Right","foot",1.2,.51),
 "block":("Male2_E13_BlockRightHigh.bvh","Right","hand",.85,.33),
}
TYPE_N={"SCALAR":1,"VEC2":2,"VEC3":3,"VEC4":4,"MAT4":16}
DTYPE={5120:np.int8,5121:np.uint8,5122:np.int16,5123:np.uint16,5125:np.uint32,5126:np.float32}
UP=np.array([0.,1.,0.])
def digest(b):return hashlib.sha256(b).hexdigest()
def frame(left,up):
    x=unit(left);y=unit(up-x*np.dot(x,up));z=unit(np.cross(x,y))
    return np.stack([x,y,z],axis=1)
def foot_frame(forward,across):
    # Resolve twist around the toe direction using the measured lateral
    # orientation instead of an arbitrary minimal-swing ankle rotation.
    z=unit(forward);x=across-z*np.dot(across,z)
    if np.linalg.norm(x)<1e-6:
        axis=np.eye(3)[np.argmin(abs(z))];x=axis-z*np.dot(axis,z)
    x=unit(x);y=unit(np.cross(z,x))
    return np.stack([x,y,z],axis=1)

def swing(a,b):
    a,b=unit(a),unit(b);dot=np.clip(np.dot(a,b),-1,1)
    cross=np.cross(a,b);s=np.linalg.norm(cross)
    if s<1e-8:
        if dot>0:return np.eye(3)
        axis=unit(np.cross(a,np.eye(3)[np.argmin(abs(a))]))
        return R.from_rotvec(axis*math.pi).as_matrix()
    return R.from_rotvec(cross/s*math.atan2(s,dot)).as_matrix()

def decode(path):
    raw=path.read_bytes()
    if struct.unpack_from("<4sII",raw)!=(b"glTF",2,len(raw)):raise ValueError("Invalid GLB")
    n,kind=struct.unpack_from("<II",raw,12)
    assert kind==0x4e4f534a
    d=json.loads(raw[20:20+n]); k,size_kind=struct.unpack_from("<II",raw,20+n)
    assert size_kind==0x004e4942 and 28+n+k==len(raw)
    return d,bytearray(raw[28+n:])

def encode(d,b):
    d["buffers"][0]["byteLength"]=len(b)
    j=json.dumps(d,ensure_ascii=False,separators=(",",":")).encode()
    j+=b" "*(-len(j)%4); b+=b"\0"*(-len(b)%4)
    return struct.pack("<4sII",b"glTF",2,28+len(j)+len(b))+struct.pack("<II",len(j),0x4e4f534a)+j+struct.pack("<II",len(b),0x004e4942)+b

def read_access(d,b,i):
    a=d["accessors"][i];v=d["bufferViews"][a["bufferView"]]
    dt=np.dtype(DTYPE[a["componentType"]]).newbyteorder("<");n=TYPE_N[a["type"]]
    start=v.get("byteOffset",0)+a.get("byteOffset",0)
    out=np.ndarray((a["count"],n),dtype=dt,buffer=b,offset=start,strides=(v.get("byteStride",dt.itemsize*n),dt.itemsize)).copy()
    if a.get("normalized"):out=out.astype(float)/np.iinfo(dt).max
    return out

class Target:
    def __init__(self,d,b):
        self.d=d;self.b=b
        self.nodes=d["nodes"];self.joints=d["skins"][0]["joints"];self.ids={self.nodes[i]["name"]:i for i in self.joints}
        if len(self.ids)!=35:raise ValueError("Expected confirmed original 35-joint youth")
        self.parent={c:i for i,node in enumerate(self.nodes) for c in node.get("children",[])}
        self.t={i:np.array(n.get("translation",[0,0,0]),float) for i,n in enumerate(self.nodes)}
        self.r={i:R.from_quat(n.get("rotation",[0,0,0,1])).as_matrix() for i,n in enumerate(self.nodes)}
        self.order=[]
        def visit(i):
            if i in self.joints:self.order.append(i)
            for c in self.nodes[i].get("children",[]):visit(c)
        visit(self.ids["Pelvis"])
        if set(self.order)!=set(self.joints):raise ValueError("Unexpected original joint hierarchy")
        self.rest_r,self.rest_p=self.fk({})
        self.hips=self.ids["Pelvis"]
        self.pelvis_frame=frame(self.pos("Thigh_L")-self.pos("Thigh_R"),UP)
        self.spine_frame=frame(self.pos("Arm_L")-self.pos("Arm_R"),self.pos("Head")-self.pos("Pelvis"))
        self.leg_length=sum(np.linalg.norm(self.t[self.ids[x]]) for x in ("Shin_R","Foot_R"))
        self.foot_points={}
        self.review_poses={}
        self.foot_frames={}
        for side in ("L","R"):
            self.foot_frames["Foot_"+side]=foot_frame(self.pos("Toe_"+side)-self.pos("Foot_"+side),self.pelvis_frame[:,0])
            self.foot_frames["Toe_"+side]=foot_frame(self.rest_r[self.ids["Toe_"+side]]@UP,self.pelvis_frame[:,0])
        inv=read_access(d,b,d["skins"][0]["inverseBindMatrices"]).reshape(-1,4,4).transpose(0,2,1)
        # Real lower sole vertices from original textured skin, not a capsule
        # approximation. Exclude the sword mesh from grounding.
        body=next(n for n in self.nodes if n.get("name")=="MeshyYouthBody")
        for primitive in d["meshes"][body["mesh"]]["primitives"]:
            a=primitive["attributes"]
            if not {"POSITION","JOINTS_0","WEIGHTS_0"}.issubset(a):continue
            v=read_access(d,b,a["POSITION"])
            j=read_access(d,b,a["JOINTS_0"]).astype(int)
            w=read_access(d,b,a["WEIGHTS_0"])
            for side,sign in (("L",1),("R",-1)):
                ids={self.ids["Foot_"+side],self.ids["Toe_"+side]}
                match=np.isin(j,[self.joints.index(i) for i in ids])
                mask=(v[:,1]<.065)&(v[:,0]*sign>0)&((w*match).sum(1)>.6)
                if not mask.any():continue
                # Sample bounded points, retaining lowest real sole vertices.
                ii=np.flatnonzero(mask);ii=ii[np.argsort(v[ii,1])[:384]]
                pts=np.concatenate([v[ii],np.ones((len(ii),1))],axis=1)
                local=np.einsum("nkij,nj->nki",inv[j[ii]],pts)
                self.foot_points.setdefault(side,[]).append((j[ii],w[ii],local))
        if set(self.foot_points)!={"L","R"}:raise ValueError("Both actual soles must be sampled")
        self.sole_frames=calibrate_soles(self,read_access)
    def pos(self,n):return self.rest_p[self.ids[n]]
    def fk(self,rot,shift=None):
        g={};p={}
        for i in self.order:
            par=self.parent.get(i);pr=g.get(par,np.eye(3));pp=p.get(par,np.zeros(3))
            g[i]=pr@rot.get(i,self.r[i]);p[i]=pp+pr@self.t[i]
            if i==self.order[0] and shift is not None:p[i]+=shift
        return g,p
    def sole(self,g,p,side):
        out=[]
        for j,w,local in self.foot_points[side]:
            matrices=np.stack([np.column_stack([g[i],p[i]]) for i in self.joints])
            point=np.einsum("nkij,nkj->nki",matrices[j],local)
            out.append((point*w[...,None]).sum(1)[:,1].min())
        return float(min(out))
    def pose(self,src,names,A,foot_angles):
        idx={n:i for i,n in enumerate(names)}
        v=lambda a,b:A@(src[idx[b]]-src[idx[a]])
        desired={}
        desired["Pelvis"]=frame(v("RightUpLeg","LeftUpLeg"),UP)@self.pelvis_frame.T@self.rest_r[self.hips]
        desired["Spine"]=frame(v("RightArm","LeftArm"),v("Hips","Neck"))@self.spine_frame.T@self.rest_r[self.ids["Spine"]]
        axes={"Head":("Head","Head_end",self.rest_r[self.ids["Head"]]@UP)}
        for side,srcside in (("L","Left"),("R","Right")):
            for target,a,b,next_target in (
                ("Arm", "Arm","ForeArm","Forearm"),("Forearm","ForeArm","Hand","Hand"),
                ("Thigh","UpLeg","Leg","Shin"),("Shin","Leg","Foot","Foot"),
                ("Foot","Foot","ToeBase","Toe")):
                child=self.ids[next_target+"_"+side]
                axes[target+"_"+side]=(srcside+a,srcside+b,self.t[child])
            axes["Hand_"+side]=(srcside+"Hand",srcside+"Hand_end",UP)
            axes["Clavicle_"+side]=(srcside+"Shoulder",srcside+"Arm",UP)
            axes["Toe_"+side]=(srcside+"ToeBase",srcside+"ToeBase_end",UP)
        # Retarget limb directions, not source Euler angles. ACCAD's original
        # bone rolls differ drastically from the fitted non-T-pose Meshy rig.
        local={};glob={}
        for i in self.order:
            name=self.nodes[i]["name"];par=self.parent.get(i);pr=glob.get(par,np.eye(3))
            base=pr@self.r[i]
            if name in desired:g=desired[name]
            elif name in axes:
                a,b,axis=axes[name]
                if name=="Head":axis=UP
                direction=v(a,b)
                if name.startswith("Foot_"):
                    g=foot_global(self,name[-1],foot_angles[name[-1]][0])
                elif name.startswith("Toe_"):
                    g=toe_global(self,name[-1],pr,foot_angles[name[-1]][1])
                else:g=swing(base@axis,direction)@base
            else:g=base
            local[i]=pr.T@g;glob[i]=g
        return local
    def append(self,array,kind,component_type=5126):
        array=np.asarray(array,dtype=np.dtype(DTYPE[component_type]).newbyteorder("<")).reshape(-1,TYPE_N[kind]);raw=array.tobytes()
        self.b+=b"\0"*(-len(self.b)%4);start=len(self.b);self.b+=raw
        self.d["bufferViews"].append({"buffer":0,"byteOffset":start,"byteLength":len(raw)})
        a={"bufferView":len(self.d["bufferViews"])-1,"componentType":component_type,"count":len(array),"type":kind}
        if kind=="SCALAR":a.update(min=[float(array.min())],max=[float(array.max())])
        self.d["accessors"].append(a);return len(self.d["accessors"])-1
    def animation(self,name,seconds,rotations,shifts):
        count=len(shifts);times=self.append(np.linspace(0,seconds,count),"SCALAR")
        samplers=[];channels=[]
        for i in self.order:
            q=R.from_matrix(np.array([p[i] for p in rotations])).as_quat()
            for f in range(1,len(q)):
                if np.dot(q[f],q[f-1])<0:q[f]*=-1
            out=self.append(q,"VEC4")
            channels.append({"sampler":len(samplers),"target":{"node":i,"path":"rotation"}})
            samplers.append({"input":times,"output":out,"interpolation":"LINEAR"})
        out=self.append(np.array(shifts)+self.t[self.hips],"VEC3")
        channels.append({"sampler":len(samplers),"target":{"node":self.hips,"path":"translation"}})
        samplers.append({"input":times,"output":out,"interpolation":"LINEAR"})
        a={"name":name,"channels":channels,"samplers":samplers,"extras":{"source":SOURCE_CREDIT}}
        self.d["animations"]=[x for x in self.d["animations"] if x.get("name")!=name]+[a]

def interpolate(p,frames):
    base=np.floor(frames).astype(int);end=np.minimum(base+1,len(p)-1)
    f=(frames-base).reshape(-1,1,1)
    return p[base]*(1-f)+p[end]*f

def adapt(target,z,name,spec):
    file=spec[0];names,p,source_rotation,dt=load_bvh(z.read(file));idx={n:i for i,n in enumerate(names)}
    gait=name in GAITS
    hips=p[:,idx["Hips"]];source_length=np.linalg.norm(p[0,idx["RightLeg"]]-p[0,idx["RightUpLeg"]])+np.linalg.norm(p[0,idx["RightFoot"]]-p[0,idx["RightLeg"]])
    scale=target.leg_length/source_length
    if gait:
        start,end,stance=spec[1:];seconds=(end-start)*dt;frames=np.linspace(start,end,round(seconds*60)+1)
        travel=hips[end]-hips[start];travel[1]=0
        forward=unit(travel);left=unit(np.cross(UP,forward));A=np.stack([left,UP,forward])
        if np.dot(A[0],np.mean((p[start:end,idx["LeftUpLeg"]]-p[start:end,idx["RightUpLeg"]]),axis=0))<0:raise ValueError("Reversed left/right source orientation")
        peak=None
    else:
        _,side,kind,seconds,impact=spec
        joint=side+("Hand" if kind=="hand" else "Foot");parent=side+("Arm" if kind=="hand" else "UpLeg")
        reach=np.linalg.norm(p[:,idx[joint]]-p[:,idx[parent]],axis=1)
        if kind=="foot" or name=="block":
            # The recorded lifted-foot / high-guard apex is the visual event.
            reach=p[:,idx[joint],1]
        # Ignore the outer rest frames; find the actual maximal extension.
        trim=max(2,int(.15/dt))
        peak=int(np.argmax(reach[trim:len(p)-trim])+trim)
        start=max(0,peak-int(.42/dt));end=min(len(p)-1,peak+int(.45/dt))
        if not start<peak<end:raise ValueError("Invalid source strike crop")
        axis=p[start:min(start+5,len(p)),idx["LeftUpLeg"]]-p[start:min(start+5,len(p)),idx["RightUpLeg"]]
        across=np.mean(axis,axis=0);across[1]=0;left=unit(across);forward=np.cross(left,UP);A=np.stack([left,UP,forward])
        t=np.linspace(0,seconds,round(seconds*60)+1)
        frames=np.interp(t,[0,impact,seconds],[start,peak,end]);stance=None
    samples=interpolate(p,frames)
    root=(samples[:,idx["Hips"]]-samples[0,idx["Hips"]])@A.T*scale
    if gait:
        root-=np.linspace(0,1,len(root))[:,None]*np.array([root[-1,0],0,root[-1,2]])
    else:
        root[:,[0,2]]=np.clip(root[:,[0,2]],-.09,.09)
    # Preserve measured phase, relative root sway and vertical height. Ground
    # against actual skin soles while retaining the recorded airborne run.
    source_toes=np.stack([samples[:,idx[x],1] for x in ("LeftToeBase","RightToeBase","LeftFoot","RightFoot")],axis=1)
    floor=float(np.percentile(source_toes,2));flight=np.maximum(0.,source_toes.min(axis=1)-floor)*scale if name=="run" else np.zeros(len(root))
    angles=source_foot_angles(samples,idx,A,start,end,p,gait,name)
    rotations=[target.pose(s,names,A,{side:values[i] for side,values in angles.items()}) for i,s in enumerate(samples)]
    if gait:
        # Close the cycle at identical local rotations, correcting drift
        # progressively; no hard discontinuity at the 60 Hz loop boundary.
        for i in target.order:
            start_r=rotations[0][i];end_r=rotations[-1][i]
            correction=R.from_matrix(end_r.T@start_r).as_rotvec()
            for j,u in enumerate(np.linspace(0,1,len(root))):
                rotations[j][i]=rotations[j][i]@R.from_rotvec(correction*u).as_matrix()
        root[-1]=root[0]
        flight[-1]=flight[0]
    ground=[];shifts=[];max_segment_error=0.
    for i,rot in enumerate(rotations):
        shift=root[i].copy()
        g,pts=target.fk(rot,shift)
        lowest=min(target.sole(g,pts,side) for side in ("L","R"))
        # Translation on hips only; rest offsets and rig lengths never change.
        shift[1]+=float(flight[i])-lowest
        if not np.isfinite(shift).all() or abs(shift[1])>.28:raise ValueError(f"{name}: excessive pelvis shift {shift[1]:.3f}")
        g,pts=target.fk(rot,shift)
        min_y=min(target.sole(g,pts,side) for side in ("L","R"))
        if min_y<-.002:raise ValueError(f"{name}: sole below floor {min_y}")
        ground.append(min_y)
        for bone in target.order:
            parent=target.parent.get(bone)
            if parent in pts:
                err=abs(np.linalg.norm(pts[bone]-pts[parent])-np.linalg.norm(target.t[bone]))
                max_segment_error=max(max_segment_error,float(err))
        shifts.append(shift)
    if gait:
        shifts[-1]=shifts[0].copy()
    target.animation(name,seconds,rotations,shifts)
    target.review_poses[name]=(rotations,shifts)
    result={"file":file,"source_sha256":digest(z.read(file)),"source_frames":[int(start),int(end)],"source_hz":round(1/dt,3),"seconds":round(float(seconds),6),"frames":len(shifts),"max_segment_error_m":max_segment_error,"min_sampled_sole_m":float(min(ground)),"max_sampled_sole_m":float(max(ground))}
    if gait:
        result["stride_m"]=round(float(np.dot(hips[end]-hips[start],A[2])*scale),5);result["stance_fraction"]=stance
        result["sole_clearance_curve_m"]=[round(float(max(0.,x)),5) for x in ground]
    else:result["source_impact_frame"]=peak;result["domain_impact_seconds"]=impact
    return result

def main():
    arg=argparse.ArgumentParser()
    arg.add_argument("--archive",type=Path,required=True);arg.add_argument("--input",type=Path,required=True)
    arg.add_argument("--output",type=Path,required=True);arg.add_argument("--report",type=Path,required=True)
    a=arg.parse_args()
    if not a.archive.is_file():
        with urllib.request.urlopen(SOURCE_URL,timeout=60) as response:raw=response.read(12_000_001)
        if digest(raw)!=SOURCE_SHA:raise ValueError("Unverified ACCAD archive")
        a.archive.parent.mkdir(parents=True,exist_ok=True);a.archive.write_bytes(raw)
    if digest(a.archive.read_bytes())!=SOURCE_SHA:raise ValueError("Wrong ACCAD archive hash")
    a.output.mkdir(parents=True,exist_ok=True)
    report={"schema":1,"source":SOURCE_URL,"source_sha256":SOURCE_SHA,"credit":SOURCE_CREDIT,"rig_joints":35,"method":"direction-based 60 Hz skeletal retarget, real skin sole grounding; in-place root with measured stride; no gameplay mutation","lods":[]}
    with zipfile.ZipFile(a.archive) as z:
        for i in range(4):
            path=a.input/f"hero_meshy_italia_{i}.glb";d,b=decode(path);t=Target(d,b)
            original_buffer_size=len(b);original_buffer_sha=digest(b)
            immutable=digest(json.dumps(original_structure(d),sort_keys=True,separators=(",",":")).encode())
            records={name:adapt(t,z,name,spec) for name,spec in {**GAITS,**FIGHT}.items()}
            records["idle"]=neutral_idle(t,read_access)
            surface_review=repair(t,read_access)
            weapon_review=remove_start_weapon(t,read_access)
            print("YOUTH_WEAPON_REVIEW",i,json.dumps(weapon_review),flush=True)
            assert digest(b[:original_buffer_size])==original_buffer_sha
            assert immutable==digest(json.dumps(original_structure(d),sort_keys=True,separators=(",",":")).encode())
            print("YOUTH_SURFACE_REVIEW",i,json.dumps(surface_review),flush=True)
            d["asset"].setdefault("extras",{})["motion_credit"]=SOURCE_CREDIT
            out=a.output/path.name;out.write_bytes(encode(d,b))
            report["lods"].append({"level":i,"sha256":digest(out.read_bytes()),"original_sha256":digest(path.read_bytes()),"clips":records,"original_mesh_skin_materials_and_binary_preserved":False,"original_positions_materials_bind_matrices_preserved":True,"original_binary_prefix_preserved":True,"surface_review":surface_review,"weapon_review":weapon_review})
            print("ACCAD_RETARGET_LOD",i,"clips",len(records),flush=True)
    report["gaits"]={k:report["lods"][0]["clips"][k] for k in GAITS}
    a.report.parent.mkdir(parents=True,exist_ok=True);a.report.write_text(json.dumps(report,indent=2)+"\n")
    print("ACCAD_RETARGET_COMPLETE",json.dumps({k:v["stride_m"] for k,v in report["gaits"].items()}))
if __name__=="__main__":main()

