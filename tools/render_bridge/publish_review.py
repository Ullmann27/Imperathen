"""Copy only hash-verified generated review files into the render-only branch."""
import argparse
import json
from pathlib import Path
import shutil
from protocol import load_job, digest

ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser()
p.add_argument("--input",type=Path,required=True)
p.add_argument("--checkout",required=True)
args=p.parse_args()
job=load_job(ROOT/"render_bridge/jobs/current.json")
source=args.input/job["job_id"]
receipt=json.loads((source/"receipt.json").read_text(encoding="utf-8"))
if receipt.get("status")!="rendered_and_reopened" or receipt.get("checkout")!=args.checkout or receipt.get("job_id")!=job["job_id"] or receipt.get("source_revision")!=job["source_revision"]:
    raise ValueError("Receipt does not match rendered source")
expected={a["id"]:a for a in job["assets"]}
rows=receipt["assets"]
if len(rows)!=len(expected) or {a["id"] for a in rows}!=set(expected):
    raise ValueError("Missing expected render")
dst=ROOT/"art/review/render-atelier"/job["job_id"]
if dst.exists(): raise ValueError("A published version already exists")
for row in rows:
    ident=row["id"]
    if row["source_git_blob"]!=expected[ident]["git_blob"] or row["armatures"]<1 or not row["actions"]:
        raise ValueError("Source or skeleton evidence mismatch")
    for name in ("Ganzfigur.png","Gesicht.png","Rueckansicht.png","Figur.blend","Original.glb"):
        if digest(source/ident/name)!=row["files"][name]:
            raise ValueError("Render file hash mismatch")
    if row["files"]["Original.glb"]["sha256"]!=row["source_sha256"]:
        raise ValueError("Original GLB mismatch")
    (dst/ident).mkdir(parents=True,exist_ok=False)
    for name in ("Ganzfigur.png","Gesicht.png","Rueckansicht.png","Figur.blend"):
        shutil.copyfile(source/ident/name,dst/ident/name)
for name in ("README.md","receipt.json"):
    shutil.copyfile(source/name,dst/name)
print("Published verified render-only gallery",dst)
