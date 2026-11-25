"""Supplementary, deforming joints for the confirmed original Meshy youth.

The original 15-joint locomotion/IK contract is retained without reparenting.
Additional joints are weighted to the actual source skin. The source's hands
are not a verified individually separated-finger mesh; grouped finger/thumb
controls deliberately do not claim independent five-finger topology.
"""
from __future__ import annotations
import math
from collections import Counter
import bpy
from mathutils import Vector

def clamp(x): return max(0.0, min(1.0, x))
def sm(a,b,x):
    t=clamp((x-a)/(b-a)); return t*t*(3-2*t)
def bell(a,b,c,d,x): return sm(a,b,x)*(1-sm(c,d,x))
def fit_auxiliary_rig(arm,body):
    original = {b.name:(b.head_local.copy(),b.tail_local.copy()) for b in arm.data.bones}
    spec = {}
    def add(name,parent,head,tail):
        h,t=Vector(head),Vector(tail)
        if (t-h).length < .012: raise ValueError("Degenerate auxiliary bone "+name)
        spec[name]=(parent,h,t)
    spine_a,spine_b=original["Spine"]
    for name,u,v in (("Lumbar",.08,.38),("Chest",.48,.85),("Neck",.86,1.02)):
        add(name,"Spine",spine_a.lerp(spine_b,u),spine_a.lerp(spine_b,v))
    for side,sign in (("L",1),("R",-1)):
        a,b=original["Arm_"+side]
        clavicle_head=Vector((sign*.035,a.y,a.z+.014))
        add("Clavicle_"+side,"Spine",clavicle_head,a)
        for prefix,donor in (("UpperArmTwist","Arm"),("ForearmTwist","Forearm")):
            start,end=original[donor+"_"+side]
            add(prefix+"_"+side,donor+"_"+side,start.lerp(end,.25),start.lerp(end,.80))
        h,t=original["Hand_"+side]
        axis=(t-h).normalized()
        across=Vector((float(-sign),0,0));across=(across-axis*across.dot(axis)).normalized()
        add("Palm_"+side,"Hand_"+side,h.lerp(t,.22),h.lerp(t,.7))
        add("FingerCurl_"+side,"Hand_"+side,h.lerp(t,.62),t+axis*.022)
        thumb=h.lerp(t,.35)+across*.018
        add("Thumb_"+side,"Hand_"+side,thumb,thumb+axis*.025+across*.021)
        foot,tip=original["Foot_"+side]
        ball=foot.lerp(tip,.7)
        add("Toe_"+side,"Foot_"+side,ball,tip+Vector((0,-.035,0)))
    h,t=original["Head"]
    add("Jaw","Head",h+Vector((0,-.03,.056)),h+Vector((0,-.079,.027)))
    for side,sign in (("L",1),("R",-1)):
        brow=h+Vector((sign*.033,-.077,.125))
        add("Brow_"+side,"Head",brow,brow+Vector((sign*.026,0,.012)))
    bpy.ops.object.select_all(action='DESELECT')
    arm.select_set(True);bpy.context.view_layer.objects.active=arm
    bpy.ops.object.mode_set(mode='EDIT')
    try:
        for name,(parent,h,t) in spec.items():
            bone=arm.data.edit_bones.new(name);bone.head=h;bone.tail=t
            bone.parent=arm.data.edit_bones[parent];bone.use_deform=True
    finally:
        bpy.ops.object.mode_set(mode='OBJECT')
    prior_names={g.index:g.name for g in body.vertex_groups}
    groups={g.name:g for g in body.vertex_groups}
    for name in spec: groups[name]=body.vertex_groups.new(name=name)
    counts=Counter()
    total_weights=Counter()
    def move(w,donor,target,f):
        take=w.get(donor,0.0)*clamp(f)
        if take>0:
            w[donor]-=take;w[target]=w.get(target,0.0)+take
    def projection(p,donor):
        a,b=original[donor];d=b-a;u=(p-a).dot(d)/d.length_squared
        return u,(p-(a+d*clamp(u))).length
    for v in body.data.vertices:
        p=v.co; x,y,z=p
        w={prior_names[g.group]:g.weight for g in v.groups if g.group in prior_names and g.weight>1e-8}
        move(w,"Spine","Lumbar",.56*bell(.88,.96,1.02,1.1,z))
        move(w,"Spine","Chest",.64*bell(1.01,1.10,1.18,1.25,z))
        neck=.46*bell(1.19,1.235,1.27,1.32,z)*(1-sm(.055,.12,abs(x-.012)))
        move(w,"Spine","Neck",neck);move(w,"Head","Neck",neck*.55)
        for side,sign in (("L",1),("R",-1)):
            shoulder=original["Arm_"+side][0]
            shoulder_mask=1-sm(.032,.095,(p-shoulder).length)
            move(w,"Spine","Clavicle_"+side,.52*shoulder_mask)
            move(w,"Arm_"+side,"Clavicle_"+side,.28*shoulder_mask)
            for prefix,donor in (("UpperArmTwist","Arm"),("ForearmTwist","Forearm")):
                bone=donor+"_"+side;u,d=projection(p,bone)
                move(w,bone,prefix+"_"+side,.58*bell(.06,.26,.7,.95,u)*(1-sm(.045,.11,d)))
            bone="Hand_"+side;u,d=projection(p,bone)
            hand_mask=(1-sm(.045,.083,d))*sm(-.1,.12,u)
            move(w,bone,"Palm_"+side,.50*bell(.0,.22,.58,.83,u)*hand_mask)
            move(w,bone,"FingerCurl_"+side,.72*sm(.45,.9,u)*hand_mask)
            h,t=original[bone];axis=(t-h).normalized()
            inside=Vector((-float(sign),0,0));inside=(inside-axis*inside.dot(axis)).normalized()
            lateral=(p-(h+(t-h)*clamp(u))).dot(inside)
            move(w,bone,"Thumb_"+side,.66*sm(.006,.025,lateral)*bell(.02,.2,.74,1.03,u)*hand_mask)
            move(w,"Foot_"+side,"Toe_"+side,.68*sm(.067,.115,-y)*(1-sm(.055,.09,z)))
        front=sm(.025,.09,-y)
        move(w,"Head","Jaw",.62*bell(1.265,1.285,1.32,1.365,z)*front*(1-sm(.054,.10,abs(x-.0167))))
        for side,sign in (("L",1),("R",-1)):
            lateral=(x-.0167)*sign
            brow=bell(.014,.027,.052,.081,lateral)*bell(1.365,1.385,1.409,1.44,z)*front
            move(w,"Head","Brow_"+side,.42*brow)
        selected=sorted(((n,a) for n,a in w.items() if a>1e-6),key=lambda a:a[1],reverse=True)[:4]
        total=sum(a for _,a in selected)
        if total<=0: raise ValueError("Unweighted original youth vertex")
        for g in list(v.groups):
            if g.group in prior_names: groups[prior_names[g.group]].remove([v.index])
        for name,value in selected:
            weight=value/total; groups[name].add([v.index],weight,'REPLACE')
            if weight>.01:counts[name]+=1;total_weights[name]+=weight
    absent=[name for name in spec if counts[name]<8 or total_weights[name]<.5]
    if absent:raise ValueError("Auxiliary joints without significant real skin weights: "+str(absent))
    return {"bones":len(arm.data.bones),"auxiliary_deform_joints":list(spec),
            "weighted_vertices_over_1pct":{n:counts[n] for n in spec},
            "maximum_vertex_influences":4,
            "topology_limit":"Grouped fingers/thumbs; independent finger articulation and phoneme lipsync are not validated."}

def auxiliary_pose(clip,t,angles):
    # Conservative secondary joint motion, phase-synchronised with existing
    # whole-body animation. Do not change the primary gait or hit timing.
    result=dict(angles)
    wave=math.sin(math.tau*t); breath=math.sin(2*math.tau*t)
    pulse=math.sin(math.pi*t)**2
    walk=clip in ("march","run")
    speech=clip=="talk"
    attack=clip in ("train","attack","block","hit")
    work=clip in ("work","gather")
    result["Lumbar"]=(.8*breath if not attack else 1.5*pulse,0,.6*wave)
    result["Chest"]=(1.2*breath if not walk else .6*breath,.5*wave,1.6*wave)
    result["Neck"]=(-.55*breath,0,1.1*wave if speech else .65*wave)
    for side,sign in (("L",1),("R",-1)):
        phase=(t+(.5 if side=="L" else 0))%1
        cycle=math.sin(math.tau*phase)
        result["Clavicle_"+side]=(1.4*cycle if walk else (3.0*pulse if speech or work else .7*breath),0,sign*.8*wave)
        result["UpperArmTwist_"+side]=(0,sign*(2.4*cycle if walk else 2.8*pulse),0)
        result["ForearmTwist_"+side]=(0,sign*(3.5*cycle if walk else 5.0*pulse),0)
        grip=(.75 if attack else .30 if work else .18)
        # Small flexion around the palm/knuckles, not an invented finger pose.
        result["Palm_"+side]=(sign*1.0*pulse,0,0)
        result["FingerCurl_"+side]=(sign*(2.0+4.0*grip*pulse),0,0)
        result["Thumb_"+side]=(sign*(1.5+2.0*grip*pulse),0,0)
        stance=.40 if clip=="run" else .56
        swing=clamp((phase-stance)/(1-stance)) if walk else 0
        result["Toe_"+side]=(2.0*math.sin(math.pi*swing)**2,0,0)
        result["Brow_"+side]=(0,0,sign*(1.2*pulse if speech else .35*wave))
    result["Jaw"]=(2.8*math.sin(math.tau*3*t)**2*pulse if speech else .7*pulse if attack else 0,0,0)
    return result

