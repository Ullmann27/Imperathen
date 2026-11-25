"""Compose and validate the actual Blender soldier portraits and exported GLBs.

Run after build_soldier_faces.py using the project Python environment.
"""
from __future__ import annotations
import argparse, hashlib, json, math, struct
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(__file__).resolve().parents[2]
ART=ROOT/"art/soldier_faces"
HAIR={"crop":"kurzer Schnitt","part":"Seitenscheitel","curl":"Locken","receding":"zurückgehender Ansatz","bald":"rasierter Kopf","sweep":"zurückgestrichen","temples":"freie Schläfen","wave":"welliges Haar"}
BEARD={"clean":"glatt rasiert","short":"kurzer Bart","moustache":"Schnurrbart","full":"Vollbart","stubble":"Bartstoppeln","goatee":"Kinn- und Oberlippenbart","chin":"Kinnbart"}

def document(path):
    data=path.read_bytes()
    magic,version,length=struct.unpack_from("<4sII",data)
    if (magic,version,length)!=(b"glTF",2,len(data)):raise ValueError("Invalid GLB: "+str(path))
    size,kind=struct.unpack_from("<II",data,12)
    if kind!=0x4e4f534a:raise ValueError("Missing glTF JSON")
    return json.loads(data[20:20+size])

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--art",type=Path,default=ART)
    parser.add_argument("--preview",action="store_true")
    args=parser.parse_args()
    report=json.loads((args.art/"build_report.json").read_text())
    members=report["profiles"]
    font_path="/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
    bold_path="/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
    font=lambda size,bold=False:ImageFont.truetype(bold_path if bold else font_path,size)
    cols=min(5,len(members));rows=math.ceil(len(members)/cols)
    cell_w,cell_h,pad,header,footer=480,675,20,174,82
    width=cols*cell_w+(cols+1)*pad
    height=header+rows*(cell_h+pad)+footer
    canvas=Image.new("RGB",(width,height),(18,24,28));draw=ImageDraw.Draw(canvas)
    draw.text((pad,22),"IMPERATHEN / FIGURENWERKSTATT",font=font(28),fill=(205,169,102))
    draw.text((pad,67),str(len(members))+" SOLDATEN · GESICHTSSTUDIE",font=font(45,True),fill=(237,235,226))
    draw.text((pad,127),"Tatsächliche Blender-Render der modellierten Varianten",font=font(23),fill=(164,177,184))
    checks=[]
    for n,member in enumerate(members):
        x=pad+(n%cols)*(cell_w+pad);y=header+(n//cols)*(cell_h+pad)
        path=args.art/"portraits"/("soldier_%02d.png"%member["id"])
        picture=Image.open(path).convert("RGB")
        if picture.size!=(480,600):raise ValueError("Unexpected portrait size: "+str(path))
        canvas.paste(picture,(x,y))
        draw.rectangle((x,y+600,x+cell_w,y+cell_h),fill=(29,37,42))
        draw.text((x+13,y+610),f'{member["id"]:02d}  {member["name"]} · {member["age"]} Jahre',font=font(24,True),fill=(238,231,210))
        text=HAIR[member["hair"]]+" · "+BEARD[member["beard"]]
        size=19
        while draw.textlength(text,font=font(size))>cell_w-26:size-=1
        draw.text((x+13,y+645),text,font=font(size),fill=(177,190,198))
        if not args.preview:
            glb=ROOT/member["glb"];doc=document(glb)
            joints={tuple(s["joints"])for s in doc.get("skins",[])}
            if not joints or any(len(s)!=15 for s in joints):raise ValueError("Expected preserved 15-bone rigs")
            names={a.get("name")for a in doc.get("animations",[])}
            expected=set(member["animation_tracks"])
            if not expected.issubset(names):raise ValueError(f'{member["id"]}: missing animations {expected-names}')
            morphs={name for m in doc.get("meshes",[]) for name in m.get("extras",{}).get("targetNames",[])}
            if not set(member["body_morphs"]).issubset(morphs):raise ValueError("Missing face morphs")
            checks.append({"id":member["id"],"bytes":glb.stat().st_size,"sha256":hashlib.sha256(glb.read_bytes()).hexdigest(),"joint_count":15,"animation_count":len(names),"morphs":sorted(morphs)})
    base=height-footer+18
    draw.text((pad,base),"Fiktive Figuren · Anatomie, Haare und Bärte in 3D bearbeitet · bestehendes Kompanie-Rig",font=font(20),fill=(154,168,175))
    draw.text((pad,base+29),"Entwurfsstudie: 20 Varianten einer anatomischen Quelle; keine unabhängigen Personenscans.",font=font(18),fill=(123,139,148))
    canvas.save(args.art/"soldier_faces_contact_sheet.jpg",quality=94,subsampling=0)
    if not args.preview:
        if len(checks)!=20 or len({m["head_geometry_sha256"]for m in members})!=20:raise ValueError("Twenty distinct heads required")
        files=list(args.art.rglob("*"))+[ROOT/m["glb"]for m in members]
        output_bytes=sum(p.stat().st_size for p in files if p.is_file())
        validation={"checked_exports":len(checks),"unique_head_geometries":20,"all_have_15_bones":True,
            "all_preserve_source_animation_tracks":True,"output_bytes":output_bytes,"exports":checks,
            "visual_review":"Contact sheet must additionally be inspected by a person/assistant; geometry/rig checks alone are not visual approval."}
        (args.art/"validation.json").write_text(json.dumps(validation,indent=2)+"\n")
        if output_bytes>100_000_000:raise ValueError(f"Output budget exceeded: {output_bytes}")
        print("SOLDIER_FACE_VALIDATION",len(checks),output_bytes)
    print(args.art/"soldier_faces_contact_sheet.jpg")

if __name__=="__main__":main()
