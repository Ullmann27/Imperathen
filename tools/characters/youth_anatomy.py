"""Original youth-specific sandal and unarmed mesh corrections.
No substitute character, bone length changes, or replacement textures.
"""
from __future__ import annotations
import copy
import io
import math
import numpy as np
from PIL import Image
from scipy.spatial import cKDTree
from scipy.spatial.transform import Rotation as R

UP = np.array([0.,1.,0.])

def unit(v):
    return v/max(float(np.linalg.norm(v)),1e-9)

def plane_frame(forward, normal):
    y=unit(normal)
    z=unit(forward-y*np.dot(forward,y))
    if np.linalg.norm(z)<.5:
        raise ValueError("Degenerate sandal sole frame")
    x=unit(np.cross(y,z))
    return np.column_stack((x,y,z))

# The original Meshy youth is bound with both sandals rolled about 80 deg
# inward (soles facing each other). Its lowest bind-pose vertices are therefore
# the lateral foot wall, not the sole, and a "lowest points" plane fit is
# ambiguous (it flipped across LODs and failed on LOD 3). The actual sandal
# sole is the dominant connected flat slab of the Foot/Toe-skinned surface;
# it is identical across all four LODs and mirror-symmetric left/right.
SOLE_PATCH_DEGREES = 12.0        # coplanarity tolerance for region growing
SOLE_MIN_AREA_M2 = 0.004         # 40 cm2: real sandal slab, not a strap
SOLE_MIN_DOMINANCE = 1.5         # measured minimum 1.93 (LOD 1 right), LOD 0 >= 3.6
SOLE_MAX_RESIDUAL_M = 0.004      # slab vertices within 4 mm of their plane
SOLE_MAX_MIRROR_DEGREES = 12.0   # left/right slabs must mirror each other
SOLE_CONTACT_BAND_M = 0.004      # vertices sampled as sole contact points


def _foot_faces(target, read_access, side):
    d,b=target.d,target.b
    node=next(n for n in target.nodes if n.get("name")=="MeshyYouthBody")
    ids=[target.joints.index(target.ids[n+"_"+side]) for n in ("Foot","Toe")]
    for index,primitive in enumerate(d["meshes"][node["mesh"]]["primitives"]):
        a=primitive["attributes"]
        if not {"POSITION","JOINTS_0","WEIGHTS_0"}.issubset(a) or "indices" not in primitive:continue
        v=read_access(d,b,a["POSITION"]).astype(float)
        j=read_access(d,b,a["JOINTS_0"]).astype(int)
        w=read_access(d,b,a["WEIGHTS_0"])
        weight=(w*np.isin(j,ids)).sum(1)
        faces=read_access(d,b,primitive["indices"]).reshape(-1,3).astype(int)
        keep=(weight[faces].mean(1)>.5)&(v[faces][:,:,1].mean(1)<.14)
        yield index,v,weight,faces[keep]


def sole_patch(target, read_access, side):
    """Largest connected coplanar Foot/Toe surface: the real sandal sole."""
    best=[]
    for index,v,weight,faces in _foot_faces(target,read_access,side):
        if not len(faces):continue
        p0,p1,p2=v[faces[:,0]],v[faces[:,1]],v[faces[:,2]]
        cross=np.cross(p1-p0,p2-p0)
        area=np.linalg.norm(cross,axis=1)/2
        normal=cross/np.maximum(2*area[:,None],1e-12)
        # Weld UV/normal seams so the slab is one connected component.
        weld={}
        welded=np.array([weld.setdefault(tuple(k),len(weld)) for k in np.round(v,5)])
        edges={}
        for f,(x,y,z) in enumerate(welded[faces]):
            for e in ((x,y),(y,z),(z,x)):edges.setdefault((min(e),max(e)),[]).append(f)
        neighbours=[[] for _ in faces]
        for shared in edges.values():
            for f in shared:neighbours[f].extend(g for g in shared if g!=f)
        seen=np.zeros(len(faces),bool)
        limit=math.cos(math.radians(SOLE_PATCH_DEGREES))
        for seed in np.argsort(-area,kind="stable"):
            if seen[seed]:continue
            component=[seed];seen[seed]=True;queue=[seed]
            while queue:
                current=queue.pop()
                for other in neighbours[current]:
                    if not seen[other] and normal[other]@normal[seed]>limit:
                        seen[other]=True;component.append(other);queue.append(other)
            best.append((float(area[component].sum()),index,v,weight,faces[component],normal[component],area[component]))
    if not best:raise ValueError("No skinned sandal surface "+side)
    best.sort(key=lambda item:-item[0])
    _,index,v,weight,faces,normals,areas=best[0]
    outward=unit((normals*areas[:,None]).sum(0))
    centre=v[np.unique(faces)].mean(0)
    # Decimated LODs split the slab into non-adjacent fragments. A fragment
    # belongs to the sole only if it has the same orientation and every one
    # of its vertices lies on the slab plane. Only a flat surface with a
    # different orientation (beyond the coplanarity tolerance) competes, since
    # the calibrated quantity is the sole orientation.
    limit=math.cos(math.radians(SOLE_PATCH_DEGREES))
    second=0.
    for total_,index_,v_,_,faces_,normals_,areas_ in best[1:]:
        direction=unit((normals_*areas_[:,None]).sum(0))
        distance=np.abs((v_[np.unique(faces_)]-centre)@outward).max()
        if direction@outward<=limit:second=max(second,total_)
        elif index_==index and distance<=SOLE_MAX_RESIDUAL_M:
            faces=np.concatenate([faces,faces_]);normals=np.concatenate([normals,normals_]);areas=np.concatenate([areas,areas_])
    total=float(areas.sum())
    outward=unit((normals*areas[:,None]).sum(0))
    corners=v[np.unique(faces)]
    centre=corners.mean(0)
    residual=float(np.abs((corners-centre)@outward).max())
    if total<SOLE_MIN_AREA_M2:
        raise ValueError(f"Original sandal sole too small {side}: {total:.5f} m2")
    if second>0 and total/second<SOLE_MIN_DOMINANCE:
        raise ValueError(f"Original sandal sole ambiguous {side}: dominance {total/second:.2f}")
    if residual>SOLE_MAX_RESIDUAL_M:
        raise ValueError(f"Original sandal sole not planar {side}: {residual:.4f} m")
    return {"primitive":index,"normal":-outward,"offset":float(outward@centre),
            "area_m2":total,"dominance":(total/second if second>0 else None),
            "faces":len(faces),"residual_m":residual,"centre":centre}


def calibrate_soles(target, read_access):
    """Use the actual sandal sole slab, not the lowest bind-pose vertices."""
    forward=unit(np.cross(target.pelvis_frame[:,0],UP))
    result={}
    for side,sign in (("L",1),("R",-1)):
        patch=sole_patch(target,read_access,side)
        normal=patch["normal"]
        # The slab belongs to this foot and faces away from its interior.
        ankle=target.pos("Foot_"+side)
        if float((patch["centre"]-ankle)@-normal)<=0:
            raise ValueError("Sandal sole faces into the foot "+side)
        direction=target.pos("Toe_"+side)-target.pos("Foot_"+side)
        rest=plane_frame(direction,normal)
        # Slight outward toe angle, anatomically consistent on both sides.
        neutral=plane_frame(R.from_rotvec(UP*(sign*.075)).apply(forward),UP)
        result[side]={"rest":rest,"neutral":neutral,"samples":patch["faces"],
                      "rest_normal":normal.tolist(),"plane_offset":patch["offset"],
                      "area_m2":patch["area_m2"],"dominance":patch["dominance"],
                      "residual_m":patch["residual_m"],"primitive":patch["primitive"]}
    mirrored=np.array(result["R"]["rest_normal"])*np.array([-1.,1.,1.])
    mirror=math.degrees(math.acos(float(np.clip(np.dot(result["L"]["rest_normal"],mirrored),-1,1))))
    if mirror>SOLE_MAX_MIRROR_DEGREES:
        raise ValueError(f"Left/right sandal soles are not mirrored: {mirror:.1f} deg")
    for side in result:result[side]["mirror_deg"]=mirror
    return result

def sole_contact_mask(info,positions):
    """Vertices on, or protruding beyond, the calibrated sandal sole plane.

    Curved heel/toe ends of the sandal protrude up to ~2 cm past the flat
    slab; they touch the floor first when the foot pitches."""
    normal=np.asarray(info["rest_normal"],float)
    return positions@normal+info["plane_offset"]<=SOLE_CONTACT_BAND_M

def pitch_of(v):
    return math.atan2(float(v[1]),float(np.linalg.norm(v[[0,2]])))

def source_foot_angles(samples,idx,A,start,end,p,gait,name):
    """Recover heel strike/toe-off relative to the recorded stance baseline."""
    result={}
    for side,source in (("L","Left"),("R","Right")):
        f,t,e=(idx[source+n] for n in ("Foot","ToeBase","ToeBase_end"))
        segment=p[start:end+1]
        low=segment[:,t,1]
        ref=start+int(np.argmin(low+.15*np.abs(segment[:,f,1]-low)))
        baseline=pitch_of(A@(p[ref,t]-p[ref,f]))
        baseline_toe=pitch_of(A@(p[ref,e]-p[ref,t]))-baseline
        angles=[]
        for frame in samples:
            foot=A@(frame[t]-frame[f]);toe=A@(frame[e]-frame[t])
            pitch=pitch_of(foot)-baseline
            bend=pitch_of(toe)-pitch_of(foot)-baseline_toe
            # Standing punches and the block do not lift both soles or
            # inherit the source skeleton's inward ankle twist.
            moving=gait or "kick" in name
            pitch=float(np.clip(pitch,-.88,.68)) if moving else float(np.clip(pitch,-.12,.12))
            bend=float(np.clip(bend,-.40,.48)) if moving else 0.
            angles.append((pitch,bend))
        result[side]=angles
    return result

def foot_global(target,side,pitch):
    info=target.sole_frames[side]
    frame=info["neutral"]@R.from_rotvec(np.array([-pitch,0.,0.])).as_matrix()
    return frame@info["rest"].T@target.rest_r[target.ids["Foot_"+side]]

def toe_global(target,side,foot,bend):
    # Rotate around the actual transverse sole axis, not a bone's local Y.
    info=target.sole_frames[side]
    axis=foot@target.rest_r[target.ids["Foot_"+side]].T@info["rest"][:,0]
    neutral=foot@target.r[target.ids["Toe_"+side]]
    return R.from_rotvec(unit(axis)*(-bend)).as_matrix()@neutral

def neutral_idle(target,read_access):
    """Retain the original upper-body idle and rebuild its actual feet."""
    source=next(a for a in target.d["animations"] if a.get("name")=="idle")
    d,b=target.d,target.b
    channels={}
    duration=0.
    for channel in source["channels"]:
        node=channel["target"]["node"]
        if node not in target.joints or channel["target"]["path"]!="rotation":continue
        sampler=source["samplers"][channel["sampler"]]
        ts=read_access(d,b,sampler["input"]).reshape(-1)
        qs=read_access(d,b,sampler["output"])
        if sampler.get("interpolation","LINEAR")=="CUBICSPLINE":qs=qs[1::3]
        if len(ts)!=len(qs):raise ValueError("Invalid original idle tracks")
        channels[node]=(ts,qs)
        duration=max(duration,float(ts[-1]))
    if duration<=0:raise ValueError("Original idle duration is absent")
    from scipy.spatial.transform import Slerp
    count=max(2,round(duration*60)+1)
    timeline=np.linspace(0,duration,count)
    tracks={}
    for node,(ts,qs) in channels.items():
        if len(ts)==1:tracks[node]=np.repeat(R.from_quat(qs).as_matrix(),count,axis=0)
        else:tracks[node]=Slerp(ts,R.from_quat(qs))(np.clip(timeline,ts[0],ts[-1])).as_matrix()
    rotations=[];shifts=[];difference=[]
    for i in range(count):
        local={};glob={}
        for node in target.order:
            name=target.nodes[node]["name"];parent=target.parent.get(node)
            pr=glob.get(parent,np.eye(3))
            if name.startswith(("Thigh_","Shin_")):
                # A stable, neutral biped: symmetric fitted rest legs.
                g=target.rest_r[node]
            elif name.startswith("Foot_"):g=foot_global(target,name[-1],0.)
            elif name.startswith("Toe_"):g=toe_global(target,name[-1],pr,0.)
            else:g=pr@(tracks[node][i] if node in tracks else target.r[node])
            local[node]=pr.T@g;glob[node]=g
        g,p=target.fk(local)
        heights=[target.sole(g,p,side) for side in ("L","R")]
        shift=np.array([0.,-min(heights),0.])
        if abs(shift[1])>.28:raise ValueError("Excessive neutral idle pelvis correction")
        difference.append(abs(heights[0]-heights[1]))
        rotations.append(local);shifts.append(shift)
    target.animation("idle",duration,rotations,shifts)
    target.review_poses["idle"]=(rotations,shifts)
    return {"source":"existing original idle upper-body tracks; mesh-calibrated standing legs",
            "frames":count,"seconds":duration,"max_two_sole_height_difference_m":max(difference),
            "sole_frames":{k:{"samples":v["samples"],"rest_normal":v["rest_normal"]} for k,v in target.sole_frames.items()}}

def texture_colors(d,b,primitive,read_access):
    """Read the actual GLB base-color atlas. No invented material labels."""
    a=primitive["attributes"];n=d["accessors"][a["POSITION"]]["count"]
    m=d.get("materials",[])[primitive["material"]] if "material" in primitive else {}
    p=m.get("pbrMetallicRoughness",{})
    color=np.array(p.get("baseColorFactor",[1,1,1,1])[:3],float)
    tex=p.get("baseColorTexture")
    if not tex:return np.broadcast_to(color,(n,3)).copy()
    uv_id=a.get("TEXCOORD_"+str(tex.get("texCoord",0)))
    if uv_id is None:raise ValueError("Textured original primitive has no UV coordinates")
    image=d["images"][d["textures"][tex["index"]]["source"]]
    if "bufferView" not in image:raise ValueError("Original texture is not embedded")
    view=d["bufferViews"][image["bufferView"]]
    start=view.get("byteOffset",0)
    with Image.open(io.BytesIO(bytes(b[start:start+view["byteLength"]]))) as im:
        rgb=np.asarray(im.convert("RGB"),dtype=float)/255.
    uv=read_access(d,b,uv_id)%1.
    x=np.minimum(rgb.shape[1]-1,(uv[:,0]*rgb.shape[1]).astype(int))
    y=np.minimum(rgb.shape[0]-1,(uv[:,1]*rgb.shape[0]).astype(int))
    return rgb[y,x]*color

def skin_color(rgb):
    r,g,b=rgb.T
    return (g>.16)&(r>g*1.15)&(r<g*1.9)&(b>g*.72)

def original_structure(document):
    """Fingerprint data other than explicitly authorized skin and weapon edits."""
    result=copy.deepcopy({k:document.get(k) for k in
                          ("meshes","nodes","skins","materials","textures","images")})
    for node in result["nodes"]:
        if node.get("name")=="PracticeBlade":
            for key in ("mesh","skin","weights"):node.pop(key,None)
    for mesh in result["meshes"]:
        for primitive in mesh["primitives"]:
            primitive.pop("indices",None)
            for key in ("JOINTS_0","WEIGHTS_0"):
                primitive.get("attributes",{}).pop(key,None)
    return result

def remove_start_weapon(target,read_access):
    """Remove the separate blade and conservatively trim fused metal remnants."""
    d,b=target.d,target.b
    blade=next(n for n in target.nodes if n.get("name")=="PracticeBlade")
    if "mesh" not in blade:raise ValueError("Original sword mesh missing before separation")
    points=[]
    for primitive in d["meshes"][blade["mesh"]]["primitives"]:
        points.extend(read_access(d,b,primitive["attributes"]["POSITION"]))
    points=np.unique(np.asarray(points),axis=0)
    if len(points)<8:raise ValueError("Invalid original blade geometry")
    center=points.mean(0)
    _,_,vh=np.linalg.svd(points-center,full_matrices=False)
    axis=vh[0];tree=cKDTree(points)
    body=next(n for n in target.nodes if n.get("name")=="MeshyYouthBody")
    hand=target.pos("Hand_R")
    report={"separate_weapon_geometry_removed":True,"source_weapon_vertices":len(points),
            "residual_faces_removed":0,"preserved_skin_faces":0,"surfaces":[]}
    hand_ids=[i for i,n in enumerate(target.joints)
              if target.nodes[n]["name"] in ("Hand_R","Palm_R","FingerCurl_R","Thumb_R","Forearm_R")]
    for primitive in d["meshes"][body["mesh"]]["primitives"]:
        a=primitive["attributes"]
        if not {"POSITION","JOINTS_0","WEIGHTS_0"}.issubset(a) or "indices" not in primitive:continue
        v=read_access(d,b,a["POSITION"])
        j=read_access(d,b,a["JOINTS_0"]).astype(int)
        w=read_access(d,b,a["WEIGHTS_0"])
        ids=read_access(d,b,primitive["indices"]).reshape(-1,3).astype(int)
        rgb=texture_colors(d,b,primitive,read_access)
        flesh=skin_color(rgb)
        center_faces=v[ids].mean(1)
        q=center_faces-center
        radius=np.linalg.norm(q-(q@axis)[:,None]*axis,axis=1)
        proximity=tree.query(center_faces)[0]
        hand_weight=(w*np.isin(j,hand_ids)).sum(1)[ids].mean(1)
        # Exact weapon source and right hand jointly delimit the candidate.
        # A face with ANY flesh-colored corner is retained; this avoids
        # carving fingers to remove the remaining hilt.
        near=(np.linalg.norm(center_faces-hand,axis=1)<.15)&(radius<.055)&(proximity<.045)&(hand_weight>.65)
        color=rgb[ids].mean(1)
        sat=color.max(1)-color.min(1)
        metal=(color.max(1)<.70)&((sat<.23)|(color[:,0]>color[:,2]*1.18))
        remove=near&metal&~flesh[ids].any(1)
        count=int(remove.sum())
        if count>max(30,int(len(ids)*.015)):
            raise ValueError("Fused weapon selection exceeds conservative hand region")
        if count:
            primitive["indices"]=target.append(ids[~remove].reshape(-1),"SCALAR",component_type=5125)
            d["bufferViews"][d["accessors"][primitive["indices"]]["bufferView"]]["target"]=34963
        report["residual_faces_removed"]+=count
        report["preserved_skin_faces"]+=int((near&flesh[ids].any(1)).sum())
        report["surfaces"].append({"faces_before":len(ids),"faces_after":int((~remove).sum()),"removed":count})
    # This asset represents the unarmed child ONLY. The adult will use the
    # independent equipment system, never this original embedded blade.
    for key in ("mesh","skin","weights"):blade.pop(key,None)
    report["remaining_fused_hilt_visual_review_required"]=True
    return report
